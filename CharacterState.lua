local ADDON_NAME, ns = ...

local function GetCharacterKey()
    local name, realm = UnitFullName("player")
    return (realm or GetRealmName() or "Unknown") .. " - " .. (name or UnitName("player") or "Unknown")
end

-- Every profile is rebuilt from ns.DEFAULTS: a wrong type would raise an error in the layout code at every login.

local VALID_ANCHOR_POINTS = {}
for _, anchor in ipairs(ns.ANCHOR_POINTS) do
    VALID_ANCHOR_POINTS[anchor.point] = true
end
local VALID_STRATA = {}
for _, level in ipairs(ns.STRATA_LEVELS) do
    VALID_STRATA[level.value] = true
end
local STRING_CHOICES = { point = VALID_ANCHOR_POINTS, relativePoint = VALID_ANCHOR_POINTS, strata = VALID_STRATA }

local function SanitizeInto(defaults, source, target)
    for key, default in pairs(defaults) do
        local value = source[key]
        local valueType = type(value)
        if valueType == type(default) then
            if valueType == "table" then
                target[key] = {}
                SanitizeInto(default, value, target[key])
            elseif valueType == "number" then
                -- Rejects NaN and infinity.
                if value == value and value ~= math.huge and value ~= -math.huge then
                    local limits = ns.NUMBER_LIMITS[key]
                    if limits then
                        value = math.max(limits[1], math.min(limits[2], value))
                    end
                    target[key] = value
                end
            elseif valueType ~= "string" or not STRING_CHOICES[key] or STRING_CHOICES[key][value] then
                target[key] = value
            end
        end
    end
end

function ns.SanitizeProfile(source)
    local db = {}
    if type(source) == "table" then
        SanitizeInto(ns.DEFAULTS, source, db)
    end
    ns.CopyDefaults(ns.DEFAULTS, db)
    return db
end

local function AdoptProfile(source)
    ns.db = ns.SanitizeProfile(source)
    ComboPointsDB.profiles[ns.currentCharacterKey] = ns.db
end

function ns.LoadCharacterProfile()
    ns.currentCharacterKey = GetCharacterKey()
    ns.classFile = select(2, UnitClass("player"))
    ns.activePowerType, ns.activePowerToken = ns.GetPowerType(ns.classFile)
    if type(ComboPointsDB) ~= "table" then
        ComboPointsDB = {}
    end
    if type(ComboPointsDB.profiles) ~= "table" then
        local legacySettings = ns.CopyTable(ComboPointsDB)
        ComboPointsDB = { version = 2, profiles = { [ns.currentCharacterKey] = legacySettings } }
    end

    AdoptProfile(ComboPointsDB.profiles[ns.currentCharacterKey])
end

function ns.ResetCurrentProfile()
    AdoptProfile(nil)
end

function ns.GetOtherCharacterKeys()
    local keys = {}
    for key in pairs(ComboPointsDB.profiles) do
        if key ~= ns.currentCharacterKey then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

function ns.CopyProfileToCurrent(sourceKey)
    local source = ComboPointsDB.profiles[sourceKey]
    if type(source) ~= "table" then
        return false
    end
    AdoptProfile(source)
    return true
end

-- Both readers are data-only parsers: the pasted text is never compiled or run (no loadstring).

local JSON_ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function EncodeJsonString(value)
    return '"' .. value:gsub('[%c"\\]', function(character)
        return JSON_ESCAPES[character] or string.format("\\u%04x", character:byte())
    end) .. '"'
end

local function IsSequence(value)
    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end
    return count > 0 and count == #value
end

local function EncodeJson(value, parts)
    local valueType = type(value)
    if valueType == "table" then
        if IsSequence(value) then
            table.insert(parts, "[")
            for index, entry in ipairs(value) do
                if index > 1 then
                    table.insert(parts, ",")
                end
                EncodeJson(entry, parts)
            end
            table.insert(parts, "]")
        else
            -- Sorted, so the same profile always exports the same text.
            local keys = {}
            for key in pairs(value) do
                table.insert(keys, tostring(key))
            end
            table.sort(keys)
            table.insert(parts, "{")
            for index, key in ipairs(keys) do
                if index > 1 then
                    table.insert(parts, ",")
                end
                table.insert(parts, EncodeJsonString(key) .. ":")
                local entry = value[key]
                if entry == nil then
                    entry = value[tonumber(key)]
                end
                EncodeJson(entry, parts)
            end
            table.insert(parts, "}")
        end
    elseif valueType == "string" then
        table.insert(parts, EncodeJsonString(value))
    elseif valueType == "number" then
        -- JSON has no NaN or infinity.
        if value ~= value or value == math.huge or value == -math.huge then
            table.insert(parts, "null")
        else
            table.insert(parts, string.format("%.14g", value))
        end
    elseif valueType == "boolean" then
        table.insert(parts, tostring(value))
    else
        table.insert(parts, "null")
    end
end

function ns.SerializeProfile(db)
    local parts = {}
    EncodeJson(db, parts)
    return table.concat(parts)
end

local MAX_IMPORT_LENGTH = 20000
local MAX_IMPORT_DEPTH = 8
local STRING_ESCAPES = { n = "\n", r = "\r", t = "\t", ["\\"] = "\\", ['"'] = '"', ["\n"] = "\n" }
local JSON_UNESCAPES = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ["\\"] = "\\", ['"'] = '"', ["/"] = "/" }

local function EncodeUtf8(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
    end
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + (math.floor(code / 0x40) % 0x40), 0x80 + (code % 0x40))
end

-- An object key that is a whole number ("3") becomes that number: number-indexed tables with gaps are written as objects.
local function ParseJsonText(text)
    local position = 1
    local ParseValue

    local function SkipSpace()
        position = text:find("%S", position) or (#text + 1)
    end

    local function Peek()
        SkipSpace()
        return text:sub(position, position)
    end

    local function ParseString()
        local parts = {}
        position = position + 1
        while true do
            local character = text:sub(position, position)
            if character == "" then
                error("unterminated string")
            elseif character == '"' then
                position = position + 1
                return table.concat(parts)
            elseif character == "\\" then
                local escape = text:sub(position + 1, position + 1)
                if escape == "u" then
                    local digits = text:match("^%x%x%x%x", position + 2)
                    if not digits then
                        error("bad unicode escape")
                    end
                    local code = tonumber(digits, 16)
                    -- Surrogate halves are not characters on their own.
                    if code >= 0xD800 and code <= 0xDFFF then
                        error("unsupported unicode escape")
                    end
                    table.insert(parts, EncodeUtf8(code))
                    position = position + 6
                else
                    local unescaped = JSON_UNESCAPES[escape]
                    if not unescaped then
                        error("bad escape")
                    end
                    table.insert(parts, unescaped)
                    position = position + 2
                end
            else
                table.insert(parts, character)
                position = position + 1
            end
        end
    end

    local function ParseNumber()
        local literal = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", position)
        local number = literal and tonumber(literal)
        if not number then
            error("bad value")
        end
        position = position + #literal
        return number
    end

    local function ParseArray(depth)
        local result = {}
        position = position + 1
        if Peek() == "]" then
            position = position + 1
            return result
        end
        while true do
            result[#result + 1] = ParseValue(depth)
            local character = Peek()
            position = position + 1
            if character == "]" then
                return result
            elseif character ~= "," then
                error("expected , or ]")
            end
        end
    end

    local function ParseObject(depth)
        local result = {}
        position = position + 1
        if Peek() == "}" then
            position = position + 1
            return result
        end
        while true do
            if Peek() ~= '"' then
                error("expected a key")
            end
            local key = ParseString()
            if Peek() ~= ":" then
                error("expected :")
            end
            position = position + 1
            if key:match("^[1-9]%d*$") then
                key = tonumber(key)
            end
            result[key] = ParseValue(depth)
            local character = Peek()
            position = position + 1
            if character == "}" then
                return result
            elseif character ~= "," then
                error("expected , or }")
            end
        end
    end

    ParseValue = function(depth)
        local character = Peek()
        if character == "{" or character == "[" then
            if depth >= MAX_IMPORT_DEPTH then
                error("nested too deeply")
            end
            if character == "{" then
                return ParseObject(depth + 1)
            end
            return ParseArray(depth + 1)
        elseif character == '"' then
            return ParseString()
        end
        for _, word in ipairs({ "true", "false", "null" }) do
            if text:sub(position, position + #word - 1) == word then
                position = position + #word
                if word == "null" then
                    return nil
                end
                return word == "true"
            end
        end
        return ParseNumber()
    end

    local result = ParseValue(0)
    SkipSpace()
    if position <= #text then
        error("trailing text")
    end
    return result
end

-- Reads the Lua-table text exported before 2.0.0, so old strings still import.
local function ParseLegacyText(text)
    local position = 1
    local ParseValue

    local function SkipSpace()
        position = text:find("%S", position) or (#text + 1)
    end

    local function Expect(character)
        SkipSpace()
        if text:sub(position, position) ~= character then
            error("expected " .. character)
        end
        position = position + 1
    end

    local function ParseString()
        local parts = {}
        position = position + 1
        while true do
            local character = text:sub(position, position)
            if character == "" then
                error("unterminated string")
            elseif character == '"' then
                position = position + 1
                return table.concat(parts)
            elseif character == "\\" then
                local digits = text:match("^%d%d?%d?", position + 1)
                if digits then
                    table.insert(parts, string.char(tonumber(digits)))
                    position = position + 1 + #digits
                else
                    local escaped = STRING_ESCAPES[text:sub(position + 1, position + 1)]
                    if not escaped then
                        error("bad escape")
                    end
                    table.insert(parts, escaped)
                    position = position + 2
                end
            else
                table.insert(parts, character)
                position = position + 1
            end
        end
    end

    local function ParseNumber()
        local literal = text:match("^-?%d[%d%.]*[eE]?[-+]?%d*", position)
        local number = literal and tonumber(literal)
        if not number then
            error("bad number")
        end
        position = position + #literal
        return number
    end

    local function ParseTable(depth)
        if depth > MAX_IMPORT_DEPTH then
            error("nested too deeply")
        end
        local result = {}
        position = position + 1
        while true do
            SkipSpace()
            if text:sub(position, position) == "}" then
                position = position + 1
                return result
            end
            Expect("[")
            SkipSpace()
            local key
            if text:sub(position, position) == '"' then
                key = ParseString()
            else
                key = ParseNumber()
            end
            Expect("]")
            Expect("=")
            result[key] = ParseValue(depth)
            SkipSpace()
            if text:sub(position, position) == "," then
                position = position + 1
            elseif text:sub(position, position) ~= "}" then
                error("expected , or }")
            end
        end
    end

    ParseValue = function(depth)
        SkipSpace()
        local character = text:sub(position, position)
        if character == "{" then
            return ParseTable(depth + 1)
        elseif character == '"' then
            return ParseString()
        end
        for _, word in ipairs({ "true", "false", "nil" }) do
            if text:sub(position, position + #word - 1) == word then
                position = position + #word
                if word == "nil" then
                    return nil
                end
                return word == "true"
            end
        end
        return ParseNumber()
    end

    local result = ParseValue(0)
    SkipSpace()
    if position <= #text then
        error("trailing text")
    end
    return result
end

function ns.DeserializeProfile(text)
    if type(text) ~= "string" or text:match("^%s*$") or #text > MAX_IMPORT_LENGTH then
        return nil
    end
    for _, parse in ipairs({ ParseJsonText, ParseLegacyText }) do
        local ok, result = pcall(parse, text)
        if ok and type(result) == "table" then
            return result
        end
    end
    return nil
end

function ns.ImportProfile(data)
    if type(data) ~= "table" then
        return false
    end
    AdoptProfile(data)
    return true
end

local function GetSpecializationID()
    local specialization = C_SpecializationInfo.GetSpecialization()
    if not specialization then
        return nil
    end
    return C_SpecializationInfo.GetSpecializationInfo(specialization)
end

function ns.IsTrackedClass(classFile)
    classFile = classFile or select(2, UnitClass("player"))
    local specializationID = GetSpecializationID()
    if classFile == "DRUID" then
        -- Second return: in Cat Form on any spec, for the catFormAllSpecs option.
        local inCatForm = GetShapeshiftFormID() == 1 -- Cat Form
        return specializationID == 103 and inCatForm, inCatForm -- Feral
    end
    if classFile == "MONK" then
        return specializationID == 269 -- Windwalker
    end
    if classFile == "MAGE" then
        return specializationID == 62 -- Arcane
    end

    return classFile == "ROGUE" or classFile == "PALADIN" or classFile == "WARLOCK"
end

-- The token is what UNIT_POWER_FREQUENT passes as its second argument.
function ns.GetPowerType(classFile)
    classFile = classFile or select(2, UnitClass("player"))
    if classFile == "DRUID" or classFile == "ROGUE" then
        return Enum.PowerType.ComboPoints, "COMBO_POINTS"
    end
    if classFile == "PALADIN" then
        return Enum.PowerType.HolyPower, "HOLY_POWER"
    end
    if classFile == "MONK" then
        return Enum.PowerType.Chi, "CHI"
    end
    if classFile == "WARLOCK" then
        return Enum.PowerType.SoulShards, "SOUL_SHARDS"
    end
    if classFile == "MAGE" then
        return Enum.PowerType.ArcaneCharges, "ARCANE_CHARGES"
    end
end

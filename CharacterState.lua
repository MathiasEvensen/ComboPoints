local ADDON_NAME, ns = ...

-- Per-character saved profile (ComboPointsDB.profiles[characterKey]).

local function GetCharacterKey()
    local name, realm = UnitFullName("player")
    return (realm or GetRealmName() or "Unknown") .. " - " .. (name or UnitName("player") or "Unknown")
end

function ns.LoadCharacterProfile()
    ns.currentCharacterKey = GetCharacterKey()
    ns.classFile = select(2, UnitClass("player"))
    ComboPointsDB = ComboPointsDB or {}
    if not ComboPointsDB.profiles then
        local legacySettings = ns.CopyTable(ComboPointsDB)
        ComboPointsDB = { version = 2, profiles = { [ns.currentCharacterKey] = legacySettings } }
    end

    ns.db = ComboPointsDB.profiles[ns.currentCharacterKey] or {}
    ComboPointsDB.profiles[ns.currentCharacterKey] = ns.db
    ns.CopyDefaults(ns.DEFAULTS, ns.db)
end

function ns.ResetCurrentProfile()
    ns.db = {}
    ComboPointsDB.profiles[ns.currentCharacterKey] = ns.db
    ns.CopyDefaults(ns.DEFAULTS, ns.db)
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
    if not source then
        return false
    end

    local db = ns.CopyTable(source)
    db.position = db.position or ns.CopyTable(ns.DEFAULTS.position)
    db.snapToFrame = source.snapToFrame == true
    ns.db = db
    ComboPointsDB.profiles[ns.currentCharacterKey] = db
    ns.CopyDefaults(ns.DEFAULTS, db)
    return true
end

-- Export/import: serialize a profile table to a pasteable Lua literal string and back.
-- Deserialization runs the parsed chunk in an empty sandbox
-- (setfenv to {}) so pasted text can only build a table, never touch globals.

local function SerializeValue(value, parts)
    local valueType = type(value)
    if valueType == "table" then
        table.insert(parts, "{")
        for key, entry in pairs(value) do
            if type(key) == "number" then
                table.insert(parts, "[" .. key .. "]=")
            else
                table.insert(parts, "[" .. string.format("%q", key) .. "]=")
            end
            SerializeValue(entry, parts)
            table.insert(parts, ",")
        end
        table.insert(parts, "}")
    elseif valueType == "string" then
        table.insert(parts, string.format("%q", value))
    elseif valueType == "number" or valueType == "boolean" then
        table.insert(parts, tostring(value))
    else
        table.insert(parts, "nil")
    end
end

function ns.SerializeProfile(db)
    local parts = {}
    SerializeValue(ns.CopyTable(db), parts)
    return table.concat(parts)
end

function ns.DeserializeProfile(text)
    if type(text) ~= "string" or text:match("^%s*$") then
        return nil
    end
    local chunk = loadstring("return " .. text)
    if not chunk then
        return nil
    end
    setfenv(chunk, {})
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        return nil
    end
    return result
end

function ns.ImportProfile(data)
    if type(data) ~= "table" then
        return false
    end
    local db = ns.CopyTable(data)
    db.position = db.position or ns.CopyTable(ns.DEFAULTS.position)
    db.snapToFrame = data.snapToFrame == true
    ns.db = db
    ComboPointsDB.profiles[ns.currentCharacterKey] = db
    ns.CopyDefaults(ns.DEFAULTS, db)
    return true
end

-- Class/spec detection: which resource to track, and whether the current
-- class+spec actually uses that resource.

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
        return specializationID == 103 and GetShapeshiftFormID() == 1 -- Feral Cat Form
    end
    if classFile == "MONK" then
        return specializationID == 269 -- Windwalker
    end
    if classFile == "MAGE" then
        return specializationID == 62 -- Arcane
    end

    return classFile == "ROGUE" or classFile == "PALADIN" or classFile == "WARLOCK"
end

function ns.GetPowerType(classFile)
    classFile = classFile or select(2, UnitClass("player"))
    if classFile == "DRUID" or classFile == "ROGUE" then
        return Enum.PowerType.ComboPoints
    end
    if classFile == "PALADIN" then
        return Enum.PowerType.HolyPower
    end
    if classFile == "MONK" then
        return Enum.PowerType.Chi
    end
    if classFile == "WARLOCK" then
        return Enum.PowerType.SoulShards
    end
    if classFile == "MAGE" then
        return Enum.PowerType.ArcaneCharges
    end
end

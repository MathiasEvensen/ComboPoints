local ADDON_NAME, ns = ...

-- Per-character saved profile (ComboPointsDB.profiles[characterKey]).

local function GetCharacterKey()
    local name, realm = UnitFullName("player")
    return (realm or GetRealmName() or "Unknown") .. " - " .. (name or UnitName("player") or "Unknown")
end

function ns.LoadCharacterProfile()
    ns.currentCharacterKey = GetCharacterKey()
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
    db.position = ns.CopyTable(source.position or ns.DEFAULTS.position)
    db.snapToFrame = source.snapToFrame == true
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

function ns.IsTrackedClass()
    local _, classFile = UnitClass("player")
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

function ns.GetPowerType()
    local _, classFile = UnitClass("player")
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

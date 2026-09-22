local ADDON_NAME, ns = ...

ns.addon = CreateFrame("Frame")

ns.DEFAULTS = {
    pointWidth = 22,
    pointHeight = 17,
    spacing = 3,
    shape = "square",
    color = { r = 1, g = 0.1411764770746231, b = 0.07450980693101883, a = 0.8463539481163025 },
    useIndividualColors = false,
    pointColors = {
        [1] = { r = 1, g = 0.1, b = 0.1, a = 1 },
        [2] = { r = 1, g = 0.1, b = 0.1, a = 1 },
        [3] = { r = 1, g = 0.82, b = 0, a = 1 },
        [4] = { r = 0.1, g = 0.9, b = 0.2, a = 1 },
        [5] = { r = 0.1, g = 0.9, b = 0.2, a = 1 },
    },
    emptyColor = { r = 0.07450980693101883, g = 0.07450980693101883, b = 0.07450980693101883, a = 0.3046874403953552 },
    showBackground = true,
    backgroundColor = { r = 0, g = 0, b = 0, a = 0.3255204856395721 },
    showBorder = true,
    borderSize = 1,
    borderColor = { r = 0, g = 0, b = 0, a = 0.5338539481163025 },
    showCounter = false,
    counterShowMax = false,
    counterHideAtZero = false,
    counterFont = "",
    counterFontSize = 16,
    counterOutline = true,
    counterColor = { r = 1, g = 1, b = 1, a = 1 },
    counterOffsetX = 0,
    counterOffsetY = 0,
    position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -180, frameName = "UIParent" },
    configPosition = { point = "TOPLEFT", relativePoint = "CENTER", x = -260, y = 305 },
    snapToFrame = false,
    onlyInCombat = false,
    onlySupportedSpecs = true,
    enabled = true,
}

-- Shared mutable state, populated by other addon files as they load and run.
ns.db = nil
ns.tracker = nil
ns.configPanel = nil
ns.pointFrames = {}
ns.activePowerType = nil
ns.currentCharacterKey = nil
ns.classFile = nil

-- Replaced with the real refresher once the config panel builds its live
-- preview (ConfigPanel.lua BuildPreviewSection); a no-op until then so
-- callers can invoke it unconditionally.
ns.UpdateConfigPreview = function() end

-- Fonts: "" means the client's standard font. The candidate list covers the
-- fonts WoW ships (locale builds ship different subsets), and each one is
-- probed with a throwaway font string before being offered, so a font missing
-- from this client never reaches the dropdown. Any font another addon has
-- registered with LibSharedMedia-3.0 is merged in when that library is loaded;
-- this addon does not embed it.

local FONT_CANDIDATES = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Skurri", path = "Fonts\\skurri.ttf" },
    { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { name = "Nimrod MT", path = "Fonts\\NIM_____.ttf" },
    { name = "2002", path = "Fonts\\2002.TTF" },
    { name = "2002 Bold", path = "Fonts\\2002B.TTF" },
    { name = "Damage", path = "Fonts\\K_Damage.TTF" },
    { name = "Pagetext", path = "Fonts\\K_Pagetext.TTF" },
    { name = "AR Kai", path = "Fonts\\ARKai_T.ttf" },
    { name = "AR Kai Combat", path = "Fonts\\ARKai_C.ttf" },
    { name = "AR Hei", path = "Fonts\\ARHei.ttf" },
    { name = "bHEI00M", path = "Fonts\\bHEI00M.ttf" },
    { name = "bHEI01B", path = "Fonts\\bHEI01B.ttf" },
    { name = "bKAI00M", path = "Fonts\\bKAI00M.ttf" },
    { name = "bLEI00D", path = "Fonts\\bLEI00D.ttf" },
}

function ns.GetDefaultFontPath()
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- SetFont's return value is inconsistent across client versions, so success is
-- confirmed by reading the path back where possible. Newer clients may report
-- the applied font as a numeric file ID instead of a path, which cannot be
-- compared to the path string; in that case trust SetFont's boolean result.
function ns.TrySetFont(fontString, path, size, flags)
    if not path or path == "" then
        return false
    end
    local ok = fontString:SetFont(path, size, flags)
    local applied = fontString:GetFont()
    if type(applied) == "string" then
        return applied:lower() == path:lower()
    end
    if type(ok) == "boolean" then
        return ok
    end
    return applied ~= nil
end

local fontTester

function ns.GetAvailableFonts()
    fontTester = fontTester or UIParent:CreateFontString(nil, "BACKGROUND", "GameFontNormal")

    local fonts = { { name = "Default", path = "" } }
    local seen = {}
    local function AddFont(name, path)
        if not path or path == "" or seen[path:lower()] then
            return
        end
        if ns.TrySetFont(fontTester, path, 12, "") then
            seen[path:lower()] = true
            table.insert(fonts, { name = name, path = path })
        end
    end

    for _, candidate in ipairs(FONT_CANDIDATES) do
        AddFont(candidate.name, candidate.path)
    end

    local sharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)
    if sharedMedia then
        for _, name in ipairs(sharedMedia:List("font")) do
            AddFont(name, sharedMedia:Fetch("font", name, true))
        end
    end

    return fonts
end

function ns.GetFontDisplayName(path)
    if not path or path == "" then
        return "Default"
    end
    for _, font in ipairs(ns.GetAvailableFonts()) do
        if font.path == path then
            return font.name
        end
    end
    return path:match("([^\\/]+)$") or path
end

function ns.GetAttachmentFrame(frameName)
    return (frameName and _G[frameName]) or UIParent
end

function ns.CopyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            ns.CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns.CopyTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and ns.CopyTable(value) or value
    end
    return result
end

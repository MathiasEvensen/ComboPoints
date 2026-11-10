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
        -- Only reached when the game reports a maximum above 5 (rogue talents).
        [6] = { r = 0.1, g = 0.9, b = 0.2, a = 1 },
        [7] = { r = 0.1, g = 0.9, b = 0.2, a = 1 },
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
    configSize = { width = 520, height = 670 },
    snapToFrame = false,
    strata = "MEDIUM",
    onlyInCombat = false,
    onlySupportedSpecs = true,
    catFormAllSpecs = false,
    enabled = true,
}

-- x/y are bounded only to reject garbage: an offset a player set must never change.
ns.NUMBER_LIMITS = {
    pointWidth = { 8, 100 },
    pointHeight = { 8, 100 },
    spacing = { 0, 50 },
    borderSize = { 1, 8 },
    counterFontSize = { 6, 48 },
    counterOffsetX = { -200, 200 },
    counterOffsetY = { -200, 200 },
    x = { -10000, 10000 },
    y = { -10000, 10000 },
    width = { 500, 900 },
    height = { 670, 900 },
    r = { 0, 1 },
    g = { 0, 1 },
    b = { 0, 1 },
    a = { 0, 1 },
}

-- In the Attach tab's button order (rows of three).
ns.ANCHOR_POINTS = {
    { point = "TOPLEFT", label = "Top left" },
    { point = "TOP", label = "Top" },
    { point = "TOPRIGHT", label = "Top right" },
    { point = "LEFT", label = "Left" },
    { point = "CENTER", label = "Center" },
    { point = "RIGHT", label = "Right" },
    { point = "BOTTOMLEFT", label = "Bottom left" },
    { point = "BOTTOM", label = "Bottom" },
    { point = "BOTTOMRIGHT", label = "Bottom right" },
}

-- Levels above DIALOG are left out so the tracker can't cover fullscreen UI and tooltips.
ns.STRATA_LEVELS = {
    { value = "BACKGROUND", label = "Background" },
    { value = "LOW", label = "Low" },
    { value = "MEDIUM", label = "Medium" },
    { value = "HIGH", label = "High" },
    { value = "DIALOG", label = "Dialog" },
}

ns.db = nil
ns.tracker = nil
ns.configPanel = nil
ns.pointFrames = {}
ns.activePowerType = nil
ns.activePowerToken = nil
ns.currentCharacterKey = nil
ns.classFile = nil
-- Not InCombatLockdown(): it is still false while PLAYER_REGEN_DISABLED handlers run.
ns.inCombat = false
-- True while the attached frame does not exist yet.
ns.attachmentPending = false

-- A no-op until ConfigPanel.lua replaces it, so callers can invoke it unconditionally.
ns.UpdateConfigPreview = function() end

-- "" means the client's standard font. Each candidate is probed first: locale builds ship different subsets.

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

-- SetFont's return value varies by client version, so the path is read back where possible.
-- Newer clients may report a numeric file ID instead; then SetFont's boolean is trusted.
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
-- Only successes are cached: the first probe at login can fail before the client has loaded the file.
local confirmedFonts = {}

function ns.GetAvailableFonts()
    local sharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)
    fontTester = fontTester or UIParent:CreateFontString(nil, "BACKGROUND", "GameFontNormal")

    local fonts = { { name = "Default", path = "" } }
    local seen = {}
    local function AddFont(name, path)
        if not path or path == "" or seen[path:lower()] then
            return
        end
        local key = path:lower()
        if confirmedFonts[key] or ns.TrySetFont(fontTester, path, 12, "") then
            confirmedFonts[key] = true
            seen[key] = true
            table.insert(fonts, { name = name, path = path })
        end
    end

    for _, candidate in ipairs(FONT_CANDIDATES) do
        AddFont(candidate.name, candidate.path)
    end

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
    local frame = frameName and _G[frameName]
    if type(frame) ~= "table" or type(frame.GetObjectType) ~= "function" or type(frame.IsForbidden) ~= "function" then
        return nil
    end
    if frame:IsForbidden() then
        return nil
    end
    return frame
end

StaticPopupDialogs["COMBOPOINTS_CONFIRM"] = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, onAccept)
        onAccept()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.Confirm(text, onAccept)
    StaticPopup_Show("COMBOPOINTS_CONFIRM", text, nil, onAccept)
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

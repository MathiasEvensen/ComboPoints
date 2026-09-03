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
    position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -180, frameName = "UIParent" },
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

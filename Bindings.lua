local ADDON_NAME, ns = ...

local function ToggleConfig()
    ns.configPanel:SetShown(not ns.configPanel:IsShown())
end

SLASH_COMBOPOINTS1 = "/combopoints"
SLASH_COMBOPOINTS2 = "/cop"
SlashCmdList.COMBOPOINTS = function(message)
    message = message:lower():match("^%s*(.-)%s*$")
    if message == "unlock" then
        if ns.db.snapToFrame then
            print("Combo Points: detach from frame before free-moving tracker.")
            return
        end
        ns.tracker.isUnlocked = true
        ns.tracker:EnableMouse(true)
        print("Combo Points: position unlocked. Drag tracker, then use /cop lock.")
    elseif message == "lock" then
        ns.tracker.isUnlocked = false
        ns.tracker:EnableMouse(false)
        print("Combo Points: position locked.")
    elseif message == "resetpos" or message == "resetposition" then
        ns.ResetPosition()
        print("Combo Points: position reset.")
    elseif message == "reset" then
        ns.ResetCurrentProfile()
        print("Combo Points: defaults restored.")
        C_UI.Reload()
    elseif message == "toggle" or message == "on" or message == "off" then
        ns.db.enabled = message == "off" and false or (message == "on" or not ns.db.enabled)
        ns.UpdateTracker()
        print("Combo Points: " .. (ns.db.enabled and "enabled." or "disabled."))
    else
        ToggleConfig()
    end
end

ns.addon:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        local loadedAddon = unit
        if loadedAddon ~= ADDON_NAME then
            return
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        ns.LoadCharacterProfile()
        ns.CreateTracker()
        ns.CreateConfigPanel()
        ns.CreateSettingsCategory()
        return
    end

    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        if unit ~= "player" then
            return
        end
    end
    ns.UpdateTracker()
end)

ns.addon:RegisterEvent("ADDON_LOADED")
ns.addon:RegisterEvent("PLAYER_LOGIN")
ns.addon:RegisterEvent("PLAYER_ENTERING_WORLD")
ns.addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ns.addon:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
ns.addon:RegisterEvent("PLAYER_REGEN_DISABLED")
ns.addon:RegisterEvent("PLAYER_REGEN_ENABLED")
ns.addon:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
ns.addon:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")

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
        ns.SetTrackerUnlocked(true)
        print("Combo Points: position unlocked. Drag tracker, then use /cop lock.")
    elseif message == "lock" then
        ns.SetTrackerUnlocked(false)
        print("Combo Points: position locked.")
    elseif message == "resetpos" or message == "resetposition" then
        ns.Confirm("Reset the tracker position and detach it from its frame?", function()
            ns.ResetPosition()
            print("Combo Points: position reset.")
        end)
    elseif message == "resetconfigpos" or message == "resetconfigposition" then
        ns.Confirm("Reset the settings window's position and size?", function()
            ns.ResetConfigPosition()
            print("Combo Points: settings window position and size reset.")
        end)
    elseif message == "reset" then
        ns.Confirm("Reset all Combo Points settings for this character to defaults? This reloads the UI.", function()
            ns.ResetCurrentProfile()
            C_UI.Reload()
        end)
    elseif message == "toggle" or message == "on" or message == "off" then
        ns.db.enabled = message == "off" and false or (message == "on" or not ns.db.enabled)
        ns.UpdateTracker()
        print("Combo Points: " .. (ns.db.enabled and "enabled." or "disabled."))
    else
        ToggleConfig()
    end
end

-- Named in ComboPoints.toc.
function ComboPoints_OnAddonCompartmentClick()
    if ns.configPanel then
        ToggleConfig()
    end
end

ns.addon:SetScript("OnEvent", function(_, event, unit, powerToken)
    if event == "ADDON_LOADED" then
        -- Another addon may have just created the frame the tracker is attached to.
        if ns.attachmentPending and ns.tracker then
            ns.ApplyLayout()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        -- A reload in the middle of a fight gets no PLAYER_REGEN_DISABLED.
        ns.inCombat = (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
        ns.LoadCharacterProfile()
        ns.CreateTracker()
        ns.CreateConfigPanel()
        ns.CreateSettingsCategory()
        return
    end

    -- Fires for every power type (energy and mana tick constantly); only the tracked resource matters.
    if event == "UNIT_POWER_FREQUENT" and powerToken ~= ns.activePowerToken then
        return
    end

    -- Sizes are snapped to whole pixels, which depends on UI scale and resolution.
    if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        ns.ApplyLayout()
    end

    if event == "PLAYER_REGEN_DISABLED" then
        ns.inCombat = true
        if ns.configPanel and ns.configPanel.CancelFramePicker() then
            print("Combo Points: frame picking cancelled, entering combat.")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.inCombat = false
    elseif event == "PLAYER_ENTERING_WORLD" and ns.attachmentPending then
        ns.ApplyLayout()
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
ns.addon:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
ns.addon:RegisterUnitEvent("UNIT_MAXPOWER", "player")
ns.addon:RegisterEvent("PLAYER_TALENT_UPDATE")
ns.addon:RegisterEvent("UI_SCALE_CHANGED")
ns.addon:RegisterEvent("DISPLAY_SIZE_CHANGED")

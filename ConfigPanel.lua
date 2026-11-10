local ADDON_NAME, ns = ...
-- Widgets.lua must run before this file (see load order in ComboPoints.toc)
-- so ns.Widgets is already populated here.
local Widgets = ns.Widgets

-- Layout tab: size/spacing/shape, position reset, enable/combat/spec checks

local function BuildLayoutTab(configPanel, layoutPage)
    local enabledCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
    enabledCheck:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -14)
    enabledCheck.Text:SetText("Enable tracker")
    enabledCheck:SetChecked(ns.db.enabled)
    enabledCheck:SetScript("OnClick", function(self)
        ns.db.enabled = self:GetChecked() and true or false
        ns.UpdateTracker()
    end)

    Widgets.AddSlider(layoutPage, "Point width", "pointWidth", -48, 1)
    Widgets.AddSlider(layoutPage, "Point height", "pointHeight", -116, 1)
    Widgets.AddSlider(layoutPage, "Spacing", "spacing", -184, 1)

    local shapeButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    shapeButton:SetHeight(26)
    Widgets.PlaceInColumn(shapeButton, layoutPage, "left", -260)
    local function RefreshShapeText()
        shapeButton:SetText("Shape: " .. (ns.db.shape == "round" and "Round" or "Square"))
    end
    shapeButton:SetScript("OnClick", function()
        ns.db.shape = ns.db.shape == "round" and "square" or "round"
        RefreshShapeText()
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    RefreshShapeText()

    local unlockButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    unlockButton:SetHeight(26)
    Widgets.PlaceInColumn(unlockButton, layoutPage, "right", -260)
    local detachHint = layoutPage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    Widgets.PlaceInColumn(detachHint, layoutPage, "right", -290)
    detachHint:SetJustifyH("CENTER")
    detachHint:SetText("Attached to a frame. Open Attach, then choose Detach to screen to free-move.")
    configPanel.RefreshUnlockText = function()
        local canFreeMove = not ns.db.snapToFrame
        unlockButton:SetEnabled(canFreeMove)
        unlockButton:SetText(canFreeMove and (ns.tracker.isUnlocked and "Lock position" or "Unlock position") or "Detach to free-move")
        detachHint:SetShown(not canFreeMove)
    end
    unlockButton:SetScript("OnClick", function()
        if ns.db.snapToFrame then
            return
        end
        ns.SetTrackerUnlocked(not ns.tracker.isUnlocked)
    end)
    configPanel.RefreshUnlockText()

    local resetPositionButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    resetPositionButton:SetHeight(26)
    Widgets.PlaceInColumn(resetPositionButton, layoutPage, "left", -322)
    resetPositionButton:SetText("Reset position")
    resetPositionButton:SetScript("OnClick", function()
        ns.Confirm("Reset the tracker position and detach it from its frame?", function()
            ns.ResetPosition()
        end)
    end)

    local resetButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    resetButton:SetHeight(26)
    Widgets.PlaceInColumn(resetButton, layoutPage, "right", -322)
    resetButton:SetText("Reset all defaults")
    resetButton:SetScript("OnClick", function()
        ns.Confirm("Reset all Combo Points settings for this character to defaults? This reloads the UI.", function()
            ns.ResetCurrentProfile()
            C_UI.Reload()
        end)
    end)

    local combatOnlyCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
    combatOnlyCheck:SetPoint("TOPLEFT", layoutPage, "TOP", 0, -358)
    combatOnlyCheck.Text:SetText("Only show in combat")
    combatOnlyCheck:SetChecked(ns.db.onlyInCombat)
    combatOnlyCheck:SetScript("OnClick", function(self)
        ns.db.onlyInCombat = self:GetChecked() and true or false
        ns.UpdateTracker()
    end)

    -- Strata: which UI layer the tracker is drawn in, for when it ends up
    -- behind (or in front of) other frames.
    local strataLowerButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    strataLowerButton:SetSize(22, 22)
    strataLowerButton:SetPoint("TOPLEFT", layoutPage, "TOP", 0, -396)
    strataLowerButton:SetText("-")
    local strataRaiseButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    strataRaiseButton:SetSize(22, 22)
    strataRaiseButton:SetPoint("TOPRIGHT", layoutPage, "TOPRIGHT", -20, -396)
    strataRaiseButton:SetText("+")
    local strataLabel = layoutPage:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    strataLabel:SetPoint("LEFT", strataLowerButton, "RIGHT", 4, 0)
    strataLabel:SetPoint("RIGHT", strataRaiseButton, "LEFT", -4, 0)
    strataLabel:SetJustifyH("CENTER")
    strataLabel:SetWordWrap(false)
    local function GetStrataIndex()
        for index, level in ipairs(ns.STRATA_LEVELS) do
            if level.value == ns.db.strata then
                return index
            end
        end
        return 3
    end
    local function RefreshStrata()
        local index = GetStrataIndex()
        strataLabel:SetText("Strata: " .. ns.STRATA_LEVELS[index].label)
        strataLowerButton:SetEnabled(index > 1)
        strataRaiseButton:SetEnabled(index < #ns.STRATA_LEVELS)
    end
    local function StepStrata(step)
        local level = ns.STRATA_LEVELS[GetStrataIndex() + step]
        if level then
            ns.db.strata = level.value
            RefreshStrata()
            ns.ApplyLayout()
            ns.UpdateTracker()
        end
    end
    strataLowerButton:SetScript("OnClick", function()
        StepStrata(-1)
    end)
    strataRaiseButton:SetScript("OnClick", function()
        StepStrata(1)
    end)
    RefreshStrata()

    -- Non-Feral druids still build combo points in Cat Form (cat-weaving), but
    -- many only shift for travel speed, so this stays opt-in. It only narrows
    -- the usable-specs filter, so it is disabled while that filter is off.
    local catFormCheck
    if ns.classFile == "DRUID" then
        catFormCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
        catFormCheck:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -390)
        catFormCheck.Text:SetText("Show in Cat Form for all specs")
        catFormCheck:SetChecked(ns.db.catFormAllSpecs)
        catFormCheck:SetEnabled(ns.db.onlySupportedSpecs)
        catFormCheck:SetScript("OnClick", function(self)
            ns.db.catFormAllSpecs = self:GetChecked() and true or false
            ns.UpdateTracker()
        end)
    end

    local supportedSpecsCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
    supportedSpecsCheck:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -358)
    supportedSpecsCheck.Text:SetText("Only show usable specs")
    supportedSpecsCheck:SetChecked(ns.db.onlySupportedSpecs)
    supportedSpecsCheck:SetScript("OnClick", function(self)
        ns.db.onlySupportedSpecs = self:GetChecked() and true or false
        if catFormCheck then
            catFormCheck:SetEnabled(ns.db.onlySupportedSpecs)
        end
        ns.UpdateTracker()
    end)
end

-- Profiles tab: copy another character's settings onto the current one

local function BuildProfilesTab(configPanel, profilesPage)
    local profilesTitle = profilesPage:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    profilesTitle:SetPoint("TOPLEFT", profilesPage, "TOPLEFT", 10, -16)
    profilesTitle:SetText("Copy settings from another character")
    local profilesHelp = profilesPage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    profilesHelp:SetPoint("TOPLEFT", profilesTitle, "BOTTOMLEFT", 0, -8)
    profilesHelp:SetText("Choose a source profile, then copy its settings, frame attachment, and position.")

    local function GetSourceDisplayName(sourceKey)
        return sourceKey:match(" %- (.+)$") or sourceKey
    end

    local RefreshCopyControls
    local copySourceKey
    local copyDropdown = Widgets.AddScrollableDropdown(profilesPage, 10, -66, 236, {
        GetItems = function()
            local items = {}
            for _, sourceKey in ipairs(ns.GetOtherCharacterKeys()) do
                table.insert(items, { name = GetSourceDisplayName(sourceKey), value = sourceKey })
            end
            return items
        end,
        GetValue = function()
            return copySourceKey
        end,
        SetValue = function(sourceKey)
            copySourceKey = sourceKey
            RefreshCopyControls()
        end,
        GetDisplayName = function(sourceKey)
            if sourceKey then
                return GetSourceDisplayName(sourceKey)
            end
            return #ns.GetOtherCharacterKeys() == 0 and "No other character profiles" or "Choose source character"
        end,
    })

    local copyApplyButton = CreateFrame("Button", nil, profilesPage, "UIPanelButtonTemplate")
    copyApplyButton:SetSize(224, 26)
    copyApplyButton:SetPoint("LEFT", copyDropdown.frame, "RIGHT", 6, 0)
    copyApplyButton:SetText("Copy selected profile")

    RefreshCopyControls = function()
        local hasSources = #ns.GetOtherCharacterKeys() > 0
        copyDropdown:SetEnabled(hasSources)
        copyDropdown:Refresh()
        copyApplyButton:SetEnabled(hasSources and copySourceKey ~= nil)
    end
    copyApplyButton:SetScript("OnClick", function()
        local sourceKey = copySourceKey
        if not sourceKey then
            return
        end
        ns.Confirm("Replace this character's Combo Points settings with " .. GetSourceDisplayName(sourceKey) .. "'s? This reloads the UI.", function()
            if ns.CopyProfileToCurrent(sourceKey) then
                C_UI.Reload()
            end
        end)
    end)
    configPanel.ResetProfileSelection = function()
        copySourceKey = nil
        RefreshCopyControls()
    end
    configPanel:SetScript("OnHide", function()
        configPanel.ResetProfileSelection()
    end)
    RefreshCopyControls()

    local exportImportTitle = profilesPage:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    exportImportTitle:SetPoint("TOPLEFT", profilesPage, "TOPLEFT", 10, -180)
    exportImportTitle:SetText("Export / import profile string")

    local statusText = profilesPage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    statusText:SetPoint("TOPLEFT", exportImportTitle, "BOTTOMLEFT", 0, -6)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("Export copies current profile as text below. Paste text below, then Import to replace current profile.")

    local editBoxBg = CreateFrame("Frame", nil, profilesPage, "BackdropTemplate")
    editBoxBg:SetPoint("TOPLEFT", profilesPage, "TOPLEFT", 10, -228)
    editBoxBg:SetPoint("TOPRIGHT", profilesPage, "TOPRIGHT", 0, -228)
    editBoxBg:SetHeight(90)
    editBoxBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    editBoxBg:SetBackdropColor(0, 0, 0, 0.6)
    editBoxBg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, editBoxBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", editBoxBg, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", editBoxBg, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        ScrollingEdit_OnTextChanged(self, scrollFrame)
    end)
    editBox:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
    editBox:SetScript("OnUpdate", ScrollingEdit_OnUpdate)
    scrollFrame:SetScrollChild(editBox)

    local exportButton = CreateFrame("Button", nil, profilesPage, "UIPanelButtonTemplate")
    exportButton:SetHeight(26)
    Widgets.PlaceInColumn(exportButton, profilesPage, "left", -328)
    exportButton:SetText("Export current profile")
    exportButton:SetScript("OnClick", function()
        editBox:SetText(ns.SerializeProfile(ns.db))
        editBox:SetFocus()
        editBox:HighlightText()
        statusText:SetText("Profile text ready below. Press Ctrl+C to copy.")
    end)

    local importButton = CreateFrame("Button", nil, profilesPage, "UIPanelButtonTemplate")
    importButton:SetHeight(26)
    Widgets.PlaceInColumn(importButton, profilesPage, "right", -328)
    importButton:SetText("Import profile from text")
    importButton:SetScript("OnClick", function()
        local data = ns.DeserializeProfile(editBox:GetText())
        if not data then
            statusText:SetText("Import failed: pasted text is not a valid profile string.")
            return
        end
        ns.Confirm("Replace this character's Combo Points settings with the pasted profile? This reloads the UI.", function()
            if ns.ImportProfile(data) then
                C_UI.Reload()
            end
        end)
    end)

    table.insert(configPanel.widthReflows, function(extraWidth)
        copyDropdown:SetWidth(236 + extraWidth / 2)
        copyApplyButton:SetWidth(224 + extraWidth / 2)
        statusText:SetWidth(478 + extraWidth)
        editBox:SetWidth(442 + extraWidth)
    end)
end

-- Colors tab: static or per-point active colors, and the empty color

local function BuildColorsTab(configPanel, colorsPage)
    local colorModeButton = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
    colorModeButton:SetHeight(26)
    Widgets.PlaceInColumn(colorModeButton, colorsPage, "full", -14)
    local staticColorButton = Widgets.AddColorPickerButton(colorsPage, "Static active color", function() return ns.db.color end, -50, false, "left")
    Widgets.AddColorPickerButton(colorsPage, "Empty color", function() return ns.db.emptyColor end, -50, false, "right")
    local individualColorLabel = Widgets.AddLabel(colorsPage, "Individual active-point colors", 10, -92)
    local individualColorButtons = {}
    for index = 1, #ns.DEFAULTS.pointColors do
        local column = (index - 1) % 2 == 0 and "left" or "right"
        local row = math.floor((index - 1) / 2)
        individualColorButtons[index] = Widgets.AddColorPickerButton(colorsPage, "Point " .. index .. " color", function() return ns.db.pointColors[index] end, -116 - (row * 34), false, column)
    end
    local function RefreshColorMode()
        colorModeButton:SetText(ns.db.useIndividualColors and "Color mode: Individual" or "Color mode: One static color")
        staticColorButton:SetShown(not ns.db.useIndividualColors)
        staticColorButton.preview:SetShown(not ns.db.useIndividualColors)
        individualColorLabel:SetShown(ns.db.useIndividualColors)
        -- One button per point the character really has (ns.GetMaxPoints).
        local pointCount = ns.GetMaxPoints()
        for index, button in ipairs(individualColorButtons) do
            local shown = ns.db.useIndividualColors and index <= pointCount
            button:SetShown(shown)
            button.preview:SetShown(shown)
        end
    end
    -- Called by Tracker.lua when the character's maximum changes.
    configPanel.RefreshPointCount = RefreshColorMode
    colorModeButton:SetScript("OnClick", function()
        ns.db.useIndividualColors = not ns.db.useIndividualColors
        RefreshColorMode()
        ns.UpdateConfigPreview()
        ns.UpdateTracker()
    end)
    RefreshColorMode()
end

-- Style tab: background/border on-off and colors, border thickness

local function BuildStyleTab(configPanel, stylePage)
    local backgroundButton = CreateFrame("Button", nil, stylePage, "UIPanelButtonTemplate")
    backgroundButton:SetHeight(26)
    Widgets.PlaceInColumn(backgroundButton, stylePage, "left", -14)
    Widgets.AddColorPickerButton(stylePage, "Box background color", function() return ns.db.backgroundColor end, -14, true, "right")
    local function RefreshBackgroundText()
        backgroundButton:SetText(ns.db.showBackground and "Box background: On" or "Box background: Off")
    end
    backgroundButton:SetScript("OnClick", function()
        ns.db.showBackground = not ns.db.showBackground
        RefreshBackgroundText()
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    RefreshBackgroundText()

    local borderButton = CreateFrame("Button", nil, stylePage, "UIPanelButtonTemplate")
    borderButton:SetHeight(26)
    Widgets.PlaceInColumn(borderButton, stylePage, "left", -50)
    Widgets.AddColorPickerButton(stylePage, "Border color", function() return ns.db.borderColor end, -50, true, "right")
    local function RefreshBorderText()
        borderButton:SetText(ns.db.showBorder and "Border: On" or "Border: Off")
    end
    borderButton:SetScript("OnClick", function()
        ns.db.showBorder = not ns.db.showBorder
        RefreshBorderText()
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    RefreshBorderText()
    Widgets.AddSlider(stylePage, "Border thickness (pixels)", "borderSize", -108, 1)

    Widgets.AddLabel(stylePage, "Point counter", 10, -152)

    local counterButton = CreateFrame("Button", nil, stylePage, "UIPanelButtonTemplate")
    counterButton:SetHeight(26)
    Widgets.PlaceInColumn(counterButton, stylePage, "left", -176)
    Widgets.AddColorPickerButton(stylePage, "Counter color", function() return ns.db.counterColor end, -176, true, "right")

    local counterFormatButton = CreateFrame("Button", nil, stylePage, "UIPanelButtonTemplate")
    counterFormatButton:SetHeight(26)
    Widgets.PlaceInColumn(counterFormatButton, stylePage, "left", -212)

    local hideAtZeroCheck = CreateFrame("CheckButton", nil, stylePage, "UICheckButtonTemplate")
    hideAtZeroCheck:SetPoint("TOPLEFT", stylePage, "TOP", 0, -210)
    hideAtZeroCheck.Text:SetText("Hide counter at 0")
    hideAtZeroCheck:SetChecked(ns.db.counterHideAtZero)

    local RefreshCounterControls
    Widgets.AddLabel(stylePage, "Counter font", 10, -246)
    local outlineCheck = CreateFrame("CheckButton", nil, stylePage, "UICheckButtonTemplate")
    outlineCheck.Text:SetText("Outline counter")
    outlineCheck:SetChecked(ns.db.counterOutline)
    outlineCheck:SetScript("OnClick", function(self)
        ns.db.counterOutline = self:GetChecked() and true or false
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    local fontPicker = Widgets.AddScrollableDropdown(stylePage, 10, -268, 236, {
        GetItems = function()
            local items = {}
            for _, font in ipairs(ns.GetAvailableFonts()) do
                table.insert(items, { name = font.name, value = font.path, font = font.path })
            end
            return items
        end,
        GetValue = function()
            return ns.db.counterFont
        end,
        SetValue = function(fontPath)
            ns.db.counterFont = fontPath
            RefreshCounterControls()
            ns.ApplyLayout()
            ns.UpdateTracker()
        end,
        GetDisplayName = function(fontPath)
            return ns.GetFontDisplayName(fontPath)
        end,
    })

    outlineCheck:SetPoint("LEFT", fontPicker.frame, "RIGHT", 10, 0)

    RefreshCounterControls = function()
        counterButton:SetText(ns.db.showCounter and "Counter: On" or "Counter: Off")
        counterFormatButton:SetText(ns.db.counterShowMax and "Counter format: current/max" or "Counter format: current")
        counterFormatButton:SetEnabled(ns.db.showCounter)
        hideAtZeroCheck:SetEnabled(ns.db.showCounter)
        hideAtZeroCheck:SetChecked(ns.db.counterHideAtZero)
        fontPicker:SetEnabled(ns.db.showCounter)
        fontPicker:Refresh()
        outlineCheck:SetEnabled(ns.db.showCounter)
        outlineCheck:SetChecked(ns.db.counterOutline)
    end

    counterButton:SetScript("OnClick", function()
        ns.db.showCounter = not ns.db.showCounter
        RefreshCounterControls()
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    counterFormatButton:SetScript("OnClick", function()
        ns.db.counterShowMax = not ns.db.counterShowMax
        RefreshCounterControls()
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    hideAtZeroCheck:SetScript("OnClick", function(self)
        ns.db.counterHideAtZero = self:GetChecked() and true or false
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    RefreshCounterControls()

    Widgets.AddSlider(stylePage, "Counter font size", "counterFontSize", -308, 1)
    Widgets.AddSlider(stylePage, "Counter X offset", "counterOffsetX", -370, 1, "left")
    Widgets.AddSlider(stylePage, "Counter Y offset", "counterOffsetY", -370, 1, "right")

    table.insert(configPanel.widthReflows, function(extraWidth)
        fontPicker:SetWidth(236 + extraWidth / 2)
    end)
end

-- Attach tab: pick a UI frame to snap to, anchor point, offset sliders

local function BuildAttachTab(configPanel, attachPage)
    local RefreshAttachmentText
    local RefreshAnchorButtons
    local RefreshOffsetControls
    local attachHelp = Widgets.AddLabel(attachPage, "Click Pick frame, hover desired UI frame, then press Enter.", 10, -14)
    attachHelp:SetTextColor(1, 0.82, 0, 1)
    local selectedFrameLabel = Widgets.AddLabel(attachPage, "", 10, -48)
    local pickButton = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
    pickButton:SetHeight(30)
    Widgets.PlaceInColumn(pickButton, attachPage, "full", -78)
    local detachButton = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
    detachButton:SetHeight(26)
    Widgets.PlaceInColumn(detachButton, attachPage, "left", -120)
    detachButton:SetText("Detach to screen")
    detachButton:SetScript("OnClick", function()
        ns.db.snapToFrame = false
        ns.db.position.frameName = "UIParent"
        ns.ApplyLayout()
        ns.UpdateTracker()
        configPanel.RefreshUnlockText()
        RefreshAttachmentText()
    end)
    local attachResetPositionButton = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
    attachResetPositionButton:SetHeight(26)
    Widgets.PlaceInColumn(attachResetPositionButton, attachPage, "right", -120)
    attachResetPositionButton:SetText("Reset position")
    attachResetPositionButton:SetScript("OnClick", function()
        ns.Confirm("Reset the tracker position and detach it from its frame?", function()
            ns.ResetPosition()
        end)
    end)

    Widgets.AddLabel(attachPage, "Attach point", 10, -166)
    local anchorOptions = ns.ANCHOR_POINTS
    local anchorButtons = {}
    RefreshAnchorButtons = function()
        for index, option in ipairs(anchorOptions) do
            anchorButtons[index]:SetEnabled(ns.db.position.point ~= option.point or ns.db.position.relativePoint ~= option.point)
        end
    end
    for index, option in ipairs(anchorOptions) do
        local button = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
        button:SetHeight(24)
        button:SetText(option.label)
        button:SetScript("OnClick", function()
            ns.db.position.point = option.point
            ns.db.position.relativePoint = option.point
            ns.ApplyLayout()
            ns.UpdateTracker()
            RefreshAnchorButtons()
        end)
        anchorButtons[index] = button
    end
    RefreshAnchorButtons()
    table.insert(configPanel.widthReflows, function(extraWidth)
        local buttonWidth = 150 + extraWidth / 3
        for index, button in ipairs(anchorButtons) do
            local column = (index - 1) % 3
            local row = math.floor((index - 1) / 3)
            button:SetWidth(buttonWidth)
            button:SetPoint("TOPLEFT", attachPage, "TOPLEFT", 10 + (column * (buttonWidth + 6)), -188 - (row * 30))
        end
    end)

    Widgets.AddLabel(attachPage, "Offset from attach point", 10, -286)
    local xOffsetSlider = Widgets.AddPositionSlider(attachPage, "X offset", "x", -322, "left")
    local yOffsetSlider = Widgets.AddPositionSlider(attachPage, "Y offset", "y", -322, "right")
    RefreshOffsetControls = function()
        xOffsetSlider:RefreshPosition()
        yOffsetSlider:RefreshPosition()
    end
    -- Called by Tracker.lua after a drag or a position reset changes
    -- ns.db.position or ns.db.snapToFrame, so every control that shows them
    -- (here and the Layout tab's unlock button) is refreshed in one place.
    configPanel.RefreshPositionControls = function()
        RefreshAnchorButtons()
        RefreshOffsetControls()
        RefreshAttachmentText()
        configPanel.RefreshUnlockText()
    end

    local pickerHighlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    pickerHighlight:SetFrameStrata("TOOLTIP")
    pickerHighlight:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    pickerHighlight:SetBackdropBorderColor(1, 0.82, 0, 1)
    pickerHighlight:Hide()

    -- The tracker, the settings window, and anything inside them are not valid
    -- targets: anchoring the tracker to itself is an error, and the window's
    -- own controls are only on screen while it is open.
    local function IsOwnFrame(frame)
        return frame == configPanel or frame == ns.tracker or frame == pickerHighlight
    end

    -- Nearest named frame at or above the mouse focus. The whole parent chain
    -- is walked, and IsForbidden is checked before any other method: calling
    -- GetName or GetParent on a forbidden frame (some nameplates) is an error.
    local function GetNamedFrameUnderCursor()
        for _, focus in ipairs(GetMouseFoci()) do
            local frame, named, usable = focus, nil, true
            while frame do
                if frame:IsForbidden() or IsOwnFrame(frame) then
                    usable = false
                    break
                end
                if not named and frame:GetName() then
                    named = frame
                end
                frame = frame:GetParent()
            end
            if usable and named then
                return named
            end
        end
    end

    RefreshAttachmentText = function()
        local frameName = ns.db.position.frameName
        local attached = ns.db.snapToFrame and frameName ~= "UIParent"
        selectedFrameLabel:SetText(attached and "Attached to: " .. frameName or "Attached to: Screen")
    end

    local function StopFramePicker()
        configPanel.isPickingFrame = false
        pickerHighlight:Hide()
        pickButton:SetText("Pick frame")
    end
    -- Combat start and panel hide get no OnKeyUp to restore key propagation, so this does it.
    -- Bindings.lua calls it on PLAYER_REGEN_DISABLED, before lockdown blocks SetPropagateKeyboardInput.
    -- Returns true if a pick was in progress.
    configPanel.CancelFramePicker = function()
        local wasPicking = configPanel.isPickingFrame
        if wasPicking then
            StopFramePicker()
        end
        if not configPanel:GetPropagateKeyboardInput() then
            configPanel:SetPropagateKeyboardInput(true)
        end
        return wasPicking
    end
    configPanel:HookScript("OnHide", function()
        if configPanel.swallowingEscape then
            -- Closed by Esc: key propagation must stay off until the key event
            -- is over (see OnKeyDown), so only stop the picker here.
            if configPanel.isPickingFrame then
                StopFramePicker()
            end
        else
            configPanel.CancelFramePicker()
        end
    end)

    pickButton:SetText("Pick frame")
    pickButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            print("Combo Points: can't pick a frame in combat.")
            return
        end
        configPanel.isPickingFrame = true
        pickButton:SetText("Hover frame, then press Enter (Esc cancels)")
    end)
    configPanel:SetScript("OnUpdate", function()
        if not configPanel.isPickingFrame then
            return
        end
        local frame = GetNamedFrameUnderCursor()
        if frame then
            pickerHighlight:ClearAllPoints()
            pickerHighlight:SetAllPoints(frame)
            pickerHighlight:Show()
        else
            pickerHighlight:Hide()
        end
    end)
    local function IsPopupShown()
        for index = 1, STATICPOPUP_NUMDIALOGS or 4 do
            local popup = _G["StaticPopup" .. index]
            if popup and popup:IsShown() then
                return true
            end
        end
        return false
    end

    -- The player's own cast; pcall because cast info can be restricted.
    local function IsCasting()
        local ok, casting = pcall(function()
            return (UnitCastingInfo("player") or UnitChannelInfo("player")) and true or false
        end)
        return ok and casting
    end

    -- True when Esc should do its normal job instead of closing this window:
    --  * in combat, where the key can't be swallowed, so closing the window
    --    would also open the game menu or clear the target from one press;
    --  * while the game's Settings window or the game menu is open, so Esc
    --    closes that one;
    --  * while a popup (such as this addon's own confirmation) or the color
    --    picker is open, or a spell is being cast or targeted: the game gives
    --    all of those Esc before any window.
    local function EscapeBelongsElsewhere()
        return InCombatLockdown()
            or (SettingsPanel and SettingsPanel:IsShown())
            or (GameMenuFrame and GameMenuFrame:IsShown())
            or IsPopupShown()
            or (ColorPickerFrame and ColorPickerFrame:IsShown())
            or SpellIsTargeting()
            or IsCasting()
    end

    configPanel:EnableKeyboard(true)
    configPanel:SetPropagateKeyboardInput(true)
    configPanel:SetScript("OnKeyDown", function(self, key)
        if not configPanel.isPickingFrame then
            -- Esc closes this window, handled here rather than through
            -- UISpecialFrames: WoW closes all of those frames together, which
            -- closed this window whenever the game's Settings window closed.
            -- Esc is left alone, and this window stays open, whenever the
            -- key belongs to something else first (see EscapeBelongsElsewhere).
            if key ~= "ESCAPE" or EscapeBelongsElsewhere() then
                return
            end
            -- An open dropdown list takes Esc first; the window stays open,
            -- so OnKeyUp restores key propagation.
            if Widgets.CloseOpenDropdown() then
                self:SetPropagateKeyboardInput(false)
                return
            end
            -- Swallow the key so it doesn't also open the game menu. A
            -- hidden frame gets no OnKeyUp, so propagation is restored on
            -- the next frame (or by CancelFramePicker if combat starts first).
            self:SetPropagateKeyboardInput(false)
            configPanel.swallowingEscape = true
            C_Timer.After(0, function()
                configPanel.swallowingEscape = false
                if not InCombatLockdown() and not configPanel:GetPropagateKeyboardInput() then
                    configPanel:SetPropagateKeyboardInput(true)
                end
            end)
            self:Hide()
            return
        end
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            StopFramePicker()
            return
        end
        if key == "ENTER" or key == "SPACE" then
            self:SetPropagateKeyboardInput(false)
            local frame = GetNamedFrameUnderCursor()
            local frameName = frame and frame:GetName()
            if frameName then
                ns.db.position.frameName = frameName
                ns.db.position.x = 0
                ns.db.position.y = 0
                ns.db.snapToFrame = true
                ns.SetTrackerUnlocked(false)
                RefreshOffsetControls()
                ns.ApplyLayout()
                ns.UpdateTracker()
                RefreshAttachmentText()
                StopFramePicker()
            end
        end
    end)
    -- OnKeyDown swallows picker keys by turning propagation off; turn it back on once the key is released
    configPanel:SetScript("OnKeyUp", function(self)
        if not self:GetPropagateKeyboardInput() then
            self:SetPropagateKeyboardInput(true)
        end
    end)
    RefreshAttachmentText()
end

-- Live preview strip at the bottom of the panel (full/2-5/empty states)

local function BuildPreviewSection(configPanel)
    local preview = CreateFrame("Frame", nil, configPanel, "BackdropTemplate")
    preview:SetPoint("BOTTOMLEFT", configPanel, "BOTTOMLEFT", 16, 16)
    preview:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -40, 16)
    preview:SetHeight(120)
    preview:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    preview:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- The active count of "full" and "partial", and the "partial" label, are
    -- filled in from the character's real maximum on every redraw.
    local PREVIEW_POINTS = #ns.DEFAULTS.pointColors
    local previewStates = {
        { kind = "full", label = "Full", y = 34 },
        { kind = "partial", y = 0 },
        { kind = "empty", label = "Empty", active = 0, y = -34 },
    }
    local function PreviewPointCount()
        return math.min(ns.GetMaxPoints(), PREVIEW_POINTS)
    end
    for _, state in ipairs(previewStates) do
        state.labelFrame = preview:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        state.labelFrame:SetPoint("LEFT", preview, "LEFT", 8, state.y)
        state.labelFrame:SetText(state.label or "")
        state.points = {}
        for index = 1, PREVIEW_POINTS do
            state.points[index] = ns.CreatePointFrame(preview)
        end
        state.counter = ns.CreateCounterText(preview)
    end

    -- Room for the points next to the labels, and the width of the points at full size.
    local function PreviewWidths(db)
        local pointCount = PreviewPointCount()
        local fullWidth = (math.min(db.pointWidth, 32) * pointCount) + (math.min(db.spacing, 8) * (pointCount - 1))
        return preview:GetWidth() - 88, fullWidth
    end

    local previewScaled = false
    local function UpdateConfigPreview()
        local db = ns.db
        local pointCount = PreviewPointCount()
        local maxWidth, totalWidth = PreviewWidths(db)
        local pointWidth = math.min(db.pointWidth, 32)
        local pointHeight = math.min(db.pointHeight, 22)
        local spacing = math.min(db.spacing, 8)
        local scale = 1
        previewScaled = totalWidth > maxWidth
        if totalWidth > maxWidth then
            scale = maxWidth / totalWidth
            pointWidth = pointWidth * scale
            pointHeight = pointHeight * scale
            spacing = spacing * scale
            totalWidth = (pointWidth * pointCount) + (spacing * (pointCount - 1))
        end

        local counterFontSize = math.max(6, math.min(db.counterFontSize, 22) * scale)
        local counterX = 78 + (totalWidth / 2) + (db.counterOffsetX * scale)

        pointWidth = ns.SnapToPixels(pointWidth, preview, 1)
        pointHeight = ns.SnapToPixels(pointHeight, preview, 1)
        local borderInset = ns.GetBorderInset(db, pointWidth, pointHeight, preview)
        spacing = ns.SnapToPixels(spacing, preview)
        local isRound = db.shape == "round"
        for _, state in ipairs(previewStates) do
            if state.kind == "full" then
                state.active = pointCount
            elseif state.kind == "partial" then
                state.active = math.min(2, pointCount)
                state.labelFrame:SetText(state.active .. " / " .. pointCount)
            end
            for index, point in ipairs(state.points) do
                point:SetShown(index <= pointCount)
                point:SetSize(pointWidth, pointHeight)
                ns.StylePointFrame(point, db, borderInset, isRound)
                ns.SetPointVisual(point, index <= state.active, index)

                point:ClearAllPoints()
                if index == 1 then
                    point:SetPoint("LEFT", preview, "LEFT", 78, state.y)
                else
                    point:SetPoint("LEFT", state.points[index - 1], "RIGHT", spacing, 0)
                end
            end

            ns.StyleCounterText(state.counter, db, counterFontSize)
            state.counter:SetText(ns.FormatCounterText(db, state.active, pointCount))
            state.counter:SetShown(ns.ShouldShowCounter(db, state.active))
            state.counter:ClearAllPoints()
            state.counter:SetPoint("CENTER", preview, "LEFT", counterX, state.y + (db.counterOffsetY * scale))
        end
    end

    ns.UpdateConfigPreview = UpdateConfigPreview
    -- OnSizeChanged fires every frame while the window is resized. The preview's layout only
    -- depends on its width while that is too narrow for the points (they scale down), so it
    -- is redrawn only then, and once more when it stops being too narrow. The preview spans
    -- the window, so this also covers the window's own size changes.
    preview:SetScript("OnSizeChanged", function()
        local maxWidth, totalWidth = PreviewWidths(ns.db)
        if previewScaled or totalWidth > maxWidth then
            UpdateConfigPreview()
        end
    end)
    UpdateConfigPreview()
end

-- Panel frame itself: chrome, tabs/pages, wires the sections above together

local DEFAULT_WIDTH, DEFAULT_HEIGHT = 520, 670
local MIN_WIDTH, MAX_WIDTH = unpack(ns.NUMBER_LIMITS.width)
local MIN_HEIGHT, MAX_HEIGHT = unpack(ns.NUMBER_LIMITS.height)

local function ApplyConfigGeometry()
    local size = ns.db.configSize
    local width = math.min(MAX_WIDTH, math.max(MIN_WIDTH, tonumber(size.width) or DEFAULT_WIDTH))
    local height = math.min(MAX_HEIGHT, math.max(MIN_HEIGHT, tonumber(size.height) or DEFAULT_HEIGHT))
    local position = ns.db.configPosition
    ns.configPanel:SetSize(width, height)
    ns.configPanel:ClearAllPoints()
    ns.configPanel:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

function ns.ResetConfigPosition()
    ns.db.configPosition = ns.CopyTable(ns.DEFAULTS.configPosition)
    ns.db.configSize = ns.CopyTable(ns.DEFAULTS.configSize)
    if ns.configPanel then
        ApplyConfigGeometry()
    end
end

function ns.CreateConfigPanel()
    local configPanel = CreateFrame("Frame", ADDON_NAME .. "Config", UIParent, "BackdropTemplate")
    ns.configPanel = configPanel
    configPanel.widthReflows = {}
    configPanel:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    configPanel:SetResizable(true)
    configPanel:SetClampedToScreen(true)
    ApplyConfigGeometry()
    configPanel:SetMovable(true)
    configPanel:EnableMouse(true)
    configPanel:RegisterForDrag("LeftButton")
    configPanel:SetScript("OnDragStart", configPanel.StartMoving)
    local function SaveConfigGeometry()
        -- WoW's layout cache would otherwise restore its own copy of the position at login.
        configPanel:SetUserPlaced(false)
        local point, _, relativePoint, x, y = configPanel:GetPoint()
        ns.db.configPosition = { point = point, relativePoint = relativePoint, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
        ns.db.configSize = { width = math.floor(configPanel:GetWidth() + 0.5), height = math.floor(configPanel:GetHeight() + 0.5) }
    end
    configPanel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveConfigGeometry()
    end)
    -- Below DIALOG, so confirmation popups and the color picker open on top of it.
    configPanel:SetFrameStrata("HIGH")
    -- Deliberately not in UISpecialFrames: WoW closes every frame listed there
    -- together, so closing the game's Settings window would close this one too.
    -- Esc is handled in the window's own OnKeyDown (BuildAttachTab) instead.
    configPanel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    configPanel:SetBackdropColor(0, 0, 0, 0.95)

    local title = configPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Combo Points")

    local close = CreateFrame("Button", nil, configPanel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local resizeGrip = CreateFrame("Button", nil, configPanel)
    resizeGrip:SetSize(24, 24)
    resizeGrip:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -6, 6)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function()
        configPanel:StartSizing("BOTTOMRIGHT", true)
        local focus = GetCurrentKeyBoardFocus()
        if focus then
            focus:ClearFocus()
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        configPanel:StopMovingOrSizing()
        SaveConfigGeometry()
    end)

    local pages = {}
    local tabs = {}
    local function CreatePage(name)
        local page = CreateFrame("Frame", nil, configPanel)
        page:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 16, -72)
        page:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -16, 156)
        page:Hide()
        pages[name] = page
        return page
    end

    local function ShowPage(name)
        for pageName, page in pairs(pages) do
            page:SetShown(pageName == name)
        end
        for pageName, tab in pairs(tabs) do
            tab:SetEnabled(pageName ~= name)
        end
    end

    local function CreateTab(name, text, x, width)
        local tab = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
        tab:SetSize(width or 116, 24)
        tab:SetPoint("TOPLEFT", configPanel, "TOPLEFT", x, -42)
        tab:SetText(text)
        tab:SetScript("OnClick", function()
            ShowPage(name)
        end)
        tabs[name] = tab
    end

    BuildLayoutTab(configPanel, CreatePage("layout"))
    BuildProfilesTab(configPanel, CreatePage("profiles"))
    BuildColorsTab(configPanel, CreatePage("colors"))
    BuildStyleTab(configPanel, CreatePage("style"))
    BuildAttachTab(configPanel, CreatePage("attach"))
    BuildPreviewSection(configPanel)

    CreateTab("layout", "Layout", 16, 92)
    CreateTab("colors", "Colors", 112, 92)
    CreateTab("style", "Style", 208, 92)
    CreateTab("attach", "Attach", 304, 92)
    CreateTab("profiles", "Profiles", 400, 92)
    ShowPage("layout")

    local reflowedWidth
    local function ReflowWidth()
        local width = math.floor(configPanel:GetWidth() + 0.5)
        if width == reflowedWidth then
            return
        end
        reflowedWidth = width
        for _, reflow in ipairs(configPanel.widthReflows) do
            reflow(width - DEFAULT_WIDTH)
        end
    end
    configPanel:SetScript("OnSizeChanged", ReflowWidth)
    ReflowWidth()
    configPanel:Hide()
end

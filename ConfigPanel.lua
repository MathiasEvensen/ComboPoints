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

    Widgets.AddSlider(layoutPage, "Point width", "pointWidth", -48, 8, 100, 1, 10, 468)
    Widgets.AddSlider(layoutPage, "Point height", "pointHeight", -116, 8, 100, 1, 10, 468)
    Widgets.AddSlider(layoutPage, "Spacing", "spacing", -184, 0, 50, 1, 10, 468)

    local shapeButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    shapeButton:SetSize(224, 26)
    shapeButton:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -260)
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
    unlockButton:SetSize(224, 26)
    unlockButton:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 244, -260)
    local detachHint = layoutPage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    detachHint:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 244, -290)
    detachHint:SetWidth(224)
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
        ns.tracker.isUnlocked = not ns.tracker.isUnlocked
        ns.tracker:EnableMouse(ns.tracker.isUnlocked)
        configPanel.RefreshUnlockText()
    end)
    configPanel.RefreshUnlockText()

    local resetPositionButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    resetPositionButton:SetSize(224, 26)
    resetPositionButton:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -322)
    resetPositionButton:SetText("Reset position")
    resetPositionButton:SetScript("OnClick", function()
        ns.ResetPosition()
        configPanel.RefreshUnlockText()
    end)

    local resetButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    resetButton:SetSize(224, 26)
    resetButton:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 244, -322)
    resetButton:SetText("Reset all defaults")
    resetButton:SetScript("OnClick", function()
        ns.ResetCurrentProfile()
        C_UI.Reload()
    end)

    local combatOnlyCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
    combatOnlyCheck:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 244, -358)
    combatOnlyCheck.Text:SetText("Only show in combat")
    combatOnlyCheck:SetChecked(ns.db.onlyInCombat)
    combatOnlyCheck:SetScript("OnClick", function(self)
        ns.db.onlyInCombat = self:GetChecked() and true or false
        ns.UpdateTracker()
    end)

    local supportedSpecsCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
    supportedSpecsCheck:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -358)
    supportedSpecsCheck.Text:SetText("Only show usable specs")
    supportedSpecsCheck:SetChecked(ns.db.onlySupportedSpecs)
    supportedSpecsCheck:SetScript("OnClick", function(self)
        ns.db.onlySupportedSpecs = self:GetChecked() and true or false
        ns.UpdateTracker()
    end)
end

-- === Profiles tab: copy another character's settings onto the current one ===

local function BuildProfilesTab(configPanel, profilesPage)
    local profilesTitle = profilesPage:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    profilesTitle:SetPoint("TOPLEFT", profilesPage, "TOPLEFT", 10, -16)
    profilesTitle:SetText("Copy settings from another character")
    local profilesHelp = profilesPage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    profilesHelp:SetPoint("TOPLEFT", profilesTitle, "BOTTOMLEFT", 0, -8)
    profilesHelp:SetText("Choose a source profile, then copy its settings, frame attachment, and position.")

    local copyDropdown = CreateFrame("Frame", ADDON_NAME .. "CopyProfileDropdown", profilesPage, "UIDropDownMenuTemplate")
    copyDropdown:SetPoint("TOPLEFT", profilesPage, "TOPLEFT", -6, -64)
    UIDropDownMenu_SetWidth(copyDropdown, 218)
    UIDropDownMenu_SetText(copyDropdown, "Choose source character")

    local copyApplyButton = CreateFrame("Button", nil, profilesPage, "UIPanelButtonTemplate")
    copyApplyButton:SetSize(224, 26)
    copyApplyButton:SetPoint("TOPLEFT", profilesPage, "TOPLEFT", 244, -72)
    copyApplyButton:SetText("Copy selected profile")

    local copySourceKeys = {}
    local copySourceIndex
    local function GetSourceDisplayName(sourceKey)
        return sourceKey:match(" %- (.+)$") or sourceKey
    end
    local function RefreshCopyControls()
        copySourceKeys = ns.GetOtherCharacterKeys()
        if #copySourceKeys == 0 then
            UIDropDownMenu_SetText(copyDropdown, "No other character profiles")
            copyDropdown.Button:SetEnabled(false)
            copyApplyButton:SetEnabled(false)
            return
        end

        copyDropdown.Button:SetEnabled(true)
        if copySourceIndex and copySourceKeys[copySourceIndex] then
            UIDropDownMenu_SetText(copyDropdown, GetSourceDisplayName(copySourceKeys[copySourceIndex]))
            copyApplyButton:SetEnabled(true)
        else
            UIDropDownMenu_SetText(copyDropdown, "Choose source character")
            copyApplyButton:SetEnabled(false)
        end

        UIDropDownMenu_Initialize(copyDropdown, function(_, level)
            if level ~= 1 then
                return
            end
            for index, sourceKey in ipairs(copySourceKeys) do
                local sourceIndex = index
                local info = UIDropDownMenu_CreateInfo()
                info.text = GetSourceDisplayName(sourceKey)
                info.checked = copySourceIndex == sourceIndex
                info.func = function()
                    copySourceIndex = sourceIndex
                    RefreshCopyControls()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end
    copyApplyButton:SetScript("OnClick", function()
        if copySourceIndex and ns.CopyProfileToCurrent(copySourceKeys[copySourceIndex]) then
            ns.ApplyLayout()
            ns.UpdateTracker()
            C_UI.Reload()
        end
    end)
    configPanel.ResetProfileSelection = function()
        copySourceIndex = nil
        RefreshCopyControls()
    end
    configPanel:SetScript("OnHide", function()
        CloseDropDownMenus()
        configPanel.ResetProfileSelection()
    end)
    RefreshCopyControls()
end

-- === Colors tab: static or per-point active colors, and the empty color ===

local function BuildColorsTab(configPanel, colorsPage)
    local colorModeButton = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
    colorModeButton:SetSize(468, 26)
    colorModeButton:SetPoint("TOPLEFT", colorsPage, "TOPLEFT", 10, -14)
    local staticColorButton = Widgets.AddColorPickerButton(colorsPage, "Static active color", ns.db.color, -50, false, 10, 200)
    Widgets.AddColorPickerButton(colorsPage, "Empty color", ns.db.emptyColor, -50, false, 244, 200)
    local individualColorLabel = Widgets.AddLabel(colorsPage, "Individual active-point colors", 10, -92)
    local individualColorButtons = {}
    for index = 1, 5 do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        individualColorButtons[index] = Widgets.AddColorPickerButton(colorsPage, "Point " .. index .. " color", ns.db.pointColors[index], -116 - (row * 34), false, 10 + (column * 234), 200)
    end
    local function RefreshColorMode()
        colorModeButton:SetText(ns.db.useIndividualColors and "Color mode: Individual" or "Color mode: One static color")
        staticColorButton:SetShown(not ns.db.useIndividualColors)
        staticColorButton.preview:SetShown(not ns.db.useIndividualColors)
        individualColorLabel:SetShown(ns.db.useIndividualColors)
        for _, button in ipairs(individualColorButtons) do
            button:SetShown(ns.db.useIndividualColors)
            button.preview:SetShown(ns.db.useIndividualColors)
        end
    end
    colorModeButton:SetScript("OnClick", function()
        ns.db.useIndividualColors = not ns.db.useIndividualColors
        RefreshColorMode()
        ns.UpdateConfigPreview()
        ns.UpdateTracker()
    end)
    RefreshColorMode()
end

-- === Style tab: background/border on-off and colors, border thickness ===

local function BuildStyleTab(configPanel, stylePage)
    local backgroundButton = CreateFrame("Button", nil, stylePage, "UIPanelButtonTemplate")
    backgroundButton:SetSize(224, 26)
    backgroundButton:SetPoint("TOPLEFT", stylePage, "TOPLEFT", 10, -14)
    Widgets.AddColorPickerButton(stylePage, "Box background color", ns.db.backgroundColor, -14, true, 244, 200)
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
    borderButton:SetSize(224, 26)
    borderButton:SetPoint("TOPLEFT", stylePage, "TOPLEFT", 10, -50)
    Widgets.AddColorPickerButton(stylePage, "Border color", ns.db.borderColor, -50, true, 244, 200)
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
    Widgets.AddSlider(stylePage, "Border thickness", "borderSize", -108, 1, 8, 1, 10, 468)
end

-- === Attach tab: pick a UI frame to snap to, anchor point, offset sliders ===

local function BuildAttachTab(configPanel, attachPage)
    local RefreshAttachmentText
    local RefreshAnchorButtons
    local RefreshOffsetControls
    local attachHelp = Widgets.AddLabel(attachPage, "Click Pick frame, hover desired UI frame, then press Enter.", 10, -14)
    attachHelp:SetTextColor(1, 0.82, 0, 1)
    local selectedFrameLabel = Widgets.AddLabel(attachPage, "", 10, -48)
    local pickButton = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
    pickButton:SetSize(468, 30)
    pickButton:SetPoint("TOPLEFT", attachPage, "TOPLEFT", 10, -78)
    local detachButton = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
    detachButton:SetSize(224, 26)
    detachButton:SetPoint("TOPLEFT", attachPage, "TOPLEFT", 10, -120)
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
    attachResetPositionButton:SetSize(224, 26)
    attachResetPositionButton:SetPoint("TOPLEFT", attachPage, "TOPLEFT", 244, -120)
    attachResetPositionButton:SetText("Reset position")
    attachResetPositionButton:SetScript("OnClick", function()
        ns.ResetPosition()
        configPanel.RefreshUnlockText()
        RefreshAttachmentText()
        RefreshAnchorButtons()
        RefreshOffsetControls()
    end)

    Widgets.AddLabel(attachPage, "Attach point", 10, -166)
    local anchorOptions = {
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
    local anchorButtons = {}
    RefreshAnchorButtons = function()
        for index, option in ipairs(anchorOptions) do
            anchorButtons[index]:SetEnabled(ns.db.position.point ~= option.point or ns.db.position.relativePoint ~= option.point)
        end
    end
    for index, option in ipairs(anchorOptions) do
        local column = (index - 1) % 3
        local row = math.floor((index - 1) / 3)
        local button = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
        button:SetSize(150, 24)
        button:SetPoint("TOPLEFT", attachPage, "TOPLEFT", 10 + (column * 156), -188 - (row * 30))
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

    Widgets.AddLabel(attachPage, "Frame-relative offset", 10, -286)
    local xOffsetSlider = Widgets.AddPositionSlider(attachPage, "X offset", "x", -310, 10, 224)
    local yOffsetSlider = Widgets.AddPositionSlider(attachPage, "Y offset", "y", -310, 244, 224)
    RefreshOffsetControls = function()
        xOffsetSlider:RefreshPosition()
        yOffsetSlider:RefreshPosition()
    end

    local pickerHighlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    pickerHighlight:SetFrameStrata("TOOLTIP")
    pickerHighlight:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    pickerHighlight:SetBackdropBorderColor(1, 0.82, 0, 1)
    pickerHighlight:Hide()

    local function GetNamedFrameUnderCursor()
        for _, focus in ipairs(GetMouseFoci()) do
            local frame = focus
            while frame and not frame:GetName() do
                frame = frame:GetParent()
            end
            if frame and frame ~= configPanel and frame ~= pickerHighlight then
                return frame
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

    pickButton:SetText("Pick frame")
    pickButton:SetScript("OnClick", function()
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
    configPanel:EnableKeyboard(true)
    configPanel:SetScript("OnKeyDown", function(_, key)
        if not configPanel.isPickingFrame then
            return
        end
        if key == "ESCAPE" then
            StopFramePicker()
            return
        end
        if key == "ENTER" or key == "SPACE" then
            local frame = GetNamedFrameUnderCursor()
            local frameName = frame and frame:GetName()
            if frameName then
                ns.db.position.frameName = frameName
                ns.db.position.x = 0
                ns.db.position.y = 0
                ns.db.snapToFrame = true
                ns.tracker.isUnlocked = false
                ns.tracker:EnableMouse(false)
                configPanel.RefreshUnlockText()
                RefreshOffsetControls()
                ns.ApplyLayout()
                ns.UpdateTracker()
                RefreshAttachmentText()
                StopFramePicker()
            end
        end
    end)
    RefreshAttachmentText()
end

-- === Live preview strip at the bottom of the panel (full/2-5/empty states) ===

local function BuildPreviewSection(configPanel)
    local preview = CreateFrame("Frame", nil, configPanel, "BackdropTemplate")
    preview:SetPoint("BOTTOMLEFT", configPanel, "BOTTOMLEFT", 16, 16)
    preview:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -40, 16)
    preview:SetHeight(120)
    preview:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    preview:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local previewStates = {
        { label = "Full", active = 5, y = 34 },
        { label = "2 / 5", active = 2, y = 0 },
        { label = "Empty", active = 0, y = -34 },
    }
    for _, state in ipairs(previewStates) do
        state.labelFrame = preview:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        state.labelFrame:SetPoint("LEFT", preview, "LEFT", 8, state.y)
        state.labelFrame:SetText(state.label)
        state.points = {}
        for index = 1, 5 do
            state.points[index] = ns.CreatePointFrame(preview)
        end
    end

    local function UpdateConfigPreview()
        local db = ns.db
        local maxWidth = preview:GetWidth() - 88
        local pointWidth = math.min(db.pointWidth, 32)
        local pointHeight = math.min(db.pointHeight, 22)
        local spacing = math.min(db.spacing, 8)
        local totalWidth = (pointWidth * 5) + (spacing * 4)
        if totalWidth > maxWidth then
            local scale = maxWidth / totalWidth
            pointWidth = pointWidth * scale
            pointHeight = pointHeight * scale
            spacing = spacing * scale
        end

        local borderInset = db.showBorder and math.min(db.borderSize, math.floor(math.min(pointWidth, pointHeight) / 3)) or 0
        local isRound = db.shape == "round"
        for _, state in ipairs(previewStates) do
            for index, point in ipairs(state.points) do
                point:SetSize(pointWidth, pointHeight)
                ns.StylePointFrame(point, db, borderInset, borderInset, isRound)
                ns.SetPointVisual(point, index <= state.active, index)

                point:ClearAllPoints()
                if index == 1 then
                    point:SetPoint("LEFT", preview, "LEFT", 78, state.y)
                else
                    point:SetPoint("LEFT", state.points[index - 1], "RIGHT", spacing, 0)
                end
            end
        end
    end

    ns.UpdateConfigPreview = UpdateConfigPreview
    preview:SetScript("OnSizeChanged", UpdateConfigPreview)
    configPanel:SetScript("OnSizeChanged", UpdateConfigPreview)
    UpdateConfigPreview()
end

-- === Panel frame itself: chrome, tabs/pages, wires the sections above together ===

function ns.CreateConfigPanel()
    local configPanel = CreateFrame("Frame", ADDON_NAME .. "Config", UIParent, "BackdropTemplate")
    ns.configPanel = configPanel
    configPanel:SetSize(520, 610)
    configPanel:SetResizeBounds(500, 610, 900, 900)
    configPanel:SetResizable(true)
    configPanel:SetPoint("CENTER")
    configPanel:SetMovable(true)
    configPanel:EnableMouse(true)
    configPanel:RegisterForDrag("LeftButton")
    configPanel:SetScript("OnDragStart", configPanel.StartMoving)
    configPanel:SetScript("OnDragStop", configPanel.StopMovingOrSizing)
    configPanel:SetFrameStrata("DIALOG")
    configPanel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    configPanel:SetBackdropColor(0, 0, 0, 0.9)

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
        configPanel:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        configPanel:StopMovingOrSizing()
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
    configPanel:Hide()
end

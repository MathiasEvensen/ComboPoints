local ADDON_NAME = ...
local addon = CreateFrame("Frame")

local DEFAULTS = {
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

local db
local tracker
local configPanel
local pointFrames = {}
local activePowerType
local UpdateConfigPreview
local currentCharacterKey

local function GetAttachmentFrame(frameName)
    return (frameName and _G[frameName]) or UIParent
end

local function CopyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function CopyTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and CopyTable(value) or value
    end
    return result
end

local function GetCharacterKey()
    local name, realm = UnitFullName("player")
    return (realm or GetRealmName() or "Unknown") .. " - " .. (name or UnitName("player") or "Unknown")
end

local function LoadCharacterProfile()
    currentCharacterKey = GetCharacterKey()
    ComboPointsDB = ComboPointsDB or {}
    if not ComboPointsDB.profiles then
        local legacySettings = CopyTable(ComboPointsDB)
        ComboPointsDB = { version = 2, profiles = { [currentCharacterKey] = legacySettings } }
    end

    db = ComboPointsDB.profiles[currentCharacterKey] or {}
    ComboPointsDB.profiles[currentCharacterKey] = db
    CopyDefaults(DEFAULTS, db)
end

local function ResetCurrentProfile()
    db = {}
    ComboPointsDB.profiles[currentCharacterKey] = db
    CopyDefaults(DEFAULTS, db)
end

local function GetOtherCharacterKeys()
    local keys = {}
    for key in pairs(ComboPointsDB.profiles) do
        if key ~= currentCharacterKey then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

local function CopyProfileToCurrent(sourceKey)
    local source = ComboPointsDB.profiles[sourceKey]
    if not source then
        return false
    end

    db = CopyTable(source)
    db.position = CopyTable(source.position or DEFAULTS.position)
    db.snapToFrame = source.snapToFrame == true
    ComboPointsDB.profiles[currentCharacterKey] = db
    CopyDefaults(DEFAULTS, db)
    return true
end

local function GetSpecializationID()
    local specialization = C_SpecializationInfo.GetSpecialization()
    if not specialization then
        return nil
    end
    return C_SpecializationInfo.GetSpecializationInfo(specialization)
end

local function IsTrackedClass()
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

local function GetPowerType()
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

local function SetPointVisual(point, active, index)
    local color = active and (db.useIndividualColors and db.pointColors[index] or db.color) or db.emptyColor
    point.texture:SetColorTexture(color.r, color.g, color.b, color.a)
end

local function ApplyLayout()
    if not tracker or not db then
        return
    end

    tracker:ClearAllPoints()
    local position = db.position
    local anchorFrame = db.snapToFrame and GetAttachmentFrame(position.frameName) or UIParent
    tracker:SetPoint(position.point, anchorFrame, position.relativePoint, position.x, position.y)

    local isRound = db.shape == "round"
    local borderInset = db.showBorder and db.borderSize or 0
    for index, point in ipairs(pointFrames) do
        point:SetSize(db.pointWidth, db.pointHeight)
        point:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = db.showBorder and "Interface\\Buttons\\WHITE8x8" or nil,
            edgeSize = db.borderSize,
            insets = { left = borderInset, right = borderInset, top = borderInset, bottom = borderInset },
        })
        local background = db.showBackground and db.backgroundColor or { r = 0, g = 0, b = 0, a = 0 }
        point:SetBackdropColor(background.r, background.g, background.b, background.a)
        point:SetBackdropBorderColor(db.borderColor.r, db.borderColor.g, db.borderColor.b, db.borderColor.a)
        if isRound and not point.isMasked then
            point.texture:AddMaskTexture(point.mask)
            point.isMasked = true
        elseif not isRound and point.isMasked then
            point.texture:RemoveMaskTexture(point.mask)
            point.isMasked = false
        end
        point.texture:ClearAllPoints()
        point.texture:SetPoint("TOPLEFT", point, "TOPLEFT", borderInset, -borderInset)
        point.texture:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -borderInset, borderInset)
        point.mask:ClearAllPoints()
        point.mask:SetPoint("TOPLEFT", point, "TOPLEFT", borderInset, -borderInset)
        point.mask:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -borderInset, borderInset)

        point:ClearAllPoints()
        if index == 1 then
            point:SetPoint("LEFT", tracker, "LEFT", 0, 0)
        else
            point:SetPoint("LEFT", pointFrames[index - 1], "RIGHT", db.spacing, 0)
        end
    end

    tracker:SetSize((db.pointWidth * #pointFrames) + (db.spacing * (#pointFrames - 1)), db.pointHeight)
    if UpdateConfigPreview then
        UpdateConfigPreview()
    end
end

local function UpdateTracker()
    if not tracker or not db then
        return
    end

    activePowerType = GetPowerType()
    local isSupportedSpec = IsTrackedClass()
    local shouldShow = db.enabled and activePowerType and (isSupportedSpec or not db.onlySupportedSpecs) and (not db.onlyInCombat or InCombatLockdown())
    if not shouldShow then
        tracker:Hide()
        return
    end

    local current = UnitPower("player", activePowerType)
    local maximum = math.min(UnitPowerMax("player", activePowerType), #pointFrames)
    for index, point in ipairs(pointFrames) do
        point:SetShown(index <= maximum)
        SetPointVisual(point, index <= current, index)
    end
    tracker:Show()
end

local function SavePosition()
    local point, _, relativePoint, x, y = tracker:GetPoint()
    db.position.point = point
    db.position.relativePoint = relativePoint
    db.position.x = math.floor(x + 0.5)
    db.position.y = math.floor(y + 0.5)
end

local function ResetPosition()
    db.position = {}
    CopyDefaults(DEFAULTS.position, db.position)
    db.snapToFrame = false
    ApplyLayout()
    UpdateTracker()
end

local function CreateTracker()
    tracker = CreateFrame("Frame", ADDON_NAME .. "Tracker", UIParent)
    tracker:SetMovable(true)
    tracker:EnableMouse(false)
    tracker:RegisterForDrag("LeftButton")
    tracker:SetScript("OnDragStart", function(self)
        if self.isUnlocked and not db.snapToFrame then
            self:StartMoving()
        end
    end)
    tracker:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    for index = 1, 10 do
        local point = CreateFrame("Frame", nil, tracker, "BackdropTemplate")
        point.texture = point:CreateTexture(nil, "ARTWORK")
        point.texture:SetAllPoints()
        point.mask = point:CreateMaskTexture()
        point.mask:SetAllPoints()
        point.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pointFrames[index] = point
    end

    ApplyLayout()
end

local function AddLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function AddSlider(parent, label, key, y, minValue, maxValue, step, x, width)
    x = x or 18
    width = width or (parent:GetWidth() - 36)
    AddLabel(parent, label, x, y)

    local valueLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueLabel:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    slider:SetWidth(width)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(db[key])
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor((value / step) + 0.5) * step
        db[key] = value
        valueLabel:SetText(string.format("%.0f", value))
        ApplyLayout()
        UpdateTracker()
    end)
    valueLabel:SetText(string.format("%.0f", db[key]))
    return slider
end

local function AddPositionSlider(parent, label, key, y, x, width)
    AddLabel(parent, label, x, y)

    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(54, 22)
    input:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y + 4)
    input:SetAutoFocus(false)
    input:SetText(string.format("%d", db.position[key]))

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    slider:SetWidth(width)
    slider:SetMinMaxValues(-500, 500)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(db.position[key])
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    local function SetPosition(value)
        value = math.max(-500, math.min(500, math.floor(value + (value >= 0 and 0.5 or -0.5))))
        db.position[key] = value
        input:SetText(string.format("%d", value))
        ApplyLayout()
        UpdateTracker()
    end

    slider:SetScript("OnValueChanged", function(_, value)
        SetPosition(value)
    end)
    input:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = math.max(-500, math.min(500, value))
            slider:SetValue(value)
        else
            self:SetText(string.format("%d", db.position[key]))
        end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:SetText(string.format("%d", db.position[key]))
        self:ClearFocus()
    end)
    slider.RefreshPosition = function()
        input:SetText(string.format("%d", db.position[key]))
        slider:SetValue(db.position[key])
    end
    return slider
end

local function AddColorPickerButton(parent, label, color, y, applyLayout, x, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    width = width or 180
    button:SetSize(width, 26)
    if x then
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    else
        button:SetPoint("TOP", parent, "TOP", 0, y)
    end
    button:SetText(label)

    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    preview:SetSize(26, 26)
    preview:SetPoint("LEFT", button, "RIGHT", 6, 0)
    preview:SetFrameLevel(button:GetFrameLevel() + 1)
    preview:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    preview:SetBackdropColor(0, 0, 0, 1)
    local previewColor = preview:CreateTexture(nil, "ARTWORK")
    previewColor:SetPoint("TOPLEFT", preview, "TOPLEFT", 3, -3)
    previewColor:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -3, 3)
    button.preview = preview
    button:SetScript("OnShow", function()
        preview:Show()
    end)
    button:SetScript("OnHide", function()
        preview:Hide()
    end)

    local function ApplyColor(r, g, b, a)
        color.r = r
        color.g = g
        color.b = b
        color.a = a or 1
        previewColor:SetColorTexture(color.r, color.g, color.b, color.a)
        if applyLayout then
            ApplyLayout()
        elseif UpdateConfigPreview then
            UpdateConfigPreview()
        end
        UpdateTracker()
    end

    ApplyColor(color.r, color.g, color.b, color.a)
    button:SetScript("OnClick", function()
        local previousValues = { r = color.r, g = color.g, b = color.b, a = color.a }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r,
            g = color.g,
            b = color.b,
            opacity = color.a,
            hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                ApplyColor(r, g, b, color.a)
            end,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                ApplyColor(r, g, b, ColorPickerFrame:GetColorAlpha())
            end,
            cancelFunc = function()
                ApplyColor(previousValues.r, previousValues.g, previousValues.b, previousValues.a)
            end,
        })
    end)
    return button
end

local function CreateConfigPanel()
    configPanel = CreateFrame("Frame", ADDON_NAME .. "Config", UIParent, "BackdropTemplate")
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

    local layoutPage = CreatePage("layout")
    AddSlider(layoutPage, "Point width", "pointWidth", -14, 8, 100, 1, 10, 468)
    AddSlider(layoutPage, "Point height", "pointHeight", -82, 8, 100, 1, 10, 468)
    AddSlider(layoutPage, "Spacing", "spacing", -150, 0, 50, 1, 10, 468)

    local shapeButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    shapeButton:SetSize(224, 26)
    shapeButton:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -226)
    local function RefreshShapeText()
        shapeButton:SetText("Shape: " .. (db.shape == "round" and "Round" or "Square"))
    end
    shapeButton:SetScript("OnClick", function()
        db.shape = db.shape == "round" and "square" or "round"
        RefreshShapeText()
        ApplyLayout()
        UpdateTracker()
    end)
    RefreshShapeText()

    local unlockButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    unlockButton:SetSize(224, 26)
    unlockButton:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 244, -226)
    local detachHint = layoutPage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    detachHint:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 244, -256)
    detachHint:SetWidth(224)
    detachHint:SetJustifyH("CENTER")
    detachHint:SetText("Attached to a frame. Open Attach, then choose Detach to screen to free-move.")
    configPanel.RefreshUnlockText = function()
        local canFreeMove = not db.snapToFrame
        unlockButton:SetEnabled(canFreeMove)
        unlockButton:SetText(canFreeMove and (tracker.isUnlocked and "Lock position" or "Unlock position") or "Detach to free-move")
        detachHint:SetShown(not canFreeMove)
    end
    unlockButton:SetScript("OnClick", function()
        if db.snapToFrame then
            return
        end
        tracker.isUnlocked = not tracker.isUnlocked
        tracker:EnableMouse(tracker.isUnlocked)
        configPanel.RefreshUnlockText()
    end)
    configPanel.RefreshUnlockText()

    local resetPositionButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    resetPositionButton:SetSize(224, 26)
    resetPositionButton:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -288)
    resetPositionButton:SetText("Reset position")
    resetPositionButton:SetScript("OnClick", function()
        ResetPosition()
        configPanel.RefreshUnlockText()
    end)

    local resetButton = CreateFrame("Button", nil, layoutPage, "UIPanelButtonTemplate")
    resetButton:SetSize(224, 26)
    resetButton:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 244, -288)
    resetButton:SetText("Reset all defaults")
    resetButton:SetScript("OnClick", function()
        ResetCurrentProfile()
        C_UI.Reload()
    end)

    local enabledCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
    enabledCheck:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -324)
    enabledCheck.Text:SetText("Enable tracker")
    enabledCheck:SetChecked(db.enabled)
    enabledCheck:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() and true or false
        UpdateTracker()
    end)

    local combatOnlyCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
    combatOnlyCheck:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 244, -324)
    combatOnlyCheck.Text:SetText("Only show in combat")
    combatOnlyCheck:SetChecked(db.onlyInCombat)
    combatOnlyCheck:SetScript("OnClick", function(self)
        db.onlyInCombat = self:GetChecked() and true or false
        UpdateTracker()
    end)

    local supportedSpecsCheck = CreateFrame("CheckButton", nil, layoutPage, "UICheckButtonTemplate")
    supportedSpecsCheck:SetPoint("TOPLEFT", layoutPage, "TOPLEFT", 10, -358)
    supportedSpecsCheck.Text:SetText("Only show usable specs")
    supportedSpecsCheck:SetChecked(db.onlySupportedSpecs)
    supportedSpecsCheck:SetScript("OnClick", function(self)
        db.onlySupportedSpecs = self:GetChecked() and true or false
        UpdateTracker()
    end)

    local profilesPage = CreatePage("profiles")
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
        copySourceKeys = GetOtherCharacterKeys()
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
        if copySourceIndex and CopyProfileToCurrent(copySourceKeys[copySourceIndex]) then
            ApplyLayout()
            UpdateTracker()
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

    local colorsPage = CreatePage("colors")
    local colorModeButton = CreateFrame("Button", nil, colorsPage, "UIPanelButtonTemplate")
    colorModeButton:SetSize(468, 26)
    colorModeButton:SetPoint("TOPLEFT", colorsPage, "TOPLEFT", 10, -14)
    local staticColorButton = AddColorPickerButton(colorsPage, "Static active color", db.color, -50, false, 10, 200)
    AddColorPickerButton(colorsPage, "Empty color", db.emptyColor, -50, false, 244, 200)
    local individualColorLabel = AddLabel(colorsPage, "Individual active-point colors", 10, -92)
    local individualColorButtons = {}
    for index = 1, 5 do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        individualColorButtons[index] = AddColorPickerButton(colorsPage, "Point " .. index .. " color", db.pointColors[index], -116 - (row * 34), false, 10 + (column * 234), 200)
    end
    local function RefreshColorMode()
        colorModeButton:SetText(db.useIndividualColors and "Color mode: Individual" or "Color mode: One static color")
        staticColorButton:SetShown(not db.useIndividualColors)
        staticColorButton.preview:SetShown(not db.useIndividualColors)
        individualColorLabel:SetShown(db.useIndividualColors)
        for _, button in ipairs(individualColorButtons) do
            button:SetShown(db.useIndividualColors)
            button.preview:SetShown(db.useIndividualColors)
        end
    end
    colorModeButton:SetScript("OnClick", function()
        db.useIndividualColors = not db.useIndividualColors
        RefreshColorMode()
        if UpdateConfigPreview then
            UpdateConfigPreview()
        end
        UpdateTracker()
    end)
    RefreshColorMode()

    local stylePage = CreatePage("style")
    local backgroundButton = CreateFrame("Button", nil, stylePage, "UIPanelButtonTemplate")
    backgroundButton:SetSize(224, 26)
    backgroundButton:SetPoint("TOPLEFT", stylePage, "TOPLEFT", 10, -14)
    AddColorPickerButton(stylePage, "Box background color", db.backgroundColor, -14, true, 244, 200)
    local function RefreshBackgroundText()
        backgroundButton:SetText(db.showBackground and "Box background: On" or "Box background: Off")
    end
    backgroundButton:SetScript("OnClick", function()
        db.showBackground = not db.showBackground
        RefreshBackgroundText()
        ApplyLayout()
        UpdateTracker()
    end)
    RefreshBackgroundText()

    local borderButton = CreateFrame("Button", nil, stylePage, "UIPanelButtonTemplate")
    borderButton:SetSize(224, 26)
    borderButton:SetPoint("TOPLEFT", stylePage, "TOPLEFT", 10, -50)
    AddColorPickerButton(stylePage, "Border color", db.borderColor, -50, true, 244, 200)
    local function RefreshBorderText()
        borderButton:SetText(db.showBorder and "Border: On" or "Border: Off")
    end
    borderButton:SetScript("OnClick", function()
        db.showBorder = not db.showBorder
        RefreshBorderText()
        ApplyLayout()
        UpdateTracker()
    end)
    RefreshBorderText()
    AddSlider(stylePage, "Border thickness", "borderSize", -108, 1, 8, 1, 10, 468)

    local attachPage = CreatePage("attach")
    local RefreshAttachmentText
    local RefreshAnchorButtons
    local RefreshOffsetControls
    local attachHelp = AddLabel(attachPage, "Click Pick frame, hover desired UI frame, then press Enter.", 10, -14)
    attachHelp:SetTextColor(1, 0.82, 0, 1)
    local selectedFrameLabel = AddLabel(attachPage, "", 10, -48)
    local pickButton = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
    pickButton:SetSize(468, 30)
    pickButton:SetPoint("TOPLEFT", attachPage, "TOPLEFT", 10, -78)
    local detachButton = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
    detachButton:SetSize(224, 26)
    detachButton:SetPoint("TOPLEFT", attachPage, "TOPLEFT", 10, -120)
    detachButton:SetText("Detach to screen")
    detachButton:SetScript("OnClick", function()
        db.snapToFrame = false
        db.position.frameName = "UIParent"
        ApplyLayout()
        UpdateTracker()
        configPanel.RefreshUnlockText()
        RefreshAttachmentText()
    end)
    local attachResetPositionButton = CreateFrame("Button", nil, attachPage, "UIPanelButtonTemplate")
    attachResetPositionButton:SetSize(224, 26)
    attachResetPositionButton:SetPoint("TOPLEFT", attachPage, "TOPLEFT", 244, -120)
    attachResetPositionButton:SetText("Reset position")
    attachResetPositionButton:SetScript("OnClick", function()
        ResetPosition()
        configPanel.RefreshUnlockText()
        RefreshAttachmentText()
        RefreshAnchorButtons()
        RefreshOffsetControls()
    end)

    AddLabel(attachPage, "Attach point", 10, -166)
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
            anchorButtons[index]:SetEnabled(db.position.point ~= option.point or db.position.relativePoint ~= option.point)
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
            db.position.point = option.point
            db.position.relativePoint = option.point
            ApplyLayout()
            UpdateTracker()
            RefreshAnchorButtons()
        end)
        anchorButtons[index] = button
    end
    RefreshAnchorButtons()

    AddLabel(attachPage, "Frame-relative offset", 10, -286)
    local xOffsetSlider = AddPositionSlider(attachPage, "X offset", "x", -310, 10, 224)
    local yOffsetSlider = AddPositionSlider(attachPage, "Y offset", "y", -310, 244, 224)
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
        local frameName = db.position.frameName
        local attached = db.snapToFrame and frameName ~= "UIParent"
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
                db.position.frameName = frameName
                db.position.x = 0
                db.position.y = 0
                db.snapToFrame = true
                tracker.isUnlocked = false
                tracker:EnableMouse(false)
                configPanel.RefreshUnlockText()
                RefreshOffsetControls()
                ApplyLayout()
                UpdateTracker()
                RefreshAttachmentText()
                StopFramePicker()
            end
        end
    end)
    RefreshAttachmentText()

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
            local point = CreateFrame("Frame", nil, preview, "BackdropTemplate")
            point.texture = point:CreateTexture(nil, "ARTWORK")
            point.mask = point:CreateMaskTexture()
            point.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            state.points[index] = point
        end
    end

    UpdateConfigPreview = function()
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
                point:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = db.showBorder and "Interface\\Buttons\\WHITE8x8" or nil,
                    edgeSize = borderInset,
                    insets = { left = borderInset, right = borderInset, top = borderInset, bottom = borderInset },
                })
                local background = db.showBackground and db.backgroundColor or { r = 0, g = 0, b = 0, a = 0 }
                point:SetBackdropColor(background.r, background.g, background.b, background.a)
                point:SetBackdropBorderColor(db.borderColor.r, db.borderColor.g, db.borderColor.b, db.borderColor.a)
                if isRound and not point.isMasked then
                    point.texture:AddMaskTexture(point.mask)
                    point.isMasked = true
                elseif not isRound and point.isMasked then
                    point.texture:RemoveMaskTexture(point.mask)
                    point.isMasked = false
                end
                point.texture:ClearAllPoints()
                point.texture:SetPoint("TOPLEFT", point, "TOPLEFT", borderInset, -borderInset)
                point.texture:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -borderInset, borderInset)
                point.mask:ClearAllPoints()
                point.mask:SetPoint("TOPLEFT", point, "TOPLEFT", borderInset, -borderInset)
                point.mask:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -borderInset, borderInset)
                SetPointVisual(point, index <= state.active, index)

                point:ClearAllPoints()
                if index == 1 then
                    point:SetPoint("LEFT", preview, "LEFT", 78, state.y)
                else
                    point:SetPoint("LEFT", state.points[index - 1], "RIGHT", spacing, 0)
                end
            end
        end
    end
    preview:SetScript("OnSizeChanged", UpdateConfigPreview)
    configPanel:SetScript("OnSizeChanged", UpdateConfigPreview)
    UpdateConfigPreview()

    CreateTab("layout", "Layout", 16, 92)
    CreateTab("colors", "Colors", 112, 92)
    CreateTab("style", "Style", 208, 92)
    CreateTab("attach", "Attach", 304, 92)
    CreateTab("profiles", "Profiles", 400, 92)
    ShowPage("layout")
    configPanel:Hide()
end

local function CreateSettingsCategory()
    local panel = CreateFrame("Frame")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("Combo Points")

    local profileImage = panel:CreateTexture(nil, "ARTWORK")
    profileImage:SetSize(310, 149)
    profileImage:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    profileImage:SetTexture("Interface\\AddOns\\ComboPoints\\cop.tga")

    local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions:SetPoint("TOPLEFT", profileImage, "BOTTOMLEFT", 0, -16)
    instructions:SetText("To access Combo Points:\nEnter /cop or /combopoints in the chat")

    local openEditorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openEditorButton:SetSize(220, 28)
    openEditorButton:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 0, -20)
    openEditorButton:SetText("Open Combo Points editor")
    openEditorButton:SetScript("OnClick", function()
        configPanel:Show()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Combo Points")
    Settings.RegisterAddOnCategory(category)
end

local function ToggleConfig()
    configPanel:SetShown(not configPanel:IsShown())
end

SLASH_COMBOPOINTS1 = "/combopoints"
SLASH_COMBOPOINTS2 = "/cop"
SlashCmdList.COMBOPOINTS = function(message)
    message = message:lower():match("^%s*(.-)%s*$")
    if message == "unlock" then
        if db.snapToFrame then
            print("Combo Points: detach from frame before free-moving tracker.")
            return
        end
        tracker.isUnlocked = true
        tracker:EnableMouse(true)
        print("Combo Points: position unlocked. Drag tracker, then use /cop lock.")
    elseif message == "lock" then
        tracker.isUnlocked = false
        tracker:EnableMouse(false)
        print("Combo Points: position locked.")
    elseif message == "resetpos" or message == "resetposition" then
        ResetPosition()
        print("Combo Points: position reset.")
    elseif message == "reset" then
        ResetCurrentProfile()
        ApplyLayout()
        UpdateTracker()
        print("Combo Points: defaults restored.")
    elseif message == "toggle" or message == "on" or message == "off" then
        db.enabled = message == "off" and false or (message == "on" or not db.enabled)
        UpdateTracker()
        print("Combo Points: " .. (db.enabled and "enabled." or "disabled."))
    else
        ToggleConfig()
    end
end

addon:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        local loadedAddon = unit
        if loadedAddon ~= ADDON_NAME then
            return
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        LoadCharacterProfile()
        CreateTracker()
        CreateConfigPanel()
        CreateSettingsCategory()
        return
    end

    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        if unit ~= "player" then
            return
        end
    end
    UpdateTracker()
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
addon:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
addon:RegisterEvent("PLAYER_REGEN_DISABLED")
addon:RegisterEvent("PLAYER_REGEN_ENABLED")
addon:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
addon:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")

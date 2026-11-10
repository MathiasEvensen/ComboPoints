local ADDON_NAME, ns = ...

ns.Widgets = {}
local Widgets = ns.Widgets

function Widgets.AddLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local COLUMN_EDGES = {
    full = { "TOPLEFT", 10, "TOPRIGHT", -10 },
    left = { "TOPLEFT", 10, "TOP", -10 },
    right = { "TOP", 0, "TOPRIGHT", -20 },
}

function Widgets.PlaceInColumn(region, parent, column, y, rightInset)
    local edges = COLUMN_EDGES[column]
    region:SetPoint("TOPLEFT", parent, edges[1], edges[2], y)
    region:SetPoint("TOPRIGHT", parent, edges[3], edges[4] - (rightInset or 0), y)
end

local function CreateBareSlider(parent, label, column, y, minValue, maxValue, step)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    Widgets.PlaceInColumn(slider, parent, column, y - 18)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")
    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", slider, "TOPLEFT", 0, 18)
    labelText:SetText(label)
    return slider
end

-- The slider's thumb is taller than the slider, so a box sitting directly on it made clicks grab the thumb.
local VALUE_BOX_GAP = 8

local function CreateStepControls(parent, slider)
    local plusButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    plusButton:SetSize(22, 22)
    plusButton:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, VALUE_BOX_GAP)
    plusButton:SetText("+")

    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(48, 22)
    input:SetPoint("RIGHT", plusButton, "LEFT", -4, 0)
    input:SetAutoFocus(false)
    input:SetJustifyH("CENTER")

    local minusButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    minusButton:SetSize(22, 22)
    minusButton:SetPoint("RIGHT", input, "LEFT", -8, 0)
    minusButton:SetText("-")

    return minusButton, input, plusButton
end

function Widgets.AddSlider(parent, label, key, y, step, column)
    local minValue, maxValue = unpack(ns.NUMBER_LIMITS[key])
    local slider = CreateBareSlider(parent, label, column or "full", y, minValue, maxValue, step)
    local minusButton, valueInput, plusButton = CreateStepControls(parent, slider)

    local function Sync()
        local value = ns.db[key]
        valueInput:SetText(string.format("%.0f", value))
        minusButton:SetEnabled(value > minValue)
        plusButton:SetEnabled(value < maxValue)
    end

    valueInput:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            slider:SetValue(math.max(minValue, math.min(maxValue, value)))
        end
        Sync()
        self:ClearFocus()
    end)
    valueInput:SetScript("OnEscapePressed", function(self)
        Sync()
        self:ClearFocus()
    end)
    minusButton:SetScript("OnClick", function()
        slider:SetValue(ns.db[key] - step)
    end)
    plusButton:SetScript("OnClick", function()
        slider:SetValue(ns.db[key] + step)
    end)

    slider:SetValue(ns.db[key])

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor((value / step) + 0.5) * step
        ns.db[key] = value
        Sync()
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    Sync()
    return slider
end

local POSITION_SLIDER_RANGE = 500

-- The slider spans only +-POSITION_SLIDER_RANGE so dragging stays precise; the box and buttons accept anything on screen.
function Widgets.AddPositionSlider(parent, label, key, y, column)
    local slider = CreateBareSlider(parent, label, column, y, -POSITION_SLIDER_RANGE, POSITION_SLIDER_RANGE, 1)

    local minusButton, input, plusButton = CreateStepControls(parent, slider)

    -- The flag stops the slider's clamped value from being written back as the position.
    local syncing = false
    local function Sync()
        local value = ns.db.position[key]
        syncing = true
        slider:SetValue(math.max(-POSITION_SLIDER_RANGE, math.min(POSITION_SLIDER_RANGE, value)))
        syncing = false
        input:SetText(string.format("%d", value))
    end

    local function SetPosition(value)
        -- Read on every change: the screen's size in UI units follows the UI scale.
        local limit = math.max(POSITION_SLIDER_RANGE, math.ceil(math.max(UIParent:GetWidth(), UIParent:GetHeight())))
        value = math.max(-limit, math.min(limit, math.floor(value + 0.5)))
        ns.db.position[key] = value
        Sync()
        ns.ApplyLayout()
        ns.UpdateTracker()
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if not syncing then
            SetPosition(value)
        end
    end)
    minusButton:SetScript("OnClick", function()
        SetPosition(ns.db.position[key] - 1)
    end)
    plusButton:SetScript("OnClick", function()
        SetPosition(ns.db.position[key] + 1)
    end)
    input:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            SetPosition(value)
        else
            Sync()
        end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        Sync()
        self:ClearFocus()
    end)
    slider.RefreshPosition = Sync
    Sync()
    return slider
end

function Widgets.AddColorPickerButton(parent, label, getColor, y, applyLayout, column)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetHeight(26)
    Widgets.PlaceInColumn(button, parent, column, y, 24)
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
        local color = getColor()
        color.r = r
        color.g = g
        color.b = b
        color.a = a or 1
        previewColor:SetColorTexture(color.r, color.g, color.b, color.a)
        if applyLayout then
            ns.ApplyLayout()
        else
            ns.UpdateConfigPreview()
        end
        ns.UpdateTracker()
    end

    do
        local color = getColor()
        ApplyColor(color.r, color.g, color.b, color.a)
    end
    button:SetScript("OnClick", function()
        local color = getColor()
        local previousValues = { r = color.r, g = color.g, b = color.b, a = color.a }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r,
            g = color.g,
            b = color.b,
            opacity = color.a,
            hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                ApplyColor(r, g, b, getColor().a)
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

local DROPDOWN_ROW_HEIGHT = 20
local DROPDOWN_LIST_HEIGHT = 180

local DROPDOWN_HEIGHT = 26

-- Tracked so Esc can close it before the settings window.
local openDropdownList

function Widgets.CloseOpenDropdown()
    if openDropdownList then
        openDropdownList:Hide()
        return true
    end
    return false
end

function Widgets.AddScrollableDropdown(parent, x, y, width, config)
    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, DROPDOWN_HEIGHT)
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    dropdown:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    dropdown:SetBackdropColor(0, 0, 0, 0.6)
    dropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    dropdown:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    local arrow = dropdown:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(18, 18)
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -5, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local selectedText = dropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    selectedText:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    selectedText:SetPoint("RIGHT", arrow, "LEFT", -4, 0)
    selectedText:SetJustifyH("LEFT")
    selectedText:SetWordWrap(false)

    local list = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    list:SetHeight(DROPDOWN_LIST_HEIGHT)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:EnableMouse(true)
    list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    list:SetBackdropColor(0, 0, 0, 0.95)
    list:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    list:Hide()
    list:SetScript("OnShow", function(self)
        if openDropdownList and openDropdownList ~= self then
            openDropdownList:Hide()
        end
        openDropdownList = self
    end)
    list:SetScript("OnHide", function(self)
        if openDropdownList == self then
            openDropdownList = nil
        end
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -26, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scroll = self:GetVerticalScroll() - (delta * DROPDOWN_ROW_HEIGHT * 2)
        self:SetVerticalScroll(math.max(0, math.min(scroll, self:GetVerticalScrollRange())))
    end)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(width, DROPDOWN_LIST_HEIGHT - 16)
    scrollFrame:SetScrollChild(content)

    local function AnchorList()
        local panel = ns.configPanel
        local dropdownBottom = dropdown:GetBottom()
        local panelBottom = panel and panel:GetBottom()
        local openUpward = dropdownBottom and panelBottom and (dropdownBottom - DROPDOWN_LIST_HEIGHT) < panelBottom

        list:ClearAllPoints()
        if openUpward then
            list:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 0, 2)
            list:SetPoint("BOTTOMRIGHT", dropdown, "TOPRIGHT", 0, 2)
        else
            list:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
            list:SetPoint("TOPRIGHT", dropdown, "BOTTOMRIGHT", 0, -2)
        end
    end

    local rows = {}
    local function AcquireRow(index)
        local row = rows[index]
        if not row then
            row = CreateFrame("Button", nil, content)
            row:SetHeight(DROPDOWN_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * DROPDOWN_ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(index - 1) * DROPDOWN_ROW_HEIGHT)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            rows[index] = row
        end
        return row
    end

    local function RebuildRows()
        local items = config.GetItems()
        local selected = config.GetValue()
        content:SetWidth(math.max(scrollFrame:GetWidth(), 1))
        for index, item in ipairs(items) do
            local row = AcquireRow(index)
            local value = item.value
            row.text:SetText(item.name)
            if item.font then
                if not ns.TrySetFont(row.text, item.font, 13, "") then
                    ns.TrySetFont(row.text, ns.GetDefaultFontPath(), 13, "")
                end
            else
                row.text:SetFontObject("GameFontNormal")
            end
            if value == selected then
                row.text:SetTextColor(1, 0.82, 0)
            else
                row.text:SetTextColor(1, 1, 1)
            end
            row:SetScript("OnClick", function()
                list:Hide()
                config.SetValue(value)
            end)
            row:Show()
        end
        for index = #items + 1, #rows do
            rows[index]:Hide()
        end
        content:SetHeight(math.max(DROPDOWN_LIST_HEIGHT - 16, #items * DROPDOWN_ROW_HEIGHT))
        return #items
    end

    local function Toggle()
        if list:IsShown() then
            list:Hide()
            return
        end
        AnchorList()
        if RebuildRows() == 0 then
            return
        end
        scrollFrame:SetVerticalScroll(0)
        list:Show()
    end

    dropdown:SetScript("OnClick", Toggle)

    parent:HookScript("OnHide", function()
        list:Hide()
    end)

    local picker = { frame = dropdown, list = list }
    function picker:SetWidth(newWidth)
        dropdown:SetWidth(newWidth)
    end
    function picker:Refresh()
        selectedText:SetText(config.GetDisplayName(config.GetValue()))
        if list:IsShown() then
            RebuildRows()
        end
    end
    function picker:SetEnabled(enabled)
        dropdown:SetEnabled(enabled)
        arrow:SetDesaturated(not enabled)
        if enabled then
            selectedText:SetTextColor(1, 1, 1)
        else
            selectedText:SetTextColor(0.5, 0.5, 0.5)
            list:Hide()
        end
    end
    return picker
end

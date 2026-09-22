local ADDON_NAME, ns = ...

ns.Widgets = {}
local Widgets = ns.Widgets

function Widgets.AddLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function CreateBareSlider(parent, x, y, width, minValue, maxValue, step)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    slider:SetWidth(width)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")
    return slider
end

function Widgets.AddSlider(parent, label, key, y, minValue, maxValue, step, x, width)
    x = x or 18
    width = width or (parent:GetWidth() - 36)
    Widgets.AddLabel(parent, label, x, y)

    local slider
    local valueInput = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    valueInput:SetSize(46, 20)
    valueInput:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y + 2)
    valueInput:SetAutoFocus(false)
    valueInput:SetNumeric(minValue >= 0)
    valueInput:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            slider:SetValue(math.max(minValue, math.min(maxValue, value)))
        else
            self:SetText(string.format("%.0f", ns.db[key]))
        end
        self:ClearFocus()
    end)
    valueInput:SetScript("OnEscapePressed", function(self)
        self:SetText(string.format("%.0f", ns.db[key]))
        self:ClearFocus()
    end)

    slider = CreateBareSlider(parent, x, y, width, minValue, maxValue, step)
    slider:SetValue(ns.db[key])

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor((value / step) + 0.5) * step
        ns.db[key] = value
        valueInput:SetText(string.format("%.0f", value))
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    valueInput:SetText(string.format("%.0f", ns.db[key]))
    return slider
end

function Widgets.AddPositionSlider(parent, label, key, y, x, width)
    Widgets.AddLabel(parent, label, x, y)

    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(54, 22)
    input:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y + 4)
    input:SetAutoFocus(false)
    input:SetText(string.format("%d", ns.db.position[key]))

    local slider = CreateBareSlider(parent, x, y, width, -500, 500, 1)
    slider:SetValue(ns.db.position[key])

    local function SetPosition(value)
        value = math.max(-500, math.min(500, math.floor(value + (value >= 0 and 0.5 or -0.5))))
        ns.db.position[key] = value
        input:SetText(string.format("%d", value))
        ns.ApplyLayout()
        ns.UpdateTracker()
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
            self:SetText(string.format("%d", ns.db.position[key]))
        end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:SetText(string.format("%d", ns.db.position[key]))
        self:ClearFocus()
    end)
    slider.RefreshPosition = function()
        input:SetText(string.format("%d", ns.db.position[key]))
        slider:SetValue(ns.db.position[key])
    end
    return slider
end

function Widgets.AddColorPickerButton(parent, label, getColor, y, applyLayout, x, width)
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

local function GetDropDownRegion(frame, suffix)
    return frame[suffix] or _G[frame:GetName() .. suffix]
end

function Widgets.AddScrollableDropdown(parent, name, x, y, width, config)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    UIDropDownMenu_SetWidth(dropdown, width)

    local leftRegion = GetDropDownRegion(dropdown, "Left") or dropdown
    local rightRegion = GetDropDownRegion(dropdown, "Right") or dropdown
    local arrowButton = GetDropDownRegion(dropdown, "Button")

    local list = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    list:SetHeight(DROPDOWN_LIST_HEIGHT)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:EnableMouse(true)
    list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    list:SetBackdropColor(0, 0, 0, 0.95)
    list:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    list:Hide()

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
            list:SetPoint("BOTTOMLEFT", leftRegion, "TOPLEFT", 0, -6)
            list:SetPoint("BOTTOMRIGHT", rightRegion, "TOPRIGHT", 0, -6)
        else
            list:SetPoint("TOPLEFT", leftRegion, "BOTTOMLEFT", 0, 6)
            list:SetPoint("TOPRIGHT", rightRegion, "BOTTOMRIGHT", 0, 6)
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

    if arrowButton then
        arrowButton:SetScript("OnClick", Toggle)
    end

    local clickCatcher = CreateFrame("Button", nil, dropdown)
    clickCatcher:SetPoint("TOPLEFT", leftRegion, "TOPLEFT", 0, 0)
    clickCatcher:SetPoint("BOTTOMRIGHT", rightRegion, "BOTTOMRIGHT", 0, 0)
    clickCatcher:SetScript("OnClick", Toggle)

    parent:HookScript("OnHide", function()
        list:Hide()
    end)

    local picker = { frame = dropdown, list = list }
    function picker:Refresh()
        UIDropDownMenu_SetText(dropdown, config.GetDisplayName(config.GetValue()))
        if list:IsShown() then
            RebuildRows()
        end
    end
    function picker:SetEnabled(enabled)
        if enabled then
            UIDropDownMenu_EnableDropDown(dropdown)
        else
            UIDropDownMenu_DisableDropDown(dropdown)
            list:Hide()
        end
        clickCatcher:SetEnabled(enabled)
    end
    return picker
end

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

    local valueLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueLabel:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)

    local slider = CreateBareSlider(parent, x, y, width, minValue, maxValue, step)
    slider:SetValue(ns.db[key])

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor((value / step) + 0.5) * step
        ns.db[key] = value
        valueLabel:SetText(string.format("%.0f", value))
        ns.ApplyLayout()
        ns.UpdateTracker()
    end)
    valueLabel:SetText(string.format("%.0f", ns.db[key]))
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

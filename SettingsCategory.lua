local ADDON_NAME, ns = ...

function ns.CreateSettingsCategory()
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
        ns.configPanel:Show()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Combo Points")
    Settings.RegisterAddOnCategory(category)
end

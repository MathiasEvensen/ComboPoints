local ADDON_NAME, ns = ...

local function SetPointVisual(point, active, index)
    local db = ns.db
    local color = active and (db.useIndividualColors and db.pointColors[index] or db.color) or db.emptyColor
    point.texture:SetColorTexture(color.r, color.g, color.b, color.a)
end
ns.SetPointVisual = SetPointVisual

function ns.ApplyLayout()
    local tracker, db = ns.tracker, ns.db
    if not tracker or not db then
        return
    end

    tracker:ClearAllPoints()
    local position = db.position
    local anchorFrame = db.snapToFrame and ns.GetAttachmentFrame(position.frameName) or UIParent
    tracker:SetPoint(position.point, anchorFrame, position.relativePoint, position.x, position.y)

    local pointFrames = ns.pointFrames
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
    if ns.UpdateConfigPreview then
        ns.UpdateConfigPreview()
    end
end

function ns.UpdateTracker()
    local tracker, db = ns.tracker, ns.db
    if not tracker or not db then
        return
    end

    ns.activePowerType = ns.GetPowerType()
    local isSupportedSpec = ns.IsTrackedClass()
    local shouldShow = db.enabled and ns.activePowerType and (isSupportedSpec or not db.onlySupportedSpecs) and (not db.onlyInCombat or InCombatLockdown())
    if not shouldShow then
        tracker:Hide()
        return
    end

    local pointFrames = ns.pointFrames
    local current = UnitPower("player", ns.activePowerType)
    local maximum = math.min(UnitPowerMax("player", ns.activePowerType), #pointFrames)
    for index, point in ipairs(pointFrames) do
        point:SetShown(index <= maximum)
        SetPointVisual(point, index <= current, index)
    end
    tracker:Show()
end

function ns.SavePosition()
    local db = ns.db
    local point, _, relativePoint, x, y = ns.tracker:GetPoint()
    db.position.point = point
    db.position.relativePoint = relativePoint
    db.position.x = math.floor(x + 0.5)
    db.position.y = math.floor(y + 0.5)
end

function ns.ResetPosition()
    local db = ns.db
    db.position = {}
    ns.CopyDefaults(ns.DEFAULTS.position, db.position)
    db.snapToFrame = false
    ns.ApplyLayout()
    ns.UpdateTracker()
end

function ns.CreateTracker()
    local tracker = CreateFrame("Frame", ADDON_NAME .. "Tracker", UIParent)
    ns.tracker = tracker
    tracker:SetMovable(true)
    tracker:EnableMouse(false)
    tracker:RegisterForDrag("LeftButton")
    tracker:SetScript("OnDragStart", function(self)
        if self.isUnlocked and not ns.db.snapToFrame then
            self:StartMoving()
        end
    end)
    tracker:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.SavePosition()
    end)

    local pointFrames = ns.pointFrames
    for index = 1, 10 do
        local point = CreateFrame("Frame", nil, tracker, "BackdropTemplate")
        point.texture = point:CreateTexture(nil, "ARTWORK")
        point.texture:SetAllPoints()
        point.mask = point:CreateMaskTexture()
        point.mask:SetAllPoints()
        point.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pointFrames[index] = point
    end

    ns.ApplyLayout()
end

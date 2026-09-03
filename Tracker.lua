local ADDON_NAME, ns = ...

local function SetPointVisual(point, active, index)
    local db = ns.db
    local color = active and (db.useIndividualColors and db.pointColors[index] or db.color) or db.emptyColor
    point.texture:SetColorTexture(color.r, color.g, color.b, color.a)
end
ns.SetPointVisual = SetPointVisual

-- Shared by the live tracker (CreateTracker/ApplyLayout) and the config
-- panel's live preview (ConfigPanel.lua BuildPreviewSection), so both stay
-- visually in sync.

-- Background/border are plain color textures layered under the active/empty
-- color texture, rather than a backdrop: SetBackdrop's edgeFile/bgFile are
-- drawn outside the normal texture pipeline, so a mask added to point.texture
-- alone can't round them off - the box stayed square behind a round dot.
-- The border is 4 edge strips (top/bottom/left/right, picture-frame style)
-- rather than one full-size quad: a full-size quad sits directly under the
-- translucent background over the whole interior, so background color reads
-- as background-over-border instead of background-over-nothing, darkening
-- it. Strips only occupy the ring band, so the interior stays a single
-- translucent layer like before.

function ns.CreatePointFrame(parent)
    local point = CreateFrame("Frame", nil, parent)
    point.borderTopTexture = point:CreateTexture(nil, "BACKGROUND")
    point.borderBottomTexture = point:CreateTexture(nil, "BACKGROUND")
    point.borderLeftTexture = point:CreateTexture(nil, "BACKGROUND")
    point.borderRightTexture = point:CreateTexture(nil, "BACKGROUND")
    point.borderTextures = { point.borderTopTexture, point.borderBottomTexture, point.borderLeftTexture, point.borderRightTexture }
    point.bgTexture = point:CreateTexture(nil, "BORDER")
    point.texture = point:CreateTexture(nil, "ARTWORK")

    point.mask = point:CreateMaskTexture()
    point.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    point.outerMask = point:CreateMaskTexture()
    point.outerMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    point.outerMask:SetAllPoints(point)

    return point
end

function ns.StylePointFrame(point, db, borderInset, isRound)
    local borderColor = db.showBorder and db.borderColor or { r = 0, g = 0, b = 0, a = 0 }
    for _, texture in ipairs(point.borderTextures) do
        texture:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    end

    local background = db.showBackground and db.backgroundColor or { r = 0, g = 0, b = 0, a = 0 }
    point.bgTexture:SetColorTexture(background.r, background.g, background.b, background.a)

    if isRound and not point.isMasked then
        point.texture:AddMaskTexture(point.mask)
        point.bgTexture:AddMaskTexture(point.mask)
        for _, texture in ipairs(point.borderTextures) do
            texture:AddMaskTexture(point.outerMask)
        end
        point.isMasked = true
    elseif not isRound and point.isMasked then
        point.texture:RemoveMaskTexture(point.mask)
        point.bgTexture:RemoveMaskTexture(point.mask)
        for _, texture in ipairs(point.borderTextures) do
            texture:RemoveMaskTexture(point.outerMask)
        end
        point.isMasked = false
    end

    point.borderLeftTexture:ClearAllPoints()
    point.borderLeftTexture:SetPoint("TOPLEFT", point, "TOPLEFT", 0, 0)
    point.borderLeftTexture:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", 0, 0)
    point.borderLeftTexture:SetWidth(borderInset)

    point.borderRightTexture:ClearAllPoints()
    point.borderRightTexture:SetPoint("TOPRIGHT", point, "TOPRIGHT", 0, 0)
    point.borderRightTexture:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", 0, 0)
    point.borderRightTexture:SetWidth(borderInset)

    point.borderTopTexture:ClearAllPoints()
    point.borderTopTexture:SetPoint("TOPLEFT", point, "TOPLEFT", borderInset, 0)
    point.borderTopTexture:SetPoint("TOPRIGHT", point, "TOPRIGHT", -borderInset, 0)
    point.borderTopTexture:SetHeight(borderInset)

    point.borderBottomTexture:ClearAllPoints()
    point.borderBottomTexture:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", borderInset, 0)
    point.borderBottomTexture:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -borderInset, 0)
    point.borderBottomTexture:SetHeight(borderInset)

    point.bgTexture:ClearAllPoints()
    point.bgTexture:SetPoint("TOPLEFT", point, "TOPLEFT", borderInset, -borderInset)
    point.bgTexture:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -borderInset, borderInset)

    point.texture:ClearAllPoints()
    point.texture:SetPoint("TOPLEFT", point, "TOPLEFT", borderInset, -borderInset)
    point.texture:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -borderInset, borderInset)

    point.mask:ClearAllPoints()
    point.mask:SetPoint("TOPLEFT", point, "TOPLEFT", borderInset, -borderInset)
    point.mask:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -borderInset, borderInset)
end

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
        ns.StylePointFrame(point, db, borderInset, isRound)

        point:ClearAllPoints()
        if index == 1 then
            point:SetPoint("LEFT", tracker, "LEFT", 0, 0)
        else
            point:SetPoint("LEFT", pointFrames[index - 1], "RIGHT", db.spacing, 0)
        end
    end

    tracker:SetSize((db.pointWidth * #pointFrames) + (db.spacing * (#pointFrames - 1)), db.pointHeight)
    ns.UpdateConfigPreview()
end

function ns.UpdateTracker()
    local tracker, db = ns.tracker, ns.db
    if not tracker or not db then
        return
    end

    ns.activePowerType = ns.GetPowerType(ns.classFile)
    local isSupportedSpec = ns.IsTrackedClass(ns.classFile)
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
        pointFrames[index] = ns.CreatePointFrame(tracker)
    end

    ns.ApplyLayout()
end

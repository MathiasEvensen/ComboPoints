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
--
-- Square mode uses 4 edge strips (picture-frame style) so border color never
-- sits under the interior fill. Round mode instead reuses one of those
-- strips as a single full-size disc masked to a true circle (borderTopTexture
-- doubles as this; the other three stay hidden) - a proper round outline
-- needs a genuine circle, which a border-thickness-sized corner radius can't
-- give. WoW's mask API can't subtract (no true ring/annulus without a custom
-- ring-shaped texture asset), so this disc necessarily sits behind the whole
-- interior: wherever the interior fill's alpha is below 1, border color
-- shows through it. That's an accepted, deliberate trade-off for a genuinely
-- round outline, not a bug - keep interior colors near-opaque to minimize it.

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
    point.mask:SetTexture("Interface\\Masks\\CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    point.outerMask = point:CreateMaskTexture()
    point.outerMask:SetTexture("Interface\\Masks\\CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
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
        point.borderTopTexture:AddMaskTexture(point.outerMask)
        point.isMasked = true
    elseif not isRound and point.isMasked then
        point.texture:RemoveMaskTexture(point.mask)
        point.bgTexture:RemoveMaskTexture(point.mask)
        point.borderTopTexture:RemoveMaskTexture(point.outerMask)
        point.isMasked = false
    end

    if isRound then
        point.borderTopTexture:ClearAllPoints()
        point.borderTopTexture:SetAllPoints(point)
        point.borderTopTexture:Show()
        point.borderBottomTexture:Hide()
        point.borderLeftTexture:Hide()
        point.borderRightTexture:Hide()
    else
        for _, texture in ipairs(point.borderTextures) do
            texture:Show()
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
    end

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

-- Counter text: a numeric readout of the current point total, drawn over the
-- bar. It lives on a holder frame layered above the point frames, since child
-- frames always render above their parent's own draw layers - a font string
-- created straight on the tracker would sit behind every point.

function ns.CreateCounterText(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetAllPoints(parent)
    holder:SetFrameLevel(parent:GetFrameLevel() + 10)
    return holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
end

function ns.StyleCounterText(counter, db, fontSize)
    local flags = db.counterOutline and "OUTLINE" or ""
    if not ns.TrySetFont(counter, db.counterFont, fontSize, flags) then
        -- Chosen font missing (locale build, or an addon that registered it is
        -- gone), so fall back rather than leave the counter unreadable.
        ns.TrySetFont(counter, ns.GetDefaultFontPath(), fontSize, flags)
    end
    -- The font object the counter was created from carries a drop shadow that
    -- SetFont does not clear; it reads as a heavy smudge next to an outline, so
    -- the outline flag is the only backdrop this counter gets.
    counter:SetShadowColor(0, 0, 0, 0)
    counter:SetShadowOffset(0, 0)
    local color = db.counterColor
    counter:SetTextColor(color.r, color.g, color.b, color.a)
end

function ns.ShouldShowCounter(db, current)
    if not db.showCounter then
        return false
    end
    return not (db.counterHideAtZero and (current or 0) == 0)
end

function ns.FormatCounterText(db, current, maximum)
    if db.counterShowMax then
        return current .. " / " .. maximum
    end
    return tostring(current)
end

-- The tracker frame is always sized for the full pool of 10 point frames while
-- only the spec's maximum are shown, so the tracker's own center sits right of
-- the visible bar's center. This is the horizontal correction from one to the
-- other; ns.UpdateTracker records the visible count in tracker.visibleCount.
function ns.GetCounterCenterOffset(db, visibleCount)
    local pointCount = #ns.pointFrames
    visibleCount = math.max(1, math.min(visibleCount or 5, pointCount))
    local visibleWidth = (db.pointWidth * visibleCount) + (db.spacing * (visibleCount - 1))
    local totalWidth = (db.pointWidth * pointCount) + (db.spacing * (pointCount - 1))
    return (visibleWidth - totalWidth) / 2
end

function ns.AnchorCounterText(tracker, db)
    local counter = tracker.counter
    if not counter then
        return
    end
    local centerOffset = ns.GetCounterCenterOffset(db, tracker.visibleCount)
    counter:ClearAllPoints()
    counter:SetPoint("CENTER", tracker, "CENTER", centerOffset + db.counterOffsetX, db.counterOffsetY)
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

    if tracker.counter then
        ns.AnchorCounterText(tracker, db)
        ns.StyleCounterText(tracker.counter, db, db.counterFontSize)
        tracker.counter:SetShown(ns.ShouldShowCounter(db, tracker.currentCount))
    end

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

    if tracker.counter then
        local counted = math.min(current, maximum)
        tracker.visibleCount = maximum
        tracker.currentCount = counted
        ns.AnchorCounterText(tracker, db)
        tracker.counter:SetText(ns.FormatCounterText(db, counted, maximum))
        tracker.counter:SetShown(ns.ShouldShowCounter(db, counted))
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

    tracker.counter = ns.CreateCounterText(tracker)

    local pointFrames = ns.pointFrames
    for index = 1, 10 do
        pointFrames[index] = ns.CreatePointFrame(tracker)
    end

    ns.ApplyLayout()
end

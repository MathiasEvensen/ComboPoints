local ADDON_NAME, ns = ...

function ns.GetMaxPoints()
    local maximum = ns.activePowerType and UnitPowerMax("player", ns.activePowerType) or 0
    if not maximum or maximum < 1 then
        maximum = 5
    end
    return math.min(maximum, math.max(#ns.pointFrames, 1))
end

local function GetActiveColor(db, index)
    if not db.useIndividualColors then
        return db.color
    end
    return db.pointColors[index] or db.pointColors[#db.pointColors] or db.color
end

local function SetPointVisual(point, active, index)
    local db = ns.db
    local color = active and GetActiveColor(db, index) or db.emptyColor
    point.texture:SetColorTexture(color.r, color.g, color.b, color.a)
end
ns.SetPointVisual = SetPointVisual

-- Plain textures instead of a backdrop: SetBackdrop is drawn outside the texture pipeline, so a mask can't round it.
-- Round mode reuses borderTopTexture as one full-size masked disc, since WoW masks can't subtract to make a ring.
-- The disc sits behind the fill, so border color shows through a translucent fill: accepted trade-off.

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

-- WoW snaps each texture edge to the pixel grid on its own, so an unrounded size is drawn thicker or thinner
-- depending on where the tracker sits. minPixels keeps a thin border from rounding to 0.
function ns.SnapToPixels(value, region, minPixels)
    return PixelUtil.GetNearestPixelSize(value, region:GetEffectiveScale(), minPixels)
end

function ns.GetPointMetrics(db)
    local tracker = ns.tracker
    if not tracker then
        return db.pointWidth, db.pointHeight, db.spacing
    end
    return ns.SnapToPixels(db.pointWidth, tracker, 1), ns.SnapToPixels(db.pointHeight, tracker, 1), ns.SnapToPixels(db.spacing, tracker)
end

-- db.borderSize counts screen pixels. Capped at a third of the point's smaller side so the border can't swallow the fill.
function ns.GetBorderInset(db, pointWidth, pointHeight, region)
    if not db.showBorder then
        return 0
    end
    local onePixel = PixelUtil.GetPixelToUIUnitFactor() / region:GetEffectiveScale()
    local maxPixels = math.max(1, math.floor(math.min(pointWidth, pointHeight) / 3 / onePixel))
    return math.min(db.borderSize, maxPixels) * onePixel
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

function ns.CreateCounterText(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetAllPoints(parent)
    holder:SetFrameLevel(parent:GetFrameLevel() + 10)
    return holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
end

function ns.StyleCounterText(counter, db, fontSize)
    local flags = db.counterOutline and "OUTLINE" or ""
    if not ns.TrySetFont(counter, db.counterFont, fontSize, flags) then
        ns.TrySetFont(counter, ns.GetDefaultFontPath(), fontSize, flags)
    end
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

function ns.GetCounterCenterOffset(db, visibleCount)
    local pointCount = #ns.pointFrames
    visibleCount = math.max(1, math.min(visibleCount or 5, pointCount))
    local pointWidth, _, spacing = ns.GetPointMetrics(db)
    local visibleWidth = (pointWidth * visibleCount) + (spacing * (visibleCount - 1))
    local totalWidth = (pointWidth * pointCount) + (spacing * (pointCount - 1))
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

-- The frame is sized for the full 10-point pool; the unused slots would otherwise swallow clicks.
local function UpdateHitRect(tracker, db)
    tracker:SetHitRectInsets(0, -2 * ns.GetCounterCenterOffset(db, tracker.visibleCount), 0, 0)
end

-- ADDON_LOADED and PLAYER_ENTERING_WORLD miss frames built later (by a timer or on first use), so also poll.
local ATTACH_RETRY_SECONDS = 60
local attachRetryTicker

local function StopAttachRetry()
    if attachRetryTicker then
        attachRetryTicker:Cancel()
        attachRetryTicker = nil
    end
end

local function StartAttachRetry()
    StopAttachRetry()
    local remaining = ATTACH_RETRY_SECONDS
    attachRetryTicker = C_Timer.NewTicker(1, function()
        remaining = remaining - 1
        if ns.GetAttachmentFrame(ns.db.position.frameName) then
            -- ApplyLayout clears attachmentPending and stops this ticker.
            ns.ApplyLayout()
            ns.UpdateTracker()
        elseif remaining <= 0 then
            StopAttachRetry()
        end
    end)
end

-- nil when the tracker has no rectangle yet. Only the visible points are tested, not the full 10-point frame.
local function IsTrackerOnScreen(tracker, db)
    local left, bottom, width, height = tracker:GetRect()
    if not left then
        return nil
    end
    local visibleWidth = width + (2 * ns.GetCounterCenterOffset(db, tracker.visibleCount))
    return left < UIParent:GetWidth() and left + visibleWidth > 0 and bottom < UIParent:GetHeight() and bottom + height > 0
end

local function PlaceAtDefault(tracker)
    local fallback = ns.DEFAULTS.position
    tracker:ClearAllPoints()
    PixelUtil.SetPoint(tracker, fallback.point, UIParent, fallback.relativePoint, fallback.x, fallback.y)
end

-- PixelUtil.SetPoint rounds only the offset: a centred anchor with an odd pixel size still puts edges on half pixels.
-- The saved position is not changed.
local function AlignToPixelGrid(tracker)
    local left, bottom = tracker:GetLeft(), tracker:GetBottom()
    local point, relativeTo, relativePoint, x, y = tracker:GetPoint()
    if not left or not bottom or not point then
        return
    end
    local nudgeX = ns.SnapToPixels(left, tracker) - left
    local nudgeY = ns.SnapToPixels(bottom, tracker) - bottom
    if math.abs(nudgeX) > 0.001 or math.abs(nudgeY) > 0.001 then
        tracker:SetPoint(point, relativeTo, relativePoint, x + nudgeX, y + nudgeY)
    end
end

function ns.ApplyLayout()
    local tracker, db = ns.tracker, ns.db
    if not tracker or not db then
        return
    end

    tracker:SetFrameStrata(db.strata)
    tracker:ClearAllPoints()
    local position = db.position
    local anchorFrame = UIParent
    ns.attachmentPending = false
    if db.snapToFrame then
        local frame = ns.GetAttachmentFrame(position.frameName)
        if frame then
            anchorFrame = frame
        else
            -- Frame not created yet: use the screen for now, retry later.
            ns.attachmentPending = true
        end
    end
    if ns.attachmentPending then
        StartAttachRetry()
    else
        StopAttachRetry()
    end
    -- SetPoint raises an error for anchors WoW refuses (itself, a frame anchored to it, a protected frame in combat).
    if not pcall(PixelUtil.SetPoint, tracker, position.point, anchorFrame, position.relativePoint, position.x, position.y) then
        PlaceAtDefault(tracker)
    end

    local pointFrames = ns.pointFrames
    local isRound = db.shape == "round"
    local pointWidth, pointHeight, spacing = ns.GetPointMetrics(db)
    local borderInset = ns.GetBorderInset(db, pointWidth, pointHeight, tracker)
    for index, point in ipairs(pointFrames) do
        point:SetSize(pointWidth, pointHeight)
        ns.StylePointFrame(point, db, borderInset, isRound)

        point:ClearAllPoints()
        if index == 1 then
            point:SetPoint("LEFT", tracker, "LEFT", 0, 0)
        else
            point:SetPoint("LEFT", pointFrames[index - 1], "RIGHT", spacing, 0)
        end
    end

    tracker:SetSize((pointWidth * #pointFrames) + (spacing * (#pointFrames - 1)), pointHeight)
    UpdateHitRect(tracker, db)

    -- A position with no visible point on screen is shown at the default instead; the saved value stays.
    -- Not when attached: only that frame knows where the tracker belongs.
    if anchorFrame == UIParent and IsTrackerOnScreen(tracker, db) == false then
        PlaceAtDefault(tracker)
    end
    AlignToPixelGrid(tracker)

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

    local maxPoints = ns.GetMaxPoints()
    if maxPoints ~= tracker.maxPoints then
        tracker.maxPoints = maxPoints
        if ns.configPanel and ns.configPanel.RefreshPointCount then
            ns.configPanel.RefreshPointCount()
        end
        ns.UpdateConfigPreview()
    end
    local isSupportedSpec, isAnySpecCatForm = ns.IsTrackedClass(ns.classFile)
    local passesSpecFilter = isSupportedSpec or (db.catFormAllSpecs and isAnySpecCatForm) or not db.onlySupportedSpecs
    local shouldShow = db.enabled and ns.activePowerType and passesSpecFilter and (not db.onlyInCombat or ns.inCombat)
    if not shouldShow then
        tracker:Hide()
        return
    end

    local pointFrames = ns.pointFrames
    local current = UnitPower("player", ns.activePowerType)
    local maximum = maxPoints
    for index, point in ipairs(pointFrames) do
        point:SetShown(index <= maximum)
        SetPointVisual(point, index <= current, index)
    end

    -- These depend only on the visible point count, so ordinary resource changes skip them.
    if maximum ~= tracker.visibleCount then
        tracker.visibleCount = maximum
        UpdateHitRect(tracker, db)
        ns.AnchorCounterText(tracker, db)
    end

    if tracker.counter then
        local counted = math.min(current, maximum)
        tracker.currentCount = counted
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
    if ns.configPanel and ns.configPanel.RefreshPositionControls then
        ns.configPanel.RefreshPositionControls()
    end
end

function ns.SetTrackerUnlocked(unlocked)
    local tracker = ns.tracker
    tracker.isUnlocked = unlocked and true or false
    tracker:EnableMouse(tracker.isUnlocked)
    if ns.configPanel and ns.configPanel.RefreshUnlockText then
        ns.configPanel.RefreshUnlockText()
    end
end

function ns.ResetPosition()
    local db = ns.db
    db.position = {}
    ns.CopyDefaults(ns.DEFAULTS.position, db.position)
    db.snapToFrame = false
    ns.ApplyLayout()
    ns.UpdateTracker()
    if ns.configPanel and ns.configPanel.RefreshPositionControls then
        ns.configPanel.RefreshPositionControls()
    end
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

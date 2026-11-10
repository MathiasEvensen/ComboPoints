local ADDON_NAME, ns = ...

-- How many points the character currently has, as the game reports it
-- (UnitPowerMax): 4 for an Arcane Mage, 5 for most, 6 or 7 for a rogue with
-- Deeper Stratagem / Secret Stratagem. Talents are never inspected directly.
-- Falls back to 5 while there is no tracked resource or no maximum yet.
function ns.GetMaxPoints()
    local maximum = ns.activePowerType and UnitPowerMax("player", ns.activePowerType) or 0
    if not maximum or maximum < 1 then
        maximum = 5
    end
    return math.min(maximum, math.max(#ns.pointFrames, 1))
end

-- Individual mode: a point beyond the configured colors reuses the last one.
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

-- Shared by the live tracker (CreateTracker/ApplyLayout) and the config
-- panel's live preview (ConfigPanel.lua BuildPreviewSection), so both stay visually in sync.

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

-- Pixel snapping. Settings are in UI units, which rarely equal a whole number
-- of screen pixels (it depends on UI scale and resolution). WoW snaps each
-- texture edge to the pixel grid on its own, so a 1.4-pixel border is drawn 1
-- or 2 pixels thick depending on where the tracker sits, and changes as it is
-- moved. Every size is therefore rounded to whole pixels for the region's
-- effective scale before use; minPixels keeps a thin border from rounding to 0.
function ns.SnapToPixels(value, region, minPixels)
    return PixelUtil.GetNearestPixelSize(value, region:GetEffectiveScale(), minPixels)
end

-- Point width, height, and spacing of the live tracker, in whole pixels.
function ns.GetPointMetrics(db)
    local tracker = ns.tracker
    if not tracker then
        return db.pointWidth, db.pointHeight, db.spacing
    end
    return ns.SnapToPixels(db.pointWidth, tracker, 1), ns.SnapToPixels(db.pointHeight, tracker, 1), ns.SnapToPixels(db.spacing, tracker)
end

-- Border thickness actually drawn, in UI units. db.borderSize counts screen
-- pixels, not UI units: a UI unit is a fraction of a pixel at most scales, so
-- stepping in units gave uneven jumps once rounded (1 -> 1 pixel, 2 -> 3).
-- Capped at a third of the point's smaller side, so a thick border on a small
-- point can't swallow the fill. Used by both the tracker and the preview so
-- they agree.
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

-- The tracker frame is sized for the full 10-point pool, so while unlocked
-- its mouse area is trimmed to the visible points; otherwise the unused slots
-- would swallow clicks meant for whatever is behind them.
local function UpdateHitRect(tracker, db)
    tracker:SetHitRectInsets(0, -2 * ns.GetCounterCenterOffset(db, tracker.visibleCount), 0, 0)
end

-- Waiting for the attached frame. ADDON_LOADED and PLAYER_ENTERING_WORLD
-- (Bindings.lua) catch most frames, but not one built later: by a timer, on
-- first use, or in another addon's own PLAYER_ENTERING_WORLD handler that runs
-- after this one. So while the attachment is pending, the frame is also looked
-- up once a second for a while. Any later layout starts the wait again.
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

-- Whether any part of the visible points is inside the screen. nil when the
-- tracker has no rectangle yet. The frame is sized for the full 10-point pool
-- and the points fill it from the left, so only the visible part is tested.
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

-- PixelUtil.SetPoint rounds only the offset. With a centred anchor and an odd
-- pixel width or height the frame's edges still land on half pixels, and WoW
-- then rounds each texture edge either way. So once the frame is placed and
-- sized, it is nudged by the fraction of a pixel that puts its bottom-left
-- corner on the pixel grid; its size is whole pixels, so every edge follows.
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
            -- The saved frame name and offsets are kept as they are.
            ns.attachmentPending = true
        end
    end
    if ns.attachmentPending then
        StartAttachRetry()
    else
        StopAttachRetry()
    end
    -- SetPoint raises an error for anchors WoW refuses (the tracker itself, a
    -- frame anchored to the tracker, a protected frame in combat). Fall back
    -- to the default screen position instead of breaking the whole layout.
    -- PixelUtil.SetPoint rounds the offsets to whole pixels as well.
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

    -- A screen position that leaves none of the visible points on screen (a
    -- damaged or imported profile, one saved at another resolution, or the
    -- offsets of an attachment whose frame does not exist yet, which only make
    -- sense against that frame) is shown at the default position instead. The
    -- saved value is not changed. Not done once attached to another frame:
    -- only that frame knows where the tracker belongs.
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

    -- The settings window shows one color button and one preview point per
    -- real point, so tell it when the maximum changes (talent or spec change).
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
    -- Same maximum as the Colors tab and the preview.
    local maximum = maxPoints
    for index, point in ipairs(pointFrames) do
        point:SetShown(index <= maximum)
        SetPointVisual(point, index <= current, index)
    end

    -- The mouse area and the counter's centre depend only on how many points
    -- are visible (and on the layout, which ApplyLayout handles), so they are
    -- left alone on ordinary resource changes.
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

-- Single place that locks/unlocks dragging, so the slash commands, the Layout
-- tab button, and the frame picker all keep the button text in sync.
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

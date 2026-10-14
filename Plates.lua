-- PaTiAggro: the row number of a problem enemy ("1", "2" …) above its nameplate, coloured by state (lost red,
-- barely held yellow, unclear grey). The same number stands in front of the row in the panel (Aggro.Number).
-- Why: a row in the aggro panel cannot target in combat — which enemy a row shows is decided by addon code, and
-- WoW forbids re-pointing, moving or showing secure buttons in combat (docs/WOW_API_COMPAT.md, FOLLOW_UPS F17).
-- The normal nameplate can: the player clicks it, Blizzard's own click targets exactly that enemy.
-- Display only: Blizzard's plates are never changed. Our own small frame is a child of the plate (so it moves and
-- hides with it); forbidden plates and missing APIs are skipped.
local _, ns = ...
local UI = ns.UI

local Plates = {}
ns.Plates = Plates

local markers = {} -- plate frame -> our marker frame
local plateByUnit = {} -- token -> plate of the last Update (the plate may no longer be reported on REMOVED)

local function plateOf(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) or type(unit) ~= "string" then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or type(plate) ~= "table" then return nil end
    if plate.IsForbidden then
        local checked, forbidden = pcall(plate.IsForbidden, plate)
        if not checked or forbidden then return nil end
    end
    return plate
end

local function markerFor(plate)
    if markers[plate] then return markers[plate] end
    local ok, marker = pcall(CreateFrame, "Frame", nil, plate)
    if not ok or not marker then return nil end
    marker:SetSize(18, 22)
    marker:SetPoint("BOTTOM", plate, "TOP", 0, 2)
    marker.text = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge") -- plain digits only (font-safe)
    marker.text:SetPoint("CENTER")
    marker:Hide()
    markers[plate] = marker
    return marker
end

local STATE_COLOR = { LOST = "Danger", DANGER = "Warning", UNKNOWN = "TextMuted" }

-- marks: { { unit = "nameplateN", number = n, state = "LOST" | "DANGER" | "UNKNOWN" } } from the panel's numbered
-- rows. Every other marker is hidden. Two marks on one plate are ambiguous: that plate shows nothing.
function Plates.Update(marks, enabled)
    local wanted, count = {}, {}
    plateByUnit = {}
    if enabled then
        for _, mark in ipairs(marks) do
            local plate = STATE_COLOR[mark.state] and mark.number and plateOf(mark.unit)
            if plate then
                wanted[plate] = mark
                count[plate] = (count[plate] or 0) + 1
                plateByUnit[mark.unit] = plate
            end
        end
    end
    for plate in pairs(wanted) do
        if count[plate] == 1 then markerFor(plate) else wanted[plate] = nil end
    end
    for plate, marker in pairs(markers) do
        local mark = wanted[plate]
        if mark then
            marker.text:SetText(tostring(mark.number))
            marker.text:SetTextColor(UI.Color(STATE_COLOR[mark.state]))
        end
        marker:SetShown(mark ~= nil)
    end
end

-- A plate got a new unit (NAME_PLATE_UNIT_ADDED) or loses its unit (…_REMOVED): its old number must not stay on
-- the next enemy. Called synchronously from the event, before the next scan decides again. The marker is hidden
-- and its number removed (a reused plate starts empty).
function Plates.Clear(unit)
    local plate = plateOf(unit) or plateByUnit[unit]
    plateByUnit[unit] = nil
    local marker = plate and markers[plate]
    if marker then
        marker:Hide()
        marker.text:SetText("")
    end
end

function Plates.HideAll()
    for _, marker in pairs(markers) do marker:Hide() end
end

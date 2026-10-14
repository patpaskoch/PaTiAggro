-- PaTiAggro nameplate numbers with mocked plates. Run via PaTiAdmin/tools/check.sh. Frames are plain tables here;
-- whether WoW draws them on real nameplates is a manual test.
local wow = require("wow_api")

local function newFrame()
    local frame = { shown = true }
    function frame:SetSize() end
    function frame:SetPoint() end
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end
    function frame:SetShown(shown) self.shown = shown and true or false end
    function frame:CreateFontString()
        local text = {}
        text.SetPoint = function() end
        text.SetText = function(fontString, value) fontString.value = value end
        text.SetTextColor = function(fontString, r) fontString.red = r end
        return text
    end
    return frame
end

local plates, created

local COLORS = { Danger = 1, Warning = 0.5, TextMuted = 0.25 }
local function setup()
    wow.install()
    plates, created = {}, {}
    _G.C_NamePlate = { GetNamePlateForUnit = function(unit) return plates[unit] end }
    _G.CreateFrame = function(_, _, parent)
        local frame = newFrame()
        frame.parent = parent
        created[#created + 1] = frame
        return frame
    end
    local ns = { UI = { Color = function(name) return COLORS[name], 0, 0, 1 end } }
    return wow.loadAddonFile("Plates.lua", ns).Plates
end

local function plate(forbidden)
    local frame = newFrame()
    function frame:IsForbidden() return forbidden == true end
    return frame
end

local function markerOn(frame)
    for _, marker in ipairs(created) do
        if marker.parent == frame then return marker end
    end
end

local function mark(unit, number, state) return { unit = unit, number = number, state = state } end

describe("Plates", function()
    it("shows each row's number on its own plate, coloured by state", function()
        local Plates = setup()
        plates.nameplate1, plates.nameplate2, plates.nameplate3 = plate(), plate(), plate()
        Plates.Update({ mark("nameplate1", 1, "LOST"), mark("nameplate2", 2, "DANGER"), mark("nameplate3", 3, "UNKNOWN") }, true)
        local lost, danger, unknown = markerOn(plates.nameplate1), markerOn(plates.nameplate2), markerOn(plates.nameplate3)
        assert.same({ true, "1", 1 }, { lost.shown, lost.text.value, lost.text.red })
        assert.same({ true, "2", 0.5 }, { danger.shown, danger.text.value, danger.text.red })
        assert.same({ true, "3", 0.25 }, { unknown.shown, unknown.text.value, unknown.text.red })
    end)

    it("marks nothing for controlled enemies, marks without a number, or two marks on one plate", function()
        local Plates = setup()
        plates.nameplate1, plates.nameplate2 = plate(), plate()
        plates.nameplate9 = plates.nameplate2 -- two tokens, one plate (must never happen; if it does: ambiguous)
        Plates.Update({ mark("nameplate1", 1, "CONTROLLED"), mark("nameplate1", nil, "LOST"),
            mark("nameplate2", 2, "LOST"), mark("nameplate9", 3, "LOST") }, true)
        assert.equal(0, #created)
    end)

    it("hides the marker when the enemy drops out of the rows or marking is off", function()
        local Plates = setup()
        plates.nameplate1 = plate()
        Plates.Update({ mark("nameplate1", 1, "LOST") }, true)
        local marker = markerOn(plates.nameplate1)
        Plates.Update({}, true)
        assert.is_false(marker.shown)
        Plates.Update({ mark("nameplate1", 1, "LOST") }, false)
        assert.is_false(marker.shown)
    end)

    it("clears the number of a removed or reused plate, even if WoW no longer reports the plate", function()
        local Plates = setup()
        plates.nameplate3 = plate()
        Plates.Update({ mark("nameplate3", 2, "LOST") }, true)
        local marker = markerOn(plates.nameplate3)
        local frame = plates.nameplate3
        plates.nameplate3 = nil -- NAME_PLATE_UNIT_REMOVED: the token has no plate any more
        Plates.Clear("nameplate3")
        assert.is_false(marker.shown)
        assert.equal("", marker.text.value)
        Plates.Update({ mark("nameplate3", 2, "LOST") }, true)
        plates.nameplate3 = frame -- reused for another enemy (NAME_PLATE_UNIT_ADDED): starts empty
        Plates.Clear("nameplate3")
        assert.is_false(marker.shown)
        assert.equal("", marker.text.value)
    end)

    it("never touches forbidden plates and survives a missing nameplate API", function()
        local Plates = setup()
        plates.nameplate1 = plate(true)
        Plates.Update({ mark("nameplate1", 1, "LOST") }, true)
        assert.equal(0, #created)
        _G.C_NamePlate = nil
        Plates.Update({ mark("nameplate1", 1, "LOST") }, true)
        Plates.Clear("nameplate1")
        assert.equal(0, #created)
    end)
end)

-- PaTiAggro aggro control rules. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Aggro.lua", {}).Aggro
end

describe("Aggro.Classify", function()
    it("maps your threat situation to controlled / danger", function()
        local Aggro = load()
        assert.equal("CONTROLLED", Aggro.Classify({ playerStatus = 3 }))
        assert.equal("DANGER", Aggro.Classify({ playerStatus = 2 }))
    end)

    it("is LOST when a group member holds it, also if you never touched it", function()
        local Aggro = load()
        assert.equal("LOST", Aggro.Classify({ playerStatus = 0, holder = { role = "HEALER" } }))
        assert.equal("LOST", Aggro.Classify({ playerStatus = nil, holder = { role = "HEALER" } }))
        assert.equal("LOST", Aggro.Classify({ playerStatus = 1 })) -- held by someone outside the group
    end)

    it("never turns unreadable data into CONTROLLED", function()
        local Aggro = load()
        assert.equal("UNKNOWN", Aggro.Classify({ playerStatus = Aggro.UNREADABLE }))
        assert.equal("UNKNOWN", Aggro.Classify({ playerStatus = nil, holderUnreadable = true }))
    end)

    it("ignores enemies nobody of the group fights", function()
        assert.is_nil(load().Classify({ playerStatus = nil }))
    end)
end)

describe("Aggro.Summarize", function()
    it("counts held enemies and lists LOST before DANGER before UNKNOWN", function()
        local Aggro = load()
        local enemies = {
            { name = "a", state = "CONTROLLED" }, { name = "b", state = "UNKNOWN" }, { name = "c", state = "DANGER" },
            { name = "d", state = "LOST" }, { name = "e", state = "CONTROLLED" }, { name = "f", state = "LOST" },
            { name = "g" }, -- not our fight
        }
        local summary = Aggro.Summarize(enemies)
        assert.equal(3, summary.held)  -- 2 controlled + 1 danger
        assert.equal(6, summary.total)
        local names = {}
        for _, enemy in ipairs(summary.rows) do names[#names + 1] = enemy.name end
        assert.same({ "d", "f", "c", "b" }, names)
    end)

    it("is empty without enemies", function()
        assert.same({ held = 0, total = 0, rows = {} }, load().Summarize({}))
    end)
end)

describe("Aggro.HolderLabel", function()
    it("prefers the role, then the name, then 'other player'", function()
        local Aggro = load()
        assert.equal("ROLE_HEALER", Aggro.HolderLabel({ role = "HEALER", hasName = true }))
        assert.equal("NAME", Aggro.HolderLabel({ hasName = true }))
        assert.equal("OTHER", Aggro.HolderLabel({}))
        assert.equal("OTHER", Aggro.HolderLabel(nil))
    end)
end)

describe("Aggro.Number", function()
    local function row(unit, guid, state) return { unit = unit, guid = guid, state = state or "LOST" } end

    it("numbers the visible problem rows with their own nameplate, in row order", function()
        local Aggro = load()
        local numbers = Aggro.Number({ row("nameplate4", "A"), row("nameplate2", "B", "DANGER"),
            row("nameplate7", "C", "UNKNOWN") }, {})
        assert.same({ 1, 2, 3 }, numbers)
    end)

    it("gives no number to a row without a nameplate token, and none to two rows sharing a token", function()
        local Aggro = load()
        assert.same({ [1] = 1 }, (Aggro.Number({ row("nameplate1", "A"), row("target", "B"), row(nil, nil) }, {})))
        local numbers = Aggro.Number({ row("nameplate1", "A"), row("nameplate1", nil), row("nameplate2", "C") }, {})
        assert.is_nil(numbers[1])
        assert.is_nil(numbers[2])
        assert.equal(1, numbers[3])
    end)

    it("keeps an enemy's number while it stays visible, also when the row order changes", function()
        local Aggro = load()
        local _, map = Aggro.Number({ row("nameplate1", "A"), row("nameplate2", "B") }, {})
        assert.same({ A = 1, B = 2 }, map)
        local numbers = Aggro.Number({ row("nameplate2", "B"), row("nameplate1", "A") }, map) -- B now sorts first
        assert.same({ 2, 1 }, numbers)
    end)

    it("reuses freed numbers, forgets enemies that left, never keeps a number above MAX_ROWS", function()
        local Aggro = load()
        local numbers, map = Aggro.Number({ row("nameplate3", "C"), row("nameplate9", "N") }, { A = 1, C = 2, X = 9 })
        assert.same({ 2, 1 }, numbers) -- C keeps 2, the new enemy takes the free 1
        assert.same({ C = 2, N = 1 }, map)
        assert.same({ 1 }, (Aggro.Number({ row("nameplate1", "X") }, { X = 9 })))
    end)

    it("keeps no number for enemies without a readable GUID", function()
        local _, map = load().Number({ row("nameplate1", nil) }, {})
        assert.same({}, map)
    end)
end)

describe("Aggro.Alerts (for the optional PaTiAlerts)", function()
    local SECRET = setmetatable({}, { __eq = function() error("secret compared") end,
        __concat = function() error("secret concatenated") end })
    local function isSecret(value) return rawequal(value, SECRET) end
    local function detail(enemy) return enemy.state == "DANGER" and "barely held" or "Healer" end

    it("sends LOST as CRITICAL and DANGER as WARNING, with the panel/nameplate number", function()
        local Aggro = load()
        local rows = { { state = "LOST", guid = "G1", unit = "nameplate3", name = "Kultist" },
            { state = "DANGER", guid = "G2", unit = "nameplate5", name = "Zombie" } }
        local alerts = Aggro.Alerts(rows, { 1, 2 }, detail, "Unknown enemy", isSecret)
        assert.same({ id = "aggro:G1", priority = "CRITICAL", kind = "AGGRO_LOST", number = 1, name = "Kultist",
            detail = "Healer" }, alerts[1])
        assert.same({ id = "aggro:G2", priority = "WARNING", kind = "AGGRO_DANGER", number = 2, name = "Zombie",
            detail = "barely held" }, alerts[2])
    end)

    it("sends nothing for CONTROLLED or UNKNOWN, so a controlled enemy's alert disappears", function()
        local Aggro = load()
        local rows = { { state = "CONTROLLED", guid = "G1", name = "A" }, { state = "UNKNOWN", guid = "G2", name = "B" } }
        assert.same({}, Aggro.Alerts(rows, {}, detail, "?", isSecret))
    end)

    it("keeps a secret name for display only, uses the token without a GUID, and no number without one", function()
        local Aggro = load()
        local alerts = Aggro.Alerts({ { state = "LOST", unit = "target", name = SECRET },
            { state = "LOST", guid = "G9" } }, {}, detail, "Unknown enemy", isSecret)
        assert.equal("aggro:target", alerts[1].id)
        assert.is_true(rawequal(SECRET, alerts[1].name))
        assert.is_nil(alerts[1].number)
        assert.equal("Unknown enemy", alerts[2].text)
    end)
end)

describe("Aggro.CurrentRows", function()
    local me, mage, healer = { name = "Brom" }, { name = "Lyra" }, { name = "Mira" }

    it("puts the aggro holder first, then sorts by percent, with states by 70/90", function()
        local Aggro = load()
        local rows = Aggro.CurrentRows({ { holder = healer, percent = 35 }, { holder = me, percent = 100, tanking = true,
            isPlayer = true }, { holder = mage, percent = 91.6 } }, 6)
        assert.same({ me, mage, healer }, { rows[1].holder, rows[2].holder, rows[3].holder })
        assert.same({ "HOLDS", "DANGER", "GOOD" }, { rows[1].state, rows[2].state, rows[3].state })
        assert.equal(92, rows[2].percent)
        assert.is_true(rows[1].isPlayer)
        assert.equal("WARNING", Aggro.CurrentRows({ { holder = mage, percent = 70 } }, 6)[1].state)
    end)

    it("puts unreadable values last and never as GOOD, and keeps at most max rows", function()
        local Aggro = load()
        local rows = Aggro.CurrentRows({ { holder = mage, percent = Aggro.UNREADABLE }, { holder = healer, percent = 5 },
            { holder = me, percent = 50 } }, 2)
        assert.equal(2, #rows)
        assert.same({ me, healer }, { rows[1].holder, rows[2].holder })
        assert.equal("UNKNOWN", Aggro.CurrentRows({ { holder = mage, percent = Aggro.UNREADABLE } }, 6)[1].state)
    end)
end)

describe("Aggro.SelfThreat", function()
    it("colours the tank by status, never by percent", function()
        local Aggro = load()
        assert.equal("GOOD", Aggro.SelfThreat("TANK", 3, 100).state)
        assert.equal("WARNING", Aggro.SelfThreat("TANK", 2, 100).state)
        assert.equal("DANGER", Aggro.SelfThreat("TANK", 0, 80).state)
        assert.is_nil(Aggro.SelfThreat("TANK", nil, nil))
    end)

    it("warns healer and damage by percent and flags real aggro", function()
        local Aggro = load()
        assert.equal("GOOD", Aggro.SelfThreat("HEALER", 0, 69).state)
        assert.equal("WARNING", Aggro.SelfThreat("DAMAGER", 1, 70).state)
        assert.equal("DANGER", Aggro.SelfThreat("DAMAGER", 1, 89.6).state)
        assert.equal(90, Aggro.SelfThreat("DAMAGER", 1, 89.6).percent)
        assert.equal("AGGRO", Aggro.SelfThreat("HEALER", 3, 100).state)
        assert.equal("AGGRO", Aggro.SelfThreat("HEALER", 2, 100).state)
        assert.is_nil(Aggro.SelfThreat("HEALER", nil, nil))
    end)

    it("never turns unreadable values into GOOD", function()
        local Aggro = load()
        assert.equal("UNKNOWN", Aggro.SelfThreat("TANK", Aggro.UNREADABLE, 100).state)
        assert.equal("UNKNOWN", Aggro.SelfThreat("HEALER", 0, Aggro.UNREADABLE).state)
    end)
end)

describe("Aggro.SelfWorst", function()
    it("picks the worst state, then the higher percent, and counts enemies on you", function()
        local Aggro = load()
        local worst = Aggro.SelfWorst({ { state = "GOOD", percent = 20 }, { state = "WARNING", percent = 71 },
            { state = "WARNING", percent = 85 } })
        assert.equal("WARNING", worst.state)
        assert.equal(85, worst.percent)
        worst = Aggro.SelfWorst({ { state = "AGGRO" }, { state = "DANGER", percent = 95 }, { state = "AGGRO" } })
        assert.equal("AGGRO", worst.state)
        assert.equal(2, worst.onYou)
        assert.is_nil(Aggro.SelfWorst({}))
    end)

    it("lets an unreadable enemy beat WARNING but not a readable DANGER", function()
        local Aggro = load()
        assert.equal("UNKNOWN", Aggro.SelfWorst({ { state = "WARNING", percent = 80 }, { state = "UNKNOWN" } }).state)
        assert.equal("DANGER", Aggro.SelfWorst({ { state = "DANGER", percent = 92 }, { state = "UNKNOWN" } }).state)
    end)
end)

describe("Aggro.OnYou", function()
    it("lists the enemies that attack you as red rows, leaving the scan untouched", function()
        local Aggro = load()
        local enemies = { { name = "A", playerStatus = 3, state = "CONTROLLED" }, { name = "B", playerStatus = 0 },
            { name = "C", playerStatus = 2, state = "DANGER" } }
        local rows = Aggro.OnYou(enemies)
        assert.equal(2, #rows)
        assert.equal("A", rows[1].name)
        assert.equal("LOST", rows[1].state)
        assert.is_true(rows[2].onYou)
        assert.equal("CONTROLLED", enemies[1].state)
    end)
end)

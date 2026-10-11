-- PaTiTank aggro control rules. Run via PaTiAdmin/tools/check.sh.
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

describe("Aggro.NextThreat", function()
    local healer, mage = { role = "HEALER" }, { name = "Magier", hasName = true }

    it("names the member closest to pulling, with the state by distance", function()
        local Aggro = load()
        local result = Aggro.NextThreat(true, { { holder = healer, percent = 40 }, { holder = mage, percent = 91.6 } })
        assert.equal(mage, result.holder)
        assert.equal(92, result.percent)
        assert.equal("DANGER", result.state)
        assert.equal("WARNING", Aggro.NextThreat(true, { { holder = mage, percent = 70 } }).state)
        assert.equal("LOW", Aggro.NextThreat(true, { { holder = mage, percent = 69 } }).state)
    end)

    it("shows nothing when you do not tank the target or nobody else is on it", function()
        local Aggro = load()
        assert.is_nil(Aggro.NextThreat(false, { { holder = mage, percent = 95 } }))
        assert.is_nil(Aggro.NextThreat(true, {}))
    end)

    it("never reports LOW or WARNING while a value is unreadable", function()
        local Aggro = load()
        local U = Aggro.UNREADABLE
        assert.equal("UNKNOWN", Aggro.NextThreat(U, {}).state)
        local hidden = { holder = healer, percent = U }
        assert.equal("UNKNOWN", Aggro.NextThreat(true, { { holder = mage, percent = 50 }, hidden }).state)
        -- a readable danger is still shown: it is true whatever the unreadable member has
        assert.equal("DANGER", Aggro.NextThreat(true, { { holder = mage, percent = 95 }, hidden }).state)
    end)
end)

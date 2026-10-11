-- PaTiTank threat adapter with mocked WoW APIs. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local SECRET = setmetatable({}, { __lt = function() error("secret compared") end, __le = function() error("secret compared") end })

local world

local function setup(units, threat)
    wow.install()
    world = { units = units, threat = threat or {} } -- threat[enemyToken][memberToken] = status
    _G.issecretvalue = function(value) return rawequal(value, SECRET) end
    _G.UnitExists = function(unit) return world.units[unit] ~= nil end
    _G.UnitCanAttack = function(_, unit) return world.units[unit].enemy == true end
    _G.UnitIsDead = function(unit) return world.units[unit].dead == true end
    _G.UnitGUID = function(unit) return world.units[unit].guid end
    _G.UnitName = function(unit) return world.units[unit].name end
    _G.UnitGroupRolesAssigned = function(unit) return world.units[unit].role or "NONE" end
    _G.UnitThreatSituation = function(member, enemy)
        local byEnemy = world.threat[enemy]
        return byEnemy and byEnemy[member]
    end
    local ns = wow.loadAddonFile("Aggro.lua", {})
    return wow.loadAddonFile("Threat.lua", ns)
end

local function byName(enemies)
    local result = {}
    for _, enemy in ipairs(enemies) do result[enemy.name] = enemy end
    return result
end

describe("Threat.Scan", function()
    it("finds nameplate enemies, de-duplicates the target and names the holder's role", function()
        local ns = setup({
            player = {}, party1 = { name = "Heila", role = "HEALER" },
            target = { enemy = true, guid = "G1", name = "Skelettkrieger" },
            nameplate1 = { enemy = true, guid = "G1", name = "Skelettkrieger" },
            nameplate2 = { enemy = true, guid = "G2", name = "Kultist" },
        }, {
            target = { player = 0, party1 = 3 }, nameplate1 = { player = 0, party1 = 3 },
            nameplate2 = { player = 3 },
        })
        ns.Threat.PlateAdded("nameplate1")
        ns.Threat.PlateAdded("nameplate2")
        local enemies = byName(ns.Threat.Scan())
        assert.equal("LOST", enemies.Skelettkrieger.state)
        assert.equal("HEALER", enemies.Skelettkrieger.holder.role)
        assert.equal("CONTROLLED", enemies.Kultist.state)
        local count = 0
        for _ in pairs(enemies) do count = count + 1 end
        assert.equal(2, count) -- target and nameplate1 are the same enemy
        assert.equal("nameplate1", enemies.Skelettkrieger.unit) -- keeps its nameplate token (for the plate marker)
        assert.equal("G1", enemies.Skelettkrieger.guid) -- readable GUID: key for stable numbers
    end)

    it("turns secret threat or member data into UNKNOWN, never CONTROLLED", function()
        local ns = setup({
            player = {}, party1 = { name = "X" },
            nameplate1 = { enemy = true, guid = "G1", name = "A" },
            nameplate2 = { enemy = true, guid = "G2", name = "B" },
        }, { nameplate1 = { player = SECRET }, nameplate2 = { player = nil, party1 = SECRET } })
        ns.Threat.PlateAdded("nameplate1")
        ns.Threat.PlateAdded("nameplate2")
        local enemies = byName(ns.Threat.Scan())
        assert.equal("UNKNOWN", enemies.A.state)
        assert.equal("UNKNOWN", enemies.B.state)
    end)

    it("never uses a secret GUID as identity", function()
        local ns = setup({
            player = {},
            nameplate1 = { enemy = true, guid = SECRET, name = "A" },
        }, { nameplate1 = { player = 0 } })
        ns.Threat.PlateAdded("nameplate1")
        local enemies = ns.Threat.Scan()
        assert.equal(1, #enemies)
        assert.is_nil(enemies[1].guid)
    end)

    it("skips dead enemies, friendly units and enemies nobody of the group fights", function()
        local ns = setup({
            player = {},
            nameplate1 = { enemy = true, dead = true, guid = "G1", name = "Dead" },
            nameplate2 = { enemy = false, guid = "G2", name = "Friend" },
            nameplate3 = { enemy = true, guid = "G3", name = "Idle" },
        }, { nameplate1 = { player = 3 } })
        for index = 1, 3 do ns.Threat.PlateAdded("nameplate" .. index) end
        assert.same({}, ns.Threat.Scan())
    end)

    it("forgets removed nameplates and skips a target with an unreadable GUID when nameplates exist", function()
        local ns = setup({
            player = {},
            target = { enemy = true, guid = SECRET, name = "T" },
            nameplate1 = { enemy = true, guid = "G1", name = "P" },
        }, { target = { player = 3 }, nameplate1 = { player = 3 } })
        ns.Threat.PlateAdded("nameplate1")
        local enemies = ns.Threat.Scan()
        assert.equal(1, #enemies)
        assert.equal("P", enemies[1].name)
        ns.Threat.PlateRemoved("nameplate1")
        enemies = ns.Threat.Scan() -- no nameplates any more: the target counts even without a readable GUID
        assert.equal(1, #enemies)
        assert.equal("T", enemies[1].name)
    end)
end)

describe("Threat.Next", function()
    local function withDetailed(units, detail) -- detail[unit] = { tanking, percent }
        local ns = setup(units)
        _G.UnitDetailedThreatSituation = function(unit)
            local entry = detail[unit]
            if not entry then return nil end
            return entry[1], nil, entry[2]
        end
        return ns
    end

    it("reads whether you tank and every member on the threat list", function()
        local ns = withDetailed({ player = {}, party1 = { name = "Heila", role = "HEALER" }, party2 = { name = "Mage" } },
            { player = { true, 100 }, party1 = { false, 81 } })
        local tanking, others = ns.Threat.Next("target")
        assert.is_true(tanking)
        assert.equal(1, #others) -- party2 is not on the threat list
        assert.equal("HEALER", others[1].holder.role)
        assert.equal(81, others[1].percent)
    end)

    it("turns secret values and API errors into UNREADABLE", function()
        local ns = withDetailed({ player = {}, party1 = { name = "A" } }, { player = { SECRET, 100 }, party1 = { false, SECRET } })
        local tanking, others = ns.Threat.Next("target")
        assert.equal(ns.Aggro.UNREADABLE, tanking)
        assert.equal(ns.Aggro.UNREADABLE, others[1].percent)
        _G.UnitDetailedThreatSituation = function() error("boom") end
        tanking = ns.Threat.Next("target")
        assert.equal(ns.Aggro.UNREADABLE, tanking)
    end)

    it("shows nothing without the API", function()
        local ns = withDetailed({ player = {} }, {})
        _G.UnitDetailedThreatSituation = nil
        local tanking, others = ns.Threat.Next("target")
        assert.is_false(tanking)
        assert.same({}, others)
    end)
end)

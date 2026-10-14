-- PaTiAggro: threat adapter (the only place with threat/nameplate API calls).
-- Reads the enemies WoW exposes through unit tokens — your target, visible nameplates, your party's targets —
-- and the threat situation of you and your group on each. It never targets or acts. Every value is checked for
-- secrecy before it is compared; anything unreadable becomes Aggro.UNREADABLE (→ state UNKNOWN).
local _, ns = ...
local Aggro = ns.Aggro

local Threat = {}
ns.Threat = Threat

local UNREADABLE = Aggro.UNREADABLE
local GROUP = { "party1", "party2", "party3", "party4", "pet" }
local PARTY_TARGETS = { "party1target", "party2target", "party3target", "party4target" }
local plates = {} -- nameplate tokens currently shown (NAME_PLATE_UNIT_ADDED/REMOVED), so we never loop 1..40

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

-- true/false for a readable yes/no API value (true/false or 1/nil), nil when it is secret.
local function flag(value)
    if isSecret(value) then return nil end
    return value == true or value == 1
end

function Threat.PlateAdded(unit) if type(unit) == "string" then plates[unit] = true end end
function Threat.PlateRemoved(unit) if type(unit) == "string" then plates[unit] = nil end end

-- UnitThreatSituation(unit, enemy): 0-3 or nil; UNREADABLE for secret values, API errors or a missing API.
local function situation(unit, enemy)
    if not UnitThreatSituation then return UNREADABLE end
    local ok, status = pcall(UnitThreatSituation, unit, enemy)
    if not ok then Threat.lastError = tostring(status):sub(1, 120) end -- /paggro debug only
    if not ok or isSecret(status) then return UNREADABLE end
    if status ~= nil and type(status) ~= "number" then return UNREADABLE end
    return status
end

-- A living enemy you could attack. Unreadable → not counted (we do not guess that it is hostile).
local function isEnemy(unit)
    if not (UnitCanAttack and UnitIsDead) then return false end -- APIs missing: show no enemies rather than error
    if flag(UnitExists(unit)) ~= true then return false end
    if flag(UnitCanAttack("player", unit)) ~= true then return false end
    return flag(UnitIsDead(unit)) == false
end

local function role(unit)
    if unit == "pet" then return "PET" end
    local value = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if isSecret(value) then return nil end
    if value == "TANK" or value == "HEALER" or value == "DAMAGER" then return value end
    return nil
end

-- Name values are only handed to SetText, never compared; hasName records whether there is one to show.
local function holderOf(member)
    local name = UnitName(member)
    return { unit = member, role = role(member), name = name, hasName = isSecret(name) or name ~= nil }
end

local function readEnemy(unit)
    local enemy = { unit = unit, name = UnitName(unit), playerStatus = situation("player", unit) }
    enemy.playerPercent = select(2, Threat.Self(unit)) -- your scaled percent (healer/damage view)
    if enemy.playerStatus == 3 or enemy.playerStatus == 2 then return enemy end -- you hold it: no holder search
    local candidate
    for _, member in ipairs(GROUP) do
        if flag(UnitExists(member)) == true then
            local status = situation(member, unit)
            if status == UNREADABLE then
                enemy.holderUnreadable = true
            elseif status == 3 then
                enemy.holder = holderOf(member)
                return enemy
            elseif status == 2 and not candidate then
                candidate = member
            end
        end
    end
    if candidate then enemy.holder = holderOf(candidate) end
    return enemy
end

-- GUID for de-duplication (the same enemy can be target, nameplate and party target at once); nil if unreadable.
local function guidOf(unit)
    local guid = UnitGUID and UnitGUID(unit)
    if isSecret(guid) or type(guid) ~= "string" then return nil end -- secrecy first; only plain strings are keys
    return guid
end

-- All enemies the group fights, each with .state (Aggro.Classify). Called at most every SCAN_DELAY seconds.
function Threat.Scan()
    local enemies, seen = {}, {}
    local function consider(unit, needsGuid)
        if not isEnemy(unit) then return end
        local id = guidOf(unit)
        if id == nil then
            if needsGuid then return end -- could duplicate a nameplate; nameplates already cover it
            id = unit
        end
        if seen[id] then return end
        seen[id] = true
        local enemy = readEnemy(unit)
        enemy.guid = id ~= unit and id or nil -- readable GUID only (number stability in Aggro.Number)
        enemy.state = Aggro.Classify(enemy)
        if enemy.state then enemies[#enemies + 1] = enemy end
    end
    -- Nameplates first: an enemy that is also your target keeps its nameplate token (Plates.lua marks that plate).
    local hasPlates = next(plates) ~= nil
    for unit in pairs(plates) do consider(unit, false) end
    consider("target", hasPlates)
    for _, unit in ipairs(PARTY_TARGETS) do consider(unit, true) end
    return enemies
end

-- UnitDetailedThreatSituation(unit, enemy) → isTanking, status, scaledPercent, …; returned as tanking, percent, status
-- (nil percent/status = not on its threat list). Secret values, API errors or odd types become UNREADABLE (checked
-- before any comparison).
local function detailed(unit, enemy)
    local ok, tanking, status, percent = pcall(UnitDetailedThreatSituation, unit, enemy)
    if not ok then
        Threat.lastError = tostring(tanking):sub(1, 120) -- /paggro debug only
        return UNREADABLE, UNREADABLE, UNREADABLE
    end
    if isSecret(tanking) then tanking = UNREADABLE else tanking = tanking == true or tanking == 1 end
    if isSecret(percent) or (percent ~= nil and type(percent) ~= "number") then percent = UNREADABLE end
    if isSecret(status) or (status ~= nil and type(status) ~= "number") then status = UNREADABLE end
    return tanking, percent, status
end

-- Input of Aggro.NextThreat for one enemy (e.g. "target"): whether you tank it, and the threat of every group member
-- on it (members not on its threat list are left out). No API → you are not known to tank it: nothing to show.
function Threat.Next(enemy)
    if not UnitDetailedThreatSituation then return false, {} end
    local tanking = detailed("player", enemy)
    local others = {}
    for _, member in ipairs(GROUP) do
        if flag(UnitExists(member)) == true then
            local _, percent = detailed(member, enemy)
            if percent ~= nil then others[#others + 1] = { holder = holderOf(member), percent = percent } end
        end
    end
    return tanking, others
end

-- Your own threat on one enemy: status (0-3) and scaled percent; nil = not on its threat list, UNREADABLE = secret or
-- an API error. No API → nil, nil (nothing known, nothing shown).
function Threat.Self(enemy)
    if not UnitDetailedThreatSituation then return nil, nil end
    local _, percent, status = detailed("player", enemy)
    return status, percent
end

-- The group role WoW reports for you (TANK / HEALER / DAMAGER), nil without one or when it is secret.
function Threat.PlayerRole()
    local value = role("player")
    if value == "PET" then return nil end
    return value
end

-- An enemy with no threat yet (nobody attacked it) is on no threat list: Threat.Self gives nil. The window shows 0 %
-- for it, but only when that is true — the threat API exists and the unit is a living enemy you could attack.
function Threat.ZeroThreat(unit)
    return UnitDetailedThreatSituation ~= nil and isEnemy(unit)
end

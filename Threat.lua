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
    local class = UnitClass and UnitClass(member) -- localized class name; may be secret (shown only when readable)
    return { unit = member, role = role(member), name = name, hasName = isSecret(name) or name ~= nil, class = class }
end

-- Status 2 = you still tank it, but someone has more threat and is about to take it: that member (status 1 on it)
-- is shown on the yellow row instead of a vague "slipping" (owner 2026-10-14).
local function challengerOf(unit)
    for _, member in ipairs(GROUP) do
        if flag(UnitExists(member)) == true and situation(member, unit) == 1 then return holderOf(member) end
    end
    return nil
end

local function readEnemy(unit)
    local enemy = { unit = unit, name = UnitName(unit), playerStatus = situation("player", unit) }
    enemy.playerPercent = select(2, Threat.Self(unit)) -- your scaled percent (healer/damage view)
    if enemy.playerStatus == 3 then return enemy end -- you hold it: no holder search
    if enemy.playerStatus == 2 then
        enemy.challenger = challengerOf(unit)
        return enemy
    end
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

-- "AGGRO TARGET" for one enemy (e.g. "target", owner 2026-10-14): you and every group member on its threat list, each
-- with whether they tank it and their scaled percent (100 = they pull it). Members not on the list are left out;
-- you are always listed when the threat API exists (0 % on an enemy nobody attacked yet — Threat.ZeroThreat).
function Threat.Current(enemy)
    local list = {}
    if not UnitDetailedThreatSituation then return list end
    local function add(unit, isPlayer)
        local tanking, percent = detailed(unit, enemy)
        if percent == nil and tanking ~= true and not isPlayer then return end
        if isPlayer and percent == nil and tanking ~= true then
            if not Threat.ZeroThreat(enemy) then return end
            percent = 0
        end
        list[#list + 1] = { holder = holderOf(unit), percent = percent, tanking = tanking, isPlayer = isPlayer }
    end
    add("player", true)
    for _, member in ipairs(GROUP) do
        if flag(UnitExists(member)) == true then add(member, false) end
    end
    return list
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

-- Another group member has the WoW role Tank (pets and you excluded); unreadable roles count as no tank.
function Threat.OtherTank()
    for _, member in ipairs(GROUP) do
        if member ~= "pet" and flag(UnitExists(member)) == true and role(member) == "TANK" then return true end
    end
    return false
end

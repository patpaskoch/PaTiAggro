-- PaTiAggro: aggro control rules, no WoW API calls (tested in tests/aggro_spec.lua).
-- Answers one question: which enemies do I not hold any more? Display only — no target, no taunt.
local _, ns = ...
local Aggro = {}
ns.Aggro = Aggro

-- Sentinel the threat adapter uses for any value it could not read safely (secret value, API error).
Aggro.UNREADABLE = {}
Aggro.MAX_ROWS = 4 -- problem rows shown under the summary

-- UnitThreatSituation(you, enemy): 3 = you tank securely, 2 = you tank but someone has more threat,
-- 1/0 = someone else tanks, nil = you are not on the enemy's threat list.
-- enemy = { playerStatus = 0-3 | nil | UNREADABLE, holder = { role?, name? } | nil, holderUnreadable = bool }
-- Returns "CONTROLLED" | "DANGER" | "LOST" | "UNKNOWN", or nil when nobody of the group fights it.
function Aggro.Classify(enemy)
    local status = enemy.playerStatus
    if status == Aggro.UNREADABLE then return "UNKNOWN" end -- never guess "controlled"
    if status == 3 then return "CONTROLLED" end
    if status == 2 then return "DANGER" end
    if enemy.holder then return "LOST" end
    if enemy.holderUnreadable then return "UNKNOWN" end
    if status == 0 or status == 1 then return "LOST" end -- someone outside your group (or unseen) holds it
    return nil
end

local ORDER = { LOST = 1, DANGER = 2, UNKNOWN = 3 }

-- enemies: list with .state set. Returns { held, total, rows = { enemy, … } } — held = CONTROLLED + DANGER
-- (you still have them), rows = the enemies that need attention: LOST first, then DANGER, then UNKNOWN.
function Aggro.Summarize(enemies)
    local summary = { held = 0, total = 0, rows = {} }
    for index, enemy in ipairs(enemies) do
        if enemy.state then
            summary.total = summary.total + 1
            if enemy.state == "CONTROLLED" or enemy.state == "DANGER" then summary.held = summary.held + 1 end
            if ORDER[enemy.state] then summary.rows[#summary.rows + 1] = { enemy = enemy, index = index } end
        end
    end
    table.sort(summary.rows, function(a, b)
        local oa, ob = ORDER[a.enemy.state], ORDER[b.enemy.state]
        if oa ~= ob then return oa < ob end
        return a.index < b.index -- stable: keep the adapter's order within a state
    end)
    for index, row in ipairs(summary.rows) do summary.rows[index] = row.enemy end
    return summary
end

-- Numbers for the visible problem rows, so a row and its nameplate marker name the same enemy ("1 Kultist → Healer"
-- ↔ "1" above that Kultist). rows: Summarize(...).rows cut to MAX_ROWS; previous: guid -> number of the last paint.
-- Only rows with their own nameplate token get a number (the marker lives on exactly that plate); two rows with the
-- same token are ambiguous and get none — no number is better than a wrong one. A readable GUID (enemy.guid, never a
-- secret value) keeps its number while the enemy stays visible; the others take the lowest free numbers.
-- Returns numbers[rowIndex] (nil = no number) and the new guid -> number map.
function Aggro.Number(rows, previous)
    local tokenCount = {}
    for _, enemy in ipairs(rows) do
        if type(enemy.unit) == "string" and enemy.unit:match("^nameplate%d+$") then
            tokenCount[enemy.unit] = (tokenCount[enemy.unit] or 0) + 1
        end
    end
    local numbers, used, nextMap = {}, {}, {}
    local function eligible(enemy) return enemy.unit ~= nil and tokenCount[enemy.unit] == 1 end
    for index, enemy in ipairs(rows) do -- keep the numbers of enemies that had one
        local kept = eligible(enemy) and enemy.guid and previous[enemy.guid]
        if kept and kept <= Aggro.MAX_ROWS and not used[kept] then
            numbers[index], used[kept] = kept, true
        end
    end
    for index, enemy in ipairs(rows) do -- everyone else: lowest free number
        if eligible(enemy) and not numbers[index] then
            local free = 1
            while used[free] do free = free + 1 end
            numbers[index], used[free] = free, true
        end
        if numbers[index] and enemy.guid then nextMap[enemy.guid] = numbers[index] end
    end
    return numbers, nextMap
end

-- Alerts for PaTiAlerts (optional): one per visible LOST (CRITICAL) or DANGER (WARNING) row, carrying the same number
-- as the panel row and the nameplate (numbers = Aggro.Number result; no number → none). UNKNOWN and CONTROLLED send
-- nothing. The id is the readable GUID or the unit token — never a name. A name may be secret: it goes into `name`
-- (display only) after the secrecy check; detailOf(enemy) must return a plain string.
function Aggro.Alerts(rows, numbers, detailOf, unknownName, isSecret)
    local list = {}
    for index, enemy in ipairs(rows) do
        local priority = (enemy.state == "LOST" and "CRITICAL") or (enemy.state == "DANGER" and "WARNING") or nil
        local id = enemy.guid or (type(enemy.unit) == "string" and enemy.unit) or nil
        if priority and id then
            local alert = { id = "aggro:" .. id, priority = priority, number = numbers[index],
                kind = priority == "CRITICAL" and "AGGRO_LOST" or "AGGRO_DANGER", detail = detailOf(enemy) }
            local name = enemy.name
            if isSecret(name) or name ~= nil then alert.name = name else alert.text = unknownName end
            list[#list + 1] = alert
        end
    end
    return list
end

-- What to show for the member holding a lost enemy: a role key, "NAME" (show holder.name as-is) or "OTHER".
-- Role first (quickest to read), then name, then "other player".
function Aggro.HolderLabel(holder)
    if not holder then return "OTHER" end
    if holder.role == "TANK" or holder.role == "HEALER" or holder.role == "DAMAGER" or holder.role == "PET" then
        return "ROLE_" .. holder.role
    end
    if holder.hasName then return "NAME" end
    return "OTHER"
end

-- Thresholds of the scaled percent (owner 2026-10-14: 70/90 suite wide): 100 = that member pulls aggro now (WoW
-- already counts the 110 % melee / 130 % ranged rule). Warning from NEXT_WARN, danger from NEXT_DANGER.
Aggro.NEXT_WARN, Aggro.NEXT_DANGER = 70, 90

-- "AGGRO TARGET" rows for one enemy (owner 2026-10-14): entries from Threat.Current, sorted — the one who has the aggro
-- first, then by percent, unreadable last. Each row gets .state: "HOLDS" (has the aggro), "GOOD" (below NEXT_WARN),
-- "WARNING" (from NEXT_WARN), "DANGER" (from NEXT_DANGER, about to pull) or "UNKNOWN"; .percent rounded (0-999).
-- At most max rows.
function Aggro.CurrentRows(entries, max)
    local rows = {}
    for _, entry in ipairs(entries) do
        local row = { holder = entry.holder, isPlayer = entry.isPlayer }
        if entry.tanking == true then
            row.state = "HOLDS"
        elseif type(entry.percent) ~= "number" then
            row.state = "UNKNOWN"
        end
        if type(entry.percent) == "number" then
            row.percent = math.max(0, math.min(999, math.floor(entry.percent + 0.5)))
            row.state = row.state or (row.percent >= Aggro.NEXT_DANGER and "DANGER")
                or (row.percent >= Aggro.NEXT_WARN and "WARNING") or "GOOD"
        end
        rows[#rows + 1] = row
    end
    local function rank(row)
        if row.state == "HOLDS" then return 2000 end
        if row.state == "UNKNOWN" then return -1 end
        return row.percent
    end
    table.sort(rows, function(a, b) return rank(a) > rank(b) end)
    while #rows > max do table.remove(rows) end
    return rows
end

-- Your own threat on one enemy, by your role (owner 2026-10-14). status = your threat status on it (0-3, nil = you are
-- not on its threat list), percent = the scaled percent (100 = you pull it); either may be UNREADABLE.
-- Tank: by status — while you tank, WoW reports 100 % for you, so a percent can never warn you. Healer/Damage: AGGRO
-- as soon as it is on you (status 2/3), else WARNING from NEXT_WARN and DANGER from NEXT_DANGER percent.
-- Returns nil (not on its list) or { state = "GOOD"|"WARNING"|"DANGER"|"AGGRO"|"UNKNOWN", percent = 0-999 | nil }.
function Aggro.SelfThreat(role, status, percent)
    if status == Aggro.UNREADABLE then return { state = "UNKNOWN" } end
    local readable = type(percent) == "number" and math.max(0, math.min(999, math.floor(percent + 0.5))) or nil
    if role == "TANK" then
        local state = (status == 3 and "GOOD") or (status == 2 and "WARNING")
            or ((status == 0 or status == 1) and "DANGER") or nil
        return state and { state = state, percent = readable } or nil
    end
    if status == 2 or status == 3 then return { state = "AGGRO", percent = readable } end
    if status == nil then return nil end
    if not readable then return { state = "UNKNOWN" } end
    local state = (readable >= Aggro.NEXT_DANGER and "DANGER") or (readable >= Aggro.NEXT_WARN and "WARNING")
        or "GOOD"
    return { state = state, percent = readable }
end

-- UNKNOWN ranks above WARNING: an unreadable enemy could be the dangerous one — but below a readable DANGER or AGGRO.
local SELF_RANK = { GOOD = 1, WARNING = 2, UNKNOWN = 3, DANGER = 4, AGGRO = 5 }

-- The worst of your SelfThreat results over several enemies (healer/damage: every enemy the group fights, since
-- healing threat lands on all of them, not only on a target). Ties: the higher percent. Returns nil for an empty list,
-- else that result (with its .name, if the caller set one) plus .onYou = how many of them attack you (AGGRO).
function Aggro.SelfWorst(results)
    local worst, onYou = nil, 0
    for _, result in ipairs(results) do
        if result.state == "AGGRO" then onYou = onYou + 1 end
        local rank, best = SELF_RANK[result.state], worst and SELF_RANK[worst.state] or 0
        if rank > best or (rank == best and (result.percent or 0) > (worst.percent or 0)) then worst = result end
    end
    if not worst then return nil end
    return { state = worst.state, percent = worst.percent, name = worst.name, onYou = onYou }
end

-- PaTiAggro (the former PaTiTank, renamed 2026-10-14): aggro for every role. Display only; no secure frames.
-- Tank view: threat on your target (coloured by your threat status), who pulls next, enemies you lost.
-- Healer/Damage view: your highest threat over all enemies the group fights, and the enemies that attack you.
-- The view follows the "My role" setting (Logic.EffectiveRole).
local addonName, ns = ...
local UI, L, Logic, Aggro, Threat, Plates = ns.UI, ns.UI.L, ns.Logic, ns.Aggro, ns.Threat, ns.Plates

local DB
local testMode = false
local aggroEvents = {} -- event -> registered (see Events)

local WIDTH, BAR_WIDTH, PAD, LINE = 280, 252, UI.Spacing.MD, 18
local THREAT_HEIGHT = 16
-- Test mode, tank: you hold the target (100 %, green) and a damage dealer is at 84 % of pulling (yellow "Next" line).
-- Healer/Damage: one enemy attacks you (red AGGRO).
local TEST = { threat = 100, next = { holder = { role = "DAMAGER" }, percent = 84, state = "WARNING" },
    self = { state = "AGGRO", percent = 100 } }

local function say(key, ...)
    print("|cff68caffPaTiAggro:|r " .. L[key]:format(...))
end

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

local function addonVersion()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMetadata and getMetadata(addonName, "Version") or "?"
end

-- Window ---------------------------------------------------------------------------------------

local window = UI.CreateWindow("PaTiAggroFrame", "PaTiAggro", WIDTH, 120)
window:SetCombatMovable(true) -- no secure children: may be dragged in combat too (PaTiShared)
local content = CreateFrame("Frame", nil, window) -- everything below the header; hidden when collapsed
content:SetPoint("TOPLEFT", 0, -UI.Sizes.HeaderHeight)
content:SetPoint("BOTTOMRIGHT")

-- Target line: label + name. The name goes straight to SetText (it may be a secret value).
local targetLabel = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
targetLabel:SetPoint("TOPLEFT", PAD, -UI.Spacing.SM - 2)
UI.BindText(targetLabel, "TARGET")
local targetName = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
targetName:SetPoint("LEFT", targetLabel, "RIGHT", UI.Spacing.SM, 0)
targetName:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
targetName:SetJustifyH("LEFT")
targetName:SetWordWrap(false)

-- The bar colour follows the state (paintBarColor), so it is not a static UI.Paint colour.
local function makeBar(top, height, labelKey)
    local background = content:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", PAD, -top)
    background:SetSize(BAR_WIDTH, height)
    UI.Paint(background, "SetColorTexture", "Panel")
    local bar = CreateFrame("StatusBar", nil, content)
    bar:SetPoint("TOPLEFT", PAD, -top)
    bar:SetSize(BAR_WIDTH, height)
    bar:SetStatusBarTexture(UI.WHITE)
    local label = bar:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    label:SetPoint("CENTER")
    UI.BindText(label, labelKey)
    return bar, label
end

local threatTop = UI.Spacing.SM + LINE + UI.Spacing.SM
local threat, threatLabel = makeBar(threatTop, THREAT_HEIGHT, "THREAT")
threat:SetMinMaxValues(0, 100)

local SELF_COLOR = { GOOD = "Success", WARNING = "Warning", DANGER = "Danger", AGGRO = "Danger", UNKNOWN = "TextMuted" }
local function paintBarColor(state) threat:SetStatusBarColor(UI.Color(SELF_COLOR[state] or "TextMuted")) end

-- "Next: Mage 92 %" — the group member closest to pulling your target (Aggro.NextThreat). Who and percent are two
-- strings because a member name may be secret (SetText only, never joined with other text).
local nextTop = threatTop + THREAT_HEIGHT + UI.Spacing.SM
local nextLabel = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
nextLabel:SetPoint("TOPLEFT", PAD, -nextTop - 2)
UI.BindText(nextLabel, "NEXT")
local nextPercent = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
nextPercent:SetPoint("TOPRIGHT", -PAD, -nextTop - 2)
nextPercent:SetJustifyH("RIGHT")
local nextWho = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
nextWho:SetPoint("LEFT", nextLabel, "RIGHT", UI.Spacing.SM, 0)
nextWho:SetPoint("RIGHT", nextPercent, "LEFT", -UI.Spacing.SM, 0)
nextWho:SetJustifyH("LEFT")
nextWho:SetWordWrap(false)

-- Aggro block: "AGGRO  x / y under control", then up to Aggro.MAX_ROWS enemies you do not (safely) hold.
local aggroTop = nextTop + LINE + UI.Spacing.MD
local aggroLabel = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Label)
aggroLabel:SetPoint("TOPLEFT", PAD, -aggroTop)
UI.BindText(aggroLabel, "AGGRO")
local aggroSummary = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
aggroSummary:SetPoint("TOPRIGHT", -PAD, -aggroTop)
aggroSummary:SetJustifyH("RIGHT")

local HOLDER_WIDTH, NUMBER_WIDTH = 96, 12
local STATE_COLOR = { LOST = "Danger", DANGER = "Warning", UNKNOWN = "TextMuted" }
local rows = {}
for index = 1, Aggro.MAX_ROWS do
    local top = aggroTop + index * LINE
    local marker = content:CreateTexture(nil, "ARTWORK")
    marker:SetPoint("TOPLEFT", PAD, -top - 3)
    marker:SetSize(3, LINE - 6)
    local holder = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    holder:SetPoint("TOPRIGHT", -PAD, -top - 2)
    holder:SetWidth(HOLDER_WIDTH)
    holder:SetJustifyH("RIGHT")
    holder:SetWordWrap(false)
    -- The number that also stands above this enemy's nameplate (empty: no plate that can be named safely).
    local number = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Title)
    number:SetPoint("TOPLEFT", PAD + 3 + UI.Spacing.SM, -top - 1)
    number:SetWidth(NUMBER_WIDTH)
    number:SetJustifyH("LEFT")
    local name = content:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    name:SetPoint("TOPLEFT", PAD + 3 + UI.Spacing.SM + NUMBER_WIDTH + UI.Spacing.XS, -top - 2)
    name:SetPoint("RIGHT", holder, "LEFT", -UI.Spacing.SM, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    rows[index] = { marker = marker, number = number, name = name, holder = holder }
end

local FULL_HEIGHT = UI.Sizes.HeaderHeight + aggroTop + LINE + PAD -- without aggro rows
local shownRows = 0
local lastNumbers = {} -- readable GUID -> row number of the last paint (Aggro.Number keeps numbers stable)
local rowUnit = {}     -- row index -> nameplate token its number belongs to (cleared on plate events)

-- Paint (threat values may be secret: they only reach the StatusBar widget) ------------------------------

-- A group member: role first, then name (may be secret: only handed to SetText), else "other player".
local function memberText(holder)
    local label = Aggro.HolderLabel(holder)
    if label == "NAME" then return holder.name end
    return L[label] or L.OTHER_PLAYER
end

local NEXT_COLOR = { LOW = "Text", WARNING = "Warning", DANGER = "Danger" }

local function paintNext(info)
    if not info or info.state == "UNKNOWN" then
        nextWho:SetText(info and L.AGGRO_UNKNOWN or L.NEXT_NONE)
        nextWho:SetTextColor(UI.Color("TextMuted"))
        nextPercent:SetText("")
        return
    end
    local color = NEXT_COLOR[info.state]
    nextWho:SetText(memberText(info.holder))
    nextWho:SetTextColor(UI.Color(color))
    nextPercent:SetText(("%d %%"):format(info.percent))
    nextPercent:SetTextColor(UI.Color(color))
end

-- The view of the last paint; nil until the first one. Labels change with it, numbers start fresh.
local role

local function updateRole()
    local new = Logic.EffectiveRole(DB.myRole, Threat.PlayerRole())
    if new == role then return end
    role = new
    local tank = role == "TANK"
    UI.BindText(threatLabel, tank and "THREAT" or "SELF_THREAT")
    UI.BindText(nextLabel, tank and "NEXT" or "SELF_STATE")
    UI.BindText(aggroLabel, tank and "AGGRO" or "ON_YOU")
    lastNumbers = {}
end

local function paintTarget()
    if testMode then
        targetName:SetText(L.TEST_TARGET)
    elseif UnitExists("target") then
        targetName:SetText(UnitName("target"))
    else
        targetName:SetText(L.NO_TARGET)
    end
    if role ~= "TANK" then return end -- healer/damage: bar and state line come from the scan (paintSelf)
    if testMode then
        threat:SetValue(TEST.threat)
        paintBarColor("GOOD")
        paintNext(TEST.next)
    elseif UnitExists("target") then
        local _, _, percent = UnitDetailedThreatSituation("player", "target")
        threat:SetValue(Logic.ThreatValue(percent, isSecret))
        local mine = Aggro.SelfThreat("TANK", Threat.Self("target"))
        paintBarColor(mine and mine.state)
        paintNext(Aggro.NextThreat(Threat.Next("target")))
    else
        threat:SetValue(0)
        paintBarColor(nil)
        paintNext(nil)
    end
end

local SELF_TEXT = { GOOD = "SELF_GOOD", WARNING = "SELF_WARNING", DANGER = "SELF_DANGER", AGGRO = "SELF_AGGRO",
    UNKNOWN = "AGGRO_UNKNOWN" }

-- Healer/Damage: the worst of your threat on the target and on every enemy the group fights (Aggro.SelfWorst).
local function paintSelf(enemies)
    local info = TEST.self
    if not testMode then
        local results = {}
        local function add(status, percent)
            local result = Aggro.SelfThreat(role, status, percent)
            if result then results[#results + 1] = result end
        end
        if UnitExists("target") then add(Threat.Self("target")) end
        for _, enemy in ipairs(enemies) do add(enemy.playerStatus, enemy.playerPercent) end
        info = Aggro.SelfWorst(results)
    end
    if not info then
        threat:SetValue(0)
        paintBarColor("GOOD")
        nextWho:SetText(L.NEXT_NONE)
        nextWho:SetTextColor(UI.Color("TextMuted"))
        nextPercent:SetText("")
        return
    end
    local color = SELF_COLOR[info.state]
    threat:SetValue(info.state == "AGGRO" and 100 or math.min(100, info.percent or 0))
    paintBarColor(info.state)
    nextWho:SetText(L[SELF_TEXT[info.state]])
    nextWho:SetTextColor(UI.Color(color))
    nextPercent:SetText(info.percent and info.state ~= "AGGRO" and ("%d %%"):format(info.percent) or "")
    nextPercent:SetTextColor(UI.Color(color))
end

-- Test mode: 6 enemies, 4 held, 1 barely held, 1 on the healer. Names are looked up at paint time (language).
-- Fake tokens/GUIDs only feed the numbering; test mode never draws on real nameplates.
local TEST_ENEMIES = {
    { key = "TEST_ENEMY_1", state = "CONTROLLED" }, { key = "TEST_ENEMY_2", state = "CONTROLLED" },
    { key = "TEST_ENEMY_3", state = "LOST", holder = { role = "HEALER" }, unit = "nameplate3", guid = "TEST-3" },
    { key = "TEST_ENEMY_4", state = "CONTROLLED" },
    { key = "TEST_ENEMY_5", state = "DANGER", unit = "nameplate5", guid = "TEST-5" },
    { key = "TEST_ENEMY_6", state = "CONTROLLED" },
}

-- Healer/Damage test: one enemy attacks you.
local TEST_ON_YOU = {
    { key = "TEST_ENEMY_3", playerStatus = 3, unit = "nameplate3", guid = "TEST-3" },
    { key = "TEST_ENEMY_1", playerStatus = 0 },
}

local function holderText(enemy)
    if enemy.onYou then return L.YOU end
    if enemy.state == "DANGER" then return L.AGGRO_DANGER end
    if enemy.state == "UNKNOWN" then return L.AGGRO_UNKNOWN end
    return memberText(enemy.holder)
end

local alertsError -- last error PaTiAlerts raised in Sync (diagnostics only, /paggro debug)

-- PaTiAlerts is optional (AGENTS.md §3): report only if it is installed with API version 1, never depend on it.
-- pcall: a problem in PaTiAlerts must never break PaTiAggro.
local function alertsApi()
    local api = _G.PaTiAlertsAPI
    if type(api) == "table" and api.version == 1 and type(api.Sync) == "function" then return api end
    return nil
end

-- Scans run while the panel is open, or while collapsed if PaTiAlerts shows the result instead.
local function scanning()
    return not DB.collapsed or alertsApi() ~= nil
end

-- Plain text for the right side of an alert (a secret holder name cannot be sent as text).
local function alertDetail(enemy)
    local text = holderText(enemy)
    if isSecret(text) then return L.OTHER_PLAYER end
    return text
end

local function applyLayout()
    content:SetShown(not DB.collapsed)
    window:SetHeight(DB.collapsed and UI.Sizes.HeaderHeight or FULL_HEIGHT + shownRows * LINE)
    window:SetTestMode(testMode)
end

local function paintAggro()
    local tank = role == "TANK"
    local enemies
    if testMode then enemies = tank and TEST_ENEMIES or TEST_ON_YOU else enemies = Threat.Scan() end
    local summary
    if tank then
        summary = Aggro.Summarize(enemies)
    else
        paintSelf(enemies)
        summary = { rows = Aggro.OnYou(enemies) }
    end
    local count = math.min(#summary.rows, Aggro.MAX_ROWS)
    local visible = {}
    for index = 1, count do visible[index] = summary.rows[index] end
    -- Row numbers and nameplate numbers come from this one list, in this one paint: they always name the same enemy.
    -- Numbers only while marking is on; markers off in test mode (no real plates) and while no scans run.
    local marking = DB.markPlates and scanning()
    local numbers = {}
    if marking then numbers, lastNumbers = Aggro.Number(visible, lastNumbers) else lastNumbers = {} end
    local marks = {}
    rowUnit = {}
    for index, enemy in ipairs(visible) do
        if numbers[index] then
            marks[#marks + 1] = { unit = enemy.unit, number = numbers[index], state = enemy.state }
            rowUnit[index] = enemy.unit
        end
    end
    Plates.Update(marks, marking and not testMode)
    -- PaTiAlerts: the same rows with the same numbers; test mode sends nothing (its enemies are not real). The
    -- healer/damage view sends nothing yet: PaTiAlerts has no "attacks you" alert kind (FOLLOW_UPS).
    local api = alertsApi()
    if api then
        local alerts = {}
        if tank and not testMode then
            alerts = Aggro.Alerts(visible, numbers, alertDetail, L.UNKNOWN_ENEMY, isSecret)
        end
        local ok, err = pcall(api.Sync, "PaTiAggro", alerts)
        if not ok then alertsError = tostring(err):sub(1, 120) end -- /paggro debug only; PaTiAggro keeps running
    end
    if not tank then
        aggroSummary:SetText(count == 0 and L.ON_YOU_NONE or L.ON_YOU_COUNT:format(#summary.rows))
        aggroSummary:SetTextColor(UI.Color(count == 0 and "Text" or "Danger"))
    else
        if summary.total == 0 then
            aggroSummary:SetText(L.AGGRO_NONE)
        elseif #summary.rows > Aggro.MAX_ROWS then
            aggroSummary:SetText(L.AGGRO_CONTROLLED:format(summary.held, summary.total) .. "  "
                .. L.AGGRO_MORE:format(#summary.rows - Aggro.MAX_ROWS))
        else
            aggroSummary:SetText(L.AGGRO_CONTROLLED:format(summary.held, summary.total))
        end
        aggroSummary:SetTextColor(UI.Color(summary.held < summary.total and "Warning" or "Text"))
    end
    for index, row in ipairs(rows) do
        local enemy = summary.rows[index]
        local shown = index <= count
        row.marker:SetShown(shown)
        row.number:SetShown(shown)
        row.name:SetShown(shown)
        row.holder:SetShown(shown)
        if shown then
            local color = STATE_COLOR[enemy.state]
            row.marker:SetColorTexture(UI.Color(color))
            row.number:SetText(numbers[index] and tostring(numbers[index]) or "")
            row.number:SetTextColor(UI.Color(color))
            local name = enemy.key and L[enemy.key] or enemy.name
            if isSecret(name) or name ~= nil then row.name:SetText(name) else row.name:SetText(L.UNKNOWN_ENEMY) end
            row.holder:SetText(holderText(enemy))
            row.holder:SetTextColor(UI.Color(color))
        end
    end
    if count ~= shownRows then
        shownRows = count
        applyLayout() -- no secure frames: resizing is fine in combat
    end
end

-- A plate got a new unit or lost it: drop its number from the plate AND from the panel row at once, so no row keeps
-- a number that no plate (or a different enemy's plate) shows. The next scan numbers again.
local function forgetPlate(unit)
    Plates.Clear(unit)
    for index, token in pairs(rowUnit) do
        if token == unit then
            rows[index].number:SetText("")
            rowUnit[index] = nil
        end
    end
end

local function paintAll()
    if not DB then return end
    updateRole()
    paintTarget()
    paintAggro()
end

-- Aggro scans are coalesced: a burst of threat/nameplate events causes one scan SCAN_DELAY later.
-- In combat a slow fallback rescan catches changes no event reports (e.g. an enemy dying).
local SCAN_DELAY, COMBAT_RESCAN = 0.1, 1.0
local scheduler = CreateFrame("Frame")
scheduler:Hide()
local due -- seconds until the next scan while the scheduler is shown

local function requestScan()
    if not DB or testMode or not scanning() then return end -- expanding repaints (paintAll)
    if not due or due > SCAN_DELAY then due = SCAN_DELAY end
    scheduler:Show()
end

scheduler:SetScript("OnUpdate", function(self, elapsed)
    due = due - elapsed
    if due > 0 then return end
    if testMode then due = nil; self:Hide(); return end
    paintAggro()
    if InCombatLockdown() then
        due = COMBAT_RESCAN
    else
        due = nil
        self:Hide()
    end
end)

-- Settings -------------------------------------------------------------------------------------

local modal

local function buildSettings()
    modal = UI.CreateModal("PaTiAggroSettings", function() return "PaTiAggro " .. L.SETTINGS end, 380)
    local scales = {}
    for _, scale in ipairs(Logic.SCALES) do
        scales[#scales + 1] = { value = scale, text = function() return ("%d %%"):format(scale * 100 + 0.5) end }
    end
    modal:AddSection("GENERAL")
    modal:AddRow("LANGUAGE", UI.CreateLanguageDropdown(modal, DB, 170))
    local roles = {}
    for _, value in ipairs(Logic.ROLES) do roles[#roles + 1] = { value = value, text = "ROLE_" .. value } end
    modal:AddRow("MY_ROLE", UI.CreateDropdown(modal, 170, {
        items = function() return roles end,
        get = function() return DB.myRole end,
        set = function(value) DB.myRole = value; paintAll() end,
    }))
    modal:AddRow("SCALE", UI.CreateDropdown(modal, 170, {
        items = function() return scales end,
        get = function() return DB.scale end,
        set = function(scale) DB.scale = scale; window:SetScale(scale) end,
    }))
    modal:AddControls(UI.CreateCheckbox(modal, "LOCK_WINDOW", {
        get = function() return window:IsLocked() end,
        set = function(locked) window:SetLocked(locked) end,
    }), UI.CreateCheckbox(modal, "MARK_PLATES", {
        get = function() return DB.markPlates end,
        set = function(mark) DB.markPlates = mark; paintAll() end,
    }))
    UI.AddWindowSettings(modal, window) -- panel opacity + snapping (PaTiShared)
    modal:Finish(function()
        Logic.RestoreDefaults(DB)
        window:ApplyTheme() -- Restore Defaults: theme back to default
        window:ApplyOpacity()
        UI.SetLanguage(DB.language)
        window:SetLocked(DB.locked)
        window:SetScale(DB.scale)
        applyLayout()
        paintAll()
    end)
end

local function openSettings()
    if not modal then buildSettings() end
    modal:Show()
end

-- Commands -------------------------------------------------------------------------------------

local function toggleTestMode()
    testMode = not testMode
    applyLayout()
    paintAll()
end

local function toggleCollapsed()
    DB.collapsed = not DB.collapsed
    applyLayout()
    paintAll()
end

local function setShown(shown, quiet) -- no secure frames: fine in combat
    window:SetShown(shown)
    if not shown and not quiet then say("HIDDEN_HINT") end
    return true
end

-- Optional PaTiSuite control panel: the same rules as the commands, without chat lines (false = not possible now).
window.suiteSetShown = function(shown) return setShown(shown, true) end

local function resetPosition()
    DB.point, DB.relativePoint, DB.x, DB.y = nil, nil, nil, nil
    window:Attach(DB, -330, 0)
end

local function aggroEventsOk(...)
    for _, event in ipairs({ ... }) do
        if not aggroEvents[event] then return "no" end
    end
    return "yes"
end

local function printDebug()
    local version, build, _, interface = GetBuildInfo()
    print("|cff68caffPaTiAggro Debug:|r")
    for _, line in ipairs({
        ("Addon %s %s · PaTiShared UI %s"):format(addonName, addonVersion(), tostring(UI.VERSION)),
        ("WoW %s (build %s, interface %s) · locale %s · UI language %s"):format(tostring(version), tostring(build),
            tostring(interface), GetLocale(), UI.GetLanguage()),
        ("Threat API %s · issecretvalue %s · combat %s · test mode %s"):format(
            UnitDetailedThreatSituation and "yes" or "no", issecretvalue and "yes" or "no",
            InCombatLockdown() and "yes" or "no", testMode and "on" or "off"),
        ("Aggro: UnitThreatSituation %s · nameplate events %s · party target events %s"):format(
            UnitThreatSituation and "yes" or "no", aggroEventsOk("NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED"),
            aggroEventsOk("UNIT_TARGET")),
        ("Role: setting %s · group role %s · view %s"):format(tostring(DB.myRole),
            tostring(Threat.PlayerRole() or "none"), tostring(role)),
        ("Last caught errors: threat API %s · PaTiAlerts %s"):format(Threat.lastError or "none",
            alertsError or "none"),
    }) do print("  " .. line) end
end

local COMMANDS = {
    [""] = function() setShown(not window:IsShown()) end,
    show = function() setShown(true) end,
    hide = function() setShown(false) end,
    test = toggleTestMode,
    lock = function() window:SetLocked(true) end,
    unlock = function() window:SetLocked(false) end,
    reset = resetPosition,
    settings = openSettings,
    debug = printDebug,
    version = function() say("VERSION", addonVersion()) end,
}

SLASH_PATIAGGRO1 = "/paggro"
SLASH_PATIAGGRO2 = "/patiaggro"
SLASH_PATIAGGRO3 = "/pt" -- transition from the old PaTiTank (owner 2026-10-14); remove the old PaTiTank folder
SlashCmdList.PATIAGGRO = function(message)
    local command = COMMANDS[(message or ""):match("^%s*(.-)%s*$"):lower()]
    if command and DB then command() else say("HELP") end
end

window:SetMenu(function()
    if not DB then return {} end
    return {
        { text = "SETTINGS", onClick = openSettings },
        { text = window:IsLocked() and "UNLOCK" or "LOCK", onClick = function() window:SetLocked(not window:IsLocked()) end },
        { text = DB.collapsed and "EXPAND" or "COLLAPSE", onClick = toggleCollapsed },
        { text = "TEST_MODE", checked = testMode, onClick = toggleTestMode },
        { text = "HIDE", onClick = function() setShown(false) end },
    }
end)

-- Events ---------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }) do
    events:RegisterEvent(event)
end
-- Aggro events: registered through pcall — should one not exist in this client, the monitor still works
-- with the rest (see /paggro debug).
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_TARGET", "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    aggroEvents[event] = pcall(events.RegisterEvent, events, event)
end
local PARTY = { party1 = true, party2 = true, party3 = true, party4 = true }

events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then -- tracked always, so test mode / collapse never lose plates
        forgetPlate(unit) -- a reused plate must not keep the number of its previous enemy
        Threat.PlateAdded(unit)
        requestScan()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        forgetPlate(unit)
        Threat.PlateRemoved(unit)
        requestScan()
    elseif event == "PLAYER_LOGIN" then
        PaTiAggroDB = Logic.Migrate(PaTiAggroDB)
        DB = PaTiAggroDB
        UI.SetLanguage(DB.language)
        window:Attach(DB, -330, 0)
        window:SetScale(DB.scale)
        applyLayout()
        paintAll()
    elseif not DB or testMode then
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        paintAll()
    elseif event == "UNIT_TARGET" then
        if PARTY[unit] then requestScan() end -- fires for every unit (nameplates too); only party targets matter
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        paintAll() -- the view follows your group role (AUTO); the "Next" line reads the group
        requestScan()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        requestScan()
    else -- target changed or threat changed
        paintTarget()
        requestScan()
    end
end)
UI.OnLanguageChanged(paintAll)
UI.OnThemeChanged(paintAll) -- state colours follow the theme (static ones repaint themselves, UI.Paint)

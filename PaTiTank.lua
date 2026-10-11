-- PaTiTank: current target, your threat on it and the aggro monitor. Display only; no secure frames. No own
-- health bar since 2026-10-10 (owner: the tank addon is about threat and aggro only).
local addonName, ns = ...
local UI, L, Logic, Aggro, Threat, Plates = ns.UI, ns.UI.L, ns.Logic, ns.Aggro, ns.Threat, ns.Plates

local DB
local testMode = false
local aggroEvents = {} -- event -> registered (see Events)

local WIDTH, BAR_WIDTH, PAD, LINE = 280, 252, UI.Spacing.MD, 18
local THREAT_HEIGHT = 16
-- Test mode: your threat in percent, and a damage dealer at 84 % of pulling (yellow "Next" line).
local TEST = { threat = 72, next = { holder = { role = "DAMAGER" }, percent = 84, state = "WARNING" } }

local function say(key, ...)
    print("|cff68caffPaTiTank:|r " .. L[key]:format(...))
end

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

local function addonVersion()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMetadata and getMetadata(addonName, "Version") or "?"
end

-- Window ---------------------------------------------------------------------------------------

local window = UI.CreateWindow("PaTiTankFrame", "PaTiTank", WIDTH, 120)
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

local function makeBar(top, height, color, labelKey)
    local background = content:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", PAD, -top)
    background:SetSize(BAR_WIDTH, height)
    UI.Paint(background, "SetColorTexture", "Panel")
    local bar = CreateFrame("StatusBar", nil, content)
    bar:SetPoint("TOPLEFT", PAD, -top)
    bar:SetSize(BAR_WIDTH, height)
    bar:SetStatusBarTexture(UI.WHITE)
    UI.Paint(bar, "SetStatusBarColor", color)
    local label = bar:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    label:SetPoint("CENTER")
    UI.BindText(label, labelKey)
    return bar
end

local threatTop = UI.Spacing.SM + LINE + UI.Spacing.SM
local threat = makeBar(threatTop, THREAT_HEIGHT, "Danger", "THREAT")
threat:SetMinMaxValues(0, 100)

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

local function paintTarget()
    if testMode then
        targetName:SetText(L.TEST_TARGET)
        threat:SetValue(TEST.threat)
        paintNext(TEST.next)
    elseif UnitExists("target") then
        targetName:SetText(UnitName("target"))
        local _, _, percent = UnitDetailedThreatSituation("player", "target")
        threat:SetValue(Logic.ThreatValue(percent, isSecret))
        paintNext(Aggro.NextThreat(Threat.Next("target")))
    else
        targetName:SetText(L.NO_TARGET)
        threat:SetValue(0)
        paintNext(nil)
    end
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

local function holderText(enemy)
    if enemy.state == "DANGER" then return L.AGGRO_DANGER end
    if enemy.state == "UNKNOWN" then return L.AGGRO_UNKNOWN end
    return memberText(enemy.holder)
end

local alertsError -- last error PaTiAlerts raised in Sync (diagnostics only, /pt debug)

-- PaTiAlerts is optional (AGENTS.md §3): report only if it is installed with API version 1, never depend on it.
-- pcall: a problem in PaTiAlerts must never break PaTiTank.
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
    local enemies = testMode and TEST_ENEMIES or Threat.Scan()
    local summary = Aggro.Summarize(enemies)
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
    -- PaTiAlerts: the same rows with the same numbers; test mode sends nothing (its enemies are not real).
    local api = alertsApi()
    if api then
        local alerts = testMode and {} or Aggro.Alerts(visible, numbers, alertDetail, L.UNKNOWN_ENEMY, isSecret)
        local ok, err = pcall(api.Sync, "PaTiTank", alerts)
        if not ok then alertsError = tostring(err):sub(1, 120) end -- /pt debug only; PaTiTank keeps running
    end
    if summary.total == 0 then
        aggroSummary:SetText(L.AGGRO_NONE)
    elseif #summary.rows > Aggro.MAX_ROWS then
        aggroSummary:SetText(L.AGGRO_CONTROLLED:format(summary.held, summary.total) .. "  "
            .. L.AGGRO_MORE:format(#summary.rows - Aggro.MAX_ROWS))
    else
        aggroSummary:SetText(L.AGGRO_CONTROLLED:format(summary.held, summary.total))
    end
    aggroSummary:SetTextColor(UI.Color(summary.held < summary.total and "Warning" or "Text"))
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
    modal = UI.CreateModal("PaTiTankSettings", function() return "PaTiTank " .. L.SETTINGS end, 380)
    local scales = {}
    for _, scale in ipairs(Logic.SCALES) do
        scales[#scales + 1] = { value = scale, text = function() return ("%d %%"):format(scale * 100 + 0.5) end }
    end
    modal:AddSection("GENERAL")
    modal:AddRow("LANGUAGE", UI.CreateLanguageDropdown(modal, DB, 170))
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
    print("|cff68caffPaTiTank Debug:|r")
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

SLASH_PATITANK1 = "/patitank"
SLASH_PATITANK2 = "/pt"
SlashCmdList.PATITANK = function(message)
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
-- with the rest (see /pt debug).
for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_TARGET", "GROUP_ROSTER_UPDATE",
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
        PaTiTankDB = Logic.Migrate(PaTiTankDB)
        DB = PaTiTankDB
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
    elseif event == "GROUP_ROSTER_UPDATE" then
        paintTarget() -- the "Next" line reads the group
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

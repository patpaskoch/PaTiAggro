-- PaTiAggro (the former PaTiTank, renamed 2026-10-14): aggro for every role. Display only; no secure frames.
-- Three sections: AGGRO TOTAL (tank: enemies you hold; healer/damage: your highest threat), AGGRO TARGET (you and your
-- group on your target, sorted) and AGGRO TEAM (tank: enemies that need you; healer/damage: enemies on you).
-- The view follows the "My role" setting (Logic.EffectiveRole).
local addonName, ns = ...
local UI, L, Logic, Aggro, Threat, Plates = ns.UI, ns.UI.L, ns.Logic, ns.Aggro, ns.Threat, ns.Plates

local DB
local testMode = false
local aggroEvents = {} -- event -> registered (see Events)

local WIDTH, BAR_WIDTH, PAD, LINE = 280, 252, UI.Spacing.MD, 18
local MEMBER_BAR = 14 -- height of one "AGGRO TARGET" bar inside its LINE
-- Clear space before a section (owner 2026-10-14): AGGRO TEAM gets the most, so the enemy list stands apart.
local GAP = { target = UI.Spacing.LG + UI.Spacing.SM, team = 2 * UI.Spacing.LG + UI.Spacing.SM }
local BOTTOM = UI.Spacing.SM -- small space below the last section
local MAX_CURRENT = 6 -- you, party1-4, pet

-- Test mode. You (Brom) hold the test enemy, Lyra is at 84 % and Mira at 35 %. Names are looked up at paint time.
local TEST_CURRENT = {
    { holder = { nameKey = "TEST_TANK", role = "TANK" }, percent = 100, tanking = true, isPlayer = true },
    { holder = { nameKey = "TEST_PLAYER", role = "DAMAGER" }, percent = 84 },
    { holder = { nameKey = "TEST_HEALER", role = "HEALER" }, percent = 35 },
}
-- Healer/damage: you target the Zombie (78 %, yellow); the Ghul and the Pestratte stand small beside it.
local TEST_SELF_CARDS = {
    { key = "TEST_ENEMY_5", state = "WARNING", percent = 78, isTarget = true,
        icon = [[Interface\Icons\Spell_Shadow_RaiseDead]] },
    { key = "TEST_ENEMY_3", state = "GOOD", percent = 40, icon = [[Interface\Icons\Spell_Shadow_AnimateDead]] },
    { key = "TEST_ENEMY_6", state = "GOOD", percent = 12 },
}

local function say(key, ...)
    print("|cff68caffPaTiAggro:|r " .. L[key]:format(...))
end

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

local function addonVersion()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMetadata and getMetadata(addonName, "Version") or "?"
end

-- Window ---------------------------------------------------------------------------------------
-- Three sections, top to bottom (owner 2026-10-14), with clear space between them:
--   5 / 6  AGGRO TOTAL           large number, small caption (healer/damage: your highest threat)
--   bars, then AGGRO TARGET <enemy>   you and your group on your target, sorted: "Name (Role)" and a percent bar
--   AGGRO TEAM, then rows        the enemies that need you (healer/damage: ON YOU — the enemies that attack you)

local window = UI.CreateWindow("PaTiAggroFrame", "PaTiAggro", WIDTH, 120)
window:SetCombatMovable(true) -- no secure children: may be dragged in combat too (PaTiShared)
local content = CreateFrame("Frame", nil, window) -- everything below the header; hidden when collapsed
content:SetPoint("TOPLEFT", 0, -UI.Sizes.HeaderHeight)
content:SetPoint("BOTTOMRIGHT")

-- Section names are small captions in the accent colour, like PaTiHeal's "TARGET" mark (owner 2026-10-14: the same
-- look in both addons). The values carry the weight, the captions only tell what they are.
local CAPTION = 12 -- height of a caption line
local CAPTION_SMALLER = 2 -- captions a little smaller than the muted text (owner 2026-10-14)
local function newSection(titleKey)
    local section = CreateFrame("Frame", nil, content)
    section:SetHeight(LINE)
    section.title = section:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
    UI.BindText(section.title, titleKey)
    UI.Paint(section.title, "SetTextColor", "Accent")
    local font, size, flags = section.title:GetFont()
    if font and size then section.title:SetFont(font, size - CAPTION_SMALLER, flags) end
    section.value = section:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    section.value:SetJustifyH("RIGHT")
    section.value:SetWordWrap(false)
    return section
end

-- AGGRO TOTAL: the number large on the left, the caption small beside it.
local total = newSection("AGGRO_TOTAL")
total.value:SetFontObject(UI.Fonts.Title)
total.value:SetPoint("TOPLEFT", PAD, -1)
total.value:SetJustifyH("LEFT")
total.title:SetPoint("BOTTOMLEFT", total.value, "BOTTOMRIGHT", UI.Spacing.SM, 1)

-- AGGRO TOTAL, healer/damage (owner 2026-11-11): enemy cards instead of one number — portrait, name and your percent.
-- The enemy you target is large; up to Aggro.MAX_SELF_CARDS others stand beside it at half the size; a single enemy
-- uses the whole width. The frame around a portrait takes the danger colour. Display only: cards are not clickable
-- (targeting from addon code is not possible safely, FOLLOW_UPS F17).
local LARGE, SMALL, CARD_TEXT = 48, 24, 14
local LARGE_WIDTH = LARGE + UI.Spacing.MD
local SMALL_WIDTH = math.floor((BAR_WIDTH - LARGE_WIDTH - UI.Spacing.SM - (Aggro.MAX_SELF_CARDS - 1) * UI.Spacing.XS)
    / Aggro.MAX_SELF_CARDS)
local CARD_COLOR = { GOOD = "TextMuted", WARNING = "Warning", DANGER = "Danger", AGGRO = "Danger", UNKNOWN = "TextMuted" }
local NO_PORTRAIT = [[Interface\Icons\INV_Misc_QuestionMark]]

local function newCard(size)
    local card = CreateFrame("Frame", nil, total)
    card.frame = card:CreateTexture(nil, "BACKGROUND")
    card.frame:SetPoint("TOPLEFT")
    card.frame:SetSize(size, size)
    card.portrait = card:CreateTexture(nil, "ARTWORK")
    card.portrait:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 2, -2)
    card.portrait:SetPoint("BOTTOMRIGHT", card.frame, "BOTTOMRIGHT", -2, 2)
    card.name = card:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.value = card:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    card.value:SetJustifyH("LEFT")
    card.value:SetWordWrap(false)
    card:Hide()
    return card
end
local largeCard = newCard(LARGE)
local smallCards = {}
for index = 1, Aggro.MAX_SELF_CARDS do
    local card = newCard(SMALL)
    card:SetPoint("TOPLEFT", PAD + LARGE_WIDTH + UI.Spacing.SM + (index - 1) * (SMALL_WIDTH + UI.Spacing.XS), -CAPTION)
    card:SetSize(SMALL_WIDTH, SMALL + 2 * CARD_TEXT)
    card.name:SetPoint("TOPLEFT", 0, -SMALL - 2)
    card.name:SetWidth(SMALL_WIDTH)
    card.value:SetPoint("TOPLEFT", 0, -SMALL - 2 - CARD_TEXT)
    card.value:SetWidth(SMALL_WIDTH)
    smallCards[index] = card
end
-- "+2": enemies that did not fit, on the caption line.
total.more = total:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
total.more:SetPoint("TOPRIGHT", -PAD, 0)
UI.Paint(total.more, "SetTextColor", "TextMuted")

-- Tank: the large number with the caption beside it. Cards: the caption on top, the cards below.
local cardView -- nil until the first paint
local function setCardView(cards)
    if cards == cardView then return end
    cardView = cards
    total.value:SetShown(not cards)
    total.more:SetShown(cards)
    total.title:ClearAllPoints()
    if cards then
        total.title:SetPoint("TOPLEFT", PAD, 0)
    else
        total.title:SetPoint("BOTTOMLEFT", total.value, "BOTTOMRIGHT", UI.Spacing.SM, 1)
        largeCard:Hide()
        for _, card in ipairs(smallCards) do card:Hide() end
    end
end

-- One enemy: the large card spans the width, name and percent beside the portrait. More: name and percent below it.
local largeAlone -- nil until the first card paint
local function placeLargeCard(alone)
    if alone == largeAlone then return end
    largeAlone = alone
    largeCard:ClearAllPoints()
    largeCard:SetPoint("TOPLEFT", PAD, -CAPTION)
    largeCard.name:ClearAllPoints()
    largeCard.value:ClearAllPoints()
    if alone then
        largeCard:SetSize(BAR_WIDTH, LARGE)
        largeCard.name:SetPoint("TOPLEFT", LARGE + UI.Spacing.MD, -UI.Spacing.SM)
        largeCard.name:SetWidth(BAR_WIDTH - LARGE - UI.Spacing.MD)
        largeCard.value:SetWidth(BAR_WIDTH - LARGE - UI.Spacing.MD)
        largeCard.value:SetPoint("TOPLEFT", largeCard.name, "BOTTOMLEFT", 0, -UI.Spacing.SM)
        largeCard.value:SetFontObject(UI.Fonts.Title)
    else
        largeCard:SetSize(LARGE_WIDTH, LARGE + 2 * CARD_TEXT)
        largeCard.name:SetPoint("TOPLEFT", 0, -LARGE - 2)
        largeCard.name:SetWidth(LARGE_WIDTH)
        largeCard.value:SetWidth(LARGE_WIDTH)
        largeCard.value:SetPoint("TOPLEFT", 0, -LARGE - 2 - CARD_TEXT)
        largeCard.value:SetFontObject(UI.Fonts.Text)
    end
end
-- AGGRO TARGET: the caption small above the bars (owner 2026-10-14), the enemy name beside it.
local now = newSection("AGGRO_TARGET")
now.title:SetPoint("TOPLEFT", PAD, 0)
now.value:SetPoint("LEFT", now.title, "RIGHT", UI.Spacing.SM, 0)
-- Hint on the right of the caption line (owner 2026-10-17): healer/damage attacking another enemy than the tank.
now.hint = now:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
now.hint:SetPoint("TOPRIGHT", -PAD, 0)
now.hint:SetJustifyH("RIGHT")
UI.Paint(now.hint, "SetTextColor", "Warning")
UI.BindText(now.hint, "NOT_TANK_TARGET")
now.hint:Hide()
now.value:SetPoint("RIGHT", now, "RIGHT", -PAD, 0) -- paintHint makes room for the hint while it is shown
now.value:SetJustifyH("LEFT")
UI.Paint(now.value, "SetTextColor", "TextMuted") -- the enemy name: light grey like the window title
-- AGGRO TEAM: the caption small above the rows.
local team = newSection("AGGRO_TEAM")
team.title:SetPoint("TOPLEFT", PAD, 0)
team.value:SetPoint("TOPRIGHT", -PAD, 0)

-- "Name (Role)" in two strings: a member name may be secret (SetText only, never joined with other text).
local function newMemberText(parent, font)
    local name = parent:CreateFontString(nil, "OVERLAY", font)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local tag = parent:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    UI.Paint(tag, "SetTextColor", "TextMuted") -- light grey like the window title (owner 2026-10-14)
    tag:SetPoint("LEFT", name, "RIGHT", UI.Spacing.XS, 0)
    tag:SetJustifyH("LEFT")
    tag:SetWordWrap(false)
    return name, tag
end

-- AGGRO TARGET rows: one bar per member — "Name (Role)" left, percent (or "has aggro") right.
local NAME_WIDTH = 110
local members = {}
for index = 1, MAX_CURRENT do
    local bar = CreateFrame("StatusBar", nil, now)
    bar:SetPoint("TOPLEFT", PAD, -CAPTION - (index - 1) * LINE - (LINE - MEMBER_BAR) / 2)
    bar:SetSize(BAR_WIDTH, MEMBER_BAR)
    bar:SetStatusBarTexture(UI.WHITE)
    bar:SetMinMaxValues(0, 100)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    UI.Paint(background, "SetColorTexture", "Panel")
    local value = bar:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    value:SetPoint("RIGHT", -UI.Spacing.SM, 0)
    value:SetJustifyH("RIGHT")
    local name, tag = newMemberText(bar, UI.Fonts.Text)
    name:SetPoint("LEFT", UI.Spacing.SM, 0)
    name:SetWidth(NAME_WIDTH)
    name:SetJustifyH("LEFT")
    tag:ClearAllPoints()
    tag:SetPoint("LEFT", UI.Spacing.SM + NAME_WIDTH + UI.Spacing.XS, 0)
    tag:SetPoint("RIGHT", value, "LEFT", -UI.Spacing.XS, 0)
    members[index] = { bar = bar, name = name, tag = tag, value = value }
end

-- AGGRO TEAM rows: marker, number (also above the enemy's nameplate), enemy name, "Name (Role)" of who has it.
local HOLDER_WIDTH, TAG_WIDTH, NUMBER_WIDTH = 64, 58, 12
local STATE_COLOR = { LOST = "Danger", DANGER = "Warning", UNKNOWN = "TextMuted" }
local rows = {}
for index = 1, Aggro.MAX_ROWS do
    local top = CAPTION + (index - 1) * LINE
    local marker = team:CreateTexture(nil, "ARTWORK")
    marker:SetPoint("TOPLEFT", PAD, -top - 3)
    marker:SetSize(3, LINE - 6)
    local holderTag = team:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    UI.Paint(holderTag, "SetTextColor", "TextMuted") -- light grey like the window title
    holderTag:SetPoint("TOPRIGHT", -PAD, -top - 2)
    holderTag:SetWidth(TAG_WIDTH)
    holderTag:SetJustifyH("LEFT")
    holderTag:SetWordWrap(false)
    local holder = team:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    holder:SetPoint("TOPRIGHT", holderTag, "TOPLEFT", -UI.Spacing.XS, 0)
    holder:SetWidth(HOLDER_WIDTH)
    holder:SetJustifyH("RIGHT")
    holder:SetWordWrap(false)
    -- The number that also stands above this enemy's nameplate (empty: no plate that can be named safely).
    local number = team:CreateFontString(nil, "OVERLAY", UI.Fonts.Title)
    number:SetPoint("TOPLEFT", PAD + 3 + UI.Spacing.SM, -top - 1)
    number:SetWidth(NUMBER_WIDTH)
    number:SetJustifyH("LEFT")
    local name = team:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    name:SetPoint("TOPLEFT", PAD + 3 + UI.Spacing.SM + NUMBER_WIDTH + UI.Spacing.XS, -top - 2)
    name:SetPoint("RIGHT", holder, "LEFT", -UI.Spacing.SM, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    rows[index] = { marker = marker, number = number, name = name, holder = holder, holderTag = holderTag }
end

local shownMembers, shownRows = 0, 0
local lastNumbers = {} -- readable GUID -> row number of the last paint (Aggro.Number keeps numbers stable)
local rowUnit = {}     -- row index -> nameplate token its number belongs to (cleared on plate events)

local totalShown = false -- AGGRO TOTAL has something to say (paintAggro)
local totalHeight = LINE + 2 -- AGGRO TOTAL: one line (tank) or the enemy cards (healer/damage)

-- Only sections with content are shown (owner 2026-10-14): AGGRO TOTAL without enemies, AGGRO TARGET without an enemy
-- target and AGGRO TEAM without rows disappear. Shown ones stack with a gap before each (GAP); AGGRO TEAM gets more
-- room above it. Returns the used height (0: nothing to show).
local function placeSections()
    local layout = {
        { section = total, shown = totalShown, height = totalHeight, gap = 0 },
        { section = now, shown = shownMembers > 0, height = CAPTION + shownMembers * LINE, gap = GAP.target },
        { section = team, shown = shownRows > 0, height = CAPTION + shownRows * LINE, gap = GAP.team },
    }
    local top, used = UI.Spacing.SM, false
    for _, entry in ipairs(layout) do
        entry.section:SetShown(entry.shown)
        if entry.shown then
            if used then top = top + entry.gap end
            entry.section:ClearAllPoints()
            entry.section:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
            entry.section:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -top)
            top, used = top + entry.height, true
        end
    end
    return used and top or 0
end

-- Paint (threat values may be secret: they only reach widgets) ----------------------------------------

-- "(Role)" for a member (owner 2026-10-14): the role when WoW assigned one, else the class when it is readable.
local function tagOf(holder)
    local roleKey = holder.role and ("ROLE_" .. holder.role)
    if roleKey and L[roleKey] then return "(" .. L[roleKey] .. ")" end
    if not isSecret(holder.class) and type(holder.class) == "string" then return "(" .. holder.class .. ")" end
    return ""
end

-- "Name (Role)"; without a name the role alone stands in the name string. The name only goes to SetText.
local function paintMember(nameString, tagString, holder)
    if holder and (holder.nameKey or holder.hasName) then
        nameString:SetText(holder.nameKey and L[holder.nameKey] or holder.name)
        tagString:SetText(tagOf(holder))
    else
        nameString:SetText(L[Aggro.HolderLabel(holder)] or L.OTHER_PLAYER)
        tagString:SetText("")
    end
end

-- The view of the last paint; nil until the first one. Labels change with it, numbers start fresh.
local role

local function updateRole()
    local new = Logic.EffectiveRole(DB.myRole, Threat.PlayerRole(), Threat.OtherTank())
    if new == role then return end
    role = new
    lastNumbers = {}
end

-- Colour of an AGGRO TARGET bar. Who has the aggro: green when that is right (you as tank, or the tank when you are
-- not), red when it is wrong. Everyone else by how close they are to pulling (70 / 90 %).
local CURRENT_COLOR = { GOOD = "TextMuted", WARNING = "Warning", DANGER = "Danger", UNKNOWN = "TextMuted" }
local function memberColor(row)
    if row.state ~= "HOLDS" then return CURRENT_COLOR[row.state] end
    local rightHolder
    if role == "TANK" then rightHolder = row.isPlayer else rightHolder = not row.isPlayer end
    return rightHolder and "Success" or "Danger"
end

local applyLayout -- defined below; the sections change the window height

-- "Not the tank's target": only in the healer/damage view; test mode shows it there as an example.
local function paintHint()
    local show = role ~= nil and role ~= "TANK" and (testMode or Threat.OffTankTarget() == true)
    now.hint:SetShown(show)
    if show then
        now.value:SetPoint("RIGHT", now.hint, "LEFT", -UI.Spacing.SM, 0)
    else
        now.value:SetPoint("RIGHT", now, "RIGHT", -PAD, 0)
    end
end

-- AGGRO TARGET: you and your group on your target.
local function paintNow()
    local list
    if testMode then
        list = TEST_CURRENT
        now.value:SetText(L.TEST_TARGET)
    elseif UnitExists("target") then
        list = Threat.Current("target")
        now.value:SetText(UnitName("target")) -- may be secret: SetText only
    else
        list = {}
        now.value:SetText(L.AGGRO_NONE)
    end
    paintHint()
    local current = Aggro.CurrentRows(list, MAX_CURRENT)
    for index, member in ipairs(members) do
        local row = current[index]
        member.bar:SetShown(row ~= nil)
        if row then
            paintMember(member.name, member.tag, row.holder)
            member.bar:SetValue(row.state == "HOLDS" and 100 or math.min(100, row.percent or 0))
            member.bar:SetStatusBarColor(UI.Color(memberColor(row)))
            local value = row.percent and ("%d %%"):format(row.percent) or L.AGGRO_UNKNOWN
            member.value:SetText(row.state == "HOLDS" and L.HAS_AGGRO or value)
        end
    end
    if #current ~= shownMembers then
        shownMembers = #current
        if DB then applyLayout() end
    end
end

-- Test mode, tank: 6 enemies, 4 held, 1 slipping to Lyra, 1 on the healer Mira.
-- Fake tokens/GUIDs only feed the numbering; test mode never draws on real nameplates.
local TEST_ENEMIES = {
    { key = "TEST_ENEMY_1", state = "CONTROLLED" }, { key = "TEST_ENEMY_2", state = "CONTROLLED" },
    { key = "TEST_ENEMY_3", state = "LOST", holder = { nameKey = "TEST_HEALER", role = "HEALER" },
        unit = "nameplate3", guid = "TEST-3" },
    { key = "TEST_ENEMY_4", state = "CONTROLLED" },
    { key = "TEST_ENEMY_5", state = "DANGER", challenger = { nameKey = "TEST_PLAYER", role = "DAMAGER" },
        unit = "nameplate5", guid = "TEST-5" },
    { key = "TEST_ENEMY_6", state = "CONTROLLED" },
}

-- Right side of an AGGRO TEAM row: who has it (red), who is about to take it (yellow), or a state word.
local function paintHolder(row, enemy)
    local word = (enemy.state == "UNKNOWN" and L.AGGRO_UNKNOWN)
        or (enemy.state == "DANGER" and not enemy.challenger and L.AGGRO_DANGER) or nil
    if word then
        row.holder:SetText(word)
        row.holderTag:SetText("")
    else
        paintMember(row.holder, row.holderTag, enemy.state == "DANGER" and enemy.challenger or enemy.holder)
    end
end

-- Plain text for an alert in PaTiAlerts (a secret name cannot be sent as text): role, else readable name.
local function alertDetail(enemy)
    if enemy.state == "UNKNOWN" then return L.AGGRO_UNKNOWN end
    local member = enemy.state == "DANGER" and enemy.challenger or enemy.holder
    if enemy.state == "DANGER" and not member then return L.AGGRO_DANGER end
    local label = Aggro.HolderLabel(member)
    if label ~= "NAME" then return L[label] or L.OTHER_PLAYER end
    if isSecret(member.name) then return L.OTHER_PLAYER end
    return member.name
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

applyLayout = function()
    content:SetShown(not DB.collapsed)
    local height = placeSections()
    window:SetHeight(DB.collapsed and UI.Sizes.HeaderHeight or UI.Sizes.HeaderHeight + height + BOTTOM)
    window:SetTestMode(testMode)
end

local SELF_COLOR = { GOOD = "Text", WARNING = "Warning", DANGER = "Danger", AGGRO = "Danger", UNKNOWN = "TextMuted" }

-- Your threat on each enemy you could pull (healer/damage): every enemy the group fights — healing threat lands on all
-- of them — plus your target, also before anyone attacked it (0 %). Each entry is a SelfThreat result with the unit
-- token for the portrait, the name (may be secret: SetText only) and whether it is your target.
local function selfEntries(enemies)
    if testMode then return TEST_SELF_CARDS end
    local list, hasTarget = {}, false
    local function add(unit, name, isTarget, status, percent)
        local result = Aggro.SelfThreat(role, status, percent)
        if not result and isTarget and Threat.ZeroThreat(unit) then result = { state = "GOOD", percent = 0 } end
        if not result then return end
        result.unit, result.name, result.isTarget = unit, name, isTarget
        list[#list + 1] = result
        hasTarget = hasTarget or isTarget
    end
    for _, enemy in ipairs(enemies) do
        add(enemy.unit, enemy.name, enemy.isTarget, enemy.playerStatus, enemy.playerPercent)
    end
    if not hasTarget and UnitExists("target") then
        local status, percent = Threat.Self("target")
        add("target", UnitName("target"), true, status, percent)
    end
    return list
end

-- SetPortraitTexture takes the unit token itself; no unit data is read. Test mode: fixed icons.
local function paintCard(card, entry)
    card:SetShown(entry ~= nil)
    if not entry then return end
    if entry.unit and SetPortraitTexture then
        SetPortraitTexture(card.portrait, entry.unit)
    else
        card.portrait:SetTexture(entry.icon or NO_PORTRAIT)
    end
    card.frame:SetColorTexture(UI.Color(CARD_COLOR[entry.state] or "TextMuted"))
    local name = entry.key and L[entry.key] or entry.name
    if isSecret(name) or name ~= nil then card.name:SetText(name) else card.name:SetText(L.UNKNOWN_ENEMY) end
    card.name:SetTextColor(UI.Color("Text"))
    if entry.state == "UNKNOWN" or not entry.percent then
        card.value:SetText(L.AGGRO_UNKNOWN)
    else
        card.value:SetText(("%d %%"):format(entry.percent))
    end
    card.value:SetTextColor(UI.Color(SELF_COLOR[entry.state] or "Text"))
end

-- AGGRO TOTAL, healer/damage: the enemy cards (see newCard). Returns whether there is anything to show and the height.
local function paintSelfTotal(enemies)
    local large, small, hidden = Aggro.SelfCards(selfEntries(enemies), Aggro.MAX_SELF_CARDS)
    placeLargeCard(#small == 0)
    paintCard(largeCard, large)
    for index, card in ipairs(smallCards) do paintCard(card, small[index]) end
    total.more:SetText(hidden > 0 and ("+%d"):format(hidden) or "")
    if not large then return false, LINE + 2 end
    return true, CAPTION + (#small == 0 and LARGE or LARGE + 2 * CARD_TEXT)
end

local function paintAggro()
    local tank = role == "TANK"
    local enemies
    if testMode then enemies = tank and TEST_ENEMIES or {} else enemies = Threat.Scan() end
    local summary, hasTotal, height
    setCardView(not tank)
    if tank then
        summary = Aggro.Summarize(enemies)
        hasTotal, height = summary.total > 0, LINE + 2
    else
        hasTotal, height = paintSelfTotal(enemies)
        summary = { rows = {} } -- no list of the enemies on you (owner 2026-10-21): the AGGRO TARGET bar shows it
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
    -- healer/damage view sends nothing yet: PaTiAlerts has no "attacks you" alert kind (FOLLOW_UPS F35).
    local api = alertsApi()
    if api then
        local alerts = {}
        if tank and not testMode then
            alerts = Aggro.Alerts(visible, numbers, alertDetail, L.UNKNOWN_ENEMY, isSecret)
        end
        local ok, err = pcall(api.Sync, "PaTiAggro", alerts)
        if not ok then alertsError = tostring(err):sub(1, 120) end -- /paggro debug only; PaTiAggro keeps running
    end
    if tank then
        total.value:SetText(summary.total == 0 and L.AGGRO_NONE
            or L.AGGRO_CONTROLLED:format(summary.held, summary.total))
        total.value:SetTextColor(UI.Color(summary.held < summary.total and "Warning" or "Text"))
        team.value:SetText(#summary.rows > Aggro.MAX_ROWS and L.AGGRO_MORE:format(#summary.rows - Aggro.MAX_ROWS) or "")
        team.value:SetTextColor(UI.Color("TextMuted"))
    end
    for index, row in ipairs(rows) do
        local enemy = summary.rows[index]
        local shown = index <= count
        row.marker:SetShown(shown)
        row.number:SetShown(shown)
        row.name:SetShown(shown)
        row.holder:SetShown(shown)
        row.holderTag:SetShown(shown)
        if shown then
            local color = STATE_COLOR[enemy.state]
            row.marker:SetColorTexture(UI.Color(color))
            row.number:SetText(numbers[index] and tostring(numbers[index]) or "")
            row.number:SetTextColor(UI.Color(color))
            local name = enemy.key and L[enemy.key] or enemy.name
            if isSecret(name) or name ~= nil then row.name:SetText(name) else row.name:SetText(L.UNKNOWN_ENEMY) end
            paintHolder(row, enemy)
            row.holder:SetTextColor(UI.Color(color))
        end
    end
    if count ~= shownRows or hasTotal ~= totalShown or height ~= totalHeight then
        shownRows, totalShown, totalHeight = count, hasTotal, height
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
    paintNow()
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
        ("Role: setting %s · group role %s · other tank %s · view %s"):format(tostring(DB.myRole),
            tostring(Threat.PlayerRole() or "none"), tostring(Threat.OtherTank()), tostring(role)),
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
        if PARTY[unit] then -- fires for every unit (nameplates too); only party targets matter
            requestScan()
            paintHint() -- the tank changed its target
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        paintAll() -- the view follows your group role (AUTO); AGGRO TARGET reads the group
        requestScan()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        requestScan()
    else -- target changed or threat changed
        paintNow()
        requestScan()
    end
end)
UI.OnLanguageChanged(paintAll)
UI.OnThemeChanged(paintAll) -- state colours follow the theme (static ones repaint themselves, UI.Paint)

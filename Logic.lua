-- PaTiAggro: saved settings and value normalisation, no WoW API calls (tested in tests/logic_spec.lua).
local _, ns = ...
local Logic = {}
ns.Logic = Logic

Logic.SCHEMA = 1
Logic.SCALES = { 0.8, 0.9, 1, 1.1, 1.25, 1.5 }
Logic.ROLES = { "AUTO", "TANK", "HEALER", "DAMAGER" } -- the "My role" setting, in menu order
Logic.ROLE_SET = { AUTO = true, TANK = true, HEALER = true, DAMAGER = true }

Logic.DEFAULTS = {
    opacity = 0.75, -- panel body opacity (PaTiShared window; 0.3–1)
    theme = "default", -- "default" | "woforever" | "dracula" (PaTiShared UI.THEMES; colours only)
    locked = false,
    collapsed = false,
    scale = 1,
    language = "auto",
    markPlates = true, -- "!" above the nameplate of a lost / barely held enemy (Plates.lua)
    myRole = "AUTO", -- AUTO | TANK | HEALER | DAMAGER: which view (owner 2026-10-14); AUTO = the group role, else TANK
}

-- 0.1.0 saved x, y (CENTER offsets) and locked; they are kept as they are, so the window stays where it was
-- (the PaTiShared window reads a missing point as CENTER). Missing values get defaults; saved false stays false.
function Logic.Migrate(db)
    if type(db) ~= "table" then db = {} end -- nil or a broken save (string, number …): start fresh
    for key, value in pairs(Logic.DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    -- A broken scale would make SetScale fail on login: only a sane number is kept (saved values elsewhere stay).
    if type(db.scale) ~= "number" or db.scale < 0.5 or db.scale > 2 then db.scale = Logic.DEFAULTS.scale end
    -- The PaTiShared themes (Soft Fantasy since 2026-10-19); a typo or an old value falls back to the default look.
    local knownTheme = { default = true, woforever = true, dracula = true, softfantasy = true }
    if not knownTheme[db.theme] then db.theme = "default" end
    if not Logic.ROLE_SET[db.myRole] then db.myRole = "AUTO" end
    db.schema = Logic.SCHEMA
    return db
end

-- "Restore Defaults": settings back, position kept.
function Logic.RestoreDefaults(db)
    for key, value in pairs(Logic.DEFAULTS) do db[key] = value end
    return db
end

-- Value for the threat bar (0-100). A secret value is returned unchanged: it may only be handed to the
-- StatusBar widget, never compared. nil (no threat data, e.g. no target) becomes 0.
function Logic.ThreatValue(percent, isSecret)
    if isSecret(percent) then return percent end
    if type(percent) ~= "number" then return 0 end
    return math.max(0, math.min(100, percent))
end

-- The view to show: the chosen role, or with AUTO the role WoW reports for you in the group (already checked for
-- secrecy; nil without one). Without your own role: when another member has the WoW role Tank you are not the tank →
-- your own threat (owner 2026-10-14: a healer saw "0 / 5" of the tank view). Without any role the tank view stays
-- (never guessed from the class); "My role" in the settings fixes the view per character.
function Logic.EffectiveRole(setting, assigned, otherTank)
    if setting ~= "AUTO" and Logic.ROLE_SET[setting] then return setting end
    if assigned == "TANK" or assigned == "HEALER" or assigned == "DAMAGER" then return assigned end
    if otherTank then return "DAMAGER" end
    return "TANK"
end

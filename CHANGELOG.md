# Changelog

Format: `## [Unreleased]` / `## [x.y.z] - YYYY-MM-DD` with Added, Changed, Fixed, Removed, Known Issues.
History before this file: `git log`.

## [Unreleased]
### Changed
- Healer/damage view: an enemy on you shows once (owner 2026-10-21: it stood in three places) — as the red
  "has aggro" bar in AGGRO TARGET. AGGRO TOTAL shows only your percent (no "AGGRO on you!"), and the "ON YOU" list
  with its nameplate numbers is gone.
- README: the install guide is in English (it was German, owner 2026-10-20) and is the only one; the short
  "Installation" section with the same steps is gone.
### Fixed
- A healer or damage dealer without an own WoW role saw the tank view ("0 / 5", owner 2026-10-14): with "My role" =
  Auto, another member assigned as tank now means you are not the tank → your own threat. Without any role the tank
  view stays (never guessed from the class); set "My role" once per character. `/paggro debug` shows "other tank".
### Added
- Theme **Soft Fantasy** (PaTiShared, owner wish 2026-10-19): calm slate blue, grey and violet with a muted
  lavender accent — the fourth choice in the settings and in PaTiSuite.
- Hint "not the tank's target" (owner 2026-10-17): in the healer/damage view, the AGGRO TARGET caption line shows it in
  yellow when your enemy target is another one than the target of the member with the WoW role Tank. Compares unit
  tokens (`UnitIsUnit`); nothing to compare (no tank, no target, unreadable) shows nothing. The tank target itself stays
  in PaTiGroup.
- "My role" setting: Auto (group role, else tank — never guessed from the class), Tank, Healer, Damage.
- Healer/damage view: "Your threat (highest)" over your target and every enemy your group fights, with
  `You: calm / rising (70 %) / about to pull (90 %) / AGGRO on you!`, and an "ON YOU" block listing the enemies that
  attack you, numbered on their nameplates. Unreadable values show "unclear", never "calm". Test mode follows the role.
- "Next" line under the threat bar (owner 2026-10-11): the group member (or pet) closest to pulling your target,
  with role or name and percent — yellow from 70 %, red from 90 % (WoW's scaled threat: 100 % = pulls, melee/ranged
  rule included). Only while you tank the target; "—" otherwise, "unclear" when a value cannot be read. Test mode: a
  damage dealer at 84 %.
- Themes (owner wish 2026-10-03): Settings → Window → Theme — Default (the PaTi look as before), WoForever (warm brown, gold/bronze) or Dracula (dark, purple/pink/cyan accents). Colours only; layout, secure buttons and behaviour are unchanged. Saved per character in this addon (`theme`, unknown values → Default); Restore Defaults returns to Default. PaTiSuite can switch all PaTi windows at once.
- Window settings (PaTiShared): panel opacity 30–100 % (default 75 %, the header stays opaque). The window registers
  itself for the optional PaTiSuite control panel, which shows/hides it with this addon's own rules. (Snapping to
  other PaTi windows was tried and removed again: it did not work in the client.)
- Optional PaTiAlerts report: every visible lost (critical) / barely held (warning) row goes to PaTiAlerts with the
  same number as the panel and the nameplate; controlled, dead or vanished enemies disappear there too. Only if
  PaTiAlerts is installed; nothing changes without it. While PaTiAlerts is installed, a collapsed panel keeps scanning.
- AddOns list icon from the PaTiSuite icon set (`Media/icon.tga`, `## IconTexture`); platform images in `assets/`.
- MIT license (`LICENSE`, not part of the release zip).
- Numbered problem enemies: each problem row gets a number (1–4) and the same number stands above that enemy's
  nameplate, coloured by state (lost red, barely held yellow, unclear grey) — also tells same-named enemies apart.
  Only rows with their own nameplate get a number; an enemy keeps its number while visible (readable GUID only).
  A reused or removed nameplate loses its number at once, on the plate and in the panel. Setting "Number problem
  enemies on nameplates", on by default. Click the nameplate to target it; the addon never targets or taunts. Panel rows are not clickable:
  in combat WoW forbids pointing a secure button at a different enemy (see PaTiAdmin FOLLOW_UPS F17).
- PaTiShared window with ••• menu (Settings, Lock/Unlock, Collapse/Expand, Test Mode, Hide), settings modal
  (language, scale, lock), `/pt settings, reset, debug, version`; `/pt` alone shows/hides the window.
- English texts, German translation.
- Aggro control monitor: "AGGRO x / y under control" plus up to 4 rows for enemies you lost (with the holder's
  role, else name, else "other player"), barely hold, or cannot read. Enemies come from your target, visible
  nameplates and your party's targets. Unreadable (secret) threat data shows as "unclear", never as controlled.
  Scans are event driven and coalesced (0.1 s); in combat a 1 s fallback rescan catches changes no event reports.
  Test mode shows 6 enemies: 4 held, 1 barely held, 1 on the healer. `/pt debug` shows which aggro APIs exist.
- Tests for the collapsed state (default, migration keeps a saved value, restore defaults expands).
### Changed
- Only sections with content are shown (owner 2026-10-14): AGGRO TOTAL hides with no enemies, AGGRO TARGET without
  an enemy target, AGGRO TEAM without rows. Captions a little smaller; AGGRO TARGET's caption now above its bars; more
  room above AGGRO TEAM, less below the last section. Roles in brackets and the enemy name in light grey like the
  window title.
- Section names as small accent captions like PaTiHeal's "TARGET" mark (owner 2026-10-14): `5 / 6` large with
  "AGGRO TOTAL" small beside it; "AGGRO NOW" is now **AGGRO TARGET**, its caption and the enemy name below the bars;
  "AGGRO TEAM" small above its rows.
- Three sections (owner 2026-10-14): **AGGRO TOTAL** (5 / 6), **AGGRO TARGET** (you and your group on your target, sorted,
  "Name (Role)" — the class when there is no role — with a percent bar each; the one who has it shows "has aggro")
  and **AGGRO TEAM** (the enemy rows, now "Name (Role)" of who has or is about to take each enemy). The "Next" bar
  and the separate threat bar are gone; AGGRO TARGET shows everyone.
- New order (owner 2026-10-14): "AGGRO TOTAL 5 / 6" at the top, then the target bar, the "Next" bar and the enemy rows.
  A yellow row ("barely held") now names the member about to take the enemy; without one it reads "slipping".
- Tank "Next" is now a small bar with the player's name (owner 2026-10-14) instead of a text line; the percent is
  how far that player is to pulling (100 % = they take it).
- Simpler display (owner 2026-10-14): no "Target:" line any more — the threat bar is at the top with the enemy's
  name on the left and your percent on the right. The warning line ("Next" for tanks, "about to pull" / "AGGRO on
  you!" for healer/damage) appears only when it matters; otherwise the aggro block moves up. The aggro header reads
  just `AGGRO 5 / 6` (no "under control"); healer/damage: `ON YOU 1`.
- **Renamed PaTiTank → PaTiAggro** (owner 2026-10-14, architecture audit variant C): aggro for every role, not only
  tanks. New folder, TOC and SavedVariables (`PaTiAggroDB`): the old PaTiTank settings (position, size, language,
  theme, opacity, numbers, collapse, lock) are not carried over — delete the old `PaTiTank` folder. Commands
  `/paggro`, `/patiaggro`; `/pt` still works for now. GitHub: patpaskoch/PaTiAggro (the old link forwards).
  PaTiAlerts lists the alerts under the source PaTiAggro.
- Tank: the threat bar colour now follows your threat status (green you hold it, yellow someone has more threat,
  red someone else has it) instead of a fixed red — the percent cannot warn a tank (always 100 % while tanking).
- Diagnostics (hardening 2026-10-02): errors that are caught so the addon keeps running are no longer silent — the debug command shows the last caught error per source (no chat spam, nothing saved).
- The window can also be moved in combat (it has no secure buttons; PaTiShared `SetCombatMovable`, hardening 2026-10-02). A broken saved position falls back to the default instead of breaking the login.
- AddOns list description in English with a German translation (`## Notes-deDE`); README rewritten for players
  (features, installation, first steps, commands, known limitations).
- New PaTiShared look instead of the legacy panel (gear, chevron, close button).
- Only your own UNIT_HEALTH/UNIT_MAXHEALTH updates the health bar (before: every unit's health event redrew everything).
- Settings in PaTiTankDB get a schema; the 0.1.0 position and lock state are kept.
### Fixed
- An enemy target nobody has attacked yet now shows 0 % instead of no number (owner 2026-10-14). Friendly targets
  and clients without the threat API still show no number.
- Hardening: a broken SavedVariables save (not a table, a broken schema or scale) no longer breaks the login; only the broken value is replaced, every valid setting (also `false`) stays, and the migration is idempotent (tests/robustness_spec.lua).
- Settings: the first section title showed the key "GENERAL" (no text for it); now "General" / "Allgemein" (FOLLOW_UPS F30).
- An enemy that is your target and has a nameplate keeps its nameplate token in the aggro scan.
- The addon did not load: the TOC listed both Lua files on one line with a literal `` `r`n `` between them.
- Target name and threat value are no longer concatenated/compared, so restricted (secret) values cannot cause errors.
- Saving defaults into the saved variables on every login (`x = x or -330`) is gone.
### Removed
- Own health bar (owner 2026-10-10: PaTiTank is about threat and aggro only). Target, threat bar and the aggro monitor
  move up.
- `PaTiSharedPanel.lua` (legacy shared panel global).
### Known Issues
- The healer/damage view sends nothing to PaTiAlerts yet (no "attacks you" alert kind there).
- Not tested in game yet (threat values, layout, secret values in combat, the whole aggro monitor).
- Aggro: enemies without a visible nameplate that nobody in your group targets are not seen. Clicking a row does
  not target the enemy (technically blocked, PaTiAdmin FOLLOW_UPS F17); click the numbered nameplate instead.

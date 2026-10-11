# Changelog

Format: `## [Unreleased]` / `## [x.y.z] - YYYY-MM-DD` with Added, Changed, Fixed, Removed, Known Issues.
History before this file: `git log`.

## [Unreleased]
### Added
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
- Diagnostics (hardening 2026-10-02): errors that are caught so the addon keeps running are no longer silent — the debug command shows the last caught error per source (no chat spam, nothing saved).
- The window can also be moved in combat (it has no secure buttons; PaTiShared `SetCombatMovable`, hardening 2026-10-02). A broken saved position falls back to the default instead of breaking the login.
- AddOns list description in English with a German translation (`## Notes-deDE`); README rewritten for players
  (features, installation, first steps, commands, known limitations).
- New PaTiShared look instead of the legacy panel (gear, chevron, close button).
- Only your own UNIT_HEALTH/UNIT_MAXHEALTH updates the health bar (before: every unit's health event redrew everything).
- Settings in PaTiTankDB get a schema; the 0.1.0 position and lock state are kept.
### Fixed
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
- Not tested in game yet (threat values, layout, secret values in combat, the whole aggro monitor).
- Aggro: enemies without a visible nameplate that nobody in your group targets are not seen. Clicking a row does
  not target the enemy (technically blocked, PaTiAdmin FOLLOW_UPS F17); click the numbered nameplate instead.

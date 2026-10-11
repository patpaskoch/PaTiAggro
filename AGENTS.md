# AGENTS.md — PaTiTank

**Read the suite rules first: [`../../PaTiAdmin/AGENTS.md`](../../PaTiAdmin/AGENTS.md).** They apply here in full.
Addon facts: `../../PaTiAdmin/docs/ARCHITECTURE.md` · open issues: `../../PaTiAdmin/docs/FOLLOW_UPS.md`.

## This addon
- Purpose: current target, your threat on it, who pulls it next, plus an aggro control monitor, for a tank.
  Display only: never targets, taunts or clicks anything.
- Files: `Logic.lua` (settings, threat value; pure, tested) · `Aggro.lua` (aggro states/summary, next threat; pure, tested) ·
  `Threat.lua` (the only threat/nameplate API calls; tested with mocks) · `Plates.lua` (number marker frames on
  nameplates; tested with mocks) ·
  `PaTiTank.lua` (window, paint, scan scheduler, settings, commands, events) ·
  `Locales/` · `Shared/` (PaTiShared, synced — never edit).
- SavedVariables: `PaTiTankDB` (per character), schema 1: x, y (+ point/relativePoint once dragged), locked, collapsed, scale,
  language, markPlates.
- Secure / combat-sensitive: none — no secure frames, so window, collapse and test mode also work in combat. Keep it that way.
  Clickable aggro rows were investigated (F17) and are not possible safely; never target from addon code.
- Secret values: health, max health, target name and threat go straight to widgets; `Logic.ThreatValue` checks before clamping.
- Secret values (aggro): every threat status, GUID and flag is checked with `issecretvalue` before use; unreadable
  → `Aggro.UNREADABLE` → state UNKNOWN, never CONTROLLED. Enemy/holder names only go to SetText.
- Hot path: `UNIT_HEALTH` fires for every unit — only `player` repaints. Aggro scans are coalesced (`requestScan`,
  0.1 s), skipped while collapsed or in test mode; nameplates are tracked by events, never by looping 1..40.
  `UNIT_TARGET` fires for every unit — only party1-4 trigger a scan.
- Slash commands: `/pt`, `/patitank`.

## Checks
`bash ../../PaTiAdmin/tools/check.sh .` before every commit. Manual WoW tests: `../../PaTiAdmin/docs/TESTING.md`.

## PaTiAlerts (optional)
Reports its current alerts with `PaTiAlertsAPI.Sync("PaTiTank", list)` after every normal refresh — only if the API
exists with version 1, always inside `pcall` (PaTiAdmin/AGENTS.md §3). The list is built by a pure, tested function.
Without PaTiAlerts nothing may change. Never make PaTiAlerts a dependency.

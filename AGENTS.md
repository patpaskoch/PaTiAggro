# AGENTS.md — PaTiAggro (formerly PaTiTank, renamed 2026-10-14)

**Read the suite rules first: [`../../PaTiAdmin/AGENTS.md`](../../PaTiAdmin/AGENTS.md).** They apply here in full.
Addon facts: `../../PaTiAdmin/docs/ARCHITECTURE.md` · open issues: `../../PaTiAdmin/docs/FOLLOW_UPS.md`.

## This addon
- Purpose: aggro for every role. Tank view: target, your threat on it (colour by status), who pulls it next, aggro
  control monitor. Healer/damage view: your highest threat over all fought enemies, enemies that attack you.
  The view follows `DB.myRole` (`Logic.EffectiveRole`: chosen role, else the group role, else tank; never the class).
  Display only: never targets, taunts or clicks anything.
- Files: `Logic.lua` (settings, threat value; pure, tested) · `Aggro.lua` (aggro states/summary, next threat, own threat by role; pure, tested) ·
  `Threat.lua` (the only threat/nameplate API calls; tested with mocks) · `Plates.lua` (number marker frames on
  nameplates; tested with mocks) ·
  `PaTiAggro.lua` (window, paint, scan scheduler, settings, commands, events) ·
  `Locales/` · `Shared/` (PaTiShared, synced — never edit).
- SavedVariables: `PaTiAggroDB` (per character; the old `PaTiTankDB` is not read — new addon folder), schema 1: x, y (+ point/relativePoint once dragged), locked, collapsed, scale,
  language, markPlates, myRole (AUTO | TANK | HEALER | DAMAGER), opacity, theme.
- Secure / combat-sensitive: none — no secure frames, so window, collapse and test mode also work in combat. Keep it that way.
  Clickable aggro rows were investigated (F17) and are not possible safely; never target from addon code.
- Secret values: target name and threat go straight to widgets; `Logic.ThreatValue` checks before clamping.
- Secret values (aggro): every threat status, GUID and flag is checked with `issecretvalue` before use; unreadable
  → `Aggro.UNREADABLE` → state UNKNOWN, never CONTROLLED. Enemy/holder names only go to SetText.
- Hot path: aggro scans are coalesced (`requestScan`,
  0.1 s), skipped while collapsed or in test mode; nameplates are tracked by events, never by looping 1..40.
  `UNIT_TARGET` fires for every unit — only party1-4 trigger a scan.
- Slash commands: `/paggro`, `/patiaggro`, and `/pt` as a transition alias from PaTiTank (owner 2026-10-14).

## Checks
`bash ../../PaTiAdmin/tools/check.sh .` before every commit. Manual WoW tests: `../../PaTiAdmin/docs/TESTING.md`.

## PaTiAlerts (optional)
Reports its current alerts with `PaTiAlertsAPI.Sync("PaTiAggro", list)` (tank view; the healer/damage view sends an empty list) after every normal refresh — only if the API
exists with version 1, always inside `pcall` (PaTiAdmin/AGENTS.md §3). The list is built by a pure, tested function.
Without PaTiAlerts nothing may change. Never make PaTiAlerts a dependency.

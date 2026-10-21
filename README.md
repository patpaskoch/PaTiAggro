# PaTiAggro

<img src="assets/icon-128.png" width="96" alt="PaTiAggro icon">

Aggro for every role in World of Warcraft: Forever (Interface 16001). As a **tank** you see your threat on your
target, who pulls it next and which enemies you lost; as a **healer or damage dealer** you see how close you are to
pulling and who has the aggro on your target. Display only — it never targets or taunts.

> Formerly **PaTiTank** (renamed 2026-10-14). Status: 0.1.0, in development, not yet released. Not yet tested in game.
> Coming from PaTiTank: delete the old `PaTiTank` folder in `AddOns`; your PaTiTank settings (position, size …) start
> fresh once.

## Install in 4 steps

### 1. Download
At the top of this page click the green **`<> Code`** button → at the very bottom **Download ZIP**.
The file `PaTiAggro-main.zip` lands in your **Downloads** folder.

### 2. Open the AddOns folder
Open Battle.net → choose **World of Warcraft** → choose the version **WoW Forever** at the top →
click the **gear** next to "Play" → **Show in Explorer**.
In the window that opens, double-click one after the other: **`_classic_beta_`** → **`Interface`** → **`AddOns`**.
WoW Forever lives in the **`_classic_beta_`** folder, even when `_retail_` or `_classic_` sit next to it (those are
other WoW versions). If `_classic_beta_` opens right away, continue with `Interface`.
(No `AddOns` folder yet: right-click the empty area → **New → Folder** → name it `AddOns`.)

### 3. Drag the folder in and rename it
In **Downloads** double-click `PaTiAggro-main.zip`. It holds a folder **`PaTiAggro-main`** —
drag it with the mouse into the **AddOns** folder. Then there: right-click the folder → **Rename** →
**`PaTiAggro`** (without "-main", otherwise WoW does not load it).

✅ It is right when you see the file `PaTiAggro.toc` directly inside the `PaTiAggro` folder.
Is there still an old **`PaTiTank`** folder: delete it (right-click → Delete) — PaTiAggro replaces it; both together
show two windows and double numbers.

### 4. Enable it in the game
Start WoW → in the character selection at the bottom left **AddOns** → tick **PaTiAggro** →
(if shown: tick **Load out of date AddOns**) → **Okay** → log in.

Type **`/paggro test`** in the chat: now you see the window with example enemies.
`/paggro test` again ends the preview.

Healer or damage? `/paggro settings` → choose **My role**. Auto uses the group role — without assigned roles it shows
the tank view ("0 / 5").

Something does not work? Just write at which step you are stuck — best with a screenshot.


## Features
- **My role** (Settings): Auto, Tank, Healer or Damage. Auto uses the role WoW reports for you in the group; without
  one, but with another member assigned as tank, it shows your own threat; without any role it shows the tank view.
  Never guessed from your class — as healer or damage without group roles, set "My role" once (saved per character).

The window has three sections, top to bottom, with clear space between them:

```
5 / 6  AGGRO TOTAL

AGGRO TARGET  Test enemy
[ Brom (Tank)              has aggro ]   green: the right one has it
[ Lyra (Damage)                 84 % ]   yellow from 70 %, red from 90 % (100 % = they take it)
[ Mira (Healer)                 35 % ]


AGGRO TEAM
▌1 Ghoul                Mira (Healer)    red: Mira has it
▌2 Zombie               Lyra (Damage)    yellow: you still hold it, Lyra is about to take it
```
The section names are small captions in the accent colour, like PaTiHeal's "TARGET" mark. Only sections with
content are shown: no AGGRO TOTAL without enemies, no AGGRO TARGET without an enemy target, no AGGRO TEAM without rows.

**AGGRO TOTAL**
- Tank: how many of the enemies your group fights you hold (`5 / 6`)
- Healer/damage: your highest threat over your target and every enemy the group fights (healing threat lands on all
  of them) — white below 70 %, yellow from 70 %, red from 90 %. An enemy that attacks you shows only in
  AGGRO TARGET (the red "has aggro" bar), not a second time here

**AGGRO TARGET** — the caption with your target's name above the bars
- As healer or damage: **"not the tank's target"** in yellow on the right when you have another enemy targeted than
  the tank (the tank is the member with the WoW role Tank). Only a hint — nothing is targeted for you
- You and every group member (and pet) on its threat list, sorted: who has the aggro first, then by percent
- Each as `Name (Role)` — the role when WoW assigned one, else the class
- The one who has it shows "has aggro": green when that is right (you as tank, or the tank when you are not),
  red when not. Everyone else shows how far they are to taking it (100 % = they pull it). An enemy nobody attacked
  yet shows you with 0 %

**AGGRO TEAM** (tank only)
- Tank: up to four enemies that need you — red = lost, with `Name (Role)` of who has it; yellow = you still hold it
  but `Name (Role)` is about to take it ("slipping" when WoW does not say who); grey = unclear.
  Unreadable data is shown as "unclear", never as held
- With **PaTiAlerts** installed (optional), the tank's lost and slipping rows also appear there, with the same number

**Both views**
- Enemies come from your target, visible nameplates and your party's targets
- **Numbered nameplates:** every AGGRO TEAM row gets a number (`1 Ghoul`), and the same number stands above
  that enemy's nameplate — red = lost, yellow = barely held, grey = unclear. Two enemies with the same name
  are told apart by their number. Click the nameplate with that number to target the enemy.
  PaTiAggro never targets or taunts on its own
- A row without a number has no nameplate that can be named safely right now (e.g. the enemy is off screen) —
  PaTiAggro shows no number rather than a wrong one
- ••• menu: Settings, Lock, Collapse, Test Mode, Hide. Settings: language, my role, scale, lock.
  Languages: English, Deutsch (others fall back to English)

## PaTiSuite

This addon is part of the **PaTiSuite** — a collection of small addons for World of Warcraft: Forever.
Each one is installed on its own and works on its own; none of them is needed by another.

- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – optional control panel to show and hide the PaTi windows
- [PaTiHeal](https://github.com/patpaskoch/PaTiHeal) – healing: party frames, heal target, click casting, HoTs, dispels
- [PaTiAuras](https://github.com/patpaskoch/PaTiAuras) – buffs, procs, tracking, group buffs and weapon imbues
- **PaTiAggro** – aggro for tank, healer and damage *(this addon)*
- [PaTiRota](https://github.com/patpaskoch/PaTiRota) – your own skill priority with cooldowns and fixed cast buttons
- [PaTiGroup](https://github.com/patpaskoch/PaTiGroup) – party awareness: tank, healer, roles and the tank's target
- [PaTiLead](https://github.com/patpaskoch/PaTiLead) – lead the group: raid markers, ready check and pull timer
- [PaTiQuest](https://github.com/patpaskoch/PaTiQuest) – selected quest and its objectives
- [PaTiDungeon](https://github.com/patpaskoch/PaTiDungeon) – instance, group and combat status
- [PaTiSocial](https://github.com/patpaskoch/PaTiSocial) – "Party Social": quick emote and message buttons
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – one window for open problems

### Goes well with (optional)

- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – lists enemies you lost or barely hold (tank view), with the same number as the panel and the nameplate
- [PaTiLead](https://github.com/patpaskoch/PaTiLead) – manual group tools: raid markers, ready check, pull timer
- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – shows and hides this window together with the other PaTi windows

## First steps
- `/paggro test` shows the display with example enemies — the tank view or, with "My role" set to Healer or Damage,
  the healer/damage view
- Turn on enemy nameplates (default key V) so PaTiAggro sees more than your target
- `/paggro` shows or hides the window
- A red row `1 Kultist → Healer` appears: click the nameplate showing a red "1" to target that enemy

## Settings
`/paggro settings` or ••• → Settings: language, my role, scale, window lock, numbers on nameplates on/off (off: no
numbers at all).
- **Window:** panel opacity (30–100 %)

## Commands
`/paggro` or `/patiaggro` (for now also `/pt`, the old PaTiTank command) — alone: show/hide · `settings` · `test` ·
`show` · `hide` · `lock` · `unlock` · `reset` (position) · `debug` (threat APIs, your role and the view) · `version`

## Known limitations
- Enemies without a visible nameplate that nobody in your group targets are not seen — for a healer without a
  target that means: turn on enemy nameplates.
- The rows in the panel are not clickable: WoW does not let an addon decide in combat which enemy a click targets.
  Click the numbered nameplate instead.
- Numbers need visible enemy nameplates; forbidden nameplates are left alone. Numbers 1–4 (the visible rows).
- The healer/damage view sends nothing to PaTiAlerts yet.
- The threat APIs are not yet confirmed in the Forever client.

## Development

Architecture, tests and engineering rules of the suite: [PaTiAdmin](https://github.com/patpaskoch/PaTiAdmin). PaTiAdmin is not a WoW addon — players do not install it. The shared UI code (PaTiShared) is already embedded in this addon's `Shared/` folder; there is nothing extra to install.

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Patrick Koch.

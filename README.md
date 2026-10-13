# PaTiTank

<img src="assets/icon-128.png" width="96" alt="PaTiTank icon">

A small tank HUD for World of Warcraft: Forever (Interface 16001): your threat on your target and which
enemies you do not hold any more. Display only — it never targets or taunts.

> Status: 0.1.0, in development, not yet released. Not yet tested in game.

## 🇩🇪 Installieren in 4 Schritten

### 1. Herunterladen
Oben auf dieser Seite auf den grünen Knopf **`<> Code`** klicken → ganz unten **Download ZIP**.
Die Datei `PaTiTank-main.zip` landet in deinem Ordner **Downloads**.

### 2. Den AddOns-Ordner öffnen
Battle.net öffnen → **World of Warcraft** auswählen → oben die Version **WoW Forever** wählen →
auf das **Zahnrad** neben „Spielen“ klicken → **Im Explorer anzeigen**.
Im Fenster, das aufgeht, nacheinander doppelklicken: **`_classic_beta_`** → **`Interface`** → **`AddOns`**.
WoW Forever liegt immer in **`_classic_beta_`**, auch wenn daneben `_retail_` oder `_classic_` liegen (die sind für andere
WoW-Versionen). Öffnet sich schon `_classic_beta_`, geht es direkt mit `Interface` weiter.
(Gibt es `AddOns` noch nicht: Rechtsklick in den leeren Bereich → **Neu → Ordner** → `AddOns` nennen.)

### 3. Den Ordner hineinziehen und umbenennen
In **Downloads** die Datei `PaTiTank-main.zip` doppelklicken. Darin ist ein Ordner **`PaTiTank-main`** —
den mit der Maus in den **AddOns**-Ordner ziehen. Dann dort: Rechtsklick auf den Ordner → **Umbenennen** →
**`PaTiTank`** (ohne „-main“, sonst lädt WoW ihn nicht).

✅ Richtig ist es, wenn du im Ordner `PaTiTank` direkt die Datei `PaTiTank.toc` siehst.

### 4. Im Spiel einschalten
WoW starten → in der Charakterauswahl unten links **AddOns** → Haken bei **PaTiTank** →
(falls angezeigt: Haken bei **Veraltete AddOns laden**) → **Okay** → einloggen.

Im Chat **`/pt test`** eingeben: Jetzt siehst du das Fenster mit Beispiel-Gegnern. Nochmal `/pt test` beendet die Vorschau.

Klappt etwas nicht? Schreib einfach, bei welchem Schritt du hängst — am besten mit einem Screenshot.

## Features
- Your current target and your threat on it (no own health bar — that is not the tank addon's job)
- **Next:** the group member closest to pulling your target, e.g. `Next: Mage 92 %` — white below 70 %, yellow from
  70 %, red from 90 % (100 % = they pull it). Only while you tank the target; unreadable values show "unclear"
- **Aggro control:** `AGGRO 5 / 6 under control` plus up to four rows for enemies that need you:
  red = lost, with who has it (role, else name, else "other player"), yellow = barely held, grey = unclear.
  Unreadable data is shown as "unclear", never as "under control"
- Enemies come from your target, visible nameplates and your party's targets
- With **PaTiAlerts** installed (optional), the lost and barely held rows also appear there, with the same number
- **Numbered nameplates:** every problem row gets a number (`1 Kultist → Healer`), and the same number stands above
  that enemy's nameplate — red = lost, yellow = barely held, grey = unclear. Two enemies with the same name are told
  apart by their number. Click the nameplate with that number to target the enemy, then taunt yourself.
  PaTiTank never targets or taunts on its own
- A row without a number has no nameplate that can be named safely right now (e.g. the enemy is off screen) —
  PaTiTank shows no number rather than a wrong one
- ••• menu: Settings, Lock, Collapse, Test Mode, Hide. Settings: language, scale, lock.
  Languages: English, Deutsch (others fall back to English)

## PaTiSuite

This addon is part of the **PaTiSuite** — a collection of small addons for World of Warcraft: Forever.
Each one is installed on its own and works on its own; none of them is needed by another.

- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – optional control panel to show and hide the PaTi windows
- [PaTiHeal](https://github.com/patpaskoch/PaTiHeal) – healing: party frames, heal target, click casting, HoTs, dispels
- [PaTiAuras](https://github.com/patpaskoch/PaTiAuras) – buffs, procs, tracking, group buffs and weapon imbues
- **PaTiTank** – tank HUD and aggro monitor *(this addon)*
- [PaTiRota](https://github.com/patpaskoch/PaTiRota) – your own skill priority with cooldowns and fixed cast buttons
- [PaTiGroup](https://github.com/patpaskoch/PaTiGroup) – party awareness: tank, healer, roles and the tank's target
- [PaTiLead](https://github.com/patpaskoch/PaTiLead) – lead the group: raid markers, ready check and pull timer
- [PaTiQuest](https://github.com/patpaskoch/PaTiQuest) – selected quest and its objectives
- [PaTiDungeon](https://github.com/patpaskoch/PaTiDungeon) – instance, group and combat status
- [PaTiSocial](https://github.com/patpaskoch/PaTiSocial) – "Party Social": quick emote and message buttons
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – one window for open problems

### Goes well with (optional)

- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – lists enemies you lost or barely hold, with the same number as the panel and the nameplate
- [PaTiLead](https://github.com/patpaskoch/PaTiLead) – manual group tools: raid markers, ready check, pull timer
- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – shows and hides this window together with the other PaTi windows

## Installation
1. Download the release zip (`PaTiTank-<version>.zip`).
2. Unpack it and copy the folder `PaTiTank` into `World of Warcraft/<client>/Interface/AddOns/`.
3. Start WoW and enable PaTiTank in the AddOns list.

## First steps
- `/pt test` shows the aggro display with six example enemies
- Turn on enemy nameplates (default key V) so PaTiTank sees more than your target
- `/pt` shows or hides the window
- A red row `1 Kultist → Healer` appears: click the nameplate showing a red "1" to target that enemy

## Settings
`/pt settings` or ••• → Settings: language, scale, window lock, numbers on nameplates on/off (off: no numbers at all).
- **Window:** panel opacity (30–100 %)

## Commands
`/pt` or `/patitank` — alone: show/hide · `settings` · `test` · `show` · `hide` · `lock` · `unlock` · `reset` (position) ·
`debug` (also shows which threat APIs your client offers) · `version`

## Known limitations
- Enemies without a visible nameplate that nobody in your group targets are not seen.
- The rows in the panel are not clickable: WoW does not let an addon decide in combat which enemy a click targets.
  Click the numbered nameplate instead.
- Numbers need visible enemy nameplates; forbidden nameplates are left alone. Numbers 1–4 (the visible rows).
- The threat APIs are not yet confirmed in the Forever client.

## Development

Architecture, tests and engineering rules of the suite: [PaTiAdmin](https://github.com/patpaskoch/PaTiAdmin). PaTiAdmin is not a WoW addon — players do not install it. The shared UI code (PaTiShared) is already embedded in this addon's `Shared/` folder; there is nothing extra to install.

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Patrick Koch.

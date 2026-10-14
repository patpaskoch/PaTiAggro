# PaTiAggro

<img src="assets/icon-128.png" width="96" alt="PaTiAggro icon">

Aggro for every role in World of Warcraft: Forever (Interface 16001). As a **tank** you see your threat on your
target, who pulls it next and which enemies you lost; as a **healer or damage dealer** you see how close you are to
pulling and which enemies attack you. Display only — it never targets or taunts.

> Formerly **PaTiTank** (renamed 2026-10-14). Status: 0.1.0, in development, not yet released. Not yet tested in game.
> Coming from PaTiTank: delete the old `PaTiTank` folder in `AddOns`; your PaTiTank settings (position, size …) start
> fresh once.

## 🇩🇪 Installieren in 4 Schritten

### 1. Herunterladen
Oben auf dieser Seite auf den grünen Knopf **`<> Code`** klicken → ganz unten **Download ZIP**.
Die Datei `PaTiAggro-main.zip` landet in deinem Ordner **Downloads**.

### 2. Den AddOns-Ordner öffnen
Battle.net öffnen → **World of Warcraft** auswählen → oben die Version **WoW Forever** wählen →
auf das **Zahnrad** neben „Spielen“ klicken → **Im Explorer anzeigen**.
Im Fenster, das aufgeht, nacheinander doppelklicken: **`_classic_beta_`** → **`Interface`** → **`AddOns`**.
WoW Forever liegt im Ordner **`_classic_beta_`**, auch wenn daneben `_retail_` oder `_classic_` liegen (die sind für andere
WoW-Versionen). Öffnet sich schon `_classic_beta_`, geht es direkt mit `Interface` weiter.
(Gibt es `AddOns` noch nicht: Rechtsklick in den leeren Bereich → **Neu → Ordner** → `AddOns` nennen.)

### 3. Den Ordner hineinziehen und umbenennen
In **Downloads** die Datei `PaTiAggro-main.zip` doppelklicken. Darin ist ein Ordner **`PaTiAggro-main`** —
den mit der Maus in den **AddOns**-Ordner ziehen. Dann dort: Rechtsklick auf den Ordner → **Umbenennen** →
**`PaTiAggro`** (ohne „-main“, sonst lädt WoW ihn nicht).

✅ Richtig ist es, wenn du im Ordner `PaTiAggro` direkt die Datei `PaTiAggro.toc` siehst.
Liegt dort noch ein alter Ordner **`PaTiTank`**: löschen (Rechtsklick → Löschen) — PaTiAggro ersetzt ihn.

### 4. Im Spiel einschalten
WoW starten → in der Charakterauswahl unten links **AddOns** → Haken bei **PaTiAggro** →
(falls angezeigt: Haken bei **Veraltete AddOns laden**) → **Okay** → einloggen.

Im Chat **`/paggro test`** eingeben: Jetzt siehst du das Fenster mit Beispiel-Gegnern. Nochmal `/paggro test` beendet die Vorschau.

Heiler oder Schaden? `/paggro settings` → **Meine Rolle** wählen (Auto nimmt die Gruppenrolle).

Klappt etwas nicht? Schreib einfach, bei welchem Schritt du hängst — am besten mit einem Screenshot.


## Features
- **My role** (Settings): Auto, Tank, Healer or Damage. Auto uses the role WoW reports for you in the group; without
  one it shows the tank view. Never guessed from your class.

**Tank view**
- **Threat bar:** your target's name on the left, your threat percent on the right. The colour comes from your threat
  status, not the percent (while you tank, WoW reports 100 % for you): green = you hold it, yellow = you hold it but
  someone has more threat, red = someone else has it. No target: an empty bar
- **Next:** a small bar under the threat bar, only when it matters — the player (by name) closest to pulling your
  target, from 70 %
  (yellow), red from 90 %. Their percent is how far they are to taking it (100 % = they pull it); yours stays at
  100 % while you hold it — two different scales, both from WoW
- **Aggro:** `AGGRO 5 / 6` plus up to four rows for enemies that need you:
  red = lost, with who has it (role, else name, else "other player"), yellow = barely held, grey = unclear.
  Unreadable data is shown as "unclear", never as held
- With **PaTiAlerts** installed (optional), the lost and barely held rows also appear there, with the same number

**Healer / damage view**
- **Threat bar:** the enemy you are closest to pulling, over your target and every enemy your group fights (healing
  threat lands on all of them) — its name left, your percent right; green below 70 %, yellow from 70 %, red from 90 %.
  Under the bar only when it matters: `You: about to pull` (from 90 %) or `AGGRO on you!` (red, full bar)
- **ON YOU:** up to four rows for the enemies that attack you, numbered on their nameplates like in the tank view

**Both views**
- Enemies come from your target, visible nameplates and your party's targets
- **Numbered nameplates:** every row gets a number (`1 Kultist → Healer`), and the same number stands above
  that enemy's nameplate — red = lost / on you, yellow = barely held, grey = unclear. Two enemies with the same name
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

## Installation
1. Download the release zip (`PaTiAggro-<version>.zip`).
2. Unpack it and copy the folder `PaTiAggro` into `World of Warcraft/<client>/Interface/AddOns/`.
3. Delete an old `PaTiTank` folder there, if you have one — both together show two windows and double numbers.
4. Start WoW and enable PaTiAggro in the AddOns list.

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

# Ingame Testing – PaTiAggro (früher PaTiTank)

World of Warcraft: Forever
Interface: 16001

Diese Datei dokumentiert ausschließlich Tests im echten WoW-Client.

Automatisierte Tests, CI und Code Review zählen NICHT als Ingame-Verifikation.
Regeln und Eintragen von Ergebnissen: [PaTiAdmin/docs/TESTING.md](https://github.com/patpaskoch/PaTiAdmin/blob/main/docs/TESTING.md#in-game-test-files).

## Legende

- [ ] offen / noch nicht bestätigt
- [x] vom Owner im echten Client bestätigt
- ❌ FAIL = im echten Client fehlgeschlagen
- 🔧 FIX IMPLEMENTED = Codefix vorhanden, Retest noch offen
- ✅ VERIFIED = erfolgreich im echten Client bestätigt
- MANUAL RETEST REQUIRED = erneuter Test notwendig

> Umbenannt 2026-10-14: Die Tests `PT-TANK-…` behalten ihre IDs (IDs werden nie umnummeriert) und gelten für PaTiAggro
> in der Tank-Ansicht; `/pt` funktioniert weiter, `/paggro` ist der neue Befehl. Neue Tests heißen `PT-AGGRO-…`.

## Installation / Laden

- [ ] PT-TANK-001 Fresh Install aus dem Release-ZIP: genau ein Ordner `PaTiTank/`, Addon lädt allein
- [ ] PT-TANK-002 PaTiTank erscheint in der AddOn-Liste mit Beschreibung
- [x] PT-TANK-003 Icon in der AddOn-Liste korrekt, keine weiße oder fehlende Textur
  - ✅ VERIFIED 2026-10-02
  - Owner: die Icons erscheinen im Spiel in der AddOn-Liste korrekt.
- [ ] PT-TANK-004 Login ohne Lua-Fehler
- [ ] PT-TANK-005 `/reload` ohne Lua-Fehler
- [ ] PT-TANK-006 `/pt debug` nennt die vorhandenen Threat-APIs und eine Aggro-Zeile

## Fenster

- [ ] PT-TANK-010 `/pt` bzw. `/patitank` blendet das Fenster ein und aus; `/pt show`, `/pt hide`
- [ ] PT-TANK-011 Fenster am Header verschieben (entsperrt)
- [ ] PT-TANK-012 Position bleibt nach `/reload`
- [ ] PT-TANK-013 Lock/Unlock (••• und `/pt lock` / `unlock`): gesperrt nicht verschiebbar
- [ ] PT-TANK-014 Größe (Scale) wirkt
- [ ] PT-TANK-015 Einstellungen öffnen (`/pt settings` und •••) und speichern
- [ ] PT-TANK-016 Collapse/Expand über •••, Zustand bleibt nach `/reload`
- [ ] PT-TANK-017 Test Mode `/pt test`: 6 Gegner, „5 / 6“, Ghul → Heiler, Zombie knapp; Zeilen `1 Ghul`, `2 Zombie`
  ohne Namensschild-Nummern
- [ ] PT-TANK-018 Panel-Deckkraft 30–100 %: nur der Hintergrund ändert sich
- [ ] PT-TANK-019 Keine Einrast-Einstellung mehr, Fenster frei verschiebbar
- [ ] PT-TANK-020 `/pt reset` setzt die Position zurück

## SavedVariables

- [ ] PT-TANK-030 Einstellungen bleiben nach `/reload`
- [ ] PT-TANK-031 Einstellungen bleiben nach Relog
- [ ] PT-TANK-032 Update mit alten Einstellungen: Position und Werte bleiben
- [ ] PT-TANK-033 „Standard wiederherstellen“ setzt die Einstellungen zurück

## Sprachen

- [ ] PT-TANK-040 deDE: alle Texte deutsch
- [ ] PT-TANK-041 Sprache enUS in den Einstellungen: nach `/reload` englisch
- [ ] PT-TANK-042 zhCN/zhTW/koKR: Englisch als Rückfall, keine Schlüsselnamen oder Kästchen
- [ ] PT-TANK-043 Keine abgeschnittenen wichtigen Texte (deDE), auch lange Gegnernamen

## Basic HUD

- ~~PT-TANK-050 Eigene Gesundheit aktualisiert sich~~
  - RETIRED 2026-10-10 – eigener Lebensbalken entfernt (Owner: PaTiTank nur Bedrohung und Aggro)
- [ ] PT-TANK-113 Kein eigener Lebensbalken mehr: oben Ziel, darunter Bedrohung, dann Aggro-Block; keine Lücke, Fenster passt
  sich an; `/pt test` ebenso
  - 🔧 FIX IMPLEMENTED 2026-10-10 (Owner: kein Lebensbalken im Tank-Addon)
  - MANUAL RETEST REQUIRED
- [ ] PT-TANK-051 Aktuelles Ziel wird angezeigt und wechselt mit
- [ ] PT-TANK-052 Eigene Bedrohung auf dem Ziel wird angezeigt
- [ ] PT-TANK-114 Zeile „Nächster:“ in der Gruppe: wer am nächsten am Aggro-Ziehen ist (Rolle oder Name) mit Prozent;
  weiß unter 70 %, gelb ab 70 %, rot ab 90 %; bei 100 % zieht dieser Spieler wirklich
  - 🔧 FIX IMPLEMENTED 2026-10-11 (Owner-Wunsch: vorher sehen, wer gleich Aggro zieht)
  - MANUAL RETEST REQUIRED
- [ ] PT-TANK-115 „Nächster: —“ ohne Ziel, solo, oder wenn du das Ziel nicht tankst; `/pt test` zeigt „Schaden 84 %“ gelb
  - MANUAL RETEST REQUIRED
- [ ] PT-TANK-116 Begleiter (Jägerpet/Wichtel) wird als „Begleiter“ berücksichtigt; im Kampf kein Lua-Fehler, Werte
  aktualisieren sich laufend (nicht „unklar“ hängen bleiben)
  - MANUAL RETEST REQUIRED

## Aggro Control

- [ ] PT-TANK-060 Pull mit 3+ Gegnern: „x / y unter Kontrolle“ stimmt
- [ ] PT-TANK-061 Verlorener Gegner (LOST): rote Zeile mit Halter
- [ ] PT-TANK-062 Knapp gehaltener Gegner (DANGER): gelbe Zeile
- [ ] PT-TANK-063 Nicht lesbare Daten (UNKNOWN): graue Zeile „unklar“, nie „unter Kontrolle“
- [ ] PT-TANK-064 Mob auf dem Heiler: „→ Heiler“ innerhalb von ~1 s
- [ ] PT-TANK-065 Mob auf einem DD: „→ DD“ (bzw. Name oder „anderer Spieler“ ohne Rolle)
- [ ] PT-TANK-066 Tote Gegner verschwinden aus Zählung und Zeilen

## Nummerierung

- [ ] PT-TANK-070 Jede Problemzeile hat eine Nummer (1–4) im Panel
- [ ] PT-TANK-071 Dieselbe Nummer steht über dem Namensschild des Gegners, Farbe = Zustand
- [ ] PT-TANK-072 Gleiche Nummer = gleicher Mob
- [ ] PT-TANK-073 Zwei gleichnamige Gegner: Nummern trotzdem richtig zugeordnet
- [ ] PT-TANK-074 Aggro zurück → Nummer am Namensschild weg
- [ ] PT-TANK-075 Mob tot → Nummer weg
- [ ] PT-TANK-076 Namensschild verschwindet und wird wiederverwendet → keine alte Nummer
- [ ] PT-TANK-077 Zeile ohne sicheres Namensschild (z. B. außerhalb des Bildschirms) hat keine Nummer
- [ ] PT-TANK-078 Einstellung „Nummern an Namensschildern“ aus → keine Nummern

## Targeting

- [ ] PT-TANK-080 Klick auf das normale Namensschild mit Nummer wählt genau diesen Mob als Ziel
- [ ] PT-TANK-081 Kein automatisches Targeting
- [ ] PT-TANK-082 Kein automatischer Taunt

Panel-Zeilen sind nicht klickbar (technisch blockiert, F17) und werden nicht getestet.

## PaTiAlerts

- [ ] PT-TANK-090 LOST erscheint in PaTiAlerts (rot, kritisch)
- [ ] PT-TANK-091 DANGER erscheint in PaTiAlerts (gelb, Warnung)
- [ ] PT-TANK-092 Gleiche Nummer wie im Panel und am Namensschild
- [ ] PT-TANK-093 Aggro zurück / Mob tot → Alert verschwindet
- [ ] PT-TANK-094 Ohne PaTiAlerts: unverändert, kein Lua-Fehler

## Combat / Sicherheit

- [ ] PT-TANK-100 Kein Lua-Fehler im Kampf
- [ ] PT-TANK-101 Keine `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN`
- [ ] PT-TANK-102 `taint.log` (`/console taintLog 1`) ohne PaTiTank-Eintrag
- [ ] PT-TANK-103 Menü und Slash-Befehle im Kampf ohne Fehler

## Combined

- [ ] PT-TANK-110 Zusammen mit allen PaTi-Addons geladen: kein Lua-Fehler
- [ ] PT-TANK-111 Keine Slash-Command-Kollision: `/pt` und `/patitank` antworten nur PaTiTank
- [ ] PT-TANK-112 Eigene Einstellungen speichern nur PaTiTank-Werte; Fenster erscheint in PaTiSuite

## Umbenennung (PaTiAggro)

- [ ] PT-AGGRO-001 Alter Ordner `PaTiTank` gelöscht, `PaTiAggro` installiert: Addon heißt in der AddOn-Liste PaTiAggro,
  mit Beschreibung und Icon; Login ohne Lua-Fehler
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-002 `/paggro`, `/patiaggro` und `/pt` öffnen/schließen das Fenster; `/paggro debug` zeigt die Zeile „Role:“
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-003 Einstellungen starten einmal neu (Position, Größe …), danach bleiben sie nach `/reload`
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-004 PaTiAlerts zeigt Aggro-Meldungen unter der Quelle „PaTiAggro“; PaTiSuite listet „Aggro“ statt „Tank“
  - MANUAL RETEST REQUIRED

## Rollen

- [ ] PT-AGGRO-010 Einstellung „Meine Rolle“: Auto / Tank / Heiler / Schaden; Wechsel sofort sichtbar (Beschriftungen,
  Block „AGGRO“ ↔ „AUF DIR“), bleibt nach `/reload`
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-011 Auto in der Gruppe mit zugewiesener Rolle (Heiler/Schaden) zeigt die passende Ansicht; ohne Rolle die
  Tank-Ansicht
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-012 Tank: Balken grün, solange du das Ziel sicher hältst; gelb, wenn jemand mehr Bedrohung hat; rot, wenn
  ein anderer es hat
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-013 Heiler/Schaden: „Deine Bedrohung (höchste)“ steigt beim Heilen/Schaden; „Du: ruhig“ unter 70 %,
  „steigt“ ab 70 %, „ziehst gleich“ ab 90 % (Farbe passend)
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-014 Heiler/Schaden: Ein Gegner greift dich an → „AGGRO auf dir!“, voller roter Balken, Zeile im Block
  „AUF DIR“ mit „→ dich“ und Nummer am Namensschild; Aggro weg → Zeile und Nummer verschwinden
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-015 Heiler ohne Ziel: Bedrohung wird trotzdem angezeigt (Feind-Namensschilder an, Taste V)
  - MANUAL RETEST REQUIRED
- [ ] PT-AGGRO-016 `/paggro test` mit Rolle Heiler oder Schaden: „AGGRO auf dir!“ und eine Zeile Ghul → dich;
  mit Rolle Tank die bisherige Testansicht (Balken grün 100 %, „Nächster: Schaden 84 %“)
  - MANUAL RETEST REQUIRED

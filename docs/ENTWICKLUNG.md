# BULBRO – Entwicklungsstand

Ergänzt [GDD.md](GDD.md) und [ART_STYLE.md](ART_STYLE.md). Hier stehen der Stand je Phase, Entscheidungen, die das GDD offenlässt (Startwerte), und offene Punkte. Bei Änderungen an Werten oder Regeln bitte mitpflegen.

## Nächste Sitzung

Stand 23.10.2026, Spezifikation in [PHASE_15.md](PHASE_15.md):

- **Erledigt:** Paket 1 (Crash nach Bosssieg, `a4c51cb`, Nacharbeit typisierte Literale `89833f1`) und Paket 2 (Lexikon-Erweiterungen, `55bf4bc`).
- **Crash-Fix im echten Spiel bestätigt:** Bosssieg mit LED-Schütze auf Spannung 0. „Glasfaser“ wurde freigeschaltet, Sieg, Challenge und Statistik sind gespeichert, der Fortsetzen-Stand wurde gelöscht.
- **Erledigt 22.10.:** Spielstand-Trennung für Headless-Checks/Tests (`38855c5`), Paket 3 (Admin-Modus, `7211a38`), Paket 4 (HUD und Tooltips, `5d3fadf`) und Paket 5 (Run-Statistiken und Run-Ende, inkl. der beiden Zusatzpunkte: Schadenszahlen verschwinden, „Nochmal“ bleibt).
- **Erledigt 22./23.10.:** Audio-Leak beim Beenden (`35963db`) und Paket 6 (Endlos-Modus, Punkte 1–6 inkl. der Ergänzungen Boss-Kartons und Banner „Bosse besiegt!“ mit Zähler „Besiegte Boss-Zyklen“).
- **Offen in Paket 6:** Punkt 7, Simulator-Auswertung der Endlos-Schwierigkeit. Tabelle und Wertvorschläge werden dem Spieler gezeigt; Werte in `endless_config.tres` erst nach seinem OK ändern.
- **Als Nächstes:** danach die Pakete 7 bis 9 der Reihe nach, jeweils mit Commit, Push und Eintrag hier.
- **Für Paket 9 schon vorhanden:** `SaveManager.get_run_history()` liefert die letzten 20 Runs (neueste zuerst) mit Charakter, Spannung, Ergebnis, Welle, Endlos-Welle, Datum, Kampfzeit, Level, Kills und Top-3-Quellen. Siehe Abschnitt „Run-Statistik und Run-Ende“.

Offene Punkte:
- `stats.runs` = 2 im echten Spielstand ist geklärt (22.10.): Die 6.014 Kills übersteigen, was ein einzelner Run auf Spannung 0 liefern kann (rund 4.850 Gegner in den Wellen 1–19 plus Bosswelle). Es sind also zwei echte Runs mit Kills zu Ende gegangen, vermutlich der in der Sicherung vom 21.10. gespeicherte, unterbrochene Run (per „Fortsetzen“) und der Sieg mit dem LED-Schützen. Headless-Check und Tests können seit dem 22.10. ohnehin nicht mehr in den echten Spielstand schreiben.
- Runs, die zwischen dem 21.10. 14:10 (Fehler eingeführt) und dem Fix endeten, fehlen in der Statistik und lassen sich nicht nachtragen.
- `piercing_dmg_pct` und `boss_dmg_pct` wirken seit Paket 2, aber noch kein Item gibt diese Stats (Kandidaten für Paket 8).
- Der Run-Ende-Bildschirm wurde mit nachgestellten Run-Daten geprüft (Screenshots 1920×1080 und 1280×720, Sieg und Tod im Endlos-Modus). Ein echter Sieg im Spiel mit Blick auf DPS-Werte und Diagramm steht noch aus.
- Erledigt 22.10.: „ObjectDB instances leaked“ im Headless-Check der Run-Szene. Betroffen waren nur `AudioStreamWAV` und `AudioStreamPlaybackWAV`: Effekte, die beim Beenden noch liefen. `stop()` übergibt das Stoppen asynchron an den Mixer-Thread; endet das Programm vorher, hält der AudioServer die Wiedergabe fest. Jetzt spielt der AudioManager headless keine Effekte (`output_enabled`), und „Beenden“ bzw. Fenster schließen laufen über `AudioManager.quit_game()` (alles stoppen, 0,1 s warten). Messung mit Unendlich HP über 20 Endloswellen (21–41): Nodes konstant 5.227, Objekte 11.430 ± 30, Resources konstant 1.276. Während eines Runs bleibt nichts liegen; die Zunahme in den ersten Wellen sind neue Gegner-Pools (je Gegnertyp 30 vorgewärmte Gegner, 271 Nodes).

Hinweise für den Neustart:
- Admin-Modus: `GameState.admin.used` sperrt `Unlocks.check` und `Unlocks.evaluate_run_end`. Neue Zähler (Achievements in Paket 9, Endlos-Bestwert in Paket 6) müssen dieselbe Sperre beachten.
- `Player.rebuild()` baut alle Werte neu auf (Charakter, Items, Run-Modifikatoren, Set-Boni); `test_player_rebuild.gd` vergleicht das für alle 22 Charaktere mit dem normalen Aufbau. Neue Effekt-Arten müssen dort weiter exakt gleich herauskommen.
- Der echte Spielstand liegt unter `%APPDATA%\Godot\app_userdata\Bulbro\save.json` (Sicherung `save.backup_2026-10-21.json`). Nie ohne OK des Spielers ändern. Tests nutzen `test_save.json` (`tests/pre_run_hook.gd`), Screenshot-Skripte sollen `SaveManager.use_path("user://shot_save.json")` setzen.
- Spielstand-Trennung (22.10.): Ohne Bildschirm nutzt das Spiel automatisch `user://headless_save.json` (frisch bei jedem Start), Tests zusätzlich `test_save.json`. Skripte mit Bildschirm setzen `-- --save=user://<name>.json` oder `BULBRO_SAVE`. Abgesichert durch `tests/unit/test_save_isolation.gd`.
- Leere Literale `{}`/`[]` nie in Ternär-Ausdrücken an typisierte Variablen geben; `tests/unit/test_typed_literals.gd` schlägt sonst fehl.
- Screenshots in echter Größe 1920×1080 gehen nur im Vollbild, gesetzt im Skript (`DisplayServer.window_set_mode`). `--resolution` allein ergibt wegen der Taskleiste 1920×1061.

## Bedienung zum Testen

| Taste | Funktion |
|---|---|
| F5 (Godot) | Spiel starten (Hauptmenü → Charakter → Startwaffe → Spannung → Run) |
| WASD / Pfeile / Stick | Bewegen |
| Esc / Start | Pause (Weiter, Optionen, Aufgeben) |
| F3 | Debug-Overlay mit allen Stats, FPS und Gegnerzahl |
| F10 | Admin-Menü (Optionen → Erweitert → Admin-Modus): Welle/Endlos wählen, Zeit anhalten/überspringen, Geschwindigkeit, Hitboxen, Charakter wechseln, Level/Funken setzen, Unverwundbar, Unendlich HP, Schaden x10, Gegner spawnen (auch Elites/Bosse)/entfernen/Arena füllen, Waffen/Items geben und entfernen, Shop kostenlos/Reroll gratis/Angebot platzieren, alle Charaktere freischalten |

Bosse testen: F10 → Run → Welle 20 starten; bei Spannung 5 erscheinen beide Bosse. Admin-Runs zählen nicht für Freischaltungen und Statistiken (Abzeichen „ADMIN“ im HUD).

## Stand je Phase

| Phase | Inhalt |
|---|---|
| 0 | Projektgerüst, Autoloads, Input-Map, GUT, CLAUDE.md |
| 1 | Art-Pipeline: SVG-Stil, Shader (Hit-Flash, Kontur), Juice-Animationen |
| 2 | Stat-System (FLAT, PERCENT, X-Modifikationen), Kampfformeln, Spieler, Arena, Debug-Overlay |
| 3 | Waffen-Grundsystem: Nah-/Fernkampf, gepoolte Projektile, Schadenszahlen |
| 4 | Gegner mit Verhaltens-Komponenten, 20 Wellen, rotes X, 100-Gegner-Limit, HUD, Game Over |
| 5 | Funken, Beutel, XP/Level, Batterien, Kartons, Leuchtkristalle, Funkendieb, Aufladung |
| 6 | Wellenende als State Machine: Kartons → Level-ups → Shop |
| 7 | Shop: Seltenheit, Sperren, Reroll, Inflation, Kombinieren, Stat-Vorschau |
| 8 | Effektsystem; alle 17 Waffen, 34 Items, 13 Set-Boni, Lampenturm; Debug-Menü; Datenprüfung |
| 9 | 12 Charaktere mit Sonderregeln und Freischaltungen; Hauptmenü, Auswahl, Optionen, Run-Ende |
| 10 | Restliche Gegner, Phasensystem, 3 Elites, 2 Bosse, Elite-/Hordewellen, legendäre Kartons |
| 11 | Partikel, Screenshake, Hit-Stop, Bodenflecken, synthetisierte Sounds, Musik-Loop, AudioManager |
| 12 | Versionierter JSON-Spielstand, Challenges mit Popup, gesperrte Items, Barrierefreiheit, manuelles Zielen, Run fortsetzen |
| 13 | Balancing-Simulator, Endlos-Modus, Übersetzungsprüfung (DE/EN), Performance-Pass, Windows-Export-Preset |
| 14a | Feste Angebotskarten (Kopf/Mitte/Fuß, gleiche Höhe, Schrift schrumpft statt Karte), Charakterauswahl mit festen Bereichen (Raster 4 Reihen, Infopanel scrollt intern) |
| 14c-3 | 10 neue Charaktere, Freischaltungen mit Fortschritt (Bestwert/Summe), 10 Sieg-Items, Debug: alle Charaktere freischalten |
| 14c-2 | 5 neue Startwaffen: Seelenlaterne, Feuerzeugwerfer, Kristallstab, Voodoo-Nadel, Dornenranke (auch im Shop) |
| 15-3 | Admin-Modus (F10, Optionen → Erweitert): Admin-Menü mit 6 Reitern, Admin-Runs zählen nicht, `Player.rebuild()` mit Regressionstest für alle 22 Charaktere |
| 15-4 | HUD und Tooltips: HP-Leisten unter normalen Gegnern (Option Immer/Nur bei Schaden/Aus), Tooltips für Waffen, Items, Set-Boni und Stats in Shop, Pause und Run-Ende (Maus und Gamepad, nie abgeschnitten), Stat-Panel mit Farben und Obergrenzen, Leiste „Aktive Set-Boni“, Tier-Kontur der schwebenden Waffen, Kills/Schaden je Waffe/Item/Effekt |
| 15-6 | Endlos-Modus überarbeitet: eigene `EndlessConfig` und `EndlessRules`, Dichte-Zuwachs, schwindende Aufladung, Doppelboss alle 10 Wellen mit linearem Zyklus-Bonus und legendären Kartons, Elite-/Hordewellen in Welle 25/35/…, Banner „Bosse besiegt! Zyklus n geschafft“, Zähler „Besiegte Boss-Zyklen“ (Run-Statistik und Historie), HUD „Endlos 7 (Welle 27)“, Shop-Hinweis „Nächste Welle: Bosse“, Bestwert „Höchste Endlos-Welle“ je Charakter (Charakterauswahl, Lexikon), Lexikon-Thema „Endlos-Modus“ |
| 15-5 | Run-Statistiken und Run-Ende: Reiter „Übersicht“/„Statistiken“ (Q/E, LB/RB), Zusammenfassung (Kampfzeit, Welle, Level, Kills, Funken gesammelt/ausgegeben, erlittener Schaden, geheilte HP, Ausweichen, Rerolls), Tabelle je Quelle mit Kills, Schaden, Anteil und DPS seit dem ersten Treffer, sortierbar (Spaltenkopf, R/X), MVP-Abzeichen, Diagramm „Schaden pro Welle“, Run-Historie der letzten 20 Runs, Schadenszahlen verschwinden beim Run-Ende |
| 14c-5 | Charakter-Simulator; Balancing in zwei Runden: neue Charaktere und Waffen, schwache alte Charaktere (Kerze, Taschenlampe, Discokugel, Nachtlicht), Drohnenleuchte |
| 14c-4 | Eigene Grafiken für die Charaktere 13–22, Porträts (alle 22), Lichtfarben, Schweben/Flackern (Irrlicht), pendelnde Kristalle (Kronleuchter), Effekt-Blitz (Stroboskop); Fluch-Symbol, Geister, Frost/Eis, Ranken, Flammen, Spiegelglanz, Feuerball, Frostnova-Ring, Kettenblitz, Licht-Drohne, Lichtranke; Option „Blitzeffekte reduzieren“ |
| 6 (Lexikon) | Hauptmenüpunkt „Lexikon“ mit 6 Reitern (Charaktere, Waffen, Items, Gegner, Waffenklassen, Spielmechaniken), Suche über alle Reiter, Filter, Sprüche (`lore_text`) für alle Einträge |
| 14c-1 | Systeme für 10 neue Charaktere: Fluch, Verlangsamen/Einfrieren/Festhalten, Verbündete (Schattengeister), Seelenglas, Zauberzyklus, Spiegelbild, Drohnen, Lichtranke, Brand-Erweiterungen, Vampirbirnen-Effekte |
| 15-1 | Fix: Absturz am Run-Ende (Sieg und Niederlage). `Unlocks.make_context` wies nach `end_run()` ein ungetyptes `{}` an `Dictionary[String, int]` zu; Challenges, Speichern und `clear_run` fielen aus. Regressionstest `test_boss_victory.gd` (inkl. Arena-Bosssieg mit Spiegelkugel auf Spannung 5) |
| 15-2 | Lexikon: Umschalter „Alles anzeigen“ (F / Y, im Spielstand gespeichert) deckt gesperrte Charaktere und Items vollständig auf; Schloss-Abzeichen auf der Karte, Kasten „Noch gesperrt“ mit Bedingung im Detail. Alle 39 Stats im Reiter Spielmechaniken mit Wirkung, Formel, Beispiel und Grenze; Beispielzahlen werden aus den Formeln und Configs berechnet (`Lexicon.stat_values`). Durchschlag-Schaden % und Boss-Schaden % wirken jetzt (vorher ohne Funktion). Fix: kein Sound-Leak mehr beim Beenden |

Leistung (Radeon RX 590, 1080p, VSync 144 Hz): 100 Gegner aller Typen mit 6 Tier-IV-Fernwaffen min. 118 FPS; 100 Gegner + 300 Projektile konstant 144 FPS.
100 Gegner + 8 Verbündete + Spiegelbild mit 6 Waffen (Welle 14): mit VSync Ø 143, min. 137 FPS; ohne VSync Ø 311, min. 214 FPS.
Paket 4 (neue Partikel und Status-Grafiken, Welle 14, 100 Gegner, VSync): Kronleuchter mit 6 Kristallstäben T4 Ø 138, min. 122 FPS; Spiegelkugel mit 6 Fernwaffen T4 Ø 140, min. 123 FPS.
Phase 15, Paket 6 (Endlos-Welle 49 und Bosswelle 50 per Admin, Arena ständig auf 100 Gegner aufgefüllt, 6 Fernwaffen T4, Standardbirne, zwei Läufe): Welle 49 mit VSync Ø 144–146, min. 117–124 FPS, ohne VSync Ø 451–548, min. 360–414; Welle 50 (beide Bosse + Begleiter) mit VSync Ø 145–148, min. 141–144, ohne VSync Ø 477–547, min. 403–491. Die stärkeren Gegner kosten nichts; das Limit von 100 Gegnern bleibt die Obergrenze.
Phase 15, Paket 4 (HP-Leisten unter Gegnern, Welle 14, 100 Gegner ständig aufgefüllt, 6 Fernwaffen T4, zwei Läufe): Leisten „Immer“ (100 sichtbar) mit VSync Ø 142–143, min. 113–128 FPS, ohne VSync Ø 346–390, min. 235–355; Leisten „Aus“ mit VSync Ø 144, min. 143–144, ohne VSync Ø 315–373, min. 218–266. Die Leisten kosten messbar nichts; die Minima mit VSync fallen in den ersten Messblock direkt nach dem Wellensprung.

## Entscheidungen und Startwerte

Alle Werte liegen als `.tres` unter `data/` und lassen sich ohne Code ändern.

### Kampf und Stats
- Negative Rüstung: jeder Punkt +1/15 mehr Schaden (Gegenstück zu 6,66 % pro positivem Punkt).
- Negatives Angriffstempo wirkt halb so stark wie positives.
- „X-Modifikationen +Y %“ wirken nur auf Zuwächse (Items, Upgrades, Set-Boni), nicht auf Basiswerte. Startboni eines Charakters zählen zur Basis.
- Mehr Max HP heilt um denselben Betrag.
- Waffen ohne eigene Angabe: 3 % Krit-Chance, Krit x2.
- Durchschlag-Schaden %: nach jedem Durchschlag Schaden x (1 + Wert/100), mehrfach bei mehreren Durchschlägen; ohne Stat kein Abzug.
- Boss-Schaden %: Waffentreffer und Explosionen gegen Elites und Bosse x (1 + Wert/100). Noch kein Item gibt diese beiden Stats.
- Brand-Ticks werden durch negatives Brand-Tempo höchstens auf 10 % gebremst (`CombatMath.BURN_SPEED_MIN_FACTOR`).

### Gegner und Wellen
- Rammkäfer: GDD-Tempo 400 als Sprint-Klasse gelesen (verfolgt mit 220–260 px/s, sprintet mit 800 px/s).
- Gruppengrößen und Spawn-Intervalle steigen pro Gegnertyp linear von seiner ersten Welle bis Welle 20.
- Elites: Kontaktschaden 3 (+1 pro Welle), Projektile 2 (+0,8), 20 Funken, legendärer Karton.
- Bosse: 29.000 HP, Kontaktschaden 30, Projektile 23. Welle 20 endet erst mit dem Tod aller Bosse; nach Ablauf des Timers spawnen keine normalen Gruppen mehr.
- Hordewelle: doppelte Gruppengröße.
- Spannung: +8 % Gegner-HP/-Schaden pro Stufe (bis +40 %); alle Stufen sofort wählbar.

### Wirtschaft und Shop
- Verbrauchsgegenstand: 2 % pro Kill, davon anfangs 35 % Kartons.
- Leuchtkristalle: 25 % Spawnchance alle 10 s, höchstens 4; HP 10 + 5 pro Welle ab Welle 2.
- Seltenheit: Tier II +6 %, Tier III +2 %, Tier IV +0,23 % pro Welle; Deckel 60 % / 25 % / 8 %.
- Reroll-Zuschlag: max(1, halbe Wellennummer).
- 35 % der Shop-Angebote sind Waffen.
- Upgrades „analog ergänzt“: Ausweichen und Tempo 3/6/9/12, Aufladung 5/8/10/12.

### Waffen und Items
- Lötkolben: Brand 3 Schaden x3 Ticks (skaliert mit Tier); Brandausbreitung im Radius 140 px.
- Blitzwerfer: Ketten-Reichweite 220 px. Glühwürmchen-Stab: Zielsuche 360°/s.
- Lampenturm: Abklingzeit 1,0 / 0,85 / 0,72 / 0,6 s je Tier des Schraubenziehers, gebaut zu Wellenbeginn.
- Supernova: Explosionsradius 90 px.
- Durchschlag und Abprall von Items laufen über die Stats `piercing` und `bounces` (kein eigener ProjectileModEffect).
- Waffen-Grafiken (48 px) dienen auch als Icons; Items haben eigene 64-px-Icons.

### Charaktere und Meta-Progression
- Startwaffe „beliebig“ = Auswahl aus den 4 Standard-Startwaffen (Funkenpistole, Glasscherbe, Ast, Funkenfaust).
- Freischaltungen sind Challenges (`data/challenges`): 7 Charakter-Bedingungen aus dem GDD und 12x „Sieg mit Charakter X schaltet Item Y frei“.
- Sieg-Items (anfangs gesperrt): Standardbirne → Sonnenkollektor, Glühfaden-Boxer → Ewige Flamme, Neonröhre → Prismenlinse, LED-Schütze → Glasfaser, Lavalampe → Blitzableiter, Taschenlampe → Werkstattkoffer, Discokugel → Discosplitter, Lichterkette → Verlängerungskabel, Halogenstrahler → Supernova, Nachtlicht → Ladestation, Blitzlicht → Schmierfett, Kerze → Recyclingschild. Kernreaktor und Laserzielfernrohr bleiben frei, damit legendäre Kartons immer Tier IV liefern.
- Spielstand `user://save.json` (Version 2), Migration aus `save.cfg` und Version 1; Tests nutzen eigene Dateien (GUT-Pre-Run-Hook).
- Run fortsetzen: Speichern am Shop-Beginn; die Shop-Angebote bleiben beim Laden unverändert.
- Barrierefreiheit (Gegner-HP/-Schaden/-Tempo 25–100 %) wirkt ab dem nächsten Run.

### Juice und Audio
- Hit-Stop 30 ms mit 0,15 s Abklingzeit, damit Krit-Serien nicht ruckeln.
- Im Headless-Modus wird keine Musik gestartet (kein Ton, vermeidet Warnungen beim Beenden).

### Status-Effekte und Charakter-Systeme (Paket 14c-1)
Gemeinsame Werte in `data/config/status_config.tres`, effektspezifische Zahlen in den Effekt-Resources.
- Neue Trigger-Haken im `ItemEffect`: Waffenangriff, Waffentreffer, brennender Tod, Überheilung, Wellenende. Zustand pro Exemplar in `TriggerEntry.state`.
- **Fluch** (`CurseStatus`): +1 Stapel pro Treffer (max. aus dem Effekt), Dauer wird zurückgesetzt, Schaden pro Sekunde x Stapel, erlittener Schaden +x % pro Stapel (wirkt auf jeden Schaden, auch Brand und Fluch-Ticks).
- **Verlangsamen/Einfrieren/Festhalten** (`SlowStatus`): stärkere Verlangsamung gewinnt; Faktor 0 stoppt Bewegung, Verhalten (auch Schießen) und Kontaktschaden. Elites/Bosse halten Status nur 50 % der Dauer. Nach dem Festhalten 1,5 s Schutz.
- Farbton nach Priorität: Frost vor Brand vor Fluch, als Shader-Parameter `tint_color` (Alpha = Stärke; dunkle Konturen bleiben dunkel). Festgehaltene Gegner bekommen keinen Frostton, sondern Ranken.
- **Verbündete** (`Ally`, Ebene „allies“): unverwundbar, Gegner ignorieren sie, nicht in der Gegnergruppe (Waffen zielen nicht darauf, kein Gegnerlimit). Kontaktschaden alle 0,5 s, Mindesttempo 260. Globales Limit 16, Pool 8.
- **Seelenglas** (`SoulCounter` in `GameState.souls`, beim Fortsetzen gespeichert): Seelen werden beim Beschwören nicht verbraucht, max. aus dem Effekt (100).
- **Spiegelbild**: Kopien aller Waffen mit eigenem Schadensfaktor, kein Lebensraub, keine Angriffs-Effekte; folgt mit 90 px Abstand. Wird zu Wellenbeginn mit den aktuellen Waffen gebaut.
- **Drohnen**: Strukturen (`data/structures/drohne.tres`), kreisen mit 95 px Radius und 120 °/s; Level-ups während der Welle fügen sofort Drohnen hinzu.
- **Lichtranke**: Struktur-Art ROOT (`data/structures/lichtranke.tres`): Radius 70, hält 1,5 s fest, höchstens 5, zählt nicht als Lampenturm.
- **Brand**: neuer Stat Brandschaden %; Brandchance pro Treffer als Effekt; `OnKillEffect.only_burning` für Explosionen brennend sterbender Gegner; Brand-Kills werden gezählt.
- Neue Stats: `burn_dmg_pct`, `kill_spark_pct`. Sonderregeln am Spieler: kein HP-Regen, keine Krits. Lebensraub-Limit per Faktor.
- Periodische Effekte (Stroboskop-Blitz, Lichtranke) sind `TimedSpawnEffect` mit `FreezeEnemiesAction` bzw. `BuildStructureAction`.

### Neue Waffen (Paket 14c-2)
- Neue Tier-Felder statt Sondercode: `burn_chance` (Brand zündet pro Treffer nur mit Chance), `extra_souls` (Seelenglas), `root_chance`/`root_duration` (Festhalten über `Enemy.root`, mit Schutzzeit), `split_count`/`split_damage_pct` (Splitter).
- Feuerzeugwerfer: Kegel als zufällige Streuung von 30°, Projektil 700 px/s, Brand 2 x 3 Ticks (skaliert mit Tier wie der Schaden).
- Kristallstab: 3 Splitter im 70°-Fächer, 200 px Flugweite (`combat_config.tres`), treffen das zersplitterte Ziel nicht erneut und splittern nicht weiter.
- Seelenlaterne: Bonus-Seele wirkt nur, wenn ein Seelenglas-Effekt aktiv ist (Irrlicht).

### Charaktere 13–22 und Freischaltungen (Paket 14c-3)
- Werte stehen im GDD Abschnitt 10.
- Abweichung vom ursprünglichen Plan: Schwarzlicht wird über 300 Kills mit der Voodoo-Nadel freigeschaltet (50 gleichzeitig Verfluchte wären ohne Schwarzlicht nicht erreichbar). Vampirbirne: 200 statt 300 geheilte HP.
- Zündkerze: Brandchance-Schaden 3 (+50 % Strom) über 3 Ticks, Explosion beim brennenden Tod 3 (+50 % Strom), Radius 50. Kronleuchter: Feuerball 8 (+100 % Strom, Radius 70), Frostnova 4 (+50 % Strom, Radius 110), Kettenblitz 6 (+80 % Strom, 3 Sprünge, 220 px).
- Fortschritt: `progress.challenge_best` im Spielstand (Bestwert bei Run-Bedingungen), Gesamtwerte als Statistik (`burn_kills`, `crystals`, `kills_<waffe>`). Zuwächse eines Runs zählen nur einmal (`GameState.reported_totals`).
- „Run beenden“ (Drohnenleuchte) zählt die Lampentürme, die beim Run-Ende stehen; der Zähler bleibt nach dem Wellenende (Sieg in Welle 20) stehen, bis die nächste Welle neu baut.

### Grafiken und Effekte (Paket 4)
- Porträts (128 x 128) erzeugt `python tools/make_portraits.py` aus den Spielsprites (Lichthof in der Lichtfarbe der Figur); nach Sprite-Änderungen neu ausführen. Charakterauswahl und Run-Ende zeigen Porträts.
- `CharacterData`: `portrait`, `light_color` (Farbe des Spielerlichts), `idle_style` (Hüpfen oder Schweben mit Flackern), `swing_texture`/`swing_pivot` (Kronleuchter-Kristalle pendeln per `Juice.swing`).
- Status auf Gegnern: Flammen (flackern), Eiskristalle beim Einfrieren (mit Eis-Pop), Eiskristall-Partikel beim Verlangsamen (alle 0,45 s), Ranken beim Festhalten, Fluch-Symbol mit Stapelzahl (1,25-fach). Größen in `status_config.tres`.
- Schattengeister: helle Cyan-Tönung, Kontur 4 px, 78 % Deckkraft, Flackern und aufsteigende Partikelschleppe. Spiegelbild: bläulich, 60 % Deckkraft, wandernder Glanz (`mirror_sheen.gdshader`).
- Feuerball fliegt mit 1100 px/s und explodiert erst beim Ankommen (`ExplosionAction.travel_speed`); Frostnova als Eisring mit Zacken und Splittern; Kettenblitz unregelmäßig gezackt mit Funken an jedem Ziel.
- Stroboskop-Blitz: Bildschirm 32 % weiß für 0,16 s, mit „Blitzeffekte reduzieren“ 30 % davon; die Figur leuchtet kurz auf.

### Balancing der neuen Charaktere (Paket 5)
Grundlage: `--characters`, `--weapons`, `--items` (200 Runs, Vergleichswerte).
- Feuerzeugwerfer 80 % → 40 % Strom (er griff 5-mal pro Sekunde mit voller Skalierung an); Voodoo-Nadel Abklingzeit 0,50 → 0,65 s (Tiers 0,60/0,55/0,51); Seelenlaterne Grundschaden 8 → 11 (17/24/35); Blitzwerfer Abklingzeit 0,60 → 0,70 s (0,64/0,60/0,55).
- Drohnenleuchte 5 statt 4 Waffenslots, Drohnen 6 statt 4 Grundschaden (auch Wartungsdrohne); Vampirbirne +12 % Lebensraub, HP-Verlust 1 pro 4 s; Stroboskop-Blitz alle 10 s; Smartbulb -15 % Schaden.
- Blitzwürfel ohne Nachteil; Geisterkerze 25 % Chance, -1 Rüstung.
- Runde 2: Schwarzlicht -2 Rüstung, Kronleuchter Max-HP-Modifikationen -25 % (Schaden kürzen wirkte laut Simulator kaum, beide hatten große Schadensreserven); Feuerzeugwerfer Abklingzeit 0,20 → 0,25 s (0,23/0,21/0,20).
- Runde 2, alte Charaktere: Kerze +5 HP-Regen, +2 Rüstung (scheiterte vorher meist in Welle 3); Taschenlampe +20 Technik, kein Schadensmalus; Discokugel +125 Glück, -40 % Angriffstempo; Nachtlicht +7 HP-Regen, -15 % Schaden.
- Drohnenleuchte (Ziel ~80 % / 50 % Siegquote auf Spannung 0 / 3): Drohnen schießen alle 0,6 statt 1,0 s (gilt auch für die Wartungsdrohne), Start mit 3 Drohnen, +30 Technik. Getestet und verworfen: nur kürzere Abklingzeit, +50 % Fern-Skalierung (wirkungslos ohne Fern-Waffen), nur 3 Drohnen, 4 Drohnen + 40 Technik (77 % / 50 %).
- Bewusst nicht geändert: Zündkerze-Brandschaden, Fluch-Verstärkung, Kronleuchter-Zauberzyklus, Spawn-Intervalle auf Spannung 0 (Einsteigerstufe darf leicht sein).
- Siegquote im Schnitt aller Charaktere je Spannung 0–5 laut Simulator nach Runde 1: 82 / 74 / 63 / 52 / 43 / 31 %; nach Runde 2 auf Spannung 0 / 3: 85 % / 57 % (alte 12: 83 / 54 %, neue 10: 87 / 60 %).

### Lexikon (Paket 6)
- Einträge baut `Lexicon` (`scripts/systems/lexicon.gd`) aus der DataRegistry; neue `.tres` erscheinen automatisch. Effekttexte nutzen dieselben Funktionen wie der Shop (`ItemData.get_description`, `TextFormat.weapon_special_lines`, `TextFormat.describe_character_stats`).
- Neue Felder (alle Übersetzungsschlüssel): `lore_text` an Charakter, Waffe, Item, Gegner, Set-Bonus, Spannung und Lexikon-Thema; `CharacterData.tip_key`; `EnemyData.behavior_key`/`counter_key`; `BossPhaseData.description_key`.
- Spielmechaniken sind `LexiconTopicData` unter `data/lexicon` (Kategorie „lexicon“ der DataRegistry, ebenso neu: „difficulties“). Jeder Stat gehört zu genau einem Thema und wird mit `STAT_INFO_<STAT>` erklärt; Zahlen in den Texten kommen aus Formeln und Configs.
- „Ab Welle“ wird aus den Wellen berechnet (Funkendieb: `drop_config`, Rußschütze: auch über Brutsack, Elites: Sonderwellen der Spannungen, Bosse: Bosswelle). Beispielwerte gelten für Welle 20, bei Elites für ihre letzte mögliche Welle.
- Gesperrte Charaktere und Items: Silhouette, Name, Bedingung mit Fortschritt; die Suche findet bei ihnen nur Name und Bedingung.
- Komponenten: `EntryCard` (feste Größe, Schrift schrumpft bei langen Namen), `DetailPanel` (Kopf fest, Inhalt scrollt), `StatTable`. Reiter: Maus, Q/E, LB/RB (Aktionen `tab_prev`/`tab_next`); rechter Stick bzw. Bild auf/ab scrollt das Detailpanel.

### Admin-Modus (Phase 15, Paket 3)
- Merker `GameState.admin.used` ab der ersten ausgeführten Aktion (Öffnen allein zählt nicht), gespeichert im Fortsetzen-Stand; in der Shop-Phase wird der Fortsetzen-Stand sofort neu geschrieben.
- Admin-Run: keine Challenges, keine Bestwerte, keine Gesamtstatistik, kein Sieg; der Fortsetzen-Stand wird am Ende trotzdem gelöscht.
- Schaden x10 wirkt in `Enemy.take_damage` auf jeden Schaden an Gegnern. Unendlich HP: Treffer kommen an (Blitz, Trigger), ziehen aber keine HP ab. Wellen über 20 starten als Endloswellen.
- Spielgeschwindigkeit 0,5x/1x/2x/4x; der Hit-Stop kehrt zur gewählten Geschwindigkeit zurück. Hitboxen: Farbe nach Kollisionsebene.
- Level setzen passt den +1-Max-HP-Bonus pro Level an, ohne Upgrade-Karten. Item entfernen und Charakterwechsel bauen den Spieler mit `Player.rebuild()` neu auf.
- Charakterwechsel: Werte neu, Waffen bleiben (auch über dem Slot-Limit), aktuelle HP bleiben (höchstens Max HP). Effekte des alten Charakters enden (Drohnen, Spiegelbild, Geister verschwinden), die des neuen starten sofort. Das Seelenglas (`GameState.souls`) bleibt erhalten. Trigger von Items behalten ihren Zustand (Timer, Zähler); das gilt künftig auch für Kondensator-Zähler und Reservebatterie aus Paket 8.
- F4-Debug-Menü und F6-Arena-Füller gibt es nicht mehr; beides steckt im Admin-Menü.

### HUD und Tooltips (Phase 15, Paket 4)
- HP-Leisten nur unter normalen Gegnern; Elites und Bosse behalten die große Leiste oben (dort zeigt Paket 7 die Phasen). Standard „Nur bei Schaden“, Option unter Optionen → „HP-Leisten der Gegner“ (`enemy_hp_bars`, Index von `EnemyHpBar.Mode`). Größe, Abstand, Farben und Waffen-Kontur in `data/config/hud_config.tres` (Startwerte: Höhe 5 px, Breite 1,6 × Kollisionsdurchmesser, 28–72 px, Kontur 2,5 px mit 90 % Deckkraft).
- Tooltips (`GameTooltip`) hängen am Element, nicht an der Maus: rechts daneben, sonst links, sonst darunter oder darüber, zuletzt an den Rand geklemmt (8 px Abstand). Inhalte in `TooltipText`. Stat-Zeilen zeigen den Tooltip nur bei Maus-Hover, damit der Gamepad-Fokus nicht durch 30 Zeilen wandert. Im Shop zeigen die Kombinieren-/Recyceln-Buttons beim Fokus den Tooltip ihrer Waffe.
- Waffen-Tooltip: aktueller Schaden ohne Krit als „Summe = Grundschaden + x % von Stat“, dazu Schaden-% und Schadensfaktor (Spiegelbild); Abklingzeit, Reichweite und Krit mit allen Stats des Spielers. Set-Boni je Klasse mit Stufen 2–6, Set-Multiplikator des Charakters eingerechnet.
- Kills und Schaden je Herkunft: gezählt wird der Schaden, den ein Gegner tatsächlich verliert (ohne Overkill). Brand und Fluch zählen für die Waffe oder das Item, das sie ausgelöst hat; Explosionen von Projektilen und Splitter für ihre Waffe; Item-Aktionen für ihr Item; Charakter-Effekte als `character/<id>`; Strukturen und Drohnen als `structure/<id>`. Zwei gleiche Waffen teilen sich die Werte (Tooltip „alle 2 zusammen“).
- Obergrenzen im Stat-Panel (`CombatMath.stat_cap`): Ausweichen (`dodge_cap`), Krit-Chance, Lebensraub und Doppelte Funken je 100. Die Erklärung im Tooltip kommt aus denselben Texten wie im Lexikon (`Lexicon.stat_text`).
- Im Shop stehen die aktiven Set-Boni in der Kopfzeile „Waffen (x/y)“, damit auch 22 Items in zwei Reihen und die Wellen-Vorschau in 1280×720 sichtbar bleiben.

### Run-Statistik und Run-Ende (Phase 15, Paket 5)
- Quelle der Tabelle sind nur `RunStats.source_kills`/`source_damage` (Paket 4). Neu erfasst werden nur Werte, die es vorher nicht gab: Kampfzeit je Welle (`wave_times`), erlittener Schaden (nach Rüstung, auch bei „Unendlich HP“), ausgewichene Treffer, ausgegebene Funken (jede erfolgreiche `GameState.spend`) und Rerolls (Shop und Level-up, auch gratis). Geheilte HP gab es schon (`healed`).
- Kampfzeit: Der WaveManager zählt nur in der laufenden Welle, solange der Spieler lebt (Shop, Kartons, Pause und Zwischenzeit zählen nicht; Admin-„Zeit anhalten“ hält nur den Wellen-Timer an, nicht die Kampfzeit). Ein Tod mitten in der Welle schließt sie mit der bisherigen Zeit ab.
- Schaden pro Welle (`wave_damage`) ist keine eigene Zählung: Am Wellenende wird der Zuwachs der Summe von `source_damage` gespeichert.
- DPS je Quelle = Schaden / (Kampfzeit jetzt − Kampfzeit beim ersten Treffer dieser Quelle), mindestens 1 s (`min_dps_time`). `first_hit_time` steht im Fortsetzen-Stand. Spät gekaufte Waffen werden so nicht kleingerechnet.
- MVP ist die Quelle mit dem meisten Schaden (bei Gleichstand mehr Kills). Sortierung: Klick auf den Spaltenkopf (nochmal = Richtung umkehren), Taste R bzw. X am Gamepad (Aktion `stats_sort`) schaltet Schaden → DPS → Kills → Anteil → Name → Art durch. Zahlen mit Tausender- und Dezimalzeichen der Sprache (DE „1.234“ und „12,3 %“).
- Run-Historie (`run_history` im Spielstand): höchstens 20 Einträge (`history_size`), Top-3-Quellen (`history_top_sources`), geschrieben in `Unlocks.evaluate_run_end`. Admin-Runs fehlen. Ein Endlos-Run nach dem Sieg ersetzt seinen Eintrag (gleiche `GameState.run_id`, steht im Fortsetzen-Stand); ein Tod im Endlos-Modus bleibt Ergebnis „victory“ mit `endless_wave`.
- Startwerte in `data/config/run_stats_config.tres`: Historie 20, Top-Quellen 3, DPS-Mindestzeit 1 s.
- Schadenszahlen: Arena gibt den Pool beim Sieg und nach der Todesverzögerung frei, bevor der Bildschirm erscheint.

### Endlos-Modus (Phase 13, überarbeitet in Phase 15, Paket 6)
- Alle Werte in `data/config/endless_config.tres` (`EndlessConfig`), gerechnet in `EndlessRules` (Spiel, Shop, Lexikon und Simulator nutzen dieselben Formeln). „Endlos-Stufe“ = Wellen seit dem Sieg (Welle 21 = 1).
- Nach dem Sieg in Welle 20: „Endlos weiterspielen“. Endloswellen dauern 60 s und nutzen die Gegnergruppen von Welle 19.
- Pro Endloswelle (Zinseszins): Gegner-HP +15 %, Schaden +10 %, Tempo +3 % (höchstens +60 %), Gruppen erscheinen um 2 % häufiger (höchstens +100 %, Intervall geteilt durch den Faktor). Das Limit von 100 Gegnern bleibt; die Schwierigkeit kommt aus stärkeren, nicht aus mehr Gegnern.
- Aufladung: Stufe 1 zahlt 50 % aus, danach je Welle 4 Prozentpunkte weniger, mindestens 10 %.
- Bosswellen: Stufe 10, 20, 30 … (Welle 30, 40, 50 …) nach Vorlage von Welle 20 (Begleitgruppen in den ersten 90 s). Beide Bosse mit vollen HP (keine 75 % wie bei Spannung 5), Endlos-Faktor plus linearer Zyklus-Bonus: Zyklus n = +40 % · n HP und +15 % · n Schaden (`Enemy.damage_multiplier`). Die Welle endet erst mit dem Tod aller Bosse, danach Kartons, Level-ups und Shop wie gewohnt; kein Sieg-Bildschirm.
- Jeder Endlos-Boss lässt 1 legendären Karton fallen (`boss_legendary_crates`).
- Nach dem Bosssieg: goldenes Banner „Bosse besiegt! Zyklus n geschafft“ (2 s, kleiner Sprung) mit Level-up-Klang, Partikeln, goldenem Ring und leichtem Bildschirmwackeln. `RunStats.boss_cycles` zählt mit (Run-Statistik nur im Endlos-Modus, Run-Historie `boss_cycles`, Fortsetzen-Stand).
- Sonderwellen auf jeder Spannung: Stufe 5, 15, 25 … (Welle 25, 35 …) ist Elite- oder Hordewelle, 40 % Horde. Ausgewürfelt mit dem Run-RNG jeweils für den nächsten 10er-Block (beim Weiterspielen und bei jedem Wellenstart), gespeichert in `GameState.special_waves`.
- HUD: „Endlos 7 (Welle 27)“. Shop: Vorschau mit Endlos-Boss- und Sonderwellen, vor jeder Bosswelle „Nächste Welle: Bosse“ (Welle 20: „Nächste Welle: Boss“).
- Bestwert „Höchste Endlos-Welle“ je Charakter (`progress.endless_best`, kein Versionssprung): zählt beim Erreichen einer Endloswelle (wie „Endlos-Welle n erreicht“ am Run-Ende), nicht in Admin-Runs. Angezeigt im Infopanel der Charakterauswahl und im Lexikon-Eintrag des Charakters.
- Ein Run wird in der Gesamtstatistik nur einmal gezählt; Funken und Kills nur als Zuwachs.

## Werkzeuge

| Befehl | Zweck |
|---|---|
| `godot --headless --path . res://tools/balance_sim.tscn -- <Spannung>` | Balancing-Tabelle: Gegner-HP pro Welle gegen DPS von drei Builds (Fern, Nah, Strom) |
| `… -- <Spannung> --apply` | Vorgeschlagene Intervall-Faktoren in die Wellen-`.tres` schreiben |
| `… -- <Spannung> --characters [--runs 200] [--ablate]` | Run-Simulation je Charakter: Siegquote, Ø Welle, Scheiter-Welle, Schadensanteile, stärkster Effekt (Ablation) |
| `… -- 0 --weapons` / `… -- 3 --items` | DPS aller Waffen gegen die eigene Klasse / Wirkung der Tier-III/IV-Items auf Siegquote |
| `… -- <Spannung> --trace <charakter-id>` | Einen Run Welle für Welle ausgeben (Kalibrierung) |
| `python tools/make_portraits.py` | Charakter-Porträts aus den Spielsprites erzeugen |
| `godot --headless --path . --export-release "Windows Desktop" build/windows/Bulbro.exe` | Windows-Build (benötigt installierte Export-Vorlagen) |

Annahmen des Simulators (Waffenzahl, Tier und Stat-Zuwachs pro Welle) stehen als Konstanten in `scripts/systems/balance_model.gd`. Die Charakter-Simulation (`scripts/systems/character_sim.gd`) nutzt echte Spieler-Objekte und liest Sondereffekte aus den Daten; ihre Vereinfachungen und Kalibrierung (Schnitt der 12 alten Charaktere ≈ 80 % Siegquote auf Spannung 0) stehen dort im Kopf. Die Siegquoten sind Vergleichswerte, keine echten Quoten.

## Offene Punkte

- Gegner überlappen sich (keine gegenseitige Abstoßung, bewusst für die Performance).
- Upgrade-Karten haben keine Icons.
- Musik ist ein synthetisierter Platzhalter; CC0-Tracks nach `audio/music` legen und in `data/config/audio_config.tres` eintragen.
- Balancing: Spannung 0 ist laut Wellenmodell in 14 von 19 Wellen leicht (gewollt). Zündkerze, Schwarzlicht und Kronleuchter liegen laut Charakter-Simulator weiter über dem Schnitt; Kerze, Taschenlampe, Discokugel und Nachtlicht darunter (Vorschläge offen). Strom-Waffen (Blitzwerfer, Feuerzeugwerfer) bleiben die stärkste Klasse.
- Windows-Build läuft (Export-Vorlagen 4.7.2 installiert); Ergebnis `build/windows/Bulbro.exe` (nicht im Git).

# BULBRO – Entwicklungsstand

Ergänzt [GDD.md](GDD.md) und [ART_STYLE.md](ART_STYLE.md). Hier stehen der Stand je Phase, Entscheidungen, die das GDD offenlässt (Startwerte), und offene Punkte. Bei Änderungen an Werten oder Regeln bitte mitpflegen.

## Bedienung zum Testen

| Taste | Funktion |
|---|---|
| F5 (Godot) | Spiel starten (Hauptmenü → Charakter → Startwaffe → Spannung → Run) |
| WASD / Pfeile / Stick | Bewegen |
| Esc / Start | Pause (Weiter, Optionen, Aufgeben) |
| F3 | Debug-Overlay mit allen Stats, FPS und Gegnerzahl |
| F4 | Debug-Menü: Item/Waffe in beliebigem Tier geben, Welle springen, unverwundbar, Funken, Level-up, alle Charaktere freischalten |
| F6 | Arena bis zum Gegnerlimit (100) füllen, Performance-Test |

Bosse testen: F4 → zu Welle 20 springen; bei Spannung 5 erscheinen beide Bosse.

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
| 14c-5 | Charakter-Simulator; Balancing in zwei Runden: neue Charaktere und Waffen, schwache alte Charaktere (Kerze, Taschenlampe, Discokugel, Nachtlicht), Drohnenleuchte |
| 14c-4 | Eigene Grafiken für die Charaktere 13–22, Porträts (alle 22), Lichtfarben, Schweben/Flackern (Irrlicht), pendelnde Kristalle (Kronleuchter), Effekt-Blitz (Stroboskop); Fluch-Symbol, Geister, Frost/Eis, Ranken, Flammen, Spiegelglanz, Feuerball, Frostnova-Ring, Kettenblitz, Licht-Drohne, Lichtranke; Option „Blitzeffekte reduzieren“ |
| 6 (Lexikon) | Hauptmenüpunkt „Lexikon“ mit 6 Reitern (Charaktere, Waffen, Items, Gegner, Waffenklassen, Spielmechaniken), Suche über alle Reiter, Filter, Sprüche (`lore_text`) für alle Einträge |
| 14c-1 | Systeme für 10 neue Charaktere: Fluch, Verlangsamen/Einfrieren/Festhalten, Verbündete (Schattengeister), Seelenglas, Zauberzyklus, Spiegelbild, Drohnen, Lichtranke, Brand-Erweiterungen, Vampirbirnen-Effekte |
| 15-1 | Fix: Absturz am Run-Ende (Sieg und Niederlage). `Unlocks.make_context` wies nach `end_run()` ein ungetyptes `{}` an `Dictionary[String, int]` zu; Challenges, Speichern und `clear_run` fielen aus. Regressionstest `test_boss_victory.gd` (inkl. Arena-Bosssieg mit Spiegelkugel auf Spannung 5) |
| 15-2 | Lexikon: Umschalter „Alles anzeigen“ (F / Y, im Spielstand gespeichert) deckt gesperrte Charaktere und Items vollständig auf; Schloss-Abzeichen auf der Karte, Kasten „Noch gesperrt“ mit Bedingung im Detail. Alle 39 Stats im Reiter Spielmechaniken mit Wirkung, Formel, Beispiel und Grenze; Beispielzahlen werden aus den Formeln und Configs berechnet (`Lexicon.stat_values`). Durchschlag-Schaden % und Boss-Schaden % wirken jetzt (vorher ohne Funktion). Fix: kein Sound-Leak mehr beim Beenden |

Leistung (Radeon RX 590, 1080p, VSync 144 Hz): 100 Gegner aller Typen mit 6 Tier-IV-Fernwaffen min. 118 FPS; 100 Gegner + 300 Projektile konstant 144 FPS.
100 Gegner + 8 Verbündete + Spiegelbild mit 6 Waffen (Welle 14): mit VSync Ø 143, min. 137 FPS; ohne VSync Ø 311, min. 214 FPS.
Paket 4 (neue Partikel und Status-Grafiken, Welle 14, 100 Gegner, VSync): Kronleuchter mit 6 Kristallstäben T4 Ø 138, min. 122 FPS; Spiegelkugel mit 6 Fernwaffen T4 Ø 140, min. 123 FPS.

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

### Endlos-Modus
- Nach dem Sieg in Welle 20: „Endlos weiterspielen“. Endloswellen dauern 60 s und nutzen die Gegnergruppen von Welle 19.
- Pro Endloswelle (Zinseszins): Gegner-HP +15 %, Schaden +10 %, Tempo +3 % (höchstens +60 %). Aufladung zahlt nur 50 % aus.
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

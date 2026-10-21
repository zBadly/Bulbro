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
| 14c-4 | Eigene Grafiken für die Charaktere 13–22, Porträts (alle 22), Lichtfarben, Schweben/Flackern (Irrlicht), pendelnde Kristalle (Kronleuchter), Effekt-Blitz (Stroboskop); Fluch-Symbol, Geister, Frost/Eis, Ranken, Flammen, Spiegelglanz, Feuerball, Frostnova-Ring, Kettenblitz, Licht-Drohne, Lichtranke; Option „Blitzeffekte reduzieren“ |
| 14c-1 | Systeme für 10 neue Charaktere: Fluch, Verlangsamen/Einfrieren/Festhalten, Verbündete (Schattengeister), Seelenglas, Zauberzyklus, Spiegelbild, Drohnen, Lichtranke, Brand-Erweiterungen, Vampirbirnen-Effekte |

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
- Balancing: Simulator-Vorschläge noch nicht übernommen (Spannung 0 laut Modell in 14 von 19 Wellen zu leicht; Strom-Build rund 1,5x stärker als Fern/Nah, vor allem durch den Ketten-Blitz).
- Windows-Build läuft (Export-Vorlagen 4.7.2 installiert); Ergebnis `build/windows/Bulbro.exe` (nicht im Git).

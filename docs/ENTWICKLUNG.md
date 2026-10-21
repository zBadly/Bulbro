# BULBRO – Entwicklungsstand

Ergänzt [GDD.md](GDD.md) und [ART_STYLE.md](ART_STYLE.md). Hier stehen der Stand je Phase, Entscheidungen, die das GDD offenlässt (Startwerte), und offene Punkte. Bei Änderungen an Werten oder Regeln bitte mitpflegen.

## Bedienung zum Testen

| Taste | Funktion |
|---|---|
| F5 (Godot) | Spiel starten (Hauptmenü → Charakter → Startwaffe → Spannung → Run) |
| WASD / Pfeile / Stick | Bewegen |
| Esc / Start | Pause (Weiter, Optionen, Aufgeben) |
| F3 | Debug-Overlay mit allen Stats, FPS und Gegnerzahl |
| F4 | Debug-Menü: Item/Waffe in beliebigem Tier geben, Welle springen, unverwundbar, Funken, Level-up |
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

Leistung (Radeon RX 590, 1080p, VSync 144 Hz): 100 Gegner aller Typen mit 6 Tier-IV-Fernwaffen min. 118 FPS; 100 Gegner + 300 Projektile konstant 144 FPS.

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

### Endlos-Modus
- Nach dem Sieg in Welle 20: „Endlos weiterspielen“. Endloswellen dauern 60 s und nutzen die Gegnergruppen von Welle 19.
- Pro Endloswelle (Zinseszins): Gegner-HP +15 %, Schaden +10 %, Tempo +3 % (höchstens +60 %). Aufladung zahlt nur 50 % aus.
- Ein Run wird in der Gesamtstatistik nur einmal gezählt; Funken und Kills nur als Zuwachs.

## Werkzeuge

| Befehl | Zweck |
|---|---|
| `godot --headless --path . res://tools/balance_sim.tscn -- <Spannung>` | Balancing-Tabelle: Gegner-HP pro Welle gegen DPS von drei Builds (Fern, Nah, Strom) |
| `… -- <Spannung> --apply` | Vorgeschlagene Intervall-Faktoren in die Wellen-`.tres` schreiben |
| `godot --headless --path . --export-release "Windows Desktop" build/windows/Bulbro.exe` | Windows-Build (benötigt installierte Export-Vorlagen) |

Annahmen des Simulators (Waffenzahl, Tier und Stat-Zuwachs pro Welle) stehen als Konstanten in `scripts/systems/balance_model.gd`.

## Offene Punkte

- Gegner überlappen sich (keine gegenseitige Abstoßung, bewusst für die Performance).
- Upgrade-Karten haben keine Icons.
- Musik ist ein synthetisierter Platzhalter; CC0-Tracks nach `audio/music` legen und in `data/config/audio_config.tres` eintragen.
- Balancing: Simulator-Vorschläge noch nicht übernommen (Spannung 0 laut Modell in 14 von 19 Wellen zu leicht; Strom-Build rund 1,5x stärker als Fern/Nah, vor allem durch den Ketten-Blitz).
- Windows-Build läuft (Export-Vorlagen 4.7.2 installiert); Ergebnis `build/windows/Bulbro.exe` (nicht im Git).

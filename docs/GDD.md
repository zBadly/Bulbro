# BULBRO – Game Design Document v1

## 0. Rolle und Arbeitsregeln
- Du bist Senior-Entwickler für Godot 4.x (GDScript mit statischen Typen) und Game Designer.
- BULBRO übernimmt die Spielmechaniken von Brotato (Arena-Roguelite, Autofire, Wellen, Shop). Alle Namen, Grafiken, Texte und Sounds sind eigene Kreationen. Keine Assets oder Texte aus Brotato.
- Datengetrieben: Alle Spielwerte liegen als Resources (.tres) unter res://data. Keine Magic Numbers im Code.
- Arbeite in kleinen Schritten: erst Plan, dann Umsetzung, dann Prüfung.
- Nach jeder Phase: Projekt headless starten und Fehler beheben, GUT-Tests ausführen, git commit mit aussagekräftiger Nachricht.
- Sprache im Spiel: Deutsch (alle Texte über eine Übersetzungstabelle, damit Englisch später möglich ist).

## 1. Spielüberblick
- 2D-Top-Down-Arena. Die Spielfigur greift automatisch an; Spieler steuert nur die Bewegung (manuelles Zielen per Maus optional).
- Ein Run = 20 Wellen, unter 30 Minuten. Welle 20 ist ein Bosskampf; Boss besiegt = Run gewonnen. Optionaler Endlos-Modus danach.
- Core Loop: Welle kämpfen und Funken sammeln -> Wellenende (restliche Funken werden eingesackt, Kartons geöffnet, Level-ups gewählt) -> Shop -> nächste Welle.
- Held: Bulbro, eine Glühbirne mit bis zu 6 schwebenden Waffen. Gegner: Schattenwesen und Motten.

## 2. Wellen
- Dauer: Welle 1 = 20 s, jede Welle +5 s bis 60 s (ab Welle 9). Welle 20 = 90 s, endet beim Tod des Bosses.
- Max. 100 Gegner gleichzeitig. Wird das überschritten, verschwindet ein zufälliger normaler Gegner ohne Drop.
- Spawns in Gruppen. Vor jedem Spawn 1 s ein pulsierendes rotes X am Boden. Nie näher als 200 px am Spieler (Startwert).
- Gegner-HP und -Schaden = Basiswert + Zuwachs pro Welle nach Welle 1 (linear). Tempo skaliert nicht.
- Spannung (Schwierigkeit) 0-5: Spannung 2-3 = eine Elite-/Horde-Welle (Welle 11 oder 12); Spannung 4-5 = drei (11/12, 14/15, 17/18; die letzte ist immer Elite). Zufall: 40 % Horde, 60 % Elite. Höhere Spannung = mehr Gegnertypen und bis +40 % HP/Schaden.
- Wellendefinitionen (welche Gegner, Gruppengröße, Intervall) als WaveData-Resources.
- Endlos-Modus nach dem Sieg: 60-s-Wellen, Gegner-HP, -Schaden, -Tempo und Spawn-Dichte wachsen pro Welle (Zinseszins), die Aufladung wird schwächer. Alle 10 Wellen (30, 40, …) erscheinen alle Bosse gleichzeitig, mit jedem Zyklus stärker; die Welle endet mit ihrem Tod. In Welle 25, 35, … wartet eine Elite- oder Hordewelle. Das Gegnerlimit bleibt bei 100. Werte in `EndlessConfig`.

## 3. Arena und Kamera
- Rechteckige Arena ca. 2000 x 1300 px (Startwert), sichtbarer Rand, Spieler kann nicht hinaus.
- Basisauflösung 1920 x 1080, stretch mode canvas_items, aspect expand. Kamera folgt mit leichtem Smoothing.

## 4. Spieler und Stats
Basiswerte: Max HP 10, Tempo 450 px/s, 6 Waffenslots, Aufsammelradius 150 px (Startwert), Unverwundbarkeit nach Treffer 0,4 s (Startwert).
Jedes Level-up gibt +1 Max HP (Startwert).

Primär-Stats (Name im Code -> Wirkung):
- max_hp: Leben. Negativ wirkt wie 1.
- hp_regen: 1. Punkt = 0,20 HP/s, jeder weitere +0,089 HP/s. Negativ wirkt wie 0.
- lifesteal: x % Chance pro Treffer auf +1 HP; höchstens einmal pro 0,1 s (max. 10 HP/s).
- damage_pct: +1 % auf allen Schaden pro Punkt (nicht auf Strukturen). Mindestschaden immer 1.
- melee_dmg, ranged_dmg, elemental_dmg (UI: Nah, Fern, Strom): flache Werte, die über die Skalierung der Waffe einfließen.
- attack_speed: Abklingzeit / (1 + AS/100). Negative Werte wirken schwächer. Max. 12 Angriffe/s.
- crit_chance: addiert sich zur Krit-Chance der Waffe, 0-100 %.
- engineering (UI: Technik): Stärke von Türmen/Strukturen.
- range: addiert zur Waffenreichweite; bei Nahkampf nur die Hälfte; minimal 25.
- armor: Schadensreduktion = armor / (armor + 15). Jeder Punkt = ca. 6,66 % mehr effektives Leben. Negativ erhöht den Schaden.
- dodge: Ausweichchance, Obergrenze 60 % (Charaktere können sie anheben).
- speed: +x % Bewegungstempo; bei -100 % Stillstand.
- luck: mehr Drops (Batterien, Kartons) und bessere Seltenheit in Shop und Level-ups.
- harvesting (UI: Aufladung): am Wellenende +x Funken und XP; wächst danach um 5 % (aufgerundet), nur wenn positiv.

Sekundär-Stats: xp_gain_pct, pickup_range_pct, item_price_pct, explosion_dmg_pct, explosion_size_pct, bounces, piercing, piercing_dmg_pct, boss_dmg_pct, structure_attack_speed_pct, burn_speed_pct, burn_spread, knockback, double_spark_chance, free_rerolls, crystals (mehr Leuchtkristalle), enemies_pct, enemy_speed_pct, reroll_price_pct, consumable_heal.

Stat-Modifikatoren von Charakteren: "X-Modifikationen +Y %" multipliziert jeden späteren Zuwachs dieses Stats.
Trefferablauf: Ausweichwurf -> Rüstungsreduktion -> HP abziehen -> Unverwundbarkeit.

## 5. XP und Level-ups
- 1 Funke = 1 Währung + 1 XP. XP bis zum nächsten Level: (Level + 3)^2 (Startwert).
- Level-ups werden am Wellenende abgearbeitet: je Level 4 Upgrade-Karten zur Wahl, rerollbar gegen Funken.
- Upgrade-Werte je Tier I/II/III/IV: Max HP 3/6/9/12; HP-Regen 2/3/4/5; Lebensraub 1/2/3/4; Schaden % 5/8/12/16; Nah 2/4/6/8; Fern 1/2/3/4; Strom 1/2/3/4; Angriffstempo % 5/10/15/20; Krit % 3/5/7/9; Technik 2/3/4/5; Reichweite 15/30/45/60; Rüstung 1/2/3/4; Glück 5/10/15/20. (Ausweichen, Tempo, Aufladung analog ergänzen.)
- Garantierte Seltenheit: Level 5 = Tier II, Level 10/15/20 = Tier III, ab Level 25 jedes 5. Level = Tier IV. Sonst wie Shop-Seltenheit, aber nach Level statt Welle.

## 6. Drops und neutrale Objekte
- Funken: jeder Gegner droppt Funken. Nicht aufgesammelte Funken werden am Wellenende in den Beutel gelegt; in der nächsten Welle gibt jeder neue Funke +1 aus dem Beutel dazu, bis er leer ist.
- Batterien (Heilung): Chance pro Gegner-Kill, heilen 3 HP. 100 Glück = doppelte Dropchance, -100 Glück = keine.
- Ersatzteil-Karton: ein gedroppter Verbrauchsgegenstand kann ein Karton sein. Chance = Basischance x (100 + Glück) % / (1 + Kartons in dieser Welle). Enthält ein Item (Seltenheit nach Welle und Glück). Am Wellenende: behalten oder für 25 % des Preises recyceln. Heilt 3 HP.
- Legendärer Karton (Elites/Boss): garantiert Tier IV.
- Leuchtkristall (neutral, wie Bäume): ab Sekunde 10 alle 10 s Spawnchance; HP 10 + 5 pro Welle; stirbt spätestens nach 8 Treffern; droppt 3 Funken und immer eine Batterie (20 % davon Karton).
- Funkendieb: ab Welle 3, 10 % Chance bei Sekunde 25 und danach alle 15 s; flieht; droppt Karton + 8 Funken.

## 7. Shop
- 4 Angebote, gemischt aus Waffen und Items. Item-Seltenheit: Tier I grau, II blau, III lila, IV rot.
- Tier II ab Shop 2, Tier III ab Shop 4, Tier IV ab Shop 8. Seltenheit steigt mit Welle und Glück; Obergrenzen etwa 60 % Tier II und 25 % Tier III.
- Reroll: erster Preis = Wellennummer + Reroll-Zuschlag; jeder Reroll erhöht um den Zuschlag; jeder neue Shop setzt zurück. Gesperrte Angebote bleiben (inkl. Preis) bis zum Entsperren oder Kauf.
- Alle 4 Angebote gekauft -> aktueller Reroll gratis.
- Inflation: Preis = Grundpreis + pro Welle (10 % des Grundpreises + 1).
- Waffen kombinieren: 2 gleiche Waffen gleichen Tiers -> 1 Waffe des nächsten Tiers (max. IV). Kauf einer vorhandenen Waffe bei vollen Slots kombiniert automatisch.
- Recyceln von Waffen gibt einen Teil des Preises zurück (Startwert 25 %).
- 15 % der Waffenangebote passen zu einer Klasse, die der Spieler bereits besitzt. Charaktere bevorzugen über Tags passende Items.
- Manche Items haben ein Limit (max. Anzahl). Shop zeigt alle Stats, das Inventar und eine Vorschau auf Elite-/Boss-Wellen.

## 8. Waffen
- Waffen schweben im Kreis um Bulbro (Radius ca. 55 px), zielen jeweils auf den nächsten Gegner in Reichweite und haben eigene Abklingzeiten.
- Nahkampf: Stoß (gerade) oder Schwung (Bogen), trifft mehrere Gegner; höhere Reichweite verlangsamt leicht.
- Fernkampf: Projektile mit Durchschlag, Abprall, Rückstoß. Projektile, Gegner und Pickups werden gepoolt.
- Schaden = (Basis + Summe(Skalierung x Stat)) x (1 + damage_pct/100) x Krit-Multiplikator; Minimum 1.
- Tier-Faustregel (Startwerte): T2 = x1,5 Schaden, x0,92 Abklingzeit; T3 = x2,2 / x0,85; T4 = x3,2 / x0,78. Preis T2 x2, T3 x3,6, T4 x6,5.

Waffenklassen und Set-Boni (bei 2/3/4/5/6 Waffen der Klasse):
- Klinge: +1..+5 Nah und +1..+5 % Lebensraub
- Stumpf: Rüstung +1/+1/+2/+2/+3, Max HP +0/+3/+3/+6/+6, Tempo -2/-4/-6/-8/-10 %
- Präzise: +3..+15 % Krit
- Schwer: +5..+25 % Schaden
- Primitiv: +3..+15 Max HP
- Unbewaffnet: +3..+15 % Ausweichen
- Elementar: +1..+5 Strom
- Werkzeug: +1..+5 Technik
- Explosiv: +5..+25 % Explosionsgröße
- Schusswaffe: +10..+50 Reichweite
- Medizinisch: +1..+5 HP-Regen
- Ätherisch: +6..+30 % Ausweichen, -1..-5 Rüstung
- Support: +3..+15 Aufladung

Waffenliste (Tier-I-Werte, alle Startwerte):
| Waffe | Art | Klassen | Schaden (Skalierung) | Abklingzeit | Reichweite | Besonderes | Preis |
|---|---|---|---|---|---|---|---|
| Funkenfaust | Nah, Stoß | Unbewaffnet | 8 (100 % Nah) | 0,78 s | 150 | Rückstoß 15 | 15 |
| Glasscherbe | Nah, Stoß | Klinge, Präzise | 6 (80 % Nah) | 0,80 s | 150 | Krit x2,5, Basis-Krit 20 % | 20 |
| Ast | Nah, Stoß | Primitiv | 10 (100 % Nah) | 1,20 s | 175 | +1 Schaden pro weiterem Ast | 15 |
| Kabelpeitsche | Nah, Schwung | Präzise | 10 (100 % Nah) | 1,10 s | 200 | trifft im Bogen | 25 |
| Lampenhammer | Nah, Schwung | Stumpf, Schwer | 30 (200 % Nah) | 2,20 s | 175 | Rückstoß 30 | 40 |
| Schraubenzieher | Nah, Schwung | Werkzeug | 12 (100 % Nah) | 1,70 s | 175 | baut einen Lampenturm | 25 |
| Lötkolben | Nah, Stoß | Elementar, Werkzeug | 10 (100 % Strom) | 1,20 s | 160 | Überspannung (Brand) | 30 |
| Funkensieb | Nah, Stoß | Support | 6 (50 % Nah) | 1,00 s | 150 | 15 % Chance +1 Funke bei Kill | 20 |
| Funkenpistole | Fern | Schusswaffe | 12 (100 % Fern) | 1,20 s | 400 | Durchschlag 1 | 25 |
| Laserpointer | Fern | Schusswaffe, Präzise | 4 (50 % Fern) | 0,35 s | 450 | leichte Streuung | 30 |
| Batterie-Schleuder | Fern | Primitiv | 10 (100 % Fern) | 1,10 s | 350 | prallt 1x ab | 15 |
| Blitzwerfer | Fern | Elementar | 6 (100 % Strom) | 0,70 s | 300 | springt auf 2 weitere Ziele | 30 |
| Leuchtrakete | Fern | Explosiv, Schusswaffe | 20 (100 % Fern) | 1,60 s | 450 | Explosion 75 px | 40 |
| Prisma | Fern | Schusswaffe | 6 x3 (80 % Fern) | 1,00 s | 350 | 3 Strahlen im Fächer | 35 |
| Taschenlampenstrahl | Fern | Elementar, Präzise | 8 (100 % Strom) | 1,00 s | 500 | unbegrenzter Durchschlag | 45 |
| Heilstrahl | Fern | Medizinisch | 8 (80 % Fern) | 1,00 s | 400 | 10 % Chance +1 HP pro Treffer | 30 |
| Glühwürmchen-Stab | Fern | Ätherisch | 12 (100 % Strom) | 1,20 s | 350 | zielsuchend | 30 |
| Seelenlaterne | Fern | Elementar, Ätherisch | 11 (100 % Strom) | 1,10 s | 350 | zielsuchende Seelenkugel; Kills geben +1 Seele (Seelenglas) | 30 |
| Feuerzeugwerfer | Fern | Elementar | 2 (40 % Strom) | 0,25 s | 200 | Flammenkegel, unbegrenzter Durchschlag, 20 % Brandchance pro Treffer | 35 |
| Kristallstab | Fern | Elementar, Präzise | 10 (100 % Strom) | 1,00 s | 400 | zersplittert beim Treffer in 3 Splitter (je 30 % Schaden) | 30 |
| Voodoo-Nadel | Fern | Ätherisch | 5 (70 % Strom) | 0,65 s | 380 | Durchschlag 2 | 25 |
| Dornenranke | Nah, Schwung | Primitiv, Medizinisch | 12 (100 % Nah + 50 % Strom) | 1,30 s | 200 | 25 % Chance, Gegner 0,5 s festzuhalten | 25 |

Lampenturm (Struktur): schießt alle 1,0 s für 5 (100 % Technik), Reichweite 400; Tier erhöht Feuerrate.

## 9. Items (Startwerte)
Fast jedes Item hat einen Vorteil und einen Nachteil. Format: Name | Tier | Effekt | Preis | Limit.
- Ersatzsicherung | I | +3 Max HP | 15
- Kupferdraht | I | +2 Strom, -1 Rüstung | 18
- Staubtuch | I | +3 % Ausweichen, -1 Max HP | 15
- Kleiner Akku | I | +2 HP-Regen | 18
- Glühwürmchenglas | I | +10 Glück, -2 % Schaden | 20
- Lupe | I | +20 Reichweite, -2 % Angriffstempo | 18
- Gummihandschuh | I | +1 Rüstung, -2 % Tempo | 15
- Stromtarif-Gutschein | I | -5 % Preise | 15 | Limit 5
- Schmierfett | I | +4 % Tempo, -6 Glück | 15
- Isolierband | I | +2 Nah, -1 Fern | 15
- Energieriegel | I | +1 Heilung durch Batterien | 15
- Sparschwein | I | +5 Aufladung | 20
- Schaltplan | II | +25 % XP, +2 Technik, -5 Glück | 35
- Schutzbrille | II | +5 % Krit, -1 Rüstung | 35
- Dynamo | II | +6 % Angriffstempo, +1 HP-Regen, -3 % Tempo | 40
- Tesla-Spule | II | 25 % Chance bei Gegnertod: 3 (+50 % Strom) Schaden an zufälligem Gegner | 40
- Würfellampe | II | +1 Gratis-Reroll pro Shop | 35 | Limit 3
- Recyclingschild | II | +35 % Funken beim Recyceln | 35 | Limit 1
- Funkenmagnet | II | +5 % doppelte Funken, +50 % Aufsammelradius, -4 % Schaden | 40
- Verlängerungskabel | II | +40 Reichweite, -3 Nah | 40
- Vorschaltgerät | II | +8 Max HP, -4 % Ausweichen | 40
- Hochspannungsschild | III | +4 Rüstung, +6 Max HP, -5 % Tempo | 75
- Discosplitter | III | +20 Glück, +6 % Ausweichen, -2 % Lebensraub | 70
- Glasfaser | III | +1 Durchschlag, -8 % Schaden | 70
- Prismenlinse | III | +1 Abprall, -15 % Schaden | 65
- Werkstattkoffer | III | +6 Technik, -8 % Angriffstempo | 70
- Ladestation | III | erzeugt alle 15 s eine Batterie | 60
- Überspannung | III | +25 % Schaden, -3 Rüstung | 80
- Sonnenkollektor | III | +18 Aufladung, +15 Glück, -5 % Angriffstempo, -3 % Krit | 75
- Kernreaktor | IV | +15 Max HP, +5 HP-Regen, -10 % Tempo | 120 | Limit 1
- Blitzableiter | IV | bei erlittenem Treffer 50 % Chance: Blitz auf 3 Gegner für 10 (+100 % Strom) | 110 | Limit 1
- Laserzielfernrohr | IV | +15 % Krit, +50 Reichweite, -3 Max HP, -2 Rüstung | 110
- Ewige Flamme | IV | +1 Durchschlag, +10 % Schaden | 130 | Limit 1
- Supernova | IV | Gegner explodieren beim Tod mit 20 % Chance für 10 (+50 % Nah) | 120 | Limit 1
Sieg-Items der Charaktere 13–22 (werden durch einen Sieg mit dem Charakter im Shop freigeschaltet):
- Geisterkerze | III | 25 % Chance bei Gegnertod: Blitz auf 2 Gegner für 6 (+60 % Strom), -1 Rüstung | 70 (Sieg mit Irrlicht)
- Zündspule | III | +2 Brandausbreitung, +25 % Brandschaden, -5 % Angriffstempo | 70 (Zündkerze)
- Kristallprisma | III | jeder 8. Angriff jeder Waffe wirkt eine Frostnova (8 +50 % Strom, 40 % langsamer für 2 s) | 75 | Limit 1 (Kronleuchter)
- UV-Röhre | III | Treffer verfluchen Gegner 3 s (2 Schaden/s, +10 % erlittener Schaden, 1 Stapel), -5 % Schaden | 75 | Limit 1 (Schwarzlicht)
- Pflanzenlicht | III | +50 % Leuchtkristalle, +3 HP-Regen, -10 Reichweite | 65 (Gewächshauslampe)
- Smart-Steckdose | III | +15 % Funken aus Kills, +1 Gratis-Reroll pro Shop, -5 % Schaden | 75 | Limit 1 (Smartbulb)
- Wartungsdrohne | III | eine kreisende Licht-Drohne (6 +100 % Technik, alle 0,6 s), -3 % Tempo | 80 | Limit 1 (Drohnenleuchte)
- Blitzwürfel | III | alle 15 s friert ein Lichtblitz alle Gegner auf dem Bildschirm 0,5 s ein (ohne Nachteil) | 75 | Limit 1 (Stroboskop)
- Blutrote Fassung | III | +4 % Lebensraub, Heilung über Max HP wird zu Schaden am nächsten Gegner, -2 HP-Regen | 70 | Limit 1 (Vampirbirne)
- Spiegelscherbe | III | +2 % Schaden pro getragener Waffe, -10 Reichweite | 70 (Spiegelkugel)
Jedes Item hat Tags (z. B. hp, luck, economy, structure, elemental), damit der Shop Charakter-Vorlieben gewichten kann.

## 10. Charaktere
Format: Name | Stats und Eigenschaften | Startwaffe(n) | Freischaltung.
1. Standardbirne | +5 Max HP, +5 % Tempo, +8 Aufladung | Wahl: Funkenpistole, Glasscherbe, Ast, Funkenfaust | Start
2. Glühfaden-Boxer | +50 % Angriffstempo mit Unbewaffnet, +15 % Ausweichen, -50 Reichweite, -50 Fern | Funkenfaust | Start
3. Neonröhre | +100 Reichweite mit Präzise-Waffen, +25 % Angriffstempo, -30 % Ausweichen, -10 Technik, -10 Fern | Glasscherbe | Start
4. LED-Schütze | +50 Reichweite, Fern-Modifikationen +50 %, keine Nahkampfwaffen, Max-HP-Modifikationen -25 % | Funkenpistole | Start
5. Lavalampe | +5 Strom, Strom-Modifikationen +33 %, Nah/Fern/Technik-Modifikationen -100 % | Lötkolben oder Blitzwerfer | Start
6. Taschenlampe | +20 Technik, Technik-Modifikationen +25 % | Schraubenzieher | 3 Lampentürme gleichzeitig besitzen
7. Discokugel | +125 Glück, Glück-Modifikationen +25 %, 75 % Chance beim Funken-Aufheben: 1 (+15 % Glück) Schaden an zufälligem Gegner, -40 % Angriffstempo, -50 % XP | beliebig | 300 Funken gesammelt (gesamt)
8. Lichterkette | 12 Waffenslots, -5 % Schaden pro Waffe | beliebig | 6 verschiedene Waffen gleichzeitig
9. Halogenstrahler | +30 % Schaden, +25 % Gegner, -10 % Ausweichen | beliebig | +50 % Schaden in einem Run
10. Nachtlicht | +7 HP-Regen, HP-Regen-Modifikationen +50 %, -15 % Schaden | Heilstrahl | 200 HP in einem Run geheilt
11. Blitzlicht | +30 % Tempo, +1 Nah pro 2 % Tempo, -3 Rüstung, -100 Rüstung beim Stillstehen | beliebig | +50 % Tempo in einem Run
12. Kerze | +8 Max HP, +5 HP-Regen, +2 Rüstung, Primitiv-Set-Bonus doppelt, kann keine Elementar-Waffen tragen | Ast | Run nur mit Primitiv-Waffen gewinnen
13. Irrlicht (Nekromant) | Kills füllen ein Seelenglas (max. 100, Seelen werden nicht verbraucht). Alle 3 s ab 5 Seelen kehrt der zuletzt getötete Gegnertyp 10 s als Schattengeist zurück (blaue Kontur, unverwundbar, Kontaktschaden 5 +100 % Strom, max. 8 gleichzeitig), +1 Geisterschaden pro 20 Seelen; Max-HP-Modifikationen -25 %, -3 Rüstung | Seelenlaterne | 500 Kills in einem Run
14. Zündkerze (Pyromane) | 25 % Chance pro Treffer auf Brand (3 +50 % Strom, 3 Ticks), +2 Brandausbreitung, +50 % Brandschaden, brennend sterbende Gegner explodieren klein (3 +50 % Strom, Radius 50); Fern-Modifikationen -50 %, keine Medizinisch-Waffen | Feuerzeugwerfer | 300 Gegner durch Brand getötet (gesamt)
15. Kronleuchter (Erzmagier) | Jeder 4. Angriff jeder Waffe wirkt im Wechsel: Feuerball (8 +100 % Strom, Radius 70), Frostnova (4 +50 % Strom, 40 % langsamer für 2 s), Kettenblitz (6 +80 % Strom, 3 Sprünge); Nah-Modifikationen -100 %, Max-HP-Modifikationen -25 % | Kristallstab | Run gewinnen, in dem Strom 30 erreicht
16. Schwarzlicht (Fluchwirker) | Treffer verfluchen Gegner 4 s: 3 Schaden/s pro Stapel, +15 % erlittener Schaden pro Stapel, bis 3 Stapel; kann nicht kritisch treffen, -2 Rüstung | Voodoo-Nadel | 300 Kills mit der Voodoo-Nadel (gesamt)
17. Gewächshauslampe (Druide) | Alle 12 s wächst eine Lichtranke, die Gegner 1,5 s festhält (max. 5); Leuchtkristalle doppelt so häufig; Batterien heilen doppelt (+3); -15 % Angriffstempo | Dornenranke | 50 Leuchtkristalle zerstört (gesamt)
18. Smartbulb (Händler) | +30 % Funken aus Kills, -15 % Shoppreise, +1 Gratis-Reroll pro Shop; -15 % Schaden, -20 % XP | beliebig | 5.000 Funken gesammelt (gesamt)
19. Drohnenleuchte (Drohnenpilot) | 3 kreisende Licht-Drohnen (6 +100 % Technik, alle 0,6 s), +1 Drohne auf Level 5, 10 und 15, +30 Technik; nur 5 Waffenslots | Schraubenzieher | Run mit 5 stehenden Lampentürmen beenden (Sieg oder Niederlage)
20. Stroboskop (Zeitmagier) | Alle 10 s friert ein Lichtblitz alle Gegner auf dem Bildschirm 1 s ein (Elites/Bosse 0,5 s); -30 Reichweite, -2 Rüstung | Laserpointer | Welle 15 erreichen, ohne ein Item mit Ausweichen zu nehmen
21. Vampirbirne (Blutsauger) | +12 % Lebensraub, Lebensraub-Limit verdoppelt, Heilung über Max HP wird zu Schaden am nächsten Gegner; verliert 1 HP pro 4 s (nie unter 1), HP-Regen wirkungslos | Glasscherbe | 200 HP durch Lebensraub in einem Run geheilt
22. Spiegelkugel (Doppelgänger) | Ein Spiegelbild folgt mit Abstand und feuert Kopien aller Waffen mit 40 % Schaden (kein Lebensraub); -20 % Max HP | beliebig | Eine Welle mit 6 gleichen Waffen (beliebiges Tier) beenden
Sieg mit einem Charakter schaltet ein neues Item für den Shop frei.

Freischaltungen (ChallengeData unter data/challenges): Run-Bedingungen speichern den Bestwert, Gesamt-Bedingungen die Summe über alle Runs; gesperrte Charaktere zeigen den Fortschritt (z. B. "312/500"). Siegbedingungen und "Run beenden" werden nur am Run-Ende geprüft, alle anderen laufend während der Welle.

Status-Effekte: Brand (Schaden pro Tick, breitet sich mit Brandausbreitung aus), Fluch (stapelbar, Schaden über Zeit und mehr erlittener Schaden), Verlangsamen/Einfrieren/Festhalten (eingefrorene Gegner laufen, schießen und treffen nicht; Elites/Bosse halten Status nur halb so lange; nach dem Festhalten kurze Schutzzeit), Verbündete (Schattengeister: unverwundbar, von Gegnern ignoriert, zählen nicht zum Gegnerlimit).

## 11. Gegner
Format: Name | Verhalten | HP (+pro Welle) | Tempo | Schaden (+pro Welle) | Funken | ab Welle.
- Schattenling | läuft auf Spieler zu, Kontaktschaden | 3 (+2) | 200-300 | 1 (+0,6) | 1 | 1
- Mottenschwarm | schnell, kommt in Gruppen | 1 (+1) | 380 | 1 (+0,6) | 1 | 2
- Rammkäfer | verfolgt, Sprint alle 2,5-3,5 s | 4 (+2,5) | 400 | 1 (+0,85) | 1 | 3
- Funkendieb | flieht, Karton + 8 Funken | 5 (+30) | 300-400 | 1 (+0,85) | 8 | 3
- Rußspucker | hält Abstand, schießt Projektile | 8 (+1) | 200 | 1 (+0,75) | 1 | 4
- Flackerer | heilt Gegner in der Nähe | 10 (+8) | 400 | 1 (+0,85) | 2 | 7 (ab Spannung 1)
- Schattenklotz | groß, Sprint, widersteht Rückstoß | 20 (+11) | 300 | 2 (+0,85) | 3 | 8
- Hetzer | wird jede Sekunde schneller (150 -> 600) | 10 (+24) | 150-600 | 1 (+1,2) | 3 | 11
- Helmmotte | robust, verfolgt | 8 (+4) | 225-275 | 1 (+1,0) | 1 | 13
- Brutsack | langsam, setzt beim Tod 3 Rußschützen frei | 10 (+1) | 120 | 1 (+0,85) | 1 | 14
- Rußschütze | kreist um Spieler, schießt nahe Projektile | 5 (+5) | 350 | 1 (+1,0) | 1 | 14
- Verstärker | flieht, bufft andere Gegner (+150 % HP, +25 % Schaden, +50 % Tempo, rote Kontur) | 20 (+3) | 150 | 1 (+0,6) | 2 | 16
Elites (Spannung 2+), HP-Basis 1 (+750 pro Welle), auf Welle 11/12 nur 75 % HP, droppen legendären Karton; je 2 Mutationsphasen (Wechsel bei 60 % HP oder nach 25 s):
- Kolbengolem: Sturmangriff alle 2 s mit Seitenprojektilen -> Phase 2: alle 1,3 s, kürzer, zusätzliche Projektile.
- Rußmutter: 4-fache Schnittwelle alle 1,4 s -> Phase 2: flieht, Doppelschnitte, spawnt Schattenlinge.
- Schattenweber: Projektilkreise um sich -> Phase 2: Spiralmuster auf den Spieler.
Bosse (Welle 20, zufällig einer; bei Spannung 5 beide mit 75 % HP), ca. 29.000 HP, Kontaktschaden 30, Projektile 23:
- Der Dimmer: verfolgt, dasht, kreisende Projektile -> ab 50 % HP: kein Dash, Projektilsalven in alle Richtungen.
- Die Finsternis: markiert Zonen um den Spieler, die nach 1 s Projektile erzeugen -> ab 75 %: größere Zonen -> ab 40 %: +150 % Tempo, Projektilkreise.

## 12. Grafikstil (an Brotato angelehnt, eigene Motive)
- Niedlicher Cartoon-Look, flache Farben, dicke dunkle Outline 3-4 px (#2A1E2E), ein Glanzlicht und ein Schattenton pro Form, keine Verläufe außer Glow.
- Alle Sprites als SVG unter res://art (Godot importiert SVG direkt). Ein Python- oder GDScript-Hilfsskript darf SVGs bei Bedarf in PNG rendern.
- Größen: Spieler ca. 72 x 96 px, normale Gegner 48-64 px, Elites 120-160 px, Bosse 200+ px, Waffen ca. 48 px, Item-Icons 64 x 64 px.
- Bulbro: gelber Glaskolben #FFE066 mit weißem Glanz, grauer Schraubsockel #9AA0A6, große ovale Augen, kleiner Mund; Charaktervarianten unterscheiden sich durch Form und Farbe.
- Gegner: Violett/Indigo (#5B3F8C, #3A2A5C) mit hellen Augen, runde Blobformen, kleine Fühler/Flügel.
- Boden: dunkles Blaugrau #2B2F3A mit zufälligen helleren Flecken; Arena-Rand als dicke Linie.
- Funken: gelbe Splitter #FFD43B mit Glow. Batterien: kleine grün-gelbe Zellen. Karton: brauner Karton mit Glühbirnen-Symbol.
- UI: dunkle halbtransparente Panels (#1B1B24, 85 %), runde Ecken, dicke runde Schrift (OFL), Tier-Farben grau #8A8A8A, blau #4A90E2, lila #9B59B6, rot #E74C3C.
- Animation per Code statt Sprite-Sheets: Idle = sanftes Hüpfen/Squash (0,6 s), Laufen = Neigung +-8 Grad und schnelleres Hüpfen, Treffer = weißer Flash-Shader 0,1 s, Tod = Squash + Pop + Partikel + kurzer Fleck am Boden, Spawn = rotes X, dann Pop-in.
- Schadenszahlen: weiß, Krits gelb und größer, steigen auf und verblassen.
- Licht: weiches PointLight2D am Spieler, leicht abgedunkelte Szene (in den Optionen abschaltbar).

## 13. Technische Architektur
- Ordner: scenes/{player,enemies,weapons,projectiles,pickups,structures,ui,world}, scripts/{core,systems,data}, data/{weapons,items,characters,enemies,waves,upgrades}, art/{player,enemies,weapons,items,ui,fx}, audio/{sfx,music}, tests/.
- Autoloads: Events (Signalbus), GameState (Run-Zustand), DataRegistry (lädt alle Resources), SaveManager, AudioManager.
- Resources: StatBlock, StatModifier, WeaponData, ItemData (Liste von Effekten), CharacterData, EnemyData, WaveData, UpgradeData.
- Effektsystem: Items und Charaktere bestehen aus kombinierbaren Effekt-Resources (StatEffect, OnKillEffect, OnHitTakenEffect, TimedSpawnEffect ...), nicht aus Spezialcode pro Item.
- Object Pools für Gegner, Projektile, Pickups, Schadenszahlen.
- Physik-Layer: player, enemies, player_projectiles, enemy_projectiles, pickups, world, neutral.
- Input: WASD/Pfeiltasten, Gamepad-Stick, Esc = Pause, Taste für manuelles Zielen.
- Run-RNG mit Seed (für Debugging reproduzierbar).
- Ziel: 60 FPS bei 100 Gegnern und 300 Projektilen.

# BULBRO

BULBRO ist ein 2D-Top-Down-Arena-Roguelite in Godot 4, das die Spielmechaniken von Brotato übernimmt: Autofire, 20 Wellen, Shop zwischen den Wellen.
Der Held ist Bulbro, eine Glühbirne mit bis zu 6 schwebenden Waffen, die gegen Schattenwesen und Motten kämpft.
Alle Namen, Grafiken (SVG), Texte und Sounds sind eigene Kreationen; das Spiel ist auf Deutsch und vollständig datengetrieben.

**Lies vor jeder Aufgabe [docs/GDD.md](docs/GDD.md).** Es ist die verbindliche Quelle für Mechaniken, Zahlen und Architektur.

Aktuelle Ausbaustufe: [docs/PHASE_15.md](docs/PHASE_15.md), Pakete einzeln abarbeiten, nach jedem Paket Commit + Push, Stand in docs/ENTWICKLUNG.md notieren.
Zum Einstieg in eine neue Sitzung zuerst den Abschnitt „Nächste Sitzung“ ganz oben in [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md) lesen.

## Arbeitsregeln (GDD Abschnitt 0)

- Rolle: Senior-Entwickler für Godot 4.x (GDScript mit statischen Typen) und Game Designer.
- Mechaniken von Brotato, aber keine Assets oder Texte aus Brotato.
- Datengetrieben: Alle Spielwerte liegen als Resources (`.tres`) unter `res://data`. Keine Magic Numbers im Code.
- Kleine Schritte: erst Plan, dann Umsetzung, dann Prüfung.
- Nach jeder Phase: Headless-Check ohne Fehler, GUT-Tests grün, `git commit` mit aussagekräftiger Nachricht.
- Nach jedem Commit eines Pakets bzw. einer Phase automatisch pushen (`git push`, Remote `origin` = github.com/zBadly/Bulbro).
- Spieltexte auf Deutsch, immer über die Übersetzungstabelle (`tr()`), nie hart codiert.

## Code-Stil

- GDScript mit statischen Typen überall (Variablen, Parameter, Rückgabewerte, Schleifenvariablen).
- `snake_case` für Dateien, Funktionen und Variablen; `PascalCase` für `class_name`; `UPPER_SNAKE_CASE` für Konstanten.
- Eine Klasse pro Datei; wiederverwendbare Klassen bekommen ein `class_name`.
- Autoload-Skripte haben **kein** `class_name`, weil der Name sonst mit dem Autoload kollidiert. Statische Helfer wie `Juice` (`scripts/core/juice.gd`) dagegen schon.
- Grafikregeln, Palette und SVG-Aufbau: [docs/ART_STYLE.md](docs/ART_STYLE.md).
- Entwicklungsstand, Startwerte und offene Punkte: [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md) (bei Wertänderungen mitpflegen).
- Systeme kommunizieren über den Signalbus `Events` statt über direkte Referenzen.
- Tests liegen unter `tests/` (Dateien `test_*.gd`, Basisklasse `GutTest`).

## Sound und Musik

Soundeffekte und der Musik-Platzhalter werden per Skript synthetisiert (Python 3, nur Standardbibliothek + numpy):

```bash
python tools/make_sfx.py     # 15 Effekte nach audio/sfx/
python tools/make_music.py   # Loop nach audio/music/bulbro_loop.wav
```

Lautstärken, Instanz-Limits und Musik stehen in `data/config/audio_config.tres`. Wiedergabe immer über `AudioManager.play(&"name")`.
Für echte Musik CC0-Tracks (z. B. kenney.nl, opengameart.org; Lizenz prüfen) nach `audio/music` legen und in der Config eintragen.

## Debug-Tasten

- **F3**: Debug-Overlay mit allen Stats
- **F10**: Admin-Menü (nur wenn in den Optionen unter „Erweitert“ der Admin-Modus an ist, auch im Release-Build): Welle/Endlos, Zeit, Geschwindigkeit, Hitboxen, Charakter, Level, Funken, Unverwundbar/Unendlich HP/Schaden x10, Gegner spawnen/entfernen/Arena füllen, Waffen und Items geben/entfernen, Shop kostenlos/Reroll gratis/Angebot platzieren, alle Charaktere freischalten. Ein Run mit einer Admin-Aktion zählt nicht für Freischaltungen und Statistiken.
- **Esc**: Pause

## Godot aufrufen

Godot 4.7.2 liegt unter `D:\Game\Tools\Godot\`. Für die Kommandozeile die Konsolen-Exe verwenden, nur sie gibt Fehler im Terminal aus.

```bash
GODOT="/d/Game/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"

# Assets/Skripte importieren (nach neuen Dateien oder class_name-Änderungen)
"$GODOT" --headless --path . --import

# Headless-Fehlercheck: Hauptmenü und Run-Szene je 300 Frames
"$GODOT" --headless --path . --quit-after 300
"$GODOT" --headless --path . --quit-after 300 res://scenes/world/main.tscn

# GUT-Testlauf (Konfiguration in .gutconfig.json)
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd
# Balancing-Simulator (Tabelle; mit --apply werden Vorschläge in die Wellen geschrieben)
"$GODOT" --headless --path . res://tools/balance_sim.tscn -- 0

# Windows-Build (Export-Vorlagen müssen im Editor installiert sein)
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/Bulbro.exe
```

Spielstände: Ohne Bildschirm (Headless-Check, GUT) nutzt das Spiel automatisch einen frischen eigenen Spielstand (`user://headless_save.json`), GUT zusätzlich `user://test_save.json`. Werkzeuge und Screenshot-Skripte mit Bildschirm setzen `-- --save=user://<name>.json` oder die Umgebungsvariable `BULBRO_SAVE`. Der echte Spielstand (`user://save.json`) wird nur bei einem normalen Spielstart verwendet.

Der Headless-Modus kompiliert keine Shader. Nach Shader-Änderungen die betroffene Szene einmal mit echtem Renderer starten (ohne `--headless`) und die Ausgabe auf Fehler prüfen.

Hilfsskripte, die mit `-s` laufen (`extends SceneTree`), werden kompiliert, bevor Autoloads existieren: Sie dürfen keine Klassen per Typ referenzieren, die Autoloads nutzen (z. B. `Arena`, `Player`). Stattdessen `Node` und `call()` verwenden.

Der Check gilt als bestanden, wenn keine Zeilen mit `ERROR`, `SCRIPT ERROR` oder `WARNING` ausgegeben werden und GUT „All tests passed!“ meldet.

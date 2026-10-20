# BULBRO – Art Style Guide

Ergänzt [GDD.md](GDD.md) Abschnitt 12. Alle Sprites sind handgeschriebene SVGs, Godot importiert sie direkt als Textur.

## Palette

| Rolle | Grundton | Schatten | Glanz | Verwendung |
|---|---|---|---|---|
| Outline | `#2A1E2E` | – | – | Alle Konturen, Augen, Mund |
| Bulbro Glas | `#FFE066` | `#F2B83A` | `#FFFFFF` | Spielerkolben |
| Bulbro Sockel | `#9AA0A6` | `#6F757C` | `#C9CED3` | Schraubsockel, Metall allgemein |
| Kontakt | `#5A5F66` | – | – | Sockelspitze |
| Wangen | `#FF9E7A` | – | – | Bulbro, 60 % Deckkraft |
| Gegner Körper | `#5B3F8C` | `#3A2A5C` | `#8A6BC0` | Alle Schattenwesen |
| Gegner Augen | `#F7F0FF` | – | – | Augenweiß |
| Gegner Tiefe | `#1A1220` | – | – | Öffnungen (Rußspucker-Schlund) |
| Funke | `#FFD43B` | `#E0A800` | `#FFF4B8` | Funken, Mündungsblitz |
| Batterie | `#6CCB4A` / `#E8E04A` | `#4E9E33` | `#C9F2A8` | Heil-Pickup |
| Karton | `#C8925A` | `#9E6C3A` | `#E3B884` | Ersatzteil-Karton, Klebeband `#EBD9B0` |
| Kristall | `#8FE3FF` | `#4FB3E0` | `#E6FAFF` | Leuchtkristall |
| Fels | `#5A5F70` | `#41444F` | `#767C90` | Kristallsockel |
| Holz | `#9C6B3F` | `#734B28` | `#C08A57` | Ast, Griffe |
| Blatt | `#7ED957` | `#55A838` | – | Ast-Blatt |
| Waffe orange | `#F28C38` | `#C9651C` | `#FFB574` | Funkenpistole |
| Glas | `#BFEFFF` | `#7FC8E8` | `#FFFFFF` | Glasscherbe |
| Handschuh | `#FFB347` | `#E08A1E` | `#FFD699` | Funkenfaust |
| Boden | `#2B2F3A` | – | `#2F3340` / `#333846` | Bodentextur und Flecken |
| Spawn-X | `#E74C3C` | – | – | Spawn-Marker, Buff-Kontur |
| UI Panel | `#1B1B24` @ 85 % | – | – | Alle Panels |
| Tier I–IV | `#8A8A8A` | `#4A90E2` | `#9B59B6` | `#E74C3C` (IV) |

## Outline-Regeln

- Farbe immer `#2A1E2E`, nie Schwarz.
- Strichstärke: **4 px** für Figuren, Gegner und Waffen; **3 px** für kleine Pickups (unter 32 px) und Details (Mund, Fühler, Gewinde).
- `stroke-linejoin="round"` und `stroke-linecap="round"` überall.
- Die Outline wird als **letzte** Ebene einer Form gezeichnet (`fill="none"`), damit Schatten und Glanz sie nie überdecken.
- Mindestens 2 px transparenter Rand zum ViewBox-Rand (halbe Strichstärke ragt nach außen).
- Der Boden hat keine Outline, nur die Arena-Begrenzung (dicke Linie).

## Schattierung

Pro Form genau ein Grundton, ein Schattenton, ein Glanzlicht. Licht kommt von **oben links**.
Technik: Form mit Schattenton füllen, Grundton als nach oben links verschobene Form per `clipPath` darüberlegen. Dadurch entsteht unten rechts eine Schattensichel. Glanz als kleine helle Ellipse oben links. Keine Verläufe, außer `radialGradient` für Glow (Funke, Kristall).

## Größen

| Objekt | Größe (px) | Datei |
|---|---|---|
| Spieler | 72 × 96 | `art/player/bulbro.svg` |
| Normale Gegner | 48–64 | `art/enemies/*.svg` |
| Elites | 120–160 | `art/enemies/elite_*.svg` |
| Bosse | 200+ | `art/enemies/boss_*.svg` |
| Waffen | 48 × 48 | `art/weapons/*.svg` |
| Item-Icons | 64 × 64 | `art/items/*.svg` |
| Pickups | 28–44 | `art/pickups/*.svg` |
| Neutrale Objekte | ca. 56 × 72 | `art/world/*.svg` |
| Spawn-Marker | 48 × 48 | `art/fx/spawn_marker.svg` |
| Bodenkachel | 256 × 256, kachelbar | `art/world/floor_tile.svg` |

Ankerpunkt: Figuren werden in Godot mit `offset.y = -Höhe/2` platziert, damit Squash und Hüpfen von den Füßen aus wirken.

## Beispiel-SVG-Struktur

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 56 56">
  <defs>
    <!-- Körperform einmal definieren, mehrfach verwenden -->
    <path id="body" d="M28,12 C40,12 49,21 49,36 ... Z"/>
    <clipPath id="body-clip"><use href="#body"/></clipPath>
  </defs>
  <!-- 1. Hintere Teile (Fühler, Flügel) mit eigener Outline -->
  <!-- 2. Form im Schattenton -->
  <use href="#body" fill="#3A2A5C"/>
  <!-- 3. Grundton, nach oben links verschoben, geclippt -->
  <ellipse cx="25" cy="30" rx="22" ry="20" fill="#5B3F8C" clip-path="url(#body-clip)"/>
  <!-- 4. Glanzlicht -->
  <ellipse cx="19" cy="22" rx="5" ry="3.5" fill="#8A6BC0" transform="rotate(-30 19 22)"/>
  <!-- 5. Outline als letzte Ebene der Form -->
  <use href="#body" fill="none" stroke="#2A1E2E" stroke-width="4" stroke-linejoin="round"/>
  <!-- 6. Gesicht obenauf -->
</svg>
```

## Animation (per Code, siehe `scripts/core/juice.gd`)

| Zustand | Umsetzung |
|---|---|
| Idle | Squash/Stretch-Hüpfen, 0,6 s pro Zyklus |
| Laufen | Neigung ±8° zur Laufrichtung, Hüpfen doppelt so schnell |
| Treffer | `hit_flash.gdshader`, 0,1 s weiß |
| Tod | Squash, Pop auf 0, danach Partikel und Fleck (spätere Phase) |
| Spawn | Rotes X pulsiert 1 s, dann Pop-in mit Überschwingen |
| Buff | `outline.gdshader` mit roter Kontur |

## Do's

- Runde, weiche Silhouetten; große Augen; klare Lesbarkeit bei 1× Zoom.
- Gegner immer violett/indigo, Spieler und Pickups warm und hell. So bleibt der Kontrast im Gewimmel erhalten.
- Gleiche Strichstärke innerhalb einer Objektgruppe.
- IDs und `clipPath`-Namen pro Datei eindeutig halten.

## Don'ts

- Keine Verläufe auf Flächen, keine Schlagschatten im SVG, keine Filter (`<filter>` wird von Godot nicht unterstützt).
- Kein Text im SVG; alle Texte laufen über die Übersetzungstabelle.
- Keine reinen Schwarz- oder Weißflächen außer Glanzpunkten.
- Keine Motive, Formen oder Farben, die Brotato-Assets direkt nachbilden.
- Keine externen Referenzen (Bilder, Fonts) im SVG.

"""Erzeugt die Charakter-Porträts (128 x 128) für Charakterauswahl und Lexikon aus den Spielsprites.

Aufruf im Projektordner:  python tools/make_portraits.py

Jedes Porträt besteht aus einem runden Lichthof in der Lichtfarbe der Figur und dem vergrößerten
Spielsprite (art/characters/<id>.svg). Schwingende Zusatzteile (<id>_kristalle.svg) werden mit eingebaut.
Nach Änderungen an einem Sprite das Skript erneut ausführen.
"""
import os
import re

SRC = "art/characters"
DST = "art/portraits"
SIZE = 128
SCALE = 1.25
OUTLINE = "#2A1E2E"
PANEL = "#1B1B24"
SWING_SUFFIX = "_kristalle"

# Lichtfarbe je Charakter (gleich wie light_color in data/characters, sonst Bulbro-Gelb)
GLOW = {
    "standardbirne": "#FFE066", "gluehfaden_boxer": "#FFB347", "neonroehre": "#FF6EC7",
    "led_schuetze": "#8FE3FF", "lavalampe": "#FF8C42", "taschenlampe": "#FFF4B8",
    "discokugel": "#C9A8F2", "lichterkette": "#7ED957", "halogenstrahler": "#FFFFFF",
    "nachtlicht": "#9FD8FF", "blitzlicht": "#FFD43B", "kerze": "#FF8C42",
    "irrlicht": "#6FD3FF", "zuendkerze": "#FFB347", "kronleuchter": "#FFD27A",
    "schwarzlicht": "#B07CFF", "gewaechshauslampe": "#9BE36A", "smartbulb": "#8FE3FF",
    "drohnenleuchte": "#FFD27A", "stroboskop": "#FFF4B8", "vampirbirne": "#FF5C6A",
    "spiegelkugel": "#E6FAFF",
}


def inner(path: str, prefix: str) -> str:
    """Inhalt eines SVG ohne Wurzel-Tag; IDs bekommen ein Präfix, damit nichts kollidiert."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    body = re.sub(r"^.*?<svg[^>]*>", "", text, count=1, flags=re.S)
    body = body.rsplit("</svg>", 1)[0]
    body = re.sub(r'id="([^"]+)"', lambda m: f'id="{prefix}{m.group(1)}"', body)
    body = re.sub(r'url\(#([^)]+)\)', lambda m: f"url(#{prefix}{m.group(1)})", body)
    body = re.sub(r'href="#([^"]+)"', lambda m: f'href="#{prefix}{m.group(1)}"', body)
    return body


def portrait(char_id: str) -> str:
    color = GLOW.get(char_id, "#FFE066")
    body = inner(os.path.join(SRC, char_id + ".svg"), "s-")
    swing = os.path.join(SRC, char_id + SWING_SUFFIX + ".svg")
    if os.path.exists(swing):
        body += inner(swing, "k-")
    w, h = 72 * SCALE, 96 * SCALE
    tx, ty = (SIZE - w) / 2, (SIZE - h) / 2 + 2
    c = SIZE / 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">\n'
        f'  <!-- Porträt {char_id} (erzeugt von tools/make_portraits.py, nicht von Hand ändern) -->\n'
        f'  <defs><radialGradient id="p-glow"><stop offset="0" stop-color="{color}" stop-opacity="0.55"/>'
        f'<stop offset="0.7" stop-color="{color}" stop-opacity="0.12"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient></defs>\n'
        f'  <circle cx="{c}" cy="{c}" r="{c - 4}" fill="{PANEL}"/>\n'
        f'  <circle cx="{c}" cy="{c}" r="{c - 4}" fill="url(#p-glow)"/>\n'
        f'  <circle cx="{c}" cy="{c}" r="{c - 4}" fill="none" stroke="{color}" stroke-width="3" stroke-opacity="0.8"/>\n'
        f'  <circle cx="{c}" cy="{c}" r="{c - 2}" fill="none" stroke="{OUTLINE}" stroke-width="2"/>\n'
        f'  <g transform="translate({tx:.1f},{ty:.1f}) scale({SCALE})">{body}  </g>\n'
        f'</svg>\n')


def main() -> None:
    os.makedirs(DST, exist_ok=True)
    count = 0
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".svg") or SWING_SUFFIX in name:
            continue
        char_id = name[:-4]
        with open(os.path.join(DST, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(portrait(char_id))
        count += 1
    print(f"{count} Porträts nach {DST}")


if __name__ == "__main__":
    main()

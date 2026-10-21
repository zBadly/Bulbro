# Phase 15 – Spezifikation

## Paket 1: Crash nach Bosssieg (höchste Priorität)
- Das Spiel stürzt ab, wenn der Boss in Welle 20 besiegt wird.
- Reproduzieren (Debug: zu Welle 20 springen, Boss mit Debug-Schaden töten), auch bei Spannung 5 mit beiden Bossen und mit Charakteren mit Verbündeten/Spiegelbild/Drohnen.
- Ursache finden und erklären (typisch: freigegebene Nodes, Signale auf gelöschte Objekte, Run-Ende während Pool-Rückgabe, Speichern des Spielstands, Challenge-Auswertung).
- Regressionstest, der einen Bosssieg simuliert.

## Paket 2: Lexikon-Erweiterungen
- Button "Alles anzeigen" (Umschalter) im Lexikon: zeigt auch nicht freigeschaltete Einträge vollständig an, als wären sie freigeschaltet. Ein dezenter Hinweis "noch gesperrt" plus Freischaltbedingung bleibt sichtbar. Einstellung wird gespeichert.
- Prüfen und nachbessern: Jeder Stat im Reiter Spielmechaniken erklärt konkret, was er macht, mit Formel in Alltagssprache, Beispiel und Obergrenze (z. B. Rüstung: "Reduziert erlittenen Schaden um Rüstung/(Rüstung+15). 5 Rüstung = 25 % weniger Schaden. Negative Rüstung erhöht den Schaden."). Gleiches für alle Sekundär-Stats.

## Paket 3: Admin-Modus
- Aktivierung: in den Optionen unter "Erweitert" ein Schalter "Admin-Modus". Ingame öffnet F10 das Admin-Menü (Spiel pausiert).
- Funktionen: Welle wählen (1-20 und Endlos), Charakter wechseln (Stats werden neu berechnet, Waffen bleiben), Level setzen, Funken setzen, beliebige Gegner spawnen (Typ, Anzahl, an Maus oder zufällig, inkl. Elites und Bosse), alle Gegner entfernen, Unverwundbar an/aus, Unendlich HP, Schaden x10, Beliebige Waffe (mit Tier) oder Item geben/entfernen, Shop: alles kostenlos, Shop neu würfeln gratis, bestimmtes Item in den Shop legen, Zeit der Welle anhalten/überspringen, Spielgeschwindigkeit 0,5x/1x/2x/4x, Hitboxen anzeigen.
- WICHTIG: Solange der Admin-Modus in einem Run benutzt wurde, zählen keine Freischaltungen, Achievements und Gesamtstatistiken. Ingame wird ein kleines "ADMIN"-Abzeichen angezeigt.
- Das bisherige Debug-Menü (F4) wird in den Admin-Modus integriert.

## Paket 4: HUD und Tooltips
- Kleine HP-Leiste unter normalen Gegnern. Option in den Einstellungen: "Immer", "Nur bei Schaden" (Standard), "Aus". Elites bekommen eine etwas größere Leiste, Bosse behalten die große oben.
- Hover-Tooltips (Maus und Gamepad-Fokus) für besessene Waffen und Items im Shop, im Pause-Menü und im Run-Ende: alle Stats bzw. Effekte, bei Waffen aktueller Schaden mit Skalierung (z. B. "18 = 12 + 50 % von 12 Nah"), Klassen, Kills und Schaden in diesem Run.
- Stat-Panel: positive Werte grün, negative rot, 0 neutral. Stats mit Obergrenze zeigen sie dahinter, z. B. "Ausweichen 45 % (max. 60 %)"; erreichte Obergrenze gelb markiert.
- Waffenklassen ingame: Im Waffen-Tooltip die Set-Boni der Klasse als Liste 2/3/4/5/6 mit hervorgehobener aktueller Stufe ("3/6 Klinge: +2 Nah, +2 % Lebensraub, nächste Stufe bei 4"). Zusätzlich im Shop eine Leiste "Aktive Set-Boni".
- Tier-Farbe ingame: Die um den Spieler schwebenden Waffen bekommen eine Kontur in ihrer Tier-Farbe (grau #8A8A8A, blau #4A90E2, lila #9B59B6, rot #E74C3C), dezent, aber bei 100 Gegnern erkennbar.

## Paket 5: Run-Statistiken und Run-Ende
- Pro Run erfassen: Kills, Schaden und DPS je Waffe und je Item mit Schadenseffekt, Kills von Verbündeten/Strukturen/Pets, erlittener Schaden, geheilte HP, ausgewichene Treffer, gesammelte und ausgegebene Funken, Rerolls, Level, Zeit je Welle.
- Nach dem Bosssieg ein Bildschirm mit drei Optionen: "Endlos weiterspielen", "Neue Runde" (zur Charakterauswahl), "Hauptmenü". Daneben ein Reiter "Statistiken" mit allen Run-Werten (Tabelle je Waffe/Item sortierbar nach Kills/Schaden), ohne die Auswahl zu verlassen. Gleicher Statistik-Bildschirm auch bei Niederlage.
- Schadenszahlen aus dem Kampf schweben beim Run-Ende-Bildschirm noch sichtbar hinter dem Titel; sie sollen beim Run-Ende verschwinden.
- Der Button "Nochmal" bleibt zusätzlich zu den drei Optionen erhalten.

## Paket 6: Endlos-Modus (überarbeiten)
- Nach dem Bosssieg wählbar. Wellen dauern 60 s, Gegner-HP, Schaden und Dichte steigen pro Welle über einen Endlos-Faktor; Aufladung wird schwächer.
- Alle 10 Wellen (30, 40, 50 ...) erscheinen beide Bosse gleichzeitig, mit jedem Bosszyklus stärker (Startwert +40 % HP und +15 % Schaden pro Zyklus).
- Bestwert "Höchste Endlos-Welle" je Charakter wird gespeichert.

## Paket 7: Boss-Phasen sichtbar
- Boss-HP-Leiste mit Markierungen an den Phasengrenzen und Phasenname/-nummer.
- Beim Phasenwechsel: kurzer Text ("Phase 2: Raserei"), Farbwechsel/Aura am Boss, kurzer Screenshake, 0,5 s Unverwundbarkeit des Bosses mit Animation. Gilt auch für Elites (kleinere Variante). Falls schon teilweise vorhanden, vervollständigen.

## Paket 8: Neue Inhalte
### Einzigartige Items (eigene Seltenheit "Einzigartig", Farbe Gold #F5A623, max. 1 pro Item pro Run, im Shop ab Welle 5 selten, nie im Karton)
- Panzerglas: +1 % Schaden pro Punkt Rüstung
- Schwungrad: +1 Nah pro 3 % Tempo
- Glücksfassung: +1 % Krit pro 10 Glück
- Hochspannungsspeicher: +1 % Schaden pro 4 Max HP, -2 HP-Regen
- Gleichrichter: +1 Strom pro 5 % Angriffstempo
- Leuchtturm: +3 Reichweite pro Level
- Reservebatterie: einmal pro Welle einen tödlichen Treffer mit 1 HP überleben
- Thermosicherung: unter 30 % HP +40 % Angriffstempo und +20 % Tempo
- Kondensator: nach je 15 Kills verursacht der nächste Angriff jeder Waffe doppelten Schaden
- Sparlampe: +1 % Schaden pro 20 Funken im Besitz (max. +30 %), Preise +10 %
Alle Werte Startwerte, per Simulator prüfen.

### Pets (eigener Item-Typ "Begleiter", max. 2 gleichzeitig, folgen dem Spieler, unverwundbar)
- Leuchtkäfer: kreist und schießt 4 (+50 % Fern) alle 1 s
- Funkenspatz: sammelt Funken in 300 px Umkreis ein
- Lampenschirm-Schildkröte: blockt alle 3 s ein gegnerisches Projektil in deiner Nähe
- Batterie-Igel: rollt auf Gegner, 8 (+60 % Nah), Rückstoß
- Mini-Birne: trägt eine Kopie deiner ersten Waffe mit 25 % Schaden

### Türme (Strukturen, skalieren mit Technik, als Items kaufbar, platzieren sich zufällig nahe dem Spieler zu Wellenbeginn)
- Flammenturm: Flammenstrahl, setzt Brand
- Frostturm: verlangsamt Gegner im Radius um 30 %
- Heilturm: heilt 1 HP alle 4 s, solange du in seinem Radius stehst
- Stolperdraht: legt alle 8 s eine Mine (15 +100 % Technik Explosionsschaden)
Pets und Türme bekommen SVGs im bestehenden Stil, Lexikon-Einträge, Kill-Statistik und Tooltips.

## Paket 9: Startwaffen-Auswahl und Achievements
### Startwaffen je Charakter (nur freigeschaltete Waffen wählbar, gesperrte als Silhouette mit Bedingung)
Standardbirne: Funkenpistole, Glasscherbe, Ast, Funkenfaust | Glühfaden-Boxer: Funkenfaust, Ast, Lampenhammer | Neonröhre: Glasscherbe, Kabelpeitsche, Laserpointer | LED-Schütze: Funkenpistole, Laserpointer, Batterie-Schleuder, Prisma | Lavalampe: Lötkolben, Blitzwerfer, Glühwürmchen-Stab, Kristallstab | Taschenlampe: Schraubenzieher, Lötkolben | Discokugel: Funkenpistole, Prisma, Funkensieb | Lichterkette: Funkenpistole, Glasscherbe, Ast | Halogenstrahler: Lampenhammer, Leuchtrakete, Taschenlampenstrahl | Nachtlicht: Heilstrahl, Dornenranke | Blitzlicht: Funkenfaust, Glasscherbe, Kabelpeitsche | Kerze: Ast, Batterie-Schleuder | Irrlicht: Seelenlaterne, Glühwürmchen-Stab | Zündkerze: Feuerzeugwerfer, Lötkolben | Kronleuchter: Kristallstab, Blitzwerfer, Taschenlampenstrahl | Schwarzlicht: Voodoo-Nadel, Glühwürmchen-Stab | Gewächshauslampe: Dornenranke, Ast, Heilstrahl | Smartbulb: Funkenpistole, Funkensieb, Laserpointer | Drohnenleuchte: Schraubenzieher, Funkenpistole | Stroboskop: Laserpointer, Prisma, Taschenlampenstrahl | Vampirbirne: Glasscherbe, Kabelpeitsche, Funkenfaust | Spiegelkugel: Prisma, Funkenpistole, Glasscherbe
Prüfe jede Liste gegen die Charakter-Einschränkungen (z. B. LED-Schütze keine Nahkampfwaffen, Kerze keine Elementar-Waffen) und melde Konflikte. Die Auswahl zeigt je Waffe Werte, Klassen und Synergie-Hinweis zum Charakter.

### Gesamtstatistiken und Achievements (dauerhaft im Spielstand)
- Hauptmenü-Punkt "Statistiken": Runs, Siege je Spannung, Spielzeit, Kills gesamt und je Gegnertyp, Funken, Lieblingscharakter/-waffe, höchste Endlos-Welle, Bestzeiten.
- Achievements (ca. 40, als Resources, mit Icon, Beschreibung und Fortschritt): z. B. Sieg mit jedem Charakter, Sieg auf jeder Spannung, 10.000 Kills, Tier-IV-Waffe kaufen, 3 Einzigartige in einem Run, Welle 50 im Endlos-Modus, Boss in unter 30 s, Run ohne Treffer in einer Welle, 6 Waffen einer Klasse, alle Pets entdeckt. Popup beim Erreichen, Übersicht im Menü und im Lexikon.

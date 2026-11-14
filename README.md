# BananaFarm

Lasher-Farmhilfe für Düsterbruch Ost auf OctoWoW (Vanilla 1.12). Teil von [BananaForge](https://github.com/BananaForge).

*Lasher farm helper for Dire Maul East on OctoWoW (Vanilla 1.12). German and English, switch with `/bf lang de|en|auto`.*

## Was es kann (Stand 0.2.0)

- **Vendorliste**: Beim Öffnen eines Händlers (z. B. Repairbot) werden alle Items der Vendorliste verkauft.
- **Mailliste**: Am Briefkasten fragt das Addon nach und schickt alle Items der Mailliste an den Bankalt (mehrere Anhänge pro Brief, soweit der Client sie erlaubt).
- **Session**: Start/Stop. Während die Session läuft, werden neue Items erkannt und automatisch einsortiert. Anzeige von Dauer, Wert und Gold pro Stunde.
- **Sortierregel**: AH-Preis mindestens x-mal Händlerwert (Standard 1,5) und über dem Mindestpreis: Mailliste, sonst Vendorliste. Graue Items gehen auf die Vendorliste. Ohne AH-Preis landet ein Item in „Unsortiert" und du entscheidest per Pop-up oder im Listen-Reiter. Von Hand zugeordnet schlägt immer die Automatik.
- **AH-Scan**: Gezielte Suche nach den bekannten Items am Auktionshaus (voller Marktpreis, Schnitt der günstigsten 30 %).
- **Taschenwarnung**, wenn nur noch wenige Plätze frei sind.
- **Verkaufsschutz**: Solange eine Session läuft, lässt sich beim Händler von Hand nur verkaufen, was auf der Vendorliste steht. Alt+Rechtsklick verkauft trotzdem.
- **Leiste**: Gold im Run (seit dem letzten Reset), in der Session und pro Stunde, dazu Dauer, Resets der letzten Stunde mit Countdown und Pull-Zähler.
- **Reset-Zähler**: Instanz-Resets werden erkannt und mit Uhrzeit gespeichert, das übersteht Relog und Charwechsel.
- **Pull-Zähler** (braucht SuperWoW): Mobs im Kampf. Im Hunter-Modus zählen Leichen mit und es gibt eine Warnung an der Grenze (Standard 80).
- **`/bf probe`**: Prüft, was SuperWoW, Nampower und der Server können. Davon hängt der Ein-Button-Loot ab, der noch fehlt.

## Installation

Ordner `BananaFarm` nach `Interface/AddOns/` kopieren. Der Ordner muss genau `BananaFarm` heißen.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/bf` | Fenster öffnen oder schließen |
| `/bf start`, `/bf stop` | Farm-Session starten oder beenden |
| `/bf alt Name` | Bankalt festlegen |
| `/bf mail` | Mailliste am Briefkasten verschicken |
| `/bf sell` | Vendorliste beim Händler verkaufen |
| `/bf reset` | Instanzen zurücksetzen (wird mitgezählt) |
| `/bf scan` | AH-Preise holen (am Auktionshaus) |
| `/bf bar` | kleine Leiste ein- oder ausblenden |
| `/bf lang de\|en\|auto` | Sprache wechseln |
| `/bf probe` | Client-Mods prüfen |

Alt+Klick auf ein Item in der Tasche legt es auf die im Fenster gewählte Liste.

## Lizenz

MIT, siehe `LICENSE`. Die Händlerwerte in `VendorData.lua` stammen aus ShaguTweaks (MIT, Copyright 2021 Eric Mauser), der Lizenztext steht in der Datei.

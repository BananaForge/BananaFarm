<p align="center">
  <img src="Media/Logo.png" alt="BananaFarm" width="300">
</p>

# BananaFarm

Lasher-Farmhilfe für Düsterbruch Ost auf OctoWoW (Vanilla 1.12, SuperWoW und Nampower). Teil von [BananaForge](https://github.com/BananaForge).

*Lasher farm helper for Dire Maul East on OctoWoW (Vanilla 1.12). German and English, switch with `/bf lang de|en|auto`.*

Version 0.4.1

## Erste Schritte

1. **Einrichten:** Beim ersten Start wählst du die Module, die du nutzen willst. Danach trägst du deinen Twink (Bankalt) und deine Mailchars ein, beides lässt sich überspringen.
2. **Session starten:** Knopf in der kleinen Leiste oder im Fenster (`/bf`). Ab jetzt zählt BananaFarm Zeit, Beute, Gold pro Stunde und Resets.
3. **Farmen:** Neue Items sortiert das Addon selbst ein. Hat ein Item keinen AH-Preis, fragt ein kleines Pop-up, wohin es soll.
4. **Händler oder Briefkasten öffnen:** Die Vendorliste wird verkauft, die Mailliste geht nach einer Abfrage an den Bankalt.

Alles Weitere steht im Fenster unter **Einstellungen**. Fährst du mit der Maus über eine Option, erscheint eine Erklärung.

## Funktionen

### Session und Gold pro Stunde
- Start/Stopp in der Leiste oder im Hauptfenster. Die Leiste zeigt Gold im Run (seit dem letzten Reset), in der Session und pro Stunde, darunter Dauer, Resets und Pulls.
- Jedes Item zählt genau einmal, beim Looten: mit Händlerwert, auf der Mailliste mit AH-Preis. Gold aus Verkäufen wird nicht noch einmal gezählt.
- Kurze Offline-Zeit beim Relog für den Reset zählt mit, damit Gold pro Stunde der echten Zeit entspricht (Pausen über 15 Minuten nicht).
- Reparaturkosten am Händler (z. B. Repairbot) werden vom Wert abgezogen.
- Entzaubern: Das entzauberte Item fällt aus der Statistik, die Mats zählen mit AH-Preis.
- Warnung, wenn die Taschen fast voll sind.

### Listen und Sortierung
- Fünf Listen: **Vendor** (wird verkauft), **Mail** (geht an den Bankalt), **Nie anfassen** (wird nie verkauft oder verschickt), **Behalten** (nur während der Session geschützt), **Unsortiert** (noch keine Entscheidung).
- Standardregel: AH-Preis mindestens x-mal Händlerwert (Standard 1,5) und über dem Mindestpreis: Mail, sonst Vendor. Graue Items gehen auf Vendor. Von Hand zugeordnet schlägt immer die Automatik.
- Alt+Klick auf ein Item in der Tasche öffnet die Auswahl der Listen. In der Liste verschieben farbige Knöpfe ein Item.
- AH-Scan am Auktionshaus: gezielte Suche nach den bekannten Items, voller Marktpreis.

### Händler
- Beim Öffnen eines Händlers wird die Vendorliste automatisch verkauft.
- **Preisprüfung:** Jedes Item wird beim ersten Verkauf einmal allein verkauft. BananaFarm vergleicht das erhaltene Gold mit der Händlertabelle und nutzt ab dann den echten Preis von OctoWoW. Abweichungen zeigt `/bf prices`.
- **Verkaufsschutz:** Während einer Session lässt sich von Hand nur verkaufen, was auf der Vendorliste steht. Alt+Rechtsklick verkauft trotzdem.

### Post
- Am Briefkasten fragt BananaFarm nach und schickt die Mailliste an den Bankalt.
- **Paketversand:** Mehrere Stapel gehen in einen Brief, sortiert nach Empfänger und Item. Klappt das auf einem Client nicht (z. B. mit TurtleMail), schickt BananaFarm automatisch einzeln weiter.
- Mehrere Mailziele: Jedem Item auf der Mailliste lässt sich ein eigener Empfänger zuordnen.

### Resets
- Instanz-Resets werden erkannt und mit Uhrzeit gespeichert, das übersteht Relog und Charwechsel.
- Die Leiste zeigt `n/5` und einen Countdown, bis der älteste Reset aus der Stunde fällt. Das Limit ist einstellbar.
- Auf dem Twink setzt der Knopf **Inst. Reset** die Instanz zurück.

### Pull-Zähler und Hunter-Modus (braucht SuperWoW)
- Zählt die Mobs, die gerade mit dir oder deinem Pet kämpfen. Mit Namensplaketten (Taste V) zählen auch Mobs, die nur hinterherlaufen.
- **Hunter-Modus** (für Jäger automatisch an): Leichen zählen mit, und an der Grenze (Standard 80) kommt eine Warnung.

### Sync mit dem Twink
- Listen, AH-Preise und Resets werden mit dem Twink abgeglichen. Den Twink trägst du nur auf dem Farmchar ein, die Kopplung läuft automatisch. Beide müssen in einer Gruppe sein.

### Speedrun
- Rundenstoppuhr in der Leiste, unabhängig von der Session. Rundenzeiten, Bestzeit, Blockzeit je Session und Posten in den Chat im Reiter Speedrun.

### Wunschliste
- Item per Shift-Klick aufnehmen, je Mob Name und Droprate eintragen. BananaFarm zählt die Kills und zeigt die Chance bisher und wie viele Kills noch fehlen.

### Unterstützen
- Im Spendenfenster (`/bf donate` oder Einstellungen) kannst du eine einmalige Spende oder ein Spenden-Abo (pro Session oder pro Runde) vormerken. Verschickt wird erst am Briefkasten nach deiner Bestätigung, höchstens 100g pro Brief. Spendenziel ist Bareg auf N'Zoth.

## Installation

**Octo Launcher:** Dieses Repository als Addon hinzufügen: `https://github.com/BananaForge/BananaFarm`

**Von Hand:** [ZIP herunterladen](https://github.com/BananaForge/BananaFarm/archive/refs/heads/main.zip), entpacken und den Ordner in `BananaFarm` umbenennen (GitHub hängt `-main` an). Dann nach `Interface/AddOns/` kopieren.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/bf` | Fenster öffnen oder schließen |
| `/bf start`, `/bf stop` | Farm-Session starten oder beenden |
| `/bf alt Name` | Twink (Bankalt) festlegen und koppeln |
| `/bf mail` | Mailliste am Briefkasten verschicken |
| `/bf sell` | Vendorliste beim Händler verkaufen |
| `/bf prices` | Ergebnis der Preisprüfung (`/bf prices reset`: neu prüfen) |
| `/bf reset` | Instanzen zurücksetzen (wird mitgezählt) |
| `/bf sync` | Abgleich mit dem Twink starten |
| `/bf wish Item` | Wunschitem hinzufügen (Link per Shift-Klick einfügen) |
| `/bf scan` | AH-Preise holen (am Auktionshaus) |
| `/bf bar` | kleine Leiste ein- oder ausblenden (auch per Tastenbelegung) |
| `/bf donate` | Spendenfenster öffnen |
| `/bf lang de\|en\|auto` | Sprache wechseln |
| `/bf probe` | Client-Mods prüfen (für die Entwickler) |

## Lizenz

MIT, siehe `LICENSE`. Die Händlerwerte in `VendorData.lua` stammen aus ShaguTweaks (MIT, Copyright 2021 Eric Mauser), der Lizenztext steht in der Datei.

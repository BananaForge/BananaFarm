# BananaFarm 0.3.0: Testliste

Fehler bitte im Wortlaut notieren (Chatzeilen, Lua-Fehler mit Dateiname und Zeile). Für den Sync braucht es beide Clients in einer Gruppe. Auf beiden Chars das Addon installieren (Ordner `BananaFarm`) und `/reload`.

## Probe
- [ ] Tote Leiche anvisieren, `/bf probe`, ganzen Fenstertext kopieren.
- [ ] Nach `/reload`: `WTF/Account/<Name>/SavedVariables/BananaFarm.lua` hochladen.

## Mail (TurtleMail)
- [ ] Einige Items auf der Mailliste, Briefkasten öffnen, Versand bestätigen: kommen Briefe beim Bankalt an?
- [ ] Gleicher Test mit vielen Items (10+): kommen alle an, einer nach dem anderen? Betreff der Briefe = Itemname (kein "bitte")?
- [ ] Falls ein Brief scheitert: Zeile "-> ..." unter der roten Meldung notieren (Grund des Spiels).
- [ ] Erscheint "Der Client hat den Anhang nicht angenommen" noch? Wenn ja, Text und welches Item.

## Session, Gold und Relog
- [ ] Start: zeigt Zeile 1 `Dauer  Gold/h` und Zeile 2 `Run: Wert  Resets n/5`?
- [ ] Mit laufender Session ausloggen und wieder einloggen: Dauer, Run-Wert und Gold/h bleiben plausibel (kein Sprung)?
- [ ] Gleicher Test mit `/reload`.
- [ ] Zonenwechsel (Instanz betreten/verlassen): kein Sprung beim Wert?

## Resets
- [ ] Instanz zurücksetzen: Chatzeile "Reset gezählt: 1/5"? Zähler und Timer in der Leiste?
- [ ] Mehrere Resets: Zähler steigt, bei 5/5 rot.
- [ ] Relog: Zähler und Timer laufen weiter?
- [ ] Wenn nichts gezählt wird: genauen Wortlaut der System-Chatzeile beim Reset notieren.

## Liste Behalten
- [ ] Item per Taste "K" in der Liste oder Alt+Klick (Tab Behalten gewählt) zuordnen.
- [ ] Session läuft: beim Händler wird das K-Item nicht verkauft, am Briefkasten nicht gemailt.
- [ ] Session gestoppt: K-Item folgt der Standardregel (z. B. graues Item wird verkauft).
- [ ] Einstellung "Liste Behalten nur während der Session schützen" ausschalten: Verhalten wie ohne Schutz?
- [ ] Sieht das Fenster mit 5 Tabs und 5 Knöpfen je Zeile sauber aus (keine Überlappung)? Bitte Screenshot.

## Sync
- [ ] Auf dem Bankalt in den Einstellungen "Sync-Partner" = Farmername eintragen. Auf dem Farmchar steht der Bankalt bereits (`/bf alt Name`).
- [ ] Beide in einer Gruppe: `/bf sync` auf einem Char. Kommt "Sync mit ...: x Listeneinträge, y Preise, z Resets übernommen"?
- [ ] Bankalt scannt das AH (`/bf scan`), danach `/bf sync` auf dem Farmchar: sind die Preise da, wechseln Items zwischen Vendor und Mail?
- [ ] Eine Liste auf dem Farmchar ändern, ausloggen (`/camp`), auf dem Bankalt prüfen: ist die Änderung angekommen?
- [ ] Login des Farmchars bei laufendem Bankalt: Abgleich nach etwa 10 s?
- [ ] Partner nicht in der Gruppe: erscheint die Meldung, und passiert der Abgleich später automatisch beim Gruppenbeitritt?
- [ ] Itemnamen auf dem Bankalt: Zeigen Items, die nur der Main kannte (vorher `#id`), nach einigen Sekunden Name und Icon? Bleiben welche bei `#id`? Dann bitte die IDs notieren.
- [ ] Nach einem Reset auf dem Farmchar und Relog: stimmen Zähler und Timer (über den Sync)?

## Verkaufsschutz (neu aus 0.2.0)
- [ ] Session läuft: Rechtsklick beim Händler auf ein Item, das nicht auf der Vendorliste steht. Kommt die Chatzeile "geschützt", bleibt das Item in der Tasche?
- [ ] Alt+Rechtsklick verkauft trotzdem?
- [ ] Session gestoppt: normaler Verkauf von Hand möglich?

## Run und Leiste (neu aus 0.2.0)
- [ ] Leiste Zeile 1 `Run  Session  g/h`, Zeile 2 `Dauer  Resets n/5 (Countdown)  Pulls`? Bitte Screenshot.
- [ ] Nach einem Reset: springt "Run" auf 0, "Session" läuft weiter?
- [ ] Sehen Fenster (480 x 600) und Einstellungen sauber aus, nichts abgeschnitten?

## Pull-Zähler und Hunter-Modus (neu aus 0.2.0)
- [ ] Erscheint "Pulls" in der Leiste? Passt die Zahl zu den gezogenen Mobs?
- [ ] Jäger: Anzeige `n/80`, zählen Leichen mit, kommt die Warnung an der Grenze?
- [ ] Anderer Char: nur die Zahl der Mobs im Kampf, fällt nach dem Kampf auf 0?

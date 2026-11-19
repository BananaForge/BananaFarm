# BananaFarm 0.4.0: Testliste

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
- [ ] Nur der Farmchar online, kein Twink: Instanz zurücksetzen, zählt und zeigt die Leiste den Reset? Chatzeile "Reset gezählt: 1/5"? Zähler und Timer in der Leiste?
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
- [ ] Kopplung (0.4.0): Beide in einer Gruppe. Nur auf dem Farmchar den Twink eintragen (Einstellungen oder `/bf alt Name`). Kommt am Twink "Gekoppelt mit ..." und am Farmchar "hat die Kopplung bestätigt"? Muss am Twink nichts eingetragen werden?
- [ ] Kopplung, Twink noch nicht in der Gruppe: Meldung am Farmchar, nach Gruppenbeitritt (ca. 5 s) koppeln sie sich selbst?
- [ ] Nach der Kopplung: Kommen Listen, Preise und Resets einmal automatisch zum Twink?
- [ ] AH-Scan am Twink mit Farmchar online in der Gruppe: Kommt vor dem Scan "hole die aktuellen Listen", beginnt der Scan danach (nach höchstens 8 s)? Nach dem Scan "Preise an ... geschickt", sind die Preise am Farmchar da?
- [ ] AH-Scan ohne Partner in der Gruppe: startet sofort, ohne Wartezeit?
- [ ] Neue Liste am Farmchar ändern, dann AH-Scan am Twink: ist die Änderung schon beim Scan berücksichtigt?
- [ ] `/bf sync` und Einstellungen: Die Zeile "Sync-Partner" ist weg, `/bf alt` heißt jetzt Twink (Bankalt).
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

## Module, Einrichtung, Icon, Keybind (neu in 0.4.0)
- [ ] Nach `/reload` erscheint das Einrichtungsfenster mit Logo und 7 Schaltern, alle an. Fertig und Escape schließen es, danach kommt es nicht wieder.
- [ ] Logo oben links im Hauptfenster sichtbar, Hintergrund transparent? Bitte Screenshot von Hauptfenster und Einrichtungsfenster.
- [ ] Hauptfenster: Reiter Listen, Einstellungen, Module sauber, Session-Zeile in der Titelzeile überdeckt nichts?
- [ ] Modul Item-Erkennung aus: Reiter Listen weg, kein Pop-up, kein AH-Scan, Session zählt nur Gold. Vendor und Mail zeigen aus.
- [ ] Modul Vendor aus: kein Auto-Verkauf beim Händler, Rechtsklick-Verkauf von Hand geht in der Session. Modul Mail aus: keine Nachfrage am Briefkasten.
- [ ] Modul Resets aus: Leiste ohne Resets, Reset wird nicht gezählt. Modul Pulls aus: keine Pull-Anzeige.
- [ ] Modul Sync aus: `/bf sync` meldet das ausgeschaltete Modul.
- [ ] Modul Tracking aus: Leiste weg. Keybind unter Optionen, Tastenbelegung, BananaFarm belegen: blendet die Leiste ein und aus?

## Entzaubern in der Goldstatistik (neu in 0.4.0)
- [ ] Session läuft, ein Item mit Wert finden (Run/Session steigen), dann entzaubern: Sinkt der Wert um den Itemwert, sobald das Item weg ist?
- [ ] Die Mats aus dem Loot-Fenster: Steigt der Wert um den AH-Preis der Mats (nach AH-Scan), ohne AH-Preis um den Händlerwert?
- [ ] Mit Autoloot und mit manuellem Looten testen. Bleibt der Wert in beiden Fällen richtig?
- [ ] Entzaubern abbrechen (Bewegen): bleibt der Wert unverändert, das Item in der Tasche?
- [ ] Item aus der Tasche entzaubern, das schon vor der Session da war: Wert sinkt nicht, nur die Mats kommen dazu?
- [ ] Wenn nichts abgezogen wird: Meldet das Spiel den Zauber als `SPELLCAST_START`? (Name des Zaubers im Chat-Log notieren, `/bf probe` hilft nicht dafür.)

## Mehrere Mailziele (neu in 0.4.0)
- [ ] Einstellungen: Zeile "Mailziele" mit z. B. `Bankone, Banktwo` füllen. Meldung im Chat, Feld zeigt die Namen sauber an?
- [ ] Reiter Listen, Mailliste: Spalte heißt "Ziel", jede Zeile zeigt ein Ziel? Linksklick schaltet vor, Rechtsklick zurück? Bitte Screenshot (Platz, Überlappung mit dem Itemnamen).
- [ ] Briefkasten öffnen: Die Nachfrage nennt alle Ziele und die Briefzahl. Gehen die Items an das jeweils zugeordnete Ziel (Briefe bei den Bankchars prüfen)?
- [ ] Mit TurtleMail und mehreren Items je Ziel: Alles angekommen, jeweils beim richtigen Char?
- [ ] Ohne eigene Ziele: Post geht wie bisher an den Twink. Zeile leeren, Meldung "Keine eigenen Mailziele mehr"?
- [ ] Ziel gleich dem eigenen Charakter: Items bleiben liegen, Meldung kommt?

## Leiste, Pull-Zähler, Speedrun (neu in 0.4.0)
- [ ] Leiste: Werden Run, Session und g/h jetzt vollständig angezeigt (auch mit Gold, Silber und Kupfer)? Bitte Screenshot mit allen drei Zeilen.
- [ ] Pull-Zähler: Außerhalb des Kampfes ist keine Pull-Anzeige da? Läuft sie im Kampf nur bei Mobs, die an dir oder dem Pet hängen, und nicht durch Kämpfe anderer Spieler in der Nähe?
- [ ] Pull-Zähler im Hunter-Modus: Zählen Leichen im Kampf weiter, und ist nach dem Kampf alles weg?
- [ ] Rundenstoppuhr: Start, Stopp (Chatzeile mit der Rundenzeit), Weiterlaufen, Reset. Läuft sie unabhängig von der Session-Uhr?
- [ ] Rundenstoppuhr bei `/reload`: Läuft sie weiter? Beim Ausloggen und Einloggen: Ist die Runde gespeichert und die Uhr auf 0?
- [ ] Reiter Speedrun: Zeigt er Statistik, Sessions und Runden ohne Überlappung? Bitte Screenshot.
- [ ] Block: Session mit 5 Resets, danach ausloggen. Steht die Session-Zeit in der Spalte Block? Wird sie nach erneutem Login und Logout ohne weiteren Reset aktualisiert?
- [ ] Posten: Kanal wechseln, letzte Runde, Beste und Block posten. Kommen die Zeilen im richtigen Kanal an? Meldung, wenn der Kanal nicht geht?
- [ ] Modul Speedrun ausschalten: Stoppuhr-Zeile, Reiter und Leiste schrumpfen auf zwei Zeilen?

## Wunschliste (neu in 0.4.0)
- [ ] Reiter Wünsche: Eingabefeld anklicken, dann Item per Shift-Klick aus der Tasche einfügen. Kommt es in die Liste? Dasselbe mit einem Chat-Link und mit AtlasLoot.
- [ ] Wenn Shift-Klick nicht klappt: `/bf wish` tippen, dann ein Item per Shift-Klick in den Chat einfügen und Enter. Klappt das?
- [ ] Nach dem Schließen des Feldes: Funktioniert das normale Chat-Fenster und Shift-Klick auf Items danach wieder wie vorher?
- [ ] Mob hinzufügen: Name genau wie im Spiel und Droprate je Mob eintragen (z. B. 1,5 und 0,8). Zählen die Kills je Mob live hoch? Stimmen Chance, schnellster Mob und Kills bis 90 % und 50 %? Entfernen per X und per leerem Namensfeld?
- [ ] Pull-Modul aus, Wunschliste an: Zählen die Kills trotzdem (mit SuperWoW)?
- [ ] Mehrfachkills (Multi-Shot, Pet): Wird jeder tote Mob aus deiner Pull-Zählung einmal gezählt, und bei dem Mob mit dem richtigen Namen?
- [ ] Item droppt: Chatzeile "Wunschitem erhalten", alle Mob-Kills auf 0, Anzahl erhalten und letzte Kills stehen da?
- [ ] Mehr als 5 Einträge: Blättert das Mausrad? Entfernen und Kills zurücksetzen gehen?
- [ ] Tabs: Passen alle fünf Reiter ins Fenster, ohne die Session-Zeile zu überdecken? Bitte Screenshot.

## Rückmeldungen und Ergänzungen (neu in 0.4.0)
- [ ] Leiste: Ist sie jetzt kompakter und passt sich der Textbreite an (auch mit Gold, Silber, Kupfer und laufender Stoppuhr)? Flackert die Breite? Bitte Screenshot.
- [ ] Hauptfenster: Kein Start-Knopf mehr, die Reiter sind frei, die Session-Zeile überdeckt den Untertitel nicht, die Versionsnummer sitzt unter dem X?
- [ ] Speedrun: Das X bei einer Runde und bei einer beendeten Session löscht sie? Beste Zeit und Leiste ändern sich mit? Die laufende Session hat kein X?
- [ ] Wunschliste: Der Spaltenkopf "Rate %" bricht nicht mehr um?
- [ ] Zuordnungs-Pop-up mit mindestens zwei Mailzielen: Der Mail-Knopf öffnet die Auswahl, ein Klick ordnet Item und Ziel zu (Mailliste zeigt das Ziel)? Mit nur einem Ziel wird gleich zugeordnet?
- [ ] AH-Scan: Zuerst die Items ohne Preis, dann Meldung "Neue Items fertig" mit Abgleich der Preise, danach die übrigen und am Ende wieder ein Abgleich (Twink in der Gruppe)? Werden unsortierte Items nach Phase 1 sofort einsortiert?
- [ ] Erste Einrichtung (bei einer neuen Datenbank oder nach Löschen von `setupDone`): Modulfenster, danach Pop-up Twink, danach Pop-up Mailchars? Bleiben die Felder in den Einstellungen leer, wenn du nichts einträgst oder überspringst? Greift ein eingetragener Twink (Kopplung) und stehen die Mailchars in den Einstellungen?

## Korrekturen nach den Screenshots vom 17.11. (neu in 0.4.0)
- [ ] Leiste: Hat die oberste Zeile jetzt oben so viel Abstand zum Rahmen wie die unterste nach unten?
- [ ] Speedrun: Das X bei einer Runde und bei einer beendeten Session löscht jetzt wirklich (Lua-5.0-Fehler behoben)? Auch bei mehreren Zeilen die richtige?
- [ ] Wunschliste: Mob hinzufügen, Name und Rate in die richtige Zeile eintragen, X entfernt die richtige Zeile (derselbe Fehler stand dort)?
- [ ] Zuordnungs-Pop-up mit mehreren Mailzielen: Ein Klick auf das zweite oder dritte Ziel ordnet genau dieses zu?
- [ ] Twink: Gibt es in der Leiste den Knopf "Inst. Reset", und fehlt er auf dem Farmchar? Setzt er die Instanzen zurück (als Gruppenleiter)? Passt die Leiste in der Breite?
- [ ] Twink resettet, Farmchar außerhalb der Instanz: Erscheint der Reset sofort beim Farmchar ("Reset durch den Partner", Resets 1/5, neuer Run), ohne `/bf sync`?
- [ ] Beide bekommen die Reset-Meldung des Spiels: Wird der Reset nicht doppelt gezählt?
- [ ] Gebietswechsel und Instanz betreten oder verlassen: Läuft danach ein Abgleich (Chatzeile nur, wenn sich etwas geändert hat)?

## 0.4.1: neu zu testen

### Gold pro Stunde
- [ ] Session läuft, ausloggen, 1 bis 2 Minuten warten, einloggen: Läuft die Dauer um die Offline-Zeit weiter (kein Sprung zurück, kein Stillstand)?
- [ ] Am Repairbot reparieren (Alles reparieren und einzelne Teile): Sinkt "Session" und "Run" um die Reparaturkosten?
- [ ] Etwas beim Händler kaufen: Ändert sich der Session-Wert NICHT?

### Preisprüfung
- [ ] Händler öffnen mit neuen Items auf der Vendorliste: Kommt die Chatzeile "Preisprüfung: x Items geprüft, y zahlt der Händler anders"? Bitte Wortlaut der Abweichungen notieren (Grays/Trash aus DM).
- [ ] `/bf prices`: zeigt alle Abweichungen. Stimmt die Spalte Händler in der Vendorliste danach mit dem Gold überein?
- [ ] Zweiter Händlerbesuch mit denselben Items: Verkauf wieder schnell (keine Pausen)?

### Paketversand
- [ ] Am Briefkasten mit mehreren Mail-Items: Chatzeile "Paketversand: bis zu n Stapel pro Brief"? Kommen beim Bankalt Briefe mit mehreren Anhängen an (Betreff: Itemname +n)?
- [ ] Falls "Paketversand klappt hier nicht, schicke einzeln weiter" erscheint: Kommen dann alle Items einzeln an? Bitte `/bf probe` (Abschnitt Post) schicken.

### Pull-Zähler
- [ ] Namensplaketten an (V), Hunter-Pull: Zählt der Zähler auch Mobs, die nur hinterherlaufen? Weicht die Zahl von der Wirklichkeit ab, um wie viel?
- [ ] `/bf probe` mit einem Mob im Ziel, der dich angreift: Abschnitt Namensplaketten schicken.

### Bedienung
- [ ] Einstellungen: Lassen sie sich mit Mausrad und Rollbalken bis ganz unten scrollen? Werden Abschnitte blass, wenn das Modul aus ist? Bitte Screenshot.
- [ ] Tooltips über jeder Option?
- [ ] Knopf "Session starten" rechts in der Reiterzeile: überlappt nichts?
- [ ] Listen: farbige Knöpfe, Beschreibungszeile, nichts überlappt (Händler- und AH-Spalte)?
- [ ] Mailliste mit zwei oder mehr Mailzielen: Klick auf das Ziel öffnet die Auswahl?
- [ ] Alt+Klick in der Tasche: Pop-up mit fünf Knöpfen (Vendor, Mail, Nie anfassen, Behalten, Abbrechen)?
- [ ] Einrichtung (Einstellungen, Einrichtung): Am Ende kommt "So funktioniert BananaFarm"?

### Spenden
- [ ] `/bf donate` auf N'Zoth: Fenster mit Einmalig und Abo. 1 Gold vormerken, Briefkasten öffnen: Abfrage "1g an Bareg spenden?" Bei Ja kommt der Brief bei Bareg an (Betreff "Spende für Addon-Entwicklung BananaFarm")?
- [ ] Abfrage mit Nein: Beim nächsten Briefkasten wird wieder gefragt?
- [ ] Abo pro Runde: Nach einem Reset steigt "Vorgemerkt" um den Betrag?
- [ ] Auf einem Char eines anderen Realms: Fenster zeigt nur den Namen zum Kopieren?

## 0.5.0: neu zu testen

### Spenden
- [ ] Auf einem anderen Char als Bareg (N'Zoth): zeigt das Fenster Einmalig und Abo? Unten steht "Erkannter Server: ...". Bitte den Text notieren.
- [ ] Auf Bareg: Hinweis "Du bist selbst der Spendenempfänger"?

### Sync
- [ ] Beide Clients in einer Gruppe, Farmchar einloggen: nach etwa 10 s Chatzeile "Sync mit ...: alles gleich" oder "... übernommen"?
- [ ] Item auf dem Farmchar von Hand zuordnen: ist es nach wenigen Sekunden beim Twink in derselben Liste?
- [ ] Neues Item farmen, das unsortiert bleibt: steht es beim Twink in Unsortiert (evtl. erst als #ID, dann mit Namen)?
- [ ] AH-Scan auf dem Twink: werden die unsortierten Items mitgescannt? Kommen die Preise beim Farmchar an?
- [ ] Falls etwas fehlt: `/bf sync status` auf beiden Chars (Prüfsummen vergleichen) und mit `/bf sync debug` den Ablauf mitschneiden.

### Unsortiert
- [ ] Knopf "Automatisch einsortieren": Items mit lohnendem AH-Preis auf Mail, sonst Vendor; Items ohne AH-Preis bleiben?
- [ ] Mit zwei oder mehr Mailchars: Abfrage je neuem Mail-Item?

### Speedrun
- [ ] Düsterbruch betreten: startet die Stoppuhr von selbst (Chatzeile)? Bitte den Zonennamen notieren, falls nicht.
- [ ] Instanz-Reset (auch durch den Twink): Runde gespeichert, Uhr auf 0? Leiste zeigt "Durchgang n/5"?
- [ ] Nach dem 5. Reset: Chatzeile "Durchgang fertig", Eintrag im Dashboard mit Gesamt- und Spielzeit?
- [ ] Reset-Knopf der Stoppuhr: laufende Zeit verworfen, nichts gespeichert?
- [ ] Dashboard: Kacheln, laufender Durchgang, Klick auf einen Durchgang zeigt die Runden. Bitte Screenshot.

### Lasher Championships
- [ ] In den Einstellungen anschalten (zwei Spieler in derselben Gilde): erscheinen beide in den Listen?
- [ ] Sortieren nach Durchgängen, Bestzeit, Gold; Gold nur mit Haken "Mein Gold zeigen"?
- [ ] Knopf "Wochensieger zeigen": Pop-up mit Podest-Icon und "Lasher Championships 2026". Am Sonntag kommt es von selbst (einmal).

## 0.6.0: neu zu testen

### Stoppuhr
- [ ] Session starten, Düsterbruch betreten: Leiste zeigt "Lap 1 0:01" in Gold?
- [ ] Ausloggen, Twink resettet, wieder einloggen: Nach etwa 10 bis 20 s ist Lap 1 mit der Zeit bis zum Reset gespeichert und Lap 2 läuft seit dem Reset (nicht seit dem Einloggen)?
- [ ] Twink resettet, während du online bist: Lap wechselt sofort?
- [ ] Nach dem 5. Reset: Chatzeile "Durchgang fertig", Leiste wartet aufs Portal, beim Betreten startet Lap 1 neu?
- [ ] Session stoppen: Abfrage mit Dauer und Wert; bei unvollständigem Durchgang der Hinweis, dass er gelöscht wird. Danach Durchgang weg, Laps weg?
- [ ] Knopf "Verwerfen" im Speedrun-Reiter.

### Einrichtung
- [ ] Neuer Char oder `BananaFarmDB.setupDone = nil` (/reload): erstes Fenster fragt nach der Sprache?

### Reset inst. (Twink)
- [ ] Klick: Wird die Instanz zurückgesetzt? Welche Chatzeile erscheint ("-> ...")? Falls "keine Antwort": `/bf probe`, Abschnitt "Instanz-Reset" schicken.

# BananaFarm: Entwicklungsnotizen

Zweck dieser Datei: In einem neuen Chat reichen das Addon (ZIP) und die Testergebnisse, damit nahtlos weitergearbeitet werden kann. Diese Datei bei jeder Änderung mitpflegen.

## Projekt

Lasher-Farmhilfe für Düsterbruch Ost auf OctoWoW (Vanilla 1.12, Lua 5.0). Teil von BananaForge. Zwei Clients gleichzeitig: Farmchar (Luminar/Bareg) und Bankalt in einer Hauptstadt. Beide sind normalerweise online und in derselben Gruppe.

Client laut Probe: 1.18.1 build 7272, enUS, Realm N'Zoth, SuperWoW 2.2, Nampower 4.6.2. Zusatzaddon bei jedem Spieler: TurtleMail.

## Arbeitsregeln des Nutzers (müssen eingehalten werden)

1. Information ist kein Auftrag. Kontext wird zur Kenntnis genommen, nicht eigenmächtig umgesetzt.
2. Fragen ("Geht das auch mit X?") werden nur beantwortet.
3. Änderungen am Code nur nach ausdrücklicher Aufforderung ("setz um", "bau ein", "go").
4. Größere Änderungen: erst kurz vorschlagen, auf Go warten.
5. Bei Unklarheit nachfragen statt raten.
6. Antworten knapp, keine ungefragten Zusatzleistungen.
7. Ordner, Dateien, MCP-Server nur anfassen, wenn der Auftrag sie nennt.
8. Godot-Regel (GDScript): keine Mehrfach-Spaces. Gilt hier nicht, BananaFarm ist Lua (Einrückung 2 Leerzeichen, wie im Bestand).
9. Kurzen Code inline im Chat ausgeben, keine Artifacts. Dateien (Addon) als Download.

## Lua-5.0-Regeln (Vanilla 1.12)

Kein `#`, kein `%`-Operator (stattdessen `BF.mod`), kein `string.match/gmatch`, kein `select`, keine `...`-Argumente. Script-Handler bekommen keine Parameter, `this`, `event`, `arg1..arg9` sind Globale. Kein `SetSize`, kein `SetColorTexture`. Timer über `BF:After(sek, fn, key)`, Ereignisse über `BF:On(event, fn)`.

## Dateien

| Datei | Inhalt |
| --- | --- |
| Core.lua | Tools, DB-Defaults, Timer, Ereignisse, Slash-Befehle |
| Locale.lua | DE/EN-Texte (`BF.T(key)`) |
| VendorData.lua | Händlerwerte (aus ShaguTweaks, MIT) |
| Prices.lua | AH-Scan, AH-Preise (`BF:AHNet`) |
| Lists.lua | Listen V (Vendor), M (Mail), I (Ignorieren), K (Behalten), U (Unsortiert), Sortierregel |
| Mail.lua | Versand an den Bankalt, inkl. TurtleMail-Pfad |
| Vendor.lua | Verkauf der Vendorliste beim Händler |
| Session.lua | Start/Stop, Snapshot, Wert, Gold/h |
| Resets.lua | Reset-Zähler und Stundentimer, Limit einstellbar, startet je Reset einen neuen Run |
| Pulls.lua | Pull-Zähler über SuperWoW-GUIDs, Hunter-Modus (neu, 0.2.0) |
| Sync.lua | Abgleich Listen, AH-Preise, Resets mit dem Partner (neu, 0.1.1) |
| Probe.lua | `/bf probe`: prüft SuperWoW/Nampower/Bindings |
| UI.lua | Fenster, Leiste, Pop-ups |

SavedVariables: `BananaFarmDB` (Felder in `Core.lua`, `BF:InitDB`).

## Erkenntnisse

- **TurtleMail und Briefversand:** TurtleMail ersetzt `PickupContainerItem` und `ClickSendMailItemButton`. Das Cursor-Item wird erst im nächsten Frame bekannt (`_cursorItem` zu `cursorItem` in `on_update`). Der bisherige Klick-Weg in Mail.lua scheiterte daher mit "Der Client hat den Anhang nicht angenommen". Lösung (0.1.1, ungetestet): `TurtleMail.sendmail_set_attachment({bag, slot})` direkt aufrufen, bis zu 21 Anhänge, danach `TurtleMail.send_mail_button_onclick()`. TurtleMail verschickt pro Anhang einen eigenen Brief (30c Porto je Brief); Erfolg wird pro `MAIL_SEND_SUCCESS` gezählt, die Charge ist fertig, wenn alle Briefe durch sind. **Testergebnis:** Bei Chargen mit mehreren Briefen ging nur der erste durch, danach kam `MAIL_FAILED` ("Brief konnte nicht gesendet werden"). Deshalb jetzt `BF.TM_BATCH = 1` (ein Brief je Durchgang, dazwischen 1 s). Ursache unklar; `Mail:Fail` zeigt jetzt die letzte `UI_ERROR_MESSAGE` des Spiels an. Außerdem las TurtleMail einen Betreffrest ("bitte") aus dem globalen `MailSubjectEditBox`, der jetzt geleert wird.
- **Probe (erste Ausführung):** `InteractUnit` ist nil. Vorhanden: `LootSlot`, `GetNumLootItems`, `CloseLoot`, `SetAutoloot`, `GetItemStats`, `UnitPosition`, `SpellInfo`, `GetUnitData`, `GetUnitField`, `GetSpellRec`, `CombatLogAdd`, `TrackUnit`, `UntrackUnit`, `ImportFile`, `ExportFile`. Der Rest der Ausgabe (Stichwortlisten) wurde noch nicht ausgewertet.
- **Relog-Bug Gold/h (behoben in 0.1.1, ungetestet):** Beim Laden waren Taschen und Gold noch leer. Der Snapshot war leer, die ganze Tasche zählte danach als Beute, und `t0` wurde ohne Sicherung der bisherigen Laufzeit überschrieben. Jetzt: Snapshot erst 3 s nach `PLAYER_ENTERING_WORLD`, Laufzeit wird bei `PLAYER_LOGOUT` gesichert.
- **Roter Lua-Fehler im Chat** (`api.lua:458: GameTooltip doesn't have a "OnTooltipSetItem"`): Quelle unbekannt, vermutlich ein anderes Addon (nicht TurtleMail). Vollständigen Pfad aus der Fehlermeldung nachreichen.

## Stand 0.3.0 (Zusammenführung von 0.1.1 und 0.2.0, ungetestet im Spiel)

0.1.1 (Bareg) und 0.2.0 (Luminar) sind beide aus 0.1.0 entstanden und wurden zusammengeführt. Zusätzlich zu den Punkten unter "Stand 0.1.1":

- **Verkaufsschutz:** Hook auf `UseContainerItem`. Läuft eine Session (Option `protect`), lässt sich beim Händler von Hand nur verkaufen, was laut `Lists:Eff` auf V steht. Alt gedrückt hebt den Schutz für den Klick auf.
- **Run und Session:** `db.session.run` zählt Beute und Gold seit dem letzten Reset. Leiste Zeile 1: Run, Session, g/h. Zeile 2: Dauer, Resets `n/Limit` mit Countdown, Pulls. Das ersetzt die zweizeilige Anzeige aus 0.1.1 (dort hieß der Session-Gesamtwert "Run:").
- **Resets:** Eine Datei aus beiden Ständen. Limit einstellbar (`resetLimit`), mehrere Meldungen binnen 3 s zählen als ein Reset, jeder Reset ruft `Session:NewRun`. `/bf reset` ruft `ResetInstances()`. `/bf sync` ist jetzt `HELP_11`.
- **Pull-Zähler (Pulls.lua):** GUIDs aus `RAW_COMBATLOG`, `UNIT_CASTEVENT`, Ziel und Mouseover; alle 0,5 s wird geprüft, was noch existiert und im Kampf ist. Hunter-Modus (`BF:HunterMode`, automatisch an für Jäger, je Char in `db.hunter` umstellbar): Leichen zählen mit, Warnung an der Grenze `pullLimit` (Standard 80). Ohne Probe-Auswertung gebaut, unbestätigt.
- **Fenster:** 480 x 600, 18 Zeilen, damit alle Einstellungen beider Stände Platz haben.

## Stand 0.1.1 (alles ungetestet im Spiel, Testliste: TESTLISTE.md)

- **Mail:** TurtleMail-Pfad (siehe Erkenntnisse).
- **Probe erweitert:** Stichwortlisten, alle Funktionsnamen in `BananaFarmDB.probeAll`, Tastenbelegungen, Slash-Befehle, Ziel-Check. Zum Auswerten: tote Leiche anvisieren, `/bf probe`, Fenstertext schicken und `WTF/Account/<Name>/SavedVariables/BananaFarm.lua` hochladen.
- **Session:** Relog-Fix. Anzeige zweizeilig (Leiste und Fensterzeile): Zeile 1 Dauer und Gold/h, Zeile 2 `Run:` Gesamtwert der Session (Beute plus Gold) und Resets.
- **Resets:** Zähler `n/5` und Timer bis der älteste Reset aus der Stunde fällt (rot bei 5/5). Zählung über die Systemmeldung `INSTANCE_RESET_SUCCESS`. Zeitstempel in `db.resets`.
- **Liste Behalten (K):** Vierte Ablageliste. Während einer laufenden Session (und bei aktiver Option `keepProtect`) wird ein K-Item weder verkauft noch gemailt. Außerhalb der Session entscheidet die Standardregel, als stünde es nicht auf K (`Lists:Eff`). Vendor, Mail und Session-Wert fragen `Lists:Eff` statt `Lists:Get`. "Ignorieren" (I) schützt weiterhin immer.
- **Sync (Sync.lua):** Abgleich mit dem Partner über Addon-Nachrichten (PARTY/RAID, Präfix `BFSYNC`). Der Partner ist `db.syncPeer`, ersatzweise `db.bankAlt`. Auf dem Bankalt den Namen des Mains in den Einstellungen unter "Sync-Partner" eintragen (oder `/bf sync Farmername`). Abgeglichen werden manuelle Listenzuordnungen (Zeitstempel je Item in `db.manualTs`), AH-Preise (`db.ah[id].ts`) und Resets (Vereinigung der Zeitstempel). Je Eintrag gewinnt der neuere Zeitstempel, ausgetauscht wird nur das Neue seit dem letzten Abgleich (`db.sync.last/since`, 2 Minuten Rand). Auslöser: 10 s nach Login (oder sobald der Partner in der Gruppe ist), vor dem Logout (Hook auf `Logout`, `Quit` und `PLAYER_LOGOUT`) und von Hand mit `/bf sync`. Option `autoSync` schaltet die automatischen Auslöser ab. Protokoll siehe Kopf von Sync.lua.
  - Noch nicht gesynct: Einstellungen, Session-Laufzeit und Session-Wert. Itemnamen werden nicht gesynct: Unbekannte Items fragt `BF:QueryItem` (Core.lua) beim Server ab (unsichtbarer Tooltip mit `item:ID`, höchstens 3 pro Schritt, 3 Versuche je ID). Bis die Antwort da ist, steht `#id` in der Liste.
  - Annahme: beide Clients haben vergleichbare Uhren (`time()`), der Rand von 2 Minuten fängt kleine Abweichungen ab.
  - Offen: `SendAddonMessage` für PARTY/RAID wird vom Client vorausgesetzt. Kein Test, ob der Server Nachrichten drosselt (Wartezeit 0,25 s je Paket).

## Offene Tests

Siehe TESTLISTE.md. Ergebnisse (auch Fehlermeldungen im Wortlaut) in den nächsten Chat mitbringen.

## Roadmap

1. Tests aus TESTLISTE.md auswerten und Fehler beheben.
2. Sync erweitern, falls gewünscht: Session-Laufzeit/Gold-h über den Partner stabil halten, Auto-Push nach einem AH-Scan des Bankalts, Itemnamen mitsenden.
3. **Loot** (zurückgestellt): Ein-Button-Loot hängt am Probe-Ergebnis, `InteractUnit` fehlt. Ersatz: Fast-Loot bei `LOOT_OPENED` (alle Slots nehmen, schließen). Pull-Zähler über GUID-Tracking (SuperWoW). Vorher Probe-Ergebnis (`probeAll`) auswerten.
4. Offen: zählt der Server das Limit über Resets oder über das Betreten neuer Instanzen? Aktuell werden Resets gezählt.

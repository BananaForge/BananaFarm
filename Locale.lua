-- BananaFarm Uebersetzungen (Deutsch / Englisch)
-- Umschaltung: /bf lang de | en | auto  (auto = Sprache des Clients)

local BF = BananaFarm
BF.L = {}

BF.L.deDE = {
  MSG_LOADED = "v%s geladen. /bf öffnet das Fenster, /bf help zeigt die Befehle.",
  MSG_LANGUAGE = "Sprache: Deutsch",
  MSG_ALT_SET = "Bankalt: %s",
  MSG_ALT_CLEARED = "Kein Bankalt mehr hinterlegt.",
  MSG_ASSIGNED = "%s steht jetzt auf: %s",
  MSG_RESORTED = "%d Items wurden nach den neuen Preisen umsortiert.",
  MSG_PROBE = "Probe fertig. Bitte den Text aus dem Fenster kopieren (Strg+A, Strg+C) und weitergeben.",

  MSG_SESSION_START = "Session gestartet. Neue Items werden automatisch einsortiert.",
  MSG_SESSION_STOP = "Session beendet. Dauer %s, Wert %s, pro Stunde %s",
  MSG_BAGS_FULL = "Taschen fast voll: noch %d Plätze frei.",

  MSG_SOLD = "%d Stapel (%d Items) verkauft für %s",
  MSG_NOSELL = "%s nimmt der Händler nicht. Wird nicht mehr angeboten, bis du es neu zuordnest.",
  ERR_NO_MERCHANT = "Öffne zuerst einen Händler.",

  MSG_MAIL_START = "Schicke %d Stapel an %s ...",
  MSG_MAIL_DONE = "%d Stapel in %d Briefen an %s verschickt.",
  MSG_MAIL_NOTHING = "Nichts von der Mailliste in den Taschen.",
  ASK_MAIL = "%d Stapel von der Mailliste an |cffffd100%s|r schicken?\n(%d Briefe, Porto %s)",
  ERR_NO_MAILBOX = "Öffne zuerst einen Briefkasten.",
  ERR_NO_ALT = "Kein Bankalt hinterlegt. In den Einstellungen eintragen oder /bf alt Name.",
  ERR_ALT_SELF = "Der Bankalt ist dieser Charakter. An sich selbst geht keine Post.",
  ERR_MAIL_CLOSED = "Briefkasten geschlossen, Versand abgebrochen.",
  ERR_NO_POSTAGE = "Nicht genug Geld für das Porto.",
  ERR_ATTACH_FAILED = "Der Client hat den Anhang nicht angenommen. Das Item liegt wieder in der Tasche. Bleibt es dabei, stört ein anderes Post-Addon.",
  ERR_MAIL_FAILED = "Brief konnte nicht gesendet werden. Name des Bankalts prüfen.",
  ERR_MAIL_TIMEOUT = "Der Server hat den Brief nicht bestätigt. Versand abgebrochen.",

  ERR_NO_AH = "Öffne zuerst das Auktionshaus.",
  MSG_AH_NOTHING = "Keine Items zum Suchen. Erst Items einsortieren oder eine Session starten.",
  MSG_AH_START = "AH-Scan gestartet: %d Items.",
  MSG_AH_ABORT = "AH-Scan abgebrochen.",
  MSG_AH_DONE = "AH-Scan fertig: %d Items gesucht, %d mit Preis, %d nicht gefunden (%d s).",

  HELP_1 = "/bf  Fenster öffnen oder schließen",
  HELP_2 = "/bf start | stop  Farm-Session starten oder beenden",
  HELP_3 = "/bf alt Name  Bankalt festlegen",
  HELP_4 = "/bf mail  Mailliste am Briefkasten verschicken",
  HELP_5 = "/bf sell  Vendorliste beim Händler verkaufen",
  HELP_6 = "/bf scan  AH-Preise holen (am Auktionshaus)",
  HELP_7 = "/bf bar  kleine Leiste ein- oder ausblenden",
  HELP_8 = "/bf lang de | en | auto  Sprache wechseln",
  HELP_9 = "/bf probe  Client-Mods prüfen (für Loot-Button und Pull-Zähler)",

  LIST_V = "Vendor",
  LIST_M = "Mail",
  LIST_I = "Ignorieren",
  LIST_U = "Unsortiert",

  TITLE_SUB = "Lasher-Farmhilfe",
  TAB_LISTS = "Listen",
  TAB_SETTINGS = "Einstellungen",
  COL_ITEM = "Item",
  COL_VENDOR = "Händler",
  COL_AH = "AH",
  HINT_ALT = "Alt+Klick auf ein Item in der Tasche legt es auf die gewählte Liste.",
  EMPTY_LIST = "Diese Liste ist leer.",
  BTN_SCAN = "AH-Scan",
  BTN_STOPSCAN = "Scan stoppen",
  SCAN_PROGRESS = "Scan: %d / %d",
  SCAN_IDLE = "Preise mit Scan: %d",
  BTN_START = "Start",
  BTN_STOP = "Stop",
  BTN_YES = "Ja",
  BTN_NO = "Nein",
  BTN_LATER = "Später",
  BTN_CLOSE = "Schließen",
  BTN_PROBE = "Probe ausführen",
  PROBE_TITLE = "BananaFarm Probe",

  SET_ALT = "Bankalt (Empfänger der Post)",
  SET_THRESHOLD = "Mailliste, wenn AH-Preis mindestens x-mal Händlerwert",
  SET_MINAH = "Mindest-AH-Preis pro Stück (in Silber)",
  SET_BAGWARN = "Warnung ab so wenigen freien Taschenplätzen (0 = aus)",
  SET_LANG = "Sprache",
  CHK_AHCUT = "AH-Preis abzüglich 5 % Gebühr rechnen",
  CHK_GRAY = "Graue Items automatisch auf die Vendorliste",
  CHK_POPUP = "Pop-up für neue Items ohne Zuordnung",
  CHK_AUTOSELL = "Beim Händler die Vendorliste automatisch verkaufen",
  CHK_MAILASK = "Am Briefkasten fragen, ob die Mailliste verschickt wird",
  CHK_ALTCLICK = "Alt+Klick in der Tasche ordnet Items zu",
  CHK_BAR = "Kleine Leiste anzeigen",

  ASSIGN_TITLE = "Neues Item: wohin damit?",
  ASSIGN_VALUES = "Händler: %s   AH: %s",
  ASSIGN_LEFT = "noch %d weitere",
  TT_MANUAL = "Von Hand zugeordnet",
  TT_AUTO = "Automatisch zugeordnet",
  TT_NOSELL = "Der Händler nimmt dieses Item nicht",
  TT_REMOVE = "Aus den Listen entfernen",
  TT_BAR = "Linksklick: Fenster öffnen. Ziehen: verschieben.",
  BAR_IDLE = "Keine Session",
  UNKNOWN = "-",
  NOT_IN_AH = "nicht im AH",
}

BF.L.enUS = {
  MSG_LOADED = "v%s loaded. /bf opens the window, /bf help lists the commands.",
  MSG_LANGUAGE = "Language: English",
  MSG_ALT_SET = "Bank alt: %s",
  MSG_ALT_CLEARED = "No bank alt set anymore.",
  MSG_ASSIGNED = "%s is now on: %s",
  MSG_RESORTED = "%d items were re-sorted using the new prices.",
  MSG_PROBE = "Probe done. Please copy the text from the window (Ctrl+A, Ctrl+C) and pass it on.",

  MSG_SESSION_START = "Session started. New items are sorted automatically.",
  MSG_SESSION_STOP = "Session ended. Duration %s, value %s, per hour %s",
  MSG_BAGS_FULL = "Bags almost full: %d slots left.",

  MSG_SOLD = "Sold %d stacks (%d items) for %s",
  MSG_NOSELL = "The vendor does not take %s. It will not be offered again until you reassign it.",
  ERR_NO_MERCHANT = "Open a vendor first.",

  MSG_MAIL_START = "Sending %d stacks to %s ...",
  MSG_MAIL_DONE = "Sent %d stacks in %d mails to %s.",
  MSG_MAIL_NOTHING = "Nothing from the mail list in your bags.",
  ASK_MAIL = "Send %d stacks from the mail list to |cffffd100%s|r?\n(%d mails, postage %s)",
  ERR_NO_MAILBOX = "Open a mailbox first.",
  ERR_NO_ALT = "No bank alt set. Enter one in the settings or use /bf alt Name.",
  ERR_ALT_SELF = "The bank alt is this character. You cannot mail yourself.",
  ERR_MAIL_CLOSED = "Mailbox closed, sending aborted.",
  ERR_NO_POSTAGE = "Not enough money for postage.",
  ERR_ATTACH_FAILED = "The client did not take the attachment. The item is back in your bag. If it keeps failing, another mail addon is in the way.",
  ERR_MAIL_FAILED = "Mail could not be sent. Check the bank alt's name.",
  ERR_MAIL_TIMEOUT = "The server did not confirm the mail. Sending aborted.",

  ERR_NO_AH = "Open the auction house first.",
  MSG_AH_NOTHING = "No items to look up. Sort some items or start a session first.",
  MSG_AH_START = "AH scan started: %d items.",
  MSG_AH_ABORT = "AH scan aborted.",
  MSG_AH_DONE = "AH scan done: %d items searched, %d priced, %d not found (%d s).",

  HELP_1 = "/bf  open or close the window",
  HELP_2 = "/bf start | stop  start or end a farm session",
  HELP_3 = "/bf alt Name  set the bank alt",
  HELP_4 = "/bf mail  send the mail list at a mailbox",
  HELP_5 = "/bf sell  sell the vendor list at a vendor",
  HELP_6 = "/bf scan  fetch AH prices (at the auction house)",
  HELP_7 = "/bf bar  show or hide the small bar",
  HELP_8 = "/bf lang de | en | auto  switch language",
  HELP_9 = "/bf probe  check client mods (for loot button and pull counter)",

  LIST_V = "Vendor",
  LIST_M = "Mail",
  LIST_I = "Ignore",
  LIST_U = "Unsorted",

  TITLE_SUB = "Lasher farm helper",
  TAB_LISTS = "Lists",
  TAB_SETTINGS = "Settings",
  COL_ITEM = "Item",
  COL_VENDOR = "Vendor",
  COL_AH = "AH",
  HINT_ALT = "Alt+click an item in your bags to put it on the selected list.",
  EMPTY_LIST = "This list is empty.",
  BTN_SCAN = "AH scan",
  BTN_STOPSCAN = "Stop scan",
  SCAN_PROGRESS = "Scan: %d / %d",
  SCAN_IDLE = "Scanned prices: %d",
  BTN_START = "Start",
  BTN_STOP = "Stop",
  BTN_YES = "Yes",
  BTN_NO = "No",
  BTN_LATER = "Later",
  BTN_CLOSE = "Close",
  BTN_PROBE = "Run probe",
  PROBE_TITLE = "BananaFarm probe",

  SET_ALT = "Bank alt (mail recipient)",
  SET_THRESHOLD = "Mail list if AH price is at least x times vendor value",
  SET_MINAH = "Minimum AH price per item (in silver)",
  SET_BAGWARN = "Warn at this many free bag slots or fewer (0 = off)",
  SET_LANG = "Language",
  CHK_AHCUT = "Calculate AH price minus 5 % fee",
  CHK_GRAY = "Put gray items on the vendor list automatically",
  CHK_POPUP = "Pop-up for new items without assignment",
  CHK_AUTOSELL = "Sell the vendor list automatically at a vendor",
  CHK_MAILASK = "Ask at the mailbox whether to send the mail list",
  CHK_ALTCLICK = "Alt+click in bags assigns items",
  CHK_BAR = "Show the small bar",

  ASSIGN_TITLE = "New item: where should it go?",
  ASSIGN_VALUES = "Vendor: %s   AH: %s",
  ASSIGN_LEFT = "%d more waiting",
  TT_MANUAL = "Assigned by hand",
  TT_AUTO = "Assigned automatically",
  TT_NOSELL = "The vendor does not take this item",
  TT_REMOVE = "Remove from the lists",
  TT_BAR = "Left-click: open window. Drag: move.",
  BAR_IDLE = "No session",
  UNKNOWN = "-",
  NOT_IN_AH = "not in AH",
}

function BF.Lang()
  local l = BananaFarmDB and BananaFarmDB.lang
  if l == "de" then return "deDE" end
  if l == "en" then return "enUS" end
  if GetLocale() == "deDE" then return "deDE" end
  return "enUS"
end

function BF.T(key)
  local t = BF.L[BF.Lang()]
  return t[key] or BF.L.enUS[key] or key
end

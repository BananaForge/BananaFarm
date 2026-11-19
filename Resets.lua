-- BananaFarm Resets: zaehlt Instanz-Resets (System-Meldung) und zeigt, wann die Stunde rum ist.
-- Gespeichert werden Zeitstempel (time()), daher laeuft der Timer ueber Relog und /reload weiter.
-- Das Limit pro Stunde ist einstellbar (Standard 5). Ein Reset beginnt in der Session einen neuen Run.
-- Der Sync gleicht die Zeitstempel mit dem Partner ab (Resets:Merge).

local BF = BananaFarm
local getn = table.getn

BF.Resets = { WINDOW = 3600 }
local R = BF.Resets

-- alles, was aelter als eine Stunde ist, faellt raus; Rest aufsteigend sortiert
function R:Prune()
  local db = BananaFarmDB
  db.resets = db.resets or {}
  local now = time()
  local keep = {}
  for i = 1, getn(db.resets) do
    local t = db.resets[i]
    if type(t) == "number" and now - t < self.WINDOW then table.insert(keep, t) end
  end
  table.sort(keep)
  db.resets = keep
  return keep
end

function R:Count()
  return getn(self:Prune())
end

-- Sekunden, bis der aelteste Reset aus der Stunde faellt (nil: keine Resets gezaehlt)
function R:Remaining()
  local l = self:Prune()
  if getn(l) == 0 then return nil end
  local rem = l[1] + self.WINDOW - time()
  if rem < 0 then rem = 0 end
  return rem
end

function R:Limit()
  local l = BananaFarmDB.resetLimit
  if type(l) ~= "number" or l < 1 then return 5 end
  return l
end

-- Zeitstempel vom Sync-Partner uebernehmen. true, wenn er neu war.
-- Zeiten, die nur wenige Sekunden auseinanderliegen, sind derselbe Reset (Uhren und Meldungen
-- laufen nicht auf die Sekunde gleich).
function R:Merge(ts)
  local l = self:Prune()
  if type(ts) ~= "number" or time() - ts >= self.WINDOW then return false end
  for i = 1, getn(l) do
    if math.abs(l[i] - ts) <= 5 then return false end
  end
  table.insert(l, ts)
  table.sort(l)
  return true
end

function R:Add()
  if not BF:Enabled("resets") then return end
  -- mehrere Meldungen auf einmal (mehrere Instanzen) sind ein Reset
  local now = GetTime()
  if self.last and now - self.last < 3 then return end
  self.last = now
  -- hat der Partner diesen Reset schon gemeldet (Sync), zaehlt er nicht doppelt
  local l = self:Prune()
  for i = 1, getn(l) do
    if math.abs(l[i] - time()) <= 5 then return end
  end
  local ts = time()
  table.insert(l, ts)
  if BF.Sync then BF.Sync:AfterReset(ts) end
  local n, limit = self:Count(), self:Limit()
  BF:Print(string.format(BF.T("MSG_RESET"), n, limit))
  if n >= limit then BF:Error(BF.T("MSG_RESET_LIMIT")) end
  BF.Session:NewRun()
  -- Speedrun: Runde endet mit dem Reset, Stoppuhr auf 0
  if BF.Speedrun then BF.Speedrun:OnResetAt(ts) end
  if BF.UI then BF.UI:Refresh() end
end

-- Reset, den der Sync-Partner gemeldet hat (er hat die Instanz zurueckgesetzt): zaehlt wie ein
-- eigener Reset und beginnt in der Session einen neuen Run.
-- Liefert true, wenn der Reset neu war. Kommt auch aus dem Sync beim Einloggen (Reset des Twinks,
-- waehrend man ausgeloggt war): dann zaehlt er rueckwirkend zur Reset-Uhrzeit.
function R:Remote(ts)
  if not BF:Enabled("resets") or type(ts) ~= "number" then return false end
  if not self:Merge(ts) then return false end
  local n, limit = self:Count(), self:Limit()
  BF:Print(string.format(BF.T("MSG_RESET_PARTNER"), n, limit))
  if n >= limit then BF:Error(BF.T("MSG_RESET_LIMIT")) end
  -- nur Resets nach dem Start der Session beginnen dort einen neuen Run
  if BF.Session:Running() and ts >= (BananaFarmDB.session.date or 0) then BF.Session:NewRun() end
  -- Speedrun: Lap endet zur Reset-Uhrzeit, die naechste beginnt im selben Moment
  if BF.Speedrun then BF.Speedrun:OnResetAt(ts) end
  if BF.UI then BF.UI:Refresh() end
  return true
end

-- Muster aus der Client-Meldung "%s has been reset." (je Sprache anders) bauen
local patterns = {}
local function addPattern(g)
  if type(g) ~= "string" then return end
  local p = string.gsub(g, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  p = string.gsub(p, "%%s", ".+")
  table.insert(patterns, "^" .. p .. "$")
end
addPattern(INSTANCE_RESET_SUCCESS)
if getn(patterns) == 0 then
  table.insert(patterns, "^.+ has been reset%.$")
  table.insert(patterns, "^.+ wurde zur.+gesetzt%.$")
end

BF:On("CHAT_MSG_SYSTEM", function(msg)
  if type(msg) ~= "string" then return end
  for i = 1, getn(patterns) do
    if string.find(msg, patterns[i]) then
      R.answer = msg
      R:Add()
      return
    end
  end
end)

-- /bf reset
-- Knopf "Reset inst." (Twink) und /bf reset. Auf OctoWoW tat der direkte Aufruf von
-- ResetInstances() nichts, der Rechtsklick aufs eigene Portraet aber schon. Deshalb denselben Weg
-- wie das Portraet-Menue gehen: erst dessen Bestaetigungsdialog, dann den Menue-Eintrag
-- nachspielen, zuletzt der direkte Aufruf. Danach 3 s auf eine Antwort warten und sie zeigen.
function R:Do()
  if GetNumPartyMembers() > 0 and IsPartyLeader and not IsPartyLeader() then
    BF:Error(BF.T("ERR_RESET_LEADER"))
    return
  end
  self.asked = GetTime()
  self.answer = nil
  local way
  local dlg = StaticPopupDialogs and StaticPopupDialogs["CONFIRM_RESET_INSTANCES"]
  if dlg and type(dlg.OnAccept) == "function" and pcall(dlg.OnAccept) then
    way = "dialog"
  elseif UnitPopup_OnClick and UnitPopupButtons and UnitPopupButtons["RESET_INSTANCES"] then
    -- Menue-Eintrag "Instanzen zuruecksetzen" am eigenen Portraet nachspielen
    local oldThis, oldMenu = this, UIDROPDOWNMENU_INIT_MENU
    this = { value = "RESET_INSTANCES" }
    UIDROPDOWNMENU_INIT_MENU = "PlayerFrameDropDown"
    if PlayerFrameDropDown then PlayerFrameDropDown.unit = "player" end
    if pcall(UnitPopup_OnClick) then way = "menu" end
    this, UIDROPDOWNMENU_INIT_MENU = oldThis, oldMenu
  end
  if not way then
    if not ResetInstances then
      BF:Print(BF.T("ERR_NO_RESET"))
      return
    end
    ResetInstances()
    way = "direct"
  end
  self.way = way
  BF:After(3, function()
    if R.answer then return end
    BF:Error(string.format(BF.T("MSG_RESET_NOANSWER"), R.way or "?"))
  end, "resetanswer")
end

-- Antwort des Servers auf den Knopf: Fehlermeldung (rot) oder Systemzeile
BF:On("UI_ERROR_MESSAGE", function(msg)
  if R.asked and GetTime() - R.asked < 3 and not R.answer then
    R.answer = msg
    BF:Error("-> " .. tostring(msg))
  end
end)

-- Systemzeile kurz nach dem Knopf (z. B. "Spieler noch in der Instanz") als Antwort zeigen
BF:On("CHAT_MSG_SYSTEM", function(msg)
  if type(msg) ~= "string" or not R.asked or R.answer then return end
  if GetTime() - R.asked > 3 then return end
  R.answer = msg
  BF:Print("-> " .. msg)
end)

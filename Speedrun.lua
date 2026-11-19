-- BananaFarm Speedrun (0.6.0): Laps und Durchgaenge, vollautomatisch.
--
-- Lap = ein Instanz-Durchlauf. Gemessen wird echte Uhrzeit (time()), Ausloggen haelt nichts an.
--   Lap 1 startet beim Betreten von Duesterbruch / Dire Maul, wenn eine Session laeuft
--   (Option srAutoStart). Ist der Autostart aus, startet Lap 1 mit der Session.
--   Lap 2 bis 5 starten beim Instanz-Reset: Die laufende Lap endet genau zur Uhrzeit des Resets,
--   die naechste beginnt im selben Moment. Das gilt auch fuer Resets des Twinks, die erst beim
--   Einloggen per Sync ankommen (rueckwirkend zur Reset-Uhrzeit).
--   Nach dem letzten Reset (Reset-Limit, Standard 5) ist der Durchgang fertig. Die naechste Lap 1
--   startet wieder am Portal (ohne Autostart: direkt mit dem Reset).
--   Session-Stopp beendet die Uhr; ein unvollstaendiger Durchgang wird dabei automatisch geloescht.
-- Durchgang: Rundenzeiten, Spielzeit (Summe der Laps) und Gesamtzeit (Start Lap 1 bis Ende der
--   letzten Lap). Da Laps lueckenlos aneinanderliegen, sind beide meist gleich. Die Gesamtzeit
--   zaehlt fuer Bestzeiten und die Gilden-Bestenliste. Gold des Durchgangs aus der Session.

local BF = BananaFarm
local getn = table.getn
local floor = math.floor

BF.Speedrun = {}
local SR = BF.Speedrun

SR.CHANNELS = { "PARTY", "RAID", "GUILD", "SAY" }
local MAX_LAPS = 200
local MAX_HEATS = 200
-- Zonenname von Duesterbruch in den Client-Sprachen (fuer den Autostart)
local DM_ZONES = { ["dire maul"] = true, ["düsterbruch"] = true, ["hache-tripes"] = true, ["la masacre"] = true }

local function refresh()
  if BF.UI then BF.UI:Refresh() end
end

local function sr()
  local d = BananaFarmDB.speedrun
  d.heats = d.heats or {}
  d.heat = d.heat or { laps = {} }
  d.heat.laps = d.heat.laps or {}
  d.laps = d.laps or {}
  d.sw = d.sw or {}
  -- Stand vor 0.6.0 (Uhr mit Pausen und Durchlauf-Zaehler): einmal auf 0
  if d.v ~= 2 then
    d.v = 2
    d.sw = {}
    d.heat = { laps = {} }
  end
  return d
end

-- ------------------------------------------------------------
-- Stoppuhr
-- ------------------------------------------------------------
function SR:Running()
  return sr().sw.running and true or false
end

-- Zeit der laufenden Lap (Sekunden), 0 wenn keine laeuft
function SR:Elapsed()
  local sw = sr().sw
  if not sw.running or not sw.t0 then return 0 end
  local e = time() - sw.t0
  if e < 0 then e = 0 end
  return e
end

-- naechste Lap beginnen (at = Startzeitpunkt, Standard jetzt)
function SR:StartLap(at)
  if not BF:Enabled("speedrun") then return end
  local d = sr()
  local sw = d.sw
  if sw.running then return end
  at = at or time()
  if getn(d.heat.laps) == 0 then
    d.heat.start = at
    d.heat.gold0 = BF.Session:Running() and BF.Session:Value() or nil
  end
  sw.running = true
  sw.t0 = at
  refresh()
end

-- frueherer Name (Leiste/Befehle): Start von Hand
function SR:Start()
  self:StartLap()
end

-- laufende Lap zum Zeitpunkt "at" beenden und speichern. Liefert die Lap oder nil.
function SR:EndLap(at)
  local d = sr()
  local sw = d.sw
  if not sw.running or not sw.t0 then return nil end
  at = at or time()
  if at < sw.t0 then return nil end
  local lap = { t = at - sw.t0, at = at, start = sw.t0 }
  sw.running = false
  sw.t0 = nil
  table.insert(d.heat.laps, lap)
  table.insert(d.laps, lap)
  while getn(d.laps) > MAX_LAPS do table.remove(d.laps, 1) end
  BF:Print(string.format(BF.T("MSG_SR_LAP2"), getn(d.heat.laps), BF.Duration(lap.t)))
  return lap
end

-- Instanz-Reset zur Uhrzeit ts (eigener Reset, Partner online oder per Sync nach dem Einloggen)
function SR:OnResetAt(ts)
  if not BF:Enabled("speedrun") then return end
  ts = ts or time()
  local d = sr()
  if not d.sw.running or not d.sw.t0 or ts < d.sw.t0 then return end
  if not self:EndLap(ts) then return end
  if getn(d.heat.laps) >= BF.Resets:Limit() then
    self:CompleteHeat()
    -- ohne Autostart gibt es kein Portal-Signal: naechster Durchgang beginnt mit dem Reset
    if not BananaFarmDB.srAutoStart and BF.Session:Running() then self:StartLap(ts) end
  else
    self:StartLap(ts)
  end
  refresh()
end

-- unvollstaendigen Durchgang loeschen (auch seine Laps aus der Rundenliste)
function SR:DiscardHeat(quiet)
  local d = sr()
  local hl = d.heat.laps
  local n = getn(hl)
  for i = 1, n do
    for j = getn(d.laps), 1, -1 do
      if d.laps[j] == hl[i] then
        table.remove(d.laps, j)
        break
      end
    end
  end
  d.heat = { laps = {} }
  d.sw.running = false
  d.sw.t0 = nil
  if n > 0 and not quiet then BF:Print(string.format(BF.T("MSG_SR_DISCARDED"), n)) end
  refresh()
end

-- Session gestartet: ohne Autostart beginnt Lap 1 sofort
function SR:OnSessionStart()
  if not BF:Enabled("speedrun") or BananaFarmDB.srAutoStart then return end
  if self:Running() then return end
  self:StartLap()
  BF:Print(BF.T("MSG_SR_SESSIONSTART"))
end

-- Session beendet: Uhr aus, unvollstaendiger Durchgang wird geloescht
function SR:OnSessionStop()
  local d = sr()
  d.sw.running = false
  d.sw.t0 = nil
  if getn(d.heat.laps) > 0 and getn(d.heat.laps) < BF.Resets:Limit() then
    self:DiscardHeat()
  else
    d.heat = { laps = {} }
  end
  refresh()
end

-- Durchgang abschliessen
function SR:CompleteHeat()
  local d = sr()
  local h = d.heat
  local n = getn(h.laps)
  if n == 0 then return end
  local laps, play = {}, 0
  for i = 1, n do
    table.insert(laps, h.laps[i].t)
    play = play + h.laps[i].t
  end
  local done = h.laps[n].at
  local start = h.start or h.laps[1].start or (h.laps[1].at - h.laps[1].t)
  local total = done - start
  if total < play then total = play end
  local gold
  if h.gold0 and BF.Session:Running() then
    gold = BF.Session:Value() - h.gold0
    if gold < 0 then gold = 0 end
  end
  table.insert(d.heats, { at = done, start = start, laps = laps, play = play, total = total, gold = gold })
  while getn(d.heats) > MAX_HEATS do table.remove(d.heats, 1) end
  d.heat = { laps = {} }
  local best = self:BestHeat()
  local isBest = best and best.total == total
  BF:Print(string.format(BF.T("MSG_SR_HEAT"), n, BF.Duration(total), BF.Duration(play))
    .. (isBest and ("  |cff40ff40" .. BF.T("SR_NEWBEST") .. "|r") or ""))
  if BF.Champ then BF.Champ:OnHeat() end
end

-- nach dem Laden: nichts anzuhalten, die Lap laeuft nach Uhrzeit weiter
function SR:OnLoad()
  sr()
end

-- Lap 1 beim Betreten von Duesterbruch (Session laeuft, kein Durchgang offen)
function SR:CheckZone()
  if not BF.ready or not BF:Enabled("speedrun") or not BananaFarmDB.srAutoStart then return end
  if not BF.Session:Running() then return end
  if not IsInInstance or not IsInInstance() then return end
  local zone = string.lower((GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "")
  if not DM_ZONES[zone] then return end
  local d = sr()
  if d.sw.running or getn(d.heat.laps) > 0 then return end
  self:StartLap()
  BF:Print(BF.T("MSG_SR_AUTOSTART"))
end

BF:On("ZONE_CHANGED_NEW_AREA", function() BF:After(1, function() SR:CheckZone() end, "srzone") end)
BF:On("PLAYER_ENTERING_WORLD", function() BF:After(2, function() SR:CheckZone() end, "srzone") end)

-- frueher: Sessions fuer die Blockzeit archivieren (seit 0.5.0 ersetzt durch Durchgaenge)
function SR:ArchiveSession() end

-- ------------------------------------------------------------
-- Statistik
-- ------------------------------------------------------------
-- Anzahl, Beste, Schnitt, Letzte der gespeicherten Runden (Leiste)
function SR:LapStats()
  local laps = BananaFarmDB.speedrun.laps
  local n = getn(laps)
  if n == 0 then return 0 end
  local best, sum = nil, 0
  for i = 1, n do
    local t = laps[i].t
    sum = sum + t
    if not best or t < best then best = t end
  end
  return n, best, sum / n, laps[n].t
end

function SR:BestHeat()
  local best
  local hs = sr().heats
  for i = 1, getn(hs) do
    if not best or hs[i].total < best.total then best = hs[i] end
  end
  return best
end

-- Kennzahlen eines Zeitraums: von (Zeitpunkt) bis jetzt. Liefert Anzahl, Bestzeit, Gold (oder nil)
function SR:PeriodStats(from)
  local hs = sr().heats
  local n, best, gold = 0, nil, nil
  for i = 1, getn(hs) do
    local h = hs[i]
    if not from or h.at >= from then
      n = n + 1
      if not best or h.total < best then best = h.total end
      if h.gold then gold = (gold or 0) + h.gold end
    end
  end
  return n, best, gold
end

function SR:HeatAvg()
  local hs = sr().heats
  local n = getn(hs)
  if n == 0 then return nil end
  local s = 0
  for i = 1, n do s = s + hs[i].total end
  return s / n
end

-- Durchgang loeschen (e ist der Eintrag selbst)
function SR:DeleteHeat(e)
  local hs = sr().heats
  for i = 1, getn(hs) do
    if hs[i] == e then
      table.remove(hs, i)
      break
    end
  end
  if BF.Champ then BF.Champ:OnHeat(true) end
  refresh()
end

-- Beginn der Woche (Montag 0 Uhr) und des Monats fuer einen Zeitpunkt
function SR.WeekStart(t)
  t = t or time()
  local d = date("*t", t)
  local sinceMon = BF.mod(d.wday + 5, 7)
  return t - (d.hour * 3600 + d.min * 60 + d.sec) - sinceMon * 86400
end

function SR.MonthStart(t)
  t = t or time()
  local d = date("*t", t)
  return t - (d.hour * 3600 + d.min * 60 + d.sec) - (d.day - 1) * 86400
end

function SR.WeekKey(t) return date("%Y%m%d", SR.WeekStart(t)) end
function SR.MonthKey(t) return date("%Y%m", t or time()) end

-- ------------------------------------------------------------
-- Posten in den Chat
-- ------------------------------------------------------------
function SR:Channel()
  local c = BananaFarmDB.srChannel
  for i = 1, getn(self.CHANNELS) do
    if self.CHANNELS[i] == c then return c end
  end
  return "PARTY"
end

function SR:CycleChannel()
  local c = self:Channel()
  local idx = 1
  for i = 1, getn(self.CHANNELS) do
    if self.CHANNELS[i] == c then idx = i end
  end
  idx = idx + 1
  if idx > getn(self.CHANNELS) then idx = 1 end
  BananaFarmDB.srChannel = self.CHANNELS[idx]
end

function SR:ChannelOK(ch)
  if ch == "PARTY" then return GetNumPartyMembers() > 0 end
  if ch == "RAID" then return GetNumRaidMembers() > 0 end
  if ch == "GUILD" then return IsInGuild() and true or false end
  return true
end

-- kind: "last" (letzte Runde) | "best" (beste Runde) | "heat" (bester Durchgang)
function SR:Post(kind)
  local n, best, avg, last = self:LapStats()
  local text
  if kind == "heat" or kind == "block" then
    local h = self:BestHeat()
    if not h then
      BF:Print(BF.T("ERR_SR_NOTHING"))
      return
    end
    local parts = {}
    for i = 1, getn(h.laps) do table.insert(parts, BF.Duration(h.laps[i])) end
    text = string.format(BF.T("MSG_SR_POST_HEAT"), BF.Duration(h.total), getn(h.laps), table.concat(parts, " / "))
  elseif n == 0 then
    BF:Print(BF.T("ERR_SR_NOTHING"))
    return
  elseif kind == "best" then
    text = string.format(BF.T("MSG_SR_POST_BEST"), BF.Duration(best), n)
  else
    text = string.format(BF.T("MSG_SR_POST_LAST"), BF.Duration(last), BF.Duration(best), BF.Duration(avg), n)
  end
  local ch = self:Channel()
  if not self:ChannelOK(ch) then
    BF:Error(BF.T("ERR_SR_NOCHAN"))
    return
  end
  SendChatMessage(text, ch)
end

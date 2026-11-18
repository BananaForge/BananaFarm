-- BananaFarm Speedrun (0.5.0): Rundenstoppuhr, Runden und Durchgaenge.
--
-- Runde = ein Instanz-Durchlauf. Die Stoppuhr laeuft unabhaengig von der Session-Uhr.
--   Start: von Hand oder automatisch beim Betreten von Duesterbruch (Option srAutoStart, erkennt
--   "Dire Maul" und "Duesterbruch"). Ist der Autostart aus, startet die erste Runde zusammen mit
--   der Session (Session:Start), weitere Runden von Hand.
--   Ende (Runde wird gespeichert): Stopp-Knopf, Instanz-Reset (automatisch, auch wenn der Partner
--   resettet) oder Logout. Nach einem Instanz-Reset steht die Uhr wieder auf 0.
--   Reset-Knopf: verwirft die laufende Zeit, ohne zu speichern (Fehlstart).
--   /reload unterbricht nur (Luecke unter 90 s).
-- Durchgang = so viele Runden wie das Reset-Limit (Standard 5). Gespeichert werden die
--   Rundenzeiten, die Spielzeit (Summe der Runden) und die Gesamtzeit vom Start der ersten bis
--   zum Ende der letzten Runde, mit Reset-Pausen. Die Gesamtzeit zaehlt fuer Bestzeiten und die
--   Gilden-Bestenliste. Gold des Durchgangs aus der Session, falls sie lief.

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
  return d
end

-- ------------------------------------------------------------
-- Rundenstoppuhr
-- ------------------------------------------------------------
function SR:Running()
  return BananaFarmDB.speedrun.sw.running and true or false
end

function SR:Elapsed()
  local sw = BananaFarmDB.speedrun.sw
  local e = sw.elapsed or 0
  if sw.running and sw.t0 then e = e + (time() - sw.t0) end
  return e
end

-- Runde speichern (je Durchlauf der Uhr ein Eintrag; Stopp und Weiterlaufen ersetzt ihn)
function SR:SaveLap()
  local d = sr()
  local sw = d.sw
  local t = self:Elapsed()
  if t <= 0 then return nil end
  local laps = d.laps
  for i = getn(laps), 1, -1 do
    if laps[i].cyc == sw.cycle then
      table.remove(laps, i)
      break
    end
  end
  table.insert(laps, { t = t, at = time(), cyc = sw.cycle })
  while getn(laps) > MAX_LAPS do table.remove(laps, 1) end
  -- auch im laufenden Durchgang
  local hl = d.heat.laps
  for i = getn(hl), 1, -1 do
    if hl[i].cyc == sw.cycle then
      table.remove(hl, i)
      break
    end
  end
  table.insert(hl, { t = t, at = time(), cyc = sw.cycle })
  return t
end

function SR:Start()
  if not BF:Enabled("speedrun") then return end
  local d = sr()
  local sw = d.sw
  if sw.running then return end
  -- erste Runde eines Durchgangs: Startzeit und Goldstand merken
  if getn(d.heat.laps) == 0 and not d.heat.start then
    d.heat.start = time()
    if BF.Session:Running() then d.heat.gold0 = BF.Session:Value() end
  end
  sw.running = true
  sw.t0 = time()
  sw.seen = sw.t0
  sw.out = nil
  refresh()
end

function SR:Stop(silent)
  local sw = BananaFarmDB.speedrun.sw
  if not sw.running then return end
  sw.elapsed = self:Elapsed()
  sw.running = false
  sw.t0 = nil
  local t = self:SaveLap()
  if t and not silent then BF:Print(string.format(BF.T("MSG_SR_LAP"), BF.Duration(t))) end
  refresh()
end

-- naechste Runde: Uhr auf 0, Durchgang fertig, wenn genug Runden beisammen sind
function SR:NewCycle()
  local d = sr()
  local sw = d.sw
  sw.running = false
  sw.t0 = nil
  sw.elapsed = 0
  sw.cycle = (sw.cycle or 1) + 1
  if getn(d.heat.laps) >= BF.Resets:Limit() then self:CompleteHeat() end
  refresh()
end

-- Reset-Knopf: laufende Zeit verwerfen, nichts speichern
function SR:Reset()
  local sw = BananaFarmDB.speedrun.sw
  if sw.running and self:Elapsed() > 0 then BF:Print(BF.T("MSG_SR_DISCARD")) end
  self:NewCycle()
end

function SR:Toggle()
  if self:Running() then self:Stop() else self:Start() end
end

-- Instanz-Reset (eigener oder vom Partner): Runde beenden und Uhr auf 0
function SR:OnReset()
  if not BF:Enabled("speedrun") then return end
  local sw = BananaFarmDB.speedrun.sw
  if sw.running then
    self:Stop()
    self:NewCycle()
  elseif (sw.elapsed or 0) > 0 then
    self:NewCycle()
  end
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
  local start = h.start or (h.laps[1].at - h.laps[1].t)
  local total = done - start
  if total < play then total = play end
  local gold
  if h.gold0 and BF.Session:Running() then
    gold = BF.Session:Value() - h.gold0
    if gold < 0 then gold = 0 end
  end
  local e = { at = done, start = start, laps = laps, play = play, total = total, gold = gold }
  table.insert(d.heats, e)
  while getn(d.heats) > MAX_HEATS do table.remove(d.heats, 1) end
  d.heat = { laps = {} }
  local best = self:BestHeat()
  local isBest = best and best.total == total
  BF:Print(string.format(BF.T("MSG_SR_HEAT"), n, BF.Duration(total), BF.Duration(play))
    .. (isBest and ("  |cff40ff40" .. BF.T("SR_NEWBEST") .. "|r") or ""))
  if BF.Champ then BF.Champ:OnHeat() end
end

-- nach dem Laden: /reload unterbricht nur, Logout oder Absturz beendet die Runde
function SR:OnLoad()
  local d = sr()
  local sw = d.sw
  if not sw.running then return end
  local ref = sw.out or sw.seen or time()
  if time() - ref < 90 then
    sw.t0 = time()
    sw.out = nil
    return
  end
  local e = sw.elapsed or 0
  if sw.t0 then e = e + math.max(0, (sw.seen or sw.t0) - sw.t0) end
  sw.elapsed = e
  sw.running = false
  sw.t0 = nil
  sw.out = nil
  self:SaveLap()
  self:NewCycle()
end

BF:On("PLAYER_LOGOUT", function()
  if not BF:Enabled("speedrun") then return end
  local sw = BananaFarmDB.speedrun.sw
  if sw.running then
    sw.elapsed = SR:Elapsed()
    sw.t0 = nil
    sw.out = time()
  end
end)

-- Lebenszeichen alle 10 s, damit ein Absturz die Rundenzeit nicht verschluckt
local tick = CreateFrame("Frame")
tick.t = 0
tick:SetScript("OnUpdate", function()
  this.t = this.t + (arg1 or 0)
  if this.t < 10 then return end
  this.t = 0
  if not BF.ready then return end
  local sw = BananaFarmDB.speedrun.sw
  if sw.running then sw.seen = time() end
end)

-- Autostart beim Betreten von Duesterbruch (nur wenn die Uhr auf 0 steht)
function SR:CheckZone()
  if not BF.ready or not BF:Enabled("speedrun") or not BananaFarmDB.srAutoStart then return end
  if not IsInInstance or not IsInInstance() then return end
  local zone = string.lower((GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "")
  if not DM_ZONES[zone] then return end
  local sw = BananaFarmDB.speedrun.sw
  if sw.running or (sw.elapsed or 0) > 0 then return end
  self:Start()
  BF:Print(BF.T("MSG_SR_AUTOSTART"))
end

-- Autostart aus: die erste Runde startet zusammen mit der Session (wenn die Uhr auf 0 steht)
function SR:OnSessionStart()
  if not BF:Enabled("speedrun") or BananaFarmDB.srAutoStart then return end
  local sw = BananaFarmDB.speedrun.sw
  if sw.running or (sw.elapsed or 0) > 0 then return end
  self:Start()
  BF:Print(BF.T("MSG_SR_SESSIONSTART"))
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

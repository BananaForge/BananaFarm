-- BananaFarm Speedrun: Rundenstoppuhr, Rundenzeiten und Blockzeiten der Sessions.
--
-- Rundenstoppuhr: von Hand (Start, Stopp, Reset), unabhaengig von der Session-Uhr. Jeder Stopp
-- speichert die Zeit als Runde (nach Stopp und Weiterlaufen wird derselbe Eintrag aktualisiert,
-- solange nicht zurueckgesetzt wurde). Beim Logout wird die Uhr beendet und zurueckgesetzt.
-- Ein /reload zaehlt nicht als Logout (Luecke unter 90 s, dann laeuft die Uhr weiter).
--
-- Block: Eine Session zaehlt ihre Resets (Session.resets). Der Block einer Session ist ihre
-- Session-Zeit (ohne Offline-Zeit) beim letzten Logout, nachdem der Reset Nummer <Limit> kam
-- (Limit = Einstellung Resets pro Stunde, Standard 5) und bevor der naechste Reset folgte.
-- Damit lassen sich die Zeiten fuer 5 Runs gegeneinander stellen.

local BF = BananaFarm
local getn = table.getn

BF.Speedrun = {}
local SR = BF.Speedrun

SR.CHANNELS = { "PARTY", "RAID", "GUILD", "SAY" }
local MAX_LAPS = 200
local MAX_SESSIONS = 100

local function refresh()
  if BF.UI then BF.UI:Refresh() end
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

-- Runde in die Liste schreiben, je Durchlauf der Uhr ein Eintrag (wird bei Weiterlaufen ersetzt)
function SR:SaveLap()
  local sr = BananaFarmDB.speedrun
  local sw = sr.sw
  local t = self:Elapsed()
  if t <= 0 then return nil end
  local laps = sr.laps
  for i = getn(laps), 1, -1 do
    if laps[i].cyc == sw.cycle then
      table.remove(laps, i)
      break
    end
  end
  table.insert(laps, { t = t, at = time(), cyc = sw.cycle })
  while getn(laps) > MAX_LAPS do table.remove(laps, 1) end
  return t
end

function SR:Start()
  if not BF:Enabled("speedrun") then return end
  local sw = BananaFarmDB.speedrun.sw
  if sw.running then return end
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

function SR:Reset()
  local sw = BananaFarmDB.speedrun.sw
  if sw.running then self:Stop(true) end
  sw.elapsed = 0
  sw.cycle = (sw.cycle or 1) + 1
  refresh()
end

function SR:Toggle()
  if self:Running() then self:Stop() else self:Start() end
end

-- nach dem Laden: eine laufende Uhr wurde bei /reload nur unterbrochen, bei Logout oder
-- Absturz wird die Runde mit der Zeit bis dahin gespeichert und die Uhr zurueckgesetzt
function SR:OnLoad()
  local sw = BananaFarmDB.speedrun.sw
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
  sw.elapsed = 0
  sw.cycle = (sw.cycle or 1) + 1
end

-- ------------------------------------------------------------
-- Logout: Uhr sichern, Blockzeit der Session merken
-- ------------------------------------------------------------
BF:On("PLAYER_LOGOUT", function()
  if not BF:Enabled("speedrun") then return end
  local sw = BananaFarmDB.speedrun.sw
  if sw.running then
    sw.elapsed = SR:Elapsed()
    sw.t0 = nil
    sw.out = time()
  end
  local s = BananaFarmDB.session
  if s.running and (s.resets or 0) == BF.Resets:Limit() then
    s.out = BF.Session:Elapsed()
    s.outAt = time()
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

-- ------------------------------------------------------------
-- Sessions und Statistik
-- ------------------------------------------------------------
-- eine beendete Session in die Liste (wird beim Start der naechsten aufgerufen)
function SR:ArchiveSession(s)
  if not s then return end
  if (s.elapsed or 0) <= 0 and (s.resets or 0) <= 0 then return end
  local list = BananaFarmDB.speedrun.sessions
  table.insert(list, { at = s.date or s.outAt, elapsed = s.elapsed or 0, resets = s.resets or 0, out = s.out })
  while getn(list) > MAX_SESSIONS do table.remove(list, 1) end
end

-- Zeilen fuer die Liste: laufende oder letzte Session zuerst, dann die archivierten, neueste vorn
function SR:SessionRows()
  local out = {}
  local s = BananaFarmDB.session
  if s.running or (s.elapsed or 0) > 0 or (s.resets or 0) > 0 then
    table.insert(out, { at = s.date, elapsed = BF.Session:Elapsed(), resets = s.resets or 0,
      out = s.out, live = s.running and true or false, cur = true })
  end
  local list = BananaFarmDB.speedrun.sessions
  for i = getn(list), 1, -1 do table.insert(out, list[i]) end
  return out
end

-- einzelne Runde oder archivierte Session aus der Liste nehmen (e ist der Eintrag selbst)
function SR:DeleteLap(e)
  local laps = BananaFarmDB.speedrun.laps
  for i = 1, getn(laps) do
    if laps[i] == e then
      table.remove(laps, i)
      break
    end
  end
  refresh()
end

function SR:DeleteSession(e)
  local list = BananaFarmDB.speedrun.sessions
  for i = 1, getn(list) do
    if list[i] == e then
      table.remove(list, i)
      break
    end
  end
  refresh()
end

-- Anzahl, Beste, Schnitt, Letzte der gespeicherten Runden
function SR:LapStats()
  local laps = BananaFarmDB.speedrun.laps
  local n = getn(laps)
  if n == 0 then return 0 end
  local best, sum
  sum = 0
  for i = 1, n do
    local t = laps[i].t
    sum = sum + t
    if not best or t < best then best = t end
  end
  return n, best, sum / n, laps[n].t
end

-- kuerzeste Blockzeit aller Sessions (auch der laufenden)
function SR:BestBlock()
  local best
  local list = BananaFarmDB.speedrun.sessions
  for i = 1, getn(list) do
    local o = list[i].out
    if o and (not best or o < best) then best = o end
  end
  local o = BananaFarmDB.session.out
  if o and (not best or o < best) then best = o end
  return best
end

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

-- kind: "last" | "best" | "block"
function SR:Post(kind)
  local n, best, avg, last = self:LapStats()
  local text
  if kind == "block" then
    local b = self:BestBlock()
    if not b then
      BF:Print(BF.T("ERR_SR_NOTHING"))
      return
    end
    text = string.format(BF.T("MSG_SR_POST_BLOCK"), BF.Duration(b), BF.Resets:Limit())
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

-- BananaFarm: globales Event "Lasher Championships <Jahr>" (Modul "event", Standard aus, braucht speedrun).
-- 0.7.0: ohne Gold (kein Startgeld, kein Preisgeld). Startgeld und Preise folgen in 0.8.0, erst nach
-- schriftlicher Freigabe durch das OctoWoW-Team (siehe DEVELOPMENT.md).
--
-- Weg: ein eigener Chat-Kanal (EVENT_CHANNEL), dem das Addon beitritt, wenn das Modul an ist. Die
-- Nachrichten des Kanals blendet das Addon im Chat aus. Addon-Nachrichten koennen in 1.12 nicht ueber
-- /4 laufen; ein eigener Kanal erreicht auf OctoWoW (Crossfaction-Chat) beide Fraktionen.
--
-- Rollen: Nur die Chars in ORGANIZERS duerfen ein Event erstellen. Event-Daten werden nur direkt von
-- diesem Absender als "bestaetigt" uebernommen; weitergegebene Event-Daten bleiben unbestaetigt, bis
-- der Organisator selbst online war.
--
-- Zeugen-Prinzip: Startet ein Teilnehmer einen Durchgang (Lap 1) oder beendet er ihn, geht eine
-- Nachricht in den Kanal. Jeder Client mit Modul notiert die Empfangszeit (Zeuge), auch der eigene
-- (Selbst-Zeuge). Kommt jemand online, fragt er nach ("Q"), ein anderer gibt den Stand weiter.
-- Gewertet wird die eigene Gesamtzeit des Durchgangs. Fremde Zeugen pruefen sie: Ist sie deutlich
-- kuerzer als das, was die Zeugen zwischen Start und Ende gesehen haben, ist der Durchgang
-- "auffaellig" und zaehlt nicht. So bringt nachtraegliches Aendern der eigenen Zeiten nichts.
-- Ganz faelschungssicher ist das nicht: Wer den Addon-Code aendert, kann auch Nachrichten faelschen.
--
-- Nachrichten (Text im Kanal, Felder mit "~", beginnen mit "BFE~"):
--   E~id~v~start~finish~rank~max~reg~minLap~minKills~minLoot~selfOk~name   Event (nur Organisator)
--   X~id                                   Event abgesagt (nur Organisator)
--   J~id~fighter~class~guild~ts            Anmeldung (Absender = Teilnehmer)
--   S~id~hid                               Durchgang gestartet (Lap 1)
--   F~id~hid~total~laps~kills~loot         Durchgang fertig (Listen mit ",")
--   Q~id                                   Bitte um den Stand
--   G~id~fuer                              Ich antworte (andere lassen es dann)
--   RE~...wie E...~org                     weitergegebenes Event
--   RJ~id~name~fighter~class~guild~ts      weitergegebene Anmeldung
--   RH~id~name~hid~total~laps~kills~loot~zeugen   weitergegebener Durchgang, zeugen = w,s,e;w,s,e

local BF = BananaFarm
local getn = table.getn
local floor = math.floor

BF.Event = { out = {} }
local EV = BF.Event

EV.CHANNEL = "BananaFarmLC"
EV.ORGANIZERS = { bareg = true, lumihunt = true }
EV.SLACK = 120 -- Sekunden Toleranz zwischen eigener Zeit und Zeugen-Zeit
EV.MAX_WIT = 4  -- Zeugen je Durchgang beim Weitergeben

local FIGHTER_A = { "Banana", "Lasher", "Thorn", "Golden", "Sneaky", "Mighty", "Turbo", "Funky", "Wild", "Lucky" }
local FIGHTER_B = { "Bandit", "Lord", "Tickler", "Whacker", "Slayer", "Rider", "Gobbler", "Champ", "Smasher", "Baron" }

local function db()
  local d = BananaFarmDB.event
  if not d then
    d = {}
    BananaFarmDB.event = d
  end
  d.parts = d.parts or {}
  d.heats = d.heats or {}
  return d
end

local function low(s) return string.lower(s or "") end

local function clean(s, max)
  s = string.gsub(s or "", "[~|]", "")
  s = BF.Trim(s)
  if string.len(s) > (max or 24) then s = string.sub(s, 1, max or 24) end
  return s
end

local function split(s, sep)
  local t = {}
  local start = 1
  while true do
    local a = string.find(s, sep, start, true)
    if not a then
      table.insert(t, string.sub(s, start))
      return t
    end
    table.insert(t, string.sub(s, start, a - 1))
    start = a + 1
  end
end

local function nums(s)
  local t = {}
  for v in string.gfind(s or "", "([^,]+)") do table.insert(t, tonumber(v) or 0) end
  return t
end

function EV:Enabled()
  return BF:Enabled("event")
end

function EV:IsOrganizer(name)
  return self.ORGANIZERS[low(name or UnitName("player"))] and true or false
end

-- aktuelles Event (oder nil)
function EV:Current()
  local d = db()
  if d.ev and not d.ev.cancelled then return d.ev end
  return nil
end

-- "upcoming" | "running" | "ended" | nil
function EV:State(ev)
  ev = ev or self:Current()
  if not ev then return nil end
  local now = time()
  if now < ev.start then return "upcoming" end
  if now <= ev.finish then return "running" end
  return "ended"
end

function EV:Title(ev)
  ev = ev or self:Current()
  local year = date("%Y", ev and ev.start or time())
  return string.format(BF.T("EVENT_TITLE"), year)
end

-- ------------------------------------------------------------
-- Kanal
-- ------------------------------------------------------------
function EV:ChannelId()
  if not GetChannelName then return nil end
  local id = GetChannelName(self.CHANNEL)
  if id and id > 0 then return id end
  return nil
end

function EV:Join()
  if not self:Enabled() then return end
  if not self:ChannelId() and JoinChannelByName then
    JoinChannelByName(self.CHANNEL)
  end
  -- Kanal nicht im Chatfenster anzeigen
  if ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, DEFAULT_CHAT_FRAME, self.CHANNEL) end
end

function EV:Leave()
  if self:ChannelId() and LeaveChannelByName then LeaveChannelByName(self.CHANNEL) end
end

-- Nachrichten gebremst senden (eine pro 1,2 s), Kanal wird bei Bedarf betreten
function EV:Send(msg)
  if not self:Enabled() then return end
  table.insert(self.out, "BFE~" .. msg)
  if not self.pumping then
    self.pumping = true
    self:Pump()
  end
end

function EV:Pump()
  local msg = self.out[1]
  if not msg then
    self.pumping = false
    return
  end
  local id = self:ChannelId()
  if id then
    table.remove(self.out, 1)
    SendChatMessage(msg, "CHANNEL", nil, id)
  else
    self:Join()
  end
  BF:After(1.2, function() EV:Pump() end, "evpump")
end

-- Kanal-Zeilen im Chatfenster ausblenden
local origChat
local function hookChat()
  if origChat or not ChatFrame_OnEvent then return end
  origChat = ChatFrame_OnEvent
  ChatFrame_OnEvent = function(ev)
    if ev and string.find(ev, "^CHAT_MSG_CHANNEL") then
      local ch = low(arg9 or "")
      local ch4 = low(arg4 or "")
      local me = low(EV.CHANNEL)
      if ch == me or string.find(ch4, me, 1, true) then return end
    end
    return origChat(ev)
  end
end

-- ------------------------------------------------------------
-- Event erstellen und verwalten (Organisator)
-- ------------------------------------------------------------
function EV:EventMsg(ev, kind)
  return (kind or "E") .. "~" .. ev.id .. "~" .. ev.v .. "~" .. ev.start .. "~" .. ev.finish .. "~" .. ev.rank .. "~"
    .. ev.max .. "~" .. ev.reg .. "~" .. ev.minLap .. "~" .. ev.minKills .. "~" .. ev.minLoot .. "~"
    .. (ev.selfOk and 1 or 0) .. "~" .. clean(ev.name, 40)
end

function EV:Create(o)
  if not self:IsOrganizer() then
    BF:Error(BF.T("ERR_EVENT_ORG"))
    return
  end
  local me = UnitName("player")
  local ev = { id = me .. "-" .. o.start, v = time(), org = me, start = o.start, finish = o.finish,
    rank = o.rank, max = o.max, reg = o.reg, minLap = o.minLap, minKills = o.minKills, minLoot = o.minLoot,
    selfOk = o.selfOk, name = string.format(BF.T("EVENT_TITLE"), date("%Y", o.start)), confirmed = true }
  local d = db()
  d.ev = ev
  d.parts = {}
  d.heats = {}
  d.shownEnd = nil
  self:Send(self:EventMsg(ev))
  BF:Print(string.format(BF.T("MSG_EVENT_CREATED"), ev.name, date("%d.%m. %H:%M", ev.start), date("%d.%m. %H:%M", ev.finish)))
  if BF.UI then BF.UI:RefreshSpeedrun() end
end

function EV:Cancel()
  local ev = self:Current()
  if not ev or low(ev.org) ~= low(UnitName("player")) then return end
  ev.cancelled = true
  self:Send("X~" .. ev.id)
  BF:Print(BF.T("MSG_EVENT_CANCELLED"))
  if BF.UI then BF.UI:RefreshSpeedrun() end
end

-- Event-Daten uebernehmen. direct = vom Organisator selbst
function EV:TakeEvent(f, org, direct)
  local id = f[1]
  local ev = { id = id, v = tonumber(f[2]) or 0, start = tonumber(f[3]) or 0, finish = tonumber(f[4]) or 0,
    rank = f[5] or "best", max = tonumber(f[6]) or 0, reg = f[7] or "end", minLap = tonumber(f[8]) or 300,
    minKills = tonumber(f[9]) or 0, minLoot = tonumber(f[10]) or 0, selfOk = f[11] == "1", name = f[12] or "",
    org = org, confirmed = direct }
  -- die ID beginnt mit dem Namen des Organisators, und nur Organisatoren duerfen Events erstellen
  if not self:IsOrganizer(org) or low(string.sub(id, 1, string.len(org))) ~= low(org) then return end
  if ev.finish <= ev.start then return end
  local d = db()
  local cur = d.ev
  if cur and cur.id == ev.id then
    if ev.v < (cur.v or 0) then return end
    if cur.confirmed and not direct and ev.v == cur.v then return end
    ev.cancelled = cur.cancelled
    d.ev = ev
  elseif not cur or ev.v > (cur.v or 0) then
    d.ev = ev
    d.parts = {}
    d.heats = {}
    d.shownEnd = nil
    if direct then BF:Print(string.format(BF.T("MSG_EVENT_NEW"), ev.name, org)) end
  end
  if BF.UI then BF.UI:RefreshSpeedrun() end
end

-- ------------------------------------------------------------
-- Teilnehmen
-- ------------------------------------------------------------
function EV:CanJoin()
  local ev = self:Current()
  if not ev then return false, "ERR_EVENT_NONE" end
  local st = self:State(ev)
  if st == "ended" then return false, "ERR_EVENT_ENDED" end
  if ev.reg == "start" and st ~= "upcoming" then return false, "ERR_EVENT_REGCLOSED" end
  if ev.max > 0 and self:Count() >= ev.max then return false, "ERR_EVENT_FULL" end
  return true
end

function EV:Count()
  local n = 0
  for _ in pairs(db().parts) do n = n + 1 end
  return n
end

function EV:Joined(name)
  return db().parts[name or UnitName("player")] ~= nil
end

function EV:RandomFighter()
  return FIGHTER_A[math.random(1, getn(FIGHTER_A))] .. " " .. FIGHTER_B[math.random(1, getn(FIGHTER_B))]
end

function EV:Register(fighter)
  local ok, err = self:CanJoin()
  if not ok then
    BF:Error(BF.T(err))
    return
  end
  fighter = clean(fighter, 24)
  if fighter == "" then fighter = self:RandomFighter() end
  local _, class = UnitClass("player")
  local guild = (GetGuildInfo and GetGuildInfo("player")) or ""
  local me = UnitName("player")
  local ts = time()
  db().parts[me] = { fighter = fighter, class = class or "", guild = clean(guild, 30), ts = ts }
  self:Send("J~" .. self:Current().id .. "~" .. fighter .. "~" .. (class or "") .. "~" .. clean(guild, 30) .. "~" .. ts)
  BF:Print(string.format(BF.T("MSG_EVENT_JOINED"), fighter))
  if BF.UI then BF.UI:RefreshSpeedrun() end
end

function EV:TakePart(id, name, fighter, class, guild, ts)
  local ev = self:Current()
  if not ev or ev.id ~= id or not name or name == "" then return end
  local d = db()
  if d.parts[name] then return end
  if ev.max > 0 and self:Count() >= ev.max then return end
  d.parts[name] = { fighter = clean(fighter, 24), class = class or "", guild = clean(guild, 30), ts = tonumber(ts) or time() }
  if BF.UI then BF.UI:RefreshSpeedrun() end
end

-- ------------------------------------------------------------
-- Durchgaenge und Zeugen
-- ------------------------------------------------------------
local function heatRec(name, hid)
  local d = db()
  d.heats[name] = d.heats[name] or {}
  local h = d.heats[name][hid]
  if not h then
    h = { wit = {} }
    d.heats[name][hid] = h
  end
  return h
end

-- eigener Durchgang beginnt (Speedrun Lap 1)
function EV:OnHeatStart(heat)
  local ev = self:Current()
  local me = UnitName("player")
  if not ev or not self:Joined(me) or self:State(ev) ~= "running" or not heat.hid then return end
  local h = heatRec(me, heat.hid)
  h.wit[me] = { s = time() }
  self:Send("S~" .. ev.id .. "~" .. heat.hid)
end

-- eigener Durchgang fertig (Speedrun CompleteHeat)
function EV:OnHeat(e)
  local ev = self:Current()
  local me = UnitName("player")
  if not ev or not self:Joined(me) or not e.hid then return end
  if e.start < ev.start or e.at > ev.finish then return end
  local h = heatRec(me, e.hid)
  h.total, h.laps, h.kills, h.loot = e.total, e.laps, e.kills, e.loot
  h.wit[me] = h.wit[me] or {}
  h.wit[me].e = time()
  h.solo = e.solo
  self:Send("F~" .. ev.id .. "~" .. e.hid .. "~" .. floor(e.total) .. "~" .. table.concat(e.laps, ",") .. "~"
    .. table.concat(e.kills or {}, ",") .. "~" .. table.concat(e.loot or {}, ",") .. "~" .. table.concat(e.solo or {}, ","))
  if BF.UI then BF.UI:RefreshSpeedrun() end
end

local function takeHeatData(h, total, laps, kills, loot, solo)
  h.total = tonumber(total)
  h.laps = nums(laps)
  h.kills = nums(kills)
  h.loot = nums(loot)
  if solo and solo ~= "" then h.solo = nums(solo) end
end

-- Wertung eines Durchgangs: ok, Zeit, Zahl fremder Zeugen, Grund (Locale-Schluessel)
function EV:Check(name, h)
  local ev = self:Current()
  if not ev or not h.total or not h.laps then return false end
  local n = getn(h.laps)
  if n < BF.Resets:Limit() then return false, nil, 0, "EVR_LAPS" end
  for i = 1, n do
    if h.laps[i] < ev.minLap then return false, nil, 0, "EVR_MINLAP" end
    if ev.minKills > 0 and (h.kills[i] or 0) < ev.minKills then return false, nil, 0, "EVR_KILLS" end
    if ev.minLoot > 0 and (h.loot[i] or 0) < ev.minLoot then return false, nil, 0, "EVR_LOOT" end
    if h.solo and h.solo[i] == 0 then return false, nil, 0, "EVR_HELPER" end
  end
  -- fremde Zeugen: gesehene Spanne zwischen Start und Ende
  local seen, nw = {}, 0
  for w, r in pairs(h.wit) do
    if low(w) ~= low(name) and r.s and r.e and r.e > r.s then
      table.insert(seen, r.e - r.s)
      nw = nw + 1
    end
  end
  if nw == 0 then
    if not ev.selfOk then return false, nil, 0, "EVR_NOWIT" end
    return true, h.total, 0
  end
  table.sort(seen)
  local med = seen[floor((nw + 1) / 2)]
  if h.total < med - self.SLACK then return false, nil, nw, "EVR_SUSPECT" end
  return true, h.total, nw
end

-- Rangliste nach der Wertung des Events: { name, fighter, class, guild, value, best, n, gold, wit }
function EV:Ranking()
  local ev = self:Current()
  if not ev then return {} end
  local d = db()
  local rows = {}
  for name, p in pairs(d.parts) do
    local n, best, gold, wit = 0, nil, 0, 0
    for hid, h in pairs(d.heats[name] or {}) do
      local ok, t, nw = self:Check(name, h)
      if ok then
        n = n + 1
        if not best or t < best then best = t end
        for i = 1, getn(h.loot or {}) do gold = gold + (h.loot[i] or 0) end
        if nw > wit then wit = nw end
      end
    end
    table.insert(rows, { name = name, fighter = p.fighter, class = p.class, guild = p.guild,
      n = n, best = best, gold = gold, wit = wit })
  end
  table.sort(rows, function(a, b)
    if ev.rank == "count" then
      if a.n ~= b.n then return a.n > b.n end
    elseif ev.rank == "gold" then
      if a.gold ~= b.gold then return a.gold > b.gold end
    else
      if (a.best ~= nil) ~= (b.best ~= nil) then return a.best ~= nil end
      if a.best and b.best and a.best ~= b.best then return a.best < b.best end
    end
    return a.name < b.name
  end)
  return rows
end

-- ------------------------------------------------------------
-- Weitergeben ("Schneeball")
-- ------------------------------------------------------------
function EV:Ask()
  local ev = self:Current()
  self:Send("Q~" .. (ev and ev.id or "-"))
end

function EV:Relay(forWhom)
  local ev = db().ev
  if not ev then return end
  self:Send("G~" .. ev.id .. "~" .. forWhom)
  self:Send(self:EventMsg(ev, "RE") .. "~" .. ev.org .. (ev.cancelled and "~X" or ""))
  local d = db()
  for name, p in pairs(d.parts) do
    self:Send("RJ~" .. ev.id .. "~" .. name .. "~" .. p.fighter .. "~" .. p.class .. "~" .. p.guild .. "~" .. p.ts)
  end
  for name, hs in pairs(d.heats) do
    for hid, h in pairs(hs) do
      local ws, k = {}, 0
      for w, r in pairs(h.wit) do
        if k < self.MAX_WIT then
          k = k + 1
          table.insert(ws, w .. "," .. (r.s or 0) .. "," .. (r.e or 0))
        end
      end
      self:Send("RH~" .. ev.id .. "~" .. name .. "~" .. hid .. "~" .. (h.total or 0) .. "~"
        .. table.concat(h.laps or {}, ",") .. "~" .. table.concat(h.kills or {}, ",") .. "~"
        .. table.concat(h.loot or {}, ",") .. "~" .. table.concat(ws, ";") .. "~" .. table.concat(h.solo or {}, ","))
    end
  end
end

-- ------------------------------------------------------------
-- Empfangen
-- ------------------------------------------------------------
function EV:OnMessage(msg, sender)
  if string.sub(msg, 1, 4) ~= "BFE~" then return end
  local f = split(string.sub(msg, 5), "~")
  local kind = table.remove(f, 1)
  local ev = self:Current()
  local now = time()

  if kind == "E" then
    self:TakeEvent(f, sender, true)
  elseif kind == "RE" then
    local org = f[13]
    if org then
      self:TakeEvent(f, org, false)
      if f[14] == "X" and db().ev and db().ev.id == f[1] then db().ev.cancelled = true end
    end
  elseif kind == "X" then
    if db().ev and db().ev.id == f[1] and low(db().ev.org) == low(sender) then
      db().ev.cancelled = true
      BF:Print(BF.T("MSG_EVENT_CANCELLED"))
    end
  elseif kind == "J" then
    self:TakePart(f[1], sender, f[2], f[3], f[4], f[5])
  elseif kind == "RJ" then
    self:TakePart(f[1], f[2], f[3], f[4], f[5], f[6])
  elseif kind == "S" then
    if ev and ev.id == f[1] and db().parts[sender] then
      local h = heatRec(sender, f[2])
      local me = UnitName("player")
      h.wit[me] = h.wit[me] or {}
      h.wit[me].s = h.wit[me].s or now
    end
  elseif kind == "F" then
    if ev and ev.id == f[1] and db().parts[sender] then
      local h = heatRec(sender, f[2])
      takeHeatData(h, f[3], f[4], f[5], f[6], f[7])
      local me = UnitName("player")
      h.wit[me] = h.wit[me] or {}
      h.wit[me].e = now
    end
  elseif kind == "RH" then
    if ev and ev.id == f[1] and db().parts[f[2]] then
      local h = heatRec(f[2], f[3])
      if not h.total then takeHeatData(h, f[4], f[5], f[6], f[7], f[9]) end
      for w, s, e in string.gfind(f[8] or "", "([^,;]+),(%d+),(%d+)") do
        local r = h.wit[w] or {}
        if not r.s and tonumber(s) > 0 then r.s = tonumber(s) end
        if not r.e and tonumber(e) > 0 then r.e = tonumber(e) end
        h.wit[w] = r
      end
    end
  elseif kind == "Q" then
    -- nur einer antwortet: zufaellige Wartezeit, wer vorher ein G fuer denselben Frager sieht, schweigt
    if db().ev then
      self.replyFor = sender
      BF:After(2 + math.random() * 10, function()
        if EV.replyFor == sender then
          EV.replyFor = nil
          EV:Relay(sender)
        end
      end, "evreply")
    end
    -- der Organisator kuendigt sein Event immer an
    if ev and low(ev.org) == low(UnitName("player")) then self:Send(self:EventMsg(ev)) end
  elseif kind == "G" then
    if self.replyFor == f[2] then
      self.replyFor = nil
      BF:Cancel("evreply")
    end
  end
  if BF.UI then BF.UI:RefreshSpeedrun() end
end

BF:On("CHAT_MSG_CHANNEL", function(msg, sender)
  if not EV:Enabled() or type(msg) ~= "string" or type(sender) ~= "string" then return end
  if low(arg9 or "") ~= low(EV.CHANNEL) and not string.find(low(arg4 or ""), low(EV.CHANNEL), 1, true) then return end
  if sender == UnitName("player") then return end
  EV:OnMessage(msg, sender)
end)

-- Login: Kanal betreten, Stand erfragen; Organisator kuendigt sein Event alle 10 Minuten an
BF:On("PLAYER_ENTERING_WORLD", function()
  if EV.loginDone then return end
  EV.loginDone = true
  hookChat()
  BF:After(15, function()
    if not EV:Enabled() then return end
    EV:Join()
    BF:After(5, function() EV:Ask() end, "evask")
  end, "evjoin")
  local function tick()
    local ev = EV:Current()
    if EV:Enabled() and ev and low(ev.org) == low(UnitName("player")) and EV:State(ev) ~= "ended" then
      EV:Send(EV:EventMsg(ev))
    end
    EV:CheckEnd()
    BF:After(600, tick, "evtick")
  end
  BF:After(60, tick, "evtick")
end)

-- Ende: einmal das Sieger-Pop-up zeigen
function EV:CheckEnd()
  local ev = self:Current()
  local d = db()
  if not self:Enabled() or not ev or self:State(ev) ~= "ended" or d.shownEnd == ev.id then return end
  d.shownEnd = ev.id
  local rows = self:Ranking()
  if getn(rows) > 0 and BF.UI then BF.UI:ShowEventWinners(rows) end
end

-- Modul an/aus: Kanal betreten oder verlassen
function EV:OnModule(on)
  if on then
    hookChat()
    self:Join()
    BF:After(3, function() EV:Ask() end, "evask")
  else
    self:Leave()
  end
end

-- ------------------------------------------------------------
-- Datum und Uhrzeit aus Eingaben (TT.MM.JJJJ und HH:MM) in einen Zeitpunkt
-- ------------------------------------------------------------
local function civ(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = floor(y / 400)
  local yoe = y - era * 400
  local mp = m > 2 and m - 3 or m + 9
  local doy = floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
  return era * 146097 + doe
end

function EV.MakeTime(dateText, timeText)
  local _, _, d, m, y = string.find(dateText or "", "^%s*(%d+)%.(%d+)%.(%d+)%s*$")
  local _, _, hh, mi = string.find(timeText or "", "^%s*(%d+):(%d+)%s*$")
  if not d or not hh then return nil end
  d, m, y, hh, mi = tonumber(d), tonumber(m), tonumber(y), tonumber(hh), tonumber(mi)
  if y < 100 then y = y + 2000 end
  if m < 1 or m > 12 or d < 1 or d > 31 or hh > 23 or mi > 59 then return nil end
  local now = time()
  local t = date("*t", now)
  local days = civ(y, m, d) - civ(t.year, t.month, t.day)
  return now - (t.hour * 3600 + t.min * 60 + t.sec) + days * 86400 + hh * 3600 + mi * 60
end

-- ------------------------------------------------------------
-- Fenster: Event-Ansicht im Speedrun-Reiter und "Event erstellen"
-- ------------------------------------------------------------
local UI = BF.UI
local T = function(k) return BF.T(k) end
local EV_ROWS = 7

local CLASS_HEX = { WARRIOR = "c79c6e", PALADIN = "f58cba", HUNTER = "abd473", ROGUE = "fff569", PRIEST = "ffffff",
  SHAMAN = "0070de", MAGE = "69ccf0", WARLOCK = "9482c9", DRUID = "ff7d0a" }

local function remaining(sec)
  if sec < 0 then sec = 0 end
  local d = floor(sec / 86400)
  local h = floor(BF.mod(sec, 86400) / 3600)
  local m = floor(BF.mod(sec, 3600) / 60)
  if d > 0 then return d .. "d " .. h .. "h" end
  if h > 0 then return h .. "h " .. m .. "m" end
  return m .. "m"
end

function UI:BuildEventPage(p)
  local C = self.C
  local e = { rows = {} }
  self.ev = e
  local banner = p:CreateTexture(nil, "ARTWORK")
  banner:SetTexture(BF.EVENT_BANNER)
  -- ganzes Bild (16:9) links in der 512x256-Textur, rechts transparent aufgefuellt
  banner:SetTexCoord(0, 455 / 512, 0, 1)
  banner:SetWidth(296)
  banner:SetHeight(166)
  banner:SetPoint("TOP", p, "TOP", 0, -32)

  e.title = self:Font(p, 15, C.gold, "Fonts\\MORPHEUS.TTF")
  e.title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -202)
  e.state = self:Font(p, 11, C.text)
  e.state:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -204)
  e.state:SetJustifyH("RIGHT")
  e.info1 = self:Font(p, 10, C.text)
  e.info1:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -222)
  e.info1:SetWidth(448)
  e.info1:SetHeight(12)
  e.info2 = self:Font(p, 10, C.muted)
  e.info2:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -236)
  e.info2:SetWidth(448)
  e.info2:SetHeight(12)
  e.info3 = self:Font(p, 10, C.muted)
  e.info3:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -250)
  e.info3:SetWidth(448)
  e.info3:SetHeight(12)

  -- Anmeldung
  e.fLabel = self:Font(p, 11, C.text)
  e.fLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -270)
  self:Loc(e.fLabel, "EV_FIGHTER")
  e.fBox = CreateFrame("EditBox", "BananaFarmEventFighter", p, "InputBoxTemplate")
  e.fBox:SetWidth(150)
  e.fBox:SetHeight(20)
  e.fBox:SetAutoFocus(false)
  e.fBox:SetMaxLetters(24)
  e.fBox:SetFontObject("ChatFontNormal")
  e.fBox:SetPoint("LEFT", e.fLabel, "RIGHT", 10, 0)
  e.fBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  e.fBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  e.dice = self:Button(p, 24, 20, "?", function() e.fBox:SetText(BF.Event:RandomFighter()) end, "flat")
  e.dice:SetPoint("LEFT", e.fBox, "RIGHT", 4, 0)
  self:Tip(e.dice, "EV_DICE", "EV_DICE_TT")
  e.join = self:Button(p, 120, 22, "EV_JOIN", function()
    local name = e.fBox:GetText()
    UI:ShowRules(function() BF.Event:Register(name) end)
  end, "ok")
  e.join:SetPoint("LEFT", e.dice, "RIGHT", 8, 0)
  e.me = self:Font(p, 11, C.gold)
  e.me:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -270)

  local cols = { { "EV_C_RANK", 16 }, { "EV_C_FIGHTER", 40 }, { "EV_C_CHAR", 160 }, { "EV_C_GUILD", 260 },
    { "EV_C_VALUE", 360 }, { "EV_C_WIT", 420 } }
  for i = 1, getn(cols) do
    local fs = self:Font(p, 10, C.muted)
    fs:SetPoint("TOPLEFT", p, "TOPLEFT", cols[i][2], -296)
    self:Loc(fs, cols[i][1])
  end
  for i = 1, EV_ROWS do
    local r = CreateFrame("Frame", nil, p)
    r:SetHeight(19)
    r:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -310 - (i - 1) * 20)
    r:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -310 - (i - 1) * 20)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    bg:SetAllPoints(r)
    if i <= 3 then bg:SetVertexColor(1, 0.82, 0.26, 0.10) elseif BF.mod(i, 2) == 0 then bg:SetVertexColor(1, 1, 1, 0.03) else bg:SetVertexColor(1, 1, 1, 0.07) end
    r.cells = {}
    for j = 1, getn(cols) do
      local fs = self:Font(r, 10)
      fs:SetPoint("LEFT", r, "LEFT", cols[j][2] - 14, 0)
      if j == 2 then fs:SetWidth(115) elseif j == 3 or j == 4 then fs:SetWidth(95) end
      fs:SetHeight(12)
      r.cells[j] = fs
    end
    e.rows[i] = r
  end
  e.empty = self:Font(p, 11, C.muted)
  e.empty:SetPoint("TOPLEFT", p, "TOPLEFT", 30, -322)
  e.empty:SetWidth(420)
  e.empty:SetJustifyH("LEFT")

  e.create = self:Button(p, 130, 22, "EV_CREATE", function() UI:ShowEventCreate() end, "primary")
  e.create:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -456)
  e.cancel = self:Button(p, 130, 22, "EV_CANCEL", function()
    UI:Confirm("evcancel", T("EV_ASK_CANCEL"), function() BF.Event:Cancel() end)
  end, "danger")
  e.cancel:SetPoint("LEFT", e.create, "RIGHT", 6, 0)
  e.note = self:Font(p, 9, C.muted)
  e.note:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -484)
  e.note:SetWidth(448)
  e.note:SetJustifyH("LEFT")
  self:Loc(e.note, "EV_NOTE")
  e.off = self:Font(p, 11, C.text)
  e.off:SetPoint("TOPLEFT", p, "TOPLEFT", 30, -270)
  e.off:SetWidth(420)
  e.off:SetJustifyH("LEFT")
  self:Loc(e.off, "EV_OFF")
end

local function rankName(r)
  if r == "count" then return T("EV_R_COUNT") elseif r == "gold" then return T("EV_R_GOLD") end
  return T("EV_R_BEST")
end

function UI:RefreshEventPage()
  local e = self.ev
  if not e then return end
  local EVM = BF.Event
  local on = EVM:Enabled()
  local ev = EVM:Current()
  local isOrg = EVM:IsOrganizer()
  local joined = EVM:Joined()
  local function show(f, v) if v then f:Show() else f:Hide() end end
  show(e.off, not on)
  show(e.create, on and isOrg)
  show(e.cancel, on and isOrg and ev and string.lower(ev.org) == string.lower(UnitName("player")) and EVM:State(ev) ~= "ended")
  if not on or not ev then
    e.title:SetText(string.format(T("EVENT_TITLE"), date("%Y")))
    e.state:SetText("")
    e.info1:SetText(on and T("EV_NONE") or "")
    e.info2:SetText("")
    e.info3:SetText("")
    for _, f in ipairs({ e.fLabel, e.fBox, e.dice, e.join, e.me, e.empty }) do f:Hide() end
    for i = 1, EV_ROWS do e.rows[i]:Hide() end
    return
  end
  local st = EVM:State(ev)
  e.title:SetText(ev.name ~= "" and ev.name or EVM:Title(ev))
  local stText
  if st == "upcoming" then
    stText = string.format(T("EV_ST_UPCOMING"), remaining(ev.start - time()))
  elseif st == "running" then
    stText = "|cff40ff40" .. string.format(T("EV_ST_RUNNING"), remaining(ev.finish - time())) .. "|r"
  else
    stText = "|cffff6050" .. T("EV_ST_ENDED") .. "|r"
  end
  if not ev.confirmed then stText = stText .. "  |cffff9040" .. T("EV_UNCONFIRMED") .. "|r" end
  e.state:SetText(stText)
  e.info1:SetText(string.format(T("EV_INFO1"), date("%d.%m. %H:%M", ev.start), date("%d.%m. %H:%M", ev.finish),
    rankName(ev.rank), EVM:Count(), ev.max > 0 and tostring(ev.max) or "-"))
  -- Beute als ganze Gold, wenn sie aufgeht ("2g" statt "2g 0s 0c")
  local loot = BF.mod(ev.minLoot, 10000) == 0 and (floor(ev.minLoot / 10000) .. "g") or BF.Money(ev.minLoot)
  e.info2:SetText(string.format(T("EV_INFO2"), floor(ev.minLap / 60), ev.minKills, loot))
  e.info3:SetText(string.format(T("EV_INFO3"), T(ev.selfOk and "YES" or "NO"),
    T(ev.reg == "start" and "EV_REG_START" or "EV_REG_END"), ev.org))
  -- Anmeldung
  local can = EVM:CanJoin()
  if joined then
    for _, f in ipairs({ e.fLabel, e.fBox, e.dice, e.join }) do f:Hide() end
    e.me:SetText(string.format(T("EV_YOU_ARE"), BananaFarmDB.event.parts[UnitName("player")].fighter))
    e.me:Show()
  else
    e.me:Hide()
    for _, f in ipairs({ e.fLabel, e.fBox, e.dice, e.join }) do f:Show() end
    e.join:SetAlpha(can and 1 or 0.4)
  end
  -- Rangliste
  local rows = EVM:Ranking()
  for i = 1, EV_ROWS do
    local r = e.rows[i]
    local x = rows[i]
    if x then
      r.cells[1]:SetText(i .. ".")
      r.cells[2]:SetText(x.fighter)
      r.cells[3]:SetText("|cff" .. (CLASS_HEX[x.class] or "ffffff") .. x.name .. "|r")
      r.cells[4]:SetText(x.guild ~= "" and x.guild or "-")
      local v
      if ev.rank == "count" then v = tostring(x.n) elseif ev.rank == "gold" then v = BF.Money(x.gold) else v = x.best and BF.Duration(x.best) or "-" end
      r.cells[5]:SetText(v)
      r.cells[6]:SetText(x.n == 0 and "-" or (x.wit > 0 and tostring(x.wit) or T("EV_SELF")))
      r:Show()
    else
      r:Hide()
    end
  end
  if getn(rows) == 0 then
    e.empty:SetText(T("EV_NOPARTS"))
    e.empty:Show()
  else
    e.empty:Hide()
  end
end

-- Event erstellen (nur Organisatoren)
function UI:ShowEventCreate()
  local C = self.C
  local f = self.evCreate
  if not f then
    f = self:Window("BananaFarmEventCreate", 420, 372)
    self.evCreate = f
    if not BananaFarmDB.pos["BananaFarmEventCreate"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
    tinsert(UISpecialFrames, "BananaFarmEventCreate")
    local title = self:Font(f, 15, C.gold, "Fonts\\MORPHEUS.TTF")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
    self:Loc(title, "EV_CREATE")
    f.fields = {}
    local y = -42
    local function box(key, w, x)
      local b = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
      b:SetWidth(w)
      b:SetHeight(20)
      b:SetAutoFocus(false)
      b:SetFontObject("ChatFontNormal")
      b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
      b:SetScript("OnEnterPressed", function() this:ClearFocus() end)
      b:SetScript("OnEscapePressed", function() this:ClearFocus() end)
      f.fields[key] = b
      return b
    end
    local function label(key, x)
      local fs = self:Font(f, 11)
      fs:SetPoint("TOPLEFT", f, "TOPLEFT", x, y - 4)
      self:Loc(fs, key)
    end
    label("EV_F_START", 18); box("sd", 86, 150); box("st", 50, 244)
    y = y - 26
    label("EV_F_END", 18); box("ed", 86, 150); box("et", 50, 244)
    y = y - 30
    label("EV_F_RANK", 18)
    f.rank = {}
    local rdefs = { { "best", "EV_R_BEST" }, { "count", "EV_R_COUNT" }, { "gold", "EV_R_GOLD" } }
    for i = 1, 3 do
      local key = rdefs[i][1]
      local b = self:Button(f, 80, 20, rdefs[i][2], function() f.rankSel = key; UI:RefreshEventCreate() end, "flat")
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 150 + (i - 1) * 84, y)
      f.rank[key] = b
    end
    y = y - 28
    label("EV_F_MAX", 18); box("max", 50, 150)
    y = y - 26
    label("EV_F_REG", 18)
    f.reg = {}
    local gdefs = { { "start", "EV_REG_START" }, { "end", "EV_REG_END" } }
    for i = 1, 2 do
      local key = gdefs[i][1]
      local b = self:Button(f, 120, 20, gdefs[i][2], function() f.regSel = key; UI:RefreshEventCreate() end, "flat")
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 150 + (i - 1) * 124, y)
      f.reg[key] = b
    end
    y = y - 30
    label("EV_F_MINLAP", 18); box("minLap", 50, 230)
    y = y - 26
    label("EV_F_MINKILLS", 18); box("minKills", 50, 230)
    y = y - 26
    label("EV_F_MINLOOT", 18); box("minLoot", 50, 230)
    y = y - 28
    f.selfOk = true
    f.selfChk = self:Check(f, "EV_F_SELFOK", { get = function() return f.selfOk end, set = function(v) f.selfOk = v end })
    f.selfChk:SetPoint("TOPLEFT", f, "TOPLEFT", 18, y)
    local ok = self:Button(f, 130, 24, "EV_CREATE_GO", function() UI:EventCreateGo() end, "ok")
    ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 14)
    local no = self:Button(f, 130, 24, "BTN_CANCEL", function() f:Hide() end, "flat")
    no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 14)
  end
  -- Vorgaben: Start zur naechsten vollen Stunde, eine Woche Dauer
  local now = time()
  local t = date("*t", now)
  local start = now - t.min * 60 - t.sec + 3600
  f.fields.sd:SetText(date("%d.%m.%Y", start))
  f.fields.st:SetText(date("%H:%M", start))
  f.fields.ed:SetText(date("%d.%m.%Y", start + 7 * 86400))
  f.fields.et:SetText(date("%H:%M", start))
  f.fields.max:SetText("0")
  f.fields.minLap:SetText("2")
  f.fields.minKills:SetText("78")
  f.fields.minLoot:SetText("2")
  f.rankSel = "best"
  f.regSel = "end"
  f.selfOk = true
  self:RefreshEventCreate()
  f:Show()
end

function UI:RefreshEventCreate()
  local f = self.evCreate
  for k, b in pairs(f.rank) do b:SetActive(k == f.rankSel) end
  for k, b in pairs(f.reg) do b:SetActive(k == f.regSel) end
  f.selfChk.Update()
end

function UI:EventCreateGo()
  local f = self.evCreate
  local F = f.fields
  local start = BF.Event.MakeTime(F.sd:GetText(), F.st:GetText())
  local finish = BF.Event.MakeTime(F.ed:GetText(), F.et:GetText())
  if not start or not finish or finish <= start then
    BF:Error(T("ERR_EVENT_DATE"))
    return
  end
  local function n(b, def)
    local v = tonumber((string.gsub(b:GetText() or "", ",", ".")))
    if not v or v < 0 then return def end
    return v
  end
  BF.Event:Create({ start = start, finish = finish, rank = f.rankSel, max = floor(n(F.max, 0)),
    reg = f.regSel, minLap = floor(n(F.minLap, 2) * 60), minKills = floor(n(F.minKills, 78)),
    minLoot = floor(n(F.minLoot, 2) * 10000), selfOk = f.selfOk })
  f:Hide()
end

-- Sieger-Pop-up am Ende (mit dem Event-Bild)
function UI:ShowEventWinners(rows)
  local C = self.C
  local f = self.evWin
  if not f then
    f = self:Window("BananaFarmEventWinners", 400, 360)
    self.evWin = f
    if not BananaFarmDB.pos["BananaFarmEventWinners"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 60) end
    tinsert(UISpecialFrames, "BananaFarmEventWinners")
    local banner = f:CreateTexture(nil, "ARTWORK")
    banner:SetTexture(BF.EVENT_BANNER)
    banner:SetTexCoord(0, 455 / 512, 0, 1)
    banner:SetWidth(320)
    banner:SetHeight(180)
    banner:SetPoint("TOP", f, "TOP", 0, -12)
    f.sub = self:Font(f, 12, C.gold)
    f.sub:SetPoint("TOP", banner, "BOTTOM", 0, -8)
    f.lines = {}
    for i = 1, 3 do
      local fs = self:Font(f, i == 1 and 14 or 12, i == 1 and C.gold or C.text)
      fs:SetPoint("TOP", f.sub, "BOTTOM", 0, -10 - (i - 1) * 22)
      fs:SetJustifyH("CENTER")
      f.lines[i] = fs
    end
    local close = self:Button(f, 120, 24, "BTN_CLOSE", function() f:Hide() end, "primary")
    close:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
  end
  local ev = BF.Event:Current()
  f.sub:SetText(T("EV_WINNERS"))
  local medal = { "|cffffd100", "|cffc7c7cf", "|cffeda55f" }
  for i = 1, 3 do
    local x = rows[i]
    if x and x.n > 0 then
      local v
      if ev and ev.rank == "count" then v = x.n .. " " .. T("SR_HEATS_SHORT")
      elseif ev and ev.rank == "gold" then v = BF.Money(x.gold)
      else v = x.best and BF.Duration(x.best) or "-" end
      f.lines[i]:SetText(medal[i] .. i .. ". " .. x.fighter .. "|r (" .. x.name .. ")   " .. v)
    else
      f.lines[i]:SetText("")
    end
  end
  f:Show()
end

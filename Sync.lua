-- BananaFarm Sync: gleicht Listen (manuelle Zuordnungen), AH-Preise und Resets mit dem Partner ab
-- (Bankalt). Weg: Addon-Nachrichten ueber PARTY/RAID, der Partner muss in der Gruppe sein.
-- Pro Eintrag gewinnt der neuere Zeitstempel. Ausgetauscht wird nur, was seit dem letzten Abgleich neu ist.
--
-- Nachrichten (Praefix BFSYNC, je max. ~200 Zeichen):
--   H                      Hallo: "ich moechte abgleichen"
--   S:<seit>               Anfrage: "schick mir alles, was seit <seit> neu ist"
--   L:id:c:ts;...          Listeneintraege (c = V M I K U oder - fuer entfernt)
--   A:id:preis:ts:n;...    AH-Preise (Kupfer pro Stueck, Zeit, Stichproben)
--   T:ts;ts;...            Reset-Zeitstempel
--   E:jetzt:nL:nA:nT       Ende: "jetzt" ist die Uhrzeit des Senders, daraus wird der naechste <seit>

local BF = BananaFarm
local getn = table.getn
local floor = math.floor

local PREFIX = "BFSYNC"
local CHUNK = 200

BF.Sync = { out = {}, rx = { L = 0, A = 0, T = 0 }, helloAt = -100, reqAt = -100, pushedAt = -100 }
local Sync = BF.Sync

function Sync:Peer()
  local db = BananaFarmDB
  local p = db.syncPeer
  if not p or p == "" then p = db.bankAlt end
  if not p or p == "" then return nil end
  return p
end

function Sync:Channel()
  if GetNumRaidMembers() > 0 then return "RAID" end
  if GetNumPartyMembers() > 0 then return "PARTY" end
  return nil
end

function Sync:State()
  local db = BananaFarmDB
  db.sync = db.sync or {}
  db.sync.last = db.sync.last or {}  -- [name] = Uhrzeit des Partners beim letzten empfangenen Ende
  db.sync.since = db.sync.since or {} -- [name] = zuletzt vom Partner angefragter Stand
  return db.sync
end

-- ------------------------------------------------------------
-- Senden (Warteschlange, ein Paket alle 0,25 s)
-- ------------------------------------------------------------
function Sync:Queue(msg)
  table.insert(self.out, msg)
  if not self.pumping then
    self.pumping = true
    self:Tick()
  end
end

function Sync:RawSend(msg)
  local ch = self:Channel()
  if ch and SendAddonMessage then SendAddonMessage(PREFIX, msg, ch) end
end

function Sync:Tick()
  local msg = table.remove(self.out, 1)
  if not msg then
    self.pumping = false
    return
  end
  self:RawSend(msg)
  BF:After(0.25, function() Sync:Tick() end, "syncpump")
end

-- beim Logout: alles Uebrige sofort raus
function Sync:Flush()
  while getn(self.out) > 0 do
    self:RawSend(table.remove(self.out, 1))
  end
  self.pumping = false
  BF:Cancel("syncpump")
end

function Sync:Add(kind, buf, entry)
  if buf == "" then return kind .. ":" .. entry end
  if string.len(buf) + string.len(entry) + 1 > CHUNK then
    self:Queue(buf)
    return kind .. ":" .. entry
  end
  return buf .. ";" .. entry
end

function Sync:ListChar(id)
  local db = BananaFarmDB
  if db.manual[id] then return db.manual[id] end
  if db.unsorted[id] then return "U" end
  return "-"
end

-- alles senden, was seit "since" neu ist (2 Minuten Rand fuer leicht abweichende Uhren)
function Sync:Push(since)
  local db = BananaFarmDB
  local cut = (since or 0) - 120
  if cut < 0 then cut = 0 end
  local nL, nA, nT = 0, 0, 0

  local buf = ""
  for id, ts in pairs(db.manualTs) do
    if ts > cut then
      buf = self:Add("L", buf, id .. ":" .. self:ListChar(id) .. ":" .. ts)
      nL = nL + 1
    end
  end
  if buf ~= "" then self:Queue(buf) end

  buf = ""
  for id, e in pairs(db.ah) do
    if e.ts and e.ts > cut then
      buf = self:Add("A", buf, id .. ":" .. floor((e.u or 0) + 0.5) .. ":" .. e.ts .. ":" .. (e.n or 0))
      nA = nA + 1
    end
  end
  if buf ~= "" then self:Queue(buf) end

  buf = ""
  local rs = BF.Resets:Prune()
  for i = 1, getn(rs) do
    buf = self:Add("T", buf, tostring(rs[i]))
    nT = nT + 1
  end
  if buf ~= "" then self:Queue(buf) end

  self:Queue("E:" .. time() .. ":" .. nL .. ":" .. nA .. ":" .. nT)
end

function Sync:Hello()
  self.helloAt = GetTime()
  self:Queue("H")
end

-- Abgleich anstossen. reason: "login" | "manual" | "group"
function Sync:Start(reason)
  local manual = reason == "manual"
  if not self:Peer() then
    if manual then BF:Print(BF.T("MSG_SYNC_NOPEER")) end
    return
  end
  if not SendAddonMessage then
    if manual then BF:Error(BF.T("ERR_SYNC_API")) end
    return
  end
  if not self:Channel() then
    self.pending = true
    if manual then BF:Print(BF.T("MSG_SYNC_NOGROUP")) end
    return
  end
  self.pending = false
  self.rx = { L = 0, A = 0, T = 0 }
  if manual then BF:Print(string.format(BF.T("MSG_SYNC_START"), self:Peer())) end
  self:Hello()
end

-- vor dem Logout: unseren Stand abliefern (ohne Anfrage, der Partner bleibt ja online)
function Sync:LogoutPush()
  if not BananaFarmDB.autoSync then return end
  local peer = self:Peer()
  if not peer or not self:Channel() or not SendAddonMessage then return end
  if GetTime() - self.pushedAt < 60 then return end
  self.pushedAt = GetTime()
  local since = self:State().since[string.lower(peer)] or 0
  self:Push(since)
end

function Sync:Command(rest)
  rest = BF.Trim(rest)
  rest = string.gsub(rest, "%s", "")
  if rest ~= "" then
    BananaFarmDB.syncPeer = rest
    BF:Print(string.format(BF.T("MSG_SYNC_PEER"), rest))
    return
  end
  self:Start("manual")
end

-- ------------------------------------------------------------
-- Empfangen
-- ------------------------------------------------------------
local function applyList(id, c)
  local db = BananaFarmDB
  if c == "V" or c == "M" or c == "I" or c == "K" then
    db.manual[id] = c
    db.auto[id] = nil
    db.unsorted[id] = nil
    db.noSell[id] = nil
  elseif c == "U" then
    db.manual[id] = nil
    db.auto[id] = nil
    db.unsorted[id] = true
  else
    db.manual[id] = nil
    db.auto[id] = nil
    db.unsorted[id] = nil
  end
end

function Sync:OnMessage(msg, sender)
  local db = BananaFarmDB
  local st = self:State()
  local key = string.lower(sender)
  local kind = string.sub(msg, 1, 1)
  local body = string.sub(msg, 3)

  if kind == "H" then
    local now = GetTime()
    if now - self.reqAt < 10 then return end
    self.reqAt = now
    self:Queue("S:" .. (st.last[key] or 0))
    -- Gegenrichtung: auch selbst Hallo sagen, damit der Partner unsere Daten bekommt
    if now - self.helloAt > 30 then self:Hello() end

  elseif kind == "S" then
    local since = tonumber(body) or 0
    st.since[key] = since
    self:Push(since)

  elseif kind == "L" then
    for sid, c, sts in string.gfind(body, "(%d+):([%a%-]):(%d+)") do
      local id, ts = tonumber(sid), tonumber(sts)
      if ts > (db.manualTs[id] or 0) then
        applyList(id, c)
        db.manualTs[id] = ts
        self.rx.L = self.rx.L + 1
      end
    end

  elseif kind == "A" then
    for sid, u, sts, n in string.gfind(body, "(%d+):(%d+):(%d+):(%d+)") do
      local id, ts = tonumber(sid), tonumber(sts)
      local e = db.ah[id]
      if ts > ((e and e.ts) or 0) then
        db.ah[id] = { u = tonumber(u), ts = ts, n = tonumber(n) }
        self.rx.A = self.rx.A + 1
      end
    end

  elseif kind == "T" then
    for ts in string.gfind(body, "(%d+)") do
      if BF.Resets:Merge(tonumber(ts)) then self.rx.T = self.rx.T + 1 end
    end

  elseif kind == "E" then
    local _, _, now = string.find(body, "^(%d+)")
    if now then st.last[key] = tonumber(now) end
    local rx = self.rx
    self.rx = { L = 0, A = 0, T = 0 }
    if rx.L > 0 or rx.A > 0 then BF.Lists:Reclassify() end
    if rx.L > 0 or rx.A > 0 or rx.T > 0 then
      BF:Print(string.format(BF.T("MSG_SYNC_OK"), sender, rx.L, rx.A, rx.T))
    end
    if BF.UI then BF.UI:Refresh() end
  end
end

BF:On("CHAT_MSG_ADDON", function(prefix, msg, dist, sender)
  if prefix ~= PREFIX or type(msg) ~= "string" or type(sender) ~= "string" then return end
  if sender == UnitName("player") then return end
  local peer = Sync:Peer()
  if not peer or string.lower(sender) ~= string.lower(peer) then return end
  Sync:OnMessage(msg, sender)
end)

-- Login: kurz warten, bis Gruppe und Welt stehen
BF:On("PLAYER_ENTERING_WORLD", function()
  if Sync.loginDone then return end
  Sync.loginDone = true
  if BananaFarmDB.autoSync then
    BF:After(10, function() Sync:Start("login") end, "synclogin")
  end
end)

-- Partner war beim Login noch nicht in der Gruppe
BF:On("PARTY_MEMBERS_CHANGED", function()
  if Sync.pending and Sync:Channel() and BananaFarmDB.autoSync then
    Sync.pending = false
    BF:After(5, function() Sync:Start("group") end, "synclogin")
  end
end)

-- Logout: /camp, /logout, Beenden und das Logout-Ereignis selbst
local function hook(name)
  local orig = getglobal(name)
  if type(orig) ~= "function" then return end
  setglobal(name, function(a1, a2)
    if BF.ready then Sync:LogoutPush() end
    return orig(a1, a2)
  end)
end
hook("Logout")
hook("Quit")

BF:On("PLAYER_LOGOUT", function()
  Sync:LogoutPush()
  Sync:Flush()
end)

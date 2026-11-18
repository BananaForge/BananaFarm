-- BananaFarm Sync (0.5.0): haelt Listen, bekannte Items, AH-Preise und Resets mit dem Partner (Twink)
-- gleich. Weg: Addon-Nachrichten ueber PARTY/RAID, der Partner muss in der Gruppe sein.
--
-- Prinzip "Pruefsumme statt Verlauf": Jede Seite rechnet je Bereich eine kleine Pruefsumme.
-- Ein Vergleich kostet eine Nachricht. Nur wenn etwas abweicht, werden die Daten in 16 Faecher
-- (Item-ID modulo 16) aufgeteilt, nur die Faecher verglichen und nur die abweichenden geschickt,
-- in beide Richtungen. Danach wird erneut verglichen. Geht eine Nachricht verloren, faellt das beim
-- naechsten Vergleich auf und wird repariert. Je Eintrag gewinnt der neuere Zeitstempel.
--
-- Bereiche:
--   L  Zuordnungen von Hand: id -> Liste (V M I U, "-" = entfernt) mit Zeitstempel (db.manualTs)
--   N  bekannte Items: alle IDs, die in einer Liste stehen (auch automatisch einsortiert und
--      unsortiert). Der Partner uebernimmt neue IDs (Standardregel oder Unsortiert), damit der
--      Twink sie im AH mitscannt.
--   A  AH-Preise: id -> Preis, Zeitstempel, Stichproben
--   T  Resets der letzten Stunde (Zeitstempel)
--
-- Nachrichten (Praefix BFSYNC, je hoechstens ~200 Zeichen):
--   P:name          Kopplung: "name" soll mich als Partner uebernehmen (nur vom Farmchar)
--   K               Kopplung uebernommen
--   D:hL:hN:hA:hT:f Pruefsummen der vier Bereiche; f = 1: bitte mit Y antworten, wenn alles gleich ist
--   Y               alles gleich
--   B:X:h0,...,h15  Pruefsummen der 16 Faecher des Bereichs X
--   W:X:b,b,...     schick mir deine Eintraege dieser Faecher von X
--   L:/N:/A:/T:     Daten (Formate siehe Push*)
--   R:ts            Reset eben gezaehlt (sofort)
--
-- Zeitpunkte: Login und Gruppenbeitritt des Partners, Zuordnung von Hand (der eine Eintrag geht
-- nach 2 s raus, danach Bestaetigung per Vergleich), neue Items, vor und nach dem AH-Scan, jeder
-- Reset, alle 10 Minuten ein Vergleich (nur wenn der Partner online in der Gruppe ist), /bf sync.

local BF = BananaFarm
local getn = table.getn
local floor = math.floor
local mod = BF.mod

local PREFIX = "BFSYNC"
local CHUNK = 200
local BUCKETS = 16
local AREAS = { "L", "N", "A", "T" }

BF.Sync = { out = {}, dirty = {}, rx = { L = 0, N = 0, A = 0, T = 0 }, rounds = 0, roundsAt = 0 }
local Sync = BF.Sync

-- ------------------------------------------------------------
-- Partner und Kanal
-- ------------------------------------------------------------
local function bare(name)
  name = name or ""
  local _, _, n = string.find(name, "^([^%-]+)")
  return string.lower(n or name)
end

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

-- Farmmain: hat einen Twink eingetragen und selbst keinen Partner uebernommen
function Sync:IsMain()
  local db = BananaFarmDB
  local alt = db.bankAlt
  if not alt or alt == "" or (db.syncPeer and db.syncPeer ~= "") then return false end
  return string.lower(alt) ~= string.lower(UnitName("player") or "")
end

-- Ist der Partner in der Gruppe und online?
function Sync:PeerOnline()
  local peer = self:Peer()
  if not peer or not self:Channel() then return false end
  local low = bare(peer)
  local n = GetNumRaidMembers()
  if n > 0 then
    for i = 1, n do
      local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
      if name and bare(name) == low then return online and true or false end
    end
    return false
  end
  for i = 1, GetNumPartyMembers() do
    local u = "party" .. i
    local name = UnitName(u)
    if name and bare(name) == low then return UnitIsConnected(u) and true or false end
  end
  return false
end

function Sync:Usable()
  return BF:Enabled("sync") and SendAddonMessage ~= nil and self:Peer() ~= nil and self:Channel() ~= nil
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
  if ch and SendAddonMessage then
    if BananaFarmDB.syncDebug then BF:Print("|cff9a9cb3sync >|r " .. string.sub(msg, 1, 60)) end
    SendAddonMessage(PREFIX, msg, ch)
  end
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

-- beim Logout: was noch in der Warteschlange steht, sofort raus
function Sync:Flush()
  while getn(self.out) > 0 do self:RawSend(table.remove(self.out, 1)) end
  self.pumping = false
  BF:Cancel("syncpump")
end

-- Eintraege zu Paketen von hoechstens CHUNK Zeichen buendeln
local function packer(kind)
  local p = { buf = "" }
  function p.add(entry)
    if p.buf == "" then
      p.buf = kind .. ":" .. entry
    elseif string.len(p.buf) + string.len(entry) + 1 > CHUNK then
      Sync:Queue(p.buf)
      p.buf = kind .. ":" .. entry
    else
      p.buf = p.buf .. ";" .. entry
    end
  end
  function p.done()
    if p.buf ~= "" then Sync:Queue(p.buf) end
    p.buf = ""
  end
  return p
end

-- ------------------------------------------------------------
-- Daten der Bereiche
-- ------------------------------------------------------------
function Sync:ListChar(id)
  local db = BananaFarmDB
  local m = db.manual[id]
  if m == "K" then m = "I" end
  if m then return m end
  if db.unsorted[id] then return "U" end
  return "-"
end

-- ruft fn(id, text) fuer jeden Eintrag eines Bereichs (text = was in die Pruefsumme und Nachricht geht)
function Sync:Each(area, fn)
  local db = BananaFarmDB
  if area == "L" then
    for id, ts in pairs(db.manualTs) do fn(id, id .. ":" .. self:ListChar(id) .. ":" .. ts) end
  elseif area == "N" then
    local seen = {}
    local function one(id)
      if not seen[id] then
        seen[id] = true
        fn(id, tostring(id))
      end
    end
    for id in pairs(db.manual) do one(id) end
    for id in pairs(db.auto) do one(id) end
    for id in pairs(db.unsorted) do one(id) end
    for id in pairs(db.manualTs) do one(id) end
  elseif area == "A" then
    for id, e in pairs(db.ah) do
      if e.ts then fn(id, id .. ":" .. floor((e.u or 0) + 0.5) .. ":" .. e.ts .. ":" .. (e.n or 0)) end
    end
  elseif area == "T" then
    local rs = BF.Resets:Prune()
    for i = 1, getn(rs) do fn(0, tostring(rs[i])) end
  end
end

local function strHash(s)
  local h = 5381
  for i = 1, string.len(s) do h = mod(h * 33 + string.byte(s, i), 16777213) end
  return h
end

local DIG = "0123456789abcdefghijklmnopqrstuvwxyz"
local function b36(n)
  n = floor(n)
  if n <= 0 then return "0" end
  local s = ""
  while n > 0 do
    local r = mod(n, 36)
    s = string.sub(DIG, r + 1, r + 1) .. s
    n = floor(n / 36)
  end
  return s
end

local function bucketOf(area, id)
  if area == "T" then return 0 end
  return mod(id, BUCKETS)
end

-- Pruefsummen: gesamt und je Fach. Reihenfolge der Eintraege egal (Summe), Anzahl zaehlt mit.
function Sync:Hashes(area)
  local per, cnt = {}, {}
  for b = 0, BUCKETS - 1 do
    per[b] = 0
    cnt[b] = 0
  end
  self:Each(area, function(id, text)
    local b = bucketOf(area, id)
    per[b] = mod(per[b] + strHash(text), 2147483629)
    cnt[b] = cnt[b] + 1
  end)
  local out, total = {}, 0
  for b = 0, BUCKETS - 1 do
    out[b] = b36(per[b]) .. "." .. b36(cnt[b])
    total = mod(total + per[b] * 31 + cnt[b], 2147483629)
  end
  return out, b36(total)
end

function Sync:Digest()
  local parts = {}
  for i = 1, getn(AREAS) do
    local _, total = self:Hashes(AREAS[i])
    table.insert(parts, total)
  end
  return parts
end

-- Eintraege bestimmter Faecher eines Bereichs senden (want = { [fach] = true })
function Sync:PushBuckets(area, want)
  local p = packer(area)
  self:Each(area, function(id, text)
    if want[bucketOf(area, id)] then p.add(text) end
  end)
  p.done()
end

-- ------------------------------------------------------------
-- Ablauf
-- ------------------------------------------------------------
-- Pruefsummen schicken. ask = true: der Partner antwortet mit Y, wenn alles gleich ist.
function Sync:SendDigest(ask)
  if not self:Usable() then return end
  local d = self:Digest()
  self:Queue("D:" .. table.concat(d, ":") .. ":" .. (ask and "1" or "0"))
end

-- nach einem Abgleich noch einmal vergleichen (hoechstens 4 Runden pro Minute, gegen Endlosschleifen)
function Sync:Verify()
  local now = GetTime()
  if now - self.roundsAt > 60 then
    self.rounds = 0
    self.roundsAt = now
  end
  if self.rounds >= 4 then return end
  self.rounds = self.rounds + 1
  BF:After(4, function() Sync:SendDigest(true) end, "syncverify")
end

-- Abgleich anstossen. reason: "login" | "manual" | "group" | "pair" | "timer" | "scan"
function Sync:Start(reason)
  local manual = reason == "manual"
  local verbose = manual or reason == "pair"
  if not BF:Enabled("sync") then
    if manual then BF:Print(BF.T("ERR_MODULE_OFF")) end
    return
  end
  if not self:Peer() then
    if manual then BF:Print(BF.T("MSG_SYNC_NOPEER")) end
    return
  end
  if not SendAddonMessage then
    if verbose then BF:Error(BF.T("ERR_SYNC_API")) end
    return
  end
  if not self:Channel() then
    self.pending = true
    if verbose then BF:Print(BF.T("MSG_SYNC_NOGROUP")) end
    return
  end
  self.pending = false
  self.manual = manual
  if self:IsMain() then self:Queue("P:" .. BananaFarmDB.bankAlt) end
  if reason == "pair" then
    BF:Print(string.format(BF.T("MSG_SYNC_PAIR"), self:Peer()))
  elseif manual then
    BF:Print(string.format(BF.T("MSG_SYNC_START"), self:Peer()))
  end
  self:SendDigest(true)
end

function Sync:Command(rest)
  rest = string.lower(BF.Trim(rest or ""))
  if rest == "debug" then
    BananaFarmDB.syncDebug = not BananaFarmDB.syncDebug
    BF:Print("Sync debug: " .. (BananaFarmDB.syncDebug and "on" or "off"))
    return
  end
  if rest == "status" then
    local d = self:Digest()
    BF:Print(string.format(BF.T("MSG_SYNC_STATUS"), tostring(self:Peer() or "-"), tostring(self:Channel() or "-"),
      self:PeerOnline() and BF.T("YES") or BF.T("NO"), table.concat(d, " ")))
    return
  end
  self:Start("manual")
end

-- Zuordnung von Hand oder neues Item: nach 2 s gebuendelt weitergeben, danach bestaetigen
function Sync:OnLocalChange(id)
  if self.applying or not id then return end
  self.dirty[id] = true
  BF:After(2, function() Sync:PushDirty() end, "syncdirty")
end

function Sync:PushDirty()
  local ids = self.dirty
  self.dirty = {}
  if not self:Usable() or not BananaFarmDB.autoSync then return end
  local db = BananaFarmDB
  local pl, pn = packer("L"), packer("N")
  local any = false
  for id in pairs(ids) do
    any = true
    pn.add(tostring(id))
    if db.manualTs[id] then pl.add(id .. ":" .. self:ListChar(id) .. ":" .. db.manualTs[id]) end
  end
  if not any then return end
  pn.done()
  pl.done()
  self:Verify()
end

-- Reset gerade gezaehlt: dem Partner sofort Bescheid geben
function Sync:AfterReset(ts)
  if not BananaFarmDB.autoSync or not self:Usable() then return end
  self:Queue("R:" .. ts)
end

-- AH-Scan: vorher abgleichen, damit der Scan alle Items des Partners kennt.
-- true = es laeuft, cb folgt (spaetestens nach 8 s). false = kein Partner online, sofort scannen.
function Sync:PrepareScan(cb)
  if self.prep or not BananaFarmDB.autoSync or not self:Usable() then return false end
  if not self:PeerOnline() then return false end
  self.prep = { cb = cb }
  BF:Print(string.format(BF.T("MSG_SYNC_PRESCAN"), self:Peer()))
  self:SendDigest(true)
  BF:After(8, function() Sync:PrepDone() end, "syncprep")
  return true
end

function Sync:PrepDone()
  local p = self.prep
  if not p then return end
  self.prep = nil
  BF:Cancel("syncprep")
  if p.cb then p.cb() end
end

-- nach dem AH-Scan (und nach Phase 1): Vergleich, die neuen Preise gehen ueber die Faecher raus
function Sync:AfterScan()
  if not BananaFarmDB.autoSync or not self:Usable() or not self:PeerOnline() then return end
  self.rounds = 0
  self:SendDigest(true)
  BF:Print(string.format(BF.T("MSG_SYNC_PRICES"), self:Peer()))
end

-- Kopplungsanfrage des Farmmains: nur wer gemeint ist, uebernimmt sie
function Sync:OnPair(target, sender)
  local db = BananaFarmDB
  if bare(target) ~= bare(UnitName("player")) then return end
  if bare(db.syncPeer) ~= bare(sender) then
    db.syncPeer = sender
    BF:Print(string.format(BF.T("MSG_SYNC_PAIRED"), sender))
    if BF.UI then BF.UI:Refresh() end
    self:Queue("K")
  end
end

-- ------------------------------------------------------------
-- Empfangen
-- ------------------------------------------------------------
local function applyList(id, c)
  local db = BananaFarmDB
  if c == "K" then c = "I" end
  if c == "V" or c == "M" or c == "I" then
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

-- neues Item vom Partner: wie ein eigener Fund einsortieren, aber ohne Pop-up
local function learn(id)
  local db = BananaFarmDB
  if db.manual[id] or db.auto[id] or db.unsorted[id] or db.manualTs[id] then return false end
  BF:ItemInfo(id) -- fragt den Namen beim Server an, falls unbekannt
  local r = BF.Lists:Classify(id)
  if r then db.auto[id] = r else db.unsorted[id] = true end
  return true
end

-- nach empfangenen Daten (gebuendelt): neu einsortieren, Meldung, Bestaetigung
function Sync:Received()
  BF:After(1.5, function()
    local rx = Sync.rx
    Sync.rx = { L = 0, N = 0, A = 0, T = 0 }
    if rx.L > 0 or rx.A > 0 or rx.N > 0 then BF.Lists:Reclassify() end
    if rx.L > 0 or rx.A > 0 or rx.N > 0 or rx.T > 0 then
      BF:Print(string.format(BF.T("MSG_SYNC_OK2"), Sync:Peer() or "?", rx.L, rx.N, rx.A, rx.T))
    end
    if BF.UI then BF.UI:Refresh() end
    Sync:Verify()
  end, "syncrx")
end

function Sync:OnMessage(msg, sender)
  local db = BananaFarmDB
  local kind = string.sub(msg, 1, 1)
  local body = string.sub(msg, 3)
  if db.syncDebug then BF:Print("|cff9a9cb3sync <|r " .. string.sub(msg, 1, 60)) end

  if kind == "D" then
    local parts = {}
    for v in string.gfind(body, "([^:]+)") do table.insert(parts, v) end
    local mine = self:Digest()
    local same = true
    for i = 1, getn(AREAS) do
      if parts[i] ~= mine[i] then
        same = false
        local hashes = self:Hashes(AREAS[i])
        local list = {}
        for b = 0, BUCKETS - 1 do table.insert(list, hashes[b]) end
        self:Queue("B:" .. AREAS[i] .. ":" .. table.concat(list, ","))
      end
    end
    if same then
      if parts[5] == "1" then self:Queue("Y") end
      if self.prep then self:PrepDone() end
    end

  elseif kind == "Y" then
    if self.manual then
      BF:Print(string.format(BF.T("MSG_SYNC_SAME"), sender))
      self.manual = false
    end
    if self.prep then self:PrepDone() end

  elseif kind == "B" then
    local _, _, area, rest = string.find(body, "^(%a):(.*)$")
    if not area then return end
    local theirs = {}
    for v in string.gfind(rest, "([^,]+)") do table.insert(theirs, v) end
    local mine = self:Hashes(area)
    local want, list = {}, {}
    for b = 0, BUCKETS - 1 do
      if theirs[b + 1] ~= mine[b] then
        want[b] = true
        table.insert(list, b)
      end
    end
    if getn(list) == 0 then return end
    self:PushBuckets(area, want)
    self:Queue("W:" .. area .. ":" .. table.concat(list, ","))

  elseif kind == "W" then
    local _, _, area, rest = string.find(body, "^(%a):(.*)$")
    if not area then return end
    local want = {}
    for v in string.gfind(rest, "(%d+)") do want[tonumber(v)] = true end
    self:PushBuckets(area, want)
    self:Verify()

  elseif kind == "L" then
    self.applying = true
    for sid, c, sts in string.gfind(body, "(%d+):([%a%-]):(%d+)") do
      local id, ts = tonumber(sid), tonumber(sts)
      if ts > (db.manualTs[id] or 0) then
        applyList(id, c)
        db.manualTs[id] = ts
        self.rx.L = self.rx.L + 1
      end
    end
    self.applying = false
    self:Received()

  elseif kind == "N" then
    for sid in string.gfind(body, "(%d+)") do
      if learn(tonumber(sid)) then self.rx.N = self.rx.N + 1 end
    end
    self:Received()

  elseif kind == "A" then
    for sid, u, sts, n in string.gfind(body, "(%d+):(%d+):(%d+):(%d+)") do
      local id, ts = tonumber(sid), tonumber(sts)
      local e = db.ah[id]
      if ts > ((e and e.ts) or 0) then
        db.ah[id] = { u = tonumber(u), ts = ts, n = tonumber(n) }
        self.rx.A = self.rx.A + 1
      end
    end
    self:Received()

  elseif kind == "T" then
    for ts in string.gfind(body, "(%d+)") do
      if BF.Resets:Merge(tonumber(ts)) then self.rx.T = self.rx.T + 1 end
    end
    self:Received()

  elseif kind == "R" then
    BF.Resets:Remote(tonumber(body))

  elseif kind == "K" then
    BF:Print(string.format(BF.T("MSG_SYNC_PAIRED_OK"), sender))
  end
end

BF:On("CHAT_MSG_ADDON", function(prefix, msg, dist, sender)
  if prefix ~= PREFIX or type(msg) ~= "string" or type(sender) ~= "string" or not BF:Enabled("sync") then return end
  if bare(sender) == bare(UnitName("player")) then return end
  if string.sub(msg, 1, 2) == "P:" then
    Sync:OnPair(string.sub(msg, 3), sender)
    return
  end
  local peer = Sync:Peer()
  if not peer or bare(sender) ~= bare(peer) then
    if BananaFarmDB.syncDebug then BF:Print("|cff9a9cb3sync: ignoriert von " .. sender .. "|r") end
    return
  end
  Sync:OnMessage(msg, sender)
end)

-- Login: kurz warten, bis Gruppe und Welt stehen
BF:On("PLAYER_ENTERING_WORLD", function()
  if Sync.loginDone then return end
  Sync.loginDone = true
  if BananaFarmDB.autoSync then
    BF:After(10, function() Sync:Start("login") end, "synclogin")
  end
  -- alle 10 Minuten ein Vergleich, solange der Partner online in der Gruppe ist
  local function timer()
    if BananaFarmDB.autoSync and Sync:Usable() and Sync:PeerOnline() then
      Sync.rounds = 0
      Sync:SendDigest(false)
    end
    BF:After(600, timer, "synctimer")
  end
  BF:After(600, timer, "synctimer")
end)

-- Partner kommt in die Gruppe (oder war beim Login noch nicht da)
BF:On("PARTY_MEMBERS_CHANGED", function()
  if not BananaFarmDB.autoSync or not Sync:Channel() then return end
  local online = Sync:PeerOnline()
  if (Sync.pending or (online and not Sync.peerWasOnline)) then
    Sync.pending = false
    BF:After(5, function() Sync:Start("group") end, "synclogin")
  end
  Sync.peerWasOnline = online
end)

BF:On("PLAYER_LOGOUT", function() Sync:Flush() end)

-- BananaFarm Session: Start/Stop, Taschen-Snapshot, Statistik (Items, Gold, Dauer, Gold/h).
-- Waehrend die Session laeuft, wird jedes neue Item erkannt (Differenz zum Snapshot positiv)
-- und automatisch einsortiert.

local BF = BananaFarm
local floor = math.floor

BF.Session = {}
local Session = BF.Session

function Session:OnLoad()
  -- Beim Laden sind Taschen und Gold noch nicht da (Ladebildschirm). Erst nach
  -- PLAYER_ENTERING_WORLD wird der Snapshot genommen, vorher zaehlt nichts als Beute.
  self.snap = nil
  self.settling = true
  local s = BananaFarmDB.session
  -- eine laufende Session ueberlebt /reload und Relog: die Uhr laeuft ab jetzt weiter.
  -- Die bis zum Logout gelaufene Zeit steht in s.elapsed (siehe PLAYER_LOGOUT).
  if s.running then s.t0 = time() end
  -- Sessions aus 0.1.0 kennen noch keinen Run
  s.resets = s.resets or 0
  s.run = s.run or { items = {}, coin = 0, start = s.elapsed or 0 }
end

-- Ein Instanz-Reset beendet den Run und beginnt den naechsten
function Session:NewRun()
  local s = BananaFarmDB.session
  if not s.running then return end
  s.resets = (s.resets or 0) + 1
  s.run = { items = {}, coin = 0, start = self:Elapsed() }
end

-- Wert des laufenden Runs (seit dem letzten Reset) in Kupfer
function Session:RunValue()
  local run = BananaFarmDB.session.run
  if not run then return 0 end
  local sum = run.coin or 0
  for id, c in pairs(run.items) do sum = sum + self:ItemValue(id) * c end
  return sum
end

function Session:RunElapsed()
  local run = BananaFarmDB.session.run
  local e = self:Elapsed() - ((run and run.start) or 0)
  if e < 0 then e = 0 end
  return e
end

-- Zonenwechsel, Login, /reload: Taschen und Gold neu abgleichen, bevor wieder gezaehlt wird
BF:On("PLAYER_ENTERING_WORLD", function()
  Session.settling = true
  BF.money = GetMoney()
  BF:After(3, function()
    Session.snap = BF.BagCounts()
    BF.money = GetMoney()
    Session.settling = false
    if BF.UI then BF.UI:Refresh() end
  end, "sessionsettle")
end)

-- Laufzeit vor Logout/Reload sichern, sonst geht sie verloren (Gold/h wuerde viel zu hoch)
BF:On("PLAYER_LOGOUT", function()
  local s = BananaFarmDB.session
  if s.running then
    s.elapsed = Session:Elapsed()
    s.t0 = nil
  end
end)

function Session:Running()
  return BananaFarmDB.session.running
end

function Session:Start()
  local db = BananaFarmDB
  if db.session.running then return end
  if BF.Speedrun and BF:Enabled("speedrun") then BF.Speedrun:ArchiveSession(db.session) end
  db.session = { running = true, t0 = time(), date = time(), elapsed = 0, items = {}, coin = 0, resets = 0,
    run = { items = {}, coin = 0, start = 0 } }
  self.snap = BF.BagCounts()
  self.warned = nil
  -- was schon in den Taschen liegt, gleich einsortieren (zaehlt nicht als Beute)
  if BF:Enabled("items") then
    for id in pairs(self.snap) do BF.Lists:Seen(id) end
  end
  BF:Print(BF.T("MSG_SESSION_START"))
  if BF.UI then BF.UI:Refresh() end
end

function Session:Stop()
  local s = BananaFarmDB.session
  if not s.running then return end
  s.elapsed = self:Elapsed()
  s.running = false
  s.t0 = nil
  local total = self:Value()
  BF:Print(string.format(BF.T("MSG_SESSION_STOP"), BF.Duration(s.elapsed), BF.Money(total), BF.Money(self:PerHour())))
  if BF.UI then BF.UI:Refresh() end
end

function Session:Toggle()
  if self:Running() then self:Stop() else self:Start() end
end

function Session:Elapsed()
  local s = BananaFarmDB.session
  local e = s.elapsed or 0
  if s.running and s.t0 then e = e + (time() - s.t0) end
  return e
end

-- Wert eines Items fuer den Tracker: was auf der Mailliste steht, zaehlt mit dem AH-Preis,
-- alles andere mit dem Haendlerwert. Verzauberungsmaterial (siehe Entzaubern unten) zaehlt mit
-- dem AH-Preis, falls vorhanden, sonst mit dem Haendlerwert, egal auf welcher Liste es steht.
function Session:ItemValue(id)
  local mats = BananaFarmDB.session.mats
  if mats and mats[id] then
    local ah = BF:AHNet(id)
    if ah then return ah end
    return BF:VendorValue(id) or 0
  end
  if BF.Lists:Eff(id) == "M" then
    local ah = BF:AHNet(id)
    if ah then return ah end
  end
  return BF:VendorValue(id) or 0
end

-- Gesamtwert der Session in Kupfer, dazu Anzahl der Items
function Session:Value()
  local s = BananaFarmDB.session
  local sum, n = s.coin or 0, 0
  for id, c in pairs(s.items) do
    sum = sum + self:ItemValue(id) * c
    n = n + c
  end
  return sum, n
end

function Session:PerHour()
  local e = self:Elapsed()
  if e < 1 then return 0 end
  return floor(self:Value() / e * 3600)
end

-- ------------------------------------------------------------
-- Entzaubern: Das entzauberte Item verschwindet aus der Statistik (sein Wert wird abgezogen),
-- die Mats aus dem Loot-Fenster danach zaehlen mit AH-Preis oder Haendlerwert.
-- Ablauf: SPELLCAST_START (Entzaubern) -> SPELLCAST_STOP -> Item faellt aus der Tasche ->
-- LOOT_OPENED/LOOT_CLOSED -> Mats kommen in die Tasche.
-- ------------------------------------------------------------
local DE_SPELLS = { ["disenchant"] = true, ["entzaubern"] = true, ["désenchanter"] = true, ["desencantar"] = true }

-- Item kann gerade durch das Entzaubern verschwinden (Zauber laeuft oder ist eben fertig)
function Session:DeItemWindow()
  local d = self.de
  if not d then return false end
  if d.cast then return true end
  return d.stopAt ~= nil and GetTime() - d.stopAt <= 5
end

-- Items, die jetzt neu in die Tasche kommen, sind Mats des Entzauberns
function Session:DeMatWindow()
  local d = self.de
  if not d then return false end
  if d.looting then return true end
  return d.lootEnd ~= nil and GetTime() - d.lootEnd <= 3
end

BF:On("SPELLCAST_START", function(name)
  if type(name) == "string" and DE_SPELLS[string.lower(name)] then
    Session.de = { cast = true }
  end
end)

BF:On("SPELLCAST_STOP", function()
  local d = Session.de
  if d and d.cast then
    d.cast = false
    d.stopAt = GetTime()
  end
end)

BF:On("SPELLCAST_INTERRUPTED", function() Session.de = nil end)

BF:On("LOOT_OPENED", function()
  local d = Session.de
  if d and d.stopAt and GetTime() - d.stopAt <= 30 then d.looting = true end
end)

BF:On("LOOT_CLOSED", function()
  local d = Session.de
  if d and d.looting then
    d.looting = false
    d.lootEnd = GetTime()
  end
end)

-- zieht hoechstens ab, was die Statistik von diesem Item kennt
local function uncount(t, id, lost)
  local have = t and t[id] or 0
  if have <= 0 then return end
  have = have - lost
  if have > 0 then t[id] = have else t[id] = nil end
end

-- Taschen haben sich geaendert: Differenz zum Snapshot auswerten
function Session:OnBags()
  local now = BF.BagCounts()
  local s = BananaFarmDB.session
  if self.settling then return end
  if s.running and self.snap and not BF.Busy() then
    if BF:Enabled("items") then
      local deItem = self:DeItemWindow()
      local deMat = self:DeMatWindow()
      for id, c in pairs(now) do
        local d = c - (self.snap[id] or 0)
        if d > 0 then
          s.items[id] = (s.items[id] or 0) + d
          s.run.items[id] = (s.run.items[id] or 0) + d
          if deMat then
            s.mats = s.mats or {}
            s.mats[id] = true
          end
          BF.Lists:Seen(id)
        end
      end
      -- entzaubert: der Itemwert faellt aus der Statistik
      if deItem then
        for id, c in pairs(self.snap) do
          local lost = c - (now[id] or 0)
          if lost > 0 then
            uncount(s.items, id, lost)
            uncount(s.run.items, id, lost)
          end
        end
      end
      -- Zustand aufraeumen, wenn nichts mehr zu erwarten ist
      local de = self.de
      if de and not de.cast and not de.looting then
        local last = de.lootEnd or de.stopAt
        if last and GetTime() - last > 40 then self.de = nil end
      end
    end
    local warn = BananaFarmDB.bagWarn or 0
    if warn > 0 then
      local free = BF.FreeSlots()
      if free <= warn and not self.warned then
        self.warned = true
        BF:Error(string.format(BF.T("MSG_BAGS_FULL"), free))
        if UIErrorsFrame then UIErrorsFrame:AddMessage(string.format(BF.T("MSG_BAGS_FULL"), free), 1, 0.3, 0.2) end
      elseif free > warn then
        self.warned = nil
      end
    end
  end
  self.snap = now
  if BF.UI then BF.UI:RefreshList() end
end

-- BAG_UPDATE feuert pro Tasche und oft mehrfach: zusammenfassen
BF:On("BAG_UPDATE", function()
  BF:After(0.3, function() Session:OnBags() end, "bags")
end)

-- gelootetes Gold: positive Aenderung, solange kein Haendler/Post/AH/Handel offen ist
BF:On("PLAYER_MONEY", function()
  local now = GetMoney()
  local delta = now - (BF.money or now)
  BF.money = now
  local s = BananaFarmDB.session
  if s.running and delta > 0 and not BF.Busy() and not Session.settling then
    s.coin = (s.coin or 0) + delta
    s.run.coin = (s.run.coin or 0) + delta
  end
end)

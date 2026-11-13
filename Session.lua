-- BananaFarm Session: Start/Stop, Taschen-Snapshot, Statistik (Items, Gold, Dauer, Gold/h).
-- Waehrend die Session laeuft, wird jedes neue Item erkannt (Differenz zum Snapshot positiv)
-- und automatisch einsortiert.

local BF = BananaFarm
local floor = math.floor

BF.Session = {}
local Session = BF.Session

function Session:OnLoad()
  self.snap = BF.BagCounts()
  local s = BananaFarmDB.session
  -- eine laufende Session ueberlebt /reload und Relog: die Uhr laeuft ab jetzt weiter
  if s.running then s.t0 = time() end
end

function Session:Running()
  return BananaFarmDB.session.running
end

function Session:Start()
  local db = BananaFarmDB
  if db.session.running then return end
  db.session = { running = true, t0 = time(), elapsed = 0, items = {}, coin = 0 }
  self.snap = BF.BagCounts()
  self.warned = nil
  -- was schon in den Taschen liegt, gleich einsortieren (zaehlt nicht als Beute)
  for id in pairs(self.snap) do BF.Lists:Seen(id) end
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
-- alles andere mit dem Haendlerwert.
function Session:ItemValue(id)
  if BF.Lists:Get(id) == "M" then
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

-- Taschen haben sich geaendert: Differenz zum Snapshot auswerten
function Session:OnBags()
  local now = BF.BagCounts()
  local s = BananaFarmDB.session
  if s.running and self.snap and not BF.Busy() then
    for id, c in pairs(now) do
      local d = c - (self.snap[id] or 0)
      if d > 0 then
        s.items[id] = (s.items[id] or 0) + d
        BF.Lists:Seen(id)
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
  if s.running and delta > 0 and not BF.Busy() then
    s.coin = (s.coin or 0) + delta
  end
end)

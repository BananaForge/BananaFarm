-- BananaFarm Haendler: beim Oeffnen eines Haendlers (z. B. Repairbot) die Vendorliste verkaufen.
-- Ein Stapel alle 0,15 s per UseContainerItem; danach Abgleich: was der Haendler nicht nimmt, wird gemerkt.
-- Nebenbei lernt das Addon den echten Stueckpreis (Gold-Differenz pro Verkauf).

local BF = BananaFarm
local getn = table.getn
local floor = math.floor

BF.Vendor = {}
local Vendor = BF.Vendor

function Vendor:Collect()
  local list = {}
  local db = BananaFarmDB
  BF.EachBagItem(function(bag, slot, id, count, locked)
    if not locked and BF.Lists:Eff(id) == "V" and not db.noSell[id] then
      table.insert(list, { bag = bag, slot = slot, id = id, c = count })
    end
  end)
  return list
end

function Vendor:Start()
  if self.run then return end
  if not BF.merchantOpen then
    BF:Print(BF.T("ERR_NO_MERCHANT"))
    return
  end
  local list = self:Collect()
  if getn(list) == 0 then return end
  self.run = { list = list, idx = 1, tried = {}, money0 = GetMoney(), last = GetMoney(), pending = 0 }
  self:Step()
end

function Vendor:Step()
  local r = self.run
  if not r then return end
  if not BF.merchantOpen then return self:Finish() end
  local p = r.list[r.idx]
  if not p then
    -- dem Server Zeit fuer die letzten Verkaeufe lassen, dann abgleichen
    BF:After(1.0, function() Vendor:Finish() end, "vendorstep")
    return
  end
  r.idx = r.idx + 1
  local id = BF.ItemID(GetContainerItemLink(p.bag, p.slot))
  local _, count = GetContainerItemInfo(p.bag, p.slot)
  if id == p.id and (count or 1) == p.c and BF.Lists:Eff(id) == "V" then
    if CursorHasItem() then ClearCursor() end
    self.selling = true
    UseContainerItem(p.bag, p.slot)
    self.selling = nil
    table.insert(r.tried, p)
    r.pending = r.pending + 1
    r.lastSold = p
  end
  BF:After(0.15, function() Vendor:Step() end, "vendorstep")
end

-- Stueckpreis lernen: nur wenn genau ein Verkauf zwischen zwei Gold-Aenderungen lag
BF:On("PLAYER_MONEY", function()
  local r = Vendor.run
  if not r then return end
  local now = GetMoney()
  local delta = now - r.last
  r.last = now
  if r.pending == 1 and r.lastSold and delta > 0 then
    local p = r.lastSold
    local unit = floor(delta / p.c)
    if unit > 0 and unit * p.c == delta then BananaFarmDB.learned[p.id] = unit end
  end
  r.pending = 0
end)

function Vendor:Finish()
  local r = self.run
  if not r then return end
  self.run = nil
  BF:Cancel("vendorstep")
  local sold, items = 0, 0
  local refused = {}
  for i = 1, getn(r.tried) do
    local p = r.tried[i]
    local id = BF.ItemID(GetContainerItemLink(p.bag, p.slot))
    if id == p.id then
      -- liegt noch da: der Haendler nimmt es nicht. Nur merken, solange er offen ist
      -- (sonst war bloss das Fenster zu schnell zu).
      if BF.merchantOpen and not refused[id] then
        refused[id] = true
        BananaFarmDB.noSell[id] = true
        BF:Print(string.format(BF.T("MSG_NOSELL"), BF:ColoredName(id)))
      end
    else
      sold = sold + 1
      items = items + p.c
    end
  end
  local income = GetMoney() - r.money0
  if sold > 0 then
    BF:Print(string.format(BF.T("MSG_SOLD"), sold, items, BF.Money(income)))
  end
  if BF.UI then BF.UI:Refresh() end
end

-- Verkaufsschutz: solange eine Session laeuft, laesst sich beim Haendler von Hand nur verkaufen,
-- was auf der Vendorliste steht. Alt gedrueckt halten hebt den Schutz fuer diesen Klick auf.
-- Der Haken sitzt auf UseContainerItem, damit er auch mit Taschen-Addons greift.
local origUse
function Vendor:HookUse()
  if origUse or not UseContainerItem then return end
  origUse = UseContainerItem
  UseContainerItem = function(bag, slot, a3)
    if BF.ready and BF.merchantOpen and not Vendor.selling and BananaFarmDB.protect
      and BF.Session:Running() and not IsAltKeyDown() then
      local id = BF.ItemID(GetContainerItemLink(bag, slot))
      if id and BF.Lists:Eff(id) ~= "V" then
        local now = GetTime()
        if not Vendor.lastBlock or now - Vendor.lastBlock > 1 then
          Vendor.lastBlock = now
          BF:Print(string.format(BF.T("MSG_PROTECTED"), BF:ColoredName(id)))
        end
        return
      end
    end
    return origUse(bag, slot, a3)
  end
end

BF:On("MERCHANT_SHOW", function()
  if not BananaFarmDB.autoSell then return end
  BF:After(0.3, function() Vendor:Start() end, "vendorstart")
end)

BF:On("MERCHANT_CLOSED", function()
  BF:Cancel("vendorstart")
  if Vendor.run then Vendor:Finish() end
end)

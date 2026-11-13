-- BananaFarm Preise: Haendlerwert und gezielter Auktionshaus-Scan.
-- Anders als in BananaBank wird der AH-Preis NICHT halbiert: hier zaehlt der volle Marktpreis
-- (Schnitt der guenstigsten 30 Prozent der Sofortkaufpreise pro Stueck).

local BF = BananaFarm
local getn = table.getn
local floor = math.floor

BF.PRICE_SHARE = 0.30
BF.AH_PAGE = 50
BF.AH_MAX_PAGES = 5
BF.AH_CUT = 0.05

-- ------------------------------------------------------------
-- Haendlerwert
-- ------------------------------------------------------------
-- Reihenfolge: beim Haendler selbst beobachtet (stimmt fuer diesen Server sicher),
-- dann die Tabelle aus ShaguTweaks, zuletzt Nampower (GetItemStats), falls vorhanden.
local npCache = {}
function BF:VendorValue(id)
  local v = BananaFarmDB.learned[id]
  if v and v > 0 then return v end
  v = BF.VendorDB and BF.VendorDB[id]
  if v and v > 0 then return v end
  if v == nil and GetItemStats then
    if npCache[id] == nil then
      npCache[id] = false
      local ok, t = pcall(GetItemStats, id)
      if ok and type(t) == "table" and type(t.sellPrice) == "number" then npCache[id] = t.sellPrice end
    end
    v = npCache[id]
    if v and v > 0 then return v end
  end
  return nil
end

-- ------------------------------------------------------------
-- AH-Preis
-- ------------------------------------------------------------
-- voller AH-Preis pro Stueck, nil wenn nie gefunden
function BF:AHPrice(id)
  local p = BananaFarmDB.ah[id]
  if p and p.u and p.u > 0 then return p.u, p.ts, p.n end
  return nil
end

-- AH-Preis so, wie die Sortierregel und der Tracker ihn rechnen (wahlweise abzueglich Gebuehr)
function BF:AHNet(id)
  local u = self:AHPrice(id)
  if not u then return nil end
  if BananaFarmDB.ahCut then u = floor(u * (1 - BF.AH_CUT)) end
  return u
end

-- Wurde schon gesucht und nichts gefunden?
function BF:AHAbsent(id)
  local p = BananaFarmDB.ah[id]
  return p ~= nil and (p.u or 0) == 0
end

local function fromSamples(list)
  table.sort(list)
  local n = getn(list)
  local take = floor(n * BF.PRICE_SHARE + 0.5)
  if take < 1 then take = 1 end
  local sum = 0
  for i = 1, take do sum = sum + list[i] end
  local p = floor(sum / take)
  if p < 1 then p = 1 end
  return p, n
end

-- ------------------------------------------------------------
-- Auktionshaus-Scan
-- ------------------------------------------------------------
-- Gezielte Suche: eine Abfrage pro bekanntem Item (alles, was in einer Liste steht oder unsortiert ist).
-- Graue Items und ignorierte Items werden nicht gesucht.
function BF:ScanTargets()
  local db = BananaFarmDB
  local seen, ids = {}, {}
  local function add(id)
    if seen[id] then return end
    seen[id] = true
    if self.Lists:Get(id) == "I" then return end
    local name, q = self:ItemInfo(id)
    if q == 0 or not name or string.find(name, "^#%d") then return end
    table.insert(ids, id)
  end
  for id in pairs(db.manual) do add(id) end
  for id in pairs(db.auto) do add(id) end
  for id in pairs(db.unsorted) do add(id) end
  -- zuerst die Items ohne Preis, dann die mit dem aeltesten Scan
  table.sort(ids, function(a, b)
    local ta = db.ah[a] and db.ah[a].ts or 0
    local tb = db.ah[b] and db.ah[b].ts or 0
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  return ids
end

function BF:StartAHScan()
  if not self.ahOpen then
    self:Print(self.T("ERR_NO_AH"))
    return
  end
  if self.scan then return end
  local ids = self:ScanTargets()
  if getn(ids) == 0 then
    self:Print(self.T("MSG_AH_NOTHING"))
    return
  end
  self.scan = { ids = ids, idx = 1, set = 0, none = 0, page = 0, hits = {}, started = GetTime() }
  self:Print(string.format(self.T("MSG_AH_START"), getn(ids)))
  if self.UI then self.UI:Refresh() end
  self:AHQuery()
end

function BF:StopAHScan(silent)
  if not self.scan then return end
  self.scan = nil
  self:Cancel("ahq")
  self:Cancel("ahtimeout")
  if not silent then self:Print(self.T("MSG_AH_ABORT")) end
  self.Lists:Reclassify()
  if self.UI then self.UI:Refresh() end
end

function BF:AHQuery()
  local s = self.scan
  if not s then return end
  if not self.ahOpen then return self:StopAHScan() end
  local id = s.ids[s.idx]
  if not id then return self:FinishAHScan() end
  if CanSendAuctionQuery and not CanSendAuctionQuery() then
    self:After(0.4, function() BF:AHQuery() end, "ahq")
    return
  end
  local name = self:ItemInfo(id)
  s.waiting = id
  -- Die Namenssuche ist eine Teilstring-Suche. Gefiltert wird ueber die Item-ID,
  -- und bei vielen Treffern blaettern wir ein paar Seiten weiter.
  QueryAuctionItems(name, nil, nil, nil, nil, nil, s.page, nil, nil)
  self:After(10, function()
    if BF.scan and BF.scan.waiting then
      BF.scan.waiting = nil
      BF:FinishTarget()
    end
  end, "ahtimeout")
end

function BF:FinishTarget()
  local s = self.scan
  if not s then return end
  local id = s.ids[s.idx]
  if id then
    if getn(s.hits) > 0 then
      local price, samples = fromSamples(s.hits)
      BananaFarmDB.ah[id] = { u = price, ts = time(), n = samples }
      s.set = s.set + 1
    else
      -- nichts gefunden: mit Datum merken, damit klar ist, dass gesucht wurde
      BananaFarmDB.ah[id] = { u = 0, ts = time(), n = 0 }
      s.none = s.none + 1
    end
  end
  s.idx = s.idx + 1
  s.page = 0
  s.hits = {}
  if self.UI then self.UI:RefreshScan() end
  if s.idx > getn(s.ids) then
    self:FinishAHScan()
  else
    self:After(0.3, function() BF:AHQuery() end, "ahq")
  end
end

BF:On("AUCTION_ITEM_LIST_UPDATE", function()
  local s = BF.scan
  if not s or not s.waiting then return end
  local id = s.waiting
  s.waiting = nil
  BF:Cancel("ahtimeout")

  local batch, total = GetNumAuctionItems("list")
  batch = batch or 0
  total = total or batch
  for i = 1, batch do
    local _, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
    local lid = BF.ItemID(GetAuctionItemLink("list", i))
    if lid == id and buyout and buyout > 0 and count and count > 0 then
      table.insert(s.hits, floor(buyout / count))
    end
  end

  local nextPage = s.page + 1
  if batch > 0 and nextPage * BF.AH_PAGE < total and nextPage < BF.AH_MAX_PAGES then
    s.page = nextPage
    BF:After(0.3, function() BF:AHQuery() end, "ahq")
    return
  end
  BF:FinishTarget()
end)

BF:On("AUCTION_HOUSE_CLOSED", function()
  if BF.scan then BF:StopAHScan() end
end)

function BF:FinishAHScan()
  local s = self.scan
  self.scan = nil
  if not s then return end
  self:Cancel("ahq")
  self:Cancel("ahtimeout")
  self:Print(string.format(self.T("MSG_AH_DONE"), getn(s.ids), s.set, s.none,
    floor((GetTime() - s.started) + 0.5)))
  -- neue Preise koennen automatische Zuordnungen kippen und Unsortiertes einsortieren
  local moved = self.Lists:Reclassify()
  if moved > 0 then self:Print(string.format(self.T("MSG_RESORTED"), moved)) end
  if self.UI then self.UI:Refresh() end
end

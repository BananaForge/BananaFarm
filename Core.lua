-- BananaFarm - Lasher-Farmhilfe fuer Duesterbruch Ost auf OctoWoW (Vanilla 1.12, Lua 5.0)
-- Teil von BananaForge. Befehl: /bf oder /bananafarm
--
-- Vanilla-Regeln, die hier ueberall gelten:
--   * Lua 5.0: kein #, kein %, kein string.match/gmatch, kein select, keine "..."-Argumente
--   * Script-Handler bekommen keine Parameter: this, event, arg1..arg9 sind Globale
--   * kein SetSize, kein SetColorTexture

BananaFarm = {}
local BF = BananaFarm

BF.VERSION = "0.1.0"

local getn = table.getn
local floor = math.floor
local mod = math.mod or math.fmod
BF.mod = mod

-- ------------------------------------------------------------
-- Ausgabe
-- ------------------------------------------------------------
function BF:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100BananaFarm:|r " .. tostring(msg))
end

function BF:Error(msg)
  self:Print("|cffff4040" .. tostring(msg) .. "|r")
end

-- ------------------------------------------------------------
-- Werkzeuge
-- ------------------------------------------------------------
function BF.Count(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

function BF.Trim(s)
  s = string.gsub(s or "", "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

-- Zahl und Einheit in der Farbe der Muenze, fuehrende Nullen fallen weg
function BF.Money(copper)
  copper = floor(copper or 0)
  local neg = copper < 0
  if neg then copper = -copper end
  local g = floor(copper / 10000)
  local s = floor(mod(copper, 10000) / 100)
  local c = mod(copper, 100)
  local out = neg and "-" or ""
  if g > 0 then out = out .. "|cffffd700" .. g .. "g|r " end
  if g > 0 or s > 0 then out = out .. "|cffc7c7cf" .. s .. "s|r " end
  -- ab 10 Gold interessiert das Kupfer nicht mehr
  if g < 10 then out = out .. "|cffeda55f" .. c .. "c|r" end
  return out
end

function BF.Duration(sec)
  sec = floor(sec or 0)
  local h = floor(sec / 3600)
  local m = floor(mod(sec, 3600) / 60)
  local s = mod(sec, 60)
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

-- ------------------------------------------------------------
-- Item-Hilfen
-- ------------------------------------------------------------
BF.QUALITY_COLOR = {
  [0] = { 0.62, 0.62, 0.62, "9d9d9d" },
  [1] = { 1.00, 1.00, 1.00, "ffffff" },
  [2] = { 0.12, 1.00, 0.00, "1eff00" },
  [3] = { 0.00, 0.44, 0.87, "0070dd" },
  [4] = { 0.64, 0.21, 0.93, "a335ee" },
  [5] = { 1.00, 0.50, 0.00, "ff8000" },
}

function BF.ItemID(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return tonumber(id)
end

-- Name, Qualitaet, Icon, Itemart zu einer ID. Was der Client einmal kannte, merken wir uns,
-- damit die Listen auch nach einem geleerten Cache lesbar bleiben.
function BF:ItemInfo(id)
  local db = BananaFarmDB
  local name, _, q, _, itype, _, _, _, tex = GetItemInfo(id)
  if name then
    local e = db.items[id]
    if not e then
      e = {}
      db.items[id] = e
    end
    e.n, e.q, e.t, e.y = name, q or 1, tex, itype
    return name, q or 1, tex, itype
  end
  local e = db.items[id]
  if e then return e.n, e.q or 1, e.t, e.y end
  return "#" .. id, 1, nil, nil
end

function BF:ColoredName(id)
  local n, q = self:ItemInfo(id)
  local c = BF.QUALITY_COLOR[q or 1] or BF.QUALITY_COLOR[1]
  return "|cff" .. c[4] .. n .. "|r"
end

-- ruft fn(bag, slot, id, count, locked) fuer jeden belegten Taschenplatz
function BF.EachBagItem(fn)
  for bag = 0, 4 do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local id = BF.ItemID(link)
        if id then
          local _, count, locked = GetContainerItemInfo(bag, slot)
          count = count or 1
          if count < 1 then count = 1 end
          fn(bag, slot, id, count, locked)
        end
      end
    end
  end
end

-- Stueckzahl je Item-ID in den Taschen
function BF.BagCounts()
  local t = {}
  BF.EachBagItem(function(bag, slot, id, count)
    t[id] = (t[id] or 0) + count
  end)
  return t
end

function BF.FreeSlots()
  local free = 0
  for bag = 0, 4 do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      if not GetContainerItemLink(bag, slot) then free = free + 1 end
    end
  end
  return free
end

-- Seelengebunden? 1.12 hat dafuer kein API-Feld, also den Tooltip lesen.
local tip
local SOUL = { ["Soulbound"] = true, ["Seelengebunden"] = true }
if ITEM_SOULBOUND then SOUL[ITEM_SOULBOUND] = true end
function BF.IsSoulbound(bag, slot)
  if not tip then
    tip = CreateFrame("GameTooltip", "BananaFarmScanTip", UIParent, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  tip:ClearLines()
  tip:SetBagItem(bag, slot)
  for i = 2, (tip:NumLines() or 0) do
    local fs = getglobal("BananaFarmScanTipTextLeft" .. i)
    local line = fs and fs:GetText()
    if line and SOUL[line] then return true end
  end
  return false
end

-- Ein Fenster offen, in dem sich Taschen und Gold aus anderen Gruenden aendern?
function BF.Busy()
  if BF.mailOpen or BF.merchantOpen or BF.ahOpen or BF.bankOpen or BF.tradeOpen then return true end
  return false
end

-- ------------------------------------------------------------
-- Datenbank
-- ------------------------------------------------------------
BF.DEFAULTS = {
  lang = "auto",
  bankAlt = "",
  threshold = 1.5,     -- Mailliste, wenn AH-Preis >= Schwelle x Haendlerwert
  minAH = 0,           -- Mindest-AH-Preis in Kupfer
  ahCut = true,        -- AH-Preis abzueglich 5 % Gebuehr rechnen
  grayVendor = true,   -- graue Items automatisch auf die Vendorliste
  popup = true,        -- Pop-up fuer unsortierte Items
  autoSell = true,     -- beim Haendler automatisch verkaufen
  mailAsk = true,      -- am Briefkasten nachfragen
  altClick = true,     -- Alt+Klick in der Tasche ordnet zu
  bar = true,          -- kleine Leiste anzeigen
  bagWarn = 4,         -- Warnung ab so wenigen freien Plaetzen (0 = aus)
}

function BF:InitDB()
  BananaFarmDB = BananaFarmDB or {}
  local db = BananaFarmDB
  for k, v in pairs(BF.DEFAULTS) do
    if db[k] == nil then db[k] = v end
  end
  local first = db.manual == nil
  db.manual = db.manual or {}     -- [id] = "V" | "M" | "I"  (von Hand, schlaegt die Automatik)
  db.auto = db.auto or {}         -- [id] = "V" | "M" | "I"  (aus der Standardregel)
  db.unsorted = db.unsorted or {} -- [id] = true
  db.items = db.items or {}       -- [id] = { n = Name, q = Qualitaet, t = Icon, y = Itemart }
  db.ah = db.ah or {}             -- [id] = { u = Kupfer pro Stueck, ts = Zeit, n = Stichproben }
  db.learned = db.learned or {}   -- [id] = beim Haendler beobachteter Stueckpreis
  db.noSell = db.noSell or {}     -- [id] = true: der Haendler nimmt es nicht
  db.pos = db.pos or {}
  db.session = db.session or { running = false, elapsed = 0, items = {}, coin = 0 }
  if first then db.manual[6948] = "I" end -- Ruhestein
end

-- ------------------------------------------------------------
-- Timer (eine OnUpdate-Schleife fuer alles)
-- ------------------------------------------------------------
BF.timers = {}
function BF:After(sec, fn, key)
  key = key or tostring(fn)
  self.timers[key] = { at = GetTime() + sec, fn = fn }
end

function BF:Cancel(key)
  self.timers[key] = nil
end

local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function()
  local now = GetTime()
  local due
  for key, t in pairs(BF.timers) do
    if now >= t.at then
      due = due or {}
      table.insert(due, key)
    end
  end
  if due then
    for i = 1, getn(due) do
      local t = BF.timers[due[i]]
      BF.timers[due[i]] = nil
      if t then t.fn() end
    end
  end
end)

-- ------------------------------------------------------------
-- Ereignisse: jedes Modul meldet sich mit BF:On(event, fn) an
-- ------------------------------------------------------------
BF.handlers = {}
local eventFrame = CreateFrame("Frame")
BF.eventFrame = eventFrame

function BF:On(ev, fn)
  if not self.handlers[ev] then
    self.handlers[ev] = {}
    eventFrame:RegisterEvent(ev)
  end
  table.insert(self.handlers[ev], fn)
end

eventFrame:SetScript("OnEvent", function()
  local list = BF.handlers[event]
  if not list then return end
  -- vor VARIABLES_LOADED gibt es noch keine Datenbank
  if not BF.ready and event ~= "VARIABLES_LOADED" then return end
  local a1, a2, a3, a4 = arg1, arg2, arg3, arg4
  for i = 1, getn(list) do list[i](a1, a2, a3, a4) end
end)

BF:On("VARIABLES_LOADED", function()
  BF:InitDB()
  BF.ready = true
  BF.money = GetMoney()
  if BF.UI then BF.UI:Init() end
  if BF.Session then BF.Session:OnLoad() end
  BF:Print(string.format(BF.T("MSG_LOADED"), BF.VERSION))
end)

BF:On("MAIL_SHOW", function() BF.mailOpen = true end)
BF:On("MAIL_CLOSED", function() BF.mailOpen = false end)
BF:On("MERCHANT_SHOW", function() BF.merchantOpen = true end)
BF:On("MERCHANT_CLOSED", function() BF.merchantOpen = false end)
BF:On("AUCTION_HOUSE_SHOW", function() BF.ahOpen = true end)
BF:On("AUCTION_HOUSE_CLOSED", function() BF.ahOpen = false end)
BF:On("BANKFRAME_OPENED", function() BF.bankOpen = true end)
BF:On("BANKFRAME_CLOSED", function() BF.bankOpen = false end)
BF:On("TRADE_SHOW", function() BF.tradeOpen = true end)
BF:On("TRADE_CLOSED", function() BF.tradeOpen = false end)

-- ------------------------------------------------------------
-- Slash-Befehle
-- ------------------------------------------------------------
SLASH_BANANAFARM1 = "/bf"
SLASH_BANANAFARM2 = "/bananafarm"
SlashCmdList["BANANAFARM"] = function(msg)
  if not BF.ready then return end
  msg = BF.Trim(msg)
  local _, _, cmd, rest = string.find(msg, "^(%S+)%s*(.*)$")
  cmd = string.lower(cmd or "")
  rest = rest or ""
  if cmd == "" then
    BF.UI:Toggle()
  elseif cmd == "probe" then
    BF:Probe()
  elseif cmd == "lang" then
    rest = string.lower(rest)
    if rest == "de" or rest == "en" or rest == "auto" then
      BF.UI:SetLanguage(rest)
    else
      BF:Print("/bf lang de | en | auto")
    end
  elseif cmd == "start" then
    BF.Session:Start()
  elseif cmd == "stop" then
    BF.Session:Stop()
  elseif cmd == "scan" then
    BF:StartAHScan()
  elseif cmd == "alt" then
    BF:SetBankAlt(rest)
  elseif cmd == "bar" then
    BananaFarmDB.bar = not BananaFarmDB.bar
    BF.UI:Refresh()
  elseif cmd == "mail" then
    BF.Mail:Start()
  elseif cmd == "sell" then
    BF.Vendor:Start()
  else
    for i = 1, 9 do BF:Print(BF.T("HELP_" .. i)) end
  end
end

function BF:SetBankAlt(name)
  name = BF.Trim(name)
  name = string.gsub(name, "%s", "")
  BananaFarmDB.bankAlt = name
  if name == "" then
    self:Print(self.T("MSG_ALT_CLEARED"))
  else
    self:Print(string.format(self.T("MSG_ALT_SET"), name))
  end
  if self.UI then self.UI:Refresh() end
end

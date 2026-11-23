-- BananaFarm - Lasher-Farmhilfe fuer Duesterbruch Ost auf OctoWoW (Vanilla 1.12, Lua 5.0)
-- Teil von BananaForge. Befehl: /bf oder /bananafarm
--
-- Vanilla-Regeln, die hier ueberall gelten:
--   * Lua 5.0: kein #, kein %, kein string.match/gmatch, kein select, keine "..."-Argumente
--   * Script-Handler bekommen keine Parameter: this, event, arg1..arg9 sind Globale
--   * kein SetSize, kein SetColorTexture

BananaFarm = {}
local BF = BananaFarm

BF.VERSION = "0.7.1"
BF.ICON = "Interface\\AddOns\\BananaFarm\\Icon"
BF.CHAMP_ICON = "Interface\\AddOns\\BananaFarm\\Champions"
BF.EVENT_BANNER = "Interface\\AddOns\\BananaFarm\\Event"

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
  self:QueryItem(id)
  return "#" .. id, 1, nil, nil
end

-- ------------------------------------------------------------
-- Unbekannte Items vom Server nachladen (z. B. Items, die nur der Partner kennt):
-- ein unsichtbarer Tooltip mit dem Item-Link loest die Abfrage aus. Je Schritt hoechstens 3 IDs,
-- jede ID wird bis zu 3-mal versucht. Sobald der Client das Item kennt, steht es in db.items.
-- ------------------------------------------------------------
BF.itemQ = { list = {}, set = {}, check = {}, tries = {} }

function BF:QueryItem(id)
  local q = self.itemQ
  if type(id) ~= "number" or id < 1 or id > 99999 then return end
  if q.set[id] or (q.tries[id] or 0) >= 3 then return end
  q.set[id] = true
  table.insert(q.list, id)
  if not q.running then
    q.running = true
    self:After(0.5, function() BF:ItemQueryStep() end, "itemquery")
  end
end

function BF:ItemQueryStep()
  local q = self.itemQ
  if not q.tip then
    q.tip = CreateFrame("GameTooltip", "BananaFarmItemTip", UIParent, "GameTooltipTemplate")
  end
  local changed = false
  -- zuvor Angefragte: angekommen?
  local check = q.check
  q.check = {}
  for i = 1, getn(check) do
    local id = check[i]
    if GetItemInfo(id) then
      self:ItemInfo(id)
      changed = true
    elseif (q.tries[id] or 0) < 3 then
      self:QueryItem(id)
    end
  end
  -- neue Anfragen
  local n = 0
  while getn(q.list) > 0 and n < 3 do
    local id = table.remove(q.list, 1)
    q.set[id] = nil
    if GetItemInfo(id) then
      self:ItemInfo(id)
      changed = true
    else
      q.tries[id] = (q.tries[id] or 0) + 1
      q.tip:SetOwner(UIParent, "ANCHOR_NONE")
      q.tip:SetHyperlink("item:" .. id .. ":0:0:0")
      q.tip:Hide()
      table.insert(q.check, id)
      n = n + 1
    end
  end
  if changed and self.UI then self.UI:Refresh() end
  if getn(q.list) > 0 or getn(q.check) > 0 then
    self:After(0.6, function() BF:ItemQueryStep() end, "itemquery")
  else
    q.running = false
  end
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
-- Module: einzeln ein- und ausschaltbar. Ein ausgeschaltetes Modul bleibt stumm
-- (keine Fenster, keine Abfragen, keine Hooks mit Wirkung). vendor und mail brauchen items.
-- ------------------------------------------------------------
BF.MODULES = { "tracking", "items", "vendor", "mail", "resets", "pulls", "speedrun", "wish", "sync", "champ", "event" }
-- Module, die ausgeschaltet starten (alle anderen sind beim ersten Start an)
BF.MODULE_OFF = { champ = true, event = true }
BF.MODULE_NEEDS = { vendor = "items", mail = "items", champ = "speedrun", event = "speedrun" }

function BF:Enabled(name)
  local m = BananaFarmDB and BananaFarmDB.modules
  if not m then return true end
  if m[name] == false then return false end
  local need = BF.MODULE_NEEDS[name]
  if need and m[need] == false then return false end
  return true
end

-- Wer ein Modul einschaltet, das ein anderes braucht, schaltet dieses mit ein
function BF:SetModule(name, on)
  local m = BananaFarmDB.modules
  m[name] = on and true or false
  local need = BF.MODULE_NEEDS[name]
  if on and need then m[need] = true end
  -- Event-Modul: Kanal betreten oder verlassen
  if name == "event" and BF.Event then BF.Event:OnModule(on) end
  -- Speedrun angeschaltet: Regeln zeigen
  if name == "speedrun" and on and BF.UI and BF.UI.ShowRules then BF.UI:ShowRules() end
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
  protect = true,      -- in der Session: beim Haendler nur die Vendorliste verkaufbar
  resetLimit = 5,      -- erlaubte Instanz-Resets pro Stunde
  pullLimit = 80,      -- Hunter-Modus: ab so vielen Mobs verschwinden die Leichen
  autoSync = true,     -- bei Login und vor dem Logout mit dem Partner abgleichen
  syncPeer = "",       -- Sync-Partner (leer: Bankalt)
  srChannel = "PARTY", -- Speedrun: Kanal fuers Posten (PARTY, RAID, GUILD, SAY)
  offlineTime = true,  -- Session-Uhr laeuft offline weiter (Relog beim Reset), Luecken bis offlineMax
  offlineMax = 900,    -- laengere Pausen (Sekunden) zaehlen nicht, z. B. ueber Nacht ausgeloggt
  repairCost = true,   -- Reparaturkosten in der Session vom Wert abziehen
  srAutoStart = true,  -- Speedrun: Stoppuhr beim Betreten von Duesterbruch starten
  champGold = false,   -- Lasher Championships: eigenes Gold mit der Gilde teilen
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
  db.vcheck = db.vcheck or {}     -- [id] = { real, tab, ts }: Preispruefung beim Haendler (einmal je ID)
  db.donate = db.donate or {}     -- Spenden: pending (Kupfer), aboMode ("session"|"run"|nil), aboAmount
  db.resets = db.resets or {}     -- Zeitstempel (time()) der gezaehlten Instanz-Resets, max. 1 Stunde alt
  db.manualTs = db.manualTs or {} -- [id] = Zeitpunkt der letzten Zuordnung von Hand (fuer den Sync)
  db.sync = db.sync or { last = {}, since = {} }
  -- aeltere Zuordnungen ohne Zeitstempel bekommen einen neutralen
  for id in pairs(db.manual) do
    if not db.manualTs[id] then db.manualTs[id] = 1 end
  end
  db.modules = db.modules or {}   -- [Modulname] = true/false (siehe BF.MODULES)
  for i = 1, getn(BF.MODULES) do
    if db.modules[BF.MODULES[i]] == nil then db.modules[BF.MODULES[i]] = not BF.MODULE_OFF[BF.MODULES[i]] end
  end
  db.mailTargets = db.mailTargets or {} -- weitere Mailziele (Namen), das erste ist das Standardziel
  db.mailTarget = db.mailTarget or {}   -- [id] = Name des Mailziels (wird nicht gesynct)
  db.wish = db.wish or {}   -- Wunschliste: { id, mobs = { { name, rate (Prozent), kills } }, got, last }
  db.speedrun = db.speedrun or {}
  db.speedrun.laps = db.speedrun.laps or {}         -- { t = Sekunden, at = Zeitpunkt, cyc = Uhr-Durchlauf }
  db.speedrun.sessions = db.speedrun.sessions or {} -- beendete Sessions: { at, elapsed, resets, out }
  db.speedrun.sw = db.speedrun.sw or { elapsed = 0, cycle = 1 } -- Rundenstoppuhr
  db.pos = db.pos or {}
  db.hunter = db.hunter or {}     -- [Charname] = true/false: Hunter-Modus von Hand
  db.session = db.session or { running = false, elapsed = 0, items = {}, coin = 0, resets = 0,
    run = { items = {}, coin = 0, start = 0 } }
  if first then db.manual[6948] = "I" end -- Ruhestein
  -- 0.5.0: Liste "Behalten" (K) entfaellt, ihre Items stehen ab jetzt auf "Nie anfassen" (I)
  for id, l in pairs(db.manual) do
    if l == "K" then
      db.manual[id] = "I"
      db.manualTs[id] = time()
    end
  end
  db.keepProtect = nil
end

-- Hunter-Modus: von Hand gesetzt, sonst an fuer Jaeger
function BF:HunterMode()
  local o = BananaFarmDB.hunter[UnitName("player") or ""]
  if o ~= nil then return o end
  local _, class = UnitClass("player")
  return class == "HUNTER"
end

function BF:SetHunterMode(on)
  BananaFarmDB.hunter[UnitName("player") or ""] = on and true or false
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
  if BF.Speedrun then BF.Speedrun:OnLoad() end
  if BF.Wish then BF.Wish:Migrate() end
  BF.Vendor:HookUse()
  BF.Pulls:Init()
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
    BF.UI:ToggleBar()
  elseif cmd == "mail" then
    BF.Mail:Start()
  elseif cmd == "sell" then
    BF.Vendor:Start()
  elseif cmd == "reset" then
    BF.Resets:Do()
  elseif cmd == "sync" then
    BF.Sync:Command(rest)
  elseif cmd == "wish" then
    BF.Wish:Command(rest)
  elseif cmd == "prices" then
    BF.Vendor:Command(rest)
  elseif cmd == "lapstats" then
    local text, n = BF.Speedrun:ExportText()
    BF.UI:ShowText(BF.T("SR_EXPORT_TITLE"), text)
    BF:Print(string.format(BF.T("MSG_SR_EXPORT"), n))
  elseif cmd == "event" then
    BF.UI.frame:Show()
    BF.UI.sr.view = "event"
    BF.UI:ShowPage("speedrun")
  elseif cmd == "donate" then
    BF.UI:ShowDonate()
  else
    for i = 1, 15 do BF:Print(BF.T("HELP_" .. i)) end
  end
end

function BF:SetBankAlt(name)
  name = BF.Trim(name)
  name = string.gsub(name, "%s", "")
  BananaFarmDB.bankAlt = name
  -- wer einen Twink einträgt, ist der Farmmain und hat selbst keinen Partner
  if name ~= "" then BananaFarmDB.syncPeer = "" end
  if name == "" then
    self:Print(self.T("MSG_ALT_CLEARED"))
  else
    self:Print(string.format(self.T("MSG_ALT_SET"), name))
  end
  if self.UI then self.UI:Refresh() end
  if name ~= "" and self.Sync then self.Sync:Start("pair") end
end

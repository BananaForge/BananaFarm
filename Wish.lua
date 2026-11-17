-- BananaFarm Wunschliste: einzelne Items farmen. Zu jedem Wunschitem gibt es eine Liste von Mobs,
-- jeder mit eigenem Namen, eigener Droprate (in Prozent) und eigenen Kills. Aus allen Kills
-- zusammen werden die Chance bisher und die noch noetigen Kills berechnet. Faellt das Item,
-- werden die Kills zurueckgesetzt (Anzahl und Kills des letzten Drops bleiben stehen).
--
-- Kills: mit SuperWoW aus der Pull-Zaehlung (ein Mob in meiner Zaehlung stirbt, siehe Pulls:Killed),
-- sonst nur eigene Todesstoesse ("Ihr habt X getoetet!"). Drops: Beutemeldung im Chat.
-- Statistik: Chance = 1 - (1-p1)^k1 * (1-p2)^k2 * ... ueber alle Mobs. Der Erwartungswert 1/p
-- aendert sich durch bisherige Misserfolge nicht, daher zeigt die Liste, wie viele Kills mit dem
-- schnellsten Mob noch bis 50 % und 90 % Chance fehlen.
-- ACHTUNG: im Spiel noch nicht bestaetigt.

local BF = BananaFarm
local getn = table.getn

BF.Wish = {}
local Wish = BF.Wish

function Wish:Get(id)
  local list = BananaFarmDB.wish
  for i = 1, getn(list) do
    if list[i].id == id then return list[i], i end
  end
  return nil
end

-- liefert den Eintrag und ob er neu ist
function Wish:Add(id)
  local e = self:Get(id)
  if e then return e, false end
  e = { id = id, mobs = {}, got = 0 }
  table.insert(BananaFarmDB.wish, e)
  BF:ItemInfo(id) -- Name und Icon nachladen
  return e, true
end

function Wish:Remove(id)
  local _, i = self:Get(id)
  if i then table.remove(BananaFarmDB.wish, i) end
end

-- Item-Link, Item-ID oder reine Zahl aus einem Text
function Wish:AddFromText(text)
  if type(text) ~= "string" then return false end
  local _, _, id = string.find(text, "item:(%d+)")
  if not id then _, _, id = string.find(text, "^%s*(%d+)%s*$") end
  id = tonumber(id)
  if not id or id <= 0 then return false end
  local _, isNew = self:Add(id)
  BF:Print(string.format(BF.T(isNew and "MSG_WISH_ADDED" or "MSG_WISH_HAVE"), BF:ColoredName(id)))
  if BF.UI then
    BF.UI.wishSel = id
    BF.UI:RefreshWish()
  end
  return true
end

function Wish:Command(rest)
  if not BF:Enabled("wish") then
    BF:Print(BF.T("ERR_MODULE_OFF"))
    return
  end
  if not self:AddFromText(rest) then BF:Print(BF.T("HELP_12")) end
end

-- ------------------------------------------------------------
-- Daten und Statistik
-- ------------------------------------------------------------
-- alte Eintraege (eine Rate und eine Liste von Namen) in Mobs mit eigener Rate umbauen
function Wish:Migrate()
  local list = BananaFarmDB.wish
  for i = 1, getn(list) do
    local e = list[i]
    local mobs = {}
    local old = e.mobs or {}
    for j = 1, getn(old) do
      if type(old[j]) == "string" then
        table.insert(mobs, { name = old[j], rate = e.rate or 0, kills = 0 })
      else
        table.insert(mobs, old[j])
      end
    end
    if e.kills and e.kills > 0 and mobs[1] then mobs[1].kills = e.kills end
    e.mobs = mobs
    e.rate = nil
    e.kills = nil
  end
end

function Wish:Total(e)
  local n = 0
  for i = 1, getn(e.mobs) do n = n + (e.mobs[i].kills or 0) end
  return n
end

function Wish:ResetKills(e)
  for i = 1, getn(e.mobs) do e.mobs[i].kills = 0 end
end

-- ln der Wahrscheinlichkeit, bei einem Kill nichts zu bekommen. nil = sicherer Drop (100 %)
local function lnMiss(rate)
  if not rate or rate <= 0 then return 0 end
  if rate >= 100 then return nil end
  return math.log(1 - rate / 100)
end

-- Summe der ln-Werte ueber alle Kills und ob ein sicherer Drop dabei war
function Wish:State(e)
  local sum, sure = 0, false
  for i = 1, getn(e.mobs) do
    local m = e.mobs[i]
    if (m.kills or 0) > 0 and (m.rate or 0) > 0 then
      local l = lnMiss(m.rate)
      if l == nil then sure = true else sum = sum + m.kills * l end
    end
  end
  return sum, sure
end

-- Kills nur mit diesem Mob, bis die Gesamtchance prob (0..1) erreicht ist (die bisherigen Kills
-- aller Mobs sind eingerechnet). 0 = schon erreicht, nil = der Mob hat keine Droprate.
function Wish:Left(e, m, prob)
  if (m.rate or 0) <= 0 then return nil end
  local sum, sure = self:State(e)
  if sure then return 0 end
  local need = math.log(1 - prob) - sum
  if need >= 0 then return 0 end
  local l = lnMiss(m.rate)
  if l == nil then return 1 end
  return math.ceil(need / l)
end

-- nil, solange kein Mob mit Name eine Droprate hat
function Wish:Info(e)
  local best
  for i = 1, getn(e.mobs) do
    local m = e.mobs[i]
    if m.name ~= "" and (m.rate or 0) > 0 then
      local l90 = self:Left(e, m, 0.9)
      if not best or l90 < best.left90 then
        best = { name = m.name, left90 = l90, left50 = self:Left(e, m, 0.5) }
      end
    end
  end
  if not best then return nil end
  local sum, sure = self:State(e)
  best.chance = sure and 1 or (1 - math.exp(sum))
  best.total = self:Total(e)
  best.reached = best.left90 == 0
  return best
end

-- ------------------------------------------------------------
-- Kills und Drops
-- ------------------------------------------------------------
function Wish:OnKill(name)
  if not BF:Enabled("wish") or type(name) ~= "string" then return end
  local low = string.lower(name)
  local hit = false
  local list = BananaFarmDB.wish
  for i = 1, getn(list) do
    local mobs = list[i].mobs
    for j = 1, getn(mobs) do
      if mobs[j].name ~= "" and string.lower(mobs[j].name) == low then
        mobs[j].kills = (mobs[j].kills or 0) + 1
        hit = true
      end
    end
  end
  if hit and BF.UI then BF.UI:RefreshWish() end
end

-- Textvorlage aus den Spiel-Texten ("You receive loot: %s.") in ein Muster umwandeln
local function pattern(fmt)
  fmt = string.gsub(fmt, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
  fmt = string.gsub(fmt, "%%s", "(.+)")
  fmt = string.gsub(fmt, "%%d", "[0-9]+")
  return "^" .. fmt .. "$"
end

local lootPatterns
local function selfLoot(msg)
  if not lootPatterns then
    lootPatterns = {}
    local names = { "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }
    for i = 1, getn(names) do
      local g = getglobal(names[i])
      if type(g) == "string" then table.insert(lootPatterns, pattern(g)) end
    end
  end
  for i = 1, getn(lootPatterns) do
    if string.find(msg, lootPatterns[i]) then return true end
  end
  return false
end

function Wish:OnLoot(msg)
  if not BF:Enabled("wish") or type(msg) ~= "string" then return end
  local id = BF.ItemID(msg)
  if not id then return end
  local e = self:Get(id)
  if not e then return end
  if not selfLoot(msg) then return end
  e.got = (e.got or 0) + 1
  e.last = self:Total(e)
  self:ResetKills(e)
  BF:Print(string.format(BF.T("MSG_WISH_GOT"), BF:ColoredName(id), e.last))
  if BF.UI then BF.UI:RefreshWish() end
end

-- ohne SuperWoW: nur eigene Todesstoesse
local killPattern
function Wish:OnDeathMsg(msg)
  if not BF:Enabled("wish") or type(msg) ~= "string" then return end
  if BF.Pulls and BF.Pulls:Available() then return end
  if not killPattern then
    local g = getglobal("SELFKILLOTHER")
    killPattern = pattern(type(g) == "string" and g or "You have slain %s!")
  end
  local _, _, name = string.find(msg, killPattern)
  if name then self:OnKill(name) end
end

BF:On("CHAT_MSG_LOOT", function(msg) Wish:OnLoot(msg) end)
BF:On("CHAT_MSG_COMBAT_HOSTILE_DEATH", function(msg) Wish:OnDeathMsg(msg) end)

-- ------------------------------------------------------------
-- Shift-Klick auf Items (Tasche, Chat-Link, AtlasLoot) in das Eingabefeld der Wunschliste:
-- Das Spiel fuegt Links nur ein, wenn die Chat-Eingabe sichtbar ist (ChatFrameEditBox:IsVisible),
-- und ruft dann ChatFrameEditBox:Insert. Solange unser Feld den Fokus hat, tut die Chat-Eingabe
-- deshalb so, als waere sie offen, und leitet Item-Links an die Wunschliste um.
-- ------------------------------------------------------------
function Wish:Capture(on)
  local cb = ChatFrameEditBox
  if not cb then return end
  if on then
    if self.cap then return end
    local cap = { insert = rawget(cb, "Insert"), visible = rawget(cb, "IsVisible"), shown = rawget(cb, "IsShown") }
    cap.origInsert = cb.Insert
    self.cap = cap
    cb.Insert = function(frame, text)
      if not Wish:AddFromText(text) then cap.origInsert(frame, text) end
    end
    cb.IsVisible = function() return true end
    cb.IsShown = function() return true end
  else
    local cap = self.cap
    if not cap then return end
    self.cap = nil
    cb.Insert = cap.insert
    cb.IsVisible = cap.visible
    cb.IsShown = cap.shown
  end
end

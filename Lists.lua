-- BananaFarm Listen: Vendor (V), Mail (M), Ignorieren (I), Behalten (K), Unsortiert (U).
-- Eine Zuordnung von Hand schlaegt immer die Automatik. Unsortierte Items bleiben in den Taschen.

local BF = BananaFarm
local getn = table.getn

BF.Lists = { queue = {} }
local Lists = BF.Lists

BF.LIST_KEYS = { "V", "M", "I", "K", "U" }

-- "V" | "M" | "I" | "U" | nil (dem Addon unbekannt)
function Lists:Get(id)
  local db = BananaFarmDB
  local l = db.manual[id] or db.auto[id]
  if l then return l end
  if db.unsorted[id] then return "U" end
  return nil
end

function Lists:IsManual(id)
  return BananaFarmDB.manual[id] ~= nil
end

-- Wirksame Liste: "Behalten" (K) schuetzt nur, solange die Session laeuft (und die Option an ist).
-- Sonst entscheidet die Standardregel, als stuende das Item nicht auf K.
function Lists:Eff(id)
  local l = self:Get(id)
  if l ~= "K" then return l end
  if BananaFarmDB.keepProtect and BF.Session and BF.Session:Running() then return "K" end
  return BananaFarmDB.auto[id] or self:Classify(id) or "U"
end

-- Zuordnung von Hand. list = "V" | "M" | "I" | "K", "U" (zurueck zu unsortiert) oder nil (ganz entfernen)
function Lists:Set(id, list)
  local db = BananaFarmDB
  BF:ItemInfo(id)
  db.manualTs[id] = time()
  if list == "V" or list == "M" or list == "I" or list == "K" then
    db.manual[id] = list
    db.auto[id] = nil
    db.unsorted[id] = nil
    db.noSell[id] = nil
  elseif list == "U" then
    db.manual[id] = nil
    db.auto[id] = nil
    db.unsorted[id] = true
  else
    db.manual[id] = nil
    db.auto[id] = nil
    db.unsorted[id] = nil
  end
  if BF.UI then BF.UI:Refresh() end
end

-- Standardregel. Liefert "V" | "M" | "I" oder nil (keine Entscheidung moeglich: unsortiert).
function Lists:Classify(id)
  local db = BananaFarmDB
  local _, q, _, itype = BF:ItemInfo(id)
  if itype == "Quest" then return "I" end
  local vendor = BF:VendorValue(id)
  if q == 0 then
    if db.grayVendor then return "V" end
    return nil
  end
  local ah = BF:AHNet(id)
  -- ohne AH-Preis entscheidet der Nutzer
  if not ah then return nil end
  if ah >= (db.minAH or 0) and ah >= (db.threshold or 1.5) * (vendor or 0) then return "M" end
  -- AH lohnt nicht: verkaufen, aber nur wenn der Haendler es sicher nimmt
  if vendor then return "V" end
  return nil
end

-- Ein Item ist (neu) in den Taschen aufgetaucht: einsortieren, falls noch nicht geschehen.
function Lists:Seen(id)
  local db = BananaFarmDB
  BF:ItemInfo(id)
  if db.manual[id] or db.auto[id] then return end
  local r = self:Classify(id)
  if r then
    db.auto[id] = r
    db.unsorted[id] = nil
    return
  end
  if not db.unsorted[id] then
    db.unsorted[id] = true
    self:Enqueue(id)
  end
end

-- Automatik neu rechnen (nach AH-Scan oder geaenderten Einstellungen). Liefert die Zahl der Wechsel.
function Lists:Reclassify()
  local db = BananaFarmDB
  local ids, moved = {}, 0
  for id in pairs(db.auto) do table.insert(ids, id) end
  for id in pairs(db.unsorted) do table.insert(ids, id) end
  for i = 1, getn(ids) do
    local id = ids[i]
    if not db.manual[id] then
      local before = db.auto[id]
      local r = self:Classify(id)
      if r then
        db.auto[id] = r
        db.unsorted[id] = nil
      else
        db.auto[id] = nil
        db.unsorted[id] = true
      end
      if r ~= before then moved = moved + 1 end
    end
  end
  return moved
end

-- alle IDs einer Liste, nach Name sortiert
function Lists:IDs(list)
  local db = BananaFarmDB
  local seen, ids = {}, {}
  local function scan(t)
    for id in pairs(t) do
      if not seen[id] then
        seen[id] = true
        if self:Get(id) == list then table.insert(ids, id) end
      end
    end
  end
  scan(db.manual)
  scan(db.auto)
  scan(db.unsorted)
  table.sort(ids, function(a, b)
    local na, nb = BF:ItemInfo(a), BF:ItemInfo(b)
    if na ~= nb then return na < nb end
    return a < b
  end)
  return ids
end

function Lists:CountOf(list)
  return getn(self:IDs(list))
end

-- ------------------------------------------------------------
-- Warteschlange fuer das Zuordnungs-Pop-up (nie im Kampf)
-- ------------------------------------------------------------
function Lists:Enqueue(id)
  for i = 1, getn(self.queue) do
    if self.queue[i] == id then return end
  end
  table.insert(self.queue, id)
  self:PopNext()
end

function Lists:PopNext()
  if not BananaFarmDB.popup or not BF.UI then return end
  if BF.UI:AssignShown() then return end
  if UnitAffectingCombat("player") then return end
  while getn(self.queue) > 0 do
    local id = table.remove(self.queue, 1)
    if self:Get(id) == "U" then
      BF.UI:ShowAssign(id)
      return
    end
  end
end

BF:On("PLAYER_REGEN_ENABLED", function()
  BF:After(1, function() Lists:PopNext() end, "popnext")
end)

-- ------------------------------------------------------------
-- Alt+Klick auf ein Item in der Tasche: auf die gerade gewaehlte Liste
-- ------------------------------------------------------------
local origClick
function Lists:HookBags()
  if origClick or not ContainerFrameItemButton_OnClick then return end
  origClick = ContainerFrameItemButton_OnClick
  ContainerFrameItemButton_OnClick = function(button, ignoreModifiers)
    if BF.ready and BananaFarmDB.altClick and button == "LeftButton" and IsAltKeyDown()
      and not IsShiftKeyDown() and not IsControlKeyDown() and this and this.GetParent then
      local id = BF.ItemID(GetContainerItemLink(this:GetParent():GetID(), this:GetID()))
      if id then
        local list = (BF.UI and BF.UI.sel) or "V"
        Lists:Set(id, list)
        BF:Print(string.format(BF.T("MSG_ASSIGNED"), BF:ColoredName(id), BF.T("LIST_" .. list)))
        return
      end
    end
    return origClick(button, ignoreModifiers)
  end
end

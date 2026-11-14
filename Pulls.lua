-- BananaFarm Pull-Zaehler: wie viele Mobs haengen gerade am Spieler?
-- Braucht SuperWoW (GUIDs). Ohne SuperWoW bleibt die Anzeige weg.
-- Quellen fuer GUIDs: RAW_COMBATLOG und UNIT_CASTEVENT (beides SuperWoW), dazu Ziel und Mouseover.
-- Hunter-Modus: Leichen zaehlen mit, bis sie verschwinden, und es gibt eine Grenze (Standard 80),
-- weil darueber die Leichen sofort verschwinden.
-- ACHTUNG: ohne Ergebnis von /bf probe gebaut, im Spiel noch nicht bestaetigt.

local BF = BananaFarm

BF.Pulls = { set = {}, count = 0 }
local Pulls = BF.Pulls

function Pulls:Available()
  return SUPERWOW_VERSION ~= nil
end

function Pulls:Limit()
  local l = BananaFarmDB.pullLimit
  if type(l) ~= "number" or l < 1 then return 80 end
  return l
end

-- feindlicher Mob im Kampf? Alle Abfragen geschuetzt: eine GUID kann jederzeit ungueltig werden
local function hostileMob(g)
  local ok, res = pcall(function()
    if not UnitExists(g) then return false end
    if UnitIsPlayer(g) then return false end
    if not UnitCanAttack("player", g) then return false end
    return true
  end)
  return ok and res
end

function Pulls:Add(g)
  if type(g) ~= "string" or self.set[g] then return end
  if not hostileMob(g) then return end
  local ok, dead = pcall(UnitIsDead, g)
  if ok and dead then return end
  self.set[g] = GetTime()
end

function Pulls:AddUnit(unit)
  local exists, g = UnitExists(unit)
  if exists and g and UnitAffectingCombat(unit) then self:Add(g) end
end

function Pulls:Sweep()
  local hunter = BF:HunterMode()
  local now = GetTime()
  local n = 0
  local drop
  for g, t in pairs(self.set) do
    local keep = false
    local ok, exists = pcall(UnitExists, g)
    if ok and exists then
      local ok2, dead = pcall(UnitIsDead, g)
      if ok2 and dead then
        keep = hunter
      else
        local ok3, combat = pcall(UnitAffectingCombat, g)
        -- frisch gesehen: dem Client 3 s geben, bis er den Kampf meldet
        keep = (ok3 and combat) or (now - t < 3)
      end
    end
    if keep then
      n = n + 1
    else
      drop = drop or {}
      table.insert(drop, g)
    end
  end
  if drop then
    for i = 1, table.getn(drop) do self.set[drop[i]] = nil end
  end
  self.count = n
  if hunter then
    local limit = self:Limit()
    if n >= limit and not self.warned then
      self.warned = true
      local msg = string.format(BF.T("MSG_PULL_LIMIT"), n, limit)
      BF:Error(msg)
      if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 1, 0.3, 0.2) end
      PlaySound("RaidWarning")
    elseif n < limit - 5 then
      self.warned = nil
    end
  end
end

-- Text fuer die Leiste, nil wenn der Zaehler nicht verfuegbar ist
function Pulls:Text()
  if not self:Available() then return nil end
  local n = self.count
  if not BF:HunterMode() then return tostring(n) end
  local limit = self:Limit()
  local color = "ffffff"
  if n >= limit then color = "ff4040" elseif n >= limit - 10 then color = "ffd100" end
  return "|cff" .. color .. n .. "|r/" .. limit
end

local function scanText(text)
  if type(text) ~= "string" then return end
  for g in string.gfind(text, "0x%x+") do
    if string.len(g) >= 18 then Pulls:Add(g) end
  end
end

function Pulls:Init()
  if self.started or not self:Available() then return end
  self.started = true
  BF:On("RAW_COMBATLOG", function(ev, text) scanText(text) end)
  BF:On("UNIT_CASTEVENT", function(caster, target)
    Pulls:Add(caster)
    Pulls:Add(target)
  end)
  BF:On("PLAYER_TARGET_CHANGED", function() Pulls:AddUnit("target") end)
  BF:On("UPDATE_MOUSEOVER_UNIT", function() Pulls:AddUnit("mouseover") end)
  local f = CreateFrame("Frame")
  f.tick = 0
  f:SetScript("OnUpdate", function()
    this.tick = this.tick + (arg1 or 0)
    if this.tick < 0.5 then return end
    this.tick = 0
    Pulls:Sweep()
  end)
end

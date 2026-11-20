-- BananaFarm Pull-Zaehler: wie viele Mobs haengen gerade am Spieler?
-- Braucht SuperWoW (GUIDs). Ohne SuperWoW bleibt die Anzeige weg.
-- Quellen fuer GUIDs: RAW_COMBATLOG und UNIT_CASTEVENT (beides SuperWoW), dazu Ziel und Mouseover.
-- Hunter-Modus: Leichen zaehlen mit, bis sie verschwinden, und es gibt eine Grenze (Standard 80),
-- weil darueber die Leichen sofort verschwinden.
-- Gezaehlt werden nur Mobs, die mit mir oder meinem Pet im Kampf sind (eigene Zauber und Treffer,
-- Angriffe auf mich oder das Pet, Ziel und Mouseover nur wenn der Mob auf mich oder das Pet geht).
-- Kaempfe anderer Spieler in der Naehe zaehlen nicht. Ausserhalb des Kampfes bleibt die Anzeige weg.
-- Zusaetzlich (0.4.1) die Namensplaketten: SuperWoW liefert dort mit GetName(1) die GUID. So zaehlen
-- auch Mobs, die nur hinter dir herlaufen und noch nicht getroffen haben (wichtig beim Hunter-Kite).
-- Voraussetzung: Namensplaketten an (Taste V). Gezaehlt wird ein Mob mit Plakette, der im Kampf ist
-- und dich oder dein Pet im Ziel hat; kennt der Client "GUIDtarget" nicht, reicht in einer Instanz
-- "im Kampf und angreifbar" (dort ist man allein).
-- ACHTUNG: ohne Ergebnis von /bf probe gebaut, im Spiel noch nicht bestaetigt.

local BF = BananaFarm

BF.Pulls = { set = {}, dead = {}, count = 0 }
local Pulls = BF.Pulls

function Pulls:Available()
  return SUPERWOW_VERSION ~= nil
end

-- Die Zaehlung laeuft auch fuer die Wunschliste (Kills), die Anzeige haengt am Modul pulls
function Pulls:Active()
  return BF:Enabled("pulls") or BF:Enabled("wish") or BF:Enabled("speedrun")
end

-- ein Mob aus meiner Zaehlung ist gestorben
function Pulls:Killed(g)
  local ok, name = pcall(UnitName, g)
  if ok and name and BF.Wish then BF.Wish:OnKill(name) end
  if ok and name and BF.Speedrun then BF.Speedrun:OnKill(name) end
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
  if not self:Active() then return end
  if type(g) ~= "string" or self.set[g] then return end
  if not hostileMob(g) then return end
  local ok, dead = pcall(UnitIsDead, g)
  if ok and dead then return end
  self.set[g] = GetTime()
end

-- Ziel oder Mouseover zaehlt nur, wenn der Mob im Kampf ist und auf mich oder mein Pet geht
function Pulls:AddUnit(unit)
  local exists, g = UnitExists(unit)
  if not exists or not g or not UnitAffectingCombat(unit) then return end
  if UnitIsUnit(unit .. "target", "player") or UnitIsUnit(unit .. "target", "pet") then self:Add(g) end
end

-- Zielt der Mob auf mich oder mein Pet? true/false, nil wenn der Client das fuer GUIDs nicht kann
local function targetsMe(g)
  local ok, me = pcall(UnitIsUnit, g .. "target", "player")
  if not ok then return nil end
  if me then return true end
  local ok2, pet = pcall(UnitIsUnit, g .. "target", "pet")
  return ok2 and pet and true or false
end

local function inInstance()
  if not IsInInstance then return false end
  local inside = IsInInstance()
  return inside and true or false
end

-- Namensplaketten durchgehen (nur im Kampf, alle 0,5 s)
function Pulls:ScanPlates()
  if not WorldFrame or not WorldFrame.GetChildren then return end
  local kids = { WorldFrame:GetChildren() }
  local instance = nil
  for i = 1, table.getn(kids) do
    local f = kids[i]
    if f and f.IsVisible and f:IsVisible() then
      local ok, g = pcall(f.GetName, f, 1)
      if ok and type(g) == "string" and string.sub(g, 1, 2) == "0x" and not self.set[g] then
        local okc, combat = pcall(UnitAffectingCombat, g)
        if okc and combat and hostileMob(g) then
          local t = targetsMe(g)
          if t == nil then
            if instance == nil then instance = inInstance() end
            t = instance
          end
          if t then self:Add(g) end
        end
      end
    end
  end
end

function Pulls:Sweep()
  if not self:Active() then
    self.set = {}
    self.dead = {}
    self.count = 0
    return
  end
  local hunter = BF:HunterMode()
  local now = GetTime()
  local inCombat = UnitAffectingCombat("player")
  if inCombat and self:Available() then self:ScanPlates() end
  local n = 0
  local drop
  for g, t in pairs(self.set) do
    local keep = false
    -- ein Mob aus meiner Zaehlung ist gestorben (auch wenn der Kampf gerade endete)
    local okx, existsx = pcall(UnitExists, g)
    if okx and existsx and not self.dead[g] then
      local okd, deadx = pcall(UnitIsDead, g)
      if okd and deadx then
        self.dead[g] = true
        self:Killed(g)
      end
    end
    if not inCombat then
      -- ausserhalb des Kampfes zaehlt nichts. Ganz frische Eintraege bleiben kurz, weil der
      -- Client den Kampf einen Moment spaeter meldet.
      keep = now - t < 3
    else
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
    end
    if keep then
      n = n + 1
    else
      drop = drop or {}
      table.insert(drop, g)
    end
  end
  if drop then
    for i = 1, table.getn(drop) do
      self.set[drop[i]] = nil
      self.dead[drop[i]] = nil
    end
  end
  self.count = n
  if not inCombat then self.warned = nil end
  if hunter and inCombat then
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
  if not self:Available() or not BF:Enabled("pulls") then return nil end
  if not UnitAffectingCombat("player") then return nil end
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

-- Kampfzeilen, die mich oder mein Pet betreffen (eigene Treffer und Zauber, Angriffe auf mich,
-- Pet-Kampf). Ist die Form des Ereignisses unbekannt, wird nicht gefiltert.
local function relevant(ev)
  if type(ev) ~= "string" or not string.find(ev, "CHAT_MSG", 1, true) then return true end
  return string.find(ev, "SELF", 1, true) or string.find(ev, "PET", 1, true)
end

function Pulls:Init()
  if self.started or not self:Available() then return end
  self.started = true
  BF:On("RAW_COMBATLOG", function(ev, text)
    if relevant(ev) then scanText(text) end
  end)
  -- nur Zauber von mir oder meinem Pet und Zauber auf mich oder das Pet
  BF:On("UNIT_CASTEVENT", function(caster, target)
    local _, me = UnitExists("player")
    local _, pet = UnitExists("pet")
    if caster and (caster == me or (pet and caster == pet)) then
      Pulls:Add(target)
    elseif target and (target == me or (pet and target == pet)) then
      Pulls:Add(caster)
    end
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

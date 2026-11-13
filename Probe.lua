-- BananaFarm Probe: /bf probe zeigt, was dieser Client kann (SuperWoW, Nampower, OctoWoW).
-- Das Ergebnis entscheidet, wie der Ein-Button-Loot und der Pull-Zaehler gebaut werden.
-- Ausgabe in einem Fenster zum Kopieren und zusaetzlich in BananaFarmDB.probe.

local BF = BananaFarm
local getn = table.getn

local CHECK = {
  "InteractUnit", "LootSlot", "GetNumLootItems", "CloseLoot", "SetAutoloot", "GetItemStats",
  "UnitPosition", "SpellInfo", "GetUnitData", "GetUnitField", "GetSpellRec", "CombatLogAdd",
  "TrackUnit", "UntrackUnit", "ImportFile", "ExportFile", "SetMouseoverUnit", "GetPlayerBuffID",
  "QueueSpellByName", "CastSpellByNameNoQueue", "IsSpellInRange", "GetCastInfo", "GetCurrentCastingInfo",
  "UnitXP", "GetObjects", "GetUnitGUID", "UnitGUID", "ResetInstances", "ConfirmLootSlot",
}
local WORDS = { "loot", "interact", "guid", "corpse" }
local CVARS = { "autoLootDefault", "AutoLoot", "NP_QueueCastTimeSpells", "NP_SpamProtectionEnabled", "FoV" }

function BF:Probe()
  local out = {}
  local function add(s) table.insert(out, s) end

  local v, build, bdate = GetBuildInfo()
  add("BananaFarm " .. BF.VERSION .. " probe")
  add("Client: " .. tostring(v) .. " build " .. tostring(build) .. " (" .. tostring(bdate) .. "), " .. tostring(GetLocale()))
  add("Realm: " .. tostring(GetRealmName and GetRealmName()))
  add("SUPERWOW_VERSION: " .. tostring(SUPERWOW_VERSION))
  add("SUPERWOW_STRING: " .. tostring(SUPERWOW_STRING))
  if GetNampowerVersion then
    local ok, a, b, c = pcall(GetNampowerVersion)
    add("GetNampowerVersion: " .. tostring(ok) .. " " .. tostring(a) .. "." .. tostring(b) .. "." .. tostring(c))
  else
    add("GetNampowerVersion: nil")
  end

  -- SuperWoW: UnitExists liefert als zweiten Wert die GUID
  local e1, g1 = UnitExists("player")
  add("UnitExists(player): " .. tostring(e1) .. ", " .. tostring(g1))
  local e2, g2 = UnitExists("target")
  add("UnitExists(target): " .. tostring(e2) .. ", " .. tostring(g2))
  if g2 then
    local ok, name = pcall(UnitName, g2)
    add("UnitName(guid): " .. tostring(ok) .. ", " .. tostring(name))
    local ok2, dead = pcall(UnitIsDead, g2)
    add("UnitIsDead(guid): " .. tostring(ok2) .. ", " .. tostring(dead))
  end

  add("")
  add("-- Funktionen (gezielt) --")
  for i = 1, getn(CHECK) do
    add(CHECK[i] .. ": " .. type(getglobal(CHECK[i])))
  end

  add("")
  add("-- Funktionen mit loot/interact/guid/corpse im Namen --")
  local names = {}
  for k, val in pairs(getfenv(0)) do
    if type(k) == "string" and type(val) == "function" then
      local low = string.lower(k)
      for i = 1, getn(WORDS) do
        if string.find(low, WORDS[i], 1, true) then
          table.insert(names, k)
          break
        end
      end
    end
  end
  table.sort(names)
  local line = ""
  for i = 1, getn(names) do
    if string.len(line) + string.len(names[i]) > 90 then
      add(line)
      line = ""
    end
    line = line .. names[i] .. "  "
  end
  if line ~= "" then add(line) end

  add("")
  add("-- CVars --")
  for i = 1, getn(CVARS) do
    local ok, val = pcall(GetCVar, CVARS[i])
    add(CVARS[i] .. ": " .. (ok and tostring(val) or "(unbekannt)"))
  end

  add("")
  add("-- Post --")
  add("Anhang-Felder: " .. BF.Mail:Slots() .. ", TurtleMail: " .. (BF.Mail:TurtleMailActive() and "ja" or "nein"))

  local text = table.concat(out, "\n")
  BananaFarmDB.probe = text
  if BF.UI then BF.UI:ShowText(BF.T("PROBE_TITLE"), text) end
  self:Print(BF.T("MSG_PROBE"))
end

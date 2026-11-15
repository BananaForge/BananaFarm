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
  "RunMacroText", "RunMacro", "ChatEdit_SendText", "SendChatMessage", "GetNumBindings", "GetBinding",
  "GetMouseFocus", "UseContainerItem", "TargetUnit", "AssistUnit", "CastSpellByName",
}
local WORDS = { "loot", "interact", "corpse", "click", "mouse", "object", "nearest", "pickup", "macro", "guid" }
local BINDWORDS = { "INTERACT", "LOOT", "MOUSEOVER", "AUTO" }
local SLASHWORDS = { "LOOT", "INTERACT", "CLICK", "MACRO", "NAMPOWER", "SUPERWOW" }
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
  -- alle globalen Funktionsnamen einsammeln (komplett in die DB, gefiltert ins Fenster)
  local all = {}
  for k, val in pairs(getfenv(0)) do
    if type(k) == "string" and type(val) == "function" then table.insert(all, k) end
  end
  table.sort(all)
  BananaFarmDB.probeAll = table.concat(all, " ")
  add("-- Funktionen nach Stichwort (alle " .. getn(all) .. " Namen stehen in BananaFarmDB.probeAll) --")
  for w = 1, getn(WORDS) do
    local hits = {}
    for i = 1, getn(all) do
      if string.find(string.lower(all[i]), WORDS[w], 1, true) then table.insert(hits, all[i]) end
    end
    add("[" .. WORDS[w] .. "] " .. getn(hits))
    local line = ""
    for i = 1, getn(hits) do
      if string.len(line) + string.len(hits[i]) > 90 then
        add(line)
        line = ""
      end
      line = line .. hits[i] .. "  "
    end
    if line ~= "" then add(line) end
  end

  -- Tastenbelegungen: gibt es einen Interact-/Loot-Befehl, der sich ueber Makro nutzen laesst?
  add("")
  add("-- Tastenbelegungen (INTERACT/LOOT/MOUSEOVER/AUTO) --")
  if GetNumBindings and GetBinding then
    local found = 0
    for i = 1, GetNumBindings() do
      local cmd, k1, k2 = GetBinding(i)
      if cmd then
        local up = string.upper(cmd)
        for w = 1, getn(BINDWORDS) do
          if string.find(up, BINDWORDS[w], 1, true) then
            add(cmd .. ": " .. tostring(k1) .. " " .. tostring(k2))
            found = found + 1
            break
          end
        end
      end
    end
    if found == 0 then add("(keine)") end
  else
    add("GetNumBindings: nil")
  end

  -- Slash-Befehle (Makros koennen nur Slash-Befehle und /script ausfuehren)
  add("")
  add("-- Slash-Befehle (LOOT/INTERACT/CLICK/MACRO/NAMPOWER/SUPERWOW) --")
  local sl = ""
  local n = 0
  if SlashCmdList then
    for k, val in pairs(SlashCmdList) do
      n = n + 1
      local up = string.upper(tostring(k))
      for w = 1, getn(SLASHWORDS) do
        if string.find(up, SLASHWORDS[w], 1, true) then
          sl = sl .. tostring(k) .. "  "
          break
        end
      end
    end
  end
  add("SlashCmdList gesamt: " .. n)
  if sl ~= "" then add(sl) end

  -- Ziel-Check: ist das Ziel eine Leiche, und ist sie lootbar?
  add("")
  add("-- Ziel --")
  if UnitExists("target") then
    add("UnitIsDead(target): " .. tostring(UnitIsDead("target")))
    add("UnitName(target): " .. tostring(UnitName("target")))
    add("LootFrame sichtbar: " .. tostring(LootFrame and LootFrame:IsVisible()))
  else
    add("(kein Ziel: fuer diesen Teil eine tote Leiche anvisieren)")
  end

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

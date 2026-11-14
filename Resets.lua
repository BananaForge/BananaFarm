-- BananaFarm Resets: zaehlt Instanz-Resets und zeigt, wann die Stunde rum ist.
-- Jeder Reset wird mit Uhrzeit (time()) in BananaFarmDB gespeichert. Das uebersteht Relog und
-- Charwechsel auf demselben Account; ein Abgleich ueber einen Twink ist nicht noetig.

local BF = BananaFarm
local getn = table.getn

BF.Resets = {}
local Resets = BF.Resets

BF.RESET_WINDOW = 3600

-- alte Eintraege verwerfen. Liefert: Anzahl in der letzten Stunde, Sekunden bis der aelteste herausfaellt
function Resets:Recent()
  local list = BananaFarmDB.resets
  local now = time()
  while getn(list) > 0 and now - list[1] >= BF.RESET_WINDOW do
    table.remove(list, 1)
  end
  local n = getn(list)
  if n == 0 then return 0, 0 end
  return n, list[1] + BF.RESET_WINDOW - now
end

function Resets:Limit()
  local l = BananaFarmDB.resetLimit
  if type(l) ~= "number" or l < 1 then return 5 end
  return l
end

function Resets:Log()
  local now = GetTime()
  -- mehrere Meldungen auf einmal (mehrere Instanzen) sind ein Reset
  if self.last and now - self.last < 3 then return end
  self.last = now
  table.insert(BananaFarmDB.resets, time())
  local n = self:Recent()
  local limit = self:Limit()
  BF:Print(string.format(BF.T("MSG_RESET"), n, limit))
  if n >= limit then BF:Error(BF.T("MSG_RESET_LIMIT")) end
  BF.Session:NewRun()
  if BF.UI then BF.UI:Refresh() end
end

-- Muster aus dem Text des Clients bauen ("%s wurde zurueckgesetzt.")
local pattern
local function resetPattern()
  if pattern ~= nil then return pattern end
  pattern = false
  if type(INSTANCE_RESET_SUCCESS) == "string" then
    local p = string.gsub(INSTANCE_RESET_SUCCESS, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = string.gsub(p, "%%s", ".+")
    pattern = "^" .. p .. "$"
  end
  return pattern
end

BF:On("CHAT_MSG_SYSTEM", function(msg)
  local p = resetPattern()
  if p and msg and string.find(msg, p) then Resets:Log() end
end)

-- Kennt der Client den Meldungstext nicht, zaehlt der Aufruf selbst
local origReset
function Resets:Hook()
  if origReset or not ResetInstances then return end
  origReset = ResetInstances
  ResetInstances = function()
    origReset()
    if not resetPattern() then Resets:Log() end
  end
end

function Resets:Do()
  if not ResetInstances then
    BF:Print(BF.T("ERR_NO_RESET"))
    return
  end
  ResetInstances()
end

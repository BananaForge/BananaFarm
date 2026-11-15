-- BananaFarm Resets: zaehlt Instanz-Resets (System-Meldung) und zeigt, wann die Stunde rum ist.
-- Gespeichert werden Zeitstempel (time()), daher laeuft der Timer ueber Relog und /reload weiter.
-- Das Limit (5 pro Stunde) und die Stundenfrist sind hier als Konstanten hinterlegt.

local BF = BananaFarm
local getn = table.getn

BF.Resets = { LIMIT = 5, WINDOW = 3600 }
local R = BF.Resets

-- alles, was aelter als eine Stunde ist, faellt raus; Rest aufsteigend sortiert
function R:Prune()
  local db = BananaFarmDB
  db.resets = db.resets or {}
  local now = time()
  local keep = {}
  for i = 1, getn(db.resets) do
    local t = db.resets[i]
    if type(t) == "number" and now - t < self.WINDOW then table.insert(keep, t) end
  end
  table.sort(keep)
  db.resets = keep
  return keep
end

function R:Count()
  return getn(self:Prune())
end

-- Sekunden, bis der aelteste Reset aus der Stunde faellt (nil: keine Resets gezaehlt)
function R:Remaining()
  local l = self:Prune()
  if getn(l) == 0 then return nil end
  local rem = l[1] + self.WINDOW - time()
  if rem < 0 then rem = 0 end
  return rem
end

-- Zeitstempel vom Sync-Partner uebernehmen. true, wenn er neu war.
function R:Merge(ts)
  local l = self:Prune()
  if type(ts) ~= "number" or time() - ts >= self.WINDOW then return false end
  for i = 1, getn(l) do
    if l[i] == ts then return false end
  end
  table.insert(l, ts)
  table.sort(l)
  return true
end

function R:Add()
  table.insert(self:Prune(), time())
  BF:Print(string.format(BF.T("MSG_RESET"), self:Count(), self.LIMIT))
  if BF.UI then BF.UI:Refresh() end
end

-- Muster aus der Client-Meldung "%s has been reset." (je Sprache anders) bauen
local patterns = {}
local function addPattern(g)
  if type(g) ~= "string" then return end
  local p = string.gsub(g, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  p = string.gsub(p, "%%s", ".+")
  table.insert(patterns, "^" .. p .. "$")
end
addPattern(INSTANCE_RESET_SUCCESS)
if getn(patterns) == 0 then
  table.insert(patterns, "^.+ has been reset%.$")
  table.insert(patterns, "^.+ wurde zur.+gesetzt%.$")
end

BF:On("CHAT_MSG_SYSTEM", function(msg)
  if type(msg) ~= "string" then return end
  for i = 1, getn(patterns) do
    if string.find(msg, patterns[i]) then
      R:Add()
      return
    end
  end
end)

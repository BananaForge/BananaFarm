-- BananaFarm: Lasher Championships (Gilden-Wettbewerb, Modul "champ", Standard aus).
--
-- Jeder Spieler mit eingeschaltetem Modul schickt im Gildenkanal eine kurze Zusammenfassung seiner
-- Durchgaenge (eine Nachricht): Woche, Monat, gesamt, je Anzahl, Bestzeit (Gesamtzeit) und Gold.
-- Gold nur, wenn der Spieler das Teilen anschaltet (champGold). Daraus rechnet jeder Client die
-- Top-10-Listen selbst. Beim Login fragt man einmal nach ("Q"), die anderen antworten zeitversetzt.
-- Gesendet wird ausserdem nach jedem fertigen Durchgang.
-- Sonntags (erstes Mal am Tag) zeigt ein Pop-up die Wochensieger (schnellster Durchgang der Woche).
--
-- Nachrichten (Praefix BFLC, Gildenkanal):
--   Q                                       wer hat welche Zeiten?
--   S:wk:wn:wb:wg:mk:mn:mb:mg:an:ab:ag      wk/mk = Woche/Monat (Schluessel), n = Anzahl, b = Bestzeit
--                                           (Sekunden, 0 = keine), g = Gold in Kupfer ("-" = nicht geteilt)
-- Hinweis: Die Zahlen meldet jeder Client selbst, das ist ein Wettbewerb unter Freunden.

local BF = BananaFarm
local getn = table.getn
local floor = math.floor

BF.Champ = { sentAt = -100 }
local CH = BF.Champ
local PREFIX = "BFLC"
local MIN_HEAT = 30 -- kuerzere Durchgaenge sind unplausibel und zaehlen nicht

local function db()
  local d = BananaFarmDB.champ
  if not d then
    d = { players = {} }
    BananaFarmDB.champ = d
  end
  d.players = d.players or {}
  return d
end

function CH:Active()
  return BF:Enabled("champ") and IsInGuild and IsInGuild() and SendAddonMessage ~= nil
end

-- eigene Kennzahlen
function CH:Mine()
  local SR = BF.Speedrun
  local wn, wb, wg = SR:PeriodStats(SR.WeekStart())
  local mn, mb, mg = SR:PeriodStats(SR.MonthStart())
  local an, ab, ag = SR:PeriodStats(nil)
  local e = { wk = SR.WeekKey(), mk = SR.MonthKey(), wn = wn, wb = wb or 0, mn = mn, mb = mb or 0,
    an = an, ab = ab or 0, t = time() }
  if BananaFarmDB.champGold then
    e.wg, e.mg, e.ag = wg or 0, mg or 0, ag or 0
  end
  return e
end

local function g(v)
  if v == nil then return "-" end
  return tostring(floor(v))
end

function CH:Send()
  if not self:Active() then return end
  local e = self:Mine()
  db().players[UnitName("player")] = e
  self.sentAt = GetTime()
  SendAddonMessage(PREFIX, "S:" .. e.wk .. ":" .. e.wn .. ":" .. floor(e.wb) .. ":" .. g(e.wg) .. ":"
    .. e.mk .. ":" .. e.mn .. ":" .. floor(e.mb) .. ":" .. g(e.mg) .. ":"
    .. e.an .. ":" .. floor(e.ab) .. ":" .. g(e.ag), "GUILD")
  if BF.UI then BF.UI:RefreshSpeedrun() end
end

-- nach jedem fertigen (oder geloeschten) Durchgang
function CH:OnHeat(quiet)
  if not self:Active() then return end
  BF:After(2, function() CH:Send() end, "champsend")
end

local function num(v)
  if v == "-" then return nil end
  return tonumber(v)
end

BF:On("CHAT_MSG_ADDON", function(prefix, msg, dist, sender)
  if prefix ~= PREFIX or type(msg) ~= "string" or type(sender) ~= "string" then return end
  if not CH:Active() or dist ~= "GUILD" then return end
  if sender == UnitName("player") then return end
  if msg == "Q" then
    -- zeitversetzt antworten, damit nicht alle gleichzeitig senden; wer gerade gesendet hat, schweigt
    if GetTime() - CH.sentAt < 30 then return end
    BF:After(2 + math.random() * 8, function()
      if GetTime() - CH.sentAt >= 30 then CH:Send() end
    end, "champreply")
    return
  end
  if string.sub(msg, 1, 2) ~= "S:" then return end
  local f = {}
  for v in string.gfind(string.sub(msg, 3), "([^:]+)") do table.insert(f, v) end
  if getn(f) < 11 then return end
  local e = { wk = f[1], wn = tonumber(f[2]) or 0, wb = tonumber(f[3]) or 0, wg = num(f[4]),
    mk = f[5], mn = tonumber(f[6]) or 0, mb = tonumber(f[7]) or 0, mg = num(f[8]),
    an = tonumber(f[9]) or 0, ab = tonumber(f[10]) or 0, ag = num(f[11]), t = time() }
  db().players[sender] = e
  if BF.UI then BF.UI:RefreshSpeedrun() end
end)

-- ------------------------------------------------------------
-- Bestenlisten
-- ------------------------------------------------------------
-- cat: "fast" (schnellster Durchgang aller Zeiten) | "week" | "month" | "all"
-- sort: "n" (Anzahl Durchgaenge) | "best" (Bestzeit) | "gold"
-- Liefert bis zu 10 Zeilen { name, n, best, gold }
function CH:Ranking(cat, sort)
  local SR = BF.Speedrun
  local wk, mk = SR.WeekKey(), SR.MonthKey()
  local rows = {}
  -- eigene Zahlen immer frisch
  if BF:Enabled("champ") then db().players[UnitName("player")] = self:Mine() end
  for name, e in pairs(db().players) do
    local n, best, gold
    if cat == "week" then
      if e.wk == wk then n, best, gold = e.wn, e.wb, e.wg end
    elseif cat == "month" then
      if e.mk == mk then n, best, gold = e.mn, e.mb, e.mg end
    else
      n, best, gold = e.an, e.ab, e.ag
    end
    if n and n > 0 then
      if not best or best < MIN_HEAT then best = nil end
      table.insert(rows, { name = name, n = n, best = best, gold = gold })
    end
  end
  if cat == "fast" then sort = "best" end
  local filtered = {}
  for i = 1, getn(rows) do
    local r = rows[i]
    if (sort ~= "best" or r.best) and (sort ~= "gold" or r.gold) then table.insert(filtered, r) end
  end
  table.sort(filtered, function(a, b)
    if sort == "best" then
      if a.best ~= b.best then return a.best < b.best end
    elseif sort == "gold" then
      if a.gold ~= b.gold then return a.gold > b.gold end
    else
      if a.n ~= b.n then return a.n > b.n end
      if a.best and b.best and a.best ~= b.best then return a.best < b.best end
    end
    return a.name < b.name
  end)
  local out = {}
  for i = 1, getn(filtered) do
    if i > 10 then break end
    table.insert(out, filtered[i])
  end
  return out
end

function CH:PlayerCount()
  local n = 0
  for _ in pairs(db().players) do n = n + 1 end
  return n
end

-- ------------------------------------------------------------
-- Wochensieger: sonntags einmal beim Login (nach dem Datenabgleich)
-- ------------------------------------------------------------
function CH:CheckSunday()
  if not BF:Enabled("champ") then return end
  local d = date("*t")
  if d.wday ~= 1 then return end
  local key = BF.Speedrun.WeekKey()
  if db().shownWeek == key then return end
  local top = self:Ranking("week", "best")
  if getn(top) == 0 then return end
  db().shownWeek = key
  if BF.UI then BF.UI:ShowWinners(top) end
end

BF:On("PLAYER_ENTERING_WORLD", function()
  if CH.loginDone then return end
  CH.loginDone = true
  BF:After(20, function()
    if CH:Active() then
      SendAddonMessage(PREFIX, "Q", "GUILD")
      CH:Send()
    end
  end, "champlogin")
  BF:After(40, function() CH:CheckSunday() end, "champsunday")
end)

-- BananaFarm UI: Hauptfenster (Listen, Einstellungen), kleine Leiste, Zuordnungs-Pop-up,
-- Abfragefenster und Textfenster. Stil wie die anderen BananaForge-Addons: dunkel mit Bananengold.

local BF = BananaFarm
local T = function(k) return BF.T(k) end
local getn = table.getn
local floor = math.floor

BF.UI = { loc = {}, sel = "V", offset = 0, page = "lists" }
local UI = BF.UI

local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_TITLE = "Fonts\\MORPHEUS.TTF"
local WHITE = "Interface\\ChatFrame\\ChatFrameBackground"
local ROWS = 18
local ROW_H = 22

UI.C = {
  gold = { 1.00, 0.82, 0.26 },
  goldDim = { 0.78, 0.60, 0.22 },
  brass = { 0.55, 0.40, 0.16 },
  text = { 0.92, 0.90, 0.84 },
  muted = { 0.60, 0.62, 0.70 },
  bg = { 0.03, 0.045, 0.09 },
  panel = { 0.055, 0.08, 0.16 },
}
local C = UI.C

UI.BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- ------------------------------------------------------------
-- Bausteine
-- ------------------------------------------------------------
function UI:Font(parent, size, color, font)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(font or FONT, size or 12, "")
  color = color or C.text
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
  fs:SetJustifyH("LEFT")
  return fs
end

-- Text haengt an einem Locale-Schluessel und wechselt mit der Sprache
function UI:Loc(fs, key)
  fs:SetText(T(key))
  table.insert(self.loc, { fs = fs, key = key })
  return fs
end

function UI:Window(name, w, h)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetWidth(w)
  f:SetHeight(h)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    BananaFarmDB.pos[this:GetName()] = { x = this:GetLeft(), y = this:GetTop() }
  end)
  f:SetBackdrop(self.BACKDROP)
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
  f:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.9)
  -- deckender Untergrund: sonst schimmert die Spielwelt durch
  local solid = f:CreateTexture(nil, "BACKGROUND")
  solid:SetTexture(WHITE)
  solid:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
  solid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
  solid:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 0.97)
  local p = BananaFarmDB.pos[name]
  if p and p.x and p.y then
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
  end
  f:Hide()
  return f
end

function UI:HLine(parent, y, x1, x2)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetTexture(WHITE)
  t:SetVertexColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 0.7)
  t:SetHeight(1)
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", x1, y)
  t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x2, y)
  return t
end

-- Knopf im BananaForge-Stil. style: nil | "primary" | "danger" | "ok" | "flat"
function UI:Button(parent, w, h, key, onClick, style)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w)
  b:SetHeight(h)
  b:SetBackdrop(self.BACKDROP)
  local bg = { 0.09, 0.13, 0.27 }
  local tc = C.gold
  if style == "primary" then
    bg = { 0.50, 0.34, 0.05 }
    tc = { 1, 0.95, 0.80 }
  elseif style == "danger" then
    bg = { 0.38, 0.08, 0.06 }
    tc = { 1, 0.85, 0.80 }
  elseif style == "ok" then
    bg = { 0.10, 0.32, 0.12 }
    tc = { 0.85, 1, 0.85 }
  elseif style == "flat" then
    bg = { 0.05, 0.07, 0.14 }
  end
  b.bgColor, b.textColor = bg, tc
  b:SetBackdropColor(bg[1], bg[2], bg[3], 0.95)
  b:SetBackdropBorderColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 0.9)

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(WHITE)
  hl:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  hl:SetVertexColor(1, 0.82, 0.3, 0.15)

  local fs = self:Font(b, h >= 26 and 13 or 11, tc)
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  fs:SetJustifyH("CENTER")
  b.fs = fs
  if key then
    if BF.L.enUS[key] then self:Loc(fs, key) else fs:SetText(key) end
  end
  b:SetScript("OnClick", function()
    PlaySound("igMainMenuOptionCheckBoxOn")
    if onClick then onClick(b, arg1) end
  end)
  -- hervorgehoben (gewaehlter Reiter, gewaehlte Liste)
  b.SetActive = function(self2, on)
    if on then
      fs:SetTextColor(1, 0.95, 0.6)
      b:SetBackdropColor(0.40, 0.28, 0.05, 0.95)
    else
      fs:SetTextColor(tc[1], tc[2], tc[3])
      b:SetBackdropColor(bg[1], bg[2], bg[3], 0.95)
    end
  end
  return b
end

-- Umschalter mit Haken, haengt direkt an einem Feld der Datenbank
function UI:Check(parent, key, field, onChange)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(380)
  b:SetHeight(18)
  local box = CreateFrame("Frame", nil, b)
  box:SetWidth(16)
  box:SetHeight(16)
  box:SetPoint("LEFT", b, "LEFT", 0, 0)
  box:SetBackdrop(self.BACKDROP)
  box:SetBackdropColor(0.02, 0.03, 0.06, 1)
  box:SetBackdropBorderColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 1)
  local chk = box:CreateTexture(nil, "OVERLAY")
  chk:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  chk:SetWidth(22)
  chk:SetHeight(22)
  chk:SetPoint("CENTER", box, "CENTER", 1, 1)
  local fs = self:Font(b, 11, C.text)
  fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
  self:Loc(fs, key)
  -- field: Name eines Feldes der Datenbank oder { get = fn, set = fn }
  local function get()
    if type(field) == "table" then return field.get() end
    return BananaFarmDB[field]
  end
  b.Update = function()
    if get() then chk:Show() else chk:Hide() end
  end
  b:SetScript("OnClick", function()
    if type(field) == "table" then field.set(not get()) else BananaFarmDB[field] = not get() end
    PlaySound("igMainMenuOptionCheckBoxOn")
    b.Update()
    if onChange then onChange() end
  end)
  b.Update()
  return b
end

-- Eingabefeld: uebernimmt beim Verlassen (Enter, Klick woanders), Escape verwirft
function UI:EditBox(name, parent, w, getter, setter, maxLetters)
  local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  e:SetWidth(w)
  e:SetHeight(20)
  e:SetAutoFocus(false)
  e:SetFontObject("ChatFontNormal")
  e:SetMaxLetters(maxLetters or 24)
  e.Update = function() e:SetText(getter()) end
  e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  e:SetScript("OnEscapePressed", function()
    this:SetText(getter())
    this:ClearFocus()
  end)
  e:SetScript("OnEditFocusLost", function()
    if this:GetText() ~= getter() then setter(this:GetText()) end
    this:SetText(getter())
  end)
  return e
end

-- Item-Tooltip nur ueber den Cache (SetHyperlink auf unbekannte Items kann in 1.12 trennen)
function UI:ItemTooltip(owner, id, extra)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if GetItemInfo(id) then
    GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
  else
    local n, q = BF:ItemInfo(id)
    local c = BF.QUALITY_COLOR[q or 1] or BF.QUALITY_COLOR[1]
    GameTooltip:AddLine(n, c[1], c[2], c[3])
  end
  if extra then
    GameTooltip:AddLine(" ")
    for i = 1, getn(extra) do GameTooltip:AddLine(extra[i], 0.8, 0.8, 0.8) end
  end
  GameTooltip:Show()
end

local function moneyOrDash(v)
  if v and v > 0 then return BF.Money(v) end
  return "|cff808590" .. T("UNKNOWN") .. "|r"
end

-- Mailziel einer Zeile: zugeordnet in Gold, Standardziel gedaempft
local function targetText(id)
  local to = BF.Mail:TargetOf(id)
  if not to then return "|cff808590" .. T("UNKNOWN") .. "|r" end
  if BF.Mail:IsTarget(BananaFarmDB.mailTarget[id]) then return "|cffffd100" .. to .. "|r" end
  return "|cff9a9cb3" .. to .. "|r"
end

local function ahText(id)
  local u = BF:AHNet(id)
  if u then return BF.Money(u) end
  if BF:AHAbsent(id) then return "|cff808590" .. T("NOT_IN_AH") .. "|r" end
  return "|cff808590" .. T("UNKNOWN") .. "|r"
end

-- ------------------------------------------------------------
-- Aufbau
-- ------------------------------------------------------------
function UI:Init()
  if self.frame then return end
  self:BuildMain()
  self:BuildBar()
  self:BuildAssign()
  self:BuildConfirm()
  self:BuildSetup()
  self:BuildSetupStep()
  BF.Lists:HookBags()
  self:Refresh()
  if not BananaFarmDB.setupDone then self:ShowSetup() end
end

function UI:BuildMain()
  local f = self:Window("BananaFarmFrame", 480, 600)
  self.frame = f
  if not BananaFarmDB.pos["BananaFarmFrame"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
  tinsert(UISpecialFrames, "BananaFarmFrame")

  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(BF.ICON)
  logo:SetWidth(32)
  logo:SetHeight(32)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -7)
  local title = self:Font(f, 20, C.gold, FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -12)
  title:SetText("BananaFarm")
  local sub = self:Font(f, 10, C.muted)
  sub:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 3)
  self:Loc(sub, "TITLE_SUB")
  local ver = self:Font(f, 9, C.muted)
  ver:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -34)
  ver:SetText("v" .. BF.VERSION)

  local close = self:Button(f, 22, 22, "X", function() f:Hide() end, "danger")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)

  self.tabLists = self:Button(f, 70, 24, "TAB_LISTS", function() UI:ShowPage("lists") end)
  self.tabLists:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -42)
  self.tabSettings = self:Button(f, 100, 24, "TAB_SETTINGS", function() UI:ShowPage("settings") end)
  self.tabSettings:SetPoint("LEFT", self.tabLists, "RIGHT", 6, 0)
  self.tabModules = self:Button(f, 70, 24, "TAB_MODULES", function() UI:ShowPage("modules") end)
  self.tabModules:SetPoint("LEFT", self.tabSettings, "RIGHT", 6, 0)
  self.tabSpeed = self:Button(f, 80, 24, "TAB_SPEEDRUN", function() UI:ShowPage("speedrun") end)
  self.tabSpeed:SetPoint("LEFT", self.tabModules, "RIGHT", 6, 0)
  self.tabWish = self:Button(f, 80, 24, "TAB_WISH", function() UI:ShowPage("wish") end)
  self.tabWish:SetPoint("LEFT", self.tabSpeed, "RIGHT", 6, 0)

  -- Session-Zeile oben rechts (Start/Stopp der Session gibt es nur in der Leiste)
  self.sessText = self:Font(f, 10, C.text)
  self.sessText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -18)
  self.sessText:SetJustifyH("RIGHT")

  self:HLine(f, -72, 12, -12)

  self.pageLists = CreateFrame("Frame", nil, f)
  self.pageLists:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -74)
  self.pageLists:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  self:BuildLists(self.pageLists)

  self.pageSettings = CreateFrame("Frame", nil, f)
  self.pageSettings:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -74)
  self.pageSettings:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  self:BuildSettings(self.pageSettings)

  self.pageModules = CreateFrame("Frame", nil, f)
  self.pageModules:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -74)
  self.pageModules:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  self:BuildModules(self.pageModules)

  self.pageSpeedrun = CreateFrame("Frame", nil, f)
  self.pageSpeedrun:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -74)
  self.pageSpeedrun:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  self:BuildSpeedrun(self.pageSpeedrun)

  self.pageWish = CreateFrame("Frame", nil, f)
  self.pageWish:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -74)
  self.pageWish:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  self:BuildWish(self.pageWish)

  -- einmal pro Sekunde die Session-Zeile auffrischen
  f.tick = 0
  f:SetScript("OnUpdate", function()
    this.tick = this.tick + (arg1 or 0)
    if this.tick < 1 then return end
    this.tick = 0
    UI:RefreshSession()
  end)
  f:SetScript("OnShow", function() UI:Refresh() end)
end

-- ------------------------------------------------------------
-- Seite Listen
-- ------------------------------------------------------------
function UI:BuildLists(p)
  self.chips = {}
  local prev
  for i = 1, getn(BF.LIST_KEYS) do
    local key = BF.LIST_KEYS[i]
    local b = self:Button(p, 86, 22, nil, function()
      UI.sel = key
      UI.offset = 0
      UI:RefreshList()
    end, "flat")
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -6) end
    prev = b
    self.chips[key] = b
  end

  local h1 = self:Font(p, 10, C.muted)
  h1:SetPoint("TOPLEFT", p, "TOPLEFT", 40, -36)
  self:Loc(h1, "COL_ITEM")
  local h2 = self:Font(p, 10, C.muted)
  h2:SetPoint("TOPRIGHT", p, "TOPLEFT", 300, -36)
  self:Loc(h2, "COL_VENDOR")
  self.colVendor = h2
  local h3 = self:Font(p, 10, C.muted)
  h3:SetPoint("TOPRIGHT", p, "TOPLEFT", 376, -36)
  self:Loc(h3, "COL_AH")

  self.rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("Button", nil, p)
    r:SetHeight(ROW_H - 2)
    r:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -50 - (i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -50 - (i - 1) * ROW_H)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetAllPoints(r)
    if BF.mod(i, 2) == 0 then bg:SetVertexColor(1, 1, 1, 0.03) else bg:SetVertexColor(1, 1, 1, 0.07) end
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(18)
    r.icon:SetHeight(18)
    r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.name = self:Font(r, 11)
    r.name:SetPoint("LEFT", r, "LEFT", 26, 0)
    r.name:SetWidth(186)
    r.name:SetHeight(12)
    r.vendor = self:Font(r, 10)
    r.vendor:SetPoint("RIGHT", r, "LEFT", 286, 0)
    r.vendor:SetJustifyH("RIGHT")
    r.ah = self:Font(r, 10)
    r.ah:SetPoint("RIGHT", r, "LEFT", 362, 0)
    r.ah:SetJustifyH("RIGHT")
    -- Mailliste: Klick auf das Ziel schaltet es weiter, Rechtsklick zurueck
    r.tgt = CreateFrame("Button", nil, r)
    r.tgt:SetWidth(76)
    r.tgt:SetHeight(18)
    r.tgt:SetPoint("RIGHT", r, "LEFT", 290, 0)
    r.tgt:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.tgt:SetScript("OnClick", function()
      local row = this:GetParent()
      if not row.id then return end
      PlaySound("igMainMenuOptionCheckBoxOn")
      BF.Mail:CycleTarget(row.id, arg1 == "RightButton" and -1 or 1)
      UI:RefreshList()
    end)
    r.tgt:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      local many = getn(BananaFarmDB.mailTargets) > 1
      GameTooltip:AddLine(T(many and "TT_TARGET" or "TT_TARGET_NONE"), 1, 0.82, 0.26)
      GameTooltip:Show()
    end)
    r.tgt:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.tgt:Hide()
    r:SetScript("OnEnter", function()
      if not this.id then return end
      local extra = { T(BF.Lists:IsManual(this.id) and "TT_MANUAL" or "TT_AUTO") }
      if BananaFarmDB.noSell[this.id] then table.insert(extra, "|cffff6050" .. T("TT_NOSELL") .. "|r") end
      UI:ItemTooltip(this, this.id, extra)
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Knoepfe: auf eine andere Liste schieben oder entfernen
    r.btn = {}
    local defs = { { "V", "V" }, { "M", "M" }, { "I", "I" }, { "K", "K" }, { "X", nil } }
    for j = 1, 5 do
      local list = defs[j][2]
      local label = defs[j][1]
      local b = self:Button(r, 16, 18, label, function()
        local id = r.id
        if not id then return end
        BF.Lists:Set(id, list)
      end, list and "flat" or "danger")
      b:SetPoint("RIGHT", r, "RIGHT", -2 - (5 - j) * 17, 0)
      b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(list and T("LIST_" .. list) or T("TT_REMOVE"), 1, 0.82, 0.26)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r.btn[label] = b
    end
    self.rows[i] = r
  end

  self.empty = self:Font(p, 11, C.muted)
  self.empty:SetPoint("TOP", p, "TOP", 0, -110)
  self:Loc(self.empty, "EMPTY_LIST")

  p:EnableMouseWheel(true)
  p:SetScript("OnMouseWheel", function()
    UI.offset = UI.offset - (arg1 or 0) * 3
    UI:RefreshList()
  end)

  local y = -50 - ROWS * ROW_H - 6
  self.pageText = self:Font(p, 10, C.muted)
  self.pageText:SetPoint("TOPRIGHT", p, "TOPRIGHT", -62, y - 4)
  self.pageText:SetJustifyH("RIGHT")
  local up = self:Button(p, 20, 18, "<", function()
    UI.offset = UI.offset - ROWS
    UI:RefreshList()
  end, "flat")
  up:SetPoint("TOPRIGHT", p, "TOPRIGHT", -36, y)
  local down = self:Button(p, 20, 18, ">", function()
    UI.offset = UI.offset + ROWS
    UI:RefreshList()
  end, "flat")
  down:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, y)

  self.scanBtn = self:Button(p, 110, 22, "BTN_SCAN", function()
    if BF.scan then BF:StopAHScan() else BF:StartAHScan() end
  end)
  self.scanBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y)
  self.scanText = self:Font(p, 10, C.muted)
  self.scanText:SetPoint("LEFT", self.scanBtn, "RIGHT", 8, 0)

  local hint = self:Font(p, 10, C.muted)
  hint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 12)
  hint:SetWidth(448)
  self:Loc(hint, "HINT_ALT")
  self.hint = hint
end

function UI:RefreshList()
  if not self.frame or not self.frame:IsVisible() or self.page ~= "lists" then return end
  for i = 1, getn(BF.LIST_KEYS) do
    local key = BF.LIST_KEYS[i]
    local b = self.chips[key]
    b.fs:SetText(T("LIST_" .. key) .. " (" .. BF.Lists:CountOf(key) .. ")")
    b:SetActive(key == self.sel)
  end
  -- auf der Mailliste steht statt des Haendlerwerts das Mailziel
  local mailTab = self.sel == "M"
  self.colVendor:SetText(T(mailTab and "COL_TARGET" or "COL_VENDOR"))
  self.hint:SetText(T(mailTab and "HINT_MAIL" or "HINT_ALT"))
  local ids = BF.Lists:IDs(self.sel)
  local n = getn(ids)
  if self.offset > n - ROWS then self.offset = n - ROWS end
  if self.offset < 0 then self.offset = 0 end
  for i = 1, ROWS do
    local r = self.rows[i]
    local id = ids[self.offset + i]
    r.id = id
    if id then
      local name, q, tex = BF:ItemInfo(id)
      local c = BF.QUALITY_COLOR[q or 1] or BF.QUALITY_COLOR[1]
      r.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
      r.name:SetText(name)
      r.name:SetTextColor(c[1], c[2], c[3])
      if mailTab then
        r.vendor:SetText(targetText(id))
        r.tgt:Show()
      else
        r.vendor:SetText(moneyOrDash(BF:VendorValue(id)))
        r.tgt:Hide()
      end
      r.ah:SetText(ahText(id))
      for label, b in pairs(r.btn) do
        if label == self.sel then b:Hide() else b:Show() end
      end
      r:Show()
    else
      r:Hide()
    end
  end
  if n == 0 then self.empty:Show() else self.empty:Hide() end
  if n > ROWS then
    local last = self.offset + ROWS
    if last > n then last = n end
    self.pageText:SetText((self.offset + 1) .. "-" .. last .. " / " .. n)
  else
    self.pageText:SetText("")
  end
  self:RefreshScan()
end

function UI:RefreshScan()
  if not self.frame or not self.frame:IsVisible() then return end
  local s = BF.scan
  if s then
    self.scanBtn.fs:SetText(T("BTN_STOPSCAN"))
    self.scanText:SetText(string.format(T("SCAN_PROGRESS"), s.idx - 1, getn(s.ids)))
  else
    self.scanBtn.fs:SetText(T("BTN_SCAN"))
    local n = 0
    for _, p in pairs(BananaFarmDB.ah) do
      if (p.u or 0) > 0 then n = n + 1 end
    end
    self.scanText:SetText(string.format(T("SCAN_IDLE"), n))
  end
end

-- ------------------------------------------------------------
-- Seite Einstellungen
-- ------------------------------------------------------------
local function num(text)
  text = string.gsub(text or "", ",", ".")
  return tonumber(text)
end

local function resort()
  BF.Lists:Reclassify()
  UI:Refresh()
end

function UI:BuildSettings(p)
  self.edits = {}
  self.checks = {}
  local y = -10

  local function editRow(key, name, w, getter, setter, maxLetters)
    local e = self:EditBox(name, p, w, getter, setter, maxLetters)
    e:SetPoint("TOPLEFT", p, "TOPLEFT", 24, y)
    local fs = self:Font(p, 11)
    fs:SetPoint("LEFT", e, "RIGHT", 10, 0)
    self:Loc(fs, key)
    table.insert(self.edits, e)
    y = y - 26
  end

  editRow("SET_ALT", "BananaFarmEditAlt", 110,
    function() return BananaFarmDB.bankAlt end,
    function(v) BF:SetBankAlt(v) end)
  editRow("SET_MAILTARGETS", "BananaFarmEditMailTargets", 220,
    function() return table.concat(BananaFarmDB.mailTargets, ", ") end,
    function(v) BF.Mail:SetTargets(v) end, 120)
  editRow("SET_THRESHOLD", "BananaFarmEditThreshold", 50,
    function() return tostring(BananaFarmDB.threshold) end,
    function(v)
      local n = num(v)
      if n and n >= 0 then
        BananaFarmDB.threshold = n
        resort()
      end
    end)
  editRow("SET_MINAH", "BananaFarmEditMinAH", 50,
    function() return tostring(BananaFarmDB.minAH / 100) end,
    function(v)
      local n = num(v)
      if n and n >= 0 then
        BananaFarmDB.minAH = floor(n * 100 + 0.5)
        resort()
      end
    end)
  editRow("SET_BAGWARN", "BananaFarmEditBagWarn", 50,
    function() return tostring(BananaFarmDB.bagWarn) end,
    function(v)
      local n = num(v)
      if n and n >= 0 then BananaFarmDB.bagWarn = floor(n) end
    end)
  editRow("SET_RESETLIMIT", "BananaFarmEditResetLimit", 50,
    function() return tostring(BananaFarmDB.resetLimit) end,
    function(v)
      local n = num(v)
      if n and n >= 1 then BananaFarmDB.resetLimit = floor(n) end
    end)
  editRow("SET_PULLLIMIT", "BananaFarmEditPullLimit", 50,
    function() return tostring(BananaFarmDB.pullLimit) end,
    function(v)
      local n = num(v)
      if n and n >= 1 then BananaFarmDB.pullLimit = floor(n) end
    end)

  y = y - 6
  local function checkRow(key, field, onChange)
    local c = self:Check(p, key, field, onChange)
    c:SetPoint("TOPLEFT", p, "TOPLEFT", 20, y)
    table.insert(self.checks, c)
    y = y - 22
  end
  checkRow("CHK_AHCUT", "ahCut", resort)
  checkRow("CHK_GRAY", "grayVendor", resort)
  checkRow("CHK_POPUP", "popup", function() BF.Lists:PopNext() end)
  checkRow("CHK_AUTOSELL", "autoSell")
  checkRow("CHK_PROTECT", "protect")
  checkRow("CHK_HUNTER", { get = function() return BF:HunterMode() end, set = function(v) BF:SetHunterMode(v) end },
    function() UI:Refresh() end)
  checkRow("CHK_MAILASK", "mailAsk")
  checkRow("CHK_ALTCLICK", "altClick")
  checkRow("CHK_BAR", "bar", function() UI:Refresh() end)
  checkRow("CHK_KEEP", "keepProtect")
  checkRow("CHK_SYNC", "autoSync")

  y = y - 10
  local lang = self:Font(p, 11)
  lang:SetPoint("TOPLEFT", p, "TOPLEFT", 20, y - 4)
  self:Loc(lang, "SET_LANG")
  self.langBtns = {}
  local defs = { { "de", "Deutsch" }, { "en", "English" }, { "auto", "Auto" } }
  for i = 1, 3 do
    local code = defs[i][1]
    local b = self:Button(p, 76, 22, defs[i][2], function() UI:SetLanguage(code) end, "flat")
    b:SetPoint("TOPLEFT", p, "TOPLEFT", 110 + (i - 1) * 80, y)
    self.langBtns[code] = b
  end

  local probe = self:Button(p, 140, 24, "BTN_PROBE", function() BF:Probe() end)
  probe:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 18, 14)
end

function UI:RefreshSettings()
  for i = 1, getn(self.edits) do self.edits[i].Update() end
  for i = 1, getn(self.checks) do self.checks[i].Update() end
  for code, b in pairs(self.langBtns) do b:SetActive(BananaFarmDB.lang == code) end
end

-- ------------------------------------------------------------
-- Module: Reiter im Hauptfenster und Einrichtungsfenster beim ersten Start
-- ------------------------------------------------------------
function UI:ModuleChecks(parent, x, y)
  self.modChecks = self.modChecks or {}
  for i = 1, getn(BF.MODULES) do
    local name = BF.MODULES[i]
    local c = self:Check(parent, "MOD_" .. string.upper(name), {
      get = function() return BF:Enabled(name) end,
      set = function(v) BF:SetModule(name, v) end,
    }, function() UI:RefreshModules() end)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    table.insert(self.modChecks, c)
    y = y - 26
  end
  return y
end

function UI:UpdateModuleChecks()
  if not self.modChecks then return end
  for i = 1, getn(self.modChecks) do self.modChecks[i].Update() end
end

function UI:RefreshModules()
  self:UpdateModuleChecks()
  self:Refresh()
end

function UI:BuildModules(p)
  local info = self:Font(p, 11, C.muted)
  info:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -12)
  info:SetWidth(440)
  self:Loc(info, "MODULES_HINT")
  self:ModuleChecks(p, 20, -56)
end

function UI:BuildSetup()
  local f = self:Window("BananaFarmSetup", 440, 486)
  self.setup = f
  if not BananaFarmDB.pos["BananaFarmSetup"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 20) end
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(BF.ICON)
  icon:SetWidth(96)
  icon:SetHeight(96)
  icon:SetPoint("TOP", f, "TOP", 0, -14)
  local title = self:Font(f, 20, C.gold, FONT_TITLE)
  title:SetPoint("TOP", icon, "BOTTOM", 0, -4)
  title:SetText("BananaFarm")
  local text = self:Font(f, 11, C.text)
  text:SetPoint("TOP", title, "BOTTOM", 0, -8)
  text:SetWidth(390)
  text:SetJustifyH("CENTER")
  self:Loc(text, "SETUP_TEXT")
  self:ModuleChecks(f, 30, -202)
  local done = self:Button(f, 140, 26, "BTN_DONE", function() f:Hide() end, "primary")
  done:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
  -- auch Schliessen per Escape zaehlt als eingerichtet
  tinsert(UISpecialFrames, "BananaFarmSetup")
  f:SetScript("OnHide", function()
    local first = not BananaFarmDB.setupDone
    BananaFarmDB.setupDone = true
    UI:Refresh()
    -- beim ersten Mal folgen die Fragen nach dem Twink und den Mailchars
    if first then UI:ShowSetupStep("twink") end
  end)
end

-- Einrichtung, Schritt 2 und 3: Twink (Sync-Partner) und Mailchars. Leer lassen oder
-- Ueberspringen aendert nichts, das Feld in den Einstellungen bleibt dann leer.
function UI:BuildSetupStep()
  local f = self:Window("BananaFarmSetupStep", 400, 200)
  self.step = f
  if not BananaFarmDB.pos["BananaFarmSetupStep"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 60) end
  f.title = self:Font(f, 14, C.gold, FONT_TITLE)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
  f.text = self:Font(f, 11, C.text)
  f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
  f.text:SetWidth(368)
  f.text:SetJustifyH("LEFT")
  f.edit = self:EditBox("BananaFarmSetupStepEdit", f, 280,
    function() return f.value or "" end,
    function(v) f.value = v end, 120)
  f.edit:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 22, 56)
  local nextBtn = self:Button(f, 130, 24, "BTN_NEXT", function() UI:SetupStepDone(true) end, "primary")
  nextBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 14)
  local skip = self:Button(f, 130, 24, "BTN_SKIP", function() UI:SetupStepDone(false) end, "flat")
  skip:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 14)
  -- Escape zaehlt als Ueberspringen
  tinsert(UISpecialFrames, "BananaFarmSetupStep")
  f:SetScript("OnHide", function() UI:SetupStepDone(false) end)
end

function UI:ShowSetupStep(kind)
  if kind == "twink" and not BF:Enabled("sync") then kind = "mail" end
  if kind == "mail" and not BF:Enabled("mail") then return end
  local f = self.step
  f.kind = kind
  f.active = true
  if kind == "twink" then
    f.title:SetText(T("SETUP_TWINK_TITLE"))
    f.text:SetText(T("SETUP_TWINK_TEXT"))
    f.value = BananaFarmDB.bankAlt or ""
  else
    f.title:SetText(T("SETUP_MAIL_TITLE"))
    f.text:SetText(T("SETUP_MAIL_TEXT"))
    f.value = table.concat(BananaFarmDB.mailTargets, ", ")
  end
  f.edit.Update()
  f:Show()
end

function UI:SetupStepDone(save)
  local f = self.step
  if not f or not f.active then return end
  f.active = false
  local v = BF.Trim(f.edit:GetText() or "")
  f:Hide()
  if save and v ~= "" then
    if f.kind == "twink" then BF:SetBankAlt(v) else BF.Mail:SetTargets(v) end
  end
  if f.kind == "twink" then self:ShowSetupStep("mail") end
end

function UI:ShowSetup()
  self:UpdateModuleChecks()
  self.setup:Show()
end

-- Tastenbelegung und /bf bar: Leiste ein- oder ausblenden
function UI:ToggleBar()
  if not BF:Enabled("tracking") then
    BF:Print(T("ERR_MODULE_OFF"))
    return
  end
  BananaFarmDB.bar = not BananaFarmDB.bar
  self:Refresh()
end

-- ------------------------------------------------------------
-- Seiten, Sprache, Auffrischen
-- ------------------------------------------------------------
function UI:ShowPage(page)
  if page == "lists" and not BF:Enabled("items") then page = "settings" end
  if page == "speedrun" and not BF:Enabled("speedrun") then page = "settings" end
  if page == "wish" and not BF:Enabled("wish") then page = "settings" end
  self.page = page
  if page == "lists" then self.pageLists:Show() else self.pageLists:Hide() end
  if page == "settings" then self.pageSettings:Show() else self.pageSettings:Hide() end
  if page == "modules" then self.pageModules:Show() else self.pageModules:Hide() end
  if page == "speedrun" then self.pageSpeedrun:Show() else self.pageSpeedrun:Hide() end
  if page == "wish" then self.pageWish:Show() else self.pageWish:Hide() end
  if page ~= "wish" and BF.Wish then BF.Wish:Capture(false) end
  self.tabLists:SetActive(page == "lists")
  self.tabSettings:SetActive(page == "settings")
  self.tabModules:SetActive(page == "modules")
  self.tabSpeed:SetActive(page == "speedrun")
  self.tabWish:SetActive(page == "wish")
  self:RefreshList()
  self:RefreshSettings()
  self:RefreshSpeedrun()
  self:RefreshWish()
  self:UpdateModuleChecks()
end

-- ------------------------------------------------------------
-- Wunschliste: Items, Droprate, Mobs, Kills und die Chance bisher
-- ------------------------------------------------------------
local WISH_ROWS = 5
local WISH_MOBROWS = 5

local function wishPercent(c)
  return string.format("%.1f%%", c * 100)
end

local function wishRowText(e)
  local parts = { string.format(T("WISH_KILLS"), BF.Wish:Total(e)) }
  local info = BF.Wish:Info(e)
  if info then
    table.insert(parts, string.format(T("WISH_CHANCE"), wishPercent(info.chance)))
  else
    table.insert(parts, "|cffff9040" .. T("WISH_NORATE") .. "|r")
  end
  if getn(e.mobs) == 0 then table.insert(parts, "|cffff9040" .. T("WISH_NOMOBS_SHORT") .. "|r") end
  if (e.got or 0) > 0 then table.insert(parts, string.format(T("WISH_GOT_SHORT"), e.got)) end
  return table.concat(parts, "   ")
end

function UI:WishMob(i)
  local e = BF.Wish:Get(self.wishSel)
  return e and e.mobs[i] or nil
end

function UI:BuildWish(p)
  local w = { rows = {}, mrows = {} }
  self.w = w
  self.wishOffset = 0

  local add = self:Font(p, 10, C.muted)
  add:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -10)
  add:SetWidth(448)
  self:Loc(add, "WISH_ADD")
  w.input = self:EditBox("BananaFarmWishInput", p, 300, function() return "" end,
    function(v) BF.Wish:AddFromText(v) end, 200)
  w.input:SetPoint("TOPLEFT", p, "TOPLEFT", 22, -38)
  local inputLost = w.input:GetScript("OnEditFocusLost")
  w.input:SetScript("OnEditFocusGained", function() BF.Wish:Capture(true) end)
  w.input:SetScript("OnEditFocusLost", function()
    BF.Wish:Capture(false)
    if inputLost then inputLost() end
  end)

  w.empty = self:Font(p, 11, C.muted)
  w.empty:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -78)
  w.empty:SetWidth(448)
  self:Loc(w.empty, "WISH_EMPTY")

  for i = 1, WISH_ROWS do
    local r = CreateFrame("Button", nil, p)
    r:SetWidth(452)
    r:SetHeight(36)
    r:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -68 - (i - 1) * 38)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetTexture(WHITE)
    r.bg:SetAllPoints(r)
    r.bg:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(28)
    r.icon:SetHeight(28)
    r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.name = self:Font(r, 11)
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
    r.name:SetWidth(400)
    r.name:SetHeight(13)
    r.info = self:Font(r, 9, C.muted)
    r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.info:SetWidth(400)
    r:SetScript("OnClick", function()
      UI.wishSel = this.id
      UI:RefreshWish()
    end)
    r:SetScript("OnEnter", function()
      if this.id then UI:ItemTooltip(this, this.id) end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    w.rows[i] = r
  end

  p:EnableMouseWheel(true)
  p:SetScript("OnMouseWheel", function()
    UI.wishOffset = UI.wishOffset - (arg1 or 0)
    UI:RefreshWish()
  end)

  -- Mobs des gewaehlten Eintrags: je Zeile Name, Droprate, Kills und der Abstand zu 90 %.
  -- Beim Tippen wird ein Feld nicht von Kill-Meldungen ueberschrieben (typing).
  local function guard(edit)
    local lost = edit:GetScript("OnEditFocusLost")
    edit:SetScript("OnEditFocusGained", function() this.typing = true end)
    edit:SetScript("OnEditFocusLost", function()
      if lost then lost() end
      this.typing = false
    end)
  end

  local h1 = self:Font(p, 10, C.muted)
  h1:SetPoint("TOPLEFT", p, "TOPLEFT", 22, -266)
  h1:SetWidth(200)
  h1:SetJustifyH("LEFT")
  self:Loc(h1, "WISH_COL_MOB")
  local h2 = self:Font(p, 10, C.muted)
  h2:SetPoint("TOPLEFT", p, "TOPLEFT", 236, -266)
  h2:SetWidth(56)
  h2:SetJustifyH("CENTER")
  self:Loc(h2, "WISH_COL_RATE")

  for i = 1, WISH_MOBROWS do
    local y = -282 - (i - 1) * 26
    local k = i -- Lua 5.0: Closures teilen sich die Zaehlvariable, darum eine Kopie je Durchlauf
    local row = {}
    row.name = self:EditBox("BananaFarmWishMobName" .. i, p, 200,
      function()
        local m = UI:WishMob(k)
        return m and m.name or ""
      end,
      function(v)
        local e = BF.Wish:Get(UI.wishSel)
        local m = e and e.mobs[k]
        if not m then return end
        v = BF.Trim(v or "")
        if v == "" then table.remove(e.mobs, k) else m.name = v end
        UI:RefreshWish()
      end, 40)
    row.name:SetPoint("TOPLEFT", p, "TOPLEFT", 22, y)
    row.rate = self:EditBox("BananaFarmWishMobRate" .. i, p, 56,
      function()
        local m = UI:WishMob(k)
        if not m or (m.rate or 0) <= 0 then return "" end
        return tostring(m.rate)
      end,
      function(v)
        local m = UI:WishMob(k)
        if not m then return end
        local s = string.gsub(v or "", ",", ".")
        local n = tonumber(s) or 0
        if n < 0 then n = 0 elseif n > 100 then n = 100 end
        m.rate = n
        UI:RefreshWish()
      end, 7)
    row.rate:SetPoint("TOPLEFT", p, "TOPLEFT", 236, y)
    row.stat = self:Font(p, 10, C.muted)
    row.stat:SetPoint("TOPLEFT", p, "TOPLEFT", 304, y - 5)
    row.stat:SetWidth(140)
    row.stat:SetJustifyH("LEFT")
    row.del = self:Button(p, 22, 20, "x", function()
      local e = BF.Wish:Get(UI.wishSel)
      if e and e.mobs[k] then
        table.remove(e.mobs, k)
        UI:RefreshWish()
      end
    end, "danger")
    row.del:SetPoint("TOPLEFT", p, "TOPLEFT", 448, y - 1)
    guard(row.name)
    guard(row.rate)
    w.mrows[i] = row
  end

  local addMob = self:Button(p, 130, 22, "BTN_WISH_ADDMOB", function()
    local e = BF.Wish:Get(UI.wishSel)
    if not e then return end
    if getn(e.mobs) >= WISH_MOBROWS then
      BF:Print(string.format(T("MSG_WISH_MOBS_FULL"), WISH_MOBROWS))
      return
    end
    table.insert(e.mobs, { name = "", rate = 0, kills = 0 })
    UI:RefreshWish()
  end)
  addMob:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -418)
  local reset = self:Button(p, 140, 22, "BTN_WISH_RESET", function()
    local e = BF.Wish:Get(UI.wishSel)
    if e then
      BF.Wish:ResetKills(e)
      UI:RefreshWish()
    end
  end)
  reset:SetPoint("LEFT", addMob, "RIGHT", 6, 0)
  local remove = self:Button(p, 100, 22, "BTN_WISH_REMOVE", function()
    if UI.wishSel then
      BF.Wish:Remove(UI.wishSel)
      UI.wishSel = nil
      UI:RefreshWish()
    end
  end, "danger")
  remove:SetPoint("LEFT", reset, "RIGHT", 6, 0)

  w.stats = self:Font(p, 11, C.text)
  w.stats:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -448)
  w.stats:SetWidth(448)
  w.stats:SetHeight(44)
  w.stats:SetJustifyV("TOP")

  local hint = self:Font(p, 10, C.muted)
  hint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 10)
  hint:SetWidth(448)
  self:Loc(hint, "WISH_HINT")
end

function UI:RefreshWish()
  local w = self.w
  if not w or not self.pageWish:IsVisible() then return end
  local list = BananaFarmDB.wish
  local n = getn(list)
  if self.wishSel and not BF.Wish:Get(self.wishSel) then self.wishSel = nil end
  if not self.wishSel and n > 0 then self.wishSel = list[1].id end
  local maxOff = n - WISH_ROWS
  if maxOff < 0 then maxOff = 0 end
  if self.wishOffset > maxOff then self.wishOffset = maxOff end
  if self.wishOffset < 0 then self.wishOffset = 0 end

  if n == 0 then w.empty:Show() else w.empty:Hide() end
  for i = 1, WISH_ROWS do
    local r, e = w.rows[i], list[self.wishOffset + i]
    if e then
      local name, q, tex = BF:ItemInfo(e.id)
      local col = BF.QUALITY_COLOR[q or 1] or BF.QUALITY_COLOR[1]
      r.id = e.id
      r.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
      r.name:SetText(name)
      r.name:SetTextColor(col[1], col[2], col[3])
      r.info:SetText(wishRowText(e))
      r.bg:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], (e.id == self.wishSel) and 0.18 or 0)
      r:Show()
    else
      r.id = nil
      r:Hide()
    end
  end

  local e = BF.Wish:Get(self.wishSel)
  for i = 1, WISH_MOBROWS do
    local row, m = w.mrows[i], e and e.mobs[i]
    if m then
      row.name:Show()
      row.rate:Show()
      row.stat:Show()
      row.del:Show()
      if not row.name.typing then row.name.Update() end
      if not row.rate.typing then row.rate.Update() end
      local kills = m.kills or 0
      local left = BF.Wish:Left(e, m, 0.9)
      if left == nil then
        row.stat:SetText(string.format(T("WISH_MOB_KILLS"), kills))
      elseif left == 0 then
        row.stat:SetText(string.format(T("WISH_MOB_DONE"), kills))
      else
        row.stat:SetText(string.format(T("WISH_MOB_STAT"), kills, left))
      end
    else
      row.name:Hide()
      row.rate:Hide()
      row.stat:Hide()
      row.del:Hide()
    end
  end

  if not e then
    w.stats:SetText("")
    return
  end
  local lines = {}
  local info = BF.Wish:Info(e)
  if info then
    table.insert(lines, string.format(T("WISH_S_CHANCE"), wishPercent(info.chance), info.total))
    if info.reached then
      table.insert(lines, T("WISH_S_REACHED"))
    else
      table.insert(lines, string.format(T("WISH_S_BEST"), info.name, info.left90, info.left50))
    end
  elseif getn(e.mobs) == 0 then
    table.insert(lines, "|cffff9040" .. T("WISH_S_NOMOBS") .. "|r")
  else
    table.insert(lines, "|cffff9040" .. T("WISH_S_NORATE") .. "|r")
  end
  if (e.got or 0) > 0 then table.insert(lines, string.format(T("WISH_S_GOT"), e.got, e.last or 0)) end
  w.stats:SetText(table.concat(lines, "\n"))
end

-- ------------------------------------------------------------
-- Speedrun: Statistik, Sessions mit Blockzeit, Rundenzeiten, Posten in den Chat
-- ------------------------------------------------------------
local SR_SESS_ROWS = 7
local SR_LAP_ROWS = 9

function UI:BuildSpeedrun(p)
  local sr = { sess = {}, laps = {} }
  self.sr = sr
  sr.stats = self:Font(p, 11, C.text)
  sr.stats:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -10)
  sr.stats:SetWidth(448)
  sr.stats2 = self:Font(p, 11, C.text)
  sr.stats2:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -28)
  sr.stats2:SetWidth(448)

  local function head(y, key)
    local h = self:Font(p, 11, C.gold)
    h:SetPoint("TOPLEFT", p, "TOPLEFT", 16, y)
    self:Loc(h, key)
    self:HLine(p, y - 16, 16, -16)
  end
  local function col(y, x, w, key)
    local fs = self:Font(p, 10, C.muted)
    fs:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
    fs:SetWidth(w)
    fs:SetJustifyH("CENTER")
    self:Loc(fs, key)
  end
  local function cell(y, x, w)
    local fs = self:Font(p, 11, C.text)
    fs:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
    fs:SetWidth(w)
    fs:SetHeight(14)
    fs:SetJustifyH("CENTER")
    return fs
  end

  -- Sessions
  head(-52, "SR_H_SESSIONS")
  col(-72, 16, 110, "SR_COL_DATE")
  col(-72, 130, 50, "SR_COL_RESETS")
  col(-72, 190, 80, "SR_COL_TIME")
  col(-72, 280, 120, "SR_COL_BLOCK")
  for i = 1, SR_SESS_ROWS do
    local y = -90 - (i - 1) * 18
    local k = i -- Lua 5.0: Closures teilen sich die Zaehlvariable, darum eine Kopie je Durchlauf
    local row = {
      date = cell(y, 16, 110),
      resets = cell(y, 130, 50),
      time = cell(y, 190, 80),
      block = cell(y, 280, 120),
      live = cell(y, 410, 60),
    }
    row.del = self:Button(p, 18, 16, "x", function()
      local e = sr.sess[k].entry
      if e then BF.Speedrun:DeleteSession(e) end
    end, "danger")
    row.del:SetPoint("TOPLEFT", p, "TOPLEFT", 450, y + 1)
    sr.sess[i] = row
  end

  -- Runden
  head(-224, "SR_H_LAPS")
  col(-244, 16, 110, "SR_COL_DATE")
  col(-244, 130, 80, "SR_COL_LAP")
  col(-244, 220, 100, "SR_COL_DELTA")
  for i = 1, SR_LAP_ROWS do
    local y = -262 - (i - 1) * 18
    local k = i -- Lua 5.0: Closures teilen sich die Zaehlvariable, darum eine Kopie je Durchlauf
    local row = { date = cell(y, 16, 110), time = cell(y, 130, 80), delta = cell(y, 220, 100) }
    row.del = self:Button(p, 18, 16, "x", function()
      local e = sr.laps[k].entry
      if e then BF.Speedrun:DeleteLap(e) end
    end, "danger")
    row.del:SetPoint("TOPLEFT", p, "TOPLEFT", 330, y + 1)
    sr.laps[i] = row
  end

  -- Posten
  sr.chan = self:Button(p, 104, 22, nil, function()
    BF.Speedrun:CycleChannel()
    UI:RefreshSpeedrun()
  end)
  sr.chan:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -432)
  local b1 = self:Button(p, 104, 22, "SR_POST_LAST", function() BF.Speedrun:Post("last") end, "primary")
  b1:SetPoint("LEFT", sr.chan, "RIGHT", 6, 0)
  local b2 = self:Button(p, 104, 22, "SR_POST_BEST", function() BF.Speedrun:Post("best") end, "primary")
  b2:SetPoint("LEFT", b1, "RIGHT", 6, 0)
  local b3 = self:Button(p, 104, 22, "SR_POST_BLOCK", function() BF.Speedrun:Post("block") end, "primary")
  b3:SetPoint("LEFT", b2, "RIGHT", 6, 0)

  sr.hint = self:Font(p, 10, C.muted)
  sr.hint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 12)
  sr.hint:SetWidth(448)
end

function UI:RefreshSpeedrun()
  local sr = self.sr
  if not sr or self.page ~= "speedrun" then return end
  local SR = BF.Speedrun
  local gray = "|cff9a9cb3"
  local limit = BF.Resets:Limit()

  local n, best, avg, last = SR:LapStats()
  if n > 0 then
    sr.stats:SetText(string.format(T("SR_STATS"), n, BF.Duration(best), BF.Duration(avg), BF.Duration(last)))
  else
    sr.stats:SetText(gray .. T("SR_NOLAPS") .. "|r")
  end
  local b = SR:BestBlock()
  if b then
    sr.stats2:SetText(string.format(T("SR_BESTBLOCK"), limit, BF.Duration(b)))
  else
    sr.stats2:SetText(gray .. string.format(T("SR_NOBLOCK"), limit) .. "|r")
  end

  local rows = SR:SessionRows()
  for i = 1, SR_SESS_ROWS do
    local r, e = sr.sess[i], rows[i]
    if e then
      local rc = "|cffffffff"
      if e.resets >= limit then rc = "|cffffd100" end
      r.date:SetText(e.at and date("%d.%m. %H:%M", e.at) or "-")
      r.resets:SetText(rc .. e.resets .. "|r")
      r.time:SetText(BF.Duration(e.elapsed))
      r.block:SetText(e.out and ("|cffffd100" .. BF.Duration(e.out) .. "|r") or (gray .. "-|r"))
      r.live:SetText(e.live and (gray .. T("SR_LIVE") .. "|r") or "")
      -- die laufende oder letzte Session bleibt, beendete lassen sich loeschen
      r.entry = (not e.cur) and e or nil
      if r.entry then r.del:Show() else r.del:Hide() end
    else
      r.date:SetText("")
      r.resets:SetText("")
      r.time:SetText("")
      r.block:SetText("")
      r.live:SetText("")
      r.entry = nil
      r.del:Hide()
    end
  end

  local laps = BananaFarmDB.speedrun.laps
  local total = getn(laps)
  for i = 1, SR_LAP_ROWS do
    local r, e = sr.laps[i], laps[total - i + 1]
    if e then
      r.date:SetText(date("%d.%m. %H:%M", e.at))
      r.time:SetText(BF.Duration(e.t))
      if e.t <= best then
        r.delta:SetText("|cffffd100" .. T("SR_BEST") .. "|r")
      else
        r.delta:SetText(gray .. "+" .. BF.Duration(e.t - best) .. "|r")
      end
      r.entry = e
      r.del:Show()
    else
      r.date:SetText("")
      r.time:SetText("")
      r.delta:SetText("")
      r.entry = nil
      r.del:Hide()
    end
  end

  sr.chan.fs:SetText(string.format(T("SR_CHANNEL"), T("SR_CH_" .. SR:Channel())))
  sr.hint:SetText(string.format(T("SR_HINT"), limit))
end

function UI:Toggle()
  if self.frame:IsVisible() then self.frame:Hide() else self.frame:Show() end
end

function UI:SetLanguage(lang)
  BananaFarmDB.lang = lang
  for i = 1, getn(self.loc) do
    local e = self.loc[i]
    e.fs:SetText(T(e.key))
  end
  BF:Print(T("MSG_LANGUAGE"))
  self:Refresh()
end

function UI:RefreshSession()
  local S = BF.Session
  local running = S:Running()
  local s = BananaFarmDB.session
  local active = running or (s.elapsed or 0) > 0
  local label = T(running and "BTN_STOP" or "BTN_START")
  local gray = "|cff9a9cb3"

  if self.frame:IsVisible() then
    local text
    if active then
      text = BF.Duration(S:Elapsed()) .. "  " .. BF.Money(S:Value()) .. "  " .. gray .. BF.Money(S:PerHour()) .. "/h|r"
    else
      text = gray .. T("BAR_IDLE") .. "|r"
    end
    self.sessText:SetText(text)
  end

  if self.bar:IsVisible() then
    -- Zeile 1: Gold im Run, in der Session, pro Stunde
    local line1
    if active then
      line1 = gray .. T("BAR_RUN") .. "|r " .. BF.Money(S:RunValue())
        .. "  " .. gray .. T("BAR_SESSION") .. "|r " .. BF.Money(S:Value())
        .. "  " .. gray .. "g/h|r " .. BF.Money(S:PerHour())
    else
      line1 = gray .. T("BAR_IDLE") .. "|r"
    end
    -- Zeile 2: Dauer, Resets der letzten Stunde mit Countdown, Pull-Zaehler
    local parts = {}
    if active then table.insert(parts, BF.Duration(S:Elapsed())) end
    if BF:Enabled("resets") then
      local n, left = BF.Resets:Count(), BF.Resets:Remaining()
      local limit = BF.Resets:Limit()
      local rc = "ffffff"
      if n >= limit then rc = "ff4040" elseif n >= limit - 1 then rc = "ffd100" end
      local rtext = T("BAR_RESETS") .. " |cff" .. rc .. n .. "/" .. limit .. "|r"
      if left then rtext = rtext .. " (" .. BF.Duration(left) .. ")" end
      table.insert(parts, rtext)
    end
    local pulls = BF.Pulls:Text()
    if pulls then table.insert(parts, T("BAR_PULLS") .. " " .. pulls) end
    local line2 = table.concat(parts, "   ")
    self.bar.text:SetText(line1)
    self.bar.text2:SetText(line2)
    self.bar.btn.fs:SetText(label)
    -- unterste Zeile: Rundenstoppuhr
    local b = self.bar
    if BF:Enabled("speedrun") then
      b:SetHeight(67)
      b.sep:Show()
      b.swBtn:Show()
      b.swReset:Show()
      b.text3:Show()
      local SR = BF.Speedrun
      local swRun = SR:Running()
      b.swBtn.fs:SetText(T(swRun and "BTN_STOP" or "BTN_START"))
      local col = swRun and "|cffffd100" or "|cffffffff"
      local line3 = gray .. T("BAR_LAP") .. "|r " .. col .. BF.Duration(SR:Elapsed()) .. "|r"
      local n, best, _, last = SR:LapStats()
      if n > 0 then
        line3 = line3 .. "   " .. gray .. T("BAR_LAST") .. "|r " .. BF.Duration(last)
          .. "   " .. gray .. T("BAR_BEST") .. "|r " .. BF.Duration(best)
      end
      b.text3:SetText(line3)
    else
      b:SetHeight(40)
      b.sep:Hide()
      b.swBtn:Hide()
      b.swReset:Hide()
      b.text3:Hide()
    end
    -- Breite folgt dem Inhalt: waechst sofort, schrumpft erst bei deutlichem Platzgewinn
    -- der Knopf Inst. Reset gehoert nur auf den Twink (hat einen Main als Partner)
    local twink = BF.Sync:Peer() and not BF.Sync:IsMain()
    if twink then b.instBtn:Show() else b.instBtn:Hide() end
    local need = 4 + 48 + 8 + math.max(b.text:GetStringWidth() or 0, b.text2:GetStringWidth() or 0) + 8 + 22 + 4
    if twink then need = need + 72 end
    if BF:Enabled("speedrun") then
      local need3 = 4 + 48 + 4 + 40 + 8 + (b.text3:GetStringWidth() or 0) + 8
      if need3 > need then need = need3 end
    end
    need = math.ceil(need)
    if need < 170 then need = 170 end
    local cur = b:GetWidth() or 0
    if need > cur or need < cur - 24 then b:SetWidth(need) end
  end
end

function UI:Refresh()
  if not self.frame then return end
  if BananaFarmDB.bar and BF:Enabled("tracking") then self.bar:Show() else self.bar:Hide() end
  if BF:Enabled("items") then self.tabLists:Show() else self.tabLists:Hide() end
  if BF:Enabled("speedrun") then self.tabSpeed:Show() else self.tabSpeed:Hide() end
  if BF:Enabled("wish") then self.tabWish:Show() else self.tabWish:Hide() end
  self:RefreshSession()
  if self.frame:IsVisible() then self:ShowPage(self.page) end
end

-- ------------------------------------------------------------
-- Kleine Leiste: Start/Stop, Gold im Run / in der Session / pro Stunde,
-- darunter Dauer, Resets der letzten Stunde und Pull-Zaehler (nur im Kampf),
-- ganz unten die Rundenstoppuhr mit eigenem Start/Stop und Reset (Modul Speedrun)
-- ------------------------------------------------------------
function UI:BuildBar()
  local f = self:Window("BananaFarmBar", 300, 40)
  self.bar = f
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(false)
  if not BananaFarmDB.pos["BananaFarmBar"] then f:SetPoint("TOP", UIParent, "TOP", 0, -120) end
  f.btn = self:Button(f, 48, 22, "BTN_START", function() BF.Session:Toggle() end, "ok")
  f.btn:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -9)
  local open = self:Button(f, 22, 22, "BF", function() UI:Toggle() end, "primary")
  open:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -9)
  -- nur auf dem Twink (Gruppenleiter): Instanzen fuer den Farmchar zuruecksetzen
  f.instBtn = self:Button(f, 68, 22, "BTN_INST_RESET", function() BF.Resets:Do() end, "flat")
  f.instBtn:SetPoint("RIGHT", open, "LEFT", -4, 0)
  f.instBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("BTN_INST_RESET"), 1, 0.82, 0.26)
    GameTooltip:AddLine(T("TT_INST_RESET"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  f.instBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.instBtn:Hide()
  open:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine("BananaFarm", 1, 0.82, 0.26)
    GameTooltip:AddLine(T("TT_BAR"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  open:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Texte nur links verankert: ihre Breite bestimmt die Breite der Leiste (siehe RefreshSession)
  f.text = self:Font(f, 10)
  f.text:SetPoint("TOPLEFT", f.btn, "TOPRIGHT", 8, 3)
  f.text:SetJustifyH("LEFT")
  f.text2 = self:Font(f, 10, C.muted)
  f.text2:SetPoint("BOTTOMLEFT", f.btn, "BOTTOMRIGHT", 8, -3)
  f.text2:SetJustifyH("LEFT")
  -- unterste Zeile: Rundenstoppuhr (Modul Speedrun), unabhaengig von der Session-Uhr
  f.sep = self:HLine(f, -40, 6, -6)
  f.swBtn = self:Button(f, 48, 18, "BTN_START", function() BF.Speedrun:Toggle() end, "primary")
  f.swBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
  f.swReset = self:Button(f, 40, 18, "BTN_SW_RESET", function() BF.Speedrun:Reset() end, "flat")
  f.swReset:SetPoint("LEFT", f.swBtn, "RIGHT", 4, 0)
  f.text3 = self:Font(f, 10)
  f.text3:SetPoint("LEFT", f.swReset, "RIGHT", 8, 0)
  f.text3:SetJustifyH("LEFT")
  f.tick = 0
  f:SetScript("OnUpdate", function()
    this.tick = this.tick + (arg1 or 0)
    if this.tick < 1 then return end
    this.tick = 0
    UI:RefreshSession()
  end)
end

-- ------------------------------------------------------------
-- Zuordnungs-Pop-up fuer unsortierte Items
-- ------------------------------------------------------------
function UI:BuildAssign()
  local f = self:Window("BananaFarmAssign", 320, 128)
  self.assign = f
  if not BananaFarmDB.pos["BananaFarmAssign"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 180) end
  local title = self:Font(f, 12, C.gold)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
  self:Loc(title, "ASSIGN_TITLE")
  f.left = self:Font(f, 9, C.muted)
  f.left:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -14)

  local slot = CreateFrame("Button", nil, f)
  slot:SetWidth(32)
  slot:SetHeight(32)
  slot:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
  f.icon = slot:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(slot)
  slot:SetScript("OnEnter", function()
    if f.id then UI:ItemTooltip(this, f.id) end
  end)
  slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.name = self:Font(f, 12)
  f.name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -2)
  f.name:SetWidth(250)
  f.name:SetHeight(13)
  f.values = self:Font(f, 10, C.muted)
  f.values:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -19)

  local function choose(list, target)
    return function()
      local id = f.id
      f:Hide()
      if id and list then
        if list == "M" and target then BananaFarmDB.mailTarget[id] = target end
        BF.Lists:Set(id, list)
        BF:Print(string.format(T("MSG_ASSIGNED"), BF:ColoredName(id), T("LIST_" .. list)))
      end
      BF.Lists:PopNext()
    end
  end
  local bv = self:Button(f, 70, 24, "LIST_V", choose("V"), "primary")
  bv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
  -- Mail: ab zwei hinterlegten Mailzielen oeffnet sich eine Auswahl, sonst wird gleich zugeordnet
  local bm = self:Button(f, 70, 24, "LIST_M", function()
    if getn(BananaFarmDB.mailTargets) >= 2 then
      UI:ToggleAssignMenu()
    else
      choose("M")()
    end
  end, "ok")
  bm:SetPoint("LEFT", bv, "RIGHT", 5, 0)
  local menu = CreateFrame("Frame", nil, f)
  menu:SetWidth(150)
  menu:SetHeight(60)
  menu:SetPoint("TOPLEFT", bm, "BOTTOMLEFT", 0, -6)
  menu:SetBackdrop(self.BACKDROP)
  menu:SetBackdropColor(0.05, 0.07, 0.14, 0.98)
  menu:SetBackdropBorderColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 0.9)
  menu:Hide()
  local mt = self:Font(menu, 9, C.muted)
  mt:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -7)
  self:Loc(mt, "ASSIGN_MAIL_TO")
  menu.btn = {}
  for i = 1, 8 do
    local k = i -- Lua 5.0: Closures teilen sich die Zaehlvariable, darum eine Kopie je Durchlauf
    local b = self:Button(menu, 134, 20, "?", function()
      local name = menu.btn[k].target
      if name then choose("M", name)() end
    end, "flat")
    b:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -20 - (i - 1) * 22)
    b:Hide()
    menu.btn[i] = b
  end
  f.menu = menu
  local bi = self:Button(f, 78, 24, "LIST_I", choose("I"))
  bi:SetPoint("LEFT", bm, "RIGHT", 5, 0)
  local bl = self:Button(f, 64, 24, "BTN_LATER", choose(nil), "flat")
  bl:SetPoint("LEFT", bi, "RIGHT", 5, 0)
end

-- Auswahl der Mailziele unter dem Pop-up ein- und ausblenden
function UI:ToggleAssignMenu()
  local m = self.assign.menu
  if m:IsVisible() then
    m:Hide()
    return
  end
  local t = BananaFarmDB.mailTargets
  local n = getn(t)
  if n > 8 then n = 8 end
  for i = 1, 8 do
    local b = m.btn[i]
    if i <= n then
      b.target = t[i]
      b.fs:SetText(t[i])
      b:Show()
    else
      b.target = nil
      b:Hide()
    end
  end
  m:SetHeight(26 + n * 22)
  m:Show()
end

function UI:AssignShown()
  return self.assign and self.assign:IsVisible()
end

function UI:ShowAssign(id)
  local f = self.assign
  f.id = id
  f.menu:Hide()
  local name, q, tex = BF:ItemInfo(id)
  local c = BF.QUALITY_COLOR[q or 1] or BF.QUALITY_COLOR[1]
  f.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.name:SetText(name)
  f.name:SetTextColor(c[1], c[2], c[3])
  f.values:SetText(string.format(T("ASSIGN_VALUES"), moneyOrDash(BF:VendorValue(id)), ahText(id)))
  local n = getn(BF.Lists.queue)
  if n > 0 then f.left:SetText(string.format(T("ASSIGN_LEFT"), n)) else f.left:SetText("") end
  f:Show()
end

-- ------------------------------------------------------------
-- Abfragefenster (Ja / Nein)
-- ------------------------------------------------------------
function UI:BuildConfirm()
  local f = self:Window("BananaFarmConfirm", 340, 110)
  self.confirm = f
  if not BananaFarmDB.pos["BananaFarmConfirm"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 120) end
  local title = self:Font(f, 13, C.gold, FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
  title:SetText("BananaFarm")
  f.text = self:Font(f, 11)
  f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -32)
  f.text:SetWidth(312)
  local yes = self:Button(f, 100, 24, "BTN_YES", function()
    local fn = f.onYes
    f:Hide()
    if fn then fn() end
  end, "ok")
  yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 12)
  local no = self:Button(f, 100, 24, "BTN_NO", function() f:Hide() end, "flat")
  no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 12)
end

function UI:Confirm(key, text, onYes)
  local f = self.confirm
  f.key = key
  f.onYes = onYes
  f.text:SetText(text)
  f:Show()
end

function UI:HideConfirm(key)
  local f = self.confirm
  if f and f.key == key then f:Hide() end
end

-- ------------------------------------------------------------
-- Textfenster zum Kopieren (Probe)
-- ------------------------------------------------------------
function UI:ShowText(title, text)
  local f = self.textFrame
  if not f then
    f = self:Window("BananaFarmText", 560, 420)
    self.textFrame = f
    if not BananaFarmDB.pos["BananaFarmText"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    tinsert(UISpecialFrames, "BananaFarmText")
    f.title = self:Font(f, 16, C.gold, FONT_TITLE)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
    local close = self:Button(f, 90, 22, "BTN_CLOSE", function() f:Hide() end, "flat")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10)
    local sf = CreateFrame("ScrollFrame", "BananaFarmTextScroll", f)
    sf:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function()
      local v = this:GetVerticalScroll() - (arg1 or 0) * 40
      local max = this:GetVerticalScrollRange() or 0
      if v > max then v = max end
      if v < 0 then v = 0 end
      this:SetVerticalScroll(v)
    end)
    local e = CreateFrame("EditBox", "BananaFarmTextEdit", sf)
    e:SetWidth(525)
    e:SetHeight(360)
    e:SetMultiLine(true)
    e:SetAutoFocus(false)
    e:SetFontObject("ChatFontNormal")
    e:SetMaxLetters(0)
    e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    sf:SetScrollChild(e)
    f.edit = e
  end
  f.title:SetText(title)
  f.edit:SetText(text)
  f:Show()
  f.edit:SetFocus()
  f.edit:HighlightText()
end

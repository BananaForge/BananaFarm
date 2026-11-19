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
local ROWS = 17
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
      local c = b.bgColor or bg
      fs:SetTextColor(tc[1], tc[2], tc[3])
      b:SetBackdropColor(c[1], c[2], c[3], 0.95)
    end
  end
  return b
end

-- Tooltip an einem Element: Titel und Erklaerung als Locale-Schluessel (Erklaerung optional)
function UI:Tip(frame, titleKey, textKey)
  frame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(T(titleKey), 1, 0.82, 0.26)
    if textKey and BF.L.enUS[textKey] then GameTooltip:AddLine(T(textKey), 0.85, 0.85, 0.85, 1) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Hintergrundfarbe eines Knopfs dauerhaft setzen (Farbe je Liste)
function UI:Tint(b, rgb)
  b.bgColor = rgb
  b:SetBackdropColor(rgb[1], rgb[2], rgb[3], 0.95)
end

-- Farben der Listen: Vendor Bernstein, Mail Gruen, Nie anfassen Rot, Behalten Blau, Unsortiert Grau
UI.LIST_COLOR = {
  V = { 0.48, 0.32, 0.06 },
  M = { 0.10, 0.34, 0.14 },
  I = { 0.40, 0.10, 0.10 },
  K = { 0.10, 0.22, 0.44 },
  U = { 0.18, 0.18, 0.22 },
}

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
  b.fs = fs
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
  if not BananaFarmDB.setupDone then self:ShowSetupStep("lang") end
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
  self.tabSpeed = self:Button(f, 80, 24, "TAB_SPEEDRUN", function() UI:ShowPage("speedrun") end)
  self.tabSpeed:SetPoint("LEFT", self.tabSettings, "RIGHT", 6, 0)
  self.tabWish = self:Button(f, 80, 24, "TAB_WISH", function() UI:ShowPage("wish") end)
  self.tabWish:SetPoint("LEFT", self.tabSpeed, "RIGHT", 6, 0)

  -- Session starten/stoppen auch im Hauptfenster (rechts in der Reiterzeile), nicht nur in der Leiste
  self.sessBtn = self:Button(f, 100, 24, "BTN_SESSION_START", function() BF.Session:Toggle() end, "ok")
  self.sessBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -42)
  self:Tip(self.sessBtn, "BAR_SESSION", "TT_SESSION")

  -- Session-Zeile oben rechts
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
  local widths = { V = 84, M = 84, I = 124, U = 124 }
  for i = 1, getn(BF.LIST_KEYS) do
    local key = BF.LIST_KEYS[i]
    local b = self:Button(p, widths[key] or 86, 22, nil, function()
      UI.sel = key
      UI.offset = 0
      UI:RefreshList()
    end, "flat")
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -6) end
    self:Tip(b, "LIST_" .. key, "LISTDESC_" .. key)
    prev = b
    self.chips[key] = b
  end

  -- Liste Unsortiert: alles mit AH-Preis nach der Standardregel einsortieren (nur per Knopf)
  self.autoBtn = self:Button(p, 150, 18, "BTN_AUTOSORT", function() UI:AutoSort() end, "primary")
  self.autoBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -30)
  self:Tip(self.autoBtn, "BTN_AUTOSORT", "TT_AUTOSORT")
  self.autoBtn:Hide()

  -- Was bedeutet die gewaehlte Liste? (eine Zeile unter den Reitern)
  self.listDesc = self:Font(p, 10, C.text)
  self.listDesc:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -33)
  self.listDesc:SetWidth(448)
  self.listDesc:SetHeight(12)

  local h1 = self:Font(p, 10, C.muted)
  h1:SetPoint("TOPLEFT", p, "TOPLEFT", 40, -50)
  self:Loc(h1, "COL_ITEM")
  local h2 = self:Font(p, 10, C.muted)
  h2:SetPoint("TOPRIGHT", p, "TOPLEFT", 288, -50)
  self:Loc(h2, "COL_VENDOR")
  self.colVendor = h2
  local h3 = self:Font(p, 10, C.muted)
  h3:SetPoint("TOPRIGHT", p, "TOPLEFT", 364, -50)
  self:Loc(h3, "COL_AH")

  self.rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("Button", nil, p)
    r:SetHeight(ROW_H - 2)
    r:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -64 - (i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -64 - (i - 1) * ROW_H)
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
    r.name:SetWidth(176)
    r.name:SetHeight(12)
    r.vendor = self:Font(r, 10)
    r.vendor:SetPoint("RIGHT", r, "LEFT", 274, 0)
    r.vendor:SetJustifyH("RIGHT")
    r.ah = self:Font(r, 10)
    r.ah:SetPoint("RIGHT", r, "LEFT", 350, 0)
    r.ah:SetJustifyH("RIGHT")
    -- Mailliste: Klick auf das Ziel oeffnet die Auswahl der Mailziele, Rechtsklick schaltet zurueck
    r.tgt = CreateFrame("Button", nil, r)
    r.tgt:SetWidth(76)
    r.tgt:SetHeight(18)
    r.tgt:SetPoint("RIGHT", r, "LEFT", 278, 0)
    r.tgt:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.tgt:SetScript("OnClick", function()
      local row = this:GetParent()
      if not row.id then return end
      PlaySound("igMainMenuOptionCheckBoxOn")
      if arg1 == "RightButton" or getn(BananaFarmDB.mailTargets) < 2 then
        BF.Mail:CycleTarget(row.id, arg1 == "RightButton" and -1 or 1)
        UI:RefreshList()
      else
        UI:ShowPicker(this, BananaFarmDB.mailTargets, function(name)
          BananaFarmDB.mailTarget[row.id] = name
          UI:RefreshList()
        end)
      end
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
    local defs = { { "V", "V" }, { "M", "M" }, { "I", "I" }, { "X", nil } }
    for j = 1, 4 do
      local list = defs[j][2]
      local label = defs[j][1]
      local b = self:Button(r, 18, 18, label, function()
        local id = r.id
        if not id then return end
        BF.Lists:Set(id, list)
      end, list and "flat" or "danger")
      if list then self:Tint(b, UI.LIST_COLOR[list]) end
      b:SetPoint("RIGHT", r, "RIGHT", -2 - (4 - j) * 19, 0)
      b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if list then
          GameTooltip:AddLine(string.format(T("TT_MOVE_TO"), T("LIST_" .. list)), 1, 0.82, 0.26)
          GameTooltip:AddLine(T("LISTDESC_" .. list), 0.85, 0.85, 0.85, 1)
        else
          GameTooltip:AddLine(T("TT_REMOVE"), 1, 0.82, 0.26)
          GameTooltip:AddLine(T("TT_REMOVE_DESC"), 0.85, 0.85, 0.85, 1)
        end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r.btn[label] = b
    end
    self.rows[i] = r
  end

  self.empty = self:Font(p, 11, C.muted)
  self.empty:SetPoint("TOP", p, "TOP", 0, -120)
  self:Loc(self.empty, "EMPTY_LIST")

  p:EnableMouseWheel(true)
  p:SetScript("OnMouseWheel", function()
    UI.offset = UI.offset - (arg1 or 0) * 3
    UI:RefreshList()
  end)

  local y = -64 - ROWS * ROW_H - 6
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
  local col = UI.LIST_COLOR[self.sel]
  self.listDesc:SetText(T("LISTDESC_" .. self.sel))
  if self.sel == "U" then
    self.autoBtn:Show()
    self.listDesc:SetWidth(290)
  else
    self.autoBtn:Hide()
    self.listDesc:SetWidth(448)
  end
  if col then self.listDesc:SetTextColor(0.6 + col[1] * 0.8, 0.6 + col[2] * 0.8, 0.6 + col[3] * 0.8) end
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

-- Einstellungen: eine scrollbare Seite, nach Bereichen gegliedert. Jeder Bereich, der zu einem Modul
-- gehoert, hat den Modulschalter als Ueberschrift; ist das Modul aus, werden seine Zeilen blass.
-- (Ersetzt den frueheren Reiter "Module"; das Einrichtungsfenster nutzt weiter UI:ModuleChecks.)
function UI:BuildSettings(p)
  self.edits = {}
  self.checks = {}
  self.sections = {}

  local sf = CreateFrame("ScrollFrame", "BananaFarmSettingsScroll", p)
  sf:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -4)
  sf:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -22, 8)
  local c = CreateFrame("Frame", nil, sf)
  c:SetWidth(452)
  c:SetHeight(100)
  sf:SetScrollChild(c)
  self.setScroll = sf
  self.setContent = c

  -- schmaler Rollbalken rechts
  local bar = CreateFrame("Slider", "BananaFarmSettingsBar", p)
  bar:SetOrientation("VERTICAL")
  bar:SetWidth(16)
  bar:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -6)
  bar:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -8, 10)
  bar:SetBackdrop(self.BACKDROP)
  bar:SetBackdropColor(0.02, 0.03, 0.06, 0.9)
  bar:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 0.6)
  bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  local thumb = bar:GetThumbTexture()
  if thumb then
    thumb:SetWidth(16)
    thumb:SetHeight(24)
  end
  bar:SetMinMaxValues(0, 1)
  bar:SetValueStep(1)
  bar:SetValue(0)
  bar:SetScript("OnValueChanged", function() sf:SetVerticalScroll(this:GetValue()) end)
  self.setBar = bar
  local function wheel()
    local lo, hi = bar:GetMinMaxValues()
    local v = bar:GetValue() - (arg1 or 0) * 44
    if v < lo then v = lo end
    if v > hi then v = hi end
    bar:SetValue(v)
  end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", wheel)
  p:EnableMouseWheel(true)
  p:SetScript("OnMouseWheel", wheel)

  local y = -6
  local sec

  -- Bereich beginnen: Ueberschrift (mit Modulschalter, wenn module gesetzt ist)
  local function section(key, module, tipKey)
    y = y - 6
    sec = { rows = {}, module = module }
    table.insert(self.sections, sec)
    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetVertexColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 0.45)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", c, "TOPLEFT", 10, y)
    line:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, y)
    y = y - 6
    if module then
      local chk = self:Check(c, key, {
        get = function() return BF:Enabled(module) end,
        set = function(v) BF:SetModule(module, v) end,
      }, function() UI:RefreshModules() end)
      chk:SetPoint("TOPLEFT", c, "TOPLEFT", 12, y)
      chk.fs:SetFont(FONT, 12, "")
      chk.fs:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
      self:Tip(chk, key, tipKey)
      table.insert(self.checks, chk)
    else
      local fs = self:Font(c, 12, C.gold)
      fs:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y - 2)
      self:Loc(fs, key)
    end
    y = y - 24
  end

  local function own(frame)
    table.insert(sec.rows, frame)
  end

  local function editRow(key, name, w, getter, setter, maxLetters)
    local e = self:EditBox(name, c, w, getter, setter, maxLetters)
    e:SetPoint("TOPLEFT", c, "TOPLEFT", 40, y)
    local fs = self:Font(c, 11)
    fs:SetPoint("LEFT", e, "RIGHT", 10, 0)
    self:Loc(fs, key)
    -- Erklaerung beim Ueberfahren des Feldes
    e:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(T(key), 1, 0.82, 0.26)
      if BF.L.enUS[key .. "_TT"] then GameTooltip:AddLine(T(key .. "_TT"), 0.85, 0.85, 0.85, 1) end
      GameTooltip:Show()
    end)
    e:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(self.edits, e)
    own(e)
    own(fs)
    y = y - 26
  end

  local function checkRow(key, field, onChange)
    local chk = self:Check(c, key, field, onChange)
    chk:SetPoint("TOPLEFT", c, "TOPLEFT", 36, y)
    if BF.L.enUS[key .. "_TT"] then self:Tip(chk, key, key .. "_TT") end
    table.insert(self.checks, chk)
    own(chk)
    y = y - 22
  end

  local function infoRow(key)
    local fs = self:Font(c, 10, C.muted)
    fs:SetPoint("TOPLEFT", c, "TOPLEFT", 38, y - 2)
    fs:SetWidth(400)
    self:Loc(fs, key)
    own(fs)
    y = y - 18
  end

  local function buttonRow(defs)
    local x = 38
    for i = 1, getn(defs) do
      local d = defs[i]
      local b = self:Button(c, d[2], 22, d[1], d[3], d[4])
      b:SetPoint("TOPLEFT", c, "TOPLEFT", x, y)
      if d[5] then self:Tip(b, d[1], d[5]) end
      own(b)
      x = x + d[2] + 6
    end
    y = y - 28
  end

  -- Allgemein
  section("SEC_GENERAL")
  local lang = self:Font(c, 11)
  lang:SetPoint("TOPLEFT", c, "TOPLEFT", 40, y - 4)
  self:Loc(lang, "SET_LANG")
  self.langBtns = {}
  local ldefs = { { "de", "Deutsch" }, { "en", "English" }, { "auto", "Auto" } }
  for i = 1, 3 do
    local code = ldefs[i][1]
    local b = self:Button(c, 76, 22, ldefs[i][2], function() UI:SetLanguage(code) end, "flat")
    b:SetPoint("TOPLEFT", c, "TOPLEFT", 130 + (i - 1) * 80, y)
    self.langBtns[code] = b
  end
  y = y - 28
  buttonRow({
    { "BTN_HOWTO", 110, function() UI:ShowSetupStep("howto") end, "flat", "TT_HOWTO" },
    { "BTN_SETUP", 110, function() UI:ShowSetup() end, "flat", "TT_SETUP" },
    { "BTN_PROBE", 110, function() BF:Probe() end, "flat", "TT_PROBE" },
  })
  buttonRow({ { "BTN_SUPPORT", 140, function() UI:ShowDonate() end, "primary", "TT_SUPPORT" } })

  -- Session und Leiste
  section("SEC_TRACKING", "tracking", "MOD_TRACKING")
  checkRow("CHK_BAR", "bar", function() UI:Refresh() end)
  checkRow("CHK_OFFLINE", "offlineTime")
  checkRow("CHK_REPAIR", "repairCost")
  editRow("SET_BAGWARN", "BananaFarmEditBagWarn", 50,
    function() return tostring(BananaFarmDB.bagWarn) end,
    function(v)
      local n = num(v)
      if n and n >= 0 then BananaFarmDB.bagWarn = floor(n) end
    end)

  -- Listen und Sortierung
  section("SEC_ITEMS", "items", "MOD_ITEMS")
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
  checkRow("CHK_AHCUT", "ahCut", resort)
  checkRow("CHK_GRAY", "grayVendor", resort)
  checkRow("CHK_POPUP", "popup", function() BF.Lists:PopNext() end)
  checkRow("CHK_ALTCLICK", "altClick")

  -- Haendler
  section("SEC_VENDOR", "vendor", "MOD_VENDOR")
  checkRow("CHK_AUTOSELL", "autoSell")
  checkRow("CHK_PROTECT", "protect")
  buttonRow({ { "BTN_PRICES", 150, function() BF.Vendor:Command("") end, "flat", "TT_PRICES" } })

  -- Post
  section("SEC_MAIL", "mail", "MOD_MAIL")
  editRow("SET_MAILTARGETS", "BananaFarmEditMailTargets", 220,
    function() return table.concat(BananaFarmDB.mailTargets, ", ") end,
    function(v) BF.Mail:SetTargets(v) end, 120)
  checkRow("CHK_MAILASK", "mailAsk")

  -- Twink und Sync
  section("SEC_SYNC", "sync", "MOD_SYNC")
  editRow("SET_ALT", "BananaFarmEditAlt", 110,
    function() return BananaFarmDB.bankAlt end,
    function(v) BF:SetBankAlt(v) end)
  checkRow("CHK_SYNC", "autoSync")

  -- Resets
  section("SEC_RESETS", "resets", "MOD_RESETS")
  editRow("SET_RESETLIMIT", "BananaFarmEditResetLimit", 50,
    function() return tostring(BananaFarmDB.resetLimit) end,
    function(v)
      local n = num(v)
      if n and n >= 1 then BananaFarmDB.resetLimit = floor(n) end
    end)

  -- Pull-Zaehler
  section("SEC_PULLS", "pulls", "MOD_PULLS")
  checkRow("CHK_HUNTER", { get = function() return BF:HunterMode() end, set = function(v) BF:SetHunterMode(v) end },
    function() UI:Refresh() end)
  editRow("SET_PULLLIMIT", "BananaFarmEditPullLimit", 50,
    function() return tostring(BananaFarmDB.pullLimit) end,
    function(v)
      local n = num(v)
      if n and n >= 1 then BananaFarmDB.pullLimit = floor(n) end
    end)
  infoRow("INFO_PULLS")

  -- Speedrun und Wunschliste: nur an/aus, alles Weitere im eigenen Reiter
  section("SEC_SPEEDRUN", "speedrun", "MOD_SPEEDRUN")
  checkRow("CHK_SRAUTO", "srAutoStart")
  infoRow("INFO_SPEEDRUN")
  section("SEC_CHAMP", "champ", "MOD_CHAMP")
  checkRow("CHK_CHAMPGOLD", "champGold", function() BF.Champ:Send() end)
  infoRow("INFO_CHAMP")
  section("SEC_WISH", "wish", "MOD_WISH")
  infoRow("INFO_WISH")

  c:SetHeight(-y + 10)
  self.setHeight = -y + 10
end

function UI:RefreshSettings()
  for i = 1, getn(self.edits) do self.edits[i].Update() end
  for i = 1, getn(self.checks) do self.checks[i].Update() end
  for code, b in pairs(self.langBtns) do b:SetActive(BananaFarmDB.lang == code) end
  -- Bereiche ausgeschalteter Module blass zeigen (bleiben bedienbar)
  for i = 1, getn(self.sections) do
    local s = self.sections[i]
    local a = 1
    if s.module and not BF:Enabled(s.module) then a = 0.4 end
    for j = 1, getn(s.rows) do s.rows[j]:SetAlpha(a) end
  end
  -- Rollbereich an die Hoehe anpassen
  local h = self.setScroll:GetHeight() or 0
  local range = (self.setHeight or 0) - h
  if range < 0 then range = 0 end
  self.setBar:SetMinMaxValues(0, range)
  if range == 0 then self.setBar:Hide() else self.setBar:Show() end
  if self.setBar:GetValue() > range then self.setBar:SetValue(range) end
end

-- ------------------------------------------------------------
-- Module: Schalter fuer das Einrichtungsfenster beim ersten Start
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

-- Knopf "Automatisch einsortieren": danach fuer jedes neue Mail-Item das Mailziel abfragen
-- (nur bei mindestens zwei Mailzielen und nur, wenn das Item noch keins hat)
function UI:AutoSort()
  local nM, nV, left, mail = BF.Lists:AutoSort()
  BF:Print(string.format(T("MSG_AUTOSORT"), nM + nV, nM, nV, left))
  if getn(BananaFarmDB.mailTargets) >= 2 then
    for i = 1, getn(mail) do
      if not BF.Mail:IsTarget(BananaFarmDB.mailTarget[mail[i]]) then self:AskTarget(mail[i]) end
    end
  end
  self:Refresh()
end

-- Fenster "An welchen Mailchar?" mit Warteschlange
function UI:AskTarget(id)
  self.tq = self.tq or {}
  table.insert(self.tq, id)
  if not (self.tAsk and self.tAsk:IsVisible()) then self:NextTarget() end
end

function UI:NextTarget()
  local id = self.tq and table.remove(self.tq, 1)
  if not id then
    if self.tAsk then self.tAsk:Hide() end
    return
  end
  local f = self.tAsk
  if not f then
    f = self:Window("BananaFarmTargetAsk", 320, 110)
    self.tAsk = f
    if not BananaFarmDB.pos["BananaFarmTargetAsk"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 160) end
    local title = self:Font(f, 12, C.gold)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    self:Loc(title, "ASK_TARGET_TITLE")
    f.left = self:Font(f, 9, C.muted)
    f.left:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -14)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetWidth(24)
    f.icon:SetHeight(24)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -32)
    f.name = self:Font(f, 12)
    f.name:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.name:SetWidth(260)
    f.btn = {}
    for i = 1, 8 do
      local k = i -- Lua 5.0: Kopie der Zaehlvariable je Durchlauf (Closures)
      local b = self:Button(f, 140, 22, "?", function()
        local name = f.btn[k].value
        if name and f.id then BananaFarmDB.mailTarget[f.id] = name end
        UI:NextTarget()
      end, "ok")
      local col = BF.mod(i - 1, 2)
      local row = floor((i - 1) / 2)
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + col * 148, -64 - row * 26)
      f.btn[i] = b
    end
  end
  f.id = id
  local name, q, tex = BF:ItemInfo(id)
  local c = BF.QUALITY_COLOR[q or 1] or BF.QUALITY_COLOR[1]
  f.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.name:SetText(name)
  f.name:SetTextColor(c[1], c[2], c[3])
  local t = BananaFarmDB.mailTargets
  local n = getn(t)
  if n > 8 then n = 8 end
  for i = 1, 8 do
    local b = f.btn[i]
    if i <= n then
      b.value = t[i]
      b.fs:SetText(t[i])
      b:Show()
    else
      b.value = nil
      b:Hide()
    end
  end
  f:SetHeight(72 + floor((n + 1) / 2) * 26)
  local rest = getn(self.tq)
  if rest > 0 then f.left:SetText(string.format(T("ASSIGN_LEFT"), rest)) else f.left:SetText("") end
  f:Show()
end

-- Kleines Auswahlmenue unter einem Element (z. B. Mailziele). onPick(name) beim Klick.
function UI:ShowPicker(anchor, names, onPick)
  local m = self.picker
  if not m then
    m = CreateFrame("Frame", "BananaFarmPicker", UIParent)
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetWidth(150)
    m:SetBackdrop(self.BACKDROP)
    m:SetBackdropColor(0.05, 0.07, 0.14, 0.98)
    m:SetBackdropBorderColor(C.goldDim[1], C.goldDim[2], C.goldDim[3], 0.9)
    m:EnableMouse(true)
    m.btn = {}
    for i = 1, 8 do
      local k = i -- Lua 5.0: Kopie der Zaehlvariable je Durchlauf (Closures)
      local b = self:Button(m, 134, 20, "?", function()
        local name = m.btn[k].value
        m:Hide()
        if name and m.onPick then m.onPick(name) end
      end, "flat")
      b:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -8 - (i - 1) * 22)
      m.btn[i] = b
    end
    tinsert(UISpecialFrames, "BananaFarmPicker")
    self.picker = m
  end
  if m:IsVisible() and m.anchor == anchor then
    m:Hide()
    return
  end
  local n = getn(names)
  if n > 8 then n = 8 end
  for i = 1, 8 do
    local b = m.btn[i]
    if i <= n then
      b.value = names[i]
      b.fs:SetText(names[i])
      b:Show()
    else
      b.value = nil
      b:Hide()
    end
  end
  m.anchor = anchor
  m.onPick = onPick
  m:SetHeight(14 + n * 22)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  m:Show()
end

function UI:BuildSetup()
  local f = self:Window("BananaFarmSetup", 440, 512)
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
  f.nextBtn = nextBtn
  f.skip = skip
  -- Schritt Sprache (beim ersten Start vor den Modulen)
  f.lang = {}
  local ldefs = { { "de", "Deutsch" }, { "en", "English" }, { "auto", "LANG_AUTO" } }
  for i = 1, 3 do
    local code = ldefs[i][1]
    local b = self:Button(f, 112, 26, ldefs[i][2], function()
      UI:SetLanguage(code)
      f.active = false
      f:Hide()
      UI:ShowSetup()
    end, i == 3 and "flat" or "primary")
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16 + (i - 1) * 124, 16)
    b:Hide()
    f.lang[i] = b
  end
  -- Escape zaehlt als Ueberspringen
  tinsert(UISpecialFrames, "BananaFarmSetupStep")
  f:SetScript("OnHide", function() UI:SetupStepDone(false) end)
end

function UI:ShowSetupStep(kind)
  if kind == "twink" and not BF:Enabled("sync") then kind = "mail" end
  if kind == "mail" and not BF:Enabled("mail") then kind = "howto" end
  local f = self.step
  f.kind = kind
  f.active = true
  for i = 1, 3 do f.lang[i]:Hide() end
  -- erster Schritt: Sprache waehlen (drei Knoepfe, kein Eingabefeld)
  if kind == "lang" then
    f.title:SetText("BananaFarm: Sprache / Language")
    f.text:SetText(T("SETUP_LANG_TEXT"))
    f:SetHeight(150)
    f.edit:Hide()
    f.skip:Hide()
    f.nextBtn:Hide()
    for i = 1, 3 do f.lang[i]:Show() end
    f:Show()
    return
  end
  f.nextBtn:Show()
  -- letzter Schritt: kurze Anleitung ohne Eingabefeld
  if kind == "howto" then
    f.title:SetText(T("SETUP_HOWTO_TITLE"))
    f.text:SetText(T("SETUP_HOWTO_TEXT"))
    f:SetHeight(250)
    f.edit:Hide()
    f.skip:Hide()
    f.nextBtn.fs:SetText(T("BTN_GO"))
    f:Show()
    return
  end
  f:SetHeight(200)
  f.edit:Show()
  f.skip:Show()
  f.nextBtn.fs:SetText(T("BTN_NEXT"))
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
  if f.kind == "howto" then return end
  -- Sprache per Escape uebersprungen: automatisch (Spielsprache), weiter mit den Modulen
  if f.kind == "lang" then
    f:Hide()
    self:ShowSetup()
    return
  end
  if save and v ~= "" then
    if f.kind == "twink" then BF:SetBankAlt(v) else BF.Mail:SetTargets(v) end
  end
  if f.kind == "twink" then
    self:ShowSetupStep("mail")
  else
    self:ShowSetupStep("howto")
  end
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
  if page == "modules" then page = "settings" end
  self.page = page
  if page == "lists" then self.pageLists:Show() else self.pageLists:Hide() end
  if page == "settings" then self.pageSettings:Show() else self.pageSettings:Hide() end
  if page == "speedrun" then self.pageSpeedrun:Show() else self.pageSpeedrun:Hide() end
  if page == "wish" then self.pageWish:Show() else self.pageWish:Hide() end
  if page ~= "wish" and BF.Wish then BF.Wish:Capture(false) end
  self.tabLists:SetActive(page == "lists")
  self.tabSettings:SetActive(page == "settings")
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
-- Speedrun-Dashboard (0.5.0): Unter-Reiter "Meine Zeiten" und "Lasher Championships"
-- ------------------------------------------------------------
local SR_ROWS = 8
local CH_ROWS = 10

-- Kachel: kleine Ueberschrift, grosser Wert
function UI:Tile(parent, w, h, key)
  local t = CreateFrame("Frame", nil, parent)
  t:SetWidth(w)
  t:SetHeight(h)
  t:SetBackdrop(self.BACKDROP)
  t:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.95)
  t:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 0.9)
  t.label = self:Font(t, 9, C.muted)
  t.label:SetPoint("TOPLEFT", t, "TOPLEFT", 7, -6)
  if key then self:Loc(t.label, key) end
  t.value = self:Font(t, 14, C.gold)
  t.value:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 7, 6)
  t.sub = self:Font(t, 9, C.muted)
  t.sub:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -6, 7)
  t.sub:SetJustifyH("RIGHT")
  return t
end

local function deltaText(t, best)
  if not best or not t then return "" end
  local d = t - best
  if d == 0 then return "|cffffd100" .. T("SR_BEST_SHORT") .. "|r" end
  if d < 0 then return "|cff40ff40-" .. BF.Duration(-d) .. "|r" end
  return "|cffff6050+" .. BF.Duration(d) .. "|r"
end

local function goldText(v)
  if not v then return "|cff808590-|r" end
  return BF.Money(v)
end

function UI:BuildSpeedrun(p)
  local sr = { rows = {}, boxes = {}, tiles = {}, crows = {} }
  self.sr = sr
  sr.view = "mine"
  sr.cat = "week"
  sr.sort = "best"

  sr.tabMine = self:Button(p, 120, 22, "SR_TAB_MINE", function() sr.view = "mine"; UI:RefreshSpeedrun() end, "flat")
  sr.tabMine:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -6)
  sr.tabGuild = self:Button(p, 170, 22, "SR_TAB_GUILD", function() sr.view = "guild"; UI:RefreshSpeedrun() end, "flat")
  sr.tabGuild:SetPoint("LEFT", sr.tabMine, "RIGHT", 4, 0)

  -- ---------------- Meine Zeiten ----------------
  local m = CreateFrame("Frame", nil, p)
  m:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  m:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  sr.mine = m

  local keys = { "SR_T_BESTHEAT", "SR_T_AVGHEAT", "SR_T_BESTLAP", "SR_T_WEEK" }
  for i = 1, 4 do
    local t = self:Tile(m, 108, 46, keys[i])
    t:SetPoint("TOPLEFT", m, "TOPLEFT", 14 + (i - 1) * 113, -36)
    sr.tiles[i] = t
  end

  local h1 = self:Font(m, 12, C.gold)
  h1:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -92)
  sr.curTitle = h1
  -- laufenden (unvollstaendigen) Durchgang wegwerfen
  sr.discard = self:Button(m, 110, 18, "BTN_DISCARD", function()
    UI:Confirm("discard", T("ASK_DISCARD"), function() BF.Speedrun:DiscardHeat() end)
  end, "danger")
  sr.discard:SetPoint("TOPRIGHT", m, "TOPRIGHT", -14, -88)
  for i = 1, 5 do
    local bx = self:Tile(m, 84, 42, nil)
    bx:SetPoint("TOPLEFT", m, "TOPLEFT", 14 + (i - 1) * 89, -108)
    bx.label:SetText(string.format(T("SR_LAPN"), i))
    sr.boxes[i] = bx
  end

  local h2 = self:Font(m, 12, C.gold)
  h2:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -162)
  self:Loc(h2, "SR_RECENT")
  local cols = { { "SR_C_DATE", 34 }, { "SR_C_TOTAL", 140 }, { "SR_C_PLAY", 210 }, { "SR_C_VSBEST", 280 }, { "SR_C_GOLD", 350 } }
  for i = 1, getn(cols) do
    local fs = self:Font(m, 10, C.muted)
    fs:SetPoint("TOPLEFT", m, "TOPLEFT", cols[i][2], -180)
    self:Loc(fs, cols[i][1])
  end
  for i = 1, SR_ROWS do
    local r = CreateFrame("Button", nil, m)
    r:SetHeight(19)
    r:SetPoint("TOPLEFT", m, "TOPLEFT", 14, -194 - (i - 1) * 20)
    r:SetPoint("TOPRIGHT", m, "TOPRIGHT", -14, -194 - (i - 1) * 20)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetAllPoints(r)
    if BF.mod(i, 2) == 0 then bg:SetVertexColor(1, 1, 1, 0.03) else bg:SetVertexColor(1, 1, 1, 0.07) end
    r.sel = r:CreateTexture(nil, "BORDER")
    r.sel:SetTexture(WHITE)
    r.sel:SetAllPoints(r)
    r.sel:SetVertexColor(1, 0.82, 0.26, 0.15)
    r.sel:Hide()
    r.cells = {}
    for j = 1, getn(cols) do
      local fs = self:Font(r, 10)
      fs:SetPoint("LEFT", r, "LEFT", cols[j][2] - 14, 0)
      r.cells[j] = fs
    end
    r.del = self:Button(r, 16, 16, "X", function()
      if r.e then BF.Speedrun:DeleteHeat(r.e) end
    end, "danger")
    r.del:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r:SetScript("OnClick", function()
      sr.selHeat = (sr.selHeat ~= this.e) and this.e or nil
      UI:RefreshSpeedrun()
    end)
    sr.rows[i] = r
  end
  sr.detail = self:Font(m, 10, C.text)
  sr.detail:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -358)
  sr.detail:SetWidth(448)
  sr.empty = self:Font(m, 11, C.muted)
  sr.empty:SetPoint("TOPLEFT", m, "TOPLEFT", 30, -220)
  sr.empty:SetWidth(420)
  sr.empty:SetJustifyH("LEFT")
  self:Loc(sr.empty, "SR_EMPTY")

  sr.chan = self:Button(m, 100, 22, nil, function()
    BF.Speedrun:CycleChannel()
    UI:RefreshSpeedrun()
  end, "flat")
  sr.chan:SetPoint("TOPLEFT", m, "TOPLEFT", 14, -384)
  local pl = self:Button(m, 110, 22, "SR_POST_LAST", function() BF.Speedrun:Post("last") end)
  pl:SetPoint("LEFT", sr.chan, "RIGHT", 6, 0)
  local pb = self:Button(m, 110, 22, "SR_POST_BEST", function() BF.Speedrun:Post("best") end)
  pb:SetPoint("LEFT", pl, "RIGHT", 6, 0)
  local ph = self:Button(m, 110, 22, "SR_POST_HEAT", function() BF.Speedrun:Post("heat") end)
  ph:SetPoint("LEFT", pb, "RIGHT", 6, 0)

  sr.auto = self:Check(m, "CHK_SRAUTO", "srAutoStart")
  sr.auto:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -416)
  self:Tip(sr.auto, "CHK_SRAUTO", "CHK_SRAUTO_TT")
  sr.hint = self:Font(m, 10, C.muted)
  sr.hint:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -442)
  sr.hint:SetWidth(448)
  sr.hint:SetJustifyH("LEFT")

  -- ---------------- Lasher Championships ----------------
  local gp = CreateFrame("Frame", nil, p)
  gp:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  gp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  sr.guild = gp
  local icon = gp:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(BF.CHAMP_ICON)
  icon:SetWidth(40)
  icon:SetHeight(40)
  icon:SetPoint("TOPLEFT", gp, "TOPLEFT", 14, -32)
  sr.cTitle = self:Font(gp, 17, C.gold, FONT_TITLE)
  sr.cTitle:SetPoint("TOPLEFT", gp, "TOPLEFT", 60, -40)
  sr.cInfo = self:Font(gp, 10, C.muted)
  sr.cInfo:SetPoint("TOPLEFT", gp, "TOPLEFT", 60, -60)

  sr.cats = {}
  local cdefs = { { "fast", "SR_CAT_FAST", 150 }, { "week", "SR_CAT_WEEK", 80 }, { "month", "SR_CAT_MONTH", 80 }, { "all", "SR_CAT_ALL", 80 } }
  local prev
  for i = 1, getn(cdefs) do
    local key = cdefs[i][1]
    local b = self:Button(gp, cdefs[i][3], 22, cdefs[i][2], function() sr.cat = key; UI:RefreshSpeedrun() end, "flat")
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", gp, "TOPLEFT", 14, -80) end
    prev = b
    sr.cats[key] = b
  end
  sr.sortLabel = self:Font(gp, 10, C.muted)
  sr.sortLabel:SetPoint("TOPLEFT", gp, "TOPLEFT", 16, -112)
  self:Loc(sr.sortLabel, "SR_SORT")
  sr.sorts = {}
  local sdefs = { { "n", "SR_S_N", 90 }, { "best", "SR_S_BEST", 80 }, { "gold", "SR_S_GOLD", 60 } }
  prev = nil
  for i = 1, getn(sdefs) do
    local key = sdefs[i][1]
    local b = self:Button(gp, sdefs[i][3], 18, sdefs[i][2], function() sr.sort = key; UI:RefreshSpeedrun() end, "flat")
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", sr.sortLabel, "RIGHT", 8, 0) end
    prev = b
    sr.sorts[key] = b
  end

  local ccols = { { "SR_C_RANK", 18 }, { "SR_C_NAME", 50 }, { "SR_C_HEATS", 200 }, { "SR_C_BEST", 290 }, { "SR_C_GOLD", 370 } }
  for i = 1, getn(ccols) do
    local fs = self:Font(gp, 10, C.muted)
    fs:SetPoint("TOPLEFT", gp, "TOPLEFT", ccols[i][2], -140)
    self:Loc(fs, ccols[i][1])
  end
  for i = 1, CH_ROWS do
    local r = CreateFrame("Frame", nil, gp)
    r:SetHeight(20)
    r:SetPoint("TOPLEFT", gp, "TOPLEFT", 14, -154 - (i - 1) * 22)
    r:SetPoint("TOPRIGHT", gp, "TOPRIGHT", -14, -154 - (i - 1) * 22)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetAllPoints(r)
    if i <= 3 then bg:SetVertexColor(1, 0.82, 0.26, 0.10) elseif BF.mod(i, 2) == 0 then bg:SetVertexColor(1, 1, 1, 0.03) else bg:SetVertexColor(1, 1, 1, 0.07) end
    r.cells = {}
    for j = 1, getn(ccols) do
      local fs = self:Font(r, 11)
      fs:SetPoint("LEFT", r, "LEFT", ccols[j][2] - 14, 0)
      r.cells[j] = fs
    end
    sr.crows[i] = r
  end
  sr.cEmpty = self:Font(gp, 11, C.muted)
  sr.cEmpty:SetPoint("TOPLEFT", gp, "TOPLEFT", 30, -180)
  sr.cEmpty:SetWidth(420)
  sr.cEmpty:SetJustifyH("LEFT")

  local win = self:Button(gp, 150, 22, "SR_SHOW_WINNERS", function()
    local top = BF.Champ:Ranking("week", "best")
    if getn(top) == 0 then BF:Print(T("MSG_CHAMP_NONE")) else UI:ShowWinners(top) end
  end, "primary")
  win:SetPoint("TOPLEFT", gp, "TOPLEFT", 14, -384)
  local share = self:Check(gp, "CHK_CHAMPGOLD", "champGold", function() BF.Champ:Send() end)
  share:SetPoint("TOPLEFT", gp, "TOPLEFT", 16, -416)
  self:Tip(share, "CHK_CHAMPGOLD", "CHK_CHAMPGOLD_TT")
  sr.share = share
  sr.cOff = self:Font(gp, 11, C.text)
  sr.cOff:SetPoint("TOPLEFT", gp, "TOPLEFT", 30, -200)
  sr.cOff:SetWidth(420)
  sr.cOff:SetJustifyH("LEFT")
  self:Loc(sr.cOff, "SR_CHAMP_OFF")
  sr.cNote = self:Font(gp, 9, C.muted)
  sr.cNote:SetPoint("TOPLEFT", gp, "TOPLEFT", 16, -442)
  sr.cNote:SetWidth(448)
  sr.cNote:SetJustifyH("LEFT")
  self:Loc(sr.cNote, "SR_CHAMP_NOTE")
end

function UI:RefreshSpeedrun()
  local sr = self.sr
  if not sr or not self.frame:IsVisible() or self.page ~= "speedrun" then return end
  local SR = BF.Speedrun
  local d = BananaFarmDB.speedrun
  local limit = BF.Resets:Limit()
  sr.tabMine:SetActive(sr.view == "mine")
  sr.tabGuild:SetActive(sr.view == "guild")
  if sr.view == "mine" then
    sr.mine:Show()
    sr.guild:Hide()
  else
    sr.mine:Hide()
    sr.guild:Show()
  end

  -- Kacheln
  local best = SR:BestHeat()
  local n, bestLap = SR:LapStats()
  local wn = SR:PeriodStats(SR.WeekStart())
  local avg = SR:HeatAvg()
  sr.tiles[1].value:SetText(best and BF.Duration(best.total) or "-")
  sr.tiles[1].sub:SetText(best and date("%d.%m.", best.at) or "")
  sr.tiles[2].value:SetText(avg and BF.Duration(avg) or "-")
  sr.tiles[2].sub:SetText(string.format(T("SR_N_HEATS"), getn(d.heats or {})))
  sr.tiles[3].value:SetText(bestLap and BF.Duration(bestLap) or "-")
  sr.tiles[3].sub:SetText(n > 0 and string.format(T("SR_N_LAPS"), n) or "")
  sr.tiles[4].value:SetText(tostring(wn))
  sr.tiles[4].sub:SetText(T("SR_HEATS_SHORT"))

  -- laufender Durchgang: fertige Runden, die laufende Runde in Gold
  local heat = d.heat or { laps = {} }
  local hl = heat.laps or {}
  sr.curTitle:SetText(string.format(T("SR_CURRENT"), getn(hl), limit))
  if getn(hl) > 0 or SR:Running() then sr.discard:Show() else sr.discard:Hide() end
  for i = 1, 5 do
    local bx = sr.boxes[i]
    if i > limit then
      bx:Hide()
    else
      bx:Show()
      local lap = hl[i]
      if lap then
        bx.value:SetText(BF.Duration(lap.t))
        bx.value:SetTextColor(1, 1, 1)
        bx.sub:SetText(deltaText(lap.t, bestLap))
      elseif i == getn(hl) + 1 and (SR:Running() or SR:Elapsed() > 0) then
        bx.value:SetText(BF.Duration(SR:Elapsed()))
        bx.value:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        bx.sub:SetText(SR:Running() and T("SR_RUNNING") or "")
      else
        bx.value:SetText("-")
        bx.value:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        bx.sub:SetText("")
      end
    end
  end

  -- letzte Durchgaenge, neueste zuerst
  local hs = d.heats or {}
  local count = getn(hs)
  for i = 1, SR_ROWS do
    local r = sr.rows[i]
    local e = hs[count - i + 1]
    r.e = e
    if e then
      r.cells[1]:SetText(date("%d.%m. %H:%M", e.at))
      r.cells[2]:SetText(BF.Duration(e.total))
      r.cells[3]:SetText(BF.Duration(e.play))
      r.cells[4]:SetText(deltaText(e.total, best and best.total))
      r.cells[5]:SetText(goldText(e.gold))
      if sr.selHeat == e then r.sel:Show() else r.sel:Hide() end
      r:Show()
    else
      r:Hide()
    end
  end
  if count == 0 then sr.empty:Show() else sr.empty:Hide() end
  local sel = sr.selHeat
  if sel then
    local parts = {}
    for i = 1, getn(sel.laps) do table.insert(parts, i .. ") " .. BF.Duration(sel.laps[i])) end
    sr.detail:SetText(T("SR_LAPS_OF") .. "  " .. table.concat(parts, "   "))
  elseif count > 0 then
    sr.detail:SetText("|cff808590" .. T("SR_CLICK_HEAT") .. "|r")
  else
    sr.detail:SetText("")
  end
  sr.chan.fs:SetText(string.format(T("SR_CHANNEL"), T("SR_CH_" .. SR:Channel())))
  sr.auto.Update()
  sr.hint:SetText(string.format(T("SR_HINT2"), limit))

  -- Lasher Championships
  sr.cTitle:SetText(string.format(T("CHAMP_TITLE"), date("%Y")))
  local on = BF:Enabled("champ")
  sr.share.Update()
  for key, b in pairs(sr.cats) do b:SetActive(key == sr.cat) end
  for key, b in pairs(sr.sorts) do b:SetActive(key == sr.sort) end
  if sr.cat == "fast" then
    sr.sortLabel:Hide()
    for _, b in pairs(sr.sorts) do b:Hide() end
  else
    sr.sortLabel:Show()
    for _, b in pairs(sr.sorts) do b:Show() end
  end
  local rows = on and BF.Champ:Ranking(sr.cat, sr.sort) or {}
  if on then
    sr.cOff:Hide()
    sr.cInfo:SetText(string.format(T("CHAMP_INFO"), BF.Champ:PlayerCount()))
  else
    sr.cOff:Show()
    sr.cInfo:SetText("")
  end
  for i = 1, CH_ROWS do
    local r = sr.crows[i]
    local e = rows[i]
    if e then
      r.cells[1]:SetText(i .. ".")
      r.cells[2]:SetText(e.name == UnitName("player") and ("|cffffd100" .. e.name .. "|r") or e.name)
      r.cells[3]:SetText(tostring(e.n))
      r.cells[4]:SetText(e.best and BF.Duration(e.best) or "-")
      r.cells[5]:SetText(goldText(e.gold))
      r:Show()
    else
      r:Hide()
    end
  end
  if on and getn(rows) == 0 then
    sr.cEmpty:SetText(T("SR_CHAMP_EMPTY"))
    sr.cEmpty:Show()
  else
    sr.cEmpty:Hide()
  end
end

-- Pop-up Wochensieger (sonntags), top = Ranking("week", "best")
function UI:ShowWinners(top)
  local f = self.winners
  if not f then
    f = self:Window("BananaFarmWinners", 340, 360)
    self.winners = f
    if not BananaFarmDB.pos["BananaFarmWinners"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 60) end
    tinsert(UISpecialFrames, "BananaFarmWinners")
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(BF.CHAMP_ICON)
    icon:SetWidth(140)
    icon:SetHeight(140)
    icon:SetPoint("TOP", f, "TOP", 0, -12)
    f.title = self:Font(f, 18, C.gold, FONT_TITLE)
    f.title:SetPoint("TOP", icon, "BOTTOM", 0, -6)
    f.title:SetJustifyH("CENTER")
    f.sub = self:Font(f, 11, C.muted)
    f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
    f.sub:SetJustifyH("CENTER")
    f.lines = {}
    for i = 1, 3 do
      local fs = self:Font(f, i == 1 and 15 or 12, i == 1 and C.gold or C.text)
      fs:SetPoint("TOP", f.sub, "BOTTOM", 0, -12 - (i - 1) * 24)
      fs:SetJustifyH("CENTER")
      f.lines[i] = fs
    end
    local close = self:Button(f, 120, 24, "BTN_CLOSE", function() f:Hide() end, "primary")
    close:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
  end
  local ws = BF.Speedrun.WeekStart()
  f.title:SetText(string.format(T("CHAMP_TITLE"), date("%Y")))
  f.sub:SetText(string.format(T("CHAMP_WEEK"), date("%d.%m.", ws), date("%d.%m.", ws + 6 * 86400)))
  local medal = { "|cffffd100", "|cffc7c7cf", "|cffeda55f" }
  for i = 1, 3 do
    local e = top[i]
    if e then
      f.lines[i]:SetText(medal[i] .. i .. ". " .. e.name .. "|r   " .. BF.Duration(e.best))
    else
      f.lines[i]:SetText("")
    end
  end
  f:Show()
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
    if self.page == "speedrun" then self:RefreshSpeedrun() end
    self.sessBtn.fs:SetText(T(running and "BTN_SESSION_STOP" or "BTN_SESSION_START"))
    self:Tint(self.sessBtn, running and { 0.38, 0.08, 0.06 } or { 0.10, 0.32, 0.12 })
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
      b:SetHeight(60)
      b.sep:Show()
      b.text3:Show()
      -- Lap 1 xx:xx | Lap 2 xx:xx | ... : fertige Laps weiss, die laufende gold, jede erscheint erst,
      -- wenn sie beginnt
      local SR = BF.Speedrun
      local hl = (BananaFarmDB.speedrun.heat or {}).laps or {}
      local parts = {}
      for i = 1, getn(hl) do
        table.insert(parts, gray .. string.format(T("BAR_LAPN"), i) .. "|r " .. BF.Duration(hl[i].t))
      end
      if SR:Running() then
        table.insert(parts, "|cffffd100" .. string.format(T("BAR_LAPN"), getn(hl) + 1) .. " " .. BF.Duration(SR:Elapsed()) .. "|r")
      end
      local line3
      if getn(parts) > 0 then
        line3 = table.concat(parts, gray .. "  ||  |r")
      elseif S:Running() and BananaFarmDB.srAutoStart then
        line3 = gray .. T("BAR_LAP_WAIT") .. "|r"
      else
        line3 = gray .. T("BAR_LAP_NONE") .. "|r"
      end
      b.text3:SetText(line3)
    else
      b:SetHeight(40)
      b.sep:Hide()
      b.text3:Hide()
    end
    -- Breite folgt dem Inhalt: waechst sofort, schrumpft erst bei deutlichem Platzgewinn
    -- der Knopf Inst. Reset gehoert nur auf den Twink (hat einen Main als Partner)
    local twink = BF.Sync:Peer() and not BF.Sync:IsMain()
    if twink then b.instBtn:Show() else b.instBtn:Hide() end
    local need = 4 + 48 + 8 + math.max(b.text:GetStringWidth() or 0, b.text2:GetStringWidth() or 0) + 8 + 22 + 4
    if twink then need = need + 72 end
    if BF:Enabled("speedrun") then
      local need3 = 10 + (b.text3:GetStringWidth() or 0) + 10
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
  self:Tip(f.btn, "BAR_SESSION", "TT_SESSION")
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
  -- keine Knoepfe mehr: Laps laufen vollautomatisch (Portal, Instanz-Reset, Session-Stopp)
  f.text3 = self:Font(f, 10)
  f.text3:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
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
  local f = self:Window("BananaFarmAssign", 360, 128)
  self.assign = f
  if not BananaFarmDB.pos["BananaFarmAssign"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 180) end
  local title = self:Font(f, 12, C.gold)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
  title:SetText(T("ASSIGN_TITLE"))
  f.title = title
  tinsert(UISpecialFrames, "BananaFarmAssign")
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
  f.name:SetWidth(290)
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
  local bv = self:Button(f, 72, 24, "LIST_V", choose("V"), "primary")
  bv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
  self:Tint(bv, UI.LIST_COLOR.V)
  self:Tip(bv, "LIST_V", "LISTDESC_V")
  -- Mail: ab zwei hinterlegten Mailzielen oeffnet sich eine Auswahl, sonst wird gleich zugeordnet
  local bm = self:Button(f, 72, 24, "LIST_M", function()
    if getn(BananaFarmDB.mailTargets) >= 2 then
      UI:ToggleAssignMenu()
    else
      choose("M")()
    end
  end, "ok")
  bm:SetPoint("LEFT", bv, "RIGHT", 5, 0)
  self:Tint(bm, UI.LIST_COLOR.M)
  self:Tip(bm, "LIST_M", "LISTDESC_M")
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
  local bi = self:Button(f, 100, 24, "LIST_I", choose("I"))
  bi:SetPoint("LEFT", bm, "RIGHT", 5, 0)
  self:Tint(bi, UI.LIST_COLOR.I)
  self:Tip(bi, "LIST_I", "LISTDESC_I")
  local bl = self:Button(f, 72, 24, "BTN_LATER", choose(nil), "flat")
  bl:SetPoint("LEFT", bi, "RIGHT", 5, 0)
  f.later = bl
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

-- manual = true: per Alt+Klick aus der Tasche (auch fuer schon zugeordnete Items)
function UI:ShowAssign(id, manual)
  local f = self.assign
  -- ein offenes Pop-up aus der Warteschlange kommt spaeter wieder dran
  if manual and f:IsVisible() and f.id and f.id ~= id and not f.manual then
    table.insert(BF.Lists.queue, 1, f.id)
  end
  f.id = id
  f.manual = manual
  f.menu:Hide()
  f.title:SetText(T(manual and "ASSIGN_TITLE_PICK" or "ASSIGN_TITLE"))
  f.later.fs:SetText(T(manual and "BTN_CANCEL" or "BTN_LATER"))
  local name, q, tex = BF:ItemInfo(id)
  local c = BF.QUALITY_COLOR[q or 1] or BF.QUALITY_COLOR[1]
  f.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.name:SetText(name)
  f.name:SetTextColor(c[1], c[2], c[3])
  local values = string.format(T("ASSIGN_VALUES"), moneyOrDash(BF:VendorValue(id)), ahText(id))
  local cur = BF.Lists:Get(id)
  if manual and cur then values = values .. "   " .. string.format(T("ASSIGN_NOW"), T("LIST_" .. cur)) end
  f.values:SetText(values)
  local n = getn(BF.Lists.queue)
  if n > 0 then f.left:SetText(string.format(T("ASSIGN_LEFT"), n)) else f.left:SetText("") end
  f:Show()
end

-- ------------------------------------------------------------
-- Abfragefenster (Ja / Nein)
-- ------------------------------------------------------------
function UI:BuildConfirm()
  local f = self:Window("BananaFarmConfirm", 340, 130)
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

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
local ROWS = 12
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
  b.Update = function()
    if BananaFarmDB[field] then chk:Show() else chk:Hide() end
  end
  b:SetScript("OnClick", function()
    BananaFarmDB[field] = not BananaFarmDB[field]
    PlaySound("igMainMenuOptionCheckBoxOn")
    b.Update()
    if onChange then onChange() end
  end)
  b.Update()
  return b
end

-- Eingabefeld: uebernimmt beim Verlassen (Enter, Klick woanders), Escape verwirft
function UI:EditBox(name, parent, w, getter, setter)
  local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  e:SetWidth(w)
  e:SetHeight(20)
  e:SetAutoFocus(false)
  e:SetFontObject("ChatFontNormal")
  e:SetMaxLetters(24)
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
  BF.Lists:HookBags()
  self:Refresh()
end

function UI:BuildMain()
  local f = self:Window("BananaFarmFrame", 480, 500)
  self.frame = f
  if not BananaFarmDB.pos["BananaFarmFrame"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
  tinsert(UISpecialFrames, "BananaFarmFrame")

  local title = self:Font(f, 20, C.gold, FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
  title:SetText("BananaFarm")
  local sub = self:Font(f, 10, C.muted)
  sub:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 3)
  self:Loc(sub, "TITLE_SUB")
  local ver = self:Font(f, 9, C.muted)
  ver:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -18)
  ver:SetText("v" .. BF.VERSION)

  local close = self:Button(f, 22, 22, "X", function() f:Hide() end, "danger")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)

  self.tabLists = self:Button(f, 110, 24, "TAB_LISTS", function() UI:ShowPage("lists") end)
  self.tabLists:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -42)
  self.tabSettings = self:Button(f, 130, 24, "TAB_SETTINGS", function() UI:ShowPage("settings") end)
  self.tabSettings:SetPoint("LEFT", self.tabLists, "RIGHT", 6, 0)

  -- Session-Zeile oben rechts
  self.sessBtn = self:Button(f, 70, 24, "BTN_START", function() BF.Session:Toggle() end, "ok")
  self.sessBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -42)
  self.sessText = self:Font(f, 10, C.text)
  self.sessText:SetPoint("RIGHT", self.sessBtn, "LEFT", -8, 0)
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
end

function UI:RefreshList()
  if not self.frame or not self.frame:IsVisible() or self.page ~= "lists" then return end
  for i = 1, getn(BF.LIST_KEYS) do
    local key = BF.LIST_KEYS[i]
    local b = self.chips[key]
    b.fs:SetText(T("LIST_" .. key) .. " (" .. BF.Lists:CountOf(key) .. ")")
    b:SetActive(key == self.sel)
  end
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
      r.vendor:SetText(moneyOrDash(BF:VendorValue(id)))
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

  local function editRow(key, name, w, getter, setter)
    local e = self:EditBox(name, p, w, getter, setter)
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
  editRow("SET_SYNCPEER", "BananaFarmEditSyncPeer", 110,
    function() return BananaFarmDB.syncPeer or "" end,
    function(v)
      v = string.gsub(BF.Trim(v), "%s", "")
      BananaFarmDB.syncPeer = v
      if v ~= "" then BF:Print(string.format(T("MSG_SYNC_PEER"), v)) end
    end)
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
-- Seiten, Sprache, Auffrischen
-- ------------------------------------------------------------
function UI:ShowPage(page)
  self.page = page
  if page == "lists" then
    self.pageLists:Show()
    self.pageSettings:Hide()
  else
    self.pageLists:Hide()
    self.pageSettings:Show()
  end
  self.tabLists:SetActive(page == "lists")
  self.tabSettings:SetActive(page == "settings")
  self:RefreshList()
  self:RefreshSettings()
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
  local text
  local s = BananaFarmDB.session
  local R = BF.Resets
  local n = R:Count()
  local rem = R:Remaining()
  local rtxt = T("BAR_RESETS") .. " " .. n .. "/" .. R.LIMIT
  if rem then rtxt = rtxt .. " " .. BF.Duration(rem) end
  if n >= R.LIMIT then rtxt = "|cffff5050" .. rtxt .. "|r" else rtxt = "|cff9a9cb3" .. rtxt .. "|r" end
  if running or (s.elapsed or 0) > 0 then
    local value = S:Value()
    text = BF.Duration(S:Elapsed()) .. "  " .. BF.Money(S:PerHour()) .. "/h"
    text = text .. "\n|cff9a9cb3" .. T("BAR_GOLD") .. "|r " .. BF.Money(value) .. "  " .. rtxt
  else
    text = "|cff9a9cb3" .. T("BAR_IDLE") .. "|r\n" .. rtxt
  end
  local label = T(running and "BTN_STOP" or "BTN_START")
  if self.frame:IsVisible() then
    self.sessText:SetText(text)
    self.sessBtn.fs:SetText(label)
  end
  if self.bar:IsVisible() then
    self.bar.text:SetText(text)
    self.bar.btn.fs:SetText(label)
  end
end

function UI:Refresh()
  if not self.frame then return end
  if BananaFarmDB.bar then self.bar:Show() else self.bar:Hide() end
  self:RefreshSession()
  if self.frame:IsVisible() then self:ShowPage(self.page) end
end

-- ------------------------------------------------------------
-- Kleine Leiste: Start/Stop, Dauer, Wert, Gold/h
-- (Pull-Zaehler und Loot-Knopf kommen nach /bf probe dazu)
-- ------------------------------------------------------------
function UI:BuildBar()
  local f = self:Window("BananaFarmBar", 320, 44)
  self.bar = f
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(false)
  if not BananaFarmDB.pos["BananaFarmBar"] then f:SetPoint("TOP", UIParent, "TOP", 0, -120) end
  f.btn = self:Button(f, 56, 22, "BTN_START", function() BF.Session:Toggle() end, "ok")
  f.btn:SetPoint("LEFT", f, "LEFT", 4, 0)
  local open = self:Button(f, 26, 22, "BF", function() UI:Toggle() end, "primary")
  open:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  open:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine("BananaFarm", 1, 0.82, 0.26)
    GameTooltip:AddLine(T("TT_BAR"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  open:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.text = self:Font(f, 10)
  f.text:SetPoint("LEFT", f.btn, "RIGHT", 8, 0)
  f.text:SetPoint("RIGHT", open, "LEFT", -6, 0)
  f.text:SetJustifyH("CENTER")
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

  local function choose(list)
    return function()
      local id = f.id
      f:Hide()
      if id and list then
        BF.Lists:Set(id, list)
        BF:Print(string.format(T("MSG_ASSIGNED"), BF:ColoredName(id), T("LIST_" .. list)))
      end
      BF.Lists:PopNext()
    end
  end
  local bv = self:Button(f, 70, 24, "LIST_V", choose("V"), "primary")
  bv:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
  local bm = self:Button(f, 70, 24, "LIST_M", choose("M"), "ok")
  bm:SetPoint("LEFT", bv, "RIGHT", 5, 0)
  local bi = self:Button(f, 78, 24, "LIST_I", choose("I"))
  bi:SetPoint("LEFT", bm, "RIGHT", 5, 0)
  local bl = self:Button(f, 64, 24, "BTN_LATER", choose(nil), "flat")
  bl:SetPoint("LEFT", bi, "RIGHT", 5, 0)
end

function UI:AssignShown()
  return self.assign and self.assign:IsVisible()
end

function UI:ShowAssign(id)
  local f = self.assign
  f.id = id
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

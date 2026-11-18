-- BananaFarm Spenden: Fenster im BananaForge-Stil, einmalige Spende und Spenden-Abo.
-- Spendenziel ist Bareg auf N'Zoth. Auf einem anderen Realm zeigt das Fenster nur den Namen zum Kopieren.
-- Auf N'Zoth wird ein Betrag nur vorgemerkt. Verschickt wird erst am Briefkasten, nach einer Abfrage
-- mit Betrag und Empfaenger (Ja = senden, Nein = beim naechsten Briefkasten wieder fragen).
-- Abo: je beendeter Session oder je Runde (Instanz-Reset in einer laufenden Session) kommt der
-- Abo-Betrag zur Vormerkung dazu. Standard: aus. Hoechstens DONATE_MAX pro Brief.

local BF = BananaFarm
local floor = math.floor

BF.Donate = {}
local D = BF.Donate

D.NAME = "Bareg"
D.REALM = "N'Zoth"
D.MAX = 1000000 -- 100 Gold pro Brief

local function db()
  local d = BananaFarmDB.donate
  d.pending = d.pending or 0
  d.total = d.total or 0
  return d
end

-- Realmname nur aus Buchstaben und Ziffern vergleichen: Apostroph-Varianten (auch typografische),
-- Leerzeichen, Zusaetze wie "OctoWoW N'Zoth" oder "[PvE]" stoeren so nicht.
local function norm(s)
  s = string.lower(s or "")
  s = string.gsub(s, "[^%a%d]", "")
  return s
end

function D:RealmName()
  return (GetRealmName and GetRealmName()) or "?"
end

function D:OnRealm()
  return string.find(norm(self:RealmName()), norm(self.REALM), 1, true) ~= nil
end

-- Spendet der Spieler gerade an sich selbst? Dann nichts tun.
function D:IsSelf()
  return string.lower(UnitName("player") or "") == string.lower(self.NAME)
end

function D:Pending()
  return db().pending
end

-- Betrag (Kupfer) vormerken
function D:Add(copper, quiet)
  copper = floor(copper or 0)
  if copper <= 0 then return end
  local d = db()
  d.pending = d.pending + copper
  if not quiet then BF:Print(string.format(BF.T("MSG_DONATE_ADDED"), BF.Money(copper), BF.Money(d.pending))) end
  if BF.UI then BF.UI:RefreshDonate() end
end

function D:Clear()
  db().pending = 0
  BF:Print(BF.T("MSG_DONATE_CLEARED"))
  if BF.UI then BF.UI:RefreshDonate() end
end

-- mode: "session" | "run" | nil (aus)
function D:SetAbo(mode, copper)
  local d = db()
  if mode and (not copper or copper <= 0) then
    BF:Print(BF.T("MSG_DONATE_NOAMOUNT"))
    return
  end
  d.aboMode = mode
  d.aboAmount = mode and floor(copper) or nil
  if mode then
    BF:Print(string.format(BF.T("MSG_DONATE_ABO"), BF.Money(d.aboAmount), BF.T(mode == "run" and "DONATE_ABO_RUN" or "DONATE_ABO_SESSION")))
  else
    BF:Print(BF.T("MSG_DONATE_ABO_OFF"))
  end
  if BF.UI then BF.UI:RefreshDonate() end
end

-- Aufrufe aus Session.lua
function D:OnSessionStop()
  local d = db()
  if d.aboMode == "session" and (d.aboAmount or 0) > 0 and self:OnRealm() and not self:IsSelf() then
    self:Add(d.aboAmount, true)
    BF:Print(string.format(BF.T("MSG_DONATE_ACCRUED"), BF.Money(d.aboAmount), BF.Money(d.pending)))
  end
end

function D:OnNewRun()
  local d = db()
  if d.aboMode == "run" and (d.aboAmount or 0) > 0 and self:OnRealm() and not self:IsSelf() then
    self:Add(d.aboAmount, true)
  end
end

-- ------------------------------------------------------------
-- Versand am Briefkasten
-- ------------------------------------------------------------
function D:Ask()
  if not BF.mailOpen or self.sending then return end
  local d = db()
  if d.pending <= 0 or not self:OnRealm() or self:IsSelf() then return end
  -- erst die Mailliste abwarten (Nachfrage offen oder Versand laeuft)
  local busy = (BF.Mail and BF.Mail.run) or (BF.UI and BF.UI.confirm and BF.UI.confirm:IsVisible())
  if busy then
    self.tries = (self.tries or 0) + 1
    if self.tries < 60 then BF:After(2, function() D:Ask() end, "donateask") end
    return
  end
  local amount = d.pending
  if amount > self.MAX then amount = self.MAX end
  BF.UI:Confirm("donate", string.format(BF.T("ASK_DONATE"), BF.Money(amount), self.NAME),
    function() D:Send(amount) end)
end

function D:Send(amount)
  if not BF.mailOpen then
    BF:Print(BF.T("ERR_NO_MAILBOX"))
    return
  end
  if amount > GetMoney() - BF.POSTAGE then
    BF:Error(BF.T("MSG_DONATE_NOMONEY"))
    return
  end
  -- nur ein Brief ohne Anhaenge: liegt schon etwas im Postfenster, lieber nichts tun
  local O = BF.MailOrig or {}
  local get = O.getItem or GetSendMailItem
  if get then
    for i = 1, BF.Mail:Slots() do
      local ok, name = pcall(get, i)
      if ok and name and name ~= "" then
        BF:Error(BF.T("MSG_DONATE_ATTACH"))
        return
      end
    end
  end
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, 2) end
  self.sending = amount
  BF:After(15, function()
    if D.sending then
      D.sending = nil
      BF:Error(BF.T("MSG_DONATE_FAIL"))
    end
  end, "donatetimeout")
  local setMoney = O.setMoney or SetSendMailMoney
  local send = O.send or SendMail
  if O.setCOD then pcall(O.setCOD, 0) elseif SetSendMailCOD then pcall(SetSendMailCOD, 0) end
  if not setMoney or not pcall(setMoney, amount) or not pcall(send, self.NAME, BF.T("DONATE_SUBJECT"), BF.T("DONATE_BODY")) then
    self.sending = nil
    BF:Cancel("donatetimeout")
    BF:Error(BF.T("MSG_DONATE_FAIL"))
  end
end

BF:On("MAIL_SEND_SUCCESS", function()
  local amount = D.sending
  if not amount then return end
  D.sending = nil
  BF:Cancel("donatetimeout")
  local d = db()
  d.pending = d.pending - amount
  if d.pending < 0 then d.pending = 0 end
  d.total = d.total + amount
  BF:Print(string.format(BF.T("MSG_DONATE_SENT"), BF.Money(amount), D.NAME))
  if BF.UI then BF.UI:RefreshDonate() end
end)

BF:On("MAIL_FAILED", function()
  if not D.sending then return end
  D.sending = nil
  BF:Cancel("donatetimeout")
  BF:Error(BF.T("MSG_DONATE_FAIL"))
end)

BF:On("MAIL_SHOW", function()
  D.tries = 0
  BF:After(1.5, function() D:Ask() end, "donateask")
end)

BF:On("MAIL_CLOSED", function()
  BF:Cancel("donateask")
  if BF.UI then BF.UI:HideConfirm("donate") end
end)

-- ------------------------------------------------------------
-- Fenster
-- ------------------------------------------------------------
local UI = BF.UI
local T = function(k) return BF.T(k) end

-- einfaches Zahlenfeld: behaelt den Text beim Verlassen (der Knopf daneben liest ihn danach)
local function amountBox(name, parent)
  local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  e:SetWidth(60)
  e:SetHeight(20)
  e:SetAutoFocus(false)
  e:SetFontObject("ChatFontNormal")
  e:SetMaxLetters(8)
  e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  return e
end

local function gold(text)
  text = string.gsub(text or "", ",", ".")
  local n = tonumber(text)
  if not n or n <= 0 then return nil end
  return floor(n * 10000 + 0.5)
end

function UI:BuildDonate()
  local C = self.C
  local f = self:Window("BananaFarmDonate", 400, 330)
  self.donate = f
  if not BananaFarmDB.pos["BananaFarmDonate"] then f:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
  tinsert(UISpecialFrames, "BananaFarmDonate")
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(BF.ICON)
  icon:SetWidth(48)
  icon:SetHeight(48)
  icon:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
  local title = self:Font(f, 16, C.gold, "Fonts\\MORPHEUS.TTF")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -16)
  self:Loc(title, "DONATE_TITLE")
  local close = self:Button(f, 22, 22, "X", function() f:Hide() end, "danger")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
  local text = self:Font(f, 11, C.text)
  text:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -38)
  text:SetWidth(310)
  text:SetJustifyH("LEFT")
  self:Loc(text, "DONATE_TEXT")

  -- anderer Realm: nur Name zum Kopieren
  local other = CreateFrame("Frame", nil, f)
  other:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -100)
  other:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  local ot = self:Font(other, 11, C.text)
  ot:SetPoint("TOPLEFT", other, "TOPLEFT", 20, -6)
  ot:SetWidth(360)
  ot:SetJustifyH("LEFT")
  self:Loc(ot, "DONATE_OTHER")
  local nb = CreateFrame("EditBox", "BananaFarmDonateName", other, "InputBoxTemplate")
  nb:SetWidth(140)
  nb:SetHeight(20)
  nb:SetAutoFocus(false)
  nb:SetFontObject("ChatFontNormal")
  nb:SetPoint("TOPLEFT", other, "TOPLEFT", 26, -56)
  nb:SetText(BF.Donate.NAME)
  -- nur zum Kopieren: Text bleibt fest, beim Anklicken markiert
  nb:SetScript("OnTextChanged", function()
    if this:GetText() ~= BF.Donate.NAME then this:SetText(BF.Donate.NAME) end
  end)
  nb:SetScript("OnEditFocusGained", function() this:HighlightText() end)
  nb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  local realm = self:Font(other, 11, C.muted)
  realm:SetPoint("LEFT", nb, "RIGHT", 10, 0)
  realm:SetText(BF.Donate.REALM)
  f.other = other
  f.otherText = ot
  f.nameBox = nb

  -- erkannter Server (zur Kontrolle, unten links)
  f.realm = self:Font(f, 9, C.muted)
  f.realm:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 6)
  f.realm:SetJustifyH("RIGHT")

  -- N'Zoth: Vormerken und Abo
  local here = CreateFrame("Frame", nil, f)
  here:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -100)
  here:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  f.here = here

  local l1 = self:Font(here, 12, C.gold)
  l1:SetPoint("TOPLEFT", here, "TOPLEFT", 20, -4)
  self:Loc(l1, "DONATE_ONCE")
  local once = amountBox("BananaFarmDonateOnce", here)
  once:SetPoint("TOPLEFT", here, "TOPLEFT", 26, -24)
  local g1 = self:Font(here, 11)
  g1:SetPoint("LEFT", once, "RIGHT", 6, 0)
  self:Loc(g1, "GOLD")
  local add = self:Button(here, 120, 22, "BTN_DONATE_ADD", function()
    local c = gold(once:GetText())
    if not c then
      BF:Print(BF.T("MSG_DONATE_NOAMOUNT"))
      return
    end
    once:SetText("")
    once:ClearFocus()
    BF.Donate:Add(c)
  end, "primary")
  add:SetPoint("LEFT", g1, "RIGHT", 12, 0)

  local l2 = self:Font(here, 12, C.gold)
  l2:SetPoint("TOPLEFT", here, "TOPLEFT", 20, -60)
  self:Loc(l2, "DONATE_ABO")
  local abo = amountBox("BananaFarmDonateAbo", here)
  abo.Update = function()
    local a = BananaFarmDB.donate.aboAmount
    if a then abo:SetText(tostring(a / 10000)) end
  end
  abo:SetPoint("TOPLEFT", here, "TOPLEFT", 26, -80)
  f.abo = abo
  local g2 = self:Font(here, 11)
  g2:SetPoint("LEFT", abo, "RIGHT", 6, 0)
  self:Loc(g2, "GOLD")
  f.modeBtn = {}
  local modes = { { "session", "DONATE_ABO_SESSION" }, { "run", "DONATE_ABO_RUN" }, { "off", "DONATE_ABO_OFF" } }
  local prev = g2
  for i = 1, 3 do
    local mode = modes[i][1]
    local b = self:Button(here, 86, 22, modes[i][2], function()
      if mode == "off" then
        BF.Donate:SetAbo(nil)
      else
        BF.Donate:SetAbo(mode, gold(abo:GetText()))
      end
      abo:ClearFocus()
    end, "flat")
    b:SetPoint("LEFT", prev, "RIGHT", i == 1 and 12 or 4, 0)
    f.modeBtn[mode] = b
    prev = b
  end

  f.pending = self:Font(here, 11, C.text)
  f.pending:SetPoint("TOPLEFT", here, "TOPLEFT", 22, -118)
  local clear = self:Button(here, 120, 22, "BTN_DONATE_CLEAR", function() BF.Donate:Clear() end, "danger")
  clear:SetPoint("TOPRIGHT", here, "TOPRIGHT", -20, -114)
  f.total = self:Font(here, 10, C.muted)
  f.total:SetPoint("TOPLEFT", here, "TOPLEFT", 22, -138)

  local hint = self:Font(here, 10, C.muted)
  hint:SetPoint("BOTTOMLEFT", here, "BOTTOMLEFT", 20, 16)
  hint:SetWidth(360)
  hint:SetJustifyH("LEFT")
  self:Loc(hint, "DONATE_HINT")
end

function UI:ShowDonate()
  if not self.donate then self:BuildDonate() end
  self.donate:Show()
  self:RefreshDonate()
end

function UI:RefreshDonate()
  local f = self.donate
  if not f or not f:IsVisible() then return end
  local D = BF.Donate
  f.realm:SetText(string.format(T("DONATE_REALM"), D:RealmName()))
  if D:OnRealm() and not D:IsSelf() then
    f.other:Hide()
    f.here:Show()
  else
    f.here:Hide()
    f.other:Show()
    -- auf Bareg selbst: eigener Hinweis statt "anderer Server"
    if D:IsSelf() then
      f.otherText:SetText(T("DONATE_SELF"))
      f.nameBox:Hide()
    else
      f.otherText:SetText(T("DONATE_OTHER"))
      f.nameBox:Show()
    end
  end
  local d = BananaFarmDB.donate
  f.abo.Update()
  for mode, b in pairs(f.modeBtn) do
    local on = (mode == "off" and not d.aboMode) or d.aboMode == mode
    b:SetActive(on)
  end
  f.pending:SetText(string.format(T("DONATE_PENDING"), BF.Money(d.pending or 0)))
  f.total:SetText(string.format(T("DONATE_TOTAL"), BF.Money(d.total or 0)))
end

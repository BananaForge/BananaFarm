-- BananaFarm Post: alle Items der Mailliste aus den Taschen an den Bankalt schicken.
-- Ablauf wie in BananaBank (Reiter Senden, kurz warten, anhaengen, pruefen, senden),
-- aber eigenstaendig und ohne Anfragen: so viele Stapel pro Brief, wie der Client erlaubt.

local BF = BananaFarm
local getn = table.getn

BF.Mail = {}
local Mail = BF.Mail

BF.POSTAGE = 30 -- Kupfer pro Anhang
BF.TM_MAX = 21 -- so viele Anhaenge fasst das TurtleMail-Sendefenster
BF.TM_BATCH = 1 -- Briefe je TurtleMail-Durchgang: bei mehreren in Folge scheiterte ab dem 2. Brief der Versand

-- Wie viele Anhaenge nimmt dieser Client? Vanilla kann einen, OctoWoW mehrere.
function Mail:Slots()
  if self.slots then return self.slots end
  local n = 0
  for i = 1, 12 do
    if getglobal("SendMailItemButton" .. i) then n = i else break end
  end
  if n < 1 then return 1 end
  self.slots = n
  return n
end

-- Ersetzt TurtleMail das Sendefenster? Dann gehen Anhaenge und Senden ueber dessen eigene Funktionen.
function Mail:TurtleMailActive()
  return type(TurtleMail) == "table" and type(TurtleMail.send_mail_button_onclick) == "function"
    and type(TurtleMail.sendmail_attached) == "function" and type(TurtleMail.sendmail_set_attachment) == "function"
end

local function tryClick(index)
  if not ClickSendMailItemButton then return end
  if index then pcall(ClickSendMailItemButton, index) else pcall(ClickSendMailItemButton) end
end

local function mailHasAttachment(index)
  if not GetSendMailItem then return nil end
  local ok, name = pcall(GetSendMailItem, index)
  if ok and name and name ~= "" then return true end
  if index then
    ok, name = pcall(GetSendMailItem)
    if ok and name and name ~= "" then return true end
  end
  return false
end

-- Stapel der Mailliste in den Taschen. Seelengebundenes laesst sich nicht verschicken und bleibt liegen.
function Mail:Collect()
  local list = {}
  BF.EachBagItem(function(bag, slot, id, count, locked)
    if not locked and BF.Lists:Eff(id) == "M" and not BF.IsSoulbound(bag, slot) then
      table.insert(list, { bag = bag, slot = slot, id = id, c = count })
    end
  end)
  return list
end

function Mail:Start()
  if self.run then return end
  local db = BananaFarmDB
  if not BF.mailOpen then
    BF:Print(BF.T("ERR_NO_MAILBOX"))
    return
  end
  if db.bankAlt == "" then
    BF:Print(BF.T("ERR_NO_ALT"))
    return
  end
  if string.lower(db.bankAlt) == string.lower(UnitName("player") or "") then
    BF:Print(BF.T("ERR_ALT_SELF"))
    return
  end
  local list = self:Collect()
  if getn(list) == 0 then
    BF:Print(BF.T("MSG_MAIL_NOTHING"))
    return
  end
  self.run = { list = list, idx = 1, stacks = 0, mails = 0, to = db.bankAlt }
  BF:Print(string.format(BF.T("MSG_MAIL_START"), getn(list), db.bankAlt))
  self:Next()
end

function Mail:Stop(errKey)
  local r = self.run
  if not r then return end
  self.run = nil
  BF:Cancel("mailstep")
  BF:Cancel("mailverify")
  BF:Cancel("mailtimeout")
  if CursorHasItem() then ClearCursor() end
  if errKey then BF:Error(BF.T(errKey)) end
  if r.mails > 0 then
    BF:Print(string.format(BF.T("MSG_MAIL_DONE"), r.stacks, r.mails, r.to))
  end
  if BF.UI then BF.UI:Refresh() end
end

function Mail:Next()
  local r = self.run
  if not r then return end
  if not BF.mailOpen then return self:Stop("ERR_MAIL_CLOSED") end
  if not r.list[r.idx] then return self:Stop() end
  if GetMoney() < BF.POSTAGE then return self:Stop("ERR_NO_POSTAGE") end
  -- Schritt 1: auf den Reiter Senden wechseln. Der Client nimmt einen Anhang
  -- erst an, wenn dieser Reiter offen ist, und braucht dafuer einen Moment.
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, 2) end
  BF:After(0.3, function()
    if Mail:TurtleMailActive() then Mail:TurtleAttach() else Mail:Step2() end
  end, "mailstep")
end

-- TurtleMail: Anhaenge direkt ueber dessen eigene Funktion setzen (der Klick-Weg scheitert dort,
-- weil TurtleMail das Cursor-Item erst im naechsten Frame kennt). TurtleMail verschickt dann
-- pro Anhang einen eigenen Brief und arbeitet die Liste selbst ab.
function Mail:TurtleAttach()
  local r = self.run
  if not r then return end
  if not BF.mailOpen then return self:Stop("ERR_MAIL_CLOSED") end
  r.turtle = true
  local max = math.floor(GetMoney() / BF.POSTAGE)
  if max > BF.TM_MAX then max = BF.TM_MAX end
  if max > BF.TM_BATCH then max = BF.TM_BATCH end
  local batch = {}
  local k = r.idx
  while r.list[k] and getn(batch) < max do
    local e = r.list[k]
    local id = BF.ItemID(GetContainerItemLink(e.bag, e.slot))
    if id == e.id then
      pcall(TurtleMail.sendmail_set_attachment, { e.bag, e.slot })
      if TurtleMail.sendmail_attached(e.bag, e.slot) then table.insert(batch, e) end
    end
    k = k + 1
  end
  r.idx = k
  if getn(batch) == 0 then
    if r.mails > 0 and not r.list[r.idx] then return self:Stop() end
    return self:AttachFailed()
  end
  r.batch = batch
  r.got = 0
  self:TurtleSend()
end

function Mail:TurtleSend()
  local r = self.run
  if not r or not r.batch then return end
  if SendMailNameEditBox then
    if SendMailNameEditBox._SetText then SendMailNameEditBox:_SetText(r.to) else SendMailNameEditBox:SetText(r.to) end
  end
  -- leerer Betreff: TurtleMail setzt selbst den Itemnamen. TurtleMail liest den Betreff aus dem
  -- globalen MailSubjectEditBox (ein Rest wie "bitte" landete sonst in jedem Brief).
  if MailSubjectEditBox then MailSubjectEditBox:SetText("") end
  if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText("") end
  if SendMailBodyEditBox then SendMailBodyEditBox:SetText("") end
  if SendMailMoney and MoneyInputFrame_SetCopper then pcall(MoneyInputFrame_SetCopper, SendMailMoney, 0) end
  if SendMailRadioButton_OnClick then pcall(SendMailRadioButton_OnClick, 1) end
  r.sending = true
  self:ArmTimeout()
  if not pcall(TurtleMail.send_mail_button_onclick) then self:Fail("ERR_MAIL_FAILED") end
end

function Mail:ArmTimeout()
  BF:Cancel("mailtimeout")
  BF:After(15, function()
    if Mail.run and Mail.run.sending then Mail:Fail("ERR_MAIL_TIMEOUT") end
  end, "mailtimeout")
end

-- haengt einen Stapel an: true (liegt im Brief), "wait" (spaeter pruefen) oder false
function Mail:Attach(e, index, stage)
  if CursorHasItem() then ClearCursor() end
  if stage ~= 2 and ClickSendMailItemButton then
    PickupContainerItem(e.bag, e.slot)
    if not CursorHasItem() then return false end
    -- genau ein Klick: manche Fenster uebernehmen den Anhang erst einen Moment spaeter
    if self:Slots() > 1 then tryClick(index) else tryClick(nil) end
    if not CursorHasItem() and mailHasAttachment(index) ~= false then return true end
    return "wait"
  end
  -- zweiter Weg: Rechtsklick haengt an, wenn der Reiter Senden offen ist (nur dann, sonst wuerde das Item benutzt)
  local sf = getglobal("SendMailFrame")
  if UseContainerItem and sf and sf:IsVisible() and self:Slots() > 1 then
    pcall(UseContainerItem, e.bag, e.slot)
    if CursorHasItem() then ClearCursor() end
    if self:AttachedNow(e, index) then return true end
    return "wait"
  end
  return false
end

function Mail:AttachedNow(e, index)
  -- TurtleMail haelt die Anhaenge in einer eigenen Liste; GetSendMailItem sieht sie nicht
  if self:TurtleMailActive() then
    local ok, res = pcall(TurtleMail.sendmail_attached, e.bag, e.slot)
    return ok and res and true or false
  end
  if mailHasAttachment(index) then return true end
  if CursorHasItem() then return false end
  local link = GetContainerItemLink(e.bag, e.slot)
  if not link then return true end
  local _, _, locked = GetContainerItemInfo(e.bag, e.slot)
  if locked then return true end
  return false
end

function Mail:Step2()
  local r = self.run
  if not r then return end
  if not BF.mailOpen then return self:Stop("ERR_MAIL_CLOSED") end
  r.stage2 = nil
  local slots = self:Slots()
  -- nicht mehr Anhaenge, als das Porto hergibt
  local afford = math.floor(GetMoney() / BF.POSTAGE)
  if afford < slots then slots = afford end
  local batch = {}
  local wait = false
  local k = r.idx
  while r.list[k] and getn(batch) < slots do
    local e = r.list[k]
    -- der Platz muss noch denselben Stapel halten (Taschen koennen sich geaendert haben)
    local id = BF.ItemID(GetContainerItemLink(e.bag, e.slot))
    if id ~= e.id then
      r.idx = k + 1
      if getn(batch) > 0 then break end
    else
      local res = self:Attach(e, getn(batch) + 1)
      if not res then break end
      table.insert(batch, e)
      r.idx = k + 1
      if res == "wait" then
        wait = true
        break
      end
    end
    k = k + 1
  end
  if getn(batch) == 0 then
    if not r.list[r.idx] then return self:Stop() end
    return self:AttachFailed()
  end
  r.batch = batch
  if wait then
    BF:After(0.5, function() Mail:Verify() end, "mailverify")
    return
  end
  self:Send()
end

function Mail:Verify()
  local r = self.run
  if not r or not r.batch then return end
  local missing = {}
  for i = 1, getn(r.batch) do
    local ok = self:AttachedNow(r.batch[i], i)
    -- erster Weg: ist der Cursor nach dem Klick leer, hat das Fenster das Item genommen,
    -- auch wenn es sich per Abfrage nicht meldet
    if not ok and not r.stage2 and not CursorHasItem() and not self:TurtleMailActive() then ok = true end
    if not ok then table.insert(missing, i) end
  end
  if getn(missing) == 0 then return self:Send() end
  if not r.stage2 then
    r.stage2 = true
    if CursorHasItem() then ClearCursor() end
    for j = 1, getn(missing) do
      local i = missing[j]
      if not self:Attach(r.batch[i], i, 2) then return self:AttachFailed() end
    end
    BF:After(0.5, function() Mail:Verify() end, "mailverify")
    return
  end
  self:AttachFailed()
end

function Mail:AttachFailed()
  self:ClearAttachments()
  self:Stop("ERR_ATTACH_FAILED")
end

-- Anhaenge zurueck in die Taschen
function Mail:ClearAttachments()
  if self:TurtleMailActive() then
    if TurtleMail.sendmail_clear then pcall(TurtleMail.sendmail_clear) end
    return
  end
  if not ClickSendMailItemButton then return end
  for i = 1, self:Slots() do
    tryClick(self:Slots() > 1 and i or nil)
    if CursorHasItem() then ClearCursor() end
  end
end

function Mail:Send()
  local r = self.run
  if not r or not r.batch then return end
  local subject = "BananaFarm (" .. getn(r.batch) .. ")"
  if SendMailNameEditBox then
    -- TurtleMail ueberschreibt SetText und ignoriert es, solange es sich einen Empfaenger gemerkt hat
    if SendMailNameEditBox._SetText then SendMailNameEditBox:_SetText(r.to) else SendMailNameEditBox:SetText(r.to) end
  end
  if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(subject) end
  if SendMailBodyEditBox then SendMailBodyEditBox:SetText("") end
  r.sending = true
  BF:After(15, function()
    if Mail.run and Mail.run.sending then Mail:Fail("ERR_MAIL_TIMEOUT") end
  end, "mailtimeout")
  -- kein Geld, keine Nachnahme
  if SendMailMoney and MoneyInputFrame_SetCopper then
    pcall(MoneyInputFrame_SetCopper, SendMailMoney, 0)
    if SendMailRadioButton_OnClick then pcall(SendMailRadioButton_OnClick, 1) end
    -- TurtleMail verschickt die Anhaenge aus der eigenen Liste; sonst die Senden-Funktion des Fensters,
    -- damit andere Post-Addons mitbekommen, was passiert
    if self:TurtleMailActive() and pcall(TurtleMail.send_mail_button_onclick) then return end
    if SendMailFrame_SendMail and pcall(SendMailFrame_SendMail) then return end
  end
  if SetSendMailCOD then pcall(SetSendMailCOD, 0) end
  SendMail(r.to, subject, "")
end

function Mail:Fail(errKey)
  local r = self.run
  if not r then return end
  r.sending = false
  if r.turtle and type(TurtleMail) == "table" then
    TurtleMail.sendmail_sending = false
    TurtleMail.sendmail_state = nil
  end
  self:ClearAttachments()
  local detail = self.lastErr
  self.lastErr = nil
  self:Stop(errKey)
  if detail then BF:Error("-> " .. tostring(detail)) end
end

-- letzte Fehlermeldung des Spiels merken, damit ein Fehlschlag den genauen Grund zeigt
BF:On("UI_ERROR_MESSAGE", function(msg)
  if Mail.run and Mail.run.sending then Mail.lastErr = msg end
end)

BF:On("MAIL_SEND_SUCCESS", function()
  local r = Mail.run
  if not r or not r.sending then return end
  if r.turtle then
    -- TurtleMail schickt pro Anhang einen Brief: erst weiter, wenn alle der Charge durch sind
    r.mails = r.mails + 1
    r.got = r.got + 1
    local n = getn(r.batch or {})
    if r.got < n then
      Mail:ArmTimeout()
      return
    end
    r.sending = false
    BF:Cancel("mailtimeout")
    r.stacks = r.stacks + n
    r.batch = nil
    r.got = 0
    BF:After(1.0, function() Mail:Next() end, "mailstep")
    return
  end
  r.sending = false
  BF:Cancel("mailtimeout")
  r.mails = r.mails + 1
  r.stacks = r.stacks + getn(r.batch or {})
  r.batch = nil
  -- dem Server einen Moment lassen, sonst lehnt er den naechsten Brief ab
  BF:After(1.0, function() Mail:Next() end, "mailstep")
end)

BF:On("MAIL_FAILED", function()
  if Mail.run and Mail.run.sending then Mail:Fail("ERR_MAIL_FAILED") end
end)

BF:On("MAIL_CLOSED", function()
  if BF.UI then BF.UI:HideConfirm("mail") end
  if Mail.run then Mail:Stop("ERR_MAIL_CLOSED") end
end)

-- Briefkasten geoeffnet: nachfragen, ob die Mailliste verschickt werden soll.
-- Nie direkt im Ereignis pruefen: Post-Addons loesen beim Oeffnen viele Updates aus.
BF:On("MAIL_SHOW", function()
  BF:After(0.5, function()
    if not BF.mailOpen or Mail.run or not BananaFarmDB.mailAsk then return end
    local list = Mail:Collect()
    local n = getn(list)
    if n == 0 then return end
    local db = BananaFarmDB
    if db.bankAlt == "" then
      BF:Print(BF.T("ERR_NO_ALT"))
      return
    end
    local letters = math.ceil(n / Mail:Slots())
    if Mail:TurtleMailActive() then letters = n end
    BF.UI:Confirm("mail", string.format(BF.T("ASK_MAIL"), n, db.bankAlt, letters, BF.Money(n * BF.POSTAGE)),
      function() Mail:Start() end)
  end, "mailask")
end)

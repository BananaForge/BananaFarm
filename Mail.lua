-- BananaFarm Post: alle Items der Mailliste aus den Taschen an den Bankalt schicken.
-- Ablauf wie in BananaBank (Reiter Senden, kurz warten, anhaengen, pruefen, senden),
-- aber eigenstaendig und ohne Anfragen: so viele Stapel pro Brief, wie der Client erlaubt.

local BF = BananaFarm
local getn = table.getn

BF.Mail = {}
local Mail = BF.Mail

BF.POSTAGE = 30 -- Kupfer pro Anhang

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
    and type(TurtleMail.sendmail_attached) == "function"
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
    if not locked and BF.Lists:Get(id) == "M" and not BF.IsSoulbound(bag, slot) then
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
  BF:After(0.3, function() Mail:Step2() end, "mailstep")
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
  self:ClearAttachments()
  self:Stop(errKey)
end

BF:On("MAIL_SEND_SUCCESS", function()
  local r = Mail.run
  if not r or not r.sending then return end
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
    BF.UI:Confirm("mail", string.format(BF.T("ASK_MAIL"), n, db.bankAlt, letters, BF.Money(n * BF.POSTAGE)),
      function() Mail:Start() end)
  end, "mailask")
end)

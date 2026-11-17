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

-- Paketversand (mehrere Stapel in einem Brief): TurtleMail ersetzt die Post-Funktionen des Spiels und
-- schickt jeden Anhang als eigenen Brief. BananaFarm wird vor TurtleMail geladen (alphabetisch),
-- deshalb merken wir uns die Originale hier beim Laden der Datei und packen damit selbst.
-- Klappt das Anhaengen oder Senden nicht, faellt der Versand fuer diesen Briefkasten auf
-- den Einzelversand zurueck (Mail.noPack).
local O = {
  pickup = PickupContainerItem,
  click = ClickSendMailItemButton,
  getItem = GetSendMailItem,
  send = SendMail,
  setMoney = SetSendMailMoney,
  setCOD = SetSendMailCOD,
}
BF.MailOrig = O

-- ------------------------------------------------------------
-- Mailziele: weitere Ziele (db.mailTargets, Reihenfolge = Rang, das erste ist das Standardziel)
-- und die Zuordnung je Item (db.mailTarget[id] = Name). Beides wird nicht gesynct.
-- Ohne eigene Ziele geht alles an den Twink (Bankalt), also den Sync-Partner.
-- ------------------------------------------------------------
function Mail:Default()
  local db = BananaFarmDB
  local t = db.mailTargets
  if t and t[1] then return t[1] end
  if db.bankAlt and db.bankAlt ~= "" then return db.bankAlt end
  return nil
end

-- Name des Ziels aus der Liste (in der gespeicherten Schreibweise) oder nil
function Mail:IsTarget(name)
  local t = BananaFarmDB.mailTargets
  if not name or not t then return nil end
  local low = string.lower(name)
  for i = 1, getn(t) do
    if string.lower(t[i]) == low then return t[i] end
  end
  return nil
end

-- Ziel eines Items: das zugeordnete (falls es noch in der Liste steht), sonst das Standardziel
function Mail:TargetOf(id)
  return self:IsTarget(BananaFarmDB.mailTarget[id]) or self:Default()
end

-- Ziel eines Items ein Stueck weiterschalten (dir = 1 vor, -1 zurueck)
function Mail:CycleTarget(id, dir)
  local t = BananaFarmDB.mailTargets
  local n = getn(t)
  if n == 0 then return end
  local cur = string.lower(self:TargetOf(id) or "")
  local idx = 0
  for i = 1, n do
    if string.lower(t[i]) == cur then idx = i end
  end
  idx = idx + (dir or 1)
  if idx > n then idx = 1 elseif idx < 1 then idx = n end
  BananaFarmDB.mailTarget[id] = t[idx]
end

-- Mailziele aus einem Text uebernehmen (Namen mit Komma). Leer = keine eigenen Ziele.
function Mail:SetTargets(v)
  local list, seen = {}, {}
  for name in string.gfind(v or "", "[^,;%s]+") do
    local k = string.lower(name)
    if not seen[k] then
      seen[k] = true
      table.insert(list, name)
    end
  end
  BananaFarmDB.mailTargets = list
  if getn(list) == 0 then
    BF:Print(BF.T("MSG_MAIL_TARGETS_CLEARED"))
  else
    BF:Print(string.format(BF.T("MSG_MAIL_TARGETS"), table.concat(list, ", "), list[1]))
  end
  if BF.UI then BF.UI:Refresh() end
end

-- Namen der Ziele einer Liste, ohne Doppelte, in der Reihenfolge des Auftretens
function Mail:NamesOf(list)
  local seen, out = {}, {}
  for i = 1, getn(list) do
    local k = string.lower(list[i].to)
    if not seen[k] then
      seen[k] = true
      table.insert(out, list[i].to)
    end
  end
  return table.concat(out, ", ")
end

-- Zahl der Briefe, je Ziel gruppiert
function Mail:Letters(list)
  local per, order = {}, {}
  for i = 1, getn(list) do
    local k = string.lower(list[i].to)
    if not per[k] then
      per[k] = 0
      table.insert(order, k)
    end
    per[k] = per[k] + 1
  end
  local n = 0
  for i = 1, getn(order) do
    if self:TurtleMailActive() and not self:PackMode() then
      n = n + per[order[i]]
    else
      n = n + math.ceil(per[order[i]] / self:Slots())
    end
  end
  return n
end

-- merkt, an wen tatsaechlich Briefe durchgingen (fuer die Abschlussmeldung)
function Mail:Tally(r)
  if not r.to then return end
  local k = string.lower(r.to)
  if not r.tally[k] then
    r.tally[k] = r.to
    table.insert(r.order, k)
  end
end

function Mail:TallyText(r)
  local out = {}
  for i = 1, getn(r.order) do table.insert(out, r.tally[r.order[i]]) end
  if getn(out) == 0 then return r.to or "?" end
  return table.concat(out, ", ")
end

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

-- Pakete moeglich? Das Postfenster hat mehrere Anhang-Felder, die Originale sind da und
-- an diesem Briefkasten ist der Paketversand noch nicht gescheitert.
function Mail:PackMode()
  if self.noPack then return false end
  return self:Slots() > 1 and O.pickup ~= nil and O.click ~= nil and O.send ~= nil
end

-- Original-Funktion, solange Pakete laufen, sonst die (evtl. von TurtleMail ersetzte) aktuelle
local function fn(name, cur)
  if Mail:PackMode() and O[name] then return O[name] end
  return cur
end

local function tryClick(index)
  local click = fn("click", ClickSendMailItemButton)
  if not click then return end
  if index then pcall(click, index) else pcall(click) end
end

local function mailHasAttachment(index)
  local get = fn("getItem", GetSendMailItem)
  if not get then return nil end
  local ok, name = pcall(get, index)
  if ok and name and name ~= "" then return true end
  if index then
    ok, name = pcall(get)
    if ok and name and name ~= "" then return true end
  end
  return false
end

-- TurtleMail-Weg nur, wenn keine Pakete moeglich sind
function Mail:UseTurtle()
  return self:TurtleMailActive() and not self:PackMode()
end

-- Stapel der Mailliste in den Taschen. Seelengebundenes laesst sich nicht verschicken und bleibt liegen.
-- Liefert die Stapel, je Ziel zusammenhaengend (Ziele in der Reihenfolge ihres ersten Auftretens),
-- dazu die Zahl der Stapel, die an diesen Charakter selbst gehen wuerden (bleiben liegen),
-- und die Zahl der Stapel ohne jedes Ziel.
function Mail:Collect()
  local list, self_, none = {}, 0, 0
  local me = string.lower(UnitName("player") or "")
  BF.EachBagItem(function(bag, slot, id, count, locked)
    if not locked and BF.Lists:Eff(id) == "M" and not BF.IsSoulbound(bag, slot) then
      local to = Mail:TargetOf(id)
      if not to then
        none = none + 1
      elseif string.lower(to) == me then
        self_ = self_ + 1
      else
        table.insert(list, { bag = bag, slot = slot, id = id, c = count, to = to })
      end
    end
  end)
  local groups, order = {}, {}
  for i = 1, getn(list) do
    local k = string.lower(list[i].to)
    if not groups[k] then
      groups[k] = {}
      table.insert(order, k)
    end
    table.insert(groups[k], list[i])
  end
  -- je Ziel ein Paket, darin gleiche Items nebeneinander
  local sorted = {}
  for i = 1, getn(order) do
    local g = groups[order[i]]
    table.sort(g, function(a, b)
      if a.id ~= b.id then return a.id < b.id end
      if a.bag ~= b.bag then return a.bag < b.bag end
      return a.slot < b.slot
    end)
    for j = 1, getn(g) do table.insert(sorted, g[j]) end
  end
  return sorted, self_, none
end

function Mail:Start()
  if self.run then return end
  if not BF:Enabled("mail") then
    BF:Print(BF.T("ERR_MODULE_OFF"))
    return
  end
  local db = BananaFarmDB
  if not BF.mailOpen then
    BF:Print(BF.T("ERR_NO_MAILBOX"))
    return
  end
  local list, mine, none = self:Collect()
  if getn(list) == 0 then
    if none > 0 then
      BF:Print(BF.T("ERR_NO_ALT"))
    elseif mine > 0 then
      BF:Print(BF.T("ERR_ALT_SELF"))
    else
      BF:Print(BF.T("MSG_MAIL_NOTHING"))
    end
    return
  end
  self.run = { list = list, idx = 1, stacks = 0, mails = 0, to = list[1].to, tally = {}, order = {} }
  if self:PackMode() then BF:Print(string.format(BF.T("MSG_MAIL_PACK"), self:Slots())) end
  BF:Print(string.format(BF.T("MSG_MAIL_START"), getn(list), self:NamesOf(list)))
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
    BF:Print(string.format(BF.T("MSG_MAIL_DONE"), r.stacks, r.mails, self:TallyText(r)))
  end
  if BF.UI then BF.UI:Refresh() end
end

function Mail:Next()
  local r = self.run
  if not r then return end
  if not BF.mailOpen then return self:Stop("ERR_MAIL_CLOSED") end
  if not r.list[r.idx] then return self:Stop() end
  r.to = r.list[r.idx].to
  if GetMoney() < BF.POSTAGE then return self:Stop("ERR_NO_POSTAGE") end
  -- Schritt 1: auf den Reiter Senden wechseln. Der Client nimmt einen Anhang
  -- erst an, wenn dieser Reiter offen ist, und braucht dafuer einen Moment.
  if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, 2) end
  BF:After(0.3, function()
    if Mail:UseTurtle() then Mail:TurtleAttach() else Mail:Step2() end
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
    if getn(batch) == 0 then r.to = e.to elseif e.to ~= r.to then break end
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
  local pickup = fn("pickup", PickupContainerItem)
  if stage ~= 2 and fn("click", ClickSendMailItemButton) then
    pickup(e.bag, e.slot)
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
  if self:UseTurtle() then
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
  r.batchStart = r.idx
  local slots = self:Slots()
  -- nicht mehr Anhaenge, als das Porto hergibt
  local afford = math.floor(GetMoney() / BF.POSTAGE)
  if afford < slots then slots = afford end
  local batch = {}
  local wait = false
  local k = r.idx
  while r.list[k] and getn(batch) < slots do
    local e = r.list[k]
    if getn(batch) == 0 then r.to = e.to elseif e.to ~= r.to then break end
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
  local turtle = self:UseTurtle()
  for i = 1, getn(r.batch) do
    local ok = self:AttachedNow(r.batch[i], i)
    -- erster Weg: ist der Cursor nach dem Klick leer, hat das Fenster das Item genommen,
    -- auch wenn es sich per Abfrage nicht meldet
    if not ok and not r.stage2 and not CursorHasItem() and not turtle then ok = true end
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
  if self:PackFallback() then return end
  self:Stop("ERR_ATTACH_FAILED")
end

-- Paket gescheitert: einmal auf den Einzelversand umschalten und dieselben Stapel neu versuchen.
-- true, wenn der Versand weiterlaeuft.
function Mail:PackFallback()
  local r = self.run
  if not r or not self:PackMode() then return false end
  self.noPack = true
  r.sending = false
  r.batch = nil
  if CursorHasItem() then ClearCursor() end
  r.idx = r.batchStart or r.idx
  BF:Print(BF.T("MSG_MAIL_NOPACK"))
  BF:Cancel("mailtimeout")
  BF:After(1.0, function() Mail:Next() end, "mailstep")
  return true
end

-- Anhaenge zurueck in die Taschen
function Mail:ClearAttachments()
  if self:UseTurtle() then
    if TurtleMail.sendmail_clear then pcall(TurtleMail.sendmail_clear) end
    return
  end
  if not fn("click", ClickSendMailItemButton) then return end
  for i = 1, self:Slots() do
    tryClick(self:Slots() > 1 and i or nil)
    if CursorHasItem() then ClearCursor() end
  end
end

function Mail:Send()
  local r = self.run
  if not r or not r.batch then return end
  local subject = "BananaFarm (" .. getn(r.batch) .. ")"
  local first = r.batch[1] and BF:ItemInfo(r.batch[1].id)
  if first and getn(r.batch) > 1 then
    subject = first .. " +" .. (getn(r.batch) - 1)
  elseif first then
    subject = first
  end
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
  -- Paket: direkt mit der Original-Funktion senden, ohne dass TurtleMail seine eigene Liste schickt
  if self:PackMode() then
    if O.setMoney then pcall(O.setMoney, 0) end
    if O.setCOD then pcall(O.setCOD, 0) end
    if not pcall(O.send, r.to, subject, "") then self:Fail("ERR_MAIL_FAILED") end
    return
  end
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
  if errKey == "ERR_MAIL_FAILED" and self:PackFallback() then
    self.lastErr = nil
    return
  end
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
    Mail:Tally(r)
    r.batch = nil
    r.got = 0
    BF:After(1.0, function() Mail:Next() end, "mailstep")
    return
  end
  r.sending = false
  BF:Cancel("mailtimeout")
  r.mails = r.mails + 1
  r.stacks = r.stacks + getn(r.batch or {})
  Mail:Tally(r)
  r.batch = nil
  -- dem Server einen Moment lassen, sonst lehnt er den naechsten Brief ab
  BF:After(1.0, function() Mail:Next() end, "mailstep")
end)

BF:On("MAIL_FAILED", function()
  if Mail.run and Mail.run.sending then Mail:Fail("ERR_MAIL_FAILED") end
end)

BF:On("MAIL_CLOSED", function()
  -- beim naechsten Briefkasten Pakete wieder versuchen
  Mail.noPack = nil
  if BF.UI then BF.UI:HideConfirm("mail") end
  if Mail.run then Mail:Stop("ERR_MAIL_CLOSED") end
end)

-- Briefkasten geoeffnet: nachfragen, ob die Mailliste verschickt werden soll.
-- Nie direkt im Ereignis pruefen: Post-Addons loesen beim Oeffnen viele Updates aus.
BF:On("MAIL_SHOW", function()
  BF:After(0.5, function()
    if not BF.mailOpen or Mail.run or not BananaFarmDB.mailAsk or not BF:Enabled("mail") then return end
    local list, mine, none = Mail:Collect()
    local n = getn(list)
    if n == 0 then
      if none > 0 then BF:Print(BF.T("ERR_NO_ALT")) end
      return
    end
    BF.UI:Confirm("mail", string.format(BF.T("ASK_MAIL"), n, Mail:NamesOf(list), Mail:Letters(list), BF.Money(n * BF.POSTAGE)),
      function() Mail:Start() end)
  end, "mailask")
end)

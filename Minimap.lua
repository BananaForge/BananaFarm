-- BananaFarm Minimap-Symbol (0.7.2): rundes Symbol (Krone und Podest) am Rand der Minimap.
-- Linksklick: Hauptfenster ein/aus. Rechtsklick: Menue (Hauptfenster, Tracking-Leiste, Listen-Modul,
-- Session starten/stoppen, Einstellungen). Ziehen verschiebt das Symbol am Minimap-Rand.
-- Abschaltbar in den Einstellungen (minimap).

local BF = BananaFarm
local UI = BF.UI
local T = function(k) return BF.T(k) end
local getn = table.getn

BF.MINIMAP_ICON = "Interface\\AddOns\\BananaFarm\\Minimap"

function UI:BuildMinimap()
  if self.mmButton then return end
  local C = self.C
  local b = CreateFrame("Button", "BananaFarmMinimapButton", Minimap)
  self.mmButton = b
  b:SetWidth(31)
  b:SetHeight(31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(BF.MINIMAP_ICON)
  icon:SetWidth(21)
  icon:SetHeight(21)
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      UI:ToggleMinimapMenu()
    else
      if UI.mmMenu then UI.mmMenu:Hide() end
      UI:Toggle()
    end
  end)
  b:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      cx, cy = cx / s, cy / s
      BananaFarmDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
      UI:PlaceMinimap()
    end)
  end)
  b:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("BananaFarm", C.gold[1], C.gold[2], C.gold[3])
    GameTooltip:AddLine(T("TT_MINIMAP"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self:PlaceMinimap()
end

function UI:PlaceMinimap()
  local b = self.mmButton
  if not b then return end
  local a = math.rad(BananaFarmDB.minimapAngle or 215)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
  if BananaFarmDB.minimap then b:Show() else b:Hide() end
end

-- Eintraege des Rechtsklick-Menues: { Text, Aktion }
function UI:MinimapEntries()
  local items = BF:Enabled("items")
  local barOn = BananaFarmDB.bar and BF:Enabled("tracking")
  return {
    { T(self.frame:IsVisible() and "MM_MAIN_HIDE" or "MM_MAIN_SHOW"), function() UI:Toggle() end },
    { T(barOn and "MM_BAR_HIDE" or "MM_BAR_SHOW"), function() UI:ToggleBar() end },
    { T(items and "MM_ITEMS_OFF" or "MM_ITEMS_ON"), function()
        BF:SetModule("items", not items)
        BF:Print(T(items and "MSG_ITEMS_OFF" or "MSG_ITEMS_ON"))
        UI:RefreshModules()
      end },
    { T(BF.Session:Running() and "MM_SESSION_STOP" or "MM_SESSION_START"), function() BF.Session:Toggle() end },
    { T("MM_SETTINGS"), function()
        UI.frame:Show()
        UI:ShowPage("settings")
      end },
  }
end

function UI:ToggleMinimapMenu()
  local m = self.mmMenu
  if not m then
    m = CreateFrame("Frame", "BananaFarmMinimapMenu", UIParent)
    self.mmMenu = m
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetWidth(200)
    m:SetBackdrop(self.BACKDROP)
    m:SetBackdropColor(0.05, 0.07, 0.14, 0.98)
    m:SetBackdropBorderColor(self.C.goldDim[1], self.C.goldDim[2], self.C.goldDim[3], 0.9)
    m:EnableMouse(true)
    if m.SetClampedToScreen then m:SetClampedToScreen(true) end
    local title = self:Font(m, 11, self.C.gold)
    title:SetPoint("TOPLEFT", m, "TOPLEFT", 10, -8)
    title:SetText("BananaFarm")
    m.btn = {}
    for i = 1, 5 do
      local k = i -- Lua 5.0: Kopie der Zaehlvariable je Durchlauf (Closures)
      local b = self:Button(m, 184, 20, "?", function()
        local fn = m.actions and m.actions[k]
        m:Hide()
        if fn then fn() end
      end, "flat")
      b:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -24 - (i - 1) * 22)
      m.btn[i] = b
    end
    m:SetHeight(32 + 5 * 22)
    tinsert(UISpecialFrames, "BananaFarmMinimapMenu")
    m:Hide()
  end
  if m:IsVisible() then
    m:Hide()
    return
  end
  local entries = self:MinimapEntries()
  m.actions = {}
  for i = 1, getn(entries) do
    m.btn[i].fs:SetText(entries[i][1])
    m.actions[i] = entries[i][2]
  end
  m:ClearAllPoints()
  m:SetPoint("TOPRIGHT", self.mmButton, "BOTTOMLEFT", 0, 0)
  m:Show()
end

BF:On("PLAYER_ENTERING_WORLD", function()
  if UI.mmButton then return end
  UI:BuildMinimap()
end)

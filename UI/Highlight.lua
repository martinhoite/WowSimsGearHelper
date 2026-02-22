local WSGH = _G.WowSimsGearHelper or {}
WSGH.UI = WSGH.UI or {}
WSGH.UI.Highlight = WSGH.UI.Highlight or {}

local HighlightState = {
  target = nil,
  targets = nil,
  activeSlotId = nil,
  bagIndicators = {},
  socketIndicators = {},
  enchant = { spellId = nil, itemId = nil, slotId = nil, bagIndicators = {}, slotIndicators = {}, lastBagKey = nil, lastSlotKey = nil },
  socketHint = { itemId = nil, extraItemId = nil, slotId = nil, bagIndicators = {}, slotIndicators = {}, lastBagKey = nil, lastSlotKey = nil },
  lastBagKey = nil,
  watcher = { lastKey = nil, elapsed = 0 },
  bagReadyWatcher = { frame = nil, elapsed = 0 },
  socketShowHandled = false,
  isHandlingSocketShow = false,
  bagRefreshPending = false,
  enchantBagRefreshPending = false,
  bagPrimeDone = false,
  socketShowRetries = 0,
}

local bagEventFrame
local IsUIVisible
local function AreBagFramesVisible()
  if WSGH.UI and WSGH.UI.BagAdapters and WSGH.UI.BagAdapters.AreBagFramesVisible then
    return WSGH.UI.BagAdapters.AreBagFramesVisible()
  end
  if not NUM_CONTAINER_FRAMES then return false end
  for i = 1, NUM_CONTAINER_FRAMES do
    local frame = _G["ContainerFrame" .. i]
    if frame and frame:IsShown() then
      return true
    end
  end
  return false
end

local function EnsureBagEventFrame()
  if bagEventFrame then return end
  bagEventFrame = CreateFrame("Frame")
  bagEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
  bagEventFrame:RegisterEvent("BAG_UPDATE")
  bagEventFrame:SetScript("OnEvent", function()
    if not (HighlightState.bagRefreshPending or HighlightState.enchantBagRefreshPending) then return end
    if not IsUIVisible() then return end
    HighlightState.bagRefreshPending = false
    HighlightState.enchantBagRefreshPending = false
    WSGH.UI.Highlight.Refresh()
  end)
end

local function EnsureBagFrameShowHooks()
  if not (WSGH.UI and WSGH.UI.BagAdapters and WSGH.UI.BagAdapters.EnsureBagFrameShowHooks) then
    return
  end
  WSGH.UI.BagAdapters.EnsureBagFrameShowHooks(function()
    if not (HighlightState.bagRefreshPending or HighlightState.enchantBagRefreshPending) then return end
    if not IsUIVisible() then return end
    HighlightState.bagRefreshPending = false
    HighlightState.enchantBagRefreshPending = false
    WSGH.UI.Highlight.Refresh()
  end)
end

IsUIVisible = function()
  return WSGH and WSGH.UI and WSGH.UI.frame and WSGH.UI.frame:IsShown()
end

local function HandleSocketFrameShow(frame)
  if HighlightState.isHandlingSocketShow then return end
  if not IsUIVisible() then return end
  HighlightState.isHandlingSocketShow = true
  -- Map the socketing item to an equipped slot and pick the first non-OK task for it.
  local slotId = HighlightState.activeSlotId
  if not slotId then
    local socketingSlot = frame and frame.socketingSlot or nil
    if socketingSlot and socketingSlot > 0 then
      slotId = socketingSlot
    end
  end
  local link = frame.itemLink
  local itemId = link and select(2, GetItemInfoInstant(link)) or nil
  if not slotId and itemId and itemId ~= 0 then
    for _, slotMeta in ipairs(WSGH.Const.SLOT_ORDER) do
      if GetInventoryItemID and GetInventoryItemID("player", slotMeta.slotId) == itemId then
        slotId = slotMeta.slotId
        break
      end
    end
  end
  if not slotId then
    if HighlightState.socketShowRetries < 2 and C_Timer and C_Timer.After then
      HighlightState.socketShowRetries = HighlightState.socketShowRetries + 1
      C_Timer.After(0, function()
        HighlightState.socketShowHandled = false
        HandleSocketFrameShow(frame)
      end)
    end
    HighlightState.isHandlingSocketShow = false
    return
  end

  HighlightState.socketShowHandled = true
  HighlightState.socketShowRetries = 0
  HighlightState.target = nil
  HighlightState.targets = nil
  HighlightState.activeSlotId = slotId
  HighlightState.watcher.lastKey = nil
  HighlightState.watcher.elapsed = 0
  WSGH.UI.Highlight.ClearAll()

  local picked = false
  local diff = WSGH.State and WSGH.State.diff
  if diff and diff.rows and slotId then
    for _, row in ipairs(diff.rows) do
      if tonumber(row.slotId) == tonumber(slotId) then
        local targets = {}
        for _, task in ipairs(row.socketTasks or {}) do
          if task.status ~= WSGH.Const.STATUS_OK then
            targets[#targets + 1] = {
              gemId = task.wantGemId,
              socketIndex = task.socketIndex,
              slotId = task.slotId,
            }
          end
        end
        if #targets > 0 then
          WSGH.UI.Highlight.SetTargets(targets)
          picked = true
        end
        break
      end
    end
  end

  if not picked then
    HighlightState.targets = nil
    HighlightState.target = nil
    WSGH.UI.Highlight.Refresh()
  end

  HighlightState.isHandlingSocketShow = false
end

local function HandleSocketApply()
  if not IsUIVisible() then return end
  if not (WSGH and WSGH.UI and WSGH.UI.RebuildAndRefresh) then return end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, WSGH.UI.RebuildAndRefresh)
  else
    WSGH.UI.RebuildAndRefresh()
  end
end

local function HandleSocketHide()
  if not IsUIVisible() then return end
  HighlightState.target = nil
  HighlightState.targets = nil
  HighlightState.watcher.lastKey = nil
  HighlightState.watcher.elapsed = 0
  HighlightState.socketShowHandled = false
  HighlightState.socketShowRetries = 0
  WSGH.UI.Highlight.ClearAll()
end

local function HandleSocketShow(frame)
  if not IsUIVisible() then return end
  HandleSocketFrameShow(frame)
  if WSGH.UI and WSGH.UI.SocketHooks and WSGH.UI.SocketHooks.EnableWatcher then
    WSGH.UI.SocketHooks.EnableWatcher()
  end
end

local function CreateIndicator(parent)
  if not parent then return nil end
  if parent.WSGHIndicator then return parent.WSGHIndicator end

  local indicator = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  indicator:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)

  -- Constrain to center so socket edges remain visible.
  local w = parent.GetWidth and parent:GetWidth() or 0
  local h = parent.GetHeight and parent:GetHeight() or 0
  local size = math.max(18, math.min(w, h) * 0.7)
  indicator:SetSize(size, size)
  indicator:SetPoint("CENTER")

  local bg = indicator:CreateTexture(nil, "OVERLAY")
  bg:SetAllPoints(indicator)
  bg:SetColorTexture(0, 0, 0, 0)
  indicator.bg = bg

  local label = indicator:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  label:SetPoint("TOPLEFT", indicator, "TOPLEFT", -8, 8)
  label:SetTextColor(1, 1, 1, 1)
  local font, _, flags = label:GetFont()
  if font then
    label:SetFont(font, 18, flags or "OUTLINE")
  end
  indicator.label = label

  local labelBg = indicator:CreateTexture(nil, "ARTWORK")
  labelBg:SetColorTexture(0, 0, 0, 0.85)
  labelBg:SetPoint("TOPLEFT", label, "TOPLEFT", -2, 2)
  labelBg:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 2, -2)
  indicator.labelBg = labelBg

  local status = indicator:CreateTexture(nil, "OVERLAY")
  status:SetSize(14, 14)
  status:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 4, -4)
  status:Hide()
  indicator.status = status

  indicator:Hide()
  parent.WSGHIndicator = indicator
  return indicator
end

local autoCastShineId = 0

local function GetHighlightStyle()
  if WSGH.Util and WSGH.Util.GetHighlightStyle then
    return WSGH.Util.GetHighlightStyle()
  end
  return WSGH.Const and WSGH.Const.HIGHLIGHT and WSGH.Const.HIGHLIGHT.style or "label"
end

local function EnsureAutoCastShine(parent)
  if not parent then return nil end
  if parent.WSGHAutoCastShine then return parent.WSGHAutoCastShine end
  if not CreateFrame or not AutoCastShine_AutoCastStart then return nil end
  local parentName = parent.GetName and parent:GetName() or nil
  local name
  if parentName and parentName ~= "" then
    name = parentName .. "WSGHAutoCastShine"
  else
    autoCastShineId = autoCastShineId + 1
    name = "WSGHAutoCastShine" .. tostring(autoCastShineId)
  end
  local shine = _G[name]
  if not shine then
    shine = CreateFrame("Frame", name, parent, "AutoCastShineTemplate")
  else
    shine:SetParent(parent)
  end
  shine:SetAllPoints(parent)
  parent.WSGHAutoCastShine = shine
  return shine
end

local function ApplyHighlightStyle(parent, context)
  if not parent then return end
  if context ~= "bag" and context ~= "slot" then return end
  local style = GetHighlightStyle()
  if style == "glow" then
    if ActionButton_ShowOverlayGlow then
      ActionButton_ShowOverlayGlow(parent)
    end
  elseif style == "autocast" then
    local shine = EnsureAutoCastShine(parent)
    if shine and AutoCastShine_AutoCastStart then
      AutoCastShine_AutoCastStart(shine)
    elseif ActionButton_ShowOverlayGlow then
      ActionButton_ShowOverlayGlow(parent)
    end
  end
end

local function ClearHighlightStyle(parent)
  if not parent then return end
  if ActionButton_HideOverlayGlow then
    ActionButton_HideOverlayGlow(parent)
  end
  local shine = parent.WSGHAutoCastShine
  if shine and AutoCastShine_AutoCastStop then
    AutoCastShine_AutoCastStop(shine)
  end
end

local function ConfigureIndicatorForBag(indicator)
  if not indicator or not indicator.label then return end
  indicator.label:ClearAllPoints()
  indicator.label:SetPoint("CENTER", indicator, "CENTER", 0, 0)
  indicator.label:SetJustifyH("CENTER")
  if indicator.labelBg then
    indicator.labelBg:ClearAllPoints()
    indicator.labelBg:SetPoint("TOPLEFT", indicator.label, "TOPLEFT", -4, 4)
    indicator.labelBg:SetPoint("BOTTOMRIGHT", indicator.label, "BOTTOMRIGHT", 4, -4)
    indicator.labelBg:Show()
  end
end

local function ClearIndicator(parent)
  if parent and parent.WSGHIndicator then
    local indicator = parent.WSGHIndicator
    ClearHighlightStyle(parent)
    indicator:Hide()
    indicator.label:SetText("")
    if indicator.bg then indicator.bg:SetColorTexture(0, 0, 0, 0) end
    if indicator.status then indicator.status:Hide() end
  end
end

local function ClearAllIndicators(collection)
  for btn in pairs(collection) do
    ClearIndicator(btn)
    collection[btn] = nil
  end
end

local function ItemIdFromValue(value)
  if type(value) == "number" then
    if value ~= 0 then return value end
    return nil
  end
  if type(value) == "string" then
    local itemId = select(2, GetItemInfoInstant(value))
    if itemId and itemId ~= 0 then return itemId end
  end
  return nil
end

local function CurrentSocketGemId(socketIndex)
  if not socketIndex then return nil end

  if C_ItemSocketInfo and C_ItemSocketInfo.GetSocketInfo then
    local info = C_ItemSocketInfo.GetSocketInfo(socketIndex)
    if info then
      local id = ItemIdFromValue(info.gemItemID) or ItemIdFromValue(info.itemID) or ItemIdFromValue(info.gemItemLink)
      if id then return id end
    end
  end

  if C_ItemSocketInfo and C_ItemSocketInfo.GetSocketGem then
    local link = C_ItemSocketInfo.GetSocketGem(socketIndex)
    local id = ItemIdFromValue(link)
    if id then return id end
  end

  if GetExistingSocketLink then
    local link = GetExistingSocketLink(socketIndex)
    local id = ItemIdFromValue(link)
    if id then return id end
  end

  if GetExistingSocketInfo then
    local _, name, link = GetExistingSocketInfo(socketIndex)
    local id = ItemIdFromValue(link) or ItemIdFromValue(name)
    if id then return id end
  end

  if GetNewSocketLink then
    local link = GetNewSocketLink(socketIndex)
    local id = ItemIdFromValue(link)
    if id then return id end
  end

  if GetNewSocketInfo then
    local _, name, link = GetNewSocketInfo(socketIndex)
    local id = ItemIdFromValue(link) or ItemIdFromValue(name)
    if id then return id end
  end

  if GetSocketGem then
    local link = GetSocketGem(socketIndex)
    local id = ItemIdFromValue(link)
    if id then return id end
  end

  if GetItemGem and ItemSocketingFrame and ItemSocketingFrame.itemLink then
    local name, link = GetItemGem(ItemSocketingFrame.itemLink, socketIndex)
    local id = ItemIdFromValue(link) or ItemIdFromValue(name)
    if id then return id end
  end

  return nil
end

local function ShouldUseCurrentSocket(slotId)
  if not slotId then return true end
  local invLink = GetInventoryItemLink and GetInventoryItemLink("player", slotId) or nil
  local openLink = ItemSocketingFrame and ItemSocketingFrame.itemLink or nil
  if invLink and openLink then
    local invId = select(2, GetItemInfoInstant(invLink))
    local openId = select(2, GetItemInfoInstant(openLink))
    if invId and openId and invId ~= openId then
      return false
    end
  end
  return true
end

local function LiveSocketStatus(wantGemId, slotId, socketIndex)
  if not wantGemId or wantGemId == 0 then return nil end
  if not ShouldUseCurrentSocket(slotId) then return nil end
  local current = CurrentSocketGemId(socketIndex)
  if not current then return nil end
  return (current == wantGemId) and WSGH.Const.STATUS_OK or WSGH.Const.STATUS_WRONG
end

local function AreAllTargetsResolved(targets, slotId)
  if not targets or #targets == 0 then return true end
  for _, t in ipairs(targets) do
    local status = LiveSocketStatus(tonumber(t.gemId), slotId, tonumber(t.socketIndex))
    if status ~= WSGH.Const.STATUS_OK then
      return false
    end
  end
  return true
end

local function AreAllSocketTasksResolved(tasksByIndex)
  if not tasksByIndex then return false end
  local hasTask = false
  for _, task in pairs(tasksByIndex) do
    hasTask = true
    if task.status ~= WSGH.Const.STATUS_OK then
      return false
    end
  end
  return hasTask
end

local function UpdateSocketStatus(indicator, task, socketIndex, slotId)
  if not (indicator and indicator.status) then return end
  indicator.status:Hide()
  indicator.label:SetText(tostring(socketIndex or ""))
  indicator.label:Show()

  if not task then return end

  local wantGemId = tonumber(task.wantGemId) or 0
  local status = task.status
  if status == WSGH.Const.STATUS_OK and wantGemId ~= 0 then
    indicator.label:SetText("")
    indicator.status:SetTexture(WSGH.Const.ICON_READY)
    indicator.status:ClearAllPoints()
    indicator.status:SetPoint("CENTER", indicator, "CENTER", 0, 0)
    indicator.status:SetSize(26, 26)
    indicator.status:Show()
  elseif wantGemId ~= 0 then
    indicator.status:SetTexture(WSGH.Const.ICON_NOTREADY)
    indicator.status:ClearAllPoints()
    local anchorParent = indicator:GetParent() or indicator
    indicator.status:SetPoint("BOTTOMRIGHT", anchorParent, "BOTTOMRIGHT", 2, -2)
    indicator.status:SetSize(16, 16)
    indicator.status:Show()
  end
end

local function BuildVisibleBagButtonIndex()
  if WSGH.UI and WSGH.UI.BagAdapters and WSGH.UI.BagAdapters.BuildVisibleBagButtonIndex then
    return WSGH.UI.BagAdapters.BuildVisibleBagButtonIndex()
  end
  return {}
end

local function FindSocketButton(socketIndex)
  if not socketIndex then return nil end
  -- Retail uses ItemSocketingFrame.SocketingContainer.Socket1/Socket2/...
  local container = ItemSocketingFrame and ItemSocketingFrame.SocketingContainer
  if container then
    local sock = container["Socket" .. socketIndex]
    -- Populate legacy globals so skins expecting ItemSocketingSocket# don't explode.
    local legacyKey = "ItemSocketingSocket" .. socketIndex
    if sock and not _G[legacyKey] then
      _G[legacyKey] = sock
    end
    if sock then return sock end
  end
  -- Legacy fallback
  local btn = _G["ItemSocketingSocket" .. socketIndex]
  if btn then return btn end
  return nil
end

local function BuildSocketTasksByIndex(slotId)
  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.rows then return {}, 0 end
  for _, row in ipairs(diff.rows) do
    if tonumber(row.slotId) == tonumber(slotId) then
      local tasks = {}
      for _, task in ipairs(row.socketTasks or {}) do
        local idx = tonumber(task.socketIndex) or 0
        if idx > 0 then
          tasks[idx] = task
        end
      end
      local count = tonumber(row.socketCount) or 0
      return tasks, count
    end
  end
  return {}, 0
end

local function BuildTargetsForSlot(slotId)
  local targets = {}
  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.rows then return targets end
  for _, row in ipairs(diff.rows) do
    if tonumber(row.slotId) == tonumber(slotId) then
      for _, task in ipairs(row.socketTasks or {}) do
        if task.status ~= WSGH.Const.STATUS_OK then
          targets[#targets + 1] = {
            gemId = task.wantGemId,
            socketIndex = task.socketIndex,
            slotId = task.slotId,
          }
        end
      end
      return targets
    end
  end
  return targets
end

local function FormatSocketIndexList(indexMap)
  local indices = {}
  for idx in pairs(indexMap) do
    indices[#indices + 1] = idx
  end
  table.sort(indices)
  local parts = {}
  for _, idx in ipairs(indices) do
    parts[#parts + 1] = tostring(idx)
  end
  return table.concat(parts, ",")
end

local function ClearEnchantIndicators()
  ClearAllIndicators(HighlightState.enchant.bagIndicators)
  ClearAllIndicators(HighlightState.enchant.slotIndicators)
  HighlightState.enchant.lastBagKey = nil
  HighlightState.enchant.lastSlotKey = nil
end

local function ClearSocketHintIndicators()
  ClearAllIndicators(HighlightState.socketHint.bagIndicators)
  ClearAllIndicators(HighlightState.socketHint.slotIndicators)
  HighlightState.socketHint.lastBagKey = nil
  HighlightState.socketHint.lastSlotKey = nil
end

local CHARACTER_SLOT_BUTTONS = {
  [1] = { "CharacterHeadSlot" },
  [2] = { "CharacterNeckSlot" },
  [3] = { "CharacterShoulderSlot" },
  [5] = { "CharacterChestSlot" },
  [6] = { "CharacterWaistSlot" },
  [7] = { "CharacterLegsSlot" },
  [8] = { "CharacterFeetSlot" },
  [9] = { "CharacterWristSlot" },
  [10] = { "CharacterHandsSlot" },
  [11] = { "CharacterFinger0Slot", "CharacterFinger1Slot" },
  [12] = { "CharacterFinger1Slot", "CharacterFinger0Slot" },
  [13] = { "CharacterTrinket0Slot", "CharacterTrinket1Slot" },
  [14] = { "CharacterTrinket1Slot", "CharacterTrinket0Slot" },
  [15] = { "CharacterBackSlot" },
  [16] = { "CharacterMainHandSlot" },
  [17] = { "CharacterSecondaryHandSlot", "CharacterOffHandSlot" },
}

local function GetCharacterSlotButton(slotId)
  local names = CHARACTER_SLOT_BUTTONS[slotId]
  if not names then return nil end
  for _, name in ipairs(names) do
    local btn = _G[name]
    if btn then return btn end
  end
  return nil
end

local function HasPendingEnchantTask(slotId, spellId)
  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.rows then return false end
  for _, row in ipairs(diff.rows) do
    if tonumber(row.slotId) == tonumber(slotId) then
      for _, task in ipairs(row.enchantTasks or {}) do
        if task.status ~= WSGH.Const.STATUS_OK then
          if not spellId or tonumber(task.wantEnchantId) == tonumber(spellId) then
            return true
          end
        end
      end
      return false
    end
  end
  return false
end

local function RefreshEnchantHighlights()
  local enchant = HighlightState.enchant
  if not enchant then return end

  local slotId = tonumber(enchant.slotId) or nil
  local spellId = tonumber(enchant.spellId) or nil
  local itemId = tonumber(enchant.itemId) or nil

  if not slotId and not spellId and not itemId then
    if next(enchant.bagIndicators) or next(enchant.slotIndicators) then
      ClearEnchantIndicators()
    end
    return
  end

  if slotId and not HasPendingEnchantTask(slotId, spellId) then
    enchant.spellId = nil
    enchant.itemId = nil
    enchant.slotId = nil
    ClearEnchantIndicators()
    return
  end

  local slotButton = slotId and GetCharacterSlotButton(slotId) or nil
  if slotButton then
    local slotKey = (slotButton.GetName and slotButton:GetName()) or tostring(slotButton)
    if enchant.lastSlotKey ~= slotKey then
      ClearAllIndicators(enchant.slotIndicators)
      enchant.lastSlotKey = slotKey
      local indicator = CreateIndicator(slotButton)
      if indicator then
        indicator.label:SetText("E")
        indicator:Show()
        ApplyHighlightStyle(slotButton, "slot")
        enchant.slotIndicators[slotButton] = true
      end
    end
  else
    if next(enchant.slotIndicators) then
      ClearAllIndicators(enchant.slotIndicators)
      enchant.lastSlotKey = nil
    end
  end

  if itemId and itemId ~= 0 and AreBagFramesVisible() then
    local bagButtonIndex = BuildVisibleBagButtonIndex()
    local bagButtons = bagButtonIndex[itemId] or {}
    local bagKeyParts = {}
    for _, btn in ipairs(bagButtons) do
      local btnName = (btn and btn.GetName and btn:GetName()) or tostring(btn)
      bagKeyParts[#bagKeyParts + 1] = btnName
    end
    table.sort(bagKeyParts)
    local bagKey = (#bagKeyParts > 0) and table.concat(bagKeyParts, "|") or "none"

    if enchant.lastBagKey ~= bagKey then
      ClearAllIndicators(enchant.bagIndicators)
      enchant.lastBagKey = bagKey
      for _, btn in ipairs(bagButtons) do
        local indicator = CreateIndicator(btn)
        if indicator then
          ConfigureIndicatorForBag(indicator)
          indicator.label:SetText("E")
          indicator:Show()
          ApplyHighlightStyle(btn, "bag")
          enchant.bagIndicators[btn] = true
        end
      end
    end
  else
    if next(enchant.bagIndicators) then
      ClearAllIndicators(enchant.bagIndicators)
      enchant.lastBagKey = nil
    end
  end
end

local function HasPendingSocketHint(slotId)
  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.rows then return false end
  for _, row in ipairs(diff.rows) do
    if tonumber(row.slotId) == tonumber(slotId) then
      return row.socketHintText ~= nil
    end
  end
  return false
end

local function RefreshSocketHintHighlights()
  local hint = HighlightState.socketHint
  if not hint then return end

  local slotId = tonumber(hint.slotId) or nil
  local itemId = tonumber(hint.itemId) or 0
  local extraItemId = tonumber(hint.extraItemId) or 0

  if not slotId and itemId == 0 and extraItemId == 0 then
    if next(hint.bagIndicators) or next(hint.slotIndicators) then
      ClearSocketHintIndicators()
    end
    return
  end

  if slotId and not HasPendingSocketHint(slotId) then
    hint.itemId = nil
    hint.extraItemId = nil
    hint.slotId = nil
    ClearSocketHintIndicators()
    return
  end

  local slotButton = slotId and GetCharacterSlotButton(slotId) or nil
  if slotButton then
    local slotKey = (slotButton.GetName and slotButton:GetName()) or tostring(slotButton)
    if hint.lastSlotKey ~= slotKey then
      ClearAllIndicators(hint.slotIndicators)
      hint.lastSlotKey = slotKey
      local indicator = CreateIndicator(slotButton)
      if indicator then
        indicator.label:SetText("S")
        indicator:Show()
        ApplyHighlightStyle(slotButton, "slot")
        hint.slotIndicators[slotButton] = true
      end
    end
  else
    if next(hint.slotIndicators) then
      ClearAllIndicators(hint.slotIndicators)
      hint.lastSlotKey = nil
    end
  end

  if AreBagFramesVisible() then
    local itemIds = {}
    if itemId ~= 0 then itemIds[itemId] = true end
    if extraItemId ~= 0 then itemIds[extraItemId] = true end

    local bagButtonIndex = BuildVisibleBagButtonIndex()
    local bagButtons = {}
    for id in pairs(itemIds) do
      for _, btn in ipairs(bagButtonIndex[id] or {}) do
        bagButtons[btn] = true
      end
    end

    local bagKeyParts = {}
    for btn in pairs(bagButtons) do
      local btnName = (btn and btn.GetName and btn:GetName()) or tostring(btn)
      bagKeyParts[#bagKeyParts + 1] = btnName
    end
    table.sort(bagKeyParts)
    local bagKey = (#bagKeyParts > 0) and table.concat(bagKeyParts, "|") or "none"

    if hint.lastBagKey ~= bagKey then
      ClearAllIndicators(hint.bagIndicators)
      hint.lastBagKey = bagKey
      for btn in pairs(bagButtons) do
        local indicator = CreateIndicator(btn)
        if indicator then
          ConfigureIndicatorForBag(indicator)
          indicator.label:SetText("S")
          indicator:Show()
          ApplyHighlightStyle(btn, "bag")
          hint.bagIndicators[btn] = true
        end
      end
    end
  else
    if next(hint.bagIndicators) then
      ClearAllIndicators(hint.bagIndicators)
      hint.lastBagKey = nil
    end
  end
end

WSGH.Debug = WSGH.Debug or {}
function WSGH.Debug.DebugSocketState(slotId)
  slotId = tonumber(slotId) or 0
  if slotId == 0 then
    WSGH.Util.Print("DebugSocketState: provide slotId.")
    return
  end
  local tasks, count = BuildSocketTasksByIndex(slotId)
  local numSockets = GetNumSockets and GetNumSockets() or count
  numSockets = math.max(numSockets, count or 0)
  WSGH.Util.Print(("Socket debug for slot %d (count %d):"):format(slotId, numSockets))
  for i = 1, numSockets do
    local want = tasks[i] and tasks[i].wantGemId or nil
    local current = CurrentSocketGemId(i)
    local status = tasks[i] and tasks[i].status or "nil"
    local info = C_ItemSocketInfo and C_ItemSocketInfo.GetSocketInfo and C_ItemSocketInfo.GetSocketInfo(i) or nil
    local existingLink = GetExistingSocketLink and GetExistingSocketLink(i) or nil
    local existingId = existingLink and select(2, GetItemInfoInstant(existingLink)) or nil
    WSGH.Util.Print(("[%d] want=%s current=%s status=%s info.itemID=%s info.gemItemID=%s existing=%s"):format(
      i,
      want or "nil",
      current or "nil",
      status,
      info and info.itemID or "nil",
      info and info.gemItemID or "nil",
      existingId or "nil"
    ))
  end
end

WSGH.UI.Highlight.DebugSocketState = WSGH.Debug.DebugSocketState

function WSGH.UI.Highlight.SetTarget(gemId, socketIndex, slotId)
  if gemId and socketIndex then
    HighlightState.target = { gemId = gemId, socketIndex = socketIndex, slotId = slotId }
    HighlightState.targets = nil
    HighlightState.activeSlotId = tonumber(slotId) or nil
  else
    HighlightState.target = nil
    HighlightState.targets = nil
    HighlightState.activeSlotId = nil
  end
  WSGH.UI.Highlight.Refresh()
end

function WSGH.UI.Highlight.SetTargets(targets)
  if type(targets) == "table" and #targets > 0 then
    HighlightState.targets = targets
    HighlightState.target = nil
    HighlightState.activeSlotId = tonumber(targets[1].slotId) or nil
  else
    HighlightState.targets = nil
    HighlightState.target = nil
    HighlightState.activeSlotId = nil
  end
  WSGH.UI.Highlight.Refresh()
end

function WSGH.UI.Highlight.SetTargetsForSlot(slotId)
  local targets = BuildTargetsForSlot(slotId)
  HighlightState.activeSlotId = tonumber(slotId) or nil
  if #targets > 0 then
    WSGH.UI.Highlight.SetTargets(targets)
  else
    HighlightState.targets = nil
    HighlightState.target = nil
    WSGH.UI.Highlight.Refresh()
  end
end

-- Watcher to detect socket changes while the socket UI is open and resync highlights/diff.
local function ShouldSocketWatcherRun()
  local t = HighlightState.target
  if not t then return false end
  if not ItemSocketingFrame or not ItemSocketingFrame:IsShown() then return false end
  if not IsUIVisible() then return false end
  return true
end

local function SocketWatcherUpdate(elapsed)
  HighlightState.watcher.elapsed = (HighlightState.watcher.elapsed or 0) + elapsed
  if HighlightState.watcher.elapsed < 0.2 then return end
  HighlightState.watcher.elapsed = 0

  local t = HighlightState.target
  if not t then return end
  local numSockets = GetNumSockets and GetNumSockets() or 0
  local parts = { tostring(t.slotId or 0) }
  for i = 1, numSockets do
    parts[#parts + 1] = tostring(CurrentSocketGemId(i) or 0)
  end
  local key = table.concat(parts, ":")
  if key ~= HighlightState.watcher.lastKey then
    HighlightState.watcher.lastKey = key
    if WSGH and WSGH.UI and WSGH.UI.RebuildAndRefresh then
      WSGH.UI.RebuildAndRefresh()
    else
      WSGH.UI.Highlight.Refresh()
    end
  end
end

local function EnsureBagReadyWatcher()
  if HighlightState.bagReadyWatcher.frame then return end
  local f = CreateFrame("Frame")
  HighlightState.bagReadyWatcher.frame = f
  f:SetScript("OnUpdate", function(_, elapsed)
    if not (HighlightState.bagRefreshPending or HighlightState.enchantBagRefreshPending) then
      f:Hide()
      return
    end
    if not IsUIVisible() then
      f:Hide()
      return
    end
    HighlightState.bagReadyWatcher.elapsed = (HighlightState.bagReadyWatcher.elapsed or 0) + elapsed
    if HighlightState.bagReadyWatcher.elapsed < 0.1 then return end
    HighlightState.bagReadyWatcher.elapsed = 0

    if not AreBagFramesVisible() then return end
    local adapters = WSGH.UI and WSGH.UI.BagAdapters or nil
    local index = adapters and adapters.BuildVisibleBagButtonIndex and adapters.BuildVisibleBagButtonIndex() or {}
    if next(index) then
      HighlightState.bagRefreshPending = false
      HighlightState.enchantBagRefreshPending = false
      WSGH.UI.Highlight.Refresh()
      f:Hide()
    end
  end)
end

function WSGH.UI.Highlight.InitializeHooks()
  if WSGH.UI and WSGH.UI.SocketHooks and WSGH.UI.SocketHooks.Initialize then
    WSGH.UI.SocketHooks.Initialize({
      OnApply = HandleSocketApply,
      OnHide = HandleSocketHide,
      OnShow = HandleSocketShow,
      ShouldWatch = ShouldSocketWatcherRun,
      OnWatcherUpdate = SocketWatcherUpdate,
    })
  end
  if ItemSocketingFrame and ItemSocketingFrame:IsShown() and not HighlightState.socketShowHandled then
    HandleSocketFrameShow(ItemSocketingFrame)
    if WSGH.UI and WSGH.UI.SocketHooks and WSGH.UI.SocketHooks.EnableWatcher then
      WSGH.UI.SocketHooks.EnableWatcher()
    end
  end
end

function WSGH.UI.Highlight.RequestBagRefresh()
  local adapters = WSGH.UI and WSGH.UI.BagAdapters or nil
  if AreBagFramesVisible() and IsUIVisible() then
    local arkVisible = adapters and adapters.IsArkInventoryVisible and adapters.IsArkInventoryVisible()
    if not arkVisible then
      WSGH.UI.Highlight.Refresh()
      return
    end
    local index = adapters and adapters.BuildVisibleBagButtonIndex and adapters.BuildVisibleBagButtonIndex() or {}
    if next(index) then
      WSGH.UI.Highlight.Refresh()
      return
    end
  end
  HighlightState.bagRefreshPending = true
  EnsureBagEventFrame()
  EnsureBagFrameShowHooks()
  EnsureBagReadyWatcher()
  if HighlightState.bagReadyWatcher.frame then
    HighlightState.bagReadyWatcher.elapsed = 0
    HighlightState.bagReadyWatcher.frame:Show()
  end
end

function WSGH.UI.Highlight.RequestEnchantBagRefresh()
  local adapters = WSGH.UI and WSGH.UI.BagAdapters or nil
  if AreBagFramesVisible() and IsUIVisible() then
    local arkVisible = adapters and adapters.IsArkInventoryVisible and adapters.IsArkInventoryVisible()
    if not arkVisible then
      WSGH.UI.Highlight.Refresh()
      return
    end
    local index = adapters and adapters.BuildVisibleBagButtonIndex and adapters.BuildVisibleBagButtonIndex() or {}
    if next(index) then
      WSGH.UI.Highlight.Refresh()
      return
    end
  end
  HighlightState.enchantBagRefreshPending = true
  EnsureBagEventFrame()
  EnsureBagFrameShowHooks()
  EnsureBagReadyWatcher()
  if HighlightState.bagReadyWatcher.frame then
    HighlightState.bagReadyWatcher.elapsed = 0
    HighlightState.bagReadyWatcher.frame:Show()
  end
end

function WSGH.UI.Highlight.PrimeBags()
  if HighlightState.bagPrimeDone then return end
  local ark = _G.ArkInventory
  if not ark then return end
  if AreBagFramesVisible() then
    HighlightState.bagPrimeDone = true
    return
  end

  HighlightState.bagPrimeDone = true
  local opened = false
  if OpenAllBags then
    opened = pcall(OpenAllBags)
  elseif ToggleAllBags then
    opened = pcall(ToggleAllBags)
  end

  if opened and CloseAllBags and C_Timer and C_Timer.After then
    C_Timer.After(0.2, function()
      if not IsUIVisible() then return end
      if AreBagFramesVisible() then
        pcall(CloseAllBags)
      end
    end)
  end
end

function WSGH.UI.Highlight.Refresh()
  if not IsUIVisible() then
    WSGH.UI.Highlight.ClearAll()
    return
  end
  WSGH.UI.Highlight.InitializeHooks()
  if AreBagFramesVisible() then
    local adapters = WSGH.UI and WSGH.UI.BagAdapters or nil
    local arkVisible = adapters and adapters.IsArkInventoryVisible and adapters.IsArkInventoryVisible()
    if not arkVisible then
      HighlightState.bagRefreshPending = false
      HighlightState.enchantBagRefreshPending = false
    else
      local index = adapters and adapters.BuildVisibleBagButtonIndex and adapters.BuildVisibleBagButtonIndex() or {}
      if next(index) then
        HighlightState.bagRefreshPending = false
        HighlightState.enchantBagRefreshPending = false
      end
    end
  end
  ClearAllIndicators(HighlightState.socketIndicators)
  local targets = HighlightState.targets
  local slotId = HighlightState.activeSlotId
  if HighlightState.activeSlotId then
    local activeTargets = BuildTargetsForSlot(HighlightState.activeSlotId)
    if #activeTargets > 0 then
      targets = activeTargets
      HighlightState.targets = activeTargets
      HighlightState.target = nil
    end
  end
  if not targets and HighlightState.target then
    targets = { HighlightState.target }
    slotId = HighlightState.target.slotId
  end

  if targets and #targets > 0 then
    local normalizedTargets = {}
    for _, t in ipairs(targets) do
      normalizedTargets[#normalizedTargets + 1] = {
        gemId = tonumber(t.gemId),
        socketIndex = tonumber(t.socketIndex),
        slotId = tonumber(t.slotId),
      }
    end
    HighlightState.targets = normalizedTargets
    HighlightState.target = nil
    targets = normalizedTargets
    if not slotId then
      slotId = targets[1] and targets[1].slotId or nil
    end
  end

  targets = targets or {}
  if not slotId then
    RefreshEnchantHighlights()
    RefreshSocketHintHighlights()
    return
  end
  local tasksByIndex, rowSocketCount = BuildSocketTasksByIndex(slotId)
  local numSockets = GetNumSockets and GetNumSockets() or 0
  numSockets = math.max(numSockets, rowSocketCount or 0)

  local socketingOpen = ItemSocketingFrame and ItemSocketingFrame:IsShown()
  if socketingOpen and AreAllSocketTasksResolved(tasksByIndex) then
    HighlightState.targets = nil
    HighlightState.target = nil
    targets = {}
    if next(HighlightState.bagIndicators) then
      ClearAllIndicators(HighlightState.bagIndicators)
    end
    HighlightState.lastBagKey = nil
  end
  if socketingOpen and #targets > 0 and AreAllTargetsResolved(targets, slotId) then
    HighlightState.targets = nil
    HighlightState.target = nil
    targets = {}
    if next(HighlightState.bagIndicators) then
      ClearAllIndicators(HighlightState.bagIndicators)
    end
    HighlightState.lastBagKey = nil
  end
  local showBagHighlights = socketingOpen and (#targets > 0) and not AreAllTargetsResolved(targets, slotId)
  if not showBagHighlights then
    if next(HighlightState.bagIndicators) then
      ClearAllIndicators(HighlightState.bagIndicators)
    end
    HighlightState.lastBagKey = nil
  else
    local bagButtonIndex = BuildVisibleBagButtonIndex()
    local bagTargetsByButton = {}
    for _, t in ipairs(targets) do
      for _, btn in ipairs(bagButtonIndex[t.gemId] or {}) do
        local socketIndexMap = bagTargetsByButton[btn] or {}
        socketIndexMap[t.socketIndex] = true
        bagTargetsByButton[btn] = socketIndexMap
      end
    end

    local bagKeyParts = {}
    for btn, socketIndexMap in pairs(bagTargetsByButton) do
      local btnName = (btn and btn.GetName and btn:GetName()) or tostring(btn)
      bagKeyParts[#bagKeyParts + 1] = btnName .. ":" .. FormatSocketIndexList(socketIndexMap)
    end
    table.sort(bagKeyParts)
    local bagKey = (#bagKeyParts > 0) and table.concat(bagKeyParts, "|") or "none"

    if HighlightState.lastBagKey ~= bagKey then
      ClearAllIndicators(HighlightState.bagIndicators)
      HighlightState.lastBagKey = bagKey
      for btn, socketIndexMap in pairs(bagTargetsByButton) do
        local indicator = CreateIndicator(btn)
        if indicator then
          ConfigureIndicatorForBag(indicator)
          indicator.label:SetText(FormatSocketIndexList(socketIndexMap))
          indicator:Show()
          ApplyHighlightStyle(btn, "bag")
          HighlightState.bagIndicators[btn] = true
        end
      end
    end
  end

  local targetsBySocketIndex = {}
  for _, t in ipairs(targets) do
    targetsBySocketIndex[t.socketIndex] = t
  end

  for i = 1, numSockets do
    local socketBtn = FindSocketButton(i)
    if socketBtn then
      local indicator = CreateIndicator(socketBtn)
      if indicator then
        indicator.label:SetText(tostring(i))
        local task = tasksByIndex[i]
        local target = targetsBySocketIndex[i]
        if not task and target and target.gemId then
          task = { wantGemId = target.gemId, status = WSGH.Const.STATUS_EMPTY }
        end
        UpdateSocketStatus(indicator, task, i, slotId)
        if indicator.bg then
          -- Avoid stacking/tinting: keep the backdrop fully transparent every render.
          indicator.bg:SetColorTexture(0, 0, 0, 0)
        end
        indicator:Show()
        HighlightState.socketIndicators[socketBtn] = true
      end
    end
  end

  RefreshEnchantHighlights()
  RefreshSocketHintHighlights()
end

function WSGH.UI.Highlight.UpdateFromState()
  if not IsUIVisible() then
    WSGH.UI.Highlight.ClearAll()
    return
  end
  -- If the socketing frame is open and we already have a target, keep showing that target
  -- to avoid retargeting to another slot mid-socketing. Diff data is refreshed elsewhere.
  local socketingOpen = ItemSocketingFrame and ItemSocketingFrame:IsShown()
  if socketingOpen and (HighlightState.target or HighlightState.targets) then
    WSGH.UI.Highlight.Refresh()
    return
  end
  if socketingOpen and HighlightState.activeSlotId then
    WSGH.UI.Highlight.Refresh()
    return
  end

  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.tasks then
    WSGH.UI.Highlight.SetTarget(nil, nil)
    return
  end
  for _, t in ipairs(diff.tasks) do
    if t.status and t.status ~= WSGH.Const.STATUS_OK and t.wantGemId and t.socketIndex then
      WSGH.UI.Highlight.SetTarget(tonumber(t.wantGemId), tonumber(t.socketIndex), tonumber(t.slotId))
      return
    end
  end
  WSGH.UI.Highlight.SetTarget(nil, nil)
end

function WSGH.UI.Highlight.SetEnchantTarget(spellId, itemId, slotId)
  local spell = tonumber(spellId) or 0
  local item = tonumber(itemId) or 0
  local slot = tonumber(slotId) or 0
  HighlightState.enchant.spellId = (spell ~= 0) and spell or nil
  HighlightState.enchant.itemId = (item ~= 0) and item or nil
  HighlightState.enchant.slotId = (slot ~= 0) and slot or nil
  ClearEnchantIndicators()
  WSGH.UI.Highlight.Refresh()
end

function WSGH.UI.Highlight.SetSocketHintTarget(itemId, slotId, extraItemId)
  local item = tonumber(itemId) or 0
  local extra = tonumber(extraItemId) or 0
  local slot = tonumber(slotId) or 0
  HighlightState.socketHint.itemId = (item ~= 0) and item or nil
  HighlightState.socketHint.extraItemId = (extra ~= 0) and extra or nil
  HighlightState.socketHint.slotId = (slot ~= 0) and slot or nil
  ClearSocketHintIndicators()
  WSGH.UI.Highlight.Refresh()
end

function WSGH.UI.Highlight.ClearAll()
  HighlightState.target = nil
  HighlightState.targets = nil
  HighlightState.activeSlotId = nil
  HighlightState.lastBagKey = nil
  ClearAllIndicators(HighlightState.bagIndicators)
  ClearAllIndicators(HighlightState.socketIndicators)
  if HighlightState.enchant then
    HighlightState.enchant.spellId = nil
    HighlightState.enchant.itemId = nil
    HighlightState.enchant.slotId = nil
    ClearEnchantIndicators()
  end
  if HighlightState.socketHint then
    HighlightState.socketHint.itemId = nil
    HighlightState.socketHint.extraItemId = nil
    HighlightState.socketHint.slotId = nil
    ClearSocketHintIndicators()
  end
end

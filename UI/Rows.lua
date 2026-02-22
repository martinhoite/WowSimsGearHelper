local WSGH = _G.WowSimsGearHelper
WSGH.UI = WSGH.UI or {}
WSGH.UI.Rows = WSGH.UI.Rows or {}

local function GetItemNameAndIcon(itemId)
  if not itemId or itemId == 0 then return nil, nil end
  local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
  return name, icon
end

local function GetEnchantIcon(spellId)
  if not spellId or spellId == 0 then return nil end
  local _, _, icon = GetSpellInfo(spellId)
  return icon
end

local function GetGemIcon(gemId)
  if not gemId or gemId == 0 then return nil end
  local _, icon = GetItemNameAndIcon(gemId)
  return icon
end

local function StatusIcon(status)
  if status == WSGH.Const.STATUS_OK then return WSGH.Const.ICON_READY end
  if status == WSGH.Const.STATUS_MISSING then return WSGH.Const.ICON_PURCHASE end
  return WSGH.Const.ICON_NOTREADY
end

local function ShowTooltip(frame, itemLinkOrId)
  if not itemLinkOrId then return end
  GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
  if type(itemLinkOrId) == "string" then
    GameTooltip:SetHyperlink(itemLinkOrId)
  else
    GameTooltip:SetItemByID(itemLinkOrId)
  end
  GameTooltip:Show()
end

local function HasItemInBags(itemId)
  if not itemId or itemId == 0 then return false end
  local bagIndex = WSGH.Scan.GetBagIndex and WSGH.Scan.GetBagIndex() or {}
  local locs = bagIndex[itemId]
  return locs and #locs > 0
end

local function SocketHintDescription(rowData)
  if not rowData then return "Add missing socket." end
  local hintItemId = tonumber(rowData.socketHintItemId) or 0
  local extraId = tonumber(rowData.socketHintExtraItemId) or 0
  local extraCount = tonumber(rowData.socketHintExtraItemCount) or 0

  local desc
  if hintItemId ~= 0 then
    local name = GetItemInfo(hintItemId) or ("item " .. hintItemId)
    desc = ("Add missing socket: %s."):format(name)
  else
    desc = "Add missing socket: Blacksmithing."
  end
  if extraId ~= 0 and extraCount > 0 then
    local extraName = GetItemInfo(extraId) or ("item " .. extraId)
    desc = desc .. (" Requires %d x %s."):format(extraCount, extraName)
  end
  return desc
end

function WSGH.UI.Rows.Create(parent)
  local rowHeight = WSGH.Const.UI.rowHeight
  local socketSize = WSGH.Const.UI.socketSize
  local socketGap = WSGH.Const.UI.socketGap
  local enchantSize = 18
  local enchantGap = 4
  local maxEnchantIcons = 2

  local rowFrame = CreateFrame("Button", nil, parent, "BackdropTemplate")
  rowFrame:SetHeight(rowHeight)
  rowFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  rowFrame:SetBackdropColor(0, 0, 0, 0.18)
  rowFrame:SetBackdropBorderColor(0, 0, 0, 0.35)

  rowFrame.action = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
  rowFrame.action:SetSize(80, 22)
  rowFrame.action:SetPoint("RIGHT", -10, 0)
  rowFrame.action:SetText("Socket")

  rowFrame.icon = rowFrame:CreateTexture(nil, "ARTWORK")
  rowFrame.icon:SetSize(28, 28)
  rowFrame.icon:SetPoint("LEFT", 6, 0)

  rowFrame.title = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  rowFrame.title:SetPoint("LEFT", rowFrame.icon, "RIGHT", 8, 6)
  rowFrame.title:SetJustifyH("LEFT")

  rowFrame.subtitle = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  rowFrame.subtitle:SetPoint("LEFT", rowFrame.icon, "RIGHT", 8, -8)
  rowFrame.subtitle:SetJustifyH("LEFT")

  rowFrame.socketsContainer = CreateFrame("Frame", nil, rowFrame)
  rowFrame.socketsContainer:SetPoint("RIGHT", rowFrame.action, "LEFT", -8, 0)
  rowFrame.socketsContainer:SetHeight(socketSize)

  rowFrame.enchantContainer = CreateFrame("Frame", nil, rowFrame)
  rowFrame.enchantContainer:SetPoint("RIGHT", rowFrame.socketsContainer, "LEFT", -8, 0)
  rowFrame.enchantContainer:SetHeight(enchantSize)

  rowFrame.enchantFrames = {}
  for i = 1, maxEnchantIcons do
    local ef = CreateFrame("Frame", nil, rowFrame.enchantContainer)
    ef:SetSize(enchantSize, enchantSize)
    if i == 1 then
      ef:SetPoint("LEFT", rowFrame.enchantContainer, "LEFT", 0, 0)
    else
      ef:SetPoint("LEFT", rowFrame.enchantFrames[i - 1], "RIGHT", enchantGap, 0)
    end

    ef.icon = ef:CreateTexture(nil, "ARTWORK")
    ef.icon:SetAllPoints()
    ef.icon:SetTexture(WSGH.Const.ICON_ENCHANT)

    ef.status = ef:CreateTexture(nil, "OVERLAY")
    ef.status:SetSize(14, 14)
    ef.status:SetPoint("BOTTOMRIGHT", 4, -4)

    rowFrame.enchantFrames[i] = ef
  end

  rowFrame.enchantContainer:SetWidth((enchantSize * maxEnchantIcons) + (enchantGap * (maxEnchantIcons - 1)))

  rowFrame.socketFrames = {}
  for i = 1, WSGH.Const.MAX_SOCKETS_RENDER do
    local socketFrame = CreateFrame("Frame", nil, rowFrame)
    socketFrame:SetSize(socketSize, socketSize)

    if i == 1 then
      socketFrame:SetPoint("LEFT", rowFrame.socketsContainer, "LEFT", 0, 0)
    else
      socketFrame:SetPoint("LEFT", rowFrame.socketFrames[i - 1], "RIGHT", socketGap, 0)
    end

    socketFrame.icon = socketFrame:CreateTexture(nil, "ARTWORK")
    socketFrame.icon:SetAllPoints()
    socketFrame.icon:SetTexture(WSGH.Const.ICON_EMPTY_SOCKET)

    socketFrame.badge = socketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    socketFrame.badge:SetPoint("TOPLEFT", -4, 4)
    socketFrame.badge:SetText(tostring(i))

    socketFrame.status = socketFrame:CreateTexture(nil, "OVERLAY")
    socketFrame.status:SetSize(14, 14)
    socketFrame.status:SetPoint("BOTTOMRIGHT", 4, -4)

    rowFrame.socketFrames[i] = socketFrame
  end

  rowFrame.socketsContainer:SetWidth((socketSize * WSGH.Const.MAX_SOCKETS_RENDER) + (socketGap * (WSGH.Const.MAX_SOCKETS_RENDER - 1)))
  rowFrame.title:SetPoint("RIGHT", rowFrame.enchantContainer, "LEFT", -12, 6)
  rowFrame.subtitle:SetPoint("RIGHT", rowFrame.enchantContainer, "LEFT", -12, -8)

  rowFrame.noSockets = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  rowFrame.noSockets:SetPoint("LEFT", rowFrame.socketsContainer, "LEFT", 0, 0)
  rowFrame.noSockets:SetPoint("RIGHT", rowFrame.socketsContainer, "RIGHT", 0, 0)
  rowFrame.noSockets:SetJustifyH("CENTER")
  rowFrame.noSockets:SetText("No sockets")

  return rowFrame
end

  

function WSGH.UI.Rows.SetRow(rowFrame, rowData, onAction)
  rowFrame.rowData = rowData

  local expectedItemId = tonumber(rowData.expectedItemId) or 0
  local equippedItemId = tonumber(rowData.equippedItemId) or 0
  local socketCount = tonumber(rowData.socketCount) or 0
  if socketCount == 0 and rowData.socketTasks then
    for _, task in ipairs(rowData.socketTasks) do
      local idx = tonumber(task.socketIndex) or 0
      if idx > socketCount then socketCount = idx end
    end
  end
  socketCount = math.max(0, math.min(socketCount, WSGH.Const.MAX_SOCKETS_RENDER))
  if rowData.rowStatus == "WRONG_ITEM" then
    socketCount = 0 -- hide socket tasks until the correct item is equipped
  end

  local displayItemId = expectedItemId ~= 0 and expectedItemId or equippedItemId
  local name, icon = GetItemNameAndIcon(displayItemId)
  local equippedName = GetItemNameAndIcon(equippedItemId)

  rowFrame.icon:SetTexture(icon or WSGH.Const.ICON_QUESTION)
  if rowData.rowStatus == "WRONG_ITEM" and name then
    rowFrame.title:SetText("|cffff4040" .. name .. "|r")
  else
    rowFrame.title:SetText(name or (displayItemId ~= 0 and ("Item " .. displayItemId) or rowData.slotKey))
  end
  rowFrame.icon:SetScript("OnEnter", function(self)
    if rowData.equippedLink then
      ShowTooltip(self, rowData.equippedLink)
      return
    end
    local expected = expectedItemId ~= 0 and expectedItemId or displayItemId
    if expected and expected ~= 0 then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetItemByID(expected)
      if rowData.rowStatus == "WRONG_ITEM" and equippedItemId ~= expected then
        GameTooltip:AddLine("Currently equipped: " .. (equippedName or ("item " .. tostring(equippedItemId))), 1, 0.25, 0.25)
      end
      if rowData.rowStatus == "WRONG_ITEM" and not rowData.hasExpectedInBags then
        GameTooltip:AddLine("Not in bags", 1, 0.25, 0.25)
      end
      GameTooltip:Show()
    end
  end)
  rowFrame.icon:SetScript("OnLeave", GameTooltip_Hide)

  local hasSocketWork = false
  local hasEnchantWork = false
  local hasTinkerWork = false
  local hasManualOnlyEnchant = false
  for _, task in ipairs(rowData.socketTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      hasSocketWork = true
      break
    end
  end
  for _, task in ipairs(rowData.enchantTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      if task.type == "APPLY_TINKER" then
        hasTinkerWork = true
      else
        hasEnchantWork = true
      end
      if task.manualOnly then
        hasManualOnlyEnchant = true
      end
    end
  end

  local statusText = rowData.rowStatus
  if rowData.rowStatus == "WRONG_ITEM" then
    if rowData.hasExpectedInBags then
      statusText = "Expected item ready to equip"
    else
      statusText = "Expected item not in bags"
    end
  elseif rowData.rowStatus == "OK" then
    statusText = "OK"
  else
    local needsEnchantOrTinker = hasEnchantWork or hasTinkerWork
    if hasSocketWork and needsEnchantOrTinker then
      if hasTinkerWork and not hasEnchantWork then
        statusText = "Needs gems and tinker"
      elseif hasEnchantWork and not hasTinkerWork then
        statusText = "Needs gems and enchant"
      else
        statusText = "Needs gems and enchant/tinker"
      end
    elseif hasTinkerWork and not hasEnchantWork then
      statusText = "Needs tinker"
    elseif hasEnchantWork then
      statusText = "Needs enchant"
    elseif hasSocketWork then
      statusText = "Needs gems"
    else
      statusText = "Needs work"
    end
  end
  if rowData.socketHintText then
    statusText = SocketHintDescription(rowData)
  end

  rowFrame.subtitle:SetText(statusText)

  local enchantDisplays = rowData.enchantDisplays or {}
  local showEnchantCount = math.min(#enchantDisplays, #rowFrame.enchantFrames)
  local enchantSize = 18
  local enchantGap = 4
  local enchantWidth = showEnchantCount > 0 and ((showEnchantCount * enchantSize) + (enchantGap * (showEnchantCount - 1))) or enchantSize
  rowFrame.enchantContainer:SetWidth(enchantWidth)
  if showEnchantCount == 0 then
    rowFrame.enchantContainer:Hide()
  else
    rowFrame.enchantContainer:Show()
  end
  for i, ef in ipairs(rowFrame.enchantFrames) do
    local data = enchantDisplays[i]
    if data then
      ef:Show()
      ef.icon:SetTexture(data.icon or GetEnchantIcon(data.spellId) or WSGH.Const.ICON_ENCHANT)
      if data.status then
        ef.status:SetTexture(StatusIcon(data.status))
        ef.status:Show()
      else
        ef.status:SetTexture(nil)
        ef.status:Hide()
      end
      ef:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if data.unsupported then
          GameTooltip:SetText(("Enchant not handled (%s) - please contact addon author"):format(tostring(data.spellId or "")), 1, 0.2, 0.2, true)
          GameTooltip:Show()
          return
        end
        local hasSpellInfo = data.spellId and GetSpellInfo(data.spellId)
        if data.itemId and data.itemId ~= 0 then
          GameTooltip:SetItemByID(data.itemId)
        elseif hasSpellInfo then
          GameTooltip:SetSpellByID(data.spellId)
        else
          local fallbackName = data.name or (data.isTinker and ("Tinker " .. tostring(data.spellId or "")) or ("Enchant " .. tostring(data.spellId or "")))
          GameTooltip:SetText(fallbackName)
        end

        if data.isTinker then
          GameTooltip:AddLine("Apply via Engineering (open the profession window to use the tinker).", 1, 0.8, 0.2, true)
        elseif data.manualOnly then
          GameTooltip:AddLine("Apply manually (no purchasable scroll).", 1, 0.8, 0.2, true)
        elseif data.itemSource == "consumable" then
          GameTooltip:AddLine("Apply using consumable.", 1, 1, 1, true)
        end
        GameTooltip:Show()
      end)
      ef:SetScript("OnLeave", GameTooltip_Hide)
    else
      ef:Hide()
      ef:SetScript("OnEnter", nil)
      ef:SetScript("OnLeave", nil)
    end
  end

  local tasksBySocket = {}
  local maxTaskIndex = 0
  for _, task in ipairs(rowData.socketTasks or {}) do
    tasksBySocket[task.socketIndex] = task
    if task.socketIndex > maxTaskIndex then
      maxTaskIndex = task.socketIndex
    end
  end

  if maxTaskIndex > 0 then
    socketCount = maxTaskIndex
  end

  local containerWidth
  if socketCount > 0 then
    containerWidth = (socketCount * WSGH.Const.UI.socketSize) + (WSGH.Const.UI.socketGap * (socketCount - 1))
  else
    containerWidth = math.max(rowFrame.noSockets:GetStringWidth() + 12, WSGH.Const.UI.socketSize * 1.5)
  end
  rowFrame.socketsContainer:SetWidth(containerWidth)

  for i = 1, WSGH.Const.MAX_SOCKETS_RENDER do
    local socketFrame = rowFrame.socketFrames[i]
    local task = tasksBySocket[i]

    if i <= socketCount and task then
      local gemIcon = GetGemIcon(task.wantGemId)
      socketFrame.icon:SetTexture(gemIcon or WSGH.Const.ICON_EMPTY_SOCKET)
      if task.status then
        socketFrame.status:SetTexture(StatusIcon(task.status))
      else
        socketFrame.status:SetTexture(nil)
      end
      socketFrame:Show()
      socketFrame:SetScript("OnEnter", function(self)
        ShowTooltip(self, task.wantGemId)
      end)
      socketFrame:SetScript("OnLeave", GameTooltip_Hide)
    elseif i <= socketCount then
      socketFrame.icon:SetTexture(WSGH.Const.ICON_EMPTY_SOCKET)
      socketFrame.status:SetTexture(nil)
      socketFrame:SetScript("OnEnter", nil)
      socketFrame:SetScript("OnLeave", nil)
      socketFrame:Show()
    else
      socketFrame:Hide()
    end
  end

  if rowData.rowStatus == "WRONG_ITEM" then
    rowFrame.noSockets:Hide()
  else
    rowFrame.noSockets:SetShown(socketCount == 0)
  end

  rowFrame.action:SetScript("OnClick", function()
    if onAction then onAction(rowData) end
  end)

  if rowData.socketHintText then
    rowFrame.action:SetText("Add socket")
    local hintItemId = tonumber(rowData.socketHintItemId) or 0
    local extraItemId = tonumber(rowData.socketHintExtraItemId) or 0
    local missingHintItem = hintItemId ~= 0 and not HasItemInBags(hintItemId)
    local missingExtraItem = extraItemId ~= 0 and not HasItemInBags(extraItemId)
    if missingHintItem or missingExtraItem then
      rowFrame.action:SetEnabled(false)
      rowFrame.action:SetText("Purchase")
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Purchase required items first.")
        GameTooltip:Show()
      end)
      rowFrame.action:SetScript("OnLeave", GameTooltip_Hide)
    else
      rowFrame.action:SetEnabled(true)
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(SocketHintDescription(rowData), nil, nil, nil, nil, true)
        GameTooltip:Show()
      end)
      rowFrame.action:SetScript("OnLeave", GameTooltip_Hide)
    end
  elseif rowData.rowStatus == "OK" then
    rowFrame.action:SetEnabled(false)
    rowFrame.action:SetText("Done")
  elseif rowData.rowStatus == "WRONG_ITEM" then
    if rowData.hasExpectedInBags then
      rowFrame.action:SetEnabled(true)
      rowFrame.action:SetText("Equip")
    else
      rowFrame.action:SetEnabled(false)
      rowFrame.action:SetText("Missing")
    end
  else
    local hasBlockingTask = false -- e.g., gem/vellum missing from bags; user must acquire it first.
    for _, task in ipairs(rowData.socketTasks or {}) do
      if task.status == WSGH.Const.STATUS_MISSING then
        hasBlockingTask = true
        break
      end
    end
    if not hasBlockingTask then
      for _, task in ipairs(rowData.enchantTasks or {}) do
        if task.status == WSGH.Const.STATUS_MISSING then
          hasBlockingTask = true
          break
        end
      end
    end
    if hasBlockingTask then
      rowFrame.action:SetEnabled(false)
      rowFrame.action:SetText("Purchase")
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Purchase required items first.")
        GameTooltip:Show()
      end)
      rowFrame.action:SetScript("OnLeave", GameTooltip_Hide)
    elseif (hasEnchantWork or hasTinkerWork) and not hasSocketWork then
      rowFrame.action:SetEnabled(true)
      if hasTinkerWork and not hasEnchantWork then
        rowFrame.action:SetText("Tinker")
      elseif hasEnchantWork and not hasTinkerWork then
        rowFrame.action:SetText("Enchant")
      else
        rowFrame.action:SetText("Enchant/Tinker")
      end
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if hasManualOnlyEnchant then
          GameTooltip:SetText("Apply the expected enchant/tinker manually (no scroll available).")
        else
          if hasTinkerWork and not hasEnchantWork then
            GameTooltip:SetText("Apply the expected tinker manually.")
          else
            GameTooltip:SetText("Apply the expected enchant using a vellum.")
          end
        end
        GameTooltip:Show()
      end)
      rowFrame.action:SetScript("OnLeave", GameTooltip_Hide)
    else
      rowFrame.action:SetEnabled(true)
      rowFrame.action:SetText("Socket")
      rowFrame.action:SetScript("OnEnter", nil)
      rowFrame.action:SetScript("OnLeave", nil)
    end
  end
end

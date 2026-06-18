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

local function SetActionButtonReforgeStyle(button, enabled)
  if not button then return end

  if enabled then
    if button.GetFontString and button:GetFontString() then
      button:GetFontString():SetTextColor(1, 1, 1, 1)
    end
    return
  end

  if button.GetFontString and button:GetFontString() then
    button:GetFontString():SetTextColor(1, 0.82, 0, 1)
  end
end

local function CountRowRemainingTasks(rowData)
  if not rowData then return 0 end
  local count = 0
  if rowData.rowStatus == "WRONG_ITEM" then
    count = count + 1
  end
  if rowData.socketHintText then
    count = count + 1
  end
  for _, task in ipairs(rowData.socketTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then count = count + 1 end
  end
  for _, task in ipairs(rowData.deferredSocketTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then count = count + 1 end
  end
  for _, task in ipairs(rowData.enchantTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then count = count + 1 end
  end
  for _, task in ipairs(rowData.upgradeTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then count = count + 1 end
  end
  for _, task in ipairs(rowData.reforgeTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then count = count + 1 end
  end
  return count
end

local function RowBadgeIcon(rowData)
  local warnings = rowData and rowData.importWarnings or {}
  if type(warnings) ~= "table" then warnings = {} end
  if #warnings > 0 then return WSGH.Const.ICON_QUESTION end
  if not rowData then return WSGH.Const.ICON_NOTREADY end
  if CountRowRemainingTasks(rowData) > 0 then return WSGH.Const.ICON_NOTREADY end
  return WSGH.Const.ICON_READY
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

local function ShowEquippedTooltip(frame, slotId, fallbackLink)
  slotId = tonumber(slotId) or 0
  if slotId ~= 0 then
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    local hasItem = GameTooltip:SetInventoryItem("player", slotId)
    if hasItem then
      GameTooltip:Show()
      return
    end
  end

  ShowTooltip(frame, fallbackLink)
end

local function HasItemInBags(itemId)
  if not itemId or itemId == 0 then return false end
  local bagIndex = WSGH.Scan.GetBagIndex and WSGH.Scan.GetBagIndex() or {}
  local locs = bagIndex[itemId]
  return locs and #locs > 0
end

local function TrackPendingItemInfo(itemId)
  itemId = tonumber(itemId) or 0
  if itemId == 0 then return end
  WSGH.UI.pendingItemInfoRefreshIds = WSGH.UI.pendingItemInfoRefreshIds or {}
  WSGH.UI.pendingItemInfoRefreshIds[itemId] = true
end

local function SocketHintDescription(rowData)
  if not rowData then return "Add missing socket." end
  local hintItemId = tonumber(rowData.socketHintItemId) or 0

  local desc
  if hintItemId ~= 0 then
    local name = GetItemInfo(hintItemId)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
      TrackPendingItemInfo(hintItemId)
      C_Item.RequestLoadItemDataByID(hintItemId)
    end
    if tonumber(rowData.slotId) == 6 then
      desc = "Add socket: Belt buckle."
    elseif name then
      desc = ("Add missing socket: %s."):format(name)
    else
      desc = rowData.socketHintText or ("Add missing socket: item " .. hintItemId .. ".")
    end
  else
    desc = rowData.socketHintText or "Add socket: Blacksmithing."
  end
  return desc
end

local function GetItemName(itemId, fallbackPrefix)
  itemId = tonumber(itemId) or 0
  if itemId == 0 then return nil end
  local name, link = GetItemInfo(itemId)
  if not link and not name and C_Item and C_Item.RequestLoadItemDataByID then
    TrackPendingItemInfo(itemId)
    C_Item.RequestLoadItemDataByID(itemId)
  end
  return link or name or ((fallbackPrefix or "item") .. " " .. tostring(itemId))
end

local function GetSpellName(spellId, fallbackPrefix)
  spellId = tonumber(spellId) or 0
  if spellId == 0 then return nil end
  local name = GetSpellInfo(spellId)
  return name or ((fallbackPrefix or "spell") .. " " .. tostring(spellId))
end

local function GetColoredItemName(itemId, fallbackPrefix)
  itemId = tonumber(itemId) or 0
  if itemId == 0 then return nil end

  local name, _, quality = GetItemInfo(itemId)
  if not name and C_Item and C_Item.RequestLoadItemDataByID then
    TrackPendingItemInfo(itemId)
    C_Item.RequestLoadItemDataByID(itemId)
  end
  if not name then
    return (fallbackPrefix or "item") .. " " .. tostring(itemId)
  end

  local qualityColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[tonumber(quality) or 0]
  if qualityColor and qualityColor.hex then
    return qualityColor.hex .. name .. "|r"
  end
  return name
end

local function BuildCurrentGemLines(gemIds)
  if type(gemIds) ~= "table" or #gemIds == 0 then
    return nil
  end

  local lines = {}
  for i, gemIdValue in ipairs(gemIds) do
    local gemId = tonumber(gemIdValue) or 0
    if gemId ~= 0 then
      local gemName = GetColoredItemName(gemId, "item") or ("item " .. tostring(gemId))
      lines[#lines + 1] = ("Socket %d: %s"):format(i, gemName)
    end
  end

  if #lines == 0 then
    return nil
  end

  return lines
end

local badgeCategoryColor = { 1, 0.82, 0 }
local badgeTextColor = { 1, 1, 1 }
local badgeTooltipTitleFont = nil
local previousBadgeTooltipTitleFontObject = nil

local function GetBadgeTooltipTitleFont()
  if badgeTooltipTitleFont then return badgeTooltipTitleFont end
  if not CreateFont then return GameFontNormal end

  badgeTooltipTitleFont = CreateFont("WowSimsGearHelperBadgeTooltipTitleFont")
  local baseFontObject = GameFontNormalLarge or GameFontNormal
  if badgeTooltipTitleFont.CopyFontObject and baseFontObject then
    badgeTooltipTitleFont:CopyFontObject(baseFontObject)
  end

  local font, size, flags
  if baseFontObject and baseFontObject.GetFont then
    font, size, flags = baseFontObject:GetFont()
  end
  if font and badgeTooltipTitleFont.SetFont then
    local targetSize = math.max(13, math.floor(((tonumber(size) or 16) * 0.75) + 0.5))
    badgeTooltipTitleFont:SetFont(font, targetSize, flags)
  end
  return badgeTooltipTitleFont
end

local function SetBadgeTooltipTitle(text, r, g, b)
  GameTooltip:SetText(text, r, g, b)
  if GameTooltipTextLeft1 and GameTooltipTextLeft1.SetFontObject then
    if GameTooltipTextLeft1.GetFontObject then
      previousBadgeTooltipTitleFontObject = GameTooltipTextLeft1:GetFontObject()
    end
    local titleFont = GetBadgeTooltipTitleFont()
    if titleFont then
      GameTooltipTextLeft1:SetFontObject(titleFont)
    end
  end
end

local function HideBadgeTooltip()
  if GameTooltipTextLeft1 and GameTooltipTextLeft1.SetFontObject then
    if previousBadgeTooltipTitleFontObject then
      GameTooltipTextLeft1:SetFontObject(previousBadgeTooltipTitleFontObject)
      previousBadgeTooltipTitleFontObject = nil
    elseif GameTooltipHeaderText then
      GameTooltipTextLeft1:SetFontObject(GameTooltipHeaderText)
    elseif GameTooltipText then
      GameTooltipTextLeft1:SetFontObject(GameTooltipText)
    end
  end
  GameTooltip_Hide()
end

local function AddBadgeCategory(state, title, lines)
  if type(lines) ~= "table" or #lines == 0 then return false end
  state = state or {}
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(title, badgeCategoryColor[1], badgeCategoryColor[2], badgeCategoryColor[3])
  for _, line in ipairs(lines) do
    local text = type(line) == "table" and line.text or tostring(line)
    local r = type(line) == "table" and line.r or badgeTextColor[1]
    local g = type(line) == "table" and line.g or badgeTextColor[2]
    local b = type(line) == "table" and line.b or badgeTextColor[3]
    GameTooltip:AddLine("  - " .. tostring(text), r or badgeTextColor[1], g or badgeTextColor[2], b or badgeTextColor[3], true)
  end
  state.hasCategory = true
  return true
end

local function AddImportWarningTooltipLines(rowData, tooltipState)
  local warnings = rowData and rowData.importWarnings or {}
  if type(warnings) ~= "table" then warnings = {} end
  if #warnings == 0 then return false end

  local lines = {}
  for _, warningCode in ipairs(warnings) do
    if warningCode == "MISSING_GEMS_OMITTED" then
      lines[#lines + 1] = "Import has no gem specified."
    elseif warningCode == "MISSING_EXTRA_SOCKET_GEM_OMITTED" then
      lines[#lines + 1] = "Import omitted a gem for the extra socket."
    elseif warningCode == "MISSING_ENCHANT_OMITTED" then
      lines[#lines + 1] = "Import has no enchant specified."
    elseif warningCode == "MISSING_UPGRADE_OMITTED" then
      local currentUpgradeLevel = tonumber(rowData.equippedUpgradeLevel) or 0
      local currentUpgradeMax = tonumber(rowData.equippedUpgradeMax) or 0
      lines[#lines + 1] = ("Import has %d/%d upgrades, intentional?"):format(currentUpgradeLevel, currentUpgradeMax)
    elseif warningCode == "UPGRADE_STEP_NOT_MAX_POTENTIAL" or warningCode == "UPGRADE_STEP_ZERO_POTENTIAL" then
      local currentUpgradeMax = tonumber(rowData.equippedUpgradeMax) or 0
      local expectedUpgradeStep = tonumber(rowData.expectedUpgradeStep) or 0
      lines[#lines + 1] = ("Import has %d/%d upgrades, intentional?"):format(expectedUpgradeStep, currentUpgradeMax)
    else
      lines[#lines + 1] = "Import warning: " .. tostring(warningCode)
    end
  end
  return AddBadgeCategory(tooltipState, "Import warnings", lines)
end

local function AddPurchaseTooltipLines(rowData, tooltipState)
  local shopping = WSGH.UI and WSGH.UI.Shopping or nil
  if not (shopping and shopping.GetRowPurchaseNeeds) then return false end

  local needs = shopping.GetRowPurchaseNeeds(rowData)
  if type(needs) ~= "table" or #needs == 0 then return false end

  local lines = {}
  for _, need in ipairs(needs) do
    local itemName = GetItemName(need.itemId, "item") or ("item " .. tostring(need.itemId))
    local count = tonumber(need.count) or 0
    local bought = tonumber(need.bought) or 0
    local text = itemName
    if count > 1 then
      text = text .. " x" .. tostring(count)
    end
    if bought > 0 then
      text = text .. (" (bought %d/%d)"):format(bought, count)
    end
    lines[#lines + 1] = text
  end

  return AddBadgeCategory(tooltipState, "Purchases required", lines)
end

local function AddRowTaskTooltipLines(rowData, tooltipState)
  local added = false
  local taskCategories = {}
  local categorySequence = 0

  local function getTaskPriorityRank(taskType)
    if WSGH.Util and WSGH.Util.GetTaskPriorityRank then
      return WSGH.Util.GetTaskPriorityRank(taskType)
    end
    return 999
  end

  local function socketLabel(socketIndex)
    socketIndex = tonumber(socketIndex) or 0
    if socketIndex > 0 then
      return "Socket " .. tostring(socketIndex)
    end
    return "Socket"
  end

  local function sortSockets(sockets)
    table.sort(sockets, function(a, b)
      return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)
  end

  local function addCategory(title, lines)
    if AddBadgeCategory(tooltipState, title, lines) then
      added = true
    end
  end

  local function addTaskCategory(taskType, title, lines)
    if type(lines) ~= "table" or #lines == 0 then return end
    categorySequence = categorySequence + 1
    taskCategories[#taskCategories + 1] = {
      taskType = taskType,
      title = title,
      lines = lines,
      rank = getTaskPriorityRank(taskType),
      sequence = categorySequence,
    }
  end

  local function renderTaskCategories()
    table.sort(taskCategories, function(a, b)
      if a.rank ~= b.rank then
        return a.rank < b.rank
      end
      return a.sequence < b.sequence
    end)

    for _, category in ipairs(taskCategories) do
      addCategory(category.title, category.lines)
    end
  end

  local function addSocketGroup(title, sockets, r, g, b)
    if #sockets == 0 then return end
    sortSockets(sockets)
    local lines = {}
    for _, socketIndex in ipairs(sockets) do
      lines[#lines + 1] = { text = socketLabel(socketIndex), r = r, g = g, b = b }
    end
    addTaskCategory("SOCKET_GEM", title, lines)
  end

  if not rowData then return false end

  if rowData.rowStatus == "WRONG_ITEM" then
    if rowData.hasExpectedInBags then
      addCategory("Item", { "Equip expected item." })
    else
      addCategory("Item", { "Expected item not in bags." })
    end
  end

  if rowData.socketHintText then
    addTaskCategory("ADD_SOCKET", "Add socket", { SocketHintDescription(rowData) })
  end

  local missingGemSockets = {}
  local insertGemSockets = {}
  local deferredGemSockets = {}
  for _, task in ipairs(rowData.socketTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      local socketIndex = tonumber(task.socketIndex) or 0
      if task.status == WSGH.Const.STATUS_MISSING then
        missingGemSockets[#missingGemSockets + 1] = socketIndex
      else
        insertGemSockets[#insertGemSockets + 1] = socketIndex
      end
    end
  end

  for _, task in ipairs(rowData.deferredSocketTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      local socketIndex = tonumber(task.socketIndex) or 0
      deferredGemSockets[#deferredGemSockets + 1] = socketIndex
    end
  end
  addSocketGroup("Missing gems", missingGemSockets)
  addSocketGroup("Insert gems", insertGemSockets)
  if #deferredGemSockets > 0 then
    sortSockets(deferredGemSockets)
    local deferredLines = {}
    for _, socketIndex in ipairs(deferredGemSockets) do
      deferredLines[#deferredLines + 1] = { text = socketLabel(socketIndex) }
    end
    addTaskCategory("ADD_SOCKET", "Add extra socket before gem", deferredLines)
  end

  local enchantLines = {}
  local tinkerLines = {}
  for _, task in ipairs(rowData.enchantTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      local spellName = GetSpellName(task.wantEnchantId, "enchant") or "expected enchant"
      if task.type == "APPLY_TINKER" then
        tinkerLines[#tinkerLines + 1] = "Apply tinker: " .. spellName .. "."
      elseif task.status == WSGH.Const.STATUS_MISSING then
        local itemName = GetItemName(task.wantEnchantItemId, "item") or "required enchant item"
        enchantLines[#enchantLines + 1] = "Missing enchant item: " .. itemName .. "."
      elseif task.manualOnly then
        enchantLines[#enchantLines + 1] = "Apply enchant manually: " .. spellName .. "."
      else
        enchantLines[#enchantLines + 1] = "Apply enchant: " .. spellName .. "."
      end
    end
  end
  addTaskCategory("APPLY_ENCHANT", "Enchanting", enchantLines)
  addTaskCategory("APPLY_TINKER", "Tinkers", tinkerLines)

  local pendingUpgradeCount = 0
  local firstUpgradeTask = nil
  for _, task in ipairs(rowData.upgradeTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      pendingUpgradeCount = pendingUpgradeCount + 1
      if not firstUpgradeTask then firstUpgradeTask = task end
    end
  end
  if pendingUpgradeCount > 0 then
    local currentStep = tonumber(rowData.equippedUpgradeLevel) or tonumber(firstUpgradeTask and firstUpgradeTask.haveUpgradeStep) or 0
    local targetStep = tonumber(firstUpgradeTask and firstUpgradeTask.targetUpgradeStep) or tonumber(rowData.expectedUpgradeStep) or 0
    local maxStep = tonumber(rowData.equippedUpgradeMax) or tonumber(firstUpgradeTask and firstUpgradeTask.upgradeMax) or 0
    if maxStep <= 0 then maxStep = math.max(2, targetStep) end
    addTaskCategory("UPGRADE_ITEM", "Upgrades", { ("Upgrade item: %d/%d -> %d/%d."):format(currentStep, maxStep, targetStep, maxStep) })
  end

  local reforgeLines = {}
  local reforgeLiteIntegration = WSGH.Integrations and WSGH.Integrations.ReforgeLite or nil
  local hasReforgeLite = reforgeLiteIntegration
    and reforgeLiteIntegration.IsAvailable
    and reforgeLiteIntegration.IsAvailable()
  for _, task in ipairs(rowData.reforgeTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      local label = task.wantReforgeText
      local want = tonumber(task.wantReforgeId) or 0
      local have = tonumber(task.haveReforgeId) or 0
      if want == 0 then
        reforgeLines[#reforgeLines + 1] = "Remove current reforge."
      elseif not hasReforgeLite then
        -- Reforge IDs are not useful without ReforgeLite's method data.
      elseif type(label) == "string" and label ~= "" then
        reforgeLines[#reforgeLines + 1] = label .. "."
      elseif have == 0 then
        reforgeLines[#reforgeLines + 1] = ("Apply ReforgeLite reforge %d."):format(want)
      else
        reforgeLines[#reforgeLines + 1] = ("Change reforge %d -> %d."):format(have, want)
      end
    end
  end
  if not hasReforgeLite and rowData.reforgeTasks and #rowData.reforgeTasks > 0 then
    reforgeLines[#reforgeLines + 1] = "ReforgeLite Classic is recommended for this task."
  end
  addTaskCategory("REFORGE_ITEM", "Reforging", reforgeLines)
  renderTaskCategories()

  return added
end

local function ShowRowStatusTooltip(frame, rowData)
  GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
  local icon = RowBadgeIcon(rowData)
  if icon == WSGH.Const.ICON_QUESTION then
    SetBadgeTooltipTitle("Review needed", 1, 0.82, 0.2)
  elseif icon == WSGH.Const.ICON_READY then
    SetBadgeTooltipTitle("No actions remaining", 0.35, 1, 0.35)
    GameTooltip:Show()
    return
  else
    SetBadgeTooltipTitle("Needs work", 1, 0.25, 0.25)
  end

  local tooltipState = {}
  local addedWarnings = AddImportWarningTooltipLines(rowData, tooltipState)
  local addedPurchases = AddPurchaseTooltipLines(rowData, tooltipState)
  local addedTasks = AddRowTaskTooltipLines(rowData, tooltipState)
  if not addedWarnings and not addedPurchases and not addedTasks then
    GameTooltip:AddLine("No remaining actions.", 1, 1, 1, true)
  end
  GameTooltip:Show()
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

  local badgeSize = WSGH.Const.UI.rowStatusBadgeSize
  local badgeOffset = WSGH.Const.UI.rowStatusBadgeOffset or { x = 0, y = 0 }
  rowFrame.statusBadge = CreateFrame("Button", nil, rowFrame)
  rowFrame.statusBadge:SetSize(badgeSize, badgeSize)
  rowFrame.statusBadge:SetPoint("BOTTOMRIGHT", rowFrame.icon, "BOTTOMRIGHT", badgeOffset.x or 0, badgeOffset.y or 0)
  rowFrame.statusBadge:SetFrameLevel((rowFrame:GetFrameLevel() or 0) + 5)
  rowFrame.statusBadge.icon = rowFrame.statusBadge:CreateTexture(nil, "OVERLAY")
  rowFrame.statusBadge.icon:SetAllPoints()

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
  rowFrame.title:SetText(name or (displayItemId ~= 0 and ("Item " .. displayItemId) or rowData.slotKey))
  rowFrame.icon:SetScript("OnEnter", function(self)
    if rowData.equippedLink then
      ShowEquippedTooltip(self, rowData.slotId, rowData.equippedLink)
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
  if rowFrame.statusBadge then
    local badgeIcon = RowBadgeIcon(rowData)
    local badgeSize = WSGH.Const.UI.rowStatusBadgeSize
    if badgeIcon == WSGH.Const.ICON_READY then
      badgeSize = WSGH.Const.UI.rowStatusBadgeCompleteSize or badgeSize
    end
    rowFrame.statusBadge:SetSize(badgeSize, badgeSize)
    rowFrame.statusBadge:SetFrameLevel((rowFrame:GetFrameLevel() or 0) + 5)
    rowFrame.statusBadge.icon:SetTexture(badgeIcon)
    rowFrame.statusBadge:SetScript("OnEnter", function(self)
      ShowRowStatusTooltip(self, rowData)
    end)
    rowFrame.statusBadge:SetScript("OnLeave", HideBadgeTooltip)
    rowFrame.statusBadge:Show()
  end

  local hasSocketWork = false
  local hasEnchantWork = false
  local hasTinkerWork = false
  local hasUpgradeWork = false
  local hasReforgeWork = false
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
    end
  end
  for _, task in ipairs(rowData.upgradeTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      hasUpgradeWork = true
    end
  end
  for _, task in ipairs(rowData.reforgeTasks or {}) do
    if task.status ~= WSGH.Const.STATUS_OK then
      hasReforgeWork = true
    end
  end
  local priority = WSGH.UI and WSGH.UI.GetRowActionPriority and WSGH.UI.GetRowActionPriority(rowData) or nil
  local hasPrioritySocket = priority and priority.hasSocketWork or hasSocketWork
  local hasPriorityAnyEnchant = priority and priority.hasEnchantWork or (hasEnchantWork or hasTinkerWork)
  local hasPriorityUpgrade = priority and priority.hasUpgradeWork or hasUpgradeWork
  local hasPriorityReforge = priority and priority.hasReforgeWork or hasReforgeWork
  local nextPriorityAction = priority and priority.nextAction or nil
  local nextPriorityEnchantTask = priority and priority.nextEnchantTask or nil

  if rowData.rowStatus == "WRONG_ITEM" then
    rowFrame.title:SetTextColor(1, 0.25, 0.25)
  elseif hasUpgradeWork then
    rowFrame.title:SetTextColor(1, 0.62, 0.22)
  elseif hasReforgeWork then
    rowFrame.title:SetTextColor(0.8, 0.62, 1)
  else
    rowFrame.title:SetTextColor(1, 0.82, 0)
  end

  local importWarnings = rowData.importWarnings or {}
  local hasGemOmissionWarning = false
  local hasExtraSocketGemOmissionWarning = false
  local hasEnchantOmissionWarning = false
  local currentEnchantId = tonumber(rowData.currentEnchantId) or 0
  local currentGemCount = tonumber(rowData.currentGemCount) or 0
  local currentGemIds = type(rowData.currentGemIds) == "table" and rowData.currentGemIds or {}
  for _, warningCode in ipairs(importWarnings) do
    if warningCode == "MISSING_GEMS_OMITTED" then
      hasGemOmissionWarning = true
    elseif warningCode == "MISSING_EXTRA_SOCKET_GEM_OMITTED" then
      hasGemOmissionWarning = true
      hasExtraSocketGemOmissionWarning = true
    elseif warningCode == "MISSING_ENCHANT_OMITTED" then
      hasEnchantOmissionWarning = true
    end
  end

  local remainingTaskCount = CountRowRemainingTasks(rowData)
  local statusText
  if remainingTaskCount == 0 then
    statusText = "No tasks left"
  elseif remainingTaskCount == 1 then
    statusText = "1 task left"
  else
    statusText = ("%d tasks left"):format(remainingTaskCount)
  end
  rowFrame.subtitle:SetTextColor(0.5, 0.5, 0.5)
  rowFrame.subtitle:SetText(statusText)

  local enchantDisplays = rowData.enchantDisplays or {}
  local showAmbiguousEnchantPlaceholder = hasEnchantOmissionWarning and #enchantDisplays == 0 and rowData.rowStatus ~= "WRONG_ITEM"
  local showEnchantCount = math.min(#enchantDisplays, #rowFrame.enchantFrames)
  if showAmbiguousEnchantPlaceholder then
    showEnchantCount = math.max(showEnchantCount, 1)
  end
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
          GameTooltip:AddLine("Apply via Engineering.", 1, 0.8, 0.2, true)
        elseif data.manualOnly then
          GameTooltip:AddLine("Apply manually (no purchasable scroll).", 1, 0.8, 0.2, true)
        elseif data.itemSource == "consumable" then
          GameTooltip:AddLine("Apply using consumable.", 1, 1, 1, true)
        end
        GameTooltip:Show()
      end)
      ef:SetScript("OnLeave", GameTooltip_Hide)
    elseif showAmbiguousEnchantPlaceholder and i == 1 then
      ef:Show()
      ef.icon:SetTexture(WSGH.Const.ICON_ENCHANT)
      ef.status:SetTexture(WSGH.Const.ICON_QUESTION)
      ef.status:Show()
      ef:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Import warning", 1, 0.82, 0.2)
        GameTooltip:AddLine("Import has no enchant specified.", 1, 1, 1, true)
        local enchantName = currentEnchantId ~= 0 and GetSpellInfo(currentEnchantId) or nil
        if currentEnchantId ~= 0 then
          if enchantName and enchantName ~= "" then
            GameTooltip:AddLine(("Item currently has enchant: %s"):format(enchantName), 1, 1, 1, true)
          else
            GameTooltip:AddLine("Item currently has an enchant.", 1, 1, 1, true)
          end
        end
        GameTooltip:AddLine("Please ensure this was intentional.", 1, 1, 1, true)
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
  local deferredBySocket = {}
  local maxTaskIndex = 0
  for _, task in ipairs(rowData.socketTasks or {}) do
    tasksBySocket[task.socketIndex] = task
    if task.socketIndex > maxTaskIndex then
      maxTaskIndex = task.socketIndex
    end
  end
  for _, task in ipairs(rowData.deferredSocketTasks or {}) do
    deferredBySocket[task.socketIndex] = task
    if task.socketIndex > maxTaskIndex then
      maxTaskIndex = task.socketIndex
    end
  end

  if maxTaskIndex > 0 then
    socketCount = math.max(socketCount, math.min(maxTaskIndex, WSGH.Const.MAX_SOCKETS_RENDER))
  end

  local physicalSocketCount = tonumber(rowData.physicalSocketCount) or 0
  local likelyMissingBuckleFromImportOmission =
    hasGemOmissionWarning and
    tonumber(rowData.slotId) == 6 and
    not rowData.socketHintText and
    physicalSocketCount > 0
  if likelyMissingBuckleFromImportOmission then
    socketCount = math.max(socketCount, math.min(physicalSocketCount + 1, WSGH.Const.MAX_SOCKETS_RENDER))
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
    local deferredTask = deferredBySocket[i]

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
    elseif i <= socketCount and deferredTask then
      local gemIcon = GetGemIcon(deferredTask.wantGemId)
      socketFrame.icon:SetTexture(gemIcon or WSGH.Const.ICON_EMPTY_SOCKET)
      socketFrame.status:SetTexture(WSGH.Const.ICON_NOTREADY)
      socketFrame:Show()
      socketFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local gemId = tonumber(deferredTask.wantGemId) or 0
        if gemId ~= 0 then
          local gemName = GetItemInfo(gemId) or ("gem " .. tostring(gemId))
          GameTooltip:SetText(("Planned gem: %s"):format(gemName))
        else
          GameTooltip:SetText("Planned gem")
        end
        GameTooltip:AddLine("Socket missing on item. Add the extra socket first, then insert this gem.", 1, 0.2, 0.2, true)
        GameTooltip:Show()
      end)
      socketFrame:SetScript("OnLeave", GameTooltip_Hide)
    elseif i <= socketCount then
      socketFrame.icon:SetTexture(WSGH.Const.ICON_EMPTY_SOCKET)
      if hasGemOmissionWarning then
        socketFrame.status:SetTexture(WSGH.Const.ICON_QUESTION)
        socketFrame:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText("Import warning", 1, 0.82, 0.2)
          GameTooltip:AddLine("Import has no gem specified.", 1, 1, 1, true)
          if hasExtraSocketGemOmissionWarning and tonumber(rowData.slotId) == 6 then
            GameTooltip:AddLine("Import also omitted a gem for the belt buckle socket.", 1, 0.82, 0.2, true)
          end
          if likelyMissingBuckleFromImportOmission and i > physicalSocketCount then
            GameTooltip:AddLine("This may also require a belt buckle for an extra socket.", 1, 0.82, 0.2, true)
          end
          if currentGemCount > 0 then
            local currentGemLines = BuildCurrentGemLines(currentGemIds)
            if currentGemLines then
              GameTooltip:AddLine("Item currently has gems:", 1, 1, 1, true)
              for _, currentGemLine in ipairs(currentGemLines) do
                GameTooltip:AddLine(currentGemLine, 1, 1, 1, true)
              end
            else
              if currentGemCount == 1 then
                GameTooltip:AddLine("Item currently has a socketed gem.", 1, 1, 1, true)
              else
                GameTooltip:AddLine("Item currently has socketed gems.", 1, 1, 1, true)
              end
            end
          end
          GameTooltip:AddLine("Please ensure this was intentional.", 1, 1, 1, true)
          GameTooltip:Show()
        end)
        socketFrame:SetScript("OnLeave", GameTooltip_Hide)
      elseif rowData.socketHintText and i > physicalSocketCount then
        socketFrame.status:SetTexture(WSGH.Const.ICON_QUESTION)
        socketFrame:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText("Socket required", 1, 0.82, 0.2)
          GameTooltip:AddLine(SocketHintDescription(rowData), 1, 1, 1, true)
          GameTooltip:Show()
        end)
        socketFrame:SetScript("OnLeave", GameTooltip_Hide)
      else
        socketFrame.status:SetTexture(nil)
        socketFrame:SetScript("OnEnter", nil)
        socketFrame:SetScript("OnLeave", nil)
      end
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
  SetActionButtonReforgeStyle(rowFrame.action, false)

  if rowData.rowStatus == "OK" then
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
    local nextActionType = nextPriorityAction and nextPriorityAction.type or nil
    local nextActionTask = nextPriorityAction and nextPriorityAction.task or nil
    local isNextActionMissing = false
    if nextActionType == "ADD_SOCKET" then
      local hintItemId = tonumber(rowData.socketHintItemId) or 0
      local extraItemId = tonumber(rowData.socketHintExtraItemId) or 0
      isNextActionMissing = (hintItemId ~= 0 and not HasItemInBags(hintItemId))
        or (extraItemId ~= 0 and not HasItemInBags(extraItemId))
    elseif nextActionTask and nextActionTask.status == WSGH.Const.STATUS_MISSING then
      isNextActionMissing = true
    end

    if isNextActionMissing or (not nextPriorityAction and hasBlockingTask) then
      rowFrame.action:SetEnabled(false)
      rowFrame.action:SetText("Purchase")
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Purchase required items first.")
        GameTooltip:Show()
      end)
      rowFrame.action:SetScript("OnLeave", GameTooltip_Hide)
    elseif nextActionType == "ADD_SOCKET" then
      rowFrame.action:SetEnabled(true)
      rowFrame.action:SetText("Add socket")
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(SocketHintDescription(rowData), nil, nil, nil, nil, true)
        GameTooltip:Show()
      end)
      rowFrame.action:SetScript("OnLeave", GameTooltip_Hide)
    elseif nextActionType == "SOCKET_GEM" or (not nextActionType and hasPrioritySocket) then
      rowFrame.action:SetEnabled(true)
      rowFrame.action:SetText("Socket")
      rowFrame.action:SetScript("OnEnter", nil)
      rowFrame.action:SetScript("OnLeave", nil)
    elseif nextActionType == "APPLY_ENCHANT" or nextActionType == "APPLY_TINKER"
      or (not nextActionType and hasPriorityAnyEnchant and not hasPrioritySocket) then
      rowFrame.action:SetEnabled(true)
      local enchantActionTask = nextActionTask or nextPriorityEnchantTask
      local nextIsTinker = nextActionType == "APPLY_TINKER" or (enchantActionTask and enchantActionTask.type == "APPLY_TINKER")
      local nextManual = enchantActionTask and enchantActionTask.manualOnly == true
      rowFrame.action:SetText(nextIsTinker and "Tinker" or "Enchant")
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if nextIsTinker then
          GameTooltip:SetText("Apply the expected tinker.")
        else
          if nextManual then
            GameTooltip:SetText("Apply the expected enchant manually (no scroll available).")
          else
            GameTooltip:SetText("Apply the expected enchant using a vellum.")
          end
        end
        GameTooltip:Show()
      end)
      rowFrame.action:SetScript("OnLeave", GameTooltip_Hide)
    elseif nextActionType == "UPGRADE_ITEM" or (not nextActionType and hasPriorityUpgrade and not hasPriorityAnyEnchant) then
      rowFrame.action:SetEnabled(true)
      rowFrame.action:SetText("Upgrade")
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local expected = tonumber(rowData.expectedUpgradeStep) or 0
        local firstTask = nextActionTask or (rowData.upgradeTasks and rowData.upgradeTasks[1] or nil)
        local targetStep = firstTask and tonumber(firstTask.targetUpgradeStep) or expected
        local currentStep = tonumber(rowData.equippedUpgradeLevel) or 0
        local maxStep = tonumber(rowData.equippedUpgradeMax) or 0
        if maxStep <= 0 then maxStep = math.max(2, targetStep) end
        GameTooltip:SetText(("Upgrade this (%d/%d -> %d/%d)."):format(currentStep, maxStep, targetStep, maxStep))
        GameTooltip:AddLine("Use the Item Upgrader NPC in your faction shrine.", 1, 0.82, 0.2, true)
        GameTooltip:Show()
      end)
      rowFrame.action:SetScript("OnLeave", GameTooltip_Hide)
    elseif nextActionType == "REFORGE_ITEM" or (not nextActionType and hasPriorityReforge and not hasPriorityAnyEnchant and not hasPriorityUpgrade) then
      rowFrame.action:SetEnabled(true)
      rowFrame.action:SetText("Reforge*")
      SetActionButtonReforgeStyle(rowFrame.action, true)
      local firstReforgeTask = nextActionTask or (rowData.reforgeTasks and rowData.reforgeTasks[1] or nil)
      local reforgeText = firstReforgeTask and firstReforgeTask.wantReforgeText or nil
      if firstReforgeTask and (tonumber(firstReforgeTask.wantReforgeId) or 0) == 0 then
        reforgeText = "Remove current reforge."
      end
      local reforgeLiteIntegration = WSGH.Integrations and WSGH.Integrations.ReforgeLite or nil
      local hasReforgeLite = reforgeLiteIntegration
        and reforgeLiteIntegration.IsAvailable
        and reforgeLiteIntegration.IsAvailable()
      rowFrame.action:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(reforgeText or "Reforge item.")
        GameTooltip:AddLine(" ")
        if hasReforgeLite then
          GameTooltip:AddLine("Use ReforgeLite to apply the changes.", 1, 0.82, 0.2, true)
        else
          GameTooltip:AddLine("Apply reforge manually. ReforgeLite Classic is recommended for this step.", 1, 0.82, 0.2, true)
        end
        GameTooltip:AddLine("Upgrade before reforging to avoid incorrect reforge results.", 1, 0.82, 0.2, true)
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

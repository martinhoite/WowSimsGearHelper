local WSGH = _G.WowSimsGearHelper or {}
WSGH.UI = WSGH.UI or {}
WSGH.UI.Shopping = WSGH.UI.Shopping or {}

local DEBUG_SHOPPING = false
local jpHighlightItemId = nil
local IsAuctionHouseOpen

local function DebugShopping(msg)
  if not DEBUG_SHOPPING then return end
  if WSGH and WSGH.Util and WSGH.Util.Print then
    WSGH.Util.Print("[Shopping] " .. tostring(msg))
  end
end

local function ResolveKnownNeededItemIdByName(itemName)
  if type(itemName) ~= "string" or itemName == "" then return 0 end
  local wantedName = WSGH.Util.NormalizeName(itemName, true)
  if wantedName == "" then return 0 end
  local diff = WSGH.State and WSGH.State.diff
  if not (diff and diff.rows) then return 0 end

  local candidateItemIds = {}
  local function addItemId(itemId)
    itemId = tonumber(itemId) or 0
    if itemId ~= 0 then
      candidateItemIds[itemId] = true
    end
  end

  for _, row in ipairs(diff.rows) do
    for _, task in ipairs(row.socketTasks or {}) do
      if task.status and task.status ~= WSGH.Const.STATUS_OK then
        addItemId(task.wantGemId)
      end
    end
    for _, task in ipairs(row.enchantTasks or {}) do
      if task.status and task.status ~= WSGH.Const.STATUS_OK then
        addItemId(task.wantEnchantItemId)
      end
    end
    if tonumber(row.missingSockets) and tonumber(row.missingSockets) > 0 then
      addItemId(row.socketHintItemId)
      addItemId(row.socketHintExtraItemId)
    end
  end

  for itemId in pairs(candidateItemIds) do
    local knownName = GetItemInfo(itemId)
    if not knownName and C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(itemId)
    end
    if knownName and WSGH.Util.NormalizeName(knownName, true) == wantedName then
      return itemId
    end
  end

  return 0
end

local function HandleAuctionWonMessage(message)
  if not message then return end
  local itemLink = message:match("|Hitem:%d+.-|h%[[^]]+%]|h")
  local itemId = itemLink and select(1, GetItemInfoInstant(itemLink)) or nil
  local bracketName = nil
  if (not itemId or itemId == 0) and type(message) == "string" then
    bracketName = message:match("%[([^%]]+)%]")
    if bracketName then
      local link = select(2, GetItemInfo(bracketName))
      itemId = link and select(1, GetItemInfoInstant(link)) or itemId
    end
  end
  if (not itemId or itemId == 0) and type(ERR_AUCTION_WON_S) == "string" then
    local pattern = "^" .. ERR_AUCTION_WON_S:gsub("%%s", "(.+)") .. "$"
    local name = message:match(pattern)
    if name then
      local link = select(2, GetItemInfo(name))
      itemId = link and select(1, GetItemInfoInstant(link)) or itemId
    end
  end
  if (not itemId or itemId == 0) and type(message) == "string" then
    itemId = tonumber(message:match("|Hitem:(%d+)"))
  end
  if itemId and itemId ~= 0 then
    local count = tonumber(message:match("|rx(%d+)")) or tonumber(message:match("(%d+)%s*x")) or tonumber(message:match("x(%d+)")) or 1
    WSGH.UI.Shopping.RecordAuctionWin(itemId, count)
    if bracketName and WSGH.UI.pendingPurchasesByName then
      local pendingKey = WSGH.Util.NormalizeName(bracketName, true)
      if pendingKey == "" then
        pendingKey = bracketName
      end
      WSGH.UI.pendingPurchasesByName[pendingKey] = nil
    end
    return
  end
  if bracketName then
    local neededItemId = ResolveKnownNeededItemIdByName(bracketName)
    if neededItemId and neededItemId ~= 0 then
      local count = tonumber(message:match("(%d+)%s*x")) or tonumber(message:match("x(%d+)")) or 1
      WSGH.UI.Shopping.RecordAuctionWin(neededItemId, count)
      return
    end
    local count = tonumber(message:match("(%d+)%s*x")) or tonumber(message:match("x(%d+)")) or 1
    WSGH.UI.Shopping.RecordAuctionWinByName(bracketName, count)
  end
end

local function EscapeLuaPattern(text)
  if type(text) ~= "string" then return "" end
  return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local auctionWonMessagePatterns = nil

local function BuildAuctionWonMessagePatterns()
  if auctionWonMessagePatterns then
    return auctionWonMessagePatterns
  end

  auctionWonMessagePatterns = {}
  for globalName, globalValue in pairs(_G) do
    if type(globalName) == "string" and globalName:match("^ERR_AUCTION_WON") and type(globalValue) == "string" and globalValue ~= "" then
      local escaped = EscapeLuaPattern(globalValue)
      local pattern = "^" .. escaped:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)") .. "$"
      auctionWonMessagePatterns[#auctionWonMessagePatterns + 1] = pattern
    end
  end

  return auctionWonMessagePatterns
end

local function IsAuctionWonMessage(message)
  if type(message) ~= "string" or message == "" then
    return false
  end
  local patterns = BuildAuctionWonMessagePatterns()
  for _, pattern in ipairs(patterns) do
    if message:match(pattern) then
      return true
    end
  end
  return false
end

local function PruneRecentAuctionMessageKeys(now)
  WSGH.UI.Shopping.recentAuctionMessageKeys = WSGH.UI.Shopping.recentAuctionMessageKeys or {}
  for key, seenAt in pairs(WSGH.UI.Shopping.recentAuctionMessageKeys) do
    if (now - (tonumber(seenAt) or 0)) > 30 then
      WSGH.UI.Shopping.recentAuctionMessageKeys[key] = nil
    end
  end
end

local function BuildAuctionWonMessageKey(message, messageId)
  messageId = tonumber(messageId) or 0
  if messageId ~= 0 then
    return "id:" .. tostring(messageId)
  end
  if type(message) ~= "string" or message == "" then
    return nil
  end
  return "msg:" .. tostring(message)
end

local function ShouldHandleAuctionWonMessage(message, messageId)
  if not IsAuctionWonMessage(message) then
    return false
  end

  local now = GetTime and GetTime() or 0
  PruneRecentAuctionMessageKeys(now)

  local key = BuildAuctionWonMessageKey(message, messageId)
  if not key then return false end

  local seenAt = tonumber(WSGH.UI.Shopping.recentAuctionMessageKeys[key]) or 0
  if seenAt > 0 and (now - seenAt) < 30 then
    return false
  end

  WSGH.UI.Shopping.recentAuctionMessageKeys[key] = now
  return true
end

local function GetAuctionChatFrame()
  local frame = DEFAULT_CHAT_FRAME or ChatFrame1
  if not frame then return nil end
  if type(frame.GetNumMessages) ~= "function" then return nil end
  if type(frame.GetMessageInfo) ~= "function" then return nil end
  return frame
end

local function PollAuctionWonMessagesFromChatHistory()
  if not IsAuctionHouseOpen() then return end

  local chatFrame = GetAuctionChatFrame()
  if not chatFrame then return end

  WSGH.UI.Shopping.chatPollState = WSGH.UI.Shopping.chatPollState or {}
  local pollState = WSGH.UI.Shopping.chatPollState
  if pollState.chatFrame ~= chatFrame then
    pollState.chatFrame = chatFrame
    pollState.lastMessageIndex = 0
  end

  local numMessages = tonumber(chatFrame:GetNumMessages()) or 0
  if numMessages <= 0 then
    pollState.lastMessageIndex = 0
    return
  end

  local lastIndex = tonumber(pollState.lastMessageIndex) or 0
  if lastIndex <= 0 or numMessages < lastIndex then
    -- Re-sync by walking backward from newest message and bail early on first
    -- recently seen auction marker; then replay unknown lines oldest->newest.
    local pending = {}
    local resyncHistoryLines = tonumber(WSGH.Const and WSGH.Const.AUCTION_CHAT_RESYNC_HISTORY_LINES) or 80
    local oldest = math.max(1, numMessages - resyncHistoryLines)
    for i = numMessages, oldest, -1 do
      local message, _, _, _, _, messageId = chatFrame:GetMessageInfo(i)
      local key = BuildAuctionWonMessageKey(message, messageId)
      if key and WSGH.UI.Shopping.recentAuctionMessageKeys and WSGH.UI.Shopping.recentAuctionMessageKeys[key] then
        break
      end
      pending[#pending + 1] = { message = message, messageId = messageId }
    end
    for i = #pending, 1, -1 do
      local entry = pending[i]
      if ShouldHandleAuctionWonMessage(entry.message, entry.messageId) then
        HandleAuctionWonMessage(entry.message)
      end
    end
    pollState.lastMessageIndex = numMessages
    return
  end

  for i = lastIndex + 1, numMessages do
    local message, _, _, _, _, messageId = chatFrame:GetMessageInfo(i)
    if ShouldHandleAuctionWonMessage(message, messageId) then
      HandleAuctionWonMessage(message)
    end
  end

  pollState.lastMessageIndex = numMessages
end

local function StopAuctionChatPoller()
  local ticker = WSGH.UI.Shopping.auctionChatPollTicker
  if ticker and ticker.Cancel then
    ticker:Cancel()
  end
  WSGH.UI.Shopping.auctionChatPollTicker = nil
end

local function StartAuctionChatPoller()
  if WSGH.UI.Shopping.auctionChatPollTicker then return end
  if not (C_Timer and C_Timer.NewTicker) then return end

  local pollIntervalSeconds = tonumber(WSGH.Const and WSGH.Const.AUCTION_CHAT_POLL_INTERVAL_SECONDS) or 2.0
  if pollIntervalSeconds <= 0 then
    pollIntervalSeconds = 2.0
  end

  PollAuctionWonMessagesFromChatHistory()
  WSGH.UI.Shopping.auctionChatPollTicker = C_Timer.NewTicker(pollIntervalSeconds, function()
    PollAuctionWonMessagesFromChatHistory()
  end)
end

local function ExtractItemIdFromAuctionRef(itemRef)
  if type(itemRef) == "number" then
    return itemRef
  end
  if type(itemRef) == "string" then
    return select(1, GetItemInfoInstant(itemRef)) or tonumber(itemRef:match("|Hitem:(%d+)")) or 0
  end
  if type(itemRef) == "table" then
    local direct = tonumber(itemRef.itemID) or tonumber(itemRef.itemId)
    if direct and direct ~= 0 then
      return direct
    end
    local key = itemRef.itemKey
    if type(key) == "table" then
      local keyId = tonumber(key.itemID) or tonumber(key.itemId)
      if keyId and keyId ~= 0 then
        return keyId
      end
    end
    local hyperlink = itemRef.hyperlink or itemRef.itemLink or itemRef.link
    if type(hyperlink) == "string" and hyperlink ~= "" then
      return select(1, GetItemInfoInstant(hyperlink)) or tonumber(hyperlink:match("|Hitem:(%d+)")) or 0
    end
  end
  return 0
end

local function ResetAuctionHouseToBrowse()
  local switched = false
  if AuctionHouseFrame then
    if AuctionHouseFrame.SetDisplayMode and AuctionHouseFrameDisplayMode and AuctionHouseFrameDisplayMode.Browse then
      switched = pcall(AuctionHouseFrame.SetDisplayMode, AuctionHouseFrame, AuctionHouseFrameDisplayMode.Browse) or switched
    end
    if AuctionHouseFrame.SetTab then
      switched = pcall(AuctionHouseFrame.SetTab, AuctionHouseFrame, 1) or switched
    end
    if AuctionHouseFrame.BrowseResultsFrame and AuctionHouseFrame.BrowseResultsFrame.Reset then
      pcall(AuctionHouseFrame.BrowseResultsFrame.Reset, AuctionHouseFrame.BrowseResultsFrame)
    end
    if AuctionHouseFrame.CommoditiesBuyFrame and AuctionHouseFrame.CommoditiesBuyFrame.BackButton then
      local back = AuctionHouseFrame.CommoditiesBuyFrame.BackButton
      local backHandler = back:GetScript("OnClick")
      if backHandler then
        pcall(backHandler, back)
      end
    end
    if AuctionHouseFrame.SearchBar then
      if AuctionHouseFrame.SearchBar.ClearSearch then
        pcall(AuctionHouseFrame.SearchBar.ClearSearch, AuctionHouseFrame.SearchBar)
      elseif AuctionHouseFrame.SearchBar.Reset then
        pcall(AuctionHouseFrame.SearchBar.Reset, AuctionHouseFrame.SearchBar)
      end
    end
  end
  if not switched and AuctionFrameTab1 and AuctionFrameTab1:GetParent() and AuctionFrameTab1:GetParent().SetTab then
    pcall(AuctionFrameTab1:GetParent().SetTab, AuctionFrameTab1:GetParent(), 1)
  elseif AuctionFrame_SetTab then
    pcall(AuctionFrame_SetTab, 1)
  end
end

IsAuctionHouseOpen = function()
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then return true end
  if AuctionFrame and AuctionFrame:IsShown() then return true end
  return false
end

local function CountItemInBags(itemId, bagIndex)
  itemId = tonumber(itemId) or 0
  if itemId == 0 then return 0 end
  local count = 0
  for _, location in ipairs((bagIndex and bagIndex[itemId]) or {}) do
    count = count + (tonumber(location.count) or 1)
  end
  return count
end

local function GetCurrencyAmountAndIcon(currencyId)
  currencyId = tonumber(currencyId) or 0
  if currencyId == 0 then return 0, nil end

  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
    if type(info) == "table" then
      local quantity = tonumber(info.quantity) or tonumber(info.totalQuantity) or tonumber(info.amount)
      if quantity then
        local icon = info.iconFileID or info.icon or info.displayInfo
        return quantity, icon
      end
    end
  end

  if GetCurrencyInfo then
    local _, amount, icon = GetCurrencyInfo(currencyId)
    amount = tonumber(amount) or 0
    return amount, icon
  end

  return 0, nil
end

local function ShowCurrencyTooltip(owner, currencyId)
  if not owner then return end
  currencyId = tonumber(currencyId) or 0
  if currencyId == 0 then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if GameTooltip.SetCurrencyByID then
    GameTooltip:SetCurrencyByID(currencyId)
    GameTooltip:Show()
    return
  end
  local name, amount, icon = GetCurrencyInfo(currencyId)
  if name then
    GameTooltip:SetText(name)
    GameTooltip:AddLine(("Amount: %d"):format(tonumber(amount) or 0), 1, 1, 1, true)
    if icon then
      GameTooltip:AddLine(("Icon: %s"):format(tostring(icon)), 0.8, 0.8, 0.8, true)
    end
  else
    GameTooltip:SetText(("Currency %d"):format(currencyId))
  end
  GameTooltip:Show()
end

local function GetUpgradeCurrencyConfig()
  local preferences = WSGH.Util and WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or {}
  local useValor = preferences and preferences.useValorForUpgrades == true
  if useValor then
    return {
      key = "VALOR",
      short = "VP",
      currencyId = WSGH.Const.VALOR_POINTS_CURRENCY_ID,
      perUpgradeStep = WSGH.Const.VALOR_POINTS_PER_UPGRADE_STEP,
      commendationItemId = WSGH.Const.VALOR_POINTS_COMMENDATION_ITEM_ID,
      cap = 3000,
    }
  end

  return {
    key = "JUSTICE",
    short = "JP",
    currencyId = WSGH.Const.JUSTICE_POINTS_CURRENCY_ID,
    perUpgradeStep = WSGH.Const.JUSTICE_POINTS_PER_UPGRADE_STEP,
    commendationItemId = WSGH.Const.JUSTICE_POINTS_COMMENDATION_ITEM_ID,
    cap = 4000,
  }
end

local function RefreshAfterPurchase()
  if not (WSGH.UI and WSGH.UI.frame and WSGH.UI.frame:IsShown()) then
    return
  end
  if WSGH.UI.RebuildAndRefresh then
    WSGH.UI.RebuildAndRefresh()
    return
  end
  if WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateShoppingList then
    WSGH.UI.Shopping.UpdateShoppingList()
  end
end

function WSGH.UI.Shopping.SearchAuctionHouseById(itemId)
  local name = GetItemInfo(itemId)
  if not name then return false end
  if not IsAuctionHouseOpen() then return false end
  ResetAuctionHouseToBrowse()
  if C_AuctionHouse and C_AuctionHouse.SendBrowseQuery then
    local query = { searchString = name, sorts = {}, filters = {} }
    local ok = pcall(C_AuctionHouse.SendBrowseQuery, query)
    return ok
  elseif QueryAuctionItems then
    local ok = pcall(QueryAuctionItems, name, nil, nil, 0, false, nil, false, false, nil)
    return ok
  end
  return false
end

function WSGH.UI.Shopping.RecordAuctionWin(itemId, count)
  if not itemId or itemId == 0 then return end
  count = tonumber(count) or 1
  local now = GetTime and GetTime() or 0
  WSGH.UI.lastPurchase = WSGH.UI.lastPurchase or {}
  local last = WSGH.UI.lastPurchase
  -- Auction wins can fire through multiple channels almost at once (AH event + chat).
  -- Keep a tight suppression window so real back-to-back wins are not dropped.
  if last.itemId == itemId and last.count == count and (now - (last.time or 0)) < 0.20 then
    return
  end
  last.itemId = itemId
  last.count = count
  last.time = now
  WSGH.UI.pendingPurchases = WSGH.UI.pendingPurchases or {}
  WSGH.UI.pendingPurchases[itemId] = (WSGH.UI.pendingPurchases[itemId] or 0) + count
  DebugShopping(("[Shopping] Auction win recorded: id %d x%d"):format(itemId, count))
  RefreshAfterPurchase()
end

function WSGH.UI.Shopping.RecordAuctionWinByName(itemName, count)
  if type(itemName) ~= "string" or itemName == "" then return end
  count = tonumber(count) or 1
  local key = WSGH.Util.NormalizeName(itemName, true)
  if key == "" then
    key = itemName
  end
  WSGH.UI.pendingPurchasesByName = WSGH.UI.pendingPurchasesByName or {}
  WSGH.UI.pendingPurchasesByName[key] = (WSGH.UI.pendingPurchasesByName[key] or 0) + count
  DebugShopping(("[Shopping] Auction win recorded by name: %s x%d"):format(itemName, count))
  RefreshAfterPurchase()
end

function WSGH.UI.Shopping.UpdateShoppingList()
  if not WSGH.UI.shoppingFrame then return end

  local frame = WSGH.UI.shoppingFrame
  local scroll = WSGH.UI.shoppingScroll
  local entries = WSGH.UI.shoppingEntries or {}
  local visibleEntries = #entries
  local empty = WSGH.UI.shoppingEmpty
  local title = WSGH.UI.shoppingTitle
  local byline = WSGH.UI.shoppingByline
  if byline then
    byline:SetWidth(math.max((frame:GetWidth() or WSGH.Const.UI.shopping.sidebarWidth) - 28, 120))
  end
  WSGH.UI.pendingPurchases = WSGH.UI.pendingPurchases or {}
  WSGH.UI.pendingPurchasesByName = WSGH.UI.pendingPurchasesByName or {}
  local bagIndex = WSGH.Scan.GetBagIndex and WSGH.Scan.GetBagIndex() or {}

  for pendingName, pendingCount in pairs(WSGH.UI.pendingPurchasesByName) do
    local resolvedItemId = ResolveKnownNeededItemIdByName(pendingName)
    if resolvedItemId and resolvedItemId ~= 0 then
      WSGH.UI.pendingPurchases[resolvedItemId] = (WSGH.UI.pendingPurchases[resolvedItemId] or 0) + (tonumber(pendingCount) or 0)
      WSGH.UI.pendingPurchasesByName[pendingName] = nil
    end
  end

  local diff = WSGH.State and WSGH.State.diff
  local needsByItem = {}
  local function AccumulateNeed(itemId, count, category)
    itemId = tonumber(itemId) or 0
    count = tonumber(count) or 0
    if itemId == 0 or count <= 0 then return end
    if not needsByItem[itemId] then
      needsByItem[itemId] = { count = 0, category = category }
    end
    needsByItem[itemId].count = needsByItem[itemId].count + count
    if category and not needsByItem[itemId].category then
      needsByItem[itemId].category = category
    end
  end

  local categoryOrder = WSGH.Const.UI.shopping.categories
  local itemsByCategory = {}
  for _, cat in ipairs(categoryOrder) do itemsByCategory[cat] = {} end
  itemsByCategory["Other"] = itemsByCategory["Other"] or {}
  local hasPendingEquipTasks = false

  if diff and diff.rows then
    local upgradeStepsNeeded = 0
    for _, row in ipairs(diff.rows) do
      if row.rowStatus == "WRONG_ITEM" then
        hasPendingEquipTasks = true
      end
      for _, task in ipairs(row.socketTasks or {}) do
        if task.status and task.status ~= WSGH.Const.STATUS_OK then
          local wantGemId = tonumber(task.wantGemId) or 0
          if wantGemId ~= 0 then
            AccumulateNeed(wantGemId, 1, "Gems")
          end
        end
      end
      for _, task in ipairs(row.enchantTasks or {}) do
        if task.status and task.status ~= WSGH.Const.STATUS_OK then
          local enchantItemId = tonumber(task.wantEnchantItemId) or 0
          if enchantItemId ~= 0 then
            local category = (task.type == "APPLY_TINKER") and "Other" or "Enchants"
            AccumulateNeed(enchantItemId, 1, category)
          end
        end
      end

      -- Add socket-creation items (e.g., belt buckles) when the plan expects more sockets than the item has.
      local hintId = tonumber(row.socketHintItemId) or 0
      local missingSockets = tonumber(row.missingSockets) or 0
      if hintId ~= 0 and missingSockets > 0 then
        local bagCount = 0
        for _, location in ipairs(bagIndex[hintId] or {}) do
          bagCount = bagCount + (location.count or 1)
        end
        local remaining = missingSockets - bagCount
        if remaining > 0 then
          AccumulateNeed(hintId, remaining, "Other")
        end
      end
      local extraId = tonumber(row.socketHintExtraItemId) or 0
      local extraCount = tonumber(row.socketHintExtraItemCount) or 0
      if extraId ~= 0 and extraCount > 0 then
        local bagCount = 0
        for _, location in ipairs(bagIndex[extraId] or {}) do
          bagCount = bagCount + (location.count or 1)
        end
        local remaining = extraCount - bagCount
        if remaining > 0 then
          AccumulateNeed(extraId, remaining, "Other")
        end
      end

      for _, task in ipairs(row.upgradeTasks or {}) do
        if task.status and task.status ~= WSGH.Const.STATUS_OK then
          upgradeStepsNeeded = upgradeStepsNeeded + 1
        end
      end
    end

    if upgradeStepsNeeded > 0 then
      local currencyConfig = GetUpgradeCurrencyConfig()
      local commendationItemId = tonumber(currencyConfig.commendationItemId)
      local commendationsInBags = CountItemInBags(commendationItemId, bagIndex)
      local currencyAmount, currencyIcon = GetCurrencyAmountAndIcon(currencyConfig.currencyId)
      local currencyPerUpgradeStep = tonumber(currencyConfig.perUpgradeStep)
      local currencyCap = tonumber(currencyConfig.cap)
      local currencyNeeded = upgradeStepsNeeded * currencyPerUpgradeStep
      local currencyMissing = currencyNeeded - currencyAmount
      if currencyMissing < 0 then currencyMissing = 0 end

      local jpPerCommNonGuild = WSGH.Const.JUSTICE_POINTS_PER_COMMENDATION_NON_GUILD
      local jpPerCommGuild = WSGH.Const.JUSTICE_POINTS_PER_COMMENDATION_GUILD
      local valorPerJpComm = WSGH.Const.VALOR_POINTS_PER_JP_COMMENDATION
      local isInGuild = (IsInGuild and IsInGuild()) and true or false
      local jpPerComm = isInGuild and jpPerCommGuild or jpPerCommNonGuild
      local neededComm = 0
      local neededValor = 0
      if currencyConfig.key == "JUSTICE" and currencyMissing > 0 then
        neededComm = math.ceil(currencyMissing / math.max(jpPerComm, 1))
        neededValor = neededComm * valorPerJpComm
      end

      if currencyMissing > 0 then
        local bucket = itemsByCategory["Other"] or {}
        itemsByCategory["Other"] = bucket
        bucket[#bucket + 1] = {
          isCurrency = true,
          currencyKey = currencyConfig.key,
          currencyShort = currencyConfig.short,
          currencyId = currencyConfig.currencyId,
          currencyAmount = currencyAmount,
          currencyCap = currencyCap,
          currencyIcon = currencyIcon,
          upgradeStepsNeeded = upgradeStepsNeeded,
          currencyNeeded = currencyNeeded,
          currencyMissing = currencyMissing,
          isInGuild = isInGuild,
          jpPerComm = jpPerComm,
          neededComm = neededComm,
          neededValor = neededValor,
          actionItemId = commendationItemId,
          actionItemCount = commendationsInBags,
          category = "Other",
        }
      end

      if currencyMissing <= 0 and jpHighlightItemId then
        if WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.SetSocketHintTarget then
          WSGH.UI.Highlight.SetSocketHintTarget(nil, nil, nil)
        end
        if WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.UpdateFromState then
          WSGH.UI.Highlight.UpdateFromState()
        end
        jpHighlightItemId = nil
      end
    else
      if jpHighlightItemId then
        if WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.SetSocketHintTarget then
          WSGH.UI.Highlight.SetSocketHintTarget(nil, nil, nil)
        end
        if WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.UpdateFromState then
          WSGH.UI.Highlight.UpdateFromState()
        end
        jpHighlightItemId = nil
      end
    end
  end

  if byline then
    if hasPendingEquipTasks then
      byline:SetText("List may be incomplete as some planned items are not equipped yet.")
      byline:Show()
    else
      byline:SetText("")
      byline:Hide()
    end
  end

  -- Fallback: if row-based scan yielded nothing, fall back to flat tasks.
  if next(needsByItem) == nil and diff and diff.tasks then
    for _, task in ipairs(diff.tasks) do
      if task.status and task.status ~= WSGH.Const.STATUS_OK then
        if task.type == "SOCKET_GEM" then
          local wantGemId = tonumber(task.wantGemId) or 0
          if wantGemId ~= 0 then
            AccumulateNeed(wantGemId, 1, "Gems")
          end
        elseif task.type == "APPLY_ENCHANT" or task.type == "APPLY_TINKER" then
          local enchantItemId = tonumber(task.wantEnchantItemId) or 0
          if enchantItemId ~= 0 then
            local category = (task.type == "APPLY_TINKER") and "Other" or "Enchants"
            AccumulateNeed(enchantItemId, 1, category)
          end
        end
      end
    end
  end

  local flattenedRows = {}
  for itemId, need in pairs(needsByItem) do
    local bagCount = 0
    for _, location in ipairs(bagIndex[itemId] or {}) do
      bagCount = bagCount + (location.count or 1)
    end
    local pending = tonumber(WSGH.UI.pendingPurchases[itemId]) or 0

    local totalNeeded = tonumber(need.count) or 0
    local remaining = totalNeeded - bagCount
    if remaining > 0 then
      -- Progress text should reflect purchases toward what is still missing now.
      local bought = math.min(remaining, pending)
      local category = need.category or "Other"
      local bucket = itemsByCategory[category] or itemsByCategory["Other"]
      bucket[#bucket + 1] = {
        itemId = itemId,
        count = remaining,
        totalNeeded = totalNeeded,
        bought = bought,
        category = category
      }
    else
      WSGH.UI.pendingPurchases[itemId] = nil
    end
  end
  for _, bucket in pairs(itemsByCategory) do
    table.sort(bucket, function(a, b) return a.itemId < b.itemId end)
  end

  for _, cat in ipairs(categoryOrder) do
    local bucket = itemsByCategory[cat]
    if bucket and #bucket > 0 then
      flattenedRows[#flattenedRows + 1] = { isHeader = true, header = cat }
      for _, entry in ipairs(bucket) do
        flattenedRows[#flattenedRows + 1] = entry
      end
    end
  end

  DebugShopping(("diff tasks=%s missingKeys=%d"):format(diff and diff.taskCount or "nil", #flattenedRows))
  local totalRows = #flattenedRows
  local entryHeight = WSGH.Const.UI.shopping.entryHeight
  local offset = 0
  if scroll then
    local currentOffset = FauxScrollFrame_GetOffset(scroll) or 0
    local maxOffset = math.max(0, totalRows - visibleEntries)
    if totalRows <= visibleEntries then
      currentOffset = 0
    elseif currentOffset > maxOffset then
      currentOffset = maxOffset
    end

    FauxScrollFrame_SetOffset(scroll, currentOffset)
    if scroll.ScrollBar then scroll.ScrollBar:SetValue(currentOffset * entryHeight) end
    FauxScrollFrame_Update(scroll, totalRows, visibleEntries, entryHeight)
    offset = currentOffset
  end

  local padding = WSGH.Const.UI.shopping.padding
  local bylineHeight = 0
  if byline and byline:IsShown() then
    bylineHeight = (byline:GetStringHeight() or 0) + 6
  end
  local height = padding + (title and title:GetStringHeight() or 0) + bylineHeight + 6

  local maxRowWidth = 0

  if totalRows == 0 then
    for _, entry in ipairs(entries) do entry:Hide() end
    if empty then
      empty:Show()
      height = height + empty:GetStringHeight() + padding
      DebugShopping("shopping list empty: no missing entries")
    end
  else
    if empty then empty:Hide() end
    for i, entry in ipairs(entries) do
      local data = flattenedRows[offset + i]
      if data then
        if data.isHeader then
          entry.icon:Hide()
          entry.icon.itemId = nil
          entry.text:SetText(data.header or "")
          entry.text:SetFontObject("GameFontHighlightSmall")
          entry.text:SetTextColor(1, 0.82, 0, 1)
          if entry.strike then entry.strike:Hide() end
          entry.count:SetText("")
          if entry.countIcon then
            entry.countIcon:Hide()
            entry.countIcon.itemId = nil
            entry.countIcon:SetScript("OnEnter", nil)
            entry.countIcon:SetScript("OnLeave", nil)
          end
          entry.search:SetShown(false)
          entry.search:SetEnabled(false)
          entry.itemId = nil
          entry:SetScript("OnEnter", nil)
          entry:SetScript("OnLeave", nil)
          entry:Show()
          local textWidth = entry.text:GetStringWidth() or 0
          local rowWidth = 14 + textWidth + 10
          if rowWidth > maxRowWidth then maxRowWidth = rowWidth end
        else
          if data.isCurrency then
            local actionItemId = tonumber(data.actionItemId) or 0
            local icon = data.currencyIcon
            local actionItemCount = tonumber(data.actionItemCount) or 0
            local currencyShort = tostring(data.currencyShort or "JP")
            local currentValue = tonumber(data.currencyAmount) or 0
            local currencyCap = tonumber(data.currencyCap) or 4000
            local currencyNeeded = tonumber(data.currencyNeeded) or 0
            local currencyMissing = tonumber(data.currencyMissing) or 0
            local upgrades = tonumber(data.upgradeStepsNeeded) or 0
            local currencyId = tonumber(data.currencyId) or 0
            local upgradesLabel = WSGH.Util.FormatCountNoun(upgrades, "upgrade")

            entry.icon:SetTexture(icon or WSGH.Const.ICON_PURCHASE)
            entry.icon:Show()
            entry.icon.itemId = nil
            entry.text:SetFontObject("GameFontNormalSmall")
            entry.text:SetText(("%s: %d/%d | Missing: %d (%s)"):format(currencyShort, currentValue, currencyCap, currencyMissing, upgradesLabel))
            entry.text:SetTextColor(1, 1, 1, 1)
            if entry.strike then entry.strike:Hide() end
            entry.count:SetText("")
            entry.count:SetTextColor(1, 1, 1, 1)
            if entry.countIcon then
              local _, _, _, _, _, _, _, _, _, commIcon = GetItemInfo(actionItemId)
              if not commIcon then
                commIcon = select(5, GetItemInfoInstant(actionItemId))
              end
              if actionItemId ~= 0 and commIcon then
                entry.countIcon.texture:SetTexture(commIcon)
                entry.countIcon.itemId = actionItemId
                entry.countIcon:SetScript("OnEnter", function(self)
                  local id = tonumber(self.itemId) or 0
                  if id == 0 then return end
                  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                  GameTooltip:SetItemByID(id)
                  GameTooltip:Show()
                end)
                entry.countIcon:SetScript("OnLeave", GameTooltip_Hide)
                entry.countIcon:Show()
              else
                entry.countIcon:Hide()
                entry.countIcon.itemId = nil
                entry.countIcon:SetScript("OnEnter", nil)
                entry.countIcon:SetScript("OnLeave", nil)
              end
            end

            entry.search:SetShown(true)
            entry.search:SetEnabled(actionItemId ~= 0)
            entry.search.itemId = actionItemId
            entry.search:SetWidth(WSGH.Const.UI.shopping.searchButton.width)
            entry.search:SetText("")
            entry.search:SetNormalTexture(WSGH.Const.ICON_SEARCH)
            local jpSearchTexture = entry.search:GetNormalTexture()
            if jpSearchTexture then
              jpSearchTexture:SetVertexColor(1, 1, 1)
            end
            entry.search:SetScript("OnEnter", function(self)
              GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
              local actionCount = tonumber(data.actionItemCount) or 0
              local jpPerCommNonGuild = WSGH.Const.JUSTICE_POINTS_PER_COMMENDATION_NON_GUILD
              local valorPerJpComm = WSGH.Const.VALOR_POINTS_PER_JP_COMMENDATION
              local commNeeded = tonumber(data.neededComm) or 0
              local valorNeeded = tonumber(data.neededValor) or 0
              local jpPerComm = tonumber(data.jpPerComm) or jpPerCommNonGuild
              local isInGuild = data.isInGuild == true
              GameTooltip:SetText("Highlight in bags")
              GameTooltip:AddLine(("Highlight Commendation of Justice in bags (%d available)."):format(actionCount), 1, 1, 1, true)
              GameTooltip:AddLine(("Commendation conversion: %d JP each, costs %d VP each."):format(
                jpPerComm,
                valorPerJpComm
              ), 0.8, 0.8, 0.8, true)
              if tostring(data.currencyKey) == "JUSTICE" then
                GameTooltip:AddLine(("Needed commendations: %d | VP cost: %d"):format(
                  commNeeded,
                  valorNeeded
                ), 0.8, 0.8, 0.8, true)
                if not isInGuild then
                  GameTooltip:AddLine("Not in a guild: join one for +100 JP per commendation.", 1, 0.2, 0.2, true)
                end
              end
              GameTooltip:Show()
            end)
            entry.search:SetScript("OnLeave", GameTooltip_Hide)
            entry.search:SetScript("OnClick", function(self)
              local id = tonumber(self.itemId) or 0
              if id == 0 then return end
              WSGH.Util.OpenBagsForGuidance()
              if WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.SetSocketHintTarget then
                WSGH.UI.Highlight.SetSocketHintTarget(id, nil, nil)
              end
              jpHighlightItemId = id
            end)

            entry.itemId = nil
            entry:SetScript("OnEnter", function(self)
              ShowCurrencyTooltip(self, currencyId)
            end)
            entry:SetScript("OnLeave", GameTooltip_Hide)
            entry:Show()

            local countWidth = entry.count:GetStringWidth() or 0
            local buttonWidth = entry.search:GetWidth() or 0
            local textWidth = entry.text:GetStringWidth() or 0
            local rowWidth = 14 + 16 + 6 + textWidth + 8 + countWidth + 8 + buttonWidth + 10
            if rowWidth > maxRowWidth then maxRowWidth = rowWidth end
          else
            if entry.countIcon then
              entry.countIcon:Hide()
              entry.countIcon.itemId = nil
              entry.countIcon:SetScript("OnEnter", nil)
              entry.countIcon:SetScript("OnLeave", nil)
            end
            DebugShopping(("entry %d item %d need %d"):format(offset + i, data.itemId, data.count))
            local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(data.itemId)
            if not name or not icon then
              local itemIcon = select(5, GetItemInfoInstant(data.itemId))
              icon = icon or itemIcon
              if C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(data.itemId)
              end
            end
            entry.icon:SetTexture(icon or WSGH.Const.ICON_PURCHASE)
            entry.icon:Show()
            entry.icon.itemId = data.itemId
            entry.text:SetFontObject("GameFontNormalSmall")
            entry.text:SetText(name or ("Item " .. data.itemId))
            local purchaseTarget = tonumber(data.count) or 0
            local isFullyPurchased = (tonumber(data.bought) or 0) >= purchaseTarget and purchaseTarget > 0
            if isFullyPurchased then
              entry.text:SetTextColor(0.72, 0.72, 0.72, 1)
            else
              entry.text:SetTextColor(1, 1, 1, 1)
            end
            if entry.strike then entry.strike:Hide() end
            local totalNeeded = purchaseTarget
            local bought = data.bought or 0
            if bought > totalNeeded then
              bought = totalNeeded
            end
            if bought > 0 and not isFullyPurchased then
              entry.count:SetText(("x%d (%d/%d bought)"):format(data.count, bought, totalNeeded))
            else
              entry.count:SetText("x" .. data.count)
            end
            entry.search:SetShown(true)
            entry.search:SetEnabled(true)
            entry.search.itemId = data.itemId
            entry.search:SetWidth(WSGH.Const.UI.shopping.searchButton.width)
            entry.search:SetText("")
            if isFullyPurchased then
              entry.search:SetNormalTexture(WSGH.Const.ICON_READY)
            else
              entry.search:SetNormalTexture(WSGH.Const.ICON_SEARCH)
            end
            local searchTexture = entry.search:GetNormalTexture()
            if searchTexture then
              searchTexture:SetVertexColor(1, 1, 1)
            end
            entry.search:SetScript("OnEnter", function(self)
              GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
              if isFullyPurchased then
                GameTooltip:SetText("Purchased")
                GameTooltip:AddLine(("%d/%d bought already."):format(bought, totalNeeded), 1, 1, 1, true)
                GameTooltip:AddLine("Loot your mailbox to finish receiving these items.", 0.85, 0.85, 0.85, true)
              else
                local itemName = self.itemId and GetItemInfo(self.itemId)
                GameTooltip:SetText("Search Auction House")
                GameTooltip:AddLine(itemName or "Search this item in the Auction House.", 1, 1, 1, true)
              end
              GameTooltip:Show()
            end)
            entry.search:SetScript("OnLeave", GameTooltip_Hide)
            entry.search:SetScript("OnClick", function(self)
              if isFullyPurchased then return end
              if not self.itemId then return end
              local ok = WSGH.UI.Shopping.SearchAuctionHouseById(self.itemId)
              if not ok then
                WSGH.Util.Print("Open the Auction House and try again.")
              end
            end)
            if isFullyPurchased then
              entry.count:SetTextColor(0.72, 0.72, 0.72, 1)
            else
              entry.count:SetTextColor(1, 1, 1, 1)
            end
            entry.itemId = data.itemId
            entry:SetScript("OnEnter", function(self)
              local id = self.itemId
              if not id or id == 0 then return end
              GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
              GameTooltip:SetItemByID(id)
              GameTooltip:Show()
            end)
            entry:SetScript("OnLeave", GameTooltip_Hide)
            entry:Show()

            local countWidth = entry.count:GetStringWidth() or 0
            local buttonWidth = entry.search:GetWidth() or 0
            local textWidth = entry.text:GetStringWidth() or 0
            local rowWidth = 14 + 16 + 6 + textWidth + 8 + countWidth + 8 + buttonWidth + 10
            if rowWidth > maxRowWidth then maxRowWidth = rowWidth end
          end
        end
      else
        entry:Hide()
        if entry.strike then entry.strike:Hide() end
        if entry.countIcon then
          entry.countIcon:Hide()
          entry.countIcon.itemId = nil
          entry.countIcon:SetScript("OnEnter", nil)
          entry.countIcon:SetScript("OnLeave", nil)
        end
        entry.search:SetShown(false)
      end
    end
    local rowsShown = math.min(visibleEntries, math.max(totalRows - offset, 0))
    height = height + (rowsShown * entryHeight) + padding
  end

  local minWidth = WSGH.Const.UI.shopping.sidebarWidth
  local targetWidth = math.max(minWidth, maxRowWidth)
  frame:SetWidth(targetWidth)
  if byline then
    byline:SetWidth(math.max(targetWidth - 28, 120))
  end
  for _, entry in ipairs(entries) do
    entry:SetWidth(targetWidth - 24)
    entry.text:ClearAllPoints()
    entry.text:SetPoint("LEFT", entry.icon, "RIGHT", 6, 0)
    if entry.search:IsShown() then
      entry.text:SetPoint("RIGHT", entry.count, "LEFT", -8, 0)
    else
      entry.text:SetPoint("RIGHT", entry, "RIGHT", -10, 0)
    end
  end
  frame:SetHeight(math.max(height + padding, 120))
end

WSGH.Debug = WSGH.Debug or {}

function WSGH.Debug.DumpShoppingEntries(maxEntries)
  local entries = WSGH.UI.shoppingEntries or {}
  local limit = tonumber(maxEntries) or #entries
  for i = 1, math.min(limit, #entries) do
    local entry = entries[i]
    if entry then
      local text = entry.text and entry.text:GetText() or ""
      local count = entry.count and entry.count:GetText() or ""
      local id = entry.itemId or 0
      local shown = entry:IsShown() and "shown" or "hidden"
      if WSGH.Util and WSGH.Util.Print then
        WSGH.Util.Print(("[Shop %d] %s id=%s text=%s count=%s"):format(i, shown, tostring(id), tostring(text), tostring(count)))
      end
    end
  end
end

function WSGH.Debug.DumpShoppingRow(index)
  index = tonumber(index) or 0
  if index == 0 then
    WSGH.Util.Print("DumpShoppingRow: provide a row index.")
    return
  end
  local entry = (WSGH.UI.shoppingEntries or {})[index]
  if not entry then
    WSGH.Util.Print(("DumpShoppingRow: row %d not found."):format(index))
    return
  end
  local text = entry.text and entry.text:GetText() or ""
  local count = entry.count and entry.count:GetText() or ""
  local id = entry.itemId or 0
  local shown = entry:IsShown() and "shown" or "hidden"
  WSGH.Util.Print(("[Shop %d] %s id=%s text=%s count=%s"):format(index, shown, tostring(id), tostring(text), tostring(count)))
  if id and id ~= 0 then
    WSGH.Debug.DumpShoppingItem(id)
  end
end

function WSGH.Debug.DumpShoppingItem(itemId)
  itemId = tonumber(itemId) or 0
  if itemId == 0 then
    WSGH.Util.Print("DumpShoppingItem: provide an itemId.")
    return
  end

  local diff = WSGH.State and WSGH.State.diff
  local bagIndex = WSGH.Scan.GetBagIndex and WSGH.Scan.GetBagIndex() or {}
  local pending = WSGH.UI.pendingPurchases and WSGH.UI.pendingPurchases[itemId] or 0
  local needCount = 0

  if diff and diff.rows then
    for _, row in ipairs(diff.rows) do
      for _, task in ipairs(row.socketTasks or {}) do
        if task.status and task.status ~= WSGH.Const.STATUS_OK and tonumber(task.wantGemId) == itemId then
          needCount = needCount + 1
        end
      end
      for _, task in ipairs(row.enchantTasks or {}) do
        if task.status and task.status ~= WSGH.Const.STATUS_OK and task.type == "APPLY_ENCHANT" and tonumber(task.wantEnchantItemId) == itemId then
          needCount = needCount + 1
        end
      end
      local hintId = tonumber(row.socketHintItemId) or 0
      local missingSockets = tonumber(row.missingSockets) or 0
      if hintId == itemId and missingSockets > 0 then
        needCount = needCount + missingSockets
      end
      local extraId = tonumber(row.socketHintExtraItemId) or 0
      local extraCount = tonumber(row.socketHintExtraItemCount) or 0
      if extraId == itemId and extraCount > 0 then
        needCount = needCount + extraCount
      end
    end
  end

  local bagCount = 0
  for _, location in ipairs(bagIndex[itemId] or {}) do
    bagCount = bagCount + (location.count or 1)
  end
  local remaining = needCount - bagCount
  if remaining < 0 then remaining = 0 end

  WSGH.Util.Print(("DumpShoppingItem %d: need=%d bag=%d pending=%d remaining=%d"):format(itemId, needCount, bagCount, pending, remaining))
end

function WSGH.UI.Shopping.DumpEntries(maxEntries)
  WSGH.Debug.DumpShoppingEntries(maxEntries)
end

function WSGH.UI.Shopping.DebugItem(itemId)
  WSGH.Debug.DumpShoppingItem(itemId)
end

local function EnsurePurchaseListener()
  if WSGH.UI.Shopping.purchaseListener then return end
  local listener = CreateFrame("Frame")
  if C_AuctionHouse then
    pcall(listener.RegisterEvent, listener, "AUCTION_HOUSE_SHOW_ITEM_WON_NOTIFICATION")
    pcall(listener.RegisterEvent, listener, "AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION")
  end
  listener:RegisterEvent("AUCTION_HOUSE_SHOW")
  listener:RegisterEvent("AUCTION_HOUSE_CLOSED")
  listener:RegisterEvent("CHAT_MSG_SYSTEM")
  listener:RegisterEvent("CHAT_MSG_LOOT")
  listener:SetScript("OnEvent", function(_, event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
      StartAuctionChatPoller()
    elseif event == "AUCTION_HOUSE_CLOSED" then
      StopAuctionChatPoller()
    elseif event == "AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION" or event == "AUCTION_HOUSE_SHOW_ITEM_WON_NOTIFICATION" then
      local itemRef, quantity = ...
      local itemId = ExtractItemIdFromAuctionRef(itemRef)
      local count = tonumber(quantity) or tonumber((type(itemRef) == "table" and (itemRef.quantity or itemRef.stackSize)) or 0) or 1
      if itemId and itemId ~= 0 then
        WSGH.UI.Shopping.RecordAuctionWin(itemId, count)
      end
    elseif event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_LOOT" then
      local message = ...
      local messageId = select(11, ...)
      if ShouldHandleAuctionWonMessage(message, messageId) then
        HandleAuctionWonMessage(message)
      end
    end
  end)
  WSGH.UI.Shopping.purchaseListener = listener
  if IsAuctionHouseOpen() then
    StartAuctionChatPoller()
  end
end

EnsurePurchaseListener()

local function EnsureItemDataListener()
  if WSGH.UI.Shopping.itemDataListener then return end
  local listener = CreateFrame("Frame")
  listener:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  if C_Item and C_Item.RequestLoadItemDataByID then
    listener:RegisterEvent("ITEM_DATA_LOAD_RESULT")
  end
  listener:SetScript("OnEvent", function(_, _, _, success)
    if success == false then return end
    if not (WSGH.UI and WSGH.UI.frame and WSGH.UI.frame:IsShown()) then return end
    WSGH.UI.Shopping.UpdateShoppingList()
  end)
  WSGH.UI.Shopping.itemDataListener = listener
end

EnsureItemDataListener()

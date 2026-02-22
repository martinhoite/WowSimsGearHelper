local WSGH = _G.WowSimsGearHelper or {}
WSGH.UI = WSGH.UI or {}
WSGH.UI.Shopping = WSGH.UI.Shopping or {}

local DEBUG_SHOPPING = false
local AUCTION_WON_PATTERNS = {}

local function DebugShopping(msg)
  if not DEBUG_SHOPPING then return end
  if WSGH and WSGH.Util and WSGH.Util.Print then
    WSGH.Util.Print("[Shopping] " .. tostring(msg))
  end
end

local function NormalizeName(text)
  if type(text) ~= "string" then return "" end
  text = text:lower()
  text = text:gsub("%s+", " ")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

local function BuildAuctionWonPatterns()
  wipe(AUCTION_WON_PATTERNS)
  if type(ERR_AUCTION_WON_S) == "string" then
    AUCTION_WON_PATTERNS[#AUCTION_WON_PATTERNS + 1] = "^" .. ERR_AUCTION_WON_S:gsub("%%s", "(.+)") .. "$"
  end
  AUCTION_WON_PATTERNS[#AUCTION_WON_PATTERNS + 1] = "|Hitem:%d+.-|h%[[^]]+%]|h"
end

local function ResolveKnownNeededItemIdByName(itemName)
  if type(itemName) ~= "string" or itemName == "" then return 0 end
  local wantedName = NormalizeName(itemName)
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
    if knownName and NormalizeName(knownName) == wantedName then
      return itemId
    end
  end

  return 0
end

local function HandleAuctionWonMessage(message)
  if not message then return end
  if #AUCTION_WON_PATTERNS == 0 then
    BuildAuctionWonPatterns()
  end
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
      WSGH.UI.pendingPurchasesByName[bracketName] = nil
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

local function IsAuctionHouseOpen()
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then return true end
  if AuctionFrame and AuctionFrame:IsShown() then return true end
  return false
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
  if last.itemId == itemId and last.count == count and (now - (last.time or 0)) < 1.0 then
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
  WSGH.UI.pendingPurchasesByName = WSGH.UI.pendingPurchasesByName or {}
  WSGH.UI.pendingPurchasesByName[itemName] = (WSGH.UI.pendingPurchasesByName[itemName] or 0) + count
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

  local categoryOrder = WSGH.Const and WSGH.Const.UI and WSGH.Const.UI.shopping and WSGH.Const.UI.shopping.categories or { "Gems", "Enchants", "Other" }
  local itemsByCategory = {}
  for _, cat in ipairs(categoryOrder) do itemsByCategory[cat] = {} end
  itemsByCategory["Other"] = itemsByCategory["Other"] or {}

  if diff and diff.rows then
    for _, row in ipairs(diff.rows) do
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
      local bought = math.min(pending, remaining)
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
  local height = padding + (title and title:GetStringHeight() or 0) + 6

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
          local isFullyPurchased = (tonumber(data.bought) or 0) >= (tonumber(data.totalNeeded) or 0) and (tonumber(data.totalNeeded) or 0) > 0
          if isFullyPurchased then
            entry.text:SetTextColor(0.72, 0.72, 0.72, 1)
            if entry.strike then
              entry.strike:ClearAllPoints()
              entry.strike:SetPoint("LEFT", entry.text, "LEFT", 0, 0)
              entry.strike:SetPoint("RIGHT", entry.count, "RIGHT", 0, 0)
              entry.strike:SetPoint("CENTER", entry.text, "CENTER", 0, 0)
              entry.strike:Show()
            end
          else
            entry.text:SetTextColor(1, 1, 1, 1)
            if entry.strike then entry.strike:Hide() end
          end
          local totalNeeded = tonumber(data.totalNeeded) or tonumber(data.count) or 0
          local bought = data.bought or 0
          if bought > totalNeeded then
            bought = totalNeeded
          end
          if bought > 0 then
            entry.count:SetText(("x%d (%d/%d bought)"):format(data.count, bought, totalNeeded))
          else
            entry.count:SetText("x" .. data.count)
          end
          entry.search:SetShown(true)
          entry.search:SetEnabled(true)
          entry.search.itemId = data.itemId
          entry.search:SetText("")
          entry.search:SetNormalTexture(WSGH.Const.ICON_SEARCH)
          local searchTexture = entry.search:GetNormalTexture()
          if searchTexture then
            searchTexture:SetVertexColor(1, 1, 1)
          end
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
      else
        entry:Hide()
        if entry.strike then entry.strike:Hide() end
        entry.search:SetShown(false)
      end
    end
    local rowsShown = math.min(visibleEntries, math.max(totalRows - offset, 0))
    height = height + (rowsShown * entryHeight) + padding
  end

  local minWidth = (WSGH.Const and WSGH.Const.UI and WSGH.Const.UI.shopping and WSGH.Const.UI.shopping.sidebarWidth) or 220
  local targetWidth = math.max(minWidth, maxRowWidth)
  frame:SetWidth(targetWidth)
  for _, entry in ipairs(entries) do
    entry:SetWidth(targetWidth - 24)
    local countWidth = entry.count:GetStringWidth() or 0
    local buttonWidth = entry.search:GetWidth() or 0
    local availableTextWidth = targetWidth - 24 - (16 + 6) - (countWidth + 8) - (buttonWidth + 8)
    entry.text:SetWidth(math.max(availableTextWidth, 50))
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
  listener:RegisterEvent("CHAT_MSG_SYSTEM")
  listener:RegisterEvent("CHAT_MSG_LOOT")
  listener:SetScript("OnEvent", function(_, event, ...)
    if event == "AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION" or event == "AUCTION_HOUSE_SHOW_ITEM_WON_NOTIFICATION" then
      local itemRef, quantity = ...
      local itemId = ExtractItemIdFromAuctionRef(itemRef)
      local count = tonumber(quantity) or tonumber((type(itemRef) == "table" and (itemRef.quantity or itemRef.stackSize)) or 0) or 1
      if itemId and itemId ~= 0 then
        WSGH.UI.Shopping.RecordAuctionWin(itemId, count)
      end
    elseif event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_LOOT" then
      local message = ...
      HandleAuctionWonMessage(message)
    end
  end)
  WSGH.UI.Shopping.purchaseListener = listener
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

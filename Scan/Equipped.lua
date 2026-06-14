local WSGH = _G.WowSimsGearHelper
WSGH.Scan = WSGH.Scan or {}
WSGH.Scan.Equipped = {}

-- Raw item-link enchant effect IDs that add an extra socket (even when empty).
local BELT_BUCKLE_ENCHANT_EFFECT_IDS = {
  [3729] = true, -- Eternal Belt Buckle (WotLK)
  [4217] = true, -- Ebonsteel Belt Buckle (Cata)
  [4314] = true, -- Living Steel Belt Buckle (MoP)
}

local function ExtractItemIdFromLink(link)
  if type(link) ~= "string" then return 0 end
  local itemString = link:match("item:([%-?%d:]+)")
  if not itemString then return 0 end
  local id = itemString:match("^([%-?%d]+)")
  return tonumber(id) or 0
end

local function ParseItemLink(link)
  -- item:ITEMID:ENCHANT:gem1:gem2:gem3:gem4:...
  if type(link) ~= "string" then
    return nil
  end

  local itemString = link:match("item:([%-?%d:]+)")
  if not itemString then
    return nil
  end

  local fields = { strsplit(":", itemString) }

  local itemId = tonumber(fields[1]) or 0
  local rawEnchantEffectId = tonumber(fields[2]) or 0
  local rawReforgeId = tonumber(fields[10]) or 0
  local enchantId = rawEnchantEffectId
  local reforgeId = 0

  -- Map item-link enchant effectIds to spellIds via shared data table.
  if WSGH.Data and WSGH.Data.Enchants and WSGH.Data.Enchants.NormalizeEffectId then
    enchantId = WSGH.Data.Enchants.NormalizeEffectId(enchantId)
  end
  if WSGH.Integrations and WSGH.Integrations.ReforgeLite and WSGH.Integrations.ReforgeLite.NormalizeReforgeId then
    reforgeId = WSGH.Integrations.ReforgeLite.NormalizeReforgeId(rawReforgeId)
  elseif rawReforgeId ~= 0 then
    local normalized = rawReforgeId - 112
    reforgeId = normalized > 0 and normalized or 0
  end

  -- Parse gem fields from the link first (preserves empty fields).
  local gemsByIndex = {}
  local maxGemSlot = 0
  for socketIndex = 1, 4 do
    local gemField = tonumber(fields[2 + socketIndex]) or 0
    if gemField ~= 0 then
      gemsByIndex[socketIndex] = gemField
      if socketIndex > maxGemSlot then maxGemSlot = socketIndex end
    end
  end

  -- Overlay with authoritative gem info if available (covers cached gem links/names).
  for socketIndex = 1, 4 do
    local gemLink = GetItemGem(link, socketIndex)
    local gemId = gemLink and select(1, GetItemInfoInstant(gemLink))
    if (not gemId or gemId == 0) and gemLink then
      gemId = ExtractItemIdFromLink(gemLink)
    end
    if gemId and gemId ~= 0 then
      gemsByIndex[socketIndex] = gemId
      if socketIndex > maxGemSlot then maxGemSlot = socketIndex end
    end
  end

  return {
    itemId = itemId,
    rawEnchantEffectId = rawEnchantEffectId,
    enchantId = enchantId,
    rawReforgeId = rawReforgeId,
    reforgeId = reforgeId,
    gemsByIndex = gemsByIndex,
    maxGemSlot = maxGemSlot,
  }
end

function WSGH.Scan.Equipped.GetState()
  local equipped = {}

  for _, slotMeta in ipairs(WSGH.Const.SLOT_ORDER) do
    local slotId = slotMeta.slotId
    local link = GetInventoryItemLink("player", slotId)
    local socketCount = 0
    local statsSocketCount = 0
    local emptySocketCount = 0
    local gemCount = 0
    local itemLevel = 0
    local tooltipSocketCount = 0
    local tooltipTinkerId = 0
    local tooltipUpgradeLevel = 0
    local tooltipUpgradeMax = 0
    local tooltipHasPrismaticSocket = false

    if link then
      local stats = GetItemStats(link) or {}
      for stat, value in pairs(stats) do
        if type(stat) == "string" and stat:find("^EMPTY_SOCKET_") then
          socketCount = socketCount + (tonumber(value) or 0)
          statsSocketCount = statsSocketCount + (tonumber(value) or 0)
          emptySocketCount = emptySocketCount + (tonumber(value) or 0)
        end
      end
      local detailed = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link) or nil
      itemLevel = tonumber(detailed) or select(4, GetItemInfo(link)) or 0
    end

    if link then
      local parsed = ParseItemLink(link) or {
        itemId = 0,
        rawEnchantEffectId = 0,
        enchantId = 0,
        rawReforgeId = 0,
        reforgeId = 0,
        gemsByIndex = {},
        maxGemSlot = 0,
      }
      local tooltipInfo = WSGH.Scan.Tooltip and WSGH.Scan.Tooltip.GetInventoryItemInfo and WSGH.Scan.Tooltip.GetInventoryItemInfo("player", slotId) or nil
      if tooltipInfo then
        tooltipSocketCount = tonumber(tooltipInfo.socketCount) or 0
        tooltipTinkerId = tonumber(tooltipInfo.tinkerId) or 0
        tooltipUpgradeLevel = tonumber(tooltipInfo.upgradeLevel) or 0
        tooltipUpgradeMax = tonumber(tooltipInfo.upgradeMax) or 0
        tooltipHasPrismaticSocket = tooltipInfo.hasPrismaticSocket == true
      end

      local entry = {
        slotKey = slotMeta.key,
        slotId = slotId,
        itemLink = link,
        itemId = parsed.itemId,
        enchantId = parsed.enchantId,
        rawReforgeId = parsed.rawReforgeId,
        reforgeId = parsed.reforgeId,
        gemsByIndex = parsed.gemsByIndex,
        socketCount = 0,
        statsSocketCount = statsSocketCount,
        parsedMaxGemSlot = parsed.maxGemSlot or 0,
        itemLevel = itemLevel,
        tooltipSocketCount = tooltipSocketCount,
        tinkerId = tooltipTinkerId,
        upgradeLevel = tooltipUpgradeLevel,
        upgradeMax = tooltipUpgradeMax,
        hasBeltBuckle = false,
      }
      for _ in pairs(parsed.gemsByIndex or {}) do
        gemCount = gemCount + 1
      end
      -- Tooltip socket lines only represent empty sockets, so they need to be
      -- combined with filled gem count for mixed states. Do not do the same for
      -- statsSocketCount: on MoP Classic, GetItemStats can still report
      -- EMPTY_SOCKET_* for already-filled sockets, which would double-count.
      local combinedTooltipAndGems = tooltipSocketCount + gemCount
      entry.socketCount = math.max(
        parsed.maxGemSlot or 0,
        statsSocketCount,
        tooltipSocketCount,
        gemCount,
        combinedTooltipAndGems
      )
      if slotId == 6 and (
        tooltipHasPrismaticSocket
        or tooltipSocketCount > statsSocketCount
      ) then
        entry.hasBeltBuckle = true
      else
        entry.hasBeltBuckle = BELT_BUCKLE_ENCHANT_EFFECT_IDS[tonumber(parsed.rawEnchantEffectId) or 0] == true
      end
      equipped[slotId] = entry
  else
      equipped[slotId] = {
        slotKey = slotMeta.key,
        slotId = slotId,
        itemLink = nil,
        itemId = 0,
        enchantId = 0,
        rawReforgeId = 0,
        reforgeId = 0,
        gemsByIndex = {},
        socketCount = 0,
        itemLevel = 0,
        hasBeltBuckle = false,
        tooltipSocketCount = 0,
        tinkerId = 0,
        upgradeLevel = 0,
        upgradeMax = 0,
      }
    end
  end

  return equipped
end

-- Debug helper: WSGH.Debug.DumpSlot(slotId)
WSGH.Debug = WSGH.Debug or {}
function WSGH.Debug.DumpSlot(slotId)
  slotId = tonumber(slotId) or 0
  if slotId == 0 then
    WSGH.Util.Print("DumpSlot: provide slotId (e.g., 6 for belt).")
    return
  end
  local link = GetInventoryItemLink("player", slotId)
  if not link then
    WSGH.Util.Print("DumpSlot: no item in slot " .. slotId)
    return
  end
  local itemString = link:match("item:([%-?%d:]+)") or ""
  local fields = { strsplit(":", itemString) }
  local itemId = tonumber(fields[1]) or 0
  local rawEnchantEffectId = tonumber(fields[2]) or 0
  local rawReforgeId = tonumber(fields[10]) or 0
  local gems = {}
  for i = 1, 4 do
    gems[i] = tonumber(fields[2 + i]) or 0
  end
  local parsed = ParseItemLink(link) or {
    itemId = itemId,
    rawEnchantEffectId = rawEnchantEffectId,
    enchantId = rawEnchantEffectId,
    rawReforgeId = rawReforgeId,
    reforgeId = 0,
    gemsByIndex = {},
    maxGemSlot = 0,
  }
  local gemsPresent = 0
  for _, gid in pairs(parsed.gemsByIndex or {}) do
    if gid and gid ~= 0 then gemsPresent = gemsPresent + 1 end
  end
  local gemLinks = {}
  for i = 1, 4 do
    gemLinks[i] = GetItemGem(link, i) or "nil"
  end
  local stats = GetItemStats(link) or {}
  local statsSocketCount = 0
  local emptySocketCount = 0
  for stat, value in pairs(stats) do
    if type(stat) == "string" and stat:find("^EMPTY_SOCKET_") then
      local v = tonumber(value) or 0
      statsSocketCount = statsSocketCount + v
      emptySocketCount = emptySocketCount + v
    end
  end
  local tooltipInfo = WSGH.Scan.Tooltip and WSGH.Scan.Tooltip.GetInventoryItemInfo and WSGH.Scan.Tooltip.GetInventoryItemInfo("player", slotId) or nil
  local tooltipSocketCount = tooltipInfo and tonumber(tooltipInfo.socketCount) or 0
  local tooltipTinkerId = tooltipInfo and tonumber(tooltipInfo.tinkerId) or 0
  local tooltipUpgradeLevel = tooltipInfo and tonumber(tooltipInfo.upgradeLevel) or 0
  local tooltipUpgradeMax = tooltipInfo and tonumber(tooltipInfo.upgradeMax) or 0
  local tooltipHasPrismaticSocket = tooltipInfo and tooltipInfo.hasPrismaticSocket == true or false
  local socketCount = math.max(
    parsed.maxGemSlot or 0,
    statsSocketCount,
    tooltipSocketCount,
    gemsPresent,
    (tooltipSocketCount + gemsPresent)
  )
  local itemLevel = tonumber(GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)) or select(4, GetItemInfo(link)) or 0

  WSGH.Util.Print(("DumpSlot %d: itemId=%d enchantEffectId=%d normalizedEnchantId=%d reforgeRaw=%d reforge=%d link=%s"):format(
    slotId,
    itemId,
    rawEnchantEffectId,
    tonumber(parsed.enchantId) or 0,
    tonumber(parsed.rawReforgeId) or rawReforgeId,
    tonumber(parsed.reforgeId) or 0,
    link
  ))
  WSGH.Util.Print(("Gems from link: %d, %d, %d, %d"):format(gems[1], gems[2], gems[3], gems[4]))
  WSGH.Util.Print(("Gem links: %s | %s | %s | %s"):format(gemLinks[1], gemLinks[2], gemLinks[3], gemLinks[4]))
  WSGH.Util.Print(("Gem count (parsed): %d"):format(gemsPresent))
  WSGH.Util.Print(("Socket counts: stats=%d emptyStats=%d parsedMax=%d total=%d"):format(
    statsSocketCount,
    emptySocketCount,
    parsed.maxGemSlot or 0,
    socketCount
  ))
  WSGH.Util.Print(("Tooltip sockets: %d"):format(tooltipSocketCount))
  WSGH.Util.Print(("Tooltip hasPrismaticSocket: %s"):format(tostring(tooltipHasPrismaticSocket)))
  WSGH.Util.Print(("Tooltip tinkerId: %d"):format(tooltipTinkerId))
  WSGH.Util.Print(("Tooltip upgrade: %d/%d"):format(tooltipUpgradeLevel, tooltipUpgradeMax))
  WSGH.Util.Print(("Item level: %d"):format(itemLevel))
  for stat, value in pairs(stats) do
    if type(stat) == "string" and stat:find("SOCKET") then
      WSGH.Util.Print(("Stat %s = %s"):format(stat, tostring(value)))
    end
  end
end

function WSGH.Debug.DumpBagButtonsForItem(itemId)
  itemId = tonumber(itemId) or 0
  if itemId == 0 then
    WSGH.Util.Print("DumpBagButtonsForItem: provide an itemId.")
    return
  end
  local bagIndex = WSGH.Scan.GetBagIndex and WSGH.Scan.GetBagIndex() or {}
  local locations = bagIndex[itemId] or {}
  if #locations == 0 then
    WSGH.Util.Print(("DumpBagButtonsForItem %d: not found in bags."):format(itemId))
    return
  end
  for _, loc in ipairs(locations) do
    local btn = nil
    if NUM_CONTAINER_FRAMES then
      for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() and frame:GetID() == loc.bag then
          local name = frame:GetName() .. "Item" .. loc.slot
          btn = _G[name]
          break
        end
      end
    end
    WSGH.Util.Print(("Item %d at bag %d slot %d -> button %s"):format(
      itemId,
      tonumber(loc.bag) or -1,
      tonumber(loc.slot) or -1,
      btn and btn:GetName() or "nil"
    ))
  end
end

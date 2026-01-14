local WSGH = _G.WowSimsGearHelper
WSGH.Scan = WSGH.Scan or {}
WSGH.Scan.Bags = {}

local function GetContainerNumSlotsCompat(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end

local function GetContainerItemIdCompat(bag, slot)
  if C_Container and C_Container.GetContainerItemID then
    return C_Container.GetContainerItemID(bag, slot)
  end
  if GetContainerItemID then
    return GetContainerItemID(bag, slot)
  end
  return nil
end

local function GetContainerItemInfoCompat(bag, slot)
  -- We do not need full item info yet, but this is useful later for counts/stacks.
  if C_Container and C_Container.GetContainerItemInfo then
    return C_Container.GetContainerItemInfo(bag, slot)
  end
  if GetContainerItemInfo then
    return GetContainerItemInfo(bag, slot)
  end
  return nil
end

function WSGH.Scan.Bags.BuildIndex()
  -- index[itemId] = { {bag=0, slot=1, count=2}, ... }
  local index = {}

  for bag = 0, 4 do
    local slots = GetContainerNumSlotsCompat(bag)
    for slot = 1, slots do
      local itemId = GetContainerItemIdCompat(bag, slot)
      if itemId then
        local count = 1

        local info = GetContainerItemInfoCompat(bag, slot)
        if type(info) == "table" and info.stackCount then
          count = info.stackCount
        elseif type(info) == "table" and info[2] then
          -- Legacy GetContainerItemInfo sometimes returns multiple values, but in some clients
          -- it can also be a table. If it is a table, the stack count is often in [2].
          count = tonumber(info[2]) or count
        end

        index[itemId] = index[itemId] or {}
        table.insert(index[itemId], {
          bag = bag,
          slot = slot,
          count = count
        })
      end
    end
  end

  return index
end

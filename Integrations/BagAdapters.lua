local WSGH = _G.WowSimsGearHelper or {}
WSGH.UI = WSGH.UI or {}
WSGH.UI.BagAdapters = WSGH.UI.BagAdapters or {}

-- Bag addon integration helpers (ElvUI, ArkInventory, Baganator, Bagnon, BetterBags, default bags).
local adapters = WSGH.UI.BagAdapters

local bagShowHooked = false
local arkBagShowHooked = false
local arkGenerateHooked = false
local arkMessageHooked = false
local baganatorBagShowHooked = false
local bagnonShowHooked = false
local betterBagsShowHooked = false

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

local function GetElvuiBagsModule()
  local elv = _G.ElvUI
  if type(elv) ~= "table" then return nil end
  local E = elv[1] or elv
  if type(E) ~= "table" or not E.GetModule then return nil end
  local ok, mod = pcall(E.GetModule, E, "Bags", true)
  if ok then return mod end
  return nil
end

local function ElvuiBagVisible()
  local mod = GetElvuiBagsModule()
  if not mod then return false end
  local frame = mod.BagFrame
  return frame and frame:IsShown() or false
end

local function ArkInventoryBagVisible()
  local ark = _G.ArkInventory
  if not (ark and ark.Frame_Main_Get and ark.Const and ark.Const.Location) then
    return false
  end
  local ok, frame = pcall(ark.Frame_Main_Get, ark.Const.Location.Bag)
  if ok and frame and frame:IsVisible() then
    return true
  end
  return false
end

function adapters.IsArkInventoryVisible()
  return ArkInventoryBagVisible()
end

local function GetBaganatorBackpackFrame()
  if not EnumerateFrames then return nil end
  local fallback
  local frame = EnumerateFrames()
  while frame do
    local name = frame.GetName and frame:GetName() or nil
    if name and (name:find("^Baganator_SingleViewBackpackViewFrame") or name:find("^Baganator_CategoryViewBackpackViewFrame")) then
      local isBackpackFrame = frame.Container and (frame.Container.BagLive or frame.Container.Layouts)
      if isBackpackFrame then
        fallback = fallback or frame
        if frame:IsShown() then
          return frame
        end
      end
    end
    frame = EnumerateFrames(frame)
  end
  return fallback
end

local function BaganatorBagVisible()
  if not _G.Baganator then return false end
  local frame = GetBaganatorBackpackFrame()
  return frame and frame:IsShown() or false
end

local function GetBetterBagsAddon()
  if not LibStub then return nil end
  local ace = LibStub("AceAddon-3.0", true)
  if not ace then return nil end
  local ok, addon = pcall(ace.GetAddon, ace, "BetterBags")
  if ok then return addon end
  return nil
end

local function GetBetterBagsBackpack()
  local addon = GetBetterBagsAddon()
  return addon and addon.Bags and addon.Bags.Backpack or nil
end

local function BetterBagsVisible()
  local bag = GetBetterBagsBackpack()
  if not bag then return false end
  if bag.IsShown then
    return bag:IsShown()
  end
  local frame = bag.frame
  return frame and frame.IsShown and frame:IsShown() or false
end

local function GetBagnonInventoryFrame()
  local bagnon = _G.Bagnon
  if not (bagnon and bagnon.Frames and bagnon.Frames.Get) then
    return nil
  end
  local ok, frame = pcall(bagnon.Frames.Get, bagnon.Frames, "inventory")
  if ok then
    return frame
  end
  return nil
end

local function BagnonBagVisible()
  local bagnon = _G.Bagnon
  if not (bagnon and bagnon.Frames and bagnon.Frames.IsShown) then
    return false
  end
  local ok, shown = pcall(bagnon.Frames.IsShown, bagnon.Frames, "inventory")
  if ok and shown then
    return true
  end
  local frame = GetBagnonInventoryFrame()
  return frame and frame.IsShown and frame:IsShown() or false
end

function adapters.AreBagFramesVisible()
  if ElvuiBagVisible() then return true end
  if ArkInventoryBagVisible() then return true end
  if BaganatorBagVisible() then return true end
  if BetterBagsVisible() then return true end
  if BagnonBagVisible() then return true end
  if not NUM_CONTAINER_FRAMES then return false end
  for i = 1, NUM_CONTAINER_FRAMES do
    local frame = _G["ContainerFrame" .. i]
    if frame and frame:IsShown() then
      return true
    end
  end
  return false
end

local function BuildBaganatorItemIndex(frame)
  local index = {}
  if not (frame and EnumerateFrames) then
    return index
  end
  local function IsDescendantOfFrame(child, parent)
    if not (child and parent) then return false end
    if child.IsDescendantOf then
      return child:IsDescendantOf(parent)
    end
    local cur = child
    while cur and cur.GetParent do
      cur = cur:GetParent()
      if cur == parent then
        return true
      end
    end
    return false
  end
  local btn = EnumerateFrames()
  while btn do
    if btn.IsShown and btn:IsShown() and btn.BGR and btn.GetID and btn.GetParent and IsDescendantOfFrame(btn, frame) then
      local parent = btn:GetParent()
      local bagId = nil
      local slotId = nil
      if btn.BGR and btn.BGR.itemLocation then
        bagId = btn.BGR.itemLocation.bagID
        slotId = btn.BGR.itemLocation.slotIndex
      else
        bagId = parent and parent.GetID and parent:GetID() or nil
        slotId = btn:GetID()
      end
      local itemId = nil
      local bagSlots = (bagId and GetContainerNumSlotsCompat(bagId)) or 0
      if bagSlots > 0 and slotId and slotId <= bagSlots then
        itemId = GetContainerItemIdCompat(bagId, slotId)
      end
      if (not itemId or itemId == 0) and btn.BGR then
        itemId = btn.BGR.itemID
      end
      if itemId and itemId ~= 0 then
        index[itemId] = index[itemId] or {}
        index[itemId][#index[itemId] + 1] = btn
      end
    end
    btn = EnumerateFrames(btn)
  end
  return index
end

local function BuildElvuiItemIndex()
  local index = {}
  local elvBags = GetElvuiBagsModule()
  if not (elvBags and elvBags.BagFrame and elvBags.BagFrame:IsShown()) then
    return index
  end
  local bags = elvBags.BagFrame.Bags or {}
  for _, bag in pairs(bags) do
    if type(bag) == "table" then
      for _, slot in ipairs(bag) do
        if slot and slot.IsShown and slot:IsShown() then
          local itemId = slot.itemID or nil
          if not itemId or itemId == 0 then
            local bagId = slot.BagID
            local slotId = slot.SlotID
            itemId = (bagId and slotId) and GetContainerItemIdCompat(bagId, slotId) or nil
          end
          if itemId and itemId ~= 0 then
            index[itemId] = index[itemId] or {}
            index[itemId][#index[itemId] + 1] = slot
          end
        end
      end
    end
  end
  return index
end

local function BuildBetterBagsItemIndex(bag)
  local index = {}
  if not bag then return index end
  local view = bag.currentView
  if not (view and view.GetItemsByBagAndSlot) then
    return index
  end
  local itemsBySlot = view:GetItemsByBagAndSlot() or {}
  for slotkey, item in pairs(itemsBySlot) do
    local button = item and item.button or nil
    local frame = item and item.frame or nil
    if (button or frame) and ((button and button.IsShown and button:IsShown()) or (frame and frame.IsShown and frame:IsShown())) then
      local bagId, slotId = nil, nil
      if view.ParseSlotKey and slotkey then
        bagId, slotId = view:ParseSlotKey(slotkey)
      end
      local itemId = nil
      if item and item.GetItemData then
        local data = item:GetItemData()
        itemId = data and data.itemInfo and data.itemInfo.itemID or nil
      end
      if (not itemId or itemId == 0) and bagId and slotId then
        itemId = GetContainerItemIdCompat(bagId, slotId)
      end
      if itemId and itemId ~= 0 then
        local target = button or frame
        index[itemId] = index[itemId] or {}
        index[itemId][#index[itemId] + 1] = target
      end
    end
  end
  return index
end

local function BuildBagnonItemIndex(frame)
  local index = {}
  if not frame then return index end
  local group = frame.ItemGroup
  local buttons = group and group.buttons or nil
  if not buttons then
    return index
  end
  for _, btn in ipairs(buttons) do
    if btn and btn.IsShown and btn:IsShown() then
      local bagId = btn.bag
      local slotId = btn.GetID and btn:GetID() or nil
      local itemId = nil
      local bagSlots = (bagId and GetContainerNumSlotsCompat(bagId)) or 0
      if bagSlots > 0 and slotId and slotId <= bagSlots then
        itemId = GetContainerItemIdCompat(bagId, slotId)
      end
      if (not itemId or itemId == 0) and btn.info then
        itemId = btn.info.itemID
      end
      if itemId and itemId ~= 0 then
        index[itemId] = index[itemId] or {}
        index[itemId][#index[itemId] + 1] = btn
      end
    end
  end
  return index
end

local function BuildArkInventoryItemIndex()
  local index = {}
  local ark = _G.ArkInventory
  if not (ark and ark.API and ark.API.ItemFrameLoadedIterate and ark.Const and ark.Const.Location) then
    return index
  end
  local ok, bagFrame = pcall(ark.Frame_Main_Get, ark.Const.Location.Bag)
  if not (ok and bagFrame and bagFrame:IsVisible()) then
    return index
  end
  for _, frame, loc_id_window, bag_id_window, slot_id in ark.API.ItemFrameLoadedIterate(ark.Const.Location.Bag) do
    if frame and frame:IsVisible() then
      local blizzardBagId = frame.ARK_Data and frame.ARK_Data.blizzard_id or nil
      if not blizzardBagId and ark.API.getBlizzardBagIdFromWindowId then
        local okMap, mapped = pcall(ark.API.getBlizzardBagIdFromWindowId, loc_id_window, bag_id_window)
        if okMap then
          blizzardBagId = mapped
        end
      end
      local itemId = blizzardBagId and slot_id and GetContainerItemIdCompat(blizzardBagId, slot_id) or nil
      if not itemId or itemId == 0 then
        local item = ark.API.ItemFrameItemTableGet and ark.API.ItemFrameItemTableGet(frame) or nil
        local link = item and item.h or nil
        itemId = link and select(2, GetItemInfoInstant(link)) or nil
      end
      if itemId and itemId ~= 0 then
        index[itemId] = index[itemId] or {}
        index[itemId][#index[itemId] + 1] = frame
      end
    end
  end
  return index
end

function adapters.BuildVisibleBagButtonIndex()
  local index = {}
  if ArkInventoryBagVisible() then
    local arkIndex = BuildArkInventoryItemIndex()
    if next(arkIndex) then
      return arkIndex
    end
  end
  if ElvuiBagVisible() then
    local elvIndex = BuildElvuiItemIndex()
    if next(elvIndex) then
      return elvIndex
    end
  end
  if BaganatorBagVisible() then
    local baganatorFrame = GetBaganatorBackpackFrame()
    if baganatorFrame then
      return BuildBaganatorItemIndex(baganatorFrame)
    end
  end
  if BetterBagsVisible() then
    local betterBags = GetBetterBagsBackpack()
    if betterBags then
      return BuildBetterBagsItemIndex(betterBags)
    end
  end
  if BagnonBagVisible() then
    local bagnonFrame = GetBagnonInventoryFrame()
    if bagnonFrame then
      return BuildBagnonItemIndex(bagnonFrame)
    end
  end
  if not NUM_CONTAINER_FRAMES then return index end
  for frameIndex = 1, NUM_CONTAINER_FRAMES do
    local frame = _G["ContainerFrame" .. frameIndex]
    if frame and frame:IsShown() then
      local bagId = frame:GetID()
      local slots = GetContainerNumSlotsCompat(bagId)
      for buttonIndex = 1, slots do
        local btn = _G[frame:GetName() .. "Item" .. buttonIndex]
        if btn then
          local slotId = btn.GetID and btn:GetID() or nil
          if not slotId or slotId == 0 then
            slotId = (slots - buttonIndex + 1)
          end
          local itemId = GetContainerItemIdCompat(bagId, slotId)
          if itemId and itemId ~= 0 then
            index[itemId] = index[itemId] or {}
            index[itemId][#index[itemId] + 1] = btn
          end
        end
      end
    end
  end
  return index
end

function adapters.EnsureBagFrameShowHooks(onShow)
  if not bagShowHooked and hooksecurefunc and ContainerFrame_OnShow then
    bagShowHooked = true
    hooksecurefunc("ContainerFrame_OnShow", function()
      if onShow then onShow() end
    end)
  end
  if not arkMessageHooked then
    local ark = _G.ArkInventory
    if ark and ark.SendMessage and ark.Const and ark.Const.Location and hooksecurefunc then
      arkMessageHooked = true
      hooksecurefunc(ark, "SendMessage", function(_, message, loc_id)
        if not onShow then return end
        if message == "EVENT_ARKINV_LOCATION_DRAW_BUCKET"
          or message == "EVENT_ARKINV_BAG_OPEN_BUCKET"
          or message == "EVENT_ARKINV_ITEM_UPDATE_BUCKET"
          or message == "EVENT_ARKINV_BAG_UPDATE_BUCKET"
          or message == "EVENT_ARKINV_LOCATION_SCANNED_BUCKET" then
          if not loc_id or loc_id == ark.Const.Location.Bag then
            onShow()
          end
        end
      end)
    end
  end
  if not arkGenerateHooked then
    local ark = _G.ArkInventory
    if ark and ark.Frame_Main_Generate and ark.Const and ark.Const.Location and hooksecurefunc then
      arkGenerateHooked = true
      hooksecurefunc(ark, "Frame_Main_Generate", function(loc_id_window)
        if not onShow then return end
        if not loc_id_window or loc_id_window == ark.Const.Location.Bag then
          onShow()
        end
      end)
    end
  end
  if not arkBagShowHooked then
    local ark = _G.ArkInventory
    if ark and ark.Frame_Main_Get and ark.Const and ark.Const.Location then
      local ok, frame = pcall(ark.Frame_Main_Get, ark.Const.Location.Bag)
      if ok and frame and not frame.WSGHShowHooked then
        arkBagShowHooked = true
        frame.WSGHShowHooked = true
        frame:HookScript("OnShow", function()
          if onShow then onShow() end
        end)
      end
    end
  end
  if _G.Baganator and EnumerateFrames then
    local frame = EnumerateFrames()
    while frame do
      local name = frame.GetName and frame:GetName() or nil
      if name and (name:find("^Baganator_SingleViewBackpackViewFrame") or name:find("^Baganator_CategoryViewBackpackViewFrame")) then
        if frame.Container and (frame.Container.BagLive or frame.Container.Layouts) and not frame.WSGHShowHooked then
          frame.WSGHShowHooked = true
          frame:HookScript("OnShow", function()
            if onShow then onShow() end
          end)
        end
      end
      frame = EnumerateFrames(frame)
    end
  end
  if not betterBagsShowHooked then
    local bag = GetBetterBagsBackpack()
    local frame = bag and bag.frame or nil
    if frame and frame.HookScript and not frame.WSGHShowHooked then
      betterBagsShowHooked = true
      frame.WSGHShowHooked = true
      frame:HookScript("OnShow", function()
        if onShow then onShow() end
      end)
    end
  end
  if not bagnonShowHooked then
    local bagnon = _G.Bagnon
    if bagnon and bagnon.Frames then
      bagnonShowHooked = true
      if bagnon.Frames.Show then
        hooksecurefunc(bagnon.Frames, "Show", function(_, id)
          if id == "inventory" and onShow then
            onShow()
          end
        end)
      end
      local frame = GetBagnonInventoryFrame()
      if frame and frame.HookScript and not frame.WSGHShowHooked then
        frame.WSGHShowHooked = true
        frame:HookScript("OnShow", function()
          if onShow then onShow() end
        end)
      end
    end
  end
  if not NUM_CONTAINER_FRAMES then return end
  for i = 1, NUM_CONTAINER_FRAMES do
    local frame = _G["ContainerFrame" .. i]
    if frame and not frame.WSGHShowHooked then
      frame.WSGHShowHooked = true
      frame:HookScript("OnShow", function()
        if onShow then onShow() end
      end)
    end
  end
end

local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Integrations = WSGH.Integrations or {}

local ReforgeLiteIntegration = WSGH.Integrations.ReforgeLite or {}
WSGH.Integrations.ReforgeLite = ReforgeLiteIntegration

local REFORGE_TABLE_BASE = 112
local WOWSIMS_METHOD_ORIGIN = "WoWSims"

local function GetPreferences()
  return WSGH.Util and WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
end

local function GetReforgeLite()
  local addon = _G.ReforgeLite
  if addon and type(addon.ValidateWoWSimsString) == "function" and type(addon.ApplyWoWSimsImport) == "function" then
    return addon
  end

  local loaded = false
  if C_AddOns and C_AddOns.LoadAddOn then
    loaded = pcall(C_AddOns.LoadAddOn, "ReforgeLite")
  elseif LoadAddOn then
    loaded = pcall(LoadAddOn, "ReforgeLite")
  end

  if loaded then
    addon = _G.ReforgeLite
    if addon and type(addon.ValidateWoWSimsString) == "function" and type(addon.ApplyWoWSimsImport) == "function" then
      return addon
    end
  end

  return nil
end

local function GetSlotIndex(slotId)
  slotId = tonumber(slotId) or 0
  return WSGH.Const and WSGH.Const.SLOT_INDEX_BY_ID and WSGH.Const.SLOT_INDEX_BY_ID[slotId] or nil
end

local function RebuildDiffSoon()
  if not (WSGH.State and WSGH.State.plan and WSGH.UI and WSGH.UI.RebuildAndRefresh) then
    return
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0.1, function()
      if WSGH.State and WSGH.State.plan and WSGH.UI and WSGH.UI.RebuildAndRefresh then
        WSGH.UI.RebuildAndRefresh()
      end
    end)
    return
  end
  WSGH.UI.RebuildAndRefresh()
end

local function HasSyncedWoWSimsMethod(addon)
  return addon
    and addon.pdb
    and addon.pdb.method
    and addon.pdb.method.items
    and addon.pdb.methodOrigin == WOWSIMS_METHOD_ORIGIN
end

local function ShowMethodWindowOnly(addon)
  if not HasSyncedWoWSimsMethod(addon) then
    return false, "missing-method"
  end

  if type(addon.Initialize) == "function" then
    pcall(addon.Initialize, addon)
  end
  if type(addon.UpdateItems) == "function" then
    pcall(addon.UpdateItems, addon)
  end
  if type(addon.ShowMethodWindow) ~= "function" then
    return false, "missing-window"
  end

  local shown, showErr = pcall(addon.ShowMethodWindow, addon)
  if not shown then
    return false, showErr
  end

  return true
end

local function ShowSyncedMethodWindowSoon()
  local function show()
    local addon = GetReforgeLite()
    if not HasSyncedWoWSimsMethod(addon) then
      return
    end
    ShowMethodWindowOnly(addon)
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, show)
    return
  end
  show()
end

local function ShouldMinimizeAtForge()
  local preferences = GetPreferences()
  return not preferences or preferences.minimizeWindowAtReforgeNpc ~= false
end

local function ShouldRestoreAfterForge()
  local preferences = GetPreferences()
  return preferences and preferences.restoreWindowAfterReforgeNpc == true
end

function ReforgeLiteIntegration.NormalizeReforgeId(rawReforgeId)
  rawReforgeId = tonumber(rawReforgeId) or 0
  if rawReforgeId == 0 then return 0 end

  local normalized = rawReforgeId - REFORGE_TABLE_BASE
  if normalized <= 0 then return 0 end
  return normalized
end

function ReforgeLiteIntegration.IsSyncEnabled()
  local preferences = GetPreferences()
  return not preferences or preferences.syncImportsToReforgeLite ~= false
end

function ReforgeLiteIntegration.IsAvailable()
  return GetReforgeLite() ~= nil
end

function ReforgeLiteIntegration.SyncImport(rawJson)
  if not ReforgeLiteIntegration.IsSyncEnabled() then
    return false, "disabled"
  end
  if type(rawJson) ~= "string" or rawJson == "" then
    return false, "empty"
  end

  local addon = GetReforgeLite()
  if not addon then
    return false, "missing"
  end

  if type(addon.Initialize) == "function" then
    pcall(addon.Initialize, addon)
  end
  if type(addon.UpdateItems) == "function" then
    pcall(addon.UpdateItems, addon)
  end

  local ok, valid, parsed = pcall(addon.ValidateWoWSimsString, addon, rawJson)
  if not ok then
    return false, valid
  end
  if not valid then
    return false, parsed
  end

  local originalShowMethodWindow = addon.ShowMethodWindow
  local shouldSuppressWindow = type(originalShowMethodWindow) == "function"
  if shouldSuppressWindow then
    addon.ShowMethodWindow = function() end
  end

  local applied, applyErr = pcall(addon.ApplyWoWSimsImport, addon, parsed)
  if shouldSuppressWindow then
    addon.ShowMethodWindow = originalShowMethodWindow
  end
  if not applied then
    return false, applyErr
  end

  return true
end

function ReforgeLiteIntegration.GetMethodItem(slotId)
  local addon = GetReforgeLite()
  local slotIndex = GetSlotIndex(slotId)
  if not (addon and slotIndex and addon.pdb and addon.pdb.method and addon.pdb.method.items) then
    return nil, nil
  end
  return addon.pdb.method.items[slotIndex], addon
end

function ReforgeLiteIntegration.GetReforgeDescription(reforgeId, slotId)
  local addon = GetReforgeLite()
  if not addon then
    return nil
  end

  local expectedReforgeId = tonumber(reforgeId) or 0
  if expectedReforgeId == 0 then
    return "No reforge"
  end

  local methodItem = select(1, ReforgeLiteIntegration.GetMethodItem(slotId))
  local methodMatches = methodItem and tonumber(methodItem.reforge) == expectedReforgeId
  local src = methodMatches and tonumber(methodItem.src) or 0
  local dst = methodMatches and tonumber(methodItem.dst) or 0
  local amount = methodMatches and tonumber(methodItem.amount) or 0

  if src == 0 or dst == 0 then
    local reforgeInfo = addon.reforgeTable and addon.reforgeTable[expectedReforgeId] or nil
    if type(reforgeInfo) == "table" then
      src = tonumber(reforgeInfo[1]) or 0
      dst = tonumber(reforgeInfo[2]) or 0
    end
  end

  if src == 0 or dst == 0 then
    return nil
  end

  local itemStats = addon.itemStats or {}
  local srcInfo = itemStats[src] or {}
  local dstInfo = itemStats[dst] or {}
  local srcName = srcInfo.long or srcInfo.name or ("stat " .. tostring(src))
  local dstName = dstInfo.long or dstInfo.name or ("stat " .. tostring(dst))

  if amount > 0 then
    return ("%d %s > %s"):format(amount, srcName, dstName)
  end
  return ("%s > %s"):format(srcName, dstName)
end

function ReforgeLiteIntegration.OpenOrGuide()
  local addon = GetReforgeLite()
  if not addon then
    WSGH.Util.Print("ReforgeLite not found. Install or enable ReforgeLite Classic to use synced reforges.")
    return false
  end

  local shown, showErr = ShowMethodWindowOnly(addon)
  if not shown then
    if showErr ~= "missing-method" and showErr ~= "missing-window" then
      WSGH.Util.Print("ReforgeLite could not open the synced WowSims output window: " .. tostring(showErr))
      return false
    end
    WSGH.Util.Print("ReforgeLite has no synced WowSims output window ready. Open ReforgeLite and import the plan there.")
    return false
  end

  WSGH.Util.Print("Use ReforgeLite to apply the synced WowSims reforge plan. WSGH will see the changes after reforging.")
  return true
end

function ReforgeLiteIntegration.Initialize()
  if ReforgeLiteIntegration.eventFrame then return end

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("FORGE_MASTER_OPENED")
  frame:RegisterEvent("FORGE_MASTER_ITEM_CHANGED")
  frame:RegisterEvent("FORGE_MASTER_CLOSED")
  frame:SetScript("OnEvent", function(_, event)
    if event == "FORGE_MASTER_OPENED" then
      if ReforgeLiteIntegration.IsSyncEnabled() and ReforgeLiteIntegration.IsAvailable() then
        if ShouldMinimizeAtForge() and WSGH.UI and WSGH.UI.frame and WSGH.UI.frame:IsShown() then
          if WSGH.UI.SetMinimizedForReforge then
            WSGH.UI.SetMinimizedForReforge(true)
          end
        elseif WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.ClearAll then
          WSGH.UI.Highlight.ClearAll()
        end
        ShowSyncedMethodWindowSoon()
      end
      RebuildDiffSoon()
      return
    end

    if event == "FORGE_MASTER_ITEM_CHANGED" or event == "FORGE_MASTER_CLOSED" then
      if event == "FORGE_MASTER_CLOSED"
        and ShouldRestoreAfterForge()
        and WSGH.UI
        and WSGH.UI.SetMinimizedForReforge then
        WSGH.UI.SetMinimizedForReforge(false)
      end
      RebuildDiffSoon()
    end
  end)

  ReforgeLiteIntegration.eventFrame = frame
end

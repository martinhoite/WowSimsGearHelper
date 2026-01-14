local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.UI = WSGH.UI or {}
WSGH.UI.Minimap = WSGH.UI.Minimap or {}

local minimap = WSGH.UI.Minimap
local initialized = false
local ICON_NAME = "WowSimsGearHelper"
local ICON_PATH = "Interface\\AddOns\\WowSimsGearHelper\\WowSimsGearHelper_icon"

local function GetPreferences()
  return WSGH.Util and WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
end

local function EnsureMinimapPrefs()
  local prefs = GetPreferences()
  if not prefs then return nil end
  prefs.minimap = prefs.minimap or {}
  if prefs.minimap.hide == nil then prefs.minimap.hide = false end
  return prefs
end

local function GetLDB()
  if not LibStub then return nil end
  return LibStub("LibDataBroker-1.1", true)
end

local function GetDBIcon()
  if not LibStub then return nil end
  return LibStub("LibDBIcon-1.0", true)
end

local function BuildDataObject()
  local LDB = GetLDB()
  if not LDB then return nil end
  if minimap.dataObject then return minimap.dataObject end

  minimap.dataObject = LDB:NewDataObject("WowSimsGearHelper", {
    type = "launcher",
    text = "WowSims Gear Helper",
    icon = ICON_PATH,
  })

  minimap.dataObject.OnClick = function(_, button)
    if button == "RightButton" then
      if WSGH.UI and WSGH.UI.OpenSettings then
        WSGH.UI.OpenSettings()
      end
    else
      if WSGH.UI and WSGH.UI.Toggle then
        WSGH.UI.Toggle()
      end
    end
  end

  minimap.dataObject.OnTooltipShow = function(tooltip)
    tooltip:AddLine("WowSims Gear Helper")
    tooltip:AddLine("Left click: |cffffd100Toggle addon|r", 1, 1, 1, true)
    tooltip:AddLine("Right click: |cffffd100Open settings|r", 1, 1, 1, true)
  end

  return minimap.dataObject
end

function minimap.Initialize()
  if initialized then return end
  initialized = true

  local prefs = EnsureMinimapPrefs()
  local dataObject = BuildDataObject()
  local icon = GetDBIcon()
  if not (prefs and dataObject and icon) then
    return
  end

  icon:Register(ICON_NAME, dataObject, prefs.minimap)
  minimap.RefreshIcon()
end

function minimap.RefreshIcon()
  local icon = GetDBIcon()
  if not icon then return end

  local prefs = EnsureMinimapPrefs()
  if not prefs then return end

  if prefs.minimap and prefs.minimap.hide then
    icon:Hide(ICON_NAME)
  else
    icon:Show(ICON_NAME)
  end
end

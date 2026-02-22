local ADDON_NAME = ...
local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH

WSGH.ADDON_NAME = ADDON_NAME
WSGH.VERSION = "0.0.4"

local function EnsureDB()
  if type(_G.WowSimsGearHelperDB) ~= "table" then
    _G.WowSimsGearHelperDB = {}
  end

  if type(_G.WowSimsGearHelperDB.profile) ~= "table" then
    _G.WowSimsGearHelperDB.profile = {}
  end

  if type(_G.WowSimsGearHelperDB.profile.ui) ~= "table" then
    _G.WowSimsGearHelperDB.profile.ui = {
      point = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
      shown = true
    }
  end

  if type(_G.WowSimsGearHelperDB.profile.prefs) ~= "table" then
    _G.WowSimsGearHelperDB.profile.prefs = {
      persistImports = false,
      savedImportText = nil,
      tinkers = {},
      upgradeCurrency = "JUSTICE",
      useValorForUpgrades = false,
    }
  end
  local prefs = _G.WowSimsGearHelperDB.profile.prefs
  if prefs.persistImports == nil then prefs.persistImports = false end
  if prefs.savedImportText == nil then prefs.savedImportText = nil end
  if prefs.tinkers == nil then prefs.tinkers = {} end
  if prefs.minimap == nil then prefs.minimap = { hide = false } end
  if prefs.minimap.hide == nil then prefs.minimap.hide = false end
  if prefs.upgradeCurrency == nil then prefs.upgradeCurrency = "JUSTICE" end
  if prefs.useValorForUpgrades == nil then prefs.useValorForUpgrades = (prefs.upgradeCurrency == "VALOR") end

  WSGH.DB = _G.WowSimsGearHelperDB
end

local function Print(msg)
  local prefix = ADDON_NAME or "WSGH"
  DEFAULT_CHAT_FRAME:AddMessage(("|cff33ff99%s|r: %s"):format(prefix, msg))
end

WSGH.Debug = WSGH.Debug or {}
function WSGH.Debug.List()
  local names = {
    "DumpSlot(slotId)",
    "DumpDiffRow(slotId)",
    "DebugSocketState(slotId)",
    "SocketDiagnostics()",
    "DumpShoppingEntries(maxEntries)",
    "DumpShoppingRow(index)",
    "DumpShoppingItem(itemId)",
    "TestSocket(slotId, socketIndex, gemId)",
  }
  Print("Debug helpers: " .. table.concat(names, ", "))
end

local function HandleSlash(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

  if msg == "" or msg == "toggle" then
    WSGH.UI.Toggle()
    return
  end

  if msg == "show" then
    WSGH.UI.Show()
    return
  end

  if msg == "hide" then
    WSGH.UI.Hide()
    return
  end

  if msg == "reset" then
    WSGH.UI.ResetPosition()
    Print("Position reset.")
    return
  end

  if msg == "testimport" then
    if WSGH.Import and WSGH.Import.__DebugTest then
      WSGH.Import.__DebugTest()
    else
      Print("Debug test is not available. Did you add __DebugTest() to Import.lua?")
    end
    return
  end

  if msg == "testbags" then
    local idx = WSGH.Scan.GetBagIndex()
    local distinct = WSGH.Util.TableCount(idx)
    Print("Bag index OK. Distinct itemIds: " .. tostring(distinct))
    return
  end
  
  if msg == "testgem" then
    local gemId = 76699
    local idx = WSGH.Scan.GetBagIndex()
    local locs = idx[gemId]
    if not locs then
      Print("Gem " .. gemId .. " not found in bags.")
      return
    end
    Print("Gem " .. gemId .. " found. Locations: " .. tostring(#locs))
    return
  end
  
  if msg == "testdiff" then
    if not (WSGH.Import and WSGH.Import.__DebugTest) then
      Print("Import debug not found. Keep __DebugTest for now.")
      return
    end
  
    -- Use the same JSON from __DebugTest, but return the plan instead.
    local json = [[
    {
      "apiVersion": 2,
      "player": {
        "class": "ClassMonk",
        "equipment": {
          "items": [
            { "id": 96641, "gems": [76884, 76699] },
            { "id": 89917 },
            {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
          ]
        }
      }
    }
    ]]
  
    local plan, err = WSGH.Import.FromJson(json)
    if not plan then
      Print("Import failed: " .. tostring(err))
      return
    end
  
    local diff, derr = WSGH.Diff.Engine.Build(plan, WSGH.Scan.GetEquipped(), WSGH.Scan.GetBagIndex())
    if not diff then
      Print("Diff failed: " .. tostring(derr))
      return
    end
  
    Print("Diff OK. Rows: " .. tostring(#diff.rows) .. ", Tasks: " .. tostring(diff.taskCount))
    return
  end

  Print("Commands: /wsgh [toggle, show, hide, reset]")
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")

events:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON_NAME then
    EnsureDB()
    if WSGH.UI and WSGH.UI.Settings and WSGH.UI.Settings.Initialize then
      WSGH.UI.Settings.Initialize()
    end
    WSGH.UI.Init()
    if WSGH.Scan and WSGH.Scan.Tooltip and WSGH.Scan.Tooltip.Initialize then
      WSGH.Scan.Tooltip.Initialize()
    end
    if WSGH.UI and WSGH.UI.Minimap and WSGH.UI.Minimap.Initialize then
      WSGH.UI.Minimap.Initialize()
    end

    SLASH_WOWSIMSGEARHELPER1 = "/wsgh"
    SlashCmdList.WOWSIMSGEARHELPER = HandleSlash

    if WSGH.DB.profile.ui.shown then
      WSGH.UI.Show()
    else
      WSGH.UI.Hide()
    end

    Print("Loaded. /wsgh to toggle.")
  end
end)

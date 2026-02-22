local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Util = WSGH.Util or {}

function WSGH.Util.Trim(s)
  if type(s) ~= "string" then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function WSGH.Util.SafeLower(s)
  if type(s) ~= "string" then return "" end
  return s:lower()
end

-- Normalizes item/recipe names for locale-safe comparisons.
-- Set stripPunctuation to true for looser matching (e.g., recipe names).
function WSGH.Util.NormalizeName(text, stripPunctuation)
  if type(text) ~= "string" then return "" end
  text = text:lower()
  if stripPunctuation then
    text = text:gsub("%b()", " ")
    text = text:gsub("[%c%p]", " ")
  end
  text = text:gsub("%s+", " ")
  return WSGH.Util.Trim(text)
end

function WSGH.Util.TableCount(t)
  if type(t) ~= "table" then return 0 end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function WSGH.Util.ShallowCopy(t)
  if type(t) ~= "table" then return {} end
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

function WSGH.Util.ArrayFilterNonZero(arr)
  local out = {}
  if type(arr) ~= "table" then return out end

  for _, v in ipairs(arr) do
    local n = tonumber(v) or 0
    if n ~= 0 then
      out[#out + 1] = n
    end
  end

  return out
end

function WSGH.Util.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(("|cff33ff99WSGH|r: %s"):format(tostring(msg)))
end

function WSGH.Util.OpenBagsForGuidance()
  local adapters = WSGH.UI and WSGH.UI.BagAdapters or nil
  if adapters and adapters.AreBagFramesVisible and adapters.AreBagFramesVisible() then
    return
  end
  if BetterBags_ToggleBags then
    pcall(BetterBags_ToggleBags)
    return
  end
  if OpenAllBags then
    pcall(OpenAllBags)
  elseif ToggleAllBags then
    pcall(ToggleAllBags)
  end
end

function WSGH.Util.Pluralize(count, singular, plural)
  local n = tonumber(count) or 0
  if n == 1 then
    return tostring(singular or "")
  end
  if plural ~= nil then
    return tostring(plural)
  end
  return tostring(singular or "") .. "s"
end

function WSGH.Util.FormatCountNoun(count, singular, plural)
  local n = tonumber(count) or 0
  return ("%d %s"):format(n, WSGH.Util.Pluralize(n, singular, plural))
end

-- Returns a coarse expansion key for the current client build.
-- Keys match the data tables used elsewhere (e.g., "MOP", "CATA").
function WSGH.Util.GetExpansionKey()
  local build = (type(GetBuildInfo) == "function") and select(4, GetBuildInfo()) or 0
  build = tonumber(build) or 0
  if build >= 50000 then return "MOP" end
  if build >= 40000 then return "CATA" end
  if build >= 30000 then return "WOTLK" end
  if build >= 20000 then return "TBC" end
  return "MOP"
end

function WSGH.Util.GetPreferences()
  if type(_G.WowSimsGearHelperDB) ~= "table" then
    _G.WowSimsGearHelperDB = {}
  end
  if type(_G.WowSimsGearHelperDB.profile) ~= "table" then
    _G.WowSimsGearHelperDB.profile = {}
  end
  if type(_G.WowSimsGearHelperDB.profile.prefs) ~= "table" then
    _G.WowSimsGearHelperDB.profile.prefs = {}
  end

  local prefs = _G.WowSimsGearHelperDB.profile.prefs
  if prefs.persistImports == nil then prefs.persistImports = false end
  if prefs.savedImportText == nil then prefs.savedImportText = nil end
  if prefs.tinkers == nil then prefs.tinkers = {} end
  if prefs.highlightStyle == nil then
    prefs.highlightStyle = (WSGH.Const and WSGH.Const.HIGHLIGHT and WSGH.Const.HIGHLIGHT.style) or "label"
  end
  if prefs.minimap == nil then
    prefs.minimap = { hide = false }
  end
  if prefs.minimap.hide == nil then
    prefs.minimap.hide = false
  end
  if prefs.upgradeCurrency == nil then
    prefs.upgradeCurrency = "JUSTICE"
  end
  if prefs.useValorForUpgrades == nil then
    prefs.useValorForUpgrades = (prefs.upgradeCurrency == "VALOR")
  end
  WSGH.DB = _G.WowSimsGearHelperDB
  return prefs
end

function WSGH.Util.GetDefaultTinkerForSlot(slotId)
  slotId = tonumber(slotId) or 0
  local preferences = WSGH.Util.GetPreferences()
  local prefVal = preferences and preferences.tinkers and preferences.tinkers[slotId]
  if prefVal ~= nil then
    return tonumber(prefVal) or 0
  end
  local defaults = WSGH.Const and WSGH.Const.DEFAULT_TINKERS or {}
  return tonumber(defaults[slotId]) or 0
end

function WSGH.Util.GetHighlightStyle()
  local preferences = WSGH.Util.GetPreferences()
  local style = preferences and preferences.highlightStyle or nil
  if style == nil or style == "" then
    style = (WSGH.Const and WSGH.Const.HIGHLIGHT and WSGH.Const.HIGHLIGHT.style) or "label"
  end
  return style
end

-- Returns true if the player currently has Engineering learned.
function WSGH.Util.HasEngineering()
  if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
    return false
  end
  local prof1, prof2, arch, fish, cook, firstAid = GetProfessions()
  for _, prof in ipairs({ prof1, prof2, arch, fish, cook, firstAid }) do
    if prof then
      local name, _, _, _, _, skillLine = GetProfessionInfo(prof)
      if tonumber(skillLine) == 202 then -- 202 = Engineering
        return true
      end
      if type(name) == "string" and name:lower():find("engineer") then
        return true
      end
    end
  end
  return false
end

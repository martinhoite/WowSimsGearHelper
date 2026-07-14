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

function WSGH.Util.GetDefaultTaskPriorityOrder()
  local order = {}
  for _, taskType in ipairs(WSGH.Const and WSGH.Const.TASK_PRIORITY_TYPES or {}) do
    if type(taskType.key) == "string" and taskType.key ~= "" then
      order[#order + 1] = taskType.key
    end
  end
  return order
end

function WSGH.Util.NormalizeTaskPriorityOrder(order)
  local normalized = {}
  local seen = {}
  local valid = {}

  for _, taskType in ipairs(WSGH.Const and WSGH.Const.TASK_PRIORITY_TYPES or {}) do
    if type(taskType.key) == "string" and taskType.key ~= "" then
      valid[taskType.key] = true
    end
  end

  if type(order) == "table" then
    for _, key in ipairs(order) do
      if valid[key] and not seen[key] then
        normalized[#normalized + 1] = key
        seen[key] = true
      end
    end
  end

  for _, key in ipairs(WSGH.Util.GetDefaultTaskPriorityOrder()) do
    if not seen[key] then
      normalized[#normalized + 1] = key
      seen[key] = true
    end
  end

  return normalized
end

function WSGH.Util.GetTaskPriorityOrder()
  local preferences = WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
  return WSGH.Util.NormalizeTaskPriorityOrder(preferences and preferences.taskPriorityOrder or nil)
end

function WSGH.Util.GetTaskPriorityRank(taskType)
  local order = WSGH.Util.GetTaskPriorityOrder()
  for index, key in ipairs(order) do
    if key == taskType then
      return index
    end
  end
  return #order + 1
end

function WSGH.Util.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(("|cff33ff99WSGH|r: %s"):format(tostring(msg)))
end

function WSGH.Util.GetAddonVersion()
  local addonName = WSGH.ADDON_NAME
  local version = nil
  if type(GetAddOnMetadata) == "function" and type(addonName) == "string" and addonName ~= "" then
    version = GetAddOnMetadata(addonName, "Version")
  end
  if type(version) ~= "string" or version == "" then
    version = WSGH.VERSION
  end
  if type(version) ~= "string" or version == "" then
    return "unknown"
  end
  return version
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
  if prefs.showReforgeReminderAfterImport == nil then prefs.showReforgeReminderAfterImport = true end
  if prefs.showReforgeReminderOnRestore == nil then prefs.showReforgeReminderOnRestore = false end
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
  if type(prefs.colors) ~= "table" then
    prefs.colors = {}
  end
  prefs.taskPriorityOrder = WSGH.Util.NormalizeTaskPriorityOrder(prefs.taskPriorityOrder)
  WSGH.DB = _G.WowSimsGearHelperDB
  return prefs
end

local function ClampColorChannel(value, fallback)
  local n = tonumber(value)
  if n == nil then
    n = tonumber(fallback) or 0
  end
  if n < 0 then return 0 end
  if n > 1 then return 1 end
  return n
end

local function CopyColor(color, fallback)
  color = type(color) == "table" and color or {}
  fallback = type(fallback) == "table" and fallback or { 1, 1, 1, 1 }
  return {
    ClampColorChannel(color.r or color[1], fallback.r or fallback[1]),
    ClampColorChannel(color.g or color[2], fallback.g or fallback[2]),
    ClampColorChannel(color.b or color[3], fallback.b or fallback[3]),
    ClampColorChannel(color.a or color[4], fallback.a or fallback[4] or 1),
  }
end

local function ColorsMatch(a, b)
  a = CopyColor(a)
  b = CopyColor(b)
  for i = 1, 4 do
    if math.abs((a[i] or 0) - (b[i] or 0)) > 0.001 then
      return false
    end
  end
  return true
end

function WSGH.Util.GetColorRoleGroups()
  return WSGH.Const and WSGH.Const.COLOR_ROLES or {}
end

function WSGH.Util.GetDefaultColor(roleKey)
  local defaults = WSGH.Const and WSGH.Const.COLOR_DEFAULTS or {}
  return CopyColor(defaults and defaults[roleKey] or nil)
end

function WSGH.Util.GetColor(roleKey, fallback)
  local defaultColor = WSGH.Util.GetDefaultColor(roleKey)
  if fallback then
    defaultColor = CopyColor(defaultColor, fallback)
  end

  local preferences = WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
  local storedColor = preferences and preferences.colors and preferences.colors[roleKey] or nil
  if type(storedColor) == "table" then
    return CopyColor(storedColor, defaultColor)
  end
  return defaultColor
end

function WSGH.Util.SetColor(roleKey, color)
  if type(roleKey) ~= "string" or roleKey == "" then return end
  local preferences = WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
  if not preferences then return end

  preferences.colors = preferences.colors or {}
  local normalized = CopyColor(color, WSGH.Util.GetDefaultColor(roleKey))
  local defaultColor = WSGH.Util.GetDefaultColor(roleKey)
  if ColorsMatch(normalized, defaultColor) then
    preferences.colors[roleKey] = nil
  else
    preferences.colors[roleKey] = {
      r = normalized[1],
      g = normalized[2],
      b = normalized[3],
      a = normalized[4],
    }
  end
end

function WSGH.Util.ResetColor(roleKey)
  local preferences = WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
  if preferences and preferences.colors then
    preferences.colors[roleKey] = nil
  end
end

function WSGH.Util.ResetAllColors()
  local preferences = WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
  if preferences then
    preferences.colors = {}
  end
end

function WSGH.Util.HasCustomColors()
  local preferences = WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
  if not (preferences and type(preferences.colors) == "table") then
    return false
  end
  local defaults = WSGH.Const and WSGH.Const.COLOR_DEFAULTS or {}
  for roleKey in pairs(preferences.colors) do
    if defaults[roleKey] then
      return true
    end
  end
  return false
end

function WSGH.Util.SetTextColor(fontString, roleKey)
  if not (fontString and fontString.SetTextColor) then return end
  local color = WSGH.Util.GetColor(roleKey)
  fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local buttonTextFontObjects = {}

local function CopyFontObjectStyle(target, source)
  if not (target and source) then return end
  if target.SetFont and source.GetFont then
    local font, size, flags = source:GetFont()
    if font then
      target:SetFont(font, size, flags)
    end
  end
  if target.SetShadowColor and source.GetShadowColor then
    target:SetShadowColor(source:GetShadowColor())
  end
  if target.SetShadowOffset and source.GetShadowOffset then
    target:SetShadowOffset(source:GetShadowOffset())
  end
end

local function GetButtonTextFontObject(button, roleKey)
  local key = roleKey or "button.defaultText"
  local fontObject = buttonTextFontObjects[key]
  if not fontObject then
    fontObject = CreateFont("WSGHButtonTextFont" .. key:gsub("[^%w]", "_"))
    buttonTextFontObjects[key] = fontObject
  end

  local source = button
    and button.GetFontString
    and button:GetFontString()
    or GameFontNormalSmall
  CopyFontObjectStyle(fontObject, source)

  local color = WSGH.Util.GetColor(key)
  fontObject:SetTextColor(color[1], color[2], color[3], color[4])
  return fontObject
end

function WSGH.Util.ApplyButtonTextColor(button, roleKey)
  if not button then return end
  local fontObject = GetButtonTextFontObject(button, roleKey)
  if button.SetNormalFontObject then
    button:SetNormalFontObject(fontObject)
  end
  if button.SetHighlightFontObject then
    button:SetHighlightFontObject(fontObject)
  end
  if button.SetDisabledFontObject then
    button:SetDisabledFontObject(fontObject)
  end
  if button.GetFontString and button:GetFontString() then
    WSGH.Util.SetTextColor(button:GetFontString(), roleKey or "button.defaultText")
  end
end

function WSGH.Util.SetTextureColor(texture, roleKey)
  if not texture then return end
  local color = WSGH.Util.GetColor(roleKey)
  if texture.SetColorTexture then
    texture:SetColorTexture(color[1], color[2], color[3], color[4])
  elseif texture.SetVertexColor then
    texture:SetVertexColor(color[1], color[2], color[3], color[4])
  end
end

local function GetWindowBackgroundRole(windowKind)
  if windowKind == "shoppingReminder" then
    return "window.reminderBackground"
  end
  return "window.background"
end

function WSGH.Util.ApplyWindowBackground(frame, windowKind, inset)
  if not frame then return end

  local background = frame.wsghOpaqueBackground
  if not background then
    background = frame:CreateTexture(nil, "BACKGROUND")
    frame.wsghOpaqueBackground = background
  end

  local backgroundInset = tonumber(inset) or 10
  background:ClearAllPoints()
  background:SetPoint("TOPLEFT", backgroundInset, -backgroundInset)
  background:SetPoint("BOTTOMRIGHT", -backgroundInset, backgroundInset)
  background:SetTexture("Interface\\Buttons\\WHITE8x8")
  local color = WSGH.Util.GetColor(GetWindowBackgroundRole(windowKind))
  background:SetVertexColor(color[1], color[2], color[3], color[4])
  background:SetShown((tonumber(color[4]) or 0) > 0)
end

function WSGH.Util.ApplyOpaqueWindowBackground(frame, windowKind, inset)
  WSGH.Util.ApplyWindowBackground(frame, windowKind, inset)
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

function WSGH.Util.HasProfession(skillLineId, namePattern)
  if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
    return false
  end
  local targetSkillLineId = tonumber(skillLineId) or 0
  local normalizedPattern = type(namePattern) == "string" and namePattern:lower() or nil
  local prof1, prof2, arch, fish, cook, firstAid = GetProfessions()
  for _, prof in ipairs({ prof1, prof2, arch, fish, cook, firstAid }) do
    if prof then
      local name, _, _, _, _, _, skillLine = GetProfessionInfo(prof)
      if targetSkillLineId ~= 0 and tonumber(skillLine) == targetSkillLineId then
        return true
      end
      if normalizedPattern and type(name) == "string" and name:lower():find(normalizedPattern, 1, true) then
        return true
      end
    end
  end
  return false
end

-- Returns true if the player currently has Engineering learned.
function WSGH.Util.HasEngineering()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.ENGINEERING or {}
  return WSGH.Util.HasProfession(definition.skillLineId, definition.namePattern)
end

-- Returns true if the player currently has Blacksmithing learned.
function WSGH.Util.HasBlacksmithing()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.BLACKSMITHING or {}
  return WSGH.Util.HasProfession(definition.skillLineId, definition.namePattern)
end

-- Returns true if the player currently has Enchanting learned.
function WSGH.Util.HasEnchanting()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.ENCHANTING or {}
  return WSGH.Util.HasProfession(definition.skillLineId, definition.namePattern)
end

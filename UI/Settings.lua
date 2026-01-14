local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.UI = WSGH.UI or {}
WSGH.UI.Settings = WSGH.UI.Settings or {}

local optionsPanel
local optionsCategoryID

local function GetPreferences()
  return WSGH.Util and WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
end

local function BuildOptionsPanel()
  if optionsPanel then return end

  local categoryName = "WowSims Gear Helper"
  optionsPanel = CreateFrame("Frame", "WowSimsGearHelperOptions", InterfaceOptionsFramePanelContainer or UIParent)
  optionsPanel.name = categoryName

  local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(categoryName)

  local desc = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  desc:SetText("Preferences")

  local preferences = GetPreferences() or {}

  local persistCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  persistCheck:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -8)
  persistCheck.Text:SetText("Save last import")
  persistCheck:SetChecked(preferences.persistImports or false)
  persistCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.persistImports = self:GetChecked()
    if not self:GetChecked() then
      preferencesTable.savedImportText = nil
    end
  end)
  persistCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Save last import", 1, 1, 1)
    GameTooltip:AddLine("Keep your last imported plan and auto-apply it next session.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  persistCheck:SetScript("OnLeave", GameTooltip_Hide)

  local minimapCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  minimapCheck:SetPoint("TOPLEFT", persistCheck, "BOTTOMLEFT", 0, -6)
  minimapCheck.Text:SetText("Show minimap icon")
  minimapCheck:SetChecked(not (preferences.minimap and preferences.minimap.hide))
  minimapCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.minimap = preferencesTable.minimap or {}
    preferencesTable.minimap.hide = not self:GetChecked()
    if WSGH.UI and WSGH.UI.Minimap and WSGH.UI.Minimap.RefreshIcon then
      WSGH.UI.Minimap.RefreshIcon()
    end
  end)
  minimapCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Show minimap icon", 1, 1, 1)
    GameTooltip:AddLine("Toggle the minimap icon used by LDB/Titan Panel.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  minimapCheck:SetScript("OnLeave", GameTooltip_Hide)

  local highlightLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  highlightLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -16)
  highlightLabel:SetText("Highlight style:")

  local highlightDrop = CreateFrame("Frame", "WSGHHighlightStyle", optionsPanel, "UIDropDownMenuTemplate")
  highlightDrop:SetPoint("TOPLEFT", highlightLabel, "BOTTOMLEFT", -16, -4)
  UIDropDownMenu_SetWidth(highlightDrop, 160)
  UIDropDownMenu_SetButtonWidth(highlightDrop, 160)

  UIDropDownMenu_Initialize(highlightDrop, function(self, level)
    local preferencesTable = GetPreferences() or {}
    local current = preferencesTable.highlightStyle
    if current == nil then
      current = WSGH.Const.HIGHLIGHT and WSGH.Const.HIGHLIGHT.style or "label"
    end
    for _, opt in ipairs(WSGH.Const.HIGHLIGHT and WSGH.Const.HIGHLIGHT.styles or {}) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = opt.text
      info.value = opt.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(highlightDrop, opt.value)
        preferencesTable.highlightStyle = opt.value
        if WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.Refresh then
          WSGH.UI.Highlight.Refresh()
        end
      end
      info.checked = (opt.value == current)
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  local highlightPrefs = GetPreferences() or {}
  local highlightInitial = highlightPrefs.highlightStyle
  if highlightInitial == nil then
    highlightInitial = WSGH.Const.HIGHLIGHT and WSGH.Const.HIGHLIGHT.style or "label"
  end
  local highlightHasInitial = false
  for _, opt in ipairs(WSGH.Const.HIGHLIGHT and WSGH.Const.HIGHLIGHT.styles or {}) do
    if opt.value == highlightInitial then
      highlightHasInitial = true
      break
    end
  end
  if not highlightHasInitial and WSGH.Const.HIGHLIGHT and WSGH.Const.HIGHLIGHT.styles and #WSGH.Const.HIGHLIGHT.styles > 0 then
    highlightInitial = WSGH.Const.HIGHLIGHT.styles[1].value
    highlightPrefs.highlightStyle = highlightInitial
  end
  UIDropDownMenu_SetSelectedValue(highlightDrop, highlightInitial)

  local tinkerLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tinkerLabel:SetPoint("TOPLEFT", highlightDrop, "BOTTOMLEFT", 16, -12)
  tinkerLabel:SetText("Default tinker:")
  tinkerLabel:SetShown(WSGH.Diff and WSGH.Diff.Engine and WSGH.Diff.Engine.ENABLE_TINKERS == true)

  local mopTinkerOptions = {
    cloak = {
      { text = "None", value = 0 },
      { text = GetSpellInfo(126392) or "Goblin Glider", value = 126392 },
      { text = GetSpellInfo(55002) or "Flexweave Underlay", value = 55002 },
    },
    gloves = {
      { text = "None", value = 0 },
      { text = GetSpellInfo(126731) or "Synapse Springs", value = 126731 },
      { text = GetSpellInfo(108789) or "Phase Fingers", value = 108789 },
      { text = GetSpellInfo(82180) or "Tazik Shocker", value = 82180 },
      { text = GetSpellInfo(109077) or "Incendiary Fireworks Launcher", value = 109077 },
    },
    belt = {
      { text = "None", value = 0 },
      { text = GetSpellInfo(55016) or "Nitro Boosts", value = 55016 },
      { text = GetSpellInfo(82200) or "Spinal Healing Injector", value = 82200 },
      { text = GetSpellInfo(84427) or "Grounded Plasma Shield", value = 84427 },
      { text = GetSpellInfo(84424) or "Invisibility Field", value = 84424 },
      { text = GetSpellInfo(67839) or "Mind Amplification Dish", value = 67839 },
      { text = GetSpellInfo(84425) or "Cardboard Assassin", value = 84425 },
      { text = GetSpellInfo(109099) or "Watergliding Jets", value = 109099 },
      { text = GetSpellInfo(40800) or "Frag Belt", value = 40800 },
      { text = GetSpellInfo(54736) or "EMP Generator", value = 54736 },
    }
  }

  local dropdownAnchor = CreateFrame("Frame", nil, optionsPanel)
  dropdownAnchor:SetPoint("TOPLEFT", tinkerLabel, "BOTTOMLEFT", 0, -6)
  dropdownAnchor:SetSize(1, 1)
  dropdownAnchor:SetShown(WSGH.Diff and WSGH.Diff.Engine and WSGH.Diff.Engine.ENABLE_TINKERS == true)
  local nextYOffset = 0

  local function CreateTinkerDropdown(name, labelText, slotId, options)
    local showTinkers = (WSGH.Diff and WSGH.Diff.Engine and WSGH.Diff.Engine.ENABLE_TINKERS == true)
    local label = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", dropdownAnchor, "TOPLEFT", 0, nextYOffset)
    label:SetText(labelText)
    label:SetShown(showTinkers)

    local drop = CreateFrame("Frame", name, optionsPanel, "UIDropDownMenuTemplate")
    drop:SetPoint("TOPLEFT", dropdownAnchor, "TOPLEFT", -16, nextYOffset - 18)
    UIDropDownMenu_SetWidth(drop, 200)
    drop:SetShown(showTinkers)

    UIDropDownMenu_Initialize(drop, function(self, level)
      local preferencesTable = GetPreferences() or {}
      preferencesTable.tinkers = preferencesTable.tinkers or {}
      local current = preferencesTable.tinkers[slotId]
      if current == nil then
        current = WSGH.Const.DEFAULT_TINKERS and WSGH.Const.DEFAULT_TINKERS[slotId] or 0
      end
      for _, opt in ipairs(options) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.text
        info.value = opt.value
        info.func = function()
          UIDropDownMenu_SetSelectedValue(drop, opt.value)
          preferencesTable.tinkers[slotId] = opt.value
        end
        info.checked = (opt.value == current)
        UIDropDownMenu_AddButton(info, level)
      end
    end)

    local preferencesTable = GetPreferences() or {}
    preferencesTable.tinkers = preferencesTable.tinkers or {}
    local initial = preferencesTable.tinkers[slotId]
    if initial == nil then
      initial = WSGH.Const.DEFAULT_TINKERS and WSGH.Const.DEFAULT_TINKERS[slotId] or 0
    end
    local hasInitial = false
    for _, opt in ipairs(options) do
      if opt.value == initial then
        hasInitial = true
        break
      end
    end
    if not hasInitial and #options > 0 then
      initial = options[1].value
      preferencesTable.tinkers[slotId] = initial
    end
    UIDropDownMenu_SetSelectedValue(drop, initial)

    nextYOffset = nextYOffset - 52
    return drop
  end

  CreateTinkerDropdown("WSGHDefaultTinkerCloak", "Cloak", 15, mopTinkerOptions.cloak)
  CreateTinkerDropdown("WSGHDefaultTinkerGloves", "Gloves", 10, mopTinkerOptions.gloves)
  CreateTinkerDropdown("WSGHDefaultTinkerBelt", "Belt", 6, mopTinkerOptions.belt)

  if Settings and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, categoryName)
    category.ID = categoryName
    category.name = categoryName
    WSGH.UI.optionsCategory = Settings.RegisterAddOnCategory(category)
    optionsCategoryID = category.ID
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(optionsPanel)
    WSGH.UI.optionsPanel = optionsPanel
    optionsCategoryID = categoryName
  end
end

function WSGH.UI.Settings.Open()
  BuildOptionsPanel()
  if Settings and Settings.OpenToCategory and optionsCategoryID then
    Settings.OpenToCategory(optionsCategoryID)
    if SettingsPanel then SettingsPanel:Show() end
  elseif InterfaceOptionsFrame_OpenToCategory and optionsPanel then
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
  end
end

function WSGH.UI.Settings.Initialize()
  BuildOptionsPanel()
end

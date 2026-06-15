local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.UI = WSGH.UI or {}
WSGH.UI.Settings = WSGH.UI.Settings or {}

local optionsPanel
local optionsCategory
local optionsCategoryID

local function GetPreferences()
  return WSGH.Util and WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
end

local function CreateTaskTypeLookup()
  local lookup = {}
  for _, taskType in ipairs(WSGH.Const and WSGH.Const.TASK_PRIORITY_TYPES or {}) do
    if type(taskType.key) == "string" and taskType.key ~= "" then
      lookup[taskType.key] = taskType
    end
  end
  return lookup
end

local function NormalizeTaskPriorityOrder(order)
  if WSGH.Util and WSGH.Util.NormalizeTaskPriorityOrder then
    return WSGH.Util.NormalizeTaskPriorityOrder(order)
  end

  local normalized = {}
  for _, taskType in ipairs(WSGH.Const and WSGH.Const.TASK_PRIORITY_TYPES or {}) do
    if type(taskType.key) == "string" and taskType.key ~= "" then
      normalized[#normalized + 1] = taskType.key
    end
  end
  return normalized
end

local function FindTaskPriorityIndex(order, key)
  for index, orderKey in ipairs(order or {}) do
    if orderKey == key then
      return index
    end
  end
  return nil
end

local function CreateTaskPrioritySection(parent, anchor)
  local layout = WSGH.Const
    and WSGH.Const.UI
    and WSGH.Const.UI.settings
    and WSGH.Const.UI.settings.taskPriority
    or {}
  local width = tonumber(layout.width) or 250
  local rowHeight = tonumber(layout.rowHeight) or 28
  local rowGap = tonumber(layout.rowGap) or 4
  local labelGap = tonumber(layout.labelGap) or 4
  local rowTopOffset = tonumber(layout.rowTopOffset) or -44
  local rankWidth = tonumber(layout.rankWidth) or 24
  local rankOffsetX = tonumber(layout.rankOffsetX) or 8
  local labelOffsetX = tonumber(layout.labelOffsetX) or 2
  local resetButton = layout.resetButton or {}
  local backdrop = layout.backdrop or {}
  local backdropInset = tonumber(backdrop.inset) or 2
  local taskTypes = WSGH.Const and WSGH.Const.TASK_PRIORITY_TYPES or {}

  local section = CreateFrame("Frame", nil, parent)
  section:SetPoint(
    "TOPLEFT",
    anchor,
    "TOPLEFT",
    tonumber(layout.xOffset) or 300,
    tonumber(layout.yOffset) or -8
  )
  section:SetSize(width, math.abs(rowTopOffset) + (#taskTypes * (rowHeight + rowGap)))

  local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
  title:SetText("Task priority")

  local reset = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
  reset:SetSize(tonumber(resetButton.width) or 64, tonumber(resetButton.height) or 20)
  reset:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, tonumber(resetButton.yOffset) or 2)
  reset:SetText("Reset")

  local note = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -labelGap)
  note:SetPoint("RIGHT", section, "RIGHT", 0, 0)
  note:SetHeight(tonumber(layout.noteHeight) or 28)
  note:SetJustifyH("LEFT")
  note:SetWordWrap(true)
  note:SetText("Drag rows to set the task order.\nIf the window is already open, you'll need to reopen it to see the changes.")

  local taskTypeLookup = CreateTaskTypeLookup()
  local rows = {}
  local draggingKey = nil
  local dragHoverIndex = nil
  local dragInsertIndex = nil

  local function GetStoredOrder()
    local preferencesTable = GetPreferences()
    if not preferencesTable then
      return NormalizeTaskPriorityOrder(nil)
    end

    preferencesTable.taskPriorityOrder = NormalizeTaskPriorityOrder(preferencesTable.taskPriorityOrder)
    return preferencesTable.taskPriorityOrder
  end

  local function SetStoredOrder(order)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.taskPriorityOrder = NormalizeTaskPriorityOrder(order)
  end

  local function MoveTaskToIndex(taskKey, targetIndex)
    if not taskKey or not targetIndex then return false end

    local order = NormalizeTaskPriorityOrder(GetStoredOrder())
    local currentIndex = FindTaskPriorityIndex(order, taskKey)
    if not currentIndex or currentIndex == targetIndex then return false end

    table.remove(order, currentIndex)
    if currentIndex < targetIndex then
      targetIndex = targetIndex - 1
    end
    targetIndex = math.max(1, math.min(targetIndex, #order + 1))
    if currentIndex == targetIndex then return false end

    table.insert(order, targetIndex, taskKey)
    SetStoredOrder(order)
    return true
  end

  local RefreshRows
  local StopDrag

  local function GetCursorCanvasY()
    if not GetCursorPosition then return nil end

    local _, cursorY = GetCursorPosition()
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
      scale = UIParent:GetEffectiveScale() or 1
    end
    return cursorY and (cursorY / scale) or nil
  end

  local function GetInsertionIndexForRow(row)
    if not row then return nil end

    local targetIndex = row.orderIndex
    local cursorY = GetCursorCanvasY()
    local top = row.GetTop and row:GetTop() or nil
    local bottom = row.GetBottom and row:GetBottom() or nil
    if cursorY and top and bottom then
      local midpoint = bottom + ((top - bottom) / 2)
      if cursorY < midpoint then
        targetIndex = targetIndex + 1
      end
    end
    return targetIndex
  end

  local function GetMouseOverRow()
    for _, row in ipairs(rows) do
      if row:IsShown() and row.IsMouseOver and row:IsMouseOver() then
        return row
      end
    end
    return nil
  end

  local function UpdateDrag()
    if not draggingKey then return end

    if not IsMouseButtonDown or not IsMouseButtonDown("LeftButton") then
      StopDrag()
      return
    end

    local row = GetMouseOverRow()
    local nextHoverIndex = row and row.orderIndex or nil
    local nextInsertIndex = row and GetInsertionIndexForRow(row) or nil
    local shouldRefresh = nextHoverIndex ~= dragHoverIndex or nextInsertIndex ~= dragInsertIndex
    dragHoverIndex = nextHoverIndex
    dragInsertIndex = nextInsertIndex

    if row and row.taskKey ~= draggingKey and nextInsertIndex then
      shouldRefresh = MoveTaskToIndex(draggingKey, nextInsertIndex) or shouldRefresh
    end

    if shouldRefresh and RefreshRows then
      RefreshRows()
    end
  end

  StopDrag = function()
    if not draggingKey then return end

    draggingKey = nil
    dragHoverIndex = nil
    dragInsertIndex = nil
    section:SetScript("OnUpdate", nil)
    if RefreshRows then RefreshRows() end
  end

  local function StartDrag(row)
    draggingKey = row.taskKey
    dragHoverIndex = row.orderIndex
    dragInsertIndex = row.orderIndex
    section:SetScript("OnUpdate", UpdateDrag)
    if RefreshRows then RefreshRows() end
  end

  RefreshRows = function()
    local order = GetStoredOrder()
    for index, key in ipairs(order) do
      local row = rows[index]
      local taskType = taskTypeLookup[key] or { label = key, description = "" }

      if row then
        row.taskKey = key
        row.orderIndex = index
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", section, "TOPLEFT", 0, rowTopOffset - ((index - 1) * (rowHeight + rowGap)))
        row:SetPoint("RIGHT", section, "RIGHT", 0, 0)
        row:SetHeight(rowHeight)
        row.rank:SetText(tostring(index))
        row.label:SetText(taskType.label or key)

        if draggingKey == key then
          row:SetBackdropColor(0.2, 0.32, 0.42, 0.85)
          row:SetBackdropBorderColor(0.95, 0.85, 0.25, 1)
        else
          row:SetBackdropColor(0.03, 0.03, 0.03, 0.45)
          row:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        end

        row:Show()
      end
    end

    for index = #order + 1, #rows do
      rows[index]:Hide()
    end
  end

  for index = 1, #taskTypes do
    local row = CreateFrame("Button", nil, section, "BackdropTemplate")
    row:SetSize(width, rowHeight)
    row:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = tonumber(backdrop.tileSize) or 16,
      edgeSize = tonumber(backdrop.edgeSize) or 10,
      insets = { left = backdropInset, right = backdropInset, top = backdropInset, bottom = backdropInset },
    })
    row:EnableMouse(true)

    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.rank:SetPoint("LEFT", row, "LEFT", rankOffsetX, 0)
    row.rank:SetWidth(rankWidth)
    row.rank:SetJustifyH("LEFT")

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.rank, "RIGHT", labelOffsetX, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -rankOffsetX, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row:SetScript("OnMouseDown", function(self, button)
      if button == "LeftButton" then
        StartDrag(self)
      end
    end)
    row:SetScript("OnMouseUp", function()
      StopDrag()
    end)
    row:SetScript("OnEnter", function(self)
      if RefreshRows then RefreshRows() end
      local taskType = taskTypeLookup[self.taskKey] or {}
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(taskType.label or tostring(self.taskKey or "Task"), 1, 1, 1)
      if type(taskType.description) == "string" and taskType.description ~= "" then
        GameTooltip:AddLine(taskType.description, nil, nil, nil, true)
      end
      if type(taskType.warning) == "string" and taskType.warning ~= "" then
        GameTooltip:AddLine(taskType.warning, 1, 0.82, 0.2, true)
      end
      GameTooltip:AddLine("Drag rows up or down to reorder.", 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
      if RefreshRows then RefreshRows() end
      GameTooltip_Hide()
    end)

    rows[index] = row
  end

  reset:SetScript("OnClick", function()
    if WSGH.Util and WSGH.Util.GetDefaultTaskPriorityOrder then
      SetStoredOrder(WSGH.Util.GetDefaultTaskPriorityOrder())
    else
      SetStoredOrder(nil)
    end
    RefreshRows()
  end)
  reset:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Reset task priority", 1, 1, 1)
    GameTooltip:AddLine("Restore the default task type order.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  reset:SetScript("OnLeave", GameTooltip_Hide)

  section:SetScript("OnHide", function()
    draggingKey = nil
    dragHoverIndex = nil
    dragInsertIndex = nil
    section:SetScript("OnUpdate", nil)
  end)

  RefreshRows()
  return section
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

  local addonVersion = WSGH.Util and WSGH.Util.GetAddonVersion and WSGH.Util.GetAddonVersion() or (WSGH.VERSION or "unknown")
  local versionText = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  versionText:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -4)
  versionText:SetText(("Version: %s"):format(tostring(addonVersion)))

  local preferences = GetPreferences() or {}
  CreateTaskPrioritySection(optionsPanel, versionText)

  local persistCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  persistCheck:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -8)
  persistCheck.Text:SetText("Save last import")
  persistCheck:SetChecked(preferences.persistImports or false)

  local restoreReminderCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  restoreReminderCheck:SetPoint("TOPLEFT", persistCheck, "BOTTOMLEFT", 18, -4)
  restoreReminderCheck.Text:SetText("Show manual reforge reminder on restore")
  restoreReminderCheck:SetChecked(preferences.showReforgeReminderOnRestore == true)

  local function RefreshRestoreReminderCheck()
    local enabled = persistCheck:GetChecked() == true
    restoreReminderCheck:SetEnabled(enabled)
    restoreReminderCheck.Text:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
  end

  persistCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.persistImports = self:GetChecked()
    if not self:GetChecked() then
      preferencesTable.savedImportText = nil
    end
    RefreshRestoreReminderCheck()
  end)
  persistCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Save last import", 1, 1, 1)
    GameTooltip:AddLine("Keep your last imported plan and auto-apply it next session.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  persistCheck:SetScript("OnLeave", GameTooltip_Hide)

  restoreReminderCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.showReforgeReminderOnRestore = self:GetChecked() and true or false
    if not self:GetChecked() and WSGH.UI and WSGH.UI.reforgeReminder and WSGH.UI.reforgeReminder.source == "restore" then
      WSGH.UI.reforgeReminder.hidden = true
      if WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateReforgeReminder then
        WSGH.UI.Shopping.UpdateReforgeReminder()
      end
    end
  end)
  restoreReminderCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Show manual reforge reminder on restore", 1, 1, 1)
    GameTooltip:AddLine("Only used when ReforgeLite Classic is not available. When a saved import is restored, show the compact manual reforge reminder again if the plan includes reforges.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  restoreReminderCheck:SetScript("OnLeave", GameTooltip_Hide)

  local minimapCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  minimapCheck:SetPoint("TOPLEFT", restoreReminderCheck, "BOTTOMLEFT", -18, -6)
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

  local opaqueBackgroundCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  opaqueBackgroundCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -6)
  opaqueBackgroundCheck.Text:SetText("Use opaque background for all windows")
  opaqueBackgroundCheck:SetChecked(preferences.useOpaqueBackgroundForAllWindows == true)
  opaqueBackgroundCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.useOpaqueBackgroundForAllWindows = self:GetChecked() and true or false
    if WSGH.UI and WSGH.UI.RefreshWindowBackgrounds then
      WSGH.UI.RefreshWindowBackgrounds()
    end
  end)
  opaqueBackgroundCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Use opaque background for all windows", 1, 1, 1)
    GameTooltip:AddLine("Apply the solid dark help/import background style to the main addon and shopping windows too.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  opaqueBackgroundCheck:SetScript("OnLeave", GameTooltip_Hide)

  local useValorCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  useValorCheck:SetPoint("TOPLEFT", opaqueBackgroundCheck, "BOTTOMLEFT", 0, -6)
  useValorCheck.Text:SetText("Use Valor for upgrades")
  useValorCheck:SetChecked(preferences.useValorForUpgrades == true)
  useValorCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    local useValor = self:GetChecked() and true or false
    preferencesTable.useValorForUpgrades = useValor
    preferencesTable.upgradeCurrency = useValor and "VALOR" or "JUSTICE"
    if WSGH.UI and WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateShoppingList then
      WSGH.UI.Shopping.UpdateShoppingList()
    end
  end)
  useValorCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Use Valor for upgrades", 1, 1, 1)
    GameTooltip:AddLine("When enabled, shopping upgrade currency info uses Valor instead of Justice.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  useValorCheck:SetScript("OnLeave", GameTooltip_Hide)

  local reforgeReminderCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  reforgeReminderCheck:SetPoint("TOPLEFT", useValorCheck, "BOTTOMLEFT", 0, -6)
  reforgeReminderCheck.Text:SetText("Show manual reforge reminder after import")
  reforgeReminderCheck:SetChecked(preferences.showReforgeReminderAfterImport ~= false)
  reforgeReminderCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.showReforgeReminderAfterImport = self:GetChecked() and true or false
    if not self:GetChecked() and WSGH.UI and WSGH.UI.reforgeReminder and WSGH.UI.reforgeReminder.source == "manual" then
      WSGH.UI.reforgeReminder.hidden = true
      if WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateReforgeReminder then
        WSGH.UI.Shopping.UpdateReforgeReminder()
      end
    end
  end)
  reforgeReminderCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Show manual reforge reminder after import", 1, 1, 1)
    GameTooltip:AddLine("Only used when ReforgeLite Classic is not available. After a manual import that includes reforges, show a compact manual reminder below the shopping list.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  reforgeReminderCheck:SetScript("OnLeave", GameTooltip_Hide)

  local reforgeLiteSyncCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  reforgeLiteSyncCheck:SetPoint("TOPLEFT", reforgeReminderCheck, "BOTTOMLEFT", 0, -6)
  reforgeLiteSyncCheck.Text:SetText("Sync imports to ReforgeLite")
  reforgeLiteSyncCheck:SetChecked(preferences.syncImportsToReforgeLite ~= false)
  reforgeLiteSyncCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.syncImportsToReforgeLite = self:GetChecked() and true or false
  end)
  reforgeLiteSyncCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Sync imports to ReforgeLite", 1, 1, 1)
    GameTooltip:AddLine("When ReforgeLite Classic is available, pass successful manual WowSims imports to its WowSims import flow.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  reforgeLiteSyncCheck:SetScript("OnLeave", GameTooltip_Hide)

  local minimizeAtForgeCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  minimizeAtForgeCheck:SetPoint("TOPLEFT", reforgeLiteSyncCheck, "BOTTOMLEFT", 0, -6)
  minimizeAtForgeCheck.Text:SetText("Minimize WSGH at Reforge NPC")
  minimizeAtForgeCheck:SetChecked(preferences.minimizeWindowAtReforgeNpc ~= false)
  minimizeAtForgeCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.minimizeWindowAtReforgeNpc = self:GetChecked() and true or false
  end)
  minimizeAtForgeCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Minimize WSGH at Reforge NPC", 1, 1, 1)
    GameTooltip:AddLine("When ReforgeLite Classic is available, collapse WSGH instead of hiding it while the reforging UI is open.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  minimizeAtForgeCheck:SetScript("OnLeave", GameTooltip_Hide)

  local restoreAfterForgeCheck = CreateFrame("CheckButton", nil, optionsPanel, "ChatConfigCheckButtonTemplate")
  restoreAfterForgeCheck:SetPoint("TOPLEFT", minimizeAtForgeCheck, "BOTTOMLEFT", 0, -6)
  restoreAfterForgeCheck.Text:SetText("Restore WSGH after Reforge NPC closes")
  restoreAfterForgeCheck:SetChecked(preferences.restoreWindowAfterReforgeNpc == true)
  restoreAfterForgeCheck:SetScript("OnClick", function(self)
    local preferencesTable = GetPreferences()
    if not preferencesTable then return end
    preferencesTable.restoreWindowAfterReforgeNpc = self:GetChecked() and true or false
  end)
  restoreAfterForgeCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Restore WSGH after Reforge NPC closes", 1, 1, 1)
    GameTooltip:AddLine("When enabled, expand WSGH again after closing the reforging UI. Disabled by default.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  restoreAfterForgeCheck:SetScript("OnLeave", GameTooltip_Hide)

  local highlightLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  highlightLabel:SetPoint("TOPLEFT", restoreAfterForgeCheck, "BOTTOMLEFT", 0, -16)
  highlightLabel:SetText("Highlight style:")

  local highlightDrop = CreateFrame("Frame", "WSGHHighlightStyle", optionsPanel, "UIDropDownMenuTemplate")
  highlightDrop:SetPoint("TOPLEFT", highlightLabel, "BOTTOMLEFT", -16, -4)
  UIDropDownMenu_SetWidth(highlightDrop, 205)
  UIDropDownMenu_SetButtonWidth(highlightDrop, 205)

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
  RefreshRestoreReminderCheck()

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
    optionsCategory = Settings.RegisterCanvasLayoutCategory(optionsPanel, categoryName)
    WSGH.UI.optionsCategory = Settings.RegisterAddOnCategory(optionsCategory)
    optionsCategoryID = optionsCategory and optionsCategory.ID or nil
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

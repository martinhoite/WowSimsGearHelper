local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.UI = WSGH.UI or {}
WSGH.UI.Settings = WSGH.UI.Settings or {}

local optionsPanel
local optionsCategory
local optionsCategoryID
local colorRows = {}
local colorPreview = {}
local colorResetAllButton = nil
local colorOpenWindowButton = nil
local colorSectionFrame = nil
local colorSectionContent = nil
local colorSectionHeight = 760
local settingsScrollContent = nil
local settingsScrollFrame = nil
local settingsScrollContentHeight = 760

local COLOR_PRESETS = {
  { text = "Default", value = "DEFAULT" },
  { text = "Custom...", value = "CUSTOM_PICKER", customPicker = true },
  { text = "White", value = "WHITE", color = { 1, 1, 1, 1 } },
  { text = "Gold", value = "GOLD", color = { 1, 0.82, 0, 1 } },
  { text = "Red", value = "RED", color = { 1, 0.2, 0.2, 1 } },
  { text = "Orange", value = "ORANGE", color = { 1, 0.62, 0.22, 1 } },
  { text = "Purple", value = "PURPLE", color = { 0.8, 0.62, 1, 1 } },
  { text = "Blue", value = "BLUE", color = { 0.35, 0.65, 1, 1 } },
  { text = "Green", value = "GREEN", color = { 0.33, 1, 0.6, 1 } },
  { text = "Gray", value = "GRAY", color = { 0.72, 0.72, 0.72, 1 } },
  { text = "Black", value = "BLACK", color = { 0, 0, 0, 1 } },
}

local function GetPreferences()
  return WSGH.Util and WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
end

local function GetColor(roleKey)
  if WSGH.Util and WSGH.Util.GetColor then
    return WSGH.Util.GetColor(roleKey)
  end
  return { 1, 1, 1, 1 }
end

local function SetFontColor(fontString, roleKey)
  if not (fontString and fontString.SetTextColor) then return end
  local color = GetColor(roleKey)
  fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local function SetFrameBackdropColor(frame, roleKey, borderRoleKey)
  if frame and frame.SetBackdropColor then
    local color = GetColor(roleKey)
    frame:SetBackdropColor(color[1], color[2], color[3], color[4])
  end
  if borderRoleKey and frame and frame.SetBackdropBorderColor then
    local borderColor = GetColor(borderRoleKey)
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
  end
end

local function ColorToHex(color)
  color = color or { 1, 1, 1, 1 }
  local r = math.floor(((tonumber(color[1]) or 1) * 255) + 0.5)
  local g = math.floor(((tonumber(color[2]) or 1) * 255) + 0.5)
  local b = math.floor(((tonumber(color[3]) or 1) * 255) + 0.5)
  return ("ff%02x%02x%02x"):format(r, g, b)
end

local function ApplyColorRefresh()
  if WSGH.UI and WSGH.UI.Settings and WSGH.UI.Settings.RefreshColorControls then
    WSGH.UI.Settings.RefreshColorControls()
  end
  if WSGH.UI and WSGH.UI.RefreshColors then
    WSGH.UI.RefreshColors()
  end
  if WSGH.UI and WSGH.UI.Render then
    WSGH.UI.Render()
  end
  if WSGH.UI and WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateShoppingList then
    WSGH.UI.Shopping.UpdateShoppingList()
  end
  if WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.Refresh then
    WSGH.UI.Highlight.Refresh()
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if WSGH.UI and WSGH.UI.Settings and WSGH.UI.Settings.RefreshColorControls then
        WSGH.UI.Settings.RefreshColorControls()
      end
      if WSGH.UI and WSGH.UI.RefreshColors then
        WSGH.UI.RefreshColors()
      end
    end)
  end
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
          SetFrameBackdropColor(row, "settings.dragRowBackground", "settings.dragRowBorder")
        else
          SetFrameBackdropColor(row, "settings.idleRowBackground", "settings.idleRowBorder")
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

local function ColorsMatch(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for i = 1, 4 do
    if math.abs((tonumber(a[i]) or 0) - (tonumber(b[i]) or 0)) > 0.001 then
      return false
    end
  end
  return true
end

local function IsColorCustomized(roleKey)
  local preferences = GetPreferences()
  return preferences
    and type(preferences.colors) == "table"
    and type(preferences.colors[roleKey]) == "table"
    or false
end

local function SetSwatchColor(texture, color)
  if not texture then return end
  color = color or { 1, 1, 1, 1 }
  texture:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function FindPresetForColor(color)
  for _, preset in ipairs(COLOR_PRESETS) do
    if preset.color and ColorsMatch(color, preset.color) then
      return preset.text, preset.value
    end
  end
  return "Custom", "CUSTOM"
end

local function GetPresetByValue(value)
  for _, preset in ipairs(COLOR_PRESETS) do
    if preset.value == value then
      return preset
    end
  end
  return nil
end

local function FormatColorPresetText(preset)
  if not (preset and preset.color) then
    return preset and preset.text or ""
  end

  local isBlack = ColorsMatch(preset.color, { 0, 0, 0, 1 })
  local swatch
  if isBlack then
    swatch = "|cffd0d0d0[|r|cff000000#|r|cffd0d0d0]|r"
  else
    swatch = "|c" .. ColorToHex(preset.color) .. "[#]|r"
  end
  return swatch .. " " .. preset.text
end

local function GetSelectedColorPreset(roleKey)
  if not IsColorCustomized(roleKey) then
    return "Default", "DEFAULT"
  end
  return FindPresetForColor(GetColor(roleKey))
end

local function ShouldShowColorPreset(roleKey, preset)
  if preset and preset.customPicker then
    return true
  end
  if not (preset and preset.color) then
    return true
  end
  local defaultColor = WSGH.Util and WSGH.Util.GetDefaultColor and WSGH.Util.GetDefaultColor(roleKey) or nil
  if defaultColor and ColorsMatch(defaultColor, preset.color) then
    return false
  end
  return true
end

local function RefreshColorPreview()
  if colorPreview.buttonDefault and WSGH.Util and WSGH.Util.ApplyButtonTextColor then
    WSGH.Util.ApplyButtonTextColor(colorPreview.buttonDefault, "button.defaultText")
  end
  if colorPreview.buttonReforge and WSGH.Util and WSGH.Util.ApplyButtonTextColor then
    WSGH.Util.ApplyButtonTextColor(colorPreview.buttonReforge, "button.reforgeText")
  end
  if colorPreview.buttonDone and WSGH.Util and WSGH.Util.ApplyButtonTextColor then
    WSGH.Util.ApplyButtonTextColor(colorPreview.buttonDone, "button.doneText")
  end
  if colorPreview.buttonDisabled and WSGH.Util and WSGH.Util.ApplyButtonTextColor then
    WSGH.Util.ApplyButtonTextColor(colorPreview.buttonDisabled, "button.purchaseText")
  end
  if colorPreview.previewButton and WSGH.Util and WSGH.Util.ApplyButtonTextColor then
    WSGH.Util.ApplyButtonTextColor(colorPreview.previewButton, "button.defaultText")
  end
  SetSwatchColor(colorPreview.windowBackground, GetColor("window.background"))
  SetSwatchColor(colorPreview.reminderBackground, GetColor("window.reminderBackground"))
  SetFontColor(colorPreview.windowBackgroundLabel, "text.normal")
  SetFontColor(colorPreview.reminderBackgroundLabel, "text.normal")
  if colorPreview.highlightTarget and WSGH.UI and WSGH.UI.Highlight and WSGH.UI.Highlight.ApplyPreview then
    WSGH.UI.Highlight.ApplyPreview(colorPreview.highlightTarget, "1")
  end
end

function WSGH.UI.Settings.RefreshColorControls()
  for _, row in ipairs(colorRows) do
    local roleKey = row.roleKey
    local color = GetColor(roleKey)
    SetSwatchColor(row.swatchTexture, color)
    if row.dropdown then
      local text, selectedValue = GetSelectedColorPreset(roleKey)
      local selectedPreset = GetPresetByValue(selectedValue)
      UIDropDownMenu_SetText(row.dropdown, selectedPreset and FormatColorPresetText(selectedPreset) or text)
      UIDropDownMenu_SetSelectedValue(row.dropdown, selectedValue)
    end
    if row.reset then
      row.reset:SetEnabled(IsColorCustomized(roleKey))
    end
  end
  if colorResetAllButton and WSGH.Util and WSGH.Util.HasCustomColors then
    colorResetAllButton:SetEnabled(WSGH.Util.HasCustomColors())
  end
  RefreshColorPreview()
end

local function SetRoleColor(roleKey, color)
  if WSGH.Util and WSGH.Util.SetColor then
    WSGH.Util.SetColor(roleKey, color)
  end
  WSGH.UI.Settings.RefreshColorControls()
  ApplyColorRefresh()
end

local function ResetRoleColor(roleKey)
  if WSGH.Util and WSGH.Util.ResetColor then
    WSGH.Util.ResetColor(roleKey)
  end
  WSGH.UI.Settings.RefreshColorControls()
  ApplyColorRefresh()
end

local function OpenColorPicker(roleKey)
  if not ColorPickerFrame then
    return
  end

  local color = GetColor(roleKey)
  local previous = { color[1], color[2], color[3], color[4] }
  local wasCustomized = IsColorCustomized(roleKey)
  local function CommitPickerColor()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local opacity = OpacitySliderFrame and OpacitySliderFrame.GetValue and OpacitySliderFrame:GetValue() or 0
    local a = 1 - (tonumber(opacity) or 0)
    SetRoleColor(roleKey, { r, g, b, a })
  end

  local function RestorePreviousColor()
    if wasCustomized then
      SetRoleColor(roleKey, previous)
    else
      ResetRoleColor(roleKey)
    end
  end

  ColorPickerFrame.func = CommitPickerColor
  ColorPickerFrame.opacityFunc = CommitPickerColor
  ColorPickerFrame.cancelFunc = RestorePreviousColor
  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = color[1],
      g = color[2],
      b = color[3],
      opacity = 1 - (tonumber(color[4]) or 1),
      hasOpacity = true,
      swatchFunc = CommitPickerColor,
      opacityFunc = CommitPickerColor,
      cancelFunc = ColorPickerFrame.cancelFunc,
    })
    return
  end
  ColorPickerFrame.previousValues = previous
  ColorPickerFrame.hasOpacity = true
  ColorPickerFrame.opacity = 1 - (tonumber(color[4]) or 1)
  ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])
  ColorPickerFrame:Hide()
  ColorPickerFrame:Show()
end

local function GetSettingsScrollLayout()
  return WSGH.Const
    and WSGH.Const.UI
    and WSGH.Const.UI.settings
    and WSGH.Const.UI.settings.scroll
    or {}
end

local function UpdateSettingsScrollHeight()
  if not settingsScrollContent then return end

  local layout = GetSettingsScrollLayout()
  local minHeight = tonumber(layout.minChildHeight) or 760
  local bottomPadding = tonumber(layout.bottomPadding) or 36
  local contentTop = settingsScrollContent.GetTop and settingsScrollContent:GetTop() or nil
  local measuredHeight = 0

  if contentTop then
    for _, child in ipairs({ settingsScrollContent:GetChildren() }) do
      if child and child.IsShown and child:IsShown() and child.GetBottom then
        local childBottom = child:GetBottom()
        if childBottom then
          measuredHeight = math.max(measuredHeight, contentTop - childBottom + bottomPadding)
        end
      end
    end
  end

  local nextHeight = math.max(minHeight, math.ceil(measuredHeight))
  settingsScrollContentHeight = nextHeight
  settingsScrollContent:SetHeight(nextHeight)

  if settingsScrollFrame and settingsScrollFrame.GetVerticalScroll then
    local viewHeight = settingsScrollFrame.GetHeight and settingsScrollFrame:GetHeight() or 0
    local maxScroll = math.max(0, nextHeight - viewHeight)
    local current = settingsScrollFrame:GetVerticalScroll() or 0
    if current > maxScroll then
      settingsScrollFrame:SetVerticalScroll(maxScroll)
      if settingsScrollFrame.ScrollBar and settingsScrollFrame.ScrollBar.SetValue then
        settingsScrollFrame.ScrollBar:SetValue(maxScroll)
      end
    end
  end
end

local function CreatePreviewLabel(parent, text, template, x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetText(text)
  return label
end

local function CreatePreviewBlock(parent, x, y, width, height)
  local block = parent:CreateTexture(nil, "BACKGROUND")
  block:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  block:SetSize(width, height)
  return block
end

local function CreatePreviewSwatch(parent, x, y, width, height)
  local swatch = CreatePreviewBlock(parent, x, y, width, height)
  swatch:SetDrawLayer("ARTWORK")
  return swatch
end

local function CreatePreviewButton(parent, text, x, y, width, height, enabled)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  button:SetSize(width, height)
  button:SetText(text)
  button:SetEnabled(enabled ~= false)
  button:EnableMouse(false)
  return button
end

local function ShowColorRoleTooltip(owner, role, extraLine)
  if not (owner and role and role.description) then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(role.label or role.key or "Color", 1, 1, 1)
  GameTooltip:AddLine(role.description, nil, nil, nil, true)
  if extraLine then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(extraLine, nil, nil, nil, true)
  end
  GameTooltip:Show()
end

local function CreateColorHelpButton(parent, role, rowLayout, y)
  if not (role and role.description) then return nil end

  local help = CreateFrame("Button", nil, parent)
  help:SetPoint(
    "TOPLEFT",
    parent,
    "TOPLEFT",
    tonumber(rowLayout.helpX) or 166,
    y + (tonumber(rowLayout.helpYOffset) or -3)
  )
  help:SetSize(tonumber(rowLayout.helpWidth) or 14, tonumber(rowLayout.helpHeight) or 14)

  local text = help:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetAllPoints(help)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("MIDDLE")
  text:SetText("?")
  help:SetScript("OnEnter", function(self)
    ShowColorRoleTooltip(self, role)
  end)
  help:SetScript("OnLeave", GameTooltip_Hide)
  return help
end

local function CreateColorPreview(parent)
  local layout = WSGH.Const and WSGH.Const.UI and WSGH.Const.UI.settings and WSGH.Const.UI.settings.colors or {}
  local previewLayout = layout.preview or {}
  local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  preview:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, tonumber(previewLayout.yOffset) or -34)
  preview:SetSize(tonumber(previewLayout.width) or 540, tonumber(previewLayout.height) or 112)
  preview:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  preview:SetBackdropColor(0.03, 0.03, 0.03, 0.55)
  preview:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

  colorPreview.buttonDefault = CreatePreviewButton(preview, "Socket", 10, -12, 70, 20, true)
  colorPreview.buttonReforge = CreatePreviewButton(preview, "Reforge*", 88, -12, 82, 20, true)
  colorPreview.buttonDone = CreatePreviewButton(preview, "Done", 178, -12, 70, 20, false)
  colorPreview.buttonDisabled = CreatePreviewButton(preview, "Purchase", 256, -12, 82, 20, false)
  colorPreview.previewButton = colorPreview.buttonDefault

  colorPreview.highlightTarget = CreateFrame("Frame", nil, preview, "BackdropTemplate")
  colorPreview.highlightTarget:SetPoint("TOPLEFT", preview, "TOPLEFT", 370, -8)
  colorPreview.highlightTarget:SetSize(28, 28)
  colorPreview.highlightTarget:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  colorPreview.highlightTarget:SetBackdropColor(0.08, 0.08, 0.08, 0.75)
  colorPreview.highlightTarget:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

  colorPreview.windowBackground = CreatePreviewSwatch(preview, 418, -12, 44, 20)
  colorPreview.windowBackgroundLabel = CreatePreviewLabel(preview, "Main", "GameFontNormalSmall", 426, -15)
  colorPreview.reminderBackground = CreatePreviewSwatch(preview, 474, -12, 48, 20)
  colorPreview.reminderBackgroundLabel = CreatePreviewLabel(preview, "Note", "GameFontNormalSmall", 484, -15)

  return preview
end

local function CreateColorSettingsSection(parent, anchor, xOffset, yOffset)
  local layout = WSGH.Const and WSGH.Const.UI and WSGH.Const.UI.settings and WSGH.Const.UI.settings.colors or {}
  local openWindowButtonLayout = layout.openWindowButton or {}
  local resetAllButtonLayout = layout.resetAllButton or {}
  local rowLayout = layout.row or {}
  local section = CreateFrame("Frame", nil, parent)
  colorSectionFrame = section
  colorSectionHeight = tonumber(layout.height) or 760
  section:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset or 0, yOffset or -12)
  section:SetSize(tonumber(layout.width) or 560, colorSectionHeight)

  local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
  title:SetText("Colors")

  colorSectionContent = CreateFrame("Frame", nil, section)
  colorSectionContent:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
  colorSectionContent:SetSize(tonumber(layout.width) or 560, tonumber(layout.contentHeight) or 740)

  local note = colorSectionContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", colorSectionContent, "TOPLEFT", 0, -18)
  note:SetWidth(tonumber(layout.noteWidth) or 520)
  note:SetJustifyH("LEFT")
  note:SetText("Swatches open the color picker. Dropdowns offer quick presets.")

  CreateColorPreview(colorSectionContent)

  colorResetAllButton = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
  colorResetAllButton:SetSize(tonumber(resetAllButtonLayout.width) or 104, tonumber(resetAllButtonLayout.height) or 20)
  colorResetAllButton:SetPoint(
    "TOPRIGHT",
    section,
    "TOPRIGHT",
    tonumber(resetAllButtonLayout.xOffset) or -16,
    tonumber(resetAllButtonLayout.yOffset) or 2
  )
  colorResetAllButton:SetText("Reset all colors")
  colorResetAllButton:SetScript("OnClick", function()
    StaticPopup_Show("WSGH_RESET_ALL_COLORS")
  end)

  colorOpenWindowButton = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
  colorOpenWindowButton:SetSize(tonumber(openWindowButtonLayout.width) or 92, tonumber(openWindowButtonLayout.height) or 20)
  colorOpenWindowButton:SetPoint(
    "TOPRIGHT",
    section,
    "TOPRIGHT",
    tonumber(openWindowButtonLayout.xOffset) or -118,
    tonumber(openWindowButtonLayout.yOffset) or 2
  )
  colorOpenWindowButton:SetText("Open window")
  colorOpenWindowButton:SetScript("OnClick", function()
    if WSGH.UI and WSGH.UI.Show then
      WSGH.UI.Show()
    end
  end)
  colorOpenWindowButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Open WSGH", 1, 1, 1)
    GameTooltip:AddLine("Show the addon window so color changes can be previewed live.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  colorOpenWindowButton:SetScript("OnLeave", GameTooltip_Hide)

  local y = tonumber(rowLayout.topOffset) or -136
  colorRows = {}
  for _, group in ipairs(WSGH.Util.GetColorRoleGroups and WSGH.Util.GetColorRoleGroups() or {}) do
    local heading = colorSectionContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", colorSectionContent, "TOPLEFT", 0, y)
    heading:SetText(group.heading or "")
    y = y - (tonumber(rowLayout.headingGap) or 20)

    for _, role in ipairs(group.roles or {}) do
      local roleKey = role.key
      local label = colorSectionContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      label:SetPoint(
        "TOPLEFT",
        colorSectionContent,
        "TOPLEFT",
        tonumber(rowLayout.labelX) or 8,
        y + (tonumber(rowLayout.labelYOffset) or -2)
      )
      label:SetWidth(tonumber(rowLayout.labelWidth) or 170)
      label:SetJustifyH("LEFT")
      label:SetText(role.label or roleKey)
      CreateColorHelpButton(colorSectionContent, role, rowLayout, y)

      local swatch = CreateFrame("Button", nil, colorSectionContent, "BackdropTemplate")
      swatch:SetPoint("TOPLEFT", colorSectionContent, "TOPLEFT", tonumber(rowLayout.swatchX) or 184, y)
      swatch:SetSize(tonumber(rowLayout.swatchWidth) or 22, tonumber(rowLayout.swatchHeight) or 18)
      swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      swatch:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
      swatch.texture = swatch:CreateTexture(nil, "ARTWORK")
      swatch.texture:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
      swatch.texture:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)
      swatch:SetScript("OnClick", function()
        OpenColorPicker(roleKey)
      end)
      if role.description then
        swatch:SetScript("OnEnter", function(self)
          ShowColorRoleTooltip(self, role)
        end)
        swatch:SetScript("OnLeave", GameTooltip_Hide)
      end

      local dropName = "WSGHColorPreset" .. tostring(#colorRows + 1)
      local drop = CreateFrame("Frame", dropName, colorSectionContent, "UIDropDownMenuTemplate")
      drop:SetPoint(
        "TOPLEFT",
        swatch,
        "TOPRIGHT",
        tonumber(rowLayout.dropdownOffsetX) or -10,
        tonumber(rowLayout.dropdownOffsetY) or 2
      )
      UIDropDownMenu_SetWidth(drop, tonumber(rowLayout.dropdownWidth) or 112)
      UIDropDownMenu_Initialize(drop, function(_, level)
        local _, selectedValue = GetSelectedColorPreset(roleKey)
        for _, preset in ipairs(COLOR_PRESETS) do
          if ShouldShowColorPreset(roleKey, preset) then
            local info = UIDropDownMenu_CreateInfo()
            info.text = FormatColorPresetText(preset)
            info.value = preset.value
            info.isNotRadio = false
            info.keepShownOnClick = false
            info.func = function()
              if preset.customPicker then
                OpenColorPicker(roleKey)
              elseif preset.value == "DEFAULT" then
                ResetRoleColor(roleKey)
              else
                SetRoleColor(roleKey, preset.color)
              end
              if CloseDropDownMenus then
                CloseDropDownMenus()
              end
            end
            info.checked = selectedValue == preset.value
            UIDropDownMenu_AddButton(info, level)
          end
        end
      end)

      local reset = CreateFrame("Button", nil, colorSectionContent, "UIPanelButtonTemplate")
      reset:SetPoint(
        "LEFT",
        drop,
        "RIGHT",
        tonumber(rowLayout.resetOffsetX) or -6,
        tonumber(rowLayout.resetOffsetY) or 0
      )
      reset:SetSize(tonumber(rowLayout.resetWidth) or 44, tonumber(rowLayout.resetHeight) or 20)
      reset:SetText("Reset")
      reset:SetScript("OnClick", function()
        ResetRoleColor(roleKey)
      end)

      colorRows[#colorRows + 1] = {
        roleKey = roleKey,
        swatchTexture = swatch.texture,
        dropdown = drop,
        reset = reset,
      }
      y = y - (tonumber(rowLayout.rowHeight) or 24)
    end
    y = y - (tonumber(rowLayout.groupGap) or 4)
  end
  local sectionHeight = math.max(tonumber(layout.height) or 760, math.abs(y) + 24)
  colorSectionHeight = sectionHeight
  section:SetHeight(sectionHeight)
  colorSectionContent:SetHeight(sectionHeight - 20)

  if not StaticPopupDialogs["WSGH_RESET_ALL_COLORS"] then
    StaticPopupDialogs["WSGH_RESET_ALL_COLORS"] = {
      text = "Reset all WowSims Gear Helper colors to their defaults?",
      button1 = "Reset",
      button2 = "Cancel",
      OnAccept = function()
        if WSGH.Util and WSGH.Util.ResetAllColors then
          WSGH.Util.ResetAllColors()
        end
        WSGH.UI.Settings.RefreshColorControls()
        ApplyColorRefresh()
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end

  UpdateSettingsScrollHeight()
  WSGH.UI.Settings.RefreshColorControls()
  return section
end

local function BuildOptionsPanel()
  if optionsPanel then return end

  local categoryName = "WowSims Gear Helper"
  optionsPanel = CreateFrame("Frame", "WowSimsGearHelperOptions", InterfaceOptionsFramePanelContainer or UIParent)
  optionsPanel.name = categoryName

  local scrollLayout = GetSettingsScrollLayout()
  local optionsScroll = CreateFrame("ScrollFrame", "WowSimsGearHelperOptionsScroll", optionsPanel, "UIPanelScrollFrameTemplate")
  settingsScrollFrame = optionsScroll
  optionsScroll:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, 0)
  optionsScroll:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -(tonumber(scrollLayout.rightInset) or 28), 0)
  optionsScroll:EnableMouseWheel(true)

  local optionsContent = CreateFrame("Frame", "WowSimsGearHelperOptionsContent", optionsScroll)
  settingsScrollContent = optionsContent
  settingsScrollContentHeight = tonumber(scrollLayout.minChildHeight) or 760
  optionsContent:SetSize(
    tonumber(scrollLayout.childWidth) or 640,
    settingsScrollContentHeight
  )
  optionsScroll:SetScrollChild(optionsContent)
  optionsScroll:SetScript("OnMouseWheel", function(self, delta)
    local childHeight = settingsScrollContent and settingsScrollContent:GetHeight() or 0
    local viewHeight = self.GetHeight and self:GetHeight() or 0
    local maxScroll = math.max(0, childHeight - viewHeight)
    local current = self.GetVerticalScroll and self:GetVerticalScroll() or 0
    local step = tonumber(scrollLayout.mouseWheelStep) or 36
    local nextScroll = current - ((tonumber(delta) or 0) * step)
    if nextScroll < 0 then nextScroll = 0 end
    if nextScroll > maxScroll then nextScroll = maxScroll end
    self:SetVerticalScroll(nextScroll)
    if self.ScrollBar and self.ScrollBar.SetValue then
      self.ScrollBar:SetValue(nextScroll)
    end
  end)

  local title = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", optionsContent, "TOPLEFT", 16, -16)
  title:SetText(categoryName)

  local desc = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  desc:SetText("Preferences")

  local addonVersion = WSGH.Util and WSGH.Util.GetAddonVersion and WSGH.Util.GetAddonVersion() or (WSGH.VERSION or "unknown")
  local versionText = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  versionText:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -4)
  versionText:SetText(("Version: %s"):format(tostring(addonVersion)))

  local preferences = GetPreferences() or {}
  CreateTaskPrioritySection(optionsContent, versionText)

  local persistCheck = CreateFrame("CheckButton", nil, optionsContent, "ChatConfigCheckButtonTemplate")
  persistCheck:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -8)
  persistCheck.Text:SetText("Save last import")
  persistCheck:SetChecked(preferences.persistImports or false)

  local restoreReminderCheck = CreateFrame("CheckButton", nil, optionsContent, "ChatConfigCheckButtonTemplate")
  restoreReminderCheck:SetPoint("TOPLEFT", persistCheck, "BOTTOMLEFT", 18, -4)
  restoreReminderCheck.Text:SetText("Show manual reforge reminder on restore")
  restoreReminderCheck:SetChecked(preferences.showReforgeReminderOnRestore == true)

  local function RefreshRestoreReminderCheck()
    local enabled = persistCheck:GetChecked() == true
    restoreReminderCheck:SetEnabled(enabled)
    if enabled then
      SetFontColor(restoreReminderCheck.Text, "text.normal")
    else
      SetFontColor(restoreReminderCheck.Text, "text.muted")
    end
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

  local minimapCheck = CreateFrame("CheckButton", nil, optionsContent, "ChatConfigCheckButtonTemplate")
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

  local useValorCheck = CreateFrame("CheckButton", nil, optionsContent, "ChatConfigCheckButtonTemplate")
  useValorCheck:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 0, -6)
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

  local reforgeReminderCheck = CreateFrame("CheckButton", nil, optionsContent, "ChatConfigCheckButtonTemplate")
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

  local reforgeLiteSyncCheck = CreateFrame("CheckButton", nil, optionsContent, "ChatConfigCheckButtonTemplate")
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

  local minimizeAtForgeCheck = CreateFrame("CheckButton", nil, optionsContent, "ChatConfigCheckButtonTemplate")
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

  local restoreAfterForgeCheck = CreateFrame("CheckButton", nil, optionsContent, "ChatConfigCheckButtonTemplate")
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

  local highlightLabel = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  highlightLabel:SetPoint("TOPLEFT", restoreAfterForgeCheck, "BOTTOMLEFT", 0, -16)
  highlightLabel:SetText("Highlight style:")

  local highlightDrop = CreateFrame("Frame", "WSGHHighlightStyle", optionsContent, "UIDropDownMenuTemplate")
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
        if WSGH.UI and WSGH.UI.Settings and WSGH.UI.Settings.RefreshColorControls then
          WSGH.UI.Settings.RefreshColorControls()
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

  local tinkerLabel = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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

  local dropdownAnchor = CreateFrame("Frame", nil, optionsContent)
  dropdownAnchor:SetPoint("TOPLEFT", tinkerLabel, "BOTTOMLEFT", 0, -6)
  dropdownAnchor:SetSize(1, 1)
  dropdownAnchor:SetShown(WSGH.Diff and WSGH.Diff.Engine and WSGH.Diff.Engine.ENABLE_TINKERS == true)
  local nextYOffset = 0

  local function CreateTinkerDropdown(name, labelText, slotId, options)
    local showTinkers = (WSGH.Diff and WSGH.Diff.Engine and WSGH.Diff.Engine.ENABLE_TINKERS == true)
    local label = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", dropdownAnchor, "TOPLEFT", 0, nextYOffset)
    label:SetText(labelText)
    label:SetShown(showTinkers)

    local drop = CreateFrame("Frame", name, optionsContent, "UIDropDownMenuTemplate")
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

  if WSGH.Diff and WSGH.Diff.Engine and WSGH.Diff.Engine.ENABLE_TINKERS == true then
    CreateColorSettingsSection(optionsContent, dropdownAnchor, 0, nextYOffset - 8)
  else
    CreateColorSettingsSection(optionsContent, highlightDrop, 16, -12)
  end
  UpdateSettingsScrollHeight()
  if C_Timer and C_Timer.After then
    C_Timer.After(0, UpdateSettingsScrollHeight)
  end
  optionsPanel:SetScript("OnShow", function()
    UpdateSettingsScrollHeight()
    if C_Timer and C_Timer.After then
      C_Timer.After(0, UpdateSettingsScrollHeight)
    end
  end)

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

local WSGH = _G.WowSimsGearHelper or {}
WSGH.UI = WSGH.UI or {}

local function GetPreferences()
  if not (WSGH.DB and WSGH.DB.profile) then return nil end
  return WSGH.DB.profile.prefs
end

local function UpdateImportEditBoxSize(scroll, editBox)
  local width = scroll:GetWidth()
  local height = scroll:GetHeight()
  if width <= 0 then width = 1 end
  if height <= 0 then height = 1 end

  editBox:SetWidth(width)

  local textHeight
  if editBox.GetStringHeight then
    textHeight = editBox:GetStringHeight()
  elseif editBox.GetTextHeight then
    textHeight = editBox:GetTextHeight()
  else
    textHeight = 0
  end
  if not textHeight or textHeight <= 0 then
    textHeight = height
  end

  editBox:SetHeight(math.max(height, textHeight + 20))
  scroll:UpdateScrollChildRect()
end

function WSGH.UI.EnsureImportDialog()
  if WSGH.UI.importDialog then return end

  local dialog = CreateFrame("Frame", "WowSimsGearHelperImportDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(560, 360)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  dialog:SetClampedToScreen(true)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetToplevel(true)
  dialog:EnableMouse(true)
  dialog:SetMovable(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
  dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  dialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })

  table.insert(UISpecialFrames, "WowSimsGearHelperImportDialog")

  local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("Import")

  local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -5, -5)

  local help = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", 18, -44)
  help:SetText("Enter WowSims JSON Export")
  help:SetTextColor(1, 0.82, 0)

  local inputWrap = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
  inputWrap:SetPoint("TOPLEFT", 18, -64)
  inputWrap:SetPoint("BOTTOMRIGHT", -18, 52)
  inputWrap:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 10, right = 10, top = 10, bottom = 10 },
  })
  inputWrap:SetBackdropColor(0, 0, 0, 0.9)
  inputWrap:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)

  local inputBg = CreateFrame("Frame", nil, inputWrap, "BackdropTemplate")
  inputBg:SetPoint("TOPLEFT", inputWrap, "TOPLEFT", 6, -6)
  inputBg:SetPoint("BOTTOMRIGHT", inputWrap, "BOTTOMRIGHT", -6, 6)
  inputBg:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  inputBg:SetBackdropColor(0, 0, 0, 0.85)
  inputBg:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)

  local scroll = CreateFrame("ScrollFrame", nil, inputWrap, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", inputBg, "TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", inputBg, "BOTTOMRIGHT", -6, 6)

  local editBox = CreateFrame("EditBox", nil, scroll)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetTextColor(1, 1, 1, 1)
  editBox:SetAltArrowKeyMode(false)
  editBox:SetTextInsets(6, 6, 6, 6)
  editBox:SetMaxLetters(0)
  editBox:SetPoint("TOPLEFT")

  editBox:SetScript("OnTextChanged", function(self)
    if WSGH.UI.importDialog then
      if WSGH.UI.importDialog.skipNextTextChange then
        WSGH.UI.importDialog.skipNextTextChange = false
        return
      end
      if WSGH.UI.importDialog.autoRunning then return end
    end
    UpdateImportEditBoxSize(scroll, self)
    local text = WSGH.Util.Trim(self:GetText() or "")
    if text ~= "" then
      WSGH.UI.importDialog.autoRunning = true
      WSGH.UI.ImportFromDialog()
    end
  end)
  editBox:SetScript("OnUpdate", function(self)
    UpdateImportEditBoxSize(scroll, self)
    self:SetScript("OnUpdate", nil)
  end)
  editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  editBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)

  scroll:SetScrollChild(editBox)
  scroll:SetScript("OnSizeChanged", function()
    UpdateImportEditBoxSize(scroll, editBox)
  end)
  inputWrap:SetScript("OnSizeChanged", function()
    UpdateImportEditBoxSize(scroll, editBox)
  end)
  inputWrap:SetScript("OnMouseDown", function()
    editBox:SetFocus()
  end)

  local accept = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  accept:SetSize(90, 22)
  accept:SetPoint("BOTTOMLEFT", 18, 18)
  accept:SetText("Accept")
  accept:SetScript("OnClick", function()
    WSGH.UI.ImportFromDialog()
  end)

  local cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  cancel:SetSize(90, 22)
  cancel:SetPoint("LEFT", accept, "RIGHT", 10, 0)
  cancel:SetText("Close")
  cancel:SetScript("OnClick", function() dialog:Hide() end)

  dialog:SetScript("OnShow", function()
    dialog.autoRunning = false
    dialog.skipNextTextChange = true
    editBox:SetFocus()
    editBox:SetCursorPosition(string.len(editBox:GetText() or ""))
    UpdateImportEditBoxSize(scroll, editBox)
    dialog.skipNextTextChange = true
    editBox:SetText("")
    editBox:SetCursorPosition(0)
  end)
  dialog:SetScript("OnHide", function()
    dialog.autoRunning = false
    dialog.skipNextTextChange = true
    editBox:SetText("")
    editBox:ClearFocus()
  end)

  dialog:Hide()

  WSGH.UI.importDialog = dialog
  WSGH.UI.importEditBox = editBox
  WSGH.UI.importAccept = accept
end

function WSGH.UI.ImportFromDialog()
  if not (WSGH.UI.importEditBox and WSGH.UI.importDialog) then return end

  WSGH.State = WSGH.State or {}

  local text = WSGH.Util.Trim(WSGH.UI.importEditBox:GetText() or "")
  if text == "" then
    WSGH.Util.Print("Nothing to import.")
    return
  end

  local plan, err = WSGH.Import.FromJson(text)
  if not plan then
    WSGH.Util.Print(err)
    if WSGH.UI.importDialog then
      WSGH.UI.importDialog.skipNextTextChange = true
      WSGH.UI.importEditBox:SetText("")
      WSGH.UI.importDialog.autoRunning = false
    end
    return
  end

  if WSGH.UI.ResetRuntimeState then
    WSGH.UI.ResetRuntimeState()
  end

  WSGH.State = WSGH.State or {}
  WSGH.State.plan = plan

  local equipped = WSGH.Scan.Equipped.GetState()
  local diff, derr = WSGH.Diff.Build(plan, equipped)
  if not diff then
    WSGH.Util.Print("Diff failed: " .. tostring(derr))
    if WSGH.UI.importDialog then WSGH.UI.importDialog.autoRunning = false end
    return
  end

  WSGH.State.diff = diff
  WSGH.UI.Render()
  WSGH.Util.Print("Imported.")
  WSGH.UI.importEditBox:ClearFocus()
  if WSGH.UI.importDialog then WSGH.UI.importDialog.autoRunning = false end
  WSGH.UI.importDialog:Hide()

  local preferences = GetPreferences()
  if preferences then
    if preferences.persistImports then
      preferences.savedImportText = text
    else
      preferences.savedImportText = nil
    end
  end
end

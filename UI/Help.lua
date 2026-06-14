local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.UI = WSGH.UI or {}
WSGH.UI.Help = WSGH.UI.Help or {}

local Help = WSGH.UI.Help

local function SetHelpTooltip(widget)
  widget:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Help", 1, 0.82, 0)
    GameTooltip:AddLine("Click for help.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", GameTooltip_Hide)
end

local function AddTextBlock(parent, cursorY, text, template, width, spacingTop, spacingBottom, color)
  local label = parent:CreateFontString(nil, "OVERLAY", template)
  label:SetPoint("TOPLEFT", 0, cursorY - (spacingTop or 0))
  label:SetWidth(width)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(true)
  label:SetText(text)
  if color then
    label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  end
  return label, (cursorY - (spacingTop or 0) - label:GetStringHeight() - (spacingBottom or 0))
end

local function PopulateGuide(parent, cursorY, width)
  local textColor = { 1, 1, 1 }
  local noteColor = { 0.82, 0.9, 1 }

  _, cursorY = AddTextBlock(parent, cursorY, "Guide", "GameFontNormalLarge", width, 0, 8, { 1, 0.82, 0 })
  _, cursorY = AddTextBlock(parent, cursorY, "Optional: use the WowSims exporter addon if you want to move your current character into WowSims first. If your target setup is already ready in WowSims, skip that step.", "GameFontHighlightSmall", width, 0, 8, textColor)
  _, cursorY = AddTextBlock(parent, cursorY, "1. Make the gear changes you want in WowSims.", "GameFontHighlightSmall", width, 0, 4, textColor)
  _, cursorY = AddTextBlock(parent, cursorY, "2. In WowSims, use the ReforgeLite export button, or click Export -> JSON.", "GameFontHighlightSmall", width, 0, 4, textColor)
  _, cursorY = AddTextBlock(parent, cursorY, "3. In-game, click Import and paste that export.", "GameFontHighlightSmall", width, 0, 4, textColor)
  _, cursorY = AddTextBlock(parent, cursorY, "4. Review the plan by hovering item badges, socket icons, and shopping entries.", "GameFontHighlightSmall", width, 0, 4, textColor)
  _, cursorY = AddTextBlock(parent, cursorY, "4a. Double-check the plan before you buy anything.", "GameFontHighlightSmall", width, 0, 4, textColor)
  _, cursorY = AddTextBlock(parent, cursorY, "5. Buy what you still need from the shopping list. Auction House search buttons use the default Auction House only.", "GameFontHighlightSmall", width, 0, 4, textColor)
  _, cursorY = AddTextBlock(parent, cursorY, "6. Apply the gems, enchants, items, and upgrades the plan calls for.", "GameFontHighlightSmall", width, 0, 4, textColor)
  _, cursorY = AddTextBlock(parent, cursorY, "Item badges summarize import warnings and remaining tasks; hover the badge for details.", "GameFontNormalSmall", width, 2, 8, noteColor)

  _, cursorY = AddTextBlock(parent, cursorY, "Settings and reminder", "GameFontNormal", width, 0, 6, { 1, 0.82, 0 })
  _, cursorY = AddTextBlock(parent, cursorY, "Use the Settings button if you want to adjust the addon's preferences.", "GameFontHighlightSmall", width, 0, 4)
  _, cursorY = AddTextBlock(parent, cursorY, "If ReforgeLite Classic is enabled, successful imports can sync the same export into ReforgeLite. You can turn that off in Settings.", "GameFontHighlightSmall", width, 0, 8)

  _, cursorY = AddTextBlock(parent, cursorY, "Limits and expectations", "GameFontNormal", width, 0, 6, { 1, 0.82, 0 })
  _, cursorY = AddTextBlock(parent, cursorY, "The addon follows the imported data literally. Verify the result yourself before you buy or apply anything.", "GameFontNormalSmall", width, 0, 6, noteColor)
  _, cursorY = AddTextBlock(parent, cursorY, "The addon guides gear, gem, enchant, upgrade, and reforge changes. It does not automate those actions for you.", "GameFontHighlightSmall", width, 0, 4)
  _, cursorY = AddTextBlock(parent, cursorY, "Reforging is handed off to ReforgeLite Classic when present. WSGH will catch the updates as they happen and update the UI.", "GameFontHighlightSmall", width, 0, 8)

  return cursorY
end

function Help.RefreshLayout()
  if not Help.dialog or not Help.scrollChild then return end

  local uiHelp = WSGH.Const.UI.help
  local dialogConfig = uiHelp.dialog
  local contentWidth = uiHelp.quickWidth
  local cursorY = 0

  if Help.content then
    Help.content:Hide()
  end

  local content = CreateFrame("Frame", nil, Help.scrollChild)
  content:SetPoint("TOPLEFT")
  content:SetSize(contentWidth, 1)
  Help.content = content

  cursorY = PopulateGuide(content, cursorY, contentWidth)

  local finalHeight = math.max(math.abs(cursorY) + 12, 1)
  content:SetSize(contentWidth, finalHeight)
  Help.scrollChild:SetSize(contentWidth, finalHeight)
  Help.scroll:SetVerticalScroll(0)

  Help.dialog:SetHeight(dialogConfig.height)
  content:Show()
end

function Help.SetExpanded(expanded)
  Help.RefreshLayout()
end

function Help.Show(mode)
  Help.EnsureDialog()
  Help.SetExpanded(mode == "details")
  Help.dialog:SetFrameStrata("FULLSCREEN_DIALOG")
  Help.dialog:Raise()
  Help.dialog:Show()
end

function Help.EnsureDialog()
  if Help.dialog then return end

  local uiHelp = WSGH.Const.UI.help
  local dialogConfig = uiHelp.dialog
  local dialog = CreateFrame("Frame", "WowSimsGearHelperHelpDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(dialogConfig.width, dialogConfig.height)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, dialogConfig.topOffset)
  dialog:SetClampedToScreen(true)
  dialog:SetFrameStrata("FULLSCREEN_DIALOG")
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
  table.insert(UISpecialFrames, "WowSimsGearHelperHelpDialog")
  if WSGH.Util and WSGH.Util.ApplyOpaqueWindowBackground then
    WSGH.Util.ApplyOpaqueWindowBackground(dialog, "help")
  end

  local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", dialogConfig.padding, -dialogConfig.padding)
  title:SetText("Help")

  local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -5, -5)

  local intro = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  intro:SetWidth(dialogConfig.width - (dialogConfig.padding * 2) - 30)
  intro:SetJustifyH("LEFT")
  intro:SetWordWrap(true)
  intro:SetText("From WowSims export to in-game changes.")

  local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
  scroll:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -36, 20)

  local scrollChild = CreateFrame("Frame", nil, scroll)
  scrollChild:SetPoint("TOPLEFT")
  scrollChild:SetSize(uiHelp.quickWidth, 1)
  scroll:SetScrollChild(scrollChild)

  if scroll.ScrollBar then
    scroll.ScrollBar:ClearAllPoints()
    scroll.ScrollBar:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -20, -54)
    scroll.ScrollBar:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 24)
  end

  Help.dialog = dialog
  Help.scroll = scroll
  Help.scrollChild = scrollChild
  Help.content = nil
  Help.RefreshLayout()
end

Help.SetHelpTooltip = SetHelpTooltip

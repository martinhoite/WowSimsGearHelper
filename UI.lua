local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.UI = WSGH.UI or {}
WSGH.Debug = WSGH.Debug or {}

local function SavePosition(frame)
  local ui = WSGH.DB.profile.ui
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  ui.point = point
  ui.relativePoint = relativePoint
  ui.x = x
  ui.y = y
end

local function RestorePosition(frame)
  local ui = WSGH.DB.profile.ui
  frame:ClearAllPoints()
  frame:SetPoint(ui.point, UIParent, ui.relativePoint, ui.x, ui.y)
end

local function CloseUIForCombat()
  if not (WSGH.UI.frame and WSGH.UI.frame:IsShown()) then return end
  WSGH.UI.Hide()
  WSGH.Util.Print("Closed during combat; reopen with /wsgh.")
end

local function EnsureUIState()
  WSGH.State = WSGH.State or {}
  WSGH.State.plan = WSGH.State.plan or nil
  WSGH.State.diff = WSGH.State.diff or nil
end

WSGH.UI.Guide = WSGH.UI.Guide or {}
local Guide = WSGH.UI.Guide
Guide.currentAction = Guide.currentAction or nil
Guide.tinkerSelectionRequestId = tonumber(Guide.tinkerSelectionRequestId) or 0

local function ResetRuntimeState()
  EnsureUIState()
  WSGH.State.plan = nil
  WSGH.State.diff = nil
  Guide.currentAction = nil
  Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
  WSGH.UI.pendingPurchases = {}

  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetTarget then
    WSGH.UI.Highlight.SetTarget(nil, nil)
  elseif WSGH.UI.Highlight and WSGH.UI.Highlight.ClearAll then
    WSGH.UI.Highlight.ClearAll()
  end
  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetEnchantTarget then
    WSGH.UI.Highlight.SetEnchantTarget(nil, nil, nil)
  end

  if WSGH.UI.scroll then
    FauxScrollFrame_SetOffset(WSGH.UI.scroll, 0)
    if WSGH.UI.scroll.ScrollBar then
      WSGH.UI.scroll.ScrollBar:SetValue(0)
    end
  end
  if WSGH.UI.shoppingScroll then
    FauxScrollFrame_SetOffset(WSGH.UI.shoppingScroll, 0)
    if WSGH.UI.shoppingScroll.ScrollBar then
      WSGH.UI.shoppingScroll.ScrollBar:SetValue(0)
    end
  end

  if WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateShoppingList then
    WSGH.UI.Shopping.UpdateShoppingList()
  end
end
WSGH.UI.ResetRuntimeState = ResetRuntimeState

local function FindNextPendingSocketTask(rowData)
  if not rowData then return nil end
  for _, task in ipairs(rowData.socketTasks or {}) do
    if task and task.status ~= WSGH.Const.STATUS_OK then
      return task
    end
  end
  return nil
end

local function FindNextPendingEnchantTask(rowData)
  if not rowData then return nil end
  for _, task in ipairs(rowData.enchantTasks or {}) do
    if task and task.status ~= WSGH.Const.STATUS_OK then
      return task
    end
  end
  return nil
end

local function HasPendingUpgradeTask(rowData)
  if not rowData then return false end
  for _, task in ipairs(rowData.upgradeTasks or {}) do
    if task and task.status ~= WSGH.Const.STATUS_OK then
      return true
    end
  end
  return false
end

function WSGH.UI.GetRowActionPriority(rowData)
  local nextSocketTask = FindNextPendingSocketTask(rowData)
  local nextEnchantTask = FindNextPendingEnchantTask(rowData)
  return {
    nextSocketTask = nextSocketTask,
    nextEnchantTask = nextEnchantTask,
    hasSocketWork = nextSocketTask ~= nil,
    hasEnchantWork = nextEnchantTask ~= nil,
    hasUpgradeWork = HasPendingUpgradeTask(rowData),
  }
end

local function DetermineNextAction(rowData)
  if not rowData or rowData.rowStatus ~= "NEEDS_WORK" then return nil end
  local priority = WSGH.UI.GetRowActionPriority(rowData)
  if priority.nextSocketTask then
    return {
      type = "SOCKET_GEM",
      task = priority.nextSocketTask,
    }
  end
  if priority.nextEnchantTask then
    return {
      type = priority.nextEnchantTask.type or "APPLY_ENCHANT",
      task = priority.nextEnchantTask,
    }
  end
  return nil
end

local function GetRowBySlotId(slotId)
  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.rows then return nil end
  for _, row in ipairs(diff.rows) do
    if tonumber(row.slotId) == tonumber(slotId) then
      return row
    end
  end
  return nil
end

local function IsSocketTaskResolved(task)
  if not task then return true end
  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.tasks then return false end
  for _, t in ipairs(diff.tasks) do
    if t.slotId == task.slotId and t.socketIndex == task.socketIndex and t.wantGemId == task.wantGemId then
      return false
    end
  end
  return true
end

local function IsEnchantTaskResolved(task)
  if not task then return true end
  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.tasks then return false end
  for _, t in ipairs(diff.tasks) do
    if t.slotId == task.slotId and t.wantEnchantId == task.wantEnchantId and t.type == task.type then
      return false
    end
  end
  return true
end

local function OpenSocketFrame(slotId)
  if not ItemSocketingFrame and LoadAddOn then
    pcall(LoadAddOn, "Blizzard_ItemSocketingUI")
  end
  if not SocketInventoryItem then return false end
  local ok = pcall(SocketInventoryItem, slotId)
  return ok and true or false
end

local function CloseSocketFrameIfOpen()
  if not (ItemSocketingFrame and ItemSocketingFrame:IsShown()) then
    return
  end
  if CloseSocketInfo then
    pcall(CloseSocketInfo)
  end
  if ItemSocketingFrame and ItemSocketingFrame:IsShown() then
    ItemSocketingFrame:Hide()
  end
end

local function OpenCharacterFrame()
  if CharacterFrame and CharacterFrame:IsShown() then return true end
  if ToggleCharacter then
    pcall(ToggleCharacter, "PaperDollFrame")
  end
  if CharacterFrame and CharacterFrame:IsShown() then return true end
  if ShowUIPanel and CharacterFrame then
    pcall(ShowUIPanel, CharacterFrame)
  end
  return CharacterFrame and CharacterFrame:IsShown()
end

local function GetEngineeringProfession()
  local professionName = nil
  local skillLineId = nil
  if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
    local prof1, prof2 = GetProfessions()
    for _, prof in ipairs({ prof1, prof2 }) do
      if prof then
        local name, _, _, _, _, _, skillLine = GetProfessionInfo(prof)
        if tonumber(skillLine) == 202 then
          professionName = name
          skillLineId = tonumber(skillLine)
          break
        end
      end
    end
  end
  return professionName, skillLineId
end

local function IsCurrentTradeSkillEngineering()
  local professionName = GetEngineeringProfession()

  if TradeSkillFrame and TradeSkillFrame:IsShown() and type(GetTradeSkillLine) == "function" then
    local openName = GetTradeSkillLine()
    if type(openName) == "string" and openName ~= "" then
      if professionName and openName == professionName then
        return true
      end
      local lowered = openName:lower()
      if lowered:find("engineer", 1, true) then
        return true
      end
      return false
    end
  end

  if ProfessionsFrame and ProfessionsFrame:IsShown() and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
    local ok, info = pcall(C_TradeSkillUI.GetTradeSkillLine)
    if ok and type(info) == "table" then
      if tonumber(info.skillLineID) == 202 then return true end
      if professionName and info.professionName == professionName then return true end
      if type(info.professionName) == "string" and info.professionName:lower():find("engineer", 1, true) then
        return true
      end
      return false
    end
  end

  return nil
end

local function IsEngineeringWindowOpen()
  local isEngineering = IsCurrentTradeSkillEngineering()
  if isEngineering ~= nil then
    return isEngineering
  end
  if TradeSkillFrame and TradeSkillFrame:IsShown() then return true end
  if ProfessionsFrame and ProfessionsFrame:IsShown() then return true end
  return false
end

local function OpenEngineeringProfession()
  if IsEngineeringWindowOpen() then
    return true
  end

  local professionName, skillLineId = GetEngineeringProfession()

  if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill and skillLineId then
    pcall(C_TradeSkillUI.OpenTradeSkill, skillLineId)
  end
  if professionName and CastSpellByName and not IsEngineeringWindowOpen() then
    pcall(CastSpellByName, professionName)
  end

  return IsEngineeringWindowOpen()
end

local function CloseEngineeringWindowIfOpen()
  if not IsEngineeringWindowOpen() then
    return
  end

  if type(CloseTradeSkill) == "function" then
    pcall(CloseTradeSkill)
  end

  if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then
    pcall(C_TradeSkillUI.CloseTradeSkill)
  end

  if TradeSkillFrame and TradeSkillFrame:IsShown() then
    TradeSkillFrame:Hide()
  end
  if ProfessionsFrame and ProfessionsFrame:IsShown() then
    ProfessionsFrame:Hide()
  end
end

local function TrySelectEngineeringRecipeByTinkerSpellId(tinkerSpellId)
  tinkerSpellId = tonumber(tinkerSpellId) or 0
  if tinkerSpellId == 0 then return false end
  local targetName = GetSpellInfo(tinkerSpellId)
  if not targetName or targetName == "" then return false end
  local targetNorm = WSGH.Util.NormalizeName(targetName, true)

  local hasLegacyTradeSkillApi =
    type(GetNumTradeSkills) == "function" and
    type(GetTradeSkillInfo) == "function" and
    type(SelectTradeSkill) == "function"

  -- MoP Classic primary path: legacy TradeSkill API.
  if hasLegacyTradeSkillApi then
    -- Ensure the full list is visible before matching by name.
    if type(SetTradeSkillItemNameFilter) == "function" then
      pcall(SetTradeSkillItemNameFilter, "")
    end
    if type(SetTradeSkillInvSlotFilter) == "function" then
      pcall(SetTradeSkillInvSlotFilter, -1, 1, 1)
    end
    if type(SetTradeSkillSubClassFilter) == "function" then
      pcall(SetTradeSkillSubClassFilter, 0, 1, 1)
    end

    local num = tonumber(GetNumTradeSkills()) or 0
    if type(ExpandTradeSkillSubClass) == "function" then
      for i = 1, num do
        local _, skillType, _, isExpanded = GetTradeSkillInfo(i)
        if skillType == "header" and not isExpanded then
          pcall(ExpandTradeSkillSubClass, i)
        end
      end
      num = tonumber(GetNumTradeSkills()) or num
    end
    local candidateIndex = nil
    for i = 1, num do
      local name, skillType = GetTradeSkillInfo(i)
      if skillType ~= "header" and name == targetName then
        candidateIndex = i
        break
      end
      if skillType ~= "header" and targetNorm ~= "" and WSGH.Util.NormalizeName(name, true) == targetNorm then
        candidateIndex = i
        break
      end
    end

    if candidateIndex then
      pcall(SelectTradeSkill, candidateIndex)
      -- Legacy TradeSkill UI can keep stale visual state while open.
      -- Force the selected row into view and refresh the panel so the
      -- current recipe display tracks the programmatic selection.
      if type(TradeSkillFrame_SetSelection) == "function" then
        pcall(TradeSkillFrame_SetSelection, candidateIndex)
      end
      if TradeSkillListScrollFrame then
        local visible = tonumber(_G.TRADE_SKILLS_DISPLAYED) or 8
        local desiredOffset = math.max(0, candidateIndex - visible)
        pcall(FauxScrollFrame_SetOffset, TradeSkillListScrollFrame, desiredOffset)
      end
      if type(TradeSkillFrame_Update) == "function" then
        pcall(TradeSkillFrame_Update)
      end
      if type(GetTradeSkillSelectionIndex) == "function" then
        local selected = tonumber(GetTradeSkillSelectionIndex()) or 0
        if selected == candidateIndex then
          return true
        end
        if selected > 0 then
          local selectedName, selectedType = GetTradeSkillInfo(selected)
          if selectedType ~= "header" and selectedName and WSGH.Util.NormalizeName(selectedName, true) == targetNorm then
            return true
          end
        end
        return false
      end
      return true
    end

    -- Keep MoP deterministic: if legacy API is present, do not branch into C_TradeSkillUI.
    return false
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.SelectRecipe then
    local recipeIds = C_TradeSkillUI.GetAllRecipeIDs() or {}
    for _, recipeId in ipairs(recipeIds) do
      local info = C_TradeSkillUI.GetRecipeInfo(recipeId)
      if info and info.name == targetName then
        pcall(C_TradeSkillUI.SelectRecipe, recipeId)
        return true
      end
      if info and targetNorm ~= "" and WSGH.Util.NormalizeName(info.name, true) == targetNorm then
        pcall(C_TradeSkillUI.SelectRecipe, recipeId)
        return true
      end
    end
  end

  return false
end

local function IsEngineeringRecipeSelected(tinkerSpellId)
  tinkerSpellId = tonumber(tinkerSpellId) or 0
  if tinkerSpellId == 0 then return false end
  local targetName = GetSpellInfo(tinkerSpellId)
  if not targetName or targetName == "" then return false end
  local targetNorm = WSGH.Util.NormalizeName(targetName, true)
  if targetNorm == "" then return false end

  if type(GetTradeSkillSelectionIndex) == "function" and type(GetTradeSkillInfo) == "function" then
    local selected = tonumber(GetTradeSkillSelectionIndex()) or 0
    if selected > 0 then
      local selectedName, selectedType = GetTradeSkillInfo(selected)
      if selectedType ~= "header" and selectedName and WSGH.Util.NormalizeName(selectedName, true) == targetNorm then
        return true
      end
    end
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetSelectedRecipeID and C_TradeSkillUI.GetRecipeInfo then
    local recipeId = tonumber(C_TradeSkillUI.GetSelectedRecipeID()) or 0
    if recipeId ~= 0 then
      local info = C_TradeSkillUI.GetRecipeInfo(recipeId)
      if info and WSGH.Util.NormalizeName(info.name, true) == targetNorm then
        return true
      end
    end
  end

  return false
end

local function TrySelectEngineeringRecipeWithRetry(tinkerSpellId, attemptsLeft, didForcedReopen, requestId)
  attemptsLeft = tonumber(attemptsLeft) or 0
  if attemptsLeft <= 0 then return false end
  didForcedReopen = didForcedReopen and true or false
  requestId = tonumber(requestId) or 0
  if requestId == 0 then return false end
  if requestId ~= (tonumber(Guide.tinkerSelectionRequestId) or 0) then
    return false
  end
  if not IsEngineeringWindowOpen() then
    if C_Timer and C_Timer.After and attemptsLeft > 1 then
      C_Timer.After(0.1, function()
        TrySelectEngineeringRecipeWithRetry(tinkerSpellId, attemptsLeft - 1, didForcedReopen, requestId)
      end)
    end
    return false
  end

  -- Always attempt selection, then verify the currently selected recipe.
  -- This avoids first-open race conditions and supports re-click re-selection.
  TrySelectEngineeringRecipeByTinkerSpellId(tinkerSpellId)
  if IsEngineeringRecipeSelected(tinkerSpellId) then
    return true
  end

  -- If selection keeps failing while the frame is open, force one reopen to
  -- reset internal trade-skill state, then continue retries.
  if not didForcedReopen and attemptsLeft <= 12 then
    CloseEngineeringWindowIfOpen()
    OpenEngineeringProfession()
    didForcedReopen = true
  end

  if C_Timer and C_Timer.After and attemptsLeft > 1 then
    C_Timer.After(0.1, function()
      TrySelectEngineeringRecipeWithRetry(tinkerSpellId, attemptsLeft - 1, didForcedReopen, requestId)
    end)
  end
  return false
end

local function ExecuteSocketAction(action)
  local t = action and action.task
  if not t then return end

  Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
  CloseEngineeringWindowIfOpen()

  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetTargetsForSlot then
    WSGH.UI.Highlight.SetTargetsForSlot(tonumber(t.slotId))
  else
    WSGH.UI.Highlight.SetTarget(tonumber(t.wantGemId), tonumber(t.socketIndex), tonumber(t.slotId))
  end
  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetEnchantTarget then
    WSGH.UI.Highlight.SetEnchantTarget(nil, nil, nil)
  end

  if WSGH.UI.Highlight and WSGH.UI.Highlight.RequestBagRefresh then
    WSGH.UI.Highlight.RequestBagRefresh()
  end
  WSGH.Util.OpenBagsForGuidance()

  local opened = OpenSocketFrame(t.slotId)
  if not opened then
    WSGH.Util.Print("Unable to open socket UI for slot " .. tostring(t.slotId) .. ".")
  end

  -- Refresh highlights now and shortly after to catch UI elements once they appear.
  WSGH.UI.Highlight.Refresh()
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, WSGH.UI.Highlight.Refresh)
    C_Timer.After(0.15, WSGH.UI.Highlight.Refresh)
    C_Timer.After(0.3, WSGH.UI.Highlight.Refresh)
  end
end

local function ExecuteEnchantAction(action)
  local t = action and action.task
  if not t then return end

  CloseSocketFrameIfOpen()

  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetEnchantTarget then
    WSGH.UI.Highlight.SetEnchantTarget(tonumber(t.wantEnchantId), tonumber(t.wantEnchantItemId), tonumber(t.slotId))
  end

  if action.type == "APPLY_TINKER" then
    Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
    local requestId = Guide.tinkerSelectionRequestId
    local opened = OpenEngineeringProfession()
    if not opened then
      WSGH.Util.Print("Unable to open Engineering. Open your profession window and apply the tinker.")
    end
    OpenCharacterFrame()
    TrySelectEngineeringRecipeWithRetry(tonumber(t.wantEnchantId) or 0, 20, false, requestId)
  else
    Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
    CloseEngineeringWindowIfOpen()
    if WSGH.UI.Highlight and WSGH.UI.Highlight.RequestEnchantBagRefresh then
      WSGH.UI.Highlight.RequestEnchantBagRefresh()
    end
    WSGH.Util.OpenBagsForGuidance()
    OpenCharacterFrame()
  end

  WSGH.UI.Highlight.Refresh()
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, WSGH.UI.Highlight.Refresh)
    C_Timer.After(0.15, WSGH.UI.Highlight.Refresh)
    C_Timer.After(0.3, WSGH.UI.Highlight.Refresh)
  end
end

local function ExecuteSocketHintAction(rowData)
  if not rowData then return end
  Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
  CloseSocketFrameIfOpen()
  local slotId = tonumber(rowData.slotId) or 0
  local itemId = tonumber(rowData.socketHintItemId) or 0
  local extraItemId = tonumber(rowData.socketHintExtraItemId) or 0

  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetTarget then
    WSGH.UI.Highlight.SetTarget(nil, nil)
  end
  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetEnchantTarget then
    WSGH.UI.Highlight.SetEnchantTarget(nil, nil, nil)
  end
  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetSocketHintTarget then
    WSGH.UI.Highlight.SetSocketHintTarget(itemId, slotId, extraItemId)
  end

  WSGH.Util.OpenBagsForGuidance()
  OpenCharacterFrame()

  if WSGH.UI.Highlight and WSGH.UI.Highlight.RequestBagRefresh then
    WSGH.UI.Highlight.RequestBagRefresh()
  end

  if itemId == 0 and extraItemId == 0 then
    WSGH.Util.Print(rowData.socketHintText or "Add missing socket.")
  end
end

local function ExecuteAction(action, rowData)
  if not action then return end
  if action.type == "SOCKET_GEM" then
    if action.task and action.task.status == WSGH.Const.STATUS_MISSING then
      WSGH.Util.Print(("Missing required gem (%d) for %s."):format(action.task.wantGemId, rowData and rowData.slotKey or "slot"))
    end
    Guide.currentAction = action
    ExecuteSocketAction(action)
  elseif action.type == "APPLY_ENCHANT" or action.type == "APPLY_TINKER" then
    if action.task and action.task.status == WSGH.Const.STATUS_MISSING then
      WSGH.Util.Print(("Missing required enchant item (%d) for %s."):format(
        action.task.wantEnchantItemId or 0,
        rowData and rowData.slotKey or "slot"
      ))
    end
    Guide.currentAction = action
    ExecuteEnchantAction(action)
  end
end

function Guide.StartForRow(rowData)
  if InCombatLockdown and InCombatLockdown() then
    WSGH.Util.Print("Cannot start guidance during combat; try again after combat.")
    return
  end

  local action = DetermineNextAction(rowData)
  if not action then
    WSGH.Util.Print("No pending actions for " .. (rowData and rowData.slotKey or "slot") .. ".")
    return
  end

  ExecuteAction(action, rowData)
end

function Guide.OnStateUpdated()
  local action = Guide.currentAction
  if not action then return end

  if action.type == "SOCKET_GEM" then
    if IsSocketTaskResolved(action.task) then
      Guide.currentAction = nil
      local socketingOpen = ItemSocketingFrame and ItemSocketingFrame:IsShown()
      if socketingOpen then
        if WSGH.UI.Highlight and WSGH.UI.Highlight.SetTargetsForSlot then
          WSGH.UI.Highlight.SetTargetsForSlot(action.task.slotId)
        elseif WSGH.UI.Highlight and WSGH.UI.Highlight.Refresh then
          WSGH.UI.Highlight.Refresh()
        end
        return
      end
      local row = GetRowBySlotId(action.task.slotId)
      local nextAction = DetermineNextAction(row)
      if nextAction then
        ExecuteAction(nextAction, row)
      else
        WSGH.UI.Highlight.UpdateFromState()
      end
    end
  elseif action.type == "APPLY_ENCHANT" or action.type == "APPLY_TINKER" then
    if IsEnchantTaskResolved(action.task) then
      Guide.currentAction = nil
      local row = GetRowBySlotId(action.task.slotId)
      local nextAction = DetermineNextAction(row)
      if nextAction then
        ExecuteAction(nextAction, row)
      else
        WSGH.UI.Highlight.UpdateFromState()
      end
    end
  end
end

function WSGH.Debug.TestSocket(slotId, socketIndex, gemId)
  slotId = tonumber(slotId) or 0
  socketIndex = tonumber(socketIndex) or 1
  gemId = tonumber(gemId) or 0
  if slotId == 0 or gemId == 0 then
    WSGH.Util.Print("Debug: provide slotId, socketIndex, gemId (e.g. TestSocket(3,1,76670)).")
    return
  end

  WSGH.Util.Print(("Debug: slot %d socket %d gem %d"):format(slotId, socketIndex, gemId))
  WSGH.UI.Highlight.SetTarget(gemId, socketIndex, slotId)

  if not ItemSocketingFrame and LoadAddOn then
    pcall(LoadAddOn, "Blizzard_ItemSocketingUI")
  end

  if SocketInventoryItem then
    pcall(SocketInventoryItem, slotId)
  end

  WSGH.UI.Highlight.Refresh()
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, WSGH.UI.Highlight.Refresh)
    C_Timer.After(0.15, WSGH.UI.Highlight.Refresh)
    C_Timer.After(0.3, WSGH.UI.Highlight.Refresh)
  end

  local btn = _G["ItemSocketingSocket" .. socketIndex]
  if btn then
    local shown = btn:IsShown() and "shown" or "hidden"
    WSGH.Util.Print("Socket button exists (" .. shown .. ").")
  else
    WSGH.Util.Print("Socket button not found.")
  end
end

local function LayoutRows()
  if not WSGH.UI.frame or not WSGH.UI.rows then return end

  local frame = WSGH.UI.frame
  local rowHeight = WSGH.UI.rowHeight
  local listTop = WSGH.UI.listTop
  local rowRightPad = WSGH.UI.rowRightPad or 18
  local availableHeight = frame:GetHeight() - math.abs(listTop) - 18
  local desired = math.max(1, math.floor(availableHeight / rowHeight))
  desired = math.min(desired, #WSGH.Const.SLOT_ORDER)

  if desired > #WSGH.UI.rows then
    for i = #WSGH.UI.rows + 1, desired do
      local row = WSGH.UI.Rows.Create(frame)
      WSGH.UI.rows[i] = row
    end
  end

  for i, row in ipairs(WSGH.UI.rows) do
    local yOffset = listTop - ((i - 1) * rowHeight)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 18, yOffset)
    row:SetPoint("TOPRIGHT", -rowRightPad, yOffset)
    if i <= desired then
      row:Show()
    else
      row:Hide()
    end
  end

  WSGH.UI.visibleRows = desired
end

local function UpdateShoppingList()
  WSGH.UI.Shopping.UpdateShoppingList()
end

local function HasEquippedSnapshotChanged()
  local diff = WSGH.State and WSGH.State.diff
  if not (diff and diff.rows) then return false end

  for _, row in ipairs(diff.rows) do
    local slotId = tonumber(row.slotId) or 0
    if slotId ~= 0 then
      local currentLink = GetInventoryItemLink("player", slotId)
      local previousLink = row.equippedLink
      if tostring(currentLink or "") ~= tostring(previousLink or "") then
        return true
      end
    end
  end

  return false
end

local function HasUpgradeSnapshotChanged()
  local diff = WSGH.State and WSGH.State.diff
  if not (diff and diff.rows) then return false end
  if not (WSGH.Scan and WSGH.Scan.Tooltip and WSGH.Scan.Tooltip.GetInventoryItemInfo) then
    return false
  end

  for _, row in ipairs(diff.rows) do
    local slotId = tonumber(row.slotId) or 0
    if slotId ~= 0 then
      local tooltipInfo = WSGH.Scan.Tooltip.GetInventoryItemInfo("player", slotId) or nil
      local liveLevel = tooltipInfo and tonumber(tooltipInfo.upgradeLevel) or 0
      local liveMax = tooltipInfo and tonumber(tooltipInfo.upgradeMax) or 0
      local rowLevel = tonumber(row.equippedUpgradeLevel) or 0
      local rowMax = tonumber(row.equippedUpgradeMax) or 0
      if liveLevel ~= rowLevel or liveMax ~= rowMax then
        return true
      end
    end
  end

  return false
end

local function ShowItemTooltip(frame, itemId)
  if not itemId or itemId == 0 then return end
  GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
  if type(itemId) == "string" then
    GameTooltip:SetHyperlink(itemId)
  else
    GameTooltip:SetItemByID(itemId)
  end
  GameTooltip:Show()
end

local BuildPlanFromEquipped
local BuildFromEquippedAndRender
local TryLoadSavedImport = function() end
local RegisterUIEvents
local UnregisterUIEvents
local function IsAuctionHouseOpen()
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then return true end
  if AuctionFrame and AuctionFrame:IsShown() then return true end
  return false
end

local function SearchAuctionHouseById(itemId)
  return WSGH.UI.Shopping.SearchAuctionHouseById(itemId)
end
WSGH.UI.IsAuctionHouseOpen = IsAuctionHouseOpen

local function BuildDiffAndRender()
  EnsureUIState()

  if not WSGH.State.plan then
    WSGH.Util.Print("No plan imported.")
    return
  end

  local diff, err = WSGH.Diff.Build(WSGH.State.plan)
  if not diff then
    WSGH.Util.Print("Diff failed: " .. tostring(err))
    return
  end

  WSGH.State.diff = diff
  WSGH.UI.Render()
end

function WSGH.UI.RebuildAndRefresh()
  BuildDiffAndRender()
  WSGH.UI.Highlight.UpdateFromState()
  WSGH.UI.Highlight.Refresh()
end
BuildPlanFromEquipped = function()
  local equipped = WSGH.Scan.Equipped.GetState()
  local plan = { slots = {} }

  for _, slotMeta in ipairs(WSGH.Const.SLOT_ORDER) do
    local eq = equipped[slotMeta.slotId] or {}
    local expectedGems = {}
    for socketIndex, gemId in pairs(eq.gemsByIndex or {}) do
      expectedGems[socketIndex] = gemId
    end

    plan.slots[slotMeta.slotId] = {
      slotId = slotMeta.slotId,
      slotKey = slotMeta.key,
      expectedItemId = eq.itemId or 0,
      expectedGemsByIndex = expectedGems,
      socketCount = eq.socketCount or 0,
    }
  end

  return plan, equipped
end

BuildFromEquippedAndRender = function()
  EnsureUIState()

  local plan, equipped = BuildPlanFromEquipped()
  WSGH.State.plan = plan

  local diff, err = WSGH.Diff.Build(plan)
  if not diff then
    WSGH.Util.Print("Diff failed: " .. tostring(err))
    return
  end

  WSGH.State.diff = diff
  WSGH.UI.Render()
end

function TryLoadSavedImport()
  local preferences = WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
  if not preferences or not preferences.persistImports then return end
  if WSGH.State.plan then return end

  local savedText = preferences.savedImportText
  if not savedText or savedText == "" then return end

  local plan, err = WSGH.Import.FromJson(savedText)
  if not plan then
    WSGH.Util.Print("Saved import invalid: " .. tostring(err))
    return
  end

  if WSGH.UI.ResetRuntimeState then
    WSGH.UI.ResetRuntimeState()
  end

  WSGH.State.plan = plan
  local diff, derr = WSGH.Diff.Build(plan)
  if diff then
    WSGH.State.diff = diff
  else
    WSGH.Util.Print("Saved import diff failed: " .. tostring(derr))
  end
end

local function OnEquipmentOrBagsChanged()
  if not (WSGH.UI.frame and WSGH.UI.frame:IsShown()) then return end
  if WSGH.State.plan then
    BuildDiffAndRender()
  else
    BuildFromEquippedAndRender()
  end
end

local function OnEventDispatch(_, event, ...)
  if event == "PLAYER_REGEN_DISABLED" then
    CloseUIForCombat()
    return
  end

  local uiVisible = WSGH.UI.frame and WSGH.UI.frame:IsShown()

  if event == "UNIT_INVENTORY_CHANGED" then
    local unit = ...
    if unit ~= "player" then return end
    OnEquipmentOrBagsChanged()
    if uiVisible then
      WSGH.UI.Highlight.UpdateFromState()
      WSGH.UI.Highlight.Refresh()
      if Guide.OnStateUpdated then Guide.OnStateUpdated() end
    end
  elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
    OnEquipmentOrBagsChanged()
    if uiVisible then
      WSGH.UI.Highlight.UpdateFromState()
      WSGH.UI.Highlight.Refresh()
      if Guide.OnStateUpdated then Guide.OnStateUpdated() end
    end
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    if uiVisible and ItemUpgradeFrame and ItemUpgradeFrame:IsShown() then
      return
    end
    if uiVisible and WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateShoppingList then
      WSGH.UI.Shopping.UpdateShoppingList()
    end
  elseif event == "SOCKET_INFO_UPDATE" then
    if WSGH.State.plan then
      BuildDiffAndRender()
      if uiVisible then
        WSGH.UI.Highlight.UpdateFromState()
      end
    end
    if uiVisible then
      WSGH.UI.Highlight.Refresh()
      -- Also refresh indicators after user presses Apply or changes socket contents.
      if WSGH.UI.Highlight.Refresh then WSGH.UI.Highlight.Refresh() end
      if Guide.OnStateUpdated then Guide.OnStateUpdated() end
    end
  end
end

RegisterUIEvents = function()
  if not WSGH.UI.eventFrame then return end
  WSGH.UI.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  WSGH.UI.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
  WSGH.UI.eventFrame:RegisterEvent("SOCKET_INFO_UPDATE")
  WSGH.UI.eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
  WSGH.UI.eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
  WSGH.UI.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
  WSGH.UI.eventFrame:SetScript("OnEvent", OnEventDispatch)
end

UnregisterUIEvents = function()
  if not WSGH.UI.eventFrame then return end
  WSGH.UI.eventFrame:UnregisterAllEvents()
end

local function EquipExpectedItem(rowData)
  if not rowData then return end
  local targetSlot = tonumber(rowData.slotId) or nil
  local locations = rowData.bagLocations
  if not locations or #locations == 0 then
    WSGH.Util.Print("Expected item not in bags.")
    return
  end

  for _, loc in ipairs(locations) do
    if loc and loc.bag ~= nil and loc.slot ~= nil then
      local equipped = false
      if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(loc.bag, loc.slot)
        if CursorHasItem() and targetSlot and EquipCursorItem then
          EquipCursorItem(targetSlot)
          equipped = true
        elseif C_Container.UseContainerItem then
          C_Container.UseContainerItem(loc.bag, loc.slot)
          equipped = true
        end
      elseif PickupContainerItem then
        PickupContainerItem(loc.bag, loc.slot)
        if CursorHasItem() and targetSlot and EquipCursorItem then
          EquipCursorItem(targetSlot)
          equipped = true
        elseif UseContainerItem then
          UseContainerItem(loc.bag, loc.slot)
          equipped = true
        end
      end

      if not equipped then
        WSGH.Util.Print("Unable to equip automatically on this client.")
        return
      end
      local expectedName = GetItemInfo(rowData.expectedItemId or 0)
      WSGH.Util.Print(("Equipping %s"):format(expectedName or ("item " .. tostring(rowData.expectedItemId))))
      BuildDiffAndRender()
      return
    end
  end

  WSGH.Util.Print("Expected item not in bags.")
end

local function TryInsertEquippedItemIntoItemUpgradeFrame(slotId)
  slotId = tonumber(slotId) or 0
  if slotId == 0 then return false end
  if not (ItemUpgradeFrame and ItemUpgradeFrame:IsShown()) then
    return false
  end
  if not (PickupInventoryItem and ItemUpgradeFrame.ItemButton and ItemUpgradeFrame.ItemButton.Click) then
    return false
  end

  if ClearCursor then
    pcall(ClearCursor)
  end
  pcall(PickupInventoryItem, slotId)

  if CursorHasItem and not CursorHasItem() then
    return false
  end

  pcall(ItemUpgradeFrame.ItemButton.Click, ItemUpgradeFrame.ItemButton)
  local consumed = not (CursorHasItem and CursorHasItem())
  if not consumed and ClearCursor then
    pcall(ClearCursor)
  end
  return consumed
end

local function OnRowAction(rowData)
  if not rowData then return end
  if rowData.rowStatus == "WRONG_ITEM" then
    EquipExpectedItem(rowData)
    return
  end
  if rowData.socketHintText then
    if InCombatLockdown and InCombatLockdown() then
      WSGH.Util.Print("Cannot start guidance during combat; try again after combat.")
      return
    end
    ExecuteSocketHintAction(rowData)
    return
  end
  local priority = WSGH.UI.GetRowActionPriority(rowData)
  if priority.hasUpgradeWork and not priority.hasSocketWork and not priority.hasEnchantWork then
    local itemName = GetItemInfo(rowData.expectedItemId or 0) or rowData.slotKey or "item"
    local current = tonumber(rowData.equippedUpgradeLevel) or 0
    local target = tonumber(rowData.expectedUpgradeStep) or 0
    local maxStep = tonumber(rowData.equippedUpgradeMax) or 0
    if maxStep <= 0 then
      maxStep = math.max(2, target)
    end
    if target > maxStep then
      target = maxStep
    end
    local inserted = TryInsertEquippedItemIntoItemUpgradeFrame(rowData.slotId)
    if inserted then
      WSGH.Util.Print(("Inserted %s into the upgrader (%d/%d -> %d/%d)."):format(
        tostring(itemName),
        current,
        maxStep,
        target,
        maxStep
      ))
      return
    end
    WSGH.Util.Print(("Upgrade needed for %s: %d/%d -> %d/%d. Visit the Item Upgrader NPC."):format(
      tostring(itemName),
      current,
      maxStep,
      target,
      maxStep
    ))
    return
  end
  Guide.StartForRow(rowData)
end

local function EnsureImportDialog()
  WSGH.UI.EnsureImportDialog()
end

local function ImportFromDialog()
  EnsureUIState()
  WSGH.UI.ImportFromDialog()
end

function WSGH.UI.OpenSettings()
  if WSGH.UI.Settings and WSGH.UI.Settings.Open then
    WSGH.UI.Settings.Open()
  end
end

function WSGH.UI.Init()
  if WSGH.UI.frame then return end
  EnsureUIState()
  TryLoadSavedImport()

  local sidebarWidth = WSGH.Const.UI.shopping.sidebarWidth
  local rowHeight = WSGH.Const.UI.rowHeight + 6
  local listTop = WSGH.Const.UI.listTop
  local rowRightPad = WSGH.Const.UI.rowRightPad
  local maxHeight = math.abs(listTop) + 18 + (#WSGH.Const.SLOT_ORDER * rowHeight) + 24
  local frameWidth = WSGH.Const.UI.width

  local mainFrame = CreateFrame("Frame", "WowSimsGearHelperFrame", UIParent, "BackdropTemplate")
  mainFrame:SetSize(frameWidth, maxHeight)
  mainFrame:SetClampedToScreen(true)
  mainFrame:SetFrameStrata("DIALOG")
  mainFrame:SetToplevel(true)
  mainFrame:SetMovable(true)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
  end)
  mainFrame:HookScript("OnHide", function()
    if WSGH.UI.Highlight and WSGH.UI.Highlight.ClearAll then
      WSGH.UI.Highlight.ClearAll()
    end
  end)
  
  table.insert(UISpecialFrames, "WowSimsGearHelperFrame")

  mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })

  RestorePosition(mainFrame)

  local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("WowSims Gear Helper")

  local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -5, -5)

  local importBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  importBtn:SetSize(90, 22)
  importBtn:SetPoint("TOPLEFT", 18, -44)
  importBtn:SetText("Import")
  importBtn:SetScript("OnClick", function()
    EnsureImportDialog()
    WSGH.UI.importDialog:Show()
    WSGH.UI.importEditBox:SetFocus()
  end)

  local settingsBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  settingsBtn:SetSize(90, 22)
  settingsBtn:SetPoint("LEFT", importBtn, "RIGHT", 10, 0)
  settingsBtn:SetText("Settings")
  settingsBtn:SetScript("OnClick", function()
    if WSGH.UI.OpenSettings then WSGH.UI.OpenSettings() end
  end)

  local summary = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  summary:SetPoint("LEFT", settingsBtn, "RIGHT", 10, 0)
  summary:SetText("No plan imported")

  local listLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listLabel:SetPoint("TOPLEFT", 18, -78)
  listLabel:SetText("Equipped slots")

  local scroll = CreateFrame("ScrollFrame", "WowSimsGearHelperScroll", mainFrame, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 18, listTop)
  scroll:SetPoint("BOTTOMRIGHT", -rowRightPad, 18)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    EnsureUIState()
    local totalRows = #(WSGH.State.diff and WSGH.State.diff.rows or {})
    local maxOffset = math.max(0, totalRows - WSGH.UI.visibleRows)
    local cur = FauxScrollFrame_GetOffset(self) or 0
    local nextOffset = math.min(maxOffset, math.max(0, cur - delta))

    FauxScrollFrame_SetOffset(self, nextOffset)
    self.ScrollBar:SetValue(nextOffset * WSGH.UI.rowHeight)
    WSGH.UI.Render()
  end)


  local rows = {}

  local function OnScroll()
    WSGH.UI.Render()
  end

  scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, OnScroll)
  end)

  if scroll.ScrollBar then
    scroll.ScrollBar:ClearAllPoints()
    scroll.ScrollBar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 12, -16)
    scroll.ScrollBar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 12, 16)
  end

  mainFrame:SetResizable(true)
  mainFrame:SetResizeBounds(frameWidth, 260, frameWidth, maxHeight)

  local sidebar = CreateFrame("Frame", "WowSimsGearHelperShopping", mainFrame, "BackdropTemplate")
  sidebar:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 8, 0)
  sidebar:SetHeight(200)
  sidebar:SetWidth(sidebarWidth)
  sidebar:SetFrameStrata("DIALOG")
  sidebar:SetToplevel(true)
  sidebar:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  sidebar:SetBackdropColor(unpack(WSGH.Const.UI.shopping.backdropColor))
  sidebar:SetBackdropBorderColor(unpack(WSGH.Const.UI.shopping.borderColor))

  local sidebarTitle = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sidebarTitle:SetPoint("TOPLEFT", 14, -14)
  sidebarTitle:SetText("Shopping List")

  local shoppingEmpty = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  shoppingEmpty:SetPoint("TOPLEFT", sidebarTitle, "BOTTOMLEFT", 0, -8)
  shoppingEmpty:SetText("No missing items")

  local shoppingScroll = CreateFrame("ScrollFrame", "WowSimsGearHelperShoppingScroll", sidebar, "FauxScrollFrameTemplate")
  shoppingScroll:SetPoint("TOPLEFT", sidebarTitle, "BOTTOMLEFT", 0, -8)
  shoppingScroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -24, 10)
  shoppingScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, entryHeight, UpdateShoppingList)
  end)

  local shoppingEntries = {}
  local entryHeight = WSGH.Const.UI.shopping.entryHeight
  local shoppingMaxEntries = 20
  for i = 1, shoppingMaxEntries do
    local entry = CreateFrame("Frame", nil, sidebar)
    entry:SetSize(sidebar:GetWidth() - 24, entryHeight)
    entry:SetPoint("TOPLEFT", shoppingScroll, "TOPLEFT", 0, -((i - 1) * entryHeight))

    entry.icon = entry:CreateTexture(nil, "ARTWORK")
    entry.icon:SetSize(16, 16)
    entry.icon:SetPoint("LEFT", 0, 0)
    entry.icon:SetScript("OnEnter", function(self)
      if self.itemId then ShowItemTooltip(self, self.itemId) end
    end)
    entry.icon:SetScript("OnLeave", GameTooltip_Hide)

    entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.text:SetPoint("LEFT", entry.icon, "RIGHT", 6, 0)
    entry.text:SetJustifyH("LEFT")
    entry.text:SetWordWrap(false)

    entry.strike = entry:CreateTexture(nil, "OVERLAY", nil, 7)
    entry.strike:SetTexture("Interface\\Buttons\\WHITE8x8")
    entry.strike:SetHeight(2)
    entry.strike:SetVertexColor(1, 1, 1, 1)
    entry.strike:SetPoint("LEFT", entry.text, "LEFT", 0, 0)
    entry.strike:SetPoint("RIGHT", entry.text, "RIGHT", 0, 0)
    entry.strike:SetPoint("CENTER", entry.text, "CENTER", 0, 0)
    entry.strike:Hide()

    entry.search = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
    entry.search:SetSize(WSGH.Const.UI.shopping.searchButton.width, WSGH.Const.UI.shopping.searchButton.height)
    entry.search:SetPoint("RIGHT", entry, "RIGHT", -4, 0)
    entry.search:SetText("X")
    entry.search:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local itemName = self.itemId and GetItemInfo(self.itemId)
    GameTooltip:SetText("Search Auction House")
    GameTooltip:AddLine(itemName or "Search this item in the Auction House.", 1, 1, 1, true)
    GameTooltip:Show()
    end)
    entry.search:SetScript("OnLeave", GameTooltip_Hide)
    entry.search:SetScript("OnClick", function(self)
      if not self.itemId then return end
      local ok = SearchAuctionHouseById(self.itemId)
      if not ok then
        WSGH.Util.Print("Open the Auction House and try again.")
      end
    end)

    entry.count = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    entry.count:SetPoint("RIGHT", entry.search, "LEFT", -6, 0)
    entry.count:SetJustifyH("RIGHT")

    entry.countIcon = CreateFrame("Button", nil, entry)
    entry.countIcon:SetSize(14, 14)
    entry.countIcon:SetPoint("RIGHT", entry.search, "LEFT", -6, 0)
    entry.countIcon.texture = entry.countIcon:CreateTexture(nil, "ARTWORK")
    entry.countIcon.texture:SetAllPoints()
    entry.countIcon:Hide()

    entry.text:SetPoint("RIGHT", entry.count, "LEFT", -8, 0)
    entry:SetScript("OnEnter", function(self)
      if self.itemId then ShowItemTooltip(self, self.itemId) end
    end)
    entry:SetScript("OnLeave", GameTooltip_Hide)

    entry:Hide()
    shoppingEntries[i] = entry
  end

  local resizer = CreateFrame("Button", nil, mainFrame)
  resizer:SetSize(16, 16)
  resizer:SetPoint("BOTTOMRIGHT", -4, 4)
  resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  resizer:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      self:GetParent():StartSizing("BOTTOMRIGHT")
    end
  end)
  resizer:SetScript("OnMouseUp", function(self)
    local parentFrame = self:GetParent()
    parentFrame:StopMovingOrSizing()
    SavePosition(parentFrame)
    LayoutRows()
    WSGH.UI.Render()
  end)

  mainFrame:SetScript("OnSizeChanged", function()
    LayoutRows()
    WSGH.UI.Render()
  end)

  WSGH.UI.frame = mainFrame
  WSGH.UI.title = title
  WSGH.UI.summary = summary
  WSGH.UI.scroll = scroll
  WSGH.UI.rows = rows
  WSGH.UI.rowHeight = rowHeight
  WSGH.UI.visibleRows = 1
  WSGH.UI.listTop = listTop
  WSGH.UI.rowRightPad = rowRightPad
  WSGH.UI.shoppingFrame = sidebar
  WSGH.UI.shoppingTitle = sidebarTitle
  WSGH.UI.shoppingScroll = shoppingScroll
  WSGH.UI.shoppingEntries = shoppingEntries
  WSGH.UI.shoppingEmpty = shoppingEmpty
  WSGH.UI.maxHeight = maxHeight
  WSGH.UI.eventFrame = CreateFrame("Frame")
  WSGH.UI.eventFrame:SetFrameStrata("DIALOG")
  WSGH.UI.eventFrame:SetScript("OnEvent", OnEventDispatch)
  WSGH.UI.eventFrame.pollElapsed = 0
  WSGH.UI.eventFrame:SetScript("OnUpdate", function(self, elapsed)
    self.pollElapsed = (tonumber(self.pollElapsed) or 0) + (tonumber(elapsed) or 0)
    if self.pollElapsed < 1.0 then return end
    self.pollElapsed = 0

    if not (WSGH.UI.frame and WSGH.UI.frame:IsShown()) then return end
    if not WSGH.State or not WSGH.State.plan then return end

    -- Some item changes (notably upgrades) may not fire equipment/bag events on all clients.
    -- Poll for equipped-link and tooltip-upgrade changes while UI is open.
    if HasEquippedSnapshotChanged() or HasUpgradeSnapshotChanged() then
      BuildDiffAndRender()
      if Guide.OnStateUpdated then Guide.OnStateUpdated() end
    end
  end)

  if WSGH.UI.Highlight and WSGH.UI.Highlight.InitializeHooks then
    WSGH.UI.Highlight.InitializeHooks()
  end

  LayoutRows()
end

function WSGH.UI.Render()
  EnsureUIState()

  local diff = WSGH.State.diff
  if not diff or not diff.rows then
    if WSGH.UI.summary then
      WSGH.UI.summary:SetText(WSGH.State.plan and "Imported, no diff yet" or "No plan imported")
    end
    UpdateShoppingList()
    return
  end

  WSGH.UI.summary:SetText(("Tasks: %d"):format(diff.taskCount or 0))

  local total = #diff.rows
  FauxScrollFrame_Update(WSGH.UI.scroll, total, WSGH.UI.visibleRows, WSGH.UI.rowHeight)

  local offset = FauxScrollFrame_GetOffset(WSGH.UI.scroll) or 0
  local maxOffset = math.max(0, total - WSGH.UI.visibleRows)
  if offset > maxOffset then
    offset = maxOffset
    FauxScrollFrame_SetOffset(WSGH.UI.scroll, offset)
    if WSGH.UI.scroll and WSGH.UI.scroll.ScrollBar then
      WSGH.UI.scroll.ScrollBar:SetValue(offset * WSGH.UI.rowHeight)
    end
  end

  for i = 1, WSGH.UI.visibleRows do
    local index = offset + i
    local rowFrame = WSGH.UI.rows[i]
    local rowData = diff.rows[index]

    if rowData then
      rowFrame:Show()
      WSGH.UI.Rows.SetRow(rowFrame, rowData, OnRowAction)
  else
    rowFrame:Hide()
  end
end

  WSGH.UI.Highlight.UpdateFromState()
  WSGH.UI.Highlight.Refresh()
  UpdateShoppingList()
end

function WSGH.UI.Show()
  if not WSGH.UI.frame then return end
  if InCombatLockdown and InCombatLockdown() then
    WSGH.Util.Print("Cannot open during combat; try /wsgh after you leave combat.")
    return
  end
  EnsureUIState()
  TryLoadSavedImport()
  if not WSGH.State.plan then
    BuildFromEquippedAndRender()
  else
    -- Always rebuild diff on show to ensure state matches current equipment/sockets.
    BuildDiffAndRender()
  end
  RegisterUIEvents()
  WSGH.UI.frame:Show()
  WSGH.DB.profile.ui.shown = true
  if WSGH.UI.Highlight and WSGH.UI.Highlight.PrimeBags then
    WSGH.UI.Highlight.PrimeBags()
  end
end

function WSGH.UI.Hide()
  if not WSGH.UI.frame then return end
  Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
  UnregisterUIEvents()
  WSGH.UI.frame:Hide()
  WSGH.DB.profile.ui.shown = false
  WSGH.UI.Highlight.SetTarget(nil, nil)
  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetEnchantTarget then
    WSGH.UI.Highlight.SetEnchantTarget(nil, nil, nil)
  end
end

function WSGH.UI.Toggle()
  if not WSGH.UI.frame then return end
  if WSGH.UI.frame:IsShown() then
    WSGH.UI.Hide()
  else
    WSGH.UI.Show()
  end
end

function WSGH.UI.ResetPosition()
  if not WSGH.UI.frame then return end
  WSGH.UI.frame:ClearAllPoints()
  WSGH.UI.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  if WSGH.UI.maxHeight then
    WSGH.UI.frame:SetHeight(WSGH.UI.maxHeight)
  end
  LayoutRows()
  WSGH.UI.Render()

  local ui = WSGH.DB.profile.ui
  ui.point = "CENTER"
  ui.relativePoint = "CENTER"
  ui.x = 0
  ui.y = 0
end

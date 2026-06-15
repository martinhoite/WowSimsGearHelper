local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.UI = WSGH.UI or {}
WSGH.Debug = WSGH.Debug or {}

local function ClearUserPlaced(frame)
  if not (frame and frame.SetUserPlaced) then return end
  local isMovable = frame.IsMovable and frame:IsMovable()
  local isResizable = frame.IsResizable and frame:IsResizable()
  if isMovable or isResizable then
    frame:SetUserPlaced(false)
  end
end

local function SavePosition(frame)
  local ui = WSGH.DB.profile.ui
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  ui.point = point
  ui.relativePoint = relativePoint
  ui.x = x
  ui.y = y
  ClearUserPlaced(frame)
end

local function RestorePosition(frame)
  local ui = WSGH.DB.profile.ui
  frame:ClearAllPoints()
  frame:SetPoint(ui.point, UIParent, ui.relativePoint, ui.x, ui.y)
end

local function ResizeFromTopLeft(frame, resize)
  if not frame then return end
  local left = frame:GetLeft()
  local top = frame:GetTop()

  if resize then resize() end

  if not left or not top then
    SavePosition(frame)
    return
  end

  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  SavePosition(frame)
end

local function IsFrameVisible(frame)
  if not frame then return false end
  if frame.IsVisible then
    return frame:IsVisible()
  end
  return frame:IsShown()
end

local function CloseUIForCombat()
  if not (
    IsFrameVisible(WSGH.UI.frame)
    or IsFrameVisible(WSGH.UI.shoppingFrame)
    or IsFrameVisible(WSGH.UI.shoppingReminder)
    or IsFrameVisible(WSGH.UI.importDialog)
    or IsFrameVisible(WSGH.UI.Help and WSGH.UI.Help.dialog)
  ) then
    return
  end
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

local function ClearHighlights()
  if not WSGH.UI.Highlight then return end
  if WSGH.UI.Highlight.ClearAll then
    WSGH.UI.Highlight.ClearAll()
    return
  end

  if WSGH.UI.Highlight.SetTarget then
    WSGH.UI.Highlight.SetTarget(nil, nil)
  end
  if WSGH.UI.Highlight.SetEnchantTarget then
    WSGH.UI.Highlight.SetEnchantTarget(nil, nil, nil)
  end
  if WSGH.UI.Highlight.SetSocketHintTarget then
    WSGH.UI.Highlight.SetSocketHintTarget(nil, nil, nil)
  end
end

local function ResetRuntimeState()
  EnsureUIState()
  WSGH.State.plan = nil
  WSGH.State.diff = nil
  WSGH.State.lastImportSource = nil
  Guide.currentAction = nil
  Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
  WSGH.UI.pendingPurchases = {}
  WSGH.UI.pendingPurchaseBagCounts = {}
  WSGH.UI.pendingPurchasesByName = {}
  WSGH.UI.reforgeReminder = nil

  ClearHighlights()

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

local function PlanHasReforges(plan)
  if type(plan) ~= "table" then return false end
  if type(plan.meta) == "table" and plan.meta.hasReforges ~= nil then
    return plan.meta.hasReforges == true
  end
  for _, slotPlan in pairs(plan.slots or {}) do
    if (tonumber(slotPlan.expectedReforgeId) or 0) ~= 0 then
      return true
    end
  end
  return false
end

local function RefreshReforgeReminder()
  if WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateReforgeReminder then
    WSGH.UI.Shopping.UpdateReforgeReminder()
  end
end

function WSGH.UI.RefreshWindowBackgrounds()
  if not (WSGH.Util and WSGH.Util.ApplyOpaqueWindowBackground) then return end

  WSGH.Util.ApplyOpaqueWindowBackground(WSGH.UI.frame, "main")
  WSGH.Util.ApplyOpaqueWindowBackground(WSGH.UI.shoppingFrame, "shopping")
  WSGH.Util.ApplyOpaqueWindowBackground(WSGH.UI.shoppingReminder, "shoppingReminder", 3)

  if WSGH.UI.Help and WSGH.UI.Help.dialog then
    WSGH.Util.ApplyOpaqueWindowBackground(WSGH.UI.Help.dialog, "help")
  end

  if WSGH.UI.importDialog then
    WSGH.Util.ApplyOpaqueWindowBackground(WSGH.UI.importDialog, "import")
  end
end

local HasEquippedSnapshotChanged
local HasUpgradeSnapshotChanged
local BuildDiffAndRender
local RegisterUIEvents
local UnregisterUIEvents
local ExecuteUpgradeAction

local function RuntimePollUpdate(self, elapsed)
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
end

local function SetRuntimePollingEnabled(enabled)
  if not WSGH.UI.eventFrame then return end
  if enabled then
    WSGH.UI.eventFrame.pollElapsed = 0
    WSGH.UI.eventFrame:SetScript("OnUpdate", RuntimePollUpdate)
  else
    WSGH.UI.eventFrame.pollElapsed = 0
    WSGH.UI.eventFrame:SetScript("OnUpdate", nil)
  end
end

local function SetAuxiliaryFramesShown(shown)
  if WSGH.UI.shoppingFrame then
    if shown then WSGH.UI.shoppingFrame:Show() else WSGH.UI.shoppingFrame:Hide() end
  end
  if WSGH.UI.shoppingReminder then
    if shown then
      if WSGH.UI.Shopping and WSGH.UI.Shopping.UpdateReforgeReminder then
        WSGH.UI.Shopping.UpdateReforgeReminder()
      end
    else
      WSGH.UI.shoppingReminder:Hide()
    end
  end
  if not shown then
    if WSGH.UI.importDialog then WSGH.UI.importDialog:Hide() end
    if WSGH.UI.Help and WSGH.UI.Help.dialog then WSGH.UI.Help.dialog:Hide() end
  end
end

local function ConfigureReforgeReminderForPlan(plan, source)
  local preferences = WSGH.Util.GetPreferences and WSGH.Util.GetPreferences() or nil
  local hasReforges = PlanHasReforges(plan)
  local shouldShow = false
  local hasReforgeLite = WSGH.Integrations
    and WSGH.Integrations.ReforgeLite
    and WSGH.Integrations.ReforgeLite.IsAvailable
    and WSGH.Integrations.ReforgeLite.IsAvailable()

  if hasReforges and not hasReforgeLite and preferences then
    if source == "manual" then
      shouldShow = preferences.showReforgeReminderAfterImport ~= false
    elseif source == "restore" then
      shouldShow = preferences.persistImports == true and preferences.showReforgeReminderOnRestore == true
    end
  end

  WSGH.UI.reforgeReminder = {
    hasReforges = hasReforges,
    source = source,
    hidden = not shouldShow,
  }
  RefreshReforgeReminder()
end

function WSGH.UI.DismissReforgeReminder()
  if not WSGH.UI.reforgeReminder then return end
  WSGH.UI.reforgeReminder.hidden = true
  RefreshReforgeReminder()
end

local function ApplyImportedPlan(plan, source, rawJson)
  if WSGH.UI.ResetRuntimeState then
    WSGH.UI.ResetRuntimeState()
  end

  WSGH.State = WSGH.State or {}
  WSGH.State.plan = plan
  WSGH.State.lastImportSource = source

  local equipped = WSGH.Scan.Equipped.GetState()
  local diff, err = WSGH.Diff.Build(plan, equipped)
  if not diff then
    return nil, err
  end

  WSGH.State.diff = diff
  ConfigureReforgeReminderForPlan(plan, source)
  if source == "manual"
    and rawJson
    and WSGH.Integrations
    and WSGH.Integrations.ReforgeLite
    and WSGH.Integrations.ReforgeLite.SyncImport then
    local synced, syncErr = WSGH.Integrations.ReforgeLite.SyncImport(rawJson)
    if synced then
      WSGH.Util.Print("Synced import to ReforgeLite.")
      local refreshedDiff = WSGH.Diff.Build(plan, WSGH.Scan.Equipped.GetState())
      if refreshedDiff then
        WSGH.State.diff = refreshedDiff
      end
    elseif syncErr ~= "missing" and syncErr ~= "disabled" and syncErr ~= "empty" then
      WSGH.Util.Print("ReforgeLite sync failed: " .. tostring(syncErr))
    end
  end
  if WSGH.UI.frame and WSGH.UI.rows then
    WSGH.UI.Render()
  end
  return true
end
WSGH.UI.ApplyImportedPlan = ApplyImportedPlan

local function GetTaskPriorityRank(taskType)
  if WSGH.Util and WSGH.Util.GetTaskPriorityRank then
    return WSGH.Util.GetTaskPriorityRank(taskType)
  end

  local order = WSGH.Util and WSGH.Util.NormalizeTaskPriorityOrder and WSGH.Util.NormalizeTaskPriorityOrder(nil) or {}
  for index, key in ipairs(order) do
    if key == taskType then
      return index
    end
  end
  return #order + 1
end

local function AddPendingActionCandidate(candidates, actionType, task, sequence)
  candidates[#candidates + 1] = {
    type = actionType,
    task = task,
    rank = GetTaskPriorityRank(actionType),
    sequence = sequence or (#candidates + 1),
  }
end

local function BuildSocketHintTask(rowData)
  if not (rowData and rowData.socketHintText) then return nil end
  return {
    type = "ADD_SOCKET",
    slotId = rowData.slotId,
    slotKey = rowData.slotKey,
    itemId = rowData.equippedItemId or rowData.expectedItemId,
    status = WSGH.Const.STATUS_WRONG,
    socketHintText = rowData.socketHintText,
    socketHintItemId = rowData.socketHintItemId,
    socketHintExtraItemId = rowData.socketHintExtraItemId,
    socketHintExtraItemCount = rowData.socketHintExtraItemCount,
  }
end

local function FindNextPendingTask(tasks, taskType)
  for _, task in ipairs(tasks or {}) do
    local currentType = task and (task.type or taskType)
    if task and task.status ~= WSGH.Const.STATUS_OK and (not taskType or currentType == taskType) then
      return task
    end
  end
  return nil
end

local function HasPendingTask(tasks, taskType)
  return FindNextPendingTask(tasks, taskType) ~= nil
end

function WSGH.UI.GetNextPriorityAction(rowData)
  if not rowData or rowData.rowStatus ~= "NEEDS_WORK" then return nil end

  local candidates = {}
  local sequence = 0

  local addSocketTask = BuildSocketHintTask(rowData)
  if addSocketTask then
    sequence = sequence + 1
    AddPendingActionCandidate(candidates, "ADD_SOCKET", addSocketTask, sequence)
  end

  local socketTask = FindNextPendingTask(rowData.socketTasks, "SOCKET_GEM")
  if socketTask then
    sequence = sequence + 1
    AddPendingActionCandidate(candidates, "SOCKET_GEM", socketTask, sequence)
  end

  local enchantTask = FindNextPendingTask(rowData.enchantTasks, "APPLY_ENCHANT")
  if enchantTask then
    sequence = sequence + 1
    AddPendingActionCandidate(candidates, "APPLY_ENCHANT", enchantTask, sequence)
  end

  local tinkerTask = FindNextPendingTask(rowData.enchantTasks, "APPLY_TINKER")
  if tinkerTask then
    sequence = sequence + 1
    AddPendingActionCandidate(candidates, "APPLY_TINKER", tinkerTask, sequence)
  end

  local upgradeTask = FindNextPendingTask(rowData.upgradeTasks, "UPGRADE_ITEM")
  if upgradeTask then
    sequence = sequence + 1
    AddPendingActionCandidate(candidates, "UPGRADE_ITEM", upgradeTask, sequence)
  end

  local reforgeTask = FindNextPendingTask(rowData.reforgeTasks, "REFORGE_ITEM")
  if reforgeTask then
    sequence = sequence + 1
    AddPendingActionCandidate(candidates, "REFORGE_ITEM", reforgeTask, sequence)
  end

  table.sort(candidates, function(a, b)
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end
    return a.sequence < b.sequence
  end)

  return candidates[1]
end

function WSGH.UI.GetRowActionPriority(rowData)
  local nextSocketTask = FindNextPendingTask(rowData and rowData.socketTasks or nil, "SOCKET_GEM")
  local nextEnchantTask = FindNextPendingTask(rowData and rowData.enchantTasks or nil, "APPLY_ENCHANT")
    or FindNextPendingTask(rowData and rowData.enchantTasks or nil, "APPLY_TINKER")
  return {
    nextAction = WSGH.UI.GetNextPriorityAction(rowData),
    nextSocketTask = nextSocketTask,
    nextEnchantTask = nextEnchantTask,
    hasAddSocketWork = rowData and rowData.socketHintText ~= nil or false,
    hasSocketWork = nextSocketTask ~= nil,
    hasEnchantWork = HasPendingTask(rowData and rowData.enchantTasks or nil, "APPLY_ENCHANT")
      or HasPendingTask(rowData and rowData.enchantTasks or nil, "APPLY_TINKER"),
    hasUpgradeWork = HasPendingTask(rowData and rowData.upgradeTasks or nil, "UPGRADE_ITEM"),
    hasReforgeWork = HasPendingTask(rowData and rowData.reforgeTasks or nil, "REFORGE_ITEM"),
  }
end

local function DetermineNextAction(rowData)
  return WSGH.UI.GetNextPriorityAction(rowData)
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

local function GetPrimaryProfession(professionDefinition)
  local professionName = nil
  local skillLineId = nil
  professionDefinition = professionDefinition or {}
  local targetSkillLineId = tonumber(professionDefinition.skillLineId) or 0
  if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
    local prof1, prof2 = GetProfessions()
    for _, prof in ipairs({ prof1, prof2 }) do
      if prof then
        local name, _, _, _, _, _, skillLine = GetProfessionInfo(prof)
        if targetSkillLineId ~= 0 and tonumber(skillLine) == targetSkillLineId then
          professionName = name
          skillLineId = tonumber(skillLine)
          break
        end
      end
    end
  end
  return professionName, skillLineId
end

local function IsCurrentTradeSkillProfession(professionDefinition)
  professionDefinition = professionDefinition or {}
  local professionName = GetPrimaryProfession(professionDefinition)
  local targetSkillLineId = tonumber(professionDefinition.skillLineId) or 0
  local namePattern = type(professionDefinition.namePattern) == "string" and professionDefinition.namePattern:lower() or nil

  if TradeSkillFrame and TradeSkillFrame:IsShown() and type(GetTradeSkillLine) == "function" then
    local openName = GetTradeSkillLine()
    if type(openName) == "string" and openName ~= "" then
      if professionName and openName == professionName then
        return true
      end
      local lowered = openName:lower()
      if namePattern and lowered:find(namePattern, 1, true) then
        return true
      end
      return false
    end
  end

  if ProfessionsFrame and ProfessionsFrame:IsShown() and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
    local ok, info = pcall(C_TradeSkillUI.GetTradeSkillLine)
    if ok and type(info) == "table" then
      if targetSkillLineId ~= 0 and tonumber(info.skillLineID) == targetSkillLineId then return true end
      if professionName and info.professionName == professionName then return true end
      if namePattern and type(info.professionName) == "string" and info.professionName:lower():find(namePattern, 1, true) then
        return true
      end
      return false
    end
  end

  return nil
end

local function IsProfessionWindowOpen(professionDefinition)
  local isProfession = IsCurrentTradeSkillProfession(professionDefinition)
  if isProfession ~= nil then
    return isProfession
  end
  if TradeSkillFrame and TradeSkillFrame:IsShown() then return true end
  if ProfessionsFrame and ProfessionsFrame:IsShown() then return true end
  return false
end

local function IsEngineeringWindowOpen()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.ENGINEERING or {}
  return IsProfessionWindowOpen(definition)
end

local function IsBlacksmithingWindowOpen()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.BLACKSMITHING or {}
  return IsProfessionWindowOpen(definition)
end

local function IsEnchantingWindowOpen()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.ENCHANTING or {}
  return IsProfessionWindowOpen(definition)
end

local function OpenProfession(professionDefinition, allowProtectedCast)
  if IsProfessionWindowOpen(professionDefinition) then
    return true
  end

  if allowProtectedCast == nil then
    allowProtectedCast = true
  end

  local professionName, skillLineId = GetPrimaryProfession(professionDefinition)

  if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill and skillLineId then
    pcall(C_TradeSkillUI.OpenTradeSkill, skillLineId)
  end
  if allowProtectedCast and professionName and CastSpellByName and not IsProfessionWindowOpen(professionDefinition) then
    pcall(CastSpellByName, professionName)
  end

  return IsProfessionWindowOpen(professionDefinition)
end

local function OpenEngineeringProfession(allowProtectedCast)
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.ENGINEERING or {}
  return OpenProfession(definition, allowProtectedCast)
end

local function OpenBlacksmithingProfession(allowProtectedCast)
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.BLACKSMITHING or {}
  return OpenProfession(definition, allowProtectedCast)
end

local function OpenEnchantingProfession(allowProtectedCast)
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.ENCHANTING or {}
  return OpenProfession(definition, allowProtectedCast)
end

local function CloseProfessionWindowIfOpen(professionDefinition)
  if not IsProfessionWindowOpen(professionDefinition) then
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

local function CleanupAfterHide()
  local runtimeWasActive = WSGH.UI.runtimeActive == true
  WSGH.UI.runtimeActive = false

  if runtimeWasActive then
    Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
  end

  if UnregisterUIEvents then
    UnregisterUIEvents()
  end
  SetRuntimePollingEnabled(false)
  if WSGH.UI.Shopping and WSGH.UI.Shopping.DisableRuntimeListeners then
    WSGH.UI.Shopping.DisableRuntimeListeners()
  end
  SetAuxiliaryFramesShown(false)
  if WSGH.DB and WSGH.DB.profile and WSGH.DB.profile.ui then
    WSGH.DB.profile.ui.shown = false
  end
  ClearHighlights()
end

local function CloseEngineeringWindowIfOpen()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.ENGINEERING or {}
  CloseProfessionWindowIfOpen(definition)
end

local function CloseBlacksmithingWindowIfOpen()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.BLACKSMITHING or {}
  CloseProfessionWindowIfOpen(definition)
end

local function CloseEnchantingWindowIfOpen()
  local definition = WSGH.Const and WSGH.Const.PROFESSIONS and WSGH.Const.PROFESSIONS.ENCHANTING or {}
  CloseProfessionWindowIfOpen(definition)
end

local function BuildRecipeNameMatchers(recipeNames)
  if type(recipeNames) == "string" then
    recipeNames = { recipeNames }
  end
  if type(recipeNames) ~= "table" then return nil end

  local matchers = { exact = {}, normalized = {} }
  for _, recipeName in ipairs(recipeNames) do
    if type(recipeName) == "string" and recipeName ~= "" then
      matchers.exact[recipeName] = true
      local normalized = WSGH.Util.NormalizeName(recipeName, true)
      if normalized ~= "" then
        matchers.normalized[normalized] = true
      end
    end
  end
  if not next(matchers.exact) and not next(matchers.normalized) then return nil end
  return matchers
end

local function RecipeNameMatches(matchers, recipeName)
  if not matchers or type(recipeName) ~= "string" or recipeName == "" then return false end
  if matchers.exact[recipeName] then return true end
  local normalized = WSGH.Util.NormalizeName(recipeName, true)
  if normalized == "" then return false end
  if matchers.normalized[normalized] == true then return true end
  for target in pairs(matchers.normalized) do
    if normalized:sub(1, #target) == target then
      local suffixText = normalized:sub(#target + 1)
      local suffix = WSGH.Util.Trim(suffixText)
      if suffixText:sub(1, 1) == " " and suffix:match("^%d+$") then
        return true
      end
    end
  end
  return false
end

local function FormatRecipeNamesForMessage(recipeNames)
  if type(recipeNames) == "string" then
    return recipeNames
  end
  if type(recipeNames) ~= "table" then
    return "requested recipe"
  end
  local names = {}
  for _, recipeName in ipairs(recipeNames) do
    if type(recipeName) == "string" and recipeName ~= "" then
      names[#names + 1] = recipeName
    end
  end
  if #names == 0 then
    return "requested recipe"
  end
  return table.concat(names, " / ")
end

local function TrySelectRecipeByNames(recipeNames)
  local matchers = BuildRecipeNameMatchers(recipeNames)
  if not matchers then return false, false, false end

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
    local recipeCount = 0
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
      if skillType ~= "header" then
        recipeCount = recipeCount + 1
        if RecipeNameMatches(matchers, name) then
          candidateIndex = i
          break
        end
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
          return true, true, true
        end
        if selected > 0 then
          local selectedName, selectedType = GetTradeSkillInfo(selected)
          if selectedType ~= "header" and RecipeNameMatches(matchers, selectedName) then
            return true, true, true
          end
        end
        return false, true, true
      end
      return true, true, true
    end

    -- Keep MoP deterministic: if legacy API is present, do not branch into C_TradeSkillUI.
    return false, recipeCount > 0, false
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.SelectRecipe then
    local recipeIds = C_TradeSkillUI.GetAllRecipeIDs() or {}
    local recipeCount = 0
    for _, recipeId in ipairs(recipeIds) do
      local info = C_TradeSkillUI.GetRecipeInfo(recipeId)
      if info and info.name then
        recipeCount = recipeCount + 1
      end
      if info and RecipeNameMatches(matchers, info.name) then
        pcall(C_TradeSkillUI.SelectRecipe, recipeId)
        return true, true, true
      end
    end
    return false, recipeCount > 0, false
  end

  return false, false, false
end

local function IsRecipeSelectedByNames(recipeNames)
  local matchers = BuildRecipeNameMatchers(recipeNames)
  if not matchers then return false end

  if type(GetTradeSkillSelectionIndex) == "function" and type(GetTradeSkillInfo) == "function" then
    local selected = tonumber(GetTradeSkillSelectionIndex()) or 0
    if selected > 0 then
      local selectedName, selectedType = GetTradeSkillInfo(selected)
      if selectedType ~= "header" and RecipeNameMatches(matchers, selectedName) then
        return true
      end
    end
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetSelectedRecipeID and C_TradeSkillUI.GetRecipeInfo then
    local recipeId = tonumber(C_TradeSkillUI.GetSelectedRecipeID()) or 0
    if recipeId ~= 0 then
      local info = C_TradeSkillUI.GetRecipeInfo(recipeId)
      if info and RecipeNameMatches(matchers, info.name) then
        return true
      end
    end
  end

  return false
end

local function TrySelectRecipeWithRetry(recipeNames, attemptsLeft, didForcedReopen, requestId, isWindowOpen, openProfession, closeProfession, options)
  attemptsLeft = tonumber(attemptsLeft) or 0
  if attemptsLeft <= 0 then return false end
  didForcedReopen = didForcedReopen and true or false
  options = options or {}
  requestId = tonumber(requestId) or 0
  if requestId == 0 then return false end
  if requestId ~= (tonumber(Guide.tinkerSelectionRequestId) or 0) then
    return false
  end
  if not isWindowOpen() then
    if C_Timer and C_Timer.After and attemptsLeft > 1 then
      C_Timer.After(0.1, function()
        TrySelectRecipeWithRetry(recipeNames, attemptsLeft - 1, didForcedReopen, requestId, isWindowOpen, openProfession, closeProfession, options)
      end)
    end
    return false
  end

  -- Always attempt selection, then verify the currently selected recipe.
  -- This avoids first-open race conditions and supports re-click re-selection.
  local selectedRecipe, recipeListPopulated, foundRecipe = TrySelectRecipeByNames(recipeNames)
  if IsRecipeSelectedByNames(recipeNames) then
    return true
  end
  if selectedRecipe then
    return true
  end

  if options.failWhenRecipeListPopulated ~= false and recipeListPopulated and not foundRecipe then
    local failureMessage = options.failureMessage
    if type(failureMessage) ~= "string" or failureMessage == "" then
      failureMessage = ("Recipe not learned or unavailable: %s."):format(FormatRecipeNamesForMessage(recipeNames))
    end
    WSGH.Util.Print(failureMessage)
    return false
  end

  -- If selection keeps failing while the frame is open, force one reopen to
  -- reset internal trade-skill state when the non-protected API can do so.
  if options.allowForcedReopen ~= false and not didForcedReopen and attemptsLeft <= 12 then
    closeProfession()
    openProfession(false)
    didForcedReopen = true
  end

  if attemptsLeft <= 1 then
    if type(options.failureMessage) == "string" and options.failureMessage ~= "" then
      WSGH.Util.Print(options.failureMessage)
    end
    return false
  end

  if C_Timer and C_Timer.After and attemptsLeft > 1 then
    C_Timer.After(0.1, function()
      TrySelectRecipeWithRetry(recipeNames, attemptsLeft - 1, didForcedReopen, requestId, isWindowOpen, openProfession, closeProfession, options)
    end)
  end
  return false
end

local function TrySelectEngineeringRecipeWithRetry(tinkerSpellId, attemptsLeft, didForcedReopen, requestId)
  tinkerSpellId = tonumber(tinkerSpellId) or 0
  if tinkerSpellId == 0 then return false end
  local targetName = GetSpellInfo(tinkerSpellId)
  if not targetName or targetName == "" then return false end
  return TrySelectRecipeWithRetry(targetName, attemptsLeft, didForcedReopen, requestId, IsEngineeringWindowOpen, OpenEngineeringProfession, CloseEngineeringWindowIfOpen)
end

local function TrySelectEnchantingRecipeWithRetry(enchantSpellId, attemptsLeft, didForcedReopen, requestId)
  enchantSpellId = tonumber(enchantSpellId) or 0
  if enchantSpellId == 0 then return false end
  local targetName = GetSpellInfo(enchantSpellId)
  if not targetName or targetName == "" then return false end
  return TrySelectRecipeWithRetry(targetName, attemptsLeft, didForcedReopen, requestId, IsEnchantingWindowOpen, OpenEnchantingProfession, CloseEnchantingWindowIfOpen, {
    allowForcedReopen = false,
    failureMessage = ("Enchanting recipe not learned or unavailable: %s."):format(targetName),
  })
end

local function BlacksmithingSocketRecipeNamesForSlot(slotId)
  slotId = tonumber(slotId) or 0
  if slotId == 9 then
    return "Socket Bracer"
  end
  if slotId == 10 then
    return "Socket Gloves"
  end
  return nil
end

local function TrySelectBlacksmithingSocketRecipeWithRetry(slotId, attemptsLeft, didForcedReopen, requestId)
  local recipeNames = BlacksmithingSocketRecipeNamesForSlot(slotId)
  if not recipeNames then return false end
  return TrySelectRecipeWithRetry(recipeNames, attemptsLeft, didForcedReopen, requestId, IsBlacksmithingWindowOpen, OpenBlacksmithingProfession, CloseBlacksmithingWindowIfOpen)
end

local function IsBlacksmithingSocketHint(rowData)
  if not rowData or not rowData.socketHintText then return false end
  local slotId = tonumber(rowData.slotId) or 0
  return slotId == 9 or slotId == 10
end

local function IsSelfEnchantingRingTask(task)
  if not task or task.type ~= "APPLY_ENCHANT" or task.manualOnly ~= true then
    return false
  end
  local slotId = tonumber(task.slotId) or 0
  if slotId ~= 11 and slotId ~= 12 then
    return false
  end
  return WSGH.Util and WSGH.Util.HasEnchanting and WSGH.Util.HasEnchanting() or false
end

local function ClearActionGuidanceHighlights()
  if WSGH.UI and WSGH.UI.Shopping and WSGH.UI.Shopping.ClearJPHighlight then
    WSGH.UI.Shopping.ClearJPHighlight()
  end
  if WSGH.UI.Highlight and WSGH.UI.Highlight.ClearAll then
    WSGH.UI.Highlight.ClearAll()
    return
  end
  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetTarget then
    WSGH.UI.Highlight.SetTarget(nil, nil)
  end
  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetEnchantTarget then
    WSGH.UI.Highlight.SetEnchantTarget(nil, nil, nil)
  end
  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetSocketHintTarget then
    WSGH.UI.Highlight.SetSocketHintTarget(nil, nil, nil)
  end
end

local function ExecuteSocketAction(action)
  local t = action and action.task
  if not t then return end

  ClearActionGuidanceHighlights()

  Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
  CloseEngineeringWindowIfOpen()
  CloseBlacksmithingWindowIfOpen()
  CloseEnchantingWindowIfOpen()

  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetTargetsForSlot then
    WSGH.UI.Highlight.SetTargetsForSlot(tonumber(t.slotId))
  else
    WSGH.UI.Highlight.SetTarget(tonumber(t.wantGemId), tonumber(t.socketIndex), tonumber(t.slotId))
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

  ClearActionGuidanceHighlights()

  CloseSocketFrameIfOpen()

  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetEnchantTarget then
    local highlightItemId = tonumber(t.wantEnchantItemId)
    if action.type == "APPLY_TINKER" then
      -- Tinker guidance is recipe/slot-driven; do not highlight the static kit item in bags.
      highlightItemId = nil
    end
    WSGH.UI.Highlight.SetEnchantTarget(tonumber(t.wantEnchantId), highlightItemId, tonumber(t.slotId))
  end

  if action.type == "APPLY_TINKER" then
    Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
    local requestId = Guide.tinkerSelectionRequestId
    CloseEnchantingWindowIfOpen()
    local opened = OpenEngineeringProfession()
    if not opened then
      WSGH.Util.Print("Unable to open Engineering automatically. Open Engineering and apply the tinker manually.")
    end
    OpenCharacterFrame()
    TrySelectEngineeringRecipeWithRetry(tonumber(t.wantEnchantId) or 0, 20, false, requestId)
  else
    Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
    CloseEngineeringWindowIfOpen()
    CloseBlacksmithingWindowIfOpen()
    local requestId = Guide.tinkerSelectionRequestId
    if IsSelfEnchantingRingTask(t) then
      local opened = OpenEnchantingProfession()
      if not opened then
        WSGH.Util.Print("Unable to open Enchanting automatically. Open Enchanting and apply the ring enchant manually.")
      end
      OpenCharacterFrame()
      TrySelectEnchantingRecipeWithRetry(tonumber(t.wantEnchantId) or 0, 20, false, requestId)
    else
      CloseEnchantingWindowIfOpen()
      if WSGH.UI.Highlight and WSGH.UI.Highlight.RequestEnchantBagRefresh then
        WSGH.UI.Highlight.RequestEnchantBagRefresh()
      end
      WSGH.Util.OpenBagsForGuidance()
      OpenCharacterFrame()
    end
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
  ClearActionGuidanceHighlights()
  Guide.tinkerSelectionRequestId = (tonumber(Guide.tinkerSelectionRequestId) or 0) + 1
  CloseSocketFrameIfOpen()
  local slotId = tonumber(rowData.slotId) or 0
  local itemId = tonumber(rowData.socketHintItemId) or 0
  local extraItemId = tonumber(rowData.socketHintExtraItemId) or 0
  local isBlacksmithingSocket = IsBlacksmithingSocketHint(rowData)
  CloseEnchantingWindowIfOpen()

  if WSGH.UI.Highlight and WSGH.UI.Highlight.SetSocketHintTarget then
    if isBlacksmithingSocket then
      WSGH.UI.Highlight.SetSocketHintTarget(nil, slotId, nil)
    else
      WSGH.UI.Highlight.SetSocketHintTarget(itemId, slotId, extraItemId)
    end
  end

  if isBlacksmithingSocket then
    local opened = OpenBlacksmithingProfession()
    if not opened then
      WSGH.Util.Print("Unable to open Blacksmithing automatically. Open Blacksmithing and apply the socket manually.")
    end
    OpenCharacterFrame()
    TrySelectBlacksmithingSocketRecipeWithRetry(slotId, 20, false, Guide.tinkerSelectionRequestId)
  else
    WSGH.Util.OpenBagsForGuidance()
    OpenCharacterFrame()
  end

  if WSGH.UI.Highlight and WSGH.UI.Highlight.RequestBagRefresh then
    if not isBlacksmithingSocket then
      WSGH.UI.Highlight.RequestBagRefresh()
    end
  end

  if itemId == 0 and extraItemId == 0 then
    WSGH.Util.Print(rowData.socketHintText or "Add missing socket.")
  end
end

local function ExecuteReforgeAction()
  ClearActionGuidanceHighlights()
  CloseSocketFrameIfOpen()
  CloseEngineeringWindowIfOpen()
  CloseBlacksmithingWindowIfOpen()
  CloseEnchantingWindowIfOpen()

  if WSGH.Integrations and WSGH.Integrations.ReforgeLite and WSGH.Integrations.ReforgeLite.OpenOrGuide then
    WSGH.Integrations.ReforgeLite.OpenOrGuide()
    return
  end

  WSGH.Util.Print("Open ReforgeLite and apply the WowSims reforge plan manually.")
end

local function NextActionRequiresDirectClick(action)
  if not action then return false end
  return action.type == "SOCKET_GEM" or action.type == "APPLY_TINKER" or action.type == "REFORGE_ITEM" or IsSelfEnchantingRingTask(action.task)
end

local function PrimeGuidanceForAction(action)
  local t = action and action.task
  if not t then return end

  ClearActionGuidanceHighlights()

  if action.type == "SOCKET_GEM" then
    if WSGH.UI.Highlight and WSGH.UI.Highlight.SetTargetsForSlot then
      WSGH.UI.Highlight.SetTargetsForSlot(tonumber(t.slotId))
    elseif WSGH.UI.Highlight and WSGH.UI.Highlight.SetTarget then
      WSGH.UI.Highlight.SetTarget(tonumber(t.wantGemId), tonumber(t.socketIndex), tonumber(t.slotId))
    end
    if WSGH.UI.Highlight and WSGH.UI.Highlight.RequestBagRefresh then
      WSGH.UI.Highlight.RequestBagRefresh()
    end
    WSGH.Util.Print("Next step requires another click to open the socket UI.")
    return
  end

  if action.type == "APPLY_ENCHANT" or action.type == "APPLY_TINKER" then
    local isSelfEnchantingRing = IsSelfEnchantingRingTask(t)
    if WSGH.UI.Highlight and WSGH.UI.Highlight.SetEnchantTarget then
      local highlightItemId = tonumber(t.wantEnchantItemId)
      if action.type == "APPLY_TINKER" then
        highlightItemId = nil
      end
      WSGH.UI.Highlight.SetEnchantTarget(tonumber(t.wantEnchantId), highlightItemId, tonumber(t.slotId))
    end
    if action.type == "APPLY_ENCHANT" and not isSelfEnchantingRing and WSGH.UI.Highlight and WSGH.UI.Highlight.RequestEnchantBagRefresh then
      WSGH.UI.Highlight.RequestEnchantBagRefresh()
    end
    if action.type == "APPLY_TINKER" then
      WSGH.Util.Print("Next step requires another click to open Engineering for the tinker.")
    elseif isSelfEnchantingRing then
      WSGH.Util.Print("Next step requires another click to open Enchanting for the ring enchant.")
    end
  end

  if action.type == "REFORGE_ITEM" then
    WSGH.Util.Print("Next step requires another click to open ReforgeLite for reforging.")
  end
end

local function ExecuteAction(action, rowData)
  if not action then return end
  if action.type == "ADD_SOCKET" then
    Guide.currentAction = nil
    ExecuteSocketHintAction(rowData)
  elseif action.type == "SOCKET_GEM" then
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
  elseif action.type == "UPGRADE_ITEM" then
    Guide.currentAction = nil
    if ExecuteUpgradeAction then
      ExecuteUpgradeAction(rowData)
    end
  elseif action.type == "REFORGE_ITEM" then
    Guide.currentAction = action
    ExecuteReforgeAction()
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
        Guide.currentAction = nextAction
        if NextActionRequiresDirectClick(nextAction) then
          PrimeGuidanceForAction(nextAction)
        else
          ExecuteAction(nextAction, row)
        end
      else
        WSGH.UI.Highlight.UpdateFromState()
      end
    end
  elseif action.type == "REFORGE_ITEM" then
    Guide.currentAction = nil
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
  if WSGH.UI.minimizedForReforge then
    for _, row in ipairs(WSGH.UI.rows) do
      row:Hide()
    end
    return
  end

  local frame = WSGH.UI.frame
  local rowHeight = WSGH.UI.rowHeight
  local rowFrameHeight = WSGH.UI.rowFrameHeight or WSGH.Const.UI.rowHeight
  local listTop = WSGH.UI.listTop
  local listBottomPadding = WSGH.UI.listBottomPadding or WSGH.Const.UI.listBottomPadding or 18
  local rowRightPad = WSGH.UI.rowRightPad or 18
  local availableHeight = frame:GetHeight() - math.abs(listTop) - rowFrameHeight - listBottomPadding
  local desired = math.max(1, math.floor(availableHeight / rowHeight) + 1)
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

local function GetMainFrameHeightForRows(rowCount)
  rowCount = math.max(1, math.min(tonumber(rowCount) or 1, #WSGH.Const.SLOT_ORDER))
  local rowStep = WSGH.UI.rowHeight or ((WSGH.Const.UI.rowHeight or 34) + (WSGH.Const.UI.rowGap or 0))
  local rowFrameHeight = WSGH.UI.rowFrameHeight or WSGH.Const.UI.rowHeight or 34
  local listTop = WSGH.UI.listTop or WSGH.Const.UI.listTop or -96
  local listBottomPadding = WSGH.UI.listBottomPadding or WSGH.Const.UI.listBottomPadding or 18

  return math.abs(listTop) + ((rowCount - 1) * rowStep) + rowFrameHeight + listBottomPadding
end

local function SnapMainFrameHeightToVisibleRows()
  if not WSGH.UI.frame then return end
  local targetHeight = GetMainFrameHeightForRows(WSGH.UI.visibleRows or 1)
  if WSGH.UI.maxHeight then
    targetHeight = math.min(targetHeight, WSGH.UI.maxHeight)
  end
  ResizeFromTopLeft(WSGH.UI.frame, function()
    WSGH.UI.frame:SetHeight(targetHeight)
  end)
end

local function SetMainBodyShown(shown)
  for _, frame in ipairs(WSGH.UI.mainBodyFrames or {}) do
    if shown then frame:Show() else frame:Hide() end
  end
  for _, row in ipairs(WSGH.UI.rows or {}) do
    if shown then row:Show() else row:Hide() end
  end
end

local function UpdateMinimizedToggleButton()
  local button = WSGH.UI.expandAfterReforgeBtn
  if not button then return end
  if WSGH.UI.minimizedForReforge then
    button:SetNormalTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
  else
    button:SetNormalTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
  end
end

function WSGH.UI.SetMinimizedForReforge(minimized)
  if not WSGH.UI.frame then return end

  if minimized then
    if WSGH.UI.minimizedForReforge then return end
    WSGH.UI.minimizedForReforge = true
    WSGH.UI.heightBeforeReforgeMinimize = WSGH.UI.frame:GetHeight()
    SetMainBodyShown(false)
    SetAuxiliaryFramesShown(false)
    ResizeFromTopLeft(WSGH.UI.frame, function()
      WSGH.UI.frame:SetHeight(WSGH.Const.UI.minimizedHeight)
    end)
    WSGH.UI.frame:SetResizable(false)
    if WSGH.UI.resizer then WSGH.UI.resizer:Hide() end
    UpdateMinimizedToggleButton()
    if WSGH.UI.Highlight and WSGH.UI.Highlight.ClearAll then
      WSGH.UI.Highlight.ClearAll()
    end
    return
  end

  if not WSGH.UI.minimizedForReforge then return end
  WSGH.UI.minimizedForReforge = false
  SetMainBodyShown(true)
  ResizeFromTopLeft(WSGH.UI.frame, function()
    WSGH.UI.frame:SetHeight(WSGH.UI.heightBeforeReforgeMinimize or WSGH.UI.maxHeight or WSGH.Const.UI.height)
  end)
  WSGH.UI.heightBeforeReforgeMinimize = nil
  WSGH.UI.frame:SetResizable(true)
  if WSGH.UI.resizer then WSGH.UI.resizer:Show() end
  UpdateMinimizedToggleButton()
  LayoutRows()
  SetAuxiliaryFramesShown(true)
  WSGH.UI.Render()
end

local function UpdateShoppingList()
  WSGH.UI.Shopping.UpdateShoppingList()
end

HasEquippedSnapshotChanged = function()
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

HasUpgradeSnapshotChanged = function()
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
local function IsAuctionHouseOpen()
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then return true end
  if AuctionFrame and AuctionFrame:IsShown() then return true end
  return false
end

local function SearchAuctionHouseById(itemId)
  return WSGH.UI.Shopping.SearchAuctionHouseById(itemId)
end
WSGH.UI.IsAuctionHouseOpen = IsAuctionHouseOpen

BuildDiffAndRender = function()
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
  if WSGH.UI.frame and WSGH.UI.frame:IsShown() then
    WSGH.UI.Highlight.UpdateFromState()
    WSGH.UI.Highlight.Refresh()
  end
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

  local ok, derr = WSGH.UI.ApplyImportedPlan(plan, "restore", savedText)
  if not ok then
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
  elseif event == "FORGE_MASTER_OPENED" or event == "FORGE_MASTER_ITEM_CHANGED" or event == "FORGE_MASTER_CLOSED" then
    if WSGH.State.plan then
      BuildDiffAndRender()
      if uiVisible then
        WSGH.UI.Highlight.UpdateFromState()
        WSGH.UI.Highlight.Refresh()
        if Guide.OnStateUpdated then Guide.OnStateUpdated() end
      end
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
  WSGH.UI.eventFrame:RegisterEvent("FORGE_MASTER_OPENED")
  WSGH.UI.eventFrame:RegisterEvent("FORGE_MASTER_ITEM_CHANGED")
  WSGH.UI.eventFrame:RegisterEvent("FORGE_MASTER_CLOSED")
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

ExecuteUpgradeAction = function(rowData)
  ClearActionGuidanceHighlights()
  if not rowData then return end

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
end

local function OnRowAction(rowData)
  if not rowData then return end
  if rowData.rowStatus == "WRONG_ITEM" then
    ClearActionGuidanceHighlights()
    EquipExpectedItem(rowData)
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
  local rowFrameHeight = WSGH.Const.UI.rowHeight
  local rowHeight = rowFrameHeight + (WSGH.Const.UI.rowGap or 0)
  local listTop = WSGH.Const.UI.listTop
  local listBottomPadding = WSGH.Const.UI.listBottomPadding or 18
  local rowRightPad = WSGH.Const.UI.rowRightPad
  local maxHeight = math.abs(listTop) + ((#WSGH.Const.SLOT_ORDER - 1) * rowHeight) + rowFrameHeight + listBottomPadding
  local frameWidth = WSGH.Const.UI.width

  local mainFrame = CreateFrame("Frame", "WowSimsGearHelperFrame", UIParent, "BackdropTemplate")
  mainFrame:SetSize(frameWidth, maxHeight)
  mainFrame:SetClampedToScreen(true)
  mainFrame:SetFrameStrata("DIALOG")
  mainFrame:SetToplevel(true)
  mainFrame:SetMovable(true)
  ClearUserPlaced(mainFrame)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
  end)
  mainFrame:HookScript("OnHide", CleanupAfterHide)
  
  table.insert(UISpecialFrames, "WowSimsGearHelperFrame")

  mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  if WSGH.Util and WSGH.Util.ApplyOpaqueWindowBackground then
    WSGH.Util.ApplyOpaqueWindowBackground(mainFrame, "main")
  end

  RestorePosition(mainFrame)
  mainFrame:SetHeight(maxHeight)
  ClearUserPlaced(mainFrame)

  local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("WowSims Gear Helper")

  local addonVersion = WSGH.Util and WSGH.Util.GetAddonVersion and WSGH.Util.GetAddonVersion() or (WSGH.VERSION or "unknown")
  local versionLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  versionLabel:SetPoint("LEFT", title, "RIGHT", 8, -1)
  versionLabel:SetText(("v%s"):format(tostring(addonVersion)))

  local helpBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  helpBtn:SetSize(WSGH.Const.UI.help.iconButton.width, WSGH.Const.UI.help.iconButton.height)
  helpBtn:SetText("?")
  helpBtn:SetScript("OnClick", function()
    if WSGH.UI.Help and WSGH.UI.Help.Show then
      WSGH.UI.Help.Show("quick")
    end
  end)
  if WSGH.UI.Help and WSGH.UI.Help.SetHelpTooltip then
    WSGH.UI.Help.SetHelpTooltip(helpBtn)
  end

  local monkColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS.MONK
  local monkColorCode = monkColor and monkColor.colorStr or "ff00ff98"
  local attribution = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  attribution:SetPoint("LEFT", versionLabel, "RIGHT", 8, 0)
  attribution:SetText(("by |c%sBlazzmonk|r - Garalon EU"):format(monkColorCode))
  attribution:SetTextColor(1, 1, 1, 1)

  local headerButtons = WSGH.Const.UI.headerButtons
  local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
  close:SetSize(WSGH.Const.UI.minimizedRestoreButton.width, WSGH.Const.UI.minimizedRestoreButton.height)
  close:SetPoint("TOPRIGHT", headerButtons.closeOffset.x, headerButtons.closeOffset.y)

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

  local expandAfterReforgeBtn = CreateFrame("Button", nil, mainFrame)
  expandAfterReforgeBtn:SetSize(
    WSGH.Const.UI.minimizedRestoreButton.width,
    WSGH.Const.UI.minimizedRestoreButton.height
  )
  expandAfterReforgeBtn:SetPoint("RIGHT", close, "LEFT", -headerButtons.collapseGap, 0)
  expandAfterReforgeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Up")
  expandAfterReforgeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Down")
  expandAfterReforgeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
  local function RefreshMinimizedToggleTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if WSGH.UI.minimizedForReforge then
      GameTooltip:SetText("Expand WSGH", 1, 1, 1)
      GameTooltip:AddLine("Show the full WowSims Gear Helper window.", nil, nil, nil, true)
    else
      GameTooltip:SetText("Collapse WSGH", 1, 1, 1)
      GameTooltip:AddLine("Keep only the header visible.", nil, nil, nil, true)
    end
    GameTooltip:Show()
  end
  expandAfterReforgeBtn:SetScript("OnClick", function(self)
    if WSGH.UI.SetMinimizedForReforge then
      WSGH.UI.SetMinimizedForReforge(not WSGH.UI.minimizedForReforge)
    end
    if self:IsMouseOver() then
      RefreshMinimizedToggleTooltip(self)
    end
  end)
  expandAfterReforgeBtn:SetScript("OnEnter", function(self)
    RefreshMinimizedToggleTooltip(self)
  end)
  expandAfterReforgeBtn:SetScript("OnLeave", GameTooltip_Hide)
  helpBtn:SetPoint("RIGHT", expandAfterReforgeBtn, "LEFT", -headerButtons.helpGap, 0)

  local listLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listLabel:SetPoint("TOPLEFT", 18, -78)
  listLabel:SetText("Equipped slots")

  local listWarningChip = CreateFrame("Button", nil, mainFrame)
  listWarningChip:SetPoint("LEFT", listLabel, "RIGHT", 10, 0)
  listWarningChip:SetHeight(18)
  listWarningChip:SetWidth(18)
  listWarningChip:EnableMouse(true)
  listWarningChip:Hide()

  local listWarningIcon = listWarningChip:CreateTexture(nil, "ARTWORK")
  listWarningIcon:SetSize(WSGH.Const.UI.warningIconSize, WSGH.Const.UI.warningIconSize)
  listWarningIcon:SetPoint("LEFT", 0, 0)
  listWarningIcon:SetTexture(WSGH.Const.ICON_WARNING)

  local listWarningText = listWarningChip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  listWarningText:SetPoint("LEFT", listWarningIcon, "RIGHT", 4, 0)
  listWarningText:SetJustifyH("LEFT")
  listWarningText:SetTextColor(1, 0.2, 0.2, 1)
  listWarningText:SetText("")

  local scroll = CreateFrame("ScrollFrame", "WowSimsGearHelperScroll", mainFrame, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 18, listTop)
  scroll:SetPoint("BOTTOMRIGHT", -rowRightPad, listBottomPadding)
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
  if WSGH.Util and WSGH.Util.ApplyOpaqueWindowBackground then
    WSGH.Util.ApplyOpaqueWindowBackground(sidebar, "shopping")
  end

  local sidebarTitle = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sidebarTitle:SetPoint("TOPLEFT", 14, -14)
  sidebarTitle:SetText("Shopping List")

  local shoppingByline = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  shoppingByline:SetPoint("TOPLEFT", sidebarTitle, "BOTTOMLEFT", 0, -4)
  shoppingByline:SetJustifyH("LEFT")
  shoppingByline:SetWordWrap(true)
  shoppingByline:SetTextColor(1, 0.2, 0.2, 1)
  shoppingByline:SetText("")
  shoppingByline:Hide()

  local shoppingEmpty = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  shoppingEmpty:SetPoint("TOPLEFT", shoppingByline, "BOTTOMLEFT", 0, -8)
  shoppingEmpty:SetText("No missing items")

  local shoppingReminder = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
  shoppingReminder:SetPoint("TOPLEFT", sidebar, "BOTTOMLEFT", 10, -4)
  shoppingReminder:SetPoint("TOPRIGHT", sidebar, "BOTTOMRIGHT", -10, -4)
  shoppingReminder:SetHeight(WSGH.Const.UI.shopping.reminder.height)
  shoppingReminder:SetFrameStrata("DIALOG")
  shoppingReminder:SetToplevel(true)
  shoppingReminder:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  shoppingReminder:SetBackdropColor(0, 0, 0, 0.75)
  shoppingReminder:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
  if WSGH.Util and WSGH.Util.ApplyOpaqueWindowBackground then
    WSGH.Util.ApplyOpaqueWindowBackground(shoppingReminder, "shoppingReminder", 3)
  end
  shoppingReminder:Hide()

  local shoppingReminderLabel = shoppingReminder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  shoppingReminderLabel:SetPoint("LEFT", WSGH.Const.UI.shopping.reminder.padding, 0)
  shoppingReminderLabel:SetText("Did you reforge?")
  shoppingReminderLabel:SetTextColor(1, 0.82, 0, 1)

  local shoppingReminderDone = CreateFrame("Button", nil, shoppingReminder, "UIPanelButtonTemplate")
  shoppingReminderDone:SetSize(
    WSGH.Const.UI.shopping.reminder.actionButton.width,
    WSGH.Const.UI.shopping.reminder.actionButton.height
  )
  shoppingReminderDone:SetPoint("LEFT", shoppingReminderLabel, "RIGHT", 12, 0)
  shoppingReminderDone:SetText("Done")
  shoppingReminderDone:SetScript("OnClick", function()
    WSGH.UI.DismissReforgeReminder()
  end)

  local shoppingReminderClose = CreateFrame("Button", nil, shoppingReminder, "UIPanelButtonTemplate")
  shoppingReminderClose:SetSize(
    WSGH.Const.UI.shopping.reminder.closeButton.width,
    WSGH.Const.UI.shopping.reminder.closeButton.height
  )
  shoppingReminderClose:SetPoint("RIGHT", shoppingReminder, "RIGHT", -8, 0)
  shoppingReminderClose:SetText("X")
  shoppingReminderClose:SetScript("OnClick", function()
    WSGH.UI.DismissReforgeReminder()
  end)

  local function ShowReforgeReminderTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Did you reforge?", 1, 0.82, 0)
    GameTooltip:AddLine("This import includes reforges. WSGH can sync them to ReforgeLite Classic when it is available.", 1, 1, 1, true)
    GameTooltip:AddLine("Use ReforgeLite to apply them, you can reopen WSGH to confirm you're done afterwards.", 1, 1, 1, true)
    GameTooltip:Show()
  end

  shoppingReminder:SetScript("OnEnter", ShowReforgeReminderTooltip)
  shoppingReminder:SetScript("OnLeave", GameTooltip_Hide)

  local entryHeight = WSGH.Const.UI.shopping.entryHeight
  local shoppingScroll = CreateFrame("ScrollFrame", "WowSimsGearHelperShoppingScroll", sidebar, "FauxScrollFrameTemplate")
  shoppingScroll:SetPoint("TOPLEFT", shoppingByline, "BOTTOMLEFT", 0, -8)
  shoppingScroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -14, 14)
  shoppingScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, entryHeight, UpdateShoppingList)
  end)

  local shoppingEntries = {}
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
    GameTooltip:AddLine("Uses the default Auction House only.", 0.8, 0.8, 0.8, true)
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
    LayoutRows()
    SnapMainFrameHeightToVisibleRows()
    LayoutRows()
    WSGH.UI.Render()
  end)

  mainFrame:SetScript("OnSizeChanged", function()
    LayoutRows()
    WSGH.UI.Render()
  end)

  WSGH.UI.frame = mainFrame
  WSGH.UI.title = title
  WSGH.UI.attribution = attribution
  WSGH.UI.summary = summary
  WSGH.UI.expandAfterReforgeBtn = expandAfterReforgeBtn
  WSGH.UI.scroll = scroll
  WSGH.UI.rows = rows
  WSGH.UI.rowHeight = rowHeight
  WSGH.UI.rowFrameHeight = rowFrameHeight
  WSGH.UI.visibleRows = 1
  WSGH.UI.listTop = listTop
  WSGH.UI.listBottomPadding = listBottomPadding
  WSGH.UI.rowRightPad = rowRightPad
  WSGH.UI.listWarningChip = listWarningChip
  WSGH.UI.listWarningText = listWarningText
  WSGH.UI.mainBodyFrames = { listLabel, listWarningChip, scroll }
  WSGH.UI.shoppingFrame = sidebar
  WSGH.UI.shoppingTitle = sidebarTitle
  WSGH.UI.shoppingByline = shoppingByline
  WSGH.UI.shoppingScroll = shoppingScroll
  WSGH.UI.shoppingEntries = shoppingEntries
  WSGH.UI.shoppingEmpty = shoppingEmpty
  WSGH.UI.shoppingReminder = shoppingReminder
  WSGH.UI.shoppingReminderLabel = shoppingReminderLabel
  WSGH.UI.resizer = resizer
  WSGH.UI.maxHeight = maxHeight
  WSGH.UI.RefreshWindowBackgrounds()
  WSGH.UI.eventFrame = CreateFrame("Frame")
  WSGH.UI.eventFrame:SetFrameStrata("DIALOG")
  WSGH.UI.eventFrame:SetScript("OnEvent", OnEventDispatch)
  WSGH.UI.eventFrame.pollElapsed = 0

  if WSGH.UI.Highlight and WSGH.UI.Highlight.InitializeHooks then
    WSGH.UI.Highlight.InitializeHooks()
  end

  LayoutRows()
  SetAuxiliaryFramesShown(false)
end

function WSGH.UI.Render()
  EnsureUIState()

  local diff = WSGH.State.diff
  if not diff or not diff.rows then
    if WSGH.UI.summary then
      WSGH.UI.summary:SetText(WSGH.State.plan and "Imported, no diff yet" or "No plan imported")
    end
    if WSGH.UI.minimizedForReforge then
      return
    end
    if WSGH.UI.listWarningChip then
      WSGH.UI.listWarningChip:Hide()
      WSGH.UI.listWarningChip:SetScript("OnEnter", nil)
      WSGH.UI.listWarningChip:SetScript("OnLeave", nil)
      if WSGH.UI.listWarningText then
        WSGH.UI.listWarningText:SetText("")
      end
    end
    UpdateShoppingList()
    return
  end

  WSGH.UI.summary:SetText(("Tasks: %d"):format(diff.taskCount or 0))
  if WSGH.UI.minimizedForReforge then
    return
  end
  if WSGH.UI.listWarningChip then
    local warningSlots = {}
    local hasGemWarning = false
    local hasEnchantWarning = false
    local hasUpgradeWarning = false
    for _, row in ipairs(diff.rows) do
      if row.hasImportWarning then
        warningSlots[#warningSlots + 1] = tostring(row.slotKey or row.slotId or "?")
        for _, warningCode in ipairs(row.importWarnings or {}) do
          if warningCode == "MISSING_GEMS_OMITTED" then
            hasGemWarning = true
          elseif warningCode == "MISSING_EXTRA_SOCKET_GEM_OMITTED" then
            hasGemWarning = true
          elseif warningCode == "MISSING_ENCHANT_OMITTED" then
            hasEnchantWarning = true
          elseif warningCode == "UPGRADE_STEP_ZERO_POTENTIAL"
            or warningCode == "MISSING_UPGRADE_OMITTED"
            or warningCode == "UPGRADE_STEP_NOT_MAX_POTENTIAL" then
            hasUpgradeWarning = true
          end
        end
      end
    end
    if #warningSlots > 0 then
      if WSGH.UI.listWarningText then
        WSGH.UI.listWarningText:SetText(("Import warnings (%d)"):format(#warningSlots))
        local iconWidth = tonumber(WSGH.Const.UI.warningIconSize) or 16
        local textWidth = WSGH.UI.listWarningText:GetStringWidth() or 0
        WSGH.UI.listWarningChip:SetWidth(iconWidth + 4 + textWidth + 2)
      end
      WSGH.UI.listWarningChip:Show()
      WSGH.UI.listWarningChip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local categories = {}
        if hasGemWarning then categories[#categories + 1] = "gems" end
        if hasEnchantWarning then categories[#categories + 1] = "enchant" end
        if hasUpgradeWarning then categories[#categories + 1] = "upgrades" end
        local titleText = "Possible import issues"
        if #categories > 0 then
          titleText = titleText .. ": " .. table.concat(categories, ", ")
        end
        GameTooltip:SetText(titleText, 1, 0.82, 0.2)
        GameTooltip:AddLine("Affected slots: " .. table.concat(warningSlots, ", "), 1, 1, 1, true)
        GameTooltip:AddLine(" ", 1, 1, 1, true)
        GameTooltip:AddLine("Import data may be incomplete.", 1, 0.82, 0.2, true)
        GameTooltip:AddLine("Please verify your import and update if it's incorrect.", 1, 0.82, 0.2, true)
        GameTooltip:AddLine("Hover row ? icons for more information.", 1, 0.82, 0.2, true)
        GameTooltip:Show()
      end)
      WSGH.UI.listWarningChip:SetScript("OnLeave", GameTooltip_Hide)
    else
      WSGH.UI.listWarningChip:Hide()
      WSGH.UI.listWarningChip:SetScript("OnEnter", nil)
      WSGH.UI.listWarningChip:SetScript("OnLeave", nil)
      if WSGH.UI.listWarningText then
        WSGH.UI.listWarningText:SetText("")
      end
    end
  end

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

  if WSGH.UI.frame and WSGH.UI.frame:IsShown() then
    WSGH.UI.Highlight.UpdateFromState()
    WSGH.UI.Highlight.Refresh()
  end
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
  if WSGH.UI.minimizedForReforge then
    WSGH.UI.SetMinimizedForReforge(false)
  end
  RegisterUIEvents()
  SetRuntimePollingEnabled(true)
  if WSGH.UI.Shopping and WSGH.UI.Shopping.EnableRuntimeListeners then
    WSGH.UI.Shopping.EnableRuntimeListeners()
  end
  WSGH.UI.runtimeActive = true
  WSGH.UI.frame:Show()
  SetAuxiliaryFramesShown(true)
  WSGH.DB.profile.ui.shown = true
  if WSGH.UI.Highlight and WSGH.UI.Highlight.PrimeBags then
    WSGH.UI.Highlight.PrimeBags()
  end
end

function WSGH.UI.Hide()
  if not WSGH.UI.frame then return end
  if WSGH.UI.minimizedForReforge then
    WSGH.UI.SetMinimizedForReforge(false)
  end
  WSGH.UI.frame:Hide()
  CleanupAfterHide()
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

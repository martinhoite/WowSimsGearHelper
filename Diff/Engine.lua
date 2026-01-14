local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Diff = WSGH.Diff or {}
WSGH.Diff.Engine = {}

local ENABLE_TINKERS = false
WSGH.Diff.Engine.ENABLE_TINKERS = ENABLE_TINKERS

local function GetExpectedTinkerId(planSlot)
  if not planSlot then return 0 end
  local tinkerId = tonumber(planSlot.tinkerId) or 0
  if tinkerId == 0 then
    local pref = WSGH.Util and WSGH.Util.GetDefaultTinkerForSlot and WSGH.Util.GetDefaultTinkerForSlot(planSlot.slotId)
    tinkerId = tonumber(pref) or 0
  end
  return tinkerId
end

local function BuildSocketTasksForSlot(planSlot, equippedSlot, bagIndex)
  local tasks = {}

  local expectedItemId = tonumber(planSlot.expectedItemId) or 0
  local equippedItemId = tonumber(equippedSlot.itemId) or 0

  -- If the planned slot is empty, ignore it for now (could be used later for "equip item" tasks).
  if expectedItemId == 0 then
    return tasks
  end

  -- If wrong item equipped, we do not generate socket tasks (avoid misleading guidance).
  if equippedItemId ~= expectedItemId then
    return tasks
  end

  local want = planSlot.expectedGemsByIndex or {}
  local have = equippedSlot.gemsByIndex or {}

  for socketIndex, wantGemId in pairs(want) do
    wantGemId = tonumber(wantGemId) or 0
    if wantGemId ~= 0 then
      local haveGemId = tonumber(have[socketIndex]) or 0

      local status = WSGH.Const.STATUS_OK
      local locations = bagIndex and bagIndex[wantGemId] or nil

      if haveGemId == 0 then
        status = WSGH.Const.STATUS_EMPTY
      elseif haveGemId ~= wantGemId then
        status = WSGH.Const.STATUS_WRONG
      end

      if status ~= WSGH.Const.STATUS_OK and (not locations or #locations == 0) then
        status = WSGH.Const.STATUS_MISSING
      end

      tasks[#tasks + 1] = {
        type = "SOCKET_GEM",
        slotId = planSlot.slotId,
        slotKey = planSlot.slotKey,
        itemId = equippedItemId,

        socketIndex = socketIndex,

        wantGemId = wantGemId,
        haveGemId = haveGemId,

        status = status,

        bagLocations = locations, -- may be nil
      }
    end
  end

  -- Ensure stable ordering for UI: socketIndex ascending
  table.sort(tasks, function(a, b)
    return a.socketIndex < b.socketIndex
  end)

  return tasks
end

local function BuildEnchantTasksForSlot(planSlot, equippedSlot, bagIndex)
  local tasks = {}

  local expectedItemId = tonumber(planSlot.expectedItemId) or 0
  local equippedItemId = tonumber(equippedSlot.itemId) or 0
  local expectedEnchantId = tonumber(planSlot.expectedEnchantId) or 0
  local hasEngineering = WSGH.Util and WSGH.Util.HasEngineering and WSGH.Util.HasEngineering() or false

  -- Do not suggest enchants if the wrong item is equipped.
  if expectedItemId == 0 or equippedItemId ~= expectedItemId then
    return tasks
  end

  local function addEnchantTask(spellId, taskType)
    spellId = tonumber(spellId) or 0
    if spellId == 0 then return end

    local haveEnchantId = tonumber(equippedSlot.enchantId) or 0
    local applyItemId, applyItemSource = 0, nil
    if WSGH.Data and WSGH.Data.Enchants and WSGH.Data.Enchants.GetItemForEnchant then
      applyItemId, applyItemSource = WSGH.Data.Enchants.GetItemForEnchant(spellId)
    end
    local locations = applyItemId ~= 0 and bagIndex and bagIndex[applyItemId] or nil
    local manualOnly = WSGH.Data and WSGH.Data.Enchants and WSGH.Data.Enchants.IsManualOnly and WSGH.Data.Enchants.IsManualOnly(spellId)
    local isTinker = WSGH.Data and WSGH.Data.Enchants and WSGH.Data.Enchants.IsTinkerSpell and WSGH.Data.Enchants.IsTinkerSpell(spellId)
    if taskType == "APPLY_TINKER" then
      manualOnly = true -- tinkers are applied manually, not via scroll
    end

    local status = WSGH.Const.STATUS_OK
    if haveEnchantId ~= spellId then
      status = WSGH.Const.STATUS_WRONG
      if isTinker then
        status = WSGH.Const.STATUS_OK
      end
      if applyItemId ~= 0 and (not locations or #locations == 0) then
        status = WSGH.Const.STATUS_MISSING
      end
    end

    tasks[#tasks + 1] = {
      type = taskType or "APPLY_ENCHANT",
      slotId = planSlot.slotId,
      slotKey = planSlot.slotKey,
      itemId = equippedItemId,

      wantEnchantId = spellId,
      wantEnchantItemId = applyItemId,
      enchantItemSource = applyItemSource,
      haveEnchantId = haveEnchantId,
      manualOnly = manualOnly,

      status = status,
      bagLocations = locations, -- may be nil
    }
  end

  addEnchantTask(expectedEnchantId, "APPLY_ENCHANT")

  if ENABLE_TINKERS then
    local expectedTinkerId = GetExpectedTinkerId(planSlot)
    if hasEngineering and expectedTinkerId ~= 0 and expectedTinkerId ~= expectedEnchantId then
      addEnchantTask(expectedTinkerId, "APPLY_TINKER")
    end
  end

  return tasks
end

local function ComputeSocketCount(planSlot, equippedSlot)
  local count = tonumber(equippedSlot.socketCount) or 0
  local maxIndex = count

  for socketIndex in pairs(planSlot.expectedGemsByIndex or {}) do
    if socketIndex > maxIndex then
      maxIndex = socketIndex
    end
  end
  for socketIndex in pairs(equippedSlot.gemsByIndex or {}) do
    if socketIndex > maxIndex then
      maxIndex = socketIndex
    end
  end

  count = math.max(count, maxIndex)
  return math.min(math.max(count, 0), WSGH.Const.MAX_SOCKETS_RENDER)
end

local function MaxExpectedSocketIndex(planSlot)
  local maxIdx = 0
  for socketIndex in pairs(planSlot.expectedGemsByIndex or {}) do
    if socketIndex > maxIdx then
      maxIdx = socketIndex
    end
  end
  return maxIdx
end

local function SocketHintForSlot(slotMeta, planSlot, equippedSlot, computedSocketCount)
  local expectedItemId = tonumber(planSlot.expectedItemId) or 0
  local equippedItemId = tonumber(equippedSlot.itemId) or 0
  if expectedItemId == 0 or equippedItemId ~= expectedItemId then
    return nil
  end

  local physicalSockets = tonumber(equippedSlot.socketCount) or 0
  local maxExpected = MaxExpectedSocketIndex(planSlot)

  -- Belt edge case: when item data is cached poorly we may miss the buckle socket; if the plan expects more sockets, trust the plan for counting.
  if slotMeta.slotId == 6 and maxExpected > physicalSockets then
    physicalSockets = maxExpected
  end
  -- Weapon sockets rely on reported stats; no extra overrides.

  local missingSockets = math.max(0, maxExpected - physicalSockets)
  if missingSockets <= 0 then return nil end

  local slotId = slotMeta.slotId
  local itemLevel = tonumber(equippedSlot.itemLevel) or 0

  -- Belts: recommend a buckle by item level.
  if slotId == 6 then
    local itemId = 90046 -- Living Steel Belt Buckle
    if itemLevel > 0 and itemLevel <= 299 then
      itemId = 41611 -- Eternal Belt Buckle
    elseif itemLevel > 0 and itemLevel <= 416 then
      itemId = 55054 -- Ebonsteel Belt Buckle
    end
    local name = GetItemInfo(itemId) or ("Belt buckle (" .. itemId .. ")")
    return { text = "Add socket: " .. name, itemId = itemId, missing = missingSockets }
  end

  -- Blacksmithing extra sockets (bracer/gloves).
  if slotId == 9 or slotId == 10 then
    local requiredSkill = (itemLevel > 416) and 550 or 400
    local fluxPerSocket = 4
    local fluxItemId = 3466 -- Strong Flux (vendor)
    local text = ("Add socket via Blacksmithing (requires %d skill) and %d x Strong Flux per socket"):format(requiredSkill, fluxPerSocket)
    return {
      text = text,
      itemId = nil,
      missing = missingSockets,
      extraItemId = fluxItemId,
      extraItemCount = fluxPerSocket * missingSockets,
    }
  end

  -- Sha-Touched / Throne of Thunder weapon socket.
  if slotId == 16 or slotId == 17 then
    if physicalSockets == 0 then
      return { text = "If this is a Sha-Touched/ToT weapon, use Eye of the Black Prince (93403)", itemId = 93403, missing = missingSockets }
    end
    return nil
  end

  return { text = ("Add an extra socket (plan has %d, item has %d)"):format(maxExpected, physicalSockets), itemId = nil, missing = missingSockets }
end

local function ComputeRowStatus(planSlot, equippedSlot, socketTasks, enchantTasks)
  local expectedItemId = tonumber(planSlot.expectedItemId) or 0
  local equippedItemId = tonumber(equippedSlot.itemId) or 0

  if expectedItemId ~= 0 and equippedItemId ~= expectedItemId then
    return "WRONG_ITEM"
  end

  for _, t in ipairs(socketTasks) do
    if t.status ~= WSGH.Const.STATUS_OK then
      return "NEEDS_WORK"
    end
  end

  for _, t in ipairs(enchantTasks) do
    if t.status ~= WSGH.Const.STATUS_OK then
      return "NEEDS_WORK"
    end
  end

  return "OK"
end

local function NextSocketTask(socketTasks)
  for _, t in ipairs(socketTasks) do
    if t.status ~= WSGH.Const.STATUS_OK then
      return t
    end
  end
  return nil
end

local function NextEnchantTask(enchantTasks)
  for _, t in ipairs(enchantTasks) do
    if t.status ~= WSGH.Const.STATUS_OK then
      return t
    end
  end
  return nil
end

local function BuildEnchantDisplays(planSlot, enchantTasks)
  local displays = {}
  local enchantId = tonumber(planSlot.expectedEnchantId) or 0
  local tinkerId = GetExpectedTinkerId(planSlot)
  local hasEngineering = WSGH.Util and WSGH.Util.HasEngineering and WSGH.Util.HasEngineering() or false

  local function addDisplay(spellId, opts)
    opts = opts or {}
    if spellId == 0 then return end
    local info = WSGH.Data and WSGH.Data.Enchants and WSGH.Data.Enchants.GetDisplayInfo(spellId) or nil
    local infoItemId = info and tonumber(info.itemId) or 0
    local infoItemSource = info and info.itemSource or nil
    local entry = {
      spellId = spellId,
      name = info and info.name or (opts.isTinker and ("Tinker " .. spellId) or ("Enchant " .. spellId)),
      icon = opts.icon or (info and info.icon) or (opts.isTinker and WSGH.Const.ICON_TINKER or WSGH.Const.ICON_ENCHANT),
      status = WSGH.Const.STATUS_OK,
      manualOnly = opts.manualOnly or false,
      itemId = infoItemId or 0,
      itemSource = infoItemSource,
      isTinker = opts.isTinker or false,
      unsupported = opts.unsupported or false,
    }
    for _, t in ipairs(enchantTasks or {}) do
      if tonumber(t.wantEnchantId) == spellId and t.status ~= WSGH.Const.STATUS_OK then
        entry.status = t.status
        entry.manualOnly = t.manualOnly and true or entry.manualOnly
        entry.itemId = tonumber(t.wantEnchantItemId) or 0
        entry.itemSource = t.enchantItemSource
        break
      end
    end
    if entry.itemId == 0 and WSGH.Data and WSGH.Data.Enchants and WSGH.Data.Enchants.GetItemForEnchant then
      local iid, src = WSGH.Data.Enchants.GetItemForEnchant(spellId)
      entry.itemId = iid or 0
      entry.itemSource = src
    end
    displays[#displays + 1] = entry
  end

  addDisplay(enchantId, { unsupported = planSlot.expectedEnchantUnsupported })
  if ENABLE_TINKERS and hasEngineering and tinkerId ~= 0 then
    addDisplay(tinkerId, { isTinker = true, icon = WSGH.Const.ICON_TINKER, manualOnly = true })
  end

  return displays
end

function WSGH.Diff.Engine.Build(plan, equipped, bagIndex)
  if type(plan) ~= "table" or type(plan.slots) ~= "table" then
    return nil, "Invalid plan"
  end

  if type(equipped) ~= "table" then
    return nil, "Invalid equipped state"
  end

  local result = {
    rows = {}, -- array in SLOT_ORDER order
    tasks = {}, -- flat list of tasks across all rows
    taskCount = 0,
  }

  for _, slotMeta in ipairs(WSGH.Const.SLOT_ORDER) do
    local slotId = slotMeta.slotId
    local planSlot = plan.slots[slotId]
    local eqSlot = equipped[slotId]

    if planSlot and eqSlot then
      local socketTasks = BuildSocketTasksForSlot(planSlot, eqSlot, bagIndex)
      local enchantTasks = BuildEnchantTasksForSlot(planSlot, eqSlot, bagIndex)
      local rowStatus = ComputeRowStatus(planSlot, eqSlot, socketTasks, enchantTasks)
      local nextTask = NextSocketTask(socketTasks)
      local nextEnchantTask = NextEnchantTask(enchantTasks)
      local computedSocketCount = ComputeSocketCount(planSlot, eqSlot)
      local socketHint = SocketHintForSlot(slotMeta, planSlot, eqSlot, computedSocketCount)
      local enchantDisplays = BuildEnchantDisplays(planSlot, enchantTasks)
      if rowStatus == "WRONG_ITEM" then
        enchantDisplays = {}
      end

      for _, t in ipairs(socketTasks) do
        if t.status ~= WSGH.Const.STATUS_OK then
          result.tasks[#result.tasks + 1] = t
        end
      end
      for _, t in ipairs(enchantTasks) do
        if t.status ~= WSGH.Const.STATUS_OK then
          result.tasks[#result.tasks + 1] = t
        end
      end

      result.rows[#result.rows + 1] = {
        slotId = slotId,
        slotKey = slotMeta.key,

        expectedItemId = planSlot.expectedItemId,
        equippedItemId = eqSlot.itemId,
        equippedLink = eqSlot.itemLink,
        bagLocations = bagIndex and bagIndex[planSlot.expectedItemId] or nil,
        hasExpectedInBags = bagIndex and bagIndex[planSlot.expectedItemId] and #bagIndex[planSlot.expectedItemId] > 0 or false,

        rowStatus = rowStatus,

        enchantTasks = enchantTasks,
        nextEnchantTask = nextEnchantTask,
        enchantDisplays = enchantDisplays,
        socketTasks = socketTasks,
        nextTask = nextTask,
        socketCount = computedSocketCount,
        physicalSocketCount = tonumber(eqSlot.socketCount) or 0,
        socketHintText = socketHint and socketHint.text or nil,
        socketHintItemId = socketHint and socketHint.itemId or nil,
        missingSockets = socketHint and socketHint.missing or 0,
        socketHintExtraItemId = socketHint and socketHint.extraItemId or nil,
        socketHintExtraItemCount = socketHint and socketHint.extraItemCount or 0,
      }
    end
  end

  result.taskCount = #result.tasks
  return result
end

-- Debug helper: WSGH.Debug.DumpDiffRow(slotId)
WSGH.Debug = WSGH.Debug or {}
function WSGH.Debug.DumpDiffRow(slotId)
  slotId = tonumber(slotId) or 0
  if slotId == 0 then
    WSGH.Util.Print("DumpDiffRow: provide slotId.")
    return
  end
  local diff = WSGH.State and WSGH.State.diff
  if not diff or not diff.rows then
    WSGH.Util.Print("DumpDiffRow: no diff.")
    return
  end
  for _, row in ipairs(diff.rows) do
    if tonumber(row.slotId) == slotId then
      WSGH.Util.Print(("Row slot %d key %s: socketCount=%s physical=%s missingSockets=%s hintItem=%s hintText=%s"):format(
        slotId,
        tostring(row.slotKey),
        tostring(row.socketCount),
        tostring(row.physicalSocketCount),
        tostring(row.missingSockets),
        tostring(row.socketHintItemId),
        tostring(row.socketHintText)
      ))
      if row.socketTasks then
        for _, t in ipairs(row.socketTasks) do
          WSGH.Util.Print(("[%d] want=%s have=%s status=%s"):format(
            tonumber(t.socketIndex) or 0,
            tostring(t.wantGemId),
            tostring(t.haveGemId),
            tostring(t.status)
          ))
        end
      end
      return
    end
  end
  WSGH.Util.Print("DumpDiffRow: slot not found.")
end

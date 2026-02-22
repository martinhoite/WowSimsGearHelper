local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Importers = WSGH.Importers or {}
WSGH.Importers.WowSimsV2 = {}

local function IsArray(t)
  if type(t) ~= "table" then
    return false
  end
  return t[1] ~= nil
end

local function NormalizeGemsByIndex(gems)
  -- Keep socket index meaning, but drop zeros.
  -- Output is a sparse map: [1]=gemId, [2]=gemId, ...
  local out = {}
  if type(gems) ~= "table" then
    return out
  end

  for i, v in ipairs(gems) do
    local n = tonumber(v) or 0
    if n ~= 0 then
      out[i] = n
    end
  end

  return out
end

local MISSING_ENCHANT_WARNED = {}
local function WarnMissingEnchant(effectId)
  effectId = tonumber(effectId) or 0
  if effectId == 0 then return end
  if MISSING_ENCHANT_WARNED[effectId] then return end
  MISSING_ENCHANT_WARNED[effectId] = true
  if WSGH and WSGH.Util and WSGH.Util.Print then
    WSGH.Util.Print(("Unsupported enchant in import (effectId %d). Please notify the addon author."):format(effectId))
  end
end

local function NormalizeEnchantId(rawEnchantId)
  rawEnchantId = tonumber(rawEnchantId) or 0
  if rawEnchantId == 0 then return 0, false end
  if WSGH and WSGH.Data and WSGH.Data.Enchants and WSGH.Data.Enchants.NormalizeEffectId then
    local normalized, known = WSGH.Data.Enchants.NormalizeEffectId(rawEnchantId)
    if not known then
      WarnMissingEnchant(rawEnchantId)
      return normalized, true
    end
    return normalized, false
  end
  WarnMissingEnchant(rawEnchantId)
  return rawEnchantId, true
end

local function NormalizeTinkerId(rawTinkerId)
  rawTinkerId = tonumber(rawTinkerId) or 0
  if rawTinkerId == 0 then return 0 end
  if WSGH and WSGH.Data and WSGH.Data.Enchants and WSGH.Data.Enchants.NormalizeEffectId then
    local normalized = WSGH.Data.Enchants.NormalizeEffectId(rawTinkerId)
    return normalized
  end
  return rawTinkerId
end

local function NormalizeUpgradeStep(rawUpgradeStep)
  if rawUpgradeStep == nil then return 0 end

  if type(rawUpgradeStep) == "number" then
    local n = tonumber(rawUpgradeStep) or 0
    if n < 0 then return 0 end
    if n > 2 then return 2 end
    return n
  end

  if type(rawUpgradeStep) ~= "string" then
    return 0
  end

  local normalized = rawUpgradeStep:gsub("%s+", ""):lower()
  if normalized == "upgradestepone" then return 1 end
  if normalized == "upgradesteptwo" then return 2 end

  local trailingNumber = tonumber(normalized:match("(%d+)$")) or 0
  if trailingNumber <= 0 then return 0 end
  if trailingNumber > 2 then return 2 end
  return trailingNumber
end

function WSGH.Importers.WowSimsV2.FromDecoded(decoded)
  if type(decoded) ~= "table" then
    return nil, "Export is not an object"
  end

  if decoded.apiVersion ~= 2 then
    return nil, "Unsupported apiVersion (expected 2)"
  end

  local player = decoded.player
  if type(player) ~= "table" then
    return nil, "Missing player object"
  end

  local equipment = player.equipment
  if type(equipment) ~= "table" then
    return nil, "Missing player.equipment"
  end

  local items = equipment.items
  if not IsArray(items) then
    return nil, "Missing player.equipment.items array"
  end

  -- Build normalized plan
  local plan = {
    meta = {
      source = "WowSims",
      apiVersion = decoded.apiVersion,
      class = player.class,
      race = player.race,
      name = player.name
    },
    slots = {} -- keyed by inventory slotId
  }

  for i, slotMeta in ipairs(WSGH.Const.SLOT_ORDER) do
    local e = items[i] or {}
    local itemId = tonumber(e.id) or 0

    local expectedEnchantId, enchantUnsupported = NormalizeEnchantId(e.enchant)
    plan.slots[slotMeta.slotId] = {
      slotKey = slotMeta.key,
      slotId = slotMeta.slotId,

      expectedItemId = itemId,

      expectedGemsByIndex = NormalizeGemsByIndex(e.gems),

      -- Stored for later features, unused in v1 UI:
      expectedEnchantId = expectedEnchantId,
      expectedEnchantUnsupported = enchantUnsupported,
      expectedReforgeId = tonumber(e.reforging) or 0,
      upgradeStep = e.upgradeStep,
      expectedUpgradeStep = NormalizeUpgradeStep(e.upgradeStep),
      randomSuffix = tonumber(e.randomSuffix) or 0,
      tinkerId = NormalizeTinkerId(e.tinker)
    }
  end

  return plan
end

local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Importers = WSGH.Importers or {}

local WowSimsImporter = WSGH.Importers.WowSims or {}
WSGH.Importers.WowSims = WowSimsImporter
WSGH.Importers.WowSimsV3 = WowSimsImporter

local SUPPORTED_API_VERSIONS = {
  [2] = true,
  [3] = true,
}

local SUPPORTED_API_VERSION_LIST = { 2, 3 }

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
  local maxIndex = 0
  if type(gems) ~= "table" then
    return out, maxIndex
  end

  for i, v in ipairs(gems) do
    maxIndex = i
    local n = tonumber(v) or 0
    if n ~= 0 then
      out[i] = n
    end
  end

  return out, maxIndex
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

local function NormalizeReforgeId(rawReforgeId)
  if WSGH.Integrations and WSGH.Integrations.ReforgeLite and WSGH.Integrations.ReforgeLite.NormalizeReforgeId then
    return WSGH.Integrations.ReforgeLite.NormalizeReforgeId(rawReforgeId)
  end

  rawReforgeId = tonumber(rawReforgeId) or 0
  if rawReforgeId == 0 then return 0 end
  local normalized = rawReforgeId - 112
  if normalized <= 0 then return 0 end
  return normalized
end

local function BuildSupportedApiVersionText()
  local count = #SUPPORTED_API_VERSION_LIST
  if count == 0 then
    return "none"
  end
  if count == 1 then
    return tostring(SUPPORTED_API_VERSION_LIST[1])
  end
  if count == 2 then
    return tostring(SUPPORTED_API_VERSION_LIST[1]) .. " and " .. tostring(SUPPORTED_API_VERSION_LIST[2])
  end

  local parts = {}
  for i = 1, count - 1 do
    parts[#parts + 1] = tostring(SUPPORTED_API_VERSION_LIST[i])
  end
  return table.concat(parts, ", ") .. ", and " .. tostring(SUPPORTED_API_VERSION_LIST[count])
end

function WowSimsImporter.IsSupportedApiVersion(rawApiVersion)
  local apiVersion = tonumber(rawApiVersion)
  return apiVersion ~= nil and SUPPORTED_API_VERSIONS[apiVersion] == true
end

function WowSimsImporter.BuildUnsupportedApiVersionError(rawApiVersion)
  local supportedVersionsText = BuildSupportedApiVersionText()
  return ("Unsupported WowSims apiVersion %s. This addon currently supports apiVersion %s. Please notify the addon author and ask for an update: https://www.curseforge.com/wow/addons/wowsims-gear-helper"):format(
    tostring(rawApiVersion),
    supportedVersionsText
  )
end

function WowSimsImporter.FromDecoded(decoded)
  if type(decoded) ~= "table" then
    return nil, "Export is not an object"
  end

  local apiVersion = tonumber(decoded.apiVersion)
  if not WowSimsImporter.IsSupportedApiVersion(apiVersion) then
    return nil, WowSimsImporter.BuildUnsupportedApiVersionError(decoded.apiVersion)
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
      apiVersion = apiVersion,
      class = player.class,
      race = player.race,
      name = player.name,
      hasReforges = false,
    },
    slots = {} -- keyed by inventory slotId
  }

  for i, slotMeta in ipairs(WSGH.Const.SLOT_ORDER) do
    local e = items[i] or {}
    local itemId = tonumber(e.id) or 0
    local importHasEnchantField = e.enchant ~= nil
    local importHasGemsField = e.gems ~= nil
    local importHasUpgradeField = e.upgradeStep ~= nil
    -- WowSims omits reforging when the target is no reforge, so every imported
    -- item carries an explicit normalized reforge target.
    local importHasReforgeField = itemId ~= 0
    local expectedGemsByIndex, expectedGemSocketCount = NormalizeGemsByIndex(e.gems)

    local expectedEnchantId, enchantUnsupported = NormalizeEnchantId(e.enchant)
    local expectedReforgeId = NormalizeReforgeId(e.reforging)
    plan.slots[slotMeta.slotId] = {
      slotKey = slotMeta.key,
      slotId = slotMeta.slotId,

      expectedItemId = itemId,

      expectedGemsByIndex = expectedGemsByIndex,
      expectedGemSocketCount = tonumber(expectedGemSocketCount) or 0,
      importHasGemsField = importHasGemsField,
      importHasEnchantField = importHasEnchantField,
      importHasUpgradeField = importHasUpgradeField,
      importHasReforgeField = importHasReforgeField,

      -- Stored for later features, unused in v1 UI:
      expectedEnchantId = expectedEnchantId,
      expectedEnchantUnsupported = enchantUnsupported,
      expectedRawReforgeId = tonumber(e.reforging) or 0,
      expectedReforgeId = expectedReforgeId,
      upgradeStep = e.upgradeStep,
      expectedUpgradeStep = NormalizeUpgradeStep(e.upgradeStep),
      randomSuffix = tonumber(e.randomSuffix) or 0,
      tinkerId = NormalizeTinkerId(e.tinker)
    }
    if expectedReforgeId ~= 0 then
      plan.meta.hasReforges = true
    end
  end

  return plan
end

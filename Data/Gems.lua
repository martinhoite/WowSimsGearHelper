local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Data = WSGH.Data or {}

local mopRareGemToPerfectGemId = {
  -- River's Heart / Lapis Lazuli
  [76636] = 76570, -- Rigid
  [76637] = 76571, -- Stormy
  [76638] = 76572, -- Sparkling
  [76639] = 76573, -- Solid

  -- Wild Jade / Alexandrite
  [76640] = 76574, -- Misty
  [76641] = 76575, -- Piercing
  [76642] = 76576, -- Lightning
  [76643] = 76577, -- Sensei's
  [76644] = 76578, -- Effulgent
  [76645] = 76579, -- Zen
  [76646] = 76580, -- Balanced
  [76647] = 76581, -- Vivid
  [76648] = 76582, -- Turbid
  [76649] = 76583, -- Radiant
  [76650] = 76584, -- Shattered
  [76651] = 76585, -- Energized
  [76652] = 76586, -- Jagged
  [76653] = 76587, -- Regal
  [76654] = 76588, -- Forceful
  [76655] = 76589, -- Confounded
  [76656] = 76590, -- Puissant
  [76657] = 76591, -- Steady

  -- Vermilion Onyx / Tiger Opal
  [76658] = 76592, -- Deadly
  [76659] = 76593, -- Crafty
  [76660] = 76594, -- Potent
  [76661] = 76595, -- Inscribed
  [76662] = 76596, -- Polished
  [76663] = 76597, -- Resolute
  [76664] = 76598, -- Stalwart
  [76665] = 76599, -- Champion's
  [76666] = 76600, -- Deft
  [76667] = 76601, -- Wicked
  [76668] = 76602, -- Reckless
  [76669] = 76603, -- Fierce
  [76670] = 76604, -- Adept
  [76671] = 76605, -- Keen
  [76672] = 76606, -- Artful
  [76673] = 76607, -- Fine
  [76674] = 76608, -- Skillful
  [76675] = 76609, -- Lucent
  [76676] = 76610, -- Tenuous
  [76677] = 76611, -- Willful
  [76678] = 76612, -- Splendid
  [76679] = 76613, -- Resplendent

  -- Imperial Amethyst / Roguestone
  [76680] = 76614, -- Glinting
  [76681] = 76615, -- Accurate
  [76682] = 76616, -- Veiled
  [76683] = 76617, -- Retaliating
  [76684] = 76618, -- Etched
  [76685] = 76619, -- Mysterious
  [76686] = 76620, -- Purified
  [76687] = 76621, -- Shifting
  [76688] = 76622, -- Guardian's
  [76689] = 76623, -- Timeless
  [76690] = 76624, -- Defender's
  [76691] = 76625, -- Sovereign

  -- Primordial Ruby / Pandarian Garnet
  [76692] = 76626, -- Delicate
  [76693] = 76627, -- Precise
  [76694] = 76628, -- Brilliant
  [76695] = 76629, -- Flashing
  [76696] = 76630, -- Bold

  -- Sun's Radiance / Sunstone
  [76697] = 76631, -- Smooth
  [76698] = 76632, -- Subtle
  [76699] = 76633, -- Quick
  [76700] = 76634, -- Fractured
  [76701] = 76635, -- Mystic
}

local mopEquivalentRareGemIdByItemId = {}
for rareGemId, perfectGemId in pairs(mopRareGemToPerfectGemId) do
  mopEquivalentRareGemIdByItemId[rareGemId] = rareGemId
  mopEquivalentRareGemIdByItemId[perfectGemId] = rareGemId
end

local function IsMopGemEquivalenceContext(expansionKey)
  if expansionKey ~= "MOP" then
    return false
  end

  local build = (type(GetBuildInfo) == "function") and select(4, GetBuildInfo()) or 0
  build = tonumber(build) or 0
  return build == 0 or build < 60000
end

local function NormalizeMopGemId(itemId)
  itemId = tonumber(itemId) or 0
  if itemId == 0 then return 0 end
  return mopEquivalentRareGemIdByItemId[itemId] or itemId
end

local Gems = {}

function Gems.AreEquivalentGemIds(expectedGemId, actualGemId, expansionKey)
  expectedGemId = tonumber(expectedGemId) or 0
  actualGemId = tonumber(actualGemId) or 0

  if expectedGemId == actualGemId then
    return true
  end

  if not IsMopGemEquivalenceContext(expansionKey) then
    return false
  end

  return NormalizeMopGemId(expectedGemId) == NormalizeMopGemId(actualGemId)
end

WSGH.Data.Gems = Gems

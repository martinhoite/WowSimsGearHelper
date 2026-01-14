local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Data = WSGH.Data or {}

-- Mapping from enchant [spellId] -> vellum itemId.
WSGH.Data.EnchantVellumMap = {
  [7445] = 38767, -- Enchant Chest - Minor Absorption
  [13611] = 11150, -- Enchant Gloves - Mining
  [13614] = 11151, -- Enchant Gloves - Herbalism
  [13697] = 11166, -- Enchant Gloves - Skinning
  [13838] = 11203, -- Enchant Gloves - Advanced Mining
  [13839] = 11205, -- Enchant Gloves - Advanced Herbalism
  [13889] = 38837, -- Enchant Boots - Minor Speed
  [13897] = 11207, -- Enchant Weapon - Fiery Weapon
  [13907] = 11208, -- Enchant Weapon - Demonslaying
  [13927] = 11226, -- Enchant Gloves - Riding Skill
  [20004] = 16254, -- Enchant Weapon - Lifestealing
  [20005] = 16223, -- Enchant Weapon - Icy Chill
  [20006] = 16248, -- Enchant Weapon - Unholy Weapon
  [20007] = 16252, -- Enchant Weapon - Crusader
  [24090] = 52781, -- Enchant Boots - Assassin's Step
  [25063] = 33153, -- Enchant Gloves - Threat
  [25070] = 33150, -- Enchant Cloak - Subtlety
  [27997] = 22558, -- Enchant Weapon - Spellsurge
  [28005] = 22557, -- Enchant Weapon - Battlemaster
  [28093] = 22559, -- Enchant Weapon - Mongoose
  [43588] = 254314, -- Enchant Weapon - Tyranny
  [44507] = 38960, -- Enchant Gloves - Gatherer
  [44525] = 38965, -- Enchant Weapon - Icebreaker
  [44578] = 38972, -- Enchant Weapon - Lifeward
  [44622] = 38988, -- Enchant Weapon - Giant Slayer
  [46579] = 35498, -- Enchant Weapon - Deathfrost
  [59620] = 44493, -- Enchant Weapon - Berserking
  [59630] = 43987, -- Enchant Weapon - Black Magic
  [64440] = 46026, -- Enchant Weapon - Blade Ward
  [64571] = 46098, -- Enchant Weapon - Blood Draining
  [71691] = 50406, -- Enchant Gloves - Angler
  [74132] = 52687, -- Enchant Gloves - Mastery
  [74190] = 52744, -- Enchant Chest - Mighty Stats
  [74192] = 52745, -- Enchant Cloak - Lesser Power
  [74193] = 52746, -- Enchant Bracer - Speed
  [74194] = 52747, -- Enchant Weapon - Mending
  [74196] = 52748, -- Enchant Weapon - Avalanche
  [74198] = 52749, -- Enchant Gloves - Haste
  [74199] = 52750, -- Enchant Boots - Haste
  [74200] = 52751, -- Enchant Chest - Stamina
  [74201] = 52752, -- Enchant Bracer - Critical Strike
  [74202] = 52753, -- Enchant Cloak - Intellect
  [74207] = 52754, -- Enchant Shield - Protection
  [74208] = 52755, -- Enchant Weapon - Elemental Slayer
  [74212] = 52756, -- Enchant Gloves - Exceptional Strength
  [74213] = 52757, -- Enchant Boots - Major Agility
  [74214] = 52758, -- Enchant Chest - Mighty Resilience
  [74220] = 52759, -- Enchant Gloves - Greater Expertise
  [74221] = 52760, -- Enchant Weapon - Hurricane
  [74226] = 52762, -- Enchant Shield - Mastery
  [74229] = 52763, -- Enchant Bracer - Superior Dodge
  [74230] = 52764, -- Enchant Cloak - Critical Strike
  [74231] = 52765, -- Enchant Chest - Exceptional Spirit
  [74232] = 52766, -- Enchant Bracer - Precision
  [74234] = 52767, -- Enchant Cloak - Protection
  [74235] = 52768, -- Enchant Off-Hand - Superior Intellect
  [74236] = 52769, -- Enchant Boots - Precision
  [74237] = 52770, -- Enchant Bracer - Exceptional Spirit
  [74238] = 52771, -- Enchant Boots - Mastery
  [74239] = 52772, -- Enchant Bracer - Greater Expertise
  [74240] = 52773, -- Enchant Cloak - Greater Intellect
  [74243] = 52735, -- Enchant Weapon - Windwalk
  [74245] = 52736, -- Enchant Weapon - Landslide
  [74247] = 52737, -- Enchant Cloak - Greater Critical Strike
  [74248] = 52738, -- Enchant Bracer - Greater Critical Strike
  [74249] = 52739, -- Enchant Chest - Peerless Stats
  [74251] = 52740, -- Enchant Chest - Greater Stamina
  [74254] = 52783, -- Enchant Gloves - Mighty Strength
  [74255] = 52784, -- Enchant Gloves - Greater Mastery
  [74256] = 52785, -- Enchant Bracer - Greater Speed
  [94746] = 52733, -- Enchant Weapon - Power Torrent
  [95471] = 68134, -- Enchant 2H Weapon - Mighty Agility
  [95653] = 52761, -- Enchant Weapon - Heartsong
  [96261] = 68785, -- Enchant Bracer - Major Strength
  [96262] = 68786, -- Enchant Bracer - Mighty Intellect
  [96264] = 68784, -- Enchant Bracer - Agility
  [104040] = 74727, -- Enchant Weapon - Colossus
  [104338] = 74700, -- Enchant Bracer - Mastery
  [104385] = 74701, -- Enchant Bracer - Major Dodge
  [104389] = 74703, -- Enchant Bracer - Super Intellect
  [104390] = 74704, -- Enchant Bracer - Exceptional Strength
  [104391] = 74705, -- Enchant Bracer - Greater Agility
  [104392] = 74706, -- Enchant Chest - Super Resilience
  [104393] = 74707, -- Enchant Chest - Mighty Spirit
  [104395] = 74708, -- Enchant Chest - Glorious Stats
  [104397] = 74709, -- Enchant Chest - Superior Stamina
  [104398] = 74710, -- Enchant Cloak - Accuracy
  [104401] = 74711, -- Enchant Cloak - Greater Protection
  [104403] = 74712, -- Enchant Cloak - Superior Intellect
  [104404] = 74713, -- Enchant Cloak - Superior Critical Strike
  [104407] = 74715, -- Enchant Boots - Greater Haste
  [104408] = 74716, -- Enchant Boots - Greater Precision
  [104409] = 74717, -- Enchant Boots - Blurred Speed
  [104414] = 74718, -- Enchant Boots - Pandaren's Step
  [104416] = 74719, -- Enchant Gloves - Greater Haste
  [104417] = 74720, -- Enchant Gloves - Superior Expertise
  [104419] = 74721, -- Enchant Gloves - Super Strength
  [104420] = 74722, -- Enchant Gloves - Superior Mastery
  [104425] = 74723, -- Enchant Weapon - Windsong
  [104427] = 74724, -- Enchant Weapon - Jade Spirit
  [104430] = 74725, -- Enchant Weapon - Elemental Force
  [104434] = 74726, -- Enchant Weapon - Dancing Steel
  [104442] = 74728, -- Enchant Weapon - River's Song
  [104445] = 74729, -- Enchant Off-Hand - Major Intellect
  [130758] = 89737, -- Enchant Shield - Greater Parry
  [142468] = 98163, -- Enchant Weapon - Bloody Dancing Steel
  [142469] = 98164, -- Enchant Weapon - Spirit of Conquest
  [359639] = 187737, -- Enchant Bracer - Assault
  [359640] = 187738, -- Enchant Cloak - Stealth
  [359641] = 187739, -- Enchant Gloves - Superior Agility
  [359642] = 187740, -- Enchant Weapon - Mighty Spirit
  [359685] = 187783, -- Enchant Shield - Resistance
  [359895] = 187814, -- Enchant Shield - Frost Resistance
  [359949] = 187807, -- Enchant Cloak - Greater Nature Resistance
  [359950] = 187815, -- Enchant Cloak - Greater Fire Resistance
}

-- Mapping from item-link enchant effectId -> spellId.
WSGH.Data.EnchantEffectToSpellMap = {
  [36] = 6297, -- Enchant: Fiery Blaze
  [37] = 43588, -- Weapon Chain
  [43] = 9784, -- Iron Shield Spike
  [44] = 7445, -- Enchant Chest - Minor Absorption
  [463] = 9782, -- Mithril Shield Spike
  [464] = 7215, -- Mithril Spurs
  [803] = 13897, -- Enchant Weapon - Fiery Weapon
  [844] = 13611, -- Enchant Gloves - Mining
  [845] = 13614, -- Enchant Gloves - Herbalism
  [846] = 71691, -- Eternium Fishing Line
  [865] = 13697, -- Enchant Gloves - Skinning
  [906] = 13838, -- Enchant Gloves - Advanced Mining
  [909] = 13839, -- Enchant Gloves - Advanced Herbalism
  [910] = 359640, -- Enchant Cloak - Stealth
  [911] = 13889, -- Enchant Boots - Minor Speed
  [912] = 13907, -- Enchant Weapon - Demonslaying
  [926] = 359895, -- Enchant Shield - Frost Resistance
  [930] = 13927, -- Enchant Gloves - Riding Skill
  [1593] = 359639, -- Enchant Bracer - Assault
  [1704] = 16624, -- Thorium Shield Spike
  [1894] = 20005, -- Enchant Weapon - Icy Chill
  [1898] = 20004, -- Enchant Weapon - Lifestealing
  [1899] = 20006, -- Enchant Weapon - Unholy Weapon
  [1900] = 20007, -- Enchant Weapon - Crusader
  [2564] = 359641, -- Enchant Gloves - Superior Agility
  [2567] = 359642, -- Enchant Weapon - Mighty Spirit
  [2603] = 24303, -- Enchant Gloves - Fishing
  [2613] = 25063, -- Enchant Gloves - Threat
  [2619] = 359950, -- Enchant Cloak - Greater Fire Resistance
  [2620] = 359949, -- Enchant Cloak - Greater Nature Resistance
  [2621] = 25070, -- Enchant Cloak - Subtlety
  [2673] = 28093, -- Enchant Weapon - Mongoose
  [2674] = 27997, -- Enchant Weapon - Spellsurge
  [2675] = 28005, -- Enchant Weapon - Battlemaster
  [3228] = 44119, -- Enchant Bracer - Template
  [3229] = 359685, -- Enchant Shield - Resistance
  [3238] = 44507, -- Enchant Gloves - Gatherer
  [3239] = 44525, -- Enchant Weapon - Icebreaker
  [3241] = 44578, -- Enchant Weapon - Lifeward
  [3251] = 44622, -- Enchant Weapon - Giant Slayer
  [3269] = 45698, -- Truesilver Fishing Line
  [3273] = 46579, -- Enchant Weapon - Deathfrost
  [3289] = 48555, -- Skybreaker Whip
  [3315] = 48401, -- Carrot on a Stick
  [3365] = 53387, -- Rune of Swordshattering
  [3366] = 56903, -- Rune of Lichbane
  [3367] = 53362, -- Rune of Spellshattering
  [3368] = 53365, -- Rune of the Fallen Crusader
  [3369] = 53386, -- Rune of Cinderglacier
  [3370] = 50401, -- Rune of Razorice
  [3594] = 54448, -- Rune of Swordbreaking
  [3595] = 54449, -- Rune of Spellbreaking
  [3599] = 54736, -- EMP Generator
  [3601] = 54793, -- Frag Belt
  [3603] = 54998, -- Hand-Mounted Pyro Rocket
  [3604] = 54999, -- Hyperspeed Accelerators
  [3605] = 55002, -- Flexweave Underlay
  [3722] = 55640, -- Lightweave Embroidery (Rank 1)
  [3728] = 55768, -- Darkglow Embroidery (Rank 1)
  [3730] = 55776, -- Swordguard Embroidery (Rank 1)
  [3748] = 56355, -- Titanium Shield Spike
  [3789] = 59620, -- Enchant Weapon - Berserking
  [3790] = 59630, -- Enchant Weapon - Black Magic
  [3847] = 62157, -- Rune of the Stoneskin Gargoyle
  [3860] = 63770, -- Reticulated Armor Webbing
  [3869] = 64440, -- Enchant Weapon - Blade Ward
  [3870] = 64571, -- Enchant Weapon - Blood Draining
  [3883] = 70163, -- Rune of the Nerubian Carapace
  [4061] = 74132, -- Enchant Gloves - Mastery
  [4062] = 24090, -- Enchant Boots - Earthen Vitality
  [4063] = 74190, -- Enchant Chest - Mighty Stats
  [4064] = 74192, -- Enchant Cloak - Lesser Power
  [4065] = 74193, -- Enchant Bracer - Speed
  [4066] = 74194, -- Enchant Weapon - Mending
  [4067] = 74196, -- Enchant Weapon - Avalanche
  [4068] = 74198, -- Enchant Gloves - Haste
  [4069] = 74199, -- Enchant Boots - Haste
  [4070] = 74200, -- Enchant Chest - Stamina
  [4071] = 74201, -- Enchant Bracer - Critical Strike
  [4072] = 74202, -- Enchant Cloak - Intellect
  [4073] = 74207, -- Enchant Shield - Protection
  [4074] = 74208, -- Enchant Weapon - Elemental Slayer
  [4075] = 74212, -- Enchant Gloves - Exceptional Strength
  [4076] = 74213, -- Enchant Boots - Major Agility
  [4077] = 74214, -- Enchant Chest - Mighty Resilience
  [4078] = 74215, -- Enchant Ring - Strength
  [4079] = 74216, -- Enchant Ring - Agility
  [4080] = 74217, -- Enchant Ring - Intellect
  [4081] = 74218, -- Enchant Ring - Stamina
  [4082] = 74220, -- Enchant Gloves - Greater Expertise
  [4083] = 74221, -- Enchant Weapon - Hurricane
  [4084] = 95653, -- Enchant Weapon - Heartsong
  [4085] = 74226, -- Enchant Shield - Mastery
  [4086] = 74229, -- Enchant Bracer - Superior Dodge
  [4087] = 74230, -- Enchant Cloak - Critical Strike
  [4088] = 74231, -- Enchant Chest - Exceptional Spirit
  [4089] = 74232, -- Enchant Bracer - Precision
  [4090] = 74234, -- Enchant Cloak - Protection
  [4091] = 74235, -- Enchant Off-Hand - Superior Intellect
  [4092] = 74236, -- Enchant Boots - Precision
  [4093] = 74237, -- Enchant Bracer - Exceptional Spirit
  [4094] = 74238, -- Enchant Boots - Mastery
  [4095] = 74239, -- Enchant Bracer - Greater Expertise
  [4096] = 74240, -- Enchant Cloak - Greater Intellect
  [4097] = 94746, -- Enchant Weapon - Power Torrent
  [4098] = 74243, -- Enchant Weapon - Windwalk
  [4099] = 74245, -- Enchant Weapon - Landslide
  [4100] = 74247, -- Enchant Cloak - Greater Critical Strike
  [4101] = 74248, -- Enchant Bracer - Greater Critical Strike
  [4102] = 74249, -- Enchant Chest - Peerless Stats
  [4103] = 74251, -- Enchant Chest - Greater Stamina
  [4104] = 24090, -- Enchant Boots - Lavawalker
  [4105] = 24090, -- Enchant Boots - Assassin's Step
  [4106] = 74254, -- Enchant Gloves - Mighty Strength
  [4107] = 74255, -- Enchant Gloves - Greater Mastery
  [4108] = 74256, -- Enchant Bracer - Greater Speed
  [4109] = 75149, -- Ghostly Spellthread
  [4110] = 75150, -- Powerful Ghostly Spellthread
  [4111] = 75151, -- Enchanted Spellthread
  [4112] = 75152, -- Powerful Enchanted Spellthread
  [4113] = 75154, -- Master's Spellthread (Rank 2)
  [4114] = 75155, -- Sanctified Spellthread (Rank 2)
  [4115] = 75171, -- Lightweave Embroidery (Rank 2)
  [4116] = 75174, -- Darkglow Embroidery (Rank 2)
  [4118] = 75177, -- Swordguard Embroidery (Rank 2)
  [4120] = 78165, -- Savage Armor Kit
  [4121] = 78166, -- Heavy Savage Armor Kit
  [4124] = 78170, -- Twilight Leg Armor
  [4126] = 78171, -- Dragonscale Leg Armor
  [4127] = 78172, -- Charscale Leg Armor
  [4175] = 95713, -- Gnomish X-Ray Scope
  [4179] = 1250229, -- Synapse Springs (Mark I)
  [4180] = 82177, -- Quickflip Deflection Plates
  [4181] = 82180, -- Tazik Shocker
  [4187] = 84424, -- Invisibility Field
  [4188] = 84427, -- Grounded Plasma Shield
  [4189] = 85007, -- Fur Lining - Stamina (Rank 2)
  [4190] = 85008, -- Fur Lining - Agility (Rank 2)
  [4191] = 85009, -- Fur Lining - Strength (Rank 2)
  [4192] = 85010, -- Fur Lining - Intellect (Rank 2)
  [4193] = 86375, -- Swiftsteel Inscription
  [4194] = 86401, -- Lionsmane Inscription
  [4195] = 86402, -- Inscription of the Earth Prince
  [4196] = 86403, -- Felfire Inscription
  [4197] = 86847, -- Inscription of Unbreakable Quartz
  [4198] = 86854, -- Greater Inscription of Unbreakable Quartz
  [4199] = 86898, -- Inscription of Charged Lodestone
  [4200] = 86899, -- Greater Inscription of Charged Lodestone
  [4201] = 86900, -- Inscription of Jagged Stone
  [4202] = 86901, -- Greater Inscription of Jagged Stone
  [4204] = 86907, -- Greater Inscription of Shattered Crystal
  [4205] = 86909, -- Inscription of Shattered Crystal
  [4214] = 84425, -- Cardboard Assassin
  [4215] = 92432, -- Elementium Shield Spike
  [4216] = 92436, -- Pyrium Shield Spike
  [4217] = 43588, -- Pyrium Weapon Chain
  [4222] = 67839, -- Mind Amplification Dish
  [4223] = 55016, -- Nitro Boosts
  [4227] = 95471, -- Enchant 2H Weapon - Mighty Agility
  [4248] = 96249, -- Greater Inscription of Vicious Intellect
  [4249] = 96250, -- Greater Inscription of Vicious Strength
  [4250] = 96251, -- Greater Inscription of Vicious Agility
  [4256] = 96261, -- Enchant Bracer - Major Strength
  [4257] = 96262, -- Enchant Bracer - Mighty Intellect
  [4258] = 96264, -- Enchant Bracer - Agility
  [4259] = 96285, -- Reinforced Fishing Line
  [4267] = 99622, -- Flintlocke's Woodchucker
  [4270] = 101598, -- Drakehide Leg Armor
  [4359] = 103461, -- Enchant Ring - Greater Agility
  [4360] = 103462, -- Enchant Ring - Greater Intellect
  [4361] = 103463, -- Enchant Ring - Greater Stamina
  [4411] = 104338, -- Enchant Bracer - Mastery
  [4412] = 104385, -- Enchant Bracer - Major Dodge
  [4414] = 104389, -- Enchant Bracer - Super Intellect
  [4415] = 104390, -- Enchant Bracer - Exceptional Strength
  [4416] = 104391, -- Enchant Bracer - Greater Agility
  [4417] = 104392, -- Enchant Chest - Super Resilience
  [4418] = 104393, -- Enchant Chest - Mighty Spirit
  [4419] = 104395, -- Enchant Chest - Glorious Stats
  [4420] = 104397, -- Enchant Chest - Superior Stamina
  [4421] = 104398, -- Enchant Cloak - Accuracy
  [4422] = 104401, -- Enchant Cloak - Greater Protection
  [4423] = 104403, -- Enchant Cloak - Superior Intellect
  [4424] = 104404, -- Enchant Cloak - Superior Critical Strike
  [4426] = 104407, -- Enchant Boots - Greater Haste
  [4427] = 104408, -- Enchant Boots - Greater Precision
  [4428] = 104409, -- Enchant Boots - Blurred Speed
  [4429] = 104414, -- Enchant Boots - Pandaren's Step
  [4430] = 104416, -- Enchant Gloves - Greater Haste
  [4431] = 104417, -- Enchant Gloves - Superior Expertise
  [4432] = 104419, -- Enchant Gloves - Super Strength
  [4433] = 104420, -- Enchant Gloves - Superior Mastery
  [4434] = 104445, -- Enchant Off-Hand - Major Intellect
  [4441] = 104425, -- Enchant Weapon - Windsong
  [4442] = 104427, -- Enchant Weapon - Jade Spirit
  [4443] = 104430, -- Enchant Weapon - Elemental Force
  [4444] = 104434, -- Enchant Weapon - Dancing Steel
  [4445] = 104040, -- Enchant Weapon - Colossus
  [4446] = 104442, -- Enchant Weapon - River's Song
  [4697] = 108789, -- Phase Fingers
  [4698] = 109077, -- Incendiary Fireworks Launcher
  [4699] = 109085, -- Lord Blastington's Scope of Doom
  [4700] = 109092, -- Mirror Scope
  [4719] = 113011, -- Inscription
  [4732] = 71691, -- Enchant Gloves - Angler
  [4750] = 82200, -- Spinal Healing Injector
  [4803] = 121192, -- Greater Tiger Fang Inscription
  [4804] = 121193, -- Greater Tiger Claw Inscription
  [4805] = 121194, -- Greater Ox Horn Inscription
  [4806] = 121195, -- Greater Crane Wing Inscription
  [4807] = 103465, -- Enchant Ring - Greater Strength
  [4822] = 122387, -- Shadowleather Leg Armor
  [4823] = 122388, -- Angerhide Leg Armor
  [4824] = 122386, -- Ironscale Leg Armor
  [4825] = 122392, -- Greater Cerulean Spellthread
  [4826] = 122393, -- Greater Pearlescent Spellthread
  [4869] = 124091, -- Sha Armor Kit
  [4870] = 124116, -- Toughened Leg Armor
  [4871] = 124118, -- Sha-Touched Leg Armor
  [4872] = 124119, -- Brutal Leg Armor
  [4875] = 124551, -- Fur Lining - Agility (Rank 3)
  [4877] = 124552, -- Fur Lining - Intellect (Rank 3)
  [4878] = 124553, -- Fur Lining - Stamina (Rank 3)
  [4879] = 124554, -- Fur Lining - Strength (Rank 3)
  [4880] = 124559, -- Primal Leg Reinforcements (Rank 3)
  [4881] = 124561, -- Draconic Leg Reinforcements (Rank 3)
  [4882] = 124563, -- Heavy Leg Reinforcements (Rank 3)
  [4883] = 124564, -- Primal Leg Reinforcements (Rank 2)
  [4884] = 124565, -- Heavy Leg Reinforcements (Rank 2)
  [4885] = 124566, -- Draconic Leg Reinforcements (Rank 2)
  [4892] = 125481, -- Lightweave Embroidery (Rank 3)
  [4893] = 125482, -- Darkglow Embroidery (Rank 3)
  [4894] = 125483, -- Swordguard Embroidery (Rank 3)
  [4895] = 125496, -- Master's Spellthread (Rank 3)
  [4896] = 125497, -- Sanctified Spellthread (Rank 3)
  [4897] = 126392, -- Goblin Glider
  [4898] = 126731, -- Synapse Springs (Mark II)
  [4907] = 127015, -- Tiger Fang Inscription
  [4908] = 127014, -- Tiger Claw Inscription
  [4909] = 127013, -- Crane Wing Inscription
  [4910] = 127012, -- Ox Horn Inscription
  [4912] = 113048, -- Secret Ox Horn Inscription
  [4913] = 113047, -- Secret Tiger Fang Inscription
  [4914] = 113046, -- Secret Tiger Claw Inscription
  [4915] = 113045, -- Secret Crane Wing Inscription
  [4918] = 43588, -- Living Steel Weapon Chain
  [4993] = 130758, -- Enchant Shield - Greater Parry
  [5000] = 109099, -- Watergliding Jets
  [5001] = 131465, -- Ghost Iron Shield Spike
  [5003] = 131862, -- Cerulean Spellthread
  [5004] = 131863, -- Pearlescent Spellthread
  [5035] = 43588, -- Enchant Weapon - Glorious Tyranny
  [5124] = 142469, -- Enchant Weapon - Spirit of Conquest
  [5125] = 142468, -- Enchant Weapon - Bloody Dancing Steel
  [8550] = 43588, -- Enchant Weapon - Tyranny
}

WSGH.Data.TinkerSpellIds = {
  [54736] = true, -- EMP Generator
  [54793] = true, -- Frag Belt
  [54998] = true, -- Hand-Mounted Pyro Rocket
  [54999] = true, -- Hyperspeed Accelerators
  [55002] = true, -- Flexweave Underlay
  [55016] = true, -- Nitro Boosts
  [63770] = true, -- Reticulated Armor Webbing
  [67839] = true, -- Mind Amplification Dish
  [82177] = true, -- Quickflip Deflection Plates
  [82180] = true, -- Tazik Shocker
  [82200] = true, -- Spinal Healing Injector
  [84424] = true, -- Invisibility Field
  [84425] = true, -- Cardboard Assassin
  [84427] = true, -- Grounded Plasma Shield
  [108789] = true, -- Phase Fingers
  [109077] = true, -- Incendiary Fireworks Launcher
  [109099] = true, -- Watergliding Jets
  [126392] = true, -- Goblin Glider
  [126731] = true, -- Synapse Springs (Mark II)
  [1250229] = true, -- Synapse Springs (Mark I)
}

-- Enchants applied via non-vellum consumables (e.g., armor kits, inscriptions).
WSGH.Data.EnchantConsumableMap = {
  [6297] = 5421, -- Enchant: Fiery Blaze
  [7215] = 7969, -- Mithril Spurs
  [9782] = 7967, -- Mithril Shield Spike
  [9784] = 6042, -- Iron Shield Spike
  [16624] = 12645, -- Thorium Shield Spike
  [43588] = 86597, -- Living Steel Weapon Chain
  [45698] = 34836, -- Truesilver Fishing Line
  [48401] = 37312, -- Carrot on a Stick
  [54736] = 40776, -- EMP Generator
  [54793] = 40800, -- Frag Belt
  [54998] = 41091, -- Hand-Mounted Pyro Rocket
  [55002] = 41111, -- Flexweave Underlay
  [55016] = 41118, -- Nitro Boosts
  [56355] = 42500, -- Titanium Shield Spike
  [71691] = 19971, -- Eternium Fishing Line
  [75149] = 54449, -- Ghostly Spellthread
  [75150] = 54450, -- Powerful Ghostly Spellthread
  [75151] = 54447, -- Enchanted Spellthread
  [75152] = 54448, -- Powerful Enchanted Spellthread
  [78165] = 56477, -- Savage Armor Kit
  [78166] = 56517, -- Heavy Savage Armor Kit
  [78170] = 56503, -- Twilight Leg Armor
  [78171] = 56550, -- Dragonscale Leg Armor
  [78172] = 56551, -- Charscale Leg Armor
  [86847] = 62321, -- Inscription of Unbreakable Quartz
  [86854] = 62333, -- Greater Inscription of Unbreakable Quartz
  [86898] = 62342, -- Inscription of Charged Lodestone
  [86899] = 62343, -- Greater Inscription of Charged Lodestone
  [86900] = 62344, -- Inscription of Jagged Stone
  [86901] = 62345, -- Greater Inscription of Jagged Stone
  [86907] = 62346, -- Greater Inscription of Shattered Crystal
  [86909] = 62347, -- Inscription of Shattered Crystal
  [92432] = 55055, -- Elementium Shield Spike
  [92436] = 55056, -- Pyrium Shield Spike
  [95713] = 59594, -- Gnomish X-Ray Scope
  [96249] = 68772, -- Greater Inscription of Vicious Intellect
  [96250] = 68773, -- Greater Inscription of Vicious Strength
  [96251] = 68774, -- Greater Inscription of Vicious Agility
  [96285] = 68796, -- Reinforced Fishing Line
  [99622] = 70139, -- Flintlocke's Woodchucker
  [101598] = 71720, -- Drakehide Leg Armor
  [109085] = 77529, -- Lord Blastington's Scope of Doom
  [109092] = 77531, -- Mirror Scope
  [109099] = 87748, -- Watergliding Jets
  [113045] = 87582, -- Secret Crane Wing Inscription
  [113046] = 87584, -- Secret Tiger Claw Inscription
  [113047] = 87585, -- Secret Tiger Fang Inscription
  [113048] = 87581, -- Secret Ox Horn Inscription
  [121192] = 83006, -- Greater Tiger Fang Inscription
  [121193] = 83007, -- Greater Tiger Claw Inscription
  [121194] = 87560, -- Greater Ox Horn Inscription
  [121195] = 87559, -- Greater Crane Wing Inscription
  [122386] = 83763, -- Ironscale Leg Armor
  [122387] = 83764, -- Shadowleather Leg Armor
  [122388] = 83765, -- Angerhide Leg Armor
  [122392] = 82445, -- Greater Cerulean Spellthread
  [122393] = 82444, -- Greater Pearlescent Spellthread
  [124091] = 85559, -- Sha Armor Kit
  [124116] = 85570, -- Toughened Leg Armor
  [124118] = 85569, -- Sha-Touched Leg Armor
  [124119] = 85568, -- Brutal Leg Armor
  [127012] = 87577, -- Ox Horn Inscription
  [127013] = 87578, -- Crane Wing Inscription
  [127014] = 87579, -- Tiger Claw Inscription
  [127015] = 87580, -- Tiger Fang Inscription
  [131465] = 86599, -- Ghost Iron Shield Spike
  [131862] = 82443, -- Cerulean Spellthread
  [131863] = 82442, -- Pearlescent Spellthread
}

-- Enchants that cannot be applied via vellum/scroll (e.g., rings, runeforges).
WSGH.Data.EnchantManualOnly = {
  [24303] = true, -- Enchant Gloves - Fishing
  [44119] = true, -- Enchant Bracer - Template
  [48555] = true, -- Skybreaker Whip
  [50401] = true, -- Rune of Razorice
  [53362] = true, -- Rune of Spellshattering
  [53365] = true, -- Rune of the Fallen Crusader
  [53386] = true, -- Rune of Cinderglacier
  [53387] = true, -- Rune of Swordshattering
  [54448] = true, -- Rune of Swordbreaking
  [54449] = true, -- Rune of Spellbreaking
  [54999] = true, -- Hyperspeed Accelerators
  [55640] = true, -- Lightweave Embroidery (Rank 1)
  [55768] = true, -- Darkglow Embroidery (Rank 1)
  [55776] = true, -- Swordguard Embroidery (Rank 1)
  [56903] = true, -- Rune of Lichbane
  [62157] = true, -- Rune of the Stoneskin Gargoyle
  [63770] = true, -- Reticulated Armor Webbing
  [67839] = true, -- Mind Amplification Dish
  [70163] = true, -- Rune of the Nerubian Carapace
  [74215] = true, -- Enchant Ring - Strength
  [74216] = true, -- Enchant Ring - Agility
  [74217] = true, -- Enchant Ring - Intellect
  [74218] = true, -- Enchant Ring - Stamina
  [75154] = true, -- Master's Spellthread (Rank 2)
  [75155] = true, -- Sanctified Spellthread (Rank 2)
  [75171] = true, -- Lightweave Embroidery (Rank 2)
  [75174] = true, -- Darkglow Embroidery (Rank 2)
  [75177] = true, -- Swordguard Embroidery (Rank 2)
  [82177] = true, -- Quickflip Deflection Plates
  [82180] = true, -- Tazik Shocker
  [82200] = true, -- Spinal Healing Injector
  [84424] = true, -- Invisibility Field
  [84425] = true, -- Cardboard Assassin
  [84427] = true, -- Grounded Plasma Shield
  [85007] = true, -- Fur Lining - Stamina (Rank 2)
  [85008] = true, -- Fur Lining - Agility (Rank 2)
  [85009] = true, -- Fur Lining - Strength (Rank 2)
  [85010] = true, -- Fur Lining - Intellect (Rank 2)
  [86375] = true, -- Swiftsteel Inscription
  [86401] = true, -- Lionsmane Inscription
  [86402] = true, -- Inscription of the Earth Prince
  [86403] = true, -- Felfire Inscription
  [103461] = true, -- Enchant Ring - Greater Agility
  [103462] = true, -- Enchant Ring - Greater Intellect
  [103463] = true, -- Enchant Ring - Greater Stamina
  [103465] = true, -- Enchant Ring - Greater Strength
  [108789] = true, -- Phase Fingers
  [109077] = true, -- Incendiary Fireworks Launcher
  [113011] = true, -- Inscription
  [124551] = true, -- Fur Lining - Agility (Rank 3)
  [124552] = true, -- Fur Lining - Intellect (Rank 3)
  [124553] = true, -- Fur Lining - Stamina (Rank 3)
  [124554] = true, -- Fur Lining - Strength (Rank 3)
  [124559] = true, -- Primal Leg Reinforcements (Rank 3)
  [124561] = true, -- Draconic Leg Reinforcements (Rank 3)
  [124563] = true, -- Heavy Leg Reinforcements (Rank 3)
  [124564] = true, -- Primal Leg Reinforcements (Rank 2)
  [124565] = true, -- Heavy Leg Reinforcements (Rank 2)
  [124566] = true, -- Draconic Leg Reinforcements (Rank 2)
  [125481] = true, -- Lightweave Embroidery (Rank 3)
  [125482] = true, -- Darkglow Embroidery (Rank 3)
  [125483] = true, -- Swordguard Embroidery (Rank 3)
  [125496] = true, -- Master's Spellthread (Rank 3)
  [125497] = true, -- Sanctified Spellthread (Rank 3)
  [126392] = true, -- Goblin Glider
  [126731] = true, -- Synapse Springs (Mark II)
  [1250229] = true, -- Synapse Springs (Mark I)
}

local Enchants = {}

function Enchants.NormalizeEffectId(effectId)
  effectId = tonumber(effectId) or 0
  if effectId == 0 then return 0, true end

  local map = WSGH.Data.EnchantEffectToSpellMap or {}
  local mapped = map[effectId]
  if mapped then
    return mapped, true
  end

  local spellId = effectId
  local vellumMap = WSGH.Data.EnchantVellumMap or {}
  local consumableMap = WSGH.Data.EnchantConsumableMap or {}
  local manualMap = WSGH.Data.EnchantManualOnly or {}
  if vellumMap[spellId] or consumableMap[spellId] or manualMap[spellId] then
    return spellId, true
  end

  return spellId, false
end

function Enchants.GetVellumItemId(enchantId, expansionKey)
  enchantId = tonumber(enchantId) or 0
  if enchantId == 0 then return 0 end

  local map = WSGH.Data.EnchantVellumMap or {}
  return map[enchantId] or 0
end

function Enchants.IsTinkerSpell(spellId)
  spellId = tonumber(spellId) or 0
  if spellId == 0 then return false end
  local tinkerMap = WSGH.Data.TinkerSpellIds or {}
  return tinkerMap[spellId] == true
end

-- Returns itemId and source ("scroll"/"consumable") for the given enchant, or 0/nil if none.
function Enchants.GetItemForEnchant(enchantId)
  enchantId = tonumber(enchantId) or 0
  if enchantId == 0 then return 0, nil end
  if Enchants.IsTinkerSpell and Enchants.IsTinkerSpell(enchantId) then
    return 0, "tinker"
  end

  local scrollId = (WSGH.Data.EnchantVellumMap or {})[enchantId]
  if scrollId then
    return scrollId, "scroll"
  end

  local consumableId = (WSGH.Data.EnchantConsumableMap or {})[enchantId]
  if consumableId then
    return consumableId, "consumable"
  end

  return 0, nil
end

function Enchants.IsManualOnly(enchantId)
  enchantId = tonumber(enchantId) or 0
  if enchantId == 0 then return false end
  if Enchants.IsTinkerSpell and Enchants.IsTinkerSpell(enchantId) then
    return true
  end
  local manual = WSGH.Data.EnchantManualOnly or {}
  if manual[enchantId] then return true end
  local itemId = select(1, Enchants.GetItemForEnchant(enchantId))
  return itemId == 0
end

function Enchants.GetDisplayInfo(enchantId)
  enchantId = tonumber(enchantId) or 0
  if enchantId == 0 then return nil end
  local itemId, source = Enchants.GetItemForEnchant(enchantId)
  if itemId and itemId ~= 0 then
    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
    if not icon then
      icon = select(5, GetItemInfoInstant(itemId))
    end
    local spellName, _, spellIcon = GetSpellInfo(enchantId)
    return {
      spellId = enchantId,
      name = name or spellName or ("Enchant " .. enchantId),
      icon = icon or spellIcon or WSGH.Const.ICON_ENCHANT,
      itemId = itemId,
      itemSource = source,
    }
  end

  local name, _, icon = GetSpellInfo(enchantId)
  return {
    spellId = enchantId,
    name = name or ("Enchant " .. enchantId),
    icon = icon or WSGH.Const.ICON_ENCHANT,
    itemId = 0,
    itemSource = nil,
  }
end

WSGH.Data.Enchants = Enchants



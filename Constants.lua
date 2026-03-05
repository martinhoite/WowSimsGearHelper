local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Const = WSGH.Const or {}

-- WowSims export uses ordered items[]. This mapping is the backbone.
WSGH.Const.SLOT_ORDER = {
  { key = "HEAD", slotId = 1 },
  { key = "NECK", slotId = 2 },
  { key = "SHOULDER", slotId = 3 },
  { key = "BACK", slotId = 15 },
  { key = "CHEST", slotId = 5 },
  { key = "WRIST", slotId = 9 },
  { key = "HANDS", slotId = 10 },
  { key = "WAIST", slotId = 6 },
  { key = "LEGS", slotId = 7 },
  { key = "FEET", slotId = 8 },
  { key = "FINGER1", slotId = 11 },
  { key = "FINGER2", slotId = 12 },
  { key = "TRINKET1", slotId = 13 },
  { key = "TRINKET2", slotId = 14 },
  { key = "MAINHAND", slotId = 16 },
  { key = "OFFHAND", slotId = 17 },
}

-- Inverse lookup: inventory slotId -> index in SLOT_ORDER (1..16).
WSGH.Const.SLOT_INDEX_BY_ID = {}
for i, s in ipairs(WSGH.Const.SLOT_ORDER) do
  WSGH.Const.SLOT_INDEX_BY_ID[s.slotId] = i
end

-- Profession metadata used by utility helpers and profession-aware UI paths.
WSGH.Const.PROFESSIONS = {
  -- Primary professions
  ALCHEMY = {
    skillLineId = 171,
    namePattern = "alchemy",
  },
  BLACKSMITHING = {
    skillLineId = 164,
    namePattern = "blacksmith",
  },
  ENGINEERING = {
    skillLineId = 202,
    namePattern = "engineer",
  },
  ENCHANTING = {
    skillLineId = 333,
    namePattern = "enchant",
  },
  HERBALISM = {
    skillLineId = 182,
    namePattern = "herbal",
  },
  INSCRIPTION = {
    skillLineId = 773,
    namePattern = "inscript",
  },
  JEWELCRAFTING = {
    skillLineId = 755,
    namePattern = "jewel",
  },
  LEATHERWORKING = {
    skillLineId = 165,
    namePattern = "leather",
  },
  MINING = {
    skillLineId = 186,
    namePattern = "mining",
  },
  SKINNING = {
    skillLineId = 393,
    namePattern = "skinning",
  },
  TAILORING = {
    skillLineId = 197,
    namePattern = "tailor",
  },

  -- Secondary professions
  ARCHAEOLOGY = {
    skillLineId = 794,
    namePattern = "archae",
  },
  COOKING = {
    skillLineId = 185,
    namePattern = "cooking",
  },
  FISHING = {
    skillLineId = 356,
    namePattern = "fishing",
  },
  FIRST_AID = {
    skillLineId = 129,
    namePattern = "first aid",
  },
}

-- Inventory slotIds that can receive baseline enchants by expansion key.
WSGH.Const.ENCHANTABLE_SLOT_IDS_BY_EXPANSION = {
  -- MoP removed head/shoulder enchants.
  MOP = {
    [5] = true,  -- chest
    [7] = true,  -- legs
    [8] = true,  -- feet
    [9] = true,  -- wrist
    [10] = true, -- hands
    [15] = true, -- cloak
    [16] = true, -- main hand
    [17] = true, -- off hand
  },
  CATA = {
    [1] = true,  -- head
    [3] = true,  -- shoulder
    [5] = true,  -- chest
    [7] = true,  -- legs
    [8] = true,  -- feet
    [9] = true,  -- wrist
    [10] = true, -- hands
    [15] = true, -- cloak
    [16] = true, -- main hand
    [17] = true, -- off hand
  },
  WOTLK = {
    [1] = true,  -- head
    [3] = true,  -- shoulder
    [5] = true,  -- chest
    [7] = true,  -- legs
    [8] = true,  -- feet
    [9] = true,  -- wrist
    [10] = true, -- hands
    [15] = true, -- cloak
    [16] = true, -- main hand
    [17] = true, -- off hand
  },
  TBC = {
    [1] = true,  -- head
    [3] = true,  -- shoulder
    [5] = true,  -- chest
    [7] = true,  -- legs
    [8] = true,  -- feet
    [9] = true,  -- wrist
    [10] = true, -- hands
    [15] = true, -- cloak
    [16] = true, -- main hand
    [17] = true, -- off hand
  },
}

-- Fallback map when expansion key is unavailable.
WSGH.Const.ENCHANTABLE_SLOT_IDS = {
  [1] = true, [3] = true, [5] = true, [7] = true, [8] = true,
  [9] = true, [10] = true, [15] = true, [16] = true, [17] = true,
}

-- Row / socket statuses
WSGH.Const.STATUS_OK = "OK"
WSGH.Const.STATUS_EMPTY = "EMPTY"
WSGH.Const.STATUS_WRONG = "WRONG"
WSGH.Const.STATUS_MISSING = "MISSING"

-- Textures (vanilla-safe)
WSGH.Const.ICON_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
WSGH.Const.ICON_NOTREADY = "Interface\\RaidFrame\\ReadyCheck-NotReady"
WSGH.Const.ICON_QUESTION = "Interface\\RaidFrame\\ReadyCheck-Waiting"
WSGH.Const.ICON_PURCHASE = "Interface\\MINIMAP\\TRACKING\\Auctioneer"
WSGH.Const.ICON_SEARCH = "Interface\\Common\\UI-Searchbox-Icon"
WSGH.Const.ICON_ENCHANT = "Interface\\Icons\\inv_misc_enchantedscroll"
WSGH.Const.ICON_TINKER = "Interface\\Icons\\Trade_Engineering"
WSGH.Const.ICON_WARNING = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertOther"

-- Default tinker spellIds by slot (MoP defaults).
WSGH.Const.DEFAULT_TINKERS = {
  [6] = 55016,   -- Belt: Nitro Boosts
  [15] = 126392, -- Cloak: Goblin Glider
  [10] = 126731, -- Gloves: Synapse Springs
}
WSGH.Const.HIGHLIGHT = {
  style = "glow",
  color = { 1, 0.8, 0.1 },
  numberColor = { 1, 0.9, 0.2 },
  styles = {
    { text = "Label only", value = "label" },
    { text = "Action button glow", value = "glow" },
    { text = "Autocast shine", value = "autocast" },
  },
}

WSGH.Const.ICON_EMPTY_SOCKET = "Interface\\ItemSocketingFrame\\UI-EmptySocket"
WSGH.Const.TINKERS_KIT_ITEM_ID = 90146
WSGH.Const.JUSTICE_POINTS_CURRENCY_ID = 395
WSGH.Const.JUSTICE_POINTS_COMMENDATION_ITEM_ID = 256883
WSGH.Const.JUSTICE_POINTS_PER_UPGRADE_STEP = 1000
WSGH.Const.VALOR_POINTS_CURRENCY_ID = 396
WSGH.Const.VALOR_POINTS_COMMENDATION_ITEM_ID = 0
WSGH.Const.VALOR_POINTS_PER_UPGRADE_STEP = 250
WSGH.Const.VALOR_POINTS_PER_JP_COMMENDATION = 125
WSGH.Const.JUSTICE_POINTS_PER_COMMENDATION_NON_GUILD = 500
WSGH.Const.JUSTICE_POINTS_PER_COMMENDATION_GUILD = 600

WSGH.Const.AUCTION_CHAT_POLL_INTERVAL_SECONDS = 0.5
WSGH.Const.AUCTION_CHAT_RESYNC_HISTORY_LINES = 80


-- Limits
WSGH.Const.MAX_SOCKETS_RENDER = 3

-- Addon-wide UI sizing (v1, tweak later)
WSGH.Const.UI = {
  width = 520,
  height = 420,
  rowHeight = 34,
  socketSize = 16,
  socketGap = 4,
  warningIconSize = 16,
  padding = 12,
  listTop = -96,
  rowRightPad = 24,
  shopping = {
    sidebarWidth = 260,
    entryHeight = 20,
    padding = 10,
    searchButton = { width = 20, height = 18 },
    searchIcon = { width = 12, height = 12 },
    categories = { "Gems", "Enchants", "Other" },
  },
}

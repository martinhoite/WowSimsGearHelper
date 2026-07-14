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

WSGH.Const.TASK_PRIORITY_TYPES = {
  {
    key = "ADD_SOCKET",
    label = "Add sockets",
    description = "Socket-addition tasks, usually Blacksmithing sockets; also covers other effects that add a socket.",
  },
  {
    key = "SOCKET_GEM",
    label = "Socket gems",
    description = "Gem tasks for empty or wrong sockets.",
  },
  {
    key = "APPLY_ENCHANT",
    label = "Apply enchants",
    description = "Standard enchant tasks from the imported plan.",
  },
  {
    key = "APPLY_TINKER",
    label = "Apply tinkers",
    description = "Engineering tinker tasks for cloak, gloves, or belt.",
  },
  {
    key = "UPGRADE_ITEM",
    label = "Upgrade items",
    description = "Item upgrade tasks using the selected currency preference.",
  },
  {
    key = "REFORGE_ITEM",
    label = "Reforge items",
    description = "Reforge tasks from the imported plan.",
    warning = "Upgrade before reforging to avoid incorrect reforge results.",
  },
}

WSGH.Const.HIGHLIGHT = {
  style = "glow",
  color = { 0.95, 0.95, 0.32 },
  numberColor = { 1, 0.95, 0.35 },
  styles = {
    { text = "Label only", value = "label" },
    { text = "Blizzard-style glow", value = "glow" },
    { text = "Autocast shine (light)", value = "autocast" },
    { text = "Autocast shine (strong)", value = "autocast_strong" },
  },
}

WSGH.Const.COLOR_ROLES = {
  {
    heading = "Buttons",
    roles = {
      { key = "button.defaultText", label = "Active action text", default = { 1, 0.82, 0, 1 }, description = "Text on enabled row action buttons such as Socket, Equip, Enchant, Upgrade, and Add socket." },
      { key = "button.reforgeText", label = "Reforge action text", default = { 1, 1, 1, 1 }, description = "Text on the Reforge* row action button." },
      { key = "button.doneText", label = "Completed action text", default = { 0.72, 0.72, 0.72, 1 }, description = "Text on disabled Done buttons for rows with no remaining tasks." },
      { key = "button.purchaseText", label = "Purchase action text", default = { 1, 0.82, 0, 1 }, description = "Text on disabled Purchase or Missing buttons when required items are not available." },
    },
  },
  {
    heading = "Window",
    roles = {
      { key = "window.background", label = "Window background", default = { 0.0235, 0.0314, 0.051, 0.88 }, description = "Backdrop color behind the main addon, import, help, and shopping windows." },
      { key = "window.reminderBackground", label = "Reminder background", default = { 0, 0, 0, 0.75 }, description = "Backdrop color for the small manual reforge reminder popup." },
      { key = "text.normal", label = "Main window text", default = { 1, 1, 1, 1 }, description = "Primary labels in the main addon window and settings controls." },
      { key = "text.secondary", label = "Secondary window text", default = { 0.8, 0.8, 0.8, 1 }, description = "Supporting text such as bylines and less prominent labels." },
      { key = "text.muted", label = "Muted window text", default = { 0.5, 0.5, 0.5, 1 }, description = "Disabled, empty, or low-emphasis text such as row subtitles and no-socket notes." },
      { key = "accent.gold", label = "Header/accent text", default = { 1, 0.82, 0, 1 }, description = "Section headings and accent labels throughout the addon UI." },
      { key = "status.warning", label = "Warning text", default = { 1, 0.82, 0.2, 1 }, description = "Warning text in rows, badges, shopping, and tooltips." },
      { key = "status.error", label = "Error text", default = { 1, 0.2, 0.2, 1 }, description = "Error text for import problems and failed states." },
    },
  },
  {
    heading = "Rows",
    roles = {
      { key = "row.defaultTitle", label = "Default row title", default = { 1, 0.82, 0, 1 }, description = "Equipped-slot row title when the row has normal pending work." },
      { key = "row.wrongItemTitle", label = "Wrong item title", default = { 1, 0.25, 0.25, 1 }, description = "Equipped-slot row title when the currently equipped item does not match the import." },
      { key = "row.upgradeTitle", label = "Upgrade row title", default = { 1, 0.62, 0.22, 1 }, description = "Equipped-slot row title when item upgrades are pending." },
      { key = "row.reforgeTitle", label = "Reforge row title", default = { 0.8, 0.62, 1, 1 }, description = "Equipped-slot row title when only reforge work remains." },
      { key = "row.subtitle", label = "Row subtitle", default = { 0.5, 0.5, 0.5, 1 }, description = "Small status text under each equipped-slot row title." },
      { key = "row.background", label = "Row background", default = { 0, 0, 0, 0.18 }, description = "Backdrop fill behind each equipped-slot row." },
      { key = "row.border", label = "Row border", default = { 0, 0, 0, 0.35 }, description = "Border around each equipped-slot row." },
    },
  },
  {
    heading = "Shopping",
    roles = {
      { key = "shopping.header", label = "Shopping headers", default = { 1, 0.82, 0, 1 }, description = "Category headings in the shopping list window." },
      { key = "shopping.itemText", label = "Shopping item text", default = { 1, 1, 1, 1 }, description = "Regular item names and counts in the shopping list." },
      { key = "shopping.completedText", label = "Shopping completed text", default = { 0.72, 0.72, 0.72, 1 }, description = "Shopping-list entries that are already purchased or satisfied." },
      { key = "shopping.warningText", label = "Shopping warning text", default = { 1, 0.2, 0.2, 1 }, description = "Warnings in the shopping list, such as missing or ambiguous purchase data." },
      { key = "shopping.reminderText", label = "Reforge reminder text", default = { 1, 0.82, 0, 1 }, description = "Text shown in the manual reforge reminder popup." },
    },
  },
  {
    heading = "Highlights",
    roles = {
      { key = "highlight.glow", label = "Highlight glow", default = { 0.95, 0.95, 0.32, 1 }, description = "Glow color around highlighted bags, items, sockets, and equipment slots." },
      { key = "highlight.number", label = "Highlight number", default = { 1, 1, 1, 1 }, description = "Number text on ordered bag/item/socket highlights." },
      { key = "highlight.numberBackground", label = "Highlight number background", default = { 0, 0, 0, 0.85 }, description = "Small backdrop behind ordered highlight numbers." },
    },
  },
  {
    heading = "Settings",
    roles = {
      { key = "settings.dragRowBackground", label = "Dragged row background", default = { 0.2, 0.32, 0.42, 0.85 }, description = "Background for a task-priority row while it is being dragged in settings." },
      { key = "settings.dragRowBorder", label = "Dragged row border", default = { 0.95, 0.85, 0.25, 1 }, description = "Border for a task-priority row while it is being dragged in settings." },
      { key = "settings.idleRowBackground", label = "Idle row background", default = { 0.03, 0.03, 0.03, 0.45 }, description = "Background for task-priority rows while they are not being dragged." },
      { key = "settings.idleRowBorder", label = "Idle row border", default = { 0.35, 0.35, 0.35, 1 }, description = "Border for task-priority rows while they are not being dragged." },
    },
  },
}

WSGH.Const.COLOR_DEFAULTS = {}
for _, colorGroup in ipairs(WSGH.Const.COLOR_ROLES) do
  for _, colorRole in ipairs(colorGroup.roles or {}) do
    if colorRole.key then
      WSGH.Const.COLOR_DEFAULTS[colorRole.key] = colorRole.default
    end
  end
end

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
  minimizedHeight = 84,
  minimizedRestoreButton = { width = 28, height = 28 },
  headerButtons = {
    closeOffset = { x = -5, y = -5 },
    collapseGap = 2,
    helpGap = 4,
  },
  rowHeight = 34,
  rowGap = 6,
  socketSize = 16,
  socketGap = 4,
  warningIconSize = 16,
  rowStatusBadgeSize = 19,
  rowStatusBadgeCompleteSize = 14,
  rowStatusBadgeOffset = { x = 0, y = -3 },
  padding = 12,
  listTop = -96,
  listBottomPadding = 18,
  rowRightPad = 24,
  shopping = {
    sidebarWidth = 260,
    entryHeight = 20,
    padding = 10,
    searchButton = { width = 20, height = 18 },
    searchIcon = { width = 12, height = 12 },
    reminder = {
      padding = 10,
      height = 34,
      actionButton = { width = 42, height = 18 },
      closeButton = { width = 18, height = 18 },
    },
    categories = { "Gems", "Enchants", "Other" },
  },
  settings = {
    scroll = {
      childWidth = 640,
      minChildHeight = 760,
      bottomPadding = 36,
      rightInset = 28,
      mouseWheelStep = 36,
    },
    taskPriority = {
      xOffset = 320,
      yOffset = -8,
      width = 250,
      rowHeight = 28,
      rowGap = 4,
      labelGap = 4,
      rowTopOffset = -58,
      rankWidth = 24,
      rankOffsetX = 8,
      labelOffsetX = 8,
      noteHeight = 32,
      resetButton = { width = 64, height = 20, yOffset = 2 },
      backdrop = {
        tileSize = 16,
        edgeSize = 10,
        inset = 2,
      },
    },
    colors = {
      width = 560,
      height = 820,
      contentHeight = 800,
      noteWidth = 520,
      preview = { width = 540, height = 44, yOffset = -34 },
      openWindowButton = { width = 92, height = 20, xOffset = -118, yOffset = 2 },
      resetAllButton = { width = 104, height = 20, xOffset = -8, yOffset = 2 },
      row = {
        topOffset = -98,
        headingGap = 20,
        rowHeight = 24,
        groupGap = 4,
        labelX = 8,
        labelYOffset = -2,
        labelWidth = 170,
        helpX = 166,
        helpYOffset = -3,
        helpWidth = 14,
        helpHeight = 14,
        swatchX = 184,
        swatchWidth = 22,
        swatchHeight = 18,
        dropdownOffsetX = -10,
        dropdownOffsetY = 2,
        dropdownWidth = 112,
        resetOffsetX = -6,
        resetOffsetY = 2,
        resetWidth = 44,
        resetHeight = 20,
      },
    },
  },
  help = {
    iconButton = { width = 18, height = 18 },
    textButton = { width = 56, height = 20 },
    dialog = {
      width = 620,
      height = 420,
      padding = 18,
      topOffset = 40,
    },
    quickWidth = 560,
  },
}

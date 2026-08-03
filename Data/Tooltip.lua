local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Data = WSGH.Data or {}

-- Fallback labels used by Scan/Tooltip.lua when Blizzard's localized upgrade
-- format string is unavailable. Non-ASCII labels preserve in-game casing.
WSGH.Data.UpgradeLevelLabelsByLocale = {
  enUS = { "Upgrade Level" },
  enGB = { "Upgrade Level" },
  ruRU = { "Уровень улучшения" },
}

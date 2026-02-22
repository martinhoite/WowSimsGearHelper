local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Scan = WSGH.Scan or {}
WSGH.Scan.Tooltip = WSGH.Scan.Tooltip or {}

local TOOLTIP_NAME = "WSGHScanTooltip"
local MAX_TOOLTIP_LINES = 30

local scanner
local socketLineSet
local tinkerCache
local ReadTooltipLines
local lastPopulateDebug

local function NormalizeText(text)
  if type(text) ~= "string" then return "" end
  local lowered = (WSGH.Util and WSGH.Util.SafeLower and WSGH.Util.SafeLower(text)) or text:lower()
  lowered = lowered:gsub("%d+", "")
  lowered = lowered:gsub("[%(%)]", " ")
  lowered = lowered:gsub("[%c%p]", " ")
  lowered = lowered:gsub("%s+", " ")
  if WSGH.Util and WSGH.Util.Trim then
    return WSGH.Util.Trim(lowered)
  end
  return (lowered:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function StartsWith(text, prefix)
  if type(text) ~= "string" or type(prefix) ~= "string" then return false end
  if prefix == "" then return false end
  return text:sub(1, #prefix) == prefix
end

local function AddNormalizedPhrase(entry, text)
  if type(entry) ~= "table" then return end
  local norm = NormalizeText(text)
  if norm == "" then return end
  if not entry.phraseSet[norm] then
    entry.phraseSet[norm] = true
    entry.phrases[#entry.phrases + 1] = norm
  end

  local usePrefix = NormalizeText(ITEM_SPELL_TRIGGER_ONUSE or "Use:")
  if usePrefix ~= "" and StartsWith(norm, usePrefix) then
    local stripped = NormalizeText(norm:sub(#usePrefix + 1))
    if stripped ~= "" and not entry.phraseSet[stripped] then
      entry.phraseSet[stripped] = true
      entry.phrases[#entry.phrases + 1] = stripped
    end
  end
end

local function AddConfiguredTinkerPhrases(entry, spellId)
  if type(entry) ~= "table" then return end
  spellId = tonumber(spellId) or 0
  if spellId == 0 then return end

  local locale = (type(GetLocale) == "function" and GetLocale()) or "enUS"
  local config = WSGH.Data and WSGH.Data.TinkerTooltipTextByLocale or nil
  if type(config) ~= "table" then return end

  local function AddBucket(bucket)
    if type(bucket) ~= "table" then return end
    local phrases = bucket[spellId]
    if type(phrases) == "string" then
      AddNormalizedPhrase(entry, phrases)
      return
    end
    if type(phrases) ~= "table" then return end
    for _, phrase in ipairs(phrases) do
      AddNormalizedPhrase(entry, phrase)
    end
  end

  AddBucket(config[locale])
  if locale ~= "enUS" then
    AddBucket(config.enUS)
  end
  AddBucket(config.default)
end

local function EnsureScanner()
  if scanner then return scanner end
  local tip = CreateFrame("GameTooltip", TOOLTIP_NAME, UIParent, "GameTooltipTemplate")
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:Hide()
  scanner = tip
  return scanner
end

local function PopulateTooltipForInventoryItem(tip, unit, slotId)
  if not tip or not tip.ClearLines then return false end
  lastPopulateDebug = {
    unit = unit,
    slotId = slotId,
    setInventoryCallOk = false,
    setInventoryResult = nil,
    usedHyperlinkFallback = false,
    setHyperlinkCallOk = false,
    setHyperlinkResult = nil,
    numLines = 0,
  }
  if tip.SetOwner then
    tip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  tip:ClearLines()

  local ok = false
  if tip.SetInventoryItem then
    local callOk, result = pcall(tip.SetInventoryItem, tip, unit, slotId)
    lastPopulateDebug.setInventoryCallOk = callOk
    lastPopulateDebug.setInventoryResult = result
    ok = callOk and true or false
  end

  if tip.Show then
    tip:Show()
  end
  if tip.NumLines then
    lastPopulateDebug.numLines = tonumber(tip:NumLines()) or 0
  end

  -- Fallback path: if inventory binding produced no lines, try explicit link.
  if (not ok or (tip.NumLines and tip:NumLines() == 0)) and GetInventoryItemLink and tip.SetHyperlink then
    local link = GetInventoryItemLink(unit, slotId)
    if link and link ~= "" then
      lastPopulateDebug.usedHyperlinkFallback = true
      tip:ClearLines()
      local callOk, result = pcall(tip.SetHyperlink, tip, link)
      lastPopulateDebug.setHyperlinkCallOk = callOk
      lastPopulateDebug.setHyperlinkResult = result
      ok = callOk or ok
      if tip.Show then
        tip:Show()
      end
      if tip.NumLines then
        lastPopulateDebug.numLines = tonumber(tip:NumLines()) or 0
      end
    end
  end

  return ok
end

local function ReadTooltipLinesFromData(data)
  local out = {}
  if type(data) ~= "table" then return out end
  if TooltipUtil and TooltipUtil.SurfaceArgs then
    pcall(TooltipUtil.SurfaceArgs, data)
  end
  local lines = data.lines
  if type(lines) ~= "table" then return out end
  for _, line in ipairs(lines) do
    if type(line) == "table" then
      local left = line.leftText
      if type(left) == "string" and left ~= "" then
        out[#out + 1] = left
      end
    end
  end
  return out
end

local function ReadTooltipLinesForInventoryItem(unit, slotId)
  if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slotId)
    if ok and type(data) == "table" then
      local dataLines = ReadTooltipLinesFromData(data)
      if #dataLines > 0 then
        return dataLines, "tooltipinfo"
      end
    end
  end

  local tip = EnsureScanner()
  if not tip then return {}, "none" end
  local populated = PopulateTooltipForInventoryItem(tip, unit, slotId)
  if not populated then
    return {}, "frame"
  end
  return ReadTooltipLines(), "frame"
end

local function BuildSocketLineSet()
  if socketLineSet then return socketLineSet end
  local lines = {
    _G.EMPTY_SOCKET_RED,
    _G.EMPTY_SOCKET_YELLOW,
    _G.EMPTY_SOCKET_BLUE,
    _G.EMPTY_SOCKET_META,
    _G.EMPTY_SOCKET_PRISMATIC,
  }
  if not _G.EMPTY_SOCKET_PRISMATIC then
    lines[#lines + 1] = "Prismatic Socket"
  end
  if not _G.EMPTY_SOCKET_META then
    lines[#lines + 1] = "Meta Socket"
  end
  if not _G.EMPTY_SOCKET_RED then
    lines[#lines + 1] = "Red Socket"
  end
  if not _G.EMPTY_SOCKET_YELLOW then
    lines[#lines + 1] = "Yellow Socket"
  end
  if not _G.EMPTY_SOCKET_BLUE then
    lines[#lines + 1] = "Blue Socket"
  end

  socketLineSet = {}
  for _, line in ipairs(lines) do
    if type(line) == "string" and line ~= "" then
      local key = (WSGH.Util and WSGH.Util.Trim and WSGH.Util.Trim(line)) or line
      socketLineSet[key] = true
    end
  end

  return socketLineSet
end

local function EnsureTinkerCache()
  if tinkerCache then return tinkerCache end
  local cache = {}
  local entriesBySpellId = {}
  local tinkerMap = WSGH.Data and WSGH.Data.TinkerSpellIds or {}
  local function EnsureEntry(spellId)
    spellId = tonumber(spellId) or 0
    if spellId == 0 then return nil end
    local entry = entriesBySpellId[spellId]
    if not entry then
      entry = {
        spellId = spellId,
        phrases = {},
        phraseSet = {},
      }
      entriesBySpellId[spellId] = entry
    end
    return entry
  end

  for key, _ in pairs(tinkerMap) do
    local spellId = 0
    if type(key) == "number" then
      spellId = tonumber(key) or 0
    end

    local entry = EnsureEntry(spellId)
    if entry then
      AddConfiguredTinkerPhrases(entry, spellId)

      -- Fallbacks: localized spell APIs may contain useful text on some clients.
      local name = GetSpellInfo(spellId)
      if name and name ~= "" then
        AddNormalizedPhrase(entry, name)
      end

      if GetSpellDescription then
        local desc = GetSpellDescription(spellId)
        if desc and desc ~= "" then
          AddNormalizedPhrase(entry, desc)
        end
      end
    end
  end

  for _, entry in pairs(entriesBySpellId) do
    if #entry.phrases > 1 then
      table.sort(entry.phrases, function(a, b)
        return #a > #b
      end)
    end
    cache[#cache + 1] = entry
  end

  tinkerCache = cache
  return cache
end

ReadTooltipLines = function()
  local lines = {}
  local tip = scanner
  if not tip then return lines end
  local seen = {}
  local function addLine(text)
    if type(text) ~= "string" or text == "" then return end
    if not seen[text] then
      seen[text] = true
      lines[#lines + 1] = text
    end
  end

  local maxLines = MAX_TOOLTIP_LINES
  if tip.NumLines then
    local count = tonumber(tip:NumLines()) or 0
    if count > 0 then
      maxLines = math.min(MAX_TOOLTIP_LINES, count + 4)
    end
  end
  for i = 1, maxLines do
    local left = _G[TOOLTIP_NAME .. "TextLeft" .. i]
    if left then
      addLine(left:GetText())
    end
  end

  if #lines == 0 and tip.GetRegions then
    local regions = { tip:GetRegions() }
    for _, region in ipairs(regions) do
      if region and region.GetObjectType and region:GetObjectType() == "FontString" then
        addLine(region:GetText())
      end
      if #lines >= MAX_TOOLTIP_LINES then
        break
      end
    end
  end

  return lines
end

local function CountSocketsFromLines(lines)
  local set = BuildSocketLineSet()
  local count = 0
  for _, line in ipairs(lines) do
    local trimmed = (WSGH.Util and WSGH.Util.Trim and WSGH.Util.Trim(line)) or line
    if set[trimmed] then
      count = count + 1
    end
  end
  return count
end

local function DetectTinkerFromLines(lines)
  local cache = EnsureTinkerCache()
  if #cache == 0 then return 0 end

  local bestSpellId = 0
  local bestScore = 0

  for _, line in ipairs(lines) do
    local norm = NormalizeText(line)
    if norm ~= "" then
      for _, entry in ipairs(cache) do
        for _, phrase in ipairs(entry.phrases or {}) do
          if phrase ~= "" and norm:find(phrase, 1, true) then
            local score = #phrase
            if score > bestScore then
              bestScore = score
              bestSpellId = entry.spellId
            end
            break
          end
        end
      end
    end
  end

  return bestSpellId
end

function WSGH.Scan.Tooltip.Initialize()
  EnsureScanner()
  BuildSocketLineSet()
  EnsureTinkerCache()
end

function WSGH.Scan.Tooltip.GetInventoryItemInfo(unit, slotId)
  if not unit or not slotId then return nil end
  local lines = ReadTooltipLinesForInventoryItem(unit, slotId)
  return {
    socketCount = CountSocketsFromLines(lines),
    tinkerId = DetectTinkerFromLines(lines),
  }
end

WSGH.Debug = WSGH.Debug or {}
function WSGH.Debug.DumpTooltipTinker(slotId)
  slotId = tonumber(slotId) or 0
  if slotId == 0 then
    WSGH.Util.Print("DumpTooltipTinker: provide slotId.")
    return
  end
  local lines, source = ReadTooltipLinesForInventoryItem("player", slotId)
  local matchId = DetectTinkerFromLines(lines)
  local locale = (type(GetLocale) == "function" and GetLocale()) or "unknown"
  WSGH.Util.Print(("DumpTooltipTinker slot %d locale %s source %s => tinkerId %d"):format(
    slotId,
    tostring(locale),
    tostring(source or "unknown"),
    tonumber(matchId) or 0
  ))
  WSGH.Util.Print(("  Captured tooltip lines: %d"):format(#lines))
  if lastPopulateDebug then
    WSGH.Util.Print(("  Populate: setInventory ok=%s result=%s usedHyperlink=%s setHyperlink ok=%s result=%s numLines=%d"):format(
      tostring(lastPopulateDebug.setInventoryCallOk),
      tostring(lastPopulateDebug.setInventoryResult),
      tostring(lastPopulateDebug.usedHyperlinkFallback),
      tostring(lastPopulateDebug.setHyperlinkCallOk),
      tostring(lastPopulateDebug.setHyperlinkResult),
      tonumber(lastPopulateDebug.numLines) or 0
    ))
  end
  if #lines == 0 then
    WSGH.Util.Print("  No tooltip text captured for this slot.")
  end
  for i, line in ipairs(lines) do
    WSGH.Util.Print(("  [%d] %s"):format(i, tostring(line)))
  end
end

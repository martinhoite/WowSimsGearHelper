-- Minimal JSON decoder for WoW addons.
-- Decode-only. Supports objects, arrays, strings, numbers, booleans, null.
-- Intended for trusted input (WowSims export).

local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH

WSGH.JSON = WSGH.JSON or {}

local function decode_error(str, idx, msg)
  error(("JSON decode error at char %d: %s"):format(idx, msg), 0)
end

local function skip_whitespace(str, idx)
  while true do
    local c = str:sub(idx, idx)
    if c == "" then return idx end
    if c ~= " " and c ~= "\n" and c ~= "\r" and c ~= "\t" then
      return idx
    end
    idx = idx + 1
  end
end

local function decode_string(str, idx)
  idx = idx + 1
  local out = {}
  local n = 0

  while true do
    local c = str:sub(idx, idx)
    if c == "" then decode_error(str, idx, "unterminated string") end

    if c == '"' then
      return table.concat(out), idx + 1
    end

    if c == "\\" then
      local esc = str:sub(idx + 1, idx + 1)
      if esc == "" then decode_error(str, idx, "unterminated escape") end

      local map = {
        ['"'] = '"',
        ['\\'] = '\\',
        ['/'] = '/',
        ['b'] = "\b",
        ['f'] = "\f",
        ['n'] = "\n",
        ['r'] = "\r",
        ['t'] = "\t",
      }

      local repl = map[esc]
      if not repl then
        decode_error(str, idx, "invalid escape \\" .. esc)
      end

      n = n + 1
      out[n] = repl
      idx = idx + 2
    else
      n = n + 1
      out[n] = c
      idx = idx + 1
    end
  end
end

local function decode_number(str, idx)
  local start = idx
  local c = str:sub(idx, idx)

  if c == "-" then idx = idx + 1 end

  while true do
    c = str:sub(idx, idx)
    if c < "0" or c > "9" then break end
    idx = idx + 1
  end

  if str:sub(idx, idx) == "." then
    idx = idx + 1
    while true do
      c = str:sub(idx, idx)
      if c < "0" or c > "9" then break end
      idx = idx + 1
    end
  end

  local num = tonumber(str:sub(start, idx - 1))
  if not num then decode_error(str, start, "invalid number") end

  return num, idx
end

local decode_value

local function decode_array(str, idx)
  idx = idx + 1
  idx = skip_whitespace(str, idx)

  local arr = {}
  local n = 0

  if str:sub(idx, idx) == "]" then
    return arr, idx + 1
  end

  while true do
    local val
    val, idx = decode_value(str, idx)
    n = n + 1
    arr[n] = val

    idx = skip_whitespace(str, idx)
    local c = str:sub(idx, idx)

    if c == "," then
      idx = skip_whitespace(str, idx + 1)
    elseif c == "]" then
      return arr, idx + 1
    else
      decode_error(str, idx, "expected ',' or ']'")
    end
  end
end

local function decode_object(str, idx)
  idx = idx + 1
  idx = skip_whitespace(str, idx)

  local obj = {}

  if str:sub(idx, idx) == "}" then
    return obj, idx + 1
  end

  while true do
    if str:sub(idx, idx) ~= '"' then
      decode_error(str, idx, "expected string key")
    end

    local key
    key, idx = decode_string(str, idx)

    idx = skip_whitespace(str, idx)
    if str:sub(idx, idx) ~= ":" then
      decode_error(str, idx, "expected ':'")
    end

    idx = skip_whitespace(str, idx + 1)

    local val
    val, idx = decode_value(str, idx)
    obj[key] = val

    idx = skip_whitespace(str, idx)
    local c = str:sub(idx, idx)

    if c == "," then
      idx = skip_whitespace(str, idx + 1)
    elseif c == "}" then
      return obj, idx + 1
    else
      decode_error(str, idx, "expected ',' or '}'")
    end
  end
end

decode_value = function(str, idx)
  idx = skip_whitespace(str, idx)
  local c = str:sub(idx, idx)

  if c == '"' then return decode_string(str, idx) end
  if c == "{" then return decode_object(str, idx) end
  if c == "[" then return decode_array(str, idx) end
  if c == "-" or (c >= "0" and c <= "9") then return decode_number(str, idx) end

  if str:sub(idx, idx + 3) == "true" then return true, idx + 4 end
  if str:sub(idx, idx + 4) == "false" then return false, idx + 5 end
  if str:sub(idx, idx + 3) == "null" then return nil, idx + 4 end

  decode_error(str, idx, "unexpected character")
end

function WSGH.JSON.Decode(text)
  if type(text) ~= "string" then
    error("JSON.Decode expects a string", 0)
  end

  local val, idx = decode_value(text, 1)
  idx = skip_whitespace(text, idx)

  if idx <= #text then
    decode_error(text, idx, "trailing garbage")
  end

  return val
end

local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Import = WSGH.Import or {}

function WSGH.Import.FromJson(jsonText)
  jsonText = WSGH.Util.Trim(jsonText or "")
  if jsonText == "" then
    return nil, "Empty input"
  end

  local decoded
  local ok, err = pcall(function()
    decoded = WSGH.JSON.Decode(jsonText)
  end)

  if not ok then
    return nil, "JSON parse error: " .. tostring(err)
  end

  if type(decoded) ~= "table" then
    return nil, "Parsed JSON is not an object"
  end

  -- Dispatch by apiVersion (and potentially source later)
  local apiVersion = decoded.apiVersion
  if apiVersion == 2 then
    return WSGH.Importers.WowSimsV2.FromDecoded(decoded)
  end

  return nil, "Unsupported apiVersion: " .. tostring(apiVersion)
end

function WSGH.Import.__DebugTest()
    local json = [[
    {
      "apiVersion": 2,
      "player": {
        "class": "ClassMonk",
        "equipment": {
          "items": [
            { "id": 96641, "gems": [76884, 76699] },
            { "id": 89917 },
            {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
          ]
        }
      }
    }
    ]]
  
    local plan, err = WSGH.Import.FromJson(json)
    if not plan then
      WSGH.Util.Print("Import failed: " .. err)
      return
    end
  
    WSGH.Util.Print("Import OK")
    WSGH.Util.Print("Class: " .. tostring(plan.meta.class))
    WSGH.Util.Print("Head item: " .. tostring(plan.slots[1].expectedItemId))
    WSGH.Util.Print("Head gem 1: " .. tostring(plan.slots[1].expectedGemsByIndex[1]))
    WSGH.Util.Print("Head gem 2: " .. tostring(plan.slots[1].expectedGemsByIndex[2]))
    WSGH.Util.Print("Neck item: " .. tostring(plan.slots[2].expectedItemId))
  end
  

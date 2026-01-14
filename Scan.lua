local WSGH = _G.WowSimsGearHelper
WSGH.Scan = WSGH.Scan or {}

function WSGH.Scan.GetEquipped()
  return WSGH.Scan.Equipped.GetState()
end

function WSGH.Scan.GetBagIndex()
  return WSGH.Scan.Bags.BuildIndex()
end

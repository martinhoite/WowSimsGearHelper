local WSGH = _G.WowSimsGearHelper or {}
_G.WowSimsGearHelper = WSGH
WSGH.Diff = WSGH.Diff or {}

function WSGH.Diff.Build(plan, equipped, bagIndex)
  equipped = equipped or WSGH.Scan.GetEquipped()
  bagIndex = bagIndex or WSGH.Scan.GetBagIndex()
  return WSGH.Diff.Engine.Build(plan, equipped, bagIndex)
end

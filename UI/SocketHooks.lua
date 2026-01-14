local WSGH = _G.WowSimsGearHelper or {}
WSGH.UI = WSGH.UI or {}
WSGH.UI.SocketHooks = WSGH.UI.SocketHooks or {}

local hooks = WSGH.UI.SocketHooks
hooks._initialized = hooks._initialized or false
hooks._watcher = hooks._watcher or nil
hooks._handlers = hooks._handlers or {}

local function BindSocketApply()
  local btn = _G.ItemSocketingSocketButton
  if not btn or btn.WSGHApplyHooked then return end
  btn.WSGHApplyHooked = true
  btn:HookScript("OnClick", function()
    local h = hooks._handlers
    if h and h.OnApply then
      h.OnApply()
    end
  end)
end

local function BindSocketFrameShow()
  local frame = _G.ItemSocketingFrame
  if not frame or frame.WSGHShowHooked then return end
  frame.WSGHShowHooked = true
  frame:HookScript("OnShow", function()
    local h = hooks._handlers
    if h and h.OnShow then
      h.OnShow(frame)
    end
  end)
end

local function BindSocketFrameHide()
  local frame = _G.ItemSocketingFrame
  if not frame or frame.WSGHHideHooked then return end
  frame.WSGHHideHooked = true
  frame:HookScript("OnHide", function()
    local h = hooks._handlers
    if h and h.OnHide then
      h.OnHide()
    end
  end)
end

local function EnsureWatcher()
  if hooks._watcher then return end
  local f = CreateFrame("Frame")
  hooks._watcher = f
  f:SetScript("OnUpdate", function(_, elapsed)
    local h = hooks._handlers
    if not h or not h.ShouldWatch or not h.ShouldWatch() then
      f:Hide()
      return
    end
    if h.OnWatcherUpdate then
      h.OnWatcherUpdate(elapsed)
    end
  end)
end

function hooks.Initialize(handlers)
  if hooks._initialized then
    hooks._handlers = handlers or hooks._handlers
    return
  end
  hooks._initialized = true
  hooks._handlers = handlers or hooks._handlers

  BindSocketApply()
  BindSocketFrameShow()
  BindSocketFrameHide()
  EnsureWatcher()
end

function hooks.RefreshHandlers(handlers)
  hooks._handlers = handlers or hooks._handlers
end

function hooks.EnableWatcher()
  EnsureWatcher()
  if hooks._watcher then
    hooks._watcher:Show()
  end
end

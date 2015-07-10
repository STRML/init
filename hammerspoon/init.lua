-- Load Extensions
local application = require "hs.application"
local window = require "hs.window"
local hotkey = require "hs.hotkey"
local keycodes = require "hs.keycodes"
local fnutils = require "hs.fnutils"
local alert = require "hs.alert"
local screen = require "hs.screen"
local grid = require "hs.grid"
local hints = require "hs.hints"
local appfinder = require "hs.appfinder"
local tabs = require "hs.tabs"

local definitions = nil
local hyper = nil
local hyper2 = nil

-- Allow saving focus, then restoring it later.
auxWin = nil
function saveFocus()
  auxWin = window.focusedWindow()
  alert.show("Window '" .. auxWin:title() .. "' saved.")
end
function focusSaved()
  if auxWin then
    auxWin:focus()
  end
end

--
-- Hotkeys
--
local hotkeys = {}
function createHotkeys()
  for key, fun in pairs(definitions) do
    local mod = hyper
    -- Any definitions ending with c are cmd defs
    if string.len(key) == 2 and string.sub(key,2,2) == "c" then
      key = string.sub(key,1,1)
      mod = {"cmd"}
    -- Ending with l are ctrl
    elseif string.len(key) == 2 and string.sub(key,2,2) == "l" then
      key = string.sub(key,1,1)
      mod = {"ctrl"}
    end

    local hk = hotkey.new(mod, key, fun)
    table.insert(hotkeys, hk)
    hk:enable()
  end
end

function rebindHotkeys()
  for i, hk in ipairs(hotkeys) do
    hk:disable()
  end
  hotkeys = {}
  createHotkeys()
  alert.show("Rebound Hotkeys")
end

--
-- Grid
--

-- HO function for automating moving a window to a predefined position.
local gridset = function(frame)
  return function()
    local win = window.focusedWindow()
    if win then
      grid.set(win, frame, win:screen())
    else
      alert.show("No focused window.")
    end
  end
end

function applyPlace(win, place)
  local scrs = screen:allScreens()
  local scr = scrs[place[1]]
  grid.set(win, place[2], scr)
end

function applyLayout(layout)
  return function()
    alert.show("Applying Layout.")
    for appName, place in pairs(layout) do
      local app = appfinder.appFromName(appName)
      if app then
        for i, win in ipairs(app:allWindows()) do
          applyPlace(win, place)
        end
      end
    end
  end
end

--
-- Conf
--

--
-- Utility
--

function reloadConfig(files)
  for _,file in pairs(files) do
    if file:sub(-4) == ".lua" then
      hs.reload()
      return
    end
  end
end

-- Prints out a table like a JSON object. Utility
function serializeTable(val, name, skipnewlines, depth)
  skipnewlines = skipnewlines or false
  depth = depth or 0

  local tmp = string.rep(" ", depth)

  if name then tmp = tmp .. name .. " = " end

  if type(val) == "table" then
    tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

    for k, v in pairs(val) do
      tmp =  tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
    end

    tmp = tmp .. string.rep(" ", depth) .. "}"
  elseif type(val) == "number" then
    tmp = tmp .. tostring(val)
  elseif type(val) == "string" then
    tmp = tmp .. string.format("%q", val)
  elseif type(val) == "boolean" then
    tmp = tmp .. (val and "true" or "false")
  else
    tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
  end

  return tmp
end

function init()
  -- Bind hotkeys.
  createHotkeys()
  -- If we hook up a keyboard, rebind.
  keycodes.inputSourceChanged(rebindHotkeys)
  -- Automatically reload config when it changes.
  hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

  alert.show("Hammerspoon, at your service.")
end

-- Actual config =================================

hyper = {"cmd", "alt", "ctrl","shift"}
hyper2 = {"ctrl"}
hs.window.animationDuration = 0.2;
-- hints.style = "vimperator"
-- Set grid size.
grid.GRIDWIDTH  = 32
grid.GRIDHEIGHT = 18
grid.MARGINX = 0
grid.MARGINY = 0
local gw = grid.GRIDWIDTH
local gh = grid.GRIDHEIGHT

local gomiddle = {x = 1, y = 1, w = 4, h = 6}
local goleft = {x = 0, y = 0, w = gw/2, h = gh}
local goright = {x = gw/2, y = 0, w = gw/2, h = gh}
local gobig = {x = 0, y = 0, w = gw, h = gh}

-- Saved layout. TODO
local layout2 = {
  ["Sublime Text"] = {1, {x = 0, y = 0, h = 12, w = 11}},
  LimeChat = {1, {x = 0, y = 12, h = 6, w = 5}},
  ["Google Chrome"] = {1, {x = 11, y = 6, h = 12, w = 11}},
  Slack = {1, {x = 22, y = 0, h = 6, w = 10}},
  Thunderbird = {1, {x = 22, y = 12, h = 6, w = 10}},
  Skype = {1, {x = 5, y = 12, h = 6, w = 6}},
  iTerm = {1, {x = 11, y = 0, h = 6, w = 9}},
  Messages = {1, {x = 26, y = 12, w = 6, h = 6}},
  Finder = {1, {x = 22, y = 6, w = 10, h = 6}}
}

definitions = {
  [";"] = saveFocus,
  a = focusSaved,

  -- h = gridset(gomiddle),
  Left = gridset(goleft),
  Up = grid.maximizeWindow,
  Right = gridset(goright),

  ["'"] = function() alert.show(serializeTable(grid.get(window.focusedWindow())), 30) end,
  g = applyLayout(layout2),

  d = grid.pushWindowNextScreen,
  q = function() appfinder.appFromName("Hammerspoon"):kill() end,

  -- TODO app focused window hints
  -- k = function() hints.windowHints(appfinder.appFromName("Sublime Text"):allWindows()) end,
  -- j = function() hints.windowHints(window.focusedWindow():application():allWindows()) end,
  -- ll = function() hyper, hyper2 = hyper2,hyper; rebindHotkeys() end,
  ["e"] = function() hints.windowHints(nil) end,

  --
  -- GRID
  --

  -- move windows
  H = grid.pushWindowLeft,
  J = grid.pushWindowDown,
  L = grid.pushWindowRight,
  K = grid.pushWindowUp,

  -- resize windows
  ["="] = grid.resizeWindowTaller,
  ["-"] = grid.resizeWindowShorter,
  ["["] = grid.resizeWindowThinner,
  ["]"] = grid.resizeWindowWider,

  M = grid.maximizeWindow,
  N = function() grid.snap(window.focusedWindow()) end
}




--
-- TABS
-- Currently crashes on sublime text.
--
-- for i=1,6 do
--   definitions[tostring(i)] = function()
--     local app = application.frontmostApplication()
--     tabs.focusTab(app,i)
--   end
-- end

init()

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

local watchers = {}


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
    if key == "." then alert.show("Key bound to `.`, which is an internal OS X shortcut for sysdiagnose.") end
    local mod = hyper
    -- Any definitions ending with c are cmd defs
    if string.len(key) == 2 and string.sub(key,2,2) == "c" then
      key = string.sub(key,1,1)
      mod = {"cmd"}
    -- Ending with l are ctrl
    elseif string.len(key) == 2 and string.sub(key,2,2) == "l" then
      key = string.sub(key,1,1)
      mod = {"ctrl"}
    elseif string.len(key) == 4 and string.sub(key,2,4) == "raw" then
      key = string.sub(key,1,1)
      mod = {}
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
  local scrs = screen.allScreens()
  local scr = scrs[place[1]]
  grid.set(win, place[2], scr)
end

function applyLayout(layout)
  return function()
    alert.show("Applying Layout.")
    -- Sort table, table keys last so they are sorted independently of the main app
    table.sort(layout, function (op1, op2)
      local type1, type2 = type(op1), type(op2)
      if type1 ~= type2 then
        return type1 < type2
      else
        return op1 < op2
      end
    end)

    for appName, place in pairs(layout) do
      -- Two types we allow: table, which is {appName, windowTitle}, or just the app itself
      if type(appName) == 'table' then
        local parentAppName = appName[1]
        local windowPattern = appName[2]
        alert(windowPattern)
        local window = appfinder.windowFromWindowTitlePattern(windowPattern)
        if window then
          applyPlace(window, place)
        end
      else
        alert(appName)
        local app = appfinder.appFromName(appName)
        if app then
          for i, win in ipairs(app:allWindows()) do
            applyPlace(win, place)
          end
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

function string.starts(str,Start)
  return string.sub(str,1,string.len(Start))==Start
end

--
-- WiFi
--

local home = {["Lemonparty"] = TRUE, ["Lemonparty 5GHz"] = TRUE}
local lastSSID = hs.wifi.currentNetwork()

function ssidChangedCallback()
  newSSID = hs.wifi.currentNetwork()

  if home[newSSID] and not home[lastSSID] then
    -- We just joined our home WiFi network
    hs.audiodevice.defaultOutputDevice():setVolume(25)
  elseif not home[newSSID] and home[lastSSID] then
    -- We just departed our home WiFi network
    hs.audiodevice.defaultOutputDevice():setVolume(0)
  end

  local messages = appfinder.appFromName('Messages')
  messages:selectMenuItem("Log In")

  lastSSID = newSSID
end

local wifiWatcher = hs.wifi.watcher.new(ssidChangedCallback)
wifiWatcher:start()

--
-- Sound
--

-- Mute on jack in/out
function audioCallback(uid, eventName, eventScope, channelIdx)
  if eventName == 'jack' then
    alert("Jack changed, muting.", 1)
    hs.audiodevice.defaultOutputDevice():setVolume(0)
  end
end


-- Watch device; mute when headphones unplugged.
local defaultDevice = hs.audiodevice.defaultOutputDevice()
defaultDevice:watcherCallback(audioCallback);
defaultDevice:watcherStart();

--
-- Application overrides
--


--
-- Fix Slack's channel switching.
-- This rebinds ctrl-tab and ctrl-shift-tab back to switching channels,
-- which is what they did before the Teams update.
--
-- Slack only provides alt+up/down for switching channels, (and the cmd-t switcher,
-- which is buggy) and have 3 (!) shortcuts for switching teams, most of which are
-- the usual tab switching shortcuts in every other app.
--
-- This basically turns the tab switching shortcuts into LimeChat shortcuts, which very smartly
-- uses the brackets to switch any channel, and ctrl-(shift)-tab to switch unreads.
local slackKeybinds = {
  hotkey.new({"ctrl"}, "tab", function()
    hs.eventtap.keyStroke({"alt", "shift"}, "Down")
  end),
  hotkey.new({"ctrl", "shift"}, "tab", function()
    hs.eventtap.keyStroke({"alt", "shift"}, "Up")
  end),
  hotkey.new({"cmd", "shift"}, "[", function()
    hs.eventtap.keyStroke({"alt"}, "Up")
  end),
  hotkey.new({"cmd", "shift"}, "]", function()
    hs.eventtap.keyStroke({"alt"}, "Down")
  end),
  -- Disables cmd-w entirely, which is so annoying on slack
  hotkey.new({"cmd"}, "w", function() return end)
}
local slackWatcher = hs.application.watcher.new(function(name, eventType, app)
  if eventType ~= hs.application.watcher.activated then return end
  local fnName = name == "Slack" and "enable" or "disable"
  for i, keybind in ipairs(slackKeybinds) do
    -- Remember that lua is weird, so this is the same as keybind.enable() in JS, `this` is first param
    keybind[fnName](keybind)
  end
end)
slackWatcher:start()

--
-- Fix Skype's channel switching.
--
local skypeKeybinds = {
  hotkey.new({"ctrl"}, "tab", function()
    hs.eventtap.keyStroke({"alt", "cmd"}, "Right")
  end),
  hotkey.new({"ctrl", "shift"}, "tab", function()
    hs.eventtap.keyStroke({"alt", "cmd"}, "Left")
  end)
}
local skypeWatcher = hs.application.watcher.new(function(name, eventType, app)
  if eventType ~= hs.application.watcher.activated then return end
  local fnName = name == "Skype" and "enable" or "disable"
  for i, keybind in ipairs(skypeKeybinds) do
    -- Remember that lua is weird, so this is the same as keybind.enable() in JS, `this` is first param
    keybind[fnName](keybind)
  end
end)
skypeWatcher:start()

--
-- INIT!
--

function init()
  -- Bind hotkeys.
  createHotkeys()
  -- If we hook up a keyboard, rebind.
  keycodes.inputSourceChanged(rebindHotkeys)
  -- Automatically reload config when it changes.
  hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
  -- Doesn't work with symlinks... so go straight to the git repo.
  hs.pathwatcher.new(os.getenv("HOME") .. "/git/oss/init/hammerspoon/", reloadConfig):start()

  -- Prevent system sleep, only if connected to AC power. (sleepType, shouldPrevent, batteryToo)
  hs.caffeinate.set('system', true, false)

  alert.show("Reloaded.", 1)
end

-- Grid config =================================

hyper = {"cmd", "alt", "ctrl","shift"}
hyper2 = {"ctrl"}
hs.window.animationDuration = 0.2;
-- hints.style = "vimperator"
-- Set grid size.
has4k = hs.screen('3840x2160')

grid.GRIDWIDTH  = has4k and 32 or 4
grid.GRIDHEIGHT = has4k and 18 or 4
grid.MARGINX = 0
grid.MARGINY = 0
local gw = grid.GRIDWIDTH
local gh = grid.GRIDHEIGHT

local goMiddle = {x = gw/4, y = gh/4, w = gw/2, h = gh/2}
local goLeft = {x = 0, y = 0, w = gw/2, h = gh}
local goRight = {x = gw/2, y = 0, w = gw/2, h = gh}
local goTopLeft = {x = 0, y = 0, w = gw/2, h = gh/2}
local goTopRight = {x = gw/2, y = 0, w = gw/2, h = gh/2}
local goBottomLeft = {x = 0, y = gh/2, w = gw/2, h = gh/2}
local goBottomRight = {x = gw/2, y = gh/2, w = gw/2, h = gh/2}
local gobig = {x = 0, y = 0, w = gw, h = gh}

-- Saved layout. TODO
local layout2 = {
  ["Sublime Text"] = {1, {x = 0, y = 0, h = 12, w = 11}},
  LimeChat = {1, {x = 0, y = 12, h = 6, w = 5}},
  ["Google Chrome"] = {1, {x = 11, y = 7, h = 11, w = 13}},
  [{"Google Chrome", "Developer Tools.*"}] = {1, {x = 24, y = 7, h = 11, w = 8}},
  Slack = {1, {x = 24, y = 0, h = 9, w = 8}},
  Postbox = {1, {x = 24, y = 9, h = 9, w = 8}},
  Skype = {1, {x = 6, y = 12, h = 6, w = 5}},
  Telegram = {1, {x = 6, y = 12, h = 6, w = 5}},
  iTerm2 = {1, {x = 11, y = 0, h = 7, w = 13}},
  Messages = {1, {x = 26, y = 12, w = 6, h = 6}},
  Finder = {1, {x = 22, y = 6, w = 10, h = 6}},
  Postico = {1, {x = 0, y = 12, w = 6, h = 6}},
}

-- Watch out, cmd-opt-ctrl-shift-period is an actual OS X shortcut for running sysdiagose
definitions = {
  r = hs.reload,
  -- Not using
  -- [";"] = saveFocus,
  -- a = focusSaved,

  -- h = gridset(godMiddle),
  Left = gridset(goLeft),
  Up = grid.maximizeWindow,
  Right = gridset(goRight),

  ['1'] = gridset(goTopLeft),
  ['3'] = gridset(goTopRight),
  ['5'] = gridset(goMiddle),
  ['7'] = gridset(goBottomLeft),
  ['9'] = gridset(goBottomRight),

  -- ["'"] = function() alert.show(serializeTable(grid.get(window.focusedWindow())), 30) end,
  g = has4k and applyLayout(layout2) or nil,

  ["'"] = grid.pushWindowPrevScreen,
  [";"] = grid.pushWindowNextScreen,
  ["\\"] = grid.show, -- way too fucked with our grid sizes
  -- q = function() hs.application.find("Hammerspoon"):kill() end,

  -- Shows all sublime windows
  -- e = function() hints.windowHints(hs.application.find("Sublime Text"):allWindows()) end,
  -- Focuses these apps
  q = function() hs.application.find("Sublime Text"):mainWindow():focus() end,
  w = function() hs.application.find("iTerm2"):mainWindow():focus() end,
  c = function() hs.application.find("Google Chrome"):mainWindow():focus() end,
  s = function() hs.application.find("Slack"):mainWindow():focus() end,
  -- Show hints for all window
  f = function() hints.windowHints(nil) end,
  -- Shows all windows for current app
  v = function() hints.windowHints(window.focusedWindow():application():allWindows()) end,

  -- Switches hypers, not used
  -- ll = function() hyper, hyper2 = hyper2,hyper; rebindHotkeys() end,

  o = function() hs.execute(os.getenv("HOME") .. "/bin/subl ".. os.getenv("HOME") .."/.hammerspoon/init.lua") end,
  --
  -- GRID
  --

  -- move windows
  h = grid.pushWindowLeft,
  j = grid.pushWindowDown,
  l = grid.pushWindowRight,
  j = grid.pushWindowUp,

  -- resize windows
  ["="] = grid.resizeWindowTaller,
  ["-"] = grid.resizeWindowShorter,
  ["["] = grid.resizeWindowThinner,
  ["]"] = grid.resizeWindowWider,

  m = grid.maximizeWindow,
  n = function() grid.snap(window.focusedWindow()) end,

  -- cmd+\ should run cmd-tab (keyboard symmetry)
  ["\\c"] = function() hs.eventtap.keyStroke({"cmd"},"tab") end
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

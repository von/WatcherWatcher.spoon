--- === WatcherWatcher ===
-- Who watches the watchers? Monitor cameras and microphones for usage.
-- Inspired by OverSight (https://objective-see.org/products/oversight.html)
-- With kudos to:
--   https://developer.okta.com/blog/2020/10/22/set-up-a-mute-indicator-light-for-zoom-with-hammerspoon
--   http://www.hammerspoon.org/Spoons/MicMute.html

local WW = {}


-- Metadata
WW.name="WW"
WW.version="0.1"
WW.author="Von Welch"
-- https://opensource.org/licenses/Apache-2.0
WW.license="Apache-2.0"
WW.homepage=""

-- Constants
WW.GREEN_DOT = "🟢"
WW.RED_DOT = "🔴"

--- WW.monitorCameras
--- Variable
--- If true (default), monitor cameras.
WW.monitorCameras = true

--- WW.monitorMics
--- Variable
--- If true (default), monitor microphones.
--- Currently off due to bug in audiodevice callbacks:
--- https://github.com/Hammerspoon/hammerspoon/issues/3057
WW.monitorMics = false

--- WW.enableMenubar
--- Variable
--- If true (default), enable menubar.
WW.enableMenubar = true

--- WW.menubarTitle
--- Variable
--- A table with the following keys:
---   * cameraInUse: Menubar title if a camera is in use.
---   * micInUse: Menubar title if a microphone is in use.
---   * cameraAndMicInUse: Menubar title if a camera and a microphone are in use.
---   * nothingInUse: Menubar title if nothing is in use.
WW.menubarTitle = {
  cameraInUse =  "📷",
  micInUse =  "🎙",
  cameraAndMicInUse = "📷🎙",
  nothingInUse = WW.GREEN_DOT
}

--- WW.callbacks
--- Variable
--- A table with the following keys:
---   * cameraInUse: callback when a camera becomes in use.
---     This function should take a single parameter of a hs.camera instance
---     and return nothing.
---   * cameraNotInUse: callback when a camera becomes not in use.
---     This function should take a single parameter of a hs.camera instance
---     and return nothing.
---   * micInUse: callback for when a microphone becomes in use.
---     This function should take a single parameter of a hs.audiodevice instance
---     and return nothing.
---   * micNotInUse: callback for when a microphone becomes not in use.
---     This function should take a single parameter of a hs.audiodevice instance
---     and return nothing.
WW.callbacks = {
  cameraInUse = nil,
  cameraNotInUse = nil,
  micInUse = nil,
  micNotInUse = nil
}

--- WW:debug(enable)
--- Method
--- Enable or disable debugging
---
--- Parameters:
---  * enable - Boolean indicating whether debugging should be on
---
--- Returns:
---  * Nothing
function WW:debug(enable)
  if enable then
    self.log.setLogLevel('debug')
    self.log.d("Debugging enabled")
  else
    self.log.d("Disabling debugging")
    self.log.setLogLevel('info')
  end
end

--- WW:init()
--- Method
--- Initializes the WW spoon
--- When a user calls hs.loadSpoon(), Hammerspoon will execute init()
--- Do generally not perform any work, map any hotkeys, start any timers/watchers/etc.
--- in the main scope of your init.lua. Instead, it should simply prepare an object
--- with methods to be used later, then return the object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * WW object

function WW:init()
  -- Set up logger for spoon
  self.log = hs.logger.new("WW")

  -- Path to this file itself
  -- See also http://www.hammerspoon.org/docs/hs.spoons.html#resourcePath
  self.path = hs.spoons.scriptPath()

  return self
end

--start() and stop()
--If your Spoon provides some kind of background activity, e.g. timers, watchers,
--spotlight searches, etc. you should generally activate them in a :start()
--method, and de-activate them in a :stop() method

--- WW:start()
--- Method
--- Start background activity.
---
--- Parameters:
---  * None
---
--- Returns:
---  * WW object
function WW:start()
  self.log.d("Starting")

  if self.monitorCameras then
    local cameraWatcherCallback = hs.fnutils.partial(WW.cameraWatcherCallback, self)
    hs.camera.setWatcherCallback(cameraWatcherCallback)
    hs.camera.startWatcher()

    local propertyCallback = hs.fnutils.partial(WW.cameraPropertyCallback, self)
    hs.fnutils.each(hs.camera.allCameras(), function(c)
      self.log.df("Starting watcher on camera %s", c:name())
      c:setPropertyWatcherCallback(propertyCallback)
      c:startPropertyWatcher()
    end)
  end

  if self.monitorMics then
    local audiodeviceWatcherCallback = hs.fnutils.partial(
      WW.audiodeviceWatcherCallback, self)
    hs.audiodevice.watcher.setCallback(audiodeviceWatcherCallback)
    hs.audiodevice.watcher.start()

    self:setupAudiodeviceCallbacks()
  end

  if self.enableMenubar then
    self.menubar = hs.menubar.new()
    self.menubar:setMenu(hs.fnutils.partial(self.menubarCallback, self))
    self:setMenuBarIcon()
  end

  return self
end

--- WW:stop()
--- Method
--- Stop background activity.
---
--- Parameters:
---  * None
---
--- Returns:
---  * WW object
function WW:stop()
  self.log.d("Stopping")

  if self.monitorCameras then
    hs.camera.setWatcherCallback(nil)
    hs.camera.stopWatcher()

    hs.fnutils.each(hs.camera.allCameras(), function(c)
      self.log.df("Stopping watcher on camera %s", c:name())
      c:setPropertyWatcherCallback(nil)
      c:stopPropertyWatcher()
    end)
  end

  if self.monitorMics then
    hs.audiodevice.watcher.setCallback(nil)
    hs.audiodevice.watcher.stop()
    hs.fnutils.each(hs.audiodevice.allInputDevices(),
      function(m)
        self.log.df("Stopping watcher on microphone %s", m:name())
        m:watcherCallback(nil)
        m:watcherStop()
      end)
  end

  if self.enableMenubar then
    self.menubar:removeFromMenuBar()
  end

  return self
end

-- bindHotKeys()
-- If your Spoon provides actions that a user can map to hotkeys, you
-- should expose a :bindHotKeys() method.

--- WW:bindHotKeys(table)
--- Method
--- The method accepts a single parameter, which is a table. The keys of the table
--- are strings that describe the action performed, and the values of the table are
--- tables containing modifiers and keynames/keycodes. E.g.
---   {
---     f1 = {{"cmd", "alt"}, "f"},
---     f2 = {{"cmd", "alt"}, "g"}
---    }
---
---
--- Parameters:
---  * mapping - Table of action to key mappings
---
--- Returns:
---  * WW object

function WW:bindHotKeys(mapping)
  local spec = {
    f1 = hs.fnutils.partial(self.feature1, self),
    f2 = hs.fnutils.partial(self.feature2, self)
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

--- WW:setMenuBarIcon()
--- Method
--- Set the menubar icon depending on if any camera or microphone is in use.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing

function WW:setMenuBarIcon()
  self.log.d("Setting menubar icon")
  local cameraInUse = self.monitorCameras and not hs.fnutils.every(
      hs.camera.allCameras(),
      function(c) return not c:isInUse() end)
  local micInUse = self.monitorMics and not hs.fnutils.every(
      hs.audiodevice.allInputDevices(),
      function(m) return not m:inUse() end)

  if cameraInUse and micInUse then
    self.menubar:setTitle(self.menubarTitle.cameraAndMicInUse)
  elseif cameraInUse then
    self.menubar:setTitle(self.menubarTitle.cameraInUse)
  elseif micInUse then
    self.menubar:setTitle(self.menubarTitle.micInUse)
  else
    self.menubar:setTitle(self.menubarTitle.nothingInUse)
  end
end

--- WW:menubarCallback()
--- Method
--- Callback for when user clicks on the menubar item.
--- Parameters:
---   * table indicating which keyboard modifiers were held down
---
--- Returns:
---   * table with menu - see hs.menubar.setMenu()
function WW:menubarCallback(modifiers)
  local t = {}
  hs.fnutils.each(hs.camera.allCameras(),
    function(c)
      local name = c:name()
      if c:isInUse() then
        name = WW.RED_DOT .. name
      end
      -- Not clear what selecting a camera should/could do.
      table.insert(t, { title = name })
    end)
  table.insert(t, { title = "-" })
  hs.fnutils.each(hs.audiodevice.allInputDevices(),
    function(m)
      local name = m:name()
      if m:inUse() then
        name = WW.RED_DOT .. name
      end
      table.insert(t, { title = name })
    end)
  return t
end

--- WW:cameraWatcherCallback()
--- Method
--- Callback for hs.camera.setWatcherCallback()
--- Parameters:
---   * hs.camera device
---   * A string, either "Added" or "Removed"
---
--- Returns:
---   * Nothing
function WW:cameraWatcherCallbackwatcherCallback(camera, change)
  if change == "Added" then
    self.log.d("Starting watcher on new camera " .. camera:name())
    local propertyCallback = hs.fnutils.partial(WW.cameraPropertyCallback, self)
    camera:setPropertyWatcherCallback(propertyCallback)
    camera:startPropertyWatcher()
  elseif change == "Removed" then
    self.log.d("Camera removed")
  else
    self.log.d("Unknowm watcher change: " .. change)
  end
end

--- WW:cameraPropertyCallback()
--- Method
--- Callback for hs.camera.setPropertyWatcherCallback()
--- Parameters:
---   * hs.camera instance
---   * property (expected to be "gone")
---   * scope (expected to be "glob")
---   * event number (ignored, expected to be 0)
---
--- Returns:
---   * Nothing
function WW:cameraPropertyCallback(camera, prop, scope, eventnum)
  self.log.df("cameraPropertyCallback(%s, %s, %s, %d, %s)",
    camera:name(), prop, scope, eventnum, tostring(camera:isInUse()))
  if prop == "gone" then
    if camera:isInUse() then
      if self.callbacks.cameraInUse then
        local ok, err = pcall(function() hs.callbacks.cameraInUse(dev) end)
        if not ok then
          self.log.ef("Error calling cameraInUse callback: %s", err)
        end
      end
    else
      if self.callbacks.cameraNotInUse then
        local ok, err = pcall(function() hs.callbacks.cameraNotInUse(dev) end)
        if not ok then
          self.log.ef("Error calling cameraNotInUse callback: %s", err)
        end
      end
    end
    if self.enableMenubar then
      self:setMenuBarIcon()
    end
  end
end

--- WW:audiodeviceWatcherCallback()
--- Method
--- Callback for hs.camera.watcher
--- Parameters:
---   * String with change
---
--- Returns:
---   * Nothing
function WW:audiodeviceWatcherCallback(event)
  self.log.df("audiodeviceWatcherCallback(%s) called", event)
  if event == "dev#" then
    -- Number of devices changed, make sure we have watchers running
    self:setupAudiodeviceCallbacks()
  end
end

--- WW:setupAudiodeviceCallbacks()
--- Method
--- Make sure we have callbacks set up for all input audiodevices.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function WW:setupAudiodeviceCallbacks()
  local callback = hs.fnutils.partial(self.audiodeviceCallback, self)
  hs.fnutils.each(hs.audiodevice.allInputDevices(),
    function(m)
      if not m:watcherIsRunning() then
        self.log.df("Starting watcher on microphone %s (%s)", m:name(), m:uid())
        m:watcherCallback(callback)
        m:watcherStart()
      end
    end)
  d = hs.audiodevice.allInputDevices()[1]
  self.log.df("Running: %s (%s) %s", d, d:uid(), d:watcherIsRunning())  -- DEBUG
end

--- WW:audiodeviceCallback()
--- Method
--- Callback for audiodevice:watcherCallback()
--- XXX This is not getting called.
---     See https://github.com/Hammerspoon/hammerspoon/issues/3057
--- Parameters:
---   * uid (string)
---   * eventname (string)
---   * scope (string)
---   * element (int)
---
--- Returns:
---   * Nothing
function WW:audiodeviceCallback(uid, eventname, scope, element)
  self.log.df("WWW.audiodeviceCallback(%s, %s, %s, %d)",
    uid, eventname, scope, element)
  if eventname == "gone" then
    dev = hs.audiodevice.findDeviceByUID(uid)
    if not dev then
      hs.log.ef("Unkown audiodevice UID %s", uid)
      return
    end
    if dev:inUse() then
      hs.log.df("Microphone %s now in use", dev:name())
      if self.callbacks.micInUse then
        local ok, err = pcall(function() hs.callbacks.micInUse(dev) end)
        if not ok then
          self.log.ef("Error calling micInUse callback: %s", err)
        end
      end
    else
      hs.log.df("Microphone %s now not in use", dev:name())
      if self.callbacks.micNotInUse then
        local ok, err = pcall(function() hs.callbacks.micNotInUse(dev) end)
        if not ok then
          self.log.ef("Error calling micNotInUse callback: %s", err)
        end
      end
    end
  end
end

return WW

--- === WatcherWatcher ===
--- Who watches the watchers? Monitor cameras and microphones for usage.
--- Inspired by:
---   OverSight (https://objective-see.org/products/oversight.html)
---   https://developer.okta.com/blog/2020/10/22/set-up-a-mute-indicator-light-for-zoom-with-hammerspoon
---   http://www.hammerspoon.org/Spoons/MicMute.html

local WW = {}


-- Metadata
WW.name="WW"
WW.version="0.3"
WW.author="Von Welch"
-- https://opensource.org/licenses/Apache-2.0
WW.license="Apache-2.0"
WW.homepage="https://github.com/von/WatcherWatcher.spoon"

-- Constants
WW.GREEN_DOT = "🟢"
WW.RED_DOT = "🔴"

--- WatcherWatcher.monitorCameras
--- Variable
--- If true (default), monitor cameras.
WW.monitorCameras = true

--- WatcherWatcher.delayInUseCallbacks
--- Variable
--- If non-zero, delay in use callbacks by given number of seconds (default 5)
--- to ignore spurious callbacks when laptop sleeps/wakes.
--- See: https://github.com/von/WatcherWatcher.spoon/issues/2
WW.delayInUseCallbacks = 5

--- WatcherWatcher.monitorMics
--- Variable
--- If true (not the default), monitor microphones.
--- Currently off due to bug in audiodevice callbacks:
--- https://github.com/Hammerspoon/hammerspoon/issues/3057
WW.monitorMics = false

--- WatcherWatcher.enableMenubar
--- Variable
--- If true (default), enable menubar.
WW.enableMenubar = true

--- WatcherWatcher.enableIcon
--- Variable
--- If true (default), enable desktop icon if a camera or mic is in use.
WW.enableIcon = true

--- WatcherWatcher.iconGeometry
--- Variable
--- Table with geometry for icon. Should be a square.
--- Can have negative values for x and y, in which case they are treated
--- as offsets from right or bottom of screen respectively.
WW.iconGeometry = { x = -60, y = 20, w = 50, h = 50 }

--- WatcherWatcher.iconFillColor
--- Variable
--- Table with fill color for icon.
WW.iconFillColor = { alpha = 1.0, red = 1.0  }

--- WatcherWatcher.iconBlink
--- Variable
--- Enable blinking of Icon?
WW.iconBlink = true

--- WatcherWatcher.iconBlinkInterval
--- Variable
--- Frequency of icon blinking in seconds
WW.iconBlinkInterval = 1.0

--- WatcherWatcher.menubarTitle
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

--- WatcherWatcher.callbacks
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

--- WatcherWatcher:debug(enable)
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

--- WatcherWatcher:init()
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

--- WatcherWatcher:start()
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

  if self.enableIcon then
    self.log.d("Creating icon")
    -- XXX I suspect this doesn't handle multiple screens correctly
    local geometry = self.iconGeometry
    -- Handle negative x or y as offsets from right or bottom
    -- XXX Primary or main screen?
    local screenFrame = hs.screen.primaryScreen():frame()
    if geometry.x < 0 then
      geometry.x = screenFrame.w + geometry.x
    end
    if geometry.y < 0 then
      geometry.y = screenFrame.h + geometry.y
    end
    self.icon = hs.canvas.new(geometry)
    if not self.icon then
      self.e("Failed to create icon")
      self.enableIcon = false
    else
      self.icon:appendElements({
          -- A circle basically filling the canvas
          type = "circle",
          center = { x = ".5", y = ".5" },
          radius = ".5",
          fillColor = self.iconFillColor,
          action = "fill"
        })

      self.iconTimer = hs.timer.new(
        self.iconBlinkInterval,
        hs.fnutils.partial(self.iconBlink, self))
    end
  end

  self:reset()

  return self
end

--- WatcherWatcher:stop()
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

  if self.enableIcon then
    self.iconTimer:stop()
    self.icon:hide()
  end

  return self
end

--- WatcherWatcher:reset()
--- Method
--- Reset all state based on current camera and microphone status.
--- Ends effects of any prior muteIcon() call.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function WW:reset()
  if self.enableMenubar then
    self:setMenuBarIcon()
  end
  if self.enableIcon then
    self:updateIcon()
  end
end

--- WatcherWatcher:bindHotKeys(table)
--- Method
--- The method accepts a single parameter, which is a table. The keys of the
--- table are strings that describe the action performed, and the values of
--- the table are tables containing modifiers and keynames/keycodes. E.g.
---   {
---     muteIcon = {{"cmd", "alt"}, "m"},
---     reset = {{"cmd", "alt"}, "r"}
---    }
---
---
--- Parameters:
---  * mapping - Table of action to key mappings
---
--- Returns:
---  * WatcherWatcher object

function WW:bindHotKeys(mapping)
  local spec = {
    muteIcon = hs.fnutils.partial(self.muteIcon, self),
    reset = hs.fnutils.partial(self.reset, self)
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

--- WatcherWatcher:camerasInUse()
--- Method
--- Return a list of cameras that are in use.
--- Parameters:
---   * None
---
--- Returns:
---   * List of cameras that are in use.
function WW:camerasInUse()
  return hs.fnutils.filter(
    hs.camera.allCameras(),
    function(c) return c:isInUse() end)
end

--- WatcherWatcher:micsInUse()
--- Method
--- Return a list of microphones that are in use.
--- Parameters:
---   * None
---
--- Returns:
---   * List of microphones that are in use.
function WW:micsInUse()
  return hs.fnutils.filter(
    hs.audiodevice.allInputDevices(),
    function(a) return a:inUse() end)
end

--- WatcherWatcher:setMenuBarIcon()
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

--- WatcherWatcher:menubarCallback()
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

--- WatcherWatcher:updateIcon()
--- Method
--- Update icon (red circle) on desktop based on current state of camera
--- and micophone usage.
--- Parameters:
---   * Nothing
---
--- Returns:
---   * Nothing
function WW:updateIcon()
  local cameraInUse = self.monitorCameras and not hs.fnutils.every(
      hs.camera.allCameras(),
      function(c) return not c:isInUse() end)
  local micInUse = self.monitorMics and not hs.fnutils.every(
      hs.audiodevice.allInputDevices(),
      function(m) return not m:inUse() end)

  if cameraInUse or micInUse then
    if self.iconBlink then
      self.log.d("Starting icon blinking")
      self.iconTimer:start()
    else
      self.log.d("Showing icon")
      self.icon:show()
    end
  else
    if self.iconBlink then
      self.log.d("Stopping icon blinking")
      self.iconTimer:stop()
      self.icon:hide()
    else
      self.log.d("Hiding icon")
      self.icon:delete()
    end
  end
end

--- WatcherWatcher:iconBlink()
--- Method
--- Toggle the icon.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function WW:iconBlink()
  if self.icon:isShowing() then
    self.icon:hide()
  else
    self.icon:show()
  end
end

--- WatcherWatcher:cameraWatcherCallback()
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

--- WatcherWatcher:muteIcon()
--- Method
--- Turn off the icon until some change causes it to turn back on.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function WW:muteIcon()
  self.log.d("Muting icon")
  if self.iconBlink then
    self.iconTimer:stop()
    self.icon:hide()
  else
    self.icon:delete()
  end
end

--- WatcherWatcher:cameraPropertyCallback()
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
      if self.delayInUseCallbacks then
        self.log.df("Delaying callback from %s for %f seconds.",
          camera:name(), self.delayInUseCallbacks)
        hs.timer.doAfter(self.delayInUseCallbacks,
          hs.fnutils.partial(self.cameraInUseDelayedCallback,
            self, camera, prop, scope, eventnum))
        return
      end
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
    if self.enableIcon then
      self:updateIcon()
    end
  end
end

-- WatcherWatcher:cameraInUseDelayedCallback()
-- I seem to get spurious camera in use callbacks when my laptop wakes or
-- sleeps that are followed by a camera not in use callback 4 seconds later.
-- This method is called by the callack when it receives an in use indiciation
-- after 5 seconds and only takes action if the camera is still in use to
-- ignore these spurious callbacks.
-- See: https://github.com/von/WatcherWatcher.spoon/issues/2
--
-- Parameters:
--   * hs.camera instance
--   * property (expected to be "gone")
--   * scope (expected to be "glob")
--   * event number (ignored, expected to be 0)
--
-- Returns:
--   * Nothing
function WW:cameraInUseDelayedCallback(camera, prop, scope, eventnum)
  self.log.df("cameraInUseDelayedCallback(%s, %s, %s, %d, %s)",
    camera:name(), prop, scope, eventnum, tostring(camera:isInUse()))
  if camera:isInUse() then
    if self.callbacks.cameraInUse then
      local ok, err = pcall(function() hs.callbacks.cameraInUse(dev) end)
      if not ok then
        self.log.ef("Error calling cameraInUse callback: %s", err)
      end
    end
    if self.enableMenubar then
      self:setMenuBarIcon()
    end
    if self.enableIcon then
      self:updateIcon()
    end
  else
    self.log.d("Camera not in use. Ignoring.")
  end
end

--- WatcherWatcher:audiodeviceWatcherCallback()
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

--- WatcherWatcher:setupAudiodeviceCallbacks()
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

--- WatcherWatcher:audiodeviceCallback()
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

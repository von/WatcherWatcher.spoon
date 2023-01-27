--- === WatcherWatcher ===
--- Who watches the watchers? Monitor cameras and microphones for usage.
--- Inspired by and kudos to:
---   OverSight (https://objective-see.org/products/oversight.html)
---   https://developer.okta.com/blog/2020/10/22/set-up-a-mute-indicator-light-for-zoom-with-hammerspoon
---   http://www.hammerspoon.org/Spoons/MicMute.html
---   https://github.com/jpf/Zoom.spoon
---
--- Behavior is configurable with WatcherWatcher.callbacks, default
--- is to provide camera and microphone status via a menubar icon
--- and via blinking circles in the upper righthand corner of the
--- screen.

local WW = {}


-- Metadata
WW.name="WatcherWatcher"
WW.version="0.7"
WW.author="Von Welch"
-- https://opensource.org/licenses/Apache-2.0
WW.license="Apache-2.0"
WW.homepage="https://github.com/von/WatcherWatcher.spoon"

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
--- If true (the default), monitor microphones.
WW.monitorMics = true

--- WatcherWatcher.audiodeviceTimerInterval
--- Variable
--- A workaround for audiodevice callbacks not working. If non-zero,
--- run a timer which checks audiodevices every given number of seconds.
--- Default is 5 seconds.
--- See https://github.com/Hammerspoon/hammerspoon/issues/3057
WW.audiodeviceTimerInterval = 5

--- WatcherWatcher.honorZoomMuteStatus
--- Variable
--- Zoom activiates the microphone and then implements its own mute, so
--- will present a false positive. If honorZoomMuteStatus is true, then
--- honor Zoom's microphone state over that of the system if it is running.
--- Default is true.
WW.honorZoomMuteStatus = true

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
---   * mute: callback from when user requests muting of indicators.
---     This function should take no aguments and return nothing.
---
--- WatcherWatcher comes with two callbacks that can be used:
---   * WatcherWatcher.Flasher, a blinking icon that can appear on the screen.
---   * WatcherWatcher.Menubar, a menubar item
WW.callbacks = {
  cameraInUse = nil,
  cameraNotInUse = nil,
  micInUse = nil,
  micNotInUse = nil,
  mute = nil
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

  self.Flasher = dofile(hs.spoons.resourcePath("Flasher.lua"))
  self.Flasher:init(self)

  self.Menubar = dofile(hs.spoons.resourcePath("Menubar.lua"))
  self.Menubar:init(self)

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
    local cameraWatcherCallback =
      hs.fnutils.partial(WW.cameraWatcherCallback, self)
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

    if self.audiodeviceTimerInterval then
      self.audiodevicestate = {}
      self.log.df(
        "Starting audiodevice timer (interval: %d)",
        self.audiodeviceTimerInterval)
      self.audiodeviceTimer = hs.timer.doEvery(
        self.audiodeviceTimerInterval,
        hs.fnutils.partial(self.audioDeviceTimerFunction, self))
    end
  end

  self:setupDefaultCallbacks()

  return self
end

-- WatcherWatcher:setupDefaultCallbacks()
-- Method
-- Set up default callbacks if callbacks are unset.
-- Parameters:
--   * None
--
-- Returns:
--   * Nothing
function WW:setupDefaultCallbacks()
  -- If there is any sign of callbacks having been set up, then
  -- we don't touch them.
  if self.callbacks.cameraInUse or self.callbacks.cameraNotInUse or
    self.callbacks.micInUse or self.callbacks.micNotInUse or
    self.callbacks.mute then
    return
  end

  self.log.d("Setting up default callbacks")

  -- We do a default big red flashing circle in the upper right corner
  -- for a camera in use.
  self.cameraFlasher = self.Flasher:new("camera")
  if #self:camerasInUse() > 0 then
    self.cameraFlasher:show()
  end
  local cameraFlasherStart, cameraFlasherStop, cameraFlasherMute =
    self.cameraFlasher:callbacks()

  -- For a microphone in use, we create a smaller orange flashing circle
  -- in the upper right.
  self.microphoneFlasher = self.Flasher:new("microphones",
      {
        geometry = { x = -30, y = 20, w = 20, h = 20 },
        fillColor = { alpha = 1.0, red = 1.0, green = 0.67 }
      })
  if #self:micsInUse() > 0 then
    self.microphoneFlasher:show()
  end
  local micFlasherStart, micFlasherStop, micFlasherMute =
    self.microphoneFlasher:callbacks()

  self.menubar = WW.Menubar
  local mbStart, mbStop = self.menubar:callbacks()

  self.callbacks.cameraInUse =
    function(dev) cameraFlasherStart(dev) mbStart(dev) end
  self.callbacks.cameraNotInUse =
    function(dev) cameraFlasherStop(dev) mbStop(dev) end
  self.callbacks.micInUse =
    function(dev) micFlasherStart(dev) mbStart(dev) end
  self.callbacks.micNotInUse =
    function(dev) micFlasherStop(dev) mbStop(dev) end
  self.callbacks.mute =
    function(dev) cameraFlasherMute() micFlasherMute() end
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
    if audiodeviceTimerInterval then
      self.audiodeviceTimer:stop()
    end
  end

  return self
end

--- WatcherWatcher:mute()
--- Method
--- Mute any visual indicators until something further causes them
--- to re-start.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Nothing
function WW:mute()
  self.log.d("Muting")

  if self.callbacks.mute then
    local ok, err = pcall(function() self.callbacks.mute() end)
    if not ok then
      self.log.ef("Error calling mute callback: %s", err)
    end
  end
end

--- WatcherWatcher:bindHotKeys(table)
--- Method
--- The method accepts a single parameter, which is a table. The keys of the
--- table are strings that describe the action performed, and the values of
--- the table are tables containing modifiers and keynames/keycodes. E.g.
---   {
---     mute = {{"cmd", "alt"}, "s"},
---     stop = {{"cmd", "alt"}, "s"}
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
    mute = hs.fnutils.partial(self.stop, self),
    stop = hs.fnutils.partial(self.stop, self)
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
  if self.honorZoomMuteStatus then
    local zoomApp = hs.application.get("zoom.us")
    if zoomApp then
      if zoomApp:findMenuItem({ "Meeting", "Unmute Audio" }) then
        -- Zoom is running and has audio muted. Treat mics as muted.
        -- This isn't perfect as we don't know for sure that Zoom
        -- has the microphone open.
        return {}
      end
    end
  end
  return hs.fnutils.filter(
    hs.audiodevice.allInputDevices(),
    function(a) return a:inUse() end)
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
function WW:cameraWatcherCallback(camera, change)
  if change == "Added" then
    self.log.d("Starting watcher on new camera " .. camera:name())
    local propertyCallback =
      hs.fnutils.partial(self.cameraPropertyCallback, self)
    camera:setPropertyWatcherCallback(propertyCallback)
    camera:startPropertyWatcher()
  elseif change == "Removed" then
    self.log.d("Camera removed")
  else
    self.log.d("Unknowm watcher change: " .. change)
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
        local ok, err = pcall(function() self.callbacks.cameraInUse(dev) end)
        if not ok then
          self.log.ef("Error calling cameraInUse callback: %s", err)
        end
      end
    else
      if self.callbacks.cameraNotInUse then
        local ok, err = pcall(function() self.callbacks.cameraNotInUse(dev) end)
        if not ok then
          self.log.ef("Error calling cameraNotInUse callback: %s", err)
        end
      end
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
      local ok, err = pcall(function() self.callbacks.cameraInUse(dev) end)
      if not ok then
        self.log.ef("Error calling cameraInUse callback: %s", err)
      end
    end
  else
    self.log.d("Camera not in use. Ignoring.")
  end
end

--- WatcherWatcher:audiodeviceWatcherCallback()
--- Method
--- Callback for hs.audiodevice.watcher
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
      self.log.ef("Unkown audiodevice UID %s", uid)
      return
    end
    if dev:inUse() then
      self:micInUse(dev)
    else
      self:micNotInUse(dev)
    end
  end
end

-- WatcherWatcher:micInUse()
-- Handle transition of a microphone to being in use.
-- Parameters:
--   * hs.audiodevice instance
--
-- Returns:
--   * Nothing
function WW:micInUse(device)
  self.log.df("Microphone %s in use", device:name())
  if self.callbacks.micInUse then
    local ok, err = pcall(function() self.callbacks.micInUse(device) end)
    if not ok then
      self.log.ef("Error calling micInUse callback: %s", err)
    end
  end
end

-- WatcherWatcher:micNotInUse()
-- Handle transition of a microphone to being not in use.
-- Parameters:
--   * hs.audiodevice instance
--
-- Returns:
--   * Nothing
function WW:micNotInUse(device)
  self.log.df("Microphone %s not in use", device:name())
  if self.callbacks.micNotInUse then
    local ok, err = pcall(function() self.callbacks.micNotInUse(device) end)
    if not ok then
      self.log.ef("Error calling micInUse callback: %s", err)
    end
  end
end

-- WatcherWatcher:checkAudiodeviceForChange()
-- Check status of audiodevice against what is in self.audiodevicestate
-- (table keyed by uids, with false == not in use, true == in use)
-- and invoke state changes as approproate.
-- Parameters:
--   * hs.audiodevice instance
--
-- Returns:
--   * Nothing
function WW:checkAudiodeviceForChange(device)
  local oldstate = self.audiodevicestate[device:uid()] or false
  local state = device:inUse()
  if state and self.honorZoomMuteStatus then
    local zoomApp = hs.application.get("zoom.us")
    if zoomApp then
      if zoomApp:findMenuItem({ "Meeting", "Unmute Audio" }) then
        -- Zoom is running and has audio muted. Treat mic as muted.
        -- This isn't perfect as we don't know for sure that Zoom
        -- has the microphone open.
        state = false
      end
    end
  end
  if state ~= oldstate then
    self.audiodevicestate[device:uid()] = state
    if state then
      self:micInUse(device)
    else
      self:micNotInUse(device)
    end
  end
end

-- WatcherWatcher:audioDeviceTimerFunction()
--
function WW:audioDeviceTimerFunction()
  hs.fnutils.ieach(
    hs.audiodevice.allInputDevices(),
    hs.fnutils.partial(self.checkAudiodeviceForChange, self))
end

return WW

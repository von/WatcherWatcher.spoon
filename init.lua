--- === WatcherWatcher ===
--- Who watches the watchers? Monitor cameras and microphones for usage.
--- Inspired by and kudos to:
---   OverSight (https://objective-see.org/products/oversight.html)
---   https://developer.okta.com/blog/2020/10/22/set-up-a-mute-indicator-light-for-zoom-with-hammerspoon
---   http://www.hammerspoon.org/Spoons/MicMute.html
---   https://github.com/jpf/Zoom.spoon
---
--- Behavior when a camera or microphone turning on is configurable
--- by adding WatcherWatcher.Indicators.
---
--- The default is to add two indicators: a WatcherWatcher.Menubar and
--- a WatcherWatcher.ScreenBorder. The default can be disabled by
--- setting WatcherWatcher.enableMenubar and/or
--- WatcherWatcher.enableDefaultIndicators to false before
--- calling WatcherWatcher:start().

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

--- WatcherWatcher.honorZoomMuteStatus
--- Variable
--- Zoom activiates the microphone and then implements its own mute, so
--- will present a false positive. If honorZoomMuteStatus is true, then
--- honor Zoom's microphone state over that of the system if it is running.
--- Default is true.
WW.honorZoomMuteStatus = true

--- WatcherWatcher.zoomMuteTimerInterval
--- Variable
--- Zoom muting/unmuting does not trigger a callback, so if we are honoring
--- Zoom mute status, we need to manually check Zoom's state to see if it
--- has the microphone muted.
--- Default is 5 seconds.
WW.zoomMuteTimerInterval = 5

--- WatcherWatcher.enableMenubar
--- Variable
--- Display the an indicator in the Mac menubar (via the Menubar class)
--- when a camera or microphone is active.
WW.enableMenubar = true

--- WatcherWatcher.enableDefaultIndicators
--- Variable
--- Enable the default indicator, which is a ScreenBorder
WW.enableDefaultIndicators = true

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

  self.ScreenBorder = dofile(hs.spoons.resourcePath("ScreenBorder.lua"))
  self.ScreenBorder:init(self)

  self.Menubar = dofile(hs.spoons.resourcePath("Menubar.lua"))
  self.Menubar:init(self)

  -- List of Indicator instances we are driving.
  self.indicators = {}

  return self
end

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
    self.log.d("Starting monitoring of cameras")
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
    self.log.d("Starting monitoring of microphones")
    local audiodeviceWatcherCallback = hs.fnutils.partial(
      WW.audiodeviceWatcherCallback, self)
    hs.audiodevice.watcher.setCallback(audiodeviceWatcherCallback)
    hs.audiodevice.watcher.start()

    self:setupAudiodeviceCallbacks()

    if self.honorZoomMuteStatus then
      self.audiodevicestate = {}
      self.log.df(
        "Starting Zom mute timer (interval: %d)",
        self.zoomMuteTimerInterval)
      self.zoomMuteTimer = hs.timer.doEvery(
        self.zoomMuteTimerInterval,
        hs.fnutils.partial(self.zoomMuteTimerFunction, self))
      self.zoomMuteTimer:start()
    end
  end

  if self.enableMenubar then
    self.menubar = WW.Menubar
    self.menubar:start()
    self:addIndicator(self.menubar)
  end

  if self.enableDefaultIndicators then
    self.log.d("Adding default ScreenBorder indicator")
    local sb = self.ScreenBorder:new()
    self:addIndicator(sb)
  end

  -- Refresh indicators on screen changes to apply any geometry changes
  self.screenWatcher = hs.screen.watcher.new(
    hs.fnutils.partial(self.refreshAllIndicators, self)):start()

  return self
end

--- WatcherWatcher:addIndicator()
--- Method
--- Given an Indicator (presumably a subclass) instance, activate it and
--- set it up to show status.
---
--- Parameters:
---   * indicator: Indicator instance
---
--- Returns:
---   * Nothing
function WW:addIndicator(indicator)
  table.insert(self.indicators, indicator)
  self.log.df("Added Indicator: %d total", #self.indicators)
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
    if honorZoomMuteStatus then
      self.zoomMuteTimer:stop()
    end
  end

  hs.fnutils.each(self.indicators,
    function(indicator)
      local ok, err = pcall(function() indicator.delete() end)
      if not ok then
        self.log.ef("Error calling indicator.delete(): %s", err)
      end
    end)

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

  hs.fnutils.each(self.indicators,
    function(indicator)
      local ok, err = pcall(function() indicator:mute() end)
      if not ok then
        self.log.ef("Error calling indicator.mute(): %s", err)
      end
    end)
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

--- WatcherWatcher:cameraInUse()
--- Method
--- Returns true if a camera is in use.
--- If monitorCameras is false, always returns false.
---
--- Parameters:
---   * None
---
--- Returns:
---   * true if a camera is in use, false otherwise.
function WW:cameraInUse()
  return hs.fnutils.some(
    hs.camera.allCameras(),
    function(c) return c:isInUse() end)
end

--- WatcherWatcher:cameraOrMicInUse()
--- Method
--- Returns true if a camera or microhone is in use.
--- See cameraInUse() and micInUse() for caveats.
---
--- Parameters:
---   * None
---
--- Returns:
---   * true if a camera or is in use, false otherwise.
function WW:cameraOrMicInUse()
  return self:micInUse() or self:cameraInUse()
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

--- WatcherWatcher:micInUse()
--- Method
--- Is a microphone in use?
--- If monitorMics is false, always returns false.
--- If honorZoomMuteStatus is true, always returns false if Zoom is muted.
---
--- Parameters:
---   * None
---
--- Returns:
---   * true if a microphone is in use, false otherwise.
function WW:micInUse()
  if not self.monitorMics then
    return false
  end
  if self.honorZoomMuteStatus and self.ZMM:muted() then
    return false
  end
  return hs.fnutils.some(
    hs.audiodevice.allInputDevices(),
    function(a) return a:inUse() end)
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

--- WatcherWatcher:updateAllIndicators()
--- Method
--- Update all attached indicators (including the Menubar).
--- Parameters:
---   * instigator (optional): hs.camera or hs.microphone instance spurring
---     the update.
---
--- Returns:
---   * Nothing
function WW:updateAllIndicators(instigator)
  self.log.df("Updating %s indicators", #self.indicators)
  hs.fnutils.each(self.indicators,
    function(indicator)
      local ok, err = pcall(function() indicator:update(instigator) end)
      if not ok then
        self.log.ef("Error calling indicator.update callback: %s", err)
      end
    end)
end

--- WatcherWatcher:refreshAllIndicators()
--- Method
--- Refresh all attached indicators (including the Menubar).
--- Presumably due to a screen geometry change.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function WW:refreshAllIndicators()
  self.log.df("Refreshing %d indicators", #self.indicators)
  hs.fnutils.each(self.indicators,
    function(indicator)
      local ok, err = pcall(function() indicator:refresh() end)
      if not ok then
        self.log.ef("Error calling indicator.refresh callback: %s", err)
      end
    end)
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
    if self.delayInUseCallbacks > 0 then
      self.log.df("Delaying callback from camera %s for %f seconds.",
        camera:name(), self.delayInUseCallbacks)
      hs.timer.doAfter(self.delayInUseCallbacks,
        hs.fnutils.partial(self.cameraInUseDelayedCallback,
          self, camera, prop, scope, eventnum))
      return
    end
    self:updateAllIndicators(camera)
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
  self:updateAllIndicators(camera)
end

--- WatcherWatcher:audiodeviceWatcherCallback()
--- Method
--- Callback for hs.audiodevice.watcher
---
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
---
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
end

--- WatcherWatcher:audiodeviceCallback()
--- Method
--- Callback for audiodevice:watcherCallback()
---
--- Parameters:
---   * uid (string)
---   * eventname (string)
---   * scope (string)
---   * element (int)
---
--- Returns:
---   * Nothing
function WW:audiodeviceCallback(uid, eventname, scope, element)
  self.log.df("audiodeviceCallback(%s, %s, %s, %d)",
    uid, eventname, scope, element)
  if eventname == "gone" then
    dev = hs.audiodevice.findDeviceByUID(uid)
    if not dev then
      self.log.ef("Unkown audiodevice UID %s", uid)
      return
    end
    self:updateAllIndicators(dev)
  end
end

-- WatcherWatcher:checkAudiodeviceForChange()
-- Check status of audiodevice against what is in self.audiodevicestate
-- (table keyed by uids, with false == not in use, true == in use)
-- and invoke state changes as approproate.
--
-- Parameters:
--   * hs.audiodevice instance
--
-- Returns:
--   * Nothing
function WW:checkAudiodeviceForChange(device)
  local oldstate = self.audiodevicestate[device:uid()] or false
  local state = device:inUse()
  if state and self.honorZoomMuteStatus then
    if self:checkZoomMuted() then
      -- Zoom is running and has audio muted. Treat mic as muted.
      -- This isn't perfect as we don't know for sure that Zoom
      -- has the microphone open.
      state = false
    end
  end
  if state ~= oldstate then
    self.log.df(
        "Detected change in audio device %s status. Updating indicators",
        device.name)
    self.audiodevicestate[device:uid()] = state
    self:updateAllIndicators(device)
  end
end

-- WatcherWatcher:zoomMuteTimerFunction()
--
-- Called by zoomMuteTimer
function WW:zoomMuteTimerFunction()
  -- Check for state change, taking Zoom mute into account
  -- Update indicators if state change has occurred.
  hs.fnutils.ieach(
    hs.audiodevice.allInputDevices(),
    hs.fnutils.partial(self.checkAudiodeviceForChange, self))
end

-- WatcherWatcher:checkZoomMuted()
-- Is Zoom running and muted? Intended for use with honorZoomMuteStatus
-- Note, this is imperfect as we don't know for sure Zoom has a particular
-- microphone muted.
--
-- Parameters:
--   * None
--
-- Returns:
--   * True if Zoom running and muted, false otherwise
function WW:checkZoomMuted()
  local zoomApp = hs.application.get("zoom.us")
  if zoomApp then
    if zoomApp:findMenuItem({ "Meeting", "Unmute Audio" }) then
      -- Zoom is running and has audio muted. Treat mic as muted.
      -- This isn't perfect as we don't know for sure that Zoom
      -- has the microphone open.
      return true
    end
  end
  return false
end

return WW

--- === WatcherWatcher.ZoomMuteMonitor ===
--- Extension to monitor Zoom mute state. Zoom apparently grabs the
--- microphone and then uses internal controls to mute/unmute it, so
--- it doesn't generate audiodevice callbacks as it mute/unmutes.
---
--- For a full-featured Zoom interface, see:
---   https://github.com/jpf/Zoom.spoon

local ZMM = {}

--- ZoomMuteMonitor.timerInterval
--- Variable
--- How often, in seconds, to poll Zoom mute state.
--- Default is 5 seconds.
ZMM.timerInterval = 5

--- ZoomMuteMonitor:debug(enable)
--- Method
--- Enable or disable debugging
---
--- Parameters:
---  * enable - Boolean indicating whether debugging should be on
---
--- Returns:
---  * Nothing
function ZMM:debug(enable)
  if enable then
    self.log.setLogLevel('debug')
    self.log.d("Debugging enabled")
  else
    self.log.d("Disabling debugging")
    self.log.setLogLevel('info')
  end
end

--- ZoomMuteMonitor:init()
--- Method
--- Initializes the ZoomMuteMonitor.
---
--- Parameters:
---  * WatcherWatcher instance
---
--- Returns:
---  * ZoomMuteMonitor object

function ZMM:init(ww)
  self.log = hs.logger.new("ZMM")

  self.ww = ww -- Currently unused

  -- Last known state of Zoom mute
  self.lastZoomMuteState = nil

  -- Callback on mute state changes
  self.callback = nil

  return self
end

--- ZoomMuteMonitor:setCallback()
--- Method
--- Set callback for Zoom mute state changes.
---
--- Parameters:
---  * Callback function. Should take a single parameter, which is a boolean
---    indicating new state of Zoom mute.
---
--- Returns:
---  * Nothing
function ZMM:setCallback(fn)
  self.callback = fn
end

--- ZoomMuteMonitor:start()
--- Method
--- Start background activity.
---
--- Parameters:
---  * None
---
--- Returns:
---  * ZoomMuteMonitor object
function ZMM:start()
  self.log.d("Starting")

  -- Watch for Zoom starting and stopping
  self.appWatcher = hs.application.watcher.new(
    hs.fnutils.partial(self.appWatcherCallback, self))
  self.appWatcher:start()

  -- Timer that will run while Zoom is active to monitor mute
  self.timer = hs.timer.doEvery(
    self.timerInterval,
    hs.fnutils.partial(self.timerFunction, self))

  if hs.application.get("zoom.us") then
    self.log.d("Zoom is already running, starting timer.")
    self.timer:start()
  end

  return self
end

--- ZoomMuteMonitor:stop()
--- Method
--- Stop background activity.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Nothing
function ZMM:stop()
  self.log.d("Stopping")
  self.appWatcher:stop()
  self.timer:stop()
  return self
end

--- ZoomMuteMonitor:muted()
--- Is Zoom running and muted?
---
--- Parameters:
---   * None
---
--- Returns:
---   * True if Zoom running and muted, false otherwise
function ZMM:muted()
  local zoomApp = hs.application.get("zoom.us")
  if zoomApp then
    -- Zoom is running
    if zoomApp:findMenuItem({ "Meeting", "Unmute Audio" }) then
      -- Zoom has audio muted.
      return true
    end
  end
  return false
end

-- ZoomMuteMonitor:appWatcherCallback()
-- Method
-- Callback function for hs.application.watcher() started in start()
--
-- Parameters:
--   * A string containing the name of the application
--   * An event type (see the constants defined above)
--   * An hs.application object representing the application, or
--     nil if the application couldn't be found
--
--  Returns:
--   * Nothing
function ZMM:appWatcherCallback(appName, eventType, app)
  if appName ~= "zoom.us" then
    return
  end
  if eventType == hs.application.watcher.launched then
    self.log.d("Zoom launch detected. Starting timer.")
    self.timer:start()
  elseif eventType == hs.application.watcher.terminateda then
    self.log.d("Zoom termination detected. Stopping timer.")
    self.timer:stop()
  end
end


-- ZoomMuteMonitor:timerFunction()
-- Method
-- Function called by timer started when Zoom is running.
-- Checks for changes in Zoom mute state and calls self.callback
-- if a change is detected. Uses self.lastZoomMuteState to store
-- last mute state.
--
-- Parameters:
--  * None
--
-- Returns:
--  * Nothing
function ZMM:timerFunction()
  local muteState = self:muted()
  if self.lastZoomMuteState == nil or muteState ~= self.lastZoomMuteState then
    self.log.df("Mute state changed: %s", muteState)
    self.lastZoomMuteState = muteState
    local ok, err = pcall(function() self.callback(muteState) end)
    if not ok then
      self.log.ef("Error calling callback: %s", err)
    end
  end
end

return ZMM

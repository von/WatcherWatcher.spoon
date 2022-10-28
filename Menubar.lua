--- === WatcherWatcher.Menubar ===
--- Callback for WatcherWatcher to create a menubar item when a microphone
--- or camera is in use.

local MB = {}

-- Constants
MB.GREEN_DOT = "🟢"
MB.RED_DOT = "🔴"

--- Menubar.title
--- Variable
--- A table with the following keys:
---   * cameraInUse: Menubar title if a camera is in use.
---   * micInUse: Menubar title if a microphone is in use.
---   * cameraAndMicInUse: Menubar title if a camera and a microphone are in use.
---   * nothingInUse: Menubar title if nothing is in use.
MB.title = {
  cameraInUse =  "📷",
  micInUse =  "🎙",
  cameraAndMicInUse = "📷🎙",
  nothingInUse = MB.GREEN_DOT
}

--- Menubar.monitorCameras
--- Variable
--- If true, includes camera in menubar. Default is true.
MB.monitorCameras = true

--- Menubar.monitorMics
--- Variable
--- If true, includes microphones in menubar. Default is true.
MB.monitorMics = true

--- Menubar:init()
--- Method
--- Initialize module.
--- Parameters:
---   * None
---
--- Returns:
---   * Menbar instance
function MB:init()
  -- Set up logger
  self.log = hs.logger.new("Menubar")

  return self
end

--- Menubar:debug(enable)
--- Method
--- Enable or disable debugging
---
--- Parameters:
---  * enable - Boolean indicating whether debugging should be on
---
--- Returns:
---  * Nothing
function MB:debug(enable)
  if enable then
    self.log.setLogLevel('debug')
    self.log.d("Debugging enabled")
  else
    self.log.d("Disabling debugging")
    self.log.setLogLevel('info')
  end
end

--- Menubar:callbacks()
--- Method
--- Return functions appropriate for WatcherWatcher callbacks that
--- will cause menubar to appear and hide.
--- Parameters:
---   * None
---
--- Returns:
---   * Start callback function. Takes a single arugment, which is a
---     hs.audiodevice or a hs.camera device which has come into use.
---   * Stop callback function. Takes a single arugment, which is a
---     hs.audiodevice or a hs.camera device which has come into use.
function MB:callbacks()
  self.menubar = hs.menubar.new()
  self.menubar:setMenu(hs.fnutils.partial(self.menubarCallback, self))
  self:update()

  local start = hs.fnutils.partial(self.update, self)
  local stop = hs.fnutils.partial(self.update, self)

  return start, stop
end

--- Menubar:update()
--- Method
--- Set the menubar icon depending on state of usage of cameras and
--- microphones.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing

function MB:update()
  self.log.d("Updating menubar icon")
  local cameraInUse = self.monitorCameras and not hs.fnutils.every(
      hs.camera.allCameras(),
      function(c) return not c:isInUse() end)
  local micInUse = self.monitorMics and not hs.fnutils.every(
      hs.audiodevice.allInputDevices(),
      function(m) return not m:inUse() end)

  if cameraInUse and micInUse then
    self.menubar:setTitle(self.title.cameraAndMicInUse)
  elseif cameraInUse then
    self.menubar:setTitle(self.title.cameraInUse)
  elseif micInUse then
    self.menubar:setTitle(self.title.micInUse)
  else
    self.menubar:setTitle(self.title.nothingInUse)
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
function MB:menubarCallback(modifiers)
  local t = {}
  if self.monitorCameras then
    hs.fnutils.each(hs.camera.allCameras(),
      function(c)
        local name = c:name()
        if c:isInUse() then
          name = self.RED_DOT .. name
        end
        table.insert(t, { title = name })
      end)
  end
  if self.monitorMics then
    hs.fnutils.each(hs.audiodevice.allInputDevices(),
      function(m)
        local name = m:name()
        if m:inUse() then
          name = self.RED_DOT .. name
        end
        table.insert(t, { title = name })
      end)
  end
  return t
end

return MB

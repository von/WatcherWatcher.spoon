--- === WatcherWatcher.Menubar ===
--- Callback for WatcherWatcher to create a menubar item when a microphone
--- or camera is in use.

local MB = {}

-- Constants
-- Characters to potential use in the menubar title or menu itself
MB.GREEN_DOT = "🟢"
MB.RED_DOT = "🔴"
MB.ORANGE_DIAMOND = "🔶"  -- U+1F536
MB.CAMERA = "📷"
MB.MICROPHONE = "🎙"

--- Menubar.title
--- Variable
--- A table with the following keys:
---   * cameraInUse: Menubar title if a camera is in use.
---   * micInUse: Menubar title if a microphone is in use.
---   * cameraAndMicInUse: Menubar title if a camera and a microphone are in use.
---   * nothingInUse: Menubar title if nothing is in use.
MB.title = {
  cameraInUse =  MB.RED_DOT,
  micInUse =  MB.RED_DOT,
  cameraAndMicInUse = MB.RED_DOT,
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

--- Menubar.menubarIfNothingInUse
--- Variable
--- If true, be present on menubar if nothing is in use.
MB.menubarIfNothingInUse = false

--- Menubar:init()
--- Method
--- Initialize module.
--- Parameters:
---   * Creating WatcherWatcher instance
---
--- Returns:
---   * Menbar instance
function MB:init(ww)
  self.ww = ww
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
  -- First agument is whether item starts in menubar
  self.menubar = hs.menubar.new(self.menubarIfNothingInUse)
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
  local cameraInUse = self.monitorCameras and (#self.ww:camerasInUse() > 0)
  local micInUse = self.monitorMics and (#self.ww:micsInUse() > 0)

  -- Note that ordering of returnToMenuBar() and setTitle() calls here
  -- is important as calling setTitle() first seems to result in
  -- the it not taking effect.
  if cameraInUse and micInUse then
    self.log.d("Updating menubar icon: Camera and microphone in use")
    self.menubar:returnToMenuBar()
    self.menubar:setTitle(self.title.cameraAndMicInUse)
  elseif cameraInUse then
    self.log.d("Updating menubar icon: Camera in use")
    self.menubar:returnToMenuBar()
    self.menubar:setTitle(self.title.cameraInUse)
  elseif micInUse then
    self.log.d("Updating menubar icon: Microphone in use")
    self.menubar:returnToMenuBar()
    self.menubar:setTitle(self.title.micInUse)
  else
    self.log.d("Updating menubar icon: Nothing in use")
    if self.menubarIfNothingInUse then
      self.menubar:returnToMenuBar()
      self.menubar:setTitle(self.title.nothingInUse)
    else
      self.menubar:removeFromMenuBar()
    end
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
  table.insert(t,
    { title = "Disable Flashers", fn = function() self.ww:mute() end })
  if self.monitorCameras then
    hs.fnutils.each(self.ww:camerasInUse(),
      function(c)
        local name = c:name()
        name = self.CAMERA .. name
        table.insert(t, { title = name, indent = 0 })
      end)
  end
  if self.monitorMics then
    hs.fnutils.each(self.ww:micsInUse(),
      function(m)
        local name = m:name()
        name = self.MICROPHONE .. name
        table.insert(t, { title = name, indent = 0 })
      end)
  end
  return t
end

return MB

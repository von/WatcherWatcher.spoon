--- === WatcherWatcher.Menubar ===
--- Callback for WatcherWatcher to create a menubar item when a microphone
--- or camera is in use.

-- Menubar is a subclass of WatcherWatcher.Indicator
local Indicator = dofile(hs.spoons.resourcePath("Indicator.lua"))
local MB = Indicator:subclass()

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

--- Menubar:new()
--- Method
--- Unimplemeneted method. Menubar is a unary object.
---
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function MB:new()
  self.log.ef("Unimplemented Menubar.new() called")
end

--- Menubar:createCanvas()
--- Method
--- Unimplemeneted method. Menubar does not use a canvas.
---
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function MB:createCanvas()
  self.log.ef("Unimplemented Menubar.createCanvas() called")
end

--- Menubar:start()
--- Method
--- Start background activity.
---
--- Parameters:
---   * None
---
--- Returns:
---   * Menubar instance
function MB:start(ww)
  -- First agument is whether item starts in menubar
  self.menubar = hs.menubar.new(self.menubarIfNothingInUse)
  -- Create menu on demand so we show active cameras and microphones.
  self.menubar:setMenu(hs.fnutils.partial(self.menubarCallback, self))
  self:update()
  return self
end

--- Menubar:refresh()
--- Does nothing.
---
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function MB:refresh()
  self.log.d("refresh() called - doing nothing.")
end

--- Menubar:update()
--- Method
--- Set the menubar icon depending on state of usage of cameras and
--- microphones.
---
--- Parameters:
---   * instigator (optional): hs.camera or hs.microphone instance which
---     caused the callback.
---
--- Returns:
---   * Nothing

function MB:update(instigator)
  local cameraInUse = self.ww:cameraInUse()
  local micInUse = self.ww:micInUse()

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

--- Menubar:show()
--- Method
--- Show the menubar icon.
---
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function MB:show()
  self.log.d("Showing menubar icon")
  self.menubar:returnToMenuBar()
end

--- Menubar:hide()
--- Method
--- Hide the menubar icon.
---
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function MB:hide()
  self.log.d("Hiding menubar icon")
  self.menubar:removeFromMenuBar()
end

--- Menubar:mute()
--- Method
--- Does nothing.
---
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function MB:mute()
  self.log.d("mute() called - doing nothing")
end

--- Menubar:delete()
--- Method
--- Destroy the Menubar instance.
---
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function MB:delete()
  self.log.d("Deleting menubar")
  self.menubar:delete()
  self.menubar = nil
end

--- Menubar:menubarCallback()
--- Method
--- Callback for when user clicks on the menubar item.
---
--- Parameters:
---   * table indicating which keyboard modifiers were held down
---
--- Returns:
---   * table with menu - see hs.menubar.setMenu()
function MB:menubarCallback(modifiers)
  local t = {}
  table.insert(t,
    { title = "Mute Indicators", fn = function() self.ww:mute() end })
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

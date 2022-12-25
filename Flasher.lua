--- === WatcherWatcher.Flasher ===
--- Callback for WatcherWatcher to create a flashing icon on the screen
--- when a microphone or camera is in use.

local Flasher = {}

--- Flasher.geometry
--- Variable
--- Table with geometry for icon. Should be a square.
--- Can have negative values for x and y, in which case they are treated
--- as offsets from right or bottom of screen respectively.
Flasher.geometry = { x = -60, y = 20, w = 50, h = 50 }

--- Flasher.fillColor
--- Variable
--- Table with fill color for icon.
Flasher.fillColor = { alpha = 1.0, red = 1.0  }

--- Flasher.blinkInterval
--- Variable
--- Frequency of icon blinking in seconds. If zero, disables blinking.
Flasher.blinkInterval = 1.0

--- Flasher:init()
--- Method
--- Initialize module.
--- Parameters:
---   * Creating WatcherWatcher instance
---
--- Returns:
---   * Flasher instance
function Flasher:init(ww)
  self.ww = ww
  -- Set up logger
  self.log = hs.logger.new("Flasher")

  return self
end

--- Flasher:debug(enable)
--- Method
--- Enable or disable debugging
---
--- Parameters:
---  * enable - Boolean indicating whether debugging should be on
---
--- Returns:
---  * Nothing
function Flasher:debug(enable)
  if enable then
    self.log.setLogLevel('debug')
    self.log.d("Debugging enabled")
  else
    self.log.d("Disabling debugging")
    self.log.setLogLevel('info')
  end
end

--- Flasher:new()
--- Method
--- Return a new Flasher instance with a copy of all the module variables
--- and which can be configured separately.
--- Parameters:
---   * Name (optional): Name to use for logging
---
--- Returns:
---   * New hs.WatcherWatcher.Flasher instance
function Flasher:new(name)
  local f = {}
  for k,v in pairs(self) do
    f[k] = v
  end
  if name then
    f.name = name
    f.log = hs.logger.new("Flasher(" .. name ..")")
    f.log.setLogLevel(self.log.getLogLevel())
  end
  return f
end

-- Flasher:createIcon()
-- Method
-- Create an hs.canvas object representing the icon.
-- Parameters:
--   * None
--
-- Returns:
--   * hs.canvas instance
function Flasher:createIcon()
  -- XXX I suspect this doesn't handle multiple screens correctly
  local geometry = self.geometry
  -- Handle negative x or y as offsets from right or bottom
  -- XXX Primary or main screen?
  local screenFrame = hs.screen.primaryScreen():frame()
  if geometry.x < 0 then
    geometry.x = screenFrame.w + geometry.x
  end
  if geometry.y < 0 then
    geometry.y = screenFrame.h + geometry.y
  end
  local icon = hs.canvas.new(geometry)
  if not icon then
    self.e("Failed to create icon")
    return nil
  end
  icon:appendElements({
      -- A circle basically filling the canvas
      type = "circle",
      center = { x = ".5", y = ".5" },
      radius = ".5",
      fillColor = self.fillColor,
      action = "fill"
    })

  return icon
end

--- Flasher:callbacks()
--- Method
--- Return functions appropriate for WatcherWatcher callbacks that
--- will cause icon to appear and hide.
--- Parameters:
---   * None
---
--- Returns:
---   * Start callback function. Takes a single arugment, which is a
---     hs.audiodevice or a hs.camera device which has come into use.
---   * Stop callback function. Takes a single arugment, which is a
---     hs.audiodevice or a hs.camera device which has come into use.
---   * Mute callback function. Takes no arguments.
function Flasher:callbacks()
  self.icon = self:createIcon()

  if self.blinkInterval > 0 then
    self.blinkTimer = hs.timer.new(
      self.blinkInterval,
      hs.fnutils.partial(self.blink, self))
  end

  local start = hs.fnutils.partial(self.show, self)
  local stop = hs.fnutils.partial(self.hide, self)
  local mute = hs.fnutils.partial(self.hide, self)

  return start, stop, mute
end

--- Flasher:show()
--- Method
--- Show the icon (possibilty starting to blink it).
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Flasher:show()
  if self.blinkInterval > 0 then
    self.log.d("Starting icon blinking")
    self.blinkTimer:start()
  else
    self.log.d("Showing icon")
    self.icon:show()
  end
end

--- Flasher:blink()
--- Method
--- Toggle the icon.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Flasher:blink()
  if self.icon:isShowing() then
    self.icon:hide()
  else
    self.icon:show()
  end
end

--- Flasher:hide()
--- Method
--- Hide the icon.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Flasher:hide()
  if self.blinkInterval > 0 then
    self.log.d("Stopping icon blinking")
    self.blinkTimer:stop()
    self.icon:hide()
  else
    self.log.d("Hiding icon")
    self.icon:hide()
  end
end

return Flasher

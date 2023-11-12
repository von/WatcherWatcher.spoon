--- === WatcherWatcher.Flasher ===
--- Callback for WatcherWatcher to create a flashing icon on the screen
--- when a microphone or camera is in use.


-- Flasher is a subclass of WatcherWatcher.Indicator
local Indicator = dofile(hs.spoons.resourcePath("Indicator.lua"))
local Flasher = Indicator:subclass()

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
---   * Flasher module
function Flasher:init(ww)
  -- Initialize super class
  Indicator.init(self, ww)
  -- Override logger with one with my name
  self.log = hs.logger.new("Flasher")

  return self
end

--- Flasher:new()
--- Method
--- Return a new Flasher instance with a copy of all the module variables
--- and which can be configured separately.
--- Parameters:
---   * Name (optional): Name to use for logging
---   * options (option): dictionary of options for new instance
---
--- Returns:
---   * New hs.WatcherWatcher.Flasher instance
function Flasher:new(name, options)
  self.log.d("Creating new Flasher")
  -- Create a new instance of Flasher
  local s = Indicator.new(self, Flasher, name, options)
  if not s then
    return nil -- Assume Indicator.new() logged error
  end

  return s
end

--- Flasher:createCanvas()
--- Method
--- Create and return hs.canvas representing graphical indicator.
---
--- Parameters:
---   * None
---
--- Returns:
---   * New hs.canvas instance
function Flasher:createCanvas()
  -- Call super call to create base canvas
  local canvas = Indicator.createCanvas(self)

  -- Fill canvas with a circle
  canvas:appendElements({
    type = "circle",
    center = { x = ".5", y = ".5" },
    radius = ".5",
    fillColor = self.fillColor,
    action = "fill"
  })

  if self.blinkInterval > 0 then
    self.log.df("Starting blink timer with interval %d", self.blinkInterval)
    self.blinkTimer = hs.timer.new(
      self.blinkInterval,
      hs.fnutils.partial(self.blink, self))
  end

  return canvas
end

--- Flasher:show()
--- Method
--- Show the indicator (possibilty starting to blink it).
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Flasher:show()
  if self.blinkInterval > 0 then
    self.log.d("Starting indicator blinking")
    self.blinkTimer:start()
  else
    self.log.d("Showing indicator")
    self.canvas:show()
  end
end

--- Flasher:blink()
--- Method
--- Toggle the indicator.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Flasher:blink()
  if self.canvas:isShowing() then
    self.canvas:hide()
  else
    self.canvas:show()
  end
end

--- Flasher:hide()
--- Method
--- Hide the indicator.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Flasher:hide()
  if self.blinkInterval > 0 then
    self.log.d("Stopping indicator blinking")
    self.blinkTimer:stop()
    self.canvas:hide()
  else
    self.log.d("Hiding indicator")
    self.canvas:hide()
  end
end

return Flasher

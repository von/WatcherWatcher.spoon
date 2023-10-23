--- === WatcherWatcher.Indicator ===
--- Abstract base class for an on-screen indicator for use by
--- WatcherWatcher to indicate a camera or microphone is in use.

-- Indicator
local Indicator = {}

-- Failed table lookups on the instances should fallback to the class table
-- to get methods
Indicator.__index = Indicator

-- Calls to Indicator() return Indicator.new()
setmetatable(Indicator, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})

--- Indicator:init()
--- Method
--- Initialize module.
--- Parameters:
---   * Creating WatcherWatcher instance
---
--- Returns:
---   * Indicator instance
function Indicator:init(ww)
  -- Set up logger
  self.log = hs.logger.new("Indicator")

  if not ww then
    self.log.e("new() called with ww == nil")
    return nil
  end

  self.ww = ww
  self.geometry = nil

  return self
end

--- Indicator:subclass()
--- Method
--- Return a table suitable for creating a subclass of Indicator.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Table suitable for constructing subclass
function Indicator:subclass()
  local subcls = {}
  
  -- Failed table lookups on the instances should fallback to the
  -- subclass table to get methods
  subcls.__index = subcls
  
  -- Syntactic sugar
  subcls.__super = Indicator

  -- Failed lookups on subclass go to the superclass
  setmetatable(subcls, {
    __index = Indicator
  })

  return subcls
end

--- Indicator:debug()
--- Method
--- Enable or disable debugging
---
--- Parameters:
---  * enable - Boolean indicating whether debugging should be on
---
--- Returns:
---  * Nothing
function Indicator:debug(enable)
  if enable then
    self.log.setLogLevel('debug')
    self.log.d("Debugging enabled")
  else
    self.log.d("Disabling debugging")
    self.log.setLogLevel('info')
  end
end

--- Indicator:new()
--- Method
--- Return a new Indicator instance with a copy of all the module variables
--- and which can be configured separately.
--- Parameters:
---   * cls: class of instance (should be Indicator subclass)
---   * Name (optional): Name to use for logging
---   * options (option): dictionary of options for new instance
---
--- Returns:
---   * New instance of cls
function Indicator:new(cls, name, options)
  self.log.d("new() called")
  local s = setmetatable({}, cls)

  -- Create custom logger using name if given
  if name then
    s.name = name
    s.log = hs.logger.new("Flasher(" .. name ..")")
    s.log.setLogLevel(cls.log.getLogLevel())
  end

  if options then
    for k,v in pairs(options) do
      s[k] = v
    end
  end

  if not s:createCanvas() then
    return nil  -- Assume createCanvas() logged error
  end

  -- Refresh canvas on screen changes to apply any geometry changes
  s.screenWatcher = hs.screen.watcher.new(
    hs.fnutils.partial(s.refresh, s)):start()

  return s
end

--- Indicator:refresh()
--- Refresh the indicator, presumably after some configuration or screen
--- geometry change.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Indicator:refresh()
  if not self.geometry then
    self.log.e("refresh() called with geometry == nil")
    return
  end
  -- Make geometry relative to primaryScreen
  -- Handle negative x or y as offsets from right or bottom
  local screenFrame = hs.screen.primaryScreen():frame()
  local x = screenFrame.x + self.geometry.x
  if self.geometry.x < 0 then
    x = x + screenFrame.w
  end
  local y = screenFrame.y + self.geometry.y
  if self.geometry.y < 0 then
    y = y + screenFrame.h
  end
  self.log.df("Refreshing icon geometry: x = %d y = %d", x, y)
  -- Note: must use named x and y coordinates here
  self.canvas:topLeft({x = x, y = y})
end

-- Indicator:createCanvas()
-- Method
-- Create self.canvas as an hs.canvas object for the indicator based on
-- self.geometry
-- Parameters:
--   * None
--
-- Returns:
--   * hs.canvas instance
function Indicator:createCanvas()
  if not self.geometry then
    self.log.e("createCanvas() called with geometry == nil")
    return
  end
  -- Make a temporary copy of our geometry as to not modify original
  local geometry = {}
  for k,v in pairs(self.geometry) do
    geometry[k] = v
  end
  -- Make geometry relative to primaryScreen
  -- Handle negative x or y as offsets from right or bottom
  local screenFrame = hs.screen.primaryScreen():frame()
  geometry.x = screenFrame.x + self.geometry.x
  if self.geometry.x < 0 then
    geometry.x = geometry.x + screenFrame.w
  end
  geometry.y = screenFrame.y + self.geometry.y
  if self.geometry.y < 0 then
    geometry.y = geometry.y + screenFrame.h
  end
  self.log.df("Placing canvas at: x = %d y = %d", geometry.x, geometry.y)

  self.canvas = hs.canvas.new(geometry)
  if not self.canvas then
    self.log.e("Failed to create canvas")
    return nil
  end
  
  return self.canvas
end

--- Indicator:callbacks()
--- Method
--- Return functions appropriate for WatcherWatcher callbacks that
--- will cause indicator to appear and hide.
--- Parameters:
---   * None
---
--- Returns:
---   * Start callback function. Takes a single arugment, which is a
---     hs.audiodevice or a hs.camera device which has come into use.
---   * Stop callback function. Takes a single arugment, which is a
---     hs.audiodevice or a hs.camera device which has come into use.
---   * Mute callback function. Takes no arguments.
function Indicator:callbacks()
  local start = hs.fnutils.partial(self.show, self)
  local stop = hs.fnutils.partial(self.hide, self)
  local mute = hs.fnutils.partial(self.hide, self)

  return start, stop, mute
end

--- Indicator:show()
--- Method
--- Show the indicator
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Indicator:show()
  if not self.canvas then
    self.log.e("show() called when canvas is nil")
    return
  end
  self.log.d("Showing indicator")
  self.canvas:show()
end

--- Indicator:hide()
--- Method
--- Hide the indicator.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Indicator:hide()
  if not self.canvas then
    self.log.e("hide() called when canvas is nil")
    return
  end
  self.log.d("Hiding indicator")
  self.canvas:hide()
end

return Indicator

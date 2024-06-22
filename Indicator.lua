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

--- Indicator.geometry
--- Variable
--- Table with geometry for indicator. Should be a square.
--- Can have negative values for x and y, in which case they are treated
--- as offsets from right or bottom of screen respectively.
--- Default is nil, which means to use whole primary screen.
Indicator.geometry = nil

--- Indicator.showFilter
--- Variable
--- showFilter should be a function which returns true if the indicator
--- show be shown. Can be one of WatcherWatcher's methods: camerasInUse()
--- micInUse(), or cameraOrMicInUse(). Or can be a custom function.
--- By default, set to cameraOrMicInUse by init().
Indicator.showFilter = nil

--- Indicator:init()
--- Method
--- Initialize module.
--- Parameters:
---   * Creating Indicator instance
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

  -- Set showFilter if not already set
  self.showFilter = self.showFilter or ww.cameraOrMicInUse

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
  local s = setmetatable({}, cls)

  -- Create custom logger using name if given
  if name then
    s.name = name
    s.log = hs.logger.new("Indicator(" .. name ..")")
    s.log.setLogLevel(cls.log.getLogLevel())
  end

  if options then
    for k,v in pairs(options) do
      s[k] = v
    end
  end

  s.canvas = s:createCanvas()
  if not s.canvas then
    self.log.e("createCanvas() returned nil")
    return nil
  end

  self.muted = false

  return s
end

--- Indicator:refresh()
--- Refresh the indicator, called at startup and when there is a screen
--- geometry change.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Indicator:refresh()
  -- We delete the canvas and recreate it to refresh it.
  if self.canvas then
    self.canvas:delete()
    self.canvas = nil
  end
  self.canvas = self:createCanvas()
  -- Make visible and appropriate to camera/microphone state
  self:update()
end

--- Indicator:createCanvas()
--- Method
--- Create and return hs.canvas representing graphical indicator.
--- This version creates an empty canvas using hs.geometry
--- Uses self.geometry. Intended to be overriden by subclasses.
--- Parameters:
---   * None
---
--- Returns:
---   * hs.canvas instance
function Indicator:createCanvas()
  -- self.geometry may be nil and will get sorted out by relativeGeometry()
  geometry = self:relativeGeometry(self.geometry)

  self.log.df("Creating canvas at: x = %d y = %d h = %d w = %d",
    geometry.x, geometry.y, geometry.h, geometry.w)

  canvas = hs.canvas.new(geometry)
  if not canvas then
    self.log.e("Failed to create canvas (hs.canvas.new() failed)")
    return nil
  end

  return canvas
end

-- Indicator:relativeGeometry()
-- Method
-- Given an hs.geometry return a copy modified to be relative to primary
-- screen. This means if x or y is negative, they are replaced by
-- values relative to the right or bottom edge of the primary screen.
-- If given nil, returns a geometry matching primary screen.
--
-- Parameters:
--   * hs.geometry instance
--     Note this is passed by reference, see:
--     https://stackoverflow.com/a/6128322/197789
--
-- Returns:
--   * hs.geometry instance modified relative to primary screen
function Indicator:relativeGeometry(geometry)
  local screenFrame = hs.screen.primaryScreen():frame()
  if geometry then
    -- geometry is a reference, copy it so we don't modify original
    geometry = hs.geometry.copy(geometry)

    -- Handle negative x or y as offsets from right or bottom
    if geometry.x < 0 then
      geometry.x = geometry.x + screenFrame.w
    end
    if geometry.y < 0 then
      geometry.y = geometry.y + screenFrame.h
    end
    -- Make given geometry relative to primaryScreen
    geometry.x = screenFrame.x + geometry.x
    geometry.y = screenFrame.y + geometry.y
  else
    -- No geometry given, use ScreenFrame
    geometry = hs.geometry.copy(screenFrame)
  end

  return geometry
end

--- Indicator:update()
--- Method
--- Called when the indicator should update its appearance based on a change
--- in the cameras or microphones in use.
---
--- Parameters:
---   * instigator (optional): The hs.camera or hs.microphone instance
---     which caused the callback to be called.
---
--- Returns:
---   * None
function Indicator:update(instigator)
  -- Assume showFilter is a WatcherWatcher method and include ww for self
  if not self.muted and self.showFilter(self.ww) then
    self:show()
  else
    self:hide()
  end
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

--- Indicator:mute()
--- Method
--- Hide the indicator until unmuted.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Indicator:mute()
  self.log.d("Muting indicator")
  self.muted = true
  self:hide()
end

--- Indicator:unmute()
--- Method
--- Allow the indicator to be shown.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Indicator:unmute()
  self.log.d("Unmuting indicator")
  self.muted = false
  self:update()
end

--- Indicator:delete()
--- Method
--- Destroy the Indicator instance.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function Indicator:delete()
  self.log.d("Deleting indicator")
  if self.canvas then
    self.canvas:delete()
    self.canvas = nil
  end
end

return Indicator

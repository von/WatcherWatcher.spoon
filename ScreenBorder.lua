--- === WatcherWatcher.ScreenBorder ===
--- Indicatgor for WatcherWatcher to create a border around the screen
--- when a microphone or camera is in use.

local SB = {}

-- ScreenBorder is a subclass of WatcherWatcher.Indicator
local Indicator = dofile(hs.spoons.resourcePath("Indicator.lua"))

-- Failed table lookups on the instances should fallback to the class table
-- to get methods
SB.__index = SB

-- Failed lookups on class go to superclass
setmetatable(SB, {
  __index = Indicator
})

--- ScreenBorder:width
--- Variable
--- Width of border as percentage of screen.
SB.width = 0.5

--- ScreenBorder:init()
--- Method
--- Initialize module.
--- Parameters:
---   * Creating WatcherWatcher instance
---
--- Returns:
---   * ScreenBorder module
function SB:init(ww)
  -- Initialize super class
  Indicator.init(self, ww)
  -- Override logger with one with my name
  self.log = hs.logger.new("ScreenBorder")

  return self
end

--- ScreenBorder:new()
--- Method
--- Return a new ScreenBorder instance with a copy of all the module variables
--- and which can be configured separately.
--- Parameters:
---   * Name (optional): Name to use for logging
---   * options (option): dictionary of options for new instance
---
--- Returns:
---   * New hs.WatcherWatcher.ScreenBorder instance
function SB:new(name, options)
  self.log.d("Creating new ScreenBorder")
  -- Create a new instance of ScreenBorder

  -- Canvas should be full size of screen
  local screenFrame = hs.screen.primaryScreen():frame()
  options = options or {}
  options.geometry = { x = 0, y = 0, w = screenFrame.w, h = screenFrame.h }
  local s = Indicator.new(self, SB, name, options)
  if not s then
    return nil -- Assume Indicator.new() logged error
  end

  -- Fill canvas with a border
  local xy = string.format("%f%%", self.width)
  local hw = string.format("%f%%", 100 - self.width * 2)

  -- For an explaination of what is going on here, see:
  --   https://github.com/Hammerspoon/hammerspoon/issues/1331
  s.canvas:appendElements({ -- Start by working on whole canvas
      action = "build", 
      type = "rectangle",

    },{ -- Remove inside of rectangle (note reversePath)
      type = "rectangle",
      frame = { x = xy, y = xy, h = hw, w = hw },
      reversePath = true,
      action = "clip"

    },{ -- Now draw border around what we just clipped
      type = "rectangle",
      frame = { x = "0%", y = "0%", h = "100%", w = "100%" },
      fillColor = { alpha = 1.0, red = 1.0 },
      action = "fill"

    },{ -- Now reset clipping in case we add something else
      type = "resetClip"
    }
    )

  s.log.d("New ScreenBorder created")
  return s
end

return SB

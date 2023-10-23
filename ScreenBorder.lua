--- === WatcherWatcher.ScreenBorder ===
--- Indicatgor for WatcherWatcher to create a border around the screen
--- when a microphone or camera is in use.

-- ScreenBorder is a subclass of WatcherWatcher.Indicator
local Indicator = dofile(hs.spoons.resourcePath("Indicator.lua"))
local SB = Indicator:subclass()

--- ScreenBorder:width
--- Variable
--- Width of border as percentage of screen.
SB.width = 0.5

--- ScreenBorder:microphoneInUseColor
--- Variable
--- Color to use if only microphone is in use
SB.microphoneInUseColor = { alpha = 1.0, red = 1.0, green = 1.0 }

--- ScreenBorder:cameraInUseColor
--- Variable
--- Color to use if only camera is in use
SB.micOnColor = { alpha = 1.0, red = 1.0 }

--- ScreenBorder:cameraAndMicInUseColor
--- Variable
--- Color to use if camera and microphone are in use
SB.cameraAndMicOnColor = { alpha = 1.0, red = 1.0 }

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
      fillColor = self.microphoneInUseColor, -- Arbitrary
      action = "fill"

    },{ -- Now reset clipping in case we add something else
      type = "resetClip"
    }
    )

  s.log.d("New ScreenBorder created")
  return s
end

--- ScreenBorder:update()
--- Method
--- Update the border, colored based on what is in use.
--- Possible hide it if nothing in use.
--- Parameters:
---   * None
---
--- Returns:
---   * Nothing
function SB:update()
  local cameraInUse = #self.ww:camerasInUse() > 0
  local micInUse = #self.ww:micsInUse() > 0

  if cameraInUse and micInUse then
    self.log.d("Updating: Camera and microphone in use")
    self.canvas[3].fillColor = self.cameraAndMicOnColor
    Indicator.show(self)
  elseif cameraInUse then
    self.log.d("Updating: Camera in use")
    self.canvas[3].fillColor = self.cameraInUseColor
    Indicator.show(self)
  elseif micInUse then
    self.log.d("Updating: Microphone in use")
    self.canvas[3].fillColor = self.microphoneInUseColor
    Indicator.show(self)
  else
    self.log.d("Updating: Nothing in use")
    Indicator.hide(self)
  end
end

--- ScreenBorder:callbacks()
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
  local start = hs.fnutils.partial(self.update, self)
  local stop = hs.fnutils.partial(self.update, self)
  local mute = hs.fnutils.partial(self.hide, self)

  return start, stop, mute
end

return SB

local fs = require("filesystem")
local shell = require("shell")
local gpu = require("component").gpu
local event = require("event")
local computer = require("computer")
local ocelot = require("component").ocelot

local resX, resY = gpu.getResolution()
local textBuffer = gpu.allocateBuffer(resX, resY - 1)

local args = {...}
local file = args[1]
if not file then
    print("\x1b[91mEnter a file name.")
    return
end
if fs.isDirectory(file) then
    print("\x1b[91mThe specified file is a directory.")
    return
end

if file:sub(1, 1) ~= "/" then
    file = fs.concat(shell.getWorkingDirectory(), file)
end

local data = ""
if fs.exists(file) then
    local handle = fs.open(file)
    local tmpdata
    repeat
        tmpdata = handle:read(math.huge or math.maxinteger)
        data = data .. (tmpdata or "")
    until not tmpdata
end

local lines = {}
for line in data:gmatch("[^\r\n]+") do
  table.insert(lines, line)
end

local function renderText(xOffset, yOffset)
  gpu.setActiveBuffer(textBuffer)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(1, 1, resX, resY - 1, " ")
  for i = yOffset + 1, #lines do
    gpu.set(1, i - yOffset, lines[i]:sub(xOffset + 1))
  end
  gpu.setActiveBuffer(0)
  gpu.bitblt(0, 1, 1, resX, resY - 1, textBuffer, 1, 1)
end

-- Initialize screen
renderText(0, 0)
gpu.setForeground(0x000000)
gpu.setBackground(0xFFFFFF)
gpu.set(1, resY, "^X")
gpu.set(10, resY, "^S")
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
gpu.set(4, resY, "Exit")
gpu.set(13, resY, "Save")

local textOffsetX = 0
local textOffsetY = 0
local cursorX = 1 -- Absolute position, not accounting for scrolling
local cursorY = 1
local cursorWhite = true
local oldTime = computer.uptime()

while true do
  local renderBufferFlag = false -- Flag to render the whole text buffer
  -- Handle events
  local previousCursorX -- Used for blackening the previous cursor location when the cursor is moved
  local previousCursorY
  repeat
    local eventArgs = {event.pull("key_down", 0.05)}
    -- The logical solution here for flashing the cursor would be to set the timeout to 0.5, and, if the timeout is reached, change the color.
    -- However, that makes scrolling freeze the screen up completely.
    -- Thus, for flashing the cursor, a timer is needed.

    if computer.uptime() >= oldTime + 0.5 then
      oldTime = computer.uptime()
      cursorWhite = not cursorWhite
    end

    if next(eventArgs) ~= nil then
      cursorWhite = true
      oldTime = computer.uptime()
    end

    if eventArgs[1] == "key_down" then
      -- Mouse events might be added later, that's why this if statement is here
      if keyboard.getCtrlDown() then
        -- Special commands
        if keyboard.keys[eventArgs[4]] == "x" then
          goto exit
        end
      end

      if keyboard.keys[eventArgs[4]] == "up" and cursorY > 1 then
        if not previousCursorX and not previousCursorY then
          previousCursorX = cursorX
          previousCursorY = cursorY
        end
        cursorY = cursorY - 1
      end
      if keyboard.keys[eventArgs[4]] == "down" then
        if not previousCursorX and not previousCursorY then
          previousCursorX = cursorX
          previousCursorY = cursorY
        end
        cursorY = cursorY + 1
      end
      if keyboard.keys[eventArgs[4]] == "left" and cursorX > 1 then
        if not previousCursorX and not previousCursorY then
          previousCursorX = cursorX
          previousCursorY = cursorY
        end
        cursorX = cursorX - 1
      end
      if keyboard.keys[eventArgs[4]] == "right" then
        if not previousCursorX and not previousCursorY then
          previousCursorX = cursorX
          previousCursorY = cursorY
        end
        cursorX = cursorX + 1
      end
    end
  until not next(eventArgs)
  if renderBufferFlag then
    renderText(textOffsetX, textOffsetY)
    if cursorWhite then
      -- If the cursor is black, then there's no need to do anything because there is no cursor after calling renderText().
      gpu.setForeground(0x000000)
      gpu.setBackground(0xFFFFFF)
      local letter = gpu.get(cursorX, cursorY)
      gpu.set(cursorX, cursorY, letter)
      -- TODO: Account for scrolling
    end
  else
    if cursorWhite then
      if previousCursorX or previousCursorY then
        -- Remove old cursor
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(0x000000)
        local letter = gpu.get(previousCursorX, previousCursorY)
        gpu.set(previousCursorX, previousCursorY, letter)
      end

      gpu.setForeground(0x000000)
      gpu.setBackground(0xFFFFFF)
      local letter = gpu.get(cursorX, cursorY)
      gpu.set(cursorX, cursorY, letter)
    else
      -- If renderText() hasn't been called, the cursor may still be white and need to be turned black.
      gpu.setForeground(0xFFFFFF)
      gpu.setBackground(0x000000)
      local letter = gpu.get(cursorX, cursorY)
      gpu.set(cursorX, cursorY, letter)
    end
  end
end

-- Cleanup
::exit::
gpu.freeBuffer(textBuffer)
gpu.setActiveBuffer(0)
terminal.clear()

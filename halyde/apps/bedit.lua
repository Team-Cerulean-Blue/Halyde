local fs = require("filesystem")
local shell = require("shell")
local gpu = require("component").gpu

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

renderText(args[2], args[3])

-- Cleanup
gpu.freeBuffer(textBuffer)
gpu.setActiveBuffer(0)

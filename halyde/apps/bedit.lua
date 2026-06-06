local fs = require("filesystem")
local shell = require("shell")

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

for _, line in ipairs(lines) do
    print(line)
end
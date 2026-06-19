local fs = require("filesystem")
local shell = require("shell")

local args = {...}

if not args[1] then
  return shell.run("help cat")
end

for _, file in pairs(args) do
  file = shell.resolvePath(file)

  local handle = fs.open(file, "r")
  if handle == nil then
    terminal.write("\27[91mCan't open " .. file .. "\27[0m\n")
    goto continue
  end
  local enddata
  while true do
    local data = handle:read(math.huge or math.maxinteger)
    if data == nil then break end
    terminal.write(data)
    enddata = data
  end
  handle:close()
  if string.sub(enddata, -1, -1) ~= "\n" then
    print("")
  end
  ::continue::
end

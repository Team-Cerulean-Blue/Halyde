local fs = require("filesystem")
local shell = require("shell")

local args = {...}

if not args[1] then
  return shell.run("help rm")
end

for _, file in pairs(args) do
  file = shell.resolvePath(file)

  local result = fs.remove(file)
  if result == false then
    terminal.write("\27[91mError: cannot delete " .. file .. "\27[0m\n")
  end
end

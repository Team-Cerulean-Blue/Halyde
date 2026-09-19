local fs = require("filesystem")
local shell = require("shell")

local args = {...}

if not args[1] then
  return shell.run("help mkdir")
end

for _, directory in pairs(args) do
  directory = shell.resolvePath(directory)

  if fs.exists(directory) then
    terminal.write("\27[91mError: " .. directory ..": An object already exists\27[0m\n")
    goto continue
  end
  local what, err = fs.makeDirectory(directory)
  if err ~= nil then
    terminal.write("\27[91mError: " .. err .. "\27[0m\n")
    goto continue
  end
  ::continue::
end

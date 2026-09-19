-- TODO: Rename this to something else (while making an alias from the original command).
-- Touch seems kind of a silly name for a command to make a file.
-- Maybe something like mkfile would be better?
local fs = require("filesystem")
local shell = require("shell")

local args = {...}

if not args[1] then
  return shell.run("help touch")
end

for _, file in pairs(args) do
  file = shell.resolvePath(file)

  local handle, err = fs.open(file, "a")
  if err ~= nil then
    terminal.write("\27[91mError: " .. err .. "\27[0m\n")
    goto continue
  end
  handle:close()
  ::continue::
end

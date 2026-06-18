local fs = require("filesystem")
local shell = require("shell")

local args = {...}

if not args[1] then
  return shell.run("help mv")
end

if not args[2] then
  terminal.write("\27[91mError: No destination\27[0m\n")
  return
end

local dest = shell.resolvePath(args[#args])

if fs.isFile(dest) then
  if #args ~= 2 then
    terminal.write("\27[91mError: Destination is not a directory\27[0m\n")
    return
  end
  local src = shell.resolvePath(args[1])
  if not fs.exists(src) then
    terminal.write("\27[91mError: " .. src .. ": No such file or directory\27[0m\n")
    return
  end
  if fs.isDirectory(src) then
    terminal.write("\27[91mError: Cannot write directory " .. src .. " to file " .. dest .. "\27[0m\n")
    return
  end
  fs.rename(src, dest)
elseif fs.isDirectory(dest) then
  for i = 1, #args - 1 do
    local src = shell.resolvePath(args[i])
    if src == dest then
      terminal.write("\27[91mError: Source and destination are the same\27[0m\n")
      goto continue
    end

    if not fs.exists(src) then
      terminal.write("\27[91mError: " .. src .. ": No such file or directory\27[0m\n")
      goto continue
    end

    fs.rename(src, fs.concat(dest, fs.basename(src)))
    ::continue::
  end
elseif not fs.exists(dest) then
  if #args ~= 2 then
    terminal.write("\27[91mError: " .. dest .. ": No such file or directory\27[0m\n")
    return
  end
  local src = shell.resolvePath(args[1])
  if not fs.exists(src) then
    terminal.write("\27[91mError: " .. src .. ": No such file or directory\27[0m\n")
    return
  end
  local destp = fs.parent(dest)
  if not fs.exists(destp) then
    terminal.write("\27[91mError: " .. destp .. ": No such file or directory\27[0m\n")
    return
  end
  if not fs.isDirectory(destp) then
    terminal.write("\27[91mError: " .. destp .. ": Not a directory\27[0m\n")
    return
  end
  fs.rename(src, dest)
else
  terminal.write("\27[91mUnknown error\27[0m\n")
end

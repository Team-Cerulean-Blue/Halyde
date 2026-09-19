local args = {...}

if args[2] then
  terminal.write("\27[91mToo many arguments.\27[0m")
end

if not args[1] then
  return
end

local fs = require("filesystem")
local shell = require("shell")

local directory = shell.resolvePath(args[1])

if not fs.exists(directory) then
  terminal.write("\27[91mError: " .. directory .. ": No such file or directory\27[0m\n")
  return
end

if not fs.isDirectory(directory) then
  terminal.write("\27[91mError: " .. directory .. ": Not a directory\27[0m\n")
  return
end

shell.setWorkingDirectory(fs.canonical(directory))

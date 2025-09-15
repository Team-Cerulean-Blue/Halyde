local directory = ...
local fs = require("filesystem")
local shell = require("shell")

if not directory then
  return
end
if directory:sub(1, 1) ~= "/" then
  directory = fs.concat(shell.getWorkingDirectory(), directory)
end
if fs.exists(directory) and fs.isDirectory(directory) then
  shell.setWorkingDirectory(fs.canonical(directory))
else
  print("\27[91mNo such directory.")
end

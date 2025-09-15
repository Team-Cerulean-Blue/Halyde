local fromFile, toFile = ...
local fs = require("filesystem")
local shell = require("shell")

if not fromFile or not toFile then
  shell.run("help cp")
  return
end
if fromFile:sub(1, 1) ~= "/" then
  fromFile = fs.concat(shell.getWorkingDirectory(), fromFile)
end
if toFile:sub(1, 1) ~= "/" then
  toFile = fs.concat(shell.getWorkingDirectory(), toFile)
end
if fromFile == toFile then
  print("\27[91mSource and destination are the same.")
  return
end
if not fs.exists(fromFile) then
  print("\27[91mSource file does not exist.")
  return
end
if fs.exists(toFile) and not (table.find({...}, "-o") or table.find({...}, "--overwrite")) then
  print("\27[91mDestination file already exists. Run this command again with -o to overwrite it.")
  return
end
fs.copy(fromFile, toFile)

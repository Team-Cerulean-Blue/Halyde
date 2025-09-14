local directory = ...
local fs = require("filesystem")

if not directory then
  require("shell").run("help mkdir")
  return
end
if directory:sub(1, 1) ~= "/" then
  directory = fs.concat(require("shell").getWorkingDirectory(), directory)
end
if fs.exists(directory) then
  print("\27[91mAn object already exists at the specified path.")
end
fs.makeDirectory(directory)

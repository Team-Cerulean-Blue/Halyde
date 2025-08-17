local directory = ...
local fs = import("filesystem")

if not directory then
  shell.run("help mkdir")
  return
end
if directory:sub(1, 1) ~= "/" then
  directory = fs.concat(shell.workingDirectory, directory)
end
if fs.exists(directory) then
  print("\27[91mAn object already exists at the specified path.")
end
fs.makeDirectory(directory)

local directory = ...
local fs = import("filesystem")

if not directory then
  return
end
if directory:sub(1, 1) ~= "/" then
  directory = fs.concat(shell.workingDirectory, directory)
end
if fs.exists(directory) and fs.isDirectory(directory) then
  shell.workingDirectory = fs.canonical(directory)
else
  print("\27[91mNo such directory.")
end

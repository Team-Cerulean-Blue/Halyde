local file = ...
local fs = import("filesystem")

if not file then
  shell.run("help rm")
  return
end
if file:sub(1, 1) ~= "/" then
  file = fs.concat(shell.workingDirectory, file)
end
if not fs.exists(file) then
  print("\27[91mFile does not exist.")
  return
end
fs.remove(file)

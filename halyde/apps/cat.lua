local files = {...}
local fs = import("filesystem")
if not files or not files[1] then
  shell.run("help cat")
  return
end
for _, file in ipairs(files) do 
  if file:sub(1, 1) ~= "/" then
    file = fs.concat(shell.workingDirectory, file)
  end
  if not fs.exists(file) then
    print("\27[91mFile does not exist.")
  end
  local handle = fs.open(file, "r")
  local data
  repeat
    data = handle:read(math.huge or math.maxinteger)
    termlib.write(data)
  until not data
end

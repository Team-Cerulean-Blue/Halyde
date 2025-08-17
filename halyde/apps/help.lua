local fs = import("filesystem")
local args = {...}
local command = args[1]
args = nil
if not command then
  local handle, data, tmpdata = fs.open("/halyde/apps/helpdb/default.txt", "r"), "", nil
  repeat
    tmpdata = handle:read(math.huge or math.maxinteger)
    data = data .. (tmpdata or "")
  until not tmpdata
  print(data)
  return
end
if shell.aliases[command] then
  command = shell.aliases[command]
end
if fs.exists("/halyde/apps/helpdb/" .. command .. ".txt") then
  local handle, data, tmpdata = fs.open("/halyde/apps/helpdb/" .. command .. ".txt", "r"), "", nil
  repeat
    tmpdata = handle:read(math.huge or math.maxinteger)
    data = data .. (tmpdata or "")
  until not tmpdata
  print(data)
  local aliases = table.copy(shell.aliases)
  if table.find(aliases, command) then
    local aliasIndex = table.find(aliases, command)
    local aliasString = "Aliases:\n  " .. aliasIndex
    aliases[aliasIndex] = nil
    while table.find(aliases, command) do
      aliasIndex = table.find(aliases, command)
      aliasString = aliasString .. ", " .. aliasIndex
      aliases[aliasIndex] = nil
    end
    print(aliasString)
  end
else
  print("Could not find help file for: " .. command .. ".")
end

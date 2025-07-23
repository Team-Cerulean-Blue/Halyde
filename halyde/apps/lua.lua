print("\27[44m".._VERSION.."\27[0m shell")
print('Type "exit" to exit.')
termlib.readHistory["lua"] = {""}
local fs = import("filesystem")

local loadedLibraries = ""
local libList = fs.list("halyde/lib")
for _, lib in pairs(libList) do
  if lib:match("(.+)%.lua") then
    loadedLibraries = loadedLibraries .. "local " .. lib:match("(.+)%.lua") .. ' = import("' .. lib:match("(.+)%.lua") .. '")\n'
  end
end

while true do
  local command = read("lua", "\27[44mlua>\27[0m ")
  if command == "exit" then
    return
  else
    local function runCommand()
      local func = load(loadedLibraries.."return "..command,"=stdin") or load(loadedLibraries..command,"=stdin")
      local res = {assert(func)()}
      if res and (type(res[1])~="nil" or type(res[2])~="nil") then print(table.unpack(res)) end
    end
    local result, reason = xpcall(runCommand, function(errMsg)
      return errMsg .. "\n\n" .. debug.traceback()
    end)
    if not result then
      print("\27[91m" .. reason)
    end
  end
end

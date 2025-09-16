-- terminal.readHistory["lua"] = {""}
local fs = require("filesystem")
local computer = require("computer")

local bootTime = computer.uptime()
local libList = fs.list("/lib/")
for _, lib in pairs(libList) do
  if lib:match("(.+)%.lua") then
    local name = lib:match("(.+)%.lua")
    _G[name] = require(name)
  end
end

print(string.format("\27[37mLoaded %d libraries in %.2f seconds\27[0m",#libList,computer.uptime()-bootTime))
print(string.format("\27[44m%s\27[0m shell",_VERSION))
print('Type "exit" to exit.')

while true do
  local command = terminal.read("lua", "\27[44mlua>\27[0m ")
  if command == "exit" then
    return
  elseif command~="" then
    local function runCommand()
      local func = load("return "..command,"=stdin") or load(command,"=stdin")
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

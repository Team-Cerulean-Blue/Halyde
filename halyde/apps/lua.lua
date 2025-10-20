-- terminal.readHistory["lua"] = {""}
local fs = require("filesystem")
local computer = require("computer")
local log = require("log")

local bootTime = computer.uptime()
local libList = fs.list("/lib/")
local failed = false
for _, lib in pairs(libList) do
  local status, err = xpcall(function()
    if lib:match("(.+)%.lua") then
      local name = lib:match("(.+)%.lua")
      _G[name] = require(name)
    end
  end, debug.traceback)
  if not status then
    print(
      string.format(
        "\x1b[91mLibrary %s has failed loading:\n │ %s",
        lib:match("(.+)%.lua"),
        tostring(err or "unknown error"):match("^(.-)\n")
      )
    ) -- TODO: only show first line of error
    log.lua.error(
      string.format(
        'The library located at "%s" has failed loading:\n%s',
        lib,
        type(err) ~= "nil" and tostring(err) or "unknown error"
      )
    )
    failed = true
  end
end

if failed then
  print(
    string.format(
      '\x1b[93mOne or more libraries failed to load. For more information, check the log entries located at "%s".',
      tostring(log.lua.logpath or "[unknown]")
    )
  )
end

print(string.format("\27[37mLoaded %d libraries in %.2f seconds\27[0m", #libList, computer.uptime() - bootTime))
print(string.format("\27[44m%s\27[0m shell", _VERSION))
print('Type "exit" to exit.')

while true do
  local command = terminal.read("lua", "\27[44mlua>\27[0m ")
  if command == "exit" then
    coroutine.yield()
    return
  elseif command ~= "" then
    local function runCommand()
      local func, err = load("return " .. command, "=stdin")
      local returns = true
      if not func then
        func, err = load(command, "=stdin")
        returns = false
      end
      if not func then
        return print("\x1b[91msyntax error: " .. (err or "unknown error"))
      end
      local res = { func() }
      if returns then
        if res and type(res[1]) ~= "nil" then
          print(table.unpack(res))
        elseif res and type(res[2]) ~= "nil" then
          print("nil", table.unpack(res))
        end
      end
    end
    local result, reason = xpcall(runCommand, function(errMsg)
      return errMsg .. "\n\n" .. debug.traceback()
    end)
    if not result then
      print("\27[91m" .. reason)
    end
  end
end

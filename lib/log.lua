local fs = require("filesystem")
local computer = require("computer")

local log = {}

function log.add(text, logType)
  checkArg(1, text, "string")
  checkArg(2, logType, "string", "nil")
  if logType ~= "debug" and logType ~= "info" and logType ~= "warning" and logType ~= "error" and logType then
    error("Log type must either be debug, info, warning or error.")
  end
  if not logType then
    logType = "debug"
  end
  local handle = fs.open("/halyde/system.log", "a")
  local time = computer.uptime()
  local logText = string.format("[%02d:%02d:%02d:%02d] " .. text, math.floor(time / 86400), math.floor(time / 3600 % 24), math.floor(time / 60 % 60), math.floor(time % 60)) .. "\n"
  if logType == "debug" then
    handle:write("\27[37m" .. logText)
  elseif logType == "info" then
    handle:write("\27[97m" .. logText)
  elseif logType == "warning" then
    handle:write("\27[93m" .. logText)
  else
    handle:write("\27[91m" .. logText)
  end
  handle:close()
end

return log

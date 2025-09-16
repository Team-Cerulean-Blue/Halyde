local fs, computer
local chunkSize = 1024
if require then
  fs = require("filesystem")
  computer = require("computer")
else
  local loadfile = ...
  fs = loadfile("/lib/filesystem.lua")(loadfile)
  computer = _G.computer
end

local log = {}

local logFileSizeLimit = 16384

local function writeToLog(path, text)
  local handle
  if fs.exists(path) then
    handle = assert(fs.open(path, "a"))
  else
    handle = assert(fs.open(path, "w"))
  end
  handle:write(text .. "\n")
  handle:close()

  -- Log trimming if it gets too long
  if fs.size(path) > logFileSizeLimit then
    local sizeCounter = 0
    local readHandle = fs.open(path, "r")
    local currentChunk = ""
    readHandle:seek("end", -chunkSize)
    repeat
      currentChunk = readHandle:read(chunkSize)
      readHandle:seek(-chunkSize * 2)
      sizeCounter = sizeCounter + chunkSize
    until sizeCounter >= logFileSizeLimit * 0.75
    while true do
      local infoEntry = currentChunk:find("INFO [", 1, true)
      local warnEntry = currentChunk:find("WARN [", 1, true)
      local errorEntry = currentChunk:find("ERROR [", 1, true)
      if not infoEntry and not warnEntry and not errorEntry then
        readHandle:seek(-chunkSize)
      else
        readHandle:seek(math.min(infoEntry or math.huge or math.maxinteger, warnEntry or math.huge or math.maxinteger,
          errorEntry or math.huge or math.maxinteger) - 1)
        break
      end
      if readHandle:seek("cur") == 0 then -- Failsafe to prevent infinite loops
        break
      end
    end
    local writeHandle = fs.open(path, "w")
    while true do
      local tmpdata = readHandle:read(math.huge or math.maxinteger)
      if not tmpdata then
        break
      end
      writeHandle:write(tmpdata)
    end
    readHandle:close()
    writeHandle:close()
  end
end

setmetatable(log, {
  ["__index"] = function(_, index)
    return {
      ["logpath"] = fs.concat("/halyde/logs/", index .. ".log"),
      ["info"] = function(text)
        writeToLog(fs.concat("/halyde/logs/", index .. ".log"),
          "INFO [" .. string.format("%.2f", computer.uptime()) .. "] " .. text)
      end,
      ["warn"] = function(text)
        writeToLog(fs.concat("/halyde/logs/", index .. ".log"),
          "WARN [" .. string.format("%.2f", computer.uptime()) .. "] " .. text)
      end,
      ["error"] = function(text)
        writeToLog(fs.concat("/halyde/logs/", index .. ".log"),
          "ERROR [" .. string.format("%.2f", computer.uptime()) .. "] " .. text)
      end,
    }
  end,
})

return log

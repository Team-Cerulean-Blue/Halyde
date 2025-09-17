local fs, computer, gpu
local chunkSize = 1024
if require then
  fs = require("filesystem")
  computer = require("computer")
  gpu = require("component").gpu
else
  local loadfile = ...
  fs = loadfile("/lib/filesystem.lua")(loadfile)
  computer = _G.computer
  gpu = loadfile("/lib/component.lua")(loadfile).gpu
end

local resX, resY = gpu.getResolution()
local log = {}
if not _G.logSettings then
  _G.logSettings = { -- We have to preload the library just for this :P
    ["printLogs"] = true,
    ["printerY"] = 1
  }
end

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

  if _G.logSettings.printLogs then
    -- Print onscreen
    if text:sub(1, 4) == "INFO" then -- Set color
      gpu.setForeground(0xFFFFFF)
    elseif text:sub(1, 4) == "WARN" then
      gpu.setForeground(0xFFFF00)
    elseif text:sub(1, 5) == "ERROR" then
      gpu.setForeground(0xFF0000)
    end
    repeat -- Line wrapping
      if _G.logSettings.printerY > resY then
        gpu.copy(1, 2, resX, resY - 1, 0, -1)
        _G.logSettings.printerY = resY
      end
      gpu.set(1, _G.logSettings.printerY, text .. string.rep(" ", resX - #text))
      text = text:sub(resX + 1)
      _G.logSettings.printerY = _G.logSettings.printerY + 1
    until text == ""
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

function log.setPrintLogs(setting) -- Yes, this works with the metatable.
  checkArg(1, setting, "boolean")
  _G.logSettings.printLogs = setting
end

return log

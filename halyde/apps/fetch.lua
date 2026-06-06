local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")

local function convert(value, fromUnit, toUnit)
  local units = {B = 1, KiB = 1024, MiB = 1024^2, GiB = 1024^3}
  return value * units[fromUnit] / units[toUnit]
end

local function printstat(text)
  terminal.write("\27[35G" .. text .. "\n")
end

local logo = ""
local handle, tmpdata = filesystem.open("/halyde/config/oslogo.ans", "r"), nil
repeat
  tmpdata = handle:read(math.huge)
  logo = logo .. (tmpdata or "")
until not tmpdata
handle:close()

terminal.write(logo)

terminal.write("\27[17A")

printstat("\27[92mOS\27[0m: " .. _OSVERSION)
printstat("\27[92mArchitecture\27[0m: " .. _VERSION)

local componentCounter = 0
for _ in component.list() do
  componentCounter = componentCounter + 1
end
printstat("\27[92mComponents\27[0m: " .. tostring(componentCounter))
printstat("\27[92mCoroutines\27[0m: " .. tostring(#tsched.getTasks()))
printstat("\27[92mBattery\27[0m: " .. tostring(math.floor(computer.energy() / computer.maxEnergy() * 1000 + 0.5) / 10) .. "%")

local totalMemory = computer.totalMemory()
local usedMemory = computer.totalMemory() - computer.freeMemory()

local function formatBytes(bytes)
  if convert(bytes, "B", "GiB") >= 1 then
    return tostring(math.floor(convert(bytes, "B", "GiB") * 100 + 0.5) / 100) .. " GiB"
  elseif convert(bytes, "B", "MiB") >= 1 then
    return tostring(math.floor(convert(bytes, "B", "MiB") * 100 + 0.5) / 100) .. " MiB"
  elseif convert(bytes, "B", "KiB") >= 1 then
    return tostring(math.floor(convert(bytes, "B", "KiB") * 100 + 0.5) / 100) .. " KiB"
  else
    return tostring(bytes) .. " B"
  end
end

printstat("\27[92mMemory\27[0m: " .. formatBytes(usedMemory) .. " / " .. formatBytes(totalMemory))

local totalDisk = component.invoke(computer.getBootAddress(), "spaceTotal")
local usedDisk = component.invoke(computer.getBootAddress(), "spaceUsed")

printstat("\27[92mDisk\27[0m: " .. formatBytes(usedDisk) .. " / " .. formatBytes(totalDisk))

local gpuComponent = component.list("gpu")()
local width, height = component.invoke(gpuComponent, "getResolution")
printstat("\27[92mResolution\27[0m: " .. tostring(width) .. "x" .. tostring(height) .. "\n")

printstat("\27[40m  \27[41m  \27[42m  \27[43m  \27[44m  \27[45m  \27[46m  \27[47m  ")
printstat("\27[100m  \27[101m  \27[102m  \27[103m  \27[104m  \27[105m  \27[106m  \27[107m  ")

terminal.write("\27[5B\27[0m")

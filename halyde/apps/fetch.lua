local component = import("component")
local computer = import("computer")

local function printstat(text)
  termlib.cursorPosX = 35
  termlib.write(text .. "\n", false)
end

termlib.write(_OSLOGO, false)
termlib.cursorPosY = termlib.cursorPosY - 17
printstat("\27[92mOS\27[0m: ".._OSVERSION)
printstat("\27[92mArchitecture\27[0m: ".._VERSION)
local componentCounter = 0
for _, _ in component.list() do
  componentCounter = componentCounter + 1
end
printstat("\27[92mComponents\27[0m: "..tostring(componentCounter))
printstat("\27[92mCoroutines\27[0m: "..tostring(#cormgr.corList))
printstat("\27[92mBattery\27[0m: "..tostring(math.floor(computer.energy() / computer.maxEnergy() * 1000 + 0.5) / 10).."%")
local totalMemory = computer.totalMemory()
local usedMemory = computer.totalMemory() - computer.freeMemory()
local totalMemoryString
if convert(totalMemory, "B", "GiB") >= 1 then
  totalMemoryString = tostring(math.floor(convert(totalMemory, "B", "GiB") * 100 + 0.5) / 100) .. " GiB"
elseif convert(totalMemory, "B", "MiB") >= 1 then
  totalMemoryString = tostring(math.floor(convert(totalMemory, "B", "MiB") * 100 + 0.5) / 100) .. " MiB"
elseif convert(totalMemory, "B", "KiB") >= 1 then
  totalMemoryString = tostring(math.floor(convert(totalMemory, "B", "KiB") * 100 + 0.5) / 100) .. " KiB"
else
  totalMemoryString = tostring(totalMemory) .. " B"
end
local usedMemoryString
if convert(usedMemory, "B", "GiB") >= 1 then
  usedMemoryString = tostring(math.floor(convert(usedMemory, "B", "GiB") * 100 + 0.5) / 100) .. " GiB"
elseif convert(usedMemory, "B", "MiB") >= 1 then
  usedMemoryString = tostring(math.floor(convert(usedMemory, "B", "MiB") * 100 + 0.5) / 100) .. " MiB"
elseif convert(usedMemory, "B", "KiB") >= 1 then
  usedMemoryString = tostring(math.floor(convert(usedMemory, "B", "KiB") * 100 + 0.5) / 100) .. " KiB"
else
  usedMemoryString = tostring(usedMemory) .. " B"
end
printstat("\27[92mMemory\27[0m: "..usedMemoryString.." / "..totalMemoryString)
local totalDisk = component.invoke(computer.getBootAddress(), "spaceTotal")
local usedDisk = component.invoke(computer.getBootAddress(), "spaceUsed")
local totalDiskString
if convert(totalDisk, "B", "GiB") >= 1 then
  totalDiskString = tostring(math.floor(convert(totalDisk, "B", "GiB") * 100 + 0.5) / 100) .. " GiB"
elseif convert(totalDisk, "B", "MiB") >= 1 then
  totalDiskString = tostring(math.floor(convert(totalDisk, "B", "MiB") * 100 + 0.5) / 100) .. " MiB"
elseif convert(totalDisk, "B", "KiB") >= 1 then
  totalDiskString = tostring(math.floor(convert(totalDisk, "B", "KiB") * 100 + 0.5) / 100) .. " KiB"
else
  totalDiskString = tostring(totalDisk) .. " B"
end
local usedDiskString
if convert(usedDisk, "B", "GiB") >= 1 then
  usedDiskString = tostring(math.floor(convert(usedDisk, "B", "GiB") * 100 + 0.5) / 100) .. " GiB"
elseif convert(usedDisk, "B", "MiB") >= 1 then
  usedDiskString = tostring(math.floor(convert(usedDisk, "B", "MiB") * 100 + 0.5) / 100) .. " MiB"
elseif convert(usedDisk, "B", "KiB") >= 1 then
  usedDiskString = tostring(math.floor(convert(usedDisk, "B", "KiB") * 100 + 0.5) / 100) .. " KiB"
else
  usedDiskString = tostring(usedDisk) .. " B"
end
printstat("\27[92mDisk\27[0m: "..usedDiskString.." / "..totalDiskString)
local width, height = component.invoke(component.list("gpu")(), "getResolution")
printstat("\27[92mResolution\27[0m: "..tostring(width).."x"..tostring(height).."\n")
printstat("\27[40m  \27[41m  \27[42m  \27[43m  \27[44m  \27[45m  \27[46m  \27[47m  ")
printstat("\27[100m  \27[101m  \27[102m  \27[103m  \27[104m  \27[105m  \27[106m  \27[107m  ")
termlib.cursorPosY = termlib.cursorPosY + 5

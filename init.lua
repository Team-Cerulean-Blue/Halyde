local gpu = component.proxy(component.list("gpu")())
local resX, resY = gpu.getResolution()

-- Architecture check
local foundArchitecture = false
for _, arch in pairs(computer.getArchitectures()) do
  if arch == "Lua 5.3" then
    foundArchitecture = true
    break
  end
end

if foundArchitecture then
  computer.setArchitecture("Lua 5.3")
else
  gpu.set(1, 1, "Required architecture (Lua 5.3) is not supported.")
  gpu.set(1, 2, "Halting.")
  while true do
    computer.pullSignal()
  end
end

local function loadfile(file)
  checkArg(1, file, "string")
  local handle = component.invoke(computer.getBootAddress(), "open", file, "r")
  local data = ""
  repeat
    local tmpdata = component.invoke(computer.getBootAddress(), "read", handle, math.huge or math.maxinteger)
    data = data .. (tmpdata or "")
  until not tmpdata
  component.invoke(computer.getBootAddress(), "close", handle)
  return assert(load(data, "=" .. file))
end

local function handleError(errorMessage)
  return(errorMessage.."\n \n"..debug.traceback())
end

function loadBoot()
  loadfile("/halyde/kernel/boot.lua")(loadfile)
end

gpu.setBackground(0x000000)
gpu.fill(1, 1, resX, resY, " ")

-- Copying low-level functions in case of post-preload failure
local pullSignal = computer.pullSignal
local shutdown = computer.shutdown

local result, reason = xpcall(loadBoot, handleError)
if not result then
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, resX, resY, " ")
  gpu.setBackground(0x800000)
  gpu.setForeground(0xFFFFFF)
  gpu.set(2,2,"A critical error has occurred.")
  local i = 4
  reason = tostring(reason):gsub("\t", "  ")
  for line in string.gmatch(reason or "unknown error", "([^\n]*)\n?") do
    gpu.set(2,i,line)
    i = i + 1
  end
  gpu.set(2,i+1, "Press any key to restart.")
  local evname
  repeat
    evname = pullSignal()
  until evname == "key_down"
  shutdown(true)
  while true do
    coroutine.yield()
  end
end

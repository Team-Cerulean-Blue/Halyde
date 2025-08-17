local gpu = component.proxy(component.list("gpu")())
local resx, resy = gpu.getResolution()

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

function loadthething()
  loadfile("/halyde/core/boot.lua")(loadfile)
end

gpu.setBackground(0x000000)
gpu.fill(1, 1, resx, resy, " ")
local result, reason = xpcall(loadthething, handleError)
if not result then
  if import then
    local computer = import("computer")
  end
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, resx, resy, " ")
  gpu.setBackground(0x800000)
  gpu.setForeground(0xFFFFFF)
  gpu.set(2,2,"A critical error has occurred.")
  local i = 4
  reason = reason:gsub("\t", "  ")
  for line in string.gmatch((reason ~= nil and tostring(reason)) or "unknown error", "([^\n]*)\n?") do
    gpu.set(2,i,line)
    i = i + 1
  end
  if computer~=nil then
    gpu.set(2,i+1, "Press any key to restart.")
    local evname
    repeat
      evname = computer.pullSignal()
    until evname == "key_down"
    computer.shutdown(true)
  end
  while true do
    coroutine.yield()
  end
end

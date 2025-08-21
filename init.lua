local gpu = component.proxy(component.list("gpu")())
local resX, resY = gpu.getResolution()

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
  local foundArchitecture = false
  for _, arch in pairs(computer.getArchitectures()) do
    if arch == "Lua 5.3" then
      foundArchitecture = true
      break
    end
  end

  if foundArchitecture then
    local _, errorMesage = computer.setArchitecture("Lua 5.3")
    if errorMessage then
      error(errorMessage)
    end
  else
    gpu.set(1, 1, "Required architecture (Lua 5.3) is not supported.")
    gpu.set(1, 2, "Halting.")
    while true do
      computer.pullSignal()
    end
  end
  loadfile("/halyde/kernel/boot.lua")(loadfile)
end

gpu.setBackground(0x000000)
gpu.fill(1, 1, resX, resY, " ")

-- Copying low-level functions in case of post-preload failure
local pullSignal = computer.pullSignal
local beep = computer.beep

local result, reason = xpcall(loadBoot, handleError)
if not result then
  local bgColor
  if gpu.getDepth() == 1 then
    bgColor = 0x000000
  else
    bgColor = 0x000080
  end
  gpu.setBackground(bgColor)
  gpu.fill(1, 1, resX, resY, " ")
  local function render()
    gpu.setForeground(0xFFFFFF)
    local i = 2
    reason = "A fatal error has occurred.\nHalyde cannot continue.\n \n" .. tostring(reason or "unknown error"):gsub("\t", "  ")
    for line in string.gmatch(reason, "([^\n]*)\n?") do
      gpu.set(2, i, line)
      i = i + 1
    end
    gpu.set(1, resY - 1, string.rep("─", resX))
    gpu.setForeground(bgColor)
    gpu.setBackground(0xFFFFFF)
    gpu.set(2, resY, "🠅   🠄   🠇   🠆")
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(bgColor)
    gpu.set(4, resY, " / ")
    gpu.set(9, resY, " / ")
    gpu.set(14, resY, " / ")
    gpu.set(20, resY, "Scroll" .. string.rep(" ", resX - 21))
  end
  render()
  beep(440, 0.2)
  beep(465, 0.2)
  beep(440, 0.2)
  beep(370, 0.5)
  while true do -- TODO: Make this scrollable
    pullSignal()
  end
end

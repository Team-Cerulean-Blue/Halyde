local io = require("io")
local component = require("component")
if not component.isAvailable("internet") then
  io.stderr.write("This program requires an internet card to run.")
  return
end
local internet = component.internet
local computer = require("computer")
local fs = require("filesystem")
local gpu = component.gpu
local width,height = gpu.getResolution()
local event = require("event")
local keyboard = require("keyboard")
local installLocation
local installAddress
local drives = {}
local driveAddresses = {}
for drive in fs.list("/mnt/") do
  local address = component.get(drive:sub(1, 3), "filesystem")
  if not component.invoke(address, "isReadOnly") then
    table.insert(drives, drive)
    table.insert(driveAddresses,address)
  end
end

local function reset()
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(1,1,width,height," ")
  require("tty").setCursor(1,1)
end

local function chooseDrive()
  local driveLabels = {}
  for i,drive in ipairs(drives) do
    local address = driveAddresses[i]
    table.insert(driveLabels,component.invoke(address,"getLabel"))
  end

  gpu.set(1,1,"Please select a drive to install Halyde to:")

  local cur = 1
  local function renderItem(idx,cur)
    if cur then
      gpu.setBackground(0xFFFFFF)
      gpu.setForeground(0x000000)
    else
      gpu.setBackground(0x000000)
      gpu.setForeground(0xFFFFFF)
    end
    gpu.fill(4,2+idx,width-3,1," ")
    local label = driveLabels[idx] or "No label"
    gpu.set(4,2+idx,label)
    gpu.set(4+#label+1,2+idx,driveAddresses[idx]:sub(1,5).."...")
  end

  local function moveCur(dir)
    local ncur = math.max(math.min(cur+dir,#drives),1)
    if cur==ncur then return end
    renderItem(ncur,true)
    renderItem(cur,false)
    cur=ncur
  end

  gpu.fill(2,3,1,#drives,"*")
  for i=1,#drives do
    renderItem(i,cur==i)
  end

  while true do
    local args = {event.pull("key_down")}
    if not args or not args[1] or not args[4] then goto continue end

    local key = keyboard.keys[args[4]]
    if key=="up" then
      moveCur(-1)
    elseif key=="down" then
      moveCur(1)
    elseif key=="right" or key=="enter" then
      gpu.setBackground(0x000000)
      gpu.setForeground(0xFFFFFF)
      gpu.fill(1,1,width,height-1," ")
      break
    elseif key=="left" or key=="back" then
      return false
    end
    ::continue::
  end

  installLocation = "/mnt/" .. drives[cur]
  installAddress = driveAddresses[cur]
  return true
end

if #drives == 0 then
  io.stderr.write("All drives are read-only.\nHalyde cannot be installed.")
elseif #drives == 1 then
  installLocation = "/mnt/" .. drives[1]
  installAddress = driveAddresses[1]
end

gpu.fill(1,1,width,height," ")
gpu.setBackground(0xFFFFFF)
gpu.setForeground(0x000000)
gpu.fill(1,height,width,1," ")
gpu.set(1,height,"Halyde Web Installer (OpenOS)")
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)

if #drives>1 then
  if not chooseDrive() then
    reset()
    return
  end
end
if not installLocation then
  reset()
  io.stderr.write("All drives are read-only.\nHalyde cannot be installed.")
  return
end

if width<80 then
  gpu.set(1,1,"Are you sure you would like to install Halyde?")
else
  gpu.set(1,1,"Are you sure you would like to install Halyde to "..installLocation.."?")
end
gpu.set(1,2,"This will erase all data on this disk.")
gpu.set(1,height-1,"Press Y to accept, or N to cancel.")
gpu.set(3,4,"Capacity: ")
gpu.set(3,5,"Used: ")
gpu.set(3,6,"ID: ")
gpu.set(3,7,"Label: ")
gpu.setForeground(0x00FF00)
if width>=80 then
  gpu.set(50,1,installLocation)
end
gpu.set(13,4,math.floor(component.invoke(installAddress,"spaceTotal")/1024).." KiB")
gpu.set(9,5,math.floor(component.invoke(installAddress,"spaceUsed")/1024).." KiB")
gpu.set(7,6,installAddress)
gpu.set(10,7,component.invoke(installAddress,"getLabel") or "No label")

if keyboard.keys[({event.pull("key_down")})[4]]=="n" then
  return reset()
end

-- installation

local computer = require("computer")

local function getFile(url)
  local request, data, tmpdata = nil, "", nil
  local status, errorMessage = pcall(function()
    request = internet.request(url)
    request:finishConnect()
  end)
  if not status then
    return false, errorMessage
  end
  local responseCode = request:response()
  if responseCode and responseCode ~= 200 then
    return false, responseCode
  end
  repeat
    tmpdata = request.read(math.huge)
    data = data .. (tmpdata or "")
  until not tmpdata
  return data
end

-- installation graphics
local webInstallConfig
local installationOrder = {"halyde", "edit", "argentum", "webinstall-extras"}

gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1,1,width,height," ")

local function lpad(str, len, char)
  str=tostring(str)
  if char == nil then char = ' ' end
  return string.rep(char, len - #str) .. str
end

local function progress(package,progress)
  local total = 0
  if webInstallConfig and type(webInstallConfig)=="table" then
    for i,pck in ipairs(installationOrder) do
      local packConfig = webInstallConfig[pck]
      -- print(pck,packConfig)
      total=total+#(packConfig.directories or {})+#(packConfig.files or {})
    end
  else
    total=1
  end

  local info = ""
  local realProgress = 1
  if type(package)=="string" then
    realProgress = progress
    info = string.format("%s %s%%",package,lpad(math.floor(progress*100),2))
  else
    realProgress = 0
    for i=1,package do
      local packConfig = webInstallConfig[installationOrder[i]]
      if i==package then
        realProgress=realProgress+progress
      else
        local value = #(packConfig.directories or {})+#packConfig.files
        realProgress=realProgress+value
      end
    end
    realProgress=realProgress/total
    local packConfig = webInstallConfig[installationOrder[package]]
    progress=progress/(#(packConfig.directories or {})+#packConfig.files)
    -- realProgress = (progress+package-1)/#installationOrder
    local packInfo = installationOrder[package].." "..lpad(math.floor(progress*100),2).."%"
    info = string.format("%s%% [%s]",lpad(math.floor(realProgress*100),2),packInfo)
  end

  info=info..string.rep(" ",width-#info)
  local progX = math.floor(realProgress*width)
  gpu.setBackground(0x00FF00)
  gpu.setForeground(0x000000)
  gpu.set(1,height,info:sub(1,progX))
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.set(progX+1,height,info:sub(progX+1))
end
local logY = 1
local function log(txt)
  if logY>=height then
    gpu.copy(1,2,width,height-2,0,-1)
    gpu.fill(1,height-1,width,1," ")
    logY=logY-1
  end
  gpu.set(1,logY,txt)
  logY=logY+1
end
----------------------------

log("Fetching Argentum configuration for Halyde")
progress("Preparing",0)
webInstallConfig = getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/main/argentum.cfg")
log("Loading Argentum configuration")
progress("Preparing",0.5)
webInstallConfig = load(webInstallConfig)
webInstallConfig = webInstallConfig()
log("Looking for outdated files in the drive")
progress("Preparing",1)
local oldFiles = {}
for oldFile in fs.list(installLocation) do
  local usedFlag = false
  for i = 1, 3 do
    for _, file in pairs(webInstallConfig[installationOrder[i]].files) do
      if oldFile == file then
        usedFlag = true
      end
    end
    if webInstallConfig[installationOrder[i]].directories then
      for _, dir in pairs(webInstallConfig[installationOrder[i]].directories) do
        if oldFile == dir .. "/" then
          usedFlag = true
        end
      end
    end
  end
  if oldFile=="halyde/" then usedFlag = true end
  if not usedFlag then
    table.insert(oldFiles, oldFile)
  end
end
log("Found "..#oldFiles)
progress(1,0)

for i = 1, 4 do
  local webInstallConfig = webInstallConfig[installationOrder[i]]
  local dirCount = 0
  if webInstallConfig.directories then
    dirCount=#webInstallConfig.directories
    for dirIdx, directory in ipairs(webInstallConfig.directories) do
      log("Creating " .. directory .. "...")
      progress(i,dirIdx-1)
      fs.makeDirectory(installLocation .. directory)
    end
  end
  for fileIdx, file in ipairs(webInstallConfig.files) do
    log("Downloading " .. file .. "...")
    progress(i,fileIdx-1+dirCount)
    local handle = fs.open(installLocation .. file, "w")
    handle:write(getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/main/" .. file))
    handle:close()
  end
end
for i, oldFile in ipairs(oldFiles) do
  log("Removing "..oldFile)
  progress("Finishing up",(i-1)/#oldFiles*1)
  fs.remove(installLocation .. oldFile)
end

log("Setting boot address")
progress("Finishing up",1)
computer.setBootAddress(component.get(installLocation:sub(6, -2)))

log("Setting label to Halyde")
component.invoke(component.get(installLocation:sub(6, -2)), "setLabel", "Halyde")

gpu.fill(1,1,width,height," ")
computer.shutdown(true)

local loadfile = ...
local filesystem = loadfile("/halyde/lib/filesystem.lua")(loadfile)

_G._OSVERSION = "Halyde 1.14.1"
_G._OSLOGO = ""
local handle, tmpdata = filesystem.open("/halyde/config/oslogo.ans", "r"), nil
repeat
  tmpdata = handle:read(math.huge)
  _OSLOGO = _OSLOGO .. (tmpdata or "")
until not tmpdata

_G.package = {["preloaded"] = {}}

loadfile("/halyde/core/datatools.lua")()

function _G.import(module, ...)
  local args = table.pack(...)
  if package.preloaded[module] then
    return package.preloaded[module]
  end
  local modulepath
  if filesystem.exists(module) then
    modulepath = module
  elseif filesystem.exists("/halyde/lib/"..module..".lua") then
    modulepath = "/halyde/lib/"..module..".lua"
  elseif shell and shell.workingDirectory and filesystem.exists(shell.workingDirectory..module) then
    modulepath = shell.workingDirectory..module
  end
  assert(modulepath, "module not found\npossible locations:\n/halyde/lib/"..module..".lua")
  local handle, data, tmpdata = filesystem.open(modulepath), "", nil
  repeat
    tmpdata = handle:read(math.huge or math.maxinteger)
    data = data .. (tmpdata or "")
  until not tmpdata
  return(assert(load(data, "="..modulepath))(table.unpack(args)))
end

local function preload(module)
  local handle, data, tmpdata = assert(filesystem.open("/halyde/lib/" .. module .. ".lua", "r")), "", nil
  repeat
    tmpdata = handle:read(math.huge or math.maxinteger)
    data = data .. (tmpdata or "")
  until not tmpdata
  package.preloaded[module] = assert(load(data, "="..module))()
  _G[module] = nil
end

preload("component")
preload("computer")

local component = import("component")
local gpu = component.gpu
local screenAddress = component.list("screen")()
--local screen = component.screen

gpu.bind(screenAddress)
--local maxWidth, maxHeight = gpu.maxResolution()
--local aspectX, aspectY = screen.getAspectRatio()
--local screenRatio = aspectX * 2 / aspectY

-- Calculate potential dimensions
--local widthLimited = math.floor(maxHeight * screenRatio)
--local heightLimited = math.floor(maxWidth / screenRatio)

--local targetWidth, targetHeight

--if widthLimited <= maxWidth then
  -- height is the limiting factor
--  targetWidth = widthLimited
--  targetHeight = maxHeight
--else
  -- width is the limiting factor
--  targetWidth = maxWidth
--  targetHeight = heightLimited
--end

--targetWidth = math.min(targetWidth, maxWidth)
--targetHeight = math.min(targetHeight, maxHeight)

--gpu.setResolution(targetWidth, targetHeight)
gpu.setResolution(gpu.maxResolution())

--local handle = assert(filesystem.open("/bazinga.txt", "w"))
--assert(handle:write("Bazinga!"))
--handle:close()

local fs = import("filesystem")
if not fs.exists("/halyde/config/shell.json") then -- Auto-generate configs
  fs.copy("/halyde/config/generate/shell.json", "/halyde/config/shell.json")
end
if not fs.exists("/halyde/config/startupapps.json") then
  fs.copy("/halyde/config/generate/startupapps.json", "/halyde/config/startupapps.json")
end
fs = nil

import("/halyde/core/cormgr.lua")

local loadfile = ...
local filesystem = assert(loadfile("/lib/filesystem.lua")(loadfile))
_G._OSVERSION = "HALYDE VERSION" -- TODO: Put this in a separate config file
_G._OSLOGO = ""
_G._PUBLIC = {}

local handle, tmpdata = filesystem.open("/halyde/config/oslogo.ans", "r"), nil
repeat
  tmpdata = handle:read(math.huge)
  _OSLOGO = _OSLOGO .. (tmpdata or "")
until not tmpdata

_G.package = {["preloaded"] = {}}

loadfile("/halyde/kernel/modules/datatools.lua")()

function _G.require(module, ...)
  local args = table.pack(...)
  if package.preloaded[module] then
    return package.preloaded[module]
  end
  local modulepath
  if filesystem.exists(module) then
    modulepath = module
  elseif filesystem.exists("/lib/" .. module .. ".lua") then
    modulepath = "/lib/" .. module .. ".lua"
  elseif shell and shell.workingDirectory and filesystem.exists(filesystem.concat(shell.workingDirectory, module .. ".lua")) then
    modulepath = shell.workingDirectory .. module .. ".lua"
  end
  assert(modulepath, "Module not found\nPossible locations:\n/lib/" .. module .. ".lua")
  local handle, data, tmpdata = filesystem.open(modulepath), "", nil
  repeat
    tmpdata = handle:read(math.huge or math.maxinteger)
    data = data .. (tmpdata or "")
  until not tmpdata
  handle:close()
  return(assert(load(data, "="..modulepath))(table.unpack(args)))
end

function _G.package.preload(module)
  local handle, data, tmpdata = assert(filesystem.open("/lib/" .. module .. ".lua", "r")), "", nil
  repeat
    tmpdata = handle:read(math.huge or math.maxinteger)
    data = data .. (tmpdata or "")
  until not tmpdata
  handle:close()
  package.preloaded[module] = assert(load(data, "="..module))()
  _G[module] = nil
end

require("/halyde/kernel/datatools.lua") -- If this is not imported BEFORE modload gets run, modload requires filesystem which requires computer which requires datatools. TODO: When VFS is implemented, make the pre-VFS loading of filesystem load a more basic version. And remove this.
require("/halyde/kernel/modload.lua")

package.preload("component")
package.preload("computer")

local component = require("component")
local gpu = component.gpu
local screenAddress = component.list("screen")()

gpu.bind(screenAddress)
gpu.setResolution(gpu.maxResolution())

if not filesystem.exists("/halyde/config/shell.json") then -- Auto-generate configs
  filesystem.copy("/halyde/config/generate/shell.json", "/halyde/config/shell.json")
end
if not filesystem.exists("/halyde/config/startupapps.json") then
  filesystem.copy("/halyde/config/generate/startupapps.json", "/halyde/config/startupapps.json")
end

require("/halyde/kernel/tsched.lua")

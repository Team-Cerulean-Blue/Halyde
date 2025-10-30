local loadfile = ...
local filesystem = assert(loadfile("/lib/filesystem.lua")(loadfile))
_G._OSVERSION = "HALYDE VERSION" -- TODO: Put this in a separate config file
_G._PUBLIC = {}
_G._PUBLIC.unicode = assert(loadfile("/lib/unicode.lua")(loadfile))
local component = assert(loadfile("/lib/component.lua")(loadfile))
local gpu = component.gpu
local screenAddress = component.list("screen")()

gpu.bind(screenAddress)
gpu.setResolution(gpu.maxResolution())

local log = assert(loadfile("/lib/log.lua")(loadfile))

log.kernel.info("Bound GPU to screen " .. tostring(screenAddress))

_G.package = { ["preloaded"] = {} }

function _G.reqgen(load)
  return function(module, ...)
    local args = table.pack(...)
    if package.preloaded[module] then
      return package.preloaded[module]
    end
    local modulepath
    if filesystem.exists(module) and not filesystem.isDirectory(module) then
      modulepath = module
    elseif
      filesystem.exists("/lib/" .. module .. ".lua") and not filesystem.isDirectory("/lib/" .. module .. ".lua")
    then
      modulepath = "/lib/" .. module .. ".lua"
    elseif
      shell
      and shell.workingDirectory
      and filesystem.exists(filesystem.concat(shell.workingDirectory, module .. ".lua"))
      and not filesystem.isDirectory(filesystem.concat(shell.workingDirectory, module .. ".lua"))
    then
      modulepath = shell.workingDirectory .. module .. ".lua"
    end
    assert(modulepath, "Module not found\nPossible locations:\n/lib/" .. module .. ".lua") -- FIXME: When providing an absolute path, this spits out some weird stuff.
    local handle, data, tmpdata = filesystem.open(modulepath), "", nil
    repeat
      tmpdata = handle:read(math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    handle:close()
    return (assert(load(data, "=" .. modulepath))(table.unpack(args)))
  end
end

_G.require = reqgen(_G.load)
log.kernel.info("Generated userland require function")

function _G.package.preload(module)
  local handle, data, tmpdata = assert(filesystem.open("/lib/" .. module .. ".lua", "r")), "", nil
  repeat
    tmpdata = handle:read(math.huge or math.maxinteger)
    data = data .. (tmpdata or "")
  until not tmpdata
  handle:close()
  package.preloaded[module] = assert(load(data, "=" .. module))()
  _G[module] = nil
  log.kernel.info(string.format("Pre-loaded /lib/%s.lua", module))
end

require("/halyde/kernel/datatools.lua") -- If this is not imported BEFORE modload gets run, modload requires filesystem which requires computer which requires datatools. TODO: When VFS is implemented, make the pre-VFS loading of filesystem load a more basic version. And remove this.
log.kernel.info("Loading modules")
require("/halyde/kernel/modload.lua")

package.preload("component")
package.preload("computer")
package.preload("log")
package.preload("event")

local computer = require("computer")
function wait(seconds)
  local oldTime = computer.uptime()
  while computer.uptime() < oldTime + seconds do
    coroutine.yield()
  end
end

if not filesystem.exists("/halyde/config/startupapps.json") then
  filesystem.copy("/halyde/config/generate/startupapps.json", "/halyde/config/startupapps.json")
end

log.kernel.info("Starting tsched")
require("/halyde/kernel/tsched.lua")

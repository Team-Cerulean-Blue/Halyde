local fs = require("filesystem")

local modulePath = "/halyde/kernel/modules"

local modules = assert(fs.list(modulePath))
local moduleTypes = {}

local function loadModule(modName)
  local moduleData = assert(require(fs.concat(modulePath, modName)), "Module did not return anything!") -- TODO: Make this not actually throw an error, rather put something in the log and move on
  table.remove(modules, table.find(modules, modName))
  if not moduleData.check() then
    return
  end
  if moduleData.dependencies then
    for _, dependency in pairs(moduleData.dependencies) do
      if table.find(modules, dependency) then
        loadModule(dependency)
      elseif table.find(modules, dependency .. ".lua") then
        loadModule(dependency .. ".lua")
      else
        for typeLookupDrvName, typeLookupDrvType in pairs(moduleTypes) do
          if typeLookupDrvType == dependency then
            loadModule(typeLookupDrvName)
            -- Don't break, because there can be multiple modules of the correct type
          end
        end
      end
    end
  end
  --print(modName)
  if moduleData.init then -- I have no idea why this would not exist, but it's a failsafe
    moduleData.init()
  end
end

for _, modName in pairs(modules) do -- Get all the module types
  local moduleData = assert(require(fs.concat(modulePath, modName)), "Module did not return anything!") -- TODO: Make this not actually throw an error, rather put something in the log and move on
  if moduleData.type then
    --print(moduleData.type)
    moduleTypes[modName] = moduleData.type -- Not the other way around because there can be multiple modules of the same type, but there can't be multiple entries with the same key
  end
end

while modules[1] do
  if modules[1]:sub(-1, -1) ~= "/" then -- Check if it's not a directory. If it is, it might be module config
    loadModule(modules[1])
  end
end

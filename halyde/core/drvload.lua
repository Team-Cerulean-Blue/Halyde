local fs = import("filesystem")

local driverPath = "/halyde/drivers"

local drivers = fs.list(driverPath)
local driverTypes = {}

local function loadDriver(drvName)
  local driverData = import(fs.concat(driverPath, drvName))
  table.remove(drivers, table.find(drivers, drvName))
  if driverData.dependencies then
    for _, dependency in pairs(driverData.dependencies) do
      if table.find(drivers, dependency) then
        loadDriver(dependency)
      elseif table.find(drivers, dependency .. ".lua") then
        loadDriver(dependency .. ".lua")
      else
        for typeLookupDrvName, typeLookupDrvType in pairs(driverTypes) do
          if typeLookupDrvType == dependency then
            loadDriver(typeLookupDrvName)
            -- Don't break, because there can be multiple drivers of the correct type
          end
        end
      end
    end
  end
  --print(drvName)
  if driverData.onStartup then -- I have no idea why would this not exist, but it's a failsafe
    driverData.onStartup()
  end
  -- More functions to be implemented in the future
end

for _, drvName in pairs(drivers) do -- Get all the driver types
  local driverData = import(fs.concat(driverPath, drvName))
  if driverData.type then
    --print(driverData.type)
    driverTypes[drvName] = driverData.type -- Not the other way around because there can be multiple drivers of the same type, but there can't be multiple entries with the same key
  end
end

for _, drvName in pairs(drivers) do -- Load the drivers
  if drvName:sub(-1, -1) ~= "/" then -- Check if it's not a directory. Otherwise it might be driver config
    loadDriver(drvName)
  end
end

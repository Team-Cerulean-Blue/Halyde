local log = require("log")
local fs = require("filesystem")

local modulePath = "/halyde/kernel/modules"

if not (fs.exists(modulePath) or fs.isDirectory(modulePath)) then
  return log.kernel.warn(
    string.format("Module directory (%s) does not exist and/or has been detected as a file - skipping", modulePath)
  )
end
local moduleList, err = fs.list(modulePath)
if not moduleList then
  return log.kernel.warn(
    string.format("Could not get list of modules (from %s): %s", modulePath, tostring(err or "unknown error"))
  )
end
local modules = {}
local moduleTypes = {}
local modulesLoaded = {}

local function loadModule(modName)
  if table.find(modulesLoaded, modName) then
    log.kernel.warn(string.format("[modload: %s] Module was already loaded - skipping", modName))
    return true
  end

  local moduleData = modules[modName]
  if not moduleData then
    log.kernel.warn(string.format("[modload: %s] Could not find module data.", modName))
    table.remove(moduleList, table.find(moduleList, modName))
    return true
  end
  local ready = false
  local status, err = xpcall(function()
    ready = moduleData.check()
  end, debug.traceback)
  if not status then
    ready = false
    log.kernel.error(
      string.format("[modload: %s] Could not check if module was ready: %s", modName, tostring(err or "unknown error"))
    )
  end
  if not ready then
    log.kernel.info(string.format("[modload: %s] Module not ready - skipping", modName))
    return false
  end
  if type(moduleData.dependencies) == "table" then
    for _, dependency in pairs(moduleData.dependencies) do
      if table.find(moduleList, dependency) then
        loadModule(dependency)
      elseif table.find(moduleList, dependency .. ".lua") then
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
  log.kernel.info(string.format("[modload: %s] Loading module", modName))
  if moduleData.init then -- I have no idea why this would not exist, but it's a failsafe
    local status, err = xpcall(function()
      moduleData.init()
    end, debug.traceback)
    if not status then
      log.kernel.error(
        string.format(
          "[modload: %s] An error has occured while initiating this module: %s",
          modName,
          tostring(err or "unknown error")
        )
      )
      return false
    else
      table.insert(modulesLoaded, modName)
      table.remove(moduleList, table.find(moduleList, modName))
    end
  end
  return true
end

for _, modName in pairs(moduleList) do -- Get all the module types
  log.kernel.info(string.format("[modload: %s] Getting data from module", modName))
  local moduleData
  local status, err = pcall(function()
    moduleData = require(fs.concat(modulePath, modName))
  end)
  if not status then
    log.kernel.error(
      string.format(
        "[modload: %s] Module returned error while getting data: %s",
        modName,
        tostring(err or "unknown error")
      )
    )
    goto continue
  end
  if type(moduleData) ~= "table" then
    log.kernel.error(
      string.format("[modload: %s] Module returned invalid type (%s) - skipping", modName, type(moduleData))
    )
    goto continue
  end
  if type(moduleData.check) ~= "function" then
    log.kernel.error(string.format('[modload: %s] Module doesn\'t contain a "check" function', modName))
    goto continue
  end
  if type(moduleData.init) ~= "function" then
    log.kernel.error(string.format('[modload: %s] Module doesn\'t contain an "init" function', modName))
    goto continue
  end
  if type(moduleData.exit) ~= "function" then
    log.kernel.error(string.format('[modload: %s] Module doesn\'t contain an "exit" function', modName))
    goto continue
  end
  modules[modName] = moduleData
  if moduleData.type then
    --print(moduleData.type)
    moduleTypes[modName] = moduleData.type -- Not the other way around because there can be multiple modules of the same type, but there can't be multiple entries with the same key
  end
  ::continue::
end

local function loadAllModules() -- attempt at loading all modules, unless if they're not ready
  local notReadyModules = {}
  while moduleList[1] do
    if moduleList[1]:sub(-1, -1) ~= "/" then -- Check if it's not a directory. If it is, it might be module config
      local ready = loadModule(moduleList[1])
      if not ready then
        table.insert(notReadyModules, table.remove(moduleList, 1))
      end
    end
  end
  moduleList = notReadyModules
  -- log.kernel.info("debug: modload finished attempting loading modules. remaining: " .. table.concat(moduleList, ","))
end

loadAllModules()

local function checkModules()
  log.kernel.info("[modload] Updating module availability.")
  loadAllModules() -- load modules that haven't returned true before
  -- exit modules that haven't returned false before (check if this is right first)
  for _, v in pairs(table.copy(modulesLoaded)) do
    local ready = false
    local status, err = xpcall(function()
      ready = modules[v].check()
    end, debug.traceback)
    if not status then
      ready = false
      log.kernel.error(
        string.format(
          "[modload: %s] Could not check if module was ready: %s",
          modName,
          tostring(err or "unknown error")
        )
      )
    end
    if not ready then
      log.kernel.info(string.format("[modload: %s] Module is no longer ready: exiting", v))
      local status, err = xpcall(function()
        modules[v].exit()
      end, debug.traceback)
      if not status then
        log.kernel.error(string.format("[modload: %s] Could not exit module: %s", v, tostring(err or "unknown error")))
      end
      table.insert(moduleList, table.remove(modulesLoaded, table.find(modulesLoaded, v)))
    end
  end
end

if _PUBLIC.tsched then
  _PUBLIC.tsched.addTask(function()
    local event = require("event")
    while true do
      event.pull("component_added", "component_removed") -- wait until a component gets added or removed
      checkModules()
    end
  end, "modload")
end

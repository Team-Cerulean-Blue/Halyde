local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")
local json = require("json")
local gpu = component.gpu
local log = require("log")

function handleError(errormsg)
  if errormsg == nil then -- TODO: Replace with proper error handling
    print("\27[91munknown error" .. "\n \n" .. debug.traceback())
  else
    print("\27[91m" .. tostring(errormsg) .. "\n \n" .. debug.traceback())
  end
end

local function runTasks()
  for i = 1, #_G.tsched.tasks do
    if tsched.tasks[i] then
      tsched.currentTask = tsched.tasks[i]
      local result, errorMessage = coroutine.resume(tsched.tasks[i].task)
      if not result then
        handleError(errorMessage)
      end
      if not tsched.tasks[i] then
        log.kernel.warn("Attempted to update a non-existent task. This is likely because it was removed.")
      elseif coroutine.status(tsched.tasks[i].task) == "dead" then
        _PUBLIC.tsched.removeTask(tsched.tasks[i].id)
        --ocelot.log("Removed coroutine")
        i = i - 1
      end
      --computer.pullSignal(0)
      --coroutine.yield()
    end
  end
end

local function taskFunction()
  local result, errorMessage = xpcall(function()
    if not filesystem.exists("/halyde/kernel/evmgr.lua") then
      error("No such file: /halyde/kernel/evmgr.lua")
    end
    local handle, data, tmpdata = filesystem.open("/halyde/kernel/evmgr.lua"), "", nil
    repeat
      tmpdata = handle:read(math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    handle:close()
    assert(load(data, "=/halyde/kernel/evmgr.lua"))()
  end, function(errorMessage)
    return errorMessage .. "\n \n" .. debug.traceback()
  end, "/halyde/kernel/evmgr.lua")
  if not result then
    if print then
      gpu.freeAllBuffers()
      print("\n\27[91m" .. errorMessage)
    else
      error(errorMessage)
    end
  end
end
_PUBLIC.tsched.addTask(taskFunction, "evmgr")
package.preload("event")

log.kernel.info("Starting startup apps...")
local handle, data, tmpdata = filesystem.open("/halyde/config/startupapps.json", "r"), "", nil
repeat
  tmpdata = handle:read(math.huge or math.maxinteger)
  data = data .. (tmpdata or "")
until not tmpdata
handle:close()
for _, line in ipairs(json.decode(data)) do
  if line ~= "" then
    --[[ if _G.print then
      print(line)
    end ]]
    _G._PUBLIC.tsched.runAsTask(line)
    runTasks()
  end
end
-- _G.cormgr.loadCoroutine("/halyde/core/shell.lua")

log.setPrintLogs(false)
while true do
  runTasks()
  if #_G.tsched.tasks == 0 then
    log.kernel.warn("No more tasks left! Shutting down...")
    computer.shutdown()
  end
end

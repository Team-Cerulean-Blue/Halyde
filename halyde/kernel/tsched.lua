local idCounter = 1

_G._PUBLIC.tsched = {}
_G.tsched = {}
_G.tsched.tasks = {}

local currentTask

local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")
local json = require("json")
local gpu = component.gpu
local log = require("log")

function _G._PUBLIC.tsched.runAsTask(path, ...)
  checkArg(1, path, "string")
  local args = { ... }
  local function taskFunction()
    local result, errorMessage = xpcall(function(...)
      local args = table.pack(...)
      if not filesystem.exists(path) then
        error("No such file: " .. path)
      end
      local handle, data, tmpdata = filesystem.open(path), "", nil
      repeat
        tmpdata = handle:read(math.huge or math.maxinteger)
        data = data .. (tmpdata or "")
      until not tmpdata
      handle:close()

      -- Userland environment definition
      local userland = table.copy(_PUBLIC)
      userland._G = userland
      userland.load = function(chunk, chunkname, mode, env)
        if not env or env == _G then
          env = userland
        end -- if they SOMEHOW get the kernel environment they're not running jack shit
        return load(chunk, chunkname, mode, env)
      end
      userland.require = reqgen(userland.load)

      assert(load(data, "=" .. path, "t", userland))(table.unpack(args))
    end, function(errorMessage)
      return errorMessage .. "\n \n" .. debug.traceback()
    end, --[[ path,]] table.unpack(args))
    if not result then
      if print then
        gpu.freeAllBuffers()
        print("\n\27[91m" .. errorMessage)
      else
        error(errorMessage)
      end
    end
    --require(path, table.unpack(args))
  end
  local _, taskInfo = _PUBLIC.tsched.addTask(taskFunction, string.match(tostring(path), "([^/]+)%.lua$"))
  taskInfo.path = path
  taskInfo.args = table.copy(args)
end

function _G._PUBLIC.tsched.addTask(func, name)
  checkArg(1, func, "function")
  checkArg(2, name, "string")
  local task = coroutine.create(func)
  local taskInfo = { ["task"] = task, ["name"] = name, ["id"] = idCounter }
  if type(currentTask) == "table" and type(currentTask.id) == "number" then
    taskInfo.parent = currentTask.id
  end
  table.insert(tsched.tasks, taskInfo)
  idCounter = idCounter + 1
  if taskInfo.parent then
    log.kernel.info(
      "Created task " .. name .. " with PID " .. idCounter - 1 .. " by parent with PID " .. taskInfo.parent
    )
  else
    log.kernel.info("Created task " .. name .. " with PID " .. idCounter - 1 .. " (no parent found)")
  end
  return task, taskInfo
end

function _G._PUBLIC.tsched.removeTask(id)
  checkArg(1, id, "number")
  -- TODO: Check for user permissions before running
  for index, task in pairs(tsched.tasks) do
    if task.id == id then
      table.remove(tsched.tasks, index)
      log.kernel.info("Removed task with PID " .. id)
      return true
    end
  end
  log.kernel.warn("Tried to remove task that doesn't exist - PID " .. id)
  return false
end

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
      currentTask = tsched.tasks[i]
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

function _G._PUBLIC.tsched.getCurrentTask()
  return table.copy(currentTask)
end

function _G._PUBLIC.tsched.getTasks()
  return table.copy(tsched.tasks)
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

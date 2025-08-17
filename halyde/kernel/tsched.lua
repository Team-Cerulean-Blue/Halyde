_G._PUBLIC.tsched = {}
_G.tsched = {}
_G.tsched.tasks = {}

local currentTask

local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")
local json = require("json")
local gpu = component.gpu
local ocelot = component.ocelot

function _G._PUBLIC.tsched.runAsTask(path,...)
  local args = {...}
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

      assert(load(data, "="..path, "t", userland))(table.unpack(args))
    end, function(errorMessage)
      return errorMessage .. "\n \n" .. debug.traceback()
    end, path, table.unpack(args))
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
  _PUBLIC.tsched.addTask(taskFunction, string.match(tostring(path), "([^/]+)%.lua$"))
end

function _G._PUBLIC.tsched.addTask(func, name)
  ocelot.log("Added task " .. name)
  local task = coroutine.create(func)
  table.insert(tsched.tasks, {["task"] = task, ["name"] = name})
  return task
end

function _G._PUBLIC.tsched.removeTask(id)
  -- TODO: Check for user permissions before running
  table.remove(_G.tsched.tasks, id)
end

function handleError(errormsg)
  if errormsg == nil then -- TODO: Replace with proper error handling (if this isn't considered proper..?)
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
      if coroutine.status(tsched.tasks[i].task) == "dead" then
        _PUBLIC.tsched.removeTask(i)
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

while true do
  runTasks()
  if #_G.tsched.tasks == 0 then
    computer.beep(1000, 0.5)
    while true do
      computer.pullSignal()
    end
  end
end

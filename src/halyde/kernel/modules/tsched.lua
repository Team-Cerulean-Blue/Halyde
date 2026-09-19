local module = {}

module.dependencies = {}

function module.check()
  return true
end

function module.init()
  _G._PUBLIC.tsched = {}
  _G.tsched = {}
  _G.tsched.tasks = {}

  local component = require("component")
  local filesystem = require("filesystem")
  local gpu = component.gpu
  local log = require("log")

  tsched.idCounter = 1

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
    local taskInfo = { ["task"] = task, ["name"] = name, ["id"] = tsched.idCounter }
    if type(tsched.currentTask) == "table" and type(tsched.currentTask.id) == "number" then
      taskInfo.parent = tsched.currentTask.id
      taskInfo.user = tsched.currentTask.user
    end
    table.insert(tsched.tasks, taskInfo)
    tsched.idCounter = tsched.idCounter + 1
    if taskInfo.parent then
      log.kernel.info(
        ("[tsched] Created task %s (PID %d) by parent PID %d as UID %d"):format(
          name,
          tsched.idCounter - 1,
          taskInfo.parent,
          taskInfo.user
        )
      )
    else
      taskInfo.user = 1 -- It's probably being run from kernel level
      log.kernel.info(
        string.format("[tsched] Created task %s (PID %d) as UID 1 (no parent found)", name, tsched.idCounter - 1)
      )
    end
    return task, taskInfo
  end

  function _G._PUBLIC.tsched.removeTask(id)
    checkArg(1, id, "number")
    -- TODO: Check for user permissions before running
    for index, task in pairs(tsched.tasks) do
      if task.id == id then
        table.remove(tsched.tasks, index)
        log.kernel.info(string.format("[tsched] Removed task with PID %d", id))
        return true
      end
    end
    log.kernel.warn(string.format("[tsched] Tried to remove task that doesn't exist - PID %d", id))
    return false
  end

  function _G._PUBLIC.tsched.getCurrentTask()
    return table.copy(tsched.currentTask)
  end

  function _G._PUBLIC.tsched.getTasks()
    return table.copy(tsched.tasks)
  end
end

function module.exit()
  -- why would you even want to
  _G._PUBLIC.tsched = nil
  _G.tsched = nil
  _G.tsched.tasks = nil
end

return module

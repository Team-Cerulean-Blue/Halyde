local module = {}

function module.check()
  return true -- The user system is kind of essential all the time...
end

function module.init()
  local fs = require("filesystem")
  local md5 = require("md5")
  local json = require("json")
  local log = require("log")

  _PUBLIC.user = {}

  function _PUBLIC.user.addTask(func, name, userId, userPassword)
    checkArg(1, func, "function")
    checkArg(2, name, "string")
    checkArg(3, userId, "number")
    checkArg(4, userPassword, "string")

    local handle, data, tmpdata = fs.open("/halyde/kernel/userreg.json"), "", nil
    repeat
      tmpdata = handle:read(math.huge)
      data = data .. (tmpdata or "")
    until not tmpdata

    local userRegistry = json.decode(data)

    if not userRegistry[userId] then
      return false, "No such UID"
    end

    local salt = md5.sumhexa(userRegistry[userId].name) -- A little bit of salt and pepper
    local passwordHash = md5.sumhexa(userPassword .. salt)
    if passwordHash ~= userRegistry[userId].hash then
      wait(3) -- Something to hopefully shove away brute forcers
      return false, "Password incorrect"
    end

    local task = coroutine.create(func)
    local taskInfo = { ["task"] = task, ["name"] = name, ["id"] = #_PUBLIC.tsched.getTasks() + 1, ["user"] = userId}
    if type(tsched.currentTask) == "table" and type(tsched.currentTask.id) == "number" then
      taskInfo.parent = tsched.currentTask.id
    end
    table.insert(tsched.tasks, taskInfo)
    if taskInfo.parent then
      log.kernel.info(
        ("[tsched (user)] Created task %s (PID %d) by parent PID %d as UID %d"):format(name, #_PUBLIC.tsched.getTasks(), taskInfo.parent, taskInfo.user)
      )
      log.kernel.info(string.format("[tsched (user)] Created task %s (PID %d) as UID %d (no parent found)", name, #_PUBLIC.tsched.getTasks(), taskInfo.user))
    end
    return task, taskInfo
  end
end

function module.exit() -- Ok bro
  _PUBLIC.user = nil
end

return module

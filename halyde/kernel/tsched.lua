local computer = require("computer")
local filesystem = require("filesystem")
local json = require("json")
local log = require("log")

function handleError(errormsg)
  local traceback = debug.traceback()
  if errormsg == nil then -- TODO: Replace with proper error handling
    print("\27[91munknown error" .. "\n \n" .. traceback)
    log.kernel.error(string.format("[tsched] Process ID %d has crashed!\n\n%s", tsched.currentTask.id, traceback))
  else
    print("\27[91m" .. tostring(errormsg) .. "\n \n" .. traceback)
    log.kernel.error(
      string.format(
        "[tsched] Process ID %d has crashed: %s\n\n%s",
        tsched.currentTask.id,
        tostring(errormsg),
        traceback
      )
    )
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
        log.kernel.warn("[tsched] Attempted to update a non-existent task. This is likely because it was removed.")
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

log.kernel.info("[tsched] Starting startup apps...")
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
    log.kernel.warn("[tsched] No more tasks left! Shutting down...")
    computer.shutdown()
  end
end

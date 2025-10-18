local computer = require("computer")
local event = {}

local bufferTime = 0.1 -- A little bit of buffer time so events won't be skipped by accident.

--local ocelot = component.proxy(component.list("ocelot")())
function event.pull(...)
  local pid = _PUBLIC.tsched and _PUBLIC.tsched.getCurrentTask() and _PUBLIC.tsched.getCurrentTask().id or "kernel"
  if not evmgr.eventQueue[pid] then
    evmgr.eventQueue[pid] = {}
  end
  local eventQueue = evmgr.eventQueue[pid]
  local args = { ... }
  local evtypes, timeout = {}, nil

  for _, arg in pairs(args) do
    if type(arg) == "number" and not timeout then -- It's a timeout
      timeout = arg
    else -- It's an event type
      table.insert(evtypes, tostring(arg))
    end
  end

  local startTime = computer.uptime()

  while true do
    -- Check event queue for matching event
    for i = 1, #eventQueue do
      local foundevent = false
      if evtypes[1] then -- event type(s) specified
        for _, evtype in pairs(evtypes) do
          if eventQueue[i][2] == evtype and eventQueue[i][1] >= startTime - bufferTime then
            foundevent = true
          end
        end
      else
        if eventQueue[i][1] >= startTime - bufferTime then
          foundevent = true
        end
      end
      if foundevent then
        -- Found matching event (or any event if no type specified)
        local result = table.copy(eventQueue[i])
        table.remove(eventQueue, i)
        table.remove(result, 1) -- remove the time of event argument
        return table.unpack(result)
      end
    end

    -- Check if we've timed out
    if timeout and computer.uptime() >= startTime + timeout then
      return nil -- Timed out, return nil
    end

    -- Yield to allow other processes to run and more events to be added
    if timeout and timeout > 0 then
      coroutine.yield()
    elseif not timeout then
      coroutine.yield()
    end
  end
end

return event

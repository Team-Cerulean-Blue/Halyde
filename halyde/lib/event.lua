local computer = import("computer")
local event = {}

local bufferTime = 0.1 -- A little bit of buffer time so events won't be skipped by accident.

--local ocelot = component.proxy(component.list("ocelot")())
function event.pull(...)
  local args = {...}
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
    for i = 1, #evmgr.eventQueue do
      local foundevent = false
      if evtypes[1] then -- event type(s) specified
        for _, evtype in pairs(evtypes) do
          if evmgr.eventQueue[i][2] == evtype and evmgr.eventQueue[i][1] >= startTime - bufferTime then
            foundevent = true
          end
        end
      else
        if evmgr.eventQueue[i][1] >= startTime - bufferTime then
          foundevent = true
        end
      end
      if foundevent then
        -- Found matching event (or any event if no type specified)
        local result = table.copy(evmgr.eventQueue[i])
        table.remove(evmgr.eventQueue, i)
        table.remove(result, 1) -- remove the time of event argument
        return table.unpack(result)
      end
    end
    
    -- Check if we've timed out
    if timeout and computer.uptime() >= startTime + timeout then
      return nil  -- Timed out, return nil
    end
    
    -- Yield to allow other processes to run and more events to be added
    coroutine.yield()
  end
end

return event

local module = {}

module.dependencies = { "tsched", "keyboard" }

function module.check()
  return true
end

local process

function module.init()
  _G.evmgr = {}
  _G.evmgr.eventQueue = { kernel = {} }
  local maxEventQueueLength = 10 -- increase if events start getting dropped

  local computer = require("computer")

  local ctrlDown = false
  local altDown = false
  local shiftDown = false

  function _G._PUBLIC.keyboard.getCtrlDown()
    return ctrlDown
  end
  function _G._PUBLIC.keyboard.getAltDown()
    return altDown
  end
  function _G._PUBLIC.keyboard.getShiftDown()
    return shiftDown
  end

  _, process = _PUBLIC.tsched.addTask(function()
    while true do
      -- check for events
      local args
      repeat
        args = { computer.uptime(), computer.pullSignal(0) }
        if args and args[2] then
          for pid in pairs(evmgr.eventQueue) do
            table.insert(evmgr.eventQueue[pid], args)
          end
          if _PUBLIC.keyboard then
            if args[2] == "key_down" then
              local keycode = args[5]
              local key = _PUBLIC.keyboard.keys[keycode]
              if key == "lcontrol" then
                ctrlDown = true
              elseif key == "lmenu" then
                altDown = true
              elseif key == "lshift" then
                shiftDown = true
              elseif key == "c" and ctrlDown and altDown then
                if print then
                  print("\n\27[91mCoroutine " .. tostring(#tsched.tasks) .. " killed.")
                end
                table.remove(tsched.tasks, #tsched.tasks)
              end
            elseif args[2] == "key_up" then
              local keycode = args[5]
              local key = _PUBLIC.keyboard.keys[keycode]
              if key == "lcontrol" then
                ctrlDown = false
              elseif key == "lmenu" then
                altDown = false
              elseif key == "lshift" then
                shiftDown = true
              end
            end
          end
          for pid in pairs(evmgr.eventQueue) do
            while #evmgr.eventQueue[pid] > maxEventQueueLength do
              --ocelot.log("Queue length breach, removing first signal")
              table.remove(evmgr.eventQueue[pid], 1)
            end
          end
        end
      until not args or not args[1]
      -- TODO: check for processes that have ended
      -- run other tasks
      coroutine.yield()
    end
  end, "evmgr")
end

function module.exit()
  _G.evmgr = nil
  _PUBLIC.tsched.removeTask(process.id)
end

return module

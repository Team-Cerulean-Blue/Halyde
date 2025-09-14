_G.evmgr = {}
_G.evmgr.eventQueue = {}
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

--local ocelot = component.proxy(component.list("ocelot")())

while true do
  local args
  repeat
    args = {computer.uptime(), computer.pullSignal(0)}
    if args and args[2] then
      table.insert(evmgr.eventQueue, args)
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
              print("\n\27[91mCoroutine "..tostring(#tsched.tasks).." killed.")
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
      while #evmgr.eventQueue > maxEventQueueLength do
        --ocelot.log("Queue length breach, removing first signal")
        table.remove(evmgr.eventQueue, 1)
      end
    end
  until not args or not args[1]
  --ocelot.log("done")
  coroutine.yield()
end

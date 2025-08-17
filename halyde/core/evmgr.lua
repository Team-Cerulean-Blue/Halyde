_G.evmgr = {}
_G.evmgr.eventQueue = {}
local maxEventQueueLength = 10 -- increase if events start getting dropped

local computer = import("computer")

keyboard.ctrlDown = false
keyboard.altDown = false
keyboard.shiftDown = false

--local ocelot = component.proxy(component.list("ocelot")())

while true do
  local args
  repeat
    args = {computer.uptime(), computer.pullSignal(0)}
    if args and args[2] then
      table.insert(evmgr.eventQueue, args)
      if keyboard then
        if args[2] == "key_down" then
          local keycode = args[5]
          local key = keyboard.keys[keycode]
          if key == "lcontrol" then
            keyboard.ctrlDown = true
          elseif key == "lmenu" then
            keyboard.altDown = true
          elseif key == "lshift" then
            keyboard.shiftDown = true
          elseif key == "c" and keyboard.ctrlDown and keyboard.altDown then
            if print then
              print("\n\27[91mCoroutine "..tostring(#cormgr.corList).." killed.")
            end
            cormgr.corList[#cormgr.corList] = nil
          end
        elseif args[2] == "key_up" then
          local keycode = args[5]
          local key = keyboard.keys[keycode]
          if key == "lcontrol" then
            keyboard.ctrlDown = false
          elseif key == "lmenu" then
            keyboard.altDown = false
          elseif key == "lshift" then
            keyboard.shiftDown = true
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

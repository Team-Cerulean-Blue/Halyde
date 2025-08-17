local fs = import("filesystem")
local json = import("json")
local handle, data, tmpdata = fs.open("/halyde/config/shell.json", "r"), "", nil
repeat
  tmpdata = handle:read(math.huge)
  data = data .. (tmpdata or "")
until not tmpdata
handle:close()
local shellcfg = json.decode(data)
import("/halyde/core/termlib.lua")
local event = import("event")
local component = import("component")
local gpu = component.gpu

_G.shell = {}
_G.shell.workingDirectory = shellcfg["defaultWorkingDirectory"]
_G.shell.aliases = shellcfg["aliases"]

local function runAsCoroutine(path, ...)
  --ocelot.log("running " .. path .. " as coroutine")
  cormgr.loadCoroutine(path, ...)
  local corIndex = #cormgr.corList
  local cor = cormgr.corList[#cormgr.corList]
  repeat
    coroutine.yield()
  until cormgr.corList[corIndex] ~= cor
end

function _G.shell.run(command)
  checkArg(1, command, "string")
  if shell.aliases[command:match("[^ ]+")] then
    local _, cmdend = command:find("[^ ]+")
    command = shell.aliases[command:match("[^ ]+")] .. command:sub(cmdend + 1)
  end
  local gm, result, args, trimmedCommand = command:gmatch("[^ ]+"), nil, {}, command
  while true do
    result = gm()
    if not result then
      break
    end
    if result:find('"') then
      local location = trimmedCommand:find('"')
      local argBefore = result:sub(1, result:find('"') - 1) -- edge case where there is no space before the quote, get the argument there
      if argBefore and argBefore ~= "" then
        table.insert(args, argBefore)
      end
      trimmedCommand = trimmedCommand:sub(location + 1)
      if trimmedCommand:find('"') then
        table.insert(args, trimmedCommand:sub(1, trimmedCommand:find('"') - 1))
        trimmedCommand = trimmedCommand:sub(trimmedCommand:find('"') + 1)
        gm = trimmedCommand:gmatch('[^ ]+')
      else
        print("\27[91mmalformed shell command")
        return
      end
    else
      table.insert(args, result)
    end
  end
  -- execute the program
  local PATH = table.copy(shellcfg.path)
  table.insert(PATH, shell.workingDirectory)
  if not args[1] then
    return
  end
  if fs.exists(args[1]) and not fs.isDirectory(args[1]) then
    local path = args[1]
    table.remove(args, 1)
    runAsCoroutine(path, table.unpack(args))
    return
  end
  for _, item in pairs(PATH) do
    if fs.exists(item..args[1]) and not fs.isDirectory(item .. args[1]) then
      local path = fs.concat(item, args[1])
      table.remove(args, 1)
      runAsCoroutine(path, table.unpack(args))
      return
    else -- try to look for it without the file extension
      local files = fs.list(item) or {}
      for _, file in pairs(files) do
        -- previous pattern: (.+)%.[^%.]+$
        if args[1] == file:match("(.+)%.[^%.]+$") and not fs.isDirectory(item .. file) then
          table.remove(args, 1)
          runAsCoroutine(item .. file, table.unpack(args))
          return
        end
      end
    end
  end
  print("No such file or command: "..args[1])
end

print(shellcfg["startupMessage"]:format(_OSVERSION, shellcfg.splashMessages[math.random(1, #shellcfg.splashMessages)]))
while true do
  coroutine.yield()
  -- print(shell.workingDirectory .. " >")
  --print(shellcfg["prompt"]:format(shell.workingDirectory),false)
  -- termlib.cursorPosX = #(shell.workingDirectory .. " >  ")
  -- termlib.cursorPosY = termlib.cursorPosY - 1
  if shell.workingDirectory:sub(-1, -1) ~= "/" then
    shell.workingDirectory = shell.workingDirectory .. "/"
  end
  local shellCommand = read("shell", shellcfg.prompt:format(shell.workingDirectory))
  shell.run(shellCommand)
  gpu.freeAllBuffers()
end

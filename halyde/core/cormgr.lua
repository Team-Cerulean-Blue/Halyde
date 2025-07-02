_G.cormgr = {}
_G.cormgr.corList = {}
_G.cormgr.labelList = {}

local component = import("component")
local filesystem = import("filesystem")
local json = import("json")
local gpu = component.gpu
--local ocelot = component.ocelot

function _G.cormgr.loadCoroutine(path,...)
  local args = {...}
  local function corFunction()
    local result, errorMessage = xpcall(function(...)
      import(...)
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
    --import(path, table.unpack(args))
  end
  cormgr.addCoroutine(corFunction, string.match(tostring(path), "([^/]+)%.lua$"))
end

function _G.cormgr.addCoroutine(func, name)
  local cor = coroutine.create(func)
  table.insert(cormgr.corList, cor)
  table.insert(cormgr.labelList, name)
  return cor
end

function _G.cormgr.removeCoroutine(name)
  local index = table.find(cormgr.labelList, cor)
  table.remove(cormgr.corList, index)
  table.remove(cormgr.labelList, index)
  --coroutine.close(cor)
end

function handleError(errormsg)
  if errormsg == nil then
    error("unknown error")
  else
    error(tostring(errormsg).."\n \n"..debug.traceback())
  end
end

local function runCoroutines()
  for i = 1, #_G.cormgr.corList do
    if cormgr.corList[i] then
      local result, errorMessage = coroutine.resume(cormgr.corList[i])
      if cormgr.corList[i] then
        if not result then
          handleError(errorMessage)
        end
        if coroutine.status(cormgr.corList[i]) == "dead" then
          table.remove(cormgr.corList, i)
          table.remove(cormgr.labelList, i)
          --ocelot.log("Removed coroutine")
          i = i - 1
        end
        --computer.pullSignal(0)
        --coroutine.yield()
      end
    end
  end
end

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
    _G.cormgr.loadCoroutine(line)
    runCoroutines()
  end
end
-- _G.cormgr.loadCoroutine("/halyde/core/shell.lua")

while true do
  runCoroutines()
  if #_G.cormgr.corList == 0 then
    computer.shutdown()
  end
end

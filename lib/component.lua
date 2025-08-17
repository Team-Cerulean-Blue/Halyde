local compLib
local LLcomponent
if table.copy then
  compLib = table.copy(component)
  LLcomponent = table.copy(component)
else
  compLib = {}
  LLcomponent = component
end

--local ocelot = LLcomponent.proxy(LLcomponent.list("ocelot")())
--ocelot.log("loaded")

_G.componentlib = {["additions"] = {}, ["removals"] = {}}
compLib.virtual = {}

function compLib.virtual.add(address, componentType, proxy)
  checkArg(1, address, "string")
  checkArg(2, componentType, "string")
  checkArg(3, proxy, "table")
  proxy["address"] = address
  componentlib.additions[address] = {["componentType"] = componentType, ["proxy"] = proxy}
  if componentlib.removals[address] then
    componentlib.removals[address] = nil
  end
end

function compLib.virtual.remove(address)
  checkArg(1, address, "string")
  if componentlib.additions[address] then
    componentlib.additions[address] = nil
  else
    table.insert(componentlib.removals, address)
  end
end

function compLib.list(componentType)
  checkArg(1, componentType, "string", "nil")
  local componentList = table.copy(LLcomponent.list(componentType))
  for address, dataTable in pairs(componentlib.additions) do
    if dataTable.componentType == componentType or not componentType then
      componentList[address] = dataTable.componentType
    end
  end
  for _, address in pairs(componentlib.removals) do
    componentList[address] = nil
  end
  local i, value
  setmetatable(componentList, {__call = function(self)
    i, value = next(self, i)
    return i, value
  end})
  return componentList
end

function compLib.proxy(address)
  if componentlib.additions[address] then
    --ocelot.log("vcomponent")
    return componentlib.additions[address].proxy
  else
    return LLcomponent.proxy(address)
  end
end

function compLib.invoke(address, funcName, ...)
  --ocelot.log("Invoking " .. funcName .. " from " .. address)
  if componentlib.additions[address] then
    --ocelot.log("vcomponent")
    return componentlib.additions[address].proxy[funcName](...)
  else
    return LLcomponent.invoke(address, funcName, ...)
  end
end

function compLib.get(address)
  checkArg(1, address, "string")
  if #address < 3 then
    return nil, "abbreviated address must be at least 3 characters long"
  end
  for currentAddress, name in compLib.list() do
    if currentAddress:find("^" .. address) then
      return(currentAddress)
    end
  end
  return nil, "full address not found"
end

-- Add main component proxies to the library
setmetatable(compLib, {["__index"] = function(_, item)
  if compLib.list(item)() then
    return compLib.proxy(compLib.list(item)())
  else
    return compLib[item]
  end
end})

return compLib

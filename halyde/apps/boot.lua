local component = import("component")
local computer = import("computer")
local args = {...}

local force = false

local forceArgIdx = table.find(args,"-f") or table.find(args,"--force")
if forceArgIdx then
  table.remove(args,forceArgIdx)
  force = true
end

local function getComponentID(str)
  local function fromSlot(slot)
    for i,v in component.list() do
      if component.slot(i)==slot then
        return i
      end
    end
  end
  if str=="hdd1"   or str=="#1" then return fromSlot(5) end
  if str=="hdd2"   or str=="#2" then return fromSlot(6) end
  if str=="floppy" or str=="#3" then return fromSlot(7) end

  if #str<3 then return nil,"Abbreviated ID must atleast have 3 characters" end
  return component.get(str)
end

local function fileExists(compID,file)
  return component.invoke(compID,"exists",file) and not component.invoke(compID,"isDirectory",file)
end

if type(args[1])=="string" then
  local compID,err = getComponentID(args[1])
  if not compID then
    print("\x1b[91mCould not get component ID from '"..args[1].."'.")
    if type(err)=="string" then print("\x1b[91m"..err) end
    return
  end
  if not force then
    if componentlib.additions[compID] then
      return print("\x1b[91mThis component is virtual and cannot be booted from directly.\nID: "..compID)
    end
    local type = component.type(compID)
    if type~="filesystem" and type~="drive" then
      return print("\x1b[91mThis component is not a storage medium.\nID: "..compID)
    end
    if type=="filesystem" and not fileExists(compID,"/init.lua") then
      return print("\x1b[91mThis storage medium doesn't have an \"init.lua\" file.\nID: "..compID)
    end
  end

  computer.setBootAddress(compID)
  if computer.getBootAddress()~=compID then
    return print("\x1b[91mFailed to set the boot address.")
  end
  computer.shutdown(true)
else
  shell.run("help boot")
end

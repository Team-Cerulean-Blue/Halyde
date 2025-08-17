local component = require("component")
local computer = require("computer")
local args = {...}
if not args then return print("\x1b[91mCannot get arguments.") end
if not args[1] then
  return shell.run("help label")
end
local inputID = args[1]
local comp

local function componentFromSlot(slotNum)
  if slotNum>=5 and slotNum<=8 then slotNum=slotNum-1 end
  for i,v in component.list() do
    if component.slot(i)==slotNum then
      comp=component.proxy(i)
    end
  end
end

if inputID=="eeprom" then
  comp = component.eeprom
elseif inputID=="halyde" then
  comp = component.proxy(computer.getBootAddress())
elseif inputID:sub(1,4)=="slot" and tonumber(inputID:sub(5)) then
  local slotNum = tonumber(inputID:sub(5))-1
  componentFromSlot(slotNum)
elseif inputID:sub(1,1)=="#" and tonumber(inputID:sub(2)) then
  local slotNum = tonumber(inputID:sub(2))+5
  componentFromSlot(slotNum)
elseif #inputID>=3 then
  local fullID = component.get(inputID)
  if not fullID then return print("\x1b[91mCould not find entire component ID from \""..inputID.."\".") end
  comp = component.proxy(fullID)
else
  print("\x1b[91mAddress must have atleast 3 characters")
  return shell.run("help label")
end
if not comp then
  return print("\x1b[91mCould not find component from \""..inputID.."\".")
end
local compID = comp.address

local function formatID(id)
  return id:sub(1,8).."\x1b[37m"..id:sub(9).."\x1b[39m"
end

local function unsupported(act)
  print("This \x1b[92m"..(comp.type or "unknown").."\x1b[39m component doesn't support "..act.." labels.\nID: "..formatID(compID))
end

local function compError(act,reason)
  print("\x1b[91mAn error occured while "..act.." the label of this component.\nComponent: "..(compID or "unknown id").." ("..((comp or {}).type or "unknown type")..")\n\n"..reason)
end

local function formatLabel(label)
  local res = "No label defined"
  if label then res="\""..label.."\"" end
  return res
end

if type(args[2])~="string" then
  if not comp.getLabel then
    return unsupported("getting")
  end
  local label
  local success,reason = pcall(function()
    label = comp.getLabel()
  end)
  if success then
    print("Label of "..formatID(compID)..((comp.type and comp.type~="filesystem") and " ("..comp.type..")" or "")..":\n  \x1b[92m"..formatLabel(label).."\x1b[39m")
  else
    compError("getting",reason)
  end
else
  if not comp.setLabel then
    return unsupported("setting")
  end
  local newLabel = ""
  for i=2,#args do
    newLabel=newLabel..tostring(args[i])
    if i<#args then newLabel=newLabel.." " end
  end
  local label
  local success,reason = pcall(function()
    label = comp.setLabel(newLabel)
  end)
  if success then
    print("Successfully set label of "..formatID(compID)..(comp.type and " ("..comp.type..")" or "").." to:\n  \x1b[92m"..formatLabel(label).."\x1b[39m")
  else
    compError("setting",reason)
  end
end

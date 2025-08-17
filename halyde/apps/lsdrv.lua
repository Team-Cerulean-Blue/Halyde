local serialize = require("serialize")
local component = require("component")
local computer = require("computer")
local unicode = require("unicode")

local width,height = component.gpu.getResolution()

local args = {...}
local showAll = not not (table.find(args,"-a") or table.find(args,"--all"))

local tablePos = {}
local tableOut = {}
local headers = {
  ["slot"]="SLOT",
  ["capacity"]="CAPACITY",
  ["managed"]="MANAGED",
  ["readOnly"]="READ-ONLY",
  ["id"]="FULL COMPONENT ID",
  ["mount"]="MOUNT",
  ["bootable"]="BOOTABLE",
  ["label"]="LABEL"
}
local headerAlign = {
  ["slot"]=false,
  ["capacity"]=true,
  ["managed"]=false,
  ["readOnly"]=false,
  ["id"]=false,
  ["mount"]=false,
  ["bootable"]=false,
  ["label"]=false
}
local function addHeader(id)
  table.insert(tableOut,{headerAlign[id],headers[id]})
  tablePos[id]=#tableOut
end
for i,v in pairs(tablePos) do print(i,v) end

local function everyHeader()
  addHeader("slot")
  addHeader("capacity")
  addHeader("managed")
  addHeader("readOnly")
  addHeader("id")
  addHeader("mount")
  addHeader("bootable")
  addHeader("label")
end

local function defaultHeaders()
  if width>100 then addHeader("slot") end
  addHeader("capacity")
  if width>80 then addHeader("id") end
  addHeader("mount")
  addHeader("label")
end

local function invalidArgSyntax(err)
  print(err)
  return shell.run("help lsdrv")
end

local outArgIdx = table.find(args,"-o") or table.find(args,"--output")
if showAll then
  everyHeader()
elseif outArgIdx then
  table.remove(args,outArgIdx)
  local arg = table.remove(args,outArgIdx)
  if not arg then return invalidArgSyntax("Argument -o must have a value") end
  if arg=="all" then
    everyHeader()
  else
    if arg:sub(1,1)=="+" then
      defaultHeaders()
    end
    for word in string.gmatch(arg:sub(2),"([^,]+)") do
      if headers[word] then
        addHeader(word)
      else
        print("\x1b[93mCategory \""..word.."\" doesn't exist\x1b[39m")
      end
    end
  end
else
  defaultHeaders()
end

local function headerUsed(id)
  return not not tablePos[id]
end

local bibytes = not (table.find(args,"-H") or table.find(args,"--si"))
local function formatSize(mem)
  local units = bibytes and {"B","KiB","MiB","GiB"} or {"B","KB","MB","GB"}
  local unit = 1
  local unitStep = bibytes and 1024 or 1000
  while mem > unitStep and units[unit] do
    unit = unit + 1
    mem = mem/unitStep
  end
  local memStr = tostring(mem):sub(1,5)
  if unicode.sub(memStr,-2)==".0" then
    memStr=unicode.sub(memStr,1,-3)
  end
  return memStr.." "..units[unit]
end

local function fileExists(proxy,path)
  return proxy.exists(path) and not proxy.isDirectory(path)
end

local function getBootCode(proxy)
  local sector1 = proxy.readSector(1)
  for i = 1,#sector1 do
    if sector1:sub(i,i)=="\0" then
      sector1 = sector1:sub(1,i-1)
      break
    end
  end
  return sector1
end

local function isBootable(proxy,type)
  if type=="drive" then
    return not not load(getBootCode(proxy))
  elseif type=="filesystem" then
    return not not (fileExists(proxy,"/init.lua") or fileExists(proxy,"/OS.lua"))
  end
end

local function formatBoolean(bool)
  return ({[true]="Yes",[false]="No"})[bool]
end

local function handleComponent(id,type)
  if not id then return end
  local proxy = component.proxy(id)
  if not proxy then return end
  -- local out = {}
  -- for i=1,#tableOut do table.insert(out,"unknown") end
  local slot,capacity,managed,readOnly,mount,bootable,label

  local cslot = component.slot(id)
  if cslot==-1 then
    slot="Virtual"
  elseif cslot==9 then
    slot="EEPROM"
  else
    slot="#"..(cslot+2)
  end

  managed="Yes"
  readOnly="No"
  if type=="drive" then
    managed="No"
    capacity=formatSize(proxy.getCapacity())
    mount="/special/drive/"..id:sub(1,3)
  elseif type=="filesystem" then
    capacity=formatSize(proxy.spaceTotal())
    if proxy.isReadOnly() then
      readOnly="Yes"
    end
    mount="/mnt/"..id:sub(1,3)
    if computer.getBootAddress()==id then mount="/" end
    if computer.tmpAddress()==id then
      mount="/tmp"
      slot="Temporary"
    end
  elseif type=="eeprom" then
    capacity=formatSize(proxy.getSize()+proxy.getDataSize())
    mount="/special/eeprom/"
  end

  if headerUsed("bootable") then
    bootable = formatBoolean(isBootable(proxy,type))
  end

  if proxy.getLabel then
    local clabel = proxy.getLabel()
    label=clabel and serialize.string(clabel) or "None"
  else
    label="Unsupported"
  end

  local function insertElement(i,v)
    if not tablePos[i] then return end
    table.insert(tableOut[tablePos[i]],v or "unknown")
  end
  insertElement("slot",slot)
  insertElement("capacity",capacity)
  insertElement("managed",managed)
  insertElement("readOnly",readOnly)
  insertElement("id",id)
  insertElement("mount",mount)
  insertElement("bootable",bootable)
  insertElement("label",label)
end

local function filter(tbl,test)
  local i=1
  while i<=#tbl do
    if not test(tbl[i]) then
      table.remove(tbl,i)
      i=i-1
    end
    i=i+1
  end
end

local function luaExpr(arg)
  local func,err = load("local component,computer,type,id,readonly,capacity=... local managed,eeprom,halyde,tmp,proxy,slot,all=type==\"drive\",type==\"eeprom\",id==\""..computer.getBootAddress().."\",id==\""..computer.tmpAddress().."\",component.proxy(id),component.slot(id)+2,true return "..arg)
  if func then
    return function(comp)
      local readOnly,capacity=false,nil
      if comp[2]=="filesystem" then
        readOnly=component.invoke(comp[1],"isReadOnly")
        capacity=component.invoke(comp[1],"spaceTotal")
      elseif comp[2]=="drive" then
        capacity=component.invoke(comp[1],"getCapacity")
      elseif comp[2]=="eeprom" then
        capacity=component.invoke(comp[1],"getSize")+component.invoke(comp[1],"getDataSize")
      end
      return func(component,computer,comp[2],comp[1],readOnly,capacity)
    end
  else
    return nil,err
  end
end

local function boolToNum(val)
  if type(val)=="boolean" then
    if val then
      return 1
    else
      return 0
    end
  end
  return val
end

local comps = {}
for i,v in component.list("filesystem") do table.insert(comps,{i,v}) end
for i,v in component.list("drive") do table.insert(comps,{i,v}) end
for i,v in component.list("eeprom") do table.insert(comps,{i,v}) end

if not showAll then
  local showArgIdx = table.find(args,"-s") or table.find(args,"--show")
  if showArgIdx then
    table.remove(args,showArgIdx)
    local arg = table.remove(args,showArgIdx)
    if not arg then return invalidArgSyntax("Argument -s must have a value") end
    local func,err = luaExpr(arg)
    if func then
      filter(comps,func)
    else
      return print("\x1b[91mInvalid component filter:\n\n"..tostring(err).."\x1b[39m")
    end
  else
    filter(comps,function(comp)
      return comp[2]~="eeprom" and comp[1]~=computer.tmpAddress()
    end)
  end
end

local sortArgIdx = table.find(args,"-S") or table.find(args,"--sort")
if sortArgIdx then
  table.remove(args,sortArgIdx)
  local arg = table.remove(args,sortArgIdx)
  if not arg then return invalidArgSyntax("Argument -S must have a value") end
  local func,err = luaExpr(arg)
  if func then
    table.sort(comps,function(a,b)
      return (boolToNum(func(a)) or 0)<(boolToNum(func(b)) or 0)
    end)
  else
    return print("\x1b[91mInvalid sort expression:\n\n"..tostring(err).."\x1b[39m")
  end
else
  table.sort(comps,function(a,b)
    return a[1]<b[1]
  end)
end

if #comps>0 then
  for i,v in ipairs(comps) do handleComponent(v[1],v[2]) end
else
  return print("Could not find storage components for this filter.")
end

local function renderTableOutput()
  local lines = {}
  for i=1,#tableOut[1]-1 do
    table.insert(lines,"")
  end

  for i=1,#tableOut do
    local length = 1
    for j=1,#lines do
      tableOut[i][j+1]=tableOut[i][j+1] or "[nil]"
      length = math.max(length,unicode.wlen(tableOut[i][j+1]))
    end
    for j=1,#lines do
      if tableOut[i][1] then
        lines[j]=lines[j]..string.rep(" ",length-unicode.wlen(tableOut[i][j+1]))..tableOut[i][j+1]
      elseif i<#tableOut then
        lines[j]=lines[j]..tableOut[i][j+1]..string.rep(" ",length-unicode.wlen(tableOut[i][j+1]))
      else
        lines[j]=lines[j]..tableOut[i][j+1]
      end
      if i<#tableOut then lines[j]=lines[j].." " end
    end
  end

  print(lines[1].."\n")
  for i=2,#lines do
    print(lines[i])
  end
end

renderTableOutput()

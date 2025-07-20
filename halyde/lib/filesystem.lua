local loadfile = ... -- raw loadfile from boot.lua
local component, computer

if loadfile then
  unicode = loadfile("/halyde/lib/unicode.lua")(loadfile)
  component = loadfile("/halyde/lib/component.lua")(loadfile)
  computer = _G.computer
elseif import then
  unicode = import("unicode")
  component = import("component")
  computer = import("computer")
end

local filesystem = {}

function filesystem.canonical(path)
  checkArg(1, path, "string")
  local segList = {}
  if path:sub(1, 1) ~= "/" then
    path = "/" .. path
  end
  path = path:gsub("/+", "/")
  for segment in path:gmatch("[^/]+") do
    if segment == ".." and segList[1] then
      table.remove(segList, #segList)
    elseif segment ~= "." then
      table.insert(segList, segment)
    end
  end
  return "/" .. table.concat(segList, "/")
end

function filesystem.concat(path1, path2)
  checkArg(1, path1, "string")
  checkArg(2, path2, "string")
  if path1:sub(-1, -1) == "/" then
    path1 = path1:sub(1, -2)
  end
  if path2:sub(1, 1) ~= "/" then
    path2 = "/" .. path2
  end
  return path1 .. path2
end

function filesystem.absolutePath(path) -- returns the address and absolute path of an object
  checkArg(1, path, "string")
  path = filesystem.canonical(path)
  local address = nil
  if path:find("^/tmp") then
    address = computer.tmpAddress()
    path = path:sub(5)
  elseif path:find("^/mnt/...") then
     address = component.get(path:sub(6,8))
    if not address then
      address = computer.getBootAddress()
    else
      path = path:sub(9)
    end
  else
    address = computer.getBootAddress()
  end
  if not address then
    return nil, "no such component"
  end
  return address, path
end

function filesystem.exists(path) -- check if path exists
  checkArg(1, path, "string")
  local address, absPath = filesystem.absolutePath(path)
  if not address then
    return false
  end
  if absPath:find("^/special/drive/...") then
    return not not (computer.getBootAddress() and component.get(absPath:sub(16,18)))
  end
  if absPath:find("^/special/eeprom/") then
    return table.find({"init.lua","data.bin","label.txt"},absPath:sub(17))
  end
  return component.invoke(address, "exists", absPath)
end

local function readBytes(self,n)
  n = n or 1
  if n==1 then
    local byte = self:read(1)
    if byte==nil then return nil end
    return string.byte(byte)
  end
  local bytes, res = {string.byte(self:read(n),1,n)}, 0
  if self.littleEndian then
    for i=#bytes,1,-1 do
      res = (res<<8)&0xFFFFFFFF | bytes[i]
    end
  else
    for i=1,#bytes do
      res = (res<<8)&0xFFFFFFFF | bytes[i]
    end
  end
  return res
end

local function readUnicodeChar(self)
  return unicode.readChar(function()
    return self:readBytes(1)
  end)
end

local function iterateBytes(self)
  return function()
    local byte = readBytes(self,1)
    if byte==nil then self:close() end
    return byte
  end
end

local function iterateUnicodeChars(self)
  return unicode.iterate(iterateBytes(self))
end

function filesystem.makeReadStream(content)
  local properHandle = {}
  local readcursor = 1
  function properHandle.read(self, amount)
    checkArg(2, amount, "number")
    local limit = string.len(content)+1
    local out = nil
    if readcursor<limit then
      if amount==math.huge then
        out = string.sub(content,math.min(readcursor,limit))
      else
        out = string.sub(content,math.min(readcursor,limit),math.min(readcursor+amount-1,limit))
      end
    end
    readcursor=readcursor+amount
    if out=="" then
      return nil
    end
    return out
  end
  properHandle.readBytes = readBytes
  properHandle.readUnicodeChar = readUnicodeChar
  properHandle.iterateBytes = iterateBytes
  properHandle.iterateUnicodeChars = iterateUnicodeChars
  function properHandle.write()
    return nil
  end
  function properHandle.close()
    content=nil
  end
  return properHandle
end

function filesystem.open(path, mode, buffered) -- opens a file and returns its handle
  checkArg(1, path, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, buffered, "boolean", "nil")
  if not mode then
    mode = "r"
  end
  if buffered == nil then
    buffered = true
  end
  if not (mode == "r" or mode == "w" or mode == "rb" or mode == "wb" or mode == "a" or mode == "ab") then
    return nil, "invalid handle type"
  end
  if path:find("^/special") and not filesystem.exists(path) then
    return nil, "/special does not allow creating files"
  end
  local address, absPath = filesystem.absolutePath(path)
  local unmanagedDrive = address==computer.getBootAddress() and absPath:find("^/special/drive")
  local unmanagedProxy, sectorSize, sectorCount, handle
  if unmanagedDrive then
    unmanagedProxy = component.proxy(component.get(absPath:sub(16,18)))
    sectorSize = unmanagedProxy.getSectorSize()
    sectorCount = math.ceil(unmanagedProxy.getCapacity()/sectorSize)
  elseif not (address==computer.getBootAddress() and absPath:find("^/special/")) then
    local handleArgs = {component.invoke(address, "open", absPath, mode)}
    handle = handleArgs[1]
    if not handle then
      return table.unpack(handleArgs)
    end
    handleArgs = nil
  end
  local properHandle = {}
  properHandle.handle = handle
  properHandle.address = address
  local content = nil
  local readcursor = 1
  if buffered and mode:sub(1,1)=="r" then
    content=""
    repeat
      tmpdata = component.invoke(address, "read", handle, math.huge or math.maxinteger)
      content = content .. (tmpdata or "")
    until not tmpdata
    component.invoke(address, "close", handle)
  end
  function properHandle.read(self, amount)
    checkArg(2, amount, "number")
    if unmanagedDrive then
      local sectorIdx = ((readcursor-1)//sectorSize)+1
      if sectorIdx>sectorCount then return nil end
      local sector = unmanagedProxy.readSector(sectorIdx)
      local data = sector:sub(((readcursor-1)%sectorSize)+1,((readcursor+math.min(amount,sectorSize)-2)%sectorSize)+1)
      readcursor=readcursor+#data
      if data=="" then return nil end
      return data
    else
      if buffered then
        local limit = string.len(content)+1
        local out = nil
        if readcursor<limit then
          if amount==math.huge then
            out = string.sub(content,math.min(readcursor,limit))
          else
            out = string.sub(content,math.min(readcursor,limit),math.min(readcursor+amount-1,limit))
          end
        end
        readcursor=readcursor+amount
        if out=="" then
          return nil
        end
        return out
      else
        return component.invoke(self.address, "read", self.handle, amount)
      end
    end
  end
  properHandle.readBytes = readBytes
  properHandle.readUnicodeChar = readUnicodeChar
  properHandle.iterateBytes = iterateBytes
  properHandle.iterateUnicodeChars = iterateUnicodeChars
  function properHandle.write(self, data)
    checkArg(2, data, "string")
    if unmanagedDrive then
      local startSector = ((readcursor-1)//sectorSize)+1
      if startSector>sectorCount then return nil, "not enough space" end
      local startSByte = ((readcursor-1)%sectorSize)+1
      local sect = unmanagedProxy.readSector(startSector)
      unmanagedProxy.writeSector(startSector,sect:sub(1,startSByte-1)..data:sub(1,sectorSize-startSByte+1))
      for i=2,(#data+startSByte)//sectorSize do
        if startSector+i-1>sectorCount then return nil, "not enough space" end
        unmanagedProxy.writeSector(startSector+i-1,data:sub(startSByte+sectorSize*(i-1),startSByte+sectorSize*i-1))
      end
      readcursor=readcursor+#data
      return true
    else
      return component.invoke(self.address, "write", self.handle, data)
    end
  end
  function properHandle.close(self)
    if buffered then
      content = nil
    else
      return component.invoke(self.address, "close", self.handle)
    end
  end
  if address==computer.getBootAddress() then
    local eeprom
    pcall(function()
      eeprom = component.eeprom
    end)
    if eeprom then
      local getFunc, setFunc
      if absPath=="/special/eeprom/init.lua" then
        getFunc,setFunc = "get","set"
      elseif absPath=="/special/eeprom/data.bin" then
        getFunc,setFunc = "getData","setData"
      elseif absPath=="/special/eeprom/label.txt" then
        getFunc,setFunc = "getLabel","setLabel"
      end
      if mode:sub(1,1)=="r" and getFunc then
        local stream = filesystem.makeReadStream(eeprom[getFunc]() or "")
        properHandle.read = stream.read
        properHandle.close = stream.close
      elseif mode:sub(1,1)=="w" and setFunc then
        local content = ""
        function properHandle.write(self, data)
          checkArg(2, data, "string")
          content=content..data
        end
        function properHandle.close(self)
          return eeprom[setFunc](content)
        end
      end
    end
  end
  return properHandle
end

function filesystem.list(path)
  checkArg(1, path, "string")
  path = filesystem.canonical(path)
  if path == "/mnt" then
    -- list drives
    local returnTable = {}
    local tmpAddress = computer.tmpAddress()
    for address, _ in component.list("filesystem") do
      if address~=tmpAddress then
        table.insert(returnTable, address:sub(1, 3) .. "/")
      end
    end
    return returnTable
  elseif path == "/special/drive" then
    local returnTable = {}
    local tmpAddress = computer.tmpAddress()
    for address, _ in component.list("drive") do
      if address~=tmpAddress then
        table.insert(returnTable, address:sub(1, 3))
      end
    end
    return returnTable
  elseif path=="/special/eeprom" then
    return {"init.lua","data.bin","label.txt"}
  else
    local address, absPath = filesystem.absolutePath(path)
    if not address then
      return false
    end
    return component.invoke(address, "list", absPath)
  end
end

function filesystem.size(path)
  checkArg(1, path, "string")
  local address, absPath = filesystem.absolutePath(path)
  if not address then
    return false
  end
  if address==computer.getBootAddress() then
    if absPath:find("^/special/drive") then
      local drive = component.get(absPath:sub(16,18))
      if not drive then return false end
      return component.invoke(drive,"getCapacity")
    elseif absPath:find("^/special/eeprom") then
      local eeprom
      pcall(function()
        eeprom = component.eeprom
      end)
      if eeprom then
        local getFunc
        if absPath=="/special/eeprom/init.lua" then
          getFunc = "get"
        elseif absPath=="/special/eeprom/data.bin" then
          getFunc = "getData"
        elseif absPath=="/special/eeprom/label.txt" then
          getFunc = "getLabel"
        end
        return #(eeprom[getFunc]())
      end
    end
  end
  return component.invoke(address, "size", absPath)
end

local function getRecursiveList(address,absPath)
  local list = component.invoke(address,"list",absPath)
  local dirList = {}
  local listChanged = true
  while listChanged do
    listChanged = false
    for i=1,#list do
      if component.invoke(address, "isDirectory", absPath.."/"..list[i]) then
        listChanged = true
        local dir = list[i]
        if dir:sub(-1)=="/" then dir=dir:sub(1,-2) end
        table.insert(dirList,dir)
        table.remove(list,i)
        local subDir = component.invoke(address,"list",absPath.."/"..dir)
        for j=1,#subDir do table.insert(list,dir.."/"..subDir[j]) end
      end
    end
  end
  return list,dirList
end

local function copyContent(fromHandle,toHandle)
  if not (fromHandle and toHandle) then return end
  local memory = math.floor(computer.freeMemory()*0.8)
  local tmpdata
  while true do
    tmpdata = fromHandle:read(memory)
    if not tmpdata then break end
    local status,reason = toHandle:write(tmpdata)
    if status~=true then break end
  end
  fromHandle:close()
  toHandle:close()
end

local function copyRecursive(fromAddress,fromAbsPath,toAddress,toAbsPath)
  -- TODO: make this use copyContent
  if fromAbsPath:sub(-1)=="/" then fromAbsPath=fromAbsPath:sub(1,-2) end
  if toAbsPath:sub(-1)=="/" then toAbsPath=toAbsPath:sub(1,-2) end
  component.invoke(toAddress,"makeDirectory",toAbsPath)
  local fileList,dirList = getRecursiveList(fromAddress,fromAbsPath)
  for i=1,#dirList do
    component.invoke(toAddress,"makeDirectory",toAbsPath.."/"..dirList[i])
  end
  for i=1,#fileList do
    local fromFile, toFile = fromAbsPath.."/"..fileList[i], toAbsPath.."/"..fileList[i]
    --[[ local handle = component.invoke(fromAddress, "open", fromFile, "r")
    local data, tmpdata = "", nil
    repeat
      tmpdata = component.invoke(fromAddress, "read", handle, math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    tmpdata = component.invoke(fromAddress, "close", handle)
    local handle = component.invoke(toAddress, "open", toFile, "w")
    component.invoke(toAddress, "write", handle, data)
    component.invoke(toAddress, "close", handle) ]]
    local fromHandle = component.invoke(fromAddress, "open", fromFile, "r")
    local toHandle = component.invoke(toAddress, "open", toFile, "w")
    copyContent({
      ["read"]=function(...) return component.invoke(fromAddress, "read", handle, ...) end,
      ["close"]=function(...) return component.invoke(fromAddress, "close", handle, ...) end
    },{
      ["write"]=function(...) return component.invoke(fromAddress, "write", handle, ...) end,
      ["close"]=function(...) return component.invoke(fromAddress, "close", handle, ...) end
    })
  end
end

function filesystem.isDirectory(path)
  checkArg(1, path, "string")
  local address, absPath = filesystem.absolutePath(path)
  if not address then
    return false
  end
  return component.invoke(address, "isDirectory", absPath)
end

function filesystem.rename(fromPath, toPath)
  checkArg(1, fromPath, "string")
  checkArg(2, toPath, "string")
  local fromAddress, fromAbsPath = filesystem.absolutePath(fromPath)
  local toAddress, toAbsPath = filesystem.absolutePath(toPath)
  if not fromAddress or not toAddress then
    return false
  end
  if fromAddress == toAddress then
    return component.invoke(fromAddress, "rename", fromAbsPath, toAbsPath)
  elseif filesystem.isDirectory(fromPath) then -- component.invoke(fromAddress, "isDirectory", fromAbsPath) then
    copyRecursive(fromAddress,fromAbsPath,toAddress,toAbsPath)
    filesystem.remove(fromPath) -- component.invoke(fromAddress,"remove", fromAbsPath)
  else
    local handle, data, tmpdata = filesystem.open(fromPath), "", nil -- component.invoke(fromAddress, "open", fromAbsPath, "r"), "", nil
    repeat
      tmpdata = handle:read(math.huge or math.maxinteger) -- component.invoke(fromAddress, "read", handle, math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    tmpdata = handle:close() -- component.invoke(fromAddress, "close", handle)
    local handle = filesystem.open(toPath) -- component.invoke(toAddress, "open", toAbsPath, "w")
    handle:write(data) -- component.invoke(toAddress, "write", handle, data)
    handle:close() -- component.invoke(toAddress, "close", handle)
    filesystem.remove(fromPath) -- component.invoke(fromAddress, "remove", fromAbsPath)
  end
end

function filesystem.copy(fromPath, toPath)
  checkArg(1, fromPath, "string")
  checkArg(2, toPath, "string")
  local fromAddress, fromAbsPath = filesystem.absolutePath(fromPath)
  local toAddress, toAbsPath = filesystem.absolutePath(toPath)
  if not fromAddress or not toAddress then
    return false
  end
  if filesystem.isDirectory(fromPath) then -- component.invoke(fromAddress, "isDirectory", fromAbsPath)
    copyRecursive(fromAddress,fromAbsPath,toAddress,toAbsPath)
  else
    --[[ local handle = filesystem.open(fromPath,"r")
    local data, tmpdata = "", nil
    repeat
      tmpdata = handle:read(math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    tmpdata = handle:close()
    local handle = filesystem.open(toPath,"w")
    handle:write(data)
    handle:close() ]]
    copyContent(filesystem.open(fromPath,"r"),filesystem.open(toPath,"w"))
  end
end

function filesystem.remove(path)
  checkArg(1, path, "string")
  local address, absPath = filesystem.absolutePath(path)
  if not address then
    return false
  end
  if absPath:find("^/special") then return false end
  if absPath:find("^/tmp") then return false end
  if absPath:find("^/mnt") then return false end
  return component.invoke(address, "remove", absPath)
end

function filesystem.makeDirectory(path)
  checkArg(1, path, "string")
  local address, absPath = filesystem.absolutePath(path)
  if not address then
    return false
  end
  return component.invoke(address, "makeDirectory", absPath)
end

return(filesystem)

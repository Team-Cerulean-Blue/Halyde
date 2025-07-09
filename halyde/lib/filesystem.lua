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
  for i=1,#bytes do
    res = (res<<8)&0xFFFFFFFF | bytes[i]
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

function filesystem.open(path, mode, buffered) -- opens a file and returns its handle
  checkArg(1, path, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, buffered, "boolean", "nil")
  if not mode then
    mode = "r"
  end
  if not buffered then
    buffered = true
  end
  if not (mode == "r" or mode == "w" or mode == "rb" or mode == "wb" or mode == "a" or mode == "ab") then
    return nil, "invalid handle type"
  end
  local address, absPath = filesystem.absolutePath(path)
  local handleArgs = {component.invoke(address, "open", absPath, mode)}
  local handle = handleArgs[1]
  if not handle then
    return table.unpack(handleArgs)
  end
  handleArgs = nil
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
  properHandle.readBytes = readBytes
  properHandle.readUnicodeChar = readUnicodeChar
  properHandle.iterateBytes = iterateBytes
  properHandle.iterateUnicodeChars = iterateUnicodeChars
  function properHandle.write(self, data)
    checkArg(2, data, "string")
    return component.invoke(self.address, "write", self.handle, data)
  end
  function properHandle.close(self)
    if buffered then
      content = nil
    else
      return component.invoke(self.address, "close", self.handle)
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

local function copyRecursive(fromAddress,fromAbsPath,toAddress,toAbsPath)
  if fromAbsPath:sub(-1)=="/" then fromAbsPath=fromAbsPath:sub(1,-2) end
  if toAbsPath:sub(-1)=="/" then toAbsPath=toAbsPath:sub(1,-2) end
  component.invoke(toAddress,"makeDirectory",toAbsPath)
  local fileList,dirList = getRecursiveList(fromAddress,fromAbsPath)
  for i=1,#dirList do
    component.invoke(toAddress,"makeDirectory",toAbsPath.."/"..dirList[i])
  end
  for i=1,#fileList do
    local fromFile, toFile = fromAbsPath.."/"..fileList[i], toAbsPath.."/"..fileList[i]
    local handle = component.invoke(fromAddress, "open", fromFile, "r")
    local data, tmpdata = "", nil
    repeat
      tmpdata = component.invoke(fromAddress, "read", handle, math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    tmpdata = component.invoke(fromAddress, "close", handle)
    local handle = component.invoke(toAddress, "open", toFile, "w")
    component.invoke(toAddress, "write", handle, data)
    component.invoke(toAddress, "close", handle)
  end
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
  elseif component.invoke(fromAddress, "isDirectory", fromAbsPath) then
    copyRecursive(fromAddress,fromAbsPath,toAddress,toAbsPath)
    component.invoke(fromAddress,"remove", fromAbsPath)
  else
    local handle, data, tmpdata = component.invoke(fromAddress, "open", fromAbsPath, "r"), "", nil
    repeat
      tmpdata = component.invoke(fromAddress, "read", handle, math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    tmpdata = component.invoke(fromAddress, "close", handle)
    local handle = component.invoke(toAddress, "open", toAbsPath, "w")
    component.invoke(toAddress, "write", handle, data)
    component.invoke(toAddress, "close", handle)
    component.invoke(fromAddress, "remove", fromAbsPath)
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
  if component.invoke(fromAddress, "isDirectory", fromAbsPath) then
    copyRecursive(fromAddress,fromAbsPath,toAddress,toAbsPath)
  else
    local handle = component.invoke(fromAddress, "open", fromAbsPath, "r")
    local data, tmpdata = "", nil
    repeat
      tmpdata = component.invoke(fromAddress, "read", handle, math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    tmpdata = component.invoke(fromAddress, "close", handle)
    local handle = component.invoke(toAddress, "open", toAbsPath, "w")
    component.invoke(toAddress, "write", handle, data)
    component.invoke(toAddress, "close", handle)
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

function filesystem.remove(path)
  checkArg(1, path, "string")
  local address, absPath = filesystem.absolutePath(path)
  if not address then
    return false
  end
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

return(filesystem)

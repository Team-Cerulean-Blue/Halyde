local loadfile = ... -- raw loadfile from boot.lua
local component, computer

if loadfile then
  component = loadfile("/halyde/lib/component.lua")(loadfile)
  computer = _G.computer
elseif import then
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
  if path:find("^/mnt/...") then
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

local function readUniChar(readByte)
    local function inRange(min,max,...)
        for _,v in ipairs({...}) do
            if not (v and v>=min and v<max) then return false end
        end
        return true
    end
    local function readByte0() return readByte() or 0 end

    local byte = readByte()

    if byte < 0x80 then
        -- ASCII character (0xxxxxxx)
        return byte
    elseif byte < 0xC0 then
        -- Continuation byte (10xxxxxx), invalid at start position
        return nil
    elseif byte < 0xE0 then
        -- 2-byte sequence (110xxxxx 10xxxxxx)
        local byte2 = readByte0()
        if inRange(0x80,0xC0,byte2) then
            local code_point = ((byte & 0x1F) << 6) | (byte2 & 0x3F)
            return code_point
        end
    elseif byte < 0xF0 then
        -- 3-byte sequence (1110xxxx 10xxxxxx 10xxxxxx)
        local byte2, byte3 = readByte0(), readByte0()
        if inRange(0x80,0xC0,byte2,byte3)then
            local code_point = ((byte & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F)
            return code_point
        end
    elseif byte < 0xF8 then
        -- 4-byte sequence (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
        local byte2, byte3, byte4 = readByte0(), readByte0(), readByte0()
        if inRange(0x80,0xC0,byte2,byte3,byte4) then
            local code_point = ((byte & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F)
            return code_point
        end
    end

    -- Invalid UTF-8 byte sequence
    return nil
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
  if not (mode == "r" or mode == "w" or mode == "rb" or mode == "wb") then
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
      -- error("amount "..amount..", limit "..limit)
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
  function properHandle.readBytes(self,n)
    n = n or 1
    if n==1 then return string.byte(self:read(1)) end
    local bytes, res = {string.byte(self:read(n),1,n)}, 0
    for i=1,#bytes do
      res = (res<<8)&0xFFFFFFFF | bytes[i]
    end
    return res
  end
  function properHandle.readUnicodeChar(self)
    return unicode.char(readUniChar(function()
      return self:readBytes(1)
    end))
  end
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
    for address, _ in component.list("filesystem") do
      table.insert(returnTable, address:sub(1, 3) .. "/")
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
  else
    local handle = component.invoke(fromAddress, "open", fromAbsPath, "r")
    local data, tmpdata
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

return(filesystem)

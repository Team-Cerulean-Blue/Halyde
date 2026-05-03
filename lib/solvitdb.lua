local solvitdb = {}

local fs = require("filesystem")

local function checkValidityAndOpen(path)
  local handle = assert(fs.open(path))
  local data = assert(handle:read(8))
  if data:sub(5, 8) == "RTFM" then
    local patLength = string.unpack("<I4", data:sub(1, 4))
    return handle, patLength
  else
    error("missing magic")
  end
end

local function readPat(handle, patLength)
  -- This needs the handle to be at byte 4
  local data, tmpdata = ""
  repeat
    tmpdata = handle:read(patLength - #data)
    data = data .. (tmpdata or "")
  until not tmpdata
  local packages = {}
  for packageData in data:gmatch("(.-%.....);") do
    packages[packageData:sub(1, -6)] = string.unpack("<I4", packageData:sub(-4, -1))
  end
  return packages
end

local function insert(readHandle, writeHandle, data)
  --NOTE: writeHandle must be in append ("a") mode
  local chunkLength = 512
  if #data > 512 then
    chunkLength = #data
  end
  buf2 = data
  while true do
    buf1 = readHandle:read(chunkLength)
    writeHandle:write(buf2)
    if not buf1 then
      break
    end
    buf2 = buf1
  end
end

local function remove(filePath, location, length)
  local chunkLength = 512
  if length > 512 then
    chunkLength = length
  end
  -- The file has to get shortened, so I have no choice but to do these shenanigans
  local readHandle = assert(fs.open(filePath, "r"))
  local tmpFilePath = filePath .. ".tmp"
  local writeHandle = assert(fs.open(tmpFilePath, "w"))
  local i = 0
  while true do
    local readAmount = chunkLength
    if readAmount > location - i then
      readAmount = location - i
    end
    if readAmount == 0 then
      break
    end
    local data = readHandle:read(readAmount)
    i = i + readAmount
    assert(writeHandle:write(data))
  end
  readHandle:seek(length)
  while true do
    local data = readHandle:read(chunkLength)
    if not data then
      break
    end
    assert(writeHandle:write(data))
  end
  readHandle:close()
  writeHandle:close()
  fs.rename(tmpFilePath, filePath)
  fs.remove(tmpFilePath)
end

function solvitdb.create(path)
  checkArg(1, path, "string")
  local handle = assert(fs.open(path, "w"))
  assert(handle:write("\0\0\0\0RTFM"))
  handle:close()
end

function solvitdb.set(path, name, data)
  checkArg(1, path, "string")
  checkArg(2, name, "string")
  checkArg(3, data, "table")
  local readHandle, patLength = checkValidityAndOpen(path)
  local pat = readPat(readHandle, patLength)
  local writeHandle = assert(fs.open(path, "a"))
  if pat[name] then
    handle:seek(pat[name])
    local data, tmpdata = ""
    repeat
      tmpdata = readHandle:read(math.huge)
      oldData = oldData .. (tmpdata or "")
    until oldData:find("\n", 1, true) or not tmpdata
    readHandle:close()
    if not oldData:find("\n", 1, true) and not tmpdata then
      error("hit unexpected EOF")
    end
    oldData = oldData:match("^[^\n]+")
    local difference = #data - #oldData
    if difference == 0 then
      writeHandle:seek("set", pat[name] + patLength + 8)
      readHandle:close()
      writeHandle:write(data)
    elseif difference < 0 then

    elseif difference > 0 then

    end
  else
    writeHandle:seek("end")
    local newPackageLocation = writeHandle:seek() - patLength - 8
    if newPackageLocation > 4294967295 then
      -- The above is the 32 bit unsigned integer limit
      error("DB too large")
    end
    writeHandle:write("Pdguess-what-time-it-is;its-soup-time.\n")
    writeHandle:seek("set", patLength + 8) -- + 8 because that's the length of the header
    local patData = ("%s.%s;"):format(name, string.pack("<I4", newPackageLocation))
    insert(readHandle, writeHandle, patData)
    readHandle:close()
    local newPatLength = patLength + #patData
    writeHandle:seek("set", 0)
    if newPatLength > 4294967295 then
      error("PAT too large")
    end
    writeHandle:write(string.pack("<I4", newPatLength))
    writeHandle:close()
  end
end

function solvitdb.get(path, name)
  checkArg(1, path, "string")
  checkArg(2, name, "string")
  local handle, patLength = checkValidityAndOpen(path)
  local pat = readPat(handle, patLength)
  if not pat[name] then
    return nil
  end
  handle:seek(pat[name])
  local data, tmpdata = ""
  repeat
    tmpdata = handle:read(math.huge)
    data = data .. (tmpdata or "")
  until data:find("\n", 1, true) or not tmpdata
  handle:close()
  if not data:find("\n", 1, true) and not tmpdata then
    error("hit unexpected EOF")
  end
  data = data:match("^[^\n]+")
  local output = {}
  if data:sub(1, 1) == "P" then
    output.type = "package"
  elseif data:sub(1, 1) == "G" then
    output.type = "group"
  elseif data:sub(1, 1) == "V" then
    output.type = "virtual-package"
  else
    error("unknown package type")
  end
  data = "." .. data:sub(2, -1)
  for series in data:gmatch("%.([dDcp][^.]*)") do
    local seriesOutput
    if series:sub(1, 1) == "d" then
      output.dependencies = {}
      seriesOutput = output.dependencies
    elseif series:sub(1, 1) == "D" then
      output.reverseDependencies = {}
      seriesOutput = output.reverseDependencies
    elseif series:sub(1, 1) == "c" then
      output.conflicts = {}
      seriesOutput = output.conflicts
    elseif series:sub(1, 1) == "p" then
      output.packages = {}
      seriesOutput = output.packages
    end
    -- Finally a case where Lua's weird table linking shenanigans are actually useful
    series = series:sub(2, -1)
    for seriesItem in series:gmatch("[^;]+") do
      table.insert(seriesOutput, seriesItem)
    end
  end
  return output
end

function solvitdb.list(path)
  checkArg(1, path, "string")
  local handle, patLength = checkValidityAndOpen(path)
  local pat = readPat(handle, patLength)
  handle:close()
  local list = {}
  for index, _ in pairs(pat) do
    table.insert(list, index)
  end
  setmetatable(list, {
    __call = function(self)
    i, value = next(self, i)
    return i, value
    end,
  })
  return list
end

function solvitdb.remove()

end

return solvitdb

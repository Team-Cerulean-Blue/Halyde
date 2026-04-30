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
  local handle = checkValidityAndOpen(path)
end

function solvitdb.get(path, name)
  checkArg(1, path, "string")
  checkArg(2, name, "string")
  local handle, patLength = checkValidityAndOpen(path)
  local pat = readPat(handle, patLength)
  assert(pat[name], "could not find package in PAT")
  handle:seek(pat[name])
  local data, tmpdata = ""
  repeat
    tmpdata = handle:read(math.huge)
    data = data .. (tmpdata or "")
  until data:find("\n", 1, true) or not tmpdata
  if not data:find("\n", 1, true) and not tmpdata then
    error("hit unexpected EOF")
  end
  data = data:match("^(.-)\n")
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

function solvitdb.remove()

end

return solvitdb

local fs = require("filesystem")
local shell = require("shell")

local function formatSize(size, isDir)
  if isDir then return "[DIR]" end
  if size >= 1024^3 then return string.format("%.1fGiB", size / 1024^3) end
  if size >= 1024^2 then return string.format("%.1fMiB", size / 1024^2) end
  if size >= 1024 then return string.format("%.1fKiB", size / 1024) end
  return size.."B"
end

local function getFileColor(name, isDir)
  if isDir then return "\27[93m" end
  if name:match("%.lua$") then return "\27[92m" end
  return "\27[0m"
end

local args = {...}
if not args[1] then
  args = {require("shell").getWorkingDirectory()}
end

for _, path in pairs(args) do
  path = shell.resolvePath(path)
  local files = fs.list(path)

  if not files then
    terminal.write("\27[91mError: " .. path .. ": No such file or directory\27[0m\n")
    goto continue
  end

  local fileList = {}
  for _, file in pairs(files) do
    local isDir = file:sub(-1) == "/"
    local name = isDir and file:sub(1, -2) or file
    local size = isDir and 0 or fs.size(fs.concat(path, file))
    table.insert(fileList, {name = name, isDir = isDir, size = size})
  end
  -- directories first
  -- then files
  table.sort(fileList, function(a, b)
  if a.isDir ~= b.isDir then return a.isDir end
    return a.name < b.name
  end)
  local maxSizeLen = 0
  for _, item in ipairs(fileList) do
    maxSizeLen = math.max(maxSizeLen, #formatSize(item.size, item.isDir))
  end

  terminal.write(path.."\n")
  for _, item in ipairs(fileList) do
    local sizeStr = formatSize(item.size, item.isDir)
    sizeStr = string.rep(" ", maxSizeLen - #sizeStr) .. sizeStr
    local color = getFileColor(item.name, item.isDir)
    terminal.write(string.format("%s  %s%s\27[0m\n", sizeStr, color, item.name))
  end
  ::continue::
end

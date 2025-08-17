local args = {...}
local target = args[1]
args = nil
local fs = require("filesystem")
local unicode = require("unicode")
local maxLength = 0
local margin = 2 -- minimum space between filename and size
local dirTable = {}
local fileTable = {}

if target then
  if target:sub(1, 1) ~= "/" then
    target = fs.concat(shell.workingDirectory, target)
  end
else
  target = shell.workingDirectory
end

local files = fs.list(target)

if files then
  for _, file in pairs(files) do
    if file:sub(-1, -1) == "/" then
      table.insert(dirTable, file)
      file = file:sub(1, -2)
    else
      table.insert(fileTable, file)
    end
    if unicode.wlen(file) > maxLength then
      maxLength = unicode.wlen(file)
    end
  end
  table.sort(dirTable)
  table.sort(fileTable)
  files = {}
  for _, v in ipairs(dirTable) do
    table.insert(files, v)
  end
  for _, v in ipairs(fileTable) do
    table.insert(files, v)
  end
  dirTable, fileTable = nil, nil
  for _, file in ipairs(files) do
    local dir = false
    local filetext
    if file:sub(-1, -1) == "/" then
      dir = true
      filetext = "\27[93m"..file:sub(1, -2)
    elseif file:find(".") and file:match("[^.]+$") == "lua" then
      filetext = "\27[92m"..file
    end
    filetext = (filetext or file)..string.rep(" ", maxLength - unicode.wlen(file) + margin)
    if dir then
      print(filetext.." \27[0m[DIR]")
    else
      local size = fs.size(fs.concat(target, file))
      local sizeString
      if convert(size, "B", "GiB") >= 1 then
        sizeString = tostring(math.floor(convert(size, "B", "GiB") * 100 + 0.5) / 100).." GiB"
      elseif convert(size, "B", "MiB") >= 1 then
        sizeString = tostring(math.floor(convert(size, "B", "MiB") * 100 + 0.5) / 100).." MiB"
      elseif convert(size, "B", "KiB") >= 1 then
        sizeString = tostring(math.floor(convert(size, "B", "KiB") * 100 + 0.5) / 100).." KiB"
      else
        sizeString = tostring(size).." B"
      end
      print(filetext.."\27[0m"..sizeString)
    end
  end
end

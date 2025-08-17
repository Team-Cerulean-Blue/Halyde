local url = ...

local component = require("component")
local fs = require("filesystem")

if not component.list("internet")() then
  print("\27[91mThis program requires an internet card to run.")
  return
end

if not url then
  print("Please enter a URL to download from.")
  shell.run("help download")
  return
end

if url:sub(-1, -1) == "/" then
  url = url:sub(1, -2)
end

local internet = component.internet

local request, data, tmpdata = nil, "", nil
local status, errorMessage = pcall(function()
  request = internet.request(url)
  request:finishConnect()
end)
if not status then
  print("\27[91mDownload failed: " .. errorMessage)
end
local responseCode = request:response()
if responseCode and responseCode ~= 200 then
  print("\27[91mDownload failed: " .. tostring(responseCode))
end
repeat
  tmpdata = request.read(math.huge)
  data = data .. (tmpdata or "")
until not tmpdata
local saveLocation
local saveLocationOK = false
repeat
  saveLocation = read(nil, "File save location: ", fs.concat(shell.workingDirectory, url:match("/([^/]+)$")))
  if fs.isDirectory(saveLocation) then
    print("\27[91mThe specified location is a directory.")
  elseif fs.exists(saveLocation) then
    local answer = read(nil, "\27[91mThere is already a file at the specified directory. Overwrite it? [Y/n]")
    if answer:lower() ~= "n" then
      saveLocationOK = true
    end
  else
    saveLocationOK = true
  end
until saveLocationOK
local handle = fs.open(saveLocation, "w")
handle:write(data)
handle:close()
print("File downloaded successfully.")

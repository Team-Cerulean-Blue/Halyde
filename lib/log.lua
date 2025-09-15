local fs, computer
if require then
	fs = require("filesystem")
	computer = require("computer")
else
	local loadfile = ...
	fs = loadfile("/lib/filesystem.lua")(loadfile)
	computer = _G.computer
end

logFileSizeLimit = 16384

local function writeToLog(path, text)
	local handle
	if fs.exists(path) then
		handle = assert(fs.open(path, "a"))
	else
		handle = assert(fs.open(path, "w"))
	end
	handle:write(text .. "\n")
	handle:close()

	-- Log trimming if it gets too long
	if fs.size(path) > logFileSizeLimit then
		ocelot.log("Trimming log...")
		local newlineCounter = 0
		local sizeCounter = 0
		local readHandle = fs.open(path, "r")
		local chunkSize = 1024
		readHandle:seek("end", -chunkSize)
		repeat
			local readText = readHandle:read(chunkSize)
			readHandle:seek(-chunkSize * 2)
			local _, newlineCount = readText:gsub("\n", "\n")
			newlineCounter = newlineCounter + newlineCount
			sizeCounter = sizeCounter + chunkSize
		until sizeCounter >= logFileSizeLimit * 0.75
		readHandle:seek(chunkSize)
		local writeHandle = fs.open(path, "w")
		while true do
			local tmpdata = readHandle:read(math.huge or math.maxinteger)
			if not tmpdata then
				break
			end
			writeHandle:write(tmpdata)
		end
		readHandle:close()
		writeHandle:close()
	end
end

local log = {}

setmetatable(log, {
	["__index"] = function(tab, index)
		return {
			["logpath"] = fs.concat("/halyde/logs/", index .. ".log"),
			["info"] = function(text)
				writeToLog(fs.concat("/halyde/logs/", index .. ".log"), "INFO [" .. computer.uptime() .. "] " .. text)
			end,
			["warn"] = function(text)
				writeToLog(fs.concat("/halyde/logs/", index .. ".log"), "WARN [" .. computer.uptime() .. "] " .. text)
			end,
			["error"] = function(text)
				writeToLog(fs.concat("/halyde/logs/", index .. ".log"), "ERROR [" .. computer.uptime() .. "] " .. text)
			end,
		}
	end,
})

return log

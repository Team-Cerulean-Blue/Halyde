local gpu = component.proxy(component.list("gpu")())
local resX, resY = gpu.getResolution()

local function loadfile(file)
	checkArg(1, file, "string")
	local handle = component.invoke(computer.getBootAddress(), "open", file, "r")
	local data = ""
	repeat
		local tmpdata = component.invoke(computer.getBootAddress(), "read", handle, math.huge or math.maxinteger)
		data = data .. (tmpdata or "")
	until not tmpdata
	component.invoke(computer.getBootAddress(), "close", handle)
	return assert(load(data, "=" .. file))
end

local function handleError(errorMessage)
	return (errorMessage .. "\n \n" .. debug.traceback())
end

function loadBoot()
	local foundArchitecture = false
	for _, arch in pairs(computer.getArchitectures()) do
		if arch == "Lua 5.3" then
			foundArchitecture = true
			break
		end
	end

	if foundArchitecture then
		local _, errorMesage = computer.setArchitecture("Lua 5.3")
		if errorMessage then
			error(errorMessage)
		end
	else
		gpu.set(1, 1, "Required architecture (Lua 5.3) is not supported.")
		gpu.set(1, 2, "Halting.")
		while true do
			computer.pullSignal()
		end
	end
	loadfile("/halyde/kernel/boot.lua")(loadfile)
end

gpu.setBackground(0x000000)
gpu.fill(1, 1, resX, resY, " ")

-- Copying low-level functions in case of post-preload failure
local pullSignal = computer.pullSignal
local beep = computer.beep
local unicode = unicode

local result, reason = xpcall(loadBoot, handleError)
local lines = {}
if not result then
	reason = "A fatal error has occurred.\nHalyde cannot continue.\n \n"
		.. tostring(reason or "unknown error"):gsub("\t", "  ")
	local bgColor
	if gpu.getDepth() == 1 then
		bgColor = 0x000000
	else
		bgColor = 0x000080
	end
	gpu.setBackground(bgColor)
	gpu.fill(1, 1, resX, resY, " ")
	for line in string.gmatch(reason, "([^\n]*)\n?") do
		table.insert(lines, line)
	end
	local function render()
		gpu.setForeground(0xFFFFFF)
		for i = 1, #lines do
			gpu.set(2, i + 1, lines[i])
		end
		gpu.fill(1, resY - 1, resX, 1, "─")
		gpu.fill(1, resY, resX, 1, " ")
		gpu.setForeground(bgColor)
		gpu.setBackground(0xFFFFFF)
		gpu.set(2, resY, "🠅   🠄   🠇   🠆")
		gpu.setForeground(0xFFFFFF)
		gpu.setBackground(bgColor)
		gpu.set(4, resY, " / ")
		gpu.set(9, resY, " / ")
		gpu.set(14, resY, " / ")
		gpu.set(19, resY, " Scroll" .. string.rep(" ", resX - 21))
	end
	local function cropset(x, y, txt)
		gpu.set(math.max(x, 1), y, unicode.sub(txt, math.max(2 - x, 1)))
	end
	local scrollX = 0
	local scrollY = 0
	local function scrollDown()
		if scrollY >= #lines - resY + 2 then
			return
		end
		gpu.copy(1, 2, resX, resY - 3, 0, -1)
		gpu.fill(1, resY - 2, resX, 1, " ")
		local line = lines[scrollY + resY - 2]
		if type(line) == "string" then
			cropset(2 - scrollX, resY - 2, line)
		end
		scrollY = scrollY + 1
	end
	local function scrollUp()
		if scrollY <= 0 then
			return
		end
		gpu.copy(1, 1, resX, resY - 3, 0, 1)
		gpu.fill(1, 1, resX, 1, " ")
		local line = lines[scrollY - 1]
		if type(line) == "string" then
			cropset(2 - scrollX, 1, line)
		end
		scrollY = scrollY - 1
	end
	local width = 0
	for i = 1, #lines do
		width = math.max(width, unicode.len(lines[i]))
	end
	local function rerender()
		for i = 1, #lines do
			local y = i - scrollY + 1
			if y > 0 and y <= resY - 2 then
				gpu.fill(1, y, resX, 1, " ")
				cropset(2 - scrollX, y, lines[i])
			end
		end
	end
	local function scrollRight()
		if scrollX >= width - resX + 2 then
			return
		end
		scrollX = scrollX + 1
		rerender()
	end
	local function scrollLeft()
		if scrollX <= 0 then
			return
		end
		scrollX = scrollX - 1
		rerender()
	end
	render()
	beep(440, 0.2)
	beep(465, 0.2)
	beep(440, 0.2)
	beep(370, 0.5)
	while true do
		local ev = { pullSignal() }
		if ev[1] == "key_down" then
			if ev[4] == 200 then
				scrollUp()
			end
			if ev[4] == 208 then
				scrollDown()
			end
			if ev[4] == 203 then
				scrollLeft()
			end
			if ev[4] == 205 then
				scrollRight()
			end
		end
		if ev[1] == "scroll" then
			if ev[5] > 0 then
				scrollUp()
			else
				scrollDown()
			end
		end
	end
end

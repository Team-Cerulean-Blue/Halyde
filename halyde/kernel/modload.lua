local log = require("log")
local fs = require("filesystem")

local modulePath = "/halyde/kernel/modules"

local moduleList = assert(fs.list(modulePath))
local modules = {}
local moduleTypes = {}

local function loadModule(modName)
	local moduleData = modules[modName]
	table.remove(moduleList, table.find(moduleList, modName))
	if not moduleData then
		log.kernel.warn(string.format("[modload: %s] Could not find module data.", modName))
		return
	end
	if not moduleData.check() then
		log.kernel.info(string.format("[modload: %s] Module not ready - skipping", modName))
		return
	end
	if moduleData.dependencies then
		for _, dependency in pairs(moduleData.dependencies) do
			if table.find(moduleList, dependency) then
				loadModule(dependency)
			elseif table.find(moduleList, dependency .. ".lua") then
				loadModule(dependency .. ".lua")
			else
				for typeLookupDrvName, typeLookupDrvType in pairs(moduleTypes) do
					if typeLookupDrvType == dependency then
						loadModule(typeLookupDrvName)
						-- Don't break, because there can be multiple modules of the correct type
					end
				end
			end
		end
	end
	--print(modName)
	log.kernel.info(string.format("[modload: %s] Loading module", modName))
	if moduleData.init then -- I have no idea why this would not exist, but it's a failsafe
		moduleData.init()
	end
end

for _, modName in pairs(moduleList) do -- Get all the module types
	log.kernel.info(string.format("[modload: %s] Getting data from module", modName))
	local moduleData = require(fs.concat(modulePath, modName)) -- TODO: Make this not actually throw an error, rather put something in the log and move on
	if type(moduleData) ~= "table" then
		log.kernel.error(
			string.format("[modload: %s] Module returned invalid type (%s) - skipping", modName, type(moduleData))
		)
		goto continue
	end
	modules[modName] = moduleData
	if moduleData.type then
		--print(moduleData.type)
		moduleTypes[modName] = moduleData.type -- Not the other way around because there can be multiple modules of the same type, but there can't be multiple entries with the same key
	end
	::continue::
end

while moduleList[1] do
	if moduleList[1]:sub(-1, -1) ~= "/" then -- Check if it's not a directory. If it is, it might be module config
		loadModule(moduleList[1])
	end
end

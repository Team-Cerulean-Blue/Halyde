local packages = {...}
local command = packages[1]
table.remove(packages, 1)
local fs = import("filesystem")
local component = import("component")
local agReg = import("/argentum/registry.cfg")
if not command then
  shell.run("help argentum")
  return
end
if not component.list("internet")() then
  print("\27[91mThis program requires an internet card to run.")
  return
end
local internet = component.internet
local source
if table.find(packages, "-s") then
  source = table.remove(packages, table.find(packages, "-s") + 1)
  table.remove(packages, table.find(packages, "-s"))
  print("Using " .. source .. " as package source")
elseif table.find(packages, "--source") then
  source = table.remove(packages, table.find(packages, "--source") + 1)
  table.remove(packages, table.find(packages, "--source"))
  print("Using " .. source .. " as package source")
else
  print("Using main registry as package source")
end
if source and source:sub(1, 1) == "/" and source:sub(-1, -1) ~= "/" then
  source = source .. "/"
end
local packageList = table.copy(packages)

local function getFile(path)
  if path:sub(1,1) == "/" then
    if not fs.exists(path) then
      return false, "file does not exist"
    end
    local handle, data, tmpdata = fs.open(path, "r"), "", nil
    repeat
      tmpdata = handle:read(math.huge)
      data = data .. (tmpdata or "")
    until not tmpdata
    handle:close()
    return data
  else
    local request, data, tmpdata = nil, "", nil
    local status, errorMessage = pcall(function()
      request = internet.request(path)
      request:finishConnect()
    end)
    if not status then
      return false, errorMessage
    end
    local responseCode = request:response()
    if responseCode and responseCode ~= 200 then
      return false, responseCode
    end
    repeat
      tmpdata = request.read(math.huge)
      data = data .. (tmpdata or "")
    until not tmpdata
    return data
  end
end

local i = 1

local function getAgConfig(package, source)
  source = source or agReg[package]
  local data, errorMessage = getFile(source .. "argentum.cfg")
  if not data or data == "" then
    print("\27[91mCould not fetch Ag config: " .. (errorMessage or "returned nil data"))
    return false
  end
  local func, errorMessage = load(data, "=argentum.cfg", "bt", {})
  if not func then
    print("\27[91mCould not fetch Ag config: " .. errorMessage .. "\nPlease contact the package owner.")
    return false
  end
  local agcfg
  local status, errorMessage = pcall(function()
    agcfg = func()
  end)
  if not status then
    print("\27[91mCould not fetch Ag config: " .. errorMessage .. "\nPlease contact the package owner.")
    return false
  end
  if not agcfg[package] or not agcfg[package].maindir or not agcfg[package].directories or not agcfg[package].files or not agcfg[package].version then
    local response = ("\27[91mAg config of " .. package .. " is improperly configured.\nPlease contact the package owner.")
  end
  return agcfg
end

local function doChecks(package)
  if not agReg[package] and not source then
    print("\27[91mPackage " .. package .. " does not exist.")
    return false
  end
  if fs.exists("/argentum/store/" .. package) then
    print("\27[91mPackage " .. package .. " is already installed.")
    return false
  end
  agcfg = getAgConfig(package, source)
  if not agcfg then
    return false
  end
  if agcfg[package].dependencies then
    for _, dependency in ipairs(agcfg[package].dependencies) do
      if not agReg[dependency] and not agcfg[dependency] then
        local response = read(nil, "\27[91mPackage " .. package .. " requires dependency " .. dependency .. " that does not exist.\n[A - Abort/s - Skip]")
        if response:lower() ~= "s" then
          fs.remove("/argentum/store/" .. package)
          return false
        end
      end
    end
    for _, dependency in pairs(agcfg[package].dependencies) do
      print(package .. " depends on " .. dependency)
      if not table.find(packages, dependency) and doChecks(dependency) then
        table.insert(packages, table.find(packages, package), dependency)
        table.insert(packageList, dependency)
        i = i + 1
      end
    end
  end
  return true
end

local function lpad(str, len, char)
  str=tostring(str)
  if char == nil then char = ' ' end
  return string.rep(char, len - #str) .. str
end

local gpu = component.gpu
local width,height = gpu.getResolution()
local function progress(package,progress)
  local info = string.format("%s %s%%",package,lpad(math.floor(progress*100),2))

  info=info..string.rep(" ",width-#info)
  local progX = math.floor(progress*width)
  gpu.setBackground(0x00FF00)
  gpu.setForeground(0x000000)
  gpu.set(1,height,info:sub(1,progX))
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.set(progX+1,height,info:sub(progX+1))
end

local function clearProgress()
  gpu.setBackground(0x000000)
  gpu.fill(1,height,width,1," ")
end

local function installPackage(package, overwriteFlag)
  if not overwriteFlag then
    overwriteFlag = false
  end
  if not overwriteFlag then print("Installing " .. package .. "...") end
  local agcfg = getAgConfig(package, source)
  if not agcfg then
    return false
  end
  local source = source or agReg[package]
  local packageStore = "V" .. agcfg[package].version
  if agcfg[package].dependencies then
    for _, dependency in ipairs(agcfg[package].dependencies) do
      if not agReg[dependency] and not agcfg[dependency] then
        local response = read(nil, "\27[91mPackage " .. package .. " requires dependency " .. dependency .. " that does not exist.\n[A - Abort/s - Skip]")
        if response:lower() ~= "s" then
          fs.remove("/argentum/store/" .. package)
          return false
        end
      end
    end
    for _, dependency in pairs(agcfg[package].dependencies) do
      if agReg[dependency] or agcfg[dependency] then
        --installPackage(dependency)
        packageStore = packageStore .. "\nD" .. dependency
      end
    end
  end
  if agcfg[package].directories then
    for _, directory in pairs(agcfg[package].directories) do
      if directory:sub(-1, -1) ~= "/" then
        directory = directory .. "/"
      end
      packageStore = "A" .. directory .. "\n" .. packageStore
      if not fs.exists(directory) then
        fs.makeDirectory(directory)
      end
    end
  end
  for idx, file in ipairs(agcfg[package].files) do
    clearProgress()
    ::retry::
    print("  Downloading " .. file .. "...")
    progress(package,idx/#agcfg[package].files)
    local data, errorMessage = getFile(source .. agcfg[package].maindir .. file)
    if not data then
      clearProgress()
      local response = read(nil, "\27[91mCould not fetch " .. file .. ": " .. errorMessage .. "\n\27[0m[a - Abort/R - Retry/s - Skip]")
      if response:lower() == "a" then
        fs.remove("/argentum/store/" .. package)
        return false
      elseif response:lower() == "s" then
        goto skip
      else
        goto retry
      end
    end
    if fs.exists(file) and not overwriteFlag then
      if not fs.exists("/argentum/store/" .. package .. "/files/" .. file:match("(.*/)")) then
        fs.makeDirectory("/argentum/store/" .. package .. "/files/" .. file:match("(.*/)"))
      end
      fs.copy(file, "/argentum/store/" .. package .. "/files/" .. file)
      packageStore = packageStore .. "\nM" .. file
    else
      packageStore = packageStore .. "\nA" .. file
    end
    local handle = fs.open(file, "w")
    handle:write(data)
    handle:close()
    ::skip::
  end
  clearProgress()
  fs.makeDirectory("/argentum/store/" .. package)
  local handle = fs.open("/argentum/store/" .. package .. "/package.cfg", "w")
  handle:write(packageStore)
  handle:close()
  return true
end

local function removePackage(package)
  print("Removing " .. package .. "...")
  if not fs.exists("/argentum/store/" .. package .. "/package.cfg") then
    print("\27[91mLocal Ag config of " .. package .. " does not exist.")
    return false
  end
  local handle, data, tmpdata = fs.open("/argentum/store/" .. package .. "/package.cfg", "r"), "", nil
  repeat
    tmpdata = handle:read(math.huge)
    data = data .. (tmpdata or "")
  until not tmpdata
  handle:close()
  data = data .. "\n"
  local idx = 0
  for line in data:gmatch("(.-)\n") do
    idx=idx+1
    if line:sub(1, 1) == "A" then
      clearProgress()
      ::retry::
      print("  Removing " .. line:sub(2) .. "...")
      if line:sub(-1, -1) == "/" and fs.list(line:sub(2))[1] then
        print("  There are still files in " .. line:sub(2) .. ". Skipping.")
      else
        progress(package,idx/select(2,data:gsub("\n","\n")))
        local result, errorMessage = fs.remove(line:sub(2))
        if not result then
          clearProgress()
          local response = read(nil, "\27[91mFailed to remove " .. line:sub(2) .. ": " .. errorMessage .. "\n\27[0m[a - Abort/r - Retry/S - Skip]")
          if response:lower() == "a" then
            return false
          elseif response:lower() == "r" then
            goto retry
          end
        end
      end
    elseif line:sub(1, 1) == "M" then
      clearProgress()
      ::retry::
      print("  Reverting " .. line:sub(2) .. "...")
      progress(package,idx/select(2,data:gsub("\n","\n")))
      local handle, data, tmpdata = fs.open("/argentum/store/" .. package .. "/files/" .. line:sub(2), "r"), "", nil
      if not handle then
        clearProgress()
        local response = read(nil, "\27[91mFailed to revert " .. line:sub(2) .. ": " .. data .. "\n\27[0m[a - Abort/R - Retry/s - Skip]") -- this is pretty stupid but i think the error message would get pushed to data
        if response:lower() == "a" then
          return false
        elseif response:lower() == "s" then
          goto skip
        else
          goto retry
        end
      end
      repeat
        tmpdata = handle:read(math.huge)
        data = data .. (tmpdata or "")
      until not tmpdata
      handle:close()
      local handle = fs.open(line:sub(2), "w")
      handle:write(data)
      handle:close()
      ::skip::
    end
  end
  clearProgress()
  fs.remove("/argentum/store/" .. package .. "/")
  return true
end

local function updatePackage(package)
  print("Updating " .. package .. "...")
  local agcfg = getAgConfig(package, source)
  if not agcfg then
    return false
  end
  local handle, data, tmpdata = fs.open("/argentum/store/" .. package .. "/package.cfg", "r"), "", nil
  repeat
    tmpdata = handle:read(math.huge)
    data = data .. (tmpdata or "")
  until not tmpdata
  handle:close()
  local oldFiles = {}
  for line in (data .. "\n"):gmatch("(.-)\n") do
    if line:sub(1, 1) == "A" or line:sub(1, 1) == "M" then
      if agcfg[package].directories then
        if not table.find(agcfg[package].files, line:sub(2)) and not table.find(agcfg[package].directories, line:sub(2, -2)) then
          table.insert(oldFiles, line:sub(2))
        end
      else
        if not table.find(agcfg[package].files, line:sub(2)) then
          table.insert(oldFiles, line:sub(2))
        end
      end
    end
  end
  for _, oldFile in pairs(oldFiles) do
    print("  Removing " .. oldFile .. "...")
  end
  return installPackage(package, true)
end

local fails = {}
if command == "install" then
  if not packages or not packages[1] then
    print("Please specify packages to install.")
    return
  end
  print("Fetching Ag registry...")
  local newRegistry, errorMessage = getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/main/argentum/registry.cfg")
  if newRegistry then
    local handle = fs.open("/argentum/registry.cfg", "w")
    handle:write(newRegistry)
    handle:close()
  else
    print("\27[91mFailed to fetch Ag registry: " .. (errorMessage or "returned nil"))
  end
  agReg = import("/argentum/registry.cfg")
  while true do
    if not doChecks(packages[i]) then
      table.insert(fails, packages[i])
      table.remove(packageList, table.find(packageList, packages[i]))
    end
    i = i + 1
    if i > #packages then
      break
    end
  end
  local answer
  if #fails == 0 then
    print("Packages that will be installed: " .. table.concat(packageList, ", "))
    if read(nil, "Would you like to proceed? [Y/n] "):lower() == "n" then
      return
    end
  elseif #packageList == 0 then
    print("None of the packages can be installed.")
    return
  else
    print("Some packages cannot be installed.")
    print("Packages that will be installed: " .. table.concat(packageList, ", "))
    print("Packages that cannot be installed: " .. table.concat(fails, ", "))
    if read(nil, "Would you like to proceed? [y/N] "):lower() ~= "y" then
      return
    end
  end
  for _, failedPackage in pairs(fails) do
    table.remove(packages, table.find(packages, failedPackage))
  end
  fails = {}
  for _, package in ipairs(packages) do
    if not installPackage(package) then
      table.insert(fails, package)
      table.remove(packageList, table.find(packageList, package))
    end
  end
  if #fails == 0 then
    print("Installation completed successfully.")
    print("Packages installed: " .. table.concat(packageList, ", "))
  elseif #packageList == 0 then
    print("All packages failed to install.")
    print("Packages that could not be installed: " .. table.concat(fails, ", "))
  else
    print("Some packages failed to install.")
    print("Packages installed: " .. table.concat(packageList, ", "))
    print("Packages that could not be installed: " .. table.concat(fails, ", "))
  end
elseif command == "remove" then
  if not packages or not packages[1] then
    print("Please specify packages to remove.")
    return
  end
  while true do
    if not fs.exists("/argentum/store/" .. packages[i]) then
      print("\27[91mPackage " .. packages[i] .. " is not installed.")
      table.insert(fails, packages[i])
      table.remove(packageList, table.find(packageList, packages[i]))
      table.remove(packages, table.find(packages, packages[i]))
      i = i - 1
    elseif packages[i] == "halyde" then -- yes, this stuff is hard-coded.
      print("\27[91mFor obvious reasons, you can't uninstall Halyde.")
      table.insert(fails, packages[i])
      table.remove(packageList, table.find(packageList, packages[i]))
      table.remove(packages, table.find(packages, packages[i]))
      i = i - 1
    elseif packages[i] == "argentum" then
      print("\27[91mFor obvious reasons, you can't uninstall Argentum.")
      table.insert(fails, packages[i])
      table.remove(packageList, table.find(packageList, packages[i]))
      table.remove(packages, table.find(packages, packages[i]))
      i = i - 1
    end
    i = i + 1
    if i > #packages then
      break
    end
  end
  -- do dependency checks
  local packagesInstalled = fs.list("/argentum/store")
  for _, currentPackage in pairs(packagesInstalled) do
    if currentPackage:sub(-1, -1) == "/" and fs.exists("/argentum/store/" .. currentPackage .. "package.cfg") then
      local handle, data, tmpdata = fs.open("/argentum/store/" .. currentPackage .. "package.cfg", "r"), "", nil
      repeat
        tmpdata = handle:read(math.huge)
        data = data .. (tmpdata or "")
      until not tmpdata
      handle:close()
      for line in (data.."\n"):gmatch("(.-)\n") do
        for i = 1, #packages do
          if line == "D" .. packages[i] then
            print(packages[i] .. " depends on " .. currentPackage:sub(1, -2))
            if not table.find(packages, currentPackage:sub(1, -2)) then
              table.insert(packages, table.find(packages, packages[i]), currentPackage:sub(1, -2))
              table.insert(packageList, currentPackage:sub(1, -2))
              i = i + 1
            end
          end
        end
      end
    end
  end
  local answer
  if #fails == 0 then
    print("Packages that will be removed: " .. table.concat(packageList, ", "))
    if read(nil, "Would you like to proceed? [Y/n] "):lower() == "n" then
      return
    end
  elseif #packageList == 0 then
    print("None of the packages can be removed.")
    return
  else
    print("Some packages cannot be removed.")
    print("Packages that will be removed: " .. table.concat(packageList, ", "))
    print("Packages that cannot be removed: " .. table.concat(fails, ", "))
    if read(nil, "Would you like to proceed? [y/N] "):lower() ~= "y" then
      return
    end
  end
  for _, failedPackage in pairs(fails) do
    table.remove(packages, table.find(packages, failedPackage))
  end
  fails = {}
  for _, package in ipairs(packages) do
    if not removePackage(package) then
      table.insert(fails, package)
      table.remove(packageList, table.find(packageList, package))
    end
  end
  if #fails == 0 then
    print("Removal completed successfully.")
    print("Packages removed: " .. table.concat(packageList, ", "))
  elseif #packageList == 0 then
    print("All packages failed to be removed.")
    print("Packages that could not be removed: " .. table.concat(fails, ", "))
  else
    print("Some packages failed to be removed.")
    print("Packages removed: " .. table.concat(packageList, ", "))
    print("Packages that could not be removed: " .. table.concat(fails, ", "))
  end
elseif command == "update" then
  print("Fetching Ag registry...")
  local newRegistry, errorMessage = getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/main/argentum/registry.cfg")
  if newRegistry then
    local handle = fs.open("/argentum/registry.cfg", "w")
    handle:write(newRegistry)
    handle:close()
  else
    print("\27[91mFailed to fetch Ag registry: " .. (errorMessage or "returned nil"))
  end
  agReg = import("/argentum/registry.cfg")
  if not packages[1] then
    local packagesInstalled = fs.list("/argentum/store/")
    for _, currentPackage in pairs(packagesInstalled) do
      if currentPackage:sub(-1, -1) == "/" and fs.exists("/argentum/store/" .. currentPackage .. "package.cfg") then
        table.insert(packages, currentPackage:sub(1, -2))
        table.insert(packageList, currentPackage:sub(1, -2))
      end
    end
  end
  while true do
    local nonexistent = false -- I couldn't figure out a better way to do this, so I have to use a flag if the package doesn't exist
    if not fs.exists("/argentum/store/" .. packages[i]) then
      print("\27[91mPackage " .. packages[i] .. " is not installed.")
      table.insert(fails, packages[i])
      table.remove(packageList, table.find(packageList, packages[i]))
      table.remove(packages, table.find(packages, packages[i]))
      i = i - 1
      nonexistent = true
    end
    if not nonexistent then
    -- Check if up to date
      local agcfg = getAgConfig(packages[i], source)
      if not agcfg then
        return false
      end
      local handle, data, tmpdata = fs.open("/argentum/store/" .. packages[i] .. "/package.cfg", "r"), "", nil
      repeat
        tmpdata = handle:read(math.huge)
        data = data .. (tmpdata or "")
      until not tmpdata
      handle:close()
      local version = "0.0.0"
      for line in (data.."\n"):gmatch("(.-)\n") do
        if line:sub(1, 1) == "V" then
          version = line:sub(2)
          break
        end
      end
      if agcfg[packages[i]].version == version then
        table.remove(packageList, table.find(packageList, packages[i]))
        table.remove(packages, table.find(packages, packages[i]))
        i = i - 1
      else
        print(packages[i].." needs updating [\x1b[93m"..version.."\x1b[39m --> \x1b[93m"..agcfg[packages[i]].version.."\x1b[39m]")
      end
    end
    i = i + 1
    if i > #packages then
      break
    end
  end
  local answer
  if #packageList == 0 then
    if #fails == 0 then
      print("All packages are up to date.")
      return
    else
      print("None of the packages can be updated.")
      return
    end
  elseif #fails == 0 then
    print("Packages that will be updated: " .. table.concat(packageList, ", "))
    if read(nil, "Would you like to proceed? [Y/n] "):lower() == "n" then
      return
    end
  else
    print("Some packages cannot be updated.")
    print("Packages that will be updated: " .. table.concat(packageList, ", "))
    print("Packages that cannot be updated: " .. table.concat(fails, ", "))
    if read(nil, "Would you like to proceed? [y/N] "):lower() ~= "y" then
      return
    end
  end
  for _, failedPackage in pairs(fails) do
    table.remove(packages, table.find(packages, failedPackage))
  end
  fails = {}
  for _, package in pairs(packages) do
    -- Previous up-to-date check

    --local agcfg = getAgConfig(package, source)
    --if not agcfg then
    --  return false
    --end
    --local handle, data, tmpdata = fs.open("/argentum/store/" .. package .. "/package.cfg", "r"), "", nil
    --repeat
    --  tmpdata = handle:read(math.huge)
    --  data = data .. (tmpdata or "")
    --until not tmpdata
    --handle:close()
    --local version = "0.0.0"
    --for line in (data.."\n"):gmatch("(.-)\n") do
    --  if line:sub(1, 1) == "V" then
    --    version = line:sub(2)
    --    break
    --  end
    --end
    --if agcfg[package].version == version then
    --  print(package .. " is up to date")
    --  goto skip
    --end
    if not updatePackage(package) then
      table.insert(fails, packages[i])
      table.remove(packageList, table.find(packageList, packages[i]))
      table.remove(packages, table.find(packages, packages[i]))
      goto skip
    end
    ::skip::
  end
  if #fails == 0 then
    print("Update completed successfully.")
    print("Packages updated: " .. table.concat(packageList, ", "))
  elseif #packageList == 0 then
    print("All packages failed to update.")
    print("Packages that could not update: " .. table.concat(fails, ", "))
  else
    print("Some packages failed to update.")
    print("Packages updated: " .. table.concat(packageList, ", "))
    print("Packages that could not update: " .. table.concat(fails, ", "))
  end
elseif command == "info" then
  if not packages[1] then
    print("Please specify a package to show information about.")
    return
  end
  print("Fetching Ag registry...")
  local newRegistry, errorMessage = getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/main/argentum/registry.cfg")
  if newRegistry then
    local handle = fs.open("/argentum/registry.cfg", "w")
    handle:write(newRegistry)
    handle:close()
  else
    print("\27[91mFailed to fetch Ag registry: " .. (errorMessage or "returned nil"))
  end
  agReg = import("/argentum/registry.cfg")
  if not agReg[packages[1]] and not source then
    print("\27[91mPackage " .. packages[1] .. " does not exist.")
    return
  end
  local agcfg = getAgConfig(packages[1], source)
  if not agcfg then
    return false
  end
  print("\27[93m" .. packages[1] .. "\27[0m v" .. agcfg[packages[1]].version .. "\n  " .. (agcfg[packages[1]].description or "No description."):gsub("\n", "  \n"))
elseif command == "search" then
  if not packages[1] then
    print("Please specify a search term.")
    return
  end
  print("Fetching Ag registry...")
  local newRegistry, errorMessage = getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/main/argentum/registry.cfg")
  if newRegistry then
    local handle = fs.open("/argentum/registry.cfg", "w")
    handle:write(newRegistry)
    handle:close()
  else
    print("\27[91mFailed to fetch Ag registry: " .. (errorMessage or "returned nil"))
  end
  agReg = import("/argentum/registry.cfg")
  local searchResults = {}
  for packageName, _ in pairs(agReg) do
    if packageName:find(packages[1], 1, true) then
      table.insert(searchResults, packageName)
    end
  end
  if not searchResults[1] then
    print("No search results found for " .. packages[1] .. ".")
    return
  end
  table.sort(searchResults)
  print("Search results: \n  " .. table.concat(searchResults, "\n  "))
elseif command == "list" then
  print("Fetching Ag registry...")
  local newRegistry, errorMessage = getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/main/argentum/registry.cfg")
  if newRegistry then
    local handle = fs.open("/argentum/registry.cfg", "w")
    handle:write(newRegistry)
    handle:close()
  else
    print("\27[91mFailed to fetch Ag registry: " .. (errorMessage or "returned nil"))
  end
  agReg = import("/argentum/registry.cfg")
  local sortedPackages = {}
  for packageName, _ in pairs(agReg) do
    table.insert(sortedPackages, packageName)
  end
  table.sort(sortedPackages)
  print("List of available Ag packages: \n  " .. table.concat(sortedPackages, "\n  "))
else
  shell.run("help ag")
end

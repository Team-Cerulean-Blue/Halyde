local cliparse = require("cliparse")
local fs = require("filesystem")
local component = require("component")
local json = require("json")

local function getFile(path)
  checkArg(1, path, "string")
  if path:sub(1, 7) == "http://" or path:sub(1, 8) == "https://" then
    if not component.list("internet")() then
      return false, "Internet card required but not found."
    end
    local handle, data, tmpdata = component.internet.request(path), "", nil
    local success, errorMessage = pcall(function()
      handle:finishConnect()
    end)
    if not success then
      return false, errorMessage
    end
    local code, message = handle:response()
    if code and code ~= 200 then
      return false, ("%d %s"):format(code, message)
    end
    repeat
      tmpdata = handle.read(math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    return true, data
  elseif path:sub(1, 1) == "/" then
    if not fs.exists(path) then
      return false, "No such file or directory: " .. path
    end
    if fs.isDirectory(path) then
      return false, "Expected file, found directory: " .. path
    end
    local handle, data, tmpdata = fs.open(path, "r", false), "", nil
    if not handle then
      return false, data
    end
    repeat
      tmpdata = handle:read(math.huge or math.maxinteger)
      data = data .. (tmpdata or "")
    until not tmpdata
    return true, data
  else
    return false, "Unsupported path: " .. path
  end
end

cliparse.config({
  ["x"] = 0,
  ["exclude-deps"] = 0,
  ["u"] = 0,
  ["update-registry"] = 0,
  ["f"] = 0,
  ["force"] = 0,
  ["c"] = 0,
  ["clean"] = 0,
  ["s"] = 1,
  ["source"] = 1
})

local parsed, errorMessage = cliparse.parse(...)

if not parsed then
  print(("\27[91m%s\n\27[0mExiting."):format(errorMessage))
  return
end

local command = parsed.args[1]

if not command then
  print("\27[91mNo command specified.\n\27[0mExiting.")
  return
end

if
  not (
    command == "install"
    or command == "remove"
    or command == "update"
    or command == "list"
    or command == "repo-list"
    or command == "repo-add"
    or command == "repo-remove"
    or command == "info"
  )
then
  print(("\27[91mInvalid command: %s\n\27[0mExiting."):format(command))
  return
end

local packages = parsed.args
table.remove(packages, 1)
-- Remove the command from the actual package list
local result, data
if parsed.flags.u or parsed.flags["update-registry"] then
  terminal.write("Updating registry...")
  result, data = getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/Pre-Alpha-3.0.0/ag2/registry.json")
  if not result then
    print(("\27[91mFailed to get registry: %s\n\27[0mExiting."):format(data))
    return
  end
  local handle, errorMessage = fs.open("/ag2/registry.json", "w")
  if not handle then
    print(("\27[91mFailed to open write handle to registry: %s\n\27[0mExiting."):format(errorMessage))
    return
  end
  local success, errorMessage = handle:write(data)
  if not success then
    print(("\27[91mFailed to write to registry: %s\n\27[0mExiting."):format(errorMessage))
    return
  end
  handle:close()
else
  result, data = getFile("/ag2/registry.json")
  if not result then
    print(("\27[91mFailed to get registry: %s\n\27[0mExiting."):format(data))
    return
  end
end

local success, registry = pcall(function()
  return json.decode(data)
end)
if not success then
  print(("\27[91mFailed to parse registry: %s\n\27[0mExiting."):format(registry))
  return
end

-- Check if everything is valid
local failure = false
local dependencyCounter = 0
if command == "install" then
  for i = 1, #packages do
    if fs.exists(("/ag2/pkg/%s.json"):format(packages[i])) then
      print(("\27[93mPackage %s is already installed, skipping"):format(packages[i]))
      table.remove(packages, i)
      i = i - 1
      goto SKIP
    end
    local source = parsed.s or parsed.source
    if not registry[packages[i]] and not source then
      print("\27[91mCould not find package in registry and no source provided: " .. packages[i])
      failure = true
      goto SKIP
    else
      source = registry[packages[i]]
    end
    local success, data = getFile(fs.concat(source, "/ag2.json"))
    if not success then
      print(("\27[91mFailed to get package config (ag2.json) of package '%s': " .. data):format(packages[i]))
      failure = true
      goto SKIP
    end
    local success, packageConfig = pcall(function()
      return json.decode(data)
    end)
    if not success then
      print(("\27[91mFailed to parse package config (ag2.json) of package '%s': " .. packageConfig):format(packages[i]))
      failure = true
      goto SKIP
    end
    if not packageConfig[packages[i]] then
      print(("\27[91mRepository package config (ag2.json) does not contain package '%s'."):format(package))
      failure = true
      goto SKIP
    end
    packageConfig = packageConfig[package]
    if packageConfig.dependencies then
      for _, dependency in ipairs(packageConfig.dependencies) do
        table.insert(packages, i + 1, dependency)
        dependencyCounter = dependencyCounter + 1
      end
    end
    ::SKIP::
  end
  if #packages == 0 then
    print("\27[91mNo packages to install.\n\27[0mExiting.")
    return
  end
end
-- TODO: Add checks for the other commands

if failure then
  print("Exiting.")
  return
end

if command == "install" then
  if dependencyCounter == 1 then
    print("\27[93m1 dependency pulled in.")
  elseif dependencyCounter >= 2 then
    print(("\27[93m%d dependencies pulled in."):format(dependencyCounter))
  end
  print("Packages that will be installed:")
  print(table.concat(packages))
  local answer = terminal.read({prefix = "\nContinue? [Y/n] "})
  if answer:lower() == "n" then
    print("Exiting.")
    return
  end

  for _, package in ipairs(packages) do
    local source
    if registry[package] then
      source = registry[package]
    else
      source = parsed.s or parsed.source
    end
    print(("Installing %s..."):format(package))
    local _, data = getFile(fs.concat(source, "/ag2.json"))
    local packageConfig = json.decode(data)[package]
    if packageConfig.directories then
      for _, directory in ipairs(packageConfig.directories) do
        print(("  Creating directory %s..."):format(directory))
        fs.makeDirectory(directory)
      end
    end
    if packageConfig.files then
      for _, file in ipairs(packageConfig.files) do
        ::RETRY::
        print(("  Downloading file %s..."):format(file))
        local success, data = getFile(fs.concat(source, file))

        if not success then
          print(("\27[91mFailed to get file '%s' of package '%s': " .. data):format(file, package))
          local answer = terminal.read({prefix = "Abort, Retry, Skip? [a/R/s]"})
          if answer:lower() == "a" then
            print("Exiting.")
            return
          elseif answer:lower() == "s" then
            print(("  \27[93mSkipped file %s."):format(file))
            goto SKIP
          else
            goto RETRY
          end
        end

        if fs.exists(file) then
          print(("\27[93mFile '%s' already exists."):format(file))
          local answer = terminal.read({prefix = "Abort, Overwrite, Skip? [a/O/s]"})
          if answer:lower() == "a" then
            print("Exiting.")
            return
          elseif answer:lower() == "s" then
            print(("  \27[93mSkipped file %s."):format(file))
            goto SKIP
          end
        end

        local handle, errorMessage = fs.open(file, "w")
        if not handle then
          print(("\27[91mFailed to open write handle to file '%s': " .. errorMessage):format(file))
          local answer = terminal.read({prefix = "Abort, Retry, Skip? [a/R/s]"})
          if answer:lower() == "a" then
            print("Exiting.")
            return
          elseif answer:lower() == "s" then
            print(("  \27[93mSkipped file %s."):format(file))
            goto SKIP
          else
            goto RETRY
          end
        end

        local success, errorMessage = handle:write(data)
        if not success then
          handle:close()
          print(("\27[91mFailed to write to file '%s': " .. errorMessage):format(file))
          local answer = terminal.read({prefix = "Abort, Retry, Skip? [a/R/s]"})
          if answer:lower() == "a" then
            print("Exiting.")
            return
          elseif answer:lower() == "s" then
            print(("  \27[93mSkipped file %s."):format(file))
            goto SKIP
          else
            goto RETRY
          end
        end

        handle:close()

        ::SKIP::
      end
    end

    print("  Writing tracking file...")
    if not fs.exists("/ag2/pkg/") then
      fs.makeDirectory("/ag2/pkg/")
      -- Technically this would break if /ag2/pkg/ was a file, but... why would it be a file?
    end

    -- TODO: Make functions for reading from and writing to a file with error handling since this is really repetitive
    ::RETRY::
    local handle, errorMessage = fs.open(("/ag2/pkg/%s.json"):format(package), "w")
    if not handle then
      print(("\27[91mFailed to open write handle to file '/ag2/pkg/%s.json': " .. errorMessage):format(package))
      local answer = terminal.read({prefix = "Abort, Retry, Skip? [a/R/s]"})
      if answer:lower() == "a" then
        print("Exiting.")
        return
      elseif answer:lower() == "s" then
        print(("  \27[93mSkipped file /ag2/pkg/%s.json."):format(package))
        goto SKIP
      else
        goto RETRY
      end
    end

    local packageData = {
      name = package,
      version = packageConfig.version,
      autoInstalled = false,
      -- TODO: Make the above actually work
      dependencies = packageConfig.dependencies,
      conflicts = packageConfig.conflicts,
      files = packageConfig.files,
      directories = packageConfig.directories,
      config = packageConfig.config
    }

    local trackingFile = json.encode(packageData)

    local success, errorMessage = handle:write(trackingFile)
    if not success then
      handle:close()
      print(("\27[91mFailed to write to file '/ag2/pkg/%s.json': " .. errorMessage):format(package))
      local answer = terminal.read({prefix = "Abort, Retry, Skip? [a/R/s]"})
      if answer:lower() == "a" then
        print("Exiting.")
        return
      elseif answer:lower() == "s" then
        print(("  \27[93mSkipped file /ag2/pkg/%s.json."):format(package))
        goto SKIP
      else
        goto RETRY
      end
    else
      handle:close()
    end
    ::SKIP::
  end
end
print("Operation completed successfully.")

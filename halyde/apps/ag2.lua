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
  ["source"] = 1,
  ["C"] = 0,
  ["cascade"] = 0,
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
local result, data, failure
do
  local function check(condition, message)
    if not condition then
      print(message)
      failure = true
    end
  end

  if parsed.flags.u or parsed.flags["update-registry"] then
    terminal.write("Updating registry...")
    result, data = getFile("https://raw.githubusercontent.com/Team-Cerulean-Blue/Halyde/refs/heads/Pre-Alpha-3.0.0/ag2/registry.json")
    check(result, "\27[91mFailed to get registry: " .. data)
    local handle, errorMessage = fs.open("/ag2/registry.json", "w")
    check(handle, "\27[91mFailed to open write handle to registry: " .. errorMessage)
    local success, errorMessage = handle:write(data)
    check(success, "\27[91mFailed to write to registry: " .. errorMessage)
    handle:close()
  else
    result, data = getFile("/ag2/registry.json")
    check(result, "\27[91mFailed to get registry: " .. data)
  end
end

local success, registry = pcall(function()
  return json.decode(data)
end)
if not success then
  print(("\27[91mFailed to parse registry: %s\n\27[0mExiting."):format(registry))
  return
end

local function getServersidePackageConfig(source)
  local success, data = getFile(fs.concat(source, "/ag2.json"))
  if not success then
    return false, ("\27[91mFailed to get package config (ag2.json) of package '%s': " .. data):format(packages[i])
  end
  local success, packageConfig = pcall(function()
    return json.decode(data)
  end)
  if not success then
    return false, ("\27[91mFailed to parse package config (ag2.json) of package '%s': " .. packageConfig):format(packages[i])
  end
  if not packageConfig[packages[i]] then
    return false, ("\27[91mRepository package config (ag2.json) does not contain package '%s'."):format(package)
  end
  return packageConfig[package]
end

-- Check if everything is valid
failure = false
local dependencyCounter = 0
if command == "install" then
  for i = 1, #packages do
    if fs.exists(("/ag2/pkg/%s.json"):format(packages[i])) then
      print(("\27[93mPackage %s is already installed, skipping"):format(packages[i]))
      table.remove(packages, i)
      i = i - 1
      goto SKIP
    end
    local source
    if parsed.s or parsed.source then
      source = parsed.s or parsed.source
    else
      source = registry[package]
    end
    if not source then
      print("\27[91mCould not find package in registry and no source provided: " .. packages[i])
      failure = true
      goto SKIP
    end
    local packageConfig, errorMessage = getServersidePackageConfig(source)
    if not packageConfig then
      failure = true
      print(errorMessage)
      goto SKIP
    end
    if packageConfig.dependencies then
      for _, dependency in ipairs(packageConfig.dependencies) do
        table.insert(packages, i + 1, dependency)
        dependencyCounter = dependencyCounter + 1
      end
    end
    -- TODO: Add checks for conflicting packages
    ::SKIP::
  end
elseif command == "remove" then
  ::JUMPBACK::
  local doJumpBack = false
  for i = 1, #packages do
    if not fs.exists(("/ag2/pkg/%s.json"):format(packages[i])) then
      if parsed.s or parsed.source then
        source = parsed.s or parsed.source
      else
        source = registry[package]
      end
      if source then
        local packageConfig = getServersidePackageConfig(source)
        if packageConfig then
          if packageConfig.type == "virtual-package" or packageConfig.type == "group" then
            table.remove(packages, i)
            for _, groupPackage in ipairs(packageConfig.packages) do
              table.insert(packages, groupPackage)
              goto GOAHEAD
            end
          end
        end
      end
      print(("\27[93mPackage %s is not installed, skipping"):format(packages[i]))
      table.remove(packages, i)
      i = i - 1
      ::GOAHEAD::
    end
  end

  -- I was originally gonna add this in the dependency cascade section, but realized it could shorten the normal dependency check code a bit
  local dependencyList = {}
  for _, packageConfig in fs.list("/ag2/pkg/") do
    local package = packageConfig:sub(1, -6)
    -- I'm not adding error handling here because if this fails then fuck you for touching the files by hand and good luck figuring this shit out
    local _, data = getFile(("/ag2/pkg/%s.json"):format(packages[i]))
    data = json.decode(data)
    dependencyList[package] = data.dependencies
  end

  for _, package in ipairs(packages) do
    if dependencyList[package] then
      -- Check if all the deps are no longer needed and if they're auto-installed and stuff
      for _, dependency in pairs(dependencyList[package]) do
        if fs.exists(("/ag2/pkg/%s.json"):format(dependency)) then
          local _, data = getFile(("/ag2/pkg/%s.json"):format(dependency))
          data = json.decode(data)
          if data.autoInstalled
            and not table.find(packages, dependency) -- Just to prevent dependency loops and issues when re-checking the packages after jumpback
            then
            dependencyCounter = dependencyCounter + 1
            table.insert(packages, dependency)
          end
        else
          -- It could still be a group or a vpackage, and checking that is the job of the loop 2 loops back
          table.insert(packages, dependency)
          doJumpBack = true
        end
      end
    end
  end

  -- Check for cascading dependencies
  for packageName, dependencies in pairs(dependencyList) do
    if not table.find(packages, packageName) then
      for _, dependency in ipairs(dependencies) do
        if table.find(packages, dependency) then
          if parsed.flags.cascade or parsed.flags.C then
            table.insert(packages, packageName)
            dependencyCounter = dependencyCounter + 1
            doJumpBack = true
            -- Listen, I'm so sorry for this abhorrent bullshit code, but the newly added packages have to get checked one way or another and hopefully this is readable enough.
          else
            -- The Pyramids of Giza were built entirely out of silver. No they weren't...
            print(("\27[93mPackage %s is depended on by %s, cannot uninstall without --cascade"):format(dependency, packageName))
            failure = true
          end
        end
      end
    end
  end
  if doJumpBack then
    goto JUMPBACK
    -- IT'S NOT SPAGHETTI SHUT UP SHUT UP SHU
  end
end
-- TODO: Add checks for the other commands

if #packages == 0 then
  print("\27[93mNo packages selected.\n\27[0mExiting.")
  return
end
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
    if parsed.s or parsed.source then
      source = parsed.s or parsed.source
    else
      source = registry[package]
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
elseif command == "remove" then

end
print("Operation completed successfully.")

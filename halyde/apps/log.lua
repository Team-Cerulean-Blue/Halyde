local log = require("log")
local shell = require("shell")
local fs = require("filesystem")

local args = {...}
if #args == 0 then
    shell.run("help log")
    return
end

local function viewlog(logname)
    local logpath = "/halyde/logs/" .. logname .. ".log"
    if not fs.exists(logpath) then
        print("Log not found.")
        return
    end
    local handle = fs.open(logpath)
    local entry = ""
    local byte
    while true do
        byte = handle:read(1)
        if not byte then return end
        if string.byte(byte) == 0x0a then --check for newline
            if string.byte(string.sub(entry, -1, -1)) == 0x0d then --failsafe in case line endings are CRLF
                entry = string.sub(entry, 1, -2)
            else
                entry = string.sub(entry, 1, -1)
            end
            if entry:sub(1, 4) == "WARN" then
                print("\x1b[93m" .. entry)
            elseif entry:sub(1, 5) == "ERROR" then
                print("\x1b[91m" .. entry)
            else
                print(entry)
            end
            entry = ""
        else
            entry = entry .. byte
        end
    end
end

local function listlogs()
    local files = fs.list("/halyde/logs")
    local logs = {}
    local j = 1
    for i in ipairs(files) do
        if not(string.sub(files[i], -1, -1) == "/") and string.sub(files[i], -4, -1) == ".log" then
            logs[j] = string.sub(files[i], 1, -5)
            j = j + 1
        end
    end
    return logs
end

local function listlogs2()
    local logs = listlogs()
    print("Found \x1b[93m" .. #logs .. "\x1b[0m logs.")
    for i in ipairs(logs) do
        if i == #logs then
            print("\x1b[93m└ \x1b[0m" .. logs[i] .. "\x1b[90m.log")
        else
            print("\x1b[93m├ \x1b[0m" .. logs[i] .. "\x1b[90m.log")
        end
    end
end

local function clearlog(logname)
    if logname then
        local logpath = "/halyde/logs/" .. logname .. ".log"
        if not fs.exists(logpath) then
            print("Log file not found.")
            return
        end
        local success, err = fs.remove(logpath)
        if not success then
            print("Failed to remove log file: " .. err)
            return
        end
    else
        local logs = listlogs()
        local j
        for i in ipairs(logs) do
            local success, err = fs.remove("/halyde/logs/" .. logs[i] .. ".log")
            if not success then
                print("Failed to remove log " .. logs[i] .. ": " .. err)
                print("Removed" .. i - 1 .. "logs.")
                return
            end
            j = i
        end
        print("Removed " .. j .. " log(s) successfully.")
    end
end

if args[1] == "view" then
    viewlog(args[2])
elseif args[1] == "list" then
    listlogs2()
elseif args[1] == "clear" then
    clearlog(args[2])
elseif args[1] == "info" or args[1] == "warn" or args[1] == "error" then
    local loglevel = args[1]
    local logname = args[2]
    local logtext = args[3]
    for i = 4, #args do
        logtext = logtext .. " " .. args[i]
    end
    log[logname][loglevel](logtext)
end
local component = require("component")
local gpu = component.gpu
local shell = require("shell")

local args = {...}

local maxX, maxY = gpu.maxResolution()
local curX, curY = gpu.getResolution()

local function setRes()
    if not(args[1] == "-x" or args[1] == "-y") then
        print("\x1b[91mUnknown argument. \x1b[39mTry running \x1b[92m\"help res\"")
        return
    end

    local lastarg = ""
    local x, y
    for i = 1, 3, 2 do
        if args[i] == "-x" then
            if lastarg ~= "x" then
                x = tonumber(args[i + 1])
                lastarg = "x"
            else
                print("\x1b[91mValue \"x\" was set more than once. \x1b[39mTry running \x1b[92m\"help res\"")
                return
            end
        elseif args[i] == "-y" then
            if lastarg ~= "y" then
                y = tonumber(args[i + 1])
                lastarg = "y"
            else
                print("\x1b[91mValue \"y\" was set more than once. \x1b[39mTry running \x1b[92m\"help res\"")
                return
            end
        end
    end

    if x then
        if x > maxX then
            print("\x1b[91mGPU does not support x higher than " .. maxX)
            return
        end
    end
    if y then
        if y > maxY then
            print("\x1b[91mGPU does not support y higher than " .. maxY)
            return
        end
    end

    if x and not(y) then
        gpu.setResolution(x, curY)
        print("Successfully set X resolution from \x1b[93m" .. curX .. "\x1b[39m to \x1b[92m" .. x .. "\x1b[39m.")
        return
    elseif not(x) and y then
        gpu.setResolution(curX, y)
        print("Successfully set Y resolution from \x1b[93m" .. curY .. "\x1b[39m to \x1b[92m" .. y .. "\x1b[39m.")
        return
    else
        gpu.setResolution(x, y)
        print("Successfully set resolution from \x1b[93m" .. curX .. "x" .. curY .. "\x1b[39m to \x1b[92m" .. x .. "x" .. y .. "\x1b[39m.")
        return
    end
end

local function getRes(val)
    if val == "x" then
        print("Current X resolution: \x1b[93m" .. curX)
        print("Maximum supported X resolution: \x1b[92m" .. maxX)
    elseif val == "y" then
        print("Current Y resolution: \x1b[93m" .. curY)
        print("Maximum supported Y resolution: \x1b[92m" .. maxY)
    else
        print("Current resolution: \x1b[93m" .. curX .. "x" .. curY)
        print("Maximum supported resolution: \x1b[92m" .. maxX .. "x" .. maxY)
    end
end

if #args == 0 then
    getRes()
    return
end

if not(#args == 1) then
    setRes()
    return
end

local axis = args[1]
if axis == "-x" then
    getRes("x")
elseif axis == "-y" then
    getRes("y")
else
    print("\x1b[91mUnknown argument. \x1b[39mTry running \x1b[92m\"help res\"")
end
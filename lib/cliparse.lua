local cliParse = {}
local cliParseConfig

function cliParse.config(config)
  -- Check if config is valid
  checkArg(1, config, "table")
  for flagName, argCount in pairs(config) do
    if type(flagName) ~= "string" then
      error("Flag name " .. tostring(flagName) .. " must be a string")
    end
    if type(argCount) == "table" then -- Min and max arg count specified
      if type(argCount[1]) ~= "number" then
        error("Min args for flag " .. flagName .. " must be a number")
      end
      if argCount[1] < 0 then
        error("Min args for flag " .. flagName .. " must not be lower than 0")
      end
      if type(argCount[2]) ~= "number" then
        error("Max args for flag " .. flagName .. " must be a number")
      end
      if argCount[2] < 0 then
        error("Max args for flag " .. flagName .. " must not be lower than 0")
      end
      if argCount[2] < argCount[1] then
        error("Max args for flag " .. flagName .. " must be more than or equal to min args")
      end
    elseif type(argCount) == "number" then -- Required arg count specified
      if argCount < 0 then
        error("Required args for flag " .. flagName .. " must not be lower than 0")
      end
    else
      error("Arg count for flag " .. flagName .. " must be either a table of 2 numbers or a number")
    end
    -- Config is all good, set it
    cliParseConfig = config
  end
end

function cliParse.parse(...)
  local args = { ... }
  local returnTable = { ["flags"] = {}, ["args"] = {} } -- This will be filled out and returned in the end

  for i = 1, #args do                                   -- This is used instead of pairs() so that the code can skip ahead when it finds arguments instead of flags by just incrementing i
    local flagList = {}
    if args[i]:sub(1, 2) == "--" then                   -- Long flag
      flagList = { args[i]:sub(3) }
    elseif args[i]:sub(1, 1) == "-" then                -- Short flag(s)
      for i2 = 2, #args[i] do                           -- i is 2 to account for the - character at the start
        table.insert(flagList, args[i]:sub(i2, i2))
      end
    end
    for flagIndex, flag in ipairs(flagList) do -- Yes, this has to be in the argument loop for the skipahead to work.
      local flagConfig = cliParseConfig[flag]
      if flagConfig then                       -- This is a real flag
        returnTable.flags[flag] = {}
        if type(flagConfig) == "table" then
          if flagIndex ~= #flagList then -- This flag is in a chain and it's not the last one
            if flagConfig[1] ~= 0 then
              return false, "Flag " .. flag .. " expects at least " .. flagConfig[1] .. " arguments, got 0"
            end
          else
            for i2 = 1, flagConfig[1] do                            -- Iterate through the items AFTER the flags to find the minimum arguments
              if args[i + i2]:sub(1, 1) ~= "-" then                 -- This checks for both long and short flags
                table.insert(returnTable.flags[flag], args[i + i2]) -- Insert the argument found into the return table
              else
                return false, "Flag " .. flag .. " expects at least " .. flagConfig[1] .. " arguments, got " .. i2
              end
            end
            i = i + flagConfig[1]
            local i2IncrementAmount                                 -- See line 71 and 76
            for i2 = 1, flagConfig[2] - flagConfig[1] do            -- Now search for the max args
              if args[i + i2]:sub(1, 1) ~= "-" then                 -- This checks for both long and short flags
                table.insert(returnTable.flags[flag], args[i + i2]) -- Insert the argument found into the return table
              else
                i2IncrementAmount = i2 - 1
                -- Since the current argument is NOT a valid one, decrement by 1 to return to the last valid one (this is important when adding i2 to i)
                break
              end
            end
            i = i + (i2IncrementAmount or flagConfig[2])
          end
        else                             -- Flag required args are a single number
          if flagIndex ~= #flagList then -- This flag is in a chain and it's not the last one
            if flagConfig ~= 0 then
              return false, "Flag " .. flag .. " expects " .. flagConfig .. " arguments, got 0"
            end
          else
            for i2 = 1, flagConfig do                               -- Now search for the max args
              if args[i + i2]:sub(1, 1) ~= "-" then                 -- This checks for both long and short flags
                table.insert(returnTable.flags[flag], args[i + i2]) -- Insert the argument found into the return table
              else
                return false, "Flag " .. flag .. " expects " .. flagConfig[1] .. " arguments, got " .. i2
              end
            end
            i = i + flagConfig
          end
        end
      else
        return false, "Unexpected flag: " .. flag
      end
    end
  end

  for _, arg in pairs(args) do
    local foundArg = false
    for _, flag in pairs(returnTable.flags) do              -- A loop in a loop... Peak efficiency
      if table.find(flag, arg) or arg:sub(1, 1) == "-" then -- AAAND ANOTHER LOOP?!
        foundArg = true
        break
      end
    end
    if not foundArg then
      table.insert(returnTable.args, arg)
    end
  end

  return returnTable
end

return cliParse

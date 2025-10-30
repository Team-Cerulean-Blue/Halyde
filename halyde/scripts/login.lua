local fs = require("filesystem")
local json = require("json")

terminal.clear()

::retry::

local username = terminal.read({
  prefix = "Username: "
})

local handle, data, tmpdata = fs.open("/halyde/kernel/userreg.json"), "", nil
repeat
  tmpdata = handle:read(math.huge or math.maxinteger)
  data = data .. (tmpdata or "")
until not tmpdata
handle:close()

local userRegistry = json.decode(data)

local foundUser, uid = false, nil
for i, user in pairs(userRegistry) do
  if user.name == username then
    foundUser = true
    uid = i
    break
  end
end

if not foundUser then
  print("User does not exist.")
  goto retry
end

local password = terminal.read({
  prefix = "Password: ",
  censor = "*"
})

local shellPath = "/halyde/scripts/shell.lua" -- TODO: Add shell selection (perhaps in a config file or user prompt?)

local handle, data, tmpdata = fs.open(shellPath), "", nil
repeat
  tmpdata = handle:read(math.huge or math.maxinteger)
  data = data .. (tmpdata or "")
until not tmpdata
handle:close()

-- Prepare userland environment
local temporaryGlobals = _G
_G = nil -- This is so copying doesn't cause an infinite loop
local userland = table.copy(temporaryGlobals)
_G = temporaryGlobals
userland._G = userland

local result, errorMessage = user.addTask(assert(load(data, "=" .. shellPath, "t", userland)), "shell", uid, password)
if not result then
  print(errorMessage)
  goto retry
end

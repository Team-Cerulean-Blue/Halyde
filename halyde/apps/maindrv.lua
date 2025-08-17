local computer = require("computer")

if type(computer)~="table" then
  return print("\x1b[91mComputer library returned '"..type(computer).."' type\x1b[39m")
end

local address = computer.getBootAddress()
print(address)

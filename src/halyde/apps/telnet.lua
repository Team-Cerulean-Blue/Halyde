-- Despite the name it's not telnet
local component = require("component")
if not component.isAvailable("internet") then
  terminal.write("telnet: this program requires an internet card to run\n")
  return
end

local internet = component.internet
if not internet.isTcpEnabled() then
  terminal.write("telnet: TCP disabled\n")
  return
end

local arg = {...}
local host = arg[1]
local port = tonumber(arg[2])

local sock = internet.connect(host, port)

local connected = false
local err
for _ = 1, 5 do
  local ok
  ok, err = sock.finishConnect()
  if ok then
    connected = true
    break
  end
  coroutine.yield()
end
if not connected then
  print("telnet: " .. err)
  return
end

print(("connected to %s:%d"):format(host, port))

while true do
  local fromSocket = sock.read(math.maxinteger or math.huge)
  if fromSocket == nil then
    print("telnet: connection closed")
    sock.close()
    return
  end
  terminal.write(fromSocket)
  terminal.flush()
  local fromTerminal = terminal.read()
  if fromTerminal == "" then
    sock.close()
    return
  end
  while fromTerminal ~= "" do
    local nbytes, err = sock.write(fromTerminal .. "\r\n")
    if err then
      print("telnet: " .. err)
      return
    end
    fromTerminal = fromTerminal:sub(nbytes + 1)
  end
end

local computerlib = table.copy(computer)
local LLcomputer = table.copy(computer)

function computerlib.pullSignal(timeout)
  local startTime = LLcomputer.uptime()
  local result
  repeat
    result = {LLcomputer.pullSignal(0)}
    coroutine.yield()
  until result or timeout and LLcomputer.uptime() >= startTime + timeout
  return table.unpack(result)
end

return computerlib

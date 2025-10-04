local computer = require("computer")
local cliparse = require("cliparse")

cliparse.config({
  ["f"] = 1,
  ["frequency"] = 1,
  ["t"] = 1,
  ["time"] = 1,
})
local parsed, err = cliparse.parse(...)
if not parsed then
  return print("\x1b[91m" .. err)
end

local freq =
  tonumber(parsed.flags.f and parsed.flags.f[1] or parsed.flags.frequency and parsed.flags.frequency[1] or "440")
local time = tonumber(parsed.flags.t and parsed.flags.t[1] or parsed.flags.time and parsed.flags.time[1] or "0.1")

computer.beep(freq, time)

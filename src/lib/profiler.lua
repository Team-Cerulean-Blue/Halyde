local thing = _G._PUBLIC or _G
thing.__PROFILER_INSTANCE = thing.__PROFILER_INSTANCE or { timers = {} }
local timers = thing.__PROFILER_INSTANCE.timers
local profiler = {}

function profiler.start(label, overwrite)
  thing.__PROFILER_INSTANCE.lastadded = label
  timers[label] = timers[label] or {}
  if not timers[label].start or overwrite then
    timers[label].start = os.clock()
  end
  return function() timers[label].time = timers[label].time or os.clock() - timers[label].start end
end

function profiler.results()
  local _now = nil
  local function now()
    _now = _now or os.clock()
    return _now
  end
  local out = {}
  for label, t in pairs(timers) do
    table.insert(out, { label = label, time = t.time or now() - t.start })
  end
  table.sort(out, function(a, b) return a.time > b.time end)
  return out
end

function profiler.profile(label, func, ...)
  local stop = profiler.start(label)
  func(...)
  stop()
end

return profiler

-- TODO: make it somehow not depend on ESC s and ESC u
local profiler = require("profiler")
local PAL = {
  { fg = "\27[31m", bg = "\27[41m" },
  { fg = "\27[32m", bg = "\27[42m" },
  { fg = "\27[33m", bg = "\27[43m" },
  { fg = "\27[34m", bg = "\27[44m" },
  { fg = "\27[35m", bg = "\27[45m" },
  { fg = "\27[36m", bg = "\27[46m" },
  { fg = "\27[37m", bg = "\27[47m" }
}
local function pal(i) return PAL[((i - 1) % #PAL) + 1] end

local results = profiler.results()
if not results then
  print("No profiling data")
  return
end

local radius
local W = terminal.getResolution()
if (W == 160) then radius = 20
elseif (W == 80) then radius = 6
else radius = 0; PAL = {{fg = "", bg = ""}} end

local MIN_PC = math.min(3, 100 / (radius * 2))

local total = 0
for _, r in ipairs(results) do total = total + r.time end

local main = {}
local other = {}
local ot = 0
local on_ = 0
for _, r in ipairs(results) do
  if r.time / total * 100 >= MIN_PC then
    table.insert(main, r)
  else
    table.insert(other, r)
    ot = ot + r.time;
    on_ = on_ + 1
  end
end
if on_ then
  table.insert(main, { label = "other (" .. on_ .. ")", time = ot })
end

local START = -math.pi / 2
local slices = {}
local cur = START
for i, m in ipairs(main) do
  local sw = m.time / total * 2 * math.pi
  slices[i] = {
    label = m.label,
    time = m.time,
    pc = ("%.1f%%"):format(m.time / total * 100),
    color = pal(i),
    sa = cur,
    sw = sw
  }
  cur = cur + sw
end
if on_ then slices[#slices].color={fg = "\27[30m", bg = "\27[40m"} end

local ASP = 2
local cx = radius * ASP
local cy = radius

local function slice_at(sx, sy)
  local dy = sy - cy
  local dx = (sx - cx) / ASP
  if dx * dx + dy * dy > radius * radius then return nil end
  local a = math.atan2(dy, dx)
  if a < START then a = a + 2 * math.pi end
  for i, sl in ipairs(slices) do
    if a >= sl.sa and a < sl.sa + sl.sw then return i end
  end
  return #slices
end

local SUB = {
  { dx = -0.25, dy = -0.375 },
  { dx = -0.25, dy = -0.125 },
  { dx = -0.25, dy =  0.125 },
  { dx =  0.25, dy = -0.375 },
  { dx =  0.25, dy = -0.125 },
  { dx =  0.25, dy =  0.125 },
  { dx = -0.25, dy =  0.375 },
  { dx =  0.25, dy =  0.375 },
}

for y = 0, radius * 2 do
  local lx, rx = math.ceil(cx - radius * ASP), math.floor(cx + radius * ASP)

  terminal.write(("\27[%dC"):format(lx))
  for x = lx, rx do
    local c = {}
    local n = 0
    for k = 1, 8 do
      local s = slice_at(x + SUB[k].dx, y + SUB[k].dy)
      c[k] = s
      if s then n = n + 1 end
    end

    if n == 0 then
      terminal.write("\27[0m ")
    else
      local counts = {}
      local order = {}
      for k = 1, 8 do
        if c[k] then
          local key = c[k]
          if not counts[key] then
            counts[key] = 0
            table.insert(order, key)
          end
          counts[key] = counts[key] + 1
        end
      end
      table.sort(order, function(a, b) return counts[a] > counts[b] end)
      local dom = order[1]
      local sub = order[2]

      if n == 8 then
        terminal.write(slices[dom].color.bg)
        if sub == nil then
          terminal.write(" ")
        else
          local mask = 0
          for k = 1, 8 do
            if c[k] == sub then mask = mask + (1 << (k - 1)) end
          end
          terminal.write(slices[sub].color.fg)
          terminal.write(utf8.char(0x2800 + mask))
        end
      else
        local mask = 0
        for k = 1, 8 do
          if c[k] == dom then mask = mask + (1 << (k - 1)) end
        end
        terminal.write("\27[0m")
        terminal.write(slices[dom].color.fg)
        terminal.write(utf8.char(0x2800 + mask))
      end
    end
  end
  terminal.write('\n')
end

terminal.write("\27[" .. radius * 2 + 1 .. "A\27[s")
local function draw_text(col, row, s)
  terminal.write("\27[u\27[" .. col .. "C\27[" .. row - 1 .. "B" .. s)
end

terminal.write("\27[0m")
if radius == 0 then goto tier1gpu end
for _, sl in ipairs(slices) do
  local y = math.floor(cy + radius * 0.62 * math.sin(sl.sa + sl.sw / 2) + 0.5)

  local function in_slice(x, row)
    local a = math.atan2(row - cy, (x - cx) / ASP)
    if a < START then
      a = a + 2 * math.pi
    end
    return a >= sl.sa and a < sl.sa + sl.sw
  end
  local function centered_draw(row, text)
    local dy = row - cy
    local half_w = math.sqrt(radius * radius - dy * dy) * ASP
    local lx, rx = math.ceil(cx - half_w), math.floor(cx + half_w)
    while lx <= rx and not in_slice(lx, row) do
      lx = lx + 1
    end
    while rx >= lx and not in_slice(rx, row) do
      rx = rx - 1
    end
    local avail = rx - lx + 1
    if avail < 3 then
      return
    end
    local t = #text > avail and text:sub(1, avail - 3) .. "..." or text
    local start_x = lx + math.floor((avail - #t) / 2)
    draw_text(start_x, row, sl.color.bg .. t)
  end
  centered_draw(y, sl.label)
  centered_draw(y + 1, sl.pc)
end
::tier1gpu::

local max_w = 0
for _, sl in pairs(slices) do
  max_w = math.max(#sl.label + 1, max_w)
end
for _, sl in pairs(other) do
  max_w = math.max(#sl.label + 3, max_w)
end
local x = radius * 2 * ASP + 2
if radius == 0 then x = 0 end
local cw = W - x - 1
local suffix_w = 18
local max_lbl = math.max(4, cw - suffix_w)
terminal.write("\27[u\27[" .. x .. "C" .. ("\27[0m%" .. max_w .. "s  %9s   %6s"):format("label", "time", "share"))
terminal.write("\n")
for _, sl in ipairs(slices) do
  local lbl = sl.label
  if #lbl > max_lbl then
    lbl = sl.label:sub(1, max_lbl - 1) .. "…"
  end
  terminal.write("\n\27[" .. x .. "C" .. ("%s%" .. max_w .. "s\27[0m  %9.4fs  %6s"):format(sl.color.bg, lbl, sl.time, sl.pc))
end
for _, sl in ipairs(other) do
  local lbl = sl.label
  if #lbl > max_lbl - 2 then
    lbl = sl.label:sub(1, max_lbl - 3) .. "…"
  end
  terminal.write("\n\27[" .. x .. "C" .. ("%s%" .. max_w .. "s\27[0m  %9.4fs  %6s"):format(slices[#slices].color.bg, lbl, sl.time, ("%.1f%%"):format(sl.time / total * 100)))
end

if radius * 2 + 2 > #slices + #other then
  terminal.write("\27[" .. radius * 2 + 2 .. "B")
end
terminal.write("\n")

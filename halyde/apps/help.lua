local fs = require("filesystem")
local shell = require("shell")

local arg = ... or "default"
local what = arg

local aliases = shell.getAliases()
if aliases[what] then
  what = aliases[what]
end
local path = "/halyde/apps/helpdb/" .. what
if not fs.exists(path) then
  print("Could not find help file for: " .. arg .. ".")
  return
end
if path == "/halyde/apps/helpdb/default" then
  return shell.run("cat " .. path) -- smh
end
local handle = fs.open(path, "r")
local data = {
  command = "",
  usage = "",
  description = "",
  args = {},
  examples = {}
}

while true do
  local line = ""
  while true do
    local char = handle:read(1)
    if not char then
      if line == "" then
        line = nil
        break
      end
      break
    end
    if char == "\n" then
      break
    end
    if char == "\r" then
      local next_char = handle:read(1)
      if next_char and next_char == "\n" then
        break
      elseif next_char then
        local pos = file:seek("cur")
        if pos then
          file:seek("set", pos - 1)
        end
        break
      end
      break
    end
    line = line .. char
  end
  if line == nil then
    break
  end
  line = line:match("^%s*(.-)%s*$")
  if line then
    local key, value = line:match("^(%w+)%s+(.*)$")
    if not key then goto continue end
    if key:lower() == "command" then
      data.command = value
    end

    if key:lower() == "usage" then
      data.usage = value
    end

    if key:lower() == "description" then
      data.description = value
    end

    if key:lower():match("^arg%d+$") then
      local num = key:lower():match("^arg(%d+)$")
      if not data.args[tonumber(num)] then data.args[tonumber(num)] = {} end
      data.args[tonumber(num)].name = value
    end

    if key:lower():match("^arg%d+description$") then
      local num = key:lower():match("^arg(%d+)description$")
      if not data.args[tonumber(num)] then data.args[tonumber(num)] = {} end
      data.args[tonumber(num)].description = value
    end

    if key:lower():match("^arg%d+sub%d+$") then
      local main_num, sub_num = key:lower():match("^arg(%d+)sub(%d+)$")
      if main_num and sub_num then
        if not data.args[tonumber(main_num)] then data.args[tonumber(main_num)] = {} end
        if not data.args[tonumber(main_num)].subflags then data.args[tonumber(main_num)].subflags = {} end
        if not data.args[tonumber(main_num)].subflags[tonumber(sub_num)] then
          data.args[tonumber(main_num)].subflags[tonumber(sub_num)] = {}
        end
        data.args[tonumber(main_num)].subflags[tonumber(sub_num)].name = value
      end
    end

    if key:lower():match("^arg%d+sub%d+description$") then
      local main_num, sub_num = key:lower():match("^arg(%d+)sub(%d+)description$")
      if main_num and sub_num then
        if not data.args[tonumber(main_num)] then data.args[tonumber(main_num)] = {} end
        if not data.args[tonumber(main_num)].subflags then data.args[tonumber(main_num)].subflags = {} end
        if not data.args[tonumber(main_num)].subflags[tonumber(sub_num)] then
          data.args[tonumber(main_num)].subflags[tonumber(sub_num)] = {}
        end
        data.args[tonumber(main_num)].subflags[tonumber(sub_num)].description = value
      end
    end

    if key:lower():match("^example%d+$") then
      local num = key:lower():match("^example(%d+)$")
      if not data.examples[tonumber(num)] then data.examples[tonumber(num)] = {} end
      data.examples[tonumber(num)].name = value
    end

    if key:lower():match("^example%d+description$") then
      local num = key:lower():match("^example(%d+)description$")
      if not data.examples[tonumber(num)] then data.examples[tonumber(num)] = {} end
      data.examples[tonumber(num)].description = value
    end
    ::continue::
  end
end

handle:close()

--print(require("serialize")(data, "\t"))

-- Halyde terminal doesn't support bold (CSI 1 m) but who cares

if data.command then
  terminal.write("\27[1mUsage: \27[0m\n")
  terminal.write("  \27[96m" .. data.command)
  if data.usage then
    terminal.write("\27[93m " .. data.usage)
  end
  terminal.write("\27[0m\n\n")
end

local width, height = terminal.getResolution()

local function wrap_text(text, indent)
  if not text then return "" end
  local words = {}
  for word in text:gmatch("%S+") do
    table.insert(words, word)
  end

  local lines = {}
  local current_line = ""

  for i, word in ipairs(words) do
    if #current_line + #word + 1 <= width * 0.66 - indent then
      if current_line == "" then
        current_line = word
      else
        current_line = current_line .. " " .. word
      end
    else
      table.insert(lines, current_line)
      current_line = word
    end
  end
  if current_line ~= "" then
    table.insert(lines, current_line)
  end

  local result = {}
  for i, line in ipairs(lines) do
    if i == 1 then
      table.insert(result, line)
    else
      table.insert(result, string.rep(" ", indent) .. line)
    end
  end
  return table.concat(result, "\n")
end

if data.description then
  terminal.write("\27[1mDescription:\27[0m\n")
  terminal.write("  " .. wrap_text(data.description, 2))
  terminal.write("\n\n")
end

if #data.args > 0 then
  terminal.write("\27[1mArguments:\27[0m\n")
  local max_len = 0
  for _, flag in ipairs(data.args) do
    if flag.name then
      max_len = math.max(max_len, #flag.name)
    end
    for _, subf in ipairs(flag.subflags or {}) do
      if subf.name then
        max_len = math.max(max_len, #subf.name + 2)
      end
    end
  end

  for _, flag in ipairs(data.args) do
    terminal.write("  \27[93m" .. (flag.name or "") .. "\27[0m" .. string.rep(" ", max_len - (flag.name and #flag.name or 0) + 2) .. wrap_text(flag.description, 4 + max_len) .. "\n")
    for _, subf in ipairs(flag.subflags or {}) do
      terminal.write("    \27[92m" .. (subf.name or "") .. "\27[0m" .. string.rep(" ", max_len - (subf.name and #subf.name or 0)) .. wrap_text(subf.description, 4 + max_len) .. "\n")
    end
  end
  terminal.write("\n")
end

local function formatExampleName(name, utility)
  if not name then return name end

  local contains = false
  if name:find(utility, 1, true) then
    contains = true
  else
    for alias, cmd in pairs(aliases) do
      if cmd == utility and name:find(alias, 1, true) then
        contains = true
        break
      end
    end
  end

  if not contains then
    return "\27[92m" .. name
  end

  local formatted = name
  formatted = formatted:gsub("(" .. utility .. ")", "\27[96m%1\27[92m")
  for alias, cmd in pairs(aliases) do
    if cmd == utility then
      formatted = formatted:gsub("(" .. alias .. ")", "\27[96m%1\27[92m")
    end
  end

  return formatted
end

if #data.examples > 0 then
  terminal.write("\27[1mExamples:\27[0m\n")
  local max_len = 0
  for _, flag in ipairs(data.examples) do
    max_len = math.max(max_len, #flag.name)
  end

  for _, flag in ipairs(data.examples) do
    terminal.write("  " .. formatExampleName(flag.name, arg) .. "\27[0m" .. string.rep(" ", max_len - #flag.name + 2) .. wrap_text(flag.description, 4 + max_len) .. "\n")
  end
  terminal.write("\n")
end

local first = true
for k, v in pairs(aliases) do
  if v == arg then
    if first then
      terminal.write("\27[1mAliases:\27[0m\n  ")
    end
    terminal.write("\27[96m" .. k)
    if not first then
      terminal.write("\27[0m, ")
    end
    first = false
  end
end
if not first then
  terminal.writec(0xa)
end

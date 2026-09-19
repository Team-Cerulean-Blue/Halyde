local function _serialize(value, indent, level, visited)
  local currentIndent = indent and string.rep(indent, level) or ""
  local nextIndent = indent and string.rep(indent, level + 1) or ""
  local sep = indent and "\n" or " "
  local t = type(value)
  if t == "nil" then return "nil" end
  if t == "string" then return string.format("%q", value) end
  if t == "number" then
    if value ~= value then return "0/0" end
    if value ==  math.huge then return "math.huge"  end
    if value == -math.huge then return "-math.huge" end
    return tostring(value)
  end
  if t == "boolean" then return tostring(value) end
  if t == "table" then
    if visited[value] then return "..." end
    visited[value] = true
    local items = {}
    local arrayCount = 0
    for i = 1, #value do
      if value[i] ~= nil then arrayCount = i else break end
    end
    for i = 1, arrayCount do
      table.insert(items, nextIndent .. _serialize(value[i], indent, level + 1, visited))
    end
    for k, v in pairs(value) do
      if type(k) ~= "number" or k < 1 or k > arrayCount then
        local keyStr
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
          keyStr = k
        else
          keyStr = "[" .. _serialize(k, indent, level + 1, visited) .. "]"
        end
        table.insert(items, nextIndent .. keyStr .. " = " .. _serialize(v, indent, level + 1, visited))
      end
    end
    visited[value] = nil
    if #items == 0 then return "{}" end
    return "{" .. sep .. table.concat(items, "," .. sep) .. sep .. currentIndent .. "}"
  end
  return tostring(value)
end

function serialize(value, indent)
  return _serialize(value, indent, 0, {})
end

return serialize

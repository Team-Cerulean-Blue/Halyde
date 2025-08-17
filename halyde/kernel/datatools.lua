local conversionTables = {
  ["bytes"] = {
    ["B"] = 1,
    ["KB"] = 1000,
    ["MB"] = 1000000,
    ["GB"] = 1000000000
  }, ["bibytes"] = {
    ["B"] = 1,
    ["KiB"] = 1024,
    ["MiB"] = 1048576,
    ["GiB"] = 1073741824
  }
}

function table.find(tab, item)
  for k, v in pairs(tab) do
    if v == item then
      return k
    end
  end
end

function table.copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[table.copy(orig_key)] = table.copy(orig_value)
    end
    setmetatable(copy, table.copy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function convert(amount, fromUnit, toUnit)
  for _, convTable in pairs(conversionTables) do
    if convTable[toUnit] then
      return amount / convTable[toUnit] * convTable[fromUnit]
    end
  end
  return false, "unit does not exist"
end

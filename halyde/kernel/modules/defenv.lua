local module = {}

module.dependencies = {"terminal"}

function module.check()
  return true -- This module should always be loaded
end

function module.init()
  local publicTable = {
    "print",
    "require",
    "_VERSION",
    "_OSVERSION",
    "assert",
    "error",
    "getmetatable",
    "ipairs",
    "load",
    "next",
    "pairs",
    "pcall",
    "rawequal",
    "rawget",
    "rawlen",
    "rawset",
    "select",
    "setmetatable",
    "tonumber",
    "tostring",
    "type",
    "xpcall",
    "bit32",
    "coroutine",
    "debug",
    "math",
    "os",
    "string",
    "table",
    "checkArg",
    "utf8",
    "convert"
  }
  for _, value in ipairs(publicTable) do
    _G._PUBLIC[value] = table.copy(_G[value])
  end
end

function module.exit()
  _G._PUBLIC = nil
end

return module

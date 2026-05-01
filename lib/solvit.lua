-- local db = require("solvitdb")
local db = {}
local fs = require("filesystem")
local json = require("json")
local dbpath = "/ag2/testdb.json"
function db.create()
  local handle = fs.open(dbpath,"w")
  handle:write("{}")
  handle:close()
end
function db.readJSON()
  local handle = fs.open(dbpath,"r")
  local content = ""
  while true do
    local s = handle:read()
    if not s then break end
    content=content..s
  end
  handle:close()
  return content
end
function db.get(pack)
  local dbc = json.decode(db.readJSON())
  return dbc[pack]
end
function db.set(pack,info)
  local dbc = json.decode(db.readJSON())
  dbc[pack]=info
  local handle = fs.open(dbpath,"w")
  handle:write(json.encode(dbc))
  handle:close()
end
function db.remove(pack)
  local dbc = json.decode(db.readJSON())
  dbc[pack]=nil
  local handle = fs.open(dbpath,"w")
  handle:write(json.encode(dbc))
  handle:close()
end

local avs = {}
function avs.splitSingular(s)
  local result = {}
  for str in string.gmatch(s, "([^.]+)") do
    table.insert(result,tonumber(str) or -1)
  end
  return result
end

function avs.parse(pack)
  if not string.find(pack,"=") then
    return {pack}
  end
  local idx=pack:find("=")
  local name=pack:sub(1,idx-1)
  local verstr=pack:sub(idx+1)
  if string.find(verstr,"-") then
    idx=verstr:find("-")
    verstr={verstr:sub(1,idx-1),verstr:sub(idx+1)}
  else
    verstr={verstr}
  end
  for i=1,#verstr do
    verstr[i]=avs.splitSingular(verstr[i])
  end
  if #verstr>1 then
    for i=1,3 do
      verstr[1][i]=math.max(verstr[1][i],0)
    end
  end
  return {name,verstr}
end

function avs.serializeSingle(ver)
  local ver2 = table.copy(ver)
  for i=1,3 do
    if ver2[i]==-1 then
      ver2[i]="*"
    else
      ver2[i]=tostring(ver2[i])
    end
  end
  return ver2[1].."."..ver2[2].."."..ver2[3]
end

function avs.serializeVersion(ver)
  out=""
  for i=1,#ver do
    out=out..avs.serializeSingle(ver[i])
    if i~=#ver then
      out=out.."-"
    end
  end
  return out
end

function avs.serializePack(pack)
  if #pack==1 then
    return pack[1]
  end
  return pack[1].."="..avs.serializeVersion(pack[2])
end

function avs.singleGreater(ver1,ver2)
  for i=1,3 do
    if ver1[i]~=ver2[i] then
      if ver1[i]==-1 or ver1[i]>ver2[i] then
        return true
      end
      if ver2[i]==-1 or ver2[i]>ver1[i] then
        return false
      end
    end
  end
  return false
end

function avs.singleLesser(ver1,ver2)
  return avs.singleGreater(ver2,ver1)
end

function avs.singleMin(ver1,ver2)
  return avs.singleLesser(ver1,ver2) and ver1 or ver2
end

function avs.singleMax(ver1,ver2)
  return avs.singleGreater(ver1,ver2) and ver1 or ver2
end

function avs.compatibleRange(vers)
  for i=1,#vers do
    if type(vers[i])=="string" then vers[i]=avs.parse(vers[i])[2] end
    if #vers[i]==1 then vers[i]={vers[i][1],vers[i][1]} end
  end
  local range = vers[1]
  for i=2,#vers do
    range[1]=avs.singleMax(range[1],vers[i][1])
    range[2]=avs.singleMin(range[2],vers[i][2])
  end
  if avs.singleGreater(range[1],range[2]) then
    return nil
  end
  return range
end

local function startTransaction()
  if not fs.exists(dbpath) then
    db.create()
  end

  local packInfo = {}
  local installPacks = {}
  local transaction = {}
  function transaction.install(name)
    table.insert(installPacks,avs.parse(name))
  end
  function transaction.remove(name)
    -- TODO: implement removing packages
  end
  function transaction.addInfo(name,info)
    packInfo[name]=info
  end
  function transaction.finalize()
    local ins = table.copy(installPacks)

    local foundDeps=false
    local i=0
    while i<=#ins do
      -- TODO: continue here
    end

    return {install=ins}

    -- return "true, {["install"] = {"dep1", "package1", "package2"}, ["remove"] = {"package3"}}" on success
    -- return "false, {"dep1"}" when not enough data
    -- return "false, "[verbose string]"" when conflict found
    -- TODO: handle dependencies
    -- TODO: handle same constant AVS
    -- TODO: handle different constant AVS conflict
    -- TODO: handle same range AVS
    -- TODO: handle different intercompatible 1.*.* range AVS
    -- TODO: handle different incompatible 1.*.* range AVS
    -- TODO: handle different intercompatible 1.*.*-2.*.* range AVS
    -- TODO: handle different incompatible 1.*.*-2.*.* range AVS
    -- TODO: handle conflicts from package info
    -- TODO: handle reverse conflicts from another package's info
  end
  function transaction.resolveConflict()
    -- :whymustisuffer:
    -- TODO: be able to resolve conflicts
  end
  function transaction.store()
    -- TODO: store to database
    -- TODO: add reverse dependencies
  end
  return transaction
end

return { avs=avs,startTransaction=startTransaction }

local db = {}
local json = require("json")
local fs = require("filesystem")
function db.init()

end
function db.get(pack)

end
function db.set(pack,info)

end
function db.remove(pack)

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
  -- TODO: load from database

  local packInfo = {}
  local installPacks = {}
  local transaction = {}
  function transaction.install(name)
    table.insert(installPacks,avs.parse(name))
  end
  function transaction.remove(name)
    -- TODO: add reverse dependencies to database
    -- TODO: add reverse conflicts to database
    -- TODO: implement removing packages
  end
  function transaction.addInfo(name,info)

  end
  function transaction.finalize()
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
  end
  function transaction.store()
    -- TODO: store to database
  end
  return transaction
end

return { avs=avs,startTransaction=startTransaction }

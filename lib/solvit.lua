local defaultDBPath = "/ag2/testdb.json"

local fs = require("filesystem")
-- local db = require("solvitdb")
local db = {}
local json = require("json")
function db.create(dbpath)
  local handle = fs.open(dbpath,"w")
  handle:write("{}")
  handle:close()
end
function db.readJSON(dbpath)
  local handle = fs.open(dbpath,"r")
  local content = ""
  while true do
    local s = handle:read(math.huge or math.maxinteger)
    if not s then break end
    content=content..s
  end
  handle:close()
  return content
end
function db.get(dbpath,pack)
  local dbc = json.decode(db.readJSON(dbpath))
  return dbc[pack]
end
function db.set(dbpath,pack,info)
  local dbc = json.decode(db.readJSON(dbpath))
  dbc[pack]=info
  local handle = fs.open(dbpath,"w")
  handle:write(json.encode(dbc))
  handle:close()
end
function db.remove(dbpath,pack)
  local dbc = json.decode(db.readJSON(dbpath))
  dbc[pack]=nil
  local handle = fs.open(dbpath,"w")
  handle:write(json.encode(dbc))
  handle:close()
end
function db.list(dbpath,pack)
  local dbc = json.decode(db.readJSON(dbpath))
  local keys = {}
  for i,_ in pairs(dbc) do
    table.insert(keys,i)
  end
  return ipairs(keys)
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
  local singles = {}
  for i=1,#ver do
    table.insert(singles,avs.serializeSingle(ver[i]))
  end
  if singles[1]==singles[2] then
    singles={singles[1]}
  end
  local out=""
  for i=1,#singles do
    out=out..singles[i]
    if i~=#singles then
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

local function packageInArray(pack,arr)
  for i=1,#arr do
    if arr[i][1]==pack[1] then -- TODO: check for compatible package version
      return true
    end
  end
  return false
end

local function removeFromArray(el,arr)
  for i=1,#arr do
    if arr[i]==el then
      table.remove(arr,i)
      return i
    end
  end
end

local function startTransaction(dbpath)
  dbpath = dbpath or defaultDBPath
  if not fs.exists(dbpath) then
    db.create(dbpath)
  end

  local installIncomplete = false
  local removeIncomplete = false

  local packInfo = {}
  local ins = {}
  local rem = {}
  local transaction = {}
  function transaction.install(name)
    table.insert(ins,avs.parse(name))
    installIncomplete = true
  end
  function transaction.remove(name)
    table.insert(rem,avs.parse(name))
    removeIncomplete = true
  end
  function transaction.autoRemove()
  end
  function transaction.update(name)
  end
  function transaction.updateAll(name)
  end
  function transaction.addInfo(name,info)
    if not info.type then info.type="package" end
    packInfo[name]=info
    -- print(require("serialize").table(packInfo))
  end

  local function getPackInfo(pack)
    return packInfo[avs.serializePack(pack)]
  end
  local function finalizeInstall(settings)
    -- find missing package information
    local missing = {}
    for i=1,#ins do
      if getPackInfo(ins[i])==nil then
        table.insert(missing,avs.serializePack(ins[i]))
      end
    end
    if #missing>0 then
      return false,missing
    end
    -- find dependencies
    installIncomplete=false
    local i=1
    while i<=#ins do
      local deps = getPackInfo(ins[i]).dependencies
      if deps and #deps>=1 then
        for j=1,#deps do
          local dep = avs.parse(deps[j])
          if (not packageInArray(dep,ins)) and type(db.get(dbpath,dep[1]))=="nil" then
            installIncomplete=true
            table.insert(ins,j,dep)
          end
        end
        i=i+#deps
      end
      i=i+1
    end
  end
  local function finalizeRemove(settings)
    removeIncomplete=false
    -- filter to only have packages in the database
    local i=1
    while i<=#rem do
      local dat = db.get(dbpath,rem[i][1])
      if not dat then
        table.remove(rem,i)
      else
        packInfo[avs.serializePack(rem[i])]=dat
        i=i+1
      end
    end
    -- get package info from database
    for i=1,#rem do
      if not getPackInfo(rem[i]) then
        packInfo[avs.serializePack(rem[i])]=db.get(rem[i][1])
      end
    end
    -- find if the main package is reverse dependant to another
    i=1
    while i<=#rem do
      local dat = getPackInfo(rem[i])
      if dat.reverseDependencies and #dat.reverseDependencies>0 then
        for _,dep in ipairs(dat.reverseDependencies) do
          if not packageInArray({dep},rem) then
            if settings.cascade then
              table.insert(rem,1,{dep})
              i=i+1
            else
              return false, "Package "..rem[i][1].." is a dependency of "..dep
            end
          end
        end
      end
      i=i+1
    end
    -- look for dependencies if settings.autoremove is on
    if settings.autoremove then
      i=1
      while i<=#rem do
        local deps = getPackInfo(rem[i]).dependencies
        if deps and #deps>=1 then
          for j=1,#deps do
            local dep = avs.parse(deps[j])
            local depdat = packInfo[deps[j]]
            if not depdat then
              depdat = db.get(dbpath,dep[1])
              packInfo[deps[j]]=depdat
            end
            if (not packageInArray(dep,rem)) and type(db.get(dbpath,dep[1]))~="nil" and (#depdat.reverseDependencies==1 and depdat.reverseDependencies[1]==rem[i][1]) then
              removeIncomplete=true
              table.insert(rem,j,dep)
            end
          end
          i=i+#deps
        end
        i=i+1
      end
    end
  end
  function transaction.finalize(settings)
    settings = settings or {}

    while installIncomplete or removeIncomplete do
      while installIncomplete do
        local out = {finalizeInstall(settings)}
        if out[1]==false then return table.unpack(out) end
      end
      while removeIncomplete do
        local out = {finalizeRemove(settings)}
        if out[1]==false then return table.unpack(out) end
      end
    end

    local install = {}
    local remove = {}
    for i=1,#ins do
      table.insert(install,avs.serializePack(ins[i]))
    end
    for i=1,#rem do
      table.insert(remove,avs.serializePack(rem[i]))
    end
    return true, {install=install,remove=remove}

    -- return "true, {["install"] = {"dep1", "package1", "package2"}, ["remove"] = {"package3"}}" on success
    -- return "false, {"dep1"}" when not enough data
    -- return "false, "[verbose string]"" when conflict found
    -- TODO: handle different constant AVS conflict (package1->dep1=1.0.0 + package2->dep1=1.2.3 where both are uninstalled)
    -- TODO: handle different constant AVS conflict (package1->dep1=1.0.0 + package2->dep1=1.2.3 where package2 is on db)
    -- TODO: handle same range AVS
    -- TODO: handle different intercompatible 1.*.* range AVS
    -- TODO: handle different incompatible 1.*.* range AVS
    -- TODO: handle different intercompatible 1.*.*-2.*.* range AVS
    -- TODO: handle different incompatible 1.*.*-2.*.* range AVS
    -- TODO: handle conflicts from package info
    -- TODO: handle reverse conflicts from another package's info
    -- TODO: handle automatic conflict resolving
    -- TODO: handle update of a single package with no dependencies
    -- TODO: handle update of a single package with dependencies that don't need updating
    -- TODO: handle update of a single package with dependencies that need updating
    -- TODO: handle update of a single package that has a set dependency version changed
    -- TODO: handle updating all packages in the database
    -- TODO: handle installing virtual packages and store this vpack info to database
    -- TODO: handle removing virtual packages from database info
    -- TODO: handle installing groups and store this group info to database
    -- TODO: handle removing groups and store this group info to database
  end
  local function storeInstall()
    -- directly set
    for _,pack in ipairs(ins) do
      if getPackInfo(pack) then
        local info = table.copy(getPackInfo(pack))
        if pack[2] then
          info.version=avs.serializeVersion(pack[2])
        else
          info.version=info.latestVersion or info.version
        end
        db.set(dbpath,pack[1],info)
      end
    end
    -- set reverse dependencies
    for _,pack in pairs(ins) do
      local i = avs.serializePack(pack)
      local v = packInfo[i]
      if v and v.dependencies then
        for _,dep in ipairs(v.dependencies) do
          local depname = avs.parse(dep)[1]
          local dat = db.get(dbpath,depname)
          if not dat then goto continue end
          if type(dat.reverseDependencies)~="table" then
            dat.reverseDependencies={}
          end
          table.insert(dat.reverseDependencies,pack[1])
          db.set(dbpath,depname,dat)
          ::continue::
        end
      end
    end
  end
  local function storeRemove()
    -- directly remove
    for _,pack in ipairs(rem) do
      db.remove(dbpath,pack[1])
    end
    -- remove reverse dependencies
    for _,pack in ipairs(rem) do
      local pdat = getPackInfo(pack)
      if not pdat.dependencies then goto continue end
      for _,dep in ipairs(pdat.dependencies) do
        local depname = avs.parse(dep)[1]
        local dat = db.get(dbpath,depname)
        if dat.reverseDependencies then
          removeFromArray(pack[1],dat.reverseDependencies)
        end
        db.set(dbpath,depname,dat)
      end
      ::continue::
    end
  end
  function transaction.store()
    if #ins>0 then
      storeInstall()
    end
    if #rem>0 then
      storeRemove()
    end
  end
  return transaction
end

return { avs=avs,startTransaction=startTransaction }

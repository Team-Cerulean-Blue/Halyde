local module = {}

function module.check()
  return true -- IPC should always be loaded
end

function module.init()
  _G.ipc = {}
  _G.ipc.shared = {}
  _PUBLIC.ipc = {}

  function _PUBLIC.ipc.shareWithAll()
    local shareTable = {}
    setmetatable(shareTable, {["__newindex"] = function(_, key, value)
      local currentPID = _PUBLIC.tsched.getCurrentTask().id
      if not _G.ipc.shared[currentPID] then
        _G.ipc.shared[currentPID] = {} -- TODO: Add some kind of cleanup routine since these IPC shares can just keep piling up
      end
      local globalTable
      for _, tab in pairs(_G.ipc.shared[currentPID]) do
        if tab.sharedWith == "all" then
          globalTable = tab
        end
      end
      if not globalTable then
        globalTable = {["sharedWith"] = "all"}
        table.insert(_G.ipc.shared[currentPID], globalTable)
      end
      if not globalTable.vars then
        globalTable.vars = {}
      end
      globalTable.vars[key] = value
    end, ["__index"] = function(_, key)
      local currentPID = _PUBLIC.tsched.getCurrentTask().id
      if not _G.ipc.shared[currentPID] then
        return nil
      end
      local globalTable
      for _, tab in pairs(_G.ipc.shared[currentPID]) do
        if tab.sharedWith == "all" then
          globalTable = tab
        end
      end
      if not globalTable then
        return nil
      end
      if not globalTable.vars then
        return nil
      end
      return globalTable.vars[key]
    end,["__pairs"]=function()
      if not _G.ipc.shared[currentPID] then
        return pairs({})
      end
      local globalTable
      for _, tab in pairs(_G.ipc.shared[currentPID]) do
        if tab.sharedWith == pid then
          globalTable = tab
        end
      end
      if not globalTable then
        return pairs({})
      end
      if not globalTable.vars then
        return pairs({})
      end

      return pairs(table.copy(globalTable.vars))
    end})
    return shareTable
  end

  function _PUBLIC.ipc.shareWith(pid)
    checkArg(1, pid, "number")
    local shareTable = {}
    setmetatable(shareTable, {["__newindex"] = function(_, key, value)
      local currentPID = _PUBLIC.tsched.getCurrentTask().id
      if not _G.ipc.shared[currentPID] then
        _G.ipc.shared[currentPID] = {} -- TODO: Add some kind of cleanup routine since these IPC shares can just keep piling up
      end
      local globalTable
      for _, tab in pairs(_G.ipc.shared[currentPID]) do
        if tab.sharedWith == "all" then
          globalTable = tab
        end
      end
      if not globalTable then
        globalTable = {["sharedWith"] = pid}
        table.insert(_G.ipc.shared[currentPID], globalTable)
      end
      if not globalTable.vars then
        globalTable.vars = {}
      end
      globalTable.vars[key] = value
    end, ["__index"] = function(_, key)
      print(_G.ipc.shared)

      local currentPID = _PUBLIC.tsched.getCurrentTask().id
      if not _G.ipc.shared[currentPID] then
        return nil
      end
      local globalTable
      for _, tab in pairs(_G.ipc.shared[currentPID]) do
        if tab.sharedWith == pid then
          globalTable = tab
        end
      end
      if not globalTable then
        return nil
      end
      if not globalTable.vars then
        return nil
      end
      return globalTable.vars[key]
    end,["__pairs"]=function()
      if not _G.ipc.shared[currentPID] then
        return pairs({})
      end
      local globalTable
      for _, tab in pairs(_G.ipc.shared[currentPID]) do
        if tab.sharedWith == pid then
          globalTable = tab
        end
      end
      if not globalTable then
        return pairs({})
      end
      if not globalTable.vars then
        return pairs({})
      end

      return pairs(table.copy(globalTable.vars))
    end})

    -- check if the reverse is also available
    --[[ if not _G.ipc.shared[pid] then
      _G.ipc.shared[pid]={}
    end
    for _, tab in pairs(_G.ipc.shared[pid]) do
      if tab.sharedWith == currentPID then
        return -- it's already added
      end
    end
    local reverseTable = {}
    reverseTable.vars = globalTable.vars
    reverseTable.sharedWith = currentPID
    table.insert(_G.ipc.shared[pid],reverseTable) ]]

    return shareTable
  end

  _PUBLIC.ipc.shared = {}
  setmetatable(_PUBLIC.ipc.shared, {["__index"] = function(_, pid)
    local currentPID = _PUBLIC.tsched.getCurrentTask().id
    local returnTable = {}
    for _, shareTable in pairs(ipc.shared[pid] or {}) do
      if shareTable.sharedWith == currentPID then
        for key, value in pairs(shareTable.vars) do
          returnTable[key] = table.copy(value)
        end
      elseif shareTable.sharedWith == "all" then
        for key, value in pairs(shareTable.vars) do
          if not returnTable[key] then
            returnTable[key] = table.copy(value)
          end
        end
      end
    end
    return returnTable
  end,["__pairs"]=function()
    local ftbl = {}
    for i in pairs(_G.ipc.shared) do
      ftbl[i]=_PUBLIC.ipc.shared[i]
    end
    return pairs(ftbl)
  end})
end

function module.exit()
  _G.ipc = nil
  _PUBLIC.ipc = nil
end

return module

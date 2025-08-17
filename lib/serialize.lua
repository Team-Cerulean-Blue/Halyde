local serialize = {}

function serialize.string(str)
  return '"'..str:gsub("[%z\1-\31\34\92\127-\159]",function(c)
    local byte = c:byte()
    if byte== 7 then return "\\a"  end
    if byte== 8 then return "\\b"  end
    if byte== 9 then return "\\t"  end
    if byte==10 then return "\\n"  end
    if byte==11 then return "\\v"  end
    if byte==12 then return "\\f"  end
    if byte==13 then return "\\r"  end
    if byte==34 then return "\\\"" end
    if byte==92 then return "\\\\" end
    return string.format("\\x%02x",byte)
  end)..'"'
end

function serialize.table(tbl,colors,stack)
  stack = table.copy(stack or {})
  table.insert(stack,tbl)
  local keyAmount = 0
  local keyNumber = true
  local out = ""
  local first = true

  for key,val in pairs(tbl) do
    if not first then out=out..",\n" end
    first=false
    out=out.."  "
    if type(key)=="string" then
      if key:match("^[%a_][%w_]*$") then
        out=out..key.."="
      else
        out=out..'['..serialize.string(key)..']='
      end
    else
      out=out.."["..tostring(key).."]="
    end
    if type(key)~="number" then
      keyNumber=false
    end

    local success,reason = pcall(function()
      local valStr = ""
      if type(val)=="table" then
        if #stack>4 or table.find(stack,val) then
          valStr="..."
        else
          valStr=serialize.table(val,colors,stack)
        end
      elseif type(val)=="string" then
        local lines = {}
        for line in (val.."\n"):gmatch("([^\n]*)\n") do table.insert(lines,line) end
        if #lines[#lines]==0 then
          lines[#lines]=nil
          lines[#lines]=lines[#lines].."\n"
        end
        for i=1,#lines do
          if i<#lines then
            lines[i]=serialize.string(lines[i].."\n")
          else
            lines[i]=serialize.string(lines[i])
          end
        end
        valStr=table.concat(lines," ..\n  ")
      else
        valStr=tostring(val)
      end
      local lines = {}
      for line in (valStr.."\n"):gmatch("([^\n]*)\n") do table.insert(lines,line) end
      out=out..table.concat(lines,"\n  ")
      lines = nil
      keyAmount=keyAmount+1
    end)
    if not success then
      if colors then out=out.."\x1b[91m" end
      out=out.."["..tostring(reason).."]"
      if colors then out=out.."\x1b[39m" end
    end
    coroutine.yield()
  end

  local metatbl = getmetatable(tbl)
  local metakeys = {}
  if type(metatbl)=="table" then
    for i,v in pairs(metatbl) do
      keyNumber=false
      table.insert(metakeys,i)
    end
  end
  if #metakeys>0 then
    out=out.."\n  "
    if colors then out=out.."\x1b[92m" end
    if table.find(metakeys,"__tostring") then
      out=out.."tostring: "..serialize.string(tostring(tbl)).."\n  "
      table.remove(metakeys,table.find(metakeys,"__tostring"))
    end
    out=out..table.concat(metakeys,", ")
    if colors then out=out.."\x1b[39m" end
  end

  if keyAmount==0 then return "{}" end
  if keyNumber then
    -- fix strings not being serialised
    local vals = {}
    for _,v in pairs(tbl) do
      if #vals>=5 and #stack>1 then
        table.insert(vals,"...")
        break
      end
      if type(v)=="table" then
        table.insert(vals,serialize.table(v,colors,stack))
      elseif type(v)=="string" then
        table.insert(vals,serialize.string(v))
      else
        table.insert(vals,tostring(v))
      end
    end
    return "{"..table.concat(vals,", ").."}"
  end
  return "{\n"..out.."\n}"
end

return serialize

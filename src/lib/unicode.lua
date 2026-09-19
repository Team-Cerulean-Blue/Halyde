local unicodeLib
local LLunicode
if table.copy then
  unicodeLib = table.copy(unicode)
  LLunicode = table.copy(unicode)
else
  unicodeLib = {}
  LLunicode = unicode
end

function unicodeLib.readCodePoint(readByte)
  checkArg(1,readByte,"function")

  local function inRange(min,max,...)
    for _,v in ipairs({...}) do
      if not (v and v>=min and v<max) then return false end
    end
    return true
  end

  local byte = readByte()
  if byte==nil then return end

  if byte < 0x80 then
    -- ASCII character (0xxxxxxx)
    return byte
  elseif byte < 0xC0 then
    -- Continuation byte (10xxxxxx), invalid at start position
    return nil
  elseif byte < 0xE0 then
    -- 2-byte sequence (110xxxxx 10xxxxxx)
    local byte2 = readByte()
    if byte2==nil then return nil end
    if inRange(0x80,0xC0,byte2) then
      local code_point = ((byte & 0x1F) << 6) | (byte2 & 0x3F)
      return code_point
    end
  elseif byte < 0xF0 then
    -- 3-byte sequence (1110xxxx 10xxxxxx 10xxxxxx)
    local byte2, byte3 = readByte(), readByte()
    if byte2==nil and byte3==nil then return nil end
    if inRange(0x80,0xC0,byte2,byte3)then
      local code_point = ((byte & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F)
      return code_point
    end
  elseif byte < 0xF8 then
    -- 4-byte sequence (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
    local byte2, byte3, byte4 = readByte(), readByte(), readByte()
    if byte2==nil and byte3==nil and byte4==nil then return nil end
    if inRange(0x80,0xC0,byte2,byte3,byte4) then
      local code_point = ((byte & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F)
      return code_point
    end
  end

  -- Invalid UTF-8 byte sequence
  return nil
end

function unicodeLib.readChar(readByte)
  checkArg(1,readByte,"function")
  return LLunicode.char(unicodeLib.readCodePoint(readByte))
end

function unicodeLib.codepoint(chr)
  checkArg(1,chr,"string")
  local ptr = 1
  return unicode.readCodePoint(function()
      local byte = chr:byte(ptr)
      ptr=ptr+1
      return byte
  end),ptr-1
end

function unicodeLib.iterate(readByte)
  checkArg(1,readByte,"string","function")
  if type(readByte)=="string" then
    local str,ptr = readByte,0
    readByte = function()
      ptr=ptr+1
      return str:byte(ptr)
    end
  end
  return function()
    local point = unicodeLib.readCodePoint(readByte)
    if point==nil then return nil end
    return LLunicode.char(point),point
  end
end

unicodeLib.char = LLunicode.char
unicodeLib.charWidth = LLunicode.charWidth
unicodeLib.isWide = LLunicode.isWide
unicodeLib.len = LLunicode.len
unicodeLib.lower = LLunicode.lower
unicodeLib.reverse = LLunicode.reverse
unicodeLib.sub = LLunicode.sub
unicodeLib.upper = LLunicode.upper
unicodeLib.wlen = LLunicode.wlen
unicodeLib.wtrunc = LLunicode.wtrunc

return unicodeLib

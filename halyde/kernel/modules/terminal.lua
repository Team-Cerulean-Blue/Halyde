--[[
TODO:
```bash
echo -e "\033[?25l" # hide
echo -e "\033[?25h" # show
```
]]
local module = {}

function module.check()
  return true -- Usually always loaded, but maybe it would be worth it to check if the computer has a GPU or not? I'm not sure.
end

function module.init()
  local serialize = require("serialize")
  local unicode = require("unicode")
  local event = require("event")

  local component = require("component")
  local computer = require("computer")
  local gpu = component.gpu
  _G._PUBLIC.terminal = {}

  local readHistory = {}
  function _PUBLIC.terminal.getHistory(id)
    checkArg(1,id,"string")
    return table.copy(readHistory[id])
  end
  function _PUBLIC.terminal.setHistory(id,hist)
    checkArg(1,id,"string")
    checkArg(2,hist,"table")
    for i=1,#hist do
      hist[i]=tostring(hist[i])
    end
    readHistory[id]=hist
  end
  function _PUBLIC.terminal.addToHistory(id,hist)
    checkArg(1,id,"string")
    checkArg(2,hist,"string")
    table.insert(readHistory[id],hist)
  end

  local function getColorPalette(depth)
    if depth == 1 then
      return {
        ["dark"] = {
          [0] = 0x000000,
          [1] = 0xffffff,
          [2] = 0xffffff,
          [3] = 0xffffff,
          [4] = 0xffffff,
          [5] = 0xffffff,
          [6] = 0xffffff,
          [7] = 0xffffff,
        },
        ["bright"] = {
          [0] = 0x000000,
          [1] = 0xffffff,
          [2] = 0xffffff,
          [3] = 0xffffff,
          [4] = 0xffffff,
          [5] = 0xffffff,
          [6] = 0xffffff,
          [7] = 0xffffff,
        }
      }
    end
    if depth == 4 then
      return {
        -- Closest colors to the 4 bit OC pallete
        -- Better than outright failure
        ["dark"] = {
          [0] = 0x000000, -- black
          [1] = 0x663300, -- brown (dark red)
          [2] = 0x336600, -- green (dark green)
          [3] = 0x336600, -- green (dark yellow)
          [4] = 0x333399, -- blue (dark blue)
          [5] = 0x9933CC, -- purple (dark purple)
          [6] = 0x333399, -- blue (dark cyan)
          [7] = 0xCCCCCC  -- silver (dark white)
        },
        ["bright"] = {
          [0] = 0x333333, -- gray (bright black)
          [1] = 0xff3333, -- red
          [2] = 0x33cc33, -- lime (green)
          [3] = 0xffff33, -- yellow
          [4] = 0x333399, -- blue
          [5] = 0xcc66cc, -- magenta (purple)
          [6] = 0x336699, -- cyan
          [7] = 0xffffff  -- white
        }
      }
    end
    if depth == 8 then
      return {
        ["dark"] = {
          [0] = 0x0f0f0f, -- black
          [1] = 0xcc2424, -- dark red
          [2] = 0x339280, -- dark green
          [3] = 0x996d00, -- dark yellow
          [4] = 0x004980, -- dark blue
          [5] = 0x9949c0, -- dark purple
          [6] = 0x33b6c0, -- dark cyan
          [7] = 0xc3c3c3  -- dark white
        },
        ["bright"] = {
          [0] = 0x666d80, -- brighter black
          [1] = 0xff6d40, -- red
          [2] = 0x33db80, -- green
          [3] = 0xffb600, -- yellow
          [4] = 0x336dff, -- blue
          [5] = 0xcc6dc0, -- purple
          [6] = 0x33dbc0, -- cyan
          [7] = 0xffffff  -- white
        }
      }
    end
    --[[ Original color palette:
    {
      ["dark"] = {
        [0] = 0x171421,
        [1] = 0xc01c28,
        [2] = 0x26a269,
        [3] = 0xa2734c,
        [4] = 0x12488b,
        [5] = 0xa347ba,
        [6] = 0x2aa1b3,
        [7] = 0xd0cfcc
      },
      ["bright"] = {
        [0] = 0x5e5c64,
        [1] = 0xf66151,
        [2] = 0x33d17a,
        [3] = 0xe9ad0c,
        [4] = 0x2a7bde,
        [5] = 0xc061cb,
        [6] = 0x33c7de,
        [7] = 0xffffff
      }
    }
    ]]
    -- Shouldn't reach here
    error()
  end

  local ANSIColorPalette = getColorPalette(gpu.maxDepth())

  local expecting_unicode_bytes = 0
  local unicode_bytes_left = 0
  local unicode_codepoint = 0
  local cursor = { x = 1, y = 1, X = nil, Y = nil } -- X and Y are managed by ESC s and ESC u
  local printState = 0 -- 0:none 1:in ESC 2:in CSI
  local color = {
    FG = ANSIColorPalette["bright"][7], BG = ANSIColorPalette["dark"][0],
    fg = nil, bg = nil, reverse = false
  }
  color.fg = color.FG
  color.bg = color.BG
  local current_codepoint = 0
  local bytes_remaining = 0
  local seq = {}

  local writeBuf = {}

  local function update_gpu_colors()
    if color.reverse then
      gpu.setForeground(color.bg)
      gpu.setBackground(color.fg)
    else
      gpu.setForeground(color.fg)
      gpu.setBackground(color.bg)
    end
  end

  local width, height = gpu.getResolution()

  function _G._PUBLIC.terminal.getResolution()
    return width, height
  end

  gpu.setForeground(color.fg)
  gpu.setBackground(color.bg)

  local function scroll()
    if gpu.copy(1, 2, width, height - 1, 0, -1) then
      gpu.setForeground(color.FG)
      gpu.setBackground(color.BG)
      gpu.fill(1, height, width, 1, " ")
      gpu.setForeground(color.fg)
      gpu.setBackground(color.bg)
      cursor.y = height
    end
  end

  local function check_wrap_and_scroll()
    if cursor.x > width then
      cursor.x = 1
      cursor.y = cursor.y + 1
    end

    while cursor.y > height do
      scroll()
    end
  end

  local function exec_csi()
    local params = {}
    local op = 0
    local current_num = 0
    local have_num = false

    for i = 1, #seq do
      local byte = seq[i]

      if 0x30 <= byte and byte <= 0x39 then
        current_num = current_num * 10 + (byte - 0x30)
        have_num = true
      elseif byte == 0x3b then
        table.insert(params, have_num and current_num or 0)
        current_num = 0
        have_num = false
      else
        if have_num then
          table.insert(params, current_num)
        end
        if 0x40 <= byte and byte <= 0x7e then
          op = byte
        end
        break
      end
    end

    local function get_param(idx, default)
      if idx <= #params and params[idx] ~= nil then
        return params[idx]
      end
      return default
    end

    if op == 0x48 or op == 0x66 then
      local row = get_param(1, 1)
      local col = get_param(2, 1)
      cursor.y = row
      cursor.x = col
      if cursor.x < 1 then cursor.x = 1 end
      if cursor.y < 1 then cursor.y = 1 end
      if cursor.x > width then cursor.x = width end
      if cursor.y > height then cursor.y = height end
      return
    end

    if op == 0x41 then
      local n = get_param(1, 1)
      cursor.y = cursor.y - n
      if cursor.y < 1 then cursor.y = 1 end
      return
    end

    if op == 0x42 then
      local n = get_param(1, 1)
      cursor.y = cursor.y + n
      if cursor.y > height then cursor.y = height end
      return
    end

    if op == 0x43 then
      local n = get_param(1, 1)
      cursor.x = cursor.x + n
      if cursor.x > width then cursor.x = width end
      return
    end

    if op == 0x44 then
      local n = get_param(1, 1)
      cursor.x = cursor.x - n
      if cursor.x < 1 then cursor.x = 1 end
      return
    end

    if op == 0x47 then
      local col = get_param(1, 1)
      cursor.x = col
      if cursor.x < 1 then cursor.x = 1 end
      if cursor.x > width then cursor.x = width end
      return
    end

    if op == 0x4a then
      local mode = get_param(1, 0)

      if mode == 0 then
        update_gpu_colors()
        gpu.fill(cursor.x, cursor.y, width - cursor.x + 1, height - cursor.y + 1, " ")
      elseif mode == 1 then
        update_gpu_colors()
        gpu.fill(1, 1, cursor.x, cursor.y, " ")
      elseif mode == 2 then
        update_gpu_colors()
        gpu.fill(1, 1, width, height, " ")
        cursor.x = 1
        cursor.y = 1
      end
      return
    end

    if op == 0x4b then
      local mode = get_param(1, 0)

      if mode == 0 then
        update_gpu_colors()
        gpu.fill(cursor.x, cursor.y, width - cursor.x + 1, 1, " ")
      elseif mode == 1 then
        update_gpu_colors()
        gpu.fill(1, cursor.y, cursor.x, 1, " ")
      elseif mode == 2 then
        update_gpu_colors()
        gpu.fill(1, cursor.y, width, 1, " ")
      end
      return
    end

    if op == 0x60 then
      local col = get_param(1, 1)
      cursor.x = col
      if cursor.x < 1 then cursor.x = 1 end
      if cursor.x > width then cursor.x = width end
      return
    end

    if op == 0x64 then
      local row = get_param(1, 1)
      cursor.y = row
      if cursor.y < 1 then cursor.y = 1 end
      if cursor.y > height then cursor.y = height end
      return
    end

    if op == 0x6d then
      local j = 1
      local function parse_extended_color()
        local mode = get_param(j + 1, -1)
        if mode == 5 then
          local idx = get_param(j + 2, 0)
          j = j + 2
          if idx < 8 then
            return ANSIColorPalette["dark"][idx]
          elseif idx < 16 then
            return ANSIColorPalette["bright"][idx - 8]
          elseif idx < 232 then
            local i = idx - 16
            local b = (i % 6) * 51
            local g = ((i // 6) % 6) * 51
            local r = (i // 36) * 51
            return (r << 16) | (g << 8) | b
          else
            local v = (idx - 232) * 10 + 8
            return (v << 16) | (v << 8) | v
          end
        elseif mode == 2 then
          local r = get_param(j + 2, 0)
          local g = get_param(j + 3, 0)
          local b = get_param(j + 4, 0)
          j = j + 4
          return (r << 16) | (g << 8) | b
        end
        return nil
      end

      if #params == 0 then
        color.reverse = false
        color.fg = color.FG
        color.bg = color.BG
        update_gpu_colors()
        return
      end

      while j <= #params do
        local p = params[j] or 0

        if p == 0 then
          color.reverse = false
          color.fg = color.FG
          color.bg = color.BG
        elseif p == 1 then
        elseif p == 2 then
        elseif p == 3 then
        elseif p == 4 then
        elseif p == 5 or p == 6 then
        elseif p == 7 then
          color.reverse = true
        elseif p == 8 then
          color.fg = color.bg
        elseif p == 9 then
        elseif p == 21 then
        elseif p == 22 then
        elseif p == 23 then
        elseif p == 24 then
        elseif p == 25 then
        elseif p == 27 then
          color.reverse = false
        elseif p == 28 then
          color.fg = color.FG
        elseif p == 29 then
        elseif 30 <= p and p <= 37 then
          color.fg = ANSIColorPalette["dark"][p - 30]
        elseif p == 38 then
          local c = parse_extended_color()
          if c then color.fg = c end
        elseif p == 39 then
          color.fg = color.FG
        elseif 40 <= p and p <= 47 then
          color.bg = ANSIColorPalette["dark"][p - 40]
        elseif p == 48 then
          local c = parse_extended_color()
          if c then color.bg = c end
        elseif p == 49 then
          color.bg = color.BG
        elseif p == 58 then
          parse_extended_color()
        elseif p == 59 then
        elseif 90 <= p and p <= 97 then
          color.fg = ANSIColorPalette["bright"][p - 90]
        elseif 100 <= p and p <= 107 then
          color.bg = ANSIColorPalette["bright"][p - 100]
        end

        j = j + 1
      end
      update_gpu_colors()
      return
    end

    if op == 0x73 then
      cursor.X = cursor.x
      cursor.Y = cursor.y
      return
    end

    if op == 0x75 then
      if cursor.X and cursor.Y then
        cursor.x = cursor.X
        cursor.y = cursor.Y
        if cursor.x < 1 then cursor.x = 1 end
        if cursor.y < 1 then cursor.y = 1 end
        if cursor.x > width then cursor.x = width end
        if cursor.y > height then cursor.y = height end
      end
      return
    end
  end

  function _G._PUBLIC.terminal.writec(byte)
    if byte == 0x1b then
      _PUBLIC.terminal.flush()
      printState = 1
      seq = {}
      return
    end

    if printState == 1 then
      if byte == 0x5b then
        printState = 2
      else
        printState = 0
      end
      return
    end

    if printState == 2 then
      table.insert(seq, byte)
      if 0x40 <= byte and byte <= 0x7e then
        exec_csi()
        printState = 0
        seq = {}
      end
      return
    end

    if byte == 0xa then
      _PUBLIC.terminal.flush()
      cursor.y = cursor.y + 1
      cursor.x = 1
      check_wrap_and_scroll()
      return
    end

    if byte == 0xd then
      _PUBLIC.terminal.flush()
      cursor.x = 1
      return
    end

    if byte == 0x8 then
      _PUBLIC.terminal.flush()
      if cursor.x > 1 then
        cursor.x = cursor.x - 1
      end
      return
    end

    if byte == 0x9 then
      _PUBLIC.terminal.flush()
      cursor.x = ((cursor.x - 1) // 8) * 8 + 9
      if cursor.x < 1 then cursor.x = 1 end
      if cursor.x > width then cursor.x = width end
      return
    end

    if byte >= 0x20 and byte <= 0x7F then
      table.insert(writeBuf, string.char(byte))
      cursor.x = cursor.x + 1
      check_wrap_and_scroll()
      if cursor.y ~= writeBufY or #writeBuf >= 32 then
        _PUBLIC.terminal.flush()
      end
    elseif byte >= 0xC2 and byte <= 0xDF then
      current_codepoint = (byte & 0x1F)
      bytes_remaining = 1
    elseif byte >= 0xE0 and byte <= 0xEF then
      current_codepoint = (byte & 0x0F)
      bytes_remaining = 2
    elseif byte >= 0xF0 and byte <= 0xF7 then
      current_codepoint = (byte & 0x07)
      bytes_remaining = 3
    elseif byte >= 0x80 and byte <= 0xBF and bytes_remaining > 0 then
      current_codepoint = (current_codepoint << 6) | (byte & 0x3F)
      bytes_remaining = bytes_remaining - 1
      if bytes_remaining == 0 then
        table.insert(writeBuf, utf8.char(current_codepoint))
        cursor.x = cursor.x + 1
        check_wrap_and_scroll()
        if cursor.y ~= writeBufY or #writeBuf >= 32 then
          _PUBLIC.terminal.flush()
        end
        current_codepoint = 0
      end
    else
      current_codepoint = 0
      bytes_remaining = 0
    end
  end

  function _G._PUBLIC.terminal.write(text)
    text = tostring(text)
    for i = 1, #text do
      _PUBLIC.terminal.writec(string.byte(text, i))
    end
  end

  function _G._PUBLIC.terminal.clear()
    update_gpu_colors()
    gpu.fill(1, 1, width, height, " ")
    writeBuf = {}
    cursor.x = 1
    cursor.y = 1
  end

  function _G._PUBLIC.terminal.flush()
    if #writeBuf == 0 then return end
    update_gpu_colors()
    gpu.set(cursor.x - #writeBuf, cursor.y, table.concat(writeBuf))
    writeBuf = {}
  end

  function _G.print(...)
    local args = {...}
    local stringArgs = {}
    for _, arg in pairs(args) do
      if type(arg)=="table" then
        table.insert(stringArgs, serialize(arg))
      elseif tostring(arg) then
        table.insert(stringArgs, tostring(arg))
      end
    end
    _PUBLIC.terminal.write(table.concat(stringArgs, "\t") .. "\n")
  end

  function _G._PUBLIC.terminal.read(options)
    checkArg(1, options, "table", "nil")
    local function checkOption(name, value, neededType)
      assert(not value or type(value) == neededType, ("%s option must be %s, %s provided"):format(name, neededType, type(value)))
    end
    if not options then
      options = {}
    end
    checkOption("readHistoryType", options.readHistoryType, "string")
    checkOption("prefix", options.prefix, "string")
    checkOption("maxChars", options.maxChars, "number")
    checkOption("defaultText", options.defaultText, "string")
    checkOption("censor", options.censor, "string")

    options.maxChars = options.maxChars or math.huge

    local text = options.defaultText or ""

    _G._PUBLIC.terminal.flush()

    local historyIdx
    if options.readHistoryType then
      if not readHistory[options.readHistoryType] then
        readHistory[options.readHistoryType] = {text}
      elseif readHistory[options.readHistoryType][#readHistory[options.readHistoryType] ] ~= text then
        table.insert(readHistory[options.readHistoryType], text)
      end
      historyIdx = #readHistory[options.readHistoryType]
    end

    local function updateHistory()
      if not options.readHistoryType then return end
      if historyIdx ~= #readHistory[options.readHistoryType] then return end
      readHistory[options.readHistoryType][historyIdx]=text
    end

    local cur = unicode.len(text)+1
    if options.prefix then _PUBLIC.terminal.write(options.prefix) end
    local startX, startY = cursor.x, cursor.y
    local fg, bg = gpu.getForeground(), gpu.getBackground()
    local cursorBlink = true
    local function checkScroll(y)
      for i=1,y-height do
        scrollDown()
        startY=startY-1
      end
      return math.min(y,height)
    end
    local function set(index, character, invertedColors) -- HACK: Currently, this will uncensor all spaces in the inputted text.
      if character==nil or character=="" then return end
      if options.censor then
        character = character:gsub("[^ ]", options.censor)
      end
      if invertedColors then
        gpu.setForeground(bg)
        gpu.setBackground(fg)
      else
        gpu.setForeground(fg)
        gpu.setBackground(bg)
      end
      index=startX+index-1
      local setX, setY = (index-1)%width+1, startY+((index-1)//width+1)-1
      setY = checkScroll(setY)
      gpu.set(setX,setY,unicode.sub(character,1,width-setX+1))
      for i=1,math.ceil((#character+setX-1)/width)+1 do
        gpu.set(1,setY+i,unicode.sub(character,2-setX+i*width,width+i*width-setX))
        setY = checkScroll(setY)
      end
    end
    local function strDef(a,b)
      if #a==0 then return b end
      return a
    end
    local function curPos(cur)
      return unicode.wlen(unicode.sub(text,1,cur-1))+1
    end
    local function add(chr)
      if type(chr)~="string" or #chr==0 then return end
      if unicode.len(text)>=options.maxChars then return end
      if options.maxChars<math.huge then
        chr=unicode.sub(chr,1,options.maxChars-unicode.len(text))
      end
      text=unicode.sub(text,1,cur-1)..chr..unicode.sub(text,cur)
      set(curPos(cur),chr,false)
      cur=math.min(cur+unicode.len(chr),options.maxChars+1)
      set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),true)
      cursorBlink = true
      set(curPos(cur+1),unicode.sub(text,cur+1),false)
    end
    local function moveCur(dir)
      set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),false)
      cur=math.max(math.min(cur+dir,unicode.len(text)+1),1)
      set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),true)
      cursorBlink = true
    end
    local function isLetter(chr)
      return not string.find("\x09 :@-./_~?&=%+#",chr,1,true)
    end
    local function nextCur(dir,chr,icur)
      if icur==nil then icur=cur end
      local next = math.max(math.min(icur+dir,unicode.len(text)+1),1)
      if chr then return unicode.sub(text,next,next) end
      return next
    end
    local function curAfterWord(dir)
      local ncur = cur
      while nextCur(dir,false,ncur)~=ncur and isLetter(nextCur(dir,true,ncur))==(dir==1) do
        ncur=nextCur(dir,false,ncur)
      end
      while nextCur(dir,false,ncur)~=ncur and isLetter(nextCur(dir,true,ncur))==(dir==-1) do
        ncur=nextCur(dir,false,ncur)
      end
      return ncur
    end
    local function moveWord(dir)
      if nextCur(dir)==cur then return end
      set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),false)
      cur=curAfterWord(dir)
      set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),true)
      cursorBlink = true
    end
    local function deleteWord(dir)
      local after = curAfterWord(dir)
      local lenb = unicode.wlen(text)
      if dir==1 then
        text=unicode.sub(text,1,cur-1)..unicode.sub(text,after)
        set(curPos(cur+1),unicode.sub(text,cur+1)..string.rep(" ",lenb-unicode.wlen(text)+1),false)
        set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),true)
      else
        text = unicode.sub(text,1,after-1)..unicode.sub(text,cur)
        cur=after
        set(curPos(cur+1),unicode.sub(text,cur+1)..string.rep(" ",lenb-unicode.wlen(text)+1),false)
        set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),true)
      end
      updateHistory()
      cursorBlink = true
    end
    local function isLine(chr)
      return chr=="\n" or chr=="\r"
    end
    --[[ gpu.set(startX,startY,unicode.sub(text,1,width-startX))
    for i=1,(#text+startX)//width-1 do
      gpu.set(startX,startY+i,unicode.sub(text,1+i*width,width-startX+i*width))
    end ]]
    set(1,text,false)
    set(curPos(cur)," ",true)

    local function reprint(new)
      set(1,new..string.rep(" ",unicode.wlen(text)-unicode.wlen(new)+1),false)
      cur=unicode.len(new)+1
      text=new
      set(curPos(cur)," ",true)
    end


    while true do
      local args = {event.pull("key_down", "clipboard", 0.5)}
      local ctrlDown = _PUBLIC.keyboard.getCtrlDown()
      if args and args[1] == "key_down" and args[4] then
        local key = _PUBLIC.keyboard.keys[args[4]]
        if key=="up" and options.readHistoryType then
          historyIdx=math.max(historyIdx-1,1)
          reprint(readHistory[options.readHistoryType][historyIdx])
        elseif key=="down" and options.readHistoryType then
          historyIdx=math.min(historyIdx+1,#readHistory[options.readHistoryType])
          reprint(readHistory[options.readHistoryType][historyIdx])
        elseif key=="left" and ctrlDown then
          moveWord(-1)
        elseif key=="right" and ctrlDown then
          moveWord(1)
        elseif key=="left" then
          moveCur(-1)
        elseif key=="right" then
          moveCur(1)
        elseif key=="home" then
          moveCur(-math.huge)
        elseif key=="end" then
          moveCur(math.huge)
        elseif key=="back" and ctrlDown then
          deleteWord(-1)
        elseif key=="delete" and ctrlDown then
          deleteWord(1)
        elseif key=="back" and cur>1 then
          text=unicode.sub(text,1,cur-2)..unicode.sub(text,cur)
          cur=cur-1
          set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),true)
          cursorBlink = true
          set(curPos(cur)+1,unicode.sub(text,cur+1).."  ",false)
          updateHistory()
        elseif key=="delete" then
          text = unicode.sub(text,1,cur-1)..unicode.sub(text,cur+1)
          set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),true)
          cursorBlink = true
          if cur<=unicode.len(text) then
            set(curPos(cur+1),unicode.sub(text,cur+1).."  ",false)
          end
          updateHistory()
        elseif key=="enter" then
          set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),false)
          break
        elseif not (args[3]<32 or (args[3]>0x7F and args[3]<=0x9F)) then
          add(unicode.char(args[3]) or " ")
          updateHistory()
        end
      elseif args and args[1]=="clipboard" then
        local clip = args[3]
        if not args[3] then goto continue end
        while isLine(unicode.sub(clip,1,1)) do clip=unicode.sub(clip,2) end
        while isLine(unicode.sub(clip,-1)) do clip=unicode.sub(clip,1,-2) end
        add(clip)
        updateHistory()
      else
        cursorBlink=not cursorBlink
        set(curPos(cur),strDef(unicode.sub(text,cur,cur)," "),cursorBlink)
      end
      ::continue::
    end

    if options.readHistoryType then
      if readHistory[options.readHistoryType][#readHistory[options.readHistoryType]]=="" then
        table.remove(readHistory[options.readHistoryType],#readHistory[options.readHistoryType])
      end
      if historyIdx<#readHistory[options.readHistoryType] then
        -- table.remove(readHistory[options.readHistoryType],historyIdx)
        table.insert(readHistory[options.readHistoryType],text)
      end
      while #readHistory[options.readHistoryType] > 50 do
        table.remove(readHistory[options.readHistoryType], 1)
      end
    end

    cursor.x=1
    cursor.y=cursor.y+math.ceil((unicode.wlen(text)+startX-1)/width)
    if cursor.y>height then scroll() end

    return text
  end
end

function module.exit()
  _G._PUBLIC.terminal = nil
end

return module

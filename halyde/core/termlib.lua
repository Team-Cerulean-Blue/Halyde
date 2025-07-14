local unicode = import("unicode")
local event = import("event")
--local keyboard = import("keyboard")

--local ocelot = component.proxy(component.list("ocelot")())
local component = import("component")
local computer = import("computer")
local gpu = component.gpu
_G.termlib = {}
termlib.cursorPosX = 1
termlib.cursorPosY = 1
termlib.readHistory = {}

local width, height = gpu.getResolution()

local ANSIColorPalette = {
  ["dark"] = {
    [0] = 0x000000,
    [1] = 0x800000,
    [2] = 0x008000,
    [3] = 0x808000,
    [4] = 0x000080,
    [5] = 0x800080,
    [6] = 0x008080,
    [7] = 0xC0C0C0
  },
  ["bright"] = {
    [0] = 0x808080,
    [1] = 0xFF0000,
    [2] = 0x00FF00,
    [3] = 0xFFFF00,
    [4] = 0x0000FF,
    [5] = 0xFF00FF,
    [6] = 0x00FFFF,
    [7] = 0xFFFFFF
  }
}

defaultForegroundColor = ANSIColorPalette["bright"][7]
defaultBackgroundColor = ANSIColorPalette["dark"][0]

gpu.setForeground(defaultForegroundColor)
gpu.setBackground(defaultBackgroundColor)

local function scrollDown()
  width, height = gpu.getResolution()
  if gpu.copy(1,1,width,height,0,-1) then
    local prevForeground = gpu.getForeground()
    local prevBackground = gpu.getBackground()
    gpu.setForeground(defaultForegroundColor)
    gpu.setBackground(defaultBackgroundColor)
    gpu.fill(1, height, width, 1, " ")
    gpu.setForeground(prevForeground)
    gpu.setBackground(prevBackground)
    termlib.cursorPosY=height
  end
end

local function newLine()
  termlib.cursorPosX=1
  termlib.cursorPosY = termlib.cursorPosY + 1
  if termlib.cursorPosY>height then
    scrollDown()
  end
end

local function parseCodeNumbers(code)
  o = {}
  for num in code:sub(3,-2):gmatch("[^;]+") do
    table.insert(o,tonumber(num))
  end
  return o
end

local function from8BitColor(num)
  num=math.floor(num)&255
  if num<16 then return 0x444444*((num>>3)&1)+(0xBB0000*((num>>2)&1)|0x00BB00*((num>>1)&1)|0x0000BB*(num&1)) end
  if num>=232 then return 0x10101*(8+(num-232)*10) end
  num=num-16
  local palette = {0,95,135,175,215,255}
  return (palette[(num//36)%6+1]<<16)|(palette[(num//6)%6+1]<<8)|palette[num%6+1]
end

local function from24BitColor(r,g,b)
  r,g,b=math.floor(r)&255,math.floor(g)&255,math.floor(b)&255
  return (r<<16)|(g<<8)|b
end

local function findCodeEnd(text,i)
  local function inRange(v,min,max)
    return v>=min and v<=max
  end
  i=i+2
  while i<=#text and not inRange(text:byte(i),0x40,0x7F) do i=i+1 end
  return i
end

function termlib.write(text, textWrap)
  width, height = gpu.getResolution()

  -- you don't know how tiring this was just for ANSI escape code support

  if textWrap == nil then
    textWrap = true
  end

  if not text or not tostring(text) then
    return
  end
  if text:find("\a") then
    computer.beep()
  end
  text = tostring(text)
  text = "\27[0m" .. text:gsub("\t", "  ")
  readBreak = 0
  -- readBreak is for when, inside the for loop, there normally would have been an increase in the "i" variable because it has read more than one character.
  -- unfortunately, changing the "i" variable would have unpredictable effects, so to not risk anything, this workaround was done.
  section = ""

  local function printSection()
    if #section==0 then
      return
    end
    while true do
      gpu.set(termlib.cursorPosX,termlib.cursorPosY,section)
      if unicode.wlen(section) > width - termlib.cursorPosX + 1 and textWrap then
        section = section:sub(width - termlib.cursorPosX + 2)
        newLine()
      else
        termlib.cursorPosX = termlib.cursorPosX+unicode.wlen(section)
        break
      end
    end
    section = ""
  end

  for i=1,#text do
    if readBreak>0 then
      readBreak = readBreak - 1
      goto continue
    end

    if string.byte(text,i)==10 then
      printSection()
      newLine()
    elseif string.byte(text,i)==13 then
      printSection()
      termlib.cursorPosX=1
    elseif string.byte(text,i)==0x1b and i<=#text-2 then
      printSection()
      --ocelot.log("0x1b char detected")
      codeType = string.sub(text,i+1,i+1)
      if codeType=="[" then
        -- Control Sequence Introducer
        --ocelot.log("Control Sequence Introducer")
        codeEndIdx = findCodeEnd(text,i)
        -- codeEndIdx = string.find(text,"m",i)
        code = string.sub(text,i,codeEndIdx)
        --ocelot.log("Code: "..code.." ("..i..", "..codeEndIdx..")")
        readBreak = readBreak + #code - 1
        nums = parseCodeNumbers(code)
        codeEnd = code:sub(-1)
        --ocelot.log("Code end: "..codeEnd..", "..#codeEnd)
        if codeEnd == "m" then
          -- Select Graphic Rendition
          --ocelot.log("Select Graphic Rendition, ID "..nums[1])
          if nums[1]>=30 and nums[1]<=37 then
            gpu.setForeground(ANSIColorPalette["dark"][nums[1]%10])
          end
          if nums[1]==38 and nums[2]==5 then
            gpu.setForeground(from8BitColor(nums[3]))
          end
          if nums[1]==38 and nums[2]==2 then
            gpu.setForeground(from24BitColor(nums[3],nums[4],nums[5]))
          end
          if nums[1]==39 or nums[1]==0 then
            gpu.setForeground(defaultForegroundColor)
          end
          if nums[1]>=40 and nums[1]<=47 then
            gpu.setBackground(ANSIColorPalette["dark"][nums[1]%10])
          end
          if nums[1]==48 and nums[2]==5 then
            gpu.setBackground(from8BitColor(nums[3]))
          end
          if nums[1]==48 and nums[2]==2 then
            gpu.setBackground(from24BitColor(nums[3],nums[4],nums[5]))
          end
          if nums[1]==49 or nums[1]==0 then
            gpu.setBackground(defaultBackgroundColor)
          end
          if nums[1]>=90 and nums[1]<=97 then
            gpu.setForeground(ANSIColorPalette["bright"][nums[1]%10])
          end
          if nums[1]>=100 and nums[1]<=107 then
            gpu.setBackground(ANSIColorPalette["bright"][nums[1]%10])
          end
        end
      end
    else
      --gpu.set(termlib.cursorPosX,termlib.cursorPosY,string.sub(text,i,i))
      section = section..string.sub(text,i,i)
    end
    ::continue::
  end
  printSection()
end

function _G.print(...)
  local args = {...}
  local stringArgs = {}
  for _, arg in pairs(args) do
    if tostring(arg) then
      table.insert(stringArgs, tostring(arg))
    end
  end
  termlib.write(table.concat(stringArgs, "   ") .. "\n")
end

function _G.clear()
  width, height = gpu.getResolution()
  gpu.setForeground(defaultForegroundColor)
  gpu.setBackground(defaultBackgroundColor)
  gpu.fill(1,1,width,height," ")
  termlib.cursorPosX, termlib.cursorPosY = 1, 1
end

function _G.read(readHistoryType, prefix, defaultText, maxChars)
  checkArg(1, readHistoryType, "string", "nil")
  checkArg(2, prefix, "string", "nil")
  checkArg(3, defaultText, "string", "nil")
  checkArg(4, maxChars, "number", "nil")
  maxChars = maxChars or math.huge

  local text = defaultText or ""

  local historyIdx
  if readHistoryType then
    if not termlib.readHistory[readHistoryType] then
      termlib.readHistory[readHistoryType] = {text}
    elseif termlib.readHistory[readHistoryType][#termlib.readHistory[readHistoryType] ] ~= "" then
      table.insert(termlib.readHistory[readHistoryType], text)
    end
    historyIdx = #termlib.readHistory[readHistoryType]
  end

  local function updateHistory()
    if not readHistoryType then return end
    termlib.readHistory[readHistoryType][historyIdx]=text
  end

  local cur = unicode.len(text)+1
  if prefix then termlib.write(prefix) end
  local startX, startY = termlib.cursorPosX, termlib.cursorPosY
  local fg, bg = gpu.getForeground(), gpu.getBackground()
  local cursorBlink = true
  local function get(idx)
    idx=startX+idx-1
    return gpu.get(idx%width,startY+(idx//width))
  end
  local function checkScroll(y)
    for i=1,y-height do
      scrollDown()
      startY=startY-1
    end
    return math.min(y,height)
  end
  local function set(idx,chr,rev)
    if chr==nil or chr=="" then return end
    if rev then
      gpu.setForeground(bg)
      gpu.setBackground(fg)
    else
      gpu.setForeground(fg)
      gpu.setBackground(bg)
    end
    idx=startX+idx-1
    local setX, setY = (idx-1)%width+1, startY+((idx-1)//width+1)-1
    setY = checkScroll(setY)
    gpu.set(setX,setY,unicode.sub(chr,1,width-setX+1))
    for i=1,math.ceil((#chr+setX-1)/width)+1 do
      gpu.set(1,setY+i,unicode.sub(chr,2-setX+i*width,width+i*width-setX))
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
    if unicode.len(text)>=maxChars then return end
    if maxChars<math.huge then
      chr=unicode.sub(chr,1,maxChars-unicode.len(text))
    end
    text=unicode.sub(text,1,cur-1)..chr..unicode.sub(text,cur)
    set(curPos(cur),chr,false)
    cur=math.min(cur+unicode.len(chr),maxChars+1)
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
    if args and args[1] == "key_down" and args[4] then
      local key = keyboard.keys[args[4]]
      if key=="up" and readHistoryType then
        historyIdx=math.max(historyIdx-1,1)
        reprint(termlib.readHistory[readHistoryType][historyIdx])
      elseif key=="down" and readHistoryType then
        historyIdx=math.min(historyIdx+1,#termlib.readHistory[readHistoryType])
        reprint(termlib.readHistory[readHistoryType][historyIdx])
      elseif key=="left" and keyboard.ctrlDown then
        moveWord(-1)
      elseif key=="right" and keyboard.ctrlDown then
        moveWord(1)
      elseif key=="left" then
        moveCur(-1)
      elseif key=="right" then
        moveCur(1)
      elseif key=="home" then
        moveCur(-math.huge)
      elseif key=="end" then
        moveCur(math.huge)
      elseif key=="back" and keyboard.ctrlDown then
        deleteWord(-1)
      elseif key=="delete" and keyboard.ctrlDown then
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

  if readHistoryType then
    if termlib.readHistory[readHistoryType][#termlib.readHistory[readHistoryType]]=="" then
      table.remove(termlib.readHistory[readHistoryType],#termlib.readHistory[readHistoryType])
    end
    if historyIdx<#termlib.readHistory[readHistoryType] then
      table.remove(termlib.readHistory[readHistoryType],historyIdx)
      table.insert(termlib.readHistory[readHistoryType],text)
    end
    while #termlib.readHistory[readHistoryType] > 50 do
      table.remove(termlib.readHistory[readHistoryType], 1)
    end
  end

  termlib.cursorPosX=1
  termlib.cursorPosY=termlib.cursorPosY+math.ceil((unicode.wlen(text)+startX-1)/width)
  if termlib.cursorPosY>height then scrollDown() end

  return text
end

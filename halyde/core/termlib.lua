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
  text = "\27[0m" .. text:gsub("\t", "  ")
  text = tostring(text)
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
        codeEndIdx = string.find(text,"m",i)
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
          if nums[1]==39 or nums[1]==0 then
            gpu.setForeground(defaultForegroundColor)
          end
          if nums[1]>=40 and nums[1]<=47 then
            gpu.setBackground(ANSIColorPalette["dark"][nums[1]%10])
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

-- god i hope this silly claude code works first try
-- Fluxdrive caught vibe coding???
function _G.read(readHistoryType, prefix, defaultText)
  checkArg(1, readHistoryType, "string", "nil")
  checkArg(2, prefix, "string", "nil")
  checkArg(3, defaultText, "string", "nil")
  local curtext = defaultText or ""
  local prefix = prefix or ""
  local textCursorPos = unicode.wlen(curtext) + 1 -- Position within the text (1-based)

  local RHIndex
  if readHistoryType then
    if not termlib.readHistory[readHistoryType] then
      termlib.readHistory[readHistoryType] = {curtext}
    elseif termlib.readHistory[readHistoryType][#termlib.readHistory[readHistoryType]] ~= "" then
      table.insert(termlib.readHistory[readHistoryType], curtext)
    end
    RHIndex = #termlib.readHistory[readHistoryType]
  end

  local cursorPosX, cursorPosY = termlib.cursorPosX, termlib.cursorPosY

  -- Track maximum text length to ensure proper clearing across wrapped lines
  local maxTextLength = unicode.wlen(prefix .. curtext)

  -- Function to calculate how many lines text will occupy
  local function calculateLines(text)
  local totalWidth = unicode.wlen(prefix .. text)
  local width = gpu.getResolution()
  return math.ceil(totalWidth / width)
  end

  -- Track maximum lines used
  local maxLinesUsed = calculateLines(curtext)

  -- Function to redraw the input line with cursor
  local function redrawLine()
  local startX, startY = cursorPosX, cursorPosY

  -- Calculate current and max lines needed
  local currentLines = calculateLines(curtext)
  local linesToClear = math.max(maxLinesUsed, currentLines)

  -- Clear all potentially used lines
  for i = 0, linesToClear - 1 do
    termlib.cursorPosX, termlib.cursorPosY = 1, startY + i
    if startY + i <= height then
      local width = gpu.getResolution()
      termlib.write(string.rep(" ", width))
    end
  end

  -- Reset cursor to start position
  termlib.cursorPosX, termlib.cursorPosY = startX, startY

  -- Update tracking variables
  maxTextLength = math.max(maxTextLength, unicode.wlen(prefix .. curtext))
  maxLinesUsed = math.max(maxLinesUsed, currentLines)

  -- Draw text with cursor positioned correctly
  local beforeCursor = curtext:sub(1, utf8.offset(curtext, textCursorPos) - 1 or 0)
  local afterCursor = curtext:sub(utf8.offset(curtext, textCursorPos) or (#curtext + 1))

  termlib.write(prefix .. beforeCursor)
  termlib.write("\27[30m\27[107m" .. (afterCursor:sub(1, 1) ~= "" and afterCursor:sub(1, 1) or " ") .. "\27[0m") -- HUGE SHOUTOUT TO WAH FOR MAKING THE ESCAPE CODES WORK YEAAAAAAA
  termlib.write(afterCursor:sub(2))
  end

  redrawLine()
  local cursorWhite = true

  while true do
    local args = {event.pull("key_down", "clipboard", 0.5)}

    if args[1] == "key_down" and args[4] then
      cursorWhite = true
      local keycode = args[4]
      local key = keyboard.keys[keycode]

      -- Handle arrow keys
      if key == "up" and readHistoryType then
        RHIndex = RHIndex - 1
        if RHIndex <= 0 then
          RHIndex = 1
        end
        curtext = termlib.readHistory[readHistoryType][RHIndex]
        textCursorPos = unicode.wlen(curtext) + 1
        redrawLine()

      elseif key == "down" and readHistoryType then
        RHIndex = RHIndex + 1
        if RHIndex > #termlib.readHistory[readHistoryType] then
          RHIndex = #termlib.readHistory[readHistoryType]
        end
        curtext = termlib.readHistory[readHistoryType][RHIndex]
        textCursorPos = unicode.wlen(curtext) + 1
        redrawLine()

      elseif key == "left" then
        -- Move cursor left
        if textCursorPos > 1 then
          textCursorPos = textCursorPos - 1
          redrawLine()
        end

      elseif key == "right" then
        -- Move cursor right
        if textCursorPos <= unicode.wlen(curtext) then
          textCursorPos = textCursorPos + 1
          redrawLine()
        end

      elseif key == "home" then
        -- Move to beginning of line
        textCursorPos = 1
        redrawLine()

      elseif key == "end" then
        -- Move to end of line
        textCursorPos = unicode.wlen(curtext) + 1
        redrawLine()

      elseif key == "back" then
        -- Backspace - delete character before cursor
        if textCursorPos > 1 then
          local beforeCursor = curtext:sub(1, utf8.offset(curtext, textCursorPos - 1) - 1 or 0)
          local afterCursor = curtext:sub(utf8.offset(curtext, textCursorPos) or (#curtext + 1))
          curtext = beforeCursor .. afterCursor
          textCursorPos = textCursorPos - 1
          if readHistoryType then
            termlib.readHistory[readHistoryType][RHIndex] = curtext
          end
          redrawLine()
        end

      elseif key == "delete" then
        -- Delete - delete character at cursor
        if textCursorPos <= unicode.wlen(curtext) then
          local beforeCursor = curtext:sub(1, utf8.offset(curtext, textCursorPos) - 1 or 0)
          local afterCursor = curtext:sub(utf8.offset(curtext, textCursorPos + 1) or (#curtext + 1))
          curtext = beforeCursor .. afterCursor
          if readHistoryType then
            termlib.readHistory[readHistoryType][RHIndex] = curtext
          end
          redrawLine()
        end

      elseif key == "enter" then
        termlib.cursorPosX, termlib.cursorPosY = cursorPosX, cursorPosY
        print(prefix .. curtext .. " ")
        if readHistoryType then
          while #termlib.readHistory[readHistoryType] > 50 do
            table.remove(termlib.readHistory[readHistoryType], 1)
          end
        end
        return curtext


      elseif args[3] >= 32 and args[3] <= 126 then
        -- Insert character at cursor position
        local char = unicode.char(args[3]) or ""
        local beforeCursor = curtext:sub(1, utf8.offset(curtext, textCursorPos) - 1 or 0)
        local afterCursor = curtext:sub(utf8.offset(curtext, textCursorPos) or (#curtext + 1))
        curtext = beforeCursor .. char .. afterCursor
        textCursorPos = textCursorPos + 1
        if readHistoryType then
          termlib.readHistory[readHistoryType][RHIndex] = curtext
        end
        redrawLine()
      end

    elseif args[1] == "clipboard" then
      -- Handle clipboard paste
        local text = args[3] or ""
        local beforeCursor = curtext:sub(1, utf8.offset(curtext, textCursorPos) - 1 or 0)
        local afterCursor = curtext:sub(utf8.offset(curtext, textCursorPos) or (#curtext + 1))
        curtext = beforeCursor .. text .. afterCursor
        textCursorPos = textCursorPos + #text
        if readHistoryType then
          termlib.readHistory[readHistoryType][RHIndex] = curtext
        end
        redrawLine()

    else
      -- Cursor blink timing
      cursorWhite = not cursorWhite
      if cursorWhite then
        redrawLine()
      else
        -- Show cursor as normal character or space
        termlib.cursorPosX, termlib.cursorPosY = cursorPosX, cursorPosY
        local beforeCursor = curtext:sub(1, utf8.offset(curtext, textCursorPos) - 1 or 0)
        local afterCursor = curtext:sub(utf8.offset(curtext, textCursorPos) or (#curtext + 1))
        termlib.write(prefix .. beforeCursor)
        termlib.write(afterCursor:sub(1, 1) ~= "" and afterCursor:sub(1, 1) or " ")
        termlib.write(afterCursor:sub(2))
      end
    end
  end
end

local file = ...
local fs = import("filesystem")
local event = import("event")
local component = import("component")
local unicode = import("unicode")
local gpu = component.gpu
local width, height = gpu.getResolution()
local scrollPosX, scrollPosY = 1, 1
local cursorPosX, cursorPosY = 1, 1
local cursorWhite = true
local changesMade = false
local renderBuffer = gpu.allocateBuffer()
local scrollSpeed = 5
local tab = "  "
--local ocelot = component.ocelot

local function rawset(x, y, text)
  termlib.cursorPosX = x
  termlib.cursorPosY = y
  termlib.write(text, false)
end

local filestring, filepath, handle, data, tmpdata
if file then
  if file:sub(1, 1) == "/" then
    filepath = file
  else
    filepath = shell.workingDirectory .. file
  end
  handle, data, tmpdata = fs.open(filepath, "r"), "", nil
  if fs.exists(filepath) then
    filestring = filepath
    repeat
      tmpdata = handle:read(math.huge)
      data = data .. (tmpdata or "")
    until not tmpdata
    tmpdata = {}
    if data:gmatch("(.-)\n")() then
      for line in data:gmatch("(.-)\n") do
        local newLine = line:gsub("\r", "") -- this took me SO LONG TO FIGURE OUT AAAAAAAA I HATE CRLF I HATE CRLF I HATE CRLF
        table.insert(tmpdata, newLine)
      end
    else
      tmpdata = {data}
    end
  else
    filepath = shell.workingDirectory .. file
    filestring = "[NEW FILE]"
    tmpdata = {""}
  end
else
  filepath = ""
  filestring = "[NEW FILE]"
  tmpdata = {""}
end
local function render()
  gpu.setActiveBuffer(renderBuffer)
  clear()
  --ocelot.log(tostring(scrollPosY))
  local realCursorX = math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2)
  if realCursorX < 1 then
    scrollPosX = scrollPosX + realCursorX - 1
    cursorPosX = 1
    realCursorX = math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2)
  end
  for i = scrollPosY, height + scrollPosY - 3 do
    rawset(1, i - scrollPosY + 1, (tmpdata[i] or ""):sub(scrollPosX))
  end
  rawset(1, height - 1, "\27[107m\27[30m" .. filestring .. string.rep(" ", width))
  rawset(1, height, "\27[107m\27[30m^X\27[0m Exit  \27[107m\27[30m^S\27[0m Save" .. string.rep(" ", width))
  local char = gpu.get(realCursorX, cursorPosY)
  if cursorWhite then
    rawset(realCursorX, cursorPosY, "\27[107m\27[30m" .. char .. "\27[0m")
  else
    rawset(realCursorX, cursorPosY, char)
  end
  gpu.bitblt()
  gpu.setActiveBuffer(0)
end

local renderFlag, cursorRenderFlag = false, false

local function scrollUp()
  cursorPosY = cursorPosY - 1
  cursorRenderFlag = true
  cursorWhite = true
  if cursorPosY < 1 then
    renderFlag = true
    scrollPosY = scrollPosY - 1
    cursorPosY = 1
  end
  if scrollPosY < 1 then
    renderFlag = false
    scrollPosY = 1
  end
  if math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2) < 1 then
    renderFlag = true
  end
end

local function scrollDown()
  cursorPosY = cursorPosY + 1
  cursorRenderFlag = true
  cursorWhite = true
  if cursorPosY + scrollPosY - 1 > #tmpdata then
    renderFlag = false
    cursorPosY = #tmpdata - scrollPosY + 1
  end
  if cursorPosY > height - 2 then
    renderFlag = true
    scrollPosY = scrollPosY + 1
    cursorPosY = height - 2
  end
  if math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2) < 1 then
    renderFlag = true
  end
end

local function scrollLeft()
  cursorRenderFlag = true
  cursorWhite = true
  if cursorPosX > 1 then
    if cursorPosX <= unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2 then
      cursorPosX = cursorPosX - 1
    elseif unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 1 > 1 then
      cursorPosX = unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 1
    end
  elseif scrollPosX > 1 then
    scrollPosX = scrollPosX - 1
    renderFlag = true
  end
  if math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2) < 1 then
    renderFlag = true
  end
end

local function scrollRight()
  cursorRenderFlag = true
  cursorWhite = true
  if cursorPosX <= unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 1 then
    cursorPosX = cursorPosX + 1
  end
  if cursorPosX > width then
    cursorPosX = width
    scrollPosX = scrollPosX + 1
    renderFlag = true
  end
end

local function processEvent(args)
  renderFlag, cursorRenderFlag = false, false
  if args[1] == "key_down" then
    local keycode = args[4]
    local key = keyboard.keys[keycode]
    if keyboard.ctrlDown then
      return false, false, key
    end
    if key == "down" and cursorPosY < #tmpdata then
      scrollDown()
    end
    if key == "up" then
      scrollUp()
    end
    if key == "left" then
      scrollLeft()
    end
    if key == "right" then
      scrollRight()
    end
    if key == "enter" then
      changesMade = true
      renderFlag = true
      cursorWhite = true
      table.insert(tmpdata, cursorPosY + 1, tmpdata[cursorPosY + scrollPosY - 1]:sub(cursorPosX))
      tmpdata[cursorPosY + scrollPosY - 1] = tmpdata[cursorPosY + scrollPosY - 1]:sub(1, cursorPosX - 1)
      cursorPosX = 1
      cursorPosY = cursorPosY + 1
      scrollPosX = 1
      if cursorPosY > height - 2 then
        scrollPosY = scrollPosY + 1
        cursorPosY = height - 2
      end
    end
    if key == "back" then
      changesMade = true
      cursorRenderFlag = true
      cursorWhite = true
      if cursorPosX == 1 and cursorPosY + scrollPosY - 1 > 1 then
        cursorPosY = cursorPosY - 1
        if cursorPosY < 1 then
          scrollPosY = scrollPosY - 1
          cursorPosY = 1
        end
        if scrollPosY < 1 then
          scrollPosY = 1
        end
        cursorPosX = unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2
        if cursorPosX > width then
          scrollPosX = cursorPosX - width + 1
          cursorPosX = width
        end
        tmpdata[cursorPosY + scrollPosY - 1] = tmpdata[cursorPosY + scrollPosY - 1] .. tmpdata[cursorPosY + 1]
        table.remove(tmpdata, cursorPosY + 1)
        renderFlag = true
      else
        tmpdata[cursorPosY + scrollPosY - 1] = tmpdata[cursorPosY + scrollPosY - 1]:sub(1, cursorPosX + scrollPosX - 3) .. tmpdata[cursorPosY + scrollPosY - 1]:sub(cursorPosX + scrollPosX - 1)
        cursorPosX = math.min(cursorPosX - 1, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) + 1)
        if cursorPosX < 1 then
          cursorPosX = 1
          scrollPosX = scrollPosX - 1
          renderFlag = true
        else
          rawset(1, cursorPosY, tmpdata[cursorPosY + scrollPosY - 1]:sub(scrollPosX) .. " ")
        end
      end
    end
    if key == "tab" then
      changesMade = true
      cursorRenderFlag = true
      cursorWhite = true
      tmpdata[cursorPosY + scrollPosY - 1] = tmpdata[cursorPosY + scrollPosY - 1]:sub(1, cursorPosX + scrollPosX - 2) .. tab .. tmpdata[cursorPosY + scrollPosY - 1]:sub(cursorPosX + scrollPosX - 1)
      cursorPosX = cursorPosX + unicode.wlen(tab)
      if cursorPosX > width then
        scrollPosX = scrollPosX + cursorPosX - width
        cursorPosX = width
        renderFlag = true
      else
        rawset(1, cursorPosY, tmpdata[cursorPosY + scrollPosY - 1]:sub(scrollPosX))
      end
    end
    if args[3] >= 32 and args[3] <= 126 then
      changesMade = true
      cursorRenderFlag = true
      cursorWhite = true
      tmpdata[cursorPosY + scrollPosY - 1] = tmpdata[cursorPosY + scrollPosY - 1]:sub(1, cursorPosX + scrollPosX - 2) .. unicode.char(args[3]) .. tmpdata[cursorPosY + scrollPosY - 1]:sub(cursorPosX + scrollPosX - 1)
      cursorPosX = math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1])) + 1
      --ocelot.log(tostring(cursorPosX))
      if cursorPosX > width then
        cursorPosX = width
        scrollPosX = scrollPosX + 1
        renderFlag = true
      else
        rawset(1, cursorPosY, tmpdata[cursorPosY + scrollPosY - 1]:sub(scrollPosX))
      end
    end
  elseif args[1] == "scroll" then
    if args[5] == 1 then
      for i = 1, scrollSpeed do
        scrollUp()
      end
    elseif args[5] == -1 and cursorPosY < #tmpdata then
      for i = 1, scrollSpeed do
        scrollDown()
      end
    end
  end
  return renderFlag, cursorRenderFlag
end

local function save()
  rawset(1, height - 1, "\27[107m\27[30m" .. string.rep(" ", width))
  termlib.cursorPosX = 1
  termlib.cursorPosY = height - 1
  local savepath = read(nil, "\27[107m\27[30mSave location: ", filepath)
  if fs.exists(savepath) then
    rawset(1, height - 1, "\27[107m\27[30m" .. string.rep(" ", width))
    local answer = read(nil, "\27[107m\27[30mFile already exists. Overwrite it? [Y/n] ")
    if answer:lower() == "n" then
      rawset(1, height - 1, "\27[107m\27[30m" .. filestring .. string.rep(" ", width))
      return
    end
  end
  local handle, errorMessage = fs.open(savepath, "w")
  if handle then
    if table.concat(tmpdata, "\n"):sub(-1, -1) == "\n" then
      handle:write(table.concat(tmpdata, "\n"))
    else
      handle:write(table.concat(tmpdata, "\n") .. "\n") -- add a newline at the end to follow POSIX standards
    end
    handle:close()
    rawset(1, height - 1, "\27[107m\27[30m" .. filestring .. string.rep(" ", width))
  else
    rawset(1, height - 1, "\27[107m\27[30mERROR: " .. errorMessage:gsub("\n", "") .. string.rep(" ", width))
  end
  changesMade = false
end

render()
while true do
  local args = {event.pull(0.5)}
  local renderFlag, cursorRenderFlag, specialKey = false, false, nil
  local previousCursorX, previousCursorY = math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2), cursorPosY
  if args and args[1] then
    cursorWhite = true
    renderFlag, cursorRenderFlag, specialKey = processEvent(args)
    if specialKey == "x" then
      if changesMade then
        termlib.cursorPosX = 1
        termlib.cursorPosY = height - 1
        local response = read(nil, "\27[107m\27[30mWould you like to save changes? [Y/n] ")
        if response:lower() ~= "n" then
          save()
        end
      end
      gpu.freeAllBuffers()
      clear()
      return
    end
    if specialKey == "s" then
      save()
    end
    repeat
      args = {event.pull("key_down", 0)}
      if args and args[1] then
        processEvent(args)
      end
    until not args or not args[1]
  else
    cursorWhite = not cursorWhite
    cursorRenderFlag = true
  end
  if cursorRenderFlag then
    local char = gpu.get(previousCursorX, previousCursorY)
    rawset(previousCursorX, previousCursorY, char)
    local realCursorX = math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2)
    if realCursorX < 1 then
      scrollPosX = scrollPosX + realCursorX - 1
      cursorPosX = 1
      realCursorX = math.min(cursorPosX, unicode.wlen(tmpdata[cursorPosY + scrollPosY - 1]) - scrollPosX + 2)
    end
    local char = gpu.get(realCursorX, cursorPosY)
    if cursorWhite then
      rawset(realCursorX, cursorPosY, "\27[107m\27[30m" .. char .. "\27[0m")
    else
      rawset(realCursorX, cursorPosY, char)
    end
  end
  if renderFlag then
    render()
  end
end

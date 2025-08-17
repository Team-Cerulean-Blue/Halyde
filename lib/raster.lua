local raster = {
  ["units"]={},
  ["defaultBackgroundColor"]=0x000000,
  ["defaultForegroundColor"]=0xFFFFFF,
  ["displayWidth"]=0,
  ["displayHeight"]=0,
  ["charWidth"]=0,
  ["charHeight"]=0,
  ["backgroundColor"]=0xFFFFFF
}

local component = require("component")
-- local ocelot = component.proxy(component.list("ocelot")())
local gpu = component.gpu

local display = {}
local chunksAffected = {}

local renderBuffer = nil

-- braille rendering

function raster.units.charToBraille(x,y)
  return x*2,y*4
end

function raster.units.brailleToChar(x,y)
  return math.ceil(x/2),math.ceil(y/4)
end

function raster.init(width, height, bgcolor)
  -- NOTE: Width and height are in characters, not pixels in braille.
  -- If the width and height are nil, the entire screen will be used.
  if width==nil and height==nil then
    width, height = gpu.getResolution()
  end

  raster.charWidth = width
  raster.charHeight = height

  width, height = raster.units.charToBraille(width, height)
  
  bgcolor = bgcolor or raster.defaultBackgroundColor
  if bgcolor~=0 then
    for i=1,width*height do
      display[i]=bgcolor
    end
  end

  raster.displayWidth = width
  raster.displayHeight = height
  raster.backgroundColor = bgcolor

  pcall(function()
    renderBuffer = gpu.allocateBuffer()
  end)

  raster.clear()
end

function raster.set(x, y, color)
  if x<1 or x>raster.displayWidth or y<1 or y>raster.displayHeight then
    return false
  end

  color = color or raster.defaultForegroundColor
  local i = x+y*raster.displayWidth
  display[i] = color

  local ci = math.floor((x-1)/2)+math.floor((y-1)/4)*raster.charWidth+1
  -- ocelot.log(x..","..y..":"..ci)
  chunksAffected[ci] = true

  return true
end

function raster.get(x, y)
  local i = x+y*raster.displayWidth
  return display[i] or raster.backgroundColor
end

local function stats(arr)
  local out = {}
  for i=1,#arr do
    local v = arr[i]
    if out[v]==nil then
      out[v]=1
    else
      out[v] = out[v] + 1
    end
  end
  return out
end

local function getKeys(t)
  local keys = {}
  for k,v in pairs(t) do
    table.insert(keys,{k,v})
  end
  table.sort(keys,function(a,b)
    return a[2]>b[2]
  end)
  for i=1,#keys do
    keys[i] = keys[i][1]
  end
  return keys
end

local function colorDifference(a,b)
  return ((a>>16)&255)-((b>>16)&255)+((a>>8)&255)-((b>>8)&255)+(a&255)-(b&255)
end

local function limitTwoColors(arr)
  local colors = getKeys(stats(arr))
  for i=1,#arr do
    local v=arr[i]
    if v==colors[1] then
      arr[i]=0
      goto continue
    elseif v==colors[2] then
      arr[i]=1
      goto continue
    else
      --error("Pixel is not in the two colors (raster.lua:90)")
      -- get closest color so atleast it kinda shows
      if colorDifference(v,colors[1])<colorDifference(v,colors[2]) then
        arr[i]=0
      else
        arr[i]=1
      end
    end
    ::continue::
  end
  return arr,colors[1] or 0,colors[2] or 0
end

local function arrayToBraille(arr)
  local codePoint = 0x2800
  for i=1,8 do
    codePoint = codePoint | arr[i]<<(i-1)
  end
  if codePoint==0x2800 then return " " end
  return utf8.char(codePoint)
end

function raster.update()
  if renderBuffer~=nil then
    gpu.setActiveBuffer(renderBuffer)
  end
  for y=1,raster.displayHeight,4 do
    -- gpu.set(0,0,tostring(y))
    for x=1,raster.displayWidth,2 do
      local ci = math.floor(x/2)+math.floor(y/4)*raster.charWidth+1
      if chunksAffected[ci] then
        local chunk = {
          raster.get(x,y),
          raster.get(x,y+1),
          raster.get(x,y+2),
          raster.get(x+1,y),
          raster.get(x+1,y+1),
          raster.get(x+1,y+2),
          raster.get(x,y+3),
          raster.get(x+1,y+3)
        }
        local colorA = nil
        local colorB = nil
        chunk,colorA,colorB = limitTwoColors(chunk)
        -- print(tostring(colorA)..","..tostring(colorB))
        cx,cy=raster.units.brailleToChar(x,y)
        gpu.setBackground(colorA)
        gpu.setForeground(colorB)
        -- gpu.set(cx,cy,tostring(colorB/0xFFFFFF))
        gpu.set(cx,cy,arrayToBraille(chunk))
        chunksAffected[ci] = false
      end
    end
  end
  if renderBuffer~=nil then
    gpu.bitblt()
    gpu.setActiveBuffer(0)
  end
end

function raster.clear()
  if renderBuffer~=nil then
    gpu.setActiveBuffer(renderBuffer)
  end
  -- clear()
  local bgcolor = raster.backgroundColor
  gpu.setBackground(bgcolor)
  gpu.fill(1,1,raster.displayWidth,raster.displayHeight," ")
  display = {}
end

function raster.free()
  if renderBuffer==nil then
    return true
  else
    return gpu.freeBuffer(renderBuffer)
  end
end

-- advanced rendering

function raster.drawLine(x1, y1, x2, y2, color)
  x1, y1, x2, y2 = math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2)
  
  local dx = math.abs(x2 - x1)
  local dy = math.abs(y2 - y1)
  
  local sx = x1 < x2 and 1 or -1
  local sy = y1 < y2 and 1 or -1
  
  local err = dx - dy
  
  while true do
    raster.set(x1, y1, color)
    
    if x1 == x2 and y1 == y2 then
      break
    end
    
    local e2 = 2 * err
    
    if e2 > -dy then
      err = err - dy
      x1 = x1 + sx
    end
    
    if e2 < dx then
      err = err + dx
      y1 = y1 + sy
    end
  end
end

function raster.drawRect(x1,y1,x2,y2,col)
  x1, y1, x2, y2 = math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2)
  if x1 > x2 then x1, x2 = x2, x1 end
  if y1 > y2 then y1, y2 = y2, y1 end
  for x=x1,x2 do
    raster.set(x,y1,col)
    raster.set(x,y2,col)
  end
  for y=y1+1,y2-1 do
    raster.set(x1,y,col)
    raster.set(x2,y,col)
  end
end

function raster.fillRect(x1,y1,x2,y2,col)
  x1, y1, x2, y2 = math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2)
  if x1 > x2 then x1, x2 = x2, x1 end
  if y1 > y2 then y1, y2 = y2, y1 end
  for x=x1,x2 do
    for y=y1,y2 do
      raster.set(x,y,col)
    end
  end
end

function raster.drawCircle(xc, yc, radius, color)
  xc=math.floor(xc)
  yc=math.floor(yc)
  radius=math.floor(radius)
  local x = 0
  local y = radius
  local d = 3 - 2 * radius
  
  while y >= x do
    -- Draw 8 symmetric points
    raster.set(xc + x, yc + y, color)
    raster.set(xc - x, yc + y, color)
    raster.set(xc + x, yc - y, color)
    raster.set(xc - x, yc - y, color)
    raster.set(xc + y, yc + x, color)
    raster.set(xc - y, yc + x, color)
    raster.set(xc + y, yc - x, color)
    raster.set(xc - y, yc - x, color)
    
    if d < 0 then
      d = d + 4 * x + 6
    else
      d = d + 4 * (x - y) + 10
      y = y - 1
    end
    x = x + 1
  end
end

function raster.drawEllipse(x1, y1, x2, y2, color)
  if x1 > x2 then x1, x2 = x2, x1 end
  if y1 > y2 then y1, y2 = y2, y1 end
  
  local xc = math.floor((x1 + x2) / 2)
  local yc = math.floor((y1 + y2) / 2)
  
  local a = math.floor((x2 - x1) / 2)
  local b = math.floor((y2 - y1) / 2)
  
  if a <= 0 or b <= 0 then
    return
  end
  
  if a == b then
    raster.drawCircle(xc, yc, a, color)
    return
  end
  
  if a <= 1 and b <= 1 then
    raster.set(xc, yc, color)
    return
  elseif a <= 1 then
    for y = yc - b, yc + b do
        raster.set(xc, y, color)
    end
    return
  elseif b <= 1 then
    for x = xc - a, xc + a do
        raster.set(x, yc, color)
    end
    return
  end
  
  local x = 0
  local y = b
  local a2 = a * a
  local b2 = b * b
  
  local d1 = b2 - (a2 * b) + (0.25 * a2)
  local dx = 2 * b2 * x
  local dy = 2 * a2 * y
  
  while dx < dy do
    raster.set(xc + x, yc + y, color)
    raster.set(xc - x, yc + y, color)
    raster.set(xc + x, yc - y, color)
    
    if d1 < 0 then
      x = x + 1
      dx = dx + (2 * b2)
      d1 = d1 + dx + b2
    else
      x = x + 1
      y = y - 1
      dx = dx + (2 * b2)
      dy = dy - (2 * a2)
      d1 = d1 + dx - dy + b2
    end
  end
  
  local d2 = b2 * (x + 0.5) * (x + 0.5) + a2 * (y - 1) * (y - 1) - a2 * b2
  
  while y >= 0 do
    raster.set(xc + x, yc + y, color)
    raster.set(xc - x, yc + y, color)
    raster.set(xc + x, yc - y, color)
    raster.set(xc - x, yc - y, color)
    
    if d2 > 0 then
      y = y - 1
      dy = dy - (2 * a2)
      d2 = d2 - dy + a2
    else
      y = y - 1
      x = x + 1
      dx = dx + (2 * b2)
      dy = dy - (2 * a2)
      d2 = d2 + dx - dy + a2
    end
  end
end

function raster.fillCircle(x, y, r, color)
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  r = math.floor(r + 0.5)
  
  if r <= 0 then return end
  
  local minX, maxX = x - r, x + r
  local minY, maxY = y - r, y + r
  
  for py = minY, maxY do
    for px = minX, maxX do
      local dx, dy = px - x, py - y
      local distSquared = dx*dx + dy*dy
      
      if distSquared <= r*r then
        raster.set(px, py, color)
      end
    end
  end
end

function raster.fillEllipse(x1, y1, x2, y2, color)
  local centerX = (x1 + x2) / 2
  local centerY = (y1 + y2) / 2
  
  local a = math.abs(x2 - x1) / 2
  local b = math.abs(y2 - y1) / 2
  
  centerX = math.floor(centerX + 0.5)
  centerY = math.floor(centerY + 0.5)
  a = math.floor(a + 0.5)
  b = math.floor(b + 0.5)
  
  if a <= 0 or b <= 0 then return end
  
  if a == b then
    raster.fillCircle(centerX, centerY, a, color)
    return
  end
  
  local minX = centerX - a
  local maxX = centerX + a
  local minY = centerY - b
  local maxY = centerY + b
  
  for y = minY, maxY do
    for x = minX, maxX do
      local dx = x - centerX
      local dy = y - centerY
      local value = (dx*dx)/(a*a) + (dy*dy)/(b*b)
      
      if value <= 1 then
        raster.set(x, y, color)
      end
    end
  end
end

return raster

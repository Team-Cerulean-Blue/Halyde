local raster = import("raster")

raster.init()

--[[for i=4,20 do
    raster.set(i,i)
    raster.set(i,i+4,0xFF00FF)
end]]

--[[ for x=4,20 do
    for y=4,20 do
        if (x+y)%2==0 then
            raster.set(x,y,0xFF00FF)
        end
    end
end ]]

local event = import("event")
local x=0
local y=0
local vx=1
local vy=1
local col = 0x808080
local i=0

while event.pull("key_down",0)==nil do
    i = i + 1
    raster.set(x,y,col)

    x = x + vx
    y = y + vy

    if x>raster.displayWidth then
        x=raster.displayWidth
        vx = -math.abs(vx)
        col = math.random(0,0xFFFFFF)
    end
    if x<1 then
        x=1
        vx = math.abs(vx)
        col = math.random(0,0xFFFFFF)
    end
    if y>raster.displayHeight-6 then
        y=raster.displayHeight-6
        vy = -math.abs(vy)
        col = math.random(0,0xFFFFFF)
    end
    if y<1 then
        y=1
        vy = math.abs(vy)
        col = math.random(0,0xFFFFFF)
    end

    if i>10 and i%15>0 then
        while true do
            local tries=0
            local dx,dy=math.random(1,raster.displayWidth),math.random(1,raster.displayHeight-6)
            if raster.get(dx,dy)~=0 then
                raster.set(dx,dy,0)
                break
            end
            tries = tries + 1
            if tries>20 then
                break
            end
        end
    end

    if i%10==0 then
        raster.update()
        coroutine.yield()
    end
end

--[[ for i=0,360,4 do
    local angle = i/180*math.pi
    if false then
        local x1,y1,x2,y2=raster.displayWidth/2,raster.displayHeight/2,raster.displayWidth/2+math.sin(angle)*80,raster.displayHeight/2+math.cos(angle)*80
        raster.fillEllipse(x1,y1,x2,y2,0xFF00FF)
        raster.update()
        raster.fillEllipse(x1,y1,x2,y2,0x000000)
    else
        local x,y,c=raster.displayWidth/2,raster.displayHeight/2,math.abs(math.sin(angle)*100)
        raster.drawCircle(x,y,c,0xFF00FF)
        raster.update()
        raster.drawCircle(x,y,c,0x000000)
    end
end ]]

raster.free()
termlib.cursorPosY=1
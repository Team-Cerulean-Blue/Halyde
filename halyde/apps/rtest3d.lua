local component = import("component")
local computer = import("computer")
local raster = import("raster")
local event = import("event")

-- Initialize the 3D renderer for a spinning cube
-- Using the raster library for drawing

-- Screen dimensions
local SCREEN_WIDTH, SCREEN_HEIGHT = component.invoke(component.list("gpu")(), "getResolution")
SCREEN_WIDTH, SCREEN_HEIGHT = SCREEN_WIDTH * 2, SCREEN_HEIGHT * 4
local CENTER_X = SCREEN_WIDTH / 2
local CENTER_Y = SCREEN_HEIGHT / 2

-- Cube properties
local CUBE_SIZE = 10
local increment = 0
local WHITE = 0xFFFFFF
local ROTATION_SPEED = 0.1

-- 3D cube vertices (centered at origin)
local vertices = {
    {-CUBE_SIZE, -CUBE_SIZE, -CUBE_SIZE}, -- 0: left bottom back
    {CUBE_SIZE, -CUBE_SIZE, -CUBE_SIZE},  -- 1: right bottom back
    {CUBE_SIZE, CUBE_SIZE, -CUBE_SIZE},   -- 2: right top back
    {-CUBE_SIZE, CUBE_SIZE, -CUBE_SIZE},  -- 3: left top back
    {-CUBE_SIZE, -CUBE_SIZE, CUBE_SIZE},  -- 4: left bottom front
    {CUBE_SIZE, -CUBE_SIZE, CUBE_SIZE},   -- 5: right bottom front
    {CUBE_SIZE, CUBE_SIZE, CUBE_SIZE},    -- 6: right top front
    {-CUBE_SIZE, CUBE_SIZE, CUBE_SIZE}    -- 7: left top front
}

-- Cube edges defined by vertex indices
local edges = {
    {0, 1}, {1, 2}, {2, 3}, {3, 0}, -- back face
    {4, 5}, {5, 6}, {6, 7}, {7, 4}, -- front face
    {0, 4}, {1, 5}, {2, 6}, {3, 7}  -- connecting edges
}

-- Projection parameters
local FOV = 256         -- Field of view (distance from camera to screen)
local Z_OFFSET = 300    -- Distance from camera to cube center

-- Initialize rotation angles
local angleX, angleY, angleZ = 0, 0, 0

-- Matrix multiplication function (apply rotation to a 3D point)
local function rotatePoint(x, y, z)
    -- Rotation around X axis
    local cosX, sinX = math.cos(angleX), math.sin(angleX)
    local y1 = y * cosX - z * sinX
    local z1 = y * sinX + z * cosX
    
    -- Rotation around Y axis
    local cosY, sinY = math.cos(angleY), math.sin(angleY)
    local x1 = x * cosY + z1 * sinY
    local z2 = -x * sinY + z1 * cosY
    
    -- Rotation around Z axis
    local cosZ, sinZ = math.cos(angleZ), math.sin(angleZ)
    local x2 = x1 * cosZ - y1 * sinZ
    local y2 = x1 * sinZ + y1 * cosZ
    
    return x2, y2, z2
end

-- Perspective projection function (3D to 2D)
local function projectPoint(x, y, z)
    -- Apply perspective projection
    local scale = FOV / (z + Z_OFFSET)
    local x2d = x * scale + CENTER_X
    local y2d = y * scale + CENTER_Y
    
    return x2d, y2d
end

-- Render a single frame
local function renderFrame()
    local time = computer.uptime()*20
    increment = time*0.05 -- increment + 0.05
    CUBE_SIZE = (math.sin(increment) + 1) * 25
    vertices = {
      {-CUBE_SIZE, -CUBE_SIZE, -CUBE_SIZE}, -- 0: left bottom back
      {CUBE_SIZE, -CUBE_SIZE, -CUBE_SIZE},  -- 1: right bottom back
      {CUBE_SIZE, CUBE_SIZE, -CUBE_SIZE},   -- 2: right top back
      {-CUBE_SIZE, CUBE_SIZE, -CUBE_SIZE},  -- 3: left top back
      {-CUBE_SIZE, -CUBE_SIZE, CUBE_SIZE},  -- 4: left bottom front
      {CUBE_SIZE, -CUBE_SIZE, CUBE_SIZE},   -- 5: right bottom front
      {CUBE_SIZE, CUBE_SIZE, CUBE_SIZE},    -- 6: right top front
      {-CUBE_SIZE, CUBE_SIZE, CUBE_SIZE}    -- 7: left top front
    }
    -- Update rotation angles
    raster.clear()
    angleX = time * ROTATION_SPEED       -- angleX
    angleY = time * ROTATION_SPEED * 0.7 -- angleY
    angleZ = time * ROTATION_SPEED * 0.5 -- angleZ
    
    -- Project all vertices
    local projectedPoints = {}
    for i, vertex in ipairs(vertices) do
        -- Rotate the point
        local x, y, z = rotatePoint(vertex[1], vertex[2], vertex[3])
        
        -- Project the point to 2D
        local x2d, y2d = projectPoint(x, y, z)
        projectedPoints[i] = {x2d, y2d}
    end
    
    -- Draw all edges
    for _, edge in ipairs(edges) do
        local p1 = projectedPoints[edge[1] + 1] -- +1 because Lua indices start at 1
        local p2 = projectedPoints[edge[2] + 1]
        
        -- Draw the line
        raster.drawLine(p1[1], p1[2], p2[1], p2[2], WHITE)
    end
    
    -- Render the frame
    raster.update()
end

-- Main program
function main()
    -- Initialize raster engine
    raster.init()
    
    -- Main loop (assume this is called repeatedly by the host environment)
    while true do
      renderFrame()
      coroutine.yield()
      if event.pull("key_down", 0) then
        raster.free()
        break
      end
    end
    -- Return a reference to renderFrame so it can be called for animation
    return renderFrame
end

-- Start the program
return main()

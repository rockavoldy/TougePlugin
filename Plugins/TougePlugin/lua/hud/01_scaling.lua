-- Scaling
-- Layout values are written in reference pixels and scaled at draw time, so the HUD follows
-- window resizes. scaling.update() runs at the start of every frame.
local baseRes = vec2(2560, 1440) -- Reference resolution
local scaleFactor = 1

local scaling = {}

function scaling.update()
    scaleFactor = math.min(sim.windowWidth / baseRes.x, sim.windowHeight / baseRes.y, 1)
end

function scaling.vec2(x, y)
    return vec2(x, y) * scaleFactor
end

-- Scales a number or a vec2.
function scaling.size(size)
    return size * scaleFactor
end

function scaling.get()
    return scaleFactor
end

scaling.update()

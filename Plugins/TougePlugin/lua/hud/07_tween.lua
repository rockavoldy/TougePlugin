-- Small tween helper for fades and slide-ins. Each named tween runs from 0 (hidden) to 1
-- (shown) and back, so an element can keep drawing while it fades out.

local tweenValues = {}
local lastTweenDelta = 0 -- the frame time of the last update, shown by the mock panel

local function EaseOutCubic(t)
    return 1 - (1 - t) ^ 3
end

-- Moves the named tween towards 1 while shown and towards 0 while hidden, taking duration
-- seconds either way, and returns its eased value.
local function Tween(name, shown, duration)
    local value = tweenValues[name] or 0
    lastTweenDelta = ui.deltaTime()
    local step = lastTweenDelta / duration
    value = shown and math.min(1, value + step) or math.max(0, value - step)
    tweenValues[name] = value
    return EaseOutCubic(value)
end

-- Restarts the named tween from 0, for elements that animate in again when their content
-- changes.
local function RestartTween(name)
    tweenValues[name] = 0
end

-- Calls draw with every colour drawn through the helpers at the given opacity (0 to 1).
local function DrawFaded(alpha, draw)
    fadeAlpha = math.max(0, math.min(1, alpha))
    draw()
    fadeAlpha = 1
end

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

-- Calls draw, multiplying the alpha of everything it draws by alpha and shading it with
-- motion.fadeTint while it fades. size is the size of the current window (window units).
local function DrawFaded(alpha, size, draw)
    if alpha >= 1 then
        draw()
        return
    end
    ui.beginGradientShade()
    draw()
    local tint = layout.as6Panel.motion.fadeTint
    local shade = rgbm(tint.r, tint.g, tint.b, alpha)
    ui.endGradientShade(vec2(0, 0), size, shade, shade, true)
end

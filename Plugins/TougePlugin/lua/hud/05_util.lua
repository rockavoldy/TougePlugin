-- Utility functions

local function HsvToRgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b

    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x
    end

    return r + m, g + m, b + m
end

local function GetEloColor(eloValue)
    local hueValue = (eloValue / 2000) * 360 - 80
    local r, g, b = HsvToRgb(hueValue, 0.7, 0.8)
    return rgbm(r, g, b, 1)
end

-- Returns the largest font size (reference pixels) up to startSize at which text fits in
-- maxWidth reference pixels.
local function FindFontSize(text, startSize, textFont, maxWidth)
    ui.pushDWriteFont(textFont)
    local fontSize = startSize
    while fontSize > 8 and ui.measureDWriteText(text, scaling.size(fontSize)).x > scaling.size(maxWidth) do
        fontSize = fontSize - 2
    end
    ui.popDWriteFont()
    return fontSize
end

local function IsInRect(point, rectMin, rectMax)
    return point.x >= rectMin.x and point.x <= rectMax.x and point.y >= rectMin.y and point.y <= rectMax.y
end

-- Consumes this frame's click if it landed inside the rectangle.
local function ConsumeClickIn(mousePos, rectMin, rectMax)
    if not mouseClickHandled and ui.mouseClicked() and IsInRect(mousePos, rectMin, rectMax) then
        mouseClickHandled = true
        return true
    end
    return false
end

local function FindCarBySessionId(sessionId)
    for i = 0, sim.carsCount - 1 do
        local c = ac.getCar(i)
        if c ~= nil and c.sessionID == sessionId then
            return c
        end
    end
    return nil
end

-- Path of the skin preview of the car with the given session ID, or nil when that car or
-- every preview of it is missing. A missing or unknown skin falls back to the first skin
-- with a preview. Results are cached per car and skin.
local carPreviewCache = {}
local function GetCarPreviewPath(sessionId)
    local c = FindCarBySessionId(sessionId)
    if c == nil then
        return nil
    end
    local carId, skinId = ac.getCarID(c.index), ac.getCarSkinID(c.index) or ""
    if carId == nil then
        return nil
    end
    local key = carId .. "/" .. skinId
    if carPreviewCache[key] == nil then
        local skinsDir = ac.getFolder(ac.FolderID.ContentCars) .. "/" .. carId .. "/skins/"
        local path = skinsDir .. skinId .. "/preview.jpg"
        if skinId == "" or not io.fileExists(path) then
            path = io.scanDir(skinsDir, "*", function (fileName)
                local candidate = skinsDir .. fileName .. "/preview.jpg"
                return io.fileExists(candidate) and candidate or nil
            end)
        end
        carPreviewCache[key] = path or false
        ac.log("Touge car preview for " .. key .. ": " .. tostring(path))
    end
    return carPreviewCache[key] or nil
end

-- Name of the car with the given session ID, or nil when there is no such car.
local function GetCarNameBySessionId(sessionId)
    local c = FindCarBySessionId(sessionId)
    return c ~= nil and ac.getCarName(c.index) or nil
end

local function checkTimeout(activatedAt, duration)
    if activatedAt ~= nil and os.clock() - activatedAt >= duration then
        return true
    end
    return false
end

local function PlayCountdownSound()
    if countdownSoundPath == nil then
        return
    end

    if countdownSoundEvent ~= nil then
        pcall(countdownSoundEvent.dispose, countdownSoundEvent)
        countdownSoundEvent = nil
    end

    local ok, event = pcall(ac.AudioEvent.fromFile, { filename = countdownSoundPath, use3D = false, loop = false }, false)
    if ok and event ~= nil then
        countdownSoundEvent = event
        event.volume = event.volume * 5
        event:start()
    end
end

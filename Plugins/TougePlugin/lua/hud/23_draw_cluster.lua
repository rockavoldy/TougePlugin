-- Initial D in-race cluster: advantage number, Driver vs Rival names and the round results.
-- Coordinates are shell pixels (see layout.cluster); ClusterScale converts them to screen.

local function ClusterScale()
    return scaling.get() * layout.cluster.shellScale
end

-- Draws a sprite with its top-left corner at shell position pos (window units).
local function DrawSprite(image, pos, size, color, uvMax)
    local s = ClusterScale()
    local p1 = pos * s
    ui.drawImage(image, p1, p1 + size * s, color or rgbm(1, 1, 1, 1), vec2(0, 0), uvMax or vec2(1, 1))
end

-- Draws text centered in a shell rectangle, shrunk to fit its width but not below
-- minFontSize. Text that still does not fit is left-aligned and cut off at the rectangle.
local function DrawFittedText(text, textFont, fontSize, minFontSize, rectMin, rectMax, color)
    local shellScale = layout.cluster.shellScale
    local width = rectMax.x - rectMin.x
    local fitted = FindFontSize(text, fontSize * shellScale, textFont, width * shellScale)
    fitted = math.max(fitted, minFontSize * shellScale)
    local s = ClusterScale()

    ui.pushDWriteFont(textFont)
    local overflows = ui.measureDWriteText(text, scaling.size(fitted)).x > width * s
    local alignment = overflows and ui.Alignment.Start or ui.Alignment.Center
    ui.dwriteDrawTextClipped(text, scaling.size(fitted), rectMin * s, rectMax * s,
        alignment, ui.Alignment.Center, false, color)
    ui.popDWriteFont()
end

local function AdvantageColor(gapSeconds)
    if gapSeconds >= 0 then
        return rgbm(1, 1, 1, 1)
    end
    -- Fades from white to red as the gap grows, fully red at redAt.
    local t = math.min(gapSeconds / layout.cluster.advantage.redAt, 1)
    return rgbm(1, 1 - t, 1 - t, 1)
end

local function DrawAdvantage()
    local a = layout.cluster.advantage
    DrawSprite(a.image, a.pos, a.size)

    local gap = race.gapSeconds
    local pointSlot = a.pos + a.point
    local function IntegerSlot(indexFromRight)
        return a.pos + vec2(a.integerRight - indexFromRight * a.integerSize.x, a.integerY)
    end
    local function DecimalSlot(index)
        return a.pos + vec2(a.decimalX + (index - 1) * a.decimalSize.x, a.decimalY)
    end

    if gap == nil then
        -- Unknown gap: "--.--"
        for i = 1, 2 do
            DrawSprite(idSprites.minus, IntegerSlot(i), a.integerSize, a.unknownColor)
            DrawSprite(idSprites.minus, DecimalSlot(i), a.decimalSize, a.unknownColor)
        end
        DrawSprite(idSprites.pointM, pointSlot, a.pointSize, a.unknownColor, a.pointUvMax)
        return
    end

    local color = AdvantageColor(gap)
    local text = string.format("%.2f", math.min(math.abs(gap), 99.99))
    local whole, decimals = text:match("^(%d+)%.(%d%d)$")

    for i = 1, #whole do
        local digit = tonumber(whole:sub(-i, -i))
        DrawSprite(idSprites.digits[digit], IntegerSlot(i), a.integerSize, color)
    end
    DrawSprite(gap >= 0 and idSprites.plus or idSprites.minus, IntegerSlot(#whole + 1), a.integerSize, color)

    DrawSprite(idSprites.pointM, pointSlot, a.pointSize, color, a.pointUvMax)
    for i = 1, 2 do
        DrawSprite(idSprites.digits[tonumber(decimals:sub(i, i))], DecimalSlot(i), a.decimalSize, color)
    end
end

local function DrawNameRow(rowOffset, name, carName, position, carColor)
    local n = layout.cluster.names
    local origin = n.pos + vec2(0, rowOffset)

    if name ~= "" then
        DrawFittedText(name, fontSemiBold, n.nameFontSize, n.nameMinFontSize, origin + n.nameMin, origin + n.nameMax, rgbm(1, 1, 1, 1))
    end
    if carName ~= "" then
        DrawFittedText(carName, font, n.carFontSize, n.carMinFontSize, origin + n.carMin, origin + n.carMax, carColor)
    end

    local digit = position and idSprites.positionDigits[position] or idSprites.positionDash
    DrawSprite(digit, origin + n.position, n.positionSize)
end

local function DrawNames()
    local n = layout.cluster.names
    DrawSprite(n.image, n.pos, n.size)

    local rivalPosition = race.position and (3 - race.position) or nil
    DrawNameRow(0, race.driverName, race.driverCarName, race.position, n.driverCarColor)
    DrawNameRow(n.rivalOffset, race.rivalName, race.rivalCarName, rivalPosition, n.rivalCarColor)
end

local function DrawRounds()
    local r = layout.cluster.rounds
    local s = ClusterScale()

    local label = "ROUNDS"
    if currentHudState == HudStates.SuddenDeath then
        label = "SUDDEN DEATH"
    elseif currentHudState == HudStates.Finished then
        -- This needs revisiting for different rulesets, as in the old standings panel.
        label = standings[3] == RaceResults.Win and "YOU WIN" or "YOU LOSE"
    end
    ui.pushDWriteFont(fontSemiBold)
    ui.dwriteDrawText(label, scaling.size(r.labelFontSize * layout.cluster.shellScale), r.label * s, r.labelColor)
    ui.popDWriteFont()

    local pips = currentHudState == HudStates.FirstTwo and 2 or 3
    for i = 1, pips do
        local x = r.pipsRight - (pips - i + 1) * r.pipSize.x - (pips - i) * r.pipSpacing
        local pipMin = vec2(x, r.y) * s
        local pipMax = pipMin + r.pipSize * s
        local rounding = r.pipSize.y * s / 2

        local result = standings[i]
        local fill = r.pending
        if result == RaceResults.Win then
            fill = r.win
        elseif result == RaceResults.Loss then
            fill = r.loss
        elseif result == RaceResults.Tie then
            fill = r.tie
        end
        ui.drawRectFilled(pipMin, pipMax, fill, rounding)
        ui.drawRect(pipMin, pipMax, r.border, rounding)
    end
end

local function DrawCluster()
    if not useIdCluster or currentHudState == HudStates.Off or idSprites == nil then
        return
    end

    local c = layout.cluster
    local size = c.size * ClusterScale()
    local pos = vec2(windowWidth - scaling.size(c.marginRight) - size.x, scaling.size(c.marginTop))
    ui.transparentWindow("idClusterWindow", pos, size, function ()
        DrawAdvantage()
        DrawNames()
        DrawRounds()
    end)
end

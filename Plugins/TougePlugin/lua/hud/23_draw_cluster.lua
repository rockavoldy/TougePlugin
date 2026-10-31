-- Initial D in-race cluster: advantage number, Driver vs Rival names and the round results.
-- Coordinates are shell pixels (see layout.cluster and 06_shell.lua).

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
    DrawShellSprite(a.image, a.pos, a.size)

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
            DrawShellSprite(idSprites.minus, IntegerSlot(i), a.integerSize, a.unknownColor)
            DrawShellSprite(idSprites.minus, DecimalSlot(i), a.decimalSize, a.unknownColor)
        end
        DrawShellSprite(idSprites.pointM, pointSlot, a.pointSize, a.unknownColor, a.pointUvMax)
        return
    end

    local color = AdvantageColor(gap)
    local text = string.format("%.2f", math.min(math.abs(gap), 99.99))
    local whole, decimals = text:match("^(%d+)%.(%d%d)$")

    for i = 1, #whole do
        local digit = tonumber(whole:sub(-i, -i))
        DrawShellSprite(idSprites.digits[digit], IntegerSlot(i), a.integerSize, color)
    end
    DrawShellSprite(gap >= 0 and idSprites.plus or idSprites.minus, IntegerSlot(#whole + 1), a.integerSize, color)

    DrawShellSprite(idSprites.pointM, pointSlot, a.pointSize, color, a.pointUvMax)
    for i = 1, 2 do
        DrawShellSprite(idSprites.digits[tonumber(decimals:sub(i, i))], DecimalSlot(i), a.decimalSize, color)
    end
end

local function DrawNameRow(rowOffset, name, carName, position, carColor)
    local n = layout.cluster.names
    local origin = n.pos + vec2(0, rowOffset)

    if name ~= "" then
        DrawShellText(name, fontSemiBold, n.nameFontSize, n.nameMinFontSize, origin + n.nameMin, origin + n.nameMax, rgbm(1, 1, 1, 1))
    end
    if carName ~= "" then
        DrawShellText(carName, font, n.carFontSize, n.carMinFontSize, origin + n.carMin, origin + n.carMax, carColor)
    end

    local digit = position and idSprites.positionDigits[position] or idSprites.positionDash
    DrawShellSprite(digit, origin + n.position, n.positionSize)
end

local function DrawNames()
    local n = layout.cluster.names
    DrawShellSprite(n.image, n.pos, n.size)

    local rivalPosition = race.position and (3 - race.position) or nil
    DrawNameRow(0, race.driverName, race.driverCarName, race.position, n.driverCarColor)
    DrawNameRow(n.rivalOffset, race.rivalName, race.rivalCarName, rivalPosition, n.rivalCarColor)
end

local function DrawRounds()
    local r = layout.cluster.rounds
    local s = ShellScale()

    local label = "ROUNDS"
    local labelColor = r.labelColor
    if currentHudState == HudStates.SuddenDeath then
        label = "SUDDEN DEATH"
    elseif currentHudState == HudStates.Finished then
        -- This needs revisiting for different rulesets, as in the old standings panel.
        local won = standings[3] == RaceResults.Win
        label = won and "YOU WIN" or "YOU LOSE"
        labelColor = won and r.win or r.loss
    end
    ui.pushDWriteFont(fontSemiBold)
    ui.dwriteDrawText(label, scaling.size(r.labelFontSize * layout.shellScale), r.label * s, labelColor)
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
    if currentHudState == HudStates.Off or idSprites == nil then
        return
    end

    local c = layout.cluster
    local size = c.size * ShellScale()
    local pos = vec2(windowWidth - scaling.size(c.marginRight) - size.x, scaling.size(c.marginTop))
    ui.transparentWindow("idClusterWindow", pos, size, function ()
        DrawAdvantage()
        DrawNames()
        DrawRounds()
    end)
end

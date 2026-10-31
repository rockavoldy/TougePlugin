-- Always-on elements: standings, Elo, tutorial and countdown.

local function DrawStandings()
    -- Replaced by the round results in the Initial D cluster.
    if useIdHud or currentHudState == HudStates.Off then
        return
    end

    local l = layout.standings
    local size = scaling.size(l.size)
    ui.transparentWindow("standingsWindow", vec2(scaling.size(l.marginLeft), windowHeight / 2), size, function()
        ui.drawImage(l.image, vec2(0, 0), size)
        if currentHudState == HudStates.FirstTwo or currentHudState == HudStates.CatAndMouse then
            DrawText("Standings", fontSemiBold, 48, scaling.size(l.title))

            local dots = 2
            if currentHudState == HudStates.CatAndMouse then dots = 3 end

            -- Circles are horizontally centered
            local circleRadius = scaling.size(l.pipRadius)
            local spacing = scaling.size(l.pipSpacing)
            local totalWidth = (dots * 2 * circleRadius) + (dots - 1) * spacing
            local xStart = (size.x - totalWidth) / 2 + circleRadius

            for i = 1, dots do
                local result = standings[i]
                local xPos = xStart + (2 * circleRadius + spacing) * (i - 1)
                -- Set color based on result
                local color
                if result == RaceResults.Tbd then
                    color = rgbm(0.5, 0.5, 0.5, 0.1) -- Gray for not played
                elseif result == RaceResults.Win then
                    color = rgbm(0.561, 0.651, 0.235, 1) -- Green for won
                elseif result == RaceResults.Loss then
                    color = rgbm(0.349, 0.0078, 0.0078, 1) -- Red for lost
                else
                    color = rgbm(0.5, 0.5, 0.5, 0.7) -- Dark grey for tie
                end
                ui.drawCircleFilled(vec2(xPos, scaling.size(l.pipY)), circleRadius, color, 32)
            end
        elseif currentHudState == HudStates.SuddenDeath then
            DrawText("Sudden Death!", fontBold, 32, scaling.size(l.suddenDeathTitle))
            DrawText("First player to win a round.", font, 18, scaling.size(l.suddenDeathBody))
        elseif currentHudState == HudStates.Finished then -- This needs revisiting for different rulesets.
            if standings[3] == RaceResults.Win then
                DrawText("You win!", fontBold, 32, scaling.size(l.result))
            else
                DrawText("You lose.", fontBold, 32, scaling.size(l.result))
            end
        end
    end)
end

local function DrawEloRow()
    local l = layout.eloRow
    ui.transparentWindow("eloWindow", scaling.size(l.pos), l.size * ShellScale(), function ()
        local displayElo = math.floor(elo + 0.5)
        DrawShellSprite(l.image, vec2(0, 0), l.size)
        -- The Elo colour goes on the label: tinting the chrome digits makes them unreadable
        -- on the navy band for most colours.
        DrawShellLabel("ELO", l.label, l.labelFontSize, GetEloColor(displayElo))
        DrawShellText(ac.getDriverName(0), fontSemiBold, l.nameFontSize, l.nameMinFontSize, l.nameMin, l.nameMax, rgbm(1, 1, 1, 1))
        DrawShellNumber(displayElo, l.digitsCenterX, l.digitsY, l.digitSize)
    end)
end

local function DrawElo()
    if elo == -1 or not showElo then
        return
    end

    if useIdHud then
        -- Waits for the digit sprites rather than flashing the old badge first.
        if idSprites ~= nil then
            DrawEloRow()
        end
        return
    end

    local l = layout.elo
    local size = scaling.size(l.size)
    ui.transparentWindow("eloWindow", scaling.size(l.pos), size, function ()
        local displayElo = math.floor(elo + 0.5)
        ui.drawImage(l.image, vec2(0, 0), size, GetEloColor(displayElo))
        DrawText("Elo", font, 24, scaling.size(l.label))

        local numberPos = displayElo >= 1000 and l.number or l.numberBelow1000
        DrawText(displayElo, fontBold, 34, scaling.size(numberPos))
    end)
end

-- Draws a key cap with its top-left corner at pos (window units).
local function DrawKey(key, pos)
    local keys = layout.tutorial.keys
    local imageSize = scaling.size(vec2(keys.size, keys.size))
    ui.drawImage(keys.image, pos, pos + imageSize)

    ui.pushDWriteFont(fontBold)
    local fontSize = scaling.size(keys.fontSize)
    local keySize = ui.measureDWriteText(key, fontSize)
    ui.dwriteDrawText(key, fontSize, pos + (imageSize - keySize) / 2)
    ui.popDWriteFont()
end

local function DrawTutorial()
    if hasTutorialHidden then
        return
    end
    -- Once auto-hidden, the tutorial only shows while the car is (nearly) stopped.
    if isTutorialAutoHidden and not (car ~= nil and car.speedKmh < 10) then
        return
    end

    local l = layout.tutorial
    local size = scaling.size(l.size)
    local pos = vec2(scaling.size(l.marginLeft), windowHeight - scaling.size(l.marginBottom) - size.y)
    ui.transparentWindow("tutorialWindow", pos, size, function ()
        ui.drawImage(l.image, vec2(0, 0), size)
        DrawText("How to play", fontSemiBold, 24, scaling.size(l.title))

        local tutorialText = "To start a race, either invite an opponent through the invite\nmenu or invite a nearby player.\n\nBeat your opponent to gain elo."
        DrawText(tutorialText, font, 14, scaling.size(l.body))
        DrawText("Controls", fontSemiBold, 24, scaling.size(l.controlsTitle))

        local keys = l.keys
        for i, binding in ipairs(keyBindings) do
            local keyPos = scaling.size(keys.first + vec2((i - 1) * keys.spacingX, 0))
            DrawKey(binding.key, keyPos)
            DrawText(binding.description, fontSemiBold, keys.labelFontSize, keyPos + scaling.size(keys.label))
        end
    end)
end

local function DrawCountdown()
    if not isCountdownHudActive then
        return
    end

    local fontSize = layout.countdown.fontSize
    ui.pushDWriteFont(fontBold)
    local textSize = ui.measureDWriteText(countdownHudMessage, scaling.size(fontSize))
    ui.popDWriteFont()

    -- Centered on the screen
    local textPos = (vec2(windowWidth, windowHeight) - textSize) / 2
    ui.transparentWindow("countdownWindow", textPos, textSize + vec2(8, 8), function ()
        DrawText(countdownHudMessage, fontBold, fontSize, vec2(0, 0))
    end)
end

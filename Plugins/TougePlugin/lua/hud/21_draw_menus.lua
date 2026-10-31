-- Right-hand panel: invite menu and course select.

-- Number of filled nearby player slots; empty slots have an empty name.
local function CountNearbyPlayers()
    local playerCount = 0
    while playerCount < 5 and nearbyPlayers[playerCount + 1] and nearbyPlayers[playerCount + 1].name ~= "" do
        playerCount = playerCount + 1
    end
    return playerCount
end

local function ChooseNearbyPlayer(player)
    hasInviteMenuOpen = false
    if #courseNames > 1 then
        -- Show a menu to choose from the different courses.
        hasCourseSelectOpen = true
        selectedPlayerId = player.id
        courseScroll = 0
    else
        SendToServer(inviteEvent, {inviteSenderName = "", inviteRecipientGuid = player.id, isCourse = isToggleCourse})
    end
end

local function ChooseCourse(course)
    SendToServer(inviteEvent, {inviteSenderName = "", inviteRecipientGuid = selectedPlayerId, courseName = course, isCourse = isToggleCourse})
    hasCourseSelectOpen = false
end

local function PanelPos()
    local p = layout.panel
    return vec2(windowWidth - scaling.size(p.marginRight + p.size.x), scaling.size(p.marginTop))
end

-- Top-left corner (window units) of the index-th row in the panel.
local function CardPos(index)
    local p = layout.panel
    return scaling.vec2(layout.card.x, p.listTop + (index - 1) * p.rowSpacing)
end

-- Draws a row card and returns its bottom-right corner (window units).
local function DrawCard(cardPos)
    local cardMax = cardPos + scaling.size(layout.card.size)
    ui.drawImage(layout.card.image, cardPos, cardMax)
    return cardMax
end

local function DrawCardName(text, cardPos, color)
    local c = layout.card
    local fontSize = FindFontSize(text, c.nameFontSize, fontBold, c.nameMaxWidth)
    local textMin = cardPos + scaling.size(c.name)

    ui.pushDWriteFont(fontBold)
    ui.dwriteDrawTextClipped(text, scaling.size(fontSize), textMin, textMin + scaling.size(c.nameClip),
        ui.Alignment.Start, ui.Alignment.Start, false, color or rgbm(1, 1, 1, 1))
    ui.popDWriteFont()
end

local function DrawRaceTypeToggle(mousePos)
    local t = layout.panel.toggle
    local toggleMin = scaling.size(t.min)
    local toggleMax = scaling.size(t.max)

    -- Drawn flipped when Outrun is selected.
    if isToggleCourse then
        ui.drawImage(t.image, toggleMin, toggleMax)
    else
        ui.drawImage(t.image, toggleMax, toggleMin)
    end

    if ConsumeClickIn(mousePos, toggleMin, toggleMax) then
        isToggleCourse = not isToggleCourse
    end

    DrawText("Course", fontSemiBold, t.fontSize, scaling.size(t.courseLabel))
    DrawText("Outrun", fontSemiBold, t.fontSize, scaling.size(t.outrunLabel))
end

local function DrawInviteMenu()
    if not hasInviteMenuOpen then
        return
    end

    local p = layout.panel
    local size = scaling.size(p.size)
    ui.transparentWindow("inviteWindow", PanelPos(), size, function ()
        ui.drawImage(p.image, vec2(0, 0), size)
        local mousePos = ui.mouseLocalPos()

        if nearbyPlayers[1] ~= nil and nearbyPlayers[1].name == "" then
            DrawText("No other players online", font, p.titleFontSize, scaling.size(p.title))
        end

        local playerCount = CountNearbyPlayers()

        if playerCount > 0 then
            DrawText("Nearby", font, p.titleFontSize, scaling.size(p.title))
            if showRaceTypeToggle then
                DrawRaceTypeToggle(mousePos)
            end
        end

        for index = 1, playerCount do
            local player = nearbyPlayers[index]
            local cardPos = CardPos(index)
            local cardMax = DrawCard(cardPos)

            if ConsumeClickIn(mousePos, cardPos, cardMax) then
                ChooseNearbyPlayer(player)
            end

            DrawAvatar(player.id, cardPos)
            DrawCardName(player.name, cardPos, player.inRace and rgbm(0.5, 0.5, 0.5, 1) or rgbm(1, 1, 1, 1))
            DrawEloBadge(player.elo, cardPos + scaling.size(layout.card.eloBadge))
        end
    end)
end

local function DrawCourseSelect()
    if not hasCourseSelectOpen then
        return
    end

    local p = layout.panel
    local size = scaling.size(p.size)
    ui.transparentWindow("courseSelectWindow", PanelPos(), size, function ()
        ui.drawImage(p.image, vec2(0, 0), size)
        DrawText("Select a course", font, p.titleFontSize, scaling.size(p.title))

        ui.childWindow("coursesListWindow", scaling.size(p.scrollSize), function ()
            -- The inner window is as tall as the whole list, so the outer one scrolls.
            local listHeight = p.listTop + #courseNames * p.rowSpacing
            ui.childWindow("actualList", scaling.vec2(p.size.x, listHeight), function ()
                local mousePos = ui.mouseLocalPos()
                for index, course in ipairs(courseNames) do
                    local cardPos = CardPos(index)
                    local cardMax = DrawCard(cardPos)

                    if ConsumeClickIn(mousePos, cardPos, cardMax) then
                        ChooseCourse(course)
                    end

                    DrawCardName(course, cardPos)
                end
            end)
        end)
    end)
end

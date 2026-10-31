-- Initial D invite menu and course select: a title row and a stack of label-less name rows,
-- anchored top-right. Rows brighten under the mouse. Coordinates are shell pixels.

-- Screen position and size of a panel with the title row and rowCount list rows.
local function IdPanelRect(rowCount)
    local p = layout.idPanel
    local size = vec2(p.rowSize.x, p.listTop + math.max(rowCount - 1, 0) * p.rowStep + p.rowSize.y) * ShellScale()
    return vec2(windowWidth - scaling.size(p.marginRight) - size.x, scaling.size(p.marginTop)), size
end

-- Draws the frosted backdrop over the whole window at windowPos (screen units). The scene
-- texture needs CSP's Graphics Adjustment; without it only the dark layer shows.
local function DrawIdBackdrop(windowPos, size)
    local b = layout.idPanel.backdrop
    if ui.isImageReady('dynamic::screen') then
        local screen = vec2(sim.windowWidth, sim.windowHeight)
        ui.beginBlurring()
        ui.drawImage('dynamic::screen', vec2(0, 0), size, rgbm(1, 1, 1, 1), windowPos / screen, (windowPos + size) / screen)
        ui.endBlurring(b.blur * ShellScale())
    end
    ui.drawRectFilled(vec2(0, 0), size, b.tint)
end

-- Draws a row with its top at shell y. Clickable rows brighten under the mouse; returns
-- true when the row was clicked this frame.
local function DrawIdRow(y, mousePos, clickable)
    local p = layout.idPanel
    local origin = vec2(0, y)
    DrawShellSprite(p.rowImage, origin, p.rowSize)
    if not clickable then
        return false
    end

    local s = ShellScale()
    local hoverMin = (origin + p.hoverMin) * s
    local hoverMax = (origin + p.hoverMax) * s
    if IsInRect(mousePos, hoverMin, hoverMax) then
        ui.drawRectFilled(hoverMin, hoverMax, p.hoverColor)
        ui.setMouseCursor(ui.MouseCursor.Hand)
    end
    return ConsumeClickIn(mousePos, hoverMin, hoverMax)
end

local function DrawIdTitle(label, title, mousePos, bandText)
    local p = layout.idPanel
    DrawIdRow(0, mousePos, false)
    DrawShellLabel(label, p.label, p.labelFontSize, p.labelColor)
    DrawShellText(title, fontSemiBold, p.nameFontSize, p.nameMinFontSize, p.nameMin, p.nameMax, p.textColor)
    if bandText ~= nil then
        DrawShellText(bandText, font, p.bandFontSize, p.bandMinFontSize, p.bandMin, p.bandMax, p.bandTextColor)
    end
end

-- Course / Outrun switch in the band of the title row.
local function DrawIdRaceTypeToggle(mousePos)
    local t = layout.idPanel.toggle
    local s = ShellScale()
    local middle = (t.min.x + t.max.x) / 2
    local halves = {
        { text = "COURSE", isCourse = true, min = t.min, max = vec2(middle, t.max.y) },
        { text = "OUTRUN", isCourse = false, min = vec2(middle, t.min.y), max = t.max },
    }

    for _, half in ipairs(halves) do
        local selected = isToggleCourse == half.isCourse
        local halfMin = half.min * s
        local halfMax = half.max * s
        ui.drawRectFilled(halfMin, halfMax, selected and t.selected or t.idle, t.rounding * s)
        if not selected and IsInRect(mousePos, halfMin, halfMax) then
            ui.setMouseCursor(ui.MouseCursor.Hand)
            if ConsumeClickIn(mousePos, halfMin, halfMax) then
                isToggleCourse = half.isCourse
            end
        end
        local textColor = selected and rgbm(1, 1, 1, 1) or rgbm(1, 1, 1, 0.6)
        DrawShellText(half.text, fontSemiBold, t.fontSize, t.fontSize, half.min, half.max, textColor)
    end
    ui.drawRect(t.min * s, t.max * s, t.border, t.rounding * s)
end

local function DrawIdInviteMenu()
    if not hasInviteMenuOpen or idSprites == nil then
        return
    end

    local p = layout.idPanel
    local playerCount = CountNearbyPlayers()
    local pos, size = IdPanelRect(playerCount)
    ui.transparentWindow("inviteWindow", pos, size, function ()
        DrawIdBackdrop(pos, size)
        local mousePos = ui.mouseLocalPos()

        local title = "Challenge a driver"
        if nearbyPlayers[1] == nil then
            title = "Looking for drivers..." -- waiting for the lobby status
        elseif playerCount == 0 then
            title = "No other players online"
        end
        local showToggle = showRaceTypeToggle and playerCount > 0
        DrawIdTitle("NEARBY", title, mousePos, not showToggle and "Press I to close" or nil)
        if showToggle then
            DrawIdRaceTypeToggle(mousePos)
        end

        for index = 1, playerCount do
            local player = nearbyPlayers[index]
            local y = p.listTop + (index - 1) * p.rowStep
            local origin = vec2(0, y)
            if DrawIdRow(y, mousePos, true) then
                ChooseNearbyPlayer(player)
            end

            -- Skipped until the avatar has loaded, so a missing one leaves no black square.
            local avatarPath = GetAvatarPath(player.id)
            if loadSteamAvatars and ui.isImageReady(avatarPath) then
                DrawShellSprite(avatarPath, origin + p.avatar, vec2(p.avatarSize, p.avatarSize))
            end

            -- Players already in a race are greyed out, as in the old menu.
            local label, labelColor, nameColor = "ELO", GetEloColor(player.elo), p.textColor
            if player.inRace then
                label, labelColor, nameColor = "IN RACE", p.busyColor, p.busyColor
            end
            DrawShellLabel(label, origin + p.label, p.labelFontSize, labelColor)
            DrawShellText(player.name, fontSemiBold, p.nameFontSize, p.nameMinFontSize, origin + p.nameMin, origin + p.nameMax, nameColor)
            DrawShellNumber(player.elo, p.digitsCenterX, y + p.digitsY, p.digitSize)
        end
    end)
end

local function DrawIdCourseSelect()
    if not hasCourseSelectOpen or idSprites == nil then
        return
    end

    local p = layout.idPanel
    local visibleRows = math.min(#courseNames, p.maxVisibleRows)
    local maxScroll = #courseNames - visibleRows
    local pos, size = IdPanelRect(visibleRows)
    ui.transparentWindow("courseSelectWindow", pos, size, function ()
        DrawIdBackdrop(pos, size)
        local mousePos = ui.mouseLocalPos()

        -- Longer lists scroll a whole row per wheel step (where this CSP build supports it).
        if maxScroll > 0 and ui.mouseWheel ~= nil and ui.windowHovered ~= nil and ui.windowHovered() then
            courseScroll = math.max(0, math.min(maxScroll, courseScroll - ui.mouseWheel()))
        end

        local bandText = maxScroll > 0 and "Scroll for more courses" or "Press I to cancel"
        DrawIdTitle("COURSE", "Select a course", mousePos, bandText)

        local raceType = isToggleCourse and "Course race" or "Outrun race"
        for row = 1, visibleRows do
            local course = courseNames[row + courseScroll]
            local y = p.listTop + (row - 1) * p.rowStep
            local origin = vec2(0, y)
            if DrawIdRow(y, mousePos, true) then
                ChooseCourse(course)
            end

            DrawShellLabel("COURSE", origin + p.label, p.labelFontSize, p.labelColor)
            DrawShellText(course, fontSemiBold, p.nameFontSize, p.nameMinFontSize, origin + p.nameMin, origin + p.nameMax, p.textColor)
            DrawShellText(raceType, font, p.bandFontSize, p.bandMinFontSize, origin + p.bandMin, origin + p.bandMax, p.bandTextColor)
        end
    end)
end

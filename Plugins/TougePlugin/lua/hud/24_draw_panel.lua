-- Invite menu and course select in the style of the Initial D Arcade Stage 6 menus (see
-- layout.as6Panel): a silver title bar, a subtitle pill and white cards that get a gold
-- frame under the mouse. Drawn in code as a placeholder; coordinates are shell pixels.

local function Fill(min, max, color, rounding)
    local s = ShellScale()
    ui.drawRectFilled(min * s, max * s, color, (rounding or 0) * s)
end

local function Outline(min, max, color, rounding, thickness)
    local s = ShellScale()
    ui.drawRect(min * s, max * s, color, (rounding or 0) * s, ui.CornerFlags.All, (thickness or 1) * s)
end

local function VerticalGradient(min, max, top, bottom)
    local s = ShellScale()
    ui.drawRectFilledMultiColor(min * s, max * s, top, top, bottom, bottom)
end

-- Screen position and size of a panel with cardCount cards starting at shell y listTop.
local function As6PanelRect(listTop, cardCount)
    local p = layout.as6Panel
    local height = listTop + cardCount * p.card.step + p.bottomPadding
    local size = vec2(p.width, height) * ShellScale()
    return vec2(windowWidth - scaling.size(p.marginRight) - size.x, scaling.size(p.marginTop)), size
end

-- Frosted backdrop over the whole window at windowPos (screen units). The scene texture
-- needs CSP's Graphics Adjustment; without it only the light layer shows.
local function DrawAs6Backdrop(windowPos, size)
    local b = layout.as6Panel.backdrop
    local s = ShellScale()
    if ui.isImageReady('dynamic::screen') then
        local screen = vec2(sim.windowWidth, sim.windowHeight)
        ui.beginBlurring()
        ui.drawImage('dynamic::screen', vec2(0, 0), size, rgbm(1, 1, 1, 1), windowPos / screen, (windowPos + size) / screen)
        ui.endBlurring(b.blur * s)
    end
    ui.drawRectFilled(vec2(0, 0), size, b.tint, b.rounding * s)
    ui.drawRect(vec2(0, 0), size, b.border, b.rounding * s)
end

local function DrawAs6Header(title, subtitle)
    local p = layout.as6Panel
    local t = p.title
    VerticalGradient(t.min, t.max, t.top, t.bottom)
    Fill(t.min, vec2(t.max.x, t.min.y + 2), t.highlight)
    DrawShellText(title, fontBold, t.fontSize, t.fontSize, t.min, t.max, t.color)

    local st = p.subtitle
    local radius = (st.max.y - st.min.y) / 2
    Fill(st.min, st.max, st.fill, radius)
    Outline(st.min, st.max, st.border, radius)
    DrawShellText(subtitle, font, st.fontSize, st.fontSize, st.min, st.max, st.color)
end

-- Course / Outrun pills, centered under the subtitle.
local function DrawAs6RaceTypeToggle(mousePos)
    local p = layout.as6Panel
    local t = p.toggle
    local card = p.card
    local s = ShellScale()
    local left = (p.width - 2 * t.size.x - t.gap) / 2
    local pills = {
        { text = "COURSE", isCourse = true, min = vec2(left, t.y) },
        { text = "OUTRUN", isCourse = false, min = vec2(left + t.size.x + t.gap, t.y) },
    }

    for _, pill in ipairs(pills) do
        local max = pill.min + t.size
        local radius = t.size.y / 2
        local selected = isToggleCourse == pill.isCourse
        Fill(pill.min, max, selected and t.selectedFill or t.idleFill, radius)
        if selected then
            Outline(pill.min, max, card.hover, radius, 2)
        elseif IsInRect(mousePos, pill.min * s, max * s) then
            ui.setMouseCursor(ui.MouseCursor.Hand)
            if ConsumeClickIn(mousePos, pill.min * s, max * s) then
                isToggleCourse = pill.isCourse
            end
        end
        DrawShellText(pill.text, fontSemiBold, t.fontSize, t.fontSize, pill.min, max, selected and t.selectedText or t.idleText)
    end
end

-- Draws a card with its top-left at shell y. content fields: boxText, chips (list of
-- { text, fill }), caption, name, detail, busy, avatar (image path or nil). Returns true when
-- the card was clicked this frame.
local function DrawAs6Card(y, mousePos, content)
    local c = layout.as6Panel.card
    local s = ShellScale()
    local origin = vec2(c.x, y)
    local cardMax = origin + c.size

    Fill(origin, cardMax, c.fill, c.rounding)
    Outline(origin, cardMax, c.border, c.rounding)

    -- Left: headline box and chips
    Fill(origin + c.boxMin, origin + c.boxMax, c.boxFill, 3)
    Outline(origin + c.boxMin, origin + c.boxMax, c.boxBorder, 3)
    DrawShellText(content.boxText, fontBold, c.boxFontSize, c.boxFontSize * 0.7,
        origin + c.boxMin, origin + c.boxMax, content.busy and c.busyColor or c.boxColor)

    for i, chip in ipairs(content.chips) do
        local chipMin = origin + vec2(c.boxMin.x + (i - 1) * (c.chipWidth + c.chipGap), c.chipY)
        local chipMax = chipMin + vec2(c.chipWidth, c.chipHeight)
        Fill(chipMin, chipMax, chip.fill or c.chipFill, 3)
        DrawShellText(chip.text, fontSemiBold, c.chipFontSize, c.chipFontSize * 0.8, chipMin, chipMax, c.chipText)
    end

    -- Right: silver info area with caption, name and detail
    VerticalGradient(origin + c.infoMin, origin + c.infoMax, c.infoTop, c.infoBottom)
    Outline(origin + c.infoMin, origin + c.infoMax, c.border)

    local textLeft = c.textLeft
    if content.avatar ~= nil then
        DrawShellSprite(content.avatar, origin + c.avatar, vec2(c.avatarSize, c.avatarSize))
        textLeft = textLeft + c.avatarShift
    end
    local function Line(span)
        return origin + vec2(textLeft, span.x), origin + vec2(c.textRight, span.y)
    end
    local captionMin, captionMax = Line(c.captionY)
    DrawShellText(content.caption, fontSemiBold, c.captionFontSize, c.captionFontSize, captionMin, captionMax, c.mutedColor, ui.Alignment.Start)
    local nameMin, nameMax = Line(c.nameY)
    DrawShellText(content.name, fontBold, c.nameFontSize, c.nameMinFontSize, nameMin, nameMax,
        content.busy and c.busyColor or c.textColor, ui.Alignment.Start)
    local detailMin, detailMax = Line(c.detailY)
    DrawShellText(content.detail, font, c.detailFontSize, c.detailFontSize, detailMin, detailMax, c.mutedColor, ui.Alignment.Start)

    -- Gold frame under the mouse
    local screenMin = origin * s
    local screenMax = cardMax * s
    if not IsInRect(mousePos, screenMin, screenMax) then
        return false
    end
    Outline(origin, cardMax, c.hoverGlow, c.rounding + 2, c.hoverGlowThickness)
    Outline(origin, cardMax, c.hover, c.rounding, c.hoverThickness)
    ui.setMouseCursor(ui.MouseCursor.Hand)
    return ConsumeClickIn(mousePos, screenMin, screenMax)
end

local function DrawIdInviteMenu()
    if not hasInviteMenuOpen then
        return
    end

    local p = layout.as6Panel
    local playerCount = CountNearbyPlayers()
    local showToggle = showRaceTypeToggle and playerCount > 0
    local listTop = showToggle and p.listTopWithToggle or p.listTop
    local pos, size = As6PanelRect(listTop, playerCount)
    ui.transparentWindow("inviteWindow", pos, size, function ()
        DrawAs6Backdrop(pos, size)
        local mousePos = ui.mouseLocalPos()

        local subtitle = "Choose a driver to challenge  ·  I to close"
        if nearbyPlayers[1] == nil then
            subtitle = "Looking for drivers..." -- waiting for the lobby status
        elseif playerCount == 0 then
            subtitle = "No other players online  ·  I to close"
        end
        DrawAs6Header("CHALLENGE", subtitle)
        if showToggle then
            DrawAs6RaceTypeToggle(mousePos)
        end

        for index = 1, playerCount do
            local player = nearbyPlayers[index]
            -- Skipped until the avatar has loaded, so a missing one leaves no empty square.
            local avatarPath = GetAvatarPath(player.id)
            local avatar = (loadSteamAvatars and ui.isImageReady(avatarPath)) and avatarPath or nil
            local clicked = DrawAs6Card(listTop + (index - 1) * p.card.step, mousePos, {
                boxText = tostring(player.elo),
                chips = {
                    { text = "ELO", fill = GetEloColor(player.elo) },
                    { text = player.inRace and "IN RACE" or "READY" },
                },
                caption = "DRIVER",
                name = player.name,
                detail = player.inRace and "Currently in a race" or "Click to challenge",
                busy = player.inRace,
                avatar = avatar,
            })
            if clicked then
                ChooseNearbyPlayer(player)
            end
        end
    end)
end

local function DrawIdCourseSelect()
    if not hasCourseSelectOpen then
        return
    end

    local p = layout.as6Panel
    local visibleCards = math.min(#courseNames, p.maxVisibleRows)
    local maxScroll = #courseNames - visibleCards
    local pos, size = As6PanelRect(p.listTop, visibleCards)
    ui.transparentWindow("courseSelectWindow", pos, size, function ()
        DrawAs6Backdrop(pos, size)
        local mousePos = ui.mouseLocalPos()

        -- Longer lists scroll a whole card per wheel step (where this CSP build supports it).
        if maxScroll > 0 and ui.mouseWheel ~= nil and ui.windowHovered ~= nil and ui.windowHovered() then
            courseScroll = math.max(0, math.min(maxScroll, courseScroll - ui.mouseWheel()))
        end

        local subtitle = maxScroll > 0 and "Scroll for more courses  ·  I to cancel" or "Choose a course  ·  I to cancel"
        DrawAs6Header("COURSE SELECT", subtitle)

        local raceType = isToggleCourse and "COURSE" or "OUTRUN"
        for row = 1, visibleCards do
            local index = row + courseScroll
            local course = courseNames[index]
            local clicked = DrawAs6Card(p.listTop + (row - 1) * p.card.step, mousePos, {
                boxText = raceType,
                chips = { { text = "No. " .. index } },
                caption = "COURSE",
                name = course,
                detail = isToggleCourse and "Course race to the finish line" or "Outrun race",
            })
            if clicked then
                ChooseCourse(course)
            end
        end
    end)
end

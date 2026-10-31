-- The integrated Touge menu, in the style of the Initial D Arcade Stage 6 menus (see
-- layout.as6Panel): one centered window with CHALLENGE, PROFILE and HOW TO PLAY tabs, a
-- banner for a pending challenge, and a small hint in place of the old tutorial panel.
-- Drawn in code as a placeholder; coordinates are shell pixels relative to the window.

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

-- Wrapped, top-left aligned text in a shell rectangle.
local function DrawParagraph(text, textFont, fontSize, min, max, color)
    local s = ShellScale()
    ui.pushDWriteFont(textFont)
    ui.dwriteDrawTextClipped(text, scaling.size(fontSize * layout.shellScale), min * s, max * s,
        ui.Alignment.Start, ui.Alignment.Start, true, color)
    ui.popDWriteFont()
end

-- True while the mouse is over the shell rectangle; also shows the hand cursor.
local function Hovered(mousePos, min, max)
    local s = ShellScale()
    if IsInRect(mousePos, min * s, max * s) then
        ui.setMouseCursor(ui.MouseCursor.Hand)
        return true
    end
    return false
end

local function Clicked(mousePos, min, max)
    local s = ShellScale()
    return ConsumeClickIn(mousePos, min * s, max * s)
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

-- Gold gradient button; returns true when clicked.
local function DrawGoldButton(min, max, text, fontSize, enabled, mousePos)
    local b = layout.as6Panel.menu.send
    if not enabled then
        Fill(min, max, b.disabled, 4)
        DrawShellText(text, fontBold, fontSize, fontSize, min, max, b.disabledText)
        return false
    end
    local hovered = Hovered(mousePos, min, max)
    VerticalGradient(min, max, hovered and b.hoverTopColor or b.topColor, b.bottomColor)
    Outline(min, max, layout.as6Panel.card.hover, 4, 2)
    DrawShellText(text, fontBold, fontSize, fontSize, min, max, b.text)
    return Clicked(mousePos, min, max)
end

-- Pill used for tabs and the race type choice; returns true when an unselected pill is clicked.
local function DrawPill(min, max, text, fontSize, selected, mousePos)
    local t = layout.as6Panel.toggle
    local radius = (max.y - min.y) / 2
    Fill(min, max, selected and t.selectedFill or t.idleFill, radius)
    if selected then
        Outline(min, max, layout.as6Panel.card.hover, radius, 2)
    end
    DrawShellText(text, fontSemiBold, fontSize, fontSize, min, max, selected and t.selectedText or t.idleText)
    return not selected and Hovered(mousePos, min, max) and Clicked(mousePos, min, max)
end

-- Draws a card of the given width with its top-left at pos. content fields: boxText, chips
-- (list of { text, fill }), caption, name, detail, busy, avatar (image path or nil).
-- Selected cards keep the gold frame; others get a thin one under the mouse. Returns true
-- when the card was clicked this frame (never when mousePos is nil).
local function DrawAs6Card(pos, width, mousePos, content, selected)
    local c = layout.as6Panel.card
    local cardMax = pos + vec2(width, c.size.y)

    Fill(pos, cardMax, c.fill, c.rounding)
    Outline(pos, cardMax, c.border, c.rounding)

    -- Left: headline box and chips
    Fill(pos + c.boxMin, pos + c.boxMax, c.boxFill, 3)
    Outline(pos + c.boxMin, pos + c.boxMax, c.boxBorder, 3)
    DrawShellText(content.boxText, fontBold, c.boxFontSize, c.boxFontSize * 0.7,
        pos + c.boxMin, pos + c.boxMax, content.busy and c.busyColor or c.boxColor)

    for i, chip in ipairs(content.chips) do
        local chipMin = pos + vec2(c.boxMin.x + (i - 1) * (c.chipWidth + c.chipGap), c.chipY)
        local chipMax = chipMin + vec2(c.chipWidth, c.chipHeight)
        Fill(chipMin, chipMax, chip.fill or c.chipFill, 3)
        DrawShellText(chip.text, fontSemiBold, c.chipFontSize, c.chipFontSize * 0.8, chipMin, chipMax, c.chipText)
    end

    -- Right: silver info area with caption, name and detail
    local infoMax = pos + vec2(width - 8, c.infoMax.y)
    VerticalGradient(pos + c.infoMin, infoMax, c.infoTop, c.infoBottom)
    Outline(pos + c.infoMin, infoMax, c.border)

    local textLeft = c.textLeft
    if content.avatar ~= nil then
        DrawShellSprite(content.avatar, pos + c.avatar, vec2(c.avatarSize, c.avatarSize))
        textLeft = textLeft + c.avatarShift
    end
    local function Line(span)
        return pos + vec2(textLeft, span.x), pos + vec2(width - 16, span.y)
    end
    local captionMin, captionMax = Line(c.captionY)
    DrawShellText(content.caption, fontSemiBold, c.captionFontSize, c.captionFontSize, captionMin, captionMax, c.mutedColor, ui.Alignment.Start)
    local nameMin, nameMax = Line(c.nameY)
    DrawShellText(content.name, fontBold, c.nameFontSize, c.nameMinFontSize, nameMin, nameMax,
        content.busy and c.busyColor or c.textColor, ui.Alignment.Start)
    local detailMin, detailMax = Line(c.detailY)
    DrawShellText(content.detail, font, c.detailFontSize, c.detailFontSize, detailMin, detailMax, c.mutedColor, ui.Alignment.Start)

    local hovered = mousePos ~= nil and Hovered(mousePos, pos, cardMax)
    if selected then
        Outline(pos, cardMax, c.hoverGlow, c.rounding + 2, c.hoverGlowThickness)
        Outline(pos, cardMax, c.hover, c.rounding, c.hoverThickness)
    elseif hovered then
        Outline(pos, cardMax, c.hover, c.rounding, 1.5)
    end
    return hovered and Clicked(mousePos, pos, cardMax)
end

local function DrawCaption(text, x, y, width)
    local m = layout.as6Panel.menu
    DrawShellText(text, fontSemiBold, m.captionFontSize, m.captionFontSize, vec2(x + 4, y), vec2(x + width, y + m.captionHeight),
        m.captionColor, ui.Alignment.Start)
end

local function FindNearbyPlayer(playerId)
    for index = 1, CountNearbyPlayers() do
        if nearbyPlayers[index].id == playerId then
            return nearbyPlayers[index]
        end
    end
    return nil
end

local tabs = {
    { id = "challenge", text = "CHALLENGE" },
    { id = "profile", text = "PROFILE" },
    { id = "howto", text = "HOW TO PLAY" },
}

local function DrawMenuHeader(subtitle, mousePos)
    local p = layout.as6Panel
    local m = p.menu
    local t = p.title
    VerticalGradient(vec2(0, 0), vec2(m.width, t.max.y), t.top, t.bottom)
    Fill(vec2(0, 0), vec2(m.width, 2), t.highlight)
    DrawShellText("TOUGE", fontBold, t.fontSize, t.fontSize, m.titleText, vec2(400, t.max.y), t.color, ui.Alignment.Start)

    local tb = m.tabs
    for i, tab in ipairs(tabs) do
        local fromRight = #tabs - i + 1
        local min = vec2(tb.right - fromRight * tb.size.x - (fromRight - 1) * tb.gap, tb.y)
        if DrawPill(min, min + tb.size, tab.text, tb.fontSize, menuTab == tab.id, mousePos) then
            menuTab = tab.id
        end
    end

    local st = p.subtitle
    local radius = (m.subtitleMax.y - m.subtitleMin.y) / 2
    Fill(m.subtitleMin, m.subtitleMax, st.fill, radius)
    Outline(m.subtitleMin, m.subtitleMax, st.border, radius)
    DrawShellText(subtitle, font, st.fontSize, st.fontSize, m.subtitleMin, m.subtitleMax, st.color)
end

-- Pending challenge with an accept button, the same as pressing M.
local function DrawInviteBanner(mousePos)
    local m = layout.as6Panel.menu
    local b = m.banner
    local c = layout.as6Panel.card
    local min = vec2(b.margin, b.y)
    local max = vec2(m.width - b.margin, b.y + b.height)
    Fill(min, max, c.fill, c.rounding)
    Outline(min, max, c.hover, c.rounding, 2)

    local text = inviteSenderName .. " (" .. inviteSenderElo .. ") challenged you"
    if inviteCourseName ~= "" then
        text = text .. "  ·  " .. inviteCourseName
    end
    local buttonMax = vec2(max.x - 10, max.y - (b.height - b.buttonSize.y) / 2)
    local buttonMin = buttonMax - b.buttonSize
    DrawShellText(text, fontBold, b.fontSize, b.fontSize * 0.8, min + vec2(16, 0), vec2(buttonMin.x - 12, max.y), c.textColor, ui.Alignment.Start)
    if DrawGoldButton(buttonMin, buttonMax, "ACCEPT  (M)", 15, true, mousePos) then
        AcceptInvite()
    end
end

local function DrawChallengeTab(top, height, mousePos)
    local m = layout.as6Panel.menu
    local card = layout.as6Panel.card

    -- Left column: drivers
    local playerCount = CountNearbyPlayers()
    DrawCaption(playerCount > 0 and ("DRIVERS  ·  " .. playerCount .. " nearby") or "DRIVERS", m.leftX, top, m.leftWidth)
    local listTop = top + m.captionHeight
    if nearbyPlayers[1] == nil or playerCount == 0 then
        local text = nearbyPlayers[1] == nil and "Looking for drivers..." or "No other players online"
        DrawShellText(text, font, 18, 18, vec2(m.leftX, listTop), vec2(m.leftX + m.leftWidth, listTop + card.size.y), card.mutedColor)
    end
    for index = 1, playerCount do
        local player = nearbyPlayers[index]
        -- Skipped until the avatar has loaded, so a missing one leaves no empty square.
        local avatarPath = GetAvatarPath(player.id)
        local avatar = (loadSteamAvatars and ui.isImageReady(avatarPath)) and avatarPath or nil
        local pos = vec2(m.leftX, listTop + (index - 1) * card.step)
        local clicked = DrawAs6Card(pos, m.leftWidth, mousePos, {
            boxText = tostring(player.elo),
            chips = {
                { text = "ELO", fill = GetEloColor(player.elo) },
                { text = player.inRace and "IN RACE" or "READY" },
            },
            caption = "DRIVER",
            name = player.name,
            detail = player.inRace and "Currently in a race" or "Click to select",
            busy = player.inRace,
            avatar = avatar,
        }, player.id == selectedPlayerId)
        if clicked then
            selectedPlayerId = player.id
        end
    end

    -- Right column: race type, course, summary and send
    local x, width = m.rightX, m.rightWidth
    local y = top
    if showRaceTypeToggle then
        DrawCaption("RACE TYPE", x, y, width)
        local t = layout.as6Panel.toggle
        local left = x + (width - 2 * t.size.x - t.gap) / 2
        local pillsTop = y + m.captionHeight
        if DrawPill(vec2(left, pillsTop), vec2(left, pillsTop) + t.size, "COURSE", t.fontSize, isToggleCourse, mousePos) then
            isToggleCourse = true
        end
        local outrunMin = vec2(left + t.size.x + t.gap, pillsTop)
        if DrawPill(outrunMin, outrunMin + t.size, "OUTRUN", t.fontSize, not isToggleCourse, mousePos) then
            isToggleCourse = false
        end
        y = pillsTop + t.size.y + 14
    end

    local cc = m.courseCard
    DrawCaption("COURSE", x, y, width)
    local coursesTop = y + m.captionHeight
    local visible = math.min(#courseNames, cc.maxVisible)
    local maxScroll = #courseNames - visible
    selectedCourseIndex = math.max(1, math.min(selectedCourseIndex, #courseNames))
    if maxScroll > 0 and ui.mouseWheel ~= nil
        and IsInRect(mousePos, vec2(x, coursesTop) * ShellScale(), vec2(x + width, coursesTop + visible * cc.step) * ShellScale()) then
        courseScroll = math.max(0, math.min(maxScroll, courseScroll - ui.mouseWheel()))
    end
    courseScroll = math.max(0, math.min(courseScroll, maxScroll))

    for row = 1, visible do
        local index = row + courseScroll
        local min = vec2(x, coursesTop + (row - 1) * cc.step)
        local max = min + vec2(width, cc.height)
        local selected = index == selectedCourseIndex
        Fill(min, max, card.fill, card.rounding)
        Outline(min, max, selected and card.hover or card.border, card.rounding, selected and card.hoverThickness or 1)
        local chipMin = min + vec2(10, (cc.height - card.chipHeight) / 2)
        local chipMax = chipMin + vec2(card.chipWidth * 0.8, card.chipHeight)
        Fill(chipMin, chipMax, card.chipFill, 3)
        DrawShellText("No. " .. index, fontSemiBold, card.chipFontSize, card.chipFontSize, chipMin, chipMax, card.chipText)
        DrawShellText(courseNames[index], fontBold, cc.fontSize, cc.minFontSize, vec2(chipMax.x + 12, min.y), max - vec2(12, 0),
            card.textColor, ui.Alignment.Start)
        if not selected and Hovered(mousePos, min, max) then
            Outline(min, max, card.hover, card.rounding, 1.5)
            if Clicked(mousePos, min, max) then
                selectedCourseIndex = index
            end
        end
    end
    if maxScroll > 0 then
        local hintTop = coursesTop + visible * cc.step
        DrawShellText("Scroll for more courses", font, 13, 13, vec2(x, hintTop), vec2(x + width, hintTop + 18), card.mutedColor)
    end

    local s = m.send
    local sendMax = vec2(x + (width + s.size.x) / 2, height - s.bottom)
    local sendMin = sendMax - s.size
    local player = FindNearbyPlayer(selectedPlayerId)
    local summary = "Select a driver to challenge"
    if player ~= nil then
        summary = player.name
        if #courseNames > 0 then
            summary = summary .. "  ·  " .. courseNames[selectedCourseIndex]
        end
        summary = summary .. "  ·  " .. (isToggleCourse and "Course race" or "Outrun race")
    end
    DrawShellText(summary, fontSemiBold, m.summaryFontSize, m.summaryFontSize * 0.8,
        vec2(x, sendMin.y - 32), vec2(x + width, sendMin.y - 6), card.textColor)
    local canSend = player ~= nil and not player.inRace
    if DrawGoldButton(sendMin, sendMax, "SEND CHALLENGE", s.fontSize, canSend, mousePos) then
        SendChallenge(player)
    end
end

local function DrawProfileTab(top)
    local m = layout.as6Panel.menu
    local pr = m.profile
    local card = layout.as6Panel.card
    local left = (m.width - pr.cardWidth) / 2
    local displayElo = math.floor(math.max(elo, 0) + 0.5)

    DrawAs6Card(vec2(left, top + 20), pr.cardWidth, nil, {
        boxText = tostring(displayElo),
        chips = { { text = "ELO", fill = GetEloColor(displayElo) } },
        caption = "DRIVER",
        name = ac.getDriverName(0),
        detail = "Your touge profile",
    }, false)

    local stats = {
        { "Elo rating", tostring(displayElo) },
        { "Races completed", tostring(racesCompleted) },
    }
    for i, stat in ipairs(stats) do
        local y = top + pr.statsTop + (i - 1) * pr.statStep
        local min = vec2(left, y)
        local max = vec2(left + pr.cardWidth, y + pr.statStep - 8)
        Fill(min, max, card.fill, card.rounding)
        Outline(min, max, card.border, card.rounding)
        DrawShellText(stat[1], fontSemiBold, pr.statFontSize, pr.statFontSize, min + vec2(16, 0), max, card.mutedColor, ui.Alignment.Start)
        DrawShellText(stat[2], fontBold, pr.statFontSize, pr.statFontSize, min, max - vec2(16, 0), card.textColor, ui.Alignment.End)
    end
end

local howtoKeys = {
    { key = "I", text = "Open or close this menu" },
    { key = "N", text = "Challenge the nearest driver" },
    { key = "M", text = "Accept a challenge" },
    { key = "F", text = "Hold to forfeit a race" },
    { key = "H", text = "Hide the menu hint" },
}

local function DrawHowToTab(top)
    local m = layout.as6Panel.menu
    local h = m.howto
    local card = layout.as6Panel.card
    local left = (m.width - h.textWidth) / 2

    local body = "Choose a driver on the Challenge tab, pick a course and a race type, and send the challenge. "
        .. "When they accept, both cars are placed at the start and the countdown begins.\n\n"
        .. "Beat your opponent to gain Elo. How much you gain depends on both drivers' Elo and cars."
    local bodyMin = vec2(left, top + 10)
    local bodyMax = vec2(left + h.textWidth, top + h.keysTop - 20)
    Fill(bodyMin - vec2(12, 8), bodyMax + vec2(12, 0), card.fill, card.rounding)
    Outline(bodyMin - vec2(12, 8), bodyMax + vec2(12, 0), card.border, card.rounding)
    DrawParagraph(body, font, h.bodyFontSize, bodyMin, bodyMax, card.textColor)

    for i, binding in ipairs(howtoKeys) do
        local column = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local keyMin = vec2(left + column * (h.keyStep + 80), top + h.keysTop + row * (h.keySize.y + 18))
        local keyMax = keyMin + h.keySize
        Fill(keyMin, keyMax, rgbm(1, 1, 1, 1), 6)
        Outline(keyMin, keyMax, card.border, 6, 2)
        DrawShellText(binding.key, fontBold, h.keyFontSize, h.keyFontSize, keyMin, keyMax, card.textColor)
        DrawShellText(binding.text, fontSemiBold, h.keyLabelFontSize, h.keyLabelFontSize * 0.8,
            vec2(keyMax.x + 10, keyMin.y), vec2(keyMax.x + h.keyStep + 60, keyMax.y), card.textColor, ui.Alignment.Start)
    end
end

local subtitles = {
    challenge = "Choose a driver, a course and a race type  ·  I to close",
    profile = "Your rating and progress  ·  I to close",
    howto = "Rules and controls  ·  I to close",
}

local function DrawTougeMenu()
    if not hasInviteMenuOpen then
        return
    end

    local m = layout.as6Panel.menu
    local height = m.height + (hasActiveInvite and m.bannerSpace or 0)
    local size = vec2(m.width, height) * ShellScale()
    local pos = (vec2(windowWidth, windowHeight) - size) / 2
    ui.transparentWindow("tougeMenuWindow", pos, size, function ()
        DrawAs6Backdrop(pos, size)
        local mousePos = ui.mouseLocalPos()
        DrawMenuHeader(subtitles[menuTab] or subtitles.challenge, mousePos)

        local top = m.contentTop
        if hasActiveInvite then
            DrawInviteBanner(mousePos)
            top = top + m.bannerSpace
        end

        if menuTab == "profile" then
            DrawProfileTab(top)
        elseif menuTab == "howto" then
            DrawHowToTab(top)
        else
            DrawChallengeTab(top, height, mousePos)
        end
    end)
end

-- Small pill in place of the old tutorial panel, under the same conditions.
local function DrawMenuHint()
    if hasTutorialHidden or hasInviteMenuOpen then
        return
    end
    if isTutorialAutoHidden and not (car ~= nil and car.speedKmh < 10) then
        return
    end

    local hint = layout.as6Panel.menu.hint
    local st = layout.as6Panel.subtitle
    local size = hint.size * ShellScale()
    local pos = vec2(scaling.size(hint.marginLeft), windowHeight - scaling.size(hint.marginBottom) - size.y)
    ui.transparentWindow("tougeMenuHint", pos, size, function ()
        local radius = hint.size.y / 2
        Fill(vec2(0, 0), hint.size, st.fill, radius)
        Outline(vec2(0, 0), hint.size, st.border, radius)
        DrawShellText("I  Touge menu   ·   H  hide", fontSemiBold, hint.fontSize, hint.fontSize, vec2(0, 0), hint.size, st.color)
    end)
end

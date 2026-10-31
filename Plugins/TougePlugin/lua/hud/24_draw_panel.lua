-- The integrated Touge menu, in the style of the Initial D Arcade Stage 6 menus (see
-- layout.as6Panel): one centered window with CHALLENGE, PROFILE and HOW TO PLAY tabs, a
-- banner for a pending challenge, and a small hint in place of the old tutorial panel.
-- Drawn in code as a placeholder; coordinates are shell pixels relative to the window.

local radii = layout.as6Panel.radius

local function Fill(min, max, color, rounding, corners)
    local s = ShellScale()
    ui.drawRectFilled(min * s, max * s, color, (rounding or 0) * s, corners or ui.CornerFlags.All)
end

local function Outline(min, max, color, rounding, thickness)
    local s = ShellScale()
    ui.drawRect(min * s, max * s, color, (rounding or 0) * s, ui.CornerFlags.All, (thickness or 1) * s)
end

-- Gradient fill with rounded corners: a rounded base in the bottom colour, a rounded cap in
-- the top colour, and the gradient between the two. topOnly rounds just the top corners.
local function VerticalGradient(min, max, top, bottom, rounding, topOnly)
    local s = ShellScale()
    local r = math.min(rounding or 0, (max.y - min.y) / 2)
    if r <= 0 then
        ui.drawRectFilledMultiColor(min * s, max * s, top, top, bottom, bottom)
        return
    end
    Fill(min, max, bottom, r, topOnly and ui.CornerFlags.Top or ui.CornerFlags.All)
    Fill(min, vec2(max.x, min.y + 2 * r), top, r, ui.CornerFlags.Top)
    local gradientMax = topOnly and max or vec2(max.x, max.y - r)
    ui.drawRectFilledMultiColor(vec2(min.x, min.y + r) * s, gradientMax * s, top, top, bottom, bottom)
end

-- Text centered in a shape, kept inset from its sides.
local function InsetText(text, textFont, fontSize, minFontSize, min, max, color, inset)
    local pad = vec2(inset or layout.as6Panel.textInset, 0)
    DrawShellText(text, textFont, fontSize, minFontSize, min + pad, max - pad, color)
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
    ui.drawRectFilled(vec2(0, 0), size, b.tint, radii.window * s)
    ui.drawRect(vec2(0, 0), size, b.border, radii.window * s)
end

-- Gold gradient button; returns true when clicked.
local function DrawGoldButton(min, max, text, fontSize, enabled, mousePos)
    local b = layout.as6Panel.menu.send
    if not enabled then
        Fill(min, max, b.disabled, radii.card)
        InsetText(text, fontBold, fontSize, fontSize * 0.8, min, max, b.disabledText)
        return false
    end
    local hovered = Hovered(mousePos, min, max)
    VerticalGradient(min, max, hovered and b.hoverTopColor or b.topColor, b.bottomColor, radii.card)
    Outline(min, max, layout.as6Panel.card.hover, radii.card, 2)
    InsetText(text, fontBold, fontSize, fontSize * 0.8, min, max, b.text)
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
    InsetText(text, fontSemiBold, fontSize, fontSize * 0.8, min, max, selected and t.selectedText or t.idleText, radius)
    return not selected and Hovered(mousePos, min, max) and Clicked(mousePos, min, max)
end

-- Draws a card of the given width with its top-left at pos. content fields: boxText, chips
-- (list of { text, fill }), caption, name, detail, busy, image (car preview path or nil).
-- Selected cards keep the gold frame; others get a thin one under the mouse. Returns true
-- when the card was clicked this frame (never when mousePos is nil).
local function DrawAs6Card(pos, width, mousePos, content, selected)
    local c = layout.as6Panel.card
    local cardMax = pos + vec2(width, c.size.y)

    Fill(pos, cardMax, c.fill, radii.card)
    Outline(pos, cardMax, c.border, radii.card)

    -- Left: headline box and chips
    Fill(pos + c.boxMin, pos + c.boxMax, c.boxFill, radii.inner)
    Outline(pos + c.boxMin, pos + c.boxMax, c.boxBorder, radii.inner)
    InsetText(content.boxText, fontBold, c.boxFontSize, c.boxFontSize * 0.7,
        pos + c.boxMin, pos + c.boxMax, content.busy and c.busyColor or c.boxColor)

    for i, chip in ipairs(content.chips) do
        local chipMin = pos + vec2(c.boxMin.x + (i - 1) * (c.chipWidth + c.chipGap), c.chipY)
        local chipMax = chipMin + vec2(c.chipWidth, c.chipHeight)
        Fill(chipMin, chipMax, chip.fill or c.chipFill, radii.chip)
        InsetText(chip.text, fontSemiBold, c.chipFontSize, c.chipFontSize * 0.7, chipMin, chipMax, c.chipText,
            layout.as6Panel.chipTextInset)
    end

    -- Right: silver info area with caption, name and detail
    local infoMax = pos + vec2(width - c.rightInset, c.infoMax.y)
    VerticalGradient(pos + c.infoMin, infoMax, c.infoTop, c.infoBottom, radii.inner)
    Outline(pos + c.infoMin, infoMax, c.border, radii.inner)

    local textLeft = c.textLeft
    if content.image ~= nil then
        local sc = ShellScale()
        local imageMin = pos + c.image
        local imageMax = imageMin + c.imageSize
        ui.drawImageRounded(content.image, imageMin * sc, imageMax * sc, rgbm(1, 1, 1, content.busy and 0.5 or 1),
            c.imageUvMin, c.imageUvMax, radii.chip * sc)
        Outline(imageMin, imageMax, c.imageBorder, radii.chip)
        textLeft = textLeft + c.imageShift
    end
    local function Line(span)
        return pos + vec2(textLeft, span.x), pos + vec2(width - c.textRightInset, span.y)
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
        Outline(pos, cardMax, c.hoverGlow, radii.card + 3, c.hoverGlowThickness)
        Outline(pos, cardMax, c.hover, radii.card, c.hoverThickness)
    elseif hovered then
        Outline(pos, cardMax, c.hover, radii.card, 1.5)
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
    VerticalGradient(vec2(0, 0), vec2(m.width, t.max.y), t.top, t.bottom, radii.window, true)
    Fill(vec2(radii.window, 0), vec2(m.width - radii.window, 2), t.highlight)
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
    InsetText(subtitle, font, st.fontSize, st.fontSize * 0.8, m.subtitleMin, m.subtitleMax, st.color, radius)
end

-- Pending challenge with an accept button, the same as pressing M.
local function DrawInviteBanner(mousePos)
    local m = layout.as6Panel.menu
    local b = m.banner
    local c = layout.as6Panel.card
    local min = vec2(b.margin, b.y)
    local max = vec2(m.width - b.margin, b.y + b.height)
    Fill(min, max, c.fill, radii.card)
    Outline(min, max, c.hover, radii.card, 2)

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
        local pos = vec2(m.leftX, listTop + (index - 1) * card.step)
        local status = player.inRace and { text = "IN RACE", fill = card.inRaceFill } or { text = "READY", fill = card.readyFill }
        local clicked = DrawAs6Card(pos, m.leftWidth, mousePos, {
            boxText = tostring(player.elo),
            chips = {
                { text = "ELO", fill = GetEloColor(player.elo) },
                status,
            },
            caption = GetCarNameBySessionId(player.sessionId) or "DRIVER",
            name = player.name,
            detail = player.inRace and "Currently in a race" or "Click to select",
            busy = player.inRace,
            image = GetCarPreviewPath(player.sessionId),
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
        Fill(min, max, card.fill, radii.card)
        Outline(min, max, selected and card.hover or card.border, radii.card, selected and card.hoverThickness or 1)
        local chipMin = min + vec2(10, (cc.height - card.chipHeight) / 2)
        local chipMax = chipMin + vec2(cc.chipWidth, card.chipHeight)
        Fill(chipMin, chipMax, card.chipFill, radii.chip)
        InsetText("No. " .. index, fontSemiBold, card.chipFontSize, card.chipFontSize * 0.7, chipMin, chipMax, card.chipText,
            layout.as6Panel.chipTextInset)
        DrawShellText(courseNames[index], fontBold, cc.fontSize, cc.minFontSize, vec2(chipMax.x + 12, min.y), max - vec2(16, 0),
            card.textColor, ui.Alignment.Start)
        if not selected and Hovered(mousePos, min, max) then
            Outline(min, max, card.hover, radii.card, 1.5)
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
    local sendMax = vec2(x + (width + s.size.x) / 2, height - m.padding)
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

    DrawAs6Card(vec2(left, top), pr.cardWidth, nil, {
        boxText = tostring(displayElo),
        chips = { { text = "ELO", fill = GetEloColor(displayElo) } },
        caption = ac.getCarName(0) or "DRIVER",
        name = ac.getDriverName(0),
        detail = "Your touge profile",
        image = car ~= nil and GetCarPreviewPath(car.sessionID) or nil,
    }, false)

    local stats = {
        { "Elo rating", tostring(displayElo) },
        { "Races completed", tostring(racesCompleted) },
    }
    for i, stat in ipairs(stats) do
        local y = top + card.size.y + pr.gap + (i - 1) * pr.statStep
        local min = vec2(left, y)
        local max = vec2(left + pr.cardWidth, y + pr.statHeight)
        Fill(min, max, card.fill, radii.card)
        Outline(min, max, card.border, radii.card)
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
    local left, right = m.padding, m.width - m.padding

    local body = "Choose a driver on the Challenge tab, pick a course and a race type, and send the challenge. "
        .. "When they accept, both cars are placed at the start and the countdown begins.\n\n"
        .. "Beat your opponent to gain Elo. How much you gain depends on both drivers' Elo and cars."
    local boxMin = vec2(left, top)
    local boxMax = vec2(right, top + h.bodyHeight)
    Fill(boxMin, boxMax, card.fill, radii.card)
    Outline(boxMin, boxMax, card.border, radii.card)
    local inset = vec2(h.bodyPadding, h.bodyPadding)
    DrawParagraph(body, font, h.bodyFontSize, boxMin + inset, boxMax - inset, card.textColor)

    local keysTop = boxMax.y + h.keysGap
    local columnWidth = (right - left) / h.keyColumns
    for i, binding in ipairs(howtoKeys) do
        local column = (i - 1) % h.keyColumns
        local row = math.floor((i - 1) / h.keyColumns)
        local keyMin = vec2(left + column * columnWidth, keysTop + row * h.keyRowStep)
        local keyMax = keyMin + h.keySize
        Fill(keyMin, keyMax, card.keyFill, radii.card)
        Outline(keyMin, keyMax, card.border, radii.card, 2)
        DrawShellText(binding.key, fontBold, h.keyFontSize, h.keyFontSize, keyMin, keyMax, card.textColor)
        DrawShellText(binding.text, fontSemiBold, h.keyLabelFontSize, h.keyLabelFontSize * 0.8,
            vec2(keyMax.x + 14, keyMin.y), vec2(keyMin.x + columnWidth - m.padding, keyMax.y), card.textColor, ui.Alignment.Start)
    end
end

-- Height of each tab's content, from the top of the content to its bottom edge.
local function ContentHeight(tab)
    local m = layout.as6Panel.menu
    local card = layout.as6Panel.card
    if tab == "profile" then
        local pr = m.profile
        return card.size.y + pr.gap + 2 * pr.statStep - (pr.statStep - pr.statHeight)
    elseif tab == "howto" then
        local h = m.howto
        local rows = math.ceil(#howtoKeys / h.keyColumns)
        return h.bodyHeight + h.keysGap + rows * h.keyRowStep - (h.keyRowStep - h.keySize.y)
    end
    return m.captionHeight + m.driverRows * card.step - (card.step - card.size.y)
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
    local top = m.contentTop + (hasActiveInvite and m.bannerSpace or 0)
    local height = top + ContentHeight(menuTab) + m.padding
    local size = vec2(m.width, height) * ShellScale()
    local pos = (vec2(windowWidth, windowHeight) - size) / 2
    ui.transparentWindow("tougeMenuWindow", pos, size, function ()
        DrawAs6Backdrop(pos, size)
        local mousePos = ui.mouseLocalPos()
        DrawMenuHeader(subtitles[menuTab] or subtitles.challenge, mousePos)

        if hasActiveInvite then
            DrawInviteBanner(mousePos)
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
        InsetText("I  Touge menu   ·   H  hide", fontSemiBold, hint.fontSize, hint.fontSize * 0.8, vec2(0, 0), hint.size, st.color, radius)
    end)
end

-- Compact Elo card, top-left, shown whenever the Elo is known.
local function DrawEloCard()
    if elo == -1 or not showElo then
        return
    end

    local l = layout.eloCard
    local c = layout.as6Panel.card
    ui.transparentWindow("eloWindow", scaling.size(l.pos), l.size * ShellScale(), function ()
        local displayElo = math.floor(math.max(elo, 0) + 0.5)
        VerticalGradient(vec2(0, 0), l.size, c.infoTop, c.infoBottom, radii.card)
        Outline(vec2(0, 0), l.size, c.border, radii.card)

        Fill(l.boxMin, l.boxMax, c.boxFill, radii.inner)
        Outline(l.boxMin, l.boxMax, c.boxBorder, radii.inner)
        InsetText(tostring(displayElo), fontBold, l.boxFontSize, l.boxFontSize * 0.7, l.boxMin, l.boxMax, c.boxColor)

        DrawShellText(ac.getDriverName(0), fontBold, l.nameFontSize, l.nameMinFontSize, l.nameMin, l.nameMax, c.textColor, ui.Alignment.Start)
        local chipMax = l.chipMin + l.chipSize
        Fill(l.chipMin, chipMax, GetEloColor(displayElo), radii.chip)
        InsetText("ELO", fontSemiBold, c.chipFontSize, c.chipFontSize, l.chipMin, chipMax, c.chipText, layout.as6Panel.chipTextInset)
    end)
end

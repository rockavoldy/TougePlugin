-- Popups and the countdown in the dark menu style (see layout.as6Panel.menu.popup and
-- .countdown). Shares the drawing helpers of 24_draw_panel.lua.

local function DrawInviteCard()
    local c = layout.as6Panel.card
    local p = layout.as6Panel.menu.popup
    DrawAs6Card(vec2(0, 0), p.width, nil, {
        boxText = tostring(inviteSenderElo),
        chips = {
            { text = "ELO", fill = GetEloColor(inviteSenderElo) },
            { text = "INVITE", fill = c.readyFill },
        },
        caption = inviteCourseName ~= "" and inviteCourseName or "Touge challenge",
        name = inviteSenderName,
        detail = "Press M to accept",
    }, false)
    Outline(vec2(0, 0), vec2(p.width, c.size.y), c.hover, radii.card, 2)
end

-- Dark plate with a gold accent bar on the left, for the notification and forfeit popups.
local function DrawMessagePlate(height)
    local c = layout.as6Panel.card
    local p = layout.as6Panel.menu.popup
    Fill(vec2(0, 0), vec2(p.width, height), c.fill, radii.card)
    Outline(vec2(0, 0), vec2(p.width, height), c.border, radii.card)
    local a = p.accent
    Fill(vec2(a.x, a.inset), vec2(a.x + a.width, height - a.inset), c.hover, radii.chip)
end

-- Wrapped text, vertically centered in a shell rectangle.
local function DrawMessageText(text, textFont, min, max, color)
    local s = ShellScale()
    local p = layout.as6Panel.menu.popup
    ui.pushDWriteFont(textFont)
    ui.dwriteDrawTextClipped(text, scaling.size(p.fontSize * layout.shellScale), min * s, max * s,
        ui.Alignment.Start, ui.Alignment.Center, true, color)
    ui.popDWriteFont()
end

local function DrawNotificationPlate()
    local p = layout.as6Panel.menu.popup
    DrawMessagePlate(p.messageHeight)
    DrawMessageText(notificationMessage, fontSemiBold, vec2(p.textLeft, 0), vec2(p.width - p.textLeft, p.messageHeight),
        layout.as6Panel.card.textColor)
end

local function DrawForfeitPlate()
    local c = layout.as6Panel.card
    local p = layout.as6Panel.menu.popup
    local h = p.messageHeight
    DrawMessagePlate(h)

    -- The mock dialog loops the hold so the bar can be seen without holding the key.
    local held = forfeitStartTime ~= nil and (os.clock() - forfeitStartTime) or (os.clock() % forfeitHoldDuration)
    local progress = math.max(0, math.min(1, held / forfeitHoldDuration))
    local textMax = vec2(p.width - p.textLeft, h - p.barBottom - p.barHeight)
    DrawMessageText("Hold F to forfeit the race", fontSemiBold, vec2(p.textLeft, 0), textMax, c.textColor)
    DrawShellText(string.format("%.1f s", math.max(0, forfeitHoldDuration - held)), fontBold, p.fontSize, p.fontSize,
        vec2(p.textLeft, 0), textMax, c.mutedColor, ui.Alignment.End)

    local barMin = vec2(p.textLeft, h - p.barBottom - p.barHeight)
    local barMax = vec2(p.width - p.textLeft, h - p.barBottom)
    Fill(barMin, barMax, c.boxFill, p.barHeight / 2)
    if progress > 0 then
        local send = layout.as6Panel.menu.send
        local fillMax = vec2(barMin.x + math.max(p.barHeight, (barMax.x - barMin.x) * progress), barMax.y)
        VerticalGradient(barMin, fillMax, send.topColor, send.bottomColor, p.barHeight / 2)
    end
end

local function DrawAs6Popups()
    local p = layout.as6Panel.menu.popup
    local s = ShellScale()
    local right = windowWidth - scaling.size(p.marginRight)
    local bottom = windowHeight - scaling.size(p.marginBottom)

    -- Each popup sits on top of the previous one.
    local function Place(name, height, draw)
        local size = vec2(p.width, height) * s
        local pos = vec2(right - size.x, bottom - size.y)
        ui.transparentWindow(name, pos, size, draw)
        bottom = pos.y - p.gap * s
    end

    if hasActiveInvite then
        Place("receivedInviteWindow", layout.as6Panel.card.size.y, DrawInviteCard)
    end
    if hasIncomingNotification then
        Place("notificationWindow", p.messageHeight, DrawNotificationPlate)
    end
    if (forfeitStartTime ~= nil and currentHudState ~= HudStates.Off) or mockShowForfeit then
        Place("forfeitWindow", p.messageHeight, DrawForfeitPlate)
    end
end

local function DrawAs6Countdown()
    if not isCountdownHudActive then
        return
    end

    local c = layout.as6Panel.menu.countdown
    local s = ShellScale()
    local fontSize = scaling.size(c.fontSize * layout.shellScale)
    ui.pushDWriteFont(fontBold)
    local textSize = ui.measureDWriteText(countdownHudMessage, fontSize)
    ui.popDWriteFont()

    local size = vec2(textSize.x + 2 * c.paddingX * s, c.height * s)
    local pos = (vec2(windowWidth, windowHeight) - size) / 2
    local message = countdownHudMessage:lower()
    local color = c.readyColor
    if message:find("go") then
        color = c.goColor
    elseif message:find("set") then
        color = c.setColor
    end
    ui.transparentWindow("countdownWindow", pos, size, function ()
        DrawAs6Backdrop(pos, size)
        Outline(vec2(0, 0), size / s, layout.as6Panel.card.hover, radii.window, 2)
        ui.pushDWriteFont(fontBold)
        ui.dwriteDrawText(countdownHudMessage, fontSize, (size - textSize) / 2, color)
        ui.popDWriteFont()
    end)
end

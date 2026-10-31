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

    -- The mock dialog loops the hold so the bar can be seen without holding the key. After
    -- the key is released the popup fades out with an empty bar.
    local held = 0
    if forfeitStartTime ~= nil then
        held = os.clock() - forfeitStartTime
    elseif mockShowForfeit then
        held = os.clock() % forfeitHoldDuration
    end
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

local function DrawPopups()
    local p = layout.as6Panel.menu.popup
    local motion = layout.as6Panel.motion
    local s = ShellScale()
    local right = windowWidth - scaling.size(p.marginRight)
    local bottom = windowHeight - scaling.size(p.marginBottom)

    -- Each popup sits on top of the previous one. A popup slides in from the right and fades,
    -- and the ones above move to make room as it grows.
    local function Place(name, height, visible, draw)
        local shown = Tween(name, visible, motion.popup)
        if shown <= 0 then
            return
        end
        local size = vec2(p.width, height) * s
        local pos = vec2(right - size.x + (1 - shown) * motion.popupSlide * s, bottom - size.y)
        ui.transparentWindow(name, pos, size, function ()
            DrawFaded(shown, size, draw)
        end)
        bottom = bottom - (size.y + p.gap * s) * shown
    end

    Place("receivedInviteWindow", layout.as6Panel.card.size.y, hasActiveInvite, DrawInviteCard)
    Place("notificationWindow", p.messageHeight, hasIncomingNotification, DrawNotificationPlate)
    Place("forfeitWindow", p.messageHeight,
        (forfeitStartTime ~= nil and currentHudState ~= HudStates.Off) or mockShowForfeit, DrawForfeitPlate)
end

local lastCountdownMessage = nil

local function DrawCountdown()
    local motion = layout.as6Panel.motion
    local shown = Tween("countdown", isCountdownHudActive, motion.countdown)
    if shown <= 0 then
        lastCountdownMessage = nil
        return
    end
    -- Each new step pops in from a larger size.
    if countdownHudMessage ~= lastCountdownMessage then
        lastCountdownMessage = countdownHudMessage
        RestartTween("countdownPop")
    end
    local pop = Tween("countdownPop", true, motion.countdown)

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
        DrawFaded(shown, size, function ()
            local textPos = (size - textSize) / 2
            ui.beginScale()
            ui.pushDWriteFont(fontBold)
            ui.dwriteDrawText(countdownHudMessage, fontSize, textPos + vec2(c.shadowOffset, c.shadowOffset) * s, c.shadowColor)
            ui.dwriteDrawText(countdownHudMessage, fontSize, textPos, color)
            ui.popDWriteFont()
            ui.endScale(motion.countdownPop + (1 - motion.countdownPop) * pop)
        end)
    end)
end

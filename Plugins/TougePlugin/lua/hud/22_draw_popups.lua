-- Bottom-right popups. They stack upwards from the bottom slot in the order invite,
-- notification, forfeit, skipping the ones that are not shown.

-- Top-left corner (screen units) of a popup slot, 0 being the bottom one.
local function PopupPos(slot)
    local p = layout.popup
    local bottomY = windowHeight - scaling.size(p.marginBottom + p.size.y)
    return vec2(windowWidth - scaling.size(p.marginRight + p.size.x), bottomY - scaling.size(p.stackStep) * slot)
end

local function DrawInvitePopup(slot)
    local l = layout.invite
    local size = scaling.size(layout.popup.size)
    ui.transparentWindow("receivedInviteWindow", PopupPos(slot), size, function ()
        ui.drawImage(layout.popup.image, vec2(0, 0), size)
        DrawAvatar(inviteSenderId, vec2(0, 0))
        DrawEloBadge(inviteSenderElo, scaling.size(l.eloBadge))
        ui.drawImage(l.mKeyImage, scaling.size(l.mKeyMin), scaling.size(l.mKeyMax))

        local fontSize = FindFontSize(inviteSenderName, l.nameFontSize, fontBold, l.nameMaxWidth)
        DrawText(inviteSenderName, fontBold, fontSize, scaling.size(l.name))
        DrawText("Challenged you!", font, l.subtitleFontSize, scaling.size(l.subtitle))
    end)
end

local function DrawNotification(slot)
    local l = layout.notification
    local size = scaling.size(layout.popup.size)
    ui.transparentWindow("notificationWindow", PopupPos(slot), size, function ()
        ui.drawImage(layout.popup.image, vec2(0, 0), size)
        ui.pushDWriteFont(fontSemiBold)
        ui.dwriteDrawTextClipped(notificationMessage, scaling.size(l.fontSize), scaling.size(l.textMin), scaling.size(l.textMax), ui.Alignment.Start, ui.Alignment.Center, true)
        ui.popDWriteFont()
    end)
end

local function DrawForfeit(slot)
    local l = layout.forfeit
    local size = scaling.size(layout.popup.size)
    ui.transparentWindow("forfeitWindow", PopupPos(slot), size, function ()
        ui.drawImage(layout.popup.image, vec2(0, 0), size)
        DrawText("Hold for 3 seconds to forfeit.", fontSemiBold, l.fontSize, scaling.size(l.text))
    end)
end

local function DrawPopups()
    local slot = 0
    if hasActiveInvite then
        DrawInvitePopup(slot)
        slot = slot + 1
    end
    if hasIncomingNotification then
        DrawNotification(slot)
        slot = slot + 1
    end
    if (forfeitStartTime ~= nil and currentHudState ~= HudStates.Off) or mockShowForfeit then
        DrawForfeit(slot)
    end
end

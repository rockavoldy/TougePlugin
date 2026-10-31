-- Challenge actions shared by the menu, the popups and the keyboard.

-- Number of filled nearby player slots; empty slots have an empty name.
local function CountNearbyPlayers()
    local playerCount = 0
    while playerCount < 5 and nearbyPlayers[playerCount + 1] and nearbyPlayers[playerCount + 1].name ~= "" do
        playerCount = playerCount + 1
    end
    return playerCount
end

-- Sends the challenge picked in the menu. The course is only named when there is more
-- than one.
local function SendChallenge(player)
    local payload = {inviteSenderName = "", inviteRecipientGuid = player.id, isCourse = isToggleCourse}
    if #courseNames > 1 then
        payload.courseName = courseNames[selectedCourseIndex]
    end
    SendToServer(inviteEvent, payload)
    hasInviteMenuOpen = false
end

local function AcceptInvite()
    SendToServer(inviteEvent, {inviteSenderName = "a", inviteRecipientGuid = 1})
    hasActiveInvite = false
end

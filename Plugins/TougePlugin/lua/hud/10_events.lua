-- Server messages. Each event has a named handler so the mock panel can drive the HUD
-- through the same code as the real event.

local function OnSessionState(message)
    ac.debug('AS_SessionState.sessionState', message.sessionState)
    ac.debug('AS_SessionState.result1', message.result1)
    ac.debug('AS_SessionState.result2', message.result2)
    ac.debug('AS_SessionState.result3', message.result3)
    ac.debug('AS_SessionState.rivalSessionId', message.rivalSessionId)

    standings[1] = message.result1
    standings[2] = message.result2
    standings[3] = message.result3
    local previousState = currentHudState
    if message.sessionState ~= HudStates.NoUpdate then currentHudState = message.sessionState end
    if currentHudState == HudStates.Finished and previousState ~= HudStates.Finished then
        -- The same rule as the cluster's YOU WIN / YOU LOSE label.
        PlaySound(standings[3] == RaceResults.Win and "win" or "lose")
    end

    if message.rivalSessionId >= 0 then
        rivalCar = FindCarBySessionId(message.rivalSessionId)
    else
        rivalCar = nil
    end
end

local function OnElo(message)
    showElo = true
    targetElo = message.elo
    if discreteMode then
        eloShownAt = os.clock()
    end
end

local function OnInvite(message)
    if message.inviteSenderName ~= "" and message.inviteRecipientGuid ~= 1 then
        hasActiveInvite = true
        inviteSenderName = message.inviteSenderName
        inviteSenderElo = message.inviteSenderElo
        inviteCourseName = message.courseName or ""
        inviteActivatedAt = os.clock()
        PlaySound("invite")
    end
end

local function OnNotification(message)
    ac.debug('AS_Notification.isCountdown', message.isCountdown)
    ac.debug('AS_Notification.message', message.message)

    if not message.isCountdown then
        notificationMessage = message.message
        hasIncomingNotification = true
        notificationActivatedAt = os.clock()
        PlaySound("notify")
    else
        if message.message == "Ready..." then
            PlaySound("countdown")
        end
        countdownHudMessage = message.message
        isCountdownHudActive = true
        countdownActivatedAt = os.clock()
    end
end

local function OnInitialization(message)
    ac.debug('AS_Initialization.discreteMode', message.discreteMode)
    ac.debug('AS_Initialization.useTrackFinish', message.useTrackFinish)

    showRaceTypeToggle = message.showRaceTypeToggle

    -- Discrete mode hides the Elo card (it shows for a while after the Elo changes) and the
    -- menu hint. Set both either way, so leaving discrete mode brings them back.
    discreteMode = message.discreteMode
    showElo = not discreteMode
    hasTutorialHidden = discreteMode
    eloShownAt = nil

    elo = message.elo - 100
    targetElo = message.elo

    racesCompleted = message.racesCompleted
    if message.racesCompleted >= 3 then
        isTutorialAutoHidden = true
    end

    courseNames = {}
    for courseName in string.gmatch(message.courseNames, "([^`]+)") do
        table.insert(courseNames, courseName)
    end
end

local function OnLobbyStatus(message)
    -- The packet carries five flattened player slots.
    for i = 1, 5 do
        nearbyPlayers[i] = {
            name = message['nearbyName' .. i],
            id = message['nearbyId' .. i],
            inRace = message['nearbyInRace' .. i],
            elo = message['nearbyElo' .. i],
            sessionId = message['nearbySessionId' .. i],
        }
        -- Looked up once here rather than every frame the menu draws.
        local c = FindCarBySessionId(nearbyPlayers[i].sessionId)
        nearbyPlayers[i].carName = c ~= nil and ac.getCarName(c.index) or nil
        nearbyPlayers[i].carPreview = GetCarPreviewPath(nearbyPlayers[i].sessionId)
    end
end

local sessionStateEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_SessionState'),
        result1 = ac.StructItem.int32(),
        result2 = ac.StructItem.int32(),
        result3 = ac.StructItem.int32(),
        sessionState = ac.StructItem.int32(),
        rivalSessionId = ac.StructItem.int32(),
    }, function (sender, message) OnSessionState(message) end)

local eloEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Elo'),
        elo = ac.StructItem.int32()
    }, function (sender, message) OnElo(message) end)

-- Also sent by the client, with magic values in inviteSenderName and inviteRecipientGuid:
-- "nearby"/1 invites the nearest car, "a"/1 accepts the pending invite, and ""/<guid>
-- invites that player.
local inviteEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Invite'),
        inviteSenderName = ac.StructItem.string(),
        inviteRecipientGuid = ac.StructItem.uint64(),
        inviteSenderElo = ac.StructItem.int32(),
        inviteSenderId = ac.StructItem.string(),
        courseName = ac.StructItem.string(),
        isCourse = ac.StructItem.boolean(),
    }, function (sender, message) OnInvite(message) end)

local notificationEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Notification'),
        message = ac.StructItem.string(64),
        isCountdown = ac.StructItem.boolean(),
    }, function (sender, message) OnNotification(message) end)

-- Client to server only.
local forfeitEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Forfeit'),
        forfeit = ac.StructItem.boolean()
    }, function (sender, message) end)

local initializationEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Initialization'),
        elo = ac.StructItem.int32(),
        racesCompleted = ac.StructItem.int32(),
        useTrackFinish = ac.StructItem.boolean(),
        discreteMode = ac.StructItem.boolean(),
        loadSteamAvatars = ac.StructItem.boolean(),
        courseNames = ac.StructItem.string(1024),
        showRaceTypeToggle = ac.StructItem.boolean(),
    }, function (sender, message) OnInitialization(message) end)

local lobbyStatusEvent = ac.OnlineEvent({
    ac.StructItem.key('AS_LobbyStatus'),
    nearbyName1 = ac.StructItem.string(),
    nearbyId1 = ac.StructItem.uint64(),
    nearbyInRace1 = ac.StructItem.boolean(),
    nearbyElo1 = ac.StructItem.int32(),
    nearbySessionId1 = ac.StructItem.int32(),
    nearbyName2 = ac.StructItem.string(),
    nearbyId2 = ac.StructItem.uint64(),
    nearbyInRace2 = ac.StructItem.boolean(),
    nearbyElo2 = ac.StructItem.int32(),
    nearbySessionId2 = ac.StructItem.int32(),
    nearbyName3 = ac.StructItem.string(),
    nearbyId3 = ac.StructItem.uint64(),
    nearbyInRace3 = ac.StructItem.boolean(),
    nearbyElo3 = ac.StructItem.int32(),
    nearbySessionId3 = ac.StructItem.int32(),
    nearbyName4 = ac.StructItem.string(),
    nearbyId4 = ac.StructItem.uint64(),
    nearbyInRace4 = ac.StructItem.boolean(),
    nearbyElo4 = ac.StructItem.int32(),
    nearbySessionId4 = ac.StructItem.int32(),
    nearbyName5 = ac.StructItem.string(),
    nearbyId5 = ac.StructItem.uint64(),
    nearbyInRace5 = ac.StructItem.boolean(),
    nearbyElo5 = ac.StructItem.int32(),
    nearbySessionId5 = ac.StructItem.int32(),
}, function (sender, message) OnLobbyStatus(message) end)

-- Sends a client message, unless the mock panel is driving the HUD.
local function SendToServer(event, payload)
    if mockActive then
        ac.log('Touge mock: message not sent to the server')
        return
    end
    event(payload)
end

-- Ask the server for the initial state.
initializationEvent({elo = elo, racesCompleted = racesCompleted})

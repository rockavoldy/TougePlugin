-- Debug mock panel. Fakes every server message by calling the same handlers as the real
-- events, so each HUD state can be shown without a second player. Opens from the online
-- extras menu when debugHud is true (00_config.lua).
--
-- Using any mock control sets mockActive, which stops the HUD from sending anything to the
-- server. Reset clears the mock state and asks the server for the real state again.

if debugHud then
    local resultNames = { [0] = "Tbd", "Win", "Loss", "Tie" }
    local stateNames = { "Off", "FirstTwo", "SuddenDeath", "Finished", "CatAndMouse" }
    local shortName = "Takumi"
    local longName = "An Extremely Long Player Name For Testing"

    local mockStandings = { RaceResults.Tbd, RaceResults.Tbd, RaceResults.Tbd }
    local mockHudState = HudStates.Off
    local mockElo = 1000
    local mockDiscrete = false
    local mockToggle = false
    local mockManyCourses = false

    local function MockSessionState()
        mockActive = true
        OnSessionState({
            result1 = mockStandings[1],
            result2 = mockStandings[2],
            result3 = mockStandings[3],
            sessionState = mockHudState,
            -- Without a second player, the player's own car stands in as the rival.
            rivalSessionId = mockHudState == HudStates.Off and -1 or car.sessionID,
        })
    end

    local function MockInitialization()
        mockActive = true
        local names = { "Akina Downhill" }
        if mockManyCourses then
            names = { "Akina Downhill", "Akina Uphill", "Usui Pass", "Irohazaka With A Very Long Course Name",
                "Myogi", "Akagi", "Happogahara", "Tsuchisaka" }
        end
        OnInitialization({
            elo = mockElo,
            racesCompleted = 0,
            useTrackFinish = true,
            discreteMode = mockDiscrete,
            loadSteamAvatars = false,
            courseNames = table.concat(names, "`"),
            showRaceTypeToggle = mockToggle,
        })
    end

    local function MockInvite(name)
        mockActive = true
        OnInvite({
            inviteSenderName = name,
            inviteRecipientGuid = 0,
            inviteSenderElo = 1234,
            inviteSenderId = "0",
            courseName = "",
            isCourse = true,
        })
    end

    local function MockLobbyStatus(count)
        mockActive = true
        local names = { shortName, "Keisuke", "Ryosuke Takahashi", longName, "Iketani" }
        local message = {}
        for i = 1, 5 do
            local present = i <= count
            message['nearbyName' .. i] = present and names[i] or ""
            message['nearbyId' .. i] = present and i or 0
            message['nearbyInRace' .. i] = present and i == 3 -- one player shown as busy
            message['nearbyElo' .. i] = present and (650 + i * 150) or 0
        end
        OnLobbyStatus(message)
        hasCourseSelectOpen = false
        hasInviteMenuOpen = true
    end

    local function MockNotification(text, isCountdown)
        mockActive = true
        OnNotification({ message = text, isCountdown = isCountdown })
    end

    local function ResetMock()
        mockStandings = { RaceResults.Tbd, RaceResults.Tbd, RaceResults.Tbd }
        mockHudState = HudStates.Off
        OnSessionState({ result1 = 0, result2 = 0, result3 = 0, sessionState = HudStates.Off, rivalSessionId = -1 })
        mockShowForfeit = false
        mockRaceOverride = false
        mockGapSeconds = 0
        hasActiveInvite = false
        hasIncomingNotification = false
        isCountdownHudActive = false
        hasInviteMenuOpen = false
        hasCourseSelectOpen = false
        nearbyPlayers = {}
        mockActive = false
        -- The server answers with the real Elo and settings.
        initializationEvent({elo = elo, racesCompleted = racesCompleted})
    end

    local function MockWindow()
        ui.textColored("Mock data is local only. While it is active, nothing is sent to the server.", rgbm.colors.red)
        ui.text(mockActive and "Mock: active" or "Mock: inactive")
        ui.sameLine()
        if ui.button("Reset") then ResetMock() end

        ui.separator()
        ui.text("Session state")
        for i, name in ipairs(stateNames) do
            if i > 1 then ui.sameLine() end
            if ui.button(name) then
                mockHudState = HudStates[name]
                MockSessionState()
            end
        end
        for i = 1, 3 do
            if i > 1 then ui.sameLine() end
            if ui.button("Round " .. i .. ": " .. resultNames[mockStandings[i]] .. "##round" .. i) then
                mockStandings[i] = (mockStandings[i] + 1) % 4
                MockSessionState()
            end
        end

        ui.separator()
        ui.text("Race data")
        if ui.checkbox("Override gap", mockRaceOverride) then
            mockRaceOverride = not mockRaceOverride
            mockActive = true
        end
        local gap, gapChanged = ui.slider("##mockGap", mockGapSeconds, -5, 5, "Gap: %.2f s")
        if gapChanged then
            mockGapSeconds = gap
        end
        ui.text(string.format("Pos %s | %.1f m | %s s | %s (%s) vs %s (%s)",
            tostring(race.position), race.gapMeters,
            race.gapSeconds and string.format("%.2f", race.gapSeconds) or "-",
            race.driverName, race.driverCarName, race.rivalName, race.rivalCarName))

        ui.separator()
        ui.text("Elo")
        for i, value in ipairs({ 650, 999, 1000, 1500, 2400 }) do
            if i > 1 then ui.sameLine() end
            if ui.button(tostring(value)) then
                mockElo = value
                mockActive = true
                OnElo({ elo = value })
            end
        end

        ui.separator()
        ui.text("Initialization (Elo counts up from 100 below)")
        if ui.checkbox("Discrete mode", mockDiscrete) then mockDiscrete = not mockDiscrete end
        if ui.checkbox("Race type toggle", mockToggle) then mockToggle = not mockToggle end
        if ui.checkbox("8 courses (opens course select)", mockManyCourses) then mockManyCourses = not mockManyCourses end
        if ui.button("Send initialization") then MockInitialization() end

        ui.separator()
        ui.text("Invite menu")
        if ui.button("0 players") then MockLobbyStatus(0) end
        ui.sameLine()
        if ui.button("1 player") then MockLobbyStatus(1) end
        ui.sameLine()
        if ui.button("5 players") then MockLobbyStatus(5) end
        ui.sameLine()
        if useIdHud then
            -- The course select is part of the integrated menu's Challenge tab.
            for _, tab in ipairs({ { "challenge", "Challenge" }, { "profile", "Profile" }, { "howto", "How to play" } }) do
                ui.sameLine()
                if ui.button("Menu: " .. tab[2]) then
                    mockActive = true
                    menuTab = tab[1]
                    hasInviteMenuOpen = true
                end
            end
        elseif ui.button("Course select") then
            mockActive = true
            hasInviteMenuOpen = false
            hasCourseSelectOpen = true
            selectedPlayerId = 1
        end

        ui.separator()
        ui.text("Popups")
        if ui.button("Invite: short name") then MockInvite(shortName) end
        ui.sameLine()
        if ui.button("Invite: long name") then MockInvite(longName) end
        if ui.button("Notification: short") then MockNotification("Invite accepted.", false) end
        ui.sameLine()
        if ui.button("Notification: long") then
            MockNotification("Keisuke won the race by outrunning Takumi on Akina Downhill.", false)
        end
        if ui.checkbox("Forfeit dialog", mockShowForfeit) then
            mockShowForfeit = not mockShowForfeit
            mockActive = true
        end

        ui.separator()
        ui.text("Countdown")
        for i, text in ipairs({ "Ready...", "Set...", "Go!" }) do
            if i > 1 then ui.sameLine() end
            if ui.button(text) then MockNotification(text, true) end
        end

        ui.separator()
        ui.text("Tutorial")
        if ui.checkbox("Hidden", hasTutorialHidden) then hasTutorialHidden = not hasTutorialHidden end
        if ui.checkbox("Auto-hidden (shows only below 10 km/h)", isTutorialAutoHidden) then
            isTutorialAutoHidden = not isTutorialAutoHidden
        end
    end

    ui.registerOnlineExtra(ui.Icons.SettingsAlt, "Touge HUD Mock", function () return true end, MockWindow, nil, ui.OnlineExtraFlags.Tool)
end

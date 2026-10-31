-- Keyboard input and timers.

local function KeyPressed(key)
    return ui.keyboardButtonPressed(key, false) and not ui.anyItemFocused() and not ui.anyItemActive()
end

local function InputCheck()
    mouseClickHandled = false
    if KeyPressed(ui.KeyIndex.N) then
        -- Send invite
        SendToServer(inviteEvent, {inviteSenderName = "nearby", inviteRecipientGuid = 1})
        PlaySound("send")
    end
    if KeyPressed(ui.KeyIndex.I) then
        hasInviteMenuOpen = not hasInviteMenuOpen
        PlaySound(hasInviteMenuOpen and "open" or "close")
        if hasInviteMenuOpen then
            local now = os.clock()
            if now - lastLobbyStatusRequest > lobbyCooldown then
                lastLobbyStatusRequest = now
                SendToServer(lobbyStatusEvent)
            end
        end
    end
    if hasActiveInvite and KeyPressed(ui.KeyIndex.M) then
        AcceptInvite()
    end
    if KeyPressed(ui.KeyIndex.H) then
        hasTutorialHidden = not hasTutorialHidden
    end
    if currentHudState ~= HudStates.Off then
        if ui.keyboardButtonDown(ui.KeyIndex.F) then
            if not forfeitLockout then
                if not forfeitStartTime then
                    forfeitStartTime = os.clock()
                elseif os.clock() - forfeitStartTime >= forfeitHoldDuration then
                    SendToServer(forfeitEvent, {forfeit = true})
                    forfeitStartTime = nil -- reset so it doesn't trigger repeatedly
                    forfeitLockout = true  -- prevent repeat forfeits on same hold
                end
            end
        else
            forfeitStartTime = nil -- reset if key is released
            forfeitLockout = false
        end
    end
end

local function UpdateTimers(dt)
    if checkTimeout(inviteActivatedAt, 10) then
        hasActiveInvite = false
        inviteActivatedAt = nil
    end

    if checkTimeout(notificationActivatedAt, 10) then
        hasIncomingNotification = false
        notificationActivatedAt = nil
    end

    if checkTimeout(countdownActivatedAt, 5) then
        isCountdownHudActive = false
        countdownActivatedAt = nil
    end

    if discreteMode and showElo and eloShownAt ~= nil and os.clock() - eloShownAt >= 15 then
        eloShownAt = nil
        showElo = false
    end

    -- Animate the displayed Elo towards the target. It stays fractional; rounding happens when drawn.
    if elo ~= targetElo then
        local step = eloAnimSpeed * dt
        if math.abs(targetElo - elo) <= step then
            elo = targetElo
        elseif targetElo > elo then
            elo = elo + step
        else
            elo = elo - step
        end
    end
end

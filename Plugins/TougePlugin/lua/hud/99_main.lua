function script.drawUI(dt)
    -- Follow window resizes
    scaling.update()
    windowWidth = sim.windowWidth
    windowHeight = sim.windowHeight

    DrawStandings()
    if useIdHud then
        DrawEloCard()
        DrawMenuHint()
        DrawTougeMenu()
    else
        DrawElo()
        DrawTutorial()
        DrawInviteMenu()
        DrawCourseSelect()
    end
    DrawCluster()
    if useIdHud then
        DrawAs6Countdown()
        DrawAs6Popups()
    else
        DrawCountdown()
        DrawPopups()
    end
end

function script.update(dt)
    InputCheck()
    UpdateTimers(dt)
    UpdateRace(dt)
end

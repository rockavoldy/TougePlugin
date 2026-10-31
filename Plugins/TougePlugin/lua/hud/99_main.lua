function script.drawUI(dt)
    -- Follow window resizes
    scaling.update()
    windowWidth = sim.windowWidth
    windowHeight = sim.windowHeight

    DrawStandings()
    DrawElo()
    if useIdHud then
        DrawMenuHint()
        DrawTougeMenu()
    else
        DrawTutorial()
        DrawInviteMenu()
        DrawCourseSelect()
    end
    DrawCluster()
    DrawCountdown()
    DrawPopups()
end

function script.update(dt)
    InputCheck()
    UpdateTimers(dt)
    UpdateRace(dt)
end

function script.drawUI(dt)
    -- Follow window resizes
    scaling.update()
    windowWidth = sim.windowWidth
    windowHeight = sim.windowHeight

    DrawStandings()
    DrawElo()
    DrawTutorial()
    DrawInviteMenu()
    DrawCourseSelect()
    DrawCountdown()
    DrawPopups()
end

function script.update(dt)
    InputCheck()
    UpdateTimers(dt)
    UpdateRace(dt)
end

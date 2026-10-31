function script.drawUI(dt)
    -- Follow window resizes
    scaling.update()
    windowWidth = sim.windowWidth
    windowHeight = sim.windowHeight

    DrawEloCard()
    DrawMenuHint()
    DrawTougeMenu()
    DrawCluster()
    DrawCountdown()
    DrawPopups()
end

function script.update(dt)
    InputCheck()
    UpdateTimers(dt)
    UpdateRace(dt)
end

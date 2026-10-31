-- Live race data, measured on the client from the two cars' spline positions. Read by the
-- in-race cluster. All gaps are from the player's point of view: positive when ahead.
local race = {
    position = nil,     -- 1 or 2, nil outside a session
    gapMeters = 0,
    gapSeconds = nil,   -- nil while the leader's history does not reach back far enough
    driverName = "",
    driverCarName = "",
    rivalName = "",
    rivalCarName = "",
}

-- Each car's recent spline positions, so the time gap can be read as "how long ago the
-- leader passed the point where the follower is now". Ring buffers keyed by car index.
local historyInterval = 0.05 -- seconds between samples
local historyLength = 600    -- 30 seconds
local histories = {}
local raceClock = 0

-- Wraps a spline delta into [-0.5, 0.5), so positions on either side of the track's start
-- line compare correctly.
local function WrapSpline(delta)
    return (delta + 0.5) % 1 - 0.5
end

local function HistoryFor(carIndex)
    if histories[carIndex] == nil then
        histories[carIndex] = { time = {}, spline = {}, head = 0, count = 0, lastSample = -math.huge }
    end
    return histories[carIndex]
end

local function RecordSample(history, now, spline)
    -- A jump means the car was teleported (a new round starts), so the old samples no longer
    -- describe this run.
    if history.count > 0 and math.abs(WrapSpline(spline - history.spline[history.head])) > 0.02 then
        history.count = 0
    end

    if history.count > 0 and now - history.lastSample < historyInterval then
        return
    end
    history.lastSample = now
    history.head = history.head % historyLength + 1
    history.time[history.head] = now
    history.spline[history.head] = spline
    history.count = math.min(history.count + 1, historyLength)
end

-- Returns when the car passed the given spline position, interpolated between samples, or
-- nil if that is older than its history.
local function TimeAtSpline(history, spline)
    local newer = history.head
    for _ = 2, history.count do
        local older = (newer - 2) % historyLength + 1
        local newerDelta = WrapSpline(history.spline[newer] - spline)
        local olderDelta = WrapSpline(history.spline[older] - spline)
        if olderDelta <= 0 and newerDelta >= 0 then
            local span = newerDelta - olderDelta
            local fraction = span > 0 and -olderDelta / span or 0
            return history.time[older] + (history.time[newer] - history.time[older]) * fraction
        end
        newer = older
    end
    return nil
end

local function UpdateRace(dt)
    raceClock = raceClock + dt

    if mockRaceOverride then
        race.position = mockGapSeconds >= 0 and 1 or 2
        race.gapSeconds = mockGapSeconds
        race.gapMeters = mockGapSeconds * 30 -- about 108 km/h
        race.driverName = ac.getDriverName(0)
        race.driverCarName = ac.getCarName(0)
        race.rivalName = "Mock Rival With A Long Name"
        race.rivalCarName = ac.getCarName(0)
        return
    end

    if rivalCar == nil or car == nil then
        race.position = nil
        race.gapMeters = 0
        race.gapSeconds = nil
        if next(histories) ~= nil then
            histories = {}
        end
        return
    end

    local mySpline = car.splinePosition
    local rivalSpline = rivalCar.splinePosition
    local myHistory = HistoryFor(car.index)
    local rivalHistory = HistoryFor(rivalCar.index)
    RecordSample(myHistory, raceClock, mySpline)
    RecordSample(rivalHistory, raceClock, rivalSpline)

    local lead = WrapSpline(mySpline - rivalSpline)
    local isAhead = lead >= 0
    race.position = isAhead and 1 or 2
    race.gapMeters = lead * sim.trackLengthM

    local passedAt
    if isAhead then
        passedAt = TimeAtSpline(myHistory, rivalSpline)
    else
        passedAt = TimeAtSpline(rivalHistory, mySpline)
    end
    if passedAt ~= nil then
        race.gapSeconds = (raceClock - passedAt) * (isAhead and 1 or -1)
    else
        race.gapSeconds = nil
    end

    race.driverName = ac.getDriverName(car.index)
    race.driverCarName = ac.getCarName(car.index)
    race.rivalName = ac.getDriverName(rivalCar.index)
    race.rivalCarName = ac.getCarName(rivalCar.index)

    ac.debug('race.position', race.position)
    ac.debug('race.gapMeters', race.gapMeters)
    ac.debug('race.gapSeconds', race.gapSeconds)
    ac.debug('race.rival', race.rivalName .. ' / ' .. race.rivalCarName)
end

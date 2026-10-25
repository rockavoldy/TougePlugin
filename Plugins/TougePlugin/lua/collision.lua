local supportAPI_collision = physics.disableCarCollisions ~= nil
local localCar = ac.getCar(0)

ac.log('Touge collision.lua loaded')
ac.debug('TP_RaceCollision.supportAPI', supportAPI_collision)
ac.debug('TP_RaceCollision.localSessionID', localCar and localCar.sessionID or -1)
ac.debug('TP_RaceCollision.localIndex', localCar and localCar.index or -1)

-- Server session IDs are not the same as local simulation indices used by
-- physics.disableCarCollisions(). Resolve a server session ID to a local index
-- by scanning the cars simulated on this client.
local function findLocalIndexForSessionId(sessionId)
    for i = 0, sim.carsCount - 1 do
        local car = ac.getCar(i)
        if car and car.sessionID == sessionId then
            return car.index
        end
    end
    return nil
end

local raceCollisionEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('TP_RaceCollision'),
        targetSessionId = ac.StructItem.byte(),
        enabled = ac.StructItem.boolean(),
    },
    function (sender, message)
        if sender ~= nil then
            ac.debug('TP_RaceCollision.unexpectedSender', sender and sender.index or -1)
            return
        end

        ac.debug('TP_RaceCollision.targetSessionId', message.targetSessionId)
        ac.debug('TP_RaceCollision.enabled', message.enabled)

        if not supportAPI_collision then
            ac.log('[Touge] TP_RaceCollision ignored: physics.disableCarCollisions API is unavailable')
            return
        end

        local targetIndex = findLocalIndexForSessionId(message.targetSessionId)

        if targetIndex == nil then
            ac.log('[Touge] TP_RaceCollision could not resolve targetSessionId='
                .. tostring(message.targetSessionId)
                .. ' enabled=' .. tostring(message.enabled)
                .. ' localSessionID=' .. tostring(localCar and localCar.sessionID or -1)
                .. ' localIndex=' .. tostring(localCar and localCar.index or -1))
            return
        end

        ac.debug('TP_RaceCollision.resolvedTargetIndex', targetIndex)

        local ok, err = pcall(function ()
            physics.disableCarCollisions(targetIndex, not message.enabled)
        end)

        if not ok then
            ac.log('[Touge] TP_RaceCollision failed: ' .. tostring(err)
                .. ' targetSessionId=' .. tostring(message.targetSessionId)
                .. ' resolvedTargetIndex=' .. tostring(targetIndex)
                .. ' enabled=' .. tostring(message.enabled)
                .. ' localSessionID=' .. tostring(localCar and localCar.sessionID or -1)
                .. ' localIndex=' .. tostring(localCar and localCar.index or -1))
        else
            ac.debug('TP_RaceCollision.applied', targetIndex)
        end
    end
)
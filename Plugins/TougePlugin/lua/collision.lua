local supportAPI_collision = physics.disableCarCollisions ~= nil

local raceCollisionEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('TP_RaceCollision'),
        targetSessionId = ac.StructItem.byte(),
        enabled = ac.StructItem.boolean(),
    },
    function (sender, message)
        if sender ~= nil then
            return
        end
        if supportAPI_collision then
            physics.disableCarCollisions(message.targetSessionId, not message.enabled)
        end
    end
)

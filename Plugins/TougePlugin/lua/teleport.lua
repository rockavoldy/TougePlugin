local supportAPI_collision = physics.disableCarCollisions ~= nil
local lockInputAPI = physics.lockUserControlsFor ~= nil
local vec = {x=vec3(1,0,0),y=vec3(0,1,0),z=vec3(0,0,1),empty=vec3(),empty2=vec2()}

ac.log('Touge teleport.lua loaded')
ac.debug('AS_Teleport.supportAPI_collision', supportAPI_collision)
ac.debug('AS_Teleport.lockInputAPI', lockInputAPI)

local function dir3FromHeading(heading)
    local h = math.rad(heading + ac.getCompassAngle(vec.z))
    return vec3(-math.sin(h), 0, -math.cos(h))
end

function TeleportExec(pos, rot)
    ac.debug('AS_Teleport.position', pos)
    ac.debug('AS_Teleport.headingVec', rot)

    if supportAPI_collision then
        local ok, err = pcall(function () physics.disableCarCollisions(0, true) end)
        if not ok then
            ac.log('[Touge] TeleportExec disableCarCollisions failed: ' .. tostring(err))
        end
    end

    if lockInputAPI then
        local ok, err = pcall(function () physics.lockUserControlsFor(10) end)
        if not ok then
            ac.log('[Touge] TeleportExec lockUserControlsFor failed: ' .. tostring(err))
        end
    end

    pos.y = FindGroundY(pos)  -- Adjust y-coordinate to ground level
    rot.y = 0 -- Make sure the car is right side up.

    ac.debug('AS_Teleport.finalPosition', pos)
    ac.debug('AS_Teleport.finalHeadingVec', rot)

    local ok, err = pcall(function () physics.setCarPosition(0, pos, rot) end)
    if not ok then
        ac.log('[Touge] TeleportExec setCarPosition failed: ' .. tostring(err))
    end
end

local teleportEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Teleport'),
        position = ac.StructItem.vec3(),
        heading = ac.StructItem.int32(),
    },
    function(sender, message)
        if sender ~= nil then
            ac.debug('AS_Teleport.unexpectedSender', sender and sender.index or -1)
            return
        end
        ac.debug('AS_Teleport.heading', message.heading)
        local direction = dir3FromHeading(message.heading)
        TeleportExec(message.position, direction)
    end
)

local lockControlsEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_LockControls'),
        lockControls = ac.StructItem.boolean(),
    },
    function (sender, message)
        ac.debug('AS_LockControls.lockControls', message.lockControls)

        local lockTimer = 10
        if message.lockControls == false then
            lockTimer = 0
        end

        if lockInputAPI then
            local ok, err = pcall(function () physics.lockUserControlsFor(lockTimer) end)
            if not ok then
                ac.log('[Touge] AS_LockControls failed: ' .. tostring(err))
            end
        end
    end
)

function FindGroundY(pos)
    local dir = vec3(0, -1, 0)  -- Direction: downward
    local maxDistance = 100.0    -- Maximum distance to check
    local distance = physics.raycastTrack(pos, dir, maxDistance)
    if distance >= 0 then
        return pos.y - distance
    else
        return pos.y  -- Fallback if no hit detected
    end
end
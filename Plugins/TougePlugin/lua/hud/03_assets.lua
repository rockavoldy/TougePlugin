-- Asset manifest. Every file the HUD downloads is listed here.
-- Bump the ?v= suffix of a file whenever its content changes, or clients keep the cached copy.
local assets = {
    images = {
        elo = baseUrl .. "Elo.png",
        standings = baseUrl .. "Standings.png",
        playerCard = baseUrl .. "PlayerCard.png",
        mKey = baseUrl .. "MKey.png",
        inviteMenu = baseUrl .. "InviteMenu.png",
        tutorial = baseUrl .. "Tutorial.png",
        key = baseUrl .. "Key.png",
        toggle = baseUrl .. "Toggle.png",
    },
    avatars = baseUrl .. "avatars/",
    fontsZip = baseUrl .. "fonts.zip",
    countdownZip = baseUrl .. "countdown.zip?v=4-beeps",
}

local font = ""
local fontBold = ""
local fontSemiBold = ""

-- Load fonts
web.loadRemoteAssets(assets.fontsZip, function(err, folder)
    if err then
      print("Failed to load fonts: " .. err)
      return
    end

    local fontPath = folder .. "/twoweekendgo-regular.otf"
    local fontPathBold = folder .. "/twoweekendgo-bold.otf"
    local fontPathSemiBold = folder .. "/twoweekendgo-semibold.otf"
    font = string.format("Two Weekend Go:%s", fontPath)
    fontBold = string.format("Two Weekend Go:%s", fontPathBold)
    fontSemiBold = string.format("Two Weekend Go:%s", fontPathSemiBold)
end)

-- Load countdown audio
web.loadRemoteAssets(assets.countdownZip, function(err, folder)
    if err then
        print("Failed to load countdown sound: " .. err)
        return
    end

    countdownSoundPath = folder .. "/countdown.wav"
end)

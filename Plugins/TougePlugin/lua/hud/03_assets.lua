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
        idNameExtended = baseUrl .. "id/name_background_extended.png?v=1",
        -- name_background.png without its baked-in labels (tools/blank_name_shell.py).
        idNameBlank = baseUrl .. "id/name_background_blank.png?v=1",
        idAdvantage = baseUrl .. "id/advantage_background.png?v=1",
    },
    avatars = baseUrl .. "avatars/",
    fontsZip = baseUrl .. "fonts.zip",
    countdownZip = baseUrl .. "countdown.zip?v=4-beeps",
    -- Digit sprites from the D Extra app's D6 theme, the same theme as the id/ shells.
    idDigitsZip = baseUrl .. "id/id_digits.zip?v=1",
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

-- Initial D digit sprites. Stays nil until the zip has loaded; the cluster is not drawn
-- before that, so it never shows without its numbers.
local idSprites = nil

web.loadRemoteAssets(assets.idDigitsZip, function(err, folder)
    if err then
        print("Failed to load Initial D digits: " .. err)
        return
    end

    local sprites = { digits = {}, positionDigits = {} }
    for i = 0, 9 do
        sprites.digits[i] = folder .. "/digits/digits_" .. i .. ".png"
        sprites.positionDigits[i] = folder .. "/position_digits/position_digits_" .. i .. ".png"
    end
    sprites.minus = folder .. "/digits/digits_minus.png"
    sprites.plus = folder .. "/digits/digits_plus.png"
    sprites.pointM = folder .. "/digits/digits_m.png" -- ". m"; only the point is drawn
    sprites.positionDash = folder .. "/position_digits/position_digits_dash.png"
    idSprites = sprites
end)

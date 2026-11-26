-- ==== 00_config.lua ====
-- Touge HUD client script.
--
-- Embedded in the plugin (Embedded/Lua/hud.lua) and pushed to clients by the server. It is
-- organized into "-- ==== <part> ====" sections that mirror the original split-file layout;
-- locals declared in an earlier section are visible in later ones.

local baseUrl = "http://" .. ac.getServerIP() .. ":" .. ac.getServerPortHTTP() .. "/static/TougePlugin/"

-- Adds the "Touge HUD Mock" window to the online extras menu, which fakes every server
-- message locally. Keep it off for release builds.
local debugHud = false

ac.log('Touge hud.lua loaded')

local HudStates = {
    Off = 0,
    FirstTwo = 1,
    SuddenDeath = 2,
    Finished = 3,
    CatAndMouse = 4,
    NoUpdate = 5,
}

local RaceResults = {
    Tbd = 0,
    Win = 1,
    Loss = 2,
    Tie = 3,
}

-- UI sounds, loaded from sounds.zip as <name>.wav. A slot without a file stays silent.
-- Volume multiplies the file's own level.
local soundSlots = {
    pick = { volume = 1 },      -- a tab, driver, course or race type is clicked
    open = { volume = 1 },      -- the menu opens
    close = { volume = 1 },     -- the menu closes
    send = { volume = 1 },      -- a challenge is sent
    accept = { volume = 1 },    -- a challenge is accepted
    invite = { volume = 1 },    -- a challenge arrives
    notify = { volume = 1 },    -- a notification arrives
    countdown = { volume = 3.75 }, -- from countdown.zip, played on "Ready..."
}

-- ==== 01_scaling.lua ====
-- Scaling
-- Layout values are written in reference pixels and scaled at draw time, so the HUD follows
-- window resizes. scaling.update() runs at the start of every frame.
local baseRes = vec2(2560, 1440) -- Reference resolution
local scaleFactor = 1

local scaling = {}

function scaling.update()
    scaleFactor = math.min(sim.windowWidth / baseRes.x, sim.windowHeight / baseRes.y, 1)
end

function scaling.vec2(x, y)
    return vec2(x, y) * scaleFactor
end

-- Scales a number or a vec2.
function scaling.size(size)
    return size * scaleFactor
end

function scaling.get()
    return scaleFactor
end

scaling.update()

-- ==== 02_state.lua ====
-- HUD state. Written by the event handlers, input and timers; read by the draw functions.

local windowWidth = sim.windowWidth
local windowHeight = sim.windowHeight

local discreteMode = false

-- elo is the displayed value, animated towards targetElo. -1 means unknown.
local elo = -1
local targetElo = -1
local eloAnimSpeed = 60 -- points per second
local showElo = true
local eloShownAt = nil

local racesCompleted = 0

local inviteSenderName = ""
local inviteSenderElo = -1
local inviteCourseName = ""
local hasActiveInvite = false
local inviteActivatedAt = nil

local hasInviteMenuOpen = false
local nearbyPlayers = {}
local selectedPlayerId = -1
local lastLobbyStatusRequest = 0
local lobbyCooldown = 1.0  -- Cooldown in seconds
local courseNames = {}
local courseScroll = 0 -- first visible row of the course list
local selectedCourseIndex = 1
local menuTab = "challenge" -- "challenge", "profile" or "howto"
local showRaceTypeToggle = false
local isToggleCourse = true

local standings = { 0, 0, 0 }  -- Default, no rounds have been completed.
local currentHudState = 0
local rivalCar = nil -- ac.StateCar of the opponent while in a session

local hasTutorialHidden = false
local isTutorialAutoHidden = false

local notificationMessage = ""
local hasIncomingNotification = false
local notificationActivatedAt = nil

local countdownHudMessage = ""
local isCountdownHudActive = false
local countdownActivatedAt = nil
-- Player settings, saved by CSP between sessions (Documents\Assetto Corsa\cfg\extension\state\lua).
local settings = ac.storage({
    soundEnabled = true,
    soundVolume = 0.8, -- master volume, 0 to 1, applied on top of each slot's volume
}, "touge_")
local isDraggingVolume = false

local soundPaths = {} -- slot name to the local file, filled as the sound zips load
local soundEvents = {} -- slot name to the ac.AudioEvent playing it

local forfeitStartTime = nil
local forfeitHoldDuration = 3.0 -- seconds
local forfeitLockout = false

local mouseClickHandled = false

-- Set by the mock panel. While mockActive is true nothing is sent to the server.
local mockActive = false
local mockShowForfeit = false
-- When set, the race tracker reports mockGapSeconds instead of measuring the cars.
local mockRaceOverride = false
local mockGapSeconds = 0

local car = ac.getCar(0)

-- ==== 03_assets.lua ====
-- Asset manifest. Every file the HUD downloads is listed here.
-- Bump the ?v= suffix of a file whenever its content changes, or clients keep the cached copy.
local assets = {
    images = {
        idNameExtended = baseUrl .. "id/name_background_extended.png?v=2",
        idAdvantage = baseUrl .. "id/advantage_background.png?v=2",
    },
    fontsZip = baseUrl .. "fonts.zip?v=2",
    countdownZip = baseUrl .. "countdown.zip?v=4-beeps",
    soundsZip = baseUrl .. "sounds.zip?v=2",
    -- Digit sprites from the D Extra app's D6 theme, the same theme as the id/ shells.
    idDigitsZip = baseUrl .. "id/id_digits.zip?v=2",
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

    soundPaths.countdown = folder .. "/countdown.wav"
end)

-- UI sounds. Only the slots whose file is in the zip get a path.
web.loadRemoteAssets(assets.soundsZip, function(err, folder)
    if err then
        print("Failed to load UI sounds: " .. err)
        return
    end

    for name in pairs(soundSlots) do
        local path = folder .. "/" .. name .. ".wav"
        if name ~= "countdown" and io.fileExists(path) then
            soundPaths[name] = path
        end
    end
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

-- ==== 04_layout.lua ====
-- Layout tables. One table per HUD element: its size, screen anchor, colours and the
-- positions of everything drawn in it. Values are shell pixels (see 06_shell.lua) relative
-- to the element's top-left corner unless noted otherwise.
local layout = {
    -- Initial D elements are laid out in the shells' native pixels; shellScale converts
    -- them to reference pixels so the shells are drawn 1:1 at 1080p (see 06_shell.lua).
    shellScale = 1440 / 1080,

    -- Compact Elo card, top-left, in the style of the menu cards: the Elo in a dark box,
    -- the player's name and an Elo-coloured chip beside it.
    eloCard = {
        pos = vec2(50, 50), -- reference pixels from the top-left of the screen
        size = vec2(300, 56),
        boxMin = vec2(6, 6),
        boxMax = vec2(100, 50),
        boxFontSize = 26,
        nameMin = vec2(112, 6),
        nameMax = vec2(288, 32),
        nameFontSize = 19,
        nameMinFontSize = 14,
        chipMin = vec2(112, 34),
        chipSize = vec2(64, 15),
    },

    -- Menus in the style of the Initial D Arcade Stage 6 menus, in a dark theme that sits
    -- with the race HUD: a steel title bar, a subtitle pill and dark cards with a gold frame
    -- on hover. Drawn in code; every size and colour is here so images can replace the
    -- shapes later.
    as6Panel = {
        -- Animation times in seconds, and slide distances in shell pixels (see 07_tween.lua).
        motion = {
            fade = 0.25, -- Elo card and menu hint
            menu = 0.18,
            menuSlide = 16, -- the menu rises into place
            popup = 0.25,
            popupSlide = 60, -- popups slide in from the right
            countdown = 0.3,
            countdownPop = 1.3, -- each countdown step starts this much larger
        },

        -- Corner radii, shared by every shape so the corners match: the window, cards and
        -- buttons, boxes inside a card, and chips. Pills are fully round.
        radius = { window = 10, card = 6, inner = 4, chip = 3 },
        -- Space between text and the sides of the shape it sits in.
        textInset = 6,
        chipTextInset = 3,

        -- Frosted backdrop: the scene behind the panel, blurred, under a dark layer.
        backdrop = {
            blur = 12,
            tint = rgbm(0.04, 0.06, 0.1, 0.62),
            border = rgbm(0.45, 0.55, 0.7, 0.5),
        },

        title = {
            height = 50,
            top = rgbm(0.2, 0.24, 0.31, 0.97), -- dark steel gradient
            bottom = rgbm(0.1, 0.12, 0.17, 0.97),
            highlight = rgbm(0.55, 0.65, 0.8, 0.6),
            fontSize = 26,
            color = rgbm(0.93, 0.95, 0.98, 1),
        },

        subtitle = {
            fill = rgbm(0.1, 0.13, 0.18, 0.9),
            border = rgbm(0.35, 0.42, 0.52, 0.8),
            fontSize = 14,
            color = rgbm(0.75, 0.8, 0.86, 1),
        },

        -- Course / Outrun pills under the subtitle.
        toggle = {
            size = vec2(140, 28),
            gap = 12,
            fontSize = 15,
            idleFill = rgbm(0.2, 0.24, 0.3, 0.92),
            idleText = rgbm(0.75, 0.8, 0.86, 1),
            selectedFill = rgbm(0.26, 0.46, 0.86, 1), -- the race HUD's driver blue
            selectedText = rgbm(1, 1, 1, 1),
        },

        card = {
            size = vec2(496, 92),
            step = 100,
            fill = rgbm(0.11, 0.13, 0.17, 0.94),
            border = rgbm(0.28, 0.33, 0.41, 1),

            -- Dark box on the left with the headline value (Elo, race type) in red.
            boxMin = vec2(8, 8),
            boxMax = vec2(116, 60),
            boxFill = rgbm(0.05, 0.06, 0.08, 1),
            boxBorder = rgbm(0.3, 0.35, 0.43, 1),
            boxFontSize = 26,
            boxColor = rgbm(1, 0.32, 0.32, 1),

            -- Tag chips under the box. Status chips stand out: blue when ready, red in a race.
            chipY = 66,
            chipHeight = 18,
            chipWidth = 52,
            chipGap = 4,
            chipFontSize = 11,
            chipFill = rgbm(0.32, 0.36, 0.43, 1),
            chipText = rgbm(1, 1, 1, 1),
            readyFill = rgbm(0.2, 0.55, 0.95, 1),
            inRaceFill = rgbm(0.92, 0.32, 0.25, 1),

            -- Info area on the right: car image, car name, big driver name, detail line. The
            -- info area and the text end rightInset / textRightInset before the card's edge.
            infoMin = vec2(122, 8),
            infoMax = vec2(488, 84),
            rightInset = 8,
            infoTop = rgbm(0.17, 0.2, 0.26, 1),
            infoBottom = rgbm(0.09, 0.11, 0.15, 1),
            textLeft = 134, -- moves right by imageShift when a car image is shown
            textRightInset = 28,
            captionY = vec2(14, 31),
            captionFontSize = 14,
            nameY = vec2(30, 62),
            nameFontSize = 28,
            nameMinFontSize = 20,
            detailY = vec2(61, 80),
            detailFontSize = 14,
            textColor = rgbm(0.95, 0.96, 0.98, 1),
            mutedColor = rgbm(0.62, 0.67, 0.74, 1),
            busyColor = rgbm(0.45, 0.48, 0.53, 1),
            keyFill = rgbm(0.05, 0.06, 0.08, 1), -- key caps on the How to play tab
            -- Car skin preview, 16:9, cropped to the middle of the picture where the car is.
            image = vec2(128, 24),
            imageSize = vec2(80, 45),
            imageShift = 82,
            imageUvMin = vec2(0.14, 0.14),
            imageUvMax = vec2(0.86, 0.86),
            imageBorder = rgbm(0.28, 0.33, 0.41, 1),

            -- Gold frame around the card under the mouse.
            hover = rgbm(0.93, 0.76, 0.3, 1),
            hoverGlow = rgbm(1, 0.85, 0.4, 0.35),
            hoverThickness = 3,
            hoverGlowThickness = 8,
        },

        -- The integrated menu, centered on the screen: title bar with tabs, subtitle, an
        -- optional pending challenge banner, then the tab content.
        -- Everything keeps padding from the window's edges; the window's height follows the
        -- open tab's content.
        menu = {
            width = 980,
            padding = 24,
            titleText = vec2(24, 0), -- "TOUGE", left-aligned in the title bar
            tabs = { right = 956, y = 11, size = vec2(152, 28), gap = 8, fontSize = 14 },
            subtitleMin = vec2(24, 62),
            subtitleMax = vec2(956, 86),

            banner = {
                y = 100,
                height = 54,
                margin = 24,
                fontSize = 18,
                buttonSize = vec2(150, 34),
            },
            bannerSpace = 66, -- how far the content moves down while the banner shows

            contentTop = 100,
            captionHeight = 26,
            captionFontSize = 13,
            captionColor = rgbm(0.7, 0.76, 0.84, 1),
            leftX = 24,
            leftWidth = 456,
            rightX = 504,
            rightWidth = 452,
            driverRows = 5, -- the Challenge tab is always tall enough for five drivers

            courseCard = {
                height = 46,
                step = 52,
                maxVisible = 5,
                fontSize = 20,
                minFontSize = 15,
                chipWidth = 46,
            },

            summaryFontSize = 15,
            send = {
                size = vec2(300, 46),
                fontSize = 20,
                topColor = rgbm(1, 0.9, 0.55, 1), -- gold gradient
                bottomColor = rgbm(0.86, 0.64, 0.18, 1),
                hoverTopColor = rgbm(1, 0.95, 0.7, 1),
                disabled = rgbm(0.25, 0.28, 0.33, 0.9),
                text = rgbm(0.2, 0.15, 0.05, 1),
                disabledText = rgbm(0.6, 0.64, 0.7, 1),
            },

            profile = {
                cardWidth = 600,
                gap = 12, -- between the card and the stat rows
            },

            -- Rows of the SETTINGS tab, centered: a label on the left, the control on the right.
            -- The PROFILE stat rows use the same row size.
            settings = {
                rowWidth = 600,
                rowHeight = 48,
                rowStep = 56,
                labelX = 16,
                labelFontSize = 20,
                controlX = 220, -- where the control starts, from the row's left edge
                pillSize = vec2(96, 28),
                pillGap = 8,
                trackHeight = 8,
                knobRadius = 11,
                valueWidth = 64, -- the percentage, right-aligned at the row's end
                wheelStep = 0.05, -- volume change per mouse wheel notch
            },

            howto = {
                bodyHeight = 150,
                bodyPadding = 16,
                bodyFontSize = 17,
                keysGap = 20, -- between the body and the key rows
                keyColumns = 2,
                keySize = vec2(46, 46),
                keyRowStep = 58,
                keyFontSize = 22,
                keyLabelFontSize = 16,
            },

            -- Bottom-right popups (invite, notification, forfeit), stacked upwards in that
            -- order. The invite popup is a menu card.
            popup = {
                marginRight = 50, -- reference pixels
                marginBottom = 50,
                width = 440,
                gap = 10,
                messageHeight = 64,
                accent = { x = 10, width = 4, inset = 12 }, -- gold bar on the left edge
                textLeft = 26,
                fontSize = 16,
                barHeight = 8, -- forfeit hold progress
                barBottom = 14,
            },

            -- Countdown text centered on the screen, with a drop shadow and no plate behind it.
            countdown = {
                height = 110, -- room around the text for its pop-in
                paddingX = 56,
                fontSize = 72,
                shadowOffset = 3,
                shadowColor = rgbm(0, 0, 0, 0.6),
                readyColor = rgbm(0.95, 0.96, 0.98, 1),
                setColor = rgbm(1, 0.85, 0.4, 1),
                goColor = rgbm(0.3, 0.8, 0.42, 1),
            },

            hint = { -- shown instead of the tutorial panel while the menu is closed
                marginLeft = 50, -- reference pixels
                marginBottom = 50,
                size = vec2(300, 34),
                fontSize = 14,
            },
        },
    },

    -- Initial D in-race cluster, anchored top-right: the advantage shell, the Driver vs Rival
    -- shell below it, and the round results under that. Positions are from the D Extra
    -- app's D6 config.
    cluster = {
        marginRight = 50, -- reference pixels
        marginTop = 50,
        size = vec2(552, 298),

        advantage = {
            image = assets.images.idAdvantage,
            pos = vec2(0, 0),
            size = vec2(552, 94),
            -- The number reads "+1.30" / "-1.30": sign and whole seconds right-aligned to
            -- integerRight, then the point and two decimals.
            integerRight = 256,
            integerY = 26,
            integerSize = vec2(55, 61),
            point = vec2(256, 26),
            pointSize = vec2(20, 61),
            pointUvMax = vec2(20 / 128, 1), -- the point is the first 20 columns of ". m"
            decimalX = 274,
            decimalY = 33,
            decimalSize = vec2(49, 54),
            redAt = -0.5, -- seconds behind at which the number is fully red
            unknownColor = rgbm(1, 1, 1, 0.5),
        },

        names = {
            image = assets.images.idNameExtended,
            pos = vec2(52, 110),
            size = vec2(500, 160),
            rivalOffset = 90, -- the rival row is the driver row moved down
            nameMin = vec2(100, 3), -- header strip, left of the baked-in "Pos"
            nameMax = vec2(325, 39),
            nameFontSize = 30,
            nameMinFontSize = 22, -- longer names are cut off rather than shrunk further
            carMin = vec2(40, 39), -- coloured band
            carMax = vec2(460, 68),
            carFontSize = 20,
            carMinFontSize = 15,
            position = vec2(374, -1),
            positionSize = vec2(36, 40),
            driverCarColor = rgbm(0.59, 0.75, 0.9, 1),
            rivalCarColor = rgbm(1, 0.41, 0.53, 1),
        },

        rounds = {
            y = 276,
            label = vec2(112, 274),
            labelFontSize = 16,
            labelColor = rgbm(0.45, 0.6, 1, 1),
            pipsRight = 492,
            pipSize = vec2(34, 14),
            pipSpacing = 8,
            win = rgbm(0.3, 0.8, 0.42, 1),     -- green
            loss = rgbm(1, 0.42, 0.53, 1),     -- pink
            tie = rgbm(0.6, 0.6, 0.6, 0.9),
            pending = rgbm(1, 1, 1, 0.12),
            border = rgbm(0.8, 0.85, 1, 0.6),
        },
    },
}

-- ==== 05_util.lua ====
-- Utility functions

local function HsvToRgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b

    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x
    end

    return r + m, g + m, b + m
end

local function GetEloColor(eloValue)
    local hueValue = (eloValue / 2000) * 360 - 80
    local r, g, b = HsvToRgb(hueValue, 0.7, 0.8)
    return rgbm(r, g, b, 1)
end

-- Returns the largest font size (reference pixels) up to startSize at which text fits in
-- maxWidth reference pixels.
local function FindFontSize(text, startSize, textFont, maxWidth)
    ui.pushDWriteFont(textFont)
    local fontSize = startSize
    while fontSize > 8 and ui.measureDWriteText(text, scaling.size(fontSize)).x > scaling.size(maxWidth) do
        fontSize = fontSize - 2
    end
    ui.popDWriteFont()
    return fontSize
end

local function IsInRect(point, rectMin, rectMax)
    return point.x >= rectMin.x and point.x <= rectMax.x and point.y >= rectMin.y and point.y <= rectMax.y
end

-- Consumes this frame's click if it landed inside the rectangle.
local function ConsumeClickIn(mousePos, rectMin, rectMax)
    if not mouseClickHandled and ui.mouseClicked() and IsInRect(mousePos, rectMin, rectMax) then
        mouseClickHandled = true
        return true
    end
    return false
end

local function FindCarBySessionId(sessionId)
    for i = 0, sim.carsCount - 1 do
        local c = ac.getCar(i)
        if c ~= nil and c.sessionID == sessionId then
            return c
        end
    end
    return nil
end

-- Path of the skin preview of the car with the given session ID, or nil when that car or
-- every preview of it is missing. A missing or unknown skin falls back to the first skin
-- with a preview. Results are cached per car and skin.
local carPreviewCache = {}
local function GetCarPreviewPath(sessionId)
    local c = FindCarBySessionId(sessionId)
    if c == nil then
        return nil
    end
    local carId, skinId = ac.getCarID(c.index), ac.getCarSkinID(c.index) or ""
    if carId == nil then
        return nil
    end
    local key = carId .. "/" .. skinId
    if carPreviewCache[key] == nil then
        local skinsDir = ac.getFolder(ac.FolderID.ContentCars) .. "/" .. carId .. "/skins/"
        local path = skinsDir .. skinId .. "/preview.jpg"
        if skinId == "" or not io.fileExists(path) then
            path = io.scanDir(skinsDir, "*", function (fileName)
                local candidate = skinsDir .. fileName .. "/preview.jpg"
                return io.fileExists(candidate) and candidate or nil
            end)
        end
        carPreviewCache[key] = path or false
    end
    return carPreviewCache[key] or nil
end

local function checkTimeout(activatedAt, duration)
    if activatedAt ~= nil and os.clock() - activatedAt >= duration then
        return true
    end
    return false
end

-- Plays the sound in the named slot of soundSlots at the player's master volume,
-- restarting it if it is still playing. Does nothing while sound is off, until the slot's
-- file has loaded, or when it has none.
local function PlaySound(name)
    local path = soundPaths[name]
    if path == nil or not settings.soundEnabled or settings.soundVolume <= 0 then
        return
    end

    if soundEvents[name] ~= nil then
        pcall(soundEvents[name].dispose, soundEvents[name])
        soundEvents[name] = nil
    end

    local ok, event = pcall(ac.AudioEvent.fromFile, { filename = path, use3D = false, loop = false }, false)
    if ok and event ~= nil then
        soundEvents[name] = event
        event.volume = event.volume * soundSlots[name].volume * settings.soundVolume
        event:start()
    end
end

-- ==== 06_shell.lua ====
-- Drawing helpers for the Initial D shells. Positions and sizes are in the shells' native
-- pixels; ShellScale converts them to screen units so the shells are drawn 1:1 at 1080p.

-- Opacity of everything drawn by the helpers while an element fades in or out, set by
-- DrawFaded (07_tween.lua). Faded applies it to a colour; nil means white.
local fadeAlpha = 1

local function Faded(color)
    color = color or rgbm(1, 1, 1, 1)
    if fadeAlpha >= 1 then
        return color
    end
    return rgbm(color.r, color.g, color.b, color.mult * fadeAlpha)
end

local function ShellScale()
    return scaling.get() * layout.shellScale
end

-- Draws an image with its top-left corner at shell position pos (window units).
local function DrawShellSprite(image, pos, size, color, uvMax)
    local s = ShellScale()
    local p1 = pos * s
    ui.drawImage(image, p1, p1 + size * s, Faded(color), vec2(0, 0), uvMax or vec2(1, 1))
end

-- Draws text in a shell rectangle, centered unless alignment is given, shrunk to fit its
-- width but not below minFontSize. Text that still does not fit is left-aligned and cut off
-- at the rectangle.
local function DrawShellText(text, textFont, fontSize, minFontSize, rectMin, rectMax, color, alignment)
    local width = rectMax.x - rectMin.x
    local fitted = FindFontSize(text, fontSize * layout.shellScale, textFont, width * layout.shellScale)
    fitted = math.max(fitted, minFontSize * layout.shellScale)
    local s = ShellScale()

    ui.pushDWriteFont(textFont)
    local overflows = ui.measureDWriteText(text, scaling.size(fitted)).x > width * s
    local horizontal = overflows and ui.Alignment.Start or (alignment or ui.Alignment.Center)
    ui.dwriteDrawTextClipped(text, scaling.size(fitted), rectMin * s, rectMax * s,
        horizontal, ui.Alignment.Center, false, Faded(color))
    ui.popDWriteFont()
end

-- ==== 07_tween.lua ====
-- Small tween helper for fades and slide-ins. Each named tween runs from 0 (hidden) to 1
-- (shown) and back, so an element can keep drawing while it fades out.

local tweenValues = {}
local lastTweenDelta = 0 -- the frame time of the last update, shown by the mock panel

local function EaseOutCubic(t)
    return 1 - (1 - t) ^ 3
end

-- Moves the named tween towards 1 while shown and towards 0 while hidden, taking duration
-- seconds either way, and returns its eased value.
local function Tween(name, shown, duration)
    local value = tweenValues[name] or 0
    lastTweenDelta = ui.deltaTime()
    local step = lastTweenDelta / duration
    value = shown and math.min(1, value + step) or math.max(0, value - step)
    tweenValues[name] = value
    return EaseOutCubic(value)
end

-- Restarts the named tween from 0, for elements that animate in again when their content
-- changes.
local function RestartTween(name)
    tweenValues[name] = 0
end

-- Calls draw with every colour drawn through the helpers at the given opacity (0 to 1).
local function DrawFaded(alpha, draw)
    fadeAlpha = math.max(0, math.min(1, alpha))
    draw()
    fadeAlpha = 1
end

-- ==== 10_events.lua ====
-- Server messages. Each event has a named handler so the mock panel can drive the HUD
-- through the same code as the real event.

local function OnSessionState(message)
    ac.debug('AS_SessionState.sessionState', message.sessionState)
    ac.debug('AS_SessionState.result1', message.result1)
    ac.debug('AS_SessionState.result2', message.result2)
    ac.debug('AS_SessionState.result3', message.result3)
    ac.debug('AS_SessionState.rivalSessionId', message.rivalSessionId)

    standings[1] = message.result1
    standings[2] = message.result2
    standings[3] = message.result3
    if message.sessionState ~= HudStates.NoUpdate then currentHudState = message.sessionState end

    if message.rivalSessionId >= 0 then
        rivalCar = FindCarBySessionId(message.rivalSessionId)
    else
        rivalCar = nil
    end
end

local function OnElo(message)
    showElo = true
    targetElo = message.elo
    if discreteMode then
        eloShownAt = os.clock()
    end
end

local function OnInvite(message)
    if message.inviteSenderName ~= "" and message.inviteRecipientGuid ~= 1 then
        hasActiveInvite = true
        inviteSenderName = message.inviteSenderName
        inviteSenderElo = message.inviteSenderElo
        inviteCourseName = message.courseName or ""
        inviteActivatedAt = os.clock()
        PlaySound("invite")
    end
end

local function OnNotification(message)
    ac.debug('AS_Notification.isCountdown', message.isCountdown)
    ac.debug('AS_Notification.message', message.message)

    if not message.isCountdown then
        notificationMessage = message.message
        hasIncomingNotification = true
        notificationActivatedAt = os.clock()
        PlaySound("notify")
    else
        if message.message == "Ready..." then
            PlaySound("countdown")
        end
        countdownHudMessage = message.message
        isCountdownHudActive = true
        countdownActivatedAt = os.clock()
    end
end

local function OnInitialization(message)
    ac.debug('AS_Initialization.discreteMode', message.discreteMode)
    ac.debug('AS_Initialization.useTrackFinish', message.useTrackFinish)

    showRaceTypeToggle = message.showRaceTypeToggle

    -- Discrete mode hides the Elo card (it shows for a while after the Elo changes) and the
    -- menu hint. Set both either way, so leaving discrete mode brings them back.
    discreteMode = message.discreteMode
    showElo = not discreteMode
    hasTutorialHidden = discreteMode
    eloShownAt = nil

    elo = message.elo - 100
    targetElo = message.elo

    racesCompleted = message.racesCompleted
    if message.racesCompleted >= 3 then
        isTutorialAutoHidden = true
    end

    courseNames = {}
    for courseName in string.gmatch(message.courseNames, "([^`]+)") do
        table.insert(courseNames, courseName)
    end
end

local function OnLobbyStatus(message)
    -- The packet carries five flattened player slots.
    for i = 1, 5 do
        nearbyPlayers[i] = {
            name = message['nearbyName' .. i],
            id = message['nearbyId' .. i],
            inRace = message['nearbyInRace' .. i],
            elo = message['nearbyElo' .. i],
            sessionId = message['nearbySessionId' .. i],
        }
        -- Looked up once here rather than every frame the menu draws.
        local c = FindCarBySessionId(nearbyPlayers[i].sessionId)
        nearbyPlayers[i].carName = c ~= nil and ac.getCarName(c.index) or nil
        nearbyPlayers[i].carPreview = GetCarPreviewPath(nearbyPlayers[i].sessionId)
    end
end

local sessionStateEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_SessionState'),
        result1 = ac.StructItem.int32(),
        result2 = ac.StructItem.int32(),
        result3 = ac.StructItem.int32(),
        sessionState = ac.StructItem.int32(),
        rivalSessionId = ac.StructItem.int32(),
    }, function (sender, message) OnSessionState(message) end)

local eloEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Elo'),
        elo = ac.StructItem.int32()
    }, function (sender, message) OnElo(message) end)

-- Also sent by the client, with magic values in inviteSenderName and inviteRecipientGuid:
-- "nearby"/1 invites the nearest car, "a"/1 accepts the pending invite, and ""/<guid>
-- invites that player.
local inviteEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Invite'),
        inviteSenderName = ac.StructItem.string(),
        inviteRecipientGuid = ac.StructItem.uint64(),
        inviteSenderElo = ac.StructItem.int32(),
        inviteSenderId = ac.StructItem.string(),
        courseName = ac.StructItem.string(),
        isCourse = ac.StructItem.boolean(),
    }, function (sender, message) OnInvite(message) end)

local notificationEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Notification'),
        message = ac.StructItem.string(64),
        isCountdown = ac.StructItem.boolean(),
    }, function (sender, message) OnNotification(message) end)

-- Client to server only.
local forfeitEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Forfeit'),
        forfeit = ac.StructItem.boolean()
    }, function (sender, message) end)

local initializationEvent = ac.OnlineEvent(
    {
        ac.StructItem.key('AS_Initialization'),
        elo = ac.StructItem.int32(),
        racesCompleted = ac.StructItem.int32(),
        useTrackFinish = ac.StructItem.boolean(),
        discreteMode = ac.StructItem.boolean(),
        loadSteamAvatars = ac.StructItem.boolean(),
        courseNames = ac.StructItem.string(1024),
        showRaceTypeToggle = ac.StructItem.boolean(),
    }, function (sender, message) OnInitialization(message) end)

local lobbyStatusEvent = ac.OnlineEvent({
    ac.StructItem.key('AS_LobbyStatus'),
    nearbyName1 = ac.StructItem.string(),
    nearbyId1 = ac.StructItem.uint64(),
    nearbyInRace1 = ac.StructItem.boolean(),
    nearbyElo1 = ac.StructItem.int32(),
    nearbySessionId1 = ac.StructItem.int32(),
    nearbyName2 = ac.StructItem.string(),
    nearbyId2 = ac.StructItem.uint64(),
    nearbyInRace2 = ac.StructItem.boolean(),
    nearbyElo2 = ac.StructItem.int32(),
    nearbySessionId2 = ac.StructItem.int32(),
    nearbyName3 = ac.StructItem.string(),
    nearbyId3 = ac.StructItem.uint64(),
    nearbyInRace3 = ac.StructItem.boolean(),
    nearbyElo3 = ac.StructItem.int32(),
    nearbySessionId3 = ac.StructItem.int32(),
    nearbyName4 = ac.StructItem.string(),
    nearbyId4 = ac.StructItem.uint64(),
    nearbyInRace4 = ac.StructItem.boolean(),
    nearbyElo4 = ac.StructItem.int32(),
    nearbySessionId4 = ac.StructItem.int32(),
    nearbyName5 = ac.StructItem.string(),
    nearbyId5 = ac.StructItem.uint64(),
    nearbyInRace5 = ac.StructItem.boolean(),
    nearbyElo5 = ac.StructItem.int32(),
    nearbySessionId5 = ac.StructItem.int32(),
}, function (sender, message) OnLobbyStatus(message) end)

-- Sends a client message, unless the mock panel is driving the HUD.
local function SendToServer(event, payload)
    if mockActive then
        ac.log('Touge mock: message not sent to the server')
        return
    end
    event(payload)
end

-- Ask the server for the initial state.
initializationEvent({elo = elo, racesCompleted = racesCompleted})

-- ==== 15_race.lua ====
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

-- ==== 21_challenge.lua ====
-- Challenge actions shared by the menu, the popups and the keyboard.

-- Number of filled nearby player slots; empty slots have an empty name.
local function CountNearbyPlayers()
    local playerCount = 0
    while playerCount < 5 and nearbyPlayers[playerCount + 1] and nearbyPlayers[playerCount + 1].name ~= "" do
        playerCount = playerCount + 1
    end
    return playerCount
end

-- Sends the challenge picked in the menu. The course is only named when there is more
-- than one.
local function SendChallenge(player)
    local payload = {inviteSenderName = "", inviteRecipientGuid = player.id, isCourse = isToggleCourse}
    if #courseNames > 1 then
        payload.courseName = courseNames[selectedCourseIndex]
    end
    SendToServer(inviteEvent, payload)
    PlaySound("send")
    hasInviteMenuOpen = false
end

local function AcceptInvite()
    SendToServer(inviteEvent, {inviteSenderName = "a", inviteRecipientGuid = 1})
    PlaySound("accept")
    hasActiveInvite = false
end

-- ==== 23_draw_cluster.lua ====
-- Initial D in-race cluster: advantage number, Driver vs Rival names and the round results.
-- Coordinates are shell pixels (see layout.cluster and 06_shell.lua).

local function AdvantageColor(gapSeconds)
    if gapSeconds >= 0 then
        return rgbm(1, 1, 1, 1)
    end
    -- Fades from white to red as the gap grows, fully red at redAt.
    local t = math.min(gapSeconds / layout.cluster.advantage.redAt, 1)
    return rgbm(1, 1 - t, 1 - t, 1)
end

local function DrawAdvantage()
    local a = layout.cluster.advantage
    DrawShellSprite(a.image, a.pos, a.size)

    local gap = race.gapSeconds
    local pointSlot = a.pos + a.point
    local function IntegerSlot(indexFromRight)
        return a.pos + vec2(a.integerRight - indexFromRight * a.integerSize.x, a.integerY)
    end
    local function DecimalSlot(index)
        return a.pos + vec2(a.decimalX + (index - 1) * a.decimalSize.x, a.decimalY)
    end

    if gap == nil then
        -- Unknown gap: "--.--"
        for i = 1, 2 do
            DrawShellSprite(idSprites.minus, IntegerSlot(i), a.integerSize, a.unknownColor)
            DrawShellSprite(idSprites.minus, DecimalSlot(i), a.decimalSize, a.unknownColor)
        end
        DrawShellSprite(idSprites.pointM, pointSlot, a.pointSize, a.unknownColor, a.pointUvMax)
        return
    end

    local color = AdvantageColor(gap)
    local text = string.format("%.2f", math.min(math.abs(gap), 99.99))
    local whole, decimals = text:match("^(%d+)%.(%d%d)$")

    for i = 1, #whole do
        local digit = tonumber(whole:sub(-i, -i))
        DrawShellSprite(idSprites.digits[digit], IntegerSlot(i), a.integerSize, color)
    end
    DrawShellSprite(gap >= 0 and idSprites.plus or idSprites.minus, IntegerSlot(#whole + 1), a.integerSize, color)

    DrawShellSprite(idSprites.pointM, pointSlot, a.pointSize, color, a.pointUvMax)
    for i = 1, 2 do
        DrawShellSprite(idSprites.digits[tonumber(decimals:sub(i, i))], DecimalSlot(i), a.decimalSize, color)
    end
end

local function DrawNameRow(rowOffset, name, carName, position, carColor)
    local n = layout.cluster.names
    local origin = n.pos + vec2(0, rowOffset)

    if name ~= "" then
        DrawShellText(name, fontSemiBold, n.nameFontSize, n.nameMinFontSize, origin + n.nameMin, origin + n.nameMax, rgbm(1, 1, 1, 1))
    end
    if carName ~= "" then
        DrawShellText(carName, font, n.carFontSize, n.carMinFontSize, origin + n.carMin, origin + n.carMax, carColor)
    end

    local digit = position and idSprites.positionDigits[position] or idSprites.positionDash
    DrawShellSprite(digit, origin + n.position, n.positionSize)
end

local function DrawNames()
    local n = layout.cluster.names
    DrawShellSprite(n.image, n.pos, n.size)

    local rivalPosition = race.position and (3 - race.position) or nil
    DrawNameRow(0, race.driverName, race.driverCarName, race.position, n.driverCarColor)
    DrawNameRow(n.rivalOffset, race.rivalName, race.rivalCarName, rivalPosition, n.rivalCarColor)
end

local function DrawRounds()
    local r = layout.cluster.rounds
    local s = ShellScale()

    local label = "ROUNDS"
    local labelColor = r.labelColor
    if currentHudState == HudStates.SuddenDeath then
        label = "SUDDEN DEATH"
    elseif currentHudState == HudStates.Finished then
        -- This needs revisiting for different rulesets, as in the old standings panel.
        local won = standings[3] == RaceResults.Win
        label = won and "YOU WIN" or "YOU LOSE"
        labelColor = won and r.win or r.loss
    end
    ui.pushDWriteFont(fontSemiBold)
    ui.dwriteDrawText(label, scaling.size(r.labelFontSize * layout.shellScale), r.label * s, labelColor)
    ui.popDWriteFont()

    local pips = currentHudState == HudStates.FirstTwo and 2 or 3
    for i = 1, pips do
        local x = r.pipsRight - (pips - i + 1) * r.pipSize.x - (pips - i) * r.pipSpacing
        local pipMin = vec2(x, r.y) * s
        local pipMax = pipMin + r.pipSize * s
        local rounding = r.pipSize.y * s / 2

        local result = standings[i]
        local fill = r.pending
        if result == RaceResults.Win then
            fill = r.win
        elseif result == RaceResults.Loss then
            fill = r.loss
        elseif result == RaceResults.Tie then
            fill = r.tie
        end
        ui.drawRectFilled(pipMin, pipMax, fill, rounding)
        ui.drawRect(pipMin, pipMax, r.border, rounding)
    end
end

local function DrawCluster()
    if currentHudState == HudStates.Off or idSprites == nil then
        return
    end

    local c = layout.cluster
    local size = c.size * ShellScale()
    local pos = vec2(windowWidth - scaling.size(c.marginRight) - size.x, scaling.size(c.marginTop))
    ui.transparentWindow("idClusterWindow", pos, size, function ()
        DrawAdvantage()
        DrawNames()
        DrawRounds()
    end)
end

-- ==== 24_draw_panel.lua ====
-- The Touge menu, in the style of the Initial D Arcade Stage 6 menus (see layout.as6Panel):
-- one centered window with CHALLENGE, PROFILE and HOW TO PLAY tabs, a banner for a pending
-- challenge, a small menu hint and the Elo card. Coordinates are shell pixels relative to
-- the window.

local radii = layout.as6Panel.radius

local function Fill(min, max, color, rounding, corners)
    local s = ShellScale()
    ui.drawRectFilled(min * s, max * s, Faded(color), (rounding or 0) * s, corners or ui.CornerFlags.All)
end

local function Outline(min, max, color, rounding, thickness)
    local s = ShellScale()
    ui.drawRect(min * s, max * s, Faded(color), (rounding or 0) * s, ui.CornerFlags.All, (thickness or 1) * s)
end

-- Gradient fill with rounded corners: a rounded base in the bottom colour, a rounded cap in
-- the top colour, and the gradient between the two. topOnly rounds just the top corners.
local function VerticalGradient(min, max, top, bottom, rounding, topOnly)
    local s = ShellScale()
    local r = math.min(rounding or 0, (max.y - min.y) / 2)
    if r <= 0 then
        ui.drawRectFilledMultiColor(min * s, max * s, Faded(top), Faded(top), Faded(bottom), Faded(bottom))
        return
    end
    Fill(min, max, bottom, r, topOnly and ui.CornerFlags.Top or ui.CornerFlags.All)
    Fill(min, vec2(max.x, min.y + 2 * r), top, r, ui.CornerFlags.Top)
    local gradientMax = topOnly and max or vec2(max.x, max.y - r)
    ui.drawRectFilledMultiColor(vec2(min.x, min.y + r) * s, gradientMax * s, Faded(top), Faded(top), Faded(bottom), Faded(bottom))
end

-- Text centered in a shape, kept inset from its sides.
local function InsetText(text, textFont, fontSize, minFontSize, min, max, color, inset)
    local pad = vec2(inset or layout.as6Panel.textInset, 0)
    DrawShellText(text, textFont, fontSize, minFontSize, min + pad, max - pad, color)
end

-- Wrapped, top-left aligned text in a shell rectangle.
local function DrawParagraph(text, textFont, fontSize, min, max, color)
    local s = ShellScale()
    ui.pushDWriteFont(textFont)
    ui.dwriteDrawTextClipped(text, scaling.size(fontSize * layout.shellScale), min * s, max * s,
        ui.Alignment.Start, ui.Alignment.Start, true, Faded(color))
    ui.popDWriteFont()
end

-- True while the mouse is over the shell rectangle; also shows the hand cursor.
local function Hovered(mousePos, min, max)
    local s = ShellScale()
    if IsInRect(mousePos, min * s, max * s) then
        ui.setMouseCursor(ui.MouseCursor.Hand)
        return true
    end
    return false
end

local function Clicked(mousePos, min, max)
    local s = ShellScale()
    return ConsumeClickIn(mousePos, min * s, max * s)
end

-- Frosted backdrop over the whole window at windowPos (screen units). The scene texture
-- needs CSP's Graphics Adjustment; without it only the light layer shows.
local function DrawAs6Backdrop(windowPos, size)
    local b = layout.as6Panel.backdrop
    local s = ShellScale()
    if ui.isImageReady('dynamic::screen') then
        local screen = vec2(sim.windowWidth, sim.windowHeight)
        ui.beginBlurring()
        ui.drawImage('dynamic::screen', vec2(0, 0), size, Faded(), windowPos / screen, (windowPos + size) / screen)
        ui.endBlurring(b.blur * s)
    end
    ui.drawRectFilled(vec2(0, 0), size, Faded(b.tint), radii.window * s)
    ui.drawRect(vec2(0, 0), size, Faded(b.border), radii.window * s)
end

-- Gold gradient button; returns true when clicked.
local function DrawGoldButton(min, max, text, fontSize, enabled, mousePos)
    local b = layout.as6Panel.menu.send
    if not enabled then
        Fill(min, max, b.disabled, radii.card)
        InsetText(text, fontBold, fontSize, fontSize * 0.8, min, max, b.disabledText)
        return false
    end
    local hovered = Hovered(mousePos, min, max)
    VerticalGradient(min, max, hovered and b.hoverTopColor or b.topColor, b.bottomColor, radii.card)
    Outline(min, max, layout.as6Panel.card.hover, radii.card, 2)
    InsetText(text, fontBold, fontSize, fontSize * 0.8, min, max, b.text)
    return Clicked(mousePos, min, max)
end

-- Pill used for tabs and the race type choice; returns true when an unselected pill is clicked.
local function DrawPill(min, max, text, fontSize, selected, mousePos)
    local t = layout.as6Panel.toggle
    local radius = (max.y - min.y) / 2
    Fill(min, max, selected and t.selectedFill or t.idleFill, radius)
    if selected then
        Outline(min, max, layout.as6Panel.card.hover, radius, 2)
    end
    InsetText(text, fontSemiBold, fontSize, fontSize * 0.8, min, max, selected and t.selectedText or t.idleText, radius)
    local clicked = not selected and Hovered(mousePos, min, max) and Clicked(mousePos, min, max)
    if clicked then
        PlaySound("pick")
    end
    return clicked
end

-- Draws a card of the given width with its top-left at pos. content fields: boxText, chips
-- (list of { text, fill }), caption, name, detail, busy, image (car preview path or nil).
-- Selected cards keep the gold frame; others get a thin one under the mouse. Returns true
-- when the card was clicked this frame (never when mousePos is nil).
local function DrawAs6Card(pos, width, mousePos, content, selected)
    local c = layout.as6Panel.card
    local cardMax = pos + vec2(width, c.size.y)

    Fill(pos, cardMax, c.fill, radii.card)
    Outline(pos, cardMax, c.border, radii.card)

    -- Left: headline box and chips
    Fill(pos + c.boxMin, pos + c.boxMax, c.boxFill, radii.inner)
    Outline(pos + c.boxMin, pos + c.boxMax, c.boxBorder, radii.inner)
    InsetText(content.boxText, fontBold, c.boxFontSize, c.boxFontSize * 0.7,
        pos + c.boxMin, pos + c.boxMax, content.busy and c.busyColor or c.boxColor)

    for i, chip in ipairs(content.chips) do
        local chipMin = pos + vec2(c.boxMin.x + (i - 1) * (c.chipWidth + c.chipGap), c.chipY)
        local chipMax = chipMin + vec2(c.chipWidth, c.chipHeight)
        Fill(chipMin, chipMax, chip.fill or c.chipFill, radii.chip)
        InsetText(chip.text, fontSemiBold, c.chipFontSize, c.chipFontSize * 0.7, chipMin, chipMax, c.chipText,
            layout.as6Panel.chipTextInset)
    end

    -- Right: silver info area with caption, name and detail
    local infoMax = pos + vec2(width - c.rightInset, c.infoMax.y)
    VerticalGradient(pos + c.infoMin, infoMax, c.infoTop, c.infoBottom, radii.inner)
    Outline(pos + c.infoMin, infoMax, c.border, radii.inner)

    local textLeft = c.textLeft
    if content.image ~= nil then
        local sc = ShellScale()
        local imageMin = pos + c.image
        local imageMax = imageMin + c.imageSize
        ui.drawImageRounded(content.image, imageMin * sc, imageMax * sc, Faded(rgbm(1, 1, 1, content.busy and 0.5 or 1)),
            c.imageUvMin, c.imageUvMax, radii.chip * sc)
        Outline(imageMin, imageMax, c.imageBorder, radii.chip)
        textLeft = textLeft + c.imageShift
    end
    local function Line(span)
        return pos + vec2(textLeft, span.x), pos + vec2(width - c.textRightInset, span.y)
    end
    local captionMin, captionMax = Line(c.captionY)
    DrawShellText(content.caption, fontSemiBold, c.captionFontSize, c.captionFontSize, captionMin, captionMax, c.mutedColor, ui.Alignment.Start)
    local nameMin, nameMax = Line(c.nameY)
    DrawShellText(content.name, fontBold, c.nameFontSize, c.nameMinFontSize, nameMin, nameMax,
        content.busy and c.busyColor or c.textColor, ui.Alignment.Start)
    local detailMin, detailMax = Line(c.detailY)
    DrawShellText(content.detail, font, c.detailFontSize, c.detailFontSize, detailMin, detailMax, c.mutedColor, ui.Alignment.Start)

    local hovered = mousePos ~= nil and Hovered(mousePos, pos, cardMax)
    if selected then
        Outline(pos, cardMax, c.hoverGlow, radii.card + 3, c.hoverGlowThickness)
        Outline(pos, cardMax, c.hover, radii.card, c.hoverThickness)
    elseif hovered then
        Outline(pos, cardMax, c.hover, radii.card, 1.5)
    end
    return hovered and Clicked(mousePos, pos, cardMax)
end

local function DrawCaption(text, x, y, width)
    local m = layout.as6Panel.menu
    DrawShellText(text, fontSemiBold, m.captionFontSize, m.captionFontSize, vec2(x + 4, y), vec2(x + width, y + m.captionHeight),
        m.captionColor, ui.Alignment.Start)
end

local function FindNearbyPlayer(playerId)
    for index = 1, CountNearbyPlayers() do
        if nearbyPlayers[index].id == playerId then
            return nearbyPlayers[index]
        end
    end
    return nil
end

local tabs = {
    { id = "challenge", text = "CHALLENGE" },
    { id = "profile", text = "PROFILE" },
    { id = "settings", text = "SETTINGS" },
    { id = "howto", text = "HOW TO PLAY" },
}

local function DrawMenuHeader(subtitle, mousePos)
    local p = layout.as6Panel
    local m = p.menu
    local t = p.title
    VerticalGradient(vec2(0, 0), vec2(m.width, t.height), t.top, t.bottom, radii.window, true)
    Fill(vec2(radii.window, 0), vec2(m.width - radii.window, 2), t.highlight)
    DrawShellText("TOUGE", fontBold, t.fontSize, t.fontSize, m.titleText, vec2(400, t.height), t.color, ui.Alignment.Start)

    local tb = m.tabs
    for i, tab in ipairs(tabs) do
        local fromRight = #tabs - i + 1
        local min = vec2(tb.right - fromRight * tb.size.x - (fromRight - 1) * tb.gap, tb.y)
        if DrawPill(min, min + tb.size, tab.text, tb.fontSize, menuTab == tab.id, mousePos) then
            menuTab = tab.id
        end
    end

    local st = p.subtitle
    local radius = (m.subtitleMax.y - m.subtitleMin.y) / 2
    Fill(m.subtitleMin, m.subtitleMax, st.fill, radius)
    Outline(m.subtitleMin, m.subtitleMax, st.border, radius)
    InsetText(subtitle, font, st.fontSize, st.fontSize * 0.8, m.subtitleMin, m.subtitleMax, st.color, radius)
end

-- Pending challenge with an accept button, the same as pressing M.
local function DrawInviteBanner(mousePos)
    local m = layout.as6Panel.menu
    local b = m.banner
    local c = layout.as6Panel.card
    local min = vec2(b.margin, b.y)
    local max = vec2(m.width - b.margin, b.y + b.height)
    Fill(min, max, c.fill, radii.card)
    Outline(min, max, c.hover, radii.card, 2)

    local text = inviteSenderName .. " (" .. inviteSenderElo .. ") challenged you"
    if inviteCourseName ~= "" then
        text = text .. "  ·  " .. inviteCourseName
    end
    local buttonMax = vec2(max.x - 10, max.y - (b.height - b.buttonSize.y) / 2)
    local buttonMin = buttonMax - b.buttonSize
    DrawShellText(text, fontBold, b.fontSize, b.fontSize * 0.8, min + vec2(16, 0), vec2(buttonMin.x - 12, max.y), c.textColor, ui.Alignment.Start)
    if DrawGoldButton(buttonMin, buttonMax, "ACCEPT  (M)", 15, true, mousePos) then
        AcceptInvite()
    end
end

local function DrawChallengeTab(top, height, mousePos)
    local m = layout.as6Panel.menu
    local card = layout.as6Panel.card

    -- Left column: drivers
    local playerCount = CountNearbyPlayers()
    DrawCaption(playerCount > 0 and ("DRIVERS  ·  " .. playerCount .. " nearby") or "DRIVERS", m.leftX, top, m.leftWidth)
    local listTop = top + m.captionHeight
    if nearbyPlayers[1] == nil or playerCount == 0 then
        local text = nearbyPlayers[1] == nil and "Looking for drivers..." or "No other players online"
        DrawShellText(text, font, 18, 18, vec2(m.leftX, listTop), vec2(m.leftX + m.leftWidth, listTop + card.size.y), card.mutedColor)
    end
    for index = 1, playerCount do
        local player = nearbyPlayers[index]
        local pos = vec2(m.leftX, listTop + (index - 1) * card.step)
        local status = player.inRace and { text = "IN RACE", fill = card.inRaceFill } or { text = "READY", fill = card.readyFill }
        local clicked = DrawAs6Card(pos, m.leftWidth, mousePos, {
            boxText = tostring(player.elo),
            chips = {
                { text = "ELO", fill = GetEloColor(player.elo) },
                status,
            },
            caption = player.carName or "DRIVER",
            name = player.name,
            detail = player.inRace and "Currently in a race" or "Click to select",
            busy = player.inRace,
            image = player.carPreview,
        }, player.id == selectedPlayerId)
        if clicked and player.id ~= selectedPlayerId then
            PlaySound("pick")
            selectedPlayerId = player.id
        end
    end

    -- Right column: race type, course, summary and send
    local x, width = m.rightX, m.rightWidth
    local y = top
    if showRaceTypeToggle then
        DrawCaption("RACE TYPE", x, y, width)
        local t = layout.as6Panel.toggle
        local left = x + (width - 2 * t.size.x - t.gap) / 2
        local pillsTop = y + m.captionHeight
        if DrawPill(vec2(left, pillsTop), vec2(left, pillsTop) + t.size, "COURSE", t.fontSize, isToggleCourse, mousePos) then
            isToggleCourse = true
        end
        local outrunMin = vec2(left + t.size.x + t.gap, pillsTop)
        if DrawPill(outrunMin, outrunMin + t.size, "OUTRUN", t.fontSize, not isToggleCourse, mousePos) then
            isToggleCourse = false
        end
        y = pillsTop + t.size.y + 14
    end

    local cc = m.courseCard
    DrawCaption("COURSE", x, y, width)
    local coursesTop = y + m.captionHeight
    local visible = math.min(#courseNames, cc.maxVisible)
    local maxScroll = #courseNames - visible
    selectedCourseIndex = math.max(1, math.min(selectedCourseIndex, #courseNames))
    if maxScroll > 0 and ui.mouseWheel ~= nil
        and IsInRect(mousePos, vec2(x, coursesTop) * ShellScale(), vec2(x + width, coursesTop + visible * cc.step) * ShellScale()) then
        courseScroll = math.max(0, math.min(maxScroll, courseScroll - ui.mouseWheel()))
    end
    courseScroll = math.max(0, math.min(courseScroll, maxScroll))

    for row = 1, visible do
        local index = row + courseScroll
        local min = vec2(x, coursesTop + (row - 1) * cc.step)
        local max = min + vec2(width, cc.height)
        local selected = index == selectedCourseIndex
        Fill(min, max, card.fill, radii.card)
        Outline(min, max, selected and card.hover or card.border, radii.card, selected and card.hoverThickness or 1)
        local chipMin = min + vec2(10, (cc.height - card.chipHeight) / 2)
        local chipMax = chipMin + vec2(cc.chipWidth, card.chipHeight)
        Fill(chipMin, chipMax, card.chipFill, radii.chip)
        InsetText("No. " .. index, fontSemiBold, card.chipFontSize, card.chipFontSize * 0.7, chipMin, chipMax, card.chipText,
            layout.as6Panel.chipTextInset)
        DrawShellText(courseNames[index], fontBold, cc.fontSize, cc.minFontSize, vec2(chipMax.x + 12, min.y), max - vec2(16, 0),
            card.textColor, ui.Alignment.Start)
        if not selected and Hovered(mousePos, min, max) then
            Outline(min, max, card.hover, radii.card, 1.5)
            if Clicked(mousePos, min, max) then
                PlaySound("pick")
                selectedCourseIndex = index
            end
        end
    end
    if maxScroll > 0 then
        local hintTop = coursesTop + visible * cc.step
        DrawShellText("Scroll for more courses", font, 13, 13, vec2(x, hintTop), vec2(x + width, hintTop + 18), card.mutedColor)
    end

    local s = m.send
    local sendMax = vec2(x + (width + s.size.x) / 2, height - m.padding)
    local sendMin = sendMax - s.size
    local player = FindNearbyPlayer(selectedPlayerId)
    local summary = "Select a driver to challenge"
    if player ~= nil then
        summary = player.name
        if #courseNames > 0 then
            summary = summary .. "  ·  " .. courseNames[selectedCourseIndex]
        end
        summary = summary .. "  ·  " .. (isToggleCourse and "Course race" or "Outrun race")
    end
    DrawShellText(summary, fontSemiBold, m.summaryFontSize, m.summaryFontSize * 0.8,
        vec2(x, sendMin.y - 32), vec2(x + width, sendMin.y - 6), card.textColor)
    local canSend = player ~= nil and not player.inRace
    if DrawGoldButton(sendMin, sendMax, "SEND CHALLENGE", s.fontSize, canSend, mousePos) then
        SendChallenge(player)
    end
end

-- A card row with a label on the left, used by the PROFILE and SETTINGS tabs. Rows are
-- centered and stacked from top. Returns the row's corners.
local function DrawLabelRow(index, top, label)
    local m = layout.as6Panel.menu
    local st = m.settings
    local card = layout.as6Panel.card
    local left = (m.width - st.rowWidth) / 2
    local min = vec2(left, top + (index - 1) * st.rowStep)
    local max = min + vec2(st.rowWidth, st.rowHeight)
    Fill(min, max, card.fill, radii.card)
    Outline(min, max, card.border, radii.card)
    DrawShellText(label, fontSemiBold, st.labelFontSize, st.labelFontSize, min + vec2(st.labelX, 0),
        vec2(min.x + st.controlX, max.y), card.mutedColor, ui.Alignment.Start)
    return min, max
end

local function DrawProfileTab(top)
    local m = layout.as6Panel.menu
    local pr = m.profile
    local card = layout.as6Panel.card
    local left = (m.width - pr.cardWidth) / 2
    local displayElo = math.floor(math.max(elo, 0) + 0.5)

    DrawAs6Card(vec2(left, top), pr.cardWidth, nil, {
        boxText = tostring(displayElo),
        chips = { { text = "ELO", fill = GetEloColor(displayElo) } },
        caption = ac.getCarName(0) or "DRIVER",
        name = ac.getDriverName(0),
        detail = "Your touge profile",
        image = car ~= nil and GetCarPreviewPath(car.sessionID) or nil,
    }, false)

    local stats = {
        { "Elo rating", tostring(displayElo) },
        { "Races completed", tostring(racesCompleted) },
    }
    local st = m.settings
    for i, stat in ipairs(stats) do
        local min, max = DrawLabelRow(i, top + card.size.y + pr.gap, stat[1])
        DrawShellText(stat[2], fontBold, st.labelFontSize, st.labelFontSize, min, max - vec2(st.labelX, 0), card.textColor, ui.Alignment.End)
    end
end

local function DrawSettingsTab(top, mousePos)
    local m = layout.as6Panel.menu
    local st = m.settings
    local card = layout.as6Panel.card
    local s = ShellScale()

    -- Sound on / off
    local min, max = DrawLabelRow(1, top, "Sound")
    local pillMin = vec2(min.x + st.controlX, min.y + (st.rowHeight - st.pillSize.y) / 2)
    if DrawPill(pillMin, pillMin + st.pillSize, "ON", layout.as6Panel.toggle.fontSize, settings.soundEnabled, mousePos) then
        settings.soundEnabled = true
        PlaySound("pick")
    end
    local offMin = pillMin + vec2(st.pillSize.x + st.pillGap, 0)
    if DrawPill(offMin, offMin + st.pillSize, "OFF", layout.as6Panel.toggle.fontSize, not settings.soundEnabled, mousePos) then
        settings.soundEnabled = false
    end

    -- Volume slider: drag along the track or use the mouse wheel over the row. A preview
    -- plays when the drag ends.
    min, max = DrawLabelRow(2, top, "Volume")
    local trackMin = vec2(min.x + st.controlX, min.y + (st.rowHeight - st.trackHeight) / 2)
    local trackMax = vec2(max.x - st.labelX - st.valueWidth, trackMin.y + st.trackHeight)
    local width = trackMax.x - trackMin.x
    local hitMin = vec2(trackMin.x - st.knobRadius, min.y)
    local hitMax = vec2(trackMax.x + st.knobRadius, max.y)

    if Hovered(mousePos, hitMin, hitMax) and Clicked(mousePos, hitMin, hitMax) then
        isDraggingVolume = true
    end
    if isDraggingVolume then
        if ui.mouseDown() and hasInviteMenuOpen then
            settings.soundVolume = math.max(0, math.min(1, (mousePos.x / s - trackMin.x) / width))
        else
            isDraggingVolume = false
            PlaySound("pick")
        end
    elseif IsInRect(mousePos, min * s, max * s) and ui.mouseWheel() ~= 0 then
        settings.soundVolume = math.max(0, math.min(1, settings.soundVolume + ui.mouseWheel() * st.wheelStep))
        PlaySound("pick")
    end

    local volume = settings.soundVolume
    local active = settings.soundEnabled
    local send = m.send
    Fill(trackMin, trackMax, card.boxFill, st.trackHeight / 2)
    if volume > 0 then
        local fillMax = vec2(trackMin.x + math.max(st.trackHeight, width * volume), trackMax.y)
        if active then
            VerticalGradient(trackMin, fillMax, send.topColor, send.bottomColor, st.trackHeight / 2)
        else
            Fill(trackMin, fillMax, card.busyColor, st.trackHeight / 2)
        end
    end
    local knob = vec2(trackMin.x + width * volume, (trackMin.y + trackMax.y) / 2) * s
    ui.drawCircleFilled(knob, st.knobRadius * s, Faded(active and card.textColor or card.busyColor), 24)
    ui.drawCircle(knob, st.knobRadius * s, Faded(card.hover), 24, (isDraggingVolume and 2 or 1) * s)

    DrawShellText(string.format("%d%%", math.floor(volume * 100 + 0.5)), fontBold, st.labelFontSize, st.labelFontSize,
        vec2(trackMax.x, min.y), max - vec2(st.labelX, 0), active and card.textColor or card.busyColor, ui.Alignment.End)
end

local howtoKeys = {
    { key = "I", text = "Open or close this menu" },
    { key = "N", text = "Challenge the nearest driver" },
    { key = "M", text = "Accept a challenge" },
    { key = "F", text = "Hold to forfeit a race" },
    { key = "H", text = "Hide the menu hint" },
}

local function DrawHowToTab(top)
    local m = layout.as6Panel.menu
    local h = m.howto
    local card = layout.as6Panel.card
    local left, right = m.padding, m.width - m.padding

    local body = "Choose a driver on the Challenge tab, pick a course and a race type, and send the challenge. "
        .. "When they accept, both cars are placed at the start and the countdown begins.\n\n"
        .. "Beat your opponent to gain Elo. How much you gain depends on both drivers' Elo and cars."
    local boxMin = vec2(left, top)
    local boxMax = vec2(right, top + h.bodyHeight)
    Fill(boxMin, boxMax, card.fill, radii.card)
    Outline(boxMin, boxMax, card.border, radii.card)
    local inset = vec2(h.bodyPadding, h.bodyPadding)
    DrawParagraph(body, font, h.bodyFontSize, boxMin + inset, boxMax - inset, card.textColor)

    local keysTop = boxMax.y + h.keysGap
    local columnWidth = (right - left) / h.keyColumns
    for i, binding in ipairs(howtoKeys) do
        local column = (i - 1) % h.keyColumns
        local row = math.floor((i - 1) / h.keyColumns)
        local keyMin = vec2(left + column * columnWidth, keysTop + row * h.keyRowStep)
        local keyMax = keyMin + h.keySize
        Fill(keyMin, keyMax, card.keyFill, radii.card)
        Outline(keyMin, keyMax, card.border, radii.card, 2)
        DrawShellText(binding.key, fontBold, h.keyFontSize, h.keyFontSize, keyMin, keyMax, card.textColor)
        DrawShellText(binding.text, fontSemiBold, h.keyLabelFontSize, h.keyLabelFontSize * 0.8,
            vec2(keyMax.x + 14, keyMin.y), vec2(keyMin.x + columnWidth - m.padding, keyMax.y), card.textColor, ui.Alignment.Start)
    end
end

-- Height of each tab's content, from the top of the content to its bottom edge.
local function ContentHeight(tab)
    local m = layout.as6Panel.menu
    local card = layout.as6Panel.card
    if tab == "profile" then
        local pr = m.profile
        local st = m.settings
        return card.size.y + pr.gap + 2 * st.rowStep - (st.rowStep - st.rowHeight)
    elseif tab == "settings" then
        local st = m.settings
        return 2 * st.rowStep - (st.rowStep - st.rowHeight)
    elseif tab == "howto" then
        local h = m.howto
        local rows = math.ceil(#howtoKeys / h.keyColumns)
        return h.bodyHeight + h.keysGap + rows * h.keyRowStep - (h.keyRowStep - h.keySize.y)
    end
    return m.captionHeight + m.driverRows * card.step - (card.step - card.size.y)
end

local subtitles = {
    challenge = "Choose a driver, a course and a race type  ·  I to close",
    profile = "Your rating and progress  ·  I to close",
    settings = "Sound and volume  ·  I to close",
    howto = "Rules and controls  ·  I to close",
}

local function DrawTougeMenu()
    local motion = layout.as6Panel.motion
    local shown = Tween("menu", hasInviteMenuOpen, motion.menu)
    if shown <= 0 then
        return
    end

    local m = layout.as6Panel.menu
    local s = ShellScale()
    local top = m.contentTop + (hasActiveInvite and m.bannerSpace or 0)
    local height = top + ContentHeight(menuTab) + m.padding
    local size = vec2(m.width, height) * s
    local pos = (vec2(windowWidth, windowHeight) - size) / 2 + vec2(0, (1 - shown) * motion.menuSlide * s)
    ui.transparentWindow("tougeMenuWindow", pos, size, function ()
        DrawFaded(shown, function ()
            DrawAs6Backdrop(pos, size)
            -- A closing menu no longer reacts to the mouse.
            local mousePos = hasInviteMenuOpen and ui.mouseLocalPos() or vec2(-1e6, -1e6)
            DrawMenuHeader(subtitles[menuTab] or subtitles.challenge, mousePos)

            if hasActiveInvite then
                DrawInviteBanner(mousePos)
            end

            if menuTab == "profile" then
                DrawProfileTab(top)
            elseif menuTab == "settings" then
                DrawSettingsTab(top, mousePos)
            elseif menuTab == "howto" then
                DrawHowToTab(top)
            else
                DrawChallengeTab(top, height, mousePos)
            end
        end)
    end)
end

-- Small pill reminding of the menu key, hidden with H and while driving once auto-hidden.
local function DrawMenuHint()
    local visible = not hasTutorialHidden and not hasInviteMenuOpen
        and not (isTutorialAutoHidden and not (car ~= nil and car.speedKmh < 10))
    local shown = Tween("hint", visible, layout.as6Panel.motion.fade)
    if shown <= 0 then
        return
    end

    local hint = layout.as6Panel.menu.hint
    local st = layout.as6Panel.subtitle
    local size = hint.size * ShellScale()
    local pos = vec2(scaling.size(hint.marginLeft), windowHeight - scaling.size(hint.marginBottom) - size.y)
    ui.transparentWindow("tougeMenuHint", pos, size, function ()
        DrawFaded(shown, function ()
            local radius = hint.size.y / 2
            Fill(vec2(0, 0), hint.size, st.fill, radius)
            Outline(vec2(0, 0), hint.size, st.border, radius)
            InsetText("I  Touge menu   ·   H  hide", fontSemiBold, hint.fontSize, hint.fontSize * 0.8, vec2(0, 0), hint.size, st.color, radius)
        end)
    end)
end

-- Compact Elo card, top-left, shown whenever the Elo is known (and, in discrete mode, for a
-- while after it changes).
local function DrawEloCardContent()
    local l = layout.eloCard
    local c = layout.as6Panel.card
    local displayElo = math.floor(math.max(elo, 0) + 0.5)
    VerticalGradient(vec2(0, 0), l.size, c.infoTop, c.infoBottom, radii.card)
    Outline(vec2(0, 0), l.size, c.border, radii.card)

    Fill(l.boxMin, l.boxMax, c.boxFill, radii.inner)
    Outline(l.boxMin, l.boxMax, c.boxBorder, radii.inner)
    InsetText(tostring(displayElo), fontBold, l.boxFontSize, l.boxFontSize * 0.7, l.boxMin, l.boxMax, c.boxColor)

    DrawShellText(ac.getDriverName(0), fontBold, l.nameFontSize, l.nameMinFontSize, l.nameMin, l.nameMax, c.textColor, ui.Alignment.Start)
    local chipMax = l.chipMin + l.chipSize
    Fill(l.chipMin, chipMax, GetEloColor(displayElo), radii.chip)
    InsetText("ELO", fontSemiBold, c.chipFontSize, c.chipFontSize, l.chipMin, chipMax, c.chipText, layout.as6Panel.chipTextInset)
end

local function DrawEloCard()
    local shown = Tween("elo", elo ~= -1 and showElo, layout.as6Panel.motion.fade)
    if shown <= 0 or elo == -1 then
        return
    end

    local size = layout.eloCard.size * ShellScale()
    ui.transparentWindow("eloWindow", scaling.size(layout.eloCard.pos), size, function ()
        DrawFaded(shown, DrawEloCardContent)
    end)
end

-- ==== 25_draw_popups.lua ====
-- Popups and the countdown in the dark menu style (see layout.as6Panel.menu.popup and
-- .countdown). Shares the drawing helpers of 24_draw_panel.lua.

local function DrawInviteCard()
    local c = layout.as6Panel.card
    local p = layout.as6Panel.menu.popup
    DrawAs6Card(vec2(0, 0), p.width, nil, {
        boxText = tostring(inviteSenderElo),
        chips = {
            { text = "ELO", fill = GetEloColor(inviteSenderElo) },
            { text = "INVITE", fill = c.readyFill },
        },
        caption = inviteCourseName ~= "" and inviteCourseName or "Touge challenge",
        name = inviteSenderName,
        detail = "Press M to accept",
    }, false)
    Outline(vec2(0, 0), vec2(p.width, c.size.y), c.hover, radii.card, 2)
end

-- Dark plate with a gold accent bar on the left, for the notification and forfeit popups.
local function DrawMessagePlate(height)
    local c = layout.as6Panel.card
    local p = layout.as6Panel.menu.popup
    Fill(vec2(0, 0), vec2(p.width, height), c.fill, radii.card)
    Outline(vec2(0, 0), vec2(p.width, height), c.border, radii.card)
    local a = p.accent
    Fill(vec2(a.x, a.inset), vec2(a.x + a.width, height - a.inset), c.hover, radii.chip)
end

-- Wrapped text, vertically centered in a shell rectangle.
local function DrawMessageText(text, textFont, min, max, color)
    local s = ShellScale()
    local p = layout.as6Panel.menu.popup
    ui.pushDWriteFont(textFont)
    ui.dwriteDrawTextClipped(text, scaling.size(p.fontSize * layout.shellScale), min * s, max * s,
        ui.Alignment.Start, ui.Alignment.Center, true, Faded(color))
    ui.popDWriteFont()
end

local function DrawNotificationPlate()
    local p = layout.as6Panel.menu.popup
    DrawMessagePlate(p.messageHeight)
    DrawMessageText(notificationMessage, fontSemiBold, vec2(p.textLeft, 0), vec2(p.width - p.textLeft, p.messageHeight),
        layout.as6Panel.card.textColor)
end

local function DrawForfeitPlate()
    local c = layout.as6Panel.card
    local p = layout.as6Panel.menu.popup
    local h = p.messageHeight
    DrawMessagePlate(h)

    -- The mock dialog loops the hold so the bar can be seen without holding the key. After
    -- the key is released the popup fades out with an empty bar.
    local held = 0
    if forfeitStartTime ~= nil then
        held = os.clock() - forfeitStartTime
    elseif mockShowForfeit then
        held = os.clock() % forfeitHoldDuration
    end
    local progress = math.max(0, math.min(1, held / forfeitHoldDuration))
    local textMax = vec2(p.width - p.textLeft, h - p.barBottom - p.barHeight)
    DrawMessageText("Hold F to forfeit the race", fontSemiBold, vec2(p.textLeft, 0), textMax, c.textColor)
    DrawShellText(string.format("%.1f s", math.max(0, forfeitHoldDuration - held)), fontBold, p.fontSize, p.fontSize,
        vec2(p.textLeft, 0), textMax, c.mutedColor, ui.Alignment.End)

    local barMin = vec2(p.textLeft, h - p.barBottom - p.barHeight)
    local barMax = vec2(p.width - p.textLeft, h - p.barBottom)
    Fill(barMin, barMax, c.boxFill, p.barHeight / 2)
    if progress > 0 then
        local send = layout.as6Panel.menu.send
        local fillMax = vec2(barMin.x + math.max(p.barHeight, (barMax.x - barMin.x) * progress), barMax.y)
        VerticalGradient(barMin, fillMax, send.topColor, send.bottomColor, p.barHeight / 2)
    end
end

local function DrawPopups()
    local p = layout.as6Panel.menu.popup
    local motion = layout.as6Panel.motion
    local s = ShellScale()
    local right = windowWidth - scaling.size(p.marginRight)
    local bottom = windowHeight - scaling.size(p.marginBottom)

    -- Each popup sits on top of the previous one. A popup slides in from the right and fades,
    -- and the ones above move to make room as it grows.
    local function Place(name, height, visible, draw)
        local shown = Tween(name, visible, motion.popup)
        if shown <= 0 then
            return
        end
        local size = vec2(p.width, height) * s
        local pos = vec2(right - size.x + (1 - shown) * motion.popupSlide * s, bottom - size.y)
        ui.transparentWindow(name, pos, size, function ()
            DrawFaded(shown, draw)
        end)
        bottom = bottom - (size.y + p.gap * s) * shown
    end

    Place("receivedInviteWindow", layout.as6Panel.card.size.y, hasActiveInvite, DrawInviteCard)
    Place("notificationWindow", p.messageHeight, hasIncomingNotification, DrawNotificationPlate)
    Place("forfeitWindow", p.messageHeight,
        (forfeitStartTime ~= nil and currentHudState ~= HudStates.Off) or mockShowForfeit, DrawForfeitPlate)
end

local lastCountdownMessage = nil

local function DrawCountdown()
    local motion = layout.as6Panel.motion
    local shown = Tween("countdown", isCountdownHudActive, motion.countdown)
    if shown <= 0 then
        lastCountdownMessage = nil
        return
    end
    -- Each new step pops in from a larger size.
    if countdownHudMessage ~= lastCountdownMessage then
        lastCountdownMessage = countdownHudMessage
        RestartTween("countdownPop")
    end
    local pop = Tween("countdownPop", true, motion.countdown)

    local c = layout.as6Panel.menu.countdown
    local s = ShellScale()
    local fontSize = scaling.size(c.fontSize * layout.shellScale)
    ui.pushDWriteFont(fontBold)
    local textSize = ui.measureDWriteText(countdownHudMessage, fontSize)
    ui.popDWriteFont()

    local size = vec2(textSize.x + 2 * c.paddingX * s, c.height * s)
    local pos = (vec2(windowWidth, windowHeight) - size) / 2
    local message = countdownHudMessage:lower()
    local color = c.readyColor
    if message:find("go") then
        color = c.goColor
    elseif message:find("set") then
        color = c.setColor
    end
    ui.transparentWindow("countdownWindow", pos, size, function ()
        DrawFaded(shown, function ()
            local textPos = (size - textSize) / 2
            ui.beginScale()
            ui.pushDWriteFont(fontBold)
            ui.dwriteDrawText(countdownHudMessage, fontSize, textPos + vec2(c.shadowOffset, c.shadowOffset) * s, Faded(c.shadowColor))
            ui.dwriteDrawText(countdownHudMessage, fontSize, textPos, Faded(color))
            ui.popDWriteFont()
            ui.endScale(motion.countdownPop + (1 - motion.countdownPop) * pop)
        end)
    end)
end

-- ==== 30_input.lua ====
-- Keyboard input and timers.

local function KeyPressed(key)
    return ui.keyboardButtonPressed(key, false) and not ui.anyItemFocused() and not ui.anyItemActive()
end

local function InputCheck()
    mouseClickHandled = false
    if KeyPressed(ui.KeyIndex.N) then
        -- Send invite
        SendToServer(inviteEvent, {inviteSenderName = "nearby", inviteRecipientGuid = 1})
        PlaySound("send")
    end
    if KeyPressed(ui.KeyIndex.I) then
        hasInviteMenuOpen = not hasInviteMenuOpen
        PlaySound(hasInviteMenuOpen and "open" or "close")
        if hasInviteMenuOpen then
            local now = os.clock()
            if now - lastLobbyStatusRequest > lobbyCooldown then
                lastLobbyStatusRequest = now
                SendToServer(lobbyStatusEvent)
            end
        end
    end
    if hasActiveInvite and KeyPressed(ui.KeyIndex.M) then
        AcceptInvite()
    end
    if KeyPressed(ui.KeyIndex.H) then
        hasTutorialHidden = not hasTutorialHidden
    end
    if currentHudState ~= HudStates.Off then
        if ui.keyboardButtonDown(ui.KeyIndex.F) then
            if not forfeitLockout then
                if not forfeitStartTime then
                    forfeitStartTime = os.clock()
                elseif os.clock() - forfeitStartTime >= forfeitHoldDuration then
                    SendToServer(forfeitEvent, {forfeit = true})
                    forfeitStartTime = nil -- reset so it doesn't trigger repeatedly
                    forfeitLockout = true  -- prevent repeat forfeits on same hold
                end
            end
        else
            forfeitStartTime = nil -- reset if key is released
            forfeitLockout = false
        end
    end
end

local function UpdateTimers(dt)
    if checkTimeout(inviteActivatedAt, 10) then
        hasActiveInvite = false
        inviteActivatedAt = nil
    end

    if checkTimeout(notificationActivatedAt, 10) then
        hasIncomingNotification = false
        notificationActivatedAt = nil
    end

    if checkTimeout(countdownActivatedAt, 5) then
        isCountdownHudActive = false
        countdownActivatedAt = nil
    end

    if discreteMode and showElo and eloShownAt ~= nil and os.clock() - eloShownAt >= 15 then
        eloShownAt = nil
        showElo = false
    end

    -- Animate the displayed Elo towards the target. It stays fractional; rounding happens when drawn.
    if elo ~= targetElo then
        local step = eloAnimSpeed * dt
        if math.abs(targetElo - elo) <= step then
            elo = targetElo
        elseif targetElo > elo then
            elo = elo + step
        else
            elo = elo - step
        end
    end
end

-- ==== 80_mock.lua ====
-- Debug mock panel. Fakes every server message by calling the same handlers as the real
-- events, so each HUD state can be shown without a second player. Opens from the online
-- extras menu when debugHud is true (00_config.lua).
--
-- Using any mock control sets mockActive, which stops the HUD from sending anything to the
-- server. Reset clears the mock state and asks the server for the real state again.

if debugHud then
    local resultNames = { [0] = "Tbd", "Win", "Loss", "Tie" }
    local stateNames = { "Off", "FirstTwo", "SuddenDeath", "Finished", "CatAndMouse" }
    local shortName = "Takumi"
    local longName = "An Extremely Long Player Name For Testing"

    local mockStandings = { RaceResults.Tbd, RaceResults.Tbd, RaceResults.Tbd }
    local mockHudState = HudStates.Off
    local mockElo = 1000
    local mockDiscrete = false
    local mockToggle = false
    local mockManyCourses = false

    local function MockSessionState()
        mockActive = true
        OnSessionState({
            result1 = mockStandings[1],
            result2 = mockStandings[2],
            result3 = mockStandings[3],
            sessionState = mockHudState,
            -- Without a second player, the player's own car stands in as the rival.
            rivalSessionId = mockHudState == HudStates.Off and -1 or car.sessionID,
        })
    end

    local function MockInitialization()
        mockActive = true
        local names = { "Akina Downhill" }
        if mockManyCourses then
            names = { "Akina Downhill", "Akina Uphill", "Usui Pass", "Irohazaka With A Very Long Course Name",
                "Myogi", "Akagi", "Happogahara", "Tsuchisaka" }
        end
        OnInitialization({
            elo = mockElo,
            racesCompleted = 0,
            useTrackFinish = true,
            discreteMode = mockDiscrete,
            loadSteamAvatars = false,
            courseNames = table.concat(names, "`"),
            showRaceTypeToggle = mockToggle,
        })
    end

    local function MockInvite(name)
        mockActive = true
        OnInvite({
            inviteSenderName = name,
            inviteRecipientGuid = 0,
            inviteSenderElo = 1234,
            inviteSenderId = "0", -- part of the packet; the HUD does not use it
            courseName = "",
            isCourse = true,
        })
    end

    local function MockLobbyStatus(count)
        mockActive = true
        local names = { shortName, "Keisuke", "Ryosuke Takahashi", longName, "Iketani" }
        local message = {}
        for i = 1, 5 do
            local present = i <= count
            message['nearbyName' .. i] = present and names[i] or ""
            message['nearbyId' .. i] = present and i or 0
            message['nearbyInRace' .. i] = present and i == 3 -- one player shown as busy
            message['nearbyElo' .. i] = present and (650 + i * 150) or 0
            -- Every mock driver shows the player's own car.
            message['nearbySessionId' .. i] = present and car.sessionID or -1
        end
        OnLobbyStatus(message)
        hasInviteMenuOpen = true
    end

    local function MockNotification(text, isCountdown)
        mockActive = true
        OnNotification({ message = text, isCountdown = isCountdown })
    end

    local function ResetMock()
        mockStandings = { RaceResults.Tbd, RaceResults.Tbd, RaceResults.Tbd }
        mockHudState = HudStates.Off
        OnSessionState({ result1 = 0, result2 = 0, result3 = 0, sessionState = HudStates.Off, rivalSessionId = -1 })
        mockShowForfeit = false
        mockRaceOverride = false
        mockGapSeconds = 0
        hasActiveInvite = false
        hasIncomingNotification = false
        isCountdownHudActive = false
        hasInviteMenuOpen = false
        nearbyPlayers = {}
        mockActive = false
        -- The server answers with the real Elo and settings.
        initializationEvent({elo = elo, racesCompleted = racesCompleted})
    end

    local function MockWindow()
        ui.textColored("Mock data is local only. While it is active, nothing is sent to the server.", rgbm.colors.red)
        ui.text(mockActive and "Mock: active" or "Mock: inactive")
        ui.sameLine()
        if ui.button("Reset") then ResetMock() end

        ui.separator()
        ui.text(string.format("Elo %.1f -> %s | showElo %s | discrete %s", elo, tostring(targetElo), tostring(showElo), tostring(discreteMode)))
        ui.text(string.format("Hint hidden %s | auto-hidden %s | speed %.0f km/h | menu open %s",
            tostring(hasTutorialHidden), tostring(isTutorialAutoHidden), car ~= nil and car.speedKmh or -1, tostring(hasInviteMenuOpen)))
        ui.text(string.format("Fade: elo %.2f | hint %.2f | menu %.2f | frame %.4f s",
            tweenValues.elo or 0, tweenValues.hint or 0, tweenValues.menu or 0, lastTweenDelta))

        ui.separator()
        ui.text("Session state")
        for i, name in ipairs(stateNames) do
            if i > 1 then ui.sameLine() end
            if ui.button(name) then
                mockHudState = HudStates[name]
                MockSessionState()
            end
        end
        for i = 1, 3 do
            if i > 1 then ui.sameLine() end
            if ui.button("Round " .. i .. ": " .. resultNames[mockStandings[i]] .. "##round" .. i) then
                mockStandings[i] = (mockStandings[i] + 1) % 4
                MockSessionState()
            end
        end

        ui.separator()
        ui.text("Race data")
        if ui.checkbox("Override gap", mockRaceOverride) then
            mockRaceOverride = not mockRaceOverride
            mockActive = true
        end
        local gap, gapChanged = ui.slider("##mockGap", mockGapSeconds, -5, 5, "Gap: %.2f s")
        if gapChanged then
            mockGapSeconds = gap
        end
        ui.text(string.format("Pos %s | %.1f m | %s s | %s (%s) vs %s (%s)",
            tostring(race.position), race.gapMeters,
            race.gapSeconds and string.format("%.2f", race.gapSeconds) or "-",
            race.driverName, race.driverCarName, race.rivalName, race.rivalCarName))

        ui.separator()
        ui.text("Elo")
        for i, value in ipairs({ 650, 999, 1000, 1500, 2400 }) do
            if i > 1 then ui.sameLine() end
            if ui.button(tostring(value)) then
                mockElo = value
                mockActive = true
                OnElo({ elo = value })
            end
        end

        ui.separator()
        ui.text("Initialization (Elo counts up from 100 below)")
        if ui.checkbox("Discrete mode (hides the Elo card and menu hint)", mockDiscrete) then mockDiscrete = not mockDiscrete end
        if ui.checkbox("Race type toggle", mockToggle) then mockToggle = not mockToggle end
        if ui.checkbox("8 courses", mockManyCourses) then mockManyCourses = not mockManyCourses end
        if ui.button("Send initialization") then MockInitialization() end

        ui.separator()
        ui.text("Menu")
        if ui.button("0 players") then MockLobbyStatus(0) end
        ui.sameLine()
        if ui.button("1 player") then MockLobbyStatus(1) end
        ui.sameLine()
        if ui.button("5 players") then MockLobbyStatus(5) end
        for _, tab in ipairs({ { "challenge", "Challenge" }, { "profile", "Profile" }, { "settings", "Settings" }, { "howto", "How to play" } }) do
            ui.sameLine()
            if ui.button("Menu: " .. tab[2]) then
                mockActive = true
                menuTab = tab[1]
                hasInviteMenuOpen = true
            end
        end

        ui.separator()
        ui.text("Popups")
        if ui.button("Invite: short name") then MockInvite(shortName) end
        ui.sameLine()
        if ui.button("Invite: long name") then MockInvite(longName) end
        if ui.button("Notification: short") then MockNotification("Invite accepted.", false) end
        ui.sameLine()
        if ui.button("Notification: long") then
            MockNotification("Keisuke won the race by outrunning Takumi on Akina Downhill.", false)
        end
        if ui.checkbox("Forfeit dialog", mockShowForfeit) then
            mockShowForfeit = not mockShowForfeit
            mockActive = true
        end

        ui.separator()
        ui.text("Countdown")
        for i, text in ipairs({ "Ready...", "Set...", "Go!" }) do
            if i > 1 then ui.sameLine() end
            if ui.button(text) then MockNotification(text, true) end
        end

        ui.separator()
        ui.text("Menu hint")
        if ui.checkbox("Hidden", hasTutorialHidden) then hasTutorialHidden = not hasTutorialHidden end
        if ui.checkbox("Auto-hidden (shows only below 10 km/h)", isTutorialAutoHidden) then
            isTutorialAutoHidden = not isTutorialAutoHidden
        end
    end

    ui.registerOnlineExtra(ui.Icons.SettingsAlt, "Touge HUD Mock", function () return true end, MockWindow, nil, ui.OnlineExtraFlags.Tool)
end

-- ==== 99_main.lua ====
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


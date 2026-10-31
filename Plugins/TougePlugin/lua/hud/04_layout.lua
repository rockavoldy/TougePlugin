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
                statHeight = 40,
                statStep = 48,
                statFontSize = 20,
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

            -- Countdown text centered on the screen on a frosted plate.
            countdown = {
                height = 110,
                paddingX = 56,
                fontSize = 72,
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

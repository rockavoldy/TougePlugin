-- Layout tables. One table per HUD element: its image, native size, screen anchor and the
-- positions of everything drawn on top of it. All values are reference pixels (see
-- 01_scaling.lua) relative to the element's top-left corner unless noted otherwise.
local layout = {
    elo = {
        image = assets.images.elo,
        pos = vec2(50, 50), -- from the top-left of the screen
        size = vec2(196, 82),
        label = vec2(11, 31),
        number = vec2(66, 26),
        numberBelow1000 = vec2(76, 26),
    },

    -- Small Elo badge on player cards: the Elo image at half size.
    eloBadge = {
        size = vec2(98, 41),
        text = vec2(32, 12),
        textBelow1000 = vec2(38, 12),
        fontSize = 16,
    },

    standings = {
        image = assets.images.standings,
        marginLeft = 50, -- vertically anchored at the screen centre
        size = vec2(387, 213),
        title = vec2(44, 37),
        pipY = 145,
        pipRadius = 25,
        pipSpacing = 40,
        suddenDeathTitle = vec2(44, 80),
        suddenDeathBody = vec2(44, 120),
        result = vec2(44, 90),
    },

    tutorial = {
        image = assets.images.tutorial,
        marginLeft = 50,
        marginBottom = 50,
        size = vec2(584, 415),
        title = vec2(32, 32),
        body = vec2(32, 78),
        controlsTitle = vec2(32, 177),
        keys = {
            image = assets.images.key,
            first = vec2(62, 215),
            spacingX = 120,
            size = 88,
            fontSize = 32,
            label = vec2(8, 96), -- relative to the key
            labelFontSize = 18,
        },
    },

    -- Shared by the invite menu and the course select screen.
    panel = {
        image = assets.images.inviteMenu,
        marginRight = 50,
        marginTop = 50,
        size = vec2(768, 1145),
        title = vec2(40, 40),
        titleFontSize = 48,
        listTop = 150,
        rowSpacing = 180,
        scrollSize = vec2(768, 1130),
        toggle = {
            image = assets.images.toggle,
            min = vec2(305, 31),
            max = vec2(736, 106),
            courseLabel = vec2(334, 50),
            outrunLabel = vec2(545, 50),
            fontSize = 36,
        },
    },

    -- A player or course row in the panel.
    card = {
        image = assets.images.playerCard,
        x = 32,
        size = vec2(705, 172),
        avatar = vec2(41, 34),
        avatarSize = 106,
        name = vec2(180, 40),
        nameClip = vec2(737, 172), -- clip rectangle size, from the name position
        nameFontSize = 48,
        nameMaxWidth = 550,
        eloBadge = vec2(180, 95),
    },

    -- Bottom-right popups (invite, notification, forfeit) stack upwards in that order.
    popup = {
        image = assets.images.playerCard,
        marginRight = 50,
        marginBottom = 50,
        size = vec2(705, 172),
        stackStep = 192,
    },

    invite = {
        eloBadge = vec2(182, 40),
        mKeyImage = assets.images.mKey,
        mKeyMin = vec2(560, 32),
        mKeyMax = vec2(670, 142),
        name = vec2(295, 35),
        nameFontSize = 48,
        nameMaxWidth = 270,
        subtitle = vec2(180, 95),
        subtitleFontSize = 36,
    },

    notification = {
        textMin = vec2(170, 0),
        textMax = vec2(650, 172),
        fontSize = 18,
    },

    forfeit = {
        text = vec2(179, 40),
        fontSize = 18,
    },

    countdown = {
        fontSize = 96,
    },

    -- Initial D elements are laid out in the shells' native pixels; shellScale converts
    -- them to reference pixels so the shells are drawn 1:1 at 1080p (see 06_shell.lua).
    shellScale = 1440 / 1080,

    -- Elo on the label-less name shell: label tab, player name in the header strip and the
    -- Elo number as chrome digits in the band.
    eloRow = {
        image = assets.images.idNameBlank,
        pos = vec2(50, 50), -- reference pixels from the top-left of the screen
        size = vec2(500, 70),
        label = vec2(38, 1),
        labelFontSize = 13,
        nameMin = vec2(100, 3),
        nameMax = vec2(420, 39),
        nameFontSize = 26,
        nameMinFontSize = 20,
        digitsCenterX = 250,
        digitsY = 41,
        digitSize = vec2(23, 26), -- position digits scaled to the band
    },

    -- Invite menu and course select in the style of the Initial D Arcade Stage 6 menus:
    -- a silver title bar, a subtitle pill and white cards with a gold frame on hover,
    -- anchored top-right. Placeholder drawn in code until real shells exist; every size and
    -- colour is here so images can replace the shapes later.
    as6Panel = {
        marginRight = 50, -- reference pixels
        marginTop = 50,
        width = 520,
        maxVisibleRows = 8, -- more course cards scroll with the mouse wheel
        bottomPadding = 12,

        -- Frosted backdrop: the scene behind the panel, blurred, under a 50% light layer.
        backdrop = {
            blur = 12,
            tint = rgbm(0.78, 0.85, 0.91, 0.5),
            border = rgbm(1, 1, 1, 0.55),
            rounding = 10,
        },

        title = {
            min = vec2(0, 0),
            max = vec2(520, 50),
            top = rgbm(0.95, 0.96, 0.97, 0.97), -- brushed silver gradient
            bottom = rgbm(0.64, 0.67, 0.71, 0.97),
            highlight = rgbm(1, 1, 1, 0.9),
            fontSize = 26,
            color = rgbm(0.2, 0.22, 0.25, 1),
        },

        subtitle = {
            min = vec2(40, 58),
            max = vec2(480, 82),
            fill = rgbm(0.86, 0.9, 0.94, 0.92),
            border = rgbm(1, 1, 1, 0.85),
            fontSize = 14,
            color = rgbm(0.25, 0.28, 0.32, 1),
        },

        -- Course / Outrun pills under the subtitle.
        toggle = {
            y = 92,
            size = vec2(140, 28),
            gap = 12,
            fontSize = 15,
            idleFill = rgbm(0.6, 0.64, 0.69, 0.92),
            idleText = rgbm(1, 1, 1, 1),
            selectedFill = rgbm(0.97, 0.97, 0.98, 1),
            selectedText = rgbm(0.2, 0.22, 0.25, 1),
        },

        listTop = 92,
        listTopWithToggle = 130,

        card = {
            x = 12,
            size = vec2(496, 86),
            step = 94,
            fill = rgbm(0.93, 0.95, 0.97, 0.95),
            border = rgbm(0.72, 0.77, 0.82, 1),
            rounding = 5,

            -- White box on the left with the headline value (Elo, race type) in red.
            boxMin = vec2(8, 8),
            boxMax = vec2(146, 56),
            boxFill = rgbm(1, 1, 1, 1),
            boxBorder = rgbm(0.7, 0.74, 0.78, 1),
            boxFontSize = 26,
            boxColor = rgbm(0.78, 0.08, 0.12, 1),

            -- Grey tag chips under the box.
            chipY = 61,
            chipHeight = 17,
            chipWidth = 67,
            chipGap = 4,
            chipFontSize = 11,
            chipFill = rgbm(0.6, 0.64, 0.69, 1),
            chipText = rgbm(1, 1, 1, 1),

            -- Silver info area on the right: caption, big name, detail line.
            infoMin = vec2(152, 8),
            infoMax = vec2(488, 78),
            infoTop = rgbm(0.99, 0.99, 1, 1),
            infoBottom = rgbm(0.85, 0.87, 0.9, 1),
            textLeft = 164, -- moves right by avatarShift when an avatar is shown
            textRight = 480,
            captionY = vec2(9, 25),
            captionFontSize = 13,
            nameY = vec2(24, 58),
            nameFontSize = 28,
            nameMinFontSize = 20,
            detailY = vec2(57, 76),
            detailFontSize = 14,
            textColor = rgbm(0.13, 0.14, 0.16, 1),
            mutedColor = rgbm(0.36, 0.39, 0.43, 1),
            busyColor = rgbm(0.55, 0.57, 0.6, 1),
            avatar = vec2(160, 13),
            avatarSize = 60,
            avatarShift = 68,

            -- Gold frame around the card under the mouse.
            hover = rgbm(0.93, 0.76, 0.3, 1),
            hoverGlow = rgbm(1, 0.85, 0.4, 0.35),
            hoverThickness = 3,
            hoverGlowThickness = 8,
        },

        -- The integrated menu, centered on the screen: title bar with tabs, subtitle, an
        -- optional pending challenge banner, then the tab content.
        menu = {
            width = 980,
            height = 620, -- without the banner
            titleText = vec2(24, 0), -- "TOUGE", left-aligned in the title bar
            tabs = { right = 964, y = 11, size = vec2(140, 28), gap = 8, fontSize = 14 },
            subtitleMin = vec2(40, 60),
            subtitleMax = vec2(940, 84),

            banner = {
                y = 94,
                height = 54,
                margin = 16,
                fontSize = 18,
                buttonSize = vec2(150, 34),
            },
            bannerSpace = 62, -- how far the content moves down while the banner shows

            contentTop = 96,
            captionHeight = 26,
            captionFontSize = 13,
            captionColor = rgbm(0.25, 0.28, 0.32, 1),
            leftX = 16,
            leftWidth = 472,
            rightX = 504,
            rightWidth = 460,

            courseCard = {
                height = 46,
                step = 52,
                maxVisible = 5,
                fontSize = 20,
                minFontSize = 15,
            },

            summaryFontSize = 15,
            send = {
                size = vec2(300, 46),
                bottom = 22, -- from the bottom of the menu
                fontSize = 20,
                topColor = rgbm(1, 0.9, 0.55, 1), -- gold gradient
                bottomColor = rgbm(0.86, 0.64, 0.18, 1),
                hoverTopColor = rgbm(1, 0.95, 0.7, 1),
                disabled = rgbm(0.7, 0.73, 0.77, 0.9),
                text = rgbm(0.2, 0.15, 0.05, 1),
                disabledText = rgbm(0.95, 0.96, 0.97, 1),
            },

            profile = {
                cardWidth = 600,
                statsTop = 220,
                statStep = 44,
                statFontSize = 20,
            },

            howto = {
                textWidth = 860,
                bodyFontSize = 17,
                keysTop = 260,
                keySize = vec2(46, 46),
                keyStep = 210,
                keyFontSize = 22,
                keyLabelFontSize = 15,
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
            win = rgbm(0.34, 0.45, 0.87, 1),   -- blue, the driver's colour
            loss = rgbm(1, 0.42, 0.53, 1),     -- pink, the rival's colour
            tie = rgbm(0.6, 0.6, 0.6, 0.9),
            pending = rgbm(1, 1, 1, 0.12),
            border = rgbm(0.8, 0.85, 1, 0.6),
        },
    },
}

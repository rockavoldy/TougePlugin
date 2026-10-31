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

    -- Invite menu and course select as a stack of label-less name rows, anchored top-right.
    -- The first row is the title; the band of the title row holds the race type toggle.
    idPanel = {
        marginRight = 50, -- reference pixels
        marginTop = 50,
        rowImage = assets.images.idNameBlank,
        rowSize = vec2(500, 70),
        listTop = 80, -- shell y of the first list row, below the title row
        rowStep = 76,
        maxVisibleRows = 10, -- more course rows scroll with the mouse wheel

        -- Frosted backdrop behind the whole panel: the scene behind it, blurred, under a
        -- 50% black layer.
        backdrop = {
            blur = 12, -- shell pixels
            tint = rgbm(0, 0, 0, 0.5),
        },

        label = vec2(38, 1),
        labelFontSize = 13,
        labelColor = rgbm(0.44, 0.65, 0.87, 1), -- the shells' "DRIVER" blue
        nameMin = vec2(100, 3),
        nameMax = vec2(420, 39),
        nameFontSize = 26,
        nameMinFontSize = 20,
        bandMin = vec2(40, 39),
        bandMax = vec2(460, 68),
        bandFontSize = 18,
        bandMinFontSize = 14,
        digitsCenterX = 250,
        digitsY = 41,
        digitSize = vec2(23, 26),
        avatar = vec2(40, 6),
        avatarSize = 58,

        hoverMin = vec2(30, 3),
        hoverMax = vec2(470, 68),
        hoverColor = rgbm(1, 1, 1, 0.1),
        textColor = rgbm(1, 1, 1, 1),
        busyColor = rgbm(0.55, 0.55, 0.55, 1),
        bandTextColor = rgbm(0.59, 0.75, 0.9, 1), -- as the driver's car name in the cluster

        toggle = {
            min = vec2(150, 42),
            max = vec2(350, 66),
            fontSize = 15,
            selected = rgbm(0.34, 0.45, 0.87, 1), -- the driver's blue
            idle = rgbm(1, 1, 1, 0.12),
            border = rgbm(0.8, 0.85, 1, 0.6),
            rounding = 4,
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

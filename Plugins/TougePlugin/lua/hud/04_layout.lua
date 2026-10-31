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
}

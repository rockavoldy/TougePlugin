-- Touge HUD client script.
--
-- The server joins every file in lua/hud/ in file name order into a single script named
-- hud.lua (see Touge.ProvideScript), so locals declared in an earlier file are visible in
-- later ones. Keep the numeric prefixes when adding files: they define the load order.

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
    win = { volume = 1 },       -- the session ends in a win
    lose = { volume = 1 },      -- the session ends in a loss
    countdown = { volume = 5 }, -- from countdown.zip, played on "Ready..."
}

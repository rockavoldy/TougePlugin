-- Touge HUD client script.
--
-- The server joins every file in lua/hud/ in file name order into a single script named
-- hud.lua (see Touge.ProvideScript), so locals declared in an earlier file are visible in
-- later ones. Keep the numeric prefixes when adding files: they define the load order.

local baseUrl = "http://" .. ac.getServerIP() .. ":" .. ac.getServerPortHTTP() .. "/static/TougePlugin/"

-- Adds the "Touge HUD Mock" window to the online extras menu, which fakes every server
-- message locally. Keep it off for release builds.
local debugHud = false

-- Draws the Initial D restyle (the in-race cluster and the restyled elements) instead of
-- the old HUD. Set to false to get the old HUD back.
local useIdHud = true

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

local keyBindings = {
    { key = "N", description = "Invite\nnearby" },
    { key = "I", description = "Invite\nmenu" },
    { key = "F", description = "Forfeit\n"},
    { key = "H", description = "Hide\ntutorial" },
}

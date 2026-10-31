-- HUD state. Written by the event handlers, input and timers; read by the draw functions.

local windowWidth = sim.windowWidth
local windowHeight = sim.windowHeight

local discreteMode = false
local loadSteamAvatars = false

-- elo is the displayed value, animated towards targetElo. -1 means unknown.
local elo = -1
local targetElo = -1
local eloAnimSpeed = 60 -- points per second
local showElo = true
local eloShownAt = nil

local racesCompleted = 0

local inviteSenderName = ""
local inviteSenderElo = -1
local inviteSenderId = ""
local inviteCourseName = ""
local hasActiveInvite = false
local inviteActivatedAt = nil

local hasInviteMenuOpen = false
local hasCourseSelectOpen = false
local nearbyPlayers = {}
local selectedPlayerId = -1
local lastLobbyStatusRequest = 0
local lobbyCooldown = 1.0  -- Cooldown in seconds
local courseNames = {}
local courseScroll = 0 -- first visible row of the Initial D course list
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
local countdownSoundPath = nil
local countdownSoundEvent = nil

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

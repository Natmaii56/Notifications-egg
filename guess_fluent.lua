--[[
    Guess the Thai Song - Fluent Edition
    UI  : StyearX/Fluent-modded (FluentPro)
    Func: ported from the original Zyzen script (functions only, UI replaced)
]]

local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/1.6.0/main.lua"))()

---------------------------------------------------------------------
-- 1. Services
---------------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local SoundService      = game:GetService("SoundService")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local UserInputService  = game:GetService("UserInputService")
local Stats             = game:GetService("Stats")
local LocalPlayer       = Players.LocalPlayer

---------------------------------------------------------------------
-- 2. Config
---------------------------------------------------------------------
local Const = {
    TAG = "[Zyzen]",
    MODES = { "Team", "Elimination", "Chaos" },
    CHAOS_ARRIVE_DISTANCE = 5,
    CHAOS_WALK_TIMEOUT = 15,
    CHAOS_DEST_OFFSET = Vector3.new(0, 3, 0),
    SCRIPT_URL = "https://raw.githubusercontent.com/Fayeeu/zyzen/refs/heads/main/mae.lua",
    SCRIPT_FILE = "Zyzen",
    REJOIN_MIN_INTERVAL = 10,
    REJOIN_SAME_SERVER = false,
}

local Settings = {
    Autoplay = false,
    AutoVoteMode = false,
    AutoSkipCountdown = false,
    AutoReward = false,
    FastClaim = false,
    SelectedMode = "Elimination",
    AnswerDelay = 2.0,
    RandomDelay = true,
    MinRandomDelay = 1.5,
    MaxRandomDelay = 2.0,
    ReloadOnTeleport = false,
    JobIdInput = "",
    WalkSpeedEnabled = false,
    WalkSpeed = 16,
    JumpPowerEnabled = false,
    JumpPower = 50,
    GravityEnabled = false,
    Gravity = 196.2,
    FOVEnabled = false,
    FieldOfView = 70,
    InfiniteJump = false,
    Noclip = false,
}

local State = {
    mode = "Unknown",
    songName = "Unknown",
    choices = {},
    canAnswer = false,
    elimButtons = {},
    chaosSongName = "",
}

local UI = {}

---------------------------------------------------------------------
-- 3. Util
---------------------------------------------------------------------
local Util = {}

local function Notify(title, content, ntype)
    Fluent:Notify({
        Title = title or "Zyzen",
        Content = tostring(content),
        Type = ntype or "Info",
        Duration = 5,
    })
end

function Util.setUI(name, text)
    local setter = UI[name]
    if setter then setter(text) end
end

function Util.log(text)
    Util.setUI("debug", text)
end

function Util.notify(description)
    Notify("Zyzen", description, "Info")
end

function Util.getDelay()
    if Settings.RandomDelay then
        local min, max = Settings.MinRandomDelay, Settings.MaxRandomDelay
        return min + math.random() * (max - min)
    end
    return Settings.AnswerDelay
end

function Util.displayName(name)
    if name and name ~= "" and name ~= "Unknown" then return name end
    return "Waiting for song..."
end

function Util.normalize(s)
    return (tostring(s):lower():gsub("%s+", ""))
end

function Util.findCorrectIndex(choices)
    for i, choice in ipairs(choices) do
        if choice.isCorrect then return i end
    end
    return 1
end

function Util.extractCorrectName(choices)
    if type(choices) ~= "table" then return "Unknown" end
    for _, choice in ipairs(choices) do
        if choice.isCorrect and choice.name then return choice.name end
    end
    return choices[1] and choices[1].name or "Unknown"
end

function Util.extractTeamName(song)
    if not song then return "Unknown" end
    if song.name and song.name ~= "" then return song.name end
    return Util.extractCorrectName(song.choices)
end

function Util.resetRound()
    State.canAnswer = false
    State.choices = {}
    State.songName = "Unknown"
    State.chaosSongName = ""
end

function Util.autoplay(action)
    task.spawn(function()
        if not Settings.Autoplay or not State.canAnswer then return end
        State.canAnswer = false
        task.wait(Util.getDelay())
        action()
    end)
end

function Util.copy(text, label)
    local fn = setclipboard or toclipboard
    if fn then
        fn(tostring(text))
        Util.notify((label or "Text") .. " copied")
    else
        Util.notify("Clipboard not supported")
    end
end

---------------------------------------------------------------------
-- 4. Persist (last rejoin timestamp only)
---------------------------------------------------------------------
local Persist = { data = {} }

do
    local PATH = "ZyzenFluent/.cache/zyzen_state.json"

    local function read()
        if not (isfile and isfile(PATH)) then return {} end
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(PATH))
        end)
        return (ok and type(decoded) == "table") and decoded or {}
    end

    function Persist.save()
        pcall(writefile, PATH, HttpService:JSONEncode(Persist.data))
    end

    Persist.data = read()
end

---------------------------------------------------------------------
-- 5. Rejoin / Server hop / Fast claim
---------------------------------------------------------------------
local Rejoin = {}

do
    local queueScript = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)

    local busy   = false
    local queued = false

    local function buildBootstrap()
        local loader
        if Const.SCRIPT_FILE ~= "" and isfile and isfile(Const.SCRIPT_FILE) then
            loader = ("loadstring(readfile(%q))()"):format(Const.SCRIPT_FILE)
        elseif Const.SCRIPT_URL ~= "" then
            loader = ("loadstring(game:HttpGet(%q))()"):format(Const.SCRIPT_URL)
        end
        if not loader then return nil end
        return "if not game:IsLoaded() then game.Loaded:Wait() end\n" .. loader
    end

    local function fail(message)
        busy = false
        warn(Const.TAG, message)
        Util.notify(message)
    end

    function Rejoin.queue()
        if queued then return true end
        if not queueScript then
            warn(Const.TAG, "Rejoin: queue_on_teleport not supported")
            return false
        end
        local bootstrap = buildBootstrap()
        if not bootstrap then
            warn(Const.TAG, "Rejoin: set Const.SCRIPT_URL or Const.SCRIPT_FILE first")
            return false
        end
        queueScript(bootstrap)
        queued = true
        return true
    end

    local function prepare()
        if Settings.ReloadOnTeleport then Rejoin.queue() end
    end

    local function teleportPlace(sameServer)
        if sameServer and #Players:GetPlayers() > 1 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        else
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end

    local function go(callback)
        local ok, err = pcall(callback)
        if not ok then fail("Teleport error: " .. tostring(err)) end
    end

    local function fetchServers(sortOrder)
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true")
            :format(game.PlaceId, sortOrder)

        local okGet, body = pcall(game.HttpGet, game, url)
        if not okGet then return nil end

        local okJson, data = pcall(HttpService.JSONDecode, HttpService, body)
        if not okJson or type(data) ~= "table" or type(data.data) ~= "table" then return nil end

        return data.data
    end

    local function pickServer(mode)
        local list = fetchServers(mode == "smallest" and "Asc" or "Desc")
        if not list then return nil end

        local candidates = {}
        for _, server in ipairs(list) do
            if server.id ~= game.JobId
                and server.playing and server.maxPlayers
                and server.playing < server.maxPlayers then
                table.insert(candidates, server)
            end
        end

        if #candidates == 0 then return nil end
        if mode == "smallest" then return candidates[1] end
        return candidates[math.random(#candidates)]
    end

    TeleportService.TeleportInitFailed:Connect(function()
        busy   = false
        queued = false
        Util.log("Teleport failed")
    end)

    function Rejoin.rejoin()
        if busy then return end
        busy = true

        prepare()
        go(function() teleportPlace(true) end)
    end

    function Rejoin.hop(mode)
        if busy then return end
        busy = true

        task.spawn(function()
            Util.notify("Searching for a server...")

            local server = pickServer(mode)
            if not server then return fail("No server found (rate limited?)") end

            prepare()
            Util.notify(("Hopping (%d/%d players)"):format(server.playing, server.maxPlayers))
            go(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
            end)
        end)
    end

    function Rejoin.join(jobId)
        if busy then return end

        jobId = (tostring(jobId or ""):gsub("%s+", ""))

        if not jobId:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then
            return Util.notify("Invalid Job ID")
        end
        if jobId == game.JobId then
            return Util.notify("Already in this server")
        end

        busy = true
        prepare()
        go(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
        end)
    end

    function Rejoin.trigger()
        if busy then return end
        busy = true

        task.spawn(function()
            local sinceLast = os.time() - (Persist.data.lastRejoin or 0)
            local remaining = Const.REJOIN_MIN_INTERVAL - sinceLast

            if remaining > 0 then
                Util.log(("Rejoin in %ds"):format(math.ceil(remaining)))
                task.wait(remaining)
            end

            if not Settings.FastClaim then
                busy = false
                return
            end

            if not Rejoin.queue() then
                busy = false
                return
            end

            Persist.data.lastRejoin = os.time()
            Persist.save()

            Util.notify("Fast Claim: rejoining...")
            go(function() teleportPlace(Const.REJOIN_SAME_SERVER) end)
        end)
    end
end

---------------------------------------------------------------------
-- 6. Remotes
---------------------------------------------------------------------
local Remotes = {}

do
    local TIMEOUT = 5
    local ok = pcall(function()
        local events = ReplicatedStorage:FindFirstChild("SongGuessEvents", TIMEOUT)
        Remotes.events = events
        Remotes.submitModeVote = ReplicatedStorage:FindFirstChild("SubmitModeVote", TIMEOUT)
        Remotes.skipCountdown = ReplicatedStorage:FindFirstChild("skipCountdownEvent", TIMEOUT)
        Remotes.submitAnswer = events:FindFirstChild("SubmitAnswer", TIMEOUT)
        Remotes.submitAnswerElim = events:FindFirstChild("SubmitAnswerEliminationMode", TIMEOUT)
        Remotes.submitVote = events:FindFirstChild("SubmitVote", TIMEOUT)
        Remotes.newQuestion = events:FindFirstChild("NewQuestion", TIMEOUT)
        Remotes.showElimSong = events:FindFirstChild("ShowEliminationSongUI", TIMEOUT)
        Remotes.showElimResult = events:FindFirstChild("ShowEliminationResultUI", TIMEOUT)
        Remotes.showChaosSong = events:FindFirstChild("ShowChaosSongUI", TIMEOUT)
    end)
    if ok then
        print(Const.TAG, "Events loaded.")
    else
        warn(Const.TAG, "Some events not found.")
    end
end

---------------------------------------------------------------------
-- 7. Fluent UI
---------------------------------------------------------------------
local Window = Fluent:CreateWindow({
    Title = "Guess the Thai Song",
    SubTitle = "Fluent Edition",
    TabWidth = 150,
    Size = UDim2.fromOffset(580, 500),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
    UserInfo = {
        UserInfo = true,
        UserInfoTitle = LocalPlayer.Name,
        UserInfoSubtitle = LocalPlayer.DisplayName,
        UserInfoColor = Color3.fromRGB(88, 101, 242),
    },
})

local Tabs = {
    Auto     = Window:AddTab({ Title = "Auto",     Icon = "rbxassetid://7733960981" }),
    Player   = Window:AddTab({ Title = "Player",   Icon = "rbxassetid://7743878358" }),
    Server   = Window:AddTab({ Title = "Server",   Icon = "rbxassetid://7734052335" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "rbxassetid://7734053495" }),
}

local Para = {}

local function AddParagraph(sec, title, content)
    local ok, para = pcall(function()
        return sec:AddParagraph({ Title = title, Content = content })
    end)
    return ok and para or nil
end

local function setParagraph(para, text)
    if not para then return end
    pcall(function() para:SetValue(tostring(text)) end)
    pcall(function() para:SetDesc(tostring(text)) end)
end

do -- Auto tab
    local secControls = Tabs.Auto:AddSection("Controls")

    secControls:AddToggle("Autoplay", {
        Title = "Autoplay",
        Default = Settings.Autoplay,
        Callback = function(v) Settings.Autoplay = v end,
    })

    secControls:AddToggle("AutoVoteMode", {
        Title = "Auto Vote Mode",
        Default = Settings.AutoVoteMode,
        Callback = function(v) Settings.AutoVoteMode = v end,
    })

    secControls:AddDropdown("SelectedMode", {
        Title = "Vote Mode",
        Values = Const.MODES,
        Default = Settings.SelectedMode,
        Callback = function(v) Settings.SelectedMode = v end,
    })

    secControls:AddToggle("AutoSkipCountdown", {
        Title = "Auto Skip Countdown",
        Default = Settings.AutoSkipCountdown,
        Callback = function(v) Settings.AutoSkipCountdown = v end,
    })

    local secSong = Tabs.Auto:AddSection("Current Song")

    Para.status   = AddParagraph(secSong, "Status", "Not Playing")
    Para.song     = AddParagraph(secSong, "Song", "Waiting...")
    Para.loudness = AddParagraph(secSong, "Loudness", "0")
    Para.time     = AddParagraph(secSong, "Time", "0:00 / 0:00")
    Para.debug    = AddParagraph(secSong, "Debug", "Ready")

    UI.status   = function(t) setParagraph(Para.status, t) end
    UI.song     = function(t) setParagraph(Para.song, t) end
    UI.loudness = function(t) setParagraph(Para.loudness, t) end
    UI.time     = function(t) setParagraph(Para.time, t) end
    UI.debug    = function(t) setParagraph(Para.debug, t) end

    local secDelay = Tabs.Auto:AddSection("Delay Config")

    secDelay:AddToggle("RandomDelay", {
        Title = "Random Delay",
        Default = Settings.RandomDelay,
        Callback = function(v) Settings.RandomDelay = v end,
    })

    secDelay:AddSlider("AnswerDelay", {
        Title = "Answer Delay",
        Min = 0, Max = 5, Default = Settings.AnswerDelay, Rounding = 2,
        Callback = function(v) Settings.AnswerDelay = v end,
    })

    secDelay:AddSlider("MinRandomDelay", {
        Title = "Min Random Delay",
        Min = 0, Max = 5, Default = Settings.MinRandomDelay, Rounding = 2,
        Callback = function(v) Settings.MinRandomDelay = v end,
    })

    secDelay:AddSlider("MaxRandomDelay", {
        Title = "Max Random Delay",
        Min = 0, Max = 5, Default = Settings.MaxRandomDelay, Rounding = 2,
        Callback = function(v) Settings.MaxRandomDelay = v end,
    })

    local secParkour = Tabs.Auto:AddSection("Parkour")

    secParkour:AddToggle("AutoReward", {
        Title = "Auto Claim Reward",
        Default = Settings.AutoReward,
        Callback = function(v) Settings.AutoReward = v end,
    })

    secParkour:AddToggle("FastClaim", {
        Title = "Fast Claim (Rejoin)",
        Default = Settings.FastClaim,
        Callback = function(v) Settings.FastClaim = v end,
    })

    Para.cooldown = AddParagraph(secParkour, "Cooldown", "Ready")
    UI.cooldown = function(t) setParagraph(Para.cooldown, t) end
end

do -- Player tab
    local secMove = Tabs.Player:AddSection("Movement")

    secMove:AddToggle("WalkSpeedEnabled", {
        Title = "WalkSpeed",
        Default = Settings.WalkSpeedEnabled,
        Callback = function(v) Settings.WalkSpeedEnabled = v end,
    })

    secMove:AddSlider("WalkSpeed", {
        Title = "Speed",
        Min = 0, Max = 200, Default = Settings.WalkSpeed, Rounding = 0,
        Callback = function(v) Settings.WalkSpeed = v end,
    })

    secMove:AddToggle("JumpPowerEnabled", {
        Title = "JumpPower",
        Default = Settings.JumpPowerEnabled,
        Callback = function(v) Settings.JumpPowerEnabled = v end,
    })

    secMove:AddSlider("JumpPower", {
        Title = "Power",
        Min = 0, Max = 300, Default = Settings.JumpPower, Rounding = 0,
        Callback = function(v) Settings.JumpPower = v end,
    })

    secMove:AddToggle("InfiniteJump", {
        Title = "Infinite Jump",
        Default = Settings.InfiniteJump,
        Callback = function(v) Settings.InfiniteJump = v end,
    })

    secMove:AddToggle("Noclip", {
        Title = "Noclip",
        Default = Settings.Noclip,
        Callback = function(v) Settings.Noclip = v end,
    })

    local secWorld = Tabs.Player:AddSection("World & Camera")

    secWorld:AddToggle("GravityEnabled", {
        Title = "Gravity",
        Default = Settings.GravityEnabled,
        Callback = function(v) Settings.GravityEnabled = v end,
    })

    secWorld:AddSlider("Gravity", {
        Title = "Gravity Value",
        Min = 0, Max = 400, Default = Settings.Gravity, Rounding = 1,
        Callback = function(v) Settings.Gravity = v end,
    })

    secWorld:AddToggle("FOVEnabled", {
        Title = "Field of View",
        Default = Settings.FOVEnabled,
        Callback = function(v) Settings.FOVEnabled = v end,
    })

    secWorld:AddSlider("FieldOfView", {
        Title = "FOV Value",
        Min = 30, Max = 120, Default = Settings.FieldOfView, Rounding = 0,
        Callback = function(v) Settings.FieldOfView = v end,
    })

    local secChar = Tabs.Player:AddSection("Character")

    secChar:AddButton({
        Title = "Reset Character",
        Callback = function()
            local character = LocalPlayer.Character
            local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.Health = 0 end
        end,
    })
end

do -- Server tab
    local joinScript = ('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, %q, game.Players.LocalPlayer)')
        :format(game.PlaceId, game.JobId)

    local secInfo = Tabs.Server:AddSection("Server Info")

    AddParagraph(secInfo, "Place ID", tostring(game.PlaceId))
    AddParagraph(secInfo, "Job ID", game.JobId)
    Para.players = AddParagraph(secInfo, "Players", "-")
    Para.ping    = AddParagraph(secInfo, "Ping", "-")

    UI.players = function(t) setParagraph(Para.players, t) end
    UI.ping    = function(t) setParagraph(Para.ping, t) end

    local secActions = Tabs.Server:AddSection("Actions")

    secActions:AddButton({
        Title = "Rejoin",
        Callback = function() Rejoin.rejoin() end,
    })

    secActions:AddButton({
        Title = "Server Hop",
        Callback = function() Rejoin.hop("random") end,
    })

    secActions:AddButton({
        Title = "Hop to Smallest Server",
        Callback = function() Rejoin.hop("smallest") end,
    })

    secActions:AddToggle("ReloadOnTeleport", {
        Title = "Re-run Script After Teleport",
        Default = Settings.ReloadOnTeleport,
        Callback = function(v) Settings.ReloadOnTeleport = v end,
    })

    local secJob = Tabs.Server:AddSection("Job ID")

    secJob:AddButton({
        Title = "Copy Job ID",
        Callback = function() Util.copy(game.JobId, "Job ID") end,
    })

    secJob:AddButton({
        Title = "Copy Join Script",
        Callback = function() Util.copy(joinScript, "Join script") end,
    })

    secJob:AddInput("JobIdInput", {
        Title = "Job ID",
        Placeholder = "Paste Job ID here",
        Callback = function(v) Settings.JobIdInput = v end,
    })

    secJob:AddButton({
        Title = "Join Server",
        Callback = function() Rejoin.join(Settings.JobIdInput) end,
    })
end

do -- Settings tab (Interface + Config managers)
    pcall(function()
        InterfaceManager:SetLibrary(Fluent)
        InterfaceManager:SetFolder("ZyzenFluent")
        InterfaceManager:BuildInterfaceSection(Tabs.Settings)
        InterfaceManager:LoadSettings()
    end)

    pcall(function()
        SaveManager:SetLibrary(Fluent)
        SaveManager:SetFolder("ZyzenFluent/Config")
        SaveManager:IgnoreThemeSettings()
        SaveManager:BuildConfigSection(Tabs.Settings)
        SaveManager:LoadAutoloadConfig()
    end)
end

---------------------------------------------------------------------
-- 8. LocalPlayer loops
---------------------------------------------------------------------
do
    local defaults = {
        Gravity     = Workspace.Gravity,
        FieldOfView = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70,
    }

    local saved  = setmetatable({}, { __mode = "k" })
    local active = {}

    local function getHumanoid()
        local character = LocalPlayer.Character
        return character and character:FindFirstChildOfClass("Humanoid")
    end

    local function drive(key, enabled, apply, restore)
        if enabled then
            apply()
            active[key] = true
        elseif active[key] then
            restore()
            active[key] = nil
        end
    end

    RunService.Heartbeat:Connect(function()
        local humanoid = getHumanoid()

        if humanoid then
            local base = saved[humanoid]
            if not base then
                base = {
                    WalkSpeed    = humanoid.WalkSpeed,
                    JumpPower    = humanoid.JumpPower,
                    UseJumpPower = humanoid.UseJumpPower,
                }
                saved[humanoid] = base
            end

            drive("WalkSpeed", Settings.WalkSpeedEnabled,
                function() humanoid.WalkSpeed = Settings.WalkSpeed end,
                function() humanoid.WalkSpeed = base.WalkSpeed end)

            drive("JumpPower", Settings.JumpPowerEnabled,
                function()
                    humanoid.UseJumpPower = true
                    humanoid.JumpPower    = Settings.JumpPower
                end,
                function()
                    humanoid.UseJumpPower = base.UseJumpPower
                    humanoid.JumpPower    = base.JumpPower
                end)
        end

        drive("Gravity", Settings.GravityEnabled,
            function() Workspace.Gravity = Settings.Gravity end,
            function() Workspace.Gravity = defaults.Gravity end)

        local camera = Workspace.CurrentCamera
        if camera then
            drive("FOV", Settings.FOVEnabled,
                function() camera.FieldOfView = Settings.FieldOfView end,
                function() camera.FieldOfView = defaults.FieldOfView end)
        end
    end)

    RunService.Stepped:Connect(function()
        if not Settings.Noclip then return end

        local character = LocalPlayer.Character
        if not character then return end

        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)

    UserInputService.JumpRequest:Connect(function()
        if not Settings.InfiniteJump then return end

        local humanoid = getHumanoid()
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

---------------------------------------------------------------------
-- 9. Song info loop
---------------------------------------------------------------------
do
    local UPDATE_INTERVAL = 0.1
    local last = {}
    local elapsed = 0

    local function update(name, value)
        if last[name] == value then return end
        last[name] = value
        Util.setUI(name, value)
    end

    local function formatTime(seconds)
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    end

    local function findPlayingSound()
        for _, child in ipairs(SoundService:GetChildren()) do
            if child:IsA("Sound") and child.IsPlaying then return child end
        end
    end

    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < UPDATE_INTERVAL then return end
        elapsed = 0

        update("song", Util.displayName(State.songName))

        local sound = findPlayingSound()
        if sound then
            update("status", "Playing")
            update("loudness", string.format("%.0f", sound.PlaybackLoudness))
            update("time", formatTime(sound.TimePosition) .. " / " .. formatTime(sound.TimeLength))
        else
            update("status", "Not Playing")
            update("loudness", "0")
            update("time", "0:00 / 0:00")
        end
    end)
end

---------------------------------------------------------------------
-- 10. Parkour reward
---------------------------------------------------------------------
do
    local POLL_INTERVAL = 0.25
    local cooldownUntil = 0

    local function claimReward()
        if not firetouchinterest then return false end
        if os.clock() < cooldownUntil then return false end

        local parkour = Workspace:FindFirstChild("Parkour")
        local rewardPath = parkour and parkour:FindFirstChild("RewardPath")
        if not rewardPath then return false end

        if not rewardPath:FindFirstChild("TouchInterest") then return false end

        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        firetouchinterest(root, rewardPath, 0)
        task.wait()
        firetouchinterest(root, rewardPath, 1)

        return true
    end

    local lastText = ""
    local function updateCooldownLabel()
        local remaining = cooldownUntil - os.clock()
        local text = remaining > 0 and (math.ceil(remaining) .. "s") or "Ready"

        if text == lastText then return end
        lastText = text
        Util.setUI("cooldown", text)
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local cooldownNotice = remotes and remotes:FindFirstChild("CooldownNotice")

    if cooldownNotice then
        cooldownNotice.OnClientEvent:Connect(function(seconds)
            seconds = tonumber(seconds)
            if not seconds then return end

            cooldownUntil = os.clock() + seconds
            Util.log(("Reward cooldown %.1fs"):format(seconds))
            updateCooldownLabel()

            if Settings.FastClaim and seconds > 0 then
                Rejoin.trigger()
            end
        end)
    else
        warn(Const.TAG, "CooldownNotice not found.")
    end

    task.spawn(function()
        while true do
            if (Settings.AutoReward or Settings.FastClaim) and claimReward() then
                Util.log("Reward touched")
            end

            updateCooldownLabel()
            task.wait(POLL_INTERVAL)
        end
    end)
end

---------------------------------------------------------------------
-- 11. Server info loop
---------------------------------------------------------------------
do
    local UPDATE_INTERVAL = 1

    local function getPing()
        local ok, value = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        return ok and math.floor(value) or nil
    end

    task.spawn(function()
        while true do
            Util.setUI("players", ("%d / %d"):format(#Players:GetPlayers(), Players.MaxPlayers))

            local ping = getPing()
            Util.setUI("ping", ping and (ping .. " ms") or "N/A")

            task.wait(UPDATE_INTERVAL)
        end
    end)
end

---------------------------------------------------------------------
-- 12. Handlers
---------------------------------------------------------------------
local events = Remotes.events
if not events then
    warn(Const.TAG, "SongGuessEvents not found.")
    return
end

do -- Survivor
    local RESETTABLE_MODES = {
        Unknown = true,
        Team = true,
        Elimination = true,
        Chaos = true,
    }

    local function onNewQuestion(_, choices, songNumber)
        if RESETTABLE_MODES[State.mode] then
            State.mode = songNumber ~= nil and "Survivor" or "Random"
        end

        State.choices = choices or {}
        State.songName = Util.extractCorrectName(State.choices)
        State.canAnswer = true

        Util.setUI("song", Util.displayName(State.songName))
        Util.log("NewQuestion: " .. #State.choices .. " choices")

        Util.autoplay(function()
            if not Remotes.submitAnswer then return end

            local idx = Util.findCorrectIndex(State.choices)
            Remotes.submitAnswer:FireServer(idx)

            Util.notify(("Answered: %d ==> %s"):format(idx, State.songName))
            Util.log(("Answered [%s]: %d"):format(State.mode, idx))
        end)
    end

    if Remotes.newQuestion then
        Remotes.newQuestion.OnClientEvent:Connect(onNewQuestion)
    end
end

do -- Mode voting
    local function autoVoteMode(waitTime, label)
        task.spawn(function()
            if not Settings.AutoVoteMode then return end
            task.wait(waitTime)
            if not Remotes.submitModeVote then return end

            Remotes.submitModeVote:FireServer(Settings.SelectedMode)
            Util.notify(label .. Settings.SelectedMode)
            Util.log("Voted: " .. Settings.SelectedMode)
        end)
    end

    local function bind(eventName, waitTime, label)
        local remote = events:FindFirstChild(eventName)
        if not remote then return end

        remote.OnClientEvent:Connect(function()
            autoVoteMode(waitTime, label)
        end)
    end

    bind("ShowModeSelection", 0.5, "Voted: ")
    bind("StartVote", 0.3, "Voted (StartVote): ")
end

do -- Team (PvP)
    local playPvPSongs = events:FindFirstChild("PlayPvPSongs")

    if playPvPSongs then
        playPvPSongs.OnClientEvent:Connect(function(song1, song2)
            local name1 = Util.extractTeamName(song1)
            local name2 = Util.extractTeamName(song2)

            State.mode = "Team"
            State.songName = name1 .. " vs " .. name2
            State.choices = { song1, song2 }
            State.canAnswer = true

            Util.setUI("song", State.songName)
            Util.log("Team: " .. State.songName)

            Util.autoplay(function()
                if not Remotes.submitVote then return end

                Remotes.submitVote:FireServer(1)
                Util.notify("Team vote: 1")
                Util.log("Team vote: 1")
            end)
        end)
    end
end

do -- Elimination
    local function collectButtons()
        local buttons = {}

        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local elimUi = playerGui and playerGui:FindFirstChild("EliminationModeSongUI")
        local container = elimUi and (elimUi:FindFirstChild("VoteSongFrame") or elimUi:FindFirstChild("Container"))
        if not container then return buttons end

        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiButton") then table.insert(buttons, child) end
        end

        table.sort(buttons, function(a, b)
            if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
            return a.Name < b.Name
        end)

        return buttons
    end

    local function onShowSong(choices, roundNumber)
        State.mode = "Elimination"
        State.songName = "Unknown"
        State.choices = {}

        if type(choices) == "table" then
            for _, choice in ipairs(choices) do
                if type(choice) == "table" then table.insert(State.choices, choice) end
            end
            State.songName = Util.extractCorrectName(State.choices)
        end

        State.elimButtons = collectButtons()
        State.canAnswer = true
        Util.log("Elimination round " .. tostring(roundNumber))

        Util.autoplay(function()
            local idx = Util.findCorrectIndex(State.choices)

            if Remotes.submitAnswerElim then
                Remotes.submitAnswerElim:FireServer(idx)
                Util.notify("Answered ==> " .. idx .. "\n" .. State.songName)

                -- Kept from the original: also submits the previous index.
                if idx > 1 then
                    Remotes.submitAnswerElim:FireServer(idx - 1)
                end
            end

            local button = State.elimButtons[idx]
            if button and firesignal then
                pcall(firesignal, button.MouseButton1Click)
            end

            Util.log("Elimination: " .. idx)
        end)
    end

    local function onShowResult(results)
        State.canAnswer = false

        local correct, wrong = 0, 0
        if type(results) == "table" then
            for _, result in ipairs(results) do
                if result.isCorrect then correct += 1 else wrong += 1 end
            end
        end

        Util.log(("Elim: %d correct / %d wrong"):format(correct, wrong))
    end

    if Remotes.showElimSong then
        Remotes.showElimSong.OnClientEvent:Connect(onShowSong)
    end

    if Remotes.showElimResult then
        Remotes.showElimResult.OnClientEvent:Connect(onShowResult)
    end
end

do -- Chaos
    local function findSongName(data)
        if type(data) ~= "table" or type(data.choices) ~= "table" then return "" end

        for _, choice in ipairs(data.choices) do
            if choice.isCorrect and choice.name then return choice.name end
        end
        return ""
    end

    local function findPicture(buttonFolder, songName)
        local target = Util.normalize(songName)
        local bestPart, bestScore = nil, 0

        for _, part in ipairs(buttonFolder:GetChildren()) do
            if part:IsA("BasePart") and part.Name:match("^PictureChaosBase%d+$") then
                local gui   = part:FindFirstChild("SurfaceGui")
                local label = gui and gui:FindFirstChild("TextLabel")

                if label and label.Text ~= "" then
                    local text  = Util.normalize(label.Text)
                    local score = 0

                    if text == target then
                        score = 2
                    elseif text:find(target, 1, true) or target:find(text, 1, true) then
                        score = 1
                    end

                    if score > bestScore then bestPart, bestScore = part, score end
                end
            end
        end

        return bestPart
    end

    local function findNearestPart(parts, position)
        local nearest, nearestDist = nil, math.huge

        for _, part in ipairs(parts) do
            local dx = part.Position.X - position.X
            local dz = part.Position.Z - position.Z
            local dist = dx * dx + dz * dz

            if dist < nearestDist then nearest, nearestDist = part, dist end
        end

        return nearest
    end

    local function walkTo(humanoid, root, dest)
        local deadline = os.clock() + Const.CHAOS_WALK_TIMEOUT

        local function distance()
            return (root.Position - dest).Magnitude
        end

        while root.Parent
            and distance() >= Const.CHAOS_ARRIVE_DISTANCE
            and os.clock() < deadline do
            humanoid:MoveTo(dest)
            task.wait(0.1)
        end

        if not root.Parent then return end

        if distance() < Const.CHAOS_ARRIVE_DISTANCE then
            Util.log("Chaos: arrived")
        else
            warn(Const.TAG, "Chaos: timeout, teleporting")
            root.CFrame = CFrame.new(dest)
            Util.log("Chaos: fallback teleport")
        end
    end

    local function play()
        local base = Workspace:FindFirstChild("ChaosModeBase")
        if not base then return warn(Const.TAG, "Chaos: ChaosModeBase not found") end

        local buttonFolder = base:FindFirstChild("ButtonChaosMode")
        local teleportFolder = base:FindFirstChild("TeleportPart")
        if not buttonFolder or not teleportFolder then
            return warn(Const.TAG, "Chaos: folders missing")
        end

        local picture = findPicture(buttonFolder, State.chaosSongName)
        if not picture then
            warn(Const.TAG, ('Chaos: no match for "%s"'):format(State.chaosSongName))
            Util.log("Chaos: no match!")
            return
        end

        local teleportParts = {}
        for _, child in ipairs(teleportFolder:GetChildren()) do
            if child:IsA("BasePart") then table.insert(teleportParts, child) end
        end

        local target = findNearestPart(teleportParts, picture.Position)
        if not target then return warn(Const.TAG, "Chaos: no TeleportPart") end

        local character = LocalPlayer.Character
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root then return end

        Util.notify("Chaos: MoveTo ==> " .. picture.Name)
        Util.log("Chaos: ==> " .. picture.Name)
        walkTo(humanoid, root, target.Position + Const.CHAOS_DEST_OFFSET)
    end

    if Remotes.showChaosSong then
        Remotes.showChaosSong.OnClientEvent:Connect(function(data, current, total)
            print(Const.TAG, ("ShowChaosSongUI #%s/%s"):format(tostring(current), tostring(total)))

            State.mode = "Chaos"
            State.canAnswer = true
            State.chaosSongName = findSongName(data)

            local shown = State.chaosSongName ~= "" and State.chaosSongName or "unknown"
            Util.setUI("song", "Chaos: " .. shown)
            Util.log("Chaos ==> " .. shown)

            Util.autoplay(play)
        end)
    else
        warn(Const.TAG, "ShowChaosSongUI not found.")
    end
end

do -- Auto skip countdown
    local updateVoteUI = ReplicatedStorage:FindFirstChild("UpdateVoteUIEvent")

    if updateVoteUI then
        updateVoteUI.OnClientEvent:Connect(function(current, needed)
            if not Settings.AutoSkipCountdown then return end

            if current >= needed and Remotes.skipCountdown then
                Remotes.skipCountdown:FireServer()
                Util.log("Skipped countdown")
            end
        end)
    end
end

do -- Round lifecycle
    local roundStart = events:FindFirstChild("RoundStart")

    if roundStart then
        roundStart.OnClientEvent:Connect(function(countdown, mode)
            if countdown == 0 and mode then
                Util.resetRound()
                State.mode = mode == "PvP" and "Team" or mode

                Util.log("Mode: " .. State.mode)
                Util.setUI("song", "Waiting for song...")

            elseif countdown == -1 then
                State.canAnswer = false
                State.choices = {}
                State.chaosSongName = ""
            end
        end)
    end
end

---------------------------------------------------------------------
-- 13. Done
---------------------------------------------------------------------
Notify("Zyzen", "Loaded successfully!", "Success")
getgenv().Fluent = Fluent

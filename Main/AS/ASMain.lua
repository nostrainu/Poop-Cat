--// Initialization
local now = tick()
if _G.UILoaded and (now - (_G.LastUILoadTime or 0)) < 5 then
    return
end

_G.UILoaded = true
_G.LastUILoadTime = now

if getgenv().uiActive then
    getgenv().uiActive = false
    task.wait(0.5)
end
if getgenv().uiUpd then
    pcall(function() getgenv().uiUpd:Unload() end)
end

getgenv().isStartup = true

--// Worker Check
local isWorker = getgenv().Automation == true or getgenv().Automitation == true

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if not isWorker and (not getgenv().Host or getgenv().Host == "") then
    getgenv().Host = LocalPlayer.Name
end

if isWorker then
    pcall(getgenv().runWorker)
    return
end

--// Load Library & Check Access
local repo = "https://raw.githubusercontent.com/nostrainu/ObsidianFork/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

getgenv().Library = Library
getgenv().uiUpd = Library
getgenv().uiActive = true

--// Check Access First
local hasAccess = false
if getgenv().Key == "bobcatsquadron" then
    hasAccess = true
elseif isfile and isfile("bobcat/games/AS/key.txt") then
    local success, saved = pcall(readfile, "bobcat/games/AS/key.txt")
    if success and saved:gsub("%s+", "") == "bobcatsquadron" then
        hasAccess = true
    end
elseif isfile and isfile("bobcat_key.txt") then
    local success, saved = pcall(readfile, "bobcat_key.txt")
    if success and saved:gsub("%s+", "") == "bobcatsquadron" then
        hasAccess = true
        if makefolder and writefile then
            pcall(makefolder, "bobcat")
            pcall(makefolder, "bobcat/games")
            pcall(makefolder, "bobcat/games/AS")
            pcall(writefile, "bobcat/games/AS/key.txt", "bobcatsquadron")
            pcall(delfile or function() end, "bobcat_key.txt")
        end
    end
end

if not hasAccess then
    Library:CreateKeySystem({
        Title = "BobCat KeySys",
        Key = "bobcatsquadron",
        SavePath = "bobcat/games/AS/key.txt",
        Discord = "https://discord.gg/Gw4nr35pCb",
        Logo = Library.ImageManager.GetAsset("PopCatDonut") or "rbxassetid://0",
        Callback = function()
            task.spawn(function()
                local loadUrl = "https://raw.githubusercontent.com/nostrainu/Poop-Cat/refs/heads/main/Main/AS/ASMain.lua"
                local mainContent = game:HttpGet(loadUrl .. "?t=" .. os.time())
                local main, mainErr = loadstring(mainContent)
                if main then
                    main()
                else
                    warn("ASMain reload failed: " .. tostring(mainErr))
                end
            end)
        end
    })
    return
end

local HttpService = game:GetService("HttpService")

--// Load Config
local path = getgenv().getProfilePath("Main")
local config = {}
if isfile(path) then
    local readSuccess, fileContent = pcall(readfile, path)
    if readSuccess and fileContent then
        local decSuccess, parsed = pcall(HttpService.JSONDecode, HttpService, fileContent)
        if decSuccess and type(parsed) == "table" then
            config = parsed
        end
    end
end
getgenv().config = config
getgenv().activeConfigTable = config
local activeProfile = "Main"
getgenv().activeProfile = activeProfile

config.HostActive = true
getgenv().saveProfile()

pcall(getgenv().startupDiscoverAlts)

local selectedAlts = {}
getgenv().selectedAlts = selectedAlts

local isSyncingUI = false
getgenv().isSyncingUI = isSyncingUI

local savePending = false
local function debouncedSave()
    if savePending then return end
    savePending = true
    task.delay(0.5, function()
        savePending = false
        getgenv().saveActiveProfile()
    end)
end
getgenv().debouncedSave = debouncedSave

local function registerSetting(name, defaultValue)
    return getgenv().registerSetting(name, defaultValue)
end

--// Sync Global Config
local function syncGlobalConfig()
    if getgenv().AccountControl then
        for k in pairs(getgenv().AccountControl) do
            if getgenv()[k] ~= nil then
                getgenv().AccountControl[k] = getgenv()[k]
            end
        end
    end
end
syncGlobalConfig()

local function SyncUI()
    if getgenv().updatingUI then return end
    getgenv().updatingUI = true
    
    pcall(function()
        local activeConfigTable = getgenv().activeConfigTable or getgenv().config or {}
        for key, value in pairs(activeConfigTable) do
            local option = Library.Options and Library.Options[key]
            if option then
                if option.Type == "Dropdown" and option.Multi then
                    if type(value) == "string" then
                        value = { [value] = true }
                    elseif type(value) ~= "table" then
                        value = {}
                    end
                end
                pcall(function()
                    option:SetValue(value)
                end)
            end
            local toggle = Library.Toggles and Library.Toggles[key]
            if toggle then
                pcall(function()
                    toggle:SetValue(value)
                end)
            end
        end
    end)
    
    getgenv().updatingUI = false
end
getgenv().SyncUI = SyncUI

local function loadProfile(profileName)
    activeProfile = profileName
    getgenv().activeProfile = profileName
    local profilePath = getgenv().getProfilePath(profileName)
    
    if profileName == "Main" then
        getgenv().activeConfigTable = getgenv().config
    elseif isfile(profilePath) then
        local data = getgenv().getProfileData(profileName)
        if data then
            getgenv().activeConfigTable = data
        else
            getgenv().activeConfigTable = {}
        end
    else
        getgenv().activeConfigTable = {}
        getgenv().saveActiveProfile()
    end
    
    getgenv().isSyncingUI = true
    SyncUI()
    getgenv().isSyncingUI = false
end
getgenv().AS_LoadProfile = loadProfile

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local lp = game:GetService("Players").LocalPlayer
            if not lp then return end
            
            local hostStats = {
                Coins = getgenv().getInventoryTotal("Yen") or 0,
                Gems = getgenv().getInventoryTotal("Gems") or 0,
                PerfectCubes = getgenv().getInventoryTotal("Perfect Cubes") or 0,
                RerollCubes = getgenv().getInventoryTotal("Reroll Cubes") or 0,
                TraitShards = getgenv().getInventoryTotal("Trait Shards") or 0,
                LastActive = os.time(),
                Status = "Online"
            }
            
            getgenv().writeProfileData(lp.Name, hostStats)
        end)
    end
end)

--// Load Macro
local Macro = getgenv().Macro

if not Macro then
    getfenv()["wa" .. "rn"]("[Anime Squadron ASMain] Macro is nil in getgenv()!")
    error("[Anime Squadron] ASFunc.lua failed to load before ASMain.lua")
end

local Loading = Library:CreateLoading({
    Title = "Poop-Cat",
    Icon = "loader-2",
    CurrentStep = 0,
    TotalSteps = 3,
    ShowSidebar = true,
})

--// Window Setup
local Window = Library:CreateWindow({
    Title = "Pop-cat",
    Footer = "Anime Squadron",
    MobileButtonsSide = "Left",
    ShowMobileButtons = true,
    NotifySide = "Right",
    Center = true,
    SideBarText = false,
    ScrollLongText = true,
    Size = Library.IsMobile and UDim2.fromOffset(470, 380) or UDim2.fromOffset(570, 450),
    DisableFloatingMenu = registerSetting("DisableFloatingMenu", false)
})

task.wait(0.2)
Loading:SetCurrentStep(3)
Loading:Destroy()

--// Tabs Setup
Window:AddTabSection("Main Features")
local Tabs = {
    --// Main Tab
    Main = Window:AddTab("Main", "layers-2"),

    --// Macro Tab
    Macro = Window:AddTab("Macro", "video"),

    --// Map Rotation
    Rotation = Window:AddTab("Map Rotation", "refresh-cw"),

    --// Miscellaneous Tab
    Misc = Window:AddTab("Miscellaneous", "book"),

    --// Webhook Tab
    Webhook = Window:AddTab("Webhook", "external-link")
}

--// Main Tab
local MainGroupBox = Tabs.Main:AddLeftGroupbox({
    Name = "Join Room",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local findWorldsModule = getgenv().findWorldsModule
local updateMapModeLevelDropdowns = getgenv().updateMapModeLevelDropdowns

local mapValues = getgenv().initialMapValues or {"GT City", "Marine Lobby", "Ninja Village", "Katakura Wasteland", "Eclipse (Before)", "Cosmic Throne Hall"}
local modeValues = getgenv().initialModeValues or {"Story", "Squadron", "Raid", "Event"}
local difficultyValues = getgenv().initialDifficultyValues or {"Normal", "Hard"}
local levelValues = getgenv().initialLevelValues or {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}
local webhookItemValues = getgenv().initialWebhookItems or {
    "Yen", "Gems", "Perfect Cubes", "Reroll Cubes", "Trait Shards",
    "Beastblood Catalyst", "Binding Cloth", "Bounty Tickets", "Chakra Fragment",
    "Currentbinder Rope", "Depthglass Bottle", "Eclipse Godstone", "Fuin Script Paper",
    "Genjutsu Fog Vial", "Hogyoku", "Ki Resonant Crystal", "Limitbreak Obsidian",
    "Meat", "Narutomaki", "Ninja Headband", "Omega Chest", "Omega Coins",
    "Garu", "Baras", "Berserker"
}

MainGroupBox:AddDropdown("SelectedMap", {
    Text = "Select Map",
    Values = mapValues,
    Multi = false,
    Default = registerSetting("SelectedMap"),
    Callback = function(val)
        setConfig("SelectedMap", val)
        updateMapModeLevelDropdowns()
    end
})

MainGroupBox:AddDropdown("SelectedMode", {
    Text = "Select Mode",
    Values = modeValues,
    Multi = false,
    Default = registerSetting("SelectedMode"),
    Callback = function(val)
        setConfig("SelectedMode", val)
        updateMapModeLevelDropdowns()
    end
})

MainGroupBox:AddDropdown("SelectedDifficulty", {
    Text = "Select Difficulty",
    Values = difficultyValues,
    Multi = false,
    Default = registerSetting("SelectedDifficulty"),
    Callback = function(val)
        setConfig("SelectedDifficulty", val)
        updateMapModeLevelDropdowns()
    end
})

MainGroupBox:AddDropdown("SelectedLevel", {
    Text = "Select Level",
    Values = levelValues,
    Multi = false,
    Default = registerSetting("SelectedLevel"),
    Callback = function(val)
        setConfig("SelectedLevel", val)
        updateMapModeLevelDropdowns()
    end
})
MainGroupBox:AddDivider()

MainGroupBox:AddSlider("JoinDelay", {
    Text = "Join Delay",
    Default = registerSetting("JoinDelay", 3),
    Min = 1, Max = 15, Rounding = 0,
    Suffix = "s",
    Callback = function(val) setConfig("JoinDelay", val) end
})

MainGroupBox:AddToggle("AutoJoin", {
    Text = "Auto Join",
    Default = registerSetting("AutoJoin", false),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("AutoJoin", val)
        if val then
            setConfig("AutoChallenge", false)
            setConfig("AutoRaid", false)
            if Library.Toggles.MapRotation then
                Library.Toggles.MapRotation:SetValue(false)
            end
            SyncUI()
        end
    end
})

MainGroupBox:AddToggle("FindMatch", {
    Text = "Find Match",
    Default = registerSetting("FindMatch", false),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("FindMatch", val)
    end
})

--// Joiner Tab
local JoinerGroupBox = Tabs.Main:AddLeftGroupbox({
    Name = "Joiner",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

JoinerGroupBox:AddDropdown("JoinPlayer", {
    Text = "Join Player",
    Values = {},
    Multi = false,
    Default = registerSetting("JoinPlayer", ""),
    Callback = function(val)
        local ok, err = pcall(function()
            val = val or ""
            setConfig("JoinPlayer", val)
            local ply = Players:FindFirstChild(val)
            if ply then
                setConfig("JoinPlayerID", tostring(ply.UserId))
            else
                setConfig("JoinPlayerID", "")
            end
        end)
        if not ok then
            warn("[JoinPlayer Callback Error] ", tostring(err))
        end
    end
})

JoinerGroupBox:AddDropdown("WaitForPlayer", {
    Text = "Wait For Player",
    Values = {},
    Multi = true,
    Default = registerSetting("WaitForPlayer", {}),
    Callback = function(val)
        local ok, err = pcall(function()
            val = val or {}
            setConfig("WaitForPlayer", val)
            setConfig("WaitForPlayerID", "")
        end)
        if not ok then
            warn("[WaitForPlayer Callback Error] ", tostring(err))
        end
    end
})

task.spawn(function()
    while getgenv().uiActive ~= false do
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name ~= LocalPlayer.Name then
                table.insert(list, p.Name)
            end
        end
        table.sort(list)
        pcall(function()
            if Library.Options and Library.Options.JoinPlayer then
                Library.Options.JoinPlayer:SetValues(list)
            end
            if Library.Options and Library.Options.WaitForPlayer then
                Library.Options.WaitForPlayer:SetValues(list)
            end
        end)
        task.wait(2)
    end
end)

JoinerGroupBox:AddSlider("JoinerDelay", {
    Text = "Join Delay",
    Default = registerSetting("JoinerDelay", 3),
    Min = 1, Max = 15, Rounding = 0,
    Suffix = "s",
    Callback = function(val) setConfig("JoinerDelay", val) end
})

JoinerGroupBox:AddToggle("AutoJoiner", {
    Text = "Auto Joiner",
    Default = registerSetting("AutoJoiner", false),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("AutoJoiner", val)
        if val then
            setConfig("AutoJoin", false)
            setConfig("AutoChallenge", false)
            setConfig("AutoRaid", false)
            if Library.Toggles.MapRotation then
                Library.Toggles.MapRotation:SetValue(false)
            end
            SyncUI()
        end
    end
})

local ChallengeGroupBox = Tabs.Main:AddRightGroupbox({
    Name = "Challenge",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local ChallengeInfoLabel = ChallengeGroupBox:AddLabel("Loading challenge data...", true)
getgenv().ChallengeInfoLabel = ChallengeInfoLabel

ChallengeGroupBox:AddDropdown("ChallengeType", {
    Text = "Challenge Type",
    Values = {"30m", "1d", "Katakara Bridge", "The Hero Hunter"},
    Multi = true,
    Default = registerSetting("ChallengeType", { ["30m"] = true, ["1d"] = true }),
    Callback = function(val) setConfig("ChallengeType", val) end
})

ChallengeGroupBox:AddDropdown("ChallengeRewardFilter", {
    Text = "Required Reward Filter",
    Values = {"Trait Shards", "Perfect Cubes", "Reroll Cubes", "Gems"},
    Multi = true,
    Default = registerSetting("ChallengeRewardFilter", {}),
    Callback = function(val) setConfig("ChallengeRewardFilter", val) end
})

ChallengeGroupBox:AddSlider("ChallengeDelay", {
    Text = "Challenge Join Delay",
    Default = registerSetting("ChallengeDelay", 3),
    Min = 1, Max = 15, Rounding = 0,
    Suffix = "s",
    Callback = function(val) setConfig("ChallengeDelay", val) end
})

ChallengeGroupBox:AddToggle("AutoChallenge", {
    Text = "Auto Challenge",
    Default = registerSetting("AutoChallenge", false),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("AutoChallenge", val)
        if val then
            setConfig("AutoJoin", false)
            setConfig("AutoRaid", false)
            if Library.Toggles.MapRotation then
                Library.Toggles.MapRotation:SetValue(false)
            end
            SyncUI()
        end
    end
})

--// Miscellaneous Tab
local MiscGroupBox = Tabs.Misc:AddLeftGroupbox({
    Name = "Summon",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

MiscGroupBox:AddDropdown("SummonBanner", {
    Text = "Select Banner",
    Values = {"Basic Banner", "Selection Banner"},
    Multi = false,
    Default = registerSetting("SummonBanner", "Basic Banner"),
    Callback = function(val) setConfig("SummonBanner", val) end
})

MiscGroupBox:AddDropdown("SummonAmount", {
    Text = "Summon Amount",
    Values = {"1", "10"},
    Multi = false,
    Default = registerSetting("SummonAmount", "10"),
    Callback = function(val) setConfig("SummonAmount", val) end
})

MiscGroupBox:AddToggle("AutoSummon", {
    Text = "Auto Summon",
    Default = registerSetting("AutoSummon", false),
    Callback = function(val) setConfig("AutoSummon", val) end
})

MiscGroupBox:AddDivider()

MiscGroupBox:AddToggle("AutoRedeemCodes", {
    Text = "Auto Redeem Codes",
    Default = registerSetting("AutoRedeemCodes", false),
    Callback = function(val)
        setConfig("AutoRedeemCodes", val)
    end
})

local MapRotationTabbox = Tabs.Rotation:AddMiddleTabbox({
    Name = "Map Rotation",
    Collapsible = true,
    Center = true,
    DefaultCollapsed = false
})

local MapSettings = MapRotationTabbox:AddTab("Map Priority")
local MapTab = MapRotationTabbox:AddTab("Map Selection")

local function updatePriorityMapDropdown(i)
    local modeOption = Library.Options["Priority" .. i]
    local mapOption = Library.Options["Priority" .. i .. "Map"]
    if not modeOption or not mapOption then return end

    local currentMode = modeOption.Value
    local currentMap = mapOption.Value

    local allowedMaps = getMapsForMode(currentMode)
    mapOption:SetValues(allowedMaps)

    if not table.find(allowedMaps, currentMap) then
        local newMap = allowedMaps[1] or ""
        mapOption:SetValue(newMap)
        setConfig("Priority" .. i .. "Map", newMap)
    end
end

MapSettings:AddDropdown("Priority1", {
    Text = "Priority 1",
    Values = {"None", "Story", "Squadron", "Raid", "Challenge"},
    Default = registerSetting("Priority1", "Story"),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("Priority1", val)
        updatePriorityMapDropdown(1)
        if getgenv().config.MapRotation and getgenv().initMapRotation then
            getgenv().initMapRotation()
        end
    end
})

MapSettings:AddDropdown("Priority2", {
    Text = "Priority 2",
    Values = {"None", "Story", "Squadron", "Raid", "Challenge"},
    Default = registerSetting("Priority2", "Story"),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("Priority2", val)
        updatePriorityMapDropdown(2)
        if getgenv().config.MapRotation and getgenv().initMapRotation then
            getgenv().initMapRotation()
        end
    end
})

MapSettings:AddDropdown("Priority3", {
    Text = "Priority 3",
    Values = {"None", "Story", "Squadron", "Raid", "Challenge"},
    Default = registerSetting("Priority3", "Squadron"),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("Priority3", val)
        updatePriorityMapDropdown(3)
        if getgenv().config.MapRotation and getgenv().initMapRotation then
            getgenv().initMapRotation()
        end
    end
})

MapSettings:AddSlider("PriorityRunsLimit", {
    Text = "Runs Per Mode",
    Default = registerSetting("PriorityRunsLimit", 5),
    Min = 1, Max = 50, Rounding = 0,
    Suffix = " run(s)",
    Callback = function(val) setConfig("PriorityRunsLimit", val) end
})

MapSettings:AddSlider("PriorityJoinDelay", {
    Text = "Cycle Join Delay",
    Default = registerSetting("PriorityJoinDelay", 5),
    Min = 1, Max = 15, Rounding = 0,
    Suffix = "s",
    Callback = function(val) setConfig("PriorityJoinDelay", val) end
})

MapSettings:AddToggle("MapRotation", {
    Text = "Auto Map Rotation",
    Default = registerSetting("MapRotation", false),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("MapRotation", val)
        if val then
            if not getgenv().isStartup then
                getgenv().CurrentPriorityIndex = 1
                setConfig("CurrentPriorityIndex", 1)
                getgenv().CurrentModeRuns = 0
                setConfig("CurrentModeRuns", 0)
                getgenv().SessionRuns = 0
            end
            if Library.Toggles.AutoJoin then
                Library.Toggles.AutoJoin:SetValue(false)
            else
                setConfig("AutoJoin", false)
            end
            if Library.Toggles.AutoChallenge then
                Library.Toggles.AutoChallenge:SetValue(false)
            else
                setConfig("AutoChallenge", false)
            end
            setConfig("AutoRaid", false)
            if getgenv().initMapRotation then
                getgenv().initMapRotation()
            end
        else
            if getgenv().initMapRotation then
                getgenv().initMapRotation()
            end
        end
        if getgenv().SyncUI then
            getgenv().SyncUI()
        end
    end
})

for i = 1, 3 do
    MapTab:AddLabel({ Text = "Priority " .. i .. " Settings", DoesWrap = true })
    MapTab:AddDropdown("Priority" .. i .. "Map", {
        Text = "Map",
        Values = mapValues,
        Default = registerSetting("Priority" .. i .. "Map", "GT City"),
        Callback = function(val) setConfig("Priority" .. i .. "Map", val) end
    })
    MapTab:AddDropdown("Priority" .. i .. "Difficulty", {
        Text = "Difficulty",
        Values = difficultyValues,
        Default = registerSetting("Priority" .. i .. "Difficulty", "Normal"),
        Callback = function(val) setConfig("Priority" .. i .. "Difficulty", val) end
    })
    MapTab:AddDropdown("Priority" .. i .. "Level", {
        Text = "Level",
        Values = levelValues,
        Default = registerSetting("Priority" .. i .. "Level", "1"),
        Callback = function(val) setConfig("Priority" .. i .. "Level", val) end
    })

    if i < 3 then
        MapTab:AddDivider()
    end

    task.spawn(function()
        task.wait(0.2)
        updatePriorityMapDropdown(i)
    end)
end

local WebhookGroupBox = Tabs.Webhook:AddLeftGroupbox({
    Name = "Webhook Settings",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

WebhookGroupBox:AddInput("WebhookURL", {
    Text = "Webhook URL",
    Default = registerSetting("WebhookURL", ""),
    Placeholder = "Enter Discord Webhook URL...",
    Callback = function(val) setConfig("WebhookURL", val) end
})

WebhookGroupBox:AddToggle("AutoChallengeWebhook", {
    Text = "Send Match Webhooks",
    Default = registerSetting("AutoChallengeWebhook", false),
    Callback = function(val) setConfig("AutoChallengeWebhook", val) end
})

WebhookGroupBox:AddToggle("PingSecretUnit", {
    Text = "Ping on Secret Unit",
    Default = registerSetting("PingSecretUnit", false),
    Callback = function(val) setConfig("PingSecretUnit", val) end
})

WebhookGroupBox:AddInput("DiscordUserID", {
    Text = "Discord User ID",
    Default = registerSetting("DiscordUserID", ""),
    Placeholder = "Enter Discord User ID for pings...",
    Callback = function(val) setConfig("DiscordUserID", val) end
})

WebhookGroupBox:AddDropdown("WebhookItems", {
    Text = "Show Items in Webhook",
    Values = webhookItemValues,
    Multi = true,
    Default = registerSetting("WebhookItems", { ["Yen"] = true, ["Gems"] = true, ["Perfect Cubes"] = true, ["Reroll Cubes"] = true }),
    Callback = function(val) setConfig("WebhookItems", val) end
})

WebhookGroupBox:AddButton("Test Webhook", function()
    local url = Library.Options.WebhookURL and Library.Options.WebhookURL.Value or ""
    if url == "" or not url:find("discord.com") then
        Library:Notify("Invalid Discord Webhook URL!", 3)
        return
    end
    
    local fields = { { name = "Status", value = "Online / Working", inline = true } }
    pcall(function()
        local getInventoryTotal = getgenv().getInventoryTotal
        local formatNumber = getgenv().formatNumber
        if getInventoryTotal and formatNumber then
            local selected = getgenv().config and getgenv().config.WebhookItems or { ["Yen"] = true, ["Gems"] = true, ["Perfect Cubes"] = true, ["Reroll Cubes"] = true }
            local order = getgenv().initialWebhookItems or { "Yen", "Gems", "Perfect Cubes", "Reroll Cubes", "Trait Shards" }
            local statsList = {}
            local processed = {}
            for _, name in ipairs(order) do
                processed[name] = true
                if selected[name] then
                    local val = getInventoryTotal(name) or 0
                    table.insert(statsList, string.format("- **%s:** %s", name, formatNumber(val)))
                end
            end
            for name, isSelected in pairs(selected) do
                if isSelected and not processed[name] then
                    local val = getInventoryTotal(name) or 0
                    table.insert(statsList, string.format("- **%s:** %s", name, formatNumber(val)))
                end
            end
            if #statsList > 0 then
                table.insert(fields, { name = "Player Data (Selected)", value = table.concat(statsList, "\n"), inline = false })
            end
        end
    end)
    
    pcall(function()
        local getgenv = getgenv
        if getgenv().sendDiscordWebhook then
            getgenv().sendDiscordWebhook(
                "Test Webhook",
                "Your Anime Squadron script webhook is configured correctly!",
                fields
            )
            Library:Notify("Test Webhook sent!", 3)
        else
            Library:Notify("Webhook function not loaded!", 3)
        end
    end)
end)

local MacroStatus

--// Macro Tab
local RecorderBox = Tabs.Macro:AddLeftGroupbox({
    Name = "Record",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

MacroStatus = RecorderBox:AddMacroStatus("MacroStatus")

local dummyLabel = {
    SetText = function() end,
    SetVisible = function() end,
}
Macro.StatusLabel = MacroStatus
Macro.SpaceLabel = dummyLabel
Macro.ActionLabel = dummyLabel
Macro.NextLabel = dummyLabel

RecorderBox:AddDivider()

RecorderBox:AddSlider("MacroDelay", {
    Text = "Delay",
    Default = registerSetting("MacroDelay", 0.2),
    Min = 0.2, Max = 1, Rounding = 1,
    Suffix = "x",
    Callback = function(val) setConfig("MacroDelay", val) end
})


RecorderBox:AddToggle("MacroRecord", {
    Text = "Record Macro",
    Default = registerSetting("MacroRecord", false),
    Callback = function(val)
        setConfig("MacroRecord", val)
        local selected = (Library.Options and Library.Options.MacroSelect) and Library.Options.MacroSelect.Value or ""
        if val then
            if Library.Toggles.MacroPlay and Library.Toggles.MacroPlay.Value then
                Library.Toggles.MacroPlay:SetValue(false)
            end
            if Macro.IsPlaying then
                task.spawn(function() Library.Toggles.MacroRecord:SetValue(false) end)
                return
            end
            if selected == "" or selected == "---" then
                task.spawn(function() Library.Toggles.MacroRecord:SetValue(false) end)
                return
            end
            local path = "bobcat/games/AS/macros/" .. selected .. ".json"
            if not isfile(path) then
                task.spawn(function() Library.Toggles.MacroRecord:SetValue(false) end)
                return
            end
            if not Macro.IsRecording then
                Macro:StartRecording()
                MacroStatus:Update({ State = "Recording (0 steps)", Current = "Waiting for actions..." })

                Macro.OnRecord = function(stepNum, actionType, args, cost)
                    local label = getLabelText(actionType)
                    local unitName = Macro:ResolveName(args[1])
                    if cost and cost > 0 then
                        unitName = string.format("%s | ¥ %d", unitName, cost)
                    end
                    MacroStatus:Update({
                        State = string.format("Recording (%d steps)", stepNum),
                        Current = string.format("%s - %s", label, unitName),
                    })
                end
            end
        else
            if Macro.IsRecording then
                Macro:StopRecording()
                if selected ~= "" and selected ~= "---" and isfile("bobcat/games/AS/macros/" .. selected .. ".json") then
                    Macro:SaveMacro(selected)
                    if Library.Options.MacroSelect then
                        Library.Options.MacroSelect:SetValues(Macro:GetMacroList())
                    end
                end
            end
            local statusText = getgenv().MacroStatus or ("Stopped - " .. #Macro.Recording .. " steps")
            MacroStatus:Update({ State = statusText })
            getgenv().MacroStatus = nil
        end
    end
})

RecorderBox:AddToggle("MacroPlay", {
    Text = "Play Macro",
    Default = registerSetting("MacroPlay", false),
    Callback = function(val)
        setConfig("MacroPlay", val)
        if val then
            Macro.HasPlayedThisMatch = false
            if Library.Toggles.MacroRecord and Library.Toggles.MacroRecord.Value then
                Library.Toggles.MacroRecord:SetValue(false)
            end
            if Macro.IsRecording then
                Macro:StopRecording()
            end
            if #Macro.Recording == 0 then
                if not getgenv().isStartup then
                    task.spawn(function() Library.Toggles.MacroPlay:SetValue(false) end)
                end
                MacroStatus:Update({ State = "Idle" })
                return
            end
            local inLobby = getgenv().isInLobby and getgenv().isInLobby()
            if not inLobby and not getgenv().isStartup then
                Macro:StartPlayback()
            end
        else
            if Macro.IsPlaying then
                Macro:Stop()
            end
            local statusText = getgenv().MacroStatus or "Stopped"
            MacroStatus:Update({ State = statusText })
            getgenv().MacroStatus = nil
        end
    end
})

RecorderBox:AddToggle("AutoReplay", {
    Text = "Auto Replay",
    Default = registerSetting("AutoReplay", false),
    Callback = function(val)
        setConfig("AutoReplay", val)
        if val then
            local inLobby = getgenv().isInLobby and getgenv().isInLobby()
            local isMid = getgenv().isMidGame and getgenv().isMidGame()
            if not inLobby and isMid == false then
                pcall(function()
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("replay"):FireServer()
                end)
            end
        end
    end
})

RecorderBox:AddToggle("AutoNext", {
    Text = "Auto Next",
    Default = registerSetting("AutoNext", false),
    Callback = function(val)
        setConfig("AutoNext", val)
        if val then
            local inLobby = getgenv().isInLobby and getgenv().isInLobby()
            local isMid = getgenv().isMidGame and getgenv().isMidGame()
            if not inLobby and isMid == false then
                pcall(function()
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("next"):FireServer()
                end)
            end
        end
    end
})

RecorderBox:AddDivider()

RecorderBox:AddDropdown("AutoSpeed", {
    Text = "Speed Value",
    Values = {"1", "2", "3"},
    Default = registerSetting("AutoSpeed", "2"),
    Callback = function(val)
        setConfig("AutoSpeed", val)
        local speedVal = tonumber(val)
        if speedVal then
            pcall(function()
                ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("change_speed"):InvokeServer(speedVal)
            end)
        end
    end
})

RecorderBox:AddToggle("AutoSpeedToggle", {
    Text = "Auto Speed Change",
    Default = registerSetting("AutoSpeedToggle", false),
    Callback = function(val) setConfig("AutoSpeedToggle", val) end
})


--// Saved Macros Group
local MacroBox = Tabs.Macro:AddRightGroupbox({
    Name = "Macros",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

MacroBox:AddInput("MacroName", {
    Text = "Macro Name",
    Default = "",
    Placeholder = "Enter name...",
})

MacroBox:AddButton("Create Macro", function()
    local name = Library.Options.MacroName and Library.Options.MacroName.Value or ""
    if name == "" then
        return
    end
    local temp = Macro.Recording
    Macro.Recording = {}
    local ok = Macro:SaveMacro(name)
    if ok then
        if Library.Options.MacroSelect then
            Library.Options.MacroSelect:SetValues(Macro:GetMacroList())
            Library.Options.MacroSelect:SetValue(name)
        end
    else
        Macro.Recording = temp
    end
end)

MacroBox:AddDivider()

MacroBox:AddDropdown("MacroSelect", {
    Text = "Saved Macros",
    Values = Macro:GetMacroList(),
    Default = registerSetting("MacroSelect", ""),
    Callback = function(val)
        setConfig("MacroSelect", val)
        if Macro:LoadMacro(val) then
            MacroStatus:Update({ State = "Loaded: " .. val .. " - " .. #Macro.Recording .. " steps" })
            if not getgenv().isStartup and getgenv().config.AutoEquipUnits and val ~= "" and val ~= "---" and (not getgenv().isInLobby or getgenv().isInLobby()) then
                task.spawn(function()
                    local ok, msg = getgenv().equipMacroUnits(val)
                    if ok and msg and msg ~= "" then
                        Library:Notify(msg, 5)
                    end
                end)
            end
        end
    end
})

MacroBox:AddToggle("AutoEquipUnits", {
    Text = "Auto Equip Units",
    Default = registerSetting("AutoEquipUnits", false),
    Callback = function(val) setConfig("AutoEquipUnits", val) end
})

MacroBox:AddButton("Delete Selected", function()
    local selected = Library.Options.MacroSelect and Library.Options.MacroSelect.Value
    if not selected or selected == "" or selected == "---" then
        return
    end
    
    local Dialog = Window:AddDialog("DeletePrompt", {
        Title = "Delete Macro",
        Description = "Are you sure you want to delete '" .. selected .. "'?",
        AutoDismiss = true,
        OutsideClickDismiss = true,
    })
    Dialog:AddFooterButton("YesButton", {
        Title = "Yes",
        Text = "Yes",
        Callback = function()
            if Macro:DeleteMacro(selected) then
                Macro.Recording = {}
                MacroStatus:Update({ State = "Idle" })
                Library.Options.MacroSelect:SetValues(Macro:GetMacroList())
                Library.Options.MacroSelect:SetValue(nil)
            end
            Dialog:Dismiss()
        end
    })
    Dialog:AddFooterButton("NoButton", {
        Title = "Cancel",
        Text = "Cancel",
        Callback = function()
            Dialog:Dismiss()
        end
    })
    Dialog:Resize()
end)

MacroBox:AddButton("Refresh List", function()
    Library.Options.MacroSelect:SetValues(Macro:GetMacroList())
end)

getgenv().refreshMacroDropdown = function()
    if Library.Options.MacroSelect then
        Library.Options.MacroSelect:SetValues(Macro:GetMacroList())
    end
end

MacroBox:AddInput("ImportMacroData", {
    Text = "Import Macro (URL or JSON)",
    Default = "",
    Placeholder = "Paste raw JSON or Discord URL...",
})

MacroBox:AddButton("Import Macro", function()
    local customName = Library.Options.MacroName and Library.Options.MacroName.Value or ""
    if customName == "" then
        Library:Notify("Please enter a Macro Name first!", 3)
        return
    end
    local inputVal = Library.Options.ImportMacroData and Library.Options.ImportMacroData.Value or ""
    if inputVal == "" then
        Library:Notify("Please enter a valid URL or JSON data.", 3)
        return
    end
    local ok, nameOrErr = getgenv().importMacroFromURL(inputVal, customName)
    if ok then
        Library:Notify("Macro successfully imported as: " .. nameOrErr, 5)
        if Library.Options.MacroSelect then
            Library.Options.MacroSelect:SetValue(nameOrErr)
        end
        if Library.Options.MacroName then
            Library.Options.MacroName:SetValue(nameOrErr)
        end
        if Library.Options.ImportMacroData then
            Library.Options.ImportMacroData:SetValue("")
        end
    else
        Library:Notify("Import failed: " .. tostring(nameOrErr), 5)
    end
end)

MacroBox:AddButton("Export Macro", function()
    local selected = Library.Options.MacroSelect and Library.Options.MacroSelect.Value
    if not selected or selected == "" or selected == "---" then
        Library:Notify("Please select a macro first.", 3)
        return
    end
    
    local ok, err = getgenv().exportMacroWebhook(selected)
    if ok then
        Library:Notify("Macro successfully exported via Webhook!", 3)
    else
        Library:Notify("Export failed: " .. tostring(err), 5)
    end
end)

MacroBox:AddDivider()

MacroBox:AddButton("Check Macro Units", function()
    local selected = Library.Options.MacroSelect and Library.Options.MacroSelect.Value
    if not selected or selected == "" or selected == "---" then
        Library:Notify("Please select a macro first.", 3)
        return
    end
    
    local units, err = getgenv().getMacroRequiredUnits(selected)
    if not units then
        Library:Notify("Failed to analyze macro: " .. tostring(err), 5)
        return
    end
    
    if #units == 0 then
        Library:Notify("No units found in this macro.", 5)
    else
        local text = "Units used in macro:\n" .. table.concat(units, "\n")
        Library:Notify(text, 10)
    end
end)

MacroBox:AddButton("Equip Macro Units", function()
    local selected = Library.Options.MacroSelect and Library.Options.MacroSelect.Value
    if not selected or selected == "" or selected == "---" then
        Library:Notify("Please select a macro first.", 3)
        return
    end
    
    local ok, msg = getgenv().equipMacroUnits(selected)
    if ok and msg and msg ~= "" then
        Library:Notify(msg, 5)
    end
end)

--// Config Tab
local SettingsTab = Window:AddTab({ Name = "Settings", Icon = "settings", Side = "Header", Visible = false })
local InfoTab = Window:AddTab({ Name = "Info", Icon = "info", Side = "SidebarBottom" })

local SettingsGroup = SettingsTab:AddLeftGroupbox("Controls")
SettingsGroup:AddLabel("Toggle UI Bind"):AddKeyPicker("MenuKeybind", {
    Default = "LeftControl",
    NoUI = true,
    Text = "Menu Keybind"
})
Library.ToggleKeybind = Library.Options.MenuKeybind

SettingsGroup:AddDivider()

SettingsGroup:AddToggle("DisableFloatingMenu", {
    Text = "Disable Floating",
    Default = registerSetting("DisableFloatingMenu", false),
    Callback = function(val)
        setConfig("DisableFloatingMenu", val)
        Library.DisableFloatingMenu = val
    end
})

SettingsGroup:AddToggle("AutoReconnect", {
    Text = "Auto Reconnect",
    Default = registerSetting("AutoReconnect", false),
    Callback = function(val) setConfig("AutoReconnect", val) end
})

SettingsGroup:AddToggle("AutoExecute", {
    Text = "Auto Execute",
    Default = registerSetting("AutoExecute", false),
    Callback = function(val) setConfig("AutoExecute", val) end
})

SettingsGroup:AddButton("Unload", function()
    Library:Unload()
end)

local ProfileGroup = InfoTab:AddMiddleGroupbox({
    Name = "Profile",
    Center = true
})

local ProfileCard = ProfileGroup:AddProfileCard({
    Role = "Premium",
    KeyType = "Lifetime"
})

local DiscordTab = ProfileCard:AddTab({
    Name = "Discord",
    Icon = "message-square"
})
DiscordTab:AddLabel("Join our Discord community for support!")
DiscordTab:AddButton("Copy Invite Link", function()
    pcall(function() setclipboard("https://discord.gg/Gw4nr35pCb") end)
end)

local ShopTab = ProfileCard:AddTab({
    Name = "Shop",
    Icon = "shopping-cart"
})
ShopTab:AddLabel("Purchase lifetime access & features!")
ShopTab:AddButton("Copy Shop URL", function()
    pcall(function() setclipboard("https://bobcat-hub.mysellix.io") end)
end)

--// Game Tab
local GameTab = ProfileCard:AddTab({
    Name = "Game",
    Icon = "gamepad-2"
})

GameTab:AddGameInfo()

--// Accounts Tab
local AccountsTab = ProfileCard:AddTab({
    Name = "Accounts",
    Icon = "users"
})
if type(config.Accounts) ~= "table" then
    config.Accounts = {}
    getgenv().saveProfile()
end

AccountsTab:AddLabel("Account Control")

local altList = AccountsTab:AddAltList("AltAccountsList", {
    Accounts = config.Accounts,
    SelectedAlts = selectedAlts,
    Searchable = true,
    StatusOrder = { "Online", "Farming", "Waiting", "Paused", "No Script" },
    StatusColors = {
        Farming = Color3.fromRGB(240, 200, 0),
        Waiting = Color3.fromRGB(0, 180, 240),
        Paused = Color3.fromRGB(150, 150, 150),
        Idle = Color3.fromRGB(150, 150, 150),
        Online = Color3.fromRGB(0, 200, 100),
        Offline = Color3.fromRGB(240, 70, 70),
        ["No Script"] = Color3.fromRGB(240, 70, 70)
    },
    OnToggle = function(alt, isSelected)
        if isSelected then
            selectedAlts[alt.Name] = true
            if not getgenv().AS_BulkSelectActive then
                loadProfile(alt.Name)
            end
        else
            selectedAlts[alt.Name] = nil
            if not getgenv().AS_BulkSelectActive then
                if activeProfile == alt.Name then
                    local nextActive = "Main"
                    for otherAltName, otherIsSelected in pairs(selectedAlts) do
                        if otherIsSelected and otherAltName ~= alt.Name then
                            nextActive = otherAltName
                            break
                        end
                    end
                    loadProfile(nextActive)
                end
            end
        end
    end,
    OnCopyID = function(alt)
        pcall(function() setclipboard(tostring(alt.Id)) end)
    end,
    OnDelete = function(alt, confirmDelete)
        local dialog = Window:AddDialog("ConfirmRemove", {
            Title = "Remove Alt Account",
            Description = "Are you sure you want to remove " .. alt.Name .. "?",
            AutoDismiss = true,
            OutsideClickDismiss = true,
            FooterButtons = {
                {
                    Id = "Confirm",
                    Title = "Yes",
                    Variant = "Destructive",
                    Callback = function()
                        for i, a in ipairs(config.Accounts) do
                            if a.Name == alt.Name then
                                table.remove(config.Accounts, i)
                                break
                            end
                        end
                        getgenv().saveProfile()
                        
                        local altPath = getgenv().getProfilePath(alt.Name)
                        pcall(delfile, altPath)
                        
                        if activeProfile == alt.Name then
                            loadProfile("Main")
                        end
                        
                        if confirmDelete then
                            confirmDelete()
                        end
                    end
                },
                {
                    Id = "Cancel",
                    Title = "No",
                    Variant = "Secondary",
                    Callback = function()
                    end
                }
            }
        })
        return dialog
    end,
    OnPause = function(alt, explicitState)
        local parsed = getgenv().getProfileData(alt.Name)
        if parsed then
            if explicitState ~= nil then
                if explicitState then
                    parsed.Status = "Paused"
                else
                    local isFarming = parsed.AutoJoin or parsed.AutoChallenge or parsed.MapRotation or parsed.AutoSummon
                    parsed.Status = isFarming and "Working" or "Waiting"
                end
            else
                if parsed.Status == "Paused" then
                    local isFarming = parsed.AutoJoin or parsed.AutoChallenge or parsed.MapRotation or parsed.AutoSummon
                    parsed.Status = isFarming and "Working" or "Waiting"
                else
                    parsed.Status = "Paused"
                end
            end
            getgenv().writeProfileData(alt.Name, parsed)
        end
    end,
    OnOpenStats = function(alt)
        local altData = {
            AutoJoin = false,
            AutoChallenge = false,
            MapRotation = false,
            AutoSummon = false,
            Status = "Waiting",
            Coins = 0,
            Gems = 0,
            PerfectCubes = 0,
            RerollCubes = 0,
            TraitShards = 0,
            LastActive = 0
        }
        local isMain = false
        pcall(function()
            local lp = game:GetService("Players").LocalPlayer
            if lp and alt.Name == lp.Name then
                isMain = true
            end
        end)
        local parsed = getgenv().getProfileData(alt.Name)
        if parsed then
            for k, v in pairs(parsed) do
                altData[k] = v
            end
        end
        local dialog = Window:AddDialog("AltStats_" .. alt.Name, {
            Title = "Statistics: " .. alt.Name,
            Description = "View real-time account details and values.",
            AutoDismiss = true,
            OutsideClickDismiss = true,
            FooterButtons = {
                {
                    Id = "Close",
                    Title = "Close",
                    Variant = "Primary"
                }
            }
        })
        local function formatNumber(val)
            if not val then return "0" end
            if val >= 1000000 then
                return string.format("%.2fM", val / 1000000)
            elseif val >= 1000 then
                return string.format("%.2fK", val / 1000)
            else
                return tostring(val)
            end
        end
        local activeStatus = "Offline"
        if isMain then
            activeStatus = "Online"
        else
            local playerInGame = Players:FindFirstChild(alt.Name)
            local isOnline = playerInGame ~= nil
            if isOnline then
                activeStatus = "Online"
            end
            if altData.LastActive and os.time() - altData.LastActive < 15 then
                activeStatus = altData.Status or "Working"
            elseif isOnline then
                activeStatus = "No Script"
            end
        end
        local lastActiveStr = "Unknown"
        if isMain then
            lastActiveStr = "Active now"
        elseif altData.LastActive and altData.LastActive > 0 then
            local diff = os.time() - altData.LastActive
            if diff < 15 then
                lastActiveStr = "Active now"
            elseif diff < 60 then
                lastActiveStr = tostring(diff) .. "s ago"
            elseif diff < 3600 then
                lastActiveStr = tostring(math.floor(diff / 60)) .. "m ago"
            else
                lastActiveStr = tostring(math.floor(diff / 3600)) .. "h ago"
            end
        end
        dialog:AddLabel("Status: " .. activeStatus)
        dialog:AddLabel("Last Active: " .. lastActiveStr)
        dialog:AddLabel("Yen: " .. formatNumber(altData.Coins))
        dialog:AddLabel("Gems: " .. formatNumber(altData.Gems))
        dialog:AddLabel("Perfect Cubes: " .. formatNumber(altData.PerfectCubes))
        dialog:AddLabel("Reroll Cubes: " .. formatNumber(altData.RerollCubes))
        dialog:AddLabel("Trait Shards: " .. formatNumber(altData.TraitShards))
        return dialog
    end,
    OnOfflineAlert = function(alt, status)
        Window:AddDialog("AltOffline_" .. alt.Name, {
            Title = "Account Inactive",
            Description = alt.Name .. " is currently " .. status .. ". Please start the script on this account to control it.",
            AutoDismiss = true,
            OutsideClickDismiss = true,
            FooterButtons = {
                {
                    Id = "Ok",
                    Title = "OK",
                    Variant = "Primary"
                }
            }
        })
    end,
    GetFarmingStatus = function(alt, isOnline)
        local parsed = getgenv().getProfileData(alt.Name)
        if parsed then
            local lastActive = parsed.LastActive or 0
            if os.time() - lastActive < 15 then
                return parsed.Status or "Working", parsed.Status == "Paused"
            end
        end
        return isOnline and "No Script" or "Offline", false
    end,
    GetAccountDetails = function(alt, isMain)
        return ""
    end
})

altList:AddAccount({
    Name = LocalPlayer.Name,
    Id = LocalPlayer.UserId,
}, {
    IsMain = true,
    AllowDelete = false,
    AllowPause = false,
    AllowCopyID = true,
    AllowStats = true
})

AccountsTab:AddToggle("HideIdentity", {
    Text = "Hide Avatar & Name",
    Default = false,
    Callback = function(val)
        if altList and altList.SetHideIdentity then
            altList:SetHideIdentity(val)
        end
    end
})

local function autoDiscoverAlts()
    local mainSuccess, mainErr = pcall(function()
        local host = getgenv().Host
        if not host or host == "" then return end
        
        local folder = "bobcat/games/AS/alts"
        if not isfolder(folder) then return end
        
        local successFiles, files = pcall(listfiles, folder)
        if not successFiles or type(files) ~= "table" then return end
        
        local changed = false
        for _, filePath in ipairs(files) do
            local fileName = string.gsub(filePath, "\\", "/")
            fileName = string.match(fileName, "([^/]+)$") or fileName
            local altName = string.match(fileName, "^" .. host .. "_(.-)%.json$")
            if altName and altName ~= host then
                local exists = false
                for _, alt in ipairs(config.Accounts or {}) do
                    if alt.Name == altName then
                        exists = true
                        break
                    end
                end
                
                if not exists then
                    local userId = "0"
                    pcall(function()
                        if isfile(filePath) then
                            local content = readfile(filePath)
                            local parsed = HttpService:JSONDecode(content)
                            if type(parsed) == "table" and parsed.UserId then
                                userId = tostring(parsed.UserId)
                            end
                        end
                    end)
                    
                    table.insert(config.Accounts, { Name = altName, Id = userId })
                    changed = true
                    if altList and altList.AddAccount then
                        altList:AddAccount({ Name = altName, Id = userId })
                    end
                end
            end
        end
        
        if changed then
            getgenv().saveProfile()
        end
    end)
end

pcall(autoDiscoverAlts)

task.spawn(function()
    while true do
        pcall(autoDiscoverAlts)
        task.wait(3)
    end
end)

SyncUI()
updateMapModeLevelDropdowns()
getgenv().isStartup = false

Library:OnUnload(function()
    getgenv().uiActive = false
    getgenv().uiUpd = nil
    _G.UILoaded = nil
    _G.LastUILoadTime = nil
end)
--// Setup
if getgenv().uiUpd then 
    pcall(getgenv().uiUpd.Unload, getgenv().uiUpd) 
end

if getgenv().GaG2_QueueLoopActive then
    getgenv().GaG2_Queue = {}
else
    getgenv().GaG2_Queue = {}
    getgenv().GaG2_QueueLoopActive = true
    task.spawn(function()
        while getgenv().GaG2_QueueLoopActive do
            local taskItem = table.remove(getgenv().GaG2_Queue, 1)
            if taskItem then
                pcall(taskItem)
            end
            task.wait(0.02)
        end
    end)
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local SharedModules = ReplicatedStorage:WaitForChild("SharedModules", 5)
local Networking, FruitValueCalc
if SharedModules then
    pcall(function()
        Networking = require(SharedModules:WaitForChild("Networking", 2))
    end)
    pcall(function()
        FruitValueCalc = require(SharedModules:WaitForChild("FruitValueCalc", 2))
    end)
end

local isWorker = getgenv().Automation == true or getgenv().Automitation == true

if not isWorker and (not getgenv().Host or getgenv().Host == "") then
    getgenv().Host = LocalPlayer.Name
end

local function calculateInventoryValues()
    return getgenv().calculateInventoryValues()
end

local function getProfilePath(profileName)
    return getgenv().getProfilePath(profileName)
end

local function getProfileData(altName)
    return getgenv().getProfileData(altName)
end

local function writeProfileData(altName, data)
    getgenv().writeProfileData(altName, data)
end

local function saveActiveProfile()
    getgenv().saveActiveProfile()
end

local function save()
    getgenv().saveProfile()
end

local function registerSetting(name, defaultValue)
    return getgenv().registerSetting(name, defaultValue)
end

local function startupDiscoverAlts()
    getgenv().startupDiscoverAlts()
end

if isWorker then
    pcall(getgenv().runWorker)
    return
end

local Library
local repo = "https://raw.githubusercontent.com/nostrainu/ObsidianFork/main/"
Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local path = getProfilePath("Main")
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
getgenv().GaG2Config = config

local activeProfile = "Main"
getgenv().activeProfile = activeProfile

local activeConfigTable = config
getgenv().activeConfigTable = activeConfigTable

config.HostActive = true
save()

pcall(startupDiscoverAlts)

local selectedAlts = {}

local isSyncingUI = false

local savePending = false
local function debouncedSave()
    if savePending then return end
    savePending = true
    task.delay(0.5, function()
        savePending = false
        saveActiveProfile()
    end)
end

local function setConfig(name, val)
    if isSyncingUI then
        if activeProfile == "Main" then
            getgenv()[name] = val
            if getgenv().AccountControl and getgenv().AccountControl[name] ~= nil then
                getgenv().AccountControl[name] = val
            end
        end
        return
    end

    activeConfigTable[name] = val
    debouncedSave()
    
    if activeProfile == "Main" then
        getgenv()[name] = val
        if getgenv().AccountControl and getgenv().AccountControl[name] ~= nil then
            getgenv().AccountControl[name] = val
        end
    end
    
    for altName, isSelected in pairs(selectedAlts) do
        if isSelected then
            local altData = getProfileData(altName) or {}
            altData[name] = val
            local host = getgenv().Host
            if host and host ~= "" then
                altData.Host = host
            end
            writeProfileData(altName, altData)

            if getgenv().BobcatWS and getgenv().BobcatWS.IsConnected() then
                getgenv().BobcatWS.PushSettings(altName, { [name] = val })
            end
        end
    end
end

local defaultSettings = getgenv().GaG2DefaultSettings or {}

for name, defaultValue in pairs(defaultSettings) do
    registerSetting(name, defaultValue)
end

local function syncGlobalConfig()
    if getgenv().AccountControl then
        for k in pairs(getgenv().AccountControl) do
            if getgenv()[k] ~= nil then
                getgenv().AccountControl[k] = getgenv()[k]
            end
        end
    end

    if getgenv().DisableRainbow and getgenv().disableRainbowAnimation then
        task.defer(getgenv().disableRainbowAnimation)
    end
end
syncGlobalConfig()

local function toHex(color)
    local r = math.clamp(math.round(color.R * 255), 0, 255)
    local g = math.clamp(math.round(color.G * 255), 0, 255)
    local b = math.clamp(math.round(color.B * 255), 0, 255)
    return string.format("%02x%02x%02x", r, g, b)
end

local function fromHex(hex)
    if type(hex) ~= "string" then return Color3.new(1, 1, 1) end
    hex = hex:gsub("#", "")
    if #hex < 6 then return Color3.new(1, 1, 1) end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return Color3.fromRGB(r, g, b)
end

local function SyncUI()
    local defaults = getgenv().GaG2DefaultSettings or {}
    for key, defaultValue in pairs(defaults) do
        local opt = Library.Toggles[key] or Library.Options[key]
        if opt then
            local value = activeConfigTable[key]
            if value == nil then
                value = defaultValue
            end
            pcall(function()
                if opt.Type == "ColorPicker" and type(value) == "string" then
                    opt:SetValue(fromHex(value))
                else
                    opt:SetValue(value)
                end
            end)
        end
    end
end

local function loadProfile(profileName)
    activeProfile = profileName
    getgenv().activeProfile = profileName
    local profilePath = getProfilePath(profileName)
    
    if profileName == "Main" then
        activeConfigTable = config
        getgenv().activeConfigTable = config
    elseif isfile(profilePath) then
        local data = getProfileData(profileName)
        if data then
            activeConfigTable = data
            getgenv().activeConfigTable = data
        else
            activeConfigTable = {}
            getgenv().activeConfigTable = {}
        end
    else
        activeConfigTable = {}
        getgenv().activeConfigTable = {}
        saveActiveProfile()
    end
    
    isSyncingUI = true
    SyncUI()
    isSyncingUI = false
end
getgenv().GaG2_LoadProfile = loadProfile

if not isWorker then
    task.spawn(function()
        while task.wait(5) do
            pcall(function()
                local lp = game:GetService("Players").LocalPlayer
                if not lp then return end
                
                local coins = 0
                local stats = lp:FindFirstChild("leaderstats")
                if stats and stats:FindFirstChild("Sheckles") then
                    coins = stats.Sheckles.Value
                end
                
                local stdVal, dailyVal, stockVal = calculateInventoryValues()
                
                local hostStats = {
                    Coins = coins,
                    FruitCount = lp:GetAttribute("FruitCount") or 0,
                    MaxFruitCapacity = lp:GetAttribute("MaxFruitCapacity") or 100,
                    InvValueStandard = stdVal,
                    InvValueDaily = dailyVal,
                    InvValueStock = stockVal,
                    LastActive = os.time(),
                    Status = "Online"
                }
                
                writeProfileData(lp.Name, hostStats)
            end)
        end
    end)
end

local wsStatusCache = {}
getgenv().wsStatusCache = wsStatusCache

local function keysToArray(tbl)
    local arr = {}
    if type(tbl) == "table" then
        for k, v in pairs(tbl) do
            if v then
                table.insert(arr, k)
            end
        end
    end
    return arr
end

local function getWeatherValues()
    return getgenv().getWeatherValues()
end

getgenv().uiActive = true
getgenv().Library = Library
getgenv().uiUpd = Library 

--// Check Access First
local hasAccess = false
if getgenv().Key == "bobcatgag2" then
    hasAccess = true
elseif isfile and isfile("bobcat/keys/bobcatkey.txt") then
    local success, saved = pcall(readfile, "bobcat/keys/bobcatkey.txt")
    if success and saved == "bobcatgag2" then
        hasAccess = true
    end
elseif isfile and isfile("bobcat_key.txt") then
    local success, saved = pcall(readfile, "bobcat_key.txt")
    if success and saved == "bobcatgag2" then
        hasAccess = true
        if makefolder and writefile then
            pcall(makefolder, "bobcat")
            pcall(makefolder, "bobcat/keys")
            pcall(writefile, "bobcat/keys/bobcatkey.txt", "bobcatgag2")
            pcall(delfile or function() end, "bobcat_key.txt")
        end
    end
end

if not hasAccess then
    Library:CreateKeySystem({
        Title = "BobCat KeySys",
        Key = "bobcatgag2",
        SavePath = "bobcat/keys/bobcatkey.txt",
        Discord = "https://discord.gg/6sdWsCy9e",
        Logo = Library.ImageManager.GetAsset("PopCatDonut") or "rbxassetid://0",
        Callback = function()
            task.spawn(function()
                local loadUrl = "https://raw.githubusercontent.com/nostrainu/Poop-Cat/main/Main/GaG2/GaG2Main.lua"
                local mainContent = game:HttpGet(loadUrl .. "?t=" .. os.time())
                local main, mainErr = loadstring(mainContent)
                if main then
                    main()
                else
                    warn("GaG2Main reload failed: " .. tostring(mainErr))
                end
            end)
        end
    })
    return
end

--// UI Window (Loads only if hasAccess == true)
local Loading = Library:CreateLoading({
    Title = "Loading bobcat...",
    Icon = "loader-2",
    CurrentStep = 0,
    TotalSteps = 3,
    ShowSidebar = true,
})

local Window = Library:CreateWindow({
    Title = "Pop-cat",
    Footer = "GaG2",
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

--// Tabs & Groupboxes
Window:AddTabSection("Main Features")
local Tabs = {
    Main = Window:AddTab("Main", "layers-2"),
    Shop = Window:AddTab("Shop", "shopping-cart"),
    ESP = Window:AddTab("ESP", "eye"),
    Misc = Window:AddTab("Misc", "box"),
}

local HarvestTab = Tabs.Main:AddMiddleGroupbox({
    Name = "Harvest Plants",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local SellTab = Tabs.Main:AddLeftGroupbox({
    Name = "Sell Plants",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local StealTab = Tabs.Main:AddRightGroupbox({
    Name = "Steal Plants",
    Collapsible = true,
    Center = true,
    DefaultCollapsed = false
})

local MiscLeft = Tabs.Shop:AddLeftGroupbox({
    Name = "Seed Shop",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local CrateLeft = Tabs.Shop:AddLeftGroupbox({
    Name = "Crate Shop",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local MiscRight = Tabs.Shop:AddRightGroupbox({
    Name = "Gear Shop",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local EspLeftGroup = Tabs.ESP:AddLeftGroupbox({
    Name = "ESP Toggles",
    Center = true
})

local EspRightGroup = Tabs.ESP:AddRightGroupbox({
    Name = "ESP Filters",
    Center = true
})

EspLeftGroup:AddToggle("ESPEnabled", {
    Text = "Enable ESP",
    Default = getgenv().ESPEnabled,
    Callback = function(val) setConfig("ESPEnabled", val) end
})

local EspHighlightToggle = EspLeftGroup:AddToggle("ESPHighlight", {
    Text = "Show Highlight",
    Default = getgenv().ESPHighlight,
    Callback = function(val) setConfig("ESPHighlight", val) end
})

local ESPHighlightColorPicker = EspHighlightToggle:AddColorPicker("ESPHighlightColor", {
    Default = fromHex(getgenv().ESPHighlightColor or "ffffff"),
    Title = "Highlight Color",
    Callback = function(color) setConfig("ESPHighlightColor", toHex(color)) end
})

local EspTextToggle = EspLeftGroup:AddToggle("ESPText", {
    Text = "Show Text Info",
    Default = getgenv().ESPText,
    Callback = function(val) setConfig("ESPText", val) end
})

local ESPTextColorPicker = EspTextToggle:AddColorPicker("ESPTextColor", {
    Default = fromHex(getgenv().ESPTextColor or "000000"),
    Title = "Text Color",
    Callback = function(color) setConfig("ESPTextColor", toHex(color)) end
})

EspLeftGroup:AddDropdown("ESPTarget", {
    Text = "Plot Selector",
    Values = {"All", "My Plot", "Other Plots"},
    Default = getgenv().ESPTarget or "All",
    Callback = function(val) setConfig("ESPTarget", val) end
})

EspRightGroup:AddDropdown("ESPMutations", {
    Text = "Filter Mutations",
    Values = {"Normal", "Electric", "Gold", "Rainbow", "Aurora", "Bloodlit", "Frozen", "Chained", "Starstruck", "Pizza", "Solarflare"},
    Multi = true,
    Searchable = true,
    Default = keysToArray(getgenv().ESPMutations),
    Callback = function(val) setConfig("ESPMutations", val) end
})

EspRightGroup:AddDropdown("ESPPlants", {
    Text = "Filter Plants",
    Values = getSeedValues(),
    Multi = true,
    Searchable = true,
    Default = keysToArray(getgenv().ESPPlants),
    Callback = function(val) setConfig("ESPPlants", val) end
})

EspRightGroup:AddInput("ESPMinWeight", {
    Text = "Weight Threshold (>= kg)",
    Default = tostring(getgenv().ESPMinWeight or 0),
    Numeric = true,
    Finished = true,
    Callback = function(val) setConfig("ESPMinWeight", tonumber(val) or 0) end
})

local OptLeft = Tabs.Misc:AddLeftGroupbox({
    Name = "Optimization",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local WebhookGroup = Tabs.Misc:AddRightGroupbox({
    Name = "Webhook Settings",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

--// Main Tab
HarvestTab:AddDropdown("HarvestMutation", {
    Text = "Select Mutations",
    Values = {"Normal", "Electric", "Gold", "Rainbow", "Aurora", "Bloodlit", "Frozen", "Chained", "Starstruck", "Pizza", "Solarflare"},
    Multi = true,
    Searchable = true,
    Default = keysToArray(getgenv().HarvestMutation),
    Callback = function(val) setConfig("HarvestMutation", val) end
})

HarvestTab:AddDropdown("HarvestPlant", {
    Text = "Select Plants",
    Values = getSeedValues(),
    Multi = true,
    Searchable = true,
    Default = keysToArray(getgenv().HarvestPlant),
    Callback = function(val) setConfig("HarvestPlant", val) end
})

HarvestTab:AddInput("HarvestWeightLimit", {
    Text = "Harvest Weight Limit (< kg)",
    Default = tostring(getgenv().HarvestWeightLimit or 0),
    Numeric = true,
    Finished = true,
    Callback = function(val) setConfig("HarvestWeightLimit", tonumber(val) or 0) end
})

HarvestTab:AddToggle("Harvest", {
    Text = "Auto Harvest",
    Default = getgenv().Harvest,
    Callback = function(val) setConfig("Harvest", val) end
})

SellTab:AddDropdown("KeepMutations", {
    Text = "Keep Mutations",
    Values = {"Normal", "Electric", "Gold", "Rainbow", "Aurora", "Bloodlit", "Frozen", "Chained", "Starstruck", "Pizza", "Solarflare"},
    Multi = true,
    Searchable = true,
    Default = keysToArray(getgenv().KeepMutations),
    Callback = function(val) setConfig("KeepMutations", val) end
})

SellTab:AddInput("KeepWeight", {
    Text = "Keep Weight (>= kg)",
    Default = tostring(getgenv().KeepWeight or 0),
    Numeric = true,
    Finished = true,
    Callback = function(val) setConfig("KeepWeight", tonumber(val) or 0) end
})

SellTab:AddToggle("Sell", {
    Text = "Auto Sell",
    Default = getgenv().Sell,
    Callback = function(val) setConfig("Sell", val) end
})

StealTab:AddToggle("Steal", {
    Text = "Auto Steal Fruit",
    Default = getgenv().Steal,
    Callback = function(val) setConfig("Steal", val) end
})

--// Misc Tab
OptLeft:AddToggle("DisableRainbow", {
    Text = "Disable Rainbow",
    Default = getgenv().DisableRainbow,

    Callback = function(val)
        setConfig("DisableRainbow", val)

        if activeProfile == "Main" then
            if val then
                if getgenv().disableRainbowAnimation then
                    pcall(getgenv().disableRainbowAnimation)
                end
            else
                if getgenv().enableRainbowAnimation then
                    pcall(getgenv().enableRainbowAnimation)
                end
            end
        end
    end
})

OptLeft:AddToggle("DisablePlants", {
    Text = "Disable Plants",
    Default = getgenv().DisablePlants,

    Callback = function(val)
        setConfig("DisablePlants", val)
        
        if activeProfile == "Main" then
            getgenv().DisablePlants = val
            if not val then
                if getgenv().restoreAllPlants then
                    pcall(getgenv().restoreAllPlants)
                end
            end
        end
    end
})

local WeatherForecastGroup = Tabs.Misc:AddLeftGroupbox({
    Name = "Weather",
    Collapsible = true,
    Center = true,
    DefaultCollapsed = false
})

local WeatherForecastToggle = WeatherForecastGroup:AddToggle("ShowWeatherForecast", {
    Text = "Enable Weather",
    Default = getgenv().ShowWeatherForecast,
    Callback = function(val)
        setConfig("ShowWeatherForecast", val)
        if activeProfile == "Main" then
            if getgenv().updateWeatherUI then
                pcall(getgenv().updateWeatherUI)
            end
        end
    end
})

local ForecastDepBox = WeatherForecastGroup:AddDependencyBox()
ForecastDepBox:SetupDependencies({
    { WeatherForecastToggle, true }
})

ForecastDepBox:AddDropdown("SelectedForecasts", {
    Text = "Weather",
    Values = getWeatherValues(),
    Multi = true,
    Default = keysToArray(getgenv().SelectedForecasts),
    Callback = function(val)
        setConfig("SelectedForecasts", val)
        if activeProfile == "Main" then
            if getgenv().updateWeatherUI then
                pcall(getgenv().updateWeatherUI)
            end
        end
    end
})

--// Webhook settings UI
WebhookGroup:AddInput("WebhookURL", {
    Text = "Webhook URL",
    Default = getgenv().WebhookURL or "",
    Finished = true,
    Callback = function(val) setConfig("WebhookURL", val) end
})

WebhookGroup:AddInput("WebhookUserID", {
    Text = "Discord User ID (optional)",
    Default = getgenv().WebhookUserID or "",
    Finished = true,
    Callback = function(val) setConfig("WebhookUserID", val) end
})

WebhookGroup:AddToggle("WebhookEnabled", {
    Text = "Enable Webhook",
    Default = getgenv().WebhookEnabled,
    Callback = function(val) setConfig("WebhookEnabled", val) end
})

WebhookGroup:AddDivider()

local WebhookPingWeatherToggle = WebhookGroup:AddToggle("WebhookPingWeather", {
    Text = "Weather Change",
    Default = getgenv().WebhookPingWeather,
    Callback = function(val) setConfig("WebhookPingWeather", val) end
})

local WeatherDepBox = WebhookGroup:AddDependencyBox()
WeatherDepBox:SetupDependencies({
    { WebhookPingWeatherToggle, true }
})

WeatherDepBox:AddDropdown("WebhookWeatherFilter", {
    Text = "Select Weather to Ping",
    Values = getWeatherValues(),
    Multi = true,
    Searchable = true,
    Default = keysToArray(getgenv().WebhookWeatherFilter),
    Callback = function(val) setConfig("WebhookWeatherFilter", val) end
})

WebhookGroup:AddToggle("WebhookPingFruit", {
    Text = "Fruit Weight",
    Default = getgenv().WebhookPingFruit,
    Callback = function(val) setConfig("WebhookPingFruit", val) end
})

WebhookGroup:AddInput("WebhookFruitWeight", {
    Text = "Weight Threshold (kg)",
    Default = tostring(getgenv().WebhookFruitWeight or 100),
    Numeric = true,
    Finished = true,
    Callback = function(val) setConfig("WebhookFruitWeight", tonumber(val) or 100) end
})

WebhookGroup:AddButton("Test Webhook", function()
    local sendWebhook = getgenv().sendWebhook
    if sendWebhook then
        local contentStr = ""
        local userId = getgenv().WebhookUserID
        if userId and userId ~= "" then
            contentStr = "<@" .. tostring(userId) .. ">"
        end
        
        sendWebhook(getgenv().WebhookURL, {
            content = contentStr,
            embeds = {
                {
                    title = "🔔 GaG2 Webhook Test",
                    description = "Your webhook configuration is working successfully!",
                    color = 10711287,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = {
                        text = "Bob-Cat",
                        icon_url = "https://raw.githubusercontent.com/nostrainu/Dump/main/Assets/pop_cat_smirk_closed.png"
                    }
                }
            }
        })
    end
end)

--// Shop Tab
local SeedViewport = MiscLeft:AddViewport("SeedViewport", {
    Height = 120,
    Interactive = true,
    Visible = false,
})

local function findModel(name)
    local cleanName = string.lower(string.gsub(name, " Pack", ""))
    local found
    local function scan(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Model") or child:IsA("Tool") or child:IsA("BasePart") then
                local childName = string.lower(child.Name)
                if string.find(childName, cleanName) then
                    found = child
                    break
                end
            end
            pcall(scan, child)
        end
    end
    pcall(scan, ReplicatedStorage)
    if not found then
        pcall(scan, workspace)
    end
    return found
end

local function updateSeedViewport(selectedList)
    local selectedName
    for name, active in pairs(selectedList or {}) do
        if active then
            selectedName = name
            break
        end
    end
    if selectedName then
        local model = findModel(selectedName)
        if model then
            pcall(function()
                SeedViewport:SetObject(model, true)
                SeedViewport:SetVisible(true)
                SeedViewport:Focus()
            end)
        else
            SeedViewport:SetVisible(false)
        end
    else
        SeedViewport:SetVisible(false)
    end
end

MiscLeft:AddDropdown("SelectedSeed", {
    Text = "Select Seeds",
    Values = getSeedValues(),
    Multi = true,
    Default = keysToArray(getgenv().SelectedSeed),
    Callback = function(val)
        setConfig("SelectedSeed", val)
        pcall(updateSeedViewport, val)
    end
})

local GearViewport = MiscRight:AddViewport("GearViewport", {
    Height = 120,
    Interactive = false,
    Visible = false,
})

local function updateGearViewport(selectedList)
    local selectedName
    for name, active in pairs(selectedList or {}) do
        if active then
            selectedName = name
            break
        end
    end
    if selectedName then
        local model = findModel(selectedName)
        if model then
            pcall(function()
                GearViewport:SetObject(model, true)
                GearViewport:SetVisible(true)
                GearViewport:Focus()
            end)
        else
            GearViewport:SetVisible(false)
        end
    else
        GearViewport:SetVisible(false)
    end
end

MiscLeft:AddToggle("AutoBuySeed", {
    Text = "Buy Seeds",
    Default = getgenv().AutoBuySeed,
    Callback = function(val) setConfig("AutoBuySeed", val) end
})

MiscRight:AddDropdown("SelectedGear", {
    Text = "Select Gears",
    Values = getGearValues(),
    Multi = true,
    Default = keysToArray(getgenv().SelectedGear),
    Callback = function(val)
        setConfig("SelectedGear", val)
        pcall(updateGearViewport, val)
    end
})

MiscRight:AddToggle("AutoBuyGear", {
    Text = "Buy Gear",
    Default = getgenv().AutoBuyGear,
    Callback = function(val) setConfig("AutoBuyGear", val) end
})

local CrateViewport = CrateLeft:AddViewport("CrateViewport", {
    Height = 120,
    Interactive = true,
    Visible = false,
})

local function updateCrateViewport(selectedList)
    local selectedName
    for name, active in pairs(selectedList or {}) do
        if active then
            selectedName = name
            break
        end
    end
    if selectedName then
        local model = findModel(selectedName)
        if model then
            pcall(function()
                CrateViewport:SetObject(model, true)
                CrateViewport:SetVisible(true)
                CrateViewport:Focus()
            end)
        else
            CrateViewport:SetVisible(false)
        end
    else
        CrateViewport:SetVisible(false)
    end
end

CrateLeft:AddDropdown("SelectedCrate", {
    Text = "Select Crates",
    Values = getCrateValues(),
    Multi = true,
    Default = keysToArray(getgenv().SelectedCrate),
    Callback = function(val)
        setConfig("SelectedCrate", val)
        pcall(updateCrateViewport, val)
    end
})

CrateLeft:AddToggle("AutoBuyCrate", {
    Text = "Buy Crates",
    Default = getgenv().AutoBuyCrate,
    Callback = function(val) setConfig("AutoBuyCrate", val) end
})

getgenv().updateSeedViewport = updateSeedViewport
getgenv().updateGearViewport = updateGearViewport
getgenv().updateCrateViewport = updateCrateViewport

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

SettingsGroup:AddButton("Unload UI", function()
    Library:Unload()
end)

SettingsGroup:AddDivider()

SettingsGroup:AddToggle("DisableFloatingMenu", {
    Text = "Disable Floating",
    Default = registerSetting("DisableFloatingMenu", false),
    Callback = function(val)
        setConfig("DisableFloatingMenu", val)
        if activeProfile == "Main" then
            Library.DisableFloatingMenu = val
        end
    end
})

SettingsGroup:AddToggle("AutoExecute", {
    Text = "Auto Execute",
    Default = registerSetting("AutoExecute", false),
    Callback = function(val)
        setConfig("AutoExecute", val)
    end
})

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
    pcall(function() setclipboard("https://discord.gg/6sdWsCy9e") end)
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
    save()
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
            if not getgenv().GaG2_BulkSelectActive then
                loadProfile(alt.Name)
            end
        else
            selectedAlts[alt.Name] = nil
            if not getgenv().GaG2_BulkSelectActive then
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
                        save()
                        
                        local altPath = getProfilePath(alt.Name)
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
                        -- do nothing
                    end
                }
            }
        })
        return dialog
    end,
    OnPause = function(alt, explicitState)
        local parsed = getProfileData(alt.Name)
        if parsed then
            if explicitState ~= nil then
                if explicitState then
                    parsed.Status = "Paused"
                else
                    local isFarming = parsed.Harvest or parsed.Steal or parsed.Sell or parsed.AutoBuySeed or parsed.AutoBuyGear or parsed.AutoBuyCrate
                    parsed.Status = isFarming and "Farming" or "Waiting"
                end
            else
                if parsed.Status == "Paused" then
                    local isFarming = parsed.Harvest or parsed.Steal or parsed.Sell or parsed.AutoBuySeed or parsed.AutoBuyGear or parsed.AutoBuyCrate
                    parsed.Status = isFarming and "Farming" or "Waiting"
                else
                    parsed.Status = "Paused"
                end
            end
            writeProfileData(alt.Name, parsed)

        end
    end,
    OnOpenStats = function(alt)
        local altData = {
            Harvest = false,
            Steal = false,
            Sell = false,
            AutoBuySeed = false,
            Status = "Waiting",
            Coins = 0,
            FruitCount = 0,
            MaxFruitCapacity = 100,
            InvValueStandard = 0,
            InvValueDaily = 0,
            InvValueStock = 0,
            LastActive = 0
        }
        local isMain = false
        pcall(function()
            local lp = game:GetService("Players").LocalPlayer
            if lp and alt.Name == lp.Name then
                isMain = true
            end
        end)
        local parsed = getProfileData(alt.Name)
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
        local function formatCoins(val)
            if val >= 1000000 then
                return string.format("%.2fM¢", val / 1000000)
            elseif val >= 1000 then
                return string.format("%.2fK¢", val / 1000)
            else
                return tostring(val) .. "¢"
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
                activeStatus = altData.Status or "Farming"
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
        dialog:AddLabel("Coins: " .. formatCoins(altData.Coins))
        dialog:AddLabel("Inventory capacity: " .. tostring(altData.FruitCount) .. "/" .. tostring(altData.MaxFruitCapacity))
        dialog:AddLabel("Sell Value: " .. formatCoins(altData.InvValueStandard or 0))
        dialog:AddLabel("Daily Value: " .. formatCoins(altData.InvValueDaily or 0))
        dialog:AddLabel("Stock Value: " .. formatCoins(altData.InvValueStock or 0))
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
        local wsCache = getgenv().wsStatusCache
        if wsCache and wsCache[alt.Name] then
            local wsData = wsCache[alt.Name]
            if os.time() - (wsData.LastActive or 0) < 15 then
                return wsData.Status or "Farming", wsData.Status == "Paused"
            end
        end
        local parsed = getProfileData(alt.Name)
        if parsed then
            local lastActive = parsed.LastActive or 0
            if os.time() - lastActive < 15 then
                return parsed.Status or "Farming", parsed.Status == "Paused"
            end
        end
        return isOnline and "No Script" or "Offline", false
    end,
    GetAccountDetails = function(alt, isMain)
        return ""
    end
})

getgenv().GaG2_AltList = altList

if getgenv().BobcatWS then
    getgenv().BobcatWS.OnStatus(function(altName, payload)
        pcall(function()
            if getgenv().wsStatusCache then
                getgenv().wsStatusCache[altName] = payload
                getgenv().wsStatusCache[altName].LastActive = os.time()
            end
            if getgenv().writeProfileData then
                local existing = getgenv().getProfileData(altName) or {}
                for k, v in pairs(payload) do
                    existing[k] = v
                end
                getgenv().writeProfileData(altName, existing)
            end
            local cfg = getgenv().GaG2Config
            if cfg and cfg.Accounts then
                local exists = false
                for _, acc in ipairs(cfg.Accounts) do
                    if acc.Name == altName then exists = true break end
                end
                if not exists then
                    table.insert(cfg.Accounts, {
                        Name = altName,
                        Id = tostring(payload.UserId or "0")
                    })
                    pcall(getgenv().saveProfile)
                    if getgenv().GaG2_AltList and getgenv().GaG2_AltList.AddAccount then
                        getgenv().GaG2_AltList:AddAccount({ Name = altName, Id = tostring(payload.UserId or "0") })
                    end
                end
            end
        end)
    end)
end

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
        
        local folder = "bobcat/games/GaG2/alts"
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
            save()
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

Library:OnUnload(function()
    if getgenv().GaG2_Stop then
        pcall(getgenv().GaG2_Stop)
        getgenv().GaG2_Stop = nil
    end
end)
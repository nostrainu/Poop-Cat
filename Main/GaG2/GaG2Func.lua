if getgenv().GaG2_Stop then
    pcall(getgenv().GaG2_Stop)
end

--// Global Settings & Configurations
getgenv().GaG2DefaultSettings = {
    Harvest = false,
    Steal = false,
    Sell = false,
    AutoExecute = false,
    AutoBuySeed = false,
    SelectedSeed = {},
    AutoBuyGear = false,
    SelectedGear = {},
    DisableRainbow = false,
    DisablePlants = false,
    HarvestMutation = {["Normal"] = true},
    HarvestPlant = {},
    AutoBuyCrate = false,
    SelectedCrate = {},
    KeepMutations = {},
    KeepWeight = 0,
    HarvestWeightLimit = 0,
    WebhookURL = "",
    WebhookUserID = "",
    WebhookEnabled = false,
    WebhookPingWeather = false,
    WebhookPingFruit = false,
    WebhookFruitWeight = 100,
    WebhookWeatherFilter = {["Goldmoon"] = true, ["Rainbow Moon"] = true, ["Bloodmoon"] = true},
    ESPEnabled = false,
    ESPTarget = "All",
    ESPMutations = {},
    ESPPlants = {},
    ESPMinWeight = 0,
    ESPHighlight = false,
    ESPText = true,
    ESPHighlightColor = "ffffff",
    ESPTextColor = "000000",
    ShowWeatherForecast = false,
    SelectedForecasts = {},
}

for name, defaultValue in pairs(getgenv().GaG2DefaultSettings) do
    getgenv()[name] = defaultValue
end

getgenv().AccountControl = {
    Harvest = getgenv().Harvest,
    Steal = getgenv().Steal,
    Sell = getgenv().Sell,
}

getgenv().IsFarmingActive = function()
    local ac = getgenv().AccountControl or {}
    return not not (ac.Harvest or ac.Steal or ac.Sell or getgenv().AutoBuySeed or getgenv().AutoBuyGear or getgenv().AutoBuyCrate)
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Networking = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Networking"))
local TimeCycleData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("TimeCycleData"))
local WeatherData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("WeatherData"))
local SeedData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("SeedData"))
local GearShopData = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("GearShopData"))

local FruitValueCalc
pcall(function()
    FruitValueCalc = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("FruitValueCalc", 2))
end)

local function calculateInventoryValues()
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    local Character = LocalPlayer.Character
    local totalStandard = 0
    local totalStock = 0
    local totalDaily = 0
    local stockMultipliers = nil
    if Networking then
        pcall(function()
            local success, stock = pcall(function()
                return Networking.FruitStock.Request:Fire()
            end)
            if success and stock and type(stock) == "table" and type(stock.entries) == "table" then
                stockMultipliers = stock.entries
            end
        end)
    end
    local dailyCrop = nil
    local dailyMult = 18.5
    pcall(function()
        for _, inst in ipairs({workspace, ReplicatedStorage}) do
            for k, v in pairs(inst:GetAttributes()) do
                local kl = k:lower()
                if string.find(kl, "daily") or string.find(kl, "deal") then
                    if type(v) == "string" then
                        dailyCrop = v
                    elseif type(v) == "number" then
                        dailyMult = v
                    end
                end
            end
        end
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Model") then
                for k, v in pairs(child:GetAttributes()) do
                    local kl = k:lower()
                    if string.find(kl, "daily") or string.find(kl, "deal") then
                        if type(v) == "string" then
                            dailyCrop = v
                        elseif type(v) == "number" then
                            dailyMult = v
                        end
                    end
                end
            end
        end
    end)
    local parsedDailyDeal = nil
    pcall(function()
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Model") then
                local dialog = child:FindFirstChildOfClass("Dialog")
                if dialog then
                    for _, choice in ipairs(dialog:GetDescendants()) do
                        if choice:IsA("DialogChoice") and choice.UserDialog and string.find(choice.UserDialog, "Daily Deal") then
                            local match = string.match(choice.UserDialog, "%[(.-)%]")
                            if match then
                                match = string.gsub(match, "%$", "")
                                local mult = 1
                                if string.find(match, "K") then
                                    mult = 1000
                                    match = string.gsub(match, "K", "")
                                elseif string.find(match, "M") then
                                    mult = 1000000
                                    match = string.gsub(match, "M", "")
                                end
                                local val = tonumber(match)
                                if val then
                                    parsedDailyDeal = val * mult
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
    local function scan(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") and (child:GetAttribute("HarvestedFruit") == true or child:GetAttribute("FruitName") or child:GetAttribute("Id")) then
                local fruitName = child:GetAttribute("FruitName")
                if fruitName and FruitValueCalc then
                    local sizeMult = child:GetAttribute("SizeMultiplier") or 1
                    local mutation = child:GetAttribute("Mutation") or "Normal"
                    local decayAlpha = child:GetAttribute("DecayAlpha") or 0
                    local baseVal = 0
                    local successVal, calculatedVal = pcall(FruitValueCalc, fruitName, sizeMult, mutation, LocalPlayer, decayAlpha)
                    if successVal and calculatedVal then
                        baseVal = calculatedVal
                    end
                    totalStandard = totalStandard + baseVal
                    local mult = 1
                    if stockMultipliers and stockMultipliers[fruitName] then
                        mult = stockMultipliers[fruitName].multiplier or 1
                    end
                    totalStock = totalStock + math.floor(baseVal * mult)
                    if dailyCrop then
                        if fruitName == dailyCrop then
                            totalDaily = totalDaily + math.floor(baseVal * dailyMult)
                        else
                            totalDaily = totalDaily + baseVal
                        end
                    else
                        totalDaily = totalDaily + (baseVal * 18.5)
                    end
                end
            end
        end
    end
    scan(Backpack)
    scan(Character)
    if parsedDailyDeal and parsedDailyDeal > 0 then
        totalDaily = parsedDailyDeal
    end
    return totalStandard, totalDaily, totalStock
end
getgenv().calculateInventoryValues = calculateInventoryValues

getgenv().getProfilePath = function(profileName)
    local host = getgenv().Host
    if profileName == "Main" then
        if host and host ~= "" then
            return "bobcat/games/GaG2/config_" .. host .. ".json"
        else
            return "bobcat/games/GaG2/config.json"
        end
    else
        if host and host ~= "" then
            return "bobcat/games/GaG2/alts/" .. host .. "_" .. profileName .. ".json"
        else
            return "bobcat/games/GaG2/alts/" .. profileName .. ".json"
        end
    end
end

local profileCache = {}
getgenv().getProfileData = function(altName)
    local cached = profileCache[altName]
    local now = os.clock()
    if cached and now - cached.time < 1 then
        return cached.data
    end
    
    local altPath = getgenv().getProfilePath(altName)
    local data = nil
    if isfile(altPath) then
        local success, content = pcall(readfile, altPath)
        if success and content then
            local successDec, parsed = pcall(HttpService.JSONDecode, HttpService, content)
            if successDec and type(parsed) == "table" then
                data = parsed
            end
        end
    end
    profileCache[altName] = { time = now, data = data }
    return data
end

getgenv().writeProfileData = function(altName, data)
    profileCache[altName] = { time = os.clock(), data = data }
    task.spawn(function()
        local altPath = getgenv().getProfilePath(altName)
        pcall(function()
            if not isfolder("bobcat/games/GaG2/alts") then
                makefolder("bobcat/games/GaG2/alts")
            end
            writefile(altPath, HttpService:JSONEncode(data))
        end)
    end)
end

getgenv().saveActiveProfile = function()
    local success, err = pcall(function()
        if not isfolder("bobcat") then makefolder("bobcat") end
        if not isfolder("bobcat/games") then makefolder("bobcat/games") end
        if not isfolder("bobcat/games/GaG2") then makefolder("bobcat/games/GaG2") end
        if getgenv().activeProfile ~= "Main" then
            if not isfolder("bobcat/games/GaG2/alts") then makefolder("bobcat/games/GaG2/alts") end
        end
        
        local profilePath = getgenv().getProfilePath(getgenv().activeProfile)
        writefile(profilePath, HttpService:JSONEncode(getgenv().activeConfigTable))
    end)
    if not success then
        warn("[GaG2 Profile Save Error]: " .. tostring(err))
    end
end

getgenv().saveProfile = function()
    getgenv().saveActiveProfile()
end

getgenv().registerSetting = function(name, defaultValue)
    local config = getgenv().GaG2Config or {}
    if config[name] == nil then config[name] = defaultValue end
    getgenv()[name] = config[name]
    return config[name]
end

getgenv().startupDiscoverAlts = function()
    local host = getgenv().Host
    if not host or host == "" then return end
    
    local config = getgenv().GaG2Config or {}
    local changed = false
    if config.Accounts then
        for i = #config.Accounts, 1, -1 do
            if config.Accounts[i].Name == host then
                table.remove(config.Accounts, i)
                changed = true
            end
        end
    end
    
    local folder = "bobcat/games/GaG2/alts"
    if not isfolder(folder) then return end
    
    local successFiles, files = pcall(listfiles, folder)
    if not successFiles or type(files) ~= "table" then return end
    
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
            end
        end
    end
    if changed then
        getgenv().saveProfile()
    end
end

getgenv().getWeatherValues = function()
    local values = {"Day", "Sunset", "Night", "Goldmoon", "Rainbow Moon", "Bloodmoon"}
    local seen = {}
    for _, v in ipairs(values) do
        seen[v] = true
    end
    
    local success, err = pcall(function()
        local SharedModules = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules", 5)
        if SharedModules then
            local TimeCycleDataMod = SharedModules:FindFirstChild("TimeCycleData")
            if TimeCycleDataMod then
                local data = require(TimeCycleDataMod)
                if data and data.Data and data.Data.Night and data.Data.Night.Weathers then
                    for name in pairs(data.Data.Night.Weathers) do
                        if name ~= "Moon" and not seen[name] then
                            seen[name] = true
                            table.insert(values, name)
                        end
                    end
                end
            end
            
            local WeatherDataMod = SharedModules:FindFirstChild("WeatherData")
            if WeatherDataMod then
                local data = require(WeatherDataMod)
                if data and data.Data then
                    for _, weather in ipairs(data.Data) do
                        local name = weather.Name
                        if name and not seen[name] then
                            seen[name] = true
                            table.insert(values, name)
                        end
                    end
                end
            end
        end
    end)
    
    table.sort(values)
    return values
end

getgenv().runWorker = function()
    
    local host = getgenv().Host
    if not host or host == "" then
        warn("[GaG2] Host not specified. Aborting control.")
        return
    end
    
    local folder = "bobcat"
    local altFolder = "bobcat/games/GaG2/alts"
    local altPath = altFolder .. "/" .. host .. "_" .. LocalPlayer.Name .. ".json"
    local confirmedPath = "bobcat/games/GaG2/confirmed_" .. host .. "_" .. LocalPlayer.Name .. ".json"
    

    
    local makeFolderSuccess, makeFolderErr = pcall(function()
        if not isfolder(folder) then makefolder(folder) end
        if not isfolder("bobcat/games") then makefolder("bobcat/games") end
        if not isfolder("bobcat/games/GaG2") then makefolder("bobcat/games/GaG2") end
        if not isfolder(altFolder) then makefolder(altFolder) end
    end)
    if not makeFolderSuccess then
        warn("[GaG2 makefolder Error]: " .. tostring(makeFolderErr))
    end

    local confirmed = nil
    if isfile(altPath) or isfile(confirmedPath) then
        confirmed = true
    else
        local repo = "https://raw.githubusercontent.com/nostrainu/ObsidianFork/main/"
        local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
        
        if not Library then
            warn("[GaG2] Failed to load library for confirmation. Aborting control.")
            return
        end
        
        Library:Prompt({
            Title = "Account Control",
            Description = "Are you sure you want to allow " .. host .. " to take control of this account?",
            Buttons = {
                {
                    Text = "Yes",
                    Color = Color3.fromRGB(0, 180, 90),
                    Callback = function()
                        confirmed = true
                        local success, err = pcall(writefile, confirmedPath, "true")
                        if not success then
                            warn("[GaG2 writefile Error]: " .. tostring(err))
                        end
                    end
                },
                {
                    Text = "No",
                    Color = Color3.fromRGB(200, 50, 50),
                    Callback = function()
                        confirmed = false
                    end
                }
            }
        })
        
        while confirmed == nil do
            task.wait(0.5)
        end
    end
    
    if not confirmed then
        return
    end

    if getgenv().BobcatWS then
        getgenv().BobcatWS.ConnectAlt("GaG2", host, LocalPlayer.Name, function(payload)
            for k, v in pairs(payload) do
                if k ~= "LastActive" and k ~= "Status" and k ~= "Host" then
                    getgenv()[k] = v
                    if getgenv().AccountControl and getgenv().AccountControl[k] ~= nil then
                        getgenv().AccountControl[k] = v
                    end
                end
            end
        end)
    end

    task.spawn(function()
        local lastWriteTime = 0
        local shouldExit = false
        local startupTime = os.time()
        while true do
            if shouldExit then break end
            pcall(function()
                local configData = {}
                if isfile(altPath) then
                    local content = readfile(altPath)
                    local parsed = HttpService:JSONDecode(content)
                    if type(parsed) == "table" then
                        configData = parsed
                        local changed = false
                        for k, v in pairs(configData) do
                            if k ~= "LastActive" and k ~= "Status" and k ~= "Host" then
                                if type(v) == "table" then
                                    local currentTable = getgenv()[k]
                                    if type(currentTable) ~= "table" then
                                        getgenv()[k] = v
                                        changed = true
                                    else
                                        for subK, subV in pairs(v) do
                                            if currentTable[subK] ~= subV then
                                                currentTable[subK] = subV
                                                changed = true
                                            end
                                        end
                                        for subK, subV in pairs(currentTable) do
                                            if v[subK] == nil then
                                                currentTable[subK] = nil
                                                changed = true
                                            end
                                        end
                                    end
                                else
                                    if getgenv()[k] ~= v then
                                        getgenv()[k] = v
                                        if getgenv().AccountControl and getgenv().AccountControl[k] ~= nil then
                                            getgenv().AccountControl[k] = v
                                        end
                                        changed = true
                                    end
                                end
                            end
                        end

                        if parsed.Status == "Paused" then
                            getgenv().Paused = true
                        else
                            getgenv().Paused = false
                        end
                    end
                end
                
                local hostConfigPath = "bobcat/games/GaG2/config_" .. host .. ".json"
                if isfile(hostConfigPath) and (os.time() - startupTime > 30) then
                    local successHost, hostContent = pcall(readfile, hostConfigPath)
                    if successHost and hostContent then
                        local successHostDec, hostConfig = pcall(HttpService.JSONDecode, HttpService, hostContent)
                        if successHostDec and type(hostConfig) == "table" then
                            local found = false
                            if hostConfig.Accounts then
                                for _, a in ipairs(hostConfig.Accounts) do
                                    if a.Name == LocalPlayer.Name then
                                        found = true
                                        break
                                    end
                                end
                            end
                            if hostConfig.HostActive == false or not found then
                                pcall(delfile, altPath)
                                pcall(delfile, confirmedPath)
                                if getgenv().GaG2_Stop then
                                    pcall(getgenv().GaG2_Stop)
                                end
                                if getgenv().uiUpd then
                                    pcall(getgenv().uiUpd.Unload, getgenv().uiUpd)
                                end

                                shouldExit = true
                                return
                            end
                        end
                    end
                end
                
                local now = os.time()
                if now - lastWriteTime >= 5 then
                    lastWriteTime = now
                    configData.LastActive = now
                    local status = "Farming"
                    if getgenv().Paused then
                        status = "Paused"
                    elseif getgenv().IsFarmingActive and not getgenv().IsFarmingActive() then
                        status = "Waiting"
                    end
                    configData.Status = status
                    configData.UserId = LocalPlayer.UserId
                    if host and host ~= "" then
                        configData.Host = host
                    end
                    
                    local coins = 0
                    pcall(function()
                        local stats = LocalPlayer:FindFirstChild("leaderstats")
                        if stats and stats:FindFirstChild("Sheckles") then
                            coins = stats.Sheckles.Value
                        end
                    end)
                    local fruitCount = LocalPlayer:GetAttribute("FruitCount") or 0
                    local maxCapacity = LocalPlayer:GetAttribute("MaxFruitCapacity") or 100
                    
                    configData.Coins = coins
                    configData.FruitCount = fruitCount
                    configData.MaxFruitCapacity = maxCapacity
                    local stdVal, dailyVal, stockVal = calculateInventoryValues()
                    configData.InvValueStandard = stdVal
                    configData.InvValueDaily = dailyVal
                    configData.InvValueStock = stockVal
                    writefile(altPath, HttpService:JSONEncode(configData))

                    if getgenv().BobcatWS and getgenv().BobcatWS.IsConnected() then
                        getgenv().BobcatWS.PushStatus({
                            Status = status,
                            Coins = coins,
                            FruitCount = fruitCount,
                            MaxFruitCapacity = maxCapacity,
                            InvValueStandard = stdVal,
                            InvValueDaily = dailyVal,
                            InvValueStock = stockVal,
                            LastActive = now
                        })
                    end
                end
            end)
            if shouldExit then break end
            task.wait(0.2)
        end
    end)
end

getgenv().getSeedValues = function()
    local seen = {}
    local values = {}
    for _, seed in ipairs(SeedData) do
        if type(seed) == "table" and seed.SeedName and not seen[seed.SeedName] then
            seen[seed.SeedName] = true
            table.insert(values, seed.SeedName)
        end
    end
    table.sort(values)
    return values
end

getgenv().getGearValues = function()
    local seen = {}
    local values = {}
    local gearList = GearShopData.Data or {}
    for _, gear in ipairs(gearList) do
        if type(gear) == "table" and gear.ItemName and not seen[gear.ItemName] then
            seen[gear.ItemName] = true
            table.insert(values, gear.ItemName)
        end
    end
    table.sort(values)
    return values
end

getgenv().getCrateValues = function()
    local crateValues = {}
    local mainThread = coroutine.running()
    task.defer(function()
        local success, CrateData = pcall(function()
            return require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("CrateData"))
        end)
        if success and CrateData then
            local success2, crateList = pcall(function()
                return CrateData.GetAllCrates and CrateData:GetAllCrates() or CrateData.GetAllCrates()
            end)
            if success2 and type(crateList) == "table" then
                local seen = {}
                for _, crate in ipairs(crateList) do
                    if type(crate) == "table" and crate.Name and not seen[crate.Name] then
                        seen[crate.Name] = true
                        table.insert(crateValues, crate.Name)
                    end
                end
                table.sort(crateValues)
            end
        end
        task.spawn(mainThread)
    end)
    coroutine.yield()
    return crateValues
end

local scriptRunning = true
local conns = {}

local BobcatWS = nil
pcall(function()
    BobcatWS = loadstring(game:HttpGet("https://raw.githubusercontent.com/nostrainu/Poop-Cat/refs/heads/main/Misc/BobcatWS.lua"))()
end)
getgenv().BobcatWS = BobcatWS

getgenv().GaG2_Stop = function()
    scriptRunning = false
    
    getgenv().uiActive = false
    getgenv().uiUpd = nil
    getgenv().GaG2_QueueLoopActive = false
    
    if getgenv().GaG2Config then
        getgenv().GaG2Config.HostActive = false
        pcall(getgenv().saveProfile)
    end
    
    for _, conn in ipairs(conns) do
        conn:Disconnect()
    end
    table.clear(conns)

    if getgenv().enableRainbowAnimation then
        pcall(getgenv().enableRainbowAnimation)
    end

    if getgenv().restoreAllPlants then
        pcall(getgenv().restoreAllPlants)
    end

    if clearESP then
        pcall(clearESP)
    end

    if cleanupCustomWeatherUI then
        pcall(cleanupCustomWeatherUI)
    end

    if getgenv().BobcatWS then
        pcall(getgenv().BobcatWS.Disconnect)
    end
end

--// Shop Tab - Shop & Auto-Buy Helpers

local function getStockItems(shopName)
    local stockValues = ReplicatedStorage:WaitForChild("StockValues", 15)
    if not stockValues then return nil end
    local shop = stockValues:FindFirstChild(shopName) or stockValues:WaitForChild(shopName, 15)
    if not shop then return nil end
    return shop:FindFirstChild("Items") or shop:WaitForChild("Items", 15)
end

local function getUIStockAmount(shopName, itemName)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    
    local shopGui = playerGui:FindFirstChild(shopName)
    if not shopGui then return 0 end
    
    local itemFrame = nil
    if shopName == "SeedShop" then
        local normalShop = shopGui:FindFirstChild("Frame", true)
        if normalShop then
            normalShop = normalShop:FindFirstChild("NormalShop", true)
            if normalShop then
                itemFrame = normalShop:FindFirstChild(itemName)
            end
        end
    elseif shopName == "GearShop" or shopName == "CrateShop" then
        local scrolling = shopGui:FindFirstChild("ScrollingFrame", true)
        if scrolling then
            itemFrame = scrolling:FindFirstChild(itemName)
        end
    end
    
    if not itemFrame then return 0 end
    local mainFrame = itemFrame:FindFirstChild("Main_Frame", true)
    if not mainFrame then return 0 end
    local stockText = mainFrame:FindFirstChild("Stock_Text", true)
    if not stockText or not stockText:IsA("TextLabel") then return 0 end
    
    local text = stockText.Text or ""
    local amount = tonumber(string.match(text, "(%d+)"))
    return amount or 0
end

local function getPlayerBalance()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if not leaderstats then return 0 end
    local sheckles = leaderstats:FindFirstChild("Sheckles")
    if not sheckles or not (sheckles:IsA("IntValue") or sheckles:IsA("NumberValue")) then return 0 end
    return sheckles.Value
end

local function getStaticPrice(shopName, itemName)
    if shopName == "SeedShop" then
        if SeedData then
            for _, seed in ipairs(SeedData) do
                if seed.SeedName == itemName then
                    return seed.PurchasePrice or 0
                end
            end
        end
    elseif shopName == "GearShop" then
        if GearShopData and GearShopData.Data then
            for _, gear in ipairs(GearShopData.Data) do
                if gear.ItemName == itemName then
                    return gear.Cost or 0
                end
            end
        end
    elseif shopName == "CrateShop" then
        local success, CrateData = pcall(function()
            return require(ReplicatedStorage:FindFirstChild("SharedModules"):FindFirstChild("CrateData"))
        end)
        if success and CrateData and CrateData.GetData then
            local data = CrateData.GetData(itemName)
            if data then
                return data.Cost or 0
            end
        end
    end
    return 0
end

local function getItemPrice(shopName, itemName)
    local price = 0
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
        
        local shopGui = playerGui:FindFirstChild(shopName)
        if not shopGui then return end
        
        local itemFrame = nil
        if shopName == "SeedShop" then
            local normalShop = shopGui:FindFirstChild("Frame", true)
            if normalShop then
                normalShop = normalShop:FindFirstChild("NormalShop", true)
                if normalShop then
                    itemFrame = normalShop:FindFirstChild(itemName)
                end
            end
        elseif shopName == "GearShop" or shopName == "CrateShop" then
            local scrolling = shopGui:FindFirstChild("ScrollingFrame", true)
            if scrolling then
                itemFrame = scrolling:FindFirstChild(itemName)
            end
        end
        
        if not itemFrame then return end
        local mainFrame = itemFrame:FindFirstChild("Main_Frame", true)
        if not mainFrame then return end
        local priceText = mainFrame:FindFirstChild("Price_Text", true)
        if not priceText or not priceText:IsA("TextLabel") then return end
        
        local text = priceText.Text or ""
        local priceNum = tonumber(string.match(text, "(%d+)"))
        if priceNum then
            price = priceNum
        end
    end)
    
    if price <= 0 then
        price = getStaticPrice(shopName, itemName)
    end
    
    return price
end

local activePurchases = {}

local function triggerBuyItem(shopName, itemName)
    if shopName == "SeedShop" and not getgenv().AutoBuySeed then return end
    if shopName == "GearShop" and not getgenv().AutoBuyGear then return end
    if shopName == "CrateShop" and not getgenv().AutoBuyCrate then return end

    local selectedTable = shopName == "SeedShop" and getgenv().SelectedSeed or (shopName == "GearShop" and getgenv().SelectedGear or getgenv().SelectedCrate)
    if not selectedTable or not selectedTable[itemName] then return end

    local key = shopName .. "_" .. itemName
    if activePurchases[key] then return end

    local stock = getUIStockAmount(shopName, itemName)
    if stock <= 0 then return end

    local price = getItemPrice(shopName, itemName)
    local balance = getPlayerBalance()

    if price <= 0 or balance < price then return end

    local buyCount = math.min(stock, math.floor(balance / price))
    if buyCount <= 0 then return end

    activePurchases[key] = true
    task.spawn(function()
        pcall(function()
            for i = 1, buyCount do
                if shopName == "SeedShop" and not getgenv().AutoBuySeed then break end
                if shopName == "GearShop" and not getgenv().AutoBuyGear then break end
                if shopName == "CrateShop" and not getgenv().AutoBuyCrate then break end
                if not scriptRunning then break end

                local currentBalance = getPlayerBalance()
                if currentBalance < price then break end

                if shopName == "SeedShop" then
                    Networking.SeedShop.PurchaseSeed:Fire(itemName)
                elseif shopName == "GearShop" then
                    Networking.GearShop.PurchaseGear:Fire(itemName)
                elseif shopName == "CrateShop" then
                    Networking.CrateShop.PurchaseCrate:Fire(itemName)
                end
                task.wait(0.2)
            end
        end)
        activePurchases[key] = nil
    end)
end
getgenv().triggerBuyItem = triggerBuyItem

local function handleAutoBuySeed()
    local selected = getgenv().SelectedSeed
    if type(selected) == "table" then
        for seedName, active in pairs(selected) do
            if active and getgenv().AutoBuySeed and scriptRunning then
                triggerBuyItem("SeedShop", seedName)
            end
        end
    end
end

local function handleAutoBuyGear()
    local selected = getgenv().SelectedGear
    if type(selected) == "table" then
        for gearName, active in pairs(selected) do
            if active and getgenv().AutoBuyGear and scriptRunning then
                triggerBuyItem("GearShop", gearName)
            end
        end
    end
end

local function handleAutoBuyCrate()
    local selected = getgenv().SelectedCrate
    if type(selected) == "table" then
        for crateName, active in pairs(selected) do
            if active and getgenv().AutoBuyCrate and scriptRunning then
                triggerBuyItem("CrateShop", crateName)
            end
        end
    end
end

--// Misc Tab - Weather Forecasting
local function predictPhaseWeather(cycleIndex, phaseName)
    local phaseData = TimeCycleData.Data[phaseName]
    if not phaseData then return nil end
    
    local sortedPhases = {}
    for name, info in pairs(TimeCycleData.Data) do
        table.insert(sortedPhases, {Name = name, Order = info.StartOrder or 1})
    end
    table.sort(sortedPhases, function(a, b) return a.Order < b.Order end)
    
    local phaseIndex = 1
    for idx, info in ipairs(sortedPhases) do
        if info.Name == phaseName then
            phaseIndex = idx
            break
        end
    end
    
    local weathers = phaseData.Weathers
    local totalChance = 0
    local naturallySpawnableWeathers = {}
    
    local MoonGating = ReplicatedStorage.SharedModules:FindFirstChild("MoonGating")
    local MoonGatingMod = MoonGating and require(MoonGating)
    
    for name, info in pairs(weathers) do
        local naturallySpawnable = true
        if info.AdminOnly then
            naturallySpawnable = false
        elseif MoonGatingMod and MoonGatingMod.IsNaturallySpawnable then
            naturallySpawnable = MoonGatingMod.IsNaturallySpawnable(name)
        end
        if naturallySpawnable then
            totalChance = totalChance + info.Chance
            table.insert(naturallySpawnableWeathers, {Name = name, Chance = info.Chance})
        end
    end
    
    if #naturallySpawnableWeathers == 0 then return nil end
    if #naturallySpawnableWeathers == 1 then return naturallySpawnableWeathers[1].Name end
    
    local seed = cycleIndex * 1000 + phaseIndex
    local rng = Random.new(seed)
    local roll = rng:NextNumber() * totalChance
    
    local currentSum = 0
    for _, info in ipairs(naturallySpawnableWeathers) do
        currentSum = currentSum + info.Chance
        if roll <= currentSum then
            return info.Name
        end
    end
    return naturallySpawnableWeathers[1].Name
end

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

local function formatDuration(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%dh %dm %ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function getTimeUntilPhase(targetPhaseName, targetCycleIndex)
    local sortedPhases = {}
    local totalDuration = 0
    for name, info in pairs(TimeCycleData.Data) do
        table.insert(sortedPhases, {Name = name, Order = info.StartOrder or 1, Duration = info.Lasts or 0})
    end
    table.sort(sortedPhases, function(a, b) return a.Order < b.Order end)
    for _, info in ipairs(sortedPhases) do
        totalDuration = totalDuration + info.Duration
    end
    
    local t = workspace:GetServerTimeNow()
    local activePhase = workspace:GetAttribute("ActivePhase") or "Day"
    local phaseDuration = workspace:GetAttribute("PhaseDuration") or 0
    local remaining = math.max(0, phaseDuration - t)
    
    local activeIdx = 1
    local targetIdx = 1
    for idx, info in ipairs(sortedPhases) do
        if info.Name == activePhase then activeIdx = idx end
        if info.Name == targetPhaseName then targetIdx = idx end
    end
    
    local currentIdx = activeIdx
    local cyclesAhead = 0
    local timeAccumulated = 0
    
    while true do
        if cyclesAhead > 5000 then return nil end
        
        local currentCycleOffset = math.floor(t / totalDuration) + cyclesAhead
        if cyclesAhead == (targetCycleIndex - math.floor(t / totalDuration)) and currentIdx == targetIdx then
            if currentIdx == activeIdx and cyclesAhead == 0 then
                return 0
            else
                return timeAccumulated
            end
        end
        
        if currentIdx == activeIdx and cyclesAhead == 0 then
            timeAccumulated = timeAccumulated + remaining
        else
            timeAccumulated = timeAccumulated + sortedPhases[currentIdx].Duration
        end
        
        currentIdx = currentIdx + 1
        if currentIdx > #sortedPhases then
            currentIdx = 1
            cyclesAhead = cyclesAhead + 1
        end
    end
end

local function getNextTimeFor(targetName)
    local t = workspace:GetServerTimeNow()
    local cycleIndex = math.floor(t / 600)
    local activePhase = workspace:GetAttribute("ActivePhase") or "Day"
    
    local isPhase = (targetName == "Day" or targetName == "Sunset" or targetName == "Night")
    if isPhase then
        local sortedPhases = {}
        for name, info in pairs(TimeCycleData.Data) do
            table.insert(sortedPhases, {Name = name, Order = info.StartOrder or 1})
        end
        table.sort(sortedPhases, function(a, b) return a.Order < b.Order end)
        
        local activeIdx = 1
        local targetIdx = 1
        for idx, info in ipairs(sortedPhases) do
            if info.Name == activePhase then activeIdx = idx end
            if info.Name == targetName then targetIdx = idx end
        end
        
        local targetCycle = cycleIndex
        if targetIdx < activeIdx then
            targetCycle = cycleIndex + 1
        end
        
        return getTimeUntilPhase(targetName, targetCycle)
    else
        local parentPhase = "Night"
        for phaseName, phaseInfo in pairs(TimeCycleData.Data) do
            if phaseInfo.Weathers and phaseInfo.Weathers[targetName] then
                parentPhase = phaseName
                break
            end
        end
        
        local baseCycle = cycleIndex
        local sortedPhases = {}
        for name, info in pairs(TimeCycleData.Data) do
            table.insert(sortedPhases, {Name = name, Order = info.StartOrder or 1})
        end
        table.sort(sortedPhases, function(a, b) return a.Order < b.Order end)
        
        local activeIdx = 1
        local parentIdx = 1
        for idx, info in ipairs(sortedPhases) do
            if info.Name == activePhase then activeIdx = idx end
            if info.Name == parentPhase then parentIdx = idx end
        end
        
        if parentIdx < activeIdx then
            baseCycle = baseCycle + 1
        end
        
        for i = baseCycle, baseCycle + 2000 do
            local weather = predictPhaseWeather(i, parentPhase)
            if weather == targetName then
                return getTimeUntilPhase(parentPhase, i)
            end
        end
        return nil
    end
end

local StaticWeatherIcons = {
    ["Rain"] = { Image = "rbxassetid://124343834471497", Color = Color3.fromRGB(255, 255, 255) },
    ["Lightning"] = { Image = "rbxassetid://129966012751860", Color = Color3.fromRGB(255, 255, 255) },
    ["Bloodmoon"] = { Image = "rbxassetid://72350957717841", Color = Color3.fromRGB(210, 0, 0) },
    ["Snowfall"] = { Image = "rbxassetid://77492704017442", Color = Color3.fromRGB(210, 210, 210) },
    ["Night"] = { Image = "rbxassetid://76206945378403", Color = Color3.fromRGB(255, 255, 255) },
    ["Starfall"] = { Image = "rbxassetid://82440542306454", Color = Color3.fromRGB(255, 255, 255) },
    ["Rainbow"] = { Image = "rbxassetid://71907919634074", Color = Color3.fromRGB(210, 210, 210) },
    ["Aurora"] = { Image = "rbxassetid://112025921017973", Color = Color3.fromRGB(255, 255, 255) },
    
    ["Day"] = { Image = "rbxassetid://100486757307207", Color = Color3.fromRGB(255, 225, 0) },
    ["Sunset"] = { Image = "rbxassetid://86217612022586", Color = Color3.fromRGB(255, 228, 90) },
    ["Moon"] = { Image = "rbxassetid://91446334780160", Color = Color3.fromRGB(30, 71, 148) },
    ["Goldmoon"] = { Image = "rbxassetid://84902063004871", Color = Color3.fromRGB(255, 221, 0) },
    ["Rainbow Moon"] = { Image = "rbxassetid://93602895495056", Color = Color3.fromRGB(166, 24, 255) },
    ["Mega Moon"] = { Image = "rbxassetid://107925838920918", Color = Color3.fromRGB(0, 0, 255) },
}

local function getGameWeatherIcon(weatherName)
    local weatherUI = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("WeatherUI")
    local frame = weatherUI and weatherUI:FindFirstChild("Frame")
    if not frame then return nil, nil end
    
    local targetName = weatherName
    if weatherName == "Rainbow Moon" then
        targetName = "Rainbow"
    end
    
    local gameFrame = frame:FindFirstChild(targetName)
    if gameFrame then
        local vector = gameFrame:FindFirstChild("Vector")
        if vector and vector:IsA("ImageLabel") then
            if vector.Image and vector.Image ~= "" then
                return vector.Image, vector.ImageColor3
            end
        end
        
        local iconImg = nil
        local iconColor = Color3.fromRGB(255, 255, 255)
        
        local function scan(obj)
            if obj:IsA("ImageLabel") and obj.Name ~= "Background" and obj.Name ~= "BevelEffect" and obj.Name ~= "InletTexture" and obj.Image ~= "" then
                iconImg = obj.Image
                iconColor = obj.ImageColor3
                return true
            end
            for _, child in ipairs(obj:GetChildren()) do
                if scan(child) then return true end
            end
            return false
        end
        scan(gameFrame)
        
        if iconImg and iconImg ~= "" then
            return iconImg, iconColor
        end
    end
    return nil, nil
end

local weatherWidget = nil

local function cleanupCustomWeatherUI()
    if weatherWidget then
        pcall(function() weatherWidget:Destroy() end)
        weatherWidget = nil
    end
    local weatherUI = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("WeatherUI")
    local frame = weatherUI and weatherUI:FindFirstChild("Frame")
    if frame then
        frame.Visible = true
    end
end
getgenv().cleanupCustomWeatherUI = cleanupCustomWeatherUI

local function updateWeatherUI()
    local weatherUI = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("WeatherUI")
    local frame = weatherUI and weatherUI:FindFirstChild("Frame")
    
    local selected = getgenv().SelectedForecasts or {}
    local hasAnySelected = false
    for _, active in pairs(selected) do
        if active then hasAnySelected = true break end
    end
    
    if not getgenv().ShowWeatherForecast or not hasAnySelected then
        cleanupCustomWeatherUI()
        return
    end
    
    if frame then
        frame.Visible = false
    end
    
    if not weatherWidget then
        cleanupCustomWeatherUI()
        
        weatherWidget = Library:CreateWidget({
            Title = "Weather",
            Position = UDim2.new(1, -255, 0, 90),
            Width = 240,
            Visible = true,
        })
    end
    
    local t = workspace:GetServerTimeNow()
    local activePhase = workspace:GetAttribute("ActivePhase") or "Day"
    local activeWeather = workspace:GetAttribute("ActiveWeather")
    local phaseDuration = workspace:GetAttribute("PhaseDuration") or 0
    local remaining = math.max(0, phaseDuration - t)
    
    local activeRows = {}
    
    for weatherName, active in pairs(selected) do
        if active and weatherName ~= "Moon" then
            activeRows[weatherName] = true
            
            local isCurrentlyActive = false
            if (activePhase == weatherName) or (activeWeather == weatherName) then
                isCurrentlyActive = true
            else
                local weatherValues = ReplicatedStorage:FindFirstChild("WeatherValues")
                if weatherValues then
                    isCurrentlyActive = weatherValues:GetAttribute(weatherName .. "_Playing") == true
                end
            end
            local timeUntil = getNextTimeFor(weatherName)
            
            local timerText = ""
            local timerColor = Color3.fromRGB(200, 200, 200)
            
            if isCurrentlyActive then
                timerText = "Active: " .. formatTime(remaining)
                timerColor = Color3.fromRGB(50, 220, 110)
            else
                timerText = timeUntil and ("in " .. formatDuration(timeUntil)) or "Not found"
                timerColor = Color3.fromRGB(200, 200, 200)
            end
            
            local iconImage = nil
            local iconColor = Color3.fromRGB(255, 255, 255)
            
            local gameIcon, gameColor = getGameWeatherIcon(weatherName)
            if gameIcon then
                iconImage = gameIcon
                iconColor = gameColor
            else
                local staticIcon = StaticWeatherIcons[weatherName]
                if staticIcon then
                    iconImage = staticIcon.Image
                    iconColor = staticIcon.Color
                else
                    local phaseName = "Night"
                    for pName, pInfo in pairs(TimeCycleData.Data) do
                        if pInfo.Weathers and pInfo.Weathers[weatherName] then
                            phaseName = pName
                            break
                        end
                    end
                    
                    local weatherInfo = TimeCycleData.Data[phaseName] and TimeCycleData.Data[phaseName].Weathers and TimeCycleData.Data[phaseName].Weathers[weatherName]
                    if weatherInfo then
                        iconImage = weatherInfo.Image
                        iconColor = weatherInfo.Color or Color3.fromRGB(255, 255, 255)
                    end
                end
            end
            
            weatherWidget:AddRow(weatherName, {
                Icon = iconImage,
                IconColor = iconColor,
                Text = weatherName,
                Value = timerText,
                Color = timerColor,
            })
        end
    end
    
    for rowId in pairs(weatherWidget.Rows) do
        if not activeRows[rowId] then
            weatherWidget:RemoveRow(rowId)
        end
    end
end

--// Main Tab - Automated Gardening Utilities
local FruitVisualizerController = nil
local function getFruitVisualizerController()
    if FruitVisualizerController then return FruitVisualizerController end
    local folders = {LocalPlayer:FindFirstChild("PlayerScripts"), ReplicatedStorage}
    for _, folder in ipairs(folders) do
        if folder then
            for _, desc in ipairs(folder:GetDescendants()) do
                if desc:IsA("ModuleScript") and desc.Name == "FruitVisualizerController" then
                    local success, mod = pcall(require, desc)
                    if success and mod then
                        FruitVisualizerController = mod
                        return FruitVisualizerController
                    end
                end
            end
        end
    end
    return nil
end

local function getFruitModel(plant)
    local fruitsFolder = plant:FindFirstChild("Fruits")
    if fruitsFolder then
        for _, child in ipairs(fruitsFolder:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                return child
            end
        end
    end
    return nil
end

local function getWeightValue(inst)
    if not inst then return 0 end
    
    local target = inst
    local fruitModel = getFruitModel(inst)
    if fruitModel then
        target = fruitModel
    end
    
    local fvc = getFruitVisualizerController()
    if fvc then
        local success, w = pcall(function()
            local weight = fvc:CalculateFruitWeight(target)
            if not weight and fvc.CalculateFruitWeight then
                weight = fvc:CalculateFruitWeight(inst)
            end
            if not weight and fvc.CalculatePlantWeight then
                weight = fvc:CalculatePlantWeight(inst)
            end
            return weight
        end)
        if success and w then
            return w
        end
    end
    
    for _, obj in ipairs({target, inst}) do
        for _, attrName in ipairs({"Weight", "Size", "Kg", "WeightValue"}) do
            local val = obj:GetAttribute(attrName)
            if val then
                if type(val) == "number" then
                    return val
                elseif type(val) == "string" then
                    local num = tonumber(string.match(val, "[%d%.]+"))
                    if num then
                        return num
                    end
                end
            end
        end
        for _, childName in ipairs({"Weight", "Size", "Kg", "WeightValue"}) do
            local valObj = obj:FindFirstChild(childName)
            if valObj and (valObj:IsA("ValueObject") or valObj:IsA("StringValue") or valObj:IsA("NumberValue") or valObj:IsA("IntValue")) then
                local val = valObj.Value
                if type(val) == "number" then
                    return val
                elseif type(val) == "string" then
                    local num = tonumber(string.match(val, "[%d%.]+"))
                    if num then
                        return num
                    end
                end
            end
        end
    end
    return 0
end

local function isFruitInstance(child)
    if child:IsA("Configuration") and child:GetAttribute("FruitProxy") == true then
        return true
    elseif child:IsA("Tool") and child:GetAttribute("HarvestedFruit") == true then
        return true
    end
    if child:GetAttribute("Fruit") or child:GetAttribute("FruitName") or child:GetAttribute("Id") then
        return true
    end
    return false
end

getgenv().sendWebhook = function(url, data)
    if not url or url == "" then return end
    local req = request or http_request or (syn and syn.request) or (http and http.request)
    if req then
        local success, err = pcall(function()
            local res = req({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })

        end)
        if not success then
            warn("[GaG2 Webhook Request Error]: " .. tostring(err))
        end
    else
        local success, err = pcall(function()
            local res = HttpService:RequestAsync({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })

        end)
        if not success then
            warn("[GaG2 Webhook RequestAsync Error]: " .. tostring(err))
        end
    end
end

local function getPlayerPlot()
    local plotId = LocalPlayer:GetAttribute("PlotId")
    if not plotId then return nil end
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return nil end
    return gardens:FindFirstChild("Plot" .. tostring(plotId))
end

local notifiedFruits = {}
local initialScanDone = false

local function checkPlotPlantsForWebhooks()
    if not getgenv().WebhookEnabled or not getgenv().WebhookPingFruit then return end
    
    local myPlot = getPlayerPlot()
    if not myPlot then return end
    
    local plants = myPlot:FindFirstChild("Plants")
    if not plants then return end
    
    local threshold = getgenv().WebhookFruitWeight
    
    if not initialScanDone then
        initialScanDone = true
        for _, plant in ipairs(plants:GetChildren()) do
            local plantId = plant:GetAttribute("PlantId")
            if plantId then
                local weight = getWeightValue(plant)
                if weight >= threshold then
                    notifiedFruits[tostring(plantId)] = true
                end
            end
        end
        return
    end
    
    for _, plant in ipairs(plants:GetChildren()) do
        local plantId = plant:GetAttribute("PlantId")
        if plantId then
            local weight = getWeightValue(plant)
            if weight >= threshold then
                local notifyKey = tostring(plantId)
                
                if not notifiedFruits[notifyKey] then
                    notifiedFruits[notifyKey] = true
                    
                    local mutation = plant:GetAttribute("Mutation")
                    if not mutation or mutation == "" then
                        mutation = "Normal"
                    end
                    local seedName = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName") or plant:GetAttribute("Seed") or plant:GetAttribute("PlantName") or plant.Name
                    
                    local sendWebhook = getgenv().sendWebhook
                    if sendWebhook then

                        local contentStr = ""
                        local userId = getgenv().WebhookUserID
                        if userId and userId ~= "" then
                            contentStr = "<@" .. tostring(userId) .. ">"
                        end
                        
                        task.spawn(function()
                            sendWebhook(getgenv().WebhookURL, {
                                content = contentStr,
                                embeds = {
                                    {
                                        title = "🌱 Giant Fruit Grown on Plot!",
                                        description = string.format("A fruit on your plot has grown to a heavy weight!\n\n**Fruit/Plant:** %s\n**Mutation:** %s\n**Weight:** %.2f kg", seedName, mutation, weight),
                                        color = 10711287,
                                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                                        footer = {
                                            text = "Bob-Cat",
                                            icon_url = "https://raw.githubusercontent.com/nostrainu/Dump/main/Assets/pop_cat_smirk_closed.png"
                                        }
                                    }
                                }
                            })
                        end)
                    end
                end
            end
        end
    end
    
    for notifyKey in pairs(notifiedFruits) do
        local foundAndAboveThreshold = false
        for _, plant in ipairs(plants:GetChildren()) do
            local plantId = plant:GetAttribute("PlantId")
            if plantId then
                local key = tostring(plantId)
                if key == notifyKey then
                    local weight = getWeightValue(plant)
                    if weight >= threshold then
                        foundAndAboveThreshold = true
                    end
                    break
                end
            end
        end
        if not foundAndAboveThreshold then
            notifiedFruits[notifyKey] = nil
        end
    end
end

local selling = false
local function handleAutoSell()
    if selling then return end
    selling = true
    pcall(function()
        local keepList = getgenv().KeepMutations or {}
        local keepWeight = tonumber(getgenv().KeepWeight) or 0

        local function getMutation(inst)
            local m = inst:GetAttribute("Mutation")
            return (not m or m == "") and "Normal" or m
        end

        local function shouldKeepFruit(child)
            if not isFruitInstance(child) then
                return false
            end
            local m = getMutation(child)
            if keepList[m] then
                return true
            end
            if keepWeight > 0 then
                local w = getWeightValue(child)
                if w >= keepWeight then
                    return true
                end
            end
            return false
        end

        local hasFruitsToKeep = false
        local function checkContainer(container)
            if not container then return end
            for _, child in ipairs(container:GetChildren()) do
                if shouldKeepFruit(child) then
                    hasFruitsToKeep = true
                    break
                end
            end
        end
        checkContainer(LocalPlayer.Backpack)
        if LocalPlayer.Character then
            checkContainer(LocalPlayer.Character)
        end

        pcall(function()
            local logData = {
                KeepList = keepList,
                KeepWeight = keepWeight,
                Tools = {}
            }
            local function scan(container, name)
                if not container then return end
                for _, child in ipairs(container:GetChildren()) do
                    if isFruitInstance(child) or child:IsA("Tool") then
                        table.insert(logData.Tools, {
                            Container = name,
                            ClassName = child.ClassName,
                            Name = child.Name,
                            HarvestedFruit = child:GetAttribute("HarvestedFruit"),
                            FruitProxy = child:GetAttribute("FruitProxy"),
                            FruitName = child:GetAttribute("FruitName"),
                            Fruit = child:GetAttribute("Fruit"),
                            Mutation = child:GetAttribute("Mutation"),
                            Weight = child:GetAttribute("Weight"),
                            Id = child:GetAttribute("Id")
                        })
                    end
                end
            end
            scan(LocalPlayer.Backpack, "Backpack")
            if LocalPlayer.Character then
                scan(LocalPlayer.Character, "Character")
            end
            logData.HasFruitsToKeep = hasFruitsToKeep
            writefile("gag2_autosell_debug.json", game:GetService("HttpService"):JSONEncode(logData))
        end)

        if not hasFruitsToKeep then
            Networking.NPCS.SellAll:Fire()
        else
            local sellList = {}
            local function collect(container)
                if not container then return end
                for _, child in ipairs(container:GetChildren()) do
                    if isFruitInstance(child) then
                        if not shouldKeepFruit(child) then
                            table.insert(sellList, child)
                        end
                    end
                end
            end
            collect(LocalPlayer.Backpack)
            if LocalPlayer.Character then
                collect(LocalPlayer.Character)
            end

            for _, inst in ipairs(sellList) do
                if not scriptRunning or not getgenv().AccountControl or not getgenv().AccountControl.Sell then
                    break
                end
                local id = inst:GetAttribute("Id")
                if id then
                    pcall(function()
                        Networking.NPCS.SellFruit:Fire(id)
                        inst:Destroy()
                    end)
                    task.wait(0.05)
                end
            end
        end
    end)
    task.wait(0.5)
    selling = false
end

local function isInventoryFull()
    local current = LocalPlayer:GetAttribute("FruitCount") or 0
    local max = LocalPlayer:GetAttribute("MaxFruitCapacity") or 100
    return current >= max
end

local function getPlantModel(prompt)
    if not prompt or not prompt.Parent then return nil end
    local current = prompt.Parent
    while current do
        if current:IsA("Model") and current:GetAttribute("PlantId") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function isNight()
    local nightVal = ReplicatedStorage:FindFirstChild("Night")
    return nightVal and nightVal.Value == true
end

local function disableRainbowAnimation()
    getgenv().DisableRainbow = true

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:GetAttribute("Mutation") == "Rainbow" then
            pcall(function()
                obj:SetAttribute("OriginalMutation", "Rainbow")
                obj:SetAttribute("Mutation", "None")
                CollectionService:RemoveTag(obj, "Rainbow")
            end)
        end
    end
end

local function enableRainbowAnimation()
    getgenv().DisableRainbow = false

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:GetAttribute("OriginalMutation") == "Rainbow" then
            pcall(function()
                obj:SetAttribute("OriginalMutation", nil)
                obj:SetAttribute("Mutation", "Rainbow")
                CollectionService:AddTag(obj, "Rainbow")
            end)
        end
    end
end

getgenv().disableRainbowAnimation = disableRainbowAnimation
getgenv().enableRainbowAnimation = enableRainbowAnimation

local function applyPlantState(descendant, disable)
    if descendant:IsA("BasePart") then
        if disable then
            descendant.LocalTransparencyModifier = 1
        else
            descendant.LocalTransparencyModifier = 0
        end
    elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
        if disable then
            if not descendant:GetAttribute("OriginalTransparency") then
                descendant:SetAttribute("OriginalTransparency", descendant.Transparency)
            end
            if descendant.Transparency ~= 1 then
                descendant.Transparency = 1
            end
        else
            local orig = descendant:GetAttribute("OriginalTransparency")
            if orig then
                descendant.Transparency = orig
                descendant:SetAttribute("OriginalTransparency", nil)
            end
        end
    elseif descendant:IsA("ParticleEmitter") or descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
        if disable then
            if descendant:GetAttribute("OriginalEnabled") == nil then
                descendant:SetAttribute("OriginalEnabled", descendant.Enabled)
            end
            if descendant.Enabled then
                descendant.Enabled = false
            end
        else
            local orig = descendant:GetAttribute("OriginalEnabled")
            if orig ~= nil then
                descendant.Enabled = orig
                descendant:SetAttribute("OriginalEnabled", nil)
            end
        end
    end
end

local function restoreAllPlants()
    local gardens = workspace:FindFirstChild("Gardens")
    if gardens then
        for _, plot in ipairs(gardens:GetChildren()) do
            local plants = plot:FindFirstChild("Plants")
            if plants then
                for _, plant in ipairs(plants:GetChildren()) do
                    for _, descendant in ipairs(plant:GetDescendants()) do
                        pcall(applyPlantState, descendant, false)
                    end
                end
            end
            task.wait(0.02)
        end
    end
end
getgenv().restoreAllPlants = restoreAllPlants

--// Daemons & Event Listeners
local function setupStockListeners(shopName)
    task.spawn(function()
        local items = getStockItems(shopName)
        if not items then return end

        local function connectValue(val)
            if not val:IsA("IntValue") and not val:IsA("NumberValue") then return end
            
            local conn = val.Changed:Connect(function(newVal)
                if newVal > 0 and scriptRunning then
                    triggerBuyItem(shopName, val.Name)
                end
            end)
            table.insert(conns, conn)
        end

        for _, val in ipairs(items:GetChildren()) do
            connectValue(val)
        end

        local connAdded = items.ChildAdded:Connect(function(val)
            connectValue(val)
            if val:IsA("IntValue") or val:IsA("NumberValue") then
                if val.Value > 0 and scriptRunning then
                    triggerBuyItem(shopName, val.Name)
                end
            end
        end)
        table.insert(conns, connAdded)
    end)
end

local function setupListeners()
    local lastPhase = workspace:GetAttribute("ActivePhase")
    local lastWeather = workspace:GetAttribute("ActiveWeather")
    
    local function checkWeatherWebhook()
        local phase = workspace:GetAttribute("ActivePhase") or "Unknown"
        local weather = workspace:GetAttribute("ActiveWeather") or "None"
        
        if phase ~= lastPhase or weather ~= lastWeather then
            lastPhase = phase
            lastWeather = weather
            
            if getgenv().WebhookEnabled and getgenv().WebhookPingWeather then
                local filter = getgenv().WebhookWeatherFilter
                local isAllowed = false
                if type(filter) == "table" then
                    if filter[phase] or filter[weather] then
                        isAllowed = true
                    end
                else
                    isAllowed = true
                end

                if isAllowed then
                    local contentStr = ""
                    local userId = getgenv().WebhookUserID
                    if userId and userId ~= "" then
                        contentStr = "<@" .. tostring(userId) .. ">"
                    end
                    
                    local sendWebhook = getgenv().sendWebhook
                    if sendWebhook then
                        task.spawn(function()
                            sendWebhook(getgenv().WebhookURL, {
                                content = contentStr,
                                embeds = {
                                    {
                                        title = "🌤️ Weather / Phase Update",
                                        description = string.format("**Phase:** %s\n**Weather:** %s", phase, weather),
                                        color = 10711287,
                                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                                        footer = {
                                            text = "Bob-Cat",
                                            icon_url = "https://raw.githubusercontent.com/nostrainu/Dump/main/Assets/pop_cat_smirk_closed.png"
                                        }
                                    }
                                }
                            })
                        end)
                    end
                end
            end
        end
    end

    table.insert(conns, workspace:GetAttributeChangedSignal("ActivePhase"):Connect(function()
        pcall(updateWeatherUI)
        pcall(checkWeatherWebhook)
    end))

    table.insert(conns, workspace:GetAttributeChangedSignal("ActiveWeather"):Connect(function()
        pcall(updateWeatherUI)
        pcall(checkWeatherWebhook)
    end))

    local weatherValues = ReplicatedStorage:WaitForChild("WeatherValues", 10)
    if weatherValues then
        for _, weather in ipairs(WeatherData.Data) do
            table.insert(conns, weatherValues:GetAttributeChangedSignal(weather.Name .. "_Playing"):Connect(function()
                pcall(updateWeatherUI)
                pcall(checkWeatherWebhook)
            end))
        end
    end

    setupStockListeners("SeedShop")
    setupStockListeners("GearShop")
    setupStockListeners("CrateShop")

    if Networking.SeedShop and Networking.SeedShop.PersonalRestock then
        local conn = Networking.SeedShop.PersonalRestock.OnClientEvent:Connect(function()
            task.wait(0.1)
            local selected = getgenv().SelectedSeed or {}
            for seedName, active in pairs(selected) do
                if active then
                    triggerBuyItem("SeedShop", seedName)
                end
            end
        end)
        table.insert(conns, conn)
    end

    if Networking.GearShop and Networking.GearShop.PersonalRestock then
        local conn = Networking.GearShop.PersonalRestock.OnClientEvent:Connect(function()
            task.wait(0.1)
            local selected = getgenv().SelectedGear or {}
            for gearName, active in pairs(selected) do
                if active then
                    triggerBuyItem("GearShop", gearName)
                end
            end
        end)
        table.insert(conns, conn)
    end

    if Networking.CrateShop and Networking.CrateShop.PersonalRestock then
        local conn = Networking.CrateShop.PersonalRestock.OnClientEvent:Connect(function()
            task.wait(0.1)
            local selected = getgenv().SelectedCrate or {}
            for crateName, active in pairs(selected) do
                if active then
                    triggerBuyItem("CrateShop", crateName)
                end
            end
        end)
        table.insert(conns, conn)
    end

    local connPopVFX = workspace.ChildAdded:Connect(function(child)
        if getgenv().DisablePlants and child.Name == "PopVFXModel" then
            task.defer(function()
                pcall(child.Destroy, child)
            end)
        end
    end)
    table.insert(conns, connPopVFX)

    table.insert(conns, CollectionService:GetInstanceAddedSignal("Rainbow"):Connect(function(obj)
        if getgenv().DisableRainbow then
            task.defer(pcall, function()
                obj:SetAttribute("OriginalMutation", "Rainbow")
                obj:SetAttribute("Mutation", "None")
                CollectionService:RemoveTag(obj, "Rainbow")
            end)
        end
    end))

    local gardens = workspace:FindFirstChild("Gardens")
    if gardens then
        local function connectPlot(plot)
            local plants = plot:FindFirstChild("Plants")
            if plants then
                local conn = plants.DescendantAdded:Connect(function(descendant)
                    if getgenv().DisablePlants then
                        pcall(applyPlantState, descendant, true)
                    end

                    local function checkRainbow()
                        if getgenv().DisableRainbow and descendant:GetAttribute("Mutation") == "Rainbow" then
                            pcall(function()
                                descendant:SetAttribute("OriginalMutation", "Rainbow")
                                descendant:SetAttribute("Mutation", "None")
                                CollectionService:RemoveTag(descendant, "Rainbow")
                            end)
                        end
                    end

                    checkRainbow()
                    local attrConn = descendant:GetAttributeChangedSignal("Mutation"):Connect(checkRainbow)
                    table.insert(conns, attrConn)
                end)
                table.insert(conns, conn)
            end
        end

        for _, plot in ipairs(gardens:GetChildren()) do
            connectPlot(plot)
        end

        local conn = gardens.ChildAdded:Connect(function(plot)
            connectPlot(plot)
        end)
        table.insert(conns, conn)
    end

end

local function shouldHarvestMutation(mutation)
    local selected = getgenv().HarvestMutation
    if type(selected) ~= "table" then
        return true
    end
    local anyActive = false
    for _, active in pairs(selected) do
        if active then
            anyActive = true
            break
        end
    end
    if not anyActive then
        return true
    end
    if selected[mutation] then
        return true
    end
    local lowerMutation = string.lower(mutation)
    for name, active in pairs(selected) do
        if active and string.lower(name) == lowerMutation then
            return true
        end
    end
    return false
end

local function shouldHarvestPlant(plantName)
    local selected = getgenv().HarvestPlant
    if type(selected) ~= "table" then
        return true
    end
    local anyActive = false
    for _, active in pairs(selected) do
        if active then
            anyActive = true
            break
        end
    end
    if not anyActive then
        return true
    end
    if selected[plantName] then
        return true
    end
    local lowerName = string.lower(plantName)
    for name, active in pairs(selected) do
        if active and string.lower(name) == lowerName then
            return true
        end
    end
    return false
end

local function handleAutoHarvestOwn()
    local myPlot = getPlayerPlot()
    if not myPlot then return end

    for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        if prompt.Enabled and prompt:IsDescendantOf(myPlot) then
            local model = getPlantModel(prompt)
            if model then
                local plantId = model:GetAttribute("PlantId")
                local fruitId = model:GetAttribute("FruitId")
                if plantId then
                    local mutation = model:GetAttribute("Mutation")
                    if not mutation or mutation == "" then
                        mutation = "Normal"
                    end
                    local harvestLimit = tonumber(getgenv().HarvestWeightLimit) or 0
                    local weight = getWeightValue(model)
                    if harvestLimit == 0 or weight < harvestLimit then
                        if shouldHarvestMutation(mutation) then
                            local seedName = model:GetAttribute("SeedName") or model:GetAttribute("CorePartName") or model:GetAttribute("Seed") or model:GetAttribute("PlantName") or model.Name
                            if shouldHarvestPlant(seedName) then
                                pcall(function()
                                    Networking.Garden.CollectFruit:Fire(plantId, fruitId or "")
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function handleAutoSteal()
    local myPlot = getPlayerPlot()
    local myPlotId = LocalPlayer:GetAttribute("PlotId")

    for _, prompt in ipairs(CollectionService:GetTagged("StealPrompt")) do
        if not scriptRunning or not (getgenv().AccountControl and getgenv().AccountControl.Steal) or isInventoryFull() then
            break
        end

        if prompt.Enabled then
            local isOwnPlot = false
            if myPlot and prompt:IsDescendantOf(myPlot) then
                isOwnPlot = true
            elseif myPlotId then
                local gardens = workspace:FindFirstChild("Gardens")
                local myPlotFolder = gardens and gardens:FindFirstChild("Plot" .. tostring(myPlotId))
                if myPlotFolder and prompt:IsDescendantOf(myPlotFolder) then
                    isOwnPlot = true
                end
            end

            if not isOwnPlot then
                local model = getPlantModel(prompt)
                if model then
                    local ownerUserId = model:GetAttribute("UserId")
                    local plantId = model:GetAttribute("PlantId")
                    local fruitId = model:GetAttribute("FruitId")
                    if ownerUserId and plantId and fruitId and fruitId ~= "" then
                        pcall(function()
                            Networking.Steal.BeginSteal:Fire(ownerUserId, plantId, fruitId)
                            task.wait(prompt.HoldDuration + 0.05)
                            Networking.Steal.CompleteSteal:Fire()
                        end)
                    end
                end
            end
        end
    end
end

--// Main Tab - Gardening Loops
task.spawn(function()
    while scriptRunning do
        if getgenv().Paused then
            task.wait(1)
        else
            local settings = getgenv().AccountControl or {}
            if isInventoryFull() then
                if settings.Sell then
                    handleAutoSell()
                end
            else
                local night = isNight()

                if settings.Harvest then
                    handleAutoHarvestOwn()
                elseif settings.Steal and night then
                    handleAutoHarvestOwn()
                end

                if settings.Steal and night then
                    handleAutoSteal()
                end
            end
            task.wait(0.1)
        end
    end
end)

--// Misc Tab - Weather Update Loop
task.spawn(function()
    while scriptRunning do
        pcall(updateWeatherUI)
        task.wait(1)
    end
end)

--// Shop Tab - Auto-Buy Loops
task.spawn(function()
    while scriptRunning do
        if getgenv().Paused then
            task.wait(1)
        else
            if getgenv().AutoBuySeed then
                pcall(handleAutoBuySeed)
            end
            if getgenv().AutoBuyGear then
                pcall(handleAutoBuyGear)
            end
            if getgenv().AutoBuyCrate then
                pcall(handleAutoBuyCrate)
            end
            task.wait(2.0)
        end
    end
end)

--// Misc Tab - Optimization Monitor Loop
task.spawn(function()
    local lastDisablePlants = nil
    local lastDisableRainbow = nil

    while scriptRunning do
        -- 1. Handle DisablePlants toggle
        local disablePlants = getgenv().DisablePlants
        if disablePlants ~= lastDisablePlants then
            lastDisablePlants = disablePlants
            if disablePlants then
                -- Apply transparency to all current plants
                local gardens = workspace:FindFirstChild("Gardens")
                if gardens then
                    for _, plot in ipairs(gardens:GetChildren()) do
                        local plants = plot:FindFirstChild("Plants")
                        if plants then
                            for _, plant in ipairs(plants:GetChildren()) do
                                for _, descendant in ipairs(plant:GetDescendants()) do
                                    pcall(applyPlantState, descendant, true)
                                end
                            end
                        end
                    end
                end
            else
                restoreAllPlants()
            end
        end

        -- 2. Clean up PopVFXModel if DisablePlants is active
        if disablePlants then
            for _, child in ipairs(workspace:GetChildren()) do
                if child.Name == "PopVFXModel" then
                    pcall(child.Destroy, child)
                end
            end
        end

        -- 3. Handle DisableRainbow toggle
        local disableRainbow = getgenv().DisableRainbow
        if disableRainbow ~= lastDisableRainbow then
            lastDisableRainbow = disableRainbow
            if disableRainbow then
                disableRainbowAnimation()
            else
                enableRainbowAnimation()
            end
        end

        task.wait(1.0)
    end
end)

--// ESP Tab - ESP Visualizer
local highlightedObjects = {}

local function clearESP()
    for target, highlight in pairs(highlightedObjects) do
        pcall(function() highlight:Destroy() end)
    end
    table.clear(highlightedObjects)
end
getgenv().clearESP = clearESP

local function applyHighlight(target, color)
    local highlight = highlightedObjects[target]
    if not highlight or not highlight.Parent then
        highlight = Instance.new("Highlight")
        highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = target
        highlight.Parent = target
        highlightedObjects[target] = highlight
    else
        highlight.Adornee = target
        highlight.Parent = target
        highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
    end
end

local function removeHighlight(target)
    local highlight = highlightedObjects[target]
    if highlight then
        pcall(function() highlight:Destroy() end)
        highlightedObjects[target] = nil
    end
end

local function toColor3(val, defaultColor)
    if type(val) == "string" then
        local success, color = pcall(Color3.fromHex, val)
        if success and color then
            return color
        end
    elseif typeof(val) == "Color3" then
        return val
    end
    return defaultColor or Color3.fromRGB(255, 255, 255)
end

local function updateESP()
    for target in pairs(highlightedObjects) do
        if not target or not target.Parent then
            highlightedObjects[target] = nil
        end
    end
    
    if not getgenv().ESPEnabled or not getgenv().ESPHighlight then
        clearESP()
        return
    end
    
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then
        clearESP()
        return
    end
    
    local myPlotId = LocalPlayer:GetAttribute("PlotId")
    local targetSetting = getgenv().ESPTarget or "All"
    local minWeight = tonumber(getgenv().ESPMinWeight) or 0
    local hColor = toColor3(getgenv().ESPHighlightColor, Color3.fromRGB(255, 255, 255))
    
    local selectedMutations = getgenv().ESPMutations or {}
    local selectedPlants = getgenv().ESPPlants or {}
    
    local filterMutations = false
    for _, active in pairs(selectedMutations) do
        if active then filterMutations = true break end
    end
    
    local filterPlants = false
    for _, active in pairs(selectedPlants) do
        if active then filterPlants = true break end
    end
    
    local activeTargets = {}
    
    for _, plot in ipairs(gardens:GetChildren()) do
        local isMyPlot = (plot.Name == "Plot" .. tostring(myPlotId))
        local shouldScanPlot = false
        if targetSetting == "All" then
            shouldScanPlot = true
        elseif targetSetting == "My Plot" and isMyPlot then
            shouldScanPlot = true
        elseif targetSetting == "Other Plots" and not isMyPlot then
            shouldScanPlot = true
        end
        
        if shouldScanPlot then
            local plantsFolder = plot:FindFirstChild("Plants")
            if plantsFolder then
                for _, plant in ipairs(plantsFolder:GetChildren()) do
                    local plantId = plant:GetAttribute("PlantId")
                    if plantId then
                        local hasFruit = (getFruitModel(plant) ~= nil)
                        
                        local weight = 0
                        if hasFruit then
                            weight = getWeightValue(plant)
                        end
                        
                        local passesWeight = true
                        if minWeight > 0 then
                            passesWeight = hasFruit and (weight >= minWeight)
                        end
                        
                        if passesWeight then
                            local mutation = plant:GetAttribute("Mutation")
                            if not mutation or mutation == "" then
                                mutation = "Normal"
                            end
                            local seedName = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName") or plant:GetAttribute("Seed") or plant:GetAttribute("PlantName") or plant.Name
                            
                            local matchesMutation = (not filterMutations) or selectedMutations[mutation]
                            local matchesPlant = (not filterPlants) or selectedPlants[seedName]
                            
                            if matchesMutation and matchesPlant then
                                local fruitsFolder = plant:FindFirstChild("Fruits")
                                local fruits = fruitsFolder and fruitsFolder:GetChildren()
                                
                                if fruits then
                                    for _, fruit in ipairs(fruits) do
                                        if fruit:IsA("Model") or fruit:IsA("BasePart") then
                                            activeTargets[fruit] = true
                                            applyHighlight(fruit, hColor)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    for target in pairs(highlightedObjects) do
        if not activeTargets[target] then
            removeHighlight(target)
        end
    end
end

--// ESP Tab - ESP Update Loop
task.spawn(function()
    while scriptRunning do
        pcall(updateESP)
        task.wait(0.5)
    end
end)

--// Misc Tab - Webhook Scanner Loop
task.spawn(function()
    while scriptRunning do
        local success, err = pcall(checkPlotPlantsForWebhooks)
        if not success then
            warn("[GaG2 Webhook Scanner Error]: " .. tostring(err))
        end
        task.wait(2.0)
    end
end)

--// Teleport & Auto-Execute
local queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport)
if queue_on_teleport then
    pcall(function()
        local queued = false
        local conn = game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(State)
            local autoExecute = false
            pcall(function()
                if getgenv().GaG2Config and getgenv().GaG2Config.AutoExecute ~= nil then
                    autoExecute = getgenv().GaG2Config.AutoExecute
                end
            end)
            if queued then return end
            if autoExecute and (State == Enum.TeleportState.Started or State == Enum.TeleportState.InProgress) then
                queued = true
                queue_on_teleport([[
                    repeat task.wait(0.5) until game:IsLoaded()
                    repeat task.wait(0.5) until game:GetService("Players").LocalPlayer
                    task.wait(8)
                    if not getgenv().uiActive then
                        local repo = "https://raw.githubusercontent.com/nostrainu/Poop-Cat/main/Main/GaG2/"
                        local success, err = pcall(function()
                            local funcContent = game:HttpGet(repo .. "GaG2Func.lua?t=" .. os.time())
                            local func, funcErr = loadstring(funcContent)
                            if not func then error("GaG2Func loadstring failed: " .. tostring(funcErr)) end
                            func()
                            
                            _G.UILoaded = nil
                            _G.LastUILoadTime = nil
                            
                            local mainContent = game:HttpGet(repo .. "GaG2Main.lua?t=" .. os.time())
                            local main, mainErr = loadstring(mainContent)
                            if not main then error("GaG2Main loadstring failed: " .. tostring(mainErr)) end
                            main()
                        end)
                        if not success then
                            warn("[Grow a Garden 2 AutoExecute Queued] Execution error: " .. tostring(err))
                        end
                    end
                ]])
            end
        end)
        table.insert(conns, conn)
    end)
end

--// Script Initialization
setupListeners()
pcall(updateWeatherUI)

if not isWorker and getgenv().BobcatWS then
    getgenv().BobcatWS.ConnectHost("GaG2", game:GetService("Players").LocalPlayer.Name)
end
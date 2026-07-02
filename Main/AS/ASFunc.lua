--// Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

--// Account Control
getgenv().AccountControl = {
    AutoJoin = getgenv().AutoJoin,
    AutoChallenge = getgenv().AutoChallenge,
    MapRotation = getgenv().MapRotation,
    AutoSummon = getgenv().AutoSummon,
    AutoRedeemCodes = getgenv().AutoRedeemCodes,
}

getgenv().IsFarmingActive = function()
    local ac = getgenv().AccountControl or {}
    return not not (ac.AutoJoin or ac.AutoChallenge or ac.MapRotation or ac.AutoSummon)
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

getgenv().getProfilePath = function(profileName)
    local host = getgenv().Host
    if profileName == "Main" then
        if host and host ~= "" then
            return "bobcat/games/AS/config_" .. host .. ".json"
        else
            return "bobcat/games/AS/config.json"
        end
    else
        if host and host ~= "" then
            return "bobcat/games/AS/alts/" .. host .. "_" .. profileName .. ".json"
        else
            return "bobcat/games/AS/alts/" .. profileName .. ".json"
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
            if not isfolder("bobcat/games/AS/alts") then
                makefolder("bobcat/games/AS/alts")
            end
            writefile(altPath, HttpService:JSONEncode(data))
        end)
    end)
end

getgenv().saveActiveProfile = function()
    if getgenv().Automation == true or getgenv().Automitation == true then return end
    local success, err = pcall(function()
        if not isfolder("bobcat") then makefolder("bobcat") end
        if not isfolder("bobcat/games") then makefolder("bobcat/games") end
        if not isfolder("bobcat/games/AS") then makefolder("bobcat/games/AS") end
        if getgenv().activeProfile ~= "Main" then
            if not isfolder("bobcat/games/AS/alts") then makefolder("bobcat/games/AS/alts") end
        end
        
        local profilePath = getgenv().getProfilePath(getgenv().activeProfile)
        writefile(profilePath, HttpService:JSONEncode(getgenv().activeConfigTable))
    end)
    if not success then
        warn("[AS Profile Save Error]: " .. tostring(err))
    end
end

getgenv().saveProfile = function()
    getgenv().saveActiveProfile()
end

getgenv().startupDiscoverAlts = function()
    local host = getgenv().Host
    if not host or host == "" then return end
    
    local config = getgenv().config or {}
    local changed = false
    if config.Accounts then
        for i = #config.Accounts, 1, -1 do
            if config.Accounts[i].Name == host then
                table.remove(config.Accounts, i)
                changed = true
            end
        end
    end
    
    local folder = "bobcat/games/AS/alts"
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

getgenv().runWorker = function()
    local host = getgenv().Host
    if not host or host == "" then
        warn("[AS] Host not specified. Aborting control.")
        return
    end
    
    local folder = "bobcat"
    local altFolder = "bobcat/games/AS/alts"
    local altPath = altFolder .. "/" .. host .. "_" .. LocalPlayer.Name .. ".json"
    local confirmedPath = "bobcat/games/AS/confirmed_" .. host .. "_" .. LocalPlayer.Name .. ".json"
    
    local makeFolderSuccess, makeFolderErr = pcall(function()
        if not isfolder(folder) then makefolder(folder) end
        if not isfolder("bobcat/games") then makefolder("bobcat/games") end
        if not isfolder("bobcat/games/AS") then makefolder("bobcat/games/AS") end
        if not isfolder(altFolder) then makefolder(altFolder) end
    end)
    if not makeFolderSuccess then
        warn("[AS makefolder Error]: " .. tostring(makeFolderErr))
    end

    local confirmed = nil
    if isfile(altPath) or isfile(confirmedPath) then
        confirmed = true
    else
        local repo = "https://raw.githubusercontent.com/nostrainu/ObsidianFork/main/"
        local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
        
        if not Library then
            warn("[AS] Failed to load library for confirmation. Aborting control.")
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
                            warn("[AS writefile Error]: " .. tostring(err))
                        end
                    end
                },
                {
                    Text = "No",
                    Color = Color3.fromRGB(200, 50, 50),
                    Callback = function()
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
                                if getgenv().config then
                                    getgenv().config[k] = v
                                end
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
                                        if k == "MapRotation" then
                                            task.spawn(function()
                                                pcall(function()
                                                    if getgenv().initMapRotation then
                                                        getgenv().initMapRotation()
                                                    end
                                                end)
                                            end)
                                        end
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
                
                local hostConfigPath = "bobcat/games/AS/config_" .. host .. ".json"
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
                    local status = "Working"
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
                    
                    configData.Coins = getgenv().getInventoryTotal("Yen") or 0
                    configData.Gems = getgenv().getInventoryTotal("Gems") or 0
                    configData.PerfectCubes = getgenv().getInventoryTotal("Perfect Cubes") or 0
                    configData.RerollCubes = getgenv().getInventoryTotal("Reroll Cubes") or 0
                    configData.TraitShards = getgenv().getInventoryTotal("Trait Shards") or 0
                    
                    writefile(altPath, HttpService:JSONEncode(configData))
                end
            end)
            if shouldExit then break end
            task.wait(0.2)
        end
    end)
end

--// Configuration
local path = "bobcat/games/AS/config.json"

local function ensurePathFolders(filePath)
    local parts = {}
    for part in string.gmatch(filePath, "[^/]+") do
        table.insert(parts, part)
    end
    if #parts > 1 then
        local current = ""
        for i = 1, #parts - 1 do
            current = current == "" and parts[i] or current .. "/" .. parts[i]
            if not isfolder(current) then
                pcall(makefolder, current)
            end
        end
    end
end

getgenv().ensurePathFolders = ensurePathFolders

local config = {}
getgenv().config = config
getgenv().updatingUI = false

local function save()
    if getgenv().Automation == true or getgenv().Automitation == true then return end
    if getgenv().saveActiveProfile then
        getgenv().saveActiveProfile()
    else
        local success, err = pcall(function()
            ensurePathFolders(path)
            writefile(path, HttpService:JSONEncode(config))
        end)
        if not success then
            warn("[Config Error] Failed to save config: " .. tostring(err))
        end
    end
end

getgenv().registerSetting = function(name, defaultValue)
    if name == "SelectedMap" then
        if getgenv().config[name] == nil or getgenv().config[name] == "Ninja Village" then
            getgenv().config[name] = ""
        end
        defaultValue = ""
    elseif name == "SelectedMode" then
        defaultValue = defaultValue or "Story"
    elseif name == "SelectedDifficulty" then
        defaultValue = defaultValue or "Normal"
    elseif name == "SelectedLevel" then
        defaultValue = defaultValue or "1"
    elseif name == "ChallengeRewardFilter" then
        defaultValue = defaultValue or {}
    end
    
    local configTable = getgenv().config or {}
    if configTable[name] == nil or (configTable[name] == "" and name ~= "SelectedMap") then
        configTable[name] = defaultValue
    end
    if name == "ChallengeType" and type(configTable[name]) == "string" then
        configTable[name] = { [configTable[name]] = true }
        save()
    end
    getgenv()[name] = configTable[name]
    return configTable[name]
end

getgenv().isStartup = true
getgenv().MatchStarted = false
getgenv().TransitionNewMatch = false

getgenv().setConfig = function(name, val)
    if getgenv().updatingUI then return end
    
    if getgenv().Automation == true or getgenv().Automitation == true then
        if getgenv().config then
            getgenv().config[name] = val
        end
        getgenv()[name] = val
        if getgenv().AccountControl and getgenv().AccountControl[name] ~= nil then
            getgenv().AccountControl[name] = val
        end
        return
    end
    
    if getgenv().isSyncingUI then
        if getgenv().activeProfile == "Main" then
            getgenv()[name] = val
            if getgenv().AccountControl and getgenv().AccountControl[name] ~= nil then
                getgenv().AccountControl[name] = val
            end
        end
        return
    end

    local activeConfigTable = getgenv().activeConfigTable or getgenv().config or {}
    activeConfigTable[name] = val
    
    if getgenv().debouncedSave then
        getgenv().debouncedSave()
    else
        save()
    end
    
    if getgenv().activeProfile == "Main" then
        getgenv()[name] = val
        if getgenv().AccountControl and getgenv().AccountControl[name] ~= nil then
            getgenv().AccountControl[name] = val
        end
    end
    
    local selectedAlts = getgenv().selectedAlts or {}
    for altName, isSelected in pairs(selectedAlts) do
        if isSelected then
            local altData = getgenv().getProfileData(altName) or {}
            altData[name] = val
            local host = getgenv().Host
            if host and host ~= "" then
                altData.Host = host
            end
            getgenv().writeProfileData(altName, altData)
        end
    end
end

getgenv().SyncUI = function()
    if getgenv().updatingUI then return end
    getgenv().updatingUI = true
    
    pcall(function()
        for key, value in pairs(getgenv().config) do
            local option = getgenv().Library and getgenv().Library.Options and getgenv().Library.Options[key]
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
            local toggle = getgenv().Library and getgenv().Library.Toggles and getgenv().Library.Toggles[key]
            if toggle then
                pcall(function()
                    toggle:SetValue(value)
                end)
            end
        end
    end)
    
    getgenv().updatingUI = false
end

local function sendDiscordWebhook(title, description, fields, thumbnailUrl, content)
    local webhookUrl = getgenv().config and getgenv().config.WebhookURL
    if not webhookUrl or webhookUrl == "" or not webhookUrl:find("discord.com") then
        return
    end
    
    local embeds = {
        {
            title = title,
            description = description,
            color = 10711287,
            fields = fields or {},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = {
                text = "Bob-Cat",
                icon_url = "https://raw.githubusercontent.com/nostrainu/Dump/main/Assets/pop_cat_smirk_closed.png"
            }
        }
    }
    
    if thumbnailUrl then
        embeds[1].thumbnail = { url = thumbnailUrl }
    end
    
    local payload = HttpService:JSONEncode({
        content = content,
        embeds = embeds
    })
    
    local req = http_request or request or (syn and syn.request)

    local maxRetries = 3
    for attempt = 1, maxRetries do
        local success, response = pcall(function()
            if req then
                return req({
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = payload
                })
            else
                return HttpService:PostAsync(webhookUrl, payload, Enum.HttpContentType.ApplicationJson)
            end
        end)

        if not success then
            warn("[Webhook Error] Request failed: " .. tostring(response))
            break
        end

        local statusCode = type(response) == "table" and (response.StatusCode or response.status_code) or nil
        if statusCode == 429 then
            local retryAfter = 5
            pcall(function()
                local body = type(response.Body) == "string" and HttpService:JSONDecode(response.Body) or nil
                if body and body.retry_after then
                    retryAfter = tonumber(body.retry_after) or 5
                end
            end)
            task.wait(retryAfter + 0.5)
        else
            break
        end
    end
end

getgenv().sendDiscordWebhook = sendDiscordWebhook

local function isSecretUnit(name)
    if not name or name == "" then return false end
    
    local lowerName = name:lower()
    if lowerName:find("madora") or lowerName:find("shanron") or lowerName:find("skeleton") or lowerName:find("baras") or lowerName:find("garu") or lowerName:find("berserker") then
        return true
    end
    
    return false
end
getgenv().isSecretUnit = isSecretUnit


getgenv().getLabelText = function(action)
    local lower = string.lower(action or "")
    if string.find(lower, "spawn") or string.find(lower, "place") then
        return "Spawn"
    elseif string.find(lower, "upgrade") then
        return "Upgrade"
    elseif string.find(lower, "ultimate") then
        return "Ultimate"
    end
    return "Action"
end

getgenv().formatUnitName = function(action, name, cost)
    if not cost or cost == 0 then
        if string.find(string.lower(action or ""), "upgrade") then
            cost = getgenv().Macro:GetUpgradeCost(name)
        else
            cost = getgenv().Macro:GetSpawnCost(name)
        end
    end
    if cost and cost > 0 then
        return string.format("%s | ¥ %d", name, cost)
    end
    return name
end

local function GetRemote(name)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    if string.find(name, "/") then
        local current = remotes
        for part in string.gmatch(name, "[^/]+") do
            current = current:FindFirstChild(part)
            if not current then return nil end
        end
        return current
    end
    return remotes:FindFirstChild(name, true)
end

--// Macro 
local MacroFolder = "bobcat/games/AS/macros"

local Macro = {
    IsRecording = false,
    IsPlaying = false,
    Recording = {},
    RecordQueue = {},
    StartTime = 0,
    LastActionTime = 0,
    PlaybackThread = nil,
    hookmetamethod = nil,
    OnRecord = nil,
    CharacterMap = {},
    HasPlayedThisMatch = false,
    HasHandledEnd = false,
    HasJoinedRoom = false,
}

task.spawn(function()
    while true do
        if getgenv().uiActive == false and not getgenv().isStartup then break end
        if Macro.RecordQueue and #Macro.RecordQueue > 0 then
            local item = table.remove(Macro.RecordQueue, 1)
            pcall(function()
                Macro:RecordAction(item.actionType, item.args)
            end)
        end
        task.wait(0.05)
    end
end)

--// Character Map
function Macro:UpdateCharacterMap(...)
    local allies = select(1, ...)
    local playerData = select(3, ...)
    
    if typeof(allies) == "table" then
        for _, unit in ipairs(allies) do
            if typeof(unit) == "table" and unit.data_id and unit.name then
                self.CharacterMap[unit.data_id] = unit.name
            end
        end
    end
    
    if typeof(playerData) == "table" and playerData.characters then
        for id, charData in pairs(playerData.characters) do
            if typeof(charData) == "table" and charData.name then
                self.CharacterMap[id] = charData.name
            end
        end
    end
end

function Macro:ResolveName(val)
    local isInstance, name = pcall(function() return val.Name end)
    local isClass, className = pcall(function() return val.ClassName end)
    local res
    if isInstance and typeof(name) == "string" and isClass and typeof(className) == "string" then
        res = name
    elseif typeof(val) == "string" then
        if self.CharacterMap[val] then
            res = self.CharacterMap[val]
        else
            res = val
        end
    else
        res = tostring(val or "?")
    end
    return res
end

local function ensureFolder()
    ensurePathFolders(MacroFolder .. "/dummy.json")
end

local function getUnitStaticData(unitName)
    local characters = ReplicatedStorage:FindFirstChild("Characters")
    local charFolder = characters and characters:FindFirstChild(unitName)
    if charFolder and charFolder:FindFirstChild("data") then
        local ok, data = pcall(require, charFolder.data)
        if ok and data then
            return data
        end
    end
    return nil
end

local function getCostReduction(unitName)
    local ok, Helper = pcall(require, ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Helper"))
    if ok and Helper and Helper.data and typeof(Helper.data) == "table" and Helper.data.characters then
        for _, charData in pairs(Helper.data.characters) do
            if charData.name == unitName and charData.equipped then
                local reduction = 1
                if charData.trait == "Entrepreneur" or charData.trait_2 == "Entrepreneur" then
                    reduction = reduction * 0.6
                end
                if charData.trait == "Wealthy" or charData.trait_2 == "Wealthy" then
                    reduction = reduction * 0.85
                end
                return reduction
            end
        end
    end
    return 1
end

function Macro:GetUpgradeCostAtLevel(unitName, currentLevel)
    local data = getUnitStaticData(unitName)
    if data and data.cost then
        local multiplier = data.upgrades and data.upgrades.cost or 1
        local reduction = getCostReduction(unitName)
        return math.floor(data.cost * (multiplier ^ currentLevel) * reduction)
    end
    return 0
end

function Macro:GetUpgradeCost(unitName)
    return self:GetUpgradeCostAtLevel(unitName, 0)
end

function Macro:GetSpawnCost(unitName)
    local data = getUnitStaticData(unitName)
    if data and data.cost then
        local reduction = getCostReduction(unitName)
        return math.floor(data.cost * reduction)
    end
    return 0
end

local lastRecordedStep = nil

local yenInstance = nil
local yenAttributeName = nil

local function getPlayerYen()
    local ply = game:GetService("Players").LocalPlayer
    if not ply then 
        return 0 
    end
    
    if yenInstance then
        local ok, val = pcall(function() return yenInstance.Value end)
        if ok and typeof(val) == "number" then 
            return val 
        end
        yenInstance = nil
    end
    
    if yenAttributeName then
        local val = ply:GetAttribute(yenAttributeName)
        if typeof(val) == "number" then return val end
        yenAttributeName = nil
    end

    for _, attr in ipairs({"yen", "Yen", "gold", "Gold", "money", "Money"}) do
        local val = ply:FindFirstChild(attr)
        if val and (val:IsA("ValueInstance") or val:IsA("NumberValue") or val:IsA("IntValue")) then
            yenInstance = val
            return val.Value
        end
    end
    
    local leaderstats = ply:FindFirstChild("leaderstats")
    if leaderstats then
        for _, attr in ipairs({"yen", "Yen", "gold", "Gold", "money", "Money"}) do
            local lVal = leaderstats:FindFirstChild(attr)
            if lVal and (lVal:IsA("ValueInstance") or lVal:IsA("NumberValue") or lVal:IsA("IntValue")) then
                yenInstance = lVal
                return lVal.Value
            end
        end
    end
    
    for _, attr in ipairs({"yen", "Yen"}) do
        local aVal = ply:GetAttribute(attr)
        if typeof(aVal) == "number" then
            yenAttributeName = attr
            return aVal
        end
    end
    
    return 0
end

--// Remote Hooking
function Macro:RecordAction(actionType, args)
    if not getgenv().MacroRecord then 
        return 
    end

    if lastRecordedStep and lastRecordedStep.action == actionType and tick() - lastRecordedStep.time < 0.05 then
        local identical = true
        for i = 1, math.max(#args, #lastRecordedStep.args) do
            if args[i] ~= lastRecordedStep.args[i] then
                identical = false
                break
            end
        end
        if identical then 
            return 
        end
    end

    local now = tick()
    lastRecordedStep = { action = actionType, args = args, time = now }

    local delay = now - self.LastActionTime
    self.LastActionTime = now

    local currentYen = 0
    pcall(function()
        currentYen = getPlayerYen()
    end)

    local cost = 0
    local lowerAction = string.lower(actionType or "")
    local unitName = self:ResolveName(args[1])
    self.RecordingLevels = self.RecordingLevels or {}

    if string.find(lowerAction, "upgrade") then
        local currentLevel = self.RecordingLevels[unitName] or 0
        cost = self:GetUpgradeCostAtLevel(unitName, currentLevel)
        self.RecordingLevels[unitName] = currentLevel + 1
    elseif string.find(lowerAction, "spawn") or string.find(lowerAction, "place") then
        cost = self:GetSpawnCost(unitName)
    end

    table.insert(self.Recording, {
        action = actionType,
        args = args,
        delay = delay,
        yen = currentYen,
        cost = cost,
    })

    if self.OnRecord then
        pcall(function()
            self.OnRecord(#self.Recording, actionType, args, cost)
        end)
    end
end

function Macro:StartRecording()
    self.Recording = {}
    self.RecordingLevels = {}
    self.IsRecording = true
    self.StartTime = tick()
    self.LastActionTime = tick()
    self:InstallHooks()
end

function Macro:StopRecording()
    self.IsRecording = false
    self:RemoveHooks()
end

function Macro:InstallHooks()
end

function Macro:RemoveHooks()
end

--// File Management
function Macro:SaveMacro(name)
    if not name or name == "" then return false end
    ensureFolder()

    local steps = {}
    for i, step in ipairs(self.Recording) do
        local lowerAction = string.lower(step.action or "")
        steps[tostring(i)] = {
            type = string.find(lowerAction, "upgrade") and "Upgrade" or "Place",
            action = step.action,
            args = step.args,
            delay = step.delay,
            yen = step.yen,
            cost = step.cost,
        }
    end

    local exportData = {
        steps = steps,
        characterMap = self.CharacterMap
    }

    local path = MacroFolder .. "/" .. name .. ".json"
    writefile(path, HttpService:JSONEncode(exportData))
    return true
end

function Macro:LoadMacro(name)
    local path = MacroFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if ok and data then
        self.Recording = {}

        if data.characterMap and typeof(data.characterMap) == "table" then
            for uuid, charName in pairs(data.characterMap) do
                self.CharacterMap[uuid] = charName
            end
        end

        local stepsData = data.steps or data
        local tempSteps = {}
        local isFlat = false
        for key, step in pairs(stepsData) do
            local stepNum = tonumber(key)
            if stepNum and typeof(step) == "table" then
                tempSteps[stepNum] = step
                isFlat = true
            end
        end

        if isFlat then
            local maxStep = 0
            for stepNum, _ in pairs(tempSteps) do
                if stepNum > maxStep then
                    maxStep = stepNum
                end
            end
            for i = 1, maxStep do
                if tempSteps[i] then
                    table.insert(self.Recording, tempSteps[i])
                end
            end
        elseif data.steps then
            self.Recording = data.steps
        end

        return true
    end
    return false
end

function Macro:DeleteMacro(name)
    local path = MacroFolder .. "/" .. name .. ".json"
    if isfile(path) then
        delfile(path)
        return true
    end
    return false
end

function Macro:GetMacroList()
    ensureFolder()
    local list = {}

    for _, file in ipairs(listfiles(MacroFolder)) do
        local name = file:match("([^/\\]+)%.json$")
        if name then
            table.insert(list, name)
        end
    end

    table.sort(list)
    return list
end

--// Playback 
function Macro:Play(loop, delayMultiplier, waitForYen, onStep, onFinish)
    if #self.Recording == 0 then
        return false
    end
    if self.IsPlaying then
        return false
    end
    if (getgenv().isInLobby and getgenv().isInLobby()) or (getgenv().isMidGame and not getgenv().isMidGame()) then
        return false
    end

    self.IsPlaying = true
    delayMultiplier = delayMultiplier or 0.2

    self.PlaybackThread = task.spawn(function()
        repeat
            local currentPlaybackLevels = {}
            for i, step in ipairs(self.Recording) do
                if not self.IsPlaying then 
                    break 
                end
                if (getgenv().isInLobby and getgenv().isInLobby()) or (getgenv().isMidGame and not getgenv().isMidGame()) then
                    self.IsPlaying = false
                    break
                end

                local lowerAction = string.lower(step.action or "")
                local unitName = self:ResolveName(step.args[1])
                local requiredYen = step.cost or 0
                local stepType = "Other"

                if string.find(lowerAction, "upgrade") then
                    stepType = "Upgrade"
                    local currentLevel = currentPlaybackLevels[unitName] or 0
                    requiredYen = self:GetUpgradeCostAtLevel(unitName, currentLevel)
                elseif string.find(lowerAction, "spawn") or string.find(lowerAction, "place") then
                    stepType = "Place"
                    requiredYen = self:GetSpawnCost(unitName)
                end

                if onStep then
                    pcall(function()
                        onStep(i, #self.Recording, step)
                    end)
                end

                if waitForYen and requiredYen > 0 then
                    while self.IsPlaying do
                        local currentYen = 0
                        pcall(function()
                            currentYen = getPlayerYen()
                        end)
                        if currentYen >= requiredYen then
                            break
                        end
                        task.wait(0.1)
                        if (getgenv().isInLobby and getgenv().isInLobby()) or (getgenv().isMidGame and not getgenv().isMidGame()) then
                            self.IsPlaying = false
                            break
                        end
                    end
                end

                if not self.IsPlaying then 
                    break 
                end

                if delayMultiplier > 0 then
                    local elapsed = 0
                    while elapsed < delayMultiplier and self.IsPlaying do
                        task.wait(0.05)
                        elapsed = elapsed + 0.05
                        if (getgenv().isInLobby and getgenv().isInLobby()) or (getgenv().isMidGame and not getgenv().isMidGame()) then
                            self.IsPlaying = false
                            break
                        end
                    end
                end

                if not self.IsPlaying then 
                    break 
                end

                local remote = GetRemote(step.action)
                if remote then
                    pcall(function()
                        if remote:IsA("RemoteEvent") then
                            remote:FireServer(unpack(step.args))
                        else
                            remote:InvokeServer(unpack(step.args))
                        end
                    end)
                    
                    if stepType == "Upgrade" then
                        currentPlaybackLevels[unitName] = (currentPlaybackLevels[unitName] or 0) + 1
                    end
                else
                    warn("[Macro Play] Remote not found:", tostring(step.action))
                end
            end
        until not loop or not self.IsPlaying

        self.IsPlaying = false
        if onFinish then
            pcall(onFinish)
        end
    end)

    return true
end

function Macro:Stop()
    self.IsPlaying = false
    if self.PlaybackThread then
        pcall(task.cancel, self.PlaybackThread)
        self.PlaybackThread = nil
    end
end

--// Autoplay Triggers
function Macro:Cleanup()
    self:Stop()
    self:StopRecording()
    self:RemoveHooks()
    if self.EndingConnection then
        pcall(function() self.EndingConnection:Disconnect() end)
        self.EndingConnection = nil
    end
    if self.StartConnection then
        pcall(function() self.StartConnection:Disconnect() end)
        self.StartConnection = nil
    end
    if self.TeleportConnection then
        pcall(function() self.TeleportConnection:Disconnect() end)
        self.TeleportConnection = nil
    end
end

task.spawn(function()
    while not getgenv().Library do task.wait(0.1) end
    getgenv().Library:OnUnload(function()
        Macro:Cleanup()
    end)
end)

local lobbyMenu = nil
local createRoomRemote = nil

local function isInLobby()
    local ply = game:GetService("Players").LocalPlayer
    if not ply then return false end
    
    if lobbyMenu and createRoomRemote then
        local ok, isLobbyVisible = pcall(function()
            return lobbyMenu.Parent and createRoomRemote.Parent
        end)
        if ok and isLobbyVisible then
            return true
        else
            lobbyMenu = nil
            createRoomRemote = nil
        end
    end
    
    local playerGui = ply:FindFirstChild("PlayerGui")
    local menus = playerGui and playerGui:FindFirstChild("Menus")
    local lobby = menus and menus:FindFirstChild("Lobby")
    if not lobby then return false end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local playRemotes = remotes and remotes:FindFirstChild("Play")
    local createRoom = playRemotes and playRemotes:FindFirstChild("create_room")
    if not createRoom then return false end
    
    lobbyMenu = lobby
    createRoomRemote = createRoom
    return true
end
getgenv().isInLobby = isInLobby

local cachedEndScreen = nil
local function isMidGame()
    local ply = game:GetService("Players").LocalPlayer
    if not ply then return false end
    
    if cachedEndScreen and cachedEndScreen.Parent then
        local endScreenVisible = false
        pcall(function() endScreenVisible = cachedEndScreen.Visible end)
        return not endScreenVisible
    end
    
    local playerGui = ply:FindFirstChild("PlayerGui")
    local menus = playerGui and playerGui:FindFirstChild("Menus")
    local endScreen = menus and menus:FindFirstChild("EndScreen")
    if endScreen then
        cachedEndScreen = endScreen
        local endScreenVisible = false
        pcall(function() endScreenVisible = endScreen.Visible end)
        return not endScreenVisible
    end
    
    return true
end
getgenv().isMidGame = isMidGame

local lastDescendantCheck = 0
local function isGameActive()
    if getgenv().MatchStarted then
        return true
    end
    
    if getgenv().TransitionNewMatch then
        local elapsed = os.time() - (getgenv().TransistionStartTime or 0)
        if elapsed > 60 then
            getgenv().TransitionNewMatch = false
        else
            local ply = game:GetService("Players").LocalPlayer
            local playerGui = ply and ply:FindFirstChild("PlayerGui")
            if playerGui then
                local now = tick()
                if now - lastDescendantCheck > 2 then
                    lastDescendantCheck = now
                    for _, desc in ipairs(playerGui:GetDescendants()) do
                        if desc:IsA("TextLabel") and desc.Visible then
                            local text = desc.Text
                            if string.find(text, "Wave") or string.find(text, "WAVE") or string.find(text, "wave") then
                                getgenv().MatchStarted = true
                                getgenv().TransitionNewMatch = false
                                Macro.HasHandledEnd = false
                                getgenv().MatchStartTime = os.time()
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end
    end
    
    local ply = game:GetService("Players").LocalPlayer
    local playerGui = ply and ply:FindFirstChild("PlayerGui")
    if playerGui then
        local now = tick()
        if now - lastDescendantCheck > 2 then
            lastDescendantCheck = now
            for _, desc in ipairs(playerGui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible then
                    local text = desc.Text
                    if string.find(text, "Wave") or string.find(text, "WAVE") or string.find(text, "wave") then
                        getgenv().MatchStarted = true
                        getgenv().TransitionNewMatch = false
                        Macro.HasHandledEnd = false
                        getgenv().MatchStartTime = os.time()
                        return true
                    end
                end
            end
        end
    end
    
    if workspace.DistributedGameTime > 20 then
        getgenv().MatchStarted = true
        getgenv().TransitionNewMatch = false
        Macro.HasHandledEnd = false
        getgenv().MatchStartTime = os.time()
        return true
    end
    
    return false
end
getgenv().isGameActive = isGameActive

function Macro:TriggerAutoplay()
    if getgenv().Library and getgenv().Library.Unloaded then return end
    if getgenv().isInLobby and getgenv().isInLobby() then return end
    if getgenv().isMidGame and not getgenv().isMidGame() then return end
    if not isGameActive() then return end
    
    if getgenv().Library and getgenv().Library.Toggles and getgenv().Library.Toggles.MacroPlay and getgenv().Library.Toggles.MacroPlay.Value then
        if not self.HasPlayedThisMatch then
            self.HasPlayedThisMatch = true
            
            pcall(function()
                local macroToLoad = nil
                local mode = getgenv().config.SelectedMode or "Story"
                if mode == "Raid" then
                    macroToLoad = getgenv().config.SelectedRaidAct
                else
                    local map = getgenv().config.SelectedMap or ""
                    local lvl = tostring(getgenv().config.SelectedLevel or "1")
                    macroToLoad = map .. " " .. lvl
                end
                
                if macroToLoad then
                    local loaded = self:LoadMacro(macroToLoad)
                    if not loaded and mode ~= "Raid" then
                        local map = getgenv().config.SelectedMap or ""
                        local lvl = tostring(getgenv().config.SelectedLevel or "1")
                        local alts = {
                            map .. " Lvl " .. lvl,
                            map .. " Level " .. lvl,
                            map .. " Act " .. lvl,
                            map .. "_" .. lvl
                        }
                        for _, alt in ipairs(alts) do
                            if self:LoadMacro(alt) then
                                macroToLoad = alt
                                loaded = true
                                break
                            end
                        end
                    end
                    if loaded then
                        if getgenv().Library and getgenv().Library.Options and getgenv().Library.Options.MacroSelect then
                            pcall(function()
                                getgenv().Library.Options.MacroSelect:SetValue(macroToLoad)
                            end)
                        end
                    end
                end
            end)
            
            local speedVal
            local autoSpeedEnabled = false
            pcall(function()
                if getgenv().Library and getgenv().Library.Toggles and getgenv().Library.Toggles.AutoSpeedToggle then
                    autoSpeedEnabled = getgenv().Library.Toggles.AutoSpeedToggle.Value
                elseif getgenv().config and getgenv().config.AutoSpeedToggle ~= nil then
                    autoSpeedEnabled = getgenv().config.AutoSpeedToggle
                end
            end)
            if autoSpeedEnabled then
                pcall(function()
                    if getgenv().Library.Options and getgenv().Library.Options.AutoSpeed then
                        speedVal = tonumber(getgenv().Library.Options.AutoSpeed.Value)
                    elseif getgenv().config and getgenv().config.AutoSpeed then
                        speedVal = tonumber(getgenv().config.AutoSpeed)
                    end
                end)
                if speedVal then
                    pcall(function()
                        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("change_speed"):InvokeServer(speedVal)
                    end)
                end
            end

            task.delay(1.5, function()
                local macroPlay = false
                pcall(function()
                    if getgenv().Library and not getgenv().Library.Unloaded and getgenv().Library.Toggles.MacroPlay then
                        macroPlay = getgenv().Library.Toggles.MacroPlay.Value
                    elseif getgenv().config and getgenv().config.MacroPlay ~= nil then
                        macroPlay = getgenv().config.MacroPlay
                    end
                end)
                if macroPlay then
                    self:StartPlayback()
                end
            end)
        end
    end
end

task.spawn(function()
    local startEvent
    while not startEvent and (getgenv().uiActive ~= false or getgenv().isStartup) do
        pcall(function() startEvent = ReplicatedStorage.Remotes.Visuals.start end)
        if not startEvent then task.wait(0.5) end
    end
    if startEvent then
        if Macro.StartConnection then
            pcall(function() Macro.StartConnection:Disconnect() end)
        end
        Macro.StartConnection = startEvent.OnClientEvent:Connect(function(...)
            local args = {...}
            pcall(function() Macro:UpdateCharacterMap(unpack(args)) end)
            Macro.HasHandledEnd = false
            getgenv().MatchStarted = true
            getgenv().TransitionNewMatch = false
            getgenv().MatchStartTime = os.time()
            Macro:TriggerAutoplay()
        end)
    end
end)

task.spawn(function()
    task.wait(0.5)
    while getgenv().uiActive ~= false or getgenv().isStartup do
        local inLobby = isInLobby()
        if not inLobby then
            if isMidGame() and isGameActive() then
                Macro:TriggerAutoplay()
            end
        end
        task.wait(0.5)
    end
end)

local function formatNumber(val)
    if not val then return "0" end
    local intVal = math.floor(tonumber(val) or 0)
    return tostring(intVal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
getgenv().formatNumber = formatNumber

local lastPlayerData = nil
local lastPlayerDataTime = 0
local function getPlayerData()
    local now = tick()
    if lastPlayerData and (now - lastPlayerDataTime) < 0.5 then
        return lastPlayerData
    end
    local localPlayer = game:GetService("Players").LocalPlayer
    if localPlayer then
        local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
        local clientFolder = playerScripts and playerScripts:FindFirstChild("Client")
        local utilityModule = clientFolder and clientFolder:FindFirstChild("Utility")
        if utilityModule and utilityModule:IsA("ModuleScript") then
            local success, utility = pcall(require, utilityModule)
            if success and type(utility) == "table" and utility.data then
                lastPlayerData = utility.data
                lastPlayerDataTime = now
                return utility.data
            end
        end
    end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local playersFolder = remotes:FindFirstChild("Players") or remotes:FindFirstChild("Player")
    if not playersFolder then return nil end
    local getRemote = playersFolder:FindFirstChild("get")
    if getRemote and getRemote:IsA("RemoteFunction") then
        local success, data = pcall(function()
            return getRemote:InvokeServer(nil, true)
        end)
        if success and typeof(data) == "table" then
            lastPlayerData = data
            lastPlayerDataTime = now
            return data
        end
    end
    return nil
end

local function getPlayerLevel()
    local pd = getPlayerData()
    if pd and pd.stats and pd.stats.level then
        return pd.stats.level
    end
    local lvl = 0
    pcall(function()
        local expLabel = game:GetService("Players").LocalPlayer.PlayerGui.Hotbar.BottomUI.LevelBar.Exp
        local text = expLabel.Text
        local levelMatch = text:match("Level%s*<font[^>]*>(%d+)</font>") or text:match("Level%s*(%d+)")
        if levelMatch then
            lvl = tonumber(levelMatch) or 0
        end
    end)
    if lvl == 0 then
        local ply = game:GetService("Players").LocalPlayer
        local levelObj = ply and (ply:FindFirstChild("level") or ply:FindFirstChild("Level"))
        if levelObj and (levelObj:IsA("ValueInstance") or levelObj:IsA("NumberValue") or levelObj:IsA("IntValue")) then
            lvl = levelObj.Value
        end
    end
    if lvl == 0 then
        local ply = game:GetService("Players").LocalPlayer
        local leaderstats = ply and ply:FindFirstChild("leaderstats")
        if leaderstats then
            local lvlVal = leaderstats:FindFirstChild("level") or leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("lvl") or leaderstats:FindFirstChild("Lvl")
            if lvlVal and (lvlVal:IsA("ValueInstance") or lvlVal:IsA("NumberValue") or lvlVal:IsA("IntValue")) then
                lvl = lvlVal.Value
            end
        end
    end
    if lvl == 0 then
        local ply = game:GetService("Players").LocalPlayer
        local attr = ply and (ply:GetAttribute("level") or ply:GetAttribute("Level") or ply:GetAttribute("lvl") or ply:GetAttribute("Lvl"))
        if typeof(attr) == "number" then
            lvl = attr
        end
    end
    return lvl
end

local function getInventoryTotal(itemName)
    local pd = getPlayerData()
    local lowerName = itemName:lower()
    if pd then
        if lowerName == "yen" or lowerName == "gold" then
            if pd.stats and pd.stats.Gold then return pd.stats.Gold end
        elseif lowerName == "gems" or lowerName == "gem" then
            if pd.stats and pd.stats.Gems then return pd.stats.Gems end
        elseif lowerName == "perfect stats" or lowerName == "perfect cubes" or lowerName == "perfect" then
            if pd.stats and pd.stats["Perfect Cubes"] then return pd.stats["Perfect Cubes"] end
            if pd.items and pd.items["Perfect Cubes"] then return pd.items["Perfect Cubes"] end
        elseif lowerName == "trait reroll" or lowerName == "reroll cubes" or lowerName == "reroll" or lowerName == "trait rerolls" then
            if pd.stats and pd.stats["Reroll Cubes"] then return pd.stats["Reroll Cubes"] end
            if pd.items and pd.items["Reroll Cubes"] then return pd.items["Reroll Cubes"] end
        elseif lowerName == "trait shard" or lowerName == "trait shards" or lowerName == "shards" then
            if pd.stats and pd.stats["Trait Shards"] then return pd.stats["Trait Shards"] end
            if pd.items and pd.items["Trait Shards"] then return pd.items["Trait Shards"] end
        end
        if pd.stats then
            if pd.stats[itemName] then return pd.stats[itemName] end
            if pd.stats[lowerName] then return pd.stats[lowerName] end
            for k, v in pairs(pd.stats) do
                if k:lower() == lowerName then return v end
            end
        end
        if pd.items then
            if pd.items[itemName] then return pd.items[itemName] end
            if pd.items[lowerName] then return pd.items[lowerName] end
            for k, v in pairs(pd.items) do
                if k:lower() == lowerName then return v end
            end
        end
    end
    local ply = game:GetService("Players").LocalPlayer
    if not ply then return nil end
    local function search(parent)
        if not parent then return nil end
        for _, child in ipairs(parent:GetChildren()) do
            local cn = child.Name:lower()
            if (cn == lowerName or cn:find(lowerName) or lowerName:find(cn)) and (child:IsA("ValueInstance") or child:IsA("NumberValue") or child:IsA("IntValue")) then
                return child.Value
            end
        end
        return nil
    end
    local val = search(ply)
    if val then return val end
    val = search(ply:FindFirstChild("leaderstats"))
    if val then return val end
    val = search(ply:FindFirstChild("Data") or ply:FindFirstChild("Stats") or ply:FindFirstChild("PlayerData"))
    if val then return val end
    pcall(function()
        local sf = ply:FindFirstChild("PlayerGui")
            and ply.PlayerGui:FindFirstChild("Menus")
            and ply.PlayerGui.Menus:FindFirstChild("Items")
            and ply.PlayerGui.Menus.Items:FindFirstChild("ScrollingFrame")
        if sf then
            for _, child in ipairs(sf:GetChildren()) do
                if child.Name:lower() == lowerName then
                    local qty = child:FindFirstChild("Quantity")
                    if qty then
                        if qty:IsA("TextLabel") or qty:IsA("TextBox") then
                            local num = tonumber(qty.Text:match("%d+"))
                            if num then val = num end
                        elseif qty:IsA("ValueInstance") or qty:IsA("NumberValue") or qty:IsA("IntValue") then
                            val = qty.Value
                        end
                    end
                end
            end
        end
    end)
    if val then return val end
    for attr, v in pairs(ply:GetAttributes()) do
        local an = attr:lower()
        if (an == lowerName or an:find(lowerName) or lowerName:find(an)) and type(v) == "number" then
            return v
        end
    end
    return nil
end
getgenv().getInventoryTotal = getInventoryTotal

local function getEquippedUnits()
    local units = {}
    pcall(function()
        local towers = game:GetService("Players").LocalPlayer.PlayerGui.Hotbar.BottomUI.Towers
        for _, child in ipairs(towers:GetChildren()) do
            if child:IsA("GuiObject") and child.Name:lower() ~= "character" then
                local nameObj = child:FindFirstChild("Name") or child:FindFirstChild("UnitName") or child:FindFirstChild("Title")
                local name = nameObj and nameObj:IsA("TextLabel") and nameObj.Text or child.Name
                local lvlObj = child:FindFirstChild("Level") or child:FindFirstChild("Lvl") or child:FindFirstChild("LevelLabel")
                local lvl = ""
                if lvlObj and lvlObj:IsA("TextLabel") then
                    lvl = lvlObj.Text
                else
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("TextLabel") and desc ~= nameObj and desc.Visible and (desc.Name:lower():find("lvl") or desc.Name:lower():find("level") or desc.Text:match("^%d+$") or desc.Text:match("^Lvl")) then
                            lvl = desc.Text
                            break
                        end
                    end
                end
                local cleanLvl = lvl:match("%d+")
                local lvlPrefix = cleanLvl and string.format("[%s] ", cleanLvl) or ""
                table.insert(units, lvlPrefix .. name)
            end
        end
    end)
    if #units == 0 then
        pcall(function()
            local hotbar = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") and game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Hotbar")
            if hotbar then
                for _, child in ipairs(hotbar:GetDescendants()) do
                    if child:IsA("Frame") and child.Visible and child.Name ~= "TowerManager" and child.Name ~= "List" then
                        local nameObj = child:FindFirstChild("Name") or child:FindFirstChild("UnitName") or child:FindFirstChild("Title")
                        if nameObj and nameObj:IsA("TextLabel") and nameObj.Visible and nameObj.Text ~= "" then
                            local name = nameObj.Text
                            local lvlObj = child:FindFirstChild("Level") or child:FindFirstChild("Lvl") or child:FindFirstChild("LevelLabel")
                            local lvl = ""
                            if lvlObj and lvlObj:IsA("TextLabel") then
                                lvl = lvlObj.Text
                            else
                                for _, desc in ipairs(child:GetDescendants()) do
                                    if desc:IsA("TextLabel") and desc ~= nameObj and desc.Visible and (desc.Name:lower():find("lvl") or desc.Name:lower():find("level") or desc.Text:match("^%d+$") or desc.Text:match("^Lvl")) then
                                        lvl = desc.Text
                                        break
                                    end
                                end
                            end
                            local cleanLvl = lvl:match("%d+")
                            local lvlPrefix = cleanLvl and string.format("[%s] - ", cleanLvl) or ""
                            table.insert(units, lvlPrefix .. name)
                        end
                    end
                end
            end
        end)
    end
    return units
end

function Macro:HandleGameEnd(immediate)
    if not getgenv().MatchStarted then return end
    if self.HasHandledEnd then return end
    self.HasHandledEnd = true

    if not immediate then
        getgenv().SessionRuns = (getgenv().SessionRuns or 0) + 1
    end

    local completedMode = getgenv().config.SelectedMode
    local completedWorld = getgenv().config.SelectedMap
    local completedAct = getgenv().config.SelectedLevel

    local parsedUI = false
    pcall(function()
        local ply = game:GetService("Players").LocalPlayer
        local menus = ply and ply:FindFirstChild("PlayerGui") and ply.PlayerGui:FindFirstChild("Menus")
        local actsFrame = menus and menus:FindFirstChild("Play") and menus.Play:FindFirstChild("Acts")
        if actsFrame then
            for _, btn in ipairs(actsFrame:GetChildren()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local unselected = btn:FindFirstChild("Unselected")
                    if unselected and not unselected.Visible then
                        local nameLabel = btn:FindFirstChild("WorldName") or btn:FindFirstChild("ContentText")
                        if nameLabel and nameLabel.Text ~= "" then
                            local t = nameLabel.Text
                            local num = t:match("%d+")
                            if num then
                                completedAct = num
                            else
                                completedAct = t:gsub("^%s+", ""):gsub("%s+$", "")
                            end
                            parsedUI = true
                        end
                        break
                    end
                end
            end
        end
    end)

    if not parsedUI then
        pcall(function()
            local ply = game:GetService("Players").LocalPlayer
            local label = ply and ply:FindFirstChild("PlayerGui")
                and ply.PlayerGui:FindFirstChild("Hotbar")
                and ply.PlayerGui.Hotbar:FindFirstChild("Info")
                and ply.PlayerGui.Hotbar.Info:FindFirstChild("World")
                and ply.PlayerGui.Hotbar.Info.World:FindFirstChild("TextLabel")
                
            if label and label.Text ~= "" then
                local text = label.Text
                local parsedWorld = text:match("^(.+)%s*-%s*[Aa]ct")
                local parsedAct = text:match("[Aa]ct%.?%s*(%d+)")
                if parsedWorld then
                    completedWorld = parsedWorld:gsub("^%s+", ""):gsub("%s+$", "")
                    parsedUI = true
                end
                if parsedAct then
                    completedAct = parsedAct
                    parsedUI = true
                end
            end
        end)
    end

    if getgenv().amc then
        completedMode = getgenv().amc.mode or completedMode
        if getgenv().amc.difficulty and getgenv().amc.difficulty ~= "" then
            completedMode = completedMode .. " " .. getgenv().amc.difficulty
        end
        if not parsedUI then
            completedWorld = getgenv().amc.world or completedWorld
        end
        local rawAct = tonumber(tostring(getgenv().amc.act):match("%d+")) or 0
        if rawAct == 0 then rawAct = 1 end
        completedAct = rawAct
    end

    local fallbackDuration = nil
    if getgenv().MatchStartTime then
        fallbackDuration = os.time() - getgenv().MatchStartTime
    end
    getgenv().MatchStartTime = nil

    if getgenv().config and getgenv().config.MapRotation and not immediate then
        local config = getgenv().config
        local limit = tonumber(config.PriorityRunsLimit) or 5
        local currentIndex = getgenv().CurrentPriorityIndex or 1
        local previewRuns = (getgenv().CurrentModeRuns or 0) + 1
        getgenv().MapRotationLastRunInfo = {
            index = currentIndex,
            runs = previewRuns,
            limit = limit,
        }
    end

    if getgenv().config and getgenv().config.AutoChallengeWebhook and not immediate then
        task.spawn(function()
            pcall(function()
                local ply = game:GetService("Players").LocalPlayer
                local endScreen = ply and ply:FindFirstChild("PlayerGui") and ply.PlayerGui:FindFirstChild("Menus") and ply.PlayerGui.Menus:FindFirstChild("EndScreen")
                
                local elapsed = 0
                while elapsed < 5 do
                    local isVisible = false
                    if endScreen then
                        isVisible = endScreen.Visible or (endScreen:IsA("ScreenGui") and endScreen.Enabled)
                    end
                    if isVisible then break end
                    task.wait(0.5)
                    elapsed = elapsed + 0.5
                end
                
                task.wait(0.5)
                
                local clearTimeText = "N/A"
                if endScreen then
                    for _, desc in ipairs(endScreen:GetDescendants()) do
                        if desc:IsA("TextLabel") and desc.Visible then
                            local t = desc.Text
                            local tLower = t:lower()
                            if tLower:find("play time") or tLower:find("playtime") then
                                local m, s = t:match("(%d+):(%d+)")
                                if m and s then
                                    clearTimeText = t
                                    break
                                else
                                    local parent = desc.Parent
                                    if parent then
                                        for _, sibling in ipairs(parent:GetChildren()) do
                                            if sibling:IsA("TextLabel") and sibling ~= desc and sibling.Visible then
                                                local st = sibling.Text
                                                local sm, ss = st:match("(%d+):(%d+)")
                                                if sm and ss then
                                                    clearTimeText = st
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if clearTimeText ~= "N/A" then break end
                        end
                    end
                    
                    if clearTimeText == "N/A" then
                        for _, desc in ipairs(endScreen:GetDescendants()) do
                            if desc:IsA("TextLabel") and desc.Visible then
                                local t = desc.Text
                                local m, s = t:match("(%d+):(%d+)")
                                if m and s then
                                    local numM = tonumber(m)
                                    local numS = tonumber(s)
                                    if numM and numS and numS < 60 then
                                        clearTimeText = t
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                
                if clearTimeText == "N/A" then
                    local duration = fallbackDuration or workspace.DistributedGameTime
                    if duration and duration > 0 then
                        local minutes = math.floor(duration / 60)
                        local seconds = math.floor(duration % 60)
                        clearTimeText = string.format("%dm %ds", minutes, seconds)
                    end
                end
                
                local statusText = "Completed"
                if endScreen then
                    for _, desc in ipairs(endScreen:GetDescendants()) do
                        if desc:IsA("TextLabel") and desc.Visible then
                            local t = desc.Text:lower()
                            if t:find("victory") or t:find("won") or t:find("win") or t:find("clear") then
                                statusText = "Victory"
                                break
                            elseif t:find("defeat") or t:find("lost") or t:find("failed") or t:find("lose") then
                                statusText = "Defeat"
                                break
                            end
                        end
                    end
                end
                
                local rewards = {}
                if endScreen then
                    for _, desc in ipairs(endScreen:GetDescendants()) do
                        if desc:IsA("TextLabel") and desc.Visible and desc.Text ~= "" then
                            local rawText = desc.Text
                            local t = rawText:gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
                            local count = t:match("^x%d+") or t:match("^%+%d+")
                            if count then
                                local parent = desc.Parent
                                local itemName = parent and parent.Name
                                if parent then
                                    for _, sibling in ipairs(parent:GetChildren()) do
                                        if sibling:IsA("TextLabel") and sibling ~= desc and sibling.Visible and sibling.Text ~= "" then
                                            local rawSiblingText = sibling.Text
                                            local st = rawSiblingText:gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
                                            if not st:match("^x%d+") and not st:match("^%+%d+") and not st:find("%%") and not st:lower():find("chance") and not st:lower():find("drop") then
                                                itemName = st
                                                break
                                            end
                                        end
                                    end
                                end
                                if itemName and itemName ~= "" and itemName ~= "Template" and itemName ~= "Amount" and itemName ~= "Count" 
                                   and not itemName:find("%%") and not itemName:lower():find("chance") and not itemName:lower():find("drop") then
                                    local itemIcon = nil
                                    if parent then
                                        for _, sibling in ipairs(parent:GetChildren()) do
                                            if sibling:IsA("ImageLabel") then
                                                itemIcon = sibling.Image
                                                break
                                            end
                                        end
                                        if not itemIcon then
                                            for _, sibling in ipairs(parent:GetDescendants()) do
                                                if sibling:IsA("ImageLabel") then
                                                    itemIcon = sibling.Image
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    rewards[itemName] = { count = count, icon = itemIcon }
                                end
                            end
                        end
                    end
                    
                    if next(rewards) == nil then
                        for _, desc in ipairs(endScreen:GetDescendants()) do
                            if desc:IsA("TextLabel") and desc.Visible and desc.Text ~= "" then
                                local rawText = desc.Text
                                local t = rawText:gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
                                local lower = t:lower()
                                if lower:find("yen") or lower:find("crystal") or lower:find("gem") or lower:find("exp") or lower:find("scroll") or lower:find("token") then
                                    local hasNum = t:match("%d+")
                                    if hasNum then
                                        local name = t
                                        local value = ""
                                        local parts = {}
                                        for part in t:gmatch("[^:]+") do
                                            table.insert(parts, part)
                                        end
                                        if #parts >= 2 then
                                            name = parts[1]:gsub("^%s+", ""):gsub("%s+$", "")
                                            value = parts[2]:gsub("^%s+", ""):gsub("%s+$", "")
                                        end
                                        
                                        local itemIcon = nil
                                        local parent = desc.Parent
                                        if parent then
                                            for _, sibling in ipairs(parent:GetChildren()) do
                                                if sibling:IsA("ImageLabel") then
                                                    itemIcon = sibling.Image
                                                    break
                                                end
                                            end
                                            if not itemIcon then
                                                for _, sibling in ipairs(parent:GetDescendants()) do
                                                    if sibling:IsA("ImageLabel") then
                                                        itemIcon = sibling.Image
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                        
                                        if value ~= "0" and value ~= "" then
                                            rewards[name] = { count = value, icon = itemIcon }
                                        elseif #parts < 2 then
                                            rewards[name] = { count = "", icon = itemIcon }
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                local yenGained = 0
                pcall(function()
                    local yenLabel = endScreen.Right.YenEarned.Amount
                    local cleanText = yenLabel.Text:gsub("[%+x,%s¥%$]", "")
                    yenGained = tonumber(cleanText) or 0
                end)
                
                local expGained = 0
                pcall(function()
                    local expLabel = endScreen.Right.ExpEarned.Amount
                    local cleanText = expLabel.Text:gsub("[%+x,%s]", "")
                    expGained = tonumber(cleanText) or 0
                end)
                
                if yenGained > 0 and not rewards["Gold"] and not rewards["Yen"] then
                    rewards["Gold"] = { count = "+" .. tostring(yenGained), icon = nil }
                end
                if expGained > 0 and not rewards["XP"] and not rewards["Exp"] then
                    rewards["XP"] = { count = "+" .. tostring(expGained), icon = nil }
                end

                local gemsGained = 0
                local perfectGained = 0
                local rerollGained = 0
                for name, info in pairs(rewards) do
                    local ln = name:lower()
                    local cleanText = info.count:gsub("[%+x,%s]", "")
                    local val = tonumber(cleanText) or 0
                    if ln == "gems" or ln == "gem" then
                        gemsGained = val
                    elseif ln == "perfect stats" or ln == "perfect cubes" or ln == "perfect" then
                        perfectGained = val
                    elseif ln == "trait reroll" or ln == "reroll cubes" or ln == "reroll" or ln == "trait rerolls" then
                        rerollGained = val
                    end
                end
                
                local rewardsList = {}
                local primaryRewardName = nil
                for name, info in pairs(rewards) do
                    local count = info.count
                    local amtStr = count ~= "" and " " .. count or ""
                    
                    local displayName = name
                    if displayName == "Gold" then
                        displayName = "Yen"
                    end
                    
                    local totalVal = getInventoryTotal(name)
                    local totalStr = ""
                    if totalVal then
                        local formattedTotal = tostring(totalVal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                        totalStr = string.format(" [x%s]", formattedTotal)
                    end
                    table.insert(rewardsList, string.format("- **%s**%s%s", displayName, amtStr, totalStr))
                    if not primaryRewardName then
                        primaryRewardName = name
                    end
                end
                local rewardsText = #rewardsList > 0 and table.concat(rewardsList, "\n") or "None"
                
                local world = completedWorld
                local act = completedAct
                local mode = completedMode
                
                pcall(function()
                    if endScreen and (endScreen.Visible or (endScreen:IsA("ScreenGui") and endScreen.Enabled)) then
                        local stats = endScreen:FindFirstChild("Stats")
                        if stats then
                            local chapterLabel = stats:FindFirstChild("Chapter")
                            local worldLabel = stats:FindFirstChild("World")
                            local modeLabel = stats:FindFirstChild("Mode")
                            local diffLabel = stats:FindFirstChild("Difficulty")
                            
                            if worldLabel and worldLabel.Text ~= "" then
                                world = worldLabel.Text
                            end
                            if chapterLabel and chapterLabel.Text ~= "" then
                                local cleaned = chapterLabel.Text:gsub("<[^>]+>", "")
                                local num = cleaned:match("%d+")
                                if num then
                                    act = num
                                else
                                    act = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
                                end
                            end
                            if modeLabel and modeLabel.Text ~= "" then
                                local completedM = modeLabel.Text
                                if diffLabel and diffLabel.Text ~= "" and diffLabel.Text:lower() ~= "normal" then
                                    completedM = completedM .. " " .. diffLabel.Text
                                end
                                mode = completedM
                            end
                        end
                    end
                end)
                
                local ply = game:GetService("Players").LocalPlayer
                local userName = ply and ply.Name or "Unknown"
                local userLevel = getPlayerLevel()
                
                local currentExp, maxExp = 0, 0
                local pd = getPlayerData()
                if pd and pd.stats and pd.stats.XP and pd.stats.level then
                    currentExp = pd.stats.XP
                    maxExp = pd.stats.level * 150
                else
                    pcall(function()
                        local expLabel = game:GetService("Players").LocalPlayer.PlayerGui.Hotbar.BottomUI.LevelBar.Exp
                        local text = expLabel.Text
                        local c, m = text:match("%[(%d+)/(%d+)%]") or text:match("(%d+)/(%d+)")
                        if c and m then
                            currentExp = tonumber(c) or 0
                            maxExp = tonumber(m) or 0
                        end
                    end)
                end
                
                local levelStr = tostring(userLevel)
                if maxExp > 0 then
                    local expGainStr = expGained > 0 and string.format(" +%d", expGained) or ""
                    levelStr = string.format("%s (%s/%s XP)%s", tostring(userLevel), formatNumber(currentExp), formatNumber(maxExp), expGainStr)
                end
                
                local equippedUnits = getEquippedUnits()
                local unitsText = #equippedUnits > 0 and table.concat(equippedUnits, "\n") or "None"
                
                local statsList = {}
                local selected = getgenv().config and getgenv().config.WebhookItems or { ["Yen"] = true, ["Gems"] = true, ["Perfect Cubes"] = true, ["Reroll Cubes"] = true }
                local order = getgenv().initialWebhookItems or {
                    "Yen", "Gems", "Perfect Cubes", "Reroll Cubes", "Trait Shards"
                }
                local processed = {}
                for _, name in ipairs(order) do
                    processed[name] = true
                    if selected[name] then
                        local val = getInventoryTotal(name) or 0
                        local gainStr = ""
                        if name == "Yen" and yenGained > 0 then
                            gainStr = string.format(" (+%s)", formatNumber(yenGained))
                        elseif name == "Gems" and gemsGained > 0 then
                            gainStr = string.format(" (+%s)", formatNumber(gemsGained))
                        elseif (name == "Perfect Cubes" or name == "Perfect Stats") and perfectGained > 0 then
                            gainStr = string.format(" (+%s)", formatNumber(perfectGained))
                        elseif (name == "Reroll Cubes" or name == "Trait Reroll") and rerollGained > 0 then
                            gainStr = string.format(" (+%s)", formatNumber(rerollGained))
                        end
                        table.insert(statsList, string.format("- **%s:** %s%s", name, formatNumber(val), gainStr))
                    end
                end
                for name, isSelected in pairs(selected) do
                    if isSelected and not processed[name] then
                        local val = getInventoryTotal(name) or 0
                        table.insert(statsList, string.format("- **%s:** %s", name, formatNumber(val)))
                    end
                end
                local playerStatsText = #statsList > 0 and table.concat(statsList, "\n") or "None"
                
                local sessionStartTime = getgenv().SessionStartTime or os.time()
                getgenv().SessionStartTime = sessionStartTime
                local elapsedSecs = os.time() - sessionStartTime
                local h = math.floor(elapsedSecs / 3600)
                local m = math.floor((elapsedSecs % 3600) / 60)
                local s = elapsedSecs % 60
                local sessionTimeStr = string.format("%02d:%02d:%02d", h, m, s)
                local runsCount = getgenv().SessionRuns or 0
                local runsLine = string.format("[Total: %s | %d Runs]", sessionTimeStr, runsCount)
                
                local descriptionText = string.format(
                    "**Player Infos**\n**User :** ||%s||\n**Level :** ||%s||\n\n**Player Stats**\n%s\n\n**Player Units**\n%s\n\n**Rewards**\n%s\n\n**Match Result**\n%s (Act %s) - %s\n%s - %s\n%s",
                    userName,
                    levelStr,
                    playerStatsText,
                    unitsText,
                    rewardsText,
                    world,
                    act,
                    mode,
                    clearTimeText,
                    statusText,
                    runsLine
                )
                
                local pingContent = nil
                if getgenv().config and getgenv().config.PingSecretUnit then
                    local hasSecret = false
                    for name, _ in pairs(rewards) do
                        if getgenv().isSecretUnit and getgenv().isSecretUnit(name) then
                            hasSecret = true
                            break
                        end
                    end
                    if hasSecret then
                        local userId = getgenv().config.DiscordUserID or ""
                        if userId ~= "" then
                            pingContent = "<@" .. tostring(userId) .. ">"
                        end
                    end
                end

                if not immediate and getgenv().sendDiscordWebhook then
                    getgenv().sendDiscordWebhook(
                        "Anime Squadron",
                        descriptionText,
                        {},
                        nil,
                        pingContent
                    )
                end
            end)
        end)
    end

    if self.IsRecording then
        getgenv().MacroStatus = "Finished"
        if getgenv().Library and getgenv().Library.Toggles and getgenv().Library.Toggles.MacroRecord then
            getgenv().Library.Toggles.MacroRecord:SetValue(false)
        else
            self:StopRecording()
        end
    end
    if self.IsPlaying then
        self:Stop()
    end
    self.HasPlayedThisMatch = false
    getgenv().MatchStarted = false
    getgenv().TransitionNewMatch = true
    getgenv().TransistionStartTime = os.time()
    getgenv().MacroStatus = "Stopped"
    
    if getgenv().Library then
        pcall(function()
            if self.StatusLabel then
                self.StatusLabel:Update({ State = "Stopped", Current = "None", Next = "None" })
            end
        end)
    end

    task.spawn(function()
        local ply = game:GetService("Players").LocalPlayer
        local endScreen = ply and ply:FindFirstChild("PlayerGui") and ply.PlayerGui:FindFirstChild("Menus") and ply.PlayerGui.Menus:FindFirstChild("EndScreen")
        
        local isVictory = false
        if not immediate then
            local elapsed = 0
            while elapsed < 5 do
                local isVisible = false
                if endScreen then
                    pcall(function()
                        isVisible = endScreen.Visible or (endScreen:IsA("ScreenGui") and endScreen.Enabled)
                    end)
                end
                if isVisible then break end
                task.wait(0.5)
                elapsed = elapsed + 0.5
            end
            task.wait(0.5)

            if endScreen then
                for _, desc in ipairs(endScreen:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Visible then
                        local t = desc.Text:lower()
                        if t:find("victory") or t:find("won") or t:find("win") or t:find("clear") then
                            isVictory = true
                            break
                        end
                    end
                end
            end
        else
            task.wait(0.2)
        end

        getgenv().MapRotationIsVictory = isVictory

        if not immediate then
            local config = getgenv().config
            if config and config.MapRotation then
                getgenv().MapRotationJustCycled = false
                getgenv().MapRotationIsConsecutive = false

                local limit = tonumber(config.PriorityRunsLimit) or 5
                if isVictory then
                    local currentRuns = (getgenv().CurrentModeRuns or 0) + 1
                    getgenv().CurrentModeRuns = currentRuns
                    setConfig("CurrentModeRuns", currentRuns)

                    getgenv().MapRotationLastRunInfo = {
                        index = getgenv().CurrentPriorityIndex or 1,
                        runs = currentRuns,
                        limit = limit
                    }

                    if currentRuns >= limit then
                        local nextIndex = (getgenv().CurrentPriorityIndex or 1) + 1
                        if nextIndex > 3 then nextIndex = 1 end

                        local currentIndex = getgenv().CurrentPriorityIndex or 1
                        local currentMode = config["Priority" .. currentIndex] or "None"
                        local currentMap = config["Priority" .. currentIndex .. "Map"] or ""
                        local currentDiff = config["Priority" .. currentIndex .. "Difficulty"] or "Normal"
                        local currentLevelStr = config["Priority" .. currentIndex .. "Level"] or "1"
                        local currentLevel = tonumber(tostring(currentLevelStr):match("%d+")) or 1

                        local nextMode = config["Priority" .. nextIndex] or "None"
                        local nextMap = config["Priority" .. nextIndex .. "Map"] or ""
                        local nextDiff = config["Priority" .. nextIndex .. "Difficulty"] or "Normal"
                        local nextLevelStr = config["Priority" .. nextIndex .. "Level"] or "1"
                        local nextLevel = tonumber(tostring(nextLevelStr):match("%d+")) or 1

                        local consecutive = false
                        local isValidMode = (currentMode == "Story" or currentMode == "Raid" or currentMode == "Squadron")
                        if isValidMode and currentMode == nextMode and currentMap == nextMap and currentDiff == nextDiff and nextLevel == (currentLevel + 1) then
                            consecutive = true
                        end

                        getgenv().CurrentPriorityIndex = nextIndex
                        setConfig("CurrentPriorityIndex", nextIndex)
                        getgenv().CurrentModeRuns = 0
                        setConfig("CurrentModeRuns", 0)

                        getgenv().MapRotationJustCycled = true
                        getgenv().MapRotationIsConsecutive = consecutive

                        task.delay(1, function()
                            if getgenv().initMapRotation then
                                getgenv().initMapRotation()
                            end
                        end)
                    end
                else
                    getgenv().MapRotationLastRunInfo = {
                        index = getgenv().CurrentPriorityIndex or 1,
                        runs = getgenv().CurrentModeRuns or 0,
                        limit = limit,
                        isDefeat = true
                    }
                end
            end
        end

        local autoReplay = false
        local autoNext = false

        pcall(function()
            if getgenv().Library and getgenv().Library.Toggles then
                if getgenv().Library.Toggles.AutoReplay then
                    autoReplay = getgenv().Library.Toggles.AutoReplay.Value
                end
                if getgenv().Library.Toggles.AutoNext then
                    autoNext = getgenv().Library.Toggles.AutoNext.Value
                end
            else
                autoReplay = getgenv().config.AutoReplay
                autoNext = getgenv().config.AutoNext
            end
        end)

        local config = getgenv().config
        if config and config.MapRotation then
            if getgenv().MapRotationJustCycled then
                if getgenv().MapRotationIsConsecutive and getgenv().MapRotationIsVictory then
                    autoReplay = false
                    autoNext = true
                else
                    autoReplay = false
                    autoNext = false
                end
            else
                autoReplay = true
                autoNext = false
            end
        end

        task.wait(1.5)

        if autoReplay then
            pcall(function()
                game:GetService("ReplicatedStorage").Remotes.Game.replay:FireServer()
            end)
        elseif autoNext then
            pcall(function()
                local nextWorld = getgenv().config.SelectedMap or ""
                local nextAct = tonumber(tostring(getgenv().config.SelectedLevel):match("%d+")) or 1
                local nextMode = getgenv().config.SelectedMode or "Story"
                local nextDiff = getgenv().config.SelectedDifficulty or "Normal"

                if not (getgenv().config and getgenv().config.MapRotation) then
                    local curAct = getgenv().amc and getgenv().amc.act or tonumber(tostring(getgenv().config.SelectedLevel):match("%d+")) or 1
                    nextAct = curAct + 1
                    nextWorld = getgenv().amc and getgenv().amc.world or nextWorld
                    nextMode = getgenv().amc and getgenv().amc.mode or nextMode
                    nextDiff = getgenv().amc and getgenv().amc.difficulty or nextDiff
                end

                writefile("bobcat/games/AS/temp_match.json", HttpService:JSONEncode({
                    mode = nextMode,
                    world = nextWorld,
                    act = nextAct,
                    difficulty = nextDiff
                }))
            end)
            pcall(function()
                game:GetService("ReplicatedStorage").Remotes.Game.next:FireServer()
            end)
        else
            pcall(function()
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Players"):WaitForChild("teleport"):FireServer()
            end)
        end

        if getgenv().CurrentlyPlayingChallenge then
            if getgenv().CurrentlyPlayingChallenge == "1d" then
                if isVictory then
                    getgenv().DailyChallengeCompleted = true
                    pcall(function()
                        local dayTime = getTimers()
                        if not dayTime or dayTime <= 0 then
                            dayTime = 86400 - (os.time() % 86400)
                        end
                        setConfig("DailyChallengeResetTime", os.time() + dayTime)
                    end)
                end
                pcall(function()
                    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Players"):WaitForChild("teleport"):FireServer()
                end)
            end
            getgenv().CurrentlyPlayingChallenge = nil
            getgenv().Current30m = nil
        end
    end)
end

task.spawn(function()
    local ending
    while not ending and (getgenv().uiActive ~= false or getgenv().isStartup) do
        pcall(function()
            ending = ReplicatedStorage.Remotes.Game.ending
        end)
        if not ending then task.wait(0.5) end
    end

    if ending then
        if Macro.EndingConnection then
            pcall(function() Macro.EndingConnection:Disconnect() end)
        end
        Macro.EndingConnection = ending.OnClientEvent:Connect(function(...)
            Macro:HandleGameEnd()
        end)
    end
end)

task.spawn(function()
    local messageRemote
    while not messageRemote and (getgenv().uiActive ~= false or getgenv().isStartup) do
        pcall(function()
            messageRemote = game:GetService("ReplicatedStorage").Remotes.Players.message
        end)
        if not messageRemote then task.wait(0.5) end
    end
    if messageRemote then
        messageRemote.OnClientEvent:Connect(function(msg)
            if type(msg) == "string" and msg:lower():find("replay this challenge") then
                getgenv().Current30m = nil
                getgenv().CurrentlyPlayingChallenge = nil
                if not isInLobby() then
                    pcall(function()
                        game:GetService("ReplicatedStorage").Remotes.Players.teleport:FireServer()
                    end)
                end
            end
        end)
    end
end)

task.spawn(function()
    while not getgenv().Library and (getgenv().uiActive ~= false or getgenv().isStartup) do
        task.wait(0.2)
    end
    
    while getgenv().uiActive ~= false or getgenv().isStartup do
        local ply = game:GetService("Players").LocalPlayer
        local playerGui = ply and ply:FindFirstChild("PlayerGui")
        local menus = playerGui and playerGui:FindFirstChild("Menus")
        local endScreen = menus and menus:FindFirstChild("EndScreen")
        if endScreen then
            local isVisible = false
            pcall(function() isVisible = endScreen.Visible end)
            if isVisible and not Macro.HasHandledEnd then
                Macro:HandleGameEnd()
            end
        end
        task.wait(1.0)
    end
end)

--// Network Hooks
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)

local runningThreads = {}
getgenv().hookCallback = function(self, ...)
    local method = getnamecallmethod()
    
    if method == "WaitForChild" then
        local args = { ... }
        local childName = args[1]
        if childName == "Game" and typeof(self) == "Instance" and self.Name == "Remotes" then
            if getgenv().isInLobby and getgenv().isInLobby() then
                return nil
            end
        end
    end
    
    if method ~= "FireServer" and method ~= "InvokeServer" then
        return getgenv().hookmetamethod(self, ...)
    end
    
    local thread = coroutine.running()
    if runningThreads[thread] then
        return getgenv().hookmetamethod(self, ...)
    end
    
    local isGameplay = false
    local isSpawn = false
    local isUpgrade = false
    local isUltimate = false
    local isReplay = false
    local isNext = false
    
    if typeof(self) == "Instance" then
        local name = self.Name
        if name == "spawn" or name == "upgrade" or name == "start" or name == "replay" or name == "next" then
            local parent = self.Parent
            local pName = parent and parent.Name
            
            if name == "spawn" and pName == "Characters" then
                isGameplay = true
                isSpawn = true
            elseif name == "upgrade" and pName == "Characters" then
                isGameplay = true
                isUpgrade = true
            elseif name == "start" and pName == "Ultimates" then
                isGameplay = true
                isUltimate = true
            elseif name == "replay" and pName == "Game" then
                isGameplay = true
                isReplay = true
            elseif name == "next" and pName == "Game" then
                isGameplay = true
                isNext = true
            end
        end
    end
    
    if isGameplay then
        runningThreads[thread] = true
        
        local isRec = getgenv().MacroRecord
        local macro = getgenv().Macro
        
        if isReplay or isNext then
            if macro then
                macro.HasPlayedThisMatch = false
                macro.HasHandledEnd = false
            end
            getgenv().MatchStarted = false
            getgenv().TransitionNewMatch = true
            getgenv().TransistionStartTime = os.time()
            
            local results = table.pack(getgenv().hookmetamethod(self, ...))
            runningThreads[thread] = nil
            return table.unpack(results, 1, results.n)
        end
        
        local remotePath = "Characters/spawn"
        if isUpgrade then
            remotePath = "Characters/upgrade"
        elseif isUltimate then
            remotePath = "Ultimates/start"
        end
        
        if method == "InvokeServer" then
            local results
            local ok, err = pcall(function(...)
                results = table.pack(getgenv().hookmetamethod(self, ...))
            end, ...)
            
            runningThreads[thread] = nil
            
            if ok and results then
                local retVal = results[1]
                if macro and isRec and retVal ~= false then
                    local args = { ... }
                    table.insert(macro.RecordQueue, { actionType = remotePath, args = args })
                end
                return table.unpack(results, 1, results.n)
            end
        else
            if macro and isRec then
                local args = { ... }
                table.insert(macro.RecordQueue, { actionType = remotePath, args = args })
            end
        end
        
        runningThreads[thread] = nil
    end
    return getgenv().hookmetamethod(self, ...)
end
getgenv().NamecallHookCallback = getgenv().hookCallback

local success, err = pcall(function()
    local oldHook = getgenv().hookmetamethod or getgenv()._oldNamecall
    if oldHook and getgenv().AS_Hooked then
        getgenv().hookmetamethod = oldHook
        getgenv()._oldNamecall = oldHook
    else
        local originalNamecall
        originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if getgenv().hookCallback then
                return getgenv().hookCallback(self, ...)
            end
            return originalNamecall(self, ...)
        end))
        getgenv().hookmetamethod = originalNamecall
        getgenv()._oldNamecall = originalNamecall
        getgenv().AS_Hooked = true
    end
end)
if not success then
    warn("[Hook Registration Error] " .. tostring(err))
end

function Macro:StartPlayback()
    if (getgenv().isInLobby and getgenv().isInLobby()) or (getgenv().isMidGame and not getgenv().isMidGame()) then
        self.HasPlayedThisMatch = false
        return
    end
    if not self.IsPlaying then
        local delayVal = getgenv().MacroDelay or 0.2
        if self.StatusLabel then
            self.StatusLabel:Update({ State = "Playing...", Current = "None", Next = "None" })
        end

        local waitYen = true
        if getgenv().config and getgenv().config.MacroWaitYen ~= nil then
            waitYen = getgenv().config.MacroWaitYen
        end

        local started = self:Play(false, delayVal, waitYen,
            function(step, total, data)
                pcall(function()
                    local label = getLabelText(data.action)
                    local unitName = formatUnitName(data.action, self:ResolveName(data.args[1]), data.cost)
                    local currentAction = string.format("%s - %s", label, unitName)
                    local nextAction = "None"

                    if step < total then
                        local nextStep = self.Recording[step + 1]
                        local nextLabel = getLabelText(nextStep.action)
                        local nextUnitName = formatUnitName(nextStep.action, self:ResolveName(nextStep.args[1]), nextStep.cost)
                        nextAction = string.format("%s - %s", nextLabel, nextUnitName)
                    end

                    if self.StatusLabel then
                        self.StatusLabel:Update({
                            State = string.format("Playing (%d/%d)", step, total),
                            Current = currentAction,
                            Next = nextAction,
                        })
                    end
                end)
            end,
            function()
                if self.StatusLabel then
                    local ended = (getgenv().isInLobby and getgenv().isInLobby()) or (getgenv().isMidGame and not getgenv().isMidGame())
                    if not ended then
                        self.StatusLabel:Update({ State = "Done" })
                    else
                        self.StatusLabel:Update({ State = "Stopped", Current = "None", Next = "None" })
                    end
                end
            end
        )
        if not started then
            self.HasPlayedThisMatch = false
        end
    end
end

--// Auto Join
task.spawn(function()
    while true do
        if getgenv().uiActive == false and not getgenv().isStartup then break end
        
        local autoJoin = false
        pcall(function()
            if getgenv().AccountControl and getgenv().AccountControl.AutoJoin ~= nil then
                autoJoin = getgenv().AccountControl.AutoJoin
            elseif getgenv().config and getgenv().config.AutoJoin ~= nil then
                autoJoin = getgenv().config.AutoJoin
            end
        end)
        
        if autoJoin and isInLobby() and not Macro.HasJoinedRoom then
            Macro.HasJoinedRoom = true
            getgenv().LastRoomJoinTime = os.time()
            
            local createdRoom = false
            local success, err = pcall(function()
                local world = ""
                local mode = "Story"
                local difficulty = "Normal"
                local act = 1
                
                if getgenv().Library and getgenv().Library.Options then
                    local opts = getgenv().Library.Options
                    if opts.SelectedMap then world = opts.SelectedMap.Value end
                    if opts.SelectedMode then mode = opts.SelectedMode.Value end
                    if opts.SelectedDifficulty then difficulty = opts.SelectedDifficulty.Value end
                    if opts.SelectedLevel then act = tonumber(opts.SelectedLevel.Value) or 1 end
                else
                    world = getgenv().config.SelectedMap or ""
                    mode = getgenv().config.SelectedMode or "Story"
                    difficulty = getgenv().config.SelectedDifficulty or "Normal"
                    act = tonumber(getgenv().config.SelectedLevel) or 1
                end
                
                local args = {
                    boosted = true,
                    act = act,
                    difficulty = difficulty,
                    mode = mode,
                    only_friends = false,
                    world = world
                }
                
                local ok, err = ReplicatedStorage.Remotes.Play.create_room:InvokeServer(args)
                if ok ~= false then
                    createdRoom = true
                    pcall(function()
                        writefile("bobcat/games/AS/temp_match.json", HttpService:JSONEncode({
                            mode = mode,
                            world = world,
                            act = act,
                            difficulty = difficulty
                        }))
                    end)
                else
                    warn("[AutoJoin] Failed to create room: " .. tostring(err))
                end
            end)
            
            if not success then
                warn("[AutoJoin] Room creation pcall error: " .. tostring(err))
                Macro.HasJoinedRoom = false
            elseif not createdRoom then
                Macro.HasJoinedRoom = false
            end
            
            if createdRoom then
                local delayTime = tonumber(getgenv().config.JoinDelay) or 3
                local elapsed = 0
                local aborted = false
                
                while elapsed < delayTime do
                    task.wait(0.1)
                    elapsed = elapsed + 0.1
                    
                    local currentAutoJoin = false
                    pcall(function()
                        if getgenv().Library and getgenv().Library.Toggles and getgenv().Library.Toggles.AutoJoin then
                            currentAutoJoin = getgenv().Library.Toggles.AutoJoin.Value
                        else
                            currentAutoJoin = getgenv().config.AutoJoin
                        end
                    end)
                    
                    if getgenv().uiActive == false or not currentAutoJoin then
                        aborted = true
                        break
                    end
                end
                
                if aborted then
                    pcall(function()
                        ReplicatedStorage.Remotes.Play.leave:FireServer()
                    end)
                    Macro.HasJoinedRoom = false
                else
                    pcall(function()
                        local remote = ReplicatedStorage.Remotes.Play.start
                        if remote:IsA("RemoteFunction") then
                            remote:InvokeServer()
                        else
                            remote:FireServer()
                        end
                    end)
                    task.delay(5, function()
                        if isInLobby() and Macro.HasJoinedRoom then
                            Macro.HasJoinedRoom = false
                        end
                    end)
                end
            end
        elseif not isInLobby() then
            Macro.HasJoinedRoom = false
        end
        task.wait(1)
    end
end)

--// Find Match
task.spawn(function()
    while true do
        if getgenv().uiActive == false and not getgenv().isStartup then break end

        local findMatch = false
        pcall(function()
            if getgenv().config and getgenv().config.FindMatch ~= nil then
                findMatch = getgenv().config.FindMatch
            end
        end)

        if findMatch and isInLobby() then
            local world = ""
            local mode = "Story"
            local difficulty = "Normal"
            local act = 1
            pcall(function()
                if getgenv().Library and getgenv().Library.Options then
                    local opts = getgenv().Library.Options
                    if opts.SelectedMap then world = opts.SelectedMap.Value end
                    if opts.SelectedMode then mode = opts.SelectedMode.Value end
                    if opts.SelectedDifficulty then difficulty = opts.SelectedDifficulty.Value end
                    if opts.SelectedLevel then act = tonumber(opts.SelectedLevel.Value) or 1 end
                else
                    world = getgenv().config.SelectedMap or ""
                    mode = getgenv().config.SelectedMode or "Story"
                    difficulty = getgenv().config.SelectedDifficulty or "Normal"
                    act = tonumber(getgenv().config.SelectedLevel) or 1
                end
            end)

            pcall(function()
                game:GetService("ReplicatedStorage").Remotes.Matchmaking.find_match:InvokeServer({
                    difficulty = difficulty,
                    mode = mode,
                    world = world,
                    act = act,
                })
            end)
        end

        task.wait(1)
    end
end)

local function formatHMS(seconds)
    seconds = tonumber(seconds) or 0
    return string.format("%02i:%02i:%02i", math.floor(seconds / 3600), math.floor(seconds / 60 % 60), math.floor(seconds % 60))
end

local function formatMS(seconds)
    seconds = tonumber(seconds) or 0
    return string.format("%02i:%02i", math.floor(seconds / 60 % 60), math.floor(seconds % 60))
end

local function formatRewardsCompact(rewardsTable)
    if not rewardsTable then return "None" end
    local items = {}
    local priorities = {"Trait Shards", "Perfect Cubes", "Reroll Cubes", "Gems", "Gold"}
    for _, name in ipairs(priorities) do
        if rewardsTable[name] then
            local amount = tostring(rewardsTable[name].amount or "1"):gsub("x", "")
            table.insert(items, name .. " x" .. amount)
        end
    end
    for name, data in pairs(rewardsTable) do
        local isPriority = false
        for _, pName in ipairs(priorities) do
            if pName == name then
                isPriority = true
                break
            end
        end
        if not isPriority then
            local amount = tostring(data.amount or "1"):gsub("x", "")
            table.insert(items, name .. " x" .. amount)
        end
    end
    if #items == 0 then return "None" end
    return table.concat(items, ", ")
end

local function getTimers()
    local day = 0
    local half_hour = 0
    pcall(function()
        local playerScripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
        local clientFolder = playerScripts and playerScripts:FindFirstChild("Client")
        local utilityModule = clientFolder and clientFolder:FindFirstChild("Utility")
        if utilityModule then
            local utility = require(utilityModule)
            if utility and utility.timers then
                day = tonumber(utility.timers.day) or 0
                half_hour = tonumber(utility.timers.half_hour) or 0
            end
        end
    end)
    return day, half_hour
end

local function matchesFilter(rewardsTable, filter)
    if not filter then return true end

    if type(filter) == "string" then
        if filter == "Any" or filter == "" then return true end
        return rewardsTable and rewardsTable[filter] ~= nil
    end

    if type(filter) == "table" then
        local hasSelection = false
        for _, v in pairs(filter) do
            if v then hasSelection = true break end
        end
        if not hasSelection then return true end

        for name, selected in pairs(filter) do
            if selected and rewardsTable and rewardsTable[name] then
                return true
            end
        end
        return false
    end

    return true
end

task.spawn(function()
    local lastFetch = 0
    if not getgenv().CachedChallenges then
        getgenv().CachedChallenges = nil
    end
    local lastDayTimer = 0
    local lastHalfHourTimer = 0
    local challengeCachePath = "bobcat/games/AS/Cache/challenge_cache.json"

    if not getgenv().CachedChallenges then
        pcall(function()
            if isfile(challengeCachePath) then
                local saved = HttpService:JSONDecode(readfile(challengeCachePath))
                if type(saved) == "table" then
                    getgenv().CachedChallenges = saved
                end
            end
        end)
    end
    
    while true do
        if getgenv().uiActive == false and not getgenv().isStartup then break end
        
        local now = os.time()

        local shouldFetch = (not getgenv().CachedChallenges or (now - lastFetch) >= 15)
        if shouldFetch and isInLobby() then
            pcall(function()
                local get_challenges = game:GetService("ReplicatedStorage").Remotes.Play:FindFirstChild("get_challenges")
                if get_challenges then
                    local result = get_challenges:InvokeServer()
                    if result then
                        getgenv().CachedChallenges = result
                        lastFetch = now
                        pcall(function()
                            ensurePathFolders(challengeCachePath)
                            writefile(challengeCachePath, HttpService:JSONEncode(result))
                        end)
                    end
                end
            end)
        end
        local cachedChallenges = getgenv().CachedChallenges
        
        local dayTime, halfHourTime = getTimers()
        if lastHalfHourTimer > 0 and halfHourTime > lastHalfHourTimer and (halfHourTime - lastHalfHourTimer) > 60 then
            getgenv().Current30m = nil
            if getgenv().CurrentlyPlayingChallenge == "30m" and not isInLobby() then
                getgenv().CurrentlyPlayingChallenge = nil
                pcall(function()
                    game:GetService("ReplicatedStorage").Remotes.Players.teleport:FireServer()
                end)
            end
        end
        lastHalfHourTimer = halfHourTime

        local label = getgenv().ChallengeInfoLabel
        if label then
            if cachedChallenges then
                local text = ""
                
                if dayTime > lastDayTimer and lastDayTimer > 0 and (dayTime - lastDayTimer) > 1000 then
                    getgenv().DailyChallengeCompleted = false
                    setConfig("DailyChallengeResetTime", 0)
                end
                lastDayTimer = dayTime
                
                local inLobbyNow = isInLobby()

                local dData = cachedChallenges["1d"]
                if dData then
                    local status
                    if getgenv().DailyChallengeCompleted then
                        status = "Completed"
                    elseif not inLobbyNow then
                        status = "In Progress"
                    else
                        status = formatHMS(dayTime)
                    end
                    text = text .. "Daily [1D] (" .. dData.world .. " Act " .. dData.act .. ")\n"
                    text = text .. "  Rewards: " .. formatRewardsCompact(dData.rewards) .. "\n\n"
                    text = text .. "  Reset in: " .. status .. "\n\n"
                else
                    text = text .. "Daily [1D]: Active challenge data not found\n\n"
                end
                
                local mData = cachedChallenges["30m"]
                if mData then
                    local mStatus = inLobbyNow and formatMS(halfHourTime) or "In Progress"
                    text = text .. "Regular [30M] (" .. mData.world .. " Act " .. mData.act .. ")\n"
                    text = text .. "  Rewards: " .. formatRewardsCompact(mData.rewards) .. "\n\n"
                    text = text .. "  Reset in: " .. mStatus .. "\n\n"
                else
                    text = text .. "Regular [30M]: Active challenge data not found\n\n"
                end
                
                local kbData = cachedChallenges["Katakara Bridge"] or cachedChallenges["katakara_bridge"] or cachedChallenges["katakura_bridge"] or cachedChallenges["inf"]
                if not kbData then
                    local isHard = (getgenv().config and getgenv().config.SelectedDifficulty == "Hard")
                    local rewards
                    if isHard then
                        rewards = {
                            ["Hogyoku Orb"] = { amount = "1x", chance = "0.5%", pity = 200, order = 1 },
                            ["Trait Shards"] = { amount = "1-2x", chance = "50%", cap = 100, order = 2 },
                            ["XP"] = { amount = "35x", chance = "100%", order = 3 }
                        }
                    else
                        rewards = {
                            ["Puppeteer"] = { amount = "1x", chance = "1%", pity = 100, order = 1 },
                            ["Trait Shards"] = { amount = "1-2x", chance = "50%", cap = 100, order = 2 },
                            ["XP"] = { amount = "25x", chance = "100%", order = 3 }
                        }
                    end
                    kbData = {
                        world = "Katakara Bridge",
                        act = 1,
                        rewards = rewards
                    }
                end
                text = text .. "Katakara Bridge [Inf] (" .. kbData.world .. " Act " .. kbData.act .. ")\n"
                text = text .. "  Rewards: " .. formatRewardsCompact(kbData.rewards) .. "\n\n"
                text = text .. "  Reset in: Permanent Stage"
                
                pcall(function()
                    label:SetText(text)
                end)
            else
                pcall(function()
                    label:SetText("Loading challenge data from server...")
                end)
            end
        end
        
        local autoChallenge = false
        pcall(function()
            if getgenv().AccountControl and getgenv().AccountControl.AutoChallenge ~= nil then
                autoChallenge = getgenv().AccountControl.AutoChallenge
            elseif getgenv().config and getgenv().config.AutoChallenge ~= nil then
                autoChallenge = getgenv().config.AutoChallenge
            end
        end)
        
        if autoChallenge and isInLobby() and not Macro.HasJoinedRoom then
            local challengeTypes = getgenv().config.ChallengeType or {}
            local rewardFilter = getgenv().config.ChallengeRewardFilter or {}
            
            local candidate = nil
            local candidateData = nil
            
            if cachedChallenges then
                if challengeTypes["1d"] and not getgenv().DailyChallengeCompleted and cachedChallenges["1d"] then
                    local dData = cachedChallenges["1d"]
                    if matchesFilter(dData.rewards, rewardFilter) then
                        candidate = "1d"
                        candidateData = dData
                    end
                end
                
                if not candidate and challengeTypes["30m"] and cachedChallenges["30m"] then
                    local mData = cachedChallenges["30m"]
                    if matchesFilter(mData.rewards, rewardFilter) then
                        candidate = "30m"
                        candidateData = mData
                    end
                end

                if not candidate and (challengeTypes["Katakara Bridge"] or challengeTypes["katakara_bridge"] or challengeTypes["katakura_bridge"]) then
                    local isHard = (getgenv().config and getgenv().config.SelectedDifficulty == "Hard")
                    local rewards
                    if isHard then
                        rewards = {
                            ["Hogyoku Orb"] = { amount = "1x", chance = "0.5%", pity = 200, order = 1 },
                            ["Trait Shards"] = { amount = "1-2x", chance = "50%", cap = 100, order = 2 },
                            ["XP"] = { amount = "35x", chance = "100%", order = 3 }
                        }
                    else
                        rewards = {
                            ["Puppeteer"] = { amount = "1x", chance = "1%", pity = 100, order = 1 },
                            ["Trait Shards"] = { amount = "1-2x", chance = "50%", cap = 100, order = 2 },
                            ["XP"] = { amount = "25x", chance = "100%", order = 3 }
                        }
                    end
                    local kbData = {
                        world = "Katakara Bridge",
                        act = 1,
                        rewards = rewards
                    }
                    if matchesFilter(kbData.rewards, rewardFilter) then
                        candidate = "Katakara Bridge"
                        candidateData = kbData
                    end
                end

                if not candidate and challengeTypes["The Hero Hunter"] then
                    local hhData = {
                        world = "The Hero Hunter",
                        act = 1,
                        rewards = nil
                    }
                    candidate = "The Hero Hunter"
                    candidateData = hhData
                end
            end
            
            if candidate and candidateData then
                Macro.HasJoinedRoom = true
                getgenv().CurrentlyPlayingChallenge = candidate
                if candidate == "30m" then
                    getgenv().Current30m = (candidateData.world or "") .. "_" .. (candidateData.act or "")
                end
                
                local createdRoom = false
                pcall(function()
                    local challengeDiff
                    if candidate == "Katakara Bridge" or candidate == "katakara_bridge" or candidate == "katakura_bridge" then
                        challengeDiff = (getgenv().config.SelectedDifficulty or "Normal")
                    elseif candidate == "1d" or candidate == "30m" then
                        challengeDiff = candidate
                    else
                        challengeDiff = (getgenv().config.SelectedDifficulty or "Normal")
                    end
                    local challengeRewards = (candidate == "Katakara Bridge" or candidate == "katakara_bridge" or candidate == "katakura_bridge") and nil or candidateData.rewards
                    local args = {
                        boosted = true,
                        difficulty = challengeDiff,
                        act = candidateData.act,
                        only_friends = false,
                        rewards = challengeRewards,
                        mode = "Challenge",
                        world = candidateData.world
                    }
                    
                    local ok, err = game:GetService("ReplicatedStorage").Remotes.Play.create_room:InvokeServer(args)
                    if ok ~= false and ok ~= nil then
                        createdRoom = true
                        pcall(function()
                            writefile("bobcat/games/AS/temp_match.json", HttpService:JSONEncode({
                                mode = "Challenge",
                                world = candidateData.world,
                                act = candidateData.act,
                                difficulty = candidate
                            }))
                        end)
                    else
                        warn("[AutoChallenge] Failed to create room: " .. tostring(err))
                    end
                end)
                
                if createdRoom then
                    getgenv().DailyChallengeFailCount = 0
                    local delayTime = tonumber(getgenv().config.ChallengeDelay) or 3
                    local elapsed = 0
                    local aborted = false
                    
                    while elapsed < delayTime do
                        task.wait(0.1)
                        elapsed = elapsed + 0.1
                        
                        local currentAutoChallenge = false
                        pcall(function()
                            if getgenv().Library and getgenv().Library.Toggles and getgenv().Library.Toggles.AutoChallenge then
                                currentAutoChallenge = getgenv().Library.Toggles.AutoChallenge.Value
                            else
                                currentAutoChallenge = getgenv().config.AutoChallenge
                            end
                        end)
                        
                        if getgenv().uiActive == false or not currentAutoChallenge then
                            aborted = true
                            break
                        end
                    end
                    
                    if aborted then
                        pcall(function()
                            game:GetService("ReplicatedStorage").Remotes.Play.leave:FireServer()
                        end)
                        Macro.HasJoinedRoom = false
                        getgenv().CurrentlyPlayingChallenge = nil
                    else
                        pcall(function()
                            game:GetService("ReplicatedStorage").Remotes.Play.start:InvokeServer()
                        end)
                        task.delay(5, function()
                            if isInLobby() and Macro.HasJoinedRoom then
                                Macro.HasJoinedRoom = false
                            end
                        end)
                    end
                else
                    Macro.HasJoinedRoom = false
                    getgenv().CurrentlyPlayingChallenge = nil
                    
                    if candidate == "1d" then
                        getgenv().DailyChallengeFailCount = (getgenv().DailyChallengeFailCount or 0) + 1
                        if getgenv().DailyChallengeFailCount >= 3 then
                            getgenv().DailyChallengeCompleted = true
                            local dayTime = getTimers()
                            if dayTime and dayTime > 0 then
                                setConfig("DailyChallengeResetTime", os.time() + dayTime)
                            end
                        end
                    end
                end
            end
        elseif not isInLobby() then
            Macro.HasJoinedRoom = false

            if getgenv().CurrentlyPlayingChallenge == "30m" and getgenv().Current30m then
                local fresh = getgenv().CachedChallenges and getgenv().CachedChallenges["30m"]
                if fresh then
                    local freshSig = (fresh.world or "") .. "_" .. (fresh.act or "")
                    if freshSig ~= getgenv().Current30m then
                        getgenv().Current30m = nil
                        getgenv().CurrentlyPlayingChallenge = nil
                        pcall(function()
                            game:GetService("ReplicatedStorage").Remotes.Players.teleport:FireServer()
                        end)
                    end
                end
            end
        end
        
        task.wait(1)
    end
end)

--// Auto Joiner
task.spawn(function()
    while true do
        if getgenv().uiActive == false and not getgenv().isStartup then break end
        
        local autoJoiner = false
        pcall(function()
            if getgenv().AccountControl and getgenv().AccountControl.AutoJoiner ~= nil then
                autoJoiner = getgenv().AccountControl.AutoJoiner
            elseif getgenv().config and getgenv().config.AutoJoiner ~= nil then
                autoJoiner = getgenv().config.AutoJoiner
            end
        end)
        
        if autoJoiner and isInLobby() and not Macro.HasJoinedRoom then
            local joinPlayerID = getgenv().config.JoinPlayerID or ""
            if joinPlayerID ~= "" then
                Macro.HasJoinedRoom = true
                getgenv().LastRoomJoinTime = os.time()
                
                local foundMatch = false
                local success, err = pcall(function()
                    local playerID = tonumber(joinPlayerID)
                    if not playerID then
                        warn("[AutoJoiner] Invalid player ID format")
                        return
                    end

                    local waitTargets = {}
                    local cfg = getgenv().config or {}
                    
                    if cfg.WaitForPlayerID and cfg.WaitForPlayerID ~= "" then
                        table.insert(waitTargets, tostring(cfg.WaitForPlayerID))
                    end
                    
                    if cfg.WaitForPlayer then
                        if type(cfg.WaitForPlayer) == "string" and cfg.WaitForPlayer ~= "" then
                            table.insert(waitTargets, cfg.WaitForPlayer)
                        elseif type(cfg.WaitForPlayer) == "table" then
                            
                            if #cfg.WaitForPlayer > 0 then
                                for i = 1, #cfg.WaitForPlayer do
                                    if #waitTargets >= 3 then break end
                                    table.insert(waitTargets, tostring(cfg.WaitForPlayer[i]))
                                end
                            else
                                for name, v in pairs(cfg.WaitForPlayer) do
                                    if #waitTargets >= 3 then break end
                                    if v then table.insert(waitTargets, tostring(name)) end
                                end
                            end
                        end
                    end
                    
                    if #waitTargets > 3 then
                        while #waitTargets > 3 do table.remove(waitTargets) end
                    end

                    if #waitTargets > 0 then
                        local timeout = tonumber(cfg.JoinerWaitTimeout) or 60
                        local elapsed = 0
                        local allPresent = false
                        while not allPresent and elapsed < timeout do
                            allPresent = true
                            for _, target in ipairs(waitTargets) do
                                local found = false
                                for _, pl in ipairs(Players:GetPlayers()) do
                                    if tostring(pl.UserId) == tostring(target) or pl.Name == tostring(target) then
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    allPresent = false
                                    break
                                end
                            end
                            if not allPresent then
                                task.wait(1)
                                elapsed = elapsed + 1
                            end
                        end
                        if not allPresent then
                            warn("[AutoJoiner] WaitForPlayer(s) timed out after " .. tostring(timeout) .. "s")
                        end
                    end

                    local matchmaking = ReplicatedStorage:FindFirstChild("Matchmaking")
                    local usedFind = false
                    if matchmaking and matchmaking:FindFirstChild("find_match") then
                        local okFind, res = pcall(function() return matchmaking.find_match:InvokeServer() end)
                        if okFind and res then
                            usedFind = true
                            foundMatch = true
                            pcall(function()
                                ReplicatedStorage.Remotes.Play.join:InvokeServer(playerID)
                            end)
                        end
                    end

                    if not usedFind then
                        local playRemotes = ReplicatedStorage.Remotes:FindFirstChild("Play")
                        if playRemotes and playRemotes:FindFirstChild("find_match") then
                            local okFind, res = pcall(function() return playRemotes.find_match:InvokeServer() end)
                            if okFind and res then
                                foundMatch = true
                                pcall(function()
                                    playRemotes.join:InvokeServer(playerID)
                                end)
                            end
                        end
                    end

                    if foundMatch then
                        pcall(function()
                            writefile("bobcat/games/AS/temp_match.json", HttpService:JSONEncode({
                                mode = "Joiner",
                                joinedPlayer = playerID,
                                joinTime = os.time()
                            }))
                        end)
                    else
                        warn("[AutoJoiner] Failed to find match")
                    end
                end)
                
                if not success then
                    warn("[AutoJoiner] Error: " .. tostring(err))
                    Macro.HasJoinedRoom = false
                elseif not foundMatch then
                    Macro.HasJoinedRoom = false
                end
                
                if foundMatch then
                    local delayTime = tonumber(getgenv().config.JoinerDelay) or 3
                    local elapsed = 0
                    local aborted = false
                    
                    while elapsed < delayTime do
                        task.wait(0.1)
                        elapsed = elapsed + 0.1
                        
                        local currentAutoJoiner = false
                        pcall(function()
                            if getgenv().Library and getgenv().Library.Toggles and getgenv().Library.Toggles.AutoJoiner then
                                currentAutoJoiner = getgenv().Library.Toggles.AutoJoiner.Value
                            else
                                currentAutoJoiner = getgenv().config.AutoJoiner
                            end
                        end)
                        
                        if getgenv().uiActive == false or not currentAutoJoiner then
                            aborted = true
                            break
                        end
                    end
                    
                    if not aborted then
                        pcall(function()
                            local remote = ReplicatedStorage.Remotes.Play.start
                            if remote:IsA("RemoteFunction") then
                                remote:InvokeServer()
                            else
                                remote:FireServer()
                            end
                        end)
                        task.delay(5, function()
                            if isInLobby() and Macro.HasJoinedRoom then
                                Macro.HasJoinedRoom = false
                            end
                        end)
                    else
                        Macro.HasJoinedRoom = false
                    end
                end
            else
                warn("[AutoJoiner] No player ID configured")
            end
        elseif not isInLobby() then
            Macro.HasJoinedRoom = false
        end
        
        task.wait(1)
    end
end)

--// Auto Summon
task.spawn(function()
    while true do
        if getgenv().uiActive == false and not getgenv().isStartup then break end
        local autoSummon = false
        pcall(function()
            if getgenv().AccountControl and getgenv().AccountControl.AutoSummon ~= nil then
                autoSummon = getgenv().AccountControl.AutoSummon
            elseif getgenv().config and getgenv().config.AutoSummon ~= nil then
                autoSummon = getgenv().config.AutoSummon
            end
        end)
        
        if autoSummon and isInLobby() then
            local banner = getgenv().config.SummonBanner or "Basic Banner"
            local amount = tonumber(getgenv().config.SummonAmount) or 10
            pcall(function()
                ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Summon"):WaitForChild("start"):InvokeServer(banner, amount)
            end)
            task.wait(2)
        else
            task.wait(1)
        end
    end
end)

--// Auto Execute
local queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport)
if queue_on_teleport then
    pcall(function()
        local queued = false
        Macro.TeleportConnection = game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(State)
            local autoExecute = false
            pcall(function()
                if getgenv().config and getgenv().config.AutoExecute ~= nil then
                    autoExecute = getgenv().config.AutoExecute
                end
            end)
            if queued then return end
            if autoExecute and (State == Enum.TeleportState.Started or State == Enum.TeleportState.InProgress) then
                queued = true
                local repo = "https://raw.githubusercontent.com/nostrainu/Poop-Cat/refs/heads/main/Main/AS/"
                local script = "repeat task.wait(0.5) until game:IsLoaded() "
                    .. "repeat task.wait(0.5) until game:GetService('Players').LocalPlayer "
                    .. "task.wait(8) "
                    .. "if not getgenv().uiActive then "
                    .. "local s,e = pcall(function() "
                    .. "loadstring(game:HttpGet('" .. repo .. "ASFunc.lua'))() "
                    .. "loadstring(game:HttpGet('" .. repo .. "ASMain.lua'))() "
                    .. "end) "
                    .. "end"
                queue_on_teleport(script)
            end
        end)
    end)
end

--// Worlds Config & Dropdown Updater
local function findWorldsModule()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local worlds = replicatedStorage:FindFirstChild("Worlds", true)
    if worlds and worlds:IsA("ModuleScript") then
        return worlds
    end
    for _, obj in ipairs(replicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") and obj.Name == "Worlds" then
            return obj
        end
    end
    local localPlayer = game:GetService("Players").LocalPlayer
    if localPlayer then
        local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
        if playerScripts then
            for _, obj in ipairs(playerScripts:GetDescendants()) do
                if obj:IsA("ModuleScript") and obj.Name == "Worlds" then
                    return obj
                end
            end
        end
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, obj in ipairs(playerGui:GetDescendants()) do
                if obj:IsA("ModuleScript") and obj.Name == "Worlds" then
                    return obj
                end
            end
        end
    end
    return nil
end

local updatingDropdowns = false

local function getMapsForMode(mode)
    if mode == "Challenge" then
        return {"30m", "Katakara Bridge", "The Hero Hunter"}
    end
    local list = {}
    local worldsModule = findWorldsModule()
    if worldsModule then
        local ok, Worlds = pcall(require, worldsModule)
        if ok and typeof(Worlds) == "table" then
            for _, worldData in pairs(Worlds) do
                if typeof(worldData) == "table" and worldData.name and worldData.Rewards then
                    if mode == "None" then
                        table.insert(list, worldData.name)
                    elseif worldData.Rewards[mode] then
                        table.insert(list, worldData.name)
                    end
                end
            end
        end
    end
    if mode == "Event" then
        local initialMaps = getgenv().initialMapValues or {}
        if table.find(initialMaps, "Cosmic Throne Hall") and not table.find(list, "Cosmic Throne Hall") then
            table.insert(list, "Cosmic Throne Hall")
        end
    end
    if #list == 0 then
        if mode == "Raid" then
            return {"GT City", "Eclipse (Before)"}
        elseif mode == "Squadron" or mode == "Story" then
            return {"GT City", "Marine Lobby", "Ninja Village", "Eclipse (Before)"}
        elseif mode == "Event" then
            return {"Cosmic Throne Hall"}
        else
            return getgenv().initialMapValues or {"GT City", "Marine Lobby", "Ninja Village", "Eclipse (Before)", "Katakura Wasteland"}
        end
    end
    table.sort(list)
    return list
end
getgenv().getMapsForMode = getMapsForMode

local function updateMapModeLevelDropdowns()
    local Library = getgenv().Library
    if updatingDropdowns or not Library then return end
    if not (Library.Options.SelectedMap and Library.Options.SelectedMode and Library.Options.SelectedDifficulty and Library.Options.SelectedLevel) then
        return
    end
    updatingDropdowns = true

    local ok, err = pcall(function()
        local map = Library.Options.SelectedMap.Value
        local mode = Library.Options.SelectedMode.Value
        local difficulty = Library.Options.SelectedDifficulty.Value
        local level = Library.Options.SelectedLevel.Value

        local fullMaps = {}
        local worldsModule = findWorldsModule()
        if worldsModule then
            local ok, Worlds = pcall(require, worldsModule)
            if ok and typeof(Worlds) == "table" then
                for _, worldData in pairs(Worlds) do
                    if typeof(worldData) == "table" and worldData.name then
                        local isChallengeOnly = (worldData.name == "Katakara Bridge" or worldData.name == "The Hero Hunter")
                        if not isChallengeOnly then
                            local rewards = worldData.Rewards
                            if typeof(rewards) == "table" and next(rewards) ~= nil then
                                table.insert(fullMaps, worldData.name)
                            end
                        end
                    end
                end
            end
        end

        if not table.find(fullMaps, "Cosmic Throne Hall") then
            table.insert(fullMaps, "Cosmic Throne Hall")
        end
        if #fullMaps == 0 then
            fullMaps = getgenv().initialMapValues or {"GT City", "Marine Lobby", "Ninja Village", "Eclipse (Before)", "Katakura Wasteland", "Cosmic Throne Hall"}
        end
        
        Library.Options.SelectedMap:SetValues(fullMaps)
        if not table.find(fullMaps, map) then
            map = fullMaps[1] or ""
            Library.Options.SelectedMap:SetValue(map)
            setConfig("SelectedMap", map)
        end

        local modes = {}
        local difficulties = {}
        local levels = {}
        local customLoaded = false

        pcall(function()
            local worldsModule = findWorldsModule()
            if worldsModule then
                local Worlds = require(worldsModule)
                local targetWorldData = nil
                for _, worldData in pairs(Worlds) do
                    if typeof(worldData) == "table" and worldData.name == map then
                        targetWorldData = worldData
                        break
                    end
                end

                if targetWorldData and targetWorldData.Rewards then
                    for mName, _ in pairs(targetWorldData.Rewards) do
                        if typeof(mName) == "string" then
                            table.insert(modes, mName)
                        end
                    end
                    table.sort(modes)

                    if #modes > 0 then
                        if not table.find(modes, mode) then
                            mode = modes[1]
                            setConfig("SelectedMode", mode)
                        end

                        local modeData = targetWorldData.Rewards[mode]
                        if modeData then
                            for dName, _ in pairs(modeData) do
                                if typeof(dName) == "string" then
                                    table.insert(difficulties, dName)
                                end
                            end
                            table.sort(difficulties)

                            if #difficulties > 0 then
                                if not table.find(difficulties, difficulty) then
                                    difficulty = difficulties[1]
                                    setConfig("SelectedDifficulty", difficulty)
                                end

                                local diffData = modeData[difficulty] or modeData.Normal or modeData.Hard or modeData.Infinite or modeData[next(modeData)]
                                if typeof(diffData) == "table" and #diffData > 0 then
                                    for i = 1, #diffData do
                                        table.insert(levels, tostring(i))
                                    end
                                    customLoaded = true
                                end
                            end
                        end
                    end
                end
            end
        end)

        if #modes == 0 then
            if map == "Katakura Wasteland" then
                modes = {"Infinite"}
            elseif map == "Cosmic Throne Hall" then
                modes = {"Event"}
            else
                modes = {"Story", "Squadron", "Raid", "Event"}
            end
            if not table.find(modes, mode) then
                mode = modes[1]
                setConfig("SelectedMode", mode)
            end
        end

        if #difficulties == 0 then
            if map == "Katakura Wasteland" then
                difficulties = {"Hard"}
            elseif map == "Cosmic Throne Hall" then
                difficulties = {"Normal"}
            else
                difficulties = {"Normal", "Hard"}
            end
            if not table.find(difficulties, difficulty) then
                difficulty = difficulties[1]
                setConfig("SelectedDifficulty", difficulty)
            end
        end

        if not customLoaded then
            local maxActs = 10
            if mode == "Squadron" then
                maxActs = map == "Ninja Village" and 4 or 3
            elseif mode == "Raid" then
                maxActs = 4
            elseif mode == "Infinite" or map == "Katakura Wasteland" or mode == "Event" then
                maxActs = 1
            end
            for i = 1, maxActs do
                table.insert(levels, tostring(i))
            end
        end

        Library.Options.SelectedMode:SetValues(modes)
        Library.Options.SelectedMode:SetValue(mode)

        Library.Options.SelectedDifficulty:SetValues(difficulties)
        Library.Options.SelectedDifficulty:SetValue(difficulty)

        if not table.find(levels, level) then
            level = levels[1]
            setConfig("SelectedLevel", level)
        end
        Library.Options.SelectedLevel:SetValues(levels)
        Library.Options.SelectedLevel:SetValue(level)

        if getgenv().Macro then
            getgenv().Macro.HasJoinedRoom = false
        end
    end)

    updatingDropdowns = false
    if not ok then
        warn("[updateMapModeLevelDropdowns Error] " .. tostring(err))
    end
end

getgenv().findWorldsModule = findWorldsModule
getgenv().updateMapModeLevelDropdowns = updateMapModeLevelDropdowns

--// Dynamic UI Value Initializers
local mapValues = {}
local modeValues = {}
local difficultyValues = {}
local levelValues = {}

pcall(function()
    local worldsModule = findWorldsModule()
    if worldsModule then
        local Worlds = require(worldsModule)
        local list = {}
        for _, worldData in pairs(Worlds) do
            if typeof(worldData) == "table" and worldData.name then
                table.insert(list, worldData.name)
            end
        end
        if #list > 0 then
            mapValues = list
        end

        if not table.find(mapValues, "Cosmic Throne Hall") then
            table.insert(mapValues, "Cosmic Throne Hall")
        end

        local defaultMap = registerSetting("SelectedMap", "")
        local defaultMode = registerSetting("SelectedMode", "Story")
        local defaultDiff = registerSetting("SelectedDifficulty", "Normal")

        local targetWorldData = nil
        for _, worldData in pairs(Worlds) do
            if typeof(worldData) == "table" and worldData.name == defaultMap then
                targetWorldData = worldData
                break
            end
        end

        if targetWorldData and targetWorldData.Rewards then
            local mList = {}
            for mName, _ in pairs(targetWorldData.Rewards) do
                if typeof(mName) == "string" then
                    table.insert(mList, mName)
                end
            end
            table.sort(mList)
            if #mList > 0 then
                modeValues = mList
            end

            if not table.find(modeValues, defaultMode) then
                defaultMode = modeValues[1]
            end

            local modeData = targetWorldData.Rewards[defaultMode]
            if modeData then
                local dList = {}
                for dName, _ in pairs(modeData) do
                    if typeof(dName) == "string" then
                        table.insert(dList, dName)
                    end
                end
                table.sort(dList)
                if #dList > 0 then
                    difficultyValues = dList
                end

                if not table.find(difficultyValues, defaultDiff) then
                    defaultDiff = difficultyValues[1]
                end

                local diffData = modeData[defaultDiff] or modeData.Normal or modeData.Hard or modeData.Infinite or modeData[next(modeData)]
                if typeof(diffData) == "table" and #diffData > 0 then
                    local lList = {}
                    for i = 1, #diffData do
                        table.insert(lList, tostring(i))
                    end
                    levelValues = lList
                end
            end
        end
    end
end)

if #mapValues == 0 then
    mapValues = {"GT City", "Marine Lobby", "Ninja Village", "Katakura Wasteland", "Eclipse (Before)", "Cosmic Throne Hall"}
end
if #modeValues == 0 then
    modeValues = {"Story", "Squadron", "Raid"}
end
if #difficultyValues == 0 then
    difficultyValues = {"Normal", "Hard"}
end
if #levelValues == 0 then
    levelValues = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}
end

getgenv().initialMapValues = mapValues
getgenv().initialModeValues = modeValues
getgenv().initialDifficultyValues = difficultyValues
getgenv().initialLevelValues = levelValues

local webhookItemValues = {"Yen", "Gems"}
pcall(function()
    local itemsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Items")
    if itemsFolder then
        local list = {}
        for _, item in ipairs(itemsFolder:GetChildren()) do
            table.insert(list, item.Name)
        end
        table.sort(list)
        for _, name in ipairs(list) do
            if name ~= "Yen" and name ~= "Gems" then
                table.insert(webhookItemValues, name)
            end
        end
    end
end)
if #webhookItemValues <= 2 then
    webhookItemValues = {
        "Yen", "Gems", "Perfect Cubes", "Reroll Cubes", "Trait Shards",
        "Beastblood Catalyst", "Binding Cloth", "Bounty Tickets", "Chakra Fragment",
        "Currentbinder Rope", "Depthglass Bottle", "Eclipse Godstone", "Fuin Script Paper",
        "Genjutsu Fog Vial", "Hogyoku", "Ki Resonant Crystal", "Limitbreak Obsidian",
        "Meat", "Narutomaki", "Ninja Headband", "Omega Chest", "Omega Coins"
    }
end
getgenv().initialWebhookItems = webhookItemValues


local function exportMacroWebhook(macroName)
    local webhookUrl = getgenv().config and getgenv().config.WebhookURL
    if not webhookUrl or webhookUrl == "" or not webhookUrl:find("discord.com") then
        return false, "Invalid or missing Webhook URL in Webhook tab."
    end
    
    local path = "bobcat/games/AS/macros/" .. macroName .. ".json"
    if not isfile(path) then
        return false, "Macro file not found."
    end
    
    local content = readfile(path)
    local boundary = "----WebKitFormBoundary" .. string.lower(string.sub(game:GetService("HttpService"):GenerateGUID(false), 1, 16))
    
    local body = "--" .. boundary .. "\r\n" ..
                 "Content-Disposition: form-data; name=\"file\"; filename=\"" .. macroName .. ".json\"\r\n" ..
                 "Content-Type: application/json\r\n\r\n" ..
                 content .. "\r\n" ..
                 "--" .. boundary .. "--\r\n"
                 
    local req = http_request or request or (syn and syn.request)
    if not req then
        return false, "Your exploit does not support HTTP requests with custom headers."
    end
    
    local success, response = pcall(function()
        return req({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
            },
            Body = body
        })
    end)
    
    if success and response and (response.StatusCode == 200 or response.StatusCode == 204 or response.StatusCode == 201) then
        return true
    else
        local errMsg = response and response.Body or "Unknown error"
        return false, "Discord API returned error: " .. tostring(errMsg)
    end
end
getgenv().exportMacroWebhook = exportMacroWebhook

local function extractFilename(url)
    local name = url:match("([^/]+)%.json")
    if not name then
        name = url:match("([^/]+)$")
    end
    if name then
        name = name:gsub("%%20", " "):gsub("[^%w%s%-_]", "")
    end
    return name or ("imported_" .. tostring(os.time()))
end

local function importMacroFromURL(urlOrData, customName)
    if not urlOrData or urlOrData == "" then
        return false, "Please enter a valid URL or JSON data."
    end
    
    local content = ""
    local isJson = urlOrData:match("^%s*{")
    
    if isJson then
        content = urlOrData
    else
        local success, fetched = pcall(function()
            return game:HttpGet(urlOrData)
        end)
        
        if not success or not fetched or fetched == "" then
            local req = http_request or request or (syn and syn.request)
            if req then
                local ok, resp = pcall(function()
                    return req({ Url = urlOrData, Method = "GET" })
                end)
                if ok and resp and resp.StatusCode == 200 then
                    fetched = resp.Body
                    success = true
                end
            end
        end
        
        if not success or not fetched or fetched == "" then
            return false, "Failed to download macro file from URL."
        end
        content = fetched
    end
    
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    
    if not ok or not decoded then
        return false, "The provided string or file is not valid JSON."
    end
    
    local macroName
    if customName and customName ~= "" then
        macroName = customName:gsub("[^%w%s%-_]", "")
    end
    if not macroName or macroName == "" then
        macroName = isJson and ("imported_" .. tostring(os.time())) or extractFilename(urlOrData)
    end
    local path = "bobcat/games/AS/macros/" .. macroName .. ".json"
    ensurePathFolders(path)
    
    writefile(path, content)
    
    if getgenv().refreshMacroDropdown then
        getgenv().refreshMacroDropdown()
    end
    
    return true, macroName
end
getgenv().importMacroFromURL = importMacroFromURL

local function getMacroRequiredUnits(macroName)
    local path = "bobcat/games/AS/macros/" .. macroName .. ".json"
    if not isfile(path) then return nil, "File not found" end
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or not data then return nil, "Invalid JSON" end
    
    local charMap = data.characterMap or {}
    local stepsData = data.steps or data
    
    local requiredUnits = {}
    local uniqueNames = {}
    
    for _, step in pairs(stepsData) do
        if typeof(step) == "table" and step.args and step.args[1] then
            local uuid = tostring(step.args[1])
            local name = charMap[uuid] or getgenv().Macro.CharacterMap[uuid] or uuid
            if name and name ~= "" then
                uniqueNames[name] = true
            end
        end
    end
    
    for name, _ in pairs(uniqueNames) do
        table.insert(requiredUnits, name)
    end
    table.sort(requiredUnits)
    return requiredUnits
end
getgenv().getMacroRequiredUnits = getMacroRequiredUnits

local function cleanUnitName(str)
    if not str then return "" end
    local cleaned = tostring(str):gsub("<[^>]+>", "")
    cleaned = cleaned:gsub("%s+", "")
    return cleaned:lower()
end

local function getIdentity()
    local ok, identity = pcall(function()
        if getthreadidentity then
            return getthreadidentity()
        elseif getidentity then
            return getidentity()
        elseif syn and syn.get_thread_identity then
            return syn.get_thread_identity()
        end
    end)
    if ok and identity then
        return identity
    end
    return nil
end

local function setIdentity(identity)
    local success = pcall(function()
        if setthreadidentity then
            setthreadidentity(identity)
        elseif setidentity then
            setidentity(identity)
        elseif syn and syn.set_thread_identity then
            syn.set_thread_identity(identity)
        end
    end)
    return success
end

local function equipMacroUnits(macroName)
    if getgenv().updatingUI then
        return true
    end
    if getgenv().isInLobby and not getgenv().isInLobby() then
        return true
    end
    
    local units, err = getMacroRequiredUnits(macroName)
    if not units then
        return false, "Failed to analyze macro units: " .. tostring(err)
    end
    
    if #units == 0 then
        return false, "No units found in this macro."
    end
    
    local pd = getPlayerData()
    
    local unequipRemote = game:GetService("ReplicatedStorage").Remotes.Characters:FindFirstChild("unequip_all")
    local equipRemote = game:GetService("ReplicatedStorage").Remotes.Characters:FindFirstChild("equip")
    if not equipRemote then
        return true
    end
    
    local ownedMap = {}
    if pd and pd.characters then
        for uuid, charData in pairs(pd.characters) do
            if typeof(charData) == "table" and charData.name then
                local cleanName = cleanUnitName(charData.name)
                if not ownedMap[cleanName] then
                    ownedMap[cleanName] = {}
                end
                table.insert(ownedMap[cleanName], { uuid = uuid, level = charData.level or 0 })
            end
        end
    end
    
    pcall(function()
        local sf = game:GetService("Players").LocalPlayer.PlayerGui.Menus.Characters.ScrollingFrame
        for _, child in ipairs(sf:GetChildren()) do
            local nameLabel = child:FindFirstChild("UnitName")
            if nameLabel and (nameLabel:IsA("TextLabel") or nameLabel:IsA("TextBox")) then
                local uName = nameLabel.Text
                local cleanName = cleanUnitName(uName)
                local uLevel = 0
                local levelLabel = child:FindFirstChild("UnitLevel")
                if levelLabel and (levelLabel:IsA("TextLabel") or levelLabel:IsA("TextBox")) then
                    uLevel = tonumber(levelLabel.Text:match("%d+")) or 0
                end
                
                local alreadyAdded = false
                if ownedMap[cleanName] then
                    for _, entry in ipairs(ownedMap[cleanName]) do
                        if entry.uuid == child.Name then
                            alreadyAdded = true
                            break
                        end
                    end
                else
                    ownedMap[cleanName] = {}
                end
                
                if not alreadyAdded then
                    table.insert(ownedMap[cleanName], { uuid = child.Name, level = uLevel })
                end
            end
        end
    end)
    
    local hasAny = false
    for _, _ in pairs(ownedMap) do
        hasAny = true
        break
    end
    if not hasAny then
        return false, "Failed to retrieve player inventory data from server and UI."
    end
    
    for name, list in pairs(ownedMap) do
        table.sort(list, function(a, b) return a.level > b.level end)
    end
    
    local equippedCount = 0
    local missingUnits = {}
    
    local charModule = getgenv().CachedCharModule
    if not charModule then
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" and rawget(v, "equip_visual") and rawget(v, "unequip_all") then
                    charModule = v
                    getgenv().CachedCharModule = v
                    break
                end
            end
        end)
    end
    
    if charModule then
        pcall(function()
            charModule.unequip_all()
        end)
        task.wait(0.2)
        
        for _, unitName in ipairs(units) do
            local cleanName = cleanUnitName(unitName)
            local list = ownedMap[cleanName]
            if list and #list > 0 then
                local item = list[1]
                local charData
                local getOk, getErr = pcall(function()
                    local getRemote = game:GetService("ReplicatedStorage").Remotes.Characters:FindFirstChild("get")
                    if getRemote then
                        charData = getRemote:InvokeServer(item.uuid)
                    end
                end)
                if not getOk then
                    Library:Notify("Get error: " .. tostring(getErr), 5)
                end
                if not charData then
                    charData = { id = item.uuid }
                end
                
                local oldId = getIdentity()
                setIdentity(2)
                
                local ok, equipErr = pcall(function()
                    charModule.selected = charData
                    charModule.equip()
                end)
                
                if oldId then
                    setIdentity(oldId)
                end
                
                if ok then
                    equippedCount = equippedCount + 1
                    task.wait(0.15)
                else
                    Library:Notify("Equip error: " .. tostring(equipErr), 5)
                end
            else
                table.insert(missingUnits, unitName)
            end
        end
    else
        if unequipRemote then
            unequipRemote:InvokeServer()
            task.wait(0.2)
        end
        
        for _, unitName in ipairs(units) do
            local cleanName = cleanUnitName(unitName)
            local list = ownedMap[cleanName]
            if list and #list > 0 then
                local item = list[1]
                local ok, ret = pcall(function()
                    return equipRemote:InvokeServer(item.uuid)
                end)
                if ok then
                    equippedCount = equippedCount + 1
                    task.wait(0.1)
                end
            else
                table.insert(missingUnits, unitName)
            end
        end
    end
    
    pcall(function()
        local getRemote = game:GetService("ReplicatedStorage").Remotes.Characters:FindFirstChild("get")
        if getRemote then getRemote:InvokeServer() end
    end)
    
    local statusMsg = string.format("Equipped %d macro units.", equippedCount)
    if #missingUnits > 0 then
        statusMsg = statusMsg .. "\nMissing units: " .. table.concat(missingUnits, ", ")
    end
    
    return true, statusMsg
end
getgenv().equipMacroUnits = equipMacroUnits

task.spawn(function()
    local redeemedCodes = {}
    local fallbackCodes = {
        "Tysm60kCCU!", "UPD0.5!", "Eclipse!", "LongMaintenance!", "10MilVisits!", 
        "50kCCU!", "EverythingIsPartOfMyPlan!", "Yokoso!",
        "40kCCU!", "5kInterested!", "Release!", "CRAZYSUPPORT!", 
        "SorryForLongMaintenance!", "Tysm30KCCU!"
    }
    while getgenv().uiActive ~= false or getgenv().isStartup do
        pcall(function()
            local autoRedeem = (getgenv().AccountControl and getgenv().AccountControl.AutoRedeemCodes) or (getgenv().config and getgenv().config.AutoRedeemCodes)
            if autoRedeem then
                if getgenv().isInLobby and getgenv().isInLobby() then
                    local useRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                        and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Codes")
                        and game:GetService("ReplicatedStorage").Remotes.Codes:FindFirstChild("use")
                    if useRemote and useRemote:IsA("RemoteFunction") then
                        for _, code in ipairs(fallbackCodes) do
                            if not redeemedCodes[code] then
                                pcall(function()
                                    useRemote:InvokeServer(code)
                                end)
                                redeemedCodes[code] = true
                                task.wait(0.5)
                            end
                        end
                    end
                end
            end
        end)
        task.wait(10)
    end
end)

task.spawn(function()
    if Macro.IdledLoopActive then return end
    Macro.IdledLoopActive = true
    while task.wait(30) do
        pcall(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.2)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

pcall(function()
    if getgenv().config and getgenv().config.DailyChallengeResetTime then
        if os.time() < getgenv().config.DailyChallengeResetTime then
            getgenv().DailyChallengeCompleted = true
        else
            getgenv().DailyChallengeCompleted = false
        end
    end

    local tempMatchFile = "bobcat/games/AS/temp_match.json"
    if isInLobby and isInLobby() then
        if isfile(tempMatchFile) then
            writefile(tempMatchFile, "{}")
        end
    else
        if isfile(tempMatchFile) then
            local content = readfile(tempMatchFile)
            local activeMatch = HttpService:JSONDecode(content)
            if activeMatch and activeMatch.world then
                getgenv().CurrentlyPlayingChallenge = activeMatch.difficulty
                getgenv().amc = activeMatch
            end
        end
    end
    if getgenv().config then
        getgenv().CurrentPriorityIndex = getgenv().config.CurrentPriorityIndex or 1
        getgenv().CurrentModeRuns = getgenv().config.CurrentModeRuns or 0

        if getgenv().config.MapRotation then
            task.spawn(function()
                task.wait(1)
                if getgenv().initMapRotation then
                    getgenv().initMapRotation()
                end
            end)
        end
    end
end)

--// Map Rotation Related
local mapRotationThread = nil

local function stopMapRotationLoop()
    if mapRotationThread then
        pcall(task.cancel, mapRotationThread)
        mapRotationThread = nil
    end
    pcall(function()
        if Macro.HasJoinedRoom then
            ReplicatedStorage.Remotes.Play.leave:FireServer()
            Macro.HasJoinedRoom = false
        end
    end)
end

local function startMapRotationLoop()
    if mapRotationThread then return end

    pcall(function()
        if getgenv().isInLobby and getgenv().isInLobby() then
            Macro.HasJoinedRoom = false
        end
    end)

    mapRotationThread = task.spawn(function()
        while true do
            local config = getgenv().config
            local mapRotation = (getgenv().AccountControl and getgenv().AccountControl.MapRotation) or (config and config.MapRotation)
            if not mapRotation or (getgenv().uiActive == false and not getgenv().isStartup) then
                mapRotationThread = nil
                break
            end

            local inLobby = false
            pcall(function()
                inLobby = getgenv().isInLobby and getgenv().isInLobby()
            end)

            if inLobby and not Macro.HasJoinedRoom then
                local index = getgenv().CurrentPriorityIndex or 1
                local mode = config["Priority" .. index] or "None"

                if mode ~= "None" and mode ~= "" then
                    local world = ""
                    local difficulty = "Normal"
                    local act = 1
                    local args = nil

                    if mode == "Challenge" then
                        local selectedChallenge = config["Priority" .. index .. "Map"] or "30m"
                        local rewardFilter = config.ChallengeRewardFilter or {}
                        local candidate = nil
                        local candidateData = nil

                        local cachedChallenges = getgenv().CachedChallenges
                        if cachedChallenges then
                            if selectedChallenge == "30m" and cachedChallenges["30m"] then
                                local mData = cachedChallenges["30m"]
                                if matchesFilter(mData.rewards, rewardFilter) then
                                    candidate = "30m"
                                    candidateData = mData
                                end
                            elseif selectedChallenge == "Katakara Bridge" then
                                local isHard = (getgenv().config and getgenv().config.SelectedDifficulty == "Hard")
                                local rewards
                                if isHard then
                                    rewards = {
                                        ["Hogyoku Orb"] = { amount = "1x", chance = "0.5%", pity = 200, order = 1 },
                                        ["Trait Shards"] = { amount = "1-2x", chance = "50%", cap = 100, order = 2 },
                                        ["XP"] = { amount = "35x", chance = "100%", order = 3 }
                                    }
                                else
                                    rewards = {
                                        ["Puppeteer"] = { amount = "1x", chance = "1%", pity = 100, order = 1 },
                                        ["Trait Shards"] = { amount = "1-2x", chance = "50%", cap = 100, order = 2 },
                                        ["XP"] = { amount = "25x", chance = "100%", order = 3 }
                                    }
                                end
                                local kbData = {
                                    world = "Katakara Bridge",
                                    act = 1,
                                    rewards = rewards
                                }
                                if matchesFilter(kbData.rewards, rewardFilter) then
                                    candidate = "Katakara Bridge"
                                    candidateData = kbData
                                end
                            elseif selectedChallenge == "The Hero Hunter" then
                                local hhData = {
                                    world = "The Hero Hunter",
                                    act = 1,
                                    rewards = nil
                                }
                                candidate = "The Hero Hunter"
                                candidateData = hhData
                            end
                        end

                        if candidate and candidateData then
                            world = candidateData.world
                            difficulty = (candidate == "Katakara Bridge" or candidate == "katakara_bridge" or candidate == "katakura_bridge") and (config.SelectedDifficulty or "Normal") or candidate
                            act = candidateData.act
                            args = {
                                boosted = true,
                                difficulty = difficulty,
                                act = act,
                                only_friends = false,
                                rewards = (candidate == "Katakara Bridge" or candidate == "katakara_bridge" or candidate == "katakura_bridge") and nil or candidateData.rewards,
                                mode = "Challenge",
                                world = world
                            }
                            getgenv().CurrentlyPlayingChallenge = candidate
                        end
                    else
                        world = config["Priority" .. index .. "Map"] or ""
                        difficulty = config["Priority" .. index .. "Difficulty"] or "Normal"
                        local lvlStr = config["Priority" .. index .. "Level"] or "1"
                        act = tonumber(tostring(lvlStr):match("%d+")) or 1
                        args = {
                            boosted = true,
                            act = act,
                            difficulty = difficulty,
                            mode = mode,
                            only_friends = false,
                            world = world
                        }
                    end

                    if args then
                        Macro.HasJoinedRoom = true

                        local createdRoom = false
                        local success, err = pcall(function()
                            local ok, joinErr = ReplicatedStorage.Remotes.Play.create_room:InvokeServer(args)
                            if ok ~= false and ok ~= nil then
                                createdRoom = true
                                pcall(function()
                                    writefile("bobcat/games/AS/temp_match.json", HttpService:JSONEncode({
                                        mode = mode,
                                        world = world,
                                        act = act,
                                        difficulty = difficulty
                                    }))
                                end)
                            else
                                warn("[AutoJoin] Failed to create room: " .. tostring(joinErr))
                            end
                        end)

                        if not success or not createdRoom then
                            Macro.HasJoinedRoom = false
                        else
                            local delayTime = tonumber(config.PriorityJoinDelay) or 5
                            local elapsed = 0
                            local aborted = false

                            while elapsed < delayTime do
                                task.wait(0.1)
                                elapsed = elapsed + 0.1
                                if not getgenv().uiActive or not config.MapRotation then
                                    aborted = true
                                    break
                                end
                            end

                            if aborted then
                                pcall(function()
                                    ReplicatedStorage.Remotes.Play.leave:FireServer()
                                end)
                                Macro.HasJoinedRoom = false
                            else
                                pcall(function()
                                    local remote = ReplicatedStorage.Remotes.Play.start
                                    if remote:IsA("RemoteFunction") then
                                        remote:InvokeServer()
                                    else
                                        remote:FireServer()
                                    end
                                end)
                                task.delay(5, function()
                                    local insideLobby = false
                                    pcall(function()
                                        insideLobby = getgenv().isInLobby and getgenv().isInLobby()
                                    end)
                                    if insideLobby and Macro.HasJoinedRoom then
                                        Macro.HasJoinedRoom = false
                                    end
                                end)
                            end
                        end
                    end
                end
            elseif not inLobby then
                Macro.HasJoinedRoom = false
            end
            task.wait(1)
        end
    end)
end

getgenv().stopMapRotationLoop = stopMapRotationLoop
getgenv().startMapRotationLoop = startMapRotationLoop

local function initMapRotation()
    if getgenv().updatingUI then return end
    local config = getgenv().config
    local mapRotation = (getgenv().AccountControl and getgenv().AccountControl.MapRotation) or (config and config.MapRotation)
    if not mapRotation then
        stopMapRotationLoop()
        return
    end

    local index = getgenv().CurrentPriorityIndex or 1
    local mode = config["Priority" .. index] or "None"

    if mode == "None" or mode == "" then
        stopMapRotationLoop()
        return
    end

    local isNormalMode = (mode == "Story" or mode == "Squadron" or mode == "Raid")
    if isNormalMode then
        local map = config["Priority" .. index .. "Map"]
        local diff = config["Priority" .. index .. "Difficulty"]
        local lvl = config["Priority" .. index .. "Level"]
        if map then setConfig("SelectedMap", map) end
        if diff then setConfig("SelectedDifficulty", diff) end
        if lvl then setConfig("SelectedLevel", lvl) end
        if mode == "Squadron" then
            setConfig("SelectedMode", "Squadron")
        elseif mode == "Raid" then
            setConfig("SelectedMode", "Raid")
        else
            setConfig("SelectedMode", "Story")
        end
    elseif mode == "Challenge" then
        setConfig("SelectedMode", "Challenge")
    end

    if getgenv().SyncUI then
        getgenv().SyncUI()
    end

    startMapRotationLoop()
end
getgenv().initMapRotation = initMapRotation

--// Auto Reconnect
task.spawn(function()
    local GuiService = game:GetService("GuiService")
    local TeleportService = game:GetService("TeleportService")
    local teleporting = false

    GuiService.ErrorMessageChanged:Connect(function(errorMessage)
        if errorMessage and errorMessage ~= "" then
            local autoReconnect = false
            pcall(function()
                if getgenv().config and getgenv().config.AutoReconnect then
                    autoReconnect = getgenv().config.AutoReconnect
                end
            end)
            if autoReconnect and not teleporting then
                teleporting = true
                task.wait(1)
                pcall(function()
                    TeleportService:Teleport(game.PlaceId)
                end)
            end
        end
    end)
end)

getgenv().Macro = Macro

return Macro
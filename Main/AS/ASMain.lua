--[[
    --// TABLE OF CONTENTS \\--
    1. Initialization
    2. Load Macro Engine
    3. Window Setup
    4. Tabs Setup
    5. Main Tab
    6. Miscellaneous Tab
    7. Macro Tab
    8. Config Tab
--]]

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

local repo = "https://raw.githubusercontent.com/nostrainu/ObsidianFork/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local folder, path = "bobcat", "as/config.json"

getgenv().Library = Library
getgenv().uiUpd = Library
getgenv().uiActive = true

--// Load Macro
local Macro = getgenv().Macro

if not Macro then
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
    Footer = "https://discord.gg/avPyBbTf",
    MobileButtonsSide = "Left",
    ShowMobileButtons = true,
    NotifySide = "Right",
    Center = true,
    SideBarText = false,
    ScrollLongText = true,
    Size = UDim2.fromOffset(650, 450),
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

    --// Miscellaneous / Misc Tab
    Misc = Window:AddTab("Miscellaneous", "book"),

    --// Webhook Tab
    Webhook = Window:AddTab("Webhook", "external-link")
}

--// Main Tab
local MainGroupBox = Tabs.Main:AddLeftGroupbox({
    Name = "Story",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

local findWorldsModule = getgenv().findWorldsModule
local updateMapModeLevelDropdowns = getgenv().updateMapModeLevelDropdowns

local mapValues = getgenv().initialMapValues or {"GT City", "Marine Lobby", "Ninja Village", "Katakura Wasteland"}
local modeValues = getgenv().initialModeValues or {"Story", "Squadron", "Raid"}
local difficultyValues = getgenv().initialDifficultyValues or {"Normal", "Hard"}
local levelValues = getgenv().initialLevelValues or {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}

MainGroupBox:AddDropdown("SelectedMap", {
    Text = "Select Map",
    Values = mapValues,
    Multi = false,
    Default = registerSetting("SelectedMap", "Ninja Village"),
    Callback = function(val)
        setConfig("SelectedMap", val)
        updateMapModeLevelDropdowns()
    end
})

MainGroupBox:AddDropdown("SelectedMode", {
    Text = "Select Mode",
    Values = modeValues,
    Multi = false,
    Default = registerSetting("SelectedMode", "Story"),
    Callback = function(val)
        setConfig("SelectedMode", val)
        updateMapModeLevelDropdowns()
    end
})

MainGroupBox:AddDropdown("SelectedDifficulty", {
    Text = "Select Difficulty",
    Values = difficultyValues,
    Multi = false,
    Default = registerSetting("SelectedDifficulty", "Normal"),
    Callback = function(val)
        setConfig("SelectedDifficulty", val)
        updateMapModeLevelDropdowns()
    end
})

MainGroupBox:AddDropdown("SelectedLevel", {
    Text = "Select Level",
    Values = levelValues,
    Multi = false,
    Default = registerSetting("SelectedLevel", "1"),
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
    Values = {"30m", "1d"},
    Multi = true,
    Default = registerSetting("ChallengeType", { ["30m"] = true, ["1d"] = true }),
    Callback = function(val) setConfig("ChallengeType", val) end
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
            SyncUI()
        end
    end
})

local RaidGroupBox = Tabs.Main:AddLeftGroupbox({
    Name = "Raid",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

RaidGroupBox:AddDropdown("SelectedRaidAct", {
    Text = "Select Raid Boss",
    Values = {"Super Beby 2", "Super Android", "Shanron", "Shanron (Omega)"},
    Multi = false,
    Default = registerSetting("SelectedRaidAct", "Shanron"),
    Callback = function(val) setConfig("SelectedRaidAct", val) end
})

RaidGroupBox:AddSlider("RaidDelay", {
    Text = "Raid Join Delay",
    Default = registerSetting("RaidDelay", 3),
    Min = 1, Max = 15, Rounding = 0,
    Suffix = "s",
    Callback = function(val) setConfig("RaidDelay", val) end
})

RaidGroupBox:AddToggle("AutoRaid", {
    Text = "Auto Raid",
    Default = registerSetting("AutoRaid", false),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("AutoRaid", val)
        if val then
            setConfig("AutoJoin", false)
            setConfig("AutoChallenge", false)
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

local PriorityGroupBox = Tabs.Misc:AddRightGroupbox({
    Name = "Autoplay Priority Settings",
    Center = true,
    Collapsible = true,
    DefaultCollapsed = false
})

PriorityGroupBox:AddToggle("PriorityCycling", {
    Text = "Enable Priority Cycling",
    Default = registerSetting("PriorityCycling", false),
    Callback = function(val)
        if getgenv().updatingUI then return end
        setConfig("PriorityCycling", val)
        if val then
            if not getgenv().isStartup then
                getgenv().CurrentPriorityIndex = 1
                setConfig("CurrentPriorityIndex", 1)
                getgenv().CurrentModeRuns = 0
                setConfig("CurrentModeRuns", 0)
            end
            if getgenv().initPriorityCycling then
                getgenv().initPriorityCycling()
            end
        end
    end
})

PriorityGroupBox:AddDropdown("Priority1", {
    Text = "Priority 1",
    Values = {"None", "Challenge", "Story", "Squadron", "Raid"},
    Default = registerSetting("Priority1", "Challenge"),
    Callback = function(val)
        setConfig("Priority1", val)
        if getgenv().config.PriorityCycling and getgenv().initPriorityCycling then
            getgenv().initPriorityCycling()
        end
    end
})

PriorityGroupBox:AddDropdown("Priority2", {
    Text = "Priority 2",
    Values = {"None", "Challenge", "Story", "Squadron", "Raid"},
    Default = registerSetting("Priority2", "Story"),
    Callback = function(val)
        setConfig("Priority2", val)
        if getgenv().config.PriorityCycling and getgenv().initPriorityCycling then
            getgenv().initPriorityCycling()
        end
    end
})

PriorityGroupBox:AddDropdown("Priority3", {
    Text = "Priority 3",
    Values = {"None", "Challenge", "Story", "Squadron", "Raid"},
    Default = registerSetting("Priority3", "Squadron"),
    Callback = function(val)
        setConfig("Priority3", val)
        if getgenv().config.PriorityCycling and getgenv().initPriorityCycling then
            getgenv().initPriorityCycling()
        end
    end
})

PriorityGroupBox:AddSlider("PriorityRunsLimit", {
    Text = "Runs Per Mode",
    Default = registerSetting("PriorityRunsLimit", 5),
    Min = 1, Max = 50, Rounding = 0,
    Suffix = " run(s)",
    Callback = function(val) setConfig("PriorityRunsLimit", val) end
})

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
    Finished = true,
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
    Finished = true,
    Callback = function(val) setConfig("DiscordUserID", val) end
})

WebhookGroupBox:AddButton("Test Webhook", function()
    local url = Library.Options.WebhookURL and Library.Options.WebhookURL.Value or ""
    if url == "" or not url:find("discord.com") then
        Library:Notify("Invalid Discord Webhook URL!", 3)
        return
    end
    
    pcall(function()
        local getgenv = getgenv
        if getgenv().sendDiscordWebhook then
            getgenv().sendDiscordWebhook(
                "Test Webhook",
                "Your Anime Squadron script webhook is configured correctly!",
                { { name = "Status", value = "Online / Working", inline = true } }
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
            local path = "as/macros/" .. selected .. ".json"
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
                if selected ~= "" and selected ~= "---" and isfile("as/macros/" .. selected .. ".json") then
                    Macro:SaveMacro(selected)
                    if Library.Options.MacroSelect then
                        Library.Options.MacroSelect:SetValues(Macro:GetMacroList())
                    end
                end
            end
            local statusText = getgenv().MacroStatus or ("Stopped — " .. #Macro.Recording .. " steps")
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
    Finished = true,
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
            MacroStatus:Update({ State = "Loaded: " .. val .. " — " .. #Macro.Recording .. " steps" })
            if not getgenv().isStartup and getgenv().config.AutoEquipUnits and val ~= "" and val ~= "---" then
                task.spawn(function()
                    local ok, msg = getgenv().equipMacroUnits(val)
                    if ok then
                        Library:Notify(msg, 5)
                    else
                        Library:Notify("Failed to equip: " .. tostring(msg), 5)
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
    Finished = true,
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
    if ok then
        Library:Notify(msg, 5)
    else
        Library:Notify("Failed to equip: " .. tostring(msg), 5)
    end
end)

--// Config Tab
Window:AddTabSection("Config")
local SettingsTab = Window:AddTab({ Name = "Settings", Icon = "settings", Side = "Header", Visible = false })
local InfoTab = Window:AddTab({ Name = "Info", Icon = "info", Side = "Sidebar" })

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

SettingsGroup:AddToggle("AutoExecute", {
    Text = "Auto Execute",
    Default = registerSetting("AutoExecute", false),
    Callback = function(val) setConfig("AutoExecute", val) end
})

SettingsGroup:AddButton("Unload", function()
    Library:Unload()
end)

local InfoMiddleTabbox = InfoTab:AddMiddleTabbox({
    Name = "Changelogs",
    IconName = "info",
    Collapsible = true,
    Center = true,
    DefaultCollapsed = false
})

local InfoSubTab = InfoMiddleTabbox:AddTab("v1.0")
InfoSubTab:AddLabel({ Text = "Anime Squadron Macro v1.0" })
InfoSubTab:AddLabel({ Text = "• Added Macro Tab: Record, replay, save, load & auto-equip" })
InfoSubTab:AddLabel({ Text = "• Added Auto Joiner: Story, Squadron, Raid, and Infinite" })
InfoSubTab:AddLabel({ Text = "• Added Priority Cycling System" })
InfoSubTab:AddLabel({ Text = "• Added Webhook Settings tab" })
InfoSubTab:AddLabel({ Text = "• Added Auto Summon (to be fixed)" })
InfoSubTab:AddLabel({ Text = "• Bug Fixes: Fixed macro deletion confirmation window" })

SyncUI()
updateMapModeLevelDropdowns()
getgenv().isStartup = false

Library:OnUnload(function()
    getgenv().uiActive = false
    getgenv().uiUpd = nil
    _G.UILoaded = nil
    _G.LastUILoadTime = nil
end)
local BobcatWS = {}

local SERVER_URL = "wss://bobcatserver.onrender.com/ws"
local AUTH_KEY = "069bfe9d585a01f57cef293741d5a8f3"

local HttpService = game:GetService("HttpService")

local ws = nil
local connected = false
local reconnecting = false
local onSettingsCallback = nil
local onStatusCallback = nil
local pingThread = nil
local role = "alt"
local currentGame = "unknown"
local currentHost = ""
local currentName = ""

local function safeEncode(t)
    local ok, result = pcall(HttpService.JSONEncode, HttpService, t)
    return ok and result or nil
end

local function safeDecode(s)
    local ok, result = pcall(HttpService.JSONDecode, HttpService, s)
    return ok and result or nil
end

local function cleanup()
    connected = false
    if pingThread then
        pcall(task.cancel, pingThread)
        pingThread = nil
    end
    if ws then
        pcall(function() ws:Close() end)
        ws = nil
    end
end

local function connect()
    if reconnecting then return end

    if not WebSocket then
        warn("[BobcatWS] WebSocket not supported on this executor")
        return
    end

    reconnecting = true

    task.spawn(function()
        while true do
            cleanup()
            local ok, result = pcall(function()
                ws = WebSocket.connect(SERVER_URL)
            end)

            if not ok or not ws then
                warn("[BobcatWS] Connection failed: " .. tostring(result))
                task.wait(5)
                reconnecting = true
            else
                local authPayload = safeEncode({
                    key = AUTH_KEY,
                    game = currentGame,
                    host = currentHost,
                    name = currentName,
                    role = role
                })

                pcall(function() ws:Send(authPayload) end)

                pingThread = task.spawn(function()
                    while ws do
                        task.wait(10)
                        if ws then
                            pcall(function()
                                ws:Send(safeEncode({ type = "ping" }))
                            end)
                        end
                    end
                end)

                ws.OnMessage:Connect(function(msg)
                    local data = safeDecode(msg)
                    if not data then return end

                    if data.type == "connected" then
                        connected = true
                        reconnecting = false
                        if role == "alt" then
                            pcall(function()
                                ws:Send(safeEncode({
                                    type = "join",
                                    name = currentName,
                                    userId = tostring(game:GetService("Players").LocalPlayer.UserId)
                                }))
                            end)
                        end
                    elseif data.type == "join" and onStatusCallback then
                        pcall(onStatusCallback, data.name, { UserId = data.userId, Status = "Online", LastActive = os.time() })
                    elseif data.type == "settings" and onSettingsCallback then
                        pcall(onSettingsCallback, data.payload)
                    elseif data.type == "status" and onStatusCallback then
                        pcall(onStatusCallback, data.name, data.payload)
                    end
                end)

                ws.OnClose:Connect(function()
                    connected = false
                    ws = nil
                    if getgenv().uiActive ~= false then
                        task.wait(5)
                        reconnecting = false
                        connect()
                    end
                end)

                reconnecting = false
                warn("[BobcatWS] Connected as " .. role .. ": " .. currentName)
                break
            end
        end
    end)
end

function BobcatWS.ConnectHost(gameName, hostName)
    if connected or reconnecting then return end
    role = "host"
    currentGame = gameName
    currentHost = hostName
    currentName = hostName
    connect()
end

function BobcatWS.ConnectAlt(gameName, hostName, altName, settingsCallback)
    if connected or reconnecting then return end
    role = "alt"
    currentGame = gameName
    currentHost = hostName
    currentName = altName
    onSettingsCallback = settingsCallback
    connect()
end

function BobcatWS.OnStatus(callback)
    onStatusCallback = callback
end

function BobcatWS.PushSettings(target, payload)
    if not connected or not ws then return end
    local msg = safeEncode({
        type = "settings",
        target = target or "all",
        payload = payload
    })
    if msg then
        pcall(function() ws:Send(msg) end)
    end
end

function BobcatWS.PushStatus(payload)
    if not connected or not ws then return end
    local msg = safeEncode({
        type = "status",
        payload = payload
    })
    if msg then
        pcall(function() ws:Send(msg) end)
    end
end

function BobcatWS.IsConnected()
    return connected
end

function BobcatWS.Disconnect()
    cleanup()
end

return BobcatWS

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
local pendingMessages = {}

local function log(msg)
    warn("[BobcatWS] " .. tostring(msg))
end

local function safeEncode(t)
    local ok, result = pcall(HttpService.JSONEncode, HttpService, t)
    if not ok then log("JSON encode error: " .. tostring(result)) end
    return ok and result or nil
end

local function safeDecode(s)
    local ok, result = pcall(HttpService.JSONDecode, HttpService, s)
    if not ok then log("JSON decode error: " .. tostring(result)) end
    return ok and result or nil
end

local function setConnected(val)
    if connected ~= val then
        connected = val
        log("connected flag changed to: " .. tostring(val))
    end
end

local function setReconnecting(val)
    if reconnecting ~= val then
        reconnecting = val
        log("reconnecting flag changed to: " .. tostring(val))
    end
end

local function flushPending()
    if onStatusCallback and #pendingMessages > 0 then
        log("Flushing " .. #pendingMessages .. " pending messages")
        for _, item in ipairs(pendingMessages) do
            local ok, err = pcall(onStatusCallback, item.name, item.payload)
            if not ok then log("OnStatus flush error: " .. tostring(err)) end
        end
        table.clear(pendingMessages)
    end
end

local function cleanup()
    setConnected(false)
    if pingThread then
        pcall(task.cancel, pingThread)
        pingThread = nil
    end
    if ws then
        pcall(function() ws:Close() end)
        ws = nil
    end
end

local function sendMsg(data)
    local msg = safeEncode(data)
    if not msg then return end
    log("SEND: " .. msg)
    local ok, err = pcall(function() ws:Send(msg) end)
    if not ok then log("Send error: " .. tostring(err)) end
end

local function connect()
    if reconnecting then log("connect() blocked: already reconnecting") return end

    if not WebSocket then
        log("WebSocket not supported on this executor")
        return
    end

    log("connect() called - role=" .. role .. " game=" .. currentGame .. " host=" .. currentHost .. " name=" .. currentName)
    setReconnecting(true)

    task.spawn(function()
        log("Reconnect loop started")
        while true do
            cleanup()
            log("Attempting WebSocket.connect to " .. SERVER_URL)
            local ok, result = pcall(function()
                ws = WebSocket.connect(SERVER_URL)
            end)

            if not ok or not ws then
                log("Connection failed: " .. tostring(result))
                task.wait(5)
                setReconnecting(true)
            else
                log("WebSocket connected, sending auth")
                local authPayload = {
                    key = AUTH_KEY,
                    game = currentGame,
                    host = currentHost,
                    name = currentName,
                    role = role
                }
                log("Auth payload: game=" .. currentGame .. " host=" .. currentHost .. " name=" .. currentName .. " role=" .. role)
                sendMsg(authPayload)

                pingThread = task.spawn(function()
                    while ws do
                        task.wait(10)
                        if ws then
                            local ok2, err2 = pcall(function()
                                ws:Send(safeEncode({ type = "ping" }))
                            end)
                            if not ok2 then log("Ping error: " .. tostring(err2)) end
                        end
                    end
                end)

                ws.OnMessage:Connect(function(msg)
                    log("RECV: " .. tostring(msg))
                    local data = safeDecode(msg)
                    if not data then return end

                    if data.type == "connected" then
                        log("'connected' packet received from server - room=" .. tostring(data.room))
                        setConnected(true)
                        setReconnecting(false)
                        if role == "alt" then
                            log("Sending 'join' packet")
                            sendMsg({
                                type = "join",
                                name = currentName,
                                userId = tostring(game:GetService("Players").LocalPlayer.UserId)
                            })
                            log("Sending initial 'status' packet")
                            sendMsg({
                                type = "status",
                                payload = {
                                    Status = "Waiting",
                                    LastActive = os.time(),
                                    UserId = tostring(game:GetService("Players").LocalPlayer.UserId)
                                }
                            })
                        end
                    elseif data.type == "error" then
                        log("Server error: " .. tostring(data.msg))
                    elseif data.type == "join" then
                        log("'join' received for: " .. tostring(data.name))
                        local payload = { UserId = data.userId, Status = "Online", LastActive = os.time() }
                        if onStatusCallback then
                            log("Calling OnStatus for join: " .. tostring(data.name))
                            local ok2, err2 = pcall(onStatusCallback, data.name, payload)
                            if not ok2 then log("OnStatus error: " .. tostring(err2)) end
                        else
                            log("OnStatus not set yet, queuing join for: " .. tostring(data.name))
                            table.insert(pendingMessages, { name = data.name, payload = payload })
                        end
                    elseif data.type == "status" then
                        log("'status' received for: " .. tostring(data.name))
                        if onStatusCallback then
                            local ok2, err2 = pcall(onStatusCallback, data.name, data.payload)
                            if not ok2 then log("OnStatus error: " .. tostring(err2)) end
                        else
                            log("OnStatus not set yet, queuing status for: " .. tostring(data.name))
                            table.insert(pendingMessages, { name = data.name, payload = data.payload })
                        end
                    elseif data.type == "settings" then
                        log("'settings' received")
                        if onSettingsCallback then
                            local ok2, err2 = pcall(onSettingsCallback, data.payload)
                            if not ok2 then log("Settings callback error: " .. tostring(err2)) end
                        else
                            log("Settings callback not set")
                        end
                    elseif data.type == "pong" then
                        log("pong received")
                    else
                        log("Unknown packet type: " .. tostring(data.type))
                    end
                end)

                ws.OnClose:Connect(function()
                    log("WebSocket closed")
                    setConnected(false)
                    ws = nil
                    if getgenv().uiActive ~= false then
                        log("Scheduling reconnect in 5s")
                        task.wait(5)
                        setReconnecting(false)
                        connect()
                    end
                end)

                setReconnecting(false)
                log("Connected as " .. role .. ": " .. currentName)
                break
            end
        end
        log("Reconnect loop ended")
    end)
end

function BobcatWS.ConnectHost(gameName, hostName)
    log("ConnectHost() called - game=" .. tostring(gameName) .. " host=" .. tostring(hostName))
    log("LocalPlayer.Name=" .. tostring(game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Name))
    if connected or reconnecting then
        log("ConnectHost() blocked: connected=" .. tostring(connected) .. " reconnecting=" .. tostring(reconnecting))
        return
    end
    role = "host"
    currentGame = gameName
    currentHost = hostName
    currentName = hostName
    connect()
end

function BobcatWS.ConnectAlt(gameName, hostName, altName, settingsCallback)
    log("ConnectAlt() called - game=" .. tostring(gameName) .. " host=" .. tostring(hostName) .. " alt=" .. tostring(altName))
    log("LocalPlayer.Name=" .. tostring(game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Name))
    if connected or reconnecting then
        log("ConnectAlt() blocked: connected=" .. tostring(connected) .. " reconnecting=" .. tostring(reconnecting))
        return
    end
    role = "alt"
    currentGame = gameName
    currentHost = hostName
    currentName = altName
    onSettingsCallback = settingsCallback
    connect()
end

function BobcatWS.OnStatus(callback)
    log("OnStatus() registered")
    onStatusCallback = callback
    flushPending()
end

function BobcatWS.PushSettings(target, payload)
    log("PushSettings() called for target=" .. tostring(target))
    if not connected or not ws then
        log("PushSettings() skipped: IsConnected=" .. tostring(connected))
        return
    end
    sendMsg({ type = "settings", target = target or "all", payload = payload })
end

function BobcatWS.PushStatus(payload)
    log("PushStatus() called")
    if not connected or not ws then
        log("PushStatus() skipped: IsConnected=" .. tostring(connected))
        return
    end
    sendMsg({ type = "status", payload = payload })
end

function BobcatWS.IsConnected()
    return connected
end

function BobcatWS.Disconnect()
    log("Disconnect() called")
    cleanup()
end

return BobcatWS

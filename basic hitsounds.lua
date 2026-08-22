local p = entity.GetLocalPlayer()
local sound = "agpa2.wav"
local previousHealth = {}
local debugEnabled = true
local lastDebug = 0

local function debugPrint(message)
    if not debugEnabled then
        return
    end

    local now = utility.GetTickCount()
    if now - lastDebug >= 1000 then
        print("[hitsounds] " .. message)
        lastDebug = now
    end
end

local function getCustomChar(player)
    if not player then
        return nil
    end

    if player.Character then
        return player.Character
    else
        local folder = game.Workspace
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Model") and child.Name == player.Name then
                    return child
                end    
            end
        end
    end
end

local function getCustomCharRed(player)
    if not player then
        return nil
    end
    if player.Character then
        return player.Character
    else
        local folder = game.Workspace
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child.ClassName == "Folder" and child.Name == "Characters" then
                    for _, child2 in ipairs(child:GetChildren()) do
                        if child2:IsA("Model") and child2.Name == player.Name then
                            return child2
                        end
                    end
                end
            end
        end
    end
end

local function getHP(player)
    local char = getCustomChar(player)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Address then
        local healthAddress = hum.Address + 0x190
        local health = memory.Read("float", healthAddress)
        print(tostring(health))
        return health
    end
end




local function getMouseVals()
    local mouse = utility.GetMousePos()
    if not mouse then
        debugPrint("GetMousePos returned nil")
        return nil, nil
    end
    return mouse[1], mouse[2]
end

local function playSound(sound)
    if sound then
        local soundData = file.read(tostring(sound))
        if soundData then
            debugPrint("playing " .. tostring(sound))
            audio.PlaySound(soundData, false, 1, 1)
        else
            debugPrint("file.read failed for " .. tostring(sound))
        end
    end
end

local function getClosest()
    local closest = nil
    local closestDist = math.huge
    local mouseX, mouseY = getMouseVals()
    if not mouseX or not mouseY then
        return nil
    end

    local players = entity.GetPlayers()
    debugPrint("players=" .. tostring(#players) .. ", mouse=" .. tostring(mouseX) .. "," .. tostring(mouseY))

    for _, player in ipairs(players) do
        if player ~= p then
            local customChar = getCustomChar(player)
            if not customChar then
                customChar = getCustomCharRed(player)
            local rootPart = customChar and customChar.HumanoidRootPart
            if not rootPart then
                debugPrint("no HumanoidRootPart for " .. tostring(player.Name))
            end

            if rootPart then
                local screenX, screenY, onScreen = utility.WorldToScreen(rootPart.Position)
                if onScreen then
                local dx = mouseX - screenX
                local dy = mouseY - screenY
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < closestDist then
                    closestDist = dist
                    closest = player
                    debugPrint("closest=" .. tostring(closest.Name) .. ", distance=" .. tostring(dist))
                end
                else
                    debugPrint(tostring(player.Name) .. " is off screen")
                end
            end
        end
    end
    end
    return closest
end

local function trackClosest()
    local closest = getClosest()
    if closest then
        local health = getHP(closest)
        if health then
            local playerName = tostring(closest.Name)
            local previous = previousHealth[playerName]
            debugPrint(playerName .. " health=" .. tostring(health) .. ", previous=" .. tostring(previous))
            if previous and health < previous then
                print("[hitsounds] damage detected on " .. playerName .. ": " .. tostring(previous - health))
                playSound(sound)
            end
            previousHealth[playerName] = health
        else
            debugPrint("health read failed for " .. tostring(closest.Name))
        end
    else
        debugPrint("no target found")
    end
end

local function on_update()
    p = entity.GetLocalPlayer()
    if not p then
        debugPrint("local player unavailable")
        return
    end
    trackClosest()
end

cheat.register("onUpdate", on_update)
print("[hitsounds] loaded; debug=" .. tostring(debugEnabled))
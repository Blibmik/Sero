-- hitsounds.lua
-- Plays a sound when the target closest to your mouse (within FOV) takes damage.

local CONFIG = {
    sound         = "agpa2.wav", -- WAV file located in C:\Serotonin\files\
    fovRadius     = 150,         -- max pixel distance from mouse; set math.huge to disable
    showFovCircle = true,        -- draw the FOV circle around the cursor
    pollInterval  = 50,          -- ms between scans (docs recommend throttling player loops)
    debugEnabled  = true,
}

local HUMANOID_HEALTH_OFFSET = 0x190

local p = entity.GetLocalPlayer()
local previousHealth = {}
local lastDebug = 0
local lastScan = 0

local function debugPrint(message)
    if not CONFIG.debugEnabled then return end
    local now = utility.GetTickCount()
    if now - lastDebug >= 1000 then
        print("[hitsounds] " .. message)
        lastDebug = now
    end
end

local function getCustomChar(player)
    if not player then return nil end
    if player.Character then
        return player.Character
    end
    local folder = game.Workspace
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") and child.Name == player.Name then
                return child
            end
        end
    end
end

local function getCustomCharRed(player)
    if not player then return nil end
    if player.Character then
        return player.Character
    end
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

local function getCharacter(player)
    return getCustomChar(player) or getCustomCharRed(player)
end

local function getHP(char)
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or type(hum.Address) ~= "number" then
        return nil
    end
    local addr = hum.Address + HUMANOID_HEALTH_OFFSET
    local health = memory.Read("float", addr)
    -- reject garbage reads so they don't trigger false hits
    if health ~= health or health < 0 or health > 1000000 then
        return nil
    end
    return health
end

local function playSound(sound)
    local soundData = file.read(tostring(sound))
    if soundData then
        audio.PlaySound(soundData, false, 1, 1)
    else
        debugPrint("file.read failed for " .. tostring(sound))
    end
end

local function getClosest()
    local mp = utility.GetMousePos()
    if not mp then
        debugPrint("GetMousePos returned nil")
        return nil, nil
    end
    local mouseX, mouseY = mp[1], mp[2]

    -- seeding with fovRadius makes the FOV cap automatic:
    -- anything farther than this never wins the comparison
    local closest, closestDist = nil, CONFIG.fovRadius

    local players = entity.GetPlayers()
    for _, player in ipairs(players) do
        if player ~= p then
            local char = getCharacter(player)
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local screenX, screenY, onScreen = utility.WorldToScreen(rootPart.Position)
                if onScreen then
                    local dx = mouseX - screenX
                    local dy = mouseY - screenY
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < closestDist then
                        closestDist = dist
                        closest = player
                    end
                end
            end
        end
    end
    return closest, closestDist
end

local function trackClosest()
    local closest, dist = getClosest()
    if not closest then return end

    local char = getCharacter(closest)
    local health = getHP(char)
    if not health then
        debugPrint("health read failed for " .. tostring(closest.Name))
        return
    end

    local playerName = tostring(closest.Name)
    local previous = previousHealth[playerName]

    if previous and health < previous then
        print(string.format("[hitsounds] damage on %s (%.0f px from mouse): -%g",
            playerName, dist, previous - health))
        playSound(CONFIG.sound)
    end
    previousHealth[playerName] = health
end

local function on_update()
    p = entity.GetLocalPlayer()
    if not p then return end

    local now = utility.GetTickCount()
    if now - lastScan < CONFIG.pollInterval then return end
    lastScan = now

    trackClosest()
end

-- FOV visualization (draw.* is only valid inside paint)
cheat.register("paint", function()
    if not CONFIG.showFovCircle or CONFIG.fovRadius == math.huge then return end
    local mp = utility.GetMousePos()
    if not mp then return end
    draw.Circle(mp[1], mp[2], CONFIG.fovRadius, Color3.fromRGB(255, 255, 255), 1, 64, 0)
end)

cheat.register("newPlace", function()
    previousHealth = {} -- don't carry stale baselines across teleports
end)

cheat.register("shutdown", function()
    previousHealth = {}
end)

cheat.register("onUpdate", on_update)
print("[hitsounds] loaded; fov=" .. tostring(CONFIG.fovRadius) .. "px, debug=" .. tostring(CONFIG.debugEnabled))


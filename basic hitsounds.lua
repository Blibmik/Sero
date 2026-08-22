-- Universal Serotonin Hitsounds & Hitmarkers
local cfg = {
    soundFile = "agpa2.wav",
    radius = 12,                  -- Hitmarker line size
    hitmarkerDuration = 400,      -- Duration in milliseconds to show hitmarker
    color = Color3.fromRGB(255, 255, 255),
    showDamageText = true,
    damageColor = Color3.fromRGB(255, 60, 60),
    volume = 1.0,
    pitch = 1.0,
    targetFov = 300,              -- Max screen distance from crosshair to track target
}

-- State tables
local lastHealth = {}
local hitmarkers = {}
local localPlayer = nil

-- Safely load sound file from C:\Serotonin\files\
local soundData = nil
if file and file.exists and file.exists(cfg.soundFile) then
    soundData = file.read(cfg.soundFile)
elseif file and file.read then
    local ok, res = pcall(file.read, cfg.soundFile)
    if ok and res and #res > 0 then
        soundData = res
    end
end

-- Safe sound player
local function playHitsound()
    if soundData and #soundData > 0 then
        pcall(function()
            audio.PlaySound(soundData, false, cfg.volume, cfg.pitch)
        end)
    elseif audio and audio.beep then
        pcall(function()
            audio.beep(1200, 60)
        end)
    end
end

-- Get Local Player safely
local function getLocalPlayer()
    if entity and entity.GetLocalPlayer then
        local lp = entity.GetLocalPlayer()
        if lp then return lp end
    end
    if game and game.GetService then
        local ok, players = pcall(game.GetService, "Players")
        if ok and players then
            return players.LocalPlayer
        end
    end
    return nil
end

local function getHumanoidHealth(player)
    if not player then return nil end

    local char = player.Character
    if not char then return nil end

    local hum = nil
    if char.FindFirstChildOfClass then
        hum = char:FindFirstChildOfClass("Humanoid")
    end
    if not hum and char.FindFirstChild then
        hum = char:FindFirstChild("Humanoid")
    end
    if not hum and char.Humanoid then
        hum = char.Humanoid
    end

    if not hum then return nil end

    if hum.Health and type(hum.Health) == "number" then
        return hum.Health
    end

    if hum.Address and memory and memory.Read and memory.IsValid then
        local offsets = { 0x194, 0x18C, 0x190 }
        for _, offset in ipairs(offsets) do
            local healthAddr = hum.Address + 0x194
            if memory.IsValid(healthAddr) then
                local hp = memory.Read("float", healthAddr)
                if hp and hp >= 0 and hp <= 100000 then
                    return hp
                end
            end
        end
    end

    return nil
end

local function spawnHitmarker(screenX, screenY, damage)
    local now = utility.GetTickCount()
    table.insert(hitmarkers, {
        x = screenX,
        y = screenY,
        startTime = now,
        damage = damage and math.floor(damage + 0.5) or nil
    })
end

local function onUpdate()
    localPlayer = getLocalPlayer()
    if not localPlayer then return end

    local players = entity and entity.GetPlayers and entity.GetPlayers()
    if not players then return end

    local mousePos = utility.GetMousePos()
    local mx = mousePos[1] or 0
    local my = mousePos[2] or 0

    for _, p in ipairs(players) do
        if p ~= localPlayer then
            local pName = p.Name or tostring(p)
            local currentHp = getHumanoidHealth(p)

            if currentHp ~= nil then
                local prevHp = lastHealth[pName]

                if prevHp ~= nil and currentHp < prevHp then
                    local diff = prevHp - currentHp
                    -- Filter out respawns / minuscule float jitter
                    if diff >= 0.5 and prevHp > 0 then
                        -- Determine hitmarker screen position
                        local hitX, hitY = mx, my
                        local headPos = p.GetBonePosition and p:GetBonePosition("Head")
                        if headPos then
                            local sX, sY, onScreen = utility.WorldToScreen(headPos)
                            if onScreen then
                                hitX, hitY = sX, sY
                            end
                        end

                        playHitsound()
                        spawnHitmarker(hitX, hitY, diff)
                    end
                end

                lastHealth[pName] = currentHp
            else
                -- Reset when character is dead/gone
                lastHealth[pName] = nil
            end
        end
    end
end

-- Rendering loop (per frame)
local function onPaint()
    local now = utility.GetTickCount()
    local r = cfg.radius
    local halfR = r / 2

    for i = #hitmarkers, 1, -1 do
        local hm = hitmarkers[i]
        local elapsed = now - hm.startTime

        if elapsed >= cfg.hitmarkerDuration then
            table.remove(hitmarkers, i)
        else
            local progress = elapsed / cfg.hitmarkerDuration
            local alpha = 1.0 - progress
            local x = hm.x
            local y = hm.y

            -- Draw COD-style 4 diagonal lines: \ /
            -- Top-Left
            draw.Line(x - r, y - r, x - halfR, y - halfR, cfg.color, 2)
            -- Top-Right
            draw.Line(x + r, y - r, x + halfR, y - halfR, cfg.color, 2)
            -- Bottom-Left
            draw.Line(x - r, y + r, x - halfR, y + halfR, cfg.color, 2)
            -- Bottom-Right
            draw.Line(x + r, y + r, x + halfR, y + halfR, cfg.color, 2)

            -- Optional damage text floating upward
            if cfg.showDamageText and hm.damage and hm.damage > 0 then
                local offsetY = math.floor(progress * 25)
                draw.TextOutlined(
                    "-" .. tostring(hm.damage),
                    x + r + 4,
                    y - halfR - offsetY,
                    cfg.damageColor,
                    "Verdana"
                )
            end
        end
    end
end

-- Reset state on place change / teleport
local function onNewPlace()
    lastHealth = {}
    hitmarkers = {}
end

-- Register cheat event hooks
cheat.Register("onUpdate", onUpdate)
cheat.Register("paint", onPaint)
cheat.Register("newPlace", onNewPlace)


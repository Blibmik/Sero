-- tracers.lua
-- Draws lines from the local player's head to every other player's target part.
-- Ported from hitsounds.lua: same character-resolution + throttled-scan skeleton.
-- Endpoints are cached in world space on the update thread and projected
-- per-frame inside paint, which is what makes them behave like 3D tracers.

local CONFIG = {
    targetPart    = "HumanoidRootPart",     -- end point of each tracer ("Head", "Torso", ...)
    maxDistance   = math.huge,              -- world-stud cap; math.huge disables
    useVisibility = true,                   -- green when LOS is clear, red when blocked
    visibleColor  = Color3.fromRGB(0, 255, 120),
    hiddenColor   = Color3.fromRGB(255, 70, 70),
    thickness     = 1,
    showEndDot    = true,                   -- small dot at the end point
    dotRadius     = 3,
    pollInterval  = 50,                     -- ms between player scans (update thread)
    selfBlockEps  = 3,                      -- studs: a ray hit this close to the target is treated as their own body, not a wall
    debugEnabled  = true,
}

local p = entity.GetLocalPlayer()
local targets = {}      -- { {name, pos, visible}, ... }, refreshed by the scan
local lastScan = 0
local lastDebug = 0

local function debugPrint(message)
    if not CONFIG.debugEnabled then return end
    local now = utility.GetTickCount()
    if now - lastDebug >= 1000 then
        print("[tracers] " .. message)
        lastDebug = now
    end
end

-- ==== character resolution (taken straight from hitsounds.lua) ====

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

-- ==== position helpers ====

local function getPartPos(char, partName)
    if not char then return nil end
    local part = char:FindFirstChild(partName)
    if part and part.Position then
        return part.Position
    end
    return nil
end

-- Head of any player: bone API first (docs-verified), custom-rig fallback after.
local function getHeadPos(player)
    if not player then return nil end
    local ok, bone = pcall(function()
        return player:GetBonePosition("Head")
    end)
    if ok and bone then
        return bone
    end
    return getPartPos(getCharacter(player), "Head")
end

-- Visibility: raycast head -> target. If something is hit but it sits within
-- selfBlockEps studs of the target, assume it is the target's own body.
-- (Distance-based on purpose: hit.Instance ancestry checks are unreliable here.)
local function checkVisible(fromPos, toPos)
    local hit = raycast.Between(fromPos, toPos)
    if not hit then return true end
    local total = (toPos - fromPos).Magnitude
    return (total - hit.Distance) < CONFIG.selfBlockEps
end

local function scanTargets()
    local head = getHeadPos(p)
    if not head then
        targets = {}
        return
    end

    local list = {}
    local players = entity.GetPlayers()
    for _, plr in ipairs(players) do
        if plr ~= p then
            local char = getCharacter(plr)
            local endPos = getPartPos(char, CONFIG.targetPart)
            if endPos then
                local delta = endPos - head
                if delta.Magnitude <= CONFIG.maxDistance then
                    local vis = true
                    if CONFIG.useVisibility then
                        vis = checkVisible(head, endPos)
                    end
                    list[#list + 1] = {
                        name    = tostring(plr.Name),
                        pos     = endPos,
                        visible = vis,
                    }
                end
            end
        end
    end
    targets = list
end

-- ==== events ====

cheat.register("onUpdate", function()
    p = entity.GetLocalPlayer()
    if not p then return end

    local now = utility.GetTickCount()
    if now - lastScan < CONFIG.pollInterval then return end
    lastScan = now

    scanTargets()
end)

-- All draw.* calls live here. Endpoints are cached world positions from the
-- scan; projecting them every frame keeps tracers tracking the camera.
cheat.register("onPaint", function()
    if #targets == 0 then return end

    local head = getHeadPos(p)
    if not head then return end

    local sx0, sy0, on0 = utility.WorldToScreen(head)
    if not on0 then return end

    for _, t in ipairs(targets) do
        local sx, sy, on = utility.WorldToScreen(t.pos)
        if on then
            local col = t.visible and CONFIG.visibleColor or CONFIG.hiddenColor
            draw.Line(sx0, sy0, sx, sy, col, CONFIG.thickness)
            if CONFIG.showEndDot then
                draw.Circle(sx, sy, CONFIG.dotRadius, col, 1, 12, 1)
            end
        end
    end
end)

cheat.register("newPlace", function()
    targets = {} -- drop stale endpoints across teleports
end)

cheat.register("shutdown", function()
    targets = {}
end)

print(string.format(
    "[tracers] loaded; part=%s, maxDist=%s, visibility=%s",
    CONFIG.targetPart,
    CONFIG.maxDistance == math.huge and "off" or string.format("%.0f", CONFIG.maxDistance),
    tostring(CONFIG.useVisibility)
))
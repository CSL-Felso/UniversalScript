--[[
    ===================================================
    PET GATO CLIENT-SIDE (CORRIGIDO)
    ===================================================
--]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local localPlayer = Players.LocalPlayer
local CAT_ASSET_ID = "rbxassetid://18314616360"

---------------------------------------------------
-- 1. SISTEMA DE ARQUIVOS (JSON CONFIG)
---------------------------------------------------
local FOLDER_NAME = "Cat"
local FILE_NAME = "Cat/Cat.json"

local catConfig = {
    CatName = "Cat",
    WalkSpeed = 18,
    TeleportDistance = 100,
    ProximityDistance = 8,
    MeowIntervalMin = 10,
    MeowIntervalMax = 50
}

if writefile and readfile and makefolder and isfolder and isfile then
    if not isfolder(FOLDER_NAME) then
        makefolder(FOLDER_NAME)
    end

    if not isfile(FILE_NAME) then
        writefile(FILE_NAME, HttpService:JSONEncode(catConfig))
    else
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(FILE_NAME))
        end)
        if success and data then
            catConfig = data
        end
    end
end

---------------------------------------------------
-- 2. AUDIO E SONS
---------------------------------------------------
local SOUND_CLICK = "rbxassetid://89976106971280"
local IDLE_MEOWS = {
    "rbxassetid://83454004588488",
    "rbxassetid://134699420140804"
}

local function createSound(parent, soundId)
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 0.8
    sound.Parent = parent
    return sound
end

---------------------------------------------------
-- 3. CARREGAR MODELO DO GATO
---------------------------------------------------
local function loadCatFromAsset()
    local existingCat = workspace:FindFirstChild("CatPet")
    if existingCat then return existingCat end

    local catModel = nil

    local success, objects = pcall(function()
        return game:GetObjects(CAT_ASSET_ID)
    end)

    if success and objects and #objects > 0 then
        catModel = objects[1]
        
        if catModel:IsA("Model") and not catModel:FindFirstChildOfClass("Humanoid") then
            local innerModel = catModel:FindFirstChildOfClass("Model")
            if innerModel then
                catModel = innerModel
            end
        end
    end

    if not catModel then
        warn("Não foi possível carregar o Asset ID 18314616360.")
        return nil
    end

    catModel.Name = "CatPet"
    catModel.Parent = workspace
    return catModel
end

local catModel = loadCatFromAsset()
if not catModel then return end

local catHumanoid = catModel:WaitForChild("Humanoid", 5) or catModel:FindFirstChildOfClass("Humanoid")
local catRoot = catModel.PrimaryPart or catModel:FindFirstChild("HumanoidRootPart") or catModel:FindFirstChildWhichIsA("BasePart")

if not catHumanoid or not catRoot then
    warn("O modelo carregado não possui Humanoid ou RootPart configurada!")
    return
end

catHumanoid.WalkSpeed = catConfig.WalkSpeed

---------------------------------------------------
-- 4. GERENCIAMENTO DE COLISÃO (SEM CAIR NO CHÃO)
---------------------------------------------------
-- Registra grupos de colisão para o gato não trombar no jogador, mas continuar colidindo com o chão
pcall(function()
    PhysicsService:RegisterCollisionGroup("PetsGroup")
    PhysicsService:RegisterCollisionGroup("PlayersGroup")
    PhysicsService:CollisionGroupSetCollidable("PetsGroup", "PlayersGroup", false)
end)

local function setupCharacterCollision(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CollisionGroup = "PlayersGroup" end)
        end
    end
end

if localPlayer.Character then setupCharacterCollision(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(setupCharacterCollision)

for _, part in ipairs(catModel:GetDescendants()) do
    if part:IsA("BasePart") then
        pcall(function() part.CollisionGroup = "PetsGroup" end)
        part.Anchored = false
        -- Importante: A RootPart DEVE colidir com o mapa para o gato não cair no limbo
        if part == catRoot then
            part.CanCollide = true
        else
            part.CanCollide = false
        end
        part.CanTouch = false
    end
end

---------------------------------------------------
-- 5. TAG DE NOME (BILLBOARDGUI)
---------------------------------------------------
local headPart = catModel:FindFirstChild("Head") or catRoot

local billboard = Instance.new("BillboardGui")
billboard.Name = "CatNameTag"
billboard.Size = UDim2.new(0, 140, 0, 40)
billboard.StudsOffset = Vector3.new(0, 2.2, 0)
billboard.AlwaysOnTop = true
billboard.MaxDistance = 25
billboard.Parent = headPart

local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 1
frame.Parent = billboard

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 170, 0)
stroke.Thickness = 2
stroke.Transparency = 1
stroke.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "🐾 " .. catConfig.CatName .. " 🐾"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextTransparency = 1
label.Font = Enum.Font.FredokaOne
label.TextSize = 15
label.Parent = frame

local isVisible = false
local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function toggleNameTag(show)
    if isVisible == show then return end
    isVisible = show

    TweenService:Create(frame, tweenInfo, {BackgroundTransparency = show and 0.2 or 1}):Play()
    TweenService:Create(label, tweenInfo, {TextTransparency = show and 0 or 1}):Play()
    TweenService:Create(stroke, tweenInfo, {Transparency = show and 0 or 1}):Play()
end

---------------------------------------------------
-- 6. INTERAÇÃO AO CLICAR
---------------------------------------------------
local clickSound = createSound(catRoot, SOUND_CLICK)

local clickDetector = catModel:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 32
clickDetector.Parent = catModel

clickDetector.MouseClick:Connect(function(playerWhoClicked)
    if playerWhoClicked == localPlayer then
        clickSound:Play()
        catHumanoid.Jump = true
    end
end)

---------------------------------------------------
-- 7. MIAU ALEATÓRIO
---------------------------------------------------
task.spawn(function()
    while catModel and catModel.Parent do
        task.wait(math.random(catConfig.MeowIntervalMin, catConfig.MeowIntervalMax))
        local randomAudio = IDLE_MEOWS[math.random(1, #IDLE_MEOWS)]
        local meowSound = createSound(catRoot, randomAudio)
        meowSound:Play()
        game:GetService("Debris"):AddItem(meowSound, 5)
    end
end)

---------------------------------------------------
-- 8. INTELIGÊNCIA ARTIFICIAL E MOVIMENTAÇÃO
---------------------------------------------------
local function getCharacter()
    return localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") and localPlayer.Character
end

local isPathfinding = false

local function followPlayer(targetPosition)
    if isPathfinding then return end
    isPathfinding = true

    local path = PathfindingService:CreatePath({
        AgentRadius = 1.5,
        AgentHeight = 2,
        AgentCanJump = true
    })

    pcall(function()
        path:ComputeAsync(catRoot.Position, targetPosition)
    end)

    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i = 2, math.min(#waypoints, 4) do
            local wp = waypoints[i]
            if wp.Action == Enum.PathWaypointAction.Jump then
                catHumanoid.Jump = true
            end
            catHumanoid:MoveTo(wp.Position)
            task.wait(0.1)
        end
    else
        catHumanoid:MoveTo(targetPosition)
    end

    isPathfinding = false
end

-- Loop Principal de IA
task.spawn(function()
    while task.wait(0.2) do
        if not catModel or not catModel.Parent then break end
        
        local char = getCharacter()
        if not char then continue end

        local playerRoot = char.HumanoidRootPart
        local playerHum = char:FindFirstChildOfClass("Humanoid")
        local distance = (catRoot.Position - playerRoot.Position).Magnitude

        -- Tag visível quando o jogador estiver perto
        toggleNameTag(distance <= catConfig.ProximityDistance)

        -- Teleporte de emergência se o gato ficar muito longe (ou cair do mapa)
        if distance > catConfig.TeleportDistance or catRoot.Position.Y < -50 then
            catRoot.CFrame = playerRoot.CFrame * CFrame.new(2, 2, 2)
            catRoot.AssemblyLinearVelocity = Vector3.zero
            continue
        end

        local isPlayerMoving = playerHum and playerHum.MoveDirection.Magnitude > 0.1

        if isPlayerMoving then
            if distance > 6 then
                task.spawn(followPlayer, playerRoot.Position + Vector3.new(2, 0, 2))
            end
        else
            if math.random(1, 10) == 1 and not isPathfinding then
                local randomOffset = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
                catHumanoid:MoveTo(playerRoot.Position + randomOffset)
            end
        end
    end
end)

-- ============================================================================
-- SISTEMA INTEGRADO: PAINEL DE CONTROLE AÉREO, CADERNO E BINÓCULO
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ----------------------------------------------------------------------------
-- 1. CONFIGURAÇÕES E ESTADOS GERAIS
-- ----------------------------------------------------------------------------
local COOLDOWN_TIME = 15
local lastActivation = 0

local config = {
    mode = 1, -- 1: Jogadores, 2: ProximityPrompt, 3: Flares, 4: Humanoids (NPCs)
    maxProjectiles = 15,
    teamCheck = true,
    blacklistedTeams = {},
    promptTargetText = "",
}

-- Offsets do Walkie-Talkie
local moveOffset = Vector3.new(0.4, 0, 0)
local rotOffset = CFrame.Angles(math.rad(20), math.rad(50), math.rad(90))
local HAND_ROTATION_OFFSET = CFrame.Angles(math.rad(-90), math.rad(180), 0)
local CAMERA_FORWARD_OFFSET = Vector3.new(0, 0, -0.5)

-- Assets
local HAND_MODEL_ID = "rbxassetid://14591511233"
local AIRCRAFT_ID = "rbxassetid://16966989659"
local TOOL_ICON_ID = "rbxassetid://72905954702614"

-- Efeitos Sonoros
local AIRCRAFT_SOUND_ID = "rbxassetid://8907185231"
local ROCKET_LAUNCH_SOUND_ID = "rbxassetid://12222065"
local ROCKET_LOOP_SOUND_ID = "rbxassetid://136678911797673"
local ROCKET_EXPLOSION_SOUND_ID = "rbxassetid://71379251021209"
local BASS_EXPLOSION_ID = "rbxassetid://1721021464"
local RADIO_CHATTER_ID = "rbxassetid://8935401928"
local SIREN_SOUND_ID = "rbxassetid://1323864509"

-- Caderno (Delta / Executors)
local fileName = "caderno_anotacoes.txt"

-- Binóculo
local MIN_FOV = 10
local MAX_FOV = 70
local savedPercent = 0
local isBinoculoEquipped = false
local isToggleActive = false
local isDragging = false

-- ----------------------------------------------------------------------------
-- 2. REPOSITÓRIO DE MODELOS (WALKIE-TALKIE / AVIÃO)
-- ----------------------------------------------------------------------------
local loadedHandModel = nil
local loadedAircraft = nil

local function createFallbackRadio()
    local model = Instance.new("Model")
    model.Name = "WalkieTalkieFallback"
    
    local body = Instance.new("Part")
    body.Name = "RadioBody"
    body.Size = Vector3.new(0.4, 1.1, 0.25)
    body.Color = Color3.fromRGB(35, 35, 35)
    body.Material = Enum.Material.SmoothPlastic
    body.Parent = model

    local antenna = Instance.new("Part")
    antenna.Name = "Antenna"
    antenna.Size = Vector3.new(0.08, 0.7, 0.08)
    antenna.Color = Color3.fromRGB(15, 15, 15)
    antenna.Material = Enum.Material.SmoothPlastic
    antenna.Position = body.Position + Vector3.new(0.12, 0.85, 0)
    antenna.Parent = model

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = body weld.Part1 = antenna weld.Parent = body
    model.PrimaryPart = body
    return model
end

local function sanitizeModel(instance, disableAnchor)
    local targetModel = instance
    if instance:IsA("Tool") or instance:IsA("Accoutrement") then
        targetModel = Instance.new("Model")
        targetModel.Name = "WalkieTalkieMesh"
        for _, child in ipairs(instance:GetChildren()) do child.Parent = targetModel end
    end

    for _, desc in ipairs(targetModel:GetDescendants()) do
        if desc.Name == "Handle" then desc.Name = "RadioPartHandle" end
        if desc:IsA("BasePart") then
            desc.CanCollide = false desc.CanTouch = false desc.CanQuery = false desc.Massless = true
            if disableAnchor then desc.Anchored = false end
        elseif desc:IsA("JointInstance") or desc:IsA("WeldConstraint") or desc:IsA("Seat") or desc:IsA("VehicleSeat") then
            desc:Destroy()
        end
    end
    return targetModel
end

task.spawn(function()
    pcall(function()
        local handRes = game:GetObjects(HAND_MODEL_ID)
        if handRes and #handRes > 0 then loadedHandModel = sanitizeModel(handRes[1], true) end
    end)
    if not loadedHandModel then
        loadedHandModel = sanitizeModel(createFallbackRadio(), true)
    end

    pcall(function()
        local planeRes = game:GetObjects(AIRCRAFT_ID)
        if planeRes and #planeRes > 0 then loadedAircraft = sanitizeModel(planeRes[1], false) end
    end)
end)

-- ----------------------------------------------------------------------------
-- 3. SONS DE SUPORTE E CAMERA SHAKE
-- ----------------------------------------------------------------------------
local staticSound = Instance.new("Sound")
staticSound.SoundId = "rbxassetid://8028069841"
staticSound.Looped = true
staticSound.Volume = 0.15

local beepSound = Instance.new("Sound")
beepSound.SoundId = "rbxassetid://6066104082"
beepSound.Volume = 0.6

local eventSound = Instance.new("Sound")
eventSound.SoundId = "rbxassetid://106856187646399"
eventSound.Volume = 4.0 
eventSound.Parent = SoundService

local radioVoice = Instance.new("Sound")
radioVoice.SoundId = RADIO_CHATTER_ID
radioVoice.Volume = 2.0
radioVoice.Parent = SoundService

local function playCameraShake(intensity, duration)
    task.spawn(function()
        local startTime = tick()
        local cam = workspace.CurrentCamera
        while tick() - startTime < duration do
            local shakeX = (math.random() - 0.5) * intensity
            local shakeY = (math.random() - 0.5) * intensity
            local shakeZ = (math.random() - 0.5) * intensity
            cam.CFrame = cam.CFrame * CFrame.Angles(shakeX, shakeY, shakeZ)
            RunService.RenderStepped:Wait()
        end
    end)
end

-- ----------------------------------------------------------------------------
-- 4. GUI: PAINEL DE CONTROLE AÉREO
-- ----------------------------------------------------------------------------
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local airstrikeGui = playerGui:FindFirstChild("AirstrikeGUI")

if not airstrikeGui then
    airstrikeGui = Instance.new("ScreenGui")
    airstrikeGui.Name = "AirstrikeGUI"
    airstrikeGui.ResetOnSpawn = false
    airstrikeGui.Parent = playerGui
end

local airstrikeFrame = airstrikeGui:FindFirstChild("MainFrame")
if not airstrikeFrame then
    airstrikeFrame = Instance.new("Frame")
    airstrikeFrame.Name = "MainFrame"
    airstrikeFrame.Size = UDim2.new(0, 310, 0, 360)
    airstrikeFrame.Position = UDim2.new(-0.4, 0, 0.25, 0)
    airstrikeFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    airstrikeFrame.BorderSizePixel = 0
    airstrikeFrame.Parent = airstrikeGui

    Instance.new("UICorner", airstrikeFrame).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Name = "TitleLabel"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "PAINEL DE CONTROLE AÉREO"
    title.TextColor3 = Color3.fromRGB(255, 200, 50)
    title.TextSize = 15
    title.Font = Enum.Font.GothamBold
    title.Parent = airstrikeFrame

    local projFrame = Instance.new("Frame")
    projFrame.Size = UDim2.new(0.9, 0, 0, 35)
    projFrame.Position = UDim2.new(0.05, 0, 0.12, 0)
    projFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    projFrame.Parent = airstrikeFrame
    Instance.new("UICorner", projFrame).CornerRadius = UDim.new(0, 6)

    local projLabel = Instance.new("TextLabel")
    projLabel.Size = UDim2.new(0.65, 0, 1, 0)
    projLabel.Position = UDim2.new(0.05, 0, 0, 0)
    projLabel.BackgroundTransparency = 1
    projLabel.Text = "Projéteis Máximos:"
    projLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    projLabel.TextXAlignment = Enum.TextXAlignment.Left
    projLabel.Font = Enum.Font.Gotham
    projLabel.TextSize = 13
    projLabel.Parent = projFrame

    local projBox = Instance.new("TextBox")
    projBox.Size = UDim2.new(0.25, 0, 0.7, 0)
    projBox.Position = UDim2.new(0.7, 0, 0.15, 0)
    projBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    projBox.Text = tostring(config.maxProjectiles)
    projBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    projBox.Font = Enum.Font.GothamBold
    projBox.Parent = projFrame
    Instance.new("UICorner", projBox).CornerRadius = UDim.new(0, 4)

    projBox.FocusLost:Connect(function()
        local val = tonumber(projBox.Text)
        if val and val > 0 then config.maxProjectiles = math.clamp(math.floor(val), 1, 15) end
        projBox.Text = tostring(config.maxProjectiles)
    end)

    local modeFrame = Instance.new("Frame")
    modeFrame.Size = UDim2.new(0.9, 0, 0, 35)
    modeFrame.Position = UDim2.new(0.05, 0, 0.24, 0)
    modeFrame.BackgroundTransparency = 1
    modeFrame.Parent = airstrikeFrame

    local btnM1 = Instance.new("TextButton")
    btnM1.Size = UDim2.new(0.23, 0, 1, 0)
    btnM1.Position = UDim2.new(0, 0, 0, 0)
    btnM1.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    btnM1.Text = "Players"
    btnM1.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnM1.Font = Enum.Font.GothamBold
    btnM1.TextSize = 10
    btnM1.Parent = modeFrame
    Instance.new("UICorner", btnM1).CornerRadius = UDim.new(0, 6)

    local btnM2 = Instance.new("TextButton")
    btnM2.Size = UDim2.new(0.23, 0, 1, 0)
    btnM2.Position = UDim2.new(0.256, 0, 0, 0)
    btnM2.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btnM2.Text = "Prompts"
    btnM2.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnM2.Font = Enum.Font.GothamBold
    btnM2.TextSize = 10
    btnM2.Parent = modeFrame
    Instance.new("UICorner", btnM2).CornerRadius = UDim.new(0, 6)

    local btnM3 = Instance.new("TextButton")
    btnM3.Size = UDim2.new(0.23, 0, 1, 0)
    btnM3.Position = UDim2.new(0.512, 0, 0, 0)
    btnM3.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btnM3.Text = "Flares"
    btnM3.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnM3.Font = Enum.Font.GothamBold
    btnM3.TextSize = 10
    btnM3.Parent = modeFrame
    Instance.new("UICorner", btnM3).CornerRadius = UDim.new(0, 6)

    local btnM4 = Instance.new("TextButton")
    btnM4.Size = UDim2.new(0.23, 0, 1, 0)
    btnM4.Position = UDim2.new(0.768, 0, 0, 0)
    btnM4.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btnM4.Text = "Humanoids"
    btnM4.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnM4.Font = Enum.Font.GothamBold
    btnM4.TextSize = 9
    btnM4.Parent = modeFrame
    Instance.new("UICorner", btnM4).CornerRadius = UDim.new(0, 6)

    local containerM1 = Instance.new("Frame")
    containerM1.Size = UDim2.new(0.9, 0, 0.6, 0)
    containerM1.Position = UDim2.new(0.05, 0, 0.36, 0)
    containerM1.BackgroundTransparency = 1
    containerM1.Parent = airstrikeFrame

    local teamCheckBtn = Instance.new("TextButton")
    teamCheckBtn.Size = UDim2.new(1, 0, 0, 35)
    teamCheckBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
    teamCheckBtn.Text = "Team Check: ATIVADO"
    teamCheckBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    teamCheckBtn.Font = Enum.Font.GothamBold
    teamCheckBtn.TextSize = 12
    teamCheckBtn.Parent = containerM1
    Instance.new("UICorner", teamCheckBtn).CornerRadius = UDim.new(0, 6)

    teamCheckBtn.MouseButton1Click:Connect(function()
        config.teamCheck = not config.teamCheck
        teamCheckBtn.Text = config.teamCheck and "Team Check: ATIVADO" or "Team Check: DESATIVADO"
        teamCheckBtn.BackgroundColor3 = config.teamCheck and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(150, 40, 40)
    end)

    local blackListLabel = Instance.new("TextLabel")
    blackListLabel.Size = UDim2.new(1, 0, 0, 20)
    blackListLabel.Position = UDim2.new(0, 0, 0.28, 0)
    blackListLabel.BackgroundTransparency = 1
    blackListLabel.Text = "Blacklist de Times (sep. por vírgula):"
    blackListLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    blackListLabel.TextXAlignment = Enum.TextXAlignment.Left
    blackListLabel.Font = Enum.Font.Gotham
    blackListLabel.TextSize = 11
    blackListLabel.Parent = containerM1

    local blackListBox = Instance.new("TextBox")
    blackListBox.Size = UDim2.new(1, 0, 0, 40)
    blackListBox.Position = UDim2.new(0, 0, 0.4, 0)
    blackListBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    blackListBox.PlaceholderText = "Ex: Red, Blue, Inimigos"
    blackListBox.Text = ""
    blackListBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    blackListBox.Font = Enum.Font.Gotham
    blackListBox.TextSize = 12
    blackListBox.Parent = containerM1
    Instance.new("UICorner", blackListBox).CornerRadius = UDim.new(0, 6)

    blackListBox.FocusLost:Connect(function()
        config.blacklistedTeams = {}
        for teamName in string.gmatch(blackListBox.Text, "[^,%s]+") do
            config.blacklistedTeams[string.lower(teamName)] = true
        end
    end)

    local containerM2 = Instance.new("Frame")
    containerM2.Size = UDim2.new(0.9, 0, 0.6, 0)
    containerM2.Position = UDim2.new(0.05, 0, 0.36, 0)
    containerM2.BackgroundTransparency = 1
    containerM2.Visible = false
    containerM2.Parent = airstrikeFrame

    local promptLabel = Instance.new("TextLabel")
    promptLabel.Size = UDim2.new(1, 0, 0, 20)
    promptLabel.BackgroundTransparency = 1
    promptLabel.Text = "Texto/Nome do ProximityPrompt:"
    promptLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    promptLabel.TextXAlignment = Enum.TextXAlignment.Left
    promptLabel.Font = Enum.Font.Gotham
    promptLabel.TextSize = 11
    promptLabel.Parent = containerM2

    local promptBox = Instance.new("TextBox")
    promptBox.Size = UDim2.new(1, 0, 0, 40)
    promptBox.Position = UDim2.new(0, 0, 0.15, 0)
    promptBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    promptBox.PlaceholderText = "Ex: Abrir, Coletar, Gerador..."
    promptBox.Text = ""
    promptBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    promptBox.Font = Enum.Font.Gotham
    promptBox.TextSize = 12
    promptBox.Parent = containerM2
    Instance.new("UICorner", promptBox).CornerRadius = UDim.new(0, 6)

    promptBox.FocusLost:Connect(function()
        config.promptTargetText = string.lower(promptBox.Text)
    end)

    local containerM3 = Instance.new("Frame")
    containerM3.Size = UDim2.new(0.9, 0, 0.6, 0)
    containerM3.Position = UDim2.new(0.05, 0, 0.36, 0)
    containerM3.BackgroundTransparency = 1
    containerM3.Visible = false
    containerM3.Parent = airstrikeFrame

    local infoM3 = Instance.new("TextLabel")
    infoM3.Size = UDim2.new(1, 0, 1, 0)
    infoM3.BackgroundTransparency = 1
    infoM3.Text = "💡 Modo Iluminação Tática:\n\nO avião disparará flares iluminadores ao redor do jogador."
    infoM3.TextColor3 = Color3.fromRGB(200, 220, 255)
    infoM3.Font = Enum.Font.Gotham
    infoM3.TextSize = 12
    infoM3.TextWrapped = true
    infoM3.Parent = containerM3

    local containerM4 = Instance.new("Frame")
    containerM4.Size = UDim2.new(0.9, 0, 0.6, 0)
    containerM4.Position = UDim2.new(0.05, 0, 0.36, 0)
    containerM4.BackgroundTransparency = 1
    containerM4.Visible = false
    containerM4.Parent = airstrikeFrame

    local infoM4 = Instance.new("TextLabel")
    infoM4.Size = UDim2.new(1, 0, 1, 0)
    infoM4.BackgroundTransparency = 1
    infoM4.Text = "💡 Modo Humanoids (NPCs):\n\nO avião rastreará e atacará todos os Humanoids no mapa que NÃO sejam jogadores reais."
    infoM4.TextColor3 = Color3.fromRGB(255, 220, 200)
    infoM4.Font = Enum.Font.Gotham
    infoM4.TextSize = 12
    infoM4.TextWrapped = true
    infoM4.Parent = containerM4

    local function selectMode(m)
        config.mode = m
        btnM1.BackgroundColor3 = (m == 1) and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(50, 50, 60)
        btnM2.BackgroundColor3 = (m == 2) and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(50, 50, 60)
        btnM3.BackgroundColor3 = (m == 3) and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(50, 50, 60)
        btnM4.BackgroundColor3 = (m == 4) and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(50, 50, 60)

        containerM1.Visible = (m == 1)
        containerM2.Visible = (m == 2)
        containerM3.Visible = (m == 3)
        containerM4.Visible = (m == 4)
    end

    btnM1.MouseButton1Click:Connect(function() selectMode(1) end)
    btnM2.MouseButton1Click:Connect(function() selectMode(2) end)
    btnM3.MouseButton1Click:Connect(function() selectMode(3) end)
    btnM4.MouseButton1Click:Connect(function() selectMode(4) end)
end

local function toggleAirstrikeUI(show)
    local targetPos = show and UDim2.new(0.02, 0, 0.25, 0) or UDim2.new(-0.4, 0, 0.25, 0)
    TweenService:Create(airstrikeFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = targetPos
    }):Play()
end

-- ----------------------------------------------------------------------------
-- 5. LÓGICA DO ATAQUE AÉREO
-- ----------------------------------------------------------------------------
local function getTargetPositions(hrpPosition)
    local targets = {}
    
    if config.mode == 1 then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local passTeamCheck = true
                if config.teamCheck and LocalPlayer.Team and p.Team and LocalPlayer.Team == p.Team then
                    passTeamCheck = false
                end
                if p.Team and config.blacklistedTeams[string.lower(p.Team.Name)] then
                    passTeamCheck = false
                end
                if passTeamCheck then table.insert(targets, p.Character.HumanoidRootPart.Position) end
            end
        end
    elseif config.mode == 2 then
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                local promptName = string.lower(desc.Name)
                local objectText = string.lower(desc.ObjectText)
                local actionText = string.lower(desc.ActionText)
                local filter = config.promptTargetText

                if filter == "" or string.find(promptName, filter) or string.find(objectText, filter) or string.find(actionText, filter) then
                    local part = desc.Parent
                    if part:IsA("BasePart") then
                        table.insert(targets, part.Position)
                    elseif part:IsA("Model") and part.PrimaryPart then
                        table.insert(targets, part.PrimaryPart.Position)
                    end
                end
            end
        end
    elseif config.mode == 3 then
        local count = config.maxProjectiles
        local radius = 60
        for i = 1, count do
            local angle = ((i - 1) / count) * (math.pi * 2)
            local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            table.insert(targets, hrpPosition + offset)
        end
    elseif config.mode == 4 then
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("Humanoid") and desc.Health > 0 then
                local charModel = desc.Parent
                if charModel and charModel:IsA("Model") then
                    local isPlayer = Players:GetPlayerFromCharacter(charModel)
                    if not isPlayer then
                        local rootPart = charModel:FindFirstChild("HumanoidRootPart") 
                            or charModel.PrimaryPart 
                            or charModel:FindFirstChild("Torso") 
                            or charModel:FindFirstChild("UpperTorso")
                        if rootPart then table.insert(targets, rootPart.Position) end
                    end
                end
            end
        end
    end
    return targets
end

local function createImpactMarker(hitPosition, isFlare)
    local xPart = Instance.new("Part")
    xPart.Name = "ImpactMarkerX"
    xPart.Size = Vector3.new(1, 1, 1)
    xPart.Position = hitPosition
    xPart.Anchored = true
    xPart.CanCollide = false
    xPart.Transparency = 1
    xPart.Parent = workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MarkerGui"
    billboard.Size = UDim2.new(0, 40, 0, 40)
    billboard.AlwaysOnTop = true
    billboard.Adornee = xPart
    billboard.Parent = xPart

    local xLabel = Instance.new("TextLabel")
    xLabel.Name = "XText"
    xLabel.Size = UDim2.new(1, 0, 1, 0)
    xLabel.BackgroundTransparency = 1
    xLabel.Text = "X"
    xLabel.TextColor3 = isFlare and Color3.fromRGB(255, 220, 50) or Color3.fromRGB(255, 40, 40)
    xLabel.TextSize = 28
    xLabel.Font = Enum.Font.GothamBold
    xLabel.Parent = billboard

    TweenService:Create(xLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        TextTransparency = 0.4
    }):Play()

    task.delay(8, function()
        if xPart then xPart:Destroy() end
    end)
end

local function spawnAirstrike()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local forward = hrp.CFrame.LookVector
    local startPos = hrp.Position + Vector3.new(0, 100, 0) - (forward * 200)
    local endPos = startPos + (forward * 500)
    
    local availableTargets = getTargetPositions(hrp.Position)
    local isFlare = (config.mode == 3)

    if not isFlare then
        for _, targetPos in ipairs(availableTargets) do
            local smokePart = Instance.new("Part")
            smokePart.Size = Vector3.new(1,1,1)
            smokePart.Position = targetPos
            smokePart.Anchored = true
            smokePart.CanCollide = false
            smokePart.Transparency = 1
            smokePart.Parent = workspace
            
            local smoke = Instance.new("Smoke", smokePart)
            smoke.Color = Color3.fromRGB(255, 30, 30)
            smoke.Size = 5
            smoke.Opacity = 0.5
            
            task.delay(6, function()
                smoke.Enabled = false
                task.wait(2)
                smokePart:Destroy()
            end)
        end
    end

    local plane = nil
    if loadedAircraft then
        plane = loadedAircraft:Clone()
    else
        plane = Instance.new("Part")
        plane.Size = Vector3.new(10, 3, 14)
        plane.Color = Color3.fromRGB(35, 35, 35)
        plane.Material = Enum.Material.SmoothPlastic
    end

    for _, p in ipairs(plane:GetDescendants()) do
        if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false end
    end
    if plane:IsA("BasePart") then plane.Anchored = true plane.CanCollide = false end

    local planeSound = Instance.new("Sound")
    planeSound.SoundId = AIRCRAFT_SOUND_ID
    planeSound.Looped = true
    planeSound.Volume = 1.0
    planeSound.RollOffMaxDistance = 1500
    planeSound.RollOffMinDistance = 50
    planeSound.Parent = plane:IsA("Model") and (plane.PrimaryPart or plane:FindFirstChildWhichIsA("BasePart")) or plane
    planeSound:Play()
    
    local sirenSound = Instance.new("Sound")
    sirenSound.SoundId = SIREN_SOUND_ID
    sirenSound.Volume = 0.8
    sirenSound.Parent = planeSound.Parent
    sirenSound:Play()

    plane.Parent = workspace

    local flightTime = 6
    task.spawn(function()
        local startTime = tick()
        while tick() - startTime < flightTime do
            local alpha = (tick() - startTime) / flightTime
            local currentPos = startPos:Lerp(endPos, alpha)
            
            local bankAngle = math.sin(alpha * math.pi) * math.rad(20) 
            local pitchAngle = 0
            
            if alpha < 0.3 then
                pitchAngle = math.rad(-15) * (1 - (alpha / 0.3))
            elseif alpha > 0.7 then
                pitchAngle = math.rad(20) * ((alpha - 0.7) / 0.3)
            end
            
            local turbulence = math.sin(tick() * 15) * math.rad(2)
            local currentCF = CFrame.lookAt(currentPos, currentPos + forward) * CFrame.Angles(pitchAngle, turbulence, bankAngle)
            
            if plane:IsA("Model") then plane:PivotTo(currentCF) else plane.CFrame = currentCF end
            task.wait()
        end
        plane:Destroy()
    end)

    task.spawn(function()
        local totalProjectiles = config.maxProjectiles

        for i = 1, totalProjectiles do
            task.wait(0.4)
            local planeCurrentPos = startPos + (forward * (i * (250 / totalProjectiles)))
            local bulletColor = isFlare and Color3.fromRGB(255, 230, 150) or Color3.fromRGB(255, 30, 30)

            local bullet = Instance.new("Part")
            bullet.Name = isFlare and "FlareProjectile" or "RedAirstrikeBullet"
            bullet.Size = Vector3.new(1.2, 3.5, 1.2)
            bullet.Shape = Enum.PartType.Cylinder
            bullet.Color = bulletColor
            bullet.Material = Enum.Material.Neon
            bullet.Anchored = true
            bullet.CanCollide = false
            bullet.CFrame = CFrame.new(planeCurrentPos) * CFrame.Angles(math.rad(90), 0, 0)
            bullet.Parent = workspace

            local light = Instance.new("PointLight")
            light.Color = bulletColor
            light.Range = isFlare and 35 or 15
            light.Brightness = isFlare and 8 or 5
            light.Parent = bullet

            local launchSound = Instance.new("Sound")
            launchSound.SoundId = ROCKET_LAUNCH_SOUND_ID
            launchSound.Volume = 1
            launchSound.Parent = bullet
            launchSound:Play()

            local loopSound = Instance.new("Sound")
            loopSound.SoundId = ROCKET_LOOP_SOUND_ID
            loopSound.Looped = true
            loopSound.Volume = 0.8
            loopSound.Parent = bullet
            loopSound:Play()

            local hitPosition = nil
            if #availableTargets > 0 then
                hitPosition = availableTargets[((i - 1) % #availableTargets) + 1]
            else
                local defaultTargetOrigin = hrp.Position + (forward * (i * 35)) + Vector3.new(0, 50, 0)
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                rayParams.FilterDescendantsInstances = {char, plane, bullet}
                local rayResult = workspace:Raycast(defaultTargetOrigin, Vector3.new(0, -300, 0), rayParams)
                hitPosition = rayResult and rayResult.Position or (defaultTargetOrigin - Vector3.new(0, 50, 0))
            end

            local fallDistance = (planeCurrentPos - hitPosition).Magnitude
            local fallDuration = math.clamp(fallDistance / 140, 0.5, 3)

            local dropTween = TweenService:Create(bullet, TweenInfo.new(fallDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                CFrame = CFrame.lookAt(hitPosition, hitPosition - Vector3.new(0, 1, 0))
            })
            dropTween:Play()

            dropTween.Completed:Connect(function()
                bullet:Destroy()
                createImpactMarker(hitPosition, isFlare)

                if not isFlare then
                    local explosionSound = Instance.new("Sound")
                    explosionSound.SoundId = ROCKET_EXPLOSION_SOUND_ID
                    explosionSound.Volume = 2
                    
                    local bassSound = Instance.new("Sound")
                    bassSound.SoundId = BASS_EXPLOSION_ID
                    bassSound.Volume = 2
                    
                    local soundPart = Instance.new("Part")
                    soundPart.Size = Vector3.new(1,1,1)
                    soundPart.Position = hitPosition
                    soundPart.Anchored = true
                    soundPart.Transparency = 1
                    soundPart.CanCollide = false
                    soundPart.Parent = workspace
                    
                    explosionSound.Parent = soundPart
                    bassSound.Parent = soundPart
                    explosionSound:Play()
                    bassSound:Play()
                    
                    local shockwave = Instance.new("Part")
                    shockwave.Shape = Enum.PartType.Ball
                    shockwave.Material = Enum.Material.Neon
                    shockwave.Color = Color3.fromRGB(255, 100, 50)
                    shockwave.Anchored = true
                    shockwave.CanCollide = false
                    shockwave.Position = hitPosition
                    shockwave.Size = Vector3.new(2, 2, 2)
                    shockwave.Transparency = 0.2
                    shockwave.Parent = workspace
                    
                    TweenService:Create(shockwave, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Size = Vector3.new(40, 40, 40),
                        Transparency = 1
                    }):Play()

                    local dist = (hrp.Position - hitPosition).Magnitude
                    if dist < 150 then
                        local intensity = math.clamp(1 - (dist / 150), 0.1, 1) * 0.15
                        playCameraShake(intensity, 0.5)
                    end
                    
                    task.delay(3, function() 
                        if soundPart then soundPart:Destroy() end 
                        if shockwave then shockwave:Destroy() end
                    end)
                else
                    local flareLand = Instance.new("Part")
                    flareLand.Size = Vector3.new(1, 0.4, 1)
                    flareLand.Position = hitPosition + Vector3.new(0, 0.2, 0)
                    flareLand.Anchored = true
                    flareLand.CanCollide = false
                    flareLand.Color = Color3.fromRGB(255, 200, 100)
                    flareLand.Material = Enum.Material.Neon
                    flareLand.Parent = workspace

                    local flareLight = Instance.new("PointLight")
                    flareLight.Color = Color3.fromRGB(255, 220, 150)
                    flareLight.Range = 80
                    flareLight.Brightness = 10
                    flareLight.Shadows = true
                    flareLight.Parent = flareLand

                    task.delay(25, function()
                        if flareLand then
                            TweenService:Create(flareLight, TweenInfo.new(2), {Brightness = 0}):Play()
                            task.wait(2)
                            flareLand:Destroy()
                        end
                    end)
                end
            end)
        end
    end)
end

-- ----------------------------------------------------------------------------
-- 6. CRIAÇÃO DA TOOL WALKIE-TALKIE
-- ----------------------------------------------------------------------------
local originalC0 = nil
local renderConnection, steppedConnection = nil, nil
local isWalkieEquipped = false
local currentEquippedModel = nil

local function getShoulder(character)
    if not character then return nil end
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    return torso and (torso:FindFirstChild("Right Shoulder") or torso:FindFirstChild("RightShoulder"))
end

local function getArmPart(character)
    if not character then return nil end
    return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm")
end

local function setupWalkieTalkieTool()
    local backpack = LocalPlayer:WaitForChild("Backpack", 5)
    if not backpack then return end

    if backpack:FindFirstChild("walkie-talkie") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("walkie-talkie")) then
        return
    end

    local tool = Instance.new("Tool")
    tool.Name = "walkie-talkie"
    tool.TextureId = TOOL_ICON_ID
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    
    staticSound.Parent = tool
    beepSound.Parent = tool

    tool.Equipped:Connect(function()
        isWalkieEquipped = true
        local character = LocalPlayer.Character
        if not character then return end

        toggleAirstrikeUI(true)
        beepSound:Play()
        staticSound:Play()
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.CameraOffset = CAMERA_FORWARD_OFFSET end

        local shoulder = getShoulder(character)
        local armPart = getArmPart(character)

        if shoulder then
            if not originalC0 then originalC0 = shoulder.C0 end
            shoulder.C0 = originalC0 * CFrame.new(moveOffset) * rotOffset
        end

        if currentEquippedModel then currentEquippedModel:Destroy() currentEquippedModel = nil end

        local modelToClone = loadedHandModel or sanitizeModel(createFallbackRadio(), true)
        if modelToClone and armPart then
            currentEquippedModel = modelToClone:Clone()
            currentEquippedModel.Parent = character
            
            local mainPart = currentEquippedModel:IsA("BasePart") and currentEquippedModel or currentEquippedModel.PrimaryPart or currentEquippedModel:FindFirstChildWhichIsA("BasePart")

            if mainPart then
                local posOffset = (armPart.Name == "RightHand") and Vector3.new(0, -0.2, -0.3) or Vector3.new(0, -0.6, -0.4)
                mainPart.CFrame = armPart.CFrame * CFrame.new(posOffset) * HAND_ROTATION_OFFSET
                
                for _, p in ipairs(currentEquippedModel:GetDescendants()) do
                    if p:IsA("BasePart") and p ~= mainPart then
                        local w = Instance.new("WeldConstraint")
                        w.Part0 = mainPart w.Part1 = p w.Parent = p
                    end
                end
                local armWeld = Instance.new("WeldConstraint")
                armWeld.Part0 = armPart armWeld.Part1 = mainPart armWeld.Parent = mainPart
            end
        end

        steppedConnection = RunService.Stepped:Connect(function()
            if not isWalkieEquipped or not LocalPlayer.Character then return end
            local char = LocalPlayer.Character
            local sh = getShoulder(char)
            if sh then sh.Transform = CFrame.new() end

            local upperArm = char:FindFirstChild("RightUpperArm")
            if upperArm and upperArm:FindFirstChild("RightElbow") then upperArm.RightElbow.Transform = CFrame.new() end
            local lowerArm = char:FindFirstChild("RightLowerArm")
            if lowerArm and lowerArm:FindFirstChild("RightWrist") then lowerArm.RightWrist.Transform = CFrame.new() end
        end)

        renderConnection = RunService.RenderStepped:Connect(function()
            if not isWalkieEquipped or not LocalPlayer.Character then return end
            local char = LocalPlayer.Character
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                    obj.LocalTransparencyModifier = (obj.Name == "Head") and 1 or 0
                end
            end
            local sh = getShoulder(char)
            if sh and originalC0 then sh.C0 = originalC0 * CFrame.new(moveOffset) * rotOffset end
        end)
    end)

    tool.Activated:Connect(function()
        local now = tick()
        local titleLabel = airstrikeFrame:FindFirstChild("TitleLabel")

        if now - lastActivation < COOLDOWN_TIME then
            local remaining = math.ceil(COOLDOWN_TIME - (now - lastActivation))
            if titleLabel then
                titleLabel.Text = "RECARREGANDO (" .. remaining .. "s)"
                titleLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                task.delay(1.5, function()
                    if titleLabel then
                        titleLabel.Text = "PAINEL DE CONTROLE AÉREO"
                        titleLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
                    end
                end)
            end
            return
        end
        
        lastActivation = now
        beepSound:Play()
        eventSound:Stop()
        eventSound:Play()
        radioVoice:Play()
        
        spawnAirstrike()
    end)

    tool.Unequipped:Connect(function()
        isWalkieEquipped = false
        toggleAirstrikeUI(false)
        staticSound:Stop()

        if currentEquippedModel then currentEquippedModel:Destroy() currentEquippedModel = nil end
        LocalPlayer.CameraMode = Enum.CameraMode.Classic

        if renderConnection then renderConnection:Disconnect() renderConnection = nil end
        if steppedConnection then steppedConnection:Disconnect() steppedConnection = nil end

        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid.CameraOffset = Vector3.new(0, 0, 0) end

            local sh = getShoulder(character)
            if sh and originalC0 then
                sh.C0 = originalC0
                sh.Transform = CFrame.new()
            end

            for _, obj in ipairs(character:GetChildren()) do
                if obj:IsA("BasePart") then obj.LocalTransparencyModifier = 0 end
            end
        end
    end)

    tool.Parent = backpack
end

-- ----------------------------------------------------------------------------
-- 7. SISTEMA DO CADERNO
-- ----------------------------------------------------------------------------
local function carregarTexto()
    if isfile and isfile(fileName) then return readfile(fileName) end
    return ""
end

local function salvarTexto(conteudo)
    if writefile then writefile(fileName, conteudo) end
end

local cadernoGui = playerGui:FindFirstChild("CadernoGui")
if not cadernoGui then
    cadernoGui = Instance.new("ScreenGui")
    cadernoGui.Name = "CadernoGui"
    cadernoGui.ResetOnSpawn = false
    cadernoGui.Parent = playerGui
end

local cadernoFrame = cadernoGui:FindFirstChild("CadernoFrame")
if not cadernoFrame then
    cadernoFrame = Instance.new("Frame")
    cadernoFrame.Name = "CadernoFrame"
    cadernoFrame.Size = UDim2.new(0, 260, 0, 320)
    cadernoFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    cadernoFrame.Position = UDim2.new(0.5, 0, -1.5, 0)
    cadernoFrame.BackgroundColor3 = Color3.fromRGB(245, 238, 220)
    cadernoFrame.BorderSizePixel = 0
    cadernoFrame.Visible = false
    cadernoFrame.Parent = cadernoGui

    Instance.new("UICorner", cadernoFrame).CornerRadius = UDim.new(0, 10)

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = Color3.fromRGB(90, 60, 40)
    uiStroke.Thickness = 3
    uiStroke.Parent = cadernoFrame

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundColor3 = Color3.fromRGB(110, 75, 50)
    header.BorderSizePixel = 0
    header.Parent = cadernoFrame

    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "📓 MEU CADERNO"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.SourceSansBold
    title.Parent = header

    local textBox = Instance.new("TextBox")
    textBox.Name = "TextoCaderno"
    textBox.Size = UDim2.new(0.9, 0, 0.8, 0)
    textBox.Position = UDim2.new(0.05, 0, 0.15, 0)
    textBox.BackgroundTransparency = 1
    textBox.TextColor3 = Color3.fromRGB(40, 40, 40)
    textBox.TextSize = 14
    textBox.Font = Enum.Font.SourceSans
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Top
    textBox.ClearTextOnFocus = false
    textBox.MultiLine = true
    textBox.TextWrapped = true
    textBox.Text = carregarTexto()
    textBox.Parent = cadernoFrame

    textBox:GetPropertyChangedSignal("Text"):Connect(function()
        salvarTexto(textBox.Text)
    end)
end

local posFora = UDim2.new(0.5, 0, -1.5, 0)
local posCentro = UDim2.new(0.5, 0, 0.5, 0)
local tweenInfoEntrada = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenInfoSaida = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local function abrirCaderno()
    cadernoFrame.Visible = true
    TweenService:Create(cadernoFrame, tweenInfoEntrada, {Position = posCentro}):Play()
end

local function fecharCaderno()
    local tweenFechar = TweenService:Create(cadernoFrame, tweenInfoSaida, {Position = posFora})
    tweenFechar:Play()
    tweenFechar.Completed:Connect(function()
        if cadernoFrame.Position == posFora then cadernoFrame.Visible = false end
    end)
end

local function setupCadernoTool()
    local backpack = LocalPlayer:WaitForChild("Backpack", 5)
    if not backpack then return end

    if backpack:FindFirstChild("Caderno") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Caderno")) then
        return
    end

    local tool = Instance.new("Tool")
    tool.Name = "Caderno"
    tool.RequiresHandle = false
    tool.CanBeDropped = false

    tool.Equipped:Connect(function() abrirCaderno() end)
    tool.Unequipped:Connect(function() fecharCaderno() end)
    tool.Parent = backpack
end

-- ----------------------------------------------------------------------------
-- 8. SISTEMA DO BINÓCULO
-- ----------------------------------------------------------------------------
local binoculoGui = playerGui:FindFirstChild("BinoculoUI")
local sliderFrame, sliderHandle, toggleButton

if not binoculoGui then
    binoculoGui = Instance.new("ScreenGui")
    binoculoGui.Name = "BinoculoUI"
    binoculoGui.ResetOnSpawn = false
    binoculoGui.Enabled = false

    sliderFrame = Instance.new("TextButton")
    sliderFrame.Name = "SliderTrack"
    sliderFrame.Text = ""
    sliderFrame.AutoButtonColor = false
    sliderFrame.Active = true
    sliderFrame.Size = UDim2.new(0, 26, 0.42, 0)
    sliderFrame.Position = UDim2.new(0.92, 0, 0.25, 0)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    sliderFrame.BackgroundTransparency = 0.3
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = binoculoGui
    Instance.new("UICorner", sliderFrame).CornerRadius = UDim.new(0, 12)

    sliderHandle = Instance.new("Frame")
    sliderHandle.Name = "SliderHandle"
    sliderHandle.Size = UDim2.new(0.85, 0, 0.22, 0)
    sliderHandle.AnchorPoint = Vector2.new(0.5, 0.5)
    sliderHandle.Position = UDim2.new(0.5, 0, 0.89, 0)
    sliderHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderHandle.BorderSizePixel = 0
    sliderHandle.Active = false
    sliderHandle.Parent = sliderFrame
    Instance.new("UICorner", sliderHandle).CornerRadius = UDim.new(0, 8)

    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleFixButton"
    toggleButton.Size = UDim2.new(0, 70, 0, 32)
    toggleButton.Position = UDim2.new(0.92, -22, 0.69, 0)
    toggleButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    toggleButton.Text = "FIXAR: OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 11
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.Active = true
    toggleButton.Parent = binoculoGui
    Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8)

    binoculoGui.Parent = playerGui
else
    sliderFrame = binoculoGui:FindFirstChild("SliderTrack")
    if sliderFrame then sliderHandle = sliderFrame:FindFirstChild("SliderHandle") end
    toggleButton = binoculoGui:FindFirstChild("ToggleFixButton")
end

local function applyZoom(percent)
    savedPercent = math.clamp(percent, 0, 1)
    if sliderHandle then
        local handleY = math.clamp(1 - savedPercent, 0.11, 0.89)
        sliderHandle.Position = UDim2.new(0.5, 0, handleY, 0)
    end
    local targetFOV = MAX_FOV - (savedPercent * (MAX_FOV - MIN_FOV))
    TweenService:Create(camera, TweenInfo.new(0.05), {FieldOfView = targetFOV}):Play()
end

local function updateZoomFromInput(inputY)
    if not sliderFrame then return end
    local trackAbsPos = sliderFrame.AbsolutePosition.Y
    local trackAbsSize = sliderFrame.AbsoluteSize.Y
    local relativeY = math.clamp(inputY - trackAbsPos, 0, trackAbsSize)
    local percent = 1 - (relativeY / trackAbsSize)
    applyZoom(percent)
end

if sliderFrame then
    sliderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateZoomFromInput(input.Position.Y)
        end
    end)
end

UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateZoomFromInput(input.Position.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

local origRightC0, origLeftC0
local armConnection = nil

local function getBinocularShoulders(char)
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not torso then return nil, nil end
    local rShoulder = torso:FindFirstChild("Right Shoulder") or torso:FindFirstChild("RightShoulder")
    local lShoulder = torso:FindFirstChild("Left Shoulder") or torso:FindFirstChild("LeftShoulder")
    return rShoulder, lShoulder
end

local function startArmOverride()
    if armConnection then armConnection:Disconnect() end

    armConnection = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end

        local rShoulder, lShoulder = getBinocularShoulders(char)

        if rShoulder and lShoulder then
            if not origRightC0 then origRightC0 = rShoulder.C0 end
            if not origLeftC0 then origLeftC0 = lShoulder.C0 end

            lShoulder.Transform = CFrame.new()
            lShoulder.C0 = origLeftC0 
                * CFrame.new(-0.4, 0, 1) 
                * CFrame.Angles(math.rad(140), math.rad(-40), math.rad(0))

            if not isToggleActive then
                rShoulder.Transform = CFrame.new()
                rShoulder.C0 = origRightC0 
                    * CFrame.new(1, 0, 1) 
                    * CFrame.Angles(math.rad(140), math.rad(-40), math.rad(0))
            else
                rShoulder.C0 = origRightC0
            end
        end
    end)
end

local function stopArmOverride()
    if armConnection then
        armConnection:Disconnect()
        armConnection = nil
    end

    local char = LocalPlayer.Character
    if char then
        local rShoulder, lShoulder = getBinocularShoulders(char)
        if rShoulder and origRightC0 then rShoulder.C0 = origRightC0 end
        if lShoulder and origLeftC0 then lShoulder.C0 = origLeftC0 end
    end
end

local function activateBinocular()
    binoculoGui.Enabled = true
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    applyZoom(savedPercent)
    startArmOverride()
end

local function deactivateBinocular()
    if not isBinoculoEquipped and not isToggleActive then
        binoculoGui.Enabled = false
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        stopArmOverride()
        TweenService:Create(camera, TweenInfo.new(0.2), {FieldOfView = MAX_FOV}):Play()
    end
end

if toggleButton then
    toggleButton.MouseButton1Click:Connect(function()
        isToggleActive = not isToggleActive

        if isToggleActive then
            toggleButton.Text = "FIXAR: ON"
            toggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
            activateBinocular()
        else
            toggleButton.Text = "FIXAR: OFF"
            toggleButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
            deactivateBinocular()
        end
    end)
end

local function setupBinoculoTool()
    local backpack = LocalPlayer:WaitForChild("Backpack", 5)
    if not backpack then return end

    if backpack:FindFirstChild("Binóculo") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Binóculo")) then
        return
    end

    local binoculo = Instance.new("Tool")
    binoculo.Name = "Binóculo"
    binoculo.RequiresHandle = false
    binoculo.CanBeDropped = false

    binoculo.Equipped:Connect(function()
        isBinoculoEquipped = true
        activateBinocular()
    end)

    binoculo.Unequipped:Connect(function()
        isBinoculoEquipped = false
        deactivateBinocular()
    end)

    binoculo.Parent = backpack
end

-- ----------------------------------------------------------------------------
-- 9. GERENCIADOR DE ENTREGA E RESPAWN AUTOMÁTICO
-- ----------------------------------------------------------------------------
local function entegarTodasAsTools()
    task.wait(0.5)
    setupWalkieTalkieTool()
    setupCadernoTool()
    setupBinoculoTool()
end

-- Entrega inicial das ferramentas
entegarTodasAsTools()

-- Reentrega automatizada ao respawnar
LocalPlayer.CharacterAdded:Connect(function()
    origRightC0, origLeftC0 = nil, nil
    originalC0 = nil
    entegarTodasAsTools()
end)

print("[SISTEMA] Todas as Tools (Walkie-Talkie, Caderno e Binóculo) e GUIs foram carregadas e configuradas com sucesso!")

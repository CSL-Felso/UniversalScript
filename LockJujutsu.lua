local art = [[
  ---  ____ ____  _     
--- / ___/ ___|| |    
---| |   \___ \| |    
---| |___ ___) | |___ 
--- \____|____/|_____|
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local log = game:GetService("TestService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Controle de Zoom e Altura
local zoom = 8
local camHeight = 3
local minZoom = 4
local maxZoom = 15
local zoomSpeed = 1.5

local enabled = false
local target = nil
local renderConnection = nil
local inputConnection = nil
local diamond = nil
local lastSwitchTime = 0

local function adjustCamera(amount)
	local oldZoom = zoom
	zoom = math.clamp(zoom + amount, minZoom, maxZoom)
	
	local diff = zoom - oldZoom 
	camHeight = camHeight + diff
end

-- ==========================================
-- CONSTRUÇÃO DA INTERFACE VISUAL (GUI)
-- ==========================================
local gui = Instance.new("ScreenGui")
gui.Name = "LockGui"
gui.Parent = player:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(140, 44)
mainFrame.Position = UDim2.new(1, -160, 0, 190)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.Active = true -- Necessário para interações
mainFrame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(1, 0)
frameCorner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(170, 240, 240)
stroke.Thickness = 1.5
stroke.Transparency = 0.6
stroke.Parent = mainFrame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(66, 34)
toggleBtn.Position = UDim2.new(0, 5, 0.5, 0)
toggleBtn.AnchorPoint = Vector2.new(0, 0.5)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Text = "Toggle"
toggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
toggleBtn.Font = Enum.Font.GothamMedium
toggleBtn.TextSize = 14
toggleBtn.Parent = mainFrame

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 10)
toggleCorner.Parent = toggleBtn

local plusBtn = Instance.new("TextButton")
plusBtn.Size = UDim2.fromOffset(30, 34)
plusBtn.Position = UDim2.new(0, 75, 0.5, 0)
plusBtn.AnchorPoint = Vector2.new(0, 0.5)
plusBtn.BackgroundTransparency = 1
plusBtn.Text = "+"
plusBtn.TextColor3 = Color3.fromRGB(170, 240, 240)
plusBtn.Font = Enum.Font.GothamMedium
plusBtn.TextSize = 26
plusBtn.Parent = mainFrame

local minusBtn = Instance.new("TextButton")
minusBtn.Size = UDim2.fromOffset(30, 34)
minusBtn.Position = UDim2.new(0, 105, 0.5, 0)
minusBtn.AnchorPoint = Vector2.new(0, 0.5)
minusBtn.BackgroundTransparency = 1
minusBtn.Text = "–"
minusBtn.TextColor3 = Color3.fromRGB(170, 240, 240)
minusBtn.Font = Enum.Font.GothamMedium
minusBtn.TextSize = 26
minusBtn.Parent = mainFrame

-- ==========================================
-- SISTEMA PARA ARRASTAR A INTERFACE (DRAG)
-- ==========================================
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function updateInput(input)
	local delta = input.Position - dragStart
	mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

mainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

mainFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		updateInput(input)
	end
end)

-- ==========================================
-- LÓGICA DO SCRIPT (LOCK-ON E LERP)
-- ==========================================
local function getClosest()
	local closest = nil
	local shortest = math.huge
	local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)

	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= player.Character then
			local hum = obj:FindFirstChild("Humanoid")
			local hrp = obj:FindFirstChild("HumanoidRootPart")

			if hum and hrp and hum.Health > 0 then
				local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)

				if onScreen then
					local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
					if dist < shortest then
						shortest = dist
						closest = obj
					end
				end
			end
		end
	end
	return closest
end

local function createDiamond(hrp)
	if diamond then diamond:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 50, 0, 50)
	bb.Adornee = hrp
	bb.AlwaysOnTop = true
	bb.Parent = player.PlayerGui

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = "rbxassetid://113520624560741"
	img.ImageColor3 = Color3.fromRGB(255, 255, 255) 
	img.Parent = bb

	diamond = bb
end

local function cleanupConnections()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

local function disable()
	enabled = false
	target = nil
	
	toggleBtn.Text = "Toggle"
	toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

	cleanupConnections()
	camera.CameraType = Enum.CameraType.Custom

	if diamond then
		diamond:Destroy()
		diamond = nil
	end

	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.AutoRotate = true end
	end
end

local function switchTarget(deltaInput)
	if tick() - lastSwitchTime < 0.3 then return end
	if not target then return end

	local currentHrp = target:FindFirstChild("HumanoidRootPart")
	if not currentHrp then return end

	local currentPos, onScreen = camera:WorldToViewportPoint(currentHrp.Position)
	if not onScreen then return end

	local closest = nil
	local shortest = math.huge
	local deltaDir = deltaInput.Unit

	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= player.Character and obj ~= target then
			local hum = obj:FindFirstChild("Humanoid")
			local hrp = obj:FindFirstChild("HumanoidRootPart")

			if hum and hrp and hum.Health > 0 then
				local pos, isVis = camera:WorldToViewportPoint(hrp.Position)
				if isVis then
					local screenDir = Vector2.new(pos.X - currentPos.X, pos.Y - currentPos.Y)
					if screenDir.Magnitude > 0 then
						local dot = screenDir.Unit:Dot(deltaDir)
						if dot > 0.5 then 
							local dist = screenDir.Magnitude
							if dist < shortest then
								shortest = dist
								closest = obj
							end
						end
					end
				end
			end
		end
	end

	if closest then
		target = closest
		createDiamond(closest:FindFirstChild("HumanoidRootPart"))
		lastSwitchTime = tick()
	end
end

local function onInputChanged(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		adjustCamera(-input.Position.Z * zoomSpeed)
	elseif enabled and target then
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if input.Delta.Magnitude > 15 then 
				switchTarget(Vector2.new(input.Delta.X, input.Delta.Y))
			end
		end
	end
end

local function enable()
	inputConnection = UserInputService.InputChanged:Connect(onInputChanged)

	renderConnection = RunService.RenderStepped:Connect(function()
		if not enabled then return end

		if not target then
			target = getClosest()
			if target then
				local hrp = target:FindFirstChild("HumanoidRootPart")
				if hrp then createDiamond(hrp) end
			else
				return
			end
		end

		local myChar = player.Character
		if not myChar then
			disable()
			return
		end

		local myHRP = myChar:FindFirstChild("HumanoidRootPart")
		local myHum = myChar:FindFirstChildOfClass("Humanoid")
		
		if not myHRP or not myHum or myHum.Health <= 0 then
			disable()
			return
		end

		local hrp = target:FindFirstChild("HumanoidRootPart")
		local hum = target:FindFirstChild("Humanoid")

		if not hrp or not hum or hum.Health <= 0 then
			disable() 
			return
		end

		local myPos = myHRP.Position
		local targetPos = hrp.Position
		local look = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)

		if myHum then myHum.AutoRotate = false end

		-- APLICAÇÃO DO LERP NO PERSONAGEM (Para virar suavemente)
		local targetCharCF = CFrame.new(myPos, look)
		myHRP.CFrame = myHRP.CFrame:Lerp(targetCharCF, 0.9)

		camera.CameraType = Enum.CameraType.Scriptable

		-- Posição desejada para a câmera (com base no zoom e altura ajustáveis)
		local dir = (hrp.Position - myHRP.Position)
		local dirUnit = dir.Unit
		local camPos = myHRP.Position - dirUnit * zoom + Vector3.new(0, camHeight, 0)
		
		local targetCamCF = CFrame.new(camPos, hrp.Position)

		-- APLICAÇÃO DO LERP NA CÂMERA (Suavidade de 0.9)
		camera.CFrame = camera.CFrame:Lerp(targetCamCF, 0.9)
	end)
end

-- ==========================================
-- BOTÕES E TECLADO
-- ==========================================
plusBtn.MouseButton1Click:Connect(function()
	adjustCamera(1)
end)

minusBtn.MouseButton1Click:Connect(function()
	adjustCamera(-1)
end)

toggleBtn.MouseButton1Click:Connect(function()
	enabled = not enabled

	if enabled then
		toggleBtn.Text = "ON"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 255, 200)
		enable()
		log:Message("[LOG]: Lock On")
	else
		disable()
		log:Message("[LOG]: Lock Off")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
    
	if input.KeyCode == Enum.KeyCode.T then
		enabled = not enabled 
        
		if enabled then
			toggleBtn.Text = "ON"
			toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 255, 200)
			enable()
			log:Message("Log: ENABLE")
		else
			disable()
			log:Message("Log: DISABLE")
		end
	elseif input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.KeypadPlus then
		adjustCamera(-1)
	elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
		adjustCamera(1)
	end
end)

log:Message(art)

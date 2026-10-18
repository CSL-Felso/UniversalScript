-- Serviços necessários
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- IDs das texturas e do som
local ID_DOZER1 = 90447395338543
local ID_DOZER2 = 100402458619661
local ID_DOZER3 = 136929109238320
local ID_DOZER4 = 72312774167181
local ID_SOUND  = 105542807829649

-- Controle para garantir apenas um Dozer ativo por vez
local isDozerActive = false

-- 1. Gerenciamento da Pasta na CoreGui (Evita duplicação)
local folder = CoreGui:FindFirstChild("DozerEventFolder")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "DozerEventFolder"
	folder.Parent = CoreGui
end

-- 2. Gerenciamento da ScreenGui principal
local screenGui = folder:FindFirstChild("DozerGui")
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DozerGui"
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = folder
end

-- 3. Fundo preto (inicialmente invisível)
local blackBackground = screenGui:FindFirstChild("BlackBackground")
if not blackBackground then
	blackBackground = Instance.new("Frame")
	blackBackground.Name = "BlackBackground"
	blackBackground.Size = UDim2.new(1, 0, 1, 0)
	blackBackground.BackgroundColor3 = Color3.new(0, 0, 0)
	blackBackground.BackgroundTransparency = 1
	blackBackground.ZIndex = 1
	blackBackground.Parent = screenGui
end

-- 4. Imagem do Dozer no meio da tela (Tamanho otimizado: 250x250)
local imageLabel = screenGui:FindFirstChild("DozerImage")
if not imageLabel then
	imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "DozerImage"
	imageLabel.Size = UDim2.new(0, 250, 0, 250)
	imageLabel.Position = UDim2.new(0.5, -125, 0.5, -125)
	imageLabel.BackgroundTransparency = 1
	imageLabel.ImageTransparency = 1 -- Começa invisível para a animação
	imageLabel.Visible = false
	imageLabel.ZIndex = 2
	imageLabel.Parent = screenGui
end

-- 5. Criação do Som (DozerSound)
local sound = screenGui:FindFirstChild("DozerSound")
if not sound then
	sound = Instance.new("Sound")
	sound.Name = "DozerSound"
	sound.SoundId = "rbxassetid://" .. ID_SOUND
	sound.Volume = 2
	sound.Parent = screenGui
end

-- Pré-carrega todos os assets para evitar travamentos
local assetsToLoad = {
	imageLabel,
	sound,
	"rbxassetid://" .. ID_DOZER1,
	"rbxassetid://" .. ID_DOZER2,
	"rbxassetid://" .. ID_DOZER3,
	"rbxassetid://" .. ID_DOZER4
}
ContentProvider:PreloadAsync(assetsToLoad)

-- Função para resetar/limpar o estado visual do Dozer (usada ao respawnar ou finalizar)
local function resetDozerState()
	isDozerActive = false
	if sound.IsPlaying then
		sound:Stop()
	end
	imageLabel.Visible = false
	imageLabel.ImageTransparency = 1
	blackBackground.BackgroundTransparency = 1
end

-- Ouve quando o personagem renasce para limpar a tela preta e o Dozer imediatamente
player.CharacterAdded:Connect(function(newCharacter)
	resetDozerState()
end)

-- Função para animar a entrada do Dozer suavemente
local function animateDozerAppear()
	imageLabel.Size = UDim2.new(0, 180, 0, 180) -- Começa menor
	imageLabel.ImageTransparency = 1
	imageLabel.Visible = true
	
	-- Configuração da animação (Tween)
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local goal = {
		Size = UDim2.new(0, 250, 0, 250),
		ImageTransparency = 0
	}
	
	local tween = TweenService:Create(imageLabel, tweenInfo, goal)
	tween:Play()
end

-- Função para executar um ciclo do Dozer
local function runDozerCycle()
	if isDozerActive then return false end
	
	local character = player.Character
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	isDozerActive = true

	-- Reseta estados e define a primeira imagem
	imageLabel.Image = "rbxassetid://" .. ID_DOZER1
	blackBackground.BackgroundTransparency = 1
	
	-- Anima a aparição do Dozer na tela
	animateDozerAppear()
	
	-- Toca o som junto
	sound.TimePosition = 0
	sound:Play()
	
	-- Quando o DozerSound acabar
	sound.Ended:Wait()
	
	-- Verifica se o player ainda está vivo e se o evento continua ativo
	if not isDozerActive or not humanoid or humanoid.Health <= 0 then
		resetDozerState()
		return false 
	end

	-- Troca para a imagem Dozer2 (Acordando)
	imageLabel.Image = "rbxassetid://" .. ID_DOZER2
	
	-- Checa se o jogador continua andando (MoveDirection.Magnitude > 0)
	task.wait(0.2) -- Janela balanceada para o jogador parar a tempo se estiver atento
	local isMoving = humanoid.MoveDirection.Magnitude > 0
	
	if isMoving then
		-- Troca para a imagem Dozer3 e deixa o fundo preto instantaneamente
		imageLabel.Image = "rbxassetid://" .. ID_DOZER3
		blackBackground.BackgroundTransparency = 0
		
		-- Espera 0.3 segundos e muda para o Dozer4 (Jumpscare final)
		task.wait(0.3)
		imageLabel.Image = "rbxassetid://" .. ID_DOZER4
		
		-- Mata o jogador
		humanoid.Health = 0
		return true 
	else
		-- Se o jogador parou, faz um fade-out suave sumindo o Dozer
		local fadeOutInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fadeTween = TweenService:Create(imageLabel, fadeOutInfo, {ImageTransparency = 1})
		fadeTween:Play()
		fadeTween.Completed:Wait()
		
		resetDozerState()
		return false
	end
end

-- Loop principal balanceado (O Dozer aparece a cada 35 a 65 segundos)
task.spawn(function()
	while true do
		local waitTime = math.random(35, 65)
		task.wait(waitTime)
		
		if not isDozerActive then
			runDozerCycle()
		end
	end
end)

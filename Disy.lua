-- ==========================================
-- FOXNAME HUB - CLEAN UI LIBRARY FRAMEWORK
-- ==========================================
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Library = {}
local Tabs = {}
local currentTab = nil
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- Cores de Fábrica (Padrão)
local Theme = {
	Background = Color3.fromRGB(15, 18, 25),
	Sidebar = Color3.fromRGB(20, 24, 33),
	ElementBg = Color3.fromRGB(30, 35, 45),
	ElementHover = Color3.fromRGB(40, 47, 60),
	Text = Color3.fromRGB(220, 220, 220),
	TextDark = Color3.fromRGB(120, 130, 145),
	Divider = Color3.fromRGB(35, 40, 50),
	ToggleOn = Color3.fromRGB(255, 255, 255),
	ToggleOff = Color3.fromRGB(60, 65, 80),
	CloseRed = Color3.fromRGB(255, 80, 80)
}

-- Registro de Elementos para troca de Cor em Tempo Real
local ThemedElements = { Backgrounds = {}, Sidebars = {}, Toggles = {} }

function Library:SetThemeColor(property, color3)
	if Theme[property] then
		Theme[property] = color3
		-- Atualiza Backgrounds
		for _, obj in pairs(ThemedElements.Backgrounds) do
			TweenService:Create(obj, TweenInfo.new(0.3), {BackgroundColor3 = Theme.Background}):Play()
		end
		-- Atualiza Elementos secundários/Sidebar
		for _, obj in pairs(ThemedElements.Sidebars) do
			TweenService:Create(obj, TweenInfo.new(0.3), {BackgroundColor3 = Theme.Sidebar}):Play()
		end
		-- Atualiza Toggles Ativos
		for _, toggleData in pairs(ThemedElements.Toggles) do
			local targetColor = toggleData.state.Value and Theme.ToggleOn or Theme.ToggleOff
			TweenService:Create(toggleData.bg, TweenInfo.new(0.3), {BackgroundColor3 = targetColor}):Play()
		end
	end
end

local function create(className, properties, children)
	local inst = Instance.new(className)
	for i, v in pairs(properties or {}) do inst[i] = v end
	for _, child in pairs(children or {}) do child.Parent = inst end
	return inst
end

-- Criando a Janela Principal
local ScreenGui = create("ScreenGui", { Name = "Disy", ResetOnSpawn = false })
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = create("Frame", {
	Name = "MainFrame", Size = UDim2.new(0, 650, 0, 400), Position = UDim2.new(0.5, -325, 0.5, -200),
	BackgroundColor3 = Theme.Background, BorderSizePixel = 0, ClipsDescendants = true,
}, { create("UICorner", {CornerRadius = UDim.new(0, 10)}) })
MainFrame.Parent = ScreenGui
table.insert(ThemedElements.Backgrounds, MainFrame)

-- Cabeçalho (TopBar)
local TopBar = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
TopBar.Parent = MainFrame

create("TextLabel", { Text = "   @Sr_Brasil6", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255,255,255), Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0,0,0,-6), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left }).Parent = TopBar
create("TextLabel", { Text = "   Hub", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.TextDark, Size = UDim2.new(1, -100, 1, 15), Position = UDim2.new(0,0,0,8), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left }).Parent = TopBar

-- Controles de Minimizar/Fechar
local WindowControls = create("Frame", { Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(1, -80, 0, 0), BackgroundTransparency = 1 })
WindowControls.Parent = TopBar
local MinimizeBtn = create("TextButton", { Size = UDim2.new(0, 40, 1, 0), BackgroundTransparency = 1, Text = "—", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.TextDark })
MinimizeBtn.Parent = WindowControls
local CloseBtn = create("TextButton", { Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(0, 40, 0, 0), BackgroundTransparency = 1, Text = "X", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.TextDark })
CloseBtn.Parent = WindowControls

-- Lógica de Minimizar
local isMinimized = false
local ContentContainer = create("Frame", { Size = UDim2.new(1,0,1,-40), Position = UDim2.new(0,0,0,40), BackgroundTransparency = 1 })
ContentContainer.Parent = MainFrame

MinimizeBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	MainFrame:TweenSize(isMinimized and UDim2.new(0, 650, 0, 40) or UDim2.new(0, 650, 0, 400), "Out", "Quart", 0.25, true)
	ContentContainer.Visible = not isMinimized
end)

-- Confirmação de Fechamento
local ConfirmOverlay = create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 1, Visible = false, ZIndex = 10 })
ConfirmOverlay.Parent = MainFrame
local ConfirmBox = create("Frame", { Size = UDim2.new(0, 250, 0, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 20), BackgroundColor3 = Theme.Sidebar, ZIndex = 11, BackgroundTransparency = 1 }, { create("UICorner", {CornerRadius = UDim.new(0, 8)}) })
ConfirmBox.Parent = ConfirmOverlay
table.insert(ThemedElements.Sidebars, ConfirmBox)

create("TextLabel", { Size = UDim2.new(1,0,0,40), Position = UDim2.new(0,0,0,10), BackgroundTransparency = 1, Text = "Deseja fechar o Menu?", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, ZIndex = 12 }).Parent = ConfirmBox
local BtnSim = create("TextButton", { Size = UDim2.new(0, 100, 0, 35), Position = UDim2.new(0, 15, 0, 70), BackgroundColor3 = Theme.CloseRed, Text = "Sim", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255,255,255), TextSize = 13, ZIndex = 12 }, { create("UICorner", {CornerRadius = UDim.new(0, 6)}) })
BtnSim.Parent = ConfirmBox
local BtnNao = create("TextButton", { Size = UDim2.new(0, 100, 0, 35), Position = UDim2.new(1, -115, 0, 70), BackgroundColor3 = Theme.ElementBg, Text = "Não", Font = Enum.Font.GothamBold, TextColor3 = Theme.Text, TextSize = 13, ZIndex = 12 }, { create("UICorner", {CornerRadius = UDim.new(0, 6)}) })
BtnNao.Parent = ConfirmBox

CloseBtn.MouseButton1Click:Connect(function()
	ConfirmOverlay.Visible = true
	TweenService:Create(ConfirmOverlay, tweenInfo, {BackgroundTransparency = 0.5}):Play()
	TweenService:Create(ConfirmBox, tweenInfo, {BackgroundTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
end)
BtnNao.MouseButton1Click:Connect(function()
	TweenService:Create(ConfirmOverlay, tweenInfo, {BackgroundTransparency = 1}):Play()
	local tw = TweenService:Create(ConfirmBox, tweenInfo, {BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 20)})
	tw:Play() tw.Completed:Wait() ConfirmOverlay.Visible = false
end)
BtnSim.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Conteiner Lateral (Sidebar) e Central (Tabs)
local Sidebar = create("ScrollingFrame", { Size = UDim2.new(0, 160, 1, -10), BackgroundTransparency = 1, ScrollBarThickness = 0 }, { create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}), create("UIPadding", {PaddingLeft = UDim.new(0, 15), PaddingRight = UDim.new(0, 15), PaddingTop = UDim.new(0, 5)}) })
Sidebar.Parent = ContentContainer

local TabContainer = create("Frame", { Size = UDim2.new(1, -180, 1, -15), Position = UDim2.new(0, 165, 0, 0), BackgroundColor3 = Theme.Sidebar, ClipsDescendants = true }, { create("UICorner", {CornerRadius = UDim.new(0, 8)}) })
TabContainer.Parent = ContentContainer
table.insert(ThemedElements.Sidebars, TabContainer)

-- Construtor de Seções (Separadores expansíveis)
function Library:CreateSection(name, icon)
	local SectionObj = { Tabs = {}, IsOpen = true }
	local SectionBtn = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
	create("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = ((icon or "📁").."  "..name), Font = Enum.Font.GothamSemibold, TextSize = 12, TextColor3 = Theme.TextDark, TextXAlignment = Enum.TextXAlignment.Left }).Parent = SectionBtn
	local Arrow = create("TextLabel", { Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -20, 0, 0), BackgroundTransparency = 1, Text = "⌃", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.TextDark })
	Arrow.Parent = SectionBtn
	create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 5), BackgroundColor3 = Theme.Divider, BorderSizePixel = 0 }).Parent = SectionBtn
	SectionBtn.Parent = Sidebar
	create("Frame", {Size = UDim2.new(1,0,0,5), BackgroundTransparency=1}).Parent = Sidebar

	SectionBtn.MouseButton1Click:Connect(function()
		SectionObj.IsOpen = not SectionObj.IsOpen
		TweenService:Create(Arrow, tweenInfo, {Rotation = SectionObj.IsOpen and 0 or 180}):Play()
		for _, tabBtn in ipairs(SectionObj.Tabs) do tabBtn.Visible = SectionObj.IsOpen end
		Sidebar.CanvasSize = UDim2.new(0,0,0, Sidebar.UIListLayout.AbsoluteContentSize.Y + 20)
	end)

	-- Construtor de Abas internas da Seção
	function SectionObj:CreateTab(tabName, iconColor, emoji)
		local TabObj = {}
		local TabButton = create("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Theme.Background, Text = "", AutoButtonColor = false }, { create("UICorner", {CornerRadius = UDim.new(0, 6)}) })
		TabButton.Parent = Sidebar
		table.insert(ThemedElements.Backgrounds, TabButton)
		table.insert(SectionObj.Tabs, TabButton)

		local IconBg = create("Frame", { Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0, 5, 0.5, -11), BackgroundColor3 = iconColor or Theme.ElementBg }, { create("UICorner", {CornerRadius = UDim.new(0, 6)}) })
		IconBg.Parent = TabButton
		create("TextLabel", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = emoji or "📄", TextSize = 12 }).Parent = IconBg

		local TabText = create("TextLabel", { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 35, 0, 0), BackgroundTransparency = 1, Text = tabName, Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = Theme.TextDark, TextXAlignment = Enum.TextXAlignment.Left })
		TabText.Parent = TabButton

		local TabPage = create("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.TextDark, Visible = false }, { create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}), create("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}) })
		TabPage.Parent = TabContainer

		TabPage.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TabPage.CanvasSize = UDim2.new(0, 0, 0, TabPage.UIListLayout.AbsoluteContentSize.Y + 20) end)

		TabButton.MouseButton1Click:Connect(function()
			for btn, data in pairs(Tabs) do
				TweenService:Create(btn, tweenInfo, {BackgroundColor3 = Theme.Background}):Play()
				TweenService:Create(data.text, tweenInfo, {TextColor3 = Theme.TextDark}):Play()
				data.page.Visible = false
			end
			TweenService:Create(TabButton, tweenInfo, {BackgroundColor3 = Theme.Sidebar}):Play()
			TweenService:Create(TabText, tweenInfo, {TextColor3 = Color3.fromRGB(255,255,255)}):Play()
			TabPage.Visible = true
		end)

		Tabs[TabButton] = {page = TabPage, text = TabText}
		if not currentTab then
			currentTab = TabButton
			TabButton.BackgroundColor3 = Theme.Sidebar
			TabText.TextColor3 = Color3.fromRGB(255,255,255)
			TabPage.Visible = true
		end

		-- Criar Botão na Aba
		function TabObj:CreateButton(btnName, callback)
			local Button = create("TextButton", { Size = UDim2.new(1, -20, 0, 45), Position = UDim2.new(0, 10, 0, 0), BackgroundColor3 = Theme.Sidebar, Text = "", AutoButtonColor = false })
			create("TextLabel", { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 15, 0, 0), BackgroundTransparency = 1, Text = btnName, Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }).Parent = Button
			create("TextLabel", { Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -30, 0, 0), BackgroundTransparency = 1, Text = "🖱️", TextSize = 14 }).Parent = Button

			Button.MouseEnter:Connect(function() TweenService:Create(Button, tweenInfo, {BackgroundColor3 = Theme.ElementHover}):Play() end)
			Button.MouseLeave:Connect(function() TweenService:Create(Button, tweenInfo, {BackgroundColor3 = Theme.Sidebar}):Play() end)
			Button.MouseButton1Click:Connect(function() pcall(callback) end)
			Button.Parent = TabPage
			table.insert(ThemedElements.Sidebars, Button)
		end

		-- Criar Toggle na Aba
		function TabObj:CreateToggle(toggleName, desc, callback)
			local height = (desc and desc ~= "") and 55 or 45
			local ToggleBtn = create("TextButton", { Size = UDim2.new(1, -20, 0, height), Position = UDim2.new(0, 10, 0, 0), BackgroundColor3 = Theme.Sidebar, Text = "", AutoButtonColor = false })
			create("TextLabel", { Size = UDim2.new(1, -70, 0, 20), Position = UDim2.new(0, 15, 0, (desc and desc ~= "") and 10 or 12), BackgroundTransparency = 1, Text = toggleName, Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left }).Parent = ToggleBtn
			if desc and desc ~= "" then create("TextLabel", { Size = UDim2.new(1, -70, 0, 15), Position = UDim2.new(0, 15, 0, 30), BackgroundTransparency = 1, Text = desc, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.TextDark, TextXAlignment = Enum.TextXAlignment.Left }).Parent = ToggleBtn end
			
			local SwitchBg = create("Frame", { Size = UDim2.new(0, 36, 0, 20), Position = UDim2.new(1, -50, 0.5, -10), BackgroundColor3 = Theme.ToggleOff }, { create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
			SwitchBg.Parent = ToggleBtn
			local SwitchDot = create("Frame", { Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = Color3.fromRGB(200, 200, 200) }, { create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
			SwitchDot.Parent = SwitchBg

			local StateValue = {Value = false}
			ToggleBtn.MouseEnter:Connect(function() TweenService:Create(ToggleBtn, tweenInfo, {BackgroundColor3 = Theme.ElementHover}):Play() end)
			ToggleBtn.MouseLeave:Connect(function() TweenService:Create(ToggleBtn, tweenInfo, {BackgroundColor3 = Theme.Sidebar}):Play() end)

			ToggleBtn.MouseButton1Click:Connect(function()
				StateValue.Value = not StateValue.Value
				TweenService:Create(SwitchDot, tweenInfo, {Position = StateValue.Value and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = StateValue.Value and Theme.Background or Color3.fromRGB(200, 200, 200)}):Play()
				TweenService:Create(SwitchBg, tweenInfo, {BackgroundColor3 = StateValue.Value and Theme.ToggleOn or Theme.ToggleOff}):Play()
				pcall(callback, StateValue.Value)
			end)
			
			ToggleBtn.Parent = TabPage
			table.insert(ThemedElements.Sidebars, ToggleBtn)
			table.insert(ThemedElements.Toggles, {bg = SwitchBg, state = StateValue})
		end

		return TabObj
	end
	return SectionObj
end

-- Mantém o tamanho inicial ajustado correto
task.defer(function() Sidebar.CanvasSize = UDim2.new(0, 0, 0, Sidebar.UIListLayout.AbsoluteContentSize.Y + 20) end)

return Library

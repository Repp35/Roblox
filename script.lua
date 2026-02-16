local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MensagemFoda"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui
screenGui.IgnoreGuiInset = true

local function criarLinha(texto, posY, corTexto)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.3, 0)
    label.Position = UDim2.new(0, 0, posY, 0)
    label.BackgroundTransparency = 1
    label.Text = texto
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = corTexto
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0,0,0)
    label.Parent = screenGui
end

criarLinha("eu não uso script", 0.35, Color3.fromRGB(255, 0, 0))
criarLinha("Seu pola", 0.55, Color3.fromRGB(255, 255, 0))
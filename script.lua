local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MensagemFoda"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local function criarLinha(texto, posY, corTexto)
    local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0.2, 0)
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

                                            criarLinha("Eu não uso script", 0.25, Color3.fromRGB(255, 0, 0))
                                            criarLinha("Perdeu 2 centavos otario", 0.45, Color3.fromRGB(255, 255, 0))
                                            criarLinha("KKKKKKKKKK-", 0.65, Color3.fromRGB(0, 255, 0))

                                            screenGui.IgnoreGuiInset = true
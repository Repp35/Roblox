-- ╔══════════════════════════════════════════════════╗
-- ║         NEXUS HUB - Professional Roblox GUI      ║
-- ║         Auto Parry System | v2.0                 ║
-- ╚══════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ══════════════════════════════════════════
--              SETTINGS
-- ══════════════════════════════════════════
local CONFIG = {
    GUI_NAME        = "NexusHub",
    -- Default theme: Black & White
    ACCENT_COLOR    = Color3.fromRGB(220, 220, 220),
    ACCENT_GLOW     = Color3.fromRGB(255, 255, 255),
    BG_DARK         = Color3.fromRGB(8,   8,   8),
    BG_MID          = Color3.fromRGB(18,  18,  18),
    BG_PANEL        = Color3.fromRGB(26,  26,  26),
    BORDER_COLOR    = Color3.fromRGB(55,  55,  55),
    TEXT_PRIMARY    = Color3.fromRGB(240, 240, 255),
    TEXT_SECONDARY  = Color3.fromRGB(140, 140, 180),
    TOGGLE_ON       = Color3.fromRGB(200, 200, 200),
    TOGGLE_OFF      = Color3.fromRGB(45, 45, 70),
    SUCCESS         = Color3.fromRGB(34, 197, 94),
    DANGER          = Color3.fromRGB(239, 68, 68),
    PARRY_DIST      = 1,   -- base detector radius (studs)
}

-- ══════════════════════════════════════════
--         GAME DETECTION
-- ══════════════════════════════════════════
local GAME_NAMES = {
    phantom = {"Phantom ball", "Bola fantasma", "Phantom Ball", "Bola Fantasma"},
    anime   = {"Anime ball", "Bola de anime", "Anime Ball", "Bola De Anime"},
}

-- PlaceId detection (fastest method — no API call needed)
-- IDs stored as strings to avoid Lua float precision issues with large integers
local GAME_IDS = {
    phantom = {"4538598064"},
    anime   = {"5120885191"},
}

local DETECTED_GAME = nil  -- "Phantom" | "Anime" | nil

local function detectGame()
    local placeId = game.PlaceId
    print("[NexusHub] PlaceId =", placeId)

    -- 1) Check by PlaceId first (instant, no API call)
    for _, id in ipairs(GAME_IDS.phantom) do
        if placeId == tonumber(id) then return "phantom" end
    end
    for _, id in ipairs(GAME_IDS.anime) do
        if placeId == tonumber(id) then return "anime" end
    end

    -- 2) Fallback: check by game name via MarketplaceService
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(placeId)
    end)
    if not ok or not info then
        print("[NexusHub] MarketplaceService failed")
        return nil
    end
    print("[NexusHub] Game name =", info.Name)
    local lower = info.Name:lower()
    for _, n in ipairs(GAME_NAMES.phantom) do
        if lower:find(n:lower(), 1, true) then return "phantom" end
    end
    for _, n in ipairs(GAME_NAMES.anime) do
        if lower:find(n:lower(), 1, true) then return "anime" end
    end
    return nil
end

-- ══════════════════════════════════════════
--              GLOBAL STATE
-- ══════════════════════════════════════════
local State = {
    autoParry                = false,
    detectorPart             = nil,
    runConnection            = nil,
    guiOpen                  = true,
    hasExecutedThisDetection = false,
    lastBallColor            = nil,
    ballWasInside            = false,
    showDetectors            = false,
    -- Auto Spam
    autoSpam                 = false,
    spamDetectorPart         = nil,
    spamConnection           = nil,
    spamActive               = false,
    spamLoopConn             = nil,
    spamMultiplier           = 1,
    savedSpamTarget          = nil,
    -- Stats GUIs
    showParryStats           = false,
    showSpamStats            = false,
    parryCount               = 0,
    spamCount                = 0,
    -- Modo de parry
    parryMode                = "remote", -- "remote" | "button" | "anime_button"
    optimizer                = false,
    -- Anime Ball: speed detector separado
    speedDetectorConn        = nil,
    animeTrackedSpeed        = 0,   -- current speed detected by speed detector
    lastSpeedCFrame          = nil, -- previous CFrame for speed calculation
}

-- ══════════════════════════════════════════
--         OLD GUI REMOVAL
-- ══════════════════════════════════════════
local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(CONFIG.GUI_NAME)
if oldGui then oldGui:Destroy() end

-- ══════════════════════════════════════════
--         LOADING SCREEN
-- ══════════════════════════════════════════
local LoadGui = Instance.new("ScreenGui")
LoadGui.Name            = "NexusHubLoader"
LoadGui.ResetOnSpawn    = false
LoadGui.IgnoreGuiInset  = true
LoadGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
LoadGui.Parent          = LocalPlayer:WaitForChild("PlayerGui")

local loadFrame = Instance.new("Frame", LoadGui)
loadFrame.Size               = UDim2.new(1, 0, 1, 0)
loadFrame.BackgroundColor3   = CONFIG.BG_DARK
loadFrame.BorderSizePixel    = 0
loadFrame.ZIndex             = 100

-- Background gradient
local loadGrad = Instance.new("UIGradient", loadFrame)
loadGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(8,  8,  20)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(14, 10, 30)),
})
loadGrad.Rotation = 135

-- Center glow
local loadGlow = Instance.new("Frame", loadFrame)
loadGlow.Size               = UDim2.new(0, 340, 0, 340)
loadGlow.Position           = UDim2.new(0.5, -170, 0.5, -170)
loadGlow.BackgroundColor3   = CONFIG.ACCENT_COLOR
loadGlow.BackgroundTransparency = 0.88
loadGlow.BorderSizePixel    = 0
loadGlow.ZIndex             = 101
Instance.new("UICorner", loadGlow).CornerRadius = UDim.new(1, 0)

-- Center card
local loadCard = Instance.new("Frame", loadFrame)
loadCard.Size               = UDim2.new(0, 300, 0, 220)
loadCard.Position           = UDim2.new(0.5, -150, 0.5, -110)
loadCard.BackgroundColor3   = CONFIG.BG_MID
loadCard.BorderSizePixel    = 0
loadCard.ZIndex             = 102
Instance.new("UICorner", loadCard).CornerRadius = UDim.new(0, 16)
local loadCardStroke = Instance.new("UIStroke", loadCard)
loadCardStroke.Color     = CONFIG.BORDER_COLOR
loadCardStroke.Thickness = 1.5

-- Top accent line
local loadAccentTop = Instance.new("Frame", loadCard)
loadAccentTop.Size             = UDim2.new(1, 0, 0, 3)
loadAccentTop.BackgroundColor3 = CONFIG.ACCENT_COLOR
loadAccentTop.BorderSizePixel  = 0
loadAccentTop.ZIndex           = 103
Instance.new("UICorner", loadAccentTop).CornerRadius = UDim.new(0, 16)
local loadAccentGrad = Instance.new("UIGradient", loadAccentTop)
loadAccentGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   CONFIG.ACCENT_COLOR),
    ColorSequenceKeypoint.new(0.5, CONFIG.ACCENT_GLOW),
    ColorSequenceKeypoint.new(1,   CONFIG.ACCENT_COLOR),
})

-- Pulsing icon / logo
local loadIcon = Instance.new("TextLabel", loadCard)
loadIcon.Text                  = "⚔"
loadIcon.Size                  = UDim2.new(0, 54, 0, 54)
loadIcon.Position              = UDim2.new(0.5, -27, 0, 20)
loadIcon.BackgroundTransparency = 1
loadIcon.TextColor3            = CONFIG.ACCENT_COLOR
loadIcon.TextSize              = 36
loadIcon.Font                  = Enum.Font.GothamBold
loadIcon.ZIndex                = 103

-- Title
local loadTitle = Instance.new("TextLabel", loadCard)
loadTitle.Text                  = "NEXUS HUB"
loadTitle.Size                  = UDim2.new(1, -20, 0, 26)
loadTitle.Position              = UDim2.new(0, 10, 0, 82)
loadTitle.BackgroundTransparency = 1
loadTitle.TextColor3            = CONFIG.TEXT_PRIMARY
loadTitle.TextSize              = 18
loadTitle.Font                  = Enum.Font.GothamBold
loadTitle.TextXAlignment        = Enum.TextXAlignment.Center
loadTitle.ZIndex                = 103

-- Status label
local loadStatus = Instance.new("TextLabel", loadCard)
loadStatus.Text                  = "🔍  Detecting game..."
loadStatus.Size                  = UDim2.new(1, -20, 0, 18)
loadStatus.Position              = UDim2.new(0, 10, 0, 114)
loadStatus.BackgroundTransparency = 1
loadStatus.TextColor3            = CONFIG.TEXT_SECONDARY
loadStatus.TextSize              = 11
loadStatus.Font                  = Enum.Font.Gotham
loadStatus.TextXAlignment        = Enum.TextXAlignment.Center
loadStatus.ZIndex                = 103

-- Progress bar (track)
local loadBarTrack = Instance.new("Frame", loadCard)
loadBarTrack.Size             = UDim2.new(1, -40, 0, 6)
loadBarTrack.Position         = UDim2.new(0, 20, 0, 148)
loadBarTrack.BackgroundColor3 = CONFIG.TOGGLE_OFF
loadBarTrack.BorderSizePixel  = 0
loadBarTrack.ZIndex           = 103
Instance.new("UICorner", loadBarTrack).CornerRadius = UDim.new(1, 0)

local loadBarFill = Instance.new("Frame", loadBarTrack)
loadBarFill.Size             = UDim2.new(0, 0, 1, 0)
loadBarFill.BackgroundColor3 = CONFIG.ACCENT_COLOR
loadBarFill.BorderSizePixel  = 0
loadBarFill.ZIndex           = 104
Instance.new("UICorner", loadBarFill).CornerRadius = UDim.new(1, 0)
local loadBarGrad = Instance.new("UIGradient", loadBarFill)
loadBarGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   CONFIG.ACCENT_COLOR),
    ColorSequenceKeypoint.new(1,   CONFIG.ACCENT_GLOW),
})

-- Detected game badge
local loadBadge = Instance.new("Frame", loadCard)
loadBadge.Size             = UDim2.new(1, -40, 0, 28)
loadBadge.Position         = UDim2.new(0, 20, 0, 168)
loadBadge.BackgroundColor3 = CONFIG.BG_PANEL
loadBadge.BackgroundTransparency = 1
loadBadge.BorderSizePixel  = 0
loadBadge.ZIndex           = 103
Instance.new("UICorner", loadBadge).CornerRadius = UDim.new(0, 8)

local loadBadgeLabel = Instance.new("TextLabel", loadBadge)
loadBadgeLabel.Size                  = UDim2.new(1, 0, 1, 0)
loadBadgeLabel.BackgroundTransparency = 1
loadBadgeLabel.TextColor3            = CONFIG.SUCCESS
loadBadgeLabel.TextSize              = 11
loadBadgeLabel.Font                  = Enum.Font.GothamBold
loadBadgeLabel.TextXAlignment        = Enum.TextXAlignment.Center
loadBadgeLabel.ZIndex                = 104
loadBadgeLabel.Text                  = ""

-- Icon pulse animation
task.spawn(function()
    while LoadGui.Parent do
        TweenService:Create(loadIcon, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {TextColor3 = CONFIG.ACCENT_GLOW}):Play()
        task.wait(0.7)
        TweenService:Create(loadIcon, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {TextColor3 = CONFIG.ACCENT_COLOR}):Play()
        task.wait(0.7)
    end
end)

-- Function to animate the progress bar
local function setLoadProgress(pct, statusText)
    TweenService:Create(loadBarFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(pct, 0, 1, 0)}):Play()
    if statusText then loadStatus.Text = statusText end
end

-- Function to close loading with animation
local function closeLoading()
    TweenService:Create(loadFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency = 1}):Play()
    TweenService:Create(loadCard, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, -150, 0.6, -110), BackgroundTransparency = 1}):Play()
    TweenService:Create(loadGlow, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    task.delay(0.55, function()
        LoadGui:Destroy()
    end)
end

-- ── Detection logic ────────────────────
-- BindableEvent ensures DETECTED_GAME is set before the GUI is built
local _guiReady = Instance.new("BindableEvent")

task.spawn(function()
    setLoadProgress(0.15, "🔍  Detecting game...")
    task.wait(0.4)

    setLoadProgress(0.45, "📡  Querying PlaceId...")
    task.wait(0.3)

    local gameMode = detectGame()
    DETECTED_GAME = gameMode

    setLoadProgress(0.75, "⚙️  Configuring modules...")
    task.wait(0.35)

    if gameMode == "phantom" then
        -- ── Phantom Ball: show "not supported yet" popup ──────────────
        -- Hides loading card and shows a warning modal instead
        loadCard.Visible = false

        -- Overlay card (wider to fit message)
        local warnCard = Instance.new("Frame", loadFrame)
        warnCard.Size             = UDim2.new(0, 360, 0, 280)
        warnCard.Position         = UDim2.new(0.5, -180, 0.5, -140)
        warnCard.BackgroundColor3 = CONFIG.BG_MID
        warnCard.BorderSizePixel  = 0
        warnCard.ZIndex           = 110
        Instance.new("UICorner", warnCard).CornerRadius = UDim.new(0, 16)
        local warnStroke = Instance.new("UIStroke", warnCard)
        warnStroke.Color     = CONFIG.DANGER
        warnStroke.Thickness = 1.5

        -- Top accent line (red)
        local warnTop = Instance.new("Frame", warnCard)
        warnTop.Size             = UDim2.new(1, 0, 0, 3)
        warnTop.BackgroundColor3 = CONFIG.DANGER
        warnTop.BorderSizePixel  = 0
        warnTop.ZIndex           = 111
        Instance.new("UICorner", warnTop).CornerRadius = UDim.new(0, 16)

        -- Icon
        local warnIcon = Instance.new("TextLabel", warnCard)
        warnIcon.Text                  = "⚠"
        warnIcon.Size                  = UDim2.new(0, 40, 0, 40)
        warnIcon.Position              = UDim2.new(0.5, -20, 0, 16)
        warnIcon.BackgroundTransparency = 1
        warnIcon.TextColor3            = CONFIG.DANGER
        warnIcon.TextSize              = 28
        warnIcon.Font                  = Enum.Font.GothamBold
        warnIcon.ZIndex                = 112

        -- Message text (English by default)
        local MSG_EN = "The script isn't working for Phantom Ball\nright now; it's only working for Anime Ball.\nWe'll fix it soon."
        local MSG_PT = "O script não está funcionando para o\nPhantom Ball agora; só está funcionando\npara o Anime Ball. Vamos corrigir em breve."
        local langPT = false

        local warnText = Instance.new("TextLabel", warnCard)
        warnText.Text                  = MSG_EN
        warnText.Size                  = UDim2.new(1, -28, 0, 70)
        warnText.Position              = UDim2.new(0, 14, 0, 62)
        warnText.BackgroundTransparency = 1
        warnText.TextColor3            = CONFIG.TEXT_PRIMARY
        warnText.TextSize              = 12
        warnText.Font                  = Enum.Font.Gotham
        warnText.TextXAlignment        = Enum.TextXAlignment.Center
        warnText.TextWrapped           = true
        warnText.ZIndex                = 112

        -- ── Language toggle ──────────────────────────
        local langContainer = Instance.new("Frame", warnCard)
        langContainer.Size             = UDim2.new(1, -28, 0, 32)
        langContainer.Position         = UDim2.new(0, 14, 0, 140)
        langContainer.BackgroundColor3 = CONFIG.BG_PANEL
        langContainer.BorderSizePixel  = 0
        langContainer.ZIndex           = 112
        Instance.new("UICorner", langContainer).CornerRadius = UDim.new(0, 8)
        local langContStroke = Instance.new("UIStroke", langContainer)
        langContStroke.Color     = CONFIG.BORDER_COLOR
        langContStroke.Thickness = 1

        local langLabel = Instance.new("TextLabel", langContainer)
        langLabel.Text                  = "🇧🇷  Português"
        langLabel.Size                  = UDim2.new(1, -70, 1, 0)
        langLabel.Position              = UDim2.new(0, 12, 0, 0)
        langLabel.BackgroundTransparency = 1
        langLabel.TextColor3            = CONFIG.TEXT_SECONDARY
        langLabel.TextSize              = 11
        langLabel.Font                  = Enum.Font.GothamSemibold
        langLabel.TextXAlignment        = Enum.TextXAlignment.Left
        langLabel.ZIndex                = 113

        local langTrack = Instance.new("Frame", langContainer)
        langTrack.Size             = UDim2.new(0, 38, 0, 20)
        langTrack.Position         = UDim2.new(1, -48, 0.5, -10)
        langTrack.BackgroundColor3 = CONFIG.TOGGLE_OFF
        langTrack.BorderSizePixel  = 0
        langTrack.ZIndex           = 113
        Instance.new("UICorner", langTrack).CornerRadius = UDim.new(1, 0)

        local langThumb = Instance.new("Frame", langTrack)
        langThumb.Size             = UDim2.new(0, 16, 0, 16)
        langThumb.Position         = UDim2.new(0, 2, 0.5, -8)
        langThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        langThumb.BorderSizePixel  = 0
        langThumb.ZIndex           = 114
        Instance.new("UICorner", langThumb).CornerRadius = UDim.new(1, 0)

        local langBusy = false
        local langHitbox = Instance.new("TextButton", langContainer)
        langHitbox.Size                  = UDim2.new(1, 0, 1, 0)
        langHitbox.BackgroundTransparency = 1
        langHitbox.Text                  = ""
        langHitbox.ZIndex                = 115

        langHitbox.MouseButton1Click:Connect(function()
            if langBusy then return end
            langBusy = true
            langPT   = not langPT
            if langPT then
                TweenService:Create(langTrack, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 200, 100)}):Play()
                TweenService:Create(langThumb, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    {Position = UDim2.new(0, 20, 0.5, -8)}):Play()
                warnText.Text = MSG_PT
            else
                TweenService:Create(langTrack, TweenInfo.new(0.2), {BackgroundColor3 = CONFIG.TOGGLE_OFF}):Play()
                TweenService:Create(langThumb, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    {Position = UDim2.new(0, 2, 0.5, -8)}):Play()
                warnText.Text = MSG_EN
            end
            task.delay(0.25, function() langBusy = false end)
        end)

        -- ── Buttons row ──────────────────────────────
        local ANIME_PLACE_ID = "5120885191"

        local enterBtn = Instance.new("TextButton", warnCard)
        enterBtn.Size             = UDim2.new(0, 158, 0, 36)
        enterBtn.Position         = UDim2.new(0, 14, 0, 190)
        enterBtn.BackgroundColor3 = Color3.fromRGB(251, 146, 60)
        enterBtn.BorderSizePixel  = 0
        enterBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        enterBtn.TextSize         = 12
        enterBtn.Font             = Enum.Font.GothamBold
        enterBtn.Text             = "Enter Anime Ball 🏮"
        enterBtn.ZIndex           = 112
        Instance.new("UICorner", enterBtn).CornerRadius = UDim.new(0, 10)

        local cancelBtn = Instance.new("TextButton", warnCard)
        cancelBtn.Size             = UDim2.new(0, 158, 0, 36)
        cancelBtn.Position         = UDim2.new(0, 188, 0, 190)
        cancelBtn.BackgroundColor3 = CONFIG.BG_PANEL
        cancelBtn.BorderSizePixel  = 0
        cancelBtn.TextColor3       = CONFIG.TEXT_SECONDARY
        cancelBtn.TextSize         = 12
        cancelBtn.Font             = Enum.Font.GothamSemibold
        cancelBtn.Text             = "Cancel"
        cancelBtn.ZIndex           = 112
        Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 10)
        local cancelStroke = Instance.new("UIStroke", cancelBtn)
        cancelStroke.Color     = CONFIG.BORDER_COLOR
        cancelStroke.Thickness = 1

        -- Button hover effects
        enterBtn.MouseEnter:Connect(function()
            TweenService:Create(enterBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 165, 80)}):Play()
        end)
        enterBtn.MouseLeave:Connect(function()
            TweenService:Create(enterBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(251, 146, 60)}):Play()
        end)
        cancelBtn.MouseEnter:Connect(function()
            TweenService:Create(cancelBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 40, 60)}):Play()
        end)
        cancelBtn.MouseLeave:Connect(function()
            TweenService:Create(cancelBtn, TweenInfo.new(0.12), {BackgroundColor3 = CONFIG.BG_PANEL}):Play()
        end)

        -- "Enter Anime Ball" → teleport to Anime Ball via PlaceId
        enterBtn.MouseButton1Click:Connect(function()
            enterBtn.Text    = "Joining..."
            enterBtn.Active  = false
            cancelBtn.Active = false
            TweenService:Create(warnCard, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
                {Position = UDim2.new(0.5, -180, 0.6, -140), BackgroundTransparency = 1}):Play()
            task.delay(0.35, function()
                game:GetService("TeleportService"):Teleport(tonumber(ANIME_PLACE_ID), LocalPlayer)
            end)
        end)

        -- "Cancel" → close everything without loading script
        cancelBtn.MouseButton1Click:Connect(function()
            TweenService:Create(loadFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {BackgroundTransparency = 1}):Play()
            TweenService:Create(warnCard, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
                {Position = UDim2.new(0.5, -180, 0.6, -140), BackgroundTransparency = 1}):Play()
            task.delay(0.5, function() LoadGui:Destroy() end)
        end)

        -- Entrance animation
        warnCard.Position = UDim2.new(0.5, -180, 0.4, -140)
        warnCard.BackgroundTransparency = 1
        TweenService:Create(warnCard, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, -180, 0.5, -140), BackgroundTransparency = 0}):Play()

        -- Script does NOT continue — no _guiReady fired
        return
    elseif gameMode == "anime" then
        loadBadge.BackgroundTransparency = 0
        local stroke = Instance.new("UIStroke", loadBadge)
        stroke.Color = Color3.fromRGB(251, 146, 60); stroke.Thickness = 1
        loadBadgeLabel.Text       = "✔  Anime Ball detected"
        loadBadgeLabel.TextColor3 = Color3.fromRGB(251, 146, 60)
    else
        -- Unsupported game: shows error and exits without loading the GUI
        loadBadge.BackgroundTransparency = 0
        local stroke = Instance.new("UIStroke", loadBadge)
        stroke.Color = CONFIG.DANGER; stroke.Thickness = 1
        loadBadgeLabel.Text       = "✖  Unsupported game"
        loadBadgeLabel.TextColor3 = CONFIG.DANGER

        setLoadProgress(1, "✖  Script not loaded.")
        loadStatus.TextColor3 = CONFIG.DANGER

        -- Pulses the card red to indicate error
        TweenService:Create(loadCardStroke, TweenInfo.new(0.3), {Color = CONFIG.DANGER}):Play()
        TweenService:Create(loadIcon,       TweenInfo.new(0.3), {TextColor3 = CONFIG.DANGER}):Play()

        task.wait(3)

        -- Closes loading and destroys everything without loading the GUI
        TweenService:Create(loadFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}):Play()
        TweenService:Create(loadCard, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -150, 0.6, -110), BackgroundTransparency = 1}):Play()
        task.wait(0.55)
        LoadGui:Destroy()
        -- Does NOT fire _guiReady — script stops here
        return
    end

    setLoadProgress(1, "✔  Ready!")
    task.wait(0.8)
    closeLoading()

    -- Signal: GUI can now be built
    _guiReady:Fire()
end)

-- Wait for detection to finish before building GUI (blocks this coroutine)
_guiReady.Event:Wait()
_guiReady:Destroy()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = CONFIG.GUI_NAME
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset  = true
ScreenGui.Parent          = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════
--              MAIN WINDOW
-- ══════════════════════════════════════════
local MainFrame = Instance.new("Frame")
MainFrame.Name               = "MainFrame"
MainFrame.Size               = UDim2.new(0, 440, 0, 320)
MainFrame.Position           = UDim2.new(0.5, -220, 0.5, -160)
MainFrame.BackgroundColor3   = CONFIG.BG_DARK
MainFrame.BorderSizePixel    = 0
MainFrame.ClipsDescendants   = true
MainFrame.Parent             = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color     = CONFIG.BORDER_COLOR
mainStroke.Thickness = 1.5

-- Background glow
local glowBg = Instance.new("Frame", MainFrame)
glowBg.Size                   = UDim2.new(1,0,1,0)
glowBg.BackgroundTransparency = 1
glowBg.ZIndex                 = 0

local glowGrad = Instance.new("UIGradient", glowBg)
glowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   CONFIG.ACCENT_COLOR),
    ColorSequenceKeypoint.new(0.5, CONFIG.BG_DARK),
    ColorSequenceKeypoint.new(1,   CONFIG.BG_DARK),
})
glowGrad.Rotation    = 135
glowGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.92),
    NumberSequenceKeypoint.new(0.4, 1),
    NumberSequenceKeypoint.new(1,   1),
})

-- Modern diagonal gradient on main background
local mainGradFrame = Instance.new("Frame", MainFrame)
mainGradFrame.Name                   = "MainGradFrame"
mainGradFrame.Size                   = UDim2.new(1, 0, 1, 0)
mainGradFrame.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
mainGradFrame.BackgroundTransparency = 1
mainGradFrame.BorderSizePixel        = 0
mainGradFrame.ZIndex                 = 0

local mainGradient = Instance.new("UIGradient", mainGradFrame)
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    CONFIG.ACCENT_GLOW),
    ColorSequenceKeypoint.new(0.35, CONFIG.ACCENT_COLOR),
    ColorSequenceKeypoint.new(0.65, CONFIG.BG_MID),
    ColorSequenceKeypoint.new(1,    CONFIG.BG_DARK),
})
mainGradient.Rotation = 145
mainGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.82),
    NumberSequenceKeypoint.new(0.3, 0.93),
    NumberSequenceKeypoint.new(0.6, 0.97),
    NumberSequenceKeypoint.new(1,   1),
})

-- ── Barra de Título ───────────────────────
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Name             = "TitleBar"
TitleBar.Size             = UDim2.new(1, 0, 0, 48)
TitleBar.BackgroundColor3 = CONFIG.BG_MID
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 2
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)

-- Corrigir arredondamento inferior do título
local titleFix = Instance.new("Frame", TitleBar)
titleFix.Size             = UDim2.new(1, 0, 0, 14)
titleFix.Position         = UDim2.new(0, 0, 1, -14)
titleFix.BackgroundColor3 = CONFIG.BG_MID
titleFix.BorderSizePixel  = 0
titleFix.ZIndex           = 2

-- Linha accent
local accentLine = Instance.new("Frame", TitleBar)
accentLine.Size             = UDim2.new(0, 60, 0, 3)
accentLine.Position         = UDim2.new(0, 16, 0, 0)
accentLine.BackgroundColor3 = CONFIG.ACCENT_COLOR
accentLine.BorderSizePixel  = 0
accentLine.ZIndex           = 3
Instance.new("UICorner", accentLine).CornerRadius = UDim.new(0, 2)
Instance.new("UIGradient", accentLine).Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, CONFIG.ACCENT_COLOR),
    ColorSequenceKeypoint.new(1, CONFIG.ACCENT_GLOW),
})

-- Logo dot
local logoDot = Instance.new("Frame", TitleBar)
logoDot.Size             = UDim2.new(0, 10, 0, 10)
logoDot.Position         = UDim2.new(0, 16, 0.5, -5)
logoDot.BackgroundColor3 = CONFIG.ACCENT_COLOR
logoDot.BorderSizePixel  = 0
logoDot.ZIndex           = 3
Instance.new("UICorner", logoDot).CornerRadius = UDim.new(1, 0)

-- Title texto
local titleLabel = Instance.new("TextLabel", TitleBar)
titleLabel.Text                  = "NEXUS HUB"
titleLabel.Size                  = UDim2.new(0, 200, 1, 0)
titleLabel.Position              = UDim2.new(0, 34, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3            = CONFIG.TEXT_PRIMARY
titleLabel.TextSize              = 15
titleLabel.Font                  = Enum.Font.GothamBold
titleLabel.TextXAlignment        = Enum.TextXAlignment.Left
titleLabel.ZIndex                = 3

local subLabel = Instance.new("TextLabel", TitleBar)
subLabel.Text                  = "v2.0  ·  Professional"
subLabel.Size                  = UDim2.new(0, 200, 0, 14)
subLabel.Position              = UDim2.new(0, 34, 0.5, 4)
subLabel.BackgroundTransparency = 1
subLabel.TextColor3            = CONFIG.TEXT_SECONDARY
subLabel.TextSize              = 10
subLabel.Font                  = Enum.Font.Gotham
subLabel.TextXAlignment        = Enum.TextXAlignment.Left
subLabel.ZIndex                = 3

-- Botão Fechar
local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Text                  = "✕"
CloseBtn.Size                  = UDim2.new(0, 30, 0, 30)
CloseBtn.Position              = UDim2.new(1, -40, 0.5, -15)
CloseBtn.BackgroundColor3      = Color3.fromRGB(239, 68, 68)
CloseBtn.BackgroundTransparency = 0.3
CloseBtn.TextColor3            = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize              = 12
CloseBtn.Font                  = Enum.Font.GothamBold
CloseBtn.BorderSizePixel       = 0
CloseBtn.ZIndex                = 4
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

-- ── Barra de Tabs ─────────────────────────
local TabBar = Instance.new("Frame", MainFrame)
TabBar.Name             = "TabBar"
TabBar.Size             = UDim2.new(1, 0, 0, 40)
TabBar.Position         = UDim2.new(0, 0, 0, 48)
TabBar.BackgroundColor3 = CONFIG.BG_MID
TabBar.BorderSizePixel  = 0
TabBar.ZIndex           = 2

local tabBarStroke = Instance.new("UIStroke", TabBar)
tabBarStroke.Color     = CONFIG.BORDER_COLOR
tabBarStroke.Thickness = 1

local tabLayout = Instance.new("UIListLayout", TabBar)
tabLayout.FillDirection       = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
tabLayout.Padding             = UDim.new(0, 4)

local tabPadding = Instance.new("UIPadding", TabBar)
tabPadding.PaddingLeft  = UDim.new(0, 8)
tabPadding.PaddingRight = UDim.new(0, 8)

-- ── Área de Conteúdo ──────────────────────
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Name                  = "ContentArea"
ContentArea.Size                  = UDim2.new(1, 0, 1, -88)
ContentArea.Position              = UDim2.new(0, 0, 0, 88)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants      = true
ContentArea.ZIndex                = 2

-- ── Botão Flutuante ───────────────────────
local FloatBtn = Instance.new("TextButton", ScreenGui)
FloatBtn.Text             = "⚔"
FloatBtn.Size             = UDim2.new(0, 44, 0, 44)
FloatBtn.Position         = UDim2.new(0, 20, 0.5, -22)
FloatBtn.BackgroundColor3 = CONFIG.ACCENT_COLOR
FloatBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
FloatBtn.TextSize         = 18
FloatBtn.Font             = Enum.Font.GothamBold
FloatBtn.BorderSizePixel  = 0
FloatBtn.Visible          = false
FloatBtn.ZIndex           = 10
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 12)

task.spawn(function()
    while true do
        TweenService:Create(FloatBtn, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = CONFIG.ACCENT_GLOW}):Play()
        task.wait(0.8)
        TweenService:Create(FloatBtn, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = CONFIG.ACCENT_COLOR}):Play()
        task.wait(0.8)
    end
end)

-- ══════════════════════════════════════════
--          SISTEMA DE ARRASTAR
-- ══════════════════════════════════════════
local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                         input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

makeDraggable(MainFrame, TitleBar)
makeDraggable(FloatBtn,  FloatBtn)

-- ══════════════════════════════════════════
--         ABRIR / FECHAR
-- ══════════════════════════════════════════
local function closeGUI()
    State.guiOpen = false
    TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size     = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(MainFrame.Position.X.Scale, MainFrame.Position.X.Offset + 220,
                             MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset + 160),
    }):Play()
    task.delay(0.35, function()
        MainFrame.Visible = false
        FloatBtn.Visible  = true
    end)
end

local function openGUI()
    State.guiOpen     = true
    FloatBtn.Visible  = false
    MainFrame.Visible = true
    MainFrame.Size    = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(0.5, -220, 0.5, -160)
    TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 440, 0, 320)
    }):Play()
end

CloseBtn.MouseButton1Click:Connect(closeGUI)
FloatBtn.MouseButton1Click:Connect(openGUI)
CloseBtn.MouseEnter:Connect(function() TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
CloseBtn.MouseLeave:Connect(function() TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.3}):Play() end)

-- ══════════════════════════════════════════
--           SISTEMA DE TABS
-- ══════════════════════════════════════════
local Tabs     = {}
local TabPages = {}

-- Declarado antes de createTab pra ser referenciável dentro dele
local function selectTab(name)
    State.currentTab = name
    for tabName, tabData in pairs(Tabs) do
        if tabName == name then
            TweenService:Create(tabData.button, TweenInfo.new(0.2), {
                TextColor3             = CONFIG.TEXT_PRIMARY,
                BackgroundColor3       = CONFIG.ACCENT_COLOR,
                BackgroundTransparency = 0.85,
            }):Play()
            TweenService:Create(tabData.indicator, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
            tabData.page.Visible = true
        else
            TweenService:Create(tabData.button, TweenInfo.new(0.2), {
                TextColor3             = CONFIG.TEXT_SECONDARY,
                BackgroundTransparency = 1,
            }):Play()
            TweenService:Create(tabData.indicator, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
            tabData.page.Visible = false
        end
    end
end

local function createTab(name, icon)
    local tab = Instance.new("TextButton", TabBar)
    tab.Text                  = (icon and (icon .. "  ") or "") .. name
    tab.Size                  = UDim2.new(0, 80, 0, 30)
    tab.BackgroundColor3      = CONFIG.BG_DARK
    tab.BackgroundTransparency = 1
    tab.TextColor3            = CONFIG.TEXT_SECONDARY
    tab.TextSize              = 12
    tab.Font                  = Enum.Font.GothamSemibold
    tab.BorderSizePixel       = 0
    tab.ZIndex                = 3
    Instance.new("UICorner", tab).CornerRadius = UDim.new(0, 8)

    local indicator = Instance.new("Frame", tab)
    indicator.Name                  = "Indicator"
    indicator.Size                  = UDim2.new(0.7, 0, 0, 2)
    indicator.Position              = UDim2.new(0.15, 0, 1, -2)
    indicator.BackgroundColor3      = CONFIG.ACCENT_COLOR
    indicator.BorderSizePixel       = 0
    indicator.BackgroundTransparency = 1
    indicator.ZIndex                = 4
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    local page = Instance.new("ScrollingFrame", ContentArea)
    page.Name                  = name .. "Page"
    page.Size                  = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel       = 0
    page.ScrollBarThickness    = 4
    page.ScrollBarImageColor3  = CONFIG.ACCENT_COLOR
    page.Visible               = false
    page.ZIndex                = 2

    local layout = Instance.new("UIListLayout", page)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding       = UDim.new(0, 8)

    local pad = Instance.new("UIPadding", page)
    pad.PaddingLeft   = UDim.new(0, 14)
    pad.PaddingRight  = UDim.new(0, 14)
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    Tabs[name]     = {button = tab, indicator = indicator, page = page}
    TabPages[name] = page
    tab.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

-- ══════════════════════════════════════════
--         UI COMPONENTS
-- ══════════════════════════════════════════
local function createToggle(parent, labelText, description, onToggle)
    local container = Instance.new("Frame", parent)
    container.Size             = UDim2.new(1, 0, 0, 60)
    container.BackgroundColor3 = CONFIG.BG_PANEL
    container.BorderSizePixel  = 0
    container.ZIndex           = 3
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", container)
    stroke.Color     = CONFIG.BORDER_COLOR
    stroke.Thickness = 1

    local lbl = Instance.new("TextLabel", container)
    lbl.Text                  = labelText
    lbl.Size                  = UDim2.new(1, -80, 0, 22)
    lbl.Position              = UDim2.new(0, 14, 0, 10)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3            = CONFIG.TEXT_PRIMARY
    lbl.TextSize              = 13
    lbl.Font                  = Enum.Font.GothamSemibold
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.ZIndex                = 4

    local desc = Instance.new("TextLabel", container)
    desc.Text                  = description or ""
    desc.Size                  = UDim2.new(1, -80, 0, 16)
    desc.Position              = UDim2.new(0, 14, 0, 33)
    desc.BackgroundTransparency = 1
    desc.TextColor3            = CONFIG.TEXT_SECONDARY
    desc.TextSize              = 10
    desc.Font                  = Enum.Font.Gotham
    desc.TextXAlignment        = Enum.TextXAlignment.Left
    desc.ZIndex                = 4

    local track = Instance.new("Frame", container)
    track.Size             = UDim2.new(0, 48, 0, 26)
    track.Position         = UDim2.new(1, -62, 0.5, -13)
    track.BackgroundColor3 = CONFIG.TOGGLE_OFF
    track.BorderSizePixel  = 0
    track.ZIndex           = 4
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame", track)
    thumb.Size             = UDim2.new(0, 20, 0, 20)
    thumb.Position         = UDim2.new(0, 3, 0.5, -10)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel  = 0
    thumb.ZIndex           = 5
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local toggleState = false
    local busy        = false

    local hitbox = Instance.new("TextButton", container)
    hitbox.Size                  = UDim2.new(1, 0, 1, 0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text                  = ""
    hitbox.ZIndex                = 6

    hitbox.MouseButton1Click:Connect(function()
        if busy then return end
        busy        = true
        toggleState = not toggleState
        if toggleState then
            TweenService:Create(track, TweenInfo.new(0.25), {BackgroundColor3 = CONFIG.TOGGLE_ON}):Play()
            TweenService:Create(thumb, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Position = UDim2.new(0, 25, 0.5, -10)}):Play()
        else
            TweenService:Create(track, TweenInfo.new(0.25), {BackgroundColor3 = CONFIG.TOGGLE_OFF}):Play()
            TweenService:Create(thumb, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Position = UDim2.new(0, 3, 0.5, -10)}):Play()
        end
        task.delay(0.25, function()
            busy = false
            if onToggle then onToggle(toggleState) end
        end)
    end)

    hitbox.MouseEnter:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26,26,46)}):Play()
        TweenService:Create(stroke,    TweenInfo.new(0.15), {Color = CONFIG.ACCENT_COLOR}):Play()
    end)
    hitbox.MouseLeave:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.15), {BackgroundColor3 = CONFIG.BG_PANEL}):Play()
        TweenService:Create(stroke,    TweenInfo.new(0.15), {Color = CONFIG.BORDER_COLOR}):Play()
    end)

    return container
end

local function createStatusLabel(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Text                  = text or ""
    lbl.Size                  = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3            = CONFIG.TEXT_SECONDARY
    lbl.TextSize              = 11
    lbl.Font                  = Enum.Font.Gotham
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.ZIndex                = 3
    return lbl
end

local function createSeparator(parent)
    local sep = Instance.new("Frame", parent)
    sep.Size             = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = CONFIG.BORDER_COLOR
    sep.BorderSizePixel  = 0
    sep.ZIndex           = 3
    local g = Instance.new("UIGradient", sep)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,0,0)),
        ColorSequenceKeypoint.new(0.5, CONFIG.BORDER_COLOR),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,0,0)),
    })
end

-- ══════════════════════════════════════════
--         COMBAT TAB
-- ══════════════════════════════════════════
local CombatPage = createTab("Combat", "⚔")

local combatHeader = Instance.new("TextLabel", CombatPage)
combatHeader.Text                  = "COMBAT MODULES"
combatHeader.Size                  = UDim2.new(1, 0, 0, 18)
combatHeader.BackgroundTransparency = 1
combatHeader.TextColor3            = CONFIG.ACCENT_COLOR
combatHeader.TextSize              = 10
combatHeader.Font                  = Enum.Font.GothamBold
combatHeader.TextXAlignment        = Enum.TextXAlignment.Left
combatHeader.ZIndex                = 3

createSeparator(CombatPage)

local detectorStatus = createStatusLabel(CombatPage, "◉  Auto Parry: Inactive")
local distInfo       = createStatusLabel(CombatPage, "")

-- ── Dropdown: Parry Mode ────────────────
local dropdownContainer = Instance.new("Frame", CombatPage)
dropdownContainer.Size             = UDim2.new(1, 0, 0, 54)
dropdownContainer.BackgroundColor3 = CONFIG.BG_PANEL
dropdownContainer.BorderSizePixel  = 0
dropdownContainer.ZIndex           = 10
Instance.new("UICorner", dropdownContainer).CornerRadius = UDim.new(0, 10)
local dropStroke = Instance.new("UIStroke", dropdownContainer)
dropStroke.Color = CONFIG.BORDER_COLOR; dropStroke.Thickness = 1

local dropLabel = Instance.new("TextLabel", dropdownContainer)
dropLabel.Text = "Parry Mode"
dropLabel.Size = UDim2.new(1, -14, 0, 18)
dropLabel.Position = UDim2.new(0, 14, 0, 6)
dropLabel.BackgroundTransparency = 1
dropLabel.TextColor3 = CONFIG.TEXT_SECONDARY
dropLabel.TextSize = 10; dropLabel.Font = Enum.Font.Gotham
dropLabel.TextXAlignment = Enum.TextXAlignment.Left
dropLabel.ZIndex = 11

-- Dropdown button
local dropBtn = Instance.new("TextButton", dropdownContainer)
dropBtn.Size             = UDim2.new(1, -28, 0, 24)
dropBtn.Position         = UDim2.new(0, 14, 0, 24)
dropBtn.BackgroundColor3 = CONFIG.BG_MID
dropBtn.BorderSizePixel  = 0
dropBtn.TextColor3       = CONFIG.TEXT_PRIMARY
dropBtn.TextSize         = 11
dropBtn.Font             = Enum.Font.GothamSemibold
dropBtn.Text             = "🔵  Remote Event (original)"
dropBtn.TextXAlignment   = Enum.TextXAlignment.Left
dropBtn.ZIndex           = 11
Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 6)
local dropBtnStroke = Instance.new("UIStroke", dropBtn)
dropBtnStroke.Color = CONFIG.BORDER_COLOR; dropBtnStroke.Thickness = 1

-- Inner button padding
local dropBtnPad = Instance.new("UIPadding", dropBtn)
dropBtnPad.PaddingLeft = UDim.new(0, 8)

-- Arrow icon
local dropArrow = Instance.new("TextLabel", dropBtn)
dropArrow.Text = "▾"
dropArrow.Size = UDim2.new(0, 20, 1, 0)
dropArrow.Position = UDim2.new(1, -24, 0, 0)
dropArrow.BackgroundTransparency = 1
dropArrow.TextColor3 = CONFIG.TEXT_SECONDARY
dropArrow.TextSize = 12; dropArrow.Font = Enum.Font.GothamBold
dropArrow.ZIndex = 12

-- Options menu (appears on top)
local dropMenu = Instance.new("Frame", ScreenGui)
dropMenu.Size             = UDim2.new(0, 0, 0, 0)
dropMenu.BackgroundColor3 = CONFIG.BG_MID
dropMenu.BorderSizePixel  = 0
dropMenu.Visible          = false
dropMenu.ZIndex           = 100
Instance.new("UICorner", dropMenu).CornerRadius = UDim.new(0, 8)
local dropMenuStroke = Instance.new("UIStroke", dropMenu)
dropMenuStroke.Color = CONFIG.ACCENT_COLOR; dropMenuStroke.Thickness = 1

local dropMenuLayout = Instance.new("UIListLayout", dropMenu)
dropMenuLayout.FillDirection = Enum.FillDirection.Vertical
dropMenuLayout.Padding = UDim.new(0, 2)
local dropMenuPad = Instance.new("UIPadding", dropMenu)
dropMenuPad.PaddingLeft = UDim.new(0, 4); dropMenuPad.PaddingRight = UDim.new(0, 4)
dropMenuPad.PaddingTop = UDim.new(0, 4); dropMenuPad.PaddingBottom = UDim.new(0, 4)

local OPTIONS = {
    { label = "🔵  Remote Event (original)", mode = "remote",       games = {"phantom", nil} },
    { label = "🟢  Button (Phantom)",        mode = "button",       games = {"phantom", nil} },
    { label = "🟠  Button (Anime Ball)",     mode = "anime_button", games = {"anime"} },
}

local dropOpen = false

local function closeDropMenu()
    dropOpen = false
    TweenService:Create(dropMenu, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, dropMenu.Size.X.Offset, 0, 0)
    }):Play()
    task.delay(0.15, function() dropMenu.Visible = false end)
    TweenService:Create(dropArrow, TweenInfo.new(0.15), {Rotation = 0}):Play()
end

local function selectOption(opt)
    State.parryMode = opt.mode
    dropBtn.Text    = opt.label
    TweenService:Create(dropBtnStroke, TweenInfo.new(0.2), {Color = CONFIG.ACCENT_COLOR}):Play()
    task.delay(0.4, function()
        TweenService:Create(dropBtnStroke, TweenInfo.new(0.3), {Color = CONFIG.BORDER_COLOR}):Play()
    end)
    closeDropMenu()
end

-- Create menu items (filtered by detected game)
for _, opt in ipairs(OPTIONS) do
    -- Filter options: "anime_button" only in Anime Ball; "remote"/"button" only in Phantom/unknown
    local show = true
    if opt.mode == "anime_button" and DETECTED_GAME ~= "anime" then show = false end
    if (opt.mode == "remote" or opt.mode == "button") and DETECTED_GAME == "anime" then show = false end
    if not show then continue end

    local item = Instance.new("TextButton", dropMenu)
    item.Size             = UDim2.new(1, 0, 0, 28)
    item.BackgroundColor3 = CONFIG.BG_PANEL
    item.BackgroundTransparency = 0.3
    item.BorderSizePixel  = 0
    item.TextColor3       = CONFIG.TEXT_PRIMARY
    item.TextSize         = 11
    item.Font             = Enum.Font.GothamSemibold
    item.Text             = opt.label
    item.TextXAlignment   = Enum.TextXAlignment.Left
    item.ZIndex           = 101
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
    local itemPad = Instance.new("UIPadding", item)
    itemPad.PaddingLeft = UDim.new(0, 8)

    local capturedOpt = opt
    item.MouseButton1Click:Connect(function() selectOption(capturedOpt) end)
    item.MouseEnter:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.ACCENT_COLOR, BackgroundTransparency = 0.7}):Play()
    end)
    item.MouseLeave:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.BG_PANEL, BackgroundTransparency = 0.3}):Play()
    end)
end

-- Auto-configure mode (DETECTED_GAME already set before GUI is built)
if DETECTED_GAME == "anime" then
    State.parryMode = "anime_button"
    dropBtn.Text    = "🟠  Button (Anime Ball)"
elseif DETECTED_GAME == "phantom" then
    State.parryMode = "remote"
    dropBtn.Text    = "🔵  Remote Event (original)"
end

dropBtn.MouseButton1Click:Connect(function()
    dropOpen = not dropOpen
    if dropOpen then
        -- Posiciona o menu abaixo do botão no ScreenGui
        local absPos = dropBtn.AbsolutePosition
        local absSize = dropBtn.AbsoluteSize
        local menuW = absSize.X + 28
        local menuH = #OPTIONS * 30 + 8
        dropMenu.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
        dropMenu.Size     = UDim2.new(0, menuW, 0, 0)
        dropMenu.Visible  = true
        TweenService:Create(dropMenu, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, menuW, 0, menuH)
        }):Play()
        TweenService:Create(dropArrow, TweenInfo.new(0.15), {Rotation = 180}):Play()
    else
        closeDropMenu()
    end
end)

-- Close menu on outside click
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and dropOpen then
        task.wait()
        if dropOpen then closeDropMenu() end
    end
end)

-- ══════════════════════════════════════════
--         AUTO PARRY SYSTEM
-- ══════════════════════════════════════════
local lastBallCFrame = nil
local trackedSpeed   = 0

-- Optimizer: deletes and recreates the remote event to clear pending callbacks in the queue
local function optimizeRemote()
    if not State.optimizer then return end
    pcall(function()
        local folder = game:GetService("ReplicatedStorage")
            :WaitForChild("TS")
            :WaitForChild("GeneratedNetworkRemotes")
        local re = folder:FindFirstChild("RE_4.6848415795802784e+76")
        if re then
            -- Disconnects all local OnClientEvent listeners
            -- (clears the pending callback queue on the client)
            re.OnClientEvent:Connect(function() end) -- sobrescreve com handler vazio
            -- Reconnects immediately to prevent queue buildup
        end
    end)
end

-- Unified parry function (used by Auto Parry and Auto Spam)
local function executeParry()
    if State.parryMode == "button" then
        -- Button Mode (Phantom Ball): ImageButton BLOCK
        pcall(function()
            local btn = game:GetService("Players").LocalPlayer
                .PlayerGui.Interface.MobileUI.Buttons.Jump.BLOCK.Button
            if not btn or not btn:IsA("ImageButton") then
                detectorStatus.Text = "◉  Error: BLOCK.Button is not ImageButton"
                return
            end
            btn:FireServer("MouseButton1Down")
            btn:FireServer("MouseButton1Up")
        end)
        State.parryCount = State.parryCount + 1

    elseif State.parryMode == "anime_button" then
        -- Anime Ball: uses getconnections like the reference script
        pcall(function()
            local btn = LocalPlayer.PlayerGui:FindFirstChild("HUD")
            if not btn then return end
            btn = btn:FindFirstChild("MobileSmall")
            if not btn then return end
            btn = btn:FindFirstChild("Block")
            if not btn then return end
            btn = btn:FindFirstChild("Detection")
            if not btn then return end
            if not btn:IsA("TextButton") then
                detectorStatus.Text = "◉  Error: Detection is not TextButton"
                return
            end
            for _, conn in pairs(getconnections(btn.MouseButton1Down)) do
                conn:Fire()
            end
            task.wait(0.01)
            for _, conn in pairs(getconnections(btn.MouseButton1Up)) do
                conn:Fire()
            end
        end)
        State.parryCount = State.parryCount + 1

    else
        -- Remote Event Mode
        local ok, err = pcall(function()
            local args = {
                buffer.fromstring("\001")
            }
            game:GetService("ReplicatedStorage")
                :WaitForChild("Remotes")
                :WaitForChild("RemoteEvent")
                :FireServer(unpack(args))
        end)
        if ok then
            State.parryCount = State.parryCount + 1
            optimizeRemote()
        else
            detectorStatus.Text = "◉  Error: " .. tostring(err):sub(1, 40)
            return
        end
    end
    TweenService:Create(detectorStatus, TweenInfo.new(0.1), {TextColor3 = CONFIG.SUCCESS}):Play()
    detectorStatus.Text = "◉  Parry EXECUTED!"
    task.delay(1.5, function()
        if State.autoParry then
            TweenService:Create(detectorStatus, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
            detectorStatus.Text = "◉  Auto Parry: Monitoring..."
        end
    end)
end

local function createDetector()
    if State.detectorPart then State.detectorPart:Destroy() end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local d = Instance.new("Part")
    d.Name         = "AutoParryDetector"
    d.Size         = Vector3.new(CONFIG.PARRY_DIST * 2, CONFIG.PARRY_DIST * 2, CONFIG.PARRY_DIST * 2)
    d.Shape        = Enum.PartType.Ball
    d.Anchored     = true
    d.CanCollide   = false
    d.Transparency = State.showDetectors and 0.6 or 1
    d.BrickColor   = BrickColor.new("Dark blue")
    d.Material     = Enum.Material.ForceField
    d.CFrame       = CFrame.new(hrp.CFrame.Position)
    d.Parent       = workspace
    State.detectorPart = d
end

local function destroyDetector()
    if State.detectorPart      then State.detectorPart:Destroy(); State.detectorPart = nil end
    if State.runConnection     then State.runConnection:Disconnect();     State.runConnection     = nil end
    if State.speedDetectorConn then State.speedDetectorConn:Disconnect(); State.speedDetectorConn = nil end
    State.animeTrackedSpeed = 0
    State.lastSpeedCFrame   = nil
end

local function startAutoParry()
    State.autoParry                = true
    State.hasExecutedThisDetection = false
    State.lastBallColor            = nil
    lastBallCFrame                 = nil
    trackedSpeed                   = 0
    detectorStatus.Text = "◉  Auto Parry: Monitoring..."
    TweenService:Create(detectorStatus, TweenInfo.new(0.3), {TextColor3 = CONFIG.SUCCESS}):Play()
    createDetector()

    -- ── ANIME BALL MODE ───────────────────────────────────────────────
    if DETECTED_GAME == "anime" then

        -- ── Speed Detector: uses AssemblyLinearVelocity of the ball (real physics velocity) ──
        State.lastSpeedCFrame   = nil
        State.animeTrackedSpeed = 0
        State.speedDetectorConn = RunService.Heartbeat:Connect(function()
            local ballsFolder = workspace:FindFirstChild("Balls")
            if not ballsFolder then
                State.animeTrackedSpeed = 0
                return
            end
            -- Get first BasePart with color different from Medium Stone Grey
            local targetBall = nil
            local closestSpd = math.huge
            for _, obj in pairs(ballsFolder:GetChildren()) do
                local part = obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart") or obj
                if part and part:IsA("BasePart") then
                    local d = (part.Position - Vector3.new(0,0,0)).Magnitude  -- qualquer ref
                    if d < closestSpd then
                        closestSpd  = d
                        targetBall  = part
                    end
                end
            end
            if not targetBall then
                State.animeTrackedSpeed = 0
                return
            end
            -- AssemblyLinearVelocity is the real physical velocity — no delta calculation
            State.animeTrackedSpeed = targetBall.AssemblyLinearVelocity.Magnitude
        end)

        -- ── Parry Loop: uses velocity already calculated by the speed detector ──
        State.runConnection = RunService.Heartbeat:Connect(function()
            if not State.autoParry then return end
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local ballsFolder = workspace:FindFirstChild("Balls")
            if not ballsFolder then
                distInfo.Text  = "  workspace.Balls not found..."
                State.hasExecutedThisDetection = false
                return
            end

            -- Get closest ball to player (supports Model and BasePart)
            local targetBall = nil
            local closestDist = math.huge
            for _, obj in pairs(ballsFolder:GetChildren()) do
                local part = obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart") or obj
                if part and part:IsA("BasePart") then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < closestDist then
                        closestDist = d
                        targetBall  = part
                    end
                end
            end

            if not targetBall then
                distInfo.Text  = "  Waiting for active ball..."
                State.hasExecutedThisDetection = false
                State.ballWasInside            = false
                return
            end

            -- Anime Ball radius: CONFIG.PARRY_DIST + math.floor(velocity / 3.90)
            local velocity = State.animeTrackedSpeed
            local radius = math.clamp(
                CONFIG.PARRY_DIST + math.floor(velocity / 3.90),
                CONFIG.PARRY_DIST,
                300
            )

            -- Update visual detector
            if State.detectorPart then
                State.detectorPart.CFrame = CFrame.new(hrp.CFrame.Position)
                State.detectorPart.Size   = Vector3.new(radius * 2, radius * 2, radius * 2)
                State.detectorPart.Transparency = State.showDetectors and 0.6 or 1
            end

            distInfo.Text = string.format("  Vel: %.1f s/s  |  Radius: %d st  |  Ball: %s",
                velocity, radius, targetBall.Name)

            local dist = closestDist  -- já calculado acima

            if State.ballWasInside and dist > radius then
                State.hasExecutedThisDetection = false
                State.ballWasInside            = false
            end

            -- Fires when: ball touched detector AND LocalPlayer has Highlight in workspace
            local localHighlight = workspace:FindFirstChild(LocalPlayer.Name)
                and workspace:FindFirstChild(LocalPlayer.Name):FindFirstChildWhichIsA("Highlight")
            if dist <= radius and localHighlight then
                State.ballWasInside = true
                if not State.hasExecutedThisDetection then
                    State.hasExecutedThisDetection = true
                    if State.detectorPart and State.showDetectors then
                        State.detectorPart.BrickColor   = BrickColor.new("Bright orange")
                        State.detectorPart.Transparency = 0.25
                        task.delay(0.4, function()
                            if State.detectorPart then
                                State.detectorPart.BrickColor   = BrickColor.new("Dark blue")
                                State.detectorPart.Transparency = 0.6
                            end
                        end)
                    end
                    executeParry()
                end
            else
                State.hasExecutedThisDetection = false
                State.ballWasInside            = false
            end
        end)

    -- ── PHANTOM BALL MODE (default) ────────────────────────────────────
    else
        State.runConnection = RunService.Heartbeat:Connect(function(dt)
            if not State.autoParry then return end
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local ball = workspace:FindFirstChild("GameBall")
            if not ball or not ball:IsA("BasePart") then
                distInfo.Text  = "  GameBall not found..."
                lastBallCFrame = nil
                State.hasExecutedThisDetection = false
                State.lastBallColor            = nil
                return
            end

            local curCF = ball.CFrame
            if lastBallCFrame ~= nil then
                local spd = (curCF.Position - lastBallCFrame.Position).Magnitude / math.max(dt, 1/60)
                trackedSpeed = trackedSpeed + (spd - trackedSpeed) * 0.3
            end
            lastBallCFrame = curCF

            local radius = math.clamp(
                CONFIG.PARRY_DIST + math.floor(trackedSpeed / 4),
                CONFIG.PARRY_DIST,
                300
            )

            if State.detectorPart then
                State.detectorPart.CFrame = CFrame.new(hrp.CFrame.Position)
                State.detectorPart.Size   = Vector3.new(radius * 2, radius * 2, radius * 2)
                State.detectorPart.Transparency = State.showDetectors and 0.6 or 1
            end

            distInfo.Text = string.format("  Vel: %.1f s/s  |  Radius: %d st", trackedSpeed, radius)

            local dist = (hrp.Position - ball.Position).Magnitude

            -- Reset apenas quando a bola SAI do detector (independente da cor)
            if dist > radius then
                State.hasExecutedThisDetection = false
                State.ballWasInside            = false
            end

            -- Cor mudou → reseta execução para permitir novo parry, mas mantém posição
            local curColor = ball.BrickColor
            if State.lastBallColor ~= curColor then
                State.hasExecutedThisDetection = false
                State.lastBallColor            = curColor
            end

            -- Dispara somente quando: bola Bright red + dentro do raio
            if ball.BrickColor == BrickColor.new("Bright red") and dist <= radius then
                State.ballWasInside = true
                if not State.hasExecutedThisDetection then
                    State.hasExecutedThisDetection = true
                    if State.detectorPart and State.showDetectors then
                        State.detectorPart.BrickColor  = BrickColor.new("Bright red")
                        State.detectorPart.Transparency = 0.25
                        task.delay(0.4, function()
                            if State.detectorPart then
                                State.detectorPart.BrickColor  = BrickColor.new("Dark blue")
                                State.detectorPart.Transparency = 0.6
                            end
                        end)
                    end
                    executeParry()
                end
            end
        end)
    end
end

local function stopAutoParry()
    State.autoParry                = false
    State.hasExecutedThisDetection = false
    State.lastBallColor            = nil
    lastBallCFrame                 = nil
    trackedSpeed                   = 0
    destroyDetector()
    detectorStatus.Text = "◉  Auto Parry: Inactive"
    TweenService:Create(detectorStatus, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
    distInfo.Text = ""
end

-- Toggle with direct callback
createToggle(CombatPage, "Auto Parry", "Detects GameBall and executes automatic parry", function(on)
    if on then startAutoParry() else stopAutoParry() end
end)

createSeparator(CombatPage)

-- ── AUTO SPAM ─────────────────────────────
local spamStatus = createStatusLabel(CombatPage, "◉  Auto Spam: Inactive")

local SPAM_DIST = 50  -- raio fixo do detector de spam

local function createSpamDetector()
    if State.spamDetectorPart then State.spamDetectorPart:Destroy() end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local d = Instance.new("Part")
    d.Name         = "AutoSpamDetector"
    d.Size         = Vector3.new(SPAM_DIST * 2, SPAM_DIST * 2, SPAM_DIST * 2)
    d.Shape        = Enum.PartType.Ball
    d.Anchored     = true
    d.CanCollide   = false
    d.Transparency = State.showDetectors and 0.6 or 1
    d.BrickColor   = BrickColor.new("Bright blue")
    d.Material     = Enum.Material.ForceField
    d.CFrame       = CFrame.new(hrp.CFrame.Position)
    d.Parent       = workspace
    State.spamDetectorPart = d
end

local function destroySpamDetector()
    if State.spamDetectorPart then State.spamDetectorPart:Destroy(); State.spamDetectorPart = nil end
    if State.spamConnection    then State.spamConnection:Disconnect();    State.spamConnection    = nil end
    if State.spamLoopConn      then State.spamLoopConn:Disconnect();      State.spamLoopConn      = nil end
    State.spamActive = false
end

local function startSpamLoop()
    if State.spamActive then return end
    State.spamActive = true
    spamStatus.Text  = "◉  Auto Spam: SPAMMING!"
    TweenService:Create(spamStatus, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
    State.spamLoopConn = RunService.Heartbeat:Connect(function()
        if not State.spamActive then return end
        if State.parryMode == "button" then
            pcall(function()
                local btn = game:GetService("Players").LocalPlayer
                    .PlayerGui.Interface.MobileUI.Buttons.Jump.BLOCK.Button
                if not btn or not btn:IsA("ImageButton") then return end
                for i = 1, State.spamMultiplier do
                    btn:FireServer("MouseButton1Down")
                    btn:FireServer("MouseButton1Up")
                    State.spamCount = State.spamCount + 1
                end
            end)
        elseif State.parryMode == "anime_button" then
            pcall(function()
                local btn = LocalPlayer.PlayerGui:FindFirstChild("HUD")
                if not btn then return end
                btn = btn:FindFirstChild("MobileSmall")
                if not btn then return end
                btn = btn:FindFirstChild("Block")
                if not btn then return end
                btn = btn:FindFirstChild("Detection")
                if not btn or not btn:IsA("TextButton") then return end
                for i = 1, State.spamMultiplier do
                    for _, conn in pairs(getconnections(btn.MouseButton1Down)) do conn:Fire() end
                    task.wait(0.01)
                    for _, conn in pairs(getconnections(btn.MouseButton1Up)) do conn:Fire() end
                    State.spamCount = State.spamCount + 1
                end
            end)
        else
            local re = game:GetService("ReplicatedStorage")
                :WaitForChild("Remotes")
                :WaitForChild("RemoteEvent")
            for i = 1, State.spamMultiplier do
                pcall(function()
                    local args = { buffer.fromstring("\001") }
                    re:FireServer(unpack(args))
                end)
                State.spamCount = State.spamCount + 1
            end
            optimizeRemote()
        end
    end)
end

local function stopSpamLoop()
    if not State.spamActive then return end
    State.spamActive = false
    if State.spamLoopConn then State.spamLoopConn:Disconnect(); State.spamLoopConn = nil end
    spamStatus.Text = "◉  Auto Spam: Monitoring..."
    TweenService:Create(spamStatus, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
end

local function startAutoSpam()
    State.autoSpam = true
    spamStatus.Text = "◉  Auto Spam: Monitoring..."
    TweenService:Create(spamStatus, TweenInfo.new(0.3), {TextColor3 = CONFIG.SUCCESS}):Play()
    createSpamDetector()

    -- Saved player name (even after losing highlight)
    local savedTargetName = nil

    State.spamConnection = RunService.Heartbeat:Connect(function()
        if not State.autoSpam then return end

        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Update detector position
        if State.spamDetectorPart then
            State.spamDetectorPart.CFrame = CFrame.new(hrp.CFrame.Position)
            State.spamDetectorPart.Transparency = State.showDetectors and 0.6 or 1
        end

        -- ── ANIME BALL: highlight-based spam ─────────────────────────────
        if DETECTED_GAME == "anime" then
            local ballsFolder = workspace:FindFirstChild("Balls")
            if not ballsFolder then stopSpamLoop(); return end

            -- Get closest ball (supports Model and BasePart)
            local closestBall, closestDist = nil, math.huge
            for _, obj in pairs(ballsFolder:GetChildren()) do
                local part = obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart") or obj
                if part and part:IsA("BasePart") then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < closestDist then
                        closestDist = d
                        closestBall = part
                    end
                end
            end

            if not closestBall then stopSpamLoop(); return end

            local ballInDetector = closestDist <= SPAM_DIST

            -- Check players inside detector with Highlight → save name
            -- When player loses Highlight but is still in detector → keep saved name
            -- When player leaves detector → delete saved name
            for _, player in pairs(Players:GetPlayers()) do
                if player == LocalPlayer then continue end
                local pChar = player.Character
                if not pChar then continue end
                local pHRP = pChar:FindFirstChild("HumanoidRootPart")
                if not pHRP then continue end

                local pDist = (pHRP.Position - hrp.Position).Magnitude

                if pDist <= SPAM_DIST then
                    -- Player inside detector: save name if they have Highlight
                    local hasHighlight = pChar:FindFirstChildWhichIsA("Highlight") ~= nil
                    if hasHighlight then
                        savedTargetName       = player.Name
                        State.savedSpamTarget = player.Name
                    end
                    -- If lost Highlight but still in detector → keep saved name (do not clear)
                else
                    -- Player left detector → clear saved name if it is them
                    if savedTargetName == player.Name then
                        savedTargetName       = nil
                        State.savedSpamTarget = nil
                    end
                end
            end

            -- Me (LocalPlayer) with Highlight + ball in detector + saved target → spam
            local myChar = LocalPlayer.Character
            local myHighlight = myChar and myChar:FindFirstChildWhichIsA("Highlight") ~= nil

            if ballInDetector and myHighlight and savedTargetName ~= nil then
                startSpamLoop()
            else
                stopSpamLoop()
            end

        -- ── PHANTOM BALL: lógica original com highlight ───────────────────
        else
            local ball = workspace:FindFirstChild("GameBall")
            local charsFolder = workspace:FindFirstChild("Characters")

            local ballInDetector = false
            if ball and ball:IsA("BasePart") then
                local ballDist = (hrp.Position - ball.Position).Magnitude
                -- Verifica distância e cor separadamente para não perder frames de transição
                if ballDist <= SPAM_DIST then
                    ballInDetector = ball.BrickColor == BrickColor.new("Bright red")
                end
            end

            if charsFolder then
                for _, player in pairs(Players:GetPlayers()) do
                    if player == LocalPlayer then continue end
                    if player.Name == LocalPlayer.Name then continue end

                    local foundChar = charsFolder:FindFirstChild(player.Name)
                    if not foundChar or foundChar == LocalPlayer.Character then continue end

                    local pHRP = foundChar:FindFirstChild("HumanoidRootPart")
                    if not pHRP then continue end

                    local pDist = (hrp.Position - pHRP.Position).Magnitude

                    if pDist <= SPAM_DIST then
                        local highlight = foundChar:FindFirstChild("PlayerBallHighlight")
                        if highlight then
                            savedTargetName = player.Name
                            State.savedSpamTarget = player.Name
                        end
                    else
                        if savedTargetName == player.Name then
                            savedTargetName = nil
                            State.savedSpamTarget = nil
                        end
                    end
                end
            end

            if ballInDetector and savedTargetName ~= nil then
                startSpamLoop()
            elseif State.spamActive and savedTargetName == nil then
                stopSpamLoop()
            end
        end
    end)
end

local function stopAutoSpam()
    State.autoSpam = false
    stopSpamLoop()
    destroySpamDetector()
    spamStatus.Text = "◉  Auto Spam: Inactive"
    TweenService:Create(spamStatus, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
end

createToggle(CombatPage, "Auto Spam", "Spams parry when detecting player with highlight (35m)", function(on)
    if on then startAutoSpam() else stopAutoSpam() end
end)

-- ── Spam Power Slider ──────────────────
local sliderContainer = Instance.new("Frame", CombatPage)
sliderContainer.Size             = UDim2.new(1, 0, 0, 72)
sliderContainer.BackgroundColor3 = CONFIG.BG_PANEL
sliderContainer.BorderSizePixel  = 0
sliderContainer.ZIndex           = 3
Instance.new("UICorner", sliderContainer).CornerRadius = UDim.new(0, 10)
local sliderStroke = Instance.new("UIStroke", sliderContainer)
sliderStroke.Color = CONFIG.BORDER_COLOR; sliderStroke.Thickness = 1

local sliderTitle = Instance.new("TextLabel", sliderContainer)
sliderTitle.Text = "⚡ Spam Power"
sliderTitle.Size = UDim2.new(0.55, 0, 0, 18)
sliderTitle.Position = UDim2.new(0, 14, 0, 6)
sliderTitle.BackgroundTransparency = 1
sliderTitle.TextColor3 = CONFIG.TEXT_PRIMARY
sliderTitle.TextSize = 12
sliderTitle.Font = Enum.Font.GothamSemibold
sliderTitle.TextXAlignment = Enum.TextXAlignment.Left
sliderTitle.ZIndex = 4

local sliderValueLabel = Instance.new("TextLabel", sliderContainer)
sliderValueLabel.Text = "1x Power"
sliderValueLabel.Size = UDim2.new(0.42, 0, 0, 18)
sliderValueLabel.Position = UDim2.new(0.58, -14, 0, 6)
sliderValueLabel.BackgroundTransparency = 1
sliderValueLabel.TextColor3 = CONFIG.ACCENT_COLOR
sliderValueLabel.TextSize = 12
sliderValueLabel.Font = Enum.Font.GothamBold
sliderValueLabel.TextXAlignment = Enum.TextXAlignment.Right
sliderValueLabel.ZIndex = 4

-- Dynamic description: "Xx Power = X Heartbeats/frame"
local sliderDesc = Instance.new("TextLabel", sliderContainer)
sliderDesc.Text = "1x Power  =  1 Heartbeat/frame"
sliderDesc.Size = UDim2.new(1, -28, 0, 14)
sliderDesc.Position = UDim2.new(0, 14, 0, 26)
sliderDesc.BackgroundTransparency = 1
sliderDesc.TextColor3 = CONFIG.TEXT_SECONDARY
sliderDesc.TextSize = 10
sliderDesc.Font = Enum.Font.Gotham
sliderDesc.TextXAlignment = Enum.TextXAlignment.Left
sliderDesc.ZIndex = 4

-- Slider track
local sliderTrack = Instance.new("Frame", sliderContainer)
sliderTrack.Size = UDim2.new(1, -28, 0, 6)
sliderTrack.Position = UDim2.new(0, 14, 0, 50)
sliderTrack.BackgroundColor3 = CONFIG.TOGGLE_OFF
sliderTrack.BorderSizePixel = 0
sliderTrack.ZIndex = 4
Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

-- Slider fill
local sliderFill = Instance.new("Frame", sliderTrack)
sliderFill.Size = UDim2.new(0, 0, 1, 0)
sliderFill.BackgroundColor3 = CONFIG.ACCENT_COLOR
sliderFill.BorderSizePixel = 0
sliderFill.ZIndex = 5
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

-- Knob
local sliderKnob = Instance.new("Frame", sliderTrack)
sliderKnob.Size = UDim2.new(0, 14, 0, 14)
sliderKnob.Position = UDim2.new(0, -7, 0.5, -7)
sliderKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
sliderKnob.BorderSizePixel = 0
sliderKnob.ZIndex = 6
Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

-- Slider logic (1x to 100x)
local SLIDER_MIN, SLIDER_MAX = 1, 100
local sliderDragging = false

local function updateSlider(xRatio)
    xRatio = math.clamp(xRatio, 0, 1)
    local value = math.round(SLIDER_MIN + xRatio * (SLIDER_MAX - SLIDER_MIN))
    State.spamMultiplier = value
    sliderValueLabel.Text = value .. "x Power"
    local hbText = value == 1 and "1 Heartbeat/frame" or (value .. " Heartbeats/frame")
    sliderDesc.Text = value .. "x Power  =  " .. hbText
    sliderFill.Size = UDim2.new(xRatio, 0, 1, 0)
    sliderKnob.Position = UDim2.new(xRatio, -7, 0.5, -7)
end

sliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = true
        local xRatio = (input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X
        updateSlider(xRatio)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                           input.UserInputType == Enum.UserInputType.Touch) then
        local xRatio = (input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X
        updateSlider(xRatio)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = false
    end
end)

createSeparator(CombatPage)

-- ── Test Button: Click on BLOCK.Button ─
local testBtnContainer = Instance.new("Frame", CombatPage)
testBtnContainer.Size             = UDim2.new(1, 0, 0, 54)
testBtnContainer.BackgroundColor3 = CONFIG.BG_PANEL
testBtnContainer.BorderSizePixel  = 0
testBtnContainer.ZIndex           = 3
Instance.new("UICorner", testBtnContainer).CornerRadius = UDim.new(0, 10)
local testBtnStroke = Instance.new("UIStroke", testBtnContainer)
testBtnStroke.Color = CONFIG.BORDER_COLOR; testBtnStroke.Thickness = 1

local testBtnLabel = Instance.new("TextLabel", testBtnContainer)
testBtnLabel.Text = "Test BLOCK Button"
testBtnLabel.Size = UDim2.new(0.6, 0, 0, 20)
testBtnLabel.Position = UDim2.new(0, 14, 0, 8)
testBtnLabel.BackgroundTransparency = 1
testBtnLabel.TextColor3 = CONFIG.TEXT_PRIMARY
testBtnLabel.TextSize = 12
testBtnLabel.Font = Enum.Font.GothamSemibold
testBtnLabel.TextXAlignment = Enum.TextXAlignment.Left
testBtnLabel.ZIndex = 4

local testBtnDesc = Instance.new("TextLabel", testBtnContainer)
testBtnDesc.Text = "Click the Button once to test"
testBtnDesc.Size = UDim2.new(0.7, 0, 0, 14)
testBtnDesc.Position = UDim2.new(0, 14, 0, 30)
testBtnDesc.BackgroundTransparency = 1
testBtnDesc.TextColor3 = CONFIG.TEXT_SECONDARY
testBtnDesc.TextSize = 10
testBtnDesc.Font = Enum.Font.Gotham
testBtnDesc.TextXAlignment = Enum.TextXAlignment.Left
testBtnDesc.ZIndex = 4

local testBtn = Instance.new("TextButton", testBtnContainer)
testBtn.Text = "▶  Test"
testBtn.Size = UDim2.new(0, 80, 0, 28)
testBtn.Position = UDim2.new(1, -94, 0.5, -14)
testBtn.BackgroundColor3 = CONFIG.ACCENT_COLOR
testBtn.BackgroundTransparency = 0.2
testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
testBtn.TextSize = 11
testBtn.Font = Enum.Font.GothamBold
testBtn.BorderSizePixel = 0
testBtn.ZIndex = 5
Instance.new("UICorner", testBtn).CornerRadius = UDim.new(0, 8)

testBtn.MouseEnter:Connect(function()
    TweenService:Create(testBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
end)
testBtn.MouseLeave:Connect(function()
    TweenService:Create(testBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
end)

testBtn.MouseButton1Click:Connect(function()
    local ok, btn

    if DETECTED_GAME == "anime" then
        -- Anime Ball: tests the TextButton Detection
        testBtnLabel.Text = "Test Detection Button"
        ok, btn = pcall(function()
            return game:GetService("Players").LocalPlayer
                :WaitForChild("PlayerGui", 3)
                :WaitForChild("HUD", 3)
                :WaitForChild("MobileSmall", 3)
                :WaitForChild("Block", 3)
                :WaitForChild("Detection", 3)
        end)
        if not ok or not btn then
            testBtnDesc.Text = "❌ Error: Detection not found!"
            TweenService:Create(testBtnDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
            TweenService:Create(testBtn,    TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.DANGER}):Play()
            task.delay(2, function()
                testBtnDesc.Text = "Click the Button once to test"
                TweenService:Create(testBtnDesc, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
                TweenService:Create(testBtn,    TweenInfo.new(0.3), {BackgroundColor3 = CONFIG.ACCENT_COLOR}):Play()
            end)
            return
        end
        if not btn:IsA("TextButton") then
            testBtnDesc.Text = "❌ Error: Detection is not a TextButton!"
            TweenService:Create(testBtnDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
            TweenService:Create(testBtn,    TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.DANGER}):Play()
            task.delay(2, function()
                testBtnDesc.Text = "Click the Button once to test"
                TweenService:Create(testBtnDesc, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
                TweenService:Create(testBtn,    TweenInfo.new(0.3), {BackgroundColor3 = CONFIG.ACCENT_COLOR}):Play()
            end)
            return
        end
    else
        -- Phantom Ball: tests the ImageButton BLOCK.Button
        testBtnLabel.Text = "Test BLOCK Button"
        ok, btn = pcall(function()
            return game:GetService("Players").LocalPlayer
                :WaitForChild("PlayerGui", 3)
                :WaitForChild("Interface", 3)
                :WaitForChild("MobileUI", 3)
                :WaitForChild("Buttons", 3)
                :WaitForChild("Jump", 3)
                :WaitForChild("BLOCK", 3)
                :WaitForChild("Button", 3)
        end)
        if not ok or not btn then
            testBtnDesc.Text = "❌ Error: BLOCK.Button not found!"
            TweenService:Create(testBtnDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
            TweenService:Create(testBtn,    TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.DANGER}):Play()
            task.delay(2, function()
                testBtnDesc.Text = "Click the Button once to test"
                TweenService:Create(testBtnDesc, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
                TweenService:Create(testBtn,    TweenInfo.new(0.3), {BackgroundColor3 = CONFIG.ACCENT_COLOR}):Play()
            end)
            return
        end
        if not btn:IsA("ImageButton") then
            testBtnDesc.Text = "❌ Error: BLOCK.Button is not an ImageButton!"
            TweenService:Create(testBtnDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
            TweenService:Create(testBtn,    TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.DANGER}):Play()
            task.delay(2, function()
                testBtnDesc.Text = "Click the Button once to test"
                TweenService:Create(testBtnDesc, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
                TweenService:Create(testBtn,    TweenInfo.new(0.3), {BackgroundColor3 = CONFIG.ACCENT_COLOR}):Play()
            end)
            return
        end
    end

    local fireOk = pcall(function()
        if DETECTED_GAME == "anime" then
            for _, conn in pairs(getconnections(btn.MouseButton1Down)) do conn:Fire() end
            task.wait(0.01)
            for _, conn in pairs(getconnections(btn.MouseButton1Up)) do conn:Fire() end
        else
            btn:FireServer("MouseButton1Down")
            btn:FireServer("MouseButton1Up")
        end
    end)

    if fireOk then
        testBtnDesc.Text = "✔ Click sent successfully!"
        TweenService:Create(testBtnDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.SUCCESS}):Play()
        TweenService:Create(testBtn,    TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.SUCCESS}):Play()
    else
        testBtnDesc.Text = "❌ Error clicking Button"
        TweenService:Create(testBtnDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
        TweenService:Create(testBtn,    TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.DANGER}):Play()
    end
    task.delay(2, function()
        testBtnDesc.Text = "Click the Button once to test"
        TweenService:Create(testBtnDesc, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
        TweenService:Create(testBtn,    TweenInfo.new(0.3), {BackgroundColor3 = CONFIG.ACCENT_COLOR}):Play()
    end)
end)

createSeparator(CombatPage)

-- ── Slider Parry Distance (Combat) ────────
do
    local pdContainer = Instance.new("Frame", CombatPage)
    pdContainer.Size             = UDim2.new(1, 0, 0, 72)
    pdContainer.BackgroundColor3 = CONFIG.BG_PANEL
    pdContainer.BorderSizePixel  = 0
    pdContainer.ZIndex           = 3
    pdContainer.ClipsDescendants = false
    Instance.new("UICorner", pdContainer).CornerRadius = UDim.new(0, 10)
    local pdStroke = Instance.new("UIStroke", pdContainer)
    pdStroke.Color = CONFIG.BORDER_COLOR; pdStroke.Thickness = 1

    local pdTitle = Instance.new("TextLabel", pdContainer)
    pdTitle.Text = "Parry Distance"
    pdTitle.Size = UDim2.new(0.55, 0, 0, 18)
    pdTitle.Position = UDim2.new(0, 14, 0, 6)
    pdTitle.BackgroundTransparency = 1
    pdTitle.TextColor3 = CONFIG.TEXT_PRIMARY
    pdTitle.TextSize = 12; pdTitle.Font = Enum.Font.GothamSemibold
    pdTitle.TextXAlignment = Enum.TextXAlignment.Left
    pdTitle.ZIndex = 4

    local pdValueLabel = Instance.new("TextLabel", pdContainer)
    pdValueLabel.Text = "1 st"
    pdValueLabel.Size = UDim2.new(0.42, 0, 0, 18)
    pdValueLabel.Position = UDim2.new(0.58, -14, 0, 6)
    pdValueLabel.BackgroundTransparency = 1
    pdValueLabel.TextColor3 = CONFIG.ACCENT_COLOR
    pdValueLabel.TextSize = 12; pdValueLabel.Font = Enum.Font.GothamBold
    pdValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    pdValueLabel.ZIndex = 4

    local pdDesc = Instance.new("TextLabel", pdContainer)
    pdDesc.Text = "Base radius of the parry detector"
    pdDesc.Size = UDim2.new(1, -28, 0, 14)
    pdDesc.Position = UDim2.new(0, 14, 0, 26)
    pdDesc.BackgroundTransparency = 1
    pdDesc.TextColor3 = CONFIG.TEXT_SECONDARY
    pdDesc.TextSize = 10; pdDesc.Font = Enum.Font.Gotham
    pdDesc.TextXAlignment = Enum.TextXAlignment.Left
    pdDesc.ZIndex = 4

    local pdTrack = Instance.new("Frame", pdContainer)
    pdTrack.Size = UDim2.new(1, -28, 0, 6)
    pdTrack.Position = UDim2.new(0, 14, 0, 50)
    pdTrack.BackgroundColor3 = CONFIG.TOGGLE_OFF
    pdTrack.BorderSizePixel = 0; pdTrack.ZIndex = 4
    Instance.new("UICorner", pdTrack).CornerRadius = UDim.new(1, 0)

    local pdFill = Instance.new("Frame", pdTrack)
    pdFill.Size = UDim2.new(0, 0, 1, 0)
    pdFill.BackgroundColor3 = CONFIG.ACCENT_COLOR
    pdFill.BorderSizePixel = 0; pdFill.ZIndex = 5
    Instance.new("UICorner", pdFill).CornerRadius = UDim.new(1, 0)

    local pdKnob = Instance.new("Frame", pdTrack)
    pdKnob.Size = UDim2.new(0, 14, 0, 14)
    pdKnob.Position = UDim2.new(0, -7, 0.5, -7)
    pdKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    pdKnob.BorderSizePixel = 0; pdKnob.ZIndex = 6
    Instance.new("UICorner", pdKnob).CornerRadius = UDim.new(1, 0)

    local PD_MIN, PD_MAX = 1, 50
    local pdDragging = false

    local function updatePdSlider(xRatio)
        xRatio = math.clamp(xRatio, 0, 1)
        local value = math.round(PD_MIN + xRatio * (PD_MAX - PD_MIN))
        CONFIG.PARRY_DIST = value
        pdValueLabel.Text = value .. " st"
        pdFill.Size = UDim2.new(xRatio, 0, 1, 0)
        pdKnob.Position = UDim2.new(xRatio, -7, 0.5, -7)
    end

    pdTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            pdDragging = true
            updatePdSlider((input.Position.X - pdTrack.AbsolutePosition.X) / pdTrack.AbsoluteSize.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if pdDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                           input.UserInputType == Enum.UserInputType.Touch) then
            updatePdSlider((input.Position.X - pdTrack.AbsolutePosition.X) / pdTrack.AbsoluteSize.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            pdDragging = false
        end
    end)
end

createSeparator(CombatPage)

createToggle(CombatPage, "Optimizer", "Clears old remote events after each fire", function(on)
    State.optimizer = on
end)
LocalPlayer.CharacterRemoving:Connect(function()
    if State.autoParry then destroyDetector() end
    if State.autoSpam  then destroySpamDetector() end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    local hrp      = char:WaitForChild("HumanoidRootPart", 5)
    local humanoid = char:WaitForChild("Humanoid", 5)
    if not hrp or not humanoid then return end

    task.wait(0.5)

    if State.autoParry then
        -- Reset variables and restart the full system
        State.hasExecutedThisDetection = false
        State.lastBallColor            = nil
        State.ballWasInside            = false
        lastBallCFrame                 = nil
        trackedSpeed                   = 0
        -- Drop old connection and restart
        if State.runConnection then State.runConnection:Disconnect(); State.runConnection = nil end
        startAutoParry()
    end

    if State.autoSpam then
        -- Drop old connection and restart
        if State.spamConnection then State.spamConnection:Disconnect(); State.spamConnection = nil end
        startAutoSpam()
    end
end)

-- ══════════════════════════════════════════
--    DEATH SOUND TAB (Anime Ball only)
-- ══════════════════════════════════════════
if DETECTED_GAME == "anime" then
    local DeathPage = createTab("Sound", "🔊")

    local deathHeader = Instance.new("TextLabel", DeathPage)
    deathHeader.Text                  = "DEATH SOUND"
    deathHeader.Size                  = UDim2.new(1, 0, 0, 18)
    deathHeader.BackgroundTransparency = 1
    deathHeader.TextColor3            = CONFIG.ACCENT_COLOR
    deathHeader.TextSize              = 10
    deathHeader.Font                  = Enum.Font.GothamBold
    deathHeader.TextXAlignment        = Enum.TextXAlignment.Left
    deathHeader.ZIndex                = 3

    createSeparator(DeathPage)

    -- ── JSON save system ──────────────────
    local SAVE_FOLDER = "NEXUS - sounds"
    local SAVE_FILE   = SAVE_FOLDER .. "/sounds.json"
    local savedSounds = {}  -- { {id="123", label="123"}, ... }

    local function ensureFolder()
        if not isfolder(SAVE_FOLDER) then
            makefolder(SAVE_FOLDER)
        end
    end

    local function loadSounds()
        ensureFolder()
        if isfile(SAVE_FILE) then
            local ok, data = pcall(function()
                return game:GetService("HttpService"):JSONDecode(readfile(SAVE_FILE))
            end)
            if ok and type(data) == "table" then
                savedSounds = data
            end
        end
    end

    local function saveSounds()
        ensureFolder()
        local ok, encoded = pcall(function()
            return game:GetService("HttpService"):JSONEncode(savedSounds)
        end)
        if ok then
            writefile(SAVE_FILE, encoded)
        end
    end

    local function idExists(id)
        for _, entry in ipairs(savedSounds) do
            if entry.id == id then return true end
        end
        return false
    end

    -- Load saved sounds on startup
    pcall(loadSounds)

    -- ── Function to apply sound ─────────────
    local function applySound(id)
        return pcall(function()
            local sound = game:GetService("ReplicatedStorage")
                :WaitForChild("Storage")
                :WaitForChild("Sounds")
                :WaitForChild("Explosions")
                :WaitForChild("Death")
            sound.SoundId = "rbxassetid://" .. id
        end)
    end

    -- ── Scrollable dropdown ───────────────
    local ddContainer = Instance.new("Frame", DeathPage)
    ddContainer.Size             = UDim2.new(1, 0, 0, 54)
    ddContainer.BackgroundColor3 = CONFIG.BG_PANEL
    ddContainer.BorderSizePixel  = 0
    ddContainer.ZIndex           = 10
    Instance.new("UICorner", ddContainer).CornerRadius = UDim.new(0, 10)
    local ddStroke = Instance.new("UIStroke", ddContainer)
    ddStroke.Color = CONFIG.BORDER_COLOR; ddStroke.Thickness = 1

    local ddLabel = Instance.new("TextLabel", ddContainer)
    ddLabel.Text = "Saved Sounds"
    ddLabel.Size = UDim2.new(1, -14, 0, 16)
    ddLabel.Position = UDim2.new(0, 14, 0, 6)
    ddLabel.BackgroundTransparency = 1
    ddLabel.TextColor3 = CONFIG.TEXT_SECONDARY
    ddLabel.TextSize = 10; ddLabel.Font = Enum.Font.Gotham
    ddLabel.TextXAlignment = Enum.TextXAlignment.Left
    ddLabel.ZIndex = 11

    local ddBtn = Instance.new("TextButton", ddContainer)
    ddBtn.Size             = UDim2.new(1, -28, 0, 24)
    ddBtn.Position         = UDim2.new(0, 14, 0, 24)
    ddBtn.BackgroundColor3 = CONFIG.BG_MID
    ddBtn.BorderSizePixel  = 0
    ddBtn.TextColor3       = CONFIG.TEXT_PRIMARY
    ddBtn.TextSize         = 11
    ddBtn.Font             = Enum.Font.GothamSemibold
    ddBtn.Text             = "Select saved sound..."
    ddBtn.TextXAlignment   = Enum.TextXAlignment.Left
    ddBtn.ZIndex           = 11
    Instance.new("UICorner", ddBtn).CornerRadius = UDim.new(0, 6)
    local ddBtnStroke = Instance.new("UIStroke", ddBtn)
    ddBtnStroke.Color = CONFIG.BORDER_COLOR; ddBtnStroke.Thickness = 1
    local ddBtnPad = Instance.new("UIPadding", ddBtn)
    ddBtnPad.PaddingLeft = UDim.new(0, 8)

    local ddArrow = Instance.new("TextLabel", ddBtn)
    ddArrow.Text = "▾"
    ddArrow.Size = UDim2.new(0, 20, 1, 0)
    ddArrow.Position = UDim2.new(1, -24, 0, 0)
    ddArrow.BackgroundTransparency = 1
    ddArrow.TextColor3 = CONFIG.TEXT_SECONDARY
    ddArrow.TextSize = 12; ddArrow.Font = Enum.Font.GothamBold
    ddArrow.ZIndex = 12

    -- Dropdown menu with ScrollingFrame
    local ddMenu = Instance.new("Frame", ScreenGui)
    ddMenu.Size             = UDim2.new(0, 0, 0, 0)
    ddMenu.BackgroundColor3 = CONFIG.BG_MID
    ddMenu.BorderSizePixel  = 0
    ddMenu.Visible          = false
    ddMenu.ZIndex           = 200
    Instance.new("UICorner", ddMenu).CornerRadius = UDim.new(0, 8)
    local ddMenuStroke = Instance.new("UIStroke", ddMenu)
    ddMenuStroke.Color = CONFIG.ACCENT_COLOR; ddMenuStroke.Thickness = 1

    -- Inner ScrollingFrame
    local ddScroll = Instance.new("ScrollingFrame", ddMenu)
    ddScroll.Size                = UDim2.new(1, -8, 1, -8)
    ddScroll.Position            = UDim2.new(0, 4, 0, 4)
    ddScroll.BackgroundTransparency = 1
    ddScroll.BorderSizePixel     = 0
    ddScroll.ScrollBarThickness  = 3
    ddScroll.ScrollBarImageColor3 = CONFIG.ACCENT_COLOR
    ddScroll.ZIndex              = 201
    ddScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)

    local ddScrollLayout = Instance.new("UIListLayout", ddScroll)
    ddScrollLayout.FillDirection = Enum.FillDirection.Vertical
    ddScrollLayout.Padding       = UDim.new(0, 2)

    ddScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ddScroll.CanvasSize = UDim2.new(0, 0, 0, ddScrollLayout.AbsoluteContentSize.Y)
    end)

    local ddOpen = false
    local DD_MAX_HEIGHT = 140  -- altura máxima do menu

    local function rebuildDropdown()
        -- Clear old items
        for _, child in pairs(ddScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        if #savedSounds == 0 then
            local empty = Instance.new("TextButton", ddScroll)
            empty.Size             = UDim2.new(1, 0, 0, 28)
            empty.BackgroundTransparency = 1
            empty.BorderSizePixel  = 0
            empty.TextColor3       = CONFIG.TEXT_SECONDARY
            empty.TextSize         = 11
            empty.Font             = Enum.Font.Gotham
            empty.Text             = "No sounds saved yet"
            empty.ZIndex           = 202
            return
        end

        for i, entry in ipairs(savedSounds) do
            local item = Instance.new("TextButton", ddScroll)
            item.Size             = UDim2.new(1, 0, 0, 28)
            item.BackgroundColor3 = CONFIG.BG_PANEL
            item.BackgroundTransparency = 0.3
            item.BorderSizePixel  = 0
            item.TextColor3       = CONFIG.TEXT_PRIMARY
            item.TextSize         = 11
            item.Font             = Enum.Font.GothamSemibold
            item.Text             = "🔊  " .. entry.id
            item.TextXAlignment   = Enum.TextXAlignment.Left
            item.ZIndex           = 202
            Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
            local itemPad = Instance.new("UIPadding", item)
            itemPad.PaddingLeft = UDim.new(0, 8)

            item.MouseEnter:Connect(function()
                TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.ACCENT_COLOR, BackgroundTransparency = 0.7}):Play()
            end)
            item.MouseLeave:Connect(function()
                TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.BG_PANEL, BackgroundTransparency = 0.3}):Play()
            end)

            local capturedId = entry.id
            item.MouseButton1Click:Connect(function()
                ddBtn.Text = "🔊  " .. capturedId
                applySound(capturedId)
                -- Close menu
                ddOpen = false
                TweenService:Create(ddMenu, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Size = UDim2.new(0, ddMenu.Size.X.Offset, 0, 0)}):Play()
                task.delay(0.15, function() ddMenu.Visible = false end)
                TweenService:Create(ddArrow, TweenInfo.new(0.15), {Rotation = 0}):Play()
            end)
        end
    end

    ddBtn.MouseButton1Click:Connect(function()
        ddOpen = not ddOpen
        if ddOpen then
            rebuildDropdown()
            local absPos  = ddBtn.AbsolutePosition
            local absSize = ddBtn.AbsoluteSize
            local menuW   = absSize.X + 28
            local contentH = ddScrollLayout.AbsoluteContentSize.Y + 8
            local menuH   = math.min(contentH, DD_MAX_HEIGHT)
            ddMenu.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
            ddMenu.Size     = UDim2.new(0, menuW, 0, 0)
            ddMenu.Visible  = true
            TweenService:Create(ddMenu, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, menuW, 0, menuH)}):Play()
            TweenService:Create(ddArrow, TweenInfo.new(0.15), {Rotation = 180}):Play()
        else
            TweenService:Create(ddMenu, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
                {Size = UDim2.new(0, ddMenu.Size.X.Offset, 0, 0)}):Play()
            task.delay(0.15, function() ddMenu.Visible = false end)
            TweenService:Create(ddArrow, TweenInfo.new(0.15), {Rotation = 0}):Play()
        end
    end)

    createSeparator(DeathPage)

    -- ── Preset IDs dropdown ───────────────
    local PRESET_SOUNDS = {
        {id = "72298953503422",  label = "72298953503422"},
        {id = "83498632148661",  label = "83498632148661"},
        {id = "18735403020",     label = "18735403020"},
        {id = "18420707371",     label = "18420707371"},
        {id = "1107208252",      label = "1107208252"},
        {id = "8243331779",      label = "8243331779"},
    }

    local presetContainer = Instance.new("Frame", DeathPage)
    presetContainer.Size             = UDim2.new(1, 0, 0, 54)
    presetContainer.BackgroundColor3 = CONFIG.BG_PANEL
    presetContainer.BorderSizePixel  = 0
    presetContainer.ZIndex           = 9
    Instance.new("UICorner", presetContainer).CornerRadius = UDim.new(0, 10)
    local presetStroke = Instance.new("UIStroke", presetContainer)
    presetStroke.Color = CONFIG.BORDER_COLOR; presetStroke.Thickness = 1

    local presetLabel = Instance.new("TextLabel", presetContainer)
    presetLabel.Text = "Preset Sounds"
    presetLabel.Size = UDim2.new(1, -14, 0, 16)
    presetLabel.Position = UDim2.new(0, 14, 0, 6)
    presetLabel.BackgroundTransparency = 1
    presetLabel.TextColor3 = CONFIG.TEXT_SECONDARY
    presetLabel.TextSize = 10; presetLabel.Font = Enum.Font.Gotham
    presetLabel.TextXAlignment = Enum.TextXAlignment.Left
    presetLabel.ZIndex = 10

    local presetBtn = Instance.new("TextButton", presetContainer)
    presetBtn.Size             = UDim2.new(1, -28, 0, 24)
    presetBtn.Position         = UDim2.new(0, 14, 0, 24)
    presetBtn.BackgroundColor3 = CONFIG.BG_MID
    presetBtn.BorderSizePixel  = 0
    presetBtn.TextColor3       = CONFIG.TEXT_PRIMARY
    presetBtn.TextSize         = 11
    presetBtn.Font             = Enum.Font.GothamSemibold
    presetBtn.Text             = "Choose a preset sound..."
    presetBtn.TextXAlignment   = Enum.TextXAlignment.Left
    presetBtn.ZIndex           = 10
    Instance.new("UICorner", presetBtn).CornerRadius = UDim.new(0, 6)
    local presetBtnStroke = Instance.new("UIStroke", presetBtn)
    presetBtnStroke.Color = CONFIG.BORDER_COLOR; presetBtnStroke.Thickness = 1
    local presetBtnPad = Instance.new("UIPadding", presetBtn)
    presetBtnPad.PaddingLeft = UDim.new(0, 8)

    local presetArrow = Instance.new("TextLabel", presetBtn)
    presetArrow.Text = "▾"
    presetArrow.Size = UDim2.new(0, 20, 1, 0)
    presetArrow.Position = UDim2.new(1, -24, 0, 0)
    presetArrow.BackgroundTransparency = 1
    presetArrow.TextColor3 = CONFIG.TEXT_SECONDARY
    presetArrow.TextSize = 12; presetArrow.Font = Enum.Font.GothamBold
    presetArrow.ZIndex = 11

    -- Menu preset com ScrollingFrame
    local presetMenu = Instance.new("Frame", ScreenGui)
    presetMenu.Size             = UDim2.new(0, 0, 0, 0)
    presetMenu.BackgroundColor3 = CONFIG.BG_MID
    presetMenu.BorderSizePixel  = 0
    presetMenu.Visible          = false
    presetMenu.ZIndex           = 190
    Instance.new("UICorner", presetMenu).CornerRadius = UDim.new(0, 8)
    local presetMenuStroke = Instance.new("UIStroke", presetMenu)
    presetMenuStroke.Color = CONFIG.ACCENT_COLOR; presetMenuStroke.Thickness = 1

    local presetScroll = Instance.new("ScrollingFrame", presetMenu)
    presetScroll.Size                = UDim2.new(1, -8, 1, -8)
    presetScroll.Position            = UDim2.new(0, 4, 0, 4)
    presetScroll.BackgroundTransparency = 1
    presetScroll.BorderSizePixel     = 0
    presetScroll.ScrollBarThickness  = 3
    presetScroll.ScrollBarImageColor3 = CONFIG.ACCENT_COLOR
    presetScroll.ZIndex              = 191

    local presetLayout = Instance.new("UIListLayout", presetScroll)
    presetLayout.FillDirection = Enum.FillDirection.Vertical
    presetLayout.Padding       = UDim.new(0, 2)
    presetLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        presetScroll.CanvasSize = UDim2.new(0, 0, 0, presetLayout.AbsoluteContentSize.Y)
    end)

    local presetOpen = false
    local PRESET_MAX_HEIGHT = 140

    -- Populate preset items
    for _, entry in ipairs(PRESET_SOUNDS) do
        local item = Instance.new("TextButton", presetScroll)
        item.Size             = UDim2.new(1, 0, 0, 28)
        item.BackgroundColor3 = CONFIG.BG_PANEL
        item.BackgroundTransparency = 0.3
        item.BorderSizePixel  = 0
        item.TextColor3       = CONFIG.TEXT_PRIMARY
        item.TextSize         = 11
        item.Font             = Enum.Font.GothamSemibold
        item.Text             = "🎵  " .. entry.label
        item.TextXAlignment   = Enum.TextXAlignment.Left
        item.ZIndex           = 192
        Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
        local iPad = Instance.new("UIPadding", item)
        iPad.PaddingLeft = UDim.new(0, 8)

        item.MouseEnter:Connect(function()
            TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.ACCENT_COLOR, BackgroundTransparency = 0.7}):Play()
        end)
        item.MouseLeave:Connect(function()
            TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.BG_PANEL, BackgroundTransparency = 0.3}):Play()
        end)

        local capturedId = entry.id
        item.MouseButton1Click:Connect(function()
            presetBtn.Text = "🎵  " .. capturedId
            applySound(capturedId)
            presetOpen = false
            TweenService:Create(presetMenu, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
                {Size = UDim2.new(0, presetMenu.Size.X.Offset, 0, 0)}):Play()
            task.delay(0.15, function() presetMenu.Visible = false end)
            TweenService:Create(presetArrow, TweenInfo.new(0.15), {Rotation = 0}):Play()
        end)
    end

    presetBtn.MouseButton1Click:Connect(function()
        presetOpen = not presetOpen
        if presetOpen then
            local absPos  = presetBtn.AbsolutePosition
            local absSize = presetBtn.AbsoluteSize
            local menuW   = absSize.X + 28
            local contentH = presetLayout.AbsoluteContentSize.Y + 8
            local menuH   = math.min(contentH, PRESET_MAX_HEIGHT)
            presetMenu.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
            presetMenu.Size     = UDim2.new(0, menuW, 0, 0)
            presetMenu.Visible  = true
            TweenService:Create(presetMenu, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, menuW, 0, menuH)}):Play()
            TweenService:Create(presetArrow, TweenInfo.new(0.15), {Rotation = 180}):Play()
        else
            TweenService:Create(presetMenu, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
                {Size = UDim2.new(0, presetMenu.Size.X.Offset, 0, 0)}):Play()
            task.delay(0.15, function() presetMenu.Visible = false end)
            TweenService:Create(presetArrow, TweenInfo.new(0.15), {Rotation = 0}):Play()
        end
    end)

    createSeparator(DeathPage)

    -- ── TextBox for new Sound ID ────────────
    local soundContainer = Instance.new("Frame", DeathPage)
    soundContainer.Size             = UDim2.new(1, 0, 0, 90)
    soundContainer.BackgroundColor3 = CONFIG.BG_PANEL
    soundContainer.BorderSizePixel  = 0
    soundContainer.ZIndex           = 3
    Instance.new("UICorner", soundContainer).CornerRadius = UDim.new(0, 10)
    local soundStroke = Instance.new("UIStroke", soundContainer)
    soundStroke.Color = CONFIG.BORDER_COLOR; soundStroke.Thickness = 1

    local soundLabel = Instance.new("TextLabel", soundContainer)
    soundLabel.Text                  = "New Sound ID"
    soundLabel.Size                  = UDim2.new(1, -14, 0, 16)
    soundLabel.Position              = UDim2.new(0, 14, 0, 8)
    soundLabel.BackgroundTransparency = 1
    soundLabel.TextColor3            = CONFIG.TEXT_SECONDARY
    soundLabel.TextSize              = 10
    soundLabel.Font                  = Enum.Font.Gotham
    soundLabel.TextXAlignment        = Enum.TextXAlignment.Left
    soundLabel.ZIndex                = 4

    local soundDesc = Instance.new("TextLabel", soundContainer)
    soundDesc.Text                  = "Enter the ID and press Enter to save"
    soundDesc.Size                  = UDim2.new(1, -14, 0, 14)
    soundDesc.Position              = UDim2.new(0, 14, 1, -18)
    soundDesc.BackgroundTransparency = 1
    soundDesc.TextColor3            = CONFIG.TEXT_SECONDARY
    soundDesc.TextSize              = 10
    soundDesc.Font                  = Enum.Font.Gotham
    soundDesc.TextXAlignment        = Enum.TextXAlignment.Left
    soundDesc.ZIndex                = 4

    local soundBoxFrame = Instance.new("Frame", soundContainer)
    soundBoxFrame.Size             = UDim2.new(1, -28, 0, 28)
    soundBoxFrame.Position         = UDim2.new(0, 14, 0, 28)
    soundBoxFrame.BackgroundColor3 = CONFIG.BG_MID
    soundBoxFrame.BorderSizePixel  = 0
    soundBoxFrame.ZIndex           = 4
    Instance.new("UICorner", soundBoxFrame).CornerRadius = UDim.new(0, 7)
    local soundBoxStroke = Instance.new("UIStroke", soundBoxFrame)
    soundBoxStroke.Color = CONFIG.BORDER_COLOR; soundBoxStroke.Thickness = 1

    local soundBox = Instance.new("TextBox", soundBoxFrame)
    soundBox.Size                  = UDim2.new(1, -16, 1, 0)
    soundBox.Position              = UDim2.new(0, 8, 0, 0)
    soundBox.BackgroundTransparency = 1
    soundBox.TextColor3            = CONFIG.TEXT_PRIMARY
    soundBox.TextSize              = 12
    soundBox.Font                  = Enum.Font.GothamSemibold
    soundBox.PlaceholderText       = "Ex: 131070686"
    soundBox.PlaceholderColor3     = CONFIG.TEXT_SECONDARY
    soundBox.Text                  = ""
    soundBox.ClearTextOnFocus      = false
    soundBox.ZIndex                = 5
    local soundBoxPad = Instance.new("UIPadding", soundBox)
    soundBoxPad.PaddingLeft = UDim.new(0, 2)

    soundBox.Focused:Connect(function()
        TweenService:Create(soundBoxStroke, TweenInfo.new(0.15), {Color = CONFIG.ACCENT_COLOR}):Play()
    end)

    soundBox.FocusLost:Connect(function(enterPressed)
        TweenService:Create(soundBoxStroke, TweenInfo.new(0.15), {Color = CONFIG.BORDER_COLOR}):Play()
        if not enterPressed or soundBox.Text == "" then return end

        local inputId = soundBox.Text:match("%d+")
        if not inputId then
            soundDesc.Text = "❌  Invalid ID — numbers only"
            TweenService:Create(soundDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
            TweenService:Create(soundBoxStroke, TweenInfo.new(0.1), {Color = CONFIG.DANGER}):Play()
            task.delay(2.5, function()
                soundDesc.Text = "Enter the ID and press Enter to save"
                TweenService:Create(soundDesc, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
                TweenService:Create(soundBoxStroke, TweenInfo.new(0.3), {Color = CONFIG.BORDER_COLOR}):Play()
            end)
            return
        end

        -- Apply sound
        local ok = applySound(inputId)

        if ok then
            -- Save to JSON if it does not exist yet
            if not idExists(inputId) then
                table.insert(savedSounds, {id = inputId})
                pcall(saveSounds)
                ddBtn.Text = "🔊  " .. inputId
            end

            soundDesc.Text = "✔  ID " .. inputId .. " applied and saved!"
            TweenService:Create(soundDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.SUCCESS}):Play()
            TweenService:Create(soundBoxStroke, TweenInfo.new(0.1), {Color = CONFIG.SUCCESS}):Play()
        else
            soundDesc.Text = "❌  Error: Sound not found"
            TweenService:Create(soundDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
            TweenService:Create(soundBoxStroke, TweenInfo.new(0.1), {Color = CONFIG.DANGER}):Play()
        end

        task.delay(2.5, function()
            soundDesc.Text = "Enter the ID and press Enter to save"
            TweenService:Create(soundDesc, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
            TweenService:Create(soundBoxStroke, TweenInfo.new(0.3), {Color = CONFIG.BORDER_COLOR}):Play()
        end)
    end)

    -- Update dropdown with saved sounds on load
    rebuildDropdown()
    if #savedSounds > 0 then
        ddBtn.Text = "🔊  " .. savedSounds[#savedSounds].id
    end
end

-- ══════════════════════════════════════════
--         VISUAL TAB
-- ══════════════════════════════════════════
local VisualPage = createTab("Visual", "👁")

local visualHeader = Instance.new("TextLabel", VisualPage)
visualHeader.Text                  = "VISUAL MODULES"
visualHeader.Size                  = UDim2.new(1, 0, 0, 18)
visualHeader.BackgroundTransparency = 1
visualHeader.TextColor3            = CONFIG.ACCENT_COLOR
visualHeader.TextSize              = 10
visualHeader.Font                  = Enum.Font.GothamBold
visualHeader.TextXAlignment        = Enum.TextXAlignment.Left
visualHeader.ZIndex                = 3

createSeparator(VisualPage)

-- ══════════════════════════════════════════
--    SKILLS TAB (Phantom Ball only)
-- ══════════════════════════════════════════
if DETECTED_GAME == "phantom" then
    local SkillsPage = createTab("Skills", "⚡")

    local skillsHeader = Instance.new("TextLabel", SkillsPage)
    skillsHeader.Text                  = "SKILLS / LIABILITIES"
    skillsHeader.Size                  = UDim2.new(1, 0, 0, 18)
    skillsHeader.BackgroundTransparency = 1
    skillsHeader.TextColor3            = CONFIG.ACCENT_COLOR
    skillsHeader.TextSize              = 10
    skillsHeader.Font                  = Enum.Font.GothamBold
    skillsHeader.TextXAlignment        = Enum.TextXAlignment.Left
    skillsHeader.ZIndex                = 3

    createSeparator(SkillsPage)

    -- Passive container
    local passiveContainer = Instance.new("Frame", SkillsPage)
    passiveContainer.Size             = UDim2.new(1, 0, 0, 90)
    passiveContainer.BackgroundColor3 = CONFIG.BG_PANEL
    passiveContainer.BorderSizePixel  = 0
    passiveContainer.ZIndex           = 3
    Instance.new("UICorner", passiveContainer).CornerRadius = UDim.new(0, 10)
    local passiveStroke = Instance.new("UIStroke", passiveContainer)
    passiveStroke.Color = CONFIG.BORDER_COLOR; passiveStroke.Thickness = 1

    local passiveLabel = Instance.new("TextLabel", passiveContainer)
    passiveLabel.Text                  = "Passive"
    passiveLabel.Size                  = UDim2.new(1, -14, 0, 16)
    passiveLabel.Position              = UDim2.new(0, 14, 0, 8)
    passiveLabel.BackgroundTransparency = 1
    passiveLabel.TextColor3            = CONFIG.TEXT_SECONDARY
    passiveLabel.TextSize              = 10
    passiveLabel.Font                  = Enum.Font.Gotham
    passiveLabel.TextXAlignment        = Enum.TextXAlignment.Left
    passiveLabel.ZIndex                = 4

    local passiveDesc = Instance.new("TextLabel", passiveContainer)
    passiveDesc.Text                  = "Enter the name and press Enter"
    passiveDesc.Size                  = UDim2.new(1, -14, 0, 14)
    passiveDesc.Position              = UDim2.new(0, 14, 1, -18)
    passiveDesc.BackgroundTransparency = 1
    passiveDesc.TextColor3            = CONFIG.TEXT_SECONDARY
    passiveDesc.TextSize              = 10
    passiveDesc.Font                  = Enum.Font.Gotham
    passiveDesc.TextXAlignment        = Enum.TextXAlignment.Left
    passiveDesc.ZIndex                = 4

    -- Passive TextBox
    local passiveBoxFrame = Instance.new("Frame", passiveContainer)
    passiveBoxFrame.Size             = UDim2.new(1, -28, 0, 28)
    passiveBoxFrame.Position         = UDim2.new(0, 14, 0, 28)
    passiveBoxFrame.BackgroundColor3 = CONFIG.BG_MID
    passiveBoxFrame.BorderSizePixel  = 0
    passiveBoxFrame.ZIndex           = 4
    Instance.new("UICorner", passiveBoxFrame).CornerRadius = UDim.new(0, 7)
    local passiveBoxStroke = Instance.new("UIStroke", passiveBoxFrame)
    passiveBoxStroke.Color = CONFIG.BORDER_COLOR; passiveBoxStroke.Thickness = 1

    local passiveBox = Instance.new("TextBox", passiveBoxFrame)
    passiveBox.Size                  = UDim2.new(1, -16, 1, 0)
    passiveBox.Position              = UDim2.new(0, 8, 0, 0)
    passiveBox.BackgroundTransparency = 1
    passiveBox.TextColor3            = CONFIG.TEXT_PRIMARY
    passiveBox.TextSize              = 12
    passiveBox.Font                  = Enum.Font.GothamSemibold
    passiveBox.PlaceholderText       = "Ex: Reflexes, Strength..."
    passiveBox.PlaceholderColor3     = CONFIG.TEXT_SECONDARY
    passiveBox.Text                  = ""
    passiveBox.ClearTextOnFocus      = false
    passiveBox.ZIndex                = 5
    local passiveBoxPad = Instance.new("UIPadding", passiveBox)
    passiveBoxPad.PaddingLeft = UDim.new(0, 2)

    -- Hover/focus no frame
    passiveBox.Focused:Connect(function()
        TweenService:Create(passiveBoxStroke, TweenInfo.new(0.15), {Color = CONFIG.ACCENT_COLOR}):Play()
    end)
    passiveBox.FocusLost:Connect(function(enterPressed)
        TweenService:Create(passiveBoxStroke, TweenInfo.new(0.15), {Color = CONFIG.BORDER_COLOR}):Play()
        if not enterPressed or passiveBox.Text == "" then return end

        local passiveName = passiveBox.Text

        local ok = pcall(function()
            local args = { passiveName, 1 }
            game:GetService("ReplicatedStorage")
                :WaitForChild("TS")
                :WaitForChild("GeneratedNetworkRemotes")
                :WaitForChild("RE_5.456556666731276e+76")
                :FireServer(unpack(args))
        end)

        if ok then
            passiveDesc.Text = "✔  \"" .. passiveName .. "\" equipado!"
            TweenService:Create(passiveDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.SUCCESS}):Play()
            TweenService:Create(passiveBoxStroke, TweenInfo.new(0.1), {Color = CONFIG.SUCCESS}):Play()
        else
            passiveDesc.Text = "❌  Error equipping passive"
            TweenService:Create(passiveDesc, TweenInfo.new(0.1), {TextColor3 = CONFIG.DANGER}):Play()
            TweenService:Create(passiveBoxStroke, TweenInfo.new(0.1), {Color = CONFIG.DANGER}):Play()
        end

        task.delay(2.5, function()
            passiveDesc.Text = "Enter the name and press Enter"
            TweenService:Create(passiveDesc, TweenInfo.new(0.3), {TextColor3 = CONFIG.TEXT_SECONDARY}):Play()
            TweenService:Create(passiveBoxStroke, TweenInfo.new(0.3), {Color = CONFIG.BORDER_COLOR}):Play()
        end)
    end)
end

createToggle(VisualPage, "Show Detectors", "Shows detector spheres in the world", function(on)
    State.showDetectors = on
    if State.detectorPart     then State.detectorPart.Transparency     = on and 0.6 or 1 end
    if State.spamDetectorPart then State.spamDetectorPart.Transparency = on and 0.6 or 1 end
end)

createSeparator(VisualPage)

-- In Anime Ball, the Visual page only shows the stats panels
if DETECTED_GAME == "anime" then
    local animeVisualInfo = Instance.new("TextLabel", VisualPage)
    animeVisualInfo.Text                  = "ANIME BALL  ·  Stats Panels"
    animeVisualInfo.Size                  = UDim2.new(1, 0, 0, 18)
    animeVisualInfo.BackgroundTransparency = 1
    animeVisualInfo.TextColor3            = Color3.fromRGB(251, 146, 60)
    animeVisualInfo.TextSize              = 10
    animeVisualInfo.Font                  = Enum.Font.GothamBold
    animeVisualInfo.TextXAlignment        = Enum.TextXAlignment.Left
    animeVisualInfo.ZIndex                = 3
    createSeparator(VisualPage)
end

-- ══════════════════════════════════════════
--     GUI FLUTUANTE - AUTO PARRY STATS
-- ══════════════════════════════════════════
local ParryStatsGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ParryStatsGui.Name           = "ParryStatsGui"
ParryStatsGui.ResetOnSpawn   = false
ParryStatsGui.IgnoreGuiInset = true
ParryStatsGui.Enabled        = false

local ParryStatsFrame = Instance.new("Frame", ParryStatsGui)
ParryStatsFrame.Size             = UDim2.new(0, 210, 0, 140)
ParryStatsFrame.Position         = UDim2.new(0, 80, 0.5, -160)
ParryStatsFrame.BackgroundColor3 = CONFIG.BG_DARK
ParryStatsFrame.BorderSizePixel  = 0
Instance.new("UICorner", ParryStatsFrame).CornerRadius = UDim.new(0, 12)
local psStroke = Instance.new("UIStroke", ParryStatsFrame)
psStroke.Color = CONFIG.ACCENT_COLOR; psStroke.Thickness = 1.5

local psHeader = Instance.new("Frame", ParryStatsFrame)
psHeader.Size             = UDim2.new(1, 0, 0, 34)
psHeader.BackgroundColor3 = CONFIG.BG_MID
psHeader.BorderSizePixel  = 0
Instance.new("UICorner", psHeader).CornerRadius = UDim.new(0, 12)
local psHeaderFix = Instance.new("Frame", psHeader)
psHeaderFix.Size = UDim2.new(1,0,0,12); psHeaderFix.Position = UDim2.new(0,0,1,-12)
psHeaderFix.BackgroundColor3 = CONFIG.BG_MID; psHeaderFix.BorderSizePixel = 0

local psTitle = Instance.new("TextLabel", psHeader)
psTitle.Text = "⚔  AUTO PARRY STATS"
psTitle.Size = UDim2.new(1,-10,1,0); psTitle.Position = UDim2.new(0,10,0,0)
psTitle.BackgroundTransparency = 1; psTitle.TextColor3 = CONFIG.ACCENT_COLOR
psTitle.TextSize = 11; psTitle.Font = Enum.Font.GothamBold
psTitle.TextXAlignment = Enum.TextXAlignment.Left

local psAccent = Instance.new("Frame", psHeader)
psAccent.Size = UDim2.new(0.45,0,0,2); psAccent.Position = UDim2.new(0,10,1,-2)
psAccent.BackgroundColor3 = CONFIG.ACCENT_COLOR; psAccent.BorderSizePixel = 0
Instance.new("UICorner", psAccent).CornerRadius = UDim.new(1,0)

-- Glow on parry stats frame background
local psGlow = Instance.new("Frame", ParryStatsFrame)
psGlow.Size = UDim2.new(1,0,1,0); psGlow.BackgroundTransparency = 1; psGlow.ZIndex = 0
local psGlowGrad = Instance.new("UIGradient", psGlow)
psGlowGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, CONFIG.ACCENT_COLOR), ColorSequenceKeypoint.new(1, CONFIG.BG_DARK)})
psGlowGrad.Rotation = 135
psGlowGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.92), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1)})

local function makeStat(parent, yPos, label)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,-20,0,18); f.Position = UDim2.new(0,10,0,yPos)
    f.BackgroundTransparency = 1
    local k = Instance.new("TextLabel", f)
    k.Size = UDim2.new(0.55,0,1,0); k.BackgroundTransparency = 1
    k.TextColor3 = CONFIG.TEXT_SECONDARY; k.TextSize = 10; k.Font = Enum.Font.Gotham
    k.TextXAlignment = Enum.TextXAlignment.Left; k.Text = label
    local v = Instance.new("TextLabel", f)
    v.Name = "Value"
    v.Size = UDim2.new(0.45,0,1,0); v.Position = UDim2.new(0.55,0,0,0)
    v.BackgroundTransparency = 1
    v.TextColor3 = CONFIG.TEXT_PRIMARY; v.TextSize = 10; v.Font = Enum.Font.GothamBold
    v.TextXAlignment = Enum.TextXAlignment.Right; v.Text = "—"
    return v
end

local psStatStatus = makeStat(ParryStatsFrame, 42,  "Status")
local psStatRadius = makeStat(ParryStatsFrame, 63,  "Current Radius")
local psStatVel    = makeStat(ParryStatsFrame, 84,  "Ball Speed")
local psStatCount  = makeStat(ParryStatsFrame, 105, "Total Parrys")

makeDraggable(ParryStatsFrame, psHeader)

-- ══════════════════════════════════════════
--     GUI FLUTUANTE - AUTO SPAM STATS
-- ══════════════════════════════════════════
local SpamStatsGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
SpamStatsGui.Name           = "SpamStatsGui"
SpamStatsGui.ResetOnSpawn   = false
SpamStatsGui.IgnoreGuiInset = true
SpamStatsGui.Enabled        = false

local SpamStatsFrame = Instance.new("Frame", SpamStatsGui)
SpamStatsFrame.Size             = UDim2.new(0, 210, 0, 140)
SpamStatsFrame.Position         = UDim2.new(0, 80, 0.5, -10)
SpamStatsFrame.BackgroundColor3 = CONFIG.BG_DARK
SpamStatsFrame.BorderSizePixel  = 0
Instance.new("UICorner", SpamStatsFrame).CornerRadius = UDim.new(0, 12)
local ssStroke = Instance.new("UIStroke", SpamStatsFrame)
ssStroke.Color = CONFIG.DANGER; ssStroke.Thickness = 1.5

local ssHeader = Instance.new("Frame", SpamStatsFrame)
ssHeader.Size             = UDim2.new(1, 0, 0, 34)
ssHeader.BackgroundColor3 = CONFIG.BG_MID
ssHeader.BorderSizePixel  = 0
Instance.new("UICorner", ssHeader).CornerRadius = UDim.new(0, 12)
local ssHeaderFix = Instance.new("Frame", ssHeader)
ssHeaderFix.Size = UDim2.new(1,0,0,12); ssHeaderFix.Position = UDim2.new(0,0,1,-12)
ssHeaderFix.BackgroundColor3 = CONFIG.BG_MID; ssHeaderFix.BorderSizePixel = 0

local ssTitle = Instance.new("TextLabel", ssHeader)
ssTitle.Text = "⚡  AUTO SPAM STATS"
ssTitle.Size = UDim2.new(1,-10,1,0); ssTitle.Position = UDim2.new(0,10,0,0)
ssTitle.BackgroundTransparency = 1; ssTitle.TextColor3 = CONFIG.DANGER
ssTitle.TextSize = 11; ssTitle.Font = Enum.Font.GothamBold
ssTitle.TextXAlignment = Enum.TextXAlignment.Left

local ssAccent = Instance.new("Frame", ssHeader)
ssAccent.Size = UDim2.new(0.45,0,0,2); ssAccent.Position = UDim2.new(0,10,1,-2)
ssAccent.BackgroundColor3 = CONFIG.DANGER; ssAccent.BorderSizePixel = 0
Instance.new("UICorner", ssAccent).CornerRadius = UDim.new(1,0)

local ssGlow = Instance.new("Frame", SpamStatsFrame)
ssGlow.Size = UDim2.new(1,0,1,0); ssGlow.BackgroundTransparency = 1; ssGlow.ZIndex = 0
local ssGlowGrad = Instance.new("UIGradient", ssGlow)
ssGlowGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, CONFIG.DANGER), ColorSequenceKeypoint.new(1, CONFIG.BG_DARK)})
ssGlowGrad.Rotation = 135
ssGlowGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.92), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1)})

local ssStatStatus = makeStat(SpamStatsFrame, 42,  "Status")
local ssStatTarget = makeStat(SpamStatsFrame, 63,  "Target")
local ssStatMult   = makeStat(SpamStatsFrame, 84,  "Multiplier")
local ssStatCount  = makeStat(SpamStatsFrame, 105, "Total Fires")

makeDraggable(SpamStatsFrame, ssHeader)

-- ── Stats update loop ─────────
RunService.RenderStepped:Connect(function()
    if State.showParryStats then
        if State.autoParry then
            local curRadius
            if DETECTED_GAME == "anime" then
                curRadius = math.clamp(CONFIG.PARRY_DIST + math.floor(State.animeTrackedSpeed / 3.90), CONFIG.PARRY_DIST, 300)
            else
                curRadius = math.clamp(CONFIG.PARRY_DIST + math.floor(trackedSpeed / 5), CONFIG.PARRY_DIST, 300)
            end
            psStatStatus.Text = State.hasExecutedThisDetection and "🔴 Executed" or "🟢 Monitoring"
            psStatRadius.Text = string.format("%.1f st", curRadius)
            psStatVel.Text    = DETECTED_GAME == "anime"
                and string.format("%.1f s/s", State.animeTrackedSpeed)
                or  string.format("%.1f s/s", trackedSpeed)
        else
            psStatStatus.Text = "⚫ Inactive"
            psStatRadius.Text = "—"
            psStatVel.Text    = "—"
        end
        psStatCount.Text = tostring(State.parryCount)
    end

    if State.showSpamStats then
        ssStatStatus.Text = State.spamActive and "🔴 Spamming" or (State.autoSpam and "🟡 Waiting" or "⚫ Inactive")
        ssStatMult.Text   = "x" .. tostring(State.spamMultiplier)
        ssStatCount.Text  = tostring(State.spamCount)
        ssStatTarget.Text = State.savedSpamTarget or "None"
    end
end)

-- Toggles in the Visual tab
createToggle(VisualPage, "Show Parry Stats", "Shows Auto Parry stats panel", function(on)
    State.showParryStats  = on
    ParryStatsGui.Enabled = on
end)

createToggle(VisualPage, "Show Spam Stats", "Shows Auto Spam stats panel", function(on)
    State.showSpamStats  = on
    SpamStatsGui.Enabled = on
end)

-- Anime Ball: auto-activates both stats panels on load
if DETECTED_GAME == "anime" then
    State.showParryStats  = true
    State.showSpamStats   = true
    ParryStatsGui.Enabled = true
    SpamStatsGui.Enabled  = true
end

-- ══════════════════════════════════════════
--         VISUAL EFFECTS
-- ══════════════════════════════════════════

-- Particles
local particleContainer = Instance.new("Frame", MainFrame)
particleContainer.Size                   = UDim2.new(1, 0, 1, 0)
particleContainer.BackgroundTransparency = 1
particleContainer.ZIndex                 = 0
particleContainer.ClipsDescendants       = true

local function spawnParticle()
    local dot = Instance.new("Frame", particleContainer)
    dot.Size             = UDim2.new(0, math.random(2,5), 0, math.random(2,5))
    dot.Position         = UDim2.new(math.random(), 0, 1, 0)
    dot.BackgroundColor3 = (math.random() > 0.5) and CONFIG.ACCENT_COLOR or CONFIG.ACCENT_GLOW
    dot.BackgroundTransparency = 0.5
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    local dur = math.random(3, 7)
    TweenService:Create(dot, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
        Position = UDim2.new(dot.Position.X.Scale, 0, -0.1, 0),
        BackgroundTransparency = 1,
    }):Play()
    task.delay(dur, function() if dot.Parent then dot:Destroy() end end)
end

task.spawn(function()
    while true do
        task.wait(math.random() * 0.8 + 0.2)
        if MainFrame.Visible then spawnParticle() end
    end
end)

-- Scan line
local scanLine = Instance.new("Frame", MainFrame)
scanLine.Size                  = UDim2.new(1, 0, 0, 2)
scanLine.Position              = UDim2.new(0, 0, 0, 0)
scanLine.BackgroundColor3      = CONFIG.ACCENT_COLOR
scanLine.BackgroundTransparency = 0.85
scanLine.BorderSizePixel       = 0
scanLine.ZIndex                = 1

local scanGrad = Instance.new("UIGradient", scanLine)
scanGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,0,0)),
    ColorSequenceKeypoint.new(0.5, CONFIG.ACCENT_COLOR),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,0,0)),
})

task.spawn(function()
    while true do
        TweenService:Create(scanLine, TweenInfo.new(2.5, Enum.EasingStyle.Linear), {Position = UDim2.new(0,0,1,0)}):Play()
        task.wait(2.5)
        scanLine.Position = UDim2.new(0,0,0,0)
        task.wait(0.1)
    end
end)

-- ══════════════════════════════════════════
--         SETTINGS TAB
-- ══════════════════════════════════════════
local ConfigPage = createTab("Config", "⚙")

local configHeader = Instance.new("TextLabel", ConfigPage)
configHeader.Text                  = "SETTINGS"
configHeader.Size                  = UDim2.new(1, 0, 0, 18)
configHeader.BackgroundTransparency = 1
configHeader.TextColor3            = CONFIG.ACCENT_COLOR
configHeader.TextSize              = 10
configHeader.Font                  = Enum.Font.GothamBold
configHeader.TextXAlignment        = Enum.TextXAlignment.Left
configHeader.ZIndex                = 3

createSeparator(ConfigPage)

-- ── THEME SYSTEM ──────────────────────
local THEMES = {
    {
        name    = "Black & White",
        accent  = Color3.fromRGB(220, 220, 220),
        glow    = Color3.fromRGB(255, 255, 255),
        bgDark  = Color3.fromRGB(8,   8,   8),
        bgMid   = Color3.fromRGB(18,  18,  18),
        bgPanel = Color3.fromRGB(26,  26,  26),
        border  = Color3.fromRGB(55,  55,  55),
        toggleOn = Color3.fromRGB(200, 200, 200),
    },
    {
        name    = "Neon Purple",
        accent  = Color3.fromRGB(99,  102, 241),
        glow    = Color3.fromRGB(139, 92,  246),
        bgDark  = Color3.fromRGB(10,  10,  18),
        bgMid   = Color3.fromRGB(16,  16,  28),
        bgPanel = Color3.fromRGB(20,  20,  36),
        border  = Color3.fromRGB(40,  40,  70),
        toggleOn = Color3.fromRGB(99, 102, 241),
    },
    {
        name    = "Cyber Red",
        accent  = Color3.fromRGB(239, 68,  68),
        glow    = Color3.fromRGB(255, 120, 80),
        bgDark  = Color3.fromRGB(12,  8,   8),
        bgMid   = Color3.fromRGB(22,  12,  12),
        bgPanel = Color3.fromRGB(30,  15,  15),
        border  = Color3.fromRGB(70,  25,  25),
        toggleOn = Color3.fromRGB(239, 68,  68),
    },
    {
        name    = "Ocean Blue",
        accent  = Color3.fromRGB(56,  189, 248),
        glow    = Color3.fromRGB(99,  220, 255),
        bgDark  = Color3.fromRGB(4,   12,  20),
        bgMid   = Color3.fromRGB(8,   20,  36),
        bgPanel = Color3.fromRGB(12,  28,  48),
        border  = Color3.fromRGB(20,  60,  90),
        toggleOn = Color3.fromRGB(56, 189, 248),
    },
    {
        name    = "Matrix Green",
        accent  = Color3.fromRGB(34,  197, 94),
        glow    = Color3.fromRGB(74,  255, 128),
        bgDark  = Color3.fromRGB(4,   12,  6),
        bgMid   = Color3.fromRGB(8,   20,  10),
        bgPanel = Color3.fromRGB(10,  28,  14),
        border  = Color3.fromRGB(20,  60,  30),
        toggleOn = Color3.fromRGB(34, 197, 94),
    },
}

local currentThemeIndex = 1 -- Black & White default

-- Stores the previous theme to know which colors to replace
local previousTheme = nil

local function colorsEqual(a, b)
    return math.abs(a.R - b.R) < 0.01 and
           math.abs(a.G - b.G) < 0.01 and
           math.abs(a.B - b.B) < 0.01
end

local function remapColor(color, old, new)
    -- Returns the matching new color if current color matches old theme
    if colorsEqual(color, old.accent)  then return new.accent  end
    if colorsEqual(color, old.glow)    then return new.glow    end
    if colorsEqual(color, old.bgDark)  then return new.bgDark  end
    if colorsEqual(color, old.bgMid)   then return new.bgMid   end
    if colorsEqual(color, old.bgPanel) then return new.bgPanel end
    if colorsEqual(color, old.border)  then return new.border  end
    if colorsEqual(color, old.toggleOn) then return new.toggleOn end
    -- TOGGLE_OFF is always the same across all themes
    return nil
end

local function applyTheme(t)
    local old = previousTheme or {
        accent   = Color3.fromRGB(220, 220, 220),
        glow     = Color3.fromRGB(255, 255, 255),
        bgDark   = Color3.fromRGB(8,   8,   8),
        bgMid    = Color3.fromRGB(18,  18,  18),
        bgPanel  = Color3.fromRGB(26,  26,  26),
        border   = Color3.fromRGB(55,  55,  55),
        toggleOn = Color3.fromRGB(200, 200, 200),
    }
    previousTheme = t

    CONFIG.ACCENT_COLOR  = t.accent
    CONFIG.ACCENT_GLOW   = t.glow
    CONFIG.BG_DARK       = t.bgDark
    CONFIG.BG_MID        = t.bgMid
    CONFIG.BG_PANEL      = t.bgPanel
    CONFIG.BORDER_COLOR  = t.border
    CONFIG.TOGGLE_ON     = t.toggleOn

    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- ── Full scan of all MainFrame descendants ──
    local function scanAndUpdate(root)
        for _, obj in ipairs(root:GetDescendants()) do
            -- Frames and buttons: BackgroundColor3
            if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("ScrollingFrame") then
                local newBg = remapColor(obj.BackgroundColor3, old, t)
                if newBg then
                    TweenService:Create(obj, tweenInfo, {BackgroundColor3 = newBg}):Play()
                end
                -- ScrollingFrame: scrollbar color
                if obj:IsA("ScrollingFrame") then
                    if colorsEqual(obj.ScrollBarImageColor3, old.accent) then
                        obj.ScrollBarImageColor3 = t.accent
                    end
                end
            end
            -- TextLabels and TextBoxes: TextColor3
            if obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
                local newTxt = remapColor(obj.TextColor3, old, t)
                if newTxt then
                    TweenService:Create(obj, tweenInfo, {TextColor3 = newTxt}):Play()
                end
            end
            -- UIStroke: Color
            if obj:IsA("UIStroke") then
                local newStroke = remapColor(obj.Color, old, t)
                if newStroke then
                    TweenService:Create(obj, tweenInfo, {Color = newStroke}):Play()
                end
            end
        end
    end

    scanAndUpdate(MainFrame)

    -- Also updates floating menus in ScreenGui (dropdowns)
    for _, obj in ipairs(ScreenGui:GetDescendants()) do
        if obj:IsA("Frame") or obj:IsA("TextButton") then
            local newBg = remapColor(obj.BackgroundColor3, old, t)
            if newBg then
                TweenService:Create(obj, tweenInfo, {BackgroundColor3 = newBg}):Play()
            end
        end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local newTxt = remapColor(obj.TextColor3, old, t)
            if newTxt then
                TweenService:Create(obj, tweenInfo, {TextColor3 = newTxt}):Play()
            end
        end
        if obj:IsA("UIStroke") then
            local newStroke = remapColor(obj.Color, old, t)
            if newStroke then
                TweenService:Create(obj, tweenInfo, {Color = newStroke}):Play()
            end
        end
        if obj:IsA("ScrollingFrame") and colorsEqual(obj.ScrollBarImageColor3, old.accent) then
            obj.ScrollBarImageColor3 = t.accent
        end
    end

    -- ── Gradients (UIGradient does not support Tween, update directly) ──
    mainGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    t.glow),
        ColorSequenceKeypoint.new(0.35, t.accent),
        ColorSequenceKeypoint.new(0.65, t.bgMid),
        ColorSequenceKeypoint.new(1,    t.bgDark),
    })

    glowGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   t.accent),
        ColorSequenceKeypoint.new(0.5, t.bgDark),
        ColorSequenceKeypoint.new(1,   t.bgDark),
    })

    -- Title accentLine gradient
    local accentLineGrad = accentLine:FindFirstChildOfClass("UIGradient")
    if accentLineGrad then
        accentLineGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, t.accent),
            ColorSequenceKeypoint.new(1, t.glow),
        })
    end

    -- ScanLine gradient
    scanGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,0,0)),
        ColorSequenceKeypoint.new(0.5, t.accent),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,0,0)),
    })

    -- FloatBtn pulse (tween task already running, just fix base color)
    TweenService:Create(FloatBtn, tweenInfo, {BackgroundColor3 = t.accent}):Play()

    -- Re-aplica o estado da tab ativa para atualizar indicator e highlight
    if State.currentTab then
        selectTab(State.currentTab)
    end
end

-- Apply default theme on start
applyTheme(THEMES[currentThemeIndex])

-- ── Themes Dropdown ─────────────────────
local themeContainer = Instance.new("Frame", ConfigPage)
themeContainer.Size             = UDim2.new(1, 0, 0, 60)
themeContainer.BackgroundColor3 = CONFIG.BG_PANEL
themeContainer.BorderSizePixel  = 0
themeContainer.ZIndex           = 3
Instance.new("UICorner", themeContainer).CornerRadius = UDim.new(0, 10)
local themeStroke = Instance.new("UIStroke", themeContainer)
themeStroke.Color     = CONFIG.BORDER_COLOR
themeStroke.Thickness = 1

local themeLabel = Instance.new("TextLabel", themeContainer)
themeLabel.Text                  = "Interface Theme"
themeLabel.Size                  = UDim2.new(1, -80, 0, 20)
themeLabel.Position              = UDim2.new(0, 14, 0, 8)
themeLabel.BackgroundTransparency = 1
themeLabel.TextColor3            = CONFIG.TEXT_PRIMARY
themeLabel.TextSize              = 13
themeLabel.Font                  = Enum.Font.GothamSemibold
themeLabel.TextXAlignment        = Enum.TextXAlignment.Left
themeLabel.ZIndex                = 4

local themeDesc = Instance.new("TextLabel", themeContainer)
themeDesc.Text                  = "Customize the GUI colors"
themeDesc.Size                  = UDim2.new(1, -80, 0, 14)
themeDesc.Position              = UDim2.new(0, 14, 0, 30)
themeDesc.BackgroundTransparency = 1
themeDesc.TextColor3            = CONFIG.TEXT_SECONDARY
themeDesc.TextSize              = 10
themeDesc.Font                  = Enum.Font.Gotham
themeDesc.TextXAlignment        = Enum.TextXAlignment.Left
themeDesc.ZIndex                = 4

-- Theme dropdown button
local themeDdBtn = Instance.new("TextButton", themeContainer)
themeDdBtn.Size             = UDim2.new(0, 130, 0, 28)
themeDdBtn.Position         = UDim2.new(1, -142, 0.5, -14)
themeDdBtn.BackgroundColor3 = CONFIG.BG_MID
themeDdBtn.BorderSizePixel  = 0
themeDdBtn.TextColor3       = CONFIG.TEXT_PRIMARY
themeDdBtn.TextSize         = 11
themeDdBtn.Font             = Enum.Font.GothamSemibold
themeDdBtn.Text             = "⬛  Black & White"
themeDdBtn.TextXAlignment   = Enum.TextXAlignment.Left
themeDdBtn.ZIndex           = 10
Instance.new("UICorner", themeDdBtn).CornerRadius = UDim.new(0, 7)
local themeDdStroke = Instance.new("UIStroke", themeDdBtn)
themeDdStroke.Color = CONFIG.BORDER_COLOR; themeDdStroke.Thickness = 1
local themeDdPad = Instance.new("UIPadding", themeDdBtn)
themeDdPad.PaddingLeft = UDim.new(0, 8)

local themeDdArrow = Instance.new("TextLabel", themeDdBtn)
themeDdArrow.Text                  = "▾"
themeDdArrow.Size                  = UDim2.new(0, 18, 1, 0)
themeDdArrow.Position              = UDim2.new(1, -20, 0, 0)
themeDdArrow.BackgroundTransparency = 1
themeDdArrow.TextColor3            = CONFIG.TEXT_SECONDARY
themeDdArrow.TextSize              = 12
themeDdArrow.Font                  = Enum.Font.GothamBold
themeDdArrow.ZIndex                = 11

-- Theme dropdown menu
local themeDdMenu = Instance.new("Frame", ScreenGui)
themeDdMenu.Size             = UDim2.new(0, 0, 0, 0)
themeDdMenu.BackgroundColor3 = CONFIG.BG_MID
themeDdMenu.BorderSizePixel  = 0
themeDdMenu.Visible          = false
themeDdMenu.ZIndex           = 200
Instance.new("UICorner", themeDdMenu).CornerRadius = UDim.new(0, 8)
local themeDdMenuStroke = Instance.new("UIStroke", themeDdMenu)
themeDdMenuStroke.Color = CONFIG.ACCENT_COLOR; themeDdMenuStroke.Thickness = 1

local themeDdScroll = Instance.new("ScrollingFrame", themeDdMenu)
themeDdScroll.Size                = UDim2.new(1, -8, 1, -8)
themeDdScroll.Position            = UDim2.new(0, 4, 0, 4)
themeDdScroll.BackgroundTransparency = 1
themeDdScroll.BorderSizePixel     = 0
themeDdScroll.ScrollBarThickness  = 3
themeDdScroll.ScrollBarImageColor3 = CONFIG.ACCENT_COLOR
themeDdScroll.ZIndex              = 201

local themeDdLayout = Instance.new("UIListLayout", themeDdScroll)
themeDdLayout.FillDirection = Enum.FillDirection.Vertical
themeDdLayout.Padding       = UDim.new(0, 2)
themeDdLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    themeDdScroll.CanvasSize = UDim2.new(0, 0, 0, themeDdLayout.AbsoluteContentSize.Y)
end)

local themeIcons = {"⬛", "💜", "🔴", "🔵", "🟢"}
local themeDdOpen = false

local function closethemeDd()
    themeDdOpen = false
    TweenService:Create(themeDdMenu, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
        {Size = UDim2.new(0, themeDdMenu.Size.X.Offset, 0, 0)}):Play()
    task.delay(0.15, function() themeDdMenu.Visible = false end)
    TweenService:Create(themeDdArrow, TweenInfo.new(0.15), {Rotation = 0}):Play()
end

for i, theme in ipairs(THEMES) do
    local item = Instance.new("TextButton", themeDdScroll)
    item.Size             = UDim2.new(1, 0, 0, 30)
    item.BackgroundColor3 = CONFIG.BG_PANEL
    item.BackgroundTransparency = 0.3
    item.BorderSizePixel  = 0
    item.TextColor3       = CONFIG.TEXT_PRIMARY
    item.TextSize         = 11
    item.Font             = Enum.Font.GothamSemibold
    item.Text             = themeIcons[i] .. "  " .. theme.name
    item.TextXAlignment   = Enum.TextXAlignment.Left
    item.ZIndex           = 202
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
    local iPad = Instance.new("UIPadding", item)
    iPad.PaddingLeft = UDim.new(0, 8)

    -- Color indicator bar
    local colorBar = Instance.new("Frame", item)
    colorBar.Size             = UDim2.new(0, 3, 0.6, 0)
    colorBar.Position         = UDim2.new(0, 0, 0.2, 0)
    colorBar.BackgroundColor3 = theme.accent
    colorBar.BorderSizePixel  = 0
    colorBar.ZIndex           = 203
    Instance.new("UICorner", colorBar).CornerRadius = UDim.new(1, 0)

    item.MouseEnter:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = theme.accent, BackgroundTransparency = 0.75}):Play()
    end)
    item.MouseLeave:Connect(function()
        TweenService:Create(item, TweenInfo.new(0.1), {BackgroundColor3 = CONFIG.BG_PANEL, BackgroundTransparency = 0.3}):Play()
    end)

    local capturedIdx = i
    local capturedTheme = theme
    item.MouseButton1Click:Connect(function()
        currentThemeIndex = capturedIdx
        themeDdBtn.Text   = themeIcons[capturedIdx] .. "  " .. capturedTheme.name
        applyTheme(capturedTheme)
        closethemeDd()
        -- Update menu stroke on next open
        themeDdMenuStroke.Color  = capturedTheme.accent
        themeDdStroke.Color      = capturedTheme.accent
        themeStroke.Color        = capturedTheme.border
    end)
end

themeDdBtn.MouseButton1Click:Connect(function()
    themeDdOpen = not themeDdOpen
    if themeDdOpen then
        local absPos  = themeDdBtn.AbsolutePosition
        local absSize = themeDdBtn.AbsoluteSize
        local menuW   = absSize.X + 20
        local contentH = themeDdLayout.AbsoluteContentSize.Y + 8
        local menuH    = math.min(contentH, 170)
        themeDdMenu.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 4)
        themeDdMenu.Size     = UDim2.new(0, menuW, 0, 0)
        themeDdMenu.Visible  = true
        TweenService:Create(themeDdMenu, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, menuW, 0, menuH)}):Play()
        TweenService:Create(themeDdArrow, TweenInfo.new(0.15), {Rotation = 180}):Play()
    else
        closethemeDd()
    end
end)

createSeparator(ConfigPage)

-- ── Toggle: Transparency ─────────────────
local transparencyContainer = Instance.new("Frame", ConfigPage)
transparencyContainer.Size             = UDim2.new(1, 0, 0, 60)
transparencyContainer.BackgroundColor3 = CONFIG.BG_PANEL
transparencyContainer.BorderSizePixel  = 0
transparencyContainer.ZIndex           = 3
Instance.new("UICorner", transparencyContainer).CornerRadius = UDim.new(0, 10)
local transpStroke = Instance.new("UIStroke", transparencyContainer)
transpStroke.Color     = CONFIG.BORDER_COLOR
transpStroke.Thickness = 1

local transpLabel = Instance.new("TextLabel", transparencyContainer)
transpLabel.Text                  = "Transparency"
transpLabel.Size                  = UDim2.new(1, -80, 0, 22)
transpLabel.Position              = UDim2.new(0, 14, 0, 10)
transpLabel.BackgroundTransparency = 1
transpLabel.TextColor3            = CONFIG.TEXT_PRIMARY
transpLabel.TextSize              = 13
transpLabel.Font                  = Enum.Font.GothamSemibold
transpLabel.TextXAlignment        = Enum.TextXAlignment.Left
transpLabel.ZIndex                = 4

local transpDesc = Instance.new("TextLabel", transparencyContainer)
transpDesc.Text                  = "Makes background and tab bar 50% transparent"
transpDesc.Size                  = UDim2.new(1, -80, 0, 16)
transpDesc.Position              = UDim2.new(0, 14, 0, 33)
transpDesc.BackgroundTransparency = 1
transpDesc.TextColor3            = CONFIG.TEXT_SECONDARY
transpDesc.TextSize              = 10
transpDesc.Font                  = Enum.Font.Gotham
transpDesc.TextXAlignment        = Enum.TextXAlignment.Left
transpDesc.ZIndex                = 4

local transpTrack = Instance.new("Frame", transparencyContainer)
transpTrack.Size             = UDim2.new(0, 48, 0, 26)
transpTrack.Position         = UDim2.new(1, -62, 0.5, -13)
transpTrack.BackgroundColor3 = CONFIG.TOGGLE_OFF
transpTrack.BorderSizePixel  = 0
transpTrack.ZIndex           = 4
Instance.new("UICorner", transpTrack).CornerRadius = UDim.new(1, 0)

local transpThumb = Instance.new("Frame", transpTrack)
transpThumb.Size             = UDim2.new(0, 20, 0, 20)
transpThumb.Position         = UDim2.new(0, 3, 0.5, -10)
transpThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
transpThumb.BorderSizePixel  = 0
transpThumb.ZIndex           = 5
Instance.new("UICorner", transpThumb).CornerRadius = UDim.new(1, 0)

local transpState = false
local transpBusy  = false

local transpHitbox = Instance.new("TextButton", transparencyContainer)
transpHitbox.Size                  = UDim2.new(1, 0, 1, 0)
transpHitbox.BackgroundTransparency = 1
transpHitbox.Text                  = ""
transpHitbox.ZIndex                = 6

transpHitbox.MouseButton1Click:Connect(function()
    if transpBusy then return end
    transpBusy  = true
    transpState = not transpState

    if transpState then
        -- Turn on: toggle ON
        TweenService:Create(transpTrack, TweenInfo.new(0.25), {BackgroundColor3 = CONFIG.TOGGLE_ON}):Play()
        TweenService:Create(transpThumb, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 25, 0.5, -10)}):Play()
        -- Apply transparency
        TweenService:Create(MainFrame, TweenInfo.new(0.35), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(TabBar,    TweenInfo.new(0.35), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(TitleBar,  TweenInfo.new(0.35), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(titleFix,  TweenInfo.new(0.35), {BackgroundTransparency = 0.5}):Play()
    else
        -- Turn off: toggle OFF
        TweenService:Create(transpTrack, TweenInfo.new(0.25), {BackgroundColor3 = CONFIG.TOGGLE_OFF}):Play()
        TweenService:Create(transpThumb, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 3, 0.5, -10)}):Play()
        -- Remove transparency
        TweenService:Create(MainFrame, TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play()
        TweenService:Create(TabBar,    TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play()
        TweenService:Create(TitleBar,  TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play()
        TweenService:Create(titleFix,  TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play()
    end

    task.delay(0.3, function() transpBusy = false end)
end)

transpHitbox.MouseEnter:Connect(function()
    TweenService:Create(transparencyContainer, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26,26,46)}):Play()
    TweenService:Create(transpStroke, TweenInfo.new(0.15), {Color = CONFIG.ACCENT_COLOR}):Play()
end)
transpHitbox.MouseLeave:Connect(function()
    TweenService:Create(transparencyContainer, TweenInfo.new(0.15), {BackgroundColor3 = CONFIG.BG_PANEL}):Play()
    TweenService:Create(transpStroke, TweenInfo.new(0.15), {Color = CONFIG.BORDER_COLOR}):Play()
end)

createSeparator(ConfigPage)

-- Info de versão
local versionInfo = Instance.new("TextLabel", ConfigPage)
versionInfo.Text                  = "NEXUS HUB  v2.0  ·  Professional  ·  by NexusDev"
versionInfo.Size                  = UDim2.new(1, 0, 0, 18)
versionInfo.BackgroundTransparency = 1
versionInfo.TextColor3            = CONFIG.TEXT_SECONDARY
versionInfo.TextSize              = 9
versionInfo.Font                  = Enum.Font.Gotham
versionInfo.TextXAlignment        = Enum.TextXAlignment.Center
versionInfo.ZIndex                = 3

-- ══════════════════════════════════════════
--         INITIALIZATION
-- ══════════════════════════════════════════
selectTab("Combat")

MainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 440, 0, 320)
}):Play()

print("[NexusHub] ✓ Loaded successfully!")
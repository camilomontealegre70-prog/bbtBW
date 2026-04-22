-- ================================================
-- Bridger: WESTERN | Saint Corpse Collector
-- PUBLIX THEME Edition | Q = script pause · P = unload · Insert = open/close menu
-- ================================================

repeat task.wait(0.5) until game:IsLoaded()

local Players         = game:GetService("Players")
local UIS             = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")
local Lighting        = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
while not player do
    task.wait(0.5)
    player = Players.LocalPlayer
end

-- ============================================
-- CONFIG
-- ============================================
local WANTED_STANDS = {
    "StarPlatinum", "TheWorld", "Tusk", "Tusk2",
    "Tusk3", "Tusk4", "SoftAndWet", "TWAU",
    "TheWorldOverHeaven", "KingCrimson",
}

local TARGET_PARTS = {
    "SaintsRightArm", "SaintsLeftArm", "SaintsRightLeg",
    "SaintsLeftLeg", "SaintsRibcage",
}

local HOLD_E_INTERVAL   = 0.1
local FALLBACK_INTERVAL = 5
local LOAD_WAIT         = 3
local MAX_GROUND_DIST   = 15
local CLOSE_HIT_DIST    = 8
local MENU_BLUR_SIZE    = 10
local toggleKey         = Enum.KeyCode.Q       -- pause / resume script logic
local unloadKey         = Enum.KeyCode.P
local menuToggleKey     = Enum.KeyCode.Insert -- show / hide entire menu UI (change in Keybinds tab)

-- ============================================
-- PUBLIX THEME (+ dark “script hub” shell like Cerberus-style UIs)
-- ============================================
local PUBLIX_LOGO_ASSET_ID = "131474144341584"
-- rbxthumb often resolves when rbxassetid thumbnails fail in-game
local PUBLIX_LOGO_PRIMARY = "rbxthumb://type=Asset&id=" .. PUBLIX_LOGO_ASSET_ID .. "&w=420&h=420"
local PUBLIX_LOGO_FALLBACK = "rbxassetid://" .. PUBLIX_LOGO_ASSET_ID

local function applyPublixLogoImage(img)
    -- Try rbxassetid first (your upload), then rbxthumb (often works when direct image fails)
    img.Image = PUBLIX_LOGO_FALLBACK
    pcall(function()
        ContentProvider:PreloadAsync({img})
    end)
    task.delay(0.5, function()
        if img.Parent then
            img.Image = PUBLIX_LOGO_PRIMARY
            pcall(function()
                ContentProvider:PreloadAsync({img})
            end)
        end
    end)
end

local THEME = {
    PublixGreen     = Color3.fromRGB(0, 122, 51),     -- #007A33 Publix brand green
    PublixGreenDim  = Color3.fromRGB(0, 92, 38),      -- darker for pressed states
    PublixGreenLite = Color3.fromRGB(46, 160, 90),    -- accent / hover
    PublixGreenHi   = Color3.fromRGB(84, 190, 122),   -- gradient highlight
    LightBG         = Color3.fromRGB(248, 252, 248),  -- near-white with green tint
    LightBG2        = Color3.fromRGB(238, 246, 238),  -- sidebar / section rows
    CardBG          = Color3.fromRGB(255, 255, 255),
    TextDark        = Color3.fromRGB(28, 40, 32),
    TextMid         = Color3.fromRGB(82, 100, 88),
    TextOnGreen     = Color3.fromRGB(255, 255, 255),
    Muted           = Color3.fromRGB(130, 148, 135),
    DangerRed       = Color3.fromRGB(200, 60, 60),
    ToggleOff       = Color3.fromRGB(210, 218, 212),
    Divider         = Color3.fromRGB(228, 238, 230),
    CardBorder      = Color3.fromRGB(222, 234, 224),
    -- Dark shell (Cerebus / exploit-hub style) + Publix accents
    ShellWindow     = Color3.fromRGB(18, 19, 24),
    ShellHeader     = Color3.fromRGB(22, 23, 30),
    ShellSidebar    = Color3.fromRGB(26, 27, 34),
    ShellContent    = Color3.fromRGB(20, 21, 27),
    ShellCard       = Color3.fromRGB(32, 34, 42),
    ShellLine       = Color3.fromRGB(48, 52, 64),
    ShellText       = Color3.fromRGB(236, 237, 242),
    ShellMuted      = Color3.fromRGB(148, 152, 165),
    ShellToggleOff  = Color3.fromRGB(52, 55, 66),
    TabText         = Color3.fromRGB(205, 208, 218),
}

local FAST  = TweenInfo.new(0.16, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local SMOOTH= TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local BOUNCE= TweenInfo.new(0.55, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local GLIDE = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- ============================================
-- STATE
-- ============================================
local running          = true
local processing       = false
local autoWipeEnabled  = true
local collectorEnabled = true
local watchedParts     = {}
local pendingPart      = nil
local connections      = {}
local char, hrp, hum

-- Stands the script treats as “wanted” (editable in Stands tab)
local selectedStands = {}
for _, s in ipairs(WANTED_STANDS) do
    selectedStands[s] = true
end

local menuGuiOpen      = true
local menuGuiWasMinimized = false
local lastMenuToggleClock = 0
local MENU_TOGGLE_DEBOUNCE = 0.22

-- Forward declarations (must exist as upvalues before any closure references them)
local runStartupScan
local unloadScript
local setStatus
local setStand
local notify

-- ============================================
-- UI HELPERS
-- ============================================
local function tween(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.PublixGreen
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, p)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, p)
    pad.PaddingBottom = UDim.new(0, p)
    pad.PaddingLeft   = UDim.new(0, p)
    pad.PaddingRight  = UDim.new(0, p)
    pad.Parent = parent
    return pad
end

-- ============================================
-- SCREEN GUI (parent)
-- ============================================
local playerGui = player:WaitForChild("PlayerGui")
-- Remove any previous instance
pcall(function()
    local old = playerGui:FindFirstChild("BridgerPublix")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BridgerPublix"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

-- ============================================
-- MENU BACKDROP (blur + ambient gradient)
-- ============================================
local menuBlur = Lighting:FindFirstChild("BridgerMenuBlur") or Instance.new("BlurEffect")
menuBlur.Name = "BridgerMenuBlur"
menuBlur.Size = 0
menuBlur.Parent = Lighting
tween(menuBlur, GLIDE, {Size = MENU_BLUR_SIZE})

local Backdrop = Instance.new("Frame")
Backdrop.Name = "Backdrop"
Backdrop.Size = UDim2.new(1, 0, 1, 0)
Backdrop.BackgroundColor3 = Color3.fromRGB(8, 20, 12)
Backdrop.BackgroundTransparency = 0.3
Backdrop.BorderSizePixel = 0
Backdrop.ZIndex = -5
Backdrop.Parent = ScreenGui

local backdropGrad = Instance.new("UIGradient")
backdropGrad.Rotation = 115
backdropGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 36, 18)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(8, 20, 12)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 12, 7)),
})
backdropGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.15),
    NumberSequenceKeypoint.new(1, 0.35),
})
backdropGrad.Parent = Backdrop

local ambientOrbA = Instance.new("Frame")
ambientOrbA.Size = UDim2.new(0, 420, 0, 420)
ambientOrbA.Position = UDim2.new(0, -120, 0, -140)
ambientOrbA.BackgroundColor3 = THEME.PublixGreenLite
ambientOrbA.BackgroundTransparency = 0.86
ambientOrbA.BorderSizePixel = 0
ambientOrbA.ZIndex = -4
ambientOrbA.Parent = Backdrop
corner(ambientOrbA, 999)

local ambientOrbB = Instance.new("Frame")
ambientOrbB.Size = UDim2.new(0, 380, 0, 380)
ambientOrbB.Position = UDim2.new(1, -260, 1, -260)
ambientOrbB.BackgroundColor3 = THEME.PublixGreen
ambientOrbB.BackgroundTransparency = 0.9
ambientOrbB.BorderSizePixel = 0
ambientOrbB.ZIndex = -4
ambientOrbB.Parent = Backdrop
corner(ambientOrbB, 999)

-- ============================================
-- LOADING SPLASH (blur bg + spinning logo)
-- ============================================
local function showSplash()
    -- Lighting blur on the game world
    local blur = Lighting:FindFirstChild("BridgerBlur") or Instance.new("BlurEffect")
    blur.Name = "BridgerBlur"
    blur.Size = 0
    blur.Parent = Lighting
    tween(blur, GLIDE, {Size = 24})

    -- Full-screen dim overlay with subtle green tint
    local splash = Instance.new("Frame")
    splash.Name = "Splash"
    splash.Size = UDim2.new(1, 0, 1, 0)
    splash.BackgroundColor3 = Color3.fromRGB(8, 22, 14)
    splash.BackgroundTransparency = 1
    splash.BorderSizePixel = 0
    splash.ZIndex = 100
    splash.Parent = ScreenGui
    tween(splash, GLIDE, {BackgroundTransparency = 0.35})

    -- Glass card
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.new(0, 0, 0, 0)
    card.BackgroundColor3 = THEME.CardBG
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.ZIndex = 101
    card.Parent = splash
    corner(card, 24)
    stroke(card, THEME.PublixGreen, 1).Transparency = 0.55

    -- Logo (ring drawn first so it sits behind the image)
    local logoHolder = Instance.new("Frame")
    logoHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    logoHolder.Position = UDim2.new(0.5, 0, 0.5, -28)
    logoHolder.Size = UDim2.new(0, 120, 0, 120)
    logoHolder.BackgroundTransparency = 1
    logoHolder.ZIndex = 103
    logoHolder.Parent = card

    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.new(0.5, 0, 0.5, 0)
    ring.Size = UDim2.new(0, 140, 0, 140)
    ring.BackgroundTransparency = 1
    ring.ZIndex = 102
    ring.Parent = logoHolder
    local ringStroke = stroke(ring, THEME.PublixGreenLite, 2)
    ringStroke.Transparency = 0.45
    corner(ring, 999)

    local logo = Instance.new("ImageLabel")
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.new(0.5, 0, 0.5, 0)
    logo.Size = UDim2.new(1, 0, 1, 0)
    logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    logo.BackgroundTransparency = 0.82
    logo.BorderSizePixel = 0
    applyPublixLogoImage(logo)
    logo.ImageTransparency = 1
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Rotation = 0
    logo.ZIndex = 104
    logo.Parent = logoHolder
    corner(logo, 14)

    -- Title + subtitle
    local title = Instance.new("TextLabel")
    title.AnchorPoint = Vector2.new(0.5, 0)
    title.Position = UDim2.new(0.5, 0, 1, -84)
    title.Size = UDim2.new(1, -20, 0, 24)
    title.BackgroundTransparency = 1
    title.Text = "PUBLIX"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 22
    title.TextColor3 = THEME.PublixGreen
    title.TextTransparency = 1
    title.ZIndex = 103
    title.Parent = card

    local subtitle = Instance.new("TextLabel")
    subtitle.AnchorPoint = Vector2.new(0.5, 0)
    subtitle.Position = UDim2.new(0.5, 0, 1, -58)
    subtitle.Size = UDim2.new(1, -20, 0, 18)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Where Shopping is a Pleasure"
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextColor3 = THEME.ShellMuted
    subtitle.TextTransparency = 1
    subtitle.ZIndex = 103
    subtitle.Parent = card

    -- Progress bar
    local barBG = Instance.new("Frame")
    barBG.AnchorPoint = Vector2.new(0.5, 1)
    barBG.Position = UDim2.new(0.5, 0, 1, -22)
    barBG.Size = UDim2.new(1, -48, 0, 4)
    barBG.BackgroundColor3 = THEME.LightBG2
    barBG.BorderSizePixel = 0
    barBG.ZIndex = 103
    barBG.Parent = card
    corner(barBG, 2)

    local barFG = Instance.new("Frame")
    barFG.Size = UDim2.new(0, 0, 1, 0)
    barFG.BackgroundColor3 = THEME.PublixGreen
    barFG.BorderSizePixel = 0
    barFG.ZIndex = 104
    barFG.Parent = barBG
    corner(barFG, 2)

    local loadingText = Instance.new("TextLabel")
    loadingText.AnchorPoint = Vector2.new(0.5, 1)
    loadingText.Position = UDim2.new(0.5, 0, 1, -30)
    loadingText.Size = UDim2.new(1, -48, 0, 16)
    loadingText.BackgroundTransparency = 1
    loadingText.Text = "Loading 0%"
    loadingText.Font = Enum.Font.GothamMedium
    loadingText.TextSize = 11
    loadingText.TextColor3 = THEME.ShellMuted
    loadingText.TextTransparency = 1
    loadingText.ZIndex = 104
    loadingText.Parent = card

    -- Gradient on progress bar
    local barGrad = Instance.new("UIGradient")
    barGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.PublixGreen),
        ColorSequenceKeypoint.new(1, THEME.PublixGreenHi),
    })
    barGrad.Parent = barFG

    -- Animate in
    tween(card, BOUNCE, {Size = UDim2.new(0, 340, 0, 280)})
    task.wait(0.2)
    logo.Size = UDim2.new(0.55, 0, 0.55, 0)
    tween(logo,     SMOOTH, {ImageTransparency = 0})
    tween(logo,     BOUNCE, {Size = UDim2.new(1, 0, 1, 0)})
    tween(title,    SMOOTH, {TextTransparency = 0})
    tween(subtitle, SMOOTH, {TextTransparency = 0})
    tween(loadingText, SMOOTH, {TextTransparency = 0})
    task.spawn(function()
        for pct = 0, 100, 5 do
            if not splash.Parent then return end
            loadingText.Text = ("Loading %d%%"):format(pct)
            barFG.Size = UDim2.new(pct / 100, 0, 1, 0)
            task.wait(0.08)
        end
    end)

    task.wait(1.8)

    -- Animate out
    tween(splash, SMOOTH, {BackgroundTransparency = 1})
    tween(card,   SMOOTH, {Size = UDim2.new(0, 0, 0, 0)})
    tween(logo,   FAST,   {ImageTransparency = 1})
    tween(title,  FAST,   {TextTransparency = 1})
    tween(subtitle, FAST, {TextTransparency = 1})
    tween(loadingText, FAST, {TextTransparency = 1})
    tween(blur,   GLIDE,  {Size = 0})
    task.wait(0.45)
    splash:Destroy()
    pcall(function() blur:Destroy() end)
end

task.spawn(showSplash)

-- ============================================
-- MAIN WINDOW (modern + sleek)
-- ============================================
local Window = Instance.new("Frame")
Window.Name = "Window"
Window.AnchorPoint = Vector2.new(0.5, 0.5)
Window.Position = UDim2.new(0.5, 0, 0.5, 0)
Window.Size = UDim2.new(0, 0, 0, 0) -- animated in
Window.BackgroundColor3 = THEME.ShellWindow
Window.BorderSizePixel = 0
Window.ClipsDescendants = true
Window.Parent = ScreenGui
corner(Window, 20)

-- Accent outline (script-hub style)
local winStroke = stroke(Window, THEME.PublixGreen, 1)
winStroke.Transparency = 0.65

-- Soft drop shadow (outside the window)
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.new(0.5, 0, 0.5, 10)
shadow.Size = UDim2.new(1, 60, 1, 60)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.55
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(49, 49, 450, 450)
shadow.ZIndex = 0
shadow.Parent = Window

-- ============================================
-- HEADER (gradient + logo + title)
-- ============================================
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 64)
Header.BackgroundColor3 = THEME.ShellHeader
Header.BorderSizePixel = 0
Header.Parent = Window
corner(Header, 20)

-- Subtle depth on dark header
local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 36, 46)),
    ColorSequenceKeypoint.new(1, THEME.ShellHeader),
})
headerGrad.Rotation = 90
headerGrad.Parent = Header

-- Publix accent strip (Cerberus-style top bar accent)
local HeaderAccent = Instance.new("Frame")
HeaderAccent.Name = "Accent"
HeaderAccent.Position = UDim2.new(0, 0, 1, -2)
HeaderAccent.Size = UDim2.new(1, 0, 0, 2)
HeaderAccent.BackgroundColor3 = THEME.PublixGreen
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header

-- Logo only (wordmark is in title area — avoids overlapping “BRIDGER CONTROL”)
local HeaderLogo = Instance.new("ImageLabel")
HeaderLogo.Name = "Logo"
HeaderLogo.AnchorPoint = Vector2.new(0, 0.5)
HeaderLogo.Position = UDim2.new(0, 14, 0.5, 0)
HeaderLogo.Size = UDim2.new(0, 44, 0, 44)
HeaderLogo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HeaderLogo.BackgroundTransparency = 0.88
HeaderLogo.BorderSizePixel = 0
applyPublixLogoImage(HeaderLogo)
HeaderLogo.ImageTransparency = 1
HeaderLogo.ScaleType = Enum.ScaleType.Fit
HeaderLogo.Parent = Header
corner(HeaderLogo, 10)

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.AnchorPoint = Vector2.new(0, 0.5)
HeaderTitle.Position = UDim2.new(0, 68, 0.5, -9)
HeaderTitle.Size = UDim2.new(1, -268, 0, 20)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "BRIDGER CONTROL"
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 15
HeaderTitle.TextColor3 = THEME.ShellText
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Parent = Header

local HeaderSub = Instance.new("TextLabel")
HeaderSub.AnchorPoint = Vector2.new(0, 0.5)
HeaderSub.Position = UDim2.new(0, 68, 0.5, 11)
HeaderSub.Size = UDim2.new(1, -268, 0, 16)
HeaderSub.BackgroundTransparency = 1
HeaderSub.Text = "Publix Edition  |  Saint Corpse Collector"
HeaderSub.Font = Enum.Font.Gotham
HeaderSub.TextSize = 11
HeaderSub.TextColor3 = THEME.ShellMuted
HeaderSub.TextXAlignment = Enum.TextXAlignment.Left
HeaderSub.TextTransparency = 0.05
HeaderSub.Parent = Header

local HeaderBadge = Instance.new("TextLabel")
HeaderBadge.AnchorPoint = Vector2.new(1, 0.5)
HeaderBadge.Position = UDim2.new(1, -208, 0.5, 0)
HeaderBadge.Size = UDim2.new(0, 120, 0, 24)
HeaderBadge.BackgroundColor3 = THEME.ShellCard
HeaderBadge.BackgroundTransparency = 0.2
HeaderBadge.Text = "PUBLIX STYLE"
HeaderBadge.Font = Enum.Font.GothamBold
HeaderBadge.TextSize = 10
HeaderBadge.TextColor3 = THEME.PublixGreenLite
HeaderBadge.Parent = Header
corner(HeaderBadge, 999)
local badgeStroke = stroke(HeaderBadge, THEME.PublixGreen, 1)
badgeStroke.Transparency = 0.55

-- Window controls (minimize + close) with circular minimalist style
local function makeControlBtn(text, xOffset)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, xOffset, 0.5, 0)
    b.Size = UDim2.new(0, 28, 0, 28)
    b.BackgroundColor3 = THEME.ShellCard
    b.BackgroundTransparency = 0.35
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.TextColor3 = THEME.ShellText
    b.AutoButtonColor = false
    b.Parent = Header
    corner(b, 999)
    return b
end
local MinBtn   = makeControlBtn("–", -52)
local CloseBtn = makeControlBtn("×", -16)

for _, btn in ipairs({CloseBtn, MinBtn}) do
    btn.MouseEnter:Connect(function()
        tween(btn, FAST, {BackgroundTransparency = 0.55})
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, FAST, {BackgroundTransparency = 0.35})
    end)
end

-- ============================================
-- SIDEBAR (tabs)
-- ============================================
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Position = UDim2.new(0, 0, 0, 64)
TabBar.Size = UDim2.new(0, 160, 1, -64)
TabBar.BackgroundColor3 = THEME.ShellSidebar
TabBar.BackgroundTransparency = 0
TabBar.BorderSizePixel = 0
TabBar.ZIndex = 3
TabBar.ClipsDescendants = false
TabBar.Parent = Window
corner(TabBar, 20)

-- Right-edge divider
local TabDivider = Instance.new("Frame")
TabDivider.AnchorPoint = Vector2.new(1, 0)
TabDivider.Position = UDim2.new(1, 0, 0, 0)
TabDivider.Size = UDim2.new(0, 1, 1, 0)
TabDivider.BackgroundColor3 = THEME.ShellLine
TabDivider.BorderSizePixel = 0
TabDivider.ZIndex = 10
TabDivider.Parent = TabBar

padding(TabBar, 12)

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Name = "TabScroll"
TabScroll.Position = UDim2.new(0, 0, 0, 0)
TabScroll.Size = UDim2.new(1, 0, 1, 0)
TabScroll.BackgroundTransparency = 1
TabScroll.BorderSizePixel = 0
TabScroll.ZIndex = 2
TabScroll.ScrollBarThickness = 6
TabScroll.ScrollBarImageColor3 = THEME.PublixGreen
TabScroll.ScrollBarImageTransparency = 0.35
TabScroll.ScrollingDirection = Enum.ScrollingDirection.Y
TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TabScroll.ClipsDescendants = true
TabScroll.Parent = TabBar

local TabList = Instance.new("UIListLayout")
TabList.Padding = UDim.new(0, 4)
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabList.VerticalAlignment = Enum.VerticalAlignment.Top
TabList.Parent = TabScroll

local ContentArea = Instance.new("Frame")
ContentArea.Name = "Content"
ContentArea.Position = UDim2.new(0, 160, 0, 64)
ContentArea.Size = UDim2.new(1, -160, 1, -64)
ContentArea.BackgroundColor3 = THEME.ShellContent
ContentArea.BorderSizePixel = 0
ContentArea.ZIndex = 2
ContentArea.Parent = Window
corner(ContentArea, 20)

local contentGrad = Instance.new("UIGradient")
contentGrad.Rotation = 100
contentGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 30, 38)),
    ColorSequenceKeypoint.new(1, THEME.ShellContent),
})
contentGrad.Parent = ContentArea

local tabs = {}
local activeTab = nil

local function setActiveTab(tabData)
    if activeTab == tabData then return end
    for _, t in ipairs(tabs) do
        t.Page.Visible = (t == tabData)
        local active = (t == tabData)
        tween(t.Button, FAST, {
            BackgroundTransparency = active and 0.28 or 0.9,
            BackgroundColor3 = THEME.ShellCard,
        })
        tween(t.Label, FAST, {
            TextColor3 = active and THEME.PublixGreenLite or THEME.TabText
        })
        tween(t.Icon, FAST, {
            TextColor3 = active and THEME.PublixGreenLite or THEME.TabText
        })
        tween(t.Stroke, FAST, {
            Transparency = active and 0.25 or 1
        })
        tween(t.Indicator, SMOOTH, {
            Size = active and UDim2.new(0, 3, 0.6, 0) or UDim2.new(0, 3, 0, 0),
            BackgroundTransparency = active and 0 or 1,
        })
    end
    if tabData and tabData.Page then
        tabData.Page.Position = UDim2.new(0, 14, 0, 0)
        for _, c in ipairs(tabData.Page:GetChildren()) do
            if c:IsA("GuiObject") then c.Visible = true end
        end
        tween(tabData.Page, GLIDE, {Position = UDim2.new(0, 0, 0, 0)})
    end
    activeTab = tabData
end

local function createTab(name, iconText)
    local tabIndex = #tabs + 1
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -4, 0, 38)
    btn.BackgroundColor3 = THEME.ShellCard
    btn.BackgroundTransparency = 0.9
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.ZIndex = 4
    btn.LayoutOrder = tabIndex
    btn.Parent = TabScroll
    corner(btn, 10)
    local btnStroke = stroke(btn, THEME.ShellLine, 1)
    btnStroke.Transparency = 1

    -- Left indicator pill
    local indicator = Instance.new("Frame")
    indicator.AnchorPoint = Vector2.new(0, 0.5)
    indicator.Position = UDim2.new(0, 0, 0.5, 0)
    indicator.Size = UDim2.new(0, 3, 0, 0)
    indicator.BackgroundColor3 = THEME.PublixGreen
    indicator.BackgroundTransparency = 1
    indicator.BorderSizePixel = 0
    indicator.Parent = btn
    corner(indicator, 2)

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 22, 1, 0)
    icon.Position = UDim2.new(0, 12, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = iconText or "[ ]"
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 12
    icon.TextColor3 = THEME.TabText
    icon.TextXAlignment = Enum.TextXAlignment.Left
    icon.ZIndex = 5
    icon.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -38, 1, 0)
    lbl.Position = UDim2.new(0, 34, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextColor3 = THEME.TabText
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 5
    lbl.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.PublixGreen
    page.ScrollBarImageTransparency = 0.3
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = ContentArea
    padding(page, 18)

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 10)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = page

    local tab = { Button = btn, Label = lbl, Icon = icon, Page = page, Indicator = indicator, Stroke = btnStroke }
    table.insert(tabs, tab)

    btn.MouseButton1Click:Connect(function() setActiveTab(tab) end)
    btn.MouseEnter:Connect(function()
        if activeTab ~= tab then
            tween(btn, FAST, {BackgroundTransparency = 0.72})
            tween(btnStroke, FAST, {Transparency = 0.35})
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab then
            tween(btn, FAST, {BackgroundTransparency = 0.9})
            tween(btnStroke, FAST, {Transparency = 1})
        end
    end)

    return tab
end

-- ============================================
-- CONTROL BUILDERS (modern / sleek)
-- ============================================
local function addWrappedNote(tab, text)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundColor3 = THEME.ShellCard
    holder.BorderSizePixel = 0
    holder.Parent = tab.Page
    corner(holder, 10)
    local holderStroke = stroke(holder, THEME.ShellLine, 1)
    holderStroke.Transparency = 0.55
    padding(holder, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.ShellText
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextWrapped = true
    lbl.Parent = holder

    return {
        Set = function(_, t) lbl.Text = t end,
    }
end

local function addSection(tab, title)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 22)
    holder.BackgroundTransparency = 1
    holder.Parent = tab.Page

    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, 0, 1, 0)
    s.BackgroundTransparency = 1
    s.Text = string.upper(title)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 11
    s.TextColor3 = THEME.ShellMuted
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = holder
    return holder
end

local function addLabel(tab, text)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.BackgroundColor3 = THEME.ShellCard
    holder.BorderSizePixel = 0
    holder.Parent = tab.Page
    corner(holder, 10)
    local holderStroke = stroke(holder, THEME.ShellLine, 1)
    holderStroke.Transparency = 0.55

    -- Subtle green accent dot
    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Position = UDim2.new(0, 14, 0.5, 0)
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.BackgroundColor3 = THEME.PublixGreenLite
    dot.BorderSizePixel = 0
    dot.Parent = holder
    corner(dot, 999)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -36, 1, 0)
    lbl.Position = UDim2.new(0, 28, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = THEME.ShellText
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder

    return {
        Set = function(_, t) lbl.Text = t end,
        _label = lbl,
    }
end

local function addToggle(tab, name, initial, callback)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, 0, 0, 44)
    holder.BackgroundColor3 = THEME.ShellCard
    holder.AutoButtonColor = false
    holder.Text = ""
    holder.Parent = tab.Page
    corner(holder, 10)
    local holderStroke = stroke(holder, THEME.ShellLine, 1)
    holderStroke.Transparency = 0.55

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -76, 1, 0)
    lbl.Position = UDim2.new(0, 16, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextColor3 = THEME.ShellText
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder

    -- iOS-style track
    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -14, 0.5, 0)
    track.Size = UDim2.new(0, 44, 0, 24)
    track.BackgroundColor3 = initial and THEME.PublixGreen or THEME.ShellToggleOff
    track.BorderSizePixel = 0
    track.Parent = holder
    corner(track, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = initial and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 999)

    -- Tiny knob shadow
    local knobShadow = Instance.new("ImageLabel")
    knobShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    knobShadow.Position = UDim2.new(0.5, 0, 0.5, 1)
    knobShadow.Size = UDim2.new(1, 8, 1, 8)
    knobShadow.BackgroundTransparency = 1
    knobShadow.Image = "rbxassetid://6014261993"
    knobShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    knobShadow.ImageTransparency = 0.8
    knobShadow.ScaleType = Enum.ScaleType.Slice
    knobShadow.SliceCenter = Rect.new(49, 49, 450, 450)
    knobShadow.ZIndex = 0
    knobShadow.Parent = knob

    local value = initial and true or false

    local function set(v)
        value = v and true or false
        tween(track, FAST, {BackgroundColor3 = value and THEME.PublixGreen or THEME.ShellToggleOff})
        tween(knob, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        })
        if callback then task.spawn(callback, value) end
    end

    holder.MouseButton1Click:Connect(function() set(not value) end)
    holder.MouseEnter:Connect(function()
        tween(holder, FAST, {BackgroundColor3 = Color3.fromRGB(40, 42, 52)})
        tween(holderStroke, FAST, {Transparency = 0.25})
    end)
    holder.MouseLeave:Connect(function()
        tween(holder, FAST, {BackgroundColor3 = THEME.ShellCard})
        tween(holderStroke, FAST, {Transparency = 0.55})
    end)

    return {
        Set = function(_, v) set(v) end,
        Get = function() return value end,
    }
end

local function addButton(tab, name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = THEME.PublixGreen
    btn.AutoButtonColor = false
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextColor3 = THEME.TextOnGreen
    btn.Parent = tab.Page
    corner(btn, 10)
    local btnStroke = stroke(btn, THEME.PublixGreenHi, 1)
    btnStroke.Transparency = 0.35

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.PublixGreenLite),
        ColorSequenceKeypoint.new(1, THEME.PublixGreen),
    })
    grad.Rotation = 90
    grad.Parent = btn

    btn.MouseEnter:Connect(function()
        tween(btn, FAST, {BackgroundColor3 = THEME.PublixGreenLite})
        tween(btnStroke, FAST, {Transparency = 0.1})
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, FAST, {BackgroundColor3 = THEME.PublixGreen})
        tween(btnStroke, FAST, {Transparency = 0.35})
    end)
    btn.MouseButton1Down:Connect(function()
        tween(btn, FAST, {BackgroundColor3 = THEME.PublixGreenDim})
    end)
    btn.MouseButton1Up:Connect(function()
        tween(btn, FAST, {BackgroundColor3 = THEME.PublixGreenLite})
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback) end
    end)

    return btn
end

-- ============================================
-- BUILD TABS
-- ============================================
local MainTab    = createTab("Main", "[M]")
local KeybindTab = createTab("Keybinds", "[K]")
local StandTab   = createTab("Stands", "[S]")
local InfoTab    = createTab("About", "[I]")

addSection(MainTab, "Info")
local StatusElement = addLabel(MainTab, "Status: Waiting...")
local StandElement  = addLabel(MainTab, "Last Stand: None")
local RuntimeElement = addLabel(MainTab, "Run Time: 00:00:00")

addSection(MainTab, "Selected stands")
local SelectedStandsElement = addWrappedNote(MainTab, "")

local function refreshSelectedStandsSummary()
    local names = {}
    for _, s in ipairs(WANTED_STANDS) do
        if selectedStands[s] then
            table.insert(names, s)
        end
    end
    if #names == 0 then
        SelectedStandsElement:Set("None selected. The script will not treat any roll as “wanted” until you enable at least one stand in the Stands tab.")
    else
        SelectedStandsElement:Set("Wanted when rolled:\n" .. table.concat(names, ", "))
    end
end
refreshSelectedStandsSummary()

addSection(MainTab, "Features")
local collectorToggleCtl
collectorToggleCtl = addToggle(MainTab, "Auto Collector", collectorEnabled, function(s)
    collectorEnabled = s
    print("[GUI] Collector: " .. (s and "ON" or "OFF"))
end)

local wipeToggleCtl = addToggle(MainTab, "Auto Wipe", autoWipeEnabled, function(s)
    autoWipeEnabled = s
    print("[GUI] Auto Wipe: " .. (s and "ON" or "OFF"))
end)

addSection(MainTab, "Control")
local masterToggleCtl
masterToggleCtl = addToggle(MainTab, "Script Active", running, function(s)
    running = s
    if running then
        setStatus("Resumed!")
        task.spawn(function() runStartupScan() end)
    else
        processing = false
        setStatus("Paused")
    end
end)

addButton(MainTab, "Unload Script", function() unloadScript() end)

addSection(KeybindTab, "Open / close menu")
addWrappedNote(KeybindTab, "Toggles the whole Bridger window (backdrop + UI). Change the key below if Insert conflicts with your game.")

addSection(KeybindTab, "Current keys")
local KeybindReadout = addWrappedNote(KeybindTab, "")

local function refreshKeybindReadout()
    KeybindReadout:Set(table.concat({
        "• Open / close menu     →  " .. menuToggleKey.Name,
        "• Script pause / resume →  " .. toggleKey.Name,
        "• Unload script         →  " .. unloadKey.Name,
    }, "\n"))
end

addSection(KeybindTab, "Rebind")
local keybindCaptureActive = false

local function bindKey(kind)
    if keybindCaptureActive then return end
    keybindCaptureActive = true

    local captureLabel = ({
        ScriptToggle = "script pause / resume",
        Unload = "unload script",
        MenuToggle = "open / close menu",
    })[kind] or kind
    notify("Keybind capture", "Press a keyboard key for: " .. captureLabel, 3)
    local conn
    conn = UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local chosen = input.KeyCode
        if chosen == Enum.KeyCode.Unknown then return end
        conn:Disconnect()
        keybindCaptureActive = false

        if kind == "ScriptToggle" then
            toggleKey = chosen
            notify("Keybind updated", "Script pause key: " .. toggleKey.Name, 3)
        elseif kind == "Unload" then
            unloadKey = chosen
            notify("Keybind updated", "Unload key: " .. unloadKey.Name, 3)
        elseif kind == "MenuToggle" then
            menuToggleKey = chosen
            notify("Keybind updated", "Open/close menu key: " .. menuToggleKey.Name, 3)
        end
        refreshKeybindReadout()
    end)
end

addButton(KeybindTab, "Set open / close menu key", function()
    bindKey("MenuToggle")
end)
addButton(KeybindTab, "Set script pause key", function()
    bindKey("ScriptToggle")
end)
addButton(KeybindTab, "Set unload key", function()
    bindKey("Unload")
end)

refreshKeybindReadout()

addSection(StandTab, "Stand filter")
addWrappedNote(StandTab, "Turn stands ON to count as wanted when you roll. OFF = unwanted (auto-wipe can still apply).")

addSection(StandTab, "Select stands")
for _, stand in ipairs(WANTED_STANDS) do
    addToggle(StandTab, stand, selectedStands[stand], function(on)
        selectedStands[stand] = on
        refreshSelectedStandsSummary()
    end)
end

addSection(InfoTab, "About")
addLabel(InfoTab, "Bridger · Publix Edition")
addLabel(InfoTab, "Theme: Publix Green")
addLabel(InfoTab, "Use the Keybinds tab to see and change hotkeys.")
addLabel(InfoTab, "Where Shopping is a Pleasure")

-- Start on Main tab
setActiveTab(MainTab)

-- ============================================
-- NOTIFICATIONS
-- ============================================
local NotifRoot = Instance.new("Frame")
NotifRoot.AnchorPoint = Vector2.new(1, 1)
NotifRoot.Position = UDim2.new(1, -20, 1, -20)
NotifRoot.Size = UDim2.new(0, 300, 1, -40)
NotifRoot.BackgroundTransparency = 1
NotifRoot.Parent = ScreenGui

local NotifList = Instance.new("UIListLayout")
NotifList.Padding = UDim.new(0, 8)
NotifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifList.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotifList.SortOrder = Enum.SortOrder.LayoutOrder
NotifList.Parent = NotifRoot

notify = function(title, body, duration)
    duration = duration or 4
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 300, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.ShellCard
    card.BorderSizePixel = 0
    card.Position = UDim2.new(1, 320, 0, 0)
    card.Parent = NotifRoot
    corner(card, 12)
    local s = stroke(card, THEME.ShellLine, 1)
    s.Transparency = 0.45

    -- Soft shadow
    local sh = Instance.new("ImageLabel")
    sh.AnchorPoint = Vector2.new(0.5, 0.5)
    sh.Position = UDim2.new(0.5, 0, 0.5, 6)
    sh.Size = UDim2.new(1, 30, 1, 30)
    sh.BackgroundTransparency = 1
    sh.Image = "rbxassetid://6014261993"
    sh.ImageColor3 = Color3.fromRGB(0, 0, 0)
    sh.ImageTransparency = 0.82
    sh.ScaleType = Enum.ScaleType.Slice
    sh.SliceCenter = Rect.new(49, 49, 450, 450)
    sh.ZIndex = 0
    sh.Parent = card

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 4, 1, 0)
    bar.BackgroundColor3 = THEME.PublixGreen
    bar.BorderSizePixel = 0
    bar.Parent = card

    local logoBG = Instance.new("Frame")
    logoBG.Position = UDim2.new(0, 14, 0, 12)
    logoBG.Size = UDim2.new(0, 30, 0, 30)
    logoBG.BackgroundColor3 = THEME.ShellSidebar
    logoBG.BorderSizePixel = 0
    logoBG.Parent = card
    corner(logoBG, 999)

    local logo = Instance.new("ImageLabel")
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.new(0.5, 0, 0.5, 0)
    logo.Size = UDim2.new(0, 22, 0, 22)
    logo.BackgroundTransparency = 1
    applyPublixLogoImage(logo)
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Parent = logoBG

    local t = Instance.new("TextLabel")
    t.Position = UDim2.new(0, 54, 0, 10)
    t.Size = UDim2.new(1, -64, 0, 18)
    t.BackgroundTransparency = 1
    t.Text = title
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.TextColor3 = THEME.PublixGreen
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = card

    local b = Instance.new("TextLabel")
    b.Position = UDim2.new(0, 54, 0, 28)
    b.Size = UDim2.new(1, -64, 0, 0)
    b.AutomaticSize = Enum.AutomaticSize.Y
    b.BackgroundTransparency = 1
    b.Text = body
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.TextColor3 = THEME.ShellMuted
    b.TextWrapped = true
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = card

    local spacer = Instance.new("Frame")
    spacer.Size = UDim2.new(1, 0, 0, 52)
    spacer.BackgroundTransparency = 1
    spacer.Parent = card

    -- slide in
    tween(card, GLIDE, {Position = UDim2.new(1, 0, 0, 0)})
    task.delay(duration, function()
        local out = TweenService:Create(card, SMOOTH, {Position = UDim2.new(1, 320, 0, 0)})
        out:Play()
        out.Completed:Connect(function() card:Destroy() end)
    end)
end

-- ============================================
-- STATUS SETTERS
-- ============================================
setStatus = function(text)
    StatusElement:Set("Status: " .. text)
    print("[Status] " .. text)
end

setStand = function(text)
    StandElement:Set("Last Stand: " .. text)
    print("[Stand] " .. text)
end

local startClock = os.clock()
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        local elapsed = math.max(0, math.floor(os.clock() - startClock))
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = elapsed % 60
        RuntimeElement:Set(string.format("Run Time: %02d:%02d:%02d", h, m, s))
        task.wait(1)
    end
end)

-- ============================================
-- WINDOW ANIMATIONS
-- ============================================
local TARGET_WIN_SIZE = UDim2.new(0, 620, 0, 400)
local minimized = false

local function setMenuBackdropExpanded(expanded)
    if expanded then
        Backdrop.Visible = true
        tween(Backdrop, SMOOTH, {BackgroundTransparency = 0.3})
        tween(menuBlur, GLIDE, {Size = MENU_BLUR_SIZE})
    else
        tween(menuBlur, FAST, {Size = 0})
        tween(Backdrop, FAST, {BackgroundTransparency = 1})
        task.delay(0.35, function()
            if Backdrop.Parent then
                Backdrop.Visible = false
            end
        end)
    end
end

task.spawn(function()
    task.wait(2.0) -- wait for splash
    if menuGuiOpen then
        tween(Window, BOUNCE, {Size = TARGET_WIN_SIZE})
        tween(HeaderLogo, SMOOTH, {ImageTransparency = 0})
    end
end)

local function minimizeWindow()
    if not menuGuiOpen then return end
    minimized = not minimized
    if minimized then
        setMenuBackdropExpanded(false)
        tween(Window, SMOOTH, {Size = UDim2.new(0, 620, 0, 64)})
    else
        setMenuBackdropExpanded(true)
        tween(Window, SMOOTH, {Size = TARGET_WIN_SIZE})
    end
end

local function syncMenuGuiVisibility()
    Window.Visible = menuGuiOpen
    if not menuGuiOpen then
        menuGuiWasMinimized = minimized
        setMenuBackdropExpanded(false)
        return
    end
    minimized = menuGuiWasMinimized
    if minimized then
        tween(Window, FAST, {Size = UDim2.new(0, 620, 0, 64)})
        setMenuBackdropExpanded(false)
    else
        tween(Window, GLIDE, {Size = TARGET_WIN_SIZE})
        setMenuBackdropExpanded(true)
    end
end

local function closeWindow()
    tween(Window, SMOOTH, {Size = UDim2.new(0, 0, 0, 0)})
end

local function openWindow()
    minimized = false
    menuGuiWasMinimized = false
    menuGuiOpen = true
    syncMenuGuiVisibility()
end

MinBtn.MouseButton1Click:Connect(minimizeWindow)
CloseBtn.MouseButton1Click:Connect(function()
    closeWindow()
    task.wait(0.4)
    unloadScript()
end)

-- ============================================
-- DRAGGING
-- ============================================
do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Window.Position
        end
    end)
    Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                        startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ============================================
-- UNLOAD
-- ============================================
unloadScript = function()
    running = false
    processing = false
    print("[Script] Unloading...")

    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}

    pcall(function()
        tween(Window, SMOOTH, {Size = UDim2.new(0, 0, 0, 0)})
    end)
    task.wait(0.4)
    pcall(function() menuBlur:Destroy() end)
    pcall(function() ScreenGui:Destroy() end)
    print("[Script] Unloaded!")
end

-- ============================================
-- TOGGLE
-- ============================================
local function toggleScript()
    running = not running
    masterToggleCtl:Set(running)
    if running then
        setStatus("Resumed!")
        task.spawn(function() runStartupScan() end)
    else
        processing = false
        setStatus("Paused")
    end
end

table.insert(connections, UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if i.KeyCode == menuToggleKey then
        local now = os.clock()
        if now - lastMenuToggleClock < MENU_TOGGLE_DEBOUNCE then return end
        lastMenuToggleClock = now
        menuGuiOpen = not menuGuiOpen
        syncMenuGuiVisibility()
        return
    end
    if not menuGuiOpen then return end
    if i.KeyCode == toggleKey then toggleScript() end
    if i.KeyCode == unloadKey then unloadScript() end
end))

-- ============================================
-- REAL PART VALIDATOR
-- ============================================
local function isRealPart(obj)
    if not (obj:IsA("BasePart") or obj:IsA("MeshPart")) then return false end

    local nameMatch = false
    for _, n in ipairs(TARGET_PARTS) do
        if obj.Name == n then nameMatch = true break end
    end
    if not nameMatch then return false end
    if obj:GetAttribute("IsCorpsePart") ~= true then return false end
    if obj.Parent ~= workspace then return false end

    local exclusions = {obj}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(exclusions, p.Character) end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclusions

    local directions = {
        Vector3.new(0,   -500, 0),
        Vector3.new(0,    500, 0),
        Vector3.new(500,  0,   0),
        Vector3.new(-500, 0,   0),
        Vector3.new(0,    0,   500),
        Vector3.new(0,    0,  -500),
    }

    local closeHits = 0
    local downDist  = nil

    for i, dir in ipairs(directions) do
        local result = workspace:Raycast(obj.Position, dir, params)
        if result then
            local dist = (obj.Position - result.Position).Magnitude
            if dist <= CLOSE_HIT_DIST then
                closeHits = closeHits + 1
            end
            if i == 1 then
                downDist = obj.Position.Y - result.Position.Y
            end
        end
    end

    if closeHits >= 4 then
        print("[Detector] FAKE — buried (" .. closeHits .. " close hits): " .. obj.Name)
        return false
    end

    if not downDist then
        print("[Detector] FAKE — no ground below: " .. obj.Name)
        return false
    end

    if downDist > MAX_GROUND_DIST then
        print("[Detector] FAKE — too high (" .. math.floor(downDist) .. "s): " .. obj.Name)
        return false
    end

    print("[Detector] REAL — " .. closeHits .. " close hits | " .. math.floor(downDist) .. " studs from ground: " .. obj.Name)
    return true
end

-- ============================================
-- PICKUP
-- ============================================
local function tryPickup(obj)
    if not obj or not obj.Parent then return end
    local prompt = obj:FindFirstChild("PickupPrompt")
    if not prompt then print("[Pickup] No prompt found") return end

    if hrp then
        local dist = (hrp.Position - obj.Position).Magnitude
        if dist > prompt.MaxActivationDistance then
            print("[Pickup] Too far (" .. math.floor(dist) .. " studs) — moving closer...")
            hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
            task.wait(0.2)
        end
    end

    print("[Pickup] Firing prompt for " .. prompt.HoldDuration .. "s...")
    setStatus("Picking up " .. obj.Name .. "...")

    local t = 0
    local holdTime = prompt.HoldDuration + 0.5
    while t < holdTime do
        if not running then return end
        if not obj or not obj.Parent then return end
        if obj:GetAttribute("BeingPickedUp") or obj.Parent ~= workspace then return end
        fireproximityprompt(prompt)
        task.wait(HOLD_E_INTERVAL)
        t = t + HOLD_E_INTERVAL
    end

    print("[Pickup] ✓ Done: " .. obj.Name)
    setStatus("Collected! Merging...")
end

-- ============================================
-- STAND DETECTION
-- ============================================
local function isWanted(name)
    return selectedStands[name] == true
end

local function clickWipe()
    local pgui = player:FindFirstChild("PlayerGui")
    if not pgui then return end

    local btn = nil
    local attempts = 0
    while not btn and attempts < 20 do
        attempts = attempts + 1
        for _, o in ipairs(pgui:GetDescendants()) do
            if o.Name == "WipeButton" and o.Visible then
                btn = o
                break
            end
        end
        if not btn then task.wait(0.5) end
    end
    if not btn then print("[Wipe] Button not found!") return end

    pcall(function() btn.MouseButton1Down:Fire() end)
    task.wait(0.1)
    pcall(function() btn.MouseButton1Up:Fire() end)
    task.wait(0.1)
    pcall(function() btn.MouseButton1Click:Fire() end)

    local t = 0
    while btn.Text ~= "ARE YOU SURE?" and t < 5 do
        task.wait(0.1)
        t = t + 0.1
    end
    if btn.Text ~= "ARE YOU SURE?" then return end

    task.wait(0.2)
    pcall(function() btn.MouseButton1Down:Fire() end)
    task.wait(0.1)
    pcall(function() btn.MouseButton1Up:Fire() end)
    task.wait(0.1)
    pcall(function() btn.MouseButton1Click:Fire() end)
    print("[Wipe] ✓ Confirmed!")
    setStatus("Wiped! Clicking Play...")
    task.wait(1)

    for _, o in ipairs(pgui:GetDescendants()) do
        if o.Name == "PlayButton" and o.Visible then
            pcall(function() o.MouseButton1Down:Fire() end)
            task.wait(0.1)
            pcall(function() o.MouseButton1Up:Fire() end)
            task.wait(0.1)
            pcall(function() o.MouseButton1Click:Fire() end)
            print("[Wipe] Play clicked!")
            break
        end
    end
end

local function watchForStand()
    local c = player.Character
    if not c then return end
    setStatus("Watching for stand...")
    table.insert(connections, c.ChildAdded:Connect(function(obj)
        if not running then return end
        if obj:IsA("Model") and obj.Name:find("Model") then
            local standName = obj.Name:gsub("Model", "")
            print("[Stand] Got: " .. standName)
            setStand(standName)
            if isWanted(standName) then
                setStatus("✓ Got " .. standName .. "!")
                notify("✓ Wanted Stand!", "Got: " .. standName, 6)
            else
                setStatus("✗ Unwanted: " .. standName .. " — wiping...")
                notify("✗ Unwanted Stand", standName .. " — auto wiping...", 4)
                if autoWipeEnabled then
                    task.wait(2)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
                end
            end
        end
    end))
end

-- ============================================
-- RESPAWN TELEPORT
-- ============================================
local function respawnTo(part)
    if not running then return end
    setStatus("Teleporting...")

    char = player.Character
    if not char then processing = false return end
    hum = char:FindFirstChild("Humanoid")
    if not hum then processing = false return end

    hum.Health = 0

    local newChar = player.CharacterAdded:Wait()
    char = newChar
    hrp  = char:WaitForChild("HumanoidRootPart")
    hum  = char:WaitForChild("Humanoid")

    if not running then processing = false return end

    if not part or not part.Parent or not isRealPart(part) then
        setStatus("Part gone!")
        processing = false
        return
    end

    hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    task.wait(0.3)

    if not part or not part.Parent then
        processing = false
        return
    end

    if part:GetAttribute("BeingPickedUp") then
        processing = false
        return
    end

    watchForStand()
    tryPickup(part)
    task.wait(0.5)

    setStatus("Waiting for spawn...")
    pendingPart = nil
    processing  = false
end

-- ============================================
-- COLLECT
-- ============================================
local function collect(part)
    if not collectorEnabled or not running or processing then return end
    processing = true
    pendingPart = part
    setStatus("Found: " .. part.Name)
    notify("★ Part Detected!", part.Name .. " found — teleporting!", 4)
    task.spawn(function() respawnTo(part) end)
end

-- ============================================
-- WATCH PART
-- ============================================
local function watchPart(obj)
    local key = "w_" .. obj:GetDebugId()
    if watchedParts[key] then return end
    watchedParts[key] = true

    table.insert(connections, obj:GetPropertyChangedSignal("Position"):Connect(function()
        if not running or watchedParts[obj] then return end
        task.wait(0.1)
        if isRealPart(obj) then
            watchedParts[obj] = true
            print("[Watcher] Position valid: " .. obj.Name)
            if not processing then collect(obj) end
        end
    end))

    table.insert(connections, obj.AttributeChanged:Connect(function(attr)
        if not running then return end
        if attr == "BeingPickedUp" and obj:GetAttribute("BeingPickedUp") and pendingPart == obj then
            print("[Watcher] Part taken!")
            processing = false
            pendingPart = nil
            setStatus("Part taken! Waiting...")
        end
    end))
end

-- ============================================
-- STARTUP SCAN
-- ============================================
runStartupScan = function()
    if not running then return end
    if not setStatus then return end
    setStatus("Scanning...")

    char = player.Character or player.CharacterAdded:Wait()
    hrp  = char:WaitForChild("HumanoidRootPart")
    hum  = char:WaitForChild("Humanoid")

    local found = false
    for _, obj in ipairs(workspace:GetDescendants()) do
        for _, n in ipairs(TARGET_PARTS) do
            if obj.Name == n and (obj:IsA("BasePart") or obj:IsA("MeshPart")) then
                watchPart(obj)
                if isRealPart(obj) and not watchedParts[obj] then
                    watchedParts[obj] = true
                    found = true
                    print("[Scan] Found: " .. obj.Name)
                    if not processing then collect(obj) end
                end
                break
            end
        end
    end

    if not found then
        setStatus("Watching for spawns...")
    end
end

-- ============================================
-- SPAWN WATCHER
-- ============================================
table.insert(connections, workspace.DescendantAdded:Connect(function(obj)
    if not running then return end
    for _, n in ipairs(TARGET_PARTS) do
        if obj.Name == n and (obj:IsA("BasePart") or obj:IsA("MeshPart")) then
            task.wait(0.2)
            watchPart(obj)
            if not watchedParts[obj] and isRealPart(obj) then
                watchedParts[obj] = true
                if not processing then collect(obj) end
            end
            break
        end
    end
end))

-- ============================================
-- FALLBACK LOOP
-- ============================================
task.spawn(function()
    while true do
        task.wait(FALLBACK_INTERVAL)
        if running and not processing then
            char = player.Character
            if char then
                hrp = char:FindFirstChild("HumanoidRootPart")
                hum = char:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if isRealPart(obj) and not watchedParts[obj] then
                            watchedParts[obj] = true
                            collect(obj)
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================
-- WIPE HANDLER ON REJOIN
-- ============================================
task.spawn(function()
    task.wait(2)
    local pgui = player:FindFirstChild("PlayerGui")
    if not pgui then return end
    for _, o in ipairs(pgui:GetDescendants()) do
        if o.Name == "WipeButton" and o.Visible and autoWipeEnabled then
            setStatus("Wiping character...")
            clickWipe()
            break
        end
    end
end)

-- ============================================
-- ENTRY POINT
-- ============================================
setStatus("Waiting for Play click...")
print("[Script] Loaded! Q = toggle | P = unload | " .. menuToggleKey.Name .. " = menu")
notify(
    "Publix Edition",
    "Keys: " .. menuToggleKey.Name .. " = open/close menu · " .. toggleKey.Name .. " = pause script · " .. unloadKey.Name .. " = unload.",
    6
)

local _ = player.Character or player.CharacterAdded:Wait()
task.wait(LOAD_WAIT)
runStartupScan()
print("[Script] Active!")

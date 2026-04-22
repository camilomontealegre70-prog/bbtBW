-- ================================================
-- Bridger: WESTERN | Saint Corpse Collector
-- PUBLIX THEME Edition | Q = toggle | P = unload
-- ================================================

repeat task.wait(0.5) until game:IsLoaded()

local Players         = game:GetService("Players")
local UIS             = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")
local Lighting        = game:GetService("Lighting")

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
local TOGGLE_KEY        = Enum.KeyCode.Q
local UNLOAD_KEY        = Enum.KeyCode.P

-- ============================================
-- PUBLIX THEME
-- ============================================
local PUBLIX_LOGO_ID = "rbxassetid://131474144341584"

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

-- Forward declarations (must exist as upvalues before any closure references them)
local runStartupScan
local unloadScript
local setStatus
local setStand

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
    corner(card, 20)
    stroke(card, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.5

    -- Logo (spins)
    local logoHolder = Instance.new("Frame")
    logoHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    logoHolder.Position = UDim2.new(0.5, 0, 0.5, -24)
    logoHolder.Size = UDim2.new(0, 120, 0, 120)
    logoHolder.BackgroundTransparency = 1
    logoHolder.ZIndex = 103
    logoHolder.Parent = card

    local logo = Instance.new("ImageLabel")
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.new(0.5, 0, 0.5, 0)
    logo.Size = UDim2.new(1, 0, 1, 0)
    logo.BackgroundTransparency = 1
    logo.Image = PUBLIX_LOGO_ID
    logo.ImageTransparency = 1
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Rotation = 0
    logo.ZIndex = 104
    logo.Parent = logoHolder

    -- Orbit ring behind logo
    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.new(0.5, 0, 0.5, 0)
    ring.Size = UDim2.new(0, 140, 0, 140)
    ring.BackgroundTransparency = 1
    ring.ZIndex = 102
    ring.Parent = logoHolder
    local ringStroke = stroke(ring, THEME.PublixGreenLite, 2)
    ringStroke.Transparency = 0.6
    corner(ring, 999)

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
    subtitle.TextColor3 = THEME.TextMid
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

    -- Gradient on progress bar
    local barGrad = Instance.new("UIGradient")
    barGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.PublixGreen),
        ColorSequenceKeypoint.new(1, THEME.PublixGreenHi),
    })
    barGrad.Parent = barFG

    -- Continuous spin on logo
    local spinning = true
    task.spawn(function()
        local rot = 0
        while spinning and logo.Parent do
            rot = (rot + 3) % 360
            logo.Rotation = rot
            task.wait(1 / 60)
        end
    end)

    -- Animate in
    tween(card, BOUNCE, {Size = UDim2.new(0, 340, 0, 280)})
    task.wait(0.2)
    tween(logo,     SMOOTH, {ImageTransparency = 0})
    tween(title,    SMOOTH, {TextTransparency = 0})
    tween(subtitle, SMOOTH, {TextTransparency = 0})
    tween(barFG,    TweenInfo.new(1.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)})

    task.wait(1.8)

    -- Animate out
    spinning = false
    tween(splash, SMOOTH, {BackgroundTransparency = 1})
    tween(card,   SMOOTH, {Size = UDim2.new(0, 0, 0, 0)})
    tween(logo,   FAST,   {ImageTransparency = 1})
    tween(title,  FAST,   {TextTransparency = 1})
    tween(subtitle, FAST, {TextTransparency = 1})
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
Window.BackgroundColor3 = THEME.LightBG
Window.BorderSizePixel = 0
Window.ClipsDescendants = true
Window.Parent = ScreenGui
corner(Window, 16)

-- Subtle 1px hairline border
local winStroke = stroke(Window, Color3.fromRGB(215, 228, 218), 1)
winStroke.Transparency = 0.2

-- Soft drop shadow (outside the window)
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.new(0.5, 0, 0.5, 10)
shadow.Size = UDim2.new(1, 60, 1, 60)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(0, 30, 14)
shadow.ImageTransparency = 0.7
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
Header.BackgroundColor3 = THEME.PublixGreen
Header.BorderSizePixel = 0
Header.Parent = Window

-- Gradient adds depth
local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, THEME.PublixGreenLite),
    ColorSequenceKeypoint.new(1, THEME.PublixGreen),
})
headerGrad.Rotation = 90
headerGrad.Parent = Header

-- Thin divider beneath header
local HeaderDivider = Instance.new("Frame")
HeaderDivider.Position = UDim2.new(0, 0, 1, 0)
HeaderDivider.Size = UDim2.new(1, 0, 0, 1)
HeaderDivider.BackgroundColor3 = THEME.Divider
HeaderDivider.BorderSizePixel = 0
HeaderDivider.Parent = Header

-- Logo in header
local HeaderLogo = Instance.new("ImageLabel")
HeaderLogo.Name = "Logo"
HeaderLogo.AnchorPoint = Vector2.new(0, 0.5)
HeaderLogo.Position = UDim2.new(0, 16, 0.5, 0)
HeaderLogo.Size = UDim2.new(0, 40, 0, 40)
HeaderLogo.BackgroundTransparency = 1
HeaderLogo.Image = PUBLIX_LOGO_ID
HeaderLogo.ScaleType = Enum.ScaleType.Fit
HeaderLogo.Parent = Header

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.AnchorPoint = Vector2.new(0, 0.5)
HeaderTitle.Position = UDim2.new(0, 66, 0.5, -9)
HeaderTitle.Size = UDim2.new(1, -180, 0, 20)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "Bridger"
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 17
HeaderTitle.TextColor3 = THEME.TextOnGreen
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Parent = Header

local HeaderSub = Instance.new("TextLabel")
HeaderSub.AnchorPoint = Vector2.new(0, 0.5)
HeaderSub.Position = UDim2.new(0, 66, 0.5, 11)
HeaderSub.Size = UDim2.new(1, -180, 0, 16)
HeaderSub.BackgroundTransparency = 1
HeaderSub.Text = "Publix Edition · Saint Corpse Collector"
HeaderSub.Font = Enum.Font.Gotham
HeaderSub.TextSize = 11
HeaderSub.TextColor3 = Color3.fromRGB(220, 245, 225)
HeaderSub.TextXAlignment = Enum.TextXAlignment.Left
HeaderSub.TextTransparency = 0.15
HeaderSub.Parent = Header

-- Window controls (minimize + close) with circular minimalist style
local function makeControlBtn(text, xOffset)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, xOffset, 0.5, 0)
    b.Size = UDim2.new(0, 28, 0, 28)
    b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundTransparency = 0.82
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.TextColor3 = THEME.TextOnGreen
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
        tween(btn, FAST, {BackgroundTransparency = 0.82})
    end)
end

-- ============================================
-- SIDEBAR (tabs)
-- ============================================
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Position = UDim2.new(0, 0, 0, 64)
TabBar.Size = UDim2.new(0, 160, 1, -64)
TabBar.BackgroundColor3 = THEME.LightBG2
TabBar.BackgroundTransparency = 0.25
TabBar.BorderSizePixel = 0
TabBar.Parent = Window

-- Right-edge divider
local TabDivider = Instance.new("Frame")
TabDivider.AnchorPoint = Vector2.new(1, 0)
TabDivider.Position = UDim2.new(1, 0, 0, 0)
TabDivider.Size = UDim2.new(0, 1, 1, 0)
TabDivider.BackgroundColor3 = THEME.Divider
TabDivider.BorderSizePixel = 0
TabDivider.Parent = TabBar

local TabList = Instance.new("UIListLayout")
TabList.Padding = UDim.new(0, 4)
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Parent = TabBar
padding(TabBar, 12)

local ContentArea = Instance.new("Frame")
ContentArea.Name = "Content"
ContentArea.Position = UDim2.new(0, 160, 0, 64)
ContentArea.Size = UDim2.new(1, -160, 1, -64)
ContentArea.BackgroundColor3 = THEME.LightBG
ContentArea.BorderSizePixel = 0
ContentArea.Parent = Window

local tabs = {}
local activeTab = nil

local function setActiveTab(tabData)
    if activeTab == tabData then return end
    for _, t in ipairs(tabs) do
        t.Page.Visible = (t == tabData)
        local active = (t == tabData)
        tween(t.Button, FAST, {
            BackgroundTransparency = active and 0 or 1,
            BackgroundColor3 = active and THEME.CardBG or THEME.CardBG,
        })
        tween(t.Label, FAST, {
            TextColor3 = active and THEME.PublixGreen or THEME.TextMid
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

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = THEME.CardBG
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.Parent = TabBar
    corner(btn, 10)

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

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 1, 0)
    lbl.Position = UDim2.new(0, 16, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextColor3 = THEME.TextMid
    lbl.TextXAlignment = Enum.TextXAlignment.Left
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

    local tab = { Button = btn, Label = lbl, Page = page, Indicator = indicator }
    table.insert(tabs, tab)

    btn.MouseButton1Click:Connect(function() setActiveTab(tab) end)
    btn.MouseEnter:Connect(function()
        if activeTab ~= tab then
            tween(btn, FAST, {BackgroundTransparency = 0.6})
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab then
            tween(btn, FAST, {BackgroundTransparency = 1})
        end
    end)

    return tab
end

-- ============================================
-- CONTROL BUILDERS (modern / sleek)
-- ============================================
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
    s.TextColor3 = THEME.Muted
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = holder
    return holder
end

local function addLabel(tab, text)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.BackgroundColor3 = THEME.CardBG
    holder.BorderSizePixel = 0
    holder.Parent = tab.Page
    corner(holder, 10)

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
    lbl.TextColor3 = THEME.TextDark
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
    holder.BackgroundColor3 = THEME.CardBG
    holder.AutoButtonColor = false
    holder.Text = ""
    holder.Parent = tab.Page
    corner(holder, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -76, 1, 0)
    lbl.Position = UDim2.new(0, 16, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextColor3 = THEME.TextDark
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder

    -- iOS-style track
    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -14, 0.5, 0)
    track.Size = UDim2.new(0, 44, 0, 24)
    track.BackgroundColor3 = initial and THEME.PublixGreen or THEME.ToggleOff
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
        tween(track, FAST, {BackgroundColor3 = value and THEME.PublixGreen or THEME.ToggleOff})
        tween(knob, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        })
        if callback then task.spawn(callback, value) end
    end

    holder.MouseButton1Click:Connect(function() set(not value) end)
    holder.MouseEnter:Connect(function()
        tween(holder, FAST, {BackgroundColor3 = Color3.fromRGB(250, 254, 250)})
    end)
    holder.MouseLeave:Connect(function()
        tween(holder, FAST, {BackgroundColor3 = THEME.CardBG})
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

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.PublixGreenLite),
        ColorSequenceKeypoint.new(1, THEME.PublixGreen),
    })
    grad.Rotation = 90
    grad.Parent = btn

    btn.MouseEnter:Connect(function()
        tween(btn, FAST, {BackgroundColor3 = THEME.PublixGreenLite})
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, FAST, {BackgroundColor3 = THEME.PublixGreen})
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
local MainTab  = createTab("Main")
local StandTab = createTab("Stands")
local InfoTab  = createTab("About")

addSection(MainTab, "Info")
local StatusElement = addLabel(MainTab, "Status: Waiting...")
local StandElement  = addLabel(MainTab, "Last Stand: None")

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
masterToggleCtl = addToggle(MainTab, "Script Active [Q]", running, function(s)
    running = s
    if running then
        setStatus("Resumed!")
        task.spawn(function() runStartupScan() end)
    else
        processing = false
        setStatus("Paused")
    end
end)

addButton(MainTab, "Unload Script [P]", function() unloadScript() end)

addSection(StandTab, "Wanted Stands")
for _, stand in ipairs(WANTED_STANDS) do
    addLabel(StandTab, "✓ " .. stand)
end

addSection(InfoTab, "About")
addLabel(InfoTab, "Bridger · Publix Edition")
addLabel(InfoTab, "Theme: Publix Green")
addLabel(InfoTab, "Hotkeys: Q = toggle, P = unload")
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

local function notify(title, body, duration)
    duration = duration or 4
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 300, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.CardBG
    card.BorderSizePixel = 0
    card.Position = UDim2.new(1, 320, 0, 0)
    card.Parent = NotifRoot
    corner(card, 12)
    local s = stroke(card, THEME.Divider, 1)
    s.Transparency = 0.3

    -- Soft shadow
    local sh = Instance.new("ImageLabel")
    sh.AnchorPoint = Vector2.new(0.5, 0.5)
    sh.Position = UDim2.new(0.5, 0, 0.5, 6)
    sh.Size = UDim2.new(1, 30, 1, 30)
    sh.BackgroundTransparency = 1
    sh.Image = "rbxassetid://6014261993"
    sh.ImageColor3 = Color3.fromRGB(0, 30, 14)
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
    logoBG.BackgroundColor3 = THEME.LightBG2
    logoBG.BorderSizePixel = 0
    logoBG.Parent = card
    corner(logoBG, 999)

    local logo = Instance.new("ImageLabel")
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.new(0.5, 0, 0.5, 0)
    logo.Size = UDim2.new(0, 22, 0, 22)
    logo.BackgroundTransparency = 1
    logo.Image = PUBLIX_LOGO_ID
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
    b.TextColor3 = THEME.TextMid
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

-- ============================================
-- WINDOW ANIMATIONS
-- ============================================
local TARGET_WIN_SIZE = UDim2.new(0, 620, 0, 400)
local minimized = false

task.spawn(function()
    task.wait(2.0) -- wait for splash
    tween(Window, BOUNCE, {Size = TARGET_WIN_SIZE})
end)

local function minimizeWindow()
    minimized = not minimized
    if minimized then
        tween(Window, SMOOTH, {Size = UDim2.new(0, 620, 0, 64)})
    else
        tween(Window, SMOOTH, {Size = TARGET_WIN_SIZE})
    end
end

local function closeWindow()
    tween(Window, SMOOTH, {Size = UDim2.new(0, 0, 0, 0)})
end

local function openWindow()
    tween(Window, BOUNCE, {Size = TARGET_WIN_SIZE})
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
    if i.KeyCode == TOGGLE_KEY then toggleScript() end
    if i.KeyCode == UNLOAD_KEY then unloadScript() end
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
    for _, s in ipairs(WANTED_STANDS) do
        if s == name then return true end
    end
    return false
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
print("[Script] Loaded! Q = toggle | P = unload")
notify("Publix Edition", "Script loaded. Press Q to pause, P to unload.", 5)

local _ = player.Character or player.CharacterAdded:Wait()
task.wait(LOAD_WAIT)
runStartupScan()
print("[Script] Active!")


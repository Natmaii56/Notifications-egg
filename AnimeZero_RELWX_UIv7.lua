-- ============================================================
--  RELWX | Anime Zero (KAITUN) | UI v7 edition
--  - ฟังก์ชันครบทุกตัวจาก Anime Zero source (farm / gacha / lobby / player / ESP / webhook)
--  - UI library: RELWX HUB UI v7 (แนบไฟล์) + Legacy API adapter
--  - KAITUN SETTINGS: ค้นหา "KAITUN SETTINGS" ในไฟล์นี้เพื่อแก้ค่า
-- ============================================================
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local SCRIPT_VERSION = "Relwx UI v7"
local GAME_NAME = "Relwx"
local GAME_KEY = "Relwx"

local function createRelwxUI()
--// ============================================================
--//  RELWX HUB  |  UI v7  (UI ONLY — ไม่มีฟังก์ชันเกม)
--//  - ปรับขนาดตามหน้าจออัตโนมัติ (+ ปรับเพิ่ม/ลดเองได้ในตั้งค่า)
--//  - ทุกอย่างผูกกับ Config และเซฟอัตโนมัติ
--//  - เพิ่มฟังก์ชันใหม่: ดูหัวข้อ "ADD YOUR FUNCTIONS"
--// ============================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

-- ฟอนต์ UI  (เปลี่ยนได้: "Montserrat" | "BuilderSans" | "Gotham")
local UI_FONT = "Montserrat"
local function E(name)
    local ok, v = pcall(function()
        return Enum.Font[name]
    end)
    return ok and v or Enum.Font.Gotham
end
local FontFamilies = {
    Montserrat = { R = E("Montserrat"), M = E("MontserratMedium"), B = E("MontserratBold") },
    BuilderSans = { R = E("BuilderSans"), M = E("BuilderSansMedium"), B = E("BuilderSansBold") },
    Gotham = { R = Enum.Font.Gotham, M = Enum.Font.GothamMedium, B = Enum.Font.GothamBold },
}
local FNT = FontFamilies[UI_FONT] or FontFamilies.Gotham

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- เสียงตอนกดเปิด/ปิด (เปลี่ยน ID ได้ตามชอบ เช่น "rbxassetid://1234567")
local SOUND_ON = "rbxasset://sounds/switch.wav"
local SOUND_OFF = "rbxasset://sounds/button.wav"
local SOUND_FALLBACK = "rbxasset://sounds/electronicpingshort.wav" -- ใช้ถ้าเสียงข้างบนโหลดไม่ได้

--==================================================
-- CONFIG  (Auto Save / Auto Load)
--==================================================

local CONFIG_FILE = "RELWX_HUB_Config.json"

local Defaults = {
    -- สี
    UIAccentColor = "#C9CBD3",
    UIBackgroundColor = "#0A0A0C",
    UIButtonColor = "#232328",
    FloatingButtonColor = "#101012",
    FloatingBorderColor = "#E4E4EA",
    FloatingGlowColor = "#8E8E98",
    -- ฟังก์ชัน
    ExampleFunctionEnabled = false,
    ExampleFunction2Enabled = false,
    ExampleSlider = 50,
    -- ระบบ
    SoundEnabled = true,
    StatsVisible = true,
    UIScalePercent = 100,
    -- สถานะ UI
    LastTab = "Home",
    WindowVisible = true,
    Maximized = false,
    CollapsedSections = "",
    WindowX = 0.5,
    WindowY = 0.5,
    FloatX = 0.04,
    FloatY = 0.25,
    StatsX = 0.5,
    StatsY = 0.045,
}

local Config = {}
for k, v in pairs(Defaults) do
    Config[k] = v
end

local LoadedFromFile = false

local function LoadConfig()
    if not (isfile and readfile) then
        return
    end
    local ok, exists = pcall(isfile, CONFIG_FILE)
    if not (ok and exists) then
        return
    end
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            for k, v in pairs(Defaults) do
                if type(data[k]) == type(v) then
                    Config[k] = data[k]
                end
            end
            for k, v in pairs(data) do
                if type(k) == "string" and (type(v) == "boolean" or type(v) == "number" or type(v) == "string" or type(v) == "table") then
                    Config[k] = v
                end
            end
            LoadedFromFile = true
        end
    end)
end

LoadConfig()
for _, k in ipairs({ "WindowX", "WindowY" }) do
    Config[k] = math.clamp(Config[k], 0.05, 0.95)
end
for _, k in ipairs({ "FloatX", "FloatY", "StatsX", "StatsY" }) do
    Config[k] = math.clamp(Config[k], 0.02, 0.98)
end
Config.UIScalePercent = math.clamp(Config.UIScalePercent, 60, 120)

local SaveHooks = {}
local SaveToken = 0

local function Fire(state)
    for _, h in ipairs(SaveHooks) do
        pcall(h, state)
    end
end

local function WriteNow()
    if not writefile then
        return "unsupported"
    end
    local ok = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
    end)
    return ok and "saved" or "failed"
end

local function SaveConfig(instant)
    SaveToken = SaveToken + 1
    local token = SaveToken
    Fire("saving")
    local function commit()
        if token ~= SaveToken then
            return
        end
        local result = WriteNow()
        Fire(result)
        if result == "saved" then
            task.delay(1.8, function()
                if token == SaveToken then
                    Fire("idle")
                end
            end)
        end
    end
    if instant then
        commit()
    else
        task.delay(0.3, commit)
    end
end

local function SetConfig(key, value)
    if Config[key] == value then
        return
    end
    Config[key] = value
    SaveConfig()
end

--==================================================
-- THEME  (ทุกสีใน UI คำนวณจาก Config และอัปเดตสดทันที)
--==================================================

local function RGB(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function Lum(c)
    return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function Hex(key, fallback)
    local ok, c = pcall(Color3.fromHex, Config[key])
    return ok and c or fallback
end

local Theme = {}

local function ComputeTheme()
    local bg = Hex("UIBackgroundColor", RGB(8, 8, 8))
    local dark = Lum(bg) < 0.5
    local to = dark and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    Theme.Bg = bg
    Theme.Surface = bg:Lerp(to, 0.05)
    Theme.Surface2 = bg:Lerp(to, 0.095)
    Theme.Stroke = bg:Lerp(to, 0.17)
    Theme.Text = dark and RGB(244, 244, 244) or RGB(20, 20, 20)
    Theme.Sub = Theme.Text:Lerp(bg, 0.32)
    Theme.Muted = Theme.Text:Lerp(bg, 0.58)
    Theme.Accent = Hex("UIAccentColor", RGB(190, 190, 190))
    Theme.OnAccent = Lum(Theme.Accent) > 0.55 and RGB(15, 15, 15) or RGB(255, 255, 255)
    Theme.Button = Hex("UIButtonColor", RGB(36, 36, 36))
    local h, s, v = Theme.Accent:ToHSV()
    if s < 0.12 then
        Theme.Accent2 = Theme.Accent:Lerp(Color3.fromRGB(96, 104, 128), 0.6) -- เทา: ไล่เป็นเหล็กอมฟ้า
    else
        Theme.Accent2 = Color3.fromHSV((h + 0.12) % 1, s, math.max(v, 0.6))
    end
end

ComputeTheme()

local ThemeHooks = {}

local function OnTheme(fn)
    ThemeHooks[#ThemeHooks + 1] = fn
    pcall(fn)
end

local function Bind(obj, prop, key)
    OnTheme(function()
        obj[prop] = Theme[key]
    end)
end

local function ApplyTheme()
    ComputeTheme()
    for _, fn in ipairs(ThemeHooks) do
        pcall(fn)
    end
end

--==================================================
-- HELPERS
--==================================================

local Orders = setmetatable({}, { __mode = "k" })
local function Next(parent)
    Orders[parent] = (Orders[parent] or 0) + 1
    return Orders[parent]
end

local function New(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function Stroke(parent, color, thickness, transparency)
    return New("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function Pad(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, parent)
end

local function List(parent, padding)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
end

local function Text(parent, text, size, font, color, align)
    local l = New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text or "",
        TextSize = size or 13,
        Font = font or FNT.R,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    if type(color) == "string" then
        Bind(l, "TextColor3", color)
    elseif color then
        l.TextColor3 = color
    end
    return l
end

local function Tween(obj, t, props, style, dir)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function Apply(obj, animate, props)
    if animate then
        Tween(obj, 0.16, props)
    else
        for k, v in pairs(props) do
            obj[k] = v
        end
    end
end

local function Panel(parent, size, class)
    local f = New(class or "Frame", { BorderSizePixel = 0, LayoutOrder = Next(parent) }, parent)
    if class == "TextButton" then
        f.Text = ""
        f.AutoButtonColor = false
    end
    if size then
        f.Size = size
    end
    Bind(f, "BackgroundColor3", "Surface")
    Corner(f, 12)
    Bind(Stroke(f, Theme.Stroke, 1, 0.4), "Color", "Stroke")
    New("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.76, 0.76, 0.76)),
        Rotation = 90,
    }, f)
    local hi = New("Frame", {
        Size = UDim2.new(1, -28, 0, 1),
        Position = UDim2.fromOffset(14, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
    }, f)
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, hi)
    return f
end

local function HoverRow(btn)
    local st = btn:FindFirstChildOfClass("UIStroke")
    btn.MouseEnter:Connect(function()
        Tween(btn, 0.12, { BackgroundColor3 = Theme.Surface2 })
        if st then
            Tween(st, 0.12, { Transparency = 0.05 })
        end
    end)
    local sc
    if btn:IsA("GuiButton") then
        sc = New("UIScale", { Scale = 1 }, btn)
        btn.MouseButton1Down:Connect(function()
            Tween(sc, 0.08, { Scale = 0.982 })
        end)
        btn.MouseButton1Up:Connect(function()
            Tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
        end)
    end
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.12, { BackgroundColor3 = Theme.Surface })
        if st then
            Tween(st, 0.12, { Transparency = 0.4 })
        end
        if sc then
            Tween(sc, 0.12, { Scale = 1 })
        end
    end)
end

-- ชั้นสีไล่เฉดอ่อนๆ ของ accent ใช้ตกแต่งการ์ด
-- ไล่เฉด Accent -> Accent2 (วัตถุที่ใช้ต้องตั้ง BackgroundColor3 เป็นสีขาว)
local function AccentGrad(parent, rotation)
    local g = New("UIGradient", { Rotation = rotation or 0 }, parent)
    OnTheme(function()
        g.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
    end)
    return g
end

local function Tint(parent)
    local t = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, parent)
    Corner(t, 12)
    local g = AccentGrad(t, 25)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 1),
    })
    return t
end

local function IsPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

-- ไอคอนวาดด้วย Frame (ไม่พึ่งรูป/asset) คืนค่าฟังก์ชันเปลี่ยนสี
local function Icon(parent, kind, x, y)
    local box = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(x, y),
        BackgroundTransparency = 1,
    }, parent)
    local parts = {}
    local function rect(px, py, w, h, r, rot)
        local f = New("Frame", {
            Size = UDim2.fromOffset(w, h),
            Position = UDim2.fromOffset(px, py),
            BorderSizePixel = 0,
            Rotation = rot or 0,
        }, box)
        Corner(f, r or 1)
        parts[#parts + 1] = { f = f }
        return f
    end
    if kind == "grid" then
        rect(1, 1, 7, 7, 2)
        rect(10, 1, 7, 7, 2)
        rect(1, 10, 7, 7, 2)
        rect(10, 10, 7, 7, 2)
    elseif kind == "sliders" then
        rect(1, 2, 16, 2, 1)
        rect(1, 8, 11, 2, 1)
        rect(1, 14, 14, 2, 1)
    elseif kind == "close" then
        rect(1, 8, 16, 2, 1, 45)
        rect(1, 8, 16, 2, 1, -45)
    elseif kind == "max" then
        local r = New("Frame", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.fromOffset(3, 3),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, box)
        Corner(r, 3)
        parts[#parts + 1] = { stroke = Stroke(r, Color3.new(1, 1, 1), 2, 0) }
    else -- ring (settings)
        local r = New("Frame", {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, box)
        Corner(r, 8)
        parts[#parts + 1] = { stroke = Stroke(r, Color3.new(1, 1, 1), 2, 0) }
        rect(7, 7, 4, 4, 2)
    end
    return function(c)
        for _, p in ipairs(parts) do
            if p.stroke then
                p.stroke.Color = c
            else
                p.f.BackgroundColor3 = c
            end
        end
    end
end

--==================================================
-- ROOT GUI
--==================================================

pcall(function()
    for _, v in ipairs(PlayerGui:GetChildren()) do
        if v.Name == "RELWX_UI" or v.Name == "RELWX_Floating" or v.Name == "RELWX_Stats"
            or v.Name == "TwoSki_RideAPet_Floating" then
            v:Destroy()
        end
    end
end)

local Screen = New("ScreenGui", {
    Name = "RELWX_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999998,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

-- เก็บ connection ทั้งหมดไว้ ตัดทิ้งตอน UI ถูกทำลาย (รันสคริปต์ซ้ำได้ไม่ค้าง)
local Conns = {}
local function Track(c)
    Conns[#Conns + 1] = c
    return c
end
Screen.Destroying:Connect(function()
    for _, c in ipairs(Conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
end)

local BW, BH = 740, 580 -- ขนาดออกแบบ (ปรับตามจอผ่าน UIScale)
local SW = 172 -- ความกว้าง sidebar

local function ViewSize()
    local s = Screen.AbsoluteSize
    if s.X > 0 and s.Y > 0 then
        return s
    end
    return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
end

local function TargetScale()
    local v = ViewSize()
    local fit = math.min(v.X * 0.97 / BW, v.Y * 0.95 / BH)
    local base = math.min(fit * (Config.Maximized and 1 or 0.92), Config.Maximized and 1.4 or 1.1)
    local s = base * (Config.UIScalePercent / 100)
    return math.clamp(s, 0.3, math.max(0.3, fit))
end

local Main = New("CanvasGroup", {
    Name = "Main",
    Size = UDim2.fromOffset(BW, BH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.WindowX, Config.WindowY),
    BorderSizePixel = 0,
    BackgroundTransparency = 0.04,
    GroupTransparency = 1,
    Active = true,
    Visible = false,
}, Screen)
Bind(Main, "BackgroundColor3", "Bg")
Corner(Main, 18)

-- แสงพื้นหลัง (aurora) มุมซ้ายบน / ขวาล่าง
local function Aurora(key, rot)
    local f = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, Main)
    Bind(f, "BackgroundColor3", key)
    Corner(f, 18)
    New("UIGradient", {
        Rotation = rot,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.82),
            NumberSequenceKeypoint.new(0.55, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, f)
end
Aurora("Accent", 35)
Aurora("Accent2", 215)

-- ฝุ่นแสงลอยช้าๆ เป็นพื้นหลัง
local Dust = New("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Main)
for i = 1, 16 do
    local sz = math.random(2, 4)
    local x = math.random()
    local p = New("Frame", {
        Size = UDim2.fromOffset(sz, sz),
        Position = UDim2.fromScale(x, 1.05),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.55 + math.random() * 0.3,
    }, Dust)
    Corner(p, 2)
    Bind(p, "BackgroundColor3", (i % 2 == 0) and "Accent" or "Accent2")
    local dur = 9 + math.random() * 9
    TweenService:Create(
        p,
        TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, math.random() * 5),
        { Position = UDim2.fromScale(math.clamp(x + (math.random() - 0.5) * 0.15, 0, 1), -0.05) }
    ):Play()
end

local MainStroke = Stroke(Main, Color3.new(1, 1, 1), 1.5, 0)
local MainGrad = New("UIGradient", { Rotation = 0 }, MainStroke)
OnTheme(function()
    MainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Stroke),
        ColorSequenceKeypoint.new(0.35, Theme.Accent),
        ColorSequenceKeypoint.new(0.65, Theme.Accent2),
        ColorSequenceKeypoint.new(1, Theme.Stroke),
    })
end)
TweenService:Create(
    MainGrad,
    TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()
local MainScale = New("UIScale", { Scale = TargetScale() }, Main)

-- เงา + แสงเรืองใต้หน้าต่าง
local Shadow = New("Frame", {
    Size = UDim2.fromOffset(BW, BH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 0,
    Visible = false,
}, Screen)
local ShadowScale = New("UIScale", { Scale = 1 }, Shadow)
local ShadowLayers = {}
for i, g in ipairs({ 8, 20, 36, 56 }) do
    local l = New("Frame", {
        Size = UDim2.new(1, g * 2, 1, g * 2),
        Position = UDim2.fromOffset(-g, -g + 10),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, Shadow)
    Corner(l, 18 + g)
    ShadowLayers[i] = { f = l, base = 0.82 + i * 0.03 }
end
local ShadowGlow = New("Frame", {
    Size = UDim2.new(1, 40, 1, 40),
    Position = UDim2.fromOffset(-20, -20),
    BorderSizePixel = 0,
}, Shadow)
Corner(ShadowGlow, 38)
Bind(ShadowGlow, "BackgroundColor3", "Accent")
ShadowLayers[#ShadowLayers + 1] = { f = ShadowGlow, base = 0.95 }

Track(RunService.RenderStepped:Connect(function()
    local vis = Main.Visible
    Shadow.Visible = vis
    if not vis then
        return
    end
    Shadow.Position = Main.Position
    Shadow.Size = Main.Size
    ShadowScale.Scale = MainScale.Scale
    local a = Main.GroupTransparency
    for _, l in ipairs(ShadowLayers) do
        l.f.BackgroundTransparency = 1 - (1 - l.base) * (1 - a)
    end
end))

-- เส้นแสงด้านบนหน้าต่าง
local TopGlow = New("Frame", {
    Size = UDim2.new(0.8, 0, 0, 1),
    Position = UDim2.fromScale(0.1, 0),
    BorderSizePixel = 0,
}, Main)
Bind(TopGlow, "BackgroundColor3", "Accent")
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, TopGlow)

local Opening = false

local function ApplyScale(animate)
    if Opening then
        return
    end
    if animate and Main.Visible then
        Tween(MainScale, 0.25, { Scale = TargetScale() }, Enum.EasingStyle.Quint)
    else
        MainScale.Scale = TargetScale()
    end
end

Track(Screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    ApplyScale(false)
end))

-- เปิด/ปิดหน้าต่างพร้อมเอฟเฟกต์ (ปิดแบบสโลว์: ค่อยๆ จางและหดลง)
-- เสียงเปิด/ปิด (ถ้าไฟล์เสียงโหลดไม่ขึ้น จะสลับไปใช้เสียงสำรองให้เอง)
local function PlayToggleSound(on, big)
    if not Config.SoundEnabled then
        return
    end
    pcall(function()
        local function play(id, vol, speed)
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = vol
            s.PlaybackSpeed = speed
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 2.5)
            return s
        end
        local speed = (on and 1.18 or 0.86) * (big and 0.85 or 1)
        local s = play(on and SOUND_ON or SOUND_OFF, big and 0.7 or 0.6, speed)
        task.delay(0.35, function()
            if s.Parent and s.TimeLength == 0 then
                play(SOUND_FALLBACK, 0.55, on and 1.35 or 0.85)
            end
        end)
    end)
end

-- ===== FX: วงคลื่น / ประกายไฟ / ลำแสง =====
local function FloatCenter()
    local s = Screen.AbsoluteSize
    return s.X * Config.FloatX, s.Y * Config.FloatY
end

local function FxRing(cx, cy, size, thick, dur, color)
    local r = New("Frame", {
        Size = UDim2.fromOffset(6, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx, cy),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 60,
    }, Screen)
    Corner(r, 9999)
    local st = Stroke(r, color or Theme.Accent, thick, 0.05)
    Tween(r, dur, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quint)
    Tween(st, dur, { Transparency = 1, Thickness = 0.5 }, Enum.EasingStyle.Quad)
    Debris:AddItem(r, dur + 0.15)
end

local function FxSparks(cx, cy, spread, count, dist)
    for i = 1, count do
        local ang = math.random() * math.pi * 2
        local d = dist * (0.45 + math.random() * 0.8)
        local sz = math.random(3, 6)
        local px = cx + (math.random() - 0.5) * spread
        local col = (i % 3 == 0) and Color3.new(1, 1, 1) or ((i % 2 == 0) and Theme.Accent or Theme.Accent2)
        local p = New("Frame", {
            Size = UDim2.fromOffset(sz, sz),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(px, cy),
            BorderSizePixel = 0,
            BackgroundColor3 = col,
            ZIndex = 61,
        }, Screen)
        Corner(p, 3)
        local dur = 0.45 + math.random() * 0.45
        Tween(p, dur, {
            Position = UDim2.fromOffset(px + math.cos(ang) * d, cy + math.sin(ang) * d * 0.85),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(1, 1),
        }, Enum.EasingStyle.Quint)
        Debris:AddItem(p, dur + 0.15)
    end
end

local function FxBeam(cx, cy, w)
    local b = New("Frame", {
        Size = UDim2.fromOffset(w, 4),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx, cy),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 62,
    }, Screen)
    New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent2),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Theme.Accent),
        }),
    }, b)
    Stroke(b, Theme.Accent, 5, 0.65)
    Debris:AddItem(b, 2)
    return b
end

local AnimToken = 0

-- เปิด: บินออกจากปุ่ม RX แล้วขยายเป็นหน้าต่าง + วงคลื่น
local function PlayOpen()
    AnimToken = AnimToken + 1
    local token = AnimToken
    Opening = true
    local t = TargetScale()
    local fx, fy = FloatCenter()

    MainStroke.Thickness = 1.5
    Main.Size = UDim2.fromOffset(BW, BH)
    Main.Position = UDim2.fromOffset(fx, fy)
    Main.GroupTransparency = 1
    MainScale.Scale = t * 0.12
    Main.Visible = true

    PlayToggleSound(true, true)
    FxRing(fx, fy, 120, 3, 0.55)
    FxSparks(fx, fy, 6, 12, 60)

    Tween(Main, 0.3, { GroupTransparency = 0 })
    Tween(Main, 0.6, { Position = UDim2.fromScale(Config.WindowX, Config.WindowY) }, Enum.EasingStyle.Quint)
    Tween(MainScale, 0.65, { Scale = t }, Enum.EasingStyle.Back)

    task.delay(0.5, function()
        if token ~= AnimToken then
            return
        end
        local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
        FxRing(ap.X + asz.X / 2, ap.Y + asz.Y / 2, math.max(asz.X, asz.Y) * 1.05, 2, 0.7, Theme.Accent2)
    end)
    task.delay(0.68, function()
        if token == AnimToken then
            Opening = false
        end
    end)
end

-- ปิด: ตัวหน้าต่างพองเล็กน้อย -> ยุบเป็นเส้นแสง -> หดเป็นจุด + ประกายไฟ -> บินเข้าปุ่ม RX แล้วปล่อยคลื่น
local function PlayClose()
    AnimToken = AnimToken + 1
    local token = AnimToken
    Opening = true
    PlayToggleSound(false, true)

    local s0 = MainScale.Scale
    local function alive()
        return token == AnimToken
    end

    -- 1) พองเล็กน้อย + ขอบสว่างวาบ
    Tween(MainScale, 0.14, { Scale = s0 * 1.03 }, Enum.EasingStyle.Sine)
    Tween(MainStroke, 0.3, { Thickness = 3.5 }, Enum.EasingStyle.Sine)

    -- 2) ยุบแนวตั้งเป็นเส้นบางๆ
    task.delay(0.14, function()
        if not alive() then
            return
        end
        Tween(Main, 0.36, { Size = UDim2.fromOffset(BW, 5) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        Tween(MainScale, 0.36, { Scale = s0 * 0.97 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    end)

    -- 3) เส้นแสงวาบ -> หดเป็นจุด + วงคลื่น + ประกายไฟ
    task.delay(0.5, function()
        if not alive() then
            return
        end
        local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
        local cx, cy = ap.X + asz.X / 2, ap.Y + asz.Y / 2
        local w = math.max(asz.X, 40)

        Main.Visible = false
        Main.Size = UDim2.fromOffset(BW, BH)
        Main.Position = UDim2.fromScale(Config.WindowX, Config.WindowY)
        MainScale.Scale = s0
        MainStroke.Thickness = 1.5

        local beam = FxBeam(cx, cy, w)
        FxRing(cx, cy, w * 0.75, 3, 0.6)
        FxRing(cx, cy, w * 0.45, 2, 0.5, Theme.Accent2)
        FxSparks(cx, cy, w, 28, 150 * math.max(s0, 0.6))
        Tween(beam, 0.26, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

        -- 4) จุดแสงบินเข้าปุ่ม RX
        task.delay(0.28, function()
            local fx, fy = FloatCenter()
            Tween(beam, 0.36, {
                Position = UDim2.fromOffset(fx, fy),
                Size = UDim2.fromOffset(8, 8),
            }, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
            task.delay(0.36, function()
                beam:Destroy()
                FxRing(fx, fy, 100, 3, 0.55)
                FxSparks(fx, fy, 6, 12, 50)
                if alive() then
                    Opening = false
                end
            end)
        end)
    end)
end

local function SetWindow(visible)
    SetConfig("WindowVisible", visible)
    if visible then
        PlayOpen()
    else
        PlayClose()
    end
end

-- ลากหน้าต่าง/ปุ่ม/วิดเจ็ต แล้วเซฟตำแหน่งเป็นสัดส่วนหน้าจอ
local function SavePosition(target, kx, ky)
    local s = Screen.AbsoluteSize
    if s.X <= 0 or s.Y <= 0 then
        return
    end
    local c = target.AbsolutePosition + target.AbsoluteSize / 2
    local fx = math.clamp(c.X / s.X, 0.02, 0.98)
    local fy = math.clamp(c.Y / s.Y, 0.02, 0.98)
    target.Position = UDim2.fromScale(fx, fy)
    SetConfig(kx, math.floor(fx * 10000) / 10000)
    SetConfig(ky, math.floor(fy * 10000) / 10000)
end

local function MakeDraggable(handle, target, kx, ky, onClick)
    local dragging, dragInput, startPos, startCenter, moved = false, nil, nil, nil, false

    handle.InputBegan:Connect(function(input)
        if IsPointer(input) then
            dragging = true
            moved = false
            dragInput = input
            startPos = input.Position
            startCenter = target.AbsolutePosition + target.AbsoluteSize / 2
        end
    end)

    Track(UIS.InputChanged:Connect(function(input)
        if not dragging or not IsMove(input) then
            return
        end
        if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
            return
        end
        local d = input.Position - startPos
        if d.Magnitude > 8 then
            moved = true
        end
        if moved then
            local s = Screen.AbsoluteSize
            target.Position = UDim2.fromOffset(
                math.clamp(startCenter.X + d.X, 0, s.X),
                math.clamp(startCenter.Y + d.Y, 0, s.Y)
            )
        end
    end))

    Track(UIS.InputEnded:Connect(function(input)
        if dragging and IsPointer(input) then
            if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
                return
            end
            dragging = false
            if moved then
                SavePosition(target, kx, ky)
            elseif onClick then
                onClick()
            end
        end
    end))
end

-- แจ้งเตือนเล็กๆ ด้านล่างจอ (Toast)
local ActiveToast
local function Toast(text, on)
    if ActiveToast then
        ActiveToast:Destroy()
        ActiveToast = nil
    end
    local t = New("TextLabel", {
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 48),
        BorderSizePixel = 0,
        Text = text,
        TextSize = 12,
        Font = FNT.M,
        BackgroundColor3 = Theme.Surface2,
        TextColor3 = Theme.Text,
        ZIndex = 300,
    }, Screen)
    Corner(t, 19)
    Stroke(t, Theme.Accent, 1, 0.55)
    Pad(t, 38, 18, 0, 0)
    local dot = New("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.new(0, -24, 0.5, -4),
        BorderSizePixel = 0,
        BackgroundColor3 = (on == true) and RGB(70, 200, 120) or (on == false and Theme.Muted or Theme.Accent),
    }, t)
    Corner(dot, 4)
    ActiveToast = t
    Tween(t, 0.35, { Position = UDim2.new(0.5, 0, 1, -26) }, Enum.EasingStyle.Back)
    task.delay(1.7, function()
        if ActiveToast == t then
            Tween(t, 0.25, { Position = UDim2.new(0.5, 0, 1, 48) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.3, function()
                t:Destroy()
                if ActiveToast == t then
                    ActiveToast = nil
                end
            end)
        end
    end)
end

--==================================================
-- SAVE STATUS PILL
--==================================================

local SaveStates = {
    idle = { "Auto Save", nil },
    saving = { "กำลังบันทึก...", RGB(240, 190, 60) },
    saved = { "บันทึกแล้ว", RGB(70, 200, 120) },
    failed = { "บันทึกไม่ได้", RGB(235, 75, 90) },
    unsupported = { "ไม่รองรับไฟล์", RGB(235, 75, 90) },
}

local function StatusPill(parent, width)
    local pill = New("Frame", { Size = UDim2.fromOffset(width or 108, 26), BorderSizePixel = 0 }, parent)
    Bind(pill, "BackgroundColor3", "Surface2")
    Corner(pill, 13)
    Bind(Stroke(pill, Theme.Stroke, 1, 0.3), "Color", "Stroke")

    local dot = New("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.new(0, 11, 0.5, -4),
        BorderSizePixel = 0,
    }, pill)
    Corner(dot, 4)

    local label = Text(pill, "", 10, FNT.M, "Sub")
    label.Position = UDim2.fromOffset(26, 0)
    label.Size = UDim2.new(1, -30, 1, 0)

    local current = "idle"
    local function render()
        local s = SaveStates[current]
        label.Text = s[1]
        dot.BackgroundColor3 = s[2] or Theme.Accent
    end
    OnTheme(render)

    SaveHooks[#SaveHooks + 1] = function(state)
        current = state
        render()
    end
    return pill
end

--==================================================
-- FPS / MS WIDGET (เล็ก ลากได้ แยกจากหน้าต่างหลัก)
--==================================================

local StatsGui = New("ScreenGui", {
    Name = "RELWX_Stats",
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
    Enabled = Config.StatsVisible,
}, PlayerGui)

local StatsBox = New("Frame", {
    Size = UDim2.fromOffset(152, 30),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.StatsX, Config.StatsY),
    BorderSizePixel = 0,
    BackgroundTransparency = 0.1,
    Active = true,
}, StatsGui)
Bind(StatsBox, "BackgroundColor3", "Surface")
Corner(StatsBox, 15)
Bind(Stroke(StatsBox, Theme.Stroke, 1, 0.2), "Color", "Stroke")

local FpsLabel = Text(StatsBox, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Center)
FpsLabel.RichText = true
FpsLabel.Size = UDim2.new(0.5, -1, 1, 0)

local MsLabel = Text(StatsBox, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Center)
MsLabel.RichText = true
MsLabel.Position = UDim2.new(0.5, 1, 0, 0)
MsLabel.Size = UDim2.new(0.5, -1, 1, 0)

local StatsDivider = New("Frame", {
    Size = UDim2.fromOffset(1, 14),
    Position = UDim2.new(0.5, 0, 0.5, -7),
    BorderSizePixel = 0,
}, StatsBox)
Bind(StatsDivider, "BackgroundColor3", "Stroke")

MakeDraggable(StatsBox, StatsBox, "StatsX", "StatsY")

local Metrics = { fps = 60, ping = 0 }

do
    local frames, acc = 0, 0
    Track(RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        acc = acc + dt
        if acc >= 0.5 then
            Metrics.fps = math.floor(frames / acc + 0.5)
            frames, acc = 0, 0
        end
    end))
end

local function GetPing()
    local ok, v = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return (ok and type(v) == "number") and math.floor(v + 0.5) or 0
end

local function Level(value, good, mid, higherIsBetter)
    local g, m, b = RGB(70, 200, 120), RGB(240, 190, 60), RGB(235, 75, 90)
    if higherIsBetter then
        return value >= good and g or (value >= mid and m or b)
    end
    return value <= good and g or (value <= mid and m or b)
end

local function RefreshStats()
    Metrics.ping = GetPing()
    local fc = Level(Metrics.fps, 50, 30, true)
    local mc = Level(Metrics.ping, 80, 160, false)
    local muted = "#" .. Theme.Muted:ToHex()
    FpsLabel.Text = string.format(
        '<font color="#%s"><b>%d</b></font> <font color="%s">FPS</font>',
        fc:ToHex(), Metrics.fps, muted
    )
    MsLabel.Text = string.format(
        '<font color="#%s"><b>%d</b></font> <font color="%s">MS</font>',
        mc:ToHex(), Metrics.ping, muted
    )
end

--==================================================
-- TOP BAR
--==================================================

local Top = New("Frame", {
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, Main)

local TopLine = New("Frame", {
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 1, -1),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.new(1, 1, 1),
}, Top)
do
    local g = AccentGrad(TopLine, 0)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.95),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 0.95),
    })
end

Top.ClipsDescendants = true
local Shine = New("Frame", {
    Size = UDim2.new(0, 120, 1, 0),
    Position = UDim2.new(-0.3, 0, 0, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
}, Top)
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.93),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, Shine)
TweenService:Create(
    Shine,
    TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 4),
    { Position = UDim2.new(1.1, 0, 0, 0) }
):Play()

local Badge = New("Frame", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.fromOffset(16, 13),
    BorderSizePixel = 0,
}, Top)
Badge.BackgroundColor3 = Color3.new(1, 1, 1)
AccentGrad(Badge, 45)
Corner(Badge, 10)
Bind(Stroke(Badge, Theme.Accent, 1.5, 0.65), "Color", "Accent")
local BadgeText = Text(Badge, "RX", 13, FNT.B, nil, Enum.TextXAlignment.Center)
BadgeText.Size = UDim2.fromScale(1, 1)
Bind(BadgeText, "TextColor3", "OnAccent")

local Brand = Text(Top, "", 15, FNT.B, "Text")
Brand.RichText = true
OnTheme(function()
    Brand.Text = 'RELWX <font color="#' .. Theme.Accent:ToHex() .. '">HUB</font>'
end)
Brand.Position = UDim2.fromOffset(60, 10)
Brand.Size = UDim2.new(1, -270, 0, 22)

local BrandSub = Text(Top, tostring(game.Name or ""), 10, FNT.R, "Muted")
BrandSub.Position = UDim2.fromOffset(60, 31)
BrandSub.Size = UDim2.new(1, -270, 0, 16)

local function WindowButton(kind, xOffset, danger)
    local b = New("TextButton", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, xOffset, 0.5, -16),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, Top)
    Corner(b, 10)
    Bind(b, "BackgroundColor3", "Surface2")
    local paint = Icon(b, kind, 7, 7)
    OnTheme(function()
        paint(Theme.Sub)
    end)
    b.MouseEnter:Connect(function()
        Tween(b, 0.12, { BackgroundColor3 = danger and RGB(200, 70, 80) or Theme.Button })
        paint(danger and RGB(255, 255, 255) or Theme.Text)
    end)
    b.MouseLeave:Connect(function()
        Tween(b, 0.12, { BackgroundColor3 = Theme.Surface2 })
        paint(Theme.Sub)
    end)
    return b
end

local MaxBtn = WindowButton("max", -86, false)
local CloseBtn = WindowButton("close", -48, true)
CloseBtn.MouseButton1Click:Connect(function()
    SetWindow(false)
end)

MakeDraggable(Top, Main, "WindowX", "WindowY")

MaxBtn.MouseButton1Click:Connect(function()
    SetConfig("Maximized", not Config.Maximized)
    SetConfig("WindowX", 0.5)
    SetConfig("WindowY", 0.5)
    Tween(Main, 0.3, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
    ApplyScale(true)
end)

--==================================================
-- SIDEBAR (หมวดหมู่)
--==================================================

local Rail = New("Frame", {
    Size = UDim2.new(0, SW, 1, -80),
    Position = UDim2.fromOffset(12, 68),
    BorderSizePixel = 0,
}, Main)
Bind(Rail, "BackgroundColor3", "Surface")
Corner(Rail, 14)
Bind(Stroke(Rail, Theme.Stroke, 1, 0.4), "Color", "Stroke")

local CatList = New("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -80),
    Position = UDim2.fromOffset(8, 10),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageTransparency = 0.3,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, Rail)
Bind(CatList, "ScrollBarImageColor3", "Accent")
List(CatList, 4)
Pad(CatList, 0, 4, 1, 1)

local UserBox = New("Frame", {
    Size = UDim2.new(1, -16, 0, 52),
    Position = UDim2.new(0, 8, 1, -60),
    BorderSizePixel = 0,
}, Rail)
Bind(UserBox, "BackgroundColor3", "Surface2")
Corner(UserBox, 12)

local Avatar = New("ImageLabel", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(0, 9, 0.5, -17),
    BorderSizePixel = 0,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=60&h=60",
}, UserBox)
Corner(Avatar, 17)
Bind(Avatar, "BackgroundColor3", "Button")
Bind(Stroke(Avatar, Theme.Accent, 1.5, 0.2), "Color", "Accent")
Bind(Stroke(UserBox, Theme.Stroke, 1, 0.5), "Color", "Stroke")
local Online = New("Frame", {
    Size = UDim2.fromOffset(10, 10),
    Position = UDim2.new(0, 36, 0.5, 7),
    BorderSizePixel = 0,
    BackgroundColor3 = RGB(70, 200, 120),
    ZIndex = 3,
}, UserBox)
Corner(Online, 5)
Bind(Stroke(Online, Theme.Surface2, 2, 0), "Color", "Surface2")

local UName = Text(UserBox, LocalPlayer.DisplayName, 12, FNT.B, "Text")
UName.Position = UDim2.fromOffset(52, 9)
UName.Size = UDim2.new(1, -58, 0, 18)
local UTag = Text(UserBox, "@" .. LocalPlayer.Name, 10, FNT.R, "Muted")
UTag.Position = UDim2.fromOffset(52, 27)
UTag.Size = UDim2.new(1, -58, 0, 14)

local Pages = {}
local TabList = {}

local function CatGroup(name)
    local l = Text(CatList, name, 10, FNT.B, "Muted")
    l.Size = UDim2.new(1, 0, 0, 26)
    l.LayoutOrder = Next(CatList)
    Pad(l, 10, 0, 6, 0)
    return l
end

local CurrentTab = nil
local function SelectTab(id)
    if not Pages[id] then
        id = "Home"
    end
    SetConfig("LastTab", id)
    local changed = id ~= CurrentTab
    CurrentTab = id
    for pid, page in pairs(Pages) do
        page.Visible = (pid == id)
    end
    if changed then
        local p = Pages[id]
        p.Position = UDim2.fromOffset(0, 16)
        Tween(p, 0.32, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
    end
    for _, t in ipairs(TabList) do
        t.active = (t.id == id)
        t.paint()
    end
end

local function Category(name, id, iconKind)
    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Next(CatList),
    }, CatList)
    Corner(b, 11)
    local bst = Stroke(b, Theme.Accent, 1, 1)

    local ind = New("Frame", {
        Size = UDim2.fromOffset(3, 8),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, b)
    Corner(ind, 2)

    local setIcon = Icon(b, iconKind, 16, 12)

    local lbl = Text(b, name, 13, FNT.M)
    lbl.Position = UDim2.fromOffset(44, 0)
    lbl.Size = UDim2.new(1, -48, 1, 0)
    lbl.TextColor3 = Theme.Sub

    local tab = { id = id, active = false, hover = false }
    function tab.paint()
        Tween(b, 0.15, {
            BackgroundColor3 = tab.active and Theme.Accent or Theme.Button,
            BackgroundTransparency = tab.active and 0.84 or (tab.hover and 0.5 or 1),
        })
        Tween(bst, 0.15, { Color = Theme.Accent, Transparency = tab.active and 0.55 or 1 })
        Tween(lbl, 0.15, { TextColor3 = tab.active and Theme.Text or Theme.Sub })
        Tween(ind, 0.15, {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = tab.active and 0 or 1,
            Size = tab.active and UDim2.fromOffset(3, 22) or UDim2.fromOffset(3, 8),
        })
        setIcon(tab.active and Theme.Accent or Theme.Sub)
    end
    TabList[#TabList + 1] = tab
    OnTheme(tab.paint)

    b.MouseEnter:Connect(function()
        tab.hover = true
        tab.paint()
    end)
    b.MouseLeave:Connect(function()
        tab.hover = false
        tab.paint()
    end)
    b.MouseButton1Click:Connect(function()
        SelectTab(id)
    end)
    return b
end

--==================================================
-- PAGES
--==================================================

local Body = New("Frame", {
    Size = UDim2.new(1, -(SW + 36), 1, -80),
    Position = UDim2.fromOffset(SW + 24, 68),
    BackgroundTransparency = 1,
}, Main)

local function MakePage(id, title, subtitle)
    local page = New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, Body)
    Bind(page, "ScrollBarImageColor3", "Stroke")
    List(page, 8)
    Pad(page, 0, 8, 0, 14)

    local head = New("Frame", {
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
        LayoutOrder = Next(page),
    }, page)
    local t = Text(head, title, 22, FNT.B, "Text")
    t.Size = UDim2.new(1, 0, 0, 28)
    local s = Text(head, subtitle or "", 11, FNT.R, "Muted")
    s.Position = UDim2.fromOffset(0, 29)
    s.Size = UDim2.new(1, 0, 0, 18)
    local hb = New("Frame", {
        Size = UDim2.fromOffset(36, 3),
        Position = UDim2.fromOffset(0, 53),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, head)
    Corner(hb, 2)
    AccentGrad(hb, 0)

    Pages[id] = page
    return page
end

-- Section แบบพับ/ขยายได้ (จำสถานะไว้ใน Config)
local Collapsed = {}
for id in string.gmatch(Config.CollapsedSections, "[^|]+") do
    Collapsed[id] = true
end
local function SaveCollapsed()
    local t = {}
    for id, v in pairs(Collapsed) do
        if v then
            t[#t + 1] = id
        end
    end
    table.sort(t)
    SetConfig("CollapsedSections", table.concat(t, "|"))
end

local SectionsByPage = {}
local CurrentSection = nil

local function Section(page, title)
    local hdr = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Next(page),
    }, page)

    local bar = New("Frame", {
        Size = UDim2.fromOffset(3, 14),
        Position = UDim2.new(0, 2, 0.5, -7),
        BorderSizePixel = 0,
    }, hdr)
    Corner(bar, 2)
    bar.BackgroundColor3 = Color3.new(1, 1, 1)
    AccentGrad(bar, 90)

    local hl = New("Frame", {
        Size = UDim2.new(1, -4, 0, 1),
        Position = UDim2.new(0, 2, 1, -1),
        BorderSizePixel = 0,
    }, hdr)
    Bind(hl, "BackgroundColor3", "Stroke")
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, hl)

    local label = Text(hdr, title, 13, FNT.B, "Text")
    label.Position = UDim2.fromOffset(14, 0)
    label.Size = UDim2.new(1, -44, 1, 0)

    -- ลูกศร (วาดด้วยเส้น 2 เส้น)
    local chev = New("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        BackgroundTransparency = 1,
    }, hdr)
    local c1 = New("Frame", {
        Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(1, 6), Rotation = 45, BorderSizePixel = 0,
    }, chev)
    local c2 = New("Frame", {
        Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(6, 6), Rotation = -45, BorderSizePixel = 0,
    }, chev)
    Corner(c1, 1)
    Corner(c2, 1)
    OnTheme(function()
        c1.BackgroundColor3 = Theme.Muted
        c2.BackgroundColor3 = Theme.Muted
    end)

    local sec = { label = hdr, items = {}, collapsed = Collapsed[title] == true }
    function sec.refresh(animate)
        for _, it in ipairs(sec.items) do
            it.frame.Visible = it.matched and not sec.collapsed
        end
        local rot = sec.collapsed and -90 or 0
        if animate then
            Tween(chev, 0.18, { Rotation = rot })
        else
            chev.Rotation = rot
        end
    end
    sec.refresh(false)

    hdr.MouseButton1Click:Connect(function()
        sec.collapsed = not sec.collapsed
        Collapsed[title] = sec.collapsed
        SaveCollapsed()
        sec.refresh(true)
    end)

    CurrentSection = sec
    SectionsByPage[page] = SectionsByPage[page] or {}
    table.insert(SectionsByPage[page], sec)
    return sec
end

local function Register(row, search)
    local sec = CurrentSection
    if sec then
        table.insert(sec.items, { frame = row, search = string.lower(search or ""), matched = true })
        sec.refresh(false)
    end
end

local Refreshers = {}

--==================================================
-- COMPONENTS: Toggle / Slider / ColorRow
--==================================================

local FuncToggles = {}
local UpdateSummary = function() end

local function Toggle(page, opts)
    local row = Panel(page, UDim2.new(1, 0, 0, 64), "TextButton")
    HoverRow(row)
    Register(row, opts.title .. " " .. (opts.desc or ""))
    local rowStroke = row:FindFirstChildOfClass("UIStroke")

    local title = Text(row, opts.title, 13, FNT.M, "Text")
    title.Position = UDim2.fromOffset(18, 11)
    title.Size = UDim2.new(1, -96, 0, 20)

    local desc = Text(row, opts.desc or "", 11, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(18, 33)
    desc.Size = UDim2.new(1, -96, 0, 18)

    local strip = New("Frame", {
        Size = UDim2.fromOffset(3, 26),
        Position = UDim2.new(0, 4, 0.5, -13),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, row)
    Corner(strip, 2)
    AccentGrad(strip, 90)

    local glow = New("Frame", {
        Size = UDim2.fromOffset(62, 40),
        Position = UDim2.new(1, -71, 0.5, -20),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, row)
    Corner(glow, 20)
    AccentGrad(glow, 0)

    local track = New("Frame", {
        Size = UDim2.fromOffset(48, 26),
        Position = UDim2.new(1, -64, 0.5, -13),
        BorderSizePixel = 0,
    }, row)
    Corner(track, 13)
    local tStroke = Stroke(track, Theme.Stroke, 1, 0.2)
    Bind(tStroke, "Color", "Stroke")

    local fill = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, track)
    Corner(fill, 13)
    AccentGrad(fill, 0)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(3, 3),
        BorderSizePixel = 0,
    }, track)
    Corner(knob, 10)

    local state = Config[opts.key] == true

    if page == Pages["Functions"] then
        FuncToggles[#FuncToggles + 1] = function()
            return state
        end
    end

    local function render(animate)
        Apply(track, animate, { BackgroundColor3 = Theme.Button })
        Apply(fill, animate, { BackgroundTransparency = state and 0 or 1 })
        Apply(glow, animate, { BackgroundTransparency = state and 0.82 or 1 })
        Apply(knob, animate, {
            Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = state and Theme.OnAccent or Theme.Sub,
        })
        Apply(strip, animate, { BackgroundTransparency = state and 0 or 1 })
        Apply(tStroke, animate, { Color = state and Theme.Accent or Theme.Stroke })
        if rowStroke then
            Apply(rowStroke, animate, {
                Color = state and Theme.Accent or Theme.Stroke,
                Transparency = state and 0.55 or 0.4,
            })
        end
        UpdateSummary()
    end
    OnTheme(function()
        render(false)
    end)

    local function set(v, fire)
        state = v
        SetConfig(opts.key, v)
        render(true)
        if fire then
            PlayToggleSound(v)
            if opts.callback then
                task.spawn(opts.callback, v)
            end
        end
    end

    row.MouseButton1Click:Connect(function()
        set(not state, true)
    end)

    Refreshers[#Refreshers + 1] = function()
        state = Config[opts.key] == true
        render(false)
        if opts.callback then
            task.spawn(opts.callback, state)
        end
    end

    if opts.callback then
        task.defer(opts.callback, state)
    end

    return {
        Get = function()
            return state
        end,
        Set = function(v)
            set(v, true)
        end,
    }
end

local function Slider(page, opts)
    local min, max, step = opts.min, opts.max, opts.step or 1
    local row = Panel(page, UDim2.new(1, 0, 0, 78))
    Register(row, opts.title .. " " .. (opts.desc or ""))

    local title = Text(row, opts.title, 13, FNT.M, "Text")
    title.Position = UDim2.fromOffset(16, 10)
    title.Size = UDim2.new(1, -110, 0, 20)

    local desc = Text(row, opts.desc or "", 11, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(16, 31)
    desc.Size = UDim2.new(1, -110, 0, 16)

    local pill = New("Frame", {
        Size = UDim2.fromOffset(82, 22),
        Position = UDim2.new(1, -98, 0, 9),
        BorderSizePixel = 0,
    }, row)
    Corner(pill, 11)
    Bind(pill, "BackgroundColor3", "Surface2")
    Bind(Stroke(pill, Theme.Accent, 1, 0.6), "Color", "Accent")
    local val = Text(row, "", 12, FNT.B, "Accent", Enum.TextXAlignment.Center)
    val.Position = UDim2.new(1, -98, 0, 9)
    val.Size = UDim2.fromOffset(82, 22)

    local bar = New("Frame", {
        Size = UDim2.new(1, -32, 0, 6),
        Position = UDim2.fromOffset(16, 60),
        BorderSizePixel = 0,
    }, row)
    Corner(bar, 3)
    Bind(bar, "BackgroundColor3", "Button")

    local fill = New("Frame", {
        Size = UDim2.fromScale(0, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, bar)
    Corner(fill, 3)
    AccentGrad(fill, 0)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        BorderSizePixel = 0,
    }, bar)
    Corner(knob, 8)
    Bind(knob, "BackgroundColor3", "Text")
    Bind(Stroke(knob, Theme.Accent, 3, 0), "Color", "Accent")

    local hit = New("TextButton", {
        Size = UDim2.new(1, -32, 0, 30),
        Position = UDim2.fromOffset(16, 48),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local value = Config[opts.key]

    local function show()
        local a = (value - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.fromScale(a, 0.5)
        val.Text = string.format("%g", value) .. (opts.suffix or "")
    end

    local function setValue(v, fire)
        v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
        if v == value and fire then
            return
        end
        value = v
        show()
        if fire then
            SetConfig(opts.key, v)
            if opts.callback then
                task.spawn(opts.callback, v)
            end
        end
    end

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * a, true)
    end

    hit.InputBegan:Connect(function(input)
        if IsPointer(input) then
            dragging = true
            page.ScrollingEnabled = false
            Tween(knob, 0.12, { Size = UDim2.fromOffset(21, 21) })
            fromX(input.Position.X)
        end
    end)
    Track(UIS.InputChanged:Connect(function(input)
        if dragging and IsMove(input) then
            fromX(input.Position.X)
        end
    end))
    Track(UIS.InputEnded:Connect(function(input)
        if dragging and IsPointer(input) then
            dragging = false
            page.ScrollingEnabled = true
            Tween(knob, 0.12, { Size = UDim2.fromOffset(16, 16) })
        end
    end))

    value = math.clamp(value, min, max)
    show()

    Refreshers[#Refreshers + 1] = function()
        value = math.clamp(Config[opts.key], min, max)
        show()
        if opts.callback then
            task.spawn(opts.callback, value)
        end
    end

    if opts.callback then
        task.defer(opts.callback, value)
    end
end

-- ============================================================
--  COLOR PICKER v2  (สี่เหลี่ยมเฉด + แถบ Hue + HEX + พรีเซ็ต)
--  เปลี่ยนสีแล้วเซฟอัตโนมัติผ่าน SetConfig เหมือนเดิม
-- ============================================================
local PaletteColors = {
    "FFFFFF", "BEBEBE", "6B6B76", "2A2A33", "0E0E14", "000000", "8B5CF6", "6366F1",
    "3B82F6", "22D3EE", "10B981", "84CC16", "FACC15", "FB923C", "EF4444", "EC4899",
}

local ActiveOverlay, ActivePopup
local PaletteConns = {}

local function ClosePalette()
    for _, c in ipairs(PaletteConns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    PaletteConns = {}
    if ActiveOverlay then
        ActiveOverlay:Destroy()
        ActiveOverlay = nil
    end
    if ActivePopup then
        ActivePopup:Destroy()
        ActivePopup = nil
    end
end

-- รวมการอัปเดตธีมให้เหลือครั้งเดียวต่อเฟรม (ลากสีแล้วไม่หน่วง)
local themePending = false
local function QueueTheme()
    if themePending then
        return
    end
    themePending = true
    task.defer(function()
        themePending = false
        ApplyTheme()
    end)
end

local function OpenPalette(title, key, onPick)
    ClosePalette()

    ActiveOverlay = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 150,
    }, Screen)
    Tween(ActiveOverlay, 0.2, { BackgroundTransparency = 0.45 })
    ActiveOverlay.MouseButton1Click:Connect(ClosePalette)

    local PW, PH = 240, 304
    local pop = New("CanvasGroup", {
        Size = UDim2.fromOffset(PW, PH),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 160,
        Active = true,
    }, Screen)
    Corner(pop, 16)
    Stroke(pop, Theme.Accent, 1.5, 0.35)
    local vs = ViewSize()
    New("UIScale", { Scale = math.clamp((vs.Y - 24) / PH, 0.5, 1) }, pop)
    ActivePopup = pop
    Tween(pop, 0.2, { GroupTransparency = 0 })

    -- สีเริ่มต้นจาก Config
    local okc, c0 = pcall(Color3.fromHex, Config[key])
    if not okc then
        c0 = Color3.new(1, 1, 1)
    end
    local H, S, V = c0:ToHSV()

    -- หัวข้อ + พรีวิว + ปุ่มปิด
    local ttl = Text(pop, title or "เลือกสี", 13, FNT.B, Theme.Text)
    ttl.Position = UDim2.fromOffset(14, 10)
    ttl.Size = UDim2.new(1, -130, 0, 20)

    local prev = New("Frame", {
        Size = UDim2.fromOffset(36, 18),
        Position = UDim2.fromOffset(PW - 82, 11),
        BorderSizePixel = 0,
    }, pop)
    Corner(prev, 6)
    Stroke(prev, Color3.new(1, 1, 1), 1, 0.75)

    local closeB = New("TextButton", {
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.fromOffset(PW - 38, 8),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "×",
        TextSize = 18,
        Font = FNT.B,
        TextColor3 = Theme.Sub,
        AutoButtonColor = false,
    }, pop)
    Corner(closeB, 8)
    closeB.MouseButton1Click:Connect(ClosePalette)

    -- สี่เหลี่ยมเลือก Saturation / Value
    local sv = New("Frame", {
        Size = UDim2.fromOffset(PW - 28, 124),
        Position = UDim2.fromOffset(14, 40),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromHSV(H, 1, 1),
    }, pop)
    Corner(sv, 10)
    local wf = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, sv)
    Corner(wf, 10)
    New("UIGradient", { Transparency = NumberSequence.new(0, 1) }, wf)
    local bf = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, sv)
    Corner(bf, 10)
    New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, bf)
    local svCur = New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, sv)
    Corner(svCur, 8)
    Stroke(svCur, Color3.new(1, 1, 1), 2.5, 0)
    local svHit = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, sv)

    -- แถบ Hue
    local hue = New("Frame", {
        Size = UDim2.fromOffset(PW - 28, 14),
        Position = UDim2.fromOffset(14, 176),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, pop)
    Corner(hue, 7)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
    }, hue)
    local hueCur = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
    }, hue)
    Corner(hueCur, 9)
    Stroke(hueCur, Color3.new(1, 1, 1), 2.5, 0)
    local hueHit = New("TextButton", {
        Size = UDim2.new(1, 0, 1, 12),
        Position = UDim2.fromOffset(0, -6),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, hue)

    -- ช่อง HEX
    local box = New("TextBox", {
        Size = UDim2.fromOffset(PW - 28, 30),
        Position = UDim2.fromOffset(14, 202),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "#RRGGBB",
        ClearTextOnFocus = false,
        TextSize = 12,
        Font = FNT.M,
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
    }, pop)
    Corner(box, 9)
    Stroke(box, Theme.Stroke, 1, 0.3)

    local function render(fromBox)
        local c = Color3.fromHSV(H, S, V)
        sv.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        svCur.Position = UDim2.fromScale(S, 1 - V)
        hueCur.Position = UDim2.fromScale(H, 0.5)
        hueCur.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        prev.BackgroundColor3 = c
        if not fromBox then
            box.Text = "#" .. string.upper(c:ToHex())
        end
        return c
    end
    local function commit(fromBox)
        onPick(render(fromBox))
    end
    render(false)

    -- ลาก (รองรับเมาส์/ทัช, ชดเชย GuiInset อัตโนมัติ)
    local function bindDrag(hit, onMove)
        local dragging, dInput = false, nil
        local off = Vector2.zero
        hit.InputBegan:Connect(function(input)
            if not IsPointer(input) then
                return
            end
            local p = Vector2.new(input.Position.X, input.Position.Y)
            local a, sz = hit.AbsolutePosition, hit.AbsoluteSize
            local inset = GuiService:GetGuiInset()
            local q = p + inset
            local inside = q.X >= a.X and q.X <= a.X + sz.X and q.Y >= a.Y and q.Y <= a.Y + sz.Y
            off = inside and inset or Vector2.zero
            dragging = true
            dInput = input
            onMove(p + off)
        end)
        PaletteConns[#PaletteConns + 1] = UIS.InputChanged:Connect(function(input)
            if dragging and IsMove(input) then
                if input.UserInputType == Enum.UserInputType.Touch and input ~= dInput then
                    return
                end
                onMove(Vector2.new(input.Position.X, input.Position.Y) + off)
            end
        end)
        PaletteConns[#PaletteConns + 1] = UIS.InputEnded:Connect(function(input)
            if dragging and IsPointer(input) then
                if input.UserInputType == Enum.UserInputType.Touch and input ~= dInput then
                    return
                end
                dragging = false
            end
        end)
    end

    bindDrag(svHit, function(pos)
        S = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
        V = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
        commit(false)
    end)
    bindDrag(hueHit, function(pos)
        H = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(1, hue.AbsoluteSize.X), 0, 1)
        commit(false)
    end)

    box.FocusLost:Connect(function()
        local h = string.match(box.Text, "^%s*#?(%x%x%x%x%x%x)%s*$")
        if h then
            H, S, V = Color3.fromHex(h):ToHSV()
            commit(false)
        else
            box.TextColor3 = RGB(235, 75, 90)
            task.delay(0.8, function()
                if box.Parent then
                    box.TextColor3 = Theme.Text
                    render(false)
                end
            end)
        end
    end)

    -- สีสำเร็จรูป
    for i, hexv in ipairs(PaletteColors) do
        local c = Color3.fromHex(hexv)
        local sw = New("TextButton", {
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.fromOffset(14 + ((i - 1) % 8) * 27, 244 + math.floor((i - 1) / 8) * 28),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, pop)
        Corner(sw, 11)
        Stroke(sw, Color3.new(1, 1, 1), 1, 0.8)
        sw.MouseButton1Click:Connect(function()
            H, S, V = c:ToHSV()
            commit(false)
        end)
    end
end

local ColorRefreshers = {}

local function ColorRow(page, title, key)
    local row = Panel(page, UDim2.new(1, 0, 0, 50), "TextButton")
    HoverRow(row)
    Register(row, title)

    local t = Text(row, title, 12, FNT.M, "Text")
    t.Position = UDim2.fromOffset(18, 0)
    t.Size = UDim2.new(1, -176, 1, 0)

    local hexLabel = Text(row, "", 10, FNT.M, "Muted", Enum.TextXAlignment.Right)
    hexLabel.Position = UDim2.new(1, -152, 0, 0)
    hexLabel.Size = UDim2.fromOffset(84, 50)

    local swatch = New("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -60, 0.5, -12),
        BorderSizePixel = 0,
    }, row)
    Corner(swatch, 8)
    Stroke(swatch, Color3.new(1, 1, 1), 1, 0.7)

    local function refresh()
        swatch.BackgroundColor3 = Hex(key, RGB(100, 100, 100))
        hexLabel.Text = string.upper(tostring(Config[key]))
    end
    refresh()
    Refreshers[#Refreshers + 1] = refresh
    ColorRefreshers[#ColorRefreshers + 1] = refresh

    row.MouseButton1Click:Connect(function()
        OpenPalette(title, key, function(c)
            SetConfig(key, "#" .. string.upper(c:ToHex()))
            refresh()
            QueueTheme()
        end)
    end)
end

-- ธีมสำเร็จรูป: แตะครั้งเดียวเปลี่ยนทั้ง UI + ปุ่ม RX (เซฟอัตโนมัติ)
local ThemePresets = {
    { "Graphite", "#C9CBD3", "#0A0A0C", "#232328" },
    { "Violet", "#8B5CF6", "#09090D", "#1C1C26" },
    { "Crimson", "#F43F5E", "#0B0708", "#26151A" },
    { "Cyber", "#22D3EE", "#06090C", "#122029" },
    { "Toxic", "#4ADE80", "#060A07", "#13211A" },
    { "Sunset", "#FB923C", "#0C0805", "#271A10" },
}

local function ThemeGrid(page)
    local holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = Next(page),
    }, page)
    New("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -7, 0, 56),
        CellPadding = UDim2.fromOffset(10, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)
    Register(holder, "ธีม theme preset สำเร็จรูป")

    for _, p in ipairs(ThemePresets) do
        local card = Panel(holder, nil, "TextButton")
        HoverRow(card)

        local function dot(hex, x)
            local d = New("Frame", {
                Size = UDim2.fromOffset(22, 22),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, x, 0.5, 0),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromHex(hex),
            }, card)
            Corner(d, 11)
            Stroke(d, Color3.new(1, 1, 1), 1, 0.8)
        end
        dot(p[3], 12)
        dot(p[4], 24)
        dot(p[2], 36)

        local n = Text(card, p[1], 12, FNT.M, "Text")
        n.Position = UDim2.fromOffset(68, 0)
        n.Size = UDim2.new(1, -74, 1, 0)

        card.MouseButton1Click:Connect(function()
            SetConfig("UIAccentColor", p[2])
            SetConfig("UIBackgroundColor", p[3])
            SetConfig("UIButtonColor", p[4])
            SetConfig("FloatingButtonColor", p[3])
            SetConfig("FloatingBorderColor", p[2])
            SetConfig("FloatingGlowColor", p[2])
            for _, fn in ipairs(ColorRefreshers) do
                pcall(fn)
            end
            QueueTheme()
            Toast("ใช้ธีม " .. p[1])
        end)
    end
end

--==================================================
-- HOME
--==================================================

local Home = MakePage("Home", "หน้าหลัก", "ภาพรวมและข้อมูลเซิร์ฟเวอร์")

-- การ์ดต้อนรับ
local Hero = Panel(Home, UDim2.new(1, 0, 0, 84))
Tint(Hero)
local HeroSub = Text(Hero, "", 11, FNT.M, "Muted")
HeroSub.Position = UDim2.fromOffset(20, 14)
HeroSub.Size = UDim2.new(0.6, 0, 0, 16)
local HeroName = Text(Hero, LocalPlayer.DisplayName, 24, FNT.B, Color3.new(1, 1, 1))
HeroName.Position = UDim2.fromOffset(20, 32)
HeroName.Size = UDim2.new(0.6, 0, 0, 38)
AccentGrad(HeroName, 0)
local HeroClock = Text(Hero, "", 26, FNT.B, "Text", Enum.TextXAlignment.Right)
HeroClock.Position = UDim2.new(0.5, 0, 0, 16)
HeroClock.Size = UDim2.new(0.5, -20, 0, 34)
local HeroDate = Text(Hero, "", 10, FNT.M, "Muted", Enum.TextXAlignment.Right)
HeroDate.Position = UDim2.new(0.5, 0, 0, 52)
HeroDate.Size = UDim2.new(0.5, -20, 0, 16)

-- การ์ดแมพ (รูปไอคอนแมพจริงจาก Roblox)
local MapImage = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150"

local MapCard = Panel(Home, UDim2.new(1, 0, 0, 116))
MapCard.ClipsDescendants = true

local MapBG = New("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = MapImage,
    ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0.86,
}, MapCard)
Corner(MapBG, 12)

local MapFade = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, MapCard)
Bind(MapFade, "BackgroundColor3", "Surface")
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.7),
    }),
}, MapFade)
Corner(MapFade, 12)
Tint(MapCard)

local MapIcon = New("ImageLabel", {
    Size = UDim2.fromOffset(84, 84),
    Position = UDim2.fromOffset(16, 16),
    BorderSizePixel = 0,
    Image = MapImage,
    ScaleType = Enum.ScaleType.Crop,
}, MapCard)
Corner(MapIcon, 16)
Bind(MapIcon, "BackgroundColor3", "Button")
Bind(Stroke(MapIcon, Theme.Stroke, 1.5, 0.1), "Color", "Stroke")

local MapName = Text(MapCard, tostring(game.Name or "Unknown"), 17, FNT.B, "Text")
MapName.Position = UDim2.fromOffset(112, 16)
MapName.Size = UDim2.new(1, -128, 0, 26)

local MapBy = Text(MapCard, "กำลังโหลดข้อมูลแมพ...", 11, FNT.R, "Muted")
MapBy.Position = UDim2.fromOffset(112, 43)
MapBy.Size = UDim2.new(1, -128, 0, 16)

local Chips = New("Frame", {
    Size = UDim2.new(1, -128, 0, 24),
    Position = UDim2.fromOffset(112, 72),
    BackgroundTransparency = 1,
}, MapCard)
New("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Chips)

local function Chip(text)
    local c = New("TextLabel", {
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        Text = text,
        TextSize = 10,
        Font = FNT.M,
        LayoutOrder = Next(Chips),
    }, Chips)
    Bind(c, "BackgroundColor3", "Surface2")
    Bind(c, "TextColor3", "Sub")
    Corner(c, 12)
    Pad(c, 10, 10, 0, 0)
    return c
end

local ChipPlace = Chip("ID " .. tostring(game.PlaceId))
local ChipPlayers = Chip("ผู้เล่น -/-")

task.spawn(function()
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info then
            if info.Name and info.Name ~= "" then
                MapName.Text = tostring(info.Name)
                BrandSub.Text = tostring(info.Name)
            end
            if info.Creator and info.Creator.Name then
                MapBy.Text = "โดย " .. tostring(info.Creator.Name)
            else
                MapBy.Text = ""
            end
        end
    end)
end)

local function Stat(parent, label, size)
    local c = Panel(parent, size)
    local bar = New("Frame", {
        Size = UDim2.fromOffset(3, 18),
        Position = UDim2.fromOffset(0, 12),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, c)
    Corner(bar, 2)
    AccentGrad(bar, 90)
    local l = Text(c, label, 10, FNT.M, "Muted")
    l.Position = UDim2.fromOffset(16, 11)
    l.Size = UDim2.new(1, -30, 0, 14)
    local v = Text(c, "-", 14, FNT.B, "Text")
    v.Position = UDim2.fromOffset(16, 30)
    v.Size = UDim2.new(1, -30, 0, 22)
    return v
end

local Grid = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder = Next(Home),
}, Home)
New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 64),
    CellPadding = UDim2.fromOffset(10, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Grid)

local StatPlayer = Stat(Grid, "ผู้เล่น")
local StatTime = Stat(Grid, "เวลาในเซิร์ฟ")
local StatFps = Stat(Grid, "FPS")
local StatPing = Stat(Grid, "Ping")

-- กราฟ FPS ย้อนหลัง
local PerfCard = Panel(Home, UDim2.new(1, 0, 0, 120))
Tint(PerfCard)
local PerfTitle = Text(PerfCard, "ประสิทธิภาพ (FPS)", 12, FNT.B, "Text")
PerfTitle.Position = UDim2.fromOffset(18, 12)
PerfTitle.Size = UDim2.new(0.5, 0, 0, 18)
local PerfAvg = Text(PerfCard, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Right)
PerfAvg.Position = UDim2.new(0.5, 0, 0, 12)
PerfAvg.Size = UDim2.new(0.5, -18, 0, 18)
local PerfBars = New("Frame", {
    Size = UDim2.new(1, -36, 0, 68),
    Position = UDim2.fromOffset(18, 40),
    BackgroundTransparency = 1,
}, PerfCard)

local PERF_N = 36
local PerfBar, PerfHist = {}, {}
for i = 1, PERF_N do
    local b = New("Frame", {
        Size = UDim2.new(1 / PERF_N, -2, 0, 2),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new((i - 1) / PERF_N, 1, 1, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, PerfBars)
    Corner(b, 2)
    PerfBar[i] = b
    PerfHist[i] = 0
end

local function PerfUpdate()
    table.remove(PerfHist, 1)
    PerfHist[#PerfHist + 1] = Metrics.fps
    local peak, sum, cnt = 60, 0, 0
    for _, v in ipairs(PerfHist) do
        if v > peak then
            peak = v
        end
        if v > 0 then
            sum = sum + v
            cnt = cnt + 1
        end
    end
    for i, v in ipairs(PerfHist) do
        local b = PerfBar[i]
        b.Size = UDim2.new(1 / PERF_N, -2, math.clamp(v / peak, 0.04, 1), 0)
        b.BackgroundColor3 = Level(v, 50, 30, true)
        b.BackgroundTransparency = v == 0 and 1 or 0.08
    end
    PerfAvg.Text = "เฉลี่ย " .. tostring(cnt > 0 and math.floor(sum / cnt + 0.5) or 0) .. " FPS"
end

local sessionStart = os.time()

local function RefreshHome()
    local hr = tonumber(os.date("%H")) or 12
    HeroSub.Text = (hr >= 5 and hr < 12 and "อรุณสวัสดิ์")
        or (hr >= 12 and hr < 17 and "สวัสดีตอนบ่าย")
        or (hr >= 17 and hr < 21 and "สวัสดีตอนเย็น")
        or "ราตรีสวัสดิ์"
    HeroClock.Text = os.date("%H:%M")
    HeroDate.Text = os.date("%d / %m / %Y")
    local sec = math.max(0, os.time() - sessionStart)
    StatPlayer.Text = LocalPlayer.DisplayName
    StatTime.Text = string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
    StatFps.Text = tostring(Metrics.fps)
    StatFps.TextColor3 = Level(Metrics.fps, 50, 30, true)
    StatPing.Text = tostring(Metrics.ping) .. " ms"
    StatPing.TextColor3 = Level(Metrics.ping, 80, 160, false)
    ChipPlayers.Text = string.format("ผู้เล่น %d/%d", #Players:GetPlayers(), Players.MaxPlayers)
    PerfUpdate()
end

task.spawn(function()
    while Screen.Parent do
        RefreshStats()
        RefreshHome()
        task.wait(0.5)
    end
end)

--==================================================
-- FUNCTIONS
--==================================================

local Functions = MakePage("Functions", "ฟังก์ชัน", "เปิด / ปิดการใช้งานได้ทันที  •  เซฟอัตโนมัติ")

--==================================================
-- >>> ADD YOUR FUNCTIONS <<<
-- เพิ่มฟังก์ชันใหม่ (ค่าจะเซฟ/โหลดอัตโนมัติ):
--   1) เพิ่มคีย์ใน Defaults ด้านบน เช่น  AutoFarm = false
--   2) Toggle(Functions, { key="AutoFarm", title="...", desc="...", callback=function(v) ... end })
--   3) Slider(Functions, { key="Speed", title="...", desc="...", min=0, max=100, step=1, callback=function(v) end })
--   4) จัดกลุ่มด้วย Section(Functions, "ชื่อหมวด") ก่อนเพิ่มแถวของหมวดนั้น
-- callback จะถูกเรียกอัตโนมัติตอนโหลด Config (ฟังก์ชันที่เปิดไว้จะทำงานต่อทันที)
--==================================================

Section(Functions, "ฟังก์ชันหลัก")

Toggle(Functions, {
    key = "ExampleFunctionEnabled",
    title = "ฟังก์ชันตัวอย่าง",
    desc = "เปิดใช้งาน / ปิดใช้งาน",
    callback = function(v)
        print("[RELWX] ExampleFunction:", v and "ON" or "OFF")
    end,
})

Slider(Functions, {
    key = "ExampleSlider",
    title = "ค่าตัวอย่าง",
    desc = "ลากเพื่อปรับค่า",
    min = 0,
    max = 100,
    step = 1,
    suffix = "%",
    callback = function(v) end,
})

Section(Functions, "ฟังก์ชันเสริม")

Toggle(Functions, {
    key = "ExampleFunction2Enabled",
    title = "ฟังก์ชันตัวอย่าง 2",
    desc = "ตัวอย่างการจัดกลุ่มแบบพับได้",
    callback = function(v)
        print("[RELWX] ExampleFunction2:", v and "ON" or "OFF")
    end,
})

--==================================================
-- SETTINGS
--==================================================

local Settings = MakePage("Settings", "ตั้งค่า", "ปรับแต่งหน้าตา RELWX  •  เปลี่ยนแล้วเซฟทันที")

Section(Settings, "ระบบ")

Toggle(Settings, {
    key = "SoundEnabled",
    title = "เสียงตอนเปิด/ปิดฟังก์ชัน",
    desc = "เล่นเสียงสั้นๆ เมื่อกดสวิตช์",
})

Toggle(Settings, {
    key = "StatsVisible",
    title = "แสดง FPS / MS",
    desc = "กล่องเล็กลากย้ายตำแหน่งได้",
    callback = function(v)
        StatsGui.Enabled = v
    end,
})

Slider(Settings, {
    key = "UIScalePercent",
    title = "ขนาดหน้าต่าง",
    desc = "ปรับเพิ่มจากขนาดอัตโนมัติตามหน้าจอ",
    min = 60,
    max = 120,
    step = 5,
    suffix = "%",
    callback = function()
        ApplyScale(true)
    end,
})

Section(Settings, "ธีมสำเร็จรูป")
ThemeGrid(Settings)

Section(Settings, "ธีม UI")
ColorRow(Settings, "สีหลัก UI", "UIAccentColor")
ColorRow(Settings, "สีพื้นหลัง UI", "UIBackgroundColor")
ColorRow(Settings, "สีปุ่ม UI", "UIButtonColor")

Section(Settings, "ปุ่มลอย RX")
ColorRow(Settings, "สีปุ่ม RX", "FloatingButtonColor")
ColorRow(Settings, "สีขอบ RX", "FloatingBorderColor")
ColorRow(Settings, "สี Glow RX", "FloatingGlowColor")

Section(Settings, "Config")

local CfgCard = Panel(Settings, UDim2.new(1, 0, 0, 64))
local CfgTitle = Text(CfgCard, "บันทึกอัตโนมัติ", 13, FNT.M, "Text")
CfgTitle.Position = UDim2.fromOffset(16, 11)
CfgTitle.Size = UDim2.new(1, -140, 0, 20)
local CfgDesc = Text(
    CfgCard,
    writefile and CONFIG_FILE or "executor นี้ไม่รองรับการเขียนไฟล์",
    10,
    FNT.R,
    "Muted"
)
CfgDesc.Position = UDim2.fromOffset(16, 33)
CfgDesc.Size = UDim2.new(1, -140, 0, 18)
local CfgPill = StatusPill(CfgCard, 108)
CfgPill.AnchorPoint = Vector2.new(1, 0.5)
CfgPill.Position = UDim2.new(1, -14, 0.5, 0)

local ResetRow = Panel(Settings, UDim2.new(1, 0, 0, 50), "TextButton")
HoverRow(ResetRow)
local ResetLabel = Text(ResetRow, "รีเซ็ตการตั้งค่าทั้งหมด", 12, FNT.M, RGB(235, 90, 100))
ResetLabel.Position = UDim2.fromOffset(16, 0)
ResetLabel.Size = UDim2.new(1, -32, 1, 0)

local FloatApplyPosition

local resetArmed = false
ResetRow.MouseButton1Click:Connect(function()
    if not resetArmed then
        resetArmed = true
        ResetLabel.Text = "กดอีกครั้งเพื่อยืนยันการรีเซ็ต"
        task.delay(3, function()
            resetArmed = false
            ResetLabel.Text = "รีเซ็ตการตั้งค่าทั้งหมด"
        end)
        return
    end
    resetArmed = false
    ResetLabel.Text = "รีเซ็ตการตั้งค่าทั้งหมด"

    for k, v in pairs(Defaults) do
        Config[k] = v
    end
    Collapsed = {}
    for _, secs in pairs(SectionsByPage) do
        for _, sec in ipairs(secs) do
            sec.collapsed = false
            sec.refresh(true)
        end
    end
    ApplyTheme()
    for _, fn in ipairs(Refreshers) do
        pcall(fn)
    end
    Tween(Main, 0.3, { Position = UDim2.fromScale(Config.WindowX, Config.WindowY) }, Enum.EasingStyle.Quint)
    ApplyScale(true)
    if FloatApplyPosition then
        FloatApplyPosition()
    end
    StatsBox.Position = UDim2.fromScale(Config.StatsX, Config.StatsY)
    StatsGui.Enabled = Config.StatsVisible
    SelectTab(Config.LastTab)
    SaveConfig(true)
    Toast("รีเซ็ตการตั้งค่าแล้ว")
end)

--==================================================
-- SIDEBAR CATEGORIES
--==================================================

CatGroup("เมนูหลัก")
Category("หน้าหลัก", "Home", "grid")
Category("ฟังก์ชัน", "Functions", "sliders")
CatGroup("ระบบ")
Category("ตั้งค่า", "Settings", "ring")

--==================================================
-- FLOATING RX BUTTON
--==================================================

local ToggleGui = New("ScreenGui", {
    Name = "RELWX_Floating",
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
}, PlayerGui)

local Float = New("Frame", {
    Size = UDim2.fromOffset(48, 48),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.FloatX, Config.FloatY),
    BackgroundTransparency = 1,
    Active = true,
}, ToggleGui)

local Glow = New("Frame", {
    Size = UDim2.new(1, 8, 1, 8),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
}, Float)
Corner(Glow, 15)
local GlowStroke = Stroke(Glow, RGB(145, 145, 145), 3, 0.2)

local RX = New("TextButton", {
    Size = UDim2.fromScale(1, 1),
    Text = "RX",
    TextSize = 15,
    Font = FNT.B,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Active = true,
}, Float)
Corner(RX, 13)
local RXStroke = Stroke(RX, RGB(255, 255, 255), 2, 0.05)
local RXGrad = New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.85),
        NumberSequenceKeypoint.new(1, 0),
    }),
}, RXStroke)
TweenService:Create(
    RXGrad,
    TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()

OnTheme(function()
    local bg = Hex("FloatingButtonColor", RGB(18, 18, 18))
    RX.BackgroundColor3 = bg
    RX.TextColor3 = Lum(bg) > 0.55 and RGB(15, 15, 15) or RGB(255, 255, 255)
    RXStroke.Color = Hex("FloatingBorderColor", RGB(255, 255, 255))
    GlowStroke.Color = Hex("FloatingGlowColor", RGB(145, 145, 145))
end)

TweenService:Create(
    GlowStroke,
    TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Transparency = 0.65 }
):Play()

FloatApplyPosition = function()
    Float.Position = UDim2.fromScale(Config.FloatX, Config.FloatY)
end

MakeDraggable(RX, Float, "FloatX", "FloatY", function()
    SetWindow(not Config.WindowVisible)
end)

--==================================================
-- START
--==================================================

SelectTab(Config.LastTab)
RefreshStats()
RefreshHome()

if Config.WindowVisible then
    PlayOpen()
end

if not LoadedFromFile then
    SaveConfig(true) -- สร้างไฟล์ Config ครั้งแรก
end

print("[RELWX] UI v7 Loaded" .. (LoadedFromFile and " (Config loaded)" or " (new Config)"))

-- Legacy feature API adapter: the game features now render with native Relwx UI components.
local LegacyTabs = {}
local LegacyCounter = 0
local function safeFlag(flag, default)
    local key = tostring(flag or ("RelwxOption" .. tostring(LegacyCounter)))
    if Config[key] == nil then Config[key] = default end
    return key
end
local function normalizeOptions(value)
    if type(value) == "table" then return value end
    if value == nil then return {} end
    return { value }
end
local function makeLegacyGroup(page, groupName)
    Section(page, tostring(groupName or "ตัวเลือก"))
    local group = {}
    function group:CreateToggle(opts)
        opts = opts or {}; LegacyCounter += 1
        local key = safeFlag(opts.Flag, opts.CurrentValue == true)
        return Toggle(page, { key = key, title = opts.Name or key, desc = opts.Description or opts.Tooltip or "", callback = opts.Callback })
    end
    function group:CreateSlider(opts)
        opts = opts or {}; LegacyCounter += 1
        local range = opts.Range or { 0, 100 }
        local key = safeFlag(opts.Flag, tonumber(opts.CurrentValue) or range[1] or 0)
        return Slider(page, { key = key, title = opts.Name or key, desc = opts.Description or "", min = tonumber(range[1]) or 0, max = tonumber(range[2]) or 100, step = tonumber(opts.Increment) or 1, callback = opts.Callback })
    end
    function group:CreateDropdown(opts)
        opts = opts or {}; LegacyCounter += 1
        local key = safeFlag(opts.Flag, opts.CurrentOption or "")
        local options = normalizeOptions(opts.Options)
        local multi = type(opts.CurrentOption) == "table"
        if type(Config[key]) ~= (multi and "table" or "string") then Config[key] = opts.CurrentOption or (multi and {} or (options[1] or "")) end
        local row = Panel(page, UDim2.new(1, 0, 0, 66), "TextButton")
        HoverRow(row); Register(row, (opts.Name or key) .. " " .. table.concat((function() local t={} for _,v in ipairs(options) do t[#t+1]=tostring(v) end return t end)(), " "))
        local title = Text(row, tostring(opts.Name or key), 13, FNT.M, "Text")
        title.Position = UDim2.fromOffset(16, 8); title.Size = UDim2.new(1, -32, 0, 20)
        local valueLabel = Text(row, "", 11, FNT.R, "Muted")
        valueLabel.Position = UDim2.fromOffset(16, 32); valueLabel.Size = UDim2.new(1, -32, 0, 24); valueLabel.TextWrapped = true
        local function currentText()
            local v = Config[key]
            if type(v) == "table" then return #v > 0 and table.concat((function() local t={} for _,x in ipairs(v) do t[#t+1]=tostring(x) end return t end)(), ", ") or "ไม่มี" end
            return tostring(v)
        end
        local function repaint() valueLabel.Text = currentText() .. "  ▾" end
        local function fire()
            SaveConfig()
            repaint()
            if opts.Callback then task.spawn(opts.Callback, type(Config[key]) == "table" and table.clone(Config[key]) or { Config[key] }) end
        end
        row.MouseButton1Click:Connect(function()
            if #options == 0 then return end
            if multi then
                local selected = normalizeOptions(Config[key]); local candidate = options[1]
                local last = 0
                for i, option in ipairs(options) do if table.find(selected, option) then last = i end end
                local idx = (last % #options) + 1; candidate = options[idx]
                if table.find(selected, candidate) then
                    for i=#selected,1,-1 do if selected[i] == candidate then table.remove(selected,i) end end
                else table.insert(selected, candidate) end
                Config[key] = selected
            else
                local idx = table.find(options, Config[key]) or 0
                Config[key] = options[(idx % #options) + 1]
            end
            fire()
        end)
        repaint()
        if opts.Callback then task.defer(opts.Callback, type(Config[key]) == "table" and table.clone(Config[key]) or { Config[key] }) end
        return { Get = function() return Config[key] end, Set = function(_,v) Config[key]=v; fire() end }
    end
    function group:CreateInput(opts)
        opts = opts or {}; LegacyCounter += 1
        local key = safeFlag(opts.Flag, tostring(opts.CurrentValue or ""))
        local row = Panel(page, UDim2.new(1, 0, 0, 72))
        Register(row, (opts.Name or key) .. " " .. tostring(opts.PlaceholderText or ""))
        local title = Text(row, tostring(opts.Name or key), 13, FNT.M, "Text")
        title.Position = UDim2.fromOffset(14, 7); title.Size = UDim2.new(1, -28, 0, 20)
        local input = New("TextBox", { Size=UDim2.new(1,-28,0,30), Position=UDim2.fromOffset(14,34), BackgroundColor3=Theme.Button, BorderSizePixel=0, ClearTextOnFocus=false, Text=tostring(Config[key] or ""), PlaceholderText=tostring(opts.PlaceholderText or ""), TextSize=12, Font=FNT.R, TextColor3=Theme.Text, PlaceholderColor3=Theme.Muted, TextXAlignment=Enum.TextXAlignment.Left }, row)
        Corner(input, 8); Pad(input, 8, 8, 0, 0)
        input.FocusLost:Connect(function() SetConfig(key,input.Text); if opts.Callback then task.spawn(opts.Callback,input.Text) end end)
        if opts.Callback then task.defer(opts.Callback, input.Text) end
        return input
    end
    function group:CreateButton(opts)
        opts = opts or {}
        local row = Panel(page, UDim2.new(1, 0, 0, 46), "TextButton"); HoverRow(row); Register(row, opts.Name or "Action")
        local label = Text(row, tostring(opts.Name or "กดใช้งาน"), 12, FNT.M, "Text")
        label.Position=UDim2.fromOffset(14,0); label.Size=UDim2.new(1,-28,1,0)
        row.MouseButton1Click:Connect(function() if opts.Callback then task.spawn(opts.Callback) end end)
        return row
    end
    function group:CreateStatus(opts)
        opts = opts or {}
        local row = Panel(page, UDim2.new(1,0,0,46)); Register(row, opts.Name or "สถานะ")
        local label = Text(row, tostring(opts.Name or "สถานะ") .. ": กำลังโหลด", 11, FNT.R, "Muted")
        label.Position=UDim2.fromOffset(12,0); label.Size=UDim2.new(1,-24,1,0); label.TextWrapped=true
        local function update()
            if not opts.Update then label.Text=tostring(opts.Name or "สถานะ"); return end
            local ok,a,b=pcall(opts.Update)
            if not ok then label.Text=tostring(opts.Name or "สถานะ") .. ": error"; return end
            if type(a)=="table" then label.Text=tostring(opts.Name or "สถานะ") .. "\n" .. tostring(a.Value or a.Text or a[1] or "-")
            elseif a ~= nil then label.Text=tostring(opts.Name or "สถานะ") .. ": " .. tostring(a) .. (b and (" ("..tostring(b)..")") or "") end
        end
        task.spawn(function() while row.Parent do update(); task.wait(math.max(0.5, tonumber(opts.UpdateRate) or 2)) end end)
        return row
    end
    function group:CreateStatusList(opts)
        opts=opts or {}
        local row=Panel(page,UDim2.new(1,0,0,math.clamp((opts.MaxRows or 6)*22+24,70,220)))
        local label=Text(row,tostring(opts.Name or "สถานะ"),12,FNT.M,"Text"); label.Position=UDim2.fromOffset(12,5); label.Size=UDim2.new(1,-24,0,18)
        local body=Text(row,tostring(opts.EmptyText or "ไม่มีข้อมูล"),10,FNT.R,"Muted"); body.Position=UDim2.fromOffset(12,25); body.Size=UDim2.new(1,-24,1,-30); body.TextYAlignment=Enum.TextYAlignment.Top; body.TextWrapped=true
        task.spawn(function() while row.Parent do local ok,rows=pcall(opts.Update or function() return {} end); if ok and type(rows)=="table" then local out={} for i,item in ipairs(rows) do if i>(opts.MaxRows or 6) then break end; if type(item)=="table" then out[#out+1]=tostring(item.Text or item.Name or "")..": "..tostring(item.Value or "") else out[#out+1]=tostring(item) end end; body.Text=#out>0 and table.concat(out,"\n") or tostring(opts.EmptyText or "ไม่มีข้อมูล") end; task.wait(math.max(0.5,tonumber(opts.UpdateRate) or 2)) end end)
        return row
    end
    function group:CreateColorPicker(opts)
        opts=opts or {}; local row=Panel(page,UDim2.new(1,0,0,42),"TextButton"); HoverRow(row)
        local label=Text(row,tostring(opts.Name or "สี"),12,FNT.M,"Text"); label.Position=UDim2.fromOffset(12,0); label.Size=UDim2.new(1,-24,1,0)
        local swatch=New("Frame",{Size=UDim2.fromOffset(22,22),Position=UDim2.new(1,-34,0.5,-11),BorderSizePixel=0,BackgroundColor3=typeof(opts.Default)=="Color3" and opts.Default or Theme.Accent},row); Corner(swatch,6)
        local colors={Color3.fromRGB(255,255,255),Color3.fromRGB(200,200,210),Color3.fromRGB(140,100,255),Color3.fromRGB(70,150,255),Color3.fromRGB(60,210,160),Color3.fromRGB(255,90,110)}; local idx=1
        row.MouseButton1Click:Connect(function() idx=idx%#colors+1; swatch.BackgroundColor3=colors[idx]; if opts.Callback then opts.Callback(colors[idx]) end end)
        return row
    end
    function group:CreateDivider()
        local line=New("Frame",{Size=UDim2.new(1,-4,0,1),BackgroundColor3=Theme.Stroke,BorderSizePixel=0},page); line.LayoutOrder=Next(page); return line
    end
    function group:CreateKeybind(opts)
        opts=opts or {}; return self:CreateDropdown({Name=opts.Name or "Keybind",Options={"RightControl","LeftControl","Insert","Home"},CurrentOption=opts.CurrentKeybind or "RightControl",Flag=opts.Flag,Callback=function(v) if opts.OnChanged then opts.OnChanged(type(v)=="table" and v[1] or v) end; if opts.Callback then opts.Callback(v) end end})
    end
    function group:CreateConfigManager() return self:CreateStatus({Name="Config",Update=function() return "บันทึกอัตโนมัติ" end}) end
    function group:CreateThemeManager() return self:CreateStatus({Name="ธีม",Update=function() return "ตั้งค่าผ่าน Relwx" end}) end
    return group
end

local RelwxAPI = {}
function RelwxAPI.CreateTab(name, icon)
    local page, id
    if name == "ตั้งค่า" then
        page, id = Settings, "Settings"
    else
        LegacyCounter += 1
        id = "RelwxTab" .. tostring(LegacyCounter)
        page = MakePage(id, name, "RELWX • " .. tostring(game.Name or ""))
        Category(name, id, icon or "grid")
    end
    local tab = { Page = page, Name = name }
    function tab:AddLeftGroupbox(opts) return makeLegacyGroup(page, type(opts)=="table" and opts.Name or opts) end
    function tab:AddRightGroupbox(opts) return makeLegacyGroup(page, type(opts)=="table" and opts.Name or opts) end
    function tab:CreateSubTab(opts)
        local n=type(opts)=="table" and opts.Name or tostring(opts)
        LegacyCounter += 1
        local sid=id .. "Sub" .. tostring(LegacyCounter)
        local subpage=MakePage(sid,n,"RELWX • " .. tostring(name))
        Category(n,sid,type(opts)=="table" and opts.Icon or "grid")
        local sub={Page=subpage,Name=n}
        function sub:AddLeftGroupbox(g) return makeLegacyGroup(subpage,type(g)=="table" and g.Name or g) end
        function sub:AddRightGroupbox(g) return makeLegacyGroup(subpage,type(g)=="table" and g.Name or g) end
        return sub
    end
    function tab:CreateConfigManager(opts) return makeLegacyGroup(page,"Config"):CreateConfigManager(opts) end
    function tab:CreateThemeManager(opts) return makeLegacyGroup(page,"Theme"):CreateThemeManager(opts) end
    return tab
end

function RelwxAPI.Notify(_, opts)
    opts=opts or {}; Toast(tostring(opts.Title or "RELWX") .. ": " .. tostring(opts.Content or opts.Text or ""))
end
function RelwxAPI.Confirm(_, opts)
    opts=opts or {}; Toast(tostring(opts.Title or "ยืนยัน") .. " — ดำเนินการต่อ")
    if opts.Callback then task.spawn(opts.Callback) end
end
function RelwxAPI.Destroy()
    pcall(function() Screen:Destroy() end)
    pcall(function() ToggleGui:Destroy() end)
    pcall(function() StatsGui:Destroy() end)
end
function RelwxAPI.Toggle(_, visible) SetWindow(visible ~= false) end
function RelwxAPI.SetKeybind() end
function RelwxAPI.SetToggleButtonPlatform() end
function RelwxAPI.LoadAutoload() end
RelwxAPI.Flags = {}
RelwxAPI.Config = Config
RelwxAPI.SetConfig = SetConfig
return RelwxAPI

end


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local hasHttpGet = typeof(game.HttpGet) == "function"
local hasLoadstring = typeof(loadstring) == "function"
local hasQueueOnTeleport = typeof(queue_on_teleport) == "function"
local httpRequest = (typeof(request) == "function" and request)
	or (typeof(http_request) == "function" and http_request)
	or (type(http) == "table" and typeof(http.request) == "function" and http.request)
	or nil


local function waitPath(root, ...)
	local node = root
	for _, name in { ... } do
		node = node:WaitForChild(name, 20)
		if not node then
			error("missing " .. name .. "; join a gameplay run first", 0)
		end
	end
	return node
end

local IN_LOBBY = ReplicatedStorage:FindFirstChild("lobby") ~= nil
local IN_RUN = not IN_LOBBY and ReplicatedStorage:FindFirstChild("game") ~= nil
if not (IN_LOBBY or IN_RUN) then
	error("unsupported place", 0)
end

local RunStore, EnemyStore, PlayerNamespace, CharacterPackets, RunPackets, Maps, CharacterController
local Enemies
local LobbyPackets, Account, Levels, MilestoneConfig, QuestConfig, CodesConfig, EconomyConfig, RollConfig, GamemodeEnum, QueueRoomStore
local TraitConfig, EmotesConfig, AccessoryConfig, CraftConfig, SkillTreeConfig, CharacterLevels, SkillTreePackets

local gacha = {}

-- ===================== KAITUN SETTINGS (edit here) =====================
gacha.K = {
	Mode = true,                       -- true: every execution force-enables the flags in On (overrides saved toggles)
	Skip = {},                         -- flags to leave alone, e.g. { AutoSummon = true, AutoTrait = true }
	AutoProgress = true,               -- Story: always queue the first map that still has chapters to clear
	TraitStopRarity = "Mythic",        -- AutoTrait keeps rolling until the trait is this rarity or better
	LeaveMinutes = 20,                 -- stuck-run guard: leave a run that lasts longer than this
	SelfFile = "Relwx_AnimeZero.lua",  -- save THIS script under this name in your executor workspace to survive teleports
	Loader = nil,                      -- or a ready loader string, e.g. 'loadstring(game:HttpGet("https://.../x.lua"))()'
	On = {
		-- in a run
		"AutoFarm", "AutoArise", "AutoSkill", "AutoDodgeIgris", "AutoRetreat", "Failsafe", "SwitchOnCooldown",
		"AutoNextChapter", "AutoRetry", "AutoLeave", "AutoLeaveRun",
		-- in the lobby
		"AutoJoin", "JoinAuto", "AutoDelivery", "AutoMilestones", "AutoDaily", "AutoQuests", "AutoAchievements",
		"AutoRedeemCodes", "AutoSkipTutorial", "AutoSummon", "SummonFavourite", "AutoTrait", "AutoEmote",
		"AutoUnlockSlots", "AutoCraft", "AutoSkillTree", "AutoEvolve", "AutoBestAccessory", "AutoBestTitle",
		"AutoRarestCharacters",
		-- safety / upkeep
		"AntiAfk", "AntiGameplayPause", "AutoReconnect", "FpsBoost", "DisableCombatCursor",
	},
}
-- Deliberately NOT enabled: SummonBuyLucky (spends gems), AutoLeaveRuns (conflicts with AutoNextChapter),
-- SkillCombo / UltBossOnly (play-style choices), Fly / NoClip / WalkSpeed / InfJump, ESP, webhooks (need your URL).

if IN_RUN then
	RunStore = require(waitPath(ReplicatedStorage, "game", "stores", "runStore"))
	EnemyStore = require(waitPath(ReplicatedStorage, "game", "stores", "enemyStore"))
	PlayerNamespace = require(waitPath(ReplicatedStorage, "game", "stores", "playerNamespace"))
	CharacterPackets = require(waitPath(ReplicatedStorage, "game", "packets", "characterPackets"))
	RunPackets = require(waitPath(ReplicatedStorage, "game", "packets", "runPackets"))
	Maps = require(waitPath(ReplicatedStorage, "global", "constants", "maps"))
	CharacterController = require(waitPath(LocalPlayer, "PlayerScripts", "game", "controllers", "characterController"))
	Enemies = require(waitPath(ReplicatedStorage, "global", "constants", "enemies"))
else
	LobbyPackets = require(waitPath(ReplicatedStorage, "lobby", "packets"))
	Account = require(waitPath(ReplicatedStorage, "global", "stores", "accountNamespace"))
	Levels = require(waitPath(ReplicatedStorage, "global", "utils", "levelProgression"))
	MilestoneConfig = require(waitPath(ReplicatedStorage, "assets", "config", "levelMilestoneConfig"))
	QuestConfig = require(waitPath(ReplicatedStorage, "assets", "config", "questConfig"))
	CodesConfig = require(waitPath(ReplicatedStorage, "assets", "config", "codesConfig"))
	EconomyConfig = require(waitPath(ReplicatedStorage, "assets", "config", "economyConfig"))
	RollConfig = require(waitPath(ReplicatedStorage, "assets", "config", "characterRollConfig"))
	GamemodeEnum = require(waitPath(ReplicatedStorage, "lobby", "enums", "gamemodeSelectEnum"))
	QueueRoomStore = require(waitPath(ReplicatedStorage, "lobby", "stores", "ququeRoomStore"))
	TraitConfig = require(waitPath(ReplicatedStorage, "assets", "config", "Traits", "traitConfig"))
	EmotesConfig = require(waitPath(ReplicatedStorage, "assets", "config", "emotesConfig"))
	AccessoryConfig = require(waitPath(ReplicatedStorage, "assets", "config", "accessoryConfig"))
	gacha.TitleConfig = require(waitPath(ReplicatedStorage, "assets", "config", "titleConfig"))
	gacha.EvolutionConfig = require(waitPath(ReplicatedStorage, "assets", "config", "evolutionConfig"))
	CraftConfig = require(waitPath(ReplicatedStorage, "assets", "config", "accessoryCraftConfig"))
	SkillTreeConfig = require(waitPath(ReplicatedStorage, "assets", "config", "characterSkillTreeConfig"))
	CharacterLevels = require(waitPath(ReplicatedStorage, "global", "utils", "characterLevelProgression"))
	SkillTreePackets = require(waitPath(ReplicatedStorage, "lobby", "modules", "skillTree", "skillTreePackets"))
end

local function createFeatureAPI(namespace)
	assert(type(namespace) == "string" and namespace ~= "", "namespace required")
	assert(type(getgenv) == "function", "getgenv unavailable")
	local env = getgenv()
	assert(type(env) == "table", "getgenv did not return a table")
	local previous = env[namespace]
	if previous ~= nil then
		assert(type(previous) == "table" and type(previous.Unload) == "function", "namespace occupied")
		local ok, err = pcall(previous.Unload)
		if not ok then
			warn("Previous cleanup: " .. tostring(err))
		end
	end

	local API = {
		State = {},
		Unloaded = false,
	}
	local cleanup = {}

	function API.Track(dispose)
		assert(type(dispose) == "function", "cleanup must be callable")
		if API.Unloaded then
			local ok, err = pcall(dispose)
			if not ok then
				warn("Cleanup: " .. tostring(err))
			end
		else
			table.insert(cleanup, dispose)
		end
		return dispose
	end

	function API.Unload()
		if API.Unloaded then
			return
		end
		API.Unloaded = true
		for index = #cleanup, 1, -1 do
			local dispose = table.remove(cleanup, index)
			local ok, err = pcall(dispose)
			if not ok then
				warn("Cleanup: " .. tostring(err))
			end
		end
		table.clear(API.State)
		if env[namespace] == API then
			env[namespace] = nil
		end
	end

	env[namespace] = API
	return API
end

local function attachUI(API, Window)
	assert(type(API) == "table" and type(API.Track) == "function", "FeatureAPI required")
	assert(type(Window) == "table" and type(Window.Destroy) == "function", "UI window required")
	API.Track(function()
		pcall(function()
			Window:Destroy()
		end)
	end)
	local gui = Window.Gui
	if typeof(gui) == "Instance" then
		local destroying = gui.Destroying:Connect(function()
			task.defer(API.Unload)
		end)
		API.Track(function()
			destroying:Disconnect()
		end)
	end
end


local API = createFeatureAPI("Relwx_AnimeZero")

local MaterialConfig
do
	local node = ReplicatedStorage:FindFirstChild("assets")
	node = node and node:FindFirstChild("config")
	node = node and node:FindFirstChild("materialConfig")
	if node then
		local ok, config = pcall(require, node)
		if ok and type(config) == "table" then
			MaterialConfig = config
		end
	end
end

local CharacterNames
do
	local node = ReplicatedStorage:FindFirstChild("global")
	node = node and node:FindFirstChild("constants")
	node = node and node:FindFirstChild("characters")
	if node then
		local ok, config = pcall(require, node)
		if ok and type(config) == "table" and type(config.charactersByName) == "table" then
			CharacterNames = config.charactersByName
		end
	end
end

local DIFFICULTY_NAMES = { "Easy", "Medium", "Hard", "Nightmare" }
local FARM_MODES = { "Front", "Orbit", "Behind", "Above", "Below" }
local TARGET_MODES = { "Nearest", "Ranged First", "Lowest HP", "Bosses First", "Biggest Pack" }
local RETREAT_ACTIONS = { "Fly Up", "Leave Run" }
local SKILL_LABELS = { "Skill 1", "Skill 2", "Skill 3", "Ultimate" }
local SKILL_SLOT = { ["Skill 1"] = 1, ["Skill 2"] = 2, ["Skill 3"] = 3, ["Ultimate"] = 4 }
local LEAVE_ACTION = 3
local POSE_RETARGET_DISTANCE = 1.5

local Flags = {
	AutoFarm = false,
	AutoArise = false,
	FarmMode = "Front",
	Failsafe = false,
	FailsafeMode = "Move Across Area",
	FailsafeSeconds = 15,
	FailsafeScanLeave = false,
	MoveSpeed = 150,
	AttackDistance = 5,
	HeightOffset = 8,
	OrbitSpeed = 180,
	AutoSkill = false,
	SkillSlots = { 1, 2, 3 },
	SkillCombo = false,
	UltBossOnly = false,
	UltBossPriority = false,
	AutoDodgeIgris = false,
	ComboOrder = { 1, 2, 3 },
	ComboDelay = 0,
	SkillRange = 25,
	SkillMinEnemies = 1,
	TargetMode = "Nearest",
	AutoRetreat = false,
	RetreatHealth = 30,
	RetreatResume = 70,
	RetreatAction = "Fly Up",
	RetreatHeight = 60,
	RetreatMaxSeconds = 15,
	SwitchOnCooldown = false,
	SwitchUltMode = "Don't Consider Ultimates",
	WebhookUrl = "",
	WebhookResults = true,
	WebhookRolls = true,
	WebhookKicked = true,
	WebhookHuTao = true,
	PingEnabled = false,
	PingUserId = "",
	PingMaterials = {},
	PingMinTier = "Off",
	AutoJoin = false,
	JoinAuto = false,
	JoinChoice = "",
	JoinChapter = 0,
	JoinDifficulty = "Easy",
	JoinPlayers = 1,
	JoinFriendsOnly = false,
	JoinDelay = 5,
	AutoDelivery = false,
	AutoMilestones = false,
	AutoDaily = false,
	AutoQuests = false,
	AutoSummon = false,
	SummonType = "Normal",
	SummonPayment = "money",
	SummonSlot = 1,
	SummonDelay = 2,
	ProtectRarity = "Mythic",
	SummonStopCharacters = {},
	SummonFavourite = false,
	SummonBuyLucky = false,
	AutoTrait = false,
	TraitCharacter = "Equipped Character",
	TraitTargets = {},
	TraitStopRarity = "None",
	AutoEmote = false,
	EmoteTargets = {},
	EmoteStopRarity = "None",
	EmoteStopAllOwned = true,
	AutoUnlockSlots = false,
	TraitDelay = 1,
	AutoCraft = false,
	CraftItems = {},
	CraftTarget = 1,
	AutoSkillTree = false,
	AutoEvolve = false,
	AutoBestAccessory = false,
	AutoBestTitle = false,
	BestGearStat = "Damage",
	AutoRarestCharacters = false,
	AutoAchievements = false,
	AutoRedeemCodes = false,
	AutoSkipTutorial = false,
	SkillTreeCharacters = {},
	SkillTreeBranches = {},
	SkillTreeMaxTier = 5,
	AutoNextChapter = false,
	AutoRetry = false,
	AutoLeave = false,
	ResultDelay = 2,
	AutoLeaveRun = false,
	LeaveMinutes = 10,
	AutoLeaveRuns = false,
	LeaveRuns = 5,
	WalkSpeedEnabled = false,
	WalkSpeed = 32,
	InfJump = false,
	NoClip = false,
	InstantProximityPrompt = false,
	Fly = false,
	FlySpeed = 60,
	AntiGameplayPause = true,
	AutoReconnect = false,
	Disable3DRendering = false,
	DisableCombatCursor = true,
	FpsBoost = false,
	UltraFpsBoost = false,
	DisableSkillVfx = false,
	DisablePlayerAnimations = false,
	AntiAfk = true,
}

local STATS_FOLDER = "Relwx/" .. GAME_KEY
local STATS_FILE = STATS_FOLDER .. "/stats.json"
local hasFiles = typeof(readfile) == "function" and typeof(writefile) == "function" and typeof(isfile) == "function"

local Stats = {
	wins = 0,
	losses = 0,
	rollHits = 0,
	kicked = 0,
	kills = 0,
	money = 0,
	gems = 0,
	xp = 0,
	materials = {},
}

local function loadStats()
	if not hasFiles then
		return
	end
	local ok, decoded = pcall(function()
		if isfile(STATS_FILE) then
			return HttpService:JSONDecode(readfile(STATS_FILE))
		end
		return nil
	end)
	if ok and type(decoded) == "table" then
		for key, value in pairs(decoded) do
			if key == "materials" then
				if type(value) == "table" then
					Stats.materials = value
				end
			elseif type(Stats[key]) == "number" and type(value) == "number" then
				Stats[key] = value
			end
		end
	end
end

local function saveStats()
	if not hasFiles then
		return
	end
	pcall(function()
		if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
			if not isfolder("Relwx") then
				makefolder("Relwx")
			end
			if not isfolder(STATS_FOLDER) then
				makefolder(STATS_FOLDER)
			end
		end
		writefile(STATS_FILE, HttpService:JSONEncode(Stats))
	end)
end

local function resetStats()
	for key, value in pairs(Stats) do
		if type(value) == "number" then
			Stats[key] = 0
		end
	end
	Stats.materials = {}
	saveStats()
end

loadStats()

local function materialInfo(id)
	local entry = MaterialConfig and (MaterialConfig[tonumber(id)] or MaterialConfig[tostring(id)])
	if type(entry) == "table" then
		return tostring(entry.Name or id), tonumber(entry.Tier) or 0, entry.Icon
	end
	return "Material " .. tostring(id), 0
end

local function ownedMaterials()
	local ok, all = pcall(function()
		local node = ReplicatedStorage:FindFirstChild("global")
		node = node and node:FindFirstChild("stores")
		node = node and node:FindFirstChild("accountNamespace")
		local account = node and require(node).getLocalPlayerAccount()
		local material = account and (account.state or account).material
		return material and material:getAll()
	end)
	return if ok and type(all) == "table" then all else nil
end

local MATERIAL_LABELS = {}
local MATERIAL_BY_LABEL = {}
local MATERIAL_TIER_OPTIONS = { "Off" }
do
	local maxTier = 0
	local ids = {}
	for id, entry in pairs(MaterialConfig or {}) do
		if type(entry) == "table" and entry.Name then
			table.insert(ids, tostring(id))
		end
	end
	table.sort(ids, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	for _, id in ipairs(ids) do
		local name, tier = materialInfo(id)
		local label = string.format("%s (T%d)", name, tier)
		table.insert(MATERIAL_LABELS, label)
		MATERIAL_BY_LABEL[label] = id
		maxTier = math.max(maxTier, tier)
	end
	for tier = 1, maxTier do
		table.insert(MATERIAL_TIER_OPTIONS, tostring(tier))
	end
end

local function webhookUrl()
	local url = string.gsub(tostring(Flags.WebhookUrl or ""), "%s+", "")
	for _, host in ipairs({ "discord%.com", "discordapp%.com", "ptb%.discord%.com", "canary%.discord%.com" }) do
		if string.find(url, "^https://" .. host .. "/api/webhooks/") then
			return url
		end
	end
	return nil
end

local thumbCache = {}

local function thumbnail(kind, id)
	id = tostring(id or ""):match("%d+")
	if not id or not httpRequest then
		return nil
	end
	local key = kind .. id
	if thumbCache[key] then
		return thumbCache[key]
	end
	local path
	if kind == "user" then
		path = "users/avatar-headshot?userIds=" .. id .. "&size=150x150&format=Png"
	elseif kind == "place" then
		path = "places/gameicons?placeIds=" .. id .. "&size=150x150&format=Png"
	else
		path = "assets?assetIds=" .. id .. "&size=420x420&format=Png"
	end
	local ok, response = pcall(httpRequest, { Url = "https://thumbnails.roblox.com/v1/" .. path, Method = "GET" })
	if not ok or type(response) ~= "table" then
		return nil
	end
	local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, tostring(response.Body))
	local entry = okDecode and type(decoded) == "table" and type(decoded.data) == "table" and decoded.data[1]
	local image = type(entry) == "table" and entry.state == "Completed" and entry.imageUrl or nil
	if image then
		thumbCache[key] = image
	end
	return image
end

local function characterArt(id)
	local info = CharacterNames and CharacterNames[tostring(id)]
	local skills = info and info.skills
	local last = type(skills) == "table" and skills[#skills]
	return type(last) == "table" and last.icon or nil
end

local function characterName(id)
	local info = CharacterNames and CharacterNames[tostring(id)]
	return info and info.displayName or tostring(id)
end

local function postWebhook(content, embed)
	local url = webhookUrl()
	if not url or not httpRequest then
		return false
	end
	local thumbAsset = embed.thumbAsset
	local extra = embed.extraEmbeds or {}
	embed.thumbAsset = nil
	embed.extraEmbeds = nil
	for _, item in ipairs(extra) do
		local icon = item.iconAsset
		item.iconAsset = nil
		if icon and item.author then
			item.author.icon_url = thumbnail("asset", icon)
		end
	end
	embed.author = {
		name = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")",
		icon_url = thumbnail("user", LocalPlayer.UserId),
	}
	if thumbAsset then
		local image = thumbnail("asset", thumbAsset)
		if image then
			embed.thumbnail = { url = image }
		end
	end
	embed.footer = { text = GAME_NAME, icon_url = thumbnail("place", game.PlaceId) }
	embed.timestamp = DateTime.now():ToIsoDate()
	local ok, response = pcall(httpRequest, {
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({ username = "Relwx", content = content, embeds = { embed, table.unpack(extra) } }),
	})
	return ok and type(response) == "table" and (tonumber(response.StatusCode) or 0) < 300
end

local function sendWebhook(content, embed)
	task.spawn(postWebhook, content, embed)
end

local function formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function formatTime(seconds)
	seconds = math.max(math.floor(tonumber(seconds) or 0), 0)
	if seconds >= 60 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return seconds .. "s"
end

local function field(name, value, inline)
	return { name = name, value = value, inline = inline ~= false }
end

local function statLine(icon, label, value)
	return string.format("%s %s  **%s**", icon, label, value)
end

local function totalsFields()
	local runs = Stats.wins + Stats.losses
	local rate = if runs > 0 then string.format("%d%%", math.floor(Stats.wins / runs * 100 + 0.5)) else "-"
	return {
		field("\u{200B}", "**━━━━━━━━  Session  ━━━━━━━━**", false),
		field("Record", table.concat({
			statLine("🏆", "Wins", formatNumber(Stats.wins)),
			statLine("💀", "Losses", formatNumber(Stats.losses)),
			statLine("📈", "Win Rate", rate),
		}, "\n")),
		field("Earned", table.concat({
			statLine("💰", "Money", formatNumber(Stats.money)),
			statLine("💎", "Gems", formatNumber(Stats.gems)),
			statLine("✨", "XP", formatNumber(Stats.xp)),
		}, "\n")),
		field("Activity", table.concat({
			statLine("⚔️", "Kills", formatNumber(Stats.kills)),
			statLine("🎲", "Pulls", formatNumber(Stats.rollHits)),
			statLine("🚪", "Kicks", formatNumber(Stats.kicked)),
		}, "\n")),
	}
end

local function withTotals(fields)
	for _, entry in ipairs(totalsFields()) do
		table.insert(fields, entry)
	end
	return fields
end

local TIER_COLORS = { 12370112, 5763719, 3447003, 10181046, 16705372, 15548997 }

local function rarityColor(rarity)
	local entry = RollConfig and RollConfig.rarities and RollConfig.rarities[rarity]
	local color = entry and entry.color
	if typeof(color) == "ColorSequence" then
		color = color.Keypoints[1].Value
	end
	if typeof(color) == "Color3" then
		return tonumber(color:ToHex(), 16)
	end
	return 16766720
end

local function pingContent(lines)
	if not Flags.PingEnabled or #lines == 0 then
		return nil
	end
	local userId = string.gsub(tostring(Flags.PingUserId or ""), "%D", "")
	if userId == "" then
		return nil
	end
	return "<@" .. userId .. "> " .. table.concat(lines, ", ")
end

local function recordRun(participant)
	local status = participant.status:get()
	if status ~= "victory" and status ~= "failed" then
		return
	end
	local materials = {}
	for id, count in tostring(participant.materials:get()):gmatch("(%d+):(%d+)") do
		materials[id] = (materials[id] or 0) + (tonumber(count) or 0)
	end
	local money = participant.earned:get() + participant.bonus:get()
	local gems = participant.gems:get()
	local xp = participant.xp:get()
	local kills = participant.kills:get()
	if status == "victory" then
		Stats.wins += 1
	else
		Stats.losses += 1
	end
	Stats.kills += kills
	Stats.money += money
	Stats.gems += gems
	Stats.xp += xp
	local drops, pingLines = {}, {}
	local minTier = tonumber(Flags.PingMinTier)
	for id, count in pairs(materials) do
		Stats.materials[id] = (Stats.materials[id] or 0) + count
		local name, tier, icon = materialInfo(id)
		table.insert(drops, { id = id, name = name, tier = tier, count = count, icon = icon })
		if table.find(Flags.PingMaterials, id) or (minTier and tier >= minTier) then
			table.insert(pingLines, string.format("%s x%d", name, count))
		end
	end
	table.sort(drops, function(a, b)
		if a.tier ~= b.tier then
			return a.tier > b.tier
		end
		return a.name < b.name
	end)
	saveStats()
	local unit = participant.unit and participant.unit:get()
	if Flags.WebhookHuTao and unit == "hutao" then
		local userId = string.gsub(tostring(Flags.PingUserId or ""), "%D", "")
		sendWebhook(if Flags.PingEnabled and userId ~= "" then "<@" .. userId .. "> Hu Tao dropped" else nil, {
			title = "🔥 Hu Tao Drop",
			description = string.format("> **%s** dropped from the raid", characterName(unit)),
			color = rarityColor("Zenless"),
			thumbAsset = characterArt(unit),
			fields = withTotals({}),
		})
	end
	if not Flags.WebhookResults then
		return
	end
	local state = RunStore.store.state
	local win = status == "victory"
	local mapName = tostring(Maps and Maps.currentMap or "?")
	mapName = mapName:sub(1, 1):upper() .. mapName:sub(2)
	local difficulty = DIFFICULTY_NAMES[tonumber(state.difficulty:get())] or tostring(state.difficulty:get())
	local store = PlayerNamespace.getLocalPlayerStore()
	local character = store and store.state.character:get()
	local owned = ownedMaterials()
	local dropEmbeds = {}
	for index, drop in ipairs(drops) do
		if index > 8 then
			table.insert(dropEmbeds, { color = 9807270, description = string.format("-# +%d more", #drops - 8) })
			break
		end
		local value = owned and owned[tostring(drop.id)]
		if type(value) == "table" and type(value.get) == "function" then
			value = value:get()
		end
		local total = tonumber(value)
		table.insert(dropEmbeds, {
			color = TIER_COLORS[math.clamp(drop.tier, 1, #TIER_COLORS)],
			author = { name = string.format("%s ×%d", drop.name, drop.count) .. (if total then string.format(" (%s)", formatNumber(total)) else "") },
			iconAsset = drop.icon,
		})
	end
	local fields = {
		field("Run", table.concat({
			statLine("⏱️", "Time", formatTime(participant.elapsed:get())),
			statLine("⚔️", "Kills", formatNumber(kills)),
			statLine("💥", "Damage", formatNumber(participant.damage:get())),
		}, "\n")),
		field("Rewards", table.concat({
			statLine("💰", "Money", "+" .. formatNumber(money)),
			statLine("💎", "Gems", "+" .. formatNumber(gems)),
			statLine("✨", "XP", "+" .. formatNumber(xp)),
		}, "\n")),
		field("Drops", if #dropEmbeds > 0 then "-# listed below" else "-# none"),
	}
	withTotals(fields)
	sendWebhook(pingContent(pingLines), {
		title = (win and "🏆 Victory" or "💀 Defeat") .. "  ·  " .. mapName,
		description = string.format(
			"> 📖 Chapter **%s**  ·  🎚️ **%s**\n> 🧍 Playing as **%s**",
			tostring(state.chapter:get()),
			difficulty,
			character and characterName(character) or "?"
		),
		color = win and 5763719 or 15548997,
		thumbAsset = character and characterArt(character),
		fields = fields,
		extraEmbeds = dropEmbeds,
	})
end

local function recordRollHit(character, rarity)
	Stats.rollHits += 1
	saveStats()
	if Flags.WebhookRolls then
		sendWebhook(nil, {
			title = "🎲 " .. tostring(rarity) .. " Pull",
			description = string.format("> **%s**\n> Slot **%d**", characterName(character), Flags.SummonSlot),
			color = rarityColor(rarity),
			thumbAsset = characterArt(character),
			fields = withTotals({}),
		})
	end
end

do
	local lastKickAt = 0
	local connection = GuiService.ErrorMessageChanged:Connect(function()
		local ok, message = pcall(GuiService.GetErrorMessage, GuiService)
		if not ok or type(message) ~= "string" or message == "" or os.clock() - lastKickAt < 5 then
			return
		end
		lastKickAt = os.clock()
		Stats.kicked += 1
		saveStats()
		if Flags.WebhookKicked then
			task.spawn(postWebhook, nil, {
				title = "🚪 Disconnected",
				description = "```\n" .. message .. "\n```",
				color = 15548997,
				fields = withTotals({}),
			})
		end
	end)
	API.Track(function()
		connection:Disconnect()
	end)
end

local function statsRows()
	return {
		{ Text = "Wins", Value = formatNumber(Stats.wins), Tone = "Success" },
		{ Text = "Losses", Value = formatNumber(Stats.losses), Tone = "Error" },
		{ Text = "Roll Hits", Value = formatNumber(Stats.rollHits), Tone = "Accent" },
		{ Text = "Kicked", Value = formatNumber(Stats.kicked), Tone = Stats.kicked > 0 and "Warning" or "Muted" },
		{ Text = "Kills", Value = formatNumber(Stats.kills), Tone = "Muted" },
		{ Text = "Money", Value = formatNumber(Stats.money), Tone = "Muted" },
		{ Text = "Gems", Value = formatNumber(Stats.gems), Tone = "Muted" },
		{ Text = "XP", Value = formatNumber(Stats.xp), Tone = "Muted" },
	}
end

local runtime = {
	exitAt = 0,
	ariseTried = setmetatable({}, { __mode = "k" }),
	target = nil,
	targetGap = math.huge,
	resultKey = nil,
	resultSeenAt = 0,
	resultActedKey = nil,
	resultActedAt = 0,
	leftRunAt = nil,
	tween = nil,
	poseTarget = nil,
	wallArea = nil,
	wallTries = 0,
	wallAt = 0,
	skip = {},
	watchId = nil,
	watchHealth = nil,
	watchAt = 0,
	anchorId = nil,
	anchorDir = Vector3.zAxis,
	orbitAngle = 0,
	lastTick = os.clock(),
	retreating = false,
	retreatAt = 0,
	retreatBlockUntil = 0,
	retreatSpot = nil,
	retreatLeftAt = nil,
	retreatCheckAt = 0,
	runsDone = 0,
	dodging = false,
	dodgeSpot = nil,
	recordedKey = nil,
	switchAt = 0,
	skillReadyAt = 0,
	rubble = nil,
	searchArea = nil,
	searchPoints = nil,
	searchPoint = nil,
	idleSince = nil,
	failsafeLeftAt = nil,
	searchSwept = false,
	comboIndex = 1,
	comboSince = nil,
	comboCastAt = 0,
}

local function characterParts()
	local character = LocalPlayer.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and humanoid.Health > 0) then
		return nil, nil, nil
	end
	return character, root, humanoid
end

local function runState()
	return RunStore.store.state
end

local function myParticipant()
	return runState().participants:get(tostring(LocalPlayer.UserId))
end

local function inActiveRun()
	local participant = myParticipant()
	return participant ~= nil and participant.status:get() == "active"
end

local function nearestEnemy(origin)
	local clock = os.clock()
	local pool = {}
	local current
	for id, enemy in pairs(EnemyStore.store.state:getAll()) do
		local skipUntil = runtime.skip[id]
		if skipUntil and clock >= skipUntil then
			runtime.skip[id] = nil
			skipUntil = nil
		end
		local health = enemy.health:get()
		if health > 0 and not skipUntil then
			local position = enemy.position:get()
			local info = Enemies.enemiesByName[enemy.name:get()]
			local entry = {
				id = id,
				position = position,
				distance = (position - origin).Magnitude,
				health = health,
				boss = info ~= nil and info.boss == true,
				ranged = info ~= nil and (tonumber(info.attackRange) or 0) > 10,
				pack = 0,
				guarded = enemy.guardedAt and enemy.guardedAt:get() ~= nil,
			}
			table.insert(pool, entry)
			if id == runtime.target then
				current = entry
			end
		end
	end
	if #pool == 0 then
		return nil, nil
	end
	local open = {}
	for _, entry in ipairs(pool) do
		if not entry.guarded then
			table.insert(open, entry)
		end
	end
	if #open > 0 then
		pool = open
		if current and current.guarded then
			current = nil
		end
	end
	local mode = Flags.TargetMode
	local better = function(a, b)
		return a.distance < b.distance
	end
	local class
	if mode == "Ranged First" then
		class = "ranged"
	elseif mode == "Bosses First" then
		class = "boss"
	elseif mode == "Lowest HP" then
		better = function(a, b)
			if a.health ~= b.health then
				return a.health < b.health
			end
			return a.distance < b.distance
		end
	elseif mode == "Biggest Pack" then
		for _, a in ipairs(pool) do
			for _, b in ipairs(pool) do
				if (a.position - b.position).Magnitude <= 18 then
					a.pack += 1
				end
			end
		end
		better = function(a, b)
			if a.pack ~= b.pack then
				return a.pack > b.pack
			end
			return a.distance < b.distance
		end
	end
	local hasClass = false
	if class then
		for _, entry in ipairs(pool) do
			if entry[class] then
				hasClass = true
				break
			end
		end
	end
	if current and mode ~= "Nearest" and (not class or current[class] or not hasClass) then
		return current.id, current.position
	end
	local best
	for _, entry in ipairs(pool) do
		if (not hasClass or entry[class]) and (not best or better(entry, best)) then
			best = entry
		end
	end
	return best.id, best.position
end

local function enemiesWithin(origin, range)
	local count = 0
	for _, enemy in pairs(EnemyStore.store.state:getAll()) do
		if enemy.health:get() > 0 and (enemy.position:get() - origin).Magnitude <= range then
			count += 1
		end
	end
	return count
end

local function targetsWithin(origin, range)
	local count = enemiesWithin(origin, range)
	local rubble = runtime.rubble
	if rubble and rubble.Parent and rubble.CanCollide and (rubble.Position - origin).Magnitude <= range + rubble.Size.Magnitude / 2 then
		count += 1
	end
	return count
end

local function releasePose()
	local tween = runtime.tween
	runtime.tween = nil
	runtime.poseTarget = nil
	if tween then
		tween:Cancel()
	end
end

local function tweenTo(root, target, wait)
	local previous = runtime.tween
	if previous then
		previous:Cancel()
	end
	local distance = (root.Position - target.Position).Magnitude
	local duration = math.max(distance / Flags.MoveSpeed, 0.05)
	local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = target })
	runtime.tween = tween
	tween:Play()
	if wait then
		local deadline = os.clock() + duration + 0.5
		while runtime.tween == tween and not API.Unloaded and os.clock() < deadline do
			task.wait()
		end
		if runtime.tween == tween then
			runtime.tween = nil
		end
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function holdPose(root, desired, focus, up)
	local last = runtime.poseTarget
	local moved = not last or (last.Position - desired).Magnitude > POSE_RETARGET_DISTANCE
	if moved then
		local target = CFrame.lookAt(desired, focus, up)
		runtime.poseTarget = target
		tweenTo(root, target, false)
		return
	end
	local tween = runtime.tween
	if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
		return
	end
	local target = CFrame.lookAt(last.Position, focus, up)
	runtime.poseTarget = target
	root.CFrame = target
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function runtime.groundAt(position, character, distance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { character }
	local enemies = Workspace:FindFirstChild("enemies")
	if enemies then
		table.insert(exclude, enemies)
	end
	local World = Workspace:FindFirstChild("World")
	local areas = World and World:FindFirstChild("Areas")
	if areas then
		table.insert(exclude, areas)
	end
	for _, name in ipairs({ "effects", "_effects", "visualizeParts" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	local origin = position + Vector3.new(0, 4, 0)
	local direction = Vector3.new(0, -(distance or 400), 0)
	for _ = 1, 8 do
		params.FilterDescendantsInstances = exclude
		local result = Workspace:Raycast(origin, direction, params)
		if not result or result.Instance.CanCollide then
			return result and result.Position or nil
		end
		table.insert(exclude, result.Instance)
	end
	return nil
end

function runtime.farmPose(position, dt, padding)
	local mode = Flags.FarmMode
	local distance = Flags.AttackDistance + (padding or 0)
	local dir = runtime.anchorDir
	local desired
	if mode == "Behind" then
		desired = position - dir * distance
	elseif mode == "Orbit" then
		runtime.orbitAngle += math.rad(Flags.OrbitSpeed) * dt
		desired = position + Vector3.new(math.cos(runtime.orbitAngle), 0, math.sin(runtime.orbitAngle)) * distance
	elseif mode == "Above" then
		desired = position + Vector3.new(0, Flags.HeightOffset + (padding or 0), 0)
	elseif mode == "Below" then
		desired = position - Vector3.new(0, Flags.HeightOffset + (padding or 0), 0)
	else
		desired = position + dir * distance
	end
	local up = if mode == "Above" or mode == "Below" then dir else Vector3.yAxis
	local focus = if up == Vector3.yAxis then Vector3.new(position.X, desired.Y, position.Z) else position
	return desired, focus, up
end

function runtime.areaZone(area)
	local World = Workspace:FindFirstChild("World")
	local areas = World and World:FindFirstChild("Areas")
	if not areas then
		return nil
	end
	local mapConfig = Maps and Maps.mapsByName[Maps.currentMap]
	local areaConfig = mapConfig and mapConfig.areas[area]
	local zone = areaConfig and areaConfig.zone and areas:FindFirstChild(tostring(areaConfig.zone))
	return zone or areas:FindFirstChild(tostring(area))
end

function runtime.searchPointsFor(area, character)
	local World = Workspace:FindFirstChild("World")
	local zone = runtime.areaZone(area)
	if not (zone and zone:IsA("BasePart")) then
		return nil
	end
	local size = zone.Size
	local nx = math.max(math.ceil(size.X / 60), 1)
	local nz = math.max(math.ceil(size.Z / 60), 1)
	local points = {}
	for ix = 1, nx do
		for iz = 1, nz do
			local column = if ix % 2 == 0 then nz - iz + 1 else iz
			local offset = Vector3.new((ix - 0.5) / nx - 0.5, 0, (column - 0.5) / nz - 0.5) * size
			local ground = runtime.groundAt(zone.CFrame:PointToWorldSpace(offset), character)
			if ground then
				table.insert(points, ground + Vector3.new(0, 3.5, 0))
			end
		end
	end
	return if #points > 0 then points else nil
end

local function areaEntryPosition(area, character)
	local World = Workspace:FindFirstChild("World")
	local zone = runtime.areaZone(area)
	if zone and zone:IsA("BasePart") then
		local ground = runtime.groundAt(zone.Position - Vector3.new(0, 4, 0), character, zone.Size.Y * 3)
		local groundY = if ground then ground.Y else zone.Position.Y - zone.Size.Y / 2
		return Vector3.new(zone.Position.X, groundY, zone.Position.Z)
	end
	local spawns = World and World:FindFirstChild("Spawns")
	local spawn = spawns and spawns:FindFirstChild(tostring(area))
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position
	end
	return nil
end

function runtime.holdSafe(root, character, area)
	local World = Workspace:FindFirstChild("World")
	local zone = runtime.areaZone(area)
	local inside = true
	if zone and zone:IsA("BasePart") then
		local localPos = zone.CFrame:PointToObjectSpace(root.Position)
		inside = math.abs(localPos.X) <= zone.Size.X / 2 and math.abs(localPos.Z) <= zone.Size.Z / 2 and math.abs(localPos.Y) <= zone.Size.Y / 2
	end
	local ground = inside and runtime.groundAt(root.Position, character)
	local spot = if ground then ground + Vector3.new(0, 3.5, 0) else nil
	if not spot then
		local center = areaEntryPosition(area, character)
		spot = center and center + Vector3.new(0, 3.5, 0)
	end
	if not spot then
		releasePose()
		return
	end
	local last = runtime.poseTarget
	if last and (last.Position - spot).Magnitude <= POSE_RETARGET_DISTANCE * 2 then
		spot = last.Position
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	holdPose(root, spot, spot + (if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis), Vector3.yAxis)
end

function runtime.failsafe(root, character, area, clock)
	if not Flags.Failsafe then
		runtime.idleSince = nil
		return false
	end
	if not runtime.idleSince then
		runtime.idleSince = clock
	end
	if clock - runtime.idleSince < Flags.FailsafeSeconds then
		return false
	end
	local function leave()
		local startedAt = runState().startedAt:get()
		if startedAt and runtime.failsafeLeftAt ~= startedAt then
			runtime.failsafeLeftAt = startedAt
			RunPackets.endAction:fire(LEAVE_ACTION)
		end
		return false
	end
	if Flags.FailsafeMode == "Leave Run" then
		return leave()
	end
	if runtime.searchArea ~= area or not runtime.searchPoints then
		runtime.searchArea = area
		runtime.searchPoints = {}
		runtime.searchPoint = nil
		runtime.searchSwept = false
	end
	local point = runtime.searchPoint
	if point then
		local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		if flat.Magnitude <= 8 and math.abs(point.Y - root.Position.Y) <= 8 then
			point = nil
		end
	end
	if not point then
		if #runtime.searchPoints == 0 then
			if runtime.searchSwept and Flags.FailsafeScanLeave then
				return leave()
			end
			runtime.searchSwept = true
			runtime.searchPoints = runtime.searchPointsFor(area, character) or {}
			if #runtime.searchPoints == 0 then
				return false
			end
		end
		local points = runtime.searchPoints
		local bestIndex, bestDistance
		for index, candidate in ipairs(points) do
			local distance = (candidate - root.Position).Magnitude
			if not bestDistance or distance < bestDistance then
				bestIndex, bestDistance = index, distance
			end
		end
		point = table.remove(points, bestIndex)
		runtime.searchPoint = point
	end
	local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	holdPose(root, point, point + (if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis), Vector3.yAxis)
	return true
end

function runtime.retreatSpotFrom(origin)
	local push = Vector3.zero
	for _, enemy in pairs(EnemyStore.store.state:getAll()) do
		if enemy.health:get() > 0 then
			local offset = origin - enemy.position:get()
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < 80 then
				push += (if flat.Magnitude > 0.05 then flat.Unit else Vector3.xAxis) * (80 - flat.Magnitude)
			end
		end
	end
	local away = if push.Magnitude > 0.05 then push.Unit * 40 else Vector3.zero
	return origin + away + Vector3.new(0, Flags.RetreatHeight, 0)
end

function runtime.retreatThreatened(spot)
	for _, enemy in pairs(EnemyStore.store.state:getAll()) do
		if enemy.health:get() > 0 then
			local offset = enemy.position:get() - spot
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < 25 then
				return true
			end
		end
	end
	return false
end

local function updateRetreat(root, humanoid)
	if not Flags.AutoRetreat or humanoid.Health <= 0 then
		if runtime.retreating then
			runtime.retreating = false
			runtime.retreatSpot = nil
			releasePose()
		end
		return false
	end
	local clock = os.clock()
	local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1) * 100
	if runtime.retreating then
		local timedOut = clock - runtime.retreatAt >= Flags.RetreatMaxSeconds
		if ratio >= math.max(Flags.RetreatResume, Flags.RetreatHealth + 5) or timedOut then
			runtime.retreating = false
			runtime.retreatSpot = nil
			if timedOut then
				runtime.retreatBlockUntil = clock + 20
			end
			releasePose()
			return false
		end
	elseif ratio <= Flags.RetreatHealth and clock >= runtime.retreatBlockUntil then
		if Flags.RetreatAction == "Leave Run" then
			local startedAt = runState().startedAt:get()
			if startedAt and runtime.retreatLeftAt ~= startedAt then
				runtime.retreatLeftAt = startedAt
				RunPackets.endAction:fire(LEAVE_ACTION)
			end
			return true
		end
		runtime.retreating = true
		runtime.retreatAt = clock
		runtime.retreatCheckAt = clock
		runtime.retreatSpot = runtime.retreatSpotFrom(root.Position)
	end
	if not runtime.retreating then
		return false
	end
	if clock - runtime.retreatCheckAt >= 1 then
		runtime.retreatCheckAt = clock
		if runtime.retreatThreatened(runtime.retreatSpot) then
			runtime.retreatSpot = runtime.retreatSpotFrom(runtime.retreatSpot - Vector3.new(0, Flags.RetreatHeight, 0))
		end
	end
	runtime.target = nil
	runtime.anchorId = nil
	runtime.targetGap = math.huge
	local look = root.CFrame.LookVector
	holdPose(root, runtime.retreatSpot, runtime.retreatSpot + Vector3.new(look.X, 0, look.Z) + Vector3.new(0, 0, 0.01), Vector3.yAxis)
	return true
end

function runtime.comboFromText(text)
	local order = {}
	for token in string.gmatch(string.lower(tostring(text or "")), "%w+") do
		local slot = if token == "u" or token == "ult" or token == "ultimate" then 4 else tonumber(token)
		if slot and SKILL_SLOT["Skill " .. slot] or slot == 4 then
			table.insert(order, slot)
		end
	end
	return order
end

function runtime.activeSkillSlots()
	if Flags.SkillCombo then
		local order = Flags.ComboOrder
		if #order == 0 then
			return {}
		end
		if runtime.comboIndex > #order then
			runtime.comboIndex = 1
		end
		return { order[runtime.comboIndex] }
	end
	return Flags.SkillSlots
end

function runtime.skillCooldown(store, slot)
	local character = store.state.character:get()
	local ok, key = pcall(PlayerNamespace.skillCooldownKey, character, slot)
	return store.state.cooldowns:get(if ok and type(key) == "string" then key else "skill" .. slot)
end

function runtime.ultReady(store)
	return (tonumber(store.state.ultProgress:get()) or 0) >= 100 and LocalPlayer:GetAttribute("UltimateLocked") ~= true
end

local function skillReady(store)
	if not Flags.AutoSkill then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	for _, slot in ipairs(runtime.activeSkillSlots()) do
		if slot ~= 4 then
			local cooldown = runtime.skillCooldown(store, slot)
			local till = cooldown and cooldown:get()
			if not till or till <= now then
				return true
			end
		end
	end
	return false
end

function runtime.areaBlocker(area)
	local mapConfig = Maps and Maps.mapsByName[Maps.currentMap]
	local areaConfig = mapConfig and mapConfig.areas[area]
	local mapFolder = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Map")
	local border = areaConfig and areaConfig.border and mapFolder and mapFolder:FindFirstChild(areaConfig.border)
	if not border then
		return nil
	end
	local maxHealth = border:GetAttribute("RubbleMaxHealth")
	local health = border:GetAttribute("RubbleHealth") or maxHealth
	if maxHealth == nil or (tonumber(health) or 0) <= 0 then
		return nil
	end
	return border:FindFirstChild("Blocker")
end

function runtime.rubbleFor(area, state, root)
	local wave = state.wave:get()
	local waveCount = state.waveCount:get()
	if wave <= 0 or waveCount <= 0 or wave < waveCount or state.remaining:get() > 0 then
		return nil
	end
	if enemiesWithin(root.Position, math.huge) > 0 then
		return nil
	end
	return runtime.liveRubble(runtime.areaBlocker(area))
end

function runtime.liveRubble(blocker)
	if blocker and blocker.Parent and blocker:IsA("BasePart") and blocker.CanCollide then
		return blocker
	end
	return nil
end

function runtime.holdRubble(root, blocker)
	local center = blocker.Position
	if runtime.anchorId ~= blocker then
		runtime.anchorId = blocker
		local away = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
		runtime.anchorDir = if away.Magnitude > 0.05 then away.Unit else Vector3.zAxis
	end
	holdPose(root, center, center - runtime.anchorDir, Vector3.yAxis)
end

function runtime.raidExit()
	if Workspace:GetAttribute("RaidExitOpen") ~= true then
		return nil
	end
	local markers = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Markers")
	local exit = markers and markers:FindFirstChild("Exit")
	local prompt = exit and exit:FindFirstChild("ExitPrompt")
	if exit and exit:IsA("BasePart") and prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
		return exit, prompt
	end
	return nil
end

function runtime.useRaidExit(root, exit, prompt)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local spot = exit.Position
	holdPose(root, spot, spot + (if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis), Vector3.yAxis)
	if (root.Position - spot).Magnitude > prompt.MaxActivationDistance - 2 or os.clock() - runtime.exitAt < 2 then
		return
	end
	runtime.exitAt = os.clock()
	if typeof(fireproximityprompt) == "function" then
		pcall(fireproximityprompt, prompt)
	else
		pcall(function()
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.05)
			prompt:InputHoldEnd()
		end)
	end
end

function runtime.ariseSpot(root)
	local folder = Workspace:FindFirstChild("AriseShadows")
	if not folder then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	local best, bestPrompt, bestGap
	for _, spot in ipairs(folder:GetChildren()) do
		local prompt = spot:FindFirstChildWhichIsA("ProximityPrompt", true)
		local expires = spot:GetAttribute("ExpiresAt")
		if prompt and prompt.Enabled and spot:GetAttribute("RaisedBy") == nil
			and (type(expires) ~= "number" or expires > now)
			and os.clock() - (runtime.ariseTried[spot] or 0) > 3 then
			local gap = (spot:GetPivot().Position - root.Position).Magnitude
			if not bestGap or gap < bestGap then
				best, bestPrompt, bestGap = spot, prompt, gap
			end
		end
	end
	return best, bestPrompt
end

function runtime.stepArise(root)
	if not Flags.AutoArise then
		return false
	end
	local spot, prompt = runtime.ariseSpot(root)
	if not spot then
		return false
	end
	local position = spot:GetPivot().Position
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	holdPose(root, position + Vector3.new(0, 3, 0), position + Vector3.new(0, 3, 0) + (if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis), Vector3.yAxis)
	if (root.Position - position).Magnitude > prompt.MaxActivationDistance - 1 then
		return true
	end
	runtime.ariseTried[spot] = os.clock()
	if typeof(fireproximityprompt) == "function" then
		pcall(fireproximityprompt, prompt)
	else
		pcall(function()
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.05)
			prompt:InputHoldEnd()
		end)
	end
	return true
end

function runtime.igrisThreats()
	local threats = {}
	for _, enemy in pairs(EnemyStore.store.state:getAll()) do
		local name = enemy.name:get()
		if enemy.health:get() > 0 and string.sub(tostring(name), 1, 9) == "soloIgris" then
			local started = enemy.attackStartedAt:get()
			local info = Enemies.enemiesByName[name]
			local attack = started and info and info.attacks and info.attacks[enemy.attackIndex:get()]
			if attack then
				local kind = runtime.igrisDanger(attack, Workspace:GetServerTimeNow() - started)
				if kind then
					local look = enemy.attackCFrame:get().LookVector
					local flat = Vector3.new(look.X, 0, look.Z)
					local position = enemy.position:get()
					table.insert(threats, {
						attack = attack,
						kind = kind,
						position = Vector3.new(position.X, 0, position.Z),
						look = if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis,
					})
				end
			end
		end
	end
	return threats
end

function runtime.igrisDanger(attack, age)
	local lunge = attack.lunge
	if lunge then
		local start = tonumber(lunge.start) or 4.45
		if age >= start - 0.6 and age <= (tonumber(attack.hitTime) or start) + 0.3 then
			return "lunge"
		end
	end
	local spikes = attack.spikes
	if spikes then
		local first = tonumber(spikes.first) or 1
		local last = first + (tonumber(spikes.telegraph) or 1) + (tonumber(spikes.gap) or 0.5) * ((tonumber(spikes.waves) or 1) - 1)
		if age >= first - 0.3 and age <= last + 0.4 then
			return "spikes"
		end
	end
	local times = {}
	if type(attack.hits) == "table" then
		for _, hit in ipairs(attack.hits) do
			table.insert(times, tonumber(hit.time))
		end
	else
		table.insert(times, tonumber(attack.hitTime))
	end
	if type(attack.slam) == "table" then
		table.insert(times, tonumber(attack.slam.time))
	end
	for _, time in ipairs(times) do
		if age >= time - 0.45 and age <= time + 0.25 then
			return "melee"
		end
	end
	return nil
end

function runtime.flatGap(from, to, point)
	local line = to - from
	local length = line.Magnitude
	if length < 0.05 then
		return (point - from).Magnitude
	end
	local along = math.clamp((point - from):Dot(line) / (length * length), 0, 1)
	return (point - (from + line * along)).Magnitude
end

function runtime.dodgeUnsafe(point, threats)
	local flat = Vector3.new(point.X, 0, point.Z)
	for _, threat in ipairs(threats) do
		local offset = flat - threat.position
		local distance = offset.Magnitude
		local lunge = threat.attack.lunge
		if distance < (if threat.kind == "lunge" then (tonumber(lunge.distance) or 60) + 25 else 32) then
			return true
		end
		local spikes = threat.attack.spikes
		if threat.kind == "spikes" and distance < (tonumber(spikes.range) or 120) + 15 then
			local spread = (spikes.lanes and tonumber(spikes.lanes.spreadAngle)) or tonumber(spikes.spread) or 45
			if offset.Unit:Dot(threat.look) > math.cos(math.rad(spread / 2 + 20)) then
				return true
			end
		end
	end
	return false
end

function runtime.dodgeGround(character, point)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, Workspace:FindFirstChild("enemies") }
	return Workspace:Raycast(point + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), params) ~= nil
end

function runtime.stepDodge(root)
	if not Flags.AutoDodgeIgris then
		runtime.dodging = false
		runtime.dodgeSpot = nil
		return false
	end
	local threats = runtime.igrisThreats()
	if #threats == 0 then
		runtime.dodging = false
		runtime.dodgeSpot = nil
		return false
	end
	local spot = runtime.dodgeSpot
	if not spot or runtime.dodgeUnsafe(spot, threats) then
		spot = nil
		if not runtime.dodgeUnsafe(root.Position, threats) then
			spot = root.Position
		else
			local here = Vector3.new(root.Position.X, 0, root.Position.Z)
			local best, bestCost
			for _, radius in ipairs({ 30, 50, 75, 100, 130 }) do
				for step = 0, 23 do
					local angle = step * math.pi / 12
					local candidate = root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
					if not runtime.dodgeUnsafe(candidate, threats) and runtime.dodgeGround(root.Parent, candidate) then
						local cost = radius
						local flat = Vector3.new(candidate.X, 0, candidate.Z)
						for _, threat in ipairs(threats) do
							if runtime.flatGap(here, flat, threat.position) < 15 then
								cost += 200
							end
						end
						if not bestCost or cost < bestCost then
							best, bestCost = candidate, cost
						end
					end
				end
				if bestCost and bestCost < 200 then
					break
				end
			end
			spot = best
		end
		runtime.dodgeSpot = spot
	end
	if not spot then
		runtime.dodging = false
		return false
	end
	spot = Vector3.new(spot.X, root.Position.Y, spot.Z)
	local nearest, nearestGap
	for _, threat in ipairs(threats) do
		local gap = (threat.position - Vector3.new(spot.X, 0, spot.Z)).Magnitude
		if not nearestGap or gap < nearestGap then
			nearest, nearestGap = threat.position, gap
		end
	end
	local focus = Vector3.new(nearest.X, spot.Y, nearest.Z)
	if (focus - spot).Magnitude < 0.05 then
		focus = spot + Vector3.zAxis
	end
	runtime.dodging = true
	runtime.target = nil
	runtime.anchorId = nil
	runtime.targetGap = math.huge
	holdPose(root, spot, focus, Vector3.yAxis)
	return true
end

function runtime.refreshPose()
	runtime.anchorId = nil
	releasePose()
end

local function stepFarm()
	local character, root, humanoid = characterParts()
	if not root or not inActiveRun() then
		runtime.retreating = false
		runtime.target = nil
		runtime.anchorId = nil
		runtime.targetGap = math.huge
		runtime.rubble = nil
		runtime.searchPoints = nil
		runtime.idleSince = nil
		releasePose()
		return
	end
	if updateRetreat(root, humanoid) then
		runtime.rubble = nil
		return
	end
	if runtime.stepDodge(root) then
		runtime.rubble = nil
		return
	end
	if runtime.stepArise(root) then
		runtime.anchorId = nil
		return
	end
	local exit, prompt = runtime.raidExit()
	if exit and enemiesWithin(root.Position, math.huge) == 0 then
		runtime.target = nil
		runtime.anchorId = nil
		runtime.targetGap = math.huge
		runtime.rubble = nil
		runtime.idleSince = nil
		runtime.useRaidExit(root, exit, prompt)
		return
	end
	local state = runState()
	local clock = os.clock()
	local wave = state.wave:get()
	local waveCount = state.waveCount:get()
	local betweenAreas = state.remaining:get() == 0
		and state.startedAt:get() ~= nil
		and state.finishedAt:get() == nil
		and (wave == 0 or (waveCount > 0 and wave >= waveCount))
	if betweenAreas then
		runtime.target = nil
		runtime.targetGap = math.huge
		local area = state.area:get()
		if runtime.wallArea ~= area then
			runtime.wallArea = area
			runtime.wallTries = 0
		end
		local blocker = runtime.rubbleFor(area, state, root)
		runtime.rubble = blocker or nil
		if blocker then
			runtime.idleSince = nil
			runtime.searchPoints = nil
			runtime.holdRubble(root, blocker)
			local store = PlayerNamespace.getLocalPlayerStore()
			if store and not store.state.blocking:get() and not store.state.cooldowns:get("m1") then
				CharacterPackets.performM1:fire()
			end
			return
		end
		if runtime.wallTries < 3 and clock - runtime.wallAt >= 1.5 then
			local target = areaEntryPosition(area, character)
			if target then
				tweenTo(root, CFrame.new(target + Vector3.new(0, 3.5, 0)), true)
				runtime.wallTries += 1
				runtime.wallAt = os.clock()
				return
			end
		end
		runtime.anchorId = nil
		if runtime.failsafe(root, character, area, clock) then
			return
		end
		runtime.holdSafe(root, character, area)
		return
	end
	runtime.wallTries = 0
	runtime.rubble = nil
	local id, position = nearestEnemy(root.Position)
	runtime.target = id
	if id then
		runtime.idleSince = nil
		runtime.searchPoints = nil
	else
		runtime.anchorId = nil
		runtime.targetGap = math.huge
		local area = state.area:get()
		local blocker = runtime.rubbleFor(area, state, root)
		if blocker then
			runtime.idleSince = nil
			runtime.rubble = blocker
			runtime.holdRubble(root, blocker)
			return
		end
		if runtime.failsafe(root, character, area, clock) then
			return
		end
		local center = areaEntryPosition(area, character)
		if center then
			local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
			if flat.Magnitude > 12 then
				local desired = center + Vector3.new(0, 3.5, 0)
				holdPose(root, desired, desired + Vector3.new(-flat.X, 0, -flat.Z), Vector3.yAxis)
				return
			end
		end
		runtime.holdSafe(root, character, area)
		return
	end
	local health = EnemyStore.store.state:get(id).health:get()
	if runtime.watchId ~= id or runtime.watchHealth ~= health then
		runtime.watchId = id
		runtime.watchHealth = health
		runtime.watchAt = clock
	elseif clock - runtime.watchAt >= 10 then
		runtime.skip[id] = clock + 15
		runtime.watchId = nil
		runtime.anchorId = nil
		releasePose()
		return
	end
	local dt = math.min(clock - runtime.lastTick, 0.2)
	runtime.lastTick = clock
	if runtime.anchorId ~= id then
		runtime.anchorId = id
		local away = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
		runtime.anchorDir = if away.Magnitude > 0.05 then away.Unit else Vector3.zAxis
		runtime.orbitAngle = math.atan2(runtime.anchorDir.Z, runtime.anchorDir.X)
	end
	local desired, focus, up = runtime.farmPose(position, dt)
	holdPose(root, desired, focus, up)
	local gap = (desired - position).Magnitude
	runtime.targetGap = gap
	local store = PlayerNamespace.getLocalPlayerStore()
	if store and skillReady(store) and targetsWithin(root.Position, Flags.SkillRange) >= Flags.SkillMinEnemies then
		if runtime.skillReadyAt == 0 then
			runtime.skillReadyAt = clock
		end
		if clock - runtime.skillReadyAt < 0.6 then
			return
		end
	else
		runtime.skillReadyAt = 0
	end
	if store and not store.state.blocking:get() and not store.state.cooldowns:get("m1") then
		CharacterPackets.performM1:fire()
	end
end

function runtime.ultAllowed()
	return not Flags.UltBossOnly or runtime.targetIsBoss()
end

function runtime.targetIsBoss()
	local id = runtime.target
	local enemy = id and EnemyStore.store.state:get(id)
	local info = enemy and Enemies.enemiesByName[enemy.name:get()]
	return info ~= nil and info.boss == true
end

local function stepSkill()
	local _, root = characterParts()
	if not root or not inActiveRun() or runtime.retreating then
		return
	end
	if targetsWithin(root.Position, Flags.SkillRange) < Flags.SkillMinEnemies then
		return
	end
	local store = PlayerNamespace.getLocalPlayerStore()
	local now = Workspace:GetServerTimeNow()
	if Flags.UltBossPriority and store and runtime.ultReady(store) and runtime.targetIsBoss() then
		local ok, started = pcall(CharacterController.performSkill, 4)
		if ok and started then
			runtime.skillReadyAt = 0
			task.wait(0.05)
			return
		end
	end
	if Flags.SkillCombo then
		local slots = runtime.activeSkillSlots()
		local slot = slots[1]
		local clock = os.clock()
		if not slot or clock - runtime.comboCastAt < Flags.ComboDelay then
			return
		end
		if slot == 4 and not runtime.ultAllowed() then
			runtime.comboIndex += 1
			runtime.comboSince = nil
			return
		end
		local cooldown = store and slot ~= 4 and runtime.skillCooldown(store, slot)
		local till = cooldown and cooldown:get()
		if till and till > now then
			runtime.comboSince = nil
			return
		end
		runtime.comboSince = runtime.comboSince or clock
		local ok, started = pcall(CharacterController.performSkill, slot)
		if ok and started then
			runtime.comboIndex += 1
			runtime.comboSince = nil
			runtime.comboCastAt = clock
			runtime.skillReadyAt = 0
			task.wait(0.05)
		elseif clock - runtime.comboSince >= 3 then
			runtime.comboIndex += 1
			runtime.comboSince = nil
		end
		return
	end
	for _, slot in ipairs(Flags.SkillSlots) do
		local cooldown = store and slot ~= 4 and runtime.skillCooldown(store, slot)
		local till = cooldown and cooldown:get()
		if (not till or till <= now) and (slot ~= 4 or runtime.ultAllowed()) then
			local ok, started = pcall(CharacterController.performSkill, slot)
			if ok and started then
				runtime.skillReadyAt = 0
				task.wait(0.05)
				return
			end
		end
	end
end

local function skillsOnCooldown()
	local store = PlayerNamespace.getLocalPlayerStore()
	if not store or #Flags.SkillSlots == 0 then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	for _, slot in ipairs(Flags.SkillSlots) do
		if slot ~= 4 then
			local cooldown = runtime.skillCooldown(store, slot)
			local till = cooldown and cooldown:get()
			if not till or till <= now then
				return false
			end
		elseif Flags.SwitchUltMode == "Consider Ultimates" and runtime.ultReady(store) and runtime.ultAllowed() then
			return false
		end
	end
	return true
end

local function stepSwitch()
	local _, root = characterParts()
	if not root or not inActiveRun() or runtime.retreating then
		return
	end
	local clock = os.clock()
	if clock - runtime.switchAt < 1 then
		return
	end
	local store = PlayerNamespace.getLocalPlayerStore()
	local gate = store and store.state.cooldowns:get("characterSwitch")
	local till = gate and gate:get()
	if till and till > Workspace:GetServerTimeNow() then
		return
	end
	if targetsWithin(root.Position, Flags.SkillRange) < 1 or not skillsOnCooldown() then
		return
	end
	runtime.switchAt = clock
	pcall(CharacterController.performSwitch)
end

local function stepRecord()
	local participant = myParticipant()
	if not participant then
		return
	end
	local status = participant.status:get()
	if status ~= "victory" and status ~= "failed" then
		return
	end
	local key = tostring(runState().startedAt:get()) .. status
	if runtime.recordedKey == key then
		return
	end
	runtime.recordedKey = key
	runtime.runsDone += 1
	recordRun(participant)
end

local function stepRun()
	local participant = myParticipant()
	if not participant then
		return
	end
	local state = runState()
	local clock = os.clock()
	if participant.status:get() == "active" then
		runtime.resultKey = nil
		local startedAt = state.startedAt:get()
		if
			Flags.AutoLeaveRun
			and startedAt
			and state.finishedAt:get() == nil
			and runtime.leftRunAt ~= startedAt
			and Workspace:GetServerTimeNow() - startedAt >= Flags.LeaveMinutes * 60
		then
			runtime.leftRunAt = startedAt
			RunPackets.endAction:fire(LEAVE_ACTION)
		end
		return
	end
	if participant.travelStatus:get() ~= "idle" then
		return
	end
	stepRecord()
	local finishedAt = state.finishedAt:get()
	local key = finishedAt or "down"
	if runtime.resultKey ~= key then
		runtime.resultKey = key
		runtime.resultSeenAt = clock
		runtime.resultActedKey = nil
	end
	if clock - runtime.resultSeenAt < Flags.ResultDelay then
		return
	end
	if runtime.resultActedKey == key and clock - runtime.resultActedAt < 8 then
		return
	end
	local action
	if Flags.AutoLeaveRuns and runtime.runsDone >= Flags.LeaveRuns then
		action = LEAVE_ACTION
	elseif finishedAt and Flags.AutoNextChapter and state.canNext:get() then
		action = 2
	elseif finishedAt and Flags.AutoRetry then
		action = 1
	elseif Flags.AutoLeave then
		action = LEAVE_ACTION
	end
	if not action then
		return
	end
	runtime.resultActedKey = key
	runtime.resultActedAt = clock
	RunPackets.endAction:fire(action)
end

local function startWorker(name, interval, gate, step)
	task.spawn(function()
		while not API.Unloaded do
			if gate() then
				local ok, err = pcall(step)
				if not ok then
					warn("[" .. GAME_NAME .. "] " .. name .. ": " .. tostring(err))
					task.wait(1)
				end
			end
			task.wait(interval)
		end
	end)
end

if IN_RUN then
	startWorker("Farm", 0, function()
		return Flags.AutoFarm
	end, stepFarm)
	startWorker("Arise", 0.1, function()
		return Flags.AutoArise and not Flags.AutoFarm
	end, function()
		local _, root = characterParts()
		local busy = root ~= nil and inActiveRun() and runtime.stepArise(root)
		if runtime.arising and not busy then
			releasePose()
		end
		runtime.arising = busy
	end)
	startWorker("Dodge", 0, function()
		return Flags.AutoDodgeIgris and not Flags.AutoFarm
	end, function()
		local _, root = characterParts()
		local was = runtime.dodging
		local busy = root ~= nil and inActiveRun() and runtime.stepDodge(root)
		if was and not busy then
			runtime.dodging = false
			releasePose()
		end
	end)
	startWorker("Skill", 0.03, function()
		return Flags.AutoSkill
	end, stepSkill)
	startWorker("Switch", 0.25, function()
		return Flags.SwitchOnCooldown
	end, stepSwitch)
	startWorker("Record", 0.5, function()
		return true
	end, stepRecord)
	startWorker("Run", 0.5, function()
		return Flags.AutoNextChapter or Flags.AutoRetry or Flags.AutoLeave or Flags.AutoLeaveRun or Flags.AutoLeaveRuns
	end, stepRun)
end

API.Track(function()
	releasePose()
	Flags.AutoFarm = false
	Flags.AutoArise = false
	Flags.AutoSkill = false
	Flags.AutoRetreat = false
	Flags.SwitchOnCooldown = false
	Flags.AutoNextChapter = false
	Flags.AutoRetry = false
	Flags.AutoLeave = false
	Flags.AutoLeaveRun = false
	Flags.AutoLeaveRuns = false
	Flags.AutoDodgeIgris = false
end)


local lobby = {
	requestId = 0,
	queueStatus = "idle",
	windowRoom = nil,
	summonId = nil,
	summonSentAt = 0,
	summonDone = true,
	pending = {},
	joinAt = 0,
	joinTries = 0,
	codesBusy = false,
	traitId = nil,
	traitSentAt = 0,
	traitDone = true,
	skillPending = nil,
	skillSentAt = 0,
	summonCount = 0,
	summonLast = "-",
	traitCount = 0,
	traitLast = "-",
	emoteId = nil,
	emoteSentAt = 0,
	emoteDone = true,
	emoteCount = 0,
	emoteLast = "-",
	unlockSentAt = 0,
	convertSentAt = 0,
	skipLabels = {},
	joinLabel = nil,
	joinLabelAt = 0,
}

local GAMEMODE_LABELS = {}
local GAMEMODE_CHOICES = {}
local CHAPTER_LABELS = {}
local RARITY_OPTIONS = { "None" }
local DIFFICULTY_LABELS = { "Easy", "Medium", "Hard", "Nightmare" }
local DIFFICULTY_INDEX = { Easy = 1, Medium = 2, Hard = 3, Nightmare = 4 }
local DIFFICULTY_GAMEMODES = { Story = true, Defend = true }
local CHARACTER_IDS = {}
local TRAIT_LABELS = {}
local TRAIT_BY_LABEL = {}
local CRAFT_LABELS = {}
local CRAFT_BY_LABEL = {}
local BRANCH_LABELS = {}
gacha.TRAIT_CHARACTER_OPTIONS = { "Equipped Character" }
gacha.TRAIT_RARITY_OPTIONS = { "None" }
gacha.TRAIT_RARITY_RANK = {}
gacha.EMOTE_NAMES = {}
gacha.EMOTE_RARITY = {}
gacha.EMOTE_RARITY_OPTIONS = { "None" }
gacha.EMOTE_RARITY_RANK = {}
if IN_LOBBY then
	local maxChapter = 1
	local ids = {}
	for id in pairs(GamemodeEnum.Gamemode) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, gamemode in ipairs(ids) do
		local mapIds = {}
		for _, entry in pairs(GamemodeEnum.Gamemode[gamemode].Maps) do
			local mapId = if type(entry) == "table" then entry.Id else entry
			if type(mapId) == "string" then
				table.insert(mapIds, mapId)
			end
		end
		table.sort(mapIds)
		for _, mapId in ipairs(mapIds) do
			local info = GamemodeEnum.Map[gamemode .. "_" .. mapId]
			local label = gamemode .. " - " .. (info and info.DisplayName or mapId)
			local chapters = 0
			if info and info.Chapters then
				for chapter in pairs(info.Chapters) do
					chapters = math.max(chapters, tonumber(chapter) or 0)
				end
			end
			maxChapter = math.max(maxChapter, chapters)
			table.insert(GAMEMODE_LABELS, label)
			GAMEMODE_CHOICES[label] = {
				gamemode = gamemode,
				map = mapId,
				chapters = chapters,
				fixedDifficulty = tonumber(GamemodeEnum.Gamemode[gamemode].FixedDifficulty),
			}
		end
	end
	table.insert(CHAPTER_LABELS, "Highest Unlocked")
	for chapter = 1, maxChapter do
		table.insert(CHAPTER_LABELS, tostring(chapter))
	end
	for _, rarity in ipairs(RollConfig.rarityOrder) do
		table.insert(RARITY_OPTIONS, rarity)
	end
	Flags.JoinChoice = GAMEMODE_LABELS[1]
	for id in pairs(SkillTreeConfig.characters) do
		table.insert(CHARACTER_IDS, id)
	end
	table.sort(CHARACTER_IDS)
	for _, trait in pairs(TraitConfig) do
		if type(trait) == "table" and trait.Enabled ~= false and trait.Name then
			local label = trait.Name .. " (" .. tostring(trait.Rarity) .. ")"
			table.insert(TRAIT_LABELS, label)
			TRAIT_BY_LABEL[label] = tonumber(trait.Id)
		end
	end
	table.sort(TRAIT_LABELS)
	for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Exotic", "Mythic", "Arcane", "Zenless" }) do
		for _, trait in pairs(TraitConfig) do
			if type(trait) == "table" and trait.Rarity == rarity and trait.Enabled ~= false then
				table.insert(gacha.TRAIT_RARITY_OPTIONS, rarity)
				break
			end
		end
		for _, emote in ipairs(EmotesConfig) do
			if emote.rarity == rarity then
				table.insert(gacha.EMOTE_RARITY_OPTIONS, rarity)
				break
			end
		end
	end
	for _, emote in ipairs(EmotesConfig) do
		table.insert(gacha.EMOTE_NAMES, emote.name)
		gacha.EMOTE_RARITY[emote.name] = emote.rarity
	end
	for key, recipe in pairs(CraftConfig) do
		local accessory = AccessoryConfig[recipe.CarftID]
		if accessory and accessory.Name then
			local needs = {}
			for pair in string.gmatch(tostring(recipe.Misc or ""), "[^|]+") do
				local material, amount = string.match(pair, "^%s*([^,]+)%s*,%s*(%d+)")
				if material then
					table.insert(needs, { id = material, amount = tonumber(amount) })
				end
			end
			table.insert(CRAFT_LABELS, accessory.Name)
			CRAFT_BY_LABEL[accessory.Name] = { key = tostring(key), accessory = tostring(recipe.CarftID), needs = needs }
		end
	end
	table.sort(CRAFT_LABELS)
	for _, branch in ipairs(SkillTreeConfig.branchOrder) do
		table.insert(BRANCH_LABELS, branch)
	end
end

do
	local LOBBY_OPTIONS_FILE = STATS_FOLDER .. "/lobby_options.json"
	if IN_LOBBY then
		pcall(function()
			if not hasFiles then
				return
			end
			if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
				if not isfolder("Relwx") then
					makefolder("Relwx")
				end
				if not isfolder(STATS_FOLDER) then
					makefolder(STATS_FOLDER)
				end
			end
			writefile(LOBBY_OPTIONS_FILE, HttpService:JSONEncode({
				gamemodeLabels = GAMEMODE_LABELS,
				gamemodeChoices = GAMEMODE_CHOICES,
				chapterLabels = CHAPTER_LABELS,
				rarityOptions = RARITY_OPTIONS,
				characterIds = CHARACTER_IDS,
				traitLabels = TRAIT_LABELS,
				traitByLabel = TRAIT_BY_LABEL,
				craftLabels = CRAFT_LABELS,
				craftByLabel = CRAFT_BY_LABEL,
				branchLabels = BRANCH_LABELS,
				traitRarityOptions = gacha.TRAIT_RARITY_OPTIONS,
				emoteNames = gacha.EMOTE_NAMES,
				emoteRarity = gacha.EMOTE_RARITY,
				emoteRarityOptions = gacha.EMOTE_RARITY_OPTIONS,
			}))
		end)
	else
		local ok, cached = pcall(function()
			if hasFiles and isfile(LOBBY_OPTIONS_FILE) then
				return HttpService:JSONDecode(readfile(LOBBY_OPTIONS_FILE))
			end
			return nil
		end)
		if ok and type(cached) == "table" then
			local function copyList(target, source)
				if type(source) == "table" then
					table.clear(target)
					for _, value in ipairs(source) do
						table.insert(target, value)
					end
				end
			end
			local function copyMap(target, source)
				if type(source) == "table" then
					for key, value in pairs(source) do
						target[key] = value
					end
				end
			end
			copyList(GAMEMODE_LABELS, cached.gamemodeLabels)
			copyMap(GAMEMODE_CHOICES, cached.gamemodeChoices)
			copyList(CHAPTER_LABELS, cached.chapterLabels)
			copyList(RARITY_OPTIONS, cached.rarityOptions)
			copyList(CHARACTER_IDS, cached.characterIds)
			copyList(TRAIT_LABELS, cached.traitLabels)
			copyMap(TRAIT_BY_LABEL, cached.traitByLabel)
			copyList(CRAFT_LABELS, cached.craftLabels)
			copyMap(CRAFT_BY_LABEL, cached.craftByLabel)
			copyList(BRANCH_LABELS, cached.branchLabels)
			copyList(gacha.TRAIT_RARITY_OPTIONS, cached.traitRarityOptions)
			copyList(gacha.EMOTE_NAMES, cached.emoteNames)
			copyMap(gacha.EMOTE_RARITY, cached.emoteRarity)
			copyList(gacha.EMOTE_RARITY_OPTIONS, cached.emoteRarityOptions)
			Flags.JoinChoice = GAMEMODE_LABELS[1]
		end
	end
end

for _, id in ipairs(CHARACTER_IDS) do
	table.insert(gacha.TRAIT_CHARACTER_OPTIONS, id)
end
for index, rarity in ipairs(gacha.TRAIT_RARITY_OPTIONS) do
	gacha.TRAIT_RARITY_RANK[rarity] = index
end
for index, rarity in ipairs(gacha.EMOTE_RARITY_OPTIONS) do
	gacha.EMOTE_RARITY_RANK[rarity] = index
end

local function nextRequestId()
	lobby.requestId = lobby.requestId % 65535 + 1
	return lobby.requestId
end

local function accountSnapshot()
	local ok, store = pcall(Account.getLocalPlayerAccount)
	if not ok or not store then
		return nil
	end
	local okTable, snapshot = pcall(store.toTable, store)
	return okTable and snapshot or nil
end

local function getDeliveryQuestCount()
	local ok, state = pcall(function()
		local account = Account.getLocalPlayerAccount()
		return account and account.state
	end)
	if not ok or type(state) ~= "table" then
		return 0
	end
	local quests = state.quests
	local progress = quests and quests.progress
	local entries = progress and progress.entries
	local value = entries and entries["delivery.dailyCount"]
	local count = (type(value) == "table" and (value.current or value.count)) or tonumber(value) or 0
	return math.max(0, tonumber(count) or 0)
end

local function playerLevel(snapshot)
	local ok, progress = pcall(Levels.getProgress, tonumber(snapshot.currencies.xp) or 0)
	return ok and type(progress) == "table" and tonumber(progress.level) or 0
end

local function notPending(key, seconds)
	local clock = os.clock()
	local sent = lobby.pending[key]
	if sent and clock - sent < seconds then
		return false
	end
	lobby.pending[key] = clock
	return true
end

local function stepMilestones()
	local snapshot = accountSnapshot()
	if not snapshot then
		return
	end
	local level = playerLevel(snapshot)
	for key in pairs(MilestoneConfig.milestones) do
		local milestone = tonumber(key)
		if milestone and milestone <= level and snapshot.claimedLevelMilestones[tostring(milestone)] ~= true then
			if notPending("milestone" .. milestone, 6) then
				LobbyPackets.claimLevelMilestone:fire({ level = milestone, requestId = nextRequestId() })
				task.wait(0.35)
			end
		end
	end
end

local function stepDaily()
	local snapshot = accountSnapshot()
	if not snapshot then
		return
	end
	local rewards = snapshot.dailyReward.rewards
	for day = 1, 7 do
		if (rewards[day] or rewards[tostring(day)]) == "available" and notPending("daily" .. day, 6) then
			LobbyPackets.claimDailyReward:fire(day)
			task.wait(0.5)
		end
	end
end

local function stepQuests()
	local snapshot = accountSnapshot()
	if not snapshot then
		return
	end
	local quests = snapshot.quests
	for id in pairs(QuestConfig.quests) do
		if quests.completed[id] == true and quests.claimed[id] ~= true and notPending("quest" .. id, 6) then
			LobbyPackets.claimQuestReward:fire({ questId = id, requestId = nextRequestId() })
			task.wait(0.4)
		end
	end
end

local function stepSummon()
	local clock = os.clock()
	if not lobby.summonDone and clock - lobby.summonSentAt < 8 then
		return
	end
	if clock - lobby.summonSentAt < Flags.SummonDelay then
		return
	end
	local snapshot = accountSnapshot()
	if not snapshot then
		return
	end
	local slot = snapshot.UnlockedCharacters["Slot" .. Flags.SummonSlot]
	if not slot or slot.Unlocked ~= true then
		return
	end
	local threshold = table.find(RollConfig.rarityOrder, Flags.ProtectRarity)
	local current = RollConfig.rarityByCharacter[slot.Character]
	local currentIndex = current and table.find(RollConfig.rarityOrder, current)
	if threshold and currentIndex and currentIndex >= threshold then
		return
	end
	if slot.Character ~= "" and table.find(Flags.SummonStopCharacters, slot.Character) then
		return
	end
	local costs = EconomyConfig.rollCosts.character
	local payment, need
	if Flags.SummonType == "Lucky" then
		payment, need = "luckySpins", costs.Lucky.amount
	elseif Flags.SummonPayment == "rolls" then
		payment, need = "rolls", costs.NormalDice.amount
	else
		payment, need = "money", costs.Normal.amount
	end
	if (tonumber(snapshot.currencies[payment]) or 0) < need then
		local conversion = EconomyConfig.currencyConversions.luckySpins
		local gems = tonumber(snapshot.currencies.gems) or 0
		if payment == "luckySpins" and Flags.SummonBuyLucky and gems >= conversion.cost.amount and clock - lobby.convertSentAt > 3 then
			lobby.convertSentAt = clock
			LobbyPackets.convertGemsToLuckySpins:fire({
				amount = math.min(10, math.floor(gems / conversion.cost.amount)),
				requestId = nextRequestId(),
			})
		end
		return
	end
	lobby.summonDone = false
	lobby.summonSentAt = clock
	lobby.summonId = nextRequestId()
	LobbyPackets.rollCharacter:fire({
		spinType = Flags.SummonType,
		slot = Flags.SummonSlot,
		paymentCurrency = payment,
		requestId = lobby.summonId,
	})
end

function gacha.traitById(id)
	for _, trait in pairs(id and TraitConfig or {}) do
		if type(trait) == "table" and tonumber(trait.Id) == id then
			return trait
		end
	end
	return nil
end

local function stepTrait()
	if not lobby.traitDone and os.clock() - lobby.traitSentAt < 7 then
		return
	end
	if os.clock() - lobby.traitSentAt < Flags.TraitDelay then
		return
	end
	local snapshot = accountSnapshot()
	local character = Flags.TraitCharacter
	if character == "Equipped Character" then
		character = snapshot and snapshot.character
	end
	local data = snapshot and character and snapshot.CharactersData[character]
	local minRank = gacha.TRAIT_RARITY_RANK[Flags.TraitStopRarity] or 1
	if not data or (#Flags.TraitTargets == 0 and minRank <= 1) then
		return
	end
	local current = tonumber(data.TraitData and data.TraitData.Trait)
	if current and table.find(Flags.TraitTargets, current) then
		return
	end
	local currentTrait = gacha.traitById(current)
	local currentRank = currentTrait and gacha.TRAIT_RARITY_RANK[currentTrait.Rarity]
	if minRank > 1 and currentRank and currentRank >= minRank then
		return
	end
	local cost = EconomyConfig.rollCosts.trait
	if (tonumber(snapshot.currencies[cost.currency]) or 0) < cost.amount then
		return
	end
	lobby.traitDone = false
	lobby.traitSentAt = os.clock()
	lobby.traitId = nextRequestId()
	LobbyPackets.rollTrait:fire({ character = character, requestId = lobby.traitId })
end

function gacha.emoteGoalReached(owned)
	if Flags.EmoteStopAllOwned and #gacha.EMOTE_NAMES > 0 then
		local all = true
		for _, name in ipairs(gacha.EMOTE_NAMES) do
			if not owned[name] then
				all = false
				break
			end
		end
		if all then
			return true
		end
	end
	for _, name in ipairs(Flags.EmoteTargets) do
		if owned[name] then
			return true
		end
	end
	local minRank = gacha.EMOTE_RARITY_RANK[Flags.EmoteStopRarity] or 1
	if minRank > 1 then
		for name, has in pairs(owned) do
			local rank = has and gacha.EMOTE_RARITY_RANK[gacha.EMOTE_RARITY[name]]
			if rank and rank >= minRank then
				return true
			end
		end
	end
	return false
end

function gacha.stepEmote()
	if not lobby.emoteDone and os.clock() - lobby.emoteSentAt < 7 then
		return
	end
	if os.clock() - lobby.emoteSentAt < 0.5 then
		return
	end
	local snapshot = accountSnapshot()
	if not snapshot then
		return
	end
	if gacha.emoteGoalReached(snapshot.emotes and snapshot.emotes.owned or {}) then
		Flags.AutoEmote = false
		return
	end
	local cost = EconomyConfig.rollCosts.emote
	if (tonumber(snapshot.currencies[cost.currency]) or 0) < cost.amount then
		return
	end
	lobby.emoteDone = false
	lobby.emoteSentAt = os.clock()
	lobby.emoteId = nextRequestId()
	LobbyPackets.rollEmote:fire({ requestId = lobby.emoteId })
end

function gacha.stepUnlockSlots()
	if os.clock() - lobby.unlockSentAt < 3 then
		return
	end
	local snapshot = accountSnapshot()
	if not snapshot then
		return
	end
	for slot = 2, 4 do
		local data = snapshot.UnlockedCharacters["Slot" .. slot]
		if data and data.Unlocked ~= true then
			local cost = tonumber(EconomyConfig.characterSlotUnlockCosts[slot])
			if cost and (tonumber(snapshot.currencies.money) or 0) >= cost then
				lobby.unlockSentAt = os.clock()
				LobbyPackets.unlockCharacterSlot:fire({ slot = slot, requestId = nextRequestId() })
			end
			return
		end
	end
end

local function stepCraft()
	local snapshot = accountSnapshot()
	if not snapshot then
		return
	end
	for _, label in ipairs(if #Flags.CraftItems > 0 then Flags.CraftItems else CRAFT_LABELS) do
		local recipe = CRAFT_BY_LABEL[label]
		if recipe and (tonumber(snapshot.accessory[recipe.accessory]) or 0) < Flags.CraftTarget then
			local enough = #recipe.needs > 0
			for _, need in ipairs(recipe.needs) do
				if (tonumber(snapshot.material[need.id]) or 0) < need.amount then
					enough = false
					break
				end
			end
			if enough and notPending("craft" .. recipe.key, 3) then
				LobbyPackets.craftAccessory:fire(recipe.key)
				task.wait(0.6)
				return
			end
		end
	end
end

local function stepSkillTree()
	if lobby.skillPending and os.clock() - lobby.skillSentAt < 6 then
		return
	end
	lobby.skillPending = nil
	local snapshot = accountSnapshot()
	if not snapshot or #Flags.SkillTreeBranches == 0 then
		return
	end
	for _, character in ipairs(Flags.SkillTreeCharacters) do
		local data = snapshot.CharactersData[character]
		local config = SkillTreeConfig.characters[character]
		if data and config and data.Progression then
			local skills = data.Progression.Skills or {}
			local ok, tokens = pcall(CharacterLevels.getAvailableTokens, character, data.Progression.Xp, skills)
			if ok and tokens then
				for _, branch in ipairs(Flags.SkillTreeBranches) do
					local tier = (tonumber(skills[branch]) or 1) + 1
					local node = config.branches[branch] and config.branches[branch].tiers[tier]
					if node and tier <= Flags.SkillTreeMaxTier and node.cost <= tokens then
						lobby.skillSentAt = os.clock()
						lobby.skillPending = nextRequestId()
						SkillTreePackets.purchaseCharacterSkill:fire({
							character = character,
							branch = branch,
							tier = tier,
							requestId = lobby.skillPending,
						})
						return
					end
				end
			end
		end
	end
end

local function roomState(number)
	local namespace = QueueRoomStore.namespace
	local ok, store = pcall(namespace.getStore, namespace, "room " .. number)
	return ok and store and store.state or nil
end

function gacha.pickAutoStory()
	if not (Flags.JoinAuto and gacha.K.AutoProgress) then
		return nil
	end
	local snapshot = accountSnapshot()
	local progress = snapshot and snapshot.achievements and snapshot.achievements.progress
	if not progress then
		return nil
	end
	local now = os.clock()
	for _, label in ipairs(GAMEMODE_LABELS) do
		local choice = GAMEMODE_CHOICES[label]
		if choice and choice.gamemode == "Story" and choice.chapters > 0 and (lobby.skipLabels[label] or 0) < now then
			local cleared = tonumber(progress["story." .. string.lower(choice.map) .. ".cleared"]) or 0
			if cleared < choice.chapters then
				return label
			end
		end
	end
	return nil
end

local function stepJoin()
	if lobby.queueStatus == "inQuque" or lobby.queueStatus == "teleporting" then
		lobby.joinLabel = nil
		return
	end
	if lobby.joinLabel and os.clock() - lobby.joinLabelAt > 25 then
		lobby.skipLabels[lobby.joinLabel] = os.clock() + 900
		warn("[" .. GAME_NAME .. "] queue for " .. tostring(lobby.joinLabel) .. " was not accepted; trying another map")
		lobby.joinLabel = nil
	end
	local _, root = characterParts()
	local choice = GAMEMODE_CHOICES[Flags.JoinChoice]
	local pickLabel = Flags.JoinChoice
	local autoLabel = gacha.pickAutoStory()
	if autoLabel then
		choice, pickLabel = GAMEMODE_CHOICES[autoLabel], autoLabel
	end
	if not root or not choice then
		return
	end
	if os.clock() - gacha.lobbyStart < Flags.JoinDelay or gacha.deliveryBusy() then
		return
	end
	if lobby.windowRoom then
		local wanted = Flags.JoinChapter
		if wanted == 0 then
			local snapshot = accountSnapshot()
			local progress = snapshot and snapshot.achievements and snapshot.achievements.progress
			local cleared = progress and tonumber(progress["story." .. string.lower(choice.map) .. ".cleared"]) or 0
			wanted = cleared + 1
		end
		local chapter = if choice.chapters > 0 then math.clamp(wanted, 1, choice.chapters) else 0
		local difficulty = choice.fixedDifficulty
			or if DIFFICULTY_GAMEMODES[choice.gamemode] then DIFFICULTY_INDEX[Flags.JoinDifficulty] or 1 else 1
		LobbyPackets.createQuque:fire({
			gamemode = choice.gamemode,
			map = choice.map,
			chapter = chapter,
			difficulty = difficulty,
			maxPlayers = Flags.JoinPlayers,
			friendsOnly = Flags.JoinFriendsOnly,
			roomNumber = lobby.windowRoom,
		})
		lobby.joinLabel, lobby.joinLabelAt = pickLabel, os.clock()
		lobby.windowRoom = nil
		lobby.joinAt = os.clock()
		task.wait(3)
		return
	end
	if os.clock() - lobby.joinAt < 4 then
		return
	end
	local rooms = Workspace.Systems:FindFirstChild("QuqueRooms")
	local best, bestDistance
	for _, folder in ipairs(rooms and rooms:GetChildren() or {}) do
		local number = tonumber(folder.Name)
		local state = number and roomState(number)
		local hitbox = folder:FindFirstChild("JoinHitbox")
		local inside = folder:FindFirstChild("Inside")
		if state and hitbox and inside and state.status:get() == "idle" then
			local distance = (hitbox.Position - root.Position).Magnitude
			if not bestDistance or distance < bestDistance then
				best = Vector3.new(hitbox.Position.X, inside.Position.Y + 2.5, hitbox.Position.Z)
				bestDistance = distance
			end
		end
	end
	if not best then
		return
	end
	lobby.joinAt = os.clock()
	lobby.joinTries += 1
	if lobby.joinTries % 2 == 0 then
		tweenTo(root, CFrame.new(best + Vector3.new(0, 0, 40)), true)
		task.wait(0.3)
	end
	tweenTo(root, CFrame.new(best), true)
	lobby.joinAt = os.clock()
end

gacha.BEST_STATS = { "Damage", "HP", "Critical Chance", "Coins", "Exp", "Drop Rate" }
gacha.gearSentAt = 0
gacha.evolveSentAt = 0

function gacha.buffScore(entry)
	local total = 0
	for _, buff in ipairs(type(entry) == "table" and type(entry.Buffs) == "table" and entry.Buffs or {}) do
		if buff.Type == Flags.BestGearStat then
			total += tonumber(buff.Percent) or 0
		end
	end
	return total
end

function gacha.stepEvolve()
	if os.clock() - gacha.evolveSentAt < 5 then
		return
	end
	local snapshot = accountSnapshot()
	local character = snapshot and snapshot.character
	local data = character and snapshot.CharactersData[character]
	local recipe = character and gacha.EvolutionConfig[character]
	if not data or not recipe or data.IsUltimateUnlocked == true then
		return
	end
	for _, cost in ipairs(recipe.currencies or {}) do
		if (tonumber(snapshot.currencies[cost.currency]) or 0) < (tonumber(cost.amount) or 0) then
			return
		end
	end
	for pair in string.gmatch(tostring(recipe.ultimate or ""), "[^|]+") do
		local material, amount = string.match(pair, "^%s*([^,]+)%s*,%s*(%d+)")
		if material and (tonumber(snapshot.material[material]) or 0) < tonumber(amount) then
			return
		end
	end
	gacha.evolveSentAt = os.clock()
	LobbyPackets.evolveCharacter:fire(character)
end

function gacha.stepBestGear()
	if os.clock() - gacha.gearSentAt < 4 then
		return
	end
	local snapshot = accountSnapshot()
	if not snapshot then
		return
	end
	if Flags.AutoBestAccessory then
		local best, bestScore = {}, {}
		for id, count in pairs(snapshot.accessory or {}) do
			local entry = AccessoryConfig[tonumber(id)] or AccessoryConfig[tostring(id)]
			local slot = entry and entry.Slot
			local score = gacha.buffScore(entry)
			if slot and (tonumber(count) or 0) > 0 and score > (bestScore[slot] or 0) then
				best[slot], bestScore[slot] = tostring(id), score
			end
		end
		local equipped = type(snapshot.equippedAccessories) == "table" and snapshot.equippedAccessories or {}
		for slot, id in pairs(best) do
			if tostring(equipped[slot] or "") ~= id then
				gacha.gearSentAt = os.clock()
				LobbyPackets.setEquippedAccessory:fire(id)
				return
			end
		end
	end
	if Flags.AutoBestTitle then
		local best, bestScore = nil, 0
		for id, entry in pairs(gacha.TitleConfig) do
			local owned = snapshot.title and (snapshot.title[id] == true or snapshot.title[tostring(id)] == true)
			local score = gacha.buffScore(entry)
			if owned and score > bestScore then
				best, bestScore = id, score
			end
		end
		if best and tostring(snapshot.equippedTitle) ~= tostring(best) then
			gacha.gearSentAt = os.clock()
			LobbyPackets.equipTitle:fire(best)
			return
		end
	end
	if Flags.AutoRarestCharacters then
		local ranked = {}
		for slot = 1, 4 do
			local data = snapshot.UnlockedCharacters["Slot" .. slot]
			if data and data.Unlocked == true and data.Character ~= "" then
				local rarity = RollConfig.rarityByCharacter[data.Character]
				table.insert(ranked, { slot = slot, rank = rarity and table.find(RollConfig.rarityOrder, rarity) or 0 })
			end
		end
		table.sort(ranked, function(a, b)
			if a.rank ~= b.rank then
				return a.rank > b.rank
			end
			return a.slot < b.slot
		end)
		local gameSlots = 0
		for key in pairs(snapshot.EquippedCharacterSlots or {}) do
			gameSlots = math.max(gameSlots, tonumber(string.match(tostring(key), "%d+")) or 0)
		end
		local top = {}
		for index = 1, math.min(gameSlots, #ranked) do
			top[ranked[index].slot] = true
		end
		local equipped = {}
		for gameSlot = 1, gameSlots do
			equipped[tonumber(snapshot.EquippedCharacterSlots["Slot" .. gameSlot]) or 0] = gameSlot
		end
		for index = 1, math.min(gameSlots, #ranked) do
			local want = ranked[index].slot
			if not equipped[want] then
				for gameSlot = 1, gameSlots do
					local current = tonumber(snapshot.EquippedCharacterSlots["Slot" .. gameSlot]) or 0
					if not top[current] then
						gacha.gearSentAt = os.clock()
						LobbyPackets.equipCharacterSlot:fire({ slot = want, gameSlot = gameSlot, requestId = nextRequestId() })
						return
					end
				end
			end
		end
	end
end

function gacha.stepAchievements()
	LobbyPackets.claimAchievementRewards:fire({ requestId = nextRequestId() })
end

function gacha.stepSkipTutorial()
	if LocalPlayer:GetAttribute("TutorialPending") ~= true then
		return
	end
	local remote = ReplicatedStorage:FindFirstChild("TutorialRemote")
	if remote then
		remote:FireServer("skip")
		task.wait(5)
	end
end

gacha.lobbyStart = os.clock()
gacha.delivery = nil
gacha.deliverySentAt = 0

function gacha.deliveryNpc(name)
	local systems = Workspace:FindFirstChild("Systems")
	local npcs = systems and systems:FindFirstChild("NPCS")
	local npc = npcs and npcs:FindFirstChild(name)
	if not npc then
		local scattered = systems and systems:FindFirstChild("ScatteredNPCS")
		npc = scattered and scattered:FindFirstChild(name)
	end
	local part = npc and npc:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

function gacha.stepDelivery()
	local state = gacha.delivery
	local _, root = characterParts()
	if not root then
		return
	end
	local clock = os.clock()
	if not state then
		if clock - gacha.deliverySentAt > 5 then
			gacha.deliverySentAt = clock
			LobbyPackets.deliveryAction:fire({ action = "refresh", requestId = nextRequestId() })
		end
		return
	end
	if state.status == "carrying" then
		local target = gacha.deliveryNpc(tostring(state.target))
		if target and (target.Position - root.Position).Magnitude > 4 then
			tweenTo(root, target.CFrame * CFrame.new(0, 0, -3), true)
		end
		return
	end
	if clock - gacha.deliverySentAt < 3 then
		return
	end
	local giver = gacha.deliveryNpc("Heiyun")
	local action
	if state.status == "delivered" then
		action = "claim"
	elseif state.status == "none" and (tonumber(state.dailyCount) or 0) < (tonumber(state.dailyLimit) or 0) then
		action = "request"
	end
	if not action then
		return
	end
	if giver and (giver.Position - root.Position).Magnitude > 10 then
		tweenTo(root, giver.CFrame * CFrame.new(0, 0, -5), true)
	end
	gacha.deliverySentAt = os.clock()
	LobbyPackets.deliveryAction:fire({ action = action, requestId = nextRequestId() })
end

function gacha.deliveryBusy()
	local state = gacha.delivery
	if not Flags.AutoDelivery or not state then
		return false
	end
	return state.status == "carrying"
		or state.status == "delivered"
		or (state.status == "none" and (tonumber(state.dailyCount) or 0) < (tonumber(state.dailyLimit) or 0))
end

local function redeemAllCodes(onDone)
	if lobby.codesBusy then
		return
	end
	lobby.codesBusy = true
	task.spawn(function()
		local redeemed = {}
		local snapshot = accountSnapshot()
		if snapshot and type(snapshot.cdk) == "table" then
			for _, code in pairs(snapshot.cdk) do
				redeemed[string.lower(tostring(code))] = true
			end
		end
		local codes = {}
		local seen = {}
		for _, entry in pairs(CodesConfig) do
			if type(entry) == "table" and type(entry.Code) == "string" and not seen[string.lower(entry.Code)] then
				seen[string.lower(entry.Code)] = true
				table.insert(codes, entry.Code)
			end
		end
		for _, code in ipairs({ "TYASHIRA", "TYFRIGID", "NEWRAID", "SORRYFORDELAY" }) do
			if not seen[string.lower(code)] then
				seen[string.lower(code)] = true
				table.insert(codes, code)
			end
		end
		table.sort(codes)
		local sent = 0
		for _, code in ipairs(codes) do
			if API.Unloaded then
				break
			end
			if not redeemed[string.lower(code)] then
				LobbyPackets.redeemCode:fire(code)
				sent += 1
				task.wait(1.2)
			end
		end
		lobby.codesBusy = false
		if onDone and not API.Unloaded then
			onDone(sent, #codes)
		end
	end)
end

if IN_LOBBY then
	local function listen(event, handler)
		local ok, handle = pcall(function()
			return event:on(handler)
		end)
		if not ok then
			warn("[" .. GAME_NAME .. "] listener: " .. tostring(handle))
			return
		end
		API.Track(function()
			local kind = typeof(handle)
			if kind == "function" then
				pcall(handle)
			elseif kind == "RBXScriptConnection" then
				handle:Disconnect()
			elseif kind == "table" and type(handle.Disconnect) == "function" then
				pcall(handle.Disconnect, handle)
			end
		end)
	end
	listen(LobbyPackets.deliveryState, function(state)
		if type(state) == "table" then
			gacha.delivery = state
		end
	end)
	listen(LobbyPackets.updateClientQuqueStatus, function(status)
		lobby.queueStatus = status
	end)
	listen(LobbyPackets.toggleQuqueWindow, function(data)
		lobby.windowRoom = if data.open then data.roomNumber else nil
	end)
	listen(LobbyPackets.characterRolled, function(data)
		if data.requestId == lobby.summonId then
			lobby.summonDone = true
			task.spawn(function()
				task.wait(0.4)
				local snapshot = accountSnapshot()
				local slot = snapshot and snapshot.UnlockedCharacters["Slot" .. Flags.SummonSlot]
				local rarity = slot and RollConfig.rarityByCharacter[slot.Character]
				local threshold = table.find(RollConfig.rarityOrder, Flags.ProtectRarity)
				local index = rarity and table.find(RollConfig.rarityOrder, rarity)
				lobby.summonCount += 1
				lobby.summonLast = if slot and slot.Character ~= "" then characterName(slot.Character) else "-"
				local wanted = slot ~= nil and table.find(Flags.SummonStopCharacters, slot.Character) ~= nil
				if ((threshold and index and index >= threshold) or wanted) and not API.Unloaded then
					recordRollHit(slot.Character, rarity)
					if Flags.SummonFavourite and slot.Favourite ~= true then
						LobbyPackets.setCharacterSlotFavourite:fire({
							slot = Flags.SummonSlot,
							favourite = true,
							requestId = nextRequestId(),
						})
					end
				end
			end)
		end
	end)
	listen(LobbyPackets.traitRolled, function(data)
		if data.requestId == lobby.traitId then
			lobby.traitDone = true
			lobby.traitCount += 1
			task.spawn(function()
				task.wait(0.4)
				local snapshot = accountSnapshot()
				local character = Flags.TraitCharacter
				if character == "Equipped Character" then
					character = snapshot and snapshot.character
				end
				local entry = snapshot and character and snapshot.CharactersData[character]
				local id = entry and entry.TraitData and tonumber(entry.TraitData.Trait)
				local trait = gacha.traitById(id)
				lobby.traitLast = if trait and trait.Name then tostring(trait.Name) else "-"
			end)
		end
	end)
	listen(LobbyPackets.emoteRolled, function(data)
		if data.requestId == lobby.emoteId then
			lobby.emoteDone = true
			if data.success then
				lobby.emoteCount += 1
				lobby.emoteLast = tostring(data.emote)
			end
		end
	end)
	listen(SkillTreePackets.characterSkillPurchaseResult, function(data)
		if data.requestId == lobby.skillPending then
			lobby.skillPending = nil
		end
	end)
	startWorker("Trait", 0.2, function()
		return Flags.AutoTrait
	end, stepTrait)
	startWorker("Craft", 1, function()
		return Flags.AutoCraft
	end, stepCraft)
	startWorker("Delivery", 1, function()
		return Flags.AutoDelivery
	end, gacha.stepDelivery)
	task.delay(3, function()
		pcall(function()
			LobbyPackets.deliveryAction:fire({ action = "refresh", requestId = nextRequestId() })
		end)
	end)
	startWorker("Evolve", 3, function()
		return Flags.AutoEvolve
	end, gacha.stepEvolve)
	startWorker("BestGear", 5, function()
		return Flags.AutoBestAccessory or Flags.AutoBestTitle or Flags.AutoRarestCharacters
	end, gacha.stepBestGear)
	startWorker("Achievements", 30, function()
		return Flags.AutoAchievements
	end, gacha.stepAchievements)
	startWorker("SkipTutorial", 2, function()
		return Flags.AutoSkipTutorial
	end, gacha.stepSkipTutorial)
	startWorker("RedeemCodes", 2, function()
		return Flags.AutoRedeemCodes
	end, function()
		if not gacha.codesAt or os.clock() - gacha.codesAt > 600 then
			gacha.codesAt = os.clock()
			redeemAllCodes()
		end
	end)
	startWorker("SkillTree", 1, function()
		return Flags.AutoSkillTree
	end, stepSkillTree)
	startWorker("Join", 0.5, function()
		return Flags.AutoJoin
	end, stepJoin)
	startWorker("Milestones", 2, function()
		return Flags.AutoMilestones
	end, stepMilestones)
	startWorker("Daily", 3, function()
		return Flags.AutoDaily
	end, stepDaily)
	startWorker("Quests", 3, function()
		return Flags.AutoQuests
	end, stepQuests)
	startWorker("Summon", 0.5, function()
		return Flags.AutoSummon
	end, stepSummon)
	startWorker("Emote", 0.3, function()
		return Flags.AutoEmote
	end, gacha.stepEmote)
	startWorker("UnlockSlots", 1, function()
		return Flags.AutoUnlockSlots
	end, gacha.stepUnlockSlots)
	API.Track(function()
		Flags.AutoJoin = false
		Flags.AutoMilestones = false
		Flags.AutoDaily = false
		Flags.AutoQuests = false
		Flags.AutoSummon = false
		Flags.AutoTrait = false
		Flags.AutoEmote = false
		Flags.AutoUnlockSlots = false
		Flags.AutoCraft = false
		Flags.AutoSkillTree = false
		Flags.AutoEvolve = false
		Flags.AutoDelivery = false
		Flags.AutoBestAccessory = false
		Flags.AutoBestTitle = false
		Flags.AutoRarestCharacters = false
		Flags.AutoAchievements = false
		Flags.AutoRedeemCodes = false
		Flags.AutoSkipTutorial = false
	end)
end

local PlayerApi = {}
local walkSnapshots = setmetatable({}, { __mode = "k" })
local noclipSnapshots = setmetatable({}, { __mode = "k" })
local promptSnapshots = setmetatable({}, { __mode = "k" })
local fpsSnapshots = setmetatable({}, { __mode = "k" })
local flyState = {
	connection = nil,
	humanoid = nil,
	priorPlatformStand = nil,
}
local infJumpConnection = nil
local noclipConnection = nil
local promptConnection = nil
local fpsConnection = nil
PlayerApi.perf = {
	ultra = setmetatable({}, { __mode = "k" }),
	ultraConnection = nil,
	ultraGlobal = nil,
	vfx = setmetatable({}, { __mode = "k" }),
	vfxConnections = {},
	anim = {},
}
local reconnectConnections = {}
local renderPrior = nil
local renderCover = nil

function PlayerApi.setWalkSpeedEnabled(value)
	Flags.WalkSpeedEnabled = value == true
	local _, _, humanoid = characterParts()
	if not humanoid then
		return
	end
	if Flags.WalkSpeedEnabled then
		if walkSnapshots[humanoid] == nil then
			walkSnapshots[humanoid] = humanoid.WalkSpeed
		end
		humanoid.WalkSpeed = Flags.WalkSpeed
	elseif walkSnapshots[humanoid] ~= nil then
		humanoid.WalkSpeed = walkSnapshots[humanoid]
		walkSnapshots[humanoid] = nil
	end
end

function PlayerApi.setWalkSpeed(value)
	Flags.WalkSpeed = value
	if Flags.WalkSpeedEnabled then
		local _, _, humanoid = characterParts()
		if humanoid then
			if walkSnapshots[humanoid] == nil then
				walkSnapshots[humanoid] = humanoid.WalkSpeed
			end
			humanoid.WalkSpeed = value
		end
	end
end

function PlayerApi.setInfJump(value)
	Flags.InfJump = value == true
	if infJumpConnection then
		infJumpConnection:Disconnect()
		infJumpConnection = nil
	end
	if not Flags.InfJump then
		return
	end
	infJumpConnection = UserInputService.JumpRequest:Connect(function()
		if API.Unloaded or not Flags.InfJump then
			return
		end
		local _, _, humanoid = characterParts()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
	API.Track(function()
		if infJumpConnection then
			infJumpConnection:Disconnect()
			infJumpConnection = nil
		end
	end)
end

local function applyNoclip(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if noclipSnapshots[part] == nil then
				noclipSnapshots[part] = part.CanCollide
			end
			part.CanCollide = false
		end
	end
end

local function restoreNoclip()
	for part, prior in pairs(noclipSnapshots) do
		if part.Parent then
			part.CanCollide = prior
		end
		noclipSnapshots[part] = nil
	end
end

function PlayerApi.setNoClip(value)
	Flags.NoClip = value == true
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	if not Flags.NoClip then
		restoreNoclip()
		return
	end
	local character = LocalPlayer.Character
	if character then
		applyNoclip(character)
	end
	noclipConnection = RunService.Stepped:Connect(function()
		if API.Unloaded or not Flags.NoClip then
			return
		end
		local live = LocalPlayer.Character
		if live then
			applyNoclip(live)
		end
	end)
	API.Track(function()
		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end
		restoreNoclip()
	end)
end

local function snapshotPrompt(prompt)
	if promptSnapshots[prompt] == nil then
		promptSnapshots[prompt] = {
			HoldDuration = prompt.HoldDuration,
			MaxActivationDistance = prompt.MaxActivationDistance,
			RequiresLineOfSight = prompt.RequiresLineOfSight,
		}
	end
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 50
	prompt.RequiresLineOfSight = false
end

local function restorePrompts()
	for prompt, prior in pairs(promptSnapshots) do
		if prompt.Parent then
			prompt.HoldDuration = prior.HoldDuration
			prompt.MaxActivationDistance = prior.MaxActivationDistance
			prompt.RequiresLineOfSight = prior.RequiresLineOfSight
		end
		promptSnapshots[prompt] = nil
	end
end

function PlayerApi.setInstantProximityPrompt(value)
	Flags.InstantProximityPrompt = value == true
	if promptConnection then
		promptConnection:Disconnect()
		promptConnection = nil
	end
	if not Flags.InstantProximityPrompt then
		restorePrompts()
		return
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") then
			snapshotPrompt(inst)
		end
	end
	promptConnection = Workspace.DescendantAdded:Connect(function(inst)
		if Flags.InstantProximityPrompt and inst:IsA("ProximityPrompt") then
			snapshotPrompt(inst)
		end
	end)
	API.Track(function()
		if promptConnection then
			promptConnection:Disconnect()
			promptConnection = nil
		end
		restorePrompts()
	end)
end

local function stopFly()
	if flyState.connection then
		flyState.connection:Disconnect()
		flyState.connection = nil
	end
	if flyState.humanoid and flyState.humanoid.Parent and flyState.priorPlatformStand ~= nil then
		flyState.humanoid.PlatformStand = flyState.priorPlatformStand
	end
	flyState.humanoid = nil
	flyState.priorPlatformStand = nil
	local _, root = characterParts()
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function PlayerApi.setFly(value)
	Flags.Fly = value == true
	stopFly()
	if not Flags.Fly then
		return
	end
	local _, root, humanoid = characterParts()
	if not (root and humanoid) then
		return
	end
	flyState.humanoid = humanoid
	flyState.priorPlatformStand = humanoid.PlatformStand
	humanoid.PlatformStand = true
	flyState.connection = RunService.RenderStepped:Connect(function()
		if API.Unloaded or not Flags.Fly then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local _, liveRoot, liveHumanoid = characterParts()
		if not (liveRoot and liveHumanoid) then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move -= camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move += Vector3.yAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			move -= Vector3.yAxis
		end
		if move.Magnitude > 0 then
			liveRoot.AssemblyLinearVelocity = move.Unit * Flags.FlySpeed
		else
			liveRoot.AssemblyLinearVelocity = Vector3.zero
		end
		liveHumanoid.PlatformStand = true
	end)
	API.Track(stopFly)
end

function PlayerApi.setFlySpeed(value)
	Flags.FlySpeed = value
end

local antiPauseGen = 0

function PlayerApi.setNoGameplayPaused(value)
	Flags.AntiGameplayPause = value == true
	antiPauseGen += 1
	local gen = antiPauseGen
	if not Flags.AntiGameplayPause then
		return
	end
	task.spawn(function()
		while not API.Unloaded and Flags.AntiGameplayPause and gen == antiPauseGen do
			pcall(function()
				GuiService:ClearError()
			end)
			local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
			if playerGui then
				local pause = playerGui:FindFirstChild("GameplayPaused")
				if pause and pause:IsA("GuiObject") then
					pause.Enabled = false
				end
			end
			task.wait(1)
		end
	end)
end

function PlayerApi.setAutoReconnect(value)
	Flags.AutoReconnect = value == true
	for _, conn in ipairs(reconnectConnections) do
		conn:Disconnect()
	end
	table.clear(reconnectConnections)
	if not Flags.AutoReconnect then
		return
	end
	local attemptToken = 0
	local function reconnect()
		if API.Unloaded or not Flags.AutoReconnect then
			return
		end
		attemptToken += 1
		local token = attemptToken
		task.spawn(function()
			task.wait(1.5)
			if API.Unloaded or not Flags.AutoReconnect or token ~= attemptToken then
				return
			end
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end)
			task.wait(4)
			if API.Unloaded or not Flags.AutoReconnect or token ~= attemptToken then
				return
			end
			pcall(function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end)
		end)
	end
	table.insert(reconnectConnections, GuiService.ErrorMessageChanged:Connect(function()
		if Flags.AutoReconnect then
			reconnect()
		end
	end))
	table.insert(reconnectConnections, TeleportService.TeleportInitFailed:Connect(function(player)
		if player == LocalPlayer and Flags.AutoReconnect then
			reconnect()
		end
	end))
	API.Track(function()
		for _, conn in ipairs(reconnectConnections) do
			conn:Disconnect()
		end
		table.clear(reconnectConnections)
	end)
end

function PlayerApi.setDisable3D(value)
	Flags.Disable3DRendering = value == true
	if Flags.Disable3DRendering then
		if renderPrior == nil and typeof(RunService.Set3dRenderingEnabled) == "function" then
			renderPrior = true
		end
		pcall(function()
			RunService:Set3dRenderingEnabled(false)
		end)
		if not renderCover then
			local gui = Instance.new("ScreenGui")
			gui.Name = "RelwxRenderCover"
			gui.IgnoreGuiInset = true
			gui.DisplayOrder = -100
			gui.ResetOnSpawn = false
			local frame = Instance.new("Frame")
			frame.BackgroundColor3 = Color3.new(0, 0, 0)
			frame.Size = UDim2.fromScale(1, 1)
			frame.BorderSizePixel = 0
			frame.Parent = gui
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
			renderCover = gui
			API.Track(function()
				if renderCover then
					renderCover:Destroy()
					renderCover = nil
				end
			end)
		end
	else
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
		if renderCover then
			renderCover:Destroy()
			renderCover = nil
		end
	end
end

local FPS_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
}

local function softenEffect(inst)
	if fpsSnapshots[inst] ~= nil then
		return
	end
	if FPS_CLASSES[inst.ClassName] then
		fpsSnapshots[inst] = { kind = "enabled", value = inst.Enabled }
		inst.Enabled = false
	end
end

function PlayerApi.setFpsBoost(value)
	Flags.FpsBoost = value == true
	if fpsConnection then
		fpsConnection:Disconnect()
		fpsConnection = nil
	end
	if not Flags.FpsBoost then
		for inst, prior in pairs(fpsSnapshots) do
			if inst.Parent and prior.kind == "enabled" then
				inst.Enabled = prior.value
			end
			fpsSnapshots[inst] = nil
		end
		if fpsSnapshots.lighting then
			local prior = fpsSnapshots.lighting
			Lighting.GlobalShadows = prior.GlobalShadows
			Lighting.FogEnd = prior.FogEnd
			fpsSnapshots.lighting = nil
		end
		return
	end
	fpsSnapshots.lighting = {
		GlobalShadows = Lighting.GlobalShadows,
		FogEnd = Lighting.FogEnd,
	}
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 1e6
	local scanned = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		softenEffect(inst)
		scanned += 1
		if scanned >= 4000 then
			break
		end
	end
	fpsConnection = Workspace.DescendantAdded:Connect(function(inst)
		if Flags.FpsBoost then
			softenEffect(inst)
		end
	end)
	API.Track(function()
		if fpsConnection then
			fpsConnection:Disconnect()
			fpsConnection = nil
		end
	end)
end

function PlayerApi.perf.ultraSoften(inst)
	local snaps = PlayerApi.perf.ultra
	if snaps[inst] ~= nil then
		return
	end
	if inst:IsA("BasePart") then
		snaps[inst] = { Material = inst.Material, CastShadow = inst.CastShadow, Reflectance = inst.Reflectance }
		inst.Material = Enum.Material.SmoothPlastic
		inst.CastShadow = false
		inst.Reflectance = 0
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		snaps[inst] = { Transparency = inst.Transparency }
		inst.Transparency = 1
	elseif FPS_CLASSES[inst.ClassName] or inst:IsA("Light") then
		snaps[inst] = { Enabled = inst.Enabled }
		inst.Enabled = false
	end
end

function PlayerApi.perf.restoreSnapshots(snaps)
	for inst, prior in pairs(snaps) do
		if typeof(inst) == "Instance" and inst.Parent then
			for prop, value in pairs(prior) do
				pcall(function()
					inst[prop] = value
				end)
			end
		end
		snaps[inst] = nil
	end
end

function PlayerApi.setUltraFpsBoost(value)
	Flags.UltraFpsBoost = value == true
	if PlayerApi.perf.ultraConnection then
		PlayerApi.perf.ultraConnection:Disconnect()
		PlayerApi.perf.ultraConnection = nil
	end
	if not Flags.UltraFpsBoost then
		PlayerApi.perf.restoreSnapshots(PlayerApi.perf.ultra)
		local prior = PlayerApi.perf.ultraGlobal
		PlayerApi.perf.ultraGlobal = nil
		if prior then
			pcall(function()
				settings().Rendering.QualityLevel = prior.QualityLevel
			end)
			local terrain = Workspace.Terrain
			terrain.WaterWaveSize = prior.WaterWaveSize
			terrain.WaterReflectance = prior.WaterReflectance
			Lighting.GlobalShadows = prior.GlobalShadows
			for effect, enabled in pairs(prior.post) do
				if effect.Parent then
					effect.Enabled = enabled
				end
			end
		end
		return
	end
	if not PlayerApi.perf.ultraGlobal then
		local terrain = Workspace.Terrain
		local prior = {
			WaterWaveSize = terrain.WaterWaveSize,
			WaterReflectance = terrain.WaterReflectance,
			GlobalShadows = Lighting.GlobalShadows,
			post = {},
		}
		pcall(function()
			prior.QualityLevel = settings().Rendering.QualityLevel
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		PlayerApi.perf.ultraGlobal = prior
		terrain.WaterWaveSize = 0
		terrain.WaterReflectance = 0
		Lighting.GlobalShadows = false
		for _, effect in ipairs(Lighting:GetDescendants()) do
			if effect:IsA("PostEffect") then
				prior.post[effect] = effect.Enabled
				effect.Enabled = false
			end
		end
	end
	PlayerApi.perf.ultraConnection = Workspace.DescendantAdded:Connect(function(inst)
		if Flags.UltraFpsBoost then
			PlayerApi.perf.ultraSoften(inst)
		end
	end)
	API.Track(function()
		if PlayerApi.perf.ultraConnection then
			PlayerApi.perf.ultraConnection:Disconnect()
			PlayerApi.perf.ultraConnection = nil
		end
	end)
	task.spawn(function()
		for index, inst in ipairs(Workspace:GetDescendants()) do
			if not Flags.UltraFpsBoost then
				return
			end
			PlayerApi.perf.ultraSoften(inst)
			if index % 1000 == 0 then
				task.wait()
			end
		end
	end)
end

PlayerApi.perf.VFX_FOLDERS = { "effects", "_effects" }

function PlayerApi.perf.hideSkillVfx(inst)
	local snaps = PlayerApi.perf.vfx
	if snaps[inst] ~= nil or inst.Name == "aoeIndicator" or inst:FindFirstAncestor("aoeIndicator") then
		return
	end
	if inst:IsA("BillboardGui") or inst:FindFirstAncestorWhichIsA("BillboardGui") then
		return
	end
	if inst:IsA("ParticleEmitter") then
		snaps[inst] = { Enabled = inst.Enabled, Transparency = inst.Transparency }
		inst.Enabled = false
		inst.Transparency = NumberSequence.new(1)
		inst:Clear()
	elseif FPS_CLASSES[inst.ClassName] or inst:IsA("Light") then
		snaps[inst] = { Enabled = inst.Enabled }
		inst.Enabled = false
	elseif inst:IsA("BasePart") then
		snaps[inst] = { LocalTransparencyModifier = inst.LocalTransparencyModifier }
		inst.LocalTransparencyModifier = 1
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		snaps[inst] = { Transparency = inst.Transparency }
		inst.Transparency = 1
	end
end

function PlayerApi.setDisableSkillVfx(value)
	Flags.DisableSkillVfx = value == true
	for _, connection in ipairs(PlayerApi.perf.vfxConnections) do
		connection:Disconnect()
	end
	table.clear(PlayerApi.perf.vfxConnections)
	if not Flags.DisableSkillVfx then
		PlayerApi.perf.restoreSnapshots(PlayerApi.perf.vfx)
		return
	end
	for _, name in ipairs(PlayerApi.perf.VFX_FOLDERS) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, inst in ipairs(folder:GetDescendants()) do
				PlayerApi.perf.hideSkillVfx(inst)
			end
			table.insert(PlayerApi.perf.vfxConnections, folder.DescendantAdded:Connect(function(inst)
				if Flags.DisableSkillVfx then
					PlayerApi.perf.hideSkillVfx(inst)
				end
			end))
		end
	end
	API.Track(function()
		for _, connection in ipairs(PlayerApi.perf.vfxConnections) do
			connection:Disconnect()
		end
		table.clear(PlayerApi.perf.vfxConnections)
	end)
end

function PlayerApi.perf.freezeAnimator(animator)
	if PlayerApi.perf.anim[animator] then
		return
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end
	PlayerApi.perf.anim[animator] = animator.AnimationPlayed:Connect(function(track)
		if Flags.DisablePlayerAnimations then
			track:Stop(0)
		end
	end)
end

function PlayerApi.perf.freezeCharacter(character)
	if not character then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	if animator and Flags.DisablePlayerAnimations then
		PlayerApi.perf.freezeAnimator(animator)
	end
end

function PlayerApi.perf.watchPlayerAnimations(player)
	task.spawn(PlayerApi.perf.freezeCharacter, player.Character)
	PlayerApi.perf.anim[player] = player.CharacterAdded:Connect(function(character)
		if Flags.DisablePlayerAnimations then
			PlayerApi.perf.freezeCharacter(character)
		end
	end)
end

function PlayerApi.perf.releaseAnimations()
	for key, connection in pairs(PlayerApi.perf.anim) do
		connection:Disconnect()
		PlayerApi.perf.anim[key] = nil
	end
end

function PlayerApi.setDisablePlayerAnimations(value)
	Flags.DisablePlayerAnimations = value == true
	PlayerApi.perf.releaseAnimations()
	if not Flags.DisablePlayerAnimations then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerApi.perf.watchPlayerAnimations(player)
	end
	PlayerApi.perf.anim.playerAdded = Players.PlayerAdded:Connect(PlayerApi.perf.watchPlayerAnimations)
	API.Track(PlayerApi.perf.releaseAnimations)
end

local COMBAT_CURSOR_BIND = "RelwxDisableCombatCursor"

function PlayerApi.setDisableCombatCursor(value)
	Flags.DisableCombatCursor = value == true
	pcall(RunService.UnbindFromRenderStep, RunService, COMBAT_CURSOR_BIND)
	if Flags.DisableCombatCursor then
		RunService:BindToRenderStep(COMBAT_CURSOR_BIND, Enum.RenderPriority.Last.Value + 1, function()
			local crosshair = LocalPlayer.PlayerGui:FindFirstChild("Crosshair")
			if crosshair and crosshair:IsA("ScreenGui") and crosshair.Enabled then
				crosshair.Enabled = false
			end
			UserInputService.MouseIconEnabled = true
		end)
		API.Track(function()
			pcall(RunService.UnbindFromRenderStep, RunService, COMBAT_CURSOR_BIND)
			local crosshair = LocalPlayer.PlayerGui:FindFirstChild("Crosshair")
			if crosshair and crosshair:IsA("ScreenGui") then
				crosshair.Enabled = true
			end
		end)
	else
		local crosshair = LocalPlayer.PlayerGui:FindFirstChild("Crosshair")
		if crosshair and crosshair:IsA("ScreenGui") then
			crosshair.Enabled = true
		end
	end
end

local MenuApi = {}
local antiAfkConnection = nil
local antiAfkGen = 0

function MenuApi.setAntiAfk(value)
	Flags.AntiAfk = value == true
	antiAfkGen += 1
	local gen = antiAfkGen
	if antiAfkConnection then
		antiAfkConnection:Disconnect()
		antiAfkConnection = nil
	end
	if not Flags.AntiAfk then
		return
	end
	antiAfkConnection = LocalPlayer.Idled:Connect(function()
		if API.Unloaded or not Flags.AntiAfk then
			return
		end
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
	task.spawn(function()
		while not API.Unloaded and Flags.AntiAfk and gen == antiAfkGen do
			task.wait(60)
			if API.Unloaded or not Flags.AntiAfk or gen ~= antiAfkGen then
				break
			end
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end)
	API.Track(function()
		if antiAfkConnection then
			antiAfkConnection:Disconnect()
			antiAfkConnection = nil
		end
		antiAfkGen += 1
	end)
end

do
	local characterConn = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.2)
		if API.Unloaded then
			return
		end
		if Flags.WalkSpeedEnabled then
			PlayerApi.setWalkSpeedEnabled(true)
		end
		if Flags.NoClip then
			PlayerApi.setNoClip(true)
		end
		if Flags.Fly then
			PlayerApi.setFly(true)
		end
	end)
	API.Track(function()
		characterConn:Disconnect()
	end)
end

local VisualApi = {
	supported = type(Drawing) == "table" and type(Drawing.new) == "function",
	cfg = {
		EspMobs = false,
		EspPlayers = false,
		EspNpcs = false,
		EspDelivery = false,
		EspBoxes = true,
		EspNames = true,
		EspDistance = true,
		EspHealth = true,
		EspTracers = false,
		EspChams = false,
		EspMobColor = Color3.fromRGB(255, 120, 50),
		EspBossColor = Color3.fromRGB(255, 205, 70),
		EspPlayerColor = Color3.fromRGB(120, 255, 150),
		EspNpcColor = Color3.fromRGB(0, 210, 255),
		EspDeliveryColor = Color3.fromRGB(255, 200, 0),
		FullBright = false,
		CustomFov = false,
		Fov = 90,
	},
	pool = {},
	chams = {},
	maxHealth = {},
	connection = nil,
	lighting = nil,
	fovPrior = nil,
}

function VisualApi.drawing(kind, props)
	local object = Drawing.new(kind)
	for key, value in pairs(props) do
		object[key] = value
	end
	return object
end

function VisualApi.entry(key)
	local entry = VisualApi.pool[key]
	if entry then
		return entry
	end
	local draw = VisualApi.drawing
	entry = {
		box = draw("Square", { Thickness = 1, Filled = false, Visible = false }),
		text = draw("Text", { Size = 14, Center = true, Outline = true, Visible = false }),
		tracer = draw("Line", { Thickness = 1, Visible = false }),
		barBack = draw("Line", { Thickness = 4, Color = Color3.new(0, 0, 0), Visible = false }),
		bar = draw("Line", { Thickness = 2, Visible = false }),
	}
	VisualApi.pool[key] = entry
	return entry
end

function VisualApi.hideEntry(entry)
	for _, object in pairs(entry) do
		object.Visible = false
	end
end

function VisualApi.removeEntry(key)
	local entry = VisualApi.pool[key]
	if not entry then
		return
	end
	VisualApi.pool[key] = nil
	for _, object in pairs(entry) do
		pcall(object.Remove, object)
	end
end

function VisualApi.setCham(key, model, color)
	local highlight = VisualApi.chams[key]
	if not model then
		if highlight then
			VisualApi.chams[key] = nil
			highlight:Destroy()
		end
		return
	end
	if not highlight or highlight.Adornee ~= model or not highlight.Parent then
		if highlight then
			highlight:Destroy()
		end
		highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillTransparency = 0.6
		highlight.OutlineTransparency = 0
		highlight.Adornee = model
		highlight.Parent = (gethui and gethui()) or game:GetService("CoreGui")
		VisualApi.chams[key] = highlight
	end
	highlight.FillColor = color
	highlight.OutlineColor = color
end

function VisualApi.collect(origin)
	local cfg = VisualApi.cfg
	local targets = {}
	if cfg.EspMobs and IN_RUN and EnemyStore then
		local ok, all = pcall(function()
			return EnemyStore.store.state:getAll()
		end)
		if ok and type(all) == "table" then
			for id, enemy in pairs(all) do
				local health = enemy.health:get()
				if health > 0 then
					local name = enemy.name:get()
					local info = Enemies.enemiesByName[name]
					local key = "mob:" .. tostring(id)
					local maxHealth = math.max(VisualApi.maxHealth[key] or 0, health, info and tonumber(info.baseHealth) or 0)
					VisualApi.maxHealth[key] = maxHealth
					local boss = info ~= nil and info.boss == true
					local height = info and tonumber(info.height) or 6
					local position = enemy.position:get()
					table.insert(targets, {
						key = key,
						label = (info and info.displayName) or name,
						top = position + Vector3.new(0, height / 2, 0),
						bottom = position - Vector3.new(0, height / 2, 0),
						position = position,
						health = health,
						maxHealth = maxHealth,
						color = if boss then cfg.EspBossColor else cfg.EspMobColor,
					})
				end
			end
		end
	end
	local function addModel(key, model, label, color)
		local root = model:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		table.insert(targets, {
			key = key,
			model = model,
			label = label,
			top = root.Position + Vector3.new(0, 3, 0),
			bottom = root.Position - Vector3.new(0, 3, 0),
			position = root.Position,
			health = humanoid and humanoid.Health,
			maxHealth = humanoid and humanoid.MaxHealth,
			color = color,
		})
	end
	if cfg.EspPlayers then
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if player ~= LocalPlayer and character then
				addModel("player:" .. player.UserId, character, player.DisplayName, cfg.EspPlayerColor)
			end
		end
	end
	local deliveryRoot
	if cfg.EspDelivery and IN_LOBBY and gacha.delivery and gacha.delivery.target then
		deliveryRoot = gacha.deliveryNpc(tostring(gacha.delivery.target))
		if deliveryRoot and deliveryRoot.Parent then
			addModel("delivery", deliveryRoot.Parent, "Deliver: " .. deliveryRoot.Parent.Name, cfg.EspDeliveryColor)
		end
	end
	if cfg.EspNpcs and IN_LOBBY then
		local systems = Workspace:FindFirstChild("Systems")
		for _, folderName in ipairs({ "NPCS", "ScatteredNPCS" }) do
			local folder = systems and systems:FindFirstChild(folderName)
			if folder then
				for _, model in ipairs(folder:GetChildren()) do
					if model:IsA("Model") and not (deliveryRoot and deliveryRoot.Parent == model) then
						addModel("npc:" .. model:GetFullName(), model, model.Name, cfg.EspNpcColor)
					end
				end
			end
		end
	end
	return targets
end

function VisualApi.render()
	local cfg = VisualApi.cfg
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local _, root = characterParts()
	local origin = root and root.Position or camera.CFrame.Position
	local seen = {}
	local viewport = camera.ViewportSize
	for _, target in ipairs(VisualApi.collect(origin)) do
		seen[target.key] = true
		local entry = VisualApi.entry(target.key)
		local top, topOn = camera:WorldToViewportPoint(target.top)
		local bottom, bottomOn = camera:WorldToViewportPoint(target.bottom)
		VisualApi.setCham(target.key, cfg.EspChams and target.model or nil, target.color)
		if not (topOn or bottomOn) or top.Z <= 0 then
			VisualApi.hideEntry(entry)
		else
			local height = math.max(math.abs(bottom.Y - top.Y), 6)
			local width = height * 0.6
			local x = (top.X + bottom.X) / 2 - width / 2
			local y = math.min(top.Y, bottom.Y)
			entry.box.Visible = cfg.EspBoxes
			entry.box.Position = Vector2.new(x, y)
			entry.box.Size = Vector2.new(width, height)
			entry.box.Color = target.color
			local parts = {}
			if cfg.EspNames then
				table.insert(parts, target.label)
			end
			if cfg.EspDistance then
				table.insert(parts, "[" .. math.floor((target.position - origin).Magnitude) .. "m]")
			end
			if cfg.EspHealth and target.health and not (target.maxHealth and target.maxHealth > 0) then
				table.insert(parts, formatNumber(math.floor(target.health)) .. " HP")
			end
			entry.text.Visible = #parts > 0
			entry.text.Text = table.concat(parts, " ")
			entry.text.Position = Vector2.new(x + width / 2, y - 16)
			entry.text.Color = target.color
			local showBar = cfg.EspHealth and target.health ~= nil and target.maxHealth ~= nil and target.maxHealth > 0
			entry.barBack.Visible = showBar
			entry.bar.Visible = showBar
			if showBar then
				local fraction = math.clamp(target.health / target.maxHealth, 0, 1)
				local barX = x - 5
				entry.barBack.From = Vector2.new(barX, y + height + 1)
				entry.barBack.To = Vector2.new(barX, y - 1)
				entry.bar.From = Vector2.new(barX, y + height)
				entry.bar.To = Vector2.new(barX, y + height - height * fraction)
				entry.bar.Color = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(80, 255, 100), fraction)
			end
			entry.tracer.Visible = cfg.EspTracers
			entry.tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
			entry.tracer.To = Vector2.new(x + width / 2, y + height)
			entry.tracer.Color = target.color
		end
	end
	for key in pairs(VisualApi.pool) do
		if not seen[key] then
			VisualApi.removeEntry(key)
			VisualApi.maxHealth[key] = nil
		end
	end
	for key in pairs(VisualApi.chams) do
		if not seen[key] then
			VisualApi.setCham(key, nil)
		end
	end
	if cfg.CustomFov then
		camera.FieldOfView = cfg.Fov
	end
end

function VisualApi.clear()
	for key in pairs(VisualApi.pool) do
		VisualApi.removeEntry(key)
	end
	for key in pairs(VisualApi.chams) do
		VisualApi.setCham(key, nil)
	end
	table.clear(VisualApi.maxHealth)
end

function VisualApi.refresh()
	local cfg = VisualApi.cfg
	local espOn = VisualApi.supported and (cfg.EspMobs or cfg.EspPlayers or cfg.EspNpcs or cfg.EspDelivery)
	local active = espOn or cfg.CustomFov
	if not espOn then
		VisualApi.clear()
	end
	if active and not VisualApi.connection and not API.Unloaded then
		VisualApi.connection = RunService.RenderStepped:Connect(function()
			local ok, err = pcall(VisualApi.render)
			if not ok then
				warn("Visuals: " .. tostring(err))
			end
		end)
	elseif not active and VisualApi.connection then
		VisualApi.connection:Disconnect()
		VisualApi.connection = nil
	end
end

function VisualApi.set(key, value)
	VisualApi.cfg[key] = value
	VisualApi.refresh()
end

function VisualApi.setCustomFov(value)
	local camera = Workspace.CurrentCamera
	if value and not VisualApi.cfg.CustomFov and camera then
		VisualApi.fovPrior = camera.FieldOfView
	end
	VisualApi.cfg.CustomFov = value == true
	if not VisualApi.cfg.CustomFov and VisualApi.fovPrior and camera then
		camera.FieldOfView = VisualApi.fovPrior
		VisualApi.fovPrior = nil
	end
	VisualApi.refresh()
end

VisualApi.BRIGHT = {
	Ambient = Color3.new(1, 1, 1),
	OutdoorAmbient = Color3.new(1, 1, 1),
	Brightness = 2,
	ClockTime = 14,
	FogEnd = 1e6,
	GlobalShadows = false,
}

function VisualApi.setFullBright(value)
	VisualApi.cfg.FullBright = value == true
	if VisualApi.lightConn then
		VisualApi.lightConn:Disconnect()
		VisualApi.lightConn = nil
	end
	if VisualApi.cfg.FullBright then
		if not VisualApi.lighting then
			VisualApi.lighting = {}
			for key in pairs(VisualApi.BRIGHT) do
				VisualApi.lighting[key] = Lighting[key]
			end
		end
		local function apply()
			for key, value2 in pairs(VisualApi.BRIGHT) do
				if Lighting[key] ~= value2 then
					Lighting[key] = value2
				end
			end
		end
		apply()
		VisualApi.lightConn = Lighting.Changed:Connect(function()
			if VisualApi.cfg.FullBright and not API.Unloaded then
				apply()
			end
		end)
	elseif VisualApi.lighting then
		for key, value2 in pairs(VisualApi.lighting) do
			pcall(function()
				Lighting[key] = value2
			end)
		end
		VisualApi.lighting = nil
	end
end

API.Track(function()
	if VisualApi.connection then
		VisualApi.connection:Disconnect()
		VisualApi.connection = nil
	end
	VisualApi.clear()
	VisualApi.setCustomFov(false)
	VisualApi.setFullBright(false)
end)

VisualApi.streamer = {
	alias = "Relwx",
	originals = setmetatable({}, { __mode = "k" }),
	watched = setmetatable({}, { __mode = "k" }),
	connections = {},
	humanoidName = nil,
}

function VisualApi.streamerNames()
	local names = { LocalPlayer.Name, LocalPlayer.DisplayName, "@" .. LocalPlayer.Name }
	table.sort(names, function(a, b)
		return #a > #b
	end)
	return names
end

function VisualApi.maskText(text)
	local alias = VisualApi.streamer.alias
	for _, name in ipairs(VisualApi.streamerNames()) do
		if name ~= "" then
			local escaped = string.gsub(name, "%p", "%%%0")
			text = string.gsub(text, escaped, alias)
		end
	end
	text = string.gsub(text, tostring(LocalPlayer.UserId), alias)
	return text
end

function VisualApi.maskObject(object)
	if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		return
	end
	local state = VisualApi.streamer
	local function apply()
		if not VisualApi.cfg.StreamerMode then
			return
		end
		local text = object.Text
		local masked = VisualApi.maskText(text)
		if masked ~= text then
			state.originals[object] = text
			object.Text = masked
		end
	end
	if not state.watched[object] then
		state.watched[object] = object:GetPropertyChangedSignal("Text"):Connect(apply)
	end
	apply()
end

function VisualApi.maskCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.DisplayName ~= VisualApi.streamer.alias then
		VisualApi.streamer.humanoidName = VisualApi.streamer.humanoidName or { humanoid = humanoid, value = humanoid.DisplayName }
		humanoid.DisplayName = VisualApi.streamer.alias
	end
end

function VisualApi.setStreamerMode(value)
	VisualApi.cfg.StreamerMode = value == true
	local state = VisualApi.streamer
	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end
	table.clear(state.connections)
	local roots = { LocalPlayer:FindFirstChildOfClass("PlayerGui"), Workspace }
	pcall(function()
		table.insert(roots, game:GetService("CoreGui"))
	end)
	if type(gethui) == "function" then
		pcall(function()
			table.insert(roots, gethui())
		end)
	end
	if VisualApi.cfg.StreamerMode and not API.Unloaded then
		for _, root in ipairs(roots) do
			pcall(function()
				for _, object in ipairs(root:GetDescendants()) do
					VisualApi.maskObject(object)
				end
				table.insert(state.connections, root.DescendantAdded:Connect(function(object)
					VisualApi.maskObject(object)
				end))
			end)
		end
		VisualApi.maskCharacter(LocalPlayer.Character)
		table.insert(state.connections, LocalPlayer.CharacterAdded:Connect(function(character)
			state.humanoidName = nil
			character:WaitForChild("Humanoid", 10)
			if VisualApi.cfg.StreamerMode then
				VisualApi.maskCharacter(character)
			end
		end))
		return
	end
	for object, connection in pairs(state.watched) do
		connection:Disconnect()
		state.watched[object] = nil
	end
	for object, text in pairs(state.originals) do
		pcall(function()
			if object.Parent then
				object.Text = text
			end
		end)
		state.originals[object] = nil
	end
	if state.humanoidName then
		pcall(function()
			state.humanoidName.humanoid.DisplayName = state.humanoidName.value
		end)
		state.humanoidName = nil
	end
end

API.Track(function()
	VisualApi.setStreamerMode(false)
end)

function VisualApi.buildTab(tab)
	local Esp = tab:AddLeftGroupbox({ Name = "ESP", Icon = "eye" })
	local function toggle(box, name, key)
		box:CreateToggle({
			Name = name,
			CurrentValue = VisualApi.cfg[key],
			Flag = key,
			Callback = function(value)
				VisualApi.set(key, value == true)
			end,
		})
	end
	local function color(box, name, key)
		box:CreateColorPicker({
			Name = name,
			Default = VisualApi.cfg[key],
			Flag = key,
			Callback = function(value)
				if typeof(value) == "Color3" then
					VisualApi.cfg[key] = value
				end
			end,
		})
	end
	Esp:CreateStatus({
		Name = "Drawing",
		Style = "Row",
		UpdateRate = 5,
		Update = function()
			if VisualApi.supported then
				return nil
			end
			return "Executor has no Drawing library", "Error"
		end,
	})
	toggle(Esp, "Mob ESP", "EspMobs")
	color(Esp, "Mob colour", "EspMobColor")
	color(Esp, "Boss colour", "EspBossColor")
	toggle(Esp, "Player ESP", "EspPlayers")
	color(Esp, "Player colour", "EspPlayerColor")
	toggle(Esp, "NPC ESP", "EspNpcs")
	color(Esp, "NPC colour", "EspNpcColor")
	toggle(Esp, "Delivery Target ESP", "EspDelivery")
	color(Esp, "Delivery colour", "EspDeliveryColor")
	Esp:CreateDivider()
	for _, pair in ipairs({ { "Boxes", "EspBoxes" }, { "Names", "EspNames" }, { "Distance", "EspDistance" }, { "Health", "EspHealth" }, { "Tracers", "EspTracers" }, { "Chams", "EspChams" } }) do
		toggle(Esp, pair[1], pair[2])
	end

	local Graphics = tab:AddRightGroupbox({ Name = "Graphics", Icon = "sun" })
	Graphics:CreateToggle({
		Name = "Full Bright",
		CurrentValue = false,
		Flag = "FullBright",
		Callback = function(value)
			VisualApi.setFullBright(value == true)
		end,
	})
	Graphics:CreateToggle({
		Name = "Custom FOV",
		CurrentValue = false,
		Flag = "CustomFov",
		Callback = function(value)
			VisualApi.setCustomFov(value == true)
		end,
	})
	Graphics:CreateSlider({
		Name = "FOV",
		Range = { 30, 120 },
		Increment = 1,
		CurrentValue = VisualApi.cfg.Fov,
		Flag = "Fov",
		Callback = function(value)
			VisualApi.cfg.Fov = tonumber(value) or VisualApi.cfg.Fov
		end,
	})

	local Privacy = tab:AddRightGroupbox({ Name = "Privacy", Icon = "eye-off" })
	Privacy:CreateToggle({
		Name = "Streamer Mode",
		CurrentValue = true,
		Flag = "StreamerMode",
		Callback = function(value)
			VisualApi.setStreamerMode(value == true)
		end,
	})
end

function VisualApi.sync(readFlag)
	local cfg = VisualApi.cfg
	for _, key in ipairs({ "EspMobs", "EspPlayers", "EspNpcs", "EspDelivery", "EspBoxes", "EspNames", "EspDistance", "EspHealth", "EspTracers", "EspChams" }) do
		local value = readFlag(key, cfg[key])
		if type(value) == "boolean" then
			cfg[key] = value
		end
	end
	for _, key in ipairs({ "EspMobColor", "EspBossColor", "EspPlayerColor", "EspNpcColor", "EspDeliveryColor" }) do
		local value = readFlag(key, nil)
		if typeof(value) == "Color3" then
			cfg[key] = value
		end
	end
	cfg.Fov = tonumber(readFlag("Fov", cfg.Fov)) or cfg.Fov
	VisualApi.setFullBright(readFlag("FullBright", false) == true)
	VisualApi.setCustomFov(readFlag("CustomFov", false) == true)
	VisualApi.setStreamerMode(readFlag("StreamerMode", true) == true)
	VisualApi.refresh()
end

local RelwxUI = createRelwxUI()
local Library = RelwxUI

do -- KAITUN: force the automation defaults into Config BEFORE the tabs read it
	local K = gacha.K
	local cfg = RelwxUI.Config
	if K.Mode and type(cfg) == "table" then
		for _, key in ipairs(K.On) do
			if not K.Skip[key] then
				cfg[key] = true
			end
		end
		cfg.JoinChapter = "Highest Unlocked"
		if not GAMEMODE_CHOICES[cfg.JoinChoice] and #GAMEMODE_LABELS > 0 then
			local pick = GAMEMODE_LABELS[1]
			for _, label in ipairs(GAMEMODE_LABELS) do
				if string.sub(label, 1, 8) == "Story - " then
					pick = label
					break
				end
			end
			cfg.JoinChoice = pick
		end
		if not K.Skip.AutoTrait then
			if K.TraitStopRarity and gacha.TRAIT_RARITY_RANK[K.TraitStopRarity] then
				cfg.TraitStopRarity = K.TraitStopRarity
			elseif #gacha.TRAIT_RARITY_OPTIONS > 1 then
				cfg.TraitStopRarity = gacha.TRAIT_RARITY_OPTIONS[#gacha.TRAIT_RARITY_OPTIONS]
			end
		end
		if not K.Skip.AutoSkillTree then
			if #CHARACTER_IDS > 0 then
				cfg.SkillTreeCharacters = table.clone(CHARACTER_IDS)
			end
			if #BRANCH_LABELS > 0 then
				cfg.SkillTreeBranches = table.clone(BRANCH_LABELS)
			end
		end
		cfg.LeaveMinutes = math.clamp(tonumber(K.LeaveMinutes) or 20, 1, 60)
		cfg.EmoteStopAllOwned = true
	end
end
local Window = {
    Destroy = function() RelwxUI.Destroy(); API.Unload() end,
    Toggle = function(_, visible) RelwxUI.Toggle(RelwxUI, visible) end,
    SetKeybind = function(_, key) RelwxUI.SetKeybind(RelwxUI, key) end,
    SetToggleButtonPlatform = function(_, platform) RelwxUI.SetToggleButtonPlatform(RelwxUI, platform) end,
    LoadAutoload = function() end,
}
attachUI(API, Window)

local Main = RelwxUI.CreateTab("ฟาร์ม", "gamepad-2")
local Lobby = RelwxUI.CreateTab("เข้าห้อง", "target")
local Gacha = RelwxUI.CreateTab("สุ่ม/ตัวละคร", "sparkles")
local Prog = RelwxUI.CreateTab("พัฒนา", "trending-up")
local Player = RelwxUI.CreateTab("ผู้เล่น", "user")
VisualApi.tab = RelwxUI.CreateTab("ภาพ/ESP", "eye")
local Webhook = RelwxUI.CreateTab("แจ้งเตือน", "bell")
local Settings = RelwxUI.CreateTab("ตั้งค่า", "settings")

local function idsFromLabels(options)
	if type(options) == "string" then
		options = { options }
	end
	local ids = {}
	for _, label in ipairs(options or {}) do
		local id = MATERIAL_BY_LABEL[label]
		if id then
			table.insert(ids, id)
		end
	end
	return ids
end

local function slotsFromOptions(options)
	local slots = {}
	if type(options) == "string" then
		options = { options }
	end
	for _, label in ipairs(options or {}) do
		local slot = SKILL_SLOT[label]
		if slot then
			table.insert(slots, slot)
		end
	end
	table.sort(slots)
	return slots
end

local function firstOption(option)
	return if type(option) == "table" then option[1] else option
end

local function listFromOptions(options)
	if type(options) == "string" then
		return { options }
	end
	local list = {}
	for _, value in ipairs(options or {}) do
		table.insert(list, value)
	end
	return list
end

local function traitIdsFromLabels(options)
	local ids = {}
	for _, label in ipairs(listFromOptions(options)) do
		local id = TRAIT_BY_LABEL[label]
		if id then
			table.insert(ids, id)
		end
	end
	return ids
end

local function liveRunRows()
	local rows = {}
	local function add(text, value, tone)
		table.insert(rows, { Text = text, Value = tostring(value), Tone = tone or "Muted" })
	end
	local ok = pcall(function()
		local state = runState()
		local participant = myParticipant()
		local _, _, humanoid = characterParts()
		local store = PlayerNamespace.getLocalPlayerStore()
		local activity, tone = "Idle", "Muted"
		if not (participant and participant.status:get() == "active") then
			activity = if participant then participant.status:get() else "Waiting"
		elseif runtime.retreating then
			activity, tone = "Retreating", "Warning"
		elseif runtime.dodging then
			activity, tone = "Dodging Igris", "Warning"
		elseif Flags.AutoFarm and runtime.target then
			activity, tone = "Farming", "Success"
		elseif Flags.AutoFarm then
			activity, tone = "Searching", "Accent"
		end
		add("Status", activity, tone)
		add("Map", tostring(Maps.currentMap) .. " | " .. tostring(workspace:GetAttribute("Mode") or "-"), "Accent")
		add("Chapter", tostring(state.chapter:get()) .. " | " .. tostring(state.difficulty:get()))
		add("Area", string.format("%s/%s", tostring(state.area:get()), tostring(state.areaCount:get())))
		add("Wave", string.format("%d/%d (%d left)", state.wave:get(), state.waveCount:get(), state.remaining:get()))
		local startedAt = state.startedAt:get()
		add("Run Time", if startedAt then formatTime(Workspace:GetServerTimeNow() - startedAt) else "-")
		if humanoid then
			local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1) * 100
			add("Health", string.format("%d%%", math.floor(ratio)), if ratio <= Flags.RetreatHealth then "Error" else "Success")
		end
		if store then
			add("Character", tostring(store.state.character:get()), "Accent")
			local now = Workspace:GetServerTimeNow()
			local parts = {}
			for slot = 1, 3 do
				local cooldown = runtime.skillCooldown(store, slot)
				local till = cooldown and cooldown:get()
				table.insert(parts, if till and till > now then string.format("%.1fs", till - now) else "Ready")
			end
			add("Skills", table.concat(parts, " | "))
		end
		if participant then
			add("Kills", formatNumber(participant.kills:get()))
			add("Damage", formatNumber(participant.damage:get()))
			add("Lives", participant.lives:get())
			add("Money", formatNumber(participant.earned:get() + participant.bonus:get()))
			add("Gems", formatNumber(participant.gems:get()))
			add("XP", formatNumber(participant.xp:get()))
		end
		local enemy = runtime.target and EnemyStore.store.state:get(runtime.target)
		if enemy then
			local info = Enemies.enemiesByName[enemy.name:get()]
			add("Target", string.format("%s (%d/%d)", info and info.displayName or enemy.name:get(), enemy.health:get(), enemy.maxHealth:get()), "Accent")
		else
			add("Target", "-")
		end
		if Flags.Failsafe then
			local idle = runtime.idleSince and os.clock() - runtime.idleSince or 0
			local left = Flags.FailsafeSeconds - idle
			if not runtime.idleSince then
				add("Failsafe", "Waiting")
			elseif left > 0 then
				add("Failsafe", string.format("%ds", math.ceil(left)), "Warning")
			else
				add("Failsafe", if Flags.FailsafeMode == "Leave Run" then "Leaving" else "Scanning", "Error")
			end
		end
		add("Record", string.format("%dW / %dL", Stats.wins, Stats.losses))
	end)
	if not ok then
		return { { Text = "Run info", Value = "unavailable", Tone = "Muted" } }
	end
	return rows
end

local function buildMainTab()
	local FarmPage = Main:CreateSubTab({ Name = "Farm", Icon = "swords" })
	local RunPage = Main:CreateSubTab({ Name = "Active Run", Icon = "repeat" })

	local Farm = FarmPage:AddLeftGroupbox({ Name = "Auto Farm", Icon = "swords" })
	Farm:CreateToggle({
		Name = "Auto Farm",
		CurrentValue = false,
		Flag = "AutoFarm",
		Callback = function(value)
			Flags.AutoFarm = value == true
			if not Flags.AutoFarm then
				releasePose()
			end
		end,
	})
	Farm:CreateToggle({
		Name = "Auto Arise",
		CurrentValue = false,
		Flag = "AutoArise",
		Callback = function(value)
			Flags.AutoArise = value == true
			if not Flags.AutoArise and not Flags.AutoFarm then
				releasePose()
			end
		end,
	})
	Farm:CreateDropdown({
		Name = "Target",
		Options = TARGET_MODES,
		CurrentOption = "Nearest",
		AllowNone = false,
		Flag = "TargetMode",
		Callback = function(option)
			local selected = firstOption(option)
			if table.find(TARGET_MODES, selected) then
				Flags.TargetMode = selected
				runtime.target = nil
				runtime.refreshPose()
			end
		end,
	})
	Farm:CreateDropdown({
		Name = "Position",
		Options = FARM_MODES,
		CurrentOption = "Front",
		AllowNone = false,
		Flag = "FarmMode",
		Callback = function(option)
			local selected = if type(option) == "table" then option[1] else option
			if table.find(FARM_MODES, selected) then
				Flags.FarmMode = selected
				runtime.refreshPose()
			end
		end,
	})
	Farm:CreateSlider({
		Name = "Distance",
		Range = { 2, 12 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = 5,
		Flag = "AttackDistance",
		Callback = function(value)
			Flags.AttackDistance = value
			runtime.refreshPose()
		end,
	})
	Farm:CreateSlider({
		Name = "Height",
		Range = { 3, 25 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = 8,
		Flag = "HeightOffset",
		Callback = function(value)
			Flags.HeightOffset = value
			runtime.refreshPose()
		end,
	})
	Farm:CreateSlider({
		Name = "Tween Speed",
		Range = { 40, 400 },
		Increment = 10,
		Suffix = " studs/s",
		CurrentValue = 150,
		Flag = "MoveSpeed",
		Callback = function(value)
			Flags.MoveSpeed = value
			runtime.refreshPose()
		end,
	})
	Farm:CreateSlider({
		Name = "Orbit Speed",
		Range = { 30, 720 },
		Increment = 10,
		Suffix = " deg/s",
		CurrentValue = 180,
		Flag = "OrbitSpeed",
		Callback = function(value)
			Flags.OrbitSpeed = value
		end,
	})

	local Combat = FarmPage:AddRightGroupbox({ Name = "Combat", Icon = "zap" })
	Combat:CreateToggle({
		Name = "Auto Skills",
		CurrentValue = false,
		Flag = "AutoSkill",
		Callback = function(value)
			Flags.AutoSkill = value == true
		end,
	})
	Combat:CreateDropdown({
		Name = "Skills",
		Options = SKILL_LABELS,
		MultipleOptions = true,
		CurrentOption = { "Skill 1", "Skill 2", "Skill 3" },
		Flag = "SkillChoice",
		Callback = function(options)
			Flags.SkillSlots = slotsFromOptions(options)
		end,
	})
	Combat:CreateToggle({
		Name = "Ultimate On Bosses Only",
		CurrentValue = false,
		Flag = "UltBossOnly",
		Callback = function(value)
			Flags.UltBossOnly = value == true
		end,
	})
	Combat:CreateToggle({
		Name = "Prioritize Ultimate On Bosses",
		CurrentValue = false,
		Flag = "UltBossPriority",
		Callback = function(value)
			Flags.UltBossPriority = value == true
		end,
	})
	Combat:CreateToggle({
		Name = "[Beta]Auto Dodge Igris",
		CurrentValue = false,
		Flag = "AutoDodgeIgris",
		Callback = function(value)
			Flags.AutoDodgeIgris = value == true
			if not Flags.AutoDodgeIgris and runtime.dodging then
				runtime.dodging = false
				releasePose()
			end
		end,
	})
	Combat:CreateToggle({
		Name = "Switch Character On Cooldown",
		CurrentValue = false,
		Flag = "SwitchOnCooldown",
		Callback = function(value)
			Flags.SwitchOnCooldown = value == true
		end,
	})
	Combat:CreateDropdown({
		Name = "Switch Logic",
		Options = { "Consider Ultimates", "Don't Consider Ultimates" },
		CurrentOption = "Don't Consider Ultimates",
		AllowNone = false,
		Flag = "SwitchUltMode",
		Callback = function(option)
			local selected = firstOption(option)
			if selected == "Consider Ultimates" or selected == "Don't Consider Ultimates" then
				Flags.SwitchUltMode = selected
			end
		end,
	})
	Combat:CreateToggle({
		Name = "Retreat To Heal",
		CurrentValue = false,
		Flag = "AutoRetreat",
		Callback = function(value)
			Flags.AutoRetreat = value == true
			if not Flags.AutoRetreat then
				runtime.retreating = false
				releasePose()
			end
		end,
	})
	Combat:CreateSlider({
		Name = "Retreat Below HP",
		Range = { 5, 90 },
		Increment = 1,
		Suffix = " %",
		CurrentValue = 30,
		Flag = "RetreatHealth",
		Callback = function(value)
			Flags.RetreatHealth = value
		end,
	})
	Combat:CreateSlider({
		Name = "Back To Fight At HP",
		Range = { 10, 100 },
		Increment = 1,
		Suffix = " %",
		CurrentValue = 70,
		Flag = "RetreatResume",
		Callback = function(value)
			Flags.RetreatResume = value
		end,
	})

	local SkillOptions = FarmPage:AddRightGroupbox({ Name = "Skill Options", Icon = "sliders-horizontal", Collapsed = true })
	SkillOptions:CreateSlider({
		Name = "Cast Range",
		Range = { 5, 80 },
		Increment = 1,
		Suffix = " studs",
		CurrentValue = 25,
		Flag = "SkillRange",
		Callback = function(value)
			Flags.SkillRange = value
		end,
	})
	SkillOptions:CreateSlider({
		Name = "Min Enemies In Range",
		Range = { 1, 10 },
		Increment = 1,
		CurrentValue = 1,
		Flag = "SkillMinEnemies",
		Callback = function(value)
			Flags.SkillMinEnemies = value
		end,
	})
	SkillOptions:CreateToggle({
		Name = "Skill Combo",
		CurrentValue = false,
		Flag = "SkillCombo",
		Callback = function(value)
			Flags.SkillCombo = value == true
			runtime.comboIndex = 1
			runtime.comboSince = nil
		end,
	})
	SkillOptions:CreateInput({
		Name = "Combo Order",
		PlaceholderText = "1, 3, 2, U",
		CurrentValue = "1, 2, 3",
		Flag = "ComboOrder",
		Callback = function(value)
			Flags.ComboOrder = runtime.comboFromText(value)
			runtime.comboIndex = 1
			runtime.comboSince = nil
		end,
	})
	SkillOptions:CreateSlider({
		Name = "Combo Delay",
		Range = { 0, 3 },
		Increment = 0.1,
		Suffix = "s",
		CurrentValue = 0,
		Flag = "ComboDelay",
		Callback = function(value)
			Flags.ComboDelay = value
		end,
	})

	local Retreat = FarmPage:AddRightGroupbox({ Name = "Retreat Options", Icon = "shield", Collapsed = true })
	Retreat:CreateDropdown({
		Name = "Retreat Action",
		Options = RETREAT_ACTIONS,
		CurrentOption = "Fly Up",
		AllowNone = false,
		Flag = "RetreatAction",
		Callback = function(option)
			local selected = firstOption(option)
			if table.find(RETREAT_ACTIONS, selected) then
				Flags.RetreatAction = selected
			end
		end,
	})
	Retreat:CreateSlider({
		Name = "Retreat Height",
		Range = { 20, 150 },
		Increment = 5,
		Suffix = " studs",
		CurrentValue = 60,
		Flag = "RetreatHeight",
		Callback = function(value)
			Flags.RetreatHeight = value
		end,
	})
	Retreat:CreateSlider({
		Name = "Max Retreat Time",
		Range = { 3, 60 },
		Increment = 1,
		Suffix = " s",
		CurrentValue = 15,
		Flag = "RetreatMaxSeconds",
		Callback = function(value)
			Flags.RetreatMaxSeconds = value
		end,
	})

	local Failsafe = FarmPage:AddLeftGroupbox({ Name = "Failsafe", Icon = "wrench", Collapsed = true })
	Failsafe:CreateToggle({
		Name = "Failsafe",
		CurrentValue = false,
		Flag = "Failsafe",
		Callback = function(value)
			Flags.Failsafe = value == true
			runtime.idleSince = nil
		end,
	})
	Failsafe:CreateDropdown({
		Name = "Mode",
		Options = { "Move Across Area", "Leave Run" },
		CurrentOption = "Move Across Area",
		AllowNone = false,
		Flag = "FailsafeMode",
		Callback = function(option)
			local selected = firstOption(option)
			if selected == "Move Across Area" or selected == "Leave Run" then
				Flags.FailsafeMode = selected
			end
		end,
	})
	Failsafe:CreateSlider({
		Name = "No NPCs For",
		Range = { 5, 120 },
		Increment = 1,
		Suffix = "s",
		CurrentValue = 15,
		Flag = "FailsafeSeconds",
		Callback = function(value)
			Flags.FailsafeSeconds = value
		end,
	})
	Failsafe:CreateToggle({
		Name = "Scan Area Before Leave Run",
		CurrentValue = false,
		Flag = "FailsafeScanLeave",
		Callback = function(value)
			Flags.FailsafeScanLeave = value == true
		end,
	})

	local Status = RunPage:AddLeftGroupbox({ Name = "Run", Icon = "flag" })
	Status:CreateStatus({
		Name = "Run",
		Style = "Badge",
		UpdateRate = 0.5,
		Update = function()
			if not IN_RUN then
				return "in the lobby", "Warning"
			end
			local ok, participant = pcall(myParticipant)
			if not ok or not participant then
				return "waiting", "Muted"
			end
			local status = tostring(participant.status:get())
			return status, if status == "active" then "Success" elseif status == "victory" then "Accent" else "Error"
		end,
	})
	Status:CreateStatus({
		Name = "Area",
		Style = "Bar",
		UpdateRate = 0.5,
		Update = function()
			local ok, area, count = pcall(function()
				local state = runState()
				return tonumber(state.area:get()) or 0, tonumber(state.areaCount:get()) or 0
			end)
			if not ok then
				return 0, 1
			end
			return area, math.max(count, 1)
		end,
	})
	Status:CreateStatus({
		Name = "Wave",
		Style = "Row",
		Update = function()
			local ok, text = pcall(function()
				local state = runState()
				return string.format("%d/%d  (%d left)", state.wave:get(), state.waveCount:get(), state.remaining:get())
			end)
			return ok and text or "-"
		end,
	})

	local RunEnd = RunPage:AddRightGroupbox({ Name = "Run End", Icon = "repeat" })
	RunEnd:CreateToggle({
		Name = "Auto Next Chapter",
		CurrentValue = false,
		Flag = "AutoNextChapter",
		Callback = function(value)
			Flags.AutoNextChapter = value == true
		end,
	})
	RunEnd:CreateToggle({
		Name = "Auto Retry",
		CurrentValue = false,
		Flag = "AutoRetry",
		Callback = function(value)
			Flags.AutoRetry = value == true
		end,
	})
	RunEnd:CreateToggle({
		Name = "Auto Leave",
		CurrentValue = false,
		Flag = "AutoLeave",
		Callback = function(value)
			Flags.AutoLeave = value == true
		end,
	})
	RunEnd:CreateSlider({
		Name = "Delay",
		Range = { 0, 15 },
		Increment = 1,
		Suffix = " s",
		CurrentValue = 2,
		Flag = "ResultDelay",
		Callback = function(value)
			Flags.ResultDelay = value
		end,
	})
	RunEnd:CreateButton({
		Name = "Leave Run",
		Callback = function()
			if not IN_RUN or not pcall(myParticipant) then
				Library:Notify({ Title = "Leave Run", Content = "Not in a run", Duration = 3 })
				return
			end
			RunPackets.endAction:fire(LEAVE_ACTION)
		end,
	})

	local Stuck = RunPage:AddRightGroupbox({ Name = "Stuck Runs", Icon = "timer" })
	Stuck:CreateToggle({
		Name = "Leave Run After Time",
		CurrentValue = false,
		Flag = "AutoLeaveRun",
		Callback = function(value)
			Flags.AutoLeaveRun = value == true
		end,
	})
	Stuck:CreateSlider({
		Name = "Leave After",
		Range = { 1, 60 },
		Increment = 1,
		Suffix = " min",
		CurrentValue = 10,
		Flag = "LeaveMinutes",
		Callback = function(value)
			Flags.LeaveMinutes = value
		end,
	})
	Stuck:CreateToggle({
		Name = "Leave After Runs",
		CurrentValue = false,
		Flag = "AutoLeaveRuns",
		Callback = function(value)
			Flags.AutoLeaveRuns = value == true
		end,
	})
	Stuck:CreateSlider({
		Name = "Runs",
		Range = { 1, 50 },
		Increment = 1,
		CurrentValue = 5,
		Flag = "LeaveRuns",
		Callback = function(value)
			Flags.LeaveRuns = value
		end,
	})

	local Info = RunPage:AddLeftGroupbox({ Name = "Live Run Info", Icon = "activity", Collapsed = true })
	Info:CreateStatusList({
		Name = "Run",
		MaxRows = 18,
		EmptyText = "no active run",
		UpdateRate = 0.5,
		Update = liveRunRows,
	})
end

local function buildPlayerTab()
	local Movement = Player:AddLeftGroupbox({ Name = "Movement", Icon = "move" })
	Movement:CreateToggle({
		Name = "WalkSpeed",
		CurrentValue = false,
		Flag = "WalkSpeedEnabled",
		Callback = function(value)
			PlayerApi.setWalkSpeedEnabled(value)
		end,
	})
	Movement:CreateSlider({
		Name = "Speed",
		Range = { 16, 250 },
		Increment = 1,
		CurrentValue = 32,
		Flag = "WalkSpeed",
		Callback = function(value)
			PlayerApi.setWalkSpeed(value)
		end,
	})
	Movement:CreateToggle({
		Name = "Infinite Jump",
		CurrentValue = false,
		Flag = "InfJump",
		Callback = function(value)
			PlayerApi.setInfJump(value)
		end,
	})
	Movement:CreateToggle({
		Name = "Noclip",
		CurrentValue = true,
		Flag = "NoClip",
		Callback = function(value)
			PlayerApi.setNoClip(value)
		end,
	})
	Movement:CreateToggle({
		Name = "Instant ProximityPrompt",
		CurrentValue = false,
		Flag = "InstantProximityPrompt",
		Callback = function(value)
			PlayerApi.setInstantProximityPrompt(value)
		end,
	})

	local FlyBox = Player:AddRightGroupbox({ Name = "Fly", Icon = "plane" })
	FlyBox:CreateToggle({
		Name = "Fly",
		CurrentValue = false,
		Flag = "Fly",
		Callback = function(value)
			PlayerApi.setFly(value)
		end,
	})
	FlyBox:CreateSlider({
		Name = "Fly Speed",
		Range = { 10, 400 },
		Increment = 1,
		CurrentValue = 60,
		Flag = "FlySpeed",
		Callback = function(value)
			PlayerApi.setFlySpeed(value)
		end,
	})

	local Performance = Player:AddLeftGroupbox({ Name = "Performance", Icon = "monitor" })
	Performance:CreateToggle({
		Name = "Disable 3D Rendering",
		CurrentValue = false,
		Flag = "Disable3DRendering",
		Callback = function(value)
			PlayerApi.setDisable3D(value)
		end,
	})
	Performance:CreateToggle({
		Name = "FPS Boost",
		CurrentValue = false,
		Flag = "FpsBoost",
		Callback = function(value)
			PlayerApi.setFpsBoost(value)
		end,
	})
	Performance:CreateToggle({
		Name = "Ultra FPS Boost",
		CurrentValue = false,
		Flag = "UltraFpsBoost",
		Callback = function(value)
			PlayerApi.setUltraFpsBoost(value)
		end,
	})
	Performance:CreateToggle({
		Name = "Disable Skill VFX",
		CurrentValue = false,
		Flag = "DisableSkillVfx",
		Callback = function(value)
			PlayerApi.setDisableSkillVfx(value)
		end,
	})
	Performance:CreateToggle({
		Name = "Disable Player Animations",
		CurrentValue = false,
		Flag = "DisablePlayerAnimations",
		Callback = function(value)
			PlayerApi.setDisablePlayerAnimations(value)
		end,
	})
	Performance:CreateToggle({
		Name = "Disable Combat Cursor",
		CurrentValue = true,
		Flag = "DisableCombatCursor",
		Callback = function(value)
			PlayerApi.setDisableCombatCursor(value)
		end,
	})

	local Session = Player:AddRightGroupbox({ Name = "Session", Icon = "repeat" })
	Session:CreateToggle({
		Name = "No Gameplay Paused",
		CurrentValue = true,
		Flag = "AntiGameplayPause",
		Callback = function(value)
			PlayerApi.setNoGameplayPaused(value)
		end,
	})
	Session:CreateToggle({
		Name = "Auto Reconnect on Kick",
		CurrentValue = false,
		Flag = "AutoReconnect",
		Callback = function(value)
			PlayerApi.setAutoReconnect(value)
		end,
	})
	Session:CreateToggle({
		Name = "Hide UI On Start",
		CurrentValue = false,
		Flag = "HideUIOnStart",
		Callback = function() end,
	})
end

local function buildWebhookTab()
	local Hook = Webhook:AddLeftGroupbox({ Name = "Webhook", Icon = "webhook" })
	Hook:CreateInput({
		Name = "Webhook URL",
		PlaceholderText = "https://discord.com/api/webhooks/...",
		CurrentValue = "",
		Flag = "WebhookUrl",
		Callback = function(value)
			Flags.WebhookUrl = tostring(value or "")
		end,
	})
	Hook:CreateToggle({
		Name = "Run Results",
		CurrentValue = true,
		Flag = "WebhookResults",
		Callback = function(value)
			Flags.WebhookResults = value == true
		end,
	})
	Hook:CreateToggle({
		Name = "Roll Hits",
		CurrentValue = true,
		Flag = "WebhookRolls",
		Callback = function(value)
			Flags.WebhookRolls = value == true
		end,
	})
	Hook:CreateToggle({
		Name = "Kicked",
		CurrentValue = true,
		Flag = "WebhookKicked",
		Callback = function(value)
			Flags.WebhookKicked = value == true
		end,
	})
	Hook:CreateToggle({
		Name = "Hu Tao Drop",
		CurrentValue = true,
		Flag = "WebhookHuTao",
		Callback = function(value)
			Flags.WebhookHuTao = value == true
		end,
	})
	Hook:CreateButton({
		Name = "Send Test",
		Icon = "send",
		Callback = function()
			task.spawn(function()
				local sent = postWebhook(nil, { title = "✅ Webhook Connected", description = "Run results, pulls and disconnects will be posted here.", color = 5793266, fields = withTotals({}) })
				Library:Notify({
					Title = GAME_NAME,
					Content = if sent then "Webhook sent" else "Webhook failed: check URL and executor HTTP support",
					Type = if sent then "Success" else "Error",
					Duration = 4,
				})
			end)
		end,
	})

	local Ping = Webhook:AddRightGroupbox({ Name = "Ping On Drops", Icon = "bell" })
	Ping:CreateToggle({
		Name = "Ping On Drops",
		CurrentValue = false,
		Flag = "PingEnabled",
		Callback = function(value)
			Flags.PingEnabled = value == true
		end,
	})
	Ping:CreateInput({
		Name = "Discord User ID",
		PlaceholderText = "123456789012345678",
		CurrentValue = "",
		Flag = "PingUserId",
		Callback = function(value)
			Flags.PingUserId = tostring(value or "")
		end,
	})
	Ping:CreateDropdown({
		Name = "Materials",
		Options = MATERIAL_LABELS,
		MultipleOptions = true,
		CurrentOption = {},
		Flag = "PingMaterials",
		Callback = function(options)
			Flags.PingMaterials = idsFromLabels(options)
		end,
	})
	Ping:CreateDropdown({
		Name = "Ping At Tier Or Above",
		Options = MATERIAL_TIER_OPTIONS,
		CurrentOption = "Off",
		AllowNone = false,
		Flag = "PingMinTier",
		Callback = function(option)
			Flags.PingMinTier = tostring(firstOption(option))
		end,
	})

	local Totals = Webhook:AddLeftGroupbox({ Name = "Totals", Icon = "chart-line" })
	Totals:CreateStatusList({
		Name = "Totals",
		MaxRows = 8,
		EmptyText = "no data",
		UpdateRate = 1,
		Update = statsRows,
	})
	Totals:CreateButton({
		Name = "Reset Totals",
		Icon = "rotate-ccw",
		Callback = function()
			Library:Confirm({
				Title = "Reset totals?",
				ConfirmText = "Reset",
				Callback = resetStats,
			})
		end,
	})
end

local function buildSettingsTab()
	local Interface = Settings:AddLeftGroupbox({ Name = "Menu", Icon = "monitor" })
	Interface:CreateKeybind({
		Name = "Toggle UI",
		CurrentKeybind = "RightControl",
		Flag = "ToggleUIKey",
		Callback = function() end,
		OnChanged = function(key)
			Window:SetKeybind(key)
		end,
	})
	Interface:CreateDropdown({
		Name = "Toggle button",
		Options = { "Mobile only", "Mobile & PC" },
		CurrentOption = "Mobile only",
		AllowNone = false,
		Flag = "ToggleButtonPlatform",
		Callback = function(option)
			local selected = if type(option) == "table" then option[1] else option
			Window:SetToggleButtonPlatform(selected == "Mobile & PC" and "Both" or "Mobile")
		end,
	})
	Interface:CreateToggle({
		Name = "Anti AFK",
		CurrentValue = true,
		Flag = "AntiAfk",
		Callback = function(value)
			MenuApi.setAntiAfk(value)
		end,
	})
	Interface:CreateButton({
		Name = "Unload",
		Icon = "power",
		Callback = function()
			Library:Confirm({
				Title = "Unload?",
				ConfirmText = "Unload",
				Callback = function()
					Window:Destroy()
				end,
			})
		end,
	})
	Settings:CreateConfigManager({ Name = "Configs", Side = "Left" })
	Settings:CreateThemeManager({ Name = "Themes", Side = "Right" })
end

function gacha.walletAmount(currency)
	local snapshot = IN_LOBBY and accountSnapshot()
	return formatNumber(tonumber(snapshot and snapshot.currencies[currency]) or 0)
end

local function buildGachaTab()
	local Characters = Gacha:AddLeftGroupbox({ Name = "Characters", Icon = "user" })
	Characters:CreateToggle({
		Name = "Auto Roll Character",
		CurrentValue = false,
		Flag = "AutoSummon",
		Callback = function(value)
			Flags.AutoSummon = value == true
		end,
	})
	Characters:CreateDropdown({
		Name = "Slot",
		Options = { "1", "2", "3", "4" },
		CurrentOption = "1",
		AllowNone = false,
		Flag = "SummonSlot",
		Callback = function(option)
			Flags.SummonSlot = tonumber(firstOption(option)) or 1
		end,
	})
	Characters:CreateDropdown({
		Name = "Spin",
		Options = { "Normal", "Lucky" },
		CurrentOption = "Normal",
		AllowNone = false,
		Flag = "SummonType",
		Callback = function(option)
			local selected = firstOption(option)
			if selected == "Normal" or selected == "Lucky" then
				Flags.SummonType = selected
			end
		end,
	})
	Characters:CreateDropdown({
		Name = "Pay With (Normal)",
		Options = { "Money", "Rolls" },
		CurrentOption = "Money",
		AllowNone = false,
		Flag = "SummonPayment",
		Callback = function(option)
			Flags.SummonPayment = string.lower(tostring(firstOption(option)))
		end,
	})
	Characters:CreateDropdown({
		Name = "Stop On Character",
		Options = CHARACTER_IDS,
		MultipleOptions = true,
		CurrentOption = {},
		Flag = "SummonStopCharacters",
		Callback = function(options)
			Flags.SummonStopCharacters = listFromOptions(options)
		end,
	})
	Characters:CreateDropdown({
		Name = "Stop On Rarity Or Better",
		Options = RARITY_OPTIONS,
		CurrentOption = "Mythic",
		AllowNone = false,
		Flag = "ProtectRarity",
		Callback = function(option)
			Flags.ProtectRarity = firstOption(option)
		end,
	})
	Characters:CreateToggle({
		Name = "Favourite Hits",
		CurrentValue = false,
		Flag = "SummonFavourite",
		Callback = function(value)
			Flags.SummonFavourite = value == true
		end,
	})
	Characters:CreateToggle({
		Name = "Buy Lucky Spins With Gems",
		CurrentValue = false,
		Flag = "SummonBuyLucky",
		Callback = function(value)
			Flags.SummonBuyLucky = value == true
		end,
	})
	Characters:CreateSlider({
		Name = "Roll Delay",
		Range = { 1, 10 },
		Increment = 1,
		Suffix = " s",
		CurrentValue = 2,
		Flag = "SummonDelay",
		Callback = function(value)
			Flags.SummonDelay = value
		end,
	})
	Characters:CreateStatus({
		Name = "Session",
		Style = "Row",
		UpdateRate = 1,
		Update = function()
			return string.format("%d rolls  last %s", lobby.summonCount, lobby.summonLast)
		end,
	})
	Characters:CreateStatus({
		Name = "Wallet",
		Style = "Row",
		UpdateRate = 1,
		Update = function()
			if not IN_LOBBY then
				return "lobby only"
			end
			return string.format("$%s  dice %s  lucky %s  gems %s", gacha.walletAmount("money"), gacha.walletAmount("rolls"), gacha.walletAmount("luckySpins"), gacha.walletAmount("gems"))
		end,
	})

	local Slots = Gacha:AddLeftGroupbox({ Name = "Slots", Icon = "layout-grid" })
	Slots:CreateToggle({
		Name = "Auto Unlock Slots",
		CurrentValue = false,
		Flag = "AutoUnlockSlots",
		Callback = function(value)
			Flags.AutoUnlockSlots = value == true
		end,
	})
	Slots:CreateStatusList({
		Name = "Your Slots",
		MaxRows = 4,
		EmptyText = "lobby only",
		UpdateRate = 1,
		Update = function()
			local rows = {}
			local snapshot = IN_LOBBY and accountSnapshot()
			if not snapshot then
				return rows
			end
			for slot = 1, 4 do
				local data = snapshot.UnlockedCharacters["Slot" .. slot]
				if data and data.Unlocked == true and data.Character ~= "" then
					table.insert(rows, {
						Text = string.format("%d  %s%s", slot, characterName(data.Character), if data.Favourite then " ★" else ""),
						Value = tostring(RollConfig.rarityByCharacter[data.Character] or "?"),
						Tone = "Accent",
					})
				elseif data and data.Unlocked == true then
					table.insert(rows, { Text = slot .. "  empty", Value = "-", Tone = "Muted" })
				else
					local cost = EconomyConfig.characterSlotUnlockCosts[slot]
					table.insert(rows, { Text = slot .. "  locked", Value = if cost then "$" .. formatNumber(cost) else "-", Tone = "Muted" })
				end
			end
			return rows
		end,
	})

	local Traits = Gacha:AddRightGroupbox({ Name = "Traits", Icon = "dices" })
	Traits:CreateToggle({
		Name = "Auto Roll Trait",
		CurrentValue = false,
		Flag = "AutoTrait",
		Callback = function(value)
			Flags.AutoTrait = value == true
		end,
	})
	Traits:CreateDropdown({
		Name = "Character",
		Options = gacha.TRAIT_CHARACTER_OPTIONS,
		CurrentOption = "Equipped Character",
		AllowNone = false,
		Flag = "TraitCharacter",
		Callback = function(option)
			Flags.TraitCharacter = tostring(firstOption(option) or "Equipped Character")
		end,
	})
	Traits:CreateDropdown({
		Name = "Stop On Trait",
		Options = TRAIT_LABELS,
		CurrentOption = {},
		MultipleOptions = true,
		Flag = "TraitTargets",
		Callback = function(options)
			Flags.TraitTargets = traitIdsFromLabels(options)
		end,
	})
	Traits:CreateDropdown({
		Name = "Stop On Rarity Or Better",
		Options = gacha.TRAIT_RARITY_OPTIONS,
		CurrentOption = "None",
		AllowNone = false,
		Flag = "TraitStopRarity",
		Callback = function(option)
			Flags.TraitStopRarity = tostring(firstOption(option) or "None")
		end,
	})
	Traits:CreateSlider({
		Name = "Roll Delay",
		Range = { 0, 5 },
		Increment = 0.5,
		Suffix = " s",
		CurrentValue = 1,
		Flag = "TraitDelay",
		Callback = function(value)
			Flags.TraitDelay = value
		end,
	})
	Traits:CreateStatus({
		Name = "Session",
		Style = "Row",
		UpdateRate = 1,
		Update = function()
			return string.format("%d rerolls  last %s", lobby.traitCount, lobby.traitLast)
		end,
	})
	Traits:CreateStatus({
		Name = "Rerolls Left",
		Style = "Row",
		UpdateRate = 1,
		Update = function()
			return if IN_LOBBY then gacha.walletAmount("traitRerolls") else "lobby only"
		end,
	})

	local Emotes = Gacha:AddRightGroupbox({ Name = "Emotes", Icon = "heart" })
	Emotes:CreateToggle({
		Name = "Auto Roll Emote",
		CurrentValue = false,
		Flag = "AutoEmote",
		Callback = function(value)
			Flags.AutoEmote = value == true
		end,
	})
	Emotes:CreateDropdown({
		Name = "Stop On Emote",
		Options = gacha.EMOTE_NAMES,
		CurrentOption = {},
		MultipleOptions = true,
		Flag = "EmoteTargets",
		Callback = function(options)
			Flags.EmoteTargets = listFromOptions(options)
		end,
	})
	Emotes:CreateDropdown({
		Name = "Stop On Rarity Or Better",
		Options = gacha.EMOTE_RARITY_OPTIONS,
		CurrentOption = "None",
		AllowNone = false,
		Flag = "EmoteStopRarity",
		Callback = function(option)
			Flags.EmoteStopRarity = tostring(firstOption(option) or "None")
		end,
	})
	Emotes:CreateToggle({
		Name = "Stop When All Owned",
		CurrentValue = true,
		Flag = "EmoteStopAllOwned",
		Callback = function(value)
			Flags.EmoteStopAllOwned = value == true
		end,
	})
	Emotes:CreateStatus({
		Name = "Session",
		Style = "Row",
		UpdateRate = 1,
		Update = function()
			return string.format("%d rolls  last %s", lobby.emoteCount, lobby.emoteLast)
		end,
	})
end

local function buildLobbyTab()
	local Join = Lobby:AddLeftGroupbox({ Name = "Auto Join", Icon = "target" })
	Join:CreateToggle({
		Name = "Auto Join",
		CurrentValue = false,
		Flag = "AutoJoin",
		Callback = function(value)
			Flags.AutoJoin = value == true
			if not Flags.AutoJoin and lobby.queueStatus == "inQuque" then
				pcall(function()
					LobbyPackets.leaveQuque:fire()
				end)
			end
		end,
	})
	Join:CreateToggle({
		Name = "Auto Story Progression",
		CurrentValue = false,
		Flag = "JoinAuto",
		Callback = function(value)
			Flags.JoinAuto = value == true
		end,
	})
	Join:CreateDropdown({
		Name = "Mode",
		Options = GAMEMODE_LABELS,
		CurrentOption = GAMEMODE_LABELS[1],
		AllowNone = false,
		Flag = "JoinChoice",
		Callback = function(option)
			local selected = firstOption(option)
			if GAMEMODE_CHOICES[selected] then
				Flags.JoinChoice = selected
			end
		end,
	})
	Join:CreateDropdown({
		Name = "Chapter",
		Options = CHAPTER_LABELS,
		CurrentOption = CHAPTER_LABELS[1],
		AllowNone = false,
		Flag = "JoinChapter",
		Callback = function(option)
			local selected = firstOption(option)
			Flags.JoinChapter = if selected == "Highest Unlocked" then 0 else tonumber(selected) or 1
		end,
	})
	Join:CreateDropdown({
		Name = "Difficulty",
		Options = DIFFICULTY_LABELS,
		CurrentOption = Flags.JoinDifficulty,
		AllowNone = false,
		Flag = "JoinDifficulty",
		Callback = function(option)
			local selected = firstOption(option)
			if DIFFICULTY_INDEX[selected] then
				Flags.JoinDifficulty = selected
			end
		end,
	})
	Join:CreateSlider({
		Name = "Max Players",
		Range = { 1, 6 },
		Increment = 1,
		CurrentValue = 1,
		Flag = "JoinPlayers",
		Callback = function(value)
			Flags.JoinPlayers = value
		end,
	})
	Join:CreateToggle({
		Name = "Friends Only",
		CurrentValue = false,
		Flag = "JoinFriendsOnly",
		Callback = function(value)
			Flags.JoinFriendsOnly = value == true
		end,
	})
	Join:CreateSlider({
		Name = "Join Delay",
		Range = { 0, 60 },
		Increment = 1,
		Suffix = "s",
		CurrentValue = 5,
		Flag = "JoinDelay",
		Callback = function(value)
			Flags.JoinDelay = value
		end,
	})
	Join:CreateButton({
		Name = "Leave Queue",
		Callback = function()
			if not IN_LOBBY then
				return
			end
			pcall(function()
				LobbyPackets.leaveQuque:fire()
			end)
		end,
	})

	local Delivery = Lobby:AddRightGroupbox({ Name = "Auto Delivery", Icon = "package" })
	Delivery:CreateToggle({
		Name = "Auto Delivery",
		CurrentValue = false,
		Flag = "AutoDelivery",
		Callback = function(value)
			Flags.AutoDelivery = value == true
		end,
	})
	Delivery:CreateStatus({
		Name = "เช็คเควสส่งของรายวัน",
		Style = "Bar",
		UpdateRate = 1,
		Update = function()
			return math.min(getDeliveryQuestCount(), 50), 50
		end,
	})
	Delivery:CreateStatus({
		Name = "สถานะเควส 50 ครั้ง",
		Style = "Row",
		UpdateRate = 1,
		Update = function()
			local count = getDeliveryQuestCount()
			if count >= 50 then
				return "สำเร็จแล้ว (50/50)"
			end
			if not Flags.AutoDelivery then
				return string.format("ปิด Auto Delivery • %d/50", count)
			end
			return string.format("เหลืออีก %d ครั้ง (%d/50)", math.max(0, 50 - count), count)
		end,
	})
end

function gacha.buildProgTab()
	local function toggle(box, name, flag, default)
		box:CreateToggle({
			Name = name,
			CurrentValue = default == true,
			Flag = flag,
			Callback = function(value)
				Flags[flag] = value == true
			end,
		})
	end

	local Tree = Prog:AddLeftGroupbox({ Name = "Skill Tree", Icon = "git-branch" })
	toggle(Tree, "Auto Skill Tree", "AutoSkillTree")
	Tree:CreateDropdown({
		Name = "Characters",
		Options = CHARACTER_IDS,
		CurrentOption = {},
		MultipleOptions = true,
		Flag = "SkillTreeCharacters",
		Callback = function(options)
			Flags.SkillTreeCharacters = listFromOptions(options)
		end,
	})
	Tree:CreateDropdown({
		Name = "Branches",
		Options = BRANCH_LABELS,
		CurrentOption = BRANCH_LABELS,
		MultipleOptions = true,
		Flag = "SkillTreeBranches",
		Callback = function(options)
			Flags.SkillTreeBranches = listFromOptions(options)
		end,
	})
	Tree:CreateSlider({
		Name = "Max Tier",
		Range = { 2, 5 },
		Increment = 1,
		CurrentValue = 5,
		Flag = "SkillTreeMaxTier",
		Callback = function(value)
			Flags.SkillTreeMaxTier = value
		end,
	})

	local Evolve = Prog:AddLeftGroupbox({ Name = "Evolve", Icon = "rocket" })
	toggle(Evolve, "Auto Evolve Equipped", "AutoEvolve")

	local Craft = Prog:AddLeftGroupbox({ Name = "Craft", Icon = "hammer" })
	toggle(Craft, "Auto Craft Accessories", "AutoCraft")
	Craft:CreateDropdown({
		Name = "Accessories (none = all)",
		Options = CRAFT_LABELS,
		CurrentOption = {},
		MultipleOptions = true,
		Flag = "CraftItems",
		Callback = function(options)
			Flags.CraftItems = listFromOptions(options)
		end,
	})
	Craft:CreateSlider({
		Name = "Craft Until Owned",
		Range = { 1, 20 },
		Increment = 1,
		CurrentValue = 1,
		Flag = "CraftTarget",
		Callback = function(value)
			Flags.CraftTarget = value
		end,
	})

	local Gear = Prog:AddRightGroupbox({ Name = "Best Gear", Icon = "crown" })
	toggle(Gear, "Equip Best Accessory", "AutoBestAccessory")
	toggle(Gear, "Equip Best Title", "AutoBestTitle")
	Gear:CreateDropdown({
		Name = "Best By",
		Options = gacha.BEST_STATS,
		CurrentOption = "Damage",
		AllowNone = false,
		Flag = "BestGearStat",
		Callback = function(option)
			local selected = firstOption(option)
			if table.find(gacha.BEST_STATS, selected) then
				Flags.BestGearStat = selected
			end
		end,
	})
	toggle(Gear, "Equip Rarest Characters", "AutoRarestCharacters")

	local Rewards = Prog:AddRightGroupbox({ Name = "Rewards", Icon = "gift" })
	toggle(Rewards, "Auto Daily Reward", "AutoDaily")
	toggle(Rewards, "Auto Claim Quests", "AutoQuests")
	toggle(Rewards, "Auto Claim Achievements", "AutoAchievements")
	toggle(Rewards, "Auto Claim Milestones", "AutoMilestones")
	toggle(Rewards, "Auto Redeem Codes", "AutoRedeemCodes")
	toggle(Rewards, "Auto Skip Tutorial", "AutoSkipTutorial")
	Rewards:CreateButton({
		Name = "Redeem All Codes",
		Callback = function()
			if not IN_LOBBY then
				Library:Notify({ Title = GAME_NAME, Content = "Redeem codes from the lobby", Type = "Warning", Duration = 4 })
				return
			end
			redeemAllCodes(function(sent, total)
				Library:Notify({
					Title = GAME_NAME,
					Content = string.format("Sent %d of %d codes", sent, total),
					Type = "Success",
					Duration = 4,
				})
			end)
		end,
	})
end

buildMainTab()
buildLobbyTab()
buildGachaTab()
gacha.buildProgTab()
buildPlayerTab()
VisualApi.buildTab(VisualApi.tab)
buildWebhookTab()
buildSettingsTab()

do
	local function readFlag(name, default)
		local entry = Library.Flags and Library.Flags[name]
		if entry == nil then
			return default
		end
		if type(entry) == "table" then
			if type(entry.Get) == "function" then
				local ok, value = pcall(entry.Get, entry)
				if ok and value ~= nil then
					return value
				end
			end
			if entry.Value ~= nil then
				return entry.Value
			end
			return default
		end
		return entry
	end

	local function syncFlags()
		for _, name in ipairs({ "AutoFarm", "AutoArise", "AutoSkill", "AutoNextChapter", "AutoRetry", "AutoLeave", "AutoLeaveRun", "AutoJoin", "JoinAuto", "JoinFriendsOnly", "AutoDelivery", "AutoMilestones", "AutoDaily", "AutoQuests", "AutoSummon", "AutoTrait", "AutoEmote", "AutoUnlockSlots", "SummonFavourite", "SummonBuyLucky", "AutoCraft", "AutoSkillTree", "AutoEvolve", "AutoBestAccessory", "AutoBestTitle", "AutoRarestCharacters", "AutoAchievements", "AutoRedeemCodes", "AutoSkipTutorial", "AutoRetreat", "SwitchOnCooldown", "SkillCombo", "PingEnabled", "UltBossPriority", "AutoLeaveRuns", "AutoDodgeIgris" }) do
			Flags[name] = readFlag(name, false) == true
		end
		for _, name in ipairs({ "WebhookResults", "WebhookRolls", "WebhookKicked", "WebhookHuTao" }) do
			Flags[name] = readFlag(name, true) == true
		end
		for _, name in ipairs({ "WebhookUrl", "PingUserId" }) do
			local value = readFlag(name, "")
			if type(value) == "string" then
				Flags[name] = value
			end
		end
		Flags.PingMaterials = idsFromLabels(readFlag("PingMaterials", {}))
		local pingTier = firstOption(readFlag("PingMinTier", "Off"))
		if table.find(MATERIAL_TIER_OPTIONS, tostring(pingTier)) then
			Flags.PingMinTier = tostring(pingTier)
		end
		local targetMode = firstOption(readFlag("TargetMode", nil))
		if table.find(TARGET_MODES, targetMode) then
			Flags.TargetMode = targetMode
		end
		local switchUltMode = firstOption(readFlag("SwitchUltMode", nil))
		if switchUltMode == "Consider Ultimates" or switchUltMode == "Don't Consider Ultimates" then
			Flags.SwitchUltMode = switchUltMode
		end
		local retreatAction = firstOption(readFlag("RetreatAction", nil))
		if table.find(RETREAT_ACTIONS, retreatAction) then
			Flags.RetreatAction = retreatAction
		end
		for _, name in ipairs({ "RetreatHealth", "RetreatResume", "RetreatHeight", "RetreatMaxSeconds", "JoinPlayers", "JoinDelay", "SummonSlot", "SummonDelay", "TraitDelay", "CraftTarget", "SkillTreeMaxTier", "MoveSpeed", "AttackDistance", "HeightOffset", "OrbitSpeed", "SkillRange", "SkillMinEnemies", "ComboDelay", "ResultDelay", "LeaveMinutes", "LeaveRuns" }) do
			local value = tonumber(readFlag(name, Flags[name]))
			if value then
				Flags[name] = value
			end
		end
		local mode = readFlag("FarmMode", nil)
		if type(mode) == "table" then
			mode = mode[1]
		end
		if table.find(FARM_MODES, mode) then
			Flags.FarmMode = mode
		end
		do
			local joinChoice = readFlag("JoinChoice", nil)
			if type(joinChoice) == "table" then
				joinChoice = joinChoice[1]
			end
			if GAMEMODE_CHOICES[joinChoice] then
				Flags.JoinChoice = joinChoice
			end
			local chapter = readFlag("JoinChapter", nil)
			if type(chapter) == "table" then
				chapter = chapter[1]
			end
			Flags.JoinChapter = if chapter == "Highest Unlocked" then 0 else tonumber(chapter) or Flags.JoinChapter
			local joinDifficulty = readFlag("JoinDifficulty", nil)
			if type(joinDifficulty) == "table" then
				joinDifficulty = joinDifficulty[1]
			end
			if DIFFICULTY_INDEX[joinDifficulty] then
				Flags.JoinDifficulty = joinDifficulty
			end
			local spinType = readFlag("SummonType", nil)
			if type(spinType) == "table" then
				spinType = spinType[1]
			end
			if spinType == "Normal" or spinType == "Lucky" then
				Flags.SummonType = spinType
			end
			local payment = readFlag("SummonPayment", nil)
			if type(payment) == "table" then
				payment = payment[1]
			end
			if payment then
				Flags.SummonPayment = string.lower(tostring(payment))
			end
			local slot = readFlag("SummonSlot", nil)
			if type(slot) == "table" then
				slot = slot[1]
			end
			Flags.SummonSlot = tonumber(slot) or Flags.SummonSlot
			local protect = readFlag("ProtectRarity", nil)
			if type(protect) == "table" then
				protect = protect[1]
			end
			if protect then
				Flags.ProtectRarity = protect
			end
			local traitCharacter = firstOption(readFlag("TraitCharacter", nil))
			if table.find(gacha.TRAIT_CHARACTER_OPTIONS, traitCharacter) then
				Flags.TraitCharacter = traitCharacter
			end
			Flags.TraitTargets = traitIdsFromLabels(readFlag("TraitTargets", {}))
			Flags.SummonStopCharacters = listFromOptions(readFlag("SummonStopCharacters", {}))
			local bestStat = firstOption(readFlag("BestGearStat", nil))
			if table.find(gacha.BEST_STATS, bestStat) then
				Flags.BestGearStat = bestStat
			end
			Flags.EmoteTargets = listFromOptions(readFlag("EmoteTargets", {}))
			Flags.EmoteStopAllOwned = readFlag("EmoteStopAllOwned", true) == true
			local traitRarity = firstOption(readFlag("TraitStopRarity", "None"))
			if gacha.TRAIT_RARITY_RANK[traitRarity] then
				Flags.TraitStopRarity = traitRarity
			end
			local emoteRarity = firstOption(readFlag("EmoteStopRarity", "None"))
			if gacha.EMOTE_RARITY_RANK[emoteRarity] then
				Flags.EmoteStopRarity = emoteRarity
			end
			Flags.CraftItems = listFromOptions(readFlag("CraftItems", {}))
			Flags.SkillTreeCharacters = listFromOptions(readFlag("SkillTreeCharacters", {}))
			Flags.SkillTreeBranches = listFromOptions(readFlag("SkillTreeBranches", BRANCH_LABELS))
		end
		local comboOrder = readFlag("ComboOrder", nil)
		if type(comboOrder) == "string" then
			Flags.ComboOrder = runtime.comboFromText(comboOrder)
		end
		local choice = readFlag("SkillChoice", nil)
		if choice ~= nil then
			Flags.SkillSlots = slotsFromOptions(choice)
		end
	end

	PlayerApi.setNoGameplayPaused(true)
	MenuApi.setAntiAfk(true)

	Window:LoadAutoload()
	syncFlags()
	VisualApi.sync(readFlag)
	PlayerApi.setDisableCombatCursor(readFlag("DisableCombatCursor", true) == true)

	if Library.Flags.HideUIOnStart == true then
		Window:Toggle(false)
	end
end

-- ===================== KAITUN: persistence + self-check =====================
do
	local K = gacha.K
	if K.Mode then
		task.spawn(function()
			local armed = false
			pcall(function()
				if not hasQueueOnTeleport then
					return
				end
				local loader = K.Loader
				if not loader and typeof(isfile) == "function" and isfile(K.SelfFile) then
					loader = 'loadstring(readfile("' .. K.SelfFile .. '"))()'
				end
				if loader then
					queue_on_teleport(loader)
					armed = true
				end
			end)
			task.wait(6)
			local off = {}
			for _, key in ipairs(K.On) do
				if not K.Skip[key] and Flags[key] ~= true then
					table.insert(off, key)
				end
			end
			local where = IN_LOBBY and "lobby" or "run"
			print(string.format("[%s] Kaitun (%s): %d/%d automations active%s", GAME_NAME, where, #K.On - #off, #K.On,
				#off > 0 and (" | not active: " .. table.concat(off, ", ")) or ""))
			if not armed then
				warn("[" .. GAME_NAME .. "] Kaitun: this script will NOT restart after a queue teleport. Save it as '"
					.. K.SelfFile .. "' in your executor workspace folder (or use autoexec), or set gacha.K.Loader.")
			end
			pcall(function()
				Library:Notify({
					Title = GAME_NAME,
					Content = string.format("Kaitun on (%s): %d/%d automations active%s", where, #K.On - #off, #K.On,
						armed and "" or " | restart-after-teleport NOT armed"),
					Type = #off == 0 and "Success" or "Warning",
					Duration = 8,
				})
			end)
		end)
	end
end



-- ===================== RELWX SQUARE PROFILE PANEL (replaces the old UI) =====================
-- One square, draggable panel: character image + name, level/XP, every wallet resource,
-- live character/run status, team slots and session stats. Reads the game's own account
-- store (same source the automations use), so Money / Gems / XP / Rolls / Lucky Spins etc.
-- are real values. The old hub window, floating button, FPS box and old stats panel are removed.
xpcall(function()
    local Players_ = game:GetService("Players")
    local UIS_ = game:GetService("UserInputService")
    local RunService_ = game:GetService("RunService")
    local StatsSvc_ = game:GetService("Stats")
    local LP = Players_.LocalPlayer
    if not LP then return end
    local PG = LP:WaitForChild("PlayerGui")

    -- remove every older UI -------------------------------------------------------------
    pcall(function()
        for _, name in ipairs({ "RELWX_ProfileStats", "RELWX_Square" }) do
            local old = PG:FindFirstChild(name)
            if old then old:Destroy() end
        end
        for _, name in ipairs({ "RELWX_UI", "RELWX_Floating", "RELWX_Stats" }) do
            local g = PG:FindFirstChild(name)
            if g and g:IsA("ScreenGui") then
                g.Enabled = false
                g:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if g.Enabled then g.Enabled = false end
                end)
            end
        end
        if RelwxUI then
            RelwxUI.Toggle = function() end -- the old window can no longer be reopened
        end
    end)

    -- helpers ---------------------------------------------------------------------------
    local C = {
        bg = Color3.fromRGB(12, 13, 19), head = Color3.fromRGB(23, 25, 38), row = Color3.fromRGB(24, 26, 37),
        accent = Color3.fromRGB(128, 96, 255), text = Color3.fromRGB(238, 240, 250), sub = Color3.fromRGB(151, 156, 176),
        good = Color3.fromRGB(92, 214, 143), warn = Color3.fromRGB(255, 198, 90), bad = Color3.fromRGB(255, 100, 104),
        blue = Color3.fromRGB(96, 170, 255),
    }
    local TONE = { Success = C.good, Error = C.bad, Warning = C.warn, Accent = C.blue, Muted = C.text }
    local function try(fn, ...)
        local ok, a = pcall(fn, ...)
        if ok then return a end
        return nil
    end
    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        o.Parent = parent
        return o
    end
    local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
    local function commas(n)
        n = tonumber(n) or 0
        local neg = n < 0
        n = math.abs(n)
        local s = (n == math.floor(n)) and string.format("%d", n) or string.format("%.2f", n)
        local int, frac = s:match("^(%d+)(.*)$")
        int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. int .. frac
    end
    local function pretty(k)
        k = tostring(k):gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
        return (k:gsub("^%l", string.upper))
    end
    local function clock(sec)
        sec = math.max(0, math.floor(tonumber(sec) or 0))
        return string.format("%02d:%02d:%02d", sec // 3600, sec % 3600 // 60, sec % 60)
    end
    local function toImage(a)
        if a == nil then return nil end
        local s = tostring(a)
        if s:find("rbxasset") then return s end
        local d = s:match("%d+")
        return d and ("rbxassetid://" .. d) or nil
    end

    -- game data -------------------------------------------------------------------------
    local startedAt = os.clock()
    local events = {}
    local function pushEvent(t)
        table.insert(events, 1, os.date("%H:%M:%S") .. "  " .. t)
        while #events > 8 do table.remove(events) end
    end
    pcall(function()
        if RelwxUI and type(RelwxUI.Notify) == "function" then
            RelwxUI.Notify = function(_, opts)
                opts = type(opts) == "table" and opts or {}
                pushEvent(tostring(opts.Title or "RELWX") .. ": " .. tostring(opts.Content or opts.Text or ""))
            end
        end
    end)

    local function getSnapshot()
        if not IN_LOBBY then return nil end
        return try(accountSnapshot)
    end
    local function currentCharacter(snap)
        if IN_RUN then
            local c = try(function() return PlayerNamespace.getLocalPlayerStore().state.character:get() end)
            if c then return tostring(c) end
        end
        local c = snap and snap.character
        if type(c) == "string" or type(c) == "number" then return tostring(c) end
        return nil
    end
    local function charName(id)
        if not id then return LP.DisplayName end
        return try(characterName, id) or tostring(id)
    end
    local fps = 60
    local fpsConn = RunService_.Heartbeat:Connect(function(dt)
        if dt > 0 then fps = fps + (1 / dt - fps) * 0.05 end
    end)
    local function ping()
        return try(function() return StatsSvc_.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    end

    -- GUI -------------------------------------------------------------------------------
    local gui = mk("ScreenGui", {
        Name = "RELWX_Square", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 1000001, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, PG)
    local SIZE = 340
    local panel = mk("Frame", {
        Name = "SquarePanel", Size = UDim2.fromOffset(SIZE, SIZE), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
    }, gui)
    corner(panel, 16)
    mk("UIStroke", { Color = C.accent, Thickness = 2, Transparency = 0.05 }, panel)
    local scale = mk("UIScale", {}, panel)
    local function rescale()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local v = cam.ViewportSize
        scale.Scale = math.clamp(math.min(v.X, v.Y) * 0.92 / SIZE, 0.6, 1.15)
    end
    rescale()
    local camConn
    pcall(function() camConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end)

    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = C.head, BorderSizePixel = 0 }, panel)
    local avatar = mk("ImageButton", {
        Name = "CharacterImage", Size = UDim2.fromOffset(78, 78), Position = UDim2.fromOffset(10, 7),
        BackgroundColor3 = Color3.fromRGB(40, 42, 58), BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, AutoButtonColor = false,
    }, header)
    corner(avatar, 14)
    mk("UIStroke", { Color = C.accent, Thickness = 1.2 }, avatar)
    local badge = mk("ImageLabel", {
        Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -20, 1, -20), BackgroundColor3 = C.head,
        BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, ZIndex = 3,
    }, avatar)
    corner(badge, 12)
    mk("UIStroke", { Color = C.bg, Thickness = 2 }, badge)

    local function label(parent, text, size, font, color, pos, sz, align)
        return mk("TextLabel", {
            BackgroundTransparency = 1, Text = text, TextSize = size, Font = font, TextColor3 = color,
            Position = pos, Size = sz, TextXAlignment = align or Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2,
        }, parent)
    end
    local nameLabel = label(header, "—", 17, Enum.Font.GothamBold, C.text, UDim2.fromOffset(102, 10), UDim2.new(1, -138, 0, 24))
    local subLabel = label(header, "@" .. LP.Name, 11, Enum.Font.Gotham, C.sub, UDim2.fromOffset(102, 34), UDim2.new(1, -114, 0, 16))
    local collapsedTitle = label(header, "RELWX KAITUN", 15, Enum.Font.GothamBold, C.text, UDim2.fromOffset(62, 0), UDim2.new(1, -102, 1, 0))
    collapsedTitle.Visible = false
    local lvlPill = mk("TextLabel", {
        Position = UDim2.fromOffset(102, 54), Size = UDim2.fromOffset(62, 22), BackgroundColor3 = C.accent, BorderSizePixel = 0,
        Text = "LV —", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), ZIndex = 2,
    }, header)
    corner(lvlPill, 11)
    local xpTrack = mk("Frame", {
        Position = UDim2.fromOffset(172, 61), Size = UDim2.new(1, -184, 0, 8), BackgroundColor3 = Color3.fromRGB(40, 42, 58), BorderSizePixel = 0,
    }, header)
    corner(xpTrack, 4)
    local xpFill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.good, BorderSizePixel = 0 }, xpTrack)
    corner(xpFill, 4)
    local minBtn = mk("TextButton", {
        Position = UDim2.new(1, -32, 0, 8), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.fromRGB(40, 42, 58),
        Text = "–", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = C.text, BorderSizePixel = 0, ZIndex = 3,
    }, header)
    corner(minBtn, 8)

    -- tabs
    local TABS = { "RESOURCES", "STATUS", "TEAM" }
    local tabBtns, activeTab = {}, 1
    local tabBar = mk("Frame", { Position = UDim2.fromOffset(10, 98), Size = UDim2.new(1, -20, 0, 26), BackgroundTransparency = 1 }, panel)
    mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)

    local scroll = mk("ScrollingFrame", {
        Position = UDim2.fromOffset(10, 130), Size = UDim2.new(1, -20, 1, -176), BackgroundColor3 = Color3.fromRGB(17, 18, 26),
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, panel)
    corner(scroll, 10)
    mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8) }, scroll)
    mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

    local report = mk("TextButton", {
        Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 30), BackgroundColor3 = Color3.fromRGB(44, 46, 66),
        Text = "REPORT ALL STATS", TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.text, BorderSizePixel = 0,
    }, panel)
    corner(report, 9)

    -- row renderer (updates in place so scrolling never jumps) --------------------------------
    local cache, order = {}, 0
    local R = {}
    function R.begin() order = 0 for _, c in pairs(cache) do c.seen = false end end
    local function entry(key, kind)
        local c = cache[key]
        if c and c.kind ~= kind then c.frame:Destroy() cache[key] = nil c = nil end
        if not c then
            local f = mk("Frame", { Size = UDim2.new(1, 0, 0, kind == "header" and 20 or 26),
                BackgroundColor3 = C.row, BackgroundTransparency = kind == "header" and 1 or 0, BorderSizePixel = 0 }, scroll)
            corner(f, 7)
            c = { frame = f, kind = kind }
            if kind == "header" then
                c.a = label(f, "", 10, Enum.Font.GothamBold, C.accent, UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0))
            else
                c.fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.good, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 1 }, f)
                corner(c.fill, 7)
                c.a = label(f, "", 11, Enum.Font.Gotham, C.sub, UDim2.fromOffset(8, 0), UDim2.new(0.56, -8, 1, 0))
                c.b = label(f, "", 12, Enum.Font.GothamBold, C.text, UDim2.fromScale(0.56, 0), UDim2.new(0.44, -8, 1, 0), Enum.TextXAlignment.Right)
            end
            cache[key] = c
        end
        order += 1
        c.seen = true
        c.frame.LayoutOrder = order
        return c
    end
    function R.header(key, text)
        entry(key, "header").a.Text = text
    end
    function R.row(key, name, value, color, fraction)
        local c = entry(key, "row")
        value = tostring(value)
        c.a.Text = name
        c.b.Text = value
        c.b.TextColor3 = color or C.text
        if value == "" then
            c.a.Size = UDim2.new(1, -16, 1, 0)
            c.a.TextColor3 = C.text
            c.b.Visible = false
        else
            c.a.Size = UDim2.new(0.56, -8, 1, 0)
            c.a.TextColor3 = C.sub
            c.b.Visible = true
        end
        if fraction then
            c.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
            c.fill.BackgroundColor3 = color or C.good
            c.fill.Visible = true
        else
            c.fill.Visible = false
        end
    end
    function R.finish()
        for key, c in pairs(cache) do
            if not c.seen then c.frame:Destroy() cache[key] = nil end
        end
    end
    -- recorder used by the report button (same interface, writes text)
    local function recorder(lines)
        return {
            begin = function() end, finish = function() end,
            header = function(_, text) table.insert(lines, "") table.insert(lines, "== " .. text .. " ==") end,
            row = function(_, name, value) table.insert(lines, value == "" and name or (name .. ": " .. tostring(value))) end,
        }
    end

    -- tab content -----------------------------------------------------------------------
    local ICON = { money = "💰", gems = "💎", xp = "✨", rolls = "🎲", luckySpins = "🍀", traitRerolls = "🔁" }
    local PRI = { money = 1, gems = 2, xp = 3, rolls = 4, luckySpins = 5, traitRerolls = 6 }
    local function tab_resources(r, snap)
        r.header("h_wallet", "WALLET")
        local cur = snap and type(snap.currencies) == "table" and snap.currencies
        if cur then
            local keys = {}
            for k in pairs(cur) do table.insert(keys, k) end
            table.sort(keys, function(a, b)
                local pa, pb = PRI[a] or 50, PRI[b] or 50
                if pa ~= pb then return pa < pb end
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                local v = cur[k]
                if type(v) == "number" then
                    r.row("c_" .. k, (ICON[k] or "◆") .. "  " .. pretty(k), commas(v), k == "gems" and C.blue or (k == "money" and C.warn or C.text))
                end
            end
        else
            r.row("c_none", "Wallet is only readable in the lobby", "", C.sub)
            local p = try(myParticipant)
            if p then
                r.row("run_money", "💰  Run Money", commas(try(function() return p.earned:get() + p.bonus:get() end) or 0), C.warn)
                r.row("run_gems", "💎  Run Gems", commas(try(function() return p.gems:get() end) or 0), C.blue)
                r.row("run_xp", "✨  Run XP", commas(try(function() return p.xp:get() end) or 0))
            end
        end
        local mats = snap and snap.material
        if type(mats) == "table" then
            local keys, shown = {}, 0
            for k, v in pairs(mats) do
                local n = type(v) == "number" and v or (type(v) == "table" and tonumber(v.amount or v.count)) or nil
                if n and n > 0 then table.insert(keys, { k = tostring(k), n = n }) end
            end
            table.sort(keys, function(a, b) return a.k < b.k end)
            if #keys > 0 then r.header("h_mats", "MATERIALS") end
            for _, e in ipairs(keys) do r.row("m_" .. e.k, pretty(e.k), commas(e.n)) end
        end
        if type(Stats) == "table" and type(Stats.materials) == "table" then
            local keys = {}
            for k, v in pairs(Stats.materials) do if type(v) == "number" and v > 0 then table.insert(keys, { k = tostring(k), n = v }) end end
            table.sort(keys, function(a, b) return a.k < b.k end)
            if #keys > 0 then r.header("h_drops", "SESSION DROPS") end
            for _, e in ipairs(keys) do r.row("d_" .. e.k, pretty(e.k), "+" .. commas(e.n), C.good) end
        end
    end

    local function tab_status(r, snap)
        r.header("h_state", "CHARACTER STATUS")
        r.row("s_loc", "Location", IN_RUN and "In Run" or "Lobby", IN_RUN and C.warn or C.good)
        if IN_RUN then
            for i, row in ipairs(try(liveRunRows) or {}) do
                r.row("run_" .. tostring(row.Text), tostring(row.Text), tostring(row.Value), TONE[row.Tone] or C.text)
            end
        else
            local q = try(function() return lobby.queueStatus end)
            r.row("s_queue", "Queue", pretty(q or "idle"), q == "idle" and C.sub or C.warn)
            local title = snap and snap.equippedTitle
            if title and tostring(title) ~= "" then r.row("s_title", "Title", pretty(title), C.blue) end
            local dq = try(getDeliveryQuestCount)
            if dq then r.row("s_deliv", "Deliveries Today", commas(dq)) end
        end
        local hum = try(function() local _, _, h = characterParts() return h end)
        if hum then
            local ratio = hum.Health / math.max(hum.MaxHealth, 1)
            r.row("s_hp", "Health", string.format("%s / %s", commas(math.floor(hum.Health)), commas(math.floor(hum.MaxHealth))),
                ratio <= 0.3 and C.bad or (ratio <= 0.6 and C.warn or C.good), ratio)
        end
        local K = try(function() return gacha.K end)
        if K and type(K.On) == "table" then
            local on = 0
            for _, key in ipairs(K.On) do if try(function() return Flags[key] end) then on += 1 end end
            r.row("s_auto", "Automations", string.format("%d / %d active", on, #K.On), on == #K.On and C.good or C.warn, on / math.max(#K.On, 1))
        end

        r.header("h_sess", "SESSION")
        if type(Stats) == "table" then
            local runs = (Stats.wins or 0) + (Stats.losses or 0)
            r.row("t_wins", "Wins", commas(Stats.wins or 0), C.good)
            r.row("t_loss", "Losses", commas(Stats.losses or 0), C.bad)
            r.row("t_rate", "Win Rate", runs > 0 and string.format("%d%%", math.floor((Stats.wins or 0) / runs * 100 + 0.5)) or "-", C.text,
                runs > 0 and (Stats.wins or 0) / runs or nil)
            r.row("t_kills", "Kills", commas(Stats.kills or 0))
            r.row("t_money", "Money Gained", "+" .. commas(Stats.money or 0), C.warn)
            r.row("t_gems", "Gems Gained", "+" .. commas(Stats.gems or 0), C.blue)
            r.row("t_xp", "XP Gained", "+" .. commas(Stats.xp or 0))
            r.row("t_rolls", "Roll Hits", commas(Stats.rollHits or 0))
            r.row("t_kick", "Kicked", commas(Stats.kicked or 0), (Stats.kicked or 0) > 0 and C.warn or C.text)
        end
        r.row("t_up", "Uptime", clock(os.clock() - startedAt))

        r.header("h_sys", "SYSTEM")
        local p = ping()
        r.row("y_fps", "FPS", string.format("%d", math.floor(fps + 0.5)), fps >= 50 and C.good or (fps >= 30 and C.warn or C.bad))
        r.row("y_ping", "Ping", p and string.format("%d ms", math.floor(p + 0.5)) or "-", (p or 0) <= 80 and C.good or ((p or 0) <= 160 and C.warn or C.bad))
        r.row("y_plr", "Players", tostring(#Players_:GetPlayers()))

        if #events > 0 then
            r.header("h_ev", "RECENT EVENTS")
            for i, e in ipairs(events) do r.row("e_" .. i, e, "", C.text) end
        end
    end

    local function tab_team(r, snap)
        r.header("h_team", "CHARACTER SLOTS")
        if not snap or type(snap.UnlockedCharacters) ~= "table" then
            r.row("tm_none", "Team data is only readable in the lobby", "", C.sub)
            local cur = currentCharacter(nil)
            if cur then r.row("tm_cur", "Active Character", charName(cur), C.blue) end
            return
        end
        local equippedSlots = {}
        for key, slot in pairs(snap.EquippedCharacterSlots or {}) do equippedSlots[tonumber(slot) or -1] = tostring(key) end
        for slot = 1, 4 do
            local data = snap.UnlockedCharacters["Slot" .. slot]
            if data and data.Unlocked == true and data.Character and data.Character ~= "" then
                local rarity = try(function() return RollConfig.rarityByCharacter[data.Character] end)
                local active = equippedSlots[slot] ~= nil
                local text = (rarity and tostring(rarity) or "") .. (active and "  ● TEAM" or "")
                r.row("tm_" .. slot, "Slot " .. slot .. "  " .. charName(data.Character), text, active and C.good or C.text)
                local xp = snap.CharactersData and snap.CharactersData[data.Character] and snap.CharactersData[data.Character].Progression
                if xp and tonumber(xp.Xp) then r.row("tmx_" .. slot, "      Character XP", commas(xp.Xp), C.sub) end
            else
                r.row("tm_" .. slot, "Slot " .. slot, (data and data.Unlocked == true) and "Empty" or "Locked", C.sub)
            end
        end
        local cur = currentCharacter(snap)
        if cur then
            r.header("h_cur", "ACTIVE")
            r.row("tm_cur", "Character", charName(cur), C.blue)
        end
    end
    local BUILDERS = { tab_resources, tab_status, tab_team }

    -- header refresh ----------------------------------------------------------------------
    local lastChar, headshot
    task.spawn(function()
        local ok, img = pcall(function()
            return Players_:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if ok then
            headshot = img
            if gui.Parent then badge.Image = img end
            if lastChar == nil and gui.Parent and avatar.Image == "" then avatar.Image = img end
        end
    end)
    local function refreshHeader(snap)
        local id = currentCharacter(snap)
        nameLabel.Text = id and charName(id) or LP.DisplayName
        subLabel.Text = "Player: " .. LP.DisplayName .. "  @" .. LP.Name
        if id ~= lastChar then
            lastChar = id
            avatar.Image = (id and toImage(try(characterArt, id))) or headshot or ""
        end
        local lvl = snap and try(playerLevel, snap)
        lvlPill.Text = lvl and ("LV " .. tostring(lvl)) or "LV —"
        local frac
        if snap and snap.currencies and Levels then
            local prog = try(Levels.getProgress, tonumber(snap.currencies.xp) or 0)
            if type(prog) == "table" then
                frac = tonumber(prog.fraction or prog.percent or prog.progress or prog.ratio)
                if not frac then
                    local cur = tonumber(prog.current or prog.xpIntoLevel or prog.xp)
                    local need = tonumber(prog.required or prog.needed or prog.xpForNext or prog.next or prog.max)
                    if cur and need and need > 0 then frac = cur / need end
                end
                if frac and frac > 1 then frac = frac / 100 end
            end
        end
        xpTrack.Visible = frac ~= nil
        xpFill.Size = UDim2.fromScale(math.clamp(frac or 0, 0, 1), 1)
    end

    local function refresh()
        if not gui.Parent then return end
        local snap = getSnapshot()
        refreshHeader(snap)
        R.begin()
        local ok, err = pcall(BUILDERS[activeTab], R, snap)
        if not ok then R.row("err", "Unavailable", tostring(err):sub(1, 40), C.bad) end
        R.finish()
    end

    local function setTab(i)
        activeTab = i
        for n, b in ipairs(tabBtns) do
            b.BackgroundColor3 = n == i and C.accent or Color3.fromRGB(32, 34, 48)
            b.TextColor3 = n == i and Color3.new(1, 1, 1) or C.sub
        end
        R.begin() R.finish() -- drop old rows (all unseen)
        scroll.CanvasPosition = Vector2.zero
        refresh()
    end
    for i, name in ipairs(TABS) do
        local b = mk("TextButton", {
            LayoutOrder = i, Size = UDim2.new(1 / #TABS, -4, 1, 0), Text = name, TextSize = 10, Font = Enum.Font.GothamBold,
            BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(32, 34, 48), TextColor3 = C.sub,
        }, tabBar)
        corner(b, 8)
        b.MouseButton1Click:Connect(function() setTab(i) end)
        tabBtns[i] = b
    end

    -- report ----------------------------------------------------------------------------
    report.MouseButton1Click:Connect(function()
        local snap = getSnapshot()
        local lines = {
            "========== RELWX CHARACTER REPORT ==========",
            "Player: " .. LP.DisplayName .. " (@" .. LP.Name .. ")  UserId " .. tostring(LP.UserId),
            "Character: " .. tostring(charName(currentCharacter(snap))) .. "   " .. lvlPill.Text,
        }
        local rec = recorder(lines)
        for _, build in ipairs(BUILDERS) do pcall(build, rec, snap) end
        table.insert(lines, "============================================")
        local text = table.concat(lines, "\n")
        print(text)
        local copied = false
        if typeof(setclipboard) == "function" then copied = pcall(setclipboard, text) end
        pushEvent("Report printed" .. (copied and " + copied" or ""))
        report.Text = copied and "REPORT PRINTED + COPIED  ✓" or "REPORT PRINTED  ✓"
        task.delay(1.6, function() if report.Parent then report.Text = "REPORT ALL STATS" end end)
    end)

    -- Minimise to a long compact bar. Tap the avatar/bar to restore the square panel.
    local collapsed = false
    local function applyCollapse()
        panel.Size = collapsed and UDim2.fromOffset(230, 56) or UDim2.fromOffset(SIZE, SIZE)
        header.Size = collapsed and UDim2.fromScale(1, 1) or UDim2.new(1, 0, 0, 92)
        avatar.Size = collapsed and UDim2.fromOffset(42, 42) or UDim2.fromOffset(78, 78)
        avatar.Position = collapsed and UDim2.fromOffset(7, 7) or UDim2.fromOffset(10, 7)
        collapsedTitle.Visible = collapsed
        for _, o in ipairs({ nameLabel, subLabel, lvlPill, xpTrack, minBtn, tabBar, scroll, report }) do
            o.Visible = not collapsed
        end
        if not collapsed then xpTrack.Visible = true end
    end
    minBtn.MouseButton1Click:Connect(function() collapsed = true applyCollapse() end)
    avatar.Activated:Connect(function()
        if collapsed then
            collapsed = false
            applyCollapse()
            refresh()
        end
    end)
    collapsedTitle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if collapsed then collapsed = false applyCollapse() refresh() end
        end
    end)

    -- drag (mouse + touch) --------------------------------------------------------------
    local dragging, dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    local dragConn = UIS_.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    gui.Destroying:Connect(function()
        pcall(function() fpsConn:Disconnect() end)
        pcall(function() dragConn:Disconnect() end)
        pcall(function() if camConn then camConn:Disconnect() end end)
    end)

    setTab(1)
    task.spawn(function()
        while gui.Parent do
            task.wait(1)
            pcall(refresh)
        end
    end)
end, function(e) warn("RELWX square UI error: " .. tostring(e)) end)
-- =================== END RELWX SQUARE PROFILE PANEL ===================

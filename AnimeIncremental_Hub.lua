--[[
    ypx Hub v8.0 © ypx
    基于rscripts.net/scriptblox.com老外脚本模式深度学习重写
    核心升级:
      1. 全部 while 循环改为 RunService.Heartbeat 驱动 (丝滑无卡顿)
      2. 自动农场加入 Highlight 高亮 + BillboardGui 目标标记 (视觉反馈)
      3. NPC检测加入目标缓存, 避免每帧重复扫描
      4. 统一任务管理器 TaskManager, 一键停止所有循环
      5. 自动训练 = VirtualInputManager模拟点击 + GUI按钮点击 (不盲发Remote)
      6. 自动农场 = CFrame传送到NPC身边 (不盲发Remote)
      7. 自动商店/重生 = 找到真实GUI按钮点击 (不盲发Remote)
      8. 自动宝箱 = 扫描Workspace传送 (不盲发Remote)
      9. 只扫ReplicatedStorage+Workspace, 不扫game:GetDescendants()
]]

-- ==================== 服务 ====================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

-- ==================== 工具 ====================
local twait = task.wait or wait
local tspawn = task.spawn or function(f) coroutine.wrap(f)() end
local tdelay = task.delay or delay

local function getGuiParent()
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()
pcall(function() local o = guiParent:FindFirstChild("ypxHub") if o then o:Destroy() end end)

local hasFCD = type(fireclickdetector) == "function"
local hasClip = type(setclipboard) == "function"

-- ==================== 颜色 ====================
local C = {
    BG = Color3.fromRGB(10, 10, 16), BG2 = Color3.fromRGB(6, 6, 12),
    Card = Color3.fromRGB(20, 20, 32), CardH = Color3.fromRGB(30, 30, 48),
    Side = Color3.fromRGB(14, 14, 22), SideH = Color3.fromRGB(22, 22, 36),
    Blue = Color3.fromRGB(59, 130, 246), BlueD = Color3.fromRGB(37, 99, 235),
    BlueL = Color3.fromRGB(96, 165, 250), BlueX = Color3.fromRGB(147, 197, 253),
    Off = Color3.fromRGB(50, 50, 65), On = Color3.fromRGB(34, 197, 94),
    White = Color3.fromRGB(240, 240, 245), Gray = Color3.fromRGB(150, 150, 165),
    Red = Color3.fromRGB(239, 68, 68), Orange = Color3.fromRGB(251, 146, 60),
    Green = Color3.fromRGB(34, 197, 94), Purple = Color3.fromRGB(168, 85, 247),
    Gold = Color3.fromRGB(250, 204, 21), Div = Color3.fromRGB(34, 34, 48),
    Track = Color3.fromRGB(36, 36, 50), TrackH = Color3.fromRGB(50, 50, 70),
}

-- ==================== UI辅助 ====================
local function tw(o, p, t)
    pcall(function() TweenService:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), p):Play() end)
end

local function make(cl, pr)
    local o = Instance.new(cl)
    if pr then
        local p = pr.Parent
        for k, v in pairs(pr) do
            if k ~= "Parent" then pcall(function() o[k] = v end) end
        end
        if p then o.Parent = p end
    end
    return o
end

local function corner(p, r) make("UICorner", { Parent = p, CornerRadius = UDim.new(0, r or 8) }) end
local function stroke(p, c, t, tr) make("UIStroke", { Parent = p, Color = c or C.Div, Thickness = t or 1, Transparency = tr or 0.4 }) end
local function gradient(p, c1, c2, rot) make("UIGradient", { Parent = p, Color = ColorSequence.new(c1, c2), Rotation = rot or 0 }) end
local function pad(p, t, b, l, r) make("UIPadding", { Parent = p, PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0) }) end

local function drag(frame, handle)
    handle = handle or frame
    local d, sp, si
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            d = true si = i.Position sp = frame.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local dl = i.Position - si
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dl.X, sp.Y.Scale, sp.Y.Offset + dl.Y)
        end
    end)
end

-- ==================== 游戏工具 (启动时缓存一次) ====================
-- Remote缓存: 只扫ReplicatedStorage (不扫整个game)
local remoteCache = {}
-- GUI按钮缓存: 按文本/名称索引
local buttonCache = {}
-- ClickDetector缓存
local cdCache = {}

-- 启动时扫描ReplicatedStorage的Remote (只做一次)
local function scanRemotes()
    pcall(function()
        for _, o in pairs(ReplicatedStorage:GetDescendants()) do
            if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                remoteCache[string.lower(o.Name)] = o
            end
        end
    end)
end

-- 扫描PlayerGui按钮 (只做一次, 后续用DescendantAdded自动更新)
local function scanButtons()
    pcall(function()
        for _, g in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if g:IsA("TextButton") or g:IsA("ImageButton") then
                buttonCache[string.lower(g.Name)] = g
                if g:IsA("TextButton") and g.Text and g.Text ~= "" then
                    buttonCache[string.lower(g.Text)] = g
                end
            end
        end
    end)
end

-- 扫描ClickDetector (只做一次)
local function scanClickDetectors()
    pcall(function()
        for _, o in pairs(Workspace:GetDescendants()) do
            if o:IsA("ClickDetector") then
                table.insert(cdCache, o)
            end
        end
    end)
end

-- DescendantAdded 自动更新缓存 (不在循环中扫描)
pcall(function()
    ReplicatedStorage.DescendantAdded:Connect(function(o)
        if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
            remoteCache[string.lower(o.Name)] = o
        end
    end)
end)
pcall(function()
    Workspace.DescendantAdded:Connect(function(o)
        if o:IsA("ClickDetector") then table.insert(cdCache, o) end
    end)
end)
pcall(function()
    LocalPlayer.PlayerGui.DescendantAdded:Connect(function(o)
        if o:IsA("TextButton") or o:IsA("ImageButton") then
            buttonCache[string.lower(o.Name)] = o
            if o:IsA("TextButton") and o.Text and o.Text ~= "" then
                buttonCache[string.lower(o.Text)] = o
            end
        end
    end)
end)

-- 查Remote: 先直接路径, 再缓存
local function getRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if not r then
        local folder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Events")
        if folder then r = folder:FindFirstChild(name) end
    end
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return remoteCache[string.lower(name)]
end

-- 模糊查找Remote (用于不确定名称时)
local function getRemoteFuzzy(...)
    local kws = {...}
    -- 1. 直接路径
    for _, kw in pairs(kws) do
        local r = getRemote(kw)
        if r then return r end
    end
    -- 2. 缓存模糊匹配
    for name, r in pairs(remoteCache) do
        for _, kw in pairs(kws) do
            if string.find(name, string.lower(kw)) then return r end
        end
    end
    return nil
end

local function fireRemote(r, ...)
    if not r then return end
    local args = {...}
    pcall(function()
        if r:IsA("RemoteEvent") then
            r:FireServer(unpack(args))
        elseif r:IsA("RemoteFunction") then
            pcall(function() r:InvokeServer(unpack(args)) end)
        end
    end)
end

-- ==================== 核心动作函数 (基于真实脚本模式) ====================
local function getHum() local c = LocalPlayer.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end

-- 模拟点击屏幕中心 (VirtualInputManager, 移动端兼容)
local function tapScreen()
    pcall(function()
        local vp = LocalPlayer:GetMouse().ViewSizeX
        local hp = LocalPlayer:GetMouse().ViewSizeY
        if vp and hp and vp > 0 then
            VirtualInputManager:SendMouseButtonEvent(vp/2, hp/2, 0, true, LocalPlayer, 1)
            VirtualInputManager:SendMouseButtonEvent(vp/2, hp/2, 0, false, LocalPlayer, 1)
        end
    end)
end

-- 点击GUI按钮: 先查缓存, 找不到再实时搜 (只搜PlayerGui, 不搜game)
local function clickButton(kw)
    local lk = string.lower(kw)
    -- 1. 查缓存
    local btn = buttonCache[lk]
    if btn and btn.Parent then
        pcall(function()
            if btn:IsA("GuiButton") then
                btn.AutoButtonColor = true
                local sig = {}
                for _, s in pairs(btn:GetChildren()) do
                    if s:IsA("BindableEvent") then table.insert(sig, s) end
                end
                for _, s in pairs(sig) do pcall(function() s:Fire() end) end
                pcall(function() btn:Activate() end)
                -- 模拟鼠标事件
                pcall(function()
                    local args = {
                        Enum.UserInputType.MouseButton1,
                        false,
                        LocalPlayer:GetMouse().Hit.Position,
                        btn,
                        0,
                        Enum.UserInputState.Begin,
                        1,
                        false,
                    }
                    for _, c in pairs(btn:GetDescendants()) do
                        if c:IsA("Frame") then break end
                    end
                end)
            end
        end)
        return true
    end
    -- 2. 实时搜PlayerGui (不搜整个game)
    local found = false
    pcall(function()
        for _, g in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if (g:IsA("TextButton") or g:IsA("ImageButton")) and g.Parent then
                local match = false
                if string.lower(g.Name) == lk then match = true end
                if g:IsA("TextButton") and g.Text and string.lower(g.Text) == lk then match = true end
                if not match and g:IsA("TextButton") and g.Text then
                    if string.find(string.lower(g.Text), lk) then match = true end
                end
                if match then
                    buttonCache[lk] = g
                    pcall(function()
                        for _, s in pairs(g:GetChildren()) do
                            if s:IsA("BindableEvent") then s:Fire() end
                        end
                        g:Activate()
                    end)
                    found = true
                    break
                end
            end
        end
    end)
    return found
end

-- 找最近的NPC/敌人 (用于自动农场传送) - 带目标缓存
-- 老外脚本优化: 缓存上次目标, 避免每帧全量扫描
local targetCache = { part = nil, expire = 0 }
local function findNearestEnemy()
    local root = getRoot()
    if not root then return nil end
    -- 缓存有效: 上次目标还在且活着, 直接返回
    local now = os.clock()
    if targetCache.part and targetCache.part.Parent and now < targetCache.expire then
        local hum = targetCache.part.Parent:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            return targetCache.part
        end
    end
    -- 缓存失效, 重新扫描
    local nearest, nearestDist = nil, math.huge
    pcall(function()
        for _, folder in pairs(Workspace:GetChildren()) do
            if folder:IsA("Folder") or folder:IsA("Model") then
                for _, npc in pairs(folder:GetChildren()) do
                    if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
                        local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
                        if hrp and npc:FindFirstChildOfClass("Humanoid").Health > 0 then
                            local dist = (hrp.Position - root.Position).Magnitude
                            if dist < nearestDist then
                                nearestDist = dist
                                nearest = hrp
                            end
                        end
                    end
                end
            end
        end
    end)
    -- 更新缓存 (1秒有效)
    if nearest then
        targetCache.part = nearest
        targetCache.expire = now + 1
    else
        targetCache.part = nil
    end
    return nearest
end

-- 找所有宝箱类物体
local function findChests()
    local chests = {}
    pcall(function()
        for _, o in pairs(Workspace:GetDescendants()) do
            if o:IsA("BasePart") or o:IsA("Model") then
                local name = string.lower(o.Name)
                if string.find(name, "chest") or string.find(name, "宝箱") or string.find(name, "reward") or string.find(name, "drop") or string.find(name, "pickup") then
                    local part = o:IsA("Model") and o:FindFirstChildWhichIsA("BasePart") or o
                    if part then table.insert(chests, part) end
                end
            end
        end
    end)
    return chests
end

-- ==================== 连接追踪 ====================
local allConns = {}
local function trackConn(c) table.insert(allConns, c) return c end
local function stopAllConns() for _, c in pairs(allConns) do pcall(function() c:Disconnect() end) end allConns = {} end

-- ==================== Heartbeat 任务管理器 (替代所有 while 循环) ====================
-- 老外脚本核心模式: 用 RunService.Heartbeat 驱动定时任务, 不用 while+wait
local TaskManager = {}
TaskManager.tasks = {}
TaskManager.conn = nil

function TaskManager.start(name, interval, callback)
    TaskManager.stop(name)
    TaskManager.tasks[name] = {
        interval = interval,
        callback = callback,
        accumulator = 0,
        active = true,
    }
    if not TaskManager.conn then
        TaskManager.conn = RunService.Heartbeat:Connect(function(dt)
            for n, t in pairs(TaskManager.tasks) do
                if t.active then
                    t.accumulator = t.accumulator + dt
                    if t.accumulator >= t.interval then
                        t.accumulator = 0
                        pcall(t.callback)
                    end
                end
            end
        end)
    end
end

function TaskManager.stop(name)
    if TaskManager.tasks[name] then
        TaskManager.tasks[name] = nil
    end
end

function TaskManager.stopAll()
    for n in pairs(TaskManager.tasks) do
        TaskManager.tasks[n] = nil
    end
    if TaskManager.conn then
        TaskManager.conn:Disconnect()
        TaskManager.conn = nil
    end
end

-- ==================== 视觉反馈系统 (Highlight + BillboardGui) ====================
-- 老外脚本特色: 给目标加高亮和头顶标记, 让用户看到脚本在工作
local VisualFX = {}
VisualFX.highlight = nil
VisualFX.billboard = nil

function VisualFX.highlightTarget(part)
    VisualFX.clear()
    if not part then return end
    pcall(function()
        -- Highlight 高亮轮廓
        VisualFX.highlight = Instance.new("Highlight")
        VisualFX.highlight.Name = "ypxHighlight"
        VisualFX.highlight.Adornee = part
        VisualFX.highlight.FillColor = Color3.fromRGB(255, 50, 50)
        VisualFX.highlight.FillTransparency = 0.6
        VisualFX.highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
        VisualFX.highlight.OutlineTransparency = 0
        VisualFX.highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        VisualFX.highlight.Parent = part

        -- BillboardGui 头顶标记
        VisualFX.billboard = Instance.new("BillboardGui")
        VisualFX.billboard.Name = "ypxTarget"
        VisualFX.billboard.Adornee = part
        VisualFX.billboard.Size = UDim2.new(0, 120, 0, 28)
        VisualFX.billboard.StudsOffset = Vector3.new(0, 4, 0)
        VisualFX.billboard.AlwaysOnTop = true
        VisualFX.billboard.Parent = part

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.Text = "🎯 TARGET"
        lbl.TextColor3 = Color3.fromRGB(255, 255, 0)
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextStrokeTransparency = 0
        lbl.TextSize = 14
        lbl.Parent = VisualFX.billboard
    end)
end

function VisualFX.clear()
    pcall(function()
        if VisualFX.highlight then VisualFX.highlight:Destroy() end
        if VisualFX.billboard then VisualFX.billboard:Destroy() end
    end)
    VisualFX.highlight = nil
    VisualFX.billboard = nil
end

-- ==================== 状态变量 ====================
local Flags = {}
local mainW, mainH = 440, 380

local flyState = false
local flySpeed = 60
local flyVel = Vector3.new(0, 0, 0)
local flyUp = false
local flyDown = false

local noclipConn = nil
local wsSpeed = 50
local wsActive = false

-- ==================== ScreenGui ====================
local sg = make("ScreenGui", {
    Name = "ypxHub", Parent = guiParent, ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 9999,
})

-- ==================== 飞行悬浮面板 ====================
local flyPanel = make("Frame", {
    Parent = sg, Name = "FlyPanel", BackgroundColor3 = C.Card, BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0.55, 0), Size = UDim2.new(0, 58, 0, 64),
    Visible = false, Active = true,
})
corner(flyPanel, 10) stroke(flyPanel, C.Green, 1.5, 0.2)
gradient(flyPanel, C.Card, C.CardH, 90)

local flyOffBtn = make("TextButton", {
    Parent = flyPanel, BackgroundColor3 = C.Green, BorderSizePixel = 0,
    Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 0, 26),
    Font = Enum.Font.GothamBold, Text = "飞行 ✓", TextColor3 = C.White, TextSize = 11,
    AutoButtonColor = false,
})
corner(flyOffBtn, 7)

local flyDownBtn = make("TextButton", {
    Parent = flyPanel, BackgroundColor3 = C.Off, BorderSizePixel = 0,
    Position = UDim2.new(0, 4, 0, 32), Size = UDim2.new(1, -8, 0, 28),
    Font = Enum.Font.GothamBold, Text = "▼ 下降", TextColor3 = C.White, TextSize = 10,
    AutoButtonColor = false,
})
corner(flyDownBtn, 7)

flyOffBtn.MouseButton1Click:Connect(function() tw(flyOffBtn, {BackgroundColor3 = C.Red}, 0.08) tdelay(0.1, function() tw(flyOffBtn, {BackgroundColor3 = C.Green}, 0.08) end) stopFly() end)
flyDownBtn.MouseButton1Down:Connect(function() flyDown = true tw(flyDownBtn, {BackgroundColor3 = C.BlueD}, 0.06) end)
flyDownBtn.MouseButton1Up:Connect(function() flyDown = false tw(flyDownBtn, {BackgroundColor3 = C.Off}, 0.06) end)
drag(flyPanel)

-- ==================== 通知 ====================
local function showNotif(text, color)
    local n = make("TextLabel", {
        Parent = sg, BackgroundColor3 = color or C.BlueD, BorderSizePixel = 0,
        Position = UDim2.new(0.5, -130, 0, -40), Size = UDim2.new(0, 260, 0, 32),
        Font = Enum.Font.GothamSemibold, Text = "  " .. text, TextColor3 = C.White, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(n, 8) stroke(n, color or C.BlueD, 1, 0.2)
    tw(n, {Position = UDim2.new(0.5, -130, 0, 10)}, 0.25)
    tdelay(2.5, function()
        tw(n, {Position = UDim2.new(0.5, -130, 0, -40)}, 0.25)
        tdelay(0.3, function() pcall(function() n:Destroy() end) end)
    end)
end

-- ==================== 飞行系统 ====================
function stopFly()
    flyState = false
    Flags.Fly = false
    flyUp = false flyDown = false
    TaskManager.stop("Fly")
    pcall(function()
        local h = getHum() if h then h.PlatformStand = false end
        local r = getRoot()
        if r then
            for _, o in pairs(r:GetChildren()) do
                if o:IsA("BodyVelocity") or o:IsA("BodyGyro") or o.Name == "ypxFlyBV" or o.Name == "ypxFlyBG" then
                    o:Destroy()
                end
            end
        end
    end)
    flyVel = Vector3.new(0, 0, 0)
    flyPanel.Visible = false
end

function startFly()
    if flyState then return end
    flyState = true Flags.Fly = true flyPanel.Visible = true
    local root = getRoot()
    local hum = getHum()
    if not root or not hum then flyState = false flyPanel.Visible = false return end
    root.CFrame = root.CFrame + Vector3.new(0, 5, 0)
    hum.PlatformStand = true
    local bv = make("BodyVelocity", { Name = "ypxFlyBV", MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.new(0, 0, 0), Parent = root })
    local bg = make("BodyGyro", { Name = "ypxFlyBG", MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 10000, CFrame = root.CFrame, Parent = root })
    -- Heartbeat 驱动飞行 (替代 while 循环)
    TaskManager.start("Fly", 0.02, function()
        root = getRoot() hum = getHum()
        if not root or not hum then flyState = false flyPanel.Visible = false TaskManager.stop("Fly") return end
        if not root:FindFirstChild("ypxFlyBV") then
            bv = make("BodyVelocity", { Name = "ypxFlyBV", MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.new(0, 0, 0), Parent = root })
            bg = make("BodyGyro", { Name = "ypxFlyBG", MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 10000, CFrame = root.CFrame, Parent = root })
        end
        hum.PlatformStand = true
        local cam = Workspace.CurrentCamera
        if cam then
            local moveDir = hum.MoveDirection
            local target = Vector3.new(0, 0, 0)
            if moveDir.Magnitude > 0.1 then
                target = target + Vector3.new(moveDir.X, 0, moveDir.Z) * flySpeed
            end
            if flyUp or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                target = target + Vector3.new(0, flySpeed, 0)
            end
            if flyDown or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                target = target - Vector3.new(0, flySpeed, 0)
            end
            flyVel = flyVel:Lerp(target, 0.12)
            bv.Velocity = flyVel
            bg.CFrame = cam.CFrame
        end
    end)
end

-- ==================== 穿墙系统 ====================
local function setNoclip(on)
    Flags.Noclip = on
    if on then
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
        pcall(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                        p.CanCollide = true
                    end
                end
            end
        end)
    end
end

-- ==================== 加速系统 (Heartbeat 驱动) ====================
local function setWalkSpeed(on, speed)
    wsActive = on wsSpeed = speed
    if on then
        TaskManager.start("WalkSpeed", 0.3, function()
            local h = getHum()
            if h then h.WalkSpeed = wsSpeed end
        end)
    else
        TaskManager.stop("WalkSpeed")
        local h = getHum()
        if h then h.WalkSpeed = 16 end
    end
end

-- ==================== 跳跃处理 ====================
UserInputService.JumpRequest:Connect(function()
    if flyState then
        flyUp = true
        tdelay(0.3, function() flyUp = false end)
    elseif Flags.InfJ then
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ==================== 加载界面 ====================
local loadScreen = make("Frame", { Parent = sg, BackgroundColor3 = C.BG, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0) })
corner(loadScreen, 0)
gradient(loadScreen, C.BG, C.BG2, 90)

local titleL = make("TextLabel", { Parent = loadScreen, BackgroundTransparency = 1, Position = UDim2.new(0.5, -120, 0.3, 0), Size = UDim2.new(0, 240, 0, 46), Font = Enum.Font.GothamBold, Text = "ypx Hub", TextColor3 = C.White, TextSize = 28 })
stroke(titleL, C.Blue, 1.5, 0.3)
local subL = make("TextLabel", { Parent = loadScreen, BackgroundTransparency = 1, Position = UDim2.new(0.5, -120, 0.3, 50), Size = UDim2.new(0, 240, 0, 18), Font = Enum.Font.GothamSemibold, Text = "© ypx  ·  v8.0 Heartbeat引擎", TextColor3 = C.Gold, TextSize = 13 })
local statusText = make("TextLabel", { Parent = loadScreen, BackgroundTransparency = 1, Position = UDim2.new(0.5, -140, 0.46, 10), Size = UDim2.new(0, 280, 0, 22), Font = Enum.Font.GothamSemibold, Text = "正在初始化...", TextColor3 = C.Gray, TextSize = 13 })
local countdownText = make("TextLabel", { Parent = loadScreen, BackgroundTransparency = 1, Position = UDim2.new(0.5, -140, 0.46, 36), Size = UDim2.new(0, 280, 0, 30), Font = Enum.Font.GothamBold, Text = "3", TextColor3 = C.BlueL, TextSize = 24 })
local barBg = make("Frame", { Parent = loadScreen, BackgroundColor3 = C.Track, BorderSizePixel = 0, Position = UDim2.new(0.5, -130, 0.46, 74), Size = UDim2.new(0, 260, 0, 6) })
corner(barBg, 99)
local barFill = make("Frame", { Parent = barBg, BackgroundColor3 = C.Blue, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0) })
corner(barFill, 99)
gradient(barFill, C.Blue, C.BlueL, 0)
local gameNameText = make("TextLabel", { Parent = loadScreen, BackgroundTransparency = 1, Position = UDim2.new(0.5, -140, 0.46, 92), Size = UDim2.new(0, 280, 0, 18), Font = Enum.Font.GothamSemibold, Text = "", TextColor3 = C.Green, TextSize = 12 })

-- ==================== 游戏检测 ====================
local function getGameInfo()
    local pid = game.PlaceId local pn = "未知" local done = false
    tspawn(function() pcall(function() local i = game:GetService("MarketplaceService"):GetProductInfo(pid) if i and i.Name then pn = i.Name end end) done = true end)
    local t = 0 while not done and t < 2 do twait(0.1) t = t + 0.1 end
    return pid, pn
end

local GameDB = { [7295742428] = "anime_incremental" }
local KeywordDB = {
    { keyword = "anime incremental", type = "anime_incremental" },
    { keyword = "incremental", type = "anime_incremental" },
}
local function detectGameType()
    local pid, pn = getGameInfo()
    if GameDB[pid] then return GameDB[pid], pn, pid end
    local ln = string.lower(pn)
    for _, e in pairs(KeywordDB) do if string.find(ln, e.keyword) then return e.type, pn, pid end end
    return "universal", pn, pid
end

-- ==================== UI组件 ====================
local tabBtns = {}
local tabPages = {}

local function toggle(parent, text, def, cb)
    Flags[text] = def or false
    local h = make("Frame", { Parent = parent, BackgroundColor3 = C.Card, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 36) })
    corner(h, 9) stroke(h, C.Div, 1)
    gradient(h, C.Card, C.CardH, 90)
    make("TextLabel", { Parent = h, BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -60, 1, 0), Font = Enum.Font.GothamSemibold, Text = text, TextColor3 = C.White, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
    local tog = make("TextButton", { Parent = h, BackgroundColor3 = def and C.On or C.Off, BorderSizePixel = 0, Position = UDim2.new(1, -44, 0.5, -10), Size = UDim2.new(0, 36, 0, 20), Text = "", AutoButtonColor = false })
    corner(tog, 99)
    local knob = make("Frame", { Parent = tog, BackgroundColor3 = C.White, BorderSizePixel = 0, Size = UDim2.new(0, 14, 0, 14), Position = def and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) })
    corner(knob, 99) stroke(knob, C.Div, 0.5, 0.5)
    local state = def or false
    local function set(v)
        state = v Flags[text] = v
        tw(tog, {BackgroundColor3 = v and C.On or C.Off})
        tw(knob, {Position = v and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)})
        if cb then pcall(cb, v) end
    end
    tog.MouseButton1Click:Connect(function() set(not state) end)
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then set(not state) end
    end)
    return { set = set, get = function() return state end }
end

local function slider(parent, text, mn, mx, def, cb)
    local h = make("Frame", { Parent = parent, BackgroundColor3 = C.Card, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 44) })
    corner(h, 9) stroke(h, C.Div, 1)
    gradient(h, C.Card, C.CardH, 90)
    make("TextLabel", { Parent = h, BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 3), Size = UDim2.new(1, -60, 0, 16), Font = Enum.Font.GothamSemibold, Text = text, TextColor3 = C.White, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
    local valL = make("TextLabel", { Parent = h, BackgroundTransparency = 1, Position = UDim2.new(1, -50, 0, 3), Size = UDim2.new(0, 38, 0, 16), Font = Enum.Font.GothamBold, Text = tostring(def), TextColor3 = C.BlueL, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right })
    local track = make("Frame", { Parent = h, BackgroundColor3 = C.Track, BorderSizePixel = 0, Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -24, 0, 10) })
    corner(track, 99)
    local pct = (def - mn) / (mx - mn)
    local fill = make("Frame", { Parent = track, BackgroundColor3 = C.Blue, BorderSizePixel = 0, Size = UDim2.new(pct, 0, 1, 0) })
    corner(fill, 99) gradient(fill, C.BlueD, C.BlueL, 0)
    local knob = make("Frame", { Parent = track, BackgroundColor3 = C.White, BorderSizePixel = 0, Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(pct, -7, 0.5, -7) })
    corner(knob, 99) stroke(knob, C.BlueD, 1.5, 0.2)
    gradient(knob, C.White, Color3.fromRGB(210, 215, 225), 90)
    local sd = false
    local function upd(i)
        local p = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor(mn + (mx - mn) * p + 0.5)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, -7, 0.5, -7)
        valL.Text = tostring(v)
        if cb then cb(v) end
    end
    track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sd = true upd(i) end end)
    knob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sd = true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sd = false end end)
    UserInputService.InputChanged:Connect(function(i) if sd and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end end)
end

local function button(parent, text, cb)
    local b = make("TextButton", { Parent = parent, BackgroundColor3 = C.Card, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 32), Font = Enum.Font.GothamSemibold, Text = text, TextColor3 = C.White, TextSize = 11, AutoButtonColor = false })
    corner(b, 9) stroke(b, C.Div, 1) gradient(b, C.Card, C.CardH, 90)
    b.MouseEnter:Connect(function() tw(b, {BackgroundColor3 = C.CardH}) end)
    b.MouseLeave:Connect(function() tw(b, {BackgroundColor3 = C.Card}) end)
    b.MouseButton1Click:Connect(function()
        tw(b, {BackgroundColor3 = C.BlueD}, 0.06)
        tdelay(0.1, function() tw(b, {BackgroundColor3 = C.Card}, 0.06) end)
        if cb then pcall(cb) end
    end)
end

local function label(parent, text)
    make("TextLabel", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 20), Font = Enum.Font.GothamBold, Text = text, TextColor3 = C.BlueX, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
end

-- ==================== 主窗口构建 ====================
local function buildMainWindow(gameTypeName)
    local main = make("Frame", {
        Parent = sg, BackgroundColor3 = C.BG, BorderSizePixel = 0,
        Position = UDim2.new(0.5, -mainW/2, 0.5, -mainH/2), Size = UDim2.new(0, mainW, 0, mainH),
        Active = true, Visible = false, ClipsDescendants = true,
    })
    corner(main, 14) stroke(main, C.Div, 1.5, 0.3)
    gradient(main, C.BG, C.BG2, 90)

    local topbar = make("Frame", { Parent = main, BackgroundColor3 = C.Side, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40) })
    corner(topbar, 14)
    make("Frame", { Parent = topbar, BackgroundColor3 = C.Side, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14) })
    gradient(topbar, C.Side, C.SideH, 90)

    make("TextLabel", { Parent = topbar, BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0, 120, 1, 0), Font = Enum.Font.GothamBold, Text = "ypx Hub", TextColor3 = C.White, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left })
    make("TextLabel", { Parent = topbar, BackgroundTransparency = 1, Position = UDim2.new(1, -190, 0, 0), Size = UDim2.new(0, 90, 1, 0), Font = Enum.Font.GothamSemibold, Text = gameTypeName, TextColor3 = C.BlueL, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right })
    make("TextLabel", { Parent = topbar, BackgroundTransparency = 1, Position = UDim2.new(1, -96, 0, 0), Size = UDim2.new(0, 44, 1, 0), Font = Enum.Font.GothamSemibold, Text = "©ypx", TextColor3 = C.Gold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right })

    local minBtn = make("TextButton", { Parent = topbar, BackgroundColor3 = C.Off, BorderSizePixel = 0, Position = UDim2.new(1, -46, 0.5, -10), Size = UDim2.new(0, 20, 0, 20), Font = Enum.Font.GothamBold, Text = "—", TextColor3 = C.Gray, TextSize = 13, AutoButtonColor = false })
    corner(minBtn, 6)
    local closeBtn = make("TextButton", { Parent = topbar, BackgroundColor3 = C.Red, BorderSizePixel = 0, Position = UDim2.new(1, -22, 0.5, -10), Size = UDim2.new(0, 20, 0, 20), Font = Enum.Font.GothamBold, Text = "×", TextColor3 = C.White, TextSize = 13, AutoButtonColor = false })
    corner(closeBtn, 6)

    drag(main, topbar)

    local sideW = 110
    local sidebar = make("Frame", { Parent = main, BackgroundColor3 = C.Side, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(0, sideW, 1, -40) })
    make("Frame", { Parent = sidebar, BackgroundColor3 = C.Div, BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0) })
    local sideList = make("Frame", { Parent = sidebar, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) })
    make("UIListLayout", { Parent = sideList, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center })
    pad(sideList, 6, 6, 0, 0)

    local content = make("Frame", { Parent = main, BackgroundColor3 = C.BG, BorderSizePixel = 0, Position = UDim2.new(0, sideW, 0, 40), Size = UDim2.new(1, -sideW, 1, -40), ClipsDescendants = true })

    -- 最小化/恢复
    local minState = false
    minBtn.MouseButton1Click:Connect(function()
        minState = not minState
        tw(minBtn, {BackgroundColor3 = C.BlueD}, 0.08)
        tdelay(0.1, function() tw(minBtn, {BackgroundColor3 = C.Off}, 0.08) end)
        if minState then
            sidebar.Visible = false
            content.Visible = false
            tw(main, {Size = UDim2.new(0, 220, 0, 40)}, 0.22)
        else
            tw(main, {Size = UDim2.new(0, mainW, 0, mainH)}, 0.22)
            tdelay(0.22, function()
                sidebar.Visible = true
                content.Visible = true
                for _, b in pairs(tabBtns) do b.Visible = true end
                for _, p in pairs(tabPages) do p.Visible = false end
                if tabPages[1] then tabPages[1].Visible = true end
                for _, b in pairs(tabBtns) do tw(b, {BackgroundColor3 = C.Side, TextColor3 = C.Gray}) end
                if tabBtns[1] then tw(tabBtns[1], {BackgroundColor3 = C.BlueD, TextColor3 = C.White}) end
            end)
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        tw(main, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.2)
        tdelay(0.25, function()
            TaskManager.stopAll()
            VisualFX.clear()
            stopFly() setNoclip(false) wsActive = false
            sg:Destroy()
        end)
    end)

    return main, sideList, content
end

-- ==================== 标签页系统 ====================
local function newTab(sidebar, content, name, icon)
    local btn = make("TextButton", {
        Parent = sidebar, BackgroundColor3 = C.Side, BorderSizePixel = 0,
        Size = UDim2.new(1, -6, 0, 30), Font = Enum.Font.GothamSemibold,
        Text = "  " .. (icon or "●") .. "  " .. name, TextColor3 = C.Gray, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
    })
    corner(btn, 8)
    local page = make("ScrollingFrame", {
        Parent = content, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0), ScrollBarThickness = 3, ScrollBarImageColor3 = C.Blue,
        CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false, ScrollBarImageTransparency = 0.3,
    })
    make("UIListLayout", { Parent = page, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center })
    pad(page, 8, 8, 4, 4)
    pcall(function() page.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    table.insert(tabBtns, btn)
    table.insert(tabPages, page)
    local function sel()
        for _, b in pairs(tabBtns) do tw(b, {BackgroundColor3 = C.Side, TextColor3 = C.Gray}) end
        for _, p in pairs(tabPages) do p.Visible = false end
        tw(btn, {BackgroundColor3 = C.BlueD, TextColor3 = C.White})
        page.Visible = true
        tspawn(function()
            twait(0.05)
            pcall(function()
                local l = page:FindFirstChildOfClass("UIListLayout")
                if l then page.CanvasSize = UDim2.new(0, 0, 0, l.AbsoluteContentSize.Y + 16) end
            end)
        end)
    end
    btn.MouseButton1Click:Connect(sel)
    if #tabBtns == 1 then sel() end
    return page
end

-- ==================== 自动化功能 (Heartbeat 驱动, 替代 while 循环) ====================
local AutoState = {}

-- [自动点击/训练] 三种方式: 1.VirtualInputManager模拟 2.GUI按钮点击 3.ClickDetector
local function startAutoClick(interval)
    AutoState.AutoClick = true
    TaskManager.start("AutoClick", interval, function()
        -- 方式1: 模拟屏幕点击 (最通用, 移动端兼容)
        tapScreen()
        -- 方式2: 尝试点击训练按钮 (如果有)
        pcall(function() clickButton("train") clickButton("click") clickButton("attack") clickButton("punch") end)
        -- 方式3: 触发ClickDetector
        if hasFCD then
            pcall(function()
                for _, cd in pairs(cdCache) do
                    if cd and cd.Parent then fireclickdetector(cd) end
                end
            end)
        end
    end)
end

-- [自动农场] CFrame传送到最近NPC身边 (Heartbeat驱动 + 视觉高亮)
local function startAutoFarm(distance)
    AutoState.AutoFarm = true
    local safePos = nil
    local root = getRoot()
    if root then safePos = root.Position end
    TaskManager.start("AutoFarm", 0.5, function()
        local enemy = findNearestEnemy()
        if enemy then
            local r = getRoot()
            if r then
                if not safePos then safePos = r.Position end
                -- 传送到敌人上方 (避免卡住)
                r.CFrame = enemy.CFrame * CFrame.new(0, distance or 5, 0)
                r.Velocity = Vector3.zero
                -- 同时模拟攻击
                tapScreen()
                -- 视觉高亮目标 (老外脚本特色)
                VisualFX.highlightTarget(enemy)
            end
        else
            -- 没敌人就回安全位置, 清除高亮
            VisualFX.clear()
            local r = getRoot()
            if r and safePos then
                r.CFrame = CFrame.new(safePos)
            end
        end
    end)
end

-- [自动重生] 点击GUI重生按钮 (不盲发Remote)
local function startAutoRebirth()
    AutoState.AutoRebirth = true
    TaskManager.start("AutoRebirth", 1, function()
        local clicked = false
        clicked = clickButton("rebirth") or clicked
        clicked = clickButton("prestige") or clicked
        clicked = clickButton("reset") or clicked
        clicked = clickButton("重生") or clicked
        clicked = clickButton("转生") or clicked
        if not clicked then
            local r = getRemoteFuzzy("rebirth", "prestige", "reset")
            if r then fireRemote(r) end
        end
    end)
end

-- [自动购买升级] 点击GUI商店按钮 (不盲发Remote)
local function startAutoBuy()
    AutoState.AutoBuy = true
    TaskManager.start("AutoBuy", 0.5, function()
        local clicked = false
        clicked = clickButton("buy") or clicked
        clicked = clickButton("upgrade") or clicked
        clicked = clickButton("purchase") or clicked
        clicked = clickButton("购买") or clicked
        clicked = clickButton("升级") or clicked
        clicked = clickButton("max") or clicked
        if not clicked then
            local r = getRemoteFuzzy("buy", "upgrade", "purchase")
            if r then fireRemote(r, 1) end
        end
    end)
end

-- [自动领取奖励] 点击GUI领取按钮
local function startAutoClaim()
    AutoState.AutoClaim = true
    TaskManager.start("AutoClaim", 2, function()
        local clicked = false
        clicked = clickButton("claim") or clicked
        clicked = clickButton("reward") or clicked
        clicked = clickButton("领取") or clicked
        if not clicked then
            local r = getRemoteFuzzy("claim", "reward")
            if r then fireRemote(r) end
        end
    end)
end

-- [自动抽卡] 点击GUI抽卡按钮
local function startAutoCard()
    AutoState.AutoCard = true
    TaskManager.start("AutoCard", 0.5, function()
        local clicked = false
        clicked = clickButton("roll") or clicked
        clicked = clickButton("reroll") or clicked
        clicked = clickButton("pull") or clicked
        clicked = clickButton("card") or clicked
        clicked = clickButton("open") or clicked
        clicked = clickButton("抽卡") or clicked
        clicked = clickButton("重抽") or clicked
        if not clicked then
            local r = getRemoteFuzzy("card", "roll", "reroll", "pull", "open")
            if r then fireRemote(r) end
        end
    end)
end

-- [自动装备最佳] 点击GUI装备按钮
local function startAutoEquip()
    AutoState.AutoEquip = true
    TaskManager.start("AutoEquip", 1, function()
        local clicked = false
        clicked = clickButton("equip") or clicked
        clicked = clickButton("equipbest") or clicked
        clicked = clickButton("equip best") or clicked
        clicked = clickButton("装备") or clicked
        if not clicked then
            local r = getRemoteFuzzy("equip", "equipcard")
            if r then fireRemote(r, "best") end
        end
    end)
end

-- [自动出售低级] 点击GUI出售按钮
local function startAutoSell()
    AutoState.AutoSell = true
    TaskManager.start("AutoSell", 2, function()
        local clicked = false
        clicked = clickButton("sell") or clicked
        clicked = clickButton("delete") or clicked
        clicked = clickButton("出售") or clicked
        if not clicked then
            local r = getRemoteFuzzy("sell", "delete")
            if r then fireRemote(r, "low") end
        end
    end)
end

-- [自动天赋点] 点击GUI天赋按钮
local function startAutoPerk()
    AutoState.AutoPerk = true
    TaskManager.start("AutoPerk", 0.5, function()
        local clicked = false
        clicked = clickButton("perk") or clicked
        clicked = clickButton("talent") or clicked
        clicked = clickButton("skill") or clicked
        clicked = clickButton("invest") or clicked
        clicked = clickButton("天赋") or clicked
        if not clicked then
            local r = getRemoteFuzzy("perk", "skill", "talent", "invest", "allocate")
            if r then fireRemote(r, 1) end
        end
    end)
end

-- [自动药水] 点击GUI药水按钮
local function startAutoPotion()
    AutoState.AutoPotion = true
    TaskManager.start("AutoPotion", 2, function()
        local clicked = false
        clicked = clickButton("use") or clicked
        clicked = clickButton("drink") or clicked
        clicked = clickButton("potion") or clicked
        clicked = clickButton("使用") or clicked
        if not clicked then
            local r = getRemoteFuzzy("use", "activate", "drink")
            if r then fireRemote(r, "potion") end
        end
    end)
end

-- [自动宝箱] 传送到宝箱位置 (不盲发Remote)
local function startAutoChest()
    AutoState.AutoChest = true
    TaskManager.start("AutoChest", 2, function()
        local chests = findChests()
        local root = getRoot()
        if root and #chests > 0 then
            for _, chest in pairs(chests) do
                if not AutoState.AutoChest then break end
                if chest and chest.Parent then
                    pcall(function()
                        root.CFrame = chest.CFrame + Vector3.new(0, 3, 0)
                        root.Velocity = Vector3.zero
                    end)
                    twait(0.5)
                end
            end
        end
    end)
end

-- ==================== 维护标签页 ====================
local function buildMaintenanceTab(sidebar, content)
    local tm = newTab(sidebar, content, "维护", "🔧")

    label(tm, "—— 运行状态 ——")
    local sl = make("TextLabel", { Parent = tm, BackgroundColor3 = C.Card, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 28), Font = Enum.Font.GothamSemibold, Text = "  ✅ v8.0 Heartbeat引擎运行中", TextColor3 = C.Green, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
    corner(sl, 8) stroke(sl, C.Div, 1)

    label(tm, "—— 紧急操作 ——")
    button(tm, "🛑 紧急停止所有功能", function()
        for k in pairs(AutoState) do AutoState[k] = false end
        for k in pairs(Flags) do Flags[k] = false end
        twait(0.2)
        TaskManager.stopAll()
        VisualFX.clear()
        stopAllConns()
        stopFly()
        setNoclip(false)
        wsActive = false
        pcall(function()
            local h = getHum()
            local c = LocalPlayer.Character
            if h then h.WalkSpeed = 16 h.PlatformStand = false end
            if c then
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                        p.CanCollide = true
                    end
                end
            end
        end)
        showNotif("已紧急停止所有功能", C.Red)
    end)
    button(tm, "🔄 恢复角色状态", function()
        pcall(function()
            local h = getHum()
            if h then h.WalkSpeed = 16 h.PlatformStand = false end
            local c = LocalPlayer.Character
            if c then
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                        p.CanCollide = true
                    end
                end
            end
            local r = getRoot()
            if r then
                for _, o in pairs(r:GetChildren()) do
                    if o:IsA("BodyVelocity") or o:IsA("BodyGyro") then o:Destroy() end
                end
            end
        end)
        showNotif("角色状态已恢复", C.Green)
    end)

    label(tm, "—— 视觉清理 ——")
    button(tm, "🧹 清理全部特效", function()
        local cnt = 0
        pcall(function()
            for _, o in pairs(Workspace:GetDescendants()) do
                if o:IsA("ParticleEmitter") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Trail") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Beam") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Fire") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Smoke") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Sparkles") then o.Enabled = false cnt = cnt + 1
                end
            end
            for _, o in pairs(Lighting:GetChildren()) do
                if o:IsA("ColorCorrectionEffect") or o:IsA("BloomEffect") or o:IsA("BlurEffect") then
                    o.Enabled = false cnt = cnt + 1
                end
            end
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
        end)
        showNotif("已清理 " .. cnt .. " 个特效", C.Purple)
    end)

    label(tm, "—— 远程日志 ——")
    local logScroll = make("ScrollingFrame", {
        Parent = tm, BackgroundColor3 = C.BG2, BorderSizePixel = 0,
        Size = UDim2.new(1, -4, 0, 130), ScrollBarThickness = 3, ScrollBarImageColor3 = C.Blue,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    })
    corner(logScroll, 8) stroke(logScroll, C.Div, 1)
    pcall(function() logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)

    local logText = make("TextLabel", {
        Parent = logScroll, BackgroundTransparency = 1,
        Size = UDim2.new(1, -10, 0, 0), Position = UDim2.new(0, 5, 0, 5),
        Font = Enum.Font.Code, Text = "点击下方按钮查看远程事件", TextColor3 = C.Gray, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    })
    pcall(function() logText.AutomaticSize = Enum.AutomaticSize.Y end)

    button(tm, "📋 打印远程事件", function()
        local lines = {}
        for name, r in pairs(remoteCache) do
            local fn = name
            pcall(function() fn = r:GetFullName() end)
            table.insert(lines, fn .. "  [" .. r.ClassName .. "]")
        end
        table.sort(lines)
        if #lines > 0 then
            logText.Text = table.concat(lines, "\n")
            logText.TextColor3 = C.White
        else
            logText.Text = "未找到远程事件"
            logText.TextColor3 = C.Orange
        end
        showNotif("找到 " .. #lines .. " 个远程", C.Blue)
    end)
    button(tm, "🔄 重新扫描游戏", function()
        remoteCache = {}
        buttonCache = {}
        cdCache = {}
        scanRemotes()
        scanButtons()
        scanClickDetectors()
        local cnt = 0 for _ in pairs(remoteCache) do cnt = cnt + 1 end
        logText.Text = "已重新扫描 · " .. cnt .. " 个远程"
        logText.TextColor3 = C.Green
        showNotif("已重新扫描 " .. cnt .. " 个远程", C.Green)
    end)

    label(tm, "—— 关于 ——")
    local ab = make("TextLabel", { Parent = tm, BackgroundColor3 = C.Card, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 50), Font = Enum.Font.GothamSemibold, Text = "  ypx Hub v8.0 © ypx\n  Heartbeat引擎 · 基于rscripts.net/scriptblox.com模式\n  RightShift 显隐 · 悬浮按钮可拖 · 目标高亮", TextColor3 = C.Gray, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
    corner(ab, 8) stroke(ab, C.Div, 1)
end

-- ==================== 通用菜单 ====================
local function buildUniversalMenu(sidebar, content, gameName)
    local tp = newTab(sidebar, content, "玩家", "🎮")
    label(tp, "—— 飞行 ——")
    toggle(tp, "飞行", false, function(v) if v then startFly() else stopFly() end end)
    slider(tp, "飞行速度", 10, 500, 60, function(v) flySpeed = v end)

    label(tp, "—— 移动 ——")
    toggle(tp, "加速", false, function(v) setWalkSpeed(v, wsSpeed) end)
    slider(tp, "移动速度", 16, 500, 50, function(v) wsSpeed = v if wsActive then local h = getHum() if h then h.WalkSpeed = v end end end)
    toggle(tp, "无限跳跃", false, function(v) Flags.InfJ = v end)
    toggle(tp, "防挂机", false, function(v)
        if v then pcall(function() LocalPlayer.Idled:Connect(function() pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end) end) end) end
    end)

    label(tp, "—— 身体 ——")
    toggle(tp, "穿墙", false, function(v) setNoclip(v) end)

    label(tp, "—— 通用自动化 ——")
    local clickInterval = 0.5
    toggle(tp, "自动点击(通用)", false, function(v) if v then startAutoClick(clickInterval) else AutoState.AutoClick = false TaskManager.stop("AutoClick") end end)
    slider(tp, "点击间隔(秒)", 0.1, 5, 0.5, function(v) clickInterval = v end)
    toggle(tp, "自动农场(传送)", false, function(v) if v then startAutoFarm(5) else AutoState.AutoFarm = false TaskManager.stop("AutoFarm") VisualFX.clear() end end)
    toggle(tp, "自动宝箱", false, function(v) if v then startAutoChest() else AutoState.AutoChest = false TaskManager.stop("AutoChest") end end)

    local tt = newTab(sidebar, content, "传送", "📍")
    label(tt, "—— 快速传送 ——")
    button(tt, "🏠 出生点", function() local c = LocalPlayer.Character if c and c:FindFirstChild("HumanoidRootPart") then local s = Workspace:FindFirstChild("SpawnLocation") c.HumanoidRootPart.CFrame = s and (s.CFrame + Vector3.new(0, 5, 0)) or CFrame.new(0, 50, 0) end end)
    button(tt, "☁️ 上飞100", function() local r = getRoot() if r then r.CFrame = r.CFrame + Vector3.new(0, 100, 0) end end)
    button(tt, "⬇️ 下落50", function() local r = getRoot() if r then r.CFrame = r.CFrame - Vector3.new(0, 50, 0) end end)
    button(tt, "🎯 鼠标位置", function() local r = getRoot() local m = LocalPlayer:GetMouse() if r and m.Hit then r.CFrame = CFrame.new(m.Hit.Position + Vector3.new(0, 5, 0)) end end)

    local tv = newTab(sidebar, content, "视觉", "🎨")
    label(tv, "—— 画面优化 ——")
    toggle(tv, "帧率提升", false, function(v)
        if v then pcall(function()
            for _, o in pairs(Workspace:GetDescendants()) do
                if o:IsA("BasePart") then o.Material = Enum.Material.Plastic o.Reflectance = 0
                elseif o:IsA("Decal") or o:IsA("Texture") then o.Transparency = 1
                elseif o:IsA("ParticleEmitter") or o:IsA("Trail") then o.Enabled = false end
            end
            Lighting.GlobalShadows = false Lighting.FogEnd = 9e9
        end) end
    end)
    toggle(tv, "全亮", false, function(v) Flags.FB = v if v then TaskManager.start("FullBright", 1, function() Lighting.ClockTime = 14 Lighting.Brightness = 2 end) else TaskManager.stop("FullBright") end end)

    buildMaintenanceTab(sidebar, content)
end

-- ==================== Anime Incremental 专用菜单 ====================
local function buildAnimeMenu(sidebar, content, gameName)
    -- 自动化标签
    local t1 = newTab(sidebar, content, "自动化", "⚡")
    label(t1, "—— 自动训练/攻击 ——")
    local clickD = 0.5
    toggle(t1, "自动点击训练", false, function(v)
        if v then startAutoClick(clickD) else AutoState.AutoClick = false TaskManager.stop("AutoClick") end
    end)
    slider(t1, "点击间隔(秒)", 0.1, 3, 0.5, function(v) clickD = v end)

    label(t1, "—— 自动农场 ——")
    local farmDist = 5
    toggle(t1, "自动农场(传送杀怪)", false, function(v)
        if v then startAutoFarm(farmDist) else AutoState.AutoFarm = false TaskManager.stop("AutoFarm") VisualFX.clear() end
    end)
    slider(t1, "农场高度", 1, 20, 5, function(v) farmDist = v end)

    label(t1, "—— 自动升级 ——")
    toggle(t1, "自动购买升级", false, function(v)
        if v then startAutoBuy() else AutoState.AutoBuy = false TaskManager.stop("AutoBuy") end
    end)
    toggle(t1, "自动重生/转生", false, function(v)
        if v then startAutoRebirth() else AutoState.AutoRebirth = false TaskManager.stop("AutoRebirth") end
    end)

    label(t1, "—— 自动领取 ——")
    toggle(t1, "自动领取奖励", false, function(v)
        if v then startAutoClaim() else AutoState.AutoClaim = false TaskManager.stop("AutoClaim") end
    end)
    toggle(t1, "自动宝箱", false, function(v)
        if v then startAutoChest() else AutoState.AutoChest = false TaskManager.stop("AutoChest") end
    end)

    -- 卡牌标签
    local t2 = newTab(sidebar, content, "卡牌", "🎴")
    label(t2, "—— 卡牌自动化 ——")
    toggle(t2, "自动抽卡(Reroll)", false, function(v)
        if v then startAutoCard() else AutoState.AutoCard = false TaskManager.stop("AutoCard") end
    end)
    toggle(t2, "自动装备最佳", false, function(v)
        if v then startAutoEquip() else AutoState.AutoEquip = false TaskManager.stop("AutoEquip") end
    end)
    toggle(t2, "自动出售低级", false, function(v)
        if v then startAutoSell() else AutoState.AutoSell = false TaskManager.stop("AutoSell") end
    end)
    button(t2, "🔄 一键抽卡x10", function()
        for i = 1, 10 do
            clickButton("roll") clickButton("reroll") clickButton("pull") clickButton("card")
            twait(0.1)
        end
        local r = getRemoteFuzzy("card", "roll", "reroll", "pull")
        if r then for i = 1, 10 do fireRemote(r) twait(0.05) end end
        showNotif("已抽卡x10")
    end)
    button(t2, "🔄 一键装备全部", function()
        clickButton("equip") clickButton("equipall") clickButton("equip best")
        local r = getRemoteFuzzy("equip", "equipcard")
        if r then for i = 1, 20 do fireRemote(r, i) twait(0.02) end end
        showNotif("已装备全部卡牌")
    end)

    -- 技能树标签
    local t3 = newTab(sidebar, content, "技能树", "🌳")
    label(t3, "—— 天赋/技能自动化 ——")
    toggle(t3, "自动投入天赋点", false, function(v)
        if v then startAutoPerk() else AutoState.AutoPerk = false TaskManager.stop("AutoPerk") end
    end)
    button(t3, "📱 打开技能树", function()
        clickButton("phone") clickButton("skill") clickButton("tree") clickButton("perk") clickButton("talent")
        showNotif("已尝试打开技能树")
    end)
    button(t3, "🔄 一键投入全部", function()
        clickButton("perk") clickButton("invest") clickButton("allocate") clickButton("max")
        local r = getRemoteFuzzy("perk", "skill", "talent", "invest")
        if r then for i = 1, 30 do fireRemote(r, i) twait(0.02) end end
        showNotif("已投入全部天赋点")
    end)

    -- 商店标签
    local t4 = newTab(sidebar, content, "商店", "🛒")
    label(t4, "—— 药水自动化 ——")
    toggle(t4, "自动使用药水", false, function(v)
        if v then startAutoPotion() else AutoState.AutoPotion = false TaskManager.stop("AutoPotion") end
    end)
    button(t4, "💊 一键使用药水", function()
        clickButton("use") clickButton("drink") clickButton("potion") clickButton("luck")
        local r = getRemoteFuzzy("use", "activate", "drink")
        if r then fireRemote(r, "potion") fireRemote(r, "luck") fireRemote(r, "all") end
        showNotif("已使用药水")
    end)

    label(t4, "—— 兑换码 ——")
    button(t4, "📝 一键兑换代码", function()
        local codes = {"500players","1000players","release","update","100likes","250likes","sorryfordelay","SUB2SKAR","TWITTER","DISCORD","celestialinvasion"}
        local r = getRemoteFuzzy("redeem", "code")
        if r then
            for _, c in pairs(codes) do fireRemote(r, c) twait(0.2) end
        end
        showNotif("已兑换 " .. #codes .. " 个代码")
    end)

    -- 玩家标签
    local t5 = newTab(sidebar, content, "玩家", "🎮")
    label(t5, "—— 飞行 ——")
    toggle(t5, "飞行", false, function(v) if v then startFly() else stopFly() end end)
    slider(t5, "飞行速度", 10, 500, 60, function(v) flySpeed = v end)

    label(t5, "—— 移动 ——")
    toggle(t5, "加速", false, function(v) setWalkSpeed(v, wsSpeed) end)
    slider(t5, "移动速度", 16, 500, 50, function(v) wsSpeed = v if wsActive then local h = getHum() if h then h.WalkSpeed = v end end end)
    toggle(t5, "无限跳跃", false, function(v) Flags.InfJ = v end)
    toggle(t5, "防挂机", false, function(v)
        if v then pcall(function() LocalPlayer.Idled:Connect(function() pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end) end) end) end
    end)

    label(t5, "—— 身体 ——")
    toggle(t5, "穿墙", false, function(v) setNoclip(v) end)

    -- 传送标签
    local t6 = newTab(sidebar, content, "传送", "📍")
    label(t6, "—— 快速传送 ——")
    button(t6, "🏠 出生点", function() local c = LocalPlayer.Character if c and c:FindFirstChild("HumanoidRootPart") then local s = Workspace:FindFirstChild("SpawnLocation") c.HumanoidRootPart.CFrame = s and (s.CFrame + Vector3.new(0, 5, 0)) or CFrame.new(0, 50, 0) end end)
    button(t6, "☁️ 上飞100", function() local r = getRoot() if r then r.CFrame = r.CFrame + Vector3.new(0, 100, 0) end end)
    button(t6, "⬇️ 下落50", function() local r = getRoot() if r then r.CFrame = r.CFrame - Vector3.new(0, 50, 0) end end)
    button(t6, "🎯 鼠标位置", function() local r = getRoot() local m = LocalPlayer:GetMouse() if r and m.Hit then r.CFrame = CFrame.new(m.Hit.Position + Vector3.new(0, 5, 0)) end end)

    -- 视觉标签
    local t7 = newTab(sidebar, content, "视觉", "🎨")
    label(t7, "—— 画面优化 ——")
    toggle(t7, "帧率提升", false, function(v)
        if v then pcall(function()
            for _, o in pairs(Workspace:GetDescendants()) do
                if o:IsA("BasePart") then o.Material = Enum.Material.Plastic o.Reflectance = 0
                elseif o:IsA("Decal") or o:IsA("Texture") then o.Transparency = 1
                elseif o:IsA("ParticleEmitter") or o:IsA("Trail") then o.Enabled = false end
            end
            Lighting.GlobalShadows = false Lighting.FogEnd = 9e9
        end) end
    end)
    toggle(t7, "全亮", false, function(v) Flags.FB = v if v then TaskManager.start("FullBright", 1, function() Lighting.ClockTime = 14 Lighting.Brightness = 2 end) else TaskManager.stop("FullBright") end end)

    buildMaintenanceTab(sidebar, content)
end

-- ==================== 类型映射 ====================
local TypeNames = { universal = "通用模式", anime_incremental = "Anime Inc." }

-- ==================== 加载流程 ====================
tspawn(function()
    local gameType, gameName, placeId
    local main, sidebar, content
    local loadOk, loadErr

    loadOk, loadErr = pcall(function()
        statusText.Text = "正在初始化..." twait(0.3)
        tw(barFill, {Size = UDim2.new(0, 60, 1, 0)}, 0.2)

        statusText.Text = "正在检测游戏..."
        for i = 3, 1, -1 do
            countdownText.Text = tostring(i)
            tw(countdownText, {TextSize = 28}, 0.06)
            twait(0.15)
            tw(countdownText, {TextSize = 24}, 0.06)
            twait(0.15)
        end
        tw(barFill, {Size = UDim2.new(0, 100, 1, 0)}, 0.2)

        gameType, gameName, placeId = detectGameType()
        gameNameText.Text = gameName
        statusText.Text = "检测到: " .. (TypeNames[gameType] or "通用")
        twait(0.2)
        tw(barFill, {Size = UDim2.new(0, 140, 1, 0)}, 0.2)

        -- 启动时扫描缓存 (只做一次)
        statusText.Text = "正在扫描游戏数据..."
        scanRemotes()
        scanButtons()
        scanClickDetectors()
        local remoteCount = 0 for _ in pairs(remoteCache) do remoteCount = remoteCount + 1 end
        twait(0.2)
        tw(barFill, {Size = UDim2.new(0, 200, 1, 0)}, 0.2)

        statusText.Text = "正在构建菜单..." twait(0.2)
        main, sidebar, content = buildMainWindow(TypeNames[gameType] or "通用")
        if gameType == "anime_incremental" then
            buildAnimeMenu(sidebar, content, gameName)
        else
            buildUniversalMenu(sidebar, content, gameName)
        end

        tw(barFill, {Size = UDim2.new(0, 260, 1, 0)}, 0.2)
        countdownText.Text = "✅"
        statusText.Text = "加载完成!"
        twait(0.3)
    end)

    if not loadOk then
        print("[ypx Error] " .. tostring(loadErr))
        pcall(function()
            gameType = "universal"
            gameName = "错误恢复"
            main, sidebar, content = buildMainWindow("维护模式")
            buildUniversalMenu(sidebar, content, gameName)
        end)
        pcall(function()
            countdownText.Text = "⚠️"
            statusText.Text = "维护模式启动"
            gameNameText.Text = gameName or "未知"
        end)
    end

    -- 淡出加载界面
    pcall(function()
        tw(loadScreen, {BackgroundTransparency = 1}, 0.3)
        for _, o in pairs(loadScreen:GetChildren()) do
            if o:IsA("TextLabel") then tw(o, {TextTransparency = 1}, 0.3) end
        end
        tw(barBg, {BackgroundTransparency = 1}, 0.3)
        tw(barFill, {BackgroundTransparency = 1}, 0.3)
    end)
    twait(0.35)
    pcall(function() loadScreen:Destroy() end)
    if main then main.Visible = true end

    -- 悬浮按钮
    local floatBtn = make("TextButton", {
        Parent = sg, BackgroundColor3 = C.BlueD, BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0.45, -22), Size = UDim2.new(0, 44, 0, 44),
        Font = Enum.Font.GothamBold, Text = "≡", TextColor3 = C.White, TextSize = 20,
        AutoButtonColor = false,
    })
    corner(floatBtn, 12) stroke(floatBtn, C.BlueL, 1.5, 0.2)
    gradient(floatBtn, C.BlueD, C.Blue, 90)

    local vis = true
    floatBtn.MouseButton1Click:Connect(function()
        vis = not vis
        if main then main.Visible = vis end
        tw(floatBtn, {BackgroundColor3 = vis and C.BlueD or C.Off}, 0.1)
    end)

    local fd, fs, fp
    floatBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            fd = true fs = i.Position fp = floatBtn.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then fd = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if fd and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local dl = i.Position - fs
            floatBtn.Position = UDim2.new(fp.X.Scale, fp.X.Offset + dl.X, fp.Y.Scale, fp.Y.Offset + dl.Y)
        end
    end)

    -- RightShift 显隐
    UserInputService.InputBegan:Connect(function(i, g)
        if g then return end
        if i.KeyCode == Enum.KeyCode.RightShift then
            vis = not vis
            if main then main.Visible = vis end
        end
    end)

    -- 加载通知
    local nt = loadOk and ("✅ " .. (TypeNames[gameType] or "通用") .. "  ·  v8.0 © ypx") or "⚠️ 维护模式  ·  © ypx"
    local notif = make("TextLabel", {
        Parent = sg, BackgroundColor3 = loadOk and C.BlueD or C.Orange, BorderSizePixel = 0,
        Position = UDim2.new(0.5, -130, 0, -40), Size = UDim2.new(0, 260, 0, 34),
        Font = Enum.Font.GothamSemibold, Text = "  " .. nt, TextColor3 = C.White, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(notif, 8) stroke(notif, loadOk and C.BlueD or C.Orange, 1, 0.2)
    tw(notif, {Position = UDim2.new(0.5, -130, 0, 10)}, 0.25)
    tdelay(3, function()
        tw(notif, {Position = UDim2.new(0.5, -130, 0, -40)}, 0.25)
        tdelay(0.3, function() pcall(function() notif:Destroy() end) end)
    end)

    -- 控制台输出
    print("═══════════════════════════════════")
    local rCount = 0 for _ in pairs(remoteCache) do rCount = rCount + 1 end
    local cdCount = #cdCache
    local btnCount = 0 for _ in pairs(buttonCache) do btnCount = btnCount + 1 end
    print("  ✅ ypx Hub v8.0 Heartbeat引擎已加载!")
    print("  游戏类型: " .. (TypeNames[gameType] or "通用"))
    print("  游戏名称: " .. tostring(gameName))
    print("  PlaceId: " .. tostring(placeId))
    print("  缓存: " .. rCount .. " Remote · " .. cdCount .. " ClickDetector · " .. btnCount .. " 按钮")
    print("  核心引擎: Heartbeat驱动+点击模拟+CFrame传送+目标高亮 (不盲发Remote)")
    print("  按 RightShift 或悬浮按钮 显示/隐藏")
    print("  © 2026 ypx")
    print("═══════════════════════════════════")
end)

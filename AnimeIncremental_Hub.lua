--[[
    ypx Hub v10.6 © ypx
    黑曼巴 x 福瑞 结合体
    核心技术 (基于老外脚本深度学习, 不需要截图):
      1. 通用自动发现引擎: 扫描所有TouchTransmitter+ProximityPrompt+ClickDetector
      2. ProximityPromptService全局绕过长按 (老外技术)
      3. firetouchinterest带3次重试 (老外技术)
      4. Remote自动发现: 正则+模糊匹配+超时保护 (老外技术)
      5. leaderstats自动发现 + delta数据快照检测 (老外技术)
      6. CollectionService标签扫描 (老外技术)
      7. CharacterAdded重连 (老外技术)
      8. 全能自动模式: 一键扫描交互所有可交互物体
      9. 符文系统 (原卡牌): 全面改名+功能修复
      10. ESP透视引擎: BillboardGui+Highlight透视敌人/物品/玩家 (v10.6新引擎)
      11. 反挂机引擎: VirtualUser+IdleTime重置防AFK踢出 (v10.6新引擎)
      12. FPS监控 + UI模板技术
      13. 日志系统: 扫描全game + 可交互物体扫描
      14. Heartbeat引擎驱动所有循环
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
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ==================== 工具 ====================
local twait = task.wait or wait
local tspawn = task.spawn or function(f) coroutine.wrap(f)() end
local tdelay = task.delay or delay

local function getGuiParent()
    local ok, cg = pcall(function() return CoreGui end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()
pcall(function() local o = guiParent:FindFirstChild("ypxHub") if o then o:Destroy() end end)

local hasFCD = type(fireclickdetector) == "function"
local hasClip = type(setclipboard) == "function"
local hasFireSignal = type(firesignal) == "function"
local hasFireTouch = type(firetouchinterest) == "function"
local hasFireProx = type(fireproximityprompt) == "function"

-- ==================== 颜色主题 (UI模板) ====================
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

-- ==================== UI辅助 (模板技术) ====================
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

-- ==================== 核心动作函数 ====================
local function getHum() local c = LocalPlayer.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end

-- ==================== 通用自动发现引擎 (老外脚本核心技术) ====================
-- 不写死关键词, 而是自动扫描所有可交互物体: TouchTransmitter + ProximityPrompt + ClickDetector
-- 这是老外通用脚本的核心: 不管什么游戏都能自动找到可交互物体

-- [全局] ProximityPromptService 绕过长按 (老外技术: 全局HoldDuration=0)
pcall(function()
    local PPS = game:GetService("ProximityPromptService")
    PPS.PromptButtonHoldBegan:Connect(function(prompt)
        pcall(function() prompt.HoldDuration = 0 end)
    end)
end)

-- [通用] 扫描所有 TouchTransmitter (老外技术: IsA("TouchTransmitter") 找所有可触摸物体)
-- TouchTransmitter 是 TouchInterest 在引擎中的实际类名
local function scanAllTouchables()
    local results = {}
    pcall(function()
        for _, o in pairs(Workspace:GetDescendants()) do
            if o:IsA("TouchTransmitter") and o.Parent and o.Parent:IsA("BasePart") then
                -- 排除玩家自己的角色
                if not o.Parent:IsDescendantOf(LocalPlayer.Character or Instance.new("Folder")) then
                    table.insert(results, o.Parent)
                end
            end
        end
    end)
    return results
end

-- [通用] 扫描所有 ProximityPrompt (老外技术: 找所有可交互提示)
local function scanAllPrompts()
    local results = {}
    pcall(function()
        for _, o in pairs(Workspace:GetDescendants()) do
            if o:IsA("ProximityPrompt") and o.Enabled and o.Parent then
                if o.Parent:IsA("BasePart") then
                    if not o.Parent:IsDescendantOf(LocalPlayer.Character or Instance.new("Folder")) then
                        table.insert(results, { prompt = o, part = o.Parent })
                    end
                end
            end
        end
    end)
    return results
end

-- [通用] 扫描所有 ClickDetector
local function scanAllClickDetectors()
    local results = {}
    pcall(function()
        for _, o in pairs(Workspace:GetDescendants()) do
            if o:IsA("ClickDetector") and o.Parent then
                local part = o.Parent:IsA("BasePart") and o.Parent or o.Parent:FindFirstChildWhichIsA("BasePart")
                if part and not part:IsDescendantOf(LocalPlayer.Character or Instance.new("Folder")) then
                    table.insert(results, { cd = o, part = part })
                end
            end
        end
    end)
    return results
end

-- [通用] 扫描Workspace中指定关键词的物体 (兼容旧逻辑, 作为补充)
local function findObjects(keywords)
    local results = {}
    pcall(function()
        for _, o in pairs(Workspace:GetDescendants()) do
            if o:IsA("BasePart") or o:IsA("Model") then
                local name = string.lower(o.Name)
                for _, kw in pairs(keywords) do
                    if string.find(name, kw) then
                        local part = o:IsA("Model") and (o:FindFirstChild("HumanoidRootPart") or o:FindFirstChildWhichIsA("BasePart")) or o
                        if part and part:IsA("BasePart") then
                            table.insert(results, part)
                        end
                        break
                    end
                end
            end
        end
    end)
    return results
end

-- [通用] 扫描 CollectionService 标签 (老外技术: 用标签找物体)
local function scanByTags()
    local results = {}
    pcall(function()
        local CS = game:GetService("CollectionService")
        for _, tag in ipairs({"Chest", "Reward", "Pickup", "Collectible", "Item", "Enemy", "NPC", "Mob", "Boss", "Training"}) do
            for _, obj in ipairs(CS:GetTagged(tag)) do
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part then table.insert(results, part) end
            end
        end
    end)
    return results
end

-- [通用] 自动发现 leaderstats (老外技术: 扫描所有ValueBase)
local leaderstatsCache = {}
local function scanLeaderstats()
    leaderstatsCache = {}
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, v in pairs(ls:GetChildren()) do
                if v:IsA("ValueBase") then
                    leaderstatsCache[string.lower(v.Name)] = v
                end
            end
        end
        -- 也扫描 player 下的所有 ValueBase
        for _, v in pairs(LocalPlayer:GetChildren()) do
            if v:IsA("ValueBase") then
                leaderstatsCache[string.lower(v.Name)] = v
            end
        end
    end)
    return leaderstatsCache
end

-- [通用] 数据快照 (老外技术: delta detection, 操作前后对比验证)
local function snapshotStats()
    local snap = {}
    for name, v in pairs(leaderstatsCache) do
        if v and v.Parent then
            pcall(function() snap[name] = v.Value end)
        end
    end
    return snap
end

local function deltaChanged(before, after)
    for name, val in pairs(before) do
        if after[name] and after[name] ~= val then
            return true, name
        end
    end
    return false
end

-- [通用] 找最近的物体
local function findNearest(targets)
    local root = getRoot()
    if not root then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, t in pairs(targets) do
        if t and t.Parent then
            pcall(function()
                local dist = (t.Position - root.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = t
                end
            end)
        end
    end
    return nearest
end

-- [通用] 传送到物体旁
local function teleportTo(part, offset)
    local root = getRoot()
    if not root or not part then return false end
    pcall(function()
        root.CFrame = part.CFrame * CFrame.new(offset or Vector3.new(0, 3, 0))
        root.Velocity = Vector3.zero
    end)
    return true
end

-- [通用] 触摸物体 (老外技术: firetouchinterest 带3次重试)
local function fireTouch(part)
    local root = getRoot()
    if not root or not part then return end
    if hasFireTouch then
        for _ = 1, 3 do
            local ok = pcall(function()
                firetouchinterest(root, part, 0)
                task.wait(0.004)
                firetouchinterest(root, part, 1)
            end)
            if ok then break end
            task.wait(0.01)
        end
    else
        pcall(function() root.CFrame = part.CFrame end)
    end
end

-- [通用] 触发ProximityPrompt (老外技术: fireproximityprompt + InputHold模拟)
local function fireProximity(part)
    pcall(function()
        local prompt = nil
        for _, c in pairs(part:GetChildren()) do
            if c:IsA("ProximityPrompt") then prompt = c break end
        end
        if not prompt and part.Parent then
            for _, c in pairs(part.Parent:GetChildren()) do
                if c:IsA("ProximityPrompt") then prompt = c break end
            end
        end
        if not prompt then
            for _, c in pairs(part:GetDescendants()) do
                if c:IsA("ProximityPrompt") then prompt = c break end
            end
        end
        if prompt then
            pcall(function() prompt.HoldDuration = 0 end)
            if hasFireProx then
                fireproximityprompt(prompt)
            else
                prompt:InputHoldBegin()
                twait(0.05)
                prompt:InputHoldEnd()
            end
        end
    end)
end

-- [通用] 触发ClickDetector
local function fireCD(part)
    pcall(function()
        local cd = part:FindFirstChildWhichIsA("ClickDetector")
        if not cd and part.Parent then
            cd = part.Parent:FindFirstChildWhichIsA("ClickDetector")
        end
        if cd and hasFCD then
            fireclickdetector(cd)
        end
    end)
end

-- [通用] 全自动交互: 传送+触摸+ProximityPrompt+ClickDetector (全套)
local function interactWith(part, offset)
    if not part or not part.Parent then return false end
    teleportTo(part, offset or Vector3.new(0, 3, 0))
    twait(0.1)
    fireTouch(part)
    fireProximity(part)
    fireCD(part)
    return true
end

-- [通用] 全自动扫描+交互所有可交互物体 (核心: 不需要知道游戏内容)
-- 扫描 TouchTransmitter + ProximityPrompt + ClickDetector + CollectionService
local function autoScanAndInteract()
    local root = getRoot()
    if not root then return 0 end
    local count = 0

    -- 1. 扫描所有 TouchTransmitter (可触摸物体)
    local touchables = scanAllTouchables()
    for _, part in pairs(touchables) do
        if part and part.Parent then
            pcall(function()
                if hasFireTouch then
                    firetouchinterest(root, part, 0)
                    firetouchinterest(root, part, 1)
                    count = count + 1
                end
            end)
        end
    end

    -- 2. 扫描所有 ProximityPrompt (可交互提示)
    local prompts = scanAllPrompts()
    for _, p in pairs(prompts) do
        if p.prompt and p.prompt.Parent then
            pcall(function()
                p.prompt.HoldDuration = 0
                if hasFireProx then
                    fireproximityprompt(p.prompt)
                else
                    p.prompt:InputHoldBegin()
                    p.prompt:InputHoldEnd()
                end
                count = count + 1
            end)
        end
    end

    -- 3. 扫描所有 ClickDetector
    local cds = scanAllClickDetectors()
    for _, c in pairs(cds) do
        if c.cd and c.cd.Parent then
            pcall(function()
                if hasFCD then fireclickdetector(c.cd) count = count + 1 end
            end)
        end
    end

    -- 4. CollectionService 标签
    local tagged = scanByTags()
    for _, part in pairs(tagged) do
        if part and part.Parent then
            interactWith(part, Vector3.new(0, 3, 0))
            count = count + 1
        end
    end

    return count
end

-- [通用] Remote 自动发现 (老外技术: 正则+模糊匹配)
local remotePatterns = {
    click = {"^click$", "^train$", "^attack$", "^punch$", "^fight$"},
    farm = {"^kill$", "^attack$", "^damage$", "^hit$", "^collect$", "^harvest$"},
    buy = {"^buy$", "^upgrade$", "^purchase$", "^improve$", "^enhance$", "^boost$"},
    rebirth = {"^rebirth$", "^prestige$", "^ascend$", "^reset$", "^reincarnate$"},
    rune = {"^rune$", "^roll$", "^reroll$", "^pull$", "^summon$", "^gacha$", "^spin$", "^open$"},
    perk = {"^perk$", "^talent$", "^skill$", "^invest$", "^allocate$"},
    potion = {"^use$", "^drink$", "^activate$", "^potion$", "^consume$"},
    claim = {"^claim$", "^reward$", "^collect$", "^redeem$"},
    equip = {"^equip$", "^equipbest$", "^equipall$"},
    sell = {"^sell$", "^delete$", "^trash$"},
}

local function findRemoteByType(typeName)
    local patterns = remotePatterns[typeName]
    if not patterns then return nil end
    -- 精确匹配
    for _, pat in ipairs(patterns) do
        for name, r in pairs(remoteCache) do
            if name:match(pat) then return r end
        end
    end
    -- 模糊匹配
    for _, pat in ipairs(patterns) do
        local kw = pat:gsub("%^",""):gsub("%$",""):gsub("%?","")
        for name, r in pairs(remoteCache) do
            if name:find(kw, 1, true) then return r end
        end
    end
    return nil
end

-- [通用] 安全调用Remote (老外技术: 超时保护)
local function safeFireRemote(r, ...)
    if not r then return false end
    local args = {...}
    local done = false
    local thread = task.spawn(function()
        pcall(function()
            if r:IsA("RemoteEvent") then
                r:FireServer(unpack(args))
            elseif r:IsA("RemoteFunction") then
                pcall(function() r:InvokeServer(unpack(args)) end)
            end
        end)
        done = true
    end)
    local start = os.clock()
    while not done and (os.clock() - start) < 2 do task.wait(0.05) end
    if not done then pcall(task.cancel, thread) end
    return done
end

-- 模拟点击屏幕 (多种方式)
local function tapScreen()
    pcall(function()
        local m = LocalPlayer:GetMouse()
        local vp = m.ViewSizeX or 1280
        local hp = m.ViewSizeY or 720
        if vp > 0 and hp > 0 then
            local cx, cy = vp / 2, hp / 2
            -- 方式1: VirtualInputManager
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, LocalPlayer, 1)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, LocalPlayer, 1)
        end
    end)
    -- 方式2: VirtualUser
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

-- ==================== GUI按钮缓存 ====================
local buttonCache = {}

-- 点击GUI按钮: 同时扫描PlayerGui+CoreGui, 使用firesignal
local function clickButton(...)
    local kws = {...}
    local matched = nil

    local function searchGui(root)
        for _, g in pairs(root:GetDescendants()) do
            if (g:IsA("TextButton") or g:IsA("ImageButton")) and g.Parent then
                local gName = string.lower(g.Name)
                local gParent = g.Parent and string.lower(g.Parent.Name) or ""
                local gText = g:IsA("TextButton") and g.Text and string.lower(g.Text) or ""
                for _, kw in pairs(kws) do
                    local lk = string.lower(kw)
                    if gName == lk or gParent == lk or gText == lk then
                        return g
                    end
                    if string.find(gName, lk) or string.find(gParent, lk) or (gText ~= "" and string.find(gText, lk)) then
                        return g
                    end
                end
            end
        end
        return nil
    end

    -- 1. 查缓存
    for _, kw in pairs(kws) do
        local lk = string.lower(kw)
        if buttonCache[lk] and buttonCache[lk].Parent then
            matched = buttonCache[lk]
            break
        end
    end

    -- 2. 搜PlayerGui
    if not matched then
        pcall(function() matched = searchGui(LocalPlayer.PlayerGui) end)
    end

    -- 3. 搜CoreGui
    if not matched then
        pcall(function() matched = searchGui(CoreGui) end)
    end

    -- 4. 执行点击 (多重方法)
    if matched then
        pcall(function()
            -- 方法1: firesignal (最可靠)
            if hasFireSignal then
                pcall(function() firesignal(matched.MouseButton1Click) end)
                pcall(function() firesignal(matched.Activated) end)
                pcall(function() firesignal(matched.MouseButton1Down) end)
                pcall(function() firesignal(matched.MouseButton1Up) end)
            end
            -- 方法2: Activate
            pcall(function() matched:Activate() end)
            -- 方法3: VirtualInputManager
            local pos = matched.AbsolutePosition
            local size = matched.AbsoluteSize
            local cx = pos.X + size.X / 2
            local cy = pos.Y + size.Y / 2
            if cx > 0 and cy > 0 then
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, LocalPlayer, 1)
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, LocalPlayer, 1)
            end
        end)
        -- 更新缓存
        for _, kw in pairs(kws) do
            buttonCache[string.lower(kw)] = matched
        end
        return true
    end
    return false
end

-- 扫描PlayerGui按钮
local function scanButtons()
    pcall(function()
        for _, g in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if g:IsA("TextButton") or g:IsA("ImageButton") then
                buttonCache[string.lower(g.Name)] = g
                if g:IsA("TextButton") and g.Text and g.Text ~= "" then
                    buttonCache[string.lower(g.Text)] = g
                end
                if g.Parent then
                    buttonCache[string.lower(g.Parent.Name)] = g
                end
            end
        end
    end)
end

-- ==================== Remote缓存 (全game扫描) ====================
local remoteCache = {}

-- 扫描全game的Remote (修复: 不只扫ReplicatedStorage)
local function scanAllRemotes()
    pcall(function()
        for _, o in pairs(game:GetDescendants()) do
            if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                remoteCache[string.lower(o.Name)] = o
            end
        end
    end)
    -- 也扫Workspace和ReplicatedStorage的子级
    pcall(function()
        for _, o in pairs(Workspace:GetDescendants()) do
            if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                remoteCache[string.lower(o.Name)] = o
            end
        end
    end)
end

local function getRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if not r then
        local folder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Events")
        if folder then r = folder:FindFirstChild(name) end
    end
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
    return remoteCache[string.lower(name)]
end

local function getRemoteFuzzy(...)
    local kws = {...}
    for _, kw in pairs(kws) do
        local r = getRemote(kw)
        if r then return r end
    end
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

-- ==================== 连接追踪 ====================
local allConns = {}
local function trackConn(c) table.insert(allConns, c) return c end
local function stopAllConns() for _, c in pairs(allConns) do pcall(function() c:Disconnect() end) end allConns = {} end

-- ==================== Heartbeat 任务管理器 ====================
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

-- ==================== 视觉反馈系统 ====================
local VisualFX = {}
VisualFX.highlight = nil
VisualFX.billboard = nil

function VisualFX.highlightTarget(part)
    VisualFX.clear()
    if not part then return end
    pcall(function()
        VisualFX.highlight = Instance.new("Highlight")
        VisualFX.highlight.Name = "ypxHighlight"
        VisualFX.highlight.Adornee = part
        VisualFX.highlight.FillColor = Color3.fromRGB(255, 50, 50)
        VisualFX.highlight.FillTransparency = 0.6
        VisualFX.highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
        VisualFX.highlight.OutlineTransparency = 0
        VisualFX.highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        VisualFX.highlight.Parent = part

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

-- ==================== FPS监控系统 ====================
local fpsValue = 60
local fpsConn = nil
local pingValue = 0

local function startFPSMonitor(updateCallback)
    local frames = 0
    local lastTime = os.clock()
    if fpsConn then fpsConn:Disconnect() end
    fpsConn = RunService.RenderStepped:Connect(function()
        frames = frames + 1
    end)
    TaskManager.start("FPS", 1, function()
        local now = os.clock()
        local elapsed = now - lastTime
        if elapsed > 0 then
            fpsValue = math.floor(frames / elapsed)
        end
        frames = 0
        lastTime = now
        -- 模拟ping
        pcall(function()
            pingValue = math.floor((LocalPlayer:GetNetworkPing and LocalPlayer:GetNetworkPing() or 0.05) * 1000)
        end)
        if updateCallback then
            pcall(updateCallback, fpsValue, pingValue)
        end
    end)
end

local function stopFPSMonitor()
    if fpsConn then fpsConn:Disconnect() fpsConn = nil end
    TaskManager.stop("FPS")
end

-- ==================== 状态变量 ====================
local Flags = {}
local mainW, mainH = 460, 420

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

-- ==================== 通知系统 (模板优化) ====================
local function showNotif(text, color)
    local n = make("TextLabel", {
        Parent = sg, BackgroundColor3 = color or C.BlueD, BorderSizePixel = 0,
        Position = UDim2.new(0.5, -130, 0, -40), Size = UDim2.new(0, 260, 0, 32),
        Font = Enum.Font.GothamSemibold, Text = "  " .. text, TextColor3 = C.White, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(n, 8) stroke(n, color or C.BlueD, 1, 0.2)
    gradient(n, color or C.BlueD, C.CardH, 90)
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

flyOffBtn.MouseButton1Click:Connect(function() tw(flyOffBtn, {BackgroundColor3 = C.Red}, 0.08) tdelay(0.1, function() tw(flyOffBtn, {BackgroundColor3 = C.Green}, 0.08) end) stopFly() end)
flyDownBtn.MouseButton1Down:Connect(function() flyDown = true tw(flyDownBtn, {BackgroundColor3 = C.BlueD}, 0.06) end)
flyDownBtn.MouseButton1Up:Connect(function() flyDown = false tw(flyDownBtn, {BackgroundColor3 = C.Off}, 0.06) end)
drag(flyPanel)

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

-- ==================== 加速系统 ====================
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

-- ==================== ESP透视引擎 (v10.6 新引擎) ====================
-- 老外技术: BillboardGui + Highlight 实现透视
-- 功能: 敌人红色 / 物品绿色 / 玩家蓝色 / 宝箱金色
local ESP = {}
ESP.objects = {}
ESP.conn = nil
ESP.enabled = false
ESP.settings = { enemies = true, items = true, players = true, distance = 500 }

function ESP.add(part, color, label, dist)
    if not part or not part.Parent then return end
    -- 避免重复添加
    for _, o in pairs(ESP.objects) do
        if o.Adornee == part then return end
    end

    local esp = Instance.new("BillboardGui")
    esp.Name = "ypxESP"
    esp.Adornee = part
    esp.Size = UDim2.new(0, 100, 0, 20)
    esp.StudsOffset = Vector3.new(0, 3, 0)
    esp.AlwaysOnTop = true
    esp.Parent = sg

    local bg = Instance.new("Frame", esp)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = color
    bg.BackgroundTransparency = 0.4
    corner(bg, 6)

    local lbl = Instance.new("TextLabel", esp)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = label or part.Name
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.TextSize = 10

    -- 添加Highlight (老外技术)
    local hl = nil
    pcall(function()
        hl = Instance.new("Highlight")
        hl.Name = "ypxESPHL"
        hl.Adornee = part
        hl.FillColor = color
        hl.FillTransparency = 0.7
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0.2
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = sg
    end)

    table.insert(ESP.objects, { gui = esp, highlight = hl, Adornee = part, color = color, label = label })
end

function ESP.clear()
    for _, o in pairs(ESP.objects) do
        pcall(function() o.gui:Destroy() end)
        pcall(function() if o.highlight then o.highlight:Destroy() end end)
    end
    ESP.objects = {}
end

function ESP.start()
    ESP.stop()
    ESP.enabled = true
    ESP.conn = RunService.Heartbeat:Connect(function()
        -- 清理无效对象
        for i = #ESP.objects, 1, -1 do
            local o = ESP.objects[i]
            if not o.Adornee or not o.Adornee.Parent then
                pcall(function() o.gui:Destroy() end)
                pcall(function() if o.highlight then o.highlight:Destroy() end end)
                table.remove(ESP.objects, i)
            end
        end

        local root = getRoot()
        if not root then return end

        -- 扫描敌人
        if ESP.settings.enemies then
            local enemies = findObjects({"enemy", "mob", "npc", "boss", "monster", "怪", "敌人", "target"})
            for _, e in pairs(enemies) do
                if e:IsA("BasePart") or e:IsA("Model") then
                    local part = e:IsA("Model") and (e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart) or e
                    if part and part.Parent then
                        local dist = (part.Position - root.Position).Magnitude
                        if dist <= ESP.settings.distance then
                            ESP.add(part, Color3.fromRGB(255, 50, 50), "敌人 " .. math.floor(dist) .. "m")
                        end
                    end
                end
            end
        end

        -- 扫描物品/宝箱
        if ESP.settings.items then
            local items = findObjects({"chest", "宝箱", "reward", "drop", "pickup", "loot", "item", "物品", "coin", "gem"})
            for _, i in pairs(items) do
                if i:IsA("BasePart") then
                    local dist = (i.Position - root.Position).Magnitude
                    if dist <= ESP.settings.distance then
                        ESP.add(i, Color3.fromRGB(50, 255, 50), "物品 " .. math.floor(dist) .. "m")
                    end
                end
            end
        end

        -- 扫描玩家
        if ESP.settings.players then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dist = (hrp.Position - root.Position).Magnitude
                        if dist <= ESP.settings.distance then
                            ESP.add(hrp, Color3.fromRGB(50, 150, 255), p.Name .. " " .. math.floor(dist) .. "m")
                        end
                    end
                end
            end
        end
    end)
end

function ESP.stop()
    ESP.enabled = false
    if ESP.conn then
        ESP.conn:Disconnect()
        ESP.conn = nil
    end
    ESP.clear()
end

-- ==================== 反挂机引擎 (Anti-AFK v10.6 新引擎) ====================
-- 老外技术: VirtualUser + IdleTime重置
-- 功能: 自动防踢, 模拟输入, 保持在线
local AntiAFK = {}
AntiAFK.enabled = false

function AntiAFK.start()
    AntiAFK.stop()
    AntiAFK.enabled = true

    -- 方式1: 拦截IdleTimeout (老外核心技术)
    pcall(function()
        LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end)

    -- 方式2: 定期模拟按键 (双重保险)
    TaskManager.start("AntiAFK", 30, function()
        pcall(function()
            -- 模拟微小移动防止超时
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        -- 备用: 模拟按键
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end)

    showNotif("反挂机已启动", C.Green)
end

function AntiAFK.stop()
    AntiAFK.enabled = false
    TaskManager.stop("AntiAFK")
end

-- ==================== 加载界面 ====================
local loadScreen = make("Frame", { Parent = sg, BackgroundColor3 = C.BG, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0) })
corner(loadScreen, 0)
gradient(loadScreen, C.BG, C.BG2, 90)

local titleL = make("TextLabel", { Parent = loadScreen, BackgroundTransparency = 1, Position = UDim2.new(0.5, -120, 0.3, 0), Size = UDim2.new(0, 240, 0, 46), Font = Enum.Font.GothamBold, Text = "ypx Hub", TextColor3 = C.White, TextSize = 28 })
stroke(titleL, C.Blue, 1.5, 0.3)
local subL = make("TextLabel", { Parent = loadScreen, BackgroundTransparency = 1, Position = UDim2.new(0.5, -120, 0.3, 50), Size = UDim2.new(0, 240, 0, 18), Font = Enum.Font.GothamSemibold, Text = "© ypx  ·  v10.6 黑曼巴x福瑞", TextColor3 = C.Gold, TextSize = 13 })
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

    make("TextLabel", { Parent = topbar, BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0, 120, 1, 0), Font = Enum.Font.GothamBold, Text = "🐍 ypx Hub", TextColor3 = C.White, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left })
    make("TextLabel", { Parent = topbar, BackgroundTransparency = 1, Position = UDim2.new(1, -240, 0, 0), Size = UDim2.new(0, 90, 1, 0), Font = Enum.Font.GothamSemibold, Text = gameTypeName, TextColor3 = C.BlueL, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right })

    -- FPS状态栏
    local fpsLbl = make("TextLabel", { Parent = topbar, BackgroundTransparency = 1, Position = UDim2.new(1, -150, 0, 0), Size = UDim2.new(0, 60, 1, 0), Font = Enum.Font.GothamSemibold, Text = "FPS: 60", TextColor3 = C.Green, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right })

    make("TextLabel", { Parent = topbar, BackgroundTransparency = 1, Position = UDim2.new(1, -86, 0, 0), Size = UDim2.new(0, 44, 1, 0), Font = Enum.Font.GothamSemibold, Text = "©ypx", TextColor3 = C.Gold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right })

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
            stopFPSMonitor()
            VisualFX.clear()
            stopFly() setNoclip(false) wsActive = false
            sg:Destroy()
        end)
    end)

    -- 启动FPS监控
    startFPSMonitor(function(fps, ping)
        if fpsLbl and fpsLbl.Parent then
            fpsLbl.Text = "FPS: " .. fps
            fpsLbl.TextColor3 = fps >= 50 and C.Green or fps >= 30 and C.Orange or C.Red
        end
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

-- ==================== 自动化功能 (全部使用宝箱逻辑) ====================
local AutoState = {}

-- [自动点击/训练] 全自动: 扫描所有可交互物体+触摸+点击+Remote (不需要截图)
local function startAutoClick(interval)
    AutoState.AutoClick = true
    TaskManager.start("AutoClick", interval, function()
        -- 方式1: 全自动扫描+交互所有可交互物体 (老外核心技术, 不需要知道游戏内容)
        autoScanAndInteract()
        -- 方式2: 模拟屏幕点击
        tapScreen()
        -- 方式3: 尝试点击GUI训练按钮
        pcall(function()
            clickButton("train") clickButton("click") clickButton("attack")
            clickButton("punch") clickButton("auto") clickButton("fight")
            clickButton("训练") clickButton("攻击")
        end)
        -- 方式4: 自动发现Remote并触发
        local r = findRemoteByType("click")
        if r then safeFireRemote(r) end
    end)
end

-- [自动农场] 全自动: 扫描所有可交互物体+Humanoid+传送+触摸 (不需要截图)
local function startAutoFarm(distance)
    AutoState.AutoFarm = true
    local safePos = nil
    local root = getRoot()
    if root then safePos = root.Position end
    TaskManager.start("AutoFarm", 0.5, function()
        -- 找所有可能的敌人/怪/NPC
        local targets = findObjects({"enemy", "mob", "npc", "boss", "monster", "dummy", "training", "creature", "怪", "敌人", "boss"})
        -- 也找有Humanoid的模型
        pcall(function()
            for _, folder in pairs(Workspace:GetChildren()) do
                if folder:IsA("Folder") or folder:IsA("Model") then
                    for _, npc in pairs(folder:GetChildren()) do
                        if npc:IsA("Model") then
                            local hum = npc:FindFirstChildOfClass("Humanoid")
                            if hum and hum.Health > 0 then
                                local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
                                if hrp then
                                    local alreadyIn = false
                                    for _, t in pairs(targets) do
                                        if t == hrp then alreadyIn = true break end
                                    end
                                    if not alreadyIn then table.insert(targets, hrp) end
                                end
                            end
                        end
                    end
                end
            end
        end)
        if #targets > 0 then
            local nearest = findNearest(targets)
            if nearest then
                local r = getRoot()
                if r then
                    if not safePos then safePos = r.Position end
                    -- 传送到敌人上方
                    r.CFrame = nearest.CFrame * CFrame.new(0, distance or 5, 0)
                    r.Velocity = Vector3.zero
                    -- 模拟攻击
                    tapScreen()
                    -- 触摸敌人
                    fireTouch(nearest)
                    fireProximity(nearest)
                    -- 视觉高亮
                    VisualFX.highlightTarget(nearest)
                end
            end
        else
            VisualFX.clear()
            local r = getRoot()
            if r and safePos then
                r.CFrame = CFrame.new(safePos)
            end
        end
    end)
end

-- [自动购买升级] 全自动: 扫描交互物体+按钮+Remote (不需要截图)
local function startAutoBuy()
    AutoState.AutoBuy = true
    TaskManager.start("AutoBuy", 1, function()
        -- 方式1: 全自动扫描所有可交互物体
        autoScanAndInteract()
        -- 方式2: 点击GUI按钮
        pcall(function()
            clickButton("buy") clickButton("upgrade") clickButton("purchase")
            clickButton("max") clickButton("购买") clickButton("升级")
            clickButton("shop") clickButton("store") clickButton("商店")
        end)
        -- 方式3: 自动发现Remote并触发 (带超时保护)
        local r = findRemoteByType("buy")
        if r then safeFireRemote(r, 1) end
    end)
end

-- [自动重生] 全自动: 扫描交互物体+按钮+Remote (不需要截图)
local function startAutoRebirth()
    AutoState.AutoRebirth = true
    TaskManager.start("AutoRebirth", 2, function()
        -- 方式1: 全自动扫描所有可交互物体
        autoScanAndInteract()
        -- 方式2: 点击GUI按钮
        pcall(function()
            clickButton("rebirth") clickButton("prestige") clickButton("reset")
            clickButton("reincarnate") clickButton("重生") clickButton("转生")
        end)
        -- 方式3: 自动发现Remote并触发
        local r = findRemoteByType("rebirth")
        if r then safeFireRemote(r) end
    end)
end

-- [自动领取奖励] 找奖励物体+传送+触摸 (宝箱逻辑)
local function startAutoClaim()
    AutoState.AutoClaim = true
    TaskManager.start("AutoClaim", 2, function()
        -- 方式1: 找奖励/领取物体 传送+触摸 (宝箱逻辑)
        local targets = findObjects({"claim", "reward", "gift", "present", "prize", "领取", "奖励", "礼物"})
        if #targets > 0 then
            for _, t in pairs(targets) do
                if not AutoState.AutoClaim then break end
                interactWith(t, Vector3.new(0, 3, 0))
                twait(0.3)
            end
        end
        -- 方式2: 点击GUI按钮
        pcall(function()
            clickButton("claim") clickButton("reward") clickButton("collect")
            clickButton("领取") clickButton("奖励")
        end)
        -- 方式3: 发Remote
        local r = getRemoteFuzzy("claim", "reward", "collect")
        if r then fireRemote(r) end
    end)
end

-- [自动宝箱] 找宝箱+传送 (宝箱逻辑 - 已验证有效)
local function startAutoChest()
    AutoState.AutoChest = true
    TaskManager.start("AutoChest", 2, function()
        local chests = findObjects({"chest", "宝箱", "reward", "drop", "pickup", "loot", "treasure"})
        local root = getRoot()
        if root and #chests > 0 then
            for _, chest in pairs(chests) do
                if not AutoState.AutoChest then break end
                if chest and chest.Parent then
                    pcall(function()
                        root.CFrame = chest.CFrame + Vector3.new(0, 3, 0)
                        root.Velocity = Vector3.zero
                    end)
                    -- 也触发触摸和ProximityPrompt
                    fireTouch(chest)
                    fireProximity(chest)
                    twait(0.5)
                end
            end
        end
    end)
end

-- [自动抽符文] 全自动: 扫描交互物体+按钮+Remote (不需要截图)
local function startAutoRune()
    AutoState.AutoRune = true
    TaskManager.start("AutoRune", 1, function()
        -- 方式1: 全自动扫描所有可交互物体
        autoScanAndInteract()
        -- 方式2: 点击GUI按钮
        pcall(function()
            clickButton("rune") clickButton("roll") clickButton("reroll")
            clickButton("pull") clickButton("summon") clickButton("gacha")
            clickButton("spin") clickButton("open") clickButton("符文") clickButton("抽取")
        end)
        -- 方式3: 自动发现Remote并触发
        local r = findRemoteByType("rune")
        if r then safeFireRemote(r) end
    end)
end

-- [自动装备最佳] 点击GUI按钮
local function startAutoEquip()
    AutoState.AutoEquip = true
    TaskManager.start("AutoEquip", 1, function()
        pcall(function()
            clickButton("equip") clickButton("equipbest") clickButton("equip best")
            clickButton("equipall") clickButton("装备") clickButton("autoequip")
        end)
        local r = getRemoteFuzzy("equip", "equiprune")
        if r then fireRemote(r, "best") end
    end)
end

-- [自动出售低级] 点击GUI按钮
local function startAutoSell()
    AutoState.AutoSell = true
    TaskManager.start("AutoSell", 2, function()
        pcall(function()
            clickButton("sell") clickButton("delete") clickButton("出售")
        end)
        local r = getRemoteFuzzy("sell", "delete")
        if r then fireRemote(r, "low") end
    end)
end

-- [自动天赋点] 全自动: 扫描交互物体+按钮+Remote (不需要截图)
local function startAutoPerk()
    AutoState.AutoPerk = true
    TaskManager.start("AutoPerk", 0.5, function()
        -- 方式1: 全自动扫描所有可交互物体
        autoScanAndInteract()
        -- 方式2: 点击GUI按钮
        pcall(function()
            clickButton("perk") clickButton("talent") clickButton("skill")
            clickButton("invest") clickButton("allocate") clickButton("max")
            clickButton("天赋") clickButton("技能")
        end)
        -- 方式3: 自动发现Remote并触发
        local r = findRemoteByType("perk")
        if r then safeFireRemote(r, 1) end
    end)
end

-- [自动药水] 全自动: 扫描交互物体+按钮+Remote (不需要截图)
local function startAutoPotion()
    AutoState.AutoPotion = true
    TaskManager.start("AutoPotion", 2, function()
        -- 方式1: 全自动扫描所有可交互物体
        autoScanAndInteract()
        -- 方式2: 点击GUI按钮
        pcall(function()
            clickButton("use") clickButton("drink") clickButton("potion")
            clickButton("luck") clickButton("boost") clickButton("使用")
        end)
        -- 方式3: 自动发现Remote并触发
        local r = findRemoteByType("potion")
        if r then safeFireRemote(r, "potion") end
    end)
end

-- ==================== 维护标签页 ====================
local function buildMaintenanceTab(sidebar, content)
    local tm = newTab(sidebar, content, "维护", "🔧")

    label(tm, "—— 性能监控 ——")
    local perfLbl = make("TextLabel", { Parent = tm, BackgroundColor3 = C.Card, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 28), Font = Enum.Font.GothamSemibold, Text = "  FPS: 60 | PING: 0ms | 流畅", TextColor3 = C.Green, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
    corner(perfLbl, 8) stroke(perfLbl, C.Div, 1)
    -- 实时更新性能监控
    TaskManager.start("PerfMonitor", 1, function()
        if perfLbl and perfLbl.Parent then
            local status = fpsValue >= 50 and "流畅" or fpsValue >= 30 and "一般" or "卡顿"
            local color = fpsValue >= 50 and C.Green or fpsValue >= 30 and C.Orange or C.Red
            perfLbl.Text = "  FPS: " .. fpsValue .. " | PING: " .. pingValue .. "ms | " .. status
            perfLbl.TextColor3 = color
        end
    end)

    label(tm, "—— 运行状态 ——")
    local sl = make("TextLabel", { Parent = tm, BackgroundColor3 = C.Card, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 28), Font = Enum.Font.GothamSemibold, Text = "  ✅ v10.6 Heartbeat引擎运行中", TextColor3 = C.Green, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
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
        -- 重启FPS监控
        startFPSMonitor(function(fps, ping) end)
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

    label(tm, "—— 远程日志 (全game扫描) ——")
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
        Font = Enum.Font.Code, Text = "点击下方按钮扫描全game远程事件", TextColor3 = C.Gray, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    })
    pcall(function() logText.AutomaticSize = Enum.AutomaticSize.Y end)

    button(tm, "📋 扫描全game远程事件", function()
        -- 修复: 扫描全game (不只ReplicatedStorage)
        local lines = {}
        pcall(function()
            for _, o in pairs(game:GetDescendants()) do
                if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                    local fn = o.Name
                    pcall(function() fn = o:GetFullName() end)
                    table.insert(lines, fn .. "  [" .. o.ClassName .. "]")
                end
            end
        end)
        table.sort(lines)
        if #lines > 0 then
            logText.Text = table.concat(lines, "\n")
            logText.TextColor3 = C.White
        else
            logText.Text = "未找到远程事件"
            logText.TextColor3 = C.Orange
        end
        showNotif("全game扫描: " .. #lines .. " 个远程", C.Blue)
    end)
    button(tm, "📋 只扫ReplicatedStorage", function()
        local lines = {}
        pcall(function()
            for _, o in pairs(ReplicatedStorage:GetDescendants()) do
                if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                    local fn = o.Name
                    pcall(function() fn = o:GetFullName() end)
                    table.insert(lines, fn .. "  [" .. o.ClassName .. "]")
                end
            end
        end)
        table.sort(lines)
        if #lines > 0 then
            logText.Text = table.concat(lines, "\n")
            logText.TextColor3 = C.White
        else
            logText.Text = "ReplicatedStorage中未找到远程事件"
            logText.TextColor3 = C.Orange
        end
        showNotif("ReplicatedStorage: " .. #lines .. " 个远程", C.Blue)
    end)
    button(tm, "📋 扫描Workspace按钮", function()
        local lines = {}
        pcall(function()
            for _, o in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if o:IsA("TextButton") or o:IsA("ImageButton") then
                    local info = o.Name
                    if o:IsA("TextButton") and o.Text and o.Text ~= "" then
                        info = info .. " (Text: " .. o.Text .. ")"
                    end
                    if o.Parent then
                        info = info .. " [Parent: " .. o.Parent.Name .. "]"
                    end
                    table.insert(lines, info)
                end
            end
        end)
        table.sort(lines)
        if #lines > 0 then
            logText.Text = table.concat(lines, "\n")
            logText.TextColor3 = C.White
        else
            logText.Text = "PlayerGui中未找到按钮"
            logText.TextColor3 = C.Orange
        end
        showNotif("找到 " .. #lines .. " 个GUI按钮", C.Blue)
    end)
    button(tm, "🔄 重新扫描游戏", function()
        remoteCache = {}
        buttonCache = {}
        scanAllRemotes()
        scanButtons()
        local cnt = 0 for _ in pairs(remoteCache) do cnt = cnt + 1 end
        local btnCnt = 0 for _ in pairs(buttonCache) do btnCnt = btnCnt + 1 end
        logText.Text = "已重新扫描 · " .. cnt .. " Remote · " .. btnCnt .. " 按钮"
        logText.TextColor3 = C.Green
        showNotif("已重新扫描 " .. cnt .. " Remote + " .. btnCnt .. " 按钮", C.Green)
    end)
    button(tm, "📋 扫描Workspace物体", function()
        local lines = {}
        local counts = {}
        pcall(function()
            for _, o in pairs(Workspace:GetDescendants()) do
                if o:IsA("BasePart") or o:IsA("Model") then
                    local name = o.Name
                    counts[name] = (counts[name] or 0) + 1
                end
            end
        end)
        for name, count in pairs(counts) do
            table.insert(lines, name .. " x" .. count)
        end
        table.sort(lines)
        if #lines > 0 then
            logText.Text = table.concat(lines, "\n")
            logText.TextColor3 = C.White
        else
            logText.Text = "Workspace为空"
            logText.TextColor3 = C.Orange
        end
        showNotif("Workspace: " .. #lines .. " 种物体", C.Blue)
    end)
    button(tm, "📋 扫描可交互物体", function()
        local lines = {}
        -- TouchTransmitter
        local touchables = scanAllTouchables()
        table.insert(lines, "=== TouchTransmitter (可触摸) x" .. #touchables .. " ===")
        for _, p in ipairs(touchables) do
            if p and p.Parent then table.insert(lines, "  " .. p:GetFullName()) end
        end
        -- ProximityPrompt
        local prompts = scanAllPrompts()
        table.insert(lines, "\n=== ProximityPrompt (可交互) x" .. #prompts .. " ===")
        for _, pr in ipairs(prompts) do
            if pr.prompt and pr.prompt.Parent then table.insert(lines, "  " .. pr.prompt:GetFullName()) end
        end
        -- ClickDetector
        local cds = scanAllClickDetectors()
        table.insert(lines, "\n=== ClickDetector (可点击) x" .. #cds .. " ===")
        for _, c in ipairs(cds) do
            if c.cd and c.cd.Parent then table.insert(lines, "  " .. c.cd:GetFullName()) end
        end
        -- leaderstats
        table.insert(lines, "\n=== leaderstats (自动发现) ===")
        for name, v in pairs(leaderstatsCache) do
            if v and v.Parent then table.insert(lines, "  " .. name .. " = " .. tostring(v.Value)) end
        end
        logText.Text = table.concat(lines, "\n")
        logText.TextColor3 = C.White
        showNotif("触摸:" .. #touchables .. " 交互:" .. #prompts .. " 点击:" .. #cds, C.Blue)
    end)

    label(tm, "—— 关于 ——")
    local ab = make("TextLabel", { Parent = tm, BackgroundColor3 = C.Card, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 60), Font = Enum.Font.GothamSemibold, Text = "  ypx Hub v10.6 © ypx\n  黑曼巴 x 福瑞 结合体\n  通用自动发现引擎 · 不需要截图\n  ESP透视+反挂机+TouchTransmitter+ProximityPrompt+ClickDetector+Remote自动发现", TextColor3 = C.Gray, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
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

    label(tp, "—— 通用自动化 (自动发现, 不需要截图) ——")
    toggle(tp, "全能自动(扫描所有可交互物体)", false, function(v)
        if v then
            AutoState.AutoAll = true
            TaskManager.start("AutoAll", 1, function()
                autoScanAndInteract()
                tapScreen()
            end)
        else
            AutoState.AutoAll = false
            TaskManager.stop("AutoAll")
        end
    end)
    local clickInterval = 0.5
    toggle(tp, "自动点击(传送+触摸)", false, function(v) if v then startAutoClick(clickInterval) else AutoState.AutoClick = false TaskManager.stop("AutoClick") end end)
    slider(tp, "点击间隔(秒)", 0.1, 5, 0.5, function(v) clickInterval = v end)
    toggle(tp, "自动农场(传送杀怪)", false, function(v) if v then startAutoFarm(5) else AutoState.AutoFarm = false TaskManager.stop("AutoFarm") VisualFX.clear() end end)
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
        if v then
            pcall(function()
                for _, o in pairs(Workspace:GetDescendants()) do
                    if o:IsA("BasePart") then
                        o.Material = Enum.Material.Plastic
                        o.Reflectance = 0
                        pcall(function() o.CastShadow = false end)
                    elseif o:IsA("Decal") or o:IsA("Texture") then
                        o.Transparency = 1
                    elseif o:IsA("ParticleEmitter") or o:IsA("Trail") then
                        o.Enabled = false
                    elseif o:IsA("Beam") then
                        o.Enabled = false
                    end
                end
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
            end)
            showNotif("已提升帧率", C.Green)
        end
    end)
    toggle(tv, "全亮", false, function(v)
        Flags.FB = v
        if v then
            TaskManager.start("FullBright", 1, function()
                Lighting.ClockTime = 14
                Lighting.Brightness = 2
                Lighting.ExposureCompensation = 0.5
            end)
            showNotif("已开启全亮", C.Gold)
        else
            TaskManager.stop("FullBright")
            Lighting.ExposureCompensation = 0
        end
    end)
    toggle(tv, "去除雾效", false, function(v)
        if v then
            TaskManager.start("NoFog", 1, function()
                Lighting.FogEnd = 9e9
                Lighting.FogStart = 9e9
            end)
        else
            TaskManager.stop("NoFog")
        end
    end)
    button(tv, "🧹 一键清理特效", function()
        local cnt = 0
        pcall(function()
            for _, o in pairs(Workspace:GetDescendants()) do
                if o:IsA("ParticleEmitter") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Trail") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Beam") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Fire") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Smoke") then o.Enabled = false cnt = cnt + 1
                end
            end
        end)
        showNotif("已清理 " .. cnt .. " 个特效", C.Purple)
    end)

    -- ESP透视引擎 (v10.6新引擎)
    label(tv, "—— ESP透视引擎 ——")
    toggle(tv, "ESP总开关", false, function(v)
        if v then ESP.start() else ESP.stop() end
    end)
    toggle(tv, "敌人透视(红)", true, function(v) ESP.settings.enemies = v end)
    toggle(tv, "物品透视(绿)", true, function(v) ESP.settings.items = v end)
    toggle(tv, "玩家透视(蓝)", true, function(v) ESP.settings.players = v end)
    slider(tv, "ESP距离", 100, 2000, 500, function(v) ESP.settings.distance = v end)
    button(tv, "清除ESP标记", function() ESP.clear() showNotif("ESP已清除", C.Purple) end)

    -- 反挂机引擎 (v10.6新引擎)
    label(tv, "—— 反挂机引擎 ——")
    toggle(tv, "反挂机(防AFK踢出)", false, function(v)
        if v then AntiAFK.start() else AntiAFK.stop() showNotif("反挂机已关闭", C.Orange) end
    end)

    buildMaintenanceTab(sidebar, content)
end

-- ==================== Anime Incremental 专用菜单 ====================
local function buildAnimeMenu(sidebar, content, gameName)
    -- 自动化标签
    local t1 = newTab(sidebar, content, "自动化", "⚡")
    label(t1, "—— 全能自动 (不需要截图) ——")
    toggle(t1, "全能自动(扫描所有可交互物体)", false, function(v)
        if v then
            AutoState.AutoAll = true
            TaskManager.start("AutoAll", 1, function()
                autoScanAndInteract()
                tapScreen()
            end)
        else
            AutoState.AutoAll = false
            TaskManager.stop("AutoAll")
        end
    end)

    label(t1, "—— 自动训练/攻击 (自动发现) ——")
    local clickD = 0.5
    toggle(t1, "自动点击训练", false, function(v)
        if v then startAutoClick(clickD) else AutoState.AutoClick = false TaskManager.stop("AutoClick") end
    end)
    slider(t1, "点击间隔(秒)", 0.1, 3, 0.5, function(v) clickD = v end)

    label(t1, "—— 自动农场 (传送杀怪) ——")
    local farmDist = 5
    toggle(t1, "自动农场", false, function(v)
        if v then startAutoFarm(farmDist) else AutoState.AutoFarm = false TaskManager.stop("AutoFarm") VisualFX.clear() end
    end)
    slider(t1, "农场高度", 1, 20, 5, function(v) farmDist = v end)

    label(t1, "—— 自动升级 (传送+触摸) ——")
    toggle(t1, "自动购买升级", false, function(v)
        if v then startAutoBuy() else AutoState.AutoBuy = false TaskManager.stop("AutoBuy") end
    end)
    toggle(t1, "自动重生/转生", false, function(v)
        if v then startAutoRebirth() else AutoState.AutoRebirth = false TaskManager.stop("AutoRebirth") end
    end)

    label(t1, "—— 自动领取 (传送+触摸) ——")
    toggle(t1, "自动领取奖励", false, function(v)
        if v then startAutoClaim() else AutoState.AutoClaim = false TaskManager.stop("AutoClaim") end
    end)
    toggle(t1, "自动宝箱", false, function(v)
        if v then startAutoChest() else AutoState.AutoChest = false TaskManager.stop("AutoChest") end
    end)

    -- 符文标签 (原卡牌)
    local t2 = newTab(sidebar, content, "符文", "🔮")
    label(t2, "—— 符文自动化 (传送+触摸) ——")
    toggle(t2, "自动抽符文(Reroll)", false, function(v)
        if v then startAutoRune() else AutoState.AutoRune = false TaskManager.stop("AutoRune") end
    end)
    toggle(t2, "自动装备最佳", false, function(v)
        if v then startAutoEquip() else AutoState.AutoEquip = false TaskManager.stop("AutoEquip") end
    end)
    toggle(t2, "自动出售低级", false, function(v)
        if v then startAutoSell() else AutoState.AutoSell = false TaskManager.stop("AutoSell") end
    end)
    button(t2, "🔄 一键抽符文x10", function()
        -- 方式1: 找符文台传送+触摸
        local targets = findObjects({"rune", "符文", "roll", "reroll", "pull", "summon", "gacha"})
        if #targets > 0 then
            for i = 1, 10 do
                if not targets[1] then break end
                interactWith(targets[1], Vector3.new(0, 3, 0))
                twait(0.1)
            end
        end
        -- 方式2: 点击按钮
        for i = 1, 10 do
            clickButton("rune") clickButton("roll") clickButton("reroll") clickButton("pull")
            twait(0.1)
        end
        -- 方式3: 发Remote
        local r = getRemoteFuzzy("rune", "roll", "reroll", "pull")
        if r then for i = 1, 10 do fireRemote(r) twait(0.05) end end
        showNotif("已抽符文x10")
    end)
    button(t2, "🔄 一键装备全部", function()
        clickButton("equip") clickButton("equipall") clickButton("equip best")
        local r = getRemoteFuzzy("equip", "equiprune")
        if r then for i = 1, 20 do fireRemote(r, i) twait(0.02) end end
        showNotif("已装备全部符文")
    end)

    -- 技能树标签
    local t3 = newTab(sidebar, content, "技能树", "🌳")
    label(t3, "—— 天赋/技能自动化 (传送+触摸) ——")
    toggle(t3, "自动投入天赋点", false, function(v)
        if v then startAutoPerk() else AutoState.AutoPerk = false TaskManager.stop("AutoPerk") end
    end)
    button(t3, "📱 打开技能树", function()
        -- 找技能树传送
        local targets = findObjects({"skill", "tree", "perk", "talent", "技能", "天赋"})
        if #targets > 0 then
            local nearest = findNearest(targets)
            if nearest then interactWith(nearest, Vector3.new(0, 3, 0)) end
        end
        clickButton("phone") clickButton("skill") clickButton("tree") clickButton("perk") clickButton("talent")
        showNotif("已尝试打开技能树")
    end)
    button(t3, "🔄 一键投入全部", function()
        -- 找技能树传送+触摸
        local targets = findObjects({"skill", "tree", "perk", "talent", "技能", "天赋"})
        if #targets > 0 then
            for _, t in pairs(targets) do
                interactWith(t, Vector3.new(0, 3, 0))
                twait(0.05)
            end
        end
        clickButton("perk") clickButton("invest") clickButton("allocate") clickButton("max")
        local r = getRemoteFuzzy("perk", "skill", "talent", "invest")
        if r then for i = 1, 30 do fireRemote(r, i) twait(0.02) end end
        showNotif("已投入全部天赋点")
    end)

    -- 商店标签
    local t4 = newTab(sidebar, content, "商店", "🛒")
    label(t4, "—— 药水自动化 (传送+触摸) ——")
    toggle(t4, "自动使用药水", false, function(v)
        if v then startAutoPotion() else AutoState.AutoPotion = false TaskManager.stop("AutoPotion") end
    end)
    button(t4, "💊 一键使用药水", function()
        -- 找药水传送+触摸
        local targets = findObjects({"potion", "brew", "drink", "药水", "药剂"})
        if #targets > 0 then
            for _, t in pairs(targets) do
                interactWith(t, Vector3.new(0, 3, 0))
                twait(0.1)
            end
        end
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
        if v then
            pcall(function()
                for _, o in pairs(Workspace:GetDescendants()) do
                    if o:IsA("BasePart") then
                        o.Material = Enum.Material.Plastic
                        o.Reflectance = 0
                        pcall(function() o.CastShadow = false end)
                    elseif o:IsA("Decal") or o:IsA("Texture") then
                        o.Transparency = 1
                    elseif o:IsA("ParticleEmitter") or o:IsA("Trail") then
                        o.Enabled = false
                    elseif o:IsA("Beam") then
                        o.Enabled = false
                    end
                end
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
            end)
            showNotif("已提升帧率", C.Green)
        end
    end)
    toggle(t7, "全亮", false, function(v)
        Flags.FB = v
        if v then
            TaskManager.start("FullBright", 1, function()
                Lighting.ClockTime = 14
                Lighting.Brightness = 2
                Lighting.ExposureCompensation = 0.5
            end)
            showNotif("已开启全亮", C.Gold)
        else
            TaskManager.stop("FullBright")
            Lighting.ExposureCompensation = 0
        end
    end)
    toggle(t7, "去除雾效", false, function(v)
        if v then
            TaskManager.start("NoFog", 1, function()
                Lighting.FogEnd = 9e9
                Lighting.FogStart = 9e9
            end)
        else
            TaskManager.stop("NoFog")
        end
    end)
    button(t7, "🧹 一键清理特效", function()
        local cnt = 0
        pcall(function()
            for _, o in pairs(Workspace:GetDescendants()) do
                if o:IsA("ParticleEmitter") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Trail") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Beam") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Fire") then o.Enabled = false cnt = cnt + 1
                elseif o:IsA("Smoke") then o.Enabled = false cnt = cnt + 1
                end
            end
        end)
        showNotif("已清理 " .. cnt .. " 个特效", C.Purple)
    end)

    -- ESP透视引擎 (v10.6新引擎)
    label(t7, "—— ESP透视引擎 ——")
    toggle(t7, "ESP总开关", false, function(v)
        if v then ESP.start() else ESP.stop() end
    end)
    toggle(t7, "敌人透视(红)", true, function(v) ESP.settings.enemies = v end)
    toggle(t7, "物品透视(绿)", true, function(v) ESP.settings.items = v end)
    toggle(t7, "玩家透视(蓝)", true, function(v) ESP.settings.players = v end)
    slider(t7, "ESP距离", 100, 2000, 500, function(v) ESP.settings.distance = v end)
    button(t7, "清除ESP标记", function() ESP.clear() showNotif("ESP已清除", C.Purple) end)

    -- 反挂机引擎 (v10.6新引擎)
    label(t7, "—— 反挂机引擎 ——")
    toggle(t7, "反挂机(防AFK踢出)", false, function(v)
        if v then AntiAFK.start() else AntiAFK.stop() showNotif("反挂机已关闭", C.Orange) end
    end)

    buildMaintenanceTab(sidebar, content)
end

-- ==================== 类型映射 ====================
local TypeNames = { universal = "通用模式", anime_incremental = "Anime Inc." }

-- ==================== 主加载流程 ====================
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

        -- 扫描缓存 (全game扫描)
        statusText.Text = "正在扫描全game数据..."
        scanAllRemotes()
        scanButtons()
        scanLeaderstats()
        local remoteCount = 0 for _ in pairs(remoteCache) do remoteCount = remoteCount + 1 end
        local statCount = 0 for _ in pairs(leaderstatsCache) do statCount = statCount + 1 end
        twait(0.2)
        tw(barFill, {Size = UDim2.new(0, 200, 1, 0)}, 0.2)

        -- CharacterAdded 重连 (老外技术: 角色重生后自动重启任务)
        LocalPlayer.CharacterAdded:Connect(function()
            twait(1)
            scanLeaderstats()
        end)

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

    -- 直接显示主窗口 (v10.6: 移除验证系统, 修复Delta SCAM检测)
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
    local nt = loadOk and ("✅ " .. (TypeNames[gameType] or "通用") .. "  ·  v10.6 © ypx") or "⚠️ 维护模式  ·  © ypx"
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
    local btnCount = 0 for _ in pairs(buttonCache) do btnCount = btnCount + 1 end
    print("  ✅ ypx Hub v10.6 已加载!")
    print("  黑曼巴 x 福瑞 结合体")
    print("  游戏类型: " .. (TypeNames[gameType] or "通用"))
    print("  游戏名称: " .. tostring(gameName))
    print("  PlaceId: " .. tostring(placeId))
    print("  缓存: " .. rCount .. " Remote (全game) · " .. btnCount .. " 按钮")
    print("  核心引擎: 通用自动发现(TouchTransmitter+ProximityPrompt+ClickDetector+Remote) + Heartbeat")
    print("  老外技术: firetouchinterest重试 + ProximityPromptService绕过 + Remote正则匹配 + delta检测")
    print("  新引擎: ESP透视(BillboardGui+Highlight) | 反挂机(VirtualUser+IdleTime)")
    print("  FPS监控: ✅ | UI模板: ✅ | leaderstats自动发现: ✅ | ESP: ✅ | 反挂机: ✅")
    print("  按 RightShift 或悬浮按钮 显示/隐藏")
    print("  © 2026 ypx")
    print("═══════════════════════════════════")
end)

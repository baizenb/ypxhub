--[[ YPX v12.5 ]]
local P=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local TS=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local RS2=game:GetService("RunService")
local VIM=game:GetService("VirtualInputManager")
local VU=game:GetService("VirtualUser")
local CG=game:GetService("CoreGui")
local LP=P.LocalPlayer
local twait=task.wait
local tspawn=task.spawn
local tdelay=task.delay

local gp
pcall(function() gp=CG end)
if not gp then gp=LP:WaitForChild("PlayerGui") end
pcall(function() local o=gp:FindFirstChild("ypxH") if o then o:Destroy() end end)

local fT,fP,fC,fS
pcall(function() fT=firetouchinterest end)
pcall(function() fP=fireproximityprompt end)
pcall(function() fC=fireclickdetector end)
pcall(function() fS=firesignal end)

local C={
BG=Color3.fromRGB(10,10,16),BG2=Color3.fromRGB(6,6,12),
Card=Color3.fromRGB(20,20,32),CardH=Color3.fromRGB(30,30,48),
Side=Color3.fromRGB(14,14,22),SideH=Color3.fromRGB(22,22,36),
Blue=Color3.fromRGB(59,130,246),BlueD=Color3.fromRGB(37,99,235),BlueL=Color3.fromRGB(96,165,250),
Off=Color3.fromRGB(50,50,65),On=Color3.fromRGB(34,197,94),
White=Color3.fromRGB(240,240,245),Gray=Color3.fromRGB(150,150,165),
Red=Color3.fromRGB(239,68,68),Orange=Color3.fromRGB(251,146,60),
Green=Color3.fromRGB(34,197,94),Gold=Color3.fromRGB(250,204,21),
Div=Color3.fromRGB(34,34,48),Track=Color3.fromRGB(36,36,50)
}

local function tw(o,p,t)
  pcall(function() TS:Create(o,TweenInfo.new(t or 0.15,Enum.EasingStyle.Quad),p):Play() end)
end
local function mk(cl,pr)
  local o=Instance.new(cl)
  if pr then
    local p=pr.Parent
    for k,v in pairs(pr) do
      if k~="Parent" then pcall(function() o[k]=v end) end
    end
    if p then o.Parent=p end
  end
  return o
end
local function crn(p,r) mk("UICorner",{Parent=p,CornerRadius=UDim.new(0,r or 8)}) end
local function stk(p,c,t) mk("UIStroke",{Parent=p,Color=c or C.Div,Thickness=t or 1,Transparency=0.4}) end
local function grd(p,c1,c2,r) mk("UIGradient",{Parent=p,Color=ColorSequence.new(c1,c2),Rotation=r or 0}) end
local function pad(p,t,b,l,r) mk("UIPadding",{Parent=p,PaddingTop=UDim.new(0,t or 0),PaddingBottom=UDim.new(0,b or 0),PaddingLeft=UDim.new(0,l or 0),PaddingRight=UDim.new(0,r or 0)}) end

local function drag(f,h)
  h=h or f
  local d,sp,si
  h.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
      d=true si=i.Position sp=f.Position
    end
  end)
  UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then d=false end
  end)
  UIS.InputChanged:Connect(function(i)
    if d and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
      local dl=i.Position-si
      f.Position=UDim2.new(sp.X.Scale,sp.X.Offset+dl.X,sp.Y.Scale,sp.Y.Offset+dl.Y)
    end
  end)
end

local function getHum()
  local c=LP.Character
  return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
  local c=LP.Character
  return c and c:FindFirstChild("HumanoidRootPart")
end

-- 全局绕过长按
pcall(function()
  local PPS=game:GetService("ProximityPromptService")
  PPS.PromptButtonHoldBegan:Connect(function(p)
    pcall(function() p.HoldDuration=0 end)
  end)
end)

-- ==================== 自动扫描引擎 ====================
local function scanTouchables()
  local r={}
  pcall(function()
    for _,o in pairs(WS:GetDescendants()) do
      if o:IsA("TouchTransmitter") and o.Parent and o.Parent:IsA("BasePart") then
        if not o.Parent:IsDescendantOf(LP.Character or Instance.new("Folder")) then
          table.insert(r,o.Parent)
        end
      end
    end
  end)
  return r
end

local function scanPrompts()
  local r={}
  pcall(function()
    for _,o in pairs(WS:GetDescendants()) do
      if o:IsA("ProximityPrompt") and o.Enabled and o.Parent then
        if o.Parent:IsA("BasePart") then
          if not o.Parent:IsDescendantOf(LP.Character or Instance.new("Folder")) then
            table.insert(r,{prompt=o,part=o.Parent})
          end
        end
      end
    end
  end)
  return r
end

local function scanClickDets()
  local r={}
  pcall(function()
    for _,o in pairs(WS:GetDescendants()) do
      if o:IsA("ClickDetector") and o.Parent then
        local p=o.Parent:IsA("BasePart") and o.Parent or o.Parent:FindFirstChildWhichIsA("BasePart")
        if p and not p:IsDescendantOf(LP.Character or Instance.new("Folder")) then
          table.insert(r,{cd=o,part=p})
        end
      end
    end
  end)
  return r
end

local function scanTags()
  local r={}
  pcall(function()
    local CS=game:GetService("CollectionService")
    for _,t in ipairs({"Chest","Reward","Pickup","Collectible","Item","Enemy","NPC","Mob","Boss","Training"}) do
      for _,o in ipairs(CS:GetTagged(t)) do
        local p=o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart")
        if p then table.insert(r,p) end
      end
    end
  end)
  return r
end

local function scanRemotes()
  local r={}
  pcall(function()
    for _,o in pairs(game:GetDescendants()) do
      if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        r[string.lower(o.Name)]=o
      end
    end
  end)
  pcall(function()
    for _,o in pairs(WS:GetDescendants()) do
      if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        r[string.lower(o.Name)]=o
      end
    end
  end)
  return r
end

local remoteCache=scanRemotes()
local function getRemote(n)
  local r=RS:FindFirstChild(n)
  if not r then
    local f=RS:FindFirstChild("Remotes") or RS:FindFirstChild("Events")
    if f then r=f:FindFirstChild(n) end
  end
  if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
  return remoteCache[string.lower(n)]
end
local function getRemoteFuzzy(...)
  local kws={...}
  for _,k in pairs(kws) do
    local r=getRemote(k)
    if r then return r end
  end
  for n,r in pairs(remoteCache) do
    for _,k in pairs(kws) do
      if string.find(n,string.lower(k)) then return r end
    end
  end
  return nil
end
local function fireRemote(r,...)
  if not r then return end
  local a={...}
  pcall(function()
    if r:IsA("RemoteEvent") then
      r:FireServer(unpack(a))
    elseif r:IsA("RemoteFunction") then
      pcall(function() r:InvokeServer(unpack(a)) end)
    end
  end)
end

-- ==================== RemoteSpy Hook引擎 ====================
-- Hook FireServer/InvokeServer,记录所有远程调用参数,去重过滤
local Spy={}
Spy.recording=false
Spy.records={}
Spy.recordMap={}
Spy.count=0
Spy.descConn=nil

local function spyArgsKey(args)
  local parts={}
  for i=1,#args do
    local v=args[i]
    local tp=type(v)
    if tp=="string" then parts[i]='"'..v:sub(1,50)..'"'
    elseif tp=="number" then parts[i]=tostring(v)
    elseif tp=="boolean" then parts[i]=tostring(v)
    elseif tp=="Instance" then parts[i]="Inst:"..(v.Name or "?")
    elseif tp=="table" then
      local ok,je=pcall(function() return game:GetService("HttpService"):JSONEncode(v) end)
      parts[i]=ok and je:sub(1,80) or "{}"
    elseif tp=="EnumItem" then parts[i]="Enum:"..tostring(v)
    else parts[i]=tp end
  end
  return table.concat(parts,",")
end

local function hookRemote(r)
  if not r then return end
  local mt=getmetatable(r)
  if not mt then return end
  local name=r.Name
  local path=name
  pcall(function() path=r:GetFullName() end)
  local key1=name.."__ypx_ev"
  local key2=name.."__ypx_fn"
  if rawget(r,key1) or rawget(r,key2) then return end
  if r:IsA("RemoteEvent") then
    local oldFire=r.FireServer
    rawset(r,key1,true)
    r.FireServer=function(self,...)
      if Spy.recording then
        local ok,args=pcall(function() return {...} end)
        if ok and args then
          local dk=name.."|"..spyArgsKey(args)
          if not Spy.recordMap[dk] then
            Spy.recordMap[dk]=true
            Spy.count=Spy.count+1
            Spy.records[Spy.count]={name=name,path=path,args=args,cls="Event",time=os.date("%H:%M:%S")}
            log("[SPY#"..Spy.count.."] "..name.."("..spyArgsKey(args)..")","info")
          end
        end
      end
      return oldFire(self,...)
    end
  elseif r:IsA("RemoteFunction") then
    local oldInvoke=r.InvokeServer
    rawset(r,key2,true)
    r.InvokeServer=function(self,...)
      if Spy.recording then
        local ok,args=pcall(function() return {...} end)
        if ok and args then
          local dk=name.."|"..spyArgsKey(args)
          if not Spy.recordMap[dk] then
            Spy.recordMap[dk]=true
            Spy.count=Spy.count+1
            Spy.records[Spy.count]={name=name,path=path,args=args,cls="Func",time=os.date("%H:%M:%S")}
            log("[SPY#"..Spy.count.."] "..name.."("..spyArgsKey(args)..")","info")
          end
        end
      end
      return oldInvoke(self,...)
    end
  end
end

local function hookAllRemotes()
  pcall(function()
    for _,o in pairs(game:GetDescendants()) do
      if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        hookRemote(o)
      end
    end
  end)
end

function Spy.start()
  if Spy.recording then return end
  Spy.recording=true
  hookAllRemotes()
  if not Spy.descConn then
    Spy.descConn=game.DescendantAdded:Connect(function(o)
      if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        hookRemote(o)
      end
    end)
  end
  log("Spy录制已启动,请在游戏内操作","ok")
end

function Spy.stop()
  Spy.recording=false
  log("Spy录制已停止,共记录"..Spy.count.."条","warn")
end

function Spy.clear()
  Spy.records={}
  Spy.recordMap={}
  Spy.count=0
  log("Spy记录已清空","info")
end

-- 按关键词查找记录
function Spy.find(kw)
  local res={}
  local lkw=string.lower(kw)
  for _,rec in pairs(Spy.records) do
    if string.find(string.lower(rec.name),lkw,1,true) then
      table.insert(res,rec)
    end
  end
  return res
end

-- 按关键词重放远程调用
function Spy.replay(kw)
  local res=Spy.find(kw)
  local played=0
  for _,rec in ipairs(res) do
    local r=getRemote(rec.name)
    if not r then
      pcall(function()
        local parts=string.split(rec.path,".")
        local obj=game
        for i=2,#parts do
          obj=obj:FindFirstChild(parts[i])
          if not obj then break end
        end
        if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then r=obj end
      end)
    end
    if r then
      fireRemote(r,unpack(rec.args))
      played=played+1
    end
  end
  return played
end

-- 自动模式:先尝试Spy重放,失败再fallback到点击
local function smartRemote(kw,...)
  local played=Spy.replay(kw)
  if played>0 then return played end
  -- fallback: 模糊匹配Remote
  for _,k in ipairs({...}) do
    local r=getRemoteFuzzy(k)
    if r then fireRemote(r) return 1 end
  end
  return 0
end

local lsc={}
local function scanLS()
  lsc={}
  pcall(function()
    local ls=LP:FindFirstChild("leaderstats")
    if ls then
      for _,v in pairs(ls:GetChildren()) do
        if v:IsA("ValueBase") then lsc[string.lower(v.Name)]=v end
      end
    end
    for _,v in pairs(LP:GetChildren()) do
      if v:IsA("ValueBase") then lsc[string.lower(v.Name)]=v end
    end
  end)
  return lsc
end
scanLS()

local function findNearest(t)
  local root=getRoot()
  if not root then return nil end
  local n,nd=nil,math.huge
  for _,o in pairs(t) do
    if o and o.Parent then
      pcall(function()
        local d=(o.Position-root.Position).Magnitude
        if d<nd then nd=d n=o end
      end)
    end
  end
  return n
end

local function tpTo(part,off)
  local root=getRoot()
  if not root or not part then return false end
  pcall(function()
    root.CFrame=part.CFrame*CFrame.new(off or Vector3.new(0,3,0))
    root.Velocity=Vector3.zero
  end)
  return true
end

local function fireTouch(part)
  local root=getRoot()
  if not root or not part then return end
  if fT then
    for _=1,3 do
      local ok=pcall(function()
        fT(root,part,0)
        twait(0.004)
        fT(root,part,1)
      end)
      if ok then break end
      twait(0.01)
    end
  else
    pcall(function() root.CFrame=part.CFrame end)
  end
end

local function fireProx(part)
  pcall(function()
    local p=nil
    for _,c in pairs(part:GetChildren()) do
      if c:IsA("ProximityPrompt") then p=c break end
    end
    if not p and part.Parent then
      for _,c in pairs(part.Parent:GetChildren()) do
        if c:IsA("ProximityPrompt") then p=c break end
      end
    end
    if not p then
      for _,c in pairs(part:GetDescendants()) do
        if c:IsA("ProximityPrompt") then p=c break end
      end
    end
    if p then
      p.HoldDuration=0
      if fP then
        fP(p)
      else
        p:InputHoldBegin()
        twait(0.05)
        p:InputHoldEnd()
      end
    end
  end)
end

local function fireCD(part)
  pcall(function()
    local cd=part:FindFirstChildWhichIsA("ClickDetector")
    if not cd and part.Parent then
      cd=part.Parent:FindFirstChildWhichIsA("ClickDetector")
    end
    if cd and fC then fC(cd) end
  end)
end

local function interact(part,off)
  if not part or not part.Parent then return false end
  tpTo(part,off or Vector3.new(0,3,0))
  twait(0.1)
  fireTouch(part)
  fireProx(part)
  fireCD(part)
  return true
end

local function autoScanInteract()
  local root=getRoot()
  if not root then return 0 end
  local c=0
  for _,p in pairs(scanTouchables()) do
    if p and p.Parent then
      pcall(function()
        if fT then fT(root,p,0) fT(root,p,1) c=c+1 end
      end)
    end
  end
  for _,p in pairs(scanPrompts()) do
    if p.prompt and p.prompt.Parent then
      pcall(function()
        p.prompt.HoldDuration=0
        if fP then fP(p.prompt) else p.prompt:InputHoldBegin() p.prompt:InputHoldEnd() end
        c=c+1
      end)
    end
  end
  for _,p in pairs(scanClickDets()) do
    if p.cd and p.cd.Parent then
      pcall(function()
        if fC then fC(p.cd) c=c+1 end
      end)
    end
  end
  for _,p in pairs(scanTags()) do
    if p and p.Parent then
      interact(p,Vector3.new(0,3,0))
      c=c+1
    end
  end
  c=c+clickAllBtns({"buy","buymax","buy max","max","upgrade","claim","reward","collect","train","attack","click","open","use","equip","sell","roll","reroll","purchase"})
  local fired=0
  for _,ty in ipairs({"click","farm","buy","claim","potion","equip","rune"}) do
    local r=findRemoteByType(ty)
    if r then fireRemote(r) fired=fired+1 end
  end
  if fired>0 then c=c+fired end
  pcall(function()
    local root=getRoot()
    if root then
      for _,o in pairs(WS:GetDescendants()) do
        if o:IsA("BasePart") and not o:IsDescendantOf(LP.Character or Instance.new("Folder")) then
          local ln=string.lower(o.Name)
          if ln:match("pack") or ln:match("chest") or ln:match("reward") or ln:match("card") then
            local d=(o.Position-root.Position).Magnitude
            if d<300 then
              if fT then pcall(function() fT(root,o,0) fT(root,o,1) end) c=c+1 end
            end
          end
        end
      end
    end
  end)
  return c
end

local btnCache={}
local function scanBtns()
  btnCache={}
  pcall(function()
    local pg=LP:FindFirstChild("PlayerGui")
    local guis={pg,CG}
    for _,g in pairs(guis) do
      if g then
        for _,o in pairs(g:GetDescendants()) do
          if (o:IsA("TextButton") or o:IsA("ImageButton")) and o.Parent then
            btnCache[string.lower(o.Name)]=o
          end
        end
      end
    end
  end)
  return btnCache
end
scanBtns()

-- v12.5: 静默点击 - 只用firesignal,绝不模拟物理鼠标,不干扰用户触摸
local function clickBtn(...)
  local kws={...}
  local clicked=0
  for _,kw in pairs(kws) do
    local lkw=string.lower(kw)
    for n,b in pairs(btnCache) do
      if n:find(lkw,1,true) and b.Parent then
        pcall(function()
          if b:IsA("TextButton") or b:IsA("ImageButton") then
            if b.Active==false then return end
            if b.Visible==false then return end
            -- 只用firesignal静默触发,不用VIM物理模拟
            if fS then
              pcall(fS,b.Activated)
              pcall(fS,b.MouseButton1Click)
            else
              pcall(function() b:Activate() end)
            end
            clicked=clicked+1
          end
        end)
      end
    end
  end
  return clicked>0
end

local function clickAllBtns(kws)
  local clicked=0
  for _,kw in ipairs(kws) do
    local lkw=string.lower(kw)
    for n,b in pairs(btnCache) do
      if n:find(lkw,1,true) and b.Parent then
        pcall(function()
          if b.Active==false then return end
          if b.Visible==false then return end
          if fS then pcall(fS,b.Activated) end
          clicked=clicked+1
        end)
      end
    end
  end
  return clicked
end

local rp={
click={"click","train","attack","punch","tap"},
farm={"kill","attack","damage","hit","collect","combat","fight"},
buy={"buy","upgrade","purchase","enhance","boost","levelup","level_up"},
rebirth={"rebirth","prestige","ascend","reset","reincarnate"},
rune={"rune","roll","reroll","pull","gacha","spin","open","summon"},
perk={"perk","talent","skill","invest","allocate","upgrade"},
potion={"use","drink","activate","potion","consume","buff","eat"},
claim={"claim","reward","collect","redeem","daily","free"},
equip={"equip","equipbest","equipall","autoequip"},
sell={"sell","delete","trash","remove","discard"}
}
local function findRemoteByType(ty)
  local kws=rp[ty]
  if not kws then return nil end
  for _,kw in ipairs(kws) do
    local r=getRemote(kw)
    if r then return r end
  end
  for _,kw in ipairs(kws) do
    local lkw=string.lower(kw)
    for n,r in pairs(remoteCache) do
      if n:find(lkw,1,true) then return r end
    end
  end
  return nil
end

-- ==================== TaskManager ====================
local TM={}
TM.tasks={}
TM.conn=nil
function TM.start(n,interval,cb)
  TM.stop(n)
  TM.tasks[n]={cb=cb,acc=0,interval=interval}
  if not TM.conn then
    TM.conn=RS2.Heartbeat:Connect(function(dt)
      for name,t in pairs(TM.tasks) do
        t.acc=t.acc+dt
        if t.acc>=t.interval then
          t.acc=0
          tspawn(function() pcall(t.cb) end)
        end
      end
    end)
  end
end
function TM.stop(n)
  if TM.tasks[n] then TM.tasks[n]=nil end
end
function TM.stopAll()
  for n in pairs(TM.tasks) do TM.tasks[n]=nil end
  if TM.conn then TM.conn:Disconnect() TM.conn=nil end
end

-- ==================== VisualFX ====================
local VFX={}
VFX.hl=nil
VFX.bb=nil
function VFX.target(part)
  VFX.clear()
  pcall(function()
    VFX.hl=Instance.new("Highlight")
    VFX.hl.Name="ypxHl"
    VFX.hl.Adornee=part
    VFX.hl.FillColor=Color3.fromRGB(255,50,50)
    VFX.hl.FillTransparency=0.6
    VFX.hl.OutlineColor=Color3.fromRGB(255,255,0)
    VFX.hl.OutlineTransparency=0
    VFX.hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    VFX.hl.Parent=part
    VFX.bb=Instance.new("BillboardGui")
    VFX.bb.Name="ypxTgt"
    VFX.bb.Adornee=part
    VFX.bb.Size=UDim2.new(0,120,0,28)
    VFX.bb.StudsOffset=Vector3.new(0,4,0)
    VFX.bb.AlwaysOnTop=true
    VFX.bb.Parent=part
    local l=Instance.new("TextLabel",VFX.bb)
    l.Size=UDim2.new(1,0,1,0)
    l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold
    l.Text="目标"
    l.TextColor3=Color3.fromRGB(255,255,0)
    l.TextStrokeColor3=Color3.fromRGB(0,0,0)
    l.TextStrokeTransparency=0
    l.TextSize=12
  end)
end
function VFX.clear()
  pcall(function()
    if VFX.hl then VFX.hl:Destroy() end
    if VFX.bb then VFX.bb:Destroy() end
  end)
  VFX.hl=nil
  VFX.bb=nil
end

-- ==================== FPS监控 ====================
local fpsV=60
local fpsC=nil
local pingV=0
local function startFPS(cb)
  local f=0
  local lt=os.clock()
  if fpsC then fpsC:Disconnect() end
  fpsC=RS2.RenderStepped:Connect(function() f=f+1 end)
  TM.start("FPS",1,function()
    local n=os.clock()
    local e=n-lt
    if e>0 then fpsV=math.floor(f/e) end
    f=0
    lt=n
    pcall(function()
      if LP.GetNetworkPing then
        pingV=math.floor(LP:GetNetworkPing()*1000)
      end
    end)
    if cb then pcall(cb,fpsV,pingV) end
  end)
end
local function stopFPS()
  if fpsC then fpsC:Disconnect() fpsC=nil end
  TM.stop("FPS")
end

-- ==================== ScreenGui ====================
local sg=mk("ScreenGui",{
  Name="ypxH",Parent=gp,ResetOnSpawn=false,
  IgnoreGuiInset=true,DisplayOrder=9999
})

-- 飞行面板
local flyP=mk("Frame",{
  Parent=sg,Name="FlyP",BackgroundColor3=C.Card,BorderSizePixel=0,
  Position=UDim2.new(0,10,0.55,0),Size=UDim2.new(0,58,0,64),
  Visible=false,Active=true
})
crn(flyP,10) stk(flyP,C.Green,1.5) grd(flyP,C.Card,C.CardH,90)
local flyOff=mk("TextButton",{
  Parent=flyP,BackgroundColor3=C.Green,BorderSizePixel=0,
  Position=UDim2.new(0,4,0,4),Size=UDim2.new(1,-8,0,26),
  Font=Enum.Font.GothamBold,Text="飞行 ✓",TextColor3=C.White,TextSize=11,
  AutoButtonColor=false
})
crn(flyOff,7)
local flyDn=mk("TextButton",{
  Parent=flyP,BackgroundColor3=C.Off,BorderSizePixel=0,
  Position=UDim2.new(0,4,0,32),Size=UDim2.new(1,-8,0,28),
  Font=Enum.Font.GothamBold,Text="▼ 下降",TextColor3=C.White,TextSize=10,
  AutoButtonColor=false
})
crn(flyDn,7)

local function notif(t,c)
  local n=mk("TextLabel",{
    Parent=sg,BackgroundColor3=c or C.BlueD,BorderSizePixel=0,
    Position=UDim2.new(0.5,-130,0,-40),Size=UDim2.new(0,260,0,32),
    Font=Enum.Font.GothamSemibold,Text="  "..t,TextColor3=C.White,TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
  })
  crn(n,8) stk(n,c or C.BlueD,1) grd(n,c or C.BlueD,C.CardH,90)
  tw(n,{Position=UDim2.new(0.5,-130,0,10)},0.25)
  tdelay(2.5,function()
    tw(n,{Position=UDim2.new(0.5,-130,0,-40)},0.25)
    tdelay(0.3,function() pcall(function() n:Destroy() end) end)
  end)
end

-- 右下角符文通知
local runeNotifY=0
local function runeNotif(t,c)
  local yOff=runeNotifY
  runeNotifY=runeNotifY+42
  if runeNotifY>168 then runeNotifY=0 end
  local n=mk("TextLabel",{
    Parent=sg,BackgroundColor3=c or C.Gold,BorderSizePixel=0,
    Position=UDim2.new(1,0,1,-50-yOff),Size=UDim2.new(0,220,0,36),
    Font=Enum.Font.GothamSemibold,Text="  "..t,TextColor3=C.White,TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
  })
  crn(n,8) stk(n,c or C.Gold,1) grd(n,c or C.Gold,C.CardH,90)
  tw(n,{Position=UDim2.new(1,-240,1,-50-yOff)},0.25)
  tdelay(2.5,function()
    tw(n,{Position=UDim2.new(1,0,1,-50-yOff)},0.3)
    tdelay(0.35,function() pcall(function() n:Destroy() end) end)
  end)
end

-- 89R币弹窗拦截器
local block89RConn
local block89RAcc=0
local function startBlock89R()
  if block89RConn then return end
  block89RConn=RS2.Heartbeat:Connect(function(dt)
    block89RAcc=block89RAcc+dt
    if block89RAcc<0.3 then return end
    block89RAcc=0
    pcall(function()
      local pg=LP:FindFirstChild("PlayerGui")
      if not pg then return end
      for _,gui in pairs(pg:GetChildren()) do
        if gui~=sg and (gui:IsA("ScreenGui") or gui:IsA("Frame")) then
          for _,d in pairs(gui:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible~=false then
              local txt=tostring(d.Text or "")
              local is89R=txt:find("89R",1,true) or txt:find("89 R",1,true) or txt:find("R币",1,true) or (txt:find("89",1,true) and txt:find("R",1,true)) or (txt:find("+10",1,true) and txt:find("R",1,true))
              if is89R then
                -- 找到弹窗容器并移除
                local popup=d.Parent
                while popup and popup~=pg and popup~=gui do
                  if popup:IsA("Frame") then
                    pcall(function() popup:Destroy() end)
                    break
                  end
                  popup=popup.Parent
                end
                if not popup or popup==gui or popup==pg then
                  pcall(function() gui:Destroy() end)
                end
                break
              end
            end
          end
        end
      end
    end)
  end)
end

-- ==================== 日志系统 ====================
local LogSys={}
LogSys.lines={}
LogSys.maxLines=80
LogSys.labels={}
LogSys.panel=nil
LogSys.scroll=nil
function LogSys.add(msg,level)
  local msgStr=tostring(msg)
  if msgStr:find("RobloxReplicatedStorage",1,true) then return end
  if msgStr:find("ReplicatedStorage.Packages",1,true) then return end
  if msgStr:find("IntegrityCheck",1,true) then return end
  if msgStr:find("GetServerVersion",1,true) then return end
  if msgStr:find("GetServerType",1,true) then return end
  if msgStr:find("GetServerChannel",1,true) then return end
  if msgStr:find("ExperienceChat",1,true) then return end
  if msgStr:find("PlayerProfile",1,true) then return end
  if msgStr:find("PlayerBlock",1,true) then return end
  if msgStr:find("SetUserActive",1,true) then return end
  if msgStr:find("SetDialogInUse",1,true) then return end
  if msgStr:find("ReferredPlayer",1,true) then return end
  if msgStr:find("CanChatWith",1,true) then return end
  if msgStr:find("CreateOrJoinParty",1,true) then return end
  if msgStr:find("PlatformLeaderboard",1,true) then return end
  if msgStr:find("ModerateChat",1,true) then return end
  if msgStr:find("NewPlayerGroup",1,true) then return end
  if msgStr:find("BuildExperience",1,true) then return end
  if msgStr:find("ExpChatFeature",1,true) then return end
  if msgStr:find("leifstout_networker",1,true) then return end
  local ts=string.format("[%02d:%02d:%02d]",os.date("%H"),os.date("%M"),os.date("%S"))
  local clr=C.Gray
  if level=="ok" then clr=C.Green
  elseif level=="warn" then clr=C.Orange
  elseif level=="err" then clr=C.Red
  elseif level=="info" then clr=C.BlueL end
  local entry=ts.." "..msgStr
  table.insert(LogSys.lines,{text=entry,color=clr})
  if #LogSys.lines>LogSys.maxLines then table.remove(LogSys.lines,1) end
  if LogSys.scroll and LogSys.scroll.Parent then
    pcall(function()
      for _,l in pairs(LogSys.labels) do pcall(function() l:Destroy() end) end
      LogSys.labels={}
      for i=#LogSys.lines,1,-1 do
        local e=LogSys.lines[i]
        local l=mk("TextLabel",{
          Parent=LogSys.scroll,BackgroundTransparency=1,
          Size=UDim2.new(1,-8,0,16),Font=Enum.Font.GothamSemibold,
          Text=e.text,TextColor3=e.color,TextSize=10,
          TextXAlignment=Enum.TextXAlignment.Left,
          TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd
        })
        table.insert(LogSys.labels,l)
      end
      local c=#LogSys.lines*19
      LogSys.scroll.CanvasSize=UDim2.new(0,0,0,c)
      LogSys.scroll.CanvasPosition=Vector2.new(0,math.max(0,c-LogSys.scroll.AbsoluteSize.Y))
    end)
  end
end
local function log(msg,level) LogSys.add(msg,level) end
local _origPrint=print
local function ypxPrint(...)
  local args={...}
  local msg=""
  for i,v in ipairs(args) do
    if i>1 then msg=msg.."\t" end
    msg=msg..tostring(v)
  end
  pcall(function() LogSys.add(msg) end)
  pcall(_origPrint,...)
end
print=ypxPrint

-- ==================== 状态变量 ====================
local Flags={}
local mW,mH=460,420
local flyS=false
local flySp=60
local flyV=Vector3.zero
local flyU=false
local flyD=false
local nC=nil
local wsSp=50
local wsA=false

-- ==================== 飞行系统 ====================
function stopFly()
  flyS=false Flags.Fly=false flyU=false flyD=false
  TM.stop("Fly")
  pcall(function()
    local r=getRoot()
    if r then
      for _,o in pairs(r:GetChildren()) do
        if o:IsA("BodyVelocity") or o:IsA("BodyGyro") or o.Name=="ypxBV" or o.Name=="ypxBG" then
          o:Destroy()
        end
      end
    end
  end)
  flyV=Vector3.zero
  flyP.Visible=false
end

function startFly()
  if flyS then return end
  flyS=true Flags.Fly=true flyP.Visible=true
  local root=getRoot()
  local hum=getHum()
  if not root or not hum then flyS=false flyP.Visible=false return end
  root.CFrame=root.CFrame+Vector3.new(0,5,0)
  hum.PlatformStand=true
  TM.start("Fly",0.02,function()
    if not root or not hum then
      flyS=false flyP.Visible=false TM.stop("Fly") return
    end
    local cam=WS.CurrentCamera
    local bv=root:FindFirstChild("ypxBV") or Instance.new("BodyVelocity")
    bv.Name="ypxBV"
    bv.MaxForce=Vector3.new(9e9,9e9,9e9)
    bv.Velocity=Vector3.zero
    bv.Parent=root
    local bg=root:FindFirstChild("ypxBG") or Instance.new("BodyGyro")
    bg.Name="ypxBG"
    bg.MaxTorque=Vector3.new(9e9,9e9,9e9)
    bg.P=9e9
    bg.Parent=root
    bg.CFrame=cam.CFrame
    local d=Vector3.zero
    if flyU or UIS:IsKeyDown(Enum.KeyCode.Space) then d=d+Vector3.new(0,1,0) end
    if flyD or UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d=d-Vector3.new(0,1,0) end
    local f=cam.CFrame.LookVector
    d=d+f*(UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
    d=d-f*(UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
    d=d+cam.CFrame.RightVector*(UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
    d=d-cam.CFrame.RightVector*(UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
    if d.Magnitude>0 then d=d.Unit*flySp end
    bv.Velocity=d
    bg.CFrame=cam.CFrame
  end)
end

flyOff.MouseButton1Click:Connect(function()
  tw(flyOff,{BackgroundColor3=C.Red},0.08)
  tdelay(0.1,function() tw(flyOff,{BackgroundColor3=C.Green},0.08) end)
  stopFly()
end)
flyDn.MouseButton1Down:Connect(function() flyD=true tw(flyDn,{BackgroundColor3=C.BlueD},0.06) end)
flyDn.MouseButton1Up:Connect(function() flyD=false tw(flyDn,{BackgroundColor3=C.Off},0.06) end)
drag(flyP)

-- 穿墙
local function setNoclip(on)
  Flags.Noclip=on
  if on then
    if nC then nC:Disconnect() end
    nC=RS2.Stepped:Connect(function()
      local c=LP.Character
      if c then
        for _,p in pairs(c:GetDescendants()) do
          if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end
        end
      end
    end)
  else
    if nC then nC:Disconnect() nC=nil end
    pcall(function()
      local c=LP.Character
      if c then
        for _,p in pairs(c:GetDescendants()) do
          if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then p.CanCollide=true end
        end
      end
    end)
  end
end

-- 加速
local function setWS(on,sp)
  wsA=on wsSp=sp
  if on then
    TM.start("WS",0.3,function()
      local h=getHum()
      if h then h.WalkSpeed=wsSp end
    end)
  else
    TM.stop("WS")
    local h=getHum()
    if h then h.WalkSpeed=16 end
  end
end

-- 跳跃
UIS.JumpRequest:Connect(function()
  if flyS then
    flyU=true
    tdelay(0.3,function() flyU=false end)
  elseif Flags.InfJ then
    local h=getHum()
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
  end
end)

-- ==================== ESP透视引擎 ====================
local ESP={}
ESP.obj={}
ESP.conn=nil
ESP.en=false
ESP.cfg={enemies=true,items=true,players=true,distance=500}

function ESP.add(part,color,label)
  if not part or not part.Parent then return end
  for _,o in pairs(ESP.obj) do
    if o.Adornee==part then return o end
  end
  local e=Instance.new("BillboardGui")
  e.Name="ypxESP"
  e.Adornee=part
  e.Size=UDim2.new(0,100,0,20)
  e.StudsOffset=Vector3.new(0,3,0)
  e.AlwaysOnTop=true
  e.Parent=sg
  local bg=mk("Frame",{Parent=e,Size=UDim2.new(1,0,1,0),BackgroundColor3=color,BackgroundTransparency=0.4})
  crn(bg,6)
  local l=mk("TextLabel",{
    Parent=e,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
    Font=Enum.Font.GothamBold,Text=label or part.Name,
    TextColor3=Color3.fromRGB(255,255,255),
    TextStrokeColor3=Color3.fromRGB(0,0,0),TextStrokeTransparency=0,TextSize=10
  })
  local hl=nil
  pcall(function()
    hl=Instance.new("Highlight")
    hl.Adornee=part
    hl.FillColor=color
    hl.FillTransparency=0.6
    hl.OutlineColor=color
    hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent=part
  end)
  local entry={gui=e,highlight=hl,Adornee=part,color=color,label=l,prefix=""}
  table.insert(ESP.obj,entry)
  return entry
end

function ESP.clear()
  for _,o in pairs(ESP.obj) do
    pcall(function()
      if o.gui then o.gui:Destroy() end
      if o.highlight then o.highlight:Destroy() end
    end)
  end
  ESP.obj={}
end

ESP.scanCache={}
ESP.scanTimer=0

function ESP.start()
  ESP.stop()
  ESP.en=true
  ESP.scanTimer=0
  ESP.scanCache={}
  local distTimer=0
  ESP.conn=RS2.Heartbeat:Connect(function(dt)
    distTimer=distTimer+dt
    ESP.scanTimer=ESP.scanTimer+dt
    for i=#ESP.obj,1,-1 do
      local o=ESP.obj[i]
      if not o.Adornee or not o.Adornee.Parent then
        pcall(function()
          if o.gui then o.gui:Destroy() end
          if o.highlight then o.highlight:Destroy() end
        end)
        table.remove(ESP.obj,i)
      end
    end
    local root=getRoot()
    if not root then return end
    if ESP.scanTimer>=2 then
      ESP.scanTimer=0
      tspawn(function()
        ESP.doScan(root)
      end)
    end
    if distTimer>=0.3 then
      distTimer=0
      for _,o in pairs(ESP.obj) do
        if o.Adornee and o.Adornee.Parent and o.label then
          pcall(function()
            local d=(o.Adornee.Position-root.Position).Magnitude
            o.label.Text=(o.prefix or "")..math.floor(d).."m"
            if d>ESP.cfg.distance then
              pcall(function()
                if o.gui then o.gui:Destroy() end
                if o.highlight then o.highlight:Destroy() end
              end)
            end
          end)
        end
      end
    end
  end)
end

function ESP.doScan(root)
  if not root or not root.Parent then return end
  local myChar=LP.Character
  local allPlayers={}
  for _,pl in pairs(P:GetPlayers()) do
    if pl.Character then allPlayers[pl.Character]=true end
  end
  local rp=root.Position
  local maxD=ESP.cfg.distance
  if ESP.cfg.enemies then
    pcall(function()
      for _,m in pairs(WS:GetChildren()) do
        if m:IsA("Model") and m~=myChar and not allPlayers[m] then
          local h=m:FindFirstChildOfClass("Humanoid")
          if h and h.Health>0 then
            local p=m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
            if p then
              local d=(p.Position-rp).Magnitude
              if d>3 and d<=maxD then
                local e=ESP.add(p,Color3.fromRGB(255,50,50),"敌人")
                if e then e.prefix="敌人 " end
              end
            end
          end
        end
      end
    end)
    pcall(function()
      for _,folder in pairs(WS:GetChildren()) do
        if folder:IsA("Folder") then
          for _,m in pairs(folder:GetChildren()) do
            if m:IsA("Model") and m~=myChar and not allPlayers[m] then
              local h=m:FindFirstChildOfClass("Humanoid")
              if h and h.Health>0 then
                local p=m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
                if p then
                  local d=(p.Position-rp).Magnitude
                  if d>3 and d<=maxD then
                    local e=ESP.add(p,Color3.fromRGB(255,50,50),"敌人")
                    if e then e.prefix="敌人 " end
                  end
                end
              end
            end
          end
        end
      end
    end)
  end
  if ESP.cfg.items then
    pcall(function()
      for _,o in pairs(WS:GetDescendants()) do
        if o:IsA("BasePart") and not o:IsDescendantOf(LP.Character or Instance.new("Folder")) then
          local ln=string.lower(o.Name)
          if ln:match("pack") or ln:match("chest") or ln:match("reward") or ln:match("pickup") or ln:match("item") or ln:match("coin") or ln:match("gem") or ln:match("orb") or ln:match("crystal") then
            local d=(o.Position-rp).Magnitude
            if d>1 and d<=maxD then
              local e=ESP.add(o,Color3.fromRGB(50,255,50),"物品")
              if e then e.prefix="物品 " end
            end
          end
        end
      end
    end)
  end
  if ESP.cfg.players then
    for _,p in pairs(P:GetPlayers()) do
      if p~=LP and p.Character then
        local hrp=p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
          local d=(hrp.Position-rp).Magnitude
          if d>1 and d<=maxD then
            local e=ESP.add(hrp,Color3.fromRGB(50,150,255),p.Name)
            if e then e.prefix=p.Name.." " end
          end
        end
      end
    end
  end
end

function ESP.stop()
  ESP.en=false
  if ESP.conn then ESP.conn:Disconnect() ESP.conn=nil end
  ESP.clear()
end

-- ==================== 反挂机引擎 ====================
local AAFK={}
AAFK.en=false
function AAFK.start()
  AAFK.stop()
  AAFK.en=true
  pcall(function()
    LP.Idled:Connect(function()
      pcall(function()
        VU:CaptureController()
        VU:ClickButton2(Vector2.new())
      end)
    end)
  end)
  TM.start("AntiAFK",30,function()
    pcall(function()
      VU:CaptureController()
      VU:ClickButton2(Vector2.new())
    end)
    pcall(function()
      VIM:SendKeyEvent(true,Enum.KeyCode.Space,false,game)
      task.wait(0.05)
      VIM:SendKeyEvent(false,Enum.KeyCode.Space,false,game)
    end)
  end)
  notif("反挂机已启动",C.Green)
end
function AAFK.stop()
  AAFK.en=false
  TM.stop("AntiAFK")
end

-- ==================== 性能监控引擎 ====================
local PM={}
PM.en=false
PM.fpsH={}
PM.lastW=0
function PM.start()
  PM.stop()
  PM.en=true
  TM.start("PerfMon",5,function()
    local avg=fpsV
    table.insert(PM.fpsH,avg)
    if #PM.fpsH>12 then table.remove(PM.fpsH,1) end
    local s=0
    for _,v in pairs(PM.fpsH) do s=s+v end
    avg=math.floor(s/#PM.fpsH)
    if avg<20 and (os.time()-PM.lastW)>60 then
      PM.lastW=os.time()
      notif("FPS过低("..avg.."),建议关闭部分功能",C.Orange)
      log("FPS过低: "..avg,"warn")
      local tc=0
      for _ in pairs(TM.tasks) do tc=tc+1 end
      if tc>5 then notif("已运行"..tc.."个任务,建议减少",C.Red) end
    end
  end)
end
function PM.stop()
  PM.en=false
  TM.stop("PerfMon")
end

-- ==================== 加载界面 ====================
local ls=mk("Frame",{
  Parent=sg,BackgroundColor3=C.BG,BorderSizePixel=0,Size=UDim2.new(1,0,1,0)
})
crn(ls,0) grd(ls,C.BG,C.BG2,90)
local tL=mk("TextLabel",{
  Parent=ls,BackgroundTransparency=1,Position=UDim2.new(0.5,-120,0.3,0),
  Size=UDim2.new(0,240,0,46),Font=Enum.Font.GothamBold,Text="YPX",
  TextColor3=C.White,TextSize=28
})
stk(tL,C.Blue,1.5,0.3)
local sL=mk("TextLabel",{
  Parent=ls,BackgroundTransparency=1,Position=UDim2.new(0.5,-120,0.3,50),
  Size=UDim2.new(0,240,0,18),Font=Enum.Font.GothamSemibold,Text="YPX  v12.5",
  TextColor3=C.Gold,TextSize=13
})
local stT=mk("TextLabel",{
  Parent=ls,BackgroundTransparency=1,Position=UDim2.new(0.5,-140,0.46,10),
  Size=UDim2.new(0,280,0,22),Font=Enum.Font.GothamSemibold,Text="正在初始化...",
  TextColor3=C.Gray,TextSize=13
})
local cdT=mk("TextLabel",{
  Parent=ls,BackgroundTransparency=1,Position=UDim2.new(0.5,-140,0.46,36),
  Size=UDim2.new(0,280,0,30),Font=Enum.Font.GothamBold,Text="3",
  TextColor3=C.BlueL,TextSize=24
})
local bb=mk("Frame",{
  Parent=ls,BackgroundColor3=C.Track,BorderSizePixel=0,
  Position=UDim2.new(0.5,-130,0.46,74),Size=UDim2.new(0,260,0,6)
})
crn(bb,99)
local bf=mk("Frame",{
  Parent=bb,BackgroundColor3=C.Blue,BorderSizePixel=0,Size=UDim2.new(0,0,1,0)
})
crn(bf,99) grd(bf,C.Blue,C.BlueL,0)
local gnT=mk("TextLabel",{
  Parent=ls,BackgroundTransparency=1,Position=UDim2.new(0.5,-140,0.46,92),
  Size=UDim2.new(0,280,0,18),Font=Enum.Font.GothamSemibold,Text="",
  TextColor3=C.Green,TextSize=12
})

-- 游戏检测
local function getGameInfo()
  local pid=game.PlaceId
  local pn="未知"
  local done=false
  tspawn(function()
    pcall(function()
      local i=game:GetService("MarketplaceService"):GetProductInfo(pid)
      if i and i.Name then pn=i.Name end
    end)
    done=true
  end)
  local t=0
  while not done and t<2 do twait(0.1) t=t+0.1 end
  return pid,pn
end
local GDB={[7295742428]="anime_incremental"}
local KDB={
  {keyword="anime incremental",type="anime_incremental"},
  {keyword="incremental",type="anime_incremental"}
}
local function detectGame()
  local pid,pn=getGameInfo()
  if GDB[pid] then return GDB[pid],pn,pid end
  local ln=string.lower(pn)
  for _,e in pairs(KDB) do
    if string.find(ln,e.keyword) then return e.type,pn,pid end
  end
  return "universal",pn,pid
end

-- ==================== UI组件 ====================
local tabBtns={}
local tabPgs={}
local currentTabIdx=1

local function toggle(parent,text,def,cb)
  Flags[text]=def or false
  local h=mk("Frame",{Parent=parent,BackgroundColor3=C.Card,BorderSizePixel=0,Size=UDim2.new(1,-4,0,36)})
  crn(h,9) stk(h,C.Div,1) grd(h,C.Card,C.CardH,90)
  mk("TextLabel",{
    Parent=h,BackgroundTransparency=1,Position=UDim2.new(0,12,0,0),
    Size=UDim2.new(1,-60,1,0),Font=Enum.Font.GothamSemibold,Text=text,
    TextColor3=C.White,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left
  })
  local tog=mk("TextButton",{
    Parent=h,BackgroundColor3=def and C.On or C.Off,BorderSizePixel=0,
    Position=UDim2.new(1,-44,0.5,-10),Size=UDim2.new(0,36,0,20),
    Text="",AutoButtonColor=false
  })
  crn(tog,99)
  local kb=mk("Frame",{
    Parent=tog,BackgroundColor3=C.White,BorderSizePixel=0,
    Size=UDim2.new(0,14,0,14),
    Position=def and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
  })
  crn(kb,99)
  local s=def or false
  local function set(v)
    s=v Flags[text]=v
    tw(tog,{BackgroundColor3=v and C.On or C.Off})
    tw(kb,{Position=v and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)})
    if cb then pcall(cb,v) end
  end
  tog.MouseButton1Click:Connect(function() set(not s) end)
  h.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
      set(not s)
    end
  end)
  return {set=set,get=function() return s end}
end

local function slider(parent,text,mn,mx,def,cb)
  local h=mk("Frame",{Parent=parent,BackgroundColor3=C.Card,BorderSizePixel=0,Size=UDim2.new(1,-4,0,44)})
  crn(h,9) stk(h,C.Div,1) grd(h,C.Card,C.CardH,90)
  mk("TextLabel",{
    Parent=h,BackgroundTransparency=1,Position=UDim2.new(0,12,0,3),
    Size=UDim2.new(1,-60,0,16),Font=Enum.Font.GothamSemibold,Text=text,
    TextColor3=C.White,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left
  })
  local vl=mk("TextLabel",{
    Parent=h,BackgroundTransparency=1,Position=UDim2.new(1,-50,0,3),
    Size=UDim2.new(0,38,0,16),Font=Enum.Font.GothamBold,Text=tostring(def),
    TextColor3=C.BlueL,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right
  })
  local tr=mk("Frame",{
    Parent=h,BackgroundColor3=C.Track,BorderSizePixel=0,
    Position=UDim2.new(0,12,0,26),Size=UDim2.new(1,-24,0,10)
  })
  crn(tr,99)
  local pct=(def-mn)/(mx-mn)
  local fl=mk("Frame",{Parent=tr,BackgroundColor3=C.Blue,BorderSizePixel=0,Size=UDim2.new(pct,0,1,0)})
  crn(fl,99) grd(fl,C.BlueD,C.BlueL,0)
  local kb=mk("Frame",{
    Parent=tr,BackgroundColor3=C.White,BorderSizePixel=0,
    Size=UDim2.new(0,14,0,14),Position=UDim2.new(pct,-7,0.5,-7)
  })
  crn(kb,99) stk(kb,C.BlueD,1.5,0.2)
  local sd=false
  local function upd(i)
    local p=math.clamp((i.Position.X-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
    local v=math.floor(mn+(mx-mn)*p+0.5)
    fl.Size=UDim2.new(p,0,1,0)
    kb.Position=UDim2.new(p,-7,0.5,-7)
    vl.Text=tostring(v)
    if cb then cb(v) end
  end
  tr.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
      sd=true upd(i)
    end
  end)
  kb.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sd=true end
  end)
  UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sd=false end
  end)
  UIS.InputChanged:Connect(function(i)
    if sd and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
      upd(i)
    end
  end)
end

local function button(parent,text,cb)
  local b=mk("TextButton",{
    Parent=parent,BackgroundColor3=C.Card,BorderSizePixel=0,
    Size=UDim2.new(1,-4,0,32),Font=Enum.Font.GothamSemibold,Text=text,
    TextColor3=C.White,TextSize=11,AutoButtonColor=false
  })
  crn(b,9) stk(b,C.Div,1) grd(b,C.Card,C.CardH,90)
  b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=C.CardH}) end)
  b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=C.Card}) end)
  b.MouseButton1Click:Connect(function()
    tw(b,{BackgroundColor3=C.BlueD},0.06)
    tdelay(0.1,function() tw(b,{BackgroundColor3=C.Card},0.06) end)
    if cb then pcall(cb) end
  end)
  return b
end

local function buildMain(gtn)
  local main=mk("Frame",{
    Parent=sg,BackgroundColor3=C.BG,BorderSizePixel=0,
    Position=UDim2.new(0.5,-mW/2,0.5,-mH/2),Size=UDim2.new(0,mW,0,mH),
    Active=true,Visible=false,ClipsDescendants=true
  })
  crn(main,14) stk(main,C.Div,1.5,0.3) grd(main,C.BG,C.BG2,90)
  local tb=mk("Frame",{Parent=main,BackgroundColor3=C.Side,BorderSizePixel=0,Size=UDim2.new(1,0,0,40)})
  crn(tb,14)
  mk("Frame",{Parent=tb,BackgroundColor3=C.Side,BorderSizePixel=0,Position=UDim2.new(0,0,1,-14),Size=UDim2.new(1,0,0,14)})
  grd(tb,C.Side,C.SideH,90)
  mk("TextLabel",{
    Parent=tb,BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),
    Size=UDim2.new(0,100,1,0),Font=Enum.Font.GothamBold,Text="🐍 YPX",
    TextColor3=C.White,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left
  })
  local gtLbl=mk("TextLabel",{
    Parent=tb,BackgroundTransparency=1,Position=UDim2.new(0,110,0,0),
    Size=UDim2.new(0,100,1,0),Font=Enum.Font.GothamSemibold,Text=gtn,
    TextColor3=C.BlueL,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left
  })
  local fl=mk("TextLabel",{
    Parent=tb,BackgroundTransparency=1,Position=UDim2.new(1,-172,0,0),
    Size=UDim2.new(0,68,1,0),Font=Enum.Font.GothamSemibold,Text="FPS: 60",
    TextColor3=C.Green,TextSize=10,TextXAlignment=Enum.TextXAlignment.Right
  })
  local vLbl=mk("TextLabel",{
    Parent=tb,BackgroundTransparency=1,Position=UDim2.new(1,-100,0,0),
    Size=UDim2.new(0,50,1,0),Font=Enum.Font.GothamSemibold,Text="v12.5",
    TextColor3=C.Gold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Right
  })
  local mnB=mk("TextButton",{
    Parent=tb,BackgroundColor3=C.Off,BorderSizePixel=0,
    Position=UDim2.new(1,-46,0.5,-10),Size=UDim2.new(0,20,0,20),
    Font=Enum.Font.GothamBold,Text="—",TextColor3=C.Gray,TextSize=13,
    AutoButtonColor=false
  })
  crn(mnB,6)
  local clB=mk("TextButton",{
    Parent=tb,BackgroundColor3=C.Red,BorderSizePixel=0,
    Position=UDim2.new(1,-22,0.5,-10),Size=UDim2.new(0,20,0,20),
    Font=Enum.Font.GothamBold,Text="×",TextColor3=C.White,TextSize=13,
    AutoButtonColor=false
  })
  crn(clB,6)
  drag(main,tb)
  local sW=110
  local sb=mk("Frame",{
    Parent=main,BackgroundColor3=C.Side,BorderSizePixel=0,
    Position=UDim2.new(0,0,0,40),Size=UDim2.new(0,sW,1,-40)
  })
  mk("Frame",{Parent=sb,BackgroundColor3=C.Div,BorderSizePixel=0,Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0)})
  local sl=mk("Frame",{Parent=sb,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)})
  mk("UIListLayout",{Parent=sl,Padding=UDim.new(0,3),HorizontalAlignment=Enum.HorizontalAlignment.Center})
  pad(sl,6,6,0,0)
  local ct=mk("Frame",{
    Parent=main,BackgroundColor3=C.BG,BorderSizePixel=0,
    Position=UDim2.new(0,sW,0,40),Size=UDim2.new(1,-sW,1,-40),ClipsDescendants=true
  })
  local ms=false
  mnB.MouseButton1Click:Connect(function()
    ms=not ms
    tw(mnB,{BackgroundColor3=C.BlueD},0.08)
    tdelay(0.1,function() tw(mnB,{BackgroundColor3=C.Off},0.08) end)
    if ms then
      sb.Visible=false ct.Visible=false gtLbl.Visible=false fl.Visible=false vLbl.Visible=false
      tw(main,{Size=UDim2.new(0,180,0,40)},0.22)
    else
      tw(main,{Size=UDim2.new(0,mW,0,mH)},0.22)
      tdelay(0.22,function()
        sb.Visible=true ct.Visible=true gtLbl.Visible=true fl.Visible=true vLbl.Visible=true
        for _,b in pairs(tabBtns) do b.Visible=true end
        for _,p in pairs(tabPgs) do p.Visible=false end
        local idx=math.min(currentTabIdx or 1,#tabPgs)
        if idx<1 then idx=1 end
        if tabPgs[idx] then tabPgs[idx].Visible=true end
        for _,b in pairs(tabBtns) do tw(b,{BackgroundColor3=C.Side,TextColor3=C.Gray}) end
        if tabBtns[idx] then tw(tabBtns[idx],{BackgroundColor3=C.BlueD,TextColor3=C.White}) end
      end)
    end
  end)
  clB.MouseButton1Click:Connect(function()
    tw(main,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0.5,0)},0.2)
    tdelay(0.25,function()
      TM.stopAll() stopFPS() VFX.clear()
      stopFly() setNoclip(false) wsA=false
      sg:Destroy()
    end)
  end)
  startFPS(function(fps,ping)
    if fl and fl.Parent then
      fl.Text="FPS: "..fps
      fl.TextColor3=fps>=50 and C.Green or fps>=30 and C.Orange or C.Red
    end
  end)
  return main,sl,ct
end

local function newTab(sb,ct,name,icon)
  local btn=mk("TextButton",{
    Parent=sb,BackgroundColor3=C.Side,BorderSizePixel=0,
    Size=UDim2.new(1,-6,0,30),Font=Enum.Font.GothamSemibold,
    Text="  "..(icon or "●").."  "..name,TextColor3=C.Gray,TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false
  })
  crn(btn,8)
  local pg=mk("ScrollingFrame",{
    Parent=ct,BackgroundTransparency=1,BorderSizePixel=0,
    Size=UDim2.new(1,0,1,0),ScrollBarThickness=3,
    ScrollBarImageColor3=C.Blue,CanvasSize=UDim2.new(0,0,0,0),
    Visible=false,ScrollBarImageTransparency=0.3
  })
  mk("UIListLayout",{Parent=pg,Padding=UDim.new(0,6),HorizontalAlignment=Enum.HorizontalAlignment.Center})
  pad(pg,8,8,4,4)
  pcall(function() pg.AutomaticCanvasSize=Enum.AutomaticSize.Y end)
  table.insert(tabBtns,btn)
  table.insert(tabPgs,pg)
  local tabIdx=#tabBtns
  local function sel()
    currentTabIdx=tabIdx
    for _,b in pairs(tabBtns) do tw(b,{BackgroundColor3=C.Side,TextColor3=C.Gray}) end
    for _,p in pairs(tabPgs) do p.Visible=false end
    tw(btn,{BackgroundColor3=C.BlueD,TextColor3=C.White})
    pg.Visible=true
  end
  btn.MouseButton1Click:Connect(sel)
  return pg,sel
end

local AS={}

local function buildMenu(sb,ct,gn)
  local t1,s1=newTab(sb,ct,"自动","⚡")
  local clickI=0.1
  toggle(t1,"自动点击(传送+触摸)",false,function(v)
    if v then
      AS.AutoClick=true
      TM.start("AutoClick",clickI,function()
        local n=findNearest(scanTouchables())
        if n then interact(n,Vector3.new(0,3,0)) end
      end)
    else
      AS.AutoClick=false TM.stop("AutoClick")
    end
  end)
  toggle(t1,"自动农场(传送杀怪)",false,function(v)
    if v then
      AS.AutoFarm=true
      log("自动农场已启动","info")
      local farmLocked=false
      local lockPos=nil
      TM.start("AutoFarm",0.5,function()
        local root=getRoot()
        if not root then farmLocked=false lockPos=nil return end
        local best=nil local bd=9999
        local myChar=LP.Character
        local playerChars={}
        for _,pl in pairs(P:GetPlayers()) do
          if pl.Character then playerChars[pl.Character]=true end
        end
        for _,m in pairs(WS:GetDescendants()) do
          if m:IsA("Model") and m~=myChar and not playerChars[m] and not m:IsDescendantOf(myChar or Instance.new("Folder")) then
            local h=m:FindFirstChildOfClass("Humanoid")
            local hrp=m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
            if h and hrp and h.Health>0 then
              pcall(function()
                local d=(hrp.Position-root.Position).Magnitude
                if d>5 and d<bd then bd=d best=hrp end
              end)
            end
          end
        end
        if best then
          tspawn(function()
            -- 只在距离>20时传送,到达后不再传送
            if bd>20 then
              farmLocked=false
              lockPos=nil
              pcall(function()
                root.CFrame=best.CFrame*CFrame.new(0,0,3)
                root.Velocity=Vector3.zero
              end)
              twait(0.05)
            else
              -- 已经到达,锁定位置不再传送
              if not farmLocked then
                farmLocked=true
                lockPos=root.Position
                log("已到达杀怪位置,锁定不再传送","ok")
              end
            end
            -- 攻击逻辑(不论是否传送都执行)
            if fT then
              pcall(function()
                fT(root,best,0)
                twait(0.01)
                fT(root,best,1)
              end)
            end
            fireProx(best)
            fireCD(best)
            VFX.target(best)
            local r=getRemoteFuzzy("attack","click","train","hit","damage","kill","combat","punch")
            if r then fireRemote(r) end
            local r2=findRemoteByType("farm")
            if r2 and r2~=r then fireRemote(r2) end
            pcall(function()
              local hum=getHum()
              if hum then
                hum:ChangeState(Enum.HumanoidStateType.Attacking)
              end
            end)
            clickBtn("attack","train","hit","punch","click","fight")
          end)
        else
          farmLocked=false
          lockPos=nil
          VFX.clear()
        end
      end)
    else
      AS.AutoFarm=false TM.stop("AutoFarm") VFX.clear()
      log("自动农场已关闭","warn")
    end
  end)
  toggle(t1,"自动宝箱",false,function(v)
    if v then
      AS.AutoChest=true
      TM.start("AutoChest",2,function()
        for _,p in pairs(scanTags()) do
          if p and p.Parent then
            local ln=string.lower(p.Name)
            if ln:match("chest") or ln:match("reward") then
              interact(p,Vector3.new(0,3,0))
            end
          end
        end
      end)
    else
      AS.AutoChest=false TM.stop("AutoChest")
    end
  end)
  toggle(t1,"自动购买升级(Buy/Max)",false,function(v)
    if v then
      AS.AutoBuyUpg=true
      log("自动购买升级已启动","info")
      TM.start("AutoBuyUpg",0.5,function()
        scanBtns()
        local clicked=clickAllBtns({"buy","buymax","buy max","max","purchase","upgrade"})
        if clicked>0 then
          local r=findRemoteByType("buy")
          if r then fireRemote(r) end
          if math.random(1,20)==1 then log("自动购买: 点击了"..clicked.."个按钮","ok") end
        end
      end)
    else
      AS.AutoBuyUpg=false TM.stop("AutoBuyUpg")
      log("自动购买升级已关闭","warn")
    end
  end)
  toggle(t1,"自动开包(全图吸取)",false,function(v)
    if v then
      AS.AutoPack=true
      log("自动开包已启动","info")
      TM.start("AutoPack",1,function()
        local root=getRoot()
        if not root then return end
        local found=false
        pcall(function()
          for _,o in pairs(WS:GetDescendants()) do
            if o:IsA("BasePart") and not o:IsDescendantOf(LP.Character or Instance.new("Folder")) then
              local ln=string.lower(o.Name)
              if ln:match("pack") or ln:match("card") or ln:match("gacha") or ln:match("summon") or ln:match("roll") or ln:match("open") then
                local d=(o.Position-root.Position).Magnitude
                if d<500 then
                  tspawn(function()
                    tpTo(o,Vector3.new(0,3,0))
                    twait(0.1)
                    fireTouch(o)
                    fireProx(o)
                    fireCD(o)
                  end)
                  found=true
                end
              end
            end
          end
        end)
        -- 优先Spy重放
        local played=Spy.replay("pack")
        if played==0 then played=Spy.replay("open") end
        if played==0 then played=Spy.replay("gacha") end
        if played==0 then
          clickBtn("open","roll","summon","gacha","spin","pull","pack")
          local r=findRemoteByType("rune")
          if r then fireRemote(r) end
        end
        if found and math.random(1,20)==1 then log("自动开包: 找到包/平台","ok") end
      end)
    else
      AS.AutoPack=false TM.stop("AutoPack")
      log("自动开包已关闭","warn")
    end
  end)
  toggle(t1,"全能自动(扫描交互全部)",false,function(v)
    if v then
      AS.AutoAll=true
      log("全能自动扫描已启动","info")
      TM.start("AutoAll",1,function()
        local c=autoScanInteract()
        if c>0 and math.random(1,10)==1 then log("全能扫描: 交互了"..c.."个对象","ok") end
      end)
    else
      AS.AutoAll=false TM.stop("AutoAll")
      log("全能自动扫描已关闭","warn")
    end
  end)
  button(t1,"🏠 出生点",function()
    local c=LP.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
      local s=WS:FindFirstChild("SpawnLocation")
      c.HumanoidRootPart.CFrame=s and (s.CFrame+Vector3.new(0,5,0)) or CFrame.new(0,50,0)
    end
  end)
  slider(t1,"点击间隔",0.05,2,0.1,function(v)
    clickI=v
    if AS.AutoClick then
      TM.stop("AutoClick")
      TM.start("AutoClick",clickI,function()
        local n=findNearest(scanTouchables())
        if n then interact(n,Vector3.new(0,3,0)) end
      end)
    end
  end)

  local t2,s2=newTab(sb,ct,"商店","🛒")
  -- v12.5: 移除无效功能,只保留重生(用smartRemote)
  toggle(t2,"自动重生(远程调用)",false,function(v)
    if v then
      AS.AutoRebirth=true
      log("自动重生已启动","info")
      TM.start("AutoRebirth",2,function()
        -- 优先用Spy记录重放
        local played=Spy.replay("rebirth")
        if played>0 then return end
        played=Spy.replay("prestige")
        if played>0 then return end
        played=Spy.replay("ascend")
        if played>0 then return end
        -- fallback: 模糊匹配
        local r=findRemoteByType("rebirth")
        if r then fireRemote(r) end
      end)
    else
      AS.AutoRebirth=false TM.stop("AutoRebirth")
      log("自动重生已关闭","warn")
    end
  end)
  toggle(t2,"自动领取(远程调用)",false,function(v)
    if v then
      AS.AutoClaim=true
      log("自动领取已启动","info")
      TM.start("AutoClaim",2,function()
        local played=Spy.replay("claim")
        if played>0 then return end
        played=Spy.replay("reward")
        if played>0 then return end
        local r=findRemoteByType("claim")
        if r then fireRemote(r) end
      end)
    else
      AS.AutoClaim=false TM.stop("AutoClaim")
      log("自动领取已关闭","warn")
    end
  end)

  local t3,s3=newTab(sb,ct,"符文","🔮")
  toggle(t3,"自动抽符文(远程调用)",false,function(v)
    if v then
      AS.AutoRune=true
      log("自动抽符文已启动","info")
      TM.start("AutoRune",0.5,function()
        -- 优先Spy重放
        local played=Spy.replay("rune")
        if played>0 then return end
        played=Spy.replay("roll")
        if played>0 then return end
        played=Spy.replay("gacha")
        if played>0 then return end
        -- fallback
        local r=findRemoteByType("rune")
        if r then fireRemote(r) end
      end)
    else
      AS.AutoRune=false TM.stop("AutoRune")
      log("自动抽符文已关闭","warn")
    end
  end)
  toggle(t3,"符文全图吸取",false,function(v)
    if v then
      AS.AutoRuneMap=true
      log("符文全图吸取已启动","info")
      runeNotifY=0
      local runeCount=0
      TM.start("AutoRuneMap",0.3,function()
        local root=getRoot()
        if not root then return end
        local collected=false
        pcall(function()
          for _,o in pairs(WS:GetDescendants()) do
            if o:IsA("BasePart") and not o:IsDescendantOf(LP.Character or Instance.new("Folder")) then
              local ln=string.lower(o.Name)
              if ln:find("rune",1,true) or ln:find("符文",1,true) then
                local d=(o.Position-root.Position).Magnitude
                if d<2000 then
                  tspawn(function()
                    tpTo(o,Vector3.new(0,3,0))
                    twait(0.05)
                    fireTouch(o)
                    fireProx(o)
                    fireCD(o)
                    -- 优先Spy重放
                    local played=Spy.replay("rune")
                    if played==0 then
                      local r=getRemoteFuzzy("collectrune","collect_rune","pickuprune","pickup_rune","claimrune","claim_rune","getrune","get_rune","rune")
                      if r then fireRemote(r) end
                    end
                  end)
                  collected=true
                  runeCount=runeCount+1
                  runeNotif("✅ 成功获取符文 #"..runeCount,C.Gold)
                  break
                end
              end
            end
          end
        end)
        if not collected then
          local played=Spy.replay("rune")
          if played==0 then
            local r=findRemoteByType("rune")
            if r then fireRemote(r) end
          end
        end
      end)
    else
      AS.AutoRuneMap=false TM.stop("AutoRuneMap")
      log("符文全图吸取已关闭","warn")
    end
  end)
  toggle(t3,"自动Roll(远程调用)",false,function(v)
    if v then
      AS.AutoRoll=true
      log("自动Roll已启动","info")
      TM.start("AutoRoll",0.5,function()
        local played=Spy.replay("roll")
        if played>0 then return end
        played=Spy.replay("reroll")
        if played>0 then return end
        played=Spy.replay("bloodline")
        if played>0 then return end
        local r=getRemoteFuzzy("roll","reroll","rolleyes","roll_eyes","rollbloodline","roll_bloodline","rollblood","roll_blood")
        if r then fireRemote(r) end
      end)
    else
      AS.AutoRoll=false TM.stop("AutoRoll")
      log("自动Roll已关闭","warn")
    end
  end)
  toggle(t3,"自动装备(远程调用)",false,function(v)
    if v then
      AS.AutoEquip=true
      log("自动装备已启动","info")
      TM.start("AutoEquip",2,function()
        local played=Spy.replay("equip")
        if played>0 then return end
        local r=findRemoteByType("equip")
        if r then fireRemote(r) end
      end)
    else
      AS.AutoEquip=false TM.stop("AutoEquip")
      log("自动装备已关闭","warn")
    end
  end)
  toggle(t3,"自动出售(远程调用)",false,function(v)
    if v then
      AS.AutoSell=true
      log("自动出售已启动","info")
      TM.start("AutoSell",2,function()
        local played=Spy.replay("sell")
        if played>0 then return end
        local r=findRemoteByType("sell")
        if r then fireRemote(r) end
      end)
    else
      AS.AutoSell=false TM.stop("AutoSell")
      log("自动出售已关闭","warn")
    end
  end)

  local t4,s4=newTab(sb,ct,"天赋","🎯")
  toggle(t4,"自动天赋(远程调用)",false,function(v)
    if v then
      AS.AutoPerk=true
      log("自动天赋已启动","info")
      TM.start("AutoPerk",1,function()
        local played=Spy.replay("perk")
        if played>0 then return end
        played=Spy.replay("talent")
        if played>0 then return end
        played=Spy.replay("skill")
        if played>0 then return end
        local r=findRemoteByType("perk")
        if r then fireRemote(r) end
      end)
    else
      AS.AutoPerk=false TM.stop("AutoPerk")
      log("自动天赋已关闭","warn")
    end
  end)
  toggle(t4,"自动药水",false,function(v)
    if v then
      AS.AutoPotion=true
      log("自动药水已启动","info")
      TM.start("AutoPotion",1.5,function()
        local used=false
        -- 1. 先打开背包/库存界面
        pcall(function()
          local pg=LP:FindFirstChild("PlayerGui")
          if pg then
            -- 尝试点击背包/库存按钮打开界面
            for _,b in pairs(pg:GetDescendants()) do
              if (b:IsA("TextButton") or b:IsA("ImageButton")) and b.Visible~=false and b.Active~=false then
                local bn=string.lower(b.Name)
                local bt=b:IsA("TextButton") and string.lower(b.Text or "") or ""
                if bn:find("inventory",1,true) or bn:find("backpack",1,true) or bn:find("bag",1,true) or bn:find("背包",1,true) or bn:find("库存",1,true) or bt:find("inventory",1,true) or bt:find("backpack",1,true) or bt:find("bag",1,true) or bt:find("背包",1,true) or bt:find("库存",1,true) then
                  pcall(function()
                    if fS then pcall(fS,b.Activated) pcall(fS,b.MouseButton1Click) end
                    pcall(function() b:Activate() end)
                    pcall(function()
                      local cx=b.AbsolutePosition.X+b.AbsoluteSize.X/2
                      local cy=b.AbsolutePosition.Y+b.AbsoluteSize.Y/2
                      VIM:SendMouseButtonEvent(cx,cy,0,true,b,1)
                      VIM:SendMouseButtonEvent(cx,cy,0,false,b,1)
                    end)
                  end)
                  break
                end
              end
            end
          end
        end)
        twait(0.2)
        -- 2. 在打开的界面内点击药水
        pcall(function()
          local pg=LP:FindFirstChild("PlayerGui")
          if pg then
            for _,b in pairs(pg:GetDescendants()) do
              if (b:IsA("TextButton") or b:IsA("ImageButton")) and b.Visible~=false and b.Active~=false then
                local bn=string.lower(b.Name)
                local bt=b:IsA("TextButton") and string.lower(b.Text or "") or ""
                -- 检测药水相关名称
                local isPotion=bn:find("potion",1,true) or bn:find("boost",1,true) or bn:find("buff",1,true) or bn:find("elixir",1,true) or bn:find("drink",1,true) or bn:find("flask",1,true) or bn:find("药水",1,true) or bn:find("药",1,true) or bt:find("potion",1,true) or bt:find("药水",1,true) or bt:find("use",1,true) or bt:find("drink",1,true) or bt:find("consume",1,true) or bt:find("activate",1,true)
                if isPotion then
                  -- 排除关闭/返回按钮
                  local skip=bn:find("close",1,true) or bn:find("exit",1,true) or bn:find("back",1,true) or bn:find("return",1,true) or bt:find("close",1,true) or bt:find("exit",1,true) or bt:find("返回",1,true) or bt:find("关闭",1,true)
                  if not skip then
                    pcall(function()
                      if fS then pcall(fS,b.Activated) pcall(fS,b.MouseButton1Click) end
                      pcall(function() b:Activate() end)
                      pcall(function()
                        local cx=b.AbsolutePosition.X+b.AbsoluteSize.X/2
                        local cy=b.AbsolutePosition.Y+b.AbsoluteSize.Y/2
                        VIM:SendMouseButtonEvent(cx,cy,0,true,b,1)
                        VIM:SendMouseButtonEvent(cx,cy,0,false,b,1)
                      end)
                      used=true
                      log("点击药水: "..b.Name,"ok")
                    end)
                  end
                end
              end
            end
          end
        end)
        -- 3. 备用: 尝试背包Tool
        if not used then
          pcall(function()
            local backpack=LP:FindFirstChild("Backpack")
            local char=LP.Character
            for _,tool in pairs(backpack and backpack:GetChildren() or {}) do
              if tool:IsA("Tool") then
                local tn=string.lower(tool.Name)
                if tn:find("potion",1,true) or tn:find("boost",1,true) or tn:find("buff",1,true) or tn:find("药水",1,true) or tn:find("药",1,true) then
                  pcall(function()
                    local hum=char and char:FindFirstChildOfClass("Humanoid")
                    if hum then
                      tspawn(function()
                        pcall(function()
                          hum:EquipTool(tool)
                          twait(0.1)
                          tool:Activate()
                        end)
                      end)
                      used=true
                      log("使用药水: "..tool.Name,"ok")
                    end
                  end)
                end
              end
            end
          end)
        end
        -- 4. 备用: Remote
        if not used then
          local r=findRemoteByType("potion")
          if r then fireRemote(r) used=true end
          local r2=getRemoteFuzzy("usepotion","use_potion","drinkpotion","activatepotion","usebuff","use_buff")
          if r2 then fireRemote(r2) used=true end
        end
      end)
    else
      AS.AutoPotion=false TM.stop("AutoPotion")
      log("自动药水已关闭","warn")
    end
  end)

  local t5,s5=newTab(sb,ct,"透视","👁")
  toggle(t5,"ESP透视开关",false,function(v)
    if v then ESP.start() notif("ESP已启动",C.Green)
    else ESP.stop() notif("ESP已关闭",C.Orange) end
  end)
  toggle(t5,"显示敌人",true,function(v) ESP.cfg.enemies=v end)
  toggle(t5,"显示物品",true,function(v) ESP.cfg.items=v end)
  toggle(t5,"显示玩家",true,function(v) ESP.cfg.players=v end)
  slider(t5,"透视距离",100,2000,500,function(v) ESP.cfg.distance=v end)

  local t6,s6=newTab(sb,ct,"功能","🚀")
  toggle(t6,"飞行(按WASD/空格)",false,function(v)
    if v then startFly() else stopFly() end
  end)
  toggle(t6,"穿墙",false,function(v) setNoclip(v) end)
  toggle(t6,"加速",false,function(v) setWS(v,wsSp) end)
  slider(t6,"飞行/加速速度",16,200,60,function(v)
    flySp=v
    if wsA then setWS(true,v) end
  end)
  toggle(t6,"无限跳跃",false,function(v) Flags.InfJ=v end)
  toggle(t6,"反挂机(防AFK踢出)",false,function(v)
    if v then AAFK.start() else AAFK.stop() notif("反挂机已关闭",C.Orange) end
  end)
  button(t6,"🏠 出生点",function()
    local c=LP.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
      local s=WS:FindFirstChild("SpawnLocation")
      c.HumanoidRootPart.CFrame=s and (s.CFrame+Vector3.new(0,5,0)) or CFrame.new(0,50,0)
    end
  end)

  local t7,s7=newTab(sb,ct,"工具","🔧")
  button(t7,"🔄 重新扫描Remote",function()
    remoteCache=scanRemotes()
    local c=0 for _ in pairs(remoteCache) do c=c+1 end
    notif("扫描完成: "..c.."个Remote",C.Green)
  end)
  button(t7,"🔄 重新扫描按钮",function()
    scanBtns()
    local c=0 for _ in pairs(btnCache) do c=c+1 end
    notif("扫描完成: "..c.."个按钮",C.Green)
  end)
  button(t7,"📋 扫描全game远程事件",function()
    local lines={}
    pcall(function()
      for _,o in pairs(game:GetDescendants()) do
        if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
          local fn=o.Name
          pcall(function() fn=o:GetFullName() end)
          table.insert(lines,fn.."  ["..o.ClassName.."]")
        end
      end
    end)
    table.sort(lines)
    log("═══ Remote扫描 ("..#lines.."个) ═══","info")
    for _,l in ipairs(lines) do log(l,"info") end
    notif("已输出 "..#lines.." 个Remote到日志",C.Blue)
  end)
  -- ===== RemoteSpy Hook控制 =====
  local spyState=false
  toggle(t7,"🔴 Spy录制(去重记录)",false,function(v)
    spyState=v
    if v then
      Spy.start()
      notif("Spy录制已启动,请在游戏内操作",C.Green)
    else
      Spy.stop()
      notif("Spy已停止,记录"..Spy.count.."条",C.Orange)
    end
  end)
  button(t7,"📋 查看Spy记录",function()
    if Spy.count==0 then
      notif("暂无记录,请先开启Spy录制",C.Orange)
      return
    end
    log("═══ Spy记录 ("..Spy.count.."条,已去重) ═══","info")
    for i,rec in pairs(Spy.records) do
      local argsStr=spyArgsKey(rec.args)
      log("#"..i.." ["..rec.cls.."] "..rec.name.."("..argsStr..")","info")
    end
    notif("已输出 "..Spy.count.." 条记录到日志",C.Blue)
  end)
  button(t7,"🗑️ 清空Spy记录",function()
    local old=Spy.count
    Spy.clear()
    notif("已清空"..old.."条记录",C.Orange)
  end)
  button(t7,"🔄 重放全部记录",function()
    if Spy.count==0 then
      notif("暂无记录可重放",C.Orange)
      return
    end
    local played=0
    for i,rec in pairs(Spy.records) do
      local r=getRemote(rec.name)
      if not r then
        pcall(function()
          local parts=string.split(rec.path,".")
          local obj=game
          for j=2,#parts do
            obj=obj:FindFirstChild(parts[j])
            if not obj then break end
          end
          if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then r=obj end
        end)
      end
      if r then
        fireRemote(r,unpack(rec.args))
        played=played+1
      end
    end
    notif("重放"..played.."/"..Spy.count.."条",C.Green)
    log("重放完成: "..played.."/"..Spy.count,"ok")
  end)
  local pl=mk("TextLabel",{
    Parent=t7,BackgroundTransparency=1,Size=UDim2.new(1,-4,0,20),
    Position=UDim2.new(0,2,0,0),Font=Enum.Font.GothamSemibold,Text="",
    TextColor3=C.BlueL,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left
  })
  TM.start("PerfDisp",1,function()
    local s=fpsV>=50 and "流畅" or fpsV>=30 and "一般" or "卡顿"
    pl.Text="FPS: "..fpsV.." | PING: "..pingV.."ms | "..s
    pl.TextColor3=fpsV>=50 and C.Green or fpsV>=30 and C.Orange or C.Red
  end)

  local t8,s8=newTab(sb,ct,"日志","📋")
  LogSys.scroll=mk("ScrollingFrame",{
    Parent=t8,BackgroundTransparency=1,BorderSizePixel=0,
    Size=UDim2.new(1,-4,0,280),ScrollBarThickness=3,
    ScrollBarImageColor3=C.Blue,CanvasSize=UDim2.new(0,0,0,0)
  })
  mk("UIListLayout",{Parent=LogSys.scroll,Padding=UDim.new(0,3),HorizontalAlignment=Enum.HorizontalAlignment.Left})
  pad(LogSys.scroll,2,2,4,4)
  pcall(function()
    for _,l in pairs(LogSys.labels) do pcall(function() l:Destroy() end) end
    LogSys.labels={}
    for i=#LogSys.lines,1,-1 do
      local e=LogSys.lines[i]
      local l=mk("TextLabel",{
        Parent=LogSys.scroll,BackgroundTransparency=1,
        Size=UDim2.new(1,-8,0,16),Font=Enum.Font.GothamSemibold,
        Text=e.text,TextColor3=e.color,TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd
      })
      table.insert(LogSys.labels,l)
    end
    local c=#LogSys.lines*19
    LogSys.scroll.CanvasSize=UDim2.new(0,0,0,c)
  end)
  button(t8,"清空日志",function()
    LogSys.lines={}
    for _,l in pairs(LogSys.labels) do pcall(function() l:Destroy() end) end
    LogSys.labels={}
    LogSys.scroll.CanvasSize=UDim2.new(0,0,0,0)
    log("日志已清空","info")
  end)
  button(t8,"输出Remote列表到日志",function()
    local lines={}
    pcall(function()
      for _,o in pairs(game:GetDescendants()) do
        if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
          local fn=o.Name
          pcall(function() fn=o:GetFullName() end)
          table.insert(lines,fn.."  ["..o.ClassName.."]")
        end
      end
    end)
    table.sort(lines)
    log("═══ Remote扫描 ("..#lines.."个) ═══","info")
    for _,l in ipairs(lines) do log(l,"info") end
    notif("已输出 "..#lines.." 个Remote到日志",C.Blue)
  end)
  button(t8,"输出GUI按钮列表到日志",function()
    scanBtns()
    local c=0
    for n,b in pairs(btnCache) do
      local fn=n
      pcall(function() fn=b:GetFullName() end)
      log("按钮: "..fn,"info")
      c=c+1
    end
    notif("已输出 "..c.." 个按钮到日志",C.Blue)
  end)
  log("YPX v12.5 日志系统就绪","ok")
end

local TN={universal="通用模式",anime_incremental="Anime Inc."}

-- ==================== 主加载流程 ====================
tspawn(function()
  local gT,gN,pId
  local main,sb,ct
  local ok,err

  ok,err=pcall(function()
    stT.Text="正在初始化..." twait(0.3)
    tw(bf,{Size=UDim2.new(0,60,1,0)},0.2)

    stT.Text="正在检测游戏..."
    for i=3,1,-1 do
      cdT.Text=tostring(i)
      tw(cdT,{TextSize=28},0.06)
      twait(0.15)
      tw(cdT,{TextSize=24},0.06)
      twait(0.15)
    end
    tw(bf,{Size=UDim2.new(0,100,1,0)},0.2)

    gT,gN,pId=detectGame()
    gnT.Text=gN
    stT.Text="检测到: "..(TN[gT] or "通用")
    log("游戏检测: "..tostring(gN).." (ID:"..tostring(pId)..")","info")
    log("游戏类型: "..(TN[gT] or "通用"),"info")
    twait(0.2)
    tw(bf,{Size=UDim2.new(0,140,1,0)},0.2)

    stT.Text="正在扫描全game数据..."
    remoteCache=scanRemotes()
    scanBtns()
    scanLS()
    local rc1=0 for _ in pairs(remoteCache) do rc1=rc1+1 end
    local bc1=0 for _ in pairs(btnCache) do bc1=bc1+1 end
    log("扫描完成: "..rc1.." Remote, "..bc1.." GUI按钮","info")
    twait(0.2)
    tw(bf,{Size=UDim2.new(0,200,1,0)},0.2)

    LP.CharacterAdded:Connect(function() twait(1) scanLS() end)

    stT.Text="正在构建菜单..." twait(0.2)
    main,sb,ct=buildMain(TN[gT] or "通用")
    buildMenu(sb,ct,gN)

    tw(bf,{Size=UDim2.new(0,260,1,0)},0.2)
    cdT.Text="✅"
    stT.Text="加载完成!" twait(0.3)
  end)

  if not ok then
    log("[YPX Error] "..tostring(err),"err")
    pcall(function()
      gT="universal" gN="错误恢复"
      main,sb,ct=buildMain("维护模式")
      buildMenu(sb,ct,gN)
    end)
    pcall(function()
      cdT.Text="⚠️"
      stT.Text="维护模式启动"
      gnT.Text=gN or "未知"
    end)
  end

  -- 淡出加载界面
  pcall(function()
    tw(ls,{BackgroundTransparency=1},0.3)
    for _,o in pairs(ls:GetChildren()) do
      if o:IsA("TextLabel") then tw(o,{TextTransparency=1},0.3) end
    end
    tw(bb,{BackgroundTransparency=1},0.3)
    tw(bf,{BackgroundTransparency=1},0.3)
  end)
  twait(0.35)
  pcall(function() ls:Destroy() end)

  if main then main.Visible=true end

  PM.start()

  -- 悬浮按钮
  local fb=mk("TextButton",{
    Parent=sg,BackgroundColor3=C.BlueD,BorderSizePixel=0,
    Position=UDim2.new(0,10,0.45,-22),Size=UDim2.new(0,44,0,44),
    Font=Enum.Font.GothamBold,Text="≡",TextColor3=C.White,TextSize=20,
    AutoButtonColor=false
  })
  crn(fb,12) stk(fb,C.BlueL,1.5,0.2) grd(fb,C.BlueD,C.Blue,90)

  local vis=true
  fb.MouseButton1Click:Connect(function()
    vis=not vis
    if main then main.Visible=vis end
    tw(fb,{BackgroundColor3=vis and C.BlueD or C.Off},0.1)
  end)

  local fd,fs,fp
  fb.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
      fd=true fs=i.Position fp=fb.Position
    end
  end)
  UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then fd=false end
  end)
  UIS.InputChanged:Connect(function(i)
    if fd and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
      local dl=i.Position-fs
      fb.Position=UDim2.new(fp.X.Scale,fp.X.Offset+dl.X,fp.Y.Scale,fp.Y.Offset+dl.Y)
    end
  end)

  -- RightShift显隐
  UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.RightShift then
      vis=not vis
      if main then main.Visible=vis end
    end
  end)

  -- 启动89R币弹窗拦截器
  startBlock89R()
  log("89R币弹窗拦截器已启动","info")

  -- 加载通知
  local nt=ok and ("✅ "..(TN[gT] or "通用").."  v12.5") or "⚠️ 维护模式"
  local nf=mk("TextLabel",{
    Parent=sg,BackgroundColor3=ok and C.BlueD or C.Orange,BorderSizePixel=0,
    Position=UDim2.new(0.5,-130,0,-40),Size=UDim2.new(0,260,0,34),
    Font=Enum.Font.GothamSemibold,Text="  "..nt,TextColor3=C.White,TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
  })
  crn(nf,8) stk(nf,ok and C.BlueD or C.Orange,1,0.2)
  tw(nf,{Position=UDim2.new(0.5,-130,0,10)},0.25)
  tdelay(3,function()
    tw(nf,{Position=UDim2.new(0.5,-130,0,-40)},0.25)
    tdelay(0.3,function() pcall(function() nf:Destroy() end) end)
  end)

  print("═══════════════════════════════════")
  print("  ✅ YPX v12.5 已加载!")
  print("  游戏类型: "..(TN[gT] or "通用"))
  print("  游戏名称: "..tostring(gN))
  print("  PlaceId: "..tostring(pId))
  local rc2=0 for _ in pairs(remoteCache) do rc2=rc2+1 end
  print("  缓存: "..rc2.." Remote")
  print("  引擎: RemoteSpy Hook | 远程调用 | ESP | 反挂机 | 性能监控 | 飞行 | 穿墙 | 日志 | 符文吸取 | 89R拦截")
  print("  按 RightShift 或悬浮按钮 显示/隐藏")
  print("  日志在「日志」标签页查看")
  print("═══════════════════════════════════")
end)

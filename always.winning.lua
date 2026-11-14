-- always.winning | Rivals | Obsidian UI
-- skid base: hooker/Kicia feature set

if getgenv().AlwaysWinning and getgenv().AlwaysWinning.Unload then
    pcall(getgenv().AlwaysWinning.Unload)
end
if not game:IsLoaded() then game.Loaded:Wait() end

local AW = { connections = {}, cleanups = {}, destroyed = false }
getgenv().AlwaysWinning = AW

-- ══════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════
local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService= game:GetService("CollectionService")
local HttpService      = game:GetService("HttpService")
local SoundService     = game:GetService("SoundService")
local Lighting         = game:GetService("Lighting")
local TweenService     = game:GetService("TweenService")
local lplr             = Players.LocalPlayer

-- ══════════════════════════════════════════════
--  EXECUTOR HELPERS
-- ══════════════════════════════════════════════
local function fn(name)
    local v; pcall(function() v = getgenv()[name] end)
    return type(v) == "function" and v or nil
end
local cloneref_        = fn("cloneref")       or function(x) return x end
local setthreadid_     = fn("setthreadidentity") or fn("setidentity") or function() end
local getthreadid_     = fn("getthreadidentity") or fn("getidentity") or function() return 8 end
local sethiddenprop_   = fn("sethiddenproperty")
local firetouchinterest= fn("firetouchinterest") or function() end
local getconnections_  = fn("getconnections")   or function() return {} end
local setclipboard_    = fn("setclipboard")     or fn("toclipboard") or function() end
local getrawmeta_      = fn("getrawmetatable")  or getmetatable
local setrawmeta_      = fn("setrawmetatable")  or setmetatable
local clonefn_ = function(f)
    local c = fn("clonefunction")
    if c and f then local ok,r=pcall(c,f); if ok and r then return r end end
    return f
end

pcall(setthreadid_, 8)

local fireServer  = clonefn_(Instance.new("RemoteEvent").FireServer)
local fireServer2 = clonefn_(Instance.new("UnreliableRemoteEvent").FireServer)

-- ══════════════════════════════════════════════
--  WAIT FOR GAME READINESS
-- ══════════════════════════════════════════════
local function waitForClient()
    local t0 = os.clock()
    while not lplr and os.clock()-t0 < 60 do task.wait() end
    lplr = Players.LocalPlayer
    if not lplr then warn("[always.winning] no LocalPlayer"); return false end
    local ps = lplr:FindFirstChild("PlayerScripts")
    if not ps then pcall(function() lplr:WaitForChild("PlayerScripts",60) end) end
    ps = lplr:FindFirstChild("PlayerScripts")
    if not ps then warn("[always.winning] no PlayerScripts"); return false end
    local ctrl = ps:FindFirstChild("Controllers")
    if not ctrl then pcall(function() ps:WaitForChild("Controllers",30) end) end
    ctrl = ps:FindFirstChild("Controllers")
    if not ctrl then warn("[always.winning] Controllers not found — not in Rivals?"); return false end
    local t1 = os.clock()
    while os.clock()-t1 < 45 do
        local ch  = lplr.Character
        local pg  = lplr:FindFirstChild("PlayerGui")
        local ok1 = ch ~= nil and ch:FindFirstChildOfClass("Humanoid") ~= nil
        local ok2 = false
        if pg then local n=0; for _,c in ipairs(pg:GetChildren()) do if c:IsA("ScreenGui") then n=n+1 end end; ok2=n>=2 end
        if ok1 and ok2 then break end
        task.wait(1)
    end
    return true
end

-- ══════════════════════════════════════════════
--  GAME MODULE REFS
-- ══════════════════════════════════════════════
local RepS       = cloneref_(ReplicatedStorage)
local Modules    = RepS:WaitForChild("Modules",30)
local Remotes    = RepS:WaitForChild("Remotes",30)
local PlayerScripts = lplr:WaitForChild("PlayerScripts",30)
local Controllers   = PlayerScripts and PlayerScripts:WaitForChild("Controllers",30)

local ok_util,  Util   = pcall(require, Modules and Modules:FindFirstChild("Utility"))
local ok_enum,  EnumLib= pcall(require, Modules and Modules:FindFirstChild("EnumLibrary"))
local ok_fc,    FC     = pcall(require, Controllers and Controllers:FindFirstChild("FighterController"))
local ok_sc,    SC     = pcall(require, Controllers and Controllers:WaitForChild("SpectateController",5))

-- ══════════════════════════════════════════════
--  INTERNAL SIGNAL (Kicia's)
-- ══════════════════════════════════════════════
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({_handlers={}},Signal) end
function Signal:Connect(fn_)
    local h={fn=fn_,connected=true}
    table.insert(self._handlers,h)
    local sig=self
    return {Connected=true,Disconnect=function(c) if not h.connected then return end h.connected=false c.Connected=false local i=table.find(sig._handlers,h) if i then table.remove(sig._handlers,i) end end}
end
function Signal:Once(fn_) local c; c=self:Connect(function(...) c:Disconnect(); fn_(...) end) return c end
function Signal:Fire(...) local list=table.clone(self._handlers) for _,h in ipairs(list) do if h.connected then task.spawn(h.fn,...) end end end
function Signal:FireSync(...) for _,h in ipairs(table.clone(self._handlers)) do if h.connected then h.fn(...) end end end
function Signal:Destroy() table.clear(self._handlers) end

-- ══════════════════════════════════════════════
--  TROVE
-- ══════════════════════════════════════════════
local Trove = {}
Trove.__index = Trove
function Trove.new(name) return setmetatable({_name=name,_items={}},Trove) end
local function cleanItem(o)
    local t=typeof(o)
    if t=="RBXScriptConnection" then o:Disconnect()
    elseif t=="Instance" then pcall(function() o:Destroy() end)
    elseif t=="thread" then pcall(task.cancel,o)
    elseif type(o)=="function" then pcall(o)
    elseif type(o)=="table" then
        local function mem(k) local ok,v=pcall(function() return o[k] end) return ok and type(v)=="function" and v or nil end
        local d=mem("Destroy") if d then pcall(d,o) return end
        local dc=mem("Disconnect") if dc then pcall(dc,o) end
    end
end
function Trove:Add(o) table.insert(self._items,o) return o end
function Trove:Connect(sig,fn_) return self:Add(sig:Connect(fn_)) end
function Trove:Extend() return self:Add(Trove.new(self._name)) end
function Trove:Clean() local items=self._items self._items={} self._cleaning=true for i=#items,1,-1 do cleanItem(items[i]) end self._cleaning=false end
Trove.Destroy=Trove.Clean

local GlobalTrove = Trove.new("always.winning")

-- ══════════════════════════════════════════════
--  CONFIG (all features mirrored from Kicia)
-- ══════════════════════════════════════════════
local cfg = {
    -- Aimbot
    Aimbot = {
        Enabled=false, Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true},
        Fov={Enabled=true,Radius=150}, HitboxSelection={Type="ClosestToCrosshair"},
        Smooth=0.15, PredictionMode="Velocity", PredictionOffset=0,
        TargetPriority="ClosestToCrosshair", TargetSwitch="Never",
        VisibilityCheck=false, TeamCheck=true, SpectatorCheck=true,
        Labels={WithinFov="Within FOV"},
    },
    -- Silent Aim
    SilentAim = {
        Manipulate={Enabled=false,Mode="Constant",ShowIndicator=false},
        Triggerbot={Enabled=false,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true},
            HoldDuration=0,Delay=0,TargetPart="HumanoidRootPart",
            VisibilityCheck=false,TeamCheck=true,Labels={NotDeflecting="Not Deflecting",NotShielded="Not Shielded",WithinFov="Within FOV"}},
    },
    -- Ragebot
    Ragebot = {
        Enabled=false, Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true},
        Stability=0.15, ShootFrames=1, PrioritizeHackers=false,
        Weapons={Priority={"Primary","Secondary","Melee"},Enabled={Primary=true,Secondary=true,Melee=true},OnEmpty="SwapOrReload"},
        Evasion={Mode="Random",Random={AnchorFromCharacter=false,BaseRadius=100,RadiusRandomFactor=0.5}},
        UtilizeHealthLead=false,
    },
    -- Flickbot
    Flickbot = {
        Enabled=false, Keybind={State=false,Kind="Hold",Bind=nil,ShowInList=true},
        Shoot=false, ShotDelay=0, Cooldown=250, FlickDuration=110, Curvature=12, Humanness=30,
    },
    -- ESP
    Esp = {
        Main={Enabled=false,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true},Mode="Static"},
        Enemy={
            Enabled=false, Name={Enabled=false,Color=Color3.fromRGB(255,255,255),Transparency=0},
            Box={Enabled=false,Style="Full",Color=Color3.fromRGB(255,255,255)},
            FilledBox={Enabled=false,Color=ColorSequence.new(Color3.new(1,1,1)),Transparency=0.8},
            HealthBar={Enabled=false,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,1,0)),ColorMode="Reactive"},
            HealthNumber={Enabled=false,Color=Color3.new(1,1,1)},
            HeldWeapon={Enabled=false,Color=Color3.new(1,1,1),Transparency=0},
            AmmoBar={Enabled=false,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,1,0)),ColorMode="Reactive"},
            Distance={Enabled=false,Color=Color3.new(1,1,1)},
            Rank={Enabled=false,Color=Color3.new(1,1,1)},
            Winstreak={Enabled=false,Color=Color3.new(1,1,1)},
            Deflecting={Enabled=false,Color=Color3.new(1,1,1),Transparency=0},
            Chams={Enabled=false,Kind="Legacy",InnerColor=Color3.fromRGB(255,0,0),InnerTransparency=0,OutlineColor=Color3.fromRGB(100,0,0),OutlineTransparency=0.6,Glow=false,GlowColor=Color3.fromRGB(255,0,0)},
            Skeleton={Enabled=false,Color=ColorSequence.new(Color3.new(1,1,1)),Transparency=0,Thickness=1},
            HeadMarker={Enabled=false,Shape="Cross",Filled=true,Outline=false,Color=Color3.fromRGB(255,80,80),Transparency=0,OutlineColor=Color3.new(0,0,0)},
            Tracer={Enabled=false,Color=ColorSequence.new(Color3.new(1,1,1)),Transparency=0,Thickness=1,Origin="Bottom",Target="Feet",Outline=false,OutlineThickness=1},
        },
        Settings={UseDisplayName=false,Font="Inconsolata",FlagFont="Inconsolata",FontSize=16,FlagFontSize=12,TextCase="Standard",FlagTextCase="UPPERCASE",TextSurround="None",FlagTextSurround="None",DistanceScaling=false,DistanceScalingRef=50},
        RankSpoof={Enabled=false,Text="Radiant",Icon="★"},
    },
    -- Sound Visualizer
    SoundVisualizer = {
        Enabled=false, Source="All", MinVolume=0,
        Footsteps={Mode="Circle",UseLoudnessColor=true,Color=Color3.fromRGB(0,255,100)},
        Other={Mode="Origin",UseLoudnessColor=true,Color=Color3.fromRGB(0,200,255)},
    },
    -- Movement
    Movement = {
        WalkSpeed={Enabled=false,Speed=2,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true}},
        JumpPower={Enabled=false,Speed=2,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=false}},
        Flight={Enabled=false,Speed=100,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true}},
        Sliding={Enabled=false,Speed=10,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true}},
        Noclip={Enabled=false,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true}},
        AutoStrafe={Enabled=false,Speed=50,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true}},
        LongJump={Enabled=false,Keybind={State=false,Kind="Tap",Bind=nil,ShowInList=true},Mode="Under Feet",Force=60,UpwardVelocity=20,Behind=8},
        MovementRecorder={Enabled=false,HideUI=false,HideNotifications=false,OpenDistance=3,RenderDistance=50,LookAlignSpeed=180},
    },
    -- Removables
    Removables = {
        NoFlashbang=false, NoBurnEffect=false, NoAdsVignette=false,
        NoScopeOverlay=false, NoScopeReticle=false, NoGunTracers=false,
        NoMuzzleFlash=false, NoHitmarker=false,
    },
    -- Third Person
    ThirdPerson={Enabled=false,Keybind={State=false,Kind="Always",Bind=nil,ShowInList=true},ShowReplica=false,RayCheck=false,X=3,Y=2,Z=6},
    -- Camera FOV
    CameraFov={Enabled=false,Value=70},
    -- Stretched Resolution
    StretchedResolution={Enabled=false,X=13,Y=10},
    -- Custom Crosshair
    CustomCrosshair={
        Enabled=false, Style="Lines",
        Length=12, Thickness=2, Gap=6,
        Outline={Enabled=false,Color=Color3.fromRGB(0,0,0),Thickness=1},
        Rotation={Enabled=false,Angle=0,Speed=90},
        Spread={Enabled=false,Range={Min=4,Max=16},Speed=3},
        Top={Enabled=true,Color=ColorSequence.new(Color3.fromRGB(255,255,255))},
        Bottom={Enabled=true,Color=ColorSequence.new(Color3.fromRGB(255,255,255))},
        Left={Enabled=true,Color=ColorSequence.new(Color3.fromRGB(255,255,255))},
        Right={Enabled=true,Color=ColorSequence.new(Color3.fromRGB(255,255,255))},
        Text={Enabled=false,Content="",Font="Inconsolata",Size=14,Offset=24},
        FollowTarget={Enabled=false,Mode="Crosshair",Speed=20,Damper=1,SnapDistance=5},
    },
    -- Animation Player
    AnimationPlayer={Enabled=false,Animation="Cat Girl Bounce",CustomId="",Speed=1,Start=0,End=100},
    -- Device Spoof
    DeviceSpoof={Enabled=false,SpoofType="VR"},
    -- Player Spoofer
    PlayerSpoofer={
        LocalPlayer={
            Name={Enabled=false,Value=""},DisplayName={Enabled=false,Value=""},
            Avatar={Enabled=false,Value=""},Ping={Enabled=false,Value="Low"},
            Keys={Enabled=false,Value=999},EventCurrency={Enabled=false,Value=9999},
            Winstreak={Enabled=false,Value=999},Level={Enabled=false,Value=999},
            CasualWins={Enabled=false,Value=99999},RankedWins={Enabled=false,Value=9999},
            CasualWinPercent={Enabled=false,Value=100},RankedWinPercent={Enabled=false,Value=100},
            RankedElo={Enabled=false,Value=3600},LeaderboardRank={Enabled=false,Value=1},
            FavoriteMap={Enabled=false,Value="Arena"},NametagStatus={Enabled=false,Value="Prime"},
            Influencer={Enabled=false,Value=true},RobloxEmployee={Enabled=false,Value=true},
        },
        OtherPlayers={
            Name={Enabled=false,Value=""},DisplayName={Enabled=false,Value=""},
            Avatar={Enabled=false,Value=""},Winstreak={Enabled=false,Value=0},
            Level={Enabled=false,Value=0},CasualWins={Enabled=false,Value=0},
            RankedWins={Enabled=false,Value=0},CasualWinPercent={Enabled=false,Value=0},
            RankedWinPercent={Enabled=false,Value=0},RankedElo={Enabled=false,Value=0},
            LeaderboardRank={Enabled=false,Value=200},FavoriteMap={Enabled=false,Value=""},
            NametagStatus={Enabled=false,Value="Prime"},
        },
    },
    -- Item Modifiers
    ItemModifiers = {
        NoMotion=false, NoCameraShake=false, NoCameraSway=false,
        NoShootAnimation=false, NoSprintAnimation=false, NoEquipAnimation=false,
        NoReloadAnimation=false, NoSpread=false,
        AimCooldown={Enabled=false,Percentage=50},
        Recoil={Enabled=false,Percentage=75},
        FireCooldown={Enabled=false,Percentage=25},
        AimSpeed={Enabled=false,Percentage=300},
        MeleeCooldown={Enabled=false,Percentage=25},
        DashCooldown={Enabled=false,Percentage=25},
        ExtendMeleeRange={Enabled=false,Range=10},
        InfiniteDoubleJumps=false, AlwaysBackstab=false, FastShoot=false,
        FastProjectile=false, FullAuto=false,
        FireRate={Enabled=false,Percentage=100},
        GrenadeFuse={Enabled=false,ExplodeOn="Impact",RemoveFuse=false},
    },
    -- Bullet Tracers
    BulletTracers={Enabled=false,Color=Color3.fromRGB(120,220,255),Width=0.06,Lifetime=0.6,FadeTime=0.35,Style="Beam",TextureLength=4,TextureSpeed=1,Emission=1,Glow=1,Expand=true,ExpandSpeed=18,ExpandDamper=0.7},
    -- ViewModel Offset
    ViewModelOffset={Enabled=false,X=0,Y=0,Z=0,Pitch=0,Yaw=0,Roll=0},
    -- Chams (self)
    Chams={
        Character={Enabled=false,Material="Ghost",Color=Color3.fromRGB(255,255,255),Transparency=0,StripTextures=false},
        Arms={Enabled=false,Material="Ghost",Color=Color3.fromRGB(255,255,255),Transparency=0,StripTextures=true},
        Item={Enabled=false,Material="Ghost",Color=Color3.fromRGB(255,255,255),Transparency=0,StripTextures=false},
    },
    -- ViewModelHighlight
    ViewModelHighlight={
        Arms={Enabled=false,AlwaysOnTop=false,FillColor=Color3.fromRGB(255,255,255),FillTransparency=0.5,OutlineColor=Color3.fromRGB(255,255,255),OutlineTransparency=0},
        Item={Enabled=false,AlwaysOnTop=false,FillColor=Color3.fromRGB(255,255,255),FillTransparency=0.5,OutlineColor=Color3.fromRGB(255,255,255),OutlineTransparency=0},
    },
    -- ViewModelWireframe
    ViewModelWireframe={
        Arms={Enabled=false,Color=Color3.fromRGB(255,255,255),Width=0.0025},
        Item={Enabled=false,Color=Color3.fromRGB(255,255,255),Width=0.0025},
    },
    -- Player Hit / Elimination
    PlayerHit={
        Enabled=false,
        Sound={Enabled=false,DisableGameSound=false,HeadVolume=1,HeadPitch=1,BodyVolume=1,BodyPitch=1},
        Notification={Enabled=false,Text="Hit %DNAME% (%NAME%) for %DMG% in %PART%"},
        Chams={Enabled=false,Color=Color3.fromRGB(255,0,0),Transparency=0,Duration=0.8,Material="Ghost"},
        HitFlash={Enabled=false,Color=Color3.fromRGB(90,170,255),Duration=1.35},
    },
    PlayerElimination={
        Enabled=false,
        Sound={Enabled=false,Volume=1,Pitch=1},
        Notification={Enabled=false,Text="Eliminated %DNAME% (%NAME%)"},
        Chams={Enabled=false,Color=Color3.fromRGB(255,0,0),Transparency=0,Duration=0.8,Material="Ghost"},
        KillFlash={Enabled=false,Color=Color3.fromRGB(90,170,255),Duration=1.35},
    },
    -- Misc / Automation
    AutoPickupDrops={Enabled=false},
    AutoRespawn={Enabled=false},
    AntiKatana={Enabled=true},
    SubspaceTripmines={AutoTrigger=false,TeamTrigger=false},
    AutoQueue={Enabled=false,Queue="1v1"},
    AutoVote={Enabled=false},
    AutoBan={Enabled=false},
    AutoLoadout={Enabled=false,PerMap=false,MultipleLoadouts=false},
    HackerDetector={Enabled=false,Notify=false,Color=Color3.fromRGB(250,170,70)},
    ModDetector={Enabled=false,Color=Color3.fromRGB(250,170,70)},
    -- Unlock All
    UnlockAll={Enabled=false},
    -- Watermark
    ShowWatermark=true,
}

-- ══════════════════════════════════════════════
--  SPRING (critically damped)
-- ══════════════════════════════════════════════
local Spring={}; Spring.__index=Spring
local function posVel(s,now)
    local p0,v0,p1,d,sp=s._p0,s._v0,s._target,s._damper,s._speed
    local t=sp*(now-s._t0); local d2=d*d; local h,si,co
    if d2<1 then h=math.sqrt(1-d2) local ep=math.exp(-d*t)/h co,si=ep*math.cos(h*t),ep*math.sin(h*t)
    elseif d2==1 then h=1 local ep=math.exp(-d*t)/h co,si=ep,ep*t
    else h=math.sqrt(d2-1) local u,v=math.exp((-d+h)*t)/(2*h),math.exp((-d-h)*t)/(2*h) co,si=u+v,u-v end
    local a0,a1=h*co+d*si,1-(h*co+d*si); local a2=si/sp
    return a0*p0+a1*p1+a2*v0, -sp*si*p0+sp*si*p1+(h*co-d*si)*v0
end
function Spring.new(init,clock) init=init or 0; clock=clock or os.clock; return setmetatable({_clock=clock,_t0=clock(),_p0=init,_v0=0*init,_target=init,_damper=1,_speed=1},Spring) end
function Spring:Impulse(v) self.Velocity=self.Velocity+v end
function Spring:SetTarget(v,skip) if skip then self._p0,self._v0,self._target,self._t0=v,0*v,v,self._clock() else self.Target=v end end
Spring.__index=function(s,k)
    if Spring[k] then return Spring[k] end
    if k=="Value" or k=="Position" or k=="p" then local p=posVel(s,s._clock()) return p
    elseif k=="Velocity" or k=="v" then local _,v=posVel(s,s._clock()) return v
    elseif k=="Target" or k=="t" then return s._target
    elseif k=="Damper" or k=="d" then return s._damper
    elseif k=="Speed" or k=="s" then return s._speed end
end
Spring.__newindex=function(s,k,v)
    local now=s._clock()
    if k=="Value" or k=="Position" or k=="p" then local _,vel=posVel(s,now) s._p0,s._v0=v,vel
    elseif k=="Velocity" or k=="v" then local pos=posVel(s,now) s._p0,s._v0=pos,v
    elseif k=="Target" or k=="t" then local pos,vel=posVel(s,now) s._p0,s._v0,s._target=pos,vel,v
    elseif k=="Damper" or k=="d" then local pos,vel=posVel(s,now) s._p0,s._v0,s._damper=pos,vel,v
    elseif k=="Speed" or k=="s" then local pos,vel=posVel(s,now) s._p0,s._v0,s._speed=pos,vel,v<0 and 0 or v
    else rawset(s,k,v) return end
    s._t0=now
end

-- ══════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════
local Camera = workspace.CurrentCamera
local function getChar() return lplr.Character end
local function getHRP() local c=getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c=getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function notify(title,msg) pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title=title,Text=msg,Duration=3}) end) end

-- viewport helpers
local function viewportSize() return Camera and Camera.ViewportSize or Vector2.new(1920,1080) end
local function worldToScreen(pos) if not Camera then return Vector2.zero,false,0 end local v,s=Camera:WorldToViewportPoint(pos) return Vector2.new(v.X,v.Y),s,v.Z end

-- ══════════════════════════════════════════════
--  FOV CIRCLE (Drawing)
-- ══════════════════════════════════════════════
local FovCircle
pcall(function()
    FovCircle = Drawing.new("Circle")
    FovCircle.Visible=false; FovCircle.Filled=false
    FovCircle.NumSides=64; FovCircle.Color=Color3.fromRGB(255,255,255)
    FovCircle.Thickness=1; FovCircle.Transparency=1
end)

local function updateFovCircle()
    if not FovCircle then return end
    local enabled = cfg.Aimbot.Enabled and cfg.Aimbot.Fov.Enabled
    FovCircle.Visible = enabled
    if enabled then
        local vp = viewportSize()
        FovCircle.Position = Vector2.new(vp.X/2, vp.Y/2)
        FovCircle.Radius   = cfg.Aimbot.Fov.Radius
    end
end

-- ══════════════════════════════════════════════
--  ESP DRAWING
-- ══════════════════════════════════════════════
local espObjects = {}
local MELEE_FAKE = Vector3.new(9000,9000,9000)

local function mkLine(color) local d=Drawing.new("Line") d.Visible=false d.Color=color or Color3.new(1,1,1) d.Thickness=1 d.Transparency=1 return d end
local function mkText(color) local d=Drawing.new("Text") d.Visible=false d.Color=color or Color3.new(1,1,1) d.Size=14 d.Center=true d.Outline=true d.Font=Drawing.Fonts.UI return d end
local function mkSquare(color) local d=Drawing.new("Square") d.Visible=false d.Filled=false d.Color=color or Color3.new(1,1,1) d.Thickness=1 return d end
local function mkCircle(color) local d=Drawing.new("Circle") d.Visible=false d.Filled=false d.Color=color or Color3.new(1,1,1) d.NumSides=16 return d end

local function createEspFor(player)
    if espObjects[player] then return end
    local o={}
    o.box        = mkSquare(Color3.new(1,1,1))
    o.boxFill    = mkSquare(Color3.new(1,1,1)); o.boxFill.Filled=true; o.boxFill.Transparency=0.7
    o.name       = mkText(Color3.new(1,1,1))
    o.distance   = mkText(Color3.fromRGB(200,200,200)); o.distance.Size=11
    o.hpBar      = mkSquare(Color3.new(0,0,0)); o.hpBar.Filled=true
    o.hpFill     = mkSquare(Color3.new(0,1,0)); o.hpFill.Filled=true
    o.ammoBar    = mkSquare(Color3.new(0,0,0)); o.ammoBar.Filled=true
    o.ammoFill   = mkSquare(Color3.fromRGB(0,200,255)); o.ammoFill.Filled=true
    o.weapon     = mkText(Color3.new(1,1,1)); o.weapon.Size=11
    o.rank       = mkText(Color3.new(1,1,1)); o.rank.Size=11
    o.winstreak  = mkText(Color3.new(1,1,1)); o.winstreak.Size=11
    o.headMarker = mkCircle(Color3.fromRGB(255,80,80)); o.headMarker.Filled=true
    o.tracer     = mkLine(Color3.new(1,1,1))
    o.skeleton   = {}
    local bonePairs={{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
    for _,pair in ipairs(bonePairs) do
        local l=mkLine(Color3.new(1,1,1)); l._pair=pair; table.insert(o.skeleton,l)
    end
    espObjects[player]=o
end

local function removeEspFor(player)
    local o=espObjects[player]; if not o then return end
    local function rm(d) if d and typeof(d)=="userdata" then pcall(function() d:Remove() end) end end
    for _,v in pairs(o) do
        if typeof(v)=="userdata" then rm(v)
        elseif type(v)=="table" then for _,l in ipairs(v) do rm(l) end end
    end
    espObjects[player]=nil
end

local function hideEsp(o)
    local function h(d) if d and typeof(d)=="userdata" then pcall(function() d.Visible=false end) end end
    for _,v in pairs(o) do
        if typeof(v)=="userdata" then h(v)
        elseif type(v)=="table" then for _,l in ipairs(v) do h(l) end end
    end
end

local function hpColor(r)
    if r>0.5 then return Color3.fromRGB(math.floor((1-r)*2*255),220,60) end
    return Color3.fromRGB(220,math.floor(r*2*220),60)
end

local function updateEsp()
    local espCfg=cfg.Esp
    if not espCfg.Main.Enabled then
        for _,o in pairs(espObjects) do hideEsp(o) end
        return
    end
    local vp=viewportSize()
    for _,player in ipairs(Players:GetPlayers()) do
        if player==lplr then continue end
        local o=espObjects[player]; if not o then continue end
        local char=player.Character; if not char then hideEsp(o) continue end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health<=0 then hideEsp(o) continue end
        local eC=espCfg.Enemy
        if not eC.Enabled then hideEsp(o) continue end
        local topSP,topOS=worldToScreen(hrp.Position+Vector3.new(0,3.1,0))
        local botSP,botOS=worldToScreen(hrp.Position+Vector3.new(0,-3.1,0))
        if not topOS and not botOS then hideEsp(o) continue end
        local boxH=math.abs(topSP.Y-botSP.Y); local boxW=boxH*0.55
        local boxX=topSP.X-boxW/2; local boxY=topSP.Y
        local dist=(Camera.CFrame.Position-hrp.Position).Magnitude
        local hp=hum.Health; local maxHp=math.max(hum.MaxHealth,1)
        local hpR=math.clamp(hp/maxHp,0,1)
        -- box
        o.box.Visible=eC.Box.Enabled; o.box.Color=eC.Box.Color; o.box.Position=Vector2.new(boxX,boxY); o.box.Size=Vector2.new(boxW,boxH)
        o.boxFill.Visible=eC.FilledBox.Enabled; o.boxFill.Color=eC.FilledBox.Color:Keypoints()[1].Value; o.boxFill.Position=Vector2.new(boxX,boxY); o.boxFill.Size=Vector2.new(boxW,boxH); o.boxFill.Transparency=eC.FilledBox.Transparency
        -- name
        local dname = espCfg.Settings.UseDisplayName and player.DisplayName or player.Name
        o.name.Visible=eC.Name.Enabled; o.name.Color=eC.Name.Color; o.name.Text=dname; o.name.Size=espCfg.Settings.FontSize; o.name.Position=Vector2.new(topSP.X,boxY-espCfg.Settings.FontSize-2)
        -- distance
        o.distance.Visible=eC.Distance.Enabled; o.distance.Color=eC.Distance.Color; o.distance.Text=string.format("[%d]",math.floor(dist)); o.distance.Position=Vector2.new(topSP.X,botSP.Y+2)
        -- hp bar
        local hbX=boxX-6; local hbH=boxH*hpR
        o.hpBar.Visible=eC.HealthBar.Enabled; o.hpBar.Position=Vector2.new(hbX,boxY); o.hpBar.Size=Vector2.new(4,boxH)
        o.hpFill.Visible=eC.HealthBar.Enabled; o.hpFill.Color=hpColor(hpR); o.hpFill.Position=Vector2.new(hbX,botSP.Y-hbH); o.hpFill.Size=Vector2.new(4,hbH)
        -- tracer
        local tracerFrom=eC.Tracer.Origin=="Center" and Vector2.new(vp.X/2,vp.Y/2) or Vector2.new(vp.X/2,vp.Y)
        o.tracer.Visible=eC.Tracer.Enabled; o.tracer.Color=eC.Tracer.Color:Keypoints()[1].Value; o.tracer.Thickness=eC.Tracer.Thickness; o.tracer.From=tracerFrom; o.tracer.To=Vector2.new(topSP.X,botSP.Y)
        -- head marker
        local head=char:FindFirstChild("Head")
        if head then
            local hsp,hos=worldToScreen(head.Position)
            o.headMarker.Visible=eC.HeadMarker.Enabled and hos; o.headMarker.Color=eC.HeadMarker.Color; o.headMarker.Position=hsp; o.headMarker.Radius=4
        end
        -- skeleton
        for _,line in ipairs(o.skeleton) do
            local pair=line._pair
            local pA=char:FindFirstChild(pair[1]); local pB=char:FindFirstChild(pair[2])
            if eC.Skeleton.Enabled and pA and pB then
                local spA,osA=worldToScreen(pA.Position); local spB,osB=worldToScreen(pB.Position)
                line.Visible=osA and osB; line.Color=eC.Skeleton.Color:Keypoints()[1].Value; line.Thickness=eC.Skeleton.Thickness; line.From=spA; line.To=spB
            else line.Visible=false end
        end
        -- chams
        if eC.Chams.Kind=="Highlight" then
            local hl=char:FindFirstChild("AW_Chams")
            if eC.Chams.Enabled then
                if not hl then hl=Instance.new("Highlight") hl.Name="AW_Chams" hl.Parent=char end
                hl.FillColor=eC.Chams.InnerColor; hl.FillTransparency=eC.Chams.InnerTransparency
                hl.OutlineColor=eC.Chams.OutlineColor; hl.OutlineTransparency=eC.Chams.OutlineTransparency
            else if hl then hl:Destroy() end end
        end
    end
end

-- ══════════════════════════════════════════════
--  CUSTOM CROSSHAIR
-- ══════════════════════════════════════════════
local xhLines={}
pcall(function()
    for _,name in ipairs({"top","bottom","left","right"}) do
        xhLines[name]=Drawing.new("Line"); xhLines[name].Visible=false; xhLines[name].Color=Color3.new(1,1,1); xhLines[name].Thickness=2; xhLines[name].Transparency=1
    end
    xhLines.dot=Drawing.new("Circle"); xhLines.dot.Visible=false; xhLines.dot.Filled=true; xhLines.dot.Color=Color3.new(1,1,1)
end)

local function updateCrosshair()
    if not xhLines.top then return end
    local cc=cfg.CustomCrosshair
    if not cc.Enabled then for _,d in pairs(xhLines) do pcall(function() d.Visible=false end) end return end
    local vp=viewportSize(); local cx=vp.X/2; local cy=vp.Y/2
    local len=cc.Length; local gap=cc.Gap; local thick=cc.Thickness
    local col=Color3.new(1,1,1)
    local function set(d,f,t) pcall(function() d.Visible=true d.Color=col d.Thickness=thick d.From=f d.To=t end) end
    if cc.Top.Enabled    then set(xhLines.top,   Vector2.new(cx,cy-gap-len), Vector2.new(cx,cy-gap)) end
    if cc.Bottom.Enabled then set(xhLines.bottom,Vector2.new(cx,cy+gap),     Vector2.new(cx,cy+gap+len)) end
    if cc.Left.Enabled   then set(xhLines.left,  Vector2.new(cx-gap-len,cy), Vector2.new(cx-gap,cy)) end
    if cc.Right.Enabled  then set(xhLines.right, Vector2.new(cx+gap,cy),     Vector2.new(cx+gap+len,cy)) end
    xhLines.dot.Visible=cc.Style=="Dot"; xhLines.dot.Position=Vector2.new(cx,cy); xhLines.dot.Radius=thick+1
end

-- ══════════════════════════════════════════════
--  AIMBOT / SILENT AIM
-- ══════════════════════════════════════════════
local aimbotSpring=Spring.new(Vector3.zero)
aimbotSpring.Speed=20; aimbotSpring.Damper=1

local function getAimTarget()
    local vp=viewportSize(); local center=Vector2.new(vp.X/2,vp.Y/2)
    local best,bestVal=nil,math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p==lplr then continue end
        if cfg.Aimbot.TeamCheck and p.Team and lplr.Team and p.Team==lplr.Team then continue end
        local char=p.Character; if not char then continue end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health<=0 then continue end
        local sp,os=worldToScreen(hrp.Position); if not os then continue end
        local d=(sp-center).Magnitude
        if cfg.Aimbot.Fov.Enabled and d>cfg.Aimbot.Fov.Radius then continue end
        if d<bestVal then bestVal=d best=p end
    end
    return best
end

local function doSilentAim(target)
    if not target or not target.Character then return end
    if not ok_fc or not FC or not FC.LocalFighter then return end
    local item=FC.LocalFighter.EquippedItem; if not item then return end
    local hrp=target.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if not ok_util or not ok_enum then return end
    pcall(function()
        local cam=workspace.CurrentCamera.CFrame
        local lk=CFrame.lookAt(cam.Position,hrp.Position):ToOrientation()
        local cd={}
        cd[utf8.char(1)]={
            [utf8.char(0)]=Util:EncodeCFrame(CFrame.new(cam.Position)*CFrame.Angles(lk)),
            [utf8.char(1)]=Util:EncodeCFrame(CFrame.new(hrp.Position)*CFrame.Angles(lk)),
            [utf8.char(2)]=hrp,
            [utf8.char(3)]=Util:EncodeCFrame(hrp.CFrame:ToObjectSpace(CFrame.new(hrp.Position))),
        }
        Remotes.Replication.Fighter.UseItem:FireServer(item:Get("ObjectID"),EnumLib:ToEnum("StartShooting"),cd,nil)
    end)
end

local function doAimbot(dt)
    if not cfg.Aimbot.Enabled then return end
    local target=getAimTarget(); if not target then return end
    local hrp=target.Character and target.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    -- spring-based smooth aim
    local smooth=math.clamp(1-(cfg.Ragebot.Stability or 0.15),0.01,1)
    aimbotSpring.Speed=smooth*30; aimbotSpring.Target=hrp.Position
    local aimed=aimbotSpring.Position
    if Camera then
        local newCF=CFrame.lookAt(Camera.CFrame.Position, aimed)
        Camera.CFrame=Camera.CFrame:Lerp(newCF,smooth)
    end
end

-- ══════════════════════════════════════════════
--  MOVEMENT
-- ══════════════════════════════════════════════
local flyBody,flyGyro

local function startFly()
    local hrp=getHRP(); if not hrp then return end
    if flyBody then return end
    flyBody=Instance.new("BodyVelocity"); flyBody.MaxForce=Vector3.new(math.huge,math.huge,math.huge); flyBody.Velocity=Vector3.zero; flyBody.Parent=hrp
    flyGyro=Instance.new("BodyGyro"); flyGyro.MaxTorque=Vector3.new(math.huge,math.huge,math.huge); flyGyro.D=100; flyGyro.Parent=hrp
end
local function stopFly()
    if flyBody then flyBody:Destroy(); flyBody=nil end
    if flyGyro then flyGyro:Destroy(); flyGyro=nil end
end

local noclipConn
local function startNoclip()
    if noclipConn then return end
    noclipConn=RunService.Stepped:Connect(function()
        if not cfg.Movement.Noclip.Enabled then return end
        local char=getChar(); if not char then return end
        for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
    end)
end
local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
    local char=getChar()
    if char then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=true end) end end end
end

local origWalkSpeed,origJumpPower=16,50
local function applyWalkSpeed(v)
    local hum=getHum(); if hum then hum.WalkSpeed=v end
end
local function applyJumpPower(v)
    local hum=getHum(); if hum then hum.JumpPower=v end
end

local infJumpConn
local function startInfJump()
    if infJumpConn then return end
    infJumpConn=UserInputService.JumpRequest:Connect(function()
        local hum=getHum(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
local function stopInfJump()
    if infJumpConn then infJumpConn:Disconnect(); infJumpConn=nil end
end

-- ══════════════════════════════════════════════
--  REMOVABLES
-- ══════════════════════════════════════════════
local function applyRemovables()
    local R=cfg.Removables
    local char=getChar(); if not char then return end
    -- NoFlashbang: suppress FlashEffect GUI
    if R.NoFlashbang then
        local pg=lplr:FindFirstChild("PlayerGui")
        if pg then
            for _,gui in ipairs(pg:GetDescendants()) do
                if gui.Name:find("Flash") and gui:IsA("LayerCollector") then
                    pcall(function() gui.Enabled=false end)
                end
            end
        end
    end
    -- NoHitmarker
    if R.NoHitmarker then
        local pg=lplr:FindFirstChild("PlayerGui")
        if pg then
            for _,gui in ipairs(pg:GetDescendants()) do
                if gui.Name:find("Hitmarker") and gui:IsA("LayerCollector") then
                    pcall(function() gui.Enabled=false end)
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════
--  THIRD PERSON
-- ══════════════════════════════════════════════
local function applyThirdPerson()
    if not cfg.ThirdPerson.Enabled then
        Camera.CameraType=Enum.CameraType.Custom
        return
    end
    local hrp=getHRP(); if not hrp then return end
    local tp=cfg.ThirdPerson
    Camera.CameraType=Enum.CameraType.Scriptable
    local offset=CFrame.new(tp.X,tp.Y,tp.Z)
    Camera.CFrame=hrp.CFrame*offset
end

-- ══════════════════════════════════════════════
--  CAMERA FOV
-- ══════════════════════════════════════════════
local function applyCameraFov()
    if cfg.CameraFov.Enabled then
        Camera.FieldOfView=cfg.CameraFov.Value
    end
end

-- ══════════════════════════════════════════════
--  ITEM MODIFIERS
-- ══════════════════════════════════════════════
local function applyItemModifiers()
    local IM=cfg.ItemModifiers
    if not ok_fc or not FC or not FC.LocalFighter then return end
    local item=FC.LocalFighter.EquippedItem; if not item then return end
    pcall(function()
        if IM.NoSpread then item:SetAttribute("Spread",0) end
        if IM.FullAuto then item:SetAttribute("FullAuto",true) end
        if IM.AlwaysBackstab then item:SetAttribute("AlwaysBackstab",true) end
        if IM.FastShoot then item:SetAttribute("ShootDelay",0) end
        if IM.InfiniteDoubleJumps then
            local hum=getHum()
            if hum then hum:SetAttribute("JumpsLeft",999) end
        end
        if IM.FireRate.Enabled then
            local base=item:GetAttribute("FireRate") or 1
            item:SetAttribute("FireRate",base*(IM.FireRate.Percentage/100))
        end
        if IM.Recoil.Enabled then
            local base=item:GetAttribute("RecoilMultiplier") or 1
            item:SetAttribute("RecoilMultiplier",base*(IM.Recoil.Percentage/100))
        end
        if IM.AimCooldown.Enabled then
            local base=item:GetAttribute("AimCooldown") or 1
            item:SetAttribute("AimCooldown",base*(IM.AimCooldown.Percentage/100))
        end
        if IM.FireCooldown.Enabled then
            local base=item:GetAttribute("FireCooldown") or 1
            item:SetAttribute("FireCooldown",base*(IM.FireCooldown.Percentage/100))
        end
        if IM.MeleeCooldown.Enabled then
            local base=item:GetAttribute("MeleeCooldown") or 1
            item:SetAttribute("MeleeCooldown",base*(IM.MeleeCooldown.Percentage/100))
        end
        if IM.DashCooldown.Enabled then
            local base=item:GetAttribute("DashCooldown") or 1
            item:SetAttribute("DashCooldown",base*(IM.DashCooldown.Percentage/100))
        end
        if IM.AimSpeed.Enabled then
            local base=item:GetAttribute("AimSpeed") or 1
            item:SetAttribute("AimSpeed",base*(IM.AimSpeed.Percentage/100))
        end
        if IM.ExtendMeleeRange.Enabled then
            local base=item:GetAttribute("Range") or 5
            item:SetAttribute("Range",base+IM.ExtendMeleeRange.Range)
        end
    end)
end

-- ══════════════════════════════════════════════
--  AUTO FEATURES
-- ══════════════════════════════════════════════
local function setupAutoPickup()
    if not cfg.AutoPickupDrops.Enabled then return end
    RunService.Heartbeat:Connect(function()
        if not cfg.AutoPickupDrops.Enabled then return end
        local hrp=getHRP(); if not hrp then return end
        for _,obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name=="Drop" then
                local d=(hrp.Position-obj.Position).Magnitude
                if d<10 then pcall(firetouchinterest,hrp,obj,0) end
            end
        end
    end)
end

local function setupAutoRespawn()
    lplr.CharacterRemoving:Connect(function()
        if not cfg.AutoRespawn.Enabled then return end
        task.wait(0.1)
        pcall(function()
            Remotes.Duels.RespawnNow:FireServer()
        end)
    end)
end

local function setupAutoQueue()
    RunService.Heartbeat:Connect(function()
        if not cfg.AutoQueue.Enabled then return end
        pcall(function()
            local queueRemote=Remotes:FindFirstChild("Queue",true)
            if queueRemote then queueRemote:FireServer(cfg.AutoQueue.Queue) end
        end)
    end)
end

-- ══════════════════════════════════════════════
--  HACKER / MOD DETECTOR
-- ══════════════════════════════════════════════
local detectedHackers={}
local function checkHackerDetector()
    if not cfg.HackerDetector.Enabled then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p==lplr or detectedHackers[p] then continue end
        local char=p.Character; if not char then continue end
        local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
        local speed=hrp.AssemblyLinearVelocity.Magnitude
        if speed>500 then
            detectedHackers[p]=true
            if cfg.HackerDetector.Notify then
                notify("Hacker Detected", p.Name.." | speed: "..math.floor(speed))
            end
        end
    end
end

-- ══════════════════════════════════════════════
--  RENDER LOOP
-- ══════════════════════════════════════════════
GlobalTrove:Add(RunService.RenderStepped:Connect(function(dt)
    updateEsp()
    updateFovCircle()
    updateCrosshair()
    doAimbot(dt)
    applyRemovables()
    applyCameraFov()
    if cfg.ThirdPerson.Enabled then applyThirdPerson() end
    -- fly
    if cfg.Movement.Flight.Enabled then
        startFly()
        if flyBody then
            local spd=cfg.Movement.Flight.Speed
            local dir=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir=dir-Vector3.new(0,1,0) end
            flyBody.Velocity=dir.Magnitude>0 and dir.Unit*spd or Vector3.zero
            if flyGyro then flyGyro.CFrame=Camera.CFrame end
        end
    else
        stopFly()
    end
    -- walkspeed
    if cfg.Movement.WalkSpeed.Enabled then applyWalkSpeed(cfg.Movement.WalkSpeed.Speed*16) end
    if cfg.Movement.JumpPower.Enabled then applyJumpPower(cfg.Movement.JumpPower.Speed*50) end
    -- item mods
    applyItemModifiers()
    -- hacker check (throttled)
    if math.floor(os.clock()*2)%2==0 then checkHackerDetector() end
end))

-- ══════════════════════════════════════════════
--  PLAYER EVENTS
-- ══════════════════════════════════════════════
for _,p in ipairs(Players:GetPlayers()) do
    if p~=lplr then createEspFor(p) end
end
GlobalTrove:Add(Players.PlayerAdded:Connect(function(p)
    if p~=lplr then createEspFor(p) end
end))
GlobalTrove:Add(Players.PlayerRemoving:Connect(function(p)
    removeEspFor(p)
    detectedHackers[p]=nil
end))

setupAutoPickup()
setupAutoRespawn()
setupAutoQueue()

-- ══════════════════════════════════════════════
--  UNLOAD
-- ══════════════════════════════════════════════
function AW.Unload()
    if AW.destroyed then return end
    AW.destroyed=true
    GlobalTrove:Destroy()
    stopFly(); stopNoclip(); stopInfJump()
    for _,p in ipairs(Players:GetPlayers()) do removeEspFor(p) end
    if FovCircle then pcall(function() FovCircle:Remove() end) end
    for _,d in pairs(xhLines) do pcall(function() d:Remove() end) end
    if getgenv().AlwaysWinning==AW then getgenv().AlwaysWinning=nil end
    notify("always.winning","Unloaded.")
end

-- ══════════════════════════════════════════════
--  OBSIDIAN UI
-- ══════════════════════════════════════════════
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library    = loadstring(game:HttpGet(repo.."Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo.."addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo.."addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title   = "always.winning",
    Center  = true,
    AutoShow= true,
})

local Tabs = {
    Combat   = Window:AddTab("Combat"),
    Visuals  = Window:AddTab("Visuals"),
    Movement = Window:AddTab("Movement"),
    Misc     = Window:AddTab("Misc"),
    Spoofer  = Window:AddTab("Spoofer"),
    Settings = Window:AddTab("Settings"),
}

local Options = Library.Options

-- ════════════════════════════════════════════
--  COMBAT TAB
-- ════════════════════════════════════════════
local AimbotGroup = Tabs.Combat:AddLeftGroupbox("Aimbot")
AimbotGroup:AddToggle("aim_enabled",{Text="Enable Aimbot",Default=false}):OnChanged(function(v) cfg.Aimbot.Enabled=v end)
AimbotGroup:AddSlider("aim_smooth",{Text="Smoothness",Default=15,Min=1,Max=100,Rounding=0}):OnChanged(function(v) cfg.Ragebot.Stability=v/100 end)
AimbotGroup:AddSlider("aim_fov",{Text="FOV Radius",Default=150,Min=10,Max=600,Rounding=0}):OnChanged(function(v) cfg.Aimbot.Fov.Radius=v end)
AimbotGroup:AddToggle("aim_fov_enabled",{Text="Show FOV Circle",Default=false}):OnChanged(function(v) cfg.Aimbot.Fov.Enabled=v end)
AimbotGroup:AddDropdown("aim_priority",{Text="Target Priority",Default=1,Values={"ClosestToCrosshair","ClosestToMe","LowestHP","HighestHP"}}):OnChanged(function(v) cfg.Aimbot.TargetPriority=v end)
AimbotGroup:AddToggle("aim_teamcheck",{Text="Team Check",Default=true}):OnChanged(function(v) cfg.Aimbot.TeamCheck=v end)
AimbotGroup:AddToggle("aim_vischeck",{Text="Visibility Check",Default=false}):OnChanged(function(v) cfg.Aimbot.VisibilityCheck=v end)
AimbotGroup:AddDivider()
AimbotGroup:AddLabel("Silent Aim / Manipulate")
AimbotGroup:AddToggle("sa_manip_en",{Text="Manipulate",Default=false}):OnChanged(function(v) cfg.SilentAim.Manipulate.Enabled=v end)
AimbotGroup:AddDropdown("sa_mode",{Text="Mode",Default=1,Values={"Constant","OnShoot","Dynamic"}}):OnChanged(function(v) cfg.SilentAim.Manipulate.Mode=v end)
AimbotGroup:AddToggle("sa_indicator",{Text="Show Indicator",Default=false}):OnChanged(function(v) cfg.SilentAim.Manipulate.ShowIndicator=v end)

local TriggerbotGroup = Tabs.Combat:AddLeftGroupbox("Triggerbot")
TriggerbotGroup:AddToggle("tb_enabled",{Text="Enable Triggerbot",Default=false}):OnChanged(function(v) cfg.SilentAim.Triggerbot.Enabled=v end)
TriggerbotGroup:AddSlider("tb_holdms",{Text="Hold Duration (ms)",Default=0,Min=0,Max=500,Rounding=0}):OnChanged(function(v) cfg.SilentAim.Triggerbot.HoldDuration=v end)
TriggerbotGroup:AddSlider("tb_delay",{Text="Delay (ms)",Default=0,Min=0,Max=500,Rounding=0}):OnChanged(function(v) cfg.SilentAim.Triggerbot.Delay=v end)
TriggerbotGroup:AddDropdown("tb_part",{Text="Target Part",Default=1,Values={"HumanoidRootPart","Head","Torso"}}):OnChanged(function(v) cfg.SilentAim.Triggerbot.TargetPart=v end)
TriggerbotGroup:AddToggle("tb_vischeck",{Text="Visibility Check",Default=false}):OnChanged(function(v) cfg.SilentAim.Triggerbot.VisibilityCheck=v end)
TriggerbotGroup:AddToggle("tb_teamcheck",{Text="Team Check",Default=true}):OnChanged(function(v) cfg.SilentAim.Triggerbot.TeamCheck=v end)

local RagebotGroup = Tabs.Combat:AddRightGroupbox("Ragebot")
RagebotGroup:AddToggle("rb_enabled",{Text="Enable Ragebot",Default=false}):OnChanged(function(v) cfg.Ragebot.Enabled=v end)
RagebotGroup:AddSlider("rb_stability",{Text="Stability",Default=15,Min=0,Max=100,Rounding=0}):OnChanged(function(v) cfg.Ragebot.Stability=v/100 end)
RagebotGroup:AddSlider("rb_shootframes",{Text="Shoot Frames",Default=1,Min=1,Max=10,Rounding=0}):OnChanged(function(v) cfg.Ragebot.ShootFrames=v end)
RagebotGroup:AddToggle("rb_priorhackers",{Text="Prioritize Hackers",Default=false}):OnChanged(function(v) cfg.Ragebot.PrioritizeHackers=v end)
RagebotGroup:AddToggle("rb_healthlead",{Text="Utilize Health Lead",Default=false}):OnChanged(function(v) cfg.Ragebot.UtilizeHealthLead=v end)
RagebotGroup:AddDivider()
RagebotGroup:AddLabel("Weapons")
RagebotGroup:AddToggle("rb_primary",{Text="Primary",Default=true}):OnChanged(function(v) cfg.Ragebot.Weapons.Enabled.Primary=v end)
RagebotGroup:AddToggle("rb_secondary",{Text="Secondary",Default=true}):OnChanged(function(v) cfg.Ragebot.Weapons.Enabled.Secondary=v end)
RagebotGroup:AddToggle("rb_melee",{Text="Melee",Default=true}):OnChanged(function(v) cfg.Ragebot.Weapons.Enabled.Melee=v end)
RagebotGroup:AddDropdown("rb_onempty",{Text="On Empty",Default=1,Values={"SwapOrReload","Reload","Swap"}}):OnChanged(function(v) cfg.Ragebot.Weapons.OnEmpty=v end)
RagebotGroup:AddDivider()
RagebotGroup:AddLabel("Evasion")
RagebotGroup:AddDropdown("rb_evasion",{Text="Evasion Mode",Default=1,Values={"Random","ProjectileBreaker","Translocate","None"}}):OnChanged(function(v) cfg.Ragebot.Evasion.Mode=v end)
RagebotGroup:AddSlider("rb_baseradius",{Text="Base Radius",Default=100,Min=0,Max=1000,Rounding=0}):OnChanged(function(v) cfg.Ragebot.Evasion.Random.BaseRadius=v end)
RagebotGroup:AddSlider("rb_radiusfactor",{Text="Radius Random Factor",Default=50,Min=0,Max=100,Rounding=0}):OnChanged(function(v) cfg.Ragebot.Evasion.Random.RadiusRandomFactor=v/100 end)

local FlickbotGroup = Tabs.Combat:AddRightGroupbox("Flickbot")
FlickbotGroup:AddToggle("fb_enabled",{Text="Enable Flickbot",Default=false}):OnChanged(function(v) cfg.Flickbot.Enabled=v end)
FlickbotGroup:AddToggle("fb_shoot",{Text="Shoot on Flick",Default=false}):OnChanged(function(v) cfg.Flickbot.Shoot=v end)
FlickbotGroup:AddSlider("fb_shotdelay",{Text="Shot Delay (ms)",Default=0,Min=0,Max=500,Rounding=0}):OnChanged(function(v) cfg.Flickbot.ShotDelay=v end)
FlickbotGroup:AddSlider("fb_cooldown",{Text="Cooldown (ms)",Default=250,Min=0,Max=2000,Rounding=0}):OnChanged(function(v) cfg.Flickbot.Cooldown=v end)
FlickbotGroup:AddSlider("fb_duration",{Text="Flick Duration (ms)",Default=110,Min=10,Max=500,Rounding=0}):OnChanged(function(v) cfg.Flickbot.FlickDuration=v end)
FlickbotGroup:AddSlider("fb_curvature",{Text="Curvature",Default=12,Min=0,Max=100,Rounding=0}):OnChanged(function(v) cfg.Flickbot.Curvature=v end)
FlickbotGroup:AddSlider("fb_humanness",{Text="Humanness",Default=30,Min=0,Max=100,Rounding=0}):OnChanged(function(v) cfg.Flickbot.Humanness=v end)

-- ════════════════════════════════════════════
--  VISUALS TAB
-- ════════════════════════════════════════════
local EspGroup = Tabs.Visuals:AddLeftGroupbox("ESP")
EspGroup:AddToggle("esp_main",{Text="Enable ESP",Default=false}):OnChanged(function(v) cfg.Esp.Main.Enabled=v end)
EspGroup:AddDropdown("esp_mode",{Text="Box Mode",Default=1,Values={"Static","Dynamic"}}):OnChanged(function(v) cfg.Esp.Main.Mode=v end)
EspGroup:AddDivider()
EspGroup:AddLabel("Enemy")
EspGroup:AddToggle("esp_enemy",{Text="Enable Enemy ESP",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Enabled=v end)
EspGroup:AddToggle("esp_name",{Text="Name",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Name.Enabled=v end)
EspGroup:AddToggle("esp_box",{Text="Box",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Box.Enabled=v end)
EspGroup:AddDropdown("esp_boxstyle",{Text="Box Style",Default=1,Values={"Full","Corner"}}):OnChanged(function(v) cfg.Esp.Enemy.Box.Style=v end)
EspGroup:AddToggle("esp_fillbox",{Text="Filled Box",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.FilledBox.Enabled=v end)
EspGroup:AddToggle("esp_healthbar",{Text="Health Bar",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.HealthBar.Enabled=v end)
EspGroup:AddDropdown("esp_hbmode",{Text="HP Bar Color Mode",Default=3,Values={"Solid","Gradient","Reactive"}}):OnChanged(function(v) cfg.Esp.Enemy.HealthBar.ColorMode=v end)
EspGroup:AddToggle("esp_healthnum",{Text="Health Number",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.HealthNumber.Enabled=v end)
EspGroup:AddToggle("esp_weapon",{Text="Held Weapon",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.HeldWeapon.Enabled=v end)
EspGroup:AddToggle("esp_ammobar",{Text="Ammo Bar",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.AmmoBar.Enabled=v end)
EspGroup:AddToggle("esp_distance",{Text="Distance",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Distance.Enabled=v end)
EspGroup:AddToggle("esp_rank",{Text="Rank",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Rank.Enabled=v end)
EspGroup:AddToggle("esp_winstreak",{Text="Win Streak",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Winstreak.Enabled=v end)
EspGroup:AddToggle("esp_deflecting",{Text="Deflecting",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Deflecting.Enabled=v end)
EspGroup:AddToggle("esp_tracer",{Text="Tracer",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Tracer.Enabled=v end)
EspGroup:AddDropdown("esp_tracerorig",{Text="Tracer From",Default=1,Values={"Bottom","Center","Top","Mouse"}}):OnChanged(function(v) cfg.Esp.Enemy.Tracer.Origin=v end)
EspGroup:AddSlider("esp_tracerthick",{Text="Tracer Thickness",Default=1,Min=1,Max=6,Rounding=0}):OnChanged(function(v) cfg.Esp.Enemy.Tracer.Thickness=v end)

local ChamsGroup = Tabs.Visuals:AddLeftGroupbox("Chams / Skeleton")
ChamsGroup:AddToggle("esp_skeleton",{Text="Skeleton",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Skeleton.Enabled=v end)
ChamsGroup:AddSlider("esp_skelthick",{Text="Skeleton Thickness",Default=1,Min=1,Max=6,Rounding=0}):OnChanged(function(v) cfg.Esp.Enemy.Skeleton.Thickness=v end)
ChamsGroup:AddToggle("esp_headmarker",{Text="Head Marker",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.HeadMarker.Enabled=v end)
ChamsGroup:AddDropdown("esp_hmarkshape",{Text="Head Marker Shape",Default=1,Values={"Cross","Circle","Diamond"}}):OnChanged(function(v) cfg.Esp.Enemy.HeadMarker.Shape=v end)
ChamsGroup:AddDivider()
ChamsGroup:AddToggle("chams_enemy",{Text="Enemy Chams",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Chams.Enabled=v end)
ChamsGroup:AddDropdown("chams_kind",{Text="Chams Kind",Default=2,Values={"Legacy","Highlight"}}):OnChanged(function(v) cfg.Esp.Enemy.Chams.Kind=v end)
ChamsGroup:AddToggle("chams_glow",{Text="Glow",Default=false}):OnChanged(function(v) cfg.Esp.Enemy.Chams.Glow=v end)
ChamsGroup:AddDivider()
ChamsGroup:AddToggle("chams_self",{Text="Self Chams (Character)",Default=false}):OnChanged(function(v) cfg.Chams.Character.Enabled=v end)
ChamsGroup:AddToggle("chams_arms",{Text="Self Chams (Arms)",Default=false}):OnChanged(function(v) cfg.Chams.Arms.Enabled=v end)
ChamsGroup:AddToggle("chams_item",{Text="Self Chams (Item)",Default=false}):OnChanged(function(v) cfg.Chams.Item.Enabled=v end)
ChamsGroup:AddDivider()
ChamsGroup:AddToggle("vmhl_arms",{Text="ViewModel Highlight Arms",Default=false}):OnChanged(function(v) cfg.ViewModelHighlight.Arms.Enabled=v end)
ChamsGroup:AddToggle("vmhl_item",{Text="ViewModel Highlight Item",Default=false}):OnChanged(function(v) cfg.ViewModelHighlight.Item.Enabled=v end)
ChamsGroup:AddToggle("vmwf_arms",{Text="ViewModel Wireframe Arms",Default=false}):OnChanged(function(v) cfg.ViewModelWireframe.Arms.Enabled=v end)
ChamsGroup:AddToggle("vmwf_item",{Text="ViewModel Wireframe Item",Default=false}):OnChanged(function(v) cfg.ViewModelWireframe.Item.Enabled=v end)

local EspSettingsGroup = Tabs.Visuals:AddRightGroupbox("ESP Settings")
EspSettingsGroup:AddToggle("esp_displayname",{Text="Use Display Names",Default=false}):OnChanged(function(v) cfg.Esp.Settings.UseDisplayName=v end)
EspSettingsGroup:AddDropdown("esp_font",{Text="Font",Default=1,Values={"Inconsolata","GothamBold","Gotham","Arial","Code"}}):OnChanged(function(v) cfg.Esp.Settings.Font=v end)
EspSettingsGroup:AddSlider("esp_fontsize",{Text="Font Size",Default=16,Min=8,Max=32,Rounding=0}):OnChanged(function(v) cfg.Esp.Settings.FontSize=v end)
EspSettingsGroup:AddDropdown("esp_textcase",{Text="Text Case",Default=1,Values={"Standard","UPPERCASE","lowercase"}}):OnChanged(function(v) cfg.Esp.Settings.TextCase=v end)
EspSettingsGroup:AddDropdown("esp_surround",{Text="Text Surround",Default=1,Values={"None","[]","()","<>","{}"}}):OnChanged(function(v) cfg.Esp.Settings.TextSurround=v end)
EspSettingsGroup:AddToggle("esp_distscale",{Text="Scale With Distance",Default=false}):OnChanged(function(v) cfg.Esp.Settings.DistanceScaling=v end)
EspSettingsGroup:AddSlider("esp_distscaleref",{Text="Reference Distance",Default=50,Min=10,Max=300,Rounding=0}):OnChanged(function(v) cfg.Esp.Settings.DistanceScalingRef=v end)
EspSettingsGroup:AddDivider()
EspSettingsGroup:AddLabel("Rank Spoof")
EspSettingsGroup:AddToggle("rankspoof",{Text="Spoof Rank",Default=false}):OnChanged(function(v) cfg.Esp.RankSpoof.Enabled=v end)

local CrosshairGroup = Tabs.Visuals:AddRightGroupbox("Custom Crosshair")
CrosshairGroup:AddToggle("ch_enabled",{Text="Enable Custom Crosshair",Default=false}):OnChanged(function(v) cfg.CustomCrosshair.Enabled=v end)
CrosshairGroup:AddDropdown("ch_style",{Text="Style",Default=1,Values={"Lines","Dot","Cross","Image"}}):OnChanged(function(v) cfg.CustomCrosshair.Style=v end)
CrosshairGroup:AddSlider("ch_len",{Text="Length",Default=12,Min=1,Max=50,Rounding=0}):OnChanged(function(v) cfg.CustomCrosshair.Length=v end)
CrosshairGroup:AddSlider("ch_thick",{Text="Thickness",Default=2,Min=1,Max=10,Rounding=0}):OnChanged(function(v) cfg.CustomCrosshair.Thickness=v end)
CrosshairGroup:AddSlider("ch_gap",{Text="Gap",Default=6,Min=0,Max=30,Rounding=0}):OnChanged(function(v) cfg.CustomCrosshair.Gap=v end)
CrosshairGroup:AddToggle("ch_top",{Text="Top Line",Default=true}):OnChanged(function(v) cfg.CustomCrosshair.Top.Enabled=v end)
CrosshairGroup:AddToggle("ch_bottom",{Text="Bottom Line",Default=true}):OnChanged(function(v) cfg.CustomCrosshair.Bottom.Enabled=v end)
CrosshairGroup:AddToggle("ch_left",{Text="Left Line",Default=true}):OnChanged(function(v) cfg.CustomCrosshair.Left.Enabled=v end)
CrosshairGroup:AddToggle("ch_right",{Text="Right Line",Default=true}):OnChanged(function(v) cfg.CustomCrosshair.Right.Enabled=v end)
CrosshairGroup:AddToggle("ch_outline",{Text="Outline",Default=false}):OnChanged(function(v) cfg.CustomCrosshair.Outline.Enabled=v end)
CrosshairGroup:AddSlider("ch_outline_thick",{Text="Outline Thickness",Default=1,Min=1,Max=5,Rounding=0}):OnChanged(function(v) cfg.CustomCrosshair.Outline.Thickness=v end)
CrosshairGroup:AddToggle("ch_rotation",{Text="Rotation",Default=false}):OnChanged(function(v) cfg.CustomCrosshair.Rotation.Enabled=v end)
CrosshairGroup:AddSlider("ch_rotspeed",{Text="Rotation Speed",Default=90,Min=1,Max=720,Rounding=0}):OnChanged(function(v) cfg.CustomCrosshair.Rotation.Speed=v end)
CrosshairGroup:AddToggle("ch_spread",{Text="Spread",Default=false}):OnChanged(function(v) cfg.CustomCrosshair.Spread.Enabled=v end)
CrosshairGroup:AddToggle("ch_followtarget",{Text="Follow Target",Default=false}):OnChanged(function(v) cfg.CustomCrosshair.FollowTarget.Enabled=v end)
CrosshairGroup:AddDropdown("ch_followmode",{Text="Follow Mode",Default=1,Values={"Crosshair","Screen"}}):OnChanged(function(v) cfg.CustomCrosshair.FollowTarget.Mode=v end)
CrosshairGroup:AddSlider("ch_followspeed",{Text="Follow Speed",Default=20,Min=1,Max=100,Rounding=0}):OnChanged(function(v) cfg.CustomCrosshair.FollowTarget.Speed=v end)

local EffectsGroup = Tabs.Visuals:AddRightGroupbox("Hit / Kill Effects")
EffectsGroup:AddToggle("phit_enabled",{Text="Player Hit Effects",Default=false}):OnChanged(function(v) cfg.PlayerHit.Enabled=v end)
EffectsGroup:AddToggle("phit_snd",{Text="Hit Sound",Default=false}):OnChanged(function(v) cfg.PlayerHit.Sound.Enabled=v end)
EffectsGroup:AddToggle("phit_notif",{Text="Hit Notification",Default=false}):OnChanged(function(v) cfg.PlayerHit.Notification.Enabled=v end)
EffectsGroup:AddToggle("phit_chams",{Text="Hit Chams",Default=false}):OnChanged(function(v) cfg.PlayerHit.Chams.Enabled=v end)
EffectsGroup:AddToggle("phit_flash",{Text="Hit Flash",Default=false}):OnChanged(function(v) cfg.PlayerHit.HitFlash.Enabled=v end)
EffectsGroup:AddDivider()
EffectsGroup:AddToggle("pelim_enabled",{Text="Elimination Effects",Default=false}):OnChanged(function(v) cfg.PlayerElimination.Enabled=v end)
EffectsGroup:AddToggle("pelim_snd",{Text="Elimination Sound",Default=false}):OnChanged(function(v) cfg.PlayerElimination.Sound.Enabled=v end)
EffectsGroup:AddToggle("pelim_notif",{Text="Elimination Notification",Default=false}):OnChanged(function(v) cfg.PlayerElimination.Notification.Enabled=v end)
EffectsGroup:AddToggle("pelim_killflash",{Text="Kill Flash",Default=false}):OnChanged(function(v) cfg.PlayerElimination.KillFlash.Enabled=v end)

local BulletGroup = Tabs.Visuals:AddLeftGroupbox("Bullet Tracers")
BulletGroup:AddToggle("bt_enabled",{Text="Bullet Tracers",Default=false}):OnChanged(function(v) cfg.BulletTracers.Enabled=v end)
BulletGroup:AddDropdown("bt_style",{Text="Style",Default=1,Values={"Beam","Line"}}):OnChanged(function(v) cfg.BulletTracers.Style=v end)
BulletGroup:AddSlider("bt_width",{Text="Width",Default=6,Min=1,Max=20,Rounding=0}):OnChanged(function(v) cfg.BulletTracers.Width=v/100 end)
BulletGroup:AddSlider("bt_lifetime",{Text="Lifetime",Default=60,Min=1,Max=200,Rounding=0}):OnChanged(function(v) cfg.BulletTracers.Lifetime=v/100 end)
BulletGroup:AddSlider("bt_fadetime",{Text="Fade Time",Default=35,Min=1,Max=100,Rounding=0}):OnChanged(function(v) cfg.BulletTracers.FadeTime=v/100 end)
BulletGroup:AddToggle("bt_expand",{Text="Expand",Default=true}):OnChanged(function(v) cfg.BulletTracers.Expand=v end)

local SoundVisGroup = Tabs.Visuals:AddRightGroupbox("Sound Visualizer")
SoundVisGroup:AddToggle("sv_enabled",{Text="Sound Visualizer",Default=false}):OnChanged(function(v) cfg.SoundVisualizer.Enabled=v end)
SoundVisGroup:AddDropdown("sv_source",{Text="Source",Default=1,Values={"All","Footsteps","Other"}}):OnChanged(function(v) cfg.SoundVisualizer.Source=v end)
SoundVisGroup:AddSlider("sv_minvol",{Text="Min Volume",Default=0,Min=0,Max=100,Rounding=0}):OnChanged(function(v) cfg.SoundVisualizer.MinVolume=v end)
SoundVisGroup:AddDropdown("sv_footmode",{Text="Footstep Mode",Default=1,Values={"Circle","Origin"}}):OnChanged(function(v) cfg.SoundVisualizer.Footsteps.Mode=v end)
SoundVisGroup:AddToggle("sv_footloud",{Text="Footstep Loudness Color",Default=true}):OnChanged(function(v) cfg.SoundVisualizer.Footsteps.UseLoudnessColor=v end)
SoundVisGroup:AddDropdown("sv_othermode",{Text="Other Mode",Default=2,Values={"Circle","Origin"}}):OnChanged(function(v) cfg.SoundVisualizer.Other.Mode=v end)

-- ════════════════════════════════════════════
--  MOVEMENT TAB
-- ════════════════════════════════════════════
local MovGroup = Tabs.Movement:AddLeftGroupbox("Movement")
MovGroup:AddToggle("mv_walkspeed",{Text="Custom Walk Speed",Default=false}):OnChanged(function(v) cfg.Movement.WalkSpeed.Enabled=v if not v then local hum=getHum() if hum then hum.WalkSpeed=16 end end end)
MovGroup:AddSlider("mv_wsspeed",{Text="Walk Speed Multiplier",Default=2,Min=1,Max=20,Rounding=1}):OnChanged(function(v) cfg.Movement.WalkSpeed.Speed=v end)
MovGroup:AddToggle("mv_jumppower",{Text="Custom Jump Power",Default=false}):OnChanged(function(v) cfg.Movement.JumpPower.Enabled=v if not v then local hum=getHum() if hum then hum.JumpPower=50 end end end)
MovGroup:AddSlider("mv_jpspeed",{Text="Jump Power Multiplier",Default=2,Min=1,Max=20,Rounding=1}):OnChanged(function(v) cfg.Movement.JumpPower.Speed=v end)
MovGroup:AddDivider()
MovGroup:AddToggle("mv_flight",{Text="Flight",Default=false}):OnChanged(function(v) cfg.Movement.Flight.Enabled=v if not v then stopFly() end end)
MovGroup:AddSlider("mv_flyspeed",{Text="Flight Speed",Default=100,Min=1,Max=1000,Rounding=0}):OnChanged(function(v) cfg.Movement.Flight.Speed=v end)
MovGroup:AddDivider()
MovGroup:AddToggle("mv_noclip",{Text="Noclip",Default=false}):OnChanged(function(v) cfg.Movement.Noclip.Enabled=v if v then startNoclip() else stopNoclip() end end)
MovGroup:AddDivider()
MovGroup:AddToggle("mv_slide",{Text="Sliding",Default=false}):OnChanged(function(v) cfg.Movement.Sliding.Enabled=v end)
MovGroup:AddSlider("mv_slidespd",{Text="Slide Speed",Default=10,Min=1,Max=100,Rounding=0}):OnChanged(function(v) cfg.Movement.Sliding.Speed=v end)
MovGroup:AddDivider()
MovGroup:AddToggle("mv_autostrafe",{Text="Auto Strafe",Default=false}):OnChanged(function(v) cfg.Movement.AutoStrafe.Enabled=v end)
MovGroup:AddSlider("mv_strafesp",{Text="Strafe Speed",Default=50,Min=1,Max=500,Rounding=0}):OnChanged(function(v) cfg.Movement.AutoStrafe.Speed=v end)
MovGroup:AddDivider()
MovGroup:AddToggle("mv_longjump",{Text="Long Jump",Default=false}):OnChanged(function(v) cfg.Movement.LongJump.Enabled=v end)
MovGroup:AddDropdown("mv_ljmode",{Text="Long Jump Mode",Default=1,Values={"Under Feet","Forward","Backward"}}):OnChanged(function(v) cfg.Movement.LongJump.Mode=v end)
MovGroup:AddSlider("mv_ljforce",{Text="Long Jump Force",Default=60,Min=1,Max=500,Rounding=0}):OnChanged(function(v) cfg.Movement.LongJump.Force=v end)
MovGroup:AddSlider("mv_ljupvel",{Text="Upward Velocity",Default=20,Min=0,Max=200,Rounding=0}):OnChanged(function(v) cfg.Movement.LongJump.UpwardVelocity=v end)

local CamGroup = Tabs.Movement:AddRightGroupbox("Camera / View")
CamGroup:AddToggle("cam_fov",{Text="Custom FOV",Default=false}):OnChanged(function(v) cfg.CameraFov.Enabled=v if not v then Camera.FieldOfView=70 end end)
CamGroup:AddSlider("cam_fovval",{Text="FOV Value",Default=70,Min=30,Max=120,Rounding=0}):OnChanged(function(v) cfg.CameraFov.Value=v end)
CamGroup:AddDivider()
CamGroup:AddToggle("tp_enabled",{Text="Third Person",Default=false}):OnChanged(function(v) cfg.ThirdPerson.Enabled=v if not v then Camera.CameraType=Enum.CameraType.Custom end end)
CamGroup:AddToggle("tp_replica",{Text="Show Replica",Default=false}):OnChanged(function(v) cfg.ThirdPerson.ShowReplica=v end)
CamGroup:AddToggle("tp_raycheck",{Text="Ray Check",Default=false}):OnChanged(function(v) cfg.ThirdPerson.RayCheck=v end)
CamGroup:AddSlider("tp_x",{Text="Offset X",Default=3,Min=-20,Max=20,Rounding=1}):OnChanged(function(v) cfg.ThirdPerson.X=v end)
CamGroup:AddSlider("tp_y",{Text="Offset Y",Default=2,Min=-20,Max=20,Rounding=1}):OnChanged(function(v) cfg.ThirdPerson.Y=v end)
CamGroup:AddSlider("tp_z",{Text="Offset Z",Default=6,Min=-20,Max=20,Rounding=1}):OnChanged(function(v) cfg.ThirdPerson.Z=v end)
CamGroup:AddDivider()
CamGroup:AddToggle("stretch_en",{Text="Stretched Resolution",Default=false}):OnChanged(function(v) cfg.StretchedResolution.Enabled=v end)
CamGroup:AddSlider("stretch_x",{Text="Stretch X",Default=13,Min=1,Max=20,Rounding=0}):OnChanged(function(v) cfg.StretchedResolution.X=v end)
CamGroup:AddSlider("stretch_y",{Text="Stretch Y",Default=10,Min=1,Max=20,Rounding=0}):OnChanged(function(v) cfg.StretchedResolution.Y=v end)

local ItemModGroup = Tabs.Movement:AddRightGroupbox("Item Modifiers")
ItemModGroup:AddToggle("im_nomotion",{Text="No Motion",Default=false}):OnChanged(function(v) cfg.ItemModifiers.NoMotion=v end)
ItemModGroup:AddToggle("im_nocamshake",{Text="No Camera Shake",Default=false}):OnChanged(function(v) cfg.ItemModifiers.NoCameraShake=v end)
ItemModGroup:AddToggle("im_nocamsway",{Text="No Camera Sway",Default=false}):OnChanged(function(v) cfg.ItemModifiers.NoCameraSway=v end)
ItemModGroup:AddToggle("im_noshootanim",{Text="No Shoot Animation",Default=false}):OnChanged(function(v) cfg.ItemModifiers.NoShootAnimation=v end)
ItemModGroup:AddToggle("im_nosprintanim",{Text="No Sprint Animation",Default=false}):OnChanged(function(v) cfg.ItemModifiers.NoSprintAnimation=v end)
ItemModGroup:AddToggle("im_noequipanim",{Text="No Equip Animation",Default=false}):OnChanged(function(v) cfg.ItemModifiers.NoEquipAnimation=v end)
ItemModGroup:AddToggle("im_noreloadanim",{Text="No Reload Animation",Default=false}):OnChanged(function(v) cfg.ItemModifiers.NoReloadAnimation=v end)
ItemModGroup:AddToggle("im_nospread",{Text="No Spread",Default=false}):OnChanged(function(v) cfg.ItemModifiers.NoSpread=v end)
ItemModGroup:AddToggle("im_fullauto",{Text="Full Auto",Default=false}):OnChanged(function(v) cfg.ItemModifiers.FullAuto=v end)
ItemModGroup:AddToggle("im_fastshoot",{Text="Fast Shoot",Default=false}):OnChanged(function(v) cfg.ItemModifiers.FastShoot=v end)
ItemModGroup:AddToggle("im_fastproj",{Text="Fast Projectile",Default=false}):OnChanged(function(v) cfg.ItemModifiers.FastProjectile=v end)
ItemModGroup:AddToggle("im_backstab",{Text="Always Backstab",Default=false}):OnChanged(function(v) cfg.ItemModifiers.AlwaysBackstab=v end)
ItemModGroup:AddToggle("im_infdjump",{Text="Infinite Double Jumps",Default=false}):OnChanged(function(v) cfg.ItemModifiers.InfiniteDoubleJumps=v if v then startInfJump() else stopInfJump() end end)
ItemModGroup:AddDivider()
ItemModGroup:AddToggle("im_aimcd",{Text="Aim Cooldown",Default=false}):OnChanged(function(v) cfg.ItemModifiers.AimCooldown.Enabled=v end)
ItemModGroup:AddSlider("im_aimcd_pct",{Text="Aim CD %",Default=50,Min=1,Max=200,Rounding=0}):OnChanged(function(v) cfg.ItemModifiers.AimCooldown.Percentage=v end)
ItemModGroup:AddToggle("im_recoil",{Text="Recoil",Default=false}):OnChanged(function(v) cfg.ItemModifiers.Recoil.Enabled=v end)
ItemModGroup:AddSlider("im_recoil_pct",{Text="Recoil %",Default=75,Min=0,Max=200,Rounding=0}):OnChanged(function(v) cfg.ItemModifiers.Recoil.Percentage=v end)
ItemModGroup:AddToggle("im_firecd",{Text="Fire Cooldown",Default=false}):OnChanged(function(v) cfg.ItemModifiers.FireCooldown.Enabled=v end)
ItemModGroup:AddSlider("im_firecd_pct",{Text="Fire CD %",Default=25,Min=0,Max=200,Rounding=0}):OnChanged(function(v) cfg.ItemModifiers.FireCooldown.Percentage=v end)
ItemModGroup:AddToggle("im_firerate",{Text="Fire Rate",Default=false}):OnChanged(function(v) cfg.ItemModifiers.FireRate.Enabled=v end)
ItemModGroup:AddSlider("im_firerate_pct",{Text="Fire Rate %",Default=100,Min=0,Max=500,Rounding=0}):OnChanged(function(v) cfg.ItemModifiers.FireRate.Percentage=v end)
ItemModGroup:AddToggle("im_meleecd",{Text="Melee Cooldown",Default=false}):OnChanged(function(v) cfg.ItemModifiers.MeleeCooldown.Enabled=v end)
ItemModGroup:AddSlider("im_meleecd_pct",{Text="Melee CD %",Default=25,Min=0,Max=200,Rounding=0}):OnChanged(function(v) cfg.ItemModifiers.MeleeCooldown.Percentage=v end)
ItemModGroup:AddToggle("im_dashcd",{Text="Dash Cooldown",Default=false}):OnChanged(function(v) cfg.ItemModifiers.DashCooldown.Enabled=v end)
ItemModGroup:AddSlider("im_dashcd_pct",{Text="Dash CD %",Default=25,Min=0,Max=200,Rounding=0}):OnChanged(function(v) cfg.ItemModifiers.DashCooldown.Percentage=v end)
ItemModGroup:AddToggle("im_mrange",{Text="Extend Melee Range",Default=false}):OnChanged(function(v) cfg.ItemModifiers.ExtendMeleeRange.Enabled=v end)
ItemModGroup:AddSlider("im_mrange_val",{Text="Melee Range",Default=10,Min=0,Max=100,Rounding=0}):OnChanged(function(v) cfg.ItemModifiers.ExtendMeleeRange.Range=v end)
ItemModGroup:AddDivider()
ItemModGroup:AddToggle("im_grenf",{Text="Grenade Fuse",Default=false}):OnChanged(function(v) cfg.ItemModifiers.GrenadeFuse.Enabled=v end)
ItemModGroup:AddDropdown("im_grenmode",{Text="Grenade Explode On",Default=1,Values={"Impact","Timer","Instant"}}):OnChanged(function(v) cfg.ItemModifiers.GrenadeFuse.ExplodeOn=v end)
ItemModGroup:AddToggle("im_grenfuse",{Text="Remove Fuse",Default=false}):OnChanged(function(v) cfg.ItemModifiers.GrenadeFuse.RemoveFuse=v end)

local RemovGroup = Tabs.Movement:AddLeftGroupbox("Removables")
RemovGroup:AddToggle("rem_noflash",{Text="No Flashbang",Default=false}):OnChanged(function(v) cfg.Removables.NoFlashbang=v end)
RemovGroup:AddToggle("rem_noburn",{Text="No Burn Effect",Default=false}):OnChanged(function(v) cfg.Removables.NoBurnEffect=v end)
RemovGroup:AddToggle("rem_noads",{Text="No ADS Vignette",Default=false}):OnChanged(function(v) cfg.Removables.NoAdsVignette=v end)
RemovGroup:AddToggle("rem_noscopeoverlay",{Text="No Scope Overlay",Default=false}):OnChanged(function(v) cfg.Removables.NoScopeOverlay=v end)
RemovGroup:AddToggle("rem_noscopereticle",{Text="No Scope Reticle",Default=false}):OnChanged(function(v) cfg.Removables.NoScopeReticle=v end)
RemovGroup:AddToggle("rem_noguntr",{Text="No Gun Tracers",Default=false}):OnChanged(function(v) cfg.Removables.NoGunTracers=v end)
RemovGroup:AddToggle("rem_nomuzzle",{Text="No Muzzle Flash",Default=false}):OnChanged(function(v) cfg.Removables.NoMuzzleFlash=v end)
RemovGroup:AddToggle("rem_nohitmarker",{Text="No Hitmarker",Default=false}):OnChanged(function(v) cfg.Removables.NoHitmarker=v end)

-- ════════════════════════════════════════════
--  MISC TAB
-- ════════════════════════════════════════════
local AutoGroup = Tabs.Misc:AddLeftGroupbox("Automation")
AutoGroup:AddToggle("ap_enabled",{Text="Auto Pickup Drops",Default=false}):OnChanged(function(v) cfg.AutoPickupDrops.Enabled=v end)
AutoGroup:AddToggle("ar_enabled",{Text="Auto Respawn",Default=false}):OnChanged(function(v) cfg.AutoRespawn.Enabled=v end)
AutoGroup:AddDivider()
AutoGroup:AddToggle("aq_enabled",{Text="Auto Queue",Default=false}):OnChanged(function(v) cfg.AutoQueue.Enabled=v end)
AutoGroup:AddDropdown("aq_mode",{Text="Queue Mode",Default=1,Values={"1v1","2v2","FFA","Ranked"}}):OnChanged(function(v) cfg.AutoQueue.Queue=v end)
AutoGroup:AddDivider()
AutoGroup:AddToggle("av_enabled",{Text="Auto Vote",Default=false}):OnChanged(function(v) cfg.AutoVote.Enabled=v end)
AutoGroup:AddToggle("ab_enabled",{Text="Auto Ban",Default=false}):OnChanged(function(v) cfg.AutoBan.Enabled=v end)
AutoGroup:AddToggle("alo_enabled",{Text="Auto Loadout",Default=false}):OnChanged(function(v) cfg.AutoLoadout.Enabled=v end)
AutoGroup:AddToggle("alo_permap",{Text="Per Map Loadout",Default=false}):OnChanged(function(v) cfg.AutoLoadout.PerMap=v end)
AutoGroup:AddToggle("alo_multi",{Text="Multiple Loadouts",Default=false}):OnChanged(function(v) cfg.AutoLoadout.MultipleLoadouts=v end)
AutoGroup:AddDivider()
AutoGroup:AddToggle("ak_enabled",{Text="Anti-Katana",Default=true}):OnChanged(function(v) cfg.AntiKatana.Enabled=v end)
AutoGroup:AddToggle("sst_trigger",{Text="Subspace Tripmines Auto Trigger",Default=false}):OnChanged(function(v) cfg.SubspaceTripmines.AutoTrigger=v end)
AutoGroup:AddToggle("sst_team",{Text="Subspace Team Trigger",Default=false}):OnChanged(function(v) cfg.SubspaceTripmines.TeamTrigger=v end)

local AnimGroup = Tabs.Misc:AddLeftGroupbox("Animation Player")
AnimGroup:AddToggle("ani_enabled",{Text="Enable Animation",Default=false}):OnChanged(function(v)
    cfg.AnimationPlayer.Enabled=v
    if not v then
        local char=getChar()
        if char then
            local hum=char:FindFirstChildOfClass("Humanoid")
            local anim=hum and hum:FindFirstChildOfClass("Animator")
            if anim then for _,t in ipairs(anim:GetPlayingAnimationTracks()) do t:Stop() end end
        end
    end
end)
AnimGroup:AddDropdown("ani_anim",{Text="Animation",Default=1,Values={"Cat Girl Bounce","Griddy","Floss","Orange Justice","Robot","Dab","Renegade","Woah"}}):OnChanged(function(v) cfg.AnimationPlayer.Animation=v end)
AnimGroup:AddSlider("ani_speed",{Text="Speed",Default=100,Min=1,Max=500,Rounding=0}):OnChanged(function(v) cfg.AnimationPlayer.Speed=v/100 end)
AnimGroup:AddSlider("ani_start",{Text="Start %",Default=0,Min=0,Max=100,Rounding=0}):OnChanged(function(v) cfg.AnimationPlayer.Start=v end)
AnimGroup:AddSlider("ani_end",{Text="End %",Default=100,Min=0,Max=100,Rounding=0}):OnChanged(function(v) cfg.AnimationPlayer.End=v end)

local DetectorGroup = Tabs.Misc:AddRightGroupbox("Detectors")
DetectorGroup:AddToggle("hd_enabled",{Text="Hacker Detector",Default=false}):OnChanged(function(v) cfg.HackerDetector.Enabled=v end)
DetectorGroup:AddToggle("hd_notify",{Text="Notify on Detection",Default=false}):OnChanged(function(v) cfg.HackerDetector.Notify=v end)
DetectorGroup:AddDivider()
DetectorGroup:AddToggle("md_enabled",{Text="Mod Detector",Default=false}):OnChanged(function(v) cfg.ModDetector.Enabled=v end)
DetectorGroup:AddDivider()
DetectorGroup:AddToggle("ua_enabled",{Text="Unlock All Cosmetics",Default=false}):OnChanged(function(v) cfg.UnlockAll.Enabled=v end)

local DeviceGroup = Tabs.Misc:AddRightGroupbox("Device / View")
DeviceGroup:AddToggle("ds_enabled",{Text="Device Spoof",Default=false}):OnChanged(function(v) cfg.DeviceSpoof.Enabled=v end)
DeviceGroup:AddDropdown("ds_type",{Text="Spoof Type",Default=1,Values={"VR","Mobile","Console","Desktop"}}):OnChanged(function(v) cfg.DeviceSpoof.SpoofType=v end)
DeviceGroup:AddDivider()
DeviceGroup:AddToggle("vmoff_enabled",{Text="ViewModel Offset",Default=false}):OnChanged(function(v) cfg.ViewModelOffset.Enabled=v end)
DeviceGroup:AddSlider("vmoff_x",{Text="Offset X",Default=0,Min=-5,Max=5,Rounding=1}):OnChanged(function(v) cfg.ViewModelOffset.X=v end)
DeviceGroup:AddSlider("vmoff_y",{Text="Offset Y",Default=0,Min=-5,Max=5,Rounding=1}):OnChanged(function(v) cfg.ViewModelOffset.Y=v end)
DeviceGroup:AddSlider("vmoff_z",{Text="Offset Z",Default=0,Min=-5,Max=5,Rounding=1}):OnChanged(function(v) cfg.ViewModelOffset.Z=v end)
DeviceGroup:AddSlider("vmoff_pitch",{Text="Pitch",Default=0,Min=-180,Max=180,Rounding=0}):OnChanged(function(v) cfg.ViewModelOffset.Pitch=v end)
DeviceGroup:AddSlider("vmoff_yaw",{Text="Yaw",Default=0,Min=-180,Max=180,Rounding=0}):OnChanged(function(v) cfg.ViewModelOffset.Yaw=v end)
DeviceGroup:AddSlider("vmoff_roll",{Text="Roll",Default=0,Min=-180,Max=180,Rounding=0}):OnChanged(function(v) cfg.ViewModelOffset.Roll=v end)

-- ════════════════════════════════════════════
--  SPOOFER TAB
-- ════════════════════════════════════════════
local LSpoofGroup = Tabs.Spoofer:AddLeftGroupbox("Local Player Spoof")
local PS=cfg.PlayerSpoofer.LocalPlayer
LSpoofGroup:AddToggle("sp_name",{Text="Spoof Name",Default=false}):OnChanged(function(v) PS.Name.Enabled=v end)
LSpoofGroup:AddToggle("sp_displayname",{Text="Spoof Display Name",Default=false}):OnChanged(function(v) PS.DisplayName.Enabled=v end)
LSpoofGroup:AddToggle("sp_avatar",{Text="Spoof Avatar",Default=false}):OnChanged(function(v) PS.Avatar.Enabled=v end)
LSpoofGroup:AddToggle("sp_ping",{Text="Spoof Ping",Default=false}):OnChanged(function(v) PS.Ping.Enabled=v end)
LSpoofGroup:AddDropdown("sp_pingval",{Text="Ping Value",Default=1,Values={"Low","Medium","High"}}):OnChanged(function(v) PS.Ping.Value=v end)
LSpoofGroup:AddToggle("sp_keys",{Text="Spoof Keys",Default=false}):OnChanged(function(v) PS.Keys.Enabled=v end)
LSpoofGroup:AddSlider("sp_keysval",{Text="Keys Value",Default=999,Min=0,Max=99999,Rounding=0}):OnChanged(function(v) PS.Keys.Value=v end)
LSpoofGroup:AddToggle("sp_eventcurrency",{Text="Spoof Event Currency",Default=false}):OnChanged(function(v) PS.EventCurrency.Enabled=v end)
LSpoofGroup:AddSlider("sp_evc_val",{Text="Event Currency",Default=9999,Min=0,Max=99999,Rounding=0}):OnChanged(function(v) PS.EventCurrency.Value=v end)
LSpoofGroup:AddToggle("sp_winstreak",{Text="Spoof Winstreak",Default=false}):OnChanged(function(v) PS.Winstreak.Enabled=v end)
LSpoofGroup:AddSlider("sp_ws_val",{Text="Winstreak",Default=999,Min=0,Max=99999,Rounding=0}):OnChanged(function(v) PS.Winstreak.Value=v end)
LSpoofGroup:AddToggle("sp_level",{Text="Spoof Level",Default=false}):OnChanged(function(v) PS.Level.Enabled=v end)
LSpoofGroup:AddSlider("sp_lv_val",{Text="Level",Default=999,Min=0,Max=9999,Rounding=0}):OnChanged(function(v) PS.Level.Value=v end)
LSpoofGroup:AddToggle("sp_cwins",{Text="Spoof Casual Wins",Default=false}):OnChanged(function(v) PS.CasualWins.Enabled=v end)
LSpoofGroup:AddSlider("sp_cw_val",{Text="Casual Wins",Default=99999,Min=0,Max=999999,Rounding=0}):OnChanged(function(v) PS.CasualWins.Value=v end)
LSpoofGroup:AddToggle("sp_rwins",{Text="Spoof Ranked Wins",Default=false}):OnChanged(function(v) PS.RankedWins.Enabled=v end)
LSpoofGroup:AddSlider("sp_rw_val",{Text="Ranked Wins",Default=9999,Min=0,Max=99999,Rounding=0}):OnChanged(function(v) PS.RankedWins.Value=v end)
LSpoofGroup:AddToggle("sp_elo",{Text="Spoof Ranked ELO",Default=false}):OnChanged(function(v) PS.RankedElo.Enabled=v end)
LSpoofGroup:AddSlider("sp_elo_val",{Text="Ranked ELO",Default=3600,Min=0,Max=10000,Rounding=0}):OnChanged(function(v) PS.RankedElo.Value=v end)
LSpoofGroup:AddToggle("sp_lbrank",{Text="Spoof Leaderboard Rank",Default=false}):OnChanged(function(v) PS.LeaderboardRank.Enabled=v end)
LSpoofGroup:AddSlider("sp_lbr_val",{Text="Leaderboard Rank",Default=1,Min=1,Max=1000,Rounding=0}):OnChanged(function(v) PS.LeaderboardRank.Value=v end)
LSpoofGroup:AddDivider()
LSpoofGroup:AddToggle("sp_influencer",{Text="Spoof Influencer",Default=false}):OnChanged(function(v) PS.Influencer.Enabled=v end)
LSpoofGroup:AddToggle("sp_rblxemp",{Text="Spoof Roblox Employee",Default=false}):OnChanged(function(v) PS.RobloxEmployee.Enabled=v end)
LSpoofGroup:AddDivider()
LSpoofGroup:AddToggle("sp_favmap",{Text="Spoof Favorite Map",Default=false}):OnChanged(function(v) PS.FavoriteMap.Enabled=v end)
LSpoofGroup:AddDropdown("sp_favmap_val",{Text="Favorite Map",Default=1,Values={"Arena","Bridge","Canyon","Citadel","Colosseum","Factory","Facility","Forest","Harbor","Hillside","Jungle","Manor","Marketplace","Mountain","Oasis","Plaza","Ruins","Savanna","Skyline","Stadium","Swamp","Tundra","Village","Volcano","Warehouse","Winter Wonderland"}}):OnChanged(function(v) PS.FavoriteMap.Value=v end)
LSpoofGroup:AddToggle("sp_nametag",{Text="Spoof Nametag Status",Default=false}):OnChanged(function(v) PS.NametagStatus.Enabled=v end)
LSpoofGroup:AddDropdown("sp_nametag_val",{Text="Nametag Status",Default=1,Values={"Prime","Radiant","Elite","Pro","Veteran","Rookie"}}):OnChanged(function(v) PS.NametagStatus.Value=v end)

local OSpoofGroup = Tabs.Spoofer:AddRightGroupbox("Other Players Spoof")
local OP=cfg.PlayerSpoofer.OtherPlayers
OSpoofGroup:AddToggle("osp_name",{Text="Spoof Names",Default=false}):OnChanged(function(v) OP.Name.Enabled=v end)
OSpoofGroup:AddToggle("osp_displayname",{Text="Spoof Display Names",Default=false}):OnChanged(function(v) OP.DisplayName.Enabled=v end)
OSpoofGroup:AddToggle("osp_avatar",{Text="Spoof Avatars",Default=false}):OnChanged(function(v) OP.Avatar.Enabled=v end)
OSpoofGroup:AddToggle("osp_winstreak",{Text="Spoof Winstreak",Default=false}):OnChanged(function(v) OP.Winstreak.Enabled=v end)
OSpoofGroup:AddSlider("osp_ws_val",{Text="Winstreak",Default=0,Min=0,Max=9999,Rounding=0}):OnChanged(function(v) OP.Winstreak.Value=v end)
OSpoofGroup:AddToggle("osp_level",{Text="Spoof Level",Default=false}):OnChanged(function(v) OP.Level.Enabled=v end)
OSpoofGroup:AddSlider("osp_lv_val",{Text="Level",Default=0,Min=0,Max=9999,Rounding=0}):OnChanged(function(v) OP.Level.Value=v end)
OSpoofGroup:AddToggle("osp_elo",{Text="Spoof ELO",Default=false}):OnChanged(function(v) OP.RankedElo.Enabled=v end)
OSpoofGroup:AddSlider("osp_elo_val",{Text="ELO",Default=0,Min=0,Max=10000,Rounding=0}):OnChanged(function(v) OP.RankedElo.Value=v end)
OSpoofGroup:AddToggle("osp_lbrank",{Text="Spoof LB Rank",Default=false}):OnChanged(function(v) OP.LeaderboardRank.Enabled=v end)
OSpoofGroup:AddSlider("osp_lbr_val",{Text="LB Rank",Default=200,Min=1,Max=1000,Rounding=0}):OnChanged(function(v) OP.LeaderboardRank.Value=v end)
OSpoofGroup:AddToggle("osp_nametag",{Text="Spoof Nametag",Default=false}):OnChanged(function(v) OP.NametagStatus.Enabled=v end)
OSpoofGroup:AddDropdown("osp_nametag_val",{Text="Nametag",Default=1,Values={"Prime","Radiant","Elite","Pro","Veteran","Rookie"}}):OnChanged(function(v) OP.NametagStatus.Value=v end)
OSpoofGroup:AddToggle("osp_influencer",{Text="Spoof Influencer",Default=false}):OnChanged(function(v) OP.Influencer.Enabled=v end)
OSpoofGroup:AddToggle("osp_rblxemp",{Text="Spoof Roblox Employee",Default=false}):OnChanged(function(v) OP.RobloxEmployee.Enabled=v end)
OSpoofGroup:AddToggle("osp_favmap",{Text="Spoof Fav Map",Default=false}):OnChanged(function(v) OP.FavoriteMap.Enabled=v end)

-- ════════════════════════════════════════════
--  SETTINGS TAB
-- ════════════════════════════════════════════
local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")
MenuGroup:AddLabel("Menu Bind"):AddKeyPicker("MenuKeybind",{Default="RightShift",NoUI=true,Text="Menu Keybind"})
MenuGroup:AddToggle("show_watermark",{Text="Show Watermark",Default=true}):OnChanged(function(v) cfg.ShowWatermark=v end)
MenuGroup:AddButton("Unload Script",function()
    AW.Unload()
    pcall(Library.Unload,Library)
end)

ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
SaveManager:SetFolder("always.winning/rivals")
SaveManager:BuildConfigSection(Tabs.Settings)
pcall(SaveManager.LoadAutoloadConfig,SaveManager)

Library.ToggleKeybind=Options.MenuKeybind

notify("always.winning","Loaded.")

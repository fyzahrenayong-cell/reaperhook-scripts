--[[
    always.winning
    Full Rivals rebuild — Obsidian UI
    Every recoverable tab + feature surface from the Kicia dump.
]]

if getgenv().AlwaysWinning and getgenv().AlwaysWinning.Unload then
    pcall(getgenv().AlwaysWinning.Unload)
end
if not game:IsLoaded() then game.Loaded:Wait() end

print("[always.winning] loading, PlaceId=" .. tostring(game.PlaceId))

local AW = { connections = {}, cleanups = {}, destroyed = false }
getgenv().AlwaysWinning = AW

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

local rawget, rawset = rawget, rawset

function AW.fn(name)
    local v
    pcall(function() v = getgenv()[name] end)
    if type(v) ~= "function" then pcall(function() v = getgenv()[name] end) end
    return type(v) == "function" and v or nil
end

local getthreadidentity_ = AW.fn("getthreadidentity") or AW.fn("getidentity")
local setthreadidentity_ = AW.fn("setthreadidentity") or AW.fn("setidentity")
local gethui_ = AW.fn("gethui")
local cloneref = AW.fn("cloneref") or function(x) return x end
local setclipboard = AW.fn("setclipboard") or AW.fn("toclipboard") or function() end
local isfolder, makefolder = AW.fn("isfolder"), AW.fn("makefolder")
local isfile, readfile, writefile, delfile, listfiles = AW.fn("isfile"), AW.fn("readfile"), AW.fn("writefile"), AW.fn("delfile"), AW.fn("listfiles")
local getcustomasset = AW.fn("getcustomasset") or AW.fn("getsynasset")
local hookmetamethod, getnamecallmethod, checkcaller = AW.fn("hookmetamethod"), AW.fn("getnamecallmethod"), AW.fn("checkcaller")

local function identity(n)
    if not setthreadidentity_ then return function() end end
    local old = getthreadidentity_ and getthreadidentity_() or nil
    pcall(setthreadidentity_, n)
    return function() if old then pcall(setthreadidentity_, old) end end
end
AW.identity = identity

local function hudParent()
    local ok, h = pcall(function() return gethui_ and gethui_() end)
    if ok and h then return h end
    return CoreGui
end
AW.hudParent = hudParent
function AW.track(c) AW.connections[#AW.connections+1] = c; return c end
function AW.onUnload(f) AW.cleanups[#AW.cleanups+1] = f end

-- Signal
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ _handlers = {} }, Signal) end
function Signal:Connect(fn)
    local h = { fn = fn, connected = true }
    table.insert(self._handlers, h)
    local sig = self
    return { Connected = true, Disconnect = function(c)
        if not h.connected then return end
        h.connected = false; c.Connected = false
        local i = table.find(sig._handlers, h)
        if i then table.remove(sig._handlers, i) end
    end }
end
function Signal:Once(fn) local c; c = self:Connect(function(...) c:Disconnect(); fn(...) end); return c end
function Signal:Fire(...) for _, h in ipairs(table.clone(self._handlers)) do if h.connected then task.spawn(h.fn, ...) end end end
function Signal:Destroy() table.clear(self._handlers) end
AW.Signal = Signal

-- Trove
local Trove = {}
Trove.__index = Trove
function Trove.new(name) return setmetatable({ _name = name, _items = {} }, Trove) end
local function cleanItem(o)
    local t = typeof(o)
    if t == "RBXScriptConnection" then o:Disconnect()
    elseif t == "Instance" then pcall(function() o:Destroy() end)
    elseif t == "thread" then pcall(task.cancel, o)
    elseif type(o) == "function" then pcall(o)
    elseif type(o) == "table" then
        local function member(k) local ok, v = pcall(function() return o[k] end); return ok and type(v) == "function" and v or nil end
        local cancel, getStatus = member("cancel"), member("getStatus")
        if cancel and getStatus then pcall(cancel, o); return end
        local destroy = member("Destroy"); if destroy then pcall(destroy, o); return end
        local disconnect = member("Disconnect"); if disconnect then pcall(disconnect, o) end
    end
end
function Trove:Add(o) table.insert(self._items, o); return o end
function Trove:Connect(sig, fn) return self:Add(sig:Connect(fn)) end
function Trove:Extend() return self:Add(Trove.new(self._name)) end
function Trove:Remove(o, keep)
    local i = table.find(self._items, o)
    if i then table.remove(self._items, i); if not keep then cleanItem(o) end end
end
function Trove:Clean()
    local items = self._items; self._items = {}; self._cleaning = true
    for i = #items, 1, -1 do cleanItem(items[i]) end
    self._cleaning = false
end
Trove.Destroy = Trove.Clean
AW.Trove = Trove
local GlobalTrove = Trove.new("AlwaysWinning")
AW.GlobalTrove = GlobalTrove

local function ensureFolder(path)
    if not (isfolder and makefolder) or type(path) ~= "string" then return end
    local acc
    for part in path:gmatch("[^/]+") do
        acc = acc and (acc .. "/" .. part) or part
        pcall(function() if not isfolder(acc) then makefolder(acc) end end)
    end
end
for _, p in ipairs({
    "always.winning","always.winning/configs","always.winning/cache",
    "always.winning/movement_recorder","always.winning/cosmetics",
    "always.winning/cosmetics/states","always.winning/esp_images",
    "always.winning/crosshair_textures","always.winning/skyboxes",
}) do ensureFolder(p) end

--==========================================================================
--  FULL CONFIG — every surface from the dump
--==========================================================================
local Config = {
    Data = {
        Aimbot = {
            Enabled = false, Mode = "Toggle", Key = "MouseButton2",
            FOV = 120, Smoothness = 0.22, TeamCheck = true, VisibleCheck = false,
            TargetPart = "Head", Prediction = 0.12, MaxDistance = 900,
            Sticky = false, AirPart = "Head", GroundPart = "HumanoidRootPart",
            ShowFOV = false, FOVColor = Color3.fromRGB(255,255,255),
        },
        SilentAim = {
            Enabled = false, Mode = "Always", Key = "E",
            FOV = 90, HitChance = 100, TargetPart = "Head",
            TeamCheck = true, VisibleCheck = false, MaxDistance = 1000,
            Prediction = 0.1, Wallbang = false, ShowFOV = false,
            FOVColor = Color3.fromRGB(0,255,140),
        },
        TriggerBot = {
            Enabled = false, Mode = "Hold", Key = "MouseButton2",
            Delay = 0.02, TeamCheck = true, MaxDistance = 400,
        },
        ESP = {
            Enabled = false, Mode = "Always", TeamCheck = false,
            UseDisplayName = true, FontSize = 14, FlagFontSize = 12,
            TextCase = "Standard", TextSurround = "None",
            FlagTextCase = "Standard", FlagTextSurround = "None",
            DistanceScaling = false, DistanceScalingRef = 100, BoxFit = "Dynamic",
            MaxDistance = 1500,
            Enemy = {
                Enabled = true,
                Name = { Enabled = true, Color = Color3.fromRGB(255,255,255), Transparency = 0 },
                Box = { Enabled = true, Color = Color3.fromRGB(255,255,255), Style = "Corner" },
                FilledBox = { Enabled = false, Color = Color3.fromRGB(255,70,70), Transparency = 0.7 },
                HealthBar = { Enabled = true, Color = Color3.fromRGB(0,255,100), ColorMode = "Reactive" },
                HealthNumber = { Enabled = false, Color = Color3.fromRGB(255,255,255) },
                HeldWeapon = { Enabled = true, Color = Color3.fromRGB(255,255,255), Transparency = 0 },
                AmmoBar = { Enabled = false, Color = Color3.fromRGB(80,180,255), ColorMode = "Solid" },
                Distance = { Enabled = true, Color = Color3.fromRGB(200,200,200) },
                Rank = { Enabled = false, Color = Color3.fromRGB(255,215,0) },
                Winstreak = { Enabled = false, Color = Color3.fromRGB(255,100,255) },
                Deflecting = { Enabled = true, Color = Color3.fromRGB(0,200,255), Transparency = 0 },
                Chams = {
                    Enabled = false, Kind = "Highlight",
                    InnerColor = Color3.fromRGB(255,70,70), InnerTransparency = 0.55,
                    OutlineColor = Color3.fromRGB(255,255,255), OutlineTransparency = 0,
                    Glow = false, GlowColor = Color3.fromRGB(255,70,70),
                },
                Skeleton = { Enabled = false, Color = Color3.fromRGB(255,255,255), Transparency = 0, Thickness = 1 },
                HeadMarker = { Enabled = false, Color = Color3.fromRGB(255,50,50), Transparency = 0, Shape = "Cross", Filled = false, Outline = true, OutlineColor = Color3.new(0,0,0), OutlineTransparency = 0 },
                Tracer = { Enabled = false, Color = Color3.fromRGB(255,255,255), Transparency = 0, Thickness = 1, Origin = "Bottom", Target = "Feet", Outline = false, OutlineColor = Color3.new(0,0,0), OutlineTransparency = 0, OutlineThickness = 2 },
            },
            Team = {
                Enabled = false,
                Name = { Enabled = true, Color = Color3.fromRGB(80,180,255), Transparency = 0 },
                Box = { Enabled = true, Color = Color3.fromRGB(80,180,255), Style = "Corner" },
                FilledBox = { Enabled = false, Color = Color3.fromRGB(80,180,255), Transparency = 0.7 },
                HealthBar = { Enabled = true, Color = Color3.fromRGB(0,200,255), ColorMode = "Reactive" },
                HealthNumber = { Enabled = false, Color = Color3.fromRGB(255,255,255) },
                HeldWeapon = { Enabled = false, Color = Color3.fromRGB(255,255,255), Transparency = 0 },
                AmmoBar = { Enabled = false, Color = Color3.fromRGB(80,180,255), ColorMode = "Solid" },
                Distance = { Enabled = true, Color = Color3.fromRGB(180,220,255) },
                Rank = { Enabled = false, Color = Color3.fromRGB(255,215,0) },
                Winstreak = { Enabled = false, Color = Color3.fromRGB(255,100,255) },
                Deflecting = { Enabled = false, Color = Color3.fromRGB(0,200,255), Transparency = 0 },
                Chams = {
                    Enabled = false, Kind = "Highlight",
                    InnerColor = Color3.fromRGB(80,180,255), InnerTransparency = 0.55,
                    OutlineColor = Color3.fromRGB(255,255,255), OutlineTransparency = 0,
                    Glow = false, GlowColor = Color3.fromRGB(80,180,255),
                },
                Skeleton = { Enabled = false, Color = Color3.fromRGB(80,180,255), Transparency = 0, Thickness = 1 },
                HeadMarker = { Enabled = false, Color = Color3.fromRGB(80,180,255), Transparency = 0, Shape = "Cross", Filled = false, Outline = true, OutlineColor = Color3.new(0,0,0), OutlineTransparency = 0 },
                Tracer = { Enabled = false, Color = Color3.fromRGB(80,180,255), Transparency = 0, Thickness = 1, Origin = "Bottom", Target = "Feet", Outline = false, OutlineColor = Color3.new(0,0,0), OutlineTransparency = 0, OutlineThickness = 2 },
            },
            RankSpoof = { Enabled = false, Text = "Owner", Icon = "" },
        },
        Movement = {
            Speed = { Enabled = false, Value = 28, Mode = "WalkSpeed" },
            Fly = { Enabled = false, Speed = 45, Key = "F" },
            NoClip = { Enabled = false, Key = "V" },
            InfiniteJump = false,
            BunnyHop = false,
            LongJump = false,
            JumpPower = { Enabled = false, Value = 50 },
            MovementRecorder = { Enabled = false, Record = false, Replay = false, Selected = "" },
        },
        Visuals = {
            FullBright = false, NoFog = false,
            Ambient = Color3.fromRGB(180,180,180),
            FOV = 70, FOVEnabled = false,
            Crosshair = {
                Enabled = false, Size = 8, Thickness = 1, Gap = 4,
                Color = Color3.fromRGB(0,255,140), Style = "Cross",
            },
            World = {
                Brightness = 2, ClockTime = 14, ForceTime = false,
                FogStart = 0, FogEnd = 1000, Exposure = 0,
            },
            Skybox = { Enabled = false, Id = "" },
        },
        Cosmetics = {
            Enabled = false,
            KillEffect = false,
            KillEffectId = "",
            Trail = false,
            TrailColor = Color3.fromRGB(0,255,160),
            Aura = false,
            AuraColor = Color3.fromRGB(255,50,50),
            CustomArms = false,
        },
        Misc = {
            Watermark = true, StreamProof = false, AutoRespawn = false, AntiAFK = true,
            HitSound = false, HitSoundId = "rbxassetid://12222216", HitSoundVolume = 1,
            Killsay = false, KillsayText = "always.winning",
            AutoBuy = false, Zoom = false, ZoomFOV = 20,
        },
        Player = {
            ThirdPerson = false, ThirdPersonDistance = 10,
            NoCameraShake = false, InfStamina = false,
        },
        Menu = { Keybind = "RightShift" },
    },
    Changed = Signal.new(),
}

function Config:Get(path)
    local node = self.Data
    for _, key in ipairs(path) do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end
function Config:Set(path, value)
    local node = self.Data
    for i = 1, #path - 1 do
        local key = path[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[path[#path]] = value
    self.Changed:Fire(path, value)
end
AW.Config = Config

-- Spring
local Spring = {}
local function posVel(self, now)
    local p0, v0, p1, d, s = self._p0, self._v0, self._target, self._damper, self._speed
    local t = s * (now - self._t0)
    local d2 = d * d
    local h, si, co
    if d2 < 1 then
        h = math.sqrt(1 - d2)
        local ep = math.exp(-d * t) / h
        co, si = ep * math.cos(h * t), ep * math.sin(h * t)
    elseif d2 == 1 then
        local ep = math.exp(-d * t); co, si = ep, ep * t
    else
        h = math.sqrt(d2 - 1)
        local u = math.exp((-d + h) * t) / (2 * h)
        local v = math.exp((-d - h) * t) / (2 * h)
        co, si = u + v, u - v
    end
    local a0 = h * co + d * si
    local a1 = 1 - a0
    local a2 = si / s
    return a0 * p0 + a1 * p1 + a2 * v0, (-s * si) * p0 + (s * si) * p1 + (h * co - d * si) * v0
end
function Spring.new(initial, clock)
    initial = initial or 0; clock = clock or os.clock
    return setmetatable({ _clock = clock, _t0 = clock(), _p0 = initial, _v0 = 0 * initial, _target = initial, _damper = 1, _speed = 1 }, Spring)
end
function Spring:Impulse(v) self.Velocity = self.Velocity + v end
function Spring:SetTarget(value, doNotAnimate)
    if doNotAnimate then self._p0, self._v0, self._target, self._t0 = value, 0 * value, value, self._clock()
    else self.Target = value end
end
Spring.__index = function(self, k)
    if Spring[k] then return Spring[k] end
    if k == "Value" or k == "Position" or k == "p" then local p = posVel(self, self._clock()); return p
    elseif k == "Velocity" or k == "v" then local _, v = posVel(self, self._clock()); return v
    elseif k == "Target" or k == "t" then return self._target
    elseif k == "Damper" or k == "d" then return self._damper
    elseif k == "Speed" or k == "s" then return self._speed end
    return nil
end
Spring.__newindex = function(self, k, v)
    local now = self._clock()
    if k == "Value" or k == "Position" or k == "p" then local _, vel = posVel(self, now); self._p0, self._v0 = v, vel
    elseif k == "Velocity" or k == "v" then local pos = posVel(self, now); self._p0, self._v0 = pos, v
    elseif k == "Target" or k == "t" then local pos, vel = posVel(self, now); self._p0, self._v0, self._target = pos, vel, v
    elseif k == "Damper" or k == "d" then local pos, vel = posVel(self, now); self._p0, self._v0, self._damper = pos, vel, v
    elseif k == "Speed" or k == "s" then local pos, vel = posVel(self, now); self._p0, self._v0, self._speed = pos, vel, v < 0 and 0 or v
    else rawset(self, k, v); return end
    self._t0 = now
end
AW.Spring = Spring

-- Utils
local function getCharacter(player) return player and player.Character end
local function getHumanoid(player) local c = getCharacter(player); return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot(player) local c = getCharacter(player); return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c.PrimaryPart) end
local function isAlive(player) local h = getHumanoid(player); return h and h.Health > 0 end
local function isTeammate(player)
    if not LocalPlayer or not player or player == LocalPlayer then return true end
    local ok, same = pcall(function() return player.Team == LocalPlayer.Team and player.Team ~= nil end)
    return ok and same
end
local function worldToScreen(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil, false end
    local screen, onScreen = cam:WorldToViewportPoint(pos)
    return Vector2.new(screen.X, screen.Y), onScreen and screen.Z > 0
end
local function formatText(str, caseMode, surround)
    if caseMode == "UPPERCASE" then str = string.upper(str)
    elseif caseMode == "lowercase" then str = string.lower(str) end
    if surround == "[]" then return "["..str.."]"
    elseif surround == "()" then return "("..str..")"
    elseif surround == "<>" then return "<"..str..">"
    elseif surround == "{}" then return "{"..str.."}" end
    return str
end

-- Drawings
local Drawings = {}
local function newDrawing(class, props)
    local ok, obj = pcall(function() return Drawing.new(class) end)
    if not ok or not obj then return nil end
    if props then for k, v in pairs(props) do pcall(function() obj[k] = v end) end end
    table.insert(Drawings, obj)
    return obj
end
AW.onUnload(function()
    for _, d in ipairs(Drawings) do pcall(function() d:Remove() end) end
    table.clear(Drawings)
end)

-- FOV circles
local AimFOVCircle = newDrawing("Circle", { Thickness = 1, NumSides = 64, Filled = false, Visible = false, ZIndex = 5 })
local SilentFOVCircle = newDrawing("Circle", { Thickness = 1, NumSides = 64, Filled = false, Visible = false, ZIndex = 5 })

-- ESP
local ESP = { objects = {}, highlights = {} }
local SKELETON_BONES = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local function clearPlayerESP(player)
    local pack = ESP.objects[player]
    if pack then
        for _, d in pairs(pack) do
            if typeof(d) == "Instance" then pcall(function() d:Destroy() end)
            elseif type(d) == "table" then for _, sd in pairs(d) do pcall(function() sd:Remove() end) end
            else pcall(function() d:Remove() end) end
        end
        ESP.objects[player] = nil
    end
    local hl = ESP.highlights[player]
    if hl then pcall(function() hl:Destroy() end); ESP.highlights[player] = nil end
end

local function createPlayerESP(player)
    if ESP.objects[player] then return end
    local pack = {}
    pack.box = newDrawing("Square", { Thickness = 1, Filled = false, Visible = false, ZIndex = 2 })
    pack.boxOutline = newDrawing("Square", { Thickness = 3, Filled = false, Visible = false, Color = Color3.new(0,0,0), ZIndex = 1 })
    pack.filled = newDrawing("Square", { Filled = true, Visible = false, ZIndex = 0 })
    pack.name = newDrawing("Text", { Size = 14, Center = true, Outline = true, Visible = false, ZIndex = 3 })
    pack.healthBarBg = newDrawing("Square", { Filled = true, Color = Color3.new(0,0,0), Visible = false, ZIndex = 1 })
    pack.healthBar = newDrawing("Square", { Filled = true, Visible = false, ZIndex = 2 })
    pack.healthNum = newDrawing("Text", { Size = 12, Center = true, Outline = true, Visible = false, ZIndex = 3 })
    pack.dist = newDrawing("Text", { Size = 13, Center = true, Outline = true, Visible = false, ZIndex = 3 })
    pack.weapon = newDrawing("Text", { Size = 12, Center = true, Outline = true, Visible = false, ZIndex = 3 })
    pack.rank = newDrawing("Text", { Size = 12, Center = true, Outline = true, Visible = false, ZIndex = 3 })
    pack.tracer = newDrawing("Line", { Thickness = 1, Visible = false, ZIndex = 2 })
    pack.tracerOutline = newDrawing("Line", { Thickness = 3, Visible = false, Color = Color3.new(0,0,0), ZIndex = 1 })
    pack.headMarker = newDrawing("Square", { Thickness = 1, Filled = false, Visible = false, ZIndex = 3 })
    pack.skeleton = {}
    for i = 1, #SKELETON_BONES do pack.skeleton[i] = newDrawing("Line", { Thickness = 1, Visible = false, ZIndex = 2 }) end
    ESP.objects[player] = pack
end

local function getSideConfig(player)
    local cfg = Config.Data.ESP
    if isTeammate(player) then return cfg.Team, "Team" end
    return cfg.Enemy, "Enemy"
end

local function updateESP()
    local rootCfg = Config.Data.ESP
    if not rootCfg.Enabled then
        for player in pairs(ESP.objects) do clearPlayerESP(player) end
        for player, hl in pairs(ESP.highlights) do pcall(function() hl:Destroy() end); ESP.highlights[player] = nil end
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then clearPlayerESP(player); continue end
        if not isAlive(player) then clearPlayerESP(player); continue end
        local side, sideName = getSideConfig(player)
        if not side or not side.Enabled then clearPlayerESP(player); continue end
        if rootCfg.TeamCheck and isTeammate(player) then clearPlayerESP(player); continue end

        local root, hum, char = getRoot(player), getHumanoid(player), getCharacter(player)
        if not root or not hum or not char then clearPlayerESP(player); continue end
        local dist = (root.Position - camPos).Magnitude
        if dist > (rootCfg.MaxDistance or 1500) then clearPlayerESP(player); continue end

        createPlayerESP(player)
        local pack = ESP.objects[player]
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local anyOnScreen = false
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                local sp, on = worldToScreen(part.Position)
                if on then
                    anyOnScreen = true
                    minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y)
                    maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y)
                end
            end
        end
        if not anyOnScreen then
            for k, d in pairs(pack) do
                if k == "skeleton" then for _, sd in pairs(d) do pcall(function() sd.Visible = false end) end
                elseif typeof(d) ~= "Instance" then pcall(function() d.Visible = false end) end
            end
            continue
        end
        local pad = 3
        minX, minY, maxX, maxY = minX-pad, minY-pad, maxX+pad, maxY+pad
        local w, h = maxX-minX, maxY-minY
        local fontSize = rootCfg.FontSize or 14

        if side.Box and side.Box.Enabled and pack.box then
            pack.box.Visible = true; pack.box.Color = side.Box.Color or Color3.new(1,1,1)
            pack.box.Size = Vector2.new(w,h); pack.box.Position = Vector2.new(minX,minY)
            if pack.boxOutline then pack.boxOutline.Visible = true; pack.boxOutline.Size = Vector2.new(w,h); pack.boxOutline.Position = Vector2.new(minX,minY) end
        else
            if pack.box then pack.box.Visible = false end
            if pack.boxOutline then pack.boxOutline.Visible = false end
        end

        if side.FilledBox and side.FilledBox.Enabled and pack.filled then
            pack.filled.Visible = true
            pack.filled.Color = side.FilledBox.Color or Color3.new(1,0,0)
            pack.filled.Transparency = side.FilledBox.Transparency or 0.7
            pack.filled.Size = Vector2.new(w,h); pack.filled.Position = Vector2.new(minX,minY)
        else if pack.filled then pack.filled.Visible = false end end

        if side.Name and side.Name.Enabled and pack.name then
            local display = formatText(rootCfg.UseDisplayName and player.DisplayName or player.Name, rootCfg.TextCase, rootCfg.TextSurround)
            pack.name.Visible = true; pack.name.Text = display
            pack.name.Color = side.Name.Color or Color3.new(1,1,1); pack.name.Size = fontSize
            pack.name.Position = Vector2.new(minX + w/2, minY - fontSize - 2)
        else if pack.name then pack.name.Visible = false end end

        if side.HealthBar and side.HealthBar.Enabled and pack.healthBar then
            local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            local barH = h * hp
            local col = side.HealthBar.Color or Color3.fromRGB(0,255,100)
            if side.HealthBar.ColorMode == "Reactive" then col = Color3.fromRGB(255*(1-hp), 255*hp, 40) end
            pack.healthBarBg.Visible = true; pack.healthBarBg.Size = Vector2.new(3,h); pack.healthBarBg.Position = Vector2.new(minX-6, minY)
            pack.healthBar.Visible = true; pack.healthBar.Color = col
            pack.healthBar.Size = Vector2.new(3, barH); pack.healthBar.Position = Vector2.new(minX-6, minY+(h-barH))
        else
            if pack.healthBar then pack.healthBar.Visible = false end
            if pack.healthBarBg then pack.healthBarBg.Visible = false end
        end

        if side.HealthNumber and side.HealthNumber.Enabled and pack.healthNum then
            pack.healthNum.Visible = true; pack.healthNum.Text = tostring(math.floor(hum.Health))
            pack.healthNum.Color = side.HealthNumber.Color or Color3.new(1,1,1)
            pack.healthNum.Size = rootCfg.FlagFontSize or 12
            pack.healthNum.Position = Vector2.new(minX-18, minY + h/2 - 6)
        else if pack.healthNum then pack.healthNum.Visible = false end end

        if side.Distance and side.Distance.Enabled and pack.dist then
            pack.dist.Visible = true; pack.dist.Text = string.format("%dm", math.floor(dist))
            pack.dist.Color = side.Distance.Color or Color3.fromRGB(200,200,200)
            pack.dist.Size = rootCfg.FlagFontSize or 12
            pack.dist.Position = Vector2.new(minX + w/2, maxY + 2)
        else if pack.dist then pack.dist.Visible = false end end

        if side.HeldWeapon and side.HeldWeapon.Enabled and pack.weapon then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                pack.weapon.Visible = true
                pack.weapon.Text = formatText(tool.Name, rootCfg.FlagTextCase, rootCfg.FlagTextSurround)
                pack.weapon.Color = side.HeldWeapon.Color or Color3.new(1,1,1)
                pack.weapon.Size = rootCfg.FlagFontSize or 12
                pack.weapon.Position = Vector2.new(minX + w/2, maxY + ((side.Distance and side.Distance.Enabled) and 14 or 2))
            else pack.weapon.Visible = false end
        else if pack.weapon then pack.weapon.Visible = false end end

        if side.Rank and side.Rank.Enabled and pack.rank then
            local rankText = (rootCfg.RankSpoof and rootCfg.RankSpoof.Enabled and rootCfg.RankSpoof.Text) or ""
            if rankText ~= "" then
                pack.rank.Visible = true
                pack.rank.Text = formatText(rankText, rootCfg.FlagTextCase, rootCfg.FlagTextSurround)
                pack.rank.Color = side.Rank.Color or Color3.fromRGB(255,215,0)
                pack.rank.Size = rootCfg.FlagFontSize or 12
                pack.rank.Position = Vector2.new(minX + w/2, minY - fontSize - 16)
            else pack.rank.Visible = false end
        else if pack.rank then pack.rank.Visible = false end end

        if side.Tracer and side.Tracer.Enabled and pack.tracer then
            local vp = cam.ViewportSize
            local origin = side.Tracer.Origin or "Bottom"
            local from = origin == "Bottom" and Vector2.new(vp.X/2, vp.Y)
                or origin == "Top" and Vector2.new(vp.X/2, 0)
                or origin == "Mouse" and UserInputService:GetMouseLocation()
                or Vector2.new(vp.X/2, vp.Y/2)
            local toY = (side.Tracer.Target == "Head") and minY or maxY
            pack.tracer.Visible = true; pack.tracer.Color = side.Tracer.Color or Color3.new(1,1,1)
            pack.tracer.Thickness = side.Tracer.Thickness or 1
            pack.tracer.From = from; pack.tracer.To = Vector2.new(minX + w/2, toY)
            if side.Tracer.Outline and pack.tracerOutline then
                pack.tracerOutline.Visible = true
                pack.tracerOutline.Thickness = side.Tracer.OutlineThickness or 3
                pack.tracerOutline.Color = side.Tracer.OutlineColor or Color3.new(0,0,0)
                pack.tracerOutline.From = from; pack.tracerOutline.To = Vector2.new(minX + w/2, toY)
            else if pack.tracerOutline then pack.tracerOutline.Visible = false end end
        else
            if pack.tracer then pack.tracer.Visible = false end
            if pack.tracerOutline then pack.tracerOutline.Visible = false end
        end

        if side.HeadMarker and side.HeadMarker.Enabled and pack.headMarker then
            local head = char:FindFirstChild("Head")
            if head then
                local sp, on = worldToScreen(head.Position)
                if on then
                    local s = 6
                    pack.headMarker.Visible = true
                    pack.headMarker.Color = side.HeadMarker.Color or Color3.new(1,0,0)
                    pack.headMarker.Filled = side.HeadMarker.Filled or false
                    pack.headMarker.Size = Vector2.new(s*2, s*2)
                    pack.headMarker.Position = Vector2.new(sp.X - s, sp.Y - s)
                else pack.headMarker.Visible = false end
            else pack.headMarker.Visible = false end
        else if pack.headMarker then pack.headMarker.Visible = false end end

        if side.Skeleton and side.Skeleton.Enabled and pack.skeleton then
            for i, bone in ipairs(SKELETON_BONES) do
                local a, b, line = char:FindFirstChild(bone[1]), char:FindFirstChild(bone[2]), pack.skeleton[i]
                if a and b and line then
                    local sa, oa = worldToScreen(a.Position)
                    local sb, ob = worldToScreen(b.Position)
                    if oa and ob then
                        line.Visible = true; line.From = sa; line.To = sb
                        line.Color = side.Skeleton.Color or Color3.new(1,1,1)
                        line.Thickness = side.Skeleton.Thickness or 1
                    else line.Visible = false end
                elseif line then line.Visible = false end
            end
        else if pack.skeleton then for _, line in pairs(pack.skeleton) do pcall(function() line.Visible = false end) end end end

        if side.Chams and side.Chams.Enabled then
            local hl = ESP.highlights[player]
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight")
                hl.Parent = hudParent(); hl.Adornee = char
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                ESP.highlights[player] = hl
            end
            hl.FillColor = side.Chams.InnerColor or Color3.fromRGB(255,70,70)
            hl.FillTransparency = side.Chams.InnerTransparency or 0.55
            hl.OutlineColor = side.Chams.OutlineColor or Color3.new(1,1,1)
            hl.OutlineTransparency = side.Chams.OutlineTransparency or 0
            hl.Enabled = true
        else
            local hl = ESP.highlights[player]
            if hl then hl.Enabled = false end
        end
    end
end
Players.PlayerRemoving:Connect(function(player) clearPlayerESP(player) end)

-- Aimbot / Silent / Trigger
local Aim = { target = nil, holding = false, silentHolding = false, triggerHolding = false, stickyTarget = nil }

local function getClosestToCursor(fov, teamCheck, maxDist, partName, sticky)
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    if sticky and Aim.stickyTarget and Aim.stickyTarget.Parent then
        local plr = Players:GetPlayerFromCharacter(Aim.stickyTarget.Parent)
        if plr and isAlive(plr) then
            local sp, on = worldToScreen(Aim.stickyTarget.Position)
            if on and (sp - UserInputService:GetMouseLocation()).Magnitude <= fov * 1.5 then return Aim.stickyTarget end
        end
    end
    local mouse = UserInputService:GetMouseLocation()
    local best, bestDist = nil, fov
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isAlive(player) then continue end
        if teamCheck and isTeammate(player) then continue end
        local char = getCharacter(player)
        local part = char and char:FindFirstChild(partName or "Head") or getRoot(player)
        if not part then continue end
        if (part.Position - cam.CFrame.Position).Magnitude > (maxDist or 1000) then continue end
        local screen, on = worldToScreen(part.Position)
        if not on then continue end
        local d = (screen - mouse).Magnitude
        if d < bestDist then bestDist = d; best = part end
    end
    if sticky then Aim.stickyTarget = best end
    return best
end

local function aimbotStep()
    local cfg = Config.Data.Aimbot
    if not cfg.Enabled then return end
    if not (cfg.Mode == "Always" or Aim.holding) then return end
    local target = getClosestToCursor(cfg.FOV, cfg.TeamCheck, cfg.MaxDistance, cfg.TargetPart, cfg.Sticky)
    Aim.target = target
    if not target then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vel = target.AssemblyLinearVelocity or Vector3.zero
    local pred = target.Position + vel * (cfg.Prediction or 0)
    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, pred), math.clamp(cfg.Smoothness or 0.22, 0.01, 1))
end

local silentTargetPart = nil
local function silentStep()
    local cfg = Config.Data.SilentAim
    if not cfg.Enabled then silentTargetPart = nil; return end
    if not (cfg.Mode == "Always" or Aim.silentHolding) then silentTargetPart = nil; return end
    if math.random(1,100) > (cfg.HitChance or 100) then silentTargetPart = nil; return end
    silentTargetPart = getClosestToCursor(cfg.FOV, cfg.TeamCheck, cfg.MaxDistance, cfg.TargetPart, false)
end

local function triggerStep()
    local cfg = Config.Data.TriggerBot
    if not cfg.Enabled then return end
    if not (cfg.Mode == "Always" or Aim.triggerHolding) then return end
    local target = getClosestToCursor(40, cfg.TeamCheck, cfg.MaxDistance, "Head", false)
    if target then
        task.wait(cfg.Delay or 0.02)
        pcall(function()
            if mouse1click then mouse1click() end
        end)
    end
end

local function updateFOVCircles()
    local mouse = UserInputService:GetMouseLocation()
    local ac = Config.Data.Aimbot
    if AimFOVCircle then
        AimFOVCircle.Visible = ac.Enabled and ac.ShowFOV
        AimFOVCircle.Position = mouse
        AimFOVCircle.Radius = ac.FOV or 120
        AimFOVCircle.Color = ac.FOVColor or Color3.new(1,1,1)
    end
    local sc = Config.Data.SilentAim
    if SilentFOVCircle then
        SilentFOVCircle.Visible = sc.Enabled and sc.ShowFOV
        SilentFOVCircle.Position = mouse
        SilentFOVCircle.Radius = sc.FOV or 90
        SilentFOVCircle.Color = sc.FOVColor or Color3.fromRGB(0,255,140)
    end
end

-- Movement
local Movement = { flyConn = nil, noclipConn = nil, bodyVel = nil, bodyGyro = nil }

local function setFly(on)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    if Movement.bodyVel then pcall(function() Movement.bodyVel:Destroy() end); Movement.bodyVel = nil end
    if Movement.bodyGyro then pcall(function() Movement.bodyGyro:Destroy() end); Movement.bodyGyro = nil end
    if Movement.flyConn then Movement.flyConn:Disconnect(); Movement.flyConn = nil end
    if not on then hum.PlatformStand = false; return end
    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(1e5,1e5,1e5); bv.Velocity = Vector3.zero; bv.Parent = root; Movement.bodyVel = bv
    local bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(1e5,1e5,1e5); bg.P = 3e3; bg.Parent = root; Movement.bodyGyro = bg
    Movement.flyConn = RunService.RenderStepped:Connect(function()
        if not Config.Data.Movement.Fly.Enabled then return end
        local cam = workspace.CurrentCamera
        if not cam or not root.Parent then return end
        local speed = Config.Data.Movement.Fly.Speed or 45
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        if dir.Magnitude > 0 then dir = dir.Unit * speed end
        bv.Velocity = dir; bg.CFrame = cam.CFrame
    end)
end

local function setNoclip(on)
    if Movement.noclipConn then Movement.noclipConn:Disconnect(); Movement.noclipConn = nil end
    if not on then return end
    Movement.noclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

local function applySpeed()
    local cfg = Config.Data.Movement.Speed
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and cfg.Enabled then hum.WalkSpeed = cfg.Value or 28 end
end

local function applyJumpPower()
    local cfg = Config.Data.Movement.JumpPower
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and cfg.Enabled then
        pcall(function() hum.JumpPower = cfg.Value or 50 end)
        pcall(function() hum.JumpHeight = (cfg.Value or 50) / 3 end)
    end
end

-- Movement Recorder
local Recorder = { recording = false, replaying = false, frames = {}, startClock = 0, replayIndex = 1, replayStart = 0, mapName = "unknown" }
local function recorderPath(name) return "always.winning/movement_recorder/" .. name .. ".json" end
function Recorder:StartRecord()
    if self.replaying then return false end
    self.recording = true; self.frames = {}; self.startClock = os.clock(); self.mapName = tostring(game.PlaceId)
    return true
end
function Recorder:StopRecord() self.recording = false; return self.frames end
function Recorder:CaptureFrame()
    if not self.recording then return end
    local root = getRoot(LocalPlayer); local hum = getHumanoid(LocalPlayer)
    if not root or not hum then return end
    table.insert(self.frames, {
        t = os.clock() - self.startClock,
        cf = { root.CFrame:GetComponents() },
        vel = { root.AssemblyLinearVelocity.X, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z },
        jump = hum.Jump,
    })
end
function Recorder:Save(name)
    if not writefile or #self.frames == 0 then return false end
    pcall(writefile, recorderPath(name), HttpService:JSONEncode({ MapName = self.mapName, Name = name, Frames = self.frames, Version = 1 }))
    return true
end
function Recorder:Load(name)
    if not readfile or not isfile or not isfile(recorderPath(name)) then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(recorderPath(name))) end)
    return ok and data or nil
end
function Recorder:List()
    if not listfiles then return {} end
    local out = {}
    pcall(function()
        for _, f in ipairs(listfiles("always.winning/movement_recorder")) do
            local name = f:match("([^/\\]+)%.json$")
            if name then table.insert(out, name) end
        end
    end)
    return out
end
function Recorder:StartReplay(data)
    if self.recording or not data or not data.Frames then return false end
    self.replaying = true; self.frames = data.Frames; self.replayIndex = 1; self.replayStart = os.clock()
    return true
end
function Recorder:StopReplay() self.replaying = false end
function Recorder:Update()
    if self.recording then self:CaptureFrame() end
    if self.replaying and self.frames then
        local elapsed = os.clock() - self.replayStart
        local root = getRoot(LocalPlayer)
        if not root then return end
        while self.replayIndex < #self.frames and self.frames[self.replayIndex].t < elapsed do self.replayIndex += 1 end
        local frame = self.frames[math.min(self.replayIndex, #self.frames)]
        if frame and frame.cf then root.CFrame = CFrame.new(unpack(frame.cf)) end
        if self.replayIndex >= #self.frames then self:StopReplay() end
    end
end

-- Visuals
local VisualState = {}
local function applyFullBright(on)
    if on then
        VisualState.oldAmbient = Lighting.Ambient; VisualState.oldBrightness = Lighting.Brightness
        Lighting.Ambient = Color3.new(1,1,1); Lighting.Brightness = 2; Lighting.GlobalShadows = false
    else
        if VisualState.oldAmbient then Lighting.Ambient = VisualState.oldAmbient end
        if VisualState.oldBrightness then Lighting.Brightness = VisualState.oldBrightness end
        Lighting.GlobalShadows = true
    end
end
local function applyNoFog(on)
    if on then VisualState.oldFog = Lighting.FogEnd; Lighting.FogEnd = 1e6
    else if VisualState.oldFog then Lighting.FogEnd = VisualState.oldFog end end
end
local function applyFOV()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local cfg = Config.Data.Visuals
    if cfg.FOVEnabled then
        if not VisualState.oldFOV then VisualState.oldFOV = cam.FieldOfView end
        cam.FieldOfView = cfg.FOV or 70
    elseif VisualState.oldFOV then cam.FieldOfView = VisualState.oldFOV; VisualState.oldFOV = nil end
end
local function applyForceTime()
    local cfg = Config.Data.Visuals.World
    if cfg.ForceTime then
        if not VisualState.oldClock then VisualState.oldClock = Lighting.ClockTime end
        Lighting.ClockTime = cfg.ClockTime or 14
    elseif VisualState.oldClock then Lighting.ClockTime = VisualState.oldClock; VisualState.oldClock = nil end
end

local Crosshair = { lines = {} }
local function rebuildCrosshair()
    for _, l in ipairs(Crosshair.lines) do pcall(function() l:Remove() end) end
    table.clear(Crosshair.lines)
    if not Config.Data.Visuals.Crosshair.Enabled then return end
    for i = 1, 4 do
        table.insert(Crosshair.lines, newDrawing("Line", {
            Thickness = Config.Data.Visuals.Crosshair.Thickness or 1,
            Color = Config.Data.Visuals.Crosshair.Color or Color3.fromRGB(0,255,140),
            Visible = true, ZIndex = 10,
        }))
    end
end
local function updateCrosshair()
    local cfg = Config.Data.Visuals.Crosshair
    if not cfg.Enabled or #Crosshair.lines < 4 then return end
    local pos = UserInputService:GetMouseLocation()
    local s, g, t = cfg.Size or 8, cfg.Gap or 4, cfg.Thickness or 1
    local col = cfg.Color or Color3.fromRGB(0,255,140)
    local L = Crosshair.lines
    L[1].From = Vector2.new(pos.X, pos.Y-g-s); L[1].To = Vector2.new(pos.X, pos.Y-g)
    L[2].From = Vector2.new(pos.X, pos.Y+g); L[2].To = Vector2.new(pos.X, pos.Y+g+s)
    L[3].From = Vector2.new(pos.X-g-s, pos.Y); L[3].To = Vector2.new(pos.X-g, pos.Y)
    L[4].From = Vector2.new(pos.X+g, pos.Y); L[4].To = Vector2.new(pos.X+g+s, pos.Y)
    for _, l in ipairs(L) do l.Color = col; l.Thickness = t; l.Visible = true end
end

-- Hit sound
local function playHitSound()
    local cfg = Config.Data.Misc
    if not cfg.HitSound then return end
    local s = Instance.new("Sound")
    s.SoundId = cfg.HitSoundId ~= "" and cfg.HitSoundId or "rbxassetid://12222216"
    s.Volume = cfg.HitSoundVolume or 1
    s.Parent = SoundService
    s:Play()
    s.Ended:Once(function() s:Destroy() end)
end

-- Anti AFK / Watermark
local antiAfkConn
local function setAntiAFK(on)
    if antiAfkConn then antiAfkConn:Disconnect(); antiAfkConn = nil end
    if not on then return end
    antiAfkConn = LocalPlayer.Idled:Connect(function()
        local vu = game:GetService("VirtualUser")
        pcall(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)
    end)
end
local Watermark = { text = nil }
local function ensureWatermark()
    if Watermark.text then return end
    Watermark.text = newDrawing("Text", {
        Text = "always.winning", Size = 16, Outline = true,
        Color = Color3.fromRGB(0,255,160), Position = Vector2.new(12,10), Visible = true, ZIndex = 20,
    })
end
local function updateWatermark()
    if not Config.Data.Misc.Watermark then if Watermark.text then Watermark.text.Visible = false end; return end
    ensureWatermark()
    Watermark.text.Visible = true
    Watermark.text.Text = string.format("always.winning  |  %s  |  %d players", LocalPlayer.Name, #Players:GetPlayers())
end

-- Loops
local lastSpeedApply = 0
GlobalTrove:Add(RunService.RenderStepped:Connect(function()
    if AW.destroyed then return end
    updateESP(); aimbotStep(); silentStep(); triggerStep()
    updateCrosshair(); updateFOVCircles(); applyFOV(); applyForceTime(); Recorder:Update()
    if os.clock() - lastSpeedApply > 0.4 then
        lastSpeedApply = os.clock(); applySpeed(); applyJumpPower()
    end
end))
GlobalTrove:Add(RunService.Heartbeat:Connect(function()
    if AW.destroyed then return end
    updateWatermark()
end))

-- Input
local function keyMatches(input, keyName)
    if not keyName or keyName == "" or keyName == "None" then return false end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and keyName == "MouseButton1" then return true end
    if input.UserInputType == Enum.UserInputType.MouseButton2 and keyName == "MouseButton2" then return true end
    if input.UserInputType == Enum.UserInputType.MouseButton3 and keyName == "MouseButton3" then return true end
    if input.KeyCode and input.KeyCode.Name == keyName then return true end
    return false
end
GlobalTrove:Add(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local aimCfg = Config.Data.Aimbot
    if keyMatches(input, aimCfg.Key) then
        if aimCfg.Mode == "Toggle" then Aim.holding = not Aim.holding else Aim.holding = true end
    end
    local silentCfg = Config.Data.SilentAim
    if keyMatches(input, silentCfg.Key) then
        if silentCfg.Mode == "Toggle" then Aim.silentHolding = not Aim.silentHolding else Aim.silentHolding = true end
    end
    local trigCfg = Config.Data.TriggerBot
    if keyMatches(input, trigCfg.Key) then
        if trigCfg.Mode == "Toggle" then Aim.triggerHolding = not Aim.triggerHolding else Aim.triggerHolding = true end
    end
    local flyCfg = Config.Data.Movement.Fly
    if keyMatches(input, flyCfg.Key) then
        flyCfg.Enabled = not flyCfg.Enabled
        Config:Set({"Movement","Fly","Enabled"}, flyCfg.Enabled)
        setFly(flyCfg.Enabled)
    end
    local ncCfg = Config.Data.Movement.NoClip
    if keyMatches(input, ncCfg.Key) then
        ncCfg.Enabled = not ncCfg.Enabled
        Config:Set({"Movement","NoClip","Enabled"}, ncCfg.Enabled)
        setNoclip(ncCfg.Enabled)
    end
end))
GlobalTrove:Add(UserInputService.InputEnded:Connect(function(input)
    if Config.Data.Aimbot.Mode == "Hold" and keyMatches(input, Config.Data.Aimbot.Key) then Aim.holding = false end
    if Config.Data.SilentAim.Mode == "Hold" and keyMatches(input, Config.Data.SilentAim.Key) then Aim.silentHolding = false end
    if Config.Data.TriggerBot.Mode == "Hold" and keyMatches(input, Config.Data.TriggerBot.Key) then Aim.triggerHolding = false end
end))
GlobalTrove:Add(UserInputService.JumpRequest:Connect(function()
    if not Config.Data.Movement.InfiniteJump then return end
    local hum = getHumanoid(LocalPlayer)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

local function onCharacter(char)
    task.wait(0.25)
    if Config.Data.Movement.Speed.Enabled then applySpeed() end
    if Config.Data.Movement.Fly.Enabled then setFly(true) end
    if Config.Data.Movement.NoClip.Enabled then setNoclip(true) end
    if Config.Data.Movement.JumpPower.Enabled then applyJumpPower() end
end
if LocalPlayer.Character then task.spawn(onCharacter, LocalPlayer.Character) end
GlobalTrove:Add(LocalPlayer.CharacterAdded:Connect(onCharacter))

function AW.Unload()
    if AW.destroyed then return end
    AW.destroyed = true
    setFly(false); setNoclip(false); applyFullBright(false); applyNoFog(false)
    Recorder:StopRecord(); Recorder:StopReplay()
    for player in pairs(ESP.objects) do clearPlayerESP(player) end
    for player, hl in pairs(ESP.highlights) do pcall(function() hl:Destroy() end) end
    for _, d in ipairs(Drawings) do pcall(function() d:Remove() end) end
    table.clear(Drawings)
    for _, f in ipairs(AW.cleanups) do pcall(f) end
    pcall(function() GlobalTrove:Destroy() end)
    if getgenv().AlwaysWinning == AW then getgenv().AlwaysWinning = nil end
    print("[always.winning] unloaded")
end

--==========================================================================
--  OBSIDIAN — EVERY TAB
--==========================================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "always.winning",
    Footer = "rivals · full",
    ToggleKeybind = Enum.KeyCode.RightShift,
    Center = true, AutoShow = true,
    Size = UDim2.fromOffset(780, 620),
})

local Tabs = {
    Combat    = Window:AddTab("Combat", "sword"),
    Visuals   = Window:AddTab("Visuals", "eye"),
    ESP       = Window:AddTab("ESP", "users"),
    Movement  = Window:AddTab("Movement", "run"),
    Player    = Window:AddTab("Player", "user"),
    Cosmetics = Window:AddTab("Cosmetics", "sparkles"),
    World     = Window:AddTab("World", "globe"),
    Misc      = Window:AddTab("Misc", "settings"),
    Settings  = Window:AddTab("Settings", "cog"),
}

-- COMBAT
local AimbotBox = Tabs.Combat:AddLeftGroupbox("Aimbot")
local SilentBox = Tabs.Combat:AddRightGroupbox("Silent Aim")
local TriggerBox = Tabs.Combat:AddRightGroupbox("Trigger Bot")

AimbotBox:AddToggle("AimbotEnabled", { Text = "Enabled", Default = false, Callback = function(v) Config:Set({"Aimbot","Enabled"}, v) end })
AimbotBox:AddDropdown("AimbotMode", { Values = {"Always","Toggle","Hold"}, Default = "Toggle", Text = "Mode", Callback = function(v) Config:Set({"Aimbot","Mode"}, v); Aim.holding = false end })
AimbotBox:AddSlider("AimbotFOV", { Text = "FOV", Default = 120, Min = 10, Max = 400, Rounding = 0, Callback = function(v) Config:Set({"Aimbot","FOV"}, v) end })
AimbotBox:AddSlider("AimbotSmooth", { Text = "Smoothness", Default = 0.22, Min = 0.01, Max = 1, Rounding = 2, Callback = function(v) Config:Set({"Aimbot","Smoothness"}, v) end })
AimbotBox:AddSlider("AimbotPredict", { Text = "Prediction", Default = 0.12, Min = 0, Max = 0.5, Rounding = 2, Callback = function(v) Config:Set({"Aimbot","Prediction"}, v) end })
AimbotBox:AddDropdown("AimbotPart", { Values = {"Head","HumanoidRootPart","UpperTorso","LowerTorso"}, Default = "Head", Text = "Target Part", Callback = function(v) Config:Set({"Aimbot","TargetPart"}, v) end })
AimbotBox:AddToggle("AimbotTeam", { Text = "Team Check", Default = true, Callback = function(v) Config:Set({"Aimbot","TeamCheck"}, v) end })
AimbotBox:AddToggle("AimbotSticky", { Text = "Sticky Target", Default = false, Callback = function(v) Config:Set({"Aimbot","Sticky"}, v) end })
AimbotBox:AddToggle("AimbotShowFOV", { Text = "Show FOV", Default = false, Callback = function(v) Config:Set({"Aimbot","ShowFOV"}, v) end })
AimbotBox:AddSlider("AimbotDist", { Text = "Max Distance", Default = 900, Min = 50, Max = 2000, Rounding = 0, Callback = function(v) Config:Set({"Aimbot","MaxDistance"}, v) end })
AimbotBox:AddLabel("FOV Color"):AddColorPicker("AimbotFOVColor", { Default = Color3.fromRGB(255,255,255), Callback = function(v) Config:Set({"Aimbot","FOVColor"}, v) end })

SilentBox:AddToggle("SilentEnabled", { Text = "Enabled", Default = false, Callback = function(v) Config:Set({"SilentAim","Enabled"}, v) end })
SilentBox:AddDropdown("SilentMode", { Values = {"Always","Toggle","Hold"}, Default = "Always", Text = "Mode", Callback = function(v) Config:Set({"SilentAim","Mode"}, v); Aim.silentHolding = false end })
SilentBox:AddSlider("SilentFOV", { Text = "FOV", Default = 90, Min = 10, Max = 400, Rounding = 0, Callback = function(v) Config:Set({"SilentAim","FOV"}, v) end })
SilentBox:AddSlider("SilentHitChance", { Text = "Hit Chance", Default = 100, Min = 1, Max = 100, Rounding = 0, Callback = function(v) Config:Set({"SilentAim","HitChance"}, v) end })
SilentBox:AddSlider("SilentPredict", { Text = "Prediction", Default = 0.1, Min = 0, Max = 0.5, Rounding = 2, Callback = function(v) Config:Set({"SilentAim","Prediction"}, v) end })
SilentBox:AddDropdown("SilentPart", { Values = {"Head","HumanoidRootPart","UpperTorso"}, Default = "Head", Text = "Target Part", Callback = function(v) Config:Set({"SilentAim","TargetPart"}, v) end })
SilentBox:AddToggle("SilentTeam", { Text = "Team Check", Default = true, Callback = function(v) Config:Set({"SilentAim","TeamCheck"}, v) end })
SilentBox:AddToggle("SilentShowFOV", { Text = "Show FOV", Default = false, Callback = function(v) Config:Set({"SilentAim","ShowFOV"}, v) end })
SilentBox:AddSlider("SilentDist", { Text = "Max Distance", Default = 1000, Min = 50, Max = 2000, Rounding = 0, Callback = function(v) Config:Set({"SilentAim","MaxDistance"}, v) end })

TriggerBox:AddToggle("TriggerEnabled", { Text = "Enabled", Default = false, Callback = function(v) Config:Set({"TriggerBot","Enabled"}, v) end })
TriggerBox:AddDropdown("TriggerMode", { Values = {"Always","Toggle","Hold"}, Default = "Hold", Text = "Mode", Callback = function(v) Config:Set({"TriggerBot","Mode"}, v); Aim.triggerHolding = false end })
TriggerBox:AddSlider("TriggerDelay", { Text = "Delay", Default = 0.02, Min = 0, Max = 0.3, Rounding = 2, Callback = function(v) Config:Set({"TriggerBot","Delay"}, v) end })
TriggerBox:AddToggle("TriggerTeam", { Text = "Team Check", Default = true, Callback = function(v) Config:Set({"TriggerBot","TeamCheck"}, v) end })
TriggerBox:AddSlider("TriggerDist", { Text = "Max Distance", Default = 400, Min = 50, Max = 1000, Rounding = 0, Callback = function(v) Config:Set({"TriggerBot","MaxDistance"}, v) end })

-- VISUALS (world + crosshair)
local WorldVis = Tabs.Visuals:AddLeftGroupbox("World")
local CrossBox = Tabs.Visuals:AddRightGroupbox("Crosshair")
WorldVis:AddToggle("FullBright", { Text = "Full Bright", Default = false, Callback = function(v) Config:Set({"Visuals","FullBright"}, v); applyFullBright(v) end })
WorldVis:AddToggle("NoFog", { Text = "No Fog", Default = false, Callback = function(v) Config:Set({"Visuals","NoFog"}, v); applyNoFog(v) end })
WorldVis:AddToggle("FOVEnabled", { Text = "Custom FOV", Default = false, Callback = function(v) Config:Set({"Visuals","FOVEnabled"}, v); applyFOV() end })
WorldVis:AddSlider("WorldFOV", { Text = "FOV Value", Default = 70, Min = 50, Max = 120, Rounding = 0, Callback = function(v) Config:Set({"Visuals","FOV"}, v); applyFOV() end })
WorldVis:AddToggle("ForceTime", { Text = "Force Clock Time", Default = false, Callback = function(v) Config:Set({"Visuals","World","ForceTime"}, v); applyForceTime() end })
WorldVis:AddSlider("ClockTime", { Text = "Clock Time", Default = 14, Min = 0, Max = 24, Rounding = 1, Callback = function(v) Config:Set({"Visuals","World","ClockTime"}, v); applyForceTime() end })

CrossBox:AddToggle("CrosshairEnabled", { Text = "Enabled", Default = false, Callback = function(v) Config:Set({"Visuals","Crosshair","Enabled"}, v); rebuildCrosshair() end })
CrossBox:AddSlider("CrosshairSize", { Text = "Size", Default = 8, Min = 2, Max = 30, Rounding = 0, Callback = function(v) Config:Set({"Visuals","Crosshair","Size"}, v) end })
CrossBox:AddSlider("CrosshairGap", { Text = "Gap", Default = 4, Min = 0, Max = 20, Rounding = 0, Callback = function(v) Config:Set({"Visuals","Crosshair","Gap"}, v) end })
CrossBox:AddSlider("CrosshairThick", { Text = "Thickness", Default = 1, Min = 1, Max = 5, Rounding = 0, Callback = function(v) Config:Set({"Visuals","Crosshair","Thickness"}, v) end })
CrossBox:AddLabel("Color"):AddColorPicker("CrosshairColor", { Default = Color3.fromRGB(0,255,140), Callback = function(v) Config:Set({"Visuals","Crosshair","Color"}, v) end })

-- ESP TAB
local ESPMain = Tabs.ESP:AddLeftGroupbox("ESP Main")
local ESPEnemy = Tabs.ESP:AddLeftGroupbox("Enemy")
local ESPTeam = Tabs.ESP:AddRightGroupbox("Team")
local ESPExtra = Tabs.ESP:AddRightGroupbox("Extra / Spoof")

ESPMain:AddToggle("ESPEnabled", { Text = "Enable ESP", Default = false, Callback = function(v)
    Config:Set({"ESP","Enabled"}, v)
    if not v then for p in pairs(ESP.objects) do clearPlayerESP(p) end end
end })
ESPMain:AddToggle("ESPTeamCheck", { Text = "Team Check", Default = false, Callback = function(v) Config:Set({"ESP","TeamCheck"}, v) end })
ESPMain:AddToggle("ESPDisplayName", { Text = "Use Display Names", Default = true, Callback = function(v) Config:Set({"ESP","UseDisplayName"}, v) end })
ESPMain:AddSlider("ESPFontSize", { Text = "Font Size", Default = 14, Min = 10, Max = 24, Rounding = 0, Callback = function(v) Config:Set({"ESP","FontSize"}, v) end })
ESPMain:AddSlider("ESPMaxDist", { Text = "Max Distance", Default = 1500, Min = 100, Max = 3000, Rounding = 0, Callback = function(v) Config:Set({"ESP","MaxDistance"}, v) end })
ESPMain:AddDropdown("ESPTextCase", { Values = {"Standard","UPPERCASE","lowercase"}, Default = "Standard", Text = "Text Case", Callback = function(v) Config:Set({"ESP","TextCase"}, v) end })
ESPMain:AddDropdown("ESPTextSurround", { Values = {"None","[]","()","<>","{}"}, Default = "None", Text = "Text Surround", Callback = function(v) Config:Set({"ESP","TextSurround"}, v) end })

local function bindSide(box, sideKey)
    local side = Config.Data.ESP[sideKey]
    box:AddToggle(sideKey.."Enabled", { Text = "Enable", Default = side.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"Enabled"}, v) end })
    box:AddToggle(sideKey.."Box", { Text = "Box", Default = side.Box.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"Box","Enabled"}, v) end })
    box:AddDropdown(sideKey.."BoxStyle", { Values = {"Full","Corner"}, Default = side.Box.Style, Text = "Box Style", Callback = function(v) Config:Set({"ESP",sideKey,"Box","Style"}, v) end })
    box:AddToggle(sideKey.."Filled", { Text = "Filled Box", Default = side.FilledBox.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"FilledBox","Enabled"}, v) end })
    box:AddToggle(sideKey.."Name", { Text = "Name", Default = side.Name.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"Name","Enabled"}, v) end })
    box:AddToggle(sideKey.."HP", { Text = "Health Bar", Default = side.HealthBar.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"HealthBar","Enabled"}, v) end })
    box:AddDropdown(sideKey.."HPMode", { Values = {"Solid","Gradient","Reactive"}, Default = side.HealthBar.ColorMode, Text = "HP Color Mode", Callback = function(v) Config:Set({"ESP",sideKey,"HealthBar","ColorMode"}, v) end })
    box:AddToggle(sideKey.."HPNum", { Text = "Health Number", Default = side.HealthNumber.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"HealthNumber","Enabled"}, v) end })
    box:AddToggle(sideKey.."Dist", { Text = "Distance", Default = side.Distance.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"Distance","Enabled"}, v) end })
    box:AddToggle(sideKey.."Weapon", { Text = "Held Weapon", Default = side.HeldWeapon.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"HeldWeapon","Enabled"}, v) end })
    box:AddToggle(sideKey.."Tracer", { Text = "Tracer", Default = side.Tracer.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"Tracer","Enabled"}, v) end })
    box:AddDropdown(sideKey.."TracerOrigin", { Values = {"Bottom","Center","Top","Mouse"}, Default = side.Tracer.Origin, Text = "Tracer Origin", Callback = function(v) Config:Set({"ESP",sideKey,"Tracer","Origin"}, v) end })
    box:AddToggle(sideKey.."Skeleton", { Text = "Skeleton", Default = side.Skeleton.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"Skeleton","Enabled"}, v) end })
    box:AddToggle(sideKey.."Chams", { Text = "Chams", Default = side.Chams.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"Chams","Enabled"}, v) end })
    box:AddDropdown(sideKey.."ChamsKind", { Values = {"Highlight","Legacy"}, Default = side.Chams.Kind, Text = "Chams Kind", Callback = function(v) Config:Set({"ESP",sideKey,"Chams","Kind"}, v) end })
    box:AddToggle(sideKey.."HeadMarker", { Text = "Head Marker", Default = side.HeadMarker.Enabled, Callback = function(v) Config:Set({"ESP",sideKey,"HeadMarker","Enabled"}, v) end })
    box:AddLabel(sideKey.." Color"):AddColorPicker(sideKey.."Color", { Default = side.Box.Color, Callback = function(v)
        Config:Set({"ESP",sideKey,"Box","Color"}, v)
        Config:Set({"ESP",sideKey,"Name","Color"}, v)
    end })
end
bindSide(ESPEnemy, "Enemy")
bindSide(ESPTeam, "Team")

ESPExtra:AddToggle("RankSpoof", { Text = "Rank Spoof", Default = false, Callback = function(v) Config:Set({"ESP","RankSpoof","Enabled"}, v) end })
ESPExtra:AddInput("RankSpoofText", { Default = "Owner", Numeric = false, Finished = true, Text = "Rank Text", Callback = function(v) Config:Set({"ESP","RankSpoof","Text"}, v) end })
ESPExtra:AddToggle("EnemyRank", { Text = "Show Rank Flag", Default = false, Callback = function(v) Config:Set({"ESP","Enemy","Rank","Enabled"}, v) end })
ESPExtra:AddToggle("EnemyWinstreak", { Text = "Win Streak Flag", Default = false, Callback = function(v) Config:Set({"ESP","Enemy","Winstreak","Enabled"}, v) end })
ESPExtra:AddToggle("EnemyDeflect", { Text = "Deflecting Flag", Default = true, Callback = function(v) Config:Set({"ESP","Enemy","Deflecting","Enabled"}, v) end })

-- MOVEMENT
local SpeedBox = Tabs.Movement:AddLeftGroupbox("Speed")
local FlyBox = Tabs.Movement:AddLeftGroupbox("Fly")
local MiscMove = Tabs.Movement:AddRightGroupbox("Misc Movement")
local RecBox = Tabs.Movement:AddRightGroupbox("Movement Recorder")

SpeedBox:AddToggle("SpeedEnabled", { Text = "Enabled", Default = false, Callback = function(v) Config:Set({"Movement","Speed","Enabled"}, v); applySpeed() end })
SpeedBox:AddSlider("SpeedValue", { Text = "WalkSpeed", Default = 28, Min = 16, Max = 200, Rounding = 0, Callback = function(v) Config:Set({"Movement","Speed","Value"}, v); applySpeed() end })
FlyBox:AddToggle("FlyEnabled", { Text = "Enabled", Default = false, Callback = function(v) Config:Set({"Movement","Fly","Enabled"}, v); setFly(v) end })
FlyBox:AddSlider("FlySpeed", { Text = "Fly Speed", Default = 45, Min = 10, Max = 200, Rounding = 0, Callback = function(v) Config:Set({"Movement","Fly","Speed"}, v) end })
MiscMove:AddToggle("NoClip", { Text = "NoClip", Default = false, Callback = function(v) Config:Set({"Movement","NoClip","Enabled"}, v); setNoclip(v) end })
MiscMove:AddToggle("InfJump", { Text = "Infinite Jump", Default = false, Callback = function(v) Config:Set({"Movement","InfiniteJump"}, v) end })
MiscMove:AddToggle("BHop", { Text = "Bunny Hop", Default = false, Callback = function(v) Config:Set({"Movement","BunnyHop"}, v) end })
MiscMove:AddToggle("JumpPowerEn", { Text = "Jump Power", Default = false, Callback = function(v) Config:Set({"Movement","JumpPower","Enabled"}, v); applyJumpPower() end })
MiscMove:AddSlider("JumpPowerVal", { Text = "Jump Power Value", Default = 50, Min = 20, Max = 200, Rounding = 0, Callback = function(v) Config:Set({"Movement","JumpPower","Value"}, v); applyJumpPower() end })

RecBox:AddToggle("RecEnabled", { Text = "Enable Recorder", Default = false, Callback = function(v) Config:Set({"Movement","MovementRecorder","Enabled"}, v) end })
RecBox:AddButton("Start Recording", function() if Recorder:StartRecord() then Library:Notify("Recording started", 2) end end)
RecBox:AddButton("Stop Recording", function() Recorder:StopRecord(); Library:Notify("Stopped ("..#Recorder.frames.." frames)", 2) end)
RecBox:AddInput("RecName", { Default = "clip1", Numeric = false, Finished = true, Text = "Save Name", Placeholder = "name" })
RecBox:AddButton("Save Recording", function()
    local name = (Library.Flags and Library.Flags.RecName) or "clip1"
    if Recorder:Save(name) then Library:Notify("Saved "..name, 2) else Library:Notify("Save failed", 2) end
end)
RecBox:AddButton("Replay Selected", function()
    local name = (Library.Flags and Library.Flags.RecName) or "clip1"
    local data = Recorder:Load(name)
    if data and Recorder:StartReplay(data) then Library:Notify("Replaying "..name, 2) else Library:Notify("Load failed", 2) end
end)
RecBox:AddButton("Stop Replay", function() Recorder:StopReplay(); Library:Notify("Replay stopped", 2) end)
RecBox:AddButton("List Recordings", function()
    local list = Recorder:List()
    Library:Notify(#list > 0 and table.concat(list, ", ") or "no recordings", 4)
end)

-- PLAYER
local PlayerBox = Tabs.Player:AddLeftGroupbox("Local Player")
PlayerBox:AddToggle("ThirdPerson", { Text = "Third Person", Default = false, Callback = function(v) Config:Set({"Player","ThirdPerson"}, v) end })
PlayerBox:AddSlider("TPDist", { Text = "TP Distance", Default = 10, Min = 2, Max = 30, Rounding = 0, Callback = function(v) Config:Set({"Player","ThirdPersonDistance"}, v) end })
PlayerBox:AddToggle("NoCamShake", { Text = "No Camera Shake", Default = false, Callback = function(v) Config:Set({"Player","NoCameraShake"}, v) end })
PlayerBox:AddToggle("InfStamina", { Text = "Infinite Stamina", Default = false, Callback = function(v) Config:Set({"Player","InfStamina"}, v) end })

-- COSMETICS
local CosBox = Tabs.Cosmetics:AddLeftGroupbox("Cosmetics")
CosBox:AddToggle("CosEnabled", { Text = "Enabled", Default = false, Callback = function(v) Config:Set({"Cosmetics","Enabled"}, v) end })
CosBox:AddToggle("KillEffect", { Text = "Kill Effect", Default = false, Callback = function(v) Config:Set({"Cosmetics","KillEffect"}, v) end })
CosBox:AddInput("KillEffectId", { Default = "", Numeric = false, Finished = true, Text = "Kill Effect Id", Callback = function(v) Config:Set({"Cosmetics","KillEffectId"}, v) end })
CosBox:AddToggle("Trail", { Text = "Trail", Default = false, Callback = function(v) Config:Set({"Cosmetics","Trail"}, v) end })
CosBox:AddLabel("Trail Color"):AddColorPicker("TrailColor", { Default = Color3.fromRGB(0,255,160), Callback = function(v) Config:Set({"Cosmetics","TrailColor"}, v) end })
CosBox:AddToggle("Aura", { Text = "Aura", Default = false, Callback = function(v) Config:Set({"Cosmetics","Aura"}, v) end })
CosBox:AddLabel("Aura Color"):AddColorPicker("AuraColor", { Default = Color3.fromRGB(255,50,50), Callback = function(v) Config:Set({"Cosmetics","AuraColor"}, v) end })
CosBox:AddToggle("CustomArms", { Text = "Custom Arms", Default = false, Callback = function(v) Config:Set({"Cosmetics","CustomArms"}, v) end })

-- WORLD
local WorldBox = Tabs.World:AddLeftGroupbox("Lighting")
WorldBox:AddToggle("WFullBright", { Text = "Full Bright", Default = false, Callback = function(v) Config:Set({"Visuals","FullBright"}, v); applyFullBright(v) end })
WorldBox:AddToggle("WNoFog", { Text = "No Fog", Default = false, Callback = function(v) Config:Set({"Visuals","NoFog"}, v); applyNoFog(v) end })
WorldBox:AddToggle("WForceTime", { Text = "Force Time", Default = false, Callback = function(v) Config:Set({"Visuals","World","ForceTime"}, v); applyForceTime() end })
WorldBox:AddSlider("WClock", { Text = "Clock Time", Default = 14, Min = 0, Max = 24, Rounding = 1, Callback = function(v) Config:Set({"Visuals","World","ClockTime"}, v); applyForceTime() end })
WorldBox:AddSlider("WBright", { Text = "Brightness", Default = 2, Min = 0, Max = 10, Rounding = 1, Callback = function(v) Config:Set({"Visuals","World","Brightness"}, v); if Config.Data.Visuals.FullBright then Lighting.Brightness = v end end })

-- MISC
local MiscBox = Tabs.Misc:AddLeftGroupbox("General")
local SoundBox = Tabs.Misc:AddRightGroupbox("Sound / Chat")
local ExtraBox = Tabs.Misc:AddRightGroupbox("Extra")

MiscBox:AddToggle("Watermark", { Text = "Watermark", Default = true, Callback = function(v) Config:Set({"Misc","Watermark"}, v) end })
MiscBox:AddToggle("AntiAFK", { Text = "Anti AFK", Default = true, Callback = function(v) Config:Set({"Misc","AntiAFK"}, v); setAntiAFK(v) end })
MiscBox:AddToggle("AutoRespawn", { Text = "Auto Respawn", Default = false, Callback = function(v) Config:Set({"Misc","AutoRespawn"}, v) end })
MiscBox:AddToggle("StreamProof", { Text = "Stream Proof", Default = false, Callback = function(v) Config:Set({"Misc","StreamProof"}, v) end })
MiscBox:AddToggle("Zoom", { Text = "Zoom", Default = false, Callback = function(v) Config:Set({"Misc","Zoom"}, v) end })
MiscBox:AddSlider("ZoomFOV", { Text = "Zoom FOV", Default = 20, Min = 5, Max = 50, Rounding = 0, Callback = function(v) Config:Set({"Misc","ZoomFOV"}, v) end })

SoundBox:AddToggle("HitSound", { Text = "Hit Sound", Default = false, Callback = function(v) Config:Set({"Misc","HitSound"}, v) end })
SoundBox:AddInput("HitSoundId", { Default = "rbxassetid://12222216", Numeric = false, Finished = true, Text = "Sound Id", Callback = function(v) Config:Set({"Misc","HitSoundId"}, v) end })
SoundBox:AddSlider("HitSoundVol", { Text = "Volume", Default = 1, Min = 0, Max = 5, Rounding = 1, Callback = function(v) Config:Set({"Misc","HitSoundVolume"}, v) end })
SoundBox:AddToggle("Killsay", { Text = "Kill Say", Default = false, Callback = function(v) Config:Set({"Misc","Killsay"}, v) end })
SoundBox:AddInput("KillsayText", { Default = "always.winning", Numeric = false, Finished = true, Text = "Kill Say Text", Callback = function(v) Config:Set({"Misc","KillsayText"}, v) end })

ExtraBox:AddButton("Test Hit Sound", function() playHitSound() end)
ExtraBox:AddButton("Unload", function() Library:Unload(); AW.Unload() end)
ExtraBox:AddButton("Copy Tag", function() setclipboard("always.winning"); Library:Notify("copied", 2) end)

-- SETTINGS
local MenuBox = Tabs.Settings:AddLeftGroupbox("Menu")
MenuBox:AddLabel("UI toggle: RightShift")
MenuBox:AddButton("Destroy Menu + Script", function() Library:Unload(); AW.Unload() end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder("always.winning/configs")
ThemeManager:SetFolder("always.winning")
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

if Config.Data.Misc.AntiAFK then setAntiAFK(true) end
if Config.Data.Misc.Watermark then ensureWatermark() end

Library:Notify("always.winning — all tabs loaded", 4)
print("[always.winning] ready — all tabs")

-- ============================================================
-- Cloudy.cc | Ragebot + Void + Tap
-- Custom UI | 380px | Mobile Toggle Button
-- ============================================================

pcall(function() setthreadidentity(8) end)
pcall(function() if syn then syn.set_thread_identity(8) end end)

-- ════════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════════
local repS  = cloneref(game:GetService("ReplicatedStorage"))
local plrs  = cloneref(game:GetService("Players"))
local runS  = cloneref(game:GetService("RunService"))
local ws    = cloneref(game:GetService("Workspace"))
local UIS   = cloneref(game:GetService("UserInputService"))
local TweenS= cloneref(game:GetService("TweenService"))
local lplr  = plrs.LocalPlayer

local ok_util, util = pcall(require, repS.Modules.Utility)
local ok_enum, enum = pcall(require, repS.Modules.EnumLibrary)
local ok_fc,   FC   = pcall(require, lplr.PlayerScripts.Controllers.FighterController)
local ok_sc,   SC   = pcall(require, lplr.PlayerScripts.Controllers:WaitForChild("SpectateController"))

if not (ok_util and ok_enum and ok_fc and ok_sc) then
    warn("[CloudyCC] failed to require game modules")
    return
end

-- ════════════════════════════════════════════
--  PAUSE FLAG
-- ════════════════════════════════════════════
getgenv().VoidPaused = false

-- ════════════════════════════════════════════
--  CONFIG
-- ════════════════════════════════════════════
getgenv().RbConfig = {
    Enabled    = true,
    FireRate   = 0.0005,
    WeaponSlot = "Melee",
}

getgenv().VConfig = {
    vst_enabled                 = false,
    vst_type                    = "Unhittability",
    vst_spin_speed              = 1e85,
    vst_unhittability_y_range   = 10,
    vst_bait_depth              = 20,
    vst_defend_proximity_escape = true,
    vst_defend_proximity_radius = 20,
    vst_defend_escape_dist      = 1000,
    melee_bypass_enabled        = false,
    melee_bypass_y_range        = 10,
    evs_burst                   = 100,
    evs_kill_velocity           = true,
    evs_snap_back               = false,
    et_total                    = 500,
    evs_iter_radius             = 500000,
    vs_min_dist                 = 1,
    vs_max_dist                 = 50000,
    vs_void_direction           = "Random",
    vs_dir_xp = 5000, vs_dir_xn = 5000,
    vs_dir_yp = 5000, vs_dir_yn = 5000,
    vs_dir_zp = 5000, vs_dir_zn = 5000,
    vs_stabilizer_enabled       = false,
    vs_stability                = 50,
    vs_pos_restore              = false,
    sounds_enabled              = false,
}

getgenv().TapConfig = {
    enabled      = false,
    delay        = 0.05,
    target_mode  = "Nearest",
    part         = "HumanoidRootPart",
    team_check   = true,
    max_dist     = 500,
    fov_enabled  = false,
    fov_radius   = 120,
    auto_tap     = false,
    auto_tap_key = Enum.KeyCode.Q,
}

local RC  = getgenv().RbConfig
local VC  = getgenv().VConfig
local TAP = getgenv().TapConfig

-- ════════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════════
getgenv().get_hrp = function(plr)
    local p = plr or lplr
    if not p.Character then return nil end
    return p.Character:FindFirstChild("HumanoidRootPart")
end

local function notify(title, msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",
            {Title=title, Text=msg, Duration=3})
    end)
end

local snd = Instance.new("Sound")
snd.SoundId = "rbxassetid://6042053214"
snd.Volume  = 0.5
snd.Parent  = lplr.Character or workspace

local play_toggle_sound = function()
    if not VC.sounds_enabled then return end
    pcall(function() snd:Play() end)
end

LP_CharAdded = lplr.CharacterAdded:Connect(function(char)
    snd.Parent = char
end)

-- ════════════════════════════════════════════
--  MANIPULATION
-- ════════════════════════════════════════════
local manip_ray_params = RaycastParams.new()
local manip_offsets = {
    Vector3.new(0,12,0), Vector3.new(0,16,0), Vector3.new(0,20,0), Vector3.new(0,24,0),
    Vector3.new(0,28,0), Vector3.new(0,32,0), Vector3.new(0,36,0), Vector3.new(0,40,0),
}
local manipulation = {}

manipulation.calculate_point = function(origin, tp, tc)
    manip_ray_params.FilterDescendantsInstances = {lplr.Character, tc}
    manip_ray_params.FilterType = Enum.RaycastFilterType.Exclude
    if not ws:Raycast(origin, tp-origin, manip_ray_params) then return origin, nil end
    for _, off in next, manip_offsets do
        local scan = origin + off
        if not ws:Raycast(scan, tp-scan, manip_ray_params) then return scan, off.Y end
    end
    return nil, nil
end

manipulation.fire_toward = function(target_part, target_char)
    pcall(function()
        if not FC.LocalFighter then return end
        local item = FC.LocalFighter.EquippedItem
        if not item then return end
        local cam = ws.CurrentCamera.CFrame
        local mp, h = manipulation.calculate_point(cam.Position, target_part.Position, target_char)
        if not mp then return end
        local sp = (h == nil and mp) or cam.Position
        local lk = CFrame.lookAt(sp, target_part.Position):ToOrientation()
        local cd = {}
        cd[utf8.char(1)] = {
            [utf8.char(0)] = util:EncodeCFrame(CFrame.new(sp.X,sp.Y+(h or 0),sp.Z)*CFrame.Angles(lk)),
            [utf8.char(1)] = h and util:EncodeCFrame(CFrame.new(target_part.Position)*CFrame.Angles(lk))
                               or  util:EncodeCFrame(CFrame.new(sp.X,sp.Y+(h or 0),sp.Z)*CFrame.Angles(lk)),
            [utf8.char(2)] = target_part,
            [utf8.char(3)] = util:EncodeCFrame(target_part.CFrame:ToObjectSpace(CFrame.new(target_part.Position))),
        }
        repS.Remotes.Replication.Fighter.UseItem:FireServer(
            item:Get("ObjectID"), enum:ToEnum("StartShooting"), cd, nil)
    end)
end

-- ════════════════════════════════════════════
--  MELEE BYPASS
-- ════════════════════════════════════════════
local MELEE_FAKE_OFFSET   = Vector3.new(9000, 9000, 9000)
local melee_conn          = nil
local melee_active        = false
local melee_fake_cf_store = {}

getgenv().start_melee_bypass = function()
    if melee_active then return end
    melee_active = true
    VC.melee_bypass_enabled = true
    melee_conn = runS.Heartbeat:Connect(function()
        if not VC.melee_bypass_enabled then return end
        local my = getgenv().get_hrp(lplr)
        if not my then return end
        pcall(function()
            for _, p in pairs(plrs:GetPlayers()) do
                if p ~= lplr and p.Character then
                    local h = p.Character:FindFirstChild("HumanoidRootPart")
                    if h then
                        local yd = my.Position.Y - h.Position.Y
                        if yd >= 0 and yd <= (VC.melee_bypass_y_range or 10) then
                            melee_fake_cf_store[p] = h.CFrame
                            local mt = getrawmetatable(h)
                            local ni = mt and rawget(mt, "__newindex")
                            local fake = CFrame.new(MELEE_FAKE_OFFSET)
                            if ni then pcall(ni, h, "CFrame", fake)
                            else rawset(h, "CFrame", fake) end
                            h.AssemblyLinearVelocity = Vector3.zero
                        else
                            melee_fake_cf_store[p] = nil
                        end
                    end
                end
            end
        end)
    end)
end

getgenv().stop_melee_bypass = function()
    melee_active = false
    VC.melee_bypass_enabled = false
    if melee_conn then melee_conn:Disconnect(); melee_conn = nil end
    melee_fake_cf_store = {}
end

-- ════════════════════════════════════════════
--  VOID INTERNALS
-- ════════════════════════════════════════════
local vst_last_pos = nil

local function vst_nuke_fallen()
    pcall(function() ws.FallenPartsDestroyHeight = -math.huge end)
    pcall(function() ws.FallenPartsDestroyHeight = 0/0 end)
    pcall(function()
        local mt = getrawmetatable(ws)
        if not mt then return end
        local ni = rawget(mt, "__newindex")
        if ni then
            pcall(ni, ws, "FallenPartsDestroyHeight", -math.huge)
            pcall(ni, ws, "FallenPartsDestroyHeight", 0/0)
        end
    end)
end

local function vst_get_dir_offset(dist)
    local mode = VC.vs_void_direction or "Random"
    local cam  = ws.CurrentCamera
    local function look_flat()
        if not cam then return Vector3.new(0,0,-1) end
        local lv = cam.CFrame.LookVector
        local v  = Vector3.new(lv.X, 0, lv.Z)
        return v.Magnitude > 0.001 and v.Unit or Vector3.new(0,0,-1)
    end
    if mode == "Forward" then
        local l = look_flat()
        return Vector3.new(l.X*dist, (math.random()<.5 and 1 or -1)*dist, l.Z*dist)
    elseif mode == "Backward" then
        local l = -look_flat()
        return Vector3.new(l.X*dist, (math.random()<.5 and 1 or -1)*dist, l.Z*dist)
    elseif mode == "Up" then
        return Vector3.new((math.random()-.5)*dist*.25, dist, (math.random()-.5)*dist*.25)
    elseif mode == "Down" then
        return Vector3.new((math.random()-.5)*dist*.25, -dist, (math.random()-.5)*dist*.25)
    elseif mode == "Left" then
        local rv = cam and cam.CFrame.RightVector or Vector3.new(1,0,0)
        local l  = Vector3.new(-rv.X, 0, -rv.Z)
        l = l.Magnitude > 0.001 and l.Unit or Vector3.new(-1,0,0)
        return Vector3.new(l.X*dist, (math.random()<.5 and 1 or -1)*dist, l.Z*dist)
    elseif mode == "Right" then
        local rv = cam and cam.CFrame.RightVector or Vector3.new(1,0,0)
        local r  = Vector3.new(rv.X, 0, rv.Z)
        r = r.Magnitude > 0.001 and r.Unit or Vector3.new(1,0,0)
        return Vector3.new(r.X*dist, (math.random()<.5 and 1 or -1)*dist, r.Z*dist)
    elseif mode == "Directional" then
        local sx = math.random()<.5 and VC.vs_dir_xp or -VC.vs_dir_xn
        local sy = math.random()<.5 and VC.vs_dir_yp or -VC.vs_dir_yn
        local sz = math.random()<.5 and VC.vs_dir_zp or -VC.vs_dir_zn
        return Vector3.new(sx, sy, sz)
    else
        local ang = math.random() * math.pi * 2
        local vy  = (math.random()<.5 and 1 or -1) * dist
        return Vector3.new(math.cos(ang)*dist, vy, math.sin(ang)*dist)
    end
end

local function vst_set_hrp_cframe(hrp, cf)
    pcall(function()
        local mt = getrawmetatable(hrp)
        local ni = mt and rawget(mt, "__newindex")
        if ni then pcall(ni, hrp, "CFrame", cf)
        else hrp.CFrame = cf end
    end)
end

local function vst_set_velocity(hrp, vel)
    pcall(function() hrp.AssemblyLinearVelocity = vel end)
    pcall(function() hrp.Velocity = vel end)
end

local function vst_do_single_void(hrp)
    if getgenv().VoidPaused then return end
    local origin = hrp.Position
    if VC.vs_pos_restore then vst_last_pos = hrp.CFrame end

    vst_nuke_fallen()

    local dist     = math.random(VC.vs_min_dist, VC.vs_max_dist)
    local offset   = vst_get_dir_offset(dist)
    local target   = origin + offset
    local targetCF = CFrame.new(target)

    vst_set_hrp_cframe(hrp, targetCF)

    if VC.evs_kill_velocity then
        vst_set_velocity(hrp, Vector3.zero)
    end

    if VC.vs_stabilizer_enabled then
        local stability = math.clamp(VC.vs_stability or 50, 1, 100) / 100
        task.delay(0.016 * (1 - stability), function()
            if VC.vs_pos_restore and vst_last_pos then
                vst_set_hrp_cframe(hrp, vst_last_pos)
            end
        end)
    end

    if VC.evs_snap_back then
        task.delay(0.05, function()
            pcall(function() vst_set_hrp_cframe(hrp, CFrame.new(origin)) end)
        end)
    end
end

-- EVS (Extra Void Spam) burst
local function vst_do_evs_burst(hrp)
    local burst = math.clamp(VC.evs_burst or 100, 1, 1000)
    for _ = 1, burst do
        vst_do_single_void(hrp)
    end
end

-- ════════════════════════════════════════════
--  VOID SPIN (Unhittability)
-- ════════════════════════════════════════════
local spin_conn = nil
local spin_active = false

local function start_spin()
    if spin_active then return end
    spin_active = true
    spin_conn = runS.Heartbeat:Connect(function()
        if getgenv().VoidPaused then return end
        local hrp = getgenv().get_hrp(lplr)
        if not hrp then return end
        pcall(function()
            local cf = hrp.CFrame
            local spd = VC.vst_spin_speed or 1e85
            vst_set_hrp_cframe(hrp, cf * CFrame.Angles(0, math.rad(spd), 0))
        end)
    end)
end

local function stop_spin()
    spin_active = false
    if spin_conn then spin_conn:Disconnect(); spin_conn = nil end
end

-- ════════════════════════════════════════════
--  VOID SPAM TYPE DISPATCH
-- ════════════════════════════════════════════
local vst_conn       = nil
local evs_conn       = nil
local defend_conn    = nil
local bait_conn      = nil
local extreme_conn   = nil

local function stop_all_void_conns()
    local function dc(c) if c then c:Disconnect() end end
    dc(vst_conn)   vst_conn     = nil
    dc(evs_conn)   evs_conn     = nil
    dc(defend_conn) defend_conn = nil
    dc(bait_conn)  bait_conn    = nil
    dc(extreme_conn) extreme_conn = nil
    stop_spin()
end

getgenv().start_voidspam_type = function()
    stop_all_void_conns()
    local mode = VC.vst_type or "Unhittability"

    if mode == "Unhittability" then
        start_spin()
        vst_conn = runS.Heartbeat:Connect(function()
            if getgenv().VoidPaused then return end
            local hrp = getgenv().get_hrp(lplr)
            if not hrp then return end
            local my_y = hrp.Position.Y
            pcall(function()
                for _, p in pairs(plrs:GetPlayers()) do
                    if p ~= lplr and p.Character then
                        local eh = p.Character:FindFirstChild("HumanoidRootPart")
                        if eh then
                            local yd = my_y - eh.Position.Y
                            if yd >= 0 and yd <= (VC.vst_unhittability_y_range or 10) then
                                local mt = getrawmetatable(eh)
                                local ni = mt and rawget(mt, "__newindex")
                                local fake = CFrame.new(MELEE_FAKE_OFFSET)
                                if ni then pcall(ni, eh, "CFrame", fake)
                                else pcall(function() eh.CFrame = fake end) end
                                pcall(function() eh.AssemblyLinearVelocity = Vector3.zero end)
                            end
                        end
                    end
                end
            end)
        end)

    elseif mode == "Defend" then
        defend_conn = runS.Heartbeat:Connect(function()
            if getgenv().VoidPaused then return end
            local hrp = getgenv().get_hrp(lplr)
            if not hrp then return end
            vst_do_evs_burst(hrp)
            if VC.vst_defend_proximity_escape then
                pcall(function()
                    for _, p in pairs(plrs:GetPlayers()) do
                        if p ~= lplr and p.Character then
                            local eh = p.Character:FindFirstChild("HumanoidRootPart")
                            if eh then
                                local d = (hrp.Position - eh.Position).Magnitude
                                if d <= (VC.vst_defend_proximity_radius or 20) then
                                    local away = (hrp.Position - eh.Position).Unit
                                    local esc  = VC.vst_defend_escape_dist or 1000
                                    vst_set_hrp_cframe(hrp, CFrame.new(hrp.Position + away * esc))
                                end
                            end
                        end
                    end
                end)
            end
        end)

    elseif mode == "Bait" then
        bait_conn = runS.Heartbeat:Connect(function()
            if getgenv().VoidPaused then return end
            local hrp = getgenv().get_hrp(lplr)
            if not hrp then return end
            pcall(function()
                local depth = VC.vst_bait_depth or 20
                local orig  = hrp.Position
                vst_set_hrp_cframe(hrp, CFrame.new(orig + Vector3.new(0, -depth, 0)))
                task.wait(0.016)
                vst_set_hrp_cframe(hrp, CFrame.new(orig))
            end)
            vst_do_evs_burst(hrp)
        end)

    elseif mode == "Extreme" then
        extreme_conn = runS.Heartbeat:Connect(function()
            if getgenv().VoidPaused then return end
            local hrp = getgenv().get_hrp(lplr)
            if not hrp then return end
            local iters = math.clamp(VC.et_total or 500, 1, 500)
            for _ = 1, iters do
                local dist   = math.random(1, math.clamp(VC.evs_iter_radius or 500000, 1, 100000000))
                local offset = vst_get_dir_offset(dist)
                vst_set_hrp_cframe(hrp, CFrame.new(hrp.Position + offset))
                if VC.evs_kill_velocity then
                    vst_set_velocity(hrp, Vector3.zero)
                end
            end
            vst_nuke_fallen()
        end)
    end
end

getgenv().stop_voidspam_type = function()
    stop_all_void_conns()
end

-- Extra void spam (EVS) standalone loop
local extra_vs_conn = nil

getgenv().start_extra_voidspam = function()
    if extra_vs_conn then return end
    extra_vs_conn = runS.Heartbeat:Connect(function()
        if getgenv().VoidPaused then return end
        local hrp = getgenv().get_hrp(lplr)
        if hrp then vst_do_evs_burst(hrp) end
    end)
end

getgenv().stop_extra_voidspam = function()
    if extra_vs_conn then extra_vs_conn:Disconnect(); extra_vs_conn = nil end
end

getgenv().disable_voidspam_type = getgenv().stop_voidspam_type

-- ════════════════════════════════════════════
--  RAGEBOT
-- ════════════════════════════════════════════
local rb_conn    = nil
local rb_running = false

local function rb_get_target()
    local my_hrp = getgenv().get_hrp(lplr)
    if not my_hrp then return nil end
    local cam     = ws.CurrentCamera
    local vp      = cam.ViewportSize
    local center  = Vector2.new(vp.X/2, vp.Y/2)
    local best, bestDist, bestScreen = nil, math.huge, nil

    for _, p in pairs(plrs:GetPlayers()) do
        if p == lplr then continue end
        if not p.Character then continue end
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        local hum = p.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end

        -- team check: skip same team
        if p.Team and lplr.Team and p.Team == lplr.Team then continue end

        local worldPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
        if not onScreen then continue end

        local screenPos = Vector2.new(worldPos.X, worldPos.Y)
        local d = (screenPos - center).Magnitude
        if d < bestDist then
            bestDist   = d
            best       = p
            bestScreen = screenPos
        end
    end
    return best
end

local function rb_fire_at(p)
    if not p or not p.Character then return end
    local slot = RC.WeaponSlot or "Melee"
    local hrp  = p.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Pause void during shot
    getgenv().VoidPaused = true
    manipulation.fire_toward(hrp, p.Character)
    task.delay(0.08, function()
        getgenv().VoidPaused = false
    end)
end

local function rb_start()
    if rb_running then return end
    rb_running = true
    rb_conn = runS.Heartbeat:Connect(function()
        if not RC.Enabled then return end
        local target = rb_get_target()
        if not target then return end
        rb_fire_at(target)
        task.wait(RC.FireRate or 0.0005)
    end)
end

local function rb_stop()
    rb_running = false
    if rb_conn then rb_conn:Disconnect(); rb_conn = nil end
end

-- ════════════════════════════════════════════
--  TAP (Manual/Auto Target Attack)
-- ════════════════════════════════════════════
local tap_conn     = nil
local tap_running  = false
local tap_key_conn = nil

local function tap_get_target()
    local my_hrp = getgenv().get_hrp(lplr)
    if not my_hrp then return nil end
    local cam    = ws.CurrentCamera
    local vp     = cam.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local best, bestVal = nil, math.huge

    for _, p in pairs(plrs:GetPlayers()) do
        if p == lplr then continue end
        if not p.Character then continue end
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        local hum = p.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        if TAP.team_check and p.Team and lplr.Team and p.Team == lplr.Team then continue end

        local dist = (my_hrp.Position - hrp.Position).Magnitude
        if dist > (TAP.max_dist or 500) then continue end

        if TAP.fov_enabled then
            local worldPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
            if not onScreen then continue end
            local screenPos = Vector2.new(worldPos.X, worldPos.Y)
            local fovD = (screenPos - center).Magnitude
            if fovD > (TAP.fov_radius or 120) then continue end
            if fovD < bestVal then bestVal = fovD; best = p end
        else
            if dist < bestVal then bestVal = dist; best = p end
        end
    end
    return best
end

local function tap_fire()
    if not TAP.enabled then return end
    local target = tap_get_target()
    if not target then return end
    local hrp = target.Character and target.Character:FindFirstChild(TAP.part or "HumanoidRootPart")
    if not hrp then return end
    getgenv().VoidPaused = true
    manipulation.fire_toward(hrp, target.Character)
    task.delay(0.08, function() getgenv().VoidPaused = false end)
end

local function tap_start_auto()
    if tap_running then return end
    tap_running = true
    tap_conn = runS.Heartbeat:Connect(function()
        if not TAP.auto_tap or not TAP.enabled then return end
        tap_fire()
        task.wait(TAP.delay or 0.05)
    end)
end

local function tap_stop_auto()
    tap_running = false
    if tap_conn then tap_conn:Disconnect(); tap_conn = nil end
end

local function tap_setup_key()
    if tap_key_conn then tap_key_conn:Disconnect(); tap_key_conn = nil end
    tap_key_conn = UIS.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == (TAP.auto_tap_key or Enum.KeyCode.Q) then
            tap_fire()
        end
    end)
end
tap_setup_key()

-- Start ragebot by default if enabled
if RC.Enabled then rb_start() end

-- ════════════════════════════════════════════
--  CUSTOM UI
-- ════════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name           = "CloudyCC_RV"
SG.ResetOnSpawn   = false
SG.IgnoreGuiInset = true
SG.DisplayOrder   = 999
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent = game:GetService("CoreGui") end)
if not SG.Parent then SG.Parent = lplr:WaitForChild("PlayerGui") end

-- ── Theme ──
local T = {
    bg       = Color3.fromRGB(10,10,16),
    panel    = Color3.fromRGB(16,16,26),
    sec      = Color3.fromRGB(22,22,36),
    border   = Color3.fromRGB(45,45,70),
    accent   = Color3.fromRGB(180,40,40),
    accentHi = Color3.fromRGB(220,60,60),
    text     = Color3.fromRGB(225,225,240),
    sub      = Color3.fromRGB(130,130,160),
    tog_on   = Color3.fromRGB(180,40,40),
    tog_off  = Color3.fromRGB(50,50,70),
    green    = Color3.fromRGB(60,200,100),
}

local UI_W = 380
local UI_H = 500

-- ── Helpers ──
local function mk(cls, props, parent)
    local i = Instance.new(cls)
    for k,v in pairs(props or {}) do i[k]=v end
    if parent then i.Parent=parent end
    return i
end
local function corner(f,r) mk("UICorner",{CornerRadius=UDim.new(0,r or 6)},f) end
local function stroke(f,c,t) mk("UIStroke",{Color=c or T.border,Thickness=t or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},f) end
local function pad(f,a,b,l,r) mk("UIPadding",{PaddingTop=UDim.new(0,a or 0),PaddingBottom=UDim.new(0,b or 0),PaddingLeft=UDim.new(0,l or 0),PaddingRight=UDim.new(0,r or 0)},f) end
local function tween(obj, props, t_)
    TweenS:Create(obj, TweenInfo.new(t_ or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ── Main Window ──
local Win = mk("Frame",{
    Name="CloudyWin", Size=UDim2.fromOffset(UI_W, UI_H),
    Position=UDim2.new(0.5,-UI_W/2,0.5,-UI_H/2),
    BackgroundColor3=T.bg, BorderSizePixel=0, Visible=true,
},SG)
corner(Win,8) stroke(Win,T.border,1)

-- ── Title Bar ──
local TBar = mk("Frame",{
    Size=UDim2.new(1,0,0,38), BackgroundColor3=T.panel, BorderSizePixel=0,
},Win)
corner(TBar,8)
mk("Frame",{Size=UDim2.new(1,0,0.5,0),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=T.panel,BorderSizePixel=0},TBar)
stroke(TBar,T.border,1)
mk("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=T.accent,BorderSizePixel=0},TBar)

mk("TextLabel",{
    Size=UDim2.new(1,-50,1,0),Position=UDim2.new(0,12,0,0),
    BackgroundTransparency=1,
    Text="Cloudy.cc  |  RageVoid",
    TextColor3=T.text,Font=Enum.Font.GothamBold,TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left,
},TBar)

-- drag
do
    local drag,ds,sp=false,nil,nil
    TBar.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=inp.Position; sp=Win.Position
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-ds
            Win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            drag=false
        end
    end)
end

-- ── Tab Bar ──
local TabBar = mk("Frame",{
    Size=UDim2.new(1,0,0,32),Position=UDim2.new(0,0,0,38),
    BackgroundColor3=T.panel,BorderSizePixel=0,
},Win)
mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,2),VerticalAlignment=Enum.VerticalAlignment.Center},TabBar)
pad(TabBar,0,0,6,6)
stroke(TabBar,T.border,1)

-- ── Content Area ──
local ContentArea = mk("Frame",{
    Size=UDim2.new(1,0,1,-70),Position=UDim2.new(0,0,0,70),
    BackgroundColor3=T.bg,BorderSizePixel=0,
},Win)

-- ── Tab System ──
local tabs = {}
local activeTab = nil

local function makeTab(name)
    local btn = mk("TextButton",{
        Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,
        BackgroundColor3=Color3.fromRGB(25,25,40),
        Text=" "..name.." ",TextColor3=T.sub,
        Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0,
        AutoButtonColor=false,
    },TabBar)
    corner(btn,5)
    pad(btn,0,0,4,4)

    local scroll = mk("ScrollingFrame",{
        Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
        ScrollBarThickness=3,ScrollBarImageColor3=T.accent,
        CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        BorderSizePixel=0,Visible=false,
    },ContentArea)
    mk("UIListLayout",{Padding=UDim.new(0,6),HorizontalAlignment=Enum.HorizontalAlignment.Center},scroll)
    pad(scroll,8,8,8,8)

    local t = {name=name, btn=btn, scroll=scroll}
    table.insert(tabs, t)

    btn.MouseButton1Click:Connect(function()
        for _, ot in ipairs(tabs) do
            ot.scroll.Visible=false
            ot.btn.BackgroundColor3=Color3.fromRGB(25,25,40)
            ot.btn.TextColor3=T.sub
        end
        scroll.Visible=true
        btn.BackgroundColor3=T.accent
        btn.TextColor3=Color3.fromRGB(255,255,255)
        activeTab=t
    end)
    return t
end

-- ── Component Helpers ──
local function makeSection(scroll, title)
    local sec = mk("Frame",{
        Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=T.panel,BorderSizePixel=0,
    },scroll)
    corner(sec,6) stroke(sec,T.border,1)
    local list = mk("UIListLayout",{Padding=UDim.new(0,4)},sec)
    pad(sec,6,6,8,8)

    if title then
        mk("TextLabel",{
            Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,
            Text=title:upper(),TextColor3=T.accent,
            Font=Enum.Font.GothamBold,TextSize=9,
            TextXAlignment=Enum.TextXAlignment.Left,
        },sec)
        mk("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=T.border,BorderSizePixel=0},sec)
    end
    return sec
end

local function makeToggle(parent, label, default, cb)
    local val = default or false
    local row = mk("Frame",{
        Size=UDim2.new(1,0,0,30),BackgroundColor3=T.sec,BorderSizePixel=0,
    },parent)
    corner(row,5)

    mk("TextLabel",{
        Size=UDim2.new(1,-52,1,0),Position=UDim2.new(0,8,0,0),
        BackgroundTransparency=1,Text=label,
        TextColor3=T.text,Font=Enum.Font.GothamMedium,TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
    },row)

    local track = mk("Frame",{
        Size=UDim2.fromOffset(34,18),Position=UDim2.new(1,-42,0.5,-9),
        BackgroundColor3=val and T.tog_on or T.tog_off,BorderSizePixel=0,
    },row)
    corner(track,9)

    local knob = mk("Frame",{
        Size=UDim2.fromOffset(14,14),
        Position=val and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
        BackgroundColor3=Color3.fromRGB(255,255,255),BorderSizePixel=0,
    },track)
    corner(knob,7)

    local btn = mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=2},row)

    local function update()
        tween(track,{BackgroundColor3=val and T.tog_on or T.tog_off})
        tween(knob,{Position=val and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)})
    end
    btn.MouseButton1Click:Connect(function()
        val=not val; update(); if cb then cb(val) end
    end)
    return {Set=function(_,v) val=v; update(); if cb then cb(val) end end, Get=function() return val end}
end

local function makeSlider(parent, label, min_, max_, default_, cb, suffix)
    local val = default_ or min_
    suffix = suffix or ""
    local row = mk("Frame",{
        Size=UDim2.new(1,0,0,46),BackgroundColor3=T.sec,BorderSizePixel=0,
    },parent)
    corner(row,5)

    local hdr = mk("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1},row)
    mk("TextLabel",{
        Size=UDim2.new(0.65,0,1,0),Position=UDim2.new(0,8,0,0),
        BackgroundTransparency=1,Text=label,
        TextColor3=T.text,Font=Enum.Font.GothamMedium,TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
    },hdr)
    local valLbl = mk("TextLabel",{
        Size=UDim2.new(0.35,0,1,0),Position=UDim2.new(0.65,0,0,0),
        BackgroundTransparency=1,Text=tostring(val)..suffix,
        TextColor3=T.accent,Font=Enum.Font.GothamBold,TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Right,
    },hdr)
    pad(valLbl,0,0,0,8)

    local track = mk("Frame",{
        Size=UDim2.new(1,-16,0,5),Position=UDim2.new(0,8,0,28),
        BackgroundColor3=Color3.fromRGB(35,35,55),BorderSizePixel=0,
    },row)
    corner(track,3)
    local fill = mk("Frame",{
        Size=UDim2.new((val-min_)/(max_-min_),0,1,0),
        BackgroundColor3=T.accent,BorderSizePixel=0,
    },track)
    corner(fill,3)

    local dragging=false
    local function setVal(x)
        local rel=math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        val=math.floor(min_+(max_-min_)*rel)
        fill.Size=UDim2.new(rel,0,1,0)
        valLbl.Text=tostring(val)..suffix
        if cb then cb(val) end
    end
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; setVal(inp.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            setVal(inp.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
    return {Set=function(_,v) val=v fill.Size=UDim2.new((v-min_)/(max_-min_),0,1,0) valLbl.Text=tostring(v)..suffix if cb then cb(v) end end}
end

local function makeDropdown(parent, label, options, default_, cb)
    local val = default_ or options[1]
    local open = false

    local row = mk("Frame",{
        Size=UDim2.new(1,0,0,30),BackgroundColor3=T.sec,BorderSizePixel=0,ZIndex=3,
    },parent)
    corner(row,5)

    mk("TextLabel",{
        Size=UDim2.new(0.5,0,1,0),Position=UDim2.new(0,8,0,0),
        BackgroundTransparency=1,Text=label,
        TextColor3=T.text,Font=Enum.Font.GothamMedium,TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3,
    },row)

    local valBtn = mk("TextButton",{
        Size=UDim2.fromOffset(130,22),Position=UDim2.new(1,-138,0.5,-11),
        BackgroundColor3=Color3.fromRGB(28,28,46),
        Text=val,TextColor3=T.accent,Font=Enum.Font.GothamMedium,TextSize=10,
        BorderSizePixel=0,ZIndex=4,AutoButtonColor=false,
    },row)
    corner(valBtn,4)

    local list = mk("ScrollingFrame",{
        Size=UDim2.fromOffset(130,math.min(#options*24+4,120)),
        Position=UDim2.new(1,-138,1,2),
        BackgroundColor3=Color3.fromRGB(18,18,30),BorderSizePixel=0,
        ScrollBarThickness=2,ScrollBarImageColor3=T.accent,
        CanvasSize=UDim2.new(0,0,0,#options*24+4),
        Visible=false,ZIndex=10,
    },row)
    corner(list,4) stroke(list,T.accent,1)
    mk("UIListLayout",{Padding=UDim.new(0,2)},list)
    pad(list,2,2,2,2)

    for _, opt in ipairs(options) do
        local ob = mk("TextButton",{
            Size=UDim2.new(1,0,0,22),
            BackgroundColor3=opt==val and Color3.fromRGB(35,35,60) or Color3.fromRGB(25,25,42),
            Text=opt,TextColor3=opt==val and T.accent or T.text,
            Font=Enum.Font.GothamMedium,TextSize=10,BorderSizePixel=0,ZIndex=11,AutoButtonColor=false,
        },list)
        corner(ob,3)
        ob.MouseButton1Click:Connect(function()
            val=opt; valBtn.Text=opt; list.Visible=false; open=false
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then
                    c.BackgroundColor3=c.Text==opt and Color3.fromRGB(35,35,60) or Color3.fromRGB(25,25,42)
                    c.TextColor3=c.Text==opt and T.accent or T.text
                end
            end
            if cb then cb(val) end
        end)
    end
    valBtn.MouseButton1Click:Connect(function()
        open=not open; list.Visible=open
    end)
    return {Set=function(_,v) val=v; valBtn.Text=v; if cb then cb(v) end end, Get=function() return val end}
end

local function makeButton(parent, label, cb)
    local btn = mk("TextButton",{
        Size=UDim2.new(1,0,0,30),BackgroundColor3=T.accent,
        Text=label,TextColor3=Color3.fromRGB(255,255,255),
        Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0,AutoButtonColor=false,
    },parent)
    corner(btn,5)
    btn.MouseButton1Click:Connect(function()
        tween(btn,{BackgroundColor3=Color3.fromRGB(120,25,25)},0.08)
        task.delay(0.1,function() tween(btn,{BackgroundColor3=T.accent},0.1) end)
        if cb then cb() end
    end)
    btn.MouseEnter:Connect(function() tween(btn,{BackgroundColor3=T.accentHi}) end)
    btn.MouseLeave:Connect(function() tween(btn,{BackgroundColor3=T.accent}) end)
    return btn
end

local function makeDivider(parent)
    mk("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=T.border,BorderSizePixel=0},parent)
end

local function makeLabel(parent, text, color)
    mk("TextLabel",{
        Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,
        Text=text,TextColor3=color or T.sub,
        Font=Enum.Font.Gotham,TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true,
    },parent)
end

-- ════════════════════════════════════════════
--  TAB: RAGEBOT
-- ════════════════════════════════════════════
local RB_Tab = makeTab("Ragebot")
local sc = RB_Tab.scroll

local rbSec = makeSection(sc, "Ragebot")
makeToggle(rbSec,"Enable Ragebot",RC.Enabled,function(v)
    RC.Enabled=v
    play_toggle_sound()
    if v then rb_start() else rb_stop() end
end)
makeSlider(rbSec,"Fire Rate (s)",0,100,math.floor(RC.FireRate*100000),function(v)
    RC.FireRate = v/100000
end,"")
makeLabel(rbSec,"Low = faster. Default 0.0005 (shown as 50)")
makeDivider(rbSec)
makeDropdown(rbSec,"Weapon Slot",{"Melee","Primary","Secondary","Utility"},RC.WeaponSlot,function(v)
    RC.WeaponSlot=v
end)

local rbInfoSec = makeSection(sc, "Status")
local rbStatusLbl = mk("TextLabel",{
    Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,
    Text="Ragebot: OFF",TextColor3=T.sub,
    Font=Enum.Font.GothamBold,TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
},rbInfoSec)
runS.Heartbeat:Connect(function()
    rbStatusLbl.Text = RC.Enabled and "Ragebot: ACTIVE" or "Ragebot: OFF"
    rbStatusLbl.TextColor3 = RC.Enabled and T.green or T.sub
end)

-- ════════════════════════════════════════════
--  TAB: VOID
-- ════════════════════════════════════════════
local VD_Tab = makeTab("Void")
local vs = VD_Tab.scroll

local vMain = makeSection(vs,"Void Spam")
makeToggle(vMain,"Enable Void",VC.vst_enabled,function(v)
    VC.vst_enabled=v
    play_toggle_sound()
    if v then
        getgenv().start_voidspam_type()
        if VC.vst_type=="Unhittability" then
            VC.melee_bypass_enabled=true
            getgenv().start_melee_bypass()
        end
        notify("Void","Void enabled: "..VC.vst_type)
    else
        getgenv().stop_voidspam_type()
        getgenv().stop_melee_bypass()
        notify("Void","Void disabled")
    end
end)
makeDropdown(vMain,"Void Type",{"Unhittability","Defend","Bait","Extreme"},VC.vst_type,function(v)
    VC.vst_type=v
    if VC.vst_enabled then
        getgenv().stop_voidspam_type()
        getgenv().start_voidspam_type()
        if v=="Unhittability" then
            VC.melee_bypass_enabled=true
            if not melee_active then getgenv().start_melee_bypass() end
        else
            getgenv().stop_melee_bypass()
        end
    end
end)
makeDropdown(vMain,"Void Direction",{"Random","Forward","Backward","Left","Right","Up","Down","Directional"},"Random",function(v)
    VC.vs_void_direction=v
end)
makeSlider(vMain,"Spin Speed",1,1000000,1000000,function(v) VC.vst_spin_speed=v end,"")
makeSlider(vMain,"Hitbox Suppress Range",1,50,10,function(v)
    VC.vst_unhittability_y_range=v
    VC.melee_bypass_y_range=v
end,"")

local vDefend = makeSection(vs,"Defend / Bait")
makeToggle(vDefend,"Proximity Escape",true,function(v) VC.vst_defend_proximity_escape=v end)
makeSlider(vDefend,"Escape Trigger Radius",1,200,20,function(v) VC.vst_defend_proximity_radius=v end,"")
makeSlider(vDefend,"Escape Distance",100,10000,1000,function(v) VC.vst_defend_escape_dist=v end,"")
makeSlider(vDefend,"Bait Depth",1,40,20,function(v) VC.vst_bait_depth=v end,"")

local vGM = makeSection(vs,"Godmode (Melee Bypass)")
makeToggle(vGM,"Enable Godmode",false,function(v)
    VC.melee_bypass_enabled=v
    play_toggle_sound()
    if v then getgenv().start_melee_bypass() else getgenv().stop_melee_bypass() end
end)
makeSlider(vGM,"Godmode Range",1,50,10,function(v) VC.melee_bypass_y_range=v end,"")

local vAdv = makeSection(vs,"Advanced EVS")
makeSlider(vAdv,"Iterations",1,500,500,function(v) VC.et_total=v end,"")
makeSlider(vAdv,"Iteration Radius",1,100000000,500000,function(v) VC.evs_iter_radius=v end,"")
makeSlider(vAdv,"Min Distance",1,50000,1,function(v) VC.vs_min_dist=v end,"")
makeSlider(vAdv,"Max Distance",1,500000,50000,function(v) VC.vs_max_dist=v end,"")
makeSlider(vAdv,"EVS Burst",1,1000,100,function(v) VC.evs_burst=v end,"")
makeToggle(vAdv,"Stabilizer",false,function(v) VC.vs_stabilizer_enabled=v end)
makeSlider(vAdv,"Stability",1,100,50,function(v) VC.vs_stability=v end,"%")
makeToggle(vAdv,"Kill Velocity",true,function(v) VC.evs_kill_velocity=v end)
makeToggle(vAdv,"Snap Back",false,function(v) VC.evs_snap_back=v end)
makeToggle(vAdv,"Position Restore",false,function(v) VC.vs_pos_restore=v end)

local vDir = makeSection(vs,"Directional Config")
makeLabel(vDir,"Used when direction = Directional")
makeSlider(vDir,"X+",1,100000000,5000,function(v) VC.vs_dir_xp=v end,"")
makeSlider(vDir,"X-",1,100000000,5000,function(v) VC.vs_dir_xn=v end,"")
makeSlider(vDir,"Y+",1,100000000,5000,function(v) VC.vs_dir_yp=v end,"")
makeSlider(vDir,"Y-",1,100000000,5000,function(v) VC.vs_dir_yn=v end,"")
makeSlider(vDir,"Z+",1,100000000,5000,function(v) VC.vs_dir_zp=v end,"")
makeSlider(vDir,"Z-",1,100000000,5000,function(v) VC.vs_dir_zn=v end,"")

local vPresets = makeSection(vs,"Quick Presets")
makeButton(vPresets,"Aggressive",function()
    VC.et_total=500; VC.evs_burst=500; VC.evs_iter_radius=1000000; VC.vs_max_dist=100000
    notify("Void","Preset: Aggressive")
end)
makeButton(vPresets,"Balanced",function()
    VC.et_total=300; VC.evs_burst=100; VC.evs_iter_radius=500000; VC.vs_max_dist=50000
    notify("Void","Preset: Balanced")
end)
makeButton(vPresets,"Light",function()
    VC.et_total=100; VC.evs_burst=50; VC.evs_iter_radius=200000; VC.vs_max_dist=20000
    notify("Void","Preset: Light")
end)

-- ════════════════════════════════════════════
--  TAB: TAP
-- ════════════════════════════════════════════
local TP_Tab = makeTab("Tap")
local ts = TP_Tab.scroll

local tpMain = makeSection(ts,"Tap Config")
makeToggle(tpMain,"Enable Tap",false,function(v)
    TAP.enabled=v
    play_toggle_sound()
    notify("Tap", v and "Tap enabled" or "Tap disabled")
end)
makeSlider(tpMain,"Tap Delay (ms)",1,500,50,function(v) TAP.delay=v/1000 end,"ms")
makeDropdown(tpMain,"Target Mode",{"Nearest","FOV"},"Nearest",function(v)
    TAP.target_mode=v
    TAP.fov_enabled=(v=="FOV")
end)
makeDropdown(tpMain,"Target Part",{"HumanoidRootPart","Head","Torso"},"HumanoidRootPart",function(v)
    TAP.part=v
end)
makeToggle(tpMain,"Team Check",true,function(v) TAP.team_check=v end)
makeSlider(tpMain,"Max Distance",1,2000,500,function(v) TAP.max_dist=v end,"")
makeSlider(tpMain,"FOV Radius",10,500,120,function(v) TAP.fov_radius=v end,"px")

local tpAuto = makeSection(ts,"Auto Tap")
makeToggle(tpAuto,"Auto Tap",false,function(v)
    TAP.auto_tap=v
    if v then tap_start_auto() else tap_stop_auto() end
end)
makeLabel(tpAuto,"Key: Q (manual tap when auto is off)")
makeButton(tpAuto,"Fire Once",function() tap_fire() end)

-- ════════════════════════════════════════════
--  TAB: SETTINGS
-- ════════════════════════════════════════════
local ST_Tab = makeTab("Settings")
local ss = ST_Tab.scroll

local stMenu = makeSection(ss,"Menu")
makeToggle(stMenu,"Sounds",false,function(v)
    VC.sounds_enabled=v
end)
makeSlider(stMenu,"Sound Volume",0,100,50,function(v)
    snd.Volume=v/100
end,"%")
makeButton(stMenu,"Test Sound",function()
    local prev=VC.sounds_enabled; VC.sounds_enabled=true
    play_toggle_sound()
    task.delay(0.3,function() VC.sounds_enabled=prev end)
end)
makeDivider(stMenu)
makeButton(stMenu,"Unload Script",function()
    RC.Enabled=false
    getgenv().disable_voidspam_type()
    getgenv().stop_extra_voidspam()
    getgenv().stop_melee_bypass()
    tap_stop_auto()
    if tap_key_conn then tap_key_conn:Disconnect() end
    if rb_conn then rb_conn:Disconnect() end
    SG:Destroy()
    if ToggleBtn then ToggleBtn:Destroy() end
    notify("Cloudy.cc","Script unloaded.")
end)

local stInfo = makeSection(ss,"Info")
makeLabel(stInfo,"Cloudy.cc | RagebotVoid")
makeLabel(stInfo,"Ragebot + Void + Tap | Mobile UI")
makeLabel(stInfo,"Toggle: button bottom-right OR RightShift")

-- ════════════════════════════════════════════
--  ACTIVATE FIRST TAB
-- ════════════════════════════════════════════
do
    local t = tabs[1]
    t.scroll.Visible=true
    t.btn.BackgroundColor3=T.accent
    t.btn.TextColor3=Color3.fromRGB(255,255,255)
    activeTab=t
end

-- ════════════════════════════════════════════
--  MOBILE TOGGLE BUTTON
-- ════════════════════════════════════════════
ToggleBtn = mk("TextButton",{
    Name="CloudyToggle",
    Size=UDim2.fromOffset(44,44),
    Position=UDim2.new(1,-54,1,-54),
    BackgroundColor3=T.accent,
    Text="☰",TextColor3=Color3.fromRGB(255,255,255),
    Font=Enum.Font.GothamBold,TextSize=18,
    BorderSizePixel=0,ZIndex=100,
},SG)
corner(ToggleBtn,22)
stroke(ToggleBtn,Color3.fromRGB(220,60,60),2)

-- Make toggle button draggable on mobile
do
    local drag,ds,sp=false,nil,nil
    ToggleBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=inp.Position; sp=ToggleBtn.Position
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if drag and inp.UserInputType==Enum.UserInputType.Touch then
            local d=inp.Position-ds
            local nx=sp.X.Offset+d.X; local ny=sp.Y.Offset+d.Y
            if math.abs(d.X)<5 and math.abs(d.Y)<5 then return end
            ToggleBtn.Position=UDim2.new(sp.X.Scale,nx,sp.Y.Scale,ny)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.Touch then
            local d=inp.Position-ds
            if math.abs(d.X)<8 and math.abs(d.Y)<8 then
                local vis=not Win.Visible
                Win.Visible=vis
                ToggleBtn.Text=vis and "✕" or "☰"
                tween(ToggleBtn,{BackgroundColor3=vis and Color3.fromRGB(120,25,25) or T.accent})
            end
            drag=false
        end
    end)
end

-- Click toggle for desktop
ToggleBtn.MouseButton1Click:Connect(function()
    local vis=not Win.Visible
    Win.Visible=vis
    ToggleBtn.Text=vis and "✕" or "☰"
    tween(ToggleBtn,{BackgroundColor3=vis and Color3.fromRGB(120,25,25) or T.accent})
end)

-- Keyboard toggle
UIS.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode==Enum.KeyCode.RightShift then
        local vis=not Win.Visible
        Win.Visible=vis
        ToggleBtn.Text=vis and "✕" or "☰"
        tween(ToggleBtn,{BackgroundColor3=vis and Color3.fromRGB(120,25,25) or T.accent})
    end
end)

notify("Cloudy.cc","RagebotVoid loaded. RightShift to toggle.")

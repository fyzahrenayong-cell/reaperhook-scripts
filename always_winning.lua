-- always.winning
-- Ragebot + Void + Tap | Obsidian UI Library
-- All features extracted from source | Custom UI

-- ════════════════════════════════════════════
-- BOOT GUARD
-- ════════════════════════════════════════════
if getgenv().AlwaysWinning and getgenv().AlwaysWinning.Unload then
    pcall(getgenv().AlwaysWinning.Unload)
end
if not game:IsLoaded() then game.Loaded:Wait() end

pcall(function() setthreadidentity(8) end)
pcall(function() if syn then syn.set_thread_identity(8) end end)

-- ════════════════════════════════════════════
-- SERVICES
-- ════════════════════════════════════════════
local repS   = cloneref(game:GetService("ReplicatedStorage"))
local plrs   = cloneref(game:GetService("Players"))
local runS   = cloneref(game:GetService("RunService"))
local ws     = cloneref(game:GetService("Workspace"))
local sndSvc = cloneref(game:GetService("SoundService"))
local lplr   = plrs.LocalPlayer

-- ════════════════════════════════════════════
-- MODULE LOAD
-- ════════════════════════════════════════════
local ok_util, util = pcall(require, repS.Modules.Utility)
local ok_enum, enum = pcall(require, repS.Modules.EnumLibrary)
local ok_fc,   FC   = pcall(require, lplr.PlayerScripts.Controllers.FighterController)
local ok_sc,   SC   = pcall(require, lplr.PlayerScripts.Controllers:WaitForChild("SpectateController"))

if not (ok_util and ok_enum and ok_fc and ok_sc) then
    warn("[always.winning] failed to require game modules")
    return
end

-- ════════════════════════════════════════════
-- GLOBAL STATE
-- ════════════════════════════════════════════
getgenv().VoidPaused = false

getgenv().AlwaysWinning = {
    Unload = function() end
}

-- ════════════════════════════════════════════
-- CONFIG
-- ════════════════════════════════════════════
getgenv().RbConfig = {
    Enabled    = true,
    FireRate   = 0.0005,
    WeaponSlot = "Melee",
    TeamCheck  = true,
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
    sound_volume                = 0.5,
}

getgenv().TapConfig = {
    enabled       = false,
    delay         = 0.08,
    auto_tap      = false,
    tap_key       = Enum.KeyCode.E,
    hold_tap      = false,
    tap_on_fire   = true,
}

local RC  = getgenv().RbConfig
local VC  = getgenv().VConfig
local TAP = getgenv().TapConfig

-- ════════════════════════════════════════════
-- HELPERS
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

local snd = Instance.new("Sound", sndSvc)
snd.SoundId = "rbxassetid://719384308"
snd.Volume  = 0.5

local function play_toggle_sound()
    if not VC.sounds_enabled then return end
    pcall(function() snd:Play() end)
end

-- ════════════════════════════════════════════
-- MANIPULATION (raycast-assisted fire)
-- ════════════════════════════════════════════
local manip_ray_params = RaycastParams.new()
local manip_offsets = {
    Vector3.new(0,12,0), Vector3.new(0,16,0), Vector3.new(0,20,0),
    Vector3.new(0,24,0), Vector3.new(0,28,0), Vector3.new(0,32,0),
    Vector3.new(0,36,0), Vector3.new(0,40,0),
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
-- MELEE BYPASS (godmode hitbox suppress)
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
-- VOID INTERNALS (hardened)
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
        return Vector3.new(
            (math.random()<.5) and (math.random()*(VC.vs_dir_xp or 5000)) or (-math.random()*(VC.vs_dir_xn or 5000)),
            (math.random()<.5) and (math.random()*(VC.vs_dir_yp or 5000)) or (-math.random()*(VC.vs_dir_yn or 5000)),
            (math.random()<.5) and (math.random()*(VC.vs_dir_zp or 5000)) or (-math.random()*(VC.vs_dir_zn or 5000))
        )
    else
        local ir = math.max(VC.evs_iter_radius or 500000, 1)
        return Vector3.new(
            (math.random()<.5 and 1 or -1)*(ir*(0.5+math.random()*0.5)),
            (math.random()<.5 and 1 or -1)*(ir*(0.5+math.random()*0.5)),
            (math.random()<.5 and 1 or -1)*(ir*(0.5+math.random()*0.5))
        )
    end
end

local function vst_do_defend_burst(hrp)
    if getgenv().VoidPaused then return end
    vst_nuke_fallen()
    local iters     = math.clamp(VC.et_total or 500, 1, 500)
    local ir        = math.max(VC.evs_iter_radius or 500000, 1)
    local base_dist = ir * (0.5 + math.random() * 0.5)
    local restore   = hrp.CFrame

    for _ = 1, iters do
        local base   = vst_last_pos or hrp.Position
        local offset = vst_get_dir_offset(base_dist)
        pcall(function()
            hrp.CFrame = CFrame.new(base + offset)
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        vst_last_pos = hrp.Position
    end

    if VC.vs_stabilizer_enabled then
        local damp = 1 - (VC.vs_stability or 50) / 100
        hrp.AssemblyLinearVelocity  = hrp.AssemblyLinearVelocity  * damp
        hrp.AssemblyAngularVelocity = hrp.AssemblyAngularVelocity * damp
    else
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    if VC.vs_pos_restore then
        pcall(function()
            hrp.CFrame = restore
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        vst_last_pos = restore.Position
    end
    vst_nuke_fallen()
end

local function vst_do_prox_escape(hrp)
    if not VC.vst_defend_proximity_escape then return end
    local esc_r = math.max(VC.vst_defend_proximity_radius or 20, 1)
    local esc_d = math.max(VC.vst_defend_escape_dist or 1000, 1)
    local my_p  = hrp.Position

    for _, p in ipairs(plrs:GetPlayers()) do
        if p ~= lplr and p.Character then
            local th  = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if th and hum and hum.Health > 0 and (my_p - th.Position).Magnitude <= esc_r then
                local ir   = math.max(VC.evs_iter_radius or 500000, 1)
                local iter = my_p
                for _ = 1, math.clamp(VC.et_total or 500, 1, 500) do
                    local sx = math.random() < .5 and 1 or -1
                    local sy = math.random() < .5 and 1 or -1
                    local sz = math.random() < .5 and 1 or -1
                    pcall(function()
                        hrp.CFrame = CFrame.new(
                            iter.X + sx * (esc_d + math.random() * esc_d * 9),
                            iter.Y + sy * (ir * (0.5 + math.random() * 0.5)),
                            iter.Z + sz * (esc_d + math.random() * esc_d * 9)
                        )
                        hrp.AssemblyLinearVelocity  = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end)
                    iter = hrp.Position
                end
                vst_last_pos = hrp.Position
                return
            end
        end
    end
end

-- ════════════════════════════════════════════
-- VOIDSPAM TYPE SYSTEM (hardened)
-- ════════════════════════════════════════════
local vst_conn       = nil
local void_spin_conn = nil
local vst_pre_cf     = nil

getgenv().start_voidspam_type = function()
    if vst_conn then vst_conn:Disconnect() end
    if void_spin_conn then void_spin_conn:Disconnect() end
    vst_last_pos = nil
    local hrp0 = getgenv().get_hrp(lplr)
    if hrp0 and not vst_pre_cf then vst_pre_cf = hrp0.CFrame end

    void_spin_conn = runS.Heartbeat:Connect(function()
        if not VC.vst_enabled then return end
        local char = lplr.Character
        if not char then return end
        local spd = VC.vst_spin_speed or 1e85
        local ang = (tick() * spd) % (2 * math.pi)
        local scf = CFrame.Angles(0, ang, 0)
        pcall(function()
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("Motor6D") then v.Transform = scf end
            end
        end)
    end)

    vst_conn = runS.Heartbeat:Connect(function()
        if not VC.vst_enabled then return end
        vst_nuke_fallen()
        local hrp = getgenv().get_hrp(lplr)
        local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        if hum:GetState() ~= Enum.HumanoidStateType.Physics then
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end

        local vtype = VC.vst_type or "Unhittability"

        if vtype == "Unhittability" then
            vst_do_defend_burst(hrp)
            local yr = math.max(VC.vst_unhittability_y_range or 10, 1)
            pcall(function()
                for _, p in pairs(plrs:GetPlayers()) do
                    if p ~= lplr and p.Character then
                        local eh = p.Character:FindFirstChild("HumanoidRootPart")
                        if eh then
                            local yd = hrp.Position.Y - eh.Position.Y
                            if yd >= 0 and yd <= yr then
                                melee_fake_cf_store[p] = eh.CFrame
                                local mt = getrawmetatable(eh)
                                local ni = mt and rawget(mt, "__newindex")
                                local fake = CFrame.new(MELEE_FAKE_OFFSET)
                                if ni then pcall(ni, eh, "CFrame", fake)
                                else pcall(function() rawset(eh, "CFrame", fake) end) end
                                eh.AssemblyLinearVelocity  = Vector3.zero
                                eh.AssemblyAngularVelocity = Vector3.zero
                            else
                                melee_fake_cf_store[p] = nil
                            end
                        end
                    end
                end
            end)
            vst_do_prox_escape(hrp)

        elseif vtype == "Defend" then
            vst_do_defend_burst(hrp)
            vst_do_prox_escape(hrp)

        elseif vtype == "Bait" then
            if getgenv().VoidPaused then return end
            local cur = hrp.Position
            pcall(function()
                hrp.CFrame = CFrame.new(cur.X, cur.Y - math.clamp(VC.vst_bait_depth or 20, 1, 40), cur.Z)
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)

        elseif vtype == "Extreme" then
            if getgenv().VoidPaused then return end
            local cur = hrp.Position
            pcall(function()
                hrp.CFrame = CFrame.new(cur.X, cur.Y - 9e25, cur.Z)
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end)
end

getgenv().stop_voidspam_type = function()
    if vst_conn then vst_conn:Disconnect(); vst_conn = nil end
    if void_spin_conn then void_spin_conn:Disconnect(); void_spin_conn = nil end
    vst_last_pos = nil
end

getgenv().disable_voidspam_type = function()
    VC.vst_enabled = false
    getgenv().stop_voidspam_type()
    local hrp  = getgenv().get_hrp(lplr)
    local char = lplr.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hrp then
        pcall(function()
            hrp.CFrame = vst_pre_cf or hrp.CFrame
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if hum then
        pcall(function() hum.AutoRotate    = true  end)
        pcall(function() hum.PlatformStand = false end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        task.defer(function()
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        end)
    end
    if char then
        pcall(function()
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("Motor6D") then v.Transform = CFrame.new() end
            end
        end)
    end
    vst_pre_cf           = nil
    melee_fake_cf_store  = {}
    getgenv().VoidPaused = false
end

-- ════════════════════════════════════════════
-- EXTRA VOIDSPAM (hardened)
-- ════════════════════════════════════════════
local evs_conn     = nil
local evs_tick_acc = 0

getgenv().start_extra_voidspam = function()
    if evs_conn then evs_conn:Disconnect() end
    evs_tick_acc = 0
    evs_conn = runS.Heartbeat:Connect(function(dt)
        if not VC.vst_enabled   then return end
        if getgenv().VoidPaused then return end
        local hrp = getgenv().get_hrp(lplr)
        local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        if hum:GetState() ~= Enum.HumanoidStateType.Physics then
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end
        evs_tick_acc = evs_tick_acc + dt
        if evs_tick_acc < 1/60 then return end
        evs_tick_acc = evs_tick_acc - 1/60

        local snap     = hrp.CFrame
        local iter_pos = hrp.Position
        local burst    = math.clamp(VC.evs_burst or 100, 1, 1000)
        local mn, mx   = VC.vs_min_dist or 1, VC.vs_max_dist or 50000

        for _ = 1, burst do
            local d  = mn + math.random() * (mx - mn)
            local tp = Vector3.new(
                iter_pos.X + (math.random() < .5 and 1 or -1) * d,
                iter_pos.Y + (math.random() < .5 and 1 or -1) * d,
                iter_pos.Z + (math.random() < .5 and 1 or -1) * d
            )
            pcall(function()
                hrp.CFrame = CFrame.new(tp)
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            iter_pos = hrp.Position
        end

        if VC.evs_kill_velocity then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        if VC.evs_snap_back then
            pcall(function()
                hrp.CFrame = snap
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end)
end

getgenv().stop_extra_voidspam = function()
    if evs_conn then evs_conn:Disconnect(); evs_conn = nil end
end

-- ════════════════════════════════════════════
-- RAGEBOT CORE
-- ════════════════════════════════════════════
local slots = {Primary=1, Secondary=2, Melee=3}
local function getSlotNumber() return slots[RC.WeaponSlot] or 3 end

task.spawn(function()
    local lf = FC.LocalFighter
    while not lf do task.wait(0.1); lf = FC.LocalFighter end
    pcall(function() lf:EquipItem(getSlotNumber()) end)
end)

task.spawn(function()
    while true do
        task.wait(1)
        if RC.Enabled then
            local lf = FC.LocalFighter
            if lf then pcall(function() lf:EquipItem(getSlotNumber()) end) end
        end
    end
end)

local lastFire   = 0
local deflecting = {}
plrs.PlayerRemoving:Connect(function(p) deflecting[p] = nil end)

local function updateDeflection()
    if not FC or not FC.Objects then return end
    for _, fo in FC.Objects do
        local player = fo.Player
        if not player then continue end
        if not fo.Entity or not fo.Entity:IsAlive() or fo:Get("IsSpectating") then
            deflecting[player] = false; continue
        end
        local eq  = fo.EquippedItem
        local isK = eq and eq.ViewModel and eq.ViewModel.Name == "Katana"
        local isD = false
        if isK then isD = (eq._attack_cooldown and eq._attack_cooldown > tick()) or false end
        deflecting[player] = isD
    end
end

local function isEnemy(player)
    if player == lplr then return false end
    if not RC.TeamCheck then return true end
    local duel = SC.CurrentDuelSubject
    local ld   = duel and duel:GetDueler(lplr)
    local lt   = ld and ld:Get("TeamID") or nil
    if lt and duel and duel.Duelers then
        for _, d in duel.Duelers do
            if d.Player == player then return d:Get("TeamID") ~= lt end
        end
    end
    local pT = player:GetAttribute("TeamID")
    local lT = lplr:GetAttribute("TeamID")
    if pT and lT then return pT ~= lT end
    return true
end

local function getClosestTarget()
    local char = lplr.Character
    if not char then return nil,nil,nil end
    local myR = char:FindFirstChild("HumanoidRootPart")
    if not myR then return nil,nil,nil end
    local cp, cr, ch, cd = nil, nil, nil, 500
    for _, p in plrs:GetPlayers() do
        if not isEnemy(p) then continue end
        local pc  = p.Character
        if not pc then continue end
        local pR  = pc:FindFirstChild("HumanoidRootPart")
        local pH  = pc:FindFirstChild("Head")
        local pHm = pc:FindFirstChildWhichIsA("Humanoid")
        if not (pR and pH and pHm and pHm.Health > 0) then continue end
        local d = (myR.Position-pR.Position).Magnitude
        if d < cd then cd=d; cp=p; cr=pR; ch=pH end
    end
    return cp, cr, ch
end

local function hasKnifeViewModel(tp)
    if not tp then return false end
    local vm = ws:FindFirstChild("ViewModels")
    if not vm then return false end
    for _, m in vm:GetChildren() do
        if m:IsA("Model")
           and string.find(m.Name, tp.Name, 1, true)
           and string.find(m.Name, "Knife", 1, true) then
            return true
        end
    end
    return false
end

-- ════════════════════════════════════════════
-- TAP SYSTEM
-- ════════════════════════════════════════════
local tap_conn     = nil
local tap_holding  = false
local UserInputService = game:GetService("UserInputService")

local function do_tap()
    if not TAP.enabled then return end
    local lf = FC and FC.LocalFighter
    if not lf then return end
    local item = lf.EquippedItem
    if not item then return end
    task.delay(TAP.delay or 0.08, function()
        pcall(function()
            local cp, cr, ch = getClosestTarget()
            if not cp or not ch then return end
            local aimCF = CFrame.lookAt(ws.CurrentCamera.CFrame.Position, ch.Position)
            local cd = {}
            cd[utf8.char(1)] = {
                [utf8.char(0)] = util:EncodeCFrame(aimCF),
                [utf8.char(1)] = util:EncodeCFrame(ch.CFrame),
                [utf8.char(2)] = ch,
                [utf8.char(3)] = util:EncodeCFrame(CFrame.new(0,0,0)),
            }
            repS.Remotes.Replication.Fighter.UseItem:FireServer(
                item:Get("ObjectID"), enum:ToEnum("StartShooting"), cd, nil)
        end)
    end)
end

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == TAP.tap_key then
        tap_holding = true
        if TAP.enabled and not TAP.auto_tap then do_tap() end
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.KeyCode == TAP.tap_key then tap_holding = false end
end)

task.spawn(function()
    while true do
        task.wait(TAP.delay or 0.08)
        if TAP.enabled and TAP.auto_tap and tap_holding then
            do_tap()
        end
    end
end)

-- ════════════════════════════════════════════
-- RAGEBOT HEARTBEAT (void pauses on shot)
-- ════════════════════════════════════════════
runS.Heartbeat:Connect(function()
    updateDeflection()
    local targetPlayer, targetRoot, targetHead = getClosestTarget()
    local desyncCF = nil

    if targetRoot and targetHead then
        local dp = hasKnifeViewModel(targetPlayer)
            and (targetRoot.CFrame * CFrame.new(0, 8, -18)).Position
            or  (targetRoot.CFrame * CFrame.new(0, 3, -20)).Position
        desyncCF = CFrame.lookAt(dp, targetHead.Position)
    end

    if desyncCF and lplr.Character then
        local myR = lplr.Character:FindFirstChild("HumanoidRootPart")
        if myR then
            local oCF = myR.CFrame
            local oV  = myR.Velocity
            local oRV = myR.RotVelocity
            myR.CFrame = desyncCF
            runS:BindToRenderStep("__restore", 101, function()
                if myR then
                    myR.CFrame      = oCF
                    myR.Velocity    = oV
                    myR.RotVelocity = oRV
                end
                runS:UnbindFromRenderStep("__restore")
            end)
        end
    end

    if not RC.Enabled then return end
    if not targetPlayer or not targetHead or not targetRoot then return end
    if deflecting[targetPlayer] then return end
    if not lplr.Character or not lplr.Character:FindFirstChild("HumanoidRootPart") then return end
    if not FC or not FC.LocalFighter then return end
    local item = FC.LocalFighter.EquippedItem
    if not item then return end
    if tick()-lastFire < RC.FireRate then return end
    lastFire = tick()

    local originPos = desyncCF and desyncCF.Position or targetRoot.Position
    local aimCF     = CFrame.lookAt(originPos, targetHead.Position)
    local cameradata = {}
    cameradata[utf8.char(1)] = {
        [utf8.char(0)] = util:EncodeCFrame(aimCF),
        [utf8.char(1)] = util:EncodeCFrame(targetHead.CFrame),
        [utf8.char(2)] = targetHead,
        [utf8.char(3)] = util:EncodeCFrame(CFrame.new(0,0,0)),
    }

    getgenv().VoidPaused = true

    repS.Remotes.Replication.Fighter.UseItem:FireServer(
        item:Get("ObjectID"),
        enum:ToEnum("StartShooting"),
        cameradata,
        nil
    )

    if TAP.tap_on_fire then do_tap() end

    task.defer(function()
        getgenv().VoidPaused = false
    end)
end)

-- ════════════════════════════════════════════
-- OBSIDIAN UI LIBRARY
-- ════════════════════════════════════════════
pcall(function() setthreadidentity(8) end)

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager= loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

if not Library then
    warn("[always.winning] UI load failed — ragebot + void still running")
    notify("always.winning", "UI failed. Script still active.")
    return
end

-- ════════════════════════════════════════════
-- CREATE WINDOW
-- ════════════════════════════════════════════
local Window = Library:CreateWindow({
    Title        = "always.winning",
    Center       = true,
    AutoShow     = true,
    TabPadding   = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Ragebot  = Window:AddTab("Ragebot"),
    Void     = Window:AddTab("Void"),
    Tap      = Window:AddTab("Tap"),
    Settings = Window:AddTab("Settings"),
}

-- ════════════════════════════════════════════
-- TAB: RAGEBOT
-- ════════════════════════════════════════════
local BoxRB = Tabs.Ragebot:AddLeftGroupbox("Ragebot")

BoxRB:AddToggle("rb_enabled", {
    Text    = "Enabled",
    Default = RC.Enabled,
}):OnChanged(function(v) RC.Enabled = v; play_toggle_sound() end)

BoxRB:AddToggle("rb_team", {
    Text    = "Team Check",
    Default = RC.TeamCheck,
}):OnChanged(function(v) RC.TeamCheck = v end)

BoxRB:AddDropdown("rb_slot", {
    Text    = "Weapon Slot",
    Default = 3,
    Values  = {"Primary","Secondary","Melee"},
}):OnChanged(function(v)
    RC.WeaponSlot = v
    local lf = FC.LocalFighter
    if lf then pcall(function() lf:EquipItem(getSlotNumber()) end) end
end)

BoxRB:AddSlider("rb_firerate", {
    Text     = "Fire Rate",
    Default  = 5,
    Min      = 1,
    Max      = 100,
    Rounding = 0,
    Tooltip  = "1 = fastest (0.0001s)",
}):OnChanged(function(v) RC.FireRate = v * 0.0001 end)

BoxRB:AddDivider()

BoxRB:AddLabel("Godmode (Melee Bypass)")
BoxRB:AddToggle("gm_en", {
    Text    = "Enable Godmode",
    Default = false,
    Tooltip = "Standalone hitbox suppression",
}):OnChanged(function(v)
    VC.melee_bypass_enabled = v
    play_toggle_sound()
    if v then getgenv().start_melee_bypass() else getgenv().stop_melee_bypass() end
end)

BoxRB:AddSlider("gm_yr", {
    Text     = "Godmode Y Range",
    Default  = 10,
    Min      = 1,
    Max      = 50,
    Rounding = 0,
}):OnChanged(function(v) VC.melee_bypass_y_range = v end)

local BoxRBR = Tabs.Ragebot:AddRightGroupbox("Status Info")
BoxRBR:AddLabel("Void pauses on shot,")
BoxRBR:AddLabel("resumes next frame.")
BoxRBR:AddLabel("Hitbox suppress active")
BoxRBR:AddLabel("while firing.")
BoxRBR:AddDivider()
BoxRBR:AddLabel("Tap fires on ragebot")
BoxRBR:AddLabel("hit when enabled.")

-- ════════════════════════════════════════════
-- TAB: VOID
-- ════════════════════════════════════════════
local VT = Tabs.Void:AddLeftTabbox()
local VM = VT:AddTab("Main")
local VA = VT:AddTab("Advanced")

VM:AddToggle("vs_en", {
    Text    = "Void (Unhittability)",
    Default = false,
    Tooltip = "Pauses while ragebot fires",
}):OnChanged(function(v)
    VC.vst_enabled = v
    play_toggle_sound()
    if v then
        getgenv().start_voidspam_type()
        getgenv().start_extra_voidspam()
        if VC.vst_type == "Unhittability" then
            VC.melee_bypass_enabled = true
            if not melee_active then getgenv().start_melee_bypass() end
        end
    else
        getgenv().disable_voidspam_type()
        getgenv().stop_extra_voidspam()
        getgenv().stop_melee_bypass()
    end
end)

VM:AddDropdown("vs_type", {
    Text    = "Void Mode",
    Default = 1,
    Values  = {"Unhittability","Defend","Bait","Extreme"},
}):OnChanged(function(v)
    VC.vst_type = v
    if VC.vst_enabled then
        getgenv().stop_voidspam_type()
        getgenv().start_voidspam_type()
        if v == "Unhittability" then
            VC.melee_bypass_enabled = true
            if not melee_active then getgenv().start_melee_bypass() end
        else
            getgenv().stop_melee_bypass()
        end
    end
end)

VM:AddDropdown("vs_void_dir", {
    Text    = "Void Direction",
    Default = 1,
    Values  = {"Random","Forward","Backward","Left","Right","Up","Down","Directional"},
}):OnChanged(function(v) VC.vs_void_direction = v end)

VM:AddSlider("vs_spin_spd", {
    Text     = "Spin Speed",
    Default  = 1000000,
    Min      = 1,
    Max      = 1000000,
    Rounding = 0,
}):OnChanged(function(v) VC.vst_spin_speed = v end)

VM:AddSlider("vs_unhit_yr", {
    Text     = "Hitbox Suppress Range",
    Default  = 10,
    Min      = 1,
    Max      = 50,
    Rounding = 0,
    Tooltip  = "Y-studs below you to suppress enemy HRPs",
}):OnChanged(function(v)
    VC.vst_unhittability_y_range = v
    VC.melee_bypass_y_range      = v
end)

VM:AddToggle("vs_prox_esc", {
    Text    = "Proximity Escape",
    Default = true,
}):OnChanged(function(v) VC.vst_defend_proximity_escape = v end)

VM:AddSlider("vs_prox_r", {
    Text     = "Escape Trigger Radius",
    Default  = 20,
    Min      = 1,
    Max      = 200,
    Rounding = 0,
}):OnChanged(function(v) VC.vst_defend_proximity_radius = v end)

VM:AddSlider("vs_esc_dist", {
    Text     = "Escape Distance",
    Default  = 1000,
    Min      = 100,
    Max      = 10000,
    Rounding = 0,
}):OnChanged(function(v) VC.vst_defend_escape_dist = v end)

VM:AddSlider("vs_bait_sl", {
    Text     = "Bait Depth",
    Default  = 20,
    Min      = 1,
    Max      = 40,
    Rounding = 0,
}):OnChanged(function(v) VC.vst_bait_depth = v end)

-- Advanced void tab
VA:AddSlider("vs_iters", {
    Text     = "Iterations",
    Default  = 500,
    Min      = 1,
    Max      = 500,
    Rounding = 0,
}):OnChanged(function(v) VC.et_total = v end)

VA:AddSlider("vs_iter_rad", {
    Text     = "Iteration Radius",
    Default  = 500000,
    Min      = 1,
    Max      = 100000000,
    Rounding = 0,
}):OnChanged(function(v) VC.evs_iter_radius = v end)

VA:AddSlider("vs_min_d", {
    Text     = "Min Distance",
    Default  = 1,
    Min      = 1,
    Max      = 50000,
    Rounding = 0,
}):OnChanged(function(v) VC.vs_min_dist = v end)

VA:AddSlider("vs_max_d", {
    Text     = "Max Distance",
    Default  = 50000,
    Min      = 1,
    Max      = 500000,
    Rounding = 0,
}):OnChanged(function(v) VC.vs_max_dist = v end)

VA:AddSlider("evs_burst_sl", {
    Text     = "EVS Burst",
    Default  = 100,
    Min      = 1,
    Max      = 1000,
    Rounding = 0,
}):OnChanged(function(v) VC.evs_burst = v end)

VA:AddToggle("vs_stab", {
    Text    = "Stabilizer",
    Default = false,
}):OnChanged(function(v) VC.vs_stabilizer_enabled = v end)

VA:AddSlider("vs_stab_sl", {
    Text     = "Stability",
    Default  = 50,
    Min      = 1,
    Max      = 100,
    Rounding = 0,
}):OnChanged(function(v) VC.vs_stability = v end)

VA:AddToggle("vs_kv", {
    Text    = "Kill Velocity",
    Default = true,
}):OnChanged(function(v) VC.evs_kill_velocity = v end)

VA:AddToggle("vs_snap", {
    Text    = "Snap Back",
    Default = false,
}):OnChanged(function(v) VC.evs_snap_back = v end)

VA:AddToggle("vs_restore", {
    Text    = "Position Restore",
    Default = false,
}):OnChanged(function(v) VC.vs_pos_restore = v end)

-- Void right column: directional config
local VR = Tabs.Void:AddRightGroupbox("Directional Config")
VR:AddLabel("Used when direction = Directional")
VR:AddSlider("vd_xp",{Text="X+",Default=5000,Min=1,Max=100000000,Rounding=0}):OnChanged(function(v) VC.vs_dir_xp=v end)
VR:AddSlider("vd_xn",{Text="X-",Default=5000,Min=1,Max=100000000,Rounding=0}):OnChanged(function(v) VC.vs_dir_xn=v end)
VR:AddSlider("vd_yp",{Text="Y+",Default=5000,Min=1,Max=100000000,Rounding=0}):OnChanged(function(v) VC.vs_dir_yp=v end)
VR:AddSlider("vd_yn",{Text="Y-",Default=5000,Min=1,Max=100000000,Rounding=0}):OnChanged(function(v) VC.vs_dir_yn=v end)
VR:AddSlider("vd_zp",{Text="Z+",Default=5000,Min=1,Max=100000000,Rounding=0}):OnChanged(function(v) VC.vs_dir_zp=v end)
VR:AddSlider("vd_zn",{Text="Z-",Default=5000,Min=1,Max=100000000,Rounding=0}):OnChanged(function(v) VC.vs_dir_zn=v end)

local VR2 = Tabs.Void:AddRightGroupbox("Quick Presets")
VR2:AddButton("Aggressive", function()
    VC.et_total=500; VC.evs_burst=500; VC.evs_iter_radius=1000000; VC.vs_max_dist=100000
    notify("always.winning","Preset: Aggressive")
end)
VR2:AddButton("Balanced", function()
    VC.et_total=300; VC.evs_burst=100; VC.evs_iter_radius=500000; VC.vs_max_dist=50000
    notify("always.winning","Preset: Balanced")
end)
VR2:AddButton("Light", function()
    VC.et_total=100; VC.evs_burst=50; VC.evs_iter_radius=200000; VC.vs_max_dist=20000
    notify("always.winning","Preset: Light")
end)

-- ════════════════════════════════════════════
-- TAB: TAP
-- ════════════════════════════════════════════
local BoxTap = Tabs.Tap:AddLeftGroupbox("Tap Settings")

BoxTap:AddToggle("tap_en", {
    Text    = "Tap Enabled",
    Default = TAP.enabled,
    Tooltip = "Fire a delayed tap after each ragebot hit",
}):OnChanged(function(v) TAP.enabled = v; play_toggle_sound() end)

BoxTap:AddToggle("tap_auto", {
    Text    = "Auto Tap (hold key)",
    Default = TAP.auto_tap,
    Tooltip = "Continuously tap while holding the key",
}):OnChanged(function(v) TAP.auto_tap = v end)

BoxTap:AddToggle("tap_on_fire", {
    Text    = "Tap on Ragebot Fire",
    Default = TAP.tap_on_fire,
    Tooltip = "Fire tap automatically when ragebot fires",
}):OnChanged(function(v) TAP.tap_on_fire = v end)

BoxTap:AddSlider("tap_delay", {
    Text     = "Tap Delay (ms)",
    Default  = 80,
    Min      = 1,
    Max      = 500,
    Rounding = 0,
}):OnChanged(function(v) TAP.delay = v / 1000 end)

BoxTap:AddLabel("Tap Keybind"):AddKeyPicker("tap_key_bind", {
    Default = "E",
    Text    = "Tap Key",
    NoUI    = false,
}):OnChanged(function(v)
    local ok, kc = pcall(function() return Enum.KeyCode[v] end)
    if ok and kc then TAP.tap_key = kc end
end)

BoxTap:AddDivider()
BoxTap:AddButton("Manual Tap", function()
    if TAP.enabled then do_tap() end
end)

local BoxTapR = Tabs.Tap:AddRightGroupbox("Tap Info")
BoxTapR:AddLabel("Tap fires UseItem after")
BoxTapR:AddLabel("a configurable delay.")
BoxTapR:AddLabel("Works with Void active.")
BoxTapR:AddLabel("Auto-tap: hold E key.")
BoxTapR:AddLabel("Tap on Fire: triggers")
BoxTapR:AddLabel("on every ragebot shot.")

-- ════════════════════════════════════════════
-- TAB: SETTINGS
-- ════════════════════════════════════════════
local BoxMenu = Tabs.Settings:AddLeftGroupbox("Menu")

BoxMenu:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI    = true,
    Text    = "Menu keybind",
})

BoxMenu:AddButton("Unload", function()
    RC.Enabled = false
    getgenv().disable_voidspam_type()
    getgenv().stop_extra_voidspam()
    getgenv().stop_melee_bypass()
    getgenv().AlwaysWinning.Unload()
    pcall(Library.Unload, Library)
end)

BoxMenu:AddDivider()
BoxMenu:AddLabel("always.winning")
BoxMenu:AddLabel("Ragebot + Void + Tap")

local BoxSnd = Tabs.Settings:AddRightGroupbox("Sounds")

BoxSnd:AddToggle("snd_en", {
    Text    = "Sounds",
    Default = false,
}):OnChanged(function(v) VC.sounds_enabled = v end)

BoxSnd:AddSlider("snd_vol", {
    Text     = "Volume",
    Default  = 50,
    Min      = 0,
    Max      = 100,
    Rounding = 0,
}):OnChanged(function(v) snd.Volume = v/100; VC.sound_volume = v/100 end)

BoxSnd:AddButton("Test Sound", function()
    local prev = VC.sounds_enabled
    VC.sounds_enabled = true
    play_toggle_sound()
    VC.sounds_enabled = prev
end)

-- ════════════════════════════════════════════
-- THEME + SAVE MANAGER
-- ════════════════════════════════════════════
if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:ApplyToTab(Tabs.Settings)
end

if SaveManager then
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({"MenuKeybind"})
    SaveManager:SetFolder("always_winning/configs")
    SaveManager:BuildConfigSection(Tabs.Settings)
    pcall(SaveManager.LoadAutoloadConfig, SaveManager)
end

Library.ToggleKeybind = Library.Options.MenuKeybind

-- ════════════════════════════════════════════
-- UNLOAD HANDLER
-- ════════════════════════════════════════════
getgenv().AlwaysWinning.Unload = function()
    RC.Enabled = false
    getgenv().disable_voidspam_type()
    getgenv().stop_extra_voidspam()
    getgenv().stop_melee_bypass()
end

print("[always.winning] loaded | Ragebot + Void + Tap | Obsidian UI")

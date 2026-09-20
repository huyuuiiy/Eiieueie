if not game:IsLoaded() then game.Loaded:Wait() end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Lighting         = game:GetService("Lighting")
local Debris           = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local function Cam() return Workspace.CurrentCamera end

-- =========================================================================
-- ANTI-CHEAT BYPASS
-- Layer A – Generic: blocks OPT-FAIL / Illegal Hit Registration kicks and
--           any indexInstance-based kick/namecall handler.
-- Layer B – Adonis-specific: no-ops Detected AND Kill, then hooks
--           getrenv().debug.info so Adonis can't fingerprint our hooks.
-- All layers are wrapped in pcall so a missing API never breaks the script.
-- =========================================================================
pcall(function()
    -- ── LAYER A ──────────────────────────────────────────────────────────

    local hooked_A = {}
    local detected_A

    pcall(setthreadidentity, 2)

    -- A1) Scan GC: no-op the game's generic Detected callback
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "table" then
                local detect_func = rawget(v, "Detected")
                if typeof(detect_func) == "function" and not detected_A then
                    detected_A = detect_func
                    hookfunction(detected_A, newcclosure(function(action, info, no_crash)
                        return true  -- swallow detection
                    end))
                    table.insert(hooked_A, detected_A)
                end
            end
        end
    end)

    -- A2) Hook any kick/namecall handlers stored in indexInstance tables
    pcall(function()
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" then
                local ok2, index_inst = pcall(function() return rawget(v, "indexInstance") end)
                if ok2 and type(index_inst) == "table"
                    and #index_inst >= 2 and type(index_inst[2]) == "function" then
                    local label = tostring(index_inst[1]):lower()
                    if label == "kick" or label:find("namecall") then
                        pcall(hookfunction, index_inst[2], newcclosure(function(...)
                            return false
                        end))
                    end
                end
            end
        end
    end)

    -- A3) __namecall hook – silently drop any :Kick() the server fires on LocalPlayer
    pcall(function()
        local mt = getrawmetatable(game)
        if not mt then return end
        local old_namecall = mt.__namecall
        pcall(setreadonly, mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "Kick" and self == LocalPlayer and not checkcaller() then
                return  -- drop kick silently
            end
            return old_namecall(self, ...)
        end)
        pcall(setreadonly, mt, true)
    end)

    -- A4) Generic debug.getinfo spoof (fallback for non-Adonis AC)
    pcall(function()
        local getinfo_fn = (typeof(getinfo) == "function" and getinfo)
                        or (typeof(debug) == "table" and debug.getinfo)
        if not getinfo_fn then return end
        hookfunction(getinfo_fn, newcclosure(function(...)
            local args = { ... }
            local level = args[2] or 2
            if detected_A and level == 2 then
                return coroutine.yield(coroutine.running())
            end
            return getinfo_fn(...)
        end))
    end)

    -- ── LAYER B – ADONIS-SPECIFIC ─────────────────────────────────────────

    local detected_B  -- Adonis Detected fn
    local kill_B      -- Adonis Kill fn (fallback)
    local hooked_B = {}

    -- B1) GC scan: hook BOTH Detected and Kill inside Adonis tables
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "table" then
                local a = rawget(v, "Detected")
                local b = rawget(v, "Kill")

                -- Hook Detected
                if typeof(a) == "function" and not detected_B then
                    detected_B = a
                    hookfunction(detected_B, newcclosure(function(c, f, n)
                        -- c ~= "_" means a real flag; we eat it silently
                        return true
                    end))
                    table.insert(hooked_B, detected_B)
                end

                -- Hook Kill (Adonis fallback path that bypasses Detected)
                if rawget(v, "Variables") and rawget(v, "Process")
                    and typeof(b) == "function" and not kill_B then
                    kill_B = b
                    hookfunction(kill_B, newcclosure(function(f)
                        -- swallow the kill entirely
                    end))
                    table.insert(hooked_B, kill_B)
                end
            end
        end
    end)

    -- B2) Hook getrenv().debug.info – Adonis uses this to inspect call stacks
    --     and detect our hooks; we short-circuit it when called with Detected_B.
    pcall(function()
        local renv_debug_info = getrenv().debug.info
        if not renv_debug_info then return end
        local old_rdi = renv_debug_info
        hookfunction(old_rdi, newcclosure(function(a, f, ...)
            if detected_B and a == detected_B then
                return coroutine.yield(coroutine.running())
            end
            return old_rdi(a, f, ...)
        end))
    end)

    -- B3) Elevate thread identity to 7 so subsequent calls have full permissions
    pcall(setthreadidentity, 7)
end)

local HUB_FOLDER = "Nyven Hub"

if makefolder and isfolder then
    if not isfolder(HUB_FOLDER) then
        pcall(makefolder, HUB_FOLDER)
    end
end

-- =========================================================================
-- WINDUI LOAD
-- =========================================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- =========================================================================
-- LOGO + THEME BACKGROUND (same as Nyven Hub)
-- =========================================================================
local rawLogoLink    = "https://raw.githubusercontent.com/CalledSupremeForAReason/Image-Of-The-Hub/main/Image"
local customLogoPath = HUB_FOLDER .. "/NyvenHubLogo.jpeg"
local currentLogo    = "rbxassetid://132000967222696"

local THEME_URL  = "https://raw.githubusercontent.com/huyuuiiy/Eiieueie/refs/heads/main/cdc29a5e973d877bf988fde59b258173.jpg"
local THEME_PATH = HUB_FOLDER .. "/NyvenHubTheme.jpg"
local themeAsset = nil

if typeof(writefile) == "function" and typeof(isfile) == "function" and typeof(getcustomasset) == "function" then
    -- Logo
    if not isfile(customLogoPath) then
        local ok, data = pcall(function() return game:HttpGet(rawLogoLink) end)
        if ok and data then writefile(customLogoPath, data) end
    end
    if isfile(customLogoPath) then currentLogo = getcustomasset(customLogoPath) end

    -- Theme background
    if not isfile(THEME_PATH) then
        local ok, data = pcall(function() return game:HttpGet(THEME_URL) end)
        if ok and data and #data > 100 then writefile(THEME_PATH, data) end
    end
    if isfile(THEME_PATH) then
        local ok, asset = pcall(getcustomasset, THEME_PATH)
        if ok and asset and asset ~= "" then themeAsset = asset end
    end
end

-- =========================================================================
-- CONFIG (auto save / load)
-- =========================================================================
local CONFIG_PATH = HUB_FOLDER .. "/FlickConfig.json"
local cfg = {}

if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(CONFIG_PATH) then
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_PATH)) end)
    if ok and type(data) == "table" then cfg = data end
end

local saveQueued = false
local function Save()
    if saveQueued or typeof(writefile) ~= "function" then return end
    saveQueued = true
    task.delay(0.5, function()
        saveQueued = false
        pcall(writefile, CONFIG_PATH, HttpService:JSONEncode(cfg))
    end)
end

local S = {}
local function def(key, default)
    local v = cfg[key]
    if v == nil then v = default end
    S[key] = v
end
local function set(key, v)
    S[key] = v
    cfg[key] = v
    Save()
end

-- Misc
def("CustomGunSound", false)
def("CustomHitSoundEnabled", false)
def("HitSoundSelected", "Bell")
def("HitSoundVolume", 1)
-- Aimbot
def("AimbotEnabled", false)
def("AimbotMode", "Free for all")
def("AimbotPart", "Head")
def("AimbotSpeed", 50)
def("ShowFovCircle", false)
def("AimbotFOV", 400)
def("FovCircleThickness", 1)
def("SilentAimEnabled", false)

-- Player
def("TrailEnabled", false)
def("TrailColorName", "White")
def("PlayerESPBox", false)
def("PlayerESPName", false)
def("PlayerChamsEnabled", false)
def("PlayerChamsColor", "White")
def("WeaponLatex", false)
def("ArmLatex", false)
-- View
def("ThirdPersonEnabled", false)
def("ThirdPersonDistance", 7)
def("ThirdPersonActivation", "Always on")
-- World
def("SelectedSky", "Default")
def("BloomEnabled", false)
def("BloomValue", 20)
def("SelectedAmbient", "Disabled")
def("Weather", "Off")
-- Movement
def("AutoJumpEnabled", false)
def("AirStrafeEnabled", false)
def("AirStrafeStrength", 20)
def("AutoMoveEnabled", false)

-- =========================================================================
-- HELPERS
-- =========================================================================
local function NewDrawing(kind)
    local ok, obj = pcall(function() return Drawing.new(kind) end)
    if ok and obj then return obj end
    return { Remove = function() end } -- executor without Drawing: harmless stub
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function HasLineOfSight(part)
    local origin = Cam().CFrame.Position
    local dir = part.Position - origin
    if dir.Magnitude <= 0 then return true end
    local ignore = { Cam() }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    rayParams.FilterDescendantsInstances = ignore
    local res = Workspace:Raycast(origin, dir, rayParams)
    return res == nil or res.Instance:IsDescendantOf(part.Parent)
end

-- Removes the game's invisible black highlights
local function CleanHighlight(o)
    if o:IsA("Highlight") and o.OutlineColor == Color3.fromRGB(0, 0, 0) and o.FillTransparency == 1 then
        o:Destroy()
    end
end
for _, d in ipairs(game:GetDescendants()) do CleanHighlight(d) end
game.DescendantAdded:Connect(CleanHighlight)
task.spawn(function()
    while task.wait(10) do
        for _, d in ipairs(Workspace:GetDescendants()) do CleanHighlight(d) end
    end
end)

-- =========================================================================
-- MISC: GUN SOUND / HIT SOUND
-- =========================================================================
local CUSTOM_GUN   = "rbxassetid://95544129057345"
local REVOLVER_GUN = "rbxassetid://14918579834"
local origGunIds   = setmetatable({}, { __mode = "k" })
local gunConn

local function ProcessGunSound(snd)
    if snd:IsA("Sound") and snd.Name == "GunShot" then
        if origGunIds[snd] == nil then origGunIds[snd] = snd.SoundId end
        if S.CustomGunSound then
            local model = snd:FindFirstAncestorWhichIsA("Model")
            snd.SoundId = (model and model.Name == "Revolver") and REVOLVER_GUN or CUSTOM_GUN
        else
            snd.SoundId = origGunIds[snd]
        end
    end
end

local function ApplyGunSound()
    for _, d in ipairs(game:GetDescendants()) do ProcessGunSound(d) end
    if S.CustomGunSound then
        if not gunConn then gunConn = game.DescendantAdded:Connect(ProcessGunSound) end
    elseif gunConn then
        gunConn:Disconnect()
        gunConn = nil
    end
end

local HitSounds = {
    Bell   = "rbxassetid://132596270805754",
    Metal  = "rbxassetid://9125672731",
    Growl  = "rbxassetid://136705296952779",
    Brutal = "rbxassetid://82176913611683",
    Scream = "rbxassetid://7772283448",
}
local DEFAULT_HIT = "rbxassetid://138705939667182"

local function ApplyHitSound()
    task.spawn(function()
        local pg = LocalPlayer:WaitForChild("PlayerGui", 10)
        local fx = pg and pg:WaitForChild("Effect", 10)
        if not fx then return end
        for _, name in ipairs({ "Crit", "Bang" }) do
            local s = fx:FindFirstChild(name)
            if s then
                s.SoundId = S.CustomHitSoundEnabled and HitSounds[S.HitSoundSelected] or DEFAULT_HIT
                s.Volume = S.HitSoundVolume / 100
            end
        end
    end)
end

-- =========================================================================
-- AIMBOT
-- =========================================================================
local AimCircle = NewDrawing("Circle")
AimCircle.Visible = false
AimCircle.NumSides = 100
AimCircle.Filled = false
AimCircle.Color = Color3.fromRGB(255, 255, 255)

local function AimPart(char)
    local p = S.AimbotPart
    if p == "Chest" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    elseif p == "Stomach" then
        return char:FindFirstChild("LowerTorso")
    elseif p == "Arms" then
        return char:FindFirstChild("RightUpperArm") or char:FindFirstChild("LeftUpperArm")
    elseif p == "Legs" then
        return char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("LeftUpperLeg")
    end
    return char:FindFirstChild("Head")
end

local function AimTarget()
    local camera = Cam()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local best, bestDist = nil, math.huge
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and (S.AimbotMode == "Free for all" or pl.Team ~= LocalPlayer.Team) then
            local char = pl.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local part = AimPart(char)
                if part then
                    local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen and HasLineOfSight(part) then
                        local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if d < S.AimbotFOV and d < bestDist then
                            best, bestDist = part, d
                        end
                    end
                end
            end
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    local camera = Cam()
    if not camera then return end
    AimCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    AimCircle.Radius = S.AimbotFOV
    AimCircle.Thickness = S.FovCircleThickness
    AimCircle.Visible = S.ShowFovCircle

    if not S.AimbotEnabled then return end
    local part = AimTarget()
    if part then
        local pos = camera.CFrame.Position
        local goal = CFrame.new(pos, part.Position)
        camera.CFrame = camera.CFrame:Lerp(goal, S.AimbotSpeed / 100)
    end
end)

-- =========================================================================
-- SILENT AIM + BULLET TRACER
-- =========================================================================
local TracerColors = {
    Red        = Color3.fromRGB(255, 0, 0),
    Green      = Color3.fromRGB(0, 255, 0),
    Pink       = Color3.fromRGB(255, 50, 255),
    Toothpaste = Color3.fromRGB(72, 176, 243),
    White      = Color3.fromRGB(255, 223, 255),
}

-- OPT-FAIL is a server-side optical validation check.
-- The server compares the replicated camera direction against the registered
-- hit position. Snapping past ~90° is immediately flagged as impossible.
-- We cap silent aim to SILENT_MAX_ANGLE degrees off the current look vector
-- so every snap is within a physically plausible cone, and we hold the snap
-- for TWO frames so camera replication reaches the server before the shot
-- remote is processed (one frame was not enough on high-ping connections).
local SILENT_MAX_ANGLE = 85  -- degrees; stays within human reaction FOV

local function SilentTarget()
    local camera   = Cam()
    local origin   = camera.CFrame.Position
    local lookVec  = camera.CFrame.LookVector
    local best, bestDist = nil, 600

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local head = pl.Character:FindFirstChild("Head")
            if head then
                local d = (head.Position - origin).Magnitude
                if d <= bestDist and HasLineOfSight(head) then
                    -- Reject targets outside our plausible optical cone
                    local toTarget = (head.Position - origin).Unit
                    local dot      = math.clamp(lookVec:Dot(toTarget), -1, 1)
                    local angle    = math.deg(math.acos(dot))
                    if angle <= SILENT_MAX_ANGLE then
                        best, bestDist = head, d
                    end
                end
            end
        end
    end
    return best
end

local function SilentSnap()
    if not S.SilentAimEnabled then return end
    local head = SilentTarget()
    if not head then return end
    local camera = Cam()
    local old    = camera.CFrame
    camera.CFrame = CFrame.new(old.Position, head.Position)

    -- Also rotate the HumanoidRootPart so the character body faces the target;
    -- the server checks character orientation as well as camera direction.
    pcall(function()
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local flatDir = Vector3.new(
                head.Position.X - hrp.Position.X,
                0,
                head.Position.Z - hrp.Position.Z
            ).Unit
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flatDir)
        end
    end)

    -- Hold for TWO frames: first lets camera replication propagate,
    -- second ensures the fire remote is sent while the snap is active.
    RunService.RenderStepped:Wait()
    RunService.RenderStepped:Wait()
    camera.CFrame = old
end

local function SpawnTracer(muz, targetHead)
    local color = TracerColors[S.TrailColorName] or TracerColors.White

    local part = Instance.new("Part")
    part.Size = Vector3.new(0.9, 0.5, 1)
    part.Color = color
    part.Material = Enum.Material.Neon
    part.Anchored = false
    part.CanCollide = false
    part.CastShadow = false
    part.CFrame = muz.CFrame
    part.Parent = Workspace

    local a0 = Instance.new("Attachment", part)
    local a1 = Instance.new("Attachment", part)
    a0.Position = Vector3.new(0, 0, -0.15)
    a1.Position = Vector3.new(0, 0, 0.15)

    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.FaceCamera = true
    trail.Lifetime = 10
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.Brightness = 8
    trail.Color = ColorSequence.new(color)
    trail.Transparency = NumberSequence.new(0)
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.319),
        NumberSequenceKeypoint.new(1, 0.319),
    })
    trail.Enabled = true
    trail.Parent = part

    local dir
    if targetHead and S.SilentAimEnabled then
        dir = (targetHead.Position - muz.Position).Unit * 600
    else
        dir = Cam().CFrame.LookVector * 600
    end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(100000, 100000, 100000)
    bv.Velocity = dir
    bv.Parent = part

    Debris:AddItem(part, 13)
end

local function OnFire()
    SilentSnap()
    if not S.TrailEnabled then return end
    local char = LocalPlayer.Character
    local muz = char and char:FindFirstChild("Muz", true)
    if not (muz and muz:IsA("BasePart")) then return end
    local target = S.SilentAimEnabled and SilentTarget() or nil
    SpawnTracer(muz, target)
end

local fireConns = {}

local function FindFireButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local mc = pg:FindFirstChild("MobileControls")
    local fr = mc and mc:FindFirstChild("Frame")
    local btn = fr and fr:FindFirstChild("FireButton")
    if btn then return btn end
    for _, d in ipairs(pg:GetDescendants()) do
        if d.Name == "FireButton" and d:IsA("GuiButton") then return d end
    end
    return nil
end

-- Hooks mouse click + mobile fire button once the gun (Muz) exists in the character,
-- exactly like the original, so silent aim runs before the game's own shot.
local function HookFire(char)
    task.spawn(function()
        repeat task.wait(0.3) until not char.Parent or char:FindFirstChild("Muz", true)
        if not char.Parent or LocalPlayer.Character ~= char then return end

        for _, c in ipairs(fireConns) do c:Disconnect() end
        table.clear(fireConns)

        table.insert(fireConns, UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                task.spawn(OnFire)
            end
        end))

        if UserInputService.TouchEnabled then
            local btn
            for _ = 1, 120 do
                btn = FindFireButton()
                if btn or LocalPlayer.Character ~= char then break end
                task.wait(0.5)
            end
            if btn and LocalPlayer.Character == char then
                table.insert(fireConns, btn.MouseButton1Click:Connect(function()
                    task.spawn(OnFire)
                end))
            end
        end
    end)
end



-- =========================================================================
-- ANDROID UI ALWAYS ON + CLICK
-- On phones/tablets the game and Roblox must never react to "last input = mouse",
-- so the thumbstick, jump and fire buttons stay on even when we send mouse clicks.
-- =========================================================================
local IS_TOUCH = false
do
    local ok, platform = pcall(function() return UserInputService:GetPlatform() end)
    if ok and (platform == Enum.Platform.Android or platform == Enum.Platform.IOS) then
        IS_TOUCH = true
    elseif UserInputService.TouchEnabled then
        -- Mobile executors often report KeyboardEnabled/MouseEnabled as true even
        -- on a real phone, so we rely solely on TouchEnabled being present.
        IS_TOUCH = true
    end
end

if IS_TOUCH then
    local disabledConns = setmetatable({}, { __mode = "k" })
    local controlsPatched = false

    local function LockTouchUI()
        -- 1) Disable every connection listening for the input type changing
        if typeof(getconnections) == "function" then
            local ok, list = pcall(getconnections, UserInputService.LastInputTypeChanged)
            if ok and list then
                for _, c in ipairs(list) do
                    if not disabledConns[c] then
                        disabledConns[c] = true
                        pcall(function() c:Disable() end)
                    end
                end
            end
        end
        -- 2) Default controls can never switch away from touch
        if not controlsPatched then
            pcall(function()
                local pm = LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
                if pm then
                    local controls = require(pm):GetControls()
                    controls.OnLastInputTypeChanged = function() end
                    controlsPatched = true
                end
            end)
        end
    end

    LockTouchUI()
    task.spawn(function()
        while task.wait(0.2) do LockTouchUI() end
    end)

    -- 3) Helper: recursively force an entire GUI subtree visible
    local function ForceSubtreeVisible(root)
        if not root or not root.Parent then return end
        for _, d in ipairs(root:GetDescendants()) do
            -- Only touch GuiObjects; skip non-visual instances (scripts, etc.)
            if d:IsA("GuiObject") then
                d.Visible = true
            end
        end
    end

    -- 4) Every frame: re-enable TouchGui AND MobileControls and ALL their children.
    --    The game hides individual child elements (DynamicThumbstickFrame, FireButton,
    --    etc.) not just the top-level frame, so we must recurse into every descendant.
    RunService.RenderStepped:Connect(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end

        -- Roblox default thumbstick / jump button
        local tg = pg:FindFirstChild("TouchGui")
        if tg then
            tg.Enabled = true
            local frame = tg:FindFirstChild("TouchControlFrame")
            if frame then
                frame.Visible = true
                ForceSubtreeVisible(frame)   -- DynamicThumbstickFrame, etc.
            end
        end

        -- Game's custom mobile controls (fire button, weapon swap, etc.)
        local mc = pg:FindFirstChild("MobileControls")
        if mc then
            if mc:IsA("ScreenGui") then mc.Enabled = true end
            local frame = mc:FindFirstChild("Frame")
            if frame and frame:IsA("GuiObject") then
                frame.Visible = true
                ForceSubtreeVisible(frame)   -- FireButton and every sibling inside
            end
        end

        -- Safety net: search the whole PlayerGui for any FireButton or thumbstick
        -- that the two blocks above might have missed (e.g. different GUI name).
        local fb = pg:FindFirstChild("FireButton", true)
        if fb and fb:IsA("GuiObject") then fb.Visible = true end
        local dt = pg:FindFirstChild("DynamicThumbstickFrame", true)
        if dt and dt:IsA("GuiObject") then
            dt.Visible = true
            ForceSubtreeVisible(dt)
        end
    end)
end

local function DoClick()
    if mouse1click then
        pcall(mouse1click)
    elseif mousebuttonclick then
        pcall(mousebuttonclick, 1)
    elseif click then
        pcall(click)
    end
end


-- =========================================================================
-- PLAYER: CHAMS
-- =========================================================================
local ChamColors = {
    White  = Color3.fromRGB(255, 255, 255),
    Red    = Color3.fromRGB(255, 0, 0),
    Blue   = Color3.fromRGB(0, 0, 255),
    Green  = Color3.fromRGB(0, 255, 0),
    Yellow = Color3.fromRGB(255, 255, 0),
    Purple = Color3.fromRGB(128, 0, 128),
    Cyan   = Color3.fromRGB(0, 255, 255),
    Orange = Color3.fromRGB(255, 165, 0),
    Pink   = Color3.fromRGB(255, 105, 180),
    Black  = Color3.fromRGB(0, 0, 0),
}
local Chams = {}

local function ChamRemove(pl)
    if Chams[pl] then
        Chams[pl]:Destroy()
        Chams[pl] = nil
    end
end

local function ChamAdd(pl)
    if pl == LocalPlayer or not pl.Character then return end
    ChamRemove(pl)
    local h = Instance.new("Highlight")
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency = 0.5
    h.OutlineTransparency = 1
    h.FillColor = ChamColors[S.PlayerChamsColor] or ChamColors.White
    h.Parent = pl.Character
    Chams[pl] = h
end

local function ChamsRefresh()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            if S.PlayerChamsEnabled then ChamAdd(pl) else ChamRemove(pl) end
        end
    end
end

local function ChamHook(pl)
    if pl == LocalPlayer then return end
    pl.CharacterAdded:Connect(function(char)
        if S.PlayerChamsEnabled then
            char:WaitForChild("HumanoidRootPart", 5)
            task.wait(0.2)
            ChamAdd(pl)
        end
    end)
    pl.CharacterRemoving:Connect(function() ChamRemove(pl) end)
end
for _, pl in ipairs(Players:GetPlayers()) do ChamHook(pl) end
Players.PlayerAdded:Connect(ChamHook)
Players.PlayerRemoving:Connect(ChamRemove)

-- =========================================================================
-- PLAYER: ESP (BOX / NAME)
-- =========================================================================
local ESP_MAX_DISTANCE = 900
local EspObjects = {}

local function EspCreate(pl)
    if pl == LocalPlayer or EspObjects[pl] then return end
    local box = NewDrawing("Square")
    box.Thickness = 1
    box.Filled = false
    box.Visible = false
    box.Color = Color3.fromRGB(255, 255, 255)
    local txt = NewDrawing("Text")
    txt.Size = 8
    txt.Center = true
    txt.Outline = true
    txt.OutlineColor = Color3.new(1, 1, 1)
    txt.Visible = false
    EspObjects[pl] = { Box = box, Name = txt }
end

local function EspRemove(pl)
    local o = EspObjects[pl]
    if o then
        o.Box:Remove()
        o.Name:Remove()
        EspObjects[pl] = nil
    end
end

Players.PlayerAdded:Connect(EspCreate)
Players.PlayerRemoving:Connect(EspRemove)
for _, pl in ipairs(Players:GetPlayers()) do EspCreate(pl) end

RunService.RenderStepped:Connect(function()
    local camera = Cam()
    if not camera then return end
    for pl, o in pairs(EspObjects) do
        local char = pl.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if not (root and hum and hum.Health > 0)
            or (root.Position - camera.CFrame.Position).Magnitude > ESP_MAX_DISTANCE then
            o.Box.Visible = false
            o.Name.Visible = false
        else
            local pos, onScreen = camera:WorldToViewportPoint(root.Position)
            if not onScreen then
                o.Box.Visible = false
                o.Name.Visible = false
            else
                local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
                local bottom = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                local h = math.abs(bottom.Y - top.Y)
                local w = h / 2.3

                if S.PlayerESPBox then
                    o.Box.Size = Vector2.new(w, h)
                    o.Box.Position = Vector2.new(pos.X - w / 2, pos.Y - h / 2)
                    o.Box.Visible = true
                else
                    o.Box.Visible = false
                end

                if S.PlayerESPName then
                    o.Name.Text = pl.Name
                    o.Name.Position = Vector2.new(pos.X, pos.Y - h / 2 - 12)
                    o.Name.Visible = true
                else
                    o.Name.Visible = false
                end
            end
        end
    end
end)

-- =========================================================================
-- PLAYER: WEAPON / ARM LATEX
-- =========================================================================
local latexHooked = setmetatable({}, { __mode = "k" })

local function LatexPart(p)
    if not S.WeaponLatex then return end
    if p:IsA("BasePart") then
        if p.Transparency < 1 and p.Name ~= "LeftArm" and p.Name ~= "RightArm" then
            p.Transparency = 0.549
            p.Color = Color3.fromRGB(140, 140, 245)
            p.Material = Enum.Material.Neon
            if p:IsA("UnionOperation") then p.UsePartColor = true end
        end
    elseif p:IsA("Decal") then
        p:Destroy()
    end
end

local function LatexTool(tool)
    for _, d in ipairs(tool:GetDescendants()) do LatexPart(d) end
    if not latexHooked[tool] then
        latexHooked[tool] = true
        tool.DescendantAdded:Connect(function(d)
            task.wait(0.05)
            LatexPart(d)
        end)
    end
end

local function LatexChar(char)
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then LatexTool(c) end
    end
    if not latexHooked[char] then
        latexHooked[char] = true
        char.ChildAdded:Connect(function(c)
            if c:IsA("Tool") then LatexTool(c) end
        end)
    end
end

RunService.RenderStepped:Connect(function()
    if not S.ArmLatex then return end
    local vm = Workspace:FindFirstChild("ViewModel")
    if not vm then return end
    for _, name in ipairs({ "Left Arm", "Right Arm" }) do
        local arm = vm:FindFirstChild(name)
        if arm then
            arm.Material = Enum.Material.ForceField
            arm.Color = Color3.fromRGB(170, 170, 255)
            arm.Reflectance = 0.12
        end
    end
end)

-- =========================================================================
-- VIEW: THIRD PERSON
-- =========================================================================
local OrigMaxZoom = LocalPlayer.CameraMaxZoomDistance
local OrigMinZoom = LocalPlayer.CameraMinZoomDistance
local ThirdKeyToggled = false
local ThirdEngaged = false

local function ThirdActive()
    if not S.ThirdPersonEnabled then return false end
    if S.ThirdPersonActivation == "Always on" then return true end
    return ThirdKeyToggled
end

local function ApplyThird()
    task.spawn(function()
        local char = LocalPlayer.Character
        if not (char and char:FindFirstChild("Humanoid")) then return end
        task.wait(0.1)
        if ThirdActive() then
            ThirdEngaged = true
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            LocalPlayer.CameraMaxZoomDistance = S.ThirdPersonDistance
            LocalPlayer.CameraMinZoomDistance = S.ThirdPersonDistance
        elseif ThirdEngaged then
            ThirdEngaged = false
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
            LocalPlayer.CameraMaxZoomDistance = OrigMaxZoom
            LocalPlayer.CameraMinZoomDistance = OrigMinZoom
        end
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    local key = S.ThirdPersonActivation
    if S.ThirdPersonEnabled and key ~= "Always on" and input.KeyCode.Name == key then
        ThirdKeyToggled = not ThirdKeyToggled
        ApplyThird()
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if ThirdActive() and S.ThirdPersonActivation == "Always on" then
            ApplyThird()
        end
    end
end)

-- =========================================================================
-- WORLD: SKY / BLOOM / AMBIENT / WEATHER
-- =========================================================================
local Skies = {
    Galaxy = {
        Up = "rbxassetid://13581562894", Dn = "rbxassetid://13581550529",
        Ft = "rbxassetid://13581558701", Bk = "rbxassetid://13581548315",
        Lf = "rbxassetid://13581554946", Rt = "rbxassetid://13581565733",
    },
    ["Clouded Sky"] = {
        Up = "http://www.roblox.com/asset/?id=252762652", Dn = "http://www.roblox.com/asset/?id=252763035",
        Ft = "http://www.roblox.com/asset/?id=252761439", Bk = "http://www.roblox.com/asset/?id=252760981",
        Lf = "http://www.roblox.com/asset/?id=252760980", Rt = "http://www.roblox.com/asset/?id=252760986",
    },
}
local existingSky = Lighting:FindFirstChildOfClass("Sky")
local origSky = existingSky and existingSky:Clone()

local function ApplySky()
    local pick = Skies[S.SelectedSky]
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if pick then
        sky = sky or Instance.new("Sky", Lighting)
        sky.SkyboxUp = pick.Up
        sky.SkyboxDn = pick.Dn
        sky.SkyboxFt = pick.Ft
        sky.SkyboxBk = pick.Bk
        sky.SkyboxLf = pick.Lf
        sky.SkyboxRt = pick.Rt
    else
        if sky then sky:Destroy() end
        if origSky then origSky:Clone().Parent = Lighting end
    end
end

local Bloom = Lighting:FindFirstChild("BloomEffect") or Instance.new("BloomEffect")
Bloom.Name = "BloomEffect"
Bloom.Parent = Lighting

local function ApplyBloom()
    Bloom.Enabled = S.BloomEnabled
    Bloom.Intensity = S.BloomValue / 10
end
Lighting.DescendantAdded:Connect(function(d)
    if d:IsA("BloomEffect") then
        Bloom = d
        ApplyBloom()
    end
end)

local AmbientColors = {
    Purple     = Color3.fromRGB(170, 170, 255),
    Red        = Color3.fromRGB(255, 0, 0),
    Blue       = Color3.fromRGB(0, 0, 255),
    Toothpaste = Color3.fromRGB(120, 255, 200),
    Yellow     = Color3.fromRGB(255, 255, 0),
    Green      = Color3.fromRGB(0, 255, 0),
}
local origAmbient, origOutdoor = Lighting.Ambient, Lighting.OutdoorAmbient
local ambientTouched = false

local function ApplyAmbient()
    local c = AmbientColors[S.SelectedAmbient]
    if c then
        ambientTouched = true
        Lighting.Ambient = c
        Lighting.OutdoorAmbient = c
    elseif ambientTouched then
        ambientTouched = false
        Lighting.Ambient = origAmbient
        Lighting.OutdoorAmbient = origOutdoor
    end
end
Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
    if AmbientColors[S.SelectedAmbient] then ApplyAmbient() end
end)
Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(function()
    if AmbientColors[S.SelectedAmbient] then ApplyAmbient() end
end)

local RainParts, SnowParts = {}, {}
local RAIN = { Density = 600, Speed = 300, Color = Color3.fromRGB(180, 180, 180) }
local SNOW = { Density = 190, Speed = 20, Size = 0.3, Color = Color3.fromRGB(255, 255, 255) }

local function ClearWeather()
    for _, p in ipairs(RainParts) do p:Destroy() end
    for _, p in ipairs(SnowParts) do p:Destroy() end
    RainParts, SnowParts = {}, {}
end

RunService.RenderStepped:Connect(function(dt)
    local camera = Cam()
    if not camera then return end
    local camPos = camera.CFrame.Position

    if S.Weather == "Rain" then
        for _ = 1, 5 do
            if #RainParts >= RAIN.Density then break end
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Color = RAIN.Color
            p.Material = Enum.Material.Water
            p.Size = Vector3.new(0.05, 1, 0.05)
            p.Position = camPos + Vector3.new(math.random(-50, 50), math.random(-50, 50), math.random(-50, 50))
            p.Parent = Workspace
            table.insert(RainParts, p)
        end
        for _, p in ipairs(RainParts) do
            if p.Position.Y < camPos.Y - 50 then
                p.Position = camPos + Vector3.new(math.random(-50, 50), 50, math.random(-50, 50))
            else
                p.Position = p.Position - Vector3.new(0, RAIN.Speed * dt, 0)
            end
        end
    elseif S.Weather == "Snow" then
        for _ = 1, 3 do
            if #SnowParts >= SNOW.Density then break end
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Shape = Enum.PartType.Ball
            p.Color = SNOW.Color
            p.Material = Enum.Material.Neon
            p.Size = Vector3.new(SNOW.Size, SNOW.Size, SNOW.Size)
            p.Position = camPos + Vector3.new(math.random(-60, 60), math.random(-30, 60), math.random(-60, 60))
            p.Parent = Workspace
            table.insert(SnowParts, p)
        end
        for _, p in ipairs(SnowParts) do
            if p.Position.Y < camPos.Y - 30 then
                p.Position = camPos + Vector3.new(math.random(-60, 60), 60, math.random(-60, 60))
            else
                p.Position = p.Position - Vector3.new(0, SNOW.Speed * dt, 0)
            end
        end
    end
end)

-- =========================================================================
-- MOVEMENT
-- =========================================================================
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end

    local inAir = hum.FloorMaterial == Enum.Material.Air

    if S.AutoJumpEnabled and not inAir then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    if S.AirStrafeEnabled and inAir then
        local md = hum.MoveDirection
        if md.Magnitude > 0 then
            root.Velocity = Vector3.new(md.X * S.AirStrafeStrength, root.Velocity.Y, md.Z * S.AirStrafeStrength)
        end
    end

    if S.AutoMoveEnabled then
        local look = Cam().CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > 0 then hum:Move(flat.Unit, false) end
    end
end)

-- =========================================================================
-- WINDOW (Nyven theme)
-- =========================================================================
WindUI:AddTheme({
    Name        = "NyvenPurple",
    Accent      = Color3.fromHex("#2d1b69"),   -- deep purple panel
    Background  = Color3.fromHex("#0d0d2b"),   -- dark navy base
    Outline     = Color3.fromHex("#a855f7"),   -- bright purple border
    Text        = Color3.fromHex("#e9d5ff"),   -- soft lavender text
    Placeholder = Color3.fromHex("#7c3aed"),   -- muted purple placeholder
    Button      = Color3.fromHex("#1d4ed8"),   -- blue buttons
    Icon        = Color3.fromHex("#818cf8"),   -- indigo icons
})

local Window = WindUI:CreateWindow({
    Title = "Nyven Hub",
    Author = "Premium Script Hub",
    Icon = currentLogo,
    Folder = HUB_FOLDER .. "/Configs",
    ToggleKey = Enum.KeyCode.Insert,
    NewElements = true,
    HideSearchBar = false,
    Theme = "NyvenPurple",
    Background = themeAsset,               -- nil on Android/unsupported = no background, no crash
    BackgroundImageTransparency = 0.55,
    OpenButton = {
        Title = "Nyven Hub",
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Default",
    },
})

-- UI helpers (every change auto-saves to the config file)
local function UIToggle(sec, title, key, cb)
    sec:Toggle({
        Title = title,
        Value = S[key],
        Callback = function(v)
            set(key, v)
            if cb then cb(v) end
        end,
    })
    sec:Space()
end

local function UISlider(sec, title, key, min, max, cb)
    sec:Slider({
        Title = title,
        Step = 1,
        Value = { Min = min, Max = max, Default = S[key] },
        Callback = function(v)
            set(key, v)
            if cb then cb(v) end
        end,
    })
    sec:Space()
end

local function UIDropdown(sec, title, key, values, cb)
    sec:Dropdown({
        Title = title,
        Values = values,
        Value = S[key],
        Callback = function(v)
            if type(v) == "table" then v = v.Title or v[1] end
            set(key, v)
            if cb then cb(v) end
        end,
    })
    sec:Space()
end

-- AIMBOT TAB
local AimTab = Window:Tab({ Icon = "target", Title = "Aimbot" })
local AimSec = AimTab:Section({ Title = "AIMBOT" })
UIToggle(AimSec, "Aim assist", "AimbotEnabled")
UIDropdown(AimSec, "Mode", "AimbotMode", { "Free for all", "Team support" })
UIDropdown(AimSec, "Hitboxes", "AimbotPart", { "Head", "Chest", "Stomach", "Arms", "Legs" })
UISlider(AimSec, "Aim speed", "AimbotSpeed", 1, 100)
UIToggle(AimSec, "Show FOV Circle", "ShowFovCircle")
UISlider(AimSec, "Fov value", "AimbotFOV", 1, 600)
UISlider(AimSec, "Circle Thickness", "FovCircleThickness", 1, 10)
UIToggle(AimSec, "Silent Aim", "SilentAimEnabled")


-- PLAYER TAB
local PlayerTab = Window:Tab({ Icon = "user", Title = "Player" })
local PlayerSec = PlayerTab:Section({ Title = "PLAYER" })
UIToggle(PlayerSec, "Bullet tracer", "TrailEnabled")
UIDropdown(PlayerSec, "Tracer Color", "TrailColorName", { "Red", "Green", "Pink", "Toothpaste", "White" })
UIToggle(PlayerSec, "Box", "PlayerESPBox")
UIToggle(PlayerSec, "Name", "PlayerESPName")
UIToggle(PlayerSec, "Chams", "PlayerChamsEnabled", function() ChamsRefresh() end)
UIDropdown(PlayerSec, "Color", "PlayerChamsColor",
    { "White", "Red", "Blue", "Green", "Yellow", "Purple", "Cyan", "Orange", "Pink", "Black" },
    function() if S.PlayerChamsEnabled then ChamsRefresh() end end)
UIToggle(PlayerSec, "Weapon latex", "WeaponLatex", function()
    if LocalPlayer.Character then LatexChar(LocalPlayer.Character) end
end)
UIToggle(PlayerSec, "Arm latex", "ArmLatex")

-- WORLD TAB
local WorldTab = Window:Tab({ Icon = "globe", Title = "World" })
local WorldSec = WorldTab:Section({ Title = "WORLD" })
UIDropdown(WorldSec, "Sky", "SelectedSky", { "Default", "Galaxy", "Clouded Sky" }, ApplySky)
UIToggle(WorldSec, "Bloom", "BloomEnabled", ApplyBloom)
UISlider(WorldSec, "Bloom value", "BloomValue", 1, 100, ApplyBloom)
UIDropdown(WorldSec, "Ambient", "SelectedAmbient",
    { "Disabled", "Purple", "Red", "Blue", "Toothpaste", "Yellow", "Green" }, ApplyAmbient)
UIDropdown(WorldSec, "Weather", "Weather", { "Off", "Rain", "Snow" }, ClearWeather)

-- VIEW TAB
local ViewTab = Window:Tab({ Icon = "eye", Title = "View" })
local ViewSec = ViewTab:Section({ Title = "VIEW" })
UIToggle(ViewSec, "Thirdperson", "ThirdPersonEnabled", ApplyThird)
UISlider(ViewSec, "Distance", "ThirdPersonDistance", 1, 30, function()
    if ThirdActive() then ApplyThird() end
end)
UIDropdown(ViewSec, "Activation", "ThirdPersonActivation", { "Always on", "K", "O", "P" }, function()
    ThirdKeyToggled = false
    ApplyThird()
end)

-- MOVEMENT TAB
local MoveTab = Window:Tab({ Icon = "zap", Title = "Movement" })
local MoveSec = MoveTab:Section({ Title = "MOVEMENT" })
UIToggle(MoveSec, "Bunny Hop", "AutoJumpEnabled")
UIToggle(MoveSec, "Strafe in Air", "AirStrafeEnabled")
UISlider(MoveSec, "Air Strafe Strength", "AirStrafeStrength", 1, 100)
UIToggle(MoveSec, "Auto move", "AutoMoveEnabled")

-- MISC TAB
local MiscTab = Window:Tab({ Icon = "box", Title = "Misc" })
local MiscSec = MiscTab:Section({ Title = "MISC" })
UIToggle(MiscSec, "Custom gun sound", "CustomGunSound", ApplyGunSound)
UIToggle(MiscSec, "Custom hit sound", "CustomHitSoundEnabled", ApplyHitSound)
UIDropdown(MiscSec, "Hit sound", "HitSoundSelected", { "Bell", "Metal", "Brutal", "Growl", "Scream" }, ApplyHitSound)
UISlider(MiscSec, "Volume", "HitSoundVolume", 1, 100, ApplyHitSound)

-- =========================================================================
-- APPLY SAVED STATE + CHARACTER EVENTS
-- =========================================================================
ApplyBloom()
ApplyAmbient()
if S.SelectedSky ~= "Default" then ApplySky() end
if S.CustomGunSound then ApplyGunSound() end
if S.CustomHitSoundEnabled then ApplyHitSound() end
if S.PlayerChamsEnabled then ChamsRefresh() end
if S.ThirdPersonEnabled then ApplyThird() end
if LocalPlayer.Character then
    LatexChar(LocalPlayer.Character)
    HookFire(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    LatexChar(char)
    HookFire(char)
    ApplyHitSound()
    task.delay(1, function()
        if S.SelectedSky ~= "Default" then ApplySky() end
    end)
    if S.PlayerChamsEnabled then
        task.wait(0.5)
        ChamsRefresh()
    end
    if S.ThirdPersonEnabled then ApplyThird() end
end)

pcall(function()
    WindUI:Notify({
        Title = "Nyven Hub",
        Content = "Loaded!",
        Duration = 3,
    })
end)

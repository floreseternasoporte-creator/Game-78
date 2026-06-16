-- ============================================================
--   BLOOD POWERS - LOCAL SCRIPT
--   Coloca esto en: StarterPlayerScripts > LocalScript
-- ============================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ─── ESPERAR REMOTES ─────────────────────────────────────────
local RemoteFolder = ReplicatedStorage:WaitForChild("BloodPowerEvents", 15)
local RE_BloodBall      = RemoteFolder:WaitForChild("BloodBall")
local RE_BloodCorpuscle = RemoteFolder:WaitForChild("BloodCorpuscle")
local RE_BloodWhip      = RemoteFolder:WaitForChild("BloodWhip")
local RE_Souls1000      = RemoteFolder:WaitForChild("Souls1000")
local RE_Effect         = RemoteFolder:WaitForChild("EffectToAll")
local RE_Stun           = RemoteFolder:WaitForChild("StunTarget")
local RE_Unlock1000     = RemoteFolder:WaitForChild("Unlock1000Souls")
local RE_Anim           = RemoteFolder:WaitForChild("PlayAnim")
local RE_Bracelet       = RemoteFolder:WaitForChild("SpawnBracelet")

-- ─── ESTADO LOCAL ────────────────────────────────────────────
local isStunned        = false
local stunEndTime      = 0
local souls1000Button  = nil
local cooldownTweens   = {}

local COOLDOWN = {
        BloodBall      = 4,
        BloodCorpuscle = 8,
        BloodWhip      = 12,
        Souls1000      = 20,
}

-- ─── GUI ──────────────────────────────────────────────────────
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Eliminar GUI previa si existe
if PlayerGui:FindFirstChild("BloodPowerGui") then
        PlayerGui.BloodPowerGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloodPowerGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- ─── CONTENEDOR DE BOTONES (esquina inferior derecha) ─────────
local ButtonFrame = Instance.new("Frame")
ButtonFrame.Name = "ButtonFrame"
ButtonFrame.Size = UDim2.new(0, 340, 0, 120)
ButtonFrame.Position = UDim2.new(1, -360, 1, -140)
ButtonFrame.BackgroundTransparency = 1
ButtonFrame.Parent = ScreenGui

local UIList = Instance.new("UIListLayout")
UIList.FillDirection = Enum.FillDirection.Horizontal
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 10)
UIList.VerticalAlignment = Enum.VerticalAlignment.Center
UIList.Parent = ButtonFrame

-- ─── FUNCIÓN PARA CREAR BOTÓN DE PODER ────────────────────────
local function createPowerButton(name, key, icon, color1, color2, order)
        local btn = Instance.new("Frame")
        btn.Name = name
        btn.Size = UDim2.new(0, 90, 0, 110)
        btn.BackgroundTransparency = 1
        btn.LayoutOrder = order
        btn.Parent = ButtonFrame

        -- Fondo del botón
        local bg = Instance.new("ImageLabel")
        bg.Name = "Background"
        bg.Size = UDim2.new(0, 80, 0, 80)
        bg.Position = UDim2.new(0.5, -40, 0, 0)
        bg.BackgroundColor3 = Color3.fromRGB(10, 0, 0)
        bg.BorderSizePixel = 0
        bg.ImageTransparency = 1
        bg.Parent = btn

        local uic = Instance.new("UICorner")
        uic.CornerRadius = UDim.new(0.15, 0)
        uic.Parent = bg

        -- Stroke animado
        local stroke = Instance.new("UIStroke")
        stroke.Color = color1
        stroke.Thickness = 2.5
        stroke.Parent = bg

        -- Ícono (texto emoji como placeholder visual)
        local iconLabel = Instance.new("TextLabel")
        iconLabel.Name = "Icon"
        iconLabel.Size = UDim2.new(1, 0, 0.65, 0)
        iconLabel.Position = UDim2.new(0, 0, 0.05, 0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = icon
        iconLabel.TextScaled = true
        iconLabel.Font = Enum.Font.GothamBold
        iconLabel.TextColor3 = color1
        iconLabel.Parent = bg

        -- Nombre del poder
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "PowerName"
        nameLabel.Size = UDim2.new(1, 0, 0.25, 0)
        nameLabel.Position = UDim2.new(0, 0, 0.70, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = name
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextStrokeTransparency = 0.5
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.Parent = btn

        -- Tecla
        local keyLabel = Instance.new("TextLabel")
        keyLabel.Name = "KeyLabel"
        keyLabel.Size = UDim2.new(0, 24, 0, 24)
        keyLabel.Position = UDim2.new(0.5, 28, 0, -4)
        keyLabel.AnchorPoint = Vector2.new(0, 0)
        keyLabel.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
        keyLabel.BorderSizePixel = 0
        keyLabel.Text = key
        keyLabel.TextScaled = true
        keyLabel.Font = Enum.Font.GothamBold
        keyLabel.TextColor3 = color1
        keyLabel.ZIndex = 5
        keyLabel.Parent = btn
        local kc = Instance.new("UICorner")
        kc.CornerRadius = UDim.new(0.3, 0)
        kc.Parent = keyLabel

        -- Overlay de cooldown (se llena de arriba a abajo)
        local cooldownOverlay = Instance.new("Frame")
        cooldownOverlay.Name = "CooldownOverlay"
        cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
        cooldownOverlay.Position = UDim2.new(0, 0, 0, 0)
        cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        cooldownOverlay.BackgroundTransparency = 0.4
        cooldownOverlay.BorderSizePixel = 0
        cooldownOverlay.ZIndex = 3
        cooldownOverlay.Parent = bg

        -- Texto de cooldown
        local cdText = Instance.new("TextLabel")
        cdText.Name = "CDText"
        cdText.Size = UDim2.new(1, 0, 1, 0)
        cdText.BackgroundTransparency = 1
        cdText.Text = ""
        cdText.TextScaled = true
        cdText.Font = Enum.Font.GothamBold
        cdText.TextColor3 = Color3.fromRGB(255, 255, 255)
        cdText.ZIndex = 4
        cdText.Parent = bg

        -- Efecto de brillo pulsante
        local glow = Instance.new("Frame")
        glow.Name = "Glow"
        glow.Size = UDim2.new(1, 8, 1, 8)
        glow.Position = UDim2.new(0, -4, 0, -4)
        glow.BackgroundColor3 = color1
        glow.BackgroundTransparency = 0.85
        glow.BorderSizePixel = 0
        glow.ZIndex = -1
        local gc = Instance.new("UICorner")
        gc.CornerRadius = UDim.new(0.18, 0)
        gc.Parent = glow
        glow.Parent = bg

        -- Animación de pulso en el glow
        task.spawn(function()
                while bg and bg.Parent do
                        TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                                BackgroundTransparency = 0.6,
                        }):Play()
                        task.wait(1.2)
                        TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                                BackgroundTransparency = 0.9,
                        }):Play()
                        task.wait(1.2)
                end
        end)

        return btn, bg, cooldownOverlay, cdText, stroke
end

-- ─── CREAR LOS 3 BOTONES INICIALES ────────────────────────────
local btn1, bg1, cd1, cdt1, stroke1 = createPowerButton("Bola de Sangre",   "Q", "🩸", Color3.fromRGB(220, 20, 20),  Color3.fromRGB(150, 0, 0),  1)
local btn2, bg2, cd2, cdt2, stroke2 = createPowerButton("Glóbulos",         "E", "💀", Color3.fromRGB(180, 0, 60),  Color3.fromRGB(120, 0, 40), 2)
local btn3, bg3, cd3, cdt3, stroke3 = createPowerButton("Látigo de Sangre", "R", "⛓", Color3.fromRGB(200, 0, 0),   Color3.fromRGB(130, 0, 0),  3)

-- ─── BOTÓN 1000 ALMAS (inicialmente oculto) ────────────────────
local btn4Frame = Instance.new("Frame")
btn4Frame.Name = "Souls1000Btn"
btn4Frame.Size = UDim2.new(0, 90, 0, 110)
btn4Frame.BackgroundTransparency = 1
btn4Frame.LayoutOrder = 4
btn4Frame.Visible = false
btn4Frame.Parent = ButtonFrame

local bg4 = Instance.new("ImageLabel")
bg4.Name = "Background"
bg4.Size = UDim2.new(0, 80, 0, 80)
bg4.Position = UDim2.new(0.5, -40, 0, 0)
bg4.BackgroundColor3 = Color3.fromRGB(5, 0, 20)
bg4.BorderSizePixel = 0
bg4.ImageTransparency = 1
bg4.Parent = btn4Frame

local uic4 = Instance.new("UICorner")
uic4.CornerRadius = UDim.new(0.15, 0)
uic4.Parent = bg4

local stroke4 = Instance.new("UIStroke")
stroke4.Color = Color3.fromRGB(180, 0, 255)
stroke4.Thickness = 3
stroke4.Parent = bg4

local icon4 = Instance.new("TextLabel")
icon4.Size = UDim2.new(1, 0, 0.65, 0)
icon4.Position = UDim2.new(0, 0, 0.05, 0)
icon4.BackgroundTransparency = 1
icon4.Text = "☠"
icon4.TextScaled = true
icon4.Font = Enum.Font.GothamBold
icon4.TextColor3 = Color3.fromRGB(200, 50, 255)
icon4.Parent = bg4

local name4 = Instance.new("TextLabel")
name4.Size = UDim2.new(1, 0, 0.25, 0)
name4.Position = UDim2.new(0, 0, 0.70, 0)
name4.BackgroundTransparency = 1
name4.Text = "1000 Almas"
name4.TextScaled = true
name4.Font = Enum.Font.GothamBold
name4.TextColor3 = Color3.fromRGB(255, 200, 255)
name4.TextStrokeTransparency = 0.5
name4.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
name4.Parent = btn4Frame

local key4 = Instance.new("TextLabel")
key4.Size = UDim2.new(0, 24, 0, 24)
key4.Position = UDim2.new(0.5, 28, 0, -4)
key4.AnchorPoint = Vector2.new(0, 0)
key4.BackgroundColor3 = Color3.fromRGB(20, 0, 40)
key4.BorderSizePixel = 0
key4.Text = "F"
key4.TextScaled = true
key4.Font = Enum.Font.GothamBold
key4.TextColor3 = Color3.fromRGB(200, 50, 255)
key4.ZIndex = 5
key4.Parent = btn4Frame
local kc4 = Instance.new("UICorner")
kc4.CornerRadius = UDim.new(0.3, 0)
kc4.Parent = key4

local cd4 = Instance.new("Frame")
cd4.Name = "CooldownOverlay"
cd4.Size = UDim2.new(1, 0, 0, 0)
cd4.Position = UDim2.new(0, 0, 0, 0)
cd4.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
cd4.BackgroundTransparency = 0.4
cd4.BorderSizePixel = 0
cd4.ZIndex = 3
cd4.Parent = bg4

local cdt4 = Instance.new("TextLabel")
cdt4.Size = UDim2.new(1, 0, 1, 0)
cdt4.BackgroundTransparency = 1
cdt4.Text = ""
cdt4.TextScaled = true
cdt4.Font = Enum.Font.GothamBold
cdt4.TextColor3 = Color3.fromRGB(255, 255, 255)
cdt4.ZIndex = 4
cdt4.Parent = bg4

local glow4 = Instance.new("Frame")
glow4.Size = UDim2.new(1, 12, 1, 12)
glow4.Position = UDim2.new(0, -6, 0, -6)
glow4.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
glow4.BackgroundTransparency = 0.7
glow4.BorderSizePixel = 0
glow4.ZIndex = -1
local gc4 = Instance.new("UICorner")
gc4.CornerRadius = UDim.new(0.18, 0)
gc4.Parent = glow4
glow4.Parent = bg4

-- Pulso especial para 1000 almas (más dramático)
task.spawn(function()
        while bg4 and bg4.Parent do
                TweenService:Create(glow4, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        BackgroundTransparency = 0.3,
                        BackgroundColor3 = Color3.fromRGB(255, 50, 255),
                }):Play()
                task.wait(0.7)
                TweenService:Create(glow4, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                        BackgroundTransparency = 0.85,
                        BackgroundColor3 = Color3.fromRGB(100, 0, 180),
                }):Play()
                task.wait(0.7)
        end
end)

souls1000Button = btn4Frame

-- ─── SISTEMA DE ANIMACIONES DE ARTES MARCIALES ───────────────
-- Usamos Motor6D tweening para animar sin AnimationController externo
-- Las poses se aplican directamente a los joints del personaje local

local animLock = false

local function getMotors(char)
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local t = {}

        local torso = char:FindFirstChild("Torso")
        if torso then
                -- R6: Motor6D viven en el Torso con estos nombres exactos
                local ls   = torso:FindFirstChild("Left Shoulder")
                local rs   = torso:FindFirstChild("Right Shoulder")
                local lh   = torso:FindFirstChild("Left Hip")
                local rh   = torso:FindFirstChild("Right Hip")
                local neck = torso:FindFirstChild("Neck")
                if ls   then t["Left Arm"]   = ls   end
                if rs   then t["Right Arm"]  = rs   end
                if lh   then t["Left Leg"]   = lh   end
                if rh   then t["Right Leg"]  = rh   end
                if neck then t["Head"]       = neck end
        else
                -- R15: Motor6D viven DENTRO de cada part, no en el torso
                local function findMotor(partName, motorName, key)
                        local part = char:FindFirstChild(partName)
                        if part then
                                -- Buscar Motor6D directamente por nombre
                                local m = part:FindFirstChildOfClass("Motor6D")
                                if not m then
                                        m = part:FindFirstChild(motorName)
                                end
                                if m then t[key] = m end
                        end
                end
                -- En R15 los motores están en la parte superior de cada extremidad
                findMotor("LeftUpperArm",  "LeftShoulder",  "Left Arm")
                findMotor("RightUpperArm", "RightShoulder", "Right Arm")
                findMotor("LeftUpperLeg",  "LeftHip",       "Left Leg")
                findMotor("RightUpperLeg", "RightHip",      "Right Leg")
                -- También probar nombres alternativos R15
                if not t["Left Arm"] then  findMotor("UpperArm_L", "LeftShoulder",  "Left Arm")  end
                if not t["Right Arm"] then findMotor("UpperArm_R", "RightShoulder", "Right Arm") end
                if not t["Left Leg"] then  findMotor("UpperLeg_L", "LeftHip",       "Left Leg")  end
                if not t["Right Leg"] then findMotor("UpperLeg_R", "RightHip",      "Right Leg") end
                local headPart = char:FindFirstChild("Head")
                if headPart then
                        local m = headPart:FindFirstChildOfClass("Motor6D")
                        if m then t["Head"] = m end
                end
        end

        -- RootJoint siempre en HumanoidRootPart
        local rj = hrp:FindFirstChild("RootJoint")
        if rj then t["HumanoidRootPart"] = rj end

        return t
end

-- Tweena un Motor6D hacia un CFrame objetivo y luego lo devuelve
-- Si targetC0 es una rotacion pura (posicion ~0), la aplica sobre DEFAULT_C0
local function tweenMotor(motor, targetC0, duration, easingStyle)
        if not motor then return end
        local start = motor.C0
        local elapsed = 0
        local conn
        conn = RunService.RenderStepped:Connect(function(dt)
                elapsed = elapsed + dt
                local alpha = math.min(elapsed / duration, 1)
                local eased = TweenService:GetValue(alpha, easingStyle or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                motor.C0 = start:Lerp(targetC0, eased)
                if alpha >= 1 then conn:Disconnect() end
        end)
        return conn
end

-- Defaults de C0 por personaje (se capturan al spawn)
local DEFAULT_C0 = {}  -- se llena al primer uso

-- Helper: construye el C0 de pose para brazos R6/R15
-- Usa la POSICIÓN del C0 base y aplica ángulos de pose limpios.
-- Los ángulos recibidos ya están en el espacio de la pose deseada:
--   X positivo = brazo adelante, X negativo = brazo atrás
--   Z afecta apertura lateral
local function poseC0(partKey, extraAngles)
        local base = DEFAULT_C0[partKey]
        if base then
                -- Usar solo la posición del default; la rotación de pose va directa
                return CFrame.new(base.X, base.Y, base.Z)
                        * CFrame.Angles(extraAngles.X, extraAngles.Y, extraAngles.Z)
        else
                return CFrame.Angles(extraAngles.X, extraAngles.Y, extraAngles.Z)
        end
end

-- Restaurar pose idle de todos los motores

local function restoreIdle(char, duration)
        duration = duration or 0.25
        for partName, motor in pairs(getMotors(char) or {}) do
                if DEFAULT_C0[partName] then
                        tweenMotor(motor, DEFAULT_C0[partName], duration, Enum.EasingStyle.Back)
                end
        end
end

-- Capturar C0 por defecto al spawn
local function captureDefaults(char)
        -- Esperar a que los Motor6D existan (puede tardar en R6 y R15)
        task.wait(0.3)
        local motors = getMotors(char)
        if not motors then return end
        local captured = 0
        for partName, motor in pairs(motors) do
                if motor and motor.Parent then
                        DEFAULT_C0[partName] = motor.C0
                        captured = captured + 1
                end
        end
        -- Si no se capturó nada (personaje aún cargando), reintentar
        if captured == 0 then
                task.wait(0.5)
                motors = getMotors(char)
                if motors then
                        for partName, motor in pairs(motors) do
                                if motor and motor.Parent then
                                        DEFAULT_C0[partName] = motor.C0
                                end
                        end
                end
        end
end

-- ── POSES DE ARTES MARCIALES ──────────────────────────────────
-- Cada pose tween los motores, espera y restaura

local function pose_BloodBall(char)
        if animLock then return end
        animLock = true
        local motors = getMotors(char)
        if not motors then animLock = false return end

        -- FASE 1: el brazo SUBE LENTO al pecho/hombro, cargando energía (0.5s)
        if motors["Left Arm"] then
                tweenMotor(motors["Left Arm"],
                        poseC0("Left Arm", Vector3.new(0, 0, math.rad(-130))),
                        0.5, Enum.EasingStyle.Sine)
        end
        if motors["Right Arm"] then
                tweenMotor(motors["Right Arm"],
                        poseC0("Right Arm", Vector3.new(0, 0, math.rad(25))),
                        0.5, Enum.EasingStyle.Sine)
        end
        if motors["HumanoidRootPart"] then
                tweenMotor(motors["HumanoidRootPart"],
                        CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(20), 0),
                        0.5, Enum.EasingStyle.Sine)
        end

        task.delay(0.5, function()
                -- FASE 2: el brazo BAJA RÁPIDO lanzando la bola (golpe seco, 0.15s)
                if motors["Left Arm"] and motors["Left Arm"].Parent then
                        tweenMotor(motors["Left Arm"],
                                poseC0("Left Arm", Vector3.new(0, 0, math.rad(-90))),
                                0.15, Enum.EasingStyle.Back)
                end
                if motors["Right Arm"] and motors["Right Arm"].Parent then
                        tweenMotor(motors["Right Arm"],
                                poseC0("Right Arm", Vector3.new(0, 0, math.rad(30))),
                                0.15, Enum.EasingStyle.Quad)
                end
                if motors["HumanoidRootPart"] and motors["HumanoidRootPart"].Parent then
                        tweenMotor(motors["HumanoidRootPart"],
                                CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(5), math.rad(-15), 0),
                                0.15, Enum.EasingStyle.Back)
                end

                task.delay(0.18, function()
                        -- FASE 3: Recoil suave del brazo tras lanzar
                        if motors["Left Arm"] and motors["Left Arm"].Parent then
                                tweenMotor(motors["Left Arm"],
                                        poseC0("Left Arm", Vector3.new(0, 0, math.rad(-60))),
                                        0.25, Enum.EasingStyle.Bounce)
                        end
                        task.delay(0.35, function()
                                restoreIdle(char, 0.35)
                                task.delay(0.35, function() animLock = false end)
                        end)
                end)
        end)
end

local function pose_BloodCorpuscle(char)
        if animLock then return end
        animLock = true
        local motors = getMotors(char)
        if not motors then animLock = false return end

        -- FASE 1: ambos brazos se elevan LENTO con palmas mirando hacia abajo (invocar)
        if motors["Left Arm"] then
                tweenMotor(motors["Left Arm"],
                        poseC0("Left Arm", Vector3.new(0, 0, math.rad(-80))),
                        0.45, Enum.EasingStyle.Sine)
        end
        if motors["Right Arm"] then
                tweenMotor(motors["Right Arm"],
                        poseC0("Right Arm", Vector3.new(0, 0, math.rad(80))),
                        0.45, Enum.EasingStyle.Sine)
        end
        if motors["HumanoidRootPart"] then
                tweenMotor(motors["HumanoidRootPart"],
                        CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-8), 0, 0),
                        0.45, Enum.EasingStyle.Sine)
        end

        -- FASE 2 (0.5s): brazos abiertos a los lados controlando la órbita
        task.delay(0.5, function()
                if motors["Left Arm"] and motors["Left Arm"].Parent then
                        tweenMotor(motors["Left Arm"],
                                poseC0("Left Arm", Vector3.new(0, 0, math.rad(-85))),
                                0.22, Enum.EasingStyle.Back)
                end
                if motors["Right Arm"] and motors["Right Arm"].Parent then
                        tweenMotor(motors["Right Arm"],
                                poseC0("Right Arm", Vector3.new(0, 0, math.rad(85))),
                                0.22, Enum.EasingStyle.Back)
                end
                if motors["HumanoidRootPart"] and motors["HumanoidRootPart"].Parent then
                        tweenMotor(motors["HumanoidRootPart"],
                                CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-14), 0, 0),
                                0.22, Enum.EasingStyle.Quad)
                end
        end)

        -- FASE 3 (2.0s): empuje hacia adelante = espinas lanzadas
        task.delay(2.0, function()
                if motors["Left Arm"] and motors["Left Arm"].Parent then
                        tweenMotor(motors["Left Arm"],
                                poseC0("Left Arm", Vector3.new(0, 0, math.rad(-90))),
                                0.14, Enum.EasingStyle.Back)
                end
                if motors["Right Arm"] and motors["Right Arm"].Parent then
                        tweenMotor(motors["Right Arm"],
                                poseC0("Right Arm", Vector3.new(0, 0, math.rad(90))),
                                0.14, Enum.EasingStyle.Back)
                end
                if motors["HumanoidRootPart"] and motors["HumanoidRootPart"].Parent then
                        tweenMotor(motors["HumanoidRootPart"],
                                CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(8), 0, 0),
                                0.14, Enum.EasingStyle.Back)
                end

                task.delay(0.4, function()
                        restoreIdle(char, 0.4)
                        task.delay(0.4, function() animLock = false end)
                end)
        end)
end

local function pose_BloodWhip(char)
        if animLock then return end
        animLock = true
        local motors = getMotors(char)
        if not motors then animLock = false return end

        -- Pose: ambos brazos suben LENTO extendiéndose al FRENTE
        if motors["Left Arm"] then
                tweenMotor(motors["Left Arm"],
                        poseC0("Left Arm", Vector3.new(0, 0, math.rad(-90))),
                        0.4, Enum.EasingStyle.Sine)
        end
        if motors["Right Arm"] then
                tweenMotor(motors["Right Arm"],
                        poseC0("Right Arm", Vector3.new(0, 0, math.rad(90))),
                        0.4, Enum.EasingStyle.Sine)
        end
        if motors["HumanoidRootPart"] then
                tweenMotor(motors["HumanoidRootPart"],
                        CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(6), 0, 0),
                        0.4, Enum.EasingStyle.Sine)
        end

        -- Vibración suave durante 8s = control activo del látigo
        local shakeConn
        local shakeElapsed = 0
        shakeConn = RunService.RenderStepped:Connect(function(dt)
                shakeElapsed = shakeElapsed + dt
                if shakeElapsed > 8 then
                        shakeConn:Disconnect()
                        restoreIdle(char, 0.4)
                        task.delay(0.4, function() animLock = false end)
                        return
                end

                local wave  = math.sin(shakeElapsed * 6) * 0.04
                local wave2 = math.sin(shakeElapsed * 9 + 1) * 0.03

                if motors["Left Arm"] and motors["Left Arm"].Parent then
                        local basePos = DEFAULT_C0["Left Arm"]
                        local px, py, pz = basePos and basePos.X or -1, basePos and basePos.Y or 0.5, basePos and basePos.Z or 0
                        motors["Left Arm"].C0 = CFrame.new(px, py, pz)
                                * CFrame.Angles(wave2, 0, math.rad(-90) + wave * 20 * math.pi/180)
                end
                if motors["Right Arm"] and motors["Right Arm"].Parent then
                        local basePos = DEFAULT_C0["Right Arm"]
                        local px, py, pz = basePos and basePos.X or 1, basePos and basePos.Y or 0.5, basePos and basePos.Z or 0
                        motors["Right Arm"].C0 = CFrame.new(px, py, pz)
                                * CFrame.Angles(-wave2, 0, math.rad(90) - wave * 20 * math.pi/180)
                end
                if motors["HumanoidRootPart"] and motors["HumanoidRootPart"].Parent then
                        motors["HumanoidRootPart"].C0 = CFrame.new(0, 0, 0)
                                * CFrame.Angles(math.rad(6) + math.sin(shakeElapsed * 4) * 0.025, 0, 0)
                end
        end)
end

local function pose_Souls1000(char)
        if animLock then return end
        animLock = true
        local motors = getMotors(char)
        if not motors then animLock = false return end

        -- FASE 1: brazos suben LENTO hacia el cielo (carga de energía)
        if motors["Left Arm"] then
                tweenMotor(motors["Left Arm"],
                        poseC0("Left Arm", Vector3.new(0, 0, math.rad(-170))),
                        0.6, Enum.EasingStyle.Sine)
        end
        if motors["Right Arm"] then
                tweenMotor(motors["Right Arm"],
                        poseC0("Right Arm", Vector3.new(0, 0, math.rad(170))),
                        0.6, Enum.EasingStyle.Sine)
        end
        if motors["HumanoidRootPart"] then
                tweenMotor(motors["HumanoidRootPart"],
                        CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-18), 0, 0),
                        0.6, Enum.EasingStyle.Sine)
        end

        -- FASE 2 (1.0s): brazos abiertos controlando orbs
        task.delay(1.0, function()
                if motors["Left Arm"] and motors["Left Arm"].Parent then
                        tweenMotor(motors["Left Arm"],
                                poseC0("Left Arm", Vector3.new(0, 0, math.rad(-130))),
                                0.30, Enum.EasingStyle.Back)
                end
                if motors["Right Arm"] and motors["Right Arm"].Parent then
                        tweenMotor(motors["Right Arm"],
                                poseC0("Right Arm", Vector3.new(0, 0, math.rad(130))),
                                0.30, Enum.EasingStyle.Back)
                end
        end)

        -- FASE 3 (3.0s): lanzamiento en arco hacia el objetivo
        task.delay(3.0, function()
                if motors["Left Arm"] and motors["Left Arm"].Parent then
                        tweenMotor(motors["Left Arm"],
                                poseC0("Left Arm", Vector3.new(0, 0, math.rad(-90))),
                                0.12, Enum.EasingStyle.Bounce)
                end
                if motors["Right Arm"] and motors["Right Arm"].Parent then
                        tweenMotor(motors["Right Arm"],
                                poseC0("Right Arm", Vector3.new(0, 0, math.rad(90))),
                                0.12, Enum.EasingStyle.Bounce)
                end
                if motors["HumanoidRootPart"] and motors["HumanoidRootPart"].Parent then
                        tweenMotor(motors["HumanoidRootPart"],
                                CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(12), 0, 0),
                                0.12, Enum.EasingStyle.Back)
                end

                task.delay(0.25, function()
                        if motors["Left Arm"] and motors["Left Arm"].Parent then
                                tweenMotor(motors["Left Arm"],
                                        poseC0("Left Arm", Vector3.new(0, 0, math.rad(-60))),
                                        0.20, Enum.EasingStyle.Quad)
                        end
                        if motors["Right Arm"] and motors["Right Arm"].Parent then
                                tweenMotor(motors["Right Arm"],
                                        poseC0("Right Arm", Vector3.new(0, 0, math.rad(60))),
                                        0.20, Enum.EasingStyle.Quad)
                        end
                        task.delay(0.55, function()
                                restoreIdle(char, 0.5)
                                task.delay(0.5, function() animLock = false end)
                        end)
                end)
        end)
end

-- Escuchar animaciones del servidor
RE_Anim.OnClientEvent:Connect(function(targetPlayer, animName)
        -- Solo aplicar la pose en el cliente del jugador que lanzó el poder
        if targetPlayer ~= LocalPlayer then return end
        local char = LocalPlayer.Character
        if not char then return end

        -- Capturar defaults si aún no se hizo o si se perdieron tras respawn
        if not next(DEFAULT_C0) then
                captureDefaults(char)
                task.wait(0.35)  -- esperar a que captureDefaults llene la tabla
        end

        -- Verificar que tenemos motores válidos antes de animar
        local motors = getMotors(char)
        if not motors or not next(motors) then return end

        if animName == "BloodBall_Pose" then
                pose_BloodBall(char)
        elseif animName == "BloodCorpuscle_Pose" then
                pose_BloodCorpuscle(char)
        elseif animName == "BloodWhip_Pose" then
                pose_BloodWhip(char)
        elseif animName == "Souls1000_Pose" then
                pose_Souls1000(char)
        end
end)

-- Capturar defaults al cargar el personaje local
local function onCharacterAdded(char)
        -- Esperar HumanoidRootPart
        char:WaitForChild("HumanoidRootPart", 10)
        -- Esperar el Torso (R6) o UpperTorso (R15)
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if not torso then
                torso = char:WaitForChild("Torso", 3) or char:WaitForChild("UpperTorso", 3)
        end
        -- En R6 esperar el Motor6D del hombro izquierdo como señal de que el rig está listo
        if torso and torso.Name == "Torso" then
                torso:WaitForChild("Left Shoulder", 8)
        end
        -- Limpiar defaults del personaje anterior
        DEFAULT_C0 = {}
        task.delay(0.8, function()
                captureDefaults(char)
        end)
end

if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ─── EFECTO ÉPICO DE ACTIVACIÓN (orbs se expanden alrededor) ────
-- Se llama ANTES de disparar el RemoteEvent al servidor
local function epicActivationEffect(onFinish)
        local char = LocalPlayer.Character
        if not char then
                if onFinish then onFinish() end
                return
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
                if onFinish then onFinish() end
                return
        end

        local ORBS_COUNT  = 14
        local epicOrbs    = {}
        local startRadius = 0.5   -- comienza compacto (en la manilla)
        local endRadius   = 2.8   -- se expande hasta rodear al personaje
        local EFFECT_TIME = 0.45  -- duración del efecto

        -- Crear orbs de energía sanguínea alrededor del cuerpo
        for i = 1, ORBS_COUNT do
                local baseAngle = (i / ORBS_COUNT) * math.pi * 2
                local orb = Instance.new("Part")
                orb.Size = Vector3.new(0.22, 0.22, 0.22)
                orb.Shape = Enum.PartType.Ball
                orb.BrickColor = (i % 3 == 0) and BrickColor.new("Crimson") or BrickColor.new("Bright red")
                orb.Material = Enum.Material.Neon
                orb.Transparency = 0.0
                orb.CanCollide = false
                orb.CastShadow = false
                orb.Anchored = true
                local pl = Instance.new("PointLight")
                pl.Color = Color3.fromRGB(255, 0, 0)
                pl.Brightness = 5
                pl.Range = 8
                pl.Parent = orb
                orb.Parent = Workspace
                table.insert(epicOrbs, {part = orb, baseAngle = baseAngle})
        end

        -- Animar la expansión
        local elapsed = 0
        local epicConn
        epicConn = RunService.RenderStepped:Connect(function(dt)
                elapsed = elapsed + dt
                local alpha = math.min(elapsed / EFFECT_TIME, 1)
                -- Easing Out Back para dar sensación de rebote épico
                local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                local currentRadius = startRadius + (endRadius - startRadius) * eased
                local rotAngle = elapsed * 8  -- rotación durante la expansión

                if hrp and hrp.Parent then
                        for _, data in ipairs(epicOrbs) do
                                local p = data.part
                                if p and p.Parent then
                                        local angle = data.baseAngle + rotAngle
                                        p.CFrame = hrp.CFrame * CFrame.new(
                                                currentRadius * math.cos(angle),
                                                0.5,  -- altura del pecho
                                                currentRadius * math.sin(angle)
                                        )
                                        -- Pulsar transparencia en la expansión
                                        p.Transparency = alpha > 0.8 and (alpha - 0.8) * 5 or 0
                                end
                        end
                end

                if alpha >= 1 then
                        epicConn:Disconnect()
                        -- Destruir orbs épicos
                        for _, data in ipairs(epicOrbs) do
                                if data.part and data.part.Parent then
                                        data.part:Destroy()
                                end
                        end
                        -- Ejecutar el poder después del efecto
                        if onFinish then onFinish() end
                end
        end)
end

-- ─── FLASH DE MANILLA AL ACTIVAR PODER ────────────────────────
local function flashBracelet()
        local char = LocalPlayer.Character
        if not char then return end
        local leftArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftLowerArm") or char:FindFirstChild("LeftHand")
        if not leftArm then return end
        -- Flash solo en el aro base y orbs cercanos a la muñeca
        for _, v in ipairs(leftArm:GetChildren()) do
                if v:IsA("BasePart") and (v.Name == "BloodBracelet" or v.Name == "BraceletOrb") then
                        local origTransp = v.Transparency
                        TweenService:Create(v, TweenInfo.new(0.08), {Transparency = 0}):Play()
                        task.delay(0.08, function()
                                if v and v.Parent then
                                        TweenService:Create(v, TweenInfo.new(0.25), {Transparency = origTransp}):Play()
                                end
                        end)
                end
        end
end


local cooldownActive = {
        BloodBall = false,
        BloodCorpuscle = false,
        BloodWhip = false,
        Souls1000 = false,
}

local function startCooldownVisual(skillName, duration, overlay, cdTextLabel, strokeUI)
        cooldownActive[skillName] = true
        overlay.Size = UDim2.new(1, 0, 1, 0)
        local startTime = tick()

        -- Tween del overlay de cooldown bajando
        TweenService:Create(overlay, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                Size = UDim2.new(1, 0, 0, 0),
        }):Play()

        -- Actualizar texto de countdown
        task.spawn(function()
                while tick() - startTime < duration do
                        local remaining = math.ceil(duration - (tick() - startTime))
                        if cdTextLabel then cdTextLabel.Text = tostring(remaining) end
                        task.wait(0.1)
                end
                if cdTextLabel then cdTextLabel.Text = "" end
                overlay.Size = UDim2.new(1, 0, 0, 0)
                cooldownActive[skillName] = false
        end)
end

-- ─── EFECTOS LOCALES DE SANGRE ────────────────────────────────
local function spawnLocalBloodSplash(position, count)
        for i = 1, count do
                local p = Instance.new("Part")
                p.Size = Vector3.new(0.2, 0.2, 0.2)
                p.Position = position + Vector3.new(math.random(-2, 2), math.random(0, 3), math.random(-2, 2))
                p.BrickColor = BrickColor.new("Bright red")
                p.Material = Enum.Material.Neon
                p.Shape = Enum.PartType.Ball
                p.Anchored = false
                p.CanCollide = false
                p.CastShadow = false
                p.Parent = Workspace
                local bv = Instance.new("BodyVelocity")
                bv.Velocity = Vector3.new(math.random(-12, 12), math.random(8, 20), math.random(-12, 12))
                bv.MaxForce = Vector3.new(1e4, 1e4, 1e4)
                bv.Parent = p
                game:GetService("Debris"):AddItem(p, 1.5)
                TweenService:Create(p, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        Transparency = 1,
                        Size = Vector3.new(0.05, 0.05, 0.05),
                }):Play()
        end
end

local function shakeCamera(intensity, duration)
        local startTime = tick()
        local shakeCon
        shakeCon = RunService.RenderStepped:Connect(function()
                local elapsed = tick() - startTime
                if elapsed > duration then
                        shakeCon:Disconnect()
                        return
                end
                local fade = 1 - (elapsed / duration)
                local offset = Vector3.new(
                        (math.random() - 0.5) * intensity * fade,
                        (math.random() - 0.5) * intensity * fade,
                        (math.random() - 0.5) * intensity * fade
                )
                Camera.CFrame = Camera.CFrame * CFrame.new(offset)
        end)
end

local function playBloodAura(character, duration, color)
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local aura = Instance.new("Part")
        aura.Name = "BloodAura"
        aura.Size = Vector3.new(6, 6, 6)
        aura.Shape = Enum.PartType.Ball
        aura.CFrame = hrp.CFrame
        aura.BrickColor = BrickColor.new("Bright red")
        aura.Material = Enum.Material.Neon
        aura.Anchored = true   -- Anchored para que el weld no falle
        aura.CanCollide = false
        aura.CastShadow = false
        aura.Transparency = 0.7
        aura.Parent = Workspace

        -- Seguir al HRP manualmente (más confiable que WeldConstraint en partes ancladas)
        local followConn
        followConn = RunService.RenderStepped:Connect(function()
                if aura and aura.Parent and hrp and hrp.Parent then
                        aura.CFrame = hrp.CFrame
                else
                        if followConn then followConn:Disconnect() end
                end
        end)

        local emit = Instance.new("ParticleEmitter")
        emit.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, color or Color3.fromRGB(200, 0, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0)),
        }
        emit.LightEmission = 1
        emit.Rate = 50
        emit.Speed = NumberRange.new(5, 12)
        emit.Lifetime = NumberRange.new(0.5, 1.2)
        emit.Size = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.5),
                NumberSequenceKeypoint.new(1, 0),
        }
        emit.Parent = aura

        TweenService:Create(aura, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Transparency = 0.55,
                Size = Vector3.new(7, 7, 7),
        }):Play()

        task.delay(duration - 0.5, function()
                if aura and aura.Parent then
                        emit.Enabled = false
                        TweenService:Create(aura, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                Transparency = 1,
                                Size = Vector3.new(1, 1, 1),
                        }):Play()
                        task.delay(0.5, function()
                                if followConn then followConn:Disconnect() end
                                if aura and aura.Parent then aura:Destroy() end
                        end)
                end
        end)
        if duration > 0 then
                task.delay(duration + 0.6, function()
                        if followConn then followConn:Disconnect() end
                        if aura and aura.Parent then aura:Destroy() end
                end)
        end
        return aura
end

-- ─── EFECTO CÁMARA LENTA LOCAL ────────────────────────────────
local function slowMotionEffect(duration)
        -- Efecto visual de cámara lenta: solo blur, sin overlay rojo
        local blur = Instance.new("BlurEffect")
        blur.Size = 0
        blur.Parent = Camera
        TweenService:Create(blur, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = 8,
        }):Play()
        task.delay(duration * 0.2, function()
                TweenService:Create(blur, TweenInfo.new(duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                        Size = 4,
                }):Play()
        end)
        task.delay(duration, function()
                TweenService:Create(blur, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        Size = 0,
                }):Play()
                task.delay(0.4, function()
                        blur:Destroy()
                end)
        end)
end

-- ─── EFECTO STUN LOCAL (recibir látigo) ───────────────────────
local stunVisual = nil

RE_Stun.OnClientEvent:Connect(function(duration)
        isStunned = true
        stunEndTime = tick() + duration

        -- Solo shake de cámara, sin ningún cartel ni overlay
        shakeCamera(0.3, 0.5)

        task.delay(duration, function()
                isStunned = false
        end)
end)

-- ─── DESBLOQUEAR PODER 1000 ALMAS ────────────────────────────
RE_Unlock1000.OnClientEvent:Connect(function()
        if souls1000Button then
                souls1000Button.Visible = true
                souls1000Button.BackgroundTransparency = 1

                -- Animación de desbloqueo épica
                TweenService:Create(bg4, TweenInfo.new(0, Enum.EasingStyle.Linear), {
                        BackgroundTransparency = 1,
                }):Play()

                -- Flash de desbloqueo
                local flash = Instance.new("Frame")
                flash.Size = UDim2.new(1, 0, 1, 0)
                flash.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
                flash.BackgroundTransparency = 0.3
                flash.BorderSizePixel = 0
                flash.ZIndex = 25
                flash.Parent = ScreenGui
                TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 1,
                }):Play()
                task.delay(0.8, function() flash:Destroy() end)

                -- Texto de desbloqueo
                local unlockTxt = Instance.new("TextLabel")
                unlockTxt.Size = UDim2.new(0.6, 0, 0.15, 0)
                unlockTxt.Position = UDim2.new(0.2, 0, 0.35, 0)
                unlockTxt.BackgroundTransparency = 1
                unlockTxt.Text = "☠ ¡PODER DESBLOQUEADO!\n1000 ALMAS ☠"
                unlockTxt.TextScaled = true
                unlockTxt.Font = Enum.Font.GothamBold
                unlockTxt.TextColor3 = Color3.fromRGB(200, 100, 255)
                unlockTxt.TextStrokeTransparency = 0.2
                unlockTxt.TextStrokeColor3 = Color3.fromRGB(80, 0, 120)
                unlockTxt.ZIndex = 26
                unlockTxt.TextTransparency = 0
                unlockTxt.Parent = ScreenGui
                TweenService:Create(unlockTxt, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        TextTransparency = 1,
                        Position = UDim2.new(0.2, 0, 0.25, 0),
                }):Play()
                task.delay(2.5, function() unlockTxt:Destroy() end)

                shakeCamera(0.5, 0.8)
        end
end)

-- ─── RECIBIR EFECTOS DEL SERVIDOR ────────────────────────────
RE_Effect.OnClientEvent:Connect(function(effectName, ...)
        local args = {...}

        -- BOLA DE SANGRE - LANZAMIENTO
        if effectName == "BloodBall_Cast" then
                local casterPlayer = args[1]
                if casterPlayer and casterPlayer.Character then
                        playBloodAura(casterPlayer.Character, 0.6)

                        -- Charge Up Particle Effect: brillo de carga en la mano
                        local char = casterPlayer.Character
                        local lArm = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
                        if lArm then
                                local chargePart = Instance.new("Part")
                                chargePart.Size = Vector3.new(0.1, 0.1, 0.1)
                                chargePart.CFrame = lArm.CFrame
                                chargePart.Anchored = true
                                chargePart.CanCollide = false
                                chargePart.Transparency = 1
                                chargePart.CastShadow = false
                                chargePart.Parent = Workspace

                                local chargePE = Instance.new("ParticleEmitter")
                                chargePE.Texture = "rbxassetid://122502397357855"  -- Charge Up Particle Effect
                                chargePE.Color = ColorSequence.new{
                                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 0)),
                                        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 0, 0)),
                                }
                                chargePE.LightEmission = 1
                                chargePE.Size = NumberSequence.new{
                                        NumberSequenceKeypoint.new(0, 0.6),
                                        NumberSequenceKeypoint.new(1, 0),
                                }
                                chargePE.Speed = NumberRange.new(3, 8)
                                chargePE.Rate = 0
                                chargePE.Lifetime = NumberRange.new(0.2, 0.5)
                                chargePE.SpreadAngle = Vector2.new(40, 40)
                                chargePE.RotSpeed = NumberRange.new(-180, 180)
                                chargePE.Parent = chargePart
                                chargePE:Emit(25)
                                game:GetService("Debris"):AddItem(chargePart, 1)
                        end
                end

        -- BOLA DE SANGRE - EXPLOSIÓN
        elseif effectName == "BloodBall_Explode" then
                local pos = args[1]
                if not pos then return end
                spawnLocalBloodSplash(pos, 60)
                shakeCamera(1.8, 0.9)

                -- Flash rojo de explosión (breve, no cubre pantalla)
                local flash = Instance.new("Frame")
                flash.Size = UDim2.new(1, 0, 1, 0)
                flash.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
                flash.BackgroundTransparency = 0.75
                flash.BorderSizePixel = 0
                flash.ZIndex = 20
                flash.Parent = ScreenGui
                TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 1,
                }):Play()
                task.delay(0.3, function() flash:Destroy() end)

                -- Onda expansiva visual: 4 anillos
                for ring = 1, 4 do
                        task.delay(ring * 0.06, function()
                                local wave = Instance.new("Part")
                                wave.Shape = Enum.PartType.Cylinder
                                wave.Size = Vector3.new(0.15, ring * 1.5, ring * 1.5)
                                wave.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
                                wave.BrickColor = ring <= 2 and BrickColor.new("Bright red") or BrickColor.new("Dark red")
                                wave.Material = Enum.Material.Neon
                                wave.Anchored = true
                                wave.CanCollide = false
                                wave.Transparency = 0.3
                                wave.CastShadow = false
                                wave.Parent = Workspace
                                TweenService:Create(wave, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                        Size = Vector3.new(0.05, 24 * ring, 24 * ring),
                                        Transparency = 1,
                                }):Play()
                                game:GetService("Debris"):AddItem(wave, 0.9)
                        end)
                end

        -- GLÓBULOS - INICIO
        elseif effectName == "BloodCorpuscle_Start" then
                local casterPlayer = args[1]
                if casterPlayer and casterPlayer.Character then
                        playBloodAura(casterPlayer.Character, 3)
                        shakeCamera(0.3, 0.5)
                end
                slowMotionEffect(4)

        -- GLÓBULOS - TRANSFORMACIÓN
        elseif effectName == "BloodCorpuscle_Transform" then
                shakeCamera(0.5, 0.8)

        -- ESPINA - IMPACTO
        elseif effectName == "Spine_Hit" then
                local pos = args[1]
                if pos then
                        spawnLocalBloodSplash(pos, 8)
                end

        -- LÁTIGO - LANZAMIENTO
        elseif effectName == "BloodWhip_Cast" then
                local casterPlayer = args[1]
                local targetPlayer = args[2]
                if casterPlayer and casterPlayer.Character then
                        playBloodAura(casterPlayer.Character, 8, Color3.fromRGB(180, 0, 0))
                end
                shakeCamera(0.8, 0.8)
                slowMotionEffect(3)

        -- 1000 ALMAS - INICIO
        elseif effectName == "Souls1000_Start" then
                local casterPlayer = args[1]
                if casterPlayer and casterPlayer.Character then
                        playBloodAura(casterPlayer.Character, 5, Color3.fromRGB(150, 0, 200))
                end
                shakeCamera(0.8, 1.0)
                slowMotionEffect(5)

                -- Oscurecer cielo dramáticamente
                local sky = Workspace:FindFirstChildOfClass("Sky")

        -- 1000 ALMAS - FORMA CRISTAL
        elseif effectName == "Souls1000_CrystalForm" then
                shakeCamera(0.6, 0.8)
                -- Flash lila
                local flash = Instance.new("Frame")
                flash.Size = UDim2.new(1, 0, 1, 0)
                flash.BackgroundColor3 = Color3.fromRGB(120, 0, 200)
                flash.BackgroundTransparency = 0.6
                flash.BorderSizePixel = 0
                flash.ZIndex = 20
                flash.Parent = ScreenGui
                TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 1,
                }):Play()
                task.delay(0.8, function() flash:Destroy() end)

        -- 1000 ALMAS - LANZAMIENTO
        elseif effectName == "Souls1000_Launch" then
                shakeCamera(1.5, 1.5)

        -- 1000 ALMAS - GOLPE FINAL
        elseif effectName == "Souls1000_FinalBlow" then
                local pos = args[1]
                shakeCamera(2.5, 1.2)
                if pos then
                        spawnLocalBloodSplash(pos, 50)
                end
                -- Flash blanco de impacto
                local flash = Instance.new("Frame")
                flash.Size = UDim2.new(1, 0, 1, 0)
                flash.BackgroundColor3 = Color3.fromRGB(255, 150, 255)
                flash.BackgroundTransparency = 0.2
                flash.BorderSizePixel = 0
                flash.ZIndex = 22
                flash.Parent = ScreenGui
                TweenService:Create(flash, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 1,
                }):Play()
                task.delay(1.0, function() flash:Destroy() end)

        -- CRISTAL IMPACTA
        elseif effectName == "Crystal_Hit" then
                local pos = args[1]
                if pos then spawnLocalBloodSplash(pos, 6) end
        end
end)

-- ─── ENTRADA DE TECLADO ───────────────────────────────────────
local keybinds = {
        [Enum.KeyCode.Q] = function()
                if cooldownActive.BloodBall then return end
                if isStunned and tick() < stunEndTime then return end
                startCooldownVisual("BloodBall", COOLDOWN.BloodBall, cd1, cdt1, stroke1)
                epicActivationEffect(function()
                        flashBracelet()
                        RE_BloodBall:FireServer()
                end)
        end,
        [Enum.KeyCode.E] = function()
                if cooldownActive.BloodCorpuscle then return end
                if isStunned and tick() < stunEndTime then return end
                startCooldownVisual("BloodCorpuscle", COOLDOWN.BloodCorpuscle, cd2, cdt2, stroke2)
                epicActivationEffect(function()
                        flashBracelet()
                        RE_BloodCorpuscle:FireServer()
                end)
        end,
        [Enum.KeyCode.R] = function()
                if cooldownActive.BloodWhip then return end
                if isStunned and tick() < stunEndTime then return end
                startCooldownVisual("BloodWhip", COOLDOWN.BloodWhip, cd3, cdt3, stroke3)
                epicActivationEffect(function()
                        flashBracelet()
                        RE_BloodWhip:FireServer()
                end)
        end,
        [Enum.KeyCode.F] = function()
                if not souls1000Button or not souls1000Button.Visible then return end
                if cooldownActive.Souls1000 then return end
                if isStunned and tick() < stunEndTime then return end
                startCooldownVisual("Souls1000", COOLDOWN.Souls1000, cd4, cdt4, stroke4)
                epicActivationEffect(function()
                        flashBracelet()
                        RE_Souls1000:FireServer()
                end)
        end,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if keybinds[input.KeyCode] then
                keybinds[input.KeyCode]()
        end
end)

-- ─── TOQUE MÓVIL (botones) ────────────────────────────────────
local function setupTouchButton(bgFrame, actionFunc)
        bgFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or
                   input.UserInputType == Enum.UserInputType.MouseButton1 then
                        -- Feedback visual de presión
                        TweenService:Create(bgFrame, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 72, 0, 72),
                                Position = UDim2.new(0.5, -36, 0, 4),
                        }):Play()
                        task.delay(0.1, function()
                                TweenService:Create(bgFrame, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                                        Size = UDim2.new(0, 80, 0, 80),
                                        Position = UDim2.new(0.5, -40, 0, 0),
                                }):Play()
                        end)
                        actionFunc()
                end
        end)
end

setupTouchButton(bg1, keybinds[Enum.KeyCode.Q])
setupTouchButton(bg2, keybinds[Enum.KeyCode.E])
setupTouchButton(bg3, keybinds[Enum.KeyCode.R])
setupTouchButton(bg4, keybinds[Enum.KeyCode.F])

-- ─── ANIMACIÓN IDLE DE BOTONES ────────────────────────────────
-- Stroke parpadeante en botones listos
task.spawn(function()
        local strokes = {stroke1, stroke2, stroke3}
        while true do
                for _, s in ipairs(strokes) do
                        if s and s.Parent then
                                TweenService:Create(s, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                                        Thickness = 3.5,
                                }):Play()
                        end
                end
                task.wait(1)
                for _, s in ipairs(strokes) do
                        if s and s.Parent then
                                TweenService:Create(s, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                                        Thickness = 1.5,
                                }):Play()
                        end
                end
                task.wait(1)
        end
end)

print("[BloodPowers] LocalScript cargado correctamente ✓")

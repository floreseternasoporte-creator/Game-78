-- ============================================================
--   BLOOD POWERS - SERVER SCRIPT
--   Coloca esto en: ServerScriptService > ServerScript
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- ─── REMOTE EVENTS ───────────────────────────────────────────
local RemoteFolder = Instance.new("Folder")
RemoteFolder.Name = "BloodPowerEvents"
RemoteFolder.Parent = ReplicatedStorage

local function makeRemote(name)
        local r = Instance.new("RemoteEvent")
        r.Name = name
        r.Parent = RemoteFolder
        return r
end

local RE_BloodBall      = makeRemote("BloodBall")
local RE_BloodCorpuscle = makeRemote("BloodCorpuscle")
local RE_BloodWhip      = makeRemote("BloodWhip")
local RE_Souls1000      = makeRemote("Souls1000")
local RE_Effect         = makeRemote("EffectToAll")
local RE_Stun           = makeRemote("StunTarget")
local RE_Unlock1000     = makeRemote("Unlock1000Souls")
local RE_Anim           = makeRemote("PlayAnim")       -- animaciones de artes marciales
local RE_Bracelet       = makeRemote("SpawnBracelet")  -- manilla de sangre

-- ─── COOLDOWNS ───────────────────────────────────────────────
local cooldowns = {}
local stunned   = {}      -- jugadores aturdidos { [player] = tickEnd }
local whipActive = {}     -- jugadores con látigo activo { [player] = targetPlayer }
local souls1000Unlocked = {}  -- jugadores con 1000 almas desbloqueado

local COOLDOWN = {
        BloodBall      = 4,
        BloodCorpuscle = 8,
        BloodWhip      = 12,
        Souls1000      = 20,
}

-- ─── IDs DE VFX (Roblox Asset IDs) ──────────────────────────
local VFX = {
        -- Bola de Sangre
        BB_Fireball       = 113831670560719,
        BB_EnergyBall     = 82367301818626,
        BB_MagicProjectile= 131948820606303,
        BB_ImpactExplosion= 71947288327190,
        BB_ChargeUp       = 122502397357855,
        -- Glóbulos
        GL_SpikeTrap      = 9116524151,
        GL_GroundSpike    = 73355950303304,
        GL_BloodSpike     = 139916424589528,
        GL_SummonRising   = 134398499898167,
        GL_EarthShatter   = 92035105491671,
        GL_WhipTrail      = 134671140004532,
        -- Látigo de Sangre
        WH_EnergyChain    = 111623916390946,
        WH_TentacleRig    = 135255029422683,
        WH_GrapeHook      = 118662377115778,
        WH_BeamTrail      = 82367301818626,
        -- 1000 Almas (audios — rellena los IDs desde el Creator Dashboard)
        S1000_Audio1      = 0,
        S1000_Audio2      = 0,
        S1000_Audio3      = 0,
}

local function isOnCooldown(player, skill)
        local key = player.UserId .. "_" .. skill
        local t = cooldowns[key]
        if t and (tick() - t) < COOLDOWN[skill] then
                return true   -- en cooldown, NO actualizar el timestamp
        end
        cooldowns[key] = tick()   -- registrar inicio de cooldown solo cuando no está activo
        return false
end

local function isStunned(player)
        local endTime = stunned[player]
        if endTime and tick() < endTime then
                return true
        end
        stunned[player] = nil
        return false
end

-- ─── UTILIDADES ──────────────────────────────────────────────
local function getNearestEnemy(caster, radius)
        local hrp = caster.Character and caster.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local closest, dist = nil, radius
        for _, p in ipairs(Players:GetPlayers()) do
                if p ~= caster and p.Character then
                        local eh = p.Character:FindFirstChild("HumanoidRootPart")
                        if eh then
                                local d = (eh.Position - hrp.Position).Magnitude
                                if d < dist then
                                        dist = d
                                        closest = p
                                end
                        end
                end
        end
        return closest
end

local function dealDamage(target, amount)
        if not target or not target.Character then return end
        local hum = target.Character:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 then
                hum:TakeDamage(amount)
                return true
        end
        return false
end

local function applyKnockback(target, direction, force)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        -- Normalizar dirección y limitar componente Y para evitar que salga volando
        local dir = direction.Unit
        local cappedDir = Vector3.new(dir.X, math.clamp(dir.Y, -0.3, 0.5), dir.Z).Unit
        local bp = Instance.new("BodyVelocity")
        bp.Velocity = cappedDir * force
        bp.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bp.Parent = hrp
        game:GetService("Debris"):AddItem(bp, 0.35)
end

local function spawnBloodParticle(position, color, size, duration)
        local p = Instance.new("Part")
        p.Size = Vector3.new(size, size, size)
        p.Position = position
        p.BrickColor = color or BrickColor.new("Bright red")
        p.Material = Enum.Material.Neon
        p.Shape = Enum.PartType.Ball
        p.Anchored = true
        p.CanCollide = false
        p.CastShadow = false
        p.Parent = Workspace
        game:GetService("Debris"):AddItem(p, duration or 1)
        return p
end

-- ─── MANILLA DE SANGRE AL SPAWN ──────────────────────────────
-- Tabla global: permite que los eventos de skills accedan a las partes
-- de la pulsera de cada jugador para animarlas (ej. desaparecer el aro)
local playerBraceletParts = {}  -- player -> allBraceletParts
local playerLeftArm = {}        -- player -> leftArm part (cache)

local function equipBloodBracelet(player)
        local char = player.Character or player.CharacterAdded:Wait()
        -- Esperar a que el personaje esté completamente cargado
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        -- Soportar R6 ("Left Arm") y R15 ("LeftLowerArm" o "LeftHand")
        local leftArm = char:FindFirstChild("Left Arm")
                or char:FindFirstChild("LeftHand")
                or char:FindFirstChild("LeftLowerArm")
        if not leftArm then return end

        -- Quitar manilla previa (partes Y la luz que dejamos en leftArm)
        for _, v in ipairs(leftArm:GetChildren()) do
                if v.Name == "BloodBracelet" or v.Name == "BraceletOrb" or v.Name == "BraceletGlow" then
                        v:Destroy()
                end
        end

        -- ── CONFIGURACIÓN POSICIÓN EN MUÑECA ───────────────────────────
        -- R6: "Left Arm" = 2 studs alto, muñeca en -0.82 desde centro
        -- R15: "LeftHand" = pequeño, muñeca en -0.25
        local isR6 = (leftArm.Name == "Left Arm")
        local wristY = isR6 and -0.82 or -0.25

        -- ── TABLA DE TODAS LAS PARTES DE LA MANILLA ────────────────────
        -- NO usamos WeldConstraint en ninguna — todas se actualizan en el Heartbeat loop
        -- Esto elimina el parpadeo (WeldConstraint peleaba con el loop)
        local allBraceletParts = {}  -- { {part, baseAngle, radius, yOffset} }

        -- ── ARO PRINCIPAL: 16 bolitas medianas formando un círculo ──────
        -- (Reemplaza el Cylinder que aparecía como "palito rojo")
        local RING_COUNT  = 16
        local RING_RADIUS = 0.52
        for i = 1, RING_COUNT do
                local angle = (i / RING_COUNT) * math.pi * 2
                local ringOrb = Instance.new("Part")
                ringOrb.Name = "BloodBracelet"
                ringOrb.Size = Vector3.new(0.13, 0.13, 0.13)
                ringOrb.Shape = Enum.PartType.Ball
                -- Alternar colores para efecto de aro
                if i % 2 == 0 then
                        ringOrb.BrickColor = BrickColor.new("Bright red")
                else
                        ringOrb.BrickColor = BrickColor.new("Crimson")
                end
                ringOrb.Material = Enum.Material.Neon
                ringOrb.Transparency = 0.0
                ringOrb.CanCollide = false
                ringOrb.CastShadow = false
                -- Posición inicial (se actualiza cada frame)
                ringOrb.CFrame = leftArm.CFrame * CFrame.new(
                        RING_RADIUS * math.cos(angle), wristY, RING_RADIUS * math.sin(angle)
                )
                ringOrb.Parent = leftArm
                -- Luz pequeña en cada perla del aro
                local pl = Instance.new("PointLight")
                pl.Color = Color3.fromRGB(255, 0, 0)
                pl.Brightness = 0.6
                pl.Range = 1.5
                pl.Parent = ringOrb
                table.insert(allBraceletParts, {part = ringOrb, baseAngle = angle, radius = RING_RADIUS, yOff = wristY, speed = 1.4})
        end

        -- ── ORBS EXTERNOS GIRANDO (bolitas grandes que orbitan alrededor) ──
        local OUTER_COUNT  = 10
        local OUTER_RADIUS = 0.65
        for i = 1, OUTER_COUNT do
                local baseAngle = (i / OUTER_COUNT) * math.pi * 2
                local orb = Instance.new("Part")
                orb.Name = "BraceletOrb"
                local isLarge = (i % 2 == 0)
                orb.Size = isLarge and Vector3.new(0.24, 0.24, 0.24) or Vector3.new(0.16, 0.16, 0.16)
                orb.Shape = Enum.PartType.Ball
                orb.BrickColor = isLarge and BrickColor.new("Crimson") or BrickColor.new("Bright red")
                orb.Material = Enum.Material.Neon
                orb.Transparency = 0.0
                orb.CanCollide = false
                orb.CastShadow = false
                orb.CFrame = leftArm.CFrame * CFrame.new(
                        OUTER_RADIUS * math.cos(baseAngle), wristY, OUTER_RADIUS * math.sin(baseAngle)
                )
                orb.Parent = leftArm

                local pl2 = Instance.new("PointLight")
                pl2.Color = Color3.fromRGB(255, 0, 0)
                pl2.Brightness = isLarge and 1.0 or 0.6
                pl2.Range = isLarge and 2.5 or 1.8
                pl2.Parent = orb

                local drip = Instance.new("ParticleEmitter")
                drip.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 0, 0)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0)),
                }
                drip.LightEmission = 1
                drip.Size = NumberSequence.new{
                        NumberSequenceKeypoint.new(0, 0.1),
                        NumberSequenceKeypoint.new(1, 0),
                }
                drip.Speed = NumberRange.new(0.3, 1.8)
                drip.Rate = 10
                drip.Lifetime = NumberRange.new(0.3, 0.7)
                drip.Parent = orb
                -- Los orbs externos giran más rápido que el aro
                table.insert(allBraceletParts, {part = orb, baseAngle = baseAngle, radius = OUTER_RADIUS, yOff = wristY, speed = 2.2})
        end

        -- ── ORBS INTERIORES (segunda órbita pequeña) ───────────────────
        local INNER_COUNT  = 6
        local INNER_RADIUS = 0.30
        for i = 1, INNER_COUNT do
                local baseAngle = (i / INNER_COUNT) * math.pi * 2 + math.pi / INNER_COUNT
                local micro = Instance.new("Part")
                micro.Name = "BraceletOrb"
                micro.Size = Vector3.new(0.10, 0.10, 0.10)
                micro.Shape = Enum.PartType.Ball
                micro.BrickColor = BrickColor.new("Dark red")
                micro.Material = Enum.Material.Neon
                micro.Transparency = 0.1
                micro.CanCollide = false
                micro.CastShadow = false
                micro.CFrame = leftArm.CFrame * CFrame.new(
                        INNER_RADIUS * math.cos(baseAngle), wristY, INNER_RADIUS * math.sin(baseAngle)
                )
                micro.Parent = leftArm
                -- Órbita interior gira en dirección opuesta
                table.insert(allBraceletParts, {part = micro, baseAngle = baseAngle, radius = INNER_RADIUS, yOff = wristY, speed = -1.8})
        end

        -- ── HEARTBEAT LOOP: mueve TODAS las partes cada frame ──────────
        -- Un único loop — sin WeldConstraint — elimina el parpadeo
        local rotConn
        -- Registrar para que los skills puedan animar el aro (ej. desaparecer antes de lanzar)
        playerBraceletParts[player] = allBraceletParts
        playerLeftArm[player] = leftArm

        rotConn = RunService.Heartbeat:Connect(function()
                if not leftArm or not leftArm.Parent then
                        rotConn:Disconnect()
                        return
                end
                local t = tick()
                for _, data in ipairs(allBraceletParts) do
                        local p = data.part
                        if p and p.Parent then
                                local angle = data.baseAngle + t * data.speed
                                p.CFrame = leftArm.CFrame * CFrame.new(
                                        data.radius * math.cos(angle),
                                        data.yOff,
                                        data.radius * math.sin(angle)
                                )
                        end
                end
        end)

        -- ── LUZ DE AURA PERMANENTE (sin part adicional) ─────────────────
        -- Ponemos la luz directamente en el leftArm para no añadir partes extras
        local existingLight = leftArm:FindFirstChildOfClass("PointLight")
        if not existingLight then
                local braceletLight = Instance.new("PointLight")
                braceletLight.Name = "BraceletGlow"
                braceletLight.Color = Color3.fromRGB(255, 0, 0)
                braceletLight.Brightness = 1.2
                braceletLight.Range = 3
                braceletLight.Parent = leftArm
        end
end

-- ── ANIMACIÓN DE RECOGIDA DEL ARO ───────────────────────────────
-- Hace que las perlas del aro principal desaparezcan UNA POR UNA,
-- como si la energía se concentrara para ser lanzada.
-- duration = tiempo total que debe durar la secuencia completa.
local function collapseBraceletRing(player, duration)
        local parts = playerBraceletParts[player]
        if not parts then return end

        -- Filtrar solo las perlas del aro principal (Name == "BloodBracelet")
        local ringParts = {}
        for _, data in ipairs(parts) do
                if data.part and data.part.Parent and data.part.Name == "BloodBracelet" then
                        table.insert(ringParts, data.part)
                end
        end
        if #ringParts == 0 then return end

        local stepDelay = duration / #ringParts
        for i, part in ipairs(ringParts) do
                task.delay((i - 1) * stepDelay, function()
                        if part and part.Parent then
                                -- Guardar tamaño original para poder restaurarlo después
                                if not part:GetAttribute("OrigSizeX") then
                                        part:SetAttribute("OrigSizeX", part.Size.X)
                                end
                                TweenService:Create(part, TweenInfo.new(stepDelay * 0.8, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                                        Size = Vector3.new(0.01, 0.01, 0.01),
                                        Transparency = 1,
                                }):Play()
                        end
                end)
        end
end

-- Restaura las perlas del aro a su tamaño y transparencia original
-- (se llama después de que el poder fue lanzado)
local function restoreBraceletRing(player, fadeInTime)
        fadeInTime = fadeInTime or 0.3
        local parts = playerBraceletParts[player]
        if not parts then return end

        for _, data in ipairs(parts) do
                local part = data.part
                if part and part.Parent and part.Name == "BloodBracelet" then
                        local origSize = part:GetAttribute("OrigSizeX") or 0.13
                        TweenService:Create(part, TweenInfo.new(fadeInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                                Size = Vector3.new(origSize, origSize, origSize),
                                Transparency = 0,
                        }):Play()
                end
        end
end

Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
                task.delay(1, function()
                        equipBloodBracelet(player)
                end)
        end)
end)

-- Equipar a jugadores ya en el servidor
for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
                task.delay(0.5, function() equipBloodBracelet(player) end)
        end
end


RE_BloodBall.OnServerEvent:Connect(function(player)
        if isOnCooldown(player, "BloodBall") then return end
        if isStunned(player) then return end

        local char = player.Character
        if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Animación: el brazo sube lento cargando energía, luego baja lanzando
        RE_Anim:FireAllClients(player, "BloodBall_Pose")
        RE_Effect:FireAllClients("BloodBall_Cast", player)

        -- El aro de la pulsera se va recogiendo mientras el brazo carga (0.55s)
        collapseBraceletRing(player, 0.5)

        -- Esperar a que el brazo termine de bajar/lanzar antes de crear la bola
        task.delay(0.62, function()
        -- Origen: desde la manilla (muñeca izquierda)
        local leftArm = char:FindFirstChild("Left Arm")
                or char:FindFirstChild("LeftHand")
                or char:FindFirstChild("LeftLowerArm")
        local spawnPos = leftArm and (leftArm.Position + Vector3.new(0, -0.7, 0)) or (hrp.Position + hrp.CFrame.LookVector * 2 + Vector3.new(0, 0.5, 0))

        -- Flash en la manilla: solo pulsar la luz, sin tocar Size ni Position
        -- (animar Size pelea con el Heartbeat loop y causa flash al suelo)
        if leftArm then
                for _, v in ipairs(leftArm:GetChildren()) do
                        local pl = v:FindFirstChildOfClass("PointLight")
                        if pl then
                                local origBright = pl.Brightness
                                pl.Brightness = origBright * 4
                                task.delay(0.12, function()
                                        if pl and pl.Parent then pl.Brightness = origBright end
                                end)
                        end
                end
        end

        -- Crear la bola: nace en la manilla y viaja hacia adelante
        local ball = Instance.new("Part")
        ball.Name = "BloodBall"
        ball.Size = Vector3.new(0.3, 0.3, 0.3)
        ball.Shape = Enum.PartType.Ball
        ball.Position = spawnPos
        ball.BrickColor = BrickColor.new("Bright red")
        ball.Material = Enum.Material.Neon
        ball.Anchored = false
        ball.CanCollide = false
        ball.CastShadow = false
        ball.Parent = Workspace

        -- Crece rápido y brutal mientras sale de la manilla
        TweenService:Create(ball, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = Vector3.new(3.0, 3.0, 3.0),
        }):Play()

        -- Luz muy intensa: ilumina todo el entorno
        local pl = Instance.new("PointLight")
        pl.Color = Color3.fromRGB(255, 20, 0)
        pl.Brightness = 14
        pl.Range = 28
        pl.Parent = ball

        -- Estela de sangre líquida densa — usa Fireball VFX + Magic Projectile
        local trail = Instance.new("ParticleEmitter")
        trail.Texture = "rbxassetid://" .. VFX.BB_Fireball
        trail.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 0)),
                ColorSequenceKeypoint.new(0.2, Color3.fromRGB(200, 0, 0)),
                ColorSequenceKeypoint.new(0.6, Color3.fromRGB(120, 0, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 0)),
        }
        trail.LightEmission = 1
        trail.Size = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.9),
                NumberSequenceKeypoint.new(0.3, 0.6),
                NumberSequenceKeypoint.new(1, 0),
        }
        trail.Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.0),
                NumberSequenceKeypoint.new(0.5, 0.3),
                NumberSequenceKeypoint.new(1, 1),
        }
        trail.Speed = NumberRange.new(0, 3)
        trail.Rate = 200
        trail.Lifetime = NumberRange.new(0.4, 0.9)
        trail.RotSpeed = NumberRange.new(-360, 360)
        trail.VelocityInheritance = 0.3
        trail.Parent = ball

        -- Segunda capa: chispas con Energy Ball Particle
        local spark = Instance.new("ParticleEmitter")
        spark.Texture = "rbxassetid://" .. VFX.BB_EnergyBall
        spark.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 0, 0)),
        }
        spark.LightEmission = 1
        spark.Size = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.15),
                NumberSequenceKeypoint.new(1, 0),
        }
        spark.Speed = NumberRange.new(4, 10)
        spark.Rate = 80
        spark.Lifetime = NumberRange.new(0.2, 0.5)
        spark.SpreadAngle = Vector2.new(25, 25)
        spark.Parent = ball

        -- Tercera capa: Magic Projectile Effect (carga mientras viaja)
        local magic = Instance.new("ParticleEmitter")
        magic.Texture = "rbxassetid://" .. VFX.BB_MagicProjectile
        magic.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 0, 0)),
        }
        magic.LightEmission = 1
        magic.Size = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.5),
                NumberSequenceKeypoint.new(1, 0),
        }
        magic.Speed = NumberRange.new(0, 1)
        magic.Rate = 30
        magic.Lifetime = NumberRange.new(0.15, 0.3)
        magic.RotSpeed = NumberRange.new(-180, 180)
        magic.Parent = ball

        -- Lanzar la bola
        local bv = Instance.new("BodyVelocity")
        bv.Velocity = hrp.CFrame.LookVector * 90
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Parent = ball

        -- Detectar impacto
        local startTime = tick()
        local hitConnection
        hitConnection = ball.Touched:Connect(function(hit)
                if tick() - startTime < 0.1 then return end
                -- Ignorar cualquier parte del propio personaje del lanzador
                if hit:IsDescendantOf(char) then return end
                local hp = Players:GetPlayerFromCharacter(hit.Parent)
                if hp == player then return end
                if not hitConnection then return end

                hitConnection:Disconnect()
                hitConnection = nil

                -- EXPLOSIÓN
                local explosionPos = ball.Position
                ball:Destroy()

                -- Impact Explosion VFX en el punto de impacto
                local impactPart = Instance.new("Part")
                impactPart.Size = Vector3.new(0.3, 0.3, 0.3)
                impactPart.Position = explosionPos
                impactPart.Anchored = true
                impactPart.CanCollide = false
                impactPart.Transparency = 1
                impactPart.CastShadow = false
                impactPart.Parent = Workspace
                local impactPE = Instance.new("ParticleEmitter")
                impactPE.Texture = "rbxassetid://" .. VFX.BB_ImpactExplosion
                impactPE.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 0)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 0, 0)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0)),
                }
                impactPE.LightEmission = 1
                impactPE.Size = NumberSequence.new{
                        NumberSequenceKeypoint.new(0, 2.0),
                        NumberSequenceKeypoint.new(1, 0),
                }
                impactPE.Speed = NumberRange.new(10, 25)
                impactPE.Rate = 0
                impactPE.Lifetime = NumberRange.new(0.5, 1.0)
                impactPE.SpreadAngle = Vector2.new(90, 90)
                impactPE.RotSpeed = NumberRange.new(-360, 360)
                impactPE.Parent = impactPart
                impactPE:Emit(60)
                game:GetService("Debris"):AddItem(impactPart, 2)

                RE_Effect:FireAllClients("BloodBall_Explode", explosionPos)

                -- Daño en área
                for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= player and p.Character then
                                local eh = p.Character:FindFirstChild("HumanoidRootPart")
                                if eh and (eh.Position - explosionPos).Magnitude < 10 then
                                        dealDamage(p, 35)
                                        local dir = (eh.Position - explosionPos).Unit
                                        applyKnockback(p, dir + Vector3.new(0, 0.5, 0), 60)
                                        RE_Stun:FireClient(p, 1.2)  -- cliente efectos stun
                                end
                        end
                end

                -- Partículas de explosión: LLUVIA BRUTAL de sangre en todas direcciones
                for i = 1, 40 do
                        local angle = math.random() * math.pi * 2
                        local elevation = math.random() * math.pi - math.pi / 2
                        local radius = math.random(2, 14)
                        local spSize = math.random() * 0.8 + 0.2
                        local sp = spawnBloodParticle(
                                explosionPos + Vector3.new(0, math.random(-1, 1), 0),
                                BrickColor.new(i % 3 == 0 and "Crimson" or "Bright red"), spSize, 2.2
                        )
                        local flyDir = Vector3.new(
                                math.cos(angle) * math.cos(elevation) * radius,
                                math.abs(math.sin(elevation)) * radius * 1.5 + math.random(1, 5),
                                math.sin(angle) * math.cos(elevation) * radius
                        )
                        TweenService:Create(sp, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                Position = explosionPos + flyDir,
                                Size = Vector3.new(0.08, 0.08, 0.08),
                                Transparency = 1,
                        }):Play()
                end

                -- Manchas de sangre en el suelo
                for i = 1, 8 do
                        local angle = (i / 8) * math.pi * 2
                        local r = math.random(1, 6)
                        local stain = Instance.new("Part")
                        stain.Size = Vector3.new(math.random(1, 3), 0.05, math.random(1, 3))
                        stain.Position = explosionPos + Vector3.new(math.cos(angle) * r, -1, math.sin(angle) * r)
                        stain.BrickColor = BrickColor.new("Maroon")
                        stain.Material = Enum.Material.SmoothPlastic
                        stain.Anchored = true
                        stain.CanCollide = false
                        stain.CastShadow = false
                        stain.Parent = Workspace
                        TweenService:Create(stain, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                Transparency = 1,
                        }):Play()
                        game:GetService("Debris"):AddItem(stain, 3.5)
                end
        end)

        game:GetService("Debris"):AddItem(ball, 6)

        -- El aro de la pulsera reaparece tras el lanzamiento
        restoreBraceletRing(player, 0.35)
        end) -- cierra task.delay(0.62)
end)

-- ─── PODER 2: GLÓBULOS / ESPINAS ─────────────────────────────
RE_BloodCorpuscle.OnServerEvent:Connect(function(player)
        if isOnCooldown(player, "BloodCorpuscle") then return end
        if isStunned(player) then return end

        local char = player.Character
        if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local origin = hrp.Position

        RE_Anim:FireAllClients(player, "BloodCorpuscle_Pose")
        RE_Effect:FireAllClients("BloodCorpuscle_Start", player)

        -- Fase 1: Glóbulos emergen del suelo alrededor del usuario (0.5s cada uno)
        local globulos = {}
        local RING_COUNT = 12
        local INNER_RADIUS = 4
        local OUTER_RADIUS = 8

        for ring = 1, 2 do
                local r = (ring == 1) and INNER_RADIUS or OUTER_RADIUS
                for i = 1, RING_COUNT do
                        local angle = (i / RING_COUNT) * math.pi * 2
                        local offset = Vector3.new(math.cos(angle) * r, -2, math.sin(angle) * r)
                        local spawnPos = origin + offset

                        local glob = Instance.new("Part")
                        glob.Name = "BloodGlob"
                        glob.Size = Vector3.new(0.6, 0.6, 0.6)
                        glob.Shape = Enum.PartType.Ball
                        glob.Position = spawnPos
                        glob.BrickColor = BrickColor.new("Bright red")
                        glob.Material = Enum.Material.Neon
                        glob.Anchored = true
                        glob.CanCollide = false
                        glob.CastShadow = false
                        glob.Parent = Workspace

                        -- Summon Rising Effect al emerger
                        local risingPE = Instance.new("ParticleEmitter")
                        risingPE.Texture      = "rbxassetid://" .. VFX.GL_SummonRising
                        risingPE.Color        = ColorSequence.new(Color3.fromRGB(180, 0, 0))
                        risingPE.LightEmission = 0.8
                        risingPE.Size         = NumberSequence.new{
                                NumberSequenceKeypoint.new(0, 0.35),
                                NumberSequenceKeypoint.new(1, 0),
                        }
                        risingPE.Speed        = NumberRange.new(2, 6)
                        risingPE.Rate         = 20
                        risingPE.Lifetime     = NumberRange.new(0.3, 0.7)
                        risingPE.Parent       = glob

                        -- Blood Spike Particle alrededor del glóbulo
                        local spikePE = Instance.new("ParticleEmitter")
                        spikePE.Texture       = "rbxassetid://" .. VFX.GL_BloodSpike
                        spikePE.Color         = ColorSequence.new{
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 0, 0)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 0)),
                        }
                        spikePE.LightEmission = 0.9
                        spikePE.Size          = NumberSequence.new{
                                NumberSequenceKeypoint.new(0, 0.2),
                                NumberSequenceKeypoint.new(1, 0),
                        }
                        spikePE.Speed         = NumberRange.new(1, 3)
                        spikePE.Rate          = 12
                        spikePE.Lifetime      = NumberRange.new(0.2, 0.5)
                        spikePE.SpreadAngle   = Vector2.new(30, 30)
                        spikePE.Parent        = glob

                        table.insert(globulos, {part = glob, angle = angle, ring = r})

                        -- Emerge del suelo
                        task.delay((ring - 1) * 0.3 + (i / RING_COUNT) * 0.4, function()
                                if not glob or not glob.Parent then return end
                                TweenService:Create(glob, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                                        Position = spawnPos + Vector3.new(0, 2.5, 0),
                                        Size = Vector3.new(0.8, 0.8, 0.8),
                                }):Play()
                        end)
                end
        end

        -- Fase 2: Crecen y se transforman en espinas (cámara lenta feel - 1.5s)
        task.delay(1.2, function()
                RE_Effect:FireAllClients("BloodCorpuscle_Transform", player)

                -- EARTH shatter vfx: una gran explosión de tierra/sangre en el centro
                local shatterPart = Instance.new("Part")
                shatterPart.Size = Vector3.new(0.3, 0.3, 0.3)
                shatterPart.Position = origin + Vector3.new(0, 0.5, 0)
                shatterPart.Anchored = true
                shatterPart.CanCollide = false
                shatterPart.Transparency = 1
                shatterPart.CastShadow = false
                shatterPart.Parent = Workspace
                local shatterPE = Instance.new("ParticleEmitter")
                shatterPE.Texture = "rbxassetid://" .. VFX.GL_EarthShatter
                shatterPE.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 0, 0)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0)),
                }
                shatterPE.LightEmission = 0.8
                shatterPE.Size = NumberSequence.new{
                        NumberSequenceKeypoint.new(0, 1.2),
                        NumberSequenceKeypoint.new(1, 0),
                }
                shatterPE.Speed = NumberRange.new(8, 18)
                shatterPE.Rate = 0
                shatterPE.Lifetime = NumberRange.new(0.6, 1.2)
                shatterPE.SpreadAngle = Vector2.new(60, 60)
                shatterPE.RotSpeed = NumberRange.new(-180, 180)
                shatterPE.Parent = shatterPart
                shatterPE:Emit(40)
                game:GetService("Debris"):AddItem(shatterPart, 2)

                -- Ground Spike Effect: partículas que suben del suelo en cada espina
                for _, data in ipairs(globulos) do
                        local part = data.part
                        if part and part.Parent then
                        -- Transformación a espina
                        part.Color = Color3.fromRGB(100, 0, 0)
                        TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
                                Size = Vector3.new(0.4, 3.5, 0.4),
                                Color = Color3.fromRGB(80, 0, 0),
                        }):Play()
                        -- Color de espina cristalina
                        task.delay(0.3, function()
                                if part and part.Parent then
                                        part.Material = Enum.Material.Glass
                                        -- Ground Spike Effect en la espina ya transformada
                                        local groundPE = Instance.new("ParticleEmitter")
                                        groundPE.Texture      = "rbxassetid://" .. VFX.GL_GroundSpike
                                        groundPE.Color        = ColorSequence.new(Color3.fromRGB(160, 0, 0))
                                        groundPE.LightEmission = 0.7
                                        groundPE.Size         = NumberSequence.new{
                                                NumberSequenceKeypoint.new(0, 0.25),
                                                NumberSequenceKeypoint.new(1, 0),
                                        }
                                        groundPE.Speed        = NumberRange.new(2, 5)
                                        groundPE.Rate         = 8
                                        groundPE.Lifetime     = NumberRange.new(0.3, 0.6)
                                        groundPE.Parent       = part
                                end
                        end)
                        end -- cierra if part and part.Parent
                end
        end)

        -- Fase 3: Espinas se lanzan hacia el enemigo más cercano (efecto épico)
        -- El aro se recoge justo antes de que los brazos empujen hacia adelante
        task.delay(1.9, function()
                collapseBraceletRing(player, 0.5)
        end)
        task.delay(2.5, function()
                local target = getNearestEnemy(player, 35)

                for i, data in ipairs(globulos) do
                        local part = data.part
                        if part and part.Parent then

                        task.delay((i / #globulos) * 0.6, function()
                                if not part or not part.Parent then return end
                                part.Anchored = false

                                local targetPos = Vector3.new(origin.X, origin.Y + 2, origin.Z)
                                if target and target.Character then
                                        local th = target.Character:FindFirstChild("HumanoidRootPart")
                                        if th then
                                                targetPos = th.Position + Vector3.new(math.random(-2, 2), math.random(-1, 2), math.random(-2, 2))
                                        end
                                end

                                local bv = Instance.new("BodyVelocity")
                                bv.Velocity = (targetPos - part.Position).Unit * 65
                                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                                bv.Parent = part

                                -- Impacto
                                local hitConn
                                hitConn = part.Touched:Connect(function(hit)
                                        local hp = Players:GetPlayerFromCharacter(hit.Parent)
                                        if hp and hp ~= player then
                                                hitConn:Disconnect()
                                                dealDamage(hp, 8)
                                                RE_Effect:FireAllClients("Spine_Hit", part.Position)
                                        end
                                        if hit.Parent ~= char then
                                                part:Destroy()
                                        end
                                end)

                                game:GetService("Debris"):AddItem(part, 3)
                        end)
                        end -- cierra if part and part.Parent
                end

                -- Daño total al enemigo más cercano
                if target then
                        task.delay(0.8, function()
                                dealDamage(target, 45)
                                if target.Character then
                                        local th = target.Character:FindFirstChild("HumanoidRootPart")
                                        if th then
                                                applyKnockback(target, Vector3.new(0, 1, 0), 30)
                                        end
                                end
                        end)
                end

                -- El aro de la pulsera reaparece tras el lanzamiento de espinas
                restoreBraceletRing(player, 0.35)
        end)
end)

-- ─── PODER 3: LÁTIGO DE SANGRE (SOSTÉN) ──────────────────────
RE_BloodWhip.OnServerEvent:Connect(function(player)
        if isOnCooldown(player, "BloodWhip") then return end
        if isStunned(player) then return end

        local char = player.Character
        if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local target = getNearestEnemy(player, 40)
        if not target then return end
        local targetChar = target.Character
        if not targetChar then return end
        local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
        if not targetHrp then return end

        -- Registrar látigo activo
        whipActive[player] = target

        RE_Anim:FireAllClients(player, "BloodWhip_Pose")
        RE_Effect:FireAllClients("BloodWhip_Cast", player, target)

        -- El aro se recoge al invocar: la energía pasa al látigo que se sostiene
        collapseBraceletRing(player, 0.4)

        -- Aturdir al objetivo
        stunned[target] = tick() + 8
        RE_Stun:FireClient(target, 8)

        -- ── LÁTIGO DE SANGRE: WHIP SEGMENTADO ONDULANTE ────────────────
        -- NUEVO SISTEMA: 14 segmentos con objetos Beam de Roblox posicionados
        -- con función seno de fase viajante → látigo real que ondula desde la mano.
        -- Amplitud grande cerca de la mano, pequeña en la punta (física de látigo).

        local WHIP_SEGS    = 14     -- número de segmentos del látigo
        local FORM_TIME    = 0.55   -- segundos hasta extensión completa
        local whipDuration = 8
        local startTime    = tick()

        -- Crear partes ancla invisibles para cada punto del látigo (0 = mano, N = punta)
        local segParts = {}
        local segAtts  = {}
        for i = 0, WHIP_SEGS do
                local sp = Instance.new("Part")
                sp.Size = Vector3.new(0.05, 0.05, 0.05)
                sp.Anchored = true
                sp.CanCollide = false
                sp.CastShadow = false
                sp.Transparency = 1
                sp.Parent = Workspace
                local sa = Instance.new("Attachment", sp)
                segParts[i] = sp
                segAtts[i]  = sa
        end

        -- Crear objetos Beam entre segmentos consecutivos
        -- (Beam en Roblox dibuja una banda continua — no una línea recta como Trail)
        local beams = {}
        for i = 0, WHIP_SEGS - 1 do
                local tProg = i / WHIP_SEGS
                local b = Instance.new("Beam")
                b.Attachment0 = segAtts[i]
                b.Attachment1 = segAtts[i + 1]
                -- Más grueso en la mano, afilado hacia la punta
                b.Width0 = 0.32 * (1 - tProg * 0.70)
                b.Width1 = 0.32 * (1 - (tProg + 1 / WHIP_SEGS) * 0.70)
                b.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 30, 0)),
                        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(200, 0, 0)),
                        ColorSequenceKeypoint.new(0.70, Color3.fromRGB(120, 0, 0)),
                        ColorSequenceKeypoint.new(1,    Color3.fromRGB(50, 0, 0)),
                }
                b.Transparency = NumberSequence.new{
                        NumberSequenceKeypoint.new(0,   0.0),
                        NumberSequenceKeypoint.new(0.8, 0.1),
                        NumberSequenceKeypoint.new(1,   0.55),
                }
                b.LightEmission  = 0.9
                b.LightInfluence = 0.1
                b.FaceCamera     = true
                b.Segments       = 6
                b.CurveSize0     = 0
                b.CurveSize1     = 0
                -- Textura de cadena de energía (Energy Chain VFX)
                b.Texture        = "rbxassetid://" .. VFX.WH_EnergyChain
                b.TextureLength  = 1.2
                b.TextureMode    = Enum.TextureMode.Wrap
                b.Parent = segParts[i]
                beams[i] = b
        end

        -- Luz en el origen (mano) — sigue al segmento 0
        local handLight = Instance.new("PointLight")
        handLight.Color      = Color3.fromRGB(255, 30, 0)
        handLight.Brightness = 6
        handLight.Range      = 12
        handLight.Parent     = segParts[0]

        -- Partícula de gotas en la mano — Beam Trail Particle
        local handDrip = Instance.new("ParticleEmitter")
        handDrip.Texture = "rbxassetid://" .. VFX.WH_BeamTrail
        handDrip.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 10, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 0)),
        }
        handDrip.LightEmission = 0.9
        handDrip.Size = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.18),
                NumberSequenceKeypoint.new(1, 0),
        }
        handDrip.Speed       = NumberRange.new(1, 4)
        handDrip.Rate        = 35
        handDrip.Lifetime    = NumberRange.new(0.2, 0.45)
        handDrip.SpreadAngle = Vector2.new(20, 20)
        handDrip.Parent      = segParts[0]

        -- Chispas de sangre en la punta (se activan cuando llega)
        local tipSpark = Instance.new("ParticleEmitter")
        tipSpark.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 0, 0)),
        }
        tipSpark.LightEmission = 1
        tipSpark.Size = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.22),
                NumberSequenceKeypoint.new(1, 0),
        }
        tipSpark.Speed       = NumberRange.new(2, 5)
        tipSpark.Rate        = 0   -- se activa al llegar
        tipSpark.Lifetime    = NumberRange.new(0.15, 0.35)
        tipSpark.SpreadAngle = Vector2.new(60, 60)
        tipSpark.Parent      = segParts[WHIP_SEGS]

        -- ── LOOP PRINCIPAL: actualiza la forma ondulante cada frame ─────
        local whipConn

        local function destroyWhip()
                for i = 0, WHIP_SEGS do
                        if segParts[i] and segParts[i].Parent then
                                segParts[i]:Destroy()
                        end
                end
        end

        whipConn = RunService.Heartbeat:Connect(function()
                local elapsed = tick() - startTime

                -- Tiempo agotado → limpiar y desbloquear 1000 Almas
                if elapsed > whipDuration then
                        whipConn:Disconnect()
                        destroyWhip()
                        whipActive[player]  = nil
                        stunned[target]     = nil
                        restoreBraceletRing(player, 0.4)
                        if not souls1000Unlocked[player] then
                                souls1000Unlocked[player] = true
                                RE_Unlock1000:FireClient(player)
                        end
                        return
                end

                local ph = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if not ph or not th then
                        whipConn:Disconnect()
                        destroyWhip()
                        whipActive[player] = nil
                        restoreBraceletRing(player, 0.4)
                        return
                end

                -- Posición de la muñeca izquierda del caster
                local lArm = player.Character:FindFirstChild("LeftHand")
                        or player.Character:FindFirstChild("Left Arm")
                local handPos
                if lArm then
                        local isR6arm = (lArm.Name == "Left Arm")
                        handPos = lArm.CFrame:PointToWorldSpace(
                                Vector3.new(0, isR6arm and -0.9 or -0.4, 0)
                        )
                else
                        handPos = ph.CFrame:PointToWorldSpace(Vector3.new(-1.5, -0.5, 0))
                end

                -- Posición del objetivo (torso)
                local targetPos = th.Position + Vector3.new(0, 0.5, 0)

                -- Vector del látigo y dirección lateral (perpendicular) para la onda
                local whipVec = targetPos - handPos
                local dist    = whipVec.Magnitude
                local dir     = whipVec.Unit
                -- Evitar artefacto cuando el látigo apunta directo arriba/abajo
                local upRef   = math.abs(dir.Y) > 0.85 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
                local sideDir = dir:Cross(upRef).Unit

                -- Parámetros de onda viajante (imita física real de látigo)
                local waveSpeed = 5.5    -- velocidad de propagación hacia la punta
                local waveFreq  = 1.8    -- número de ciclos a lo largo del látigo
                local maxAmp    = 1.7    -- amplitud máxima (cerca de la mano)
                local t_now     = tick()

                -- Factor de extensión: el látigo "crece" gradualmente al inicio
                local extFactor = math.min(elapsed / FORM_TIME, 1)

                -- Activar chispas en punta cuando el látigo está completamente extendido
                if extFactor >= 1 and tipSpark.Rate == 0 then
                        tipSpark.Rate = 30
                end

                -- ── ACTUALIZAR POSICIÓN DE CADA SEGMENTO ──────────────────
                for i = 0, WHIP_SEGS do
                        local prog = i / WHIP_SEGS   -- 0 = mano, 1 = punta

                        if prog > extFactor then
                                -- Segmento aún no revelado → pegarlo a la mano
                                segParts[i].CFrame = CFrame.new(handPos)
                        else
                                -- Posición base interpolada a lo largo del látigo
                                local basePos = handPos + dir * (dist * prog)

                                -- Amplitud de onda: grande cerca de la mano, cero en la punta
                                -- (exactamente como un látigo real al chasquear)
                                local amp   = maxAmp * math.pow(1 - prog, 1.15) * extFactor

                                -- Fase viajante: la onda se propaga desde la mano hacia la punta
                                local phase = prog * waveFreq * math.pi * 2 - t_now * waveSpeed

                                -- Desplazamiento lateral principal
                                local lateralOff = math.sin(phase) * amp
                                -- Pequeña ondulación vertical secundaria (da profundidad)
                                local vertOff    = math.sin(phase * 0.65 + math.pi * 0.5) * amp * 0.28

                                segParts[i].CFrame = CFrame.new(
                                        basePos
                                        + sideDir * lateralOff
                                        + Vector3.new(0, vertOff, 0)
                                )
                        end
                end

                -- Daño periódico al objetivo mientras el látigo está activo
                if extFactor >= 1 and math.floor(elapsed * 2) % 2 == 0 then
                        dealDamage(target, 1)
                end
        end)
end)

-- ─── PODER 4: 1000 ALMAS ─────────────────────────────────────
RE_Souls1000.OnServerEvent:Connect(function(player)
        if not souls1000Unlocked[player] then return end
        if isOnCooldown(player, "Souls1000") then return end

        local char = player.Character
        if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local target = getNearestEnemy(player, 50)

        RE_Anim:FireAllClients(player, "Souls1000_Pose")
        RE_Effect:FireAllClients("Souls1000_Start", player)

        -- ── SONIDOS 1000 ALMAS ─────────────────────────────────────────
        -- INSTRUCCIÓN: Busca los IDs de audio en el Creator Dashboard de Roblox
        -- (Creator Hub → Audio → Store) y reemplaza los 0 en la tabla VFX arriba.
        -- Cuando VFX.S1000_Audio1 ~= 0, el sonido se reproducirá automáticamente.
        if VFX.S1000_Audio1 ~= 0 then
                local snd = Instance.new("Sound")
                snd.SoundId = "rbxassetid://" .. VFX.S1000_Audio1
                snd.Volume = 1.5
                snd.RollOffMaxDistance = 80
                snd.Parent = hrp
                snd:Play()
                game:GetService("Debris"):AddItem(snd, 10)
        end
        if VFX.S1000_Audio2 ~= 0 then
                task.delay(0.8, function()
                        if not hrp or not hrp.Parent then return end
                        local snd2 = Instance.new("Sound")
                        snd2.SoundId = "rbxassetid://" .. VFX.S1000_Audio2
                        snd2.Volume = 1.2
                        snd2.RollOffMaxDistance = 80
                        snd2.Parent = hrp
                        snd2:Play()
                        game:GetService("Debris"):AddItem(snd2, 10)
                end)
        end
        if VFX.S1000_Audio3 ~= 0 then
                task.delay(3.0, function()
                        if not hrp or not hrp.Parent then return end
                        local snd3 = Instance.new("Sound")
                        snd3.SoundId = "rbxassetid://" .. VFX.S1000_Audio3
                        snd3.Volume = 1.8
                        snd3.RollOffMaxDistance = 100
                        snd3.Parent = hrp
                        snd3:Play()
                        game:GetService("Debris"):AddItem(snd3, 10)
                end)
        end

        -- Fase 1: Sangre emerge de la tierra épicamente (8 oleadas)
        local allCrystals = {}

        for wave = 1, 8 do
                task.delay(wave * 0.2, function()
                        local waveRadius = 3 + wave * 2.5
                        local count = 8 + wave * 3
                        for i = 1, count do
                                local angle = (i / count) * math.pi * 2 + wave * 0.3
                                local offset = Vector3.new(
                                        math.cos(angle) * waveRadius + math.random(-2, 2),
                                        -3,
                                        math.sin(angle) * waveRadius + math.random(-2, 2)
                                )
                                local basePos = hrp.Position + offset

                                -- Sangre emergiendo
                                local blood = Instance.new("Part")
                                blood.Name = "SoulBlood"
                                blood.Size = Vector3.new(0.5, 0.5, 0.5)
                                blood.Shape = Enum.PartType.Ball
                                blood.Position = basePos
                                blood.BrickColor = BrickColor.new("Bright red")
                                blood.Material = Enum.Material.Neon
                                blood.Anchored = true
                                blood.CanCollide = false
                                blood.CastShadow = false
                                blood.Parent = Workspace

                                -- Emitter de sangre
                                local emit = Instance.new("ParticleEmitter")
                                emit.Color = ColorSequence.new{
                                        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 0, 0)),
                                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 0, 50)),
                                        ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 0, 0)),
                                }
                                emit.LightEmission = 0.9
                                emit.Size = NumberSequence.new{
                                        NumberSequenceKeypoint.new(0, 0.4),
                                        NumberSequenceKeypoint.new(1, 0),
                                }
                                emit.Speed = NumberRange.new(3, 8)
                                emit.Rate = 60
                                emit.Lifetime = NumberRange.new(0.5, 1)
                                emit.Parent = blood

                                local pl = Instance.new("PointLight")
                                pl.Color = Color3.fromRGB(200, 0, 0)
                                pl.Brightness = 3
                                pl.Range = 6
                                pl.Parent = blood

                                -- Emerge
                                TweenService:Create(blood, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                                        Position = basePos + Vector3.new(0, 4 + math.random() * 3, 0),
                                        Size = Vector3.new(0.8, 0.8, 0.8),
                                }):Play()

                                table.insert(allCrystals, blood)
                        end
                end)
        end

        -- Fase 2: Se convierten en cristales (cámara lenta épica)
        task.delay(2.2, function()
                RE_Effect:FireAllClients("Souls1000_CrystalForm", player)
                for i, part in ipairs(allCrystals) do
                        if part and part.Parent then
                        task.delay(i * 0.015, function()
                                if not part or not part.Parent then return end
                                part.Color = Color3.fromRGB(180, 0, 0)
                                TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
                                        Size = Vector3.new(0.6, 2.0, 0.6),
                                        Color = Color3.fromRGB(180, 0, 0),
                                }):Play()
                                task.delay(0.25, function()
                                        if part and part.Parent then
                                                part.Material = Enum.Material.Glass
                                                part.BrickColor = BrickColor.new("Crimson")
                                        end
                                end)
                        end)
                        end -- cierra if part and part.Parent
                end
        end)

        -- Fase 3: LLUVIA DE CRISTALES HACIA EL OPONENTE
        -- El aro se recoge justo antes del lanzamiento masivo
        task.delay(2.9, function()
                collapseBraceletRing(player, 0.5)
        end)
        task.delay(3.5, function()
                local targetHrp = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")

                RE_Effect:FireAllClients("Souls1000_Launch", player, target)

                -- Lanzar cada cristal
                for i, crystal in ipairs(allCrystals) do
                        if crystal and crystal.Parent then

                        task.delay(i * 0.02, function()
                                if not crystal or not crystal.Parent then return end
                                crystal.Anchored = false
                                crystal.CanCollide = true

                                local dest
                                if targetHrp then
                                        dest = targetHrp.Position + Vector3.new(
                                                math.random(-4, 4),
                                                math.random(-2, 3),
                                                math.random(-4, 4)
                                        )
                                else
                                        dest = hrp.Position + hrp.CFrame.LookVector * 30
                                end

                                -- Trayectoria parabólica épica
                                local bv = Instance.new("BodyVelocity")
                                local dir = (dest - crystal.Position).Unit
                                bv.Velocity = dir * 75 + Vector3.new(0, 15, 0)
                                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                                bv.Parent = crystal

                                local hitConn
                                hitConn = crystal.Touched:Connect(function(hit)
                                        local hp = Players:GetPlayerFromCharacter(hit.Parent)
                                        if hp and hp ~= player then
                                                hitConn:Disconnect()
                                                dealDamage(hp, 12)
                                                RE_Effect:FireAllClients("Crystal_Hit", crystal.Position)
                                        end
                                        task.delay(0.05, function()
                                                if crystal and crystal.Parent then
                                                        crystal:Destroy()
                                                end
                                        end)
                                end)

                                game:GetService("Debris"):AddItem(crystal, 5)
                        end)
                        end -- cierra if crystal and crystal.Parent
                end

                -- GOLPE FINAL MASIVO - oponente sale volando (controlado)
                if target then
                        task.delay(0.5, function()
                                local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                                if th then
                                        dealDamage(target, 100)
                                        -- Knockback épico pero controlado (no sale al espacio)
                                        local dir = (th.Position - hrp.Position).Unit
                                        applyKnockback(target, dir + Vector3.new(0, 0.4, 0), 75)
                                        RE_Effect:FireAllClients("Souls1000_FinalBlow", th.Position)
                                        RE_Stun:FireClient(target, 3)
                                end
                        end)
                end

                -- Resetear poder 1000 almas
                task.delay(4, function()
                        souls1000Unlocked[player] = nil
                end)

                -- El aro de la pulsera reaparece tras el lanzamiento masivo
                restoreBraceletRing(player, 0.4)
        end)
end)

-- ─── LIMPIAR AL SALIR ─────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
        cooldowns[player.UserId .. "_BloodBall"]      = nil
        cooldowns[player.UserId .. "_BloodCorpuscle"] = nil
        cooldowns[player.UserId .. "_BloodWhip"]      = nil
        cooldowns[player.UserId .. "_Souls1000"]      = nil
        stunned[player]       = nil
        whipActive[player]    = nil
        souls1000Unlocked[player] = nil
end)

print("[BloodPowers] ServerScript cargado correctamente ✓")

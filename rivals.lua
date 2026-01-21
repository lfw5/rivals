-- Wait for game to load FIRST
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Load GMM-UI-Lib Library AFTER game is loaded
local GmmUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/MermiXO/GMM-Ui-Lib/refs/heads/main/src.lua?t=" .. tick()))()

-- Services (with additional safety checks)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:WaitForChild("LocalPlayer", 10)
if not LocalPlayer then
    warn("LocalPlayer not found!")
    return
end

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Variables
local enabled = false
local espEnabled = false
local aimbotEnabled = false

-- Configuration ESP personnalisable
local espConfig = {
    -- Box
    boxEnabled = true,
    boxColor = Color3.fromRGB(0, 255, 0),
    boxThickness = 2,
    boxFilled = false,
    
    -- Health Bar
    healthBarEnabled = true,
    healthBarPosition = "Top", -- "Top", "Bottom", "Left", "Right"
    healthBarColorGradient = true, -- Si true: rouge->vert selon la vie
    healthBarColor = Color3.fromRGB(0, 255, 0),
    healthBarThickness = 5,
    healthBarOutline = true,
    
    -- Distance
    distanceEnabled = true,
    distanceColor = Color3.fromRGB(255, 255, 255),
    distanceSize = 14,
    
    -- Name
    nameEnabled = true,
    nameColor = Color3.fromRGB(255, 255, 255),
    nameSize = 14,
    
    -- Skeleton
    skeletonEnabled = false,
    skeletonColor = Color3.fromRGB(255, 255, 255),
    skeletonThickness = 2,
    
    -- Tracers (lignes depuis le bas de l'écran)
    tracersEnabled = false,
    tracersColor = Color3.fromRGB(255, 255, 255),
    tracersThickness = 2,
    tracersFrom = "Bottom", -- "Bottom", "Middle", "Top"
}

-- Configuration Aimbot
local aimbotConfig = {
    enabled = false,
    teamCheck = false,
    aliveCheck = true,
    wallCheck = false,
    
    -- FOV Settings
    fovEnabled = true,
    fovVisible = true,
    fovRadius = 90,
    fovColor = Color3.fromRGB(255, 255, 255),
    fovLockedColor = Color3.fromRGB(255, 150, 150),
    fovThickness = 2,
    
    -- Targeting
    lockPart = "Head", -- "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"
    
    -- Smoothing
    smoothEnabled = true,
    smoothness = 0.15, -- 0 = instant, plus grand = plus lent (secondes)
    sensitivity = 3.5, -- Pour mousemoverel mode
    
    -- Prediction
    prediction = false,
    predictionAmount = 0.12,
    
    -- Trigger
    triggerKey = Enum.KeyCode.Q, -- Q key (A on AZERTY)
    toggleMode = false, -- false = hold, true = toggle
}

-- Aimbot Variables
local aimbotLocked = nil
local aimbotRunning = false
local fovCircle = Drawing.new("Circle")
local fovCircleOutline = Drawing.new("Circle")

-- Setup FOV Circle
fovCircle.Visible = false
fovCircle.Filled = false
fovCircle.Transparency = 1
fovCircleOutline.Visible = false
fovCircleOutline.Filled = false
fovCircleOutline.Transparency = 1

-- Stockage des vitesses pour la prédiction
local playerVelocities = {}

-- ESP rectangles et barres de vie
local espData = {}

-- Liste des joueurs à ignorer
local ignoredPlayers = {
    ["azedbanh"] = true
}

-- Fonction pour calculer la couleur de la barre de vie
local function getHealthColor(healthPercent)
    if not espConfig.healthBarColorGradient then
        return espConfig.healthBarColor
    end
    -- Gradient de rouge (0%) à jaune (50%) à vert (100%)
    if healthPercent > 0.5 then
        local t = (healthPercent - 0.5) * 2
        return Color3.new(1 - t, 1, 0)
    else
        local t = healthPercent * 2
        return Color3.new(1, t, 0)
    end
end

-- Fonctions ESP
local function clearESP()
    for _, v in pairs(espData) do
        if v.box then v.box:Remove() end
        if v.hp then v.hp:Remove() end
        if v.hpOutline then v.hpOutline:Remove() end
        if v.name then v.name:Remove() end
        if v.distance then v.distance:Remove() end
        if v.tracer then v.tracer:Remove() end
        if v.skeleton then
            for _, line in pairs(v.skeleton) do
                line:Remove()
            end
        end
    end
    espData = {}
end

local function createESP(player)
    if espData[player] then return end
    espData[player] = {}
    
    -- Rectangle
    local box = Drawing.new("Square")
    box.Thickness = espConfig.boxThickness
    box.Color = espConfig.boxColor
    box.Filled = espConfig.boxFilled
    box.Visible = false
    espData[player].box = box
    
    -- Barre de vie outline
    local hpOutline = Drawing.new("Square")
    hpOutline.Thickness = 0
    hpOutline.Filled = true
    hpOutline.Color = Color3.fromRGB(0, 0, 0)
    hpOutline.Visible = false
    espData[player].hpOutline = hpOutline
    
    -- Barre de vie
    local hp = Drawing.new("Square")
    hp.Thickness = 0
    hp.Filled = true
    hp.Color = Color3.fromRGB(0, 255, 0)
    hp.Visible = false
    espData[player].hp = hp
    
    -- Nom du joueur
    local name = Drawing.new("Text")
    name.Text = player.Name
    name.Size = espConfig.nameSize
    name.Color = espConfig.nameColor
    name.Center = true
    name.Outline = true
    name.Visible = false
    espData[player].name = name
    
    -- Distance
    local distance = Drawing.new("Text")
    distance.Text = "0m"
    distance.Size = espConfig.distanceSize
    distance.Color = espConfig.distanceColor
    distance.Center = true
    distance.Outline = true
    distance.Visible = false
    espData[player].distance = distance
    
    -- Tracer
    local tracer = Drawing.new("Line")
    tracer.Thickness = espConfig.tracersThickness
    tracer.Color = espConfig.tracersColor
    tracer.Visible = false
    espData[player].tracer = tracer
    
    -- Skeleton (plusieurs lignes pour les membres)
    espData[player].skeleton = {}
    local limbs = {
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},
    }
    for i = 1, #limbs do
        local line = Drawing.new("Line")
        line.Thickness = espConfig.skeletonThickness
        line.Color = espConfig.skeletonColor
        line.Visible = false
        espData[player].skeleton[i] = {line = line, from = limbs[i][1], to = limbs[i][2]}
    end
end

local function updateESP()
    if not espEnabled then
        clearESP()
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not ignoredPlayers[player.Name] then
            if not espData[player] then
                createESP(player)
            end
            
            local char = player.Character
            local tbl = espData[player]
            
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") and char:FindFirstChildOfClass("Humanoid") then
                local hrp = char.HumanoidRootPart
                local head = char.Head
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                
                -- Calcul de la distance
                local dist = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) 
                    and (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude or 0
                
                -- Calcul du rectangle
                local size = hrp.Size
                local cf = hrp.CFrame
                local points = {
                    cf * Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
                    cf * Vector3.new(-size.X/2,  size.Y/2, -size.Z/2),
                    cf * Vector3.new( size.X/2,  size.Y/2, -size.Z/2),
                    cf * Vector3.new( size.X/2, -size.Y/2, -size.Z/2),
                    cf * Vector3.new(-size.X/2, -size.Y/2,  size.Z/2),
                    cf * Vector3.new(-size.X/2,  size.Y/2,  size.Z/2),
                    cf * Vector3.new( size.X/2,  size.Y/2,  size.Z/2),
                    cf * Vector3.new( size.X/2, -size.Y/2,  size.Z/2),
                }
                
                local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                for _, p in ipairs(points) do
                    local screen, onScreen = Camera:WorldToViewportPoint(p)
                    if onScreen then
                        minX = math.min(minX, screen.X)
                        minY = math.min(minY, screen.Y)
                        maxX = math.max(maxX, screen.X)
                        maxY = math.max(maxY, screen.Y)
                    end
                end
                
                if minX < maxX and minY < maxY and minX ~= math.huge then
                    -- Box
                    if espConfig.boxEnabled then
                        tbl.box.Position = Vector2.new(minX, minY)
                        tbl.box.Size = Vector2.new(maxX - minX, maxY - minY)
                        tbl.box.Color = espConfig.boxColor
                        tbl.box.Thickness = espConfig.boxThickness
                        tbl.box.Filled = espConfig.boxFilled
                        tbl.box.Visible = true
                    else
                        tbl.box.Visible = false
                    end
                    
                    -- Health Bar
                    if espConfig.healthBarEnabled then
                        local hpPerc = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                        local barW, barH
                        local barPos
                        local skipNormalBar = false

                        if espConfig.healthBarPosition == "Top" then
                            barW = math.max(40, (maxX - minX) * 0.8)
                            barH = espConfig.healthBarThickness
                            barPos = Vector2.new((minX + maxX) / 2 - barW / 2, minY - 10)
                        elseif espConfig.healthBarPosition == "Bottom" then
                            barW = math.max(40, (maxX - minX) * 0.8)
                            barH = espConfig.healthBarThickness
                            barPos = Vector2.new((minX + maxX) / 2 - barW / 2, maxY + 5)
                        elseif espConfig.healthBarPosition == "Left" then
                            barW = espConfig.healthBarThickness
                            barH = maxY - minY
                            barPos = Vector2.new(minX - 10, minY)
                            skipNormalBar = true
                            -- Pour la gauche, on inverse la logique
                            if espConfig.healthBarOutline then
                                tbl.hpOutline.Position = Vector2.new(barPos.X - 1, barPos.Y - 1)
                                tbl.hpOutline.Size = Vector2.new(barW + 2, barH + 2)
                                tbl.hpOutline.Visible = true
                            else
                                tbl.hpOutline.Visible = false
                            end
                            tbl.hp.Position = Vector2.new(barPos.X, barPos.Y + barH * (1 - hpPerc))
                            tbl.hp.Size = Vector2.new(barW, barH * hpPerc)
                            tbl.hp.Color = getHealthColor(hpPerc)
                            tbl.hp.Visible = true
                        elseif espConfig.healthBarPosition == "Right" then
                            barW = espConfig.healthBarThickness
                            barH = maxY - minY
                            barPos = Vector2.new(maxX + 5, minY)
                            skipNormalBar = true
                            -- Pour la droite, on inverse la logique
                            if espConfig.healthBarOutline then
                                tbl.hpOutline.Position = Vector2.new(barPos.X - 1, barPos.Y - 1)
                                tbl.hpOutline.Size = Vector2.new(barW + 2, barH + 2)
                                tbl.hpOutline.Visible = true
                            else
                                tbl.hpOutline.Visible = false
                            end
                            tbl.hp.Position = Vector2.new(barPos.X, barPos.Y + barH * (1 - hpPerc))
                            tbl.hp.Size = Vector2.new(barW, barH * hpPerc)
                            tbl.hp.Color = getHealthColor(hpPerc)
                            tbl.hp.Visible = true
                        end

                        -- Pour Top et Bottom (barres horizontales)
                        if not skipNormalBar then
                            if espConfig.healthBarOutline then
                                tbl.hpOutline.Position = Vector2.new(barPos.X - 1, barPos.Y - 1)
                                tbl.hpOutline.Size = Vector2.new(barW + 2, barH + 2)
                                tbl.hpOutline.Visible = true
                            else
                                tbl.hpOutline.Visible = false
                            end

                            tbl.hp.Position = barPos
                            tbl.hp.Size = Vector2.new(barW * hpPerc, barH)
                            tbl.hp.Color = getHealthColor(hpPerc)
                            tbl.hp.Visible = true
                        end
                    else
                        tbl.hp.Visible = false
                        tbl.hpOutline.Visible = false
                    end
                    
                    -- Name
                    if espConfig.nameEnabled then
                        tbl.name.Text = player.Name
                        tbl.name.Position = Vector2.new((minX + maxX) / 2, minY - 25)
                        tbl.name.Size = espConfig.nameSize
                        tbl.name.Color = espConfig.nameColor
                        tbl.name.Visible = true
                    else
                        tbl.name.Visible = false
                    end
                    
                    -- Distance
                    if espConfig.distanceEnabled then
                        tbl.distance.Text = string.format("%.0fm", dist)
                        tbl.distance.Position = Vector2.new((minX + maxX) / 2, maxY + 5)
                        tbl.distance.Size = espConfig.distanceSize
                        tbl.distance.Color = espConfig.distanceColor
                        tbl.distance.Visible = true
                    else
                        tbl.distance.Visible = false
                    end
                    
                    -- Tracers
                    if espConfig.tracersEnabled then
                        local fromY
                        if espConfig.tracersFrom == "Bottom" then
                            fromY = Camera.ViewportSize.Y
                        elseif espConfig.tracersFrom == "Middle" then
                            fromY = Camera.ViewportSize.Y / 2
                        else -- Top
                            fromY = 0
                        end
                        
                        tbl.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, fromY)
                        tbl.tracer.To = Vector2.new((minX + maxX) / 2, maxY)
                        tbl.tracer.Color = espConfig.tracersColor
                        tbl.tracer.Thickness = espConfig.tracersThickness
                        tbl.tracer.Visible = true
                    else
                        tbl.tracer.Visible = false
                    end
                    
                    -- Skeleton
                    if espConfig.skeletonEnabled then
                        for _, skelData in pairs(tbl.skeleton) do
                            local part1 = char:FindFirstChild(skelData.from)
                            local part2 = char:FindFirstChild(skelData.to)
                            
                            if part1 and part2 then
                                local pos1, onScreen1 = Camera:WorldToViewportPoint(part1.Position)
                                local pos2, onScreen2 = Camera:WorldToViewportPoint(part2.Position)
                                
                                if onScreen1 and onScreen2 then
                                    skelData.line.From = Vector2.new(pos1.X, pos1.Y)
                                    skelData.line.To = Vector2.new(pos2.X, pos2.Y)
                                    skelData.line.Color = espConfig.skeletonColor
                                    skelData.line.Thickness = espConfig.skeletonThickness
                                    skelData.line.Visible = true
                                else
                                    skelData.line.Visible = false
                                end
                            else
                                skelData.line.Visible = false
                            end
                        end
                    else
                        for _, skelData in pairs(tbl.skeleton) do
                            skelData.line.Visible = false
                        end
                    end
                else
                    tbl.box.Visible = false
                    tbl.hp.Visible = false
                    tbl.hpOutline.Visible = false
                    tbl.name.Visible = false
                    tbl.distance.Visible = false
                    tbl.tracer.Visible = false
                    for _, skelData in pairs(tbl.skeleton) do
                        skelData.line.Visible = false
                    end
                end
            else
                tbl.box.Visible = false
                tbl.hp.Visible = false
                tbl.hpOutline.Visible = false
                tbl.name.Visible = false
                tbl.distance.Visible = false
                tbl.tracer.Visible = false
                for _, skelData in pairs(tbl.skeleton) do
                    skelData.line.Visible = false
                end
            end
        elseif espData[player] then
            local tbl = espData[player]
            tbl.box.Visible = false
            tbl.hp.Visible = false
            tbl.hpOutline.Visible = false
            tbl.name.Visible = false
            tbl.distance.Visible = false
            tbl.tracer.Visible = false
            for _, skelData in pairs(tbl.skeleton) do
                skelData.line.Visible = false
            end
        end
    end
end

-- Fonctions Aimbot
local function cancelAimbotLock()
    aimbotLocked = nil
    fovCircle.Color = aimbotConfig.fovColor
end

local function getClosestPlayerAimbot()
    if not aimbotConfig.enabled then return nil end
    
    local closestPlayer = nil
    local shortestDistance = aimbotConfig.fovEnabled and aimbotConfig.fovRadius or math.huge
    
    local mousePos = UIS:GetMouseLocation()
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not ignoredPlayers[player.Name] then
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                local targetPart = char:FindFirstChild(aimbotConfig.lockPart)
                
                if humanoid and targetPart then
                    -- Team check
                    if aimbotConfig.teamCheck and player.Team == LocalPlayer.Team then
                        continue
                    end
                    
                    -- Alive check
                    if aimbotConfig.aliveCheck and humanoid.Health <= 0 then
                        continue
                    end
                    
                    -- Wall check
                    if aimbotConfig.wallCheck then
                        local ray = Ray.new(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position).Unit * 500)
                        local part, position = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, char})
                        if part then
                            continue
                        end
                    end
                    
                    -- Distance check
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        
                        if distance < shortestDistance then
                            closestPlayer = player
                            shortestDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function updateAimbot()
    if not aimbotConfig.enabled or not aimbotRunning then
        cancelAimbotLock()
        return
    end
    
    -- Get closest player
    local target = getClosestPlayerAimbot()
    
    if target then
        aimbotLocked = target
        fovCircle.Color = aimbotConfig.fovLockedColor
        
        local char = target.Character
        if char then
            local targetPart = char:FindFirstChild(aimbotConfig.lockPart)
            if targetPart then
                local targetPos = targetPart.Position
                
                -- Prediction
                if aimbotConfig.prediction then
                    local targetVelocity = targetPart.AssemblyVelocity or targetPart.Velocity or Vector3.new(0, 0, 0)
                    targetPos = targetPos + (targetVelocity * aimbotConfig.predictionAmount)
                end
                
                -- Smooth aiming
                if aimbotConfig.smoothEnabled and aimbotConfig.smoothness > 0 then
                    local tween = TweenService:Create(
                        Camera,
                        TweenInfo.new(aimbotConfig.smoothness, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                        {CFrame = CFrame.new(Camera.CFrame.Position, targetPos)}
                    )
                    tween:Play()
                else
                    -- Instant lock
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                end
            end
        end
    else
        cancelAimbotLock()
    end
end

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    if espData[player] then
        if espData[player].box then espData[player].box:Remove() end
        if espData[player].hp then espData[player].hp:Remove() end
        if espData[player].hpOutline then espData[player].hpOutline:Remove() end
        if espData[player].name then espData[player].name:Remove() end
        if espData[player].distance then espData[player].distance:Remove() end
        if espData[player].tracer then espData[player].tracer:Remove() end
        if espData[player].skeleton then
            for _, skelData in pairs(espData[player].skeleton) do
                skelData.line:Remove()
            end
        end
        espData[player] = nil
    end
    playerVelocities[player] = nil
    
    if aimbotLocked == player then
        cancelAimbotLock()
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            if espEnabled then
                createESP(player)
            end
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            if espEnabled then
                createESP(player)
            end
        end)
    end
end)

-- Input handling for aimbot
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == aimbotConfig.triggerKey or input.KeyCode == aimbotConfig.triggerKey then
        if aimbotConfig.toggleMode then
            aimbotRunning = not aimbotRunning
        else
            aimbotRunning = true
        end
    end
end)

UIS.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if not aimbotConfig.toggleMode then
        if input.UserInputType == aimbotConfig.triggerKey or input.KeyCode == aimbotConfig.triggerKey then
            aimbotRunning = false
            cancelAimbotLock()
        end
    end
end)

-- Main loop
RunService.RenderStepped:Connect(function(dt)
    -- ESP Update
    if espEnabled then
        updateESP()
    end
    
    -- Aimbot FOV Circle Update
    if aimbotConfig.fovEnabled and aimbotConfig.fovVisible then
        local mousePos = UIS:GetMouseLocation()
        
        fovCircle.Position = mousePos
        fovCircle.Radius = aimbotConfig.fovRadius
        fovCircle.Thickness = aimbotConfig.fovThickness
        fovCircle.Color = aimbotLocked and aimbotConfig.fovLockedColor or aimbotConfig.fovColor
        fovCircle.Visible = true
        
        fovCircleOutline.Position = mousePos
        fovCircleOutline.Radius = aimbotConfig.fovRadius
        fovCircleOutline.Thickness = aimbotConfig.fovThickness + 2
        fovCircleOutline.Color = Color3.fromRGB(0, 0, 0)
        fovCircleOutline.Visible = true
    else
        fovCircle.Visible = false
        fovCircleOutline.Visible = false
    end
    
    -- Aimbot Update
    if aimbotConfig.enabled then
        updateAimbot()
    end

    -- Triggerbot (seulement si enabled = true)
    if enabled then
        local target = Mouse.Target
        if target then
            local model = target:FindFirstAncestorOfClass("Model")
            if model then
                local humanoid = model:FindFirstChildOfClass("Humanoid")
                local hrp = model:FindFirstChild("HumanoidRootPart")
                local player = Players:GetPlayerFromCharacter(model)

                if humanoid and hrp and player ~= LocalPlayer and not ignoredPlayers[player.Name] then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        mouse1press()
                        return
                    end
                end
            end
        end
        mouse1release()
    end
end)

-- Create GMM-UI Window
local ui = GmmUI.new({ Title = "RIVALS CHEAT" })

-- Create Menus
local MainMenu = ui:NewMenu("MAIN")
local AimbotMenu = ui:NewMenu("AIMBOT")
local AimbotFOVMenu = ui:NewMenu("AIMBOT FOV")
local AimbotTargetMenu = ui:NewMenu("AIMBOT TARGET")
local ESPMenu = ui:NewMenu("ESP")
local ESPBoxMenu = ui:NewMenu("ESP BOX")
local ESPHealthMenu = ui:NewMenu("ESP HEALTH")
local ESPInfoMenu = ui:NewMenu("ESP INFO")
local ESPSkeletonMenu = ui:NewMenu("ESP SKELETON")
local SettingsMenu = ui:NewMenu("SETTINGS")

-- MAIN MENU
MainMenu:Toggle("Enable Triggerbot", "Toggle triggerbot on/off", enabled, function(state)
    enabled = state
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Triggerbot",
        Text = enabled and "Enabled" or "Disabled",
        Duration = 3
    })
end)

MainMenu:Button("Open Aimbot Menu", "Configure aimbot settings", function()
    ui:PushMenu(AimbotMenu)
end)

MainMenu:Button("Open ESP Menu", "Go to ESP options", function()
    ui:PushMenu(ESPMenu)
end)

MainMenu:Button("Open Settings", "Go to settings", function()
    ui:PushMenu(SettingsMenu)
end)

-- AIMBOT MENU
AimbotMenu:Toggle("Enable Aimbot", "Toggle aimbot on/off", aimbotConfig.enabled, function(state)
    aimbotConfig.enabled = state
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Aimbot",
        Text = state and "Enabled" or "Disabled",
        Duration = 3
    })
end)

AimbotMenu:Toggle("Team Check", "Don't target teammates", aimbotConfig.teamCheck, function(state)
    aimbotConfig.teamCheck = state
end)

AimbotMenu:Toggle("Wall Check", "Don't target through walls", aimbotConfig.wallCheck, function(state)
    aimbotConfig.wallCheck = state
end)

AimbotMenu:Toggle("Smooth Aiming", "Enable smooth camera movement", aimbotConfig.smoothEnabled, function(state)
    aimbotConfig.smoothEnabled = state
end)

AimbotMenu:Toggle("Toggle Mode", "Toggle on/off instead of hold", aimbotConfig.toggleMode, function(state)
    aimbotConfig.toggleMode = state
    aimbotRunning = false
    cancelAimbotLock()
end)

AimbotMenu:Button("FOV Settings", "Configure FOV circle", function()
    ui:PushMenu(AimbotFOVMenu)
end)

AimbotMenu:Button("Target Settings", "Configure targeting options", function()
    ui:PushMenu(AimbotTargetMenu)
end)

AimbotMenu:Button("Back", "Return to main menu", function()
    ui:Back()
end)

-- AIMBOT FOV MENU
AimbotFOVMenu:Toggle("Enable FOV", "Use FOV circle for targeting", aimbotConfig.fovEnabled, function(state)
    aimbotConfig.fovEnabled = state
end)

AimbotFOVMenu:Toggle("Show FOV Circle", "Display FOV circle", aimbotConfig.fovVisible, function(state)
    aimbotConfig.fovVisible = state
end)

AimbotFOVMenu:Button("FOV Size: " .. aimbotConfig.fovRadius, "Change FOV radius (click to cycle)", function()
    local sizes = {60, 90, 120, 150, 180, 200}
    local currentIndex = 1
    for i, size in ipairs(sizes) do
        if size == aimbotConfig.fovRadius then
            currentIndex = i
            break
        end
    end
    local nextIndex = (currentIndex % #sizes) + 1
    aimbotConfig.fovRadius = sizes[nextIndex]
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "FOV Radius",
        Text = "Changed to: " .. aimbotConfig.fovRadius,
        Duration = 2
    })
end)

AimbotFOVMenu:Button("Back", "Return to aimbot menu", function()
    ui:Back()
end)

-- AIMBOT TARGET MENU
AimbotTargetMenu:Button("Target Part: " .. aimbotConfig.lockPart, "Change body part to aim at", function()
    local parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
    local currentIndex = 1
    for i, part in ipairs(parts) do
        if part == aimbotConfig.lockPart then
            currentIndex = i
            break
        end
    end
    local nextIndex = (currentIndex % #parts) + 1
    aimbotConfig.lockPart = parts[nextIndex]
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Target Part",
        Text = "Changed to: " .. aimbotConfig.lockPart,
        Duration = 2
    })
end)

AimbotTargetMenu:Button("Smoothness: " .. string.format("%.2f", aimbotConfig.smoothness), "Adjust smooth speed", function()
    local speeds = {0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30}
    local currentIndex = 1
    for i, speed in ipairs(speeds) do
        if math.abs(speed - aimbotConfig.smoothness) < 0.01 then
            currentIndex = i
            break
        end
    end
    local nextIndex = (currentIndex % #speeds) + 1
    aimbotConfig.smoothness = speeds[nextIndex]
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Smoothness",
        Text = aimbotConfig.smoothness == 0 and "Instant Lock" or string.format("%.2fs", aimbotConfig.smoothness),
        Duration = 2
    })
end)

AimbotTargetMenu:Toggle("Prediction", "Predict target movement", aimbotConfig.prediction, function(state)
    aimbotConfig.prediction = state
end)

AimbotTargetMenu:Button("Back", "Return to aimbot menu", function()
    ui:Back()
end)

-- ESP MENU
ESPMenu:Toggle("Enable ESP", "Show player boxes and health bars", espEnabled, function(state)
    espEnabled = state
    if not espEnabled then
        clearESP()
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                createESP(player)
            end
        end
    end
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "ESP",
        Text = espEnabled and "Enabled" or "Disabled",
        Duration = 3
    })
end)

ESPMenu:Button("Box Settings", "Configure ESP boxes", function()
    ui:PushMenu(ESPBoxMenu)
end)

ESPMenu:Button("Health Bar Settings", "Configure health bars", function()
    ui:PushMenu(ESPHealthMenu)
end)

ESPMenu:Button("Info Settings", "Configure name/distance display", function()
    ui:PushMenu(ESPInfoMenu)
end)

ESPMenu:Button("Skeleton & Tracers", "Configure skeleton and tracers", function()
    ui:PushMenu(ESPSkeletonMenu)
end)

ESPMenu:Button("Back", "Return to main menu", function()
    ui:Back()
end)

-- ESP BOX MENU
ESPBoxMenu:Toggle("Show Box", "Enable/disable ESP boxes", espConfig.boxEnabled, function(state)
    espConfig.boxEnabled = state
end)

ESPBoxMenu:Toggle("Filled Box", "Fill the ESP box", espConfig.boxFilled, function(state)
    espConfig.boxFilled = state
end)

ESPBoxMenu:Button("Back", "Return to ESP menu", function()
    ui:Back()
end)

-- ESP HEALTH BAR MENU
ESPHealthMenu:Toggle("Show Health Bar", "Enable/disable health bars", espConfig.healthBarEnabled, function(state)
    espConfig.healthBarEnabled = state
end)

ESPHealthMenu:Toggle("Color Gradient", "Health bar color changes with HP", espConfig.healthBarColorGradient, function(state)
    espConfig.healthBarColorGradient = state
end)

ESPHealthMenu:Toggle("Show Outline", "Add black outline to health bar", espConfig.healthBarOutline, function(state)
    espConfig.healthBarOutline = state
end)

ESPHealthMenu:Button("Position: " .. espConfig.healthBarPosition, "Change health bar position", function()
    local positions = {"Top", "Bottom", "Left", "Right"}
    local currentIndex = 1
    for i, pos in ipairs(positions) do
        if pos == espConfig.healthBarPosition then
            currentIndex = i
            break
        end
    end
    local nextIndex = (currentIndex % #positions) + 1
    espConfig.healthBarPosition = positions[nextIndex]
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Health Bar Position",
        Text = "Changed to: " .. espConfig.healthBarPosition,
        Duration = 2
    })
end)

ESPHealthMenu:Button("Back", "Return to ESP menu", function()
    ui:Back()
end)

-- ESP INFO MENU
ESPInfoMenu:Toggle("Show Name", "Display player names", espConfig.nameEnabled, function(state)
    espConfig.nameEnabled = state
end)

ESPInfoMenu:Toggle("Show Distance", "Display distance to players", espConfig.distanceEnabled, function(state)
    espConfig.distanceEnabled = state
end)

ESPInfoMenu:Button("Back", "Return to ESP menu", function()
    ui:Back()
end)

-- ESP SKELETON & TRACERS MENU
ESPSkeletonMenu:Toggle("Show Skeleton", "Display player skeleton", espConfig.skeletonEnabled, function(state)
    espConfig.skeletonEnabled = state
end)

ESPSkeletonMenu:Toggle("Show Tracers", "Display lines to players", espConfig.tracersEnabled, function(state)
    espConfig.tracersEnabled = state
end)

ESPSkeletonMenu:Button("Tracer From: " .. espConfig.tracersFrom, "Change tracer origin point", function()
    local positions = {"Bottom", "Middle", "Top"}
    local currentIndex = 1
    for i, pos in ipairs(positions) do
        if pos == espConfig.tracersFrom then
            currentIndex = i
            break
        end
    end
    local nextIndex = (currentIndex % #positions) + 1
    espConfig.tracersFrom = positions[nextIndex]
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Tracer Position",
        Text = "Changed to: " .. espConfig.tracersFrom,
        Duration = 2
    })
end)

ESPSkeletonMenu:Button("Back", "Return to ESP menu", function()
    ui:Back()
end)

-- SETTINGS MENU
SettingsMenu:Button("Clear Ignored Players", "Reset ignore list (keeps azedbanh)", function()
    ignoredPlayers = {["azedbanh"] = true}
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Ignore List",
        Text = "Cleared all ignored players",
        Duration = 3
    })
end)

SettingsMenu:Button("Back", "Return to main menu", function()
    ui:Back()
end)

-- Show the menu
ui:PushMenu(MainMenu)

-- Welcome notification
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Rivals Cheat Loaded",
    Text = "Press F4 or Insert to open menu!",
    Duration = 8
})

--[[
    ╔════════════════════════════════════════════════════════════╗
    ║       PROJECT: SYSTEM: AWAKENING (V1.9.2 TOTAL)            ║
    ║       STUDIO: SHADOW PROTOCOL LABS                         ║
    ║------------------------------------------------------------║
    ║       LEAD DEVELOPER: ENZO CAVALCANTI                      ║
    ║       MOD: CONTROLES SEPARADOS PARA VIDA E DISTÂNCIA       ║
    ╚════════════════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

--// [CONFIGURAÇÃO GLOBAL]
getgenv().SystemConfig = {
    MiraAtiva = false,
    FovRadius = 500,
    Smoothness = 0.35,
    TeamCheck = true,
    HighlightEnabled = false,
    DotEnabled = false,
    MicroHpEnabled = false,   -- [ADICIONADO]: Controle individual da vida nos pés
    MicroDistEnabled = false, -- [ADICIONADO]: Controle individual da distância nos pés
    FullBright = false,
    NoShadows = false,
    ClarezaMod = false,
    ShowFPS = false,
    ShowPlayers = false
}

local OriginalSettings = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
    Exposure = Lighting.ExposureCompensation
}

--// [SISTEMA DE INTERFACE: TAGS E BOTÃO ELITE]
local ScreenGui = Instance.new("ScreenGui", CoreGui)
local TagContainer = Instance.new("Frame", ScreenGui)
TagContainer.Size = UDim2.new(0, 60, 0, 50) 
TagContainer.Position = UDim2.new(0, 5, 0, 45) 
TagContainer.BackgroundTransparency = 1
local UIList = Instance.new("UIListLayout", TagContainer)
UIList.Padding = UDim.new(0, 3)

local function CreateTag(color)
    local f = Instance.new("Frame", TagContainer)
    f.Size = UDim2.new(0, 70, 0, 16) 
    f.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    f.BackgroundTransparency = 0.5
    f.Visible = false
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.TextColor3 = color
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    return f, l
end

local fpsF, fpsL = CreateTag(Color3.fromRGB(0, 255, 120))
local countF, countL = CreateTag(Color3.fromRGB(255, 255, 0))

-- Botão Flutuante Elite
local FloatingBtn = Instance.new("TextButton", ScreenGui)
FloatingBtn.Visible = false 
FloatingBtn.Size = UDim2.new(0, 65, 0, 35)
FloatingBtn.Position = UDim2.new(0.1, 0, 0.5, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 23, 35)
FloatingBtn.Text = "OFF"
FloatingBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.TextSize = 14
FloatingBtn.Draggable = true
FloatingBtn.Active = true
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", FloatingBtn)
Stroke.Thickness = 2
Stroke.Color = Color3.fromRGB(40, 50, 70)

local function UpdateBtnVisual(active)
    if active then
        TweenService:Create(FloatingBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 35, 60)}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(57, 172, 231)}):Play()
        FloatingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        FloatingBtn.Text = "ON"
    else
        TweenService:Create(FloatingBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(15, 23, 35)}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(40, 50, 70)}):Play()
        FloatingBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        FloatingBtn.Text = "OFF"
    end
end

FloatingBtn.MouseButton1Click:Connect(function()
    getgenv().SystemConfig.MiraAtiva = not getgenv().SystemConfig.MiraAtiva
    UpdateBtnVisual(getgenv().SystemConfig.MiraAtiva)
end)

--// [FUNÇÃO: BUSCA DE ALVO (Aimbot)]
local function getTarget()
    local closest, shortest = nil, getgenv().SystemConfig.FovRadius
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            
            if head and hum and hum.Health > 0 then
                local isTeam = (p.Team == Player.Team and Player.Team ~= nil)
                if not (isTeam and getgenv().SystemConfig.TeamCheck) then
                    local pos, vis = Camera:WorldToViewportPoint(head.Position)
                    if vis and pos.Z > 0 then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist < shortest then
                            shortest = dist
                            closest = head
                        end
                    end
                end
            end
        end
    end
    return closest
end

--// [FUNÇÃO: WALL CHECK]
local function IsBehindWall(targetPart)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {Player.Character, targetPart.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position), rayParams)
    return result ~= nil
end

--// [FUNÇÃO INTEGRADA DO MICRO-HUD]
local function CreateMicroDisplay(char)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not root then return nil end
    
    local billboard = root:FindFirstChild("Aguia_MicroHUD")
    if not billboard then
        billboard = Instance.new("BillboardGui", root)
        billboard.Name = "Aguia_MicroHUD"
        billboard.Size = UDim2.new(0, 35, 0, 12)
        billboard.AlwaysOnTop = true
        billboard.ExtentsOffset = Vector3.new(0, -3.7, 0)
        
        local bgBar = Instance.new("Frame", billboard)
        bgBar.Name = "BackgroundBar"
        bgBar.Size = UDim2.new(1, 0, 0, 2)
        bgBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        bgBar.BorderSizePixel = 0
        
        local mainBar = Instance.new("Frame", bgBar)
        mainBar.Name = "MainBar"
        mainBar.Size = UDim2.new(1, 0, 1, 0)
        mainBar.BorderSizePixel = 0
        
        local label = Instance.new("TextLabel", billboard)
        label.Name = "DistLabel"
        label.Size = UDim2.new(1, 0, 0, 8)
        label.Position = UDim2.new(0, 0, 0, 3)
        label.BackgroundTransparency = 1
        label.TextSize = 8
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.4
    end
    return billboard
end

--// [INTERFACE RAYFIELD]
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "👑 SYSTEM: AWAKENING | v1.9.2",
   LoadingTitle = "SHADOW PROTOCOL LABS",
   LoadingSubtitle = "By: Enzo Cavalcanti",
   ConfigurationSaving = { Enabled = false },
   Theme = "DarkBlue" 
})

local CombatTab = Window:CreateTab("🔫 Combate", 10734950020)
local VisualTab = Window:CreateTab("👁️ Visual", 10734951477)
local LightTab = Window:CreateTab("💡 Iluminação", 10734951477)
local StatusTab = Window:CreateTab("📊 Monitor", 4483362458)

CombatTab:CreateToggle({ 
    Name = "Ativar Mira", 
    CurrentValue = false, 
    Callback = function(v) 
        getgenv().SystemConfig.MiraAtiva = v 
        FloatingBtn.Visible = v 
        UpdateBtnVisual(v)
    end 
})
CombatTab:CreateSlider({ Name = "Suavidade", Range = {0.1, 1}, Increment = 0.05, CurrentValue = 0.35, Callback = function(v) getgenv().SystemConfig.Smoothness = v end })

-- [BOTÕES SEPARADOS NA ABA VISUAL]
VisualTab:CreateToggle({ Name = "Ativar Raio-X", CurrentValue = false, Callback = function(v) getgenv().SystemConfig.HighlightEnabled = v end })
VisualTab:CreateToggle({ Name = "Ponto na Cabeça", CurrentValue = false, Callback = function(v) getgenv().SystemConfig.DotEnabled = v end })
VisualTab:CreateToggle({ Name = "Micro-HUD: Vida nos Pés", CurrentValue = false, Callback = function(v) getgenv().SystemConfig.MicroHpEnabled = v end }) -- Botão Vida
VisualTab:CreateToggle({ Name = "Micro-HUD: Distância nos Pés", CurrentValue = false, Callback = function(v) getgenv().SystemConfig.MicroDistEnabled = v end }) -- Botão Distância

LightTab:CreateToggle({ 
    Name = "FullBright", 
    CurrentValue = false, 
    Callback = function(v) 
        getgenv().SystemConfig.FullBright = v 
        if not v then
            Lighting.Ambient = OriginalSettings.Ambient
            Lighting.Brightness = OriginalSettings.Brightness
            Lighting.ClockTime = OriginalSettings.ClockTime
            Lighting.FogEnd = OriginalSettings.FogEnd
            Lighting.OutdoorAmbient = OriginalSettings.OutdoorAmbient
        end
    end 
})
LightTab:CreateToggle({ Name = "Clareza Técnica", CurrentValue = false, Callback = function(v) getgenv().SystemConfig.ClarezaMod = v end })
LightTab:CreateToggle({ Name = "Remover Sombras", CurrentValue = false, Callback = function(v) Lighting.GlobalShadows = not v end })

StatusTab:CreateToggle({ Name = "Mostrar FPS", CurrentValue = false, Callback = function(v) getgenv().SystemConfig.ShowFPS = v fpsF.Visible = v end })
StatusTab:CreateToggle({ Name = "Contador Players", CurrentValue = false, Callback = function(v) getgenv().SystemConfig.ShowPlayers = v countF.Visible = v end })

--// [LOOP CORE]
RunService.RenderStepped:Connect(function(dt)
    if getgenv().SystemConfig.ShowFPS then fpsL.Text = "FPS: " .. math.floor(1/dt) end
    if getgenv().SystemConfig.ShowPlayers then countL.Text = "P: " .. #Players:GetPlayers() end

    if getgenv().SystemConfig.MiraAtiva then
        local target = getTarget()
        if target then
            local goal = CFrame.new(Camera.CFrame.Position, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, getgenv().SystemConfig.Smoothness * math.clamp(60 * dt, 0, 1))
        end
    end

    if getgenv().SystemConfig.FullBright then
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.ClockTime = 14
    end
    if getgenv().SystemConfig.ClarezaMod then
        Lighting.Brightness = 3
        Lighting.ExposureCompensation = 0.5
    else
        if not getgenv().SystemConfig.FullBright then
            Lighting.Brightness = OriginalSettings.Brightness
            Lighting.ExposureCompensation = OriginalSettings.Exposure
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local char = p.Character
            local head = char:FindFirstChild("Head")
            
            -- [EXECUÇÃO DO SEU VISUAL ORIGINAL: INTACTO]
            if head then
                local isTeam = (p.Team == Player.Team and Player.Team ~= nil)
                local statusColor = isTeam and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
                
                local hl = char:FindFirstChild("System_HL") or Instance.new("Highlight", char)
                hl.Name = "System_HL"
                hl.Enabled = getgenv().SystemConfig.HighlightEnabled
                hl.FillColor = statusColor
                hl.OutlineColor = statusColor
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                
                local behind = IsBehindWall(head)
                local dotColor = isTeam and Color3.fromRGB(0, 255, 0) or (behind and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(255, 0, 0))

                local dot = head:FindFirstChild("System_Dot")
                if not dot then
                    local bill = Instance.new("BillboardGui", head)
                    bill.Name = "System_Dot"
                    bill.Size = UDim2.new(0, 10, 0, 10)
                    bill.AlwaysOnTop = true
                    bill.ExtentsOffset = Vector3.new(0, 1.5, 0)
                    local f = Instance.new("Frame", bill)
                    f.Size = UDim2.new(1,0,1,0)
                    Instance.new("UICorner", f).CornerRadius = UDim.new(1,0)
                    dot = bill
                end
                dot.Enabled = getgenv().SystemConfig.DotEnabled
                dot.Frame.BackgroundColor3 = dotColor
            end

            -- [EXECUÇÃO INDEPENDENTE: MICRO-HUD CONTROLADO POR BOTÕES SEPARADOS]
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and root then
                local hud = root:FindFirstChild("Aguia_MicroHUD")
                
                -- Se qualquer uma das duas opções estiver ativada e o player estiver vivo
                if (getgenv().SystemConfig.MicroHpEnabled or getgenv().SystemConfig.MicroDistEnabled) and hum.Health > 0 then
                    local currentHud = CreateMicroDisplay(char)
                    if currentHud then
                        local isTeam = (p.Team == Player.Team and Player.Team ~= nil)
                        local teamColor = isTeam and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 50, 50)
                        
                        -- Controle da Barrinha de Vida
                        if getgenv().SystemConfig.MicroHpEnabled then
                            local healthRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            currentHud.BackgroundBar.MainBar.Size = UDim2.new(healthRatio, 0, 1, 0)
                            currentHud.BackgroundBar.MainBar.BackgroundColor3 = teamColor
                            currentHud.BackgroundBar.Visible = true
                        else
                            currentHud.BackgroundBar.Visible = false
                        end
                        
                        -- Controle do Texto de Distância
                        if getgenv().SystemConfig.MicroDistEnabled then
                            local distance = math.floor(Player:DistanceFromCharacter(root.Position))
                            currentHud.DistLabel.Text = string.format("%dm", distance)
                            currentHud.DistLabel.TextColor3 = teamColor
                            currentHud.DistLabel.Visible = true
                        else
                            currentHud.DistLabel.Visible = false
                        end
                        
                        currentHud.Enabled = true
                    end
                else
                    -- Se ambos os botões forem desligados ou o player morrer, apaga o HUD
                    if hud then
                        hud.Enabled = false
                    end
                end
            end
            
        end
    end
end)

Rayfield:Notify({Title = "SHADOW PROTOCOL LABS", Content = "Otimização Concluída! Pronto para dominar, meu rei!", Duration = 5})

--// Main Libarys \\--
-- Загружаем основную библиотеку (Puppyware Reborn base KinX)
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/imagoodpersond/puppyware/main/lib"))()
local NotifyLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/imagoodpersond/puppyware/main/notify"))()
local OriginalNotify = NotifyLibrary.Notify -- Сохраняем оригинальную функцию Notify

--// Services \\--
-- Централизованное получение служб
local Services = {
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
    Lighting = game:GetService("Lighting"),
    Workspace = game:GetService("Workspace"),
    TeleportService = game:GetService("TeleportService") -- Добавляем TeleportService
}

local LocalPlayer = Services.Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local CurrentCamera = Services.Workspace.CurrentCamera

-- Стандартные/дефолтные значения для сброса
local defaultSettings = {
    WalkSpeed = 16,
    Gravity = 196,
    FlySpeed = 50,
    FOV = 70,
    ToggleGUIKey = Enum.KeyCode.RightShift, -- Default for Puppyware
    FlyToggleKey = Enum.KeyCode.H,
    FPSCap = 60, -- Стандартный FPS Roblox
    ThemeAccent = Color3.fromRGB(244, 95, 115), -- Стандартный акцент KinX UI
    NotificationSoundId = "rbxassetid://0" -- ID звука по умолчанию (0 - без звука)
}

-- Переменная для хранения текущего ID звука уведомлений
local currentNotificationSoundId = defaultSettings.NotificationSoundId
local notificationSound = Instance.new("Sound")
-- Размещаем Sound в PlayerGui, чтобы он был доступен и корректно воспроизводился для локального игрока
notificationSound.Parent = Services.Players.LocalPlayer.PlayerGui 

-- Переопределяем функцию Notify, чтобы добавить воспроизведение звука
local function Notify(options)
    OriginalNotify(options) -- Вызываем оригинальную функцию для отображения уведомления

    if currentNotificationSoundId ~= "rbxassetid://0" then
        notificationSound.SoundId = currentNotificationSoundId
        notificationSound:Play()
    end
end
-- Теперь, когда вы используете Notify, он будет воспроизводить звук

-- === НАЧАЛО БЛОКА КОДА ДЛЯ ФУНКЦИИ ПОЛЕТА И NOCLIP (из tutor.lua) ===
local Character = nil -- Будет обновляться при спавне
local Humanoid = nil -- Будет обновляться при спавне

local flying = false
local noclipActive = false -- Переменная для состояния NoClip

local flySpeed = defaultSettings.FlySpeed -- Скорость полета по умолчанию
local originalGravity = Services.Workspace.Gravity -- Сохраняем исходную гравитацию
local originalWalkSpeed = defaultSettings.WalkSpeed -- Стандартная скорость ходьбы Roblox
local originalJumpPower = 50 -- Стандартная сила прыжка Roblox (не изменяем)
local originalFOV = defaultSettings.FOV -- Стандартное значение FOV

local flightMovementConnection = nil -- Соединение для цикла полета
local bodyGyro = nil
local bodyVelocity = nil

local noclipCollisionConnection = nil -- Соединение для цикла NoClip коллизий

-- Функция для получения нужной части тела для BodyMovers (для полета)
local function getPrimaryPart()
    if not Character then return nil end
    if Character:FindFirstChild("HumanoidRootPart") then
        return Character:FindFirstChild("HumanoidRootPart")
    elseif Humanoid and Humanoid.RigType == Enum.HumanoidRigType.R6 then
        return Character:FindFirstChild("Torso")
    end
    return nil
end

-- ======================================================
-- ЛОГИКА ПОЛЕТА
-- ======================================================

local function disableFlight()
    if not flying then return end

    flying = false

    if flightMovementConnection then
        flightMovementConnection:Disconnect()
        flightMovementConnection = nil
    end

    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end

    if Humanoid then
        Humanoid.WalkSpeed = originalWalkSpeed
        Humanoid.JumpPower = originalJumpPower
        Humanoid.PlatformStand = false
        Humanoid.AutoRotate = true
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
        Humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end

    if not noclipActive then
        Services.Workspace.Gravity = originalGravity
    end

    if Character and Character:FindFirstChild("Animate") then
        Character.Animate.Disabled = false
    end

    print("Полет деактивирован!")
end

local function enableFlight()
    if flying then return end
    if not Character or not Humanoid or Humanoid.Health <= 0 then return end

    if noclipActive then disableNoClip() end

    flying = true

    Services.Workspace.Gravity = 0

    Humanoid.WalkSpeed = 0
    Humanoid.JumpPower = 0
    Humanoid.Sit = false
    Humanoid.PlatformStand = true
    Humanoid.AutoRotate = false

    if Character and Character:FindFirstChild("Animate") then
        Character.Animate.Disabled = true
        for _, track in ipairs(Humanoid:GetPlayingAnimationTracks()) do
            track:Stop()
        end
    end

    local primaryPart = getPrimaryPart()
    if not primaryPart then
        warn("PrimaryPart for flight not found! Disabling flight.")
        disableFlight()
        return
    end

    bodyGyro = Instance.new("BodyGyro", primaryPart)
    bodyGyro.P = 1000000
    bodyGyro.D = 3333 -- Уменьшено значение D для уменьшения плавности поворотов (быстрее)
    bodyGyro.maxTorque = Vector3.new(math.huge, math.huge, math.huge)

    bodyVelocity = Instance.new("BodyVelocity", primaryPart)
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)

    print("Полет активирован!")

    flightMovementConnection = Services.RunService.RenderStepped:Connect(function()
        if not flying or not Character or not Humanoid or Humanoid.Health <= 0 or not primaryPart.Parent then
            disableFlight()
            return
        end

        local currentCamera = Services.Workspace.CurrentCamera
        local cameraLookVector = currentCamera.CFrame.LookVector
        local cameraRightVector = currentCamera.CFrame.RightVector
        local cameraUpVector = currentCamera.CFrame.UpVector

        local moveDirection = Vector3.new(0, 0, 0)

        if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection += cameraLookVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection -= cameraLookVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection -= cameraRightVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection += cameraRightVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection += cameraUpVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or Services.UserInputService:IsKeyDown(Enum.KeyCode.C) then
            moveDirection -= cameraUpVector
        end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end

        bodyVelocity.Velocity = moveDirection * flySpeed
        bodyGyro.CFrame = CFrame.new(primaryPart.Position, primaryPart.Position + cameraLookVector)
    end)
end

local function toggleFlight()
    if flying then
        disableFlight()
    else
        enableFlight()
    end
end

-- ======================================================
-- ЛОГИКА NOCLIP
-- ======================================================

local function disableNoClip()
    if not noclipActive then return end

    noclipActive = false

    if noclipCollisionConnection then
        noclipCollisionConnection:Disconnect()
        noclipCollisionConnection = nil
    end

    if Character then
        for _,v in pairs(Character:GetDescendants()) do
            if v:IsA('BasePart') and not v.CanCollide then
                v.CanCollide = true
            end
        end
    end

    if Humanoid and not flying then
        Humanoid.WalkSpeed = originalWalkSpeed
        Humanoid.JumpPower = originalJumpPower
        Humanoid.PlatformStand = false
        Humanoid.AutoRotate = true
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
        Humanoid:ChangeState(Enum.HumanoidStateType.Running)
        if Character and Character:FindFirstChild("Animate") then
            Character.Animate.Disabled = false
        end
    end

    print("NoClip деактивирован!")
end

local function enableNoClip()
    if noclipActive then return end

    if not Character or not Humanoid or Humanoid.Health <= 0 then return end

    if flying then disableFlight() end

    noclipActive = true

    if Character and Character:FindFirstChild("Animate") then
        Character.Animate.Disabled = true
        for _, track in ipairs(Humanoid:GetPlayingAnimationTracks()) do
            track:Stop()
        end
    end

    print("NoClip активирован!")

    noclipCollisionConnection = Services.RunService.Stepped:Connect(function()
        if not noclipActive or not Character or not Humanoid or Humanoid.Health <= 0 then
            disableNoClip()
            return
        end

        for _,v in pairs(Character:GetDescendants()) do
            if v:IsA('BasePart') and v.CanCollide then
                v.CanCollide = false
            end
        end
    end)
end

-- ======================================================
-- ОБРАБОТЧИКИ СОБЫТИЙ (Остаются в силе для обоих режимов)
-- ======================================================

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = newCharacter:WaitForChild("Humanoid")
    disableFlight()
    disableNoClip()
    Humanoid.Died:Connect(function()
        disableFlight()
        disableNoClip()
    end)
end)

Character = LocalPlayer.Character
if Character then
    Humanoid = Character:WaitForChild("Humanoid")
    Humanoid.Died:Connect(function()
        disableFlight()
        disableNoClip()
    end)
end
-- === КОНЕЦ БЛОКА КОДА ДЛЯ ФУНКЦИИ ПОЛЕТА И NOCLIP ===

-- Инициализация окна GUI
local Window = library:new({name = "ZalupaHub", accent = defaultSettings.ThemeAccent, textsize = 13})

-- === Вкладка "InternetT" ===
local InternetT_Tab = Window:page({name = "InternetT"})
local scriptsSection = InternetT_Tab:section({name = "Scripts", side = "left", size = 320})

scriptsSection:button({name = "Execute Infinity Yields", callback = function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
    Notify({Title = "ZalupaHub", Description = "Infinity Yields executed!", Duration = 3})
end})

scriptsSection:button({name = "Execute Orca Hub", callback = function()
    loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/richie0866/orca/master/public/latest.lua"))()
    Notify({Title = "ZalupaHub", Description = "Orca Hub executed!", Duration = 3})
end})

scriptsSection:button({name = "Execute Dex Explorer", callback = function()
    loadstring(game:HttpGet("https://cdn.wearedevs.net/scripts/Dex%20Explorer.txt"))()
    Notify({Title = "ZalupaHub", Description = "Dex Explorer executed!", Duration = 3})
end})

scriptsSection:button({name = "Execute Universal AimBot", callback = function()
    loadstring(game:HttpGet("https://pastebin.com/raw/Y7Fv6BYd"))()
    Notify({Title = "ZalupaHub", Description = "Universal AimBot executed!", Duration = 3})
end})

-- === Вкладка "DefaultT" ===
local DefaultT_Tab = Window:page({name = "DefaultT"})
local toolsSection = DefaultT_Tab:section({name = "Tools", side = "left", size = 320})

toolsSection:slider({name = "WalkSpeed", def = 16, max = 1000, min = 0, rounding = true, callback = function(Value)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = Value
end})

toolsSection:slider({name = "Gravity", def = 196, max = 500, min = 0, rounding = true, callback = function(Value)
    Services.Workspace.Gravity = Value
end})

-- Добавляем кнопки для сброса на значения по умолчанию
toolsSection:button({name = "Set Default Gravity", callback = function()
    Services.Workspace.Gravity = defaultSettings.Gravity
    Notify({Title = "Default Settings", Description = "Gravity set to "..defaultSettings.Gravity.."!", Duration = 2})
end})

toolsSection:button({name = "Set Default Speed", callback = function()
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = defaultSettings.WalkSpeed
    Notify({Title = "Default Settings", Description = "Speed set to "..defaultSettings.WalkSpeed.."!", Duration = 2})
end})

-- TP Tool (оставлен, как был)
toolsSection:button({name = "TP Tool", callback = function()
    local mouse = game.Players.LocalPlayer:GetMouse()
    local tool = Instance.new("Tool")
    tool.RequiresHandle = false
    tool.Name = "TP TOOL"
    tool.Activated:connect(function()
    local pos = mouse.Hit+Vector3.new(0,2.5,0)
    pos = CFrame.new(pos.X,pos.Y,pos.Z)
    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = pos
    end)
    tool.Parent = game.Players.LocalPlayer.Backpack
    Notify({Title = "TP Tool", Description = "Tool equipped!", Duration = 2})
end})

-- Добавляем бинд на полет
local flyToggleKey = defaultSettings.FlyToggleKey
local flyKeybind = toolsSection:keybind({
    name = "Toggle Fly", 
    def = flyToggleKey, 
    callback = function(newKey)
        flyToggleKey = newKey
        Notify({Title = "Flight", Description = "Flight Key changed to: " .. newKey.Name, Duration = 3})
    end
})

-- *** Отдельный слушатель для активации полета по горячей клавише ***
Services.UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == flyToggleKey then
        toggleFlight()
        Notify({Title = "Flight", Description = "Flight Toggled!", Duration = 2})
    end
end)

-- Слайдер для скорости полета
toolsSection:slider({name = "Fly Speed", def = flySpeed, max = 200, min = 10, rounding = true, callback = function(Value)
    flySpeed = Value
end})

-- Кнопка для сброса скорости полета
toolsSection:button({name = "Set Default Fly Speed", callback = function()
    flySpeed = defaultSettings.FlySpeed
    Notify({Title = "Flight", Description = "Fly Speed set to "..defaultSettings.FlySpeed.."!", Duration = 2})
end})

-- Добавляем кнопку для NoClip (по желанию)
toolsSection:button({name = "Toggle NoClip", callback = function()
    enableNoClip()
    Notify({Title = "NoClip", Description = "NoClip Enabled!", Duration = 2})
end})

-- === Секция для FOV (справа) ===
local cameraSection = DefaultT_Tab:section({name = "Camera Settings", side = "right", size = 320})

cameraSection:slider({name = "Field of View (FOV)", def = defaultSettings.FOV, max = 120, min = 30, rounding = true, callback = function(Value)
    Services.Workspace.CurrentCamera.FieldOfView = Value
end})

cameraSection:button({name = "Set Standard FOV", callback = function()
    Services.Workspace.CurrentCamera.FieldOfView = defaultSettings.FOV
    Notify({Title = "Camera Settings", Description = "FOV set to "..defaultSettings.FOV.."!", Duration = 2})
end})

-- === Секция для списка игроков (под Camera Settings) ===
local playerListSection = DefaultT_Tab:section({name = "Player List", side = "right", size = 180})

local selectedPlayerName = nil -- Переменная для хранения имени выбранного игрока
local playerDropdownInstance = nil -- Ссылка на экземпляр dropdown

-- Функция для получения списка имен игроков
local function getPlayerNamesForDropdown()
    local names = {}
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    if #names == 0 then
        table.insert(names, "No Players")
    end
    return names
end

-- Функция для обновления dropdown (пересоздания)
local function updatePlayerDropdown()
    -- Удаляем старые элементы в секции, если они есть (очистка UI)
    -- Предполагаем, что section:Clear() очищает все дочерние элементы.
    -- Если нет, это место, где могут быть проблемы с накоплением элементов.
    if playerListSection.Clear then -- Проверяем, есть ли метод Clear
        playerListSection:Clear()
    else
        -- Если Clear() нет, это будет проблематично с Puppyware.
        -- Нам нужно как-то удалить старый dropdown и кнопку.
        -- В данном случае, мы будем полагаться на то, что новый UI просто заменит старый.
        -- Это может привести к "наслоению" элементов GUI, если библиотека не умеет их заменять.
    end

    local playerNames = getPlayerNamesForDropdown()
    playerDropdownInstance = playerListSection:dropdown({
        name = "Select Player",
        def = playerNames[1] or "No Players",
        options = playerNames,
        callback = function(playerName)
            selectedPlayerName = playerName
            Notify({Title = "Player Selection", Description = "Выбран игрок: " .. playerName, Duration = 2})
        end
    })

    -- Устанавливаем выбранного игрока после создания dropdown
    if #playerNames > 0 and playerNames[1] ~= "No Players" then
        selectedPlayerName = playerNames[1]
    else
        selectedPlayerName = nil
    end

    -- Кнопка телепортации к выбранному игроку
    playerListSection:button({
        name = "Teleport to Selected Player",
        callback = function()
            if selectedPlayerName and selectedPlayerName ~= "No Players" then
                local targetPlayer = Services.Players:FindFirstChild(selectedPlayerName)
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 5, 0)
                    Notify({Title = "Teleport", Description = "Телепортирован к " .. selectedPlayerName, Duration = 2})
                else
                    Notify({Title = "Teleport Error", Description = "Не удалось телепортироваться к " .. selectedPlayerName .. ". Возможно, его нет или персонаж не загружен.", Duration = 3})
                end
            else
                Notify({Title = "Teleport Error", Description = "Пожалуйста, выберите игрока из списка.", Duration = 3})
            end
        end
    })
end

-- Инициализируем список игроков при запуске
updatePlayerDropdown()

-- Подключаемся к событиям PlayerAdded и PlayerRemoving
Services.Players.PlayerAdded:Connect(function()
    task.wait(0.5) -- Небольшая задержка, чтобы дать персонажу игрока загрузиться
    updatePlayerDropdown()
end)

Services.Players.PlayerRemoving:Connect(updatePlayerDropdown)

-- === Вкладка "Settings" ===
local SettingsTab = Window:page({name = "Settings"})

-- Левая секция: GUI Control
local guiControlSection = SettingsTab:section({name = "GUI Control", side = "left", size = 200})

-- Бинд для скрытия/показа GUI
local currentToggleKey = defaultSettings.ToggleGUIKey
local guiKeybind = guiControlSection:keybind({
    name = "Toggle GUI Key", 
    def = currentToggleKey,
    callback = function(newKey)
        Window.key = newKey
        Notify({Title = "ZalupaHub", Description = "GUI Toggle Key changed to: " .. newKey.Name, Duration = 3})
    end
})

-- FPS Unlocker
local fpsUnlockerToggle = guiControlSection:toggle({name = "FPS Unlocker", def = false, callback = function(Boolean)
    if Boolean then
        if setfpscap then
            setfpscap(240)
            Notify({Title = "FPS Unlocker", Description = "FPS unlocked to 240!", Duration = 2})
        else
            Notify({Title = "FPS Unlocker", Description = "Your exploit does not support setfpscap!", Duration = 3})
        end
    else
        if setfpscap then
            setfpscap(defaultSettings.FPSCap)
            Notify({Title = "FPS Unlocker", Description = "FPS set to 60!", Duration = 2})
        end
    end
end})

-- Кнопка для сброса всех настроек GUI к значениям по умолчанию
guiControlSection:button({name = "Reset Settings", callback = function()
    -- Сброс WalkSpeed
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = defaultSettings.WalkSpeed
    -- Сброс Gravity
    Services.Workspace.Gravity = defaultSettings.Gravity
    -- Сброс Fly Speed
    flySpeed = defaultSettings.FlySpeed
    -- Сброс FOV
    Services.Workspace.CurrentCamera.FieldOfView = defaultSettings.FOV
    -- Сброс клавиши Toggle GUI Key (через setkey)
    Window.key = defaultSettings.ToggleGUIKey
    -- Сброс клавиши Fly Toggle Key (обновляем переменную)
    flyToggleKey = defaultSettings.FlyToggleKey
    -- Сброс FPS Unlocker (если включен)
    if setfpscap then
        fpsUnlockerToggle:set(false) -- Визуально выключаем тоггл и сбрасываем FPS
    end
    -- Принудительное выключение полета и noclip
    disableFlight()
    disableNoClip()
    
    -- Сброс звука уведомлений
    currentNotificationSoundId = defaultSettings.NotificationSoundId
    Notify({Title = "Settings", Description = "Звук уведомлений сброшен на стандартный.", Duration = 3})

    -- Сброс темы UI (стандартная тема)
    Window:settheme("accent", defaultSettings.ThemeAccent)

    Notify({Title = "Settings", Description = "All settings reset to default!", Duration = 3})
end})

-- Кнопка для полного закрытия скрипта
guiControlSection:button({name = "Destroy Script", callback = function()
    Window.screen:Remove()
    Notify({Title = "ZalupaHub", Description = "Script destroyed!", Duration = 3})
end})

-- Секция для тем UI (перемещена вправо)
local themeSection = SettingsTab:section({name = "UI Theme", side = "right", size = 200})

-- Функция для применения темы
local function applyTheme(accentColor)
    -- KinX UI использует settheme("accent", color) для изменения акцентного цвета
    Window:settheme("accent", accentColor)
    -- Уведомление при смене цвета убрано по просьбе
end

-- Colorpicker для выбора акцентного цвета темы
themeSection:colorpicker({name = "Custom Accent Color", def = defaultSettings.ThemeAccent, callback = function(Color)
    applyTheme(Color)
end})

-- Кнопки для заранее подготовленных тем
themeSection:button({name = "Theme: Standard", callback = function()
    applyTheme(Color3.fromRGB(244, 95, 115)) -- Оригинальный цвет акцента KinX
end})

themeSection:button({name = "Theme: Dark Orange", callback = function()
    applyTheme(Color3.fromRGB(150, 75, 0)) -- Темно-оранжевый акцент
end})

themeSection:button({name = "Theme: Dark Purple", callback = function()
    applyTheme(Color3.fromRGB(95, 81, 168)) -- Темно-фиолетовый акцент
end})

-- Секция About (перемещена вправо, под Theme Section)
local aboutSection = SettingsTab:section({name = "About", side = "right", size = 100})

-- Копирование Telegram Link
aboutSection:button({name = "Copy Telegram Link", callback = function()
    setclipboard("https://t.me/ubogiyinject")
    Notify({Title = "ZalupaHub", Description = "Telegram link copied!", Duration = 3})
end})

-- === Новая секция "Notification Settings" (находится слева, под GUI Control) ===
local notificationSettingsSection = SettingsTab:section({name = "Notification Settings", side = "left", size = 200})

notificationSettingsSection:dropdown({
    name = "Notification Sound",
    def = "Без звука", -- Значение по умолчанию
    options = {
        "Без звука",
        "Rust Headshot",
        "Osu Click",
        "Simple Click",
        "Click",
        "Screameeer"
    },
    callback = function(selectedOption)
        local soundMapping = {
            ["Без звука"] = "rbxassetid://0",
            ["Rust Headshot"] = "rbxassetid://4764109000",
            ["Osu Click"] = "rbxassetid://7147454322",
            ["Simple Click"] = "rbxassetid://6655851046",
            ["Click"] = "rbxassetid://8394620892",
            ["Screameeer"] = "rbxassetid://6429064547"
        }
        currentNotificationSoundId = soundMapping[selectedOption] or "rbxassetid://0"
        Notify({Title = "Настройки уведомлений", Description = "Звук изменен на: " .. selectedOption, Duration = 2})
    end
})

-- Добавим кнопку для тестирования выбранного звука
notificationSettingsSection:button({name = "Тест звука уведомления", callback = function()
    -- Вызываем Notify, чтобы воспроизвести текущий звук
    Notify({Title = "Тест звука", Description = "Это тестовое уведомление.", Duration = 2})
end})
-- =======================================================
-- BLOX FRUITS: AUTO FARM FRUIT, CONFIG GACHA, WEBHOOK & SAVE SETTING
-- =======================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- =======================================================
-- HỆ THỐNG FOLDER "Beta", LƯU & LOAD SETTING
-- =======================================================
local folderName = "Beta"
local configFileName = folderName .. "/AutoFruit_Setting.json"
local logFileName = folderName .. "/AutoFruit_Log_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".txt"
local errorFileName = folderName .. "/error.txt"

if makefolder and not isfolder(folderName) then
    pcall(function() makefolder(folderName) end)
end

local function writeLog(message, isError)
    local timestamp = os.date("[%X]")
    local formattedMsg = timestamp .. " " .. tostring(message)
    
    if isError then
        print("❌ " .. formattedMsg)
        if writefile and appendfile then
            pcall(function()
                if not isfile(errorFileName) then
                    writefile(errorFileName, formattedMsg .. "\n")
                else
                    appendfile(errorFileName, formattedMsg .. "\n")
                end
            end)
        end
    else
        print(formattedMsg)
    end
    
    if writefile and appendfile then
        pcall(function()
            if not isfile(logFileName) then
                writefile(logFileName, formattedMsg .. "\n")
            else
                appendfile(logFileName, formattedMsg .. "\n")
            end
        end)
    end
end

-- Cấu hình mặc định
local targetTeam = "Marines"
local tweenSpeed = 250
local autoGachaConfig = true
local webhookUrl = ""
local autoFarmEnabled = false

-- Đọc cấu hình từ getgenv() nếu có trước tiên
if getgenv().Config then
    if getgenv().Config.Team then targetTeam = getgenv().Config.Team end
    if getgenv().Config.TweenSpeed then tweenSpeed = getgenv().Config.TweenSpeed end
    if getgenv().Config.AutoGacha ~= nil then autoGachaConfig = getgenv().Config.AutoGacha end
    if getgenv().Config.WebhookUrl then webhookUrl = getgenv().Config.WebhookUrl end
end

-- Hàm đọc setting từ file JSON trong workspace
local function loadSetting()
    if not isfile or not readfile then return false end
    local success, result = pcall(function()
        if isfile(configFileName) then
            local content = readfile(configFileName)
            return HttpService:JSONDecode(content)
        end
    end)
    if success and type(result) == "table" then
        return result
    end
    return nil
end

local savedConfig = loadSetting()
if savedConfig then
    autoFarmEnabled = savedConfig.AutoFarm or autoFarmEnabled
    targetTeam = savedConfig.Team or targetTeam
    tweenSpeed = savedConfig.TweenSpeed or tweenSpeed
    autoGachaConfig = (savedConfig.AutoGacha ~= nil) and savedConfig.AutoGacha or autoGachaConfig
    webhookUrl = savedConfig.WebhookUrl or webhookUrl
    writeLog("Đã tải thành công setting cũ từ workspace/Beta!")
end

-- Hàm lưu setting vào file JSON
local function saveSetting(isFarmOn)
    if not writefile then return end
    pcall(function()
        local data = {
            AutoFarm = isFarmOn,
            Team = targetTeam,
            TweenSpeed = tweenSpeed,
            AutoGacha = autoGachaConfig,
            WebhookUrl = webhookUrl
        }
        writefile(configFileName, HttpService:JSONEncode(data))
    end)
end

writeLog("=== KHỞI ĐỘNG SCRIPT AUTO FARM FRUIT ===")
task.wait(5)

-- =======================================================
-- GỬI WEBHOOK DISCORD
-- =======================================================
local function sendWebhook(title, description, color)
    if not webhookUrl or webhookUrl == "" then return end
    
    task.spawn(function()
        pcall(function()
            local requestFunc = syn and syn.request or http_request or request or HttpPost
            if not requestFunc then return end
            
            local data = {
                ["embeds"] = {
                    {
                        ["title"] = title,
                        ["description"] = description,
                        ["color"] = color or 65280,
                        ["footer"] = {
                            ["text"] = "Blox Fruits Auto Farm Fruit • " .. os.date("%Y-%m-%d %X")
                        }
                    }
                }
            }
            
            requestFunc({
                Url = webhookUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(data)
            })
        end)
    end)
end

-- =======================================================
-- AUTO CHỌN TEAM
-- =======================================================
local function autoSelectTeam()
    pcall(function()
        if LocalPlayer.Team == nil or LocalPlayer.Team.Name == "" or LocalPlayer.Team.Name == "Neutral" then
            local commF = ReplicatedStorage:WaitForChild("Remotes", 5) and ReplicatedStorage.Remotes:WaitForChild("CommF_", 5)
            if commF then
                commF:InvokeServer("SetTeam", targetTeam)
                writeLog("Đã chọn Team thành công: " .. targetTeam)
            end
        end
    end)
end

autoSelectTeam()

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    writeLog("Nhân vật đã respawn/load lại.")
end)

local isTweening = false
local currentTween = nil
local noclipConnection = nil
local bodyVelocity = nil

getgenv()._BF_IS_HOPPING = false

local espFolder = Instance.new("Folder")
espFolder.Name = "FruitESPFolder"
espFolder.Parent = Workspace

-- =======================================================
-- QUEUE TELEPORT & ULTRA HOP (XỬ LÝ SERVER ĐẦY/LỖI/ĐÔNG)
-- =======================================================
local queueTeleport = (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or queue_on_teleport
    or (getgenv and getgenv().queue_on_teleport)

if not getgenv()._BF_RECENT_JOBIDS then
    getgenv()._BF_RECENT_JOBIDS = {}
end

if game.JobId and game.JobId ~= "" then
    local list = getgenv()._BF_RECENT_JOBIDS
    for i = #list, 1, -1 do
        if list[i] == game.JobId then
            table.remove(list, i)
        end
    end
    table.insert(list, 1, game.JobId)
    while #list > 5 do
        table.remove(list)
    end
    getgenv()._BF_RECENT_JOBIDS = list
end

local function isRecent(jobId)
    if jobId == game.JobId then return true end
    for _, id in ipairs(getgenv()._BF_RECENT_JOBIDS) do
        if id == jobId then return true end
    end
    return false
end

local function ultraFastHop()
    if getgenv()._BF_IS_HOPPING then return end
    getgenv()._BF_IS_HOPPING = true
    writeLog("Đang tiến hành Ultra Hop tìm server mới...")

    local serverBrowser = ReplicatedStorage:WaitForChild("__ServerBrowser", 5)
    if not serverBrowser then
        writeLog("[LỖI] Không tìm thấy __ServerBrowser để Hop!", true)
        getgenv()._BF_IS_HOPPING = false
        return
    end

    local hopped = false

    local function tryTeleport(targetJob)
        if hopped then return end

        local list = getgenv()._BF_RECENT_JOBIDS
        table.insert(list, 1, targetJob)
        while #list > 5 do
            table.remove(list)
        end
        getgenv()._BF_RECENT_JOBIDS = list

        if queueTeleport then
            local str = HttpService:JSONEncode(list)
            local autoScript = string.format([[
                getgenv()._BF_RECENT_JOBIDS = game:GetService('HttpService'):JSONDecode('%s')
                getgenv().AUTO_FARM_FRUIT = true
                getgenv().Config = {
                    Team = "%s",
                    TweenSpeed = %d,
                    AutoGacha = %s,
                    WebhookUrl = "%s"
                }
            ]], str, targetTeam, tweenSpeed, tostring(autoGachaConfig), webhookUrl)
            pcall(function() queueTeleport(autoScript) end)
        end

        local success, err = pcall(function()
            for _ = 1, 5 do
                local res = serverBrowser:InvokeServer("teleport", targetJob)
                if res and type(res) == "string" and res:lower():find("full") then
                    error("GameFull")
                end
                task.wait(0.2)
            end
        end)

        if success then
            hopped = true
        else
            writeLog("[CẢNH BÁO] Server lỗi hoặc đầy. Đang đổi sang server khác...", true)
            getgenv()._BF_IS_HOPPING = false
            task.spawn(function()
                task.wait(1)
                ultraFastHop()
            end)
        end
    end

    local startOffset = math.random(1, 50)
    for batch = 0, 9 do
        task.spawn(function()
            for i = 1, 50 do
                if hopped then return end
                local page = startOffset + batch * 50 + i
                local pageData = nil
                pcall(function()
                    pageData = serverBrowser:InvokeServer(page)
                end)

                if type(pageData) == "table" and next(pageData) and not hopped then
                    local validList = {}
                    for jobId, playerObj in pairs(pageData) do
                        local playerCount = type(playerObj) == "table" and playerObj.Count or 0
                        if jobId and jobId ~= "" and not isRecent(jobId) and playerCount < 12 then
                            table.insert(validList, jobId)
                        end
                    end

                    if #validList == 0 then
                        for jobId, _ in pairs(pageData) do
                            if jobId and jobId ~= "" and not isRecent(jobId) then
                                table.insert(validList, jobId)
                            end
                        end
                    end

                    if #validList > 0 and not hopped then
                        local target = validList[math.random(1, #validList)]
                        writeLog("Đã tìm thấy Server phù hợp, chuẩn bị Teleport sang JobId: " .. tostring(target))
                        tryTeleport(target)
                        return
                    end
                end
            end
        end)
    end

    task.delay(6, function()
        if not hopped then
            getgenv()._BF_IS_HOPPING = false
            writeLog("Hop server quá thời gian, thử lại vòng tiếp theo...", true)
            task.spawn(ultraFastHop)
        end
    end)
end

-- =======================================================
-- TWEEN & NOCLIP
-- =======================================================
local function setNoclip(enable)
    if enable then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                if Character then
                    for _, part in pairs(Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

local function stopTween()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end

    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end

    setNoclip(false)
    isTweening = false

    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = true
        task.wait(0.1)
        hrp.Anchored = false
    end
end

local function topos(Tween_Pos, onComplete)
    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    stopTween()

    local distance = (hrp.Position - Tween_Pos.Position).Magnitude

    if distance <= 300 then
        hrp.CFrame = Tween_Pos
        if onComplete then onComplete() end
        return
    end

    setNoclip(true)
    isTweening = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "BodyClip"
    bodyVelocity.Parent = hrp
    bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)

    local targetY = Tween_Pos.Y
    local targetCFrameHorizontal = CFrame.new(Tween_Pos.X, hrp.Position.Y, Tween_Pos.Z)
    local horizontalDistance = (hrp.Position - targetCFrameHorizontal.Position).Magnitude
    local duration = horizontalDistance / tweenSpeed

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrameHorizontal})

    currentTween.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed then
            hrp.CFrame = CFrame.new(Tween_Pos.X, targetY, Tween_Pos.Z)
            stopTween()
            if onComplete then onComplete() end
        else
            stopTween()
        end
    end)

    currentTween:Play()
end

-- =======================================================
-- LỌC TRÁI, AUTO STORE & WEBHOOK THÔNG BÁO
-- =======================================================
local function isRealFruit(obj)
    if not obj or not obj.Parent then return false end
    local name = obj.Name:lower()

    if name:find("tree") or name:find("enemy") or name:find("npc") or name:find("bush") or name:find("plant") then
        return false
    end

    local handle = obj:FindFirstChild("Handle") or (obj:IsA("BasePart") and obj)
    if handle and (obj:FindFirstChildOfClass("TouchInterest") or handle:FindFirstChildOfClass("TouchInterest") or name:find("fruit")) then
        return true, handle
    end
    return false
end

local function getSpawnedFruits()
    local fruits = {}
    for _, obj in pairs(Workspace:GetChildren()) do
        local isFruit, handle = isRealFruit(obj)
        if isFruit then
            table.insert(fruits, {Instance = obj, Handle = handle, Name = obj.Name})
        end
    end
    return fruits
end

local function autoStoreFruit(isGacha, gachaFruitName)
    task.wait(0.6)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
    
    if not commF then return end

    local fruitTool = nil
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:lower():find("fruit") or tool.Name:lower():find("trái")) then
                fruitTool = tool
                break
            end
        end
    end

    if not fruitTool and Character then
        for _, tool in pairs(Character:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:lower():find("fruit") or tool.Name:lower():find("trái")) then
                fruitTool = tool
                break
            end
        end
    end

    local actualFruitName = gachaFruitName or (fruitTool and fruitTool.Name)

    if fruitTool then
        pcall(function()
            commF:InvokeServer("StoreFruit", fruitTool.Name, fruitTool)
            writeLog("Đã cất kho trái cây: " .. tostring(fruitTool.Name))
            
            if not isGacha then
                sendWebhook("🍎 Nhặt Trái Thành Công!", "Người chơi **" .. LocalPlayer.Name .. "** đã nhặt và cất kho trái: **" .. tostring(fruitTool.Name) .. "**", 3066993)
            end
        end)
    end

    if isGacha and actualFruitName then
        sendWebhook("🎁 Gacha Trái Thành Công!", "Người chơi **" .. LocalPlayer.Name .. "** vừa quay Gacha ra trái: **" .. tostring(actualFruitName) .. "**", 15158332)
    end
end

local function autoGachaFruit()
    if not autoGachaConfig then return end

    task.spawn(function()
        writeLog("Bắt đầu vòng lặp Auto Gacha (15s/lượt).")
        while autoGachaConfig do
            pcall(function()
                local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                if commF then
                    commF:InvokeServer("Cousin", "DLCBoxData")
                    task.wait(0.5)
                    local result = commF:InvokeServer("Cousin", "try purchase DLCBoxData")
                    writeLog("Kết quả Gacha: " .. tostring(result))
                    
                    task.wait(0.5)
                    autoStoreFruit(true, type(result) == "string" and result ~= "Success" and result ~= "" and result or nil)
                end
            end)
            task.wait(15)
        end
    end)
end

-- =======================================================
-- ESP & VÒNG LẶP FARM CHÍNH
-- =======================================================
RunService.RenderStepped:Connect(function()
    espFolder:ClearAllChildren()
    if not autoFarmEnabled then return end

    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    local fruits = getSpawnedFruits()

    for _, fruit in pairs(fruits) do
        local handle = fruit.Handle
        if handle then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "ESP_" .. fruit.Name
            billboard.Adornee = handle
            billboard.Size = UDim2.new(0, 150, 0, 40)
            billboard.AlwaysOnTop = true
            billboard.Parent = espFolder

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, 0, 1, 0)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = Color3.fromRGB(255, 85, 85)
            txt.TextStrokeTransparency = 0
            txt.TextSize = 14
            txt.Font = Enum.Font.SourceSansBold
            txt.Parent = billboard

            local dist = hrp and math.floor((hrp.Position - handle.Position).Magnitude) or 0
            txt.Text = "🍎 " .. fruit.Name .. "\n[" .. dist .. "m]"
        end
    end
end)

local mainTitle

local function startOneClickLoop()
    task.spawn(function()
        writeLog("Bắt đầu vòng lặp Auto Farm Fruit...")
        if autoGachaConfig then
            autoGachaFruit()
        end

        while autoFarmEnabled do
            local fruits = getSpawnedFruits()

            if #fruits == 0 then
                if mainTitle then mainTitle.Text = "❌ Không có trái! Đang Hop..." end
                writeLog("Không tìm thấy trái nào trong server. Tiến hành Hop...")
                task.wait(1)
                ultraFastHop()
                break
            else
                writeLog("Phát hiện tổng cộng " .. tostring(#fruits) .." trái.")
                for i, fruit in ipairs(fruits) do
                    if not autoFarmEnabled then break end
                    if fruit.Handle and fruit.Handle.Parent then
                        if mainTitle then mainTitle.Text = string.format("🚀 (%d/%d): %s", i, #fruits, fruit.Name) end
                        writeLog(string.format("Đang bay tới nhặt trái: %s", fruit.Name))
                        
                        local completed = false
                        topos(fruit.Handle.CFrame + Vector3.new(0, 3, 0), function()
                            completed = true
                            autoStoreFruit(false)
                        end)

                        repeat task.wait(0.2) until completed or not isTweening or not autoFarmEnabled
                        if not autoFarmEnabled then break end
                    end
                end

                if autoFarmEnabled then
                    if mainTitle then mainTitle.Text = "✅ Đã nhặt hết! Chờ 5s hop..." end
                    task.wait(5)
                    if autoFarmEnabled then
                        ultraFastHop()
                        break
                    end
                end
            end
            task.wait(1)
        end
    end)
end

-- =======================================================
-- GIAO DIỆN GUI ĐIỀU KHIỂN
-- =======================================================
local gui = Instance.new("ScreenGui")
gui.Name = "FruitOneClickGui"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 120)
mainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

mainTitle = Instance.new("TextLabel")
mainTitle.Size = UDim2.new(1, 0, 0, 35)
mainTitle.Text = "⚡ AUTO FRUIT & HOP"
mainTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
mainTitle.TextSize = 13
mainTitle.Font = Enum.Font.SourceSansBold
mainTitle.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
mainTitle.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = mainTitle

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.9, 0, 0, 45)
toggleBtn.Position = UDim2.new(0.05, 0, 0.45, 0)
toggleBtn.Text = autoFarmEnabled and "🟢 AUTO FARM: BẬT" or "🔴 AUTO FARM: TẮT"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 14
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.BackgroundColor3 = autoFarmEnabled and Color3.fromRGB(40, 180, 100) or Color3.fromRGB(220, 60, 60)
toggleBtn.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = toggleBtn

toggleBtn.MouseButton1Click:Connect(function()
    autoFarmEnabled = not autoFarmEnabled
    saveSetting(autoFarmEnabled)

    if autoFarmEnabled then
        toggleBtn.Text = "🟢 AUTO FARM: BẬT"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
        startOneClickLoop()
    else
        toggleBtn.Text = "🔴 AUTO FARM: TẮT"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        stopTween()
        if mainTitle then mainTitle.Text = "⚡ AUTO FRUIT & HOP" end
    end
end)

-- Tự động chạy lại nếu trong workspace lưu trạng thái đang Bật
if autoFarmEnabled then
    task.spawn(function()
        task.wait(1)
        startOneClickLoop()
    end)
end

if getgenv().AUTO_FARM_FRUIT then
    getgenv().AUTO_FARM_FRUIT = nil
    autoFarmEnabled = true
    saveSetting(autoFarmEnabled)
    toggleBtn.Text = "🟢 AUTO FARM: BẬT"
    toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
    task.wait(1)
    startOneClickLoop()
end
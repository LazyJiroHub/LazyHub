if not game:IsLoaded() then game.Loaded:Wait() end

local Intro
do
    local made, result = pcall(function()
        local Players = game:GetService("Players")
        local TweenService = game:GetService("TweenService")
        local RunService = game:GetService("RunService")
        local CoreGui = game:GetService("CoreGui")
        local started = os.clock()
        local MIN_TIME = 3.2

        pcall(function()
            local old = (gethui and gethui() or CoreGui):FindFirstChild("LazyJiroIntro")
            if old then old:Destroy() end
        end)

        local gui = Instance.new("ScreenGui")
        gui.Name = "LazyJiroIntro"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 1000
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
        local mounted = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
        if not mounted or not gui.Parent then
            gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        end

        local pinkA, pinkB = Color3.fromRGB(255, 190, 212), Color3.fromRGB(255, 150, 190)
        local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = r; c.Parent = o end

        local back = Instance.new("Frame")
        back.Size = UDim2.fromScale(1, 1)
        back.BackgroundColor3 = Color3.fromRGB(14, 11, 17)
        back.BorderSizePixel = 0
        back.Parent = gui
        local backGrad = Instance.new("UIGradient")
        backGrad.Rotation = 90
        backGrad.Color = ColorSequence.new(Color3.fromRGB(30, 18, 34), Color3.fromRGB(11, 8, 14))
        backGrad.Parent = back

        local petals = {}
        for i = 1, 30 do
            local w = 8 + math.random() * 7
            local f = Instance.new("Frame")
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Size = UDim2.fromOffset(w, w * 0.7)
            f.BackgroundColor3 = (i % 2 == 0) and pinkA or pinkB
            f.BackgroundTransparency = 0.1 + math.random() * 0.25
            f.BorderSizePixel = 0
            f.Parent = back
            corner(f, UDim.new(0.5, 0))
            petals[i] = {
                f = f, x = math.random(), y = math.random(), spd = 0.06 + math.random() * 0.09,
                amp = 14 + math.random() * 34, ph = math.random() * 6.28, rs = (math.random() - 0.5) * 220,
            }
        end

        local center = Instance.new("Frame")
        center.AnchorPoint = Vector2.new(0.5, 0.5)
        center.Position = UDim2.fromScale(0.5, 0.5)
        center.Size = UDim2.fromOffset(460, 150)
        center.BackgroundTransparency = 1
        center.Parent = back

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 56)
        title.BackgroundTransparency = 1
        title.Text = "Obsession Hub"
        title.Font = Enum.Font.GothamBlack
        title.TextSize = 46
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Parent = center
        local titleGrad = Instance.new("UIGradient")
        titleGrad.Color = ColorSequence.new(Color3.fromRGB(255, 220, 232), Color3.fromRGB(255, 140, 186))
        titleGrad.Rotation = 0
        titleGrad.Parent = title

        local sub = Instance.new("TextLabel")
        sub.Position = UDim2.fromOffset(0, 66)
        sub.Size = UDim2.new(1, 0, 0, 22)
        sub.BackgroundTransparency = 1
        sub.Text = "Initializing"
        sub.Font = Enum.Font.GothamMedium
        sub.TextSize = 15
        sub.TextColor3 = Color3.fromRGB(200, 190, 210)
        sub.Parent = center

        local bar = Instance.new("Frame")
        bar.AnchorPoint = Vector2.new(0.5, 0)
        bar.Position = UDim2.new(0.5, 0, 0, 108)
        bar.Size = UDim2.fromOffset(280, 6)
        bar.BackgroundColor3 = Color3.fromRGB(45, 36, 52)
        bar.BorderSizePixel = 0
        bar.Parent = center
        corner(bar, UDim.new(0.5, 0))
        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = Color3.new(1, 1, 1)
        fill.BorderSizePixel = 0
        fill.Parent = bar
        corner(fill, UDim.new(0.5, 0))
        local fillGrad = Instance.new("UIGradient")
        fillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 200, 220), Color3.fromRGB(255, 150, 190))
        fillGrad.Parent = fill

        local status, target, shown, clock, closed = "Initializing", 0.05, 0, 0, false
        local beat = RunService.Heartbeat:Connect(function(dt)
            clock += dt
            for _, p in ipairs(petals) do
                p.y += p.spd * dt
                if p.y > 1.05 then p.y = -0.05; p.x = math.random() end
                p.f.Position = UDim2.new(p.x, math.sin(clock * 0.9 + p.ph) * p.amp, p.y, 0)
                p.f.Rotation += p.rs * dt
            end
            shown += (target - shown) * math.min(1, dt * 4)
            fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
            sub.Text = status .. string.rep(".", math.floor(clock * 2.5) % 4)
        end)

        local api = {}
        function api.Set(text, pct)
            if closed then return end
            status = text or status
            target = math.max(target, pct or target)
        end
        function api.Close()
            if closed then return end
            closed = true
            beat:Disconnect()
            gui:Destroy()
        end

        function api.Finish(window)
            task.spawn(function()
                if closed then return end
                local left = MIN_TIME - (os.clock() - started)
                if left > 0 then task.wait(left) end
                api.Set("Ready", 1)
                local deadline = os.clock() + 0.8
                while shown < 0.98 and os.clock() < deadline do task.wait() end
                local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("GuiObject") then
                        TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
                    end
                    if d:IsA("TextLabel") then
                        TweenService:Create(d, info, { TextTransparency = 1 }):Play()
                    end
                end
                if window then pcall(window.SetVisible, window, true) end
                task.wait(0.75)
                api.Close()
            end)
        end

        task.delay(45, api.Close)
        return api
    end)
    if made and type(result) == "table" then
        Intro = result
    else
        Intro = { Set = function() end, Finish = function() end, Close = function() end }
    end
end

local env = getgenv and getgenv() or _G
env.LazyJiroIntro = Intro
env.LazyJiroWindow = nil

local base = "https://raw.githubusercontent.com/jiroscriptsss/LazyHub/main/Games/"

local Games = {
    [118805555015549] = "LootToForge.lua",
}

local file = Games[game.PlaceId] or Games[game.GameId]

if not file then
    warn(("[Lazy Jiro Hub] Game not supported. PlaceId=%s GameId=%s"):format(tostring(game.PlaceId), tostring(game.GameId)))
    Intro.Set("This game is not supported", 1)
    task.delay(2.5, Intro.Close)
    return
end

Intro.Set("Downloading", 0.2)
local ok, src = pcall(function() return game:HttpGet(base .. file) end)
if not ok then
    warn("[Lazy Jiro Hub] Could not download " .. file .. ": " .. tostring(src))
    Intro.Set("Could not download the script", 1)
    task.delay(2.5, Intro.Close)
    return
end

local fn, err = loadstring(src)
if not fn then
    warn("[Lazy Jiro Hub] Script error in " .. file .. ": " .. tostring(err))
    Intro.Set("The script failed to load", 1)
    task.delay(2.5, Intro.Close)
    return
end

Intro.Set("Starting", 0.35)
local ran, runErr = pcall(fn)
if not ran then
    warn("[Lazy Jiro Hub] Script error in " .. file .. ": " .. tostring(runErr))
    Intro.Set("The script hit an error", 1)
    task.delay(2.5, Intro.Close)
    return
end

Intro.Finish(env.LazyJiroWindow)

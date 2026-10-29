if not game:IsLoaded() then
    game.Loaded:Wait()
end

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
            if old then
                old:Destroy()
            end
        end)

        local gui = Instance.new("ScreenGui")
        gui.Name = "LazyJiroIntro"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 1000
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        pcall(function()
            if syn and syn.protect_gui then
                syn.protect_gui(gui)
            end
        end)

        local mounted = pcall(function()
            gui.Parent = (gethui and gethui()) or CoreGui
        end)

        if not mounted or not gui.Parent then
            gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        end

        -- same palette as the hub window
        local Bg = Color3.fromRGB(14, 8, 9)
        local Element = Color3.fromRGB(42, 27, 28)
        local Stroke = Color3.fromRGB(70, 40, 42)
        local Accent = Color3.fromRGB(232, 58, 58)
        local Accent2 = Color3.fromRGB(255, 130, 120)
        local Deep = Color3.fromRGB(190, 36, 44)
        local SubText = Color3.fromRGB(196, 180, 182)

        local function corner(o, r)
            local c = Instance.new("UICorner")
            c.CornerRadius = r
            c.Parent = o
            return c
        end

        local sweepGrads = {}

        -- animated white border with the red shine sweep
        local function shineStroke(parent, thickness)
            local st = Instance.new("UIStroke")
            st.Color = Color3.new(1, 1, 1)
            st.Thickness = thickness or 1.4
            st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            st.Parent = parent

            local g = Instance.new("UIGradient")
            g.Rotation = 35
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 28, 34)),
                ColorSequenceKeypoint.new(0.42, Color3.fromRGB(150, 34, 40)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 190)),
                ColorSequenceKeypoint.new(0.58, Color3.fromRGB(232, 58, 58)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 28, 34)),
            })
            g.Parent = st
            sweepGrads[#sweepGrads + 1] = g
            return st
        end

        local function sheen(parent, radius)
            local s = Instance.new("Frame")
            s.Name = "Sheen"
            s.BackgroundColor3 = Color3.new(1, 1, 1)
            s.BorderSizePixel = 0
            s.Size = UDim2.new(1, 0, 0.5, 0)
            s.Parent = parent
            corner(s, radius)

            local g = Instance.new("UIGradient")
            g.Rotation = 90
            g.Transparency = NumberSequence.new(0.8, 1)
            g.Parent = s
            return s
        end

        local back = Instance.new("Frame")
        back.Size = UDim2.fromScale(1, 1)
        back.BackgroundColor3 = Color3.new(1, 1, 1)
        back.BorderSizePixel = 0
        back.Parent = gui

        local backGrad = Instance.new("UIGradient")
        backGrad.Rotation = 90
        backGrad.Color = ColorSequence.new(
            Color3.fromRGB(34, 15, 16),
            Color3.fromRGB(10, 5, 6)
        )
        backGrad.Parent = back

        local petalColors = { Accent, Accent2, Deep }
        local petals = {}

        for i = 1, 30 do
            local w = 8 + math.random() * 7
            local f = Instance.new("Frame")

            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Size = UDim2.fromOffset(w, w * 0.7)
            f.BackgroundColor3 = petalColors[(i % 3) + 1]
            f.BackgroundTransparency = 0.12 + math.random() * 0.3
            f.BorderSizePixel = 0
            f.Parent = back

            corner(f, UDim.new(0.5, 0))

            petals[i] = {
                f = f,
                x = math.random(),
                y = math.random(),
                spd = 0.06 + math.random() * 0.09,
                amp = 14 + math.random() * 34,
                ph = math.random() * 6.28,
                rs = (math.random() - 0.5) * 220,
            }
        end

        local card = Instance.new("Frame")
        card.Name = "Card"
        card.AnchorPoint = Vector2.new(0.5, 0.5)
        card.Position = UDim2.fromScale(0.5, 0.5)
        card.Size = UDim2.fromOffset(480, 176)
        card.BackgroundColor3 = Color3.new(1, 1, 1)
        card.BackgroundTransparency = 0.03
        card.BorderSizePixel = 0
        card.Parent = back
        corner(card, UDim.new(0, 16))

        local cardGrad = Instance.new("UIGradient")
        cardGrad.Rotation = 90
        cardGrad.Color = ColorSequence.new(
            Color3.fromRGB(38, 17, 18),
            Bg
        )
        cardGrad.Parent = card

        shineStroke(card, 1.5)

        local title = Instance.new("TextLabel")
        title.Position = UDim2.fromOffset(0, 24)
        title.Size = UDim2.new(1, 0, 0, 56)
        title.BackgroundTransparency = 1
        title.Text = "OBSESSION HUB"
        title.Font = Enum.Font.GothamBlack
        title.TextSize = 42
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Parent = card

        local titleGrad = Instance.new("UIGradient")
        titleGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 24, 30)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 190, 180)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 24, 30)),
        })
        titleGrad.Parent = title
        sweepGrads[#sweepGrads + 1] = titleGrad

        local sub = Instance.new("TextLabel")
        sub.Position = UDim2.fromOffset(0, 88)
        sub.Size = UDim2.new(1, 0, 0, 22)
        sub.BackgroundTransparency = 1
        sub.Text = "Initializing"
        sub.Font = Enum.Font.GothamMedium
        sub.TextSize = 15
        sub.TextColor3 = Accent2
        sub.Parent = card

        local bar = Instance.new("Frame")
        bar.AnchorPoint = Vector2.new(0.5, 0)
        bar.Position = UDim2.new(0.5, 0, 0, 128)
        bar.Size = UDim2.fromOffset(300, 8)
        bar.BackgroundColor3 = Element
        bar.BorderSizePixel = 0
        bar.Parent = card
        corner(bar, UDim.new(0.5, 0))

        local barStroke = Instance.new("UIStroke")
        barStroke.Color = Stroke
        barStroke.Thickness = 1
        barStroke.Transparency = 0.3
        barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        barStroke.Parent = bar

        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = Color3.new(1, 1, 1)
        fill.BorderSizePixel = 0
        fill.Parent = bar
        corner(fill, UDim.new(0.5, 0))
        sheen(fill, UDim.new(0.5, 0))

        local fillGrad = Instance.new("UIGradient")
        fillGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 28, 34)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 140)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 36, 44)),
        })
        fillGrad.Parent = fill
        sweepGrads[#sweepGrads + 1] = fillGrad

        local status = "Initializing"
        local target = 0.05
        local shown = 0
        local clock = 0
        local closed = false

        local beat = RunService.Heartbeat:Connect(function(dt)
            clock += dt

            for _, p in ipairs(petals) do
                p.y += p.spd * dt

                if p.y > 1.05 then
                    p.y = -0.05
                    p.x = math.random()
                end

                p.f.Position = UDim2.new(
                    p.x,
                    math.sin(clock * 0.9 + p.ph) * p.amp,
                    p.y,
                    0
                )

                p.f.Rotation += p.rs * dt
            end

            local offset = Vector2.new(((clock * 0.45) % 2) - 1, 0)

            for _, g in ipairs(sweepGrads) do
                g.Offset = offset
            end

            local progressStep = dt * 4

            if progressStep > 1 then
                progressStep = 1
            end

            shown += (target - shown) * progressStep
            fill.Size = UDim2.fromScale(
                math.clamp(shown, 0, 1),
                1
            )

            sub.Text = status .. string.rep(
                ".",
                math.floor(clock * 2.5) % 4
            )
        end)

        local api = {}

        function api.Set(text, pct)
            if closed then
                return
            end

            status = text or status
            target = math.max(target, pct or target)
        end

        function api.Close()
            if closed then
                return
            end

            closed = true
            beat:Disconnect()
            gui:Destroy()

            local e = getgenv and getgenv() or _G

            if e.LazyJiroIntro == api then
                e.LazyJiroIntro = nil
            end
        end

        function api.Finish(window)
            task.spawn(function()
                if closed then
                    return
                end

                local left = MIN_TIME - (os.clock() - started)

                if left > 0 then
                    task.wait(left)
                end

                api.Set("Ready", 1)

                local deadline = os.clock() + 0.8

                while shown < 0.98 and os.clock() < deadline do
                    task.wait()
                end

                local info = TweenInfo.new(
                    0.7,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                )

                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("GuiObject") then
                        TweenService:Create(
                            d,
                            info,
                            { BackgroundTransparency = 1 }
                        ):Play()
                    end

                    if d:IsA("TextLabel") then
                        TweenService:Create(
                            d,
                            info,
                            { TextTransparency = 1 }
                        ):Play()
                    end

                    if d:IsA("UIStroke") then
                        TweenService:Create(
                            d,
                            info,
                            { Transparency = 1 }
                        ):Play()
                    end
                end

                -- the window may be built after Finish was called, so look it up late
                local e = getgenv and getgenv() or _G
                local hub = window or e.LazyJiroWindow

                if hub then
                    pcall(hub.SetVisible, hub, true)
                end

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
        Intro = {
            Set = function() end,
            Finish = function() end,
            Close = function() end,
        }
    end
end

local env = getgenv and getgenv() or _G

env.LazyJiroIntro = Intro
env.LazyJiroIntroAt = os.clock()
env.LazyJiroWindow = nil

local BASE =
    "https://raw.githubusercontent.com/LazyJiroHub/LazyHub/refs/heads/main/Folder/"

local Registry = {
    {
        name = "Anime Dice",
        file = "AnimeDice.lua",
        ids = { 113290951185459, 10708913337 },
    },

    {
        name = "Loot To Forge",
        file = "LootToForge.lua",
        ids = { 118805555015549 },
    },

    {
        name = "Deep Fishing",
        file = "DeepFishing.lua",
        ids = { 132239307080610 },
    },

    {
        name = "Ride A Pet",
        file = "RideAPet.lua",
        ids = { 124216119978534 },
    },

    {
        name = "Project Delta Premium",
        file = "Project Delta Premium.lua",
        ids = { 7336302630, 2862098693 },
    },

    {
        name = "Strafe Fps",
        file = "StrafeFps.lua",
        ids = { 109020905733214, 9187332740 },
    },

    {
        name = "Tap Simulator Reborn",
        file = "TapSimulator.lua",
        ids = { 72858262610964 },
    },
}

local byId = {}

for _, entry in ipairs(Registry) do
    for _, id in ipairs(entry.ids) do
        byId[id] = entry
    end
end

local entry = byId[game.GameId] or byId[game.PlaceId]

local function Fail(message, warning)
    warn("[LazyJiro Hub] " .. warning)
    Intro.Set(message, 1)
    task.delay(2.5, Intro.Close)
end

if not entry then
    Fail(
        "This game is not supported",
        ("Game not supported. PlaceId=%s GameId=%s"):format(
            tostring(game.PlaceId),
            tostring(game.GameId)
        )
    )

    return
end

Intro.Set("Downloading " .. entry.name, 0.2)

local url = BASE .. (entry.file:gsub(" ", "%%20"))

local ok, src = pcall(function()
    return game:HttpGet(url)
end)

if not ok then
    Fail(
        "Could not download the script",
        "Could not download " .. entry.file .. ": " .. tostring(src)
    )

    return
end

local fn, err = loadstring(src)

if not fn then
    Fail(
        "The script failed to load",
        "Script error in " .. entry.file .. ": " .. tostring(err)
    )

    return
end

Intro.Set("Starting " .. entry.name, 0.35)

local ran, runErr = pcall(fn)

if not ran then
    Fail(
        "The script hit an error",
        "Script error in " .. entry.file .. ": " .. tostring(runErr)
    )

    return
end

Intro.Finish(env.LazyJiroWindow)

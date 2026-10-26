local Boot = getgenv()
if Boot.JiroBooting and os.clock() - Boot.JiroBooting < 25 then
	pcall(function()
		game:GetService("StarterGui")
			:SetCore("SendNotification", { Title = "Jiro", Text = "Already starting, give it a few seconds", Duration = 5 })
	end)
	return
end
Boot.JiroBooting = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
do
	local waited = 0
	local ok = false
	while not ok and waited < 25 do
		local events = ReplicatedStorage:FindFirstChild("Events")
		local remotes = events and events:FindFirstChild("RemoteEvents")
		ok = ReplicatedStorage:FindFirstChild("Shared") ~= nil and remotes ~= nil and remotes:FindFirstChild("ThrowRod") ~= nil and remotes:FindFirstChild("FishHooked") ~= nil
		if not ok then
			waited += task.wait(0.5) or 0.5
		end
	end
	if not ok then
		Boot.JiroBooting = nil
		warn("[Jiro] This is not Deep Fishing, the hub was not started")
		return
	end
	waited = 0
	while workspace:GetAttribute("ClientLoaded") ~= true and waited < 60 do
		waited += task.wait(0.25) or 0.25
	end
	LocalPlayer:WaitForChild("PlayerGui", 20)
	task.wait(0.5)
end
local BootOk, BootError = xpcall(function()
local Library = (function()
local LazyJiroLib = (function()
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")
local CoreGui          = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local Theme = {
    Bg      = Color3.fromRGB(14, 11, 17),
    Panel   = Color3.fromRGB(20, 16, 24),
    Card    = Color3.fromRGB(27, 22, 32),
    Element = Color3.fromRGB(37, 30, 43),
    Hover   = Color3.fromRGB(52, 42, 60),
    Stroke  = Color3.fromRGB(54, 44, 62),
    Accent  = Color3.fromRGB(255, 150, 190),
    Accent2 = Color3.fromRGB(255, 200, 220),
    Deep    = Color3.fromRGB(236, 92, 148),
    Text    = Color3.fromRGB(248, 242, 249),
    SubText = Color3.fromRGB(185, 185, 205),
    Good    = Color3.fromRGB(110, 231, 160),
}

local Lib = { Theme = Theme, Version = 6 }

local function New(class, props, kids)
    local o = Instance.new(class)
    if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    return o
end

local function Corner(o, r)
    return New("UICorner", { CornerRadius = type(r) == "number" and UDim.new(0, r) or r, Parent = o })
end

local function Stroke(o, color, thickness, transparency)
    return New("UIStroke", {
        Color = color or Theme.Stroke, Thickness = thickness or 1, Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o,
    })
end

local function Pad(o, l, t, r, b)
    t = t or l; r = r or l; b = b or t
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b), Parent = o,
    })
end

local function Grad(o, c1, c2, rot)
    return New("UIGradient", { Rotation = rot or 90, Color = ColorSequence.new(c1, c2), Parent = o })
end

local function Tween(o, props, t, style, dir)
    TweenService:Create(o, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props):Play()
end

local function Fire(cb, ...)
    if type(cb) ~= "function" then return end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(cb, table.unpack(args, 1, args.n))
        if not ok then warn("[Lazy Jiro Hub] callback error: " .. tostring(err)) end
    end)
end

local function IsPointer(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function IsMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function HeartPetal(parent, s, fill, line, pos, rot, transp)
    local d = s * 0.7071
    local box = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(s * 2.4, s * 2.4),
        Rotation = rot, BackgroundTransparency = 1, Parent = parent,
    })
    local function piece(circle, ox, oy, sz, color)
        local f = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, ox, 0.5, oy),
            Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = color, BackgroundTransparency = transp or 0, Parent = box,
        })
        if circle then Corner(f, UDim.new(0.5, 0)) else f.Rotation = 45; Corner(f, math.max(1, sz * 0.1)) end
    end
    if line then
        local g = math.max(2, s * 0.14)
        piece(false, 0, 0, s + g, line)
        piece(true, d / 2, -d / 2, s + g, line)
        piece(true, -d / 2, -d / 2, s + g, line)
    end
    piece(false, 0, 0, s, fill)
    piece(true, d / 2, -d / 2, s, fill)
    piece(true, -d / 2, -d / 2, s, fill)
    return box
end

local function MakeSakura(parent, size, speed, reg)
    local holder = New("Frame", { Name = "Sakura", Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent })
    local flower = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holder,
    })
    local s = size * 0.3
    local d = s * 0.7071
    local fills = { Color3.fromRGB(255, 190, 212), Color3.fromRGB(255, 172, 200) }
    local line = Color3.fromRGB(232, 96, 150)
    for i = 0, 4 do
        local a = math.rad(i * 72)
        HeartPetal(flower, s, fills[(i % 2) + 1], line, UDim2.new(0.5, math.sin(a) * d, 0.5, -math.cos(a) * d), i * 72)
    end
    for i = 0, 4 do
        local ang = i * 72 + 36
        local len = size * 0.15
        New("Frame", {
            AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(math.max(1, size * 0.025), len), Rotation = ang,
            BackgroundColor3 = Color3.fromRGB(226, 72, 124), Parent = flower,
        })
    end
    local disc = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size * 0.15, size * 0.15), BackgroundColor3 = Color3.fromRGB(240, 84, 138), Parent = flower,
    })
    Corner(disc, UDim.new(0.5, 0))
    for i = 0, 4 do
        local a = math.rad(i * 72 + 36)
        local len = size * 0.17
        local dot = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, math.sin(a) * len, 0.5, -math.cos(a) * len),
            Size = UDim2.fromOffset(math.max(2, size * 0.065), math.max(2, size * 0.065)),
            BackgroundColor3 = Color3.fromRGB(255, 226, 120), Parent = flower,
        })
        Corner(dot, UDim.new(0.5, 0))
    end
    if speed and speed ~= 0 then
        reg(RunService.Heartbeat:Connect(function(dt)
            flower.Rotation = (flower.Rotation + dt * speed) % 360
        end))
    end
    return holder, flower
end

local function MakeDraggable(handle, target, reg)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if IsPointer(i) then
            dragging, dragStart, startPos = true, i.Position, target.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    reg(UserInputService.InputChanged:Connect(function(i)
        if dragging and IsMove(i) then
            local d = i.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

local Elements = {}

local function nextOrder(card)
    if card._empty then card._empty:Destroy(); card._empty = nil end
    card._n = card._n + 1
    card._labelGroup = nil
    if card.Tab and card.Tab.Balance then card.Tab.Balance() end
    return card._n
end
local function addEl(card, name, frame) table.insert(card.Els, { Name = tostring(name), Frame = frame }) end
local function Row(card, h)
    return New("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = nextOrder(card), Parent = card.Frame })
end
local function RowLabel(row, text, width)
    return New("TextLabel", {
        Size = width or UDim2.new(1, -56, 1, 0), BackgroundTransparency = 1, Text = text,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
end

function Elements:AddSeparator()
    local sep = New("Frame", {
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.5,
        LayoutOrder = nextOrder(self), Parent = self.Frame,
    })
    addEl(self, "", sep)
    return sep
end

function Elements:AddToggle(o)
    local desc = o.Description ~= nil
    local row = Row(self, desc and 46 or 32)
    addEl(self, o.Name, row)
    RowLabel(row, o.Name, desc and UDim2.new(1, -56, 0, 32) or nil)
    if desc then
        New("TextLabel", {
            Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
            Text = o.Description, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
    end
    local sw = New("Frame", {
        AnchorPoint = desc and Vector2.new(1, 0) or Vector2.new(1, 0.5),
        Position = desc and UDim2.new(1, 0, 0, 5) or UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(42, 22), BackgroundColor3 = Theme.Element, Parent = row,
    })
    Corner(sw, UDim.new(0.5, 0))
    local st = Stroke(sw, Theme.Stroke, 1)
    local knob = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Theme.SubText, Parent = sw,
    })
    Corner(knob, UDim.new(0.5, 0))
    local btn = New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = row })

    local obj = { Value = false, Window = self.Window }
    function obj:Set(v, silent)
        v = v and true or false
        self.Value = v
        Tween(sw, { BackgroundColor3 = v and Theme.Accent or Theme.Element }, 0.2)
        Tween(st, { Color = v and Theme.Accent or Theme.Stroke }, 0.2)
        Tween(knob, {
            Position = v and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = v and Color3.new(1, 1, 1) or Theme.SubText,
        }, 0.22, Enum.EasingStyle.Back)
        if o.Flag then self.Window.Flags[o.Flag] = v end
        if not silent then Fire(o.Callback, v) end
    end
    btn.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
    obj:Set(o.Default or false, true)
    return obj
end

function Elements:AddToggleGrid(o)
    local items = o.Items or {}
    local cols = math.max(1, o.Columns or 2)
    local CELL, GAP = 36, 10
    local rowsN = math.max(1, math.ceil(#items / cols))
    local row = Row(self, rowsN * CELL + (rowsN - 1) * GAP)
    addEl(self, o.Name or table.concat(items, " "), row)
    New("UIGridLayout", {
        CellSize = UDim2.new(1 / cols, -(GAP * (cols - 1)) / cols, 0, CELL),
        CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row,
    })
    local obj = { Values = {}, Window = self.Window }
    local cells = {}
    for i, name in ipairs(items) do
        obj.Values[name] = false
        local b = New("TextButton", {
            LayoutOrder = i, BackgroundColor3 = Theme.Element, AutoButtonColor = false, Text = tostring(name),
            Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.SubText, Parent = row,
        })
        Corner(b, 10)
        cells[name] = { b = b, st = Stroke(b, Theme.Stroke, 1) }
    end
    function obj:Set(name, v, silent)
        local c = cells[name]
        if not c then return end
        v = v and true or false
        self.Values[name] = v
        Tween(c.b, { BackgroundColor3 = v and Theme.Accent or Theme.Element, TextColor3 = v and Theme.Bg or Theme.SubText }, 0.18)
        Tween(c.st, { Color = v and Theme.Accent or Theme.Stroke }, 0.18)
        if o.Flag then self.Window.Flags[o.Flag .. "." .. tostring(name)] = v end
        if not silent then Fire(o.Callback, name, v) end
    end
    for name, c in pairs(cells) do
        c.b.MouseButton1Click:Connect(function() obj:Set(name, not obj.Values[name]) end)
    end
    for _, name in ipairs(o.Default or {}) do obj:Set(name, true, true) end
    return obj
end

function Elements:AddSlider(o)
    local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
    local suffix = o.Suffix or ""
    local function fmt(v)
        if inc % 1 == 0 then return tostring(math.floor(v + 0.5)) end
        return string.format("%.2f", v)
    end

    local row = Row(self, 58)
    addEl(self, o.Name, row)
    RowLabel(row, o.Name, UDim2.new(1, -90, 0, 26))

    local box = New("TextBox", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(80, 26),
        BackgroundColor3 = Theme.Element, Text = "", Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Theme.Accent, ClearTextOnFocus = false, Parent = row,
    })
    Corner(box, 8); Stroke(box, Theme.Stroke, 1)

    local function stepBtn(txt, anchorX, posX)
        local b = New("TextButton", {
            AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(posX, 0, 0, 34), Size = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 1, AutoButtonColor = false, Text = txt, Font = Enum.Font.GothamBold,
            TextSize = 17, TextColor3 = Theme.SubText, Parent = row,
        })
        b.MouseEnter:Connect(function() Tween(b, { TextColor3 = Theme.Accent }, 0.15) end)
        b.MouseLeave:Connect(function() Tween(b, { TextColor3 = Theme.SubText }, 0.15) end)
        return b
    end
    local minus, plus = stepBtn("-", 0, 0), stepBtn("+", 1, 1)

    local bar = New("Frame", {
        Position = UDim2.new(0, 28, 0, 41), Size = UDim2.new(1, -56, 0, 6), BackgroundColor3 = Theme.Element, Parent = row,
    })
    Corner(bar, UDim.new(0.5, 0))
    local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar })
    Corner(fill, UDim.new(0.5, 0))
    Grad(fill, Theme.Accent2, Theme.Accent, 0)
    local knob = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = bar,
    })
    Corner(knob, UDim.new(0.5, 0)); Stroke(knob, Theme.Accent, 2.5)
    local hit = New("TextButton", {
        Position = UDim2.new(0, 28, 0, 30), Size = UDim2.new(1, -56, 0, 28), BackgroundTransparency = 1, Text = "", Parent = row,
    })

    local obj = { Value = nil, Window = self.Window }
    function obj:Set(v, silent)
        local steps = math.floor(((tonumber(v) or min) - min) / inc + 0.5)
        v = math.clamp(steps * inc + min, min, max)
        local changed = v ~= self.Value
        self.Value = v
        local rel = (max == min) and 0 or (v - min) / (max - min)
        fill.Size = UDim2.fromScale(rel, 1)
        knob.Position = UDim2.fromScale(rel, 0.5)
        box.Text = fmt(v) .. suffix
        if o.Flag then self.Window.Flags[o.Flag] = v end
        if changed and not silent then Fire(o.Callback, v) end
    end

    local dragging = false
    local function fromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        obj:Set(min + (max - min) * rel)
    end
    hit.InputBegan:Connect(function(i)
        if IsPointer(i) then dragging = true; fromX(i.Position.X) end
    end)
    self.Window.reg(UserInputService.InputChanged:Connect(function(i)
        if dragging and IsMove(i) then fromX(i.Position.X) end
    end))
    self.Window.reg(UserInputService.InputEnded:Connect(function(i)
        if IsPointer(i) then dragging = false end
    end))
    minus.MouseButton1Click:Connect(function() obj:Set(obj.Value - inc) end)
    plus.MouseButton1Click:Connect(function() obj:Set(obj.Value + inc) end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text:match("[%-%d%.]+"))
        obj:Set(n or obj.Value)
        box.Text = fmt(obj.Value) .. suffix
    end)
    obj:Set(o.Default or min, true)
    return obj
end

function Elements:AddButton(o)
    local isPrimary = o.Primary == true
    local bgColor = isPrimary and Theme.Accent or Theme.Element
    local txtColor = isPrimary and Theme.Bg or Theme.Text
    local strokeColor = isPrimary and Theme.Accent or Theme.Stroke

    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = bgColor, AutoButtonColor = false,
        Text = o.Name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = txtColor,
        LayoutOrder = nextOrder(self), Parent = self.Frame,
    })
    Corner(b, 10)
    local st = Stroke(b, strokeColor, 1)
    addEl(self, o.Name, b)

    b.MouseEnter:Connect(function()
        Tween(b, { BackgroundColor3 = isPrimary and Theme.Accent2 or Theme.Hover }, 0.15)
        Tween(st, { Color = isPrimary and Theme.Accent2 or Theme.Accent }, 0.15)
    end)
    b.MouseLeave:Connect(function()
        Tween(b, { BackgroundColor3 = bgColor }, 0.15)
        Tween(st, { Color = strokeColor }, 0.15)
    end)
    b.MouseButton1Click:Connect(function()
        Fire(o.Callback)
    end)
    return { Button = b, SetText = function(_, t) b.Text = t end }
end

function Elements:AddDropdown(o)
    local opts = o.Options or {}
    local multi = o.Multi == true
    local stacked = o.Stacked == true
    local ROW, GAP, MAX_LIST = 28, 4, 150
    local card = self

    local cont = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        LayoutOrder = nextOrder(self), Parent = self.Frame,
    })
    New("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = cont })
    addEl(self, o.Name, cont)
    if stacked then
        New("TextLabel", {
            LayoutOrder = -2, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = o.Name,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = cont,
        })
        if o.Description then
            New("TextLabel", {
                LayoutOrder = -1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                Text = o.Description, TextWrapped = true,
                Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
                Parent = cont,
            })
        end
    end

    local head = New("TextButton", {
        LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Element,
        AutoButtonColor = false, Text = "", Parent = cont,
    })
    Corner(head, 10); Stroke(head, Theme.Stroke, 1)
    local labelW = 0
    if not stacked then
        local okW, tw = pcall(function()
            return TextService:GetTextSize(tostring(o.Name), 13, Enum.Font.GothamMedium, Vector2.new(1000, 36)).X
        end)
        labelW = math.clamp((okW and tw or 80) + 8, 40, 125)
        New("TextLabel", {
            Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0, labelW, 1, 0), BackgroundTransparency = 1, Text = o.Name,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
        })
    end
    local val = New("TextLabel", {
        Position = stacked and UDim2.new(0, 12, 0, 0) or UDim2.new(0, 12 + labelW, 0, 0),
        Size = stacked and UDim2.new(1, -34, 1, 0) or UDim2.new(1, -(12 + labelW + 26), 1, 0), BackgroundTransparency = 1, Text = "",
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = stacked and Theme.Text or Theme.Accent,
        TextXAlignment = stacked and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
    })
    local arrow = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 14, 1, 0),
        BackgroundTransparency = 1, Text = "v", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.SubText, Parent = head,
    })
    local list = New("ScrollingFrame", {
        LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = cont,
    })
    New("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    New("UIPadding", { PaddingBottom = UDim.new(0, 6), Parent = list })

    local obj = { Value = multi and {} or nil, Window = self.Window }
    local buttons = {}
    local current = {}

    local function summary()
        local picked = {}
        for _, opt in ipairs(current) do
            if obj.Value[opt] then table.insert(picked, tostring(opt)) end
        end
        return #picked > 0 and table.concat(picked, ", ") or "None"
    end

    local function refreshColors()
        for opt, b in pairs(buttons) do
            local on
            if multi then on = obj.Value[opt] == true else on = opt == obj.Value end
            b.TextColor3 = on and Theme.Accent or Theme.SubText
            b.BackgroundColor3 = on and Theme.Hover or Theme.Panel
        end
    end

    function obj:Set(v, silent)
        if multi then
            local set = {}
            if type(v) == "table" then
                for k, x in pairs(v) do
                    if type(k) == "number" then set[x] = true elseif x then set[k] = true end
                end
            end
            self.Value = set
            val.Text = summary()
            refreshColors()
            if o.Flag then self.Window.Flags[o.Flag] = set end
            if not silent then Fire(o.Callback, table.clone(set)) end
            return
        end
        self.Value = v
        val.Text = tostring(v)
        refreshColors()
        if o.Flag then self.Window.Flags[o.Flag] = v end
        if not silent then Fire(o.Callback, v) end
    end

    function obj:Refresh(newOpts)
        for _, b in pairs(buttons) do b:Destroy() end
        buttons = {}
        current = newOpts
        local n = #newOpts
        local h = n > 0 and math.min(n * (ROW + GAP) - GAP, MAX_LIST) or 0
        list.Size = UDim2.new(1, 0, 0, h)
        for idx, opt in ipairs(newOpts) do
            local b = New("TextButton", {
                LayoutOrder = idx, Size = UDim2.new(1, -6, 0, ROW), BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
                Text = tostring(opt), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.SubText, Parent = list,
            })
            Corner(b, 8)
            b.MouseButton1Click:Connect(function()
                if multi then
                    local set = table.clone(obj.Value)
                    if set[opt] then set[opt] = nil else set[opt] = true end
                    obj:Set(set)
                else
                    obj:Set(opt)
                    list.Visible = false; arrow.Text = "v"
                    if card.Tab and card.Tab.Balance then card.Tab.Balance() end
                end
            end)
            buttons[opt] = b
        end
        if multi then val.Text = summary() end
        refreshColors()
    end

    head.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        arrow.Text = list.Visible and "^" or "v"
        task.delay(0.05, function()
            if card.Tab and card.Tab.Balance then card.Tab.Balance() end
        end)
    end)

    obj:Refresh(opts)
    if multi then
        obj:Set(o.Default or {}, true)
    else
        obj:Set(o.Default or opts[1] or "None", true)
    end
    return obj
end

function Elements:AddInput(o)
    if o.Stacked then
        local cont = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            LayoutOrder = nextOrder(self), Parent = self.Frame,
        })
        New("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = cont })
        addEl(self, o.Name, cont)
        New("TextLabel", {
            LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = o.Name,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = cont,
        })
        if o.Description then
            New("TextLabel", {
                LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                Text = o.Description, TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = cont,
            })
        end
        local sbox = New("TextBox", {
            LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Element, Text = o.Default or "",
            PlaceholderText = o.Placeholder or "Type here...", PlaceholderColor3 = Theme.SubText, Font = Enum.Font.Gotham,
            TextSize = 12, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = cont,
        })
        Corner(sbox, 10); Pad(sbox, 12, 0, 12, 0)
        local sst = Stroke(sbox, Theme.Stroke, 1)
        sbox.Focused:Connect(function() Tween(sst, { Color = Theme.Accent }, 0.15) end)
        sbox.FocusLost:Connect(function()
            Tween(sst, { Color = Theme.Stroke }, 0.15)
            if o.Flag then self.Window.Flags[o.Flag] = sbox.Text end
            Fire(o.Callback, sbox.Text)
        end)
        return { Box = sbox, Get = function() return sbox.Text end, Set = function(_, t) sbox.Text = t end }
    end
    local row = Row(self, 36)
    addEl(self, o.Name, row)
    RowLabel(row, o.Name, UDim2.new(0.42, 0, 1, 0))
    local box = New("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.55, 0, 0, 30),
        BackgroundColor3 = Theme.Element, Text = o.Default or "", PlaceholderText = o.Placeholder or "Type here...",
        PlaceholderColor3 = Theme.SubText, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Text,
        ClearTextOnFocus = false, Parent = row,
    })
    Corner(box, 9)
    local st = Stroke(box, Theme.Stroke, 1)
    box.Focused:Connect(function() Tween(st, { Color = Theme.Accent }, 0.15) end)
    box.FocusLost:Connect(function()
        Tween(st, { Color = Theme.Stroke }, 0.15)
        if o.Flag then self.Window.Flags[o.Flag] = box.Text end
        Fire(o.Callback, box.Text)
    end)
    return { Box = box, Get = function() return box.Text end, Set = function(_, t) box.Text = t end }
end

function Elements:AddKeybind(o)
    local row = Row(self, 32)
    addEl(self, o.Name, row)
    RowLabel(row, o.Name, UDim2.new(1, -96, 1, 0))
    local btn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(88, 26),
        BackgroundColor3 = Theme.Element, AutoButtonColor = false, Text = "", Font = Enum.Font.GothamBold,
        TextSize = 12, TextColor3 = Theme.Accent, Parent = row,
    })
    Corner(btn, 8); Stroke(btn, Theme.Stroke, 1)
    local obj = { Value = o.Default or Enum.KeyCode.Unknown }
    local listening = false
    function obj:Set(k, silent)
        self.Value = k
        btn.Text = k.Name
        if not silent then Fire(o.Changed, k) end
    end
    btn.MouseButton1Click:Connect(function() listening = true; btn.Text = "..." end)
    self.Window.reg(UserInputService.InputBegan:Connect(function(i, gpe)
        if listening then
            if i.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                obj:Set(i.KeyCode == Enum.KeyCode.Escape and obj.Value or i.KeyCode)
            end
        elseif not gpe and i.KeyCode == obj.Value and o.Callback then
            Fire(o.Callback)
        end
    end))
    obj:Set(obj.Value, true)
    return obj
end

function Elements:AddLabel(text)
    local group = self._labelGroup
    if not group then
        group = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            LayoutOrder = nextOrder(self), Parent = self.Frame,
        })
        New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = group })
        addEl(self, text, group)
        self._labelGroup = group
        self._labelEntry = self.Els[#self.Els]
        self._labelCount = 0
    else
        self._labelEntry.Name = self._labelEntry.Name .. " " .. tostring(text)
    end
    self._labelCount = self._labelCount + 1
    local l = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, TextWrapped = true,
        Text = text, RichText = true, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = self._labelCount, Parent = group,
    })
    return { Set = function(_, t) l.Text = t end }
end

function Lib:CreateWindow(cfg)
    cfg = cfg or {}
    local Window = {
        Pages = {}, Flags = {}, Visible = true, _conns = {}, _query = "",
        ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift,
    }
    local function reg(c) table.insert(Window._conns, c); return c end
    Window.reg = reg

    local function cleanup(parent)
        pcall(function()
            local o = parent and parent:FindFirstChild("LazyJiroHub")
            if o then o:Destroy() end
        end)
    end
    cleanup(CoreGui)
    cleanup(LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    pcall(function() if gethui then cleanup(gethui()) end end)

    local gui = New("ScreenGui", {
        Name = "LazyJiroHub", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    })
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    local mounted = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not mounted or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local baseScale = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and 0.75 or 1

    local holder = New("Frame", {
        Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(740, 470), BackgroundTransparency = 1, Parent = gui,
    })
    local main = New("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = holder,
    })
    Corner(main, 16)
    Grad(main, Color3.fromRGB(26, 17, 31), Theme.Bg, 90)
    local ws = Stroke(main, Color3.new(1, 1, 1), 1.3, 0.25)
    Grad(ws, Theme.Accent, Color3.fromRGB(70, 52, 90), 60)
    local scale = New("UIScale", { Scale = 0.6, Parent = main })
    Tween(scale, { Scale = baseScale }, 0.5, Enum.EasingStyle.Back)

    local glow = New("Frame", {
        Position = UDim2.fromOffset(208, 0), Size = UDim2.new(1, -208, 0, 170), BackgroundColor3 = Theme.Accent, ZIndex = 0, Parent = main,
    })
    Corner(glow, 16)
    New("UIGradient", {
        Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1) }),
        Parent = glow,
    })

    local layer = New("Frame", {
        Name = "Petals", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16),
        BackgroundTransparency = 1, ZIndex = 0, Parent = main,
    })
    local fall = {}
    for i = 1, 9 do
        local sz = 3.5 + math.random() * 2.5
        local p = HeartPetal(layer, sz, Color3.fromRGB(255, 176, 204), nil, UDim2.fromScale(0, 0), 0, 0.5)
        fall[i] = {
            f = p, x = math.random(), y = math.random(), spd = 0.035 + math.random() * 0.05,
            amp = 10 + math.random() * 24, ph = math.random() * 6.28, rs = (math.random() - 0.5) * 140,
        }
    end
    local clock = 0
    reg(RunService.Heartbeat:Connect(function(dt)
        if not holder.Visible or not layer.Visible then return end
        clock = clock + dt
        for _, p in ipairs(fall) do
            p.y = p.y + p.spd * dt
            if p.y > 1.05 then p.y = -0.05; p.x = math.random() end
            p.f.Position = UDim2.new(p.x, math.sin(clock * 0.9 + p.ph) * p.amp, p.y, 0)
            p.f.Rotation = p.f.Rotation + p.rs * dt
        end
    end))

    local SIDE = 208
    local side = New("Frame", { Name = "Sidebar", Size = UDim2.new(0, SIDE, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = main })
    Corner(side, 16)
    Grad(side, Color3.fromRGB(25, 18, 29), Color3.fromRGB(17, 13, 20), 90)
    local cover = New("Frame", { Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 16, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = side })
    Grad(cover, Color3.fromRGB(25, 18, 29), Color3.fromRGB(17, 13, 20), 90)
    New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Theme.Stroke, Parent = side })

    local header = New("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, Parent = side })
    local logoGlow = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(40, 40), Size = UDim2.fromOffset(58, 58),
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.88, Parent = header,
    })
    Corner(logoGlow, UDim.new(0.5, 0))
    local logo = MakeSakura(header, 48, 36, reg)
    logo.Position = UDim2.fromOffset(16, 16)
    local title = New("TextLabel", {
        Position = UDim2.fromOffset(72, 18), Size = UDim2.new(1, -76, 0, 20), BackgroundTransparency = 1,
        Text = cfg.Name or "LAZY JIRO HUB", Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
    })
    Grad(title, Theme.Accent2, Theme.Accent, 0)
    local subtitle = New("TextLabel", {
        Position = UDim2.fromOffset(72, 38), Size = UDim2.new(1, -76, 0, 16), BackgroundTransparency = 1,
        Text = cfg.Subtitle or "Detecting game...", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
    })
    if not cfg.Subtitle then
        task.spawn(function()
            local name
            local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
            if ok and info and info.Name then name = info.Name end
            if not name or name == "" then name = game.Name end
            if not name or name == "" or name == "Game" then name = "Unknown Game" end
            name = name:gsub("%b[]", ""):gsub("^%s+", ""):gsub("%s+$", "")
            subtitle.Text = name
            Window.GameName = name
        end)
    end

    local searchBg = New("Frame", { Position = UDim2.fromOffset(14, 84), Size = UDim2.new(1, -28, 0, 34), BackgroundColor3 = Theme.Element, Parent = side })
    Corner(searchBg, 10)
    local searchStroke = Stroke(searchBg, Theme.Stroke, 1)
    local sRing = New("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = searchBg })
    Corner(sRing, UDim.new(0.5, 0)); Stroke(sRing, Theme.SubText, 1.6)
    New("Frame", { Position = UDim2.fromOffset(20, 21), Size = UDim2.fromOffset(6, 2), Rotation = 45, BackgroundColor3 = Theme.SubText, Parent = searchBg })
    local search = New("TextBox", {
        Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = "",
        PlaceholderText = "Search...", PlaceholderColor3 = Theme.SubText, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = searchBg,
    })
    search.Focused:Connect(function() Tween(searchStroke, { Color = Theme.Accent }, 0.15) end)
    search.FocusLost:Connect(function() Tween(searchStroke, { Color = Theme.Stroke }, 0.15) end)

    local nav = New("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 122), Size = UDim2.new(1, 0, 1, -198), BackgroundTransparency = 1,
        ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = side,
    })
    New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = nav })
    local navOrder = 0

    local prof = New("Frame", { Position = UDim2.new(0, 10, 1, -68), Size = UDim2.new(1, -20, 0, 58), BackgroundColor3 = Theme.Card, Parent = side })
    Corner(prof, 12); Stroke(prof, Theme.Stroke, 1)
    local av = New("ImageLabel", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Theme.Element, Image = "", Parent = prof })
    Corner(av, UDim.new(0.5, 0)); Stroke(av, Theme.Accent, 1.5)
    local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(46, 45), Size = UDim2.fromOffset(11, 11), BackgroundColor3 = Theme.Good, Parent = prof })
    Corner(dot, UDim.new(0.5, 0)); Stroke(dot, Theme.Card, 2)
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok then av.Image = img end
    end)
    local function profLine(y, text, size, font, color)
        New("TextLabel", {
            Position = UDim2.fromOffset(60, y), Size = UDim2.new(1, -66, 0, 14), BackgroundTransparency = 1, Text = text,
            Font = font, TextSize = size, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = prof,
        })
    end
    profLine(9, LocalPlayer.DisplayName, 12, Enum.Font.GothamBold, Theme.Text)
    profLine(24, "@" .. LocalPlayer.Name, 10, Enum.Font.Gotham, Theme.SubText)
    profLine(37, "ID: " .. LocalPlayer.UserId, 10, Enum.Font.GothamMedium, Theme.Accent)

    local top = New("Frame", { Position = UDim2.fromOffset(SIDE, 0), Size = UDim2.new(1, -SIDE, 0, 62), BackgroundTransparency = 1, Parent = main })
    local tabHolder = New("Frame", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0), BackgroundTransparency = 1, Parent = top })

    local ctrl = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.new(0, 0, 0, 32),
        AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = top,
    })
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ctrl })

    local function iconBtn(order, kind, hoverBg, hoverFg)
        local b = New("TextButton", {
            LayoutOrder = order, Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Theme.Element,
            AutoButtonColor = false, Text = "", Parent = ctrl,
        })
        Corner(b, 10)
        local parts = {}
        local function bar(w, h, rot)
            local f = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h),
                Rotation = rot or 0, BackgroundColor3 = Theme.SubText, Parent = b,
            })
            Corner(f, UDim.new(0.5, 0))
            table.insert(parts, { inst = f })
        end
        if kind == "min" then
            bar(11, 2)
        elseif kind == "close" then
            bar(13, 2, 45); bar(13, 2, -45)
        elseif kind == "link" then
            local c = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22),
                Rotation = -45, BackgroundTransparency = 1, Parent = b,
            })
            for _, dx in ipairs({ -3.5, 3.5 }) do
                local ring = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, dx, 0.5, 0),
                    Size = UDim2.fromOffset(10, 7), BackgroundTransparency = 1, Parent = c,
                })
                Corner(ring, UDim.new(0.5, 0))
                table.insert(parts, { stroke = Stroke(ring, Theme.SubText, 1.6) })
            end
        end
        local function recolor(c)
            for _, p in ipairs(parts) do
                if p.stroke then Tween(p.stroke, { Color = c }, 0.15) else Tween(p.inst, { BackgroundColor3 = c }, 0.15) end
            end
        end
        b.MouseEnter:Connect(function() Tween(b, { BackgroundColor3 = hoverBg or Theme.Hover }, 0.15); recolor(hoverFg or Theme.Text) end)
        b.MouseLeave:Connect(function() Tween(b, { BackgroundColor3 = Theme.Element }, 0.15); recolor(Theme.SubText) end)
        return b
    end
    local liveBox = New("Frame", {
        LayoutOrder = 1, Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Theme.Element, Parent = ctrl,
    })
    Corner(liveBox, 10)
    local liveGlow = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20),
        BackgroundColor3 = Theme.Good, BackgroundTransparency = 0.85, Parent = liveBox,
    })
    Corner(liveGlow, UDim.new(0.5, 0))
    local liveDot = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Theme.Good, Parent = liveBox,
    })
    Corner(liveDot, UDim.new(0.5, 0))
    reg(RunService.Heartbeat:Connect(function()
        if not holder.Visible then return end
        local pulse = (math.sin(os.clock() * 4) + 1) / 2
        liveDot.BackgroundTransparency = 0.75 * (1 - pulse)
        liveGlow.BackgroundTransparency = 0.95 - 0.2 * pulse
    end))
    local hideBtn = iconBtn(2, "min")
    local closeBtn = iconBtn(3, "close", Color3.fromRGB(176, 52, 82), Color3.new(1, 1, 1))

    New("Frame", { Position = UDim2.new(0, 16, 1, -1), Size = UDim2.new(1, -32, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.35, Parent = top })

    local content = New("Frame", { Position = UDim2.fromOffset(SIDE, 62), Size = UDim2.new(1, -SIDE, 1, -62), BackgroundTransparency = 1, ClipsDescendants = true, Parent = main })

    MakeDraggable(top, holder, reg)
    MakeDraggable(header, holder, reg)

    local bubble = New("TextButton", {
        Name = "Bubble", Position = UDim2.new(0, 22, 0.5, -28), Size = UDim2.fromOffset(56, 56),
        BackgroundColor3 = Theme.Panel, AutoButtonColor = false, Text = "", Visible = false, Parent = gui,
    })
    Corner(bubble, UDim.new(0.5, 0))
    local bs = Stroke(bubble, Color3.new(1, 1, 1), 1.6)
    Grad(bs, Theme.Accent, Color3.fromRGB(90, 60, 110), 45)
    local bl = MakeSakura(bubble, 40, 30, reg)
    bl.AnchorPoint = Vector2.new(0.5, 0.5); bl.Position = UDim2.fromScale(0.5, 0.5)
    MakeDraggable(bubble, bubble, reg)

    local notifHolder = New("Frame", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18), Size = UDim2.new(0, 290, 1, -36),
        BackgroundTransparency = 1, Parent = gui,
    })
    New("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Parent = notifHolder })

    function Window:Notify(o)
        o = o or {}
        local dur = o.Duration or 4
        local n = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Panel,
            BackgroundTransparency = 1, Parent = notifHolder,
        })
        Corner(n, 12)
        local st = Stroke(n, Theme.Accent, 1, 1)
        Pad(n, 14, 11, 12, 0)
        New("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = n })
        New("TextLabel", {
            LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = o.Title or "Lazy Jiro Hub",
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 1, Parent = n,
        })
        New("TextLabel", {
            LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            Text = o.Content or "", TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = n,
        })
        local barWrap = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1, Parent = n })
        local bar = New("Frame", { Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, Parent = barWrap })
        Corner(bar, UDim.new(0.5, 0))

        local function fade(to)
            for _, d in ipairs(n:GetDescendants()) do
                if d:IsA("TextLabel") then Tween(d, { TextTransparency = to }, 0.3) end
            end
            Tween(n, { BackgroundTransparency = to == 0 and 0.03 or 1 }, 0.3)
            Tween(st, { Transparency = to == 0 and 0.35 or 1 }, 0.3)
            Tween(bar, { BackgroundTransparency = to }, 0.3)
        end
        fade(0)
        Tween(bar, { Size = UDim2.new(0, 0, 0, 3) }, dur, Enum.EasingStyle.Linear)
        task.delay(dur, function()
            fade(1)
            task.wait(0.35)
            n:Destroy()
        end)
    end

    function Window:SetVisible(v)
        self.Visible = v
        if v then
            holder.Visible = true; bubble.Visible = false
            scale.Scale = 0.6
            Tween(scale, { Scale = baseScale }, 0.4, Enum.EasingStyle.Back)
        else
            Tween(scale, { Scale = 0.01 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.2, function()
                if not self.Visible then holder.Visible = false; bubble.Visible = cfg.Bubble ~= false end
            end)
        end
    end
    function Window:Toggle() self:SetVisible(not self.Visible) end
    function Window:SetToggleKey(k) self.ToggleKey = k end
    function Window:SetPetals(v) layer.Visible = v end
    function Window:SetScale(s) baseScale = s; Tween(scale, { Scale = s }, 0.2) end
    function Window:Destroy()
        for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
        gui:Destroy()
    end

    bubble.MouseButton1Click:Connect(function() Window:SetVisible(true) end)
    hideBtn.MouseButton1Click:Connect(function() Window:SetVisible(false) end)
    closeBtn.MouseButton1Click:Connect(function()
        Tween(scale, { Scale = 0.01 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.22, function() Window:Destroy() end)
    end)
    reg(UserInputService.InputBegan:Connect(function(i, gpe)
        if not gpe and i.KeyCode == Window.ToggleKey then Window:Toggle() end
    end))

    function Window:_applyFilter()
        local page = self.CurrentPage
        if not page or not page.CurrentTab then return end
        local q = self._query:lower()
        for _, card in ipairs(page.CurrentTab.Cards) do
            local any = false
            for _, el in ipairs(card.Els) do
                local m = q == "" or el.Name:lower():find(q, 1, true) ~= nil
                el.Frame.Visible = m
                if m then any = true end
            end
            card.Frame.Visible = (q == "") or any
        end
        if page.CurrentTab.Balance then page.CurrentTab.Balance() end
    end
    search:GetPropertyChangedSignal("Text"):Connect(function()
        Window._query = search.Text
        Window:_applyFilter()
    end)

    function Window:AddCategory(text)
        navOrder = navOrder + 1
        local l = New("TextLabel", {
            LayoutOrder = navOrder, Size = UDim2.new(1, -20, 0, 28), BackgroundTransparency = 1, Text = text:upper(),
            Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, Parent = nav,
        })
        Pad(l, 6, 0, 0, 5)
    end

    local function selectPage(page)
        for _, p in ipairs(Window.Pages) do
            local on = p == page
            Tween(p.Btn, { BackgroundTransparency = on and 0.86 or 1 }, 0.2)
            Tween(p.Bar, { BackgroundTransparency = on and 0 or 1 }, 0.2)
            Tween(p.Chip, { BackgroundTransparency = on and 0.7 or 0.88 }, 0.2)
            Tween(p.NameLbl, { TextColor3 = on and Theme.Text or Theme.SubText }, 0.2)
            p.TabBar.Visible = on
            if not on then
                for _, t in ipairs(p.Tabs) do t.Frame.Visible = false end
            end
        end
        Window.CurrentPage = page
        page:_selectTab(page.CurrentTab or page.Tabs[1])
    end

    function Window:AddPage(o)
        local page = { Tabs = {}, Window = Window }
        navOrder = navOrder + 1
        page.Btn = New("TextButton", {
            LayoutOrder = navOrder, Size = UDim2.new(1, -20, 0, 40), BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = nav,
        })
        Corner(page.Btn, 11)
        page.Bar = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 20),
            BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, Parent = page.Btn,
        })
        Corner(page.Bar, UDim.new(0.5, 0))
        page.Chip = New("Frame", {
            Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.88, Parent = page.Btn,
        })
        Corner(page.Chip, 8)
        local icon = o.Icon and tostring(o.Icon) or nil
        if icon and icon:find("rbxassetid") then
            New("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
                BackgroundTransparency = 1, Image = icon, ImageColor3 = Theme.Accent, Parent = page.Chip,
            })
        elseif icon then
            New("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = icon, Font = Enum.Font.GothamBold,
                TextSize = 14, TextColor3 = Theme.Accent, Parent = page.Chip,
            })
        else
            HeartPetal(page.Chip, 6.5, Theme.Accent2, Theme.Deep, UDim2.new(0.5, 0, 0.5, 1), 22, 0)
        end
        page.NameLbl = New("TextLabel", {
            Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = o.Name,
            Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = page.Btn,
        })
        page.Btn.MouseEnter:Connect(function()
            if Window.CurrentPage ~= page then
                Tween(page.NameLbl, { TextColor3 = Theme.Text }, 0.15); Tween(page.Btn, { BackgroundTransparency = 0.94 }, 0.15)
            end
        end)
        page.Btn.MouseLeave:Connect(function()
            if Window.CurrentPage ~= page then
                Tween(page.NameLbl, { TextColor3 = Theme.SubText }, 0.15); Tween(page.Btn, { BackgroundTransparency = 1 }, 0.15)
            end
        end)

        page.TabBar = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 0, 0, 40),
            AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.Panel, Visible = false, Parent = tabHolder,
        })
        Corner(page.TabBar, 12); Stroke(page.TabBar, Theme.Stroke, 1); Pad(page.TabBar, 4, 4, 4, 4)
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center, Parent = page.TabBar,
        })

        function page:_selectTab(tab)
            if not tab then return end
            self.CurrentTab = tab
            for _, t in ipairs(self.Tabs) do
                local on = t == tab
                t.Frame.Visible = on and Window.CurrentPage == self
                Tween(t.Btn, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and Theme.Bg or Theme.SubText }, 0.2)
            end
            Window:_applyFilter()
        end

        function page:AddTab(name)
            local tab = { Cards = {}, Page = page }
            tab.Btn = New("TextButton", {
                LayoutOrder = #page.Tabs + 1, Size = UDim2.new(0, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AutoButtonColor = false, Text = name,
                Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.SubText, Parent = page.TabBar,
            })
            Corner(tab.Btn, 9); Pad(tab.Btn, 16, 0, 16, 0)
            Grad(tab.Btn, Theme.Accent2, Theme.Accent, 0)
            tab.Btn.MouseButton1Click:Connect(function() page:_selectTab(tab) end)
            tab.Btn.MouseEnter:Connect(function()
                if page.CurrentTab ~= tab then Tween(tab.Btn, { TextColor3 = Theme.Text }, 0.15) end
            end)
            tab.Btn.MouseLeave:Connect(function()
                if page.CurrentTab ~= tab then Tween(tab.Btn, { TextColor3 = Theme.SubText }, 0.15) end
            end)

            tab.Frame = New("ScrollingFrame", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 3,
                ScrollBarImageColor3 = Theme.Accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(), Visible = false, Parent = content,
            })
            New("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = tab.Frame,
            })
            New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Parent = tab.Frame })
            local colRow = New("Frame", {
                LayoutOrder = 2, Size = UDim2.new(1, -32, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = tab.Frame,
            })
            New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Parent = tab.Frame })
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16),
                SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top,
                Parent = colRow,
            })
            local function col(order)
                local c = New("Frame", {
                    LayoutOrder = order, Size = UDim2.new(0.5, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1, Parent = colRow,
                })
                New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
                New("UIPadding", { PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0), Parent = c })
                return c
            end
            tab.Cols = { Left = col(1), Right = col(2) }

            tab.Balance = function() end

            function tab:AddCard(title, side, tag)
                local colKey = (side == "Left" or side == "Right") and side
                    or (#tab.Cards % 2 == 0 and "Left" or "Right")
                local card = setmetatable({ Els = {}, _n = 0, Window = Window, Tab = tab }, { __index = Elements })
                card.Frame = New("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(1, 1, 1),
                    BackgroundTransparency = 0.04, Parent = tab.Cols[colKey],
                })
                Corner(card.Frame, 14); Stroke(card.Frame, Theme.Stroke, 1)
                Grad(card.Frame, Color3.fromRGB(33, 26, 38), Theme.Card, 90)
                Pad(card.Frame, 14, 14, 14, 14)
                New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card.Frame })

                local head = New("Frame", { LayoutOrder = -2, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = card.Frame })
                local pill = New("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(4, 16),
                    BackgroundColor3 = Color3.new(1, 1, 1), Parent = head,
                })
                Corner(pill, UDim.new(0.5, 0)); Grad(pill, Theme.Accent2, Theme.Deep, 90)
                New("TextLabel", {
                    Position = UDim2.fromOffset(13, 0), Size = UDim2.new(1, -13, 1, 0), BackgroundTransparency = 1, Text = title,
                    Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
                })
                if tag then
                    local badge = New("TextLabel", {
                        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(40, 20),
                        BackgroundColor3 = Color3.fromRGB(96, 40, 52), Text = tostring(tag), Font = Enum.Font.GothamBold,
                        TextSize = 11, TextColor3 = Color3.fromRGB(255, 140, 150), Parent = head,
                    })
                    Corner(badge, 6); Stroke(badge, Color3.fromRGB(230, 110, 110), 1)
                end
                New("Frame", { LayoutOrder = -1, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.3, Parent = card.Frame })

                card._empty = New("TextLabel", {
                    LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Nothing here yet",
                    Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText, TextTransparency = 0.45, Parent = card.Frame,
                })
                table.insert(tab.Cards, card)
                tab.Balance()
                return card
            end

            table.insert(page.Tabs, tab)
            if not page.CurrentTab then page:_selectTab(tab) end
            return tab
        end

        page.Btn.MouseButton1Click:Connect(function() selectPage(page) end)
        table.insert(Window.Pages, page)
        if #Window.Pages == 1 then selectPage(page) end
        return page
    end

    return Window
end

return Lib

end)()
    local LJ = LazyJiroLib
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local Library = {
        Options = {}, Toggles = {}, Unloaded = false,
        IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
        Commands = {}, _signals = {}, _unload = {}, _tabs = {},
    }

    local function safe(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, err = pcall(fn, ...)
        if not ok then warn("[LazyJiro] callback error: " .. tostring(err)) end
    end

    local SAKURA = "\u{1F338}"

    local function wrapElement(kind, idx, info, registry)
        local el = { Type = kind, Idx = idx, Text = info.Text, Tooltip = info.Tooltip, Callback = info.Callback, Changed = nil }
        function el:OnChanged(fn) self.Changed = fn end
        function el:RunChanged()
            safe(self.Callback, self.Value)
            safe(self.Changed, self.Value)
        end
        if idx then registry[idx] = el end
        return el
    end

    local function shortTip(info)
        local t = info.Tooltip
        if type(t) == "string" and #t > 0 and #t <= 58 then return t end
        return nil
    end

    local Groupbox = {}
    Groupbox.__index = Groupbox

    function Groupbox:AddToggle(idx, info)
        info = info or {}
        local el = wrapElement("Toggle", idx, info, Library.Toggles)
        el.Default = info.Default == true
        el.Value = el.Default
        local lj
        lj = self.Card:AddToggle({
            Name = tostring(info.Text or idx), Description = shortTip(info), Default = el.Default,
            Callback = function(v)
                if el.Value == v then return end
                el.Value = v
                el:RunChanged()
            end,
        })
        function el:SetValue(v)
            v = v and true or false
            self.Value = v
            lj:Set(v, true)
            self:RunChanged()
        end
        function el:SetText(t) self.Text = t end
        return el
    end

    function Groupbox:AddSlider(idx, info)
        info = info or {}
        local el = wrapElement("Slider", idx, info, Library.Options)
        local rounding = info.Rounding or 0
        local inc = rounding > 0 and (10 ^ -rounding) or 1
        el.Min, el.Max = info.Min or 0, info.Max or 100
        el.Default = info.Default or el.Min
        el.Value = el.Default
        local lj = self.Card:AddSlider({
            Name = tostring(info.Text or idx), Min = el.Min, Max = el.Max, Increment = inc,
            Suffix = info.Suffix or "", Default = el.Default,
            Callback = function(v)
                if el.Value == v then return end
                el.Value = v
                el:RunChanged()
            end,
        })
        function el:SetValue(v)
            local n = tonumber(v)
            if not n or n == self.Value then return end
            n = math.clamp(n, self.Min, self.Max)
            self.Value = n
            lj:Set(n, true)
            self:RunChanged()
        end
        return el
    end

    function Groupbox:AddDropdown(idx, info)
        info = info or {}
        local el = wrapElement("Dropdown", idx, info, Library.Options)
        local values = {}
        for _, v in ipairs(info.Values or {}) do table.insert(values, v) end
        el.Values, el.Multi = values, info.Multi == true
        local function exists(v) return table.find(values, v) ~= nil end
        local defaults = {}
        local d = info.Default
        if type(d) == "string" then
            if exists(d) then table.insert(defaults, d) end
        elseif type(d) == "table" then
            for _, c in ipairs(d) do if exists(c) then table.insert(defaults, c) end end
        elseif type(d) == "number" and values[d] ~= nil then
            table.insert(defaults, values[d])
        end
        el.Default = defaults
        if el.Multi then
            el.Value = {}
            for _, v in ipairs(defaults) do el.Value[v] = true end
        else
            el.Value = defaults[1] or values[1]
        end
        local lj
        lj = self.Card:AddDropdown({
            Name = tostring(info.Text or idx), Options = values, Multi = el.Multi, Description = shortTip(info),
            Stacked = #tostring(info.Text or idx) > 14,
            Default = el.Multi and defaults or defaults[1],
            Callback = function(v)
                if el.Multi then
                    local set = {}
                    for k, on in pairs(v) do if on then set[k] = true end end
                    el.Value = set
                else
                    if el.Value == v then return end
                    el.Value = v
                end
                el:RunChanged()
            end,
        })
        function el:SetValue(v)
            if self.Multi then
                if type(v) == "string" then v = (v == "") and {} or { [v] = true } end
                local set = {}
                for k, on in pairs(v or {}) do
                    if type(on) ~= "boolean" then
                        if exists(on) then set[on] = true end
                    elseif on and exists(k) then
                        set[k] = true
                    end
                end
                self.Value = set
                lj:Set(set, true)
            else
                if exists(v) then
                    self.Value = v
                    lj:Set(v, true)
                elseif not v then
                    self.Value = nil
                end
            end
            self:RunChanged()
        end
        function el:SetValues(list)
            values = {}
            for _, v in ipairs(list) do table.insert(values, v) end
            self.Values = values
            lj:Refresh(values)
        end
        return el
    end

    function Groupbox:AddInput(idx, info)
        info = info or {}
        local el = wrapElement("Input", idx, info, Library.Options)
        el.Default = info.Default or ""
        el.Value = el.Default
        local finished = info.Finished == true
        local lj = self.Card:AddInput({
            Name = tostring(info.Text or idx), Placeholder = info.Placeholder, Default = el.Default,
            Stacked = #tostring(info.Text or idx) > 12,
            Callback = function(text)
                el.Value = text
                el:RunChanged()
            end,
        })
        if not finished and lj.Box then
            lj.Box:GetPropertyChangedSignal("Text"):Connect(function() el.Value = lj.Box.Text end)
        end
        function el:SetValue(text)
            text = tostring(text or "")
            self.Value = text
            lj:Set(text)
            self:RunChanged()
        end
        return el
    end

    function Groupbox:AddButton(info, func)
        if type(info) == "string" then info = { Text = info, Func = func } end
        local handle = {}
        local clicked = false
        local lj = self.Card:AddButton({
            Name = tostring(info.Text or "Button"),
            Callback = function()
                if info.DoubleClick then
                    if not clicked then
                        clicked = true
                        handle.SetText(handle, "Click again to confirm")
                        task.delay(2, function() clicked = false; handle.SetText(handle, info.Text) end)
                        return
                    end
                    clicked = false
                    handle.SetText(handle, info.Text)
                end
                safe(info.Func or info.Callback)
            end,
        })
        function handle:SetText(t) lj:SetText(t) end
        function handle:AddButton() return handle end
        function handle:SetDisabled() end
        function handle:SetVisible() end
        return handle
    end

    function Groupbox:AddLabel(info, wrap)
        local text = type(info) == "table" and info.Text or info
        local current
        local lj = self.Card:AddLabel(tostring(text or ""))
        current = tostring(text or "")
        local handle = {}
        function handle:SetText(t)
            t = tostring(t)
            if t == current then return end
            current = t
            lj:Set(t)
        end
        function handle:SetVisible() end
        function handle:AddKeyPicker() return handle end
        function handle:AddColorPicker() return handle end
        return handle
    end

    function Groupbox:AddDivider() self.Card:AddSeparator() end
    function Groupbox:AddDependencyBox() return self end
    function Groupbox:SetupDependencies() end
    function Groupbox:Resize() end

    local TabMt = {}
    TabMt.__index = TabMt

    local function makeBox(tab, name, side)
        local card = tab.LJTab:AddCard(tostring(name), side)
        local box = setmetatable({ Card = card, Tab = tab }, Groupbox)
        tab.Groupboxes[name] = box
        return box
    end
    function TabMt:AddLeftGroupbox(name) return makeBox(self, name, "Left") end
    function TabMt:AddRightGroupbox(name) return makeBox(self, name, "Right") end
    function TabMt:AddTabbox() return { AddTab = function(_, name) return makeBox(self, name, "Right") end } end
    function TabMt:Show() self.Page:_selectTab(self.LJTab); end

    local WindowMt = {}
    WindowMt.__index = WindowMt

    local GROUP_OF = {
        Main = "Farm", Fishing = "Farm", Stats = "Farm",
        Upgrades = "Progress", Rewards = "Progress", Items = "Progress",
        Webhook = "Utilities", Misc = "Utilities", Settings = "Utilities",
    }
    local CATEGORY_OF = { Farm = "Deep Fishing", Utilities = "Extras" }

    function WindowMt:AddTab(name, icon)
        if type(name) == "table" then name = name.Name end
        name = tostring(name)
        local group = GROUP_OF[name] or "Utilities"
        local page = self.Pages[group]
        if not page then
            if CATEGORY_OF[group] then self.LJ:AddCategory(CATEGORY_OF[group]) end
            page = self.LJ:AddPage({ Name = group, Icon = SAKURA })
            self.Pages[group] = page
        end
        local ljtab = page:AddTab(name)
        local tab = setmetatable({ Page = page, LJTab = ljtab, Groupboxes = {}, Name = name }, TabMt)
        table.insert(Library._tabs, tab)
        return tab
    end

    function WindowMt:AddMiscTab(opts)
        local tab = self:AddTab("Misc", "zap")
        local box = tab:AddLeftGroupbox("Connection")
        local TeleportService = game:GetService("TeleportService")
        box:AddToggle("AntiAfk", { Text = "Anti AFK", Default = true })
        local idleConn
        local function applyAntiAfk(on)
            if idleConn then idleConn:Disconnect(); idleConn = nil end
            if on then
                idleConn = LocalPlayer.Idled:Connect(function()
                    pcall(function()
                        local vu = game:GetService("VirtualUser")
                        vu:CaptureController()
                        vu:ClickButton2(Vector2.new())
                    end)
                end)
                Library:GiveSignal(idleConn)
            end
        end
        applyAntiAfk(true)
        Library.Toggles.AntiAfk:OnChanged(applyAntiAfk)
        box:AddButton({ Text = "Rejoin", Func = function()
            Library:Notify({ Title = "Rejoin", Description = "Rejoining this server...", Time = 3 })
            pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
        end })
        box:AddButton({ Text = "Server Hop", Func = function()
            Library:Notify({ Title = "Server Hop", Description = "Looking for another server...", Time = 3 })
            task.spawn(function()
                local ok, body = pcall(function()
                    return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
                end)
                if ok then
                    local decoded = pcall(function() return HttpService:JSONDecode(body) end) and HttpService:JSONDecode(body) or nil
                    for _, s in ipairs(decoded and decoded.data or {}) do
                        if s.id ~= game.JobId and s.playing < s.maxPlayers then
                            pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer) end)
                            return
                        end
                    end
                end
                Library:Notify({ Title = "Server Hop", Description = "No other public servers were found.", Time = 4 })
            end)
        end })
        return tab
    end

    function Library:CreateWindow(info)
        info = info or {}
        local win = LJ:CreateWindow({
            Name = "LAZY JIRO HUB",
            Subtitle = tostring(info.Footer or "Deep Fishing"),
            ToggleKey = info.ToggleKeybind,
        })
        self.LJWindow = win
        local origDestroy = win.Destroy
        self._destroyWindow = origDestroy
        win.Destroy = function(w)
            if not Library.Unloaded then Library:Unload() else origDestroy(w) end
        end
        return setmetatable({ LJ = win, Pages = {} }, WindowMt)
    end

    setmetatable(Library, {
        __index = function(_, key)
            if key == "Toggled" then
                local w = rawget(Library, "LJWindow")
                return w == nil or w.Visible ~= false
            elseif key == "ActiveTab" then
                for _, tab in ipairs(rawget(Library, "_tabs")) do
                    if tab.LJTab.Frame.Visible then return tab end
                end
                return nil
            end
            return nil
        end,
        __newindex = function(t, k, v)
            if k == "Toggled" or k == "ActiveTab" then return end
            rawset(t, k, v)
        end,
    })

    function Library:Notify(info, time)
        local w = self.LJWindow
        if not w then return end
        if type(info) ~= "table" then info = { Description = tostring(info), Time = time } end
        w:Notify({ Title = info.Title or "Lazy Jiro Hub", Content = info.Description or "", Duration = info.Time or 4 })
    end

    function Library:GiveSignal(conn)
        table.insert(self._signals, conn)
        return conn
    end

    function Library:OnUnload(fn) table.insert(self._unload, fn) end

    function Library:Unload()
        if self.Unloaded then return end
        self.Unloaded = true
        for _, fn in ipairs(self._unload) do safe(fn) end
        for _, c in ipairs(self._signals) do pcall(function() c:Disconnect() end) end
        if self.LJWindow and self._destroyWindow then pcall(self._destroyWindow, self.LJWindow) end
    end

    function Library:ShowConfirmPrompt(info)
        local now = os.clock()
        if self._confirmAt and now - self._confirmAt < 5 then
            self._confirmAt = nil
            safe(info.OnConfirm)
        else
            self._confirmAt = now
            self:Notify({ Title = info.Title or "Confirm", Description = tostring(info.Text or "Are you sure?") .. " Press the same button again within 5 s to confirm.", Time = 5 })
        end
    end

    function Library:AddCommand(def) table.insert(self.Commands, def) end
    function Library.FetchAddon() return "return nil" end

    task.defer(function()
        pcall(function()
            LocalPlayer.Chatted:Connect(function(msg)
                local name, rest = msg:match("^;(%S+)%s*(.*)$")
                if not name then return end
                name = name:lower()
                for _, cmd in ipairs(Library.Commands) do
                    local hit = tostring(cmd.Name):lower() == name
                    for _, a in ipairs(cmd.Aliases or {}) do hit = hit or tostring(a):lower() == name end
                    if hit then
                        local ok, out = pcall(cmd.Callback, rest ~= "" and { rest:match("%S+") } or {})
                        Library:Notify({ Title = cmd.Name, Description = ok and tostring(out or "done") or tostring(out), Time = 4 })
                        return
                    end
                end
            end)
        end)
    end)

    local function makeSaveManager()
        local SM = { Ignore = {}, Folder = "LazyJiro", SubFolder = "", Library = nil }
        local fs = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
        local function dir() return SM.Folder .. (SM.SubFolder ~= "" and ("/" .. SM.SubFolder) or "") end
        local function ensure()
            if not (fs and makefolder and isfolder) then return end
            for _, p in ipairs({ SM.Folder, dir() }) do
                if not isfolder(p) then pcall(makefolder, p) end
            end
        end
        local function path(name) return dir() .. "/" .. name .. ".json" end
        function SM:SetLibrary(lib) self.Library = lib end
        function SM:IgnoreThemeSettings() end
        function SM:SetIgnoreIndexes(list) for _, k in ipairs(list) do self.Ignore[k] = true end end
        function SM:SetFolder(f) self.Folder = f end
        function SM:SetSubFolder(f) self.SubFolder = f end
        function SM:Save(name)
            if not fs then return false, "no file access" end
            if not name or name:gsub("%s", "") == "" then return false, "config name is empty" end
            ensure()
            local data = {}
            for idx, t in pairs(Library.Toggles) do if not self.Ignore[idx] then data[idx] = { Type = "Toggle", Value = t.Value } end end
            for idx, o in pairs(Library.Options) do
                if not self.Ignore[idx] and (o.Type == "Slider" or o.Type == "Dropdown" or o.Type == "Input") then
                    data[idx] = { Type = o.Type, Value = o.Value }
                end
            end
            local ok, err = pcall(writefile, path(name), HttpService:JSONEncode(data))
            return ok, err
        end
        function SM:Load(name)
            if not fs or not isfile(path(name)) then return false, "config not found" end
            local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path(name))) end)
            if not ok then return false, "bad config file" end
            for idx, saved in pairs(data) do
                local target = Library.Toggles[idx] or Library.Options[idx]
                if target and not self.Ignore[idx] then pcall(target.SetValue, target, saved.Value) end
            end
            return true
        end
        function SM:Delete(name)
            if fs and isfile(path(name)) and delfile then pcall(delfile, path(name)); return true end
            return false, "config not found"
        end
        function SM:RefreshConfigList()
            local out = {}
            if fs and listfiles and isfolder and isfolder(dir()) then
                for _, f in ipairs(listfiles(dir())) do
                    local n = f:match("([^/\\]+)%.json$")
                    if n and n ~= "autoload" then table.insert(out, n) end
                end
            end
            table.sort(out)
            return out
        end
        function SM:SaveAutoloadConfig(name)
            if not fs then return false, "no file access" end
            ensure()
            return pcall(writefile, dir() .. "/autoload.txt", name)
        end
        function SM:GetAutoloadConfig()
            if fs and isfile(dir() .. "/autoload.txt") then return readfile(dir() .. "/autoload.txt") end
            return "none"
        end
        function SM:DeleteAutoLoadConfig()
            if fs and isfile(dir() .. "/autoload.txt") and delfile then pcall(delfile, dir() .. "/autoload.txt") end
        end
        function SM:LoadAutoloadConfig()
            local name = self:GetAutoloadConfig()
            if name and name ~= "none" then
                task.delay(1.5, function() self:Load(name) end)
            end
        end
        function SM:BuildConfigSection(tab)
            local box = tab:AddLeftGroupbox("Configuration")
            box:AddInput("SaveManager_ConfigName", { Text = "Config name", Placeholder = "my config", Finished = true })
            box:AddButton({ Text = "Create config", Func = function()
                local ok, err = self:Save(Library.Options.SaveManager_ConfigName.Value)
                Library:Notify({ Title = "Config", Description = ok and "Saved" or tostring(err), Time = 3 })
            end })
            local list = box:AddDropdown("SaveManager_ConfigList", { Text = "Config list", Values = self:RefreshConfigList(), Default = 1 })
            box:AddButton({ Text = "Load config", Func = function()
                local ok, err = self:Load(Library.Options.SaveManager_ConfigList.Value)
                Library:Notify({ Title = "Config", Description = ok and "Loaded" or tostring(err), Time = 3 })
            end })
            box:AddButton({ Text = "Overwrite config", Func = function()
                local ok, err = self:Save(Library.Options.SaveManager_ConfigList.Value)
                Library:Notify({ Title = "Config", Description = ok and "Overwritten" or tostring(err), Time = 3 })
            end })
            box:AddButton({ Text = "Refresh list", Func = function() list:SetValues(self:RefreshConfigList()) end })
            box:AddButton({ Text = "Set as autoload", Func = function()
                local name = Library.Options.SaveManager_ConfigList.Value
                if name then
                    local ok, err = self:SaveAutoloadConfig(name)
                    Library:Notify({ Title = "Config", Description = ok and ("Autoload: " .. name) or tostring(err), Time = 3 })
                end
            end })
            local ui = tab:AddRightGroupbox("Menu")
            ui:AddButton({ Text = "Unload hub", Func = function() Library:Unload() end })
        end
        return SM
    end

    Library.SaveManager = makeSaveManager()
    Library.ThemeManager = {
        SetLibrary = function() end, SetFolder = function() end, ApplyToTab = function() end, ApplyToGroupbox = function() end,
    }
    return Library
end)()
local N = {}
local ThemeManager, SaveManager, Options, Toggles, Discord, GameName, LoaderScript, INSTANCE, alive, UIQueue, notify, HttpService
local RunService, LogFile, Log, brief, log, logProblem, flushLog, Perf, send, invoke, waitFor
do
	local function loadAddon(name)
		local lastError
		for attempt = 1, 3 do
			local ok, addon = pcall(function()
				return loadstring(Library.FetchAddon(AddonsUrl, name, attempt > 1))()
			end)
			if ok and type(addon) == "table" then
				return addon
			end
			lastError = addon
			if attempt < 3 then
				task.wait(1)
			end
		end
		warn("[Jiro] addon failed: " .. name .. " (" .. tostring(lastError) .. "), themes and configs are off this time")
		return setmetatable({ Ignore = {} }, {
			__index = function(_, key)
				if key == "Folder" or key == "SubFolder" then
					return nil
				end
				return function(_, ...)
					if key == "RefreshConfigList" then
						return {}
					end
					if key == "Save" or key == "Load" or key == "Delete" or key == "SaveAutoloadConfig" then
						return false, "addons unavailable"
					end
					return nil
				end
			end,
		})
	end
	ThemeManager = Library.ThemeManager
	SaveManager = Library.SaveManager
	Options = Library.Options
	Toggles = Library.Toggles
	Discord = "https://discord.gg/PdQvN2bDCu"
	GameName = "Deep Fishing"
	LoaderScript = (type(getgenv().LazyJiroLoader) == "string" and getgenv().LazyJiroLoader) or ""
	local Env = getgenv()
	if Env.DeepFishingInstance then
		pcall(function()
			Env.DeepFishingInstance.stop = true
		end)
	end
	task.wait(0.2)
	INSTANCE = { stop = false }
	Env.DeepFishingInstance = INSTANCE
	function alive()
		return not INSTANCE.stop and Env.DeepFishingInstance == INSTANCE and not Library.Unloaded
	end
	UIQueue = { list = {} }
	function UIQueue.push(fn)
		if #UIQueue.list < 200 then
			table.insert(UIQueue.list, fn)
		end
	end
	function UIQueue.flush()
		local list = UIQueue.list
		if #list == 0 then
			return
		end
		UIQueue.list = {}
		for _, fn in ipairs(list) do
			pcall(fn)
		end
	end
	function notify(Title, Text, Time)
		UIQueue.push(function()
			Library:Notify({ Title = Title, Description = Text, Time = Time or 3 })
		end)
	end
	HttpService = game:GetService("HttpService")
	RunService = game:GetService("RunService")
	LogFile = "Jiro_FISH_" .. LocalPlayer.Name .. "_log.txt"
	Log = { lines = {}, start = os.clock(), dirty = false, flushedAt = 0, problems = {}, problemCount = 0, limit = 4000 }
	function brief(value, depth)
		depth = depth or 0
		local kind = typeof(value)
		if kind == "Instance" then
			local ok, name = pcall(function()
				return value.Name
			end)
			return if ok then tostring(name) else "?"
		elseif kind == "Vector3" then
			return string.format("(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
		elseif kind == "number" then
			if value ~= value then
				return "nan"
			elseif value % 1 == 0 and math.abs(value) < 1e15 then
				return string.format("%d", value)
			elseif math.abs(value) >= 1e6 then
				return string.format("%.3g", value)
			end
			return string.format("%.2f", value)
		elseif kind == "string" then
			return if #value > 120 then string.sub(value, 1, 120) .. "..." else value
		elseif kind == "table" then
			if depth >= 2 then
				return "{...}"
			end
			local parts, n = {}, 0
			for k, v in pairs(value) do
				n += 1
				if n > 10 then
					table.insert(parts, "...")
					break
				end
				table.insert(parts, tostring(k) .. "=" .. brief(v, depth + 1))
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		end
		return tostring(value)
	end
	function log(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = if type(parts[i]) == "string" then parts[i] else brief(parts[i])
		end
		local line = string.format("[%7.2f] %s", os.clock() - Log.start, (string.gsub(table.concat(parts, " ", 1, parts.n), "%s+$", "")))
		if #line > 600 then
			line = string.sub(line, 1, 600) .. "..."
		end
		local lines = Log.lines
		lines[#lines + 1] = line
		if #lines > Log.limit + 500 then
			table.move(lines, #lines - Log.limit + 1, #lines, 1)
			for i = #lines, Log.limit + 1, -1 do
				lines[i] = nil
			end
		end
		Log.dirty = true
	end
	Library.LoadLogger = function(line)
		pcall(log, line)
	end
	function logProblem(text)
		text = string.sub(tostring(text or ""), 1, 300)
		log("PROBLEM", text)
		Log.problemCount += 1
		if #Log.problems < 12 and not table.find(Log.problems, text) then
			table.insert(Log.problems, text)
		end
	end
	function flushLog(force)
		if Log.dirty and type(writefile) == "function" and (force or os.clock() - Log.flushedAt > 30) then
			Log.dirty = false
			Log.flushedAt = os.clock()
			local head = ""
			if Log.header then
				local ok, text = pcall(Log.header)
				if ok and type(text) == "string" then
					head = text .. "\n"
				end
			end
			task.spawn(pcall, writefile, LogFile, head .. table.concat(Log.lines, "\n"))
		end
	end
	do
		local executor = "?"
		pcall(function()
			executor = table.concat({ identifyexecutor() }, " ")
		end)
		local version = "?"
		pcall(function()
			version = tostring(game.PlaceVersion)
		end)
		log("BOOT", GameName, "place", game.PlaceId, "version", version, "built on 172", "job", string.sub(tostring(game.JobId), 1, 8), "executor", executor)
	end
	Perf = { frames = 0, time = 0, worst = 0, hitches = 0, freezes = 0, work = {}, hitchLogAt = 0, last = nil }
	Library:GiveSignal(RunService.Heartbeat:Connect(function(dt)
		Perf.frames += 1
		Perf.time += dt
		if dt > Perf.worst then
			Perf.worst = dt
		end
		if dt > 0.1 then
			Perf.hitches += 1
			if dt > 0.25 and os.clock() - Perf.hitchLogAt > 2 then
				Perf.hitchLogAt = os.clock()
				log("HITCH", math.floor(dt * 1000) .. "ms", "while:", if Log.context then Log.context() else "?")
			end
			if dt > 1 then
				Perf.freezes += 1
			end
		end
	end))
	local function safeRequire(path)
		local result, done = nil, false
		task.spawn(function()
			local ok, value = pcall(function()
				local node = ReplicatedStorage
				for part in path:gmatch("[^%.]+") do
					node = node:WaitForChild(part, 8)
				end
				return require(node)
			end)
			result = ok and value or nil
			done = true
		end)
		local waited = 0
		while not done and waited < 12 do
			waited += task.wait(0.05) or 0.05
		end
		if result == nil then
			log("REQUIRE failed", path)
		end
		return result
	end
	N.safeRequire = safeRequire
	N.Sh = safeRequire("Shared") or {}
	function N.sh(path)
		local node = N.Sh
		for part in string.gmatch(path, "[^%.]+") do
			if type(node) ~= "table" then
				return nil
			end
			local ok, child = pcall(function()
				return node[part]
			end)
			if not ok then
				return nil
			end
			node = child
		end
		return node
	end
	local Allowed = {
		ThrowRod = true,
		FishHooked = true,
		ReelBait = true,
		FishCaught = true,
		CancelThrow = true,
		Upgrades = true,
		RodShop = true,
		BaitShop = true,
		ConsumeBait = true,
		Potion = true,
		EquipTool = true,
		Lock = true,
		Teleport = true,
		Enchant = true,
		MutationReroll = true,
		FishingObject = true,
		JoJoUnbox = true,
		LikeGift = true,
		BossRelic = true,
		BigMouth = true,
		Pond = true,
		Offline = true,
		DailyRewards = true,
		DailyClaimable = true,
		PlaytimeGift = true,
		NextDayReward = true,
		EarlyLeaveReward = true,
		Comeback = true,
		Season = true,
		Achievement = true,
		Codes = true,
		GroupReward = true,
		Referral = true,
		Settings = true,
		Tutorial = true,
		PondGuide = true,
		DoubleSpeed = true,
		OfflineNet = true,
		StreakHold = true,
		HatchEgg = true,
		EquipPet = true,
		Cargo = true,
		Merchant = true,
		ThrowCharges = true,
		AdminGift = true,
		Skins = true,
		Cave = true,
		Maze = true,
	}
	local Functions = { Sell = true, SellAll = true }
	local Quiet = { ThrowRod = true, FishHooked = true, ReelBait = true, FishCaught = true, EquipTool = true, Lock = true }
	local Kinds = {
		DailyClaimable = { Claim = true, Sync = true },
		Pond = { Collect = true, AddFish = true, AddFood = true, BuyFood = true, Upgrade = true, EquipBest = true, SellAllDead = true, ReviveHeart = true },
		MutationReroll = { Spin = true, Skip = true },
		Settings = { RareCutscene = true, TeleportCutscene = true, AutoFeed = true },
		OfflineNet = { Buy = true },
		Cargo = { Give = true, Send = true, Claim = true, Sync = true },
		EquipPet = { Equip = true, PondEquip = true, PondUnequip = true },
		HatchEgg = { Place = true, Hatch = true },
		Merchant = { Open = true, Buy = true },
		ThrowCharges = { Use = true },
		Season = { Claim = true, Gift = true, Quest = true },
		AdminGift = { Claim = true, ClaimAll = true },
		Skins = { Equip = true },
		Cave = { ClaimRod = true },
		Maze = { ClaimRod = true },
	}
	N.Sent ={ count = 0, byName = {}, window = {}, recent = {} }
	function N.remoteExists(name)
		local events = ReplicatedStorage:FindFirstChild("Events")
		local folder = events and events:FindFirstChild(if Functions[name] then "RemoteFunctions" else "RemoteEvents")
		return folder ~= nil and folder:FindFirstChild(name) ~= nil
	end
	local function pace(name)
		local now = os.clock()
		local recent = N.Sent.recent
		while #recent > 0 and now - recent[1] > 1 do
			table.remove(recent, 1)
		end
		local w = N.Sent.window[name]
		if not w or now - w.at > 2 then
			w = { at = now, n = 0 }
			N.Sent.window[name] = w
		end
		if (#recent >= 15 or w.n >= 120) and coroutine.isyieldable() then
			task.wait(if #recent >= 15 then math.max(1 - (now - recent[1]), 0.05) else math.max(2 - (now - w.at), 0.05))
			pace(name)
			return
		end
		w.n += 1
		table.insert(recent, os.clock())
	end
	local function event(name)
		local Ev = N.Sh.Events
		if type(Ev) ~= "table" or type(Ev.Client) ~= "function" or not N.remoteExists(name) then
			return nil
		end
		local ok, obj = pcall(Ev.Client, name)
		return if ok then obj else nil
	end
	N.event = event
	function send(name, ...)
		local first = ...
		if not Allowed[name] or (Kinds[name] and not Kinds[name][first]) then
			log("BLOCKED", name, brief(first))
			return false
		end
		local obj = event(name)
		if not obj then
			log("NO REMOTE", name)
			return false
		end
		pace(name)
		local args = table.pack(...)
		local learn = N.Learn
		if learn then
			learn.replaying = true
		end
		local ok, err = pcall(function()
			obj:Fire(true, table.unpack(args, 1, args.n))
		end)
		if learn then
			learn.replaying = false
		end
		N.Sent.count += 1
		N.Sent.byName[name] = (N.Sent.byName[name] or 0) + 1
		if not Quiet[name] or not ok then
			log("SEND", name, brief(table.pack(...)), if ok then "" else "failed: " .. tostring(err))
		end
		return ok
	end
	function invoke(name, ...)
		if not Functions[name] then
			log("BLOCKED", name)
			return nil
		end
		local obj = event(name)
		if not obj then
			log("NO REMOTE", name)
			return nil
		end
		pace(name)
		local args = table.pack(...)
		local ok, result = pcall(function()
			return obj:Invoke(5, table.unpack(args, 1, args.n))
		end)
		N.Sent.count += 1
		N.Sent.byName[name] = (N.Sent.byName[name] or 0) + 1
		if not ok then
			log("INVOKE failed", name, tostring(result))
			return nil
		end
		return result
	end
	N.Listeners = {}
	function N.listen(name, fn)
		task.spawn(function()
			local obj
			local waited = 0
			while not obj and waited < 30 and alive() do
				obj = event(name)
				if not obj then
					waited += task.wait(1) or 1
				end
			end
			if not obj then
				log("NO REMOTE", "listen " .. name)
				return
			end
			local ok, err = pcall(function()
				obj:Connect(function(...)
					if not alive() then
						return
					end
					local fine, problem = pcall(fn, ...)
					if not fine then
						log("ERROR", "event " .. name, tostring(problem))
					end
				end)
			end)
			if ok then
				N.Listeners[name] = true
			else
				log("ERROR", "listen " .. name, tostring(err))
			end
		end)
	end
	function waitFor(check, seconds)
		local waited = 0
		while waited < seconds do
			if check() then
				return true
			end
			waited += task.wait(0.05) or 0.05
		end
		return check() and true or false
	end
end
local formatNumber, allows, selected, on, optionNumber, optionText, Status, setStatus, picked
do
	local Suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
	function formatNumber(n)
		n = tonumber(n) or 0
		if n ~= n or n == math.huge then
			return "?"
		end
		local negative = n < 0
		n = math.abs(n)
		local text
		if n < 1000 then
			text = if n % 1 == 0 or n >= 100 then tostring(math.floor(n)) else (string.format("%.1f", n):gsub("%.0$", ""))
		else
			local i = 1
			while n >= 1000 and i < #Suffixes do
				n /= 1000
				i += 1
			end
			text = string.format("%.2f", n):gsub("%.?0+$", "") .. Suffixes[i]
		end
		return (if negative then "-" else "") .. text
	end
	function N.longTime(seconds)
		seconds = math.max(0, math.floor(tonumber(seconds) or 0))
		if seconds >= 3600 then
			return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
		elseif seconds >= 60 then
			return string.format("%dm", math.ceil(seconds / 60))
		end
		return string.format("%ds", seconds)
	end
	function allows(option, value)
		local v = option and option.Value
		if v == nil then
			return true
		end
		if type(v) == "table" then
			if next(v) == nil then
				return true
			end
			return v[value] == true
		end
		return v == value
	end
	function selected(option, value)
		local v = option and option.Value
		if type(v) == "table" then
			return v[value] == true
		end
		return v == value
	end
	function picked(option)
		local list = {}
		local v = option and option.Value
		if type(v) == "table" then
			for key, yes in pairs(v) do
				if yes then
					table.insert(list, key)
				end
			end
			table.sort(list)
		elseif type(v) == "string" and v ~= "" then
			table.insert(list, v)
		end
		return list
	end
	function on(name)
		local t = Toggles[name]
		return t ~= nil and t.Value == true
	end
	function optionNumber(name, default)
		local option = Options[name]
		return tonumber(option and option.Value) or default
	end
	function optionText(name, default)
		local option = Options[name]
		local value = option and option.Value
		return if type(value) == "string" and value ~= "" then value else default
	end
	function N.planner()
		return on("SmartPlanner")
	end
	function N.wants(name)
		return on(name) or N.planner()
	end
	function N.reserve()
		local P = N.Plan
		return if P and N.planner() and P.need and (P.eta or 1) <= 0.25 then (tonumber(P.need.price) or 0) else 0
	end
	local IdleAt = {}
	function N.planIdle(reason, status)
		setStatus(status or ("Waiting: " .. reason))
		if N.planner() and os.clock() - (IdleAt[reason] or -1e9) > 60 then
			IdleAt[reason] = os.clock()
			log("PLAN idle", "reason=" .. reason)
		end
	end
	function N.safeMove()
		return optionText("MoveMode", "Teleport") ~= "Teleport"
	end
	local DueAt = {}
	function N.due(key, seconds)
		local now = os.clock()
		if now >= (DueAt[key] or 0) then
			DueAt[key] = now + seconds
			return true
		end
		return false
	end
	function N.undue(key)
		DueAt[key] = nil
	end
	Status = "Idle"
	local StatusSeen, StatusSeenCount = {}, 0
	function setStatus(text)
		if Status ~= text then
			local now = os.clock()
			if now - (StatusSeen[text] or -1e9) > 4 then
				log("STATUS", text)
			end
			if not StatusSeen[text] then
				StatusSeenCount += 1
				if StatusSeenCount > 400 then
					table.clear(StatusSeen)
					StatusSeenCount = 0
				end
			end
			StatusSeen[text] = now
			Log.statusAt = now
		end
		Status = text
	end
	Log.context = function()
		return Status
	end
	function N.data()
		local pd = N.Sh.PlayerData
		local client = type(pd) == "table" and rawget(pd, "Client")
		local data = type(client) == "table" and client.Data
		return if type(data) == "table" then data else {}
	end
	function N.ready()
		return next(N.data()) ~= nil
	end
	function N.cash()
		return tonumber(N.data().Cash) or 0
	end
	function N.level()
		return tonumber(N.data().Level) or 1
	end
	function N.tab(key)
		local v = N.data()[key]
		return if type(v) == "table" then v else {}
	end
	function N.serverTime()
		local ok, now = pcall(function()
			return workspace:GetServerTimeNow()
		end)
		return if ok and type(now) == "number" then now else os.time()
	end
	function N.worldKey()
		local raw = N.data().World or "World 1"
		local cfg = N.sh("Config.WorldsConfig")
		if type(cfg) == "table" and type(cfg.KeyFromUIName) == "function" then
			local ok, key = pcall(cfg.KeyFromUIName, raw)
			if ok and type(key) == "string" then
				return key
			end
		end
		return raw
	end
	function N.worldCfg(key)
		local cfg = N.sh("Config.WorldsConfig")
		local worlds = type(cfg) == "table" and cfg.Worlds
		return type(worlds) == "table" and worlds[key or N.worldKey()] or nil
	end
	function N.worldNumber(key)
		local w = N.worldCfg(key)
		return w and tonumber(w.WorldNumber) or 0
	end
	function N.unlocked(key)
		return N.tab("UnlockedWorlds")[key] == true
	end
	function N.bestFishingWorld()
		local best, bestNumber = "World 1", 1
		for key, yes in pairs(N.tab("UnlockedWorlds")) do
			local n = N.worldNumber(key)
			local w = N.worldCfg(key)
			if yes and w and not w.NoFishing and n > bestNumber then
				best, bestNumber = key, n
			end
		end
		return best, bestNumber
	end
	function N.inv()
		return N.tab("Inventory")
	end
	function N.isLocked(item)
		local lockMod = N.sh("Modules.Lock")
		if type(lockMod) == "table" and type(lockMod.IsLocked) == "function" then
			local ok, yes = pcall(lockMod.IsLocked, item)
			if ok then
				return yes == true
			end
		end
		return type(item.Data) == "table" and item.Data.Locked == true
	end
	function N.fishDef(name)
		local fish = N.sh("Content.Item.Fish")
		if type(fish) ~= "table" or type(fish.Get) ~= "function" then
			return nil
		end
		local ok, def = pcall(fish.Get, fish, name, true)
		return if ok and type(def) == "table" then def else nil
	end
	function N.value(item)
		local svc = N.sh("Services.Item")
		if type(svc) ~= "table" or type(svc.GetSellValue) ~= "function" then
			local def = item and N.fishDef(item.Name)
			return def and tonumber(def.SellPrice) or 0
		end
		local ok, v = pcall(svc.GetSellValue, svc, LocalPlayer, item)
		return if ok and type(v) == "number" then v else 0
	end
	function N.fishValue(name, size, mutation)
		return N.value({ Type = "Fish", Name = name, Data = { Size = size or 1, Mutation = mutation } })
	end
	function N.relicOf(item)
		local bp = N.sh("Services.Backpack")
		if type(bp) ~= "table" or type(bp.RelicKey) ~= "function" then
			return nil
		end
		local ok, key = pcall(bp.RelicKey, bp, item)
		if ok and key ~= nil and not (type(item.Data) == "table" and item.Data.Used) then
			return key
		end
		return nil
	end
	function N.keeps(item, def)
		def = def or N.fishDef(item.Name)
		local rarity = def and def.Rarity or "Common"
		if selected(Options.KeepRarities, rarity) or selected(Options.KeepFish, tostring(item.Name)) then
			return true
		end
		if N.cargoKeeps and N.cargoKeeps(item) then
			return true
		end
		return on("KeepMutated") and type(item.Data) == "table" and item.Data.Mutation ~= nil
	end
	local ValueCache, Stats = {}, { at = -1e9 }
	function N.cachedValue(guid, item)
		local now = os.clock()
		local c = ValueCache[guid]
		if not c or now - c.at > 60 or c.item ~= item then
			c = { v = N.value(item), at = now, item = item }
			ValueCache[guid] = c
		end
		return c.v
	end
	function N.fishStats(fresh)
		local now = os.clock()
		if not fresh and now - Stats.at < 2 then
			return Stats.count, Stats.sellable, Stats.value, Stats.total
		end
		local count, sellable, value, total = 0, 0, 0, 0
		local inv = N.inv()
		for guid, item in pairs(inv) do
			if type(item) == "table" and item.Type == "Fish" then
				count += 1
				if not N.relicOf(item) then
					local def = N.fishDef(item.Name)
					if not def or def.SellPrice then
						local v = N.cachedValue(guid, item)
						total += v
						if not N.isLocked(item) and not N.keeps(item, def) then
							sellable += 1
							value += v
						end
					end
				end
			end
		end
		if now - (Stats.trimAt or 0) > 300 then
			Stats.trimAt = now
			for guid in pairs(ValueCache) do
				if inv[guid] == nil then
					ValueCache[guid] = nil
				end
			end
		end
		Stats.at, Stats.count, Stats.sellable, Stats.value, Stats.total = now, count, sellable, value, total
		return count, sellable, value, total
	end
	function N.backpack()
		local bp = N.sh("Services.Backpack")
		if type(bp) == "table" and type(bp.GetCap) == "function" then
			local ok, res = pcall(bp.GetCap, bp)
			if ok and type(res) == "table" and tonumber(res.Cap) then
				return tonumber(res.Count) or 0, tonumber(res.Cap)
			end
		end
		local n = 0
		for _ in pairs(N.inv()) do
			n += 1
		end
		return n, 2500
	end
	function N.itemsOf(kind)
		local out = {}
		for guid, item in pairs(N.inv()) do
			if type(item) == "table" and item.Type == kind then
				table.insert(out, { guid = guid, item = item })
			end
		end
		table.sort(out, function(a, b)
			return tostring(a.guid) < tostring(b.guid)
		end)
		return out
	end
	function N.char()
		return LocalPlayer.Character
	end
	function N.root()
		local char = LocalPlayer.Character
		return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
	end
	function N.humanoid()
		local char = LocalPlayer.Character
		return char and char:FindFirstChildOfClass("Humanoid")
	end
	function N.alive()
		local hum = N.humanoid()
		return hum ~= nil and hum.Health > 0 and N.root() ~= nil
	end
	function N.myPos()
		local root = N.root()
		return root and root.Position
	end
	function N.tp(pos)
		local char = LocalPlayer.Character
		local root = N.root()
		if not (char and root) then
			return false
		end
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
		end)
		return (pcall(function()
			char:PivotTo(CFrame.new(pos))
		end))
	end
	function N.goTo(pos, near, timeout)
		near = near or 6
		local root = N.root()
		if not root then
			return false
		end
		local function flat()
			local p = N.myPos() or pos
			return Vector3.new(p.X - pos.X, 0, p.Z - pos.Z).Magnitude
		end
		if flat() <= near then
			return true
		end
		if not N.safeMove() then
			for try = 1, 6 do
				N.tp(pos + Vector3.new(0, 3, 0))
				task.wait(0.3 + 0.1 * try)
				if flat() <= near then
					return true
				end
			end
			logProblem(string.format("Teleport did not land on the spot (%.0f studs off)", flat()))
			return false
		end
		local hum = N.humanoid()
		if not hum then
			return false
		end
		local started, sentAt, lastDist, lastAt = os.clock(), -1e9, flat(), os.clock()
		timeout = timeout or 30
		while os.clock() - started < timeout and alive() do
			if os.clock() - sentAt >= 2 then
				sentAt = os.clock()
				pcall(function()
					hum:MoveTo(pos)
				end)
			end
			local d = flat()
			if d <= near then
				return true
			end
			if lastDist - d > 1 then
				lastDist, lastAt = d, os.clock()
			elseif os.clock() - lastAt > 1.5 then
				lastAt = os.clock()
				pcall(function()
					hum.Jump = true
				end)
			end
			task.wait(0.1)
		end
		logProblem(string.format("Walk did not reach the spot (%.0f studs left). Movement Teleport skips walking", flat()))
		return false
	end
	function N.worldFolder()
		local root = workspace:FindFirstChild("World")
		if not root then
			return nil
		end
		local byName = root:FindFirstChild(N.worldKey()) or root:FindFirstChild(N.data().World or "")
		if byName then
			return byName
		end
		for _, child in ipairs(root:GetChildren()) do
			if child:FindFirstChild("Interactable") then
				return child
			end
		end
		return nil
	end
	function N.spot(name)
		local folder = N.worldFolder()
		local inter = folder and folder:FindFirstChild("Interactable")
		local inst = (inter and inter:FindFirstChild(name)) or (folder and folder:FindFirstChild(name, true))
		if not inst then
			return nil
		end
		local ok, pos = pcall(function()
			if inst:IsA("BasePart") then
				return inst.Position
			end
			return inst:GetPivot().Position
		end)
		return if ok then pos else nil
	end
	function N.holdTool(name)
		local char = N.char()
		if not char then
			return false
		end
		local held = char:FindFirstChildOfClass("Tool")
		if held and held.Name == name then
			return true
		end
		local bp = LocalPlayer:FindFirstChild("Backpack")
		local tool = bp and bp:FindFirstChild(name)
		local hum = N.humanoid()
		if not (hum and tool and tool:IsA("Tool")) then
			return false
		end
		pcall(function()
			hum:EquipTool(tool)
		end)
		return true
	end
	function N.holdItem(guid)
		send("EquipTool", guid, "Equip")
		task.wait(0.35)
	end
end
local Session = {
	started = os.clock(),
	casts = 0,
	perfect = 0,
	hooked = 0,
	caught = 0,
	castValue = 0,
	specials = 0,
	fights = 0,
	refused = 0,
	sold = 0,
	soldValue = 0,
	upgrades = 0,
	rods = 0,
	baits = 0,
	worlds = 0,
	claims = 0,
	codes = 0,
	opened = 0,
	potions = 0,
	relics = 0,
	pondTrips = 0,
	bigMouth = 0,
	enchants = 0,
	mutations = 0,
	best = 0,
	bestName = "-",
	cashStart = nil,
	levelStart = nil,
}
N.Events = {}
N.Fish = {
	cast = nil,
	last = "",
	engine = "-",
	canThrow = nil,
	refusals = {},
	fails = 0,
	fallbackUntil = 0,
	fallbackReason = "",
	cycle = 0,
	evCast = 0,
	af = nil,
	afTried = false,
	patched = nil,
	orig = {},
	paused = false,
	mode = "safe",
}
do
	local F = N.Fish
	N.Rate = { start = os.clock(), casts = 0, tSum = 0, best = 0, causes = {}, minutes = 0 }
	function N.rateCause(why)
		local R = N.Rate
		R.causes[why] = (R.causes[why] or 0) + 1
	end
	function N.rateCast(took)
		local R = N.Rate
		R.casts += 1
		R.tSum += tonumber(took) or 0
	end
	function N.rateTick()
		local R = N.Rate
		if os.clock() - R.start < 60 then
			return
		end
		local span = (os.clock() - R.start) / 60
		local perMin = R.casts / span
		local avgT = if R.casts > 0 then R.tSum / R.casts else 0
		log("RATE", "casts/min=" .. string.format("%.1f", perMin), "avg cast t=" .. string.format("%.1f", avgT), "best minute=" .. string.format("%.1f", R.best))
		if R.minutes >= 2 and R.best > 0 and perMin < 0.6 * R.best and (N.wants("AutoFish") or N.planner()) then
			local cause, count = "longer fights (avg cast " .. string.format("%.1f", avgT) .. " s)", 0
			for why, n in pairs(R.causes) do
				if n > count then
					cause, count = "pause: " .. why .. " x" .. n, n
				end
			end
			log("SLOW", "cause=" .. cause, "casts/min=" .. string.format("%.1f", perMin), "best=" .. string.format("%.1f", R.best))
		end
		R.minutes += 1
		R.best = math.max(R.best, perMin)
		R.start, R.casts, R.tSum, R.causes = os.clock(), 0, 0, {}
	end
	F.ladder = { phase = "measureSafe", mode = "safe", t0 = nil, w0 = 0, safe = nil, blat = nil, keep = "safe", falls = {}, dayOffUntil = 0, ratio = nil }
	local L = F.ladder
	local function modeChoice()
		return string.sub(optionText("FishMode", "Fast (default)"), 1, 4)
	end
	function N.fishMode()
		local c = modeChoice()
		if c == "Legi" or os.clock() < F.fallbackUntil or os.clock() < L.dayOffUntil then
			return "safe"
		end
		return "blatant"
	end
	function N.ladderTick() end
	function N.modeText()
		local c = modeChoice()
		if os.clock() < F.fallbackUntil then
			return "Fishing with the game's auto fishing (fast way paused " .. tostring(F.pauseText or "30 min") .. ": " .. F.fallbackReason .. ")"
		end
		if os.clock() < L.dayOffUntil then
			return "Fishing with the game's auto fishing (fast way off for the day)"
		end
		if c == "Legi" then
			return "Fishing with the game's auto fishing (your choice)"
		end
		return "Fishing at full speed"
	end
	function N.fallback(reason)
		if os.clock() < F.fallbackUntil then
			return
		end
		local now = os.clock()
		local pause = if #L.falls == 0 then 300 else 1800
		F.fallbackUntil = now + pause
		F.fallbackReason = reason
		F.pauseText = if pause >= 1800 then "30 min" else "5 min"
		L.phase, L.mode, L.keep = "cooldown", "safe", "safe"
		table.insert(L.falls, now)
		while #L.falls > 0 and now - L.falls[1] > 86400 do
			table.remove(L.falls, 1)
		end
		log("MODE fallback blatant -> safe", "reason=" .. tostring(reason), "retry in " .. F.pauseText, "falls today=" .. #L.falls)
		if #L.falls >= 3 then
			L.dayOffUntil = now + 86400
			log("MODE blatant off for the day", "falls=" .. #L.falls)
		end
		notify("Auto Fish", "Fast fishing paused for " .. F.pauseText .. " (" .. tostring(reason) .. "), using the game's auto fishing meanwhile", 6)
	end
	pcall(function()
		game:GetService("GuiService").ErrorMessageChanged:Connect(function(msg)
			if alive() and N.fishMode() == "blatant" and tostring(msg) ~= "" then
				N.fallback("client message: " .. string.sub(tostring(msg), 1, 60))
			end
		end)
	end)
	function N.hookCapRaw()
		local d = N.data()
		local U = N.sh("Config.UpgradesConfig")
		local cap = 3
		pcall(function()
			local key = U.KeyForData(d)
			local level = U.LevelOf(d, "Capacity", key)
			local W = N.sh("Config.WorldsConfig")
			local effect = (W.ForPlayerData(d).UpgradeEffect or 1)
			cap = U.CapacityValue(level, effect, key)
		end)
		pcall(function()
			cap += N.sh("Modules.Enchant").Add(d, "HookSlots") or 0
		end)
		return math.max(cap, 1)
	end
	function N.hookCap()
		local d = N.data()
		local U = N.sh("Config.UpgradesConfig")
		local cap = 3
		pcall(function()
			local key = U.KeyForData(d)
			local level = U.LevelOf(d, "Capacity", key)
			local W = N.sh("Config.WorldsConfig")
			local effect = (W.ForPlayerData(d).UpgradeEffect or 1)
			cap = U.CapacityValue(level, effect, key)
		end)
		pcall(function()
			cap += N.sh("Modules.Enchant").Add(d, "HookSlots") or 0
		end)
		local count, max = N.backpack()
		return math.max(math.min(cap, max - count), 0)
	end
	function N.fightRequired(name, boss)
		local CF = N.sh("Modules.CatchFight")
		if type(CF) ~= "table" or type(CF.Required) ~= "function" then
			return nil
		end
		local def = if boss then CF.Boss else N.fishDef(name)
		local ok, req = pcall(CF.Required, def)
		return if ok and type(req) == "number" and req > 0 then req else nil
	end
	function N.hookSeconds(name, boss)
		local req = N.fightRequired(name, boss)
		if N.fishMode() == "blatant" then
			return 0.11 + (if req then req / 10 + 0.15 else 0)
		end
		return 0.6 + (if req then req / 7 + 0.4 else 0)
	end
	function N.throwArea()
		local folder = N.worldFolder()
		local inter = folder and folder:FindFirstChild("Interactable")
		return inter and inter:FindFirstChild("Throw")
	end
	N.Dry = {}
	local function isWaterHit(hit)
		if not hit then
			return false
		end
		local wet = false
		pcall(function()
			if hit.Material == Enum.Material.Water then
				wet = true
				return
			end
			local node = hit.Instance
			for _ = 1, 4 do
				if not node then
					break
				end
				if string.find(string.lower(tostring(node.Name)), "water", 1, true) then
					wet = true
					return
				end
				node = node.Parent
			end
			wet = game:GetService("CollectionService"):HasTag(hit.Instance, "AnimatedWater") == true
		end)
		return wet
	end
	N.isWaterHit = isWaterHit
	local function rayDown(from, length, ignore)
		local ok, hit = pcall(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignore
			params.IgnoreWater = false
			return workspace:Raycast(from, Vector3.new(0, -length, 0), params)
		end)
		return if ok then hit else nil
	end
	N.rayDown = rayDown
	function N.wetHere()
		local hum = N.humanoid()
		local swimming = false
		pcall(function()
			swimming = hum ~= nil and hum:GetState() == Enum.HumanoidStateType.Swimming
		end)
		if swimming then
			return true
		end
		local pos = N.myPos()
		if not pos then
			return nil
		end
		local hit = rayDown(pos + Vector3.new(0, 8, 0), 20, { LocalPlayer.Character, N.throwArea() })
		if not hit then
			return nil
		end
		return isWaterHit(hit)
	end
	function N.dryPier()
		local key = N.worldKey()
		if N.Dry[key] then
			return N.Dry[key]
		end
		local area = N.throwArea()
		if not area then
			return nil
		end
		local ThrowArea = N.sh("Modules.ThrowArea")
		local best, bestScore, hits = nil, nil, 0
		pcall(function()
			local ignore = { LocalPlayer.Character, area }
			for _, box in ipairs(area:GetChildren()) do
				if box:IsA("BasePart") then
					local cf, size = box.CFrame, box.Size
					for i = -2, 2 do
						for j = -2, 2 do
							local top = cf * Vector3.new(size.X * 0.2 * i, size.Y / 2 + 40, size.Z * 0.2 * j)
							local hit = rayDown(top, size.Y + 90, ignore)
							if hit then
								hits += 1
								if not isWaterHit(hit) then
									local stand = hit.Position + Vector3.new(0, 3, 0)
									local inside = true
									if type(ThrowArea) == "table" and type(ThrowArea.IsInside) == "function" then
										local ok, yes = pcall(ThrowArea.IsInside, area, stand)
										inside = not ok or yes == true
									end
									local score = math.abs(i) + math.abs(j)
									if inside and (not best or score < bestScore) then
										best, bestScore = stand, score
									end
								end
							end
						end
					end
				end
			end
		end)
		if best then
			N.Dry[key] = best
			log("PIER dry spot", key, brief(best))
		elseif hits > 0 and N.due("pierNoDry" .. key, 600) then
			log("PIER no dry spot", key, "rays=" .. hits, "(using the area centre)")
		end
		return best
	end
	function N.pierPos()
		local area = N.throwArea()
		local part = area and (area:FindFirstChild("Part") or area:FindFirstChildWhichIsA("BasePart", true))
		if not part then
			return nil
		end
		local att = part:FindFirstChild("PierTutorialAttachment")
		if att and not F.attWet then
			local ok, pos = pcall(function()
				return att.WorldPosition
			end)
			if ok and pos then
				return pos
			end
		end
		return N.dryPier() or part.Position
	end
	function N.atPier()
		if F.canThrow == true then
			return true
		end
		local pos = N.myPos()
		local area = N.throwArea()
		if not (pos and area) then
			return false
		end
		local ThrowArea = N.sh("Modules.ThrowArea")
		if type(ThrowArea) == "table" and type(ThrowArea.IsInside) == "function" then
			local ok, inside = pcall(ThrowArea.IsInside, area, pos)
			if ok then
				return inside == true
			end
		end
		local part = area:FindFirstChild("Part")
		if part then
			local d, s = pos - part.Position, part.Size
			return math.abs(d.X) <= s.X / 2 + 2 and math.abs(d.Z) <= s.Z / 2 + 2 and math.abs(d.Y) <= s.Y / 2 + 6
		end
		return false
	end
	function N.goPier()
		if N.atPier() then
			return true
		end
		local pos = N.pierPos()
		if not pos then
			setStatus("Waiting for the pier to load")
			return false
		end
		setStatus("Going to the pier")
		N.goTo(pos, 3)
		return waitFor(N.atPier, 2)
	end
	function N.rodHeld()
		local char = N.char()
		local tool = char and char:FindFirstChildOfClass("Tool")
		return tool ~= nil and tool.Name == (N.data().RodEquipped or "Wooden Rod")
	end
	function N.equipRod()
		if N.rodHeld() then
			return true
		end
		N.holdTool(N.data().RodEquipped or "Wooden Rod")
		return waitFor(N.rodHeld, 1.5)
	end
	N.listen("ThrowRod", function(kind, a, b)
		local cast = F.cast
		if kind == "Started" and type(a) == "table" then
			F.lastSchool = a
			if not cast then
				Session.casts += 1
			end
			if cast and not cast.payload then
				cast.payload = a
				cast.startedAt = os.clock()
			end
		elseif kind == "Catch" then
			if cast and cast.payload then
				if a then
					cast.windowOpen = true
					cast.openedAt = os.clock()
				else
					cast.windowOpen = false
					cast.closed = true
				end
			end
		elseif kind == "Landed" then
			if cast and cast.payload then
				cast.landed = true
			end
		elseif kind == "Refused" then
			Session.refused += 1
			if cast then
				cast.refused = tostring(a)
			end
			log("THROW refused", tostring(a))
			local code = string.lower(tostring(a))
			if code == "swimming" or code == "not_in_area" or code == "left_area_on_release" then
				F.needDry = code
				F.canThrow = nil
				return
			elseif code == "bag_full" then
				N.undue("sellFull")
				return
			end
			local now = os.clock()
			table.insert(F.refusals, now)
			while #F.refusals > 0 and now - F.refusals[1] > 60 do
				table.remove(F.refusals, 1)
			end
			if N.fishMode() == "blatant" then
				if string.find(code, "flag", 1, true) or string.find(code, "suspect", 1, true) or string.find(code, "cheat", 1, true) then
					N.fallback("server answer " .. tostring(a))
				elseif #F.refusals >= 3 then
					N.fallback("server refused 3 casts in a minute")
				end
			end
		end
	end)
	N.listen("Fishing", function(kind)
		if kind == "Entered" then
			F.canThrow = true
		elseif kind == "Left" then
			F.canThrow = false
		end
	end)
	local function throwPower(rate)
		local perfect = math.random() < rate
		local p
		if perfect then
			p = 0.41 + math.random() * 0.12
		elseif math.random() < 0.5 then
			p = 0.15 + math.random() * 0.22
		else
			p = 0.58 + math.random() * 0.3
		end
		return p + (1 + math.random() * 8) * 1e-7, perfect
	end
	N.throwPower = throwPower
	function N.rankSchool(payload, cap)
		local school = type(payload.school) == "table" and payload.school or {}
		local sizes = type(payload.sizes) == "table" and payload.sizes or {}
		local muts = type(payload.mutations) == "table" and payload.mutations or {}
		local fish = {}
		for i, name in ipairs(school) do
			local boss = payload.boss == i
			local value = N.fishValue(name, sizes[i], muts[i]) * (if boss then 2 else 1)
			local index = N.tab("Index").Fish
			if on("IndexHunt") and type(index) == "table" and not index[name] then
				value = value * 1.5 + 1
			end
			if N.cargoBonus then
				value = N.cargoBonus(name, muts[i], value)
			end
			table.insert(fish, { index = i, name = name, value = value, fight = N.fightRequired(name, boss), boss = boss })
		end
		for idx, e in pairs(type(payload.extra) == "table" and payload.extra or {}) do
			local value = N.fishValue(e.name, e.size, e.mutation)
			if N.cargoBonus then
				value = N.cargoBonus(e.name, e.mutation, value)
			end
			table.insert(fish, { index = idx, name = e.name, value = value, fight = N.fightRequired(e.name, false), extra = true })
		end
		local rate = if N.planner() then N.incomeRate() else 0
		if rate > 1 then
			for _, f in ipairs(fish) do
				f.net = f.value - rate * N.hookSeconds(f.name, f.boss)
			end
		end
		table.sort(fish, function(x, y)
			local a, b = x.net or x.value, y.net or y.value
			if a ~= b then
				return a > b
			end
			return x.index < y.index
		end)
		local picks = {}
		for k, special in ipairs(type(payload.specials) == "table" and payload.specials or {}) do
			table.insert(picks, { index = #school + k, special = true, name = if type(special) == "table" then tostring(special.Name or special.name or "special") else tostring(special) })
		end
		for i = 1, math.min(cap, #fish) do
			local f = fish[i]
			if f.net and f.net <= 0 and not f.boss and #picks > 0 then
				break
			end
			table.insert(picks, f)
		end
		return picks, fish
	end
	function N.castOnce(blatant)
		local cast = { sentAt = os.clock(), blatant = blatant, hooked = {}, value = 0 }
		F.cast = cast
		local power, perfect = throwPower(math.clamp(optionNumber("PerfectRate", 60) / 100, 0, if blatant then 0.6 else 0.95))
		send("ThrowRod", power)
		Session.casts += 1
		if perfect then
			Session.perfect += 1
		end
		if not waitFor(function()
			return cast.payload ~= nil or cast.refused ~= nil
		end, 4) then
			F.fails += 1
			log("THROW no answer", "power=" .. string.format("%.2f", power), "fails=" .. F.fails)
			send("CancelThrow")
			F.cast = nil
			if F.fails >= 3 and blatant then
				N.fallback("3 casts without an answer")
			end
			task.wait(1)
			return false
		end
		if cast.refused then
			F.cast = nil
			task.wait(1.5)
			return false
		end
		F.fails = 0
		local p = cast.payload
		local cap = N.hookCap()
		if N.chargeStep then
			N.chargeStep(cast, p, cap)
			if cast.collectAll or cast.extra or cast.mutated then
				local q = table.clone(p)
				q.mutations = table.clone(type(p.mutations) == "table" and p.mutations or {})
				for idx, m in pairs(cast.mutated or {}) do
					if type(idx) == "number" and idx <= #(p.school or {}) then
						q.mutations[idx] = m
					elseif cast.extra and cast.extra[idx] then
						cast.extra[idx].mutation = m
					end
				end
				q.extra = cast.extra
				p = q
				cap = if cast.collectAll then 10000 else cap + (cast.capBonus or 0)
			end
		end
		local picks, fish = N.rankSchool(p, cap)
		if cast.collectAll then
			for _, pick in ipairs(picks) do
				if pick.fight and not pick.boss then
					pick.fight = nil
				end
			end
		end
		local waitOpen = (tonumber(p.arcDuration) or 2) + (tonumber(p.diveDuration) or 1) + (tonumber(p.holdDuration) or 0) + 12
		for _, b in ipairs(type(p.bounces) == "table" and p.bounces or {}) do
			waitOpen += tonumber(type(b) == "table" and b.Duration) or 0.5
		end
		if not waitFor(function()
			return cast.windowOpen or cast.closed
		end, waitOpen) then
			log("CAST no catch window", "throw=" .. tostring(p.throwId))
			F.noWindow = (F.noWindow or 0) + 1
			if blatant and F.noWindow >= 2 then
				N.fallback("2 casts without a catch window")
			end
		else
			F.noWindow = 0
		end
		local hookedList = {}
		local function hook(pick)
			if not cast.windowOpen or not alive() then
				return false
			end
			if pick.special then
				send("FishHooked", pick.index)
				Session.specials += 1
				log("SPECIAL", "k=" .. (pick.index - #(p.school or {})), "item=" .. tostring(pick.name))
				local EggC = N.sh("Content.Item.Egg")
				if EggC and type(EggC.Items) == "table" and EggC.Items[pick.name] then
					log("EGG hooked", tostring(pick.name), "via=" .. (if N.whaleWindow and N.whaleWindow() then "whale" else "cast"))
				end
			elseif pick.fight then
				send("FishHooked", pick.index, "fight", nil, true)
				Session.fights += 1
				task.wait(pick.fight / (if blatant then 10 else 7) + 0.15)
				send("FishHooked", pick.index, "won", pick.fight + math.random(0, 2))
			else
				send("FishHooked", pick.index)
			end
			cast.hooked[pick.index] = true
			table.insert(hookedList, pick.index)
			if not pick.special then
				cast.value += pick.value or 0
			end
			return true
		end
		if cast.windowOpen then
			task.wait(if blatant then 0.05 + math.random() * 0.1 else 0.6 + math.random() * 0.5)
			local fights = {}
			for _, pick in ipairs(picks) do
				if pick.fight then
					table.insert(fights, pick)
				elseif hook(pick) then
					task.wait(if blatant then 0.08 + math.random() * 0.05 else 0.35 + math.random() * 0.35)
				end
			end
			for _, pick in ipairs(fights) do
				if hook(pick) then
					task.wait(if blatant then 0.1 else 0.4 + math.random() * 0.3)
				end
			end
			local fishHooked = 0
			for _, pick in ipairs(picks) do
				if not pick.special and cast.hooked[pick.index] then
					fishHooked += 1
				end
			end
			if cast.windowOpen and (blatant or (cap > 0 and fishHooked >= cap)) then
				send("ReelBait", true)
			end
		end
		local landWait = (tonumber(p.pullUpDuration) or 10) + (tonumber(p.returnDuration) or 2) + 20
		if not waitFor(function()
			return cast.landed == true
		end, landWait) then
			log("CAST no landing", "throw=" .. tostring(p.throwId))
			F.cast = nil
			return false
		end
		task.wait(if blatant then 0.05 else 0.2 + math.random() * 0.3)
		local fishCount = 0
		local nSchool, nSpecial = #(p.school or {}), #(type(p.specials) == "table" and p.specials or {})
		for _, idx in ipairs(hookedList) do
			if idx <= nSchool or idx > nSchool + nSpecial then
				fishCount += 1
			end
		end
		if #hookedList > 0 then
			send("FishCaught", p.throwId, hookedList, false)
		end
		local took = os.clock() - cast.sentAt
		Session.hooked += #hookedList
		Session.caught += fishCount
		Session.castValue += cast.value
		if cast.value > Session.best and fish[1] then
			Session.best = cast.value
		end
		if fish[1] and fish[1].value > 0 and cast.hooked[fish[1].index] and (tonumber(fish[1].value) or 0) >= (Session.bestFish or 0) then
			Session.bestFish = fish[1].value
			Session.bestName = fish[1].name
		end
		F.cycle = if F.cycle > 0 then F.cycle * 0.8 + took * 0.2 else took
		F.evCast = if F.evCast > 0 then F.evCast * 0.8 + cast.value * 0.2 else cast.value
		F.last = string.format("%d fish + %d finds, %s coins, %.1f s", fishCount, #hookedList - fishCount, formatNumber(cast.value), took)
		log(
			"CAST",
			"id=" .. tostring(p.throwId),
			"mode=" .. (if blatant then "blatant" else "safe-direct"),
			"perfect=" .. tostring(perfect),
			"school=" .. #(p.school or {}),
			"cap=" .. cap,
			"best=" .. formatNumber(fish[1] and fish[1].value or 0),
			"took=" .. formatNumber(cast.value),
			"hooks=" .. #hookedList,
			"t=" .. string.format("%.1f", took)
		)
		if N.Events.cast then
			pcall(N.Events.cast, fish[1], cast.hooked)
		end
		N.rateCast(took)
		F.cast = nil
		return true
	end
	local function findAutoFishing()
		if F.af or F.afTried then
			return F.af
		end
		F.afTried = true
		local node = LocalPlayer:FindFirstChild("PlayerScripts")
		for _, part in ipairs({ "Client", "Controllers", "Fishing", "AutoFishing" }) do
			node = node and node:FindFirstChild(part)
		end
		if not (node and node:IsA("ModuleScript")) then
			log("FISH engine", "game auto fishing not found, Safe uses the legit remote pace")
			return nil
		end
		local result, done = nil, false
		task.spawn(function()
			local ok, mod = pcall(require, node)
			result = ok and type(mod) == "table" and mod or nil
			done = true
		end)
		waitFor(function()
			return done
		end, 5)
		if result and type(rawget(result, "SetOn")) == "function" and type(rawget(result, "PickTarget")) == "function" then
			F.af = result
			log("FISH engine", "game auto fishing found")
		else
			log("FISH engine", "game auto fishing unusable, Safe uses the legit remote pace")
		end
		return F.af
	end
	N.findAutoFishing = findAutoFishing
	local function patch(AF)
		if F.patched == AF then
			return
		end
		F.orig = { PickTarget = rawget(AF, "PickTarget"), Boost = rawget(AF, "Boost") }
		F.patched = AF
		AF.PickTarget = function(self, list, hangY)
			if not (alive() and N.wants("AutoFish")) then
				return F.orig.PickTarget(self, list, hangY)
			end
			local best, bestScore
			for _, f in ipairs(list) do
				local okValid, valid = pcall(self.TargetValid, self, f, hangY)
				if okValid and valid then
					local score = if f.special then math.huge else N.fishValue(f.name, f.size, f.mutation or f.pendingMutation)
					if not best or score > bestScore then
						best, bestScore = f, score
					end
				end
			end
			return best
		end
		AF.Boost = function(self)
			if alive() and N.wants("AutoFish") then
				return math.clamp(optionNumber("PerfectRate", 60) / 100, 0, 0.95)
			end
			return F.orig.Boost(self)
		end
		log("FISH patched", "target=best value", "perfect=" .. math.floor(optionNumber("PerfectRate", 60)) .. "%")
	end
	function N.unpatch()
		local AF = F.patched
		if AF then
			pcall(function()
				if AF.On then
					AF:SetOn(false)
				end
			end)
			AF.PickTarget = F.orig.PickTarget
			AF.Boost = F.orig.Boost
			F.patched = nil
			log("FISH unpatched")
		end
	end
	function N.pauseFishing(why)
		F.paused = true
		N.rateCause(tostring(why))
		if why and N.streakHoldOn then
			N.streakHoldOn(why)
		end
		local AF = F.patched
		if AF and AF.On then
			pcall(AF.SetOn, AF, false)
		end
		waitFor(function()
			if F.cast then
				return false
			end
			local tc = AF and AF.Controllers and AF.Controllers.ThrowCinematic
			return not (tc and tc.Active)
		end, 40)
		if why then
			log("FISH pause", why)
		end
	end
	function N.resumeFishing()
		F.paused = false
		if N.streakHoldOff then
			N.streakHoldOff()
		end
	end
	N.Tut = { at = -1e9, sentStep = nil, guarded = nil, dropped = 0, droppedAt = -1e9, released = false }
	local tutorialOnce
	function N.tutorialHold()
		local cur = tonumber(N.data().Tutorial) or -1
		return on("TutorialHold") and not N.Tut.released and cur < 100 and cur <= 6
	end
	function N.tutorialDecide()
		local cur = tonumber(N.data().Tutorial) or -1
		if not on("TutorialHold") then
			N.Tut.released = false
			return
		end
		if cur >= 100 or cur > 6 then
			if N.due("tutNa", 3600) then
				log("TUTORIAL hold", "n/a", "reason=" .. (if cur >= 100 then "the account finished the tutorial, step 6 cannot be reached again" else "step " .. cur .. " is past the x2 luck step"))
			end
			return
		end
		if cur ~= 6 or N.Tut.released or not N.planner() or not N.due("tutDecide", 300) then
			return
		end
		local perHour = N.Econ.rate * 3600
		local ev = N.Fish.evCast
		if perHour <= 0 or ev <= 0 then
			return
		end
		local P = N.sh("Config.PlaytimeGiftConfig")
		local giftSeconds, giftCasts = 0, 0
		pcall(function()
			for _, stage in ipairs(P.Stages) do
				giftSeconds += tonumber(stage.Duration) or 0
				for _, reward in ipairs(stage.Rewards or {}) do
					giftCasts += tonumber(reward.Casts) or 0
				end
			end
		end)
		if giftSeconds <= 0 then
			giftSeconds, giftCasts = 2400, 88
		end
		local left = 24 - ((os.clock() - Session.started) / 3600) % 24
		local holdValue = 0.5 * perHour * left
		local finishValue = giftCasts * ev + 0.1 * perHour * left
		local canFinish = left * 3600 > giftSeconds + 600
		local text = string.format("x2 luck +50%% = %s over %.1f h vs gift %d casts + quests/scrolls = %s%s", formatNumber(holdValue), left, giftCasts, formatNumber(finishValue), if canFinish then "" else " (the gift no longer fits the window)")
		if canFinish and finishValue > holdValue then
			N.Tut.released = true
			log("TUTORIAL finish", "reason=" .. text)
		elseif N.due("tutHoldLog", 1800) then
			log("TUTORIAL hold", "reason=" .. text)
		end
	end
	function N.tutorialGuard()
		if N.Tut.guarded then
			return true
		end
		local obj = N.event("Tutorial")
		if not obj then
			return false
		end
		local ok = pcall(function()
			local fire = obj.Fire
			obj.Fire = function(self, reliable, n, ...)
				if type(n) == "number" and n > 6 and N.tutorialHold() then
					N.Tut.dropped += 1
					if os.clock() - N.Tut.droppedAt > 60 then
						N.Tut.droppedAt = os.clock()
						log("TUTORIAL hold", "dropped step " .. tostring(n), "(x2 luck stays)")
					end
					return
				end
				return fire(self, reliable, n, ...)
			end
		end)
		N.Tut.guarded = ok or nil
		if ok then
			log("TUTORIAL guard on", "steps above 6 are held back while Tutorial hold is on")
		end
		return ok
	end
	function N.tutorialStep()
		if N.tutorialHold() then
			N.tutorialGuard()
			if N.due("tutHoldPlan", 1800) then
				log("PLAN tutorial", "hold=on", "step=" .. tostring(N.data().Tutorial), "value=x2 luck, x1.3 distance per cast", "cost=no playtime gifts, quests or guaranteed scrolls")
			end
		end
		for _ = 1, 3 do
			if not tutorialOnce() then
				return
			end
			task.wait(2.5)
		end
	end
	function tutorialOnce()
		local cur = tonumber(N.data().Tutorial) or -1
		if cur >= 100 or cur >= 8 then
			return false
		end
		if cur >= 6 and N.tutorialHold() then
			return false
		end
		local nextStep = math.max(cur + 1, 1)
		local caught = math.max(Session.caught, tonumber(N.tab("Stats").FishCaught) or 0)
		local waited = os.clock() - N.Tut.at
		local ready = ({
			[1] = true,
			[2] = N.atPier(),
			[3] = Session.casts >= 1,
			[4] = caught >= 1,
			[5] = Session.sold >= 1 or waited > 90,
			[6] = (tonumber(N.tab("Upgrades").Strength) or 0) >= 1 or waited > 90,
			[7] = caught >= 3 or waited > 90,
			[8] = waited > 20,
		})[nextStep]
		if nextStep == 6 and (tonumber(N.tab("Upgrades").Strength) or 0) < 1 then
			local U = N.sh("Config.UpgradesConfig")
			local price = U and U.GetPrice and U.GetPrice("Strength", 0) or math.huge
			if N.cash() >= price then
				send("Upgrades", "Buy", "Strength")
				log("TUTORIAL buy Strength", formatNumber(price))
				task.wait(1)
				ready = true
			end
		end
		if nextStep == 8 and not N.tab("Rods")["Iron Rod"] and N.cash() >= 5000 then
			send("RodShop", "Buy", "Iron Rod")
			task.wait(0.5)
			send("RodShop", "Equip", "Iron Rod")
			log("TUTORIAL buy Iron Rod")
		end
		if ready and waited > 2 then
			N.Tut.at = os.clock()
			send("Tutorial", nextStep)
			log("TUTORIAL step", nextStep)
			return true
		end
		return false
	end
	function N.fishStep()
		N.ladderTick()
		F.mode = N.fishMode()
		if F.paused then
			task.wait(0.3)
			return
		end
		local count, max = N.backpack()
		if max - count < N.hookCapRaw() then
			if N.wants("SmartSell") and N.due("sellFull", if N.Sell.needNpc then 20 else 6) then
				local _, sellable = N.fishStats(true)
				if sellable > 0 then
					N.sellNow(string.format("backpack %d/%d before the cast", count, max))
					count, max = N.backpack()
				end
			end
			if count >= max then
				N.pauseFishing("backpack full")
				F.paused = false
				if N.wants("SmartSell") then
					N.planIdle("backpack full of protected fish", "Backpack full of kept fish: unlock some or shorten the Keep lists")
				else
					setStatus("Backpack full: Smart Sell or Sell Now makes room")
				end
				task.wait(2)
				return
			end
		end
		if (N.data().World and N.worldCfg() and N.worldCfg().NoFishing) then
			setStatus("In a world without fishing, going back")
			N.travel(N.bestFishingWorld())
			return
		end
		if not N.goPier() then
			if not N.pierPos() then
				N.planIdle("pier not loaded in " .. N.worldKey(), "Waiting for the pier to load")
			else
				N.planIdle("could not reach the pier", "Going to the pier")
			end
			task.wait(1)
			return
		end
		if F.needDry or (N.due("wetCheck", 3) and N.wetHere() == true) then
			local why = F.needDry or "water under the character"
			F.needDry = nil
			N.Dry[N.worldKey()] = nil
			F.attWet = true
			local spot = N.dryPier()
			local pos = N.myPos()
			local moving = spot ~= nil and pos ~= nil and (spot - pos).Magnitude > 3
			if moving or N.due("wetLog", 60) then
				log("MOVE wet -> dry", N.worldKey(), "reason=" .. tostring(why), "spot=" .. (if spot then brief(spot) else "none found, area centre"))
			end
			if moving then
				N.goTo(spot, 3)
				F.canThrow = nil
				task.wait(0.3)
				return
			end
			if not spot and N.due("wetNoSpot", 30) then
				local area = N.throwArea()
				local part = area and (area:FindFirstChild("Part") or area:FindFirstChildWhichIsA("BasePart", true))
				if part then
					N.goTo(part.Position + Vector3.new(0, 3, 0), 3)
				end
			end
		end
		if not N.equipRod() then
			N.planIdle("rod " .. tostring(N.data().RodEquipped) .. " not in the backpack", "Equipping the rod")
			task.wait(1)
			return
		end
		N.tutorialDecide()
		if (tonumber(N.data().Tutorial) or -1) < 100 then
			N.tutorialStep()
		end
		if not F.rareCutscene and N.ready() then
			F.rareCutscene = true
			if N.tab("Settings").RareCutscene ~= "None" then
				send("Settings", "RareCutscene", "None")
				log("SETTING", "RareCutscene=None", "(a rare catch no longer holds the next cast for 4-7 s)")
			end
		end
		if N.data().IsInGroup and not F.doubleSpeed then
			F.doubleSpeed = true
			send("DoubleSpeed", true)
			log("FISH double speed on (group member)")
		end
		if F.mode == "safe" then
			local AF = findAutoFishing()
			if AF then
				F.engine = "game"
				patch(AF)
				if not AF.On then
					local ok, err = pcall(AF.SetOn, AF, true)
					log("FISH safe", "game auto fishing on", if ok then "" else tostring(err))
				end
				setStatus("Fishing: the game's auto fishing, aimed at the best fish")
				if N.due("safeStats", 300) then
					local caught = tonumber(N.tab("Stats").FishCaught) or 0
					F.caughtBase = F.caughtBase or caught
					log("FISH safe stats", "casts=" .. Session.casts, "caught=" .. (caught - F.caughtBase), "income/h=" .. formatNumber(N.Econ.rate * 3600), "perfect=" .. math.floor(optionNumber("PerfectRate", 60)) .. "%")
				end
				task.wait(1)
				return
			end
			F.engine = "remote-legit"
			setStatus("Fishing at the game's own pace")
			N.castOnce(false)
			task.wait(1.5 + math.random())
			return
		end
		if F.patched and F.patched.On then
			N.pauseFishing("switching to Blatant")
			F.paused = false
		end
		if not F.afOffChecked then
			F.afOffChecked = true
			local AF = findAutoFishing()
			if AF and AF.On then
				pcall(AF.SetOn, AF, false)
				log("FISH game auto fishing was on, switched off (Blatant casts by itself, no catch animation)")
			end
		end
		F.engine = "remote-blatant"
		setStatus("Fishing: best fish of every school, instant reel")
		N.castOnce(true)
		task.wait(0.15 + math.random() * 0.15)
	end
	function N.fishOff()
		if F.patched then
			N.unpatch()
		end
	end
end
N.Reward = { log = {}, last = "", seasonHold = {}, hold = {} }
N.Notes = { list = {} }
do
	local function plain(text)
		return (string.gsub(string.gsub(tostring(text or ""), "<[^>]->", ""), "%s+", " "))
	end
	task.spawn(function()
		local ok, remote = pcall(function()
			return ReplicatedStorage:WaitForChild("Shared", 15):WaitForChild("Utils", 15):WaitForChild("Notification", 15):WaitForChild("RemoteEvent", 15)
		end)
		if not (ok and typeof(remote) == "Instance" and remote:IsA("RemoteEvent")) then
			log("NO REMOTE", "notification listener")
			return
		end
		local conn = remote.OnClientEvent:Connect(function(payload)
			if not alive() then
				return
			end
			local text = plain(if type(payload) == "table" then payload.Text else payload)
			if text ~= "" and text ~= "nil" then
				local list = N.Notes.list
				table.insert(list, { at = os.clock(), text = text })
				if #list > 60 then
					table.remove(list, 1)
				end
			end
		end)
		pcall(function()
			Library:GiveSignal(conn)
		end)
	end)
	function N.noteSince(t0, pattern)
		local list = N.Notes.list
		for i = #list, 1, -1 do
			local n = list[i]
			if n.at < t0 then
				break
			end
			if not pattern or string.find(string.lower(n.text), pattern, 1, true) then
				return n.text
			end
		end
		return nil
	end
end
do
	local R = N.Reward
	local function remember(what)
		Session.claims += 1
		table.insert(R.log, 1, os.date("%H:%M") .. "  " .. what)
		while #R.log > 6 do
			table.remove(R.log)
		end
		R.last = what
	end
	local function claimed(what)
		remember(what)
		log("REWARD", what)
	end
	N.claimed = claimed
	local function verify(key, what, done, seconds, holdSeconds)
		local t0 = os.clock()
		local ok = waitFor(done, seconds or 3)
		if ok and not N.noteSince(t0) then
			waitFor(function()
				return N.noteSince(t0) ~= nil
			end, 1)
		end
		local note = N.noteSince(t0)
		if ok then
			remember(what)
			log("REWARD", what, "ok", if note then "note=" .. note else "(data changed, no notice)")
			R.hold[key] = nil
		else
			R.hold[key] = os.clock() + (holdSeconds or 600)
			log("REWARD FAILED", what, "answer=" .. (if note then note else "no data change"), "(retry in " .. N.longTime(holdSeconds or 600) .. ")")
		end
		return ok
	end
	N.verifyClaim = verify
	local function held(key)
		return os.clock() < (R.hold[key] or 0)
	end
	local function cfg(name)
		local c = N.sh("Config." .. name)
		return if type(c) == "table" then c else nil
	end
	local function call(f, ...)
		if type(f) ~= "function" then
			return false, nil
		end
		return pcall(f, ...)
	end
	local function count(t)
		local n = 0
		for _ in pairs(type(t) == "table" and t or {}) do
			n += 1
		end
		return n
	end
	function N.rewardStep()
		if not N.wants("AutoRewards") then
			return
		end
		local d = N.data()
		local now = N.serverTime()
		local dr = d.DailyRewards
		if type(dr) ~= "table" then
			if N.due("dailySync", 120) then
				send("DailyRewards", "Sync")
			end
		elseif not held("daily") and N.due("daily", 30) then
			local c = cfg("DailyRewardsConfig")
			local ok, can = call(c and c.CanClaim, dr, now)
			if ok and can then
				local before = tonumber(dr.Claimed) or 0
				local from, to = before + 1, math.max(tonumber(dr.Unlocked) or 1, before + 1)
				send("DailyRewards", "Claim", to)
				verify("daily", if to > from then string.format("Daily rewards days %d-%d (catch-up)", from, to) else "Daily reward day " .. from, function()
					local x = N.data().DailyRewards
					return type(x) == "table" and (tonumber(x.Claimed) or 0) > before
				end, 4)
				return
			end
		end
		if not held("claimable") and N.due("claimable", 60) then
			local c = cfg("DailyClaimableConfig")
			local ok, state = call(c and c.State, d.DailyClaimable, now)
			if ok and (state == "Free" or state == "Stale" or state == "Again") then
				send("DailyClaimable", "Claim")
				verify("claimable", "Free daily roll", function()
					local fine, after = call(c.State, N.data().DailyClaimable, N.serverTime())
					return fine and (after == "Ad" or after == "Done")
				end, 4)
				return
			elseif not ok and N.due("claimableSync", 600) then
				send("DailyClaimable", "Sync")
			end
		end
		local stage = tonumber(d.PlaytimeGiftStage) or 0
		local readyAt = tonumber(d.PlaytimeGiftReadyAt) or 0
		local statsPlayed = tonumber(N.tab("Stats").SecondsPlayed) or 0
		R.playBase = R.playBase or statsPlayed
		R.playBaseAt = R.playBaseAt or os.clock()
		local played = math.max(statsPlayed, R.playBase + (os.clock() - R.playBaseAt))
		local hold = false
		local P = N.Plan
		if stage == 2 and N.planner() and P and type(P.need) == "table" and P.need.kind == "world" and P.need.name ~= "Pond" and (tonumber(P.eta) or 99) <= 0.5 then
			hold = true
			if R.heldFor ~= P.need.name then
				R.heldFor = P.need.name
				log("REWARD hold", "playtime gift 3 (70 casts) until " .. tostring(P.need.name), "eta=" .. string.format("%.2f h", tonumber(P.eta) or 0))
			end
		end
		if not hold and stage >= 1 and readyAt > 0 and played >= readyAt and not held("playtime") and N.due("playtime", 90) then
			send("PlaytimeGift", "Claim")
			verify("playtime", "Playtime gift " .. stage, function()
				local s = tonumber(N.data().PlaytimeGiftStage) or 0
				return s ~= stage
			end, 4, 300)
			return
		end
		local nd = cfg("NextDayRewardConfig")
		local wait = tonumber(nd and nd.WaitSeconds) or 43200
		local at = tonumber(d.NextDayRewardAt) or 0
		if not d.IsNextDayRewardClaimed and at > 0 and now - at >= wait and not held("nextDay") and N.due("nextDay", 60) then
			send("NextDayReward")
			verify("nextDay", "Next day reward", function()
				return N.data().IsNextDayRewardClaimed == true
			end, 4)
			return
		end
		if N.due("season", 3) then
			local c = cfg("SeasonConfig")
			local s = d.Season
			if c and type(s) == "table" and s.Id == c.Id then
				local okDay, day = call(c.DayNumber, now)
				local okXp, more = call(c.XPClaimable, tonumber(s.XP) or 0, now)
				local canXp = not okXp or more ~= false
				local action
				if okDay and day ~= nil and s.GiftDay ~= day and canXp and not held("seasongift" .. tostring(day)) then
					action = { key = "seasongift" .. tostring(day), args = { "Gift" }, text = "Season daily gift", done = function(x)
						return x.GiftDay == day
					end }
				end
				local quests = type(s.Quests) == "table" and s.Quests or {}
				for i = 1, tonumber(c.DAILY_QUESTS) or 3 do
					local q = quests["Q" .. i]
					local def = type(q) == "table" and type(c.Quests) == "table" and c.Quests[q.Id] or nil
					local finished = type(q) == "table" and (q.Done == true or (def ~= nil and (tonumber(q.Progress) or 0) >= (tonumber(def.Goal) or math.huge)))
					local key = "seasonquest" .. i .. tostring(q and q.Id) .. tostring(day)
					if not action and finished and not q.Claimed and canXp and not held(key) then
						action = { key = key, args = { "Quest", "Q" .. i }, text = "Season quest " .. tostring(def and def.Text or q.Id or i), done = function(x)
							local qq = type(x.Quests) == "table" and x.Quests["Q" .. i]
							return type(qq) == "table" and qq.Claimed == true
						end }
					end
				end
				local okTier, tier = call(c.TierFromXP, tonumber(s.XP) or 0)
				local free = type(s.Free) == "table" and s.Free or {}
				local paid = type(s.Paid) == "table" and s.Paid or {}
				for t = 1, (if okTier then tonumber(tier) or 0 else 0) do
					if not action and not free["T" .. t] and not held("seasontier" .. t) then
						action = { key = "seasontier" .. t, args = { "Claim", "Free", t }, text = "Season tier " .. t, done = function(x)
							return type(x.Free) == "table" and x.Free["T" .. t] == true
						end }
					end
					if not action and s.Premium == true and not paid["T" .. t] and not held("seasonpaid" .. t) then
						action = { key = "seasonpaid" .. t, args = { "Claim", "Premium", t }, text = "Season Golden Line tier " .. t, done = function(x)
							return type(x.Paid) == "table" and x.Paid["T" .. t] == true
						end }
					end
				end
				if action then
					send("Season", table.unpack(action.args))
					verify(action.key, action.text, function()
						local x = N.data().Season
						return type(x) == "table" and action.done(x)
					end, 3)
					return
				end
			end
		end
		if N.due("achievements", 45) then
			local c = cfg("AchievementConfig")
			if c and type(c.Order) == "table" then
				for _, item in ipairs(c.Order) do
					local key = "ach" .. tostring(item.Key)
					local ok, can = call(c.CanClaim, item, d)
					if ok and can and not held(key) then
						local function tiers()
							local fine, n = call(c.Claimed, item, N.data())
							if fine and tonumber(n) then
								return tonumber(n)
							end
							local a = N.tab("Achievements")
							return tonumber(type(a.Claimed) == "table" and a.Claimed[item.Key]) or 0
						end
						local before = tiers()
						send("Achievement", "Claim", item.Key)
						verify(key, "Achievement " .. tostring(item.Key) .. " tier " .. (before + 1), function()
							return tiers() > before
						end, 4)
						return
					end
				end
			end
		end
		local inbox = count(d.GiftInbox)
		if inbox > 0 and not held("inbox") and N.due("inbox", 30) then
			send("AdminGift", "ClaimAll")
			verify("inbox", "Gift inbox: " .. inbox .. " gift" .. (if inbox == 1 then "" else "s"), function()
				return count(N.data().GiftInbox) < inbox
			end, 5)
			return
		end
		if d.IsInGroup and not d.IsGroupRewardClaimed and not held("group") and N.due("group", 60) then
			send("GroupReward")
			verify("group", "Group reward", function()
				return N.data().IsGroupRewardClaimed == true
			end, 4)
			return
		end
		local ref = type(d.Referral) == "table" and d.Referral or {}
		local friend = tonumber(ref.LinkedWithUserId) or 0
		if friend ~= 0 and not ref.IsClaimed and (tonumber(N.tab("Stats").SecondsPlayed) or 0) >= 900 and Players:GetPlayerByUserId(friend) and not held("referral") and N.due("referral", 120) then
			send("Referral", "Claim")
			verify("referral", "Referral reward", function()
				local x = N.data().Referral
				return type(x) == "table" and x.IsClaimed == true
			end, 4)
			return
		end
		local cb = cfg("ComebackConfig")
		local okCb, canCb = call(cb and cb.CanClaim, d, now)
		if okCb and canCb and not held("comeback") and N.due("comeback", 60) then
			local stageBefore = tonumber(d.ComebackStage) or 0
			send("Comeback", "Claim")
			verify("comeback", "Comeback day " .. stageBefore, function()
				local x = N.data()
				return (tonumber(x.ComebackStage) or 0) ~= stageBefore
			end, 4)
			return
		end
		local el = cfg("EarlyLeaveRewardConfig")
		local okRun, canRun = call(el and el.CanRun, d)
		if okRun and canRun and N.due("earlySeen", 300) then
			send("EarlyLeaveReward", "Seen")
			return
		end
		local okEl, canEl = call(el and el.CanClaim, d)
		if okEl and canEl and not held("early") and N.due("early", 120) then
			send("EarlyLeaveReward", "Claim")
			verify("early", "Early leave reward", function()
				return N.data().IsEarlyLeaveRewardClaimed == true
			end, 4)
			return
		end
		local waiting = tonumber(d.OfflineReward) or 0
		local OC = cfg("OfflineConfig")
		local batch = math.max((tonumber(OC and OC.NotifyOver) or 10) - 1, 1)
		if waiting >= batch and not held("offline") and N.due("offline", 120) then
			send("Offline")
			verify("offline", "Offline net " .. formatNumber(waiting) .. " fish", function()
				return (tonumber(N.data().OfflineReward) or 0) < waiting
			end, 4, 300)
			return
		end
	end
	N.Codes = {
		known = { "update10", "update9", "volcano", "boats", "sunkencrown", "update8", "keys", "kraken", "update7", "pond", "update4", "skins" },
		tried = {},
		results = {},
		last = "-",
		queue = {},
	}
	local C = N.Codes
	local CodeFile = "Jiro/FISH_codes_" .. tostring(LocalPlayer.UserId) .. ".txt"
	pcall(function()
		if isfile(CodeFile) then
			for code in string.gmatch(readfile(CodeFile), "[^\n]+") do
				C.tried[code] = true
			end
		end
	end)
	local function saveTried()
		pcall(function()
			if makefolder and isfolder and not isfolder("Jiro") then
				makefolder("Jiro")
			end
			local list = {}
			for code in pairs(C.tried) do
				table.insert(list, code)
			end
			table.sort(list)
			writefile(CodeFile, table.concat(list, "\n"))
		end)
	end
	local function norm(code)
		return string.lower((string.gsub(tostring(code or ""), "[^%w]", "")))
	end
	N.listen("Codes", function(status, a, b)
		local text = tostring(status)
		C.last = text .. (if a ~= nil then " " .. tostring(a) else "")
		C.results[C.pending or "?"] = text
		log("CODE result", tostring(C.pending), text, brief(a), brief(b))
		if N.Events.code and C.pending then
			pcall(N.Events.code, C.pending, text)
		end
	end)
	function N.redeemCode(code)
		code = norm(code)
		if code == "" then
			return
		end
		C.pending = code
		C.tried[code] = true
		saveTried()
		send("Codes", code)
		Session.codes += 1
	end
	function N.redeemAllCodes()
		for _, code in ipairs(C.known) do
			table.insert(C.queue, code)
		end
	end
	function N.codeCounts()
		local redeemed, tried = 0, 0
		local have = N.tab("Codes")
		for _ in pairs(C.tried) do
			tried += 1
		end
		for _ in pairs(have) do
			redeemed += 1
		end
		return redeemed, tried
	end
	function N.codeStep()
		local d = N.data()
		if N.wants("AutoCodes") and N.due("codeScan", 30) then
			local have = N.tab("Codes")
			for _, code in ipairs(C.known) do
				if not have[code] and not C.tried[code] and not table.find(C.queue, code) then
					table.insert(C.queue, code)
				end
			end
			if type(d.SecretCode) == "string" and d.SecretCode ~= "" and not d.SecretCodeRedeemed and not C.tried["secret:" .. d.SecretCode] then
				C.tried["secret:" .. d.SecretCode] = true
				table.insert(C.queue, d.SecretCode)
				log("CODE secret code from the signs queued")
			end
		end
		if #C.queue > 0 and N.due("codeSend", 6) then
			N.redeemCode(table.remove(C.queue, 1))
		end
	end
	N.Items = { last = "-", openedNames = {}, fails = {} }
	local I = N.Items
	local function unitsOf(guid)
		local item = N.inv()[guid]
		if type(item) ~= "table" then
			return 0
		end
		return math.max(tonumber(type(item.Data) == "table" and item.Data.Amount) or 1, 1)
	end
	N.unitsOf = unitsOf
	function N.holdAndWait(guid, seconds)
		N.holdItem(guid)
		return waitFor(function()
			local char = N.char()
			local tool = char and char:FindFirstChildOfClass("Tool")
			return tool ~= nil and tool.Name == guid
		end, seconds or 2)
	end
	local function useHeld(remote, kind, guid, name, what)
		local before = unitsOf(guid)
		N.pauseFishing()
		N.holdAndWait(guid, 2)
		local t0 = os.clock()
		send(remote, "Open", guid)
		local ok = waitFor(function()
			return unitsOf(guid) < before
		end, 3)
		local note = N.noteSince(t0)
		if ok then
			Session.opened += 1
			I.last = what .. " " .. name
			I.fails[guid] = nil
			log("OPEN", kind, name, "ok", if note then "note=" .. note else "")
		else
			I.fails[guid] = (I.fails[guid] or 0) + 1
			log("OPEN FAILED", kind, name, "answer=" .. (if note then note else "still in the backpack"), "try=" .. I.fails[guid])
		end
		return ok
	end
	function N.potionKey(name)
		local PC = N.sh("Config.PotionConfig")
		if type(PC) == "table" and type(PC.KeyForItem) == "function" then
			local ok, key = pcall(PC.KeyForItem, name)
			if ok and type(key) == "string" then
				return key
			end
		end
		return (string.gsub(tostring(name), " Potion$", ""))
	end
	local function potionLeft(name)
		local key = N.potionKey(name)
		local PC = N.sh("Config.PotionConfig")
		if type(PC) == "table" and type(PC.Remaining) == "function" then
			local ok, left = pcall(PC.Remaining, N.data(), key, N.serverTime())
			if ok and tonumber(left) then
				return tonumber(left)
			end
		end
		local p = N.tab("Potions")[key]
		if type(p) == "number" then
			return p - N.serverTime()
		end
		return 0
	end
	local function potionActive(name)
		return potionLeft(name) > 0
	end
	N.potionActive = potionActive
	N.potionLeft = potionLeft
	function N.drinkPotion(guid, name, why)
		local before = potionLeft(name)
		N.pauseFishing()
		N.holdAndWait(guid, 2)
		send("Potion", "Drink", guid)
		local ok = waitFor(function()
			return potionLeft(name) > before + 1
		end, 3)
		if ok then
			Session.potions += 1
			I.last = "Drank " .. name
			log("POTION", name, "ok", string.format("ends in %d s", math.floor(potionLeft(name))), why or "")
		else
			log("POTION FAILED", name, "answer=timer unchanged", why or "")
		end
		return ok
	end
	local function bossRunning()
		local BE = N.sh("Config.BossEventConfig")
		if type(BE) ~= "table" or type(BE.IsActive) ~= "function" then
			return false
		end
		for _, name in ipairs({ "Sunken", "SunkenQueen", "Kraken" }) do
			local ok, yes = pcall(BE.IsActive, name)
			if ok and yes then
				return true
			end
		end
		return false
	end
	N.bossRunning = bossRunning
	function N.itemChores()
		if not N.ready() then
			return false
		end
		if N.wants("AutoOpen") and N.due("open", 5) then
			local Chests = N.sh("Content.Item.Chest")
			for _, kind in ipairs({ "Chest", "Cage", "Exclusive" }) do
				for _, entry in ipairs(N.itemsOf(kind)) do
					local def = kind == "Chest" and Chests and type(Chests.Items) == "table" and Chests.Items[tostring(entry.item.Name)] or nil
					local crate = type(def) == "table" and (def.Kind == "SkinChest" or def.Kind == "BoatBottle")
					if (I.fails[entry.guid] or 0) < 3 and not crate then
						useHeld(if kind == "Exclusive" then "LikeGift" else "FishingObject", kind, entry.guid, tostring(entry.item.Name), "Opened")
						task.wait(0.5)
						return true
					end
				end
			end
		end
		if on("UseSummons") and N.due("summon", 20) and not bossRunning() and not (N.whaleWindow and N.whaleWindow()) then
			for _, entry in ipairs(N.itemsOf("Summon")) do
				if (I.fails[entry.guid] or 0) < 3 then
					local ok = useHeld("FishingObject", "Summon", entry.guid, tostring(entry.item.Name), "Summoned with")
					if ok then
						waitFor(bossRunning, 4)
						log("SUMMON", tostring(entry.item.Name), "boss running=" .. tostring(bossRunning()))
					end
					return true
				end
			end
		end
		if on("AutoPotions") and N.worldKey() ~= "Pond" and N.due("potions", 10) then
			for _, entry in ipairs(N.itemsOf("Potion")) do
				local name = tostring(entry.item.Name)
				local key = N.potionKey(name)
				local saved = key == "Coins" and on("SellPotion") and N.wants("SmartSell")
				if selected(Options.PotionKinds, key) and not saved and not potionActive(name) and (I.fails[entry.guid] or 0) < 3 then
					if not N.drinkPotion(entry.guid, name, "Auto Potions") then
						I.fails[entry.guid] = (I.fails[entry.guid] or 0) + 1
					end
					task.wait(0.5)
					return true
				end
			end
		end
		if on("AutoRelics") and N.due("relics", 15) then
			local BR = N.sh("Config.BossRelicConfig")
			for guid, item in pairs(N.inv()) do
				if type(item) == "table" and item.Type == "Fish" then
					local key = N.relicOf(item)
					local def = key and BR and type(BR.Get) == "function" and select(2, pcall(BR.Get, key))
					local whaleRelic = type(def) == "table" and (def.HatchLuck ~= nil or def.EggDrop ~= nil)
					if key and type(def) == "table" and not def.SellAll and not whaleRelic then
						N.pauseFishing()
						N.holdAndWait(guid, 2)
						send("BossRelic", "Consume", guid)
						local ok = waitFor(function()
							return N.relicOf(N.inv()[guid] or {}) == nil
						end, 3)
						Session.relics += 1
						I.last = "Used relic " .. tostring(key)
						log(if ok then "RELIC" else "RELIC FAILED", tostring(key), if ok then "ok" else "answer=relic still unused")
						task.wait(0.5)
						return true
					end
				end
			end
			if N.whaleIn and N.useWhaleRelic then
				local wait = N.whaleIn()
				if wait > 0 and wait <= 90 and N.useWhaleRelic("whale egg drop in " .. math.floor(wait) .. " s") then
					I.last = "Used the Whale relic before the egg drop"
					return true
				end
			end
		end
		return false
	end
	function N.useSellRelics()
		local BR = N.sh("Config.BossRelicConfig")
		local used = 0
		for guid, item in pairs(N.inv()) do
			if type(item) == "table" and item.Type == "Fish" then
				local key = N.relicOf(item)
				local ok, def = false, nil
				if key and BR and type(BR.Get) == "function" then
					ok, def = pcall(BR.Get, key)
				end
				if key and ok and type(def) == "table" and def.SellAll then
					N.holdAndWait(guid, 2)
					send("BossRelic", "Consume", guid)
					used += 1
					Session.relics += 1
					log("RELIC sell boost", tostring(key))
					task.wait(0.8)
				end
			end
		end
		return used
	end
	local function kgOf(item)
		local Fish = N.sh("Content.Item.Fish")
		if type(Fish) == "table" and type(Fish.GetWeight) == "function" then
			local ok, kg = pcall(Fish.GetWeight, Fish, item)
			if ok and tonumber(kg) then
				return tonumber(kg)
			end
		end
		local def = N.fishDef(item.Name)
		local size = type(item.Data) == "table" and tonumber(item.Data.Size) or 1
		return (def and tonumber(def.Weight) or 1) * size ^ 3
	end
	N.fishKg = kgOf
	function N.bigMouthPlan(need)
		local fish = {}
		for guid, item in pairs(N.inv()) do
			if type(item) == "table" and item.Type == "Fish" and not N.isLocked(item) and not N.relicOf(item) and not N.keeps(item) then
				local kg = kgOf(item)
				if kg > 0 then
					table.insert(fish, { guid = guid, kg = kg, v = N.cachedValue(guid, item) })
				end
			end
		end
		if #fish == 0 or need <= 0 then
			return {}, 0, 0
		end
		local single
		for _, f in ipairs(fish) do
			if f.kg >= need and (not single or f.v < single.v) then
				single = f
			end
		end
		table.sort(fish, function(a, b)
			return a.v / a.kg < b.v / b.kg
		end)
		local list, kg, cost = {}, 0, 0
		for _, f in ipairs(fish) do
			if kg >= need then
				break
			end
			table.insert(list, f)
			kg += f.kg
			cost += f.v
		end
		if single and (kg < need or single.v <= cost) then
			return { single }, single.v, single.kg
		end
		if kg < need then
			return {}, 0, kg
		end
		return list, cost, kg
	end
	local function bigMouthSpot()
		local folder = N.worldFolder()
		local inter = folder and folder:FindFirstChild("Interactable")
		local model = (inter and inter:FindFirstChild("BigMouthFish")) or (folder and folder:FindFirstChild("BigMouthFish", true))
		if not model then
			return nil
		end
		local att = model:FindFirstChild("ProximityAttachment", true)
		local ok, pos = pcall(function()
			if att and att:IsA("Attachment") then
				return att.WorldPosition
			end
			return model:GetPivot().Position
		end)
		return if ok then pos else nil
	end
	function N.reachBigMouth(pos)
		local function dist()
			local my = N.myPos()
			return if my then (my - pos).Magnitude else math.huge
		end
		if dist() <= 9 then
			return true
		end
		if N.safeMove() then
			return N.goTo(pos, 8)
		end
		for _, a in ipairs({ -1, 0, 90, 180, 270 }) do
			local p = pos
			if a >= 0 then
				local r = math.rad(a)
				p = pos + Vector3.new(math.cos(r) * 6, 0, math.sin(r) * 6)
			end
			N.tp(p + Vector3.new(0, 2, 0))
			task.wait(0.5)
			if dist() <= 9.5 then
				return true
			end
		end
		return false
	end
	function N.bigMouthStep()
		if not N.wants("AutoBigMouth") or not N.unlocked("World 1") then
			return false
		end
		if N.whaleWindow and N.whaleWindow() then
			return false
		end
		local bm = N.tab("BigMouth")
		if (tonumber(bm.ReadyAt) or 0) > N.serverTime() or os.clock() < (N.bmBackoff or 0) or not N.due("bigMouth", 60) then
			return false
		end
		local goal = tonumber(bm.Goal) or 0
		local need = math.max(goal - (tonumber(bm.Progress) or 0), 0)
		local plan, cost, kg = N.bigMouthPlan(if goal > 0 then need else 1)
		if goal > 0 and #plan == 0 then
			if N.due("bigMouthNoFish", 600) then
				log("BIGMOUTH waits", "no sellable fish reach " .. formatNumber(need) .. " kg yet (have " .. formatNumber(kg) .. " kg)")
			end
			return false
		end
		local BC = N.sh("Config.BigMouthConfig")
		local step = 0.05
		pcall(function()
			step = BC.LuckStepFor(tonumber(bm.Feeds) or 0, BC.LuckFor(N.data()))
		end)
		if N.planner() and N.castModel and goal > 0 and N.due("bigMouthPrice", 120) then
			local base = N.castModel()
			local up = N.castModel({ extraLuck = step })
			local worth = 0
			if base and up and base > 0 then
				worth = (up / base - 1) * N.incomeRate() * 3600 * math.max(N.Plan.horizon or 12, 1)
			end
			if N.potionWorth then
				worth += N.potionWorth("Luck Potion", 600) * 0.36
			end
			if cost > worth then
				log("BIGMOUTH skipped", "cost=" .. formatNumber(cost), "(" .. #plan .. " fish, " .. formatNumber(kg) .. " kg of " .. formatNumber(goal) .. ")", "luck +" .. math.floor(step * 100) .. "% and the reward over the horizon=" .. formatNumber(worth))
				N.bmBackoff = os.clock() + 1800
				return false
			end
		end
		N.pauseFishing("Big Mouth")
		local back = N.worldKey()
		if back ~= "World 1" and not N.travel("World 1") then
			N.resumeFishing()
			return false
		end
		local pos
		waitFor(function()
			pos = bigMouthSpot()
			return pos ~= nil
		end, 8)
		if not pos or not N.reachBigMouth(pos) then
			N.BMFail = (N.BMFail or 0) + 1
			local wait = if N.BMFail >= 2 then 3600 else 300
			N.bmBackoff = os.clock() + wait
			local my = N.myPos()
			log("BIGMOUTH not reached", "spot=" .. (if pos then string.format("(%.0f, %.0f, %.0f)", pos.X, pos.Y, pos.Z) else "missing"), "dist=" .. (if pos and my then string.format("%.0f", (my - pos).Magnitude) else "?"), "fails=" .. N.BMFail, if N.BMFail >= 2 then "off for 1 h" else "retry in 5 min")
			if N.BMFail >= 2 then
				N.BMFail = 0
			end
			if back ~= "World 1" then
				N.travel(back)
			end
			N.resumeFishing()
			return false
		end
		N.BMFail = 0
		setStatus("Feeding the Big Mouth")
		if (tonumber(N.tab("BigMouth").Goal) or 0) <= 0 then
			send("BigMouth", "Open")
			waitFor(function()
				return (tonumber(N.tab("BigMouth").Goal) or 0) > 0
			end, 3)
			goal = tonumber(N.tab("BigMouth").Goal) or 0
			need = math.max(goal - (tonumber(N.tab("BigMouth").Progress) or 0), 0)
			plan = N.bigMouthPlan(need)
			if #plan == 0 then
				log("BIGMOUTH waits", "opened, goal " .. formatNumber(goal) .. " kg: not enough sellable fish weight yet")
				N.bmBackoff = os.clock() + 600
				if back ~= "World 1" then
					N.travel(back)
				end
				N.resumeFishing()
				return true
			end
		end
		local feedsBefore = tonumber(N.tab("BigMouth").Feeds) or 0
		local readyBefore = tonumber(N.tab("BigMouth").ReadyAt) or 0
		local t0 = os.clock()
		local fed, fedKg = 0, 0
		for _, f in ipairs(plan) do
			if not alive() or not N.wants("AutoBigMouth") or (tonumber(N.tab("BigMouth").ReadyAt) or 0) > N.serverTime() then
				break
			end
			if N.inv()[f.guid] then
				N.holdAndWait(f.guid, 2)
				local progress = tonumber(N.tab("BigMouth").Progress) or 0
				send("BigMouth", "Feed")
				waitFor(function()
					return N.inv()[f.guid] == nil or (tonumber(N.tab("BigMouth").Progress) or 0) ~= progress
				end, 2.5)
				fed += 1
				fedKg += f.kg
			end
		end
		local done = waitFor(function()
			local b = N.tab("BigMouth")
			return (tonumber(b.Feeds) or 0) > feedsBefore or (tonumber(b.ReadyAt) or 0) > readyBefore
		end, 4)
		Session.bigMouth += 1
		local b = N.tab("BigMouth")
		local note = N.noteSince(t0)
		if done then
			remember("Big Mouth fed (" .. fed .. " fish, " .. formatNumber(fedKg) .. " kg)")
			log("BIGMOUTH fed", fed .. " fish " .. formatNumber(fedKg) .. " kg", "ok", "luck now +" .. math.floor((tonumber(b.Luck) or 0) * 100 + 0.5) .. "%", "feeds=" .. tostring(b.Feeds), if note then "note=" .. note else "")
		else
			log("BIGMOUTH FAILED", "fed " .. fed .. " fish " .. formatNumber(fedKg) .. " kg", "progress=" .. tostring(b.Progress) .. "/" .. tostring(b.Goal), "answer=" .. (if note then note else "feeding not finished"))
			N.bmBackoff = os.clock() + 600
		end
		if back ~= "World 1" then
			N.travel(back)
		end
		N.resumeFishing()
		return true
	end
	local function stoneOf(slot)
		for _, entry in ipairs(N.itemsOf("Scroll")) do
			local n = tostring(entry.item.Name)
			if (slot == 1 and n == "Enchant Stone") or (slot == 2 and n == "Ultra Enchant Stone") then
				return entry.guid
			end
		end
		return nil
	end
	function N.enchantNames()
		local E = N.sh("Modules.Enchant")
		if type(E) == "table" and type(E.Names) == "function" then
			local ok, a, b = pcall(E.Names, N.data())
			if ok then
				return a, b
			end
		end
		return nil, nil
	end
	function N.enchantStep()
		if not on("AutoEnchant") or not N.due("enchant", 20) then
			return false
		end
		local s1, s2 = N.enchantNames()
		local want1 = stoneOf(1) and not selected(Options.EnchantTargets, tostring(s1))
		local want2 = stoneOf(2) and not selected(Options.EnchantTargets, tostring(s2))
		if not (want1 or want2) then
			return false
		end
		local pos = N.spot("NPC_StoneMage")
		if not pos then
			if N.due("enchantNoMage", 600) then
				log("ENCHANT no Stone Mage in " .. N.worldKey())
			end
			return false
		end
		N.pauseFishing("enchant")
		if not N.goTo(pos, 8) then
			N.resumeFishing()
			return false
		end
		local slot = if want1 then 1 else 2
		local guid = stoneOf(slot)
		if guid then
			N.holdAndWait(guid, 2)
			send("Enchant", "Roll")
			Session.enchants += 1
			task.wait(2)
			local n1, n2 = N.enchantNames()
			log("ENCHANT roll", "slot=" .. slot, "now=" .. tostring(if slot == 1 then n1 else n2))
		end
		N.resumeFishing()
		return true
	end
	function N.mutationStep()
		if not on("AutoMutate") or not N.due("mutate", 30) then
			return false
		end
		local normal, ultra = 0, 0
		for _, entry in ipairs(N.itemsOf("Scroll")) do
			local n = tostring(entry.item.Name)
			local amount = tonumber(type(entry.item.Data) == "table" and entry.item.Data.Amount) or 1
			if n == "Mutation Scroll" then
				normal += amount
			elseif n == "Ultra Mutation Scroll" then
				ultra += amount
			end
		end
		local useUltra = ultra > 0 and (normal <= 0 or optionText("MutateScroll", "Mutation Scroll first") == "Ultra first")
		if normal <= 0 and not useUltra then
			return false
		end
		local pos = N.spot("MutationDealer")
		if not pos then
			return false
		end
		local best, bestValue
		for guid, item in pairs(N.inv()) do
			if type(item) == "table" and item.Type == "Fish" and not (type(item.Data) == "table" and item.Data.Mutation) and not N.relicOf(item) then
				local v = N.value(item)
				if not best or v > bestValue then
					best, bestValue = guid, v
				end
			end
		end
		if not best then
			return false
		end
		N.pauseFishing("mutation")
		if N.goTo(pos, 8) then
			N.holdAndWait(best, 2)
			send("MutationReroll", "Spin", useUltra)
			Session.mutations += 1
			task.wait(2.5)
			local item = N.inv()[best]
			log("MUTATE spin", if useUltra then "ultra" else "normal", formatNumber(bestValue), "now=" .. tostring(type(item) == "table" and type(item.Data) == "table" and item.Data.Mutation or "-"))
		end
		N.resumeFishing()
		return true
	end
end
N.Econ = { samples = {}, rate = 0, spent = 0 }
N.Plan = { text = "", say = "", best = nil, need = nil, lastKey = "", lastAt = -1e9, list = {} }
N.Sell = { needNpc = nil, last = "-", locked = {}, at = os.clock() }
N.Shop = { near = {}, last = "-", stockOut = {} }
N.Pond = { last = "-", at = -1e9 }
N.World = { last = "-" }
do
	local E, P = N.Econ, N.Plan
	local function cfg(name)
		local c = N.sh("Config." .. name)
		return if type(c) == "table" then c else nil
	end
	function N.backpackValue()
		return (select(4, N.fishStats())) or 0
	end
	local function pondValue()
		local total = 0
		pcall(function()
			for _, f in pairs(N.tab("Pond").Fish or {}) do
				if type(f) == "table" and f.Name and not f.Dead then
					total += N.value(f)
				end
			end
		end)
		return total
	end
	E.adjust = 0
	function N.econTick()
		local boost = math.max(tonumber(workspace:GetAttribute("ServerCash")) or 1, 1)
		local worth = N.cash() + N.backpackValue() / boost + pondValue() + E.spent + E.adjust
		local prev = E.samples[#E.samples]
		if prev and worth < prev.w then
			E.adjust += prev.w - worth
			worth = prev.w
		end
		local now = os.clock()
		table.insert(E.samples, { t = now, w = worth, c = Session.casts, v = Session.castValue })
		while #E.samples > 2 and now - E.samples[1].t > 900 do
			table.remove(E.samples, 1)
		end
		local first, last = E.samples[1], E.samples[#E.samples]
		if last.t - first.t >= 60 then
			E.measured = true
			E.rate = math.max((last.w - first.w) / (last.t - first.t), 0)
			E.cps = math.max((last.c - first.c) / (last.t - first.t), 0)
			if E.cps > 0 and N.castModel then
				local _, info = N.castModel()
				if info then
					local seen = math.clamp(1 / E.cps - info.cycle, 0.3, 30)
					E.overhead = if E.overhead then E.overhead * 0.7 + seen * 0.3 else seen
				end
			end
		end
		local prevS = E.samples[#E.samples - 1]
		if prevS and N.castScale then
			local dc, dv = last.c - prevS.c, last.v - prevS.v
			local scale, model = N.castScale()
			if dc > 0 and model and model > 0 and scale > 0 then
				E.rhoNum = (E.rhoNum or 0) * 0.9 + dv
				E.rhoDen = (E.rhoDen or 0) * 0.9 + scale * model * dc
			end
		end
	end
	function N.spent(amount)
		E.spent += tonumber(amount) or 0
	end
	function N.expectedRate()
		if os.clock() - (E.expAt or -1e9) < 3 then
			return E.exp
		end
		E.expAt, E.exp = os.clock(), nil
		local scale, model = N.castScale()
		if model and model > 0 and (E.cps or 0) > 0 and (E.rhoDen or 0) > 0 then
			local rho = math.clamp(E.rhoNum / E.rhoDen, 0.3, 5)
			E.exp = rho * scale * model * E.cps
		end
		return E.exp
	end
	local function knownRate()
		local r = N.expectedRate() or E.rate
		if r <= 0 and N.Fish.cycle > 0 and N.Fish.evCast > 0 then
			r = N.Fish.evCast / N.Fish.cycle
		end
		if r <= 0 and N.castModel then
			pcall(function()
				local scale, model = N.castScale()
				local _, info = N.castModel()
				if model and model > 0 and info and (info.cycle or 0) > 0 then
					r = scale * model / (info.cycle + (E.overhead or 3))
				end
			end)
		end
		return r
	end
	local function rawRate()
		return math.max(knownRate(), 1)
	end
	local RateFile = "Jiro/FISH_rate_" .. tostring(LocalPlayer.UserId) .. ".txt"
	pcall(function()
		if isfile and isfile(RateFile) then
			local r, w = string.match(readfile(RateFile), "^(%S+)\t(.+)$")
			E.prior, E.priorWorld = tonumber(r), w
		end
	end)
	function N.rateMeasured()
		return E.measured == true or (tonumber(E.prior) or 0) > 1 and E.priorWorld == N.worldKey() or knownRate() > 1
	end
	function N.incomeRate()
		if not E.measured then
			local known = knownRate()
			if known > 1 then
				return known
			end
			if (tonumber(E.prior) or 0) > 1 and E.priorWorld == N.worldKey() then
				return E.prior
			end
			return 1
		end
		local raw = rawRate()
		if os.clock() - (E.savedAt or -1e9) >= 60 then
			E.savedAt = os.clock()
			pcall(function()
				if makefolder and isfolder and not isfolder("Jiro") then
					makefolder("Jiro")
				end
				writefile(RateFile, tostring(raw) .. "\t" .. N.worldKey())
			end)
		end
		return raw
	end
	local function rodPower(name)
		local rods = N.sh("Content.Item.Rod")
		local def = rods and type(rods.Items) == "table" and rods.Items[name]
		if not def then
			return 0, 0
		end
		local W = cfg("WorldsConfig")
		local factor = 1
		pcall(function()
			local home = math.max(N.worldNumber(def.RequiredWorld or "World 1"), if def.FullPowerThrough then N.worldNumber(def.FullPowerThrough) else 0)
			factor = W.RodFactor(home, select(2, N.bestFishingWorld()))
		end)
		return (tonumber(def.Luck) or 0) * factor, (tonumber(def.Strength) or 0) * factor
	end
	N.rodPower = rodPower
	function N.hallOf(def)
		if type(def) ~= "table" then
			return nil
		end
		return if def.CaveOnly then "Cave" elseif def.MazeOnly then "Maze" elseif def.VolcanoOnly then "Volcano" else nil
	end
	function N.hallReady(hall)
		if hall ~= "Cave" and hall ~= "Maze" then
			return false
		end
		local HC = cfg(hall .. "Config")
		local state = N.tab(hall)
		if not (HC and state.KeyInserted == true and state.RodUnlocked ~= true) then
			return false
		end
		local slots = type(state.Slots) == "table" and state.Slots or {}
		for i = 1, #(type(HC.Slots) == "table" and HC.Slots or {}) do
			local ok, filled = pcall(HC.Filled, slots, i)
			if not (ok and filled) then
				return false
			end
		end
		return true
	end
	local function statGain(U, stat, level, key)
		local step = 1
		pcall(function()
			step = U.StepFor(stat, key)
		end)
		if stat == "Capacity" then
			local cap = math.max(N.hookCap(), 1)
			return step / cap * 0.7
		elseif stat == "Strength" then
			local ok, a, b = pcall(function()
				return U.StrengthMultiplier(level), U.StrengthMultiplier(level + step)
			end)
			return if ok and a and a > 0 then (b / a - 1) * 0.6 else 0.05
		elseif stat == "Weight" then
			local ok, a, b = pcall(function()
				return U.WeightMultiplier(level), U.WeightMultiplier(level + step)
			end)
			return if ok and a and a > 0 then (b / a - 1) * 0.6 else 0.03
		end
		return if level <= 0 then 0.05 else 0.02
	end
	local function try(f, default, ...)
		local ok, v = pcall(f, ...)
		if ok and v ~= nil then
			return v
		end
		return default
	end
	local function fishOrder(Fish)
		local list = {}
		for name, def in pairs(Fish.Items) do
			if type(def) == "table" and tonumber(def.SellPrice) and def.SellPrice > 0 then
				table.insert(list, { name = name, price = def.SellPrice })
			end
		end
		table.sort(list, function(a, b)
			return a.price > b.price
		end)
		return list
	end
	local function baseBait()
		local baits = N.sh("Content.Item.Bait")
		local defs = baits and baits.Items
		local best
		if type(defs) == "table" then
			for name, n in pairs(N.tab("ActiveBaits")) do
				local def = defs[name]
				if (tonumber(n) or 0) > 0 and def and (not best or (tonumber(def.Luck) or 0) > (tonumber(best.Luck) or 0)) then
					best = def
				end
			end
		end
		return best or false
	end
	local function flightOf(dist)
		local d = math.max(dist, 0)
		return math.min(if d < 110 then d ^ 2 * 0.03540353338991906 else d ^ 0.975 * 4.38, 40546.68244059479)
	end
	local function arcTime(mag)
		local function timeFor(apex)
			local v = math.max(apex, 0) * 2 / (36.4 * (1 + math.max(apex, 0) / 1000))
			return math.max(math.sqrt(v) * 2, 0.45)
		end
		local function solved(m)
			local apex = 0.045 * math.max(m, 0)
			return timeFor(math.max(apex / (1 + (apex / 420) ^ 3) ^ (1 / 3), 8))
		end
		if mag > 6000 then
			return math.min(solved(6000) * (mag / 6000) ^ 0.11, 8)
		end
		return solved(mag)
	end
	function N.castModel(over)
		over = over or {}
		local d = N.data()
		local U, Wc = cfg("UpgradesConfig"), cfg("WorldsConfig")
		local Fish, Rods = N.sh("Content.Item.Fish"), N.sh("Content.Item.Rod")
		if not (U and Wc and type(Fish) == "table" and type(Fish.Items) == "table" and type(Fish.SpawnWeights) == "function") then
			return nil
		end
		local key = over.world or (N.bestFishingWorld())
		local wdef = type(Wc.Worlds) == "table" and Wc.Worlds[key]
		if not wdef then
			return nil
		end
		local effect = tonumber(wdef.UpgradeEffect) or 1
		local levels = try(U.LevelsFor, {}, d, key)
		local function lv(stat)
			if over.levels and over.levels[stat] then
				return over.levels[stat]
			end
			return tonumber(levels[stat]) or 0
		end
		local rodName = over.rod or d.RodEquipped or "Wooden Rod"
		local rdef = type(Rods) == "table" and type(Rods.Items) == "table" and Rods.Items[rodName] or {}
		local home = math.max(N.worldNumber(rdef.RequiredWorld or "World 1"), if rdef.FullPowerThrough then N.worldNumber(rdef.FullPowerThrough) else 0)
		local factor = try(Wc.RodFactor, 1, home, tonumber(wdef.WorldNumber) or 1)
		local bait = over.bait
		if bait == nil then
			bait = baseBait()
		end
		local baitLuck = if bait then tonumber(bait.Luck) or 0 else 0
		local baitWeight = if bait then tonumber(bait.Weight) or 0 else 0
		local Enchant = N.sh("Modules.Enchant")
		local function ench(effect2)
			return tonumber(try(function()
				return Enchant.Add(d, effect2)
			end, 0)) or 0
		end
		local luckSum = (tonumber(rdef.Luck) or 0) * factor / 100 + baitLuck / 100
			+ try(function()
				return cfg("LevelConfig").LuckForLevel(N.level()) / 100
			end, 0)
			+ try(function()
				return cfg("ReferralConfig").LuckFor(d)
			end, 0)
			+ try(function()
				return cfg("BigMouthConfig").LuckFor(d)
			end, 0)
			+ ench("Luck") + (over.extraLuck or 0)
		local skin = try(function()
			return cfg("SkinBoostConfig").WornMultiplier(d, "Luck")
		end, 1)
		local gamepass = try(function()
			return cfg("LuckConfig").MultiplierFor(type(d.Gamepasses) == "table" and d.Gamepasses or {})
		end, 1)
		local potion = try(function()
			return cfg("PotionConfig").LuckBonus(d)
		end, 0)
		local pet = if N.petLuck then N.petLuck() else 1
		local streak = if N.streakLuck then N.streakLuck() else 1
		local luck = ((1 + luckSum) * skin * gamepass * pet * streak + potion) * (tonumber(workspace:GetAttribute("ServerLuck")) or 1) * (over.luckMult or 1)
		local quality = over.quality or (if N.fishMode() == "blatant" then 2 else 1.8)
		local dist = math.min(quality * 25 * U.StrengthMultiplier(lv("Strength"), effect) * (1 + (tonumber(rdef.Strength) or 0) * factor / 100) * (1 + ench("Distance")), 11700)
		local bounceLevel = lv("Bounce")
		local pBounce = try(function()
			return U.BounceChance(bounceLevel, effect)
		end, 0) * (if quality >= 2 then 1 elseif quality >= 1.5 then 0.5 else 0)
		local gBounce = try(function()
			return U.BounceGain(bounceLevel, effect)
		end, 0)
		dist += pBounce * math.min(dist * gBounce, math.max(11700 - dist, 0))
		local depth = math.log(dist * U.WeightMultiplier(lv("Weight"), effect) * (baitWeight / 100 + 1) / 60 + 1, 2) * 30 + 26 + ench("Depth")
		local hooks = U.CapacityValue(lv("Capacity"), effect, key) + ench("HookSlots") + math.floor(try(function()
			return cfg("PotionConfig").Bonus(d, "Capacity")
		end, 0))
		local school = math.clamp(math.floor(math.max(hooks * 1.5, (depth - 26) / 5.5) + 0.5), 3, 56)
		local ok, weights, total = pcall(Fish.SpawnWeights, Fish, luck, tonumber(wdef.WorldNumber) or 1, depth, tonumber(wdef.DepthScale) or 1)
		if not (ok and type(weights) == "table" and tonumber(total) and total > 0) then
			return nil
		end
		local n, k = school, math.min(hooks, school)
		local function slots(F)
			if F <= 0 then
				return 0
			elseif F >= 1 then
				return k
			end
			local q = 1 - F
			local pmf, ratio = q ^ n, F / q
			local cdf, acc = 0, 0
			for m = 1, k do
				cdf += pmf
				acc += 1 - cdf
				pmf = pmf * (n - (m - 1)) / m * ratio
			end
			return acc
		end
		local sum, cumulative, before, hookTime = 0, 0, 0, 0
		for _, e in ipairs(fishOrder(Fish)) do
			local w = weights[e.name]
			if w and w > 0 then
				cumulative += w / total
				local now = slots(cumulative)
				sum += e.price * (now - before)
				hookTime += (now - before) * N.hookSeconds(e.name, false)
				before = now
			end
		end
		if sum <= 0 then
			return nil
		end
		local mag = flightOf(dist)
		local cycle = arcTime(mag) + math.clamp(depth / 70, 0.15, 1) + math.clamp(mag / 3810, 1, 3) + hookTime
		return sum, { luck = luck, dist = dist, depth = depth, hooks = hooks, school = school, cycle = cycle }
	end
	function N.castScale()
		local base = N.castModel()
		local scale = 1
		pcall(function()
			local Fish = N.sh("Content.Item.Fish")
			local list = fishOrder(Fish)
			local e = list[#list]
			local v = N.value({ Type = "Fish", Name = e.name, Data = { Size = 1 } })
			local boost = math.max(tonumber(workspace:GetAttribute("ServerCash")) or 1, 1)
			if v > 0 and e.price > 0 then
				scale = v / boost / e.price
			end
		end)
		return scale, base
	end
	local function catchUp(key, budget)
		local U = cfg("UpgradesConfig")
		local cur = try(U.LevelsFor, {}, N.data(), key)
		local lvls = {}
		for _, stat in ipairs(U.Order) do
			lvls[stat] = tonumber(cur[stat]) or 0
		end
		local spent = 0
		while true do
			local pickStat, pickPrice
			for _, stat in ipairs(U.Order) do
				local ok, price = pcall(function()
					if lvls[stat] < U.MaxLevelFor(stat, key) then
						return U.GetPrice(stat, lvls[stat], key)
					end
					return nil
				end)
				if ok and price and price > 0 and spent + price <= budget and (not pickPrice or price < pickPrice) then
					pickStat, pickPrice = stat, price
				end
			end
			if not pickStat then
				break
			end
			lvls[pickStat] += U.StepFor(pickStat, key)
			spent += pickPrice
		end
		return lvls, spent
	end
	function N.horizon()
		return math.max((24 - ((os.clock() - Session.started) / 3600) % 24) * 0.9, 6)
	end
	function N.candidates()
		local d = N.data()
		local out = {}
		local rate = N.incomeRate()
		local U = cfg("UpgradesConfig")
		local base, baseInfo = N.castModel()
		local _, bestNumber = N.bestFishingWorld()
		local overhead = E.overhead or 1.5
		local H = N.horizon()
		local function perCycle(c, info)
			return c / (info.cycle + overhead)
		end
		local function gain(over)
			if not (base and base > 0) then
				return nil
			end
			local c, info = N.castModel(over)
			return if c then math.max(perCycle(c, info) / perCycle(base, baseInfo) - 1, 0) else nil
		end
		local worldCand, worldRate, worldLvls
		if N.planner() or on("AutoWorlds") then
			local W = cfg("WorldsConfig")
			for key, w in pairs(W and type(W.Worlds) == "table" and W.Worlds or {}) do
				if not w.NoFishing and tonumber(w.WorldNumber) == bestNumber + 1 and not N.unlocked(key) and N.level() >= (tonumber(w.RequiredLevel) or 1) then
					local price = tonumber(w.UnlockPrice) or 0
					local frac, extra = 5, 0
					if base then
						local lvls, spent = catchUp(key, price * 0.1)
						local bestRate
						for name in pairs(N.tab("Rods")) do
							local c, info = N.castModel({ world = key, rod = name, levels = lvls })
							if c and (not bestRate or perCycle(c, info) > bestRate) then
								bestRate = perCycle(c, info)
							end
						end
						if not bestRate then
							local c, info = N.castModel({ world = key, levels = lvls })
							bestRate = if c then perCycle(c, info) else nil
						end
						if bestRate then
							frac, extra = math.clamp(bestRate / perCycle(base, baseInfo) - 1, 0.2, 1000), spent
							worldRate, worldLvls = bestRate, lvls
						end
					end
					worldCand = { kind = "world", name = key, price = price, cost = price + extra, g = frac, frac = frac, persist = true, key = key }
					table.insert(out, worldCand)
				end
			end
		end
		local tW, mW
		if worldCand then
			local funds = N.cash() + N.backpackValue() * 0.95
			tW = math.max(worldCand.price - funds, 0) / rate / 3600 + 0.02
			mW = 1 + worldCand.g
			worldCand.eta = tW
		end
		local function averaged(g, gPost)
			if not tW then
				return g
			end
			return (g * math.min(tW, H) + gPost * mW * math.max(H - tW, 0)) / H
		end
		if U and type(U.Order) == "table" and (N.planner() or on("AutoUpgrades")) then
			local key = "World 1"
			pcall(function()
				key = U.KeyForData(d)
			end)
			for _, stat in ipairs(U.Order) do
				if N.planner() or selected(Options.UpgradeStats, stat) then
					local ok, level, max, price = pcall(function()
						local lv = U.LevelOf(d, stat, key)
						return lv, U.MaxLevelFor(stat, key), U.GetPrice(stat, lv, key)
					end)
					if ok and level < max and price and price > 0 then
						local step = 1
						pcall(function()
							step = U.StepFor(stat, key)
						end)
						local g = gain({ world = key, levels = { [stat] = level + step } }) or statGain(U, stat, level, key)
						table.insert(out, { kind = "upgrade", name = stat, price = price, g = g, frac = averaged(g, 0), persist = false })
					end
				end
			end
		end
		local rods = N.sh("Content.Item.Rod")
		if rods and type(rods.Items) == "table" and (N.planner() or on("AutoRods")) then
			local curL, curS = rodPower(d.RodEquipped or "Wooden Rod")
			local owned = N.tab("Rods")
			for name, def in pairs(rods.Items) do
				local price = tonumber(def.Price) or 0
				local need = N.worldNumber(def.RequiredWorld or "World 1")
				local hall = N.hallOf(def)
				local reachable = hall == nil or (N.hallReady(hall) and not (N.memo and N.memo("hall_rod_" .. hall) == "unreachable"))
				if not owned[name] and price > 0 and need <= bestNumber and reachable then
					local g = gain({ rod = name })
					if not g then
						local l, s = rodPower(name)
						g = (l - curL) / (100 + curL) * 0.8 + (s - curS) / (100 + curS) * 0.4
					end
					if g > 0.005 then
						local gPost = 0
						if worldRate then
							local c, info = N.castModel({ world = worldCand.key, rod = name, levels = worldLvls })
							if c then
								gPost = math.max(perCycle(c, info) / worldRate - 1, 0)
							end
						end
						table.insert(out, { kind = "rod", name = name, price = price, g = g, frac = averaged(g, gPost), persist = gPost > 0.01, hall = hall })
					end
				end
			end
		end
		if N.wants("AutoPond") and not N.unlocked("Pond") and N.level() >= 5 then
			table.insert(out, { kind = "world", name = "Pond", price = 25000, g = 0.15, frac = 0.15, persist = true })
		end
		for _, c in ipairs(out) do
			c.payback = (c.cost or c.price) / math.max(rate * c.frac, 1e-6) / 3600
			c.paybackNow = (c.cost or c.price) / math.max(rate * c.g, 1e-6) / 3600
		end
		table.sort(out, function(a, b)
			return a.payback < b.payback
		end)
		return out
	end
	function N.beatsWorld(c, world, funds, rate)
		local need = math.max(world.price - funds, 0)
		local without = need / rate
		if c.persist then
			without += c.price / (rate * (1 + world.g))
		end
		local with = (need + c.price) / (rate * (1 + c.g))
		return with < without
	end
	function N.netCandidate()
		local OC = cfg("OfflineConfig")
		if not (OC and OC.Enabled and N.Fish.evCast > 0) then
			return nil
		end
		local ok, price, spf, nextSpf = pcall(function()
			local lv = OC.LevelFor(N.data())
			return OC.PriceFor(lv), OC.SecondsPerFishFor(lv), OC.SecondsPerFishFor(lv + 1)
		end)
		if not (ok and price and price > 0 and spf and nextSpf and nextSpf < spf) then
			return nil
		end
		local perFish = N.Fish.evCast / math.max(N.hookCapRaw(), 1) * 0.25 / 100 ^ math.max(select(2, N.bestFishingWorld()) - 1, 0)
		local extraPerSecond = (1 / nextSpf - 1 / spf) * perFish
		return { kind = "net", name = "Offline Net", price = price, frac = extraPerSecond / N.incomeRate(), payback = price / math.max(extraPerSecond, 1e-9) / 3600 }
	end
	local function owned(c)
		local d = N.data()
		if c.kind == "rod" then
			return N.tab("Rods")[c.name] ~= nil
		elseif c.kind == "world" then
			return N.unlocked(c.name)
		elseif c.kind == "upgrade" then
			return (c.levelBefore or -1) < (tonumber(N.tab("Upgrades")[c.name]) or 0) or N.cash() < (c.cashBefore or 0) - c.price * 0.5 or d == nil
		elseif c.kind == "net" then
			return (c.levelBefore or -1) < (tonumber(d.OfflineNetLevel) or 1) or N.cash() < (c.cashBefore or 0) - c.price * 0.5
		end
		return false
	end
	function N.rejoin(reason)
		local keep = Toggles.KeepOnTeleport
		if not (keep and keep.Value) then
			log("REJOIN skipped", "Keep after teleport is off", "reason=" .. tostring(reason))
			return false
		end
		if os.clock() - (N.World.rejoinAt or -1e9) < 600 then
			return false
		end
		N.World.rejoinAt = os.clock()
		local obj = N.event("IdleRejoin")
		if not obj then
			log("NO REMOTE", "IdleRejoin")
			return false
		end
		log("REJOIN", "reason=" .. tostring(reason), "(IdleRejoin: the server saves and moves us, the hub restarts after the teleport)")
		flushLog(true)
		N.Sent.count += 1
		N.Sent.byName.IdleRejoin = (N.Sent.byName.IdleRejoin or 0) + 1
		return (pcall(function()
			obj:Fire(true, { AutoFishing = false, DoubleSpeed = N.data().IsInGroup == true })
		end))
	end
	N.listen("Teleport", function(answer)
		if type(answer) == "table" and answer.Success == false then
			N.World.refused = tostring(answer.World) .. " " .. brief(answer)
		end
	end)
	function N.cutscene()
		local AF = N.findAutoFishing and N.findAutoFishing()
		local C = AF and AF.Controllers
		local cut = C and C.Cutscene
		return if type(cut) == "table" and type(cut.Play) == "function" then cut else nil
	end
	function N.travel(key)
		if not key or N.worldKey() == key then
			return true
		end
		if N.due("cutsceneOff", 3600) then
			send("Settings", "TeleportCutscene", false)
		end
		N.pauseFishing("travel to " .. tostring(key))
		setStatus("Travelling to " .. tostring(key))
		local before = N.worldFolder()
		local cut = N.cutscene()
		local function go()
			N.World.refused = nil
			if cut then
				pcall(cut.Play, cut, key)
			end
			send("Teleport", key)
			waitFor(function()
				return N.worldKey() == key or N.World.refused ~= nil
			end, 30)
			return N.worldKey() == key
		end
		local ok = go()
		if not ok and N.World.refused and string.find(string.lower(N.World.refused), "reel", 1, true) then
			log("WORLD line still out", tostring(key), "cancelling the throw and travelling again")
			send("CancelThrow")
			task.wait(1.5)
			ok = go()
		end
		if ok then
			waitFor(function()
				local folder = N.worldFolder()
				return folder ~= nil and folder ~= before and folder:FindFirstChild("Interactable") ~= nil
			end, 8)
		end
		task.wait(1.5)
		N.World.last = (if ok then "Arrived in " else "Could not reach ") .. tostring(key)
		local loaded = N.worldFolder()
		log("WORLD", if ok then "arrived" else "failed", tostring(key), "client world=" .. (if loaded then loaded.Name else "none"), if cut then "(game travel)" else "(remote only)", if N.World.refused then "refused=" .. N.World.refused else "")
		if ok then
			N.World.fails = 0
		elseif N.World.refused then
			N.World.failAt = os.clock()
		else
			N.World.fails = (if os.clock() - (N.World.failAt or -1e9) < 600 then (N.World.fails or 0) else 0) + 1
			N.World.failAt = os.clock()
			if N.World.fails >= 2 then
				N.World.fails = 0
				N.rejoin("world change to " .. tostring(key) .. " failed twice")
			end
		end
		N.resumeFishing()
		return ok
	end
	local ShopSpot = { rod = "Rods", bait = "Baits" }
	N.Hall = { last = "-", answer = nil }
	for _, hallName in ipairs({ "Cave", "Maze" }) do
		N.listen(hallName, function(kind, a)
			N.Hall.answer = tostring(kind) .. (if a ~= nil then " " .. tostring(a) else "")
		end)
	end
	function N.claimHallRod(c, why, probe)
		local HC = cfg(tostring(c.hall) .. "Config")
		if not (HC and N.hallReady(c.hall)) then
			return false
		end
		local back = N.worldKey()
		N.pauseFishing("hall rod " .. tostring(c.name))
		setStatus((if probe then "Checking the way to the " else "Claiming the ") .. tostring(c.name) .. " in the " .. tostring(c.hall))
		local function finish(ok, text)
			N.Hall.last = text
			if probe then
				local result = if ok then "reachable" else "unreachable"
				N.memo("hall_rod_" .. tostring(c.hall), result)
				log("PROBE", "hall_rod", "hall=" .. tostring(c.hall), "result=" .. result, text)
			else
				log(if ok then "HALL rod ok" else "HALL rod FAILED", tostring(c.name), text)
			end
			local home = N.bestFishingWorld()
			N.travel(if back ~= HC.SubWorld and back ~= "Pond" then back else home)
			N.resumeFishing()
			return ok
		end
		if N.worldKey() ~= HC.SubWorld then
			if N.worldKey() ~= HC.World and not N.travel(HC.World) then
				return finish(false, "could not reach " .. tostring(HC.World))
			end
			N.Hall.answer = nil
			if not N.travel(HC.SubWorld) then
				return finish(false, "the gate did not let us in (" .. tostring(N.Hall.answer or "no answer") .. ")")
			end
		end
		local root = workspace:FindFirstChild("World")
		local folder = (root and root:FindFirstChild(HC.SubWorld)) or N.worldFolder()
		local hallRoom = folder and folder:FindFirstChild("FishHall", true)
		local pedestal = hallRoom and hallRoom:FindFirstChild("RodPedestal", true)
		local display = pedestal and pedestal:FindFirstChild("RodDisplay", true)
		local pos
		pcall(function()
			pos = if display and display:IsA("Attachment") then display.WorldPosition elseif pedestal then pedestal:GetPivot().Position else nil
		end)
		if not pos then
			return finish(false, "no RodPedestal in " .. tostring(HC.SubWorld))
		end
		N.tp(pos + Vector3.new(0, 3, 0))
		task.wait(0.6)
		N.Hall.answer = nil
		local cashBefore = N.cash()
		send(c.hall, "ClaimRod")
		local ok = waitFor(function()
			return N.tab("Rods")[c.name] ~= nil or (probe and N.Hall.answer ~= nil)
		end, 4)
		ok = N.tab("Rods")[c.name] ~= nil
		if probe and not ok then
			local answer = tostring(N.Hall.answer or "no answer")
			return finish(string.sub(answer, 1, 6) == "NoCash", "answer=" .. answer .. " (cash " .. formatNumber(N.cash()) .. " of " .. formatNumber(c.price) .. ")")
		end
		if ok then
			N.spent(math.max(cashBefore - N.cash(), 0))
			Session.rods += 1
			N.Shop.last = string.format("rod %s for %s (%s)", tostring(c.name), formatNumber(c.price), tostring(c.hall))
			log("BUY", "rod", tostring(c.name), "price=" .. formatNumber(c.price), "payback=" .. (if c.payback then string.format("%.1fh", c.payback) else "-"), why or "", "hall=" .. tostring(c.hall))
			if N.Events.bought then
				pcall(N.Events.bought, c.name, c.price)
			end
			return finish(true, "claimed at the pedestal, answer=" .. tostring(N.Hall.answer or "-"))
		end
		return finish(false, "answer=" .. tostring(N.Hall.answer or "no data change"))
	end
	function N.hallProbeStep()
		if not (N.planner() or on("AutoRods")) or not N.due("hallProbe", 120) then
			return false
		end
		if N.whaleWindow and N.whaleWindow() then
			return false
		end
		local rods = N.sh("Content.Item.Rod")
		for name, def in pairs(rods and type(rods.Items) == "table" and rods.Items or {}) do
			local hall = N.hallOf(def)
			local price = tonumber(def.Price) or 0
			if hall and N.hallReady(hall) and N.tab("Rods")[name] == nil and N.memo and not N.memo("hall_rod_" .. hall) and N.cash() < price then
				return N.claimHallRod({ kind = "rod", name = name, price = price, hall = hall }, "probe", true)
			end
		end
		return false
	end
	function N.buy(c, why)
		if c.kind == "rod" and c.hall then
			return N.claimHallRod(c, why)
		end
		local before = N.cash()
		c.cashBefore = before
		c.levelBefore = if c.kind == "net" then (tonumber(N.data().OfflineNetLevel) or 1) else (tonumber(N.tab("Upgrades")[c.name]) or 0)
		local function fire()
			if c.kind == "upgrade" then
				send("Upgrades", "Buy", c.name)
			elseif c.kind == "net" then
				send("OfflineNet", "Buy")
			elseif c.kind == "rod" then
				send("RodShop", "Buy", c.name)
			elseif c.kind == "world" then
				N.travel(c.name)
			end
		end
		local spotName = ShopSpot[c.kind]
		local back
		if spotName and N.Shop.near[c.kind] then
			back = N.myPos()
			N.pauseFishing("shop")
			local pos = N.spot(spotName)
			if pos then
				N.goTo(pos, 10)
			end
		end
		fire()
		local ok = waitFor(function()
			return owned(c) or N.cash() <= before - c.price * 0.5
		end, 3)
		if not ok and spotName and not N.Shop.near[c.kind] then
			local pos = N.spot(spotName)
			if pos then
				N.pauseFishing("shop probe")
				back = N.myPos()
				N.goTo(pos, 10)
				fire()
				ok = waitFor(function()
					return owned(c) or N.cash() <= before - c.price * 0.5
				end, 3)
				N.Shop.near[c.kind] = ok or nil
				log("SHOP probe", c.kind, "far=fail", "near=" .. (if ok then "ok" else "fail"))
			end
		end
		if back then
			N.resumeFishing()
		end
		if ok then
			N.spent(c.price)
			if c.kind == "rod" then
				Session.rods += 1
				send("RodShop", "Equip", c.name)
			elseif c.kind == "upgrade" or c.kind == "net" then
				Session.upgrades += 1
			elseif c.kind == "world" then
				Session.worlds += 1
			end
			N.Shop.last = string.format("%s %s for %s", c.kind, c.name, formatNumber(c.price))
			log("BUY", c.kind, c.name, "price=" .. formatNumber(c.price), "payback=" .. (if c.payback then string.format("%.1fh", c.payback) else "-"), why or "")
			if N.Events.bought then
				pcall(N.Events.bought, c.name, c.price)
			end
		else
			log("BUY failed", c.kind, c.name, "price=" .. formatNumber(c.price))
		end
		return ok
	end
	function N.equipBestRod()
		local d = N.data()
		local best, bestScore = d.RodEquipped, nil
		for name in pairs(N.tab("Rods")) do
			local l, s = rodPower(name)
			local score = l * 2 + s
			if not bestScore or score > bestScore then
				best, bestScore = name, score
			end
		end
		local curL, curS = rodPower(d.RodEquipped or "Wooden Rod")
		if best and best ~= d.RodEquipped and bestScore > curL * 2 + curS then
			send("RodShop", "Equip", best)
			log("ROD equip", best)
			return true
		end
		return false
	end
	function N.spendStep()
		local list = N.candidates()
		P.list = list
		local horizon = N.horizon()
		P.horizon = horizon
		if N.planner() and not N.rateMeasured() then
			P.need, P.eta = nil, nil
			P.say = N.modeText() .. ": measuring the income first (about a minute), then buying by payback"
			if P.lastKey ~= "unmeasured" then
				P.lastKey, P.lastAt = "unmeasured", os.clock()
				log("PLAN rate not measured yet, fishing first")
			end
			return false
		end
		if N.planner() then
			local net = N.netCandidate()
			if net and N.cash() - N.reserve() >= net.price * 500 and net.payback <= horizon and N.buy(net, "planner spare cash") then
				return true
			end
			local best = list[1]
			local pick, fund
			P.need, P.eta = nil, nil
			local cash = N.cash()
			local _, sellable, value = N.fishStats(true)
			local funds = cash + value * 0.95
			if best and best.payback <= horizon then
				if cash >= best.price then
					pick = best
				elseif sellable > 0 and funds >= best.price then
					fund = best
				else
					P.need = best
					P.eta = math.max(best.price - funds, 0) / N.incomeRate() / 3600
					local limit = math.min(P.eta, horizon)
					local rate = N.incomeRate()
					for _, c in ipairs(list) do
						local goesFirst
						if best.kind == "world" and best.cost then
							goesFirst = c.price < best.price and N.beatsWorld(c, best, funds, rate)
						else
							goesFirst = c.paybackNow <= limit
						end
						if c ~= best and goesFirst then
							if cash >= c.price then
								pick = c
								break
							elseif sellable > 0 and funds >= c.price then
								fund = c
								break
							end
						end
					end
				end
			end
			local function saving(c)
				return string.format("saving for %s: %s (payback %.1f h, about %s)", c.name, formatNumber(c.price), c.payback, N.longTime(P.eta * 3600))
			end
			local action = if pick
				then pick.name
				elseif fund then fund.name .. " (sell first)"
				elseif P.need then "- (fishing, " .. saving(P.need) .. ")"
				else "-"
			local key = (best and best.name or "-") .. "/" .. (if not pick and not fund and P.need then "saving " .. P.need.name .. string.format("/%.0f/%.0f", math.log(math.max(P.need.payback, 0.01)) / 0.2, math.log(math.max(P.eta * 60, 1)) / 0.2) else action)
			if key ~= P.lastKey or os.clock() - P.lastAt > 60 then
				P.lastKey, P.lastAt = key, os.clock()
				local parts = {}
				for i = 1, math.min(5, #list) do
					local c = list[i]
					if (c.g or 0) <= 0.0005 or (tonumber(c.payback) or math.huge) > 1e5 then
						table.insert(parts, string.format("%s %s %s no gain", c.kind, c.name, formatNumber(c.price)))
					else
						table.insert(parts, string.format("%s %s %s payback %.1fh (today %.1fh, +%d%%)", c.kind, c.name, formatNumber(c.price), c.payback, c.paybackNow or c.payback, math.floor((c.g or 0) * 100)))
					end
				end
				log("PLAN", "rate=" .. formatNumber(N.incomeRate()) .. "/s", "horizon=" .. string.format("%.1fh", horizon), "best: " .. (if #parts > 0 then table.concat(parts, " | ") else "-"), "buy=" .. action)
			end
			local fishing = N.modeText()
			P.say = if pick
				then string.format("Buying %s (%s, payback %.1f h), then %s", pick.name, formatNumber(pick.price), pick.payback, string.lower(fishing))
				elseif fund then string.format("Selling the backpack to buy %s (%s, payback %.1f h)", fund.name, formatNumber(fund.price), fund.payback)
				elseif P.need then fishing .. ", " .. saving(P.need)
				else string.format("%s. Nothing pays back within %.0f h yet", fishing, horizon)
			if fund then
				N.sellNow("fund " .. fund.name)
				if N.cash() >= fund.price then
					pick = fund
				else
					P.need = fund
					P.eta = math.max(fund.price - N.cash(), 0) / N.incomeRate() / 3600
					P.say = fishing .. ", " .. saving(fund)
					log("PLAN fund short", fund.name, "cash=" .. formatNumber(N.cash()), "price=" .. formatNumber(fund.price), "eta=" .. N.longTime(P.eta * 3600))
				end
			end
			if pick then
				if N.buy(pick, "planner") then
					P.need, P.eta = nil, nil
					N.equipBestRod()
					return true
				end
			end
			return false
		end
		P.need = nil
		local cheapest
		for _, c in ipairs(list) do
			if N.cash() >= c.price and (c.kind ~= "rod" or on("AutoRods")) then
				if c.kind == "world" and (on("AutoWorlds") or (c.name == "Pond" and on("AutoPond"))) then
					return N.buy(c, "plain")
				end
				if c.kind == "upgrade" and on("AutoUpgrades") and (not cheapest or c.price < cheapest.price) then
					cheapest = c
				end
			end
		end
		if on("AutoRods") then
			local bestRod
			for _, c in ipairs(list) do
				if c.kind == "rod" and N.cash() >= c.price and (not bestRod or c.frac > bestRod.frac) then
					bestRod = c
				end
			end
			if bestRod and N.buy(bestRod, "plain") then
				N.equipBestRod()
				return true
			end
		end
		if cheapest then
			return N.buy(cheapest, "plain")
		end
		return false
	end
	function N.worldStep()
		if not (on("AutoWorlds") or N.planner()) then
			return false
		end
		local best = N.bestFishingWorld()
		local cur = N.worldKey()
		if best ~= cur and not (N.worldCfg(cur) and N.worldCfg(cur).NoFishing and N.Pond.busy) then
			return N.travel(best)
		end
		return false
	end
	function N.protectStep()
		local n = 0
		for guid, item in pairs(N.inv()) do
			if n >= 25 then
				break
			end
			if type(item) == "table" and item.Type == "Fish" and not N.isLocked(item) and not N.relicOf(item) and not N.Sell.locked[guid] then
				if N.keeps(item) then
					send("Lock", "Toggle", guid)
					N.Sell.locked[guid] = true
					if N.cargoKeeps and N.cargoKeeps(item) then
						N.Cargo.lockedFor[guid] = true
					end
					n += 1
					task.wait(0.1)
				end
			end
		end
		if n > 0 then
			log("SELL protect locked", n)
		end
		return n
	end
	function N.sellNow(reason)
		local _, sellable, value = N.fishStats(true)
		if sellable == 0 then
			return false
		end
		N.protectStep()
		if on("AutoRelics") then
			N.useSellRelics()
		end
		local restore = if N.salePrep then N.salePrep(reason) else nil
		local multText = if N.saleMultText then N.saleMultText() else nil
		local predicted = if N.salePredict then N.salePredict() else nil
		local cashBefore = N.cash()
		local function sell()
			local res = invoke("SellAll", "Fish", nil)
			local amount = type(res) == "table" and tonumber(res.Amount) or 0
			return amount > 0, res
		end
		local ok, res, back = false, nil, nil
		local tries = {}
		if not N.Sell.memoUsed and N.memo then
			N.Sell.memoUsed = true
			if N.memo("sell_route") == "npc" then
				N.Sell.needNpc = true
				N.Sell.needNpcAt = os.clock()
			end
		end
		if N.Sell.needNpc and os.clock() - (N.Sell.needNpcAt or 0) > 21600 then
			N.Sell.needNpc = nil
		end
		if not N.Sell.needNpc then
			ok, res = sell()
			table.insert(tries, "far=" .. (if ok then "ok" else brief(res)))
			if not ok then
				task.wait(1.5)
				ok, res = sell()
				table.insert(tries, "far2=" .. (if ok then "ok" else brief(res)))
			end
		end
		local pos
		if not ok then
			pos = N.spot("NPC_Sell")
			if pos then
				N.pauseFishing("sell trip")
				back = true
				N.goTo(pos, 8)
				task.wait(0.6)
				ok, res = sell()
				table.insert(tries, "npc=" .. (if ok then "ok" else brief(res)))
				if not ok then
					task.wait(1.5)
					ok, res = sell()
					table.insert(tries, "npc2=" .. (if ok then "ok" else brief(res)))
				end
				if ok and N.Sell.needNpc == nil and #tries >= 3 then
					N.Sell.needNpc = true
					N.Sell.needNpcAt = os.clock()
					if N.memo then
						N.memo("sell_route", "npc")
					end
				end
				log("SELL route", table.concat(tries, " "), "remember npc=" .. tostring(N.Sell.needNpc))
			end
		end
		if back then
			N.resumeFishing()
		end
		if restore then
			pcall(restore)
		end
		if ok then
			local got = tonumber(res.Value) or math.max(N.cash() - cashBefore, 0)
			if multText then
				log("SELL mult=" .. multText)
			end
			if N.sellRodProbe and predicted and not res.Boost then
				N.sellRodProbe(predicted, got)
			end
			Session.sold += tonumber(res.Amount) or 0
			Session.soldValue += got
			N.Sell.at = os.clock()
			N.Sell.last = string.format("%d fish for %s%s (%s)", tonumber(res.Amount) or 0, formatNumber(got), if res.Boost then " x" .. tostring(res.Boost) .. " " .. tostring(res.BoostName or "") else "", reason)
			log("SELL", "amount=" .. tostring(res.Amount), "value=" .. formatNumber(got), "boost=" .. tostring(res.Boost or 1), "reason=" .. reason, "near=" .. tostring(back == true))
			if N.Events.sold then
				pcall(N.Events.sold, tonumber(res.Amount) or 0, got)
			end
			N.Sell.lastFail, N.Sell.overSince = nil, nil
		else
			N.Sell.lastFail = string.format("the server sold nothing (NPC_Sell %s in %s, near=%s)", if pos then "found" else "missing", N.worldKey(), tostring(back == true))
			log("SELL failed", "fish=" .. sellable, "value=" .. formatNumber(value), N.Sell.lastFail, "answers: " .. table.concat(tries, " "))
		end
		return ok
	end
	function N.sellThreshold()
		local t = optionNumber("SellAt", 80) / 100
		if on("SellPotion") and N.coinsPotionGuid and N.coinsPotionGuid() and not N.potionActive("Coins") then
			t = math.max(t, 0.95)
		end
		return t
	end
	function N.sellWatch(count, max, sellable)
		local S2 = N.Sell
		if count / math.max(max, 1) < N.sellThreshold() then
			S2.overSince = nil
			return false
		end
		S2.overSince = S2.overSince or os.clock()
		if os.clock() - math.max(S2.overSince, S2.at or 0) < 300 or not N.due("sellStall", 300) then
			return false
		end
		local reason
		if sellable == 0 then
			reason = string.format("all %d fish are locked or kept (the game's Auto Lock=%s, Keep lists, cargo order)", count, tostring(N.data().AutoLock or "None"))
		elseif S2.lastFail then
			reason = S2.lastFail
		else
			reason = "no sale was tried (status: " .. tostring(Status) .. ")"
		end
		log("SELL stalled", "reason=" .. reason, "backpack=" .. count .. "/" .. max, "sellable=" .. sellable, "world=" .. N.worldKey())
		S2.needNpc = nil
		S2.locked = {}
		if sellable == 0 then
			setStatus("Smart Sell: every fish is locked or kept, nothing to sell")
			return false
		end
		return N.sellNow("watchdog")
	end
	function N.sellStep()
		if not N.wants("SmartSell") or not N.due("sellCheck", 5) then
			return false
		end
		local count, max = N.backpack()
		local _, sellable, value = N.fishStats()
		if N.sellWatch(count, max, sellable) then
			return true
		end
		if sellable == 0 then
			return false
		end
		local fill = count / math.max(max, 1)
		local boost = tonumber(workspace:GetAttribute("ServerCash")) or 1
		local reason
		local SS = N.SaleStack
		if fill >= N.sellThreshold() then
			reason = string.format("backpack %d%%", math.floor(fill * 100))
		elseif boost > 1 and sellable >= 5 then
			reason = "CashBoost x" .. boost
		elseif SS and SS.potionUntil > 0 and N.serverTime() >= SS.potionUntil - 10 and sellable >= 5 then
			SS.potionUntil = 0
			reason = "Coins potion ends"
		elseif N.planner() and P.need and N.cash() < P.need.price and N.cash() + value * 0.95 >= P.need.price then
			reason = "fund " .. P.need.name
		elseif optionNumber("SellEvery", 0) > 0 and os.clock() - N.Sell.at >= optionNumber("SellEvery", 0) * 60 then
			reason = "timer"
		elseif (tonumber(N.data().Tutorial) or 100) == 4 then
			reason = "tutorial first sale"
		end
		if not reason then
			return false
		end
		return N.sellNow(reason)
	end
	function N.baitStep()
		if not N.wants("AutoBait") or not N.due("bait", 10) then
			return false
		end
		local active = 0
		for _, n in pairs(N.tab("ActiveBaits")) do
			active += tonumber(n) or 0
		end
		if active > 0 then
			return false
		end
		local baits = N.sh("Content.Item.Bait")
		local defs = baits and type(baits.Items) == "table" and baits.Items or {}
		local bestGuid, bestLuck, bestAmount
		for _, entry in ipairs(N.itemsOf("Bait")) do
			local def = defs[entry.item.Name]
			local luck = def and tonumber(def.Luck) or 0
			if not bestGuid or luck > bestLuck then
				bestGuid, bestLuck = entry.guid, luck
				bestAmount = tonumber(type(entry.item.Data) == "table" and entry.item.Data.Amount) or 1
			end
		end
		if bestGuid then
			local n = math.clamp(bestAmount, 1, 10)
			send("ConsumeBait", bestGuid, n)
			Session.baits += n
			log("BAIT use", "luck=" .. tostring(bestLuck), "x" .. n, "=" .. (n * 5) .. " casts")
			return true
		end
		if not N.wants("BuyBait") then
			return false
		end
		local perCast = math.max(N.Fish.evCast, N.incomeRate() * math.max(N.Fish.cycle, 15))
		local budget = perCast * optionNumber("BaitBudget", 10) / 100
		local free = N.cash() - N.reserve()
		local pick, pickLuck
		local K, base = N.castScale()
		local none = if base then N.castModel({ bait = false }) else nil
		if base and none then
			local pickNet
			for name, def in pairs(defs) do
				local price = tonumber(def.Price) or math.huge
				if price * 2 <= free and (N.Shop.stockOut[name] or 0) < os.clock() then
					local c = N.castModel({ bait = def })
					local net = if c then (c - none) * K - price / 5 else -1
					if net > 0 and (not pickNet or net > pickNet) then
						pick, pickNet, pickLuck = name, net, tonumber(def.Luck) or 0
					end
				end
			end
		else
			for name, def in pairs(defs) do
				local price = tonumber(def.Price) or math.huge
				if price / 5 <= budget and price * 2 <= free and (N.Shop.stockOut[name] or 0) < os.clock() and (not pick or (tonumber(def.Luck) or 0) > pickLuck) then
					pick, pickLuck = name, tonumber(def.Luck) or 0
				end
			end
		end
		if not pick then
			return false
		end
		local price = tonumber(defs[pick].Price) or 0
		local count = if price * 10 <= free * 0.05 then 10 else 2
		local before = #N.itemsOf("Bait")
		send("BaitShop", "Buy", pick, count)
		if not waitFor(function()
			return #N.itemsOf("Bait") > before
		end, 3) then
			N.Shop.stockOut[pick] = os.clock() + 300
			log("BAIT buy failed", pick, "(out of stock or too far), retry in 5m")
			return false
		end
		log("BAIT buy", pick, "x" .. count, "cost/cast=" .. formatNumber(price / 5), "cast value=" .. formatNumber(perCast))
		return true
	end
	local function pondCount(key)
		local n = 0
		for _, f in pairs(type(N.tab("Pond")[key]) == "table" and N.tab("Pond")[key] or {}) do
			if f ~= nil then
				n += 1
			end
		end
		return n
	end
	local function pondPart(name)
		local folder = N.worldFolder()
		local inter = folder and folder:FindFirstChild("Interactable")
		local inst = (inter and inter:FindFirstChild(name)) or (folder and folder:FindFirstChild(name, true))
		if inst and not inst:IsA("BasePart") then
			inst = inst:FindFirstChild("SurfacePart", true) or inst:FindFirstChildWhichIsA("BasePart", true)
		end
		return inst
	end
	local function pondPending(pond)
		local PondMod = N.sh("Modules.Pond")
		local p = tonumber(pond.PendingIncome) or 0
		pcall(function()
			p = math.max(p, tonumber(PondMod:Project(pond, N.serverTime())) or 0)
		end)
		return p
	end
	N.pondPending = pondPending
	function N.pondStep()
		if not N.wants("AutoPond") then
			return false
		end
		if not N.unlocked("Pond") then
			return false
		end
		if N.tripBlocked and N.whaleWindow() then
			N.tripBlocked("pond")
			return false
		end
		if not N.due("pondCheck", 30) then
			return false
		end
		local pond = N.tab("Pond")
		local PondMod = N.sh("Modules.Pond")
		local cfgPond = N.sh("Config.PondConfig") or {}
		local hourly = 0
		pcall(function()
			hourly = PondMod:BaseRate(pond) * 3600
		end)
		N.Pond.hourly = hourly
		local pending = pondPending(pond)
		local level = tonumber(pond.Level) or 1
		local upPrice = type(cfgPond.CapacityPrices) == "table" and tonumber(cfgPond.CapacityPrices[level]) or nil
		local upTo = type(cfgPond.CapacityLevels) == "table" and cfgPond.CapacityLevels[level + 1] or nil
		local canUpgrade = upPrice ~= nil and upTo ~= nil and N.cash() >= upPrice * 2 and os.clock() >= (N.Pond.upgradeHold or 0)
		local maxHours = tonumber(cfgPond.MaxPendingHours) or 8
		local since = os.clock() - (N.Pond.at or -1e9)
		local stockNow, stockMax = tonumber(pond.Stock) or 0, 0
		pcall(function()
			stockMax = tonumber(PondMod:MaxStock(pond)) or 0
		end)
		pcall(function()
			local _, s = PondMod:Project(pond, N.serverTime())
			stockNow = tonumber(s) or stockNow
		end)
		N.Pond.stock, N.Pond.stockMax = stockNow, stockMax
		local due
		if N.planner() then
			local P = N.Plan
			local completes = false
			if P and type(P.need) == "table" and tonumber(P.need.price) then
				local _, _, value = N.fishStats(true)
				local funds = N.cash() + (tonumber(value) or 0) * 0.95
				completes = funds < P.need.price and funds + pending >= P.need.price
			end
			local foodLow = stockMax > 0 and next(type(pond.Fish) == "table" and pond.Fish or {}) ~= nil and stockNow < stockMax * 0.5
			due = since >= 600 and (canUpgrade or completes or foodLow or (hourly > 0 and pending >= hourly * (maxHours - 1)) or since >= 3 * 3600)
		else
			due = since >= optionNumber("PondEvery", 60) * 60
		end
		if not due then
			return false
		end
		N.Pond.at = os.clock()
		local back = N.worldKey()
		N.Pond.busy = true
		if not N.travel("Pond") then
			N.Pond.busy = false
			return false
		end
		setStatus("Pond: collecting and feeding")
		pond = N.tab("Pond")
		local stored = tonumber(pond.PendingIncome) or 0
		local before = N.cash()
		local pad = pondPart("Collect")
		if pad then
			N.tp(pad.Position + Vector3.new(0, 3, 0))
			task.wait(0.5)
		end
		send("Pond", "Collect")
		local got = 0
		if stored >= 1 then
			local collected = waitFor(function()
				return (tonumber(N.tab("Pond").PendingIncome) or 0) < math.max(stored * 0.5, 1) and N.cash() > before
			end, 3)
			got = math.max(N.cash() - before, 0)
			if collected then
				log("POND collect ok", "got=" .. formatNumber(got), "pending was " .. formatNumber(stored))
			else
				log("POND collect FAILED", "pending=" .. formatNumber(tonumber(N.tab("Pond").PendingIncome) or 0), "pad=" .. tostring(pad ~= nil), "answer=no data change")
			end
		end
		local fishBefore = pondCount("Fish")
		send("Pond", "EquipBest")
		waitFor(function()
			return pondCount("Fish") ~= fishBefore
		end, 1.5)
		pond = N.tab("Pond")
		local dead = 0
		for _, f in pairs(type(pond.Fish) == "table" and pond.Fish or {}) do
			if type(f) == "table" and f.Dead then
				dead += 1
			end
		end
		if dead > 0 then
			if on("AutoPond") then
				send("Pond", "ReviveHeart")
				task.wait(1)
			end
			send("Pond", "SellAllDead")
			task.wait(0.5)
			log("POND dead fish", dead, if on("AutoPond") then "revived or sold" else "sold")
		end
		local foods = N.sh("Content.Item.Food")
		local stock, maxStock = tonumber(pond.Stock) or 0, 0
		pcall(function()
			maxStock = PondMod:MaxStock(pond)
		end)
		pcall(function()
			local _, s = PondMod:Project(pond, N.serverTime())
			stock = tonumber(s) or stock
		end)
		if foods and type(foods.Items) == "table" and maxStock > 0 and stock < maxStock * 0.9 then
			local pick, pickMult
			for name, def in pairs(foods.Items) do
				local price = tonumber(def.Price) or math.huge
				if price <= math.max(hourly * 0.5, 300) and price * 3 <= N.cash() and (not pick or (tonumber(def.Multiplier) or 0) > pickMult) then
					pick, pickMult = name, tonumber(def.Multiplier) or 0
				end
			end
			if pick then
				local feed = math.max(tonumber(foods.Items[pick].Feed) or 25, 1)
				local upkeep = 0
				for _, f in pairs(type(pond.Fish) == "table" and pond.Fish or {}) do
					if type(f) == "table" and not f.Dead then
						local okU, u = pcall(function()
							return PondMod:UpkeepOf(f)
						end)
						upkeep += if okU and tonumber(u) then tonumber(u) else 0.72
					end
				end
				local function foodUnits()
					local n = 0
					for _, entry in ipairs(N.itemsOf("Food")) do
						n += math.max(tonumber(type(entry.item.Data) == "table" and entry.item.Data.Amount) or 1, 1)
					end
					return n
				end
				local fill = math.max(math.ceil((maxStock - stock) / feed), 0)
				local spare = math.ceil(upkeep * 3 / feed)
				local buy = math.clamp(fill + spare - foodUnits(), 0, 12)
				for _ = 1, buy do
					send("Pond", "BuyFood", pick)
					task.wait(0.6)
				end
				task.wait(0.5)
				for _ = 1, fill do
					local live = tonumber(N.tab("Pond").Stock) or 0
					local items = N.itemsOf("Food")
					if live > maxStock - feed or #items == 0 then
						break
					end
					send("Pond", "AddFood", items[1].guid)
					task.wait(0.4)
				end
				local after = tonumber(N.tab("Pond").Stock) or 0
				log(if after > stock or after >= maxStock * 0.9 then "POND food ok" else "POND food FAILED", pick, "stock " .. string.format("%.1f -> %.1f of %.1f", stock, after, maxStock), "bought " .. buy, "spare " .. foodUnits() .. " for Auto Feed")
			end
		end
		if N.due("pondAutoFeed", 3600) then
			send("Settings", "AutoFeed", true)
		end
		if canUpgrade then
			local sign = pondPart("Stud Sign")
			if sign then
				N.tp(sign.Position + Vector3.new(0, 3, 0))
				task.wait(0.5)
			end
			send("Pond", "Upgrade")
			if waitFor(function()
				return (tonumber(N.tab("Pond").Level) or 1) > level
			end, 3) then
				N.spent(upPrice)
				N.Pond.upgradeFails = 0
				log("POND upgrade ok", formatNumber(upPrice), "capacity -> " .. tostring(upTo))
				local n = pondCount("Fish")
				send("Pond", "EquipBest")
				waitFor(function()
					return pondCount("Fish") > n
				end, 2)
			else
				N.Pond.upgradeFails = (N.Pond.upgradeFails or 0) + 1
				if N.Pond.upgradeFails >= 2 then
					N.Pond.upgradeHold = os.clock() + 3600
				end
				log("POND upgrade FAILED", formatNumber(upPrice), "level still " .. tostring(N.tab("Pond").Level), "sign=" .. tostring(sign ~= nil), "answer=no data change", if N.Pond.upgradeFails >= 2 then "(waits 1 h)" else "")
			end
		end
		if N.pondPetStep then
			N.pondPetStep(true)
		end
		Session.pondTrips += 1
		N.Pond.last = string.format("Collected %s, %d fish, level %s, %s/h", formatNumber(got), pondCount("Fish"), tostring(N.tab("Pond").Level or 1), formatNumber(hourly))
		log("POND trip", N.Pond.last)
		N.Pond.busy = false
		N.travel(back ~= "Pond" and back or N.bestFishingWorld())
		return true
	end
	N.Probe = { last = "-", names = { "ProbeSell2", "ProbeTpLocked", "ProbeStreakHold" } }
	do
		local ProbeFile = "Jiro/FISH_probes_" .. tostring(LocalPlayer.UserId) .. ".txt"
		local memory = {}
		pcall(function()
			if isfile(ProbeFile) then
				for line in string.gmatch(readfile(ProbeFile), "[^\n]+") do
					local key, result = string.match(line, "^(%S+)%s+(.+)$")
					if key then
						memory[key] = result
					end
				end
			end
		end)
		local function saveMemory()
			pcall(function()
				if makefolder and isfolder and not isfolder("Jiro") then
					makefolder("Jiro")
				end
				local lines = {}
				for key, result in pairs(memory) do
					table.insert(lines, key .. " " .. result)
				end
				table.sort(lines)
				writefile(ProbeFile, table.concat(lines, "\n"))
			end)
		end
		local function placeVersion()
			local ok, v = pcall(function()
				return game.PlaceVersion
			end)
			return tostring(if ok and v ~= nil then v else 0)
		end
		local function switchOff(name)
			local toggle = Toggles[name]
			if toggle and toggle.Value then
				local quiet = N.quiet
				N.quiet = true
				pcall(toggle.SetValue, toggle, false)
				N.quiet = quiet
			end
		end
		local function probeSell2()
			local guid, cheapest
			for g, item in pairs(N.inv()) do
				if type(item) == "table" and item.Type == "Fish" and not N.isLocked(item) and not N.relicOf(item) and not N.keeps(item) then
					local v = N.value(item)
					if not cheapest or v < cheapest then
						guid, cheapest = g, v
					end
				end
			end
			if not guid then
				return nil, "needs one cheap unprotected fish in the backpack"
			end
			N.pauseFishing("probe sell2")
			local pos = N.spot("NPC_Sell")
			if pos then
				N.goTo(pos, 8)
			end
			N.holdItem(guid)
			local a, b, done = nil, nil, 0
			task.spawn(function()
				a = invoke("Sell", guid)
				done += 1
			end)
			task.spawn(function()
				b = invoke("Sell", guid)
				done += 1
			end)
			waitFor(function()
				return done >= 2
			end, 12)
			N.resumeFishing()
			local x, y = tonumber(a) or 0, tonumber(b) or 0
			if done < 2 then
				return nil, "the sale did not answer in 12 s, trying again"
			elseif x > 0 and y > 0 then
				return string.format("DUPLICATE both paid %s + %s for one fish", formatNumber(x), formatNumber(y))
			elseif x > 0 or y > 0 then
				return string.format("refused the second sale (%s, %s)", formatNumber(x), formatNumber(y))
			end
			return "neither sale paid (not at the merchant or the fish is not for sale)"
		end
		local function probeTpLocked()
			local W = cfg("WorldsConfig")
			local key, def
			for k, w in pairs(W and type(W.Worlds) == "table" and W.Worlds or {}) do
				if not w.NoFishing and not N.unlocked(k) and N.level() < (tonumber(w.RequiredLevel) or 1) and (not def or (tonumber(w.WorldNumber) or 0) < (tonumber(def.WorldNumber) or 0)) then
					key, def = k, w
				end
			end
			if not key then
				return "n/a (no locked fishing world above this level)"
			end
			local back = N.worldKey()
			N.pauseFishing("probe tp_locked")
			send("Teleport", key)
			local moved = waitFor(function()
				return N.worldKey() == key
			end, 15)
			local context = string.format("%s level=%d needs=%s cash=%s price=%s", key, N.level(), tostring(def.RequiredLevel), formatNumber(N.cash()), formatNumber(tonumber(def.UnlockPrice) or 0))
			N.resumeFishing()
			if moved then
				N.travel(back)
				return "TRAVELLED, the server did not stop it: " .. context
			end
			return "refused: " .. context
		end
		local function probeStreakHold()
			local function heldUntil()
				return tonumber(LocalPlayer:GetAttribute("StreakHeldUntil")) or 0
			end
			local before = heldUntil()
			send("StreakHold", true)
			local held = waitFor(function()
				return heldUntil() > math.max(before, N.serverTime())
			end, 4)
			local seconds = heldUntil() - N.serverTime()
			task.wait(0.5)
			send("StreakHold", false)
			return if held then string.format("held %.0f s ahead (StreakHeldUntil set)", seconds) else "no hold (StreakHeldUntil unchanged)"
		end
		local Probes = {
			{ toggle = "ProbeSell2", name = "sell2", run = probeSell2 },
			{ toggle = "ProbeTpLocked", name = "tp_locked", run = probeTpLocked },
			{ toggle = "ProbeStreakHold", name = "streakhold", run = probeStreakHold },
		}
		function N.probeStep()
			for _, p in ipairs(Probes) do
				if on(p.toggle) and N.due("probe_" .. p.name, 20) then
					local key = p.name .. "@" .. placeVersion()
					if memory[key] then
						N.Probe.last = p.name .. ": " .. memory[key] .. " (remembered)"
						log("PROBE", p.name, "result=" .. memory[key], "(remembered for PlaceVersion " .. placeVersion() .. ")")
						switchOff(p.toggle)
						return false
					end
					local result, why = p.run()
					if result then
						memory[key] = result
						saveMemory()
						N.Probe.last = p.name .. ": " .. result
						log("PROBE", p.name, "result=" .. result)
						switchOff(p.toggle)
						return true
					end
					setStatus("Probe " .. p.name .. " waits: " .. tostring(why))
					if N.due("probeWait_" .. p.name, 300) then
						log("PROBE", p.name, "waiting", tostring(why))
					end
				end
			end
			return false
		end
	end
end
N.Learn = { names = { "HatchEgg", "EquipPet", "PetLevel", "Cargo", "Merchant", "Vault", "Volcano", "ThrowCharges", "Season" }, hooked = {}, templates = {}, memo = {}, replaying = false }
N.Streak = { held = false, menu = false, at = -1e9 }
N.Cargo = { keep = {}, missing = {}, at = -1e9, unitBonus = 0, unitWorth = 0, lockedFor = {}, denied = nil, waitCycle = nil, waitSince = 0, planned = nil, sent = 0, claims = 0, last = "-" }
N.Pets = { last = "-", lucks = {}, luckAt = -1e9, luck = 1 }
N.Eggs = { last = "Auto Hatch Eggs is off: eggs stay in the backpack", placeOff = false, placeFails = 0, trips = 0, hatched = 0, placed = 0 }
do
	local L = N.Learn
	local function placeVersion()
		local ok, v = pcall(function()
			return game.PlaceVersion
		end)
		return tostring(if ok and v ~= nil then v else 0)
	end
	N.placeVersion = placeVersion
	local LearnFile = "Jiro/FISH_learned_" .. tostring(LocalPlayer.UserId) .. ".txt"
	local function isGuid(v)
		return type(v) == "string" and (N.inv()[v] ~= nil or (#v == 12 and string.match(v, "^%x+$") ~= nil))
	end
	local function save()
		pcall(function()
			if makefolder and isfolder and not isfolder("Jiro") then
				makefolder("Jiro")
			end
			local disk = {}
			pcall(function()
				if isfile and isfile(LearnFile) then
					for line in string.gmatch(readfile(LearnFile), "[^\n]+") do
						local kind, key = string.match(line, "^(%a)\t([^\t]+)\t")
						if kind and key then
							disk[kind .. "\t" .. key] = line
						end
					end
				end
			end)
			for key, t in pairs(L.templates) do
				disk["T\t" .. key] = "T\t" .. key .. "\t" .. HttpService:JSONEncode(t)
			end
			for key, value in pairs(L.memo) do
				disk["M\t" .. key] = "M\t" .. key .. "\t" .. tostring(value)
			end
			local lines = {}
			for _, line in pairs(disk) do
				table.insert(lines, line)
			end
			table.sort(lines)
			writefile(LearnFile, table.concat(lines, "\n"))
		end)
	end
	pcall(function()
		if isfile and isfile(LearnFile) then
			for line in string.gmatch(readfile(LearnFile), "[^\n]+") do
				local kind, key, rest = string.match(line, "^(%a)\t([^\t]+)\t(.+)$")
				if kind == "T" then
					local ok, t = pcall(HttpService.JSONDecode, HttpService, rest)
					if ok and type(t) == "table" then
						L.templates[key] = t
					end
				elseif kind == "M" then
					L.memo[key] = rest
				end
			end
		end
	end)
	function N.learnRecord(name, args, quiet)
		local key = if type(args[1]) == "string" and not isGuid(args[1]) then args[1] else "-"
		local desc, guids = {}, 0
		for i = 1, args.n do
			local v = args[i]
			if isGuid(v) then
				desc[i] = { "g" }
				guids += 1
			elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
				desc[i] = { "v", v }
			elseif v == nil then
				desc[i] = { "n" }
			else
				desc[i] = { "t", brief(v) }
			end
		end
		local tkey = name .. "|" .. key .. "|" .. placeVersion()
		local fresh = L.templates[tkey] == nil
		L.templates[tkey] = { name = name, key = key, pv = placeVersion(), n = args.n, desc = desc, guids = guids }
		if fresh then
			if not quiet then
				log("SEEN", name, "args=" .. brief(args), "guids=" .. guids, "(the game's own client call)")
			end
			save()
		end
	end
	function N.learnHook()
		for _, name in ipairs(L.names) do
			if not L.hooked[name] then
				local obj = N.event(name)
				if obj and type(obj.Fire) == "function" then
					local fire = obj.Fire
					local ok = pcall(function()
						obj.Fire = function(self, reliable, ...)
							if not L.replaying and alive() then
								local args = table.pack(...)
								pcall(N.learnRecord, name, args)
							end
							return fire(self, reliable, ...)
						end
					end)
					L.hooked[name] = ok
				end
			end
		end
		if not L.versionLogged then
			L.versionLogged = true
			local pv = placeVersion()
			log("VERSION", "live=" .. pv, "built on=172", "seen shapes=" .. (function()
				local n = 0
				for _, t in pairs(L.templates) do
					if t.pv == pv then
						n += 1
					end
				end
				return n
			end)())
		end
	end
	function N.memo(key, value)
		if value == nil then
			return L.memo[key .. "@" .. placeVersion()]
		end
		L.memo[key .. "@" .. placeVersion()] = value
		save()
		return value
	end
	local function count(t)
		local n = 0
		for _ in pairs(type(t) == "table" and t or {}) do
			n += 1
		end
		return n
	end
	N.count = count
	local function cfg(name)
		local c = N.sh("Config." .. name)
		return if type(c) == "table" then c else nil
	end
	local function streakCount()
		local live = tonumber(LocalPlayer:GetAttribute("Streak")) or 0
		return math.max(live, tonumber(N.tab("CatchStreak").Count) or 0)
	end
	N.streakCount = streakCount
	function N.streakLuck()
		local SC = cfg("StreakConfig")
		local luck = 0
		pcall(function()
			local c = streakCount()
			for _, m in ipairs(SC.Milestones) do
				if c >= (tonumber(m.At) or math.huge) then
					luck = math.max(luck, tonumber(m.Luck) or 0)
				end
			end
		end)
		return 1 + luck
	end
	local LongTrips = { "pond", "hatchery", "merchant", "travel" }
	function N.streakHoldOn(why)
		local S2 = N.Streak
		if S2.held or not N.wants("KeepStreak") or streakCount() < 50 or not N.remoteExists("StreakHold") then
			return
		end
		S2.held = true
		send("StreakHold", true)
		local text = string.lower(tostring(why))
		for _, word in ipairs(LongTrips) do
			if string.find(text, word, 1, true) then
				S2.menu = true
				send("StreakHold", true, "Menu")
				break
			end
		end
		if os.clock() - S2.at > 60 then
			S2.at = os.clock()
			log("STREAK hold", "count=" .. streakCount(), "trip=" .. tostring(why), "menu=" .. tostring(S2.menu), "luck=x" .. string.format("%.2f", N.streakLuck()))
		end
	end
	function N.streakHoldOff()
		local S2 = N.Streak
		if S2.held then
			S2.held = false
			send("StreakHold", false)
			if S2.menu then
				S2.menu = false
				send("StreakHold", false, "Menu")
			end
		end
	end
	local function eggDrop()
		local BE = cfg("BossEventConfig")
		local ev = BE and type(BE.Events) == "table" and BE.Events.EggDrop or nil
		local s = type(ev) == "table" and ev.Scheduled or nil
		return tonumber(s and s.WindowSeconds) or 1800, tonumber(s and s.Offset) or 900, tonumber(ev and ev.LeadSeconds) or 24, tonumber(s and s.DurationSeconds) or 324
	end
	function N.whaleWindow(t)
		t = t or N.serverTime()
		local W = cfg("WhaleEventConfig")
		if W and type(W.EggsOpen) == "function" then
			local ok, yes = pcall(W.EggsOpen, t)
			if ok and type(yes) == "boolean" then
				return yes
			end
		end
		local window, offset, lead, duration = eggDrop()
		local p = t % window
		return p >= offset + lead and p < offset + duration
	end
	function N.whaleIn(t)
		t = t or N.serverTime()
		if N.whaleWindow(t) then
			return 0
		end
		local window, offset, lead = eggDrop()
		local p = t % window
		local open = offset + lead
		return if p < open then open - p else window - p + open
	end
	function N.whaleActive()
		if N.whaleWindow() then
			return true
		end
		local W = cfg("WhaleEventConfig")
		if not (W and type(W.IsActive) == "function") then
			return false
		end
		local ok, yes = pcall(W.IsActive, N.serverTime())
		return ok and yes == true
	end
	function N.tripBlocked(what)
		if not N.whaleWindow() then
			return false
		end
		local window = math.floor(N.serverTime() / 1800)
		if N.Streak.whaleLogged ~= window then
			N.Streak.whaleLogged = window
			log("WHALE window", "eggs open, casting only in " .. N.worldKey(), "trips wait (" .. tostring(what) .. ")")
		end
		return true
	end
	local function order()
		local o = N.tab("Cargo").Order
		return if type(o) == "table" then o else nil
	end
	local function cycleNow()
		local CC = cfg("CargoConfig")
		local secs = tonumber(CC and CC.CycleSeconds) or 21600
		return math.floor(N.serverTime() / secs)
	end
	local function mutationOf(item)
		local text = N.sh("Modules.ItemDataToText")
		if type(text) == "table" and type(text.GetMutation) == "function" then
			local ok, m = pcall(text.GetMutation, item)
			if ok then
				return m
			end
		end
		return type(item.Data) == "table" and item.Data.Mutation or nil
	end
	local function matches(slot, item)
		if type(item) ~= "table" or item.Type ~= slot.Type or item.Name ~= slot.Name then
			return false
		end
		return slot.Type ~= "Fish" or mutationOf(item) == slot.Mutation
	end
	local function listed(item)
		local def = N.fishDef(item.Name)
		return selected(Options.KeepRarities, def and def.Rarity or "Common") or selected(Options.KeepFish, tostring(item.Name)) or (on("KeepMutated") and type(item.Data) == "table" and item.Data.Mutation ~= nil)
	end
	local function amountOf(item)
		return math.max(tonumber(type(item.Data) == "table" and item.Data.Amount) or 1, 1)
	end
	local function rewardWorth(o)
		local worth, cash = 0, 0
		for _, r in ipairs(type(o.Rewards) == "table" and o.Rewards or {}) do
			if type(r) == "table" then
				if r.Type == "Currency" or r.Name == "Cash" then
					cash += tonumber(r.Amount) or 0
				elseif r.Type == "Potion" and N.potionWorth then
					worth += N.potionWorth(tostring(r.Name), tonumber(r.Duration))
				elseif r.Type == "Chest" then
					local Ch = N.sh("Content.Item.Chest")
					local def = Ch and type(Ch.Items) == "table" and Ch.Items[tostring(r.Name)]
					if type(def) == "table" and type(def.CoinCasts) == "table" then
						local casts = ((tonumber(def.CoinCasts[1]) or 0) + (tonumber(def.CoinCasts[2]) or 0)) / 2
						worth += casts * (tonumber(N.Fish.evCast) or 0) * (tonumber(r.Amount) or 1)
					end
				elseif r.Type == "Egg" and N.eggValue then
					worth += N.eggValue(tostring(r.Name)) * (tonumber(r.Amount) or 1)
				end
			end
		end
		return cash + worth, cash
	end
	function N.cargoRefresh(force)
		local C = N.Cargo
		if not force and os.clock() - C.at < 5 then
			return C.keep
		end
		C.at = os.clock()
		local keep, missing, units = {}, {}, 0
		local o = order()
		if o and not o.Sent and type(o.Slots) == "table" then
			local fish = {}
			for guid, item in pairs(N.inv()) do
				local handLocked = type(item) == "table" and N.isLocked(item) and not C.lockedFor[guid]
				if type(item) == "table" and item.Type == "Fish" and not N.relicOf(item) and not listed(item) and not handLocked then
					table.insert(fish, { guid = guid, item = item, v = N.cachedValue(guid, item) })
				end
			end
			table.sort(fish, function(a, b)
				return a.v < b.v
			end)
			local used = {}
			for _, slot in ipairs(o.Slots) do
				if type(slot) == "table" then
					local left = (tonumber(slot.Need) or 0) - (tonumber(slot.Given) or 0)
					units += tonumber(slot.Need) or 0
					if slot.Type == "Fish" and left > 0 then
						for _, f in ipairs(fish) do
							if left <= 0 then
								break
							end
							if not used[f.guid] and matches(slot, f.item) then
								used[f.guid] = true
								keep[f.item] = f.guid
								left -= 1
							end
						end
						if left > 0 then
							local key = tostring(slot.Name) .. "|" .. tostring(slot.Mutation or "-")
							missing[key] = (missing[key] or 0) + left
						end
					end
				end
			end
		end
		C.keep, C.missing = keep, missing
		local worth, cash = 0, 0
		if o then
			worth, cash = rewardWorth(o)
		end
		C.unitBonus = if units > 0 then cash / units else 0
		C.unitWorth = if units > 0 then worth / units else 0
		return keep
	end
	function N.cargoKeeps(item)
		return N.wants("AutoCargo") and N.cargoRefresh()[item] ~= nil
	end
	function N.cargoBonus(name, mutation, value)
		if not N.wants("AutoCargo") then
			return value
		end
		local C = N.Cargo
		if (C.missing[tostring(name) .. "|" .. tostring(mutation or "-")] or 0) > 0 then
			return math.max(value, C.unitWorth)
		end
		return value
	end
	local function slotsDone(o)
		local done, total = 0, 0
		for _, slot in ipairs(type(o.Slots) == "table" and o.Slots or {}) do
			if type(slot) == "table" then
				total += 1
				if (tonumber(slot.Given) or 0) >= (tonumber(slot.Need) or 0) then
					done += 1
				end
			end
		end
		return done, total
	end
	function N.cargoText()
		local o = order()
		local cargo = N.tab("Cargo")
		local voyage = cargo.Voyage
		local lines = {}
		if type(voyage) == "table" then
			local left = (tonumber(voyage.ReturnAt) or 0) - N.serverTime()
			table.insert(lines, if left > 0 then "Ship at sea, back in " .. N.longTime(left) else "Ship is back: claiming the reward")
		end
		if not o or o.Cycle ~= cycleNow() then
			table.insert(lines, "No order for this cycle yet (one every 6 hours)")
		else
			local done, total = slotsDone(o)
			local worth, cash = rewardWorth(o)
			local kept = count(N.Cargo.keep)
			table.insert(lines, string.format("Order tier %s: %d/%d slots%s", tostring(o.Tier or "?"), done, total, if o.Sent then ", sent" else ""))
			local extras = {}
			for _, r in ipairs(type(o.Rewards) == "table" and o.Rewards or {}) do
				if type(r) == "table" and r.Type ~= "Currency" and r.Type ~= "XP" and r.Name ~= "Cash" then
					table.insert(extras, if r.Type == "Potion" then tostring(r.Name) .. " potion" else tostring(r.Name))
				end
			end
			table.insert(lines, string.format("Reward %s coins%s, worth %s in all", formatNumber(cash), if #extras > 0 then " + " .. table.concat(extras, " + ") else "", formatNumber(worth)))
			if not o.Sent then
				local needs, fishLeft, buyLeft = {}, 0, 0
				for _, slot in ipairs(type(o.Slots) == "table" and o.Slots or {}) do
					local left = type(slot) == "table" and (tonumber(slot.Need) or 0) - (tonumber(slot.Given) or 0) or 0
					if left > 0 then
						table.insert(needs, string.format("%d %s%s", left, tostring(slot.Name), if slot.Mutation then " (" .. tostring(slot.Mutation) .. ")" else ""))
						if slot.Type == "Fish" then
							fishLeft += left
						else
							buyLeft += left
						end
					end
				end
				table.insert(lines, string.format("Keeping %d fish for it", kept))
				if #needs > 0 then
					table.insert(lines, "Still needs: " .. table.concat(needs, ", ") .. (if fishLeft > 0 and buyLeft > 0 then " (bait and food are bought once the fish are in)" else ""))
				end
			end
		end
		table.insert(lines, "Last: " .. N.Cargo.last)
		return table.concat(lines, "\n")
	end
	local function tierWait()
		local CC = cfg("CargoConfig")
		local tiers = CC and type(CC.Tiers) == "table" and CC.Tiers or {}
		local lvl = N.level()
		local nextMin, curCash, nextCash
		for _, t in ipairs(tiers) do
			local m = tonumber(type(t) == "table" and t.MinLevel)
			if m and m <= lvl then
				curCash = tonumber(t.MinCash)
			elseif m and (not nextMin or m < nextMin) then
				nextMin, nextCash = m, tonumber(t.MinCash)
			end
		end
		if nextMin ~= lvl + 1 then
			return nil
		end
		local C = N.Cargo
		local cyc = cycleNow()
		if C.waitCycle ~= cyc then
			C.waitCycle, C.waitSince = cyc, os.clock()
			log("CARGO wait level", nextMin, "(the next order tier: minimum reward " .. formatNumber(curCash or 0) .. " -> " .. formatNumber(nextCash or 0) .. "), at most 45 min")
		end
		return if os.clock() - C.waitSince < 2700 then nextMin else nil
	end
	N.cargoTierWait = tierWait
	N.listen("Cargo", function(kind, a)
		local C = N.Cargo
		if kind == "Denied" then
			C.denied = tostring(a)
			log("CARGO denied", tostring(a))
		elseif kind == "Sent" then
			C.sent += 1
		elseif kind == "Claimed" then
			C.claims += 1
		end
	end)
	local function giveSlot(i, slot, left, cycle, allowStacks)
		local C = N.Cargo
		local avail = 0
		for guid, item in pairs(N.inv()) do
			if matches(slot, item) and not N.relicOf(item) then
				if slot.Type == "Fish" then
					if listed(item) then
						if not N.isLocked(item) then
							send("Lock", "Toggle", guid)
							N.Sell.locked[guid] = true
							task.wait(0.1)
						end
					elseif N.isLocked(item) and (C.lockedFor[guid] or N.Sell.locked[guid]) then
						if avail < left then
							send("Lock", "Toggle", guid)
							C.lockedFor[guid] = nil
							N.Sell.locked[guid] = nil
							avail += 1
							task.wait(0.1)
						end
					elseif not N.isLocked(item) then
						avail += 1
					end
				elseif allowStacks and not N.isLocked(item) then
					avail += amountOf(item)
				end
			end
		end
		local n = math.min(left, avail)
		if n <= 0 then
			return 0
		end
		task.wait(0.3)
		local before = tonumber(slot.Given) or 0
		C.denied = nil
		for _ = 1, n do
			send("Cargo", "Give", i, cycle)
			task.wait(0.3)
			if C.denied then
				break
			end
		end
		waitFor(function()
			local o = order()
			local s = o and o.Slots and o.Slots[i]
			return s ~= nil and (tonumber(s.Given) or 0) >= before + n
		end, 2)
		local o = order()
		local s = o and o.Slots and o.Slots[i]
		local given = (s and tonumber(s.Given) or before) - before
		log("CARGO give", tostring(slot.Name) .. (if slot.Mutation then " (" .. tostring(slot.Mutation) .. ")" else ""), "slot=" .. i, "x" .. given .. "/" .. n, if C.denied then "denied=" .. C.denied else "")
		if given > 0 then
			C.last = string.format("gave %d x %s", given, tostring(slot.Name))
		end
		return given
	end
	local function buyFor(slot, need)
		local kind = slot.Type
		local item = N.sh("Content.Item." .. tostring(kind))
		local def = item and type(item.Items) == "table" and item.Items[slot.Name]
		local price = tonumber(def and def.Price) or math.huge
		return price * need, price
	end
	function N.cargoStep()
		if not N.wants("AutoCargo") or not N.due("cargo", 15) then
			return false
		end
		local C = N.Cargo
		local now = N.serverTime()
		local cargo = N.tab("Cargo")
		local voyage = cargo.Voyage
		if type(voyage) == "table" and (tonumber(voyage.ReturnAt) or math.huge) <= now then
			local cashBefore = N.cash()
			send("Cargo", "Claim")
			local cleared = waitFor(function()
				return type(N.tab("Cargo").Voyage) ~= "table"
			end, 3)
			local got = math.max(N.cash() - cashBefore, 0)
			if not cleared then
				C.last = "voyage claim refused, retry in 2 minutes"
				log("CARGO claim FAILED", "answer=" .. tostring(C.denied or "no data change"), "tier=" .. tostring(voyage.Tier))
				N.undue("cargo")
				N.due("cargo", 120)
				return true
			end
			C.last = "claimed the voyage reward (" .. formatNumber(got) .. " coins)"
			log("CARGO claim", "ok coins=" .. formatNumber(got), "tier=" .. tostring(voyage.Tier))
			N.claimed("Cargo voyage reward " .. formatNumber(got))
			return true
		end
		local o = order()
		local cyc = cycleNow()
		if not o or o.Cycle ~= cyc then
			if tierWait() then
				C.last = "waiting for the next level before taking this cycle's order (better tier)"
				return false
			end
			if N.due("cargoSync", 60) then
				send("Cargo", "Sync")
				log("CARGO sync", "cycle=" .. cyc)
			end
			return false
		end
		if C.planned ~= tostring(o.Cycle) then
			C.planned = tostring(o.Cycle)
			N.cargoRefresh(true)
			local worth, cash = rewardWorth(o)
			local _, total = slotsDone(o)
			log("CARGO plan", "tier=" .. tostring(o.Tier), "slots=" .. total, "reward=" .. formatNumber(cash), "worth=" .. formatNumber(worth), if o.Sent then (if type(N.tab("Cargo").Voyage) == "table" then "already sent, the ship is at sea" else "already sent and claimed, the next order comes with the next cycle") else "per unit=" .. formatNumber(C.unitWorth))
		end
		local keep = N.cargoRefresh(true)
		local wanted = {}
		for _, guid in pairs(keep) do
			wanted[guid] = true
		end
		local unlocked = 0
		for guid in pairs(C.lockedFor) do
			local item = N.inv()[guid]
			if not item then
				C.lockedFor[guid] = nil
			elseif (o.Sent or not wanted[guid]) and N.isLocked(item) and not listed(item) then
				send("Lock", "Toggle", guid)
				C.lockedFor[guid] = nil
				N.Sell.locked[guid] = nil
				unlocked += 1
				task.wait(0.1)
			end
		end
		if unlocked > 0 then
			log("CARGO unlocked", unlocked, "fish the order no longer needs")
		end
		if o.Sent then
			return unlocked > 0
		end
		local gave = 0
		local fishDone = true
		for i, slot in ipairs(type(o.Slots) == "table" and o.Slots or {}) do
			local left = (tonumber(slot.Need) or 0) - (tonumber(slot.Given) or 0)
			if left > 0 and slot.Type == "Fish" then
				gave += giveSlot(i, slot, left, o.Cycle, false)
				local s = order() and order().Slots[i]
				if s and (tonumber(s.Given) or 0) < (tonumber(s.Need) or 0) then
					fishDone = false
				end
			end
		end
		if fishDone then
			local worth = rewardWorth(o)
			for i, slot in ipairs(o.Slots) do
				local left = (tonumber(slot.Need) or 0) - (tonumber(slot.Given) or 0)
				if left > 0 and (slot.Type == "Bait" or slot.Type == "Food") then
					local mine = on("AutoCargo")
					if mine then
						gave += giveSlot(i, slot, left, o.Cycle, true)
						local s = order() and order().Slots[i]
						left = (tonumber(s and s.Need) or 0) - (tonumber(s and s.Given) or 0)
					end
					if left > 0 then
						local cost, price = buyFor(slot, left)
						if cost <= worth * 0.5 and cost <= N.cash() - N.reserve() then
							local function stack()
								local n = 0
								for _, it in ipairs(N.itemsOf(slot.Type)) do
									if it.item.Name == slot.Name then
										n += amountOf(it.item)
									end
								end
								return n
							end
							local before = stack()
							if slot.Type == "Bait" then
								send("BaitShop", "Buy", slot.Name, left)
							elseif N.unlocked("Pond") and not N.tripBlocked("cargo food") then
								local back = N.worldKey()
								if N.travel("Pond") then
									for _ = 1, 3 do
										local missingUnits = before + left - stack()
										if missingUnits <= 0 then
											break
										end
										for _ = 1, missingUnits do
											send("Pond", "BuyFood", slot.Name)
											task.wait(0.6)
										end
										waitFor(function()
											return stack() >= before + left
										end, 2)
									end
									N.travel(if back ~= "Pond" then back else N.bestFishingWorld())
								end
							end
							local got = waitFor(function()
								return stack() >= before + left
							end, 3)
							local arrived = math.max(stack() - before, 0)
							log("CARGO buy", tostring(slot.Name), "x" .. left, "price=" .. formatNumber(price), if got then "ok" else string.format("got %d of %d (stock or shop reach)", arrived, left))
							if got then
								N.spent(cost)
								gave += giveSlot(i, slot, left, o.Cycle, true)
							elseif arrived > 0 then
								N.spent(price * arrived)
								gave += giveSlot(i, slot, arrived, o.Cycle, true)
							end
						else
							C.last = string.format("%s x%d for the order costs %s: %s", tostring(slot.Name), left, formatNumber(cost), if cost > worth * 0.5 then "more than half its reward, skipped" else "waiting for spare cash")
						end
					end
				end
			end
		end
		o = order()
		local done, total = slotsDone(o)
		if total > 0 and done == total and not o.Sent and type(N.tab("Cargo").Voyage) ~= "table" then
			send("Cargo", "Send", o.Cycle)
			waitFor(function()
				local x = order()
				return x ~= nil and x.Sent == true
			end, 3)
			local sent = order() and order().Sent == true
			C.last = if sent then "order sent on its voyage" else "send refused: " .. tostring(C.denied)
			log("CARGO send", "cycle=" .. tostring(o.Cycle), if sent then "ok" else "refused " .. tostring(C.denied))
			return true
		end
		return gave > 0 or unlocked > 0
	end
	local function guidsOf(t)
		local set = {}
		for k, v in pairs(type(t) == "table" and t or {}) do
			if type(k) == "string" and v ~= nil and v ~= false then
				set[k] = true
			elseif type(v) == "string" then
				set[v] = true
			end
		end
		return set
	end
	function N.equippedPets()
		return guidsOf(N.tab("EquippedPets"))
	end
	function N.pondPets()
		return guidsOf(N.tab("PondPets"))
	end
	local function petDef(name)
		local P = N.sh("Content.Item.Pet")
		local items = P and type(P.Items) == "table" and P.Items or {}
		return items[name]
	end
	N.petDef = petDef
	local function boostsOf(item, atMax)
		local B = cfg("PetBoostConfig")
		local data = type(item.Data) == "table" and item.Data or {}
		local name = tostring(item.Name)
		local shiny = data.Shiny == true
		local level = math.max(tonumber(data.Level) or 1, 1)
		if atMax then
			local PC = cfg("PetConfig")
			local def = petDef(name)
			if PC and type(PC.MaxLevel) == "function" then
				local ok, m = pcall(PC.MaxLevel, { Name = name, Rarity = def and def.Rarity }, shiny)
				if ok and tonumber(m) then
					level = math.max(level, tonumber(m))
				end
			end
		end
		if B and type(B.Get) == "function" then
			local ok, b = pcall(B.Get, name, shiny, level)
			if ok and type(b) == "table" then
				return b, 1
			end
		end
		local b = B and type(B.Boosts) == "table" and B.Boosts[name] or nil
		local k = 1
		if B and type(B.LevelFactor) == "function" then
			local ok, f = pcall(B.LevelFactor, name, level)
			if ok and tonumber(f) and f >= 0.5 and f <= 10 then
				k = f
			end
		end
		if shiny then
			k *= tonumber(B and B.ShinyBonus) or 1.5
		end
		return (if type(b) == "table" then b else {}), k
	end
	N.petBoosts = boostsOf
	local function bonus(x, k)
		x = tonumber(x)
		return if x then 1 + (x - 1) * k else 1
	end
	function N.petLuck()
		local P = N.Pets
		if os.clock() - P.luckAt < 10 then
			return P.luck
		end
		P.luckAt = os.clock()
		local luck = 1
		local inv = N.inv()
		for guid in pairs(N.equippedPets()) do
			local item = inv[guid]
			if type(item) == "table" then
				local b, k = boostsOf(item)
				luck *= bonus(b.Luck, k)
			end
		end
		P.luck = luck
		return luck
	end
	function N.petCoins(item)
		local b, k = boostsOf(item)
		return bonus(b.Coins, k)
	end
	function N.petScore(item, atMax, noCoins)
		local b, k = boostsOf(item, atMax)
		local score = if noCoins then 1 else bonus(b.Coins, k)
		local luck = bonus(b.Luck, k)
		if luck ~= 1 and N.castModel then
			local P = N.Pets
			local key = string.format("%.3f", luck)
			local ratio = P.lucks[key]
			if not ratio then
				local cur = N.petLuck()
				local base, up = N.castModel({ luckMult = 1 / cur }), N.castModel({ luckMult = luck / cur })
				ratio = if base and up and base > 0 then up / base else luck ^ 0.5
				P.lucks[key] = ratio
			end
			score *= ratio
		end
		score *= 1 + (bonus(b.Mutation, k) - 1) * 0.1
		score *= 1 + (bonus(b.Treasure, k) - 1) * 0.05
		score *= 1 + (bonus(b.XP, k) - 1) * 0.02
		if tonumber(b.Golden) then
			local every = math.max(10 - (tonumber(b.Golden) or 0) * k, 2)
			score *= 1 + (1 / every - 0.1)
		end
		if tonumber(b.DoubleCatch) then
			score *= 1 + tonumber(b.DoubleCatch) * k
		end
		local B = cfg("PetBoostConfig")
		local fishing = B and type(B.Fishing) == "table" and B.Fishing[tostring(item.Name)]
		if type(fishing) == "table" and tonumber(fishing.PerMinute) and N.incomeRate then
			local perFish = (tonumber(N.Fish.evCast) or 0) / math.max(N.hookCapRaw(), 1)
			local perMinute = N.incomeRate() * 60
			if perMinute > 0 then
				score *= 1 + math.min(tonumber(fishing.PerMinute) * perFish / perMinute, 2)
			end
		end
		return score
	end
	function N.equipPet(guid)
		send("EquipPet", "Equip", guid)
		return waitFor(function()
			return N.equippedPets()[guid] == true
		end, 3)
	end
	function N.bestFishingPet(includePond)
		local pond = N.pondPets()
		local noCoins = on("SellPet")
		local best, bestScore
		for _, e in ipairs(N.itemsOf("Pet")) do
			if includePond or not pond[e.guid] then
				local s = N.petScore(e.item, true, noCoins) + (tonumber(type(e.item.Data) == "table" and e.item.Data.Level) or 1) * 1e-6
				if not best or s > bestScore then
					best, bestScore = e, s
				end
			end
		end
		return best, bestScore
	end
	function N.petStep()
		if not on("AutoEquipPet") or not N.due("pets", 30) then
			return false
		end
		local pets = N.itemsOf("Pet")
		if #pets == 0 then
			N.Pets.last = "No pets yet: the first egg comes from the sources in Next egg"
			return false
		end
		table.clear(N.Pets.lucks)
		local equipped = N.equippedPets()
		local noCoins = on("SellPet")
		local cur, curScore
		for _, e in ipairs(pets) do
			if equipped[e.guid] then
				local s = N.petScore(e.item, true, noCoins)
				if not cur or s > curScore then
					cur, curScore = e, s
				end
			end
		end
		local best, bestScore = N.bestFishingPet(true)
		if not best then
			N.Pets.last = "No pet to equip"
			return false
		end
		local coinsPet = if noCoins and N.bestCoinsPet then N.bestCoinsPet(true) else nil
		N.Pets.last = string.format("Equipped %s (x%.2f income at max level); best %s (x%.2f)%s; %d %s, %d in the pond", if cur then tostring(cur.item.Name) else "none", curScore or 1, tostring(best.item.Name), bestScore, if coinsPet then "; for sales " .. tostring(coinsPet.item.Name) else "", #pets, if #pets == 1 then "pet" else "pets", count(N.tab("PondPets")))
		if cur and (cur.guid == best.guid or bestScore <= curScore * 1.01) then
			return false
		end
		if N.pondPets()[best.guid] then
			if N.due("petPondWait" .. best.guid, 900) then
				log("PET", tostring(best.item.Name), "is in the pond: taken out on the next pond visit, then equipped")
			end
			return false
		end
		if N.due("petTry" .. best.guid, 600) then
			local ok = N.equipPet(best.guid)
			log("PET equip", tostring(best.item.Name), "score=x" .. string.format("%.2f", bestScore), "was=" .. (if cur then tostring(cur.item.Name) else "none"), if ok then "ok" else "no change")
			N.Pets.luckAt = -1e9
			return true
		end
		return false
	end
	local function eggDef(name)
		local PC = cfg("PetConfig")
		if not PC then
			return nil
		end
		for _, fn in ipairs({ "EggOfItem", "GetEgg" }) do
			if type(PC[fn]) == "function" then
				local ok, e = pcall(PC[fn], name)
				if ok and type(e) == "table" then
					return e
				end
			end
		end
		for _, egg in ipairs(type(PC.Eggs) == "table" and PC.Eggs or {}) do
			if type(egg) == "table" and (egg.Name == name or tostring(egg.Name) .. " Egg" == name or egg.DisplayName == name) then
				return egg
			end
		end
		return nil
	end
	N.eggDef = eggDef
	function N.pondBonus(item)
		local PC = cfg("PondConfig") or {}
		local name = tostring(item.Name)
		local def = petDef(name)
		local b = (type(PC.PetBonusByPet) == "table" and tonumber(PC.PetBonusByPet[name])) or (type(PC.PetBonus) == "table" and tonumber(PC.PetBonus[def and def.Rarity or "Common"])) or 0.01
		if type(item.Data) == "table" and item.Data.Shiny then
			b *= tonumber(PC.PetBonusShiny) or 1.5
		end
		return b
	end
	function N.eggValue(name)
		local egg = eggDef(name)
		if not egg or type(egg.Odds) ~= "table" then
			return 0
		end
		local rate = if N.incomeRate then N.incomeRate() else 0
		local horizon = (if N.horizon then N.horizon() else 24) * 3600
		local noCoins = on("SellPet")
		local _, bar = N.bestFishingPet(true)
		bar = math.max(bar or 1, 1)
		local coinsBar = 1
		if noCoins and N.bestCoinsPet then
			local _, c = N.bestCoinsPet(true)
			coinsBar = math.max(tonumber(c) or 1, 1)
		end
		local pondRate = tonumber(N.Pond and N.Pond.hourly) or 0
		local total = 0
		for pet, pct in pairs(egg.Odds) do
			local p = (tonumber(pct) or 0) / 100
			local item = { Name = pet, Data = { Level = 1 } }
			local gain = math.max(N.petScore(item, true, noCoins) - bar, 0) * rate * horizon
			if noCoins then
				gain = math.max(gain, math.max(N.petCoins(item) - coinsBar, 0) * rate * horizon)
			end
			gain += N.pondBonus(item) * pondRate / 3600 * horizon * 0.5
			total += p * gain
		end
		return total
	end
	local function hatcherySlots()
		local PC = cfg("PetConfig")
		return tonumber(PC and type(PC.Hatchery) == "table" and PC.Hatchery.Slots) or 5
	end
	local function eggRank(name)
		local e = eggDef(name)
		return N.eggValue(name) + (tonumber(e and e.World) or 0) * 1e-3
	end
	local function heldGuid()
		local char = N.char()
		local tool = char and char:FindFirstChildOfClass("Tool")
		return tool and tool.Name
	end
	local function whaleCharge()
		local BR = cfg("BossRelicConfig")
		local d = N.data()
		if BR and type(BR.Charges) == "function" then
			local ok, n = pcall(BR.Charges, d, "Whale")
			if ok and tonumber(n) then
				return tonumber(n)
			end
		end
		return tonumber(N.tab("RelicCharges").Whale) or 0
	end
	N.whaleCharge = whaleCharge
	function N.useWhaleRelic(why)
		if not on("AutoRelics") or whaleCharge() > 0 then
			return false
		end
		local BR = cfg("BossRelicConfig")
		for guid, item in pairs(N.inv()) do
			if type(item) == "table" and item.Type == "Fish" then
				local key = N.relicOf(item)
				local ok, def = false, nil
				if key and BR and type(BR.Get) == "function" then
					ok, def = pcall(BR.Get, key)
				end
				if key and ok and type(def) == "table" and (def.HatchLuck or def.EggDrop) then
					N.pauseFishing()
					N.holdItem(guid)
					send("BossRelic", "Consume", guid)
					Session.relics += 1
					log("RELIC", tostring(key), "hatch luck x" .. tostring(def.HatchLuck), "egg drop x" .. tostring(def.EggDrop), "(" .. tostring(why) .. ")")
					task.wait(0.8)
					return true
				end
			end
		end
		return false
	end
	function N.eggStep()
		local E = N.Eggs
		if not on("AutoEggs") or not N.due("eggs", 30) then
			return false
		end
		if not N.unlocked("Pond") then
			E.last = "The hatchery is on the pond island: unlock the pond first (Auto Pond or the Smart Planner)"
			return false
		end
		local now = N.serverTime()
		local placed = N.tab("PlacedEggs")
		local free, ready, nextAt, growing = {}, {}, math.huge, 0
		for i = 1, hatcherySlots() do
			local key = tostring(i)
			local entry = placed[key]
			if entry == nil then
				table.insert(free, key)
			elseif type(entry) == "table" then
				growing += 1
				local r = tonumber(entry.ReadyAt)
				if r and r <= now then
					table.insert(ready, { key = key, egg = tostring(entry.Egg), v = eggRank(tostring(entry.Egg)) })
				elseif r then
					nextAt = math.min(nextAt, r)
				end
			end
		end
		local eggs = {}
		for _, e in ipairs(N.itemsOf("Egg")) do
			table.insert(eggs, { guid = e.guid, name = tostring(e.item.Name), n = amountOf(e.item), v = eggRank(tostring(e.item.Name)) })
		end
		table.sort(eggs, function(a, b)
			return a.v > b.v
		end)
		local inBag = 0
		for _, e in ipairs(eggs) do
			inBag += e.n
		end
		E.last = string.format("Eggs %d in the backpack, %d/%d in the hatchery%s\nHatched %d, placed %d this session", inBag, growing, hatcherySlots(), if nextAt < math.huge then ", next ready in " .. N.longTime(nextAt - now) else "", E.hatched, E.placed)
		if os.clock() < (E.holdUntil or 0) then
			ready = {}
			E.last ..= "\nHatching paused " .. N.longTime(E.holdUntil - os.clock()) .. " (the server refused it twice)"
		end
		local wantPlace = inBag > 0 and #free > 0 and not E.placeOff
		if not (wantPlace or #ready > 0) then
			return false
		end
		if N.tripBlocked("hatchery") then
			return false
		end
		local back = N.worldKey()
		N.pauseFishing("hatchery trip")
		if back ~= "Pond" and not N.travel("Pond") then
			N.resumeFishing()
			return false
		end
		E.trips += 1
		setStatus("Egg hatchery: hatching and placing eggs")
		local root = workspace:FindFirstChild("World")
		local pond = (root and root:FindFirstChild("Pond")) or N.worldFolder()
		local bed = (pond and pond:FindFirstChild("EggHatchery", true)) or workspace:FindFirstChild("EggHatchery", true)
		if bed then
			local ok, pos = pcall(function()
				local slot = bed:FindFirstChild("Slot1", true)
				return if slot then slot.Position else bed:GetPivot().Position
			end)
			if ok and pos then
				N.goTo(pos, 5)
			end
		end
		table.sort(ready, function(a, b)
			return a.v > b.v
		end)
		for idx, r in ipairs(ready) do
			local def = eggDef(r.egg)
			if idx == 1 and (tonumber(def and def.World) or 1) >= 2 then
				N.useWhaleRelic("before hatching " .. r.egg)
			end
			local pets = #N.itemsOf("Pet")
			send("HatchEgg", "Hatch", r.key)
			if waitFor(function()
				return N.tab("PlacedEggs")[r.key] == nil or #N.itemsOf("Pet") > pets
			end, 4) then
				E.hatched += 1
				E.hatchFails = 0
				waitFor(function()
					return #N.itemsOf("Pet") > pets
				end, 8)
				log("EGG hatched", r.egg, "slot=" .. r.key, "pets now=" .. #N.itemsOf("Pet"))
				table.insert(free, r.key)
			else
				E.hatchFails = (E.hatchFails or 0) + 1
				log("EGG hatch no change", r.egg, "slot=" .. r.key, "fails=" .. E.hatchFails)
				if E.hatchFails >= 2 then
					E.hatchFails = 0
					E.holdUntil = os.clock() + 900
					log("PROBE", "egg_hatch", "result=rejected", "gain=0", "(hatching waits 15 min)")
				end
				break
			end
			task.wait(0.6)
		end
		if not E.placeOff then
			table.sort(free)
			local okAny, failed = false, false
			for _, e in ipairs(eggs) do
				for _ = 1, e.n do
					local key = table.remove(free, 1)
					if not key or not alive() or N.inv()[e.guid] == nil then
						if key then
							table.insert(free, 1, key)
						end
						break
					end
					N.holdItem(e.guid)
					waitFor(function()
						return heldGuid() == e.guid
					end, 1.5)
					send("HatchEgg", "Place", key)
					if waitFor(function()
						return N.tab("PlacedEggs")[key] ~= nil
					end, 3) then
						okAny = true
						E.placed += 1
						log("EGG placed", e.name, "slot=" .. key, "growing=" .. count(N.tab("PlacedEggs")) .. "/" .. hatcherySlots())
						task.wait(0.6)
					else
						failed = true
						break
					end
				end
				if failed or #free == 0 then
					break
				end
			end
			if okAny then
				E.placeFails = 0
			elseif failed then
				E.placeFails += 1
				log("PROBE", "egg_place", "result=rejected", "try=" .. E.placeFails, "held=" .. tostring(heldGuid()), "(HatchEgg Place with the egg held did not place it)")
				if E.placeFails >= 2 then
					E.placeOff = true
					log("EGG placing off for this session", "(two trips without a placed egg)")
				end
			end
		end
		if N.pondPetStep then
			N.pondPetStep(true)
		end
		N.travel(if back ~= "Pond" then back else N.bestFishingWorld())
		N.resumeFishing()
		return true
	end
end
N.SaleStack = { potionUntil = 0, last = "-" }
N.Merchant = { last = "Off", doneVisit = nil, bought = 0, probed = false }
N.Charges = { last = "-", used = 0 }
N.PondPets = { last = "-", at = -1e9 }
do
	local function cfg(name)
		local c = N.sh("Config." .. name)
		return if type(c) == "table" then c else nil
	end
	local count = N.count
	function N.potionWorth(name, seconds)
		local key = N.potionKey(name)
		seconds = tonumber(seconds) or 600
		local rate = if N.incomeRate then N.incomeRate() else 0
		if rate <= 0 then
			return 0
		end
		if key == "Luck" or key == "StayLuck" or key == "Beginner" then
			local ratio = 1.2
			pcall(function()
				local base, info = N.castModel()
				local up = N.castModel({ luckMult = (info.luck + 0.5) / info.luck })
				if base and up and base > 0 then
					ratio = up / base
				end
			end)
			return rate * seconds * math.max(ratio - 1, 0)
		elseif key == "Coins" then
			return rate * seconds * 0.5 * 3
		elseif key == "Capacity" then
			return rate * seconds * 5 / math.max(N.hookCapRaw(), 1)
		elseif key == "Mutation" then
			return rate * seconds * 0.05
		end
		return 0
	end
	function N.saleMultText()
		local parts, mult = {}, 1
		local boost = tonumber(workspace:GetAttribute("ServerCash")) or 1
		if boost > 1 then
			mult *= boost
			table.insert(parts, "boost x" .. boost)
		end
		local social = 0
		if N.data().IsInGroup == true then
			social += 0.1
			table.insert(parts, "group +10%")
		end
		local friends = tonumber(LocalPlayer:GetAttribute("FriendsInServer"))
		if friends and friends > 0 then
			local f = math.clamp(math.floor(friends), 0, 4)
			social += f * 0.1
			table.insert(parts, "friends +" .. (f * 10) .. "%")
		end
		mult *= 1 + social
		if N.potionActive("Coins") then
			mult *= 1.5
			table.insert(parts, "potion +50%")
		end
		local inv = N.inv()
		for guid in pairs(N.equippedPets()) do
			local item = inv[guid]
			local c = type(item) == "table" and N.petCoins(item) or 1
			if c > 1.0001 then
				mult *= c
				table.insert(parts, string.format("pet x%.2f", c))
			end
		end
		return string.format("x%.2f", mult) .. (if #parts > 0 then " (" .. table.concat(parts, ", ") .. ")" else " (no multiplier)")
	end
	function N.socialText()
		local inGroup = N.data().IsInGroup == true
		local friends = math.clamp(math.floor(tonumber(LocalPlayer:GetAttribute("FriendsInServer")) or 0), 0, 4)
		return string.format("Sale bonus: group %s, friends here %d/4 (+%d%%)", if inGroup then "+10% (joined)" else "not joined (+10% and faster casts when you join)", friends, friends * 10)
	end
	function N.coinsPotionGuid()
		for _, e in ipairs(N.itemsOf("Potion")) do
			if N.potionKey(tostring(e.item.Name)) == "Coins" then
				return e.guid
			end
		end
		return nil
	end
	local function bestCoinsPet(includePond)
		local pond = N.pondPets()
		local best, bestC
		for _, e in ipairs(N.itemsOf("Pet")) do
			if includePond or not pond[e.guid] then
				local c = N.petCoins(e.item)
				if c > 1.0001 and (not best or c > bestC) then
					best, bestC = e, c
				end
			end
		end
		return best, bestC
	end
	N.bestCoinsPet = bestCoinsPet
	function N.salePrep(reason)
		local SS = N.SaleStack
		local text = string.lower(tostring(reason))
		local count2, max = N.backpack()
		local _, _, sellValue = N.fishStats(true)
		local big = string.find(text, "backpack", 1, true) ~= nil
			or (string.find(text, "cashboost", 1, true) ~= nil and count2 >= max * 0.5)
			or (N.incomeRate and sellValue >= N.incomeRate() * 300)
		if on("SellPotion") and big and not N.potionActive("Coins") and N.worldKey() ~= "Pond" then
			local guid = N.coinsPotionGuid()
			if guid and N.drinkPotion(guid, "Coins Potion", "at sale (" .. tostring(reason) .. ")") then
				local left = N.potionLeft("Coins Potion")
				SS.potionUntil = N.serverTime() + math.max(tonumber(left) or 600, 0)
				SS.last = "Coins potion drunk for a sale of " .. count2 .. " fish worth " .. formatNumber(sellValue)
				log("POTION Coins at sale", "fish=" .. count2, "worth=" .. formatNumber(sellValue), "ends in " .. math.floor(tonumber(left) or 600) .. " s")
			end
		end
		if not on("SellPet") then
			return nil
		end
		local best, bestC = bestCoinsPet()
		if not best then
			return nil
		end
		local prev, prevC = nil, 1
		local inv = N.inv()
		for guid in pairs(N.equippedPets()) do
			prev = guid
			if type(inv[guid]) == "table" then
				prevC = N.petCoins(inv[guid])
			end
		end
		if prev == best.guid or bestC <= prevC * 1.001 then
			return nil
		end
		if not N.equipPet(best.guid) then
			log("SELL pet swap no change", tostring(best.item.Name))
			return nil
		end
		log("SELL pet swap", tostring(best.item.Name), string.format("coins x%.2f", bestC))
		return function()
			if prev and N.inv()[prev] then
				N.equipPet(prev)
			end
		end
	end
	function N.salePredict()
		local sum = 0
		for guid, item in pairs(N.inv()) do
			if type(item) == "table" and item.Type == "Fish" and not N.isLocked(item) and not N.relicOf(item) then
				sum += N.value(item)
			end
		end
		return sum
	end
	function N.sellRodProbe(predicted, got)
		if N.memo("sell_rod") or predicted <= 0 then
			return
		end
		local E = N.sh("Modules.Enchant")
		local bonus = 0
		pcall(function()
			bonus = tonumber(E.Add(N.data(), "SellValue", nil)) or 0
		end)
		if math.abs(bonus) < 0.01 then
			return
		end
		local ratio = got / predicted
		local result
		if math.abs(ratio - 1) <= 0.03 then
			result = "accepted"
		elseif math.abs(ratio * (1 + bonus) - 1) <= 0.03 then
			result = "rejected"
		else
			return
		end
		N.memo("sell_rod", result)
		log("PROBE", "sell_rod", "result=" .. result, string.format("gain=x%.2f", if result == "accepted" then 1 + bonus else 1), "rod=" .. tostring(N.data().RodEquipped), string.format("paid/predicted=%.3f", ratio))
	end
	function N.vaultProbe()
		if N.memo("vault_cap") then
			return
		end
		local vault = N.tab("Vault")
		local inVault = count(vault.Fish)
		if inVault == 0 then
			return
		end
		local used = N.backpack()
		local inBag = count(N.inv())
		local result
		if used >= inBag + inVault then
			result = "rejected"
		elseif used <= inBag then
			result = "accepted"
		else
			return
		end
		N.memo("vault_cap", result)
		log("PROBE", "vault_cap", "result=" .. result, "gain=" .. (if result == "accepted" then "+" .. inVault .. " slots" else "0"), "backpack=" .. used, "items=" .. inBag, "vault=" .. inVault)
	end
	local Category = { Egg = "Eggs", Potion = "Potions", Bait = "Bait", Food = "Bait", Fish = "Fish", Chest = "Chests", Cage = "Chests", Key = "Keys", Scroll = "Scrolls" }
	local function wantsCat(kind)
		local opt = Options.MerchantBuy
		if not opt then
			return kind == "Egg" or kind == "Potion" or kind == "Bait" or kind == "Food" or kind == "Fish"
		end
		return selected(opt, Category[kind] or kind)
	end
	local function merchantSpot(MC)
		local root = workspace:FindFirstChild("World")
		local world = (root and root:FindFirstChild(MC.World or "World 1")) or (N.worldKey() == (MC.World or "World 1") and N.worldFolder()) or nil
		local island = world and world:FindFirstChild(MC.Island or "Merchant Island", true)
		local spot = island and island:FindFirstChild("MerchantSpot", true)
		if not spot then
			return nil
		end
		local ok, pos = pcall(function()
			return if spot:IsA("BasePart") then spot.Position else spot:GetPivot().Position
		end)
		return if ok then pos else nil
	end
	local function drinks(key)
		if key == "Coins" then
			return on("SellPotion") or (on("AutoPotions") and selected(Options.PotionKinds, key))
		end
		return on("AutoPotions") and selected(Options.PotionKinds, key)
	end
	local function castsOf(offer)
		local MC = cfg("MerchantConfig")
		local t = MC and type(MC.Casts) == "table" and MC.Casts[tostring(offer.Type)]
		return t and tonumber(t[tostring(offer.Name)]) or nil
	end
	function N.merchantOfferValue(offer)
		local kind, name = tostring(offer.Type), tostring(offer.Name)
		local stock = math.max(tonumber(offer.Stock) or 0, 0)
		if not wantsCat(kind) then
			return 0, stock, false, "not picked"
		end
		local price = tonumber(offer.Price) or 0
		if kind == "Egg" then
			return N.eggValue(name) * stock, stock, true, "egg"
		elseif kind == "Potion" then
			local key = N.potionKey(name)
			if not drinks(key) then
				return 0, stock, false, "no toggle drinks " .. key .. " potions"
			end
			local worth = N.potionWorth(name, 600)
			return worth * stock, stock, false, if worth > 0 then "potion" else key .. " potions have no coin value"
		elseif kind == "Bait" or kind == "Food" then
			local B = N.sh("Content.Item." .. kind)
			local def = B and type(B.Items) == "table" and B.Items[name]
			local shop = tonumber(def and def.Price) or 0
			local cargoNeed = 0
			local o = N.tab("Cargo").Order
			for _, slot in ipairs(type(o) == "table" and type(o.Slots) == "table" and o.Slots or {}) do
				if slot.Type == kind and slot.Name == name then
					cargoNeed += math.max((tonumber(slot.Need) or 0) - (tonumber(slot.Given) or 0), 0)
				end
			end
			if cargoNeed > 0 and N.wants("AutoCargo") then
				local n = math.min(cargoNeed, stock)
				return shop * n * 1.5, n, false, "cargo order"
			end
			if kind == "Bait" and N.wants("AutoBait") then
				return shop * stock, stock, false, "Auto Bait"
			end
			return 0, stock, false, "nothing uses it"
		elseif kind == "Fish" then
			local o = N.tab("Cargo").Order
			for _, slot in ipairs(type(o) == "table" and type(o.Slots) == "table" and o.Slots or {}) do
				if slot.Type == "Fish" and slot.Name == name and slot.Mutation == nil and (tonumber(slot.Given) or 0) < (tonumber(slot.Need) or 0) and N.wants("AutoCargo") then
					return N.Cargo.unitWorth, 1, false, "cargo slot"
				end
			end
			return 0, 1, false, "no cargo slot"
		elseif kind == "Chest" then
			local C = N.sh("Content.Item.Chest")
			local def = C and type(C.Items) == "table" and C.Items[name]
			local casts = castsOf(offer)
			local coins = type(def) == "table" and type(def.CoinCasts) == "table" and ((tonumber(def.CoinCasts[1]) or 0) + (tonumber(def.CoinCasts[2]) or 0)) / 2 or 0
			local perCast = if casts and casts > 0 then price / casts else 0
			local bait = 0
			if type(def) == "table" and N.wants("AutoBait") then
				local amount = type(def.BaitAmount) == "table" and ((tonumber(def.BaitAmount[1]) or 0) + (tonumber(def.BaitAmount[2]) or 0)) / 2 or 0
				bait = (tonumber(def.BaitChance) or 0) * amount * N.baitAtTier(tonumber(def.BaitTier) or 0.5)
			end
			return (coins * perCast + bait) * stock, stock, false, string.format("chest %.0f casts of coins + bait %s for %s casts", coins, formatNumber(bait), tostring(casts))
		elseif kind == "Cage" then
			local C = N.sh("Content.Item.Cage")
			local def = C and type(C.Items) == "table" and C.Items[name]
			local n = type(def) == "table" and type(def.FishCount) == "table" and ((tonumber(def.FishCount[1]) or 0) + (tonumber(def.FishCount[2]) or 0)) / 2 or 0
			local perFish = (tonumber(N.Fish.evCast) or 0) / math.max(N.hookCapRaw(), 1) * 0.5
			return n * perFish * stock, stock, false, string.format("cage %.0f fish of about %s", n, formatNumber(perFish))
		elseif kind == "Scroll" then
			local have = 0
			for _, e in ipairs(N.itemsOf("Scroll")) do
				if tostring(e.item.Name) == name then
					have += tonumber(type(e.item.Data) == "table" and e.item.Data.Amount) or 1
				end
			end
			local used = (string.find(name, "Enchant", 1, true) and on("AutoEnchant")) or (string.find(name, "Mutation", 1, true) and on("AutoMutate"))
			if used and have < 5 then
				return price * stock * 1.01, stock, false, "scroll for " .. (if string.find(name, "Enchant", 1, true) then "Auto Enchant" else "Auto Mutate")
			end
			return 0, stock, false, string.format("scroll (you have %d, its toggle %s)", have, if used then "has enough" else "is off")
		elseif kind == "Key" then
			local keyName = string.gsub(name, " Fragment$", " Key")
			local have = N.tab("FoundKeys")[keyName] == true
			for _, e in ipairs(N.itemsOf("Key")) do
				if tostring(e.item.Name) == keyName then
					have = true
				end
			end
			if have then
				return 0, stock, false, "you already have the " .. keyName
			end
			return price * stock * 1.01, stock, false, "fragment of the missing " .. keyName
		end
		return 0, stock, false, "no value model"
	end
	function N.baitAtTier(tier)
		local B = N.sh("Content.Item.Bait")
		local list = {}
		for _, def in pairs(B and type(B.Items) == "table" and B.Items or {}) do
			local p = tonumber(type(def) == "table" and def.Price)
			if p and p > 0 then
				table.insert(list, p)
			end
		end
		if #list == 0 then
			return 0
		end
		table.sort(list)
		return list[math.clamp(math.floor((#list - 1) * math.clamp(tier, 0, 1) + 1.5), 1, #list)]
	end
	local function eggOdds()
		local W = cfg("WhaleEventConfig")
		local num = N.worldNumber(N.worldKey())
		local p = 0
		if W and type(W.WorldEggs) == "function" then
			pcall(function()
				for _, e in ipairs(W.WorldEggs(num)) do
					p += 1 / (tonumber(e.OneIn) or math.huge)
				end
			end)
		end
		return p
	end
	function N.eggPlanText()
		local parts = {}
		local now = N.serverTime()
		local MC = cfg("MerchantConfig")
		if MC and type(MC.Window) == "function" then
			local ok, w = pcall(MC.Window, now)
			if ok and type(w) == "table" then
				local off = if N.wants("AutoMerchant") and wantsCat("Egg") then "" else " (Auto Merchant > Eggs off)"
				if w.Present then
					local entry = N.tab("Merchants")[MC.World or "World 1"]
					local eggs = {}
					if type(entry) == "table" and entry.Visit == w.Visit then
						for _, o in ipairs(type(entry.Offers) == "table" and entry.Offers or {}) do
							if type(o) == "table" and o.Type == "Egg" and (tonumber(o.Stock) or 0) > 0 then
								table.insert(eggs, string.format("%s x%d (%s casts)", tostring(o.Name), tonumber(o.Stock) or 1, tostring(castsOf(o) or "?")))
							end
						end
						table.insert(parts, "Merchant here: " .. (if #eggs > 0 then table.concat(eggs, ", ") else "no egg left") .. off)
					else
						table.insert(parts, "Merchant here now" .. off)
					end
				else
					table.insert(parts, "Merchant in " .. N.longTime(math.max((tonumber(w.NextArrival) or now) - now, 0)) .. off)
				end
			end
		end
		local cargo = N.tab("Cargo")
		local o = cargo.Order
		local eggName
		for _, r in ipairs(type(o) == "table" and type(o.Rewards) == "table" and o.Rewards or {}) do
			if type(r) == "table" and r.Type == "Egg" then
				eggName = tostring(r.Name)
			end
		end
		local cOff = if N.wants("AutoCargo") then "" else " (Auto Tasks off)"
		if type(cargo.Voyage) == "table" then
			table.insert(parts, "Cargo ship back in " .. N.longTime(math.max((tonumber(cargo.Voyage.ReturnAt) or now) - now, 0)) .. cOff)
		elseif type(o) == "table" and not o.Sent then
			local done, total = 0, 0
			for _, slot in ipairs(type(o.Slots) == "table" and o.Slots or {}) do
				total += 1
				if (tonumber(slot.Given) or 0) >= (tonumber(slot.Need) or 0) then
					done += 1
				end
			end
			table.insert(parts, string.format("Cargo order %d/%d slots%s%s", done, total, if eggName then " -> " .. eggName else "", cOff))
		else
			local CC = N.sh("Config.CargoConfig")
			local secs = tonumber(type(CC) == "table" and CC.CycleSeconds) or 21600
			local cyc = math.floor(now / secs)
			if type(o) == "table" and o.Sent and o.Cycle == cyc then
				table.insert(parts, "Cargo: next order in " .. N.longTime((cyc + 1) * secs - now) .. cOff)
			else
				table.insert(parts, "Cargo: this cycle's order comes with the next sync" .. cOff)
			end
		end
		local odds = eggOdds()
		local oddsText = if odds > 0 then string.format(" (1 in %d casts in %s)", math.floor(1 / odds + 0.5), N.worldKey()) else ""
		if N.whaleWindow() then
			table.insert(parts, "Whale eggs open now" .. oddsText)
		else
			table.insert(parts, "Whale eggs in " .. N.longTime(N.whaleIn()) .. oddsText)
		end
		return "Next egg: " .. table.concat(parts, " | ")
	end
	N.listen("Merchant", function(kind, a)
		if kind == "Denied" then
			N.Merchant.denied = tostring(a)
		elseif kind == "Bought" then
			N.Merchant.boughtNote = brief(a)
		end
	end)
	function N.merchantStep()
		local M = N.Merchant
		if not N.wants("AutoMerchant") or not N.due("merchant", 20) then
			return false
		end
		local MC = cfg("MerchantConfig")
		if not (MC and type(MC.Window) == "function") then
			M.last = "No merchant in this game version"
			return false
		end
		local now = N.serverTime()
		local ok, w = pcall(MC.Window, now)
		if not ok or type(w) ~= "table" then
			return false
		end
		if not w.Present then
			M.last = string.format("Arrives in %s (World 1, stays %s); Jiro goes there when it arrives. Bought %d this session", N.longTime(math.max((tonumber(w.NextArrival) or now) - now, 0)), N.longTime(tonumber(MC.StaySeconds) or 600), M.bought)
			return false
		end
		if M.doneVisit == w.Visit or (tonumber(w.LeavesAt) or 0) - now < 20 then
			return false
		end
		if M.skipVisit == w.Visit and os.clock() < (M.skipUntil or 0) then
			return false
		end
		if N.tripBlocked("merchant") then
			return false
		end
		if (tonumber(N.Fish.evCast) or 0) <= 0 or N.incomeRate() <= 0 then
			M.last = "Here now: pricing the offers after the first casts"
			return false
		end
		local worldKey = MC.World or "World 1"
		local entry = N.tab("Merchants")[worldKey]
		if type(entry) ~= "table" or entry.Visit ~= w.Visit then
			send("Merchant", "Open")
			waitFor(function()
				local e = N.tab("Merchants")[worldKey]
				return type(e) == "table" and e.Visit == w.Visit
			end, 3)
			entry = N.tab("Merchants")[worldKey]
			if type(entry) ~= "table" or entry.Visit ~= w.Visit then
				M.last = "The merchant sent no offers (retry in 20 s)"
				return false
			end
		end
		local list, skipped = {}, {}
		for i, offer in ipairs(type(entry.Offers) == "table" and entry.Offers or {}) do
			if type(offer) == "table" and (tonumber(offer.Stock) or 0) > 0 then
				local value, n, must, why = N.merchantOfferValue(offer)
				local price = (tonumber(offer.Price) or math.huge) * math.max(n, 1)
				if n > 0 and (must or value > price) then
					table.insert(list, { i = i, offer = offer, n = n, value = value, price = price, must = must })
				else
					table.insert(skipped, tostring(offer.Name) .. " (" .. why .. ")")
				end
			end
		end
		table.sort(list, function(a, b)
			if a.must ~= b.must then
				return a.must
			end
			return a.value / a.price > b.value / b.price
		end)
		local picks, total, cost, short = {}, 0, 0, {}
		local _, sellable, sellValue = N.fishStats(true)
		local funds = N.cash() + (if N.wants("SmartSell") and sellable > 0 then sellValue * 0.9 else 0)
		for _, p in ipairs(list) do
			if cost + p.price <= funds then
				table.insert(picks, p)
				cost += p.price
				total += p.value
			else
				table.insert(short, tostring(p.offer.Name))
			end
		end
		local anyMust = false
		for _, p in ipairs(picks) do
			anyMust = anyMust or p.must
		end
		local here = N.worldKey() == worldKey
		local tripCost = N.incomeRate() * (if here then 6 else 40)
		if #picks == 0 or (not anyMust and total - cost < tripCost) then
			M.skipVisit, M.skipUntil = w.Visit, os.clock() + 120
			M.last = string.format("Here now: nothing to buy%s%s", if #short > 0 then "; short of cash for " .. table.concat(short, ", ") else "", if #skipped > 0 then "; skipped " .. table.concat(skipped, ", ") else "")
			if N.due("merchantSkipLog" .. tostring(w.Visit), 300) then
				log("MERCHANT skip", "worth=" .. formatNumber(total), "cost=" .. formatNumber(cost), "trip=" .. formatNumber(tripCost), "short=" .. (if #short > 0 then table.concat(short, ", ") else "-"), "funds=" .. formatNumber(funds), "skipped=" .. table.concat(skipped, "; "))
			end
			return false
		end
		local back = N.worldKey()
		N.pauseFishing("merchant trip")
		if cost > N.cash() then
			N.sellNow("fund the merchant (" .. formatNumber(cost) .. ")")
		end
		if not here and not N.travel(worldKey) then
			N.resumeFishing()
			return false
		end
		local pos = merchantSpot(MC)
		if pos then
			N.goTo(pos, 8)
			task.wait(0.5)
		end
		setStatus("Traveling merchant: buying " .. #picks .. " offers")
		local bought = 0
		for _, p in ipairs(picks) do
			local before = tonumber(p.offer.Stock) or 0
			local invBefore = count(N.inv())
			M.denied = nil
			if N.cash() < p.price then
				log("MERCHANT buy skipped", tostring(p.offer.Name), "cash=" .. formatNumber(N.cash()), "price=" .. formatNumber(p.price))
				table.insert(short, tostring(p.offer.Name))
				continue
			end
			send("Merchant", "Buy", w.Visit, p.i, p.n)
			local okBuy = waitFor(function()
				local e = N.tab("Merchants")[worldKey]
				local o = type(e) == "table" and type(e.Offers) == "table" and e.Offers[p.i]
				return type(o) == "table" and (tonumber(o.Stock) or 0) < before
			end, 2.5)
			local casts = castsOf(p.offer)
			if okBuy then
				bought += 1
				M.bought += 1
				N.spent(p.price)
				log("MERCHANT buy", tostring(p.offer.Name), "x" .. p.n, "ok", "for " .. (if casts then tostring(casts * p.n) .. " casts = " else "") .. formatNumber(p.price), "value=" .. formatNumber(p.value), "items " .. invBefore .. "->" .. count(N.inv()), "answer=" .. tostring(M.boughtNote or "-"))
				M.boughtNote = nil
			else
				log("MERCHANT buy FAILED", tostring(p.offer.Name), "x" .. p.n, "answer=" .. tostring(M.denied or "stock unchanged"))
			end
			if not M.probed then
				M.probed = true
				log("PROBE", "merchant_buy", "result=" .. (if okBuy then "accepted" else "rejected"), "gain=" .. (if okBuy then tostring(p.offer.Name) .. "x" .. p.n else "0"), "near=" .. tostring(pos ~= nil))
			end
			task.wait(0.4)
		end
		if #short == 0 then
			M.doneVisit = w.Visit
		end
		M.last = string.format("Visit %s: bought %d of %d picks for %s%s", tostring(w.Visit), bought, #picks, formatNumber(cost), if #short > 0 then "; waiting for cash for " .. table.concat(short, ", ") else "")
		N.travel(if back ~= "Pond" then back else N.bestFishingWorld())
		N.resumeFishing()
		return true
	end
	local ChargeOrder = { "More Fish", "Mutation Luck", "Collect All" }
	N.listen("ThrowRod", function(kind, a)
		local cast = N.Fish.cast
		if not cast then
			return
		end
		if kind == "MoreFish" and type(a) == "table" then
			cast.extra = cast.extra or {}
			local from = tonumber(a.from) or 0
			for i, name in ipairs(type(a.names) == "table" and a.names or {}) do
				cast.extra[from + i] = { name = name, size = type(a.sizes) == "table" and a.sizes[i] or 1, mutation = type(a.mutations) == "table" and a.mutations[i] or nil }
			end
			cast.charges = cast.charges or {}
			cast.charges["More Fish"] = true
			cast.capBonus = (cast.capBonus or 0) + #(type(a.names) == "table" and a.names or {})
		elseif kind == "CollectAll" then
			cast.collectAll = true
			cast.charges = cast.charges or {}
			cast.charges["Collect All"] = true
		elseif kind == "Mutations" and type(a) == "table" then
			cast.mutated = cast.mutated or {}
			for _, pair in ipairs(a) do
				if type(pair) == "table" and pair[1] then
					cast.mutated[pair[1]] = pair[2]
				end
			end
			cast.charges = cast.charges or {}
			cast.charges["Mutation Luck"] = true
		end
	end)
	local function owned(name)
		return tonumber(N.tab("ThrowCharges")[name]) or 0
	end
	function N.chargeStep(cast, payload, cap)
		if not on("UseCharges") or not payload then
			return
		end
		local C = N.Charges
		if owned("Collect All") <= 0 and owned("More Fish") <= 0 and owned("Mutation Luck") <= 0 then
			return
		end
		if N.memo("charge_use") == "rejected" then
			return
		end
		local avg = tonumber(N.Fish.evCast) or 0
		if avg <= 0 then
			return
		end
		local values = {}
		for i, name in ipairs(type(payload.school) == "table" and payload.school or {}) do
			table.insert(values, N.fishValue(name, payload.sizes and payload.sizes[i], payload.mutations and payload.mutations[i]))
		end
		table.sort(values, function(x, y)
			return x > y
		end)
		local all, top = 0, 0
		for i, v in ipairs(values) do
			all += v
			if i <= cap then
				top += v
			end
		end
		local leftover = all - top
		local use = {}
		if owned("Collect All") > 0 and leftover >= avg * 4 then
			use = { "More Fish", "Mutation Luck", "Collect All" }
		elseif owned("Collect All") <= 0 and top >= avg * 3 then
			use = { "More Fish", "Mutation Luck" }
		end
		if #use == 0 then
			return
		end
		local used = {}
		for _, name in ipairs(ChargeOrder) do
			if table.find(use, name) and owned(name) > 0 and not cast.windowOpen and alive() then
				local before = owned(name)
				send("ThrowCharges", "Use", name)
				local ok = waitFor(function()
					return (cast.charges and cast.charges[name]) or owned(name) < before
				end, 1.2)
				table.insert(used, name .. "=" .. (if ok then "ok" else "no"))
				if ok then
					C.used += 1
				end
				log("PROBE", "charge_use", "name=" .. name, "result=" .. (if ok then "accepted" else "rejected"), "gain=+" .. (if name == "More Fish" then tostring(cast.capBonus or 0) .. " fish" elseif name == "Collect All" then tostring(#values - math.min(cap, #values)) .. " fish over the cap" else "x3 mutations"))
				if not ok and N.memo("charge_use") ~= "accepted" then
					N.Charges.fails = (N.Charges.fails or 0) + 1
					if N.Charges.fails >= 3 then
						N.memo("charge_use", "rejected")
					end
				elseif ok then
					N.Charges.fails = 0
					if N.memo("charge_use") ~= "accepted" then
						N.memo("charge_use", "accepted")
					end
				end
				task.wait(0.55)
			end
		end
		C.last = string.format("%s on a school of %d (cap %d, %s over the cap)", table.concat(used, ", "), #values, cap, formatNumber(leftover))
	end
	N.Skin = { last = "Off", holdUntil = 0 }
	function N.skinScore(name)
		local SB = cfg("SkinBoostConfig")
		if not (SB and type(SB.Get) == "function") or not name or name == "" then
			return 1
		end
		local ok, b = pcall(SB.Get, name)
		if not ok or type(b) ~= "table" then
			return 1
		end
		local score = tonumber(b.Coins) or 1
		local luck = tonumber(b.Luck) or 1
		if luck ~= 1 and N.castModel then
			local cur = 1
			pcall(function()
				cur = SB.WornMultiplier(N.data(), "Luck")
			end)
			local base, up = N.castModel({ luckMult = 1 / math.max(cur, 0.01) }), N.castModel({ luckMult = luck / math.max(cur, 0.01) })
			score *= if base and up and base > 0 then up / base else luck ^ 0.5
		end
		score *= 1 + ((tonumber(b.Mutation) or 1) - 1) * 0.1
		score *= 1 + ((tonumber(b.Treasure) or 1) - 1) * 0.05
		score *= 1 + ((tonumber(b.XP) or 1) - 1) * 0.02
		if tonumber(b.Golden) then
			score *= 1 + (1 / math.max(10 - tonumber(b.Golden), 2) - 0.1)
		end
		score *= 1 + (tonumber(b.DoubleCatch) or 0)
		return score
	end
	function N.skinStep()
		local S2 = N.Skin
		if not on("WearBestSkin") or os.clock() < S2.holdUntil or not N.due("skin", 60) then
			return false
		end
		local d = N.data()
		local worn = tostring(d.SkinEquipped or "")
		local best, bestScore = worn, if worn ~= "" then N.skinScore(worn) else 1
		local owned = 0
		for name, v in pairs(N.tab("Skins")) do
			if (tonumber(v) or 0) > 0 or type(v) == "table" then
				owned += 1
				local s = N.skinScore(name)
				if s > bestScore * 1.002 then
					best, bestScore = name, s
				end
			end
		end
		S2.last = string.format("Wearing %s (x%.2f income); %d skins owned", if worn ~= "" then worn else "no skin", if worn ~= "" then N.skinScore(worn) else 1, owned)
		if best == worn or best == "" then
			return false
		end
		N.pauseFishing()
		send("Skins", "Equip", best, 0)
		local ok = waitFor(function()
			return N.data().SkinEquipped == best
		end, 3)
		log(if ok then "SKIN wear ok" else "SKIN wear FAILED", best, string.format("x%.3f income", bestScore), "was=" .. (if worn ~= "" then worn else "none"), if ok then "" else "answer=SkinEquipped unchanged")
		if ok then
			S2.last = string.format("Wearing %s (x%.2f income); %d skins owned", best, bestScore, owned)
		else
			S2.holdUntil = os.clock() + 1800
		end
		N.resumeFishing()
		return true
	end
	function N.pondPetStep(atPond)
		local PP = N.PondPets
		if not on("AutoPondPets") then
			return false
		end
		if not atPond and not N.due("pondPetsCheck", 60) then
			return false
		end
		if not N.unlocked("Pond") then
			PP.last = "Pond locked"
			return false
		end
		local PC = cfg("PetConfig")
		local max = tonumber(PC and PC.MaxPondPets) or 10
		local keepOut = {}
		for guid in pairs(N.equippedPets()) do
			keepOut[guid] = true
		end
		local best = N.bestFishingPet and N.bestFishingPet(true)
		if best then
			keepOut[best.guid] = true
		end
		if on("SellPet") then
			local coins = N.bestCoinsPet(true)
			if coins then
				keepOut[coins.guid] = true
			end
		end
		local list = {}
		for _, e in ipairs(N.itemsOf("Pet")) do
			if not keepOut[e.guid] then
				table.insert(list, { guid = e.guid, item = e.item, b = N.pondBonus(e.item) })
			end
		end
		table.sort(list, function(a, b)
			return a.b > b.b
		end)
		local target, bonus = {}, 0
		for i = 1, math.min(max, #list) do
			target[list[i].guid] = true
			bonus += list[i].b
		end
		local current = N.pondPets()
		local out, into = {}, {}
		for guid in pairs(current) do
			if not target[guid] then
				table.insert(out, guid)
			end
		end
		for guid in pairs(target) do
			if not current[guid] then
				table.insert(into, guid)
			end
		end
		PP.last = string.format("%d/%d pets in the pond, +%d%% pond income", count(current), max, math.floor(bonus * 100 + 0.5))
		if #out == 0 and #into == 0 then
			return false
		end
		if not atPond then
			if N.worldKey() ~= "Pond" then
				if not N.due("pondPets", 900) or N.tripBlocked("pond pets") then
					return false
				end
				local back = N.worldKey()
				if not N.travel("Pond") then
					return false
				end
				local did = N.pondPetStep(true)
				N.travel(if back ~= "Pond" then back else N.bestFishingWorld())
				return did
			end
		end
		for _, guid in ipairs(out) do
			send("EquipPet", "PondUnequip", guid)
			task.wait(0.15)
		end
		for _, guid in ipairs(into) do
			send("EquipPet", "PondEquip", guid)
			task.wait(0.15)
		end
		local ok = waitFor(function()
			local now = N.pondPets()
			for guid in pairs(target) do
				if not now[guid] then
					return false
				end
			end
			return true
		end, 2.5)
		PP.last = string.format("%d/%d pets in the pond, +%d%% pond income", count(N.pondPets()), max, math.floor(bonus * 100 + 0.5))
		log("POND pets", "in=" .. #into, "out=" .. #out, "now=" .. count(N.pondPets()) .. "/" .. max, "bonus=+" .. math.floor(bonus * 100 + 0.5) .. "%", if ok then "ok" else "partly (needs your own pond island)")
		if not N.memo("pond_pets") then
			N.memo("pond_pets", if ok then "accepted" else "rejected")
			log("PROBE", "pond_pets", "result=" .. (if ok then "accepted" else "rejected"), "gain=+" .. math.floor(bonus * 100 + 0.5) .. "%")
		end
		return true
	end
end
local Window, Tabs, Labels
do
	do
		local setIdentity = setthreadidentity or set_thread_identity or setidentity or (syn and syn.set_thread_identity)
		function N.fixIdentity()
			if setIdentity then
				pcall(setIdentity, 8)
			end
		end
		N.fixIdentity()
	end
	Window = Library:CreateWindow({
		Title = "Jiro",
		Author = "Jiro",
		Theme = "Jiro Silver",
		Icon = "jiro",
		Footer = GameName,
		FooterGame = true,
		NotifySide = "Right",
		ShowCustomCursor = false,
		ToggleKeybind = Enum.KeyCode.RightControl,
		Center = true,
		AutoShow = true,
	})
	function N.addTab(name, icon, description)
		if Window.AddInfoTab then
			return Window:AddTab({ Name = name, Icon = icon, Description = description })
		end
		return Window:AddTab(name, icon)
	end
	Tabs = {}
	if Window.AddInfoTab then
		pcall(function()
			Tabs.Info = Window:AddInfoTab({
				Discord = Discord,
				DiscordAvatar = "jiro-square",
				DiscordBanner = "jiro-banner",
				DiscordTitle = "Jiro",
				DiscordDescription = "Keyless scripts, updates and support",
				Feedback = function(Box)
					Tabs.FeedbackBox = Box
				end,
			})
		end)
	end
	Tabs.Main = N.addTab("Main", "house", "Quick Start and what Jiro does next")
	Tabs.Fishing = N.addTab("Fishing", "fish", "Auto Fish, throw charges, Smart Sell, bait, pond and the Smart Planner")
	Tabs.Upgrades = N.addTab("Upgrades", "trending-up", "Upgrades, rods, worlds and the traveling merchant")
	Tabs.Rewards = N.addTab("Rewards", "gift", "Daily, playtime, season, achievements, codes, the Big Mouth and cargo orders")
	Tabs.Items = N.addTab("Items", "backpack", "Chests, potions, relics, enchants, mutations, pets and eggs")
	Tabs.Stats = N.addTab("Stats", "chart-column", "Session progress and rates")
	Tabs.Webhook = N.addTab("Webhook", "webhook", "Discord posts")
	if Window.AddMiscTab then
		pcall(function()
			Tabs.Misc = Window:AddMiscTab({ Description = "Performance, AFK and connection", RejoinScript = LoaderScript })
		end)
	end
	Labels = {}
	N.FarmToggles = {
		{ "AutoFish", "Fish" },
		{ "SmartSell", "Sell" },
		{ "SmartPlanner", "Smart Planner" },
		{ "AutoBait", "Bait" },
		{ "AutoPond", "Pond" },
		{ "AutoUpgrades", "Upgrades" },
		{ "AutoRods", "Rods" },
		{ "AutoWorlds", "Worlds" },
		{ "AutoRewards", "Rewards" },
		{ "AutoCodes", "Codes" },
		{ "AutoBigMouth", "Big Mouth" },
		{ "AutoOpen", "Open chests" },
		{ "AutoPotions", "Potions" },
		{ "AutoRelics", "Relics" },
		{ "AutoEnchant", "Enchant" },
		{ "AutoMutate", "Mutations" },
		{ "KeepStreak", "Catch streak" },
		{ "AutoCargo", "Cargo orders" },
		{ "AutoEggs", "Eggs" },
		{ "AutoEquipPet", "Pets" },
		{ "AutoPondPets", "Pond pets" },
		{ "AutoMerchant", "Merchant" },
		{ "UseCharges", "Throw charges" },
		{ "UseSummons", "Sunken Crowns" },
		{ "WearBestSkin", "Rod skin" },
	}
	function N.resetOptions()
		local ignore = (SaveManager and SaveManager.Ignore) or {}
		local function skip(name)
			return ignore[name] == true or name == "MenuKeybind" or string.find(name, "^SaveManager") ~= nil or string.find(name, "^Jiro") ~= nil or string.find(name, "^ThemeManager") ~= nil
		end
		N.quiet = true
		local changed = 0
		for name, toggle in pairs(Toggles) do
			local default = toggle.Default
			if not skip(name) and type(default) == "boolean" and toggle.Value ~= default then
				pcall(toggle.SetValue, toggle, default)
				changed += 1
			end
		end
		for name, option in pairs(Options) do
			local kind = option.Type
			local default = option.Default
			if not skip(name) and default ~= nil and kind ~= "KeyPicker" and kind ~= "ColorPicker" then
				local value = default
				if type(default) == "table" and option.Multi then
					value = {}
					for k, v in pairs(default) do
						if type(k) == "number" then
							value[v] = true
						elseif v then
							value[k] = true
						end
					end
				elseif type(default) == "table" then
					value = default[1]
				end
				pcall(option.SetValue, option, value)
				changed += 1
			end
		end
		N.quiet = false
		log("RESET options to defaults", "controls", changed)
		notify("Jiro", "All hub options are back to their defaults. Saved configs are untouched", 5)
	end
	function N.askReset()
		Library:ShowConfirmPrompt({
			Title = "Reset Hub Options",
			Text = "Reset all options to defaults?",
			Warning = "Saved configs are not deleted",
			ConfirmText = "Reset",
			CancelText = "Cancel",
			OnConfirm = function()
				N.resetOptions()
			end,
		})
	end
	local function listKeys(path, filter)
		local t = N.sh(path)
		local items = type(t) == "table" and (t.Items or t) or {}
		local out = {}
		if type(items) == "table" then
			for name, def in pairs(items) do
				if type(name) == "string" and type(def) == "table" and (not filter or filter(def)) then
					table.insert(out, name)
				end
			end
		end
		table.sort(out)
		return out
	end
	do
		local FishBox = Tabs.Fishing:AddLeftGroupbox("Auto Fish", "fish")
		FishBox:AddToggle("AutoFish", {
			Text = "Auto Fish",
			Default = false,
			Tooltip = "Goes to the pier, holds your rod, finishes the tutorial and fishes. Mode picks how. It also sets the game's Rare Cutscene setting to None once, so a rare catch no longer holds the next cast for 4-7 s",
			Callback = function(v)
				if not v and not N.planner() then
					N.fishOff()
				end
			end,
		})
		FishBox:AddDropdown("FishMode", {
			Text = "Mode",
			Values = { "Fast (default)", "Legit (game's auto fishing)" },
			Default = "Fast (default)",
			Tooltip = "Fast (default): casts through the game's remotes, hooks the best fish of the whole school and reels right away (about 2x faster). If the server refuses casts or shows an error message, the hub uses the game's auto fishing for 5 minutes the first time that day and 30 minutes after that; after 3 such pauses in a day it stays on it for the day. Legit: always the game's own auto fishing, aimed at the most valuable fish",
		})
		FishBox:AddSlider("PerfectRate", {
			Text = "Perfect Rate",
			Default = 60,
			Min = 0,
			Max = 95,
			Rounding = 0,
			Suffix = "%",
			Tooltip = "Share of Perfect throws (+33% distance, deeper water, more fish). 60% is what the game's AutoBoost enchant gives",
		})
		FishBox:AddToggle("IndexHunt", { Text = "Index Hunt", Default = false, Tooltip = "Counts species missing from your index 50% higher when picking fish (every 10/25/50/75/100 species = +10% on all sales)" })
		FishBox:AddToggle("TutorialHold", {
			Text = "Tutorial hold (x2 luck)",
			Default = false,
			Tooltip = "Stops the tutorial at step 6 and keeps it there: the server gives every cast x2 luck, x1.3 distance and 2 free bounces while you are on that step. The price: no playtime gifts, quests or guaranteed scrolls until the tutorial is finished. For new accounts only (an account that already finished the tutorial cannot go back, the toggle then does nothing). Off = the tutorial is finished for you. With the Smart Planner on, it compares the two and finishes the tutorial itself only when that is worth more (log TUTORIAL hold / TUTORIAL finish reason=)",
		})
		FishBox:AddToggle("KeepStreak", {
			Text = "Keep catch streak on trips",
			Default = false,
			Tooltip = "Your catch streak (a catch every 90 s) gives up to +20% luck at 2,500 catches. During sell, pond, egg, merchant and world trips Jiro sends the game's own streak holds (the cutscene one, plus the menu one on long trips) and releases them when fishing resumes. The server limits how long a hold lasts",
		})
		Labels.Fish = FishBox:AddLabel({ Text = "-", DoesWrap = true })
		local ChargeBox = Tabs.Fishing:AddLeftGroupbox("Throw Charges", "zap")
		ChargeBox:AddToggle("UseCharges", {
			Text = "Use owned throw charges",
			Default = false,
			Tooltip = "Spends the throw charges you already own (Collect All, More Fish, Mutation Luck) on a school worth it: Collect All when the fish over your hook limit are worth at least 4 average casts, with More Fish and Mutation Luck first. Never buys charges (they cost Robux). Freeze Fish is never used (it only changes the game's visuals)",
		})
		Labels.Charges = ChargeBox:AddLabel({ Text = "-", DoesWrap = true })
		local SellBox = Tabs.Fishing:AddRightGroupbox("Smart Sell", "coins")
		SellBox:AddToggle("SmartSell", {
			Text = "Smart Sell",
			Default = false,
			Tooltip = "Sells all unlocked fish (the merchant's Sell All) when the backpack fills, during a server CashBoost, when the Smart Planner needs the cash, or on the timer. Kept fish are locked first",
		})
		SellBox:AddSlider("SellAt", { Text = "Sell at backpack", Default = 80, Min = 10, Max = 100, Rounding = 0, Suffix = "%" })
		SellBox:AddSlider("SellEvery", { Text = "Also sell every", Default = 0, Min = 0, Max = 60, Rounding = 0, Suffix = " min", HideMax = true, Tooltip = "0 = only by the rules above" })
		local rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Exotic" }
		SellBox:AddDropdown("KeepRarities", { Text = "Keep rarities", Values = rarities, Default = { "Secret", "Exotic" }, Multi = true, AllowNull = true, Tooltip = "Fish of these rarities are locked (favorited) and never sold" })
		SellBox:AddToggle("KeepMutated", { Text = "Keep mutated fish", Default = false })
		SellBox:AddDropdown("KeepFish", { Text = "Keep fish", Values = listKeys("Content.Item.Fish"), Default = {}, Multi = true, AllowNull = true, Searchable = true, Tooltip = "These species are locked and never sold" })
		SellBox:AddToggle("SellPotion", {
			Text = "Coins potion at sale",
			Default = false,
			Tooltip = "The game prices fish when you sell, not when you catch them. With this on, Smart Sell holds the catch up to 95% of the backpack, drinks one of your Coins potions (+50%) right before the full sale and sells again just before the potion ends, so one potion covers the whole backpack plus 10 minutes of catches. Auto Potions then leaves the Coins potions to Smart Sell",
		})
		SellBox:AddToggle("SellPet", {
			Text = "Coins pet at sale",
			Default = false,
			Tooltip = "Right before a sale, equips your best Coins pet (Lion x1.1, Koala x1.08, Bull x1.05 ...) and puts your fishing pet back right after. Only pets outside the pond",
		})
		SellBox:AddButton({
			Text = "Sell Now",
			Func = function()
				task.spawn(N.runManual, function()
					N.sellNow("button")
				end)
			end,
		})
		Labels.Sell = SellBox:AddLabel({ Text = "-", DoesWrap = true })
		local BaitBox = Tabs.Fishing:AddLeftGroupbox("Bait", "worm")
		BaitBox:AddToggle("AutoBait", { Text = "Auto Bait", Default = false, Tooltip = "Keeps your strongest bait active (one bait = 5 casts)" })
		BaitBox:AddToggle("BuyBait", { Text = "Buy bait", Default = true, Tooltip = "With Auto Bait: buys the strongest bait in stock whose cost per cast stays under the budget" })
		BaitBox:AddSlider("BaitBudget", { Text = "Bait budget", Default = 10, Min = 1, Max = 50, Rounding = 0, Suffix = "% of a cast", Tooltip = "Most a bait may cost per cast, as a share of what one cast earns" })
		Labels.Bait = BaitBox:AddLabel({ Text = "-", DoesWrap = true })
		local PondBox = Tabs.Fishing:AddRightGroupbox("Pond", "droplets")
		PondBox:AddToggle("AutoPond", {
			Text = "Auto Pond",
			Default = false,
			Tooltip = "Unlocks the pond (level 5), then visits it: collects the income, fills it with your best fish (the game's Equip Best), revives or clears dead fish, buys food and capacity",
		})
		PondBox:AddSlider("PondEvery", { Text = "Visit every", Default = 60, Min = 20, Max = 240, Rounding = 0, Suffix = " min", Tooltip = "Without the Smart Planner. The planner goes for a capacity upgrade, for coins that complete its next buy, when the food falls under half, near the 8 hour cap or every 3 hours, and leaves food for the game's Auto Feed" })
		Labels.Pond = PondBox:AddLabel({ Text = "-", DoesWrap = true })
		local PlanBox = Tabs.Fishing:AddLeftGroupbox("Smart Planner", "brain")
		PlanBox:AddToggle("SmartPlanner", {
			Text = "Smart Planner",
			Default = false,
			Tooltip = "Autopilot: plays the whole game by itself, even with every other toggle off. Fishes (Mode and Perfect Rate from Auto Fish), sells by the Smart Sell rules and protect lists when the backpack needs it or a purchase waits, buys upgrades, rods, bait, the next world, the pond and offline net levels in the order of the fastest payback (price / extra coins per second, within 24 h); with Tutorial hold on it also decides whether holding the tutorial still beats finishing it, visits the pond, claims rewards and codes, plays the cargo orders (gives, sends, claims), buys from the traveling merchant by value, keeps trips out of the whale egg windows, feeds the Big Mouth, opens chests and keeps the catch streak on trips. Your potions, relics, scrolls, throw charges, eggs and pets are used only by their own toggles. Saving for something = fishing meanwhile. Your other toggles stay as you set them",
			Callback = function(v)
				if not v then
					N.plannerOffAt = os.clock()
					if N.InfoText then
						N.InfoText.planner = "Smart Planner is off"
						N.InfoText.plan = "Smart Planner is off"
					end
					setStatus(if N.Fish and N.Fish.cast then "Smart Planner off, finishing the cast in flight" else "Smart Planner off")
					if not on("AutoFish") then
						N.fishOff()
					end
				end
			end,
		})
		Labels.Planner = PlanBox:AddLabel({ Text = "-", DoesWrap = true })
		local ProbeBox = Tabs.Fishing:AddRightGroupbox("Probes", "flask-conical")
		ProbeBox:AddToggle("ProbeSell2", {
			Text = "Probe: sell one fish twice",
			Default = false,
			Tooltip = "One-shot experiment (once per game version): at the merchant, sells one cheap fish with two Sell calls at the same moment. The expected answer is one sale and one refusal; the result goes to the log (PROBE sell2 result=) and switches the toggle off",
		})
		ProbeBox:AddToggle("ProbeTpLocked", {
			Text = "Probe: teleport to a locked world",
			Default = false,
			Tooltip = "One-shot experiment (once per game version): asks the server to teleport you to the next world above your level, which the game normally gates. The expected answer is a refusal; the result goes to the log (PROBE tp_locked result=)",
		})
		ProbeBox:AddToggle("ProbeStreakHold", {
			Text = "Probe: streak hold",
			Default = false,
			Tooltip = "One-shot experiment (once per game version): sends the game's own StreakHold(true) and checks whether the server holds your streak, then releases it. The result goes to the log (PROBE streakhold result=)",
		})
		Labels.Probes = ProbeBox:AddLabel({ Text = "-", DoesWrap = true })
		N.QuickBox = Tabs.Main:AddLeftGroupbox("Quick Start", "zap")
		local StatusBox = Tabs.Main:AddRightGroupbox("Status", "activity")
		Labels.Status = StatusBox:AddLabel({ Text = "Idle", DoesWrap = true })
		Labels.Info = StatusBox:AddLabel({ Text = "-", DoesWrap = true })
		Labels.Plan = StatusBox:AddLabel({ Text = "-", DoesWrap = true })
		Labels.Lines = StatusBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local UpBox = Tabs.Upgrades:AddLeftGroupbox("Upgrades", "arrow-up")
		UpBox:AddToggle("AutoUpgrades", { Text = "Auto Upgrades", Default = false, Tooltip = "Buys the cheapest picked upgrade you can afford (Capacity = hooks per cast, Strength = distance, Weight = depth, Bounce). Smart Planner buys by payback instead" })
		UpBox:AddDropdown("UpgradeStats", { Text = "Upgrades", Values = { "Capacity", "Strength", "Weight", "Bounce" }, Default = { "Capacity", "Strength", "Weight", "Bounce" }, Multi = true, AllowNull = true })
		Labels.Upgrades = UpBox:AddLabel({ Text = "-", DoesWrap = true })
		local RodBox = Tabs.Upgrades:AddRightGroupbox("Rods", "anchor")
		RodBox:AddToggle("AutoRods", { Text = "Auto Rods", Default = false, Tooltip = "Buys the strongest rod you can afford and equips your best rod. Smart Planner buys by payback instead" })
		Labels.Rods = RodBox:AddLabel({ Text = "-", DoesWrap = true })
		local WorldBox = Tabs.Upgrades:AddRightGroupbox("Worlds", "globe")
		WorldBox:AddToggle("AutoWorlds", { Text = "Auto Worlds", Default = false, Tooltip = "Unlocks the next world once your level and cash allow (the game's own level and price for each world) and fishes in the best one" })
		WorldBox:AddDropdown("MoveMode", { Text = "Movement", Values = { "Walk", "Teleport" }, Default = "Teleport", Tooltip = "Teleport (default): straight to the pier, merchant and shops. Walk: walks there" })
		Labels.World = WorldBox:AddLabel({ Text = "-", DoesWrap = true })
		local MerchantBox = Tabs.Upgrades:AddLeftGroupbox("Traveling Merchant", "store")
		MerchantBox:AddToggle("AutoMerchant", {
			Text = "Auto Merchant",
			Default = false,
			Tooltip = "The traveling merchant visits World 1 for 10 minutes every 90 minutes. Jiro reads its offers from anywhere, goes to Merchant Island while it is there and sells fish first when the cash is short. Buy picks what: Eggs (every egg in stock, the main way to new pets), Potions (the kinds your Auto Potions or Coins potion at sale will drink), Bait (20% under the shop price, for Auto Bait or the cargo order), Fish (for a cargo slot), Chests (lucky chests and fish cages, when their coins, bait and fish are worth the price), Keys (fragments of a hall key you do not have yet) and Scrolls (when Auto Enchant or Auto Mutate runs low)",
		})
		MerchantBox:AddDropdown("MerchantBuy", { Text = "Buy", Values = { "Eggs", "Potions", "Bait", "Fish", "Chests", "Keys", "Scrolls" }, Default = { "Eggs", "Potions", "Bait", "Fish", "Chests", "Keys", "Scrolls" }, Multi = true, AllowNull = true, Tooltip = "What Auto Merchant may buy. Eggs are bought whenever in stock; everything else only when it is worth more than its price to you" })
		Labels.Merchant = MerchantBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local RewardBox = Tabs.Rewards:AddLeftGroupbox("Rewards", "gift")
		RewardBox:AddToggle("AutoRewards", {
			Text = "Auto Rewards",
			Default = false,
			Tooltip = "Daily ladder, free daily roll, playtime gifts, next day reward, season tiers (Golden Line tiers too when you own it), the season daily gift and quests, achievements, your gift inbox, offline net catch, and the group, referral, comeback and early leave rewards when you have them. Each claim is checked against the game's own data before it counts as claimed",
		})
		Labels.Rewards = RewardBox:AddLabel({ Text = "-", DoesWrap = true })
		local CodeBox = Tabs.Rewards:AddRightGroupbox("Codes", "ticket")
		CodeBox:AddToggle("AutoCodes", { Text = "Auto Redeem Codes", Default = false, Tooltip = "Redeems every known code once on this account, plus your secret code from the four signs" })
		CodeBox:AddButton({
			Text = "Redeem all known",
			Func = function()
				N.redeemAllCodes()
			end,
		})
		CodeBox:AddInput("CodeText", { Text = "Code", Placeholder = "Type a code from the game's socials", Finished = false, Default = "" })
		CodeBox:AddButton({
			Text = "Redeem",
			Func = function()
				N.redeemCode(Options.CodeText and Options.CodeText.Value)
				pcall(Options.CodeText.SetValue, Options.CodeText, "")
			end,
		})
		Labels.Codes = CodeBox:AddLabel({ Text = "-", DoesWrap = true })
		local MouthBox = Tabs.Rewards:AddLeftGroupbox("Big Mouth", "smile")
		MouthBox:AddToggle("AutoBigMouth", { Text = "Auto Big Mouth", Default = false, Tooltip = "Every 12 h feeds the Big Mouth (World 1) until its weight goal is met, with the fish that cost the least per kg (often one heavy cheap fish): permanent luck (+10% for the first five, then +5%, up to +200%) and a reward roll. Kept and locked fish are never fed" })
		Labels.BigMouth = MouthBox:AddLabel({ Text = "-", DoesWrap = true })
		local CargoBox = Tabs.Rewards:AddRightGroupbox("Cargo Orders", "ship")
		CargoBox:AddToggle("AutoCargo", {
			Text = "Auto Tasks (cargo orders)",
			Default = false,
			Tooltip = "Plays the cargo orders (task board, one every 6 hours) from anywhere: keeps the fish the order needs (locked before every sale), aims the casts at the missing species, gives them to the ship, buys the bait or food slots when the reward covers them, sends the ship and claims the reward when it is back. Waits for your next level when that gives a better order tier. A reward = at least 1.5x what you give (500 to 100M by level) plus XP, a Luck potion, a chest and an egg. Your own bait and food stacks are given only with this toggle on (the Smart Planner alone buys what the order needs)",
		})
		Labels.Cargo = CargoBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local OpenBox = Tabs.Items:AddLeftGroupbox("Chests & Gifts", "package-open")
		OpenBox:AddToggle("AutoOpen", { Text = "Auto Open", Default = false, Tooltip = "Opens chests, cages and like gifts from your catches" })
		Labels.Open = OpenBox:AddLabel({ Text = "-", DoesWrap = true })
		local PotionBox = Tabs.Items:AddRightGroupbox("Potions", "flask-conical")
		PotionBox:AddToggle("AutoPotions", { Text = "Auto Potions", Default = false, Tooltip = "Drinks a picked potion when none of its kind runs (not in the pond, where potions pause)" })
		PotionBox:AddDropdown("PotionKinds", { Text = "Potions", Values = { "Luck", "Coins", "XP", "Mutation", "Capacity" }, Default = { "Luck", "Coins", "XP", "Mutation", "Capacity" }, Multi = true, AllowNull = true })
		Labels.Potions = PotionBox:AddLabel({ Text = "-", DoesWrap = true })
		local RelicBox = Tabs.Items:AddLeftGroupbox("Boss Relics & Summons", "crown")
		RelicBox:AddToggle("AutoRelics", { Text = "Auto Relics", Default = false, Tooltip = "Uses boss relics: luck relics right away, the Kraken relic (x10 on the next sale) right before Smart Sell sells" })
		RelicBox:AddToggle("UseSummons", {
			Text = "Use Sunken Crowns",
			Default = false,
			Tooltip = "Uses your Sunken Crowns one at a time: each summons a boss to the server for 10 minutes (Sunken King 90%, Sunken Queen 10%) and you get x5 luck to catch it (its relic: +50 or +100 throw luck, a season fish). Never while a boss already runs or whale eggs are open",
		})
		local EnchantBox = Tabs.Items:AddRightGroupbox("Enchant", "sparkles")
		EnchantBox:AddToggle("AutoEnchant", { Text = "Auto Enchant", Default = false, Tooltip = "At the Stone Mage: rolls Enchant Stones (slot 1) and Ultra Enchant Stones (slot 2) until the rod has a picked enchant" })
		EnchantBox:AddDropdown("EnchantTargets", { Text = "Stop at", Values = listKeys("Config.EnchantConfig"), Default = { "Trawler", "Fishmonger", "Deepnet", "Midas" }, Multi = true, AllowNull = true, Searchable = true })
		Labels.Enchant = EnchantBox:AddLabel({ Text = "-", DoesWrap = true })
		local MutateBox = Tabs.Items:AddLeftGroupbox("Mutation Dealer", "dna")
		MutateBox:AddToggle("AutoMutate", { Text = "Auto Mutate", Default = false, Tooltip = "Spends Mutation Scrolls at the Mutation Dealer on your most valuable fish without a mutation (x2 to x15 sell value)" })
		MutateBox:AddDropdown("MutateScroll", { Text = "Scroll", Values = { "Mutation Scroll first", "Ultra first" }, Default = "Mutation Scroll first", Tooltip = "Which scroll Auto Mutate spends first. Ultra Mutation Scrolls roll the better mutations; with only Ultra scrolls left they are used either way" })
		Labels.Items = MutateBox:AddLabel({ Text = "-", DoesWrap = true })
		local PetBox = Tabs.Items:AddRightGroupbox("Pets, Eggs & Skin", "paw-print")
		PetBox:AddToggle("AutoEggs", {
			Text = "Auto Hatch Eggs",
			Default = false,
			Tooltip = "Takes your eggs to the hatchery on your pond island (5 slots), hatches the grown ones (the most valuable first) and places new ones, the best eggs first. With Auto Relics on, the Whale relic (x5 hatch luck) is used right before hatching a valuable egg, never on a Default egg. Trips wait while whale eggs are open. Never touches the Robux Hatch Now",
		})
		PetBox:AddToggle("AutoEquipPet", {
			Text = "Equip Best Pet",
			Default = false,
			Tooltip = "Equips the pet that adds the most income at its max level (levels come in about 1.5 h of fishing): coins, luck (priced through better fish), mutation, golden throws, double catches and pets that fish by themselves, shiny included",
		})
		PetBox:AddToggle("AutoPondPets", {
			Text = "Auto Pond Pets",
			Default = false,
			Tooltip = "Puts up to 10 of your other pets into the pond (each adds 1% to 15% pond income, shiny x1.5), the best ones first, on your pond trips. Your fishing pet (and the Coins pet with Coins pet at sale) stay out",
		})
		PetBox:AddToggle("WearBestSkin", {
			Text = "Wear best rod skin",
			Default = false,
			Tooltip = "Wears the rod skin you own that adds the most income (luck, coins at sale, mutation, golden throws), switching between casts. It changes how your rod looks",
		})
		Labels.Pets = PetBox:AddLabel({ Text = "-", DoesWrap = true })
	end
	do
		local QuickBox = N.QuickBox
		N.Mirrors = {}
		local syncing = false
		local function setQuiet(toggle, v)
			syncing = true
			local quiet = N.quiet
			N.quiet = true
			pcall(toggle.SetValue, toggle, v)
			N.quiet = quiet
			syncing = false
		end
		local function mirror(main, text, tooltip)
			if Library.MirrorToggle then
				local ok, made = pcall(Library.MirrorToggle, Library, main, QuickBox, { Text = text, Tooltip = tooltip })
				if ok and made then
					return made
				end
			end
			local id = "QS" .. main
			local copy = QuickBox:AddToggle(id, {
				Text = text,
				Default = false,
				Tooltip = tooltip,
				Callback = function(v)
					local target = Toggles[main]
					if syncing or not target or target.Value == v then
						return
					end
					syncing = true
					pcall(target.SetValue, target, v)
					syncing = false
				end,
			})
			table.insert(N.Mirrors, { main = main, copy = id })
			local target = Toggles[main]
			if target and target.OnChanged then
				pcall(target.OnChanged, target, function(v)
					local q = Toggles[id]
					if not syncing and q and q.Value ~= v then
						setQuiet(q, v)
					end
				end)
			end
			return copy
		end
		function N.syncMirrors()
			for _, m in ipairs(N.Mirrors) do
				local a, b = Toggles[m.main], Toggles[m.copy]
				if a and b and a.Value ~= b.Value and not syncing then
					setQuiet(b, a.Value)
				end
			end
		end
		mirror("AutoFish", "Auto Fish", "Same as Fishing > Auto Fish (the mode is picked there)")
		mirror("SmartSell", "Smart Sell", "Same as Fishing > Smart Sell")
		mirror("SmartPlanner", "Smart Planner", "Same as Fishing > Smart Planner: the autopilot fishes, sells, buys by payback, visits the pond and claims everything by itself")
		mirror("AutoPond", "Auto Pond", "Same as Fishing > Auto Pond")
		mirror("AutoRewards", "Auto Rewards", "Same as Rewards > Auto Rewards")
		QuickBox:AddButton({
			Text = "Stop Everything",
			Tooltip = "Turns every automation off",
			Func = function()
				N.stopAll()
			end,
		})
		QuickBox:AddButton({
			Text = "Reset Hub Options",
			Tooltip = "Puts every toggle, dropdown, slider and input back to its default. Saved configs are not deleted",
			Func = function()
				N.askReset()
			end,
		})
	end
end
N.StatRows = {}
do
	local function statRow(box, icon, text, size, color)
		if box.AddStat then
			local ok, stat = pcall(box.AddStat, box, { Icon = icon, Text = text, Value = "-", Size = size or 22, ValueColor = color })
			if ok and stat then
				return {
					set = function(value)
						stat:SetValue(value)
					end,
				}
			end
		end
		local label = box:AddLabel({ Text = text .. ": -", DoesWrap = true })
		return {
			set = function(value)
				label:SetText(text .. ": " .. tostring(value))
			end,
		}
	end
	local ProgressBox = Tabs.Stats:AddLeftGroupbox("Progress", "trending-up")
	N.StatRows.Cash = statRow(ProgressBox, "coins", "Coins", 28)
	N.StatRows.Earned = statRow(ProgressBox, "trending-up", "Earned this session", 22, "FontColor")
	N.StatRows.Rate = statRow(ProgressBox, "activity", "Coins per hour", 22, "FontColor")
	N.StatRows.Level = statRow(ProgressBox, "chevrons-up", "Level", 22)
	N.StatRows.World = statRow(ProgressBox, "globe", "World", 22)
	N.StatRows.Time = statRow(ProgressBox, "clock", "Session", 22, "FontColor")
	local FishStats = Tabs.Stats:AddRightGroupbox("Fishing", "fish")
	N.StatRows.Casts = statRow(FishStats, "target", "Casts / Perfect", 28)
	N.StatRows.Caught = statRow(FishStats, "fish", "Fish caught / finds", 22)
	N.StatRows.Best = statRow(FishStats, "award", "Best fish", 22)
	N.StatRows.Cycle = statRow(FishStats, "timer", "Cast time / value", 22)
	N.StatRows.Sold = statRow(FishStats, "coins", "Sold fish / coins", 22)
	N.StatRows.Backpack = statRow(FishStats, "backpack", "Backpack", 22)
	local BuyStats = Tabs.Stats:AddLeftGroupbox("Purchases", "shopping-cart")
	N.StatRows.Buys = statRow(BuyStats, "arrow-up", "Upgrades / rods / worlds", 22)
	N.StatRows.Bait = statRow(BuyStats, "worm", "Baits used", 22)
	N.StatRows.Pond = statRow(BuyStats, "droplets", "Pond trips", 22)
	local RewardStats = Tabs.Stats:AddRightGroupbox("Rewards & Items", "gift")
	N.StatRows.Claims = statRow(RewardStats, "gift", "Rewards claimed", 22)
	N.StatRows.Codes = statRow(RewardStats, "ticket", "Codes redeemed / tried", 22)
	N.StatRows.Items = statRow(RewardStats, "package-open", "Opened / potions / relics", 22)
	function N.drawStats()
		local elapsed = math.max(os.clock() - Session.started, 1)
		local count, max = N.backpack()
		local cash = N.cash()
		local earned = cash + N.Econ.spent - (Session.cashStart or cash)
		local redeemed, tried = N.codeCounts()
		local level = N.level()
		local values = {
			Cash = formatNumber(cash),
			Earned = "+" .. formatNumber(math.max(earned, 0)),
			Rate = formatNumber(N.Econ.rate * 3600),
			Level = string.format("%d (+%d)", level, level - (Session.levelStart or level)),
			World = N.worldKey(),
			Time = string.format("%dh %02dm", elapsed // 3600, (elapsed % 3600) // 60),
			Casts = formatNumber(Session.casts) .. " / " .. formatNumber(Session.perfect),
			Caught = formatNumber(Session.caught) .. " / " .. formatNumber(Session.specials),
			Best = tostring(Session.bestName) .. " " .. formatNumber(Session.bestFish or 0),
			Cycle = string.format("%.1f s / %s", N.Fish.cycle, formatNumber(N.Fish.evCast)),
			Sold = formatNumber(Session.sold) .. " / " .. formatNumber(Session.soldValue),
			Backpack = count .. " / " .. max,
			Buys = Session.upgrades .. " / " .. Session.rods .. " / " .. Session.worlds,
			Bait = tostring(Session.baits),
			Pond = tostring(Session.pondTrips),
			Claims = tostring(Session.claims),
			Codes = redeemed .. " / " .. tried,
			Items = Session.opened .. " / " .. Session.potions .. " / " .. Session.relics,
		}
		if N.fixIdentity then
			N.fixIdentity()
		end
		for key, value in pairs(values) do
			local row = N.StatRows[key]
			if row then
				row.set(value)
			end
		end
	end
end
local Debug = {}
do
	function Debug.perfText()
		local last = Perf.last
		if not last then
			return "first reading in 30 s"
		end
		return string.format(
			"fps %d, worst frame %dms, hitches %d, freezes %d, Jiro used %dms in %ds (%.2f%%), ping %sms, memory %sMB",
			math.floor(last.fps + 0.5),
			math.floor(last.worst * 1000),
			last.hitches,
			last.freezes,
			math.floor(last.hub * 1000),
			math.floor(last.span),
			last.hub / math.max(last.span, 1) * 100,
			tostring(last.ping),
			tostring(last.memory)
		)
	end
	function Debug.running()
		local running = {}
		for _, row in ipairs(N.FarmToggles) do
			if on(row[1]) then
				table.insert(running, row[1])
			end
		end
		return running
	end
	function Debug.header()
		local elapsed = math.floor(os.clock() - Session.started)
		local executor = "?"
		pcall(function()
			executor = table.concat({ identifyexecutor() }, " ")
		end)
		local d = N.data()
		local count, max = N.backpack()
		local lines = {
			"Jiro debug log  |  " .. GameName,
			string.format("Player %s (@%s)  |  executor %s  |  place %s  |  %s", LocalPlayer.DisplayName, LocalPlayer.Name, executor, tostring(game.PlaceId), os.date("%Y-%m-%d %H:%M:%S")),
			string.format(
				"Session %dh %02dm  |  casts %d (perfect %d, refused %d)  |  caught %d, finds %d, fights %d  |  sold %d for %s  |  upgrades %d, rods %d, worlds %d, baits %d  |  pond %d  |  claims %d, codes %d",
				elapsed // 3600,
				(elapsed % 3600) // 60,
				Session.casts,
				Session.perfect,
				Session.refused,
				Session.caught,
				Session.specials,
				Session.fights,
				Session.sold,
				formatNumber(Session.soldValue),
				Session.upgrades,
				Session.rods,
				Session.worlds,
				Session.baits,
				Session.pondTrips,
				Session.claims,
				Session.codes
			),
			"Status: " .. tostring(Status) .. "  |  mode " .. N.fishMode() .. " (" .. tostring(N.Fish.engine) .. ")" .. (if N.Fish.fallbackReason ~= "" then ", last fallback: " .. N.Fish.fallbackReason else "") .. "  |  planner " .. (if N.planner() then "on" else "off"),
			"Running: " .. table.concat(Debug.running(), ", "),
			string.format(
				"Game: world %s, cash %s, level %s, rod %s, hooks %d, backpack %d/%d, tutorial %s, rate %s/h, events %s",
				N.worldKey(),
				formatNumber(N.cash()),
				tostring(d.Level),
				tostring(d.RodEquipped),
				N.hookCap(),
				count,
				max,
				tostring(d.Tutorial),
				formatNumber(N.Econ.rate * 3600),
				(function()
					local n = 0
					for _ in pairs(N.Listeners) do
						n += 1
					end
					return tostring(n)
				end)()
			),
			"Perf: " .. Debug.perfText(),
			"Plan: " .. (if N.Plan.say ~= "" then N.Plan.say else "-"),
			"Problems (" .. Log.problemCount .. "): " .. (if #Log.problems > 0 then table.concat(Log.problems, " | ") else "none"),
			string.rep("-", 70),
		}
		return table.concat(lines, "\n")
	end
	Log.header = Debug.header
end
N.AllAutoToggles = {}
for _, row in ipairs(N.FarmToggles) do
	table.insert(N.AllAutoToggles, row[1])
end
N.Manual = { running = false }
do
	function N.runManual(fn, ...)
		if N.Manual.running then
			notify("Jiro", "Still busy with the last action", 3)
			return
		end
		N.Manual.running = true
		local ok, err = pcall(fn, ...)
		N.Manual.running = false
		if not ok then
			log("ERROR", "manual action", tostring(err))
		end
	end
	function N.stopAll()
		N.quiet = true
		for _, name in ipairs(N.AllAutoToggles) do
			local toggle = Toggles[name]
			if toggle and toggle.Value then
				toggle:SetValue(false)
			end
		end
		for _, name in ipairs(N.Probe.names) do
			local toggle = Toggles[name]
			if toggle and toggle.Value then
				toggle:SetValue(false)
			end
		end
		N.quiet = false
		N.fishOff()
		log("STOP everything")
		notify("Jiro", "Everything is off", 3)
	end
end
do
	local KeepOnTeleport = true
	local function queueSelf()
		local queue = queue_on_teleport or (typeof(syn) == "table" and syn.queue_on_teleport) or queueonteleport
		if type(queue) ~= "function" or INSTANCE.queued or LoaderScript == "" then
			return INSTANCE.queued == true
		end
		INSTANCE.queued = pcall(
			queue,
			table.concat({
				"if not game:IsLoaded() then game.Loaded:Wait() end",
				"if game.GameId ~= " .. tostring(game.GameId) .. " then return end",
				LoaderScript,
			}, "\n")
		)
		return INSTANCE.queued
	end
	if Tabs.Misc then
		pcall(function()
			local ExecBox = Tabs.Misc:AddRightGroupbox("Auto Execute", "zap")
			ExecBox:AddToggle("KeepOnTeleport", {
				Text = "Keep after teleport",
				Default = true,
				Tooltip = "When the game moves you to another server the hub starts again there",
				Callback = function(value)
					KeepOnTeleport = value
				end,
			})
			ExecBox:AddButton({
				Text = "Copy loader",
				Func = function()
					if LoaderScript == "" then notify("Loader", "Set getgenv().LazyJiroLoader to your loader line first, then this button copies it", 6) return end
					local copied = setclipboard and pcall(setclipboard, LoaderScript)
					notify("Loader", if copied then "Copied, put it in your executor's autoexec folder to start the hub on join" else LoaderScript, 6)
				end,
			})
			Library:GiveSignal(LocalPlayer.OnTeleport:Connect(function(state)
				if state == Enum.TeleportState.Started and KeepOnTeleport then
					queueSelf()
				end
			end))
		end)
	end
end
do
	local FeedbackWebhook = (function(hex)
	local key = "jiro"
	local out = {}
	for i = 1, #hex, 2 do
		local index = (i - 1) // 2
		out[#out + 1] = string.char(bit32.bxor(tonumber(string.sub(hex, i, i + 1), 16), string.byte(key, index % #key + 1)))
	end
	return table.concat(out)
end)("0b1b060606494c40161f06100c1d1658161c0e4013061c5c140a101e1a1c081c5d474046555b414645455b5f414f4d42565c46465a213442062c114154242338053c06271f253c393121051a1b365723213f343b153d1d052a00272d43242044363b4331142a273f01250226562e06064046272a3e3b3d3021")
	local Hook = { queue = {}, sent = 0, feedbackAt = -1e9, feedbackCount = 0 }
	local function httpRequest(options)
		local fn = (typeof(syn) == "table" and syn.request) or (typeof(http) == "table" and http.request) or http_request or request
		if type(fn) ~= "function" then
			return nil
		end
		local ok, response = pcall(fn, options)
		return if ok then response else nil
	end
	local function validWebhook(url)
		return type(url) == "string"
			and (
					url:find("^https://discord%.com/api/webhooks/")
					or url:find("^https://discordapp%.com/api/webhooks/")
					or url:find("^https://canary%.discord%.com/api/webhooks/")
					or url:find("^https://ptb%.discord%.com/api/webhooks/")
				)
				~= nil
	end
	local function postWebhook(url, payload)
		if not validWebhook(url) then
			return false, 0
		end
		local response = httpRequest({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
		local code = response and tonumber(response.StatusCode) or 0
		return code >= 200 and code < 300, code
	end
	local GameLink = "https://www.roblox.com/games/" .. tostring(game.PlaceId)
	local function gameField()
		return { name = "Game", value = "[" .. GameName .. "](" .. GameLink .. ")", inline = true }
	end
	local function playerField()
		if Toggles.WebhookHideName and Toggles.WebhookHideName.Value then
			return "Hidden"
		end
		return "||" .. LocalPlayer.Name .. "||"
	end
	local function queueEmbed(embed)
		if #Hook.queue < 30 then
			embed.footer = embed.footer or { text = "Jiro  \u{00B7}  " .. GameName }
			embed.timestamp = embed.timestamp or DateTime.now():ToIsoDate()
			table.insert(Hook.queue, embed)
		end
	end
	local function hookOn()
		return Toggles.WebhookOn and Toggles.WebhookOn.Value
	end
	local function reportEmbed(title)
		local elapsed = math.max(os.clock() - Session.started, 60)
		local count, max = N.backpack()
		return {
			title = title,
			color = 6344854,
			fields = {
				{ name = "Coins", value = formatNumber(N.cash()), inline = true },
				{ name = "Per hour", value = formatNumber(N.Econ.rate * 3600), inline = true },
				{ name = "Level", value = tostring(N.level()), inline = true },
				{ name = "World", value = N.worldKey(), inline = true },
				{ name = "Casts", value = formatNumber(Session.casts), inline = true },
				{ name = "Backpack", value = count .. " / " .. max, inline = true },
				{ name = "Best fish", value = tostring(Session.bestName) .. " " .. formatNumber(Session.bestFish or 0), inline = true },
				{ name = "Sold", value = formatNumber(Session.soldValue), inline = true },
				{ name = "Session", value = string.format("%dh %02dm", elapsed // 3600, (elapsed % 3600) // 60), inline = true },
				{ name = "Player", value = playerField(), inline = true },
			},
		}
	end
	N.Events.cast = function(best, hooked)
		if not (hookOn() and on("WebhookRare") and best and hooked[best.index]) then
			return
		end
		local def = N.fishDef(best.name)
		local rarity = def and def.Rarity or "Common"
		if selected(Options.WebhookRarities, rarity) then
			queueEmbed({
				title = "\u{2726}  Caught " .. tostring(best.name),
				description = "**" .. rarity .. "**, worth **" .. formatNumber(best.value) .. "** coins.",
				color = 11027200,
				fields = { { name = "Player", value = playerField(), inline = true } },
			})
		end
	end
	N.Events.sold = function(amount, value)
		if hookOn() and on("WebhookSales") then
			queueEmbed({
				title = "\u{2726}  Sold " .. tostring(amount) .. " fish",
				description = "For **" .. formatNumber(value) .. "** coins.",
				color = 6283215,
				fields = { { name = "Player", value = playerField(), inline = true } },
			})
		end
	end
	N.Events.code = function(code, message)
		if hookOn() and on("WebhookCodes") then
			queueEmbed({
				title = "\u{2726}  Code " .. tostring(code),
				description = tostring(message or ""),
				color = 6283215,
				fields = { { name = "Player", value = playerField(), inline = true } },
			})
		end
	end
	N.Events.bought = function(name, price)
		if hookOn() and on("WebhookBuys") then
			queueEmbed({
				title = "\u{2726}  Bought " .. tostring(name),
				description = "Paid **" .. formatNumber(price) .. "** coins.",
				color = 8454016,
				fields = { { name = "Player", value = playerField(), inline = true } },
			})
		end
	end
	task.spawn(function()
		local lastReport = os.clock()
		while alive() do
			task.wait(2.5)
			pcall(function()
				local url = Options.WebhookUrl and Options.WebhookUrl.Value
				local enabled = hookOn() and validWebhook(url)
				local every = (Options.WebhookReport and Options.WebhookReport.Value or 0) * 60
				if enabled and every > 0 and os.clock() - lastReport >= every then
					lastReport = os.clock()
					queueEmbed(reportEmbed("\u{2726}  Farm report"))
				end
				if not enabled then
					table.clear(Hook.queue)
					return
				end
				if N.cardTick then
					N.cardTick()
				end
				local embed = table.remove(Hook.queue, 1)
				if embed then
					embed.author = { name = GameName }
					if postWebhook(url, { username = "Jiro", allowed_mentions = { parse = {} }, embeds = { embed } }) then
						Hook.sent += 1
					end
				end
			end)
		end
	end)
	local function sendFeedback(kind, text, anonymous)
		if FeedbackWebhook == "" then
			notify("Feedback", "Send it on our Discord: " .. Discord, 6)
			return
		end
		if os.clock() - Hook.feedbackAt < 90 then
			notify("Feedback", "Please wait " .. math.ceil(90 - (os.clock() - Hook.feedbackAt)) .. "s before sending again", 4)
			return
		end
		if Hook.feedbackCount >= 6 then
			notify("Feedback", "You sent 6 messages this session, thanks! Use our Discord for more", 5)
			return
		end
		text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if #text < 8 then
			notify("Feedback", "Write at least a few words", 4)
			return
		end
		text = text:sub(1, 1000):gsub("@", "@\u{200B}")
		Hook.feedbackAt = os.clock()
		Hook.feedbackCount += 1
		notify("Feedback", "Sending...", 2)
		task.spawn(function()
			local executor = "Unknown"
			pcall(function()
				executor = table.concat({ identifyexecutor() }, " ")
			end)
			local colors = { Idea = 7995310, Bug = 16739978, Question = 6275327, Other = 14146792 }
			pcall(Library.PostFeedback, kind, text, anonymous, executor)
			local ok = postWebhook(FeedbackWebhook, {
				username = "Jiro Feedback",
				allowed_mentions = { parse = {} },
				embeds = {
					{
						author = { name = GameName, url = GameLink },
						title = "\u{2726}  " .. kind .. "  \u{00B7}  " .. GameName,
						description = text,
						color = colors[kind] or 14146792,
						fields = {
							{
								name = "From",
								value = if anonymous then "Anonymous" else string.format("%s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name),
								inline = true,
							},
							gameField(),
							{ name = "Executor", value = executor, inline = true },
							{ name = "Status", value = tostring(Status):sub(1, 200), inline = false },
						},
						footer = { text = "Jiro feedback  \u{00B7}  " .. GameName },
						timestamp = DateTime.now():ToIsoDate(),
					},
				},
			})
			notify("Feedback", if ok then "Thanks! Jiro got your message." else "Could not send, try again later", 5)
		end)
	end
	pcall(function()
		local holder = Tabs.Misc or Tabs.Main
		local PerfBox = holder:AddLeftGroupbox("Performance", "gauge")
		Labels.Perf = PerfBox:AddLabel({ Text = "Measuring...", DoesWrap = true })
	end)
	local Card = { id = nil, at = -1e9, url = nil }
	function N.cardTick()
		local url = Options.WebhookUrl and Options.WebhookUrl.Value
		if not (hookOn() and on("WebhookCard") and validWebhook(url)) then
			return false
		end
		if os.clock() - Card.at < 120 then
			return false
		end
		Card.at = os.clock()
		if Card.url ~= url then
			Card.url, Card.id = url, nil
		end
		local embed = reportEmbed("\u{2726}  Live stats")
		embed.author = { name = GameName }
		embed.footer = { text = "Jiro  \u{00B7}  " .. GameName .. "  \u{00B7}  updates every 2 min" }
		embed.timestamp = DateTime.now():ToIsoDate()
		local body = HttpService:JSONEncode({ username = "Jiro", allowed_mentions = { parse = {} }, embeds = { embed } })
		if Card.id then
			local response = httpRequest({ Url = url .. "/messages/" .. Card.id, Method = "PATCH", Headers = { ["Content-Type"] = "application/json" }, Body = body })
			local code = response and tonumber(response.StatusCode) or 0
			if code >= 200 and code < 300 then
				return true
			end
			Card.id = nil
		end
		local response = httpRequest({ Url = url .. "?wait=true", Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
		local ok, data = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		if ok and type(data) == "table" and data.id then
			Card.id = tostring(data.id)
			log("WEBHOOK card", Card.id)
		end
		return true
	end
	if Tabs.Webhook then
		pcall(function()
			local HookBox = Tabs.Webhook:AddLeftGroupbox("Discord Webhook", "webhook")
			HookBox:AddToggle("WebhookOn", { Text = "Post to Discord", Default = false, Tooltip = "Posts to your own Discord webhook: the events on the right, a timed report and a live stats card" })
			HookBox:AddInput("WebhookUrl", { Text = "Webhook URL", Placeholder = "https://discord.com/api/webhooks/...", Finished = true, Default = "" })
			HookBox:AddToggle("WebhookCard", { Text = "Live stats card", Default = true, Tooltip = "One message with your coins, income, level and session, edited every 2 minutes instead of new posts" })
			HookBox:AddSlider("WebhookReport", { Text = "Report every", Default = 30, Min = 0, Max = 180, Rounding = 0, Suffix = " min", HideMax = true, Tooltip = "0 turns the timed report off" })
			HookBox:AddToggle("WebhookHideName", { Text = "Hide my username", Default = false })
			HookBox:AddButton({
				Text = "Send test",
				Func = function()
					local url = Options.WebhookUrl and Options.WebhookUrl.Value
					if not validWebhook(url) then
						notify("Webhook", "Paste a Discord webhook URL first", 4)
						return
					end
					task.spawn(function()
						local embed = reportEmbed("\u{2726}  Test from Jiro")
						embed.author = { name = GameName }
						embed.footer = { text = "Jiro  \u{00B7}  " .. GameName }
						local ok, code = postWebhook(url, { username = "Jiro", allowed_mentions = { parse = {} }, embeds = { embed } })
						notify("Webhook", if ok then "Test sent" else "Discord answered " .. tostring(code), 4)
					end)
				end,
			})
			local PostBox = Tabs.Webhook:AddRightGroupbox("Posts", "bell")
			PostBox:AddToggle("WebhookRare", { Text = "Rare catches", Default = true })
			PostBox:AddDropdown("WebhookRarities", { Text = "Rare means", Values = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Exotic" }, Default = { "Mythic", "Secret", "Exotic" }, Multi = true, AllowNull = true })
			PostBox:AddToggle("WebhookSales", { Text = "Sales", Default = false })
			PostBox:AddToggle("WebhookBuys", { Text = "Purchases", Default = true })
			PostBox:AddToggle("WebhookCodes", { Text = "Codes redeemed", Default = true })
			PostBox:AddLabel({ Text = '<font transparency="0.35">Each post goes out once, at most one every 2.5 s. Pick what is worth a ping.</font>', DoesWrap = true })
		end)
	end
	if Tabs.Info then
		pcall(function()
			local StartBox = Tabs.Info:AddLeftGroupbox("Quick Setup", "wand-sparkles")
			StartBox:AddLabel({
				Text = '<font transparency="0.4">Tell Jiro what to do in a few taps. Nothing is picked for you, everything can be changed later.</font>',
				DoesWrap = true,
			})
			StartBox:AddButton({
				Text = "Open quick setup",
				Func = function()
					pcall(N.openWizard)
				end,
			})
			local FeedbackBox = Tabs.FeedbackBox or Tabs.Info:AddLeftGroupbox("Feedback", "message-square")
			FeedbackBox:AddDropdown("FeedbackType", { Text = "Type", Values = { "Idea", "Bug", "Question", "Other" }, Default = "Idea" })
			FeedbackBox:AddInput("FeedbackText", { Text = "Message", Placeholder = "Tell Jiro what to add or fix...", Finished = false, Default = "" })
			FeedbackBox:AddToggle("FeedbackAnon", { Text = "Send anonymously", Default = false })
			FeedbackBox:AddButton({
				Text = "Send feedback",
				Func = function()
					sendFeedback(Options.FeedbackType.Value, Options.FeedbackText.Value, Toggles.FeedbackAnon.Value)
					pcall(Options.FeedbackText.SetValue, Options.FeedbackText, "")
				end,
			})
		end)
	end
end
do
	local function setToggles(names, args)
		local word = args and args[1] and string.lower(tostring(args[1])) or ""
		local first = Toggles[names[1]]
		local state
		if word == "on" or word == "1" or word == "true" then
			state = true
		elseif word == "off" or word == "0" or word == "false" then
			state = false
		else
			state = not (first and first.Value)
		end
		for _, name in ipairs(names) do
			local toggle = Toggles[name]
			if toggle then
				toggle:SetValue(state)
			end
		end
		return state
	end
	N.setToggles = setToggles
	local function toggleCommand(name, aliases, names, text)
		Library:AddCommand({
			Name = name,
			Aliases = aliases,
			Args = "[on/off]",
			Description = "Turns " .. text .. " on or off",
			Source = GameName,
			Callback = function(args)
				return text .. (if setToggles(names, args) then " on" else " off")
			end,
		})
	end
	if Library.AddCommand then
		pcall(function()
			toggleCommand("planner", { "smart" }, { "SmartPlanner" }, "Smart Planner")
			toggleCommand("fish", {}, { "AutoFish" }, "Auto Fish")
			toggleCommand("sell", {}, { "SmartSell" }, "Smart Sell")
			toggleCommand("pond", {}, { "AutoPond" }, "Auto Pond")
			toggleCommand("rewards", { "claim" }, { "AutoRewards" }, "Auto Rewards")
			Library:AddCommand({
				Name = "stop",
				Aliases = { "alloff" },
				Description = "Turns every automation off",
				Source = GameName,
				Callback = function()
					N.stopAll()
					return "Everything off"
				end,
			})
			Library:AddCommand({
				Name = "status",
				Description = "Shows what Jiro is doing",
				Source = GameName,
				Callback = function()
					return string.format("%s  |  coins %s  |  level %d  |  %s  |  %d casts", Status, formatNumber(N.cash()), N.level(), N.worldKey(), Session.casts)
				end,
			})
			Library:AddCommand({
				Name = "perf",
				Aliases = { "fps", "lag" },
				Description = "Shows how smooth the game runs and how much time Jiro takes",
				Source = GameName,
				Callback = Debug.perfText,
			})
		end)
	end
	if Library.OnUnload then
		Library:OnUnload(function()
			pcall(N.fishOff)
			INSTANCE.stop = true
			log("UNLOAD")
			flushLog(true)
		end)
	end
	if Window.AddCommandsTab then
		pcall(function()
			Tabs.Commands = Window:AddCommandsTab()
		end)
	end
	if Library.SetQuickBar then
		pcall(function()
			Library:SetQuickBar({
				{ Toggle = "AutoFish", Icon = "fish", Label = "Fish" },
				{ Toggle = "SmartSell", Icon = "coins", Label = "Sell" },
				{ Toggle = "SmartPlanner", Icon = "brain", Label = "Planner" },
				{ Toggle = "AutoPond", Icon = "droplets", Label = "Pond" },
				{ Toggle = "AutoRewards", Icon = "gift", Label = "Rewards" },
			})
		end)
	end
	local SetupFlag = "Jiro/FISH_setup_done.txt"
	function N.markSetupDone()
		pcall(function()
			if makefolder and isfolder and not isfolder("Jiro") then
				makefolder("Jiro")
			end
			writefile(SetupFlag, "1")
		end)
	end
	function N.setupDone()
		local ok, done = pcall(function()
			return isfile(SetupFlag)
		end)
		return not ok or done == true
	end
	function N.openWizard()
		if not Library.ShowWizard then
			return
		end
		return Library:ShowWizard({
			SkipText = "Skip",
			FinishText = "Start",
			Steps = {
				{
					Id = "tasks",
					Title = "What should Jiro do for you?",
					Description = "Nothing is picked for you: tap what you want running, tap again to unpick.",
					Multi = true,
					Required = false,
					Default = {},
					Choices = {
						{ Id = "fish", Title = "Fish", Description = "Auto Fish on the best fish of every cast", Icon = "fish", Color = "#5fb8ff" },
						{ Id = "sell", Title = "Sell", Description = "Smart Sell when the backpack fills, keeps Secret and Exotic fish", Icon = "coins", Color = "#fab428" },
						{ Id = "planner", Title = "Smart Planner", Description = "Autopilot: fishes, sells, buys by payback, pond, rewards, the whole game", Icon = "brain", Color = "#3ccf91" },
						{ Id = "pond", Title = "Pond", Description = "Unlock, fill, feed and collect the pond", Icon = "droplets", Color = "#4fd1c5" },
						{ Id = "rewards", Title = "Claim rewards", Description = "Daily, playtime, season, achievements, offline and the Big Mouth", Icon = "gift", Color = "#ff5d8f" },
						{ Id = "codes", Title = "Redeem codes", Description = "Every known code and your secret code", Icon = "ticket", Color = "#b18cff" },
						{ Id = "items", Title = "Items", Description = "Open chests, drink potions, use relics, keep a bait active", Icon = "package-open", Color = "#f0b90b" },
					},
				},
			},
			Finish = function(values)
				local chosen = type(values.tasks) == "table" and values.tasks or {}
				local groups = {
					fish = { "AutoFish" },
					sell = { "SmartSell" },
					planner = { "SmartPlanner" },
					pond = { "AutoPond" },
					rewards = { "AutoRewards", "AutoBigMouth" },
					codes = { "AutoCodes" },
					items = { "AutoOpen", "AutoPotions", "AutoRelics", "AutoBait" },
				}
				local want = {}
				for _, id in ipairs(chosen) do
					want[id] = true
				end
				for id, yes in pairs(chosen) do
					if yes == true then
						want[id] = true
					end
				end
				for id, names in pairs(groups) do
					if want[id] then
						setToggles(names, { "on" })
					end
				end
				N.markSetupDone()
				notify("Quick setup done", "Change anything in the tabs any time", 5)
			end,
			Skipped = function()
				N.markSetupDone()
				notify("Quick setup", "Skipped. Open it again from the Info tab.", 4)
			end,
		})
	end
end
if Window.AddSettingsTab then
	local ok, tab = pcall(Window.AddSettingsTab, Window, {
		ThemeManager = ThemeManager,
		SaveManager = SaveManager,
		Folder = "DeepFishing",
		MenuKeybind = "RightControl",
	})
	if ok and tab then
		Tabs.Settings = tab
		pcall(function()
			local ids = {}
			for _, m in ipairs(N.Mirrors or {}) do
				table.insert(ids, m.copy)
			end
			SaveManager:SetIgnoreIndexes(ids)
		end)
	else
		Tabs.Settings = N.addTab("Settings", "settings", "Menu and configs")
	end
else
	Tabs.Settings = Window:AddTab("Settings", "settings")
	pcall(function()
		ThemeManager:SetLibrary(Library)
		SaveManager:SetLibrary(Library)
		SaveManager:IgnoreThemeSettings()
		SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
		ThemeManager:SetFolder("Jiro")
		SaveManager:SetFolder("Jiro/DeepFishing")
		SaveManager:BuildConfigSection(Tabs.Settings)
		ThemeManager:ApplyToTab(Tabs.Settings)
		SaveManager:LoadAutoloadConfig()
	end)
end
if Window.AddInfoTab then
	local DonateMethods = {
		{
			Id = "PayPal",
			Icon = "pay-paypal",
			Symbol = "PP",
			Name = "PayPal",
			Network = "paypal.me",
			Address = "https://paypal.me/KrystianKujawski73",
			Display = "KrystianKujawski73",
			Link = true,
			Color = "#0070e0",
			Note = "Paste the link in your browser and pick any amount",
		},
		{
			Id = "BTC",
			Icon = "pay-btc",
			Symbol = "BTC",
			Name = "Bitcoin",
			Network = "Bitcoin network",
			Address = "bc1q787972ksk3auu2d37gju8m6je0kx9mmskglsvh",
			Color = "#f7931a",
			Note = "Only send BTC on the Bitcoin network",
		},
		{
			Id = "ETH",
			Icon = "pay-eth",
			Symbol = "ETH",
			Name = "Ethereum",
			Network = "ERC20",
			Address = "0xBa0e07FdDB15fe3c9B7CE42F76cef8F09FEdAB64",
			Color = "#627eea",
			Note = "Only send ETH or ERC20 tokens on Ethereum",
		},
		{
			Id = "SOL",
			Icon = "pay-sol",
			Symbol = "SOL",
			Name = "Solana",
			Network = "Solana",
			Address = "4UriDCT4iBsLAuzLdowpSEL4mZq7Ecrxs4pNrV5ztHxW",
			Color = "#9945ff",
			Note = "Only send SOL or Solana tokens",
		},
		{
			Id = "BNB",
			Icon = "pay-bnb",
			Symbol = "BNB",
			Name = "BNB",
			Network = "BNB Smart Chain",
			Address = "0xBa0e07FdDB15fe3c9B7CE42F76cef8F09FEdAB64",
			Color = "#f0b90b",
			Note = "Only send on BNB Smart Chain (BEP20)",
		},
	}
	pcall(function()
		local info = Tabs.Info
		if not info then
			return
		end
		local community = info.Groupboxes and info.Groupboxes.Community
		if community then
			community:AddLabel({
				Text = '<font color="#60d696">All Jiro scripts are keyless and free.</font> <font transparency="0.35">Want your own script for any game? We make custom paid scripts on request, open a ticket on our Discord.</font>',
				DoesWrap = true,
			})
		end
		local right = info:AddRightGroupbox("Support Jiro", "heart", nil, true)
		right:AddDonateBoard({ Methods = DonateMethods })
		right:AddLabel({
			Text = '<font transparency="0.35">Donations are 100% voluntary, nothing is locked behind them. They help keep Jiro updated.</font>',
			DoesWrap = true,
		})
		right.BoxHolder.LayoutOrder = -100
	end)
end
pcall(function()
	Library.RenderOverlayInfo = function()
		return string.format("coins %s  \u{00B7}  level %d", formatNumber(N.cash()), N.level())
	end
end)
Library.OnAutoload = false
Library.OnUserToggle = nil
task.delay(3, function()
	local function show(value)
		if type(value) == "table" then
			local keys = {}
			for k, v in pairs(value) do
				table.insert(keys, tostring(if type(k) == "number" then v else k))
			end
			table.sort(keys)
			return "{" .. table.concat(keys, ",") .. "}"
		end
		return tostring(value)
	end
	local restored = {}
	for name, toggle in pairs(Toggles) do
		if toggle.Value == true and not toggle.Default and string.sub(name, 1, 2) ~= "QS" then
			table.insert(restored, name)
		end
	end
	table.sort(restored)
	log("AUTOLOAD toggles=" .. (if #restored > 0 then table.concat(restored, ",") else "-"))
	pcall(function()
		local opt = Options.MerchantBuy
		local v = opt and opt.Value
		if type(v) == "table" then
			local picked = {}
			for k, yes in pairs(v) do
				if yes then
					table.insert(picked, tostring(k))
				end
			end
			table.sort(picked)
			if table.concat(picked, ",") == "Bait,Eggs,Fish,Potions" then
				local quiet = N.quiet
				N.quiet = true
				opt:SetValue({ Eggs = true, Potions = true, Bait = true, Fish = true, Chests = true, Keys = true, Scrolls = true })
				N.quiet = quiet
				log("CONFIG migrate MerchantBuy", "old default -> every category (each only when worth its price)")
			end
		end
	end)
	local function hook(name, element)
		local run = element.RunChanged
		if type(run) ~= "function" or element.Type == "KeyPicker" or element.Type == "ColorPicker" then
			return
		end
		element.RunChanged = function(self, ...)
			if not N.quiet then
				log("CLICK", name .. "=" .. show(element.Value))
			end
			return run(self, ...)
		end
	end
	for name, toggle in pairs(Toggles) do
		hook(name, toggle)
	end
	for name, option in pairs(Options) do
		hook(name, option)
	end
end)
do
	local ErrorLogAt = {}
	local function reportError(where, err)
		local text = tostring(err)
		local first = string.match(text, "^[^\n]*") or text
		if os.clock() - (ErrorLogAt[first] or -1e9) > 30 then
			ErrorLogAt[first] = os.clock()
			log("ERROR", where, text)
			logProblem(where .. ": " .. first)
		end
		return first
	end
	local function anyAutoOn()
		for _, name in ipairs(N.AllAutoToggles) do
			if on(name) then
				return true
			end
		end
		return false
	end
	N.anyAutoOn = anyAutoOn
	local function loop(name, body)
		task.spawn(function()
			while alive() do
				local ok, err = xpcall(body, debug.traceback)
				if not ok then
					setStatus("Error: " .. reportError(name, err))
					task.wait(1)
				end
				task.wait()
			end
		end)
	end
	local function spending()
		return N.planner() or on("AutoUpgrades") or on("AutoRods") or on("AutoWorlds") or on("AutoPond")
	end
	loop("main loop", function()
		if N.Manual.running then
			task.wait(0.3)
			return
		end
		if not N.ready() then
			setStatus("Waiting for the game data")
			task.wait(1)
			return
		end
		Session.cashStart = Session.cashStart or N.cash()
		Session.levelStart = Session.levelStart or N.level()
		if not N.alive() then
			setStatus("Waiting for the character")
			task.wait(0.5)
			return
		end
		if N.sellStep() then
			return
		end
		if N.probeStep() then
			return
		end
		if spending() and N.due("spend", 4) and N.spendStep() then
			return
		end
		if N.worldStep() then
			return
		end
		if N.pondStep() then
			return
		end
		if N.bigMouthStep() or N.enchantStep() or N.mutationStep() then
			return
		end
		if N.itemChores() then
			return
		end
		if N.eggStep() or N.petStep() or N.skinStep() or N.cargoStep() or N.merchantStep() or N.pondPetStep(false) or N.hallProbeStep() then
			return
		end
		N.baitStep()
		if N.wants("AutoFish") then
			N.resumeFishing()
			N.fishStep()
			return
		end
		if not anyAutoOn() then
			setStatus("Idle")
		else
			setStatus("Waiting (Auto Fish is off: turn it or the Smart Planner on to fish)")
		end
		task.wait(0.5)
	end)
	loop("chores", function()
		if N.ready() then
			if N.due("learnHook", 30) then
				N.learnHook()
			end
			N.rewardStep()
			N.codeStep()
			if N.due("econ", 15) then
				N.econTick()
			end
			if N.due("vaultProbe", 120) then
				N.vaultProbe()
			end
		end
		task.wait(1)
	end)
	N.InfoText = {}
	function N.upNext()
		local out = {}
		local who = if N.planner() then "Smart Planner: " else ""
		if N.planner() then
			table.insert(out, if N.Plan.say ~= "" then "Smart Planner: " .. N.Plan.say else "Smart Planner: fishing, the first purchases come after about a minute of income data")
		end
		if N.wants("AutoFish") and not N.planner() then
			table.insert(out, N.modeText() .. string.format(", %d%% Perfect", math.floor(optionNumber("PerfectRate", 60))))
		end
		if N.wants("SmartSell") then
			table.insert(out, who .. string.format("selling at %d%% backpack, before a cast that would not fit%s", math.floor(optionNumber("SellAt", 80)), if N.planner() then " and to fund the next buy" else ""))
		end
		if N.wants("AutoPond") then
			local pondText
			if not N.unlocked("Pond") then
				pondText = "pond unlock at level 5 when it pays back"
			elseif N.planner() then
				pondText = "pond trip for a capacity upgrade, coins that complete the next buy, food under half, the 8 h cap or every 3 h (" .. formatNumber(tonumber(N.Pond.hourly) or 0) .. "/h" .. (if (N.Pond.stockMax or 0) > 0 then string.format(", food %d/%d", math.floor(N.Pond.stock or 0), math.floor(N.Pond.stockMax)) else "") .. ")"
			else
				pondText = "pond trip every " .. math.floor(optionNumber("PondEvery", 60)) .. " min"
			end
			table.insert(out, who .. pondText)
		end
		if N.wants("AutoRewards") then
			table.insert(out, who .. "claiming rewards" .. (if N.wants("AutoCodes") then " and codes" else "") .. " when ready")
		end
		if N.tutorialHold() then
			table.insert(out, "Tutorial held at step 6: x2 luck on every cast (no playtime gifts or quests meanwhile)")
		end
		if N.wants("AutoCargo") then
			table.insert(out, who .. "cargo order: keeping the fish it needs, giving them, sending the ship and claiming it")
		end
		if N.wants("AutoMerchant") then
			table.insert(out, who .. "traveling merchant: " .. N.Merchant.last)
		end
		if on("AutoEggs") then
			table.insert(out, "Eggs: hatchery trip when an egg waits or a grown one can hatch")
		end
		if on("AutoEquipPet") then
			table.insert(out, "Pets: " .. N.Pets.last)
		end
		if on("AutoPondPets") then
			table.insert(out, "Pond pets: " .. N.PondPets.last)
		end
		if on("UseCharges") then
			table.insert(out, "Throw charges: on the next school worth it")
		end
		if on("UseSummons") then
			table.insert(out, "Sunken Crowns: one at a time, when no boss runs (" .. #N.itemsOf("Summon") .. " stacks owned)")
		end
		if on("WearBestSkin") then
			table.insert(out, "Rod skin: " .. N.Skin.last)
		end
		if N.whaleWindow() then
			table.insert(out, "Whale eggs open: casting only, trips wait")
		elseif N.whaleIn() <= 120 then
			table.insert(out, "Whale eggs open in " .. N.longTime(N.whaleIn()))
		end
		return out
	end
	task.spawn(function()
		while alive() do
			local started = os.clock()
			local ok, err = pcall(function()
				local I = N.InfoText
				local d = N.data()
				local count, max = N.backpack()
				I.info = string.format(
					"Coins <b>%s</b>  \u{00B7}  level <b>%d</b>  \u{00B7}  %s\nIncome <b>%s</b>/h  \u{00B7}  backpack %d/%d  \u{00B7}  hooks %d\nCasts <b>%d</b>  \u{00B7}  sold %s  \u{00B7}  Smart Planner %s",
					formatNumber(N.cash()),
					N.level(),
					N.worldKey(),
					formatNumber(N.Econ.rate * 3600),
					count,
					max,
					N.hookCap(),
					Session.casts,
					formatNumber(Session.soldValue),
					if N.planner() then "on" else "off"
				)
				local upNext = N.upNext()
				I.plan = if #upNext > 0 then "<b>Up next</b>\n" .. '<font transparency="0.2">\u{2022} ' .. table.concat(upNext, "\n\u{2022} ") .. "</font>" else "Up next: nothing running"
				local F = N.Fish
				local engineText = ({ ["remote-blatant"] = "Fast", ["remote-legit"] = "Legit pace", game = "the game's auto fishing" })[tostring(F.engine)] or "starting"
				I.fish = string.format(
					"<b>%s</b> (%s)%s\nLast cast: %s\nCasts %d, Perfect %d, caught %d, finds %d, fights %d\nCast %.1f s, %s coins per cast",
					N.modeText(),
					engineText,
					if os.clock() < F.fallbackUntil then "\nFast paused " .. N.longTime(F.fallbackUntil - os.clock()) .. ": " .. F.fallbackReason else "",
					if F.last ~= "" then F.last else "-",
					Session.casts,
					Session.perfect,
					Session.caught,
					Session.specials,
					Session.fights,
					F.cycle,
					formatNumber(F.evCast)
				)
				local _, sellable, value = N.fishStats()
				I.sell = string.format("Backpack <b>%d/%d</b>, %d sellable worth %s\nLast: %s\nSold %s fish for %s\n%s", count, max, sellable, formatNumber(value), N.Sell.last, formatNumber(Session.sold), formatNumber(Session.soldValue), N.socialText())
				local active = 0
				for name, n in pairs(N.tab("ActiveBaits")) do
					active += tonumber(n) or 0
				end
				I.bait = string.format("Active bait casts <b>%d</b>  \u{00B7}  %d baits in the backpack\nUsed %d this session", active, #N.itemsOf("Bait"), Session.baits)
				local pond = N.tab("Pond")
				local pondCfg = N.worldCfg("Pond") or {}
				I.pond = if not N.unlocked("Pond")
					then string.format("Pond locked (level %s, %s). Auto Pond unlocks it", tostring(pondCfg.RequiredLevel or 5), formatNumber(pondCfg.UnlockPrice or 0))
					else string.format("Level %s, waiting %s%s\n%s\nTrips %d", tostring(pond.Level or 1), formatNumber(if N.pondPending then N.pondPending(pond) else (pond.PendingIncome or 0)), if (N.Pond.stockMax or 0) > 0 then string.format("  \u{00B7}  food %d/%d", math.floor(N.Pond.stock or 0), math.floor(N.Pond.stockMax)) else "", N.Pond.last, Session.pondTrips)
				I.probes = if N.Probe.last ~= "-" then "Last probe: " .. N.Probe.last else "Off. Each probe runs once per game version and logs PROBE &lt;name&gt; result="
				I.planner = if N.planner()
					then string.format("<b>On</b>  \u{00B7}  income %s/h\n%s\nLast buy: %s", formatNumber(N.Econ.rate * 3600), if N.Plan.say ~= "" then N.Plan.say else "Fishing; the first purchases come after about a minute of income data", N.Shop.last)
					else "Off. Turn it on and Jiro plays the whole game: fishing, selling, buying by payback, pond, rewards. Your other toggles stay as they are"
				local up = N.tab("Upgrades")
				I.upgrades = string.format("Capacity %s  \u{00B7}  Strength %s  \u{00B7}  Weight %s  \u{00B7}  Bounce %s\nHooks per cast %d\nBought %d this session", tostring(up.Capacity or 0), tostring(up.Strength or 0), tostring(up.Weight or 0), tostring(up.Bounce or 0), N.hookCap(), Session.upgrades)
				local luck, strength = N.rodPower(d.RodEquipped or "Wooden Rod")
				local halls = {}
				for _, hall in ipairs({ "Cave", "Maze" }) do
					local st = N.tab(hall)
					local HC = N.sh("Config." .. hall .. "Config")
					if type(HC) == "table" and HC.Rod then
						local state = if N.tab("Rods")[HC.Rod] ~= nil then "owned" elseif N.hallReady(hall) then "ready to buy" elseif st.KeyInserted then "key in, relic fish missing" else "locked"
						table.insert(halls, string.format("%s: %s", tostring(HC.Rod), state))
					end
				end
				I.rods = string.format("Equipped <b>%s</b> (luck %s, strength %s)\nHall rods: %s\nBought %d this session%s", tostring(d.RodEquipped or "-"), formatNumber(luck), formatNumber(strength), table.concat(halls, ", "), Session.rods, if N.Hall.last ~= "-" then "\nLast hall visit: " .. N.Hall.last else "")
				I.world = string.format("In <b>%s</b>, best unlocked %s\n%s", N.worldKey(), (N.bestFishingWorld()), N.World.last)
				I.rewards = string.format("Claimed <b>%d</b> this session%s", Session.claims, if #N.Reward.log > 0 then "\n" .. table.concat(N.Reward.log, "\n") else "")
				local redeemed, tried = N.codeCounts()
				I.codes = string.format("Redeemed <b>%d</b>, tried %d\nLast: %s", redeemed, tried, N.Codes.last)
				local bm = N.tab("BigMouth")
				local wait = (tonumber(bm.ReadyAt) or 0) - N.serverTime()
				local goal = tonumber(bm.Goal) or 0
				I.bigMouth = string.format("Luck +%d%%  \u{00B7}  feeds %s%s\n%s", math.floor((tonumber(bm.Luck) or 0) * 100 + 0.5), tostring(bm.Feeds or 0), if wait <= 0 and goal > 0 then "  \u{00B7}  goal " .. formatNumber(tonumber(bm.Progress) or 0) .. "/" .. formatNumber(goal) .. " kg" else "", if wait > 0 then "Hungry again in " .. N.longTime(wait) else "Hungry now")
				I.open = string.format("Opened %d  \u{00B7}  potions %d  \u{00B7}  relics %d\nLast: %s", Session.opened, Session.potions, Session.relics, N.Items.last)
				local s1, s2 = N.enchantNames()
				local stones, ultraStones, scrolls, ultraScrolls = 0, 0, 0, 0
				for _, e in ipairs(N.itemsOf("Scroll")) do
					local n = tostring(e.item.Name)
					local amount = tonumber(type(e.item.Data) == "table" and e.item.Data.Amount) or 1
					if n == "Enchant Stone" then
						stones += amount
					elseif n == "Ultra Enchant Stone" then
						ultraStones += amount
					elseif n == "Mutation Scroll" then
						scrolls += amount
					elseif n == "Ultra Mutation Scroll" then
						ultraScrolls += amount
					end
				end
				I.enchant = string.format("Rod enchants: %s / %s\nStones %d, Ultra %d  \u{00B7}  rolls %d this session", tostring(s1 or "-"), tostring(s2 or "-"), stones, ultraStones, Session.enchants)
				I.items = string.format("Mutation Scrolls %d, Ultra %d\nSpins %d this session", scrolls, ultraScrolls, Session.mutations)
				local owned, running = {}, {}
				for _, e in ipairs(N.itemsOf("Potion")) do
					local key = N.potionKey(tostring(e.item.Name))
					owned[key] = (owned[key] or 0) + (tonumber(type(e.item.Data) == "table" and e.item.Data.Amount) or 1)
				end
				for _, key in ipairs({ "Luck", "Coins", "XP", "Mutation", "Capacity" }) do
					local left = N.potionLeft and N.potionLeft(key .. " Potion") or 0
					if left > 0 then
						table.insert(running, key .. " " .. N.longTime(left))
					end
				end
				local ownedText = {}
				for key, n in pairs(owned) do
					table.insert(ownedText, key .. " " .. n)
				end
				table.sort(ownedText)
				I.potions = string.format("Running: %s\nOwned: %s", if #running > 0 then table.concat(running, ", ") else "none", if #ownedText > 0 then table.concat(ownedText, ", ") else "none")
				I.cargo = N.cargoText()
				I.pets = N.eggPlanText() .. "\n" .. N.Eggs.last .. "\n" .. N.Pets.last .. "\nPond pets: " .. N.PondPets.last .. "\nRod skin: " .. N.Skin.last
				I.merchant = N.Merchant.last
				local tc = N.tab("ThrowCharges")
				I.charges = string.format("Owned: Collect All %d, More Fish %d, Mutation Luck %d\nUsed %d this session. Last: %s", tonumber(tc["Collect All"]) or 0, tonumber(tc["More Fish"]) or 0, tonumber(tc["Mutation Luck"]) or 0, N.Charges.used, N.Charges.last)
				I.lines = string.format("Rewards %d  \u{00B7}  codes %d  \u{00B7}  pond trips %d\nLast reward: %s", Session.claims, redeemed, Session.pondTrips, if N.Reward.last ~= "" then N.Reward.last else "-")
			end)
			if not ok then
				reportError("info", err)
			end
			pcall(N.rateTick)
			Perf.work.info = (Perf.work.info or 0) + (os.clock() - started)
			task.wait(1)
		end
	end)
	local function shown(tab)
		if tab == nil or Library.Toggled == false then
			return false
		end
		return Library.ActiveTab == nil or Library.ActiveTab == tab
	end
	local UiLater, uiMoved = {}, false
	pcall(function()
		Library:GiveSignal(RunService.Heartbeat:Connect(function()
			if #UiLater == 0 then
				return
			end
			local queue = UiLater
			UiLater = {}
			for _, fn in ipairs(queue) do
				if N.fixIdentity then
					N.fixIdentity()
				end
				pcall(fn)
			end
		end))
	end)
	task.spawn(function()
		local uiErrorAt = -1e9
		local function group(fn)
			N.fixIdentity()
			local ok, err = xpcall(fn, debug.traceback)
			if ok then
				return
			end
			if string.find(tostring(err), "lacking capability", 1, true) then
				if #UiLater < 20 then
					table.insert(UiLater, fn)
				end
				if not uiMoved then
					uiMoved = true
					log("UI thread lost its rights, UI updates now run on the frame thread")
				end
				return
			end
			if os.clock() - uiErrorAt > 30 then
				uiErrorAt = os.clock()
				log("ERROR", "ui", string.sub(tostring(err), 1, 300))
			end
		end
		local frame = 0
		while alive() do
			frame += 1
			local started = os.clock()
			group(UIQueue.flush)
			if frame % 3 == 0 then
				local I = N.InfoText
				if shown(Tabs.Main) then
					group(function()
						Labels.Status:SetText(Status)
						Labels.Info:SetText(I.info or "-")
						Labels.Lines:SetText(I.lines or "-")
						Labels.Plan:SetText(I.plan or "-")
					end)
				end
				if shown(Tabs.Fishing) then
					group(function()
						Labels.Fish:SetText(I.fish or "-")
						Labels.Charges:SetText(I.charges or "-")
						Labels.Sell:SetText(I.sell or "-")
						Labels.Bait:SetText(I.bait or "-")
						Labels.Pond:SetText(I.pond or "-")
						Labels.Planner:SetText(I.planner or "-")
						Labels.Probes:SetText(I.probes or "-")
					end)
				end
				if frame % 6 == 0 and N.syncMirrors then
					group(N.syncMirrors)
				end
				if shown(Tabs.Upgrades) then
					group(function()
						Labels.Upgrades:SetText(I.upgrades or "-")
						Labels.Rods:SetText(I.rods or "-")
						Labels.World:SetText(I.world or "-")
						Labels.Merchant:SetText(I.merchant or "-")
					end)
				end
				if shown(Tabs.Rewards) then
					group(function()
						Labels.Rewards:SetText(I.rewards or "-")
						Labels.Codes:SetText(I.codes or "-")
						Labels.BigMouth:SetText(I.bigMouth or "-")
						Labels.Cargo:SetText(I.cargo or "-")
					end)
				end
				if shown(Tabs.Items) then
					group(function()
						Labels.Open:SetText(I.open or "-")
						Labels.Items:SetText(I.items or "-")
						if Labels.Enchant then
							Labels.Enchant:SetText(I.enchant or "-")
						end
						if Labels.Potions then
							Labels.Potions:SetText(I.potions or "-")
						end
						Labels.Pets:SetText(I.pets or "-")
					end)
				end
				if shown(Tabs.Stats) or frame % 30 == 0 then
					group(N.drawStats)
				end
				if Labels.Perf and shown(Tabs.Misc) then
					group(function()
						Labels.Perf:SetText(Debug.perfText())
					end)
				end
			end
			Perf.work.ui = (Perf.work.ui or 0) + (os.clock() - started)
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		local windowStart = os.clock()
		while alive() do
			task.wait(5)
			pcall(function()
				if os.clock() - windowStart >= 30 then
					local span = os.clock() - windowStart
					windowStart = os.clock()
					local hub, parts = 0, {}
					for key, seconds in pairs(Perf.work) do
						hub += seconds
						table.insert(parts, key .. " " .. math.floor(seconds * 1000) .. "ms")
					end
					table.sort(parts)
					local ping, memory = "?", "?"
					pcall(function()
						ping = tostring(math.floor(LocalPlayer:GetNetworkPing() * 1000))
					end)
					pcall(function()
						memory = tostring(math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb()))
					end)
					Perf.last = { fps = if Perf.time > 0 then Perf.frames / Perf.time else 0, worst = Perf.worst, hitches = Perf.hitches, freezes = Perf.freezes, hub = hub, span = span, ping = ping, memory = memory }
					log("PERF", Debug.perfText(), "|", table.concat(parts, ", "))
					Perf.frames, Perf.time, Perf.worst, Perf.hitches, Perf.freezes = 0, 0, 0, 0, 0
					table.clear(Perf.work)
					flushLog(false)
				end
				if Log.statusAt and os.clock() - Log.statusAt > 600 and Log.stuckAt ~= Log.statusAt and anyAutoOn() and not string.find(Status, "Fishing", 1, true) and string.sub(Status, 1, 7) ~= "Waiting" then
					Log.stuckAt = Log.statusAt
					logProblem("Stuck for 10 minutes on: " .. tostring(Status))
					if N.planner() then
						N.rejoin("stuck 10 minutes on: " .. tostring(Status))
					end
				end
			end)
		end
	end)
	pcall(function()
		Tabs.Main:Show()
	end)
	do
		local key = "RightControl"
		pcall(function()
			if Options.MenuKeybind and Options.MenuKeybind.Value then
				key = tostring(Options.MenuKeybind.Value)
			end
		end)
		notify("Jiro", if Library.IsMobile then "Loaded and ready. The flower button opens and closes the hub." else "Loaded. Press " .. key .. " to hide or show the menu.", 5)
	end
end
end, debug.traceback)
Boot.JiroBooting = nil
if not BootOk then
	local report = "[Jiro] Deep Fishing failed to start:\n" .. tostring(BootError)
	warn(report)
	Boot.JiroLastError = report
	local copied = pcall(setclipboard, report)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Jiro error",
			Text = if copied
				then "Hub failed to start. The error is copied to your clipboard."
				else "Hub failed to start. Press F9 and send the red [Jiro] line.",
			Duration = 20,
		})
	end)
end

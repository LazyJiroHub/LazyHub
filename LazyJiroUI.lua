local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
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

local Lib = { Theme = Theme, Version = 4 }

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
    local row = Row(self, 32)
    addEl(self, o.Name, row)
    RowLabel(row, o.Name)
    local sw = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
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
                LayoutOrder = -1, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = o.Description,
                Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, Parent = cont,
            })
        end
    end

    local head = New("TextButton", {
        LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Element,
        AutoButtonColor = false, Text = "", Parent = cont,
    })
    Corner(head, 10); Stroke(head, Theme.Stroke, 1)
    if not stacked then New("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.4, -12, 1, 0), BackgroundTransparency = 1, Text = o.Name,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
    }) end
    local val = New("TextLabel", {
        Position = stacked and UDim2.new(0, 12, 0, 0) or UDim2.new(0.4, 0, 0, 0),
        Size = stacked and UDim2.new(1, -34, 1, 0) or UDim2.new(0.6, -30, 1, 0), BackgroundTransparency = 1, Text = "",
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = stacked and Theme.Text or Theme.Accent,
        TextXAlignment = stacked and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
    })
    local arrow = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 14, 1, 0),
        BackgroundTransparency = 1, Text = "v", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.SubText, Parent = head,
    })
    -- Option list scrolls once it gets taller than MAX_LIST so long lists don't stretch the card
    local list = New("ScrollingFrame", {
        LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = cont,
    })
    New("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    -- bottom inset so the open list never clips the card boundary below it
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
            -- accepts a list { "A", "B" } or a set { A = true }
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
        -- defer so AutomaticCanvasSize settles before Balance re-measures columns
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
        local sbox = New("TextBox", {
            LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Element, Text = o.Default or "",
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
    local l = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, TextWrapped = true,
        Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(self), Parent = self.Frame,
    })
    addEl(self, text, l)
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
        Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 1, -204), BackgroundTransparency = 1,
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
    local linkBtn = iconBtn(1, "link")
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
    linkBtn.MouseButton1Click:Connect(function()
        local ok = pcall(function() setclipboard(cfg.Link or "https://github.com") end)
        Window:Notify({ Title = ok and "Link copied" or "Link", Content = cfg.Link or "https://github.com", Duration = 3 })
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
            -- UIPadding is not applied to scale sizes inside a ScrollingFrame, which made the
            -- columns overflow on the right. Inset the row with explicit offsets instead.
            local colRow = New("Frame", {
                Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = tab.Frame,
            })
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
                -- ensure both columns always start at the same top edge
                New("UIPadding", { PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0), Parent = c })
                return c
            end
            tab.Cols = { Left = col(1), Right = col(2) }

            tab.Balance = function()
                if tab._balancing then return end
                tab._balancing = true
                task.delay(0.1, function()
                    tab._balancing = false
                    for _, c in ipairs(tab.Cards) do c.Limit.MinSize = Vector2.new(0, 0) end
                    task.wait()
                    task.wait()
                    if not tab.Frame.Parent then return end
                    local sc = math.max(scale.Scale, 0.05)
                    local info = {}
                    for _, column in pairs(tab.Cols) do
                        local last
                        for _, c in ipairs(tab.Cards) do
                            if c.Frame.Parent == column and c.Frame.Visible then last = c end
                        end
                        table.insert(info, { h = column.AbsoluteSize.Y / sc, last = last })
                    end
                    local target = 0
                    for _, i in ipairs(info) do target = math.max(target, i.h) end
                    for _, i in ipairs(info) do
                        if i.last and i.h < target and (target - i.h) <= 60 then
                            i.last.Limit.MinSize = Vector2.new(0, i.last.Frame.AbsoluteSize.Y / sc + (target - i.h))
                        end
                    end
                end)
            end

            function tab:AddCard(title, side, tag)
                -- guard: unknown side strings fall back to alternating Left/Right
                local colKey = (side == "Left" or side == "Right") and side
                    or (#tab.Cards % 2 == 0 and "Left" or "Right")
                local card = setmetatable({ Els = {}, _n = 0, Window = Window, Tab = tab }, { __index = Elements })
                card.Frame = New("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(1, 1, 1),
                    BackgroundTransparency = 0.04, Parent = tab.Cols[colKey],
                })
                Corner(card.Frame, 14); Stroke(card.Frame, Theme.Stroke, 1)
                Grad(card.Frame, Color3.fromRGB(33, 26, 38), Theme.Card, 90)
                card.Limit = New("UISizeConstraint", { MinSize = Vector2.new(0, 0), Parent = card.Frame })
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

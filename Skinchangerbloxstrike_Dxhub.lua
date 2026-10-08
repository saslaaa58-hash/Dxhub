-- =========================================================================
-- [ DXHUB v3 — BloxStrike Edition ]
-- [ GUI: DX Hub (матовое стекло) • Функции и настройки — без изменений ]
-- =========================================================================

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- =========================================================================
-- [ HELPERS ]
-- =========================================================================

local function get_player_team(p)
    if not p then return nil end
    if p.Team then return p.Team.Name end
    return nil
end

local function hasVestDetails(char)
    if not char then return false end
    local a = char:FindFirstChild("CharacterArmor")
    return a ~= nil and a:FindFirstChild("VestDetails") ~= nil
end

local function isAlly(char)
    if not char then return false end
    local my = LP.Character
    if not my then return false end
    return hasVestDetails(my) == hasVestDetails(char)
end

local function SafeRequire(m)
    if not m then return nil end
    local s, r = pcall(function() return require(m) end)
    if s and r and type(r) == "table" then return r end
    return nil
end

local function GetMoveDirection()
    local d = Vector3.zero
    local look  = Camera.CFrame.LookVector
    local right = Camera.CFrame.RightVector
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then d += look end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then d -= look end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then d -= right end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then d += right end
    return Vector3.new(d.X, 0, d.Z).Unit
end

-- =========================================================================
-- [ DX HUB GUI ]
-- Библиотека интерфейса с тем же API, что был у Obsidian:
-- CreateWindow / AddTab / AddLeftGroupbox / AddRightGroupbox /
-- AddToggle / AddSlider / AddDropdown / AddLabel(:AddColorPicker, :AddKeyPicker) / AddButton / AddDivider
-- Благодаря этому весь код ниже (вкладки, настройки, функции) остался как был.
-- =========================================================================

local Library = { Options = {}, Toggles = {}, Unloaded = false, _conns = {}, _unload = {}, _open = false }
local Options = Library.Options
local Toggles = Library.Toggles

local THEME = {
    Accent = Color3.fromRGB(240, 240, 240), Accent2 = Color3.fromRGB(120, 120, 120),
    Glass  = Color3.fromRGB(10, 10, 10),    Text = Color3.fromRGB(245, 245, 245),
    Sub    = Color3.fromRGB(150, 150, 150),
}
local WHITE = Color3.new(1, 1, 1)
local DARK  = Color3.fromRGB(22, 22, 22)
local SEL   = Color3.fromRGB(12, 12, 12)
local ACCENT_SEQ = ColorSequence.new({
    ColorSequenceKeypoint.new(0, THEME.Accent),
    ColorSequenceKeypoint.new(0.5, THEME.Accent2),
    ColorSequenceKeypoint.new(1, THEME.Accent),
})
local LIGHT_SEQ = ColorSequence.new(WHITE, Color3.fromRGB(205, 205, 205))
local ICONS = { crosshair = "target", eye = "eye", ["person-standing"] = "user", palette = "palette", settings = "gear" }

local function new(class, props, children)
    local inst = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else inst[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    if parent then inst.Parent = parent end
    return inst
end

local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function corner(inst, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 10), Parent = inst }) end

local function stroke(inst, transparency, thickness, color)
    return new("UIStroke", {
        Color = color or WHITE, Transparency = transparency or 0.9, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst,
    })
end

local function gradient(inst, seq, rot) return new("UIGradient", { Color = seq, Rotation = rot or 0, Parent = inst }) end

local orderCounter = setmetatable({}, { __mode = "k" })
local function place(parent, inst)
    orderCounter[parent] = (orderCounter[parent] or 0) + 1
    inst.LayoutOrder = orderCounter[parent]
end

local function connect(sig, fn)
    local c = sig:Connect(fn)
    Library._conns[#Library._conns + 1] = c
    return c
end

-- Нарисованные иконки (без внешних картинок)
local function drawIcon(parent, kind, s, color, pos)
    local ic = new("Frame", {
        Size = UDim2.fromOffset(s, s), Position = pos or UDim2.new(), BackgroundTransparency = 1,
        ClipsDescendants = (kind == "user"), Parent = parent,
    })
    local parts, holes = {}, {}
    local function box(cx, cy, w, h, rot, round, hole)
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromScale(w, h),
            Rotation = rot or 0, BackgroundColor3 = hole and DARK or color, BorderSizePixel = 0, Parent = ic,
        })
        if round then corner(f, 1000) end
        if hole then holes[#holes + 1] = f else parts[#parts + 1] = { f, "BackgroundColor3" } end
        return f
    end
    local th = math.max(2, s * 0.09)
    if kind == "user" then
        box(0.5, 0.3, 0.38, 0.38, 0, true)
        box(0.5, 1.0, 0.78, 0.78, 0, true)
    elseif kind == "eye" then
        local e = box(0.5, 0.5, 0.96, 0.56, 0, true)
        e.BackgroundTransparency = 1
        parts[#parts + 1] = { stroke(e, 0, th, color), "Color" }
        box(0.5, 0.5, 0.3, 0.3, 0, true)
        box(0.5, 0.5, 0.12, 0.12, 0, true, true)
    elseif kind == "gear" then
        for _, r in ipairs({ 0, 45, 90, 135 }) do box(0.5, 0.5, 0.15, 0.98, r) end
        box(0.5, 0.5, 0.64, 0.64, 0, true)
        box(0.5, 0.5, 0.28, 0.28, 0, true, true)
    elseif kind == "palette" then
        box(0.5, 0.5, 0.94, 0.94, 0, true)
        box(0.32, 0.4, 0.16, 0.16, 0, true, true)
        box(0.58, 0.28, 0.16, 0.16, 0, true, true)
        box(0.74, 0.52, 0.16, 0.16, 0, true, true)
        box(0.42, 0.74, 0.2, 0.2, 0, true, true)
    elseif kind == "target" then
        local r = box(0.5, 0.5, 0.86, 0.86, 0, true)
        r.BackgroundTransparency = 1
        parts[#parts + 1] = { stroke(r, 0, th, color), "Color" }
        box(0.5, 0.5, 0.1, 1)
        box(0.5, 0.5, 1, 0.1)
        box(0.5, 0.5, 0.44, 0.44, 0, true, true)
        box(0.5, 0.5, 0.18, 0.18, 0, true)
    elseif kind == "logo" then
        local o = box(0.5, 0.5, 0.62, 0.62, 45)
        o.BackgroundTransparency = 1
        parts[#parts + 1] = { stroke(o, 0, th, color), "Color" }
        box(0.5, 0.5, 0.26, 0.26, 45)
    else -- home
        box(0.5, 0.38, 0.5, 0.5, 45)
        box(0.5, 0.7, 0.58, 0.34)
        box(0.5, 0.79, 0.15, 0.2, 0, false, true)
    end
    local function tint(c, holeColor, animated)
        for _, p in ipairs(parts) do
            if animated then tween(p[1], 0.25, { [p[2]] = c }) else p[1][p[2]] = c end
        end
        for _, h in ipairs(holes) do
            if animated then tween(h, 0.25, { BackgroundColor3 = holeColor }) else h.BackgroundColor3 = holeColor end
        end
    end
    return ic, tint
end

-- Перетаскивание ползунков (на телефоне отключаем прокрутку списка, пока тянешь)
local function bindDrag(hit, track, onFrac)
    local dragging, scroller = false, nil
    local function upd(x) onFrac(math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)) end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            scroller = hit:FindFirstAncestorWhichIsA("ScrollingFrame")
            if scroller then scroller.ScrollingEnabled = false end
            upd(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            upd(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if scroller then scroller.ScrollingEnabled = true end
        end
    end)
end

local function makeDraggable(handle, target, getScale)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            local s = getScale and getScale() or 1
            tween(target, 0.08, { Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / s,
                startPos.Y.Scale, startPos.Y.Offset + d.Y / s) }, Enum.EasingStyle.Sine)
        end
    end)
end

local function hoverFx(btn, target, base, over)
    btn.MouseEnter:Connect(function() tween(target, 0.15, { BackgroundTransparency = over }) end)
    btn.MouseLeave:Connect(function() tween(target, 0.15, { BackgroundTransparency = base }) end)
end

-- Уведомления (внизу справа)
local toastHolder
function Library:Notify(text, time)
    if not toastHolder then return end
    local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = toastHolder })
    place(toastHolder, holder)
    local toast = new("CanvasGroup", {
        Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(260, 0), BackgroundColor3 = THEME.Glass,
        BackgroundTransparency = 0.15, GroupTransparency = 1, Parent = holder,
    })
    corner(toast, 10)
    stroke(toast, 0.8, 1)
    new("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Text = text,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Parent = toast,
    })
    tween(toast, 0.4, { Position = UDim2.new(), GroupTransparency = 0 }, Enum.EasingStyle.Back)
    task.delay(time or 2.5, function()
        tween(toast, 0.3, { Position = UDim2.fromOffset(260, 0), GroupTransparency = 1 }).Completed:Wait()
        holder:Destroy()
    end)
end

function Library:OnUnload(fn) self._unload[#self._unload + 1] = fn end

function Library:Unload()
    if self.Unloaded then return end
    self.Unloaded = true
    for _, f in ipairs(self._unload) do pcall(f) end
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    if self.Gui then pcall(function() self.Gui:Destroy() end) end
    if self._blur then pcall(function() self._blur:Destroy() end) end
end

-- ------------------------------ Groupbox: элементы управления ------------------------------
-- Общие методы элементов: OnChanged (подписка на изменение) и GetState (состояние)
local function addMethods(obj, info)
    obj.OnChanged = function(self, fn)
        local prev = info.Callback
        info.Callback = function(...)
            if prev then prev(...) end
            fn(...)
        end
    end
    obj.GetState = function(self)
        if self.State ~= nil then return self.State and true or false end
        return self.Value and true or false
    end
end

local function makeGroupbox(column, title)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.93, BorderSizePixel = 0, Parent = column,
    })
    place(column, frame)
    corner(frame, 12)
    stroke(frame, 0.88, 1)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10), Parent = frame,
    })
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
    local head = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = string.upper(title), Font = Enum.Font.GothamBold,
        TextSize = 12, TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
    })
    place(frame, head)

    local Box = {}
    local function mk(h, clip)
        local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, ClipsDescendants = clip or false, Parent = frame })
        place(frame, f)
        return f
    end
    local function callback(info, ...)
        if info and info.Callback then
            local ok, err = pcall(info.Callback, ...)
            if not ok then warn("[DxHub] callback: " .. tostring(err)) end
        end
    end

    -- Toggle
    function Box:AddToggle(idx, info)
        info = info or {}
        local obj = { Type = "Toggle", Value = info.Default and true or false }
        Toggles[idx] = obj
        addMethods(obj, info)
        obj.AddColorPicker = function(self, idx2, info2)
            info2 = info2 or {}
            Box:AddLabel(info2.Title or idx2):AddColorPicker(idx2, info2)
            return self
        end
        obj.AddKeyPicker = function(self, idx2, info2)
            info2 = info2 or {}
            Box:AddLabel(info2.Text or idx2):AddKeyPicker(idx2, info2)
            return self
        end
        local f = mk(30)
        local disabled = info.Disabled == true
        new("TextLabel", {
            Size = UDim2.new(1, -52, 1, 0), BackgroundTransparency = 1, Text = info.Text or idx, Font = Enum.Font.GothamMedium,
            TextSize = 13, TextColor3 = disabled and THEME.Sub or THEME.Text, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = f,
        })
        local OFF, ON = Color3.fromRGB(62, 62, 62), Color3.fromRGB(240, 240, 240)
        local sw = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(40, 22),
            BackgroundColor3 = OFF, BorderSizePixel = 0, Parent = f,
        })
        corner(sw, 11)
        local knob = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = Color3.fromRGB(200, 200, 200), BorderSizePixel = 0, Parent = sw,
        })
        corner(knob, 8)
        if disabled then sw.BackgroundTransparency = 0.6; knob.BackgroundTransparency = 0.6 end
        local function render()
            tween(knob, 0.3, {
                Position = obj.Value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                BackgroundColor3 = obj.Value and Color3.fromRGB(14, 14, 14) or Color3.fromRGB(200, 200, 200),
            }, Enum.EasingStyle.Back)
            tween(sw, 0.25, { BackgroundColor3 = obj.Value and ON or OFF })
        end
        render()
        function obj:SetValue(v, silent)
            if disabled then return end
            obj.Value = v and true or false
            render()
            if not silent then callback(info, obj.Value) end
        end
        local btn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
        btn.MouseButton1Click:Connect(function() obj:SetValue(not obj.Value) end)
        return obj
    end

    -- Slider
    function Box:AddSlider(idx, info)
        info = info or {}
        local min, max, rnd = info.Min or 0, info.Max or 100, info.Rounding or 0
        local mult = 10 ^ rnd
        local obj = { Type = "Slider", Value = info.Default or min, Min = min, Max = max }
        Options[idx] = obj
        addMethods(obj, info)
        local f = mk(44)
        new("TextLabel", {
            Size = UDim2.new(0.62, 0, 0, 16), BackgroundTransparency = 1, Text = info.Text or idx, Font = Enum.Font.GothamMedium,
            TextSize = 13, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f,
        })
        local valueLabel = new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.38, 0, 0, 16),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Accent,
            TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = f,
        })
        local track = new("Frame", {
            Position = UDim2.new(0, 0, 0, 29), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = f,
        })
        corner(track, 3)
        local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = track })
        corner(fill, 3)
        gradient(fill, ACCENT_SEQ, 0)
        local knob = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = fill,
        })
        corner(knob, 7)
        local function fmt(v)
            local s = rnd > 0 and string.format("%." .. rnd .. "f", v) or tostring(math.floor(v + 0.5))
            return info.Suffix and (s .. " " .. info.Suffix) or s
        end
        local function visual()
            valueLabel.Text = fmt(obj.Value)
            local frac = (max > min) and (obj.Value - min) / (max - min) or 0
            tween(fill, 0.1, { Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1) }, Enum.EasingStyle.Sine)
        end
        function obj:SetValue(v, silent)
            v = math.clamp(math.floor(v * mult + 0.5) / mult, min, max)
            obj.Value = v
            visual()
            if not silent then callback(info, v) end
        end
        obj.Value = math.clamp(obj.Value, min, max)
        visual()
        local hit = new("TextButton", {
            Position = UDim2.new(0, -4, 0, 22), Size = UDim2.new(1, 8, 0, 22), BackgroundTransparency = 1, Text = "", Parent = f,
        })
        bindDrag(hit, track, function(frac) obj:SetValue(min + (max - min) * frac) end)
        return obj
    end

    -- Dropdown (раскрывается внутри карточки, подходит для длинных списков скинов)
    function Box:AddDropdown(idx, info)
        info = info or {}
        local values = info.Values or {}
        local cur = info.Default
        if type(cur) == "number" then cur = values[cur] end
        cur = cur or values[1]
        local obj = { Type = "Dropdown", Value = cur, Values = values }
        Options[idx] = obj
        addMethods(obj, info)
        local f = mk(50, true)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = info.Text or idx, Font = Enum.Font.GothamMedium,
            TextSize = 13, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f,
        })
        local pill = new("TextButton", {
            Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.88, Text = "", AutoButtonColor = false, Parent = f,
        })
        corner(pill, 8)
        local pillText = new("TextLabel", {
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0), BackgroundTransparency = 1, Text = tostring(cur or "—"),
            Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = pill,
        })
        local arrow = new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1,
            Text = ">", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.Sub, Rotation = 90, Parent = pill,
        })
        local list = new("ScrollingFrame", {
            Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = f,
        })
        new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
        local open = false
        local function listHeight() return math.min(#values * 28, 140) end
        local function rebuild()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for i, v in ipairs(values) do
                local b = new("TextButton", {
                    LayoutOrder = i, Size = UDim2.new(1, -4, 0, 26), BackgroundColor3 = WHITE,
                    BackgroundTransparency = (v == obj.Value) and 0.2 or 0.94, Text = tostring(v), Font = Enum.Font.GothamMedium, TextSize = 12,
                    TextColor3 = (v == obj.Value) and SEL or THEME.Text, AutoButtonColor = false, Parent = list,
                })
                corner(b, 7)
                b.MouseButton1Click:Connect(function()
                    obj:SetValue(v)
                    obj:Close()
                end)
            end
        end
        function obj:Close()
            open = false
            tween(f, 0.25, { Size = UDim2.new(1, 0, 0, 50) })
            tween(arrow, 0.25, { Rotation = 90 })
            task.delay(0.25, function() if not open then list.Visible = false end end)
        end
        function obj:SetValue(v, silent)
            if type(v) == "number" then v = values[v] end
            obj.Value = v
            pillText.Text = tostring(v or "—")
            if not silent then callback(info, v) end
        end
        function obj:SetValues(newValues)
            values = newValues
            obj.Values = newValues
            if open then rebuild() end
        end
        pill.MouseButton1Click:Connect(function()
            if open then obj:Close(); return end
            open = true
            rebuild()
            list.Size = UDim2.new(1, 0, 0, listHeight())
            list.Visible = true
            tween(f, 0.25, { Size = UDim2.new(1, 0, 0, 56 + listHeight()) })
            tween(arrow, 0.25, { Rotation = -90 })
        end)
        hoverFx(pill, pill, 0.88, 0.8)
        return obj
    end

    -- Input (текстовое поле)
    function Box:AddInput(idx, info)
        info = info or {}
        local obj = { Type = "Input", Value = info.Default or "" }
        Options[idx] = obj
        addMethods(obj, info)
        local f = mk(50)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = info.Text or idx, Font = Enum.Font.GothamMedium,
            TextSize = 13, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
        })
        local tb = new("TextBox", {
            Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = WHITE, BackgroundTransparency = 0.88,
            Text = obj.Value, PlaceholderText = info.Placeholder or "", PlaceholderColor3 = THEME.Sub, TextColor3 = THEME.Text,
            Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
        })
        corner(tb, 8)
        new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = tb })
        function obj:SetValue(v, silent)
            obj.Value = tostring(v or "")
            tb.Text = obj.Value
            if not silent then callback(info, obj.Value) end
        end
        tb:GetPropertyChangedSignal("Text"):Connect(function() obj.Value = tb.Text end)
        tb.FocusLost:Connect(function() callback(info, tb.Text) end)
        return obj
    end

    -- Button
    function Box:AddButton(a, b)
        local text, func
        if type(a) == "table" then text, func = a.Text, a.Func else text, func = a, b end
        local f = mk(32)
        local bg = new("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.06, Text = text or "Button",
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = SEL, AutoButtonColor = false, Parent = f,
        })
        corner(bg, 8)
        gradient(bg, LIGHT_SEQ, 0)
        hoverFx(bg, bg, 0.06, 0.22)
        bg.MouseButton1Click:Connect(function()
            if func then
                local ok, err = pcall(func)
                if not ok then warn("[DxHub] button: " .. tostring(err)) end
            end
        end)
        return { Frame = f, SetText = function(_, t) bg.Text = t end }
    end

    function Box:AddDivider()
        local f = mk(8)
        new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = f,
        })
    end

    -- Label (+ цвет / клавиша на той же строке)
    function Box:AddLabel(text)
        local f = mk(24, true)
        local lbl = new("TextLabel", {
            Size = UDim2.new(1, -70, 0, 24), BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamMedium,
            TextSize = 13, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f,
        })
        local L = { Frame = f }
        function L:SetText(t) lbl.Text = t end

        -- ColorPicker: пресеты + R/G/B
        function L:AddColorPicker(idx, info)
            info = info or {}
            local obj = { Type = "ColorPicker", Value = info.Default or WHITE }
            Options[idx] = obj
            addMethods(obj, info)
            local swatch = new("Frame", {
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(40, 16),
                BackgroundColor3 = obj.Value, BorderSizePixel = 0, Parent = f,
            })
            corner(swatch, 6)
            stroke(swatch, 0.5, 1)
            local panel = new("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 108), BackgroundTransparency = 1, Parent = f })
            local presets = {
                Color3.fromRGB(255, 85, 100), Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 230, 90), Color3.fromRGB(90, 235, 150),
                Color3.fromRGB(80, 210, 255), Color3.fromRGB(110, 140, 255), Color3.fromRGB(190, 100, 255), Color3.fromRGB(255, 255, 255),
            }
            local refreshers = {}
            local function refreshAll()
                swatch.BackgroundColor3 = obj.Value
                for _, r in ipairs(refreshers) do r() end
            end
            function obj:SetValue(c, silent)
                if typeof(c) == "table" then c = Color3.fromRGB(c.r or c[1] or 255, c.g or c[2] or 255, c.b or c[3] or 255) end
                obj.Value = c
                refreshAll()
                if not silent then callback(info, c) end
            end
            for i, pc in ipairs(presets) do
                local b = new("TextButton", {
                    Position = UDim2.fromOffset((i - 1) * 25, 0), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = pc, Text = "",
                    AutoButtonColor = false, Parent = panel,
                })
                corner(b, 10)
                b.MouseButton1Click:Connect(function() obj:SetValue(pc) end)
            end
            local chans = {
                { "R", Color3.fromRGB(255, 90, 100), "R" }, { "G", Color3.fromRGB(90, 230, 140), "G" }, { "B", Color3.fromRGB(90, 150, 255), "B" },
            }
            for i, ch in ipairs(chans) do
                local y = 28 + (i - 1) * 24
                new("TextLabel", {
                    Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(14, 18), BackgroundTransparency = 1, Text = ch[1],
                    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = THEME.Sub, Parent = panel,
                })
                local track = new("Frame", {
                    Position = UDim2.fromOffset(18, y + 7), Size = UDim2.new(1, -62, 0, 4), BackgroundColor3 = WHITE,
                    BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = panel,
                })
                corner(track, 2)
                local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ch[2], BorderSizePixel = 0, Parent = track })
                corner(fill, 2)
                local val = new("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y), Size = UDim2.fromOffset(34, 18), BackgroundTransparency = 1,
                    Text = "0", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Right, Parent = panel,
                })
                local function chanValue() return math.floor(obj.Value[ch[3]] * 255 + 0.5) end
                refreshers[#refreshers + 1] = function()
                    fill.Size = UDim2.fromScale(chanValue() / 255, 1)
                    val.Text = tostring(chanValue())
                end
                local hit = new("TextButton", {
                    Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -52, 0, 18), BackgroundTransparency = 1, Text = "", Parent = panel,
                })
                bindDrag(hit, track, function(frac)
                    local r, g, b = obj.Value.R, obj.Value.G, obj.Value.B
                    if ch[3] == "R" then r = frac elseif ch[3] == "G" then g = frac else b = frac end
                    obj:SetValue(Color3.new(r, g, b))
                end)
            end
            refreshAll()
            local open = false
            local hdr = new("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "", Parent = f })
            hdr.MouseButton1Click:Connect(function()
                open = not open
                tween(f, 0.3, { Size = UDim2.new(1, 0, 0, open and 142 or 24) })
            end)
            return obj
        end

        -- KeyPicker
        function L:AddKeyPicker(idx, info)
            info = info or {}
            local obj = { Type = "KeyPicker", Value = info.Default or "None", State = false }
            Options[idx] = obj
            addMethods(obj, info)
            local btn = new("TextButton", {
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(64, 20), BackgroundColor3 = WHITE,
                BackgroundTransparency = 0.88, Text = tostring(obj.Value), Font = Enum.Font.GothamBold, TextSize = 11,
                TextColor3 = THEME.Text, AutoButtonColor = false, Parent = f,
            })
            corner(btn, 6)
            local listening = false
            local function norm(name)
                if name == "LeftControl" then return "LCtrl" end
                if name == "RightControl" then return "RCtrl" end
                return name
            end
            function obj:SetValue(v)
                obj.Value = type(v) == "table" and tostring(v[1]) or tostring(v)
                btn.Text = obj.Value
            end
            btn.MouseButton1Click:Connect(function()
                listening = true
                btn.Text = "..."
            end)
            connect(UserInputService.InputBegan, function(input, gp)
                if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                if listening then
                    listening = false
                    if input.KeyCode == Enum.KeyCode.Escape then
                        btn.Text = obj.Value
                    else
                        obj.Value = norm(input.KeyCode.Name)
                        btn.Text = obj.Value
                    end
                    return
                end
                if not gp and input.KeyCode.Name == obj.Value then
                    obj.State = not obj.State
                    callback(info, obj.State)
                end
            end)
            return obj
        end
        return L
    end

    return Box
end

-- ------------------------------ Окно ------------------------------
function Library:CreateWindow(info)
    info = info or {}
    local Window = { _tabs = {}, _count = 0 }
    local WIN_W, WIN_H, SIDE = 700, 430, 150

    local gui = new("ScreenGui", {
        Name = "DXHub", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
    })
    local okp = pcall(function() gui.Parent = (typeof(gethui) == "function" and gethui()) or CoreGui end)
    if not okp or not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
    Library.Gui = gui
    Library._blur = new("BlurEffect", { Name = "DXHubBlur", Size = 0, Parent = Lighting })
    local blur = Library._blur

    local root = new("Frame", {
        Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundTransparency = 1, Visible = false, Parent = gui,
    })
    local fit = new("UIScale", { Parent = root })
    local function updateFit()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local v = cam.ViewportSize
        fit.Scale = math.min(1, v.X / (WIN_W + 60), v.Y / (WIN_H + 70))
    end
    updateFit()
    connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), updateFit)
    connect(RunService.RenderStepped, function()
        local cam = Workspace.CurrentCamera
        if cam and Library._lastVp ~= cam.ViewportSize then
            Library._lastVp = cam.ViewportSize
            updateFit()
        end
    end)

    -- Окно: CanvasGroup для плавного появления; градиент фона — в отдельном Frame (иначе красит весь текст)
    local window = new("CanvasGroup", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, GroupTransparency = 1, Parent = root,
    })
    corner(window, 18)
    local winScale = new("UIScale", { Scale = 0.85, Parent = window })
    local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = window })
    gradient(bg, ColorSequence.new(Color3.fromRGB(58, 58, 58), Color3.fromRGB(10, 10, 10)), 60)
    local winStroke = stroke(window, 0.1, 2)
    local strokeGrad = gradient(winStroke, ACCENT_SEQ, 0)
    local shine = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = window })
    new("UIGradient", {
        Rotation = 35, Parent = shine,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.4, 0.96), NumberSequenceKeypoint.new(1, 1),
        }),
    })
    local function orb(color, startPos, endPos, size, time)
        local o = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = startPos, Size = UDim2.fromOffset(size, size), BackgroundColor3 = color,
            BackgroundTransparency = 0.86, BorderSizePixel = 0, Parent = window,
        })
        corner(o, size)
        TweenService:Create(o, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = endPos }):Play()
    end
    orb(THEME.Accent, UDim2.fromScale(0.25, 0.2), UDim2.fromScale(0.55, 0.6), 260, 7)
    orb(THEME.Accent2, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.6, 0.35), 220, 9)

    -- Сайдбар
    local sidebar = new("Frame", {
        Size = UDim2.new(0, SIDE, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 10, 22), BackgroundTransparency = 0.7,
        BorderSizePixel = 0, Parent = window,
    })
    new("Frame", {
        Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9,
        BorderSizePixel = 0, Parent = sidebar,
    })
    drawIcon(sidebar, "logo", 26, WHITE, UDim2.fromOffset(14, 16))
    local logo = new("TextLabel", {
        Position = UDim2.fromOffset(46, 14), Size = UDim2.new(1, -52, 0, 30), BackgroundTransparency = 1, Text = "DX HUB",
        Font = Enum.Font.GothamBlack, TextSize = 19, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Parent = sidebar,
    })
    local logoGrad = gradient(logo, ACCENT_SEQ, 0)
    new("TextLabel", {
        Position = UDim2.fromOffset(46, 40), Size = UDim2.new(1, -52, 0, 14), BackgroundTransparency = 1, Text = "BloxStrike",
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = sidebar,
    })
    local tabArea = new("Frame", {
        Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -80), BackgroundTransparency = 1, Parent = sidebar,
    })
    local indicator = new("Frame", {
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 38), BackgroundColor3 = WHITE, BackgroundTransparency = 0.04,
        BorderSizePixel = 0, Parent = tabArea,
    })
    corner(indicator, 11)
    gradient(indicator, LIGHT_SEQ, 0)

    -- Верхняя панель
    local topbar = new("Frame", { Position = UDim2.fromOffset(SIDE, 0), Size = UDim2.new(1, -SIDE, 0, 50), BackgroundTransparency = 1, Parent = window })
    local title = new("TextLabel", {
        Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -70, 1, 0), BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold,
        TextSize = 19, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = topbar,
    })
    new("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = topbar,
    })
    local closeBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = Color3.fromRGB(110, 110, 110), BackgroundTransparency = 0.6, Text = "×", Font = Enum.Font.GothamBold,
        TextSize = 22, TextColor3 = THEME.Text, AutoButtonColor = false, Parent = topbar,
    })
    corner(closeBtn, 14)
    closeBtn.MouseEnter:Connect(function() tween(closeBtn, 0.3, { BackgroundTransparency = 0.1, Rotation = 90 }, Enum.EasingStyle.Back) end)
    closeBtn.MouseLeave:Connect(function() tween(closeBtn, 0.3, { BackgroundTransparency = 0.6, Rotation = 0 }, Enum.EasingStyle.Back) end)

    local pages = new("Frame", {
        Position = UDim2.fromOffset(SIDE, 50), Size = UDim2.new(1, -SIDE, 1, -50), BackgroundTransparency = 1, ClipsDescendants = true, Parent = window,
    })
    makeDraggable(topbar, root, function() return fit.Scale end)
    makeDraggable(sidebar, root, function() return fit.Scale end)

    toastHolder = new("Frame", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(260, 300), BackgroundTransparency = 1, Parent = gui,
    })
    new("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastHolder,
    })

    -- Открытие / закрытие
    local token
    local function setOpen(state)
        if state == Library._open then return end
        Library._open = state
        local my = {}
        token = my
        if state then
            root.Visible = true
            winScale.Scale = 0.8
            window.GroupTransparency = 1
            window.Position = UDim2.new(0.5, 0, 0.5, 30)
            tween(window, 0.5, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) })
            tween(winScale, 0.65, { Scale = 1 }, Enum.EasingStyle.Back)
            tween(blur, 0.5, { Size = 14 })
        else
            tween(window, 0.3, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 20) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tween(winScale, 0.3, { Scale = 0.88 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            tween(blur, 0.35, { Size = 0 })
            task.delay(0.32, function() if token == my then root.Visible = false end end)
        end
    end
    function Library:Toggle() setOpen(not Library._open) end
    closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

    -- Круглая кнопка-лаунчер: тап — открыть/закрыть, потянуть — переместить
    local launcher = new("Frame", {
        Name = "Launcher", Active = true, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.4, 0),
        Size = UDim2.fromOffset(54, 54), BackgroundColor3 = THEME.Glass, BackgroundTransparency = 0.15, Parent = gui,
    })
    corner(launcher, 27)
    local launcherGrad = gradient(stroke(launcher, 0, 2.5), ACCENT_SEQ, 0)
    drawIcon(launcher, "logo", 30, WHITE, UDim2.fromOffset(12, 12))
    local lScale = new("UIScale", { Parent = launcher })
    local ldrag, lmoved, lstart, lpos = false, false, nil, nil
    launcher.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ldrag, lmoved, lstart, lpos = true, false, input.Position, launcher.Position
            tween(lScale, 0.1, { Scale = 0.88 })
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    ldrag = false
                    tween(lScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
                    if not lmoved then Library:Toggle() end
                end
            end)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if ldrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - lstart
            if d.Magnitude > 8 then lmoved = true end
            if lmoved then launcher.Position = UDim2.new(lpos.X.Scale, lpos.X.Offset + d.X, lpos.Y.Scale, lpos.Y.Offset + d.Y) end
        end
    end)
    launcher.MouseEnter:Connect(function() tween(lScale, 0.35, { Scale = 1.1 }, Enum.EasingStyle.Back) end)
    launcher.MouseLeave:Connect(function() if not ldrag then tween(lScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end end)

    -- Вращение градиентов
    connect(RunService.RenderStepped, function(dt)
        launcherGrad.Rotation = (launcherGrad.Rotation + dt * 90) % 360
        if Library._open then
            strokeGrad.Rotation = (strokeGrad.Rotation + dt * 40) % 360
            logoGrad.Rotation = (logoGrad.Rotation + dt * 30) % 360
        end
    end)

    -- Вкладки
    local current
    local function selectTab(t)
        if current == t then return end
        local prev = current
        current = t
        if prev then
            tween(prev.page, 0.2, { GroupTransparency = 1 })
            tween(prev.label, 0.25, { TextColor3 = THEME.Sub })
            prev.tint(THEME.Sub, DARK, true)
            task.delay(0.2, function() if current ~= prev then prev.page.Visible = false end end)
        end
        t.page.Visible = true
        t.page.Position = UDim2.fromOffset(0, 20)
        tween(t.page, 0.45, { GroupTransparency = 0, Position = UDim2.new() })
        tween(t.label, 0.25, { TextColor3 = SEL })
        t.tint(SEL, WHITE, true)
        tween(indicator, 0.4, { Position = UDim2.fromOffset(10, (t.index - 1) * 44) }, Enum.EasingStyle.Back)
        title.Text = t.name
        title.TextTransparency = 1
        title.Position = UDim2.fromOffset(20, 8)
        tween(title, 0.35, { TextTransparency = 0, Position = UDim2.fromOffset(20, 0) })
    end

    function Window:AddTab(name, iconName)
        Window._count += 1
        local index = Window._count
        local btn = new("TextButton", {
            Position = UDim2.fromOffset(10, (index - 1) * 44), Size = UDim2.new(1, -20, 0, 38), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, Parent = tabArea,
        })
        local _, tint = drawIcon(btn, ICONS[iconName] or "home", 18, THEME.Sub, UDim2.fromOffset(13, 10))
        local lbl = new("TextLabel", {
            Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -42, 1, 0), BackgroundTransparency = 1, Text = name,
            Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = THEME.Sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
        })
        local page = new("CanvasGroup", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = pages,
        })
        local function column(xScale, xOff)
            local sf = new("ScrollingFrame", {
                Position = UDim2.new(xScale, xOff, 0, 0), Size = UDim2.new(0.5, -15, 1, -6), BackgroundTransparency = 1, BorderSizePixel = 0,
                ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.Accent, CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = page,
            })
            new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
            new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 16), Parent = sf })
            return sf
        end
        local left, right = column(0, 10), column(0.5, 5)

        local T = { name = name, index = index, page = page, label = lbl, tint = tint }
        function T:AddLeftGroupbox(title2) return makeGroupbox(left, title2) end
        function T:AddRightGroupbox(title2) return makeGroupbox(right, title2) end
        Window._tabs[#Window._tabs + 1] = T

        btn.MouseEnter:Connect(function() if current ~= T then tween(lbl, 0.2, { TextColor3 = THEME.Text }) end end)
        btn.MouseLeave:Connect(function() if current ~= T then tween(lbl, 0.2, { TextColor3 = THEME.Sub }) end end)
        btn.MouseButton1Click:Connect(function() selectTab(T) end)
        if index == 1 then selectTab(T) end
        return T
    end

    Library:OnUnload(function() launcher:Destroy() end)
    if info.AutoShow ~= false then task.defer(function() setOpen(true) end) end
    return Window
end

-- =========================================================================
-- [ WINDOW ]
-- =========================================================================

local Window = Library:CreateWindow({
    Title = "DX HUB",
    Center = true,
    AutoShow = true,
})

-- Универсальные геттеры (для совместимости с разными версиями библиотек)
local function getToggle(name)
    local t = Toggles and Toggles[name]
    if t then
        local ok, v = pcall(function() return t.Value end)
        if ok then return v and true or false end
    end
    local o = Options and Options[name]
    if o then
        local ok, v = pcall(function() return o.Value end)
        if ok then return v and true or false end
    end
    return false
end

local function getOption(name, default)
    local o = Options and Options[name]
    if o then
        local ok, v = pcall(function() return o.Value end)
        if ok and v ~= nil then return v end
    end
    local t = Toggles and Toggles[name]
    if t then
        local ok, v = pcall(function() return t.Value end)
        if ok and v ~= nil then return v end
    end
    return default
end

local Tabs = {
    Combat      = Window:AddTab('Combat', 'crosshair'),
    Visuals     = Window:AddTab('Visuals', 'eye'),
    Movements   = Window:AddTab('Movements', 'person-standing'),
    World       = Window:AddTab('World', 'globe'),
    Weapons     = Window:AddTab('Weapons', 'crosshair'),
    Misc        = Window:AddTab('Misc', 'activity'),
    SkinChanger = Window:AddTab('SkinChanger', 'palette'),
    Settings    = Window:AddTab('Settings', 'settings'),
}

-- =========================================================================
-- [ SETTINGS ]
-- =========================================================================

local SettingsGroup = Tabs.Settings:AddLeftGroupbox("Interface", "settings")

SettingsGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Text = "Menu Keybind",
    Default = "RightShift",
    Mode = "Toggle",
    Callback = function(v) Library:Toggle() end
})

connect(UserInputService.InputBegan, function(input, gp)
    if not gp then
        local cv = getOption("MenuKeybind", "RightShift")
        if cv == "LeftControl" or cv == "LCtrl" then
            if input.KeyCode == Enum.KeyCode.LeftControl then Library:Toggle() end
        elseif cv == "RightControl" or cv == "RCtrl" then
            if input.KeyCode == Enum.KeyCode.RightControl then Library:Toggle() end
        end
    end
end)

SettingsGroup:AddDivider()
SettingsGroup:AddButton("Unload Menu", function() Library:Unload() end)

-- =========================================================================
-- [ COMBAT — AIM + SILENT ]
-- =========================================================================

local AimBox = Tabs.Combat:AddLeftGroupbox("Aimbot", "target")

AimBox:AddToggle("AimbotEnabled",   { Text = "Enable Aimbot",               Default = false })
AimBox:AddToggle("AimbotSnap",      { Text = "Instant Snap",                Default = true })
AimBox:AddSlider("AimbotFOV",       { Text = "FOV", Default = 200, Min = 10, Max = 800, Rounding = 0, Suffix = "px" })
AimBox:AddSlider("AimbotSmooth",    { Text = "Smoothness", Default = 15, Min = 1, Max = 100, Rounding = 0, Suffix = "%" })
AimBox:AddDropdown("AimbotPart",    { Text = "Target Part", Values = {"Head","UpperTorso","HumanoidRootPart","LowerTorso"}, Default = "Head" })
AimBox:AddToggle("AimbotTeamCheck", { Text = "Team Check",                  Default = true })
AimBox:AddToggle("AimbotWallCheck", { Text = "Wall Check",                  Default = false })
AimBox:AddToggle("AimbotDrawFOV",   { Text = "Draw FOV Circle",             Default = true })
AimBox:AddLabel("FOV Color"):AddColorPicker("AimbotFovColor", { Default = Color3.fromRGB(0, 217, 163) })

local SilentBox = Tabs.Combat:AddRightGroupbox("Silent Aim", "radio")

SilentBox:AddToggle("SilentAim", {
    Text = "Enable Silent Aim",
    Default = false,
    Disabled = typeof(hookfunction) ~= "function" and typeof(hookmetamethod) ~= "function",
    DisabledTooltip = "Executor doesn't support hookmetamethod."
})
SilentBox:AddSlider("SilentFOV",  { Text = "Silent FOV", Default = 150, Min = 10, Max = 800, Rounding = 0, Suffix = "px" })
SilentBox:AddDropdown("SilentPart", {
    Text = "Hit Part",
    Values = {"Head","UpperTorso","HumanoidRootPart","LowerTorso"},
    Default = "Head"
})
SilentBox:AddToggle("SilentWallbang",  { Text = "Wallbang", Default = true })
SilentBox:AddToggle("SilentTeamCheck", { Text = "Team Check", Default = true })
SilentBox:AddToggle("SilentDrawFOV",   { Text = "Draw Silent FOV", Default = false })
SilentBox:AddLabel("Silent FOV Color"):AddColorPicker("SilentFovColor", { Default = Color3.fromRGB(255, 100, 60) })

-- =========================================================================
-- [ VISUALS — ESP + CHAMS ]
-- =========================================================================

local ESPBox = Tabs.Visuals:AddLeftGroupbox("ESP", "eye")

ESPBox:AddToggle("ESPEnabled",   { Text = "Включить ESP", Default = false })
ESPBox:AddToggle("ESPTeamCheck", { Text = "Проверка команды", Default = true })
ESPBox:AddDropdown("ESPTargets", { Text = "Кого показывать", Values = {"Все", "Только враги", "Только союзники"}, Default = "Все" })
ESPBox:AddDivider()

ESPBox:AddToggle("ESPBox",       { Text = "Рамка (бокс)", Default = true })
ESPBox:AddLabel("Box Color"):AddColorPicker("ESPBoxColor", { Default = Color3.fromRGB(0, 217, 163) })

ESPBox:AddToggle("ESPName",      { Text = "Имя", Default = true })
ESPBox:AddLabel("Name Color"):AddColorPicker("ESPNameColor", { Default = Color3.fromRGB(255, 255, 255) })

ESPBox:AddToggle("ESPHealth",    { Text = "Полоска HP", Default = true })
ESPBox:AddLabel("Health Top"):AddColorPicker("ESPHealthTop",       { Default = Color3.fromRGB(0, 220, 120) })
ESPBox:AddLabel("Health Bottom"):AddColorPicker("ESPHealthBottom", { Default = Color3.fromRGB(255, 60, 60) })

ESPBox:AddToggle("ESPDistance",  { Text = "Дистанция", Default = true })
ESPBox:AddToggle("ESPWeapon",    { Text = "Оружие в руках", Default = true })
ESPBox:AddToggle("ESPTracer",    { Text = "Трейсер (линия)", Default = false })
ESPBox:AddLabel("Tracer Color"):AddColorPicker("ESPTracerColor", { Default = Color3.fromRGB(0, 217, 163) })
ESPBox:AddToggle("ESPSkeleton", { Text = "Скелет", Default = false })
ESPBox:AddLabel("Цвет скелета"):AddColorPicker("ESPSkeletonColor", { Default = Color3.fromRGB(255, 255, 255) })
ESPBox:AddDropdown("ESPTracerOrigin", { Text = "Откуда линия", Values = {"Bottom","Center","Top","Mouse"}, Default = "Bottom" })

local ChamsBox = Tabs.Visuals:AddRightGroupbox("Chams", "layers")

ChamsBox:AddToggle("ChamsEnabled",   { Text = "Включить чамсы", Default = false })
ChamsBox:AddToggle("ChamsTeamCheck", { Text = "Проверка команды", Default = true })
ChamsBox:AddDivider()

ChamsBox:AddLabel("Visible Color"):AddColorPicker("ChamsVisibleColor",   { Default = Color3.fromRGB(0, 220, 120) })
ChamsBox:AddLabel("Occluded Color"):AddColorPicker("ChamsOccludedColor", { Default = Color3.fromRGB(255, 60, 60) })
ChamsBox:AddSlider("ChamsFillTransparency",    { Text = "Fill Transparency",    Default = 0.5, Min = 0, Max = 1, Rounding = 2 })
ChamsBox:AddSlider("ChamsOutlineTransparency", { Text = "Outline Transparency", Default = 0.2, Min = 0, Max = 1, Rounding = 2 })

-- =========================================================================
-- [ MOVEMENTS ]
-- =========================================================================

local MoveBox = Tabs.Movements:AddLeftGroupbox("Movement", "activity")

MoveBox:AddToggle("AutoBhop",     { Text = "Auto Bhop",      Default = false })
MoveBox:AddSlider("BhopSpeed",    { Text = "Bhop Speed",     Default = 18, Min = 5, Max = 30, Rounding = 1, Suffix = "spd" })
MoveBox:AddToggle("NoFallDamage", { Text = "No Fall Damage", Default = false })

local SpeedBox = Tabs.Movements:AddRightGroupbox("Speed", "zap")

SpeedBox:AddToggle("SpeedEnabled", { Text = "Enable Speed", Default = false })
SpeedBox:AddSlider("WalkSpeed",    { Text = "Walk Speed",   Default = 22, Min = 16, Max = 120, Rounding = 0, Suffix = "spd" })

-- =========================================================================
-- [ SKIN CHANGER ]
-- =========================================================================

local RS = ReplicatedStorage
local SD = { SkinsRoot = nil, SkinSelections = {}, GloveSelections = {}, GloveFolders = {} }

pcall(function()
    SD.SkinsRoot = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Skins")
end)

if SD.SkinsRoot then
    pcall(function()
        for _, wf in ipairs(SD.SkinsRoot:GetChildren()) do
            local skins = {}
            for _, sf in ipairs(wf:GetChildren()) do skins[#skins + 1] = sf.Name end
            table.sort(skins)
            SD.SkinSelections[wf.Name] = skins
        end
        for _, folder in ipairs(SD.SkinsRoot:GetChildren()) do
            if (folder.Name:match("Glove") or folder.Name:match("Gloves") or folder.Name == "Hand Wraps")
               and not (folder.Name:match("T Glove") or folder.Name:match("CT Glove")
                     or folder.Name:match("T Gloves") or folder.Name:match("CT Gloves")) then
                SD.GloveFolders[#SD.GloveFolders + 1] = folder
            end
        end
    end)
end

for _, gf in ipairs(SD.GloveFolders) do
    local skins = {"Default"}
    for _, skin in ipairs(gf:GetChildren()) do skins[#skins + 1] = skin.Name end
    SD.GloveSelections[gf.Name] = skins
end

local SkinConfig = {
    SkinChanger  = { Enabled = false, Skins = {} },
    KnifeChanger = { Enabled = false, Model = "Skeleton Knife" },
    GloveChanger = { Enabled = false, Gloves = {}, Model = "Sports Gloves", Skin = "Default" },
}

for w, s in pairs(SD.SkinSelections) do SkinConfig.SkinChanger.Skins[w] = s[1] or "Default" end
for _, gf in ipairs(SD.GloveFolders) do SkinConfig.GloveChanger.Gloves[gf.Name] = "Default" end

local BaseKnives = {"CT Knife", "T Knife", "Knife"}
local function Checkknife(w)
    if not w then return false end
    for _, k in ipairs(BaseKnives) do if w == k then return true end end
    return false
end

local SkinsBox  = Tabs.SkinChanger:AddLeftGroupbox("Weapon Skins", "palette")
local GlovesBox = Tabs.SkinChanger:AddRightGroupbox("Gloves", "hand")
local KnifeBox  = Tabs.SkinChanger:AddRightGroupbox("Knife", "sword")

SkinsBox:AddToggle("EnableSkins", {
    Text = "Enable Weapon Skins",
    Default = false,
    Callback = function(v) SkinConfig.SkinChanger.Enabled = v end
})

local KnifeModels = {"Karambit","Butterfly Knife","Flip Knife","Gut Knife","M9 Bayonet","Skeleton Knife","Stiletto Knife"}
local ExcludedWeapons = {"Driver Gloves","Sports Gloves","Operator Gloves","Hand Wraps"}

KnifeBox:AddToggle("KnifeChangerToggle", {
    Text = "Enable Knife Changer",
    Default = false,
    Callback = function(v) SkinConfig.KnifeChanger.Enabled = v end
})

KnifeBox:AddDropdown("KnifeModel", {
    Text = "Knife Model",
    Values = KnifeModels,
    Default = "Skeleton Knife",
    Callback = function(v) SkinConfig.KnifeChanger.Model = v end
})

for _, kn in ipairs(KnifeModels) do
    local ks = SD.SkinSelections[kn]
    if ks then
        KnifeBox:AddDropdown("KnifeSkin_" .. kn, {
            Text = kn .. " Skin",
            Values = ks,
            Default = 1,
            Callback = function(v) SkinConfig.SkinChanger.Skins[kn] = v end
        })
    end
end

GlovesBox:AddToggle("GloveChangerToggle", {
    Text = "Enable Gloves Changer",
    Default = false,
    Callback = function(v) SkinConfig.GloveChanger.Enabled = v end
})

local GloveModels = {}
for k in pairs(SD.GloveSelections) do GloveModels[#GloveModels + 1] = k end
table.sort(GloveModels)

GlovesBox:AddDropdown("GloveModel", {
    Text = "Glove Model",
    Values = GloveModels,
    Default = GloveModels[1] or "Sports Gloves",
    Callback = function(v) SkinConfig.GloveChanger.Model = v end
})

for _, gFolder in ipairs(SD.GloveFolders) do
    local gName = gFolder.Name
    local gSkins = SD.GloveSelections[gName]
    if gSkins then
        GlovesBox:AddDropdown("GloveSkin_" .. gName, {
            Text = gName .. " Skin",
            Values = gSkins,
            Default = 1,
            Callback = function(v) SkinConfig.GloveChanger.Gloves[gName] = v end
        })
    end
end

for w, s in pairs(SD.SkinSelections) do
    if not table.find(KnifeModels, w) and not table.find(GloveModels, w) and not table.find(ExcludedWeapons, w) then
        SkinsBox:AddDropdown("Skin_" .. w, {
            Text = w,
            Values = s,
            Default = 1,
            Callback = function(v) SkinConfig.SkinChanger.Skins[w] = v end
        })
    end
end

local KnifeSource = nil -- сохраняем Sk, чтобы брать модель выбранного ножа
local function InitKnifeChanger()
    pcall(function()
        local SM = RS:FindFirstChild("Database") and RS.Database:FindFirstChild("Components")
            and RS.Database.Components:FindFirstChild("Libraries")
            and RS.Database.Components.Libraries:FindFirstChild("Skins")
        local VM = RS:FindFirstChild("Classes") and RS.Classes:FindFirstChild("WeaponComponent")
            and RS.Classes.WeaponComponent:FindFirstChild("Classes")
            and RS.Classes.WeaponComponent.Classes:FindFirstChild("Viewmodel")
        if not SM or not VM then return end

        local Sk = SafeRequire(SM)
        local Vm = SafeRequire(VM)
        if not Sk or not Vm then return end
        KnifeSource = Sk

        local oGCM = Sk.GetCameraModel
        Sk.GetCameraModel = function(w, sk, ...)
            if SkinConfig.KnifeChanger.Enabled and w and Checkknife(w) then
                local nk = SkinConfig.KnifeChanger.Model
                local ns = SkinConfig.SkinChanger.Skins[nk] or "Vanilla"
                local s, r = pcall(oGCM, nk, ns, ...)
                if s and r then return r end
            end
            local s, r = pcall(oGCM, w, sk, ...)
            if s then return r end
            return nil
        end

        local oGChM = Sk.GetCharacterModel
        Sk.GetCharacterModel = function(w, sk, ...)
            if SkinConfig.KnifeChanger.Enabled and w and Checkknife(w) then
                local nk = SkinConfig.KnifeChanger.Model
                local ns = SkinConfig.SkinChanger.Skins[nk] or "Vanilla"
                local s, r = pcall(oGChM, nk, ns, ...)
                if s and r then return r end
            end
            local s, r = pcall(oGChM, w, sk, ...)
            if s then return r end
            return nil
        end

        local oVN = Vm.new
        Vm.new = function(vc, w, sk, ...)
            if SkinConfig.KnifeChanger.Enabled and w and Checkknife(w) then
                local nk = SkinConfig.KnifeChanger.Model
                local ns = SkinConfig.SkinChanger.Skins[nk] or "Vanilla"
                local s, r = pcall(oVN, vc, nk, ns, ...)
                if s and r then return r end
            end
            local s, r = pcall(oVN, vc, w, sk, ...)
            if s then return r end
            return nil
        end

        if Sk.GetGloves then
            local oGG = Sk.GetGloves
            Sk.GetGloves = function(g, sk)
                if SkinConfig.GloveChanger.Enabled and SkinConfig.GloveChanger.Model then
                    local gm = SkinConfig.GloveChanger.Model
                    local ts = SkinConfig.GloveChanger.Gloves[gm] or "Default"
                    local s, r = pcall(oGG, gm, ts)
                    if s and r then return r end
                end
                local s, r = pcall(oGG, g, sk)
                if s then return r end
                return nil
            end
        end
    end)
end

InitKnifeChanger()

local function GetWeaponModel()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    for _, ch in pairs(cam:GetChildren()) do
        if ch:IsA("Model") and ch.Name ~= "Arms" and ch.Name ~= "Arms1"
            and ch.Name ~= "Arms2" and ch.Name ~= "Viewmodel" then
            return ch
        end
    end
    return nil
end

local function ApplySkin()
    if not SD.SkinsRoot then return end
    local wm = GetWeaponModel()
    if not wm then return end
    local own = wm.Name
    local ewn = own
    local ca = false
    if Checkknife(own) then
        if SkinConfig.KnifeChanger.Enabled then ewn = SkinConfig.KnifeChanger.Model ca = true end
    else
        if SkinConfig.SkinChanger.Enabled then ca = true end
    end
    if not ca then return end
    -- Замена меша ножа: берём модель выбранного ножа и переносим MeshId/TextureID в текущую модель.
    -- Делаем один раз на каждую модель оружия (тег на модели).
    if Checkknife(own) and KnifeSource then
        local tag = "DxKnifeMesh_" .. tostring(ewn)
        if not wm:GetAttribute(tag) then
            wm:SetAttribute(tag, true)
            pcall(function()
                local rep = KnifeSource.GetCameraModel(ewn, SkinConfig.SkinChanger.Skins[ewn] or "Default")
                if rep then
                    for _, src in ipairs(rep:GetDescendants()) do
                        if src:IsA("MeshPart") then
                            local dst = wm:FindFirstChild(src.Name, true)
                            if dst and dst:IsA("MeshPart") then
                                pcall(function() dst.MeshId = src.MeshId end)
                                pcall(function() dst.TextureID = src.TextureID end)
                            end
                        end
                    end
                    rep:Destroy()
                end
            end)
        end
    end
    local sel = SkinConfig.SkinChanger.Skins[ewn]
    if not sel or sel == "Default" then return end
    local wsf = SD.SkinsRoot:FindFirstChild(ewn); if not wsf then return end
    local sf = wsf:FindFirstChild(sel); if not sf then return end
    local cf = sf:FindFirstChild("Camera"); if not cf then return end
    local fn = cf:FindFirstChild("Factory New"); if not fn then return end
    for _, sa in pairs(fn:GetChildren()) do
        if sa:IsA("SurfaceAppearance") then
            local pt = wm:FindFirstChild(sa.Name, true)
            if pt and (pt:IsA("BasePart") or pt:IsA("MeshPart")) then
                for _, old in pairs(pt:GetChildren()) do
                    if old:IsA("SurfaceAppearance") then old:Destroy() end
                end
                sa:Clone().Parent = pt
            end
        end
    end
end

local function ApplyGloves()
    if not SkinConfig.GloveChanger.Enabled then return end
    local cam = Workspace.CurrentCamera; if not cam then return end
    local am
    for _, ch in ipairs(cam:GetChildren()) do
        if ch:IsA("Model") and (ch.Name:match("Arms") or ch:FindFirstChild("Right Arm")) then
            am = ch; break
        end
    end
    if not am then return end
    local la = am:FindFirstChild("Left Arm")
    local ra = am:FindFirstChild("Right Arm")
    if not la or not ra then return end
    local lg = la:FindFirstChild("Glove")
    local rg = ra:FindFirstChild("Glove")
    if not lg or not rg then return end
    for _, old in pairs(lg:GetChildren()) do if old:IsA("SurfaceAppearance") then old:Destroy() end end
    for _, old in pairs(rg:GetChildren()) do if old:IsA("SurfaceAppearance") then old:Destroy() end end
    local sm = SkinConfig.GloveChanger.Model; if not sm then return end
    local sel = SkinConfig.GloveChanger.Gloves[sm]
    if not sel or sel == "Default" then return end
    if not SD.SkinsRoot then return end
    local gsf = SD.SkinsRoot:FindFirstChild(sm); if not gsf then return end
    local sv = gsf:FindFirstChild(sel); if not sv then return end
    local cfd = sv:FindFirstChild("Camera"); if not cfd then return end
    local fnew = cfd:FindFirstChild("Factory New"); if not fnew then return end
    for _, sa in pairs(fnew:GetChildren()) do
        if sa:IsA("SurfaceAppearance") then
            sa:Clone().Parent = lg
            sa:Clone().Parent = rg
        end
    end
end

-- =========================================================================
-- [ ESP + TRACER CACHE ]
-- =========================================================================

local TracerGui = Instance.new("ScreenGui")
TracerGui.Name = "DxHub_Tracers"
TracerGui.ResetOnSpawn = false
TracerGui.IgnoreGuiInset = true
TracerGui.DisplayOrder = 5
pcall(function() TracerGui.Parent = CoreGui end)

local ESPCache = {}
local ChamsHighlights = {}
local SKEL_R15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local SKEL_R6 = {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}

local function makeESP(player)
    if player == LP then return end
    if ESPCache[player] then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "DxHub_ESP_BB"
    bb.Size = UDim2.fromOffset(180, 70)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Adornee = char
    bb.Parent = char

    local boxFrame = Instance.new("Frame", bb)
    boxFrame.Name = "Box"
    boxFrame.Size = UDim2.new(1, 0, 1, 0)
    boxFrame.BackgroundTransparency = 1
    boxFrame.Visible = false
    local boxStroke = Instance.new("UIStroke", boxFrame)
    boxStroke.Thickness = 1.5
    boxStroke.Color = Color3.fromRGB(0, 217, 163)
    boxStroke.Transparency = 0.1

    local hpBg = Instance.new("Frame", bb)
    hpBg.Name = "HpBg"
    hpBg.Size = UDim2.new(0, 3, 1, 0)
    hpBg.Position = UDim2.new(0, -6, 0, 0)
    hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    hpBg.BorderSizePixel = 0
    hpBg.Visible = false

    local hpFill = Instance.new("Frame", hpBg)
    hpFill.AnchorPoint = Vector2.new(0, 1)
    hpFill.Position = UDim2.new(0, 0, 1, 0)
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 220, 120)
    hpFill.BorderSizePixel = 0

    local nameLbl = Instance.new("TextLabel", bb)
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.Position = UDim2.new(0, 0, 0, -18)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = player.Name
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.TextStrokeTransparency = 0.2
    nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLbl.Visible = false

    local distLbl = Instance.new("TextLabel", bb)
    distLbl.Size = UDim2.new(1, 0, 0, 13)
    distLbl.Position = UDim2.new(0, 0, 1, 2)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "0m"
    distLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    distLbl.Font = Enum.Font.GothamMedium
    distLbl.TextSize = 11
    distLbl.TextStrokeTransparency = 0.3
    distLbl.Visible = false

    local wepLbl = Instance.new("TextLabel", bb)
    wepLbl.Size = UDim2.new(1, 0, 0, 13)
    wepLbl.Position = UDim2.new(0, 0, 1, 16)
    wepLbl.BackgroundTransparency = 1
    wepLbl.Text = "[ None ]"
    wepLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
    wepLbl.Font = Enum.Font.GothamMedium
    wepLbl.TextSize = 11
    wepLbl.TextStrokeTransparency = 0.3
    wepLbl.Visible = false

    local tracer = Instance.new("Frame", TracerGui)
    tracer.AnchorPoint = Vector2.new(0, 0.5)
    tracer.BorderSizePixel = 0
    tracer.BackgroundColor3 = Color3.fromRGB(0, 217, 163)
    tracer.Visible = false

    local skel = {}
    for i = 1, 14 do
        local l = Drawing.new("Line")
        l.Thickness = 2
        l.Transparency = 1
        l.Visible = false
        skel[i] = l
    end

    ESPCache[player] = {
        skel = skel,
        bb = bb,
        boxFrame = boxFrame, boxStroke = boxStroke,
        hpBg = hpBg, hpFill = hpFill,
        name = nameLbl, dist = distLbl, wep = wepLbl,
        tracer = tracer,
        char = char,
    }
end

local function destroyESP(player)
    local d = ESPCache[player]
    if d then
        pcall(function() d.bb:Destroy() end)
        pcall(function() d.tracer:Destroy() end)
        if d.skel then for _, l in ipairs(d.skel) do pcall(function() l:Remove() end) end end
        ESPCache[player] = nil
    end
end

local function removeChams(char)
    local h = ChamsHighlights[char]
    if h then
        pcall(function() h.visible:Destroy() end)
        pcall(function() h.unvisible:Destroy() end)
        ChamsHighlights[char] = nil
    end
end

-- =========================================================================
-- [ AIMBOT + FOV CIRCLES ]
-- =========================================================================

local AimbotFovCircle = Drawing.new("Circle")
AimbotFovCircle.NumSides = 128
AimbotFovCircle.Thickness = 1.5
AimbotFovCircle.Filled = false
AimbotFovCircle.Visible = false

local SilentFovCircle = Drawing.new("Circle")
SilentFovCircle.NumSides = 128
SilentFovCircle.Thickness = 1.5
SilentFovCircle.Filled = false
SilentFovCircle.Visible = false

local SilentTarget = nil
local RayParamsAim = RaycastParams.new()
RayParamsAim.FilterType = Enum.RaycastFilterType.Exclude
RayParamsAim.IgnoreWater = true

local function isVisible(target)
    local ignoreList = {LP.Character}
    local myTeam = get_player_team(LP)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and get_player_team(p) == myTeam and p.Character then
            table.insert(ignoreList, p.Character)
        end
    end
    RayParamsAim.FilterDescendantsInstances = ignoreList
    local result = Workspace:Raycast(Camera.CFrame.Position, target.Position - Camera.CFrame.Position, RayParamsAim)
    if result then
        local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
        local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
        if hitPlayer and hitPlayer.Character == target.Parent then return true end
        return false
    end
    return true
end

-- Цели для аима: берём модели из папки Characters, живых, врага определяем по бронежилету (isAlly)
local function aimTargets(includeAllies)
    local out = {}
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then return out end
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m ~= LP.Character then
            local hp = m:GetAttribute("Health")
            local dead = m:GetAttribute("Dead") or m:GetAttribute("Invincible")
            if not dead and (hp == nil or hp > 0) then
                if includeAllies or not isAlly(m) then
                    out[#out + 1] = m
                end
            end
        end
    end
    return out
end

local function FindAimbotTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = cam.ViewportSize / 2
    local fov = getOption("AimbotFOV", 200)
    local partName = getOption("AimbotPart", "Head")
    local wallChk = getToggle("AimbotWallCheck")
    local best, bestD = nil, math.huge
    for _, m in ipairs(aimTargets(not getToggle("AimbotTeamCheck"))) do
        local tp = m:FindFirstChild(partName) or m:FindFirstChild("Head")
        if tp and not (wallChk and not isVisible(tp)) then
            local sp, on = cam:WorldToViewportPoint(tp.Position)
            if on then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d <= fov and d < bestD then
                    bestD = d
                    best = {part = tp}
                end
            end
        end
    end
    return best
end

local function FindSilentTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = cam.ViewportSize / 2
    local fov = getOption("SilentFOV", 150)
    local partName = getOption("SilentPart", "Head")
    local wallOk = getToggle("SilentWallbang")
    local best, bestD = nil, math.huge
    for _, m in ipairs(aimTargets(not getToggle("SilentTeamCheck"))) do
        local tp = m:FindFirstChild(partName) or m:FindFirstChild("Head")
        if tp and (wallOk or isVisible(tp)) then
            local sp, on = cam:WorldToViewportPoint(tp.Position)
            if on then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d <= fov and d < bestD then
                    bestD = d
                    best = {part = tp}
                end
            end
        end
    end
    return best
end

-- Silent aim: находим функцию отправки выстрела (как в PasteHub) и переписываем попадание на цель.
-- Наводку камеры не трогаем, поэтому прицел на экране остаётся на месте.
local XSend = nil
do
    local gc = getgc or get_gc_objects
    if gc then
        pcall(function()
            for _, obj in next, gc(true) do
                if type(obj) == "table" and rawget(obj, "shoot") and typeof(obj.shoot) == "function" then
                    for _, uv in pairs(debug.getupvalues(obj.shoot)) do
                        if type(uv) == "table" and rawget(uv, "Inventory") and type(uv.Inventory) == "table"
                            and rawget(uv.Inventory, "ShootWeapon") then
                            XSend = uv.Inventory.ShootWeapon.Send
                        end
                    end
                end
            end
        end)
    end
end

local XSendOld = nil
if XSend and typeof(hookfunction) == "function" then
    pcall(function()
        XSendOld = hookfunction(XSend, function(...)
            local tgt = SilentTarget
            if getToggle("SilentAim") and tgt and tgt.Parent then
                local a1 = ...
                if type(a1) == "table" and type(a1.Bullets) == "table" then
                    for _, bullet in pairs(a1.Bullets) do
                        if type(bullet.Hits) == "table" then
                            for _, hit in pairs(bullet.Hits) do
                                hit.Instance = tgt
                                hit.Position = tgt.Position
                            end
                        end
                    end
                end
            end
            return XSendOld(...)
        end)
    end)
end

task.delay(3, function()
    if not XSend then
        Library:Notify("Silent Aim: не найден метод стрельбы (нужен getgc). Аим камеры работает.", 6)
    elseif not XSendOld then
        Library:Notify("Silent Aim: хук не установлен (нужен hookfunction).", 6)
    end
end)

-- =========================================================================
-- [ ЕДИНЫЙ RENDER CYCLE — ВСЁ ЗДЕСЬ ]
-- =========================================================================

local originalWalkSpeed = 16
local esplastCheck = 0

connect(RunService.RenderStepped, function()
    local now = tick()
    local vp = Camera.ViewportSize
    local center = vp / 2
    local teamCheck = getToggle("ESPTeamCheck")
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

    -- ============ AIM FOV CIRCLES ============
    pcall(function()
        AimbotFovCircle.Position = center
        AimbotFovCircle.Radius   = getOption("AimbotFOV", 200)
        AimbotFovCircle.Color    = getOption("AimbotFovColor", Color3.fromRGB(0,217,163))
        AimbotFovCircle.Visible  = getToggle("AimbotEnabled") and getToggle("AimbotDrawFOV")

        SilentFovCircle.Position = center
        SilentFovCircle.Radius   = getOption("SilentFOV", 150)
        SilentFovCircle.Color    = getOption("SilentFovColor", Color3.fromRGB(255,100,60))
        SilentFovCircle.Visible  = getToggle("SilentAim") and getToggle("SilentDrawFOV")
    end)

    -- ============ AIMBOT ============
    if getToggle("AimbotEnabled") then
        pcall(function()
            local t = FindAimbotTarget()
            if t and t.part and t.part.Parent then
                local pos = t.part.Position
                local vel = t.part.AssemblyLinearVelocity
                if vel and vel.Magnitude > 1 then
                    local d = (pos - Camera.CFrame.Position).Magnitude
                    pos = pos + vel * (d / 2000)
                end
                local lookAt = CFrame.new(Camera.CFrame.Position, pos)
                if getToggle("AimbotSnap") then
                    Camera.CFrame = lookAt
                else
                    local smooth = getOption("AimbotSmooth", 15) / 100
                    Camera.CFrame = Camera.CFrame:Lerp(lookAt, math.clamp(smooth, 0.05, 1))
                end
            end
        end)
    end

    -- ============ SILENT TARGET UPDATE ============
    if getToggle("SilentAim") then
        local t = FindSilentTarget()
        SilentTarget = t and t.part or nil
    elseif not getToggle("SilentAim") then
        SilentTarget = nil
    end

    -- ============ ESP ============
    if getToggle("ESPEnabled") then
        -- Ленивый makeESP для уже существующих игроков
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and not ESPCache[p] and p.Character then
                makeESP(p)
            end
        end

        local showBox = getToggle("ESPBox")
        local showName = getToggle("ESPName")
        local showHP = getToggle("ESPHealth")
        local showDist = getToggle("ESPDistance")
        local showWep = getToggle("ESPWeapon")
        local showTracer = getToggle("ESPTracer")
        local colBox = getOption("ESPBoxColor", Color3.fromRGB(0,217,163))
        local colName = getOption("ESPNameColor", Color3.fromRGB(255,255,255))
        local colTracer = getOption("ESPTracerColor", Color3.fromRGB(0,217,163))

        for player, data in pairs(ESPCache) do
            local char = data.char
            if not char or not char.Parent then
                destroyESP(player)
            else
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then
                    data.bb.Enabled = false
                    data.tracer.Visible = false
                    data.boxFrame.Visible = false
                    data.hpBg.Visible = false
                    data.name.Visible = false
                    data.dist.Visible = false
                    data.wep.Visible = false
                    if data.skel then for _, l in ipairs(data.skel) do l.Visible = false end end
                else
                    local skip = false
                    if char == LP.Character then skip = true end
                    local tgt = getOption("ESPTargets", "Все")
                    local ally = isAlly(char)
                    if tgt == "Только враги" and ally then skip = true end
                    if tgt == "Только союзники" and not ally then skip = true end
                    if teamCheck and ally and tgt ~= "Только союзники" then skip = true end

                    data.bb.Enabled = not skip
                    if skip then
                        data.tracer.Visible = false
                    else
                        data.boxFrame.Visible = showBox
                        data.boxStroke.Color = colBox

                        data.hpBg.Visible = showHP
                        if showHP then
                            local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            data.hpFill.Size = UDim2.new(1, 0, pct, 0)
                            data.hpFill.BackgroundColor3 = getOption("ESPHealthBottom", Color3.fromRGB(255,60,60)):Lerp(
                                getOption("ESPHealthTop", Color3.fromRGB(0,220,120)), pct)
                        end

                        data.name.Visible = showName
                        if showName then
                            data.name.Text = player.Name
                            data.name.TextColor3 = colName
                        end

                        data.dist.Visible = showDist
                        if showDist and myRoot then
                            data.dist.Text = string.format("%dm", math.floor((myRoot.Position - hrp.Position).Magnitude))
                        end

                        data.wep.Visible = showWep
                        if showWep then
                            local w = "None"
                            for _, t in ipairs(char:GetChildren()) do
                                if t:IsA("Tool") then w = t.Name break end
                            end
                            data.wep.Text = "[" .. w .. "]"
                        end

                        if getToggle("ESPSkeleton") and data.skel then
                            local bones = char:FindFirstChild("UpperTorso") and SKEL_R15 or SKEL_R6
                            local colSk = getOption("ESPSkeletonColor", Color3.fromRGB(255,255,255))
                            for i, b in ipairs(bones) do
                                local line = data.skel[i]
                                if not line then break end
                                local pA, pB = char:FindFirstChild(b[1]), char:FindFirstChild(b[2])
                                if pA and pB then
                                    local a, va = Camera:WorldToViewportPoint(pA.Position)
                                    local bpos, vb = Camera:WorldToViewportPoint(pB.Position)
                                    if va and vb then
                                        line.From = Vector2.new(a.X, a.Y)
                                        line.To = Vector2.new(bpos.X, bpos.Y)
                                        line.Color = colSk
                                        line.Visible = true
                                    else line.Visible = false end
                                else line.Visible = false end
                            end
                            for i = #bones + 1, #data.skel do data.skel[i].Visible = false end
                        elseif data.skel then
                            for _, l in ipairs(data.skel) do l.Visible = false end
                        end

                        if showTracer then
                            local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                            if on then
                                local origin = Vector2.new(vp.X / 2, vp.Y)
                                local mode = getOption("ESPTracerOrigin", "Bottom")
                                if mode == "Center" then origin = center
                                elseif mode == "Top" then origin = Vector2.new(vp.X/2, 0)
                                elseif mode == "Mouse" then
                                    local m = UserInputService:GetMouseLocation()
                                    origin = Vector2.new(m.X, m.Y)
                                end
                                local target = Vector2.new(sp.X, sp.Y)
                                local diff = target - origin
                                data.tracer.BackgroundColor3 = colTracer
                                data.tracer.Size = UDim2.fromOffset(diff.Magnitude, 1.5)
                                data.tracer.Position = UDim2.fromOffset(origin.X, origin.Y)
                                data.tracer.Rotation = math.deg(math.atan2(diff.Y, diff.X))
                                data.tracer.Visible = true
                            else
                                data.tracer.Visible = false
                            end
                        else
                            data.tracer.Visible = false
                        end
                    end
                end
            end
        end
    else
        for player in pairs(ESPCache) do destroyESP(player) end
    end

    -- ============ CHAMS ============
    if getToggle("ChamsEnabled") then
        local teamChk = getToggle("ChamsTeamCheck")
        local colVis = getOption("ChamsVisibleColor", Color3.fromRGB(0,220,120))
        local colUnvis = getOption("ChamsOccludedColor", Color3.fromRGB(255,60,60))
        local fillTr = getOption("ChamsFillTransparency", 0.5)
        local outTr = getOption("ChamsOutlineTransparency", 0.2)

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local char = p.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    if not (teamChk and isAlly(char)) then
                        if not ChamsHighlights[char] then
                            local hv = Instance.new("Highlight")
                            hv.Name = "DxHub_Chams_Vis"
                            hv.DepthMode = Enum.HighlightDepthMode.Occluded
                            hv.Adornee = char
                            hv.Parent = char
                            local hu = Instance.new("Highlight")
                            hu.Name = "DxHub_Chams_Unvis"
                            hu.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            hu.Adornee = char
                            hu.Parent = char
                            ChamsHighlights[char] = { visible = hv, unvisible = hu }
                            char.AncestryChanged:Connect(function(_, np)
                                if np == nil then removeChams(char) end
                            end)
                        end

                        local h = ChamsHighlights[char]
                        local root = char:FindFirstChild("HumanoidRootPart")
                        RayParamsAim.FilterDescendantsInstances = {LP.Character, char}
                        local ray = Workspace:Raycast(Camera.CFrame.Position, root.Position - Camera.CFrame.Position, RayParamsAim)
                        local seen = ray == nil

                        h.visible.FillColor = colVis
                        h.visible.OutlineColor = colVis
                        h.visible.FillTransparency = fillTr
                        h.visible.OutlineTransparency = outTr
                        h.visible.Enabled = seen

                        h.unvisible.FillColor = colUnvis
                        h.unvisible.OutlineColor = colUnvis
                        h.unvisible.FillTransparency = fillTr
                        h.unvisible.OutlineTransparency = outTr
                        h.unvisible.Enabled = not seen
                    else
                        if ChamsHighlights[char] then removeChams(char) end
                    end
                end
            end
        end
    else
        for char in pairs(ChamsHighlights) do removeChams(char) end
    end

    -- ============ MOVEMENT ============
    pcall(function()
        local char = LP.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            if root and hum then
                -- Speed
                if getToggle("SpeedEnabled") then
                    hum.WalkSpeed = getOption("WalkSpeed", 22)
                else
                    if hum.WalkSpeed ~= originalWalkSpeed then
                        hum.WalkSpeed = originalWalkSpeed
                    end
                end

                -- Auto Bhop
                if getToggle("AutoBhop") then
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        local rp = RaycastParams.new()
                        rp.FilterDescendantsInstances = {char}
                        rp.FilterType = Enum.RaycastFilterType.Exclude
                        if Workspace:Raycast(root.Position, Vector3.new(0, -4, 0), rp) then
                            hum.Jump = true
                        end
                    end
                    local ok, result = pcall(GetMoveDirection)
                    if ok and result.Magnitude > 0 then
                        local spd = math.clamp(getOption("BhopSpeed", 18), 5, 30)
                        local dir = result * spd
                        local v = root.AssemblyLinearVelocity
                        root.AssemblyLinearVelocity = Vector3.new(
                            v.X + (dir.X - v.X) * 0.2,
                            v.Y,
                            v.Z + (dir.Z - v.Z) * 0.2
                        )
                    end
                end

                -- No Fall Damage
                if getToggle("NoFallDamage") then
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                end
            end
        end
    end)

    -- ============ SKIN CHANGER (реже) ============
    if now - esplastCheck > 0.5 then
        pcall(function()
            if SkinConfig.SkinChanger.Enabled or SkinConfig.KnifeChanger.Enabled then ApplySkin() end
            if SkinConfig.GloveChanger.Enabled then ApplyGloves() end
        end)
        esplastCheck = now
    end
end)


do
-- =========================================================================
-- [ ДОП. МОДУЛИ: из PasteHub, перенесены в DX Hub ]
-- =========================================================================

-- ---------- ВИД ОРУЖИЯ / КАМЕРА ----------
local VisualTab = Tabs.Visuals
local CamBox = VisualTab:AddRightGroupbox("Камера и прицел", "video")
CamBox:AddToggle("CustomFov", { Text = "Своё поле зрения", Default = false })
CamBox:AddSlider("FovValue", { Text = "Поле зрения", Default = 90, Min = 70, Max = 120, Rounding = 0, Suffix = "°" })
CamBox:AddToggle("ThirdPerson", { Text = "Вид от третьего лица", Default = false })
CamBox:AddSlider("ThirdDist", { Text = "Дистанция камеры", Default = 10, Min = 5, Max = 50, Rounding = 1, Suffix = "st" })
CamBox:AddToggle("RemoveScope", { Text = "Убрать прицел снайперки", Default = false })
CamBox:AddToggle("ScopeFov", { Text = "Поле зрения в прицеле", Default = false })
CamBox:AddSlider("ScopeFovValue", { Text = "FOV в прицеле", Default = 70, Min = 10, Max = 100, Rounding = 1, Suffix = "°" })
CamBox:AddToggle("ScopeCross", { Text = "Свой крест в прицеле", Default = false })
CamBox:AddSlider("ScopeThick", { Text = "Толщина креста", Default = 2, Min = 1, Max = 10, Rounding = 1, Suffix = "px" })
CamBox:AddSlider("ScopeLenLR", { Text = "Длина по горизонтали", Default = 150, Min = 0, Max = 1000, Rounding = 0, Suffix = "px" })
CamBox:AddSlider("ScopeLenTB", { Text = "Длина по вертикали", Default = 100, Min = 0, Max = 1000, Rounding = 0, Suffix = "px" })
CamBox:AddLabel("Цвет креста"):AddColorPicker("ScopeCrossColor", { Default = Color3.fromRGB(255, 255, 255) })

local scopeGui = Instance.new("ScreenGui")
scopeGui.Name = "DxHub_Scope"
scopeGui.ResetOnSpawn = false
scopeGui.IgnoreGuiInset = true
pcall(function() scopeGui.Parent = CoreGui end)
local sFrame = Instance.new("Frame", scopeGui)
sFrame.AnchorPoint = Vector2.new(0.5, 0.5)
sFrame.Position = UDim2.fromScale(0.5, 0.5)
sFrame.Size = UDim2.fromOffset(0, 0)
sFrame.BackgroundTransparency = 1
local crossL = Instance.new("Frame", sFrame)
local crossR = Instance.new("Frame", sFrame)
local crossT = Instance.new("Frame", sFrame)
local crossB = Instance.new("Frame", sFrame)
for _, f in ipairs({crossL, crossR, crossT, crossB}) do f.BorderSizePixel = 0 end

local function getScopeFrame()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local ok, f = pcall(function() return pg.MainGui.Gameplay.Middle.SniperScope end)
    return ok and f or nil
end

connect(RunService.RenderStepped, function()
    local cam = Workspace.CurrentCamera
    local scope = getScopeFrame()
    local scoped = scope and scope.Visible

    if getToggle("CustomFov") and cam then
        cam.FieldOfView = getOption("FovValue", 90)
    end
    if getToggle("ThirdPerson") then
        local d = getOption("ThirdDist", 10)
        pcall(function()
            LP.CameraMode = Enum.CameraMode.Classic
            LP.CameraMinZoomDistance = d
            LP.CameraMaxZoomDistance = d
        end)
    end
    if scope then
        if getToggle("RemoveScope") then
            if scoped then scope.Size = UDim2.new(0, 0, 0, 0) else scope.Size = UDim2.new(1, 0, 1, 0) end
        elseif scope.Size ~= UDim2.new(1, 0, 1, 0) then
            scope.Size = UDim2.new(1, 0, 1, 0)
        end
        if getToggle("ScopeFov") and scoped and cam then
            cam.FieldOfView = getOption("ScopeFovValue", 70)
        end
    end

    local show = getToggle("ScopeCross") and scoped
    sFrame.Visible = show
    if show then
        local col = getOption("ScopeCrossColor", Color3.fromRGB(255, 255, 255))
        local th = getOption("ScopeThick", 2)
        local lr = getOption("ScopeLenLR", 150)
        local tb = getOption("ScopeLenTB", 100)
        crossL.BackgroundColor3 = col; crossR.BackgroundColor3 = col
        crossT.BackgroundColor3 = col; crossB.BackgroundColor3 = col
        crossL.AnchorPoint = Vector2.new(1, 0.5); crossL.Position = UDim2.new(0, 0, 0.5, 0)
        crossL.Size = UDim2.new(0, lr, 0, th)
        crossR.AnchorPoint = Vector2.new(0, 0.5); crossR.Position = UDim2.new(0, 0, 0.5, 0)
        crossR.Size = UDim2.new(0, lr, 0, th)
        crossT.AnchorPoint = Vector2.new(0.5, 1); crossT.Position = UDim2.new(0, 0, 0, 0)
        crossT.Size = UDim2.new(0, th, 0, tb)
        crossB.AnchorPoint = Vector2.new(0.5, 0); crossB.Position = UDim2.new(0, 0, 0, 0)
        crossB.Size = UDim2.new(0, th, 0, tb)
    end
end)

-- ---------- ВИЗУАЛЬНЫЕ ЭФФЕКТЫ ОРУЖИЯ: трассеры, попадания ----------
local EffBox = Tabs.Visuals:AddLeftGroupbox("Эффекты выстрелов", "sparkles")
EffBox:AddToggle("ImpactFx", { Text = "Точка попадания", Default = false })
EffBox:AddLabel("Цвет точки"):AddColorPicker("ImpactColor", { Default = Color3.fromRGB(255, 0, 0) })

local function rainbowColor() return Color3.fromHSV((tick() % 5) / 5, 1, 1) end

local function spawnImpact(pos)
    if not getToggle("ImpactFx") or not pos then return end
    local p = Instance.new("Part")
    p.Name = "DxHub_Impact"
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
    p.Size = Vector3.new(0.6, 0.6, 0.6)
    p.Material = Enum.Material.Neon
    p.Color = getOption("ImpactColor", Color3.fromRGB(255, 0, 0))
    p.Position = pos
    p.Parent = Workspace
    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < 3 and p.Parent do
            p.Transparency = (tick() - t0) / 3
            task.wait()
        end
        p:Destroy()
    end)
end

-- ---------- ЗВУК И МАРКЕР ПОПАДАНИЯ ----------
local HitBox = Tabs.Combat:AddRightGroupbox("Попадания", "volume-2")
HitBox:AddToggle("HitSound", { Text = "Звук попадания", Default = false })
HitBox:AddDropdown("HitSoundPreset", {
    Text = "Звук",
    Values = {"Neverlose", "Skeet", "Bell", "Bubble", "Coins", "Pick"},
    Default = "Neverlose",
})
HitBox:AddInput("CustomSoundId", { Text = "Свой звук (ID)", Default = "", Placeholder = "только цифры" })
HitBox:AddSlider("HitVolume", { Text = "Громкость", Default = 1, Min = 0.1, Max = 5, Rounding = 1 })
HitBox:AddToggle("HitMarker", { Text = "Маркер попадания", Default = false })
HitBox:AddLabel("Цвет маркера"):AddColorPicker("HitMarkerColor", { Default = Color3.fromRGB(255, 255, 255) })
HitBox:AddToggle("HitMarkerRainbow", { Text = "Радужный маркер", Default = false })
HitBox:AddSlider("HitMarkerSize", { Text = "Размер маркера", Default = 25, Min = 5, Max = 50, Rounding = 0, Suffix = "px" })
HitBox:AddSlider("HitMarkerTime", { Text = "Длительность маркера", Default = 2, Min = 0.5, Max = 5, Rounding = 1, Suffix = "с" })

local HIT_SOUNDS = {
    ["Neverlose"] = "rbxassetid://139452805868562",
    ["Skeet"]     = "rbxassetid://83717596220569",
    ["Bell"]      = "rbxassetid://96481309571950",
    ["Bubble"]    = "rbxassetid://104824514322839",
    ["Coins"]     = "rbxassetid://5613553529",
    ["Pick"]      = "rbxassetid://8616930816",
}

local function playHitSound()
    if not getToggle("HitSound") then return end
    local id = HIT_SOUNDS[getOption("HitSoundPreset", "Neverlose")] or HIT_SOUNDS.Neverlose
    local custom = string.gsub(getOption("CustomSoundId", ""), "%D", "")
    if custom ~= "" then id = "rbxassetid://" .. custom end
    local snd = Instance.new("Sound")
    snd.SoundId = id
    snd.Volume = getOption("HitVolume", 1)
    snd.Parent = CoreGui
    snd:Play()
    task.delay(4, function() snd:Destroy() end)
end

local markers = {}
local function addHitMarker(pos)
    if not getToggle("HitMarker") then return end
    table.insert(markers, {pos = pos, t0 = tick(), lines = {}})
    local m = markers[#markers]
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 2
        l.Transparency = 1
        l.Visible = false
        m.lines[i] = l
    end
end

connect(RunService.RenderStepped, function()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = tick()
    local col = getToggle("HitMarkerRainbow") and rainbowColor() or getOption("HitMarkerColor", Color3.fromRGB(255, 255, 255))
    local size = getOption("HitMarkerSize", 25)
    local life = getOption("HitMarkerTime", 2)
    for i = #markers, 1, -1 do
        local m = markers[i]
        local age = now - m.t0
        if age > life or not getToggle("HitMarker") then
            for _, l in ipairs(m.lines) do pcall(function() l:Remove() end) end
            table.remove(markers, i)
        else
            local sp, on = cam:WorldToViewportPoint(m.pos)
            for j = 1, 4 do
                local l = m.lines[j]
                if on then
                    local ang = math.rad((age * 360) % 360 + (j - 1) * 90)
                    local c, s = math.cos(ang), math.sin(ang)
                    l.From = Vector2.new(sp.X + c * 6, sp.Y + s * 6)
                    l.To = Vector2.new(sp.X + c * (6 + size), sp.Y + s * (6 + size))
                    l.Color = col
                    l.Visible = true
                else l.Visible = false end
            end
        end
    end
end)

-- хук выстрелов (только визуалы; вход в стрельбу не трогаем)
pcall(function()
    local GC = getgc or get_gc_objects
    local sendFn
    for _, obj in next, GC(true) do
        if type(obj) == "table" and rawget(obj, "shoot") and typeof(obj.shoot) == "function" then
            pcall(function()
                for _, uv in pairs(debug.getupvalues(obj.shoot)) do
                    if type(uv) == "table" and rawget(uv, "Inventory") and rawget(uv.Inventory, "ShootWeapon") then
                        sendFn = uv.Inventory.ShootWeapon.Send
                    end
                end
            end)
        end
    end
    if sendFn and typeof(hookfunction) == "function" then
        local old
        old = hookfunction(sendFn, function(...)
            local args = {...}
            pcall(function()
                local cam = Workspace.CurrentCamera
                if args[1] and type(args[1].Bullets) == "table" then
                    for _, bullet in pairs(args[1].Bullets) do
                        if type(bullet.Hits) == "table" then
                            for _, hit in pairs(bullet.Hits) do
                                if hit.Position then
                                                                        spawnImpact(hit.Position)
                                    playHitSound()
                                    addHitMarker(hit.Position)
                                end
                            end
                        end
                    end
                end
            end)
            return old(...)
        end)
    end
end)

-- ---------- ЧАМСЫ V2 (видимые / за стеной, цвет и материал) ----------
local ChamsV2 = Tabs.Visuals:AddRightGroupbox("Чамсы (продвинутые)", "layers")
ChamsV2:AddToggle("Chams2", { Text = "Включить", Default = false })
ChamsV2:AddToggle("Chams2Team", { Text = "Проверка команды", Default = true })
ChamsV2:AddDropdown("Chams2MatVis", { Text = "Материал (видно)", Values = {"Neon", "Metal", "ForceField", "SmoothPlastic"}, Default = "Neon" })
ChamsV2:AddLabel("Цвет (видно)"):AddColorPicker("Chams2ColVis", { Default = Color3.fromRGB(0, 200, 0) })
ChamsV2:AddDropdown("Chams2MatHid", { Text = "Материал (за стеной)", Values = {"Neon", "Metal", "ForceField", "SmoothPlastic"}, Default = "Metal" })
ChamsV2:AddLabel("Цвет (за стеной)"):AddColorPicker("Chams2ColHid", { Default = Color3.fromRGB(200, 0, 0) })
ChamsV2:AddSlider("Chams2Fill", { Text = "Прозрачность заливки", Default = 0.3, Min = 0, Max = 1, Rounding = 2 })
ChamsV2:AddSlider("Chams2Out", { Text = "Прозрачность контура", Default = 0, Min = 0, Max = 1, Rounding = 2 })

local CHAM_MATS = {Neon = Enum.Material.Neon, Metal = Enum.Material.Metal,
    ForceField = Enum.Material.ForceField, SmoothPlastic = Enum.Material.SmoothPlastic}
local chamRay = RaycastParams.new()
chamRay.FilterType = Enum.RaycastFilterType.Exclude
local chamHL = {}
local chamOrig = {}

local function chamVisible(char)
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not root then return false end
    local camPos = Workspace.CurrentCamera.CFrame.Position
    chamRay.FilterDescendantsInstances = {LP.Character, char}
    return Workspace:Raycast(camPos, root.Position - camPos, chamRay) == nil
end

connect(RunService.RenderStepped, function()
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then return end
    local on = getToggle("Chams2")
    local teamChk = getToggle("Chams2Team")
    for char, hl in pairs(chamHL) do
        if not char.Parent or not on then
            for _, h in pairs(hl) do pcall(function() h:Destroy() end) end
            chamHL[char] = nil
            for part, o in pairs(chamOrig[char] or {}) do
                if part.Parent then part.Material, part.Color = o[1], o[2] end
            end
            chamOrig[char] = nil
        end
    end
    if not on then return end
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj ~= LP.Character then
            if teamChk and isAlly(obj) then
                if chamHL[obj] then
                    for _, h in pairs(chamHL[obj]) do pcall(function() h:Destroy() end) end
                    chamHL[obj] = nil
                end
                continue
            end
            if not chamHL[obj] then
                local vis = Instance.new("Highlight")
                vis.DepthMode = Enum.HighlightDepthMode.Occluded
                vis.Adornee = obj
                vis.Parent = obj
                local hid = Instance.new("Highlight")
                hid.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hid.Adornee = obj
                hid.Parent = obj
                chamHL[obj] = {vis = vis, hid = hid}
            end
            local hl = chamHL[obj]
            local seen = chamVisible(obj)
            local cV = getOption("Chams2ColVis", Color3.fromRGB(0, 200, 0))
            local cH = getOption("Chams2ColHid", Color3.fromRGB(200, 0, 0))
            local fill, out = getOption("Chams2Fill", 0.3), getOption("Chams2Out", 0)
            hl.vis.FillColor, hl.vis.OutlineColor = cV, cV
            hl.vis.FillTransparency, hl.vis.OutlineTransparency = fill, out
            hl.vis.Enabled = seen
            hl.hid.FillColor, hl.hid.OutlineColor = cH, cH
            hl.hid.FillTransparency, hl.hid.OutlineTransparency = fill, out
            hl.hid.Enabled = not seen
        end
    end
end)

-- ---------- НОЧЬ / НЕБО / ПОГОДА / АТМОСФЕРА ----------
local WorldMod = Tabs.World and Tabs.World or Tabs.Visuals
local SkyBox = WorldMod:AddLeftGroupbox("Небо и погода", "cloud")
local SKY = {
    ["Ночь"]      = {"1514717643","1514716936","1514715910","1514714945","1514714011","1514713374"},
    ["Закат"]     = {"17525686840","17525678473","17525684686","17525680663","17525682665","17525674545"},
    ["Космос"]    = {"159248188","159248183","159248187","159248173","159248192","159248176"},
    ["Облака"]    = {"252760981","252763035","252761439","252760980","252760986","252762652"},
    ["Розовое"]   = {"7890140060","7890140060","7890140060","7890140060","7890140060","7890140060"},
}
local skyNames = {"Ночь", "Закат", "Космос", "Облака", "Розовое"}
SkyBox:AddToggle("SkyOn", { Text = "Своё небо", Default = false })
SkyBox:AddDropdown("SkyPreset", { Text = "Небо", Values = skyNames, Default = "Ночь" })
SkyBox:AddDropdown("Weather", { Text = "Погода", Values = {"Нет", "Дождь", "Снег"}, Default = "Нет" })
SkyBox:AddToggle("AtmoOn", { Text = "Атмосфера (туман)", Default = false })
SkyBox:AddSlider("AtmoDensity", { Text = "Плотность атмосферы", Default = 30, Min = 0, Max = 100, Rounding = 0, Suffix = "%" })
SkyBox:AddLabel("Цвет атмосферы"):AddColorPicker("AtmoColor", { Default = Color3.fromRGB(199, 199, 199) })
SkyBox:AddToggle("TimeOn", { Text = "Своё время суток", Default = false })
SkyBox:AddSlider("TimeVal", { Text = "Время", Default = 12, Min = 0, Max = 24, Rounding = 1, Suffix = "ч" })

local skyObj
local lastSky
local function applySky(name)
    local ids = SKY[name]
    if not ids then return end
    skyObj = skyObj or Instance.new("Sky")
    skyObj.Name = "DxHub_Sky"
    skyObj.Parent = Lighting
    skyObj.SkyboxBk = "rbxassetid://" .. ids[1]
    skyObj.SkyboxDn = "rbxassetid://" .. ids[2]
    skyObj.SkyboxFt = "rbxassetid://" .. ids[3]
    skyObj.SkyboxLf = "rbxassetid://" .. ids[4]
    skyObj.SkyboxRt = "rbxassetid://" .. ids[5]
    skyObj.SkyboxUp = "rbxassetid://" .. ids[6]
end

local weatherPart
local function setWeather(name)
    if weatherPart then weatherPart:Destroy(); weatherPart = nil end
    if name == "Нет" then return end
    weatherPart = Instance.new("Part")
    weatherPart.Anchored, weatherPart.CanCollide, weatherPart.Transparency = true, false, 1
    weatherPart.Size = Vector3.new(100, 1, 100)
    weatherPart.Parent = Workspace.CurrentCamera
    local em = Instance.new("ParticleEmitter", weatherPart)
    em.EmissionDirection = Enum.NormalId.Bottom
    if name == "Дождь" then
        em.Texture = "rbxassetid://241868005"
        em.Rate = 4000
        em.Size = NumberSequence.new(3, 6)
        em.Lifetime = NumberRange.new(2, 2.5)
        em.Speed = NumberRange.new(80, 100)
        em.Acceleration = Vector3.new(0, -50, 0)
    else
        em.Texture = "rbxassetid://99851851"
        em.Rate = 150
        em.Size = NumberSequence.new(0.25, 0.35)
        em.Lifetime = NumberRange.new(5, 10)
        em.Speed = NumberRange.new(30, 30)
        em.SpreadAngle = Vector2.new(50, 50)
    end
end

connect(RunService.RenderStepped, function()
    if getToggle("SkyOn") then
        local name = getOption("SkyPreset", "Ночь")
        if lastSky ~= name then lastSky = name; applySky(name) end
    elseif skyObj then
        skyObj:Destroy(); skyObj = nil; lastSky = nil
    end
    if weatherPart and weatherPart.Parent and Workspace.CurrentCamera then
        weatherPart.CFrame = Workspace.CurrentCamera.CFrame * CFrame.new(0, 30, 0)
    end
    if getToggle("AtmoOn") then
        local at = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
        at.Density = getOption("AtmoDensity", 30) / 100
        at.Color = getOption("AtmoColor", Color3.fromRGB(199, 199, 199))
    else
        local at = Lighting:FindFirstChildOfClass("Atmosphere")
        if at then at:Destroy() end
    end
    if getToggle("TimeOn") then
        Lighting.ClockTime = getOption("TimeVal", 12)
    end
end)

-- погода: перерисовываем только при смене варианта (в callback, без спама)
Options.Weather:OnChanged(function(v) setWeather(v) end)

-- ---------- БЫСТРАЯ ПЕРЕЗАРЯДКА ----------
local ReloadBox = Tabs.Misc:AddRightGroupbox("Перезарядка", "rotate-cw")
ReloadBox:AddToggle("InstantReload", { Text = "Быстрая перезарядка", Default = false })
local RELOAD_ANIMS = {Reload = true, ReloadStart = true, ReloadAction = true, ReloadEnd = true}
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            if not getToggle("InstantReload") then return end
            local IC = require(ReplicatedStorage.Controllers.InventoryController)
            local w = IC.peekCurrentEquippedForMovement and IC.peekCurrentEquippedForMovement()
            if not w or not w.IsReloading then return end
            for _, container in ipairs({w.Viewmodel and w.Viewmodel.Animation, w.CharacterAnimator}) do
                if container and container.Animations then
                    for name, track in pairs(container.Animations) do
                        if RELOAD_ANIMS[name] and track.IsPlaying then track:AdjustSpeed(199) end
                    end
                end
            end
        end)
    end
end)

-- ---------- Выгрузка: убираем всё добавленное ----------
Library:OnUnload(function()
    pcall(function() if skyObj then skyObj:Destroy() end end)
    pcall(function() if weatherPart then weatherPart:Destroy() end end)
    pcall(function() scopeGui:Destroy() end)
    for _, h in pairs(chamHL) do for _, x in pairs(h) do pcall(function() x:Destroy() end) end end
    for _, m in ipairs(markers) do for _, l in ipairs(m.lines) do pcall(function() l:Remove() end) end end
    pcall(function() LP.CameraMode = Enum.CameraMode.LockFirstPerson end)
end)


end

do
-- =========================================================================
-- [ PASTEHUB: ПЕРЕНЕСЕННЫЕ ФУНКЦИИ (скинченджер не затронут) ]
-- =========================================================================

-- ---------- ТЕХ. ХЕЛПЕРЫ PASTEHUB ----------
local MaterialLimits = {
    [Enum.Material.Asphalt] = 0.25, [Enum.Material.Basalt] = 0.25, [Enum.Material.Brick] = 0.25,
    [Enum.Material.Cobblestone] = 0.25, [Enum.Material.Concrete] = 0.25, [Enum.Material.CrackedLava] = 0.25,
    [Enum.Material.DiamondPlate] = 0.25, [Enum.Material.Foil] = 0.25, [Enum.Material.Glacier] = 0.25,
    [Enum.Material.Granite] = 0.25, [Enum.Material.Grass] = 0.25, [Enum.Material.Ground] = 0.25,
    [Enum.Material.Ice] = 0.25, [Enum.Material.LeafyGrass] = 0.25, [Enum.Material.Limestone] = 0.25,
    [Enum.Material.Marble] = 0.25, [Enum.Material.Metal] = 0.25, [Enum.Material.Mud] = 0.25,
    [Enum.Material.Pavement] = 0.25, [Enum.Material.Rock] = 0.25, [Enum.Material.Salt] = 0.25,
    [Enum.Material.Sand] = 0.25, [Enum.Material.Sandstone] = 0.25, [Enum.Material.Slate] = 0.25,
    [Enum.Material.Snow] = 0.25, [Enum.Material.ForceField] = 0.25, [Enum.Material.Neon] = 0.25,
    [Enum.Material.CorrodedMetal] = 0.25, [Enum.Material.Pebble] = 0.25, [Enum.Material.CeramicTiles] = 0.25,
    [Enum.Material.Plaster] = 0.25, [Enum.Material.Plastic] = 7, [Enum.Material.SmoothPlastic] = 7,
    [Enum.Material.Wood] = 7, [Enum.Material.WoodPlanks] = 7, [Enum.Material.Cardboard] = 7,
    [Enum.Material.Glass] = 100, [Enum.Material.Fabric] = 100,
}
local MaterialVariantLimits = { ["IndoorWall"] = 0.25, ["Sandy Brick"] = 0.25 }

local function pasteRainbow() return Color3.fromHSV((tick() % 5) / 5, 1, 1) end

-- ---------- ПРОБИВАЕМОСТЬ (пенетрация) ----------
local function GetPenetrationStats(origin, direction, maxPen, ignoreList, targetRoot)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.CollisionGroup = "Bullet"
    local filter = ignoreList or {LP.Character, Workspace.CurrentCamera}
    params.FilterDescendantsInstances = filter
    local currentOrigin, currentDir = origin, direction
    local accMat, accVar = {}, {}
    local stats = {TotalThickness = 0, MaterialStats = {}, Success = false, FailReason = "Max Steps", EndPos = Vector3.zero}
    local backParams = RaycastParams.new()
    backParams.FilterType = Enum.RaycastFilterType.Include
    backParams.CollisionGroup = "Bullet"
    for _ = 1, 100 do
        if not currentOrigin or not currentDir then break end
        local result = Workspace:Raycast(currentOrigin, currentDir * 1000, params)
        if not result then
            if not targetRoot then
                stats.Success = true
                stats.EndPos = currentOrigin + currentDir * 1000
            else
                stats.FailReason = "Void (Missed)"
            end
            break
        end
        if not result.Instance or not result.Instance.Parent then
            stats.FailReason = "Destroyed Instance"
            break
        end
        if targetRoot and result.Instance:IsDescendantOf(targetRoot) then
            stats.Success = true
            stats.EndPos = result.Position
            stats.FailReason = "Hit"
            return stats
        end
        table.insert(filter, result.Instance)
        params.FilterDescendantsInstances = filter
        local enterPos = result.Position
        local fakeEnd = enterPos + currentDir * 1000
        backParams.FilterDescendantsInstances = {result.Instance}
        local backRes = Workspace:Raycast(fakeEnd, enterPos - fakeEnd, backParams)
        local thickness, limit = 0.5, 0.25
        if not backRes then
            thickness = 5
            stats.FailReason = "Infinite/Block"
        else
            thickness = (enterPos - backRes.Position).Magnitude
            local variant = backRes.Instance.MaterialVariant
            if variant ~= "" and MaterialVariantLimits[variant] then
                limit = MaterialVariantLimits[variant]
                accVar[variant] = (accVar[variant] or 0) + thickness
                if accVar[variant] > limit + maxPen then
                    stats.FailReason = string.format("Var: %s (%.1f > %.1f)", variant, accVar[variant], limit + maxPen)
                    return stats
                end
            else
                local mat = backRes.Material
                limit = MaterialLimits[mat] or 0.25
                accMat[mat] = (accMat[mat] or 0) + thickness
                if accMat[mat] > limit + maxPen then
                    stats.FailReason = string.format("%s (%.1f / %.1f)", mat.Name, accMat[mat], limit + maxPen)
                    return stats
                end
            end
            currentOrigin = backRes.Position
        end
        stats.TotalThickness = stats.TotalThickness + thickness
    end
    return stats
end

local penTxt = Drawing.new("Text")
penTxt.Visible = false
penTxt.Center = true
penTxt.Size = 18
penTxt.Font = 2
penTxt.Outline = true

local PenBox = Tabs.Combat:AddRightGroupbox("Пробивание стен", "shield")
PenBox:AddToggle("ShowPenetration", { Text = "Показывать пробиваемость", Default = false })

connect(RunService.RenderStepped, function()
    local cam = Workspace.CurrentCamera
    if not (getToggle("ShowPenetration") and cam) then penTxt.Visible = false; return end
    penTxt.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2 - 70)
    local res = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 1000)
    if not res then penTxt.Visible = false; return end
    local st = GetPenetrationStats(cam.CFrame.Position, cam.CFrame.LookVector, 4, {LP.Character, cam}, nil)
    penTxt.Visible = true
    if st.Success then
        penTxt.Text = string.format("ПРОБИВАЕТСЯ (%.1f st)", st.TotalThickness or 0)
        penTxt.Color = Color3.fromRGB(0, 255, 0)
    else
        penTxt.Text = "НЕ ПРОБИВАЕТСЯ"
        penTxt.Color = Color3.fromRGB(255, 0, 0)
    end
end)

-- ---------- ОРУЖИЕ: ЧАМСЫ НА ВЬЮМОДЕЛИ, ОТТЕНОК, РУКИ ----------
local WeaponChamsBox = Tabs.World:AddRightGroupbox("Чамсы оружия", "eye")
WeaponChamsBox:AddToggle("WeaponChamsEnabled", { Text = "Включить чамсы оружия", Default = false })
    :AddColorPicker("WeaponChamsColor", { Default = Color3.fromRGB(0, 150, 255), Title = "Цвет чамсов" })
WeaponChamsBox:AddDropdown("WeaponChamsMode", {
    Text = "Материал",
    Values = {"Glass", "ForceField", "Metal", "Highlight", "Neon"},
    Default = "Glass",
})
WeaponChamsBox:AddSlider("GlassTransparency", { Text = "Прозрачность стекла", Default = 0.4, Min = 0, Max = 1, Rounding = 2 })
WeaponChamsBox:AddSlider("MetalReflectance", { Text = "Отражение металла", Default = 1.0, Min = 0, Max = 1, Rounding = 1 })

local weaponHL = {}
connect(RunService.RenderStepped, function()
    local on = getToggle("WeaponChamsEnabled")
    local mode = getOption("WeaponChamsMode", "Glass")
    local col = getOption("WeaponChamsColor", Color3.fromRGB(0, 150, 255))
    local wm
    for _, ch in ipairs(Workspace.CurrentCamera:GetChildren()) do
        if ch:IsA("Model") and ch.Name ~= "Viewmodel" and not ch.Name:lower():find("light") then
            local w = ch:FindFirstChild("Weapon") or ch
            if w:IsA("Model") and w.Name ~= "Viewmodel" and not w.Name:lower():find("light") then wm = w; break end
        end
    end
    if not on or not wm then
        for _, h in pairs(weaponHL) do if h.Parent then h:Destroy() end end
        weaponHL = {}
        return
    end
    for _, part in ipairs(wm:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "Hitbox" and part.Name ~= "HumanoidRootPart"
            and not part:FindFirstAncestor("Viewmodel") and not part:FindFirstAncestor("ViewmodelLight") then
            pcall(function()
                if mode == "Highlight" then
                    local h = part:FindFirstChild("DxWeaponHL")
                    if not h then
                        h = Instance.new("Highlight")
                        h.Name = "DxWeaponHL"
                        h.Adornee = part
                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        h.FillTransparency = 0
                        h.OutlineTransparency = 1
                        h.Parent = part
                        weaponHL[part] = h
                    end
                    h.FillColor = col
                else
                    local h = part:FindFirstChild("DxWeaponHL")
                    if h then h:Destroy() end
                    if mode == "Glass" then
                        part.Material = Enum.Material.Glass
                        part.Color = col
                        part.Transparency = getOption("GlassTransparency", 0.4)
                    elseif mode == "ForceField" then
                        part.Material = Enum.Material.ForceField
                        part.Color = col
                        part.Transparency = 0
                    elseif mode == "Metal" then
                        part.Material = Enum.Material.Metal
                        part.Color = col
                        part.Reflectance = getOption("MetalReflectance", 1.0)
                        part.Transparency = 0
                    elseif mode == "Neon" then
                        part.Material = Enum.Material.Neon
                        part.Color = col
                        part.Transparency = 0
                    end
                end
            end)
        end
    end
end)

-- ---------- ПОЛОЖЕНИЕ РУК ----------
local HandsBox = Tabs.World:AddRightGroupbox("Положение рук", "hand")
HandsBox:AddToggle("CustomHands", { Text = "Своё положение рук", Default = false })
HandsBox:AddSlider("HandsX", { Text = "X", Default = 0.2, Min = -2, Max = 2, Rounding = 3, Suffix = "st" })
HandsBox:AddSlider("HandsY", { Text = "Y", Default = -0.155, Min = -2, Max = 2, Rounding = 3, Suffix = "st" })
HandsBox:AddSlider("HandsZ", { Text = "Z", Default = 0.075, Min = -2, Max = 2, Rounding = 3, Suffix = "st" })
connect(RunService.RenderStepped, function()
    if not getToggle("CustomHands") then return end
    local v = Vector3.new(getOption("HandsX", 0.2), getOption("HandsY", -0.155), getOption("HandsZ", 0.075))
    for _, ch in ipairs(Workspace.CurrentCamera:GetChildren()) do
        if ch:IsA("Model") then
            local st = ch:FindFirstChild("Stats")
            local d = st and st:FindFirstChild("Default")
            if d and d:IsA("Vector3Value") then d.Value = v end
        end
    end
end)

-- ---------- ЗОНЫ ДЫМА И МОЛОТОВА (кольцо на земле) ----------
local ZoneBox = Tabs.Visuals:AddRightGroupbox("Зоны гранат", "flame")
ZoneBox:AddToggle("MolotovZone", { Text = "Зона молотова", Default = false })
    :AddColorPicker("MolotovZoneColor", { Default = Color3.fromRGB(255, 60, 0) })
ZoneBox:AddToggle("GrenadeTracers", { Text = "Траектория гранат", Default = false })
    :AddColorPicker("GrenadeTracerColor", { Default = Color3.fromRGB(255, 100, 0) })

local ZONE_SEG = 40
local zones = {}
local function zoneBounds(parent)
    local sx, sz, n, miny = 0, 0, 0, math.huge
    local parts = {}
    for _, v in ipairs(parent:GetChildren()) do
        if v:IsA("BasePart") then
            n += 1; sx += v.Position.X; sz += v.Position.Z
            miny = math.min(miny, v.Position.Y - v.Size.Y / 2)
            parts[#parts + 1] = v
        end
    end
    if n == 0 then return nil end
    local cx, cz = sx / n, sz / n
    local maxR = 1.2
    for _, p in ipairs(parts) do
        local r = math.sqrt((p.Position.X - cx) ^ 2 + (p.Position.Z - cz) ^ 2) + math.max(p.Size.X, p.Size.Z) / 2
        if r > maxR then maxR = r end
    end
    return Vector3.new(cx, miny, cz), maxR
end

local function makeRing(parent, isMolotov)
    if zones[parent] then return end
    local segs = {}
    for i = 1, ZONE_SEG do
        local p = Instance.new("Part")
        p.Name = "DxZoneSeg"
        p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
        p.Material = Enum.Material.Neon
        p.Shape = Enum.PartType.Cylinder
        p.Size = Vector3.new(0.3, 0.3, 0.3)
        p.Transparency = 1
        p.Parent = Workspace
        segs[i] = p
    end
    zones[parent] = {segs = segs, molotov = isMolotov, t0 = tick()}
    parent.AncestryChanged:Connect(function(_, np)
        if np == nil then
            local z = zones[parent]
            if z then
                for _, s in ipairs(z.segs) do pcall(function() s:Destroy() end) end
                zones[parent] = nil
            end
        end
    end)
end

local function scanZones(root)
    for _, obj in ipairs(root:GetChildren()) do
        local n = obj.Name:lower()
        local isM = n:find("molotov") or n:find("firezone") or n:find("fire_zone") or n:find("burnzone")
        if isM and getToggle("MolotovZone") then makeRing(obj, true) end
    end
end

task.spawn(function()
    task.wait(1)
    while task.wait(2) do pcall(function() scanZones(Workspace) end) end
end)

connect(RunService.RenderStepped, function()
    local now = tick()
    for parent, z in pairs(zones) do
        local alive = parent.Parent ~= nil
        local onM = getToggle("MolotovZone")
        local enabled = z.molotov and onM
        local c, r = zoneBounds(parent)
        if not c or not alive then
            for _, s in ipairs(z.segs) do s.Transparency = 1 end
        else
            local col = getOption("MolotovZoneColor", Color3.fromRGB(255, 60, 0))
            local fade = math.clamp((now - z.t0) / 0.4, 0, 1)
            for i, seg in ipairs(z.segs) do
                local a1 = (2 * math.pi) * ((i - 1) / ZONE_SEG)
                local a2 = (2 * math.pi) * (i / ZONE_SEG)
                local pA = c + Vector3.new(math.cos(a1) * r, 0.3, math.sin(a1) * r)
                local pB = c + Vector3.new(math.cos(a2) * r, 0.3, math.sin(a2) * r)
                local d = pB - pA
                local len = d.Magnitude
                if len > 0.01 then
                    seg.Size = Vector3.new(len, 0.28, 0.28)
                    seg.CFrame = CFrame.lookAt((pA + pB) / 2, (pA + pB) / 2 + d) * CFrame.Angles(0, math.rad(90), 0)
                end
                seg.Color = col
                seg.Transparency = enabled and (1 - fade) or 1
            end
        end
    end
end)

-- ---------- ТРАЕКТОРИЯ ГРАНАТ ----------
local GRENADE_WORDS = {"grenade", "flash", "molotov", "bang", "frag", "incendiary", "decoy", "nade", "throwable"}
local GRENADE_BAD = {"gun", "rifle", "pistol", "bullet", "casing", "light", "muzzle", "arm", "leg", "torso", "head", "humanoid"}
local tracked = setmetatable({}, {__mode = "k"})

local function isGrenadeName(obj)
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return false end
    local n = obj.Name:lower()
    for _, b in ipairs(GRENADE_BAD) do if n:find(b) then return false end end
    for _, w in ipairs(GRENADE_WORDS) do if n:find(w) then return true end end
    return false
end

local function trackGrenade(obj)
    if tracked[obj] then return end
    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
    if not part or part.Size.Magnitude > 8 then return end
    if Players:GetPlayerFromCharacter(obj) or Players:GetPlayerFromCharacter(obj.Parent) then return end
    tracked[obj] = {part = part, hist = {}, lines = {}}
    for i = 1, 30 do
        local l = Drawing.new("Line")
        l.Thickness, l.Transparency, l.Visible = 2, 1, false
        tracked[obj].lines[i] = l
    end
end

connect(RunService.RenderStepped, function()
    local on = getToggle("GrenadeTracers")
    local cam = Workspace.CurrentCamera
    for obj, t in pairs(tracked) do
        if not obj.Parent or not t.part.Parent then
            for _, l in ipairs(t.lines) do pcall(function() l:Remove() end) end
            tracked[obj] = nil
        elseif on then
            table.insert(t.hist, 1, t.part.Position)
            if #t.hist > 31 then table.remove(t.hist) end
            local col = getOption("GrenadeTracerColor", Color3.fromRGB(255, 100, 0))
            for i = 1, 30 do
                local l, p1, p2 = t.lines[i], t.hist[i], t.hist[i + 1]
                if p1 and p2 then
                    local s1, o1 = cam:WorldToViewportPoint(p1)
                    local s2, o2 = cam:WorldToViewportPoint(p2)
                    if (o1 or o2) and s1.Z > 0 and s2.Z > 0 then
                        l.From = Vector2.new(s1.X, s1.Y); l.To = Vector2.new(s2.X, s2.Y)
                        l.Color = col; l.Visible = true
                    else l.Visible = false end
                else l.Visible = false end
            end
        else
            for _, l in ipairs(t.lines) do l.Visible = false end
        end
    end
end)

task.spawn(function()
    task.wait(0.5)
    while task.wait(0.5) do
        pcall(function()
            for _, obj in ipairs(Workspace:GetChildren()) do
                if isGrenadeName(obj) then trackGrenade(obj) end
            end
            local dbr = Workspace:FindFirstChild("Debris") or Workspace:FindFirstChild("Effects")
            if dbr then
                for _, obj in ipairs(dbr:GetChildren()) do
                    if isGrenadeName(obj) then trackGrenade(obj) end
                end
            end
        end)
    end
end)

-- ---------- ХИТМАРКЕР / ЗВУК ПОПАДАНИЯ / ТРАССЕРЫ ПУЛЬ ----------
local ShotBox = Tabs.Weapons:AddRightGroupbox("Визуал выстрелов", "crosshair")
ShotBox:AddToggle("BulletImpacts", { Text = "Точка попадания", Default = false })
    :AddColorPicker("BulletImpactsColor", { Default = Color3.fromRGB(255, 0, 0) })

ShotBox:AddToggle("HitSoundEnabled", { Text = "Звук попадания", Default = false })
ShotBox:AddToggle("CustomHitSoundToggle", { Text = "Свой звук", Default = false })
ShotBox:AddInput("CustomHitSoundID", { Text = "ID звука", Default = "", Placeholder = "rbxassetid://..." })
ShotBox:AddDropdown("HitSoundPreset", {
    Text = "Звук",
    Values = {"Neverlose", "Skeet", "Bell", "Bell2", "Bubble", "Rust", "Agro1", "Agro2", "Coins", "Schaater", "Pick"},
    Default = "Neverlose",
})
ShotBox:AddSlider("HitSoundVolume", { Text = "Громкость звука", Default = 1, Min = 0.1, Max = 5, Rounding = 1, Suffix = "x" })

local HIT_PRESETS = {
    Neverlose = "rbxassetid://139452805868562", Skeet = "rbxassetid://83717596220569",
    Bell = "rbxassetid://96481309571950", Bell2 = "rbxassetid://124010691633262",
    Bubble = "rbxassetid://104824514322839", Rust = "rbxassetid://1255040462",
    Agro1 = "rbxassetid://132463144859699", Agro2 = "rbxassetid://102651850556408",
    Coins = "rbxassetid://5613553529", Schaater = "rbxassetid://17405655409", Pick = "rbxassetid://8616930816",
}

local function playHit()
    if not getToggle("HitSoundEnabled") then return end
    local id = HIT_PRESETS[getOption("HitSoundPreset", "Neverlose")] or HIT_PRESETS.Neverlose
    if getToggle("CustomHitSoundToggle") then
        local raw = getOption("CustomHitSoundID", "")
        if raw ~= "" then
            id = raw:find("rbxassetid://") and raw or ("rbxassetid://" .. string.gsub(raw, "%D", ""))
        end
    end
    local snd = Instance.new("Sound")
    snd.SoundId = id
    snd.Volume = getOption("HitSoundVolume", 1)
    snd.Parent = CoreGui
    snd:Play()
    task.delay(4, function() snd:Destroy() end)
end

local function spawnImpact(pos)
    if not getToggle("BulletImpacts") then return end
    local p = Instance.new("Part")
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
    p.Size = Vector3.new(0.6, 0.6, 0.6)
    p.Material = Enum.Material.Neon
    p.Color = getOption("BulletImpactsColor", Color3.fromRGB(255, 0, 0))
    p.Position = pos
    p.Parent = Workspace
    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < 3 and p.Parent do
            p.Transparency = (tick() - t0) / 3
            task.wait()
        end
        p:Destroy()
    end)
end

local HitMarkerBox = Tabs.Weapons:AddRightGroupbox("Маркер попадания", "crosshair")
HitMarkerBox:AddToggle("HitMarkerEnabled", { Text = "Маркер попадания", Default = false })
    :AddColorPicker("HitMarkerColor", { Default = Color3.fromRGB(255, 255, 255) })
HitMarkerBox:AddToggle("HitMarkerRainbow", { Text = "Радужный маркер", Default = false })
HitMarkerBox:AddSlider("HitMarkerDuration", { Text = "Длительность", Default = 2, Min = 0.5, Max = 5, Rounding = 1, Suffix = "с" })
HitMarkerBox:AddSlider("HitMarkerSpinSpeed", { Text = "Скорость вращения", Default = 720, Min = 0, Max = 1440, Rounding = 0, Suffix = "°/с" })
HitMarkerBox:AddSlider("HitMarkerSize", { Text = "Размер", Default = 25, Min = 5, Max = 50, Rounding = 0, Suffix = "px" })
HitMarkerBox:AddSlider("HitMarkerThickness", { Text = "Толщина", Default = 2, Min = 1, Max = 6, Rounding = 1, Suffix = "px" })

local hitMarkers = {}
local function addHitMarker(pos)
    if not getToggle("HitMarkerEnabled") then return end
    local lines = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = getOption("HitMarkerThickness", 2)
        l.Transparency = 1
        l.Visible = false
        lines[i] = l
    end
    table.insert(hitMarkers, {lines = lines, pos = pos, t0 = tick(), dur = getOption("HitMarkerDuration", 2)})
end

connect(RunService.RenderStepped, function()
    local cam = Workspace.CurrentCamera
    local now = tick()
    local col = getToggle("HitMarkerRainbow") and pasteRainbow() or getOption("HitMarkerColor", Color3.fromRGB(255, 255, 255))
    local size = getOption("HitMarkerSize", 25)
    local spin = getOption("HitMarkerSpinSpeed", 720)
    for i = #hitMarkers, 1, -1 do
        local m = hitMarkers[i]
        local age = now - m.t0
        if age > m.dur or not getToggle("HitMarkerEnabled") then
            for _, l in ipairs(m.lines) do pcall(function() l:Remove() end) end
            table.remove(hitMarkers, i)
        else
            local sp, on = cam:WorldToViewportPoint(m.pos)
            local pulse = 1 + 0.35 * math.sin(now * math.pi)
            for j = 1, 4 do
                local l = m.lines[j]
                if on then
                    local ang = math.rad((age * spin) % 360 + (j - 1) * 90)
                    local c, s = math.cos(ang), math.sin(ang)
                    local g = 6 * pulse
                    l.From = Vector2.new(sp.X + c * g, sp.Y + s * g)
                    l.To = Vector2.new(sp.X + c * (g + size * pulse), sp.Y + s * (g + size * pulse))
                    l.Color = col
                    l.Thickness = getOption("HitMarkerThickness", 2)
                    l.Visible = true
                else l.Visible = false end
            end
        end
    end
end)

-- хук выстрела: только визуальная часть (трассер, точка, звук, маркер). Наводку не меняем.
pcall(function()
    local getgc_ = getgc or get_gc_objects
    if not getgc_ or typeof(hookfunction) ~= "function" then return end
    local sendFn
    for _, obj in next, getgc_(true) do
        if type(obj) == "table" and rawget(obj, "shoot") and typeof(obj.shoot) == "function" then
            pcall(function()
                for _, uv in pairs(debug.getupvalues(obj.shoot)) do
                    if type(uv) == "table" and rawget(uv, "Inventory") and rawget(uv.Inventory, "ShootWeapon") then
                        sendFn = uv.Inventory.ShootWeapon.Send
                    end
                end
            end)
        end
    end
    if not sendFn then return end
    local old
    old = hookfunction(sendFn, function(...)
        local args = {...}
        pcall(function()
            local cam = Workspace.CurrentCamera
            if args[1] and type(args[1].Bullets) == "table" then
                for _, bullet in pairs(args[1].Bullets) do
                    if type(bullet.Hits) == "table" then
                        for _, hit in pairs(bullet.Hits) do
                            if hit.Position then
                                                                spawnImpact(hit.Position)
                                playHit()
                                addHitMarker(hit.Position)
                            end
                        end
                    end
                end
            end
        end)
        return old(...)
    end)
end)

-- ---------- ПРИЦЕЛ СНАЙПЕРКИ: FOV, КРЕСТ, УДАЛЕНИЕ ----------
local ScopeBox = Tabs.World:AddRightGroupbox("Прицел снайперки", "crosshair")
ScopeBox:AddToggle("CustomScopeFov", { Text = "FOV в прицеле", Default = false })
ScopeBox:AddSlider("ScopeFovValue", { Text = "FOV в прицеле", Default = 70, Min = 10, Max = 100, Rounding = 1, Suffix = "°" })
ScopeBox:AddToggle("RemoveScope", { Text = "Убрать прицел", Default = false })
ScopeBox:AddToggle("ScopeCrosshair", { Text = "Свой крест", Default = false })
    :AddColorPicker("ScopeCrosshairColor", { Default = Color3.fromRGB(255, 255, 255) })
ScopeBox:AddSlider("ScopeThick", { Text = "Толщина креста", Default = 2, Min = 1, Max = 10, Rounding = 1, Suffix = "px" })
ScopeBox:AddSlider("ScopeLenLR", { Text = "Длина по горизонтали", Default = 150, Min = 0, Max = 1000, Rounding = 0, Suffix = "px" })
ScopeBox:AddSlider("ScopeLenTB", { Text = "Длина по вертикали", Default = 100, Min = 0, Max = 1000, Rounding = 0, Suffix = "px" })

local scopeGui2 = Instance.new("ScreenGui")
scopeGui2.Name = "DxHub_ScopeCross"
scopeGui2.ResetOnSpawn = false
scopeGui2.IgnoreGuiInset = true
pcall(function() scopeGui2.Parent = CoreGui end)
local cf = Instance.new("Frame", scopeGui2)
cf.AnchorPoint = Vector2.new(0.5, 0.5)
cf.Position = UDim2.fromScale(0.5, 0.5)
cf.Size = UDim2.fromOffset(0, 0)
cf.BackgroundTransparency = 1
local cL, cR, cT, cB = Instance.new("Frame", cf), Instance.new("Frame", cf), Instance.new("Frame", cf), Instance.new("Frame", cf)
for _, f in ipairs({cL, cR, cT, cB}) do f.BorderSizePixel = 0 end

connect(RunService.RenderStepped, function()
    local cam = Workspace.CurrentCamera
    local pg = LP:FindFirstChild("PlayerGui")
    local ok, scope = pcall(function() return pg.MainGui.Gameplay.Middle.SniperScope end)
    scope = ok and scope or nil
    local scoped = scope and scope.Visible
    if scope then
        if getToggle("RemoveScope") then
            scope.Size = scoped and UDim2.new(0, 0, 0, 0) or UDim2.new(1, 0, 1, 0)
        elseif scope.Size ~= UDim2.new(1, 0, 1, 0) then
            scope.Size = UDim2.new(1, 0, 1, 0)
        end
    end
    if getToggle("CustomScopeFov") and scoped and cam then
        cam.FieldOfView = getOption("ScopeFovValue", 70)
    end
    local show = getToggle("ScopeCrosshair") and scoped
    cf.Visible = show
    if show then
        local col = getOption("ScopeCrosshairColor", Color3.fromRGB(255, 255, 255))
        local th = getOption("ScopeThick", 2)
        local lr = getOption("ScopeLenLR", 150)
        local tb = getOption("ScopeLenTB", 100)
        for _, f in ipairs({cL, cR, cT, cB}) do f.BackgroundColor3 = col end
        cL.AnchorPoint = Vector2.new(1, 0.5); cL.Position = UDim2.new(0, 0, 0.5, 0); cL.Size = UDim2.new(0, lr, 0, th)
        cR.AnchorPoint = Vector2.new(0, 0.5); cR.Position = UDim2.new(0, 0, 0.5, 0); cR.Size = UDim2.new(0, lr, 0, th)
        cT.AnchorPoint = Vector2.new(0.5, 1); cT.Position = UDim2.new(0, 0, 0, 0); cT.Size = UDim2.new(0, th, 0, tb)
        cB.AnchorPoint = Vector2.new(0.5, 0); cB.Position = UDim2.new(0, 0, 0, 0); cB.Size = UDim2.new(0, th, 0, tb)
    end
end)

-- ---------- ОТДАЧА / РАЗБРОС / ВСПЫШКИ / ДЫМ / СКОРОСТРЕЛЬНОСТЬ ----------
local ModsBox = Tabs.Weapons:AddLeftGroupbox("Модификации оружия", "wrench")
ModsBox:AddToggle("NoFlash", { Text = "Без вспышки", Default = false,
    Disabled = typeof(hookfunction) ~= "function", DisabledTooltip = "Нужен hookfunction" })
ModsBox:AddToggle("NoSmoke", { Text = "Без дыма", Default = false,
    Disabled = typeof(hookfunction) ~= "function", DisabledTooltip = "Нужен hookfunction" })
ModsBox:AddToggle("FireRateOn", { Text = "Изменить скорострельность", Default = false,
    Disabled = typeof(hookfunction) ~= "function", DisabledTooltip = "Нужен hookfunction" })
ModsBox:AddSlider("FireRateVal", { Text = "Задержка между выстрелами", Default = 0.01, Min = 0, Max = 1, Rounding = 3, Suffix = "с" })
ModsBox:AddToggle("NoRecoil", { Text = "Без отдачи", Default = false,
    Disabled = typeof(hookfunction) ~= "function", DisabledTooltip = "Нужен hookfunction" })
ModsBox:AddToggle("NoSpread", { Text = "Без разброса", Default = false,
    Disabled = typeof(hookfunction) ~= "function", DisabledTooltip = "Нужен hookfunction" })

do
    local getgc_ = getgc or get_gc_objects
    if getgc_ and typeof(hookfunction) == "function" then
        local firerateObjs, firerateOrig = {}, {}
        for _, obj in next, getgc_(true) do
            if type(obj) == "table" and rawget(obj, "FireRate") then
                table.insert(firerateObjs, obj)
                table.insert(firerateOrig, table.clone(obj))
            end
            if type(obj) == "table" and rawget(obj, "setWeaponRecoil") then
                pcall(function()
                    local o; o = hookfunction(obj.setWeaponRecoil, function(...)
                        if getToggle("NoRecoil") then return end
                        return o(...)
                    end)
                end)
            end
            if type(obj) == "function" and debug.getinfo(obj).name == "calculateRecoilOffset" then
                pcall(function()
                    local o; o = hookfunction(obj, function(...)
                        if getToggle("NoRecoil") then return UDim2.new() end
                        return o(...)
                    end)
                end)
            end
            if type(obj) == "table" and rawget(obj, "getTrueSpread") then
                pcall(function()
                    local o; o = hookfunction(obj.getTrueSpread, function(p1)
                        if getToggle("NoSpread") then return 0 end
                        return o(p1)
                    end)
                end)
            end
            if type(obj) == "function" and debug.getinfo(obj).name == "Flash" then
                pcall(function()
                    local o; o = hookfunction(obj, function(...)
                        if getToggle("NoFlash") then return end
                        return o(...)
                    end)
                end)
            end
            if type(obj) == "function" and debug.getinfo(obj).name == "CreateVoxel" then
                local up = debug.getupvalue(obj, 1)
                if up and tostring(up) == "Smoke" then
                    pcall(function()
                        local o; o = hookfunction(obj, function(...)
                            if getToggle("NoSmoke") then return end
                            return o(...)
                        end)
                    end)
                end
            end
        end
        task.spawn(function()
            while task.wait(0.05) do
                pcall(function()
                    local on = getToggle("FireRateOn")
                    local val = math.max(getOption("FireRateVal", 0.01), 0.01)
                    for i, obj in next, firerateObjs do
                        pcall(function()
                            setreadonly(obj, false)
                            rawset(obj, "FireRate", on and val or firerateOrig[i].FireRate)
                            setreadonly(obj, true)
                        end)
                    end
                end)
            end
        end)
    end
end

-- ---------- ЦВЕТ МИРА / НОЧЬ ----------
local NightBox = Tabs.World:AddLeftGroupbox("Цвет мира", "moon")
NightBox:AddToggle("WorldColorOn", { Text = "Цвет мира", Default = false })
    :AddColorPicker("WorldColorPicker", { Default = Color3.fromRGB(255, 255, 255) })
NightBox:AddToggle("SkyColorOn", { Text = "Второй цвет (атмосфера)", Default = false })
    :AddColorPicker("SkyColorPicker", { Default = Color3.fromRGB(255, 255, 255) })

local worldOrig = setmetatable({}, {__mode = "k"})
local function isMine(obj)
    local c = LP.Character
    if c and (obj == c or obj:IsDescendantOf(c)) then return true end
    if obj:IsDescendantOf(Workspace.CurrentCamera) then return true end
    return obj.Name:find("Dx") ~= nil
end

local function colorWorld(on)
    local col = getOption("WorldColorPicker", Color3.fromRGB(255, 255, 255))
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not isMine(obj) then
            if on then
                if not worldOrig[obj] then worldOrig[obj] = obj.Color end
                obj.Color = col
            elseif worldOrig[obj] then
                obj.Color = worldOrig[obj]
                worldOrig[obj] = nil
            end
        end
    end
end

Toggles.WorldColorOn:OnChanged(function() colorWorld(getToggle("WorldColorOn")) end)

connect(RunService.RenderStepped, function()
    if getToggle("SkyColorOn") then
        local c = getOption("SkyColorPicker", Color3.fromRGB(255, 255, 255))
        Lighting.Ambient = c
        Lighting.OutdoorAmbient = c
        Lighting.FogColor = c
    end
end)

-- ---------- АТМОСФЕРА / ЦВЕТОКОРРЕКЦИЯ ----------
local AtmoBox = Tabs.World:AddLeftGroupbox("Атмосфера", "cloud")
AtmoBox:AddToggle("AtmoOn", { Text = "Атмосфера", Default = false })
AtmoBox:AddSlider("AtmoDensity", { Text = "Плотность", Default = 0.3, Min = 0, Max = 1, Rounding = 2 })
AtmoBox:AddSlider("AtmoHaze", { Text = "Дымка", Default = 0, Min = 0, Max = 10, Rounding = 1 })
AtmoBox:AddSlider("AtmoGlare", { Text = "Блики", Default = 0, Min = 0, Max = 10, Rounding = 1 })
AtmoBox:AddToggle("ColorCorr", { Text = "Цветокоррекция", Default = false })
AtmoBox:AddSlider("ColorSat", { Text = "Насыщенность", Default = 0, Min = -1, Max = 1, Rounding = 2 })
AtmoBox:AddSlider("ColorContrast", { Text = "Контраст", Default = 0, Min = -1, Max = 1, Rounding = 1 })

-- ---------- ЧАМСЫ V3 (из PasteHub: материалы, цвет, видимость) ----------
local ChamsV3 = Tabs.Visuals:AddRightGroupbox("Чамсы V3", "layers")
ChamsV3:AddToggle("ChamsV3Enabled", { Text = "Включить", Default = false })
ChamsV3:AddToggle("ChamsV3Team", { Text = "Проверка команды", Default = true })
ChamsV3:AddDropdown("ChamsV3MatVis", { Text = "Материал (видно)", Values = {"Neon", "Metal", "ForceField", "SmoothPlastic"}, Default = "Neon" })
ChamsV3:AddLabel("Цвет (видно)"):AddColorPicker("ChamsV3ColVis", { Default = Color3.fromRGB(0, 200, 0) })
ChamsV3:AddDropdown("ChamsV3MatHid", { Text = "Материал (за стеной)", Values = {"Neon", "Metal", "ForceField", "SmoothPlastic"}, Default = "Metal" })
ChamsV3:AddLabel("Цвет (за стеной)"):AddColorPicker("ChamsV3ColHid", { Default = Color3.fromRGB(200, 0, 0) })
ChamsV3:AddSlider("ChamsV3Fill", { Text = "Прозрачность заливки", Default = 0.3, Min = 0, Max = 1, Rounding = 2 })
ChamsV3:AddSlider("ChamsV3Out", { Text = "Прозрачность контура", Default = 0, Min = 0, Max = 1, Rounding = 2 })

local chamsV3Hl = {}
local chamsV3Ray = RaycastParams.new()
chamsV3Ray.FilterType = Enum.RaycastFilterType.Exclude
local function v3Visible(char)
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not root then return false end
    local camPos = Workspace.CurrentCamera.CFrame.Position
    chamsV3Ray.FilterDescendantsInstances = {LP.Character, char}
    return Workspace:Raycast(camPos, root.Position - camPos, chamsV3Ray) == nil
end
local V3MAT = {Neon = Enum.Material.Neon, Metal = Enum.Material.Metal, ForceField = Enum.Material.ForceField, SmoothPlastic = Enum.Material.SmoothPlastic}

connect(RunService.RenderStepped, function()
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then return end
    local on = getToggle("ChamsV3Enabled")
    for char, pair in pairs(chamsV3Hl) do
        if not char.Parent or not on then
            for _, h in pairs(pair) do pcall(function() h:Destroy() end) end
            chamsV3Hl[char] = nil
        end
    end
    if not on then return end
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj ~= LP.Character then
            if getToggle("ChamsV3Team") and isAlly(obj) then
                if chamsV3Hl[obj] then
                    for _, h in pairs(chamsV3Hl[obj]) do pcall(function() h:Destroy() end) end
                    chamsV3Hl[obj] = nil
                end
                continue
            end
            if not chamsV3Hl[obj] then
                local vis = Instance.new("Highlight")
                vis.DepthMode = Enum.HighlightDepthMode.Occluded
                vis.Adornee = obj
                vis.Parent = obj
                local hid = Instance.new("Highlight")
                hid.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hid.Adornee = obj
                hid.Parent = obj
                chamsV3Hl[obj] = {vis = vis, hid = hid}
            end
            local hl = chamsV3Hl[obj]
            local seen = v3Visible(obj)
            local cV = getOption("ChamsV3ColVis", Color3.fromRGB(0, 200, 0))
            local cH = getOption("ChamsV3ColHid", Color3.fromRGB(200, 0, 0))
            local fill, out = getOption("ChamsV3Fill", 0.3), getOption("ChamsV3Out", 0)
            hl.vis.FillColor, hl.vis.OutlineColor = cV, cV
            hl.vis.FillTransparency, hl.vis.OutlineTransparency = fill, out
            hl.vis.Enabled = seen
            hl.hid.FillColor, hl.hid.OutlineColor = cH, cH
            hl.hid.FillTransparency, hl.hid.OutlineTransparency = fill, out
            hl.hid.Enabled = not seen
        end
    end
end)

-- ---------- БЫСТРАЯ ПЕРЕЗАРЯДКА (из PasteHub) ----------
local ReloadBox = Tabs.Weapons:AddRightGroupbox("Перезарядка", "rotate-cw")
ReloadBox:AddToggle("InstantReload", { Text = "Быстрая перезарядка", Default = false })
task.spawn(function()
    local RELOAD = {Reload = true, ReloadStart = true, ReloadAction = true, ReloadEnd = true}
    while task.wait(0.1) do
        pcall(function()
            if not getToggle("InstantReload") then return end
            local IC = require(ReplicatedStorage.Controllers.InventoryController)
            local w = IC.peekCurrentEquippedForMovement and IC.peekCurrentEquippedForMovement()
            if not w or not w.IsReloading then return end
            for _, c in ipairs({w.Viewmodel and w.Viewmodel.Animation, w.CharacterAnimator}) do
                if c and c.Animations then
                    for name, track in pairs(c.Animations) do
                        if RELOAD[name] and track.IsPlaying then track:AdjustSpeed(199) end
                    end
                end
            end
        end)
    end
end)

-- ---------- ВЫГРУЗКА: вернуть всё, что перенесли ----------
Library:OnUnload(function()
    pcall(function() scopeGui2:Destroy() end)
    for _, h in pairs(chamsV3Hl) do for _, x in pairs(h) do pcall(function() x:Destroy() end) end end
    for _, m in ipairs(hitMarkers) do for _, l in ipairs(m.lines) do pcall(function() l:Remove() end) end end
    for _, z in pairs(zones) do for _, s in ipairs(z.segs) do pcall(function() s:Destroy() end) end end
    for _, w in pairs(weaponHL) do pcall(function() w:Destroy() end) end
    pcall(function() penTxt:Remove() end)
    pcall(function() Workspace.CurrentCamera.FieldOfView = 70 end)
end)


end

do
-- =========================================================================
-- [ PASTEHUB: ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ (скинченджер не затронут) ]
-- =========================================================================

-- ---------- MEMESENSE: наводка на ближайшего врага ----------
local CubeCombatBox = Tabs.Combat:AddLeftGroupbox("Memesense", "crosshair")
CubeCombatBox:AddToggle("MemesenseMainToggle", { Text = "Режим Memesense", Default = false })
    :AddKeyPicker("MemesenseKeybind", { Text = "Клавиша Memesense", Default = "None", Mode = "Toggle" })
CubeCombatBox:AddToggle("CubeAimbotEnabled", { Text = "Умная наводка", Default = false })
CubeCombatBox:AddToggle("CubeVisibleCheck", { Text = "Проверка видимости", Default = false })
CubeCombatBox:AddDropdown("CubeHitPart", {
    Text = "Часть тела",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Default = "Head",
})
CubeCombatBox:AddToggle("CubeTriggerbot", { Text = "Триггербот (Memesense)", Default = false })
CubeCombatBox:AddSlider("CubeTriggerbotDelay", { Text = "Задержка триггербота", Default = 0.01, Min = 0, Max = 1, Rounding = 3, Suffix = "с" })
CubeCombatBox:AddToggle("ShowTargetPlayer", { Text = "Показывать цель", Default = false })
CubeCombatBox:AddDropdown("ShowTargetMode", { Text = "Режим показа", Values = {"Line", "Crosshair"}, Default = "Crosshair" })
CubeCombatBox:AddLabel("Цвет линии"):AddColorPicker("ShowTargetLineColor", { Default = Color3.fromRGB(0, 255, 255) })
CubeCombatBox:AddLabel("Цвет прицела"):AddColorPicker("ShowTargetCrosshairColor", { Default = Color3.fromRGB(0, 255, 255) })

local function memesenseOn()
    local t = getToggle("MemesenseMainToggle")
    local kp = Options.MemesenseKeybind
    if kp and kp.Value ~= "None" and kp.Value ~= "Always" and kp.Value ~= "Toggle" then
        t = kp:GetState()
    end
    return t
end

local function isEnemyChar(char)
    if not char or not LP.Character then return false end
    local mine = hasVestDetails(LP.Character)
    local theirs = hasVestDetails(char)
    if mine then return not theirs end
    return theirs
end

local cubeTarget, lockedTarget = nil, nil
local function findCubeTarget()
    local cam = Workspace.CurrentCamera
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then cubeTarget = nil; return end
    local partName = getOption("CubeHitPart", "Head")
    local vis = getToggle("CubeVisibleCheck")
    local best, bestD = nil, math.huge
    for _, char in ipairs(folder:GetChildren()) do
        if char:IsA("Model") and char ~= LP.Character and isEnemyChar(char) then
            local hum = char:GetAttribute("Health")
            if not (char:GetAttribute("Dead") or (hum and hum <= 0)) then
                local part = char:FindFirstChild(partName) or char:FindFirstChild("Head")
                if part and (not vis or isVisible(part)) then
                    local d = (cam.CFrame.Position - part.Position).Magnitude
                    if d < bestD then best, bestD = part, d end
                end
            end
        end
    end
    cubeTarget = best
end

connect(RunService.RenderStepped, function()
    if memesenseOn() then
        findCubeTarget()
        local cam = Workspace.CurrentCamera
        if getToggle("CubeAimbotEnabled") and cubeTarget and cubeTarget.Parent then
            cam.CFrame = CFrame.new(cam.CFrame.Position, cubeTarget.Position)
        end
    else
        cubeTarget = nil
    end
end)

-- Показ цели (линия или прицел над целью)
local showLines = {}
for i = 1, 4 do
    local l = Drawing.new("Line"); l.Thickness = 2; l.Transparency = 1; l.Visible = false
    showLines[i] = l
end
local showConn = Drawing.new("Line"); showConn.Thickness = 1.5; showConn.Transparency = 1; showConn.Visible = false
connect(RunService.RenderStepped, function()
    local on = memesenseOn() and getToggle("ShowTargetPlayer") and cubeTarget and cubeTarget.Parent
    if not on then
        for _, l in ipairs(showLines) do l.Visible = false end
        showConn.Visible = false
        return
    end
    local cam = Workspace.CurrentCamera
    local sp = cam:WorldToViewportPoint(cubeTarget.Position)
    local c = Vector2.new(sp.X, sp.Y)
    if getOption("ShowTargetMode", "Crosshair") == "Crosshair" then
        showConn.Visible = false
        local col = getOption("ShowTargetCrosshairColor", Color3.fromRGB(0, 255, 255))
        local ang = math.rad((tick() * 180) % 360)
        local pulse = 1 + 0.3 * math.sin(tick() * math.pi * 2)
        for j = 1, 4 do
            local a = ang + (j - 1) * math.pi / 2
            local g = 5 * pulse
            showLines[j].From = c + Vector2.new(math.cos(a) * g, math.sin(a) * g)
            showLines[j].To = c + Vector2.new(math.cos(a) * (g + 16 * pulse), math.sin(a) * (g + 16 * pulse))
            showLines[j].Color = col
            showLines[j].Visible = true
        end
    else
        for _, l in ipairs(showLines) do l.Visible = false end
        showConn.From = cam.ViewportSize / 2
        showConn.To = c
        showConn.Color = getOption("ShowTargetLineColor", Color3.fromRGB(0, 255, 255))
        showConn.Visible = true
    end
end)

-- Триггербот: стреляет, когда прицел на враге (Memesense)
task.spawn(function()
    local trRay = RaycastParams.new()
    trRay.FilterType = Enum.RaycastFilterType.Exclude
    while task.wait(getOption("CubeTriggerbotDelay", 0.01)) do
        pcall(function()
            if not (memesenseOn() and getToggle("CubeTriggerbot")) then return end
            local cam = Workspace.CurrentCamera
            if not cam then return end
            trRay.FilterDescendantsInstances = {LP.Character}
            local r = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 1000, trRay)
            local hit = false
            if r and r.Instance then
                local m = r.Instance:FindFirstAncestorOfClass("Model")
                if m and isEnemyChar(m) and not m:GetAttribute("Dead") then hit = true end
            end
            if hit and cubeTarget then
                local ok, w = pcall(function() return require(ReplicatedStorage.Controllers.InventoryController).peekCurrentEquippedForMovement() end)
                if ok and w and w.shoot then pcall(function() w:shoot() end) end
            end
        end)
    end
end)

-- ---------- RAGEBOT / ТРИГГЕРБОТ / СИЛЕНТ (как в PasteHub) ----------
local RageBox = Tabs.Combat:AddRightGroupbox("Ragebot", "flame")
RageBox:AddToggle("Ragebot", { Text = "Включить ragebot", Default = false,
    Disabled = typeof(hookfunction) ~= "function", DisabledTooltip = "Нужен hookfunction" })
RageBox:AddSlider("RageDelay", { Text = "Задержка", Default = 0.01, Min = 0, Max = 1, Rounding = 3, Suffix = "с" })
RageBox:AddDropdown("RageHitPart", { Text = "Часть тела", Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}, Default = "Head" })
RageBox:AddToggle("RagebotVisibleCheck", { Text = "Проверка видимости", Default = true })
RageBox:AddToggle("RagebotWallCheck", { Text = "Проверка стен", Default = false })
RageBox:AddToggle("RageTriggerbot", { Text = "Триггербот", Default = false })
RageBox:AddSlider("TriggerbotDelay", { Text = "Задержка триггербота", Default = 0.01, Min = 0, Max = 1, Rounding = 3, Suffix = "с" })

local rageTarget = nil
task.spawn(function()
    while task.wait(getOption("RageDelay", 0.01)) do
        pcall(function()
            if not getToggle("Ragebot") then rageTarget = nil; return end
            local cam = Workspace.CurrentCamera
            local folder = Workspace:FindFirstChild("Characters")
            if not folder then return end
            local partName = getOption("RageHitPart", "Head")
            local best, bestD = nil, math.huge
            for _, char in ipairs(folder:GetChildren()) do
                if char:IsA("Model") and char ~= LP.Character and isEnemyChar(char) and not char:GetAttribute("Dead") then
                    local part = char:FindFirstChild(partName) or char:FindFirstChild("Head")
                    if part then
                        local _, onScreen = cam:WorldToViewportPoint(part.Position)
                        local ok = true
                        if getToggle("RagebotVisibleCheck") and not onScreen then ok = false end
                        if ok and getToggle("RagebotWallCheck") and not isVisible(part) then ok = false end
                        local d = (cam.CFrame.Position - part.Position).Magnitude
                        if ok and d < bestD then best, bestD = part, d end
                    end
                end
            end
            rageTarget = best
            if rageTarget then
                local ok, w = pcall(function() return require(ReplicatedStorage.Controllers.InventoryController).peekCurrentEquippedForMovement() end)
                if ok and w and w.shoot then pcall(function() w:shoot() end) end
            end
        end)
    end
end)

-- ---------- ПРИОРИТЕТНАЯ ЦЕЛЬ ----------
local priorityName = nil
local function priorityList()
    local out = {"[ АВТО ]"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and (get_player_team(p) ~= get_player_team(LP)) then out[#out + 1] = p.Name end
    end
    return out
end
RageBox:AddDropdown("RagePriorityTarget", {
    Text = "Приоритетная цель",
    Values = priorityList(),
    Default = "[ АВТО ]",
    Callback = function(v) priorityName = (v ~= "[ АВТО ]") and v or nil end,
})
RageBox:AddButton("Обновить список целей", function()
    Options.RagePriorityTarget:SetValues(priorityList())
    Options.RagePriorityTarget:SetValue("[ АВТО ]")
    priorityName = nil
end)

-- ---------- НАСТРОЙКА ФОВ-КРУГА И УЗКИЙ БЛОК ----------
local CustomFovBox = Tabs.World:AddRightGroupbox("Своё FOV по клавише", "video")
CustomFovBox:AddToggle("CustomFovToggle", { Text = "Своё FOV", Default = false })
    :AddKeyPicker("CustomFovKey", { Text = "Клавиша FOV", Default = "One", Mode = "Always" })
CustomFovBox:AddSlider("FovAmount", { Text = "Значение FOV", Default = 90, Min = 70, Max = 120, Rounding = 0, Suffix = "°" })

connect(RunService.RenderStepped, function()
    if not getToggle("CustomFovToggle") then return end
    local kp = Options.CustomFovKey
    local active = true
    if kp and kp.Value ~= "Always" and kp.Value ~= "One" then active = kp:GetState() end
    if active then
        local cam = Workspace.CurrentCamera
        if cam then cam.FieldOfView = getOption("FovAmount", 90) end
    end
end)

-- ---------- ВРЕМЯ СУТОК / ЯРКОСТЬ / ЦВЕТА / НЕБО ----------
local LightBox = Tabs.World:AddLeftGroupbox("Свет и время", "sun")
LightBox:AddToggle("EnableTime", { Text = "Своё время", Default = false })
LightBox:AddSlider("WorldClockTime", { Text = "Время", Default = 12, Min = 0, Max = 24, Rounding = 1, Suffix = "ч" })
LightBox:AddToggle("EnableBrightness", { Text = "Своя яркость", Default = false })
LightBox:AddSlider("WorldBrightness", { Text = "Яркость", Default = 2, Min = 0, Max = 10, Rounding = 1, Suffix = "x" })
LightBox:AddToggle("EnableColors", { Text = "Свои цвета света", Default = false })
LightBox:AddLabel("Цвет окружения"):AddColorPicker("WorldAmbient", { Default = Color3.fromRGB(127, 127, 127) })
LightBox:AddLabel("Цвет улицы"):AddColorPicker("WorldOutdoorAmbient", { Default = Color3.fromRGB(127, 127, 127) })

local lightOrig = {
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
}
connect(RunService.RenderStepped, function()
    if getToggle("EnableTime") then Lighting.ClockTime = getOption("WorldClockTime", 12)
    else Lighting.ClockTime = lightOrig.ClockTime end
    if getToggle("EnableBrightness") then Lighting.Brightness = getOption("WorldBrightness", 2)
    else Lighting.Brightness = lightOrig.Brightness end
    if getToggle("EnableColors") then
        Lighting.Ambient = getOption("WorldAmbient", Color3.fromRGB(127, 127, 127))
        Lighting.OutdoorAmbient = getOption("WorldOutdoorAmbient", Color3.fromRGB(127, 127, 127))
    else
        Lighting.Ambient = lightOrig.Ambient
        Lighting.OutdoorAmbient = lightOrig.OutdoorAmbient
    end
end)

-- ---------- ЭЛЕМЕНТЫ ESP: КРУГ ВОКРУГ ЦЕЛИ ----------
-- (круговая цель: кольцо и след у ног/головы. Работает поверх уже существующего ESP)
local CircBox = Tabs.Visuals:AddLeftGroupbox("Круговая цель", "circle")
CircBox:AddToggle("ESPCircularTarget", { Text = "Круговая цель", Default = false })
CircBox:AddLabel("Цвет круга"):AddColorPicker("ESPCircularTargetColor", { Default = Color3.fromRGB(255, 200, 0) })

local circLines = {}
for i = 1, 32 do
    local l = Drawing.new("Line"); l.Thickness = 1.5; l.Transparency = 1; l.Visible = false
    circLines[i] = l
end
local circAlpha, circDir = 0, 1
connect(RunService.RenderStepped, function(dt)
    local on = getToggle("ESPCircularTarget") and cubeTarget and cubeTarget.Parent
    if not on then
        for _, l in ipairs(circLines) do l.Visible = false end
        return
    end
    circAlpha = circAlpha + dt * 2 * circDir
    if circAlpha >= 1 then circAlpha, circDir = 1, -1 elseif circAlpha <= 0 then circAlpha, circDir = 0, 1 end
    local center = cubeTarget.Position + Vector3.new(0, -2.5 + 5 * circAlpha, 0)
    local col = getOption("ESPCircularTargetColor", Color3.fromRGB(255, 200, 0))
    local cam = Workspace.CurrentCamera
    for i = 1, 32 do
        local a1 = (i - 1) / 32 * math.pi * 2
        local a2 = i / 32 * math.pi * 2
        local p1 = center + Vector3.new(math.cos(a1) * 2.2, 0, math.sin(a1) * 2.2)
        local p2 = center + Vector3.new(math.cos(a2) * 2.2, 0, math.sin(a2) * 2.2)
        local s1, v1 = cam:WorldToViewportPoint(p1)
        local s2, v2 = cam:WorldToViewportPoint(p2)
        if v1 and v2 then
            circLines[i].From = Vector2.new(s1.X, s1.Y)
            circLines[i].To = Vector2.new(s2.X, s2.Y)
            circLines[i].Color = col
            circLines[i].Visible = true
        else
            circLines[i].Visible = false
        end
    end
end)

-- ---------- ВЫГРУЗКА ----------
Library:OnUnload(function()
    for _, l in ipairs(showLines) do pcall(function() l:Remove() end) end
    pcall(function() showConn:Remove() end)
    for _, l in ipairs(circLines) do pcall(function() l:Remove() end) end
    pcall(function()
        Lighting.Ambient = lightOrig.Ambient
        Lighting.OutdoorAmbient = lightOrig.OutdoorAmbient
        Lighting.Brightness = lightOrig.Brightness
        Lighting.ClockTime = lightOrig.ClockTime
    end)
end)


do
end

do
-- =========================================================================
-- [ ESP: 5 РЕЖИМОВ — каждый режим рисует по-своему, один из них должен работать ]
--   1. Drawing      — линии через библиотеку Drawing (нужен эксплойтер с Drawing)
--   2. ScreenGui    — обычные рамки GUI (работает везде, без Drawing)
--   3. BillboardGui — подписи над головой (чистый Roblox, без Drawing)
--   4. Highlight    — свечение через Highlight (чистый Roblox)
--   5. SelectionBox — 3D-коробка в мире (чистый Roblox)
-- =========================================================================
local XESP = Tabs.Visuals:AddRightGroupbox("ESP: 5 режимов", "scan")
XESP:AddToggle("XESPOn", { Text = "Включить ESP", Default = false })
XESP:AddDropdown("XESPMode", {
    Text = "Режим отрисовки",
    Values = {
        "1. Drawing (линии)",
        "2. ScreenGui (рамки)",
        "3. BillboardGui (подписи)",
        "4. Highlight (свечение)",
        "5. SelectionBox (3D)",
    },
    Default = "2. ScreenGui (рамки)",
})
XESP:AddDropdown("XESPTeam", { Text = "Кого показывать", Values = {"Все", "Враги", "Союзники"}, Default = "Враги" })
XESP:AddSlider("XESPDist", { Text = "Макс. дистанция", Default = 1500, Min = 50, Max = 5000, Rounding = 0, Suffix = "st" })
XESP:AddLabel("Цвет ESP"):AddColorPicker("XESPColor", { Default = Color3.fromRGB(255, 255, 255) })
XESP:AddToggle("XESPNames", { Text = "Показывать имя", Default = true })
XESP:AddToggle("XESPDists", { Text = "Показывать дистанцию", Default = true })

local xGuiRoot = nil
local function xGui()
    if xGuiRoot and xGuiRoot.Parent then return xGuiRoot end
    xGuiRoot = Instance.new("ScreenGui")
    xGuiRoot.Name = "DxHub_ESP"
    xGuiRoot.ResetOnSpawn = false
    xGuiRoot.IgnoreGuiInset = true
    xGuiRoot.DisplayOrder = 50
    pcall(function() xGuiRoot.Parent = CoreGui end)
    if not xGuiRoot.Parent then xGuiRoot.Parent = LP:WaitForChild("PlayerGui") end
    return xGuiRoot
end

local xEntries = {}
local xModeCur = nil

local function xAdd(e, o)
    e.objs[#e.objs + 1] = o
    return o
end

local function xKill(e)
    for _, o in ipairs(e.objs) do
        pcall(function() o:Destroy() end)
        pcall(function() o:Remove() end)
    end
    e.objs = {}
end

local function xKillAll()
    for m, e in pairs(xEntries) do
        xKill(e)
        xEntries[m] = nil
    end
end

local function xSetVis(e, on)
    for _, o in ipairs(e.objs) do
        pcall(function() o.Visible = on end)
    end
end

local function xTargetsNow()
    local out = {}
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then return out end
    local team = getOption("XESPTeam", "Враги")
    local maxD = getOption("XESPDist", 1500)
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m ~= LP.Character then
            local hrp = m:FindFirstChild("HumanoidRootPart")
            local hp = m:GetAttribute("Health")
            local dead = m:GetAttribute("Dead") or m:GetAttribute("Invincible") or (hp ~= nil and hp <= 0)
            if hrp and not dead then
                local dist = myRoot and (hrp.Position - myRoot.Position).Magnitude or 0
                if dist <= maxD then
                    local ally = isAlly(m)
                    if team == "Все" or (team == "Враги" and not ally) or (team == "Союзники" and ally) then
                        out[#out + 1] = {model = m, hrp = hrp}
                    end
                end
            end
        end
    end
    return out
end

local function xBox(hrp)
    local cam = Workspace.CurrentCamera
    local top, a = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.2, 0))
    local bot, b = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
    if top.Z <= 0 or bot.Z <= 0 then return nil end
    local h = math.abs(top.Y - bot.Y)
    if h < 2 then return nil end
    local w = h * 0.55
    local cx = (top.X + bot.X) / 2
    return cx - w / 2, top.Y, w, h
end

local function xLabel(t)
    local s = ""
    if getToggle("XESPNames") then s = t.model.Name end
    if getToggle("XESPDists") then
        local cam = Workspace.CurrentCamera
        local d = math.floor((t.hrp.Position - cam.CFrame.Position).Magnitude)
        s = (s ~= "" and (s .. "  ") or "") .. d .. "m"
    end
    return s
end

-- Режим 1: Drawing
local function xDrawing(e, t, col)
    if not Drawing then return end
    if not e.lines then
        e.lines = {}
        for i = 1, 4 do
            local l = xAdd(e, Drawing.new("Line"))
            l.Thickness = 1.5
            l.Transparency = 1
            e.lines[i] = l
        end
        e.txt = xAdd(e, Drawing.new("Text"))
        e.txt.Center = true
        e.txt.Outline = true
        e.txt.Size = 14
    end
    local x, y, w, h = xBox(t.hrp)
    if not x then xSetVis(e, false) return end
    local pts = {{x, y, x + w, y}, {x + w, y, x + w, y + h}, {x + w, y + h, x, y + h}, {x, y + h, x, y}}
    for i = 1, 4 do
        local l, p = e.lines[i], pts[i]
        l.From = Vector2.new(p[1], p[2])
        l.To = Vector2.new(p[3], p[4])
        l.Color = col
        l.Visible = true
    end
    e.txt.Text = xLabel(t)
    e.txt.Position = Vector2.new(x + w / 2, y - 16)
    e.txt.Color = col
    e.txt.Visible = e.txt.Text ~= ""
end

-- Режим 2: ScreenGui
local function xGuiMode(e, t, col)
    if not e.frame then
        local f = Instance.new("Frame")
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.Parent = xGui()
        local st = Instance.new("UIStroke")
        st.Thickness = 1.5
        st.Parent = f
        local tl = Instance.new("TextLabel")
        tl.BackgroundTransparency = 1
        tl.Size = UDim2.new(1, 0, 0, 14)
        tl.Position = UDim2.new(0, 0, 0, -16)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 13
        tl.TextStrokeTransparency = 0.4
        tl.TextColor3 = col
        tl.Parent = f
        e.frame, e.stroke, e.tl = f, st, tl
        xAdd(e, f)
    end
    local x, y, w, h = xBox(t.hrp)
    if not x then e.frame.Visible = false return end
    e.frame.Visible = true
    e.frame.Position = UDim2.fromOffset(x, y)
    e.frame.Size = UDim2.fromOffset(w, h)
    e.stroke.Color = col
    e.tl.Text = xLabel(t)
    e.tl.TextColor3 = col
end

-- Режим 3: BillboardGui
local function xBillboard(e, t, col)
    if not e.bb then
        local bb = Instance.new("BillboardGui")
        bb.Adornee = t.hrp
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(200, 34)
        bb.StudsOffset = Vector3.new(0, 3.6, 0)
        bb.Parent = t.hrp
        local tl = Instance.new("TextLabel")
        tl.BackgroundTransparency = 1
        tl.Size = UDim2.fromScale(1, 1)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 14
        tl.TextStrokeTransparency = 0.3
        tl.Parent = bb
        e.bb, e.tl = bb, tl
        xAdd(e, bb)
    end
    e.tl.Text = xLabel(t)
    e.tl.TextColor3 = col
end

-- Режим 4: Highlight
local function xHighlight(e, t, col)
    if not e.hl then
        local hl = Instance.new("Highlight")
        hl.Adornee = t.model
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.75
        hl.OutlineTransparency = 0
        hl.Parent = t.model
        e.hl = hl
        xAdd(e, hl)
    end
    e.hl.FillColor = col
    e.hl.OutlineColor = col
end

-- Режим 5: SelectionBox
local function xSelection(e, t, col)
    if not e.part then
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Transparency = 1
        p.Parent = Workspace
        local sb = Instance.new("SelectionBox")
        sb.Adornee = p
        sb.LineThickness = 0.03
        sb.Parent = p
        e.part, e.sb = p, sb
        xAdd(e, p)
    end
    local cf, size = t.model:GetBoundingBox()
    e.part.CFrame = cf
    e.part.Size = size + Vector3.new(0.2, 0.2, 0.2)
    e.sb.Color3 = col
end

local xRenderers = {
    ["1"] = function(e, t, col) xDrawing(e, t, col) end,
    ["2"] = function(e, t, col) xGuiMode(e, t, col) end,
    ["3"] = function(e, t, col) xBillboard(e, t, col) end,
    ["4"] = function(e, t, col) xHighlight(e, t, col) end,
    ["5"] = function(e, t, col) xSelection(e, t, col) end,
}

connect(RunService.RenderStepped, function()
    if not getToggle("XESPOn") then
        if next(xEntries) then xKillAll() end
        xModeCur = nil
        return
    end
    local mode = string.sub(getOption("XESPMode", "2. ScreenGui (рамки)"), 1, 1)
    if mode ~= xModeCur then
        xKillAll()
        xModeCur = mode
    end
    local col = getOption("XESPColor", Color3.fromRGB(255, 255, 255))
    local seen = {}
    for _, t in ipairs(xTargetsNow()) do
        seen[t.model] = true
        local e = xEntries[t.model]
        if not e then
            e = {objs = {}}
            xEntries[t.model] = e
        end
        local fn = xRenderers[mode]
        if fn then pcall(fn, e, t, col) end
    end
    for m, e in pairs(xEntries) do
        if not seen[m] or not m.Parent then
            xKill(e)
            xEntries[m] = nil
        end
    end
end)

Library:OnUnload(function() xKillAll() end)

-- =========================================================================
-- [ ДИАГНОСТИКА СКИНОВ + ЗАЩИТА ОТ КОНФЛИКТОВ ]
-- Скин-логика не менялась. Здесь только показываем статус и выключаем фичи,
-- которые правят те же модели оружия (это ломает модель ножа и скины).
-- =========================================================================
local skinDiagBox = Tabs.SkinChanger:AddRightGroupbox("Диагностика скинов", "info")
local skinDiag = skinDiagBox:AddLabel("Загрузка...")
local skinLast = 0
connect(RunService.RenderStepped, function()
    local now = tick()
    if now - skinLast < 0.5 then return end
    skinLast = now
    local anySkin = SkinConfig.SkinChanger.Enabled or SkinConfig.KnifeChanger.Enabled or SkinConfig.GloveChanger.Enabled
    if anySkin then
        if Toggles.CustomHands and Toggles.CustomHands.Value then
            Toggles.CustomHands:SetValue(false)
            Library:Notify("Положение рук выключено: конфликтует со скинами", 4)
        end
        if Toggles.WeaponChamsEnabled and Toggles.WeaponChamsEnabled.Value then
            Toggles.WeaponChamsEnabled:SetValue(false)
            Library:Notify("Чамсы оружия выключены: конфликтуют со скинами", 4)
        end
    end
    local wm = GetWeaponModel()
    skinDiag:SetText(string.format(
        "Скины: %s  |  Нож: %s  |  Перчатки: %s\nМодель в камере: %s\nПапка Assets.Skins: %s",
        SkinConfig.SkinChanger.Enabled and "ВКЛ" or "выкл",
        SkinConfig.KnifeChanger.Enabled and SkinConfig.KnifeChanger.Model or "выкл",
        SkinConfig.GloveChanger.Enabled and "ВКЛ" or "выкл",
        wm and wm.Name or "не найдена (возьми нож или оружие в руки)",
        SD.SkinsRoot and ("найдена, моделей: " .. #SD.SkinsRoot:GetChildren()) or "НЕ НАЙДЕНА"))
end)

end

end

-- Авто-создание ESP при появлении игрока
connect(Players.PlayerAdded, function(p)
    task.wait(0.5)
    if getToggle("ESPEnabled") then makeESP(p) end
end)
connect(Players.PlayerRemoving, function(p)
    destroyESP(p)
end)

-- Выгрузка меню: убираем ESP, чамсы, круги и трассеры
Library:OnUnload(function()
    for player in pairs(ESPCache) do destroyESP(player) end
    for char in pairs(ChamsHighlights) do removeChams(char) end
    pcall(function() AimbotFovCircle:Remove() end)
    pcall(function() SilentFovCircle:Remove() end)
    pcall(function() TracerGui:Destroy() end)
    SilentTarget = nil
end)

-- =========================================================================
-- [ CONFIGS — сохранение настроек (вместо SaveManager) ]
-- =========================================================================

local function BuildConfigSection(tab)
    local DIR = "dxhub/bloxstrike/dxhub"
    local fs = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfolder) == "function"
        and typeof(makefolder) == "function" and typeof(isfile) == "function"
    _G.DXHubMem = _G.DXHubMem or {}
    local mem = _G.DXHubMem
    local IGNORE = { MenuKeybind = true, DX_ConfigName = true, DX_ConfigList = true }

    local box = tab:AddRightGroupbox("Configuration", "folder")
    local nameInput = box:AddInput("DX_ConfigName", { Text = "Config name", Default = "", Placeholder = "name" })
    local list = { "—" }
    local picker = box:AddDropdown("DX_ConfigList", { Text = "Config list", Values = list, Default = 1 })
    local autoLabel = box:AddLabel("Autoload: none")

    local function ensureDir()
        if not fs then return end
        local acc = ""
        for part in string.gmatch(DIR, "[^/]+") do
            acc = acc == "" and part or (acc .. "/" .. part)
            if not isfolder(acc) then makefolder(acc) end
        end
    end
    local function cleanName(n)
        n = string.gsub(n or "", "[\\/:%*%?\"<>|]", "")
        n = string.gsub(n, "^%s+", "")
        n = string.gsub(n, "%s+$", "")
        return n
    end
    local function serialize()
        local data = {}
        for idx, t in pairs(Toggles) do
            if not IGNORE[idx] then data[idx] = t.Value and true or false end
        end
        for idx, o in pairs(Options) do
            if not IGNORE[idx] then
                if o.Type == "Slider" then
                    data[idx] = o.Value
                elseif o.Type == "Dropdown" then
                    data[idx] = o.Value
                elseif o.Type == "ColorPicker" then
                    local c = o.Value
                    data[idx] = { r = math.floor(c.R * 255 + 0.5), g = math.floor(c.G * 255 + 0.5), b = math.floor(c.B * 255 + 0.5) }
                end
            end
        end
        return HttpService:JSONEncode(data)
    end
    local function apply(text)
        local ok, data = pcall(function() return HttpService:JSONDecode(text) end)
        if not ok or type(data) ~= "table" then return false end
        for idx, v in pairs(data) do
            if Toggles[idx] then
                Toggles[idx]:SetValue(v)
            elseif Options[idx] and Options[idx].SetValue then
                pcall(function() Options[idx]:SetValue(v) end)
            end
        end
        return true
    end
    local function names()
        local out = {}
        if fs and typeof(listfiles) == "function" then
            ensureDir()
            for _, f in ipairs(listfiles(DIR)) do
                local n = string.match(f, "([^/\\]+)%.json$")
                if n then out[#out + 1] = n end
            end
        else
            for n in pairs(mem) do out[#out + 1] = n end
        end
        table.sort(out)
        return out
    end
    local function refresh()
        local n = names()
        table.clear(list)
        if #n == 0 then list[1] = "—" else for _, v in ipairs(n) do list[#list + 1] = v end end
        picker:SetValues(list)
        picker:SetValue(list[1], true)
    end
    local function read(n)
        if fs and isfile(DIR .. "/" .. n .. ".json") then return readfile(DIR .. "/" .. n .. ".json") end
        return mem[n]
    end
    local function write(n)
        if fs then
            ensureDir()
            writefile(DIR .. "/" .. n .. ".json", serialize())
        else
            mem[n] = serialize()
        end
    end
    local function pickName()
        local n = cleanName(nameInput.Value)
        if n == "" and picker.Value and picker.Value ~= "—" then n = picker.Value end
        return n
    end

    box:AddButton("Create config", function()
        local n = cleanName(nameInput.Value)
        if n == "" then Library:Notify("Enter a config name"); return end
        write(n); refresh(); picker:SetValue(n, true)
        Library:Notify("Created config: " .. n)
    end)
    box:AddButton("Load config", function()
        local n = (picker.Value and picker.Value ~= "—") and picker.Value or pickName()
        local text = n and read(n)
        if not text then Library:Notify("Config not found"); return end
        if apply(text) then Library:Notify("Loaded config: " .. n) else Library:Notify("Config is corrupted") end
    end)
    box:AddButton("Overwrite config", function()
        local n = (picker.Value and picker.Value ~= "—") and picker.Value or pickName()
        if not n or n == "" then Library:Notify("Select a config"); return end
        write(n)
        Library:Notify("Overwrote config: " .. n)
    end)
    box:AddButton("Delete config", function()
        local n = (picker.Value and picker.Value ~= "—") and picker.Value or pickName()
        if not n or n == "" then return end
        if fs and typeof(delfile) == "function" then pcall(delfile, DIR .. "/" .. n .. ".json") end
        mem[n] = nil
        refresh()
        Library:Notify("Deleted config: " .. n)
    end)
    box:AddButton("Refresh list", refresh)
    box:AddButton("Set as autoload", function()
        local n = (picker.Value and picker.Value ~= "—") and picker.Value or pickName()
        if not n or n == "" then return end
        if not fs then Library:Notify("Autoload needs writefile"); return end
        ensureDir()
        writefile(DIR .. "/autoload.txt", n)
        autoLabel:SetText("Autoload: " .. n)
        Library:Notify("Autoload: " .. n)
    end)
    box:AddButton("Reset autoload", function()
        if fs and typeof(delfile) == "function" and isfile(DIR .. "/autoload.txt") then pcall(delfile, DIR .. "/autoload.txt") end
        autoLabel:SetText("Autoload: none")
    end)

    refresh()
    -- автозагрузка
    if fs then
        pcall(function()
            if isfile(DIR .. "/autoload.txt") then
                local n = readfile(DIR .. "/autoload.txt")
                local text = read(n)
                if text and apply(text) then
                    autoLabel:SetText("Autoload: " .. n)
                    Library:Notify("Autoloaded config: " .. n)
                end
            end
        end)
    end
end

BuildConfigSection(Tabs.Settings)

print("[DxHub v3] Loaded — Combat / Visuals / Movements / SkinChanger")

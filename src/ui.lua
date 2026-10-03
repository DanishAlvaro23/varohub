-- src/ui.lua
-- Floating orb ala Delta. Tap orb → expand jadi window penuh tab.
-- Tidak pakai require. Core di-inject via UI.init(Core).

local UI = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Core = nil
local THEME = {
	bg        = Color3.fromRGB(14, 14, 20),
	bg2       = Color3.fromRGB(22, 22, 32),
	accent    = Color3.fromRGB(150, 90, 255),
	accent2   = Color3.fromRGB(190, 140, 255),
	text      = Color3.fromRGB(235, 235, 255),
	textDim   = Color3.fromRGB(165, 165, 200),
	stroke    = Color3.fromRGB(150, 90, 255),
	on        = Color3.fromRGB(120, 220, 150),
	off       = Color3.fromRGB(60, 60, 80),
}

local function tween(o, p, t, style, dir)
	TweenService:Create(o, TweenInfo.new(t or 0.22, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), p):Play()
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

function UI.init(core)
	Core = core
	return UI
end

function UI.create(opts)
	opts = opts or {}
	local name = opts.name or "varohub"
	local version = opts.version or "1.0.0"
	local parent = opts.parent or game:GetService("CoreGui")

	assert(Core, "[varohub:ui] UI.init(Core) dulu sebelum create")

	local gui = new("ScreenGui", {
		Name = name .. "UI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = parent,
	})

	-- ====== FLOATING ORB ======
	local orb = new("TextButton", {
		Name = "Orb",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = THEME.bg2,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Parent = gui,
	})
	new("UICorner", {CornerRadius = UDim.new(1, 0)}, orb)

	local orbStroke = new("UIStroke", {
		Color = THEME.stroke,
		Thickness = 2,
		Transparency = 0.2,
		Parent = orb,
	})
	local orbGrad = new("UIGradient", {Rotation = 45}, orb)
	orbGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.accent),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 20, 80)),
	})

	-- glow ring
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(86, 86),
		BackgroundTransparency = 1,
		Parent = orb,
	})
	new("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
	new("UIStroke", {
		Color = THEME.accent2,
		Thickness = 2,
		Transparency = 0.6,
		Parent = ring,
	})

	-- logo "V"
	local logo = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "V",
		TextSize = 30,
		TextColor3 = THEME.text,
		Parent = orb,
	})
	local logoGrad = new("UIGradient", {Rotation = 90}, logo)
	logoGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, THEME.accent2),
	})

	-- pulse
	task.spawn(function()
		while gui.Parent do
			tween(ring, {Size = UDim2.fromOffset(100, 100), BackgroundTransparency = 0.85}, 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.2)
			tween(ring, {Size = UDim2.fromOffset(86, 86), BackgroundTransparency = 1}, 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.2)
		end
	end)

	-- ====== MAIN WINDOW (hidden) ======
	local win = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 380),
		BackgroundColor3 = THEME.bg,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		Parent = gui,
	})
	new("UICorner", {CornerRadius = UDim.new(0, 14)}, win)
	new("UIStroke", {Color = THEME.stroke, Thickness = 1.5, Transparency = 0.25}, win)
	local winGrad = new("UIGradient", {Rotation = 45}, win)
	winGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 32, 96)),
		ColorSequenceKeypoint.new(1, THEME.bg),
	})

	-- top bar
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = win,
	})
	new("TextLabel", {
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(1, -80, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = string.upper(name),
		TextSize = 16,
		TextColor3 = THEME.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})
	new("TextLabel", {
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(1, -80, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "  v" .. version,
		TextSize = 11,
		TextColor3 = THEME.textDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})

	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(230, 80, 100),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Parent = bar,
	})
	new("UICorner", {CornerRadius = UDim.new(0, 8)}, close)

	-- sidebar
	local side = new("ScrollingFrame", {
		Position = UDim2.new(0, 10, 0, 44),
		Size = UDim2.fromOffset(140, 324),
		BackgroundColor3 = THEME.bg2,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = win,
	})
	new("UICorner", {CornerRadius = UDim.new(0, 10)}, side)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, side)
	new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, side)

	-- content
	local content = new("Frame", {
		Position = UDim2.new(0, 160, 0, 44),
		Size = UDim2.fromOffset(390, 324),
		BackgroundTransparency = 1,
		Parent = win,
	})

	local pages = {}
	local tabs = {}

	local function selectTab(name)
		for n, p in pairs(pages) do p.Visible = (n == name) end
		for n, b in pairs(tabs) do
			tween(b, {BackgroundColor3 = (n == name) and THEME.accent or Color3.fromRGB(36, 36, 52)})
		end
	end

	-- ====== EXPAND / COLLAPSE ======
	local expanded = false
	local function expand()
		if expanded then return end
		expanded = true
		orb.Visible = false
		win.Visible = true
		win.Size = UDim2.fromOffset(0, 0)
		win.BackgroundTransparency = 1
		tween(win, {Size = UDim2.fromOffset(560, 380), BackgroundTransparency = 0}, 0.28, Enum.EasingStyle.Back)
	end
	local function collapse()
		if not expanded then return end
		expanded = false
		tween(win, {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.2)
		win.Visible = false
		orb.Visible = true
	end

	close.MouseButton1Click:Connect(collapse)
	orb.MouseButton1Click:Connect(expand)

	-- ====== DRAG ======
	local dragging, dragStart, startPos
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = i.Position
			startPos = win.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	-- ====== API ======
	local api = {}
	api.instance = gui
	api.window = win
	api.orb = orb

	function api.tab(tabName)
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Color3.fromRGB(36, 36, 52),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = "  " .. tabName,
			TextSize = 13,
			TextColor3 = THEME.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			Parent = side,
		})
		new("UICorner", {CornerRadius = UDim.new(0, 8)}, btn)

		local page = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = THEME.accent,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = content,
		})
		new("UIListLayout", {Padding = UDim.new(0, 6)}, page)
		new("UIPadding", {PaddingRight = UDim.new(0, 6)}, page)

		pages[tabName] = page
		tabs[tabName] = btn
		btn.MouseButton1Click:Connect(function() selectTab(tabName) end)

		if next(pages) == tabName then selectTab(tabName) end
		return page
	end

	function api.button(parent, text, cb, color)
		local b = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = color or THEME.accent,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = text,
			TextSize = 13,
			TextColor3 = THEME.text,
			AutoButtonColor = false,
			Parent = parent,
		})
		new("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
		new("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.8}, b)
		b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = THEME.accent2}) end)
		b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = color or THEME.accent}) end)
		b.MouseButton1Click:Connect(cb or function() end)
		return b
	end

	function api.toggle(parent, text, flagName, default)
		local row = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Color3.fromRGB(28, 28, 42),
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Parent = parent,
		})
		new("UICorner", {CornerRadius = UDim.new(0, 8)}, row)
		new("TextLabel", {
			Position = UDim2.new(0, 12, 0, 0),
			Size = UDim2.new(1, -56, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = text,
			TextSize = 13,
			TextColor3 = THEME.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local ind = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(36, 18),
			BackgroundColor3 = THEME.off,
			BorderSizePixel = 0,
			Parent = row,
		})
		new("UICorner", {CornerRadius = UDim.new(1, 0)}, ind)
		local knob = new("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0, 2, 0.5, -7),
			BackgroundColor3 = Color3.fromRGB(240, 240, 255),
			BorderSizePixel = 0,
			Parent = ind,
		})
		new("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)

		local function render(v)
			tween(ind, {BackgroundColor3 = v and THEME.on or THEME.off})
			tween(knob, {Position = v and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)})
		end
		render(Core.STATE:flag(flagName, default or false))
		Core.STATE:on("flag:" .. flagName, render)
		row.MouseButton1Click:Connect(function()
			Core.STATE:setFlag(flagName, not Core.STATE:flag(flagName, false))
		end)
		return row
	end

	function api.slider(parent, text, flagName, min, max, default)
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = Color3.fromRGB(28, 28, 42),
			BorderSizePixel = 0,
			Parent = parent,
		})
		new("UICorner", {CornerRadius = UDim.new(0, 8)}, row)
		local lbl = new("TextLabel", {
			Position = UDim2.new(0, 12, 0, 4),
			Size = UDim2.new(1, -24, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = text .. ": " .. tostring(default or min),
			TextSize = 12,
			TextColor3 = THEME.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local track = new("Frame", {
			Position = UDim2.new(0, 12, 0, 28),
			Size = UDim2.new(1, -24, 0, 8),
			BackgroundColor3 = THEME.off,
			BorderSizePixel = 0,
			Parent = row,
		})
		new("UICorner", {CornerRadius = UDim.new(1, 0)}, track)
		local fill = new("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = THEME.accent,
			BorderSizePixel = 0,
			Parent = track,
		})
		new("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)

		local dragging = false
		local function apply(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local val = math.floor(min + (max - min) * rel + 0.5)
			fill.Size = UDim2.fromScale(rel, 1)
			lbl.Text = text .. ": " .. tostring(val)
			Core.STATE:setFlag(flagName, val)
		end
		track.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				apply(i.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				apply(i.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		return row
	end

	function api.label(parent, text)
		return new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = text,
			TextSize = 12,
			TextColor3 = THEME.textDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = parent,
		})
	end

	function api.divider(parent)
		return new("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.fromRGB(60, 60, 85),
			BorderSizePixel = 0,
			Parent = parent,
		})
	end

	function api.expand() expand() end
	function api.collapse() collapse() end
	function api.destroy() gui:Destroy() end

	return api
end

return UI
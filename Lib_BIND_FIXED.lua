-- XuilanLib (COPY-PASTE)
-- Fixes in this version:
-- 1) Persistent states across section switching (Toggle/Slider/Dropdown/TextBox)
-- 2) Keeps all previous fixes (multi-touch drag, dropdown attach/close, themes, open text offset etc.)
-- NOTE: Visual style unchanged; only state logic added/fixed.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")


-- Key System global Y offset (in pixels). Adjust if you want the whole key UI higher/lower.
local KEY_SYSTEM_Y_OFFSET = 0
local XuilanLib = {}
XuilanLib.__index = XuilanLib

--==================================================
-- SETTINGS (Open Ui text offset)
--==================================================
-- X: + right, - left
-- Y: + down, - up
local OPEN_TEXT_OFFSET_X = -10
local OPEN_TEXT_OFFSET_Y = 0

--==================================================
-- Helpers
--==================================================
local function ParseFont(v)
	if typeof(v) == "EnumItem" then return v end
	if typeof(v) == "string" and Enum.Font[v] then
		return Enum.Font[v]
	end
	return Enum.Font.SourceSans
end

local function ParseColor(v)
	if typeof(v) == "Color3" then return v end
	if typeof(v) == "table" then
		return Color3.fromRGB(v[1] or 255, v[2] or 255, v[3] or 255)
	end
	if typeof(v) == "string" then
		local hex = v:gsub("#","")
		if #hex == 6 then
			local r = tonumber(hex:sub(1,2),16)
			local g = tonumber(hex:sub(3,4),16)
			local b = tonumber(hex:sub(5,6),16)
			if r and g and b then return Color3.fromRGB(r,g,b) end
		end
		local r,g,b = v:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
		if r and g and b then return Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b)) end
	end
	return Color3.fromRGB(255,255,255)
end

local function asAsset(v)
	if not v then return nil end
	if typeof(v) == "number" then return "rbxassetid://"..tostring(v) end
	if typeof(v) == "string" then
		if v:find("rbxassetid://") then return v end
		if v:match("^%d+$") then return "rbxassetid://"..v end
		return v
	end
	return nil
end

local function clamp(n, a, b)
	if n < a then return a end
	if n > b then return b end
	return n
end

local function clampTextSize(n, fallback)
	n = tonumber(n)
	if not n then return fallback end
	n = math.floor(n + 0.5)
	return clamp(n, 6, 44)
end

local function brighten(c, add)
	return Color3.fromRGB(
		clamp(math.floor(c.R*255 + add + 0.5), 0, 255),
		clamp(math.floor(c.G*255 + add + 0.5), 0, 255),
		clamp(math.floor(c.B*255 + add + 0.5), 0, 255)
	)
end

local function getTouchId(input)
	local ok, id = pcall(function() return input.TouchId end)
	if ok then return id end
	return nil
end

local function ParseKeyCode(v)
	if typeof(v) == "EnumItem" and v.EnumType == Enum.KeyCode then
		return v
	end
	if typeof(v) == "string" then
		local kc = Enum.KeyCode[v]
		if kc then return kc end
	end
	return nil
end

--==================================================
-- Color helpers (HSV/RGB + parsing for ColorPicker)
--==================================================
local function rgbText(c)
	return string.format("%d, %d, %d",
		math.floor(c.R*255 + 0.5),
		math.floor(c.G*255 + 0.5),
		math.floor(c.B*255 + 0.5)
	)
end

local function hsvToRgb(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f*s)
	local t = v * (1 - (1-f)*s)
	i = i % 6

	local r,g,b
	if i == 0 then r,g,b = v,t,p
	elseif i == 1 then r,g,b = q,v,p
	elseif i == 2 then r,g,b = p,v,t
	elseif i == 3 then r,g,b = p,q,v
	elseif i == 4 then r,g,b = t,p,v
	else r,g,b = v,p,q end

	return Color3.new(r,g,b)
end

local function rgbToHsv(c)
	local r,g,b = c.R, c.G, c.B
	local maxc = math.max(r,g,b)
	local minc = math.min(r,g,b)
	local delta = maxc - minc

	local h = 0
	if delta > 0 then
		if maxc == r then
			h = ((g - b) / delta) % 6
		elseif maxc == g then
			h = ((b - r) / delta) + 2
		else
			h = ((r - g) / delta) + 4
		end
		h = h / 6
	end

	local s = (maxc == 0) and 0 or (delta / maxc)
	local v = maxc
	return h, s, v
end

local function parseColorText(s)
	if typeof(s) ~= "string" then return nil end
	s = s:gsub("%s+", "")
	if s == "" then return nil end

	-- rgb: "r,g,b"
	do
		local r,g,b = s:match("^(%d+),(%d+),(%d+)$")
		if r and g and b then
			r,g,b = tonumber(r), tonumber(g), tonumber(b)
			if r and g and b then
				return Color3.fromRGB(clamp(r,0,255), clamp(g,0,255), clamp(b,0,255))
			end
		end
	end

	-- hex: "#RRGGBB" or "RRGGBB"
	do
		local h = s:gsub("#","")
		if #h == 6 and h:match("^[0-9a-fA-F]+$") then
			local r = tonumber(h:sub(1,2),16)
			local g = tonumber(h:sub(3,4),16)
			local b = tonumber(h:sub(5,6),16)
			if r and g and b then
				return Color3.fromRGB(r,g,b)
			end
		end
	end

	return nil
end

--==================================================
-- Themes (30)  [оставлено как было]
--==================================================
--==================================================
-- Themes (10 bright + distinct)
-- Each theme may include:
--  MainT, InnerT, BgImageT (transparencies)
--==================================================
local Themes = {
	{ Name="Default Dark", Main=Color3.fromRGB(18,18,18), Inner=Color3.fromRGB(105,105,105), Row=Color3.fromRGB(140,140,140), ValueBox=Color3.fromRGB(105,105,105), PillOff=Color3.fromRGB(145,145,145), Fill=Color3.fromRGB(90,90,90), Lines=Color3.fromRGB(120,120,120), Separator=Color3.fromRGB(120,120,120), Accent=Color3.fromRGB(39,227,36), Title=Color3.fromRGB(235,235,235), Desc=Color3.fromRGB(200,200,200), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(220,220,220), MainT=0.12, InnerT=0.8, BgImageT=0.85 },
	{ Name="Light",        Main=Color3.fromRGB(235,235,235), Inner=Color3.fromRGB(210,210,210), Row=Color3.fromRGB(190,190,190), ValueBox=Color3.fromRGB(200,200,200), PillOff=Color3.fromRGB(175,175,175), Fill=Color3.fromRGB(140,140,140), Lines=Color3.fromRGB(160,160,160), Separator=Color3.fromRGB(160,160,160), Accent=Color3.fromRGB(39,227,36), Title=Color3.fromRGB(25,25,25), Desc=Color3.fromRGB(55,55,55), Text=Color3.fromRGB(20,20,20), Muted=Color3.fromRGB(60,60,60), MainT=0.10, InnerT=0.25, BgImageT=0.90 },
	{ Name="Neon",         Main=Color3.fromRGB(10,10,10), Inner=Color3.fromRGB(35,35,35), Row=Color3.fromRGB(55,55,55), ValueBox=Color3.fromRGB(45,45,45), PillOff=Color3.fromRGB(80,80,80), Fill=Color3.fromRGB(20,180,255), Lines=Color3.fromRGB(20,180,255), Separator=Color3.fromRGB(20,180,255), Accent=Color3.fromRGB(255,40,200), Title=Color3.fromRGB(245,245,245), Desc=Color3.fromRGB(210,210,210), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(230,230,230), MainT=0.12, InnerT=0.75, BgImageT=0.88 },
	{ Name="Cyber",        Main=Color3.fromRGB(12,14,18), Inner=Color3.fromRGB(24,110,120), Row=Color3.fromRGB(40,140,150), ValueBox=Color3.fromRGB(24,110,120), PillOff=Color3.fromRGB(55,150,160), Fill=Color3.fromRGB(0,210,255), Lines=Color3.fromRGB(0,210,255), Separator=Color3.fromRGB(0,210,255), Accent=Color3.fromRGB(39,227,36), Title=Color3.fromRGB(240,255,255), Desc=Color3.fromRGB(200,240,240), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(220,250,250), MainT=0.12, InnerT=0.78, BgImageT=0.86 },
	{ Name="Sunset",       Main=Color3.fromRGB(20,12,14), Inner=Color3.fromRGB(150,70,65), Row=Color3.fromRGB(175,95,80), ValueBox=Color3.fromRGB(150,70,65), PillOff=Color3.fromRGB(185,110,90), Fill=Color3.fromRGB(255,140,0), Lines=Color3.fromRGB(255,140,0), Separator=Color3.fromRGB(255,140,0), Accent=Color3.fromRGB(255,60,60), Title=Color3.fromRGB(255,250,245), Desc=Color3.fromRGB(235,220,210), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(245,235,225), MainT=0.12, InnerT=0.78, BgImageT=0.87 },
	{ Name="Ocean",        Main=Color3.fromRGB(8,16,24), Inner=Color3.fromRGB(40,110,150), Row=Color3.fromRGB(55,135,175), ValueBox=Color3.fromRGB(40,110,150), PillOff=Color3.fromRGB(70,150,195), Fill=Color3.fromRGB(0,170,255), Lines=Color3.fromRGB(0,170,255), Separator=Color3.fromRGB(0,170,255), Accent=Color3.fromRGB(39,227,36), Title=Color3.fromRGB(245,255,255), Desc=Color3.fromRGB(205,230,240), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(225,245,255), MainT=0.12, InnerT=0.78, BgImageT=0.87 },
	{ Name="Violet",       Main=Color3.fromRGB(14,10,20), Inner=Color3.fromRGB(120,80,160), Row=Color3.fromRGB(145,105,185), ValueBox=Color3.fromRGB(120,80,160), PillOff=Color3.fromRGB(160,130,200), Fill=Color3.fromRGB(180,80,255), Lines=Color3.fromRGB(180,80,255), Separator=Color3.fromRGB(180,80,255), Accent=Color3.fromRGB(39,227,36), Title=Color3.fromRGB(250,245,255), Desc=Color3.fromRGB(220,210,235), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(235,225,245), MainT=0.12, InnerT=0.78, BgImageT=0.87 },
	{ Name="Emerald",      Main=Color3.fromRGB(10,18,14), Inner=Color3.fromRGB(60,140,95), Row=Color3.fromRGB(85,165,120), ValueBox=Color3.fromRGB(60,140,95), PillOff=Color3.fromRGB(105,180,135), Fill=Color3.fromRGB(39,227,36), Lines=Color3.fromRGB(39,227,36), Separator=Color3.fromRGB(39,227,36), Accent=Color3.fromRGB(0,255,170), Title=Color3.fromRGB(245,255,250), Desc=Color3.fromRGB(215,235,225), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(235,250,242), MainT=0.12, InnerT=0.78, BgImageT=0.87 },
	{ Name="Candy",        Main=Color3.fromRGB(22,10,16), Inner=Color3.fromRGB(160,85,120), Row=Color3.fromRGB(190,115,150), ValueBox=Color3.fromRGB(160,85,120), PillOff=Color3.fromRGB(210,145,175), Fill=Color3.fromRGB(255,60,180), Lines=Color3.fromRGB(255,60,180), Separator=Color3.fromRGB(255,60,180), Accent=Color3.fromRGB(255,230,60), Title=Color3.fromRGB(255,250,255), Desc=Color3.fromRGB(235,215,235), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(245,230,245), MainT=0.12, InnerT=0.78, BgImageT=0.87 },
	{ Name="Lava",         Main=Color3.fromRGB(18,8,8), Inner=Color3.fromRGB(150,55,35), Row=Color3.fromRGB(185,85,55), ValueBox=Color3.fromRGB(150,55,35), PillOff=Color3.fromRGB(215,115,75), Fill=Color3.fromRGB(255,80,0), Lines=Color3.fromRGB(255,80,0), Separator=Color3.fromRGB(255,80,0), Accent=Color3.fromRGB(255,0,0), Title=Color3.fromRGB(255,245,235), Desc=Color3.fromRGB(235,210,200), Text=Color3.fromRGB(255,255,255), Muted=Color3.fromRGB(245,225,215), MainT=0.12, InnerT=0.78, BgImageT=0.87 },
}

for _,t in ipairs(Themes) do
	t.Separator = t.Separator or t.Lines
end

local function getThemeByName(name)
	for _,t in ipairs(Themes) do
		if t.Name == name then return t end
	end
	return Themes[1]
end

--==================================================
-- Notification System
--==================================================
local function CreateNotifier(screenGui, getTheme, MAIN_T, MAIN_CORNER)
	local holder = Instance.new("Frame")
	holder.Name = "NotificationsHolder"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.AnchorPoint = Vector2.new(1,1)
	holder.Position = UDim2.new(1,-12, 1,-12)
	holder.Size = UDim2.new(0, 213, 0, 220)
	holder.ZIndex = 9000
	holder.Parent = screenGui

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Padding = UDim.new(0,8)
	list.Parent = holder

	local Notifier = {}

	function Notifier:Notify(opt)
		opt = opt or {}
		local theme = getTheme()

		local titleText = tostring(opt.Title or "Notification")
		local descText = tostring(opt.Description or "")
		local duration = tonumber(opt.Duration) or 2.0

		local titleFont = ParseFont(opt.TitleFont or Enum.Font.SourceSansBold)
		local descFont = ParseFont(opt.DescriptionFont or Enum.Font.SourceSans)
		local titleColor = ParseColor(opt.TitleColor or theme.Title)
		local descColor = ParseColor(opt.DescriptionColor or theme.Desc)

		local wrap = Instance.new("Frame")
		wrap.BackgroundTransparency = 1
		wrap.BorderSizePixel = 0
		wrap.Size = UDim2.new(1,0,0,64)
		wrap.LayoutOrder = math.floor(os.clock()*1000)
		wrap.Parent = holder

		local card = Instance.new("Frame")
		card.BorderSizePixel = 0
		card.BackgroundColor3 = theme.Main
		card.BackgroundTransparency = MAIN_T
		card.Size = UDim2.new(1,0,1,0)
		card.Position = UDim2.new(1, 260, 0, 0)
		card.ZIndex = 9001
		card.Parent = wrap

		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0, MAIN_CORNER)
		cr.Parent = card

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.Parent = card

		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.BorderSizePixel = 0
		tl.Text = titleText
		tl.Font = titleFont
		tl.TextSize = 18
		tl.TextColor3 = titleColor
		tl.TextXAlignment = Enum.TextXAlignment.Left
		tl.TextYAlignment = Enum.TextYAlignment.Top
		tl.Size = UDim2.new(1,0,0,20)
		tl.ZIndex = 9002
		tl.Parent = card

		local dl = Instance.new("TextLabel")
		dl.BackgroundTransparency = 1
		dl.BorderSizePixel = 0
		dl.Text = descText
		dl.Font = descFont
		dl.TextSize = 14
		dl.TextColor3 = descColor
		dl.TextXAlignment = Enum.TextXAlignment.Left
		dl.TextYAlignment = Enum.TextYAlignment.Top
		dl.TextWrapped = true
		dl.Position = UDim2.new(0,0,0,22)
		dl.Size = UDim2.new(1,0,1,-22)
		dl.ZIndex = 9002
		dl.Parent = card

		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0,0,0,0)
		}):Play()

		task.delay(duration, function()
			if not card or not card.Parent then return end
			local t = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(1, 260, 0, 0)
			})
			t:Play()
			t.Completed:Connect(function()
				if wrap and wrap.Parent then wrap:Destroy() end
			end)
		end)
	end

	return Notifier
end

local function shouldNotify(when, state)
	when = tostring(when or "Both")
	if when == "Both" then return true end
	if when == "On" then return state == true end
	if when == "Off" then return state == false end
	return false
end

--==================================================
-- CreateWindow
--==================================================
function XuilanLib:CreateWindow(settings)
	settings = settings or {}

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local old = playerGui:FindFirstChild("CustomRectangleGui")
	if old then old:Destroy() end

	local MAIN_T = 0.12
	local MAIN_CORNER = 14

	local INNER_T = 0.8
	local INNER_CORNER = 14

	local ROW_CORNER = 12
	local ROW_BG_T = INNER_T
	local ROW_H = 34

	local HEADER_TOP = 3
	local HEADER_BOTTOM = 3

	local ASSET_PUG = asAsset(settings.Icon) or "rbxassetid://136007050760089"
	local ASSET_CLOSE = "rbxassetid://87923978940368"
	local ASSET_MINUS = "rbxassetid://92670491990824"
	local ASSET_FINGERPRINT = "rbxassetid://134643086907470"
	local ASSET_ARROWS = "rbxassetid://97961707453604"

	local currentTheme = getThemeByName(settings.DefaultTheme or Themes[1].Name)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CustomRectangleGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 999999
	screenGui.Parent = playerGui

	local Notifier = CreateNotifier(screenGui, function() return currentTheme end, MAIN_T, MAIN_CORNER)

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainRectangle"
	mainFrame.Size = UDim2.new(0,400,0,280)
	mainFrame.AnchorPoint = Vector2.new(0.5,0.5)
	mainFrame.Position = UDim2.new(0.5,0,0.5,0)
	mainFrame.BackgroundColor3 = currentTheme.Main
	mainFrame.BackgroundTransparency = MAIN_T
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.ZIndex = 1000
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, MAIN_CORNER)
	mainCorner.Parent = mainFrame

	local innerFrame = Instance.new("Frame")
	innerFrame.Name = "InnerRectangle"
	innerFrame.Size = UDim2.new(0,260,0,235)
	innerFrame.AnchorPoint = Vector2.new(1,1)
	innerFrame.Position = UDim2.new(1,-10, 1,-10)
	innerFrame.BackgroundColor3 = currentTheme.Inner
	innerFrame.BackgroundTransparency = INNER_T
	innerFrame.BorderSizePixel = 0
	innerFrame.ZIndex = 1001
	innerFrame.Parent = mainFrame

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0, INNER_CORNER)
	innerCorner.Parent = innerFrame

	local innerMask = Instance.new("Frame")
	innerMask.Name = "InnerMask"
	innerMask.BackgroundTransparency = 1
	innerMask.BorderSizePixel = 0
	innerMask.ClipsDescendants = true
	innerMask.Size = UDim2.new(1,0,1,0)
	innerMask.ZIndex = 1002
	innerMask.Parent = innerFrame

	local innerMaskCorner = Instance.new("UICorner")
	innerMaskCorner.CornerRadius = UDim.new(0, INNER_CORNER)
	innerMaskCorner.Parent = innerMask

	--==================================================
	-- Optional Background Image (inside inner, clipped, behind elements)
	--==================================================
	local bgImage
	if settings.BackgroundImage then
		bgImage = Instance.new("ImageLabel")
		bgImage.Name = "BackgroundImage"
		bgImage.BackgroundTransparency = 1
		bgImage.BorderSizePixel = 0
		bgImage.Image = asAsset(settings.BackgroundImage)
		bgImage.ScaleType = Enum.ScaleType.Fit
		bgImage.AnchorPoint = Vector2.new(0.5,0.5)
		bgImage.Position = UDim2.new(0.5,0,0.5,0)
		bgImage.Size = UDim2.new(1.3,0,1.3,0)
		bgImage.ImageTransparency = 0.85
		bgImage.ZIndex = 1003
		bgImage.Parent = innerMask
	end

	local image = Instance.new("ImageLabel")
	image.Name = "TopLeftImage"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = ASSET_PUG
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = 1002
	image.Parent = mainFrame

	local textWrap = Instance.new("Frame")
	textWrap.BackgroundTransparency = 1
	textWrap.BorderSizePixel = 0
	textWrap.ZIndex = 1002
	textWrap.Parent = mainFrame

	local headerList = Instance.new("UIListLayout")
	headerList.FillDirection = Enum.FillDirection.Vertical
	headerList.SortOrder = Enum.SortOrder.LayoutOrder
	headerList.Parent = textWrap

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.BorderSizePixel = 0
	title.Text = settings.Title or "XuilanLib"
	title.Font = ParseFont(settings.TitleFont or "SourceSansBold")
	title.TextColor3 = ParseColor(settings.TitleColor or "235,235,235")
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.ZIndex = 1003
	title.LayoutOrder = 1
	title.Parent = textWrap

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.BorderSizePixel = 0
	desc.Text = settings.Description or ""
	desc.Font = ParseFont(settings.DescriptionFont or "SourceSansBold")
	desc.TextColor3 = ParseColor(settings.DescriptionColor or "200,200,200")
	desc.TextScaled = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.ZIndex = 1003
	desc.LayoutOrder = 2
	desc.Parent = textWrap

	local closeBtn = Instance.new("ImageButton")
	closeBtn.BackgroundTransparency = 1
	closeBtn.BorderSizePixel = 0
	closeBtn.AutoButtonColor = false
	closeBtn.AnchorPoint = Vector2.new(1,0)
	closeBtn.Image = ASSET_CLOSE
	closeBtn.ScaleType = Enum.ScaleType.Fit
	closeBtn.ZIndex = 2000
	closeBtn.Parent = mainFrame

	local minusBtn = Instance.new("ImageButton")
	minusBtn.BackgroundTransparency = 1
	minusBtn.BorderSizePixel = 0
	minusBtn.AutoButtonColor = false
	minusBtn.AnchorPoint = Vector2.new(1,0)
	minusBtn.Image = ASSET_MINUS
	minusBtn.ScaleType = Enum.ScaleType.Fit
	minusBtn.ZIndex = 2000
	minusBtn.Parent = mainFrame

	local function press1px(btn)
		local p = btn.Position
		btn.Position = UDim2.new(p.X.Scale, p.X.Offset+1, p.Y.Scale, p.Y.Offset+1)
		task.delay(0.08, function()
			if btn and btn.Parent then
				btn.Position = p
			end
		end)
	end

	--==================================================
	-- Open Ui pill (collapse button)
	--==================================================
	local openPill = Instance.new("Frame")
	openPill.Name = "OpenPill"
	openPill.Visible = false
	openPill.BorderSizePixel = 0
	openPill.AnchorPoint = Vector2.new(0.5,0)
	openPill.Position = UDim2.new(0.5,0,0,12)
	openPill.BackgroundColor3 = currentTheme.Main
	openPill.BackgroundTransparency = MAIN_T
	openPill.ZIndex = 3000
	openPill.Parent = screenGui

	local openPillCorner = Instance.new("UICorner")
	openPillCorner.CornerRadius = UDim.new(1,0)
	openPillCorner.Parent = openPill

	local arrowsSize = math.floor(16*1.3 + 0.5)

	local arrowsBtn = Instance.new("ImageButton")
	arrowsBtn.Name = "DragArrows"
	arrowsBtn.BackgroundTransparency = 1
	arrowsBtn.BorderSizePixel = 0
	arrowsBtn.AutoButtonColor = false
	arrowsBtn.Image = ASSET_ARROWS
	arrowsBtn.ScaleType = Enum.ScaleType.Fit
	arrowsBtn.Size = UDim2.new(0,arrowsSize,0,arrowsSize)
	arrowsBtn.Position = UDim2.new(0,8, 0.5, -math.floor(arrowsSize/2))
	arrowsBtn.ZIndex = 3003
	arrowsBtn.Parent = openPill

	local openTextBtn = Instance.new("TextButton")
	openTextBtn.Name = "OpenTextHitbox"
	openTextBtn.BackgroundTransparency = 1
	openTextBtn.BorderSizePixel = 0
	openTextBtn.AutoButtonColor = false
	openTextBtn.Text = ""
	openTextBtn.ZIndex = 3001
	openTextBtn.Parent = openPill

	local openTextLabel = Instance.new("TextLabel")
	openTextLabel.Name = "OpenTextLabel"
	openTextLabel.BackgroundTransparency = 1
	openTextLabel.BorderSizePixel = 0
	openTextLabel.Text = "Open Ui"
	openTextLabel.Font = Enum.Font.SourceSansBold
	openTextLabel.TextSize = 16
	openTextLabel.TextColor3 = Color3.fromRGB(255,255,255)
	openTextLabel.TextXAlignment = Enum.TextXAlignment.Center
	openTextLabel.TextYAlignment = Enum.TextYAlignment.Center
	openTextLabel.AnchorPoint = Vector2.new(0.5,0.5)
	openTextLabel.Size = UDim2.new(1,0,1,0)
	openTextLabel.ZIndex = 3002
	openTextLabel.Parent = openTextBtn

	local function updateOpenPill()
		local txt = openTextLabel.Text
		local bounds = TextService:GetTextSize(txt, openTextLabel.TextSize, openTextLabel.Font, Vector2.new(1000,1000))

		local minW = 140
		local w = 8 + arrowsSize + 8 + bounds.X + 14
		if w < minW then w = minW end
		openPill.Size = UDim2.new(0, math.floor(w+0.5), 0, 34)

		local leftX = 8 + arrowsSize + 8
		openTextBtn.Position = UDim2.new(0, leftX, 0, 0)
		openTextBtn.Size = UDim2.new(1, -leftX, 1, 0)

		openTextLabel.Position = UDim2.new(0.5, OPEN_TEXT_OFFSET_X, 0.5, OPEN_TEXT_OFFSET_Y)
	end
	updateOpenPill()
	openTextLabel:GetPropertyChangedSignal("Text"):Connect(updateOpenPill)
	openTextLabel:GetPropertyChangedSignal("TextSize"):Connect(updateOpenPill)
	openTextLabel:GetPropertyChangedSignal("Font"):Connect(updateOpenPill)

	openTextBtn.Activated:Connect(function()
		openPill.Visible = false
		mainFrame.Visible = true
	end)

	--==================================================
	-- Panels: Sections (left) + Content (inner)
	--==================================================
	local sectionsPanel = Instance.new("ScrollingFrame")
	sectionsPanel.BackgroundTransparency = 1
	sectionsPanel.BorderSizePixel = 0
	sectionsPanel.ScrollBarThickness = 0
	sectionsPanel.ScrollingDirection = Enum.ScrollingDirection.Y
	sectionsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sectionsPanel.CanvasSize = UDim2.new(0,0,0,0)
	sectionsPanel.ZIndex = 1002
	sectionsPanel.Parent = mainFrame

	local sectionsList = Instance.new("UIListLayout")
	sectionsList.SortOrder = Enum.SortOrder.LayoutOrder
	sectionsList.Padding = UDim.new(0,2)
	sectionsList.Parent = sectionsPanel

	local contentScroll = Instance.new("ScrollingFrame")
	contentScroll.BackgroundTransparency = 1
	contentScroll.BorderSizePixel = 0
	contentScroll.ScrollBarThickness = 0
	contentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	contentScroll.CanvasSize = UDim2.new(0,0,0,0)
	contentScroll.ZIndex = 1010
	contentScroll.Parent = innerMask

	local contentPad = Instance.new("UIPadding")
	contentPad.PaddingLeft = UDim.new(0,10)
	contentPad.PaddingRight = UDim.new(0,10)
	contentPad.PaddingTop = UDim.new(0,10)
	contentPad.PaddingBottom = UDim.new(0,10)
	contentPad.Parent = contentScroll

	local contentList = Instance.new("UIListLayout")
	contentList.SortOrder = Enum.SortOrder.LayoutOrder
	contentList.Padding = UDim.new(0,8)
	contentList.Parent = contentScroll

	local bottomSpacer = Instance.new("Frame")
	bottomSpacer.BackgroundTransparency = 1
	bottomSpacer.BorderSizePixel = 0
	bottomSpacer.Size = UDim2.new(1,0,0,INNER_CORNER)
	bottomSpacer.LayoutOrder = 999999
	bottomSpacer.Parent = contentScroll

	--==================================================
	-- Window object + theme targets + binds registry
	--==================================================
	local Window = {}
	Window.Sections = {}
	Window._selectedIndex = nil
	Window._sectionButtons = {}
	Window._leftOrder = 0
	Window._pendingDefaultThemeName = settings.DefaultTheme

	local ThemeTargets = { SectionButtons = {}, SectionSeparators = {}, Rows = {} }

	--==================================================
	-- Dropdown Manager (keeps dropdown attached to GUI + closes on section change)
	--==================================================
	local DropdownManager = {
		Menu = nil,
		Anchor = nil, -- TextButton that opened it
	}

	local function CloseDropdown()
		if DropdownManager.Menu and DropdownManager.Menu.Parent then
			DropdownManager.Menu:Destroy()
		end
		DropdownManager.Menu = nil
		DropdownManager.Anchor = nil
	end

	local function UpdateDropdownPosition()
		local menu = DropdownManager.Menu
		local anchor = DropdownManager.Anchor
		if not menu or not anchor then return end
		if not anchor.Parent then
			CloseDropdown()
			return
		end

		local pos = anchor.AbsolutePosition
		local size = anchor.AbsoluteSize
		menu.Position = UDim2.new(0, pos.X + size.X + 5, 0, pos.Y)
	end

	-- close dropdown when tapping/clicking outside
	do
		local function inside(gui, p)
			local gp = gui.AbsolutePosition
			local gs = gui.AbsoluteSize
			return (p.X >= gp.X and p.X <= gp.X + gs.X and p.Y >= gp.Y and p.Y <= gp.Y + gs.Y)
		end

		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if not DropdownManager.Menu then return end

			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local p = input.Position
				local menu = DropdownManager.Menu
				local anchor = DropdownManager.Anchor

				if menu and menu.Parent and inside(menu, p) then return end
				if anchor and anchor.Parent and inside(anchor, p) then return end

				CloseDropdown()
			end
		end)
	end

	-- Bind system
	local BindRegistry = {} -- [Enum.KeyCode] = { fn1, fn2, ... }
	local BindListenerConnected = false

	local function EnsureBindListener()
		if BindListenerConnected then return end
		BindListenerConnected = true

		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			local kc = input.KeyCode
			local list = BindRegistry[kc]
			if not list then return end
			for _,fn in ipairs(list) do
				if typeof(fn) == "function" then
					task.spawn(fn)
				end
			end
		end)
	end

	local function RegisterBind(bindStr, fn)
		local kc = ParseKeyCode(bindStr)
		if not kc then return end
		EnsureBindListener()
		BindRegistry[kc] = BindRegistry[kc] or {}
		table.insert(BindRegistry[kc], fn)
	end

	-- Resolve bind settings.
	-- New API:
	--   Bind = true/false
	--   BindKey = "" / "F" / Enum.KeyCode.F
	-- Backward compatible:
	--   Bind = "F" or Enum.KeyCode.F (treated as enabled)
	local function ResolveBindOpt(opt)
		if type(opt) ~= "table" then return nil end
		local b = opt.Bind
		-- Backward compat: Bind can be string/Enum.KeyCode
		if typeof(b) == "string" or (typeof(b) == "EnumItem" and b.EnumType == Enum.KeyCode) then
			return b
		end
		-- New API: Bind boolean gate + BindKey value
		if b == true then
			local k = opt.BindKey
			if typeof(k) == "string" then
				k = k:gsub("^%s+",""):gsub("%s+$","")
				if k == "" then return nil end
				return k
			end
			if typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode then
				return k
			end
		end
		return nil
	end

	local function ApplyTheme(theme)
		currentTheme = theme
		-- UI text color override (ThemeSection color picker)
		local textOverride = Window and Window._uiTextOverride

		mainFrame.BackgroundColor3 = theme.Main
		innerFrame.BackgroundColor3 = theme.Inner
		openPill.BackgroundColor3 = theme.Main

		-- Apply transparencies from theme if present
		if theme.MainT ~= nil then
			mainFrame.BackgroundTransparency = theme.MainT
			openPill.BackgroundTransparency = theme.MainT
		end
		if theme.InnerT ~= nil then
			innerFrame.BackgroundTransparency = theme.InnerT
			ROW_BG_T = (theme.RowT ~= nil) and theme.RowT or theme.InnerT
		end
		if theme.RowT ~= nil and theme.InnerT == nil then
			ROW_BG_T = theme.RowT
		end
		if bgImage and theme.BgImageT ~= nil then
			bgImage.ImageTransparency = theme.BgImageT
		end

		if not title:GetAttribute("XuilanBaseTextColor") then title:SetAttribute("XuilanBaseTextColor", title.TextColor3) end
		if not desc:GetAttribute("XuilanBaseTextColor") then desc:SetAttribute("XuilanBaseTextColor", desc.TextColor3) end
		local _titleBase = title:GetAttribute("XuilanBaseTextColor")
		local _descBase = desc:GetAttribute("XuilanBaseTextColor")
		title.TextColor3 = (textOverride or _titleBase or theme.Title)
		desc.TextColor3 = (textOverride or _descBase or theme.Desc)
for _, b in ipairs(ThemeTargets.SectionButtons) do
			if b and b.Parent then
				if not b:GetAttribute("XuilanBaseTextColor") then b:SetAttribute("XuilanBaseTextColor", b.TextColor3) end
				b.TextColor3 = (textOverride or b:GetAttribute("XuilanBaseTextColor") or theme.Title)
			end
		end


	for _, s in ipairs(ThemeTargets.SectionSeparators) do
		if s and s.Parent then
			s.BackgroundColor3 = theme.Separator
		end
	end

		for _, r in ipairs(ThemeTargets.Rows) do
			if r.Content and r.Content.Parent then
				r.Content.BackgroundColor3 = theme.Row
				r.Content.BackgroundTransparency = ROW_BG_T
			end
			if r.Label and r.Label.Parent then
				if not r.Label:GetAttribute("XuilanBaseTextColor") then r.Label:SetAttribute("XuilanBaseTextColor", r.Label.TextColor3) end
				r.Label.TextColor3 = (textOverride or r.Label:GetAttribute("XuilanBaseTextColor") or theme.Text)
			end
			if r.Muted and r.Muted.Parent then
				if not r.Muted:GetAttribute("XuilanBaseTextColor") then r.Muted:SetAttribute("XuilanBaseTextColor", r.Muted.TextColor3) end
				r.Muted.TextColor3 = (textOverride or r.Muted:GetAttribute("XuilanBaseTextColor") or theme.Muted)
			end
			if r.Type == "Toggle" then
				if r.Pill and r.Pill.Parent then
					r.Pill.BackgroundColor3 = (r.State.Value and theme.Accent or theme.PillOff)
				end
			elseif r.Type == "Slider" then
				if r.Track and r.Track.Parent then r.Track.BackgroundColor3 = theme.PillOff end
				if r.Fill and r.Fill.Parent then r.Fill.BackgroundColor3 = theme.Fill end
				if r.ValueBox and r.ValueBox.Parent then r.ValueBox.BackgroundColor3 = theme.ValueBox end
			elseif r.Type == "Dropdown" then
				if r.SelectBtn and r.SelectBtn.Parent then r.SelectBtn.BackgroundColor3 = theme.ValueBox end
			elseif r.Type == "TextBox" then
				if r.InputBox and r.InputBox.Parent then r.InputBox.BackgroundColor3 = theme.ValueBox end
			elseif r.Type == "HeadText" then
				if r.LeftLine and r.LeftLine.Parent then r.LeftLine.BackgroundColor3 = theme.Lines end
				if r.RightLine and r.RightLine.Parent then r.RightLine.BackgroundColor3 = theme.Lines end

			elseif r.Type == "Separator" then
				if r.Bar and r.Bar.Parent then r.Bar.BackgroundColor3 = theme.Separator end
			elseif r.Type == "ColorPicker" then
				if r.Preview and r.Preview.Parent then r.Preview.BackgroundColor3 = r.State.Color end
				if r.Track and r.Track.Parent then
					-- gradient stays, but corner color/box updates
				end
				if r.InputBox and r.InputBox.Parent then r.InputBox.BackgroundColor3 = theme.ValueBox end
				if r.Title and r.Title.Parent then r.Title.TextColor3 = (textOverride or theme.Text) end
				if r.Label and r.Label.Parent then if not r.Label:GetAttribute("XuilanBaseTextColor") then r.Label:SetAttribute("XuilanBaseTextColor", r.Label.TextColor3) end
				r.Label.TextColor3 = (textOverride or r.Label:GetAttribute("XuilanBaseTextColor") or theme.Text) end
			end
		end
	end

	
	function Window:AddTheme(nameOrDef, maybeDef)
		-- Supports:
		-- 1) Window:AddTheme({ Name="MyTheme", ...old keys... })
		-- 2) Window:AddTheme("MyTheme", { MainColor="255,255,255", InnerColor="#112233", AccentColor="0,170,255", TextColor="255,255,255",
		--                                RowColor="...", ValueBoxColor="...", PillOffColor="...", FillColor="...", LinesColor="...", SeparatorColor="...",
		--                                TitleColor="...", DescColor="...", MutedColor="...",
		--                                MainTransparency=0.12, InnerTransparency=0.8, RowTransparency=0.8, BgImageTransparency=0.85 })
		local def
		if typeof(nameOrDef) == "string" then
			def = maybeDef or {}
			def.Name = nameOrDef
		elseif typeof(nameOrDef) == "table" then
			def = nameOrDef
		else
			return
		end
		if typeof(def) ~= "table" or not def.Name then return end

		local t = {}
		t.Name = tostring(def.Name)

		local function pickColorAlt(primary, alt, fallback)
			if def[primary] ~= nil then return ParseColor(def[primary]) end
			if alt and def[alt] ~= nil then return ParseColor(def[alt]) end
			return fallback
		end
		local function pickNumberKey(primary, fallback)
			local v = def[primary]
			if v == nil then return fallback end
			v = tonumber(v)
			return v ~= nil and v or fallback
		end

		local base = currentTheme or Themes[1]

		-- Colors (support old keys + new *Color keys)
		t.Main      = pickColorAlt("Main", "MainColor", base.Main)
		t.Inner     = pickColorAlt("Inner", "InnerColor", base.Inner)
		t.Row       = pickColorAlt("Row", "RowColor", base.Row)
		t.ValueBox  = pickColorAlt("ValueBox", "ValueBoxColor", base.ValueBox)
		t.PillOff   = pickColorAlt("PillOff", "PillOffColor", base.PillOff)
		t.Fill      = pickColorAlt("Fill", "FillColor", base.Fill)
		t.Lines     = pickColorAlt("Lines", "LinesColor", base.Lines)
		t.Separator = pickColorAlt("Separator", "SeparatorColor", base.Separator or base.Lines)
		t.Accent    = pickColorAlt("Accent", "AccentColor", base.Accent)
		t.Title     = pickColorAlt("Title", "TitleColor", base.Title)
		t.Desc      = pickColorAlt("Desc", "DescColor", base.Desc)
		t.Text      = pickColorAlt("Text", "TextColor", base.Text)
		t.Muted     = pickColorAlt("Muted", "MutedColor", base.Muted)

		-- Transparencies (support old keys + new *Transparency keys)
		t.MainT    = (def.MainT ~= nil) and tonumber(def.MainT) or pickNumberKey("MainTransparency", base.MainT)
		t.InnerT   = (def.InnerT ~= nil) and tonumber(def.InnerT) or pickNumberKey("InnerTransparency", base.InnerT)
		t.RowT     = (def.RowT ~= nil) and tonumber(def.RowT) or pickNumberKey("RowTransparency", (base.RowT ~= nil and base.RowT or base.InnerT))
		t.BgImageT = (def.BgImageT ~= nil) and tonumber(def.BgImageT) or pickNumberKey("BgImageTransparency", base.BgImageT)

		-- Upsert (replace if same name exists)
		local replaced = false
		for i, old in ipairs(Themes) do
			if old and old.Name == t.Name then
				Themes[i] = t
				replaced = true
				break
			end
		end
		if not replaced then
			table.insert(Themes, t)
		end

		-- Refresh theme dropdown if it exists
		if Window._themeDropdownApi and Window._themeDropdownApi.RefreshOptions then
			Window._themeDropdownApi:RefreshOptions()
		end

		-- If this theme is meant to be default, apply it now
		if Window._pendingDefaultThemeName and tostring(Window._pendingDefaultThemeName) == t.Name then
			Window._pendingDefaultThemeName = nil
			Window:SetTheme(t.Name)
		end
	end

	function Window:SetTheme(name)
		local t = getThemeByName(name)
		ApplyTheme(t)
	end

	function Window:Notify(opt)
		Notifier:Notify(opt)
	end

	--==================================================
	-- Layout update
	--==================================================
	local function updateLayout()
		local mainTop = mainFrame.AbsolutePosition.Y
		local innerTop = innerFrame.AbsolutePosition.Y

		local headerHeight = math.floor((innerTop - mainTop) - (3 + 3))
		if headerHeight < 1 then headerHeight = 1 end

		local iconSize = math.max(12, math.floor(headerHeight * 0.60))
		closeBtn.Size = UDim2.new(0,iconSize,0,iconSize)
		closeBtn.Position = UDim2.new(1,-10,0,10)

		minusBtn.Size = UDim2.new(0,iconSize,0,iconSize)
		minusBtn.Position = UDim2.new(1, -(10 + iconSize + 10), 0, 10)

		image.Position = UDim2.new(0,10,0,3)
		image.Size = UDim2.new(0,headerHeight,0,headerHeight)

		local reservedRight = 10 + iconSize + 10 + iconSize + 12
		local availW = mainFrame.AbsoluteSize.X - (10 + headerHeight + 10) - reservedRight
		if availW < 10 then availW = 10 end

		textWrap.Position = UDim2.new(0, 10 + headerHeight + 10, 0, 3)
		textWrap.Size = UDim2.new(0, availW, 0, headerHeight)

		local usableH = headerHeight - 4
		if usableH < 2 then usableH = 2 end
		local titleH = math.floor(usableH * 0.58)
		local descH = usableH - titleH
		title.Size = UDim2.new(1,0,0,titleH)
		desc.Size = UDim2.new(1,0,0,descH)

		local mainW = mainFrame.AbsoluteSize.X
		local mainH = mainFrame.AbsoluteSize.Y
		local innerW = innerFrame.AbsoluteSize.X
		local innerLeft = mainW - 10 - innerW

		local panelX = 3
		local panelRight = innerLeft - 3
		local panelW = panelRight - panelX
		if panelW < 20 then panelW = 20 end

		local panelY = math.floor(innerTop - mainTop)
		local panelH = mainH - panelY - 10
		if panelH < 20 then panelH = 20 end

		sectionsPanel.Position = UDim2.new(0,panelX, 0,panelY)
		sectionsPanel.Size = UDim2.new(0,panelW, 0,panelH)

		contentScroll.Size = UDim2.new(1,0,1,0)
		contentScroll.Position = UDim2.new(0,0,0,0)
		UpdateDropdownPosition()
	end

	task.defer(updateLayout)
	mainFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateLayout)
	mainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
	innerFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateLayout)
	innerFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)

	--==================================================
	-- Section selection + content rerender
	--==================================================
	local function applySectionSelected(btn, selected)
		btn.BackgroundColor3 = currentTheme.Inner
		btn.BackgroundTransparency = selected and INNER_T or 1
	end

	local function clearContent()
		for _, ch in ipairs(contentScroll:GetChildren()) do
			if ch:IsA("GuiObject") and ch ~= bottomSpacer then
				ch:Destroy()
			end
		end
		bottomSpacer.Parent = contentScroll
		ThemeTargets.Rows = {}
	end

	--==================================================
	-- Row factory
	--==================================================
	local function createRow(height)
		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.Text = ""
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1,0,0,height or ROW_H)
		row.ZIndex = 1011
		row.Parent = contentScroll

		local content = Instance.new("Frame")
		content.BorderSizePixel = 0
		content.BackgroundColor3 = currentTheme.Row
		content.BackgroundTransparency = ROW_BG_T
		content.Size = UDim2.new(1,0,1,0)
		content.ZIndex = 1011
		content.Parent = row

		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, ROW_CORNER)
		cc.Parent = content

		local sc = Instance.new("UIScale")
		sc.Scale = 1
		sc.Parent = content

		return row, content, sc
	end

	local function pressFX(content, scaleObj, baseColor)
		content.BackgroundColor3 = brighten(baseColor, 70)
		TweenService:Create(scaleObj, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=0.985}):Play()
		task.delay(0.1, function()
			if content and content.Parent then
				content.BackgroundColor3 = baseColor
			end
			if scaleObj and scaleObj.Parent then
				TweenService:Create(scaleObj, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=1}):Play()
			end
		end)
	end

	--==================================================
	-- Slider active lock
	--==================================================
	local ACTIVE_SLIDER = nil

	--==================================================
	-- Notification firing for element notifications
	--==================================================
	local function FireElementNotifications(notifs, state)
		if typeof(notifs) ~= "table" then return end
		for _,n in ipairs(notifs) do
			if typeof(n) == "table" then
				if shouldNotify(n.When or "Both", state) then
					Notifier:Notify({
						Title = n.Title or "Notification",
						Description = n.Description or "",
						Duration = n.Duration or 2.0,
						TitleColor = n["Title color"] or n.TitleColor,
						TitleFont = n["Title font"] or n.TitleFont,
						DescriptionColor = n["Descr color"] or n.DescriptionColor,
						DescriptionFont = n["Descr font"] or n.DescriptionFont,
					})
				end
			end
		end
	end

	--==================================================
	-- STATE HELPERS (NEW)
	--==================================================
local function initElementState(el)
	local opt = el.Opt or {}

	if el.Type == "Toggle" then
		el.State = el.State or { Value = (opt.Default == true) }

	elseif el.Type == "Slider" then
		local minV = tonumber(opt.Min) or 0
		local maxV = tonumber(opt.Max) or 100
		if maxV < minV then minV, maxV = maxV, minV end
		local inc = tonumber(opt.Increment) or 1
		if inc <= 0 then inc = 1 end

		local function snap(v)
			v = clamp(v, minV, maxV)
			local steps = (v - minV) / inc
			local snapped = minV + (math.floor(steps + 0.5) * inc)
			return clamp(snapped, minV, maxV)
		end

		local def = tonumber(opt.Default)
		if def == nil then def = minV end

		el.State = el.State or { Value = snap(def), Min=minV, Max=maxV, Inc=inc }

	elseif el.Type == "Dropdown" then
		local options = opt.Options
		if typeof(options) ~= "table" then options = {"1","2","3"} end

		local multi = (opt.Multi == true)

		if not multi then
			local def = opt.Default
			if def == nil then def = options[1] end
			el.State = el.State or { Multi=false, Value=tostring(def) }
		else
			local picked = {}
			if typeof(opt.Default) == "table" then
				for _,v in ipairs(opt.Default) do picked[tostring(v)] = true end
			elseif opt.Default ~= nil then
				picked[tostring(opt.Default)] = true
			else
				picked[tostring(options[1])] = true
			end
			el.State = el.State or { Multi=true, Values=picked }
		end

	elseif el.Type == "TextBox" then
		local def = opt.Default
		if def == nil then def = "" end
		el.State = el.State or { Text = tostring(def) }

	elseif el.Type == "ColorPicker" then
		local def = opt.Default
		local c
		if typeof(def) == "Color3" then
			c = def
		elseif typeof(def) == "string" then
			c = parseColorText(def) or ParseColor(def)
		else
			c = ParseColor(def)
		end
		local h,s,v = rgbToHsv(c)
		el.State = el.State or { Color = c, H = h, S = s, V = v }
	end
end
	-- Element Renderers (STATEFUL)
	--==================================================

	--========================
	-- Toggle
	--========================
	local function renderToggle(section, opt, elementRef)
		local row, content = createRow(ROW_H)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = opt.Name or "Toggle"
		label.Font = ParseFont(opt.Font or section.Font or "SourceSansBold")
		label.TextSize = clampTextSize(opt.TextSize, 15)
		label.TextColor3 = ParseColor(opt.Color or section.Color or currentTheme.Text)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Position = UDim2.new(0,10,0,0)
		label.Size = UDim2.new(1,-120,1,0)
		label.ZIndex = 1012
		label.Parent = content

		local DOT = 13
		local PAD = 2
		local pillW = DOT*2 + PAD*2
		local pillH = DOT + PAD*2

		local pill = Instance.new("Frame")
		pill.BorderSizePixel = 0
		pill.AnchorPoint = Vector2.new(1,0.5)
		pill.Position = UDim2.new(1,-10,0.5,0)
		pill.Size = UDim2.new(0,pillW,0,pillH)
		pill.ZIndex = 1012
		pill.Parent = content

		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(1,0)
		pc.Parent = pill

		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = Color3.fromRGB(255,255,255)
		dot.BorderSizePixel = 0
		dot.Size = UDim2.new(0,DOT,0,DOT)
		dot.ZIndex = 1013
		dot.Parent = pill

		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1,0)
		dc.Parent = dot

		local state = elementRef.State -- {Value=bool}

		local function setState(on, instant)
			state.Value = on -- SAVE!
			local leftX = PAD
			local rightX = pillW - DOT - PAD
			local x = on and rightX or leftX
			local col = on and currentTheme.Accent or currentTheme.PillOff

			if instant then
				pill.BackgroundColor3 = col
				dot.Position = UDim2.new(0,x,0.5,-math.floor(DOT/2))
			else
				TweenService:Create(pill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3=col}):Play()
				TweenService:Create(dot, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position=UDim2.new(0,x,0.5,-math.floor(DOT/2))}):Play()
			end
		end

		setState(state.Value, true)

		local function doToggle()
			setState(not state.Value, false)
			if typeof(opt.Callback) == "function" then opt.Callback(state.Value) end
			if elementRef.Notifications then
				FireElementNotifications(elementRef.Notifications, state.Value)
			end
		end

		row.Activated:Connect(doToggle)

		local bindVal = ResolveBindOpt(opt)
		if bindVal then
			RegisterBind(bindVal, function()
				if mainFrame and mainFrame.Parent then
					doToggle()
				end
			end)
		end

		table.insert(ThemeTargets.Rows, {Type="Toggle", Content=content, Label=label, Pill=pill, State=state})
	end

	--========================
	-- Button (fingerprint fixed)
	--========================
	local function renderButton(section, opt, elementRef)
		local row, content, sc = createRow(ROW_H)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = opt.Name or "Button"
		label.Font = ParseFont(opt.Font or section.Font or "SourceSansBold")
		label.TextSize = clampTextSize(opt.TextSize, 15)
		label.TextColor3 = ParseColor(opt.Color or section.Color or currentTheme.Text)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Position = UDim2.new(0,10,0,0)
		label.Size = UDim2.new(1,-60,1,0)
		label.ZIndex = 1012
		label.Parent = content

		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.BorderSizePixel = 0
		icon.Image = ASSET_FINGERPRINT
		icon.ScaleType = Enum.ScaleType.Fit
		icon.AnchorPoint = Vector2.new(1,0.5)
		icon.Position = UDim2.new(1,-10,0.5,0)
		icon.Size = UDim2.new(0,27,0,27)
		icon.ZIndex = 1013
		icon.Parent = content

		local function doPress()
			pressFX(content, sc, currentTheme.Row)
			if typeof(opt.Callback) == "function" then opt.Callback() end
			if elementRef.Notifications then
				FireElementNotifications(elementRef.Notifications, true)
			end
		end

		row.Activated:Connect(doPress)

		local bindVal = ResolveBindOpt(opt)
		if bindVal then
			RegisterBind(bindVal, function()
				if mainFrame and mainFrame.Parent then
					doPress()
				end
			end)
		end

		table.insert(ThemeTargets.Rows, {Type="Button", Content=content, Label=label})
	end

	--========================
	-- Slider (STATEFUL)
	--========================
	local function renderSlider(section, opt, elementRef)
		local minV = tonumber(opt.Min) or 0
		local maxV = tonumber(opt.Max) or 100
		if maxV < minV then minV, maxV = maxV, minV end
		local inc = tonumber(opt.Increment) or 1
		if inc <= 0 then inc = 1 end

		local function snap(v)
			v = clamp(v, minV, maxV)
			local steps = (v - minV) / inc
			local snapped = minV + (math.floor(steps + 0.5) * inc)
			return clamp(snapped, minV, maxV)
		end

		local state = elementRef.State -- {Value=number}
		state.Value = snap(tonumber(state.Value) or (tonumber(opt.Default) or minV)) -- safety

		local row, content = createRow(ROW_H)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = opt.Name or "Slider"
		label.Font = ParseFont(opt.Font or section.Font or "SourceSansBold")
		label.TextSize = clampTextSize(opt.TextSize, 15)
		label.TextColor3 = ParseColor(opt.Color or section.Color or currentTheme.Text)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Position = UDim2.new(0,10,0,0)
		label.Size = UDim2.new(0,70,1,0)
		label.ZIndex = 1012
		label.Parent = content

		local valueBoxW = math.floor(48/1.3 + 0.5)

		local valueBox = Instance.new("Frame")
		valueBox.BorderSizePixel = 0
		valueBox.BackgroundColor3 = currentTheme.ValueBox
		valueBox.AnchorPoint = Vector2.new(1,0.5)
		valueBox.Position = UDim2.new(1,-10,0.5,0)
		valueBox.Size = UDim2.new(0,valueBoxW,0,18)
		valueBox.ZIndex = 1012
		valueBox.Parent = content

		local vbc = Instance.new("UICorner")
		vbc.CornerRadius = UDim.new(0,6)
		vbc.Parent = valueBox

		local valueInput = Instance.new("TextBox")
		valueInput.BackgroundTransparency = 1
		valueInput.BorderSizePixel = 0
		valueInput.ClearTextOnFocus = false
		valueInput.Text = tostring(state.Value)
		valueInput.Font = Enum.Font.SourceSansBold
		valueInput.TextSize = clampTextSize(opt.ValueTextSize, 14)
		valueInput.TextColor3 = Color3.fromRGB(255,255,255)
		valueInput.TextXAlignment = Enum.TextXAlignment.Center
		valueInput.TextYAlignment = Enum.TextYAlignment.Center
		valueInput.Size = UDim2.new(1,0,1,0)
		valueInput.ZIndex = 1013
		valueInput.Parent = valueBox

		local trackH = 5
		local knobD = math.max(7, math.floor(trackH * 1.5 + 0.5))

		local track = Instance.new("Frame")
		track.BorderSizePixel = 0
		track.BackgroundColor3 = currentTheme.PillOff
		track.AnchorPoint = Vector2.new(0,0.5)
		track.Position = UDim2.new(0, 10+70+8, 0.5, 0)
		track.Size = UDim2.new(0, 120, 0, trackH)
		track.ZIndex = 1012
		track.Parent = content

		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1,0)
		tc.Parent = track

		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = currentTheme.Fill
		fill.Size = UDim2.new(0,0,1,0)
		fill.ZIndex = 1013
		fill.Parent = track

		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1,0)
		fc.Parent = fill

		local knob = Instance.new("ImageButton")
		knob.AutoButtonColor = false
		knob.BorderSizePixel = 0
		knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
		knob.AnchorPoint = Vector2.new(0.5,0.5)
		knob.Position = UDim2.new(0,0,0.5,0)
		knob.Size = UDim2.new(0,knobD,0,knobD)
		knob.ZIndex = 1014
		knob.Parent = track

		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(1,0)
		kc.Parent = knob

		local function layoutTrack()
			local cw = content.AbsoluteSize.X
			if cw <= 0 then return end

			local valueLeft = cw - 10 - valueBoxW
			local trackRight = valueLeft - 10
			local fullLeft = 10 + 70 + 8
			local fullW = trackRight - fullLeft
			if fullW < 60 then fullW = 60 end

			local newW = math.floor(fullW * (2/3) + 0.5)
			if newW < 50 then newW = 50 end

			local newLeft = trackRight - newW
			if newLeft < fullLeft then newLeft = fullLeft end

			track.Position = UDim2.new(0,newLeft,0.5,0)
			track.Size = UDim2.new(0,newW,0,trackH)
		end

		content:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTrack)
		task.defer(layoutTrack)

		local function setFromAlpha(a, fire)
			a = clamp(a, 0, 1)
			local raw = minV + a * (maxV - minV)
			local newVal = snap(raw)

			if newVal ~= state.Value then
				state.Value = newVal -- SAVE!
				if fire and typeof(opt.Callback) == "function" then
					opt.Callback(state.Value)
				end
			end

			valueInput.Text = tostring(state.Value)

			local w = track.AbsoluteSize.X
			if w <= 1 then return end
			local x = clamp(((state.Value - minV) / (maxV - minV)) * w, 0, w)
			knob.Position = UDim2.new(0,x,0.5,0)
			fill.Size = UDim2.new(0,x,1,0)
		end

		local function setByScreenX(screenX, fire)
			local left = track.AbsolutePosition.X
			local w = track.AbsoluteSize.X
			if w <= 1 then return end
			setFromAlpha((screenX-left)/w, fire)
		end

		task.defer(function()
			local a = 0
			if maxV ~= minV then a = (state.Value - minV) / (maxV - minV) end
			setFromAlpha(a, false)
		end)

		local dragging = false
		local activeType = nil
		local activeTouchId = nil

		local function beginDrag(input)
			if ACTIVE_SLIDER and ACTIVE_SLIDER ~= row then return end
			ACTIVE_SLIDER = row

			dragging = true
			activeType = input.UserInputType
			activeTouchId = (activeType == Enum.UserInputType.Touch) and getTouchId(input) or nil
			setByScreenX(input.Position.X, true)
		end

		knob.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				beginDrag(input)
			end
		end)
		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				beginDrag(input)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if ACTIVE_SLIDER ~= row then return end

			if activeType == Enum.UserInputType.MouseButton1 then
				if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			else
				if input.UserInputType ~= Enum.UserInputType.Touch then return end
				if activeTouchId ~= nil and getTouchId(input) ~= activeTouchId then return end
			end

			setByScreenX(input.Position.X, true)
		end)

		UserInputService.InputEnded:Connect(function(input)
			if not dragging or ACTIVE_SLIDER ~= row then return end
			if activeType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
				ACTIVE_SLIDER = nil
			elseif activeType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch then
				if activeTouchId == nil or getTouchId(input) == activeTouchId then
					dragging = false
					ACTIVE_SLIDER = nil
				end
			end
		end)

		valueInput.FocusLost:Connect(function()
			local n = tonumber(valueInput.Text)
			if n == nil then
				valueInput.Text = tostring(state.Value)
				return
			end
			n = snap(n)
			if n ~= state.Value then
				state.Value = n -- SAVE!
				if typeof(opt.Callback) == "function" then opt.Callback(state.Value) end
			end
			local a = 0
			if maxV ~= minV then a = (state.Value - minV) / (maxV - minV) end
			setFromAlpha(a, false)
		end)

		table.insert(ThemeTargets.Rows, {Type="Slider", Content=content, Label=label, Track=track, Fill=fill, ValueBox=valueBox})
	end

	--========================
	-- Dropdown (STATEFUL)
	--========================
	local function renderDropdown(section, opt, elementRef)
		local options = opt.Options
		if typeof(options) ~= "table" then options = {"1","2","3"} end

		local multi = (opt.Multi == true)

		local state = elementRef.State
		state.Multi = multi

		local function displayText()
			if not multi then
				return tostring(state.Value or options[1])
			end
			local arr = {}
			for _,v in ipairs(options) do
				if state.Values and state.Values[tostring(v)] then
					table.insert(arr, tostring(v))
				end
			end
			if #arr == 0 then return "None" end
			if #arr > 3 then return tostring(#arr).." selected" end
			return table.concat(arr, ", ")
		end

		if not multi then
			if state.Value == nil then
				local def = opt.Default
				if def == nil then def = options[1] end
				state.Value = tostring(def)
			end
		else
			state.Values = state.Values or {}
			-- если пусто вообще — подстрахуем
			local any = false
			for _,v in pairs(state.Values) do
				if v == true then any = true break end
			end
			if not any then
				local def = opt.Default
				if typeof(def) == "table" then
					for _,vv in ipairs(def) do state.Values[tostring(vv)] = true end
				elseif def ~= nil then
					state.Values[tostring(def)] = true
				else
					state.Values[tostring(options[1])] = true
				end
			end
		end

		local row, content = createRow(ROW_H)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = opt.Name or "Dropdown"
		label.Font = ParseFont(opt.Font or section.Font or "SourceSansBold")
		label.TextSize = clampTextSize(opt.TextSize, 15)
		label.TextColor3 = ParseColor(opt.Color or section.Color or currentTheme.Text)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Position = UDim2.new(0,10,0,0)
		label.Size = UDim2.new(1,-130,1,0)
		label.ZIndex = 1012
		label.Parent = content

		local selectBtn = Instance.new("TextButton")
		selectBtn.AutoButtonColor = false
		selectBtn.BorderSizePixel = 0
		selectBtn.BackgroundColor3 = currentTheme.ValueBox
		selectBtn.BackgroundTransparency = 0
		selectBtn.Text = displayText()
		selectBtn.Font = Enum.Font.SourceSansBold
		selectBtn.TextSize = clampTextSize(opt.ValueTextSize, 14)
		selectBtn.TextColor3 = Color3.fromRGB(255,255,255)
		selectBtn.AnchorPoint = Vector2.new(1,0.5)
		selectBtn.Position = UDim2.new(1,-10,0.5,0)
		selectBtn.Size = UDim2.new(0,110,0,22)
		selectBtn.ZIndex = 1013
		selectBtn.Parent = content

		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0,6)
		sc.Parent = selectBtn

		local function fireCallback()
			if typeof(opt.Callback) ~= "function" then return end
			if not multi then
				opt.Callback(tostring(state.Value))
			else
				local out = {}
				for _,v in ipairs(options) do
					if state.Values and state.Values[tostring(v)] then
						table.insert(out, tostring(v))
					end
				end
				opt.Callback(out)
			end
		end

		local function openMenu()
			CloseDropdown()

			local menu = Instance.new("Frame")
			menu.BorderSizePixel = 0
			menu.BackgroundColor3 = currentTheme.ValueBox
			menu.BackgroundTransparency = 0.3
			menu.ZIndex = 5000
			menu.Parent = screenGui

			local mc = Instance.new("UICorner")
			mc.CornerRadius = UDim.new(0,8)
			mc.Parent = menu

			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0,6)
			pad.PaddingBottom = UDim.new(0,6)
			pad.PaddingLeft = UDim.new(0,6)
			pad.PaddingRight = UDim.new(0,6)
			pad.Parent = menu

			local maxVisible = 6
			local itemH = 22
			local itemGap = 4
			local visible = math.min(#options, maxVisible)
			local viewH = (visible * itemH) + ((visible-1)*itemGap)

			local host
			if #options > maxVisible then
				local s = Instance.new("ScrollingFrame")
				s.BackgroundTransparency = 1
				s.BorderSizePixel = 0
				s.ScrollBarThickness = 0
				s.ScrollingDirection = Enum.ScrollingDirection.Y
				s.AutomaticCanvasSize = Enum.AutomaticSize.Y
				s.CanvasSize = UDim2.new(0,0,0,0)
				s.Size = UDim2.new(1,0,0,viewH)
				s.ZIndex = 5001
				s.Parent = menu
				host = s
			else
				local f = Instance.new("Frame")
				f.BackgroundTransparency = 1
				f.BorderSizePixel = 0
				f.Size = UDim2.new(1,0,0,viewH)
				f.ZIndex = 5001
				f.Parent = menu
				host = f
			end

			local list = Instance.new("UIListLayout")
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.Padding = UDim.new(0,itemGap)
			list.Parent = host

			for i,optVal in ipairs(options) do
				local s = tostring(optVal)

				local b = Instance.new("TextButton")
				b.AutoButtonColor = false
				b.BorderSizePixel = 0
				b.BackgroundColor3 = currentTheme.Row
				b.BackgroundTransparency = ROW_BG_T
				b.Text = s
				b.Font = Enum.Font.SourceSansBold
				b.TextSize = clampTextSize(opt.ValueTextSize, 14)
				b.TextColor3 = Color3.fromRGB(255,255,255)
				b.Size = UDim2.new(1,0,0,itemH)
				b.LayoutOrder = i
				b.ZIndex = 5002
				b.Parent = host

				local bc = Instance.new("UICorner")
				bc.CornerRadius = UDim.new(0,6)
				bc.Parent = b

				local function refresh()
					if not multi then
						b.BackgroundColor3 = (s == tostring(state.Value)) and brighten(currentTheme.Row, 25) or currentTheme.Row
					else
						b.BackgroundColor3 = (state.Values and state.Values[s] == true) and brighten(currentTheme.Row, 25) or currentTheme.Row
					end
				end
				refresh()

				b.Activated:Connect(function()
					if not multi then
						state.Value = s -- SAVE!
						selectBtn.Text = displayText()
						fireCallback()
						CloseDropdown()
						return
					end
					state.Values = state.Values or {}
					state.Values[s] = not state.Values[s] -- SAVE!
					selectBtn.Text = displayText()
					fireCallback()
					refresh()
				end)
			end

			menu.Size = UDim2.new(0,180,0,6+viewH+6)

			DropdownManager.Menu = menu
			DropdownManager.Anchor = selectBtn
			UpdateDropdownPosition()
		end

		selectBtn.Activated:Connect(function()
			if DropdownManager.Menu and DropdownManager.Anchor == selectBtn then
				CloseDropdown()
			else
				openMenu()
			end
		end)

		table.insert(ThemeTargets.Rows, {Type="Dropdown", Content=content, Label=label, SelectBtn=selectBtn})
	end

	--========================
	-- TextBox (STATEFUL)
	--========================
	local function renderTextBox(section, opt, elementRef)
		local state = elementRef.State -- {Text=string}

		local row, content = createRow(ROW_H)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = opt.Name or "Text Box"
		label.Font = ParseFont(opt.Font or section.Font or "SourceSansBold")
		label.TextSize = clampTextSize(opt.TextSize, 15)
		label.TextColor3 = ParseColor(opt.Color or section.Color or currentTheme.Text)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Position = UDim2.new(0,10,0,0)
		label.Size = UDim2.new(1,-140,1,0)
		label.ZIndex = 1012
		label.Parent = content

		local boxW = 111
		local box = Instance.new("Frame")
		box.BorderSizePixel = 0
		box.BackgroundColor3 = currentTheme.ValueBox
		box.AnchorPoint = Vector2.new(1,0.5)
		box.Position = UDim2.new(1,-10,0.5,0)
		box.Size = UDim2.new(0,boxW,0,22)
		box.ZIndex = 1012
		box.Parent = content

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0,6)
		bc.Parent = box

		local input = Instance.new("TextBox")
		input.BackgroundTransparency = 1
		input.BorderSizePixel = 0
		input.ClearTextOnFocus = false
		input.Font = Enum.Font.SourceSansBold
		input.TextSize = clampTextSize(opt.ValueTextSize, 14)
		input.TextXAlignment = Enum.TextXAlignment.Center
		input.TextYAlignment = Enum.TextYAlignment.Center
		input.Size = UDim2.new(1,0,1,0)
		input.ZIndex = 1013
		input.Parent = box

		local txt = tostring(state.Text or "")
		if txt == "" then
			input.Text = ""
			input.PlaceholderText = "..."
		else
			input.Text = txt
			input.PlaceholderText = "..."
		end

		input.PlaceholderColor3 = Color3.fromRGB(255,255,255)
		input.TextColor3 = Color3.fromRGB(255,255,255)
		input.TextTransparency = 0.45

		input.Focused:Connect(function()
			input.TextTransparency = 0
		end)
		input.FocusLost:Connect(function()
			state.Text = input.Text -- SAVE!
			input.TextTransparency = 0.45
			if typeof(opt.Callback) == "function" then opt.Callback(state.Text) end
		end)

		table.insert(ThemeTargets.Rows, {Type="TextBox", Content=content, Label=label, InputBox=box})
	end

	--========================
	-- Label
	--========================
	local function renderLabel(section, opt)
		local lines = tonumber(opt.Lines) or 3
		if lines < 1 then lines = 1 end
		local rowH = 16 + (lines * 14)

		local row, content = createRow(rowH)

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.BorderSizePixel = 0
		text.TextWrapped = true
		text.Text = opt.Text or "Label"
		text.Font = ParseFont(opt.Font or section.Font or "SourceSans")
		text.TextSize = clampTextSize(opt.TextSize, 13)
		text.TextColor3 = ParseColor(opt.Color or section.Color or currentTheme.Muted)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.Position = UDim2.new(0,10,0,10)
		text.Size = UDim2.new(1,-20,1,-20)
		text.ZIndex = 1012
		text.Parent = content

		table.insert(ThemeTargets.Rows, {Type="Label", Content=content, Muted=text})
	end

	--========================
	-- HeadText
	--========================
	local function renderHeadText(section, opt)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1,0,0,30)
		row.ZIndex = 1011
		row.Parent = contentScroll

		local head = Instance.new("TextLabel")
		head.BackgroundTransparency = 1
		head.BorderSizePixel = 0
		head.Text = opt.Text or "Head Text"
		head.Font = ParseFont(opt.Font or section.Font or "SourceSansBold")
		head.TextSize = clampTextSize(opt.TextSize, 16)
		head.TextColor3 = ParseColor(opt.Color or section.Color or currentTheme.Text)
		head.TextXAlignment = Enum.TextXAlignment.Center
		head.TextYAlignment = Enum.TextYAlignment.Center
		head.Size = UDim2.new(0,110,0,12)
		head.AnchorPoint = Vector2.new(0.5,0.5)
		head.Position = UDim2.new(0.5,0,0.5,0)
		head.ZIndex = 1013
		head.Parent = row

		local showLines = (opt.Lines ~= false)
		local lineColor = ParseColor(opt.LineColor or currentTheme.Lines)

		local leftLine = Instance.new("Frame")
		leftLine.BorderSizePixel = 0
		leftLine.BackgroundColor3 = lineColor
		leftLine.Visible = showLines
		leftLine.ZIndex = 1012
		leftLine.Parent = row

		local leftCorner = Instance.new("UICorner")
		leftCorner.CornerRadius = UDim.new(1,0)
		leftCorner.Parent = leftLine

		local rightLine = Instance.new("Frame")
		rightLine.BorderSizePixel = 0
		rightLine.BackgroundColor3 = lineColor
		rightLine.Visible = showLines
		rightLine.ZIndex = 1012
		rightLine.Parent = row

		local rightCorner = Instance.new("UICorner")
		rightCorner.CornerRadius = UDim.new(1,0)
		rightCorner.Parent = rightLine

		local function layoutLines()
			if not showLines then return end
			local w = row.AbsoluteSize.X
			if w <= 0 then return end
			local innerPad = 5
			local gap = 5
			local headW = 110
			local available = w - (innerPad*2) - headW - (gap*2)
			local lineW = math.max(10, math.floor(available/2))
			leftLine.Size = UDim2.new(0,lineW,0,2)
			leftLine.Position = UDim2.new(0, innerPad, 0.5, -1)
			rightLine.Size = UDim2.new(0,lineW,0,2)
			rightLine.Position = UDim2.new(1, -innerPad-lineW, 0.5, -1)
		end

		task.defer(layoutLines)
		row:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLines)

		table.insert(ThemeTargets.Rows, {Type="HeadText", LeftLine=leftLine, RightLine=rightLine, Label=head})
	end
	--========================
	-- Separator (inside section content)
	--========================
	local function renderSeparator()
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Size = UDim2.new(1,0,0,14)
		holder.ZIndex = 1011
		holder.Parent = contentScroll

		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = (currentTheme.Separator or currentTheme.Lines)
		bar.AnchorPoint = Vector2.new(0.5,0.5)
		bar.Position = UDim2.new(0.5,0,0.5,0)
		bar.Size = UDim2.new(1,0,0,2)
		bar.ZIndex = 1012
		bar.Parent = holder

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1,0)
		c.Parent = bar

		table.insert(ThemeTargets.Rows, {Type="Separator", Bar=bar})
	end

	--========================
	-- ColorPicker (STATEFUL)
	--========================
	local function renderColorPicker(section, opt, elementRef)
		local state = elementRef.State -- {Color, H, S, V}

		local rowH = 70
		local row, content = createRow(rowH)

		local titleLbl = Instance.new("TextLabel")
		titleLbl.BackgroundTransparency = 1
		titleLbl.BorderSizePixel = 0
		titleLbl.Text = opt.Name or "Color Picker"
		titleLbl.Font = ParseFont(opt.Font or section.Font or "SourceSans")
		titleLbl.TextSize = clampTextSize(opt.TextSize, 12)
		titleLbl.TextColor3 = currentTheme.Text
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.TextYAlignment = Enum.TextYAlignment.Top
		titleLbl.Position = UDim2.new(0,10,0,8)
		titleLbl.Size = UDim2.new(1,-20,0,14)
		titleLbl.ZIndex = 1012
		titleLbl.Parent = content

		local previewSize = 22
		local trackH = 6
		local knobD = 10
		local inputW = 130
		local gap = 10
		local controlsY = 34
		local yCenter = controlsY + math.floor(previewSize/2)

		local preview = Instance.new("Frame")
		preview.BorderSizePixel = 0
		preview.BackgroundColor3 = state.Color
		preview.Position = UDim2.new(0,10,0,controlsY)
		preview.Size = UDim2.new(0,previewSize,0,previewSize)
		preview.ZIndex = 1012
		preview.Parent = content

		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0,6)
		pc.Parent = preview

		local inputBox = Instance.new("Frame")
		inputBox.BorderSizePixel = 0
		inputBox.BackgroundColor3 = currentTheme.ValueBox
		inputBox.AnchorPoint = Vector2.new(1,0)
		inputBox.Position = UDim2.new(1,-10,0,controlsY)
		inputBox.Size = UDim2.new(0,inputW,0,previewSize)
		inputBox.ZIndex = 1012
		inputBox.Parent = content

		local ibc = Instance.new("UICorner")
		ibc.CornerRadius = UDim.new(0,6)
		ibc.Parent = inputBox

		local input = Instance.new("TextBox")
		input.BackgroundTransparency = 1
		input.BorderSizePixel = 0
		input.ClearTextOnFocus = false
		input.Text = rgbText(state.Color)
		input.Font = Enum.Font.SourceSansBold
		input.TextSize = clampTextSize(opt.ValueTextSize, 13)
		input.TextColor3 = Color3.fromRGB(255,255,255)
		input.TextTransparency = 0.45
		input.TextXAlignment = Enum.TextXAlignment.Center
		input.TextYAlignment = Enum.TextYAlignment.Center
		input.Size = UDim2.new(1,0,1,0)
		input.ZIndex = 1013
		input.Parent = inputBox

		local track = Instance.new("Frame")
		track.BorderSizePixel = 0
		track.BackgroundColor3 = Color3.fromRGB(255,255,255)
		track.AnchorPoint = Vector2.new(0,0.5)
		track.Position = UDim2.new(0, 10 + previewSize + gap, 0, yCenter)
		track.Size = UDim2.new(1, -(10 + previewSize + gap + gap + inputW + 10), 0, trackH)
		track.ZIndex = 1012
		track.Parent = content

		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1,0)
		tc.Parent = track

		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,255,255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,0)),
		})
		grad.Parent = track

		local knob = Instance.new("ImageButton")
		knob.AutoButtonColor = false
		knob.BorderSizePixel = 0
		knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
		knob.AnchorPoint = Vector2.new(0.5,0.5)
		knob.Position = UDim2.new(0,0,0.5,0)
		knob.Size = UDim2.new(0,knobD,0,knobD)
		knob.ZIndex = 1014
		knob.Parent = track

		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(1,0)
		kc.Parent = knob

		local function syncKnob()
			local w = track.AbsoluteSize.X
			if w <= 1 then return end
			local x = clamp((state.H or 0) * w, 0, w)
			knob.Position = UDim2.new(0,x,0.5,0)
		end

		local function setHueFromAlpha(a, fire)
			a = clamp(a, 0, 1)
			state.H = a
			state.S = 1
			state.V = 1
			state.Color = hsvToRgb(state.H, state.S, state.V)
			preview.BackgroundColor3 = state.Color
			input.Text = rgbText(state.Color)

			if fire and typeof(opt.Callback) == "function" then
				opt.Callback(state.Color)
			end
			syncKnob()
		end

		local function setHueByScreenX(screenX, fire)
			local left = track.AbsolutePosition.X
			local w = track.AbsoluteSize.X
			if w <= 1 then return end
			setHueFromAlpha((screenX - left) / w, fire)
		end

		-- initial sync from current color
		do
			local h,s,v = rgbToHsv(state.Color)
			state.H, state.S, state.V = h,s,v
			syncKnob()
		end

		track:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncKnob)

		local dragging = false
		local activeType = nil
		local activeTouchId = nil

		local function beginDrag(inputObj)
			if ACTIVE_SLIDER and ACTIVE_SLIDER ~= row then return end
			ACTIVE_SLIDER = row

			dragging = true
			activeType = inputObj.UserInputType
			activeTouchId = (activeType == Enum.UserInputType.Touch) and getTouchId(inputObj) or nil
			setHueByScreenX(inputObj.Position.X, true)
		end

		knob.InputBegan:Connect(function(inputObj)
			if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
				beginDrag(inputObj)
			end
		end)
		track.InputBegan:Connect(function(inputObj)
			if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
				beginDrag(inputObj)
			end
		end)

		UserInputService.InputChanged:Connect(function(inputObj)
			if not dragging then return end
			if ACTIVE_SLIDER ~= row then return end

			if activeType == Enum.UserInputType.MouseButton1 then
				if inputObj.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			else
				if inputObj.UserInputType ~= Enum.UserInputType.Touch then return end
				if activeTouchId ~= nil and getTouchId(inputObj) ~= activeTouchId then return end
			end

			setHueByScreenX(inputObj.Position.X, true)
		end)

		UserInputService.InputEnded:Connect(function(inputObj)
			if not dragging or ACTIVE_SLIDER ~= row then return end

			if activeType == Enum.UserInputType.MouseButton1 and inputObj.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
				ACTIVE_SLIDER = nil
			elseif activeType == Enum.UserInputType.Touch and inputObj.UserInputType == Enum.UserInputType.Touch then
				if activeTouchId == nil or getTouchId(inputObj) == activeTouchId then
					dragging = false
					ACTIVE_SLIDER = nil
				end
			end
		end)

		input.Focused:Connect(function()
			input.TextTransparency = 0
		end)

		input.FocusLost:Connect(function()
			local typed = input.Text
			local c = parseColorText(typed) or ParseColor(typed)
			if typeof(c) == "Color3" then
				state.Color = c
				local h,s,v = rgbToHsv(c)
				state.H, state.S, state.V = h,s,v
				preview.BackgroundColor3 = state.Color
				input.Text = rgbText(state.Color)
				syncKnob()
				if typeof(opt.Callback) == "function" then
					opt.Callback(state.Color)
				end
			else
				-- revert
				input.Text = rgbText(state.Color)
				syncKnob()
			end
			input.TextTransparency = 0.45
		end)

		table.insert(ThemeTargets.Rows, {
			Type="ColorPicker",
			Content=content,
			Preview=preview,
			Track=track,
			InputBox=inputBox,
			Title=titleLbl,
			Label=titleLbl,
			State=state
		})

	end

	--==================================================
	-- Section rendering
	--==================================================
	local function renderSection(section)
		clearContent()
		for _, el in ipairs(section._elements) do
			if el.Type == "Toggle" then renderToggle(section, el.Opt, el)
			elseif el.Type == "Button" then renderButton(section, el.Opt, el)
			elseif el.Type == "Slider" then renderSlider(section, el.Opt, el)
			elseif el.Type == "Dropdown" then renderDropdown(section, el.Opt, el)
			elseif el.Type == "TextBox" then renderTextBox(section, el.Opt, el)
			elseif el.Type == "Label" then renderLabel(section, el.Opt)
			elseif el.Type == "HeadText" then renderHeadText(section, el.Opt)
			elseif el.Type == "Separator" then renderSeparator()
			elseif el.Type == "ColorPicker" then renderColorPicker(section, el.Opt, el)
			end
		end
		ApplyTheme(currentTheme)
	end

	local function setSelected(idx)
		CloseDropdown()
		if Window._selectedIndex == idx then return end
		if Window._selectedIndex then
			local oldBtn = Window._sectionButtons[Window._selectedIndex]
			if oldBtn then applySectionSelected(oldBtn, false) end
		end
		Window._selectedIndex = idx
		local btn = Window._sectionButtons[idx]
		if btn then applySectionSelected(btn, true) end
		local section = Window.Sections[idx]
		if section then renderSection(section) end
	end

	--==================================================
	--==================================================
	-- Window separator (left list)
	--==================================================
	function Window:AddSeparator()
		Window._leftOrder = (Window._leftOrder or 0) + 1

		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Size = UDim2.new(1,0,0,10)
		holder.LayoutOrder = Window._leftOrder
		holder.ZIndex = 1002
		holder.Parent = sectionsPanel

		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = (currentTheme.Separator or currentTheme.Lines)
		bar.AnchorPoint = Vector2.new(0.5,0.5)
		bar.Position = UDim2.new(0.5,0,0.5,0)
		bar.Size = UDim2.new(1,0,0,2)
		bar.ZIndex = 1003
		bar.Parent = holder

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1,0)
		c.Parent = bar

		table.insert(ThemeTargets.SectionSeparators, bar)
		return bar
	end

	-- AddSection API
	--==================================================
	function Window:AddSection(opt)
		opt = opt or {}
		local section = {}
		section.Name = opt.Name or "Section"
		section.Font = ParseFont(opt.Font or "SourceSans")
		section.Color = ParseColor(opt.Color or "#ffffff")
		section._elements = {}
		section._lastElement = nil

		table.insert(Window.Sections, section)
		local idx = #Window.Sections

		
local function pushElement(el)
	el.Notifications = el.Notifications or {}
	el.Opt = el.Opt or {}
	initElementState(el) -- persistent state once
	table.insert(section._elements, el)
	section._lastElement = el

	-- tiny element API (so callers can update after creation, e.g. Dropdown options)
	local api = {}
	api.Element = el

	function api:SetOptions(opts)
		el.Opt.Options = opts
		if Window._selectedIndex == idx then
			renderSection(section)
		end
	end

	function api:SetValue(v)
		-- stores in persistent state; renderer reads from el.State
		el.State = el.State or {}
		el.State.Value = v
		if Window._selectedIndex == idx then
			renderSection(section)
		end
	end

	-- render only if this section is visible right now
	if Window._selectedIndex == idx then
		renderSection(section)
	end

	return api
end

function section:AddToggle(t)     return pushElement({Type="Toggle",     Opt=t or {}}) end
function section:AddButton(t)     return pushElement({Type="Button",     Opt=t or {}}) end
function section:AddSlider(t)     return pushElement({Type="Slider",     Opt=t or {}}) end
function section:AddDropdown(t)   return pushElement({Type="Dropdown",   Opt=t or {}}) end
function section:AddTextBox(t)    return pushElement({Type="TextBox",    Opt=t or {}}) end
function section:AddLabel(t)      return pushElement({Type="Label",      Opt=t or {}}) end
function section:AddHeadText(t)   return pushElement({Type="HeadText",   Opt=t or {}}) end
function section:AddSeparator()   return pushElement({Type="Separator",  Opt={}}) end
function section:AddColorPicker(t)return pushElement({Type="ColorPicker",Opt=t or {}}) end

function section:AddNotification(n)
			if not section._lastElement then return end
			section._lastElement.Notifications = section._lastElement.Notifications or {}
			table.insert(section._lastElement.Notifications, n or {})
		end

		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Text = section.Name
		b.Font = Enum.Font.SourceSans
		b.TextSize = 12
		b.TextColor3 = currentTheme.Title
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Size = UDim2.new(1,0,0,24)
		Window._leftOrder = (Window._leftOrder or 0) + 1
		b.LayoutOrder = Window._leftOrder
		b.ZIndex = 1003
		b.Parent = sectionsPanel

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0,12)
		pad.PaddingRight = UDim.new(0,2)
		pad.Parent = b

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, INNER_CORNER)
		c.Parent = b

		applySectionSelected(b, false)
		b.Activated:Connect(function() setSelected(idx) end)

		Window._sectionButtons[idx] = b
		table.insert(ThemeTargets.SectionButtons, b)

		if Window._selectedIndex == nil then
			setSelected(1)
		end

		return section
	end

	--==================================================
	-- Optional Theme Section
	--==================================================
	
	--==================================================
	-- Optional Theme Section (controls live ONLY here)
	--==================================================
	if settings.ThemeSection == true then
		local themeSection = Window:AddSection({Name="Themes", Font="SourceSans", Color="#ffffff"})

		local function themeNames()
			local names = {}
			for _,t in ipairs(Themes) do table.insert(names, t.Name) end
			return names
		end

		local themeDropdown = themeSection:AddDropdown({
			Name = "Theme",
			Options = themeNames(),
			Default = currentTheme.Name,
			Multi = false,
			Callback = function(name)
				Window:SetTheme(name)
			end
		})

		-- Expose a tiny API so Window:AddTheme can refresh dropdown
		Window._themeDropdownApi = {
			RefreshOptions = function(self)
				-- try common patterns without breaking visuals
				if themeDropdown and themeDropdown.SetOptions then
					themeDropdown:SetOptions(themeNames())
				elseif themeDropdown and themeDropdown.Api and themeDropdown.Api.RefreshOptions then
					themeDropdown.Api:RefreshOptions()
				end
			end
		}

		-- Sliders to tweak transparencies (stored in current theme)
		themeSection:AddSlider({
			Name = "Main Transparency",
			Min = 0,
			Max = 1,
			Default = currentTheme.MainT or MAIN_T,
			Increment = 0.01,
			Callback = function(v)
				currentTheme.MainT = v
				ApplyTheme(currentTheme)
			end
		})

		themeSection:AddSlider({
			Name = "Inner Transparency",
			Min = 0,
			Max = 1,
			Default = currentTheme.InnerT or INNER_T,
			Increment = 0.01,
			Callback = function(v)
				currentTheme.InnerT = v
				ApplyTheme(currentTheme)
			end
		})

		
		-- Button/Row background controls
		themeSection:AddSlider({
			Name = "Row Transparency",
			Min = 0,
			Max = 1,
			Default = currentTheme.RowT or currentTheme.InnerT or INNER_T,
			Increment = 0.01,
			Callback = function(v)
				currentTheme.RowT = v
				ApplyTheme(currentTheme)
			end
		})

themeSection:AddSlider({
			Name = "Image Transparency",
			Min = 0,
			Max = 1,
			Default = currentTheme.BgImageT or 0.85,
			Increment = 0.01,
			Callback = function(v)
				currentTheme.BgImageT = v
				ApplyTheme(currentTheme)
			end
		})

		-- Text color picker override (doesn't touch theme backgrounds)
		themeSection:AddColorPicker({
			Name = "Select Ui Text Color",
			Default = string.format("%d, %d, %d",
				math.floor((currentTheme.Text and currentTheme.Text.R*255) or 255),
				math.floor((currentTheme.Text and currentTheme.Text.G*255) or 255),
				math.floor((currentTheme.Text and currentTheme.Text.B*255) or 255)
			),
			Font = "SourceSans",
			TextSize = 12,
			Callback = function(c3)
				Window._uiTextOverride = c3
				ApplyTheme(currentTheme)
			end
		})
		-- Reset UI text color override back to element-defined colors
		themeSection:AddButton({
			Name = "Reset Color",
			Font = "SourceSansBold",
			Color = "255,255,255",
			TextSize = 12,
			Callback = function()
				Window._uiTextOverride = nil
				ApplyTheme(currentTheme)
			end
		})

	end

	ApplyTheme(currentTheme)

	--==================================================
	-- Close / Minimize handlers
	--==================================================
	closeBtn.Activated:Connect(function()
		press1px(closeBtn)
		CloseDropdown()
		task.delay(0.12, function()
			if screenGui then screenGui:Destroy() end
		end)
	end)

	minusBtn.Activated:Connect(function()
		press1px(minusBtn)
		CloseDropdown()
		task.delay(0.12, function()
			mainFrame.Visible = false
			openPill.Visible = true
		end)
	end)

	--==================================================
	-- Drag pill ONLY by arrows (MULTI-TOUCH SAFE)
	--==================================================
	do
		local dragging = false
		local startPos
		local dragStart
		local activeInput
		local activeIsMouse = false

		arrowsBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				activeIsMouse = true
				activeInput = input
				dragStart = input.Position
				startPos = openPill.Position
			elseif input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				activeIsMouse = false
				activeInput = input
				dragStart = input.Position
				startPos = openPill.Position
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging or not dragStart or not startPos then return end

			if activeIsMouse then
				if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			else
				if input ~= activeInput then return end
			end

			local delta = input.Position - dragStart
			openPill.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end)

		UserInputService.InputEnded:Connect(function(input)
			if not dragging then return end

			if activeIsMouse then
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
					activeInput = nil
				end
			else
				if input == activeInput then
					dragging = false
					activeInput = nil
				end
			end
		end)
	end

	--==================================================
	-- Main drag (MULTI-TOUCH SAFE)
	--==================================================
	do
		local dragging = false
		local startPos
		local dragStart
		local activeInput
		local activeIsMouse = false

		mainFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				activeIsMouse = true
				activeInput = input
				dragStart = input.Position
				startPos = mainFrame.Position
			elseif input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				activeIsMouse = false
				activeInput = input
				dragStart = input.Position
				startPos = mainFrame.Position
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging or not dragStart or not startPos then return end

			if activeIsMouse then
				if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			else
				if input ~= activeInput then return end
			end

			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)

			UpdateDropdownPosition()
		end)

		UserInputService.InputEnded:Connect(function(input)
			if not dragging then return end

			if activeIsMouse then
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
					activeInput = nil
				end
			else
				if input == activeInput then
					dragging = false
					activeInput = nil
				end
			end
		end)
	end


function Window:AddKeySystem(cfg)
	cfg = cfg or {}

	local correctKey = tostring(cfg.Key or "")
	local buttons = cfg.Buttons or {}

	-- Hide all content until key accepted
	innerFrame.Visible = false
	if sectionsPanel then sectionsPanel.Visible = false end

	-- Holder
	local holder = Instance.new("Frame")
	holder.Name = "KeySystemHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.Parent = mainFrame
	holder.ZIndex = 2000

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = holder

	-- Title centered
	local title = Instance.new("TextLabel")
	title.Name = "KeyTitle"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(0.8, 0, 0, 30)
	title.Text = "Enter the Key:"
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.ZIndex = 2001
	title.Parent = holder

	-- Input box
	local input = Instance.new("TextBox")
	input.Name = "KeyInput"
	input.Size = UDim2.new(0.8, 0, 0, 35)
	input.BackgroundColor3 = currentTheme.Row
	input.BackgroundTransparency = INNER_T
	input.BorderSizePixel = 0
	input.TextColor3 = Color3.fromRGB(255, 255, 255)
	input.Text = ""
	input.PlaceholderText = ""
	input.ClearTextOnFocus = false
	input.Font = Enum.Font.SourceSans
	input.TextSize = 16
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.ZIndex = 2001
	input.Parent = holder

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 14)
	inputCorner.Parent = input

	local inputPad = Instance.new("UIPadding")
	inputPad.PaddingLeft = UDim.new(0, 12)
	inputPad.PaddingRight = UDim.new(0, 12)
	inputPad.Parent = input

	-- Status label INSIDE the TextBox (centered)
	local status = Instance.new("TextLabel")
	status.Name = "KeyStatus"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -24, 1, 0)
	status.Position = UDim2.new(0, 12, 0, 0)
	status.Text = ""
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextYAlignment = Enum.TextYAlignment.Center
	status.Font = Enum.Font.SourceSansBold
	status.TextSize = 16
	status.TextColor3 = Color3.fromRGB(255, 255, 255)
	status.TextTransparency = 1
	status.ZIndex = 2002
	status.Parent = input

	-- Buttons grid (always below)
	local grid = Instance.new("Frame")
	grid.Name = "KeyButtons"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(0.8, 0, 0, 90)
	grid.ZIndex = 2001
	grid.Parent = holder

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.48, 0, 0, 36)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.Parent = grid

	local function makeKeyButton(bcfg, idx)
		local btn = Instance.new("TextButton")
		btn.Name = "KeyBtn_" .. tostring(idx)
		btn.BackgroundColor3 = ParseColor(bcfg.BackgroundColor or "60,60,80")
		btn.BackgroundTransparency = tonumber(bcfg.BackgroundTransparency or 0)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.ZIndex = 2002
		btn.Parent = grid

		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 14)
		bc.Parent = btn

		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.new(1, 0, 1, 0)
		inner.ZIndex = 2003
		inner.Parent = btn

		local il = Instance.new("UIListLayout")
		il.FillDirection = Enum.FillDirection.Horizontal
		il.HorizontalAlignment = Enum.HorizontalAlignment.Left
		il.VerticalAlignment = Enum.VerticalAlignment.Center
		il.Padding = UDim.new(0, 10) -- <-- space between icon and text
		il.Parent = inner

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = inner

		if bcfg.Icon and bcfg.Icon ~= "" then
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Size = UDim2.new(0, 18, 0, 18)
			icon.Image = "rbxassetid://" .. tostring(bcfg.Icon)
			icon.ZIndex = 2004
			icon.Parent = inner
		else
			local spacer = Instance.new("Frame")
			spacer.BackgroundTransparency = 1
			spacer.Size = UDim2.new(0, 18, 0, 18)
			spacer.Parent = inner
		end

		local txt = Instance.new("TextLabel")
		txt.BackgroundTransparency = 1
		txt.Size = UDim2.new(1, -40, 1, 0)
		txt.Text = bcfg.Text or ("Button " .. tostring(idx))
		txt.TextColor3 = ParseColor(bcfg.TextColor or "255,255,255")
		txt.Font = Enum.Font.SourceSans
		txt.TextSize = 14
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.TextYAlignment = Enum.TextYAlignment.Center
		txt.ZIndex = 2004
		txt.Parent = inner

		btn.MouseButton1Click:Connect(function()
			if bcfg.CopyContent then
				pcall(function()
					setclipboard(tostring(bcfg.CopyContent))
				end)
			end
		end)
	end

	for i = 1, math.min(4, #buttons) do
		makeKeyButton(buttons[i], i)
	end

	local busy = false

	local function showStatus(text)
		status.Text = text
		status.TextTransparency = 1
		local t = TweenService:Create(status, TweenInfo.new(0.5), {TextTransparency = 0})
		t:Play()
		t.Completed:Wait()
	end

	local function hideStatus()
		local t = TweenService:Create(status, TweenInfo.new(0.35), {TextTransparency = 1})
		t:Play()
		t.Completed:Wait()
		status.Text = ""
	end

	input.FocusLost:Connect(function(enterPressed)
		if not enterPressed then return end
		if busy then return end
		busy = true

		local typed = input.Text or ""
		-- clear typed text so it doesn't mix with status text
		input.Text = ""

		if typed == correctKey then
			input.TextEditable = false
			showStatus("The key is correct")
			task.wait(2)
			holder:Destroy()
			innerFrame.Visible = true
			if sectionsPanel then sectionsPanel.Visible = true end
		else
			showStatus("The key is incorrect")
			task.wait(2)
			hideStatus()
			input.TextEditable = true
		end

		busy = false
	end)
end


	return Window
end

return setmetatable({}, XuilanLib)

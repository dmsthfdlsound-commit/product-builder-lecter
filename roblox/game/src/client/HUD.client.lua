--------------------------------------------------------------------
-- +1 Pop! HUD — Speed 카운터 + 전광판 배너 + 트레일 상점 (v0.2)
-- StarterPlayerScripts (LocalScript)
--------------------------------------------------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local stats = player:WaitForChild("leaderstats")
local speed = stats:WaitForChild("Speed")
local wins = stats:WaitForChild("Wins")
local rebirths = stats:WaitForChild("Rebirths")

local gui = Instance.new("ScreenGui")
gui.Name = "Plus1HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- 큰 스피드 카운터
local counter = Instance.new("TextLabel")
counter.AnchorPoint = Vector2.new(0.5, 0)
counter.Position = UDim2.fromScale(0.5, 0.03)
counter.Size = UDim2.fromScale(0.34, 0.11)
counter.BackgroundTransparency = 1
counter.Font = Enum.Font.FredokaOne
counter.TextScaled = true
counter.TextColor3 = Color3.fromRGB(255, 255, 255)
counter.TextStrokeTransparency = 0.15
counter.TextStrokeColor3 = Color3.fromRGB(70, 120, 200)
counter.Text = "⚡ 0"
counter.Parent = gui

-- 보조 라인 (Wins / Rebirths)
local subline = Instance.new("TextLabel")
subline.AnchorPoint = Vector2.new(0.5, 0)
subline.Position = UDim2.fromScale(0.5, 0.14)
subline.Size = UDim2.fromScale(0.3, 0.035)
subline.BackgroundTransparency = 1
subline.Font = Enum.Font.FredokaOne
subline.TextScaled = true
subline.TextColor3 = Color3.fromRGB(235, 235, 245)
subline.TextStrokeTransparency = 0.4
subline.Parent = gui

-- +N 플로터
local floater = Instance.new("TextLabel")
floater.AnchorPoint = Vector2.new(0.5, 0)
floater.Size = UDim2.fromScale(0.12, 0.05)
floater.BackgroundTransparency = 1
floater.Font = Enum.Font.FredokaOne
floater.TextScaled = true
floater.TextColor3 = Color3.fromRGB(140, 255, 170)
floater.TextStrokeTransparency = 0.3
floater.TextTransparency = 1
floater.Parent = gui

-- 전광판 배너
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.fromScale(0.5, 0.21)
banner.Size = UDim2.fromScale(0.55, 0.045)
banner.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.FredokaOne
banner.TextScaled = true
banner.TextColor3 = Color3.fromRGB(255, 230, 150)
banner.TextStrokeTransparency = 0.5
banner.Text = ""
banner.TextTransparency = 1
banner.Parent = gui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = banner

local function refresh()
	counter.Text = ("⚡ %d"):format(speed.Value)
	subline.Text = ("🏆 %d   ♻️ %d (뽁 ×%d)"):format(wins.Value, rebirths.Value, rebirths.Value + 1)
end

-- 속도감 연출: Speed가 오를수록 시야각(FOV)이 넓어져 "빨라지는 몸느낌"을 증폭
local function updateFov(value)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local target = math.clamp(70 + value * 0.055, 70, 95)
	TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = target,
	}):Play()
end

local lastSpeed = speed.Value

speed.Changed:Connect(function(newValue)
	local delta = newValue - lastSpeed
	lastSpeed = newValue
	refresh()
	updateFov(newValue)

	-- 카운터 펄스
	counter.TextColor3 = delta >= 0 and Color3.fromRGB(190, 255, 210) or Color3.fromRGB(255, 190, 190)
	TweenService:Create(counter, TweenInfo.new(0.25), {
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}):Play()

	-- +N 플로터 (양수 증가일 때만)
	if delta > 0 then
		floater.Text = ("+%d"):format(delta)
		floater.TextTransparency = 0
		floater.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.12, 0.145)
		TweenService:Create(floater, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = floater.Position - UDim2.fromScale(0, 0.05),
			TextTransparency = 1,
		}):Play()
	end
end)

wins.Changed:Connect(refresh)
rebirths.Changed:Connect(refresh)
refresh()
updateFov(speed.Value)

-- 서버 전광판 구독
local announce = ReplicatedStorage:WaitForChild("Announce", 10)
if announce then
	local hideAt = 0
	announce.Changed:Connect(function(text)
		if text == "" then return end
		banner.Text = "  " .. text .. "  "
		banner.TextTransparency = 0
		banner.BackgroundTransparency = 0.25
		hideAt = os.clock() + 4
		task.delay(4, function()
			if os.clock() >= hideAt then
				TweenService:Create(banner, TweenInfo.new(0.5), {
					TextTransparency = 1,
					BackgroundTransparency = 1,
				}):Play()
			end
		end)
	end)
end

--------------------------------------------------------------------
-- 트레일 상점 UI (v0.2) — ⭐ Wins로 구매, 치장 전용
--------------------------------------------------------------------
local function roundify(inst, px)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, px or 10)
	corner.Parent = inst
end

local shopRF = ReplicatedStorage:WaitForChild("TrailShop", 10)
if shopRF then
	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Position = UDim2.new(1, -12, 0, 12)
	toggle.Size = UDim2.fromOffset(110, 42)
	toggle.Font = Enum.Font.FredokaOne
	toggle.TextScaled = true
	toggle.Text = "🛒 상점"
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.BackgroundColor3 = Color3.fromRGB(85, 125, 225)
	toggle.Parent = gui
	roundify(toggle)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 62)
	panel.Size = UDim2.fromOffset(270, 252)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
	panel.BackgroundTransparency = 0.12
	panel.Visible = false
	panel.Parent = gui
	roundify(panel, 12)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = "트레일 상점 — ⭐ Wins로 구매"
	title.TextColor3 = Color3.fromRGB(255, 230, 150)
	title.Parent = panel

	local list = Instance.new("Frame")
	list.Position = UDim2.new(0, 8, 0, 38)
	list.Size = UDim2.new(1, -16, 1, -74)
	list.BackgroundTransparency = 1
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local shopMsg = Instance.new("TextLabel")
	shopMsg.AnchorPoint = Vector2.new(0, 1)
	shopMsg.Position = UDim2.new(0, 8, 1, -6)
	shopMsg.Size = UDim2.new(1, -16, 0, 24)
	shopMsg.BackgroundTransparency = 1
	shopMsg.Font = Enum.Font.FredokaOne
	shopMsg.TextScaled = true
	shopMsg.Text = ""
	shopMsg.TextColor3 = Color3.fromRGB(200, 255, 210)
	shopMsg.Parent = panel

	local rows = {} -- id → { action = TextButton, item = 카탈로그 항목 }
	local refreshShop

	local function invoke(action, id)
		task.spawn(function()
			local ok, snapshot = pcall(function()
				return shopRF:InvokeServer(action, id)
			end)
			if ok and type(snapshot) == "table" then
				refreshShop(snapshot)
			end
		end)
	end

	local function buildRow(order, item)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 48)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
		row.LayoutOrder = order
		row.Parent = list
		roundify(row, 8)

		local swatch = Instance.new("Frame")
		swatch.Position = UDim2.new(0, 6, 0.5, -12)
		swatch.Size = UDim2.fromOffset(24, 24)
		swatch.BackgroundColor3 = Color3.fromRGB(item.color[1], item.color[2], item.color[3])
		swatch.Parent = row
		roundify(swatch, 12)

		local name = Instance.new("TextLabel")
		name.Position = UDim2.new(0, 36, 0, 0)
		name.Size = UDim2.new(0.4, 0, 1, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = item.name
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Parent = row

		local action = Instance.new("TextButton")
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -6, 0.5, 0)
		action.Size = UDim2.new(0.4, 0, 0, 36)
		action.Font = Enum.Font.FredokaOne
		action.TextScaled = true
		action.TextColor3 = Color3.new(1, 1, 1)
		action.BackgroundColor3 = Color3.fromRGB(85, 125, 225)
		action.Parent = row
		roundify(action, 8)

		action.Activated:Connect(function()
			local current = rows[item.id].item
			if not current.owned then
				invoke("buy", item.id)
			elseif current.equipped then
				invoke("equip", "") -- 장착 해제
			else
				invoke("equip", item.id)
			end
		end)

		rows[item.id] = { action = action, item = item }
	end

	refreshShop = function(snapshot)
		for order, item in snapshot.catalog do
			if not rows[item.id] then
				buildRow(order, item)
			end
			local row = rows[item.id]
			row.item = item
			if item.equipped then
				row.action.Text = "✓ 장착중"
				row.action.BackgroundColor3 = Color3.fromRGB(70, 190, 110)
			elseif item.owned then
				row.action.Text = "장착"
				row.action.BackgroundColor3 = Color3.fromRGB(85, 125, 225)
			else
				row.action.Text = ("구매 %d⭐"):format(item.price)
				row.action.BackgroundColor3 = Color3.fromRGB(225, 120, 85)
			end
		end
		if snapshot.msg and snapshot.msg ~= "" then
			shopMsg.Text = snapshot.msg
			task.delay(3, function()
				if shopMsg.Text == snapshot.msg then
					shopMsg.Text = ""
				end
			end)
		end
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			invoke("get")
		end
	end)

	invoke("get") -- 접속 시 초기 상태 로드
end

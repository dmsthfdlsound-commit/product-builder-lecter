--------------------------------------------------------------------
-- +1 Pop! HUD — 화면 중앙 상단 Speed 카운터 + 전광판 배너
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

local lastSpeed = speed.Value

speed.Changed:Connect(function(newValue)
	local delta = newValue - lastSpeed
	lastSpeed = newValue
	refresh()

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

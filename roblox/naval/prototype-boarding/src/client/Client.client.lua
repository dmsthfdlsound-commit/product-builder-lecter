--------------------------------------------------------------------
-- 백병전 스파이크 — 클라이언트 (HUD + 검격 트리거 + 연출)
--------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RE_Game = remotes:WaitForChild("GameEvent")
local RE_Hit = remotes:WaitForChild("HitFX")
local RE_Swing = remotes:WaitForChild("Swing")

local bs = ReplicatedStorage:WaitForChild("BoardState")
local crewLeft = bs:WaitForChild("CrewLeft")
local capture = bs:WaitForChild("Capture")

local MAX_CREW = math.max(1, crewLeft.Value)
local CAPTURE_TIME = 10

local function ping(speed, vol)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	s.PlaybackSpeed = speed; s.Volume = vol; s.Parent = camera
	s:Play(); task.delay(1.2, function() s:Destroy() end)
end
local function splash(speed, vol)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/impact_water.mp3"
	s.PlaybackSpeed = speed; s.Volume = vol; s.Parent = camera
	s:Play(); task.delay(2, function() s:Destroy() end)
end

--------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BoardHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props, parent)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.35
	for k, v in props do l[k] = v end
	l.Parent = parent
	return l
end

label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.new(0.7, 0, 0, 26), Text = "⚔️ 백병전 — 적 선원 소탕 or 조타륜 점거" }, gui)

local crewText = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 42),
	Size = UDim2.new(0.4, 0, 0, 24), Text = "", TextColor3 = Color3.fromRGB(255, 150, 140) }, gui)

-- 점거 게이지
local capHolder = Instance.new("Frame")
capHolder.AnchorPoint = Vector2.new(0.5, 0)
capHolder.Position = UDim2.new(0.5, 0, 0, 72)
capHolder.Size = UDim2.new(0.34, 0, 0, 16)
capHolder.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
capHolder.BackgroundTransparency = 0.25
capHolder.Parent = gui
local chc = Instance.new("UICorner"); chc.CornerRadius = UDim.new(0, 8); chc.Parent = capHolder
local capFill = Instance.new("Frame")
capFill.Size = UDim2.fromScale(0, 1)
capFill.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
capFill.Parent = capHolder
local cfc = Instance.new("UICorner"); cfc.CornerRadius = UDim.new(0, 8); cfc.Parent = capFill
label({ Position = UDim2.new(0, 6, 0, -1), Size = UDim2.new(1, -12, 1, 2),
	Text = "🎡 조타륜 점거", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, capHolder)

local banner = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0),
	Size = UDim2.new(0.85, 0, 0, 52), Text = "", TextColor3 = Color3.fromRGB(255, 225, 120) }, gui)
local subBanner = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.38, 0),
	Size = UDim2.new(0.8, 0, 0, 24), Text = "" }, gui)
local bannerUntil = 0
local function showBanner(t1, t2, dur)
	banner.Text = t1; subBanner.Text = t2 or ""
	bannerUntil = os.clock() + (dur or 3)
	task.delay(dur or 3, function()
		if os.clock() >= bannerUntil then banner.Text = ""; subBanner.Text = "" end
	end)
end

label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(0.9, 0, 0, 18),
	Text = "🗡️ 커틀러스 장착 후 클릭/탭 = 베기 · 적함 후미 조타륜 근처에 서 있으면 점거",
	TextTransparency = 0.15 }, gui)

local function refresh()
	crewText.Text = ("👥 적 선원 %d / %d"):format(crewLeft.Value, MAX_CREW)
	capFill.Size = UDim2.fromScale(capture.Value / CAPTURE_TIME, 1)
end
crewLeft.Changed:Connect(refresh)
capture.Changed:Connect(refresh)
refresh()

--------------------------------------------------------------------
-- 검격: Tool.Activated → 서버 판정 + 로컬 스윙 연출
--------------------------------------------------------------------
local function hookTool(tool)
	if tool.Name ~= "커틀러스" then return end
	tool.Activated:Connect(function()
		RE_Swing:FireServer()
		-- 기본 슬래시 애니메이션 트리거 (Animate 스크립트 표준 훅)
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		ping(1.3 + math.random() * 0.3, 0.35) -- 휘두름
	end)
end
local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(hookTool)
player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then hookTool(c) end
	end)
end)
for _, t in backpack:GetChildren() do
	if t:IsA("Tool") then hookTool(t) end
end

--------------------------------------------------------------------
-- 피격/타격 연출
--------------------------------------------------------------------
local function floater(pos, text, color)
	local anchor = Instance.new("Part")
	anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.Position = pos
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(5, 1.8); bb.AlwaysOnTop = true; bb.Parent = anchor
	local l = label({ Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color }, bb)
	task.spawn(function()
		for i = 1, 16 do
			bb.StudsOffset = Vector3.new(0, i * 0.3, 0)
			l.TextTransparency = i / 16
			task.wait(0.035)
		end
		anchor:Destroy()
	end)
end

RE_Hit.OnClientEvent:Connect(function(data)
	if data.hurt then
		floater(data.pos + Vector3.new(0, 3, 0), tostring(data.dmg), Color3.fromRGB(255, 100, 90))
		splash(1.4, 0.4)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.CameraOffset = Vector3.new(0.4, -0.2, 0) end
		task.delay(0.12, function()
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if h then h.CameraOffset = Vector3.new() end
		end)
	else
		floater(data.pos + Vector3.new(0, 3.5, 0), "-" .. data.dmg, Color3.fromRGB(255, 220, 120))
		ping(0.6 + math.random() * 0.2, 0.5)
		local anchor = Instance.new("Part")
		anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1); anchor.Position = data.pos
		anchor.Parent = workspace
		local em = Instance.new("ParticleEmitter")
		em.Color = ColorSequence.new(Color3.fromRGB(255, 180, 120))
		em.Lifetime = NumberRange.new(0.25, 0.5)
		em.Speed = NumberRange.new(8, 16)
		em.SpreadAngle = Vector2.new(180, 180)
		em.Size = NumberSequence.new(0.8, 0.1)
		em.Parent = anchor
		em:Emit(14)
		task.delay(0.8, function() anchor:Destroy() end)
	end
end)

RE_Game.OnClientEvent:Connect(function(data)
	if data.type == "start" then
		showBanner("🪝 도선 성공!", "적 선원을 소탕하거나 조타륜을 점거하세요", 3.5)
		splash(0.5, 0.8)
	elseif data.type == "win" then
		if data.path == "capture" then
			showBanner("🎡 조타륜 점거 — 나포!!", "적함이 우리 것이 됐다 · 8초 후 다음 라운드", 5)
		else
			showBanner("⚔️ 선원 소탕 — 나포!!", "완전 제압 보너스 · 8초 후 다음 라운드", 5)
		end
		ping(0.9, 0.8); ping(1.2, 0.8)
	end
end)

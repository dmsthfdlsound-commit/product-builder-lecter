--------------------------------------------------------------------
-- 해상전 스파이크 — 클라이언트
-- 세트 트릭: 갑판(월드)은 고정, 바다·적함·카메라가 움직여 항해감을 만든다.
-- 조준(마우스/터치) → 일제사격 → 탄도 연출 → 부위 피해 / 브레이스 타이밍 방어.
--------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local world = workspace:WaitForChild("NavalWorld")
local ocean = world:WaitForChild("Ocean")
local foam = world:WaitForChild("Foam")
local enemy = world:WaitForChild("EnemyShip")
local myShip = world:WaitForChild("PlayerShip")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RE_Fire = remotes:WaitForChild("Fire")
local RE_FireResult = remotes:WaitForChild("FireResult")
local RE_Volley = remotes:WaitForChild("Volley")
local RE_Brace = remotes:WaitForChild("Brace")
local RE_Game = remotes:WaitForChild("GameEvent")

local bs = ReplicatedStorage:WaitForChild("BattleState")
local hpSail = bs:WaitForChild("SailHP")
local hpHull = bs:WaitForChild("HullHP")
local hpDeck = bs:WaitForChild("DeckHP")
local shipHP = bs:WaitForChild("ShipHP")

local FIRE_CD = 6.0
local MAX_SAIL = math.max(1, hpSail.Value)
local MAX_HULL = math.max(1, hpHull.Value)
local MAX_DECK = math.max(1, hpDeck.Value)
local MAX_SHIP = math.max(1, shipHP.Value)

--------------------------------------------------------------------
-- 사운드 (내장 에셋 — 본편에서 실제 SFX로 교체)
--------------------------------------------------------------------
local function play(speed, vol)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/impact_water.mp3"
	s.PlaybackSpeed = speed
	s.Volume = vol
	s.Parent = camera
	s:Play()
	task.delay(2.5, function() s:Destroy() end)
end
local function ping(speed, vol)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	s.PlaybackSpeed = speed
	s.Volume = vol
	s.Parent = camera
	s:Play()
	task.delay(1.5, function() s:Destroy() end)
end

--------------------------------------------------------------------
-- 세트 트릭: 바다·포말·적함 흔들기 (갑판은 절대 건드리지 않음)
--------------------------------------------------------------------
local enemyBase = {}   -- part → 기준 CFrame
for _, p in enemy:GetDescendants() do
	if p:IsA("BasePart") then enemyBase[p] = p.CFrame end
end
local foamBase = {}
for _, p in foam:GetChildren() do
	if p:IsA("BasePart") then foamBase[p] = p.Position end
end
local ENEMY_CENTER = CFrame.new(330, 6, 0)
local sinkStart = nil -- os.clock (침몰 연출)

local shakeAmp, shakeUntil = 0, 0
local function shake(amp, dur)
	shakeAmp = math.max(shakeAmp, amp)
	shakeUntil = os.clock() + dur
end

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()

	-- 바다 상하동 + 포말 드리프트 (배가 전진하는 듯한 착시)
	ocean.CFrame = CFrame.new(0, -0.5 + math.sin(t * 0.5) * 0.8, 0)
	for p, base in foamBase do
		local x = ((base.X + t * 7 + 500) % 1000) - 500
		p.Position = Vector3.new(x, 0.15 + math.sin(t * 0.5 + base.Z) * 0.8, base.Z)
	end

	-- 적함 바빙 (+침몰 연출)
	local bob = CFrame.new(0, math.sin(t * 0.62) * 1.5, 0)
		* CFrame.Angles(math.sin(t * 0.41) * 0.022, 0, math.sin(t * 0.55) * 0.035)
	if sinkStart then
		local a = math.clamp((os.clock() - sinkStart) / 4.5, 0, 1)
		bob = CFrame.new(0, -24 * a * a, 0) * CFrame.Angles(0, 0, math.rad(28) * a) * bob
	end
	local xf = ENEMY_CENTER * bob * ENEMY_CENTER:Inverse()
	for p, base in enemyBase do
		if p.Parent then p.CFrame = xf * base end
	end

	-- 카메라: 몸의 흔들림(오프셋) + 피격 셰이크
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local sway = Vector3.new(math.sin(t * 0.5) * 0.25, math.sin(t * 0.83) * 0.45, 0)
		if os.clock() < shakeUntil then
			sway += Vector3.new((math.random() - 0.5) * shakeAmp, (math.random() - 0.5) * shakeAmp, 0)
		else
			shakeAmp = 0
		end
		hum.CameraOffset = sway
	end
end)

--------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "NavalHUD"
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
local function bar(y, name, color)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, y)
	holder.Size = UDim2.new(0.36, 0, 0, 16)
	holder.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
	holder.BackgroundTransparency = 0.25
	holder.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = holder
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.Parent = holder
	local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 8); fc.Parent = fill
	label({ Position = UDim2.new(0, 6, 0, -1), Size = UDim2.new(1, -12, 1, 2),
		Text = name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, holder)
	return fill
end

label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.new(0.5, 0, 0, 26), Text = "⚔️ 적함 · 연습 스쿠너" }, gui)
local fSail = bar(46, "⛵ 돛", Color3.fromRGB(80, 200, 255))
local fHull = bar(66, "🛡️ 선체", Color3.fromRGB(255, 150, 60))
local fDeck = bar(86, "👥 갑판", Color3.fromRGB(255, 90, 90))
local segTip = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 106),
	Size = UDim2.new(0.6, 0, 0, 20), Text = "", TextColor3 = Color3.fromRGB(255, 230, 140) }, gui)

-- 아군 선체
label({ Position = UDim2.new(0, 14, 1, -96), Size = UDim2.new(0, 150, 0, 20),
	Text = "🚢 아군 선체", TextXAlignment = Enum.TextXAlignment.Left }, gui)
local myHolder = Instance.new("Frame")
myHolder.Position = UDim2.new(0, 14, 1, -72)
myHolder.Size = UDim2.new(0.3, 0, 0, 18)
myHolder.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
myHolder.BackgroundTransparency = 0.25
myHolder.Parent = gui
local mhc = Instance.new("UICorner"); mhc.CornerRadius = UDim.new(0, 9); mhc.Parent = myHolder
local fShip = Instance.new("Frame")
fShip.Size = UDim2.fromScale(1, 1)
fShip.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
fShip.Parent = myHolder
local fsc = Instance.new("UICorner"); fsc.CornerRadius = UDim.new(0, 9); fsc.Parent = fShip

local tip = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(0.9, 0, 0, 18), Text = "🎯 적함을 클릭/터치로 조준 · 돛=발묶기 · 갑판=화력 감소 · 선체=격침  (PC: F 발사 · G 브레이스)",
	TextTransparency = 0.15 }, gui)

-- 버튼
local function button(text, pos, color)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = pos
	b.Size = UDim2.fromOffset(150, 62)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.Parent = gui
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = b
	return b
end
local fireBtn = button("💥 일제사격", UDim2.new(1, -14, 1, -14), Color3.fromRGB(226, 92, 62))
local braceBtn = button("🛡️ 브레이스", UDim2.new(1, -14, 1, -86), Color3.fromRGB(70, 110, 200))

-- 중앙 배너
local banner = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.32, 0),
	Size = UDim2.new(0.85, 0, 0, 54), Text = "", TextColor3 = Color3.fromRGB(255, 225, 120) }, gui)
local subBanner = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.40, 0),
	Size = UDim2.new(0.8, 0, 0, 26), Text = "" }, gui)
local bannerUntil = 0
local function showBanner(text, sub, dur)
	banner.Text = text
	subBanner.Text = sub or ""
	bannerUntil = os.clock() + (dur or 3)
	task.delay(dur or 3, function()
		if os.clock() >= bannerUntil then banner.Text = ""; subBanner.Text = "" end
	end)
end

local function refreshBars()
	fSail.Size = UDim2.fromScale(hpSail.Value / MAX_SAIL, 1)
	fHull.Size = UDim2.fromScale(hpHull.Value / MAX_HULL, 1)
	fDeck.Size = UDim2.fromScale(hpDeck.Value / MAX_DECK, 1)
	fShip.Size = UDim2.fromScale(shipHP.Value / MAX_SHIP, 1)
	fShip.BackgroundColor3 = shipHP.Value / MAX_SHIP > 0.35
		and Color3.fromRGB(90, 220, 120) or Color3.fromRGB(235, 90, 70)
	local effects = {}
	if hpSail.Value <= 0 then table.insert(effects, "⛵ 적 재장전 +60%") end
	if hpDeck.Value <= 0 then table.insert(effects, "👥 적 화력 −50%") end
	segTip.Text = table.concat(effects, "   ")
end
hpSail.Changed:Connect(refreshBars)
hpHull.Changed:Connect(refreshBars)
hpDeck.Changed:Connect(refreshBars)
shipHP.Changed:Connect(refreshBars)
refreshBars()

--------------------------------------------------------------------
-- 조준
--------------------------------------------------------------------
local aimPos = nil
local crosshair = Instance.new("Part")
crosshair.Shape = Enum.PartType.Ball
crosshair.Size = Vector3.new(2.4, 2.4, 2.4)
crosshair.Material = Enum.Material.Neon
crosshair.Color = Color3.fromRGB(255, 230, 90)
crosshair.Anchored = true
crosshair.CanCollide = false
crosshair.Transparency = 1
crosshair.Parent = workspace
local chGui = Instance.new("BillboardGui")
chGui.Size = UDim2.fromScale(6, 1.6)
chGui.StudsOffset = Vector3.new(0, 2.4, 0)
chGui.AlwaysOnTop = true
chGui.Parent = crosshair
local chLabel = label({ Size = UDim2.fromScale(1, 1), Text = "" }, chGui)

local SEG_KO = { Sail = "⛵ 돛", Hull = "🛡️ 선체", Deck = "👥 갑판" }
local SEG_COLOR = {
	Sail = Color3.fromRGB(80, 200, 255),
	Hull = Color3.fromRGB(255, 150, 60),
	Deck = Color3.fromRGB(255, 90, 90),
}

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Include
aimParams.FilterDescendantsInstances = { enemy }

local function updateAim(screenPos)
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 900, aimParams)
	if hit then
		aimPos = hit.Position
		local seg = hit.Instance:GetAttribute("Seg") or "Hull"
		crosshair.Position = hit.Position
		crosshair.Transparency = 0.15
		crosshair.Color = SEG_COLOR[seg]
		chLabel.Text = SEG_KO[seg]
		chLabel.TextColor3 = SEG_COLOR[seg]
	end
end

UserInputService.InputChanged:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		updateAim(input.Position)
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1 then
		updateAim(input.Position)
	end
end)

--------------------------------------------------------------------
-- 발사
--------------------------------------------------------------------
local lastFireAt = -99
local function tryFire()
	if os.clock() - lastFireAt < FIRE_CD then return end
	if not aimPos then
		showBanner("🎯 먼저 적함을 조준!", "적함을 클릭/터치하세요", 1.2)
		return
	end
	lastFireAt = os.clock()
	RE_Fire:FireServer(aimPos)
end
fireBtn.Activated:Connect(tryFire)
braceBtn.Activated:Connect(function() RE_Brace:FireServer() end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then tryFire() end
	if input.KeyCode == Enum.KeyCode.G then RE_Brace:FireServer() end
end)

-- 쿨다운 표시
RunService.Heartbeat:Connect(function()
	local left = FIRE_CD - (os.clock() - lastFireAt)
	if left > 0 then
		fireBtn.Text = ("재장전 %.1f"):format(left)
		fireBtn.BackgroundColor3 = Color3.fromRGB(120, 84, 74)
	else
		fireBtn.Text = "💥 일제사격"
		fireBtn.BackgroundColor3 = Color3.fromRGB(226, 92, 62)
	end
end)

--------------------------------------------------------------------
-- 탄도 연출
--------------------------------------------------------------------
local function floater(pos, text, color)
	local anchor = Instance.new("Part")
	anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.Position = pos
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(7, 2.2); bb.AlwaysOnTop = true; bb.Parent = anchor
	local l = label({ Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color }, bb)
	task.spawn(function()
		for i = 1, 20 do
			bb.StudsOffset = Vector3.new(0, i * 0.28, 0)
			l.TextTransparency = i / 20
			task.wait(0.035)
		end
		anchor:Destroy()
	end)
end

local function burst(pos, color, count, speed)
	local anchor = Instance.new("Part")
	anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1); anchor.Position = pos
	anchor.Parent = workspace
	local em = Instance.new("ParticleEmitter")
	em.Color = ColorSequence.new(color)
	em.Lifetime = NumberRange.new(0.35, 0.8)
	em.Speed = NumberRange.new(speed * 0.6, speed)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Size = NumberSequence.new(1.4, 0.2)
	em.Parent = anchor
	em:Emit(count)
	task.delay(1.2, function() anchor:Destroy() end)
end

local function flyBall(from, to, seg, dmg, delay)
	task.delay(delay, function()
		play(0.42 + math.random() * 0.1, 0.7) -- 발사 붐
		burst(from, Color3.fromRGB(200, 200, 200), 14, 10) -- 포연
		shake(0.5, 0.15)
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(1.1, 1.1, 1.1)
		ball.Color = Color3.fromRGB(30, 30, 34)
		ball.Material = Enum.Material.Metal
		ball.Anchored = true; ball.CanCollide = false
		ball.Parent = workspace
		local dist = (to - from).Magnitude
		local dur = math.max(0.35, dist / 380)
		local mid = (from + to) / 2 + Vector3.new(0, dist * 0.10, 0)
		local t0 = os.clock()
		while true do
			local a = (os.clock() - t0) / dur
			if a >= 1 then break end
			local p1 = from:Lerp(mid, a)
			local p2 = mid:Lerp(to, a)
			ball.Position = p1:Lerp(p2, a)
			RunService.RenderStepped:Wait()
		end
		ball:Destroy()
		if seg == "Miss" then
			burst(Vector3.new(to.X, 0.5, to.Z), Color3.fromRGB(220, 240, 255), 22, 26)
			play(0.9 + math.random() * 0.25, 0.5)
			floater(to + Vector3.new(0, 3, 0), "빗나감", Color3.fromRGB(200, 210, 230))
		else
			burst(to, Color3.fromRGB(255, 170, 70), 26, 30)
			burst(to, Color3.fromRGB(120, 80, 50), 16, 18)
			ping(0.5 + math.random() * 0.15, 0.5)
			floater(to + Vector3.new(0, 3, 0), "-" .. dmg .. " " .. (SEG_KO[seg] or ""), SEG_COLOR[seg] or Color3.new(1, 1, 1))
		end
	end)
end

RE_FireResult.OnClientEvent:Connect(function(data)
	for i, shot in data.shots do
		flyBall(shot.from, shot.to, shot.seg, shot.dmg, (i - 1) * 0.09)
	end
end)

--------------------------------------------------------------------
-- 적 일제사격 / 브레이스
--------------------------------------------------------------------
local volleyGlow = {}
for _, p in enemy:GetDescendants() do
	if p:IsA("BasePart") and p:GetAttribute("VolleyCannon") then
		table.insert(volleyGlow, p)
	end
end
local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
vignette.BackgroundTransparency = 1
vignette.ZIndex = 0
vignette.Parent = gui

RE_Volley.OnClientEvent:Connect(function(data)
	if data.phase == "warn" then
		for _, c in volleyGlow do
			c.Material = Enum.Material.Neon
			c.Color = Color3.fromRGB(255, 70, 60)
		end
		vignette.BackgroundTransparency = 0.82
		braceBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
		braceBtn.Text = "🛡️ 지금 브레이스!!"
		ping(0.7, 0.8); ping(0.55, 0.8)
		task.delay(1.1, function()
			for _, c in volleyGlow do
				c.Material = Enum.Material.Metal
				c.Color = Color3.fromRGB(40, 38, 46)
			end
			vignette.BackgroundTransparency = 1
			braceBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
			braceBtn.Text = "🛡️ 브레이스"
		end)
	elseif data.phase == "hit" then
		play(0.38, 1)
		if data.grade == "perfect" then
			shake(0.6, 0.25)
			showBanner("✨ PERFECT 브레이스!", ("피해 −80%%  (−%d)"):format(data.dmg), 1.6)
		elseif data.grade == "brace" then
			shake(1.4, 0.4)
			showBanner("🛡️ 브레이스!", ("피해 −55%%  (−%d)"):format(data.dmg), 1.6)
		else
			shake(2.6, 0.7)
			showBanner("💥 직격!!", ("−%d 피해 — G키/버튼으로 막으세요"):format(data.dmg), 1.8)
		end
		burst(Vector3.new(10, 9, math.random(-20, 20)), Color3.fromRGB(150, 100, 60), 20, 22)
	end
end)

--------------------------------------------------------------------
-- 게임 이벤트 (격침/패배/리셋)
--------------------------------------------------------------------
RE_Game.OnClientEvent:Connect(function(data)
	if data.type == "sunk" then
		sinkStart = os.clock()
		play(0.3, 1)
		shake(1.2, 0.6)
		local bonus = {}
		if data.sails then table.insert(bonus, "돛 완파") end
		if data.crew then table.insert(bonus, "선원 제압") end
		showBanner("⚓ 격침!! +1", #bonus > 0 and ("보너스: " .. table.concat(bonus, " · ")) or "다음 적함 접근 중…", 5)
	elseif data.type == "respawn" then
		sinkStart = nil
		showBanner("🏴‍☠️ 새 적함 등장!", "돛/갑판/선체 — 어디를 노릴지가 전략", 2.5)
	elseif data.type == "defeat" then
		shake(3, 1)
		showBanner("🌊 침몰… 구조됩니다", "손실 없음 — 5초 후 재도전", 4.5)
	elseif data.type == "reset" then
		sinkStart = nil
		showBanner("⚔️ 전투 재개!", "", 2)
	end
end)

showBanner("⚓ 해상전 스파이크", "적함을 조준하고 💥 일제사격! (부위마다 효과가 다릅니다)", 4)

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
local RE_Select = remotes:WaitForChild("SelectStage")
local RE_Battle = remotes:WaitForChild("BattleEvent")
local RE_Shop = remotes:WaitForChild("Shop")
local RE_Cut = remotes:WaitForChild("CutGrapple")

local bs = ReplicatedStorage:WaitForChild("BattleState")
local hpSail = bs:WaitForChild("SailHP")
local hpHull = bs:WaitForChild("HullHP")
local hpDeck = bs:WaitForChild("DeckHP")
local shipHP = bs:WaitForChild("ShipHP")

local FIRE_CD = 6.0
local MAX_SAIL, MAX_HULL, MAX_DECK = 1, 1, 1
local MAX_SHIP = math.max(1, shipHP.Value)

-- 해도 데이터 (서버 STAGES와 동일 유지)
local STAGE_INFO = {
	{ id = 1, name = "연안 밀수선", diff = "★", silver = 120, bonusText = "90초 내 격침" },
	{ id = 2, name = "호송 스쿠너", diff = "★★", silver = 260, bonusText = "돛+갑판 완파 후 격침" },
	{ id = 3, name = "사략 브리간틴", diff = "★★★", silver = 520, bonusText = "퍼펙트 브레이스 5회" },
}
local myStars = { 0, 0, 0 }
local mySilver = 0
local myUpg = { cannon = 0, armor = 0, aim = 0 }
local UPG_INFO = {
	{ key = "cannon", icon = "💥", name = "포문 확장", costs = { 300, 800, 1800 },
		fx = { "4발", "5발", "6발", "7발" } },
	{ key = "armor", icon = "🛡️", name = "장갑판", costs = { 250, 700, 1600 },
		fx = { "피격 100%", "88%", "78%", "70%" } },
	{ key = "aim", icon = "🎯", name = "조준 보조", costs = { 200, 600, 1400 },
		fx = { "산포 9.0", "7.25", "5.5", "3.75" } },
}

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
local phaseX, phaseXTarget = 0, 0 -- 2막 접근 오프셋 (330 → 120)

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
	-- 2막 접근: 적함이 미끄러져 들어옴
	if phaseX ~= phaseXTarget then
		local dir = phaseXTarget > phaseX and 1 or -1
		phaseX = math.clamp(phaseX + dir * 70 / 60, math.min(phaseX, phaseXTarget), math.max(phaseX, phaseXTarget))
	end
	local xf = CFrame.new(-phaseX, 0, 0) * ENEMY_CENTER * bob * ENEMY_CENTER:Inverse()
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

local enemyTitle = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.new(0.5, 0, 0, 26), Text = "" }, gui)
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
local fireLabel = "💥 일제사격"
RunService.Heartbeat:Connect(function()
	local left = FIRE_CD - (os.clock() - lastFireAt)
	if left > 0 then
		fireBtn.Text = ("재장전 %.1f"):format(left)
		fireBtn.BackgroundColor3 = Color3.fromRGB(120, 84, 74)
	else
		fireBtn.Text = fireLabel
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
	if data.type == "captured" then
		play(0.6, 1)
		shake(1, 0.4)
		showBanner("🏴‍☠️ 나포!!", "적함을 접수했다 — 보상 1.5배", 3.5)
	elseif data.type == "sunk" then
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

--------------------------------------------------------------------
-- 해도 (스테이지 선택) + 승리/패배 화면
--------------------------------------------------------------------
local chart = Instance.new("Frame")
chart.Size = UDim2.fromScale(1, 1)
chart.BackgroundColor3 = Color3.fromRGB(16, 26, 48)
chart.BackgroundTransparency = 0.06
chart.Visible = true
chart.ZIndex = 10
chart.Parent = gui

label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.06, 0),
	Size = UDim2.new(0.8, 0, 0, 44), Text = "🗺️ 해도 — 연습 해역", ZIndex = 11,
	TextColor3 = Color3.fromRGB(255, 230, 150) }, chart)
local silverLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.13, 0),
	Size = UDim2.new(0.5, 0, 0, 24), Text = "🪙 0", ZIndex = 11 }, chart)

local cards = {}
for i, info in STAGE_INFO do
	local card = Instance.new("TextButton")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.30 + (i - 1) * 0.185, 0)
	card.Size = UDim2.new(0.72, 0, 0.15, 0)
	card.BackgroundColor3 = Color3.fromRGB(30, 44, 80)
	card.Text = ""
	card.ZIndex = 11
	card.Parent = chart
	local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 14); cc.Parent = card
	local title = label({ Position = UDim2.new(0.04, 0, 0.08, 0), Size = UDim2.new(0.6, 0, 0.36, 0),
		Text = ("%d. %s  %s"):format(info.id, info.name, info.diff),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, card)
	local starsL = label({ Position = UDim2.new(0.66, 0, 0.08, 0), Size = UDim2.new(0.3, 0, 0.36, 0),
		Text = "☆☆☆", TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12,
		TextColor3 = Color3.fromRGB(255, 220, 90) }, card)
	local sub = label({ Position = UDim2.new(0.04, 0, 0.52, 0), Size = UDim2.new(0.92, 0, 0.34, 0),
		Text = ("🪙 %d  ·  ⭐3 조건: %s"):format(info.silver, info.bonusText),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, TextTransparency = 0.2 }, card)
	card.Activated:Connect(function()
		RE_Select:FireServer(info.id)
	end)
	cards[i] = { card = card, starsL = starsL, title = title, sub = sub }
end
label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.97, 0),
	Size = UDim2.new(0.8, 0, 0, 20), Text = "스테이지를 선택하면 출항합니다 · 이전 스테이지 ⭐1 이상이 잠금 해제 조건",
	ZIndex = 11, TextTransparency = 0.2 }, chart)

local function refreshChart()
	silverLabel.Text = ("🪙 %d"):format(mySilver)
	for i, c in cards do
		local st = myStars[i] or 0
		c.starsL.Text = string.rep("⭐", st) .. string.rep("☆", 3 - st)
		local locked = i > 1 and (myStars[i - 1] or 0) < 1
		c.card.BackgroundColor3 = locked and Color3.fromRGB(24, 28, 40) or Color3.fromRGB(30, 44, 80)
		c.title.TextTransparency = locked and 0.55 or 0
		c.sub.Text = locked and "🔒 이전 스테이지 ⭐1 필요"
			or ("🪙 %d  ·  ⭐3 조건: %s"):format(STAGE_INFO[i].silver, STAGE_INFO[i].bonusText)
	end
end
refreshChart()

-- 조선소 (은화 상점) — 해도 위 패널
local shopBtn = Instance.new("TextButton")
shopBtn.AnchorPoint = Vector2.new(0.5, 1)
shopBtn.Position = UDim2.new(0.5, 0, 0.92, 0)
shopBtn.Size = UDim2.new(0.4, 0, 0.06, 0)
shopBtn.Font = Enum.Font.FredokaOne
shopBtn.TextScaled = true
shopBtn.Text = "🛠️ 조선소"
shopBtn.TextColor3 = Color3.new(1, 1, 1)
shopBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 50)
shopBtn.ZIndex = 11
shopBtn.Parent = chart
local sbc = Instance.new("UICorner"); sbc.CornerRadius = UDim.new(0, 12); sbc.Parent = shopBtn

local shop = Instance.new("Frame")
shop.AnchorPoint = Vector2.new(0.5, 0.5)
shop.Position = UDim2.fromScale(0.5, 0.5)
shop.Size = UDim2.new(0.78, 0, 0.6, 0)
shop.BackgroundColor3 = Color3.fromRGB(26, 34, 58)
shop.Visible = false
shop.ZIndex = 15
shop.Parent = gui
local shc = Instance.new("UICorner"); shc.CornerRadius = UDim.new(0, 16); shc.Parent = shop
label({ Position = UDim2.new(0, 0, 0.03, 0), Size = UDim2.new(1, 0, 0.12, 0),
	Text = "🛠️ 조선소 — 은화로 함선 강화", ZIndex = 16,
	TextColor3 = Color3.fromRGB(255, 230, 150) }, shop)
local shopSilver = label({ Position = UDim2.new(0, 0, 0.15, 0), Size = UDim2.new(1, 0, 0.08, 0),
	Text = "🪙 0", ZIndex = 16 }, shop)

local shopRows = {}
for i, info in UPG_INFO do
	local row = Instance.new("Frame")
	row.Position = UDim2.new(0.05, 0, 0.24 + (i - 1) * 0.21, 0)
	row.Size = UDim2.new(0.9, 0, 0.18, 0)
	row.BackgroundColor3 = Color3.fromRGB(38, 48, 78)
	row.ZIndex = 16
	row.Parent = shop
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 10); rc.Parent = row
	local nameL = label({ Position = UDim2.new(0.03, 0, 0.08, 0), Size = UDim2.new(0.55, 0, 0.44, 0),
		Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 17 }, row)
	local fxL = label({ Position = UDim2.new(0.03, 0, 0.54, 0), Size = UDim2.new(0.55, 0, 0.36, 0),
		Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 17, TextTransparency = 0.2 }, row)
	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(0.97, 0, 0.5, 0)
	buy.Size = UDim2.new(0.32, 0, 0.7, 0)
	buy.Font = Enum.Font.FredokaOne
	buy.TextScaled = true
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.BackgroundColor3 = Color3.fromRGB(70, 160, 100)
	buy.ZIndex = 17
	buy.Parent = row
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 10); bc.Parent = buy
	buy.Activated:Connect(function() RE_Shop:FireServer(info.key) end)
	shopRows[i] = { name = nameL, fx = fxL, buy = buy }
end

local shopClose = Instance.new("TextButton")
shopClose.AnchorPoint = Vector2.new(0.5, 1)
shopClose.Position = UDim2.new(0.5, 0, 0.96, 0)
shopClose.Size = UDim2.new(0.3, 0, 0.1, 0)
shopClose.Font = Enum.Font.FredokaOne
shopClose.TextScaled = true
shopClose.Text = "닫기"
shopClose.TextColor3 = Color3.new(1, 1, 1)
shopClose.BackgroundColor3 = Color3.fromRGB(90, 100, 130)
shopClose.ZIndex = 16
shopClose.Parent = shop
local scc = Instance.new("UICorner"); scc.CornerRadius = UDim.new(0, 10); scc.Parent = shopClose

local function refreshShop()
	shopSilver.Text = ("🪙 %d"):format(mySilver)
	for i, info in UPG_INFO do
		local tier = myUpg[info.key] or 0
		local row = shopRows[i]
		row.name.Text = ("%s %s  %s%s"):format(info.icon, info.name,
			string.rep("●", tier), string.rep("○", 3 - tier))
		if tier >= 3 then
			row.fx.Text = "현재: " .. info.fx[4] .. " (최대)"
			row.buy.Text = "MAX"
			row.buy.BackgroundColor3 = Color3.fromRGB(80, 86, 105)
		else
			row.fx.Text = ("현재: %s → 다음: %s"):format(info.fx[tier + 1], info.fx[tier + 2])
			local cost = info.costs[tier + 1]
			row.buy.Text = ("🪙 %d"):format(cost)
			row.buy.BackgroundColor3 = mySilver >= cost
				and Color3.fromRGB(70, 160, 100) or Color3.fromRGB(120, 70, 60)
		end
	end
end
shopBtn.Activated:Connect(function()
	shop.Visible = not shop.Visible
	refreshShop()
end)
shopClose.Activated:Connect(function() shop.Visible = false end)

-- 선술집 (가챠) — 확률 상시 공개 + 천장 카운터 노출이 원칙
local RE_Gacha = remotes:WaitForChild("Gacha")
local myPityR, myPityS, myTrain = 0, 0, 0
local myCrew = {}
local mySquad = {}
local R_KO = { C = "커먼", U = "언커먼", R = "레어", S = "슈퍼레어" }
local R_COL = {
	C = Color3.fromRGB(180, 200, 220), U = Color3.fromRGB(120, 230, 150),
	R = Color3.fromRGB(200, 130, 255), S = Color3.fromRGB(255, 200, 60),
}

local tavernBtn = Instance.new("TextButton")
tavernBtn.AnchorPoint = Vector2.new(0.5, 1)
tavernBtn.Position = UDim2.new(0.28, 0, 0.92, 0)
tavernBtn.Size = UDim2.new(0.34, 0, 0.06, 0)
tavernBtn.Font = Enum.Font.FredokaOne
tavernBtn.TextScaled = true
tavernBtn.Text = "🍺 선술집 (선원 모집)"
tavernBtn.TextColor3 = Color3.new(1, 1, 1)
tavernBtn.BackgroundColor3 = Color3.fromRGB(150, 90, 130)
tavernBtn.ZIndex = 11
tavernBtn.Parent = chart
local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 12); tbc.Parent = tavernBtn

local tavern = Instance.new("Frame")
tavern.AnchorPoint = Vector2.new(0.5, 0.5)
tavern.Position = UDim2.fromScale(0.5, 0.5)
tavern.Size = UDim2.new(0.82, 0, 0.7, 0)
tavern.BackgroundColor3 = Color3.fromRGB(40, 28, 40)
tavern.Visible = false
tavern.ZIndex = 15
tavern.Parent = gui
local tvc = Instance.new("UICorner"); tvc.CornerRadius = UDim.new(0, 16); tvc.Parent = tavern
label({ Position = UDim2.new(0, 0, 0.02, 0), Size = UDim2.new(1, 0, 0.1, 0),
	Text = "🍺 선술집 — 선원 모집 (150🪙)", ZIndex = 16,
	TextColor3 = Color3.fromRGB(255, 210, 160) }, tavern)
label({ Position = UDim2.new(0, 0, 0.12, 0), Size = UDim2.new(1, 0, 0.06, 0),
	Text = "확률: 커먼 60% · 언커먼 27% · 레어 10% · 슈퍼레어 3% (상시 공개)", ZIndex = 16,
	TextTransparency = 0.15 }, tavern)
local pityLabel = label({ Position = UDim2.new(0, 0, 0.19, 0), Size = UDim2.new(1, 0, 0.06, 0),
	Text = "", ZIndex = 16, TextColor3 = Color3.fromRGB(255, 230, 140) }, tavern)
local squadLabel = label({ Position = UDim2.new(0, 0, 0.26, 0), Size = UDim2.new(1, 0, 0.06, 0),
	Text = "", ZIndex = 16, TextColor3 = Color3.fromRGB(150, 220, 255) }, tavern)

-- 결과 카드
local resultCard = Instance.new("Frame")
resultCard.AnchorPoint = Vector2.new(0.5, 0.5)
resultCard.Position = UDim2.fromScale(0.5, 0.52)
resultCard.Size = UDim2.new(0.7, 0, 0.3, 0)
resultCard.BackgroundColor3 = Color3.fromRGB(60, 45, 60)
resultCard.Visible = false
resultCard.ZIndex = 17
resultCard.Parent = tavern
local rcc = Instance.new("UICorner"); rcc.CornerRadius = UDim.new(0, 14); rcc.Parent = resultCard
local rcStroke = Instance.new("UIStroke"); rcStroke.Thickness = 4; rcStroke.Parent = resultCard
local rcRarity = label({ Position = UDim2.new(0, 0, 0.06, 0), Size = UDim2.new(1, 0, 0.24, 0),
	Text = "", ZIndex = 18 }, resultCard)
local rcName = label({ Position = UDim2.new(0, 0, 0.32, 0), Size = UDim2.new(1, 0, 0.3, 0),
	Text = "", ZIndex = 18 }, resultCard)
local rcSkill = label({ Position = UDim2.new(0, 0, 0.64, 0), Size = UDim2.new(1, 0, 0.22, 0),
	Text = "", ZIndex = 18, TextTransparency = 0.1 }, resultCard)

local rollBtn = Instance.new("TextButton")
rollBtn.AnchorPoint = Vector2.new(0.5, 1)
rollBtn.Position = UDim2.new(0.5, 0, 0.86, 0)
rollBtn.Size = UDim2.new(0.44, 0, 0.1, 0)
rollBtn.Font = Enum.Font.FredokaOne
rollBtn.TextScaled = true
rollBtn.Text = "🎲 모집 (150🪙)"
rollBtn.TextColor3 = Color3.new(1, 1, 1)
rollBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 60)
rollBtn.ZIndex = 16
rollBtn.Parent = tavern
local rbc = Instance.new("UICorner"); rbc.CornerRadius = UDim.new(0, 12); rbc.Parent = rollBtn
rollBtn.Activated:Connect(function() RE_Gacha:FireServer() end)

local tavernClose = Instance.new("TextButton")
tavernClose.AnchorPoint = Vector2.new(0.5, 1)
tavernClose.Position = UDim2.new(0.5, 0, 0.97, 0)
tavernClose.Size = UDim2.new(0.3, 0, 0.08, 0)
tavernClose.Font = Enum.Font.FredokaOne
tavernClose.TextScaled = true
tavernClose.Text = "닫기"
tavernClose.TextColor3 = Color3.new(1, 1, 1)
tavernClose.BackgroundColor3 = Color3.fromRGB(90, 100, 130)
tavernClose.ZIndex = 16
tavernClose.Parent = tavern
local tcc = Instance.new("UICorner"); tcc.CornerRadius = UDim.new(0, 10); tcc.Parent = tavernClose
tavernClose.Activated:Connect(function() tavern.Visible = false end)

local function refreshTavern()
	pityLabel.Text = ("천장: 레어+ 보장까지 %d회 · 슈퍼레어 보장까지 %d회 · 훈련점수 %d"):format(
		math.max(0, 20 - myPityR), math.max(0, 60 - myPityS), myTrain)
	local names = {}
	for _, m in mySquad do
		table.insert(names, ("[%s] %s"):format(R_KO[m.r] or m.r, m.name))
	end
	squadLabel.Text = #names > 0 and ("도선 스쿼드: " .. table.concat(names, " · ")) or "도선 스쿼드: (기본 선원)"
	rollBtn.BackgroundColor3 = mySilver >= 150
		and Color3.fromRGB(200, 120, 60) or Color3.fromRGB(110, 80, 70)
end
tavernBtn.Activated:Connect(function()
	tavern.Visible = not tavern.Visible
	refreshTavern()
end)

-- 승리 패널
local winPanel = Instance.new("Frame")
winPanel.AnchorPoint = Vector2.new(0.5, 0.5)
winPanel.Position = UDim2.fromScale(0.5, 0.5)
winPanel.Size = UDim2.new(0.7, 0, 0.44, 0)
winPanel.BackgroundColor3 = Color3.fromRGB(20, 32, 60)
winPanel.Visible = false
winPanel.ZIndex = 20
winPanel.Parent = gui
local wpc = Instance.new("UICorner"); wpc.CornerRadius = UDim.new(0, 18); wpc.Parent = winPanel
local winTitle = label({ Position = UDim2.new(0, 0, 0.06, 0), Size = UDim2.new(1, 0, 0.2, 0),
	Text = "⚓ 격침!!", ZIndex = 21, TextColor3 = Color3.fromRGB(255, 230, 150) }, winPanel)
local winStars = label({ Position = UDim2.new(0, 0, 0.3, 0), Size = UDim2.new(1, 0, 0.28, 0),
	Text = "", ZIndex = 21 }, winPanel)
local winInfo = label({ Position = UDim2.new(0, 0, 0.6, 0), Size = UDim2.new(1, 0, 0.14, 0),
	Text = "", ZIndex = 21, TextTransparency = 0.1 }, winPanel)
local backBtn = Instance.new("TextButton")
backBtn.AnchorPoint = Vector2.new(0.5, 1)
backBtn.Position = UDim2.new(0.5, 0, 0.94, 0)
backBtn.Size = UDim2.new(0.4, 0, 0.16, 0)
backBtn.Font = Enum.Font.FredokaOne
backBtn.TextScaled = true
backBtn.Text = "🗺️ 해도로"
backBtn.TextColor3 = Color3.new(1, 1, 1)
backBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
backBtn.ZIndex = 21
backBtn.Parent = winPanel
local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(0, 12); bbc.Parent = backBtn
backBtn.Activated:Connect(function()
	winPanel.Visible = false
	chart.Visible = true
	refreshChart()
end)

-- 2막: 갈고리 UI (탭/클릭 or 절단 버튼)
local hooks = {} -- [id] = part
local cutBtn = Instance.new("TextButton")
cutBtn.AnchorPoint = Vector2.new(0.5, 1)
cutBtn.Position = UDim2.new(0.5, 0, 1, -14)
cutBtn.Size = UDim2.fromOffset(190, 58)
cutBtn.Font = Enum.Font.FredokaOne
cutBtn.TextScaled = true
cutBtn.Text = "🪓 밧줄 절단!!"
cutBtn.TextColor3 = Color3.new(1, 1, 1)
cutBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
cutBtn.Visible = false
cutBtn.Parent = gui
local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 14); cbc.Parent = cutBtn

local function oldestHook()
	local minId = nil
	for id in hooks do
		if not minId or id < minId then minId = id end
	end
	return minId
end
cutBtn.Activated:Connect(function()
	local id = oldestHook()
	if id then RE_Cut:FireServer(id) end
end)

local function removeHook(id)
	local h = hooks[id]
	if h then h:Destroy(); hooks[id] = nil end
	cutBtn.Visible = next(hooks) ~= nil
end

local function spawnHook(id, z)
	local hook = Instance.new("Part")
	hook.Shape = Enum.PartType.Ball
	hook.Size = Vector3.new(2, 2, 2)
	hook.Color = Color3.fromRGB(255, 80, 60)
	hook.Material = Enum.Material.Neon
	hook.Anchored = true; hook.CanCollide = false
	hook.Position = Vector3.new(12.4, 10.8, z)
	hook.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(7, 2); bb.StudsOffset = Vector3.new(0, 2.4, 0); bb.AlwaysOnTop = true
	bb.Parent = hook
	label({ Size = UDim2.fromScale(1, 1), Text = "🪝 갈고리! 절단하라", TextColor3 = Color3.fromRGB(255, 120, 100) }, bb)
	hooks[id] = hook
	cutBtn.Visible = true
	ping(0.45, 0.9)
end

-- 갈고리 직접 클릭/탭 절단
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		local list = {}
		for _, h in hooks do table.insert(list, h) end
		if #list == 0 then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = list
		local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		if hit then
			for id, h in hooks do
				if h == hit.Instance then RE_Cut:FireServer(id) break end
			end
		end
	end
end)

-- 3막: 커틀러스 스윙 훅
local RE_Swing = remotes:WaitForChild("Swing")
local function hookTool(tool)
	if tool.Name ~= "커틀러스" then return end
	tool.Activated:Connect(function()
		RE_Swing:FireServer()
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		ping(1.3 + math.random() * 0.3, 0.35)
	end)
end
local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(function(c)
	if c:IsA("Tool") then hookTool(c) end
end)
player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then hookTool(c) end
	end)
end)
for _, t in backpack:GetChildren() do
	if t:IsA("Tool") then hookTool(t) end
end

RE_Battle.OnClientEvent:Connect(function(data)
	if data.type == "phase3" then
		phaseXTarget = 291
		fireLabel = "⚔️ 백병전!"
		for id in hooks do removeHook(id) end
		showBanner("🪝 3막 — 도선!!", "아군 선원 3명과 함께 돌격! 커틀러스(1번) 장착 후 클릭/탭", 4)
		play(0.45, 1)
		shake(1.5, 0.5)
	elseif data.type == "crewHit" then
		if data.ally then
			ping(0.45 + math.random() * 0.15, 0.25) -- 아군 교전음 (은은하게)
		else
			floater(data.pos + Vector3.new(0, 3.5, 0), "-35", Color3.fromRGB(255, 220, 120))
			ping(0.55 + math.random() * 0.2, 0.5)
		end
	elseif data.type == "gachaResult" then
		resultCard.Visible = true
		local col = R_COL[data.rarity] or Color3.new(1, 1, 1)
		rcStroke.Color = col
		rcRarity.Text = (data.rarity == "S" and "✨ " or "") .. (R_KO[data.rarity] or data.rarity) .. (data.rarity == "S" and " ✨" or "")
		rcRarity.TextColor3 = col
		rcName.Text = data.name
		rcName.TextColor3 = col
		rcSkill.Text = "🎯 " .. data.skill .. (data.dupe and "  (중복 → 훈련점수)" or "")
		if data.rarity == "S" then
			ping(0.8, 0.9); ping(1.1, 0.9); ping(1.4, 0.9)
			shake(1.2, 0.4)
		elseif data.rarity == "R" then
			ping(0.9, 0.8); ping(1.2, 0.7)
		else
			ping(1.0, 0.6)
		end
		refreshTavern()
	elseif data.type == "srPull" then
		showBanner("✨ " .. data.who .. "님이 [슈퍼레어] " .. data.name .. " 영입!!", "선술집에서 모집 가능", 3.5)
	elseif data.type == "phase2" then
		phaseXTarget = 210
		FIRE_CD = 1.2
		fireLabel = "🎯 선회포"
		showBanner("⚡ 2막 — 총격전!", "적함 접근! 선회포로 선원 저격 · 갈고리를 잘라라", 3)
		play(0.5, 0.9)
	elseif data.type == "grapple" then
		spawnHook(data.id, data.z)
	elseif data.type == "grappleCut" then
		removeHook(data.id)
		floater(Vector3.new(12, 12, 0), "✂️ 절단!", Color3.fromRGB(140, 255, 170))
		ping(1.1, 0.7)
	elseif data.type == "grappleHit" then
		removeHook(data.id)
		shake(2.2, 0.5)
		showBanner("🪝 갈고리 적중!", "−120 선체 — 다음 갈고리는 잘라내세요", 1.8)
	elseif data.type == "profile" then
		mySilver = data.silver or 0
		if type(data.stars) == "table" then
			for i = 1, 3 do myStars[i] = data.stars[i] or 0 end
		end
		if type(data.upg) == "table" then
			for k in myUpg do myUpg[k] = data.upg[k] or 0 end
		end
		myPityR = data.pityR or 0
		myPityS = data.pityS or 0
		myTrain = data.train or 0
		if type(data.crew) == "table" then myCrew = data.crew end
		if type(data.squad) == "table" then mySquad = data.squad end
		refreshChart()
		refreshShop()
		refreshTavern()
	elseif data.type == "countdown" then
		chart.Visible = false
		winPanel.Visible = false
		phaseXTarget = 0
		phaseX = 0
		FIRE_CD = 6.0
		fireLabel = "💥 일제사격"
		for id in hooks do removeHook(id) end
		MAX_SAIL = math.max(1, data.max.sail)
		MAX_HULL = math.max(1, data.max.hull)
		MAX_DECK = math.max(1, data.max.deck)
		MAX_SHIP = math.max(1, data.max.ship)
		enemyTitle.Text = "⚔️ 적함 · " .. data.name
		task.spawn(function()
			for n = 3, 1, -1 do
				showBanner("⚓ 출항! " .. tostring(n), data.name .. " 접근 중…", 1)
				ping(0.8 + n * 0.1, 0.6)
				task.wait(1)
			end
			refreshBars()
		end)
	elseif data.type == "win" then
		local nm = STAGE_INFO[data.stage] and STAGE_INFO[data.stage].name or "적함"
		winTitle.Text = data.boarded and ("🏴‍☠️ %s 나포!! (×1.5)"):format(nm) or ("⚓ %s 격침!!"):format(nm)
		winInfo.Text = ("🪙 +%d  ·  %d초  ·  퍼펙트 %d회"):format(data.silver, data.elapsed, data.perfects)
		winStars.Text = ""
		winPanel.Visible = true
		task.spawn(function()
			for s = 1, 3 do
				task.wait(0.5)
				if s <= data.stars then
					winStars.Text = winStars.Text .. "⭐"
					ping(0.9 + s * 0.15, 0.8)
				else
					winStars.Text = winStars.Text .. "☆"
				end
			end
		end)
	elseif data.type == "lose" then
		showBanner("🌊 침몰… 구조됩니다", "손실 없음 — 해도에서 재도전", 3)
		task.delay(3, function()
			chart.Visible = true
			refreshChart()
		end)
	end
end)

showBanner("⚓ 해상전 v0.1 «포격전»", "해도에서 스테이지를 선택하세요", 4)

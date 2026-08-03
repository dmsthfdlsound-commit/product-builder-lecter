--------------------------------------------------------------------
-- +1 Pop! 뽁뽁이 탈출 (Bubble Wrap Escape) — v0.2
-- 코어 루프: 뽁뽁이를 밟으면 +1 Speed → 스피드 게이트 통과 → WIN → 리버스
-- v0.2: Wins로 사는 트레일 상점 (치장 전용 — 남을 이기는 힘은 팔지 않음)
-- 이 스크립트 하나가 맵 생성부터 저장까지 전부 담당합니다 (ServerScriptService)
--------------------------------------------------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------------
-- 설정 (밸런스는 여기서만 조정)
--------------------------------------------------------------------
local CONFIG = {
	BaseWalkSpeed = 16,
	SpeedToWalk = 0.06,      -- Speed 1당 걷기속도 보너스
	MaxWalkSpeed = 100,
	TileCooldown = 1.5,      -- 같은 뽁뽁이 재사용 대기(초, 플레이어별)
	PopRespawn = 2.5,        -- 터진 뽁뽁이 복구 시간
	TileSize = 5,
	FieldWidth = 10,         -- 뽁뽁이 가로 개수
	ZoneLength = 12,         -- 존당 뽁뽁이 세로 개수
	GateReqs = { 50, 150, 300, 500, 800 },
	RebirthBaseReq = 1000,   -- 리버스 요구치 = Base × (리버스+1)
	AutosaveInterval = 120,
	-- 트레일 상점 (Wins 재화, 치장 전용)
	Trails = {
		{ id = "bubble",  name = "🫧 비눗방울", price = 3,
			colors = { {170, 225, 255}, {255, 255, 255} }, lightEmission = 0.2 },
		{ id = "rainbow", name = "🌈 무지개", price = 10,
			colors = { {255, 80, 80}, {255, 220, 80}, {90, 220, 120}, {90, 160, 255}, {190, 110, 255} }, lightEmission = 0.4 },
		{ id = "gold",    name = "⭐ 황금", price = 25,
			colors = { {255, 220, 90}, {255, 150, 40} }, lightEmission = 1 },
	},
}

local function trailDefById(id)
	for _, def in CONFIG.Trails do
		if def.id == id then
			return def
		end
	end
	return nil
end

local ZONE_COLORS = {
	Color3.fromRGB(255, 214, 231), -- 딸기
	Color3.fromRGB(255, 236, 179), -- 바나나
	Color3.fromRGB(204, 236, 255), -- 소다
	Color3.fromRGB(214, 255, 214), -- 멜론
	Color3.fromRGB(233, 214, 255), -- 포도
}

--------------------------------------------------------------------
-- 서버 전광판 (클라이언트 HUD가 구독)
--------------------------------------------------------------------
local announce = Instance.new("StringValue")
announce.Name = "Announce"
announce.Parent = ReplicatedStorage

local function broadcast(text)
	announce.Value = "" -- 같은 문구 연속 방송도 Changed가 뜨도록
	announce.Value = text
end

--------------------------------------------------------------------
-- 플레이어 데이터 (leaderstats + DataStore)
--------------------------------------------------------------------
local store
pcall(function()
	store = DataStoreService:GetDataStore("Plus1Pop_v1")
end)

-- 트레일 소유/장착 상태 (서버 권위 — 클라이언트는 요청만)
local trailState = {} -- [player] = { owned = {id=true}, equipped = "id" or "" }

local function statsOf(player)
	local s = player:FindFirstChild("leaderstats")
	if not s then return nil end
	return s:FindFirstChild("Speed"), s:FindFirstChild("Wins"), s:FindFirstChild("Rebirths")
end

local function applyWalkSpeed(player)
	local speed, _, rebirths = statsOf(player)
	if not speed then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = math.min(CONFIG.BaseWalkSpeed + speed.Value * CONFIG.SpeedToWalk, CONFIG.MaxWalkSpeed)
	end
end

local function loadData(player)
	local data = { s = 0, w = 0, r = 0, t = {}, e = "" }
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			data.s = tonumber(saved.s) or 0
			data.w = tonumber(saved.w) or 0
			data.r = tonumber(saved.r) or 0
			if type(saved.t) == "table" then
				for _, id in saved.t do
					if trailDefById(id) then
						data.t[id] = true
					end
				end
			end
			if type(saved.e) == "string" and data.t[saved.e] then
				data.e = saved.e
			end
		end
	end
	return data
end

local function saveData(player)
	if not store then return end
	local speed, wins, rebirths = statsOf(player)
	if not speed then return end
	local state = trailState[player]
	local ownedIds = {}
	if state then
		for id in state.owned do
			table.insert(ownedIds, id)
		end
	end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, {
			s = speed.Value,
			w = wins.Value,
			r = rebirths.Value,
			t = ownedIds,
			e = state and state.equipped or "",
		})
	end)
end

-- 장착된 트레일을 캐릭터에 적용 (기존 것 제거 후 재생성)
local function applyEquippedTrail(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	for _, name in { "Plus1Trail", "Plus1TrailA0", "Plus1TrailA1" } do
		local old = root:FindFirstChild(name)
		if old then old:Destroy() end
	end

	local state = trailState[player]
	local def = state and trailDefById(state.equipped)
	if not def then return end

	local a0 = Instance.new("Attachment")
	a0.Name = "Plus1TrailA0"
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = root

	local a1 = Instance.new("Attachment")
	a1.Name = "Plus1TrailA1"
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = root

	local keypoints = {}
	local n = #def.colors
	for i, rgb in def.colors do
		local t = (n == 1) and 0 or (i - 1) / (n - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(t, Color3.fromRGB(rgb[1], rgb[2], rgb[3])))
	end

	local trail = Instance.new("Trail")
	trail.Name = "Plus1Trail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keypoints)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.55
	trail.FaceCamera = true
	trail.LightEmission = def.lightEmission or 0.2
	trail.Parent = root
end

Players.PlayerAdded:Connect(function(player)
	local data = loadData(player)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local speed = Instance.new("IntValue")
	speed.Name = "Speed"
	speed.Value = data.s
	speed.Parent = stats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = data.w
	wins.Parent = stats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.r
	rebirths.Parent = stats

	stats.Parent = player

	trailState[player] = { owned = data.t, equipped = data.e }

	speed.Changed:Connect(function()
		applyWalkSpeed(player)
	end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		applyWalkSpeed(player)
		applyEquippedTrail(player)
	end)
	if player.Character then
		applyWalkSpeed(player)
		applyEquippedTrail(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	trailState[player] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveData(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(CONFIG.AutosaveInterval)
		for _, player in Players:GetPlayers() do
			saveData(player)
		end
	end
end)

--------------------------------------------------------------------
-- 트레일 상점 (RemoteFunction) — 검증은 전부 서버에서
--------------------------------------------------------------------
local shopRF = Instance.new("RemoteFunction")
shopRF.Name = "TrailShop"
shopRF.Parent = ReplicatedStorage

local function shopSnapshot(player, ok, msg)
	local state = trailState[player] or { owned = {}, equipped = "" }
	local _, wins = statsOf(player)
	local catalog = {}
	for _, def in CONFIG.Trails do
		table.insert(catalog, {
			id = def.id,
			name = def.name,
			price = def.price,
			color = def.colors[1],
			owned = state.owned[def.id] == true,
			equipped = state.equipped == def.id,
		})
	end
	return { ok = ok ~= false, msg = msg or "", wins = wins and wins.Value or 0, catalog = catalog }
end

shopRF.OnServerInvoke = function(player, action, trailId)
	local state = trailState[player]
	local _, wins = statsOf(player)
	if not (state and wins) then
		return shopSnapshot(player, false, "로딩 중이에요, 잠시 후 다시!")
	end

	if action == "get" then
		return shopSnapshot(player)

	elseif action == "buy" then
		local def = trailDefById(trailId)
		if not def then
			return shopSnapshot(player, false, "없는 트레일이에요")
		end
		if state.owned[def.id] then
			return shopSnapshot(player, false, "이미 보유 중!")
		end
		if wins.Value < def.price then
			return shopSnapshot(player, false, ("Wins가 부족해요 (%d 필요)"):format(def.price))
		end
		wins.Value -= def.price
		state.owned[def.id] = true
		state.equipped = def.id -- 구매 즉시 장착 (첫 도파민)
		applyEquippedTrail(player)
		saveData(player)
		broadcast(("🛒 %s님이 %s 트레일 획득!"):format(player.Name, def.name))
		return shopSnapshot(player, true, def.name .. " 구매 & 장착 완료!")

	elseif action == "equip" then
		if trailId == nil or trailId == "" then
			state.equipped = ""
			applyEquippedTrail(player)
			saveData(player)
			return shopSnapshot(player, true, "트레일을 해제했어요")
		end
		local def = trailDefById(trailId)
		if not (def and state.owned[def.id]) then
			return shopSnapshot(player, false, "먼저 구매해야 해요")
		end
		state.equipped = def.id
		applyEquippedTrail(player)
		saveData(player)
		return shopSnapshot(player, true, def.name .. " 장착!")
	end

	return shopSnapshot(player, false, "알 수 없는 요청")
end

--------------------------------------------------------------------
-- 유틸
--------------------------------------------------------------------
local function playerFromHit(hit)
	local model = hit and hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model) or nil
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		part[k] = v
	end
	return part
end

local function popSound(parent)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav" -- 내장 사운드라 로딩 실패 없음
	sound.PlaybackSpeed = 0.9 + math.random() * 0.5
	sound.Volume = 0.5
	sound.Parent = parent
	sound:Play()
	task.delay(1, function() sound:Destroy() end)
end

local function makeLabel(parent, text, textColor, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromScale(14, 3.5)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = parent
	return label
end

--------------------------------------------------------------------
-- 맵 생성 (코드가 맵을 만들기 때문에 빈 Baseplate에서도 동작)
--------------------------------------------------------------------
local map = Instance.new("Folder")
map.Name = "Plus1Map"
map.Parent = workspace

local TILE = CONFIG.TileSize
local fieldWidthStuds = CONFIG.FieldWidth * TILE

-- 뽁뽁이 한 개
local function spawnBubble(x, z, zoneColor)
	local bubble = makePart({
		Name = "Bubble",
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(235, 250, 255),
		Transparency = 0.15,
		Size = Vector3.new(1.1, TILE - 0.9, TILE - 0.9),
		CFrame = CFrame.new(x, 0.55, z) * CFrame.Angles(0, 0, math.rad(90)),
		CanCollide = false,
	})
	bubble.Parent = map

	local popped = false
	local lastPopByPlayer = {}

	bubble.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or popped then return end

		local now = os.clock()
		if lastPopByPlayer[player] and now - lastPopByPlayer[player] < CONFIG.TileCooldown then
			return
		end
		lastPopByPlayer[player] = now

		local speed, _, rebirths = statsOf(player)
		if not speed then return end

		-- 리버스가 곧 배수: +1 × (리버스+1)
		speed.Value += 1 + rebirths.Value

		popped = true
		popSound(bubble)
		TweenService:Create(bubble, TweenInfo.new(0.12), {
			Size = Vector3.new(0.3, TILE - 2.2, TILE - 2.2),
			Transparency = 0.75,
			Color = zoneColor,
		}):Play()

		task.delay(CONFIG.PopRespawn, function()
			if not bubble.Parent then return end
			TweenService:Create(bubble, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
				Size = Vector3.new(1.1, TILE - 0.9, TILE - 0.9),
				Transparency = 0.15,
				Color = Color3.fromRGB(235, 250, 255),
			}):Play()
			task.wait(0.25)
			popped = false
		end)
	end)
end

-- 존(뽁뽁이 밭) 하나: 시작 z를 받아 끝 z를 돌려줌
local function buildZone(zoneIndex, zStart)
	local zoneColor = ZONE_COLORS[(zoneIndex - 1) % #ZONE_COLORS + 1]
	local lengthStuds = CONFIG.ZoneLength * TILE

	local ground = makePart({
		Name = "Ground" .. zoneIndex,
		Material = Enum.Material.SmoothPlastic,
		Color = zoneColor,
		Size = Vector3.new(fieldWidthStuds + 12, 1, lengthStuds + 4),
		CFrame = CFrame.new(0, -0.5, zStart + lengthStuds / 2),
	})
	ground.Parent = map

	for row = 0, CONFIG.ZoneLength - 1 do
		for col = 0, CONFIG.FieldWidth - 1 do
			local x = (col - (CONFIG.FieldWidth - 1) / 2) * TILE
			local z = zStart + row * TILE + TILE / 2
			spawnBubble(x, z, zoneColor)
		end
	end

	return zStart + lengthStuds
end

-- 스피드 게이트: 요구치 미달이면 되돌리고, 충족하면 통과 텔레포트
local function buildGate(req, z)
	local gate = makePart({
		Name = "Gate" .. req,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 105, 130),
		Transparency = 0.45,
		Size = Vector3.new(fieldWidthStuds + 12, 14, 2),
		CFrame = CFrame.new(0, 6.5, z),
	})
	gate.Parent = map

	local base = makePart({
		Name = "GateBase" .. req,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(90, 90, 110),
		Size = Vector3.new(fieldWidthStuds + 12, 1, 6),
		CFrame = CFrame.new(0, -0.5, z),
	})
	base.Parent = map

	makeLabel(gate, "🔒 Speed " .. req, Color3.new(1, 1, 1))

	local cooldown = {}
	gate.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then return end
		local now = os.clock()
		if cooldown[player] and now - cooldown[player] < 0.6 then return end
		cooldown[player] = now

		local char = player.Character
		local speed = statsOf(player)
		if not (char and speed) then return end

		local pivot = char:GetPivot()
		if speed.Value >= req then
			char:PivotTo(CFrame.new(pivot.Position.X, 4, z + 5)) -- 통과
			popSound(gate)
		else
			char:PivotTo(CFrame.new(pivot.Position.X, 4, z - 7)) -- 반동
			broadcast(("🔒 %s님: Speed %d 필요! (현재 %d)"):format(player.Name, req, speed.Value))
		end
	end)

	return z + 4
end

-- 스폰 구역
local spawnGround = makePart({
	Name = "SpawnGround",
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(250, 250, 255),
	Size = Vector3.new(fieldWidthStuds + 12, 1, 30),
	CFrame = CFrame.new(0, -0.5, -15),
})
spawnGround.Parent = map

local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(8, 1, 8)
spawnPad.CFrame = CFrame.new(0, 0.1, -20)
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Material = Enum.Material.Neon
spawnPad.Color = Color3.fromRGB(255, 255, 255)
spawnPad.TopSurface = Enum.SurfaceType.Smooth
spawnPad.Parent = map

-- 리버스 패드 (스폰 옆)
local rebirthPad = makePart({
	Name = "RebirthPad",
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 196, 66),
	Size = Vector3.new(10, 1, 10),
	CFrame = CFrame.new(-fieldWidthStuds / 2 - 8, 0.1, -20),
})
rebirthPad.Parent = map
local rebirthLabel = makeLabel(rebirthPad, "♻️ 리버스: Speed " .. CONFIG.RebirthBaseReq, Color3.fromRGB(255, 220, 120), UDim2.fromScale(18, 4))

do
	local cooldown = {}
	rebirthPad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then return end
		local now = os.clock()
		if cooldown[player] and now - cooldown[player] < 2 then return end
		cooldown[player] = now

		local speed, _, rebirths = statsOf(player)
		if not speed then return end
		local req = CONFIG.RebirthBaseReq * (rebirths.Value + 1)

		if speed.Value >= req then
			speed.Value = 0
			rebirths.Value += 1
			applyWalkSpeed(player)
			saveData(player)
			broadcast(("🎉 %s님이 리버스 %d회 달성!! (뽁 배수 ×%d)"):format(player.Name, rebirths.Value, rebirths.Value + 1))
		else
			broadcast(("♻️ %s님: 리버스까지 Speed %d 필요 (현재 %d)"):format(player.Name, req, speed.Value))
		end
	end)
end

-- 본편: 존 → 게이트 → 존 → ... → WIN 패드
local z = 0
for i, req in CONFIG.GateReqs do
	z = buildZone(i, z)
	z = buildGate(req, z + 2)
end

local finalGround = makePart({
	Name = "FinalGround",
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(212, 255, 227),
	Size = Vector3.new(fieldWidthStuds + 12, 1, 24),
	CFrame = CFrame.new(0, -0.5, z + 12),
})
finalGround.Parent = map

local winPad = makePart({
	Name = "WinPad",
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(64, 255, 128),
	Size = Vector3.new(12, 1, 12),
	CFrame = CFrame.new(0, 0.1, z + 12),
})
winPad.Parent = map
makeLabel(winPad, "🏆 WIN!", Color3.fromRGB(150, 255, 180), UDim2.fromScale(12, 4))

local sparkle = Instance.new("ParticleEmitter")
sparkle.Rate = 12
sparkle.Lifetime = NumberRange.new(0.8, 1.4)
sparkle.Speed = NumberRange.new(6, 12)
sparkle.SpreadAngle = Vector2.new(45, 45)
sparkle.Parent = winPad

do
	local cooldown = {}
	winPad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then return end
		local now = os.clock()
		if cooldown[player] and now - cooldown[player] < 3 then return end
		cooldown[player] = now

		local _, wins, rebirths = statsOf(player)
		if not wins then return end
		wins.Value += 1 + rebirths.Value
		saveData(player)
		broadcast(("🏆 %s님 탈출 성공! (+%d Win)"):format(player.Name, 1 + rebirths.Value))

		local char = player.Character
		if char then
			char:PivotTo(CFrame.new(0, 4, -20)) -- 스폰으로 귀환, Speed는 유지
		end
	end)
end

-- 리버스 요구치 라벨 실시간화: 플레이어별이 아니라 기본값 표시만 (v1)
print(("[+1 Pop] 맵 생성 완료 — 존 %d개, 게이트 %s, 총 길이 %d studs"):format(
	#CONFIG.GateReqs, table.concat(CONFIG.GateReqs, "/"), z + 24))

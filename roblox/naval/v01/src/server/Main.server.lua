--------------------------------------------------------------------
-- 해상전 v0.1 «포격전» — 해도(스테이지 선택) + 난이도 3종 + 별 평가
-- 스파이크 ①②(세트 트릭·포격) 위에 스테이지 구조를 얹은 첫 게임 형태.
-- 갑판 고정 원칙·서버 권위 판정 유지. 별/은화는 DataStore 저장.
--------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local CONFIG = {
	FireCooldown = 6.0,
	ShotDamage = 45,
	ShotSpread = 9,
	CannonCount = 4,
	ShipHP = 1200,
	BraceWindow = 1.0,
	PerfectWindow = 0.4,
}

-- 스테이지 3종 (클라이언트 해도와 동일 테이블 유지)
local STAGES = {
	{ id = 1, name = "연안 밀수선", hp = { Sail = 200, Hull = 400, Deck = 150 },
		volley = 70, interval = { 10, 13 }, firstDelay = 14, silver = 120,
		bonus = "time", bonusVal = 90, hullColor = Color3.fromRGB(90, 78, 60) },
	{ id = 2, name = "호송 스쿠너", hp = { Sail = 300, Hull = 600, Deck = 250 },
		volley = 95, interval = { 8, 11 }, firstDelay = 12, silver = 260,
		bonus = "strip", bonusVal = 0, hullColor = Color3.fromRGB(70, 50, 60) },
	{ id = 3, name = "사략 브리간틴", hp = { Sail = 400, Hull = 850, Deck = 350 },
		volley = 120, interval = { 7, 9 }, firstDelay = 10, silver = 520,
		bonus = "perfect", bonusVal = 5, hullColor = Color3.fromRGB(45, 40, 55) },
}

--------------------------------------------------------------------
-- 리모트
--------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function mkRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local RE_Fire = mkRemote("Fire")
local RE_FireResult = mkRemote("FireResult")
local RE_Volley = mkRemote("Volley")
local RE_Brace = mkRemote("Brace")
local RE_Game = mkRemote("GameEvent")
local RE_Select = mkRemote("SelectStage")
local RE_Battle = mkRemote("BattleEvent")
local RE_Shop = mkRemote("Shop")

-- 조선소 업그레이드 (성능은 은화로만 — 치장만 로벅스 원칙)
local UPGRADES = {
	cannon = { name = "포문 확장", costs = { 300, 800, 1800 } },  -- 일제사격 +1발/티어
	armor  = { name = "장갑판",   costs = { 250, 700, 1600 } },  -- 피격 ×0.88/0.78/0.70
	aim    = { name = "조준 보조", costs = { 200, 600, 1400 } },  -- 산포 9→7.25→5.5→3.75
}
local ARMOR_FACTOR = { [0] = 1.0, 0.88, 0.78, 0.70 }

-- 상태 (클라 HUD가 구독)
local state = Instance.new("Folder")
state.Name = "BattleState"
state.Parent = ReplicatedStorage
local function mkInt(name, v)
	local i = Instance.new("IntValue")
	i.Name = name
	i.Value = v
	i.Parent = state
	return i
end
local hpSail = mkInt("SailHP", 0)
local hpHull = mkInt("HullHP", 0)
local hpDeck = mkInt("DeckHP", 0)
local shipHP = mkInt("ShipHP", CONFIG.ShipHP)
local curStage = mkInt("Stage", 0) -- 0 = 해도 화면
local phase = mkInt("Phase", 1)    -- 1 = 포격전, 2 = 총격전, 3 = 백병전
local RE_Cut = mkRemote("CutGrapple")
local RE_Swing = mkRemote("Swing")
local PHASE3_OFFSET = 291          -- 3막 적함 시각 위치 = 330 − 291 = X 39 (현측 접현)

--------------------------------------------------------------------
-- 월드 생성
--------------------------------------------------------------------
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

local world = Instance.new("Folder")
world.Name = "NavalWorld"
world.Parent = workspace

-- 바다 (클라가 Y를 흔든다)
local ocean = part({
	Name = "Ocean", Size = Vector3.new(3000, 1, 3000),
	CFrame = CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(52, 132, 185),
	Material = Enum.Material.SmoothPlastic, Transparency = 0.12,
}, world)
part({
	Name = "OceanDeep", Size = Vector3.new(3000, 1, 3000),
	CFrame = CFrame.new(0, -7, 0), Color = Color3.fromRGB(22, 70, 110),
	Material = Enum.Material.SmoothPlastic,
}, world)
-- 포말 (클라가 드리프트)
local foam = Instance.new("Folder")
foam.Name = "Foam"
foam.Parent = world
math.randomseed(7)
for i = 1, 26 do
	part({
		Name = "F" .. i, Size = Vector3.new(math.random(8, 16), 0.2, 1.6),
		CFrame = CFrame.new(math.random(-500, 500), 0.15, math.random(-500, 500)),
		Color = Color3.fromRGB(235, 248, 255), Transparency = 0.45,
		CanCollide = false, Material = Enum.Material.SmoothPlastic,
	}, foam)
end

-- 아군 함선 (완전 고정 — 세트)
local myShip = Instance.new("Model")
myShip.Name = "PlayerShip"
myShip.Parent = world
part({ Name = "Hull", Size = Vector3.new(26, 8, 60), CFrame = CFrame.new(0, 2, 0),
	Color = Color3.fromRGB(96, 66, 42), Material = Enum.Material.WoodPlanks }, myShip)
local deck = part({ Name = "Deck", Size = Vector3.new(24, 2, 56), CFrame = CFrame.new(0, 7, 0),
	Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks }, myShip)
for _, side in { -1, 1 } do
	part({ Name = "Rail", Size = Vector3.new(1, 3, 56), CFrame = CFrame.new(side * 12.2, 9.5, 0),
		Color = Color3.fromRGB(96, 66, 42), Material = Enum.Material.Wood }, myShip)
end
for _, zEnd in { -28, 28 } do
	part({ Name = "RailEnd", Size = Vector3.new(24, 3, 1), CFrame = CFrame.new(0, 9.5, zEnd),
		Color = Color3.fromRGB(96, 66, 42), Material = Enum.Material.Wood }, myShip)
end
for _, mz in { -14, 12 } do
	part({ Name = "Mast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(30, 2.2, 2.2),
		CFrame = CFrame.new(0, 23, mz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 85, 55), Material = Enum.Material.Wood }, myShip)
	part({ Name = "Sail", Size = Vector3.new(17, 13, 0.4), CFrame = CFrame.new(0, 21, mz),
		Color = Color3.fromRGB(245, 240, 225), Material = Enum.Material.Fabric }, myShip)
end
-- 아군 대포 (우현 = +X, 적 방향)
local muzzles = {}
for i, cz in { -18, -6, 6, 18 } do
	local c = part({ Name = "Cannon" .. i, Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6.5, 1.8, 1.8), CFrame = CFrame.new(12.5, 9, cz),
		Color = Color3.fromRGB(45, 45, 52), Material = Enum.Material.Metal }, myShip)
	c:SetAttribute("PlayerCannon", true)
	muzzles[i] = Vector3.new(16.2, 9, cz)
end
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(10, 1, 10)
spawnPad.CFrame = CFrame.new(0, 8.6, 18)
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Transparency = 1
spawnPad.Parent = myShip

-- 적함 (서버는 정적 — 흔들림은 클라 연출)
local enemy = Instance.new("Model")
enemy.Name = "EnemyShip"
enemy.Parent = world
local function seg(p, s) p:SetAttribute("Seg", s) return p end
seg(part({ Name = "EHull", Size = Vector3.new(26, 9, 72), CFrame = CFrame.new(330, 2.5, 0),
	Color = Color3.fromRGB(70, 50, 60), Material = Enum.Material.WoodPlanks }, enemy), "Hull")
seg(part({ Name = "EHullTop", Size = Vector3.new(24, 3, 68), CFrame = CFrame.new(330, 8.5, 0),
	Color = Color3.fromRGB(88, 62, 72), Material = Enum.Material.WoodPlanks }, enemy), "Hull")
local eDeck = seg(part({ Name = "EDeck", Size = Vector3.new(22, 1, 64), CFrame = CFrame.new(330, 10.2, 0),
	Color = Color3.fromRGB(140, 100, 66), Material = Enum.Material.WoodPlanks }, enemy), "Deck")
for _, mz in { -16, 14 } do
	seg(part({ Name = "EMast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(34, 2.4, 2.4),
		CFrame = CFrame.new(330, 27, mz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood }, enemy), "Sail")
	seg(part({ Name = "ESail", Size = Vector3.new(19, 15, 0.5), CFrame = CFrame.new(330, 24, mz),
		Color = Color3.fromRGB(230, 220, 200), Material = Enum.Material.Fabric }, enemy), "Sail")
end
-- 적 선원 표적 (갑판 전략)
for i, cz in { -20, -8, 5, 18 } do
	seg(part({ Name = "ECrew" .. i, Size = Vector3.new(2.2, 5, 2.2),
		CFrame = CFrame.new(324 + (i % 2) * 10, 13.2, cz),
		Color = Color3.fromRGB(190, 150, 110), Material = Enum.Material.SmoothPlastic }, enemy), "Deck")
end
-- 적 일제사격 포 (아군 방향 -X)
for i, cz in { -22, -8, 8, 22 } do
	local c = part({ Name = "EVolleyCannon" .. i, Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 1.8, 1.8), CFrame = CFrame.new(316.5, 9.5, cz),
		Color = Color3.fromRGB(40, 38, 46), Material = Enum.Material.Metal }, enemy)
	c:SetAttribute("VolleyCannon", true)
end

--------------------------------------------------------------------
-- 전투 상태 (FSM: 해도(0) → 전투(stage) → 결과 → 해도)
--------------------------------------------------------------------
local lastFire = {}   -- [player] = os.clock
local lastBrace = {}  -- [player] = os.clock
local sunk = false
local battleActive = false
local stageCfg = nil
local battleStats = { startT = 0, perfects = 0 }

local store
pcall(function() store = DataStoreService:GetDataStore("NavalV01_v1") end)
local profiles = {} -- [player] = { silver = n, stars = {0,0,0} }

local function pushProfile(player)
	local pf = profiles[player]
	if pf then
		RE_Battle:FireClient(player, { type = "profile",
			silver = pf.silver, stars = pf.stars, upg = pf.upg })
	end
end

local function saveProfile(player)
	local pf = profiles[player]
	if not (store and pf) then return end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, { silver = pf.silver, stars = pf.stars, upg = pf.upg })
	end)
end

Players.PlayerAdded:Connect(function(player)
	local pf = { silver = 0, stars = { 0, 0, 0 }, upg = { cannon = 0, armor = 0, aim = 0 } }
	if store then
		local ok, saved = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
		if ok and type(saved) == "table" then
			pf.silver = tonumber(saved.silver) or 0
			if type(saved.stars) == "table" then
				for i = 1, 3 do pf.stars[i] = tonumber(saved.stars[i]) or 0 end
			end
			if type(saved.upg) == "table" then
				for k in pf.upg do pf.upg[k] = math.clamp(tonumber(saved.upg[k]) or 0, 0, 3) end
			end
		end
	end
	profiles[player] = pf
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local s = Instance.new("IntValue"); s.Name = "은화"; s.Value = pf.silver; s.Parent = stats
	local p = Instance.new("IntValue"); p.Name = "퍼펙트"; p.Value = 0; p.Parent = stats
	stats.Parent = player
	task.delay(1, function() pushProfile(player) end)
end)
Players.PlayerRemoving:Connect(function(player)
	saveProfile(player)
	profiles[player] = nil
	lastFire[player] = nil
	lastBrace[player] = nil
end)
game:BindToClose(function()
	for _, plr in Players:GetPlayers() do saveProfile(plr) end
end)

local function addStat(player, name, n)
	local v = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild(name)
	if v then v.Value += n end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { enemy }

--------------------------------------------------------------------
-- 승리 처리 (격침 or 나포)
--------------------------------------------------------------------
local boardFolder = nil -- 3막 임시 오브젝트 (널판·적 선원)

local function clearBoarding()
	if boardFolder then boardFolder:Destroy(); boardFolder = nil end
end

local function winStage(boarded)
	if sunk then return end
	sunk = true
	battleActive = false
	local cfg = stageCfg
	local elapsed = os.clock() - battleStats.startT
	local stars = 1
	if shipHP.Value >= CONFIG.ShipHP * 0.75 then stars += 1 end
	local bonusOk = false
	if cfg.bonus == "time" then bonusOk = elapsed <= cfg.bonusVal
	elseif cfg.bonus == "strip" then bonusOk = (hpSail.Value <= 0 and hpDeck.Value <= 0)
	elseif cfg.bonus == "perfect" then bonusOk = battleStats.perfects >= cfg.bonusVal end
	if bonusOk then stars += 1 end
	local reward = boarded and math.floor(cfg.silver * 1.5) or cfg.silver

	RE_Game:FireAllClients({ type = boarded and "captured" or "sunk",
		sails = hpSail.Value <= 0, crew = hpDeck.Value <= 0 })
	for _, plr in Players:GetPlayers() do
		local pf = profiles[plr]
		if pf then
			pf.silver += reward
			if stars > (pf.stars[cfg.id] or 0) then pf.stars[cfg.id] = stars end
			local lv = plr:FindFirstChild("leaderstats")
			local sv = lv and lv:FindFirstChild("은화")
			if sv then sv.Value = pf.silver end
			saveProfile(plr)
			pushProfile(plr)
		end
	end
	task.delay(3.5, function()
		clearBoarding()
		curStage.Value = 0
		RE_Battle:FireAllClients({ type = "win", stage = cfg.id, stars = stars,
			silver = reward, boarded = boarded == true,
			elapsed = math.floor(elapsed), perfects = battleStats.perfects })
	end)
end

--------------------------------------------------------------------
-- 3막: 도선 백병전 (선원 NPC = CFrame 스테퍼, 물리 리스크 0)
-- 주의: 3막 오브젝트는 적함의 '시각적' 위치(X≈39)에 스폰 —
-- 플레이어 물리는 클라이언트에서 돌므로 클라가 옮겨둔 갑판 위를 걸을 수 있다.
--------------------------------------------------------------------
local crews = {}

local function startBoarding()
	if not battleActive or sunk then return end
	clearBoarding()
	boardFolder = Instance.new("Folder")
	boardFolder.Name = "Boarding"
	boardFolder.Parent = workspace
	local ex = 330 - PHASE3_OFFSET -- 적함 시각 중심 X ≈ 39
	for _, pz in { -12, 12 } do
		part({ Name = "Plank", Size = Vector3.new(17, 0.6, 3.4),
			CFrame = CFrame.new((12.2 + (ex - 12)) / 2, 9.4, pz) * CFrame.Angles(0, 0, math.rad(-9)),
			Color = Color3.fromRGB(170, 130, 85), Material = Enum.Material.WoodPlanks }, boardFolder)
	end
	table.clear(crews)
	for i = 1, 4 do
		local m = Instance.new("Model")
		m.Name = "BCrew" .. i
		local root = part({ Name = "Body", Size = Vector3.new(2.4, 5, 1.6),
			CFrame = CFrame.new(ex - 4 + (i % 2) * 8, 13.4, -18 + i * 8),
			Color = Color3.fromRGB(165, 120, 95), Material = Enum.Material.SmoothPlastic }, m)
		part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8),
			CFrame = root.CFrame * CFrame.new(0, 3.3, 0),
			Color = Color3.fromRGB(255, 90, 80), Material = Enum.Material.SmoothPlastic, CanCollide = false }, m)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(4, 0.9); bb.StudsOffset = Vector3.new(0, 3.4, 0); bb.AlwaysOnTop = true
		bb.Parent = root
		local hpBar = Instance.new("Frame")
		hpBar.Size = UDim2.fromScale(1, 0.4); hpBar.Position = UDim2.fromScale(0, 0.3)
		hpBar.BackgroundColor3 = Color3.fromRGB(230, 70, 60); hpBar.Parent = bb
		m.Parent = boardFolder
		crews[i] = { model = m, root = root, hp = 80, lastAtk = 0, alive = true, bar = hpBar }
	end
end

local function crewAlive()
	local n = 0
	for _, c in crews do
		if c.alive then n += 1 end
	end
	return n
end

-- 선원 AI 스테퍼
task.spawn(function()
	while true do
		task.wait(1 / 15)
		if not battleActive or sunk or phase.Value ~= 3 or not boardFolder then continue end
		local now = os.clock()
		for _, rec in crews do
			if rec.alive and rec.root.Parent then
				local best, bestD = nil, math.huge
				for _, plr in Players:GetPlayers() do
					local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
					if hrp and hum and hum.Health > 0 then
						local d = (hrp.Position - rec.root.Position).Magnitude
						if d < bestD then best, bestD = hrp, d end
					end
				end
				if best then
					if bestD > 5 then
						local dir = (best.Position - rec.root.Position) * Vector3.new(1, 0, 1)
						if dir.Magnitude > 0.1 then
							rec.model:PivotTo(CFrame.lookAt(rec.root.Position + dir.Unit * (9.5 / 15),
								rec.root.Position + dir.Unit * 10))
						end
					elseif now - rec.lastAtk > 1.4 then
						rec.lastAtk = now
						local hum = best.Parent and best.Parent:FindFirstChildOfClass("Humanoid")
						if hum then hum:TakeDamage(10) end
					end
				end
			end
		end
	end
end)

-- 커틀러스 검격 (3막 전용)
RE_Swing.OnServerEvent:Connect(function(player)
	if not battleActive or sunk or phase.Value ~= 3 then return end
	local now = os.clock()
	if lastFire[player] and now - lastFire[player] < 0.45 then return end
	lastFire[player] = now
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	for _, rec in crews do
		if rec.alive then
			local off = rec.root.Position - hrp.Position
			if off.Magnitude <= 10 and off.Unit:Dot(hrp.CFrame.LookVector) >= 0.35 then
				rec.hp -= 35
				rec.bar.Size = UDim2.fromScale(math.max(0, rec.hp / 80), 0.4)
				RE_Battle:FireAllClients({ type = "crewHit", pos = rec.root.Position })
				if rec.hp <= 0 then
					rec.alive = false
					local m = rec.model
					task.spawn(function()
						for k = 1, 10 do
							m:PivotTo(m:GetPivot() * CFrame.new(0, -0.3, 0) * CFrame.Angles(0.1, 0, 0.05))
							for _, p in m:GetDescendants() do
								if p:IsA("BasePart") then p.Transparency = k / 10; p.CanCollide = false end
							end
							task.wait(0.05)
						end
						m:Destroy()
					end)
					if crewAlive() == 0 then winStage(true) end
				end
			end
		end
	end
end)

-- 커틀러스 지급 (항시 보유, 3막에서만 유효)
local StarterPack = game:GetService("StarterPack")
local cutlass = Instance.new("Tool")
cutlass.Name = "커틀러스"
cutlass.RequiresHandle = true
cutlass.CanBeDropped = false
local chandle = Instance.new("Part")
chandle.Name = "Handle"
chandle.Size = Vector3.new(0.4, 4.6, 0.7)
chandle.Color = Color3.fromRGB(200, 205, 215)
chandle.Material = Enum.Material.Metal
chandle.CanCollide = false
chandle.Parent = cutlass
cutlass.Grip = CFrame.new(0, -1.6, 0)
cutlass.Parent = StarterPack

-- 발사 처리
RE_Fire.OnServerEvent:Connect(function(player, aimPos)
	if sunk or not battleActive or phase.Value == 3 then return end
	if typeof(aimPos) ~= "Vector3" then return end
	local now = os.clock()
	local cd = phase.Value == 2 and 1.2 or CONFIG.FireCooldown
	if lastFire[player] and now - lastFire[player] < cd - 0.15 then return end
	lastFire[player] = now
	-- 조준점 새니티: 적함 근방만 허용
	if (aimPos - Vector3.new(330, 12, 0)).Magnitude > 140 then return end

	local pf = profiles[player]
	local upg = pf and pf.upg or { cannon = 0, armor = 0, aim = 0 }
	local shotCount = CONFIG.CannonCount + upg.cannon
	local spread = CONFIG.ShotSpread - upg.aim * 1.75
	if phase.Value == 2 then
		shotCount = 1        -- 2막: 선회포 단발 (빠른 연사, 저격)
		spread = 2.5
	end

	local shots = {}
	for i = 1, shotCount do
		local from = muzzles[(i - 1) % #muzzles + 1]
		local target = aimPos + Vector3.new(
			(math.random() - 0.5) * 2 * spread,
			(math.random() - 0.5) * 2 * spread * 0.7,
			(math.random() - 0.5) * 2 * spread)
		local dir = (target - from).Unit * 600
		local hit = workspace:Raycast(from, dir, rayParams)
		local shot = { from = from, to = target, seg = "Miss", dmg = 0 }
		if hit then
			local segName = hit.Instance:GetAttribute("Seg") or "Hull"
			shot.to = hit.Position
			shot.seg = segName
			shot.dmg = CONFIG.ShotDamage
			if phase.Value == 2 then
				-- 선회포: 대인 저격 특화 (갑판 40 / 선체 25 / 돛 15)
				shot.dmg = segName == "Deck" and 40 or (segName == "Hull" and 25 or 15)
			end
			if segName == "Sail" and hpSail.Value > 0 then
				hpSail.Value = math.max(0, hpSail.Value - shot.dmg)
			elseif segName == "Deck" and hpDeck.Value > 0 then
				hpDeck.Value = math.max(0, hpDeck.Value - shot.dmg)
			else
				shot.seg = "Hull"
				hpHull.Value = math.max(0, hpHull.Value - shot.dmg)
			end
		else
			-- 물기둥 연출용: 수면 교차점
			local tWater = from.Y / math.max(0.1, -dir.Unit.Y)
			if dir.Unit.Y < 0 then
				shot.to = from + dir.Unit * math.min(tWater, 550)
			end
		end
		table.insert(shots, shot)
	end
	RE_FireResult:FireAllClients({ shooter = player.Name, shots = shots })

	-- 1막 → 2막 전환: 적 선체 50% 붕괴 시 접근전
	if phase.Value == 1 and battleActive and not sunk
		and hpHull.Value <= math.floor(stageCfg.hp.Hull * 0.5) and hpHull.Value > 0 then
		phase.Value = 2
		RE_Battle:FireAllClients({ type = "phase2" })
	end

	-- 2막 → 3막 도선: 적 선체 25% 이하
	if phase.Value == 2 and battleActive and not sunk
		and hpHull.Value > 0 and hpHull.Value <= math.floor(stageCfg.hp.Hull * 0.25) then
		phase.Value = 3
		RE_Battle:FireAllClients({ type = "phase3" })
		task.delay(3.5, startBoarding)
	end

	-- 격침 = 스테이지 승리 (1·2막에서 선체 0)
	if hpHull.Value <= 0 and not sunk then
		winStage(false)
	end
end)

RE_Brace.OnServerEvent:Connect(function(player)
	lastBrace[player] = os.clock()
end)

-- 적 일제사격 루프 (전투 중에만)
task.spawn(function()
	while true do
		task.wait(0.5)
		if not battleActive or sunk or phase.Value == 3 or #Players:GetPlayers() == 0 then continue end
		local cfg = stageCfg
		local interval = math.random(cfg.interval[1], cfg.interval[2])
		if hpSail.Value <= 0 then interval = math.floor(interval * 1.6) end -- 돛 파괴 → 재장전 지연
		local waited = 0
		while waited < interval do
			task.wait(0.25)
			waited += 0.25
			if not battleActive then break end
		end
		if not battleActive or sunk then continue end

		RE_Volley:FireAllClients({ phase = "warn" })
		task.wait(1.0)
		if not battleActive or sunk or phase.Value == 3 then continue end
		local impactT = os.clock()

		local bestFactor, bestGrade = 1.0, "full"
		for _, plr in Players:GetPlayers() do
			local bt = lastBrace[plr]
			if bt then
				local delta = impactT - bt
				if delta >= 0 and delta <= CONFIG.PerfectWindow then
					if 0.2 < bestFactor then bestFactor, bestGrade = 0.2, "perfect" end
					addStat(plr, "퍼펙트", 1)
					battleStats.perfects += 1
				elseif delta >= 0 and delta <= CONFIG.BraceWindow and bestFactor > 0.45 then
					bestFactor, bestGrade = 0.45, "brace"
				end
			end
		end

		local dmg = math.random(cfg.volley - 15, cfg.volley + 15)
		if hpDeck.Value <= 0 then dmg = math.floor(dmg * 0.5) end -- 선원 제압 → 화력 반감
		-- 장갑판: 접속자 중 최고 티어 적용 (협동 보너스)
		local bestArmor = 0
		for _, plr in Players:GetPlayers() do
			local p = profiles[plr]
			if p and p.upg.armor > bestArmor then bestArmor = p.upg.armor end
		end
		dmg = math.floor(dmg * ARMOR_FACTOR[bestArmor])
		dmg = math.floor(dmg * bestFactor)
		shipHP.Value = math.max(0, shipHP.Value - dmg)

		RE_Volley:FireAllClients({ phase = "hit", dmg = dmg, grade = bestGrade, shipHP = shipHP.Value })

		if shipHP.Value <= 0 then
			battleActive = false
			RE_Game:FireAllClients({ type = "defeat" })
			task.wait(4)
			curStage.Value = 0
			RE_Battle:FireAllClients({ type = "lose", stage = cfg.id })
		end
	end
end)

--------------------------------------------------------------------
-- 해도: 스테이지 선택 → 전투 시작
--------------------------------------------------------------------
local enemyHullParts = {}
for _, p in enemy:GetDescendants() do
	if p:IsA("BasePart") and p:GetAttribute("Seg") == "Hull" then
		table.insert(enemyHullParts, p)
	end
end

RE_Select.OnServerEvent:Connect(function(player, stageId)
	if battleActive or curStage.Value ~= 0 then return end
	stageId = tonumber(stageId)
	local cfg = STAGES[stageId]
	if not cfg then return end
	-- 잠금: 이전 스테이지 별 1개 이상
	local pf = profiles[player]
	if stageId > 1 and (not pf or (pf.stars[stageId - 1] or 0) < 1) then return end

	stageCfg = cfg
	curStage.Value = stageId
	phase.Value = 1
	clearBoarding()
	sunk = false
	hpSail.Value = cfg.hp.Sail
	hpHull.Value = cfg.hp.Hull
	hpDeck.Value = cfg.hp.Deck
	shipHP.Value = CONFIG.ShipHP
	for _, p in enemyHullParts do p.Color = cfg.hullColor end -- 스테이지별 적함 색

	RE_Battle:FireAllClients({ type = "countdown", stage = stageId, name = cfg.name,
		max = { sail = cfg.hp.Sail, hull = cfg.hp.Hull, deck = cfg.hp.Deck, ship = CONFIG.ShipHP },
		firstDelay = cfg.firstDelay, bonus = cfg.bonus, bonusVal = cfg.bonusVal })
	task.delay(3, function()
		battleStats = { startT = os.clock(), perfects = 0 }
		battleActive = true
		RE_Game:FireAllClients({ type = "respawn" })
	end)
	-- 첫 일제사격 유예: 루프가 0.5s 폴링이므로 firstDelay는 클라 안내용 + 인터벌 하한으로 보장
end)

--------------------------------------------------------------------
-- 2막: 갈고리 러시 (차단 못 하면 선체 피해)
--------------------------------------------------------------------
local grapples = {}   -- [id] = true (활성)
local grappleId = 0

local function shipDefeat()
	battleActive = false
	RE_Game:FireAllClients({ type = "defeat" })
	task.delay(4, function()
		curStage.Value = 0
		RE_Battle:FireAllClients({ type = "lose", stage = stageCfg and stageCfg.id or 0 })
	end)
end

task.spawn(function()
	while true do
		task.wait(1)
		if not battleActive or sunk or phase.Value ~= 2 then continue end
		task.wait(math.random(4, 7))
		if not battleActive or sunk or phase.Value ~= 2 then continue end
		grappleId += 1
		local id = grappleId
		grapples[id] = true
		local z = math.random(-20, 20)
		RE_Battle:FireAllClients({ type = "grapple", id = id, z = z })
		task.delay(2.6, function()
			if grapples[id] then
				grapples[id] = nil
				shipHP.Value = math.max(0, shipHP.Value - 120)
				RE_Battle:FireAllClients({ type = "grappleHit", id = id, shipHP = shipHP.Value })
				if shipHP.Value <= 0 and battleActive then shipDefeat() end
			end
		end)
	end
end)

RE_Cut.OnServerEvent:Connect(function(player, id)
	id = tonumber(id)
	if id and grapples[id] then
		grapples[id] = nil
		RE_Battle:FireAllClients({ type = "grappleCut", id = id, by = player.Name })
	end
end)

-- 조선소 구매 (서버 권위)
RE_Shop.OnServerEvent:Connect(function(player, line)
	if battleActive then return end
	local pf = profiles[player]
	local def = UPGRADES[line]
	if not (pf and def) then return end
	local tier = pf.upg[line] or 0
	if tier >= 3 then return end
	local cost = def.costs[tier + 1]
	if pf.silver < cost then return end
	pf.silver -= cost
	pf.upg[line] = tier + 1
	local lv = player:FindFirstChild("leaderstats")
	local sv = lv and lv:FindFirstChild("은화")
	if sv then sv.Value = pf.silver end
	saveProfile(player)
	pushProfile(player)
end)

print("[NavalV01] 해도 대기 — 스테이지를 선택하세요")

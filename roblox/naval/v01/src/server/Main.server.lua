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
	if pf then RE_Battle:FireClient(player, { type = "profile", silver = pf.silver, stars = pf.stars }) end
end

local function saveProfile(player)
	local pf = profiles[player]
	if not (store and pf) then return end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, { silver = pf.silver, stars = pf.stars })
	end)
end

Players.PlayerAdded:Connect(function(player)
	local pf = { silver = 0, stars = { 0, 0, 0 } }
	if store then
		local ok, saved = pcall(function() return store:GetAsync("p_" .. player.UserId) end)
		if ok and type(saved) == "table" then
			pf.silver = tonumber(saved.silver) or 0
			if type(saved.stars) == "table" then
				for i = 1, 3 do pf.stars[i] = tonumber(saved.stars[i]) or 0 end
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

-- 발사 처리
RE_Fire.OnServerEvent:Connect(function(player, aimPos)
	if sunk or not battleActive then return end
	if typeof(aimPos) ~= "Vector3" then return end
	local now = os.clock()
	if lastFire[player] and now - lastFire[player] < CONFIG.FireCooldown - 0.15 then return end
	lastFire[player] = now
	-- 조준점 새니티: 적함 근방만 허용
	if (aimPos - Vector3.new(330, 12, 0)).Magnitude > 140 then return end

	local shots = {}
	for i = 1, CONFIG.CannonCount do
		local from = muzzles[i]
		local target = aimPos + Vector3.new(
			(math.random() - 0.5) * 2 * CONFIG.ShotSpread,
			(math.random() - 0.5) * 2 * CONFIG.ShotSpread * 0.7,
			(math.random() - 0.5) * 2 * CONFIG.ShotSpread)
		local dir = (target - from).Unit * 600
		local hit = workspace:Raycast(from, dir, rayParams)
		local shot = { from = from, to = target, seg = "Miss", dmg = 0 }
		if hit then
			local segName = hit.Instance:GetAttribute("Seg") or "Hull"
			shot.to = hit.Position
			shot.seg = segName
			shot.dmg = CONFIG.ShotDamage
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

	-- 격침 = 스테이지 승리
	if hpHull.Value <= 0 and not sunk then
		sunk = true
		battleActive = false
		local cfg = stageCfg
		local elapsed = os.clock() - battleStats.startT
		-- 별 계산: ①승리 ②아군 선체 75%+ ③스테이지별 보너스
		local stars = 1
		if shipHP.Value >= CONFIG.ShipHP * 0.75 then stars += 1 end
		local bonusOk = false
		if cfg.bonus == "time" then bonusOk = elapsed <= cfg.bonusVal
		elseif cfg.bonus == "strip" then bonusOk = (hpSail.Value <= 0 and hpDeck.Value <= 0)
		elseif cfg.bonus == "perfect" then bonusOk = battleStats.perfects >= cfg.bonusVal end
		if bonusOk then stars += 1 end

		RE_Game:FireAllClients({ type = "sunk", sails = hpSail.Value <= 0, crew = hpDeck.Value <= 0 })
		for _, plr in Players:GetPlayers() do
			local pf = profiles[plr]
			if pf then
				pf.silver += cfg.silver
				if stars > (pf.stars[cfg.id] or 0) then pf.stars[cfg.id] = stars end
				local lv = plr:FindFirstChild("leaderstats")
				local sv = lv and lv:FindFirstChild("은화")
				if sv then sv.Value = pf.silver end
				saveProfile(plr)
				pushProfile(plr)
			end
		end
		task.delay(3.5, function()
			curStage.Value = 0
			RE_Battle:FireAllClients({ type = "win", stage = cfg.id, stars = stars,
				silver = cfg.silver, elapsed = math.floor(elapsed), perfects = battleStats.perfects })
		end)
	end
end)

RE_Brace.OnServerEvent:Connect(function(player)
	lastBrace[player] = os.clock()
end)

-- 적 일제사격 루프 (전투 중에만)
task.spawn(function()
	while true do
		task.wait(0.5)
		if not battleActive or sunk or #Players:GetPlayers() == 0 then continue end
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
		if not battleActive or sunk then continue end
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

print("[NavalV01] 해도 대기 — 스테이지를 선택하세요")

--------------------------------------------------------------------
-- 해상전 스파이크 v0 — 1막 포격전 + 세트 트릭 검증용
-- 설계: 갑판은 절대 움직이지 않는다. 바다·적함·카메라만 움직인다(클라 연출).
-- 서버 = 정적 월드 생성 + 전투 권위(발사 판정·적 일제사격·HP).
-- ⚠️ 스파이크 전용 코드 — 본편은 design.md 아키텍처로 재작성 예정.
--------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	FireCooldown = 6.0,
	ShotDamage = 45,
	ShotSpread = 9,          -- 착탄 산포 (studs)
	CannonCount = 4,
	EnemyHP = { Sail = 300, Hull = 600, Deck = 250 },
	ShipHP = 1200,           -- 아군 선체 (공유)
	VolleyBase = 95,         -- 적 일제사격 기본 피해
	VolleyInterval = { 8, 11 },
	VolleyFirstDelay = 12,   -- 리스폰 후 첫 공격 유예
	BraceWindow = 1.0,       -- 경고~착탄 사이 브레이스 인정
	PerfectWindow = 0.4,     -- 착탄 직전 퍼펙트 창
	SinkRespawn = 9,
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
local hpSail = mkInt("SailHP", CONFIG.EnemyHP.Sail)
local hpHull = mkInt("HullHP", CONFIG.EnemyHP.Hull)
local hpDeck = mkInt("DeckHP", CONFIG.EnemyHP.Deck)
local shipHP = mkInt("ShipHP", CONFIG.ShipHP)

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
-- 전투 상태
--------------------------------------------------------------------
local lastFire = {}   -- [player] = os.clock
local lastBrace = {}  -- [player] = os.clock
local sunk = false
local roundActive = true

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local s = Instance.new("IntValue"); s.Name = "격침"; s.Value = 0; s.Parent = stats
	local p = Instance.new("IntValue"); p.Name = "퍼펙트"; p.Value = 0; p.Parent = stats
	stats.Parent = player
end)
Players.PlayerRemoving:Connect(function(player)
	lastFire[player] = nil
	lastBrace[player] = nil
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
	if sunk or not roundActive then return end
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

	-- 격침 판정
	if hpHull.Value <= 0 and not sunk then
		sunk = true
		RE_Game:FireAllClients({ type = "sunk",
			sails = hpSail.Value <= 0, crew = hpDeck.Value <= 0 })
		for _, plr in Players:GetPlayers() do addStat(plr, "격침", 1) end
		task.delay(CONFIG.SinkRespawn, function()
			hpSail.Value = CONFIG.EnemyHP.Sail
			hpHull.Value = CONFIG.EnemyHP.Hull
			hpDeck.Value = CONFIG.EnemyHP.Deck
			shipHP.Value = math.min(CONFIG.ShipHP, shipHP.Value + 400) -- 격침 보상: 수리
			sunk = false
			RE_Game:FireAllClients({ type = "respawn" })
		end)
	end
end)

RE_Brace.OnServerEvent:Connect(function(player)
	lastBrace[player] = os.clock()
end)

-- 적 일제사격 루프
task.spawn(function()
	task.wait(CONFIG.VolleyFirstDelay)
	while true do
		local interval = math.random(CONFIG.VolleyInterval[1], CONFIG.VolleyInterval[2])
		-- 돛 파괴 시 재장전 느려짐 (부위 전략 검증 포인트)
		if hpSail.Value <= 0 then interval = math.floor(interval * 1.6) end
		task.wait(interval)
		if sunk or #Players:GetPlayers() == 0 then continue end

		RE_Volley:FireAllClients({ phase = "warn" })
		task.wait(1.0)
		local impactT = os.clock()

		-- 승조원 중 최고 등급 브레이스 적용 (협동 보상)
		local bestFactor, bestGrade = 1.0, "full"
		for _, plr in Players:GetPlayers() do
			local bt = lastBrace[plr]
			if bt then
				local delta = impactT - bt
				if delta >= 0 and delta <= CONFIG.PerfectWindow then
					if 0.2 < bestFactor then bestFactor, bestGrade = 0.2, "perfect" end
					addStat(plr, "퍼펙트", 1)
				elseif delta >= 0 and delta <= CONFIG.BraceWindow and bestFactor > 0.45 then
					bestFactor, bestGrade = 0.45, "brace"
				end
			end
		end

		local dmg = math.random(CONFIG.VolleyBase - 15, CONFIG.VolleyBase + 15)
		-- 선원 제압 시 화력 반감 (부위 전략 검증 포인트 2)
		if hpDeck.Value <= 0 then dmg = math.floor(dmg * 0.5) end
		dmg = math.floor(dmg * bestFactor)
		shipHP.Value = math.max(0, shipHP.Value - dmg)

		RE_Volley:FireAllClients({ phase = "hit", dmg = dmg, grade = bestGrade, shipHP = shipHP.Value })

		if shipHP.Value <= 0 then
			roundActive = false
			RE_Game:FireAllClients({ type = "defeat" })
			task.wait(5)
			hpSail.Value = CONFIG.EnemyHP.Sail
			hpHull.Value = CONFIG.EnemyHP.Hull
			hpDeck.Value = CONFIG.EnemyHP.Deck
			shipHP.Value = CONFIG.ShipHP
			sunk = false
			roundActive = true
			RE_Game:FireAllClients({ type = "reset" })
			task.wait(CONFIG.VolleyFirstDelay)
		end
	end
end)

print("[NavalSpike] 월드 생성 완료 — 갑판 고정, 전투 루프 가동")

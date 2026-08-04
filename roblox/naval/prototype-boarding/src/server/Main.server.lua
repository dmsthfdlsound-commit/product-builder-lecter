--------------------------------------------------------------------
-- 백병전 스파이크 v0 — 3막(근거리) 최소본
-- 상황: 도선 성공 직후. 두 함선이 갈고리로 고정(전부 앵커)되어 있고
-- 널판 2개로 연결됨. 목표: ① 적 선원 전원 처치 or ② 조타륜 10초 점거.
-- ⚠️ 스파이크 전용 — NPC는 휴머노이드 없는 CFrame 스테퍼(물리 리스크 0).
--------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CONFIG = {
	CrewCount = 5,
	CrewHP = 70,
	CrewSpeed = 9.5,        -- studs/s (플레이어 16보다 느림 — 카이팅 가능)
	CrewDamage = 12,
	CrewAttackRange = 5,
	CrewAttackCd = 1.4,
	SwordDamage = 35,
	SwordRange = 10,
	SwordArcDot = 0.35,      -- 전방 판정 (cos ~70°)
	SwordCd = 0.45,
	CaptureTime = 10,        -- 조타륜 점거 초
	CaptureRadius = 8,
	RoundRestart = 8,
}

--------------------------------------------------------------------
-- 리모트/상태
--------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local RE_Game = Instance.new("RemoteEvent"); RE_Game.Name = "GameEvent"; RE_Game.Parent = remotes
local RE_Hit = Instance.new("RemoteEvent"); RE_Hit.Name = "HitFX"; RE_Hit.Parent = remotes

local state = Instance.new("Folder")
state.Name = "BoardState"
state.Parent = ReplicatedStorage
local crewLeft = Instance.new("IntValue"); crewLeft.Name = "CrewLeft"; crewLeft.Value = CONFIG.CrewCount; crewLeft.Parent = state
local capture = Instance.new("NumberValue"); capture.Name = "Capture"; capture.Value = 0; capture.Parent = state

--------------------------------------------------------------------
-- 월드 (두 함선 나란히 고정 + 널판)
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
world.Name = "BoardWorld"
world.Parent = workspace

part({ Name = "Ocean", Size = Vector3.new(2000, 1, 2000), CFrame = CFrame.new(0, -0.5, 0),
	Color = Color3.fromRGB(45, 115, 165), Material = Enum.Material.SmoothPlastic, Transparency = 0.1 }, world)
part({ Name = "OceanDeep", Size = Vector3.new(2000, 1, 2000), CFrame = CFrame.new(0, -7, 0),
	Color = Color3.fromRGB(20, 60, 95), Material = Enum.Material.SmoothPlastic }, world)

-- 아군 함선 (좌측, X<0)
local function buildShip(cx, hullColor, deckColor, name)
	local m = Instance.new("Model"); m.Name = name; m.Parent = world
	part({ Name = "Hull", Size = Vector3.new(24, 8, 58), CFrame = CFrame.new(cx, 2, 0),
		Color = hullColor, Material = Enum.Material.WoodPlanks }, m)
	part({ Name = "Deck", Size = Vector3.new(22, 2, 54), CFrame = CFrame.new(cx, 7, 0),
		Color = deckColor, Material = Enum.Material.WoodPlanks }, m)
	for _, sideZ in { -27, 27 } do
		part({ Name = "RailEnd", Size = Vector3.new(22, 3, 1), CFrame = CFrame.new(cx, 9.5, sideZ),
			Color = hullColor, Material = Enum.Material.Wood }, m)
	end
	for _, mz in { -13, 13 } do
		part({ Name = "Mast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(28, 2, 2),
			CFrame = CFrame.new(cx, 22, mz) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood }, m)
	end
	return m
end
local myShip = buildShip(-16, Color3.fromRGB(96, 66, 42), Color3.fromRGB(150, 110, 70), "PlayerShip")
-- 바깥쪽 레일만 (안쪽은 도선을 위해 개방)
part({ Name = "Rail", Size = Vector3.new(1, 3, 54), CFrame = CFrame.new(-27.2, 9.5, 0),
	Color = Color3.fromRGB(96, 66, 42), Material = Enum.Material.Wood }, myShip)

local foe = buildShip(16, Color3.fromRGB(70, 50, 60), Color3.fromRGB(140, 100, 66), "EnemyShip")
part({ Name = "Rail", Size = Vector3.new(1, 3, 54), CFrame = CFrame.new(27.2, 9.5, 0),
	Color = Color3.fromRGB(70, 50, 60), Material = Enum.Material.Wood }, foe)

-- 널판 2개 (도선 다리) + 갈고리 로프 연출
for _, pz in { -12, 12 } do
	part({ Name = "Plank", Size = Vector3.new(12, 0.6, 3.4), CFrame = CFrame.new(0, 8.3, pz),
		Color = Color3.fromRGB(170, 130, 85), Material = Enum.Material.WoodPlanks }, world)
	part({ Name = "Rope", Size = Vector3.new(12, 0.25, 0.25), CFrame = CFrame.new(0, 10.5, pz + 2),
		Color = Color3.fromRGB(120, 100, 70), Material = Enum.Material.Fabric, CanCollide = false }, world)
end

-- 조타륜 (점거 목표, 적함 후미)
local wheel = part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5, 5),
	CFrame = CFrame.new(16, 11, 22) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(150, 105, 60), Material = Enum.Material.Wood }, world)
local wheelZoneCenter = Vector3.new(16, 9, 21)

local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(8, 1, 8)
spawnPad.CFrame = CFrame.new(-22, 8.6, 0)
spawnPad.Anchored = true; spawnPad.Neutral = true; spawnPad.Transparency = 1
spawnPad.Parent = world

--------------------------------------------------------------------
-- 커틀러스 (Tool — 모바일 버튼이 공짜로 생김)
--------------------------------------------------------------------
local StarterPack = game:GetService("StarterPack")
local tool = Instance.new("Tool")
tool.Name = "커틀러스"
tool.RequiresHandle = true
tool.CanBeDropped = false
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.4, 4.6, 0.7)
handle.Color = Color3.fromRGB(200, 205, 215)
handle.Material = Enum.Material.Metal
handle.CanCollide = false
handle.Parent = tool
tool.Grip = CFrame.new(0, -1.6, 0)
tool.Parent = StarterPack

--------------------------------------------------------------------
-- 적 선원 NPC (휴머노이드 없음 — 서버 CFrame 스테퍼)
--------------------------------------------------------------------
local crews = {} -- {model, root, hp, lastAtk, alive}
local roundActive = true

local function spawnCrew(i)
	local m = Instance.new("Model")
	m.Name = "Crew" .. i
	local root = part({ Name = "Body", Size = Vector3.new(2.4, 5, 1.6),
		CFrame = CFrame.new(10 + (i % 3) * 5, 10.6, -18 + i * 7),
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
	m:SetAttribute("Crew", true)
	m.Parent = world
	local rec = { model = m, root = root, hp = CONFIG.CrewHP, lastAtk = 0, alive = true, bar = hpBar,
		headOffset = CFrame.new(0, 3.3, 0) }
	crews[i] = rec
	return rec
end

local function resetRound()
	for _, c in crews do
		if c.model then c.model:Destroy() end
	end
	table.clear(crews)
	for i = 1, CONFIG.CrewCount do spawnCrew(i) end
	crewLeft.Value = CONFIG.CrewCount
	capture.Value = 0
	roundActive = true
	RE_Game:FireAllClients({ type = "start" })
end

local function nearestTarget(pos)
	local best, bestD = nil, math.huge
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - pos).Magnitude
			if d < bestD then best, bestD = hrp, d end
		end
	end
	return best, bestD
end

local function win(path)
	if not roundActive then return end
	roundActive = false
	for _, plr in Players:GetPlayers() do
		local v = plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("나포")
		if v then v.Value += 1 end
	end
	RE_Game:FireAllClients({ type = "win", path = path })
	task.delay(CONFIG.RoundRestart, resetRound)
end

local function damageCrew(rec, dmg, hitPos)
	if not rec.alive then return end
	rec.hp -= dmg
	rec.bar.Size = UDim2.fromScale(math.max(0, rec.hp / CONFIG.CrewHP), 0.4)
	RE_Hit:FireAllClients({ pos = hitPos, dmg = dmg })
	if rec.hp <= 0 then
		rec.alive = false
		crewLeft.Value -= 1
		local m = rec.model
		task.spawn(function()
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
			for i = 1, 12 do
				m:PivotTo(m:GetPivot() * CFrame.new(0, -0.25, 0) * CFrame.Angles(0.09, 0, 0.06))
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then p.Transparency = i / 12 end
				end
				task.wait(0.05)
			end
			m:Destroy()
		end)
		if crewLeft.Value <= 0 then win("clear") end
	end
end

-- NPC AI: 15Hz 스테퍼
task.spawn(function()
	while true do
		task.wait(1 / 15)
		if not roundActive then continue end
		local now = os.clock()
		for _, rec in crews do
			if rec.alive and rec.root.Parent then
				local target, dist = nearestTarget(rec.root.Position)
				if target then
					if dist > CONFIG.CrewAttackRange then
						local dir = (target.Position - rec.root.Position) * Vector3.new(1, 0, 1)
						if dir.Magnitude > 0.1 then
							local step = dir.Unit * CONFIG.CrewSpeed / 15
							local newPos = rec.root.Position + step
							-- 갑판 위로 클램프 (스파이크: 지오메트리 신뢰)
							local look = CFrame.lookAt(newPos, newPos + dir.Unit)
							rec.model:PivotTo(look)
						end
					elseif now - rec.lastAtk > CONFIG.CrewAttackCd then
						rec.lastAtk = now
						local char = target.Parent
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum:TakeDamage(CONFIG.CrewDamage)
							RE_Hit:FireAllClients({ pos = target.Position, dmg = -CONFIG.CrewDamage, hurt = true })
						end
					end
				end
			end
		end
	end
end)

-- 조타륜 점거: 10Hz
task.spawn(function()
	while true do
		task.wait(0.1)
		if not roundActive then continue end
		local someone = false
		for _, plr in Players:GetPlayers() do
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - wheelZoneCenter).Magnitude <= CONFIG.CaptureRadius then
				someone = true
				break
			end
		end
		if someone then
			capture.Value = math.min(CONFIG.CaptureTime, capture.Value + 0.1)
			if capture.Value >= CONFIG.CaptureTime then win("capture") end
		else
			capture.Value = math.max(0, capture.Value - 0.2) -- 이탈 시 서서히 감소
		end
	end
end)

--------------------------------------------------------------------
-- 검격 판정 (Tool.Activated는 클라 → 리모트)
--------------------------------------------------------------------
local RE_Swing = Instance.new("RemoteEvent"); RE_Swing.Name = "Swing"; RE_Swing.Parent = remotes
local lastSwing = {}

RE_Swing.OnServerEvent:Connect(function(player)
	if not roundActive then return end
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < CONFIG.SwordCd then return end
	lastSwing[player] = now
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local fwd = hrp.CFrame.LookVector
	for _, rec in crews do
		if rec.alive then
			local off = rec.root.Position - hrp.Position
			local dist = off.Magnitude
			if dist <= CONFIG.SwordRange and off.Unit:Dot(fwd) >= CONFIG.SwordArcDot then
				damageCrew(rec, CONFIG.SwordDamage, rec.root.Position)
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local v = Instance.new("IntValue"); v.Name = "나포"; v.Value = 0; v.Parent = stats
	stats.Parent = player
end)
Players.PlayerRemoving:Connect(function(player) lastSwing[player] = nil end)

resetRound()
print("[BoardingSpike] 도선 완료 — 백병전 개시")

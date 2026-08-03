# 로블록스 엔진 실현 가능성 (해상전)

> Roblox engine feasibility for a multiplayer naval combat game (ships on an ocean, cannon fire, boarding) — water, buoyancy, replication, streaming, deck movement, map scale, projectiles

## Terrain water's waves are purely cosmetic — they have zero physics, and there is no wave-height API.
Terrain.WaterWaveSize (0-1) and WaterWaveSpeed (0-100) are render-only properties. DevForum consensus is blunt: "smooth terrain water waves don't have any physics whatsoever." Buoyancy is evaluated against the flat top surface of 4x4x4-stud water voxels. Terrain:GetWaveHeight() has been an open feature request since ~2018 and still does not exist.

**→ 시사점**: Any 'ride the swell / dodge the rogue wave / rough-seas damage' mechanic must be driven by a wave function WE own. Once you own the function, Terrain water's only remaining advantage (built-in buoyancy) is the thing you're replacing anyway — so a custom mesh ocean becomes the correct default, not the fancy option.

출처: https://devforum.roblox.com/t/terrain-water-wave-physics/751422 ; https://devforum.roblox.com/t/terraingetwaveheightvector3/182047 ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/parts/terrain.md

## Terrain water is a volumetric voxel structure — cost scales with volume, not surface area — and big oceans blow up memory.
Terrain voxels are 4x4x4 studs. A widely-cited case of ~11 billion water voxels reported 20-40 GB RAM in Studio and the live client refusing to load the place. Even a modest 16k x 16k ocean only 100 studs deep is ~419 million voxels. Multiple threads report terrain water alone tanking FPS and load times on large maps.

**→ 시사점**: If we use Terrain water at all, it must be a thin shell (a few voxels deep) over a bounded playable area — never a filled box. This is a strong practical argument for a flat mesh ocean, which has literally zero voxel cost.

출처: https://devforum.roblox.com/t/massive-ocean-conflict-with-performance/705625 ; https://devforum.roblox.com/t/terrain-water-is-way-too-demanding-in-my-place-is-there-anything-that-i-can-do-about-the-performance/1190054

## Terrain water + StreamingEnabled is a documented bug farm — and Server Authority forces StreamingEnabled on.
Reported issues: terrain chunks silently failing to stream in, terrain water rendering at the wrong height after a stream-out/stream-in cycle, water disappearing and reappearing, terrain LOD not upgrading until you walk on it, and 4096x4096 maps showing missing terrain. Separately, Workspace.AuthorityMode = Server force-enables StreamingEnabled.

**→ 시사점**: Terrain water and a server-authoritative build are on a collision course. A client-side mesh ocean is never streamed (it's created locally, re-centred under the camera) and sidesteps this entire bug class.

출처: https://devforum.roblox.com/t/terrain-water-renders-wrong-with-streamingenabled/3068489 ; https://devforum.roblox.com/t/large-chunks-of-terrain-not-visible-for-a-second-with-streaming-enabled/457351 ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/projects/server-authority/index.md

## The community-standard high-performance ocean is a client-side skinned-mesh / EditableMesh Gerstner or FFT plane with an analytic height lookup — and it is astonishingly cheap.
The best-known resource reports ~0.05 ms/frame for 9 planes of ~530 bones each, clients synchronised via workspace:GetServerTimeNow(), plus a fast GetHeight(x, z) function explicitly provided for floatable objects. Newer 2025-2026 implementations use EditableMesh with FFT/Philips-spectrum waves, frustum culling, multithreading and vertex-lerp LOD so distant vertices don't update every frame. The plane re-centres under the player for an 'infinite' ocean.

**→ 시사점**: This is the path. Because water height is a pure function of (x, z, t) against a shared clock, server and every client independently compute identical water height with ZERO replication. Ship buoyancy becomes deterministic across the whole session — which is exactly what a server-authoritative naval game needs.

출처: https://devforum.roblox.com/t/performant-skinned-mesh-ocean-with-built-in-support-for-floatable-objects-boats-ships-and-more/1820025 ; https://devforum.roblox.com/t/simulated-ocean-with-editablemesh/3562339 ; https://devforum.roblox.com/t/realistic-fft-ocean/2950964

## Terrain water forces Humanoid Swimming state, which makes below-waterline walkable interiors impossible.
Humanoid swim state is driven by occupying water voxels, and you cannot subtract terrain water from the inside of a moving hull. DevForum threads on 'how to clear water inside boat' and masking a submarine's waterline all conclude you must abandon terrain water. The inverse confirms the mechanism: community modules deliberately fake voxel water to make characters swim inside ordinary parts.

**→ 시사점**: Naval combat wants gun decks, holds and boarding below the rail. That requirement alone disqualifies Terrain water. With a mesh ocean, 'is submerged' is our own predicate, so hull interiors stay dry and walkable for free.

출처: https://devforum.roblox.com/t/how-to-clear-water-inside-boat/780065 ; https://devforum.roblox.com/t/how-do-i-mask-the-water-line-inside-of-my-submarine/1988911 ; https://devforum.roblox.com/t/smooth-terrain-swimming-but-inside-of-partsv30/1766401

## Engine buoyancy is a per-contact force system and it actively fights large multi-part vessels.
Water density is 1 RMU/stud^3 (= 1 g/cm^3); parts denser than 1 sink. Buoyancy plus viscous drag are injected through the normal contact pipeline, per part in contact. Reported consequences: unanchored cruise ships changing pitch and yaw drastically when a player jumps; floating parts spontaneously spinning; and a regression where parts removed from the Default CollisionGroup stopped floating entirely.

**→ 시사점**: Do not let the engine keep the ship upright. Model buoyancy ourselves as ~4-8 deliberate sample-point forces on ONE rigid assembly, so the vessel's attitude comes from forces we chose rather than hundreds of accidental contacts we didn't.

출처: https://devforum.roblox.com/t/buoyancy-affected-by-players-any-way-to-stop-this/1235120 ; https://devforum.roblox.com/t/terrain-water-breakage-collisiongroups-buoyancy/339291 ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/physics/units.md

## The stable ship architecture is exactly one welded assembly with only the root part anchored (or nothing anchored) — and part count is then nearly free for physics.
Official docs: an assembly is one rigid body; AssemblyMass becomes infinite if any part is anchored; root-part selection is automatic (anchored > non-massless > RootPriority > size, with Seat/VehicleSeat/HumanoidRootPart multipliers) and cannot be set directly, only biased via RootPriority. Crucially: "Anchoring all parts is actually less performant, as it creates more assemblies." Build A Boat For Treasure's own wiki confirms the payoff: a properly welded 10,000+ block ship moves about as fast as a 10-block ship.

**→ 시사점**: One assembly, one deliberately high-RootPriority hull root part. Detail on the ship costs render/memory/streaming budget but almost nothing in the physics step — so optimise the ship for draw calls and instance count, not for physics.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/physics/assemblies.md ; https://build-a-boat-for-treasure.fandom.com/wiki/Boats

## Constraint choice matters more than tuning: LinearVelocity + AngularVelocity is current, BodyVelocity/BodyGyro are deprecated, and AlignPosition on a hull is a jitter generator.
LinearVelocity/AngularVelocity officially replace deprecated BodyVelocity/BodyAngularVelocity. Devs consistently warn that an unconstrained 3-axis LinearVelocity makes the vessel ignore gravity (it holds Y velocity). AlignPosition-driven boats generate a steady stream of jitter/stutter/flipping threads, plus reported AlignPosition/AlignOrientation replication failures. High Responsiveness or RigidityEnabled makes them effectively kinematic and then they fight buoyancy.

**→ 시사점**: Working recipe: per-point buoyancy VectorForces for heave/roll/pitch, LinearVelocity constrained to a line or the XZ plane for surge, AngularVelocity (or a soft AlignOrientation) for yaw. Never AlignPosition on the hull, and never the deprecated Body* movers for new work.

출처: https://devforum.roblox.com/t/moving-boat-with-alignposition/3642168 ; https://devforum.roblox.com/t/why-does-a-basic-align-position-stutter/3035828 ; https://devforum.roblox.com/t/what-are-the-alternatives-for-bodyvelocity-and-bodyangularvelocity/1688963

## Fully kinematic CFrame-driven ships look the most stable and are the worst to stand on.
Anchored parts report no AssemblyLinearVelocity, so characters get no velocity inheritance at all; Touched never fires from CFrame assignment; the server always owns anchored parts and cannot delegate them to a client; and setting hundreds of part CFrames per frame produces large CPU spikes (setting a physics model's CFrame in RenderStepped is a known bug source).

**→ 시사점**: Kinematic buys 'never jitters, never flips, never falls apart' at the price of writing 100% of the deck-movement and hit-detection layer yourself. Only choose it if we commit to a custom character controller from day one — it is not a shortcut.

출처: https://devforum.roblox.com/t/how-do-i-get-the-velocity-of-an-anchored-part/1364450 ; https://devforum.roblox.com/t/poor-performance-updating-hundreds-of-part-positions/2191572 ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/physics/network-ownership.md

## Network ownership is a zero-sum trade: whoever owns the hull gets a crisp helm, and everyone else sees interpolation.
Server owns every BasePart by default and ALWAYS owns anchored parts. In an unanchored mechanism, setting ownership on one assembly applies to every assembly in it. Official vehicle guidance is to assign ownership to the seat occupant and to give loose parts on top of the vehicle to the same client. The docs also state that keeping server ownership "may result in jittery physics interactions" and that the driver waits several network cycles before input registers.

**→ 시사점**: Split authority per subsystem rather than picking one side: ship kinematics can be client-predicted for feel, while damage, sinking, loot and scoring stay server-authoritative. Do not try to make a single ownership setting satisfy both feel and fairness.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/physics/network-ownership.md ; https://devforum.roblox.com/t/reducing-vehicle-lag-with-setnetworkownerplayer-but-worried-about-exploits/1388561

## A client-owned ship is a large, officially documented exploit surface.
Roblox's own security doc states a client with ownership can teleport parts anywhere, set velocities to extreme values including Inf and NaN, fling other players' characters, clip through walls, fire fake Touched events, and opportunistically acquire ownership of additional nearby unanchored parts. The historic SimulationRadius/MaxSimulationRadius exploits vacuumed every unanchored part on a map to the exploiter; Roblox capped SimulationRadius (~1000 studs) and removed the ability to set it, but the underlying 'client simulates physics' hole remains.

**→ 시사점**: Nothing gameplay-critical may be an unanchored, client-ownable part near a player: no floating loot crates, no physical cannonballs, no unanchored boarding planks, no unanchored powder barrels. Server-side validation of position deltas and hit claims is mandatory, not optional.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/scripting/security/network-ownership.md ; https://devforum.roblox.com/t/anti-exploit-for-maxsimulationradiussimulationradius-exploit-tping-unanchored-parts-to-player/1009199

## Roughly 10+ simultaneous multi-assembly vehicles is where physics replication visibly falls over.
An engine bug report states that experiences with 10 or more vehicles composed of multiple assemblies begin to rubber-band or teleport because replication data is overloaded and split up. The 2026 ImprovedPhysicsReplication rollout (opt-in Workspace.ImprovedPhysicsReplication, broad rollout from ~15 June 2026, 'eventual consistency' so updates survive packet drops) has its own fresh bug reports — including a server-owned assembly driven by LinearVelocity + AlignOrientation + PlaneConstraint snapping about once per second on low-population servers, Motor6D replication fighting the client, momentary teleports, and RopeConstraint inconsistency.

**→ 시사점**: Budget for roughly 6-12 simultaneously simulated ships per server, not 30. Design the match as few big crewed ships (e.g. 2 teams x 2-4 ships, 4-8 crew each) rather than one ship per player. Note the failing constraint stack in that bug report is almost exactly the stack a boat wants — test it early.

출처: https://devforum.roblox.com/t/severe-vehicle-rubber-banding-experienced-during-high-player-count-sessions/3381709 ; https://devforum.roblox.com/t/improvedphysicsreplication-server-owned-assembly-jittersteleports-low-server-player-count-only/4695826 ; https://devforum.roblox.com/t/upcoming-improvements-to-physics-replication/4675512

## Server Authority went to full release in July 2026 and is the real answer to 'who simulates the boat' — but it dictates your entire architecture.
Setting Workspace.AuthorityMode = Server force-enables NextGenerationReplication, PlayerScriptsUseInputActionSystem, SignalBehavior = Deferred, UseFixedSimulation and StreamingEnabled. Simulation logic must live in RunService:BindToSimulation() modules initialised on both client and server, may only touch properties tagged 'Simulation Access' (BasePart.CFrame qualifies), may NOT yield (no task.wait, no task.spawn), and custom state rides on attributes limited to the first 64 per instance with <=50-char names and <=50-char string values. Clients predict a few frames ahead and roll back + resimulate on misprediction; mispredictions caused by other players' inputs are described as normal and unavoidable.

**→ 시사점**: For a PvP naval game this is a genuine competitive edge — cheat-resistant ship movement with prediction, no custom anti-cheat. But it must be a week-1 decision, not a month-6 migration: input handling, state storage and yielding patterns are all constrained. Open 2026 bug reports include prediction working badly with ControllerManager-based physics character controllers and high receive bandwidth — so prototype the ship + deck controller under Server Authority immediately.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/projects/server-authority/index.md ; https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993 ; https://devforum.roblox.com/t/server-authority-prediction-does-not-work-well-with-physics-based-character-controllers-controllermanagers/4178473

## StreamingEnabled genuinely breaks moving vehicles unless you explicitly take control of it.
Defaults: StreamingMinRadius 64 studs, StreamingTargetRadius 1024 studs (512-1024 recommended). Streamed-out instances are parented to nil rather than destroyed, and reading Position on them "continue[s] to succeed but return[s] the last replicated value which can be arbitrarily stale." Official warning: "Avoid creating moving assemblies with unnecessarily large numbers of instances, as all of the instances streaming in unison may cause network/CPU spikes." Client physics only runs in streamed-in regions. Reported vehicle bugs: welded parts not removed on stream-out, frozen physics-less ghost vehicles, and SeatWeld failing to stream to a client.

**→ 시사점**: Every ship must be ModelStreamingMode = Atomic at minimum so it streams all-or-nothing, and per-ship instance count must stay low precisely because the whole ship arrives in one burst. Any server logic that reads a ship's Position must run server-side, where all instances are always visible.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/workspace/streaming/index.md ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/workspace/streaming/techniques.md ; https://devforum.roblox.com/t/vehicles-not-getting-streamed-inout-correctly/447201 ; https://devforum.roblox.com/t/with-streamingenabled-sometimes-a-seatweld-is-not-streamed-in-to-a-client/2882256

## Player.ReplicationFocus is the intended lever for vehicle streaming, and extra foci are expensive.
Streaming normally centres on the character's PrimaryPart, but Player.ReplicationFocus retargets it, and Player:AddReplicationFocus()/RemoveReplicationFocus() add more. Official warning: a single player with nine dynamically moving foci can generate server networking and streaming work comparable to ten players moving around the game.

**→ 시사점**: Set each crew member's ReplicationFocus to their ship's root so the streamed bubble sails with the vessel. Do NOT hand every player extra foci on enemy ships — instead keep enemy ships cheap enough to fit inside the 1024-stud target radius, and represent anything beyond that with a client-side proxy (silhouette mesh + wake) fed by cheap position updates.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/workspace/streaming/index.md ; https://devforum.roblox.com/t/new-instance-streaming-feature-multiple-replication-foci/3848736

## Part budget: ships are cheap for physics but expensive for render, streaming and memory.
Practical guidance converging across docs and community: under ~5,000 workspace instances during active play is comfortable on mid-range mobile; 15,000-20,000 instances is 'almost always struggling'; ~40k parts / 80k instances performs badly on low-end. Roblox's own perf docs give a low-end mobile baseline of under 1,000 draw calls and under 1,000,000 triangles, a 16.67 ms total frame budget at 60 FPS, and a server memory target below 50% of (6.25 GiB + 100 MiB x max players). For physics specifically, ~500-1,500+ INDEPENDENT unanchored parts is where the step time starts hurting — but a welded ship is one body no matter how many parts it contains.

**→ 시사점**: Target ~150-400 instances per ship, built from a handful of MeshParts (hull, deck, masts, rails, rigging as single meshes) rather than 2,000 bricks. Eight ships at 300 instances = 2,400, leaving real headroom for islands, players and VFX under the 5,000-instance mobile ceiling. Reuse identical meshes across the fleet so draw calls barely move.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/performance-optimization/design.md ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/performance-optimization/identify.md ; https://devforum.roblox.com/t/whats-a-good-maximum-part-count-for-low-end-devices/1930430 ; https://devforum.roblox.com/t/question-about-performance-with-unanchored-parts/1667830

## Collision fidelity is where a beautiful hull silently kills performance.
CollisionFidelity ranges Box < Hull < Default < PreciseConvexDecomposition. Precise is the most expensive to compute and stores substantially more collision geometry and memory; Hull cannot represent a concave interior at all, so a 'hull' fidelity ship hull is a solid lump.

**→ 시사점**: Make the visual hull one mesh with CanCollide off and Box/Hull fidelity, then hand-author collision from a few invisible box parts: deck plane, bulwark walls, stair ramps, hatch blockers. This is faster AND gives the character controller a flat, predictable deck instead of a noisy decomposed mesh.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/workspace/collisions.md ; https://devforum.roblox.com/t/meshpart-usage-performance-optimizations/1319217

## Walking on a moving ship is the hardest problem in the project, the engine does not solve it, and welding is a trap.
Confirmed engine bugs: characters do not inherit velocity from moving platforms they stand on, and a character's AssemblyLinearVelocity excludes the platform's velocity — worst when the platform is server-owned while the character is client-owned. Physics 'almost' works while grounded and fails on jumps, stairs and ladders, where players drift backwards. The welding workaround is documented as broken in multiple ways: a welded character that walks drags the entire boat; welding something to a character sinks the boat they're seated in and the ship flies up when they leave; WeldConstraint restricts jumping and can trap the character inside the platform; re-welding after respawn can kill the player. Two overlapping humanoids gradually slide off a moving platform.

**→ 시사점**: Budget real engineering for a custom deck controller. Practical stack: (a) same-owner rule — ship and its crew's characters share one network owner; (b) set every character part Massless = true so crew never alters buoyancy or handling (BABFT confirms boats slow down as more players board); (c) add the ship's velocity to the character each frame while grounded on it, and preserve it through the jump arc; (d) put that logic in the Character Controller Library (full release 30 April 2026: ControllerManager + AvatarAbilities, with GroundController/AirController/SwimController/ClimbController exposing acceleration, deceleration, friction and jump momentum conservation) rather than fighting the Humanoid black box — but note the CCL docs say nothing about moving ground, so it is still our code.

출처: https://devforum.roblox.com/t/characters-do-not-inherit-velocity-from-moving-platforms-they-are-standing-on/1484232 ; https://devforum.roblox.com/t/assemblylinearvelocity-property-of-humanoid-assembly-does-not-inherit-velocity-of-humanoid-platform/1839144 ; https://devforum.roblox.com/t/welding-a-character-to-a-boat/261444 ; https://devforum.roblox.com/t/welding-something-to-the-players-character-sinks-the-boat-theyre-seated-in/4243205 ; https://devforum.roblox.com/t/full-release-the-future-of-character-movement-character-controller-library/4565267

## The cheapest robust solution to deck movement is a local reference frame / instanced interior, and that's effectively what shipping games do.
DevForum consensus for ships is either CFrame-syncing the character to the platform in a LocalScript every frame, or moving the world instead of the ship. Ship interiors in practice are commonly separate static rooms the player is transitioned into rather than genuinely moving spaces.

**→ 시사점**: Big design lever: make below-deck fighting a STATIC instanced interior (the hold rendered at a fixed world location) while the exterior hull actually sails. Boarding becomes a scripted transition. That removes moving-platform physics from most on-foot combat and is dramatically cheaper than making melee work on a pitching deck.

출처: https://devforum.roblox.com/t/moving-ship-player-movement/1374675 ; https://devforum.roblox.com/t/sync-player-movement-with-a-moving-ship/3535557 ; https://devforum.roblox.com/t/help-with-script-to-avoid-floating-point-precision-error/3073335

## Map scale: the engine lets you go far bigger than you should, and precision degrades with distance from origin.
Vector3 is single-precision float; devs report visual jitter and 'vibration' that intensifies with distance from (0,0,0). The theoretical point where fractional precision dies is 8,388,608 studs, but visible artifacts start far earlier — in the tens of thousands. Heightmap terrain generation was capped at 16384^3 studs; 32,768 x 32,768 is discussed as a soft edge for part-based maps. Raycasts max out at 15,000 studs (with one bug report of mesh raycasts failing around ~2,100 studs). Default FallenPartsDestroyHeight (~-500) deletes anything that sinks past it. For reference, 1 stud = 28 cm and gravity is 196.2 studs/s^2.

**→ 시사점**: Keep the whole ocean inside roughly +/-8,000 studs of origin (an 8k x 8k playfield), 16k x 16k absolute maximum. That is plenty: at Fisch's fastest boat (320 studs/s) an 8,000-stud crossing is 25 s; at a period-appropriate 60-120 studs/s it's 65-130 s. Design for TRAVEL TIME, not absolute distance — 8,000 studs is only ~2.2 km of 'real' sea, and with a 1024-stud streaming radius players only ever see about a kilometre of it anyway. If we ever truly need more world, use a floating-origin/world-shift scheme, not bigger absolute coordinates.

출처: https://devforum.roblox.com/t/loss-of-precision-causes-game-breaking-issues-at-distances-far-from-origin/202782 ; https://devforum.roblox.com/t/maximum-game-size-terrain-map-size/327266 ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/physics/units.md ; https://www.sportskeeda.com/roblox-news/all-boats-fisch

## Cannonballs must be stepped raycasts, not physical parts — the engine gives you no choice.
Touched is unreliable once a part's AssemblyLinearVelocity exceeds ~100 studs/s (GetTouchingParts is worse), and Touched never fires when position is set via CFrame. Physical projectiles are unanchored parts a client can hijack, and devs report ~1-second-scale replication delays plus client/server divergence that grows when the shooter is moving. FastCast is the standard answer: stepped raycasts that simulate ballistics with a purely cosmetic visual part, paired with PartCache/ObjectCache for the visuals. With gravity at 196.2 studs/s^2, 45-degree range is approximately v^2/g: 300 studs/s gives ~460 studs, 500 studs/s gives ~1,270 studs.

**→ 시사점**: Raycast ballistics also cleanly solves 'cannonball inherits the firing ship's velocity' — we add that vector explicitly and deterministically instead of hoping physics does it. Pick muzzle velocity ~250-400 studs/s so effective range lands in the ~320-800 stud band, comfortably inside the 1024-stud streaming radius, meaning combat never crosses a streaming boundary.

출처: https://devforum.roblox.com/t/hit-detection-for-fast-moving-objects/1943799 ; https://devforum.roblox.com/t/making-a-combat-game-with-ranged-weapons-fastcast-may-be-the-module-for-you/133474 ; https://devforum.roblox.com/t/latency-when-replicating-moving-parts-projectiles-from-client-to-server/3135292 ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/physics/units.md

## Hit registration is 'which ship position do we trust' — and ships being huge and slow makes lag compensation unusually easy.
Server-side raycasts miss because of latency (players hit on their screen but not on the server); client-side raycasts are trivially spoofed. The accepted pattern is: client fires and simulates locally, sends origin + direction + timestamp, and the server re-raycasts from the reported origin while validating distance, line-of-sight and fire rate. SecureCast-style community resources do fully server-authoritative projectiles with lag-compensated (rewound) hitboxes.

**→ 시사점**: Exploit the geometry: a 200 ms rewind error on a 100 stud/s ship is ~20 studs against a 150-stud-long target — a hit is still a hit. Keep a rolling CFrame history buffer per ship and validate cannon hits server-side with generous tolerance. Reserve strict, tight validation for small targets (players, crow's nests), where the error actually matters.

출처: https://devforum.roblox.com/t/archived-securecast-server-authoritative-projectiles-with-lag-compensation-multi-threading-and-more/2546164 ; https://devforum.roblox.com/t/secure-yet-accurate-gun-raycasting/168495 ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/tutorials/use-case-tutorials/scripting/intermediate-scripting/hit-detection-with-lasers.md

## Mass and density are a genuinely cheap gameplay dial — flooding and listing come almost free.
Water is 1 RMU/stud^3; custom material density is clamped to [0.0001, 100] RMU/stud^3; 1 RMU = 21.952 kg; gravity is 196.2 studs/s^2. The community-standard custom buoyancy is an upward force of roughly mass * gravity distributed across N sample points, each scaled by local submerged depth, plus linear and angular damping. AssemblyCenterOfMass and AssemblyMass are read directly off the assembly.

**→ 시사점**: Tonnage, cargo weight, crew and flooding collapse into one number (assembly mass) plus per-point submersion. Damage a section, reduce its buoyant force, and the ship lists and settles authentically with no new system. Very high perceived production value per line of code.

출처: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/physics/units.md ; https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/physics/assemblies.md ; https://devforum.roblox.com/t/buoyancy-formula/1942158

## Boarding is the riskiest mechanic because it puts two independently-simulated rigid bodies in contact.
Roblox does not handle collisions well between differently network-owned items — a client-owned boat colliding with non-client-owned objects is explicitly called out as one of the biggest problems. Rubber-banding worsens with vehicle count. And a character jumping between two moving assemblies inherits velocity from neither.

**→ 시사점**: Do not implement boarding as free-form physics hull-to-hull collision. Make it a STATE: when two ships are in range and grappled, snap them into a fixed relative CFrame with one designated physics leader and the other following (welded/aligned) so they behave as a single assembly for the duration. That single decision kills the cross-owner collision problem, the hull-crushing bug class, and the 'the deck I'm jumping to moves differently' problem at once.

출처: https://devforum.roblox.com/t/massive-physics-network-ownership-replication-lagdesync/4620373 ; https://devforum.roblox.com/t/severe-vehicle-rubber-banding-experienced-during-high-player-count-sessions/3381709 ; community consensus across search results

## ⛔ 하드 제약
- Do NOT design wave-riding, swell-surfing or wave-dodging gameplay on Terrain water. Terrain wave properties are render-only, there is no physics displacement and no GetWaveHeight API.
- Do NOT design walkable below-waterline interiors (gun deck, hold, brig) while using Terrain water. Players enter Humanoid Swimming state inside the hull and you cannot subtract terrain water from a moving vessel.
- Do NOT fill a large ocean volume with Terrain water. Cost is volumetric at 4x4x4 studs per voxel; extreme cases have hit 20-40 GB and had the client refuse to load the place.
- Do NOT rely on engine buoyancy to keep a ship upright. It is applied per contact, so players jumping visibly swing pitch and yaw, and collision-group changes have historically disabled floating outright.
- Do NOT build the ship as many loose or separately-unanchored parts. ~500-1,500+ independent unanchored parts starts hurting the physics step, and loose blocks / blocks-inside-blocks are documented to degrade boat behaviour.
- Do NOT anchor every part of the ship. Official docs: anchoring all parts creates more assemblies and is LESS performant. Anchor the root only, or nothing.
- Do NOT drive the hull with AlignPosition. Widely reported jitter, stutter, flipping and replication failures. Also do not use deprecated BodyVelocity / BodyAngularVelocity / BodyGyro for new work.
- Do NOT apply unconstrained 3-axis LinearVelocity to the hull — it nullifies gravity and fights buoyancy. Constrain it to a line or the XZ plane and let buoyancy own the vertical axis.
- Do NOT weld player characters to the deck to keep them aboard. Documented failures: a walking welded character drags the whole boat, welding adds mass and sinks the boat, the ship flies up on unweld, jumping breaks, and re-welding after respawn can kill the player.
- Do NOT assume characters inherit ship velocity. It is a confirmed engine bug, worst when ship and character have different network owners; jumps, stairs and ladders all drift the player aft.
- Do NOT make anything gameplay-critical an unanchored, client-ownable part near a player. A client owner can teleport it, set Inf/NaN velocity, fling other players and fake Touched events.
- Do NOT use physical parts as cannonballs. Touched is unreliable above ~100 studs/s AssemblyLinearVelocity, never fires on CFrame moves, and physical projectiles replicate late and desync from the shooter.
- Do NOT design for 20-30 simultaneous player-driven ships. 10+ multi-assembly vehicles is a documented rubber-banding threshold, and 2026's ImprovedPhysicsReplication has fresh bug reports against exactly the LinearVelocity + AlignOrientation constraint stack a boat uses.
- Do NOT design ship-to-ship ramming, crushing or grinding as emergent physics between two client-owned hulls. Cross-network-owner collisions are explicitly called out as poorly handled.
- Do NOT place the playfield far from the world origin or exceed ~16,000 studs of extent. Single-precision Vector3 jitter grows with distance, heightmap terrain caps at 16384, and raycasts cap at 15,000 studs.
- Do NOT assume StreamingEnabled 'just works' with moving ships. Welds and SeatWelds failing to stream, frozen physics-less ghost vehicles, streamed-out instances parented to nil, and arbitrarily stale Position reads are all documented.
- Do NOT adopt Server Authority casually or mid-project. It force-enables StreamingEnabled, UseFixedSimulation, Deferred signals and the Input Action System; forbids yielding inside BindToSimulation; and caps custom state at the first 64 attributes with <=50-char names and string values.
- Do NOT build a 2,000-part 'detailed' ship. ~5,000 workspace instances is the comfortable mobile ceiling for the WHOLE scene, 15-20k is failing, and the low-end baseline is under 1,000 draw calls and 1M triangles.
- Do NOT set the hull mesh to PreciseConvexDecomposition collision fidelity. It is the most expensive to compute and stores far more collision geometry.
- Do NOT let sinking ships or wreckage fall past FallenPartsDestroyHeight (default ~-500) unless you intend them to be deleted.
- Do NOT hand players multiple replication foci to 'see' distant ships. Nine dynamic foci on one player costs the server roughly what ten players cost.

## 💡 기회
- An analytic shared wave field (Gerstner or FFT) plus workspace:GetServerTimeNow() gives server and every client identical water height with literally zero bytes replicated — deterministic buoyancy for free. Reference implementations run ~0.05 ms/frame for 9 planes x ~530 bones.
- Welded assemblies make part count nearly free for physics: a properly welded 10,000-part ship moves like a 10-part one. Spend the budget on silhouette and readability, not on physics simplification.
- Draw calls are roughly per unique mesh, so a fleet of identical frigates is almost free to render. Standardise on 3-4 hull classes and reuse aggressively.
- A custom mesh ocean makes 'submerged' our own predicate — dry, walkable gun decks and holds below the rail, with zero engine fighting. This is a visible feature no terrain-water competitor can ship.
- Massless = true on character parts makes crew weightless to ship handling, so crew size becomes a pure design dial with no buoyancy or handling regression (Build A Boat For Treasure confirms boats slow as players board — we can simply not have that problem).
- AssemblyMass + per-point submersion turns cargo weight, crew load, flooding and listing into one physically-honest system. Damage a compartment, drop its buoyant force, and the ship visibly settles and lists — enormous perceived depth for very little code.
- Ships are huge, slow, high-inertia targets, which makes server-authoritative lag compensation genuinely accurate here: a 200 ms rewind on a 100 stud/s ship is ~20 studs of error against a 150-stud target. Rewound-CFrame hit validation with generous tolerance is honest AND cheat-proof — lag compensation on easy mode.
- FastCast-style stepped raycasts plus PartCache give hundreds of convincing cannonballs at near-zero physics cost, with explicit deterministic control over inherited ship velocity, drop and drag.
- Gravity of 196.2 studs/s^2 produces short, readable artillery arcs (range ~= v^2/g). A 250-400 studs/s muzzle velocity puts effective range in the 320-800 stud band — entirely inside a single 1024-stud streaming radius, so a fight never crosses a streaming boundary.
- Player.ReplicationFocus set to the ship's root makes the streamed bubble sail with the vessel; combined with ModelStreamingMode = Atomic ships, streaming flips from hazard to free LOD and memory savings.
- Server Authority (full release July 2026) gives prediction + rollback ship movement that is simultaneously responsive and cheat-proof. Every existing naval game on the platform runs client-owned, exploitable boats — this is a real differentiator, if we commit at week 1.
- The Character Controller Library (full release 30 April 2026) exposes GroundController/AirController with explicit acceleration, deceleration, friction and jump momentum conservation in Luau — the sanctioned hook point for injecting deck-relative velocity instead of fighting the Humanoid black box.
- Static instanced below-deck interiors sidestep moving-platform physics for the majority of on-foot combat and double as a natural, dramatic boarding set piece — cheaper AND better staged than fighting on a pitching deck.
- Grapple-and-lock boarding (snap two hulls into a fixed relative CFrame, one leader + one follower) converts the hardest multiplayer physics problem in the design into a state machine with no engine risk.
- Terrain water is still perfectly good for harbours and island shallows where the sea is static scenery and no ship interior is involved — a hybrid (terrain water in port, mesh ocean at sea) is viable if the seam is hidden by geometry or fog.
- Raycasts reach 15,000 studs, so spyglass spotting, long-range line-of-sight, horizon detection and sail-visibility checks across the entire map are essentially free.
- Because water height is a pure function, wind, current and 'rough seas' zones can be authored as cheap analytic fields that every client agrees on — regional weather with no replication cost.
- A 1024-stud streaming radius plus an 8k x 8k playfield means only a small slice of the world is ever resident. That makes an ambitious-feeling ocean cheap on mobile, provided ships stay in the 150-400 instance range.

# 전직·동료 시스템 사례 연구

> Class advancement (전직), companion/crew, and collection systems in successful Roblox RPGs and adjacent games — design patterns, player complaints, and monetization limits, mapped to a naval "hero job-change + ship crew" game

## Successful advancement ladders put the FIRST job change absurdly early and the flashy one at mid-game — the pattern is 'tier 1 in the first session, tier 2 at the content wall'.
Arcane Lineage: base class at level 5, Super Class at level 15 (of a ~40-level ladder). MapleStory (the canonical 전직 reference): 1st at Lv10, 2nd at Lv30, 3rd at Lv60, 4th at Lv100. Arcane Odyssey: first Awakening at Lv120 + defeating King Calvus; second Awakening is gated around Lv220-250 and is still described as unobtainable/unreleased (sources conflict on the exact number — treat as uncertain). Blox Fruits Race V4 minimum is ~Lv1509; King Legacy race V2 needs Lv3000 + Second Sea, V3 needs Third Sea + 10 Void Cores.

**→ 시사점**: Give the naval hero their first 전직 inside 30-60 minutes (choose your station: Gunner/Carpenter/Navigator...), tier 2 at the first real content gate (first big naval boss / first crossing), tier 3 as a late prestige. Do NOT copy Blox Fruits/King Legacy's four-digit level gates — that only works when the game already has 200-hour players.

출처: https://arcane-lineage.fandom.com/wiki/Classes , https://strategywiki.org/wiki/MapleStory/Job_Advancements , https://roblox-arcane-odyssey.fandom.com/wiki/Mage , https://blox-fruits.fandom.com/wiki/Race_Awakening , https://king-legacy.fandom.com/wiki/Races

## Branching works best when the branch is gated by REPUTATION/ALIGNMENT rather than level — it turns a menu choice into a roleplay commitment.
Arcane Lineage gives each base class 3 Super Class paths — Chaotic, Neutral, Orderly. Chaotic and Orderly each require their own quest chain; Neutral requires no quests but costs more gold to learn. Players shift alignment by doing 'dark' versions of quests or consuming Heartbreaking Elixirs (community reports ~8 elixirs to flip quickly). Ragnarok Online's classic job quests similarly had per-class bespoke tasks (Magician's solvent mixing, Archer's trunk collection) and alignment-flavored dialogue.

**→ 시사점**: Branch the naval 전직 on faction reputation — Navy / Pirate / Merchant Company — with a bespoke quest per branch and a payable 'Neutral/freelance' branch for players who don't want the quest. This is a direct fit: the same base station (Gunner) becomes Naval Master Gunner vs Pirate Powder Monkey vs Privateer.

출처: https://arcane-lineage.fandom.com/wiki/Classes , https://tcrf.net/Ragnarok_Online/Changes/Job_Quest

## Advancement should be CHUNKED into individually purchasable pieces, not one binary unlock — Blox Fruits sells awakening one move at a time.
In Blox Fruits you awaken each of a fruit's 5 moves (Z/X/C/V/F) separately at the Fragment Dealer in Second/Third Sea. Per-move costs run roughly 500-5,000 Fragments; full-fruit totals range from ~9,500 (Light) to ~24,500 (Dragon), with mid-tier fruits like Magma/Buddha around 14,500. Players deliberately prioritize the 2-3 moves that matter and stop.

**→ 시사점**: After the 전직 ceremony, the new job should open a rack of 4-6 abilities each bought separately with a job currency (e.g., Commendations / Prize Shares). Every play session then ends with a purchase, and the 30-hour player and the 3-hour player are both mid-progress instead of one being stuck at a wall.

출처: https://rblxguide.com/games/blox-fruits/awakening , https://bloxfruit.io/guides/awakening-guide/

## The market has converged on a split: STAT respec is cheap/free and abundant, IDENTITY change is scarce — and the identity change is exactly where the paywall complaints land.
Blox Fruits hands out stat-reset codes constantly around events/updates (they are a standard entry in every codes article). Arcane Odyssey gives free stat resets before Lv80 and an 'Interchange' potion that resets stat build + awakening, but changing your first magic requires Hecate Essence — a 1-in-12 spawn on procedural islands in the Far Reaches of the Dark Sea (endgame, dangerous), reusable unlimited times per file — OR a 2,000 Robux one-time store purchase. There is a live player suggestion thread titled 'Magic Reset/Hecate Essence Rework'. Grand Piece Online charges 50 Robux per race reroll with ~68% chance of rolling Human, so the community routes around it via free codes, AFK World, and Impel Down raid shop rerolls.

**→ 시사점**: Make stat/skill-point respec free and unlimited (a barrel below decks). Make 전직 change earnable: 1 free re-pick at each tier milestone, then a token from content (a rare item from a dangerous voyage). If you sell it, sell speed/convenience, and never let Robux be the only realistic path — that is precisely the shape players write rework threads about.

출처: https://roblox-arcane-odyssey.fandom.com/wiki/Hecate_Essence , https://forum.arcaneodyssey.dev/t/magic-reset-hecate-essence-rework/146863 , https://gamertweak.com/how-to-change-race-gpo/ , https://sportskeeda.com/roblox-news/blox-fruits-codes-reset-stats

## Deepwoken's Shrine of Order shows respec can be CONTENT rather than a menu — but it needs explicit caps or players weaponize it.
The Shrine averages/redistributes your invested points; the known ruleset is that core attributes and weapon stats cannot lose more than 25 invested points, attunement stats can lose any amount, only stats with at least 1 manual point are touched, and non-divisible remainders are returned as free points. The community's actual use is an exploit-adjacent optimization: buy expensive high-requirement talents/mantras first, then order the points away — 'allowing your builds to effectively have more points than intended.' Talents and mantra upgrade levels auto-downgrade or vanish if requirements are no longer met.

**→ 시사점**: Put respec at a physical place you must sail to (a shrine island / drydock), which makes it a destination and a screenshot. Copy two mechanics: hard per-stat loss caps, and auto-downgrade (not deletion) of abilities whose requirements you drop below. Expect min-maxers to try to order-and-keep — decide up front whether that's a feature or a bug.

출처: https://deepwoken.fandom.com/wiki/Deep_Shrines/Shrine_of_Order

## Permanently locked classes still ship in 2026, but only when paired with a freely-swappable second layer.
Arcane Lineage locks your main class for the life of that character (the class is determined by starting weapon + which trainer you talk to; changing means a new character), yet Sub Classes can be swapped at any time by talking to a Sub Class Trainer. (Some SEO wikis claim gold-based respecs exist — the Fandom wiki says otherwise; treat 'is AL fully locked' as uncertain.) Deepwoken's version of this is permadeath + purchasable character slots: 3 slots free via badges, extra slots 200 Robux.

**→ 시사점**: Two-layer it: a locked-ish 'Hero Job' that carries identity, title, and prestige (changeable only via an earned token), plus a freely swapped 'Doctrine/Rigging' layer you can change at the helm before any voyage. Players get commitment-prestige AND experimentation in the same character.

출처: https://arcane-lineage.fandom.com/wiki/Classes , https://deepwoken.fandom.com/wiki/Character_Slots

## The single highest-leverage 'this is a BIG deal' mechanic on Roblox is the server-wide broadcast with escalating cutscene/VFX/music tiers — Sol's RNG built an entire viral game on it.
Sol's RNG fires an opening cutscene plus a chat line for rare rolls; global-tier auras print '[GLOBAL]: <Username> has rolled <Aura>, which is 1 in <Rarity>!!' and the rarest (Monarch, ~1 in 3 billion) prints a bespoke line, 'All hail, The <Username>.' Rarer auras get more elaborate visuals, cutscenes and sometimes exclusive background music. Pet Simulator 99 does the same for rare hatches — 'the whole server lights up in global chat.'

**→ 시사점**: Ship the 전직 as: freeze input → bespoke camera/cutscene on deck → server-wide broadcast in chat with the new job name → escalating VFX+music per tier, with a unique bespoke broadcast line for the final tier that names the player. This is cheap to build and is the main driver of clips/TikToks, which is your acquisition channel.

출처: https://sol-rng.fandom.com/wiki/Opening_Cutscenes , https://sol-rng.fandom.com/wiki/Auras , https://marix.app/library/games/pet-simulator-99-huge-pet-chances

## A transformation only feels powerful if it is mechanically useful and visible to OTHER players' screens.
Blox Fruits Race V4: you charge an awakening gauge by dealing/taking damage, then trigger a transformation animation during which you are invincible (i-frames), your avatar visually changes per race, and nearby enemy players' screens are desaturated to black-and-white. Note that the V4 reveal itself 'sparked widespread outrage' in the community — hype-then-disappoint is a real risk on reveal.

**→ 시사점**: The 전직/awakening activation should: (1) grant brief invulnerability so it's usable as a combat tool, (2) alter the player's own model/outfit permanently at least a little, (3) apply a screen-level effect on nearby players so the flex is involuntary on their end. And under-promise on reveal.

출처: https://blox-fruits.fandom.com/wiki/Race_Awakening , https://bloxfruitswiki.org/wiki/race-awakening/

## Titles above the nameplate are the standard persistent flex and are near-free to implement.
Equippable titles that render above the username and in chat are essentially universal in Roblox RPGs (Blox Fruits, RPG Simulator, Fabled Legacy, Etheria, Asylum Life). Etheria ties them to prestige count: one title at 1st prestige, another at 5th, another at 10th.

**→ 시사점**: Each 전직 tier grants a title + nameplate color, and the ship's crew manifest / sail insignia shows the captain's job. Tie the rarest titles to repeat-prestige counts so long-term players have a visible ladder past max level.

출처: https://blox-fruits.fandom.com/wiki/Titles , https://roblox-etheria.fandom.com/wiki/Prestige , https://rpg-simulator.fandom.com/wiki/Titles

## Advancement gated on PvP wins and no-death runs is the most-resented gate in the genre — Type Soul's Bankai grind is the cautionary tale.
Type Soul's Bankai has 4 stages, requires Elite Grade, and stage 1 alone needs 13 raid wins OR 16 ranked 2v2 wins OR 26 ranked 1v1 wins. Stage 2 must be completed without dying — dying resets progress completely and forces a full do-over. Guides describe the pursuit as 'emotionally taxing'. Arcane Odyssey players separately describe 6-8 hours of 'mindless and boring' cargo/Sailors-Lodge grinding just to reach Lv120 for the first awakening, made worse by a cargo-run XP nerf.

**→ 시사점**: Gate the naval 전직 on DEEDS with multiple redundant paths (win N naval engagements OR survive N storms OR chart N islands OR deliver N cargoes), never on a single PvP win count, and never full-reset advancement progress on death — use a soft setback (lose 1 of N stamps) so the player is still moving forward.

출처: https://typesoulwiki.org/progression , https://www.sportskeeda.com/roblox-news/how-get-bankai-type-soul , https://forum.arcaneodyssey.dev/t/any-good-grinding-strats/155132

## The exact ship-crew fantasy has already been shipped in a Roblox naval RPG — and it failed on EXECUTION, not concept. That gap is the single biggest opening here.
Arcane Odyssey has hireable NPC ship crews with exactly the archetypes you named: Navigator (winds/weather), Shipbuilder (repair), Chef (cooked meals), Cannoneer (naval firepower), Merchant (sells goods to captain and crew), Enchanter (temporary ship/crew boosts). They boost ship stats, warn about sea events, fire cannons, and take orders from a book at the helm. Community verdict: 'ship crews are useless' — NPC-vs-NPC combat is 'sloppy and slow' and players can clear a pirate crew alone; crew members get swept away by waves in the Dark Sea, follow the player, or vanish; forum threads ask for 'Making Ship Crew more active'.

**→ 시사점**: Our crew must deliver value through deterministic systemic effects (reload time, repair rate, tack speed, loot rolls, buff food) plus SCRIPTED, reliable set-pieces (a boarding volley animation, a carpenter patch cutscene, a lookout callout) — never through emergent NPC AI pathing or NPC-vs-NPC melee. Also: crew must never be lost to physics.

출처: https://roblox-arcane-odyssey.fandom.com/wiki/Ship_Crews , https://forum.arcaneodyssey.dev/t/ship-mechanics-making-ship-crew-more-active/147591 , https://roblox-arcane-odyssey.fandom.com/f/p/4400000000000115976

## Role-fit bonuses on named ship stations are the cleanest crew mechanic in the naval space — Sea of Conquest's +20% for correct placement.
Sea of Conquest: Pirate War gives each ship three officer positions — Captain, First Mate, Gunner — that unlock as the ship levels. Each position grants its own attribute boost, and heroes flagged as suited to a position gain roughly +20% extra stats when placed there. Heroes come from gacha (Echo Conch) and duplicates convert to shards/badges used for promotion, which can grant new skills or stat boosts. Assassin's Creed IV Black Flag Resynced (2026) works the same way narratively: named officers (e.g. Anne Bonny as Quartermaster, Tobias Smith granting the Cohort Mortar) each unlock a distinct ship ability plus an officer quest.

**→ 시사점**: Build 6 stations matching your archetypes and give each crew member a preferred station with a role-fit multiplier. Off-role placement stays legal but weaker — that turns crew management into a loadout puzzle (skill) instead of a raw-power check (luck). Give a few named/story officers who unlock a unique ship ability + a personal quest.

출처: https://www.bluestacks.com/blog/game-guides/sea-of-conquest/scpw-hero-formation-guide-en.html , https://gamingonphone.com/guides/sea-of-conquest-pirate-war-team-composition-guide-and-tips/ , https://www.videogameschronicle.com/guide/ac-black-flag-resynced-new-officers-quests/

## Active companion slot counts converge on 3 starting → 6-8 maximum, with slot expansion as the monetization surface (sold AND earnable).
Grow a Garden: 3 active pet slots, expandable to 8 by trading in aged pets (+1 for a pet aged 20+, up to +5 for aged 75+) or by buying with Robux; 60-pet inventory cap. Anime Vanguards: most maps allow 6-8 unit placement slots. Sea of Conquest: 3 officer slots per ship, unlocked by ship level. Pet Simulator 99: 6 free enchant slots unlocked via ranks + 3 premium slots sold for Robux.

**→ 시사점**: Start with 3 manned stations, expand to 6 (one per archetype) via ship upgrades/hull tier. Sell slot unlocks only where a free earn path also exists (PS99's 6-free-3-paid split and Grow a Garden's aged-pet trade-in are the two accepted templates). Cap active crew at 6 for readability and client performance.

출처: https://www.pockettactics.com/grow-a-garden-pet , https://growagarden.fandom.com/wiki/Pets , https://wiki.vanguards.gg/Unit_List , https://pet-simulator.fandom.com/wiki/Enchants_(Pet_Simulator_99)

## The proven way to stop companions from invalidating player skill is to point their power at the ECONOMY/UTILITY loop instead of at combat damage.
Grow a Garden — one of the platform's biggest games — has pets whose abilities are entirely passive/utility: applying crop mutations, cutting egg hatch time, generating XP, duplicating fruit. Strength scales with pet age (cooldown reductions, better proc chances) and is gated by a hunger bar (a pet that hits 0 hunger stops aging). Contrast with ARPG summoner-build discourse, where players report bosses 'dying instantly offscreen before they could even reach them' and walking through screens of mobs — the recurring complaint pattern when companions do the damage.

**→ 시사점**: Crew buff the SHIP and the LOOP (reload speed, repair rate, sail trim, loot quality, cooking buffs, chart reveals), while the hero's own combat stays 100% player-input. If crew do fight, cap them at chip/support damage and make their contribution scripted and legible ('Gunner fires a broadside on your command') rather than autonomous.

출처: https://progameguides.com/roblox/all-animals-and-pet-passives-in-grow-a-garden-roblox/ , https://growagarden.fandom.com/wiki/Pet_Mutations , https://steamcommunity.com/app/219990/discussions/0/4030221396675305999

## Four anti-power-creep tools are actually in production use: diminishing returns on stacked same-type effects, elemental rock-paper-scissors, retro-buffs for old units, and fast public nerfs.
Pet Simulator 99 enchants use explicit additive diminishing returns — the 1st copy of an enchant is 100% effective, then 60%, 38.3%, 27.5% — so stacking one effect is deliberately bad and roster variety is optimal. Anime Defenders' Elements system (Update 8) gives every unit and enemy one of 12 types, with 2x damage on strong matchups and 0.5x on weak, rewarding roster breadth over raw stats. Anime Vanguards added 'memorias' specifically so older units can keep up with new ones, after community complaints that new units 'so synergistic' left older ones with 'not much room'. Deepwoken ships fast targeted nerfs with published numbers (Brazen Blow hyperarmor 2s→1s; Rending Impact given a 30s cooldown; Arcwarder defense 15%→10%) and the community broadly accepts them as necessary.

**→ 시사점**: Build DR into crew stacking from day one (two Gunners ≠ 2x cannons). Add a matchup layer (shot type vs hull type / weather) so a broad crew beats a stacked one. Announce a 'veteran retrofit' path at launch so month-1 crew stay usable in month 12. Publish numeric nerf notes — Deepwoken proves players forgive nerfs they can read.

출처: https://pet-simulator.fandom.com/wiki/Enchants_(Pet_Simulator_99) , https://animedefenders.fandom.com/wiki/Units , https://animevanguards.fandom.com/f/p/4400000000000108108 , https://playpatch.org/roblox/deepwoken/tier-list/

## Collection depth is manufactured on three multiplied axes — base rarity × shiny/variant × trait/affix — which is why a 120-unit roster reads as 374 collectibles.
Anime Defenders has 120 base units, rising to 374 counting Shiny and Evolved variants; shinies are ~1 in 1000, do +5% damage, and are tradable. Anime Adventures trait odds are published and brutal: Godspeed 1%, Reaper 0.8%, Celestial 0.36%, Divine 0.2%, Golden 0.15%, Unique 0.1%.

**→ 시사점**: Get the same depth cheaply: ~20-30 crew archetypes × a visual variant (Veteran/Scarred/Legendary portrait) × a trait/quirk. Publish the odds yourself (you must anyway — see constraints) and make the top trait reachable via pity, because a 0.1% top trait with no floor is where the fairness complaints start.

출처: https://animedefenders.fandom.com/wiki/Units , https://animeadventures.fandom.com/wiki/Traits , https://progameguides.com/roblox/anime-adventures-traits-tier-list/

## Duplicates must ALWAYS convert into something — the genre standard is 5-into-1 rank-ups plus a dupe-to-reroll-currency sink.
Pet Simulator 99: 5 normal → Golden (1.5x power), 5 Golden → Rainbow (3x), 5 Rainbow → Shiny (5x). Anime Adventures: evolution consumes 1 duplicate of the base unit plus crafted materials, dupes can be sold for Gold Coins, and removing a Shiny yields Star Remnants — the reroll currency; evolving a unit also unlocks a valuable third equipment slot. Sea of Conquest converts hero duplicates into badges/shards for promotion, which can grant new skills.

**→ 시사점**: Every duplicate crew card should feed either a rank-up ladder (5 Gunners → Veteran Gunner → Master Gunner, visibly re-skinned each step) or the trait-reroll currency. Tie an extra equipment/heirloom slot to the rank-up so promoting a crew member is also a capacity increase, not just bigger numbers.

출처: https://pet-simulator.fandom.com/wiki/Enchants_(Pet_Simulator_99) , https://animeadventures.fandom.com/wiki/Evolution , https://animeadventures.fandom.com/wiki/Traits , https://www.levelwinner.com/sea-of-conquest-beginners-guide-tips-tricks-strategies/

## Visible pity plus a FLAT reroll cost is now the fairness baseline; charging more to reroll your best units reads as punishment.
Anime Vanguards trait rerolls cost one reroll token regardless of unit rarity, and reroll pity is tracked per unit with reported thresholds around 1500/858/400/300. Anime Adventures charges 5 Star Remnants per reroll for Mythical/Secret units versus 1 for Rare/Epic/Legendary. Community critique of AA is explicit: 'trait rerolling makes up 1/3 of powercreep consideration', gems are 'extremely draining to obtain', and drop rates are 'abominable compared to the labor required'. General consensus in gacha writing: pity protects players from failing forever and protects the studio from rage, refunds, and regulatory risk.

**→ 시사점**: Flat reroll cost + an on-screen pity counter ('guaranteed Rare+ in 12 rerolls'). And cap trait/quirk contribution to total crew power at roughly 10-15% so rerolling is optimization and flavor, not the actual power axis — that single cap defuses the loudest complaint category in this genre.

출처: https://animevanguards.fandom.com/wiki/Trait_Rerolls , https://animeadventures.fandom.com/wiki/Traits , https://animeadventures.fandom.com/f/p/4400000000000161606 , https://mwm.ai/glossary/pity-system

## HARD REGULATORY SHIFT (2026): Roblox globalized Korea-driven loot-box rules — any Robux-derived random item must publish every outcome's odds, and luck boosts must show numerically-updated true odds live.
Roblox overhauled its Paid Random Items policy to comply with South Korea's game law (mandatory probability disclosure since March 2024) and rolled it out worldwide rather than region-forking. Coverage: items bought with Robux, or with in-game currency purchased using Robux, that yield a random outcome. Requirements include disclosing odds of potential awards before spend, numerically explaining any paid odds-boosting item's impact before purchase, and dynamically updating displayed odds while a boost is active. Paid eggs, crates, spins, pity systems and luck boosts are all in scope, with regional compliance handled through PolicyService. Explicit exemption: randomized rewards granted for completing actions that involve no Robux/in-game-currency payment need no odds disclosure.

**→ 시사점**: Two clean choices for crew recruitment: (a) keep ALL randomness on the free/earned track (tavern hires, rescuing castaways, recruiting prisoners after a naval victory) and make anything Robux-purchasable DETERMINISTIC (pick the crew member you want) — this dodges the disclosure regime entirely and reads as anti-gacha in 2026; or (b) run a paid gacha and build a full public odds table plus a live-updating boosted-odds UI. Also design for PolicyService turning paid random items OFF for some users/regions — the game must still function.

출처: https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm , https://create.roblox.com/docs/production/monetization/paid-random-items , https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622

## The community's P2W line is drawn precisely at combat advantage: Deepwoken's model is defended, Blox Fruits' 2,500-Robux permanent fruits are the standing example of crossing it.
Deepwoken charges 400 Robux one-time access, 200 Robux per extra character slot (3 slots free via badges) and cosmetics — described as 'nothing that gives paying players a direct combat advantage', with the community taking pride in earned progress. Blox Fruits sells permanent fruits for ~2,500 Robux (Robux purchase makes it permanent; buying with in-game money means it's replaced later) and 450-Robux 2x Money passes; players say the game is '200 hours of grinding or spending Robux' and that PvP comes down to who can pay for Dragon/Kitsune/Gravity. Developer-side consensus writing agrees: sell cosmetics, convenience and time-savers, not competitive advantage.

**→ 시사점**: Monetize: crew/station SLOTS (with a free earn path), cosmetic ship-and-crew skins and uniforms, named-title/nameplate flair, XP or reputation boosts, respec/fast-travel convenience, a battle pass on voyages. Never sell: the top-tier 전직, the strongest crew member, or the only viable respec. Consider a modest paid-access or supporter pass — Deepwoken shows a paying-only audience defends the model and improves server quality.

출처: https://deepwoken.fandom.com/wiki/Character_Slots , https://www.oreateai.com/blog/understanding-the-400-robux-price-tag-of-deepwoken/2ff9a7a893c4257df86df48e3b364802 , https://blox-fruits.fandom.com/f/p/4400000000000537295/r/4400000000003922549 , https://www.sportskeeda.com/roblox-news/everything-know-gamepasses-roblox-blox-fruits

## Free respec is the modern default in AAA and the argument against it is now a minority position — but 'consequence' is still what makes advancement prestigious.
Dragon Age: The Veilguard's unlimited free respec from the skills menu is cited as the player-friendly trend other AAA RPGs should follow. The pro-free argument in circulation: non-free respecs 'discourage experiments, punish noobs, and kill the playerbase' where the skill ceiling is already high. The counter-argument that persists: 'a fun part of RPG is living with the consequences of choices.' Roblox's audience skews young and largely does not pre-research builds, which pushes hard toward the free side.

**→ 시사점**: Resolve the tension by layer, not by compromise: numbers (stat points, doctrine, crew stations) fully free and instant; identity (the 전직 name, title, transformation VFX) costs an earned token and re-triggers the ceremony. Players get zero dead-end risk, and the 전직 keeps its weight.

출처: https://gamerant.com/rpgs-best-respec-systems/ , https://forums.larian.com/ubbthreads.php?ubb=showflat&Number=615238&page=all

## Direct archetype mapping: every pattern above has a natural ship-crew expression, and the six roles you named map cleanly onto both the hero 전직 ladder and the crew station grid.
Arcane Odyssey already validates the vocabulary (Cannoneer, Shipbuilder, Navigator, Chef, Merchant, Enchanter) and Sea of Conquest validates the station-with-role-fit-bonus structure (Captain / First Mate / Gunner, +~20% on match). The natural translation: Gunner = damage/burst (Blox-Fruits-style per-move awakening of broadside abilities); Carpenter = survivability/repair (Deepwoken-style talent picks); Navigator = mobility/wind/weather and chart reveals (Grow-a-Garden-style utility passives); Quartermaster = economy, loot quality, crew morale/loyalty (Merchant analog); Cook = timed party buffs with a food/hunger economy (Grow a Garden's hunger gate); Surgeon = healing/revive and permadeath mitigation (fits the Deepwoken risk axis).

**→ 시사점**: Use one shared archetype table for both systems: the hero picks one archetype as their 전직 (with 3 faction branches each), and crew members occupy the other five stations. Crew that share the hero's archetype should synergize with the hero's job abilities — a Master Gunner crew member enhancing the Gunner hero's broadside — which creates real build synergy without ever letting a companion out-damage the player.

출처: https://roblox-arcane-odyssey.fandom.com/wiki/Ship_Crews , https://www.bluestacks.com/blog/game-guides/sea-of-conquest/scpw-hero-formation-guide-en.html

## ⛔ 하드 제약
- Roblox Paid Random Items policy (expanded 2026, Korea-law driven, applied globally): any random item bought with Robux — or with in-game currency purchased using Robux — must disclose the odds of every possible outcome before purchase. Paid luck boosts must have their effect explained numerically and must dynamically display the player's true boosted odds while active. Eggs, crates, spins, pity systems and luck boosts are all in scope.
- PolicyService can restrict/disable paid random items for specific users and regions. Any paid recruitment gacha must degrade gracefully to a deterministic purchase for restricted players, or the feature is simply unavailable to a slice of the audience.
- Randomized rewards granted for actions that involve NO Robux or Robux-derived currency are exempt from odds disclosure — this makes an earn-only crew RNG track materially cheaper to ship and to compliance-review than a paid one.
- Physically simulated NPC crew on Roblox is not reliable enough to carry core value. Arcane Odyssey's crew NPCs are called 'useless' — swept away by waves in the Dark Sea, failing to return to the ship, disappearing at random, and their NPC-vs-NPC combat is 'sloppy and slow'. Crew value must be systemic/deterministic, and crew must never be losable to physics.
- Cannot sell the strongest 전직 tier or the strongest crew member for Robux without triggering P2W backlash. Blox Fruits' 2,500-Robux permanent fruits are the standing community example ('200 hours of grinding or spending Robux'; PvP decided by who pays for Dragon/Kitsune/Gravity).
- Server-wide broadcasts only stay special if they are rare — every additional broadcast trigger devalues the 전직 announcement. Budget a strict number of broadcast-worthy events.
- Full resets of advancement progress on death drive quits (Type Soul's Bankai stage 2 'die and start over'). Not viable for a mass-audience naval game; use soft setbacks.
- A truly locked, un-respecable build is not viable for the Roblox demographic (young, non-researching players who will hit a dead end and quit) — but a fully free identity swap destroys the prestige of the 전직. The only workable resolution is layering: free numbers, earned identity.
- Active companion slots must stay at roughly 6 or fewer for UI readability and client performance; the genre converges on 3 starting slots expanding to 6-8.
- Trait/affix rerolls cannot be allowed to become the dominant power axis — Anime Adventures' community explicitly blames rerolling for about a third of its power creep, alongside 'extremely draining' currency acquisition.
- Any tradable rarity tier (shinies, event-exclusive crew) creates an off-platform value market and scam/dupe pressure; if crew are tradable, that economy has to be designed and moderated from day one.

## 💡 기회
- Nobody has made a ship crew FEEL good. Arcane Odyssey proved the fantasy and the exact six archetypes resonate, then shipped them broken (buggy, weak, lost at sea). A crew system built on deterministic station buffs + reliable scripted set-pieces + crew barks would immediately be the best crew system on Roblox.
- Two progression axes no Roblox naval game runs together: a hero 전직 ladder AND a ship-station crew grid, cross-linked so crew amplify the hero's job abilities. Arcane Odyssey has classes but weak crew; Sea of Conquest has crew stations but no hero job-change fantasy.
- Earn-only crew recruitment (rescue castaways, recruit defeated prisoners, tavern hires with reputation gates) is a genuine 2026 differentiator: it dodges the odds-disclosure regime entirely, reads as explicitly anti-gacha, and taps the documented player preference for earned unlocks over rolls.
- Role-fit multipliers with legal-but-weaker off-role placement (Sea of Conquest's +20% pattern) turns crew management into a loadout puzzle — skill expression, not a luck check. No Roblox naval game does this.
- Respec as a DESTINATION (a Shrine-of-Order-style drydock island you must sail to) monetizes convenience — fast travel, dock berth — without ever paywalling the respec itself, which is where Arcane Odyssey's 2,000-Robux magic change generates rework threads.
- Visible pity counter + flat reroll cost regardless of crew rarity is direct, marketable differentiation against Anime Adventures' 5x-cost-on-your-best-units model. 'You will never fail forever, and we show you the counter' is a bullet point competitors can't match without redesigning.
- Announce the 'veteran retrofit' anti-power-creep path (Anime Vanguards' memorias, but shipped at launch instead of as damage control) — pre-empts the single most predictable long-term complaint.
- Server-wide 전직 broadcast with escalating cutscene/VFX/music per tier and a bespoke named line for the final tier: the cheapest high-perceived-value feature available, and the documented engine of Sol's RNG's virality. Design it as clip bait.
- Granular advancement purchases (Blox Fruits' per-move awakening, 500-5,000 fragments each) mean no player is ever staring at an unreachable wall — everyone has a next purchase this session.
- Faction-branched 전직 (Navy / Pirate / Merchant, Arcane Lineage's Chaotic/Neutral/Orderly pattern with a payable neutral path) triples class count from one archetype table and creates natural PvP/roleplay factions for free.
- A crew loyalty/personality layer (named officers with personal quests that unlock unique ship abilities, per AC Black Flag Resynced) is unexplored on Roblox and adds narrative depth at low engineering cost.
- Pointing crew power at the loop (repair rate, reload, sail trim, loot quality, cooking buffs, chart reveals) rather than damage — Grow a Garden's validated pattern at enormous scale — lets us have deep companion collection while keeping every point of the hero's combat player-driven, which is the exact thing Deepwoken/Arcane Odyssey players say they value.

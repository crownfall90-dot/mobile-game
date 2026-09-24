# Зелья и засовы / Pins & Potions: final design document (v1.0 build)

**Status:** final for this iteration. **Engine:** Godot 4.5.1, GDScript, GL Compatibility renderer, portrait 720×1280.
**Scope:** 18 levels on 3 floors, a full meta layer and store-ready packaging. Everything is procedural: `_draw`, shaders and hand-written SVG.
**This document merges three proposals:** retention/market, player delight, and the shipping engineer. When they disagreed, the choice that is robust and verifiable was taken.

---

## 0. Decisions at a glance

| Topic | Decision |
|---|---|
| Recommended name | **«Зелья и засовы» / "Pins & Potions"**. 8 ranked options are in §2. |
| Heroine | **Мирра / Mirra**, the alchemist's apprentice (keep the current look: orange hair, blue robe, violet hat) |
| Missing mentor (story hook) | **Мастер Алембик / Master Alembic**. The ending reveals he turned himself into a frog. |
| Content this iteration | **3 floors × 6 levels = 18 levels.** Floor 4 is only a teaser card ("Ледник / Frost Cellar, coming soon"). |
| New mechanics (exactly 4) | **Acid grate**, **Sieve**, **Magma slime**, **Rune circle** (stone → gold). All are count-based or collision-layer based, with no impulses or timing windows. |
| Gold variants (not mechanics) | **Gem**: same physics as gold, worth 5 coins. **Ingredient**: an optional collectible. |
| Currencies | **Coins** (earned and spent), **Stars** (earned in levels, spent on lab restoration), **Hint potions** (consumable) |
| Main meta | **Master's Lab restoration.** The hub *is* the lab room: 9 objects restored with stars. |
| Collections | 9 outfits, 3 familiars (economic perks only), a 12-page Grimoire, 6 ingredients |
| Daily | A 7-day calendar that never resets, plus **Potion of the Day** (a Golden Rush replay: gold becomes gems) |
| Hints | Taken from **verifier-proven winning orders**, so they are always correct. Free after 2 fails. Skip after 3 fails. |
| No energy, no lives | Retry is instant and free, forever |
| Monetization | Stubs only (`Monetization` autoload always returns *unavailable*). No SDK and no INTERNET permission. |
| Physics rule | Nothing the player buys changes physics. `Engine.time_scale` is never touched. |
| Code budget | About 4,000 new or rewritten GDScript lines for P0 and about 450 for P1 (§16) |

---

## 1. Product thesis

The pull-the-pin genre is cheap to acquire players for, but they leave quickly: D1 is about 30–35% and D7 about 6–10%. We keep the genre's 20–60 s core, which is also the core of a good ad creative, and add three things the clones lack:

1. **Chemistry chains as spectacle.** The stone wave, acid fizz, the rune circle raining gold and the magma slime that flips the rules. Every reaction gets a sound, a comic word pop-up, particles and haptics. Our store video shows reactions, not just lava.
2. **A heroine to care about.** Mirra appears on the icon, the loading screen, the hub, in levels and on results. She wears her outfit and brings her familiar everywhere. Losing is cartoon soot, never death (PEGI 3 / ESRB E).
3. **A visible home that improves.** Royal-Match-style: stars rebuild the Master's Lab, which *is* the main menu. Rhythm: play 2 levels, restore 1 object.

**Tagline.** RU «Тяни засов. Вари реакцию. Преврати лаву в золото.» / EN "Pull the pin. Brew the reaction. Turn lava into gold."

**Closed-test targets:**
- D1 ≥ 40% and D7 ≥ 12%.
- At least 70% of installs reach level 1-6.
- Median session ≥ 6 min.

---

## 2. Name options (ranked)

Play titles are limited to 30 characters, and the counts below include the subtitle. Before committing, search Google Play, WIPO and Rospatent once. A web search today found no game called "Pins & Potions", only an enamel-pin craft shop.

| # | RU | EN | Store title (length) | Why |
|---|---|---|---|---|
| **1 (default)** | **Зелья и засовы** | **Pins & Potions** | "Pins & Potions: Tower Rescue" (28) / «Зелья и засовы: спаси Мирру» (27) | Alliterates in both languages (з-з, P-P). Contains the genre keyword people search for (*pins*) and our differentiator (*potions*). «Засов» (sliding bolt) sounds nicer than «штырь» and describes the mechanic exactly. Recommended by 2 of 3 designers. |
| 2 | Мирра и Башня зелий | Mirra and the Potion Tower | 26 / 19 | Mascot brand in the style of Save the Doge, and grows into sequels. Weaker for keyword search, so it needs the subtitle ": Pin Puzzle". |
| 3 | Из лавы — золото | Lava to Gold | "Lava to Gold: Pin Puzzle" (24) | States our signature aha (the rune circle) in three words and sells well in a GIF. |
| 4 | Зельепад | Potionfall | "Potionfall: Pin Puzzle" (22) | A coined word, like звездопад (starfall). Most ownable and likely trademark-free. Needs a subtitle. |
| 5 | Шипучая башня | Fizzy Tower | "Fizzy Tower: Pin Rescue" (23) | Cute and sensory, matches the fizz sound design, and kids can say it. No genre keyword. |
| 6 | Эликсир спасения | Elixir Escape | 13 | E-E alliteration. *Escape* is a strong keyword. Fairy-tale tone in Russian. |
| 7 | Откупорь! | Uncork! | "Uncork! Potion Pin Puzzle" (25) | Turns the core action into alchemy language. A good logo (a popping cork). Weak for search. |
| 8 | Алхимическая башня | Alchemy Tower | 18 | The current working title. Safe, but generic, and "Alchemy …" is crowded in search. |

**If option 1 is chosen:**
- **Package id:** `com.crownfall90.pinspotions` (the owner confirms the prefix). It is permanent after the first Play upload. The 0.1.0 test APK (`com.alchemytower.game`) then installs as a separate app; uninstall it.
- **Launcher name:** set it per locale through `application/config/name_localized` (ru: «Зелья и засовы», en: "Pins & Potions").
- **In-game wording (RU):** the UI says «засов» everywhere ("Потяни засов!").

---

## 3. Player experience

### 3.1 Loops

- **Micro loop (20–60 s):**
  - Read the cutaway, then tap pins in order. The pull sound rises 1 semitone per pin within a level.
  - Watch the chain: steam, then the stone wave with its rising "tock" ladder, slimes popping, gold flying to the counter.
  - Mirra cheers (win), or gets sooty with swirly eyes (lose), with one-tap retry.
- **Session (6–10 min):**
  - Level, then the Result screen: stars stamp in, the coin breakdown counts up, the chest bar fills, and the next-goal bar shows the nearest lab object or outfit.
  - **Primary button is always "Далее / Next".** The meta never interrupts.
  - Star costs are tuned so something is restorable every 1–2 levels.
- **Daily:** claim the calendar, play Potion of the Day, collect the Owl's hint.
- **Long term (D2–D14):** restore all 9 lab objects (which plays the ending), collect 9 outfits and 3 familiars, fill the Grimoire (12 pages + 6 ingredients), earn 3★ everywhere. Floor 4 arrives in update 1.

### 3.2 First-session script (no menus before the first win)

| Time | Event |
|---|---|
| 0:00 | Loading screen, 1–2 s: the logo flask fills. First launch only: one intro story card (P1): «Мирра опрокинула Зелье порядка — башня запечаталась, а подопытные слизни сбежали!», dismissed with one tap. |
| 0:05 | **1-1 First Pin**: 1 pin and an animated hand. Win in under 15 s, 3★. |
| 0:25 | Result, then the **hub (lab) for the first time**. A guided tap: "Restore the Shelves ★2" → dust puff → shelves pop in → a hand on "Играть". |
| 1:30 | **1-2**: water + lava = stone. «Эврика!» banner: first Grimoire page, +20 coins. The Grimoire button appears. |
| 3:00 | **1-3**: the hint button pulses. The first hint is free (tutorial). The Wardrobe and Daily buttons appear. The Day 1 calendar can be claimed (+50). |
| ~5:00 | After 1-4, about 300 coins, so the Wardrobe shows a red dot and the player buys **Ember Robe (300)**. The first ingredient (Star Mushroom) is found. |
| ~7:00 | **1-5 (Hard)**: the existing level. It is the 5th paying win, so the **first chest** opens (100 coins + 1 hint). |
| ~9:00 | **1-6 finale**: Floor 1 complete. **Cat Уголёк** joins (+150 coins). Intro card for Floor 2 "Acid Lab". Potion of the Day unlocks. |
| Exit | The hub shows the Day 2 calendar preview (+50 + hint potion), 3 lab objects waiting, and the Acid Lab. That is 3 open loops. |

### 3.3 Progressive feature reveal (hidden until unlocked, never shown as greyed-out)

| Feature | Appears |
|---|---|
| Hub + Map | After the first win |
| Grimoire button | After the first page is discovered (1-2) |
| Wardrobe, Daily | After 1-3 is cleared |
| Potion of the Day | After Floor 1 is complete |
| Familiars tab | When the first familiar is granted (Floor 1 complete) |

---

## 4. Mechanics

### 4.1 Existing rules (kept) and required fixes

Kept as is:
- Substances: water, lava, acid, gold, stone.
- Reactions: water + lava → stone with a chain wave (25 px radius, 0.04 s step); acid + stone → both removed; acid + water → acid becomes water; lava and acid kill slimes and Mirra.
- Win: pieces ≥ goal and no live enemies. Lose: lava, acid or a live enemy in the hero zone, or 5 s after the last pin with no win.
- Measured today with Godot 4.5.1 headless and `--fixed-fps 60`: one autoplay run takes **0.85 s wall time**. On `level_001`, the solution wins with 3★ (22/22), `water,lava,gold,floor` loses (enemy), and `gold,lava,water,floor` also wins (3 of 24 orders win).

Fixes, owned by the Mechanics agent:

1. **Reaction table.** Replace the `if`-chain in `Level._react` with a `(kind, kind) → handler` table. Replace `Substances.is_deadly` in the enemy contact check with the enemy vulnerability table: `{slime: [LAVA, ACID], magma: [WATER, ACID]}`.
2. **Event bus.** `Level` emits `reaction(id, pos, info)` and `collected(kind, pos)` (§18.4). `Level` never calls audio, haptics or Profile. The GameScreen and Juice layers react to the events, which keeps headless verification clean.
3. **Win window.** The win fires when the goal is met, no enemy is alive **and no piece has been collected for 0.8 s** (capped at 3.0 s after the goal is first met). This makes 3★ reliable, because rolling coins are no longer cut off. Lose checks stay active until the win fires.
4. **Zero-gold levels.** `pieces_total == 0` now gives 3★; today it divides by zero.
5. **Contact monitoring.** `Item.set_kind()` owns the collision mask (the sieve bit) and the contact monitor, instead of `setup()` only.
6. **Cartoon lose.** `hero.die()` becomes `hero.oops(reason)`: sooty (lava), frizzy hair (acid), slimed (enemy), sad (stuck). No tipping over.
7. **Jitter hook.** `Level.jitter_seed`: when it is not 0, every spawned body is offset by ±1 px (seeded RNG). Used only by verification.

### 4.2 The four new mechanics

#### M1. Acid grate / Решётка
- **Rules:**
  - An iron lattice that blocks **all** bodies: drops, gold, stones, enemies.
  - Each acid drop that touches it is **consumed** and removes 1 HP (default `hp` 8, allowed 4–12). At 0 HP it dissolves with a fizz and a «Дзынь!» pop-up.
  - Water and lava do nothing to it.
  - Puzzle value: acid spent on the grate is not available for a slime, and water released first dilutes the acid that should have opened the grate.
- **JSON:** `"grates": [{"rect": [x, y, w, h], "hp": 8}]` (axis-aligned).
- **Implementation (`scripts/level/grate.gd`, about 90 lines):**
  - A StaticBody2D on `LAYER_WORLD` with a RectangleShape2D.
  - Acid items already report `body_entered` against static bodies. In `_resolve_contact`: if the other body is a `Grate` and the item is ACID, call `_remove(item)` and `grate.hit()`, and emit `grate_hit {hp}`.
  - At 0 HP: `shape.set_deferred("disabled", true)`, play a drip-and-fade dissolve over 0.4 s, emit `grate_break`.
  - Draw: a frame plus vertical bars every 14 px with rivets. The colour lerps from steel `#6b6488` to acid green `#7fdc3a` as HP drops, and the bars thin.
- **Verification:** purely count-based. The lint checks `hp` is within 4–12.

#### M2. Sieve / Сито
- **Rules:** a mesh plate. Liquids (water, lava, acid) fall through it. Gold, gems, ingredients, stone and all enemies rest on it. It separates treasure from liquid, and lets lava drain onto a slime while the gold waits.
- **JSON:** a wall entry with `"type": "sieve"`, for example `{"poly": [...], "type": "sieve"}`. The plate should be 8–12 px thick.
- **Implementation (about 30 lines in `walls.gd` plus a mask rule in `item.gd`):**
  - New layer `LAYER_SIEVE := 8` on a separate StaticBody2D.
  - `Item.set_kind()` sets `collision_mask = WORLD | ITEMS | ENEMY`, plus `SIEVE` for non-fluid kinds. Enemies always include `SIEVE`.
  - Lava that cools to stone starts colliding with the sieve, which is intended.
  - Draw: a brass frame `#a8741a` with a 45° mesh of `#f5c542` lines every 10 px at 60% alpha.
- **Verification:** the lint warns when a lava fill lies within 60 px above a sieve, because cooling inside the mesh would eject the stone unpredictably. The jitter check catches remaining flakiness.

#### M3. Magma slime / Огненный слизень
- **Rules:**
  - An orange slime with dark glowing cracks. **Lava does not hurt it**: it bathes and glows brighter, which emits `magma_bath` once.
  - **Water or acid kills it.** A water kill consumes the drop, makes steam, and leaves **3 stones** at its position. Those stones can then go through a rune circle.
  - Reaching Mirra loses the level.
  - It flips the rule players learned on Floor 1.
- **JSON:** `enemies[].kind`: `"slime"` (default) or `"magma"`.
- **Implementation (about 50 lines):**
  - `Enemy.kind` plus a per-kind palette (TOP `#ff6a1f`, BOTTOM `#9e2a0a`, cracks `#3a0f05`, additive ember glow). `Enemy.killed_by(item_kind) -> bool`.
  - Stones spawn at offsets (−12, 6), (12, 6) and (0, −10) through `Level._spawn_item`.
  - Same radius (30) and mass (3) as the slime, so layouts can swap enemies freely.

#### M4. Rune circle / Круг превращения
- **Rules:**
  - A glowing, slowly turning rune circle placed in a shaft. Any **stone** that passes through it becomes a **gold coin**, with a flash, a bell and a «Золото!» pop-up. Everything else passes unchanged.
  - The aha: you *want* to make stone, so water on lava stops being defence and becomes a gold factory. Level 3-2 has no gold at all.
- **JSON:** `"circles": [{"pos": [x, y], "r": 48}]` (r from 36 to 60).
- **Implementation (`scripts/level/transmuter.gd`, about 70 lines):**
  - An Area2D with `collision_mask = LAYER_ITEMS`, polled with `get_overlapping_bodies()` in `Level._physics_process`, so no contact monitors are needed.
  - For a STONE item: `set_kind(GOLD)` with `transmuted = true`. It is drawn as a coin of radius 9, so the collider is unchanged. `pieces_total += 1`, emit `transmute`.
  - Draw: 2 concentric arcs, 8 glyph strokes, rotation from `_t`, an additive glow disc.
- **Goals:** levels with circles use an absolute goal: `"goal": {"pieces": 16, "three_star": 26}`. Ratio goals (`{"gold": 0.7}`) stay valid for all other levels.

### 4.3 Gold variants (P0 gem, P1 ingredient)

- **Gem / Самоцвет** (`"kind": "gem"`):
  - Same radius (11), mass (0.4) and friction as gold, so a verified solution stays valid.
  - Counts as 1 piece toward the goal and stars, and pays **5 coins** (a coin pays 1).
  - The random 35% gem look on ordinary gold is removed, so value is readable at a glance.
  - This is what powers the Golden Rush modifier.
- **Ingredient / Ингредиент** (`"kind": "relic", "count": 1, "relic": "<id>"`):
  - Radius 12 and mass 0.4, blocked by the sieve. Nothing destroys it; it is lost only if it falls out of the tower.
  - Collected when it enters the hero zone. It does **not** count toward the goal.
  - 6 in total: the 4th and 6th level of each floor.
  - Drawn as small icons with a white halo: star mushroom, phoenix feather, moon dew, dragon scale, frog crown, philosopher's pebble.

### 4.4 Systems on top of the mechanics

- **Reaction juice** (`scripts/ui/juice.gd`), driven only by `Level.reaction` and `collected`:
  - **Word pop-ups:** a pool of 8 Labels (scale 0 → 1.2 → 1, rise 40 px, fade over 0.6 s), with the same id throttled to once per 0.35 s:

    | Event | Pop-up |
    |---|---|
    | Water + lava steam | «Пшш!» |
    | Stone wave of 10 or more | «Волна ×N!» |
    | Slime pop | «Хлоп!» |
    | Acid reaction | «Шшш!» |
    | Grate break | «Дзынь!» |
    | Transmutation | «Золото!» |

  - **Pitch ladders:**
    - Stone tocks rise 1 semitone per tock, up to +12, and reset after a 0.5 s gap.
    - Coins collected within 0.3 s of each other rise 1 semitone each, up to +12.
  - **Combo text:** 3 or more reactions within 1.2 s show «Цепная реакция ×N!». Cosmetic only; it is not paid in coins, so verification never depends on it.
  - **Discovery:** the first time an event maps to a Grimoire page, a non-blocking «Эврика! Новая страница» banner slides down.
- **Golden Rush modifier:** `Game.load_level(id, {"golden": true})` rewrites fills of kind `gold` to `gem` at load time. Physics are identical, and verification checks it anyway (gate G7).

### 4.5 Considered and cut or deferred

| Idea | Verdict | Why |
|---|---|---|
| Ice block / Frost flask | Deferred to **Floor 4 (update 1)** | Good mechanics, but they exceed the 4-mechanic cap. The flask needs an impact trigger. |
| Growth flask and vines, thunder powder, cracked walls, explosions | Cut | High cost (150–220 lines each), and impulses or blasts threaten determinism |
| Fire imp, stone golem, acid slime | Cut | Magma slime covers the "flipped rules" idea. More species dilute readability. |
| Sleeping gas, frost, smoke (4th fluid) | Cut | The metaball renderer's R/G/B channels are all taken |
| Mirror floors | Deferred (P2) | Mirrored physics is not bit-symmetric (the spawn grid starts from the left), so every mirror needs re-verification. Golden Rush gives daily variety for free. |
| Cauldron (4 h brew), Phoenix, win-back notifications | Deferred | Weak without notifications. Keep the scope for levels. |
| Star gates on floors, bonus levels, pin skins, palette picker | Cut | Stars fund the lab instead. Bonus levels are content we cannot afford to verify now. |
| Engine.time_scale slow-motion or hit-stop | **Banned** | It changes the physics step and invalidates verified solutions |

---

## 5. Levels

### 5.1 Level JSON v2 (backward-compatible with v1)

```json
{
  "format": 2,
  "id": "f2_03",
  "floor": 2,
  "title": {"ru": "Решётка", "en": "The Grate"},
  "hint":  {"ru": "Кислота разъедает решётку", "en": "Acid eats through the grate"},
  "tutorial": "",            // "" | "hand" (hand on solution[0]) | "hint" (free-hint lesson)
  "intro": "grate",          // new-element card id shown before the first attempt (optional)
  "hard": false,
  "tower": {"rect": [130, 200, 460, 1010]},
  "walls":   [{"poly": [[100,180],[130,180],[130,1240],[100,1240]]},
              {"poly": [[140,700],[350,720],[350,730],[140,710]], "type": "sieve"}],
  "grates":  [{"rect": [360, 600, 220, 14], "hp": 8}],
  "circles": [{"pos": [360, 900], "r": 48}],
  "pins":    [{"id": "acid", "from": [68, 392], "to": [360, 392]}],
  "fills":   [{"kind": "acid", "rect": [136, 214, 212, 164], "count": 26},
              {"kind": "relic", "rect": [400, 420, 40, 40], "count": 1, "relic": "moon_dew"}],
  "enemies": [{"kind": "slime", "pos": [245, 770]}],
  "hero":    {"pos": [360, 1210], "zone": [130, 960, 460, 250]},
  "goal":    {"gold": 0.7},        // or {"pieces": 16, "three_star": 26}
  "solution": ["acid", "water", "floor"],
  "fails":   [["water", "acid", "floor"]],
  "verify":  {"max_win_share": 0.34, "daily": true}
}
```

- `title` and `hint` may still be plain strings (treated as RU).
- `fill.kind` is one of water, lava, acid, gold, **gem**, stone, **relic**.
- `enemies[].kind` is slime or **magma**. `walls[].type` is `solid` (default) or **sieve**.
- **Stars:**
  - 3★ at ≥ 95% of `pieces_total`, or ≥ `three_star` for an absolute goal.
  - 2★ at ≥ the midpoint between the goal and the 3★ threshold.
  - 1★ when the goal is reached.

### 5.2 `levels/index.json` v2

`levels/index.json` is created once in Phase 0 with all 18 ids. Level agents never edit it. Missing files are skipped with a warning.

```json
{"format": 2,
 "floors": [
  {"id": "storeroom", "n": 1, "title": {"ru": "Кладовая", "en": "The Storeroom"}, "theme": "storeroom",
   "levels": ["f1_01","f1_02","f1_03","f1_04","f1_05","f1_06"]},
  {"id": "acid_lab", "n": 2, "title": {"ru": "Кислотная лаборатория", "en": "The Acid Lab"}, "theme": "acid_lab",
   "levels": ["f2_01","f2_02","f2_03","f2_04","f2_05","f2_06"]},
  {"id": "hall", "n": 3, "title": {"ru": "Зал превращений", "en": "The Transmutation Hall"}, "theme": "hall",
   "levels": ["f3_01","f3_02","f3_03","f3_04","f3_05","f3_06"]}],
 "teaser": {"title": {"ru": "Ледник", "en": "The Frost Cellar"}, "text": {"ru": "Скоро: лёд и морозные флаконы", "en": "Coming soon: ice and frost flasks"}}}
```

### 5.3 Chapter plan: 18 levels

The pattern on every floor: levels 1–2 introduce the new idea, 3–4 practise and twist it, **5 is Hard** (red badge, clear bonus ×2), and **6 is the finale** (a big payoff, a bit easier than 5).

**Floor 1 · «Кладовая» / The Storeroom** (amber). Elements: water, lava, gold, slime, the stone wave. No new code, so authoring starts at hour 0.

| Lvl | id | Title RU / EN | Pins | Idea | Must-lose order(s) | Extras |
|---|---|---|---|---|---|---|
| 1-1 | f1_01 | «Первый засов» / First Pin | 1 | A gold chamber above Mirra | n/a | tutorial `hand` |
| 1-2 | f1_02 | «Горячий пол» / Hot Floor | 2 | Water first hardens a lava pocket in the gold's path | gold → water (the gold shoves lava into the zone) | intro `water_lava` |
| 1-3 | f1_03 | «Слизень на обед» / Slime Snack | 3 | Lava onto the slime, then open its floor, then the gold | floor first (the slime reaches Mirra) | intro `slime`, tutorial `hint` |
| 1-4 | f1_04 | «Каменный мост» / Stone Bridge | 3 | A long lava strip fills a gap; one water release makes a ≥15-drop wave bridge; gold rolls over | gold before water; water before lava (no bridge, gold falls into the pit) | relic star_mushroom |
| 1-5 | f1_05 | «Горячий приём» / Hot Welcome | 4 | **The existing `level_001`**, renamed | water,lava,gold,floor (verified LOST); floor,lava,water,gold | **Hard** |
| 1-6 | f1_06 | «Двое в банке» / Two in a Jar | 4 | Lava must reach two slimes on two ledges before water seals the rest; about 30-piece gold cascade | water before the 2nd lava pin | relic phoenix_feather; floor reward |

**Floor 2 · «Кислотная лаборатория» / The Acid Lab** (green-teal). Adds first use of acid, **grate** and **sieve**.

| Lvl | id | Title RU / EN | Pins | Idea | Must-lose order(s) | Extras |
|---|---|---|---|---|---|---|
| 2-1 | f2_01 | «Кислотный дождь» / Acid Rain | 2 | Acid pops the slime, which guards the gold path | gold → acid | intro `acid` |
| 2-2 | f2_02 | «Разбавь!» / Dilute! | 3 | An acid tank over the exit: water dilutes it, then acid dissolves a stone plug holding the gold. Order matters twice. | floor first (acid reaches Mirra) | |
| 2-3 | f2_03 | «Решётка» / The Grate | 3 | Gold behind a grate (hp 8); acid must reach it before the water tank opens | water → acid → floor (acid diluted, grate survives → stuck) | intro `grate` |
| 2-4 | f2_04 | «Сито» / The Sieve | 3 | A lava + gold mix sits on a sieve over a slime pit: lava drains onto the slime, gold stays, then the side pin rolls it to Mirra | side pin first (lava goes with the gold) | intro `sieve`, relic moon_dew |
| 2-5 | f2_05 | «Каждая капля» / Every Drop Counts | 4 | Limited acid (about 24 drops) split between a grate (hp 10) and a slime; water released last cleans up the leftovers | water early; slime branch first (not enough acid for the grate) | **Hard** |
| 2-6 | f2_06 | «Авария в лаборатории» / Lab Accident | 5 | All Floor 2 reactions: plug, sieve, grate, dilution; big gold | 2 designed wrong orders | relic dragon_scale; floor reward |

**Floor 3 · «Зал превращений» / The Transmutation Hall** (purple and gold). Adds **rune circle**, **magma slime**, gems.

| Lvl | id | Title RU / EN | Pins | Idea | Must-lose order(s) | Extras |
|---|---|---|---|---|---|---|
| 3-1 | f3_01 | «Свинец в золото» / Lead into Gold | 1 | A heap of 30 stones pours through a circle and rains gold. Pure wow. | n/a | intro `circle`, tutorial `hand`, absolute goal |
| 3-2 | f3_02 | «Сделай золото сам» / Make Your Own Gold | 3 | **No gold in the level.** Water hardens lava, then the floor pin sends the stones through the circle. | floor first (lava reaches Mirra) | absolute goal |
| 3-3 | f3_03 | «Огненный слизень» / Magma Slime | 3 | The lava bath does nothing; water douses the slime and its 3 stones become 3 coins | lava → floor → water (the slime survives the lava and reaches Mirra) | intro `magma` |
| 3-4 | f3_04 | «Двое разных» / Odd Couple | 4 | A purple slime and a magma slime: lava for one, water for the other, without the water cooling the lava first | water first (it cools the lava, and the purple slime survives) | relic frog_crown, gems |
| 3-5 | f3_05 | «Не спеши, кислота» / Easy on the Acid | 4 | Acid must open the grate, then be diluted before it can dissolve the stones heading into the circle | water → acid (grate stays); lava before acid (the stones are dissolved) | **Hard** |
| 3-6 | f3_06 | «Философский каскад» / Philosopher's Cascade | 5 | A 50-drop lava wave, then a stone avalanche through 2 circles, with a magma slime guard; about 40 pieces including gems | 2 designed wrong orders | relic philosophers_pebble; Floor 4 teaser |

**Total: 18 levels and 60 pins; 6 ingredients; 7 intro cards** (water_lava, slime, acid, grate, sieve, circle, magma).
Pins per level: F1 1,2,3,3,4,4 · F2 2,3,3,3,4,5 · F3 1,3,3,4,4,5. The **maximum is 5 pins**, so an order search is at most 120 orders.

### 5.4 Difficulty targets (measured by the verifier)

The metric is **win share**: the fraction of all pin orders that win at normal timing.

| Position | Max win share |
|---|---|
| x-1 (1-pin levels are exempt) | 0.50 |
| x-2 … x-4 | 0.34 |
| x-5 Hard | 0.17 (level_001 measures 0.125) |
| x-6 Finale | 0.25 |

Expected first-try win rate: Floor 1 about 90% → 65%, Floor 2 about 75% → 45%, Floor 3 about 70% → 40%.

### 5.5 Verification gates (`tools/verify.py`, every level, before every merge)

| Gate | Check |
|---|---|
| G1 | `tools/lint_levels.py` passes: schema; unique ids; solution and fail pins exist; pin handles outside the tower rect; each fill rect can hold its count (2.05·r grid); fill bottoms 5–8 px above a pin; ≤ 160 dynamic bodies, ≤ 120 fluid drops, ≤ 5 pins; grate hp 4–12; circle r 36–60; ≤ 1 relic; ratio goal 0.5–0.8; **warning** for lava within 60 px above a sieve |
| G2 | The **solution WINS** in 5 runs: interval 1.5 s with jitter seeds 0, 1 and 2; interval 0.8 s with seed 0; and "settle" (pull the next pin when all bodies sleep, max 4 s) with seed 0 |
| G3 | At 1.5 s with seed 0: **3★**, and the relic is collected if the level has one |
| G4 | Every `fails` order **LOSES** with seeds 0 and 1. Levels with ≥ 2 pins need at least 1 fail order. |
| G5 | Levels with ≥ 3 pins: pulling **all pins in the same frame** does not win |
| G6 | **Order search** over all permutations with seeds 0 and 1: win share ≤ cap; ≤ 10% flaky orders (outcome changes with the seed); the solution and fail orders must be 0% flaky. Orders that win under both seeds are written to `levels/solutions/<id>.json` for the hint system. |
| G7 | Golden Rush: the solution still wins with 3★. On failure the level gets `"daily": false` and leaves the Potion of the Day pool. |

- **Cost:** about 250 runs per level × 0.85 s ≈ 64 min serial for 18 levels, or about 16 min on 4 cores (`-j nproc`). Results are cached by (level-file SHA, engine version) in `.verify_cache/`.
- **Mechanic test levels:** `levels/test/t_*.json` (not in the index) run through the same gates with `--file=`.

### 5.6 Authoring rules

1. **Start from the wrong order.** Design the order that must lose, then the geometry that makes it lose.
2. **Chamber layout:**
   - Floors slope ≥ 15° toward exits, so drops never balance on flat ledges.
   - Chambers ≥ 60 px wide.
   - ≥ 20 px clearance around pin tips.
3. **Goals:**
   - Ratio goals 0.6–0.7; never 1.0.
   - Only design 3★ where the solution reliably collects ≥ 95%.
4. **Chamber kit:** a JSON snippet library in `docs/LEVEL_FORMAT.md`: side pit, gold shelf, funnel to hero, zigzag ramp, grate window, sieve tray, circle shaft.
5. **Rework rule:** a level that fails a gate is **redesigned, not tuned**. If time runs out, ship 16 levels (cut f2_05 and f3_05) rather than flaky ones.

---

## 6. Economy (all numbers live in `data/economy.json`)

### 6.1 Currencies

| Currency | Earned | Spent | Notes |
|---|---|---|---|
| **Coins / Монеты** | Levels, chests, floors, lab sets, Grimoire, daily | Outfits, hints (when out of potions), skip | Starting balance 0 |
| **Stars / Звёзды** | 1–3 per level; wallet = Σ best stars − stars spent | Lab restoration | Improving a level's best adds to the wallet. Max 54. |
| **Hint potions / Зелья-подсказки** | Start with 3; chests, calendar, floors, Owl | 1 per hint | |

### 6.2 Income (exact)

- **Level first clear:**
  - (1 per coin piece + 5 per gem + clear bonus 20, or **40 on Hard** + 10 per star) × (1 + streak% + Cat 10%).
  - Example: 20 coins, 3★ on a normal level = 20 + 20 + 30 = **70**.
- **Replay:** pieces value + 10 per *newly earned* star. No clear bonus, no multipliers, no chest progress.
- **Win streak (P1):**
  - A win on the first attempt of a first clear or a Potion of the Day adds +10%, capped at +50%.
  - Any loss or restart resets it. Replays of cleared levels do not touch it.
- **Chest, fixed contents:** every **5** paying wins (first clears + the first Potion of the Day win of a day), **100 coins + 1 hint**. With the Frog equipped, every 4 wins.
- **Floor complete** (all 6 levels cleared or skipped):
  - Storeroom: 150 coins + 1 hint + **Cat**
  - Acid Lab: 200 + 1 hint + **Owl**
  - Transmutation Hall: 250 + 2 hints + Floor 4 teaser
- **Lab set complete** (each 3-object set): **+100**. All 9 objects: the ending card + the **Frog "Мастер Алембик"** familiar.
- **Grimoire:** regular page +20, secret page +50 (300 total). 100% gives the **Grand Alchemist** outfit.
- **7-day calendar:**
  - Advances one slot on each new local date with a claim. It never resets.
  - Clock rollback: a claim needs today's `YYYY-MM-DD` to be greater than `last_claim`.

  | Day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
  |---|---|---|---|---|---|---|---|
  | Reward | 50 | 50 + 1 hint | 100 | 2 hints | 150 | 100 + 1 hint | 200 + **Moon Robe** (cycle 1); later cycles 300 + 2 hints |

  Cycle 1 totals 650 coins + 4 hints.
- **Potion of the Day** (after Floor 1):
  - Level = `cleared_daily_pool[hash(date) % n]` with Golden Rush.
  - The first win that day pays pieces × 5 (about 100). Later plays that day pay nothing.
  - Counts toward the chest.
- **Owl equipped:** +1 hint potion on the first launch of each day.
- **Welcome back (P1):** 3 or more days away gives 150 coins + 2 hints, with a card «Мирра соскучилась!».

### 6.3 Sinks and prices

| Sink | Price |
|---|---|
| Hint when out of potions | 60 coins (confirm dialog) |
| Skip (offered after 3 losses in a row on the level) | 250 coins. The level counts as cleared with 0★ (unlocks the next level); no coins, no chest progress, no streak change; replayable for stars. |
| Outfits (paid) | 300 / 500 / 800 / 1,200 / 2,500 (§7.2) |
| Lab objects | Stars: 2, 3, 4 · 4, 4, 5 · 5, 6, 7 (40★ of the 54 possible) |

### 6.4 `data/economy.json` (owned by the Meta agent)

```json
{
  "start": {"coins": 0, "hints": 3, "outfit": "apprentice"},
  "level": {"coin": 1, "gem": 5, "clear": 20, "clear_hard": 40, "per_new_star": 10},
  "streak": {"per_win": 0.10, "cap": 0.50},
  "cat_bonus": 0.10,
  "chest": {"every": 5, "every_frog": 4, "coins": 100, "hints": 1},
  "floor_reward": {"storeroom": {"coins": 150, "hints": 1, "grant": "cat"},
                   "acid_lab":  {"coins": 200, "hints": 1, "grant": "owl"},
                   "hall":      {"coins": 250, "hints": 2}},
  "lab_set_bonus": 100,
  "hint": {"coins": 60, "free_after_fails": 2},
  "skip": {"coins": 250, "after_fails": 3},
  "grimoire": {"page": 20, "secret": 50},
  "daily": [{"coins": 50}, {"coins": 50, "hints": 1}, {"coins": 100}, {"hints": 2},
            {"coins": 150}, {"coins": 100, "hints": 1},
            {"coins": 200, "grant": "moon", "repeat": {"coins": 300, "hints": 2}}],
  "potion_of_day": {"after_floor": "storeroom", "gem_value": 5},
  "owl_daily_hints": 1,
  "welcome_back": {"days": 3, "coins": 150, "hints": 2}
}
```

### 6.5 Budget check

**Engaged player, D7** (all 18 levels, all dailies, average 2.5★): about **4,700 coins** in total.

| Source | Coins |
|---|---|
| Level first clears | about 1,350 |
| Cat bonus | about 90 |
| Win streak | about 150 |
| Chests (24 paying wins → 4 chests) | 400 |
| Floor rewards | 600 |
| Lab sets | 300 |
| Grimoire | 300 |
| Calendar | 650 |
| Potion of the Day (6 × about 100) | about 600 |
| Star-improvement replays | about 250 |

- That player buys Ember, Frost, Herbalist and Pirate (2,800) and has about 1,900 of the 2,500 for Golden Magister, which becomes the D8–D10 goal and bridges to update 1.
- Hint potions available in week 1 are about 20, so hints never block progress.

**Median player** (12 levels over 3 active days): about **1,900 coins**, enough for 3 outfits.

| Source | Coins |
|---|---|
| Levels | about 850 |
| Chests | 200 |
| Floors 1–2 | 350 |
| Lab set | about 100 |
| Grimoire | about 200 |
| Calendar | 200 |

**First purchase:** Ember (300) is affordable right after 1-4. **Stars:** an average of 2.22★ per level completes the lab; below that, the player replays for stars, which is a soft push, not a wall.

---

## 7. Unlockables and content catalog (`data/catalog.json`, owned by Meta)

### 7.1 Master's Lab restoration (the hub room)

The 9 objects unlock in order. A floor's set becomes available once that floor is unlocked.

| # | id | RU / EN | ★ cost | Set (floor) | Slot rect in the 720×1280 hub |
|---|---|---|---|---|---|
| 1 | shelves | Полки / Shelves | 2 | 1 | 40, 300, 190, 220 |
| 2 | barrels | Бочки / Barrels | 3 | 1 | 30, 760, 180, 200 |
| 3 | lantern | Фонарь / Lantern | 4 | 1 | 240, 130, 70, 120 |
| 4 | workbench | Верстак с колбами / Flask Workbench | 4 | 2 | 480, 760, 210, 200 |
| 5 | window | Витраж / Stained Window | 4 | 2 | 260, 170, 200, 290 |
| 6 | bookcase | Книжный шкаф / Bookcase | 5 | 2 | 500, 260, 190, 440 |
| 7 | rug | Ковёр с рунами / Rune Rug | 5 | 3 | 180, 960, 360, 110 |
| 8 | telescope | Телескоп / Telescope | 6 | 3 | 420, 470, 140, 200 |
| 9 | alembic | Великий алембик / Great Alembic | 7 | 3 | 240, 520, 240, 380 |

Each object has three states:
- **Broken:** desaturated 60%, rotated 6°, crack polylines, a cobweb.
- **Ghost** (the next one to restore): a pulsing dashed outline with a star tag.
- **Restored:** full colour.

Restoring plays a dust puff, a pop-in (TRANS_BACK) and the `restore` SFX. Restoring the Great Alembic plays the ending card: Master Alembic hops out as a frog and becomes the Frog familiar, followed by «Продолжение следует… Ледник» (to be continued: the Frost Cellar).

### 7.2 Outfits (9): a palette plus a hat style

The palette fields are robe, robe_dark, hat, hat_dark and trim. Outfits are data only; `hero.gd` draws them.

| id | RU / EN | Palette (robe / robe_dark / hat / hat_dark / trim) | Hat style | Unlock |
|---|---|---|---|---|
| apprentice | Ученица / Apprentice | 3d7bff / 1f3f9e / 8a4dff / 5427b8 / f5c542 | pointy | free |
| ember | Огненная мантия / Ember Robe | e0452b / 8a1f12 / ff9a2e / b8520f / ffe27a | pointy + flame tip | 300 |
| frost | Морозный плащ / Frost Cloak | 7fd6ff / 2f7fb0 / e6f7ff / 8cc4e0 / ffffff | hood | 500 |
| herbalist | Травница / Herbalist | 4fae5a / 245c2c / — / — / ff7ab8 | flower wreath | 800 |
| pirate | Пиратка-алхимик / Pirate Alchemist | 2b2b3d / 111118 / c0392b / 7a1f16 / f5c542 | bandana | 1,200 |
| golden | Золотой магистр / Golden Magister | f5c542 / a8741a / fff1b8 / d9a93a / ffffff | crown | 2,500 |
| moon | Лунная мантия / Moon Robe | 2a2f7a / 151842 / 3d46b8 / 20266e / cfe3ff | pointy + crescent | calendar Day 7 |
| slime_queen | Королева слизней / Slime Queen | b561ff / 5b1f9e / d59bff / 8a4dff / 4dff9a | slime crown | all 6 ingredients |
| grand | Великий алхимик / Grand Alchemist | 6a1fb0 / 34105c / 8a4dff / 5427b8 / ffc933 | tall pointy with stars | Grimoire 100% |

### 7.3 Familiars (3)

Only one can be equipped. Familiars have no collision and sit beside Mirra: idle bob, cover their eyes on danger, hop on a win. Each is about 40 lines of `_draw`.

| id | RU / EN | Look | Perk (economic only) | Source |
|---|---|---|---|---|
| cat | Кот Уголёк / Ugolyok the Cat | Black cat, amber eyes | +10% level coins | Floor 1 complete |
| owl | Сова Тиса / Tisa the Owl | Grey-brown owl, big eyes | +1 hint potion per day | Floor 2 complete |
| frog | Мастер Алембик / Master Alembic | Green frog with tiny spectacles and hat | Chest every 4 wins | Lab 9/9 restored |

### 7.4 Grimoire / Гримуар: 12 reaction pages + 6 ingredient cards

| Page id | RU / EN | Trigger (event → condition) |
|---|---|---|
| water_lava | Вода + лава = камень / Water + Lava = Stone | `steam` |
| lava_slime | Лава против слизня / Lava vs Slime | `slime_pop` killer=lava |
| stone_wave | Каменная волна / Stone Wave | `wave_end` n ≥ 15 |
| acid_slime | Кислота против слизня / Acid vs Slime | `slime_pop` killer=acid |
| dilute | Вода разбавляет кислоту / Water Dilutes Acid | `dilute` |
| acid_stone | Кислота ест камень / Acid Eats Stone | `acid_stone` |
| acid_grate | Кислота ест решётку / Acid Eats the Grate | `grate_break` |
| transmute | Камень → золото / Stone into Gold | `transmute` |
| magma_bath | Лавовая ванна / Lava Bath | `magma_bath` |
| magma_water | Вода гасит огненного слизня / Water Douses Magma | `slime_pop` enemy=magma, killer=water |
| *noble_gold (secret)* | Благородный металл / Noble Metal | `noble_gold` (acid touches gold: nothing happens) |
| *great_wave (secret)* | Великая волна / Great Wave | `wave_end` n ≥ 40 |

- Undiscovered pages show «?» and a riddle, for example «Что будет, если кислота встретит золото?» ("What happens when acid meets gold?").
- Ingredient cards fill in as ingredients are found.
- Completion = (pages + ingredients) / 18.

---

## 8. Hints, skip, anti-frustration

- **Hint button** (HUD bottom-left, flask icon, badge = potion count, or "60" with a coin icon when out):
  1. Filter the verified winning orders (`Game.winning_orders(id)`) by the pins already pulled. Prefer `solution` if it is still consistent.
  2. If **no winning order** matches: «Этот путь не сработает — начнём заново?» ("This path won't work, start over?") with **[Заново / Restart]** for free. No potion is spent.
  3. Otherwise spend 1 potion (or 60 coins after a confirm). This starts **guided mode for this attempt**: the next pin gets a gold pulse ring and a drawn pointing hand, and after each pull the following pin is highlighted.
- **Free hint:** after **2 losses in a row** on a level, the next hint there is free (badge «FREE»). The first hint on 1-3 is free as a tutorial.
- **Skip:** after **3 losses in a row**, for 250 coins (§6.3). A hidden rewarded-ad placement `skip_level` is reserved.
- **Also:**
  - Retry is under 0.5 s.
  - A near-miss line: «Собрано 78% золота» or «Ещё 2 монеты до ★★★».
  - Hard levels are marked before you play them.
  - After a 2nd loss, Mirra says «Почти! Попробуй другой порядок» ("Almost! Try another order").

---

## 9. Screens (exact list)

All screens are built in code with `UiKit`. `Router` stacks screens with a 0.25 s fade; popups appear on layer 50 (TRANS_BACK 0.25 s).

| # | Screen | Elements |
|---|---|---|
| S0 | Boot splash | Colour only, `#120c24`, no image (no white flash) |
| S1 | **Loading** | Background shader; `Logo` (the icon flask drawn in code at about 260 px, whose **liquid level is the progress** and which bubbles); localized title (64 px gold, 10 px ink outline) and tagline; one tip line rotating every 2.5 s (8 tips, e.g. «Вода + лава = камень»); version in the corner. See §11.3. |
| S2 | **Hub = Master's Lab** | **Top bar:** coin pill (tap → Wardrobe), star pill (tap → restore sheet), hint-potion pill, gear. **Room:** the lab drawn full-screen (stone wall, floorboards, moonlit arched window) with 9 object slots. **Mirra** (Hero node, equipped outfit) at (360, 1010) with her familiar; tapping her makes her hop and say one of 8 lines. **Bottom row:** [Карта] [Гардероб] **[ИГРАТЬ · 2-3]** (big gold, pulsing; shows a Hard badge on x-5; when everything is cleared it reads «Ледник — скоро» and opens the Map) [Гримуар %] [Награды]. Red dots when a lab object or outfit is affordable, a daily reward is claimable, or a Grimoire page is new. **Restore sheet** (bottom sheet): object name, «★3», [Восстановить ★3] or «Нужно ещё ★2 — играй уровни» (need 2 more stars: play levels). Android back opens the exit confirmation. |
| S3 | **Tower Map** | Vertical scroll, bottom-up, opens at the current level. **3 floor bands** in their theme tint, each headed «Этаж 2 · Кислотная лаборатория» with the new-element icon. **6 flask-shaped nodes** (96 px) zigzag along a copper pipe: number, 0–3 stars, a Hard badge, an ingredient flask (empty or filled) on relic levels, a lock. The current node carries Mirra's hat marker and pulses. A floor-reward icon (locked, ready or opened) sits at the top of each band. A frosted "Ледник: скоро" teaser sits on top. Tapping a locked node shakes it and shows a toast. |
| S4 | **Game** (Level + HUD) | **Top:** pause (88 px) left; «2-3 · Решётка» centre; a gold tube "collected / needed" with 3 star notches beneath; restart right; the streak flame under the tube (P1). **Bottom:** hint button left (badge); the tutorial hint banner centre (existing). **Juice layer:** word pop-ups, «Эврика!» banner, coins flying to the tube. Tutorial hand. Familiar next to Mirra. A New-element card before the first attempt when `intro` is set. |
| P1 | Pause | Resume, Restart, Map, Home; Sound, Music and Vibration toggles. Opens by itself when the app goes to the background. |
| P2 | **Result: win** | Ribbon title «Спасена!» / "Rescued!"; Mirra celebrating (1.4× scale) with her familiar hopping. **3 stars stamp in** (scale 1.6 → 1, ring, pings). The line «Золото 20/22». **Coin breakdown count-up:** Coins 18 · Gems 2×5 · Clear bonus 20 · New stars 3×10 · Streak +30% · Cat +10% = total, then the coins fly to the pill. Toasts: new Grimoire page(s), ingredient found. **Chest bar** with 5 segments (when full, [Открыть] opens M2). **Next-goal bar:** «★ 4/5 → Фонарь» or «Огненная мантия 240/300». Near-miss line when below 3★. Buttons: **[Далее]** primary, [Ещё раз], a small [Лаборатория] icon. A hidden `double_coins` slot. |
| P3 | **Result: lose** | «Ой!»; a reason line: «Мирра обожглась о лаву» (lava) / «Кислота добралась до Мирры» (acid) / «Слизень добрался до Мирры» (enemy) / «Не хватило золота» (not enough gold); sooty Mirra; near-miss %. Buttons: **[Ещё раз]** primary, [Подсказка] (shows FREE after 2 fails), [Пропустить · 250] (after 3 fails), a small [Карта]. |
| S5 | **Wardrobe** | A large live Mirra preview that hops when an outfit is tried on. Tabs [Наряды / Outfits] and [Питомцы / Familiars]. A 3-column card grid: a static mini-Mirra thumbnail, the name, and the price or unlock reason («День 7», «Все ингредиенты», «Гримуар 100%», «Этаж 2»). Buttons: [Купить 300] / [Надеть] / [Надето]. Familiar cards show the perk text. A purchase plays confetti, a twirl and a coin cascade. |
| S6 | **Grimoire** | A book panel; header «9/18 · 50%» plus a reward preview (Grand Alchemist). Tabs [Реакции / Reactions] (12 cards, 2 columns: drawn formula icons "blob + blob → result", a name, and one line in Mirra's voice; undiscovered cards show «?» and a riddle) and [Ингредиенты / Ingredients] (6). |
| P4 | **Daily** | 7 slot cards (4 + 3): claimed ones ticked, today glowing, the future dimmed; Day 7 shows the Moon Robe. **[Забрать / Claim]**. Below: the **Potion of the Day** card («Золотая лихорадка: всё золото — самоцветы ×5», "Golden Rush: all gold becomes gems ×5") with the level number and [Играть], or «Завтра новое зелье» (a new potion tomorrow) with a countdown to midnight. |
| P5 | **Settings** | See §13. |
| M1 | New-element card | A large drawn icon, the name, 1–2 rule lines with mini icons, a looping mini animation (two blobs meet and change), [Понятно!]. 7 cards, all data-driven from the catalog. |
| M2 | Chest open | The chest shakes 3 times, bursts open, and the rewards fly out to the pills. |
| M3 | Floor complete | The tower band lights up, the familiar card appears, the coins, and «Этаж 2 открыт!». |
| M4 | Confirm | Buy, reset (double), exit, hint for coins, skip. |
| M5 | Story card (P1) | A panel with Mirra's portrait, 2–3 lines, tap to continue: the intro, and the lab-complete ending. |
| M6 | Toasts | «Эврика!», ingredient found, not enough coins («Не хватает монет — пройди уровень»). |

**Back navigation:**
- Back closes the top popup first, then pops the screen.
- On the Hub it asks «Выйти?» ("Exit?").
- In Game it opens Pause. On the Result screens it goes to the Map.
- `quit_on_go_back=false`. Every screen has a back path, which the Play pre-launch robot needs.

---

## 10. Visual style

**Mood:** cosy neon alchemy at night. Indigo interiors, glowing liquids as the brightest things on screen, gold for every reward, sticker-like ink outlines.

**Tokens** (defined once in `UiKit`):

| Token | Value |
|---|---|
| Background | `#120c24` → `#2a1a4a` (existing shader) |
| Panel | `#2a2147`, glass at 88% alpha, border `#9d8fd0` 3 px, radius 22 |
| Ink | `#1b1236` (UI outline), `#24163d` (characters) |
| Text | `#ffffff`, muted 70% |
| Gold (primary, coins) | `#f5c542`, dark `#a8741a`, light `#fff1b8` |
| Magenta ("new", dots) | `#ff4fd8` |
| Danger | `#ff5a5a` |
| Water | `#1a6bfa` / `#8ce6ff` |
| Lava | `#f2380f` / `#ffdb4d` |
| Acid | `#4dcc1a` / `#d9ff73` |
| Slime | `#b561ff` |
| Magma slime | `#ff6a1f` + cracks `#3a0f05` |

**Per-floor themes** (backdrop and wall tints plus one particle type, same code for all):

| Floor | Walls (top / bottom) | Light / accent | Particles |
|---|---|---|---|
| Storeroom | `#514574` / `#2b2345` | amber `#ffb35c` | dust motes |
| Acid Lab | `#3f5a5e` / `#1f2e33` | green `#8cff9a` | rising bubbles |
| Transmutation Hall | `#5a3f7a` / `#2a1a45` | gold rune lines at 25% | gold sparkles |

**UI kit:**
- Chunky buttons: StyleBoxFlat with radius 22 and a 6 px darker bottom lip. Pressing squashes to 0.94 for 80 ms with a tick sound. Gold for primary, violet `#8a4dff` for secondary.
- Round icon buttons are 88 px. The minimum touch target is 88 px.
- Font: Godot's default font (it already renders Cyrillic) through a FontVariation with embolden 0.6, an 8 px ink outline and a 2 px shadow for headings. Sizes 28 / 36 / 56 / 84.
- Numbers count up. Coins fly along Bézier curves.

**Icons:** 25 hand-written SVGs in `art/icons/` (48 viewBox, 3 px ink stroke, 2-tone fill), rasterized at runtime with `Image.load_svg_from_string` and cached per size. The set: coin, star, gem, hint, gear, pause, restart, home, map, book, hanger, calendar, chest, lock, play, back, close, check, sound_on, sound_off, music, vibration, flame, relic, hand.

**Accessibility:** substances also differ by pattern and motion: lava veins, rising acid bubble rings (a small shader addition), water surface sparkle.

**Performance:**
- 60 fps on Mali-G52 / Adreno 506-class phones.
- The hub, the map and walls are static `_draw` canvases, redrawn only on change.
- One particle system per screen, ≤ 300 particles.
- "Меньше эффектов" (Reduce effects) halves particles, disables screen shake and sets the fluid buffer to 0.35 scale.

---

## 11. App icon, logo, loading screen, store graphics

### 11.1 App icon (hand-written SVG, `art/app/`)

Concept: a round alchemy flask, **water on the left and glowing lava on the right, with a jagged grey stone seam where they meet**. A **gold pin** pierces the neck horizontally. **Mirra's violet pointed hat** sits on the stopper. No text. It must read at 48 px.

Files:
- `icon_bg.svg`: 108×108, radial gradient `#6a3bc8` → `#2a1560` → `#140c24` centred at (54, 43), with 3 four-point sparkles `#ffe27a` at 85% near (26, 30), (84, 34) and (80, 80).
- `icon_fg.svg`: everything inside the **r = 33 safe circle** centred at (54, 54).
- `icon_mono.svg`: the same foreground silhouette in white only (flask outline, pin, hat) for Android 13 themed icons.

Foreground sketch (valid SVG; the Art agent may polish it but must keep it inside the safe circle; no filters, no text, because ThorVG supports neither):

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
  <defs>
    <linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8ce6ff"/><stop offset="1" stop-color="#1a6bfa"/></linearGradient>
    <linearGradient id="l" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffdb4d"/><stop offset="1" stop-color="#f2380f"/></linearGradient>
  </defs>
  <circle cx="60" cy="73" r="13" fill="#ff7a1a" opacity="0.3"/>                       <!-- lava glow -->
  <circle cx="54" cy="69" r="16" fill="#2a2147" opacity="0.9"/>                         <!-- glass -->
  <path d="M54,64 L38.8,64 A16,16 0 0,0 54,85 Z" fill="url(#w)"/>                        <!-- water -->
  <path d="M54,64 L69.2,64 A16,16 0 0,1 54,85 Z" fill="url(#l)"/>                        <!-- lava -->
  <polygon points="52,64 56,64 54.5,68 57,72 54,76 56.5,80 54,85 51.5,81 53.5,77 51,73 53.5,69 51,66"
           fill="#8d8aa3" stroke="#4a4760" stroke-width="1"/>                           <!-- stone seam -->
  <line x1="40" y1="64" x2="68" y2="64" stroke="#ffffff" stroke-opacity="0.55" stroke-width="1.5"/>
  <circle cx="54" cy="69" r="16" fill="none" stroke="#1b1236" stroke-width="3"/>
  <path d="M43,61 A12.5,12.5 0 0,1 50,56" fill="none" stroke="#ffffff" stroke-opacity="0.6" stroke-width="2.5" stroke-linecap="round"/>
  <rect x="48.5" y="44" width="11" height="10.5" fill="#2a2147"/>                        <!-- neck -->
  <path d="M48.5,44 V53 M59.5,44 V53" stroke="#1b1236" stroke-width="3"/>
  <rect x="45.5" y="41" width="17" height="4.5" rx="2" fill="#9d8fd0" stroke="#1b1236" stroke-width="2"/>
  <line x1="35" y1="48.5" x2="79" y2="48.5" stroke="#a8741a" stroke-width="5" stroke-linecap="round"/>   <!-- pin -->
  <line x1="36" y1="47.6" x2="78" y2="47.6" stroke="#f5c542" stroke-width="2.5" stroke-linecap="round"/>
  <circle cx="31" cy="48.5" r="4.5" fill="none" stroke="#a8741a" stroke-width="4.5"/>
  <circle cx="31" cy="48.5" r="4.5" fill="none" stroke="#f5c542" stroke-width="2.5"/>
  <ellipse cx="54" cy="40.5" rx="12" ry="3" fill="#5427b8" stroke="#24163d" stroke-width="2"/>            <!-- hat brim -->
  <path d="M45,40 Q51,33 57,24 Q59,32 63,40 Z" fill="#8a4dff" stroke="#24163d" stroke-width="2"/>        <!-- hat cone -->
  <circle cx="55.5" cy="33" r="2" fill="#ffc933"/>
</svg>
```

`tools/make_icons.gd` (headless) produces:
- 432×432 PNGs of fg, bg and mono (adaptive icon layers).
- A 192×192 legacy icon (bg with fg composited).
- The 512×512 Play icon (full-bleed square with no rounding; Play applies the mask).
- `res://icon.svg` for the project.

All of them are wired into `export_presets.cfg`.

### 11.2 Logo
The `Logo` node draws the same flask at 4× with animated bubbles, plus a title Label (gold fill, 10 px ink outline) and a small drawn pin crossing the «и» / "&". It is used on the loading screen and at the top of the result ribbon.

### 11.3 Loading screen: real work, in steps spread across frames

1. `Profile.load()`, including the `.bak` fallback and migration from `progress.cfg`.
2. `Game` parses and validates the index and all 18 level files.
3. `Sfx.prepare()` synthesizes the SFX in ≤ 8 ms slices per frame (about 3 s of audio, well under 200 ms total).
4. **Shader warm-up:** render a hidden FluidRenderer with 20 drops (one of each fluid), the backdrop and FX for 2 frames at alpha 0.01. This avoids a first-level stutter on GLES3.
5. Route: on first launch, the story card (P1) and then **f1_01**; otherwise the **Hub**.

Minimum 1.0 s, target ≤ 2.5 s on low-end phones. Dev flags skip the loading screen.

### 11.4 Store graphics
- **Feature graphic 1024×500:** captured from an in-engine `--screen=promo` under xvfb: the logo on the left, and on the right a lava wave turning to stone, gold raining from a rune circle, and Mirra cheering. Text needs the font, so it is not an SVG.
- **Screenshots:** 6 at 1080×1920 with `--shot`: stone wave, rune-circle gold rain, magma slime, the hub before and after restoration, the wardrobe, a 3★ result. RU and EN captions. **Real gameplay only.**

---

## 12. Audio and haptics (all synthesized at runtime)

Format: `AudioStreamWAV`, 22,050 Hz mono 16-bit, generated during loading. A pool of 8 players with ±4% random pitch (except the ladders), and SFX and Music buses. Nothing plays when headless.

| id | Trigger | Recipe | Throttle |
|---|---|---|---|
| ui_tap | Button press | 30 ms sine 880 → 660 Hz | 40 ms |
| ui_pop | Popup open | 80 ms sine sweep 300 → 600 Hz, soft | — |
| pin | Pin pull | 40 ms band-noise burst + sine sweep 600 → 1,400 Hz over 120 ms + inharmonic partial ×2.76 at −12 dB; +1 semitone per later pin in the level | — |
| steam | Water + lava | High-passed noise, 350 ms exponential decay | 90 ms |
| stone_tock | Each stone in a wave | 25 ms 90 Hz thump + 2 kHz click; ladder +1 semitone per tock, cap +12 | 40 ms |
| fizz | Acid reactions, dilution | Noise × (0.5 + 0.5·sin 2π·30t), 2–6 kHz band, 250 ms | 90 ms |
| slime_pop | Enemy killed | Sine 500 → 120 Hz over 180 ms with 12 Hz vibrato + 40 ms noise splat | 60 ms |
| magma_hiss | Water kills magma | Steam 500 ms + 70 Hz rumble | — |
| grate_hit | Acid on grate | 60 ms fizz + 1.2 kHz tick | 60 ms |
| grate_break | Grate dissolves | Clang: partials at 523 / 1,410 / 2,230 Hz with a 600 ms decay + fizz tail | — |
| transmute | Stone → gold | Bell: 1,568 + 2,349 Hz sines with a 400 ms decay + 3-note sparkle; ladder | 70 ms |
| coin / gem | Collected | Two blips 1,320 → 1,760 Hz (60 ms each); gem adds a 2,637 Hz triangle shimmer; ladder +1 semitone within 0.3 s, cap +12 | 35 ms |
| relic | Ingredient found | Ascending pentatonic, 5 notes, triangle, 400 ms | — |
| star1/2/3 | Result stars | Triangle pings at 880 / 1,175 / 1,568 Hz, 250 ms, with ring | — |
| win | Win | C5-E5-G5-C6 triangle arpeggio (90 ms each) + 400 ms held chord | — |
| lose | Lose | G4 → E♭4 falling minor third, low-passed square, 500 ms | — |
| eureka | New page | Glissando 600 → 1,800 Hz + 2 sparkle blips | — |
| chest | Chest open | 3 noise rattles + glissando 400 → 1,600 Hz + a cascade of 8 coins 40 ms apart | — |
| purchase / restore | Buy, restore | A cascade of 5 coins + a low "whoomp" / low-passed dust noise 200 ms + pop 440 → 880 Hz | — |

**Music (P1):**
- An 8-bar C-major-pentatonic loop at 96 BPM (20 s): a soft sine pad with slow attack plus a decaying triangle "harp" pluck, at −18 dB.
- Rendered on the `WorkerThreadPool` after the hub is visible, and cached as raw PCM in `user://audio_v1/music.pcm`.
- It is silent until ready. Cut it if it is slow on the owner's phone.

**Haptics** (`Input.vibrate_handheld(ms, 0.5)`, VIBRATE permission, toggle in Settings):

| Event | Pattern |
|---|---|
| Pin | 15 ms |
| Slime pop | 30 ms |
| Grate break | 35 ms |
| Transmute | 10 ms (throttled to 150 ms) |
| Chest | 40 ms |
| Lose | 60 ms |
| Win | 3 × 20 ms, 120 ms apart |

**App lifecycle:** audio is muted and the level paused on `NOTIFICATION_APPLICATION_PAUSED` or focus loss.

---

## 13. Settings (popup P5)

- Toggles: **Звук / Sound**, **Музыка / Music**, **Вибрация / Vibration**.
- **Язык / Language:** Авто / Русский / English. Auto uses `OS.get_locale_language()`, with RU for `ru`, `uk`, `be` and `kk`, otherwise EN.
- **Меньше эффектов / Reduce effects.**
- **Повторить обучение / Replay tutorial** (resets the FTUE flags).
- **Политика конфиденциальности / Privacy:** in-app text («Игра работает офлайн и не собирает данных», "The game works offline and collects no data") plus an [Открыть / Open] button that calls `OS.shell_open(url)` for the GitHub Pages copy.
- **Лицензии / Licenses:** `Engine.get_license_text()` and `Engine.get_copyright_info()` in a scroll panel. This notice is required by Godot's MIT licence.
- **Об игре / About:** version 1.0.0 and credits («Сделано на Godot Engine», "Made with Godot Engine").
- **Сбросить прогресс / Reset progress:** double confirmation.
- **Hidden dev panel** (7 taps on the version):
  - [Copy stats]: puts the local per-level plays, wins, fails and hint use on the clipboard via `DisplayServer.clipboard_set`, so closed-test players can send feedback without analytics.
  - [Self-test] (P1): replays every solution on the device and lists failures, which catches ARM-versus-x86 physics drift.
  - [Unlock all]: debug builds only.

---

## 14. Monetization and analytics hooks (no SDK)

- **`Monetization` autoload:**
  - `rewarded_available(placement) -> false`
  - `show_rewarded(placement)` emits `rewarded_finished(placement, false)`
  - `iap_available() -> false`
  - `purchase(product_id)` is a no-op
  - UI slots render only when `rewarded_available()` is true, so they are invisible in v1.
- **Reserved placements:** `double_coins` (win result), `free_hint`, `skip_level`, `daily_double`.
- **Reserved products:** `no_ads`, `starter_pack` (1,000 coins + 5 hints + Golden Magister, about $3.99).
- **Future ad policy:** rewarded ads only. If interstitials are ever added: never before Floor 2 is complete, and at most 1 per 3 minutes.
- **Analytics:** there is no network. `Profile.data.stats` keeps local counters: plays, wins, fails and fail reasons per level; hint uses; skips; purchases; daily claims. They are exposed only through the dev panel.

---

## 15. Store readiness checklist (status September 2026)

1. **Identity:** choose the final name, then the package id (permanent). `versionName` 1.0.0, `versionCode` 10000, incremented on every upload.
2. **AAB preset "Android AAB (Play)":**
   - `gradle_build/use_gradle_build=true`, `export_format=1`.
   - **target SDK 36**, which Play has required for new apps and updates since 31 Aug 2026. Set `gradle_build/target_sdk=36`; the Godot 4.5.1 template default is lower.
   - min SDK 24; ABIs arm64-v8a + armeabi-v7a.
   - Install the template with `--install-android-build-template`.
   - Needs the Android SDK platform 36 and Gradle downloads. If the container cannot do this, the owner builds locally with the documented preset.
   - Keep the existing no-Gradle APK preset for phone testing (arm64 only halves its size).
3. **16 KB page alignment:** check the native libraries with `zipalign -c -P 16 -v 4` or the Play Console bundle explorer.
4. **Signing:** an upload keystore outside git, passed through `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables. Enroll in Play App Signing.
5. **Preset options:**
   - `permissions/vibrate=true` only; no INTERNET.
   - `user_data_backup/allow=true` (Auto Backup keeps the save).
   - `include_filter="levels/*.json,levels/solutions/*.json,data/*.json,data/strings/*.json,art/icons/*.svg"`.
   - Icons wired in (main 192; adaptive foreground, background and monochrome 432).
6. **Project settings:** `application/config/quit_on_go_back=false`, `name_localized` for RU and EN, portrait, immersive mode.
7. **Listing:**
   - Title ≤ 30 characters, short description ≤ 80, full description ≤ 4,000, in RU and EN. Category Puzzle.
   - Short description EN: "Pull the pins, mix potions and rescue the young alchemist!"
   - Short description RU: «Тяни засовы, смешивай зелья и спаси юную алхимичку!»
   - Assets: 512 icon, 1024×500 feature graphic, 6 screenshots.
8. **App content:**
   - Privacy policy URL (a one-page RU/EN site on GitHub Pages, `docs/privacy/index.html`).
   - Data safety: "No data collected or shared". Ads: No. In-app purchases: none.
   - IARC: cartoon fantasy peril, no blood, no death, no gambling (chest contents are fixed), so expect **PEGI 3 / ESRB E**.
   - Target audience: **13+ recommended**, which keeps future ad options outside the Families policy. The owner decides.
9. **Testing track:** new personal developer accounts need a **closed test with ≥ 12 opted-in testers for 14 consecutive days** before production. Start it as soon as the P0 build is stable. Read the pre-launch report.

---

## 16. Scope, priorities, line budget

About 1,730 lines exist today. `main.gd` (151) and `hud.gd` (313) are replaced, so their lines count as rewrites.

| Module | P0 lines | P1 lines |
|---|---|---|
| core: game 110, profile 200, economy 180, loc 50, router 110, monetization 25 | 675 | +40 (streak, Potion of the Day, welcome back) |
| dev/dev_runner.gd | 140 | +40 (on-device self-test) |
| ui: kit 200, icons 40, popup base 50 | 290 | |
| screens: loading 90, hub 180, map 150, game_screen 140, hud 160, juice 90 | 810 | |
| popups: pause 50, result 160, settings 110, confirm 40, intro card 70, chest 60, daily 100 | 590 | +50 (story card) |
| wardrobe 150, grimoire 120 | 270 | |
| art: lab_art 220, logo 60 | 280 | familiar.gd +120 |
| level/hero.gd (outfits, hats, oops states) | +110 | |
| mechanics: level +150, item/substances +70, enemy +50, grate 90, transmuter 70, walls +30, pin +25, backdrop themes +25 | 510 | relic/ingredient +50 |
| audio: synth 100, sfx 140 | 240 | music.gd +100 |
| tools: make_icons 40, test_meta 80 | 120 | |
| **Total** | **≈ 4,035** | **≈ +450** |

Python tools are not counted in the GDScript budget: verify.py about 220 lines, lint_levels.py about 160.

**P0 (must ship):**
- Screens: loading, hub with lab restoration, map, game + HUD, pause, results, wardrobe, Grimoire, daily calendar, settings with licenses, back handling.
- 4 mechanics plus gems; 18 levels passing G1–G7; hints and skip; chests; floor rewards.
- SFX and haptics; RU and EN; icon and adaptive icons; APK and AAB presets.
- Tooling: verify, lint, test_meta, smoke, screenshots.

**P1 (if time allows):**
- Familiars (Cat first), ingredients and the Slime Queen outfit, Potion of the Day, win streak.
- Music, story cards, welcome back, on-device self-test.

**P2 (update 1):** Floor 4 "Ледник" (ice blocks + frost flask), mirror floors, cauldron, notifications, cloud save, real ads and IAP.

**Cut order if over budget or behind schedule:**
1. Music
2. Story cards
3. Familiars 2–3
4. Potion of the Day
5. Ingredients
6. Streak
7. Secret Grimoire pages
8. Lab down to 6 objects
9. Outfits down to 5
10. f2_05 and f3_05 (16 levels)

**Never cut:** the verify pipeline, instant retry, hints, loading, hub restoration, map, results with a next goal, settings and back handling, SFX, daily calendar, app icon.

---

## 17. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Physics plays out differently on ARM phones than on the x86 verifier | Outcomes depend on topology and counts; two timing profiles plus jitter seeds; goals 0.6–0.7; the win-window fix; the on-device self-test before release |
| Level throughput (18 physics levels with fail orders) | Floor 1 and 2-1…2-2 need no new code, so they start at hour 0; the chamber kit; 2 level agents; order search in parallel; the 16-level cut line |
| Sieve cooling edge case | Lint warning plus the flaky-order gate; never put a water source where lava can cool inside the mesh |
| Rune circle breaks ratio goals | Absolute `pieces` / `three_star` goals on circle levels; old levels unchanged |
| Line budget overrun | Tiers and the cut order (§16); outfits are data, lab objects ≤ 25 lines of `_draw` each |
| Synthesized audio sounds cheap or slow | Short envelopes, pitch sweeps, random pitch; SFX ≤ 200 ms of CPU; music optional and cached |
| SVG rasterization quirks (ThorVG: no filters or text) | Only shapes, paths and gradients; test the 48 px render early; flask-only fallback without the hat |
| Gradle, AAB or API 36 build in the container | APK preset always works for testing; the AAB may be built locally by the owner |
| The meta swamps a 1-minute puzzle | "Next" always primary; features revealed one by one (§3.3) |
| Content runs out by about D2 for engaged players | 3★ replays feed the lab, plus ingredients, Potion of the Day, and the Golden Magister goal; update cadence of a new floor every 2–3 weeks (JSON + at most 1 mechanic) |
| Trademarks and look-alike rivals | Avoid "Hero Rescue", "Pull the Pin", "Little Alchemy", "Potion Craft", "Alchemy Stars"; real-gameplay store art |
| 12-tester / 14-day gate | Recruit testers as soon as the first AAB exists |

---

## 18. Module breakdown for parallel implementation

### 18.1 Layout and single owner per file

```
project.godot                  F0 only (autoloads, settings)          export_presets.cfg   G (after F0 sets include_filter)
scenes/main.tscn               F0 (root Node + 10-line boot script calling Router.boot())
scripts/core/game.gd           F0   autoload Game
scripts/core/loc.gd            F0   autoload Loc
scripts/core/router.gd         F0 (D may polish transitions via its own ui/transition.gd)  autoload Router
scripts/core/monetization.gd   F0   autoload Monetization
scripts/core/profile.gd        F (F0 writes compile-clean stub)       autoload Profile
scripts/core/economy.gd        F (F0 stub)                             autoload Economy
scripts/audio/synth.gd, sfx.gd, music.gd   G (F0 stub sfx.gd)         autoload Sfx
scripts/dev/dev_runner.gd      F0
scripts/level/level.gd item.gd substances.gd enemy.gd walls.gd pin.gd backdrop.gd fx.gd grate.gd transmuter.gd   A
scripts/level/hero.gd          G   (F0 adds API stubs: set_outfit, oops)
scripts/art/lab_art.gd familiar.gd logo.gd   G (F0 stubs)
scripts/ui/kit.gd icons.gd popup.gd transition.gd   D
scripts/screens/loading_screen.gd hub_screen.gd map_screen.gd   D
scripts/popups/settings_popup.gd confirm_popup.gd intro_card.gd story_card.gd floor_complete.gd   D
scripts/screens/game_screen.gd (F0 ports main.gd, then E owns)  scripts/ui/hud.gd juice.gd   E
scripts/popups/pause_popup.gd result_popup.gd chest_popup.gd   E
scripts/screens/wardrobe_screen.gd grimoire_screen.gd  scripts/popups/daily_popup.gd   F
data/catalog.json data/economy.json   F
data/strings/core.json (F0) ui.json (D) game.json (E) meta.json (F) store.json (G)   — Loc merges all files
levels/index.json              F0 (all 18 ids up front; nobody else edits)
levels/f1_*.json, f2_01, f2_02 B        levels/f2_03..f2_06, f3_*.json C        levels/test/*.json A
levels/solutions/<id>.json     generated by verify.py (one file per level, so no merge conflicts)
art/icons/*.svg D     art/app/*.svg G
tools/verify.py lint_levels.py test_levels.sh smoke.sh shots.sh   F0     tools/make_icons.gd G     tools/test_meta.gd F
docs/ARCHITECTURE.md F0 (copy of §18)   docs/LEVEL_FORMAT.md A   docs/STORE.md, docs/privacy/index.html G
```

### 18.2 Autoloads (in this order in `project.godot`)

`Loc` → `Profile` → `Game` → `Economy` → `Sfx` → `Monetization` → `Router`.

### 18.3 Public APIs (F0 creates every signature as a compile-clean stub; owners fill the bodies)

```gdscript
# Loc
signal lang_changed
func t(key: String, args: Array = []) -> String        # falls back to key
func pick(v: Variant) -> String                         # String or {ru,en}
func lang() -> String ; func set_lang(code: String) -> void   # "auto"|"ru"|"en"

# Game (catalog)
var dev: Dictionary                                     # parsed dev flags
func floors() -> Array ; func floor_of(level_id: String) -> Dictionary
func level_ids() -> PackedStringArray ; func has_level(id: String) -> bool
func level_label(id: String) -> String                  # "2-3"
func level_meta(id: String) -> Dictionary               # {id,floor,n,hard,title,relic,intro,tutorial,daily}
func load_level(id: String, mods: Dictionary = {}) -> Dictionary      # mods: {"golden": true}
func load_level_file(path: String, mods: Dictionary = {}) -> Dictionary
func winning_orders(id: String) -> Array                # solutions/<id>.json, fallback [solution]
func next_level_after(id: String) -> String             # "" if last

# Profile (state only, no rules)
signal changed(key: StringName)   # &"coins" &"hints" &"stars" &"levels" &"owned" &"equipped" &"lab" &"grimoire" &"settings" &"daily"
var volatile := false             # dev/verify runs never write to disk
func load() -> void ; func save() -> void               # debounced 0.5 s, atomic
func coins() -> int ; func add_coins(n: int, reason: String) -> void ; func spend_coins(n: int, reason: String) -> bool
func hints() -> int ; func add_hints(n: int) -> void ; func spend_hint() -> bool
func best_stars(id: String) -> int ; func is_cleared(id: String) -> bool ; func is_unlocked(id: String) -> bool
func record_result(id: String, stars: int, skipped := false) -> Dictionary   # {first_clear, new_stars}
func stars_total() -> int ; func stars_wallet() -> int ; func spend_stars(n: int) -> bool
func current_level_id() -> String
func fails(id: String) -> int ; func add_fail(id: String) -> void ; func reset_fails(id: String) -> void
func has_relic(level_id: String) -> bool ; func add_relic(level_id: String) -> void
func owns(item_id: String) -> bool ; func grant(item_id: String) -> void
func equipped(slot: StringName) -> String ; func equip(slot: StringName, item_id: String) -> void   # &"outfit" &"familiar"
func lab_restored(obj_id: String) -> bool ; func mark_restored(obj_id: String) -> void
func grimoire_has(page_id: String) -> bool ; func grimoire_add(page_id: String) -> bool
func setting(key: StringName) -> Variant ; func set_setting(key: StringName, v: Variant) -> void
func flag(key: String) -> bool ; func set_flag(key: String, v := true) -> void
func today() -> String            # local "YYYY-MM-DD"; var fake_today for tests
func stat_inc(path: String, n := 1) -> void

# Economy (rules; reads data/economy.json + data/catalog.json; mutates Profile)
signal granted(breakdown: Dictionary)
func level_reward(level_id: String, result: Dictionary, mods: Dictionary = {}) -> Dictionary
   # result: {won,stars,pieces,pieces_total,coins_pieces,gems,relic,first_try}
   # returns {lines:[{key,amount}], total, new_stars, first_clear, chest_ready, streak, floor_completed, grants:[]}
func level_lost(level_id: String, reason: String) -> void
func chest_progress() -> Vector2i ; func open_chest() -> Dictionary
func outfit(id: String) -> Dictionary ; func outfits() -> Array ; func familiars() -> Array
func price(item_id: String) -> int ; func buy(item_id: String) -> bool ; func unlock_reason(item_id: String) -> String
func lab_objects() -> Array ; func next_restore() -> String ; func can_restore(obj_id: String) -> bool ; func restore(obj_id: String) -> Dictionary
func hint_cost(level_id: String) -> Dictionary          # {free:bool, potions:int, coins:int}
func take_hint(level_id: String) -> bool
func can_skip(level_id: String) -> bool ; func skip(level_id: String) -> bool
func daily_state() -> Dictionary ; func claim_daily() -> Dictionary
func potion_of_day() -> Dictionary                      # {available, level_id, done_today}
func discover_from_event(id: StringName, info: Dictionary) -> Array   # newly discovered page ids (coins granted)
func badges() -> Dictionary                             # {lab,wardrobe,daily,grimoire}: bool
func on_app_open() -> Array                             # owl hint, welcome back → toasts

# Sfx
func prepare(budget_ms: int) -> bool                    # call each loading frame until true
func play(id: StringName, semitones := 0.0, volume_db := 0.0) -> void
func haptic(ms: int) -> void
func set_music(on: bool) -> void

# Monetization — see §14.

# Router
signal screen_changed(name: StringName)
func boot() -> void                                     # dev flags → DevRunner, else loading
func go(screen: StringName, args := {}) -> void         # replace stack
func push(screen: StringName, args := {}) -> void ; func back() -> void
func popup(name: StringName, args := {}) -> Node        # node emits closed(result)
func toast(text: String, icon: StringName = &"") -> void
# Screen contract: any Node with open(args: Dictionary); optional on_back() -> bool (true = handled).
# Registry: const SCREENS / POPUPS: StringName -> script path.

# Level (A)
signal won(stars: int) ; signal lost(reason: String)
signal gold_changed(collected: int, needed: int, total: int) ; signal pin_pulled(pin: Pin)
signal reaction(id: StringName, pos: Vector2, info: Dictionary)
signal collected(kind: StringName, pos: Vector2)        # &"coin" &"gem" &"relic"
var jitter_seed := 0 ; var hero_outfit: Dictionary ; var familiar_kind: StringName
func build(data: Dictionary) -> void
func pull_pin(pin: Pin) -> void ; func pin_by_id(id: String) -> Pin ; func pulled_ids() -> PackedStringArray
func set_hint_pin(pin_id: String) -> void               # "" clears; Pin draws ring + hand
func result() -> Dictionary                             # {stars,pieces,pieces_total,coins_pieces,gems,relic,reason}

# GameScreen (E)
signal level_ready(level: Level) ; signal level_finished(result: Dictionary)
var level: Level
func open(args: Dictionary) -> void                     # {id, mods, dev:bool}
func restart() -> void

# Hero (G)        Mood {IDLE, SCARED, HAPPY, OOPS}
func setup(pos: Vector2, with_body := true) -> void ; func set_outfit(o: Dictionary) -> void
func set_scared(v: bool) ; func bounce() ; func celebrate() ; func oops(reason: String)   # die() kept as alias
# Familiar (G):  func setup(kind: StringName) ; func react(what: StringName)   # &"win" &"danger" &"idle" &"oops"
# LabArt (G):    static func draw_room(ci: CanvasItem, size: Vector2) ; static func draw_object(ci, obj_id: StringName, rect: Rect2, state: int, t: float)  # BROKEN|GHOST|RESTORED
#                const SLOTS: Dictionary (§7.1 rects)
# Logo (G):      extends Control; var progress := -1.0 (≥0 = loading fill)
# UiKit (D):     static button(text, style:=&"primary", icon:=&"") ; icon_button(icon, badge:="") ; label(text, size:=36) ;
#                panel(style:=&"glass") ; pill(icon) (set_value with count-up) ; star_row(n, size) ; progress_bar() ;
#                toggle(text, value, cb) ; red_dot() ; fly_coins(from: Vector2, to: Control, n: int) ; count_up(label, a, b, dur)
# Icons (D):     static func tex(name: StringName, px := 64) -> Texture2D
```

### 18.4 Data contracts

**Reaction events** (`Level.reaction` id → info):

| Event id | info | Emitted when |
|---|---|---|
| `&"steam"` | {} | Water + lava |
| `&"stone"` | {n} | Each solidify; n = current chain length |
| `&"wave_end"` | {n} | The cooling queue empties |
| `&"slime_pop"` | {enemy, killer} | Enemy killed |
| `&"acid_stone"` | | Acid dissolves stone |
| `&"dilute"` | | Water dilutes acid |
| `&"grate_hit"` | {hp} | Acid drop on a grate |
| `&"grate_break"` | | Grate dissolves |
| `&"magma_bath"` | | Magma slime first touches lava |
| `&"transmute"` | | Stone becomes gold in a circle |
| `&"noble_gold"` | | Acid touches gold; once per level |

Pin pulls stay on `pin_pulled`. The Grimoire mapping lives in `catalog.json`: `{"id": "lava_slime", "event": "slime_pop", "when": {"killer": "lava", "enemy": "slime"}}` or `{"event": "wave_end", "min_n": 15}`.

**Save v2** (`user://save.json`; written to `save.tmp`, the old file copied to `save.bak`, then renamed; on a parse failure load `.bak`; migrate `progress.cfg` index 0 → `f1_05`):

```json
{"v": 2, "coins": 0, "hints": 3, "stars_spent": 0,
 "levels": {"f1_01": {"stars": 3, "cleared": true, "skipped": false, "relic": false}},
 "fails": {}, "streak": 0, "chest": 0,
 "owned": ["apprentice"], "equipped": {"outfit": "apprentice", "familiar": ""},
 "lab": [], "grimoire": [],
 "daily": {"slot": 0, "cycle": 0, "last_claim": "", "potion_done": "", "owl_last": ""},
 "last_open": "", "flags": {},
 "settings": {"sfx": true, "music": true, "vibration": true, "lang": "auto", "low_fx": false},
 "stats": {}}
```

**Dev CLI** (`DevRunner`; `Profile.volatile = true`; no audio or loading screen):

| Flag | Meaning |
|---|---|
| `--level=<id or index>`, `--file=<res path>` | Level to open |
| `--autoplay`, `--pins=a,b,c`, `--all-at-once` | Pull order |
| `--interval=<sec>` or `--interval=settle` | Pull timing |
| `--jitter=<seed>` | ±1 px spawns and ±15% delays |
| `--mods=golden` | Golden Rush |
| `--json` | Machine-readable output |
| `--screen=<hub, map, wardrobe, grimoire, daily, settings, result, promo>` | Open a screen for screenshots |
| `--shot=path.png@sec` | Save a screenshot |
| `--smoke` | Run the smoke flow |

`--json` prints one line: `RESULT_JSON {"level":"f2_03","order":[...],"won":true,"reason":"","stars":3,"pieces":20,"total":22,"relic":true,"t":6.2}`. The legacy `RESULT: WON …` line is kept for `test_levels.sh`.

### 18.5 Phases and agents

| Phase | Agent | Delivers | Can start |
|---|---|---|---|
| 0 | **F0 Foundation** | autoload stubs with final signatures; Game, Loc, Router, Monetization, DevRunner; main.gd split into game_screen.gd; index v2; `level_001` → `f1_05` with `fails`; verify.py, lint, smoke and shots scripts; docs/ARCHITECTURE.md; `include_filter`. **Merge before anyone else.** | Immediately |
| 1 | **A Mechanics** | In order: (1) event bus, `result()`, win window, zero-gold fix, jitter, hint pin, `oops` call; (2) magma; (3) grate; (4) sieve; (5) circle + absolute goals; (6) gem + relic; (7) floor themes. Each step with a `levels/test/t_*.json` passing the gates. | After F0 |
| 1 | **B Levels I** | f1_01…f1_06, f2_01, f2_02 (relics added after A step 6) | After F0 |
| 1 | **C Levels II** | f2_03…f2_06, f3_01…f3_06, each as its mechanic lands; paper sketches before that | After F0 |
| 1 | **D Shell UI** | UiKit, icons + SVGs, loading, hub (uses the LabArt/Hero/Logo stubs), map, settings, confirm, intro card, story card, floor complete, transitions | After F0 |
| 1 | **E Game UX** | game_screen, HUD, Juice (sound, haptic and discovery wiring), hint flow, pause, result win/lose, chest, FTUE hand | After F0 |
| 1 | **F Meta** | Profile, Economy, catalog.json, economy.json, wardrobe, Grimoire, daily, test_meta.gd | After F0 |
| 1 | **G Art, Audio, Store** | hero outfits and expressions, familiars, lab art (9 objects × 3 states), logo, synth and SFX (+ music P1), app SVGs + make_icons, export presets (APK + AAB), STORE.md, privacy page | After F0 |
| 2 | **Integrator** | FTUE flags and progressive reveal; badges; full verify of 18 levels and test levels; test_meta; smoke; screenshots of every screen and level reviewed; APK 1.0.0 build; AAB if the SDK allows | After Phase 1 merges |

### 18.6 Rules for agents

1. **Edit only files you own.** Need an API change? Add a new function in your own file, or ask the Integrator. Never change a signature from §18.3 on your own.
2. `project.godot` and `levels/index.json` are F0 and Integrator only. Strings go in your own `data/strings/<module>.json` with a key prefix (`ui.`, `game.`, `meta.`, `store.`).
3. Headless-safe code:
   - no audio or haptics when `DisplayServer.get_name() == "headless"`;
   - no await on rendering in the game path;
   - `Profile.volatile` during dev runs.
4. Never use `Engine.time_scale`, physics impulses from effects, or randomness that affects physics except `jitter_seed`.
5. Before merging, pass `tools/lint_levels.py`, `tools/verify.py` (changed levels, or all levels if `scripts/level/` changed), `tools/test_meta.gd`, and `tools/smoke.sh`, with no `SCRIPT ERROR` in stderr.

### 18.7 Definition of done (v1.0 build)

- All 18 levels pass G1–G7.
- test_meta passes and smoke passes.
- Screenshots of every screen and level have been reviewed by an agent.
- The APK installs, cold start is ≤ 3 s, and it runs at 60 fps in levels on the owner's phone.
- The on-device self-test passes (P1).
- The store checklist in §15 is completed, except the owner-only items (keystore, Play account, testers).

---

## 19. Decisions needed from the owner

1. **Name:** the default is «Зелья и засовы / Pins & Potions» (§2). Or pick any option 2–8.
2. **Package id** (permanent), e.g. `com.crownfall90.pinspotions`.
3. **Heroine name:** Мирра / Mirra (default), or Мия / Mia.
4. **Play target audience:** 13+ (recommended) or including children (Families policy).
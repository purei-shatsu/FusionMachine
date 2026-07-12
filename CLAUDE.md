# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Solar2D (formerly Corona) Lua game that recreates the fusion mechanic of *Yu-Gi-Oh! Forbidden Memories* (PS1). Landscape mobile, single scene, no scene manager.

It ships **two games on one engine** — Yu-Gi-Oh! on the modern TCG card pool, and a Digimon TCG version. They share the entire turn/fusion/battle/AI loop and all animations, and differ only in what a card *is* and which card a given A+B fuses into. See "Game modes" below.

## Running and building

There is no CLI build/test/lint setup. Open the repo root in the **Solar2D Simulator**; it runs `main.lua`. `build.settings` (orientation, platform excludes) and `config.lua` (768×1024 letterbox, 60fps) are the standard Corona entry points.

Solar2D globals (`display`, `transition`, `timer`, `audio`, `easing`, `native`, `system`, `Runtime`, `sqlite3`) are ambient — never required.

Two flags at the top of [main.lua](main.lua):
- `gameMode` — `"yugioh"` or `"digimon"`.
- `generateImages` — `true` runs [ImageGenerator.lua](ImageGenerator.lua) instead of the game. It renders a `CardView` per row of `cards.cdb` and `display.save`s it to `pics/<id>.jpg` in the **Documents** directory (must be copied back into `pics/` manually). Yu-Gi-Oh only; the Digimon art is prepared offline by `tools/convert_art.py`.

Tests: only the `Utils` submodule has a suite ([Utils/spec/Tests_spec.lua](Utils/spec/Tests_spec.lua), busted). Run `busted` from inside `Utils/`. The game itself has no tests.

## Submodules

`.gitmodules` declares `Utils` and `EventSystem` (both from gitea.yfrit.com). **`EventSystem` is not checked out** — [OldEventSystem/](OldEventSystem/) is a vendored older copy that the game deliberately uses instead (commit "Force using old event system for compatibility"). Require it as `OldEventSystem.Event` / `OldEventSystem.Eventer`, never `EventSystem.*`.

## Core infrastructure (read these before touching anything else)

**SmartRequire** ([Utils/SmartRequire.lua](Utils/SmartRequire.lua), installed by `main.lua`) monkey-patches `_G.require` with two behaviors:
1. A second argument rewrites the path relative to the caller's module — `require("Event", ...)` inside `OldEventSystem/src/Eventer.lua` resolves to `OldEventSystem.Event`. This is how submodules require their own siblings without knowing their mount point.
2. On failure it retries with `.src.` inserted after the first dot, so `OldEventSystem.Event` finds `OldEventSystem/src/Event.lua`.

**Class** ([Utils/Class.lua](Utils/Class.lua)): `Class.new(defaultsTable, constructor, parent)`. The first table becomes both the class table and the instance metatable's `__index`, so fields declared there are *class-level defaults/constants* (e.g. `CardView.width`, `Game.aiDifficulty`). Instantiate with `Foo:new(...)`. The parent constructor runs before the child's, with the same arguments.

**Event bus** ([OldEventSystem/src/Event.lua](OldEventSystem/src/Event.lua)): a single global, hierarchical event tree. `Event.broadcast("FieldSpace", "Clicked", side, position)` also fires listeners registered on the prefix `{"FieldSpace"}` and on `{}`. Listeners receive the *entire* broadcast argument list, event names included — hence the `_` placeholders in `Game`'s listener table:

```lua
FieldSpace = {
    Clicked = function(self, _, _, ...)   -- self, "FieldSpace", "Clicked", side, position
```

**Eventer** ([OldEventSystem/src/Eventer.lua](OldEventSystem/src/Eventer.lua)): pass it as the `parent` to `Class.new` and declare a `listeners.events` (and/or `listeners.requests`) tree in the class defaults; the constructor walks it and registers everything with `self` bound. `Game` is the only Eventer; views broadcast, `Game` listens.

**Coroutines drive all sequencing.** Turn logic runs inside `coroutine.wrap`. `Transition.to(obj, params, wait)` ([Transition.lua](Transition.lua)) with `wait = true` yields the running coroutine and resumes it in `onComplete` — that is the only way to await an animation, and it errors outside a coroutine. `Animator` builds long sequences by accumulating a module-level `delay` counter across `transition.to` calls and yielding on a shared `resumeCoroutine` upvalue.

Globals in play: `IS_PLAYER_TURN` (set in `Game:runPlayerTurn`/`runAITurn`, gates all touch input in `CardView:touch`), `permutations(t, min, max)` and `printR` (both defined globally by [Utils/Utils.lua](Utils/Utils.lua)).

## Game modes

[main.lua](main.lua) calls `GameMode.set(gameMode)` **before requiring anything else**, because a rules module opens its database as a side effect of being loaded.

[GameMode.lua](GameMode.lua) resolves `rules()` to [YugiohRules.lua](YugiohRules.lua) or [DigimonRules.lua](DigimonRules.lua). That is the *only* seam. Each rules module owns its `.cdb`, its SQL, and its card model, and answers exactly three questions:

- `drawCards(amount)` — the random hand pull
- `getFusionResult(a, b)` — one pairwise fusion, or `nil` when the pair fuses into nothing
- `compareStats(a, b)` — `1 | -1 | 0`, which of two fusion results the AI prefers

The card models ([YugiohCardModel.lua](YugiohCardModel.lua), [DigimonCardModel.lua](DigimonCardModel.lua)) extend [CardModel.lua](CardModel.lua), which only holds the raw row. They share **no** database columns, so they meet on five methods and the rest of the game knows only those: `getId`, `getName`, `getPower` (the single stat that decides battles — atk or DP), `getImagePath`, `getDisplayText` (the two lines [CardText.lua](CardText.lua) paints over the art). Anything beyond that is read only by that mode's own Rules (`getLevel`/`getColors`/`getTraits` on the Digimon side, `getRace`/`getAttribute` on the Yu-Gi-Oh one).

Everything else is mode-agnostic and must stay that way: `Game`, `FusionProcessor`, `Animator`, `CardView`, `CardText`, `CardLocator`, `Camera`, `FieldSpace`. `FusionProcessor.performFusion` owns the *chain* (left-to-right, each result feeding the next as material A; a failed step falls through to material B, which `Animator` detects by model identity) and delegates each pairwise step to the rules.

[Database.lua](Database.lua) is a factory — `Database.open(filename)` — not a singleton.

**AI** (`Game:_playAIFusion`): brute-forces `permutations(hand, 1, aiDifficulty)`, optionally prepending a field card to overwrite it, and scores candidates with `_isFusionBetter` (`Rules.compareStats` → prefers not replacing → prefers more materials). `aiDifficulty` ratchets upward with the card-count deficit and never decreases.

### Yu-Gi-Oh rules

[cards.cdb](cards.cdb) is a YGOPro-format SQLite DB — `datas(id, type, atk, def, level, race, attribute, ...)` joined to `texts(id, name, desc, ...)`. [filter.sql](filter.sql) records the pruning already applied (aliases, non-monsters, `?` atk/def removed). `race` and `attribute` are bitflags; the names live in [YugiohCardModel.lua](YugiohCardModel.lua).

`forbiddenMemoriesIds` (in `YugiohRules`) is the ~700-id FM card pool, spliced into queries as an `in (...)` clause. **Draws** are restricted to it; **fusion results** are not — the query has `(d.id in (%s) or 1=1)`, where the `or 1=1` intentionally disables the restriction. Delete `or 1=1` to confine results to the FM pool.

The fusion rule *is* the SQL in `YugiohRules.getFusionResult`: pick the card whose race comes from one material and attribute from the other, with `atk <= defA + defB` and atk (or atk+def) strictly beating both materials, ordered by atk/def/id.

[TODO.txt](TODO.txt) (Portuguese) holds the current design backlog and the house rules that deviate from Forbidden Memories.

### Digimon rules

Draws are **level-3 Digimon only**, restricted to `card_kind = 0` (and to `drawSets`, when that list is non-empty). Cards with **no art are deliberately still played**: `display.newImageRect` returns nil for the missing `digimon_pics/<id>.jpg`, and `CardView:_createImage` stands a white rectangle in for it and prints the card's name, so a gap in the art is visible and named rather than silently shrinking the pool. Fusing A + B:

- `level(C) = max(level(A), level(B)) + 1`
- C shares a **trait** with one material and a **colour** with the other
- ordered by newest set (`sets.release_order`) desc, then `card_id`

C may carry colours **neither material has** — Impmon (Purple/Red) + Sunarizamon (Black) fuses into Tyrannomon (Red/Green), taking Red from the first and `Dinosaur` from the second, and its Green is free. An earlier rule required every colour of C to come from A or B; it was dropped because it rejected exactly this kind of pair.

Every condition is symmetric, so the fusion is commutative and deterministic by construction — do not add tie-breaking that reads A and B asymmetrically. DP plays **no part** in the rule, so a result can have lower DP than its materials. Levels top out at 7, so a level-7 material asks for a level-8 result, finds none, and always fails — that is the chain cap, and it is why no explicit cap exists.

A card has **up to two traits**: the first two distinct groups among its `card_types`, in `ord` order (824 of the 3,183 Digimon have two). Two vocabularies live in `card_types` — *typings* (Beast, Cyborg, Ice-Snow), which are always the `ord = 0` type on every Digimon, and *affiliations* (Royal Knight, Xros, X-Antibody), which only ever appear at `ord >= 1`. [DigimonTraits.lua](DigimonTraits.lua) groups DCGO's 205 raw traits into **46** of both kinds, because the raw traits are far too fine-grained to fuse on (Mini Dragon, Dragonkin and Beast Dragon are all `Dragon`; Reptile is folded into `Dinosaur`, being the Agumon→Greymon line; the Appmon function traits — Search, Zip, Online, Reboot — are all `App`; the ten D-Reaper `*Agent` traits are all `Demon`), and the rule compares *groups*.

The rest is **slop**, listed explicitly in the same module and skipped. Two kinds: product markers (`LIBERATOR`, `TS`, `CS`, `DM`…) that say which set a card came from rather than what it is — fusing on them would mean every EX11 card fuses with every other EX11 card — and affiliations that can never fire, because a result is always one level *above* both materials, so a group whose cards all sit at one level (`Deva`, `Ten Warriors`, `Dark Masters`…) can never be the trait they share. `Royal Base`, `Chronicle` and `DigiPolice` are slop for a subtler version of the same thing: the two-trait cap crowds them out of every card that carries them. So Coronamon (Beast/Light Fang/TS) is `Beast` + `Galaxy`. **Every raw trait must be in exactly one of the two tables**: one that is in neither maps to `nil` and blows up, rather than being silently bucketed into the wrong group *or* silently dropped.

The trait grouping cannot live in the database — it is a rule, and rules live in `DigimonRules`. But SQL has to filter on it, so `DigimonRules.buildTraitIndex` resolves every Digimon through `DigimonTraits` once at module load into a **`temp` table `card_traits`**, which the fusion query then joins against. That is also where an unknown trait errors out.

The trait rule is what makes fusion able to fail: measured over sampled same-level pairs, level-3 pairs fuse 99% of the time, level-4 98%, level-5 99%, level-6 91% — level 7 has just 100 cards, so chains still thin out at the top. A failed step is not an error; `FusionProcessor` falls through to material B.

## The Digimon database

[digimon.cdb](digimon.cdb) holds 4,284 cards (3,183 Digimon, 524 Option, 332 Tamer, 245 DigiEgg) across 67 sets, generated by [tools/dcgo_import.py](tools/dcgo_import.py) from [DCGO](https://github.com/DCGO2), a Unity Digimon TCG simulator at `D:\Git\DCGO`. It stores one Unity YAML `.asset` per card under `DCGO/Assets/CardBaseEntity/<Set>/<Color>/<Kind>/`.

Schema in [tools/schema.sql](tools/schema.sql). It is **deliberately Digimon-native, not the YGO `datas`/`texts` shape** — nothing is squeezed into `atk`/`def`/`race`/`attribute`, so the rule design stays unconstrained. `cards` carries level, dp, play_cost, rarity, memory/link fields and the three effect texts; child tables carry the genuinely multi-valued fields (`card_colors`, `card_kinds`, `card_types`, `card_forms`, `card_attributes`) plus `card_evo_costs` — the structured `{from_color, from_level, memory_cost}` digivolution requirements, still unused by the game.

`sets(set_code, release_order, release_date)` exists because **nothing in the DCGO assets carries a date**, and `rowid` is useless (the importer walks folders alphabetically, so BT10 lands before BT2). It is populated from the hand-maintained `SET_RELEASES` map in the importer, sourced from <https://en.digimoncard.com/products/>. The importer **errors** if a card's set has no entry there, so a new DCGO set cannot silently sort wrong. The undated promo lines (`P`, `LM`) get `release_order = 0` and lose every recency tie.

Re-run `python tools/dcgo_import.py` whenever DCGO ships a new set (needs PyYAML). It is incremental and idempotent: each row keeps the sha1 of its source `.asset`, so only new/changed cards are touched. Deletions require an explicit `--prune`, so a half-synced DCGO checkout cannot silently wipe rows.

Card art: `python tools/convert_art.py` (needs Pillow) converts the 430×601 `.webp` in `D:\Downloads\DCGO_Application\Assets\Textures\Card` into `digimon_pics/<card_id>.jpg`, because Solar2D's `display.newImageRect` cannot load webp. It is idempotent (skips existing files; `--force` to redo). **`digimon_pics/` is gitignored** — ~350 MB, regenerate it rather than committing it.

Non-obvious facts about the source data, all learned the hard way:
- `cardColors` and `cardKind` are hex int-array blobs and **must not go through YAML** — `01000000` matches YAML 1.1's octal rule and silently becomes 262144. The importer regexes both out of the raw text (`int_blob`). Colours decode as `0=Red 1=Blue 2=Yellow 3=Green 4=White 5=Black 6=Purple`, derived by majority vote against the `<Color>` folders because DCGO's `Assets/Scripts` submodule (which defines the C# enums) is not cloned.
- One card, `EX12_021_P1`, has a bare `=` in `dualEffect` (every other card has a name or `'-'`). That is YAML 1.1's reserved *value* tag, which `SafeLoader` has no constructor for, so it kills the whole parse — the importer registers one that keeps it a plain string. The game never reads the field.
- Stage and attribute look single-valued but aren't: 67 cards have two forms (BT18-102 is Mega *and* Hybrid), 5 have two attributes (BT16-102 is Vaccine *and* Free), and types run up to six. Hence the child tables.
- 21 Digimon genuinely have **no level** (Calumon, the D-Reaper `ADR-xx` agents, Eater) — level-based rules must expect `level = 0`. They never reach play today, since draws are level 3 and fusion asks for `max + 1`.
- `cardKind` is authoritative, the folder name is not (the DigiEgg `BT1_002` is filed under `Red/Digimon`). It is also **multi-valued**: BT25/EX12 ship 9 dual cards that are a Digimon with an Option side (Siriusmon EX12-018 is `[0, 2]`), hence `card_kinds`. `cards.card_kind` keeps the *first* kind, which is always the primary nature — a dual card is a Digimon that also has an Option side, never the reverse — so the game's `card_kind = 0` filter still draws and fuses them as Digimon. Alt-art printings (`_P0`/`_P1` assets) keep the base `CardID` and differ only in `CardSpriteName`, so they merge on `CardID`.
- Some fields are simply **wrong in DCGO**, and `CARD_FIXES` in the importer overrides them by `CardID`. It covers three defects: (a) values that are **not types at all leak into `Type_ENG`**. On six cards `Type_ENG` and `Attribute_ENG` are outright **swapped** — P-059 is typed "Virus" with attribute "Ceratopsian", and EX11-011 has its attribute leaking into the front of its type list; the Japanese fields say the opposite, and without the fix "Virus" and "Vaccine" show up as traits. Two more leak further down the list, which only matters now that the game reads past `ord = 0`: BT17-077 is `[Ancient Holy Warrior, **Free**]` (an attribute) and EX12-076 ends in `**Hybrid**` (a form). They are found by querying for any type that is also a known attribute or form name, since a trait can never be Vaccine/Data/Virus/Free or Mega/Hybrid. (b) EX11-009, EX11-010 and EX11-047 ship with **`DP` and `PlayCost` zeroed out** (the rest of EX-11 is fine), so MasterTyrannomon fought at 0 power. Nothing can detect that automatically — DP 0 is legal, and BT18-086 Lucemon: Larva really is a 0 DP card — so the values come from the official card list. (c) three EX-11 cards have **wiki scrape leftovers** in place of their name (`[[:Category:|]]`), and one of them, EX11-074 Vortexdramon, also has `???` as its first type, which made it fuse into nothing since no trait group contains `???` — it is really a Bird Dragon. The other two are Tamers the game never loads. A card's `source_hash` mixes in its `CARD_FIXES` entry, so editing the map re-imports exactly the cards it names instead of skipping them as unchanged.
- Only 4,227 of the 4,284 cards have art (`cards.has_art` / `cards.image_file`) — the rest are sets DCGO ships assets for but no textures. The game no longer filters on `has_art`, so a drawn card without art shows as a white rectangle and logs its name. `has_art` is a fact about the *art folder*, not about the `.asset`, so the importer's source_hash skip cannot see it change: `refresh_art` re-stamps `has_art`/`image_file` on **every** row each run, imported or not. Without that, art downloaded after a card's first import would never be picked up.
- Levels: 3 → 745, 4 → 847, 5 → 745, 6 → 725, 7 → 100. Colours: 3,342 cards are mono, 906 dual, only 36 tri-colour.

## Style

4-space indent, no semicolons, camelCase, `_privateMethod` prefix for internals, lowercase `--comments`. Lua tables are formatted one-field-per-line (lua-format style). Keep it consistent with surrounding code.

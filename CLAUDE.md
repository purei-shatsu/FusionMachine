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

The card models ([YugiohCardModel.lua](YugiohCardModel.lua), [DigimonCardModel.lua](DigimonCardModel.lua)) extend [CardModel.lua](CardModel.lua), which only holds the raw row. They share **no** database columns, so they meet on five methods and the rest of the game knows only those: `getId`, `getName`, `getPower` (the single stat that decides battles — atk or DP), `getImagePath`, `getDisplayText` (the two lines [CardText.lua](CardText.lua) paints over the art). Anything beyond that is read only by that mode's own Rules.

Everything else is mode-agnostic and must stay that way: `Game`, `FusionProcessor`, `Animator`, `CardView`, `CardText`, `CardLocator`, `Camera`, `FieldSpace`. `FusionProcessor.performFusion` owns the *chain* (left-to-right, each result feeding the next as material A; a failed step falls through to material B, which `Animator` detects by model identity) and delegates each pairwise step to the rules.

[Database.lua](Database.lua) is a factory — `Database.open(filename)` — not a singleton.

**AI** (`Game:_playAIFusion`): brute-forces `permutations(hand, 1, aiDifficulty)`, optionally prepending a field card to overwrite it, and scores candidates with `_isFusionBetter` (`Rules.compareStats` → prefers not replacing → prefers more materials). `aiDifficulty` ratchets upward with the card-count deficit and never decreases.

### Yu-Gi-Oh rules

[cards.cdb](cards.cdb) is a YGOPro-format SQLite DB — `datas(id, type, atk, def, level, race, attribute, ...)` joined to `texts(id, name, desc, ...)`. [filter.sql](filter.sql) records the pruning already applied (aliases, non-monsters, `?` atk/def removed). `race` and `attribute` are bitflags; the names live in [YugiohCardModel.lua](YugiohCardModel.lua).

`forbiddenMemoriesIds` (in `YugiohRules`) is the ~700-id FM card pool, spliced into queries as an `in (...)` clause. **Draws** are restricted to it; **fusion results** are not — the query has `(d.id in (%s) or 1=1)`, where the `or 1=1` intentionally disables the restriction. Delete `or 1=1` to confine results to the FM pool.

The fusion rule *is* the SQL in `YugiohRules.getFusionResult`: pick the card whose race comes from one material and attribute from the other, with `atk <= defA + defB` and atk (or atk+def) strictly beating both materials, ordered by atk/def/id.

[TODO.txt](TODO.txt) (Portuguese) holds the current design backlog and the house rules that deviate from Forbidden Memories.

### Digimon rules

Draws are **level-3 Digimon only**. Cards are restricted to `card_kind = 0` and `has_art = 1` everywhere — a card with no art does not exist in the game. Fusing A + B:

- `level(C) = max(level(A), level(B)) + 1`
- every colour of C comes from A or B (no new colour may appear)
- C shares at least one colour with A **and** at least one with B
- ordered by colour count desc, then newest set (`sets.release_order`) desc, then `card_id`

All three conditions are symmetric, so the fusion is commutative and deterministic by construction — do not add tie-breaking that reads A and B asymmetrically. DP plays **no part** in the rule, so a result can have lower DP than its materials. Levels top out at 7, so a level-7 material asks for a level-8 result, finds none, and always fails — that is the chain cap, and it is why no explicit cap exists. In practice fusions almost never fail: all 1,770 pairs of a 60-card level-3 sample produced a result.

## The Digimon database

[digimon.cdb](digimon.cdb) holds 4,018 cards (2,994 Digimon, 481 Option, 310 Tamer, 233 DigiEgg) across 59 sets, generated by [tools/dcgo_import.py](tools/dcgo_import.py) from [DCGO](https://github.com/DCGO2), a Unity Digimon TCG simulator at `D:\Git\DCGO`. It stores one Unity YAML `.asset` per card under `DCGO/Assets/CardBaseEntity/<Set>/<Color>/<Kind>/`.

Schema in [tools/schema.sql](tools/schema.sql). It is **deliberately Digimon-native, not the YGO `datas`/`texts` shape** — nothing is squeezed into `atk`/`def`/`race`/`attribute`, so the rule design stays unconstrained. `cards` carries level, dp, play_cost, rarity, memory/link fields and the three effect texts; child tables carry the genuinely multi-valued fields (`card_colors`, `card_types`, `card_forms`, `card_attributes`) plus `card_evo_costs` — the structured `{from_color, from_level, memory_cost}` digivolution requirements, still unused by the game.

`sets(set_code, release_order, release_date)` exists because **nothing in the DCGO assets carries a date**, and `rowid` is useless (the importer walks folders alphabetically, so BT10 lands before BT2). It is populated from the hand-maintained `SET_RELEASES` map in the importer, sourced from <https://en.digimoncard.com/products/>. The importer **errors** if a card's set has no entry there, so a new DCGO set cannot silently sort wrong. The undated promo lines (`P`, `LM`) get `release_order = 0` and lose every recency tie.

Re-run `python tools/dcgo_import.py` whenever DCGO ships a new set (needs PyYAML). It is incremental and idempotent: each row keeps the sha1 of its source `.asset`, so only new/changed cards are touched. Deletions require an explicit `--prune`, so a half-synced DCGO checkout cannot silently wipe rows.

Card art: `python tools/convert_art.py` (needs Pillow) converts the 430×601 `.webp` in `D:\Downloads\DCGO_Application\Assets\Textures\Card` into `digimon_pics/<card_id>.jpg`, because Solar2D's `display.newImageRect` cannot load webp. It is idempotent (skips existing files; `--force` to redo). **`digimon_pics/` is gitignored** — ~350 MB, regenerate it rather than committing it.

Non-obvious facts about the source data, all learned the hard way:
- `cardColors` is a hex int-array blob and **must not go through YAML** — `01000000` matches YAML 1.1's octal rule and silently becomes 262144. The importer regexes it out of the raw text. Decoded: `0=Red 1=Blue 2=Yellow 3=Green 4=White 5=Black 6=Purple`, derived by majority vote against the `<Color>` folders because DCGO's `Assets/Scripts` submodule (which defines the C# enums) is not cloned.
- Stage and attribute look single-valued but aren't: 75 cards have two forms (BT18-102 is Mega *and* Hybrid), 14 have two attributes (BT16-102 is Vaccine *and* Free), and types run up to six. Hence the child tables.
- 21 Digimon genuinely have **no level** (Calumon, the D-Reaper `ADR-xx` agents, Eater) — level-based rules must expect `level = 0`. They never reach play today, since draws are level 3 and fusion asks for `max + 1`.
- `cardKind` is authoritative, the folder name is not (the DigiEgg `BT1_002` is filed under `Red/Digimon`). Alt-art printings (`_P0`/`_P1` assets) keep the base `CardID` and differ only in `CardSpriteName`, so they merge on `CardID`.
- Only 3,276 of the 4,018 cards have art (`cards.has_art` / `cards.image_file`), which is why every gameplay query filters on `has_art = 1`. That still leaves 581 level-3 Digimon to draw from.
- Levels: 3 → 701, 4 → 801, 5 → 701, 6 → 677, 7 → 93. Colours: 3,200 cards are mono, 792 dual, only 24 tri-colour.

## Style

4-space indent, no semicolons, camelCase, `_privateMethod` prefix for internals, lowercase `--comments`. Lua tables are formatted one-field-per-line (lua-format style). Keep it consistent with surrounding code.

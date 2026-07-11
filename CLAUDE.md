# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Solar2D (formerly Corona) Lua game that recreates the fusion mechanic of *Yu-Gi-Oh! Forbidden Memories* (PS1) on top of the modern TCG card pool. Landscape mobile, single scene, no scene manager.

## Running and building

There is no CLI build/test/lint setup. Open the repo root in the **Solar2D Simulator**; it runs `main.lua`. `build.settings` (orientation, platform excludes) and `config.lua` (768×1024 letterbox, 60fps) are the standard Corona entry points.

Solar2D globals (`display`, `transition`, `timer`, `audio`, `easing`, `native`, `system`, `Runtime`, `sqlite3`) are ambient — never required.

Two run modes, toggled by `generateImages` at the top of [main.lua](main.lua):
- `false` — normal game.
- `true` — runs [ImageGenerator.lua](ImageGenerator.lua), which renders a `CardView` per database row and `display.save`s it to `pics/<id>.jpg` in the **Documents** directory (must be copied back into `pics/` manually).

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

## Data and game rules

[cards.cdb](cards.cdb) is a YGOPro-format SQLite DB — `datas(id, type, atk, def, level, race, attribute, ...)` joined to `texts(id, name, desc, ...)`. [Database.lua](Database.lua) opens it once and is queried with raw SQL built via `string.format`. [filter.sql](filter.sql) records the pruning already applied (aliases, non-monsters, `?` atk/def removed). `race` and `attribute` are bitflags; the names live in [CardText.lua](CardText.lua).

`Game.forbiddenMemoriesIds` (in [Game.lua](Game.lua)) is the ~700-id FM card pool, spliced into queries as an `in (...)` clause. **Draws** are restricted to it; **fusion results** currently are not — [FusionProcessor.lua](FusionProcessor.lua) has `(d.id in (%s) or 1=1)`, where the `or 1=1` intentionally disables the restriction. Delete `or 1=1` to confine results to the FM pool.

The fusion rule itself *is* the SQL query in `FusionProcessor._getFusionResult`: pick the card whose race comes from one material and attribute from the other, with `atk <= defA + defB` and atk (or atk+def) strictly beating both materials, ordered by atk/def/id. A failed fusion falls through to material B. Chains fuse left-to-right, each result feeding the next.

**AI** (`Game:_playAIFusion`): brute-forces `permutations(hand, 1, aiDifficulty)`, optionally prepending a field card to overwrite it, and scores candidates with `_isFusionBetter` (atk → def → prefers not replacing → prefers more materials). `aiDifficulty` ratchets upward with the card-count deficit and never decreases.

[TODO.txt](TODO.txt) (Portuguese) holds the current design backlog and the house rules that deviate from Forbidden Memories.

## Digimon adaptation (in progress)

The game is being re-themed from Yu-Gi-Oh! to the **Digimon TCG**. Step 1 — the card database — is done; the fusion/digivolution rules will be redesigned later and will be *completely different* from the YGO rules above. Nothing in the Lua game reads any of this yet; `cards.cdb` and all gameplay code are still the YGO originals.

[digimon.cdb](digimon.cdb) holds 4,018 cards (2,994 Digimon, 481 Option, 310 Tamer, 233 DigiEgg) across 59 sets, generated by [tools/dcgo_import.py](tools/dcgo_import.py) from [DCGO](https://github.com/DCGO2), a Unity Digimon TCG simulator at `D:\Git\DCGO`. It stores one Unity YAML `.asset` per card under `DCGO/Assets/CardBaseEntity/<Set>/<Color>/<Kind>/`.

Schema in [tools/schema.sql](tools/schema.sql). It is **deliberately Digimon-native, not the YGO `datas`/`texts` shape** — nothing is squeezed into `atk`/`def`/`race`/`attribute`, so the future rule design stays unconstrained. `cards` carries level, dp, play_cost, rarity, memory/link fields and the three effect texts; child tables carry the genuinely multi-valued fields (`card_colors`, `card_types`, `card_forms`, `card_attributes`) plus `card_evo_costs` — the structured `{from_color, from_level, memory_cost}` digivolution requirements, which is the most useful table for building new fusion rules.

Re-run `python tools/dcgo_import.py` whenever DCGO ships a new set (needs PyYAML). It is incremental and idempotent: each row keeps the sha1 of its source `.asset`, so only new/changed cards are touched. Deletions require an explicit `--prune`, so a half-synced DCGO checkout cannot silently wipe rows.

Non-obvious facts about the source data, all learned the hard way:
- `cardColors` is a hex int-array blob and **must not go through YAML** — `01000000` matches YAML 1.1's octal rule and silently becomes 262144. The importer regexes it out of the raw text. Decoded: `0=Red 1=Blue 2=Yellow 3=Green 4=White 5=Black 6=Purple`, derived by majority vote against the `<Color>` folders because DCGO's `Assets/Scripts` submodule (which defines the C# enums) is not cloned.
- Stage and attribute look single-valued but aren't: 75 cards have two forms (BT18-102 is Mega *and* Hybrid), 14 have two attributes (BT16-102 is Vaccine *and* Free), and types run up to six. Hence the child tables.
- 21 Digimon genuinely have **no level** (Calumon, the D-Reaper `ADR-xx` agents, Eater) — level-based rules must expect `level = 0`.
- `cardKind` is authoritative, the folder name is not (the DigiEgg `BT1_002` is filed under `Red/Digimon`). Alt-art printings (`_P0`/`_P1` assets) keep the base `CardID` and differ only in `CardSpriteName`, so they merge on `CardID`.
- Art is **not** imported yet — that is the next step. Card art is 430×601 `.webp` named `<CardID>.webp` in `D:\Downloads\DCGO_Application\Assets\Textures\Card`, covering 3,276 of the 4,018 cards; `cards.has_art` / `cards.image_file` record which. The game still expects `pics/<id>.jpg` ([CardView.lua](CardView.lua)).

## Style

4-space indent, no semicolons, camelCase, `_privateMethod` prefix for internals, lowercase `--comments`. Lua tables are formatted one-field-per-line (lua-format style). Keep it consistent with surrounding code.

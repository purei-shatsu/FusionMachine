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

## Unrelated WIP

[tools/](tools/) and `digimon.cdb` are an untracked, separate exploration: a Python importer that scrapes Digimon TCG card data out of the DCGO simulator's Unity assets. Nothing in the Lua game reads them.

## Style

4-space indent, no semicolons, camelCase, `_privateMethod` prefix for internals, lowercase `--comments`. Lua tables are formatted one-field-per-line (lua-format style). Keep it consistent with surrounding code.

# danieltalbert — repo root

This repo holds two projects. The active one is **Neural Quest: Gradientfall**,
a 3D open-world Godot 4 game in `gradientfall/`.

**Read `gradientfall/CLAUDE.md` before doing any Gradientfall work** — it is the
builder's contract (iron rules, conventions, division of labour) and it lists the
docs to read first.

## This is the canonical repo. Do not use the other one.

- **Correct remote:** `danieltalbert/danieltalbert` (this repo), branch **`main`**.
  One tree, one branch. `main` == `origin/main` is the real, playable state.
- **WRONG remote:** `danieltalbert/gradientfall` is a *standalone* repo created by
  a one-off "portfolio publish". Cloud sessions cloned it by mistake and did work
  there for a while, which split the project in two and cost real time — the game
  appeared to lose its photoreal grass because that repo is frozen on the old
  lineage. Its unique milestones (Town of Bootstrap, Inventory) have since been
  ported here. **Do not clone, push to, or judge the game from it.**
- Stale on-disk copies under `Documents/Codex/.../gradientfall/` are frozen
  2026-07-20 snapshots, each marked `STALE_DO_NOT_USE.md`. Never open them.

Confirm before building or judging visuals:

```
git remote -v && git branch --show-current && git log --oneline -1
```

Expect `danieltalbert/danieltalbert` and `main`.

## Running the game (any platform)

Godot **4.7.1**. The project is `gradientfall/game/`. Paths in code are all
`res://` or relative, so macOS/Linux/Windows all work — only the Godot binary
differs.

```
godot --path gradientfall/game --import --headless     # ALWAYS import first
godot --path gradientfall/game
```

`--import` first is not optional when a session added new script classes: the
editor's global class cache is otherwise stale and boot fails with
"Could not find type". This has bitten past sessions.

Useful dev flags (after a `--` separator):

- `--screenshot=/abs/dir` — capture the standard angle set and quit. This is the
  eyes-on verification tool (GDD §10); visual work is not "done" until looked at.
- `--grass=0.25` — scale blade count. **Ship density (~5.4M blades) is tuned for
  a high-end desktop GPU and will crawl on a laptop or Mac.** Use this to iterate
  and test everything else at a playable frame rate.
- `--no-grass` — boot without the carpets, to attribute frame cost honestly.
- `--kern-base` — opt in to the imported Blender body for Kern (see
  `gradientfall/docs/DEVLOG.md` for why it is still gated).

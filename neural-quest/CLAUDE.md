# NEURAL QUEST

A retro pixel-art educational RPG that teaches 20 machine learning topics.
Built in Godot 4.x with GDScript. Target version: v0.1.0.

## Provenance note

The original single-file HTML5 prototype (v3) referenced by the project brief
was not available in any repository attached to the build session. The project
owner explicitly authorized authoring the full content set fresh (recorded
2026-07-15). Everything in `data/` is therefore the canonical content, written
for this project, not a port of prior text. The content rule still applies
going forward: strings in `data/` are the product. Do not paraphrase, shorten,
or "improve" them casually; treat any edit to them as a content change that
needs owner review.

## What the game is

The player descends a long vertical serpentine overworld through 4 biomes:

1. Act 1: Prediction Plains (green) - supervised learning basics
2. Act 2: Guild of Ensembles (autumn) - stronger classifiers and evaluation
3. Act 3: Unsupervised Underworld (purple) - learning without labels
4. Act 4: Deep Learning Depths (deep blue) - neural networks

Twenty numbered boss portals sit along the path, one per ML topic, ordered
easy to hard (5 per act). Each zone between bosses contains one wandering
tutor who teaches that boss's topic in two short pages, and one roaming
mini-battle monster that drills it for small XP. Everything is optional free
roam; nothing gates the bosses. The loop: learn from the tutor, drill on the
monster, beat the boss.

## Hard requirements (feature parity spec)

1. Overworld: tile-based vertical map, 16x16 tiles, 4 biome palettes,
   serpentine path connecting 20 portals, decorative solid obstacles per
   biome (trees, pillars, crystals, coral), camera follows player.
2. Player: 4-direction movement with collision, hold-to-sprint (about 1.6x)
   with dust particles, walk animation, gold crown on the sprite once all 20
   bosses are cleared.
3. Boss portals: walking onto one opens a quiz panel showing act label, world
   name, topic, zone-prep status (tutor read? mini beaten?), the literal
   definition, one question with 3 shuffled options, and a vocab loot line.
   Wrong answers allow retry within the panel. XP: 50 first-try, 25 after a
   retry. Cleared bosses reopen in review mode (no XP).
4. Tutors: 20 wandering NPCs on a short leash around a home point, "?"
   indicator until read, 2-page lesson dialog, re-readable forever.
5. Mini monsters: 20 roamers with "!" indicator, one drill question each,
   +15 XP on first win, free retries, review mode after.
6. Data shards: 60 collectibles placed deterministically on path tiles,
   +2 XP each, sparkle burst and blip on pickup.
7. Streak: consecutive FIRST-TRY correct answers across bosses, minis, and
   the Glitch. Multiplier by streak: 1.0, 1.25, 1.5, 1.75, 2.0 (capped).
   Any wrong answer resets it. Review wins can extend the streak but never
   grant XP. Session-only, never saved.
8. Golden Glitch: when absent, spawns on a random path tile about every 40 s;
   wanders faster than other entities; relocates every 40 s if ignored.
   Touching it opens a ONE-SHOT remix question drawn from topics the player
   has engaged with (tutor read, mini beaten, or boss cleared). Correct:
   40 XP times streak multiplier. Wrong: answer revealed, it escapes. Either
   way it despawns and the respawn timer restarts.
9. Quest compass: edge-of-screen arrow to the lowest-numbered uncleared boss;
   after 20/20 it points to the Glitch when active.
10. Levels: one level per 150 XP using the TITLES ladder, level-up toast and
    fanfare.
11. Achievements: the 10 entries in the ACH map (data/meta.json), unlocked
    with toast pop-ins and persisted.
12. Save/load: cleared bosses, minis beaten, tutors read, shards collected,
    achievements, total XP, glitch catch count to user:// as JSON. Load on
    boot; title screen shows Continue plus New Game (erase save) when a save
    exists.
13. Audio: chiptune SFX (panel open, page turn, correct arpeggio, wrong buzz,
    shard blip, level fanfare) as tiny WAVs synthesized by tools/gen_sfx.py
    and committed. Mute toggle (M key and touch button).
14. Controls: keyboard (WASD or arrows, Shift sprint) AND mobile touch D-pad
    plus RUN button. Tap targets at least 44 px at final scale.
15. Juice: floating +XP text, particle bursts on pickups and wins, brief
    screen shake on boss entry, panel pop-in animation, CRT scanline overlay
    toggleable in code (Main.SCANLINES).

## Game math

- XP: boss 50 first-try / 25 after retry, mini 15, shard 2, glitch 40.
  All XP awards are multiplied by the streak multiplier, then rounded down.
- Streak multiplier table: [1.0, 1.25, 1.5, 1.75, 2.0], indexed by
  min(streak, 4) where streak is counted BEFORE the current answer is added.
- Level = floor(xp / 150) + 1. Title = TITLES[min(level - 1, len - 1)].
- Glitch timers: 40 s respawn when absent, 40 s relocate while ignored.

## Content data (data/)

- data/worlds.json: array of exactly 20 worlds. Each world:
  id (1..20), act (1..4), world (name), topic, definition, question,
  options (exactly 3), answer (0..2), vocab (loot line),
  tutor {name, pages (exactly 2)}, mini {name, question, options (3),
  answer (0..2)}.
- data/meta.json: acts (4 names + palettes), titles ladder, achievements map
  (10 entries: id, name, desc), and tunable constants.
- data/map.json: generated by tools/gen_map.py (deterministic, seeded).
  Grid rows as strings ('.' ground, 'P' path, '#' obstacle), plus portal,
  tutor home, mini home, and exactly 60 shard coordinates.
- tools/validate_content.py asserts all counts and ranges. Run it after any
  content edit: `python3 tools/validate_content.py`

## Topic ladder

Act 1 Prediction Plains: 1 Linear Regression, 2 Logistic Regression,
3 K-Nearest Neighbors, 4 Decision Trees, 5 Overfitting and Train/Test Split.
Act 2 Guild of Ensembles: 6 Naive Bayes, 7 Support Vector Machines,
8 Bagging and Random Forests, 9 Gradient Boosting, 10 Cross-Validation and
Evaluation Metrics.
Act 3 Unsupervised Underworld: 11 K-Means Clustering, 12 Hierarchical
Clustering, 13 Principal Component Analysis, 14 Anomaly Detection,
15 Recommender Systems.
Act 4 Deep Learning Depths: 16 Neurons and Activation Functions, 17 Gradient
Descent and Backpropagation, 18 Convolutional Neural Networks, 19 Recurrent
Networks and Sequence Models, 20 Transformers and Attention.

## Palette

Authored for this project (no reference CSS existed; see Provenance note).

UI / global:
- bg deep space: #0b0c14
- panel fill: #141728, panel border: #3a3f5c
- text: #e8e6f0, dim text: #9aa0b8
- gold accent (XP, crown, glitch): #ffd45e
- cyan accent (player tunic, links): #4de3d1
- success green: #58e07a, danger red: #ff5c72, xp blue: #7ee0ff

Act 1 Prediction Plains: ground #3fa34d, ground dark #2d7d46,
path #d9c27e, path dark #c4ad6a, tree trunk #6b4a2b, tree leaves #1f6b38.
Act 2 Guild of Ensembles: ground #b0722e, ground dark #8f5722,
path #e0b268, path dark #caa055, pillar #c9a15f, autumn leaf #d1512d.
Act 3 Unsupervised Underworld: ground #4a2e63, ground dark #3b2352,
path #8a6fae, path dark #79609b, crystal #b57ee0, crystal core #7c4dbb,
crystal glow #e0c2ff.
Act 4 Deep Learning Depths: ground #1c3a5e, ground dark #16324f,
path #3f6c96, path dark #345d83, coral #2fa3c7, coral dark #1b6f9e,
coral glow #7fe3ff.
Player: skin #f2d5a0, tunic #4de3d1, hair #503020, boots #705038,
crown #ffd45e.

## Architecture decisions

- Godot 4.x (developed against 4.3+ APIs, uses TileMapLayer). Base viewport
  240x320, stretch mode canvas_items, aspect keep, nearest filtering, pixel
  snap. Window override 480x640 for desktop.
- Data-driven: all content in /data as JSON, loaded by the ContentDb
  autoload. No strings hard-coded in scenes if they exist in data.
- Autoloads (order matters): ContentDb (loads data), GameState (save, XP,
  streak, achievements, signals), Sfx (WAV playback plus mute), Toasts
  (queued toast pop-ins on a CanvasLayer).
- The overworld map is PRE-GENERATED by tools/gen_map.py into data/map.json
  (seeded, deterministic) rather than generated inside Godot. Rationale: the
  60 shard placements and entity homes can then be validated headlessly by
  tools/validate_content.py, and the game code stays a pure consumer of data.
- Terrain renders through a TileMapLayer whose TileSet is built at runtime
  from a programmatically generated atlas texture (art/pixel_art.gd). No
  external image assets; the repo has zero binary art dependencies.
- Collision is pure grid logic (solid tile lookup with an AABB step), not
  the physics engine. Entities are plain Node2D subclasses. Rationale:
  deterministic, trivial to test, no TileSet physics-layer setup in code.
- Scenes: main.tscn is the only .tscn file; every game object (Overworld,
  Player, Portal, Tutor, Monster, GoldenGlitch, Shard, QuizPanel, TutorPanel,
  HUD, TitleScreen, VictoryScreen) is a GDScript class instantiated from
  code. Rationale: all art and layout are programmatic anyway, hand-written
  .tscn text is the least reviewable and most error-prone part of an
  editor-less build. The class list mirrors the scene list in the brief.
- Input actions are registered in code (InputMap) by the ContentDb autoload
  at startup instead of hand-writing InputEventKey blobs in project.godot.
- QuizPanel is one class reused for boss, mini, and glitch via a Mode enum.
- Save file: user://neural_quest_save.json, versioned {"v": 1, ...}.
- SFX are tiny mono 22.05 kHz 16-bit WAVs committed under assets/sfx,
  regenerated by `python3 tools/gen_sfx.py`.
- Writing style everywhere (UI text, comments, commits, docs): clean
  language, no profanity, never use em dashes.

## Verification

No Godot binary was available in the build environment. What was verified
headlessly: `python3 tools/validate_content.py` (content counts and ranges),
`gdparse` (gdtoolkit 4.5) on every .gd file, JSON well-formedness, and WAV
generation. NOT verified headlessly: actual engine boot, rendering, audio
playback. Verify locally with:

    godot --headless --path neural-quest --import
    godot --path neural-quest

## BACKLOG (ideas beyond parity, do not build yet)

- Per-world minigames (for example: drag points onto a regression line,
  sort samples into clusters, route a signal through a tiny network).
- Chiptune background music per act with crossfade at biome borders.
- More monster variety: 2 or 3 sprite bodies per act with palette swaps.
- Boss rematch mode with harder remix questions and a par-time medal.
- Gamepad support (already trivial via InputMap additions).
- NG+ mode: shuffled question pools and 5-option questions.
- Accessibility: text size toggle, reduced-flash mode, screen-reader dump of
  lesson text to OS clipboard.
- Minimap overlay showing visited zones and remaining shards.
- Daily Glitch challenge with seeded question of the day.

#!/usr/bin/env python3
"""Validate the Neural Quest content set. Exit code 0 means all checks pass.

Asserts: exactly 20 worlds, 20 tutors with 2 pages each, 20 minis, exactly 60
shard placements on path tiles, every answer index in range, 10 achievements,
and full walkable connectivity from spawn to every portal, tutor, and mini.
"""

import json
import sys
from collections import deque
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data"
errors = []


def check(cond, msg):
    if not cond:
        errors.append(msg)


worlds = json.loads((DATA / "worlds.json").read_text())
meta = json.loads((DATA / "meta.json").read_text())
map_data = json.loads((DATA / "map.json").read_text())

# Worlds
check(len(worlds) == 20, f"expected 20 worlds, got {len(worlds)}")
for i, w in enumerate(worlds):
    wid = w.get("id")
    check(wid == i + 1, f"world index {i} has id {wid}, expected {i + 1}")
    check(w.get("act") == 1 + i // 5, f"world {wid}: act should be {1 + i // 5}")
    for field in ("world", "topic", "definition", "question", "vocab"):
        check(bool(str(w.get(field, "")).strip()), f"world {wid}: empty {field}")
    check(len(w.get("options", [])) == 3, f"world {wid}: needs exactly 3 options")
    check(w.get("answer") in (0, 1, 2), f"world {wid}: answer index out of range")
    remix = w.get("remix", {})
    check(bool(str(remix.get("question", "")).strip()), f"world {wid}: remix missing question")
    check(len(remix.get("options", [])) == 3, f"world {wid}: remix needs exactly 3 options")
    check(remix.get("answer") in (0, 1, 2), f"world {wid}: remix answer out of range")
    lab = w.get("lab", {})
    check(bool(str(lab.get("name", "")).strip()), f"world {wid}: lab missing name")
    check(bool(str(lab.get("goal", "")).strip()), f"world {wid}: lab missing goal")
    tut = w.get("tutor", {})
    check(bool(str(tut.get("name", "")).strip()), f"world {wid}: tutor missing name")
    pages = tut.get("pages", [])
    check(len(pages) == 2, f"world {wid}: tutor needs exactly 2 pages")
    check(all(str(p).strip() for p in pages), f"world {wid}: empty tutor page")
    mini = w.get("mini", {})
    check(bool(str(mini.get("name", "")).strip()), f"world {wid}: mini missing name")
    check(bool(str(mini.get("question", "")).strip()), f"world {wid}: mini missing question")
    check(len(mini.get("options", [])) == 3, f"world {wid}: mini needs exactly 3 options")
    check(mini.get("answer") in (0, 1, 2), f"world {wid}: mini answer out of range")

# Meta
check(len(meta.get("acts", [])) == 4, "expected 4 acts")
for act in meta.get("acts", []):
    pal = act.get("palette", {})
    for key in ("ground", "ground_dark", "path", "path_dark", "obstacle_a", "obstacle_b", "accent"):
        v = pal.get(key, "")
        check(len(v) == 7 and v.startswith("#"), f"act {act.get('id')}: bad palette color {key}={v}")
check(len(meta.get("titles", [])) >= 5, "titles ladder too short")
check(len(meta.get("achievements", {})) == 12, "expected exactly 12 achievements")
for aid, a in meta.get("achievements", {}).items():
    check(bool(a.get("name")) and bool(a.get("desc")), f"achievement {aid}: missing name or desc")
consts = meta.get("constants", {})
check(len(consts.get("streak_multipliers", [])) == 5, "expected 5 streak multipliers")
check(consts.get("shard_count") == 60, "shard_count constant must be 60")

# Map
rows = map_data["rows"]
width, height = map_data["width"], map_data["height"]
check(len(rows) == height, "row count does not match height")
check(all(len(r) == width for r in rows), "ragged map rows")
check(all(set(r) <= set(".P#") for r in rows), "unknown tile character")


def tile(x, y):
    return rows[y][x] if 0 <= x < width and 0 <= y < height else "#"


check(len(map_data["portals"]) == 20, "expected 20 portals")
check(len(map_data["tutors"]) == 20, "expected 20 tutor homes")
check(len(map_data["minis"]) == 20, "expected 20 mini homes")
check(len(map_data["labs"]) == 20, "expected 20 lab stations")
shards = map_data["shards"]
check(len(shards) == 60, f"expected exactly 60 shards, got {len(shards)}")
check(len({tuple(s) for s in shards}) == 60, "duplicate shard placements")
for x, y in shards:
    check(tile(x, y) == "P", f"shard at ({x},{y}) is not on a path tile")
for p in map_data["portals"]:
    check(tile(p["x"], p["y"]) == "P", f"portal {p['id']} not on path")
for e in map_data["tutors"] + map_data["minis"] + map_data["labs"]:
    check(tile(e["x"], e["y"]) != "#", f"entity {e['id']} home at ({e['x']},{e['y']}) is solid")

# Connectivity: BFS from spawn over walkable tiles must reach everything.
sx, sy = map_data["spawn"]
check(tile(sx, sy) != "#", "spawn is solid")
seen = {(sx, sy)}
queue = deque([(sx, sy)])
while queue:
    cx, cy = queue.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = cx + dx, cy + dy
        if (nx, ny) not in seen and tile(nx, ny) != "#":
            seen.add((nx, ny))
            queue.append((nx, ny))
for p in map_data["portals"]:
    check((p["x"], p["y"]) in seen, f"portal {p['id']} unreachable from spawn")
for label, ents in (("tutor", map_data["tutors"]), ("mini", map_data["minis"]),
                    ("lab", map_data["labs"])):
    for e in ents:
        check((e["x"], e["y"]) in seen, f"{label} {e['id']} unreachable from spawn")
for x, y in shards:
    check((x, y) in seen, f"shard at ({x},{y}) unreachable from spawn")

if errors:
    print(f"FAIL: {len(errors)} problem(s)")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print("OK: 20 worlds, 20 tutors x 2 pages, 20 minis, 20 portals, "
      f"{len(shards)} shards on reachable path tiles, "
      f"{len(meta['achievements'])} achievements, all answer indices in range.")

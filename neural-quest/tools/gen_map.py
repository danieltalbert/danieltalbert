#!/usr/bin/env python3
"""Generate the Neural Quest overworld into data/map.json.

Deterministic: a fixed seed produces the same map every run, so the 60 shard
placements and entity homes are stable, committed data that the validation
script can assert against. The game only consumes data/map.json.

Grid legend: '#' solid, '.' ground (walkable), 'P' path (walkable).
Coordinates are [x, y] tile indices, origin top-left.
"""

import json
import random
from pathlib import Path

SEED = 20260715
WIDTH = 15
ZONES = 20
ZONE_H = 20
TOP_MARGIN = 4
BOTTOM_MARGIN = 6
HEIGHT = TOP_MARGIN + ZONES * ZONE_H + BOTTOM_MARGIN
SHARDS_PER_ZONE = 3
OBSTACLE_CHANCE = 0.11

rng = random.Random(SEED)
grid = [["." for _ in range(WIDTH)] for _ in range(HEIGHT)]


def carve(x, y):
    if 1 <= x < WIDTH - 1 and 1 <= y < HEIGHT - 1:
        grid[y][x] = "P"


def carve_v(x, y0, y1):
    for y in range(min(y0, y1), max(y0, y1) + 1):
        carve(x, y)


def carve_h(y, x0, x1):
    for x in range(min(x0, x1), max(x0, x1) + 1):
        carve(x, y)


def clear_area(cx, cy, r=1):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if 1 <= x < WIDTH - 1 and 1 <= y < HEIGHT - 1 and grid[y][x] == "#":
                grid[y][x] = "."


# Borders are solid.
for x in range(WIDTH):
    grid[0][x] = "#"
    grid[HEIGHT - 1][x] = "#"
for y in range(HEIGHT):
    grid[y][0] = "#"
    grid[y][WIDTH - 1] = "#"

portals = []
tutors = []
minis = []
labs = []
zones = []

x = WIDTH // 2
y = 2
spawn = [x, y]
carve_v(x, 2, TOP_MARGIN)
y = TOP_MARGIN

for i in range(ZONES):
    zone_y0 = TOP_MARGIN + i * ZONE_H
    zone_y1 = zone_y0 + ZONE_H - 1
    act = 1 + i // 5
    zones.append({"id": i + 1, "act": act, "y0": zone_y0, "y1": zone_y1})

    # Two horizontal sweeps per zone make the serpentine shape.
    side_left = i % 2 == 0
    tx1 = rng.randint(2, 5) if side_left else rng.randint(9, 12)
    mid1 = zone_y0 + rng.randint(3, 6)
    carve_v(x, y, mid1)
    carve_h(mid1, x, tx1)

    tx2 = rng.randint(6, 8)
    mid2 = zone_y0 + rng.randint(11, 14)
    carve_v(tx1, mid1, mid2)
    carve_h(mid2, tx1, tx2)

    portal_y = zone_y1 - 1
    carve_v(tx2, mid2, portal_y)
    for py in range(portal_y - 1, portal_y + 2):
        for px in range(tx2 - 1, tx2 + 2):
            carve(px, py)
    portals.append({"id": i + 1, "x": tx2, "y": portal_y})

    # Tutor home sits beside the first sweep, mini beside the second.
    t_off = 2 if tx1 < WIDTH // 2 else -2
    tutor_home = [max(2, min(WIDTH - 3, tx1 + t_off)), max(zone_y0 + 1, mid1 - 2)]
    tutors.append({"id": i + 1, "x": tutor_home[0], "y": tutor_home[1]})

    m_off = -2 if tx1 < WIDTH // 2 else 2
    mini_home = [max(2, min(WIDTH - 3, tx2 + m_off)), min(zone_y1 - 3, mid2 + 2)]
    minis.append({"id": i + 1, "x": mini_home[0], "y": mini_home[1]})

    # Lab station: a static terminal beside the second sweep, opposite the
    # mini monster so each zone reads as tutor, lab, monster, boss.
    l_off = 2 if m_off < 0 else -2
    lab_home = [max(2, min(WIDTH - 3, tx2 + l_off)), max(zone_y0 + 2, mid2 - 2)]
    labs.append({"id": i + 1, "x": lab_home[0], "y": lab_home[1]})

    x, y = tx2, portal_y

# A short tail below the last portal.
carve_v(x, y, HEIGHT - BOTTOM_MARGIN + 2)

# Scatter decorative solid obstacles on ground far enough from the path.
def near_path(px, py, r=1):
    for yy in range(py - r, py + r + 1):
        for xx in range(px - r, px + r + 1):
            if 0 <= xx < WIDTH and 0 <= yy < HEIGHT and grid[yy][xx] == "P":
                return True
    return False


for yy in range(1, HEIGHT - 1):
    for xx in range(1, WIDTH - 1):
        if grid[yy][xx] == "." and not near_path(xx, yy) and rng.random() < OBSTACLE_CHANCE:
            grid[yy][xx] = "#"

# Keep a wander pocket clear around every entity home.
for e in tutors + minis + labs:
    clear_area(e["x"], e["y"], 2)
    grid[e["y"]][e["x"]] = "."

# Shards: exactly 3 per zone on plain path tiles, away from portal plazas.
shards = []
for z, p in zip(zones, portals):
    plaza = {(px, py) for py in range(p["y"] - 1, p["y"] + 2)
             for px in range(p["x"] - 1, p["x"] + 2)}
    tiles = [(xx, yy) for yy in range(z["y0"], z["y1"] + 1)
             for xx in range(1, WIDTH - 1)
             if grid[yy][xx] == "P" and (xx, yy) not in plaza]
    tiles.sort()
    for xx, yy in rng.sample(tiles, SHARDS_PER_ZONE):
        shards.append([xx, yy])

out = {
    "seed": SEED,
    "tile": 16,
    "width": WIDTH,
    "height": HEIGHT,
    "spawn": spawn,
    "rows": ["".join(r) for r in grid],
    "zones": zones,
    "portals": portals,
    "tutors": tutors,
    "minis": minis,
    "labs": labs,
    "shards": shards,
}

dest = Path(__file__).resolve().parent.parent / "data" / "map.json"
dest.write_text(json.dumps(out, indent=1) + "\n")
print(f"wrote {dest}: {WIDTH}x{HEIGHT}, {len(portals)} portals, "
      f"{len(tutors)} tutors, {len(minis)} minis, {len(labs)} labs, "
      f"{len(shards)} shards")

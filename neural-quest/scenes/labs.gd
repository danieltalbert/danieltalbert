class_name LabLibrary
## The interactive ML labs: one small visual simulation per topic family,
## driven by four directions plus OK (keyboard, gamepad, or on-screen
## buttons). Every lab is deterministic per world via a seeded RNG.
##
## A lab exposes: setup(), handle(action), render(canvas), status(), hint(),
## and sets `done = true` when its goal is met. LabPanel owns rewards.

const TEXT := Color("#e8e6f0")
const DIM := Color("#9aa0b8")
const GOLD := Color("#ffd45e")
const CYAN := Color("#4de3d1")
const XP_BLUE := Color("#7ee0ff")
const RED := Color("#ff5c72")
const GREEN := Color("#58e07a")


static func make(world_id: int) -> BaseLab:
	var lab: BaseLab
	match world_id:
		1: lab = FitLineLab.new()
		2: lab = BoundaryLab.new()
		3: lab = KnnLab.new()
		4: lab = TreeLab.new()
		5: lab = DegreeLab.new()
		6: lab = BayesLab.new()
		7: lab = MarginLab.new()
		8: lab = EnsembleLab.new()
		9: lab = BoostLab.new()
		10: lab = ThresholdLab.new()
		11: lab = KmeansLab.new()
		12: lab = HierarchyLab.new()
		13: lab = PcaLab.new()
		14: lab = AnomalyLab.new()
		15: lab = MatrixLab.new()
		16: lab = NeuronLab.new()
		17: lab = DescentLab.new()
		18: lab = ConvLab.new()
		19: lab = GateLab.new()
		20: lab = AttentionLab.new()
		_: lab = FitLineLab.new()
	lab.world_id = world_id
	lab.rng.seed = 977000 + world_id
	lab.setup()
	return lab


static func txt(c: Control, pos: Vector2, s: String, col: Color = TEXT,
		size: int = 8) -> void:
	c.draw_string(ThemeDB.fallback_font, pos, s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Map unit coords (0..1, y up) into the canvas with a margin.
static func pt(c: Control, u: float, v: float) -> Vector2:
	return Vector2(8.0 + u * (c.size.x - 16.0),
		c.size.y - 8.0 - v * (c.size.y - 16.0))


class BaseLab extends RefCounted:
	var world_id := 1
	var rng := RandomNumberGenerator.new()
	var done := false
	var flash := ""

	func setup() -> void:
		pass

	func handle(_action: String) -> void:
		pass

	func render(_c: Control) -> void:
		pass

	func status() -> String:
		return ""

	func hint() -> String:
		return "Arrows adjust, OK confirms"


# 1: drag a line through points, minimize squared error.
class FitLineLab extends BaseLab:
	var a := 0.0
	var b := 0.5
	var xs: Array = []
	var ys: Array = []
	var target := 0.0

	func setup() -> void:
		var a0 := rng.randf_range(-0.7, 0.7)
		var b0 := rng.randf_range(0.35, 0.65)
		for i in 14:
			var x := rng.randf_range(0.05, 0.95)
			xs.append(x)
			ys.append(clampf(a0 * (x - 0.5) + b0 + rng.randf_range(-0.07, 0.07), 0.02, 0.98))
		target = _mse(a0, b0) * 1000.0 + 1.5

	func _mse(sa: float, sb: float) -> float:
		var s := 0.0
		for i in xs.size():
			var e: float = sa * (xs[i] - 0.5) + sb - ys[i]
			s += e * e
		return s / xs.size()

	func handle(action: String) -> void:
		match action:
			"up": a += 0.08
			"down": a -= 0.08
			"left": b -= 0.03
			"right": b += 0.03
		a = clampf(a, -1.5, 1.5)
		b = clampf(b, 0.0, 1.0)
		if _mse(a, b) * 1000.0 <= target:
			done = true

	func render(c: Control) -> void:
		for i in xs.size():
			var p := LabLibrary.pt(c, xs[i], ys[i])
			var on_line := LabLibrary.pt(c, xs[i], clampf(a * (xs[i] - 0.5) + b, 0.0, 1.0))
			c.draw_line(p, on_line, Color(LabLibrary.RED, 0.35), 1.0)
			c.draw_circle(p, 2.0, LabLibrary.TEXT)
		var l0 := LabLibrary.pt(c, 0.0, clampf(a * -0.5 + b, -0.2, 1.2))
		var l1 := LabLibrary.pt(c, 1.0, clampf(a * 0.5 + b, -0.2, 1.2))
		c.draw_line(l0, l1, LabLibrary.GOLD if done else LabLibrary.CYAN, 2.0)

	func status() -> String:
		return "MSE %.1f  target %.1f" % [_mse(a, b) * 1000.0, target]

	func hint() -> String:
		return "Up/Down tilt, Left/Right raise"


# 2: rotate and slide a decision boundary; 7 extends this with a margin goal.
class BoundaryLab extends BaseLab:
	var theta := 0.9
	var offset := 0.0
	var px: Array = []
	var py: Array = []
	var cls: Array = []
	var need := 14

	func setup() -> void:
		for i in 16:
			var is_b := i >= 8
			var cx := 0.68 if is_b else 0.32
			var cy := 0.64 if is_b else 0.36
			px.append(clampf(cx + rng.randf_range(-0.13, 0.13), 0.03, 0.97))
			py.append(clampf(cy + rng.randf_range(-0.13, 0.13), 0.03, 0.97))
			cls.append(1 if is_b else 0)

	func _f(x: float, y: float) -> float:
		return cos(theta) * (x - 0.5) + sin(theta) * (y - 0.5) - offset

	func _acc() -> int:
		var n := 0
		for i in px.size():
			var pred := 1 if _f(px[i], py[i]) > 0.0 else 0
			if pred == cls[i]:
				n += 1
		return n

	func _min_margin() -> float:
		var m := 99.0
		for i in px.size():
			m = minf(m, absf(_f(px[i], py[i])))
		return m

	func handle(action: String) -> void:
		match action:
			"left": theta -= 0.12
			"right": theta += 0.12
			"up": offset += 0.025
			"down": offset -= 0.025
		offset = clampf(offset, -0.4, 0.4)
		_check()

	func _check() -> void:
		if _acc() >= need:
			done = true

	func render(c: Control) -> void:
		for i in px.size():
			var col := LabLibrary.CYAN if cls[i] == 0 else LabLibrary.GOLD
			var correct: bool = (1 if _f(px[i], py[i]) > 0.0 else 0) == int(cls[i])
			c.draw_circle(LabLibrary.pt(c, px[i], py[i]), 2.5 if correct else 2.0, col)
			if not correct:
				c.draw_circle(LabLibrary.pt(c, px[i], py[i]), 4.0, Color(LabLibrary.RED, 0.6))
		var n := Vector2(cos(theta), sin(theta))
		var d := Vector2(-n.y, n.x)
		var mid := Vector2(0.5, 0.5) + n * offset
		var e0 := mid + d * 0.9
		var e1 := mid - d * 0.9
		c.draw_line(LabLibrary.pt(c, e0.x, e0.y), LabLibrary.pt(c, e1.x, e1.y),
			LabLibrary.GOLD if done else LabLibrary.TEXT, 2.0)

	func status() -> String:
		return "Sorted %d/16  need %d" % [_acc(), need]

	func hint() -> String:
		return "Left/Right turn, Up/Down slide"


# 7: same field, but the widest street wins.
class MarginLab extends BoundaryLab:
	const MARGIN_NEED := 0.05

	func _check() -> void:
		if _acc() == 16 and _min_margin() >= MARGIN_NEED:
			done = true

	func render(c: Control) -> void:
		super(c)
		var n := Vector2(cos(theta), sin(theta))
		var d := Vector2(-n.y, n.x)
		var m := _min_margin()
		for side: float in [-1.0, 1.0]:
			var mid := Vector2(0.5, 0.5) + n * (offset + side * m)
			var e0 := mid + d * 0.9
			var e1 := mid - d * 0.9
			c.draw_line(LabLibrary.pt(c, e0.x, e0.y), LabLibrary.pt(c, e1.x, e1.y),
				Color(LabLibrary.GREEN, 0.5), 1.0)

	func status() -> String:
		return "Sorted %d/16  margin %.3f  need %.3f" % [_acc(), _min_margin(), MARGIN_NEED]


# 3: grow k, watch the neighbor vote.
class KnnLab extends BaseLab:
	var k := 1
	var px: Array = []
	var py: Array = []
	var cls: Array = []
	var qx := 0.0
	var qy := 0.0
	var order: Array = []

	func setup() -> void:
		for i in 12:
			var is_b := i >= 6
			px.append(clampf((0.66 if is_b else 0.34) + rng.randf_range(-0.16, 0.16), 0.03, 0.97))
			py.append(clampf((0.6 if is_b else 0.4) + rng.randf_range(-0.16, 0.16), 0.03, 0.97))
			cls.append(1 if is_b else 0)
		qx = 0.34 + rng.randf_range(-0.05, 0.11)
		qy = 0.4 + rng.randf_range(-0.05, 0.11)
		for i in px.size():
			order.append(i)
		order.sort_custom(func(x, y): return _d(x) < _d(y))

	func _d(i: int) -> float:
		return Vector2(px[i] - qx, py[i] - qy).length()

	func _vote() -> Array:
		var counts := [0, 0]
		for j in k:
			counts[cls[order[j]]] += 1
		return counts

	func handle(action: String) -> void:
		match action:
			"left": k = maxi(1, k - 1)
			"right": k = mini(9, k + 1)
			"ok":
				var v := _vote()
				if v[0] > v[1]:
					done = true
				else:
					flash = "The vote says the wrong herd. Change k."

	func render(c: Control) -> void:
		var radius: float = _d(order[k - 1])
		var q := LabLibrary.pt(c, qx, qy)
		c.draw_circle(q, radius * (c.size.x - 16.0), Color(LabLibrary.TEXT, 0.08))
		for i in px.size():
			var col := LabLibrary.CYAN if cls[i] == 0 else LabLibrary.GOLD
			c.draw_circle(LabLibrary.pt(c, px[i], py[i]), 2.5, col)
		for j in k:
			var i: int = order[j]
			c.draw_circle(LabLibrary.pt(c, px[i], py[i]), 4.5, Color(LabLibrary.GREEN, 0.55))
		c.draw_circle(q, 3.5, LabLibrary.RED)

	func status() -> String:
		var v := _vote()
		return "k=%d  vote: %d cyan vs %d gold" % [k, v[0], v[1]]

	func hint() -> String:
		return "Left/Right set k, OK to call the vote"


# 4: two stakes partition the field like a depth-2 tree.
class TreeLab extends BaseLab:
	var vx := 0.5
	var hy := 0.5
	var px: Array = []
	var py: Array = []
	var cls: Array = []

	func setup() -> void:
		for i in 16:
			var x: float
			var y: float
			var label: int
			if i < 7:
				x = rng.randf_range(0.05, 0.36)
				y = rng.randf_range(0.05, 0.95)
				label = 0
			elif i < 12:
				x = rng.randf_range(0.56, 0.95)
				y = rng.randf_range(0.6, 0.95)
				label = 1
			else:
				x = rng.randf_range(0.56, 0.95)
				y = rng.randf_range(0.05, 0.42)
				label = 0
			px.append(x)
			py.append(y)
			cls.append(label)

	func _region(x: float, y: float) -> int:
		if x < vx:
			return 0
		return 1 if y >= hy else 2

	func _acc() -> int:
		var maj := [[0, 0], [0, 0], [0, 0]]
		for i in px.size():
			maj[_region(px[i], py[i])][cls[i]] += 1
		var n := 0
		for r in 3:
			n += maxi(maj[r][0], maj[r][1])
		return n

	func handle(action: String) -> void:
		match action:
			"left": vx -= 0.04
			"right": vx += 0.04
			"up": hy += 0.04
			"down": hy -= 0.04
		vx = clampf(vx, 0.05, 0.95)
		hy = clampf(hy, 0.05, 0.95)
		if _acc() >= 15:
			done = true

	func render(c: Control) -> void:
		for i in px.size():
			var col := LabLibrary.CYAN if cls[i] == 0 else LabLibrary.GOLD
			c.draw_circle(LabLibrary.pt(c, px[i], py[i]), 2.5, col)
		var line_col := LabLibrary.GOLD if done else LabLibrary.TEXT
		c.draw_line(LabLibrary.pt(c, vx, 0.0), LabLibrary.pt(c, vx, 1.0), line_col, 2.0)
		c.draw_line(LabLibrary.pt(c, vx, hy), LabLibrary.pt(c, 1.0, hy), line_col, 2.0)

	func status() -> String:
		return "Penned correctly %d/16  need 15" % _acc()

	func hint() -> String:
		return "Left/Right first stake, Up/Down second"


# 5: pick the polynomial degree where TEST error bottoms out.
class DegreeLab extends BaseLab:
	var d := 0
	var train: Array = []
	var test: Array = []
	var best := 3

	func setup() -> void:
		var t := [70.0, 48.0, 33.0, 22.0, 16.0, 11.0, 8.0, 6.0, 4.5, 3.5]
		for i in 10:
			train.append(t[i] + rng.randf_range(-1.0, 1.0))
			var over: float = maxf(0.0, i - 3.0)
			test.append(t[i] + 7.0 + 5.5 * over * over * 0.55 + rng.randf_range(-1.0, 1.0))
		best = 0
		for i in 10:
			if test[i] < test[best]:
				best = i

	func handle(action: String) -> void:
		match action:
			"left": d = maxi(0, d - 1)
			"right": d = mini(9, d + 1)
			"ok":
				if d == best:
					done = true
				else:
					flash = "Feel the U shape: test error can still drop."

	func render(c: Control) -> void:
		var w := (c.size.x - 24.0) / 10.0
		for i in 10:
			var x := 12.0 + i * w
			var th: float = train[i] / 80.0 * (c.size.y - 30.0)
			var eh: float = test[i] / 80.0 * (c.size.y - 30.0)
			c.draw_rect(Rect2(x, c.size.y - 14.0 - th, w * 0.35, th), LabLibrary.CYAN)
			c.draw_rect(Rect2(x + w * 0.4, c.size.y - 14.0 - eh, w * 0.35, eh), LabLibrary.GOLD)
			if i == d:
				c.draw_rect(Rect2(x - 1.0, c.size.y - 12.0, w * 0.8, 3.0),
					LabLibrary.GREEN if done else LabLibrary.TEXT)
		LabLibrary.txt(c, Vector2(10, 10), "cyan = train, gold = TEST", LabLibrary.DIM, 7)

	func status() -> String:
		return "degree %d  train %.0f  test %.0f" % [d, train[d], test[d]]

	func hint() -> String:
		return "Left/Right choose degree, OK confirms"


# 6: apply word evidence, watch the spam odds move.
class BayesLab extends BaseLab:
	const CARDS := [["WIN GOLD", 4.0], ["FREE!!!", 3.0], ["dragon deal", 2.5],
		["meeting", 0.4], ["thanks", 0.5]]
	var cursor := 0
	var applied: Array = [false, false, false, false, false]
	var odds := 1.0 / 9.0

	func handle(action: String) -> void:
		match action:
			"left": cursor = maxi(0, cursor - 1)
			"right": cursor = mini(CARDS.size() - 1, cursor + 1)
			"ok":
				if not applied[cursor]:
					applied[cursor] = true
					odds *= float(CARDS[cursor][1])
				var all_done := true
				for a in applied:
					if not a:
						all_done = false
				if all_done:
					done = true

	func render(c: Control) -> void:
		var w := (c.size.x - 20.0) / CARDS.size()
		for i in CARDS.size():
			var r := Rect2(10.0 + i * w, 18.0, w - 3.0, 26.0)
			var lr: float = CARDS[i][1]
			var col := LabLibrary.RED if lr > 1.0 else LabLibrary.GREEN
			c.draw_rect(r, Color(col, 0.5 if applied[i] else 0.15))
			c.draw_rect(r, LabLibrary.TEXT if i == cursor else Color(LabLibrary.DIM, 0.5), false, 1.0)
			LabLibrary.txt(c, r.position + Vector2(2, 11), str(CARDS[i][0]), LabLibrary.TEXT, 6)
			LabLibrary.txt(c, r.position + Vector2(2, 21), "x%.1f" % lr, col, 7)
		var p := odds / (1.0 + odds)
		var bar := Rect2(10.0, c.size.y - 34.0, c.size.x - 20.0, 12.0)
		c.draw_rect(bar, Color(0, 0, 0, 0.4))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)),
			LabLibrary.RED if p > 0.5 else LabLibrary.GREEN)
		LabLibrary.txt(c, Vector2(10, c.size.y - 40.0),
			"P(spam) = %.2f   prior was 0.10" % p, LabLibrary.TEXT, 7)

	func status() -> String:
		return "Apply every clue. Order never matters."

	func hint() -> String:
		return "Left/Right pick a clue, OK weighs it"


# 8: more voters, steadier chorus.
class EnsembleLab extends BaseLab:
	var n := 1
	var bits: Array = []

	func setup() -> void:
		for t in 25:
			var row: Array = []
			for s in 40:
				row.append(1 if rng.randf() < 0.65 else 0)
			bits.append(row)

	func _acc(m: int) -> float:
		var correct := 0
		for s in 40:
			var votes := 0
			for t in m:
				votes += int(bits[t][s])
			if votes * 2 > m:
				correct += 1
		return correct / 40.0

	func handle(action: String) -> void:
		match action:
			"left": n = maxi(1, n - 1)
			"right": n = mini(25, n + 1)
		if _acc(n) >= 0.85:
			done = true

	func render(c: Control) -> void:
		var prev := Vector2.ZERO
		for m in range(1, n + 1):
			var p := Vector2(10.0 + (m - 1) * (c.size.x - 20.0) / 24.0,
				c.size.y - 12.0 - _acc(m) * (c.size.y - 40.0))
			c.draw_circle(p, 1.5, LabLibrary.CYAN)
			if m > 1:
				c.draw_line(prev, p, Color(LabLibrary.CYAN, 0.6), 1.0)
			prev = p
		var ty := c.size.y - 12.0 - 0.85 * (c.size.y - 40.0)
		c.draw_line(Vector2(10, ty), Vector2(c.size.x - 10.0, ty),
			Color(LabLibrary.GOLD, 0.6), 1.0)
		LabLibrary.txt(c, Vector2(10, 12), "single tree is right 65 percent of the time",
			LabLibrary.DIM, 7)

	func status() -> String:
		return "%d trees voting, accuracy %.0f%%  target 85%%" % [n, _acc(n) * 100.0]

	func hint() -> String:
		return "Left/Right add or remove trees"


# 9: hammer correction rounds; too many overfits.
class BoostLab extends BaseLab:
	var r := 0

	func _train(rounds: int) -> float:
		return 0.9 * pow(0.76, rounds)

	func _test(rounds: int) -> float:
		var over: float = maxf(0.0, rounds - 8.0)
		return _train(rounds) + 0.06 + 0.011 * over * over

	func handle(action: String) -> void:
		match action:
			"ok", "right": r = mini(14, r + 1)
			"left": r = maxi(0, r - 1)
		if _test(r) <= 0.17:
			done = true

	func render(c: Control) -> void:
		for i in range(0, r + 1):
			var x := 10.0 + i * (c.size.x - 20.0) / 14.0
			var yt := c.size.y - 12.0 - _train(i) * (c.size.y - 36.0)
			var ye := c.size.y - 12.0 - _test(i) * (c.size.y - 36.0)
			c.draw_circle(Vector2(x, yt), 1.5, LabLibrary.CYAN)
			c.draw_circle(Vector2(x, ye), 1.5, LabLibrary.GOLD)
		var glow := _test(r)
		c.draw_circle(Vector2(c.size.x - 24.0, 24.0), 4.0 + glow * 22.0,
			Color(LabLibrary.RED, 0.25 + glow * 0.5))
		LabLibrary.txt(c, Vector2(10, 12), "cyan train, gold TEST error", LabLibrary.DIM, 7)

	func status() -> String:
		var warn := "  (overfitting!)" if r > 9 else ""
		return "rounds %d  test error %.2f  target 0.17%s" % [r, _test(r), warn]

	func hint() -> String:
		return "OK hammers a round, Left undoes"


# 10 and 14 share a threshold engine with different framing.
class ThresholdLab extends BaseLab:
	var t := 0.5
	var neg: Array = []
	var pos: Array = []
	var neg_label := "honest"
	var pos_label := "target"

	func setup() -> void:
		for i in 20:
			neg.append(clampf(0.33 + rng.randf_range(-0.18, 0.18), 0.02, 0.98))
		for i in 8:
			pos.append(clampf(0.7 + rng.randf_range(-0.16, 0.16), 0.02, 0.98))

	func _counts() -> Dictionary:
		var tp := 0
		var fp := 0
		for s in pos:
			if s >= t:
				tp += 1
		for s in neg:
			if s >= t:
				fp += 1
		return {"tp": tp, "fp": fp, "fn": pos.size() - tp}

	func _f1() -> float:
		var k := _counts()
		var tp: int = k["tp"]
		if tp == 0:
			return 0.0
		var precision := float(tp) / float(tp + k["fp"])
		var recall := float(tp) / float(tp + k["fn"])
		return 2.0 * precision * recall / (precision + recall)

	func handle(action: String) -> void:
		match action:
			"left": t -= 0.02
			"right": t += 0.02
		t = clampf(t, 0.02, 0.98)
		_win_check()

	func _win_check() -> void:
		if _f1() >= 0.85:
			done = true

	func render(c: Control) -> void:
		_draw_scores(c, neg, 0.68, LabLibrary.CYAN)
		_draw_scores(c, pos, 0.3, LabLibrary.GOLD)
		var x := 8.0 + t * (c.size.x - 16.0)
		c.draw_line(Vector2(x, 12.0), Vector2(x, c.size.y - 12.0),
			LabLibrary.GOLD if done else LabLibrary.RED, 2.0)
		LabLibrary.txt(c, Vector2(10, 12), "flagged if score is right of the line",
			LabLibrary.DIM, 7)

	func _draw_scores(c: Control, scores: Array, v: float, col: Color) -> void:
		var stack := {}
		for s in scores:
			var bucket := int(s * 24.0)
			stack[bucket] = stack.get(bucket, 0) + 1
			c.draw_circle(LabLibrary.pt(c, s, v + stack[bucket] * 0.035), 2.0, col)

	func status() -> String:
		var k := _counts()
		var tp := int(k["tp"])
		var fp := int(k["fp"])
		var fn := int(k["fn"])
		var precision := 0.0 if tp + fp == 0 else float(tp) / (tp + fp)
		var recall := float(tp) / maxi(1, tp + fn)
		return "P %.2f  R %.2f  F1 %.2f  need 0.85" % [precision, recall, _f1()]

	func hint() -> String:
		return "Left/Right slide the threshold"


class AnomalyLab extends ThresholdLab:
	func setup() -> void:
		for i in 20:
			neg.append(clampf(0.3 + rng.randf_range(-0.16, 0.16), 0.02, 0.98))
		for i in 5:
			pos.append(clampf(0.76 + rng.randf_range(-0.12, 0.12), 0.02, 0.98))

	func _win_check() -> void:
		var k := _counts()
		if k["tp"] >= 4 and k["fp"] <= 2:
			done = true

	func status() -> String:
		var k := _counts()
		return "smugglers caught %d/5  merchants harassed %d (max 2)" % [k["tp"], k["fp"]]


# 11: step the torches until nothing moves.
class KmeansLab extends BaseLab:
	var px: Array = []
	var py: Array = []
	var assign: Array = []
	var cx: Array = []
	var cy: Array = []
	var phase := "assign"
	var steps := 0

	func setup() -> void:
		var centers := [[0.25, 0.7], [0.7, 0.75], [0.55, 0.25]]
		for b in 3:
			for i in 6:
				px.append(clampf(centers[b][0] + rng.randf_range(-0.1, 0.1), 0.03, 0.97))
				py.append(clampf(centers[b][1] + rng.randf_range(-0.1, 0.1), 0.03, 0.97))
				assign.append(-1)
		for j in 3:
			cx.append(rng.randf_range(0.2, 0.8))
			cy.append(rng.randf_range(0.2, 0.8))

	func handle(action: String) -> void:
		if action != "ok" or done:
			return
		steps += 1
		if phase == "assign":
			var changed := 0
			for i in px.size():
				var bestj := 0
				var bestd := 99.0
				for j in 3:
					var dd := Vector2(px[i] - cx[j], py[i] - cy[j]).length()
					if dd < bestd:
						bestd = dd
						bestj = j
				if assign[i] != bestj:
					changed += 1
					assign[i] = bestj
			if changed == 0 and steps > 2:
				done = true
			phase = "move"
		else:
			for j in 3:
				var sx := 0.0
				var sy := 0.0
				var n := 0
				for i in px.size():
					if assign[i] == j:
						sx += px[i]
						sy += py[i]
						n += 1
				if n > 0:
					cx[j] = sx / n
					cy[j] = sy / n
			phase = "assign"

	func render(c: Control) -> void:
		var cols := [LabLibrary.CYAN, LabLibrary.GOLD, LabLibrary.GREEN]
		for i in px.size():
			var col: Color = LabLibrary.DIM if assign[i] < 0 else cols[assign[i]]
			c.draw_circle(LabLibrary.pt(c, px[i], py[i]), 2.5, col)
		for j in 3:
			var p := LabLibrary.pt(c, cx[j], cy[j])
			c.draw_line(p - Vector2(4, 4), p + Vector2(4, 4), cols[j], 2.0)
			c.draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), cols[j], 2.0)

	func status() -> String:
		var next := "assign gems" if phase == "assign" else "move torches"
		return "converged!" if done else "OK to %s (step %d)" % [next, steps]

	func hint() -> String:
		return "OK steps the algorithm"


# 12: merge nearest clusters until three remain.
class HierarchyLab extends BaseLab:
	var px: Array = []
	var py: Array = []
	var clusters: Array = []
	var links: Array = []

	func setup() -> void:
		var centers := [[0.2, 0.75], [0.72, 0.7], [0.5, 0.22]]
		for b in 3:
			for i in 3:
				px.append(clampf(centers[b][0] + rng.randf_range(-0.09, 0.09), 0.03, 0.97))
				py.append(clampf(centers[b][1] + rng.randf_range(-0.09, 0.09), 0.03, 0.97))
		for i in px.size():
			clusters.append([i])

	func _centroid(cl: Array) -> Vector2:
		var s := Vector2.ZERO
		for i in cl:
			s += Vector2(px[i], py[i])
		return s / cl.size()

	func handle(action: String) -> void:
		if action != "ok" or done:
			return
		var bi := 0
		var bj := 1
		var bd := 99.0
		for i in clusters.size():
			for j in range(i + 1, clusters.size()):
				var dd := _centroid(clusters[i]).distance_to(_centroid(clusters[j]))
				if dd < bd:
					bd = dd
					bi = i
					bj = j
		links.append([_centroid(clusters[bi]), _centroid(clusters[bj])])
		var merged: Array = clusters[bi] + clusters[bj]
		clusters.remove_at(bj)
		clusters.remove_at(bi)
		clusters.append(merged)
		if clusters.size() == 3:
			done = true

	func render(c: Control) -> void:
		for l in links:
			c.draw_line(LabLibrary.pt(c, l[0].x, l[0].y), LabLibrary.pt(c, l[1].x, l[1].y),
				Color(LabLibrary.DIM, 0.7), 1.0)
		var cols := [LabLibrary.CYAN, LabLibrary.GOLD, LabLibrary.GREEN,
			LabLibrary.RED, LabLibrary.XP_BLUE, LabLibrary.TEXT,
			Color("#e0a040"), Color("#b57ee0"), Color("#8fe08a")]
		for ci in clusters.size():
			for i in clusters[ci]:
				c.draw_circle(LabLibrary.pt(c, px[i], py[i]), 2.5, cols[ci % cols.size()])

	func status() -> String:
		return "clusters: %d  (merge until 3)" % clusters.size()

	func hint() -> String:
		return "OK merges the two nearest clusters"


# 13: spin an axis to capture the most variance.
class PcaLab extends BaseLab:
	var theta := 0.0
	var pts: Array = []
	var varmax := 0.0

	func setup() -> void:
		var phi := rng.randf_range(0.3, 1.2)
		var dir := Vector2(cos(phi), sin(phi))
		var perp := Vector2(-dir.y, dir.x)
		for i in 16:
			var p := Vector2(0.5, 0.5) + dir * rng.randf_range(-0.34, 0.34) \
				+ perp * rng.randf_range(-0.06, 0.06)
			pts.append(Vector2(clampf(p.x, 0.03, 0.97), clampf(p.y, 0.03, 0.97)))
		for s in 180:
			varmax = maxf(varmax, _variance(s * PI / 180.0))

	func _variance(ang: float) -> float:
		var axis := Vector2(cos(ang), sin(ang))
		var mean := 0.0
		var projections: Array = []
		for p in pts:
			var proj: float = (p - Vector2(0.5, 0.5)).dot(axis)
			projections.append(proj)
			mean += proj
		mean /= projections.size()
		var v := 0.0
		for proj in projections:
			v += (proj - mean) * (proj - mean)
		return v / projections.size()

	func handle(action: String) -> void:
		match action:
			"left": theta -= 0.06
			"right": theta += 0.06
		if _variance(theta) >= 0.92 * varmax:
			done = true

	func render(c: Control) -> void:
		var axis := Vector2(cos(theta), sin(theta))
		for p in pts:
			var sp := LabLibrary.pt(c, p.x, p.y)
			c.draw_circle(sp, 2.0, LabLibrary.TEXT)
			var proj: Vector2 = Vector2(0.5, 0.5) + axis * (p - Vector2(0.5, 0.5)).dot(axis)
			c.draw_line(sp, LabLibrary.pt(c, proj.x, proj.y), Color(LabLibrary.DIM, 0.3), 1.0)
			c.draw_circle(LabLibrary.pt(c, proj.x, proj.y), 1.2, LabLibrary.XP_BLUE)
		var e0 := Vector2(0.5, 0.5) + axis * 0.55
		var e1 := Vector2(0.5, 0.5) - axis * 0.55
		c.draw_line(LabLibrary.pt(c, e0.x, e0.y), LabLibrary.pt(c, e1.x, e1.y),
			LabLibrary.GOLD if done else LabLibrary.CYAN, 2.0)
		var frac := _variance(theta) / varmax
		c.draw_rect(Rect2(10, 8, (c.size.x - 20.0) * frac, 4), LabLibrary.GOLD)
		c.draw_rect(Rect2(10, 8, c.size.x - 20.0, 4), Color(LabLibrary.DIM, 0.4), false, 1.0)

	func status() -> String:
		return "variance captured %.0f%%  need 92%%" % (_variance(theta) / varmax * 100.0)

	func hint() -> String:
		return "Left/Right spin the axis"


# 15: fill the missing rating from the kindred row.
class MatrixLab extends BaseLab:
	var grid: Array = []
	var guess := 3
	var answer := 0
	var similar_row := 0

	func setup() -> void:
		grid = [
			[5, 3, 4, 4],
			[4, 2, 4, 5],
			[1, 5, 2, 1],
			[4, 2, 4, -1],
		]
		similar_row = 1
		answer = grid[similar_row][3]

	func handle(action: String) -> void:
		match action:
			"left": guess = maxi(1, guess - 1)
			"right": guess = mini(5, guess + 1)
			"ok":
				if guess == answer:
					done = true
				else:
					flash = "Find the row most like the bottom row."

	func render(c: Control) -> void:
		var names := ["Ana", "Bel", "Cor", "YOU"]
		var items := ["rope", "map", "torch", "boat"]
		var cw := 30.0
		var ox := 44.0
		for j in 4:
			LabLibrary.txt(c, Vector2(ox + j * cw, 14), items[j], LabLibrary.DIM, 6)
		for i in 4:
			var row_col := LabLibrary.TEXT
			if i == similar_row:
				row_col = LabLibrary.GREEN
			LabLibrary.txt(c, Vector2(8, 30 + i * 20), names[i],
				LabLibrary.GOLD if i == 3 else row_col, 7)
			for j in 4:
				var v: int = grid[i][j]
				var cell := Rect2(ox + j * cw - 4, 20 + i * 20, cw - 6, 14)
				if v < 0:
					c.draw_rect(cell, Color(LabLibrary.GOLD, 0.25))
					LabLibrary.txt(c, cell.position + Vector2(8, 11),
						str(guess) + "?", LabLibrary.GOLD, 8)
				else:
					LabLibrary.txt(c, cell.position + Vector2(8, 11), str(v), row_col, 8)

	func status() -> String:
		return "Whose past ratings mirror YOURS?"

	func hint() -> String:
		return "Left/Right set the rating, OK fills it"


# 16: tune two weights; the boundary is their perpendicular.
class NeuronLab extends BaseLab:
	var w1 := 0.2
	var w2 := -0.6
	var px: Array = []
	var py: Array = []
	var cls: Array = []

	func setup() -> void:
		var phi := rng.randf_range(0.0, PI)
		var w0 := Vector2(cos(phi), sin(phi))
		var n := 0
		while n < 12:
			var p := Vector2(rng.randf_range(0.05, 0.95), rng.randf_range(0.05, 0.95))
			var f := (p - Vector2(0.5, 0.5)).dot(w0)
			if absf(f) < 0.08:
				continue
			px.append(p.x)
			py.append(p.y)
			cls.append(1 if f > 0.0 else 0)
			n += 1

	func _acc() -> int:
		var n := 0
		for i in px.size():
			var f: float = w1 * (float(px[i]) - 0.5) + w2 * (float(py[i]) - 0.5)
			if (1 if f > 0.0 else 0) == int(cls[i]):
				n += 1
		return n

	func handle(action: String) -> void:
		match action:
			"left": w1 -= 0.15
			"right": w1 += 0.15
			"up": w2 += 0.15
			"down": w2 -= 0.15
		w1 = clampf(w1, -1.5, 1.5)
		w2 = clampf(w2, -1.5, 1.5)
		if _acc() == 12 and Vector2(w1, w2).length() > 0.2:
			done = true

	func render(c: Control) -> void:
		for i in px.size():
			var col := LabLibrary.CYAN if cls[i] == 0 else LabLibrary.GOLD
			c.draw_circle(LabLibrary.pt(c, px[i], py[i]), 2.5, col)
		var w := Vector2(w1, w2)
		if w.length() > 0.05:
			var dir := Vector2(-w.y, w.x).normalized()
			var e0 := Vector2(0.5, 0.5) + dir * 0.7
			var e1 := Vector2(0.5, 0.5) - dir * 0.7
			c.draw_line(LabLibrary.pt(c, e0.x, e0.y), LabLibrary.pt(c, e1.x, e1.y),
				LabLibrary.GOLD if done else LabLibrary.TEXT, 2.0)
			var tip := Vector2(0.5, 0.5) + w.normalized() * 0.16
			c.draw_line(LabLibrary.pt(c, 0.5, 0.5), LabLibrary.pt(c, tip.x, tip.y),
				LabLibrary.GREEN, 1.0)

	func status() -> String:
		return "w1 %.2f  w2 %.2f  sorted %d/12" % [w1, w2, _acc()]

	func hint() -> String:
		return "Left/Right w1, Up/Down w2"


# 17: learning rate roulette on a loss valley.
class DescentLab extends BaseLab:
	const RATES := [0.05, 0.2, 0.45, 1.05]
	var rate_i := 1
	var x := 0.08
	var trail: Array = []
	var minx := 0.62

	func _loss(v: float) -> float:
		return (v - minx) * (v - minx) * 2.2

	func handle(action: String) -> void:
		match action:
			"left": rate_i = maxi(0, rate_i - 1)
			"right": rate_i = mini(RATES.size() - 1, rate_i + 1)
			"up":
				x = 0.08
				trail.clear()
			"ok":
				trail.append(x)
				if trail.size() > 14:
					trail.pop_front()
				x = x - float(RATES[rate_i]) * 2.0 * 2.2 * (x - minx)
				x = clampf(x, -0.3, 1.3)
				if absf(x - minx) < 0.02:
					done = true

	func render(c: Control) -> void:
		var prev := Vector2.ZERO
		for i in 40:
			var u := i / 39.0
			var p := LabLibrary.pt(c, u, clampf(_loss(u) * 1.6, 0.0, 1.0))
			if i > 0:
				c.draw_line(prev, p, LabLibrary.DIM, 1.0)
			prev = p
		for t in trail:
			var tu := clampf(t, 0.0, 1.0)
			c.draw_circle(LabLibrary.pt(c, tu, clampf(_loss(tu) * 1.6, 0.0, 1.0)),
				1.5, Color(LabLibrary.XP_BLUE, 0.5))
		var bu := clampf(x, 0.0, 1.0)
		c.draw_circle(LabLibrary.pt(c, bu, clampf(_loss(bu) * 1.6, 0.0, 1.0)),
			3.5, LabLibrary.GOLD if done else LabLibrary.RED)

	func status() -> String:
		var s := "lr %.2f  loss %.3f" % [float(RATES[rate_i]), _loss(x)]
		if absf(x - minx) > 0.6:
			s += "  DIVERGING"
		return s

	func hint() -> String:
		return "Left/Right pick rate, OK steps, Up resets"


# 18: slide a filter, light up the hidden pattern.
class ConvLab extends BaseLab:
	const W := 9
	const H := 6
	var grid: Array = []
	var fx := 0
	var fy := 0
	var best_x := 0
	var best_y := 0
	var visited: Dictionary = {}

	func setup() -> void:
		for yy in H:
			var row: Array = []
			for xx in W:
				row.append(1 if rng.randf() < 0.16 else 0)
			grid.append(row)
		best_x = rng.randi_range(0, W - 3)
		best_y = rng.randi_range(0, H - 3)
		for i in 3:
			grid[best_y + 1][best_x + i] = 1
			grid[best_y + i][best_x + 1] = 1
		grid[best_y][best_x] = 0
		grid[best_y][best_x + 2] = 0
		grid[best_y + 2][best_x] = 0
		grid[best_y + 2][best_x + 2] = 0

	func _response(ax: int, ay: int) -> int:
		var s := 0
		for dy in 3:
			for dx in 3:
				var is_plus := dx == 1 or dy == 1
				s += int(grid[ay + dy][ax + dx]) * (2 if is_plus else -2)
		return s

	func handle(action: String) -> void:
		match action:
			"left": fx = maxi(0, fx - 1)
			"right": fx = mini(W - 3, fx + 1)
			"up": fy = maxi(0, fy - 1)
			"down": fy = mini(H - 3, fy + 1)
			"ok":
				if _response(fx, fy) >= _response(best_x, best_y):
					done = true
				else:
					flash = "A brighter response hides elsewhere."
		visited[Vector2i(fx, fy)] = _response(fx, fy)

	func render(c: Control) -> void:
		var cell := minf((c.size.x - 20.0) / W, (c.size.y - 30.0) / H)
		var ox := (c.size.x - cell * W) / 2.0
		var oy := 20.0
		for v in visited:
			var strength: float = clampf(visited[v] / 10.0, 0.0, 1.0)
			c.draw_rect(Rect2(ox + v.x * cell, oy + v.y * cell, cell * 3, cell * 3),
				Color(LabLibrary.GOLD.r, LabLibrary.GOLD.g, 0.2, strength * 0.12))
		for yy in H:
			for xx in W:
				var r := Rect2(ox + xx * cell + 1, oy + yy * cell + 1, cell - 2, cell - 2)
				c.draw_rect(r, LabLibrary.CYAN if grid[yy][xx] == 1 else Color(1, 1, 1, 0.07))
		c.draw_rect(Rect2(ox + fx * cell, oy + fy * cell, cell * 3, cell * 3),
			LabLibrary.GOLD if done else LabLibrary.RED, false, 2.0)
		LabLibrary.txt(c, Vector2(10, 12),
			"filter matches a plus sign shape", LabLibrary.DIM, 7)

	func status() -> String:
		return "response here: %d" % _response(fx, fy)

	func hint() -> String:
		return "Arrows slide the filter, OK claims the peak"


# 19: guard the memory gate along the sequence.
class GateLab extends BaseLab:
	var step := 0
	var gate_open := false
	var memory := 1.0
	var corrupted := false

	func handle(action: String) -> void:
		if done:
			return
		match action:
			"up", "down":
				gate_open = not gate_open
			"ok":
				if step < 5:
					if gate_open:
						corrupted = true
						memory = 0.15
						flash = "A distractor flooded in! Up to reset."
					step += 1
				else:
					if gate_open and not corrupted:
						done = true
					elif not gate_open:
						flash = "Delivery needs the gate OPEN at the end."
					else:
						flash = "The message was lost. Up resets the run."
			"left":
				pass
		if corrupted and (action == "up" or action == "down"):
			step = 0
			memory = 1.0
			corrupted = false
			gate_open = false
			flash = "Run restarted."

	func render(c: Control) -> void:
		var w := (c.size.x - 30.0) / 6.0
		for i in 6:
			var x := 15.0 + i * w
			var r := Rect2(x, c.size.y * 0.5 - 8, w - 6, 16)
			var col := Color(LabLibrary.DIM, 0.3)
			if i < step:
				col = Color(LabLibrary.GREEN, 0.4)
			elif i == step:
				col = Color(LabLibrary.GOLD, 0.5)
			c.draw_rect(r, col)
			LabLibrary.txt(c, r.position + Vector2(2, -4),
				"OUT" if i == 5 else "x%d" % (i + 1), LabLibrary.DIM, 6)
		var mh := memory * 26.0
		c.draw_rect(Rect2(16, c.size.y - 44 - mh, 14, mh),
			LabLibrary.RED if corrupted else LabLibrary.XP_BLUE)
		LabLibrary.txt(c, Vector2(14, c.size.y - 34), "memory", LabLibrary.DIM, 6)
		var gate_col := LabLibrary.GREEN if gate_open else LabLibrary.RED
		LabLibrary.txt(c, Vector2(c.size.x - 74, c.size.y - 40),
			"gate: %s" % ("OPEN" if gate_open else "CLOSED"), gate_col, 8)

	func status() -> String:
		if step < 5:
			return "step %d of 6: distractors incoming, hold the gate" % (step + 1)
		return "final step: deliver the message"

	func hint() -> String:
		return "Up toggles the gate, OK advances"


# 20: point attention at the right word.
class AttentionLab extends BaseLab:
	const WORDS := ["The", "shard", "glowed", "because", "it", "was", "charged"]
	const WEIGHTS := [0.02, 0.8, 0.08, 0.02, 0.0, 0.03, 0.05]
	var cursor := 0
	var revealed := false

	func handle(action: String) -> void:
		match action:
			"left": cursor = maxi(0, cursor - 1)
			"right": cursor = mini(WORDS.size() - 1, cursor + 1)
			"ok":
				revealed = true
				if cursor == 1:
					done = true
				else:
					flash = "The weights disagree. What does IT refer to?"

	func render(c: Control) -> void:
		LabLibrary.txt(c, Vector2(10, 16), "Query token: \"it\"", LabLibrary.GOLD, 8)
		var x := 10.0
		var y := c.size.y * 0.62
		for i in WORDS.size():
			var wtext: String = WORDS[i]
			var wpx := wtext.length() * 6.0 + 6.0
			if x + wpx > c.size.x - 10.0:
				x = 10.0
				y += 24.0
			if revealed:
				var bh: float = WEIGHTS[i] * 34.0
				c.draw_rect(Rect2(x, y - 14 - bh, wpx - 4, bh),
					Color(LabLibrary.XP_BLUE, 0.8))
			var col := LabLibrary.TEXT
			if i == 4:
				col = LabLibrary.GOLD
			if i == cursor:
				c.draw_rect(Rect2(x - 2, y - 10, wpx, 14),
					Color(LabLibrary.GREEN, 0.25))
			LabLibrary.txt(c, Vector2(x, y), wtext, col, 8)
			x += wpx + 4.0

	func status() -> String:
		return "attention weights revealed" if revealed else "aim, then OK to attend"

	func hint() -> String:
		return "Left/Right aim attention, OK commits"

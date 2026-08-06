extends Node3D
## Dev-only survey rig that photographs ALL of Datasedge Meadows (GDD §10:
## visual work needs eyes). Instances the real main scene — so grass, flora,
## irises, forage, clouds, motes and vistas are all live exactly as they ship —
## then flies its own camera through a full tour: aerial overviews from four
## bearings, every canonical landmark site, the region's four borders, ground
## detail, and a time-of-day set.
##
## Built so Danny can judge "is the meadow done?" from one contact sheet rather
## than a handful of lucky angles. Positions come from the canonical map coords
## in MeadowLandmarks/MeadowTerrain, so the tour stays honest as the region
## iterates.
##
## Run:
##   godot --path game res://scenes/dev/meadow_survey.tscn -- --surveydir=C:/abs/dir
## Never part of the shipped game; nothing else references this scene.

## Metres of clearance kept between an aerial camera and the ground below it.
const AERIAL_CLEARANCE: float = 12.0

var _main: Node3D
var _camera: Camera3D
var _terrain: MeadowTerrain
var _peaks: GradientPeaks


func _ready() -> void:
	var dir: String = _survey_dir()
	if dir == "":
		push_error("MeadowSurvey: pass -- --surveydir=C:/abs/dir")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1600, 900)
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_camera = Camera3D.new()
	_camera.name = "SurveyCamera"
	_camera.fov = 62.0
	_camera.far = 6000.0
	_camera.environment = _make_environment()
	add_child(_camera)
	_capture_all.call_deferred(dir)


func _survey_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--surveydir="):
			return arg.get_slice("=", 1)
	return ""


## The survey carries its own Environment so captures stay judgeable even while
## another lane has the shared scene's sky/cloud settings mid-surgery.
func _make_environment() -> Environment:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.48, 0.88)
	sky_material.sky_horizon_color = Color(0.74, 0.85, 0.95)
	sky_material.ground_bottom_color = Color(0.25, 0.32, 0.22)
	sky_material.ground_horizon_color = Color(0.66, 0.76, 0.62)
	sky_material.sun_angle_max = 8.0
	sky_material.sun_curve = 0.08
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.88
	environment.glow_enabled = true
	environment.glow_intensity = 0.48
	environment.glow_bloom = 0.1
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.82, 0.9)
	environment.fog_density = 0.00028
	environment.fog_sky_affect = 0.04
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.1
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.6
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_cascades = 5
	environment.sdfgi_max_distance = 400.0
	environment.sdfgi_read_sky_light = true
	return environment


func _capture_all(dir: String) -> void:
	_terrain = _main.get_node("World/Terrain") as MeadowTerrain
	_peaks = _main.get_node_or_null("World/Vistas/ClimbablePeaks") as GradientPeaks
	# Keep the frame clean: Kern's body, Bit, the floating name labels and the
	# HUD all sit on the lens and hide the world this survey is judging.
	_hide(_main.get_node_or_null("Player/Visual"))
	_hide(_main.get_node_or_null("Bit"))
	_hide(_main.get_node_or_null("World/Landmarks"))
	_hide(_main.get_node_or_null("CombatHud"))
	var cycle: SkyCycle = _main.get_node_or_null("World/SkyCycle") as SkyCycle
	if cycle != null:
		cycle.paused = true
		cycle.set_hour(10.2)
	_camera.current = true

	for i in 150:  # SDFGI / TAA convergence before the first frame
		await get_tree().process_frame

	for shot in _shots():
		await _take(dir, shot)

	# Time-of-day set over the town view — the same frame across the color script.
	if cycle != null:
		for tod in [
			{"name": "23_tod_dawn", "hour": 6.2},
			{"name": "24_tod_noon", "hour": 13.0},
			{"name": "25_tod_dusk", "hour": 17.8},
			{"name": "26_tod_night", "hour": 22.0},
		]:
			cycle.set_hour(float(tod["hour"]))
			await _take(dir, {
				"name": tod["name"], "pos": Vector2(-70.0, 120.0), "up": 16.0,
				"aim": Vector2(0.0, 24.0), "aim_up": 6.0, "fov": 66.0,
			})
	get_tree().quit()


func _hide(node: Node) -> void:
	if node != null and "visible" in node:
		node.set("visible", false)


## One capture. `pos`/`aim` are world XZ in metres; `up`/`aim_up` are metres
## above the sampled ground at those points, so framing survives terrain edits.
## `abs_y` overrides the camera height for the high aerials.
func _take(dir: String, shot: Dictionary) -> void:
	var flat: Vector2 = shot["pos"]
	var eye_y: float = 0.0
	if shot.has("abs_y"):
		eye_y = maxf(float(shot["abs_y"]), _surface_height(flat) + AERIAL_CLEARANCE)
	else:
		eye_y = _surface_height(flat) + float(shot["up"])
	_camera.position = Vector3(flat.x, eye_y, flat.y)
	var aim_flat: Vector2 = shot["aim"]
	_camera.look_at(Vector3(
		aim_flat.x, _surface_height(aim_flat) + float(shot["aim_up"]), aim_flat.y
	))
	_camera.fov = float(shot["fov"]) if shot.has("fov") else 62.0
	for i in 40:
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = dir.path_join(String(shot["name"]) + ".png")
	print("Survey %s -> %s" % ["OK" if image.save_png(path) == OK else "FAILED", path])


## Canonical site coordinates match MeadowLandmarks so Bit's naming, the future
## POI props, and these captures always describe the same geography.
func _shots() -> Array[Dictionary]:
	return [
		# ---- aerial overviews of the full 2.4 km region ----
		{"name": "01_aerial_south_north", "pos": Vector2(0.0, 1900.0), "abs_y": 780.0,
			"aim": Vector2(0.0, -300.0), "aim_up": 120.0, "fov": 72.0},
		{"name": "02_aerial_west_east", "pos": Vector2(-1900.0, 0.0), "abs_y": 740.0,
			"aim": Vector2(200.0, 10.0), "aim_up": 90.0, "fov": 72.0},
		{"name": "03_aerial_north_south", "pos": Vector2(-40.0, -1500.0), "abs_y": 800.0,
			"aim": Vector2(0.0, 400.0), "aim_up": 60.0, "fov": 72.0},
		{"name": "04_aerial_east_west", "pos": Vector2(1900.0, 60.0), "abs_y": 740.0,
			"aim": Vector2(-160.0, 0.0), "aim_up": 90.0, "fov": 72.0},
		{"name": "05_aerial_high_oblique", "pos": Vector2(1150.0, 1300.0), "abs_y": 900.0,
			"aim": Vector2(-160.0, -200.0), "aim_up": 60.0, "fov": 76.0},

		# ---- Bootstrap ----
		{"name": "06_bootstrap_town_site", "pos": Vector2(-96.0, 150.0), "up": 4.0,
			"aim": Vector2(0.0, 30.0), "aim_up": 3.0, "fov": 66.0},
		{"name": "07_bootstrap_aerial", "pos": Vector2(-40.0, 190.0), "abs_y": 120.0,
			"aim": Vector2(10.0, 20.0), "aim_up": 4.0, "fov": 70.0},

		# ---- the newly raised points of interest ----
		{"name": "08_seed_vault_ruins", "pos": Vector2(-284.0, -222.0), "up": 3.0,
			"aim": Vector2(-320.0, -260.0), "aim_up": 1.5, "fov": 66.0},
		{"name": "09_shrine_first_light", "pos": Vector2(-404.0, -118.0), "up": 3.0,
			"aim": Vector2(-436.0, -150.0), "aim_up": 3.0, "fov": 64.0},
		{"name": "10_whispering_well", "pos": Vector2(202.0, 82.0), "up": 2.2,
			"aim": Vector2(212.0, 62.0), "aim_up": 1.5},
		{"name": "11_hivewise_apiary", "pos": Vector2(310.0, -98.0), "up": 2.6,
			"aim": Vector2(332.0, -120.0), "aim_up": 1.0, "fov": 66.0},
		{"name": "12_boundary_stones", "pos": Vector2(124.0, -408.0), "up": 2.6,
			"aim": Vector2(150.0, -430.0), "aim_up": 1.5},
		{"name": "13_ascent_tally_knoll", "pos": Vector2(-66.0, -740.0), "up": 2.6,
			"aim": Vector2(-90.0, -764.0), "aim_up": 2.0},
		{"name": "14_sluicework", "pos": Vector2(-158.0, 262.0), "up": 3.0,
			"aim": Vector2(-182.0, 286.0), "aim_up": 0.5, "fov": 68.0},
		{"name": "15_tempering_pool", "pos": Vector2(240.0, 760.0), "up": 2.6,
			"aim": Vector2(262.0, 782.0), "aim_up": 0.3},
		{"name": "16_hillwatchers_camp", "pos": Vector2(-498.0, -498.0), "up": 2.6,
			"aim": Vector2(-520.0, -520.0), "aim_up": 1.0},
		{"name": "17_sunken_granary", "pos": Vector2(-738.0, 400.0), "up": 3.0,
			"aim": Vector2(-762.0, 424.0), "aim_up": 1.0},
		{"name": "18_petal_brokers_wagon", "pos": Vector2(-858.0, -100.0), "up": 2.6,
			"aim": Vector2(-880.0, -122.0), "aim_up": 1.2},
		{"name": "19_long_fallow", "pos": Vector2(596.0, 490.0), "up": 3.2,
			"aim": Vector2(624.0, 520.0), "aim_up": 0.8, "fov": 68.0},
		{"name": "20_thresher_fallow", "pos": Vector2(724.0, -524.0), "up": 3.4,
			"aim": Vector2(760.0, -560.0), "aim_up": 0.8, "fov": 70.0},
		{"name": "21_wayfinders_nook", "pos": Vector2(-122.0, 360.0), "up": 2.0,
			"aim": Vector2(-140.0, 380.0), "aim_up": 1.0},
		{"name": "22_deepgreen_overlook", "pos": Vector2(1022.0, 100.0), "up": 2.6,
			"aim": Vector2(1046.0, 120.0), "aim_up": 1.2, "fov": 66.0},

		# ---- the long views that prove the new scale ----
		{"name": "23_border_north_peaks", "pos": Vector2(-20.0, -300.0), "up": 4.0,
			"aim": Vector2(20.0, -1520.0), "aim_up": 320.0, "fov": 68.0},
		{"name": "24_border_west_sea", "pos": Vector2(-900.0, 10.0), "up": 4.0,
			"aim": Vector2(-1900.0, 0.0), "aim_up": 6.0, "fov": 66.0},
		{"name": "25_long_view_south", "pos": Vector2(0.0, -600.0), "up": 6.0,
			"aim": Vector2(0.0, 900.0), "aim_up": 20.0, "fov": 72.0},
	]


## Ground height at a point — the peaks own their footprint, the meadow the rest.
func _surface_height(flat: Vector2) -> float:
	if _peaks != null and _peaks.in_bounds(flat.x, flat.y):
		return _peaks.get_height(flat.x, flat.y)
	if _terrain != null:
		return _terrain.get_height(flat.x, flat.y)
	return 0.0

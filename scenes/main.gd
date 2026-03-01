extends Node2D

const ISLAND_RADIUS := 350.0
const ISO := 0.5

# Warm pastel palette matching concept art
const SKY_TOP := Color(0.72, 0.62, 0.78)
const SKY_MID := Color(0.82, 0.68, 0.72)
const SKY_BOT := Color(0.90, 0.78, 0.70)
const GRASS_TOP := Color(0.45, 0.74, 0.35)
const GRASS_LIGHT := Color(0.52, 0.80, 0.40)
const DIRT_COLOR := Color(0.58, 0.40, 0.28)
const DIRT_DARK := Color(0.42, 0.30, 0.22)
const ROCK_COLOR := Color(0.35, 0.32, 0.30)
const ROCK_DARK := Color(0.25, 0.22, 0.20)
const PATH_COLOR := Color(0.62, 0.55, 0.48)
const PATH_DARK := Color(0.52, 0.44, 0.38)

var _cloud_data: Array = []
var _tree_data: Array = []
var _crystal_data: Array = []
var _flower_data: Array = []
var _stone_path_segments: Array = []
var _floating_debris: Array = []
var _time := 0.0

var player_scene := preload("res://scenes/player/player.tscn")
var building_scene := preload("res://scenes/buildings/building.tscn")
var egg_scene := preload("res://scenes/creatures/egg.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")

var building_placements := [
	{ "type": Enums.BuildingType.INCUBATOR, "pos": Vector2(60, -50) },
	{ "type": Enums.BuildingType.REST_ZONE, "pos": Vector2(160, 40) },
	{ "type": Enums.BuildingType.NATURE_CABIN, "pos": Vector2(-150, 20) },
	{ "type": Enums.BuildingType.MAGIC_TOWER, "pos": Vector2(100, -140) },
	{ "type": Enums.BuildingType.MINING_WORKSHOP, "pos": Vector2(-80, 110) },
]

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_generate_clouds(rng)
	_generate_trees(rng)
	_generate_crystals(rng)
	_generate_flowers(rng)
	_generate_stone_paths()
	_generate_floating_debris(rng)

	var game_world := Node2D.new()
	game_world.name = "GameWorld"
	game_world.y_sort_enabled = true
	add_child(game_world)
	GameManager.world_root = game_world

	_place_buildings(game_world)
	_spawn_player(game_world)
	_spawn_initial_eggs()

	var hud = hud_scene.instantiate()
	add_child(hud)
	_setup_camera()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	_draw_sky_gradient()
	_draw_clouds_back()
	_draw_floating_debris()
	_draw_island_layers()
	_draw_stone_paths()
	_draw_grass_details()
	_draw_flowers()
	_draw_crystals()
	_draw_trees()
	_draw_clouds_front()

# ---------- SKY ----------
func _draw_sky_gradient() -> void:
	for i in 24:
		var t := float(i) / 23.0
		var col: Color
		if t < 0.5:
			col = SKY_TOP.lerp(SKY_MID, t * 2.0)
		else:
			col = SKY_MID.lerp(SKY_BOT, (t - 0.5) * 2.0)
		draw_rect(Rect2(-700, -400 + i * 40, 1400, 42), col)

# ---------- CLOUDS ----------
func _generate_clouds(rng: RandomNumberGenerator) -> void:
	for i in 16:
		_cloud_data.append({
			"pos": Vector2(rng.randf_range(-650, 650), rng.randf_range(-380, 380)),
			"scale": rng.randf_range(0.6, 1.4),
			"speed": rng.randf_range(0.03, 0.12),
			"layer": rng.randf_range(0, 1),
		})

func _draw_clouds_back() -> void:
	for c in _cloud_data:
		if c["layer"] < 0.5:
			var p: Vector2 = c["pos"] + Vector2(sin(_time * c["speed"]) * 25, 0)
			_draw_one_cloud(p, c["scale"], 0.18)

func _draw_clouds_front() -> void:
	for c in _cloud_data:
		if c["layer"] >= 0.5:
			var p: Vector2 = c["pos"] + Vector2(sin(_time * c["speed"] + 2.0) * 35, 0)
			_draw_one_cloud(p, c["scale"], 0.22)

func _draw_one_cloud(pos: Vector2, sc: float, alpha: float) -> void:
	var ca := Color(1, 1, 1, alpha)
	var cb := Color(1, 0.97, 0.95, alpha * 0.7)
	draw_circle(pos, 35 * sc, ca)
	draw_circle(pos + Vector2(28, -6) * sc, 25 * sc, ca)
	draw_circle(pos + Vector2(-22, 4) * sc, 22 * sc, cb)
	draw_circle(pos + Vector2(12, 12) * sc, 18 * sc, cb)
	draw_circle(pos + Vector2(-10, -8) * sc, 20 * sc, ca)

# ---------- ISLAND LAYERS ----------
func _draw_island_layers() -> void:
	var rx := ISLAND_RADIUS
	var ry := rx * ISO

	# Layer 3: Rock bottom
	var rock_pts := PackedVector2Array()
	for i in 48:
		var a := float(i) / 47.0 * TAU
		rock_pts.append(Vector2(cos(a) * (rx - 10), sin(a) * (ry - 5) + 55))
	draw_colored_polygon(rock_pts, ROCK_COLOR)
	# Bottom rough edge
	for i in 48:
		var a := float(i) / 47.0 * TAU
		var na := float(i + 1) / 47.0 * TAU
		var r1 := rx - 10 + sin(i * 3.7) * 8
		var r2 := rx - 10 + sin((i + 1) * 3.7) * 8
		var p1 := Vector2(cos(a) * r1, sin(a) * (ry - 5) + 55)
		var p2 := Vector2(cos(na) * r2, sin(na) * (ry - 5) + 55)
		draw_line(p1, p2, ROCK_DARK, 2.0)

	# Layer 2: Dirt sides
	var dirt_pts := PackedVector2Array()
	for i in 48:
		var a := float(i) / 47.0 * TAU
		dirt_pts.append(Vector2(cos(a) * (rx - 4), sin(a) * (ry - 2) + 35))
	draw_colored_polygon(dirt_pts, DIRT_COLOR)
	for i in 48:
		var a := float(i) / 47.0 * TAU
		var na := float(i + 1) / 47.0 * TAU
		if sin(a) > -0.2:
			var p1 := Vector2(cos(a) * (rx - 4), sin(a) * (ry - 2) + 35)
			var p2 := Vector2(cos(na) * (rx - 4), sin(na) * (ry - 2) + 35)
			draw_line(p1, p2, DIRT_DARK, 2.5)
	# Dirt texture lines
	for i in 12:
		var a := 0.2 + i * 0.45
		var x := cos(a) * (rx - 20)
		var y := sin(a) * (ry - 10) + 40
		draw_line(Vector2(x - 8, y), Vector2(x + 8, y + 2), DIRT_DARK.lerp(DIRT_COLOR, 0.5), 1.0)

	# Layer 1: Grass top
	var grass_pts := PackedVector2Array()
	for i in 64:
		var a := float(i) / 63.0 * TAU
		grass_pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(grass_pts, GRASS_TOP)

	# Grass edge highlight (top) and shadow (bottom)
	for i in 64:
		var a := float(i) / 63.0 * TAU
		var na := float(i + 1) / 63.0 * TAU
		var p1 := Vector2(cos(a) * rx, sin(a) * ry)
		var p2 := Vector2(cos(na) * rx, sin(na) * ry)
		var edge_col := GRASS_LIGHT if sin(a) < 0 else DIRT_COLOR
		draw_line(p1, p2, edge_col, 2.5)

func _draw_grass_details() -> void:
	var rx := ISLAND_RADIUS
	var ry := rx * ISO
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99
	for i in 30:
		var a := rng2.randf() * TAU
		var d := rng2.randf_range(0.15, 0.85)
		var px := cos(a) * rx * d
		var py := sin(a) * ry * d
		var r := rng2.randf_range(6, 14)
		var c := GRASS_LIGHT.lerp(GRASS_TOP, rng2.randf_range(0, 1))
		draw_circle(Vector2(px, py), r, c)

# ---------- STONE PATHS ----------
func _generate_stone_paths() -> void:
	_stone_path_segments.clear()
	for i in building_placements.size():
		var p1: Vector2 = building_placements[i]["pos"]
		for j in range(i + 1, building_placements.size()):
			var p2: Vector2 = building_placements[j]["pos"]
			if p1.distance_to(p2) < 300:
				_stone_path_segments.append([p1, p2])
	_stone_path_segments.append([Vector2(0, 50), building_placements[0]["pos"]])

func _draw_stone_paths() -> void:
	for seg in _stone_path_segments:
		var from: Vector2 = seg[0]
		var to: Vector2 = seg[1]
		var steps := int(from.distance_to(to) / 10)
		for i in steps:
			var t := float(i) / maxf(float(steps - 1), 1.0)
			var p := from.lerp(to, t)
			var wobble := Vector2(sin(i * 1.8) * 3, cos(i * 2.1) * 2)
			var size := 4.0 + sin(i * 0.9) * 1.5
			draw_circle(p + wobble, size, PATH_COLOR)
			draw_arc(p + wobble, size, 0, TAU, 8, PATH_DARK, 0.8)

# ---------- TREES ----------
func _generate_trees(rng: RandomNumberGenerator) -> void:
	var rx := ISLAND_RADIUS
	var ry := rx * ISO
	for i in 18:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.35, 0.92)
		var px := cos(a) * rx * d
		var py := sin(a) * ry * d
		var too_close := false
		for bp in building_placements:
			if Vector2(px, py).distance_to(bp["pos"]) < 50:
				too_close = true
				break
		if too_close:
			continue
		_tree_data.append({
			"pos": Vector2(px, py),
			"height": rng.randf_range(28, 50),
			"crown_r": rng.randf_range(14, 24),
			"type": rng.randi_range(0, 2),
		})

func _draw_trees() -> void:
	for t in _tree_data:
		var p: Vector2 = t["pos"]
		var h: float = t["height"]
		var cr: float = t["crown_r"]
		var tp: int = t["type"]
		# Trunk
		var trunk_col := Color(0.45, 0.32, 0.20)
		draw_line(p, p + Vector2(0, -h), trunk_col, 3.5)
		draw_line(p + Vector2(1, 0), p + Vector2(1, -h), trunk_col.lightened(0.15), 1.5)
		match tp:
			0: _draw_round_tree(p + Vector2(0, -h), cr)
			1: _draw_pine_tree(p + Vector2(0, -h), cr)
			2: _draw_bushy_tree(p + Vector2(0, -h), cr)

func _draw_round_tree(top: Vector2, r: float) -> void:
	var leaf_dark := Color(0.28, 0.52, 0.22)
	var leaf_mid := Color(0.35, 0.62, 0.28)
	var leaf_light := Color(0.45, 0.72, 0.35)
	draw_circle(top, r, leaf_dark)
	draw_circle(top + Vector2(r * 0.35, -r * 0.2), r * 0.75, leaf_mid)
	draw_circle(top + Vector2(-r * 0.25, -r * 0.35), r * 0.6, leaf_light)
	draw_circle(top + Vector2(r * 0.1, -r * 0.5), r * 0.4, leaf_light.lightened(0.1))

func _draw_pine_tree(top: Vector2, r: float) -> void:
	var c1 := Color(0.22, 0.48, 0.25)
	var c2 := Color(0.30, 0.58, 0.30)
	for i in 3:
		var y_off := i * r * 0.5
		var w := r * (1.0 - i * 0.2)
		var tri := PackedVector2Array([
			top + Vector2(0, -r + y_off), top + Vector2(w, y_off), top + Vector2(-w, y_off)
		])
		draw_colored_polygon(tri, c1 if i % 2 == 0 else c2)

func _draw_bushy_tree(top: Vector2, r: float) -> void:
	var c := Color(0.32, 0.58, 0.26)
	draw_circle(top, r * 0.9, c)
	draw_circle(top + Vector2(-r * 0.5, r * 0.15), r * 0.65, c.darkened(0.1))
	draw_circle(top + Vector2(r * 0.5, r * 0.2), r * 0.7, c.lightened(0.05))
	draw_circle(top + Vector2(0, -r * 0.3), r * 0.55, c.lightened(0.12))

# ---------- CRYSTALS ----------
func _generate_crystals(rng: RandomNumberGenerator) -> void:
	var rx := ISLAND_RADIUS
	var ry := rx * ISO
	for i in 6:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.5, 0.88)
		var px := cos(a) * rx * d
		var py := sin(a) * ry * d
		var too_close := false
		for bp in building_placements:
			if Vector2(px, py).distance_to(bp["pos"]) < 45:
				too_close = true
				break
		if too_close:
			continue
		_crystal_data.append({
			"pos": Vector2(px, py),
			"hue": rng.randf_range(0.5, 0.9),
			"size": rng.randf_range(8, 16),
		})

func _draw_crystals() -> void:
	for c in _crystal_data:
		var p: Vector2 = c["pos"]
		var sz: float = c["size"]
		var hue: float = c["hue"]
		var base_col := Color.from_hsv(hue, 0.4, 0.95)
		var glow_col := Color.from_hsv(hue, 0.25, 1.0, 0.35)
		# Glow
		var glow_sz := sz * 2.0 + sin(_time * 2.0 + p.x) * 3.0
		draw_circle(p + Vector2(0, -sz * 0.5), glow_sz, glow_col)
		# Crystal shards
		for i in 3:
			var off_x := (i - 1) * sz * 0.4
			var h := sz * (0.8 + i * 0.2)
			var shard := PackedVector2Array([
				p + Vector2(off_x - 3, 0),
				p + Vector2(off_x - 1, -h),
				p + Vector2(off_x + 1, -h),
				p + Vector2(off_x + 3, 0),
			])
			draw_colored_polygon(shard, base_col)
			draw_polyline(shard + PackedVector2Array([shard[0]]), base_col.lightened(0.3), 1.0)

# ---------- FLOWERS ----------
func _generate_flowers(rng: RandomNumberGenerator) -> void:
	var rx := ISLAND_RADIUS
	var ry := rx * ISO
	var colors := [
		Color(0.9, 0.35, 0.45), Color(0.95, 0.80, 0.25),
		Color(0.75, 0.45, 0.85), Color(0.95, 0.55, 0.30),
		Color(0.45, 0.55, 0.92), Color(1.0, 0.75, 0.80),
	]
	for i in 35:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.1, 0.9)
		var px := cos(a) * rx * d
		var py := sin(a) * ry * d
		_flower_data.append({
			"pos": Vector2(px, py),
			"color": colors[rng.randi() % colors.size()],
			"size": rng.randf_range(2.0, 4.5),
		})

func _draw_flowers() -> void:
	for f in _flower_data:
		var p: Vector2 = f["pos"]
		var col: Color = f["color"]
		var sz: float = f["size"]
		var sway := sin(_time * 1.8 + p.x * 0.08) * 1.5
		draw_line(p, p + Vector2(sway, -sz * 2.5), Color(0.3, 0.55, 0.22), 1.2)
		draw_circle(p + Vector2(sway, -sz * 3), sz, col)
		draw_circle(p + Vector2(sway, -sz * 3), sz * 0.4, Color(1, 0.95, 0.55))

# ---------- FLOATING DEBRIS ----------
func _generate_floating_debris(rng: RandomNumberGenerator) -> void:
	for i in 8:
		_floating_debris.append({
			"pos": Vector2(rng.randf_range(-250, 250), rng.randf_range(60, 120)),
			"size": rng.randf_range(4, 10),
			"speed": rng.randf_range(0.3, 0.8),
		})

func _draw_floating_debris() -> void:
	for d in _floating_debris:
		var p: Vector2 = d["pos"]
		var sz: float = d["size"]
		var bob := sin(_time * d["speed"] + p.x) * 8.0
		var dp := p + Vector2(0, bob)
		draw_rect(Rect2(dp.x - sz/2, dp.y - sz/2, sz, sz), ROCK_COLOR.darkened(0.2))

# ---------- SETUP ----------
func _place_buildings(parent: Node2D) -> void:
	for bp in building_placements:
		var b = building_scene.instantiate()
		b.building_type = bp["type"]
		b.position = bp["pos"]
		parent.add_child(b)
		GameManager.register_building(b)

func _spawn_player(parent: Node2D) -> void:
	var p = player_scene.instantiate()
	p.position = Vector2(-20, 50)
	parent.add_child(p)

func _spawn_initial_eggs() -> void:
	for i in 5:
		var angle := i * TAU / 5.0 + 0.5
		var dist := randf_range(80, 200)
		var pos := Vector2(cos(angle) * dist, sin(angle) * dist * ISO)
		GameManager.spawn_egg_at(pos, randi_range(0, 4))

func _setup_camera() -> void:
	if GameManager.player:
		var cam := Camera2D.new()
		cam.name = "MainCamera"
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0
		cam.zoom = Vector2(1.4, 1.4)
		GameManager.player.add_child(cam)

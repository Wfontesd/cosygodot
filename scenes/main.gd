extends Node2D

const ISLAND_RADIUS := 350.0
const ISLAND_COLOR := Color(0.42, 0.72, 0.38)
const ISLAND_EDGE_COLOR := Color(0.55, 0.42, 0.30)
const CLOUD_COLOR := Color(1, 1, 1, 0.35)

var _cloud_positions: Array = []
var _decoration_positions: Array = []
var _time := 0.0

var player_scene := preload("res://scenes/player/player.tscn")
var building_scene := preload("res://scenes/buildings/building.tscn")
var egg_scene := preload("res://scenes/creatures/egg.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")

var building_placements := [
	{ "type": Enums.BuildingType.INCUBATOR, "pos": Vector2(0, -60) },
	{ "type": Enums.BuildingType.REST_ZONE, "pos": Vector2(160, 40) },
	{ "type": Enums.BuildingType.NATURE_CABIN, "pos": Vector2(-170, 30) },
	{ "type": Enums.BuildingType.MAGIC_TOWER, "pos": Vector2(100, -130) },
	{ "type": Enums.BuildingType.MINING_WORKSHOP, "pos": Vector2(-90, 110) },
]

func _ready() -> void:
	_generate_clouds()
	_generate_decorations()

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
	_draw_sky()
	_draw_clouds_behind()
	_draw_island()
	_draw_decorations()
	_draw_clouds_front()

func _draw_sky() -> void:
	var cam_offset := Vector2.ZERO
	if GameManager.player:
		cam_offset = GameManager.player.global_position * 0.1
	for i in 8:
		var y_base: float = -400 + i * 120 - cam_offset.y * 0.05
		var alpha: float = 0.03 + i * 0.008
		draw_rect(Rect2(-800, y_base, 1600, 120), Color(0.6, 0.8, 0.95, alpha))

func _draw_clouds_behind() -> void:
	for i in _cloud_positions.size() / 2:
		var cp: Vector2 = _cloud_positions[i]
		cp.x += sin(_time * 0.15 + i) * 20
		_draw_cloud(cp, 0.2 + i * 0.02)

func _draw_clouds_front() -> void:
	for i in range(_cloud_positions.size() / 2, _cloud_positions.size()):
		var cp: Vector2 = _cloud_positions[i]
		cp.x += sin(_time * 0.1 + i * 0.5) * 30
		_draw_cloud(cp, 0.15 + (i - _cloud_positions.size() / 2) * 0.015)

func _draw_cloud(pos: Vector2, alpha: float) -> void:
	draw_circle(pos, 40, Color(1, 1, 1, alpha))
	draw_circle(pos + Vector2(30, -5), 30, Color(1, 1, 1, alpha * 0.8))
	draw_circle(pos + Vector2(-25, 3), 28, Color(1, 1, 1, alpha * 0.85))
	draw_circle(pos + Vector2(15, 10), 22, Color(1, 1, 1, alpha * 0.7))

func _draw_island() -> void:
	var rx := ISLAND_RADIUS
	var ry := ISLAND_RADIUS * Enums.ISO_RATIO

	# Island underside (floating effect)
	var under_pts := PackedVector2Array()
	var depth := 40.0
	under_pts.append(Vector2(-rx, 0))
	for i in 12:
		var t: float = float(i) / 11.0
		var x: float = -rx + t * 2 * rx
		var edge_y: float = ry * sqrt(max(0, 1.0 - (x * x) / (rx * rx)))
		under_pts.append(Vector2(x, edge_y + depth * (1.0 - abs(x) / rx)))
	under_pts.append(Vector2(rx, 0))
	draw_colored_polygon(under_pts, ISLAND_EDGE_COLOR.darkened(0.3))

	# Main island surface (ellipse)
	var surface := PackedVector2Array()
	for i in 48:
		var angle: float = i * TAU / 48.0
		surface.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(surface, ISLAND_COLOR)

	# Edge highlight
	for i in 48:
		var angle: float = i * TAU / 48.0
		var next_angle: float = (i + 1) * TAU / 48.0
		var p1 := Vector2(cos(angle) * rx, sin(angle) * ry)
		var p2 := Vector2(cos(next_angle) * rx, sin(next_angle) * ry)
		var c := ISLAND_EDGE_COLOR if sin(angle) > 0 else ISLAND_COLOR.lightened(0.15)
		draw_line(p1, p2, c, 2.0)

	# Grass patches
	for i in 20:
		var a := i * TAU / 20.0 + 0.3
		var r := randf_range(0.3, 0.8) * rx * 0.8
		var px := cos(a) * r
		var py := sin(a) * r * Enums.ISO_RATIO
		if px * px / (rx * rx) + py * py / (ry * ry) < 0.85:
			draw_circle(Vector2(px, py), 8 + i % 5, ISLAND_COLOR.lightened(0.08 + (i % 3) * 0.04))

	# Path between buildings (dirt trails)
	for i in building_placements.size():
		var p1: Vector2 = building_placements[i]["pos"]
		for j in range(i + 1, building_placements.size()):
			var p2: Vector2 = building_placements[j]["pos"]
			if p1.distance_to(p2) < 280:
				_draw_path(p1, p2)

func _draw_path(from: Vector2, to: Vector2) -> void:
	var trail_color := Color(0.52, 0.45, 0.35, 0.4)
	var steps: int = int(from.distance_to(to) / 12)
	for i in steps:
		var t: float = float(i) / maxf(float(steps - 1), 1.0)
		var p := from.lerp(to, t)
		p += Vector2(sin(i * 1.3) * 3, cos(i * 1.7) * 2)
		draw_circle(p, 4, trail_color)

func _draw_decorations() -> void:
	for d in _decoration_positions:
		var pos: Vector2 = d["pos"]
		var dtype: int = d["type"]
		match dtype:
			0: _draw_flower(pos, d["color"])
			1: _draw_bush(pos)
			2: _draw_rock_deco(pos)
			3: _draw_tree(pos)

func _draw_flower(pos: Vector2, color: Color) -> void:
	var sway := sin(_time * 2.0 + pos.x * 0.1) * 2.0
	draw_line(pos + Vector2(0, 0), pos + Vector2(sway, -8), Color(0.3, 0.6, 0.25), 1.5)
	draw_circle(pos + Vector2(sway, -10), 3.0, color)
	draw_circle(pos + Vector2(sway, -10), 1.5, Color(1, 0.95, 0.5))

func _draw_bush(pos: Vector2) -> void:
	draw_circle(pos + Vector2(0, -4), 8, Color(0.3, 0.6, 0.28))
	draw_circle(pos + Vector2(5, -6), 6, Color(0.35, 0.65, 0.32))
	draw_circle(pos + Vector2(-4, -3), 5, Color(0.28, 0.58, 0.25))

func _draw_rock_deco(pos: Vector2) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-6, 0), pos + Vector2(-4, -7),
		pos + Vector2(3, -8), pos + Vector2(7, -3), pos + Vector2(5, 0)
	])
	draw_colored_polygon(pts, Color(0.58, 0.55, 0.50))

func _draw_tree(pos: Vector2) -> void:
	draw_line(pos, pos + Vector2(0, -18), Color(0.45, 0.32, 0.2), 3)
	draw_circle(pos + Vector2(0, -22), 12, Color(0.28, 0.55, 0.25))
	draw_circle(pos + Vector2(6, -18), 8, Color(0.32, 0.58, 0.28))
	draw_circle(pos + Vector2(-5, -20), 9, Color(0.3, 0.56, 0.26))

func _generate_clouds() -> void:
	_cloud_positions.clear()
	for i in 12:
		_cloud_positions.append(Vector2(
			randf_range(-600, 600),
			randf_range(-350, 350)
		))

func _generate_decorations() -> void:
	_decoration_positions.clear()
	var rx := ISLAND_RADIUS
	var ry := ISLAND_RADIUS * Enums.ISO_RATIO

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for i in 40:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(0.2, 0.9)
		var px := cos(angle) * rx * dist
		var py := sin(angle) * ry * dist

		var too_close := false
		for bp in building_placements:
			if Vector2(px, py).distance_to(bp["pos"]) < 55:
				too_close = true
				break
		if too_close:
			continue

		var dtype := rng.randi_range(0, 3)
		var flower_colors := [
			Color(0.9, 0.3, 0.4), Color(0.95, 0.8, 0.2),
			Color(0.7, 0.4, 0.85), Color(0.95, 0.6, 0.3),
			Color(0.4, 0.5, 0.9)
		]
		_decoration_positions.append({
			"pos": Vector2(px, py),
			"type": dtype,
			"color": flower_colors[rng.randi() % flower_colors.size()]
		})

func _place_buildings(parent: Node2D) -> void:
	for bp in building_placements:
		var b = building_scene.instantiate()
		b.building_type = bp["type"]
		b.position = bp["pos"]
		parent.add_child(b)
		GameManager.register_building(b)

func _spawn_player(parent: Node2D) -> void:
	var p = player_scene.instantiate()
	p.position = Vector2(0, 50)
	parent.add_child(p)

func _spawn_initial_eggs() -> void:
	for i in 4:
		var angle := i * TAU / 4.0 + 0.5
		var dist := randf_range(80, 200)
		var pos := Vector2(cos(angle) * dist, sin(angle) * dist * Enums.ISO_RATIO)
		GameManager.spawn_egg_at(pos, randi_range(0, 4))

func _setup_camera() -> void:
	if GameManager.player:
		var cam := Camera2D.new()
		cam.name = "MainCamera"
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0
		cam.zoom = Vector2(1.3, 1.3)
		GameManager.player.add_child(cam)

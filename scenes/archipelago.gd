extends Node2D

const TILE_SCALE := 0.45
const TILE_HALF_W := 64.0
const TILE_HALF_H := 32.0
const STACK_H := 20.0
const BRIDGE_WIDTH := 8.0

# Sky palette
const SKY_TOP := Color(0.72, 0.62, 0.78)
const SKY_MID := Color(0.82, 0.68, 0.72)
const SKY_BOT := Color(0.90, 0.78, 0.70)

# Biome ground colors (tint applied to tiles)
const BIOME_TINT := {
	Enums.Element.PLANT: Color(1.0, 1.0, 1.0),
	Enums.Element.FIRE: Color(1.1, 0.9, 0.85),
	Enums.Element.WATER: Color(0.9, 0.95, 1.1),
	Enums.Element.ROCK: Color(0.95, 0.92, 0.88),
	Enums.Element.MAGIC: Color(1.0, 0.92, 1.08),
}

var generator: ArchipelagoGenerator
var validator: GenerationValidator
var _time := 0.0
var _cloud_data: Array = []
var _show_debug := false

var tex_grass: Texture2D
var tex_dirt: Texture2D
var tex_stone: Texture2D
var tex_wood: Texture2D
var tex_leaf_dark: Texture2D
var tex_leaf_light: Texture2D
var tex_ore_blue: Texture2D
var tex_ore_gold: Texture2D

var player_scene: PackedScene
var building_scene: PackedScene
var hud_scene: PackedScene

@export var seed_value: int = 42
@export var island_count: int = 10

func _ready() -> void:
	_load_assets()

	generator = ArchipelagoGenerator.new()
	generator.seed_value = seed_value
	generator.island_count = island_count
	generator.world_radius = 900.0
	generator.min_distance = 220.0
	generator.bridge_max_length = 500.0
	generator.relaxation_iterations = 120
	validator = GenerationValidator.new()

	_generate_world()

func _load_assets() -> void:
	tex_grass = load("res://assets/kenney/voxelTile_10.png")
	tex_dirt = load("res://assets/kenney/voxelTile_04.png")
	tex_stone = load("res://assets/kenney/voxelTile_09.png")
	tex_wood = load("res://assets/kenney/voxelTile_22.png")
	tex_leaf_dark = load("res://assets/kenney/voxelTile_05.png")
	tex_leaf_light = load("res://assets/kenney/voxelTile_03.png")
	tex_ore_blue = load("res://assets/kenney/voxelTile_36.png")
	tex_ore_gold = load("res://assets/kenney/voxelTile_35.png")
	player_scene = preload("res://scenes/player/player.tscn")
	building_scene = preload("res://scenes/buildings/building.tscn")
	hud_scene = preload("res://scenes/ui/hud.tscn")

func _generate_world() -> void:
	# Clear previous
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	generator.generate()
	GameManager.set_archipelago_generator(generator)
	var valid := validator.validate(generator)
	print(validator.get_report())

	# Generate clouds
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 999
	_cloud_data.clear()
	for i in 18:
		_cloud_data.append({
			"pos": Vector2(rng.randf_range(-900, 900), rng.randf_range(-600, 600)),
			"scale": rng.randf_range(0.5, 1.3),
			"speed": rng.randf_range(0.02, 0.08),
			"layer": rng.randf_range(0, 1),
		})

	# Tile layer
	var tile_layer := Node2D.new()
	tile_layer.name = "TileLayer"
	tile_layer.z_index = -10
	add_child(tile_layer)
	_build_all_islands(tile_layer)

	# Game world (y-sorted)
	var game_world := Node2D.new()
	game_world.name = "GameWorld"
	game_world.y_sort_enabled = true
	add_child(game_world)
	GameManager.world_root = game_world

	# Place buildings on hub
	_place_hub_buildings(game_world)

	# Spawn eggs on various islands
	_spawn_eggs_on_islands()

	# Spawn player on hub
	var hub := generator.islands[generator.hub_id]
	var player := player_scene.instantiate()
	player.position = hub.world_pos
	game_world.add_child(player)

	# Camera
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 4.0
	cam.zoom = Vector2(1.0, 1.0)
	player.add_child(cam)

	# HUD
	var hud := hud_scene.instantiate()
	add_child(hud)

func _process(delta: float) -> void:
	_time += delta
	if Input.is_action_just_pressed("cancel"):
		_show_debug = not _show_debug
	queue_redraw()

func _draw() -> void:
	_draw_sky()
	_draw_clouds(0.5, false)
	_draw_bridges()
	_draw_clouds(0.5, true)
	if _show_debug:
		_draw_debug_overlay()

# ─── Sky ───
func _draw_sky() -> void:
	for i in 30:
		var t := float(i) / 29.0
		var col: Color
		if t < 0.5:
			col = SKY_TOP.lerp(SKY_MID, t * 2.0)
		else:
			col = SKY_MID.lerp(SKY_BOT, (t - 0.5) * 2.0)
		draw_rect(Rect2(-1200, -800 + i * 60, 2400, 62), col)

# ─── Clouds ───
func _draw_clouds(threshold: float, above: bool) -> void:
	for c in _cloud_data:
		var is_above: bool = c["layer"] >= threshold
		if is_above != above:
			continue
		var p: Vector2 = c["pos"] + Vector2(sin(_time * c["speed"]) * 30, 0)
		var sc: float = c["scale"]
		var alpha := 0.18 if above else 0.14
		var ca := Color(1, 1, 1, alpha)
		draw_circle(p, 35 * sc, ca)
		draw_circle(p + Vector2(28, -6) * sc, 25 * sc, ca)
		draw_circle(p + Vector2(-22, 4) * sc, 22 * sc, Color(1, 0.97, 0.95, alpha * 0.7))

# ─── Bridges ───
func _draw_bridges() -> void:
	for bridge in generator.bridges:
		if bridge.path_points.size() < 2:
			continue
		var col := bridge.get_style_color()
		var rail_col := col.darkened(0.2)

		# Bridge planks
		for i in range(bridge.path_points.size() - 1):
			var p1: Vector2 = bridge.path_points[i]
			var p2: Vector2 = bridge.path_points[i + 1]
			var dir := (p2 - p1).normalized()
			var perp := Vector2(-dir.y, dir.x) * BRIDGE_WIDTH * 0.5

			var quad := PackedVector2Array([
				p1 + perp, p2 + perp, p2 - perp, p1 - perp
			])
			draw_colored_polygon(quad, col)

		# Railings
		draw_polyline(bridge.path_points, rail_col, 1.5)
		var offset_pts := PackedVector2Array()
		for p in bridge.path_points:
			var idx := bridge.path_points.find(p)
			var next_idx := mini(idx + 1, bridge.path_points.size() - 1)
			var dir := Vector2.ZERO
			if next_idx != idx:
				dir = (bridge.path_points[next_idx] - p).normalized()
			var perp := Vector2(-dir.y, dir.x) * BRIDGE_WIDTH * 0.5
			offset_pts.append(p + perp)
		if offset_pts.size() >= 2:
			draw_polyline(offset_pts, rail_col, 1.5)

		# Posts at regular intervals
		for i in range(0, bridge.path_points.size(), 4):
			var p: Vector2 = bridge.path_points[i]
			draw_circle(p, 2.5, rail_col.darkened(0.1))

# ─── Build all islands ───
func _build_all_islands(parent: Node2D) -> void:
	# Sort by Y for proper overlap
	var sorted_ids: Array[int] = []
	for i in generator.islands.size():
		sorted_ids.append(i)
	sorted_ids.sort_custom(func(a, b): return generator.islands[a].world_pos.y < generator.islands[b].world_pos.y)

	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = seed_value + 777

	for island_id in sorted_ids:
		var island := generator.islands[island_id]
		var island_node := Node2D.new()
		island_node.name = "Island_%d" % island_id
		island_node.position = island.world_pos + Vector2(0, island.height)
		parent.add_child(island_node)
		_build_island_tiles(island_node, island, tree_rng)

func _build_island_tiles(parent: Node2D, island: IslandData, rng: RandomNumberGenerator) -> void:
	var grid_r := island.get_tile_radius()
	var tint: Color = BIOME_TINT.get(island.biome, Color.WHITE)

	for gy in range(-grid_r, grid_r + 1):
		for gx in range(-grid_r, grid_r + 1):
			if absi(gx) + absi(gy) > grid_r:
				continue

			var sp := Vector2(
				float(gx - gy) * TILE_HALF_W * TILE_SCALE,
				float(gx + gy) * TILE_HALF_H * TILE_SCALE
			)
			var dist := absi(gx) + absi(gy)

			# Depth layers on edges
			if dist >= grid_r - 1:
				_place_tile(parent, tex_stone, sp + Vector2(0, STACK_H * 2), -2, Color.WHITE)
			if dist >= grid_r - 2:
				_place_tile(parent, tex_dirt, sp + Vector2(0, STACK_H), -1, tint)

			# Surface
			_place_tile(parent, tex_grass, sp, 0, tint)

	# Trees (not on hub center area)
	var tree_count := rng.randi_range(1, 3) + island.get_tile_radius() / 2
	for _t in tree_count:
		var gx := rng.randi_range(-grid_r + 1, grid_r - 1)
		var gy := rng.randi_range(-grid_r + 1, grid_r - 1)
		if absi(gx) + absi(gy) >= grid_r:
			continue
		if island.is_hub and absi(gx) + absi(gy) < 2:
			continue
		var sp := Vector2(
			float(gx - gy) * TILE_HALF_W * TILE_SCALE,
			float(gx + gy) * TILE_HALF_H * TILE_SCALE
		)
		_place_tile(parent, tex_wood, sp + Vector2(0, -STACK_H), 2, Color.WHITE)
		var leaf_tex = tex_leaf_dark if rng.randi() % 2 == 0 else tex_leaf_light
		_place_tile(parent, leaf_tex, sp + Vector2(0, -STACK_H * 2), 3, tint)
		if rng.randf() > 0.5:
			_place_tile(parent, tex_leaf_light, sp + Vector2(0, -STACK_H * 3), 3, tint)

	# Crystals on magic islands
	if island.biome == Enums.Element.MAGIC:
		for _c in 2:
			var gx := rng.randi_range(-grid_r + 1, grid_r - 1)
			var gy := rng.randi_range(-grid_r + 1, grid_r - 1)
			if absi(gx) + absi(gy) >= grid_r:
				continue
			var sp := Vector2(
				float(gx - gy) * TILE_HALF_W * TILE_SCALE,
				float(gx + gy) * TILE_HALF_H * TILE_SCALE
			)
			_place_tile(parent, tex_ore_blue, sp + Vector2(0, -STACK_H), 2, Color.WHITE)

	# Ore on rock islands
	if island.biome == Enums.Element.ROCK:
		for _c in 2:
			var gx := rng.randi_range(-grid_r + 1, grid_r - 1)
			var gy := rng.randi_range(-grid_r + 1, grid_r - 1)
			if absi(gx) + absi(gy) >= grid_r:
				continue
			var sp := Vector2(
				float(gx - gy) * TILE_HALF_W * TILE_SCALE,
				float(gx + gy) * TILE_HALF_H * TILE_SCALE
			)
			_place_tile(parent, tex_ore_gold, sp + Vector2(0, -STACK_H), 2, Color.WHITE)

func _place_tile(parent: Node2D, tex: Texture2D, pos: Vector2, z: int, tint: Color) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos
	spr.scale = Vector2(TILE_SCALE, TILE_SCALE)
	spr.z_index = z
	spr.modulate = tint
	parent.add_child(spr)

# ─── Place buildings on hub ───
func _place_hub_buildings(parent: Node2D) -> void:
	var hub := generator.islands[generator.hub_id]
	var building_types := [
		Enums.BuildingType.INCUBATOR,
		Enums.BuildingType.REST_ZONE,
		Enums.BuildingType.NATURE_CABIN,
		Enums.BuildingType.MAGIC_TOWER,
		Enums.BuildingType.MINING_WORKSHOP,
	]
	var offsets := [
		Vector2(20, -15), Vector2(60, 20), Vector2(-60, 10),
		Vector2(40, -55), Vector2(-35, 45),
	]
	for i in building_types.size():
		var b := building_scene.instantiate()
		b.building_type = building_types[i]
		b.position = hub.world_pos + offsets[i]
		parent.add_child(b)
		GameManager.register_building(b)

# ─── Spawn eggs on islands ───
func _spawn_eggs_on_islands() -> void:
	var egg_rng := RandomNumberGenerator.new()
	egg_rng.seed = seed_value + 555
	for island in generator.islands:
		var count := 1 if island.is_hub else egg_rng.randi_range(0, 2)
		for _e in count:
			var angle := egg_rng.randf() * TAU
			var dist := egg_rng.randf_range(20, island.radius * 0.5)
			var pos := island.world_pos + Vector2(cos(angle) * dist, sin(angle) * dist * 0.5)
			GameManager.spawn_egg_at(pos, egg_rng.randi_range(0, 4))

# ─── Debug overlay ───
func _draw_debug_overlay() -> void:
	# Draw graph edges
	for bridge in generator.bridges:
		var a := generator.islands[bridge.island_a_id]
		var b := generator.islands[bridge.island_b_id]
		var col := Color.GREEN if bridge.valid else Color.RED
		draw_line(a.world_pos, b.world_pos, col, 2.0)
		var mid := (a.world_pos + b.world_pos) * 0.5
		draw_string(ThemeDB.fallback_font, mid + Vector2(-10, -5), "%.0f" % bridge.length, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)

	# Draw island info
	for island in generator.islands:
		var p := island.world_pos
		var r := island.radius
		# Bounding circle
		draw_arc(p, r, 0, TAU, 24, Color.CYAN if not island.is_hub else Color.YELLOW, 1.5)
		# Label
		var label := "#%d %s %s" % [island.id, island.get_biome_name(), island.get_size_name()]
		if island.is_hub:
			label += " [HUB]"
		draw_string(ThemeDB.fallback_font, p + Vector2(-30, -r - 8), label, HORIZONTAL_ALIGNMENT_LEFT, 100, 8, Color.WHITE)
		# Degree
		draw_string(ThemeDB.fallback_font, p + Vector2(-10, r + 12), "deg=%d" % island.connections.size(), HORIZONTAL_ALIGNMENT_LEFT, 50, 7, Color(0.8, 0.8, 0.8))

extends Node2D

const ISLAND_RADIUS := 350.0
const ISO := 0.5
const TILE_SCALE := 0.55
const TILE_HALF_W := 64.0
const TILE_HALF_H := 32.0
const STACK_OFFSET := 35.0
const GRID_RADIUS := 6

const SKY_TOP := Color(0.72, 0.62, 0.78)
const SKY_MID := Color(0.82, 0.68, 0.72)
const SKY_BOT := Color(0.90, 0.78, 0.70)

var _cloud_data: Array = []
var _flower_data: Array = []
var _time := 0.0

var player_scene := preload("res://scenes/player/player.tscn")
var building_scene := preload("res://scenes/buildings/building.tscn")
var hud_scene := preload("res://scenes/ui/hud.tscn")

var tex_grass: Texture2D
var tex_dirt: Texture2D
var tex_stone: Texture2D
var tex_wood: Texture2D
var tex_leaf_dark: Texture2D
var tex_leaf_light: Texture2D
var tex_ore_gold: Texture2D
var tex_ore_blue: Texture2D
var tex_brick: Texture2D
var tex_stone_brick: Texture2D
var tex_furnace: Texture2D

var building_placements := [
	{ "type": Enums.BuildingType.INCUBATOR, "pos": Vector2(35, -18) },
	{ "type": Enums.BuildingType.REST_ZONE, "pos": Vector2(140, 35) },
	{ "type": Enums.BuildingType.NATURE_CABIN, "pos": Vector2(-140, 18) },
	{ "type": Enums.BuildingType.MAGIC_TOWER, "pos": Vector2(70, -90) },
	{ "type": Enums.BuildingType.MINING_WORKSHOP, "pos": Vector2(-70, 90) },
]

func _ready() -> void:
	_load_textures()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_generate_clouds(rng)
	_generate_flowers(rng)

	# Tile layer (behind game objects)
	var tile_layer := Node2D.new()
	tile_layer.name = "TileLayer"
	tile_layer.z_index = -10
	add_child(tile_layer)
	_build_tile_island(tile_layer, rng)

	# Game world (y-sorted for entities)
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

func _load_textures() -> void:
	tex_grass = load("res://assets/kenney/voxelTile_10.png")
	tex_dirt = load("res://assets/kenney/voxelTile_04.png")
	tex_stone = load("res://assets/kenney/voxelTile_09.png")
	tex_wood = load("res://assets/kenney/voxelTile_22.png")
	tex_leaf_dark = load("res://assets/kenney/voxelTile_05.png")
	tex_leaf_light = load("res://assets/kenney/voxelTile_03.png")
	tex_ore_gold = load("res://assets/kenney/voxelTile_35.png")
	tex_ore_blue = load("res://assets/kenney/voxelTile_36.png")
	tex_brick = load("res://assets/kenney/voxelTile_27.png")
	tex_stone_brick = load("res://assets/kenney/voxelTile_30.png")
	tex_furnace = load("res://assets/kenney/voxelTile_17.png")

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	_draw_sky_gradient()
	_draw_clouds_back()
	_draw_flowers()
	_draw_clouds_front()

# ─── Grid helpers ───
func _grid_to_screen(gx: int, gy: int) -> Vector2:
	return Vector2(
		float(gx - gy) * TILE_HALF_W * TILE_SCALE,
		float(gx + gy) * TILE_HALF_H * TILE_SCALE
	)

func _is_in_island(gx: int, gy: int) -> bool:
	return absi(gx) + absi(gy) <= GRID_RADIUS

func _is_edge(gx: int, gy: int) -> bool:
	return absi(gx) + absi(gy) == GRID_RADIUS

# ─── Tile island ───
func _build_tile_island(parent: Node2D, rng: RandomNumberGenerator) -> void:
	# Place all tiles sorted by Y for proper overlap
	for gy in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for gx in range(-GRID_RADIUS, GRID_RADIUS + 1):
			if not _is_in_island(gx, gy):
				continue
			var sp := _grid_to_screen(gx, gy)
			var dist := absi(gx) + absi(gy)

			# Bottom layers visible on front-facing edges
			if dist >= GRID_RADIUS - 1:
				_place_tile(parent, tex_stone, sp + Vector2(0, STACK_OFFSET * 2), -2)
			if dist >= GRID_RADIUS - 2:
				_place_tile(parent, tex_dirt, sp + Vector2(0, STACK_OFFSET), -1)

			# Grass surface
			_place_tile(parent, tex_grass, sp, 0)

	# Trees
	_build_trees(parent, rng)
	# Crystals
	_build_crystals(parent, rng)

func _place_tile(parent: Node2D, tex: Texture2D, pos: Vector2, z: int) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = pos
	spr.scale = Vector2(TILE_SCALE, TILE_SCALE)
	spr.z_index = z
	parent.add_child(spr)

# ─── Trees ───
func _build_trees(parent: Node2D, rng: RandomNumberGenerator) -> void:
	var tree_positions: Array = []
	for i in 14:
		var gx := rng.randi_range(-GRID_RADIUS + 1, GRID_RADIUS - 1)
		var gy := rng.randi_range(-GRID_RADIUS + 1, GRID_RADIUS - 1)
		if not _is_in_island(gx, gy) or _is_edge(gx, gy):
			continue
		var sp := _grid_to_screen(gx, gy)
		var too_close := false
		for bp in building_placements:
			if sp.distance_to(bp["pos"]) < 55:
				too_close = true
				break
		for existing in tree_positions:
			if sp.distance_to(existing) < 35:
				too_close = true
				break
		if too_close:
			continue
		tree_positions.append(sp)
		var height := rng.randi_range(2, 3)
		var tree_type := rng.randi_range(0, 2)
		_build_one_tree(parent, sp, height, tree_type)

func _build_one_tree(parent: Node2D, base_pos: Vector2, height: int, tree_type: int) -> void:
	# Trunk: wood blocks
	_place_tile(parent, tex_wood, base_pos + Vector2(0, -STACK_OFFSET), 2)
	if height >= 3:
		_place_tile(parent, tex_wood, base_pos + Vector2(0, -STACK_OFFSET * 2), 2)
	# Crown: leaf blocks
	var crown_y := -STACK_OFFSET * height
	match tree_type:
		0:
			_place_tile(parent, tex_leaf_dark, base_pos + Vector2(0, crown_y), 3)
			_place_tile(parent, tex_leaf_light, base_pos + Vector2(0, crown_y - STACK_OFFSET), 3)
		1:
			_place_tile(parent, tex_leaf_light, base_pos + Vector2(0, crown_y), 3)
			_place_tile(parent, tex_leaf_dark, base_pos + Vector2(0, crown_y - STACK_OFFSET), 3)
			_place_tile(parent, tex_leaf_light, base_pos + Vector2(0, crown_y - STACK_OFFSET * 2), 3)
		2:
			_place_tile(parent, tex_leaf_dark, base_pos + Vector2(0, crown_y), 3)

# ─── Crystals ───
func _build_crystals(parent: Node2D, rng: RandomNumberGenerator) -> void:
	for i in 5:
		var gx := rng.randi_range(-GRID_RADIUS + 1, GRID_RADIUS - 1)
		var gy := rng.randi_range(-GRID_RADIUS + 1, GRID_RADIUS - 1)
		if not _is_in_island(gx, gy) or _is_edge(gx, gy):
			continue
		var sp := _grid_to_screen(gx, gy)
		var too_close := false
		for bp in building_placements:
			if sp.distance_to(bp["pos"]) < 50:
				too_close = true
				break
		if too_close:
			continue
		var ore_tex = tex_ore_blue if rng.randi() % 2 == 0 else tex_ore_gold
		_place_tile(parent, ore_tex, sp + Vector2(0, -STACK_OFFSET), 2)

# ─── Sky ───
func _draw_sky_gradient() -> void:
	for i in 24:
		var t := float(i) / 23.0
		var col: Color
		if t < 0.5:
			col = SKY_TOP.lerp(SKY_MID, t * 2.0)
		else:
			col = SKY_MID.lerp(SKY_BOT, (t - 0.5) * 2.0)
		draw_rect(Rect2(-700, -400 + i * 40, 1400, 42), col)

# ─── Clouds ───
func _generate_clouds(rng: RandomNumberGenerator) -> void:
	for i in 14:
		_cloud_data.append({
			"pos": Vector2(rng.randf_range(-600, 600), rng.randf_range(-350, 350)),
			"scale": rng.randf_range(0.6, 1.3),
			"speed": rng.randf_range(0.03, 0.10),
			"layer": rng.randf_range(0, 1),
		})

func _draw_clouds_back() -> void:
	for c in _cloud_data:
		if c["layer"] < 0.5:
			var p: Vector2 = c["pos"] + Vector2(sin(_time * c["speed"]) * 25, 0)
			_draw_one_cloud(p, c["scale"], 0.16)

func _draw_clouds_front() -> void:
	for c in _cloud_data:
		if c["layer"] >= 0.5:
			var p: Vector2 = c["pos"] + Vector2(sin(_time * c["speed"] + 2.0) * 35, 0)
			_draw_one_cloud(p, c["scale"], 0.20)

func _draw_one_cloud(pos: Vector2, sc: float, alpha: float) -> void:
	var ca := Color(1, 1, 1, alpha)
	draw_circle(pos, 35 * sc, ca)
	draw_circle(pos + Vector2(28, -6) * sc, 25 * sc, ca)
	draw_circle(pos + Vector2(-22, 4) * sc, 22 * sc, Color(1, 0.97, 0.95, alpha * 0.7))
	draw_circle(pos + Vector2(12, 12) * sc, 18 * sc, Color(1, 0.97, 0.95, alpha * 0.7))

# ─── Flowers ───
func _generate_flowers(rng: RandomNumberGenerator) -> void:
	var colors := [
		Color(0.9, 0.35, 0.45), Color(0.95, 0.80, 0.25),
		Color(0.75, 0.45, 0.85), Color(0.95, 0.55, 0.30),
		Color(0.45, 0.55, 0.92), Color(1.0, 0.75, 0.80),
	]
	for i in 20:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.1, 0.6)
		var rx := ISLAND_RADIUS * 0.55
		var ry := rx * ISO
		_flower_data.append({
			"pos": Vector2(cos(a) * rx * d, sin(a) * ry * d),
			"color": colors[rng.randi() % colors.size()],
			"size": rng.randf_range(2.0, 4.0),
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

# ─── Setup ───
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
		var dist := randf_range(60, 150)
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

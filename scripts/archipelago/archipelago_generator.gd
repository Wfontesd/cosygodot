class_name ArchipelagoGenerator
extends RefCounted

# --- Exposed parameters ---
var seed_value: int = 42
var island_count: int = 10
var world_radius: float = 600.0
var hub_bias: float = 0.8
var branchiness: float = 0.3
var min_distance: float = 160.0
var bridge_max_length: float = 350.0
var biome_weights := {
	Enums.Element.PLANT: 1.0,
	Enums.Element.FIRE: 0.8,
	Enums.Element.WATER: 0.8,
	Enums.Element.ROCK: 0.7,
	Enums.Element.MAGIC: 0.6,
}
var size_weights := [0.3, 0.5, 0.2]  # small, medium, large
var height_range := Vector2(-30.0, 30.0)
var max_degree: int = 4
var relaxation_iterations: int = 80
var iso_ratio: float = 0.5

# --- Output ---
var islands: Array[IslandData] = []
var bridges: Array[BridgeData] = []
var hub_id: int = 0
var rng: RandomNumberGenerator

# --- Bridge style rules: biome pair → style ---
var bridge_style_rules := {}

func generate() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	islands.clear()
	bridges.clear()
	_init_bridge_style_rules()

	island_count = clampi(island_count, 8, 15)
	_create_island_nodes()
	_select_hub()
	_place_islands_spatial()
	_relax_positions()
	_assign_heights()
	_assign_biomes()
	_assign_sizes()
	_build_spanning_tree()
	_add_extra_edges()
	_compute_island_radii()
	_compute_bridge_geometry()

func _init_bridge_style_rules() -> void:
	bridge_style_rules.clear()
	bridge_style_rules[_pair_key(Enums.Element.PLANT, Enums.Element.PLANT)] = 3  # vine
	bridge_style_rules[_pair_key(Enums.Element.ROCK, Enums.Element.ROCK)] = 1   # stone
	bridge_style_rules[_pair_key(Enums.Element.MAGIC, Enums.Element.MAGIC)] = 4 # rune
	bridge_style_rules[_pair_key(Enums.Element.FIRE, Enums.Element.FIRE)] = 1   # stone
	bridge_style_rules[_pair_key(Enums.Element.WATER, Enums.Element.WATER)] = 0 # wood
	bridge_style_rules[_pair_key(Enums.Element.MAGIC, Enums.Element.PLANT)] = 2 # crystal
	bridge_style_rules[_pair_key(Enums.Element.FIRE, Enums.Element.ROCK)] = 1   # stone

func _pair_key(a: int, b: int) -> int:
	return mini(a, b) * 100 + maxi(a, b)

# ─── Step 1: Create island node data ───
func _create_island_nodes() -> void:
	for i in island_count:
		var island := IslandData.new()
		island.id = i
		islands.append(island)

# ─── Step 2: Select hub island ───
func _select_hub() -> void:
	if rng.randf() < hub_bias:
		hub_id = 0
	else:
		hub_id = rng.randi_range(0, islands.size() - 1)
	islands[hub_id].is_hub = true
	islands[hub_id].size_class = 2  # hub is always large

# ─── Step 3: Initial spatial placement ───
func _place_islands_spatial() -> void:
	islands[hub_id].grid_pos = Vector2.ZERO

	var placed := [hub_id]
	var attempts := 0
	var max_attempts := 5000

	for i in islands.size():
		if i == hub_id:
			continue
		var ok := false
		while not ok and attempts < max_attempts:
			attempts += 1
			var angle := rng.randf() * TAU
			var dist := rng.randf_range(min_distance * 0.8, world_radius)
			var pos := Vector2(cos(angle) * dist, sin(angle) * dist)

			var too_close := false
			for pi in placed:
				if islands[pi].grid_pos.distance_to(pos) < min_distance:
					too_close = true
					break
			if too_close:
				continue

			islands[i].grid_pos = pos
			placed.append(i)
			ok = true

		if not ok:
			var fallback_angle := i * TAU / float(island_count)
			var fallback_dist := min_distance * 1.5 + i * 30.0
			islands[i].grid_pos = Vector2(cos(fallback_angle) * fallback_dist, sin(fallback_angle) * fallback_dist)

# ─── Step 4: Force-directed relaxation ───
func _relax_positions() -> void:
	var repulsion := 25000.0
	var attraction := 0.005
	var damping := 0.90

	var velocities: Array[Vector2] = []
	for i in islands.size():
		velocities.append(Vector2.ZERO)

	for _iter in relaxation_iterations:
		for i in islands.size():
			var force := Vector2.ZERO

			# Repulsion from all other islands
			for j in islands.size():
				if i == j:
					continue
				var diff := islands[i].grid_pos - islands[j].grid_pos
				var dist := diff.length()
				if dist < 1.0:
					diff = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
					dist = 1.0
				force += diff.normalized() * repulsion / (dist * dist)

			# Attraction toward center (keeps layout compact)
			force -= islands[i].grid_pos * attraction

			# Hub stays near center
			if islands[i].is_hub:
				force -= islands[i].grid_pos * 0.05

			velocities[i] = (velocities[i] + force) * damping

		for i in islands.size():
			islands[i].grid_pos += velocities[i]

	# Convert to world positions (apply iso ratio to Y)
	for island in islands:
		island.world_pos = Vector2(island.grid_pos.x, island.grid_pos.y * iso_ratio)

# ─── Step 5: Height assignment ───
func _assign_heights() -> void:
	for island in islands:
		if island.is_hub:
			island.height = 0.0
		else:
			island.height = rng.randf_range(height_range.x, height_range.y)

# ─── Step 6: Biome assignment (weighted) ───
func _assign_biomes() -> void:
	var biome_list: Array[int] = []
	var weight_list: Array[float] = []
	var total := 0.0
	for biome in biome_weights:
		biome_list.append(biome)
		weight_list.append(biome_weights[biome])
		total += biome_weights[biome]

	for island in islands:
		if island.is_hub:
			island.biome = Enums.Element.PLANT
			continue
		var roll := rng.randf() * total
		var accum := 0.0
		for idx in biome_list.size():
			accum += weight_list[idx]
			if roll <= accum:
				island.biome = biome_list[idx]
				break

# ─── Step 7: Size assignment ───
func _assign_sizes() -> void:
	var total := 0.0
	for w in size_weights:
		total += w
	for island in islands:
		if island.is_hub:
			continue
		var roll := rng.randf() * total
		var accum := 0.0
		for idx in size_weights.size():
			accum += size_weights[idx]
			if roll <= accum:
				island.size_class = idx
				break

# ─── Step 8: Minimum spanning tree (Prim's) ───
func _build_spanning_tree() -> void:
	var in_tree := [hub_id]
	var not_in_tree: Array[int] = []
	for i in islands.size():
		if i != hub_id:
			not_in_tree.append(i)

	while not_in_tree.size() > 0:
		var best_from := -1
		var best_to := -1
		var best_dist := INF

		for a in in_tree:
			for b in not_in_tree:
				var d := islands[a].grid_pos.distance_to(islands[b].grid_pos)
				if d < best_dist:
					best_dist = d
					best_from = a
					best_to = b

		if best_to < 0:
			break

		_add_edge(best_from, best_to)
		in_tree.append(best_to)
		not_in_tree.erase(best_to)

# ─── Step 9: Add extra edges for loops ───
func _add_extra_edges() -> void:
	var extra_count := int(float(islands.size()) * branchiness)
	extra_count = clampi(extra_count, 1, 4)

	for _e in extra_count:
		var best_pair := Vector2i(-1, -1)
		var best_dist := INF

		for i in islands.size():
			if islands[i].connections.size() >= max_degree:
				continue
			for j in range(i + 1, islands.size()):
				if islands[j].connections.size() >= max_degree:
					continue
				if islands[i].connections.has(j):
					continue
				var d := islands[i].grid_pos.distance_to(islands[j].grid_pos)
				if d > bridge_max_length * 1.5:
					continue
				var score := d + rng.randf_range(0, 100)
				if score < best_dist:
					best_dist = score
					best_pair = Vector2i(i, j)

		if best_pair.x >= 0:
			_add_edge(best_pair.x, best_pair.y)

func _add_edge(a: int, b: int) -> void:
	if not islands[a].connections.has(b):
		islands[a].connections.append(b)
	if not islands[b].connections.has(a):
		islands[b].connections.append(a)

	var bridge := BridgeData.new()
	bridge.id = bridges.size()
	bridge.island_a_id = a
	bridge.island_b_id = b
	bridge.length = islands[a].world_pos.distance_to(islands[b].world_pos)
	bridge.style = _resolve_bridge_style(islands[a].biome, islands[b].biome)
	bridges.append(bridge)

func _resolve_bridge_style(biome_a: int, biome_b: int) -> int:
	var key := _pair_key(biome_a, biome_b)
	if bridge_style_rules.has(key):
		return bridge_style_rules[key]
	return 0  # default wood

# ─── Step 10: Compute island radii based on size ───
func _compute_island_radii() -> void:
	for island in islands:
		match island.size_class:
			0: island.radius = 55.0 + rng.randf_range(-5, 5)
			1: island.radius = 80.0 + rng.randf_range(-8, 8)
			2: island.radius = 115.0 + rng.randf_range(-10, 10)

# ─── Step 11: Bridge anchors and paths ───
func _compute_bridge_geometry() -> void:
	for bridge in bridges:
		var a := islands[bridge.island_a_id]
		var b := islands[bridge.island_b_id]
		var dir_ab := (b.world_pos - a.world_pos).normalized()

		bridge.anchor_a = a.world_pos + dir_ab * a.radius * 0.85
		bridge.anchor_b = b.world_pos - dir_ab * b.radius * 0.85

		# Bezier control point (slight arc)
		var mid := (bridge.anchor_a + bridge.anchor_b) * 0.5
		var perp := Vector2(-dir_ab.y, dir_ab.x)
		var arc_amount := rng.randf_range(-20.0, 20.0)
		var height_diff := (b.height - a.height) * 0.3
		bridge.control_point = mid + perp * arc_amount + Vector2(0, height_diff)

		# Sample bezier path
		bridge.path_points.clear()
		var steps := 16
		for i in steps + 1:
			var t := float(i) / float(steps)
			var p := _quadratic_bezier(bridge.anchor_a, bridge.control_point, bridge.anchor_b, t)
			bridge.path_points.append(p)

		bridge.length = 0.0
		for i in range(1, bridge.path_points.size()):
			bridge.length += bridge.path_points[i - 1].distance_to(bridge.path_points[i])

		bridge.valid = bridge.length <= bridge_max_length

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	return q0.lerp(q1, t)

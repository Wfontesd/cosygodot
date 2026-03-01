extends StaticBody2D

signal creature_added(creature)
signal creature_removed(creature)
signal egg_hatched(element)
signal panel_requested()

@export var building_type: int = Enums.BuildingType.INCUBATOR

var assigned_creatures: Array = []
var incubating_eggs: Array = []
var _hatch_timers: Array = []

const BASE_HATCH_TIME := 10.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	_build_visual()
	_build_collision()
	_build_interaction_area()

func _process(delta: float) -> void:
	if building_type == Enums.BuildingType.INCUBATOR:
		_process_incubation(delta)
	queue_redraw()

func _process_incubation(delta: float) -> void:
	var mod := EcosystemManager.get_incubation_modifier()
	var i := 0
	while i < _hatch_timers.size():
		_hatch_timers[i] -= delta / mod
		if _hatch_timers[i] <= 0:
			var elem: int = incubating_eggs[i]
			incubating_eggs.remove_at(i)
			_hatch_timers.remove_at(i)
			_on_egg_hatched(elem)
		else:
			i += 1

func _on_egg_hatched(element: int) -> void:
	GameManager.spawn_creature_at(global_position + Vector2(0, 30), element)
	egg_hatched.emit(element)

func add_egg(element: int) -> void:
	if building_type != Enums.BuildingType.INCUBATOR:
		return
	if incubating_eggs.size() >= get_capacity():
		return
	incubating_eggs.append(element)
	_hatch_timers.append(BASE_HATCH_TIME)

func add_creature(creature) -> void:
	if assigned_creatures.size() >= get_capacity():
		return
	assigned_creatures.append(creature)
	creature_added.emit(creature)

func remove_creature(creature) -> void:
	assigned_creatures.erase(creature)
	creature_removed.emit(creature)

func is_full() -> bool:
	if building_type == Enums.BuildingType.INCUBATOR:
		return incubating_eggs.size() >= get_capacity()
	return assigned_creatures.size() >= get_capacity()

func get_capacity() -> int:
	return Enums.BUILDING_CAPACITIES.get(building_type, 3)

func get_interaction_type() -> String:
	return "building"

func open_panel() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_building_panel(self)

func get_synergy_bonus() -> float:
	var affinity: int = Enums.BUILDING_ELEMENT_AFFINITY.get(building_type, -1)
	if affinity < 0:
		return 1.0
	var bonus := 0.0
	for c in assigned_creatures:
		if c and is_instance_valid(c):
			bonus += EcosystemManager.get_synergy_bonus(affinity, c.element)
	return 1.0 + bonus * 0.1

func get_incubation_progress() -> Array:
	var result := []
	for i in _hatch_timers.size():
		result.append({
			"element": incubating_eggs[i],
			"progress": 1.0 - (_hatch_timers[i] / BASE_HATCH_TIME)
		})
	return result

func _build_visual() -> void:
	var vis := Node2D.new()
	vis.name = "Visual"
	add_child(vis)
	vis.set_meta("building_ref", self)
	vis.set_script(_make_draw_script())

func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 24)
	col.shape = shape
	add_child(col)

func _build_interaction_area() -> void:
	var area := Area2D.new()
	area.name = "InteractionArea"
	area.collision_layer = 16
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 50.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)

func _make_draw_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node2D

func _draw():
	var bref = get_meta("building_ref")
	if not bref or not is_instance_valid(bref):
		return
	var btype: int = bref.building_type

	# Shadow
	draw_circle(Vector2(0, 12), 32.0, Color(0, 0, 0, 0.10))

	# Base platform
	var base := PackedVector2Array([
		Vector2(0, 12), Vector2(32, 0), Vector2(0, -12), Vector2(-32, 0)
	])
	draw_colored_polygon(base, Color(0.58, 0.50, 0.40))
	var base_top := PackedVector2Array([
		Vector2(0, 8), Vector2(30, -2), Vector2(0, -12), Vector2(-30, -2)
	])
	draw_colored_polygon(base_top, Color(0.65, 0.56, 0.45))
	draw_polyline(base_top + PackedVector2Array([base_top[0]]), Color(0.50, 0.42, 0.35), 1.5)

	match btype:
		Enums.BuildingType.INCUBATOR:
			_draw_incubator(bref)
		Enums.BuildingType.REST_ZONE:
			_draw_rest_zone()
		Enums.BuildingType.NATURE_CABIN:
			_draw_nature_cabin()
		Enums.BuildingType.MAGIC_TOWER:
			_draw_magic_tower()
		Enums.BuildingType.MINING_WORKSHOP:
			_draw_mining_workshop()

	# Label
	var icon: String = Enums.BUILDING_ICONS.get(btype, "")
	var bname: String = Enums.BUILDING_NAMES.get(btype, "")
	var cap: int = bref.get_capacity()
	var used: int = bref.assigned_creatures.size()
	if btype == Enums.BuildingType.INCUBATOR:
		used = bref.incubating_eggs.size()
	var label := icon + " " + bname
	draw_string(ThemeDB.fallback_font, Vector2(-32, -50), label, HORIZONTAL_ALIGNMENT_LEFT, 80, 8, Color(1, 1, 1, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-8, -42), str(used) + "/" + str(cap), HORIZONTAL_ALIGNMENT_LEFT, 30, 8, Color(0.95, 0.9, 0.7))

func _draw_incubator(bref):
	# Circular base ring
	draw_circle(Vector2(0, -2), 20.0, Color(0.65, 0.50, 0.38))
	draw_circle(Vector2(0, -4), 18.0, Color(0.75, 0.60, 0.48))
	# Glass dome
	var dome := PackedVector2Array()
	for i in 20:
		var a: float = PI + float(i) / 19.0 * PI
		dome.append(Vector2(cos(a) * 16, sin(a) * 20 - 6))
	dome.append(Vector2(16, -6))
	var t := Time.get_ticks_msec() * 0.002
	var glow := (sin(t) + 1.0) * 0.1
	draw_colored_polygon(dome, Color(0.92, 0.88, 0.82, 0.6 + glow))
	draw_polyline(dome, Color(0.85, 0.75, 0.55), 2.0)
	# Ring glow
	draw_arc(Vector2(0, -4), 18.0, 0, TAU, 24, Color(1.0, 0.85, 0.5, 0.3 + glow * 0.5), 2.0)
	# Eggs inside
	var eggs = bref.get_incubation_progress()
	for i in eggs.size():
		var egg = eggs[i]
		var ex: float = -7.0 + i * 7.0
		var ec: Color = Enums.ELEMENT_COLORS.get(egg["element"], Color.WHITE)
		var prog: float = egg["progress"]
		draw_circle(Vector2(ex, -8), 5.0, ec.lerp(Color(1, 1, 0.9), 1.0 - prog))
		if prog > 0.5:
			draw_arc(Vector2(ex, -8), 6.0, 0, TAU * prog, 12, Color(1, 1, 0.8, 0.5), 1.5)

func _draw_rest_zone():
	# Soft cushion/cloud bed
	draw_circle(Vector2(0, -4), 16.0, Color(0.70, 0.65, 0.88))
	draw_circle(Vector2(-8, -6), 10.0, Color(0.78, 0.72, 0.92))
	draw_circle(Vector2(8, -3), 11.0, Color(0.75, 0.70, 0.90))
	draw_circle(Vector2(0, -10), 8.0, Color(0.82, 0.78, 0.95))
	# Stars/sparkles
	for i in 3:
		var sx := -8.0 + i * 8.0
		draw_string(ThemeDB.fallback_font, Vector2(sx - 3, -18 - i * 3), "✦", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.9, 0.85, 1.0, 0.6))

func _draw_nature_cabin():
	var wood := Color(0.50, 0.35, 0.22)
	var wood_light := Color(0.58, 0.42, 0.28)
	var leaf := Color(0.35, 0.62, 0.28)
	var leaf_dark := Color(0.28, 0.50, 0.22)
	# Walls
	var walls := PackedVector2Array([
		Vector2(-16, -4), Vector2(-16, -22), Vector2(16, -22), Vector2(16, -4)
	])
	draw_colored_polygon(walls, wood)
	# Wall planks
	for i in 4:
		var y := -6 - i * 4
		draw_line(Vector2(-15, y), Vector2(15, y), wood_light, 0.8)
	# Door
	draw_rect(Rect2(-5, -15, 10, 11), Color(0.40, 0.28, 0.18))
	draw_rect(Rect2(-4, -14, 8, 10), Color(0.45, 0.32, 0.22))
	draw_circle(Vector2(2, -10), 1.0, Color(0.7, 0.6, 0.3))
	# Leafy roof
	var roof := PackedVector2Array([
		Vector2(-22, -22), Vector2(0, -38), Vector2(22, -22)
	])
	draw_colored_polygon(roof, leaf)
	draw_polyline(roof + PackedVector2Array([roof[0]]), leaf_dark, 2.0)
	# Leaf details on roof
	for i in 5:
		var lx := -14.0 + i * 7.0
		var ly: float = -26.0 - abs(lx) * 0.3
		draw_circle(Vector2(lx, ly), 5.0, leaf.lightened(0.1 + i * 0.03))
	# Window
	draw_rect(Rect2(6, -20, 6, 5), Color(0.6, 0.8, 0.95, 0.8))
	draw_rect(Rect2(6, -20, 6, 5), Color(0.45, 0.35, 0.22), false, 1.0)

func _draw_magic_tower():
	var stone := Color(0.48, 0.40, 0.55)
	var stone_light := Color(0.55, 0.48, 0.62)
	# Tower body
	var tower := PackedVector2Array([
		Vector2(-10, -4), Vector2(-12, -35), Vector2(0, -42),
		Vector2(12, -35), Vector2(10, -4)
	])
	draw_colored_polygon(tower, stone)
	draw_polyline(tower + PackedVector2Array([tower[0]]), stone_light, 1.5)
	# Stone blocks
	for i in 5:
		var y := -8 - i * 6
		draw_line(Vector2(-10 + i, y), Vector2(10 - i, y), stone_light, 0.7)
	# Crystal on top
	var t := Time.get_ticks_msec() * 0.003
	var glow := (sin(t) + 1.0) * 0.3
	var crystal_col := Color(0.7, 0.35, 0.9)
	# Crystal glow
	draw_circle(Vector2(0, -44), 10.0 + glow * 3, Color(0.7, 0.35, 0.9, 0.15 + glow * 0.1))
	# Crystal shards
	var shard := PackedVector2Array([
		Vector2(-3, -42), Vector2(0, -54), Vector2(3, -42)
	])
	draw_colored_polygon(shard, crystal_col.lightened(glow * 0.3))
	var shard2 := PackedVector2Array([
		Vector2(-5, -40), Vector2(-2, -48), Vector2(0, -40)
	])
	draw_colored_polygon(shard2, crystal_col.lightened(0.15))
	var shard3 := PackedVector2Array([
		Vector2(1, -41), Vector2(4, -50), Vector2(6, -41)
	])
	draw_colored_polygon(shard3, crystal_col.lightened(0.2))
	# Window slit
	draw_rect(Rect2(-2, -22, 4, 8), Color(0.6, 0.8, 0.95, 0.6))

func _draw_mining_workshop():
	var wood := Color(0.52, 0.42, 0.32)
	var rock := Color(0.50, 0.47, 0.42)
	# Workshop body
	var body := PackedVector2Array([
		Vector2(-18, -4), Vector2(-18, -18), Vector2(18, -18), Vector2(18, -4)
	])
	draw_colored_polygon(body, wood)
	# Flat roof
	var roof := PackedVector2Array([
		Vector2(-20, -18), Vector2(-18, -22), Vector2(18, -22), Vector2(20, -18)
	])
	draw_colored_polygon(roof, rock)
	# Anvil
	var anvil := PackedVector2Array([
		Vector2(-6, -4), Vector2(-8, -10), Vector2(-4, -12),
		Vector2(4, -12), Vector2(8, -10), Vector2(6, -4)
	])
	draw_colored_polygon(anvil, Color(0.38, 0.36, 0.34))
	draw_polyline(anvil + PackedVector2Array([anvil[0]]), Color(0.30, 0.28, 0.26), 1.5)
	# Chimney
	draw_rect(Rect2(10, -28, 5, 10), rock.darkened(0.1))
	# Smoke
	var t := Time.get_ticks_msec() * 0.002
	for i in 3:
		var sy := -30.0 - i * 6 - sin(t + i) * 2
		var sx := 12.5 + sin(t * 0.5 + i * 1.5) * 3
		draw_circle(Vector2(sx, sy), 3.0 - i * 0.5, Color(0.7, 0.65, 0.6, 0.3 - i * 0.08))
	# Door
	draw_rect(Rect2(-4, -14, 8, 10), Color(0.40, 0.32, 0.24))
	# Rock pile
	for i in 3:
		draw_circle(Vector2(-12.0 + i * 3, -6), 2.5, rock.darkened(0.15))

func _process(_d):
	queue_redraw()
"""
	s.reload()
	return s

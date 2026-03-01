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
	var affinity: int = Enums.BUILDING_ELEMENT_AFFINITY.get(btype, -1)
	var base_col := Color(0.75, 0.7, 0.6)
	var accent_col: Color = Enums.ELEMENT_COLORS.get(affinity, Color(0.85, 0.8, 0.7))

	# Shadow
	var shadow := PackedVector2Array([
		Vector2(0, 18), Vector2(30, 6), Vector2(0, -6), Vector2(-30, 6)
	])
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.1))

	# Base platform (isometric diamond)
	var base := PackedVector2Array([
		Vector2(0, 10), Vector2(28, -2), Vector2(0, -14), Vector2(-28, -2)
	])
	draw_colored_polygon(base, base_col)
	draw_polyline(base + PackedVector2Array([base[0]]), base_col.darkened(0.3), 1.5)

	# Building body
	match btype:
		Enums.BuildingType.INCUBATOR:
			_draw_incubator(bref, accent_col)
		Enums.BuildingType.REST_ZONE:
			_draw_rest_zone(accent_col)
		Enums.BuildingType.NATURE_CABIN:
			_draw_nature_cabin(accent_col)
		Enums.BuildingType.MAGIC_TOWER:
			_draw_magic_tower(accent_col)
		Enums.BuildingType.MINING_WORKSHOP:
			_draw_mining_workshop(accent_col)

	# Name label
	var icon: String = Enums.BUILDING_ICONS.get(btype, "")
	var bname: String = Enums.BUILDING_NAMES.get(btype, "")
	draw_string(ThemeDB.fallback_font, Vector2(-30, -38), icon + " " + bname, HORIZONTAL_ALIGNMENT_LEFT, 80, 9, Color.WHITE)

	# Capacity indicator
	var cap: int = bref.get_capacity()
	var used: int = bref.assigned_creatures.size()
	if btype == Enums.BuildingType.INCUBATOR:
		used = bref.incubating_eggs.size()
	var cap_text := str(used) + "/" + str(cap)
	draw_string(ThemeDB.fallback_font, Vector2(-10, -28), cap_text, HORIZONTAL_ALIGNMENT_LEFT, 40, 8, Color(0.95, 0.95, 0.9))

func _draw_incubator(bref, col: Color):
	# Dome shape
	var dome := PackedVector2Array([
		Vector2(-16, -4), Vector2(-12, -18), Vector2(0, -24),
		Vector2(12, -18), Vector2(16, -4)
	])
	draw_colored_polygon(dome, Color(0.9, 0.85, 0.75))
	draw_polyline(dome, col, 2.0)
	# Eggs inside (incubation progress)
	var eggs = bref.get_incubation_progress()
	for i in eggs.size():
		var egg = eggs[i]
		var ex: float = -8.0 + i * 8.0
		var ec: Color = Enums.ELEMENT_COLORS.get(egg["element"], Color.WHITE)
		draw_circle(Vector2(ex, -8), 4.0, ec.lerp(Color.WHITE, 1.0 - egg["progress"]))

func _draw_rest_zone(col: Color):
	# Bed/cushion shape
	var bed := PackedVector2Array([
		Vector2(-14, -4), Vector2(14, -4), Vector2(14, -12), Vector2(-14, -12)
	])
	draw_colored_polygon(bed, Color(0.6, 0.55, 0.85))
	draw_polyline(bed + PackedVector2Array([bed[0]]), Color(0.45, 0.4, 0.7), 1.5)
	# Pillow
	draw_circle(Vector2(-6, -10), 5.0, Color(0.8, 0.75, 0.95))

func _draw_nature_cabin(col: Color):
	# Cabin walls
	var walls := PackedVector2Array([
		Vector2(-14, -4), Vector2(-14, -20), Vector2(14, -20), Vector2(14, -4)
	])
	draw_colored_polygon(walls, Color(0.55, 0.4, 0.28))
	# Roof
	var roof := PackedVector2Array([
		Vector2(-18, -20), Vector2(0, -32), Vector2(18, -20)
	])
	draw_colored_polygon(roof, col)
	# Door
	draw_rect(Rect2(-4, -14, 8, 10), Color(0.4, 0.3, 0.2))

func _draw_magic_tower(col: Color):
	# Tower body
	var tower := PackedVector2Array([
		Vector2(-8, -4), Vector2(-10, -30), Vector2(0, -36),
		Vector2(10, -30), Vector2(8, -4)
	])
	draw_colored_polygon(tower, Color(0.5, 0.4, 0.6))
	draw_polyline(tower + PackedVector2Array([tower[0]]), col, 1.5)
	# Crystal on top
	var t := Time.get_ticks_msec() * 0.003
	var glow := (sin(t) + 1.0) * 0.3
	draw_circle(Vector2(0, -36), 5.0, col.lightened(glow))

func _draw_mining_workshop(col: Color):
	# Workshop body
	var body := PackedVector2Array([
		Vector2(-16, -4), Vector2(-16, -16), Vector2(16, -16), Vector2(16, -4)
	])
	draw_colored_polygon(body, Color(0.55, 0.5, 0.42))
	# Anvil
	var anvil := PackedVector2Array([
		Vector2(-6, -6), Vector2(-4, -12), Vector2(4, -12), Vector2(6, -6)
	])
	draw_colored_polygon(anvil, Color(0.4, 0.38, 0.35))

func _process(_d):
	queue_redraw()
"""
	s.reload()
	return s

extends CharacterBody2D

signal state_changed(new_state)

@export var element: int = Enums.Element.PLANT

var current_state: int = Enums.CreatureState.IDLE
var assigned_building = null
var energy := 100.0
var _state_timer := 0.0
var _target_pos := Vector2.ZERO
var _wander_origin := Vector2.ZERO
var _speed := 45.0
var _instability_offset := Vector2.ZERO
var _bob_time := 0.0

const WANDER_RADIUS := 80.0
const ENERGY_DRAIN := 2.0
const ENERGY_RESTORE := 15.0
const WORK_RANGE := 30.0

func _ready() -> void:
	_wander_origin = position
	_state_timer = randf_range(1.0, 3.0)
	_build_visual()
	_build_collision()

func _physics_process(delta: float) -> void:
	_state_timer -= delta
	energy = clampf(energy - ENERGY_DRAIN * delta, 0.0, 100.0)
	_bob_time += delta * 4.0

	var speed_mod := EcosystemManager.get_speed_modifier()
	var instability := EcosystemManager.get_instability()
	if instability > 0:
		_instability_offset = Vector2(
			sin(Time.get_ticks_msec() * 0.01 + position.x) * instability * 8.0,
			cos(Time.get_ticks_msec() * 0.012 + position.y) * instability * 4.0
		)
	else:
		_instability_offset = Vector2.ZERO

	match current_state:
		Enums.CreatureState.IDLE:
			_process_idle(delta)
		Enums.CreatureState.WANDER:
			_process_wander(delta, speed_mod)
		Enums.CreatureState.WORK:
			_process_work(delta, speed_mod)
		Enums.CreatureState.REST:
			_process_rest(delta)

	var bob := sin(_bob_time) * 1.5 if velocity.length() > 1.0 else 0.0
	if has_node("Visual"):
		$Visual.position = Vector2(0, bob) + _instability_offset

	queue_redraw()

func _process_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0:
		if energy < 30.0:
			_change_state(Enums.CreatureState.REST)
		elif assigned_building and randf() < 0.4:
			_change_state(Enums.CreatureState.WORK)
		else:
			_change_state(Enums.CreatureState.WANDER)

func _process_wander(delta: float, speed_mod: float) -> void:
	var dir := position.direction_to(_target_pos)
	var dist := position.distance_to(_target_pos)
	if dist < 5.0 or _state_timer <= 0:
		_change_state(Enums.CreatureState.IDLE)
		return
	velocity = Vector2(dir.x, dir.y * Enums.ISO_RATIO) * _speed * speed_mod
	move_and_slide()

func _process_work(delta: float, speed_mod: float) -> void:
	if not assigned_building or not is_instance_valid(assigned_building):
		_change_state(Enums.CreatureState.IDLE)
		return
	var target: Vector2 = assigned_building.global_position
	var dist := global_position.distance_to(target)
	if dist > WORK_RANGE:
		var dir := global_position.direction_to(target)
		velocity = Vector2(dir.x, dir.y) * _speed * speed_mod
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if _state_timer <= 0:
			_change_state(Enums.CreatureState.IDLE)

func _process_rest(delta: float) -> void:
	velocity = Vector2.ZERO
	energy = clampf(energy + ENERGY_RESTORE * delta, 0.0, 100.0)
	if energy >= 90.0 or _state_timer <= 0:
		_change_state(Enums.CreatureState.IDLE)

func _change_state(new_state: int) -> void:
	current_state = new_state
	match new_state:
		Enums.CreatureState.IDLE:
			_state_timer = randf_range(2.0, 4.0)
		Enums.CreatureState.WANDER:
			_state_timer = randf_range(3.0, 6.0)
			var angle := randf() * TAU
			var dist := randf_range(20.0, WANDER_RADIUS)
			_target_pos = _wander_origin + Vector2(cos(angle) * dist, sin(angle) * dist * Enums.ISO_RATIO)
		Enums.CreatureState.WORK:
			_state_timer = randf_range(4.0, 8.0)
		Enums.CreatureState.REST:
			_state_timer = randf_range(3.0, 6.0)
	state_changed.emit(new_state)

func get_interaction_type() -> String:
	return "creature"

func show_radial_menu() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_creature_menu(self)

func _build_visual() -> void:
	var vis := Node2D.new()
	vis.name = "Visual"
	add_child(vis)
	var creature_ref := self
	vis.set_script(_make_draw_script())
	vis.set_meta("creature_ref", self)

func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	col.position = Vector2(0, 2)
	add_child(col)
	collision_layer = 2
	collision_mask = 0

func _make_draw_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node2D

func _draw():
	var c_ref = get_meta("creature_ref")
	if not c_ref or not is_instance_valid(c_ref):
		return
	var elem: int = c_ref.element
	var col: Color = Enums.ELEMENT_COLORS.get(elem, Color.WHITE)
	var state: int = c_ref.current_state
	# Shadow
	draw_circle(Vector2(0, 6), 7.0, Color(0, 0, 0, 0.15))
	# Body shape varies by element
	match elem:
		Enums.Element.PLANT:
			_draw_plant(col)
		Enums.Element.FIRE:
			_draw_fire(col)
		Enums.Element.WATER:
			_draw_water(col)
		Enums.Element.ROCK:
			_draw_rock(col)
		Enums.Element.MAGIC:
			_draw_magic(col)
	# Eyes
	draw_circle(Vector2(-3, -6), 1.5, Color.WHITE)
	draw_circle(Vector2(3, -6), 1.5, Color.WHITE)
	draw_circle(Vector2(-3, -6), 0.8, Color(0.15, 0.1, 0.1))
	draw_circle(Vector2(3, -6), 0.8, Color(0.15, 0.1, 0.1))
	# State indicator
	if state == Enums.CreatureState.REST:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -18), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.8))
	elif state == Enums.CreatureState.WORK:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -18), "⚒", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col.darkened(0.2))
	# Energy bar
	var energy_pct: float = c_ref.energy / 100.0
	draw_rect(Rect2(-8, -22, 16, 2), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-8, -22, 16 * energy_pct, 2), Color(0.3, 0.9, 0.3) if energy_pct > 0.3 else Color(0.9, 0.3, 0.2))

func _draw_plant(col: Color):
	var body := PackedVector2Array([
		Vector2(0, -10), Vector2(9, 0), Vector2(6, 8),
		Vector2(0, 10), Vector2(-6, 8), Vector2(-9, 0)
	])
	draw_colored_polygon(body, col)
	draw_polyline(body + PackedVector2Array([body[0]]), col.darkened(0.3), 1.0)
	# Leaf accent
	draw_line(Vector2(0, -10), Vector2(5, -15), col.lightened(0.3), 2.0)
	draw_line(Vector2(0, -10), Vector2(-4, -14), col.lightened(0.3), 2.0)

func _draw_fire(col: Color):
	var body := PackedVector2Array([
		Vector2(0, -14), Vector2(8, -4), Vector2(6, 6),
		Vector2(0, 10), Vector2(-6, 6), Vector2(-8, -4)
	])
	draw_colored_polygon(body, col)
	# Flame crest
	var flame := PackedVector2Array([
		Vector2(-4, -12), Vector2(0, -20), Vector2(4, -12)
	])
	draw_colored_polygon(flame, col.lightened(0.3))

func _draw_water(col: Color):
	# Rounded blob
	draw_circle(Vector2(0, 0), 10.0, col)
	draw_circle(Vector2(-3, -3), 4.0, col.lightened(0.25))

func _draw_rock(col: Color):
	var body := PackedVector2Array([
		Vector2(-8, -6), Vector2(0, -10), Vector2(8, -6),
		Vector2(10, 2), Vector2(6, 8), Vector2(-6, 8), Vector2(-10, 2)
	])
	draw_colored_polygon(body, col)
	draw_polyline(body + PackedVector2Array([body[0]]), col.darkened(0.3), 1.5)

func _draw_magic(col: Color):
	draw_circle(Vector2(0, 0), 9.0, col.lightened(0.1))
	# Crystal accents
	for i in 3:
		var angle := i * TAU / 3.0 + Time.get_ticks_msec() * 0.002
		var p := Vector2(cos(angle) * 12, sin(angle) * 8)
		draw_circle(p, 3.0, col.lightened(0.4))

func _process(_d):
	queue_redraw()
"""
	s.reload()
	return s

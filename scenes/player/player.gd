extends CharacterBody2D

const WALK_SPEED := 120.0
const RUN_SPEED := 200.0
const INTERACTION_RADIUS := 60.0

var current_target = null
var _bob_time := 0.0
var _facing := Vector2(0, 1)

func _ready() -> void:
	GameManager.player = self
	z_index = 0
	_build_visual()
	_build_interaction_area()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_running := Input.is_action_pressed("run")
	var spd := RUN_SPEED if is_running else WALK_SPEED

	velocity = Vector2(input.x, input.y * Enums.ISO_RATIO).normalized() * spd
	if input.length() > 0.1:
		_facing = input.normalized()
	move_and_slide()

	position = GameManager.clamp_to_island(position, 20.0)

	_bob_time += delta * (8.0 if is_running else 5.0)
	var bob_offset := sin(_bob_time) * 2.0 if velocity.length() > 1.0 else 0.0
	$Visual.position.y = bob_offset

	_update_interaction_target()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_target:
		_interact_with(current_target)

func _build_visual() -> void:
	var vis := Node2D.new()
	vis.name = "Visual"
	add_child(vis)
	vis.set_script(_create_player_draw_script())

func _build_interaction_area() -> void:
	var area := Area2D.new()
	area.name = "InteractionArea"
	area.collision_layer = 0
	area.collision_mask = 0b11110
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACTION_RADIUS
	shape.shape = circle
	area.add_child(shape)
	add_child(area)

func _update_interaction_target() -> void:
	var area: Area2D = $InteractionArea
	var best_body = null
	var best_body_dist := 9999.0
	var best_area_target = null
	var best_area_dist := 9999.0

	for body in area.get_overlapping_bodies():
		if body == self:
			continue
		if not body.has_method("get_interaction_type"):
			continue
		var d := global_position.distance_to(body.global_position)
		if d < best_body_dist:
			best_body_dist = d
			best_body = body

	for a in area.get_overlapping_areas():
		var target_node = a
		if not target_node.has_method("get_interaction_type"):
			target_node = a.get_parent()
		if target_node == self or target_node == area:
			continue
		if not target_node.has_method("get_interaction_type"):
			continue
		var d := global_position.distance_to(target_node.global_position)
		if d < best_area_dist:
			best_area_dist = d
			best_area_target = target_node

	var best = best_body if best_body else best_area_target

	if best != current_target:
		current_target = best
		GameManager.interaction_target_changed.emit(current_target)

func _interact_with(target) -> void:
	if target.has_method("get_interaction_type"):
		var itype = target.get_interaction_type()
		match itype:
			"egg":
				if GameManager.held_egg_element < 0:
					GameManager.pickup_egg(target)
			"building":
				if GameManager.held_egg_element >= 0 and target.building_type == Enums.BuildingType.INCUBATOR:
					GameManager.deposit_egg(target)
				else:
					target.open_panel()
			"creature":
				target.show_radial_menu()

func _create_player_draw_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node2D

func _draw():
	# Shadow
	draw_circle(Vector2(0, 12), 16.0, Color(0, 0, 0, 0.12))
	# Body
	var body := PackedVector2Array([
		Vector2(0, -14), Vector2(13, -1), Vector2(10, 10),
		Vector2(0, 14), Vector2(-10, 10), Vector2(-13, -1)
	])
	draw_colored_polygon(body, Color(0.92, 0.82, 0.68))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.65, 0.52, 0.40), 1.8)
	# Shirt/tunic detail
	var tunic := PackedVector2Array([
		Vector2(-10, 2), Vector2(10, 2), Vector2(8, 10),
		Vector2(0, 14), Vector2(-8, 10)
	])
	draw_colored_polygon(tunic, Color(0.55, 0.72, 0.55))
	draw_polyline(tunic + PackedVector2Array([tunic[0]]), Color(0.40, 0.55, 0.40), 1.0)
	# Belt
	draw_line(Vector2(-10, 2), Vector2(10, 2), Color(0.50, 0.38, 0.25), 2.0)
	# Head
	draw_circle(Vector2(0, -21), 10.0, Color(0.95, 0.88, 0.78))
	draw_arc(Vector2(0, -21), 10.0, 0, TAU, 24, Color(0.65, 0.52, 0.40), 1.5)
	# Hair
	var hair := PackedVector2Array([
		Vector2(-9, -23), Vector2(-7, -32), Vector2(0, -34),
		Vector2(7, -32), Vector2(9, -23)
	])
	draw_colored_polygon(hair, Color(0.50, 0.35, 0.22))
	# Eyes
	draw_circle(Vector2(-3.5, -22), 2.0, Color.WHITE)
	draw_circle(Vector2(3.5, -22), 2.0, Color.WHITE)
	draw_circle(Vector2(-3.5, -22), 1.0, Color(0.20, 0.15, 0.10))
	draw_circle(Vector2(3.5, -22), 1.0, Color(0.20, 0.15, 0.10))
	# Eye shine
	draw_circle(Vector2(-4.0, -23), 0.6, Color(1, 1, 1, 0.8))
	draw_circle(Vector2(3.0, -23), 0.6, Color(1, 1, 1, 0.8))
	# Blush
	draw_circle(Vector2(-6, -19), 2.5, Color(0.95, 0.70, 0.65, 0.35))
	draw_circle(Vector2(6, -19), 2.5, Color(0.95, 0.70, 0.65, 0.35))
	# Smile
	draw_arc(Vector2(0, -18.5), 3.0, 0.2, PI - 0.2, 8, Color(0.50, 0.35, 0.25), 1.2)
	# Held egg
	if GameManager.held_egg_element >= 0:
		var c: Color = Enums.ELEMENT_COLORS[GameManager.held_egg_element]
		draw_circle(Vector2(15, -8), 7.0, c)
		draw_circle(Vector2(14, -10), 2.5, c.lightened(0.3))
		draw_arc(Vector2(15, -8), 7.0, 0, TAU, 12, c.darkened(0.2), 1.5)

func _process(_d):
	queue_redraw()
"""
	s.reload()
	return s

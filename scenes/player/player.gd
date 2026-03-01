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
	var best = null
	var best_dist := 9999.0

	for body in area.get_overlapping_bodies():
		if body == self:
			continue
		var d := global_position.distance_to(body.global_position)
		if d < best_dist:
			best_dist = d
			best = body

	for a in area.get_overlapping_areas():
		var target_node = a
		if not target_node.has_method("get_interaction_type"):
			target_node = a.get_parent()
		if target_node == self or target_node == area:
			continue
		if not target_node.has_method("get_interaction_type"):
			continue
		var d := global_position.distance_to(target_node.global_position)
		if d < best_dist:
			best_dist = d
			best = target_node

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
	draw_circle(Vector2(0, 11), 14.0, Color(0, 0, 0, 0.15))
	# Body (isometric diamond)
	var body := PackedVector2Array([
		Vector2(0, -16), Vector2(12, -2), Vector2(0, 12), Vector2(-12, -2)
	])
	draw_colored_polygon(body, Color(0.95, 0.88, 0.75))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.6, 0.5, 0.4), 1.5)
	# Head
	draw_circle(Vector2(0, -22), 8.0, Color(0.98, 0.92, 0.82))
	draw_arc(Vector2(0, -22), 8.0, 0, TAU, 24, Color(0.6, 0.5, 0.4), 1.5)
	# Eyes
	draw_circle(Vector2(-3, -23), 1.5, Color(0.25, 0.2, 0.15))
	draw_circle(Vector2(3, -23), 1.5, Color(0.25, 0.2, 0.15))
	# Held egg indicator
	if GameManager.held_egg_element >= 0:
		var c: Color = Enums.ELEMENT_COLORS[GameManager.held_egg_element]
		draw_circle(Vector2(14, -10), 6.0, c)
		draw_arc(Vector2(14, -10), 6.0, 0, TAU, 12, c.darkened(0.3), 1.5)

func _process(_d):
	queue_redraw()
"""
	s.reload()
	return s


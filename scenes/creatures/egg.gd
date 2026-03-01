extends Area2D

@export var element: int = Enums.Element.PLANT

var _hover_time := 0.0

func _ready() -> void:
	_build_visual()
	_build_collision()
	collision_layer = 8
	collision_mask = 0

func _process(delta: float) -> void:
	_hover_time += delta
	if has_node("Visual"):
		$Visual.position.y = sin(_hover_time * 2.5) * 3.0
	queue_redraw()

func get_interaction_type() -> String:
	return "egg"

func _build_visual() -> void:
	var vis := Node2D.new()
	vis.name = "Visual"
	add_child(vis)
	vis.set_meta("egg_ref", self)
	vis.set_script(_make_draw_script())

func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	add_child(col)

func _make_draw_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node2D

func _draw():
	var egg_ref = get_meta("egg_ref")
	if not egg_ref or not is_instance_valid(egg_ref):
		return
	var col: Color = Enums.ELEMENT_COLORS.get(egg_ref.element, Color.WHITE)
	var t := Time.get_ticks_msec() * 0.003
	var pulse := (sin(t) + 1.0) * 0.15
	# Glow aura
	draw_circle(Vector2(0, -2), 16.0 + pulse * 5.0, Color(col.r, col.g, col.b, 0.12 + pulse * 0.1))
	draw_circle(Vector2(0, -2), 12.0, Color(col.r, col.g, col.b, 0.08))
	# Shadow
	draw_circle(Vector2(0, 10), 8.0, Color(0, 0, 0, 0.12))
	# Egg shape
	var points := PackedVector2Array()
	for i in 24:
		var a: float = i * TAU / 24.0
		var rx := 8.0
		var ry := 11.0
		var squash: float = 1.0 + 0.15 * maxf(0.0, -sin(a))
		points.append(Vector2(cos(a) * rx, sin(a) * ry * squash - 2.0))
	draw_colored_polygon(points, col)
	draw_polyline(points + PackedVector2Array([points[0]]), col.darkened(0.20), 1.8)
	# Highlight
	draw_circle(Vector2(-3, -7), 3.0, col.lightened(0.35))
	draw_circle(Vector2(-2, -5), 1.5, Color(1, 1, 1, 0.45))
	# Pattern dots
	for i in 3:
		var dx := -3.0 + i * 3.0
		draw_circle(Vector2(dx, 2), 1.2, col.darkened(0.15))
	# Element icon
	var icon: String = Enums.ELEMENT_ICONS.get(egg_ref.element, "?")
	draw_string(ThemeDB.fallback_font, Vector2(-5, 5), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

func _process(_d):
	queue_redraw()
"""
	s.reload()
	return s

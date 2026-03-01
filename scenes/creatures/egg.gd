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
	# Shadow
	draw_circle(Vector2(0, 8), 6.0, Color(0, 0, 0, 0.12))
	# Egg shape (ellipse via polygon)
	var points := PackedVector2Array()
	for i in 16:
		var a: float = i * TAU / 16.0
		points.append(Vector2(cos(a) * 7.0, sin(a) * 10.0 - 2.0))
	draw_colored_polygon(points, col)
	draw_polyline(points + PackedVector2Array([points[0]]), col.darkened(0.25), 1.5)
	# Shine
	draw_circle(Vector2(-2, -5), 2.0, col.lightened(0.4))
	# Element symbol
	var icon: String = Enums.ELEMENT_ICONS.get(egg_ref.element, "?")
	draw_string(ThemeDB.fallback_font, Vector2(-5, 3), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

func _process(_d):
	queue_redraw()
"""
	s.reload()
	return s

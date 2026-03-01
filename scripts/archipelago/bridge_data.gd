class_name BridgeData
extends RefCounted

var id: int
var island_a_id: int
var island_b_id: int
var anchor_a: Vector2
var anchor_b: Vector2
var length: float
var style: int = 0  # 0=wood, 1=stone, 2=crystal, 3=vine, 4=rune
var control_point: Vector2
var path_points: PackedVector2Array = PackedVector2Array()
var valid: bool = true

const STYLE_NAMES := ["Bois", "Pierre", "Cristal", "Vignes", "Runes"]
const STYLE_COLORS := [
	Color(0.55, 0.40, 0.25),
	Color(0.55, 0.52, 0.50),
	Color(0.50, 0.70, 0.90),
	Color(0.35, 0.60, 0.30),
	Color(0.65, 0.40, 0.80),
]

func get_style_name() -> String:
	if style >= 0 and style < STYLE_NAMES.size():
		return STYLE_NAMES[style]
	return "?"

func get_style_color() -> Color:
	if style >= 0 and style < STYLE_COLORS.size():
		return STYLE_COLORS[style]
	return Color.WHITE

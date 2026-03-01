class_name IslandData
extends RefCounted

var id: int
var grid_pos: Vector2
var world_pos: Vector2
var height: float = 0.0
var biome: int = Enums.Element.PLANT
var size_class: int = 1  # 0=small, 1=medium, 2=large
var is_hub: bool = false
var connections: Array[int] = []
var radius: float = 80.0
var buildings: Array = []
var spawn_points: Array[Vector2] = []

func get_biome_name() -> String:
	return Enums.ELEMENT_NAMES.get(biome, "?")

func get_size_name() -> String:
	match size_class:
		0: return "Petite"
		1: return "Moyenne"
		2: return "Grande"
		_: return "?"

func get_tile_radius() -> int:
	match size_class:
		0: return 3
		1: return 4
		2: return 6
		_: return 4

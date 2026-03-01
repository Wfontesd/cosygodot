extends Node

signal creature_born(creature_node)
signal egg_spawned(egg_node)
signal building_placed(building_node)
signal interaction_target_changed(target)
signal held_item_changed(element_type)

var creatures: Array = []
var buildings: Array = []
var eggs: Array = []
var player: CharacterBody2D
var world_root: Node2D

var held_egg_element: int = -1

var creature_scene: PackedScene
var egg_scene: PackedScene
var building_scene: PackedScene

var _egg_spawn_timer := 0.0
const EGG_SPAWN_INTERVAL := 12.0
const MAX_EGGS := 8
const ISLAND_RADIUS := 350.0

func _ready() -> void:
	_setup_inputs()
	creature_scene = preload("res://scenes/creatures/creature.tscn")
	egg_scene = preload("res://scenes/creatures/egg.tscn")
	building_scene = preload("res://scenes/buildings/building.tscn")

func _process(delta: float) -> void:
	_egg_spawn_timer += delta
	if _egg_spawn_timer >= EGG_SPAWN_INTERVAL and eggs.size() < MAX_EGGS:
		_egg_spawn_timer = 0.0
		spawn_egg_random()

func _setup_inputs() -> void:
	var actions := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"run": [KEY_SHIFT],
		"cancel": [KEY_ESCAPE],
		"menu_1": [KEY_1],
		"menu_2": [KEY_2],
		"menu_3": [KEY_3],
		"menu_4": [KEY_4],
	}
	for action_name in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			for key in actions[action_name]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action_name, event)

func register_building(building_node) -> void:
	buildings.append(building_node)
	building_placed.emit(building_node)

func register_egg(egg_node) -> void:
	eggs.append(egg_node)
	egg_spawned.emit(egg_node)

func unregister_egg(egg_node) -> void:
	eggs.erase(egg_node)

func register_creature(creature_node) -> void:
	creatures.append(creature_node)
	creature_born.emit(creature_node)
	EcosystemManager.recalculate(creatures)

func unregister_creature(creature_node) -> void:
	creatures.erase(creature_node)
	EcosystemManager.recalculate(creatures)

func pickup_egg(egg_node) -> void:
	held_egg_element = egg_node.element
	unregister_egg(egg_node)
	egg_node.queue_free()
	held_item_changed.emit(held_egg_element)

func deposit_egg(building_node) -> void:
	if held_egg_element < 0:
		return
	building_node.add_egg(held_egg_element)
	held_egg_element = -1
	held_item_changed.emit(-1)

func spawn_creature_at(pos: Vector2, element: int) -> void:
	if not world_root:
		return
	var c = creature_scene.instantiate()
	c.element = element
	c.position = pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))
	world_root.add_child(c)
	register_creature(c)

func spawn_egg_random() -> void:
	if not world_root:
		return
	var angle := randf() * TAU
	var dist := randf_range(60.0, ISLAND_RADIUS - 40.0)
	var pos := Vector2(cos(angle) * dist, sin(angle) * dist * Enums.ISO_RATIO)
	var egg = egg_scene.instantiate()
	egg.element = randi_range(0, 4)
	egg.position = pos
	world_root.add_child(egg)
	register_egg(egg)

func spawn_egg_at(pos: Vector2, element: int) -> void:
	if not world_root:
		return
	var egg = egg_scene.instantiate()
	egg.element = element
	egg.position = pos
	world_root.add_child(egg)
	register_egg(egg)

func assign_creature_to_building(creature_node, building_node) -> void:
	if building_node.is_full():
		return
	if creature_node.assigned_building:
		creature_node.assigned_building.remove_creature(creature_node)
	building_node.add_creature(creature_node)
	creature_node.assigned_building = building_node
	EcosystemManager.recalculate(creatures)

func get_nearby_buildings(pos: Vector2, radius: float) -> Array:
	var result := []
	for b in buildings:
		if b.global_position.distance_to(pos) < radius:
			result.append(b)
	return result

class_name GenerationValidator
extends RefCounted

var warnings: Array[String] = []
var errors: Array[String] = []

func validate(gen: ArchipelagoGenerator) -> bool:
	warnings.clear()
	errors.clear()

	_check_island_count(gen)
	_check_connectivity(gen)
	_check_distances(gen)
	_check_bridge_lengths(gen)
	_check_degree(gen)
	_check_overlap(gen)

	return errors.is_empty()

func _check_island_count(gen: ArchipelagoGenerator) -> void:
	var n := gen.islands.size()
	if n < 8:
		errors.append("Trop peu d'îles : %d (min 8)" % n)
	elif n > 15:
		errors.append("Trop d'îles : %d (max 15)" % n)

func _check_connectivity(gen: ArchipelagoGenerator) -> void:
	if gen.islands.is_empty():
		errors.append("Aucune île générée")
		return

	var visited := {}
	var queue: Array[int] = [gen.hub_id]
	visited[gen.hub_id] = true

	while queue.size() > 0:
		var current: int = queue.pop_front()
		for neighbor in gen.islands[current].connections:
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)

	if visited.size() != gen.islands.size():
		var unreachable := gen.islands.size() - visited.size()
		errors.append("Graphe non connecté : %d îles inaccessibles" % unreachable)

func _check_distances(gen: ArchipelagoGenerator) -> void:
	for i in gen.islands.size():
		for j in range(i + 1, gen.islands.size()):
			var d := gen.islands[i].world_pos.distance_to(gen.islands[j].world_pos)
			if d < gen.min_distance * 0.5:
				warnings.append("Îles %d et %d très proches (%.0f < %.0f)" % [i, j, d, gen.min_distance])

func _check_bridge_lengths(gen: ArchipelagoGenerator) -> void:
	for bridge in gen.bridges:
		if not bridge.valid:
			warnings.append("Pont %d trop long (%.0f > %.0f)" % [bridge.id, bridge.length, gen.bridge_max_length])

func _check_degree(gen: ArchipelagoGenerator) -> void:
	for island in gen.islands:
		if island.connections.size() > gen.max_degree:
			warnings.append("Île %d : degré %d > max %d" % [island.id, island.connections.size(), gen.max_degree])

func _check_overlap(gen: ArchipelagoGenerator) -> void:
	for i in gen.islands.size():
		for j in range(i + 1, gen.islands.size()):
			var d := gen.islands[i].world_pos.distance_to(gen.islands[j].world_pos)
			var min_d := gen.islands[i].radius + gen.islands[j].radius
			if d < min_d * 0.7:
				warnings.append("Îles %d et %d se chevauchent (dist=%.0f < rayons=%.0f)" % [i, j, d, min_d])

func get_report() -> String:
	var lines := PackedStringArray()
	lines.append("=== Validation Report ===")
	lines.append("Errors: %d | Warnings: %d" % [errors.size(), warnings.size()])
	for e in errors:
		lines.append("  ✗ " + e)
	for w in warnings:
		lines.append("  ⚠ " + w)
	if errors.is_empty() and warnings.is_empty():
		lines.append("  ✓ All constraints satisfied")
	return "\n".join(lines)

extends Node

signal balance_changed(balance_dict)

var element_counts := {
	Enums.Element.PLANT: 0,
	Enums.Element.FIRE: 0,
	Enums.Element.WATER: 0,
	Enums.Element.ROCK: 0,
	Enums.Element.MAGIC: 0,
}

var element_ratios := {
	Enums.Element.PLANT: 0.0,
	Enums.Element.FIRE: 0.0,
	Enums.Element.WATER: 0.0,
	Enums.Element.ROCK: 0.0,
	Enums.Element.MAGIC: 0.0,
}

var active_effects := {}

const IMBALANCE_THRESHOLD := 0.35

func recalculate(creatures: Array) -> void:
	for key in element_counts:
		element_counts[key] = 0

	for c in creatures:
		if c and is_instance_valid(c):
			element_counts[c.element] += 1

	var total := 0
	for key in element_counts:
		total += element_counts[key]

	for key in element_ratios:
		element_ratios[key] = float(element_counts[key]) / max(total, 1)

	_compute_effects()
	balance_changed.emit(element_ratios)

func _compute_effects() -> void:
	active_effects.clear()
	if element_ratios[Enums.Element.FIRE] > IMBALANCE_THRESHOLD:
		active_effects["vegetation_slowed"] = element_ratios[Enums.Element.FIRE]
	if element_ratios[Enums.Element.WATER] > IMBALANCE_THRESHOLD:
		active_effects["incubation_slow"] = element_ratios[Enums.Element.WATER]
	if element_ratios[Enums.Element.ROCK] > IMBALANCE_THRESHOLD:
		active_effects["low_dynamism"] = element_ratios[Enums.Element.ROCK]
	if element_ratios[Enums.Element.MAGIC] > IMBALANCE_THRESHOLD:
		active_effects["instability"] = element_ratios[Enums.Element.MAGIC]

func get_speed_modifier() -> float:
	if active_effects.has("low_dynamism"):
		return lerp(1.0, 0.6, active_effects["low_dynamism"])
	return 1.0

func get_incubation_modifier() -> float:
	if active_effects.has("incubation_slow"):
		return lerp(1.0, 1.8, active_effects["incubation_slow"])
	return 1.0

func get_growth_modifier() -> float:
	if active_effects.has("vegetation_slowed"):
		return lerp(1.0, 0.5, active_effects["vegetation_slowed"])
	return 1.0

func get_instability() -> float:
	if active_effects.has("instability"):
		return active_effects["instability"]
	return 0.0

func get_synergy_bonus(building_element: int, creature_element: int) -> float:
	if building_element == creature_element:
		return 1.5
	return 1.0

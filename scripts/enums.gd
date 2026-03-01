extends Node

enum Element { PLANT, FIRE, WATER, ROCK, MAGIC }

enum BuildingType { INCUBATOR, REST_ZONE, NATURE_CABIN, MAGIC_TOWER, MINING_WORKSHOP }

enum CreatureState { IDLE, WANDER, WORK, REST }

const ELEMENT_COLORS := {
	Element.PLANT: Color(0.36, 0.76, 0.38),
	Element.FIRE: Color(0.93, 0.42, 0.18),
	Element.WATER: Color(0.25, 0.56, 0.92),
	Element.ROCK: Color(0.62, 0.52, 0.40),
	Element.MAGIC: Color(0.70, 0.35, 0.90),
}

const ELEMENT_NAMES := {
	Element.PLANT: "Plante",
	Element.FIRE: "Feu",
	Element.WATER: "Eau",
	Element.ROCK: "Roche",
	Element.MAGIC: "Magie",
}

const ELEMENT_ICONS := {
	Element.PLANT: "🌿",
	Element.FIRE: "🔥",
	Element.WATER: "💧",
	Element.ROCK: "🪨",
	Element.MAGIC: "✨",
}

const BUILDING_NAMES := {
	BuildingType.INCUBATOR: "Incubateur",
	BuildingType.REST_ZONE: "Zone de repos",
	BuildingType.NATURE_CABIN: "Cabane nature",
	BuildingType.MAGIC_TOWER: "Tour magique",
	BuildingType.MINING_WORKSHOP: "Atelier minier",
}

const BUILDING_ICONS := {
	BuildingType.INCUBATOR: "🥚",
	BuildingType.REST_ZONE: "🛏️",
	BuildingType.NATURE_CABIN: "🌿",
	BuildingType.MAGIC_TOWER: "🔮",
	BuildingType.MINING_WORKSHOP: "🪨",
}

const BUILDING_CAPACITIES := {
	BuildingType.INCUBATOR: 3,
	BuildingType.REST_ZONE: 4,
	BuildingType.NATURE_CABIN: 3,
	BuildingType.MAGIC_TOWER: 2,
	BuildingType.MINING_WORKSHOP: 3,
}

const BUILDING_ELEMENT_AFFINITY := {
	BuildingType.INCUBATOR: -1,
	BuildingType.REST_ZONE: -1,
	BuildingType.NATURE_CABIN: Element.PLANT,
	BuildingType.MAGIC_TOWER: Element.MAGIC,
	BuildingType.MINING_WORKSHOP: Element.ROCK,
}

const ISO_RATIO := 0.5

extends CanvasLayer

var _interaction_prompt: PanelContainer
var _prompt_label: Label
var _balance_bars = {}
var _creature_count_label: Label
var _held_item_label: Label
var _building_panel: PanelContainer
var _building_panel_content: VBoxContainer
var _radial_menu: PanelContainer
var _radial_content: VBoxContainer
var _active_creature_for_menu = null
var _effects_label: Label
var _hint_label: Label

func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_build_hud()
	_build_interaction_prompt()
	_build_building_panel()
	_build_radial_menu()

	GameManager.interaction_target_changed.connect(_on_target_changed)
	GameManager.held_item_changed.connect(_on_held_changed)
	EcosystemManager.balance_changed.connect(_on_balance_changed)
	GameManager.creature_born.connect(func(_c): _update_creature_count())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_building_panel.visible = false
		_radial_menu.visible = false
	if _radial_menu.visible:
		if event.is_action_pressed("menu_1"):
			_on_radial_option(0)
		elif event.is_action_pressed("menu_2"):
			_on_radial_option(1)
		elif event.is_action_pressed("menu_3"):
			_on_radial_option(2)

func _build_hud() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.size = Vector2(260, 220)
	add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.82)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "🏝️ Floating Sanctuary"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var balance_label := Label.new()
	balance_label.text = "Équilibre élémentaire :"
	balance_label.add_theme_font_size_override("font_size", 10)
	balance_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(balance_label)

	for elem in Enums.Element.values():
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		vbox.add_child(hbox)

		var icon := Label.new()
		icon.text = Enums.ELEMENT_ICONS[elem]
		icon.add_theme_font_size_override("font_size", 11)
		icon.custom_minimum_size.x = 22
		hbox.add_child(icon)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(120, 10)
		bar.max_value = 1.0
		bar.value = 0.0
		bar.show_percentage = false
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = Enums.ELEMENT_COLORS[elem].darkened(0.6)
		bar_style.corner_radius_top_left = 3
		bar_style.corner_radius_top_right = 3
		bar_style.corner_radius_bottom_left = 3
		bar_style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("background", bar_style)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Enums.ELEMENT_COLORS[elem]
		fill_style.corner_radius_top_left = 3
		fill_style.corner_radius_top_right = 3
		fill_style.corner_radius_bottom_left = 3
		fill_style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("fill", fill_style)
		hbox.add_child(bar)
		_balance_bars[elem] = bar

		var pct := Label.new()
		pct.name = "Pct" + str(elem)
		pct.text = "0%"
		pct.add_theme_font_size_override("font_size", 9)
		pct.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		pct.custom_minimum_size.x = 30
		hbox.add_child(pct)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	_creature_count_label = Label.new()
	_creature_count_label.text = "Créatures : 0"
	_creature_count_label.add_theme_font_size_override("font_size", 10)
	_creature_count_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_creature_count_label)

	_held_item_label = Label.new()
	_held_item_label.text = ""
	_held_item_label.add_theme_font_size_override("font_size", 10)
	_held_item_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	vbox.add_child(_held_item_label)

	_effects_label = Label.new()
	_effects_label.text = ""
	_effects_label.add_theme_font_size_override("font_size", 9)
	_effects_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
	_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_effects_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(440, 680)
	_hint_label.text = "WASD : Déplacer  |  Shift : Courir  |  E : Interagir  |  Esc : Fermer"
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	add_child(_hint_label)

func _build_interaction_prompt() -> void:
	_interaction_prompt = PanelContainer.new()
	_interaction_prompt.position = Vector2(560, 620)
	_interaction_prompt.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18, 0.88)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_interaction_prompt.add_theme_stylebox_override("panel", style)

	_prompt_label = Label.new()
	_prompt_label.text = ""
	_prompt_label.add_theme_font_size_override("font_size", 12)
	_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	_interaction_prompt.add_child(_prompt_label)
	add_child(_interaction_prompt)

func _build_building_panel() -> void:
	_building_panel = PanelContainer.new()
	_building_panel.position = Vector2(880, 100)
	_building_panel.custom_minimum_size = Vector2(280, 200)
	_building_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.35, 0.55)
	_building_panel.add_theme_stylebox_override("panel", style)

	_building_panel_content = VBoxContainer.new()
	_building_panel_content.add_theme_constant_override("separation", 4)
	_building_panel.add_child(_building_panel_content)
	add_child(_building_panel)

func _build_radial_menu() -> void:
	_radial_menu = PanelContainer.new()
	_radial_menu.position = Vector2(500, 300)
	_radial_menu.custom_minimum_size = Vector2(220, 0)
	_radial_menu.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18, 0.92)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.45, 0.7)
	_radial_menu.add_theme_stylebox_override("panel", style)

	_radial_content = VBoxContainer.new()
	_radial_content.add_theme_constant_override("separation", 2)
	_radial_menu.add_child(_radial_content)
	add_child(_radial_menu)

func _on_target_changed(target) -> void:
	if not target:
		_interaction_prompt.visible = false
		return
	_interaction_prompt.visible = true
	if target.has_method("get_interaction_type"):
		var itype: String = target.get_interaction_type()
		match itype:
			"egg":
				if GameManager.held_egg_element < 0:
					var elem_name = Enums.ELEMENT_NAMES.get(target.element, "?")
					_prompt_label.text = "E : Ramasser l'œuf (" + str(elem_name) + ")"
				else:
					_prompt_label.text = "(mains pleines)"
			"building":
				var bname = Enums.BUILDING_NAMES.get(target.building_type, "Bâtiment")
				if GameManager.held_egg_element >= 0 and target.building_type == Enums.BuildingType.INCUBATOR:
					_prompt_label.text = "E : Déposer l'œuf dans " + str(bname)
				else:
					_prompt_label.text = "E : Ouvrir " + str(bname)
			"creature":
				_prompt_label.text = "E : Interagir avec la créature"

func _on_held_changed(element: int) -> void:
	if element >= 0:
		var ename = Enums.ELEMENT_NAMES.get(element, "?")
		var eicon = Enums.ELEMENT_ICONS.get(element, "")
		_held_item_label.text = "Tenu : " + str(eicon) + " Œuf " + str(ename)
	else:
		_held_item_label.text = ""

func _on_balance_changed(ratios: Dictionary) -> void:
	for elem in ratios:
		if _balance_bars.has(elem):
			_balance_bars[elem].value = ratios[elem]
			var pct_node = _balance_bars[elem].get_parent().get_node("Pct" + str(elem))
			if pct_node:
				pct_node.text = str(int(ratios[elem] * 100)) + "%"
	_update_effects_display()

func _update_creature_count() -> void:
	_creature_count_label.text = "Créatures : " + str(GameManager.creatures.size())

func _update_effects_display() -> void:
	var effects = EcosystemManager.active_effects
	if effects.is_empty():
		_effects_label.text = "Écosystème : Équilibré ✨"
		return
	var lines := PackedStringArray()
	if effects.has("vegetation_slowed"):
		lines.append("⚠ Trop de Feu → végétation ralentie")
	if effects.has("incubation_slow"):
		lines.append("⚠ Trop d'Eau → incubation lente")
	if effects.has("low_dynamism"):
		lines.append("⚠ Trop de Roche → dynamisme réduit")
	if effects.has("instability"):
		lines.append("⚠ Trop de Magie → instabilité")
	_effects_label.text = "\n".join(lines)

func show_building_panel(building) -> void:
	_radial_menu.visible = false
	_building_panel.visible = true
	_refresh_building_panel(building)

func _refresh_building_panel(building) -> void:
	for c in _building_panel_content.get_children():
		c.queue_free()

	var bname = Enums.BUILDING_NAMES.get(building.building_type, "Bâtiment")
	var bicon = Enums.BUILDING_ICONS.get(building.building_type, "")

	var title := Label.new()
	title.text = str(bicon) + " " + str(bname)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_building_panel_content.add_child(title)

	var sep := HSeparator.new()
	_building_panel_content.add_child(sep)

	if building.building_type == Enums.BuildingType.INCUBATOR:
		var eggs_info := Label.new()
		var progress = building.get_incubation_progress()
		if progress.is_empty():
			eggs_info.text = "Aucun œuf en incubation"
		else:
			var lines := PackedStringArray()
			for p in progress:
				var ename = Enums.ELEMENT_NAMES.get(p["element"], "?")
				var eicon = Enums.ELEMENT_ICONS.get(p["element"], "")
				lines.append(str(eicon) + " " + str(ename) + " : " + str(int(p["progress"] * 100)) + "%")
			eggs_info.text = "\n".join(lines)
		eggs_info.add_theme_font_size_override("font_size", 10)
		eggs_info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		_building_panel_content.add_child(eggs_info)
	else:
		var cap = building.get_capacity()
		var used = building.assigned_creatures.size()
		var cap_label := Label.new()
		cap_label.text = "Occupants : " + str(used) + " / " + str(cap)
		cap_label.add_theme_font_size_override("font_size", 10)
		cap_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		_building_panel_content.add_child(cap_label)

		for creature in building.assigned_creatures:
			if creature and is_instance_valid(creature):
				var cl := Label.new()
				var eicon = Enums.ELEMENT_ICONS.get(creature.element, "")
				var ename = Enums.ELEMENT_NAMES.get(creature.element, "?")
				cl.text = "  " + str(eicon) + " Créature " + str(ename)
				cl.add_theme_font_size_override("font_size", 9)
				cl.add_theme_color_override("font_color", Enums.ELEMENT_COLORS.get(creature.element, Color.WHITE))
				_building_panel_content.add_child(cl)

	var synergy = building.get_synergy_bonus()
	if synergy > 1.0:
		var syn_label := Label.new()
		syn_label.text = "✨ Bonus de synergie : x" + str(snapped(synergy, 0.01))
		syn_label.add_theme_font_size_override("font_size", 10)
		syn_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		_building_panel_content.add_child(syn_label)

	var close_hint := Label.new()
	close_hint.text = "\n[Esc] Fermer"
	close_hint.add_theme_font_size_override("font_size", 9)
	close_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_building_panel_content.add_child(close_hint)

func show_creature_menu(creature) -> void:
	_building_panel.visible = false
	_radial_menu.visible = true
	_active_creature_for_menu = creature
	_refresh_radial_menu(creature)

func _refresh_radial_menu(creature) -> void:
	for c in _radial_content.get_children():
		c.queue_free()

	var eicon = Enums.ELEMENT_ICONS.get(creature.element, "")
	var ename = Enums.ELEMENT_NAMES.get(creature.element, "?")

	var title := Label.new()
	title.text = str(eicon) + " Créature " + str(ename)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Enums.ELEMENT_COLORS.get(creature.element, Color.WHITE))
	_radial_content.add_child(title)

	var energy_label := Label.new()
	energy_label.text = "Énergie : " + str(int(creature.energy)) + "%"
	energy_label.add_theme_font_size_override("font_size", 10)
	energy_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_radial_content.add_child(energy_label)

	var state_names = {
		Enums.CreatureState.IDLE: "Au repos",
		Enums.CreatureState.WANDER: "Exploration",
		Enums.CreatureState.WORK: "Travail",
		Enums.CreatureState.REST: "Sommeil",
	}
	var state_label := Label.new()
	state_label.text = "État : " + str(state_names.get(creature.current_state, "?"))
	state_label.add_theme_font_size_override("font_size", 10)
	state_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_radial_content.add_child(state_label)

	var sep := HSeparator.new()
	_radial_content.add_child(sep)

	var nearby := GameManager.get_nearby_buildings(creature.global_position, 200.0)
	var options: Array = []
	for b in nearby:
		if not b.is_full() and b.building_type != Enums.BuildingType.INCUBATOR:
			options.append(b)

	if options.is_empty():
		var no_opt := Label.new()
		no_opt.text = "(Aucun bâtiment disponible)"
		no_opt.add_theme_font_size_override("font_size", 10)
		no_opt.add_theme_color_override("font_color", Color(0.6, 0.55, 0.55))
		_radial_content.add_child(no_opt)
	else:
		for i in mini(options.size(), 3):
			var b = options[i]
			var bicon = Enums.BUILDING_ICONS.get(b.building_type, "")
			var bname = Enums.BUILDING_NAMES.get(b.building_type, "?")
			var opt := Label.new()
			opt.text = "[" + str(i + 1) + "] Assigner → " + str(bicon) + " " + str(bname)
			opt.add_theme_font_size_override("font_size", 11)
			opt.add_theme_color_override("font_color", Color(0.9, 0.88, 0.75))
			opt.set_meta("building_ref", b)
			_radial_content.add_child(opt)

	var close_hint := Label.new()
	close_hint.text = "\n[Esc] Fermer"
	close_hint.add_theme_font_size_override("font_size", 9)
	close_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_radial_content.add_child(close_hint)

func _on_radial_option(index: int) -> void:
	if not _active_creature_for_menu or not is_instance_valid(_active_creature_for_menu):
		_radial_menu.visible = false
		return
	var option_idx := 0
	for child in _radial_content.get_children():
		if child.has_meta("building_ref"):
			if option_idx == index:
				var building = child.get_meta("building_ref")
				GameManager.assign_creature_to_building(_active_creature_for_menu, building)
				_radial_menu.visible = false
				return
			option_idx += 1
	_radial_menu.visible = false

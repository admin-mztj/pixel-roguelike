extends CanvasLayer

## Map selection overlay shown after clearing a room with multiple exits.
## Player clicks a room button to choose their next path.

signal room_selected(room_key: String)

const ICONS := {
	0: "⚔️", 1: "💀", 2: "🛒", 3: "⛩️",
	4: "🔥", 5: "📦", 6: "❓", 7: "👹",
}

const COL_HEADERS := ["Start", "I", "II", "III", "Boss"]

@onready var panel: Panel = $Panel
@onready var biome_label: Label = $Panel/BiomeLabel
@onready var columns_container: HBoxContainer = $Panel/ScrollContainer/ColumnsContainer
@onready var instruction_label: Label = $Panel/InstructionLabel

var _next_node_keys: Array[String] = []  # Track available next room keys


func show_map(map_graph: RefCounted, current_node_index: int) -> void:
	# Clear previous
	for child in columns_container.get_children():
		child.queue_free()
	_next_node_keys.clear()

	var current_node = map_graph.flat_nodes[current_node_index]
	var reachable: Dictionary = {}
	for idx in current_node.next_node_indices:
		reachable[idx] = true

	# Build 5 columns
	for col in range(5):
		var col_vbox = VBoxContainer.new()
		col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_vbox.add_theme_constant_override("separation", 4)

		var header = Label.new()
		header.text = COL_HEADERS[col]
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		col_vbox.add_child(header)

		for node in map_graph.columns[col]:
			var idx = map_graph.flat_nodes.find(node)
			var btn = Button.new()
			btn.size_flags_horizontal = Control.SIZE_FILL
			btn.custom_minimum_size = Vector2(130, 36)

			var icon = ICONS.get(node.room_type, "?")
			var name_text = _get_room_name(node)
			btn.text = "%s %s" % [icon, name_text]

			if node.is_completed:
				btn.disabled = true
				btn.text = "✓ " + btn.text
			elif node.is_current:
				btn.disabled = true
				btn.modulate = Color(1, 1, 0.3, 1)
			elif reachable.has(idx):
				btn.pressed.connect(_on_room_pressed.bind(node.room_key))
				btn.modulate = Color(1, 0.9, 0.5, 1)
				_next_node_keys.append(node.room_key)
			else:
				btn.disabled = true
				btn.modulate = Color(0.25, 0.25, 0.25, 0.4)

			col_vbox.add_child(btn)
		columns_container.add_child(col_vbox)

	if map_graph.biome_data:
		biome_label.text = map_graph.biome_data.biome_name
		biome_label.add_theme_color_override("font_color", map_graph.biome_data.map_tint)

	instruction_label.text = "Click a highlighted room to proceed" if _next_node_keys.size() > 1 else "Continue to the next room..."
	visible = true


func hide_map() -> void:
	visible = false


func _on_room_pressed(room_key: String) -> void:
	room_selected.emit(room_key)
	hide_map()


func _get_room_name(node: RefCounted) -> String:
	# Try to load RoomData to get display name
	if not node.room_data_path.is_empty():
		var data = load(node.room_data_path)
		if data and data.get("room_name"):
			return data.room_name
	return node.room_key

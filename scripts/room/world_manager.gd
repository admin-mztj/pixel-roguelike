extends Node2D

## World manager: biome progression, map generation, room transitions, game over.
## P3: Replaces hardcoded room_registry with dynamic MapGraph generation.

const BIOME_DATA_PATHS = [
	"res://resources/biomes/forest.tres",
	"res://resources/biomes/graveyard.tres",
	"res://resources/biomes/lava.tres",
	"res://resources/biomes/void.tres",
]

var biome_list: Array = []           # Array[BiomeData]
var current_map_graph: RefCounted = null
var current_biome_idx: int = 0
var transition_in_progress: bool = false
var game_over: bool = false
var room_registry: Dictionary = {}

@onready var rooms_container: Node2D = $Rooms
@onready var player: CharacterBody2D = $Player
@onready var fade_rect: ColorRect = $"FadeOverlay/ColorRect"
@onready var map_select_ui: CanvasLayer = $MapSelectUI
@onready var game_over_ui: CanvasLayer = $GameOverUI
@onready var game_over_label: Label = $"GameOverUI/Overlay/Label"
@onready var victory_ui: CanvasLayer = $VictoryUI


func _ready() -> void:
	# Load biomes
	for path in BIOME_DATA_PATHS:
		var data = load(path)
		if data:
			biome_list.append(data)

	# Connect signals
	EventBus.room_cleared.connect(_on_room_cleared)
	EventBus.room_transition_requested.connect(_on_room_transition_requested)
	EventBus.game_over.connect(_on_game_over)
	map_select_ui.room_selected.connect(_on_map_room_selected)

	# Hide UI
	game_over_ui.hide()
	victory_ui.hide()
	map_select_ui.hide_map()
	fade_rect.modulate.a = 0.0

	# Start first biome
	_start_biome(0)


func _start_biome(biome_index: int) -> void:
	if biome_index >= biome_list.size():
		_show_victory()
		return

	current_biome_idx = biome_index
	var biome = biome_list[biome_index]

	# Generate map graph
	var graph = load("res://scripts/room/map_graph.gd").new()
	graph.generate(biome, randi())
	current_map_graph = graph

	# Build dynamic registry from graph
	room_registry.clear()
	for node in graph.flat_nodes:
		node.is_completed = false
		node.is_current = false
		room_registry[node.room_key] = {
			"scene": "res://scenes/room/room_base.tscn",
			"data": node.room_data_path,
		}

	# Update game state
	GameState.current_biome_index = biome_index
	GameState.current_biome_name = biome.biome_name
	GameState.rooms_cleared_in_biome = 0
	EventBus.biome_changed.emit(biome)
	EventBus.map_generated.emit(graph)

	# Load start room (column 0)
	var start_node = graph.columns[0][0]
	start_node.is_current = true
	_load_room(start_node.room_key, "")


func _load_room(room_key: String, entry_direction: String) -> void:
	if not room_registry.has(room_key):
		push_error("Room key not found: " + room_key)
		return

	var info: Dictionary = room_registry[room_key]
	var room_scene = load(info["scene"])
	var room = room_scene.instantiate()
	room.room_data = load(info["data"])

	# Apply biome color overrides
	if current_biome_idx < biome_list.size():
		var biome = biome_list[current_biome_idx]
		if room.room_data:
			room.room_data.floor_color = biome.floor_color
			room.room_data.wall_color = biome.wall_color

	# Configure door connections from map graph
	_configure_room_from_graph(room, room_key)

	rooms_container.add_child(room)

	# Position player
	if entry_direction.is_empty():
		player.global_position = Vector2.ZERO
	else:
		var entry_pos = room.get_entry_position(entry_direction)
		player.global_position = entry_pos

	_set_camera_limits()
	room.activate_room(entry_direction)


func _unload_current_room() -> void:
	for child in rooms_container.get_children():
		if child.has_method("deactivate_room"):
			child.deactivate_room()
		child.queue_free()


func _configure_room_from_graph(room: Node2D, room_key: String) -> void:
	var node = current_map_graph.get_node_by_key(room_key)
	if not node:
		return

	var doors_node = room.get_node("Doors")
	var door_children = doors_node.get_children()
	if door_children.is_empty():
		return

	# Collect door directions
	var door_dirs: Array[String] = []
	for door_child in door_children:
		var dir = _get_door_direction(door_child)
		door_dirs.append(dir)

	# Assign connections for next nodes
	for i in range(min(node.next_node_indices.size(), door_dirs.size())):
		var next_idx = node.next_node_indices[i]
		if next_idx >= 0 and next_idx < current_map_graph.flat_nodes.size():
			var next_node = current_map_graph.flat_nodes[next_idx]
			var d = door_dirs[i]
			var entry = _opposite_direction(d)
			for door_child in door_children:
				if _get_door_direction(door_child) == d:
					door_child.connected_room = next_node.room_key
					door_child.connected_entry = entry
					if door_child.has_method("set_connection"):
						door_child.set_connection(next_node.room_key, entry)


func _get_door_direction(door: Node2D) -> String:
	if abs(door.rotation_degrees) < 45:
		return "north" if door.position.y < 0 else "south"
	else:
		return "west" if door.position.x < 0 else "east"


func _opposite_direction(dir: String) -> String:
	match dir:
		"north": return "South"
		"south": return "North"
		"east": return "West"
		"west": return "East"
	return ""


func _on_room_cleared(room_node: Node2D) -> void:
	if transition_in_progress or game_over:
		return

	var current_node = _get_current_map_node()
	if current_node:
		current_node.is_completed = true
		current_node.is_current = false

	GameState.rooms_cleared_in_biome += 1

	if not current_node:
		return

	var next_indices = current_node.next_node_indices

	if next_indices.is_empty():
		_advance_biome()
	elif next_indices.size() == 1:
		await get_tree().create_timer(1.0).timeout
		if not game_over:
			_transition_to_node(next_indices[0])
	else:
		await get_tree().create_timer(0.5).timeout
		if not game_over:
			var cur_idx = current_map_graph.flat_nodes.find(current_node)
			map_select_ui.show_map(current_map_graph, cur_idx)


func _on_map_room_selected(room_key: String) -> void:
	var node = current_map_graph.get_node_by_key(room_key)
	if node:
		var idx = current_map_graph.flat_nodes.find(node)
		_transition_to_node(idx)


func _transition_to_node(target_index: int) -> void:
	transition_in_progress = true
	player.disable_input()
	await _fade_to(1.0, 0.3)
	_unload_current_room()
	_load_room(current_map_graph.flat_nodes[target_index].room_key, _get_entry_dir(target_index))
	await _fade_to(0.0, 0.3)
	player.enable_input()
	transition_in_progress = false


func _on_room_transition_requested(door: Node2D) -> void:
	if transition_in_progress or game_over:
		return
	var next_room = door.connected_room
	if next_room.is_empty():
		return
	transition_in_progress = true
	player.disable_input()
	await _fade_to(1.0, 0.3)
	_unload_current_room()
	_load_room(next_room, door.connected_entry)
	await _fade_to(0.0, 0.3)
	player.enable_input()
	transition_in_progress = false


func _advance_biome() -> void:
	await get_tree().create_timer(1.5).timeout
	if game_over:
		return
	transition_in_progress = true
	player.disable_input()
	await _fade_to(1.0, 0.5)
	_unload_current_room()
	await _fade_to(0.0, 0.5)
	_start_biome(current_biome_idx + 1)
	player.enable_input()
	transition_in_progress = false


func _get_current_map_node() -> RefCounted:
	for node in current_map_graph.flat_nodes:
		if node.is_current:
			return node
	return null


func _get_entry_dir(target_index: int) -> String:
	if target_index < 0 or target_index >= current_map_graph.flat_nodes.size():
		return ""
	# Default: enter from west if moving right in columns
	return "West"


func _fade_to(target_alpha: float, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", target_alpha, duration)
	await tween.finished


func _set_camera_limits() -> void:
	var camera = player.get_node("Camera2D") as Camera2D
	if not camera:
		return
	var half_w = 960.0 / 2.0
	var half_h = 540.0 / 2.0
	var margin = 40.0
	camera.limit_left = int(-half_w + margin)
	camera.limit_right = int(half_w - margin)
	camera.limit_top = int(-half_h + margin)
	camera.limit_bottom = int(half_h - margin)


func _on_game_over() -> void:
	game_over = true
	game_over_ui.show()
	game_over_label.text = "GAME OVER\nPress R to restart"
	if not InputMap.has_action("restart"):
		var event = InputEventKey.new()
		event.physical_keycode = KEY_R
		InputMap.add_action("restart")
		InputMap.action_add_event("restart", event)


func _show_victory() -> void:
	game_over = true
	victory_ui.show()
	if not InputMap.has_action("restart"):
		var event = InputEventKey.new()
		event.physical_keycode = KEY_R
		InputMap.add_action("restart")
		InputMap.action_add_event("restart", event)


func _input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

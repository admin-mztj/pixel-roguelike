extends Node2D

## World manager: room loading, transitions, game over.
## Replaces the old game_manager.gd in a multi-room architecture.

const STARTING_ROOM = "room_1"

# Room registry: key → { scene_path, data_path }
var room_registry: Dictionary = {}

var current_room: Node2D = null
var current_room_key: String = ""
var transition_in_progress: bool = false
var game_over: bool = false

@onready var rooms_container: Node2D = $Rooms
@onready var player: CharacterBody2D = $Player
@onready var fade_rect: ColorRect = $"FadeOverlay/ColorRect"
@onready var game_over_ui: CanvasLayer = $GameOverUI
@onready var game_over_label: Label = $"GameOverUI/Overlay/Label"


func _ready() -> void:
	_build_registry()

	# Connect signals
	EventBus.room_transition_requested.connect(_on_room_transition_requested)
	EventBus.game_over.connect(_on_game_over)

	# Hide UI
	game_over_ui.hide()
	fade_rect.modulate.a = 0.0

	# Load starting room
	_load_room(STARTING_ROOM, "")


func _build_registry() -> void:
	room_registry = {
		"room_1": {
			"scene": "res://scenes/room/room_base.tscn",
			"data": "res://resources/rooms/combat_1.tres",
		},
		"room_2": {
			"scene": "res://scenes/room/room_base.tscn",
			"data": "res://resources/rooms/combat_2.tres",
		},
		"room_3": {
			"scene": "res://scenes/room/room_base.tscn",
			"data": "res://resources/rooms/combat_3.tres",
		},
		"room_4": {
			"scene": "res://scenes/room/room_base.tscn",
			"data": "res://resources/rooms/elite.tres",
		},
	}


func _load_room(room_key: String, entry_direction: String) -> void:
	if not room_registry.has(room_key):
		push_error("Room key not found: " + room_key)
		return

	var info: Dictionary = room_registry[room_key]
	var room_scene = load(info["scene"]) as PackedScene
	var room = room_scene.instantiate()

	# Assign room data
	var data = load(info["data"])
	room.room_data = data

	rooms_container.add_child(room)
	current_room = room
	current_room_key = room_key

	# Position player
	if entry_direction.is_empty():
		player.global_position = Vector2.ZERO  # First room: center
	else:
		var entry_pos = room.get_entry_position(entry_direction)
		player.global_position = entry_pos

	# Set camera limits
	_set_camera_limits()

	# Activate the room (locks doors, starts waves)
	room.activate_room(entry_direction)

	EventBus.room_entered.emit(data)


func _unload_current_room() -> void:
	if current_room:
		current_room.deactivate_room()
		current_room.queue_free()
		current_room = null
		current_room_key = ""


func _on_room_transition_requested(door: Node2D) -> void:
	if transition_in_progress or game_over:
		return

	var next_room = door.connected_room
	var entry_dir = door.connected_entry

	if next_room.is_empty():
		return

	transition_in_progress = true
	player.disable_input()

	# Fade out
	await _fade_to(1.0, 0.3)

	# Swap rooms
	_unload_current_room()
	_load_room(next_room, entry_dir)

	# Fade in
	await _fade_to(0.0, 0.3)

	player.enable_input()
	transition_in_progress = false

	EventBus.room_transition_completed.emit(current_room)


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


func _input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

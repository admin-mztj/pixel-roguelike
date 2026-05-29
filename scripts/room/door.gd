extends Node2D

## Door with LOCKED/UNLOCKED states.
## Locked on room entry, unlocked when all enemies cleared.

enum DoorState { LOCKED, UNLOCKED }
enum DoorDirection { NORTH, SOUTH, EAST, WEST }

@export var direction: int = 0  # DoorDirection
@export var connected_room: String = ""  # Room key for transition
@export var connected_entry: String = ""  # Entry side in next room ("North"/"South"/"East"/"West")

var current_state: int = DoorState.LOCKED

@onready var door_body: StaticBody2D = $DoorBody
@onready var door_trigger: Area2D = $DoorTrigger
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_set_state(DoorState.LOCKED)
	door_trigger.body_entered.connect(_on_player_entered)
	_create_placeholder_texture()


func _set_state(new_state: int) -> void:
	current_state = new_state
	match new_state:
		DoorState.LOCKED:
			door_body.collision_layer = 16
			door_trigger.monitoring = false
			sprite.modulate = Color.RED
		DoorState.UNLOCKED:
			door_body.collision_layer = 0
			door_trigger.monitoring = true
			sprite.modulate = Color.GREEN


func unlock() -> void:
	if current_state == DoorState.UNLOCKED:
		return
	_set_state(DoorState.UNLOCKED)
	EventBus.door_unlocked.emit(self)


func _on_player_entered(body: Node2D) -> void:
	if current_state != DoorState.UNLOCKED:
		return
	if body.is_in_group("player") and not connected_room.is_empty():
		EventBus.room_transition_requested.emit(self)


func _create_placeholder_texture() -> void:
	var img = Image.create(48, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.2, 0.2, 1))
	# Border
	for x in 48:
		img.set_pixel(x, 0, Color.WHITE)
		img.set_pixel(x, 31, Color.WHITE)
	for y in 32:
		img.set_pixel(0, y, Color.WHITE)
		img.set_pixel(47, y, Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)

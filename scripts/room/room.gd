extends Node2D

## Room controller: walls, doors, wave spawning, clear detection.

const ROOM_WIDTH = 960.0
const ROOM_HEIGHT = 540.0
const WALL_THICKNESS = 32.0
const DOOR_GAP = 48.0

@export var room_data: Resource

var current_wave: int = 0
var total_waves: int = 0
var enemies_alive: int = 0
var room_cleared: bool = false
var room_active: bool = false

@onready var walls_parent: Node2D = $Walls
@onready var doors_parent: Node2D = $Doors
@onready var enemies_parent: Node2D = $Enemies
@onready var spawn_points: Node2D = $SpawnPoints
@onready var entry_points: Node2D = $EntryPoints


func _ready() -> void:
	if room_data:
		total_waves = room_data.wave_enemy_counts.size()
		_create_walls()
		_configure_doors()


func activate_room(entry_direction: String) -> void:
	room_active = true
	EventBus.enemy_died.connect(_on_enemy_died)
	_lock_all_doors()
	if total_waves > 0:
		_start_next_wave()
	else:
		# No enemies — shop/sanctum rooms (future)
		_on_all_waves_complete()
	EventBus.room_entered.emit(room_data)


func deactivate_room() -> void:
	room_active = false
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)


func get_entry_position(direction: String) -> Vector2:
	var entry = entry_points.get_node_or_null("Entry" + direction) as Marker2D
	if entry:
		return entry.global_position
	return Vector2.ZERO


func _create_walls() -> void:
	var wall_color = room_data.wall_color if room_data else Color(0.25, 0.25, 0.3)
	var half_w = ROOM_WIDTH / 2.0
	var half_h = ROOM_HEIGHT / 2.0
	var half_t = WALL_THICKNESS / 2.0

	# Floor
	var floor = ColorRect.new()
	floor.name = "Floor"
	floor.size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
	floor.color = room_data.floor_color if room_data else Color(0.12, 0.12, 0.18)
	floor.position = -Vector2(ROOM_WIDTH, ROOM_HEIGHT) / 2.0
	walls_parent.add_child(floor)

	# Wall config: direction, center_y, wall_width, door_axis, door_offset
	var configs = [
		{ "side": "North", "pos": Vector2(0, -half_h + half_t), "size": Vector2(ROOM_WIDTH, WALL_THICKNESS), "has_door": _has_door("north") },
		{ "side": "South", "pos": Vector2(0, half_h - half_t), "size": Vector2(ROOM_WIDTH, WALL_THICKNESS), "has_door": _has_door("south") },
		{ "side": "West", "pos": Vector2(-half_w + half_t, 0), "size": Vector2(WALL_THICKNESS, ROOM_HEIGHT), "has_door": _has_door("west") },
		{ "side": "East", "pos": Vector2(half_w - half_t, 0), "size": Vector2(WALL_THICKNESS, ROOM_HEIGHT), "has_door": _has_door("east") },
	]

	for cfg in configs:
		if cfg["has_door"]:
			# Two wall segments with a gap
			var is_horizontal = cfg["size"].x > cfg["size"].y
			var total_length = cfg["size"].x if is_horizontal else cfg["size"].y
			var thickness = cfg["size"].y if is_horizontal else cfg["size"].x
			var seg_length = (total_length - DOOR_GAP) / 2.0
			var seg_center = seg_length / 2.0 + DOOR_GAP / 2.0

			if is_horizontal:
				_create_wall_segment(Vector2(-seg_center, cfg["pos"].y), Vector2(seg_length, thickness), wall_color)
				_create_wall_segment(Vector2(seg_center, cfg["pos"].y), Vector2(seg_length, thickness), wall_color)
			else:
				_create_wall_segment(Vector2(cfg["pos"].x, -seg_center), Vector2(thickness, seg_length), wall_color)
				_create_wall_segment(Vector2(cfg["pos"].x, seg_center), Vector2(thickness, seg_length), wall_color)
		else:
			# Continuous wall
			_create_wall_segment(cfg["pos"], cfg["size"], wall_color)


func _create_wall_segment(pos: Vector2, size: Vector2, color: Color) -> void:
	var wall = StaticBody2D.new()
	wall.collision_layer = 16
	wall.collision_mask = 0
	wall.position = pos

	var collision = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	collision.shape = rect
	wall.add_child(collision)

	var visual = ColorRect.new()
	visual.size = size
	visual.color = color
	visual.position = -size / 2.0
	wall.add_child(visual)

	walls_parent.add_child(wall)


func _configure_doors() -> void:
	var door_scene = load("res://scenes/room/door.tscn") as PackedScene
	var half_w = ROOM_WIDTH / 2.0
	var half_h = ROOM_HEIGHT / 2.0
	var half_t = WALL_THICKNESS / 2.0

	var door_configs = [
		{ "dir": "north", "pos": Vector2(0, -half_h + half_t), "rot": 0.0 },
		{ "dir": "south", "pos": Vector2(0, half_h - half_t), "rot": 0.0 },
		{ "dir": "west", "pos": Vector2(-half_w + half_t, 0), "rot": 90.0 },
		{ "dir": "east", "pos": Vector2(half_w - half_t, 0), "rot": 90.0 },
	]

	for cfg in door_configs:
		if _has_door(cfg["dir"]):
			var door = door_scene.instantiate()
			door.position = cfg["pos"]
			door.rotation_degrees = cfg["rot"]
			door.connected_room = _get_connected_room(cfg["dir"])
			door.connected_entry = _get_entry_direction(cfg["dir"])
			doors_parent.add_child(door)


func _has_door(side: String) -> bool:
	if not room_data:
		return false
	match side:
		"north": return room_data.north_door
		"south": return room_data.south_door
		"east": return room_data.east_door
		"west": return room_data.west_door
	return false


func _get_connected_room(side: String) -> String:
	if not room_data:
		return ""
	match side:
		"north": return room_data.north_room
		"south": return room_data.south_room
		"east": return room_data.east_room
		"west": return room_data.west_room
	return ""


func _get_entry_direction(side: String) -> String:
	# When exiting through a door, which side does the player enter the next room from?
	match side:
		"north": return "South"
		"south": return "North"
		"east": return "West"
		"west": return "East"
	return ""


func _lock_all_doors() -> void:
	# Doors start locked by default; no action needed here
	pass


func _unlock_all_doors() -> void:
	for child in doors_parent.get_children():
		if child.has_method("unlock"):
			child.unlock()


func _start_next_wave() -> void:
	if current_wave >= total_waves:
		_on_all_waves_complete()
		return

	var count = room_data.wave_enemy_counts[current_wave]
	var delay = room_data.wave_delays[current_wave] if current_wave < room_data.wave_delays.size() else 1.0
	var simultaneous = room_data.wave_simultaneous[current_wave] if current_wave < room_data.wave_simultaneous.size() else false

	EventBus.wave_started.emit(current_wave + 1, total_waves)

	# Wait for delay, then spawn
	await get_tree().create_timer(delay).timeout

	if not room_active:
		return

	if simultaneous:
		for i in range(count):
			_spawn_enemy()
	else:
		for i in range(count):
			if not room_active:
				return
			_spawn_enemy()
			await get_tree().create_timer(0.3).timeout

	current_wave += 1


func _spawn_enemy() -> void:
	var enemy_scene = load("res://scenes/enemies/enemy.tscn") as PackedScene
	var enemy = enemy_scene.instantiate()

	# Pick random stats from pool
	if room_data and room_data.enemy_pool.size() > 0:
		var stats = room_data.enemy_pool[randi() % room_data.enemy_pool.size()]
		enemy.set("stats", stats)

	# Random spawn position
	var pos = _get_random_spawn_position()
	enemy.global_position = pos

	enemies_parent.add_child(enemy)
	enemies_alive += 1


func _on_enemy_died(_enemy: Node2D) -> void:
	enemies_alive = max(0, enemies_alive - 1)
	GameState.total_enemies_killed += 1

	if not room_active:
		return

	# Check if wave is done
	if enemies_alive == 0:
		EventBus.wave_completed.emit(current_wave, total_waves)
		if current_wave >= total_waves:
			_on_all_waves_complete()
		else:
			await get_tree().create_timer(1.0).timeout
			if room_active:
				_start_next_wave()


func _on_all_waves_complete() -> void:
	room_cleared = true
	GameState.rooms_cleared += 1
	_unlock_all_doors()
	EventBus.room_cleared.emit(self)


func _get_random_spawn_position() -> Vector2:
	if spawn_points and spawn_points.get_child_count() > 0:
		var markers = spawn_points.get_children()
		var marker = markers[randi() % markers.size()] as Marker2D
		return marker.global_position

	# Fallback: random position within room
	var half_w = ROOM_WIDTH / 2.0 - WALL_THICKNESS - 32.0
	var half_h = ROOM_HEIGHT / 2.0 - WALL_THICKNESS - 32.0
	return Vector2(randf_range(-half_w, half_w), randf_range(-half_h, half_h))

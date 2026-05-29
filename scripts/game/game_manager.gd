extends Node2D

## Game manager: room setup, enemy spawning, wave management, game over.

# Room dimensions (matches viewport 960x540)
const ROOM_WIDTH := 960.0
const ROOM_HEIGHT := 540.0
const WALL_THICKNESS := 32.0

# Spawning
const INITIAL_ENEMY_COUNT := 3
const RESPAWN_DELAY := 2.0
const MAX_ENEMIES_ALIVE := 8

var enemies_alive: int = 0
var enemies_to_spawn: int = INITIAL_ENEMY_COUNT
var spawn_timer: float = 0.0
var game_over: bool = false

@onready var spawn_points: Node2D = $SpawnPoints
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var game_over_label: Label = $GameOverUI/Label
@onready var game_over_ui: Control = $GameOverUI

# Enemy stats pool for variety
var enemy_stats_pool: Array = []


func _ready() -> void:
	# Create room walls
	_create_walls()

	# Load enemy stat variants
	enemy_stats_pool = [
		load("res://resources/enemies/basic_enemy.tres"),
		load("res://resources/enemies/fast_enemy.tres"),
	]

	# Connect signals
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.game_over.connect(_on_game_over)

	# Setup camera limits via player's camera
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = player_spawn.global_position
		var player_camera := player.get_node("Camera2D") as Camera2D
		if player_camera:
			player_camera.limit_left = int(-ROOM_WIDTH / 2 + WALL_THICKNESS)
			player_camera.limit_right = int(ROOM_WIDTH / 2 - WALL_THICKNESS)
			player_camera.limit_top = int(-ROOM_HEIGHT / 2 + WALL_THICKNESS)
			player_camera.limit_bottom = int(ROOM_HEIGHT / 2 - WALL_THICKNESS)

	# Spawn initial enemies
	_spawn_initial_enemies()

	# Hide game over UI
	game_over_ui.visible = false


func _create_walls() -> void:
	var walls_parent := $Walls
	var wall_color := Color(0.25, 0.25, 0.3, 1)

	# Create four walls: top, bottom, left, right
	var wall_configs := [
		{ "name": "TopWall", "pos": Vector2(0, -ROOM_HEIGHT / 2 + WALL_THICKNESS / 2), "size": Vector2(ROOM_WIDTH, WALL_THICKNESS) },
		{ "name": "BottomWall", "pos": Vector2(0, ROOM_HEIGHT / 2 - WALL_THICKNESS / 2), "size": Vector2(ROOM_WIDTH, WALL_THICKNESS) },
		{ "name": "LeftWall", "pos": Vector2(-ROOM_WIDTH / 2 + WALL_THICKNESS / 2, 0), "size": Vector2(WALL_THICKNESS, ROOM_HEIGHT) },
		{ "name": "RightWall", "pos": Vector2(ROOM_WIDTH / 2 - WALL_THICKNESS / 2, 0), "size": Vector2(WALL_THICKNESS, ROOM_HEIGHT) },
	]

	for cfg in wall_configs:
		var wall := StaticBody2D.new()
		wall.name = cfg["name"]
		wall.collision_layer = 16  # Layer 5 = walls
		wall.collision_mask = 0

		var collision := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = cfg["size"]
		collision.shape = rect_shape
		wall.add_child(collision)

		# Visual
		var visual := ColorRect.new()
		visual.size = cfg["size"]
		visual.color = wall_color
		visual.position = -cfg["size"] / 2  # Center the rect
		wall.add_child(visual)

		wall.position = cfg["pos"]
		walls_parent.add_child(wall)

	# Floor background
	var floor := ColorRect.new()
	floor.name = "Floor"
	floor.size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
	floor.color = Color(0.12, 0.12, 0.18, 1)
	floor.position = -Vector2(ROOM_WIDTH, ROOM_HEIGHT) / 2
	walls_parent.add_child(floor)
	# Move floor to the back
	walls_parent.move_child(floor, 0)


func _process(delta: float) -> void:
	if game_over:
		return

	# Maintain minimum enemies alive
	if enemies_alive < INITIAL_ENEMY_COUNT and enemies_to_spawn <= 0:
		spawn_timer += delta
		if spawn_timer >= RESPAWN_DELAY:
			spawn_timer = 0.0
			enemies_to_spawn = INITIAL_ENEMY_COUNT
			_spawn_wave()


func _spawn_initial_enemies() -> void:
	for i in range(INITIAL_ENEMY_COUNT):
		var pos := _get_random_spawn_position()
		_spawn_enemy(pos)
	enemies_to_spawn = 0


func _spawn_wave() -> void:
	var count := mini(INITIAL_ENEMY_COUNT, MAX_ENEMIES_ALIVE - enemies_alive)
	for i in range(count):
		var pos := _get_random_spawn_position()
		_spawn_enemy(pos)
	enemies_to_spawn = 0


func _spawn_enemy(position: Vector2) -> void:
	var enemy_scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as Node

	# Randomly pick stats
	var stats = enemy_stats_pool[randi() % enemy_stats_pool.size()]
	enemy.set("stats", stats)
	enemy.global_position = position

	add_child(enemy)
	enemies_alive += 1


func _on_enemy_died(_enemy: Node2D) -> void:
	enemies_alive = max(0, enemies_alive - 1)


func _on_game_over() -> void:
	game_over = true
	game_over_ui.visible = true
	game_over_label.text = "GAME OVER\nPress R to restart"

	# Allow restart
	if not InputMap.has_action("restart"):
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R
		InputMap.add_action("restart")
		InputMap.action_add_event("restart", event)


func _input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _get_random_spawn_position() -> Vector2:
	# Get a random spawn point marker, or generate a random position
	if spawn_points and spawn_points.get_child_count() > 0:
		var markers := spawn_points.get_children()
		var marker := markers[randi() % markers.size()] as Marker2D
		return marker.global_position

	# Fallback: random position within room (away from center)
	var angle := randf() * TAU
	var distance := randf_range(150.0, 350.0)
	return Vector2(cos(angle), sin(angle)) * distance

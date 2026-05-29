extends Node

## Holds minimal shared mutable state for the current run.
## P1 scope: player health only.

var player_max_health: int = 100
var player_current_health: int = 100
var is_player_alive: bool = true

# P2: Room tracking
var current_room_name: String = ""
var rooms_cleared: int = 0
var total_enemies_killed: int = 0

# P3: Biome and map tracking
var current_biome_index: int = 0
var current_biome_name: String = ""
var rooms_cleared_in_biome: int = 0
var total_biomes: int = 4


func reset() -> void:
	player_current_health = player_max_health
	is_player_alive = true
	current_room_name = ""
	rooms_cleared = 0
	total_enemies_killed = 0
	current_biome_index = 0
	current_biome_name = ""
	rooms_cleared_in_biome = 0


func take_damage(amount: int) -> void:
	if not is_player_alive:
		return
	player_current_health = max(0, player_current_health - amount)
	EventBus.player_health_changed.emit(player_current_health, player_max_health)
	EventBus.player_damaged.emit(amount)
	if player_current_health == 0:
		is_player_alive = false
		EventBus.player_died.emit()
		EventBus.game_over.emit()

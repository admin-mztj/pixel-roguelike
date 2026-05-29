extends Node

## Global signal bus for decoupled communication.
## All cross-system events flow through this singleton.

signal enemy_died(enemy_node: Node2D)
signal enemy_hit(enemy_node: Node2D, damage_amount: int)
signal player_health_changed(current_health: int, max_health: int)
signal player_damaged(damage_amount: int)
signal player_died()
signal game_over()

# P2: Room system signals
signal room_entered(room_data: Resource)
signal room_cleared(room_node: Node2D)
signal room_transition_requested(door_node: Node2D)
signal room_transition_completed(room_node: Node2D)
signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int, total_waves: int)
signal door_unlocked(door_node: Node2D)

# P3: Map and biome signals
signal map_generated(map_graph: RefCounted)
signal room_selected_on_map(room_key: String)
signal biome_changed(biome_data: Resource)

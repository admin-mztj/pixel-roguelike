extends Node

## Global signal bus for decoupled communication.
## All cross-system events flow through this singleton.

signal enemy_died(enemy_node: Node2D)
signal enemy_hit(enemy_node: Node2D, damage_amount: int)
signal player_health_changed(current_health: int, max_health: int)
signal player_damaged(damage_amount: int)
signal player_died()
signal game_over()

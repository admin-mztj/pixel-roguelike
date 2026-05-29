class_name EnemyStats
extends Resource

## Data-driven enemy configuration.
## Create variants by duplicating .tres files and tweaking values.

@export var display_name: String = "Enemy"
@export var max_health: int = 30
@export var move_speed: float = 80.0
@export var contact_damage: int = 10
@export var experience_value: int = 5
@export var color: Color = Color.RED
@export var size: Vector2 = Vector2(30, 30)

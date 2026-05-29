class_name RoomData
extends Resource

## Data-driven room configuration.
## One .tres file per room — defines walls, doors, waves, and enemy pool.

enum RoomType { COMBAT, ELITE, SHOP, SANCTUM, REST, TREASURE, EVENT, BOSS }

@export var room_name: String = "Unnamed Room"
@export var room_type: int = 0  # RoomType enum

# Visual
@export var floor_color: Color = Color(0.12, 0.12, 0.18, 1)
@export var wall_color: Color = Color(0.25, 0.25, 0.30, 1)

# Doors (which sides have doors)
@export var north_door: bool = false
@export var south_door: bool = false
@export var east_door: bool = false
@export var west_door: bool = false

# Connected room keys (empty = no connection)
@export var north_room: String = ""
@export var south_room: String = ""
@export var east_room: String = ""
@export var west_room: String = ""

# Wave definitions (parallel arrays)
@export var wave_enemy_counts: Array[int] = [3, 3]
@export var wave_delays: Array[float] = [0.5, 2.0]
@export var wave_simultaneous: Array[bool] = [false, false]

# Enemy pool for random selection
@export var enemy_pool: Array[Resource] = []

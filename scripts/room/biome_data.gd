extends Resource

## Defines all properties of one biome/生态区.
## One .tres file per biome (forest, graveyard, lava, void).

@export var biome_name: String = "Unknown Biome"
@export var biome_index: int = 0
@export var description: String = ""

# Visual overrides
@export var floor_color: Color = Color(0.12, 0.12, 0.18)
@export var wall_color: Color = Color(0.25, 0.25, 0.30)
@export var map_tint: Color = Color.WHITE

# Room pools — paths to RoomData .tres files
@export var combat_rooms: Array[String] = []
@export var elite_rooms: Array[String] = []
@export var shop_rooms: Array[String] = []
@export var sanctum_rooms: Array[String] = []
@export var rest_rooms: Array[String] = []
@export var treasure_rooms: Array[String] = []
@export var event_rooms: Array[String] = []
@export var boss_room: String = ""

# Column generation
@export var min_rooms_per_col: int = 2
@export var max_rooms_per_col: int = 3

extends RefCounted

## One node in the generated room map graph.
## Each node represents a room in the biome.

var room_key: String = ""
var room_type: int = 0  # RoomData.RoomType
var biome_index: int = 0
var column: int = 0
var room_data_path: String = ""  # path to RoomData .tres

# Indices into MapGraph.flat_nodes
var next_node_indices: Array[int] = []
var prev_node_indices: Array[int] = []

# Temp references used during graph generation (cleared after flatten)
var _next_nodes_temp: Array = []
var _prev_nodes_temp: Array = []

# Runtime state
var is_completed: bool = false
var is_current: bool = false

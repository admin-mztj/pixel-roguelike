extends RefCounted

## Generated branching room graph for one biome.
## 5 columns: 0=start, 1-3=branch, 4=boss.

var biome_data: Resource = null
var columns: Array[Array] = []     # Array[5] of Array
var flat_nodes: Array = []  # All nodes, column-major order
var current_node_index: int = -1


func generate(p_biome_data: Resource, p_seed: int) -> void:
	biome_data = p_biome_data
	seed(p_seed)
	var rng = RandomNumberGenerator.new()
	rng.seed = p_seed

	columns.clear()
	flat_nodes.clear()

	# Column 0: start room (combat)
	var start_node = _create_node(rng, 0)
	start_node.room_type = 0  # COMBAT
	start_node.room_data_path = _pick_from_pool(rng, biome_data.combat_rooms)
	columns.append([start_node])

	# Columns 1-3: branch columns
	for col in range(1, 4):
		var count = rng.randi_range(biome_data.min_rooms_per_col, biome_data.max_rooms_per_col)
		var col_nodes: Array = []
		for i in range(count):
			var node = _create_node(rng, col)
			_assign_room_type(rng, node, col)
			col_nodes.append(node)
		columns.append(col_nodes)

	# Column 4: boss
	var boss_node = _create_node(rng, 4)
	boss_node.room_type = 7  # BOSS
	boss_node.room_data_path = biome_data.boss_room
	columns.append([boss_node])

	# Connect edges between adjacent columns
	for col in range(4):
		_connect_columns(rng, col, col + 1)

	# Flatten into flat_nodes and assign indices
	flat_nodes.clear()
	for col in range(5):
		for node in columns[col]:
			node.next_node_indices.clear()
			node.prev_node_indices.clear()

	for col in range(5):
		for node in columns[col]:
			flat_nodes.append(node)

	# Now that we have flat indices, populate the connections
	for col in range(5):
		for node in columns[col]:
			for raw_node in node._next_nodes_temp:
				var idx = flat_nodes.find(raw_node)
				if idx >= 0 and idx not in node.next_node_indices:
					node.next_node_indices.append(idx)
			for raw_node in node._prev_nodes_temp:
				var idx = flat_nodes.find(raw_node)
				if idx >= 0 and idx not in node.prev_node_indices:
					node.prev_node_indices.append(idx)


func _create_node(rng: RandomNumberGenerator, col: int) :
	var node = load("res://scripts/room/map_node.gd").new()
	node.column = col
	node.biome_index = biome_data.biome_index
	node.room_key = _generate_key(col, flat_nodes.size())
	# Temp arrays for edges (resolved to indices after flatten)
	node._next_nodes_temp = []
	node._prev_nodes_temp = []
	return node


func _assign_room_type(rng: RandomNumberGenerator, node: RefCounted, col: int) -> void:
	var roll = rng.randf()
	# Weight distribution varies by column depth
	var combat_wt: float
	var elite_wt: float

	match col:
		1: combat_wt = 0.60; elite_wt = 0.15
		2: combat_wt = 0.50; elite_wt = 0.15
		3: combat_wt = 0.40; elite_wt = 0.15

	if roll < combat_wt:
		node.room_type = 0  # COMBAT
		node.room_data_path = _pick_from_pool(rng, biome_data.combat_rooms)
	elif roll < combat_wt + elite_wt:
		node.room_type = 1  # ELITE
		node.room_data_path = _pick_from_pool(rng, biome_data.elite_rooms)
	elif roll < combat_wt + elite_wt + 0.10:
		node.room_type = 2  # SHOP
		node.room_data_path = _pick_from_pool(rng, biome_data.shop_rooms)
	elif roll < combat_wt + elite_wt + 0.18:
		node.room_type = 3  # SANCTUM
		node.room_data_path = _pick_from_pool(rng, biome_data.sanctum_rooms)
	elif roll < combat_wt + elite_wt + 0.25:
		node.room_type = 4  # REST
		node.room_data_path = _pick_from_pool(rng, biome_data.rest_rooms)
	elif roll < combat_wt + elite_wt + 0.33:
		node.room_type = 5  # TREASURE
		node.room_data_path = _pick_from_pool(rng, biome_data.treasure_rooms)
	else:
		node.room_type = 6  # EVENT
		node.room_data_path = _pick_from_pool(rng, biome_data.event_rooms)

	# Fallback to combat if pool is empty
	if node.room_data_path.is_empty():
		node.room_type = 0
		node.room_data_path = _pick_from_pool(rng, biome_data.combat_rooms)


func _connect_columns(rng: RandomNumberGenerator, from_col: int, to_col: int) -> void:
	var from_nodes = columns[from_col]
	var to_nodes = columns[to_col]

	# Each to_node must have at least 1 incoming edge
	for to_node in to_nodes:
		var src = from_nodes[rng.randi() % from_nodes.size()]
		to_node._prev_nodes_temp.append(src)
		src._next_nodes_temp.append(to_node)

	# Ensure each from_node has at least 1 outgoing edge
	for from_node in from_nodes:
		if from_node._next_nodes_temp.is_empty():
			var dst = to_nodes[rng.randi() % to_nodes.size()]
			from_node._next_nodes_temp.append(dst)
			if from_node not in dst._prev_nodes_temp:
				dst._prev_nodes_temp.append(from_node)

	# Optionally add second connections (20% chance per from_node)
	for from_node in from_nodes:
		if from_node._next_nodes_temp.size() == 1 and rng.randf() < 0.3:
			var candidates = to_nodes.duplicate()
			for existing in from_node._next_nodes_temp:
				candidates.erase(existing)
			if candidates.size() > 0:
				var extra = candidates[rng.randi() % candidates.size()]
				from_node._next_nodes_temp.append(extra)
				if from_node not in extra._prev_nodes_temp:
					extra._prev_nodes_temp.append(from_node)


func _pick_from_pool(rng: RandomNumberGenerator, pool: Array[String]) -> String:
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


func _generate_key(col: int, idx: int) -> String:
	return "%s_col%d_%d" % [biome_data.biome_name.to_lower().replace(" ", "_"), col, idx]


func get_next_nodes(node_index: int) -> Array:
	if node_index < 0 or node_index >= flat_nodes.size():
		return []
	var result: Array = []
	for idx in flat_nodes[node_index].next_node_indices:
		if idx >= 0 and idx < flat_nodes.size():
			result.append(flat_nodes[idx])
	return result


func get_node_by_key(room_key: String) :
	for node in flat_nodes:
		if node.room_key == room_key:
			return node
	return null

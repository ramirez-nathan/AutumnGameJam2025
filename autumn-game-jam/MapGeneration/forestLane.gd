# forestLane.gd
extends Node3D

const GRASS_TILE_SCENE: PackedScene = preload("res://AssetScenes/Tiles/Grass.tscn")
const TREE_SCENE: PackedScene = preload("res://AssetScenes/Obstacles/3Tree.tscn")  # adjust if your tree path is different

@export var numColumns: int = 30      # width of lane in tiles
@export var cellSize: float = 1.0
@export var groundHeight: float = 0.5   # not really used now, but fine to keep
@export var obstacleChance: float = 0.3 # chance per cell for a tree
@export var playableHalfWidth: int = 7  # should match Player.maxAbsGridX

var rng := RandomNumberGenerator.new()
var halfColumns: int = 0

var blockedColumns: Dictionary = {}    # xIndex -> true if blocked
var protectedColumns: Dictionary = {}  # xIndex -> true if should NEVER spawn obstacle
var obstacleNodes: Dictionary = {}     # xIndex -> Node3D for that obstacle


func _ready() -> void:
	rng.randomize()
	createRow()


func setProtectedColumns(columns: Array[int]) -> void:
	protectedColumns.clear()
	for x in columns:
		protectedColumns[int(x)] = true


func clearObstaclesAtColumns(columns: Array[int]) -> void:
	for x in columns:
		var key: int = int(x)
		if obstacleNodes.has(key):
			var node: Node3D = obstacleNodes[key]
			if is_instance_valid(node):
				node.queue_free()
			obstacleNodes.erase(key)
		if blockedColumns.has(key):
			blockedColumns.erase(key)


func createRow() -> void:
	halfColumns = numColumns / 2

	for col in range(numColumns):
		var xIndex: int = col - halfColumns
		createGroundCell(xIndex)

		# Don't spawn trees in protected columns (before/after ravine bridges)
		if not protectedColumns.has(xIndex) and rng.randf() < obstacleChance:
			createObstacleAt(xIndex)


func createGroundCell(xIndex: int) -> void:
	# Use your Grass tile scene instead of a generated cube
	var tile: Node3D = GRASS_TILE_SCENE.instantiate()

	# Position at the correct column; tweak Y if the mesh is too high/low
	tile.position = Vector3(float(xIndex) * cellSize, 0.0, 0.0)

	# OPTIONAL: if you want to visually darken tiles outside the playable band,
	# you can edit the Grass.tscn (e.g., two variants) or modify materials here,
	# but that depends on how the tile is set up.
	#
	# Example (ONLY if tile root is MeshInstance3D and you're okay overriding):
	# if tile is MeshInstance3D:
	#     var mat := tile.get_active_material(0)
	#     if mat != null:
	#         if abs(xIndex) > playableHalfWidth:
	#             mat.albedo_color = mat.albedo_color * 0.5

	add_child(tile)


func createObstacleAt(xIndex: int) -> void:
	# Use your tree scene as the obstacle model
	var tree: Node3D = TREE_SCENE.instantiate()

	# Place the tree on this tile; tweak Y if needed based on the model pivot
	tree.position = Vector3(float(xIndex) * cellSize, 0.0, 0.0)

	add_child(tree)

	blockedColumns[xIndex] = true
	obstacleNodes[xIndex] = tree


func isCellWalkable(xIndex: int) -> bool:
	if abs(xIndex) > halfColumns:
		return false

	if blockedColumns.has(xIndex):
		return false

	return true

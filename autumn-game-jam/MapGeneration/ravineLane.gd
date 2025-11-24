# ravineLane.gd
extends Node3D

const RAVINE_TILE_SCENE: PackedScene = preload("res://AssetScenes/Tiles/Ravine.tscn")
const BRIDGE_SCENE: PackedScene      = preload("res://AssetScenes/Tiles/Bridge.tscn")

@export var numColumns: int = 35
@export var cellSize: float = 1.0
@export var numPlatforms: int = 4
@export var playableHalfWidth: int = 10    # matches Player.maxAbsGridX

var rng := RandomNumberGenerator.new()
var halfColumns: int = 0
var walkableColumns: Dictionary = {}     # xIndex -> true if SAFE (bridge/platform)


func _ready() -> void:
	rng.randomize()
	createRow()


func createRow() -> void:
	halfColumns = numColumns / 2

	# 1. Create ravine ground tiles across the whole row
	for col in range(numColumns):
		var xIndex: int = col - halfColumns
		createGroundCell(xIndex)

	# 2. Pick random columns for bridges/platforms
	var columnIndices: Array[int] = []
	for col in range(numColumns):
		columnIndices.append(col - halfColumns)

	columnIndices.shuffle()

	var count: int = min(numPlatforms, columnIndices.size())
	for i in range(count):
		createPlatformAt(columnIndices[i])


func createGroundCell(xIndex: int) -> void:
	var tile: Node3D = RAVINE_TILE_SCENE.instantiate()

	# Position the ravine tile at the correct grid column.
	# Adjust Y if needed based on how your tile mesh is modeled.
	tile.position = Vector3(float(xIndex) * cellSize, 0.0, 0.0)

	# OPTIONAL: if you still want a visual band (center vs outside),
	# you can change a material parameter or child node here,
	# but that depends on how Ravine.tscn is set up.

	add_child(tile)


func createPlatformAt(xIndex: int) -> void:
	var bridge: Node3D = BRIDGE_SCENE.instantiate()

	# Place bridge at same grid column, same Z; tweak Y if needed
	bridge.position = Vector3(float(xIndex) * cellSize, 0.0, 0.0)
	add_child(bridge)

	# Mark this column as safe for gameplay (used by isCellWalkable/getSafeColumns)
	walkableColumns[xIndex] = true


func isCellWalkable(xIndex: int) -> bool:
	if abs(xIndex) > halfColumns:
		return false

	# Only bridge/platform columns are safe
	return walkableColumns.has(xIndex)


func getSafeColumns() -> Array[int]:
	var cols: Array[int] = []
	for x in walkableColumns.keys():
		cols.append(int(x))
	return cols

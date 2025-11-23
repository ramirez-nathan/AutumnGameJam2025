# ravineLane.gd
extends Node3D

@export var numColumns: int = 30
@export var cellSize: float = 1.0
@export var groundHeight: float = 0.5
@export var numPlatforms: int = 4
@export var playableHalfWidth: int = 7    # matches Player.maxAbsGridX

var rng := RandomNumberGenerator.new()
var halfColumns: int = 0
var walkableColumns: Dictionary = {}     # xIndex -> true if SAFE (green platform)


func _ready() -> void:
	rng.randomize()
	createRow()


func createRow() -> void:
	halfColumns = numColumns / 2

	# 1. Create black ground cells across the whole row (with band highlight)
	for col in range(numColumns):
		var xIndex: int = col - halfColumns
		createGroundCell(xIndex)

	# 2. Pick some unique columns to place green platforms on
	var columnIndices: Array[int] = []
	for col in range(numColumns):
		columnIndices.append(col - halfColumns)

	columnIndices.shuffle()

	var count: int = min(numPlatforms, columnIndices.size())
	for i in range(count):
		createPlatformAt(columnIndices[i])


func createGroundCell(xIndex: int) -> void:
	var cell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cellSize, groundHeight, cellSize)
	cell.mesh = box

	var mat := StandardMaterial3D.new()

	# Inside band = dark gray, outside = full black
	if abs(xIndex) <= playableHalfWidth:
		mat.albedo_color = Color(0.08, 0.08, 0.08)
	else:
		mat.albedo_color = Color(0.0, 0.0, 0.0)

	cell.set_surface_override_material(0, mat)

	cell.position = Vector3(float(xIndex) * cellSize, -groundHeight / 2.0, 0.0)
	add_child(cell)


func createPlatformAt(xIndex: int) -> void:
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()

	var platformHeight: float = cellSize * 0.8
	box.size = Vector3(cellSize * 0.6, platformHeight, cellSize * 0.6)
	block.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.8, 0.1)  # GREEN safe platform
	block.set_surface_override_material(0, mat)

	block.position = Vector3(float(xIndex) * cellSize, platformHeight / 2.0, 0.0)
	add_child(block)

	walkableColumns[xIndex] = true


func isCellWalkable(xIndex: int) -> bool:
	if abs(xIndex) > halfColumns:
		return false

	# Only green platforms are safe
	return walkableColumns.has(xIndex)


func getSafeColumns() -> Array[int]:
	var cols: Array[int] = []
	for x in walkableColumns.keys():
		cols.append(int(x))
	return cols

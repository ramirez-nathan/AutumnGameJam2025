# forestLane.gd
extends Node3D

@export var numColumns: int = 30      # width of lane in tiles
@export var cellSize: float = 1.0
@export var groundHeight: float = 0.5
@export var obstacleChance: float = 0.2   # chance per cell for a red block

var rng := RandomNumberGenerator.new()
var halfColumns: int = 0
var blockedColumns: Dictionary = {}      # xIndex -> true if blocked


func _ready() -> void:
	rng.randomize()
	createRow()


func createRow() -> void:
	halfColumns = numColumns / 2

	for col in range(numColumns):
		var xIndex: int = col - halfColumns   # e.g. -15..+14 for 30 columns
		createGroundCell(xIndex)

		if rng.randf() < obstacleChance:
			createObstacleAt(xIndex)


func createGroundCell(xIndex: int) -> void:
	var cell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cellSize, groundHeight, cellSize)
	cell.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.8, 0.1)  # GREEN grass
	cell.set_surface_override_material(0, mat)

	cell.position = Vector3(float(xIndex) * cellSize, -groundHeight / 2.0, 0.0)
	add_child(cell)


func createObstacleAt(xIndex: int) -> void:
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()

	var obstacleHeight: float = cellSize * 0.8
	box.size = Vector3(cellSize * 0.6, obstacleHeight, cellSize * 0.6)
	block.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0)  # RED
	block.set_surface_override_material(0, mat)

	block.position = Vector3(float(xIndex) * cellSize, obstacleHeight / 2.0, 0.0)
	add_child(block)

	blockedColumns[xIndex] = true


func isCellWalkable(xIndex: int) -> bool:
	if abs(xIndex) > halfColumns:
		return false

	if blockedColumns.has(xIndex):
		return false

	return true

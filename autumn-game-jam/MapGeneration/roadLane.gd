# roadLane.gd
extends Node3D

# --- CAR SCENES ---
const MINI_CAR_SCENE: PackedScene  = preload("res://AssetScenes/Obstacles/MiniCar.tscn")
const SEDAN_SCENE: PackedScene     = preload("res://AssetScenes/Obstacles/Sedan.tscn")
const TRUCK_SCENE: PackedScene     = preload("res://AssetScenes/Obstacles/Truck.tscn")
const PICKUP_SCENE: PackedScene    = preload("res://AssetScenes/Obstacles/Pickup.tscn")

# All car types we can spawn
var carScenes: Array[PackedScene] = [
	MINI_CAR_SCENE,
	SEDAN_SCENE,
	TRUCK_SCENE,
	PICKUP_SCENE,
]

# --- LANE SETTINGS ---
@export var numColumns: int = 30
@export var cellSize: float = 1.0
@export var groundHeight: float = 0.5
@export var playableHalfWidth: int = 7    # should match Player.maxAbsGridX

# --- CAR SPAWN SETTINGS ---
@export var minSpawnInterval: float = 1.0   # MIN seconds between spawns
@export var maxSpawnInterval: float = 2.0   # MAX seconds between spawns

# --- CAR SPEED SETTINGS (PER-LANE) ---
@export var minLaneSpeed: float = 3.0       # MIN lane speed
@export var maxLaneSpeed: float = 6.0       # MAX lane speed
var laneCarSpeed: float = 4.0               # actual speed chosen for THIS lane

# Vertical offset for cars if they float/sink slightly
@export var carYOffset: float = 0.0

var rng := RandomNumberGenerator.new()
var halfColumns: int = 0

# Kept for compatibility with world.gd / ravine rules
var protectedColumns: Dictionary = {}      # not really used now
var blockedColumns: Dictionary = {}        # no static blocks here

# Car data: each item is { "node": Node3D, "dir": float }
var activeCars: Array = []

# Spawn direction:
# true  = spawnLeft (left -> right)
# false = spawnRight (right -> left)
var spawnFromLeft: bool = true
var spawnTimer: float = 0.0
var nextSpawnTime: float = 1.0

# Bright colors to randomize car paint
var carColors: Array[Color] = [
	Color(1.0, 0.0, 0.0),    # red
	Color(0.0, 1.0, 0.0),    # green
	Color(0.0, 0.4, 1.0),    # blue
	Color(1.0, 1.0, 0.0),    # yellow
	Color(1.0, 0.5, 0.0),    # orange
	Color(0.8, 0.0, 0.8),    # purple
	Color(0.0, 1.0, 1.0),    # cyan
	Color(1.0, 0.0, 1.0),    # magenta
	Color(1.0, 0.8, 0.8),    # light pink
	Color(0.6, 0.8, 1.0),    # light blue
	Color(0.6, 1.0, 0.6),    # light green
	Color(1.0, 1.0, 1.0),    # white
	Color(0.5, 0.5, 0.5),    # gray
	Color(1.0, 0.9, 0.3),    # gold-ish
	Color(0.4, 0.0, 0.0),    # dark red
	Color(0.0, 0.0, 0.0)     # black
]


func _ready() -> void:
	rng.randomize()
	halfColumns = numColumns / 2

	_createRoadTiles()
	_chooseLaneDirection()
	_chooseLaneSpeed()
	_resetSpawnTimer()


func _process(delta: float) -> void:
	_updateCarSpawning(delta)
	_updateCars(delta)


# ----------------------
#  ROAD GROUND GEOMETRY
# ----------------------
func _createRoadTiles() -> void:
	for col in range(numColumns):
		var xIndex: int = col - halfColumns
		_createGroundCell(xIndex)


func _createGroundCell(xIndex: int) -> void:
	var cell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cellSize, groundHeight, cellSize)
	cell.mesh = box

	var mat := StandardMaterial3D.new()

	# Inside playable band = mid gray, outside = very dark gray
	if abs(xIndex) <= playableHalfWidth:
		mat.albedo_color = Color(0.4, 0.4, 0.4)   # main road
	else:
		mat.albedo_color = Color(0.1, 0.1, 0.1)   # dark shoulder / off-limits

	cell.set_surface_override_material(0, mat)

	cell.position = Vector3(float(xIndex) * cellSize, -groundHeight / 2.0, 0.0)
	add_child(cell)


# ----------------------
#  SPAWN DIRECTION & SPEED
# ----------------------
func _chooseLaneDirection() -> void:
	# Randomly choose whether this lane is spawnLeft or spawnRight
	spawnFromLeft = rng.randf() < 0.5
	# For testing, you can force one:
	# spawnFromLeft = true   # always left -> right
	# spawnFromLeft = false  # always right -> left


func _chooseLaneSpeed() -> void:
	# Each lane picks ONE speed in range; all its cars use that
	laneCarSpeed = rng.randf_range(minLaneSpeed, maxLaneSpeed)
	# Debug (optional):
	# print("RoadLane speed: ", laneCarSpeed, " dir: ", spawnFromLeft ? "L->R" : "R->L")


# ----------------------
#  CAR SPAWNING / MOVING
# ----------------------
func _resetSpawnTimer() -> void:
	nextSpawnTime = rng.randf_range(minSpawnInterval, maxSpawnInterval)
	spawnTimer = 0.0


func _updateCarSpawning(delta: float) -> void:
	spawnTimer += delta
	if spawnTimer >= nextSpawnTime:
		_spawnCar()
		_resetSpawnTimer()


func _spawnCar() -> void:
	if carScenes.is_empty():
		return

	# Randomly pick a car model
	var randomIndex: int = rng.randi_range(0, carScenes.size() - 1)
	var carScene: PackedScene = carScenes[randomIndex]
	var car: Node3D = carScene.instantiate()

	# Spawn position & direction
	var laneHalfWidthWorld: float = float(halfColumns) * cellSize
	var spawnX: float
	var directionSign: float

	if spawnFromLeft:
		# spawnLeft: from leftmost side, going right (+X)
		spawnX = -laneHalfWidthWorld - cellSize   # just off-screen
		directionSign = 1.0
	else:
		# spawnRight: from rightmost side, going left (-X)
		spawnX = laneHalfWidthWorld + cellSize
		directionSign = -1.0

	car.position = Vector3(spawnX, carYOffset, 0.0)

	# Face the direction of travel.
	# You said:
	# - cars moving left -> right should be rotated +90 degrees
	# - cars moving right -> left should be rotated -90 degrees
	#
	# Using radians:
	var yaw: float = deg_to_rad(90.0) if spawnFromLeft else deg_to_rad(-90.0)
	car.rotation.y = yaw

	# Give car a random bright color
	_applyRandomColorToCar(car)

	add_child(car)

	# Track this car (all cars use *laneCarSpeed* now)
	activeCars.append({
		"node": car,
		"dir": directionSign,
	})


func _updateCars(delta: float) -> void:
	var laneHalfWidthWorld: float = float(halfColumns) * cellSize
	var despawnLimit: float = laneHalfWidthWorld + (cellSize * 4.0)

	for i in range(activeCars.size() - 1, -1, -1):
		var carData = activeCars[i]
		var car: Node3D = carData["node"]

		if not is_instance_valid(car):
			activeCars.remove_at(i)
			continue

		var directionSign: float = carData["dir"]

		# Move along X axis using laneCarSpeed (same for whole lane)
		car.position.x += laneCarSpeed * directionSign * delta

		# Despawn if far off-screen
		if abs(car.position.x) > despawnLimit:
			car.queue_free()
			activeCars.remove_at(i)


# ----------------------
#  COLOR HELPERS
# ----------------------
func _applyRandomColorToCar(car: Node3D) -> void:
	if carColors.is_empty():
		return

	var colorIndex: int = rng.randi_range(0, carColors.size() - 1)
	var chosenColor: Color = carColors[colorIndex]

	_applyColorRecursive(car, chosenColor)


func _applyColorRecursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var meshInst: MeshInstance3D = node
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		meshInst.set_surface_override_material(0, mat)

	for child in node.get_children():
		_applyColorRecursive(child, color)


# ----------------------
#  PROTECTED COLUMNS API
# (for ravine bridge rules; basically no-ops now)
# ----------------------
func setProtectedColumns(columns: Array[int]) -> void:
	protectedColumns.clear()
	for x in columns:
		protectedColumns[int(x)] = true


func clearObstaclesAtColumns(columns: Array[int]) -> void:
	for x in columns:
		var key: int = int(x)
		if blockedColumns.has(key):
			blockedColumns.erase(key)


# ----------------------
#  WALKABILITY (for player grid movement)
# ----------------------
func isCellWalkable(xIndex: int) -> bool:
	# Road tiles are always walkable in the grid sense.
	# Getting hit by a car is handled by collision shapes
	# on the car scenes + the player.
	if abs(xIndex) > halfColumns:
		return false
	return true

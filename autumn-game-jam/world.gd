# world.gd
extends Node3D

@export var forestLaneScene: PackedScene
@export var roadLaneScene: PackedScene
@export var ravineLaneScene: PackedScene

@export var cellSize: float = 1.0             # must match lanes & player
@export var playableLanesAhead: int = 52      # player can walk this many lanes ahead of furthest
@export var playableLanesBehind: int = 3      # player can walk this many lanes behind furthest
@export var visibleExtraBehind: int = 8       # extra lanes we KEEP behind, but cannot walk on

@onready var player: Node3D = $Player

var laneMap: Dictionary = {}                  # laneIndex -> lane Node3D

@export var currentLaneIndex: int = 0
@export var furthestLaneTraveled: int = 0
@export var furthestLaneGenerated: int = -1

var rng := RandomNumberGenerator.new()

enum LaneType { FOREST, ROAD, RAVINE }
var lastLaneType: int = LaneType.FOREST


func _ready() -> void:
	rng.randomize()

	currentLaneIndex = roundi(player.position.z / cellSize)
	furthestLaneTraveled = currentLaneIndex

	ensureLanesAroundPlayer()


func _process(delta: float) -> void:
	var laneFromPos: int = roundi(player.position.z / cellSize)

	if laneFromPos != currentLaneIndex:
		currentLaneIndex = laneFromPos

		if currentLaneIndex > furthestLaneTraveled:
			furthestLaneTraveled = currentLaneIndex

	ensureLanesAroundPlayer()
	cleanupOldLanes()


func getPlayableMinMax() -> Vector2i:
	var minLane: int = furthestLaneTraveled - playableLanesBehind
	var maxLane: int = furthestLaneTraveled + playableLanesAhead
	return Vector2i(minLane, maxLane)


func getGeometryMinMax() -> Vector2i:
	var playable: Vector2i = getPlayableMinMax()
	var minLaneGeom: int = playable.x - visibleExtraBehind
	var maxLaneGeom: int = playable.y
	return Vector2i(minLaneGeom, maxLaneGeom)


func ensureLanesAroundPlayer() -> void:
	var geom: Vector2i = getGeometryMinMax()
	var minLaneGeom: int = geom.x
	var maxLaneGeom: int = geom.y

	for laneIndex in range(minLaneGeom, maxLaneGeom + 1):
		if not laneMap.has(laneIndex):
			spawnLane(laneIndex)

	if maxLaneGeom > furthestLaneGenerated:
		furthestLaneGenerated = maxLaneGeom


func chooseLaneType(laneIndex: int) -> int:
	# Early game: always forest so it's safe
	if laneIndex < 4:
		lastLaneType = LaneType.FOREST
		return LaneType.FOREST

	# Base random weights:
	# ~50% forest, 35% road, 15% ravine
	var r: float = rng.randf()
	var candidate: int

	if r < 0.5:
		candidate = LaneType.FOREST
	elif r < 0.85:
		candidate = LaneType.ROAD
	else:
		candidate = LaneType.RAVINE

	# Ravine only 1 lane wide FOR NOW:
	if lastLaneType == LaneType.RAVINE and candidate == LaneType.RAVINE:
		candidate = LaneType.FOREST if rng.randf() < 0.5 else LaneType.ROAD

	lastLaneType = candidate
	return candidate


func spawnLane(laneIndex: int) -> void:
	var laneType: int = chooseLaneType(laneIndex)
	var scene: PackedScene

	match laneType:
		LaneType.FOREST:
			scene = forestLaneScene
		LaneType.ROAD:
			scene = roadLaneScene
		LaneType.RAVINE:
			scene = ravineLaneScene
		_:
			scene = forestLaneScene

	var lane: Node3D = scene.instantiate()

	# 1) Handle "AFTER ravine": if previous lane is ravine, protect its platform columns
	var prevIndex: int = laneIndex - 1
	if laneMap.has(prevIndex):
		var prevLane: Node = laneMap[prevIndex]
		if prevLane.has_method("getSafeColumns") and lane.has_method("setProtectedColumns"):
			var safeColsRaw: Array = prevLane.getSafeColumns()
			var safeCols: Array[int] = []
			for c in safeColsRaw:
				safeCols.append(int(c))
			lane.setProtectedColumns(safeCols)
	# (lane _ready hasn't fired yet; this affects obstacle spawning)

	add_child(lane)

	lane.position = Vector3(0.0, 0.0, float(laneIndex) * cellSize)
	lane.set_meta("laneIndex", laneIndex)
	laneMap[laneIndex] = lane

	# 2) Handle "BEFORE ravine": if THIS lane is a ravine, clear obstacles in the lane before it
	if lane.has_method("getSafeColumns") and laneMap.has(prevIndex):
		var safeCols2: Array[int] = lane.getSafeColumns()
		var prevLane2: Node = laneMap[prevIndex]
		if prevLane2.has_method("clearObstaclesAtColumns"):
			prevLane2.clearObstaclesAtColumns(safeCols2)


func cleanupOldLanes() -> void:
	var geom: Vector2i = getGeometryMinMax()
	var minLaneGeom: int = geom.x
	var maxLaneGeom: int = geom.y

	for laneIndex in laneMap.keys():
		if laneIndex < minLaneGeom or laneIndex > maxLaneGeom:
			var laneNode: Node = laneMap[laneIndex]
			if is_instance_valid(laneNode):
				laneNode.queue_free()
			laneMap.erase(laneIndex)


func isLaneWithinBounds(laneIndex: int) -> bool:
	var playable: Vector2i = getPlayableMinMax()
	var minLane: int = playable.x
	var maxLane: int = playable.y
	return laneIndex >= minLane and laneIndex <= maxLane


func isCellWalkable(gridX: int, gridZ: int) -> bool:
	if not isLaneWithinBounds(gridZ):
		return false

	if not laneMap.has(gridZ):
		return false

	var lane: Node = laneMap[gridZ]
	if lane.has_method("isCellWalkable"):
		return lane.isCellWalkable(gridX)

	return true

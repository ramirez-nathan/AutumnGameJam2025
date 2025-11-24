# cameraController.gd
extends Camera3D

@export var player: Node3D          # drag your Player node here in the inspector
@export var forwardSpeed: float = 0.75   # how fast the camera moves in +Z (units/sec)
@export var followSpeed: float = 6.0    # how quickly camera follows player in X/Y
@export var xOffset: float = -2.0        # horizontal offset from player
@export var yOffset: float = 8.0        # height above player
@export var zOffset: float = -3.0       
@export var zStartOffset: float = -10.0 # START offset behind the player on Z

var currentZ: float


func _ready() -> void:
	if player:
		# Start the camera at a position relative to the player
		var p: Vector3 = player.global_position
		currentZ = p.z + zStartOffset
		global_position = Vector3(
			p.x + xOffset,
			p.y + yOffset,
			currentZ
		)
	else:
		# Fallback: just remember our initial Z
		currentZ = global_position.z


func _physics_process(delta: float) -> void:
	if not player:
		return

	var pos: Vector3 = global_position

	
	
	# 2. Smoothly follow player's X and Y (left/right & height)
	var targetX: float = player.global_position.x + xOffset
	pos.x = move_toward(pos.x, targetX, followSpeed * delta)
	
	var CameraDistanceFromPlayerZ = abs(global_position.z - player.global_position.z)
	
	if (CameraDistanceFromPlayerZ > 5.0): 
		var targetZ: float = player.global_position.z + zOffset
		pos.z = move_toward(pos.z, targetZ, followSpeed * delta)
	else:
		# 1. Camera always moves forward in +Z at constant speed
		pos.z += forwardSpeed * delta
	

	global_position = pos
	# (We keep the camera's rotation as set in the editor so it keeps looking down)

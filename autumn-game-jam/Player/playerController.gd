# playerController.gd
extends CharacterBody3D

enum Form { DUCK, KANGAROO, HAWK, CAPYBARA }

# movement tuning
const TILE_SIZE := 1.0

@export var cellSize: float = 1.0      # should match World + lanes (keep at 1.0)
@export var maxAbsGridX: int = 10      # player can move from -10..+10

# grid state (logical tile position)
var gridX: int = 0
var gridZ: int = 0

# form state trackers
var current_form: Form = Form.DUCK
var previous_form: Form = Form.DUCK

# input lock
var input_locked := false
var input_lock_time := 0.01  # tuneable, 10ms feels good

var form_stats := {
	Form.DUCK: {
		"move_speed": 6.0,
		"can_move_freely": true,
		"jump_distance": 1,
	},
	Form.KANGAROO: {
		"move_speed": 4.0,
		"can_move_freely": false,
		"jump_distance": 2, # gaps
	},
	Form.HAWK: {
		"move_speed": 10.0,
		"can_move_freely": false,
	},
	Form.CAPYBARA: {
		"move_speed": 1.0,
		"can_move_freely": true,
	}
}

# global movement variables
var input_dir := Vector3.ZERO
var target_position := Vector3.ZERO
var is_moving := false

# kangaroo specific states
var is_jumping := false
var jump_timer := 0.0
var jump_duration := 0.25
var _jump_start_pos := Vector3.ZERO
var _jump_peak_height := 1.0
var _jump_target_grid_x: int = 0
var _jump_target_grid_z: int = 0

# hawk specific states
var is_hawk_powered := false
var hawk_timer := 0.0
var max_hawk_time := 3.0
var _hawk_start_pos := Vector3.ZERO

# forms that can be cycled through (hawk is excluded)
var cycle_forms := [Form.DUCK, Form.KANGAROO, Form.CAPYBARA]


func _ready() -> void:
	# Snap to grid at start
	gridX = roundi(global_position.x / cellSize)
	gridZ = roundi(global_position.z / cellSize)
	global_position = Vector3(gridX * cellSize, global_position.y, gridZ * cellSize)
	target_position = global_position


# main phys loop
func _physics_process(delta: float) -> void:
	# Hawk power overrides all input & movement
	if is_hawk_powered:
		_handle_hawk_power(delta)
		return

	_handle_input()
	_handle_movement(delta)


# input handler
func _handle_input():
	if is_moving or is_jumping or input_locked:
		return

	var dir := Vector3.ZERO

	# Use just_pressed and an elif chain so we only move 1 tile in 1 direction per tap
	if Input.is_action_just_pressed("move_forward"):
		dir.z += 1
	elif Input.is_action_just_pressed("move_back"):
		dir.z -= 1
	elif Input.is_action_just_pressed("move_left"):
		dir.x += 1
	elif Input.is_action_just_pressed("move_right"):
		dir.x -= 1

	if dir != Vector3.ZERO:
		_attempt_move(dir)

	# cycle forward
	if Input.is_action_just_pressed("shift_form"):
		cycle_form_forward()

	# arrow key cycling
	if Input.is_action_just_pressed("cycle_right"):
		cycle_form_forward()

	if Input.is_action_just_pressed("cycle_left"):
		cycle_form_backward()


# central move validation: band, lanes, collision
func _can_move_to(targetGridX: int, targetGridZ: int) -> bool:
	# 0) horizontal band limit (-maxAbsGridX .. +maxAbsGridX)
	if abs(targetGridX) > maxAbsGridX:
		return false

	var worldNode: Node = get_parent()

	# 1) lane window / back-forward limits
	if worldNode != null and worldNode.has_method("isLaneWithinBounds"):
		if not worldNode.isLaneWithinBounds(targetGridZ):
			return false

	# 2) tile walkability (no trees, no road blocks, must be on platform, etc.)
	if worldNode != null and worldNode.has_method("isCellWalkable"):
		if not worldNode.isCellWalkable(targetGridX, targetGridZ):
			return false

	return true


# NEW: rotate character to face the given grid direction
func _face_direction(dx: int, dz: int) -> void:
	var dir_vec := Vector3(dx, 0, dz)
	if dir_vec == Vector3.ZERO:
		return

	dir_vec = dir_vec.normalized()
	# y-rotation in Godot is atan2(x, z)
	var yaw := atan2(dir_vec.x, dir_vec.z)
	rotation.y = yaw


func _attempt_move(dir: Vector3) -> void:
	var stats = form_stats[current_form]

	# convert direction vector to grid deltas (-1/0/1)
	var dx: int = int(dir.x)
	var dz: int = int(dir.z)

	# KANGAROO: jumping multiple tiles
	if current_form == Form.KANGAROO:
		var jump_dist: int = stats["jump_distance"]
		_start_kangaroo_jump(dx, dz, jump_dist)
		return

	# Basic 1-tile step for duck/capybara
	var newGridX: int = gridX + dx
	var newGridZ: int = gridZ + dz

	if not _can_move_to(newGridX, newGridZ):
		return

	# Face the direction we are about to move
	_face_direction(dx, dz)

	gridX = newGridX
	gridZ = newGridZ

	target_position = Vector3(
		gridX * cellSize,
		global_position.y,
		gridZ * cellSize
	)

	is_moving = true


func _handle_movement(delta):
	# kangaroo jump update
	if current_form == Form.KANGAROO and is_jumping:
		_update_kangaroo_jump(delta)
		return

	if is_moving:
		var speed: float = form_stats[current_form]["move_speed"]
		global_position = global_position.move_toward(target_position, speed * delta)

		if global_position.distance_to(target_position) < 0.01:
			global_position = target_position
			is_moving = false
			_lock_input_for(input_lock_time)


# form change helpers
func _set_form(new_form: Form):
	if current_form == new_form:
		return

	current_form = new_form
	print("Shifted to: ", Form.keys()[new_form])


func cycle_form_forward():
	if is_hawk_powered:
		return  # can't swap during hawk mode

	var idx = cycle_forms.find(current_form)
	if idx == -1:
		return

	var next_idx = (idx + 1) % cycle_forms.size()
	_set_form(cycle_forms[next_idx])


func cycle_form_backward():
	if is_hawk_powered:
		return

	var idx = cycle_forms.find(current_form)
	if idx == -1:
		return

	var prev_idx = (idx - 1 + cycle_forms.size()) % cycle_forms.size()
	_set_form(cycle_forms[prev_idx])


# kangaroo jump
func _start_kangaroo_jump(dx: int, dz: int, dist: int):
	var targetGridX: int = gridX + dx * dist
	var targetGridZ: int = gridZ + dz * dist

	# check landing tile with same rules (band, lane, collision)
	if not _can_move_to(targetGridX, targetGridZ):
		return

	# Face the jump direction
	_face_direction(dx, dz)

	is_jumping = true
	jump_timer = 0.0

	_jump_start_pos = global_position
	_jump_peak_height = 1.0

	_jump_target_grid_x = targetGridX
	_jump_target_grid_z = targetGridZ

	target_position = Vector3(
		targetGridX * cellSize,
		global_position.y,
		targetGridZ * cellSize
	)


func _update_kangaroo_jump(delta):
	jump_timer += delta
	var t: float = jump_timer / jump_duration

	if t >= 1.0:
		global_position = target_position
		gridX = _jump_target_grid_x
		gridZ = _jump_target_grid_z
		is_jumping = false
		_lock_input_for(input_lock_time)
		return

	# Parabolic arc
	var horizontal := _jump_start_pos.lerp(target_position, t)
	var vertical := sin(t * PI) * _jump_peak_height

	global_position = Vector3(horizontal.x, vertical, horizontal.z)


func _lock_input_for(time: float):
	input_locked = true
	await get_tree().create_timer(time).timeout
	input_locked = false


# hawk mode
func activate_hawk_power():
	if is_hawk_powered:
		return

	previous_form = current_form
	_set_form(Form.HAWK)

	is_hawk_powered = true
	hawk_timer = 0.0
	_hawk_start_pos = global_position

	# OPTIONAL: face the hawk's forward direction (0,0,-1)
	_face_direction(0, -1)

	print("Hawk mode activated!")


func _handle_hawk_power(delta):
	# NOTE: z direction here may be "backwards" vs your other movement.
	# Keep or flip depending on what looks right in your camera.
	var forward = Vector3(0, 0, -1)
	var speed: float = form_stats[Form.HAWK]["move_speed"]

	global_position += forward * speed * delta
	hawk_timer += delta

	# condition 1: Time expired
	if hawk_timer >= max_hawk_time:
		_end_hawk_mode()
		return

	# condition 2: Land on safe tile (using grid + world, not raycast)
	if _is_on_safe_tile():
		_end_hawk_mode()
		return


func _end_hawk_mode():
	print("Landing from hawk mode")

	is_hawk_powered = false

	# snap to grid for clean placement
	gridX = roundi(global_position.x / cellSize)
	gridZ = roundi(global_position.z / cellSize)

	global_position = Vector3(
		gridX * cellSize,
		global_position.y,
		gridZ * cellSize
	)

	# return to previous form
	_set_form(previous_form)


func _is_on_safe_tile() -> bool:
	var worldNode: Node = get_parent()
	if worldNode == null:
		return false

	var gx: int = roundi(global_position.x / cellSize)
	var gz: int = roundi(global_position.z / cellSize)

	# respect lane bounds too
	if worldNode.has_method("isLaneWithinBounds"):
		if not worldNode.isLaneWithinBounds(gz):
			return false

	if worldNode.has_method("isCellWalkable"):
		return worldNode.isCellWalkable(gx, gz)

	return false

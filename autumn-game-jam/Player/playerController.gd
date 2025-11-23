extends CharacterBody3D

enum Form { DUCK, KANGAROO, HAWK, CAPYBARA }

# movement tuning
const TILE_SIZE := 1.0

# form state trackers
var current_form: Form = Form.DUCK
var previous_form: Form = Form.DUCK

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

# hawk specific states
var is_hawk_powered := false
var hawk_timer := 0.0
var max_hawk_time := 3.0
var _hawk_start_pos := Vector3.ZERO

# forms that can be cycled through (hawk is excluded)
var cycle_forms := [Form.DUCK, Form.KANGAROO, Form.CAPYBARA]

func _ready() -> void:
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
	if is_moving:
		return
		
	var dir := Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		dir.z -= 1
	if Input.is_action_pressed("move_back"):
		dir.z += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	
	if dir != Vector3.ZERO:
		input_dir = dir.normalized()
		_attempt_move()
		
	# cycle forward
	if Input.is_action_just_pressed("shift_form"):
		cycle_form_forward()

	# arrow key cycling
	if Input.is_action_just_pressed("cycle_right"):
		cycle_form_forward()

	if Input.is_action_just_pressed("cycle_left"):
		cycle_form_backward()

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

	
func _attempt_move():
	var stats = form_stats[current_form]
	
	if current_form == Form.KANGAROO:
		_start_kangaroo_jump(input_dir, stats["jump_distance"])
		return
		
	# basic step
	var step = input_dir * TILE_SIZE
	target_position = global_position + step
	is_moving = true

func _handle_movement(delta):
	# kangaroon jump update
	if current_form == Form.KANGAROO and is_jumping:
		_update_kangaroo_jump(delta)
		return
		
	if is_moving:
		var speed = form_stats[current_form]["move_speed"]
		global_position = global_position.move_toward(target_position, speed * delta)

		if global_position.distance_to(target_position) < 0.01:
			global_position = target_position
			is_moving = false
			
# kangaroo jump
func _start_kangaroo_jump(dir: Vector3, dist: int):
	is_jumping = true
	jump_timer = 0.0

	target_position = global_position + (dir * TILE_SIZE * dist)
	_jump_start_pos = global_position
	_jump_peak_height = 1.0

func _update_kangaroo_jump(delta):
	jump_timer += delta
	var t = jump_timer / jump_duration

	if t >= 1.0:
		global_position = target_position
		is_jumping = false
		return

	# Parabolic arc
	var horizontal := _jump_start_pos.lerp(target_position, t)
	var vertical := sin(t * PI) * _jump_peak_height

	global_position = Vector3(horizontal.x, vertical, horizontal.z)

# hawk mode
func activate_hawk_power():
	if is_hawk_powered:
		return

	previous_form = current_form
	_set_form(Form.HAWK)

	is_hawk_powered = true
	hawk_timer = 0.0
	_hawk_start_pos = global_position

	print("Hawk mode activated!")

func _handle_hawk_power(delta):
	var forward = Vector3(0, 0, -1)
	var speed = form_stats[Form.HAWK]["move_speed"]

	global_position += forward * speed * delta

	hawk_timer += delta

	# condition 1: Time expired
	if hawk_timer >= max_hawk_time:
		_end_hawk_mode()
		return

	# condition 2: Land on safe tile
	if _is_on_safe_tile():
		_end_hawk_mode()
		return

func _end_hawk_mode():
	print("Landing from hawk mode")

	is_hawk_powered = false

	# snap to grid for clean placement
	global_position = Vector3(
		round(global_position.x),
		global_position.y,
		round(global_position.z)
	)

	# return to previous form
	_set_form(previous_form)
	
func _is_on_safe_tile() -> bool:
	# raycast downward
	var space = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 2, 0)
	var to = global_position + Vector3(0, -5, 0)

	var hit = space.raycast(from, to)

	if hit and hit.collider and hit.collider.has_meta("safe_tile"):
		return true

	return false

extends Area3D

@export var auto_destroy := true
@export var rotate_speed := 60.0 # degrees/sec

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	
func _process(delta):
	# simple float/rotate effect
	rotation.y += deg_to_rad(rotate_speed) * delta
	position.y = 0.5 + sin(Time.get_ticks_msec() * 0.002) * 0.1
	
func _on_body_entered(body):
	if not body is CharacterBody3D:
		return

	# Check if the body has hawk activation function
	if body.has_method("activate_hawk_power"):
		body.activate_hawk_power()

		# Optional: Play animation / particles before deleting
		if auto_destroy:
			queue_free()

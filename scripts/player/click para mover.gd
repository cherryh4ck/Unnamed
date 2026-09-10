extends CharacterBody3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var speed: float = 700.0


func _ready() -> void:
	print("jugador listo")
	pass


func _physics_process(_delta: float) -> void:
	print("finished? ", nav_agent.is_navigation_finished())
	if nav_agent.is_navigation_finished():
		return

	move_to_point(speed)


func move_to_point(move_speed: float) -> void:
	var target_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(target_pos)
	print("moviendo hacia: ", target_pos, " direccion: ", direction)

	velocity = direction * move_speed
	move_and_slide()


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("leftMouse"):
		print("click detectado")
		var camera = get_viewport().get_camera_3d()
		print("camara: ", camera)

		var mouse_pos = get_viewport().get_mouse_position()
		var ray_length = 5000
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * ray_length
		var space = get_world_3d().direct_space_state
		var ray_query = PhysicsRayQueryParameters3D.new()
		ray_query.from = from
		ray_query.to = to
		var result = space.intersect_ray(ray_query)
		print("resultado raycast: ", result)

		if result.is_empty():
			print("el rayo no pego en nada")
			return

		nav_agent.target_position = result.position
		print("target seteado: ", nav_agent.target_position)
	

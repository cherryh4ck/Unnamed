extends CharacterBody3D

@export var ClickReference: NodePath = NodePath("../ClickReference")
@onready var click_reference: Node3D = get_node_or_null(ClickReference)
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var speed: float = 700.0

func _ready() -> void:
	click_reference.hide()
	print("Jugador listo")
	pass


func _physics_process(_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		click_reference.hide()
		return

	move_to_point(speed)


func move_to_point(move_speed: float) -> void:
	var target_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(target_pos)

	velocity = direction * move_speed
	move_and_slide()


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("leftMouse"):
		var camera = get_viewport().get_camera_3d()

		var mouse_pos = get_viewport().get_mouse_position()
		var ray_length = 5000
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * ray_length
		var space = get_world_3d().direct_space_state
		var ray_query = PhysicsRayQueryParameters3D.new()
		ray_query.from = from
		ray_query.to = to
		ray_query.exclude = [self.get_rid()]
		var result = space.intersect_ray(ray_query)

		if result.is_empty():
			return

		if click_reference:
			click_reference.global_position = result.position
			click_reference.show()
		nav_agent.target_position = result.position
	

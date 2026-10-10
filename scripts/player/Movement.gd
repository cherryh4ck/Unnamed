extends CharacterBody3D

@export var ClickReference: NodePath = NodePath("../ClickReference")
@onready var click_reference: Node3D = get_node_or_null(ClickReference)
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var speed: float = 700.0

var sonidos_pasos: Array[AudioStream] = []
var reproductor_pasos: AudioStreamPlayer3D
var intervalo_pasos: float = 0.4
var tiempo_paso: float = 0.4
var ultimo_paso: int = -1

func _ready() -> void:
	click_reference.hide()

	for i in range(1, 8):
		var ruta = "res://sounds/ambient/footsteps/footstep%d.wav" % i
		if ResourceLoader.exists(ruta):
			sonidos_pasos.append(load(ruta))

	reproductor_pasos = AudioStreamPlayer3D.new()
	reproductor_pasos.volume_db = 12.0
	add_child(reproductor_pasos)

	print("Jugador listo")
	pass


func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		click_reference.hide()
		tiempo_paso = intervalo_pasos
		return

	move_to_point(speed)

	tiempo_paso += delta
	if tiempo_paso >= intervalo_pasos:
		tiempo_paso = 0.0
		reproducir_paso()


func reproducir_paso() -> void:
	if sonidos_pasos.is_empty():
		return

	var indice = randi() % sonidos_pasos.size()
	if sonidos_pasos.size() > 1 and indice == ultimo_paso:
		indice = (indice + 1) % sonidos_pasos.size()
	ultimo_paso = indice

	reproductor_pasos.stream = sonidos_pasos[indice]
	reproductor_pasos.play()


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

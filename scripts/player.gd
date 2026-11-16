extends CharacterBody3D

const SPEED := 5.2
const JUMP_VELOCITY := 5.5
const GRAVITY := 18.0

var mobile_actions: Dictionary = {}
var camera_node: Camera3D

func _ready() -> void:
    camera_node = get_node_or_null("Camera3D")

func set_mobile_action(action: String, pressed: bool) -> void:
    mobile_actions[action] = pressed

func rotate_camera(amount: float) -> void:
    if camera_node:
        camera_node.rotation.x = clampf(camera_node.rotation.x + amount, deg_to_rad(-85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
    if camera_node == null:
        camera_node = get_node_or_null("Camera3D")
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    if (Input.is_action_just_pressed("jump") or mobile_actions.get("jump", false)) and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var input_vector := Vector2.ZERO
    input_vector.y -= float(Input.is_action_pressed("move_forward") or mobile_actions.get("move_forward", false))
    input_vector.y += float(Input.is_action_pressed("move_back") or mobile_actions.get("move_back", false))
    input_vector.x -= float(Input.is_action_pressed("move_left") or mobile_actions.get("move_left", false))
    input_vector.x += float(Input.is_action_pressed("move_right") or mobile_actions.get("move_right", false))
    input_vector = input_vector.normalized()

    var direction := (global_transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
    if direction.length() > 0.001:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED * 8 * delta)
        velocity.z = move_toward(velocity.z, 0, SPEED * 8 * delta)
    move_and_slide()

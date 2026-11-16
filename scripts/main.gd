extends Node3D

const BLOCK_SIZE := 1.0
const WORLD_RADIUS := 10
const REACH := 6.0

var blocks: Dictionary = {}
var block_materials: Array[StandardMaterial3D] = []
var player: CharacterBody3D
var camera: Camera3D
var status_label: Label
var selected_block := 0
var touch_look_id := -1
var last_touch_position := Vector2.ZERO
var look_sensitivity := 0.004

const BLOCK_NAMES := ["Grass", "Dirt", "Stone", "Wood"]
const BLOCK_COLORS := [
    Color(0.25, 0.68, 0.25),
    Color(0.45, 0.29, 0.16),
    Color(0.48, 0.50, 0.53),
    Color(0.48, 0.30, 0.14)
]

func _ready() -> void:
    _make_materials()
    _make_world()
    _make_player()
    _make_environment()
    _make_mobile_ui()

func _make_materials() -> void:
    for color in BLOCK_COLORS:
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 1.0
        block_materials.append(material)

func _make_environment() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.78, 0.88)
    env.ambient_light_energy = 0.8
    world_env.environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_energy = 1.1
    add_child(sun)

func _make_world() -> void:
    # Flat starter island with a small raised patch; all blocks are editable.
    for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
        for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
            _add_block(Vector3i(x, 0, z), 0)
            _add_block(Vector3i(x, -1, z), 1)
            if (x * 7 + z * 11) % 29 == 0:
                _add_block(Vector3i(x, 1, z), 1)
    # A few simple trees made from the same editable blocks.
    _make_tree(Vector3i(-4, 1, -3))
    _make_tree(Vector3i(5, 1, 4))

func _make_tree(origin: Vector3i) -> void:
    for y in range(3):
        _add_block(origin + Vector3i(0, y, 0), 3)
    for x in range(-2, 3):
        for z in range(-2, 3):
            for y in range(2, 4):
                if abs(x) + abs(z) < 4:
                    _add_block(origin + Vector3i(x, y, z), 0)

func _add_block(cell: Vector3i, material_index: int) -> void:
    if blocks.has(cell):
        return
    var body := StaticBody3D.new()
    body.position = Vector3(cell) + Vector3.ONE * 0.5
    body.set_meta("cell", cell)
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    mesh_instance.mesh = mesh
    mesh_instance.material_override = block_materials[material_index]
    body.add_child(mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3.ONE
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    blocks[cell] = {"node": body, "type": material_index}

func _remove_block(cell: Vector3i) -> void:
    if not blocks.has(cell):
        return
    var entry: Dictionary = blocks[cell]
    entry.node.queue_free()
    blocks.erase(cell)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 3.5, 7)
    player.set_script(load("res://scripts/player.gd"))
    add_child(player)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.55, 0)
    camera.current = true
    player.add_child(camera)

func _make_mobile_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    layer.add_child(root)

    status_label = Label.new()
    status_label.position = Vector2(18, 14)
    status_label.add_theme_font_size_override("font_size", 22)
    status_label.add_theme_color_override("font_color", Color.WHITE)
    status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    status_label.add_theme_constant_override("shadow_offset_x", 2)
    status_label.add_theme_constant_override("shadow_offset_y", 2)
    root.add_child(status_label)
    _update_status()

    _add_button(root, "▲", Vector2(95, -190), Vector2(66, 66), "move_forward")
    _add_button(root, "▼", Vector2(95, -45), Vector2(66, 66), "move_back")
    _add_button(root, "◀", Vector2(25, -118), Vector2(66, 66), "move_left")
    _add_button(root, "▶", Vector2(165, -118), Vector2(66, 66), "move_right")
    _add_button(root, "JUMP", Vector2(-110, -190), Vector2(92, 58), "jump")
    _add_action_button(root, "BREAK", Vector2(-110, -118), Vector2(92, 58), _break_target)
    _add_action_button(root, "PLACE", Vector2(-110, -46), Vector2(92, 58), _place_target)
    _add_action_button(root, "BLOCK", Vector2(-110, -264), Vector2(92, 58), _cycle_block)

func _add_button(parent: Control, caption: String, offset: Vector2, size: Vector2, action: String) -> void:
    var button := Button.new()
    button.text = caption
    button.size = size
    button.anchor_left = 0.0 if offset.x >= 0 else 1.0
    button.anchor_right = button.anchor_left
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.position = offset
    button.add_theme_font_size_override("font_size", 18)
    button.button_down.connect(func(): player.set_mobile_action(action, true))
    button.button_up.connect(func(): player.set_mobile_action(action, false))
    parent.add_child(button)

func _add_action_button(parent: Control, caption: String, offset: Vector2, size: Vector2, callback: Callable) -> void:
    var button := Button.new()
    button.text = caption
    button.size = size
    button.anchor_left = 1.0
    button.anchor_right = 1.0
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.position = offset
    button.add_theme_font_size_override("font_size", 16)
    button.pressed.connect(callback)
    parent.add_child(button)

func _update_status() -> void:
    if is_instance_valid(status_label):
        status_label.text = "GPT CRAFT  |  Selected: " + BLOCK_NAMES[selected_block] + "  |  Blocks: " + str(blocks.size())

func _cycle_block() -> void:
    selected_block = (selected_block + 1) % BLOCK_NAMES.size()
    _update_status()

func _get_target() -> Dictionary:
    var from := camera.global_position
    var to := from + (-camera.global_transform.basis.z * REACH)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player.get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(query)

func _break_target() -> void:
    var hit := _get_target()
    if hit.is_empty():
        return
    var collider = hit.collider
    if collider is StaticBody3D and collider.has_meta("cell"):
        _remove_block(collider.get_meta("cell"))
        _update_status()

func _place_target() -> void:
    var hit := _get_target()
    if hit.is_empty():
        return
    var normal: Vector3 = hit.normal
    var adjacent := hit.position + normal * 0.51
    var cell := Vector3i(floori(adjacent.x), floori(adjacent.y), floori(adjacent.z))
    var player_cell := Vector3i(floori(player.global_position.x), floori(player.global_position.y), floori(player.global_position.z))
    if cell == player_cell or cell == player_cell + Vector3i(0, 1, 0):
        return
    _add_block(cell, selected_block)
    _update_status()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x > get_viewport().size.x * 0.38:
            touch_look_id = event.index
            last_touch_position = event.position
        elif not event.pressed and event.index == touch_look_id:
            touch_look_id = -1
    elif event is InputEventScreenDrag and event.index == touch_look_id:
        var delta := event.position - last_touch_position
        last_touch_position = event.position
        player.rotate_y(-delta.x * look_sensitivity)
        player.rotate_camera(-delta.y * look_sensitivity)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        player.rotate_y(-event.relative.x * look_sensitivity)
        player.rotate_camera(-event.relative.y * look_sensitivity)

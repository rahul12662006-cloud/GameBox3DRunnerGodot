extends Node3D

# GameBox Builder - real 3D endless runner prototype.
# This is intentionally template/config driven so the Android builder can later inject config.json.

const LANES := [-2.6, 0.0, 2.6]
const PLAYER_Z := 5.5
const SPAWN_Z := -72.0
const DESPAWN_Z := 12.0
const BASE_Y := 0.78

var config: Dictionary = {
	"gameName": "GameBox 3D Runner",
	"map": "city",
	"character": "runner_boy",
	"speed": 3,
	"difficulty": 2,
	"coinsEnabled": true,
	"powerupsEnabled": true,
	"obstaclePack": "mixed_starter_pack"
}

var materials: Dictionary = {}
var world_root: Node3D
var items_root: Node3D
var player_root: Node3D
var player_body: Node3D
var camera: Camera3D
var hud_label: Label
var message_panel: Panel
var message_label: Label
var restart_button: Button
var pause_button: Button

var lane_index := 1
var player_y := BASE_Y
var vertical_velocity := 0.0
var on_ground := true
var slide_timer := 0.0
var shield_timer := 0.0
var magnet_timer := 0.0
var double_timer := 0.0
var spawn_timer := 0.0
var distance_score := 0.0
var coins := 0
var best_score := 0
var game_over := false
var paused := false
var items: Array = []

func _ready() -> void:
	randomize()
	setup_keyboard_input()
	load_config()
	load_best_score()
	create_materials()
	create_world()
	create_player()
	create_camera()
	create_ui()
	reset_game()

func _process(delta: float) -> void:
	if game_over or paused:
		return
	update_player(delta)
	update_powerups(delta)
	update_spawning(delta)
	update_items(delta)
	update_camera(delta)
	distance_score += delta * game_speed() * 8.5
	update_hud()


func setup_keyboard_input() -> void:
	add_key_action("lane_left", KEY_LEFT)
	add_key_action("lane_right", KEY_RIGHT)
	add_key_action("jump", KEY_SPACE)
	add_key_action("slide", KEY_SHIFT)

func add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, ev)

func load_config() -> void:
	var path := "res://configs/config.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			for key in parsed.keys():
				config[key] = parsed[key]

func load_best_score() -> void:
	var save := ConfigFile.new()
	if save.load("user://gamebox_runner_score.cfg") == OK:
		best_score = int(save.get_value("scores", "best", 0))

func save_best_score() -> void:
	var save := ConfigFile.new()
	save.set_value("scores", "best", best_score)
	save.save("user://gamebox_runner_score.cfg")

func create_materials() -> void:
	materials["road"] = make_mat(Color(0.055, 0.065, 0.095), 0.88, 0.0)
	materials["lane"] = make_mat(Color(0.55, 0.60, 0.72, 0.72), 0.45, 0.0)
	materials["edge"] = make_mat(Color(0.52, 0.26, 1.0), 0.28, 0.0, true)
	materials["player"] = make_mat(character_color(), 0.50, 0.05)
	materials["player_dark"] = make_mat(Color(0.18, 0.13, 0.35), 0.70, 0.0)
	materials["coin"] = make_mat(Color(1.0, 0.78, 0.16), 0.25, 0.0, true)
	materials["obstacle"] = make_mat(Color(1.0, 0.27, 0.28), 0.55, 0.0)
	materials["box"] = make_mat(Color(1.0, 0.50, 0.20), 0.62, 0.0)
	materials["gate"] = make_mat(Color(0.18, 0.85, 1.0), 0.24, 0.0, true)
	materials["shadow"] = make_mat(Color(0, 0, 0, 0.40), 0.90, 0.0)

func make_mat(color: Color, roughness := 0.7, metallic := 0.0, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.65
	return m

func character_color() -> Color:
	var name := str(config.get("character", "runner_boy")).to_lower()
	if name.contains("soldier"):
		return Color(0.30, 0.82, 0.42)
	if name.contains("robot"):
		return Color(0.38, 0.85, 1.0)
	if name.contains("ninja"):
		return Color(0.15, 0.14, 0.20)
	if name.contains("alien"):
		return Color(0.42, 1.0, 0.45)
	return Color(0.55, 0.35, 1.0)

func map_key() -> String:
	var m := str(config.get("map", "city")).to_lower()
	if m.contains("jungle") or m.contains("temple"):
		return "jungle"
	if m.contains("desert") or m.contains("ruin"):
		return "desert"
	if m.contains("snow") or m.contains("bridge"):
		return "snow"
	if m.contains("cyber") or m.contains("neon"):
		return "cyber"
	return "city"

func create_world() -> void:
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	items_root = Node3D.new()
	items_root.name = "Items"
	add_child(items_root)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.75
	match map_key():
		"jungle":
			env.background_color = Color(0.03, 0.15, 0.10)
		"desert":
			env.background_color = Color(0.23, 0.13, 0.07)
		"snow":
			env.background_color = Color(0.13, 0.17, 0.24)
		"cyber":
			env.background_color = Color(0.02, 0.02, 0.08)
		_:
			env.background_color = Color(0.04, 0.05, 0.10)
	world_env.environment = env
	add_child(world_env)
	RenderingServer.set_default_clear_color(env.background_color)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, -20, 0)
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 5, 6)
	fill.light_energy = 1.8
	fill.omni_range = 18
	add_child(fill)

	create_road()
	create_environment_props()

func create_road() -> void:
	# Main road platform
	add_box("Road", Vector3(0, 0, -32), Vector3(4.2, 0.05, 42.0), materials["road"], world_root)
	# Purple edge rails
	add_box("LeftEdge", Vector3(-4.6, 0.12, -32), Vector3(0.12, 0.08, 42.0), materials["edge"], world_root)
	add_box("RightEdge", Vector3(4.6, 0.12, -32), Vector3(0.12, 0.08, 42.0), materials["edge"], world_root)
	# Lane dividers + depth markers
	for z in range(-72, 12, 5):
		add_box("DepthDash", Vector3(0, 0.18, float(z)), Vector3(0.13, 0.035, 0.40), materials["lane"], world_root)
	for x in [-1.3, 1.3]:
		add_box("LaneLine", Vector3(x, 0.16, -32), Vector3(0.035, 0.035, 42.0), materials["lane"], world_root)
	# Ground base below road for depth
	var base_mat := make_mat(Color(0.01, 0.012, 0.02), 0.95, 0.0)
	add_box("DeepBase", Vector3(0, -0.12, -32), Vector3(5.8, 0.05, 42.0), base_mat, world_root)

func create_environment_props() -> void:
	var key := map_key()
	for i in range(18):
		var z := -70.0 + i * 5.0
		var side := -1.0 if i % 2 == 0 else 1.0
		match key:
			"city":
				create_building(side * randf_range(6.2, 8.5), z, randf_range(2.2, 5.5))
			"jungle":
				create_tree(side * randf_range(5.8, 7.4), z)
			"desert":
				create_pillar(side * randf_range(5.8, 7.8), z)
			"snow":
				create_snow_rock(side * randf_range(5.8, 7.8), z)
			"cyber":
				create_neon_frame(z)

func create_building(x: float, z: float, h: float) -> void:
	var mat := make_mat(Color(randf_range(0.08, 0.14), randf_range(0.09, 0.14), randf_range(0.18, 0.28)), 0.9, 0.0)
	add_box("Building", Vector3(x, h * 0.5, z), Vector3(randf_range(0.8, 1.5), h, randf_range(0.7, 1.2)), mat, world_root)
	var win_mat := make_mat(Color(0.35, 0.42, 1.0), 0.25, 0.0, true)
	for y in range(1, int(h)):
		add_box("Window", Vector3(x + sign(x) * -0.42, y + 0.05, z + 0.18), Vector3(0.03, 0.12, 0.10), win_mat, world_root)

func create_tree(x: float, z: float) -> void:
	var trunk := make_mat(Color(0.28, 0.14, 0.05), 0.8, 0.0)
	var leaf := make_mat(Color(0.05, randf_range(0.35, 0.55), 0.16), 0.75, 0.0)
	add_cylinder("Trunk", Vector3(x, 0.65, z), 0.16, 1.3, trunk, world_root)
	add_sphere("Leaves", Vector3(x, 1.65, z), Vector3(0.8, 0.7, 0.8), leaf, world_root)

func create_pillar(x: float, z: float) -> void:
	var mat := make_mat(Color(0.55, 0.34, 0.16), 0.85, 0.0)
	add_cylinder("DesertPillar", Vector3(x, 1.2, z), 0.35, randf_range(1.8, 3.5), mat, world_root)
	add_box("PillarTop", Vector3(x, 2.65, z), Vector3(0.65, 0.18, 0.65), mat, world_root)

func create_snow_rock(x: float, z: float) -> void:
	var mat := make_mat(Color(0.82, 0.90, 1.0), 0.55, 0.0)
	add_sphere("SnowRock", Vector3(x, 0.45, z), Vector3(randf_range(0.5, 1.1), randf_range(0.25, 0.55), randf_range(0.5, 1.1)), mat, world_root)

func create_neon_frame(z: float) -> void:
	var mat := make_mat(Color(0.08, 0.95, 1.0), 0.25, 0.0, true)
	add_box("NeonLeft", Vector3(-5.2, 2.0, z), Vector3(0.08, 2.2, 0.08), mat, world_root)
	add_box("NeonRight", Vector3(5.2, 2.0, z), Vector3(0.08, 2.2, 0.08), mat, world_root)
	add_box("NeonTop", Vector3(0, 4.15, z), Vector3(5.3, 0.08, 0.08), mat, world_root)

func create_player() -> void:
	player_root = Node3D.new()
	player_root.name = "Player"
	add_child(player_root)
	player_root.position = Vector3(LANES[lane_index], BASE_Y, PLAYER_Z)

	player_body = Node3D.new()
	player_root.add_child(player_body)

	add_capsule("Body", Vector3(0, 0.45, 0), 0.38, 1.0, materials["player"], player_body)
	add_sphere("Head", Vector3(0, 1.23, 0), Vector3(0.36, 0.36, 0.36), materials["player"], player_body)
	add_sphere("FaceDot", Vector3(0.13, 1.32, 0.26), Vector3(0.08, 0.08, 0.04), make_mat(Color(1, 1, 1), 0.3, 0.0), player_body)
	add_box("LegL", Vector3(-0.17, -0.18, 0), Vector3(0.09, 0.42, 0.10), materials["player_dark"], player_body)
	add_box("LegR", Vector3(0.17, -0.18, 0), Vector3(0.09, 0.42, 0.10), materials["player_dark"], player_body)
	add_box("Shadow", Vector3(0, -0.69, 0.06), Vector3(0.55, 0.018, 0.35), materials["shadow"], player_body)

func create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "RunnerCamera"
	camera.fov = 62
	camera.position = Vector3(0, 5.4, 12.5)
	camera.rotation_degrees = Vector3(-23, 0, 0)
	camera.current = true
	add_child(camera)

func create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	hud_label = Label.new()
	hud_label.name = "HUD"
	hud_label.anchor_left = 0.04
	hud_label.anchor_right = 0.96
	hud_label.anchor_top = 0.035
	hud_label.anchor_bottom = 0.17
	hud_label.add_theme_font_size_override("font_size", 28)
	hud_label.add_theme_color_override("font_color", Color(0.93, 0.91, 1.0))
	hud_label.text = "Loading..."
	root.add_child(hud_label)

	pause_button = make_button("Pause", 0.77, 0.04, 0.96, 0.105)
	pause_button.pressed.connect(toggle_pause)
	root.add_child(pause_button)

	var left_button := make_button("Lane Left", 0.05, 0.83, 0.47, 0.91)
	left_button.pressed.connect(lane_left)
	root.add_child(left_button)
	var right_button := make_button("Lane Right", 0.53, 0.83, 0.95, 0.91)
	right_button.pressed.connect(lane_right)
	root.add_child(right_button)
	var jump_button := make_button("Jump", 0.05, 0.925, 0.47, 0.99)
	jump_button.pressed.connect(jump)
	root.add_child(jump_button)
	var slide_button := make_button("Slide", 0.53, 0.925, 0.95, 0.99)
	slide_button.pressed.connect(slide)
	root.add_child(slide_button)

	message_panel = Panel.new()
	message_panel.anchor_left = 0.16
	message_panel.anchor_right = 0.84
	message_panel.anchor_top = 0.35
	message_panel.anchor_bottom = 0.56
	message_panel.visible = false
	root.add_child(message_panel)
	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 30)
	message_label.add_theme_color_override("font_color", Color(0.96, 0.94, 1.0))
	message_panel.add_child(message_label)
	restart_button = make_button("Restart", 0.29, 0.57, 0.71, 0.64)
	restart_button.visible = false
	restart_button.pressed.connect(reset_game)
	root.add_child(restart_button)

func make_button(text: String, l: float, t: float, r: float, b: float) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_left = l
	button.anchor_top = t
	button.anchor_right = r
	button.anchor_bottom = b
	button.add_theme_font_size_override("font_size", 26)
	return button

func reset_game() -> void:
	for item in items:
		if is_instance_valid(item["node"]):
			item["node"].queue_free()
	items.clear()
	lane_index = 1
	player_y = BASE_Y
	vertical_velocity = 0.0
	on_ground = true
	slide_timer = 0.0
	shield_timer = 0.0
	magnet_timer = 0.0
	double_timer = 0.0
	spawn_timer = 0.0
	distance_score = 0.0
	coins = 0
	game_over = false
	paused = false
	message_panel.visible = false
	restart_button.visible = false
	pause_button.text = "Pause"
	player_root.position = Vector3(LANES[lane_index], BASE_Y, PLAYER_Z)
	for i in range(7):
		spawn_item(-18.0 - i * 10.0)
	update_hud()

func game_speed() -> float:
	var speed_setting := float(config.get("speed", 3))
	var difficulty := float(config.get("difficulty", 2))
	return 8.0 + speed_setting * 1.7 + difficulty * 0.55 + min(distance_score / 600.0, 5.0)

func update_player(delta: float) -> void:
	var target_x := LANES[lane_index]
	player_root.position.x = lerp(player_root.position.x, target_x, min(delta * 12.0, 1.0))
	if not on_ground:
		vertical_velocity -= 18.0 * delta
		player_y += vertical_velocity * delta
		if player_y <= BASE_Y:
			player_y = BASE_Y
			vertical_velocity = 0.0
			on_ground = true
	player_root.position.y = player_y
	if slide_timer > 0.0:
		slide_timer -= delta
		player_body.scale.y = lerp(player_body.scale.y, 0.58, min(delta * 18.0, 1.0))
		player_body.position.y = lerp(player_body.position.y, -0.22, min(delta * 18.0, 1.0))
	else:
		player_body.scale.y = lerp(player_body.scale.y, 1.0, min(delta * 14.0, 1.0))
		player_body.position.y = lerp(player_body.position.y, 0.0, min(delta * 14.0, 1.0))
	# Tiny running bob
	player_body.rotation_degrees.y = sin(Time.get_ticks_msec() * 0.009) * 3.0

func update_powerups(delta: float) -> void:
	shield_timer = max(0.0, shield_timer - delta)
	magnet_timer = max(0.0, magnet_timer - delta)
	double_timer = max(0.0, double_timer - delta)

func update_spawning(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_item(SPAWN_Z)
		var difficulty := float(config.get("difficulty", 2))
		spawn_timer = randf_range(0.72, 1.15) - difficulty * 0.045
		spawn_timer = max(spawn_timer, 0.42)

func update_items(delta: float) -> void:
	var move := game_speed() * delta
	var to_remove: Array = []
	for item in items:
		item["z"] += move
		item["node"].position.z = item["z"]
		# Magnet pulls coins/powerups toward player lane.
		if magnet_timer > 0.0 and (item["kind"] == "coin" or item["kind"] == "powerup"):
			item["node"].position.x = lerp(item["node"].position.x, player_root.position.x, min(delta * 5.0, 1.0))
			if abs(item["z"] - PLAYER_Z) < 2.8 and abs(item["node"].position.x - player_root.position.x) < 1.3:
				collect_item(item)
				to_remove.append(item)
				continue
		item["node"].rotation_degrees.y += delta * 80.0 if item["kind"] == "coin" else delta * 18.0
		if item["z"] > DESPAWN_Z:
			to_remove.append(item)
		elif abs(item["z"] - PLAYER_Z) < 0.95:
			check_collision(item, to_remove)
	for item in to_remove:
		items.erase(item)
		if is_instance_valid(item["node"]):
			item["node"].queue_free()

func update_camera(delta: float) -> void:
	camera.position.x = lerp(camera.position.x, player_root.position.x * 0.16, min(delta * 3.0, 1.0))
	camera.position.y = lerp(camera.position.y, 5.4 + player_root.position.y * 0.16, min(delta * 2.0, 1.0))

func update_hud() -> void:
	var score := int(distance_score)
	hud_label.text = "%s\nScore: %d   Best: %d   Coins: %d\nLane: %d   Speed: %s   Difficulty: %s" % [str(config.get("gameName", "3D Runner")), score, best_score, coins, lane_index + 1, str(config.get("speed", 3)), str(config.get("difficulty", 2))]
	var buffs: Array[String] = []
	if shield_timer > 0.0:
		buffs.append("Shield %ds" % int(ceil(shield_timer)))
	if magnet_timer > 0.0:
		buffs.append("Magnet %ds" % int(ceil(magnet_timer)))
	if double_timer > 0.0:
		buffs.append("2x Coins %ds" % int(ceil(double_timer)))
	if buffs.size() > 0:
		hud_label.text += "\n" + "  •  ".join(buffs)

func spawn_item(z: float) -> void:
	var lane := randi_range(0, 2)
	var roll := randf()
	var kind := "block"
	if bool(config.get("coinsEnabled", true)) and roll < 0.30:
		kind = "coin"
	elif bool(config.get("powerupsEnabled", true)) and roll < 0.38:
		kind = "powerup"
	else:
		var pack := str(config.get("obstaclePack", "mixed_starter_pack")).to_lower()
		if pack.contains("gate"):
			kind = "gate"
		elif pack.contains("ramp"):
			kind = "ramp"
		elif pack.contains("cone"):
			kind = "cone"
		else:
			kind = ["block", "gate", "cone", "barrier"].pick_random()
	var node := create_item_node(kind)
	node.position = Vector3(LANES[lane], item_height(kind), z)
	items_root.add_child(node)
	items.append({"node": node, "lane": lane, "z": z, "kind": kind})

func item_height(kind: String) -> float:
	match kind:
		"coin":
			return 1.25
		"powerup":
			return 1.65
		"gate":
			return 1.72
		"ramp":
			return 0.28
		_:
			return 0.55

func create_item_node(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Item_%s" % kind
	match kind:
		"coin":
			add_coin_mesh(root)
		"powerup":
			add_sphere("Powerup", Vector3.ZERO, Vector3(0.32, 0.32, 0.32), materials["gate"], root)
		"gate":
			add_box("GateTop", Vector3(0, 0, 0), Vector3(0.8, 0.16, 0.16), materials["gate"], root)
			add_box("GateL", Vector3(-0.42, -0.75, 0), Vector3(0.08, 1.3, 0.12), materials["gate"], root)
			add_box("GateR", Vector3(0.42, -0.75, 0), Vector3(0.08, 1.3, 0.12), materials["gate"], root)
		"ramp":
			add_box("Ramp", Vector3.ZERO, Vector3(0.75, 0.28, 0.75), materials["box"], root)
			root.rotation_degrees.x = -12
		"cone":
			add_cylinder("Cone", Vector3.ZERO, 0.38, 0.85, materials["obstacle"], root)
		"barrier":
			add_box("Barrier", Vector3(0, 0, 0), Vector3(1.0, 0.62, 0.35), materials["obstacle"], root)
		_:
			add_box("Box", Vector3(0, 0, 0), Vector3(0.86, 0.86, 0.86), materials["box"], root)
	return root

func add_coin_mesh(parent: Node3D) -> void:
	var coin := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 0.10
	mesh.radial_segments = 32
	coin.mesh = mesh
	coin.rotation_degrees.x = 90
	coin.material_override = materials["coin"]
	parent.add_child(coin)

func check_collision(item: Dictionary, to_remove: Array) -> void:
	if item["kind"] == "coin" or item["kind"] == "powerup":
		if abs(item["node"].position.x - player_root.position.x) < 0.75:
			collect_item(item)
			to_remove.append(item)
		return
	if item["lane"] != lane_index:
		return
	var passed := false
	if item["kind"] == "gate" and slide_timer > 0.0:
		passed = true
	if (item["kind"] == "block" or item["kind"] == "cone" or item["kind"] == "barrier") and player_root.position.y > 1.35:
		passed = true
	if item["kind"] == "ramp" and player_root.position.y > 1.0:
		passed = true
	if passed:
		return
	if shield_timer > 0.0:
		shield_timer = 0.0
		to_remove.append(item)
		return
	end_game()

func collect_item(item: Dictionary) -> void:
	if item["kind"] == "coin":
		coins += 2 if double_timer > 0.0 else 1
		distance_score += 30
	elif item["kind"] == "powerup":
		match randi_range(0, 2):
			0:
				shield_timer = 6.0
			1:
				magnet_timer = 7.0
			_:
				double_timer = 8.0

func end_game() -> void:
	game_over = true
	var final_score := int(distance_score)
	if final_score > best_score:
		best_score = final_score
		save_best_score()
	message_panel.visible = true
	restart_button.visible = true
	message_label.text = "Game Over\nScore %d  •  Coins %d" % [final_score, coins]
	update_hud()

func toggle_pause() -> void:
	if game_over:
		return
	paused = not paused
	pause_button.text = "Play" if paused else "Pause"
	message_panel.visible = paused
	message_label.text = "Paused" if paused else ""

func lane_left() -> void:
	if not game_over and not paused:
		lane_index = max(0, lane_index - 1)

func lane_right() -> void:
	if not game_over and not paused:
		lane_index = min(2, lane_index + 1)

func jump() -> void:
	if game_over or paused:
		return
	if on_ground:
		on_ground = false
		vertical_velocity = 8.8

func slide() -> void:
	if game_over or paused:
		return
	if on_ground:
		slide_timer = 0.85

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lane_left"):
		lane_left()
	elif event.is_action_pressed("lane_right"):
		lane_right()
	elif event.is_action_pressed("jump"):
		jump()
	elif event.is_action_pressed("slide"):
		slide()

func add_box(name: String, pos: Vector3, scale: Vector3, mat: Material, parent: Node) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.scale = scale
	node.material_override = mat
	parent.add_child(node)
	return node

func add_sphere(name: String, pos: Vector3, scale: Vector3, mat: Material, parent: Node) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.scale = scale
	node.material_override = mat
	parent.add_child(node)
	return node

func add_cylinder(name: String, pos: Vector3, radius: float, height: float, mat: Material, parent: Node) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

func add_capsule(name: String, pos: Vector3, radius: float, height: float, mat: Material, parent: Node) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

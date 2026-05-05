extends Node3D

# GameBox 3D Runner - Android-safe real 3D prototype.
# Phase 5A.4: procedural low-poly polish pass with cleaner UI, environment, obstacles and feedback.

const LANES = [-1.65, 0.0, 1.65]
const PLAYER_Z = 3.2
const SPAWN_Z = -92.0
const DESPAWN_Z = 9.5
const BASE_Y = 0.64

var config = {
	"gameName": "GameBox 3D Runner",
	"map": "city",
	"character": "runner_boy",
	"speed": 3,
	"difficulty": 2,
	"coinsEnabled": true,
	"powerupsEnabled": true,
	"obstaclePack": "mixed_starter_pack"
}

var mats = {}
var world_root
var item_root
var player_root
var player_body
var camera
var hud_label
var status_label
var pause_button
var restart_button
var game_over_panel
var game_over_label

var lane_index = 1
var player_y = BASE_Y
var vertical_velocity = 0.0
var on_ground = true
var slide_timer = 0.0
var shield_timer = 0.0
var magnet_timer = 0.0
var double_timer = 0.0
var spawn_timer = 0.0
var distance_score = 0.0
var coins = 0
var best_score = 0
var is_game_over = false
var is_paused = false
var items = []
var road_dash_nodes = []
var env_motion_nodes = []
var player_arm_l
var player_arm_r
var player_leg_l
var player_leg_r
var player_head
var player_trail_nodes = []
var run_cycle = 0.0
var last_lane_index = 1
var screen_shake_timer = 0.0
var feedback_label
var feedback_timer = 0.0

func _ready():
	randomize()
	create_boot_ui()
	status_label.text = "Loading runner..."
	setup_keyboard_input()
	load_config()
	load_best_score()
	create_materials()
	create_world()
	create_player()
	create_camera()
	create_game_ui()
	reset_game()
	status_label.text = ""

func _process(delta):
	if is_game_over or is_paused:
		return
	update_player(delta)
	update_powerups(delta)
	update_spawning(delta)
	update_items(delta)
	update_world_motion(delta)
	update_camera(delta)
	distance_score += delta * game_speed() * 8.0
	update_hud()

func create_boot_ui():
	var layer = CanvasLayer.new()
	layer.name = "BootUI"
	add_child(layer)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.anchor_left = 0.05
	status_label.anchor_right = 0.95
	status_label.anchor_top = 0.44
	status_label.anchor_bottom = 0.56
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	status_label.text = "Booting GameBox 3D Runner..."
	layer.add_child(status_label)

func setup_keyboard_input():
	add_key_action("lane_left", KEY_LEFT)
	add_key_action("lane_right", KEY_RIGHT)
	add_key_action("jump", KEY_SPACE)
	add_key_action("slide", KEY_SHIFT)

func add_key_action(action_name, keycode):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev = InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, ev)

func load_config():
	var path = "res://configs/config.json"
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			for key in parsed.keys():
				config[key] = parsed[key]

func load_best_score():
	var save = ConfigFile.new()
	if save.load("user://runner_score.cfg") == OK:
		best_score = int(save.get_value("scores", "best", 0))

func save_best_score():
	var save = ConfigFile.new()
	save.set_value("scores", "best", best_score)
	save.save("user://runner_score.cfg")

func create_materials():
	mats["road"] = make_mat(Color(0.020, 0.024, 0.034))
	mats["road_panel"] = make_mat(Color(0.032, 0.038, 0.055))
	mats["road_side"] = make_mat(Color(0.48, 0.25, 1.00), true, 0.45)
	mats["lane"] = make_mat(Color(0.72, 0.76, 0.92))
	mats["lane_glow"] = make_mat(Color(0.70, 0.58, 1.0), true, 0.35)
	mats["player"] = make_mat(character_color())
	mats["player_light"] = make_mat(character_color().lightened(0.25), true, 0.10)
	mats["player_dark"] = make_mat(Color(0.13, 0.10, 0.25))
	mats["shoe"] = make_mat(Color(0.06, 0.055, 0.09))
	mats["coin"] = make_mat(Color(1.0, 0.78, 0.12), true, 0.55)
	mats["powerup"] = make_mat(Color(0.18, 0.88, 0.95), true, 0.70)
	mats["obstacle"] = make_mat(Color(1.0, 0.20, 0.28))
	mats["obstacle_dark"] = make_mat(Color(0.42, 0.06, 0.10))
	mats["box"] = make_mat(Color(0.95, 0.42, 0.18))
	mats["box_band"] = make_mat(Color(1.0, 0.78, 0.42))
	mats["shadow"] = make_mat(Color(0.0, 0.0, 0.0, 0.48))
	mats["env_dark"] = make_mat(Color(0.075, 0.075, 0.14))
	mats["env_mid"] = make_mat(Color(0.11, 0.11, 0.20))
	mats["window"] = make_mat(Color(0.48, 0.55, 0.88), true, 0.30)
	mats["env_green"] = make_mat(Color(0.05, 0.32, 0.14))
	mats["env_desert"] = make_mat(Color(0.52, 0.31, 0.14))
	mats["env_snow"] = make_mat(Color(0.78, 0.88, 0.98))
	mats["env_cyber"] = make_mat(Color(0.10, 0.72, 0.95), true, 0.90)
	mats["lamp"] = make_mat(Color(1.0, 0.86, 0.52), true, 1.0)

func make_mat(color, emission_enabled := false, emission_energy := 0.0):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	mat.metallic = 0.0
	if emission_enabled:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	return mat

func character_color():
	var name = str(config.get("character", "runner_boy")).to_lower()
	if name.find("soldier") >= 0:
		return Color(0.28, 0.78, 0.38)
	if name.find("robot") >= 0:
		return Color(0.32, 0.80, 1.0)
	if name.find("ninja") >= 0:
		return Color(0.13, 0.12, 0.18)
	if name.find("alien") >= 0:
		return Color(0.45, 1.0, 0.45)
	return Color(0.55, 0.35, 1.0)

func map_key():
	var m = str(config.get("map", "city")).to_lower()
	if m.find("jungle") >= 0 or m.find("temple") >= 0:
		return "jungle"
	if m.find("desert") >= 0 or m.find("ruin") >= 0:
		return "desert"
	if m.find("snow") >= 0 or m.find("bridge") >= 0:
		return "snow"
	if m.find("cyber") >= 0 or m.find("neon") >= 0:
		return "cyber"
	return "city"

func create_world():
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	item_root = Node3D.new()
	item_root.name = "Items"
	add_child(item_root)

	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	match map_key():
		"jungle": e.background_color = Color(0.015, 0.09, 0.06)
		"desert": e.background_color = Color(0.18, 0.10, 0.045)
		"snow": e.background_color = Color(0.10, 0.14, 0.20)
		"cyber": e.background_color = Color(0.008, 0.010, 0.035)
		_: e.background_color = Color(0.018, 0.022, 0.040)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.40, 0.42, 0.55)
	e.ambient_light_energy = 0.65
	e.fog_enabled = true
	e.fog_density = 0.028
	e.fog_light_color = e.background_color.lightened(0.20)
	env.environment = e
	add_child(env)
	RenderingServer.set_default_clear_color(e.background_color)

	var sun = DirectionalLight3D.new()
	sun.light_energy = 2.65
	sun.rotation_degrees = Vector3(-58, -22, 0)
	add_child(sun)
	var fill = OmniLight3D.new()
	fill.position = Vector3(0, 4.2, 4.2)
	fill.light_energy = 1.85
	fill.omni_range = 24.0
	add_child(fill)
	var rim = OmniLight3D.new()
	rim.position = Vector3(0, 2.5, -12.0)
	rim.light_energy = 1.05
	rim.omni_range = 30.0
	add_child(rim)

	create_road()
	create_environment_props()

func create_road():
	road_dash_nodes.clear()
	add_box("GroundPlane", Vector3(0, -0.09, -38), Vector3(20.0, 0.055, 74.0), make_mat(Color(0.009, 0.010, 0.018)), world_root)

	# Segmented road plates give visible forward motion instead of one flat slab.
	for i in range(16):
		var z = -84.0 + float(i) * 6.0
		var mat = mats["road"] if i % 2 == 0 else mats["road_panel"]
		var plate = add_box("RoadPlate", Vector3(0, 0, z), Vector3(5.35, 0.08, 5.82), mat, world_root)
		road_dash_nodes.append(plate)

	add_box("LeftRail", Vector3(-3.45, 0.16, -38), Vector3(0.10, 0.13, 58.0), mats["road_side"], world_root)
	add_box("RightRail", Vector3(3.45, 0.16, -38), Vector3(0.10, 0.13, 58.0), mats["road_side"], world_root)
	add_box("LeftShoulder", Vector3(-3.15, 0.02, -38), Vector3(0.36, 0.04, 58.0), make_mat(Color(0.035, 0.030, 0.070)), world_root)
	add_box("RightShoulder", Vector3(3.15, 0.02, -38), Vector3(0.36, 0.04, 58.0), make_mat(Color(0.035, 0.030, 0.070)), world_root)

	for x in [-0.83, 0.83]:
		add_box("LaneLine", Vector3(x, 0.14, -38), Vector3(0.025, 0.035, 58.0), mats["lane"], world_root)
	for z in range(-88, 8, 4):
		var dash = add_box("CenterDash", Vector3(0, 0.18, float(z)), Vector3(0.10, 0.035, 0.42), mats["lane_glow"], world_root)
		road_dash_nodes.append(dash)
	for side_x in [-2.40, 2.40]:
		for z in range(-88, 8, 5):
			var side_dash = add_box("EdgeDash", Vector3(side_x, 0.18, float(z)), Vector3(0.055, 0.035, 0.72), mats["road_side"], world_root)
			road_dash_nodes.append(side_dash)

func create_environment_props():
	env_motion_nodes.clear()
	var key = map_key()
	for i in range(34):
		var z = -92.0 + float(i) * 4.1
		var left_x = -5.9 - randf() * 1.2
		var right_x = 5.9 + randf() * 1.2
		match key:
			"jungle":
				create_tree(left_x, z)
				create_tree(right_x, z + 2.2)
			"desert":
				create_pillar(left_x, z)
				create_pillar(right_x, z + 1.7)
			"snow":
				create_rock(left_x, z, mats["env_snow"])
				create_rock(right_x, z + 1.3, mats["env_snow"])
			"cyber":
				create_neon_gate(z)
			_:
				create_building(left_x, z)
				create_building(right_x, z + 2.0)

func create_prop_group(name, x, z):
	var group = Node3D.new()
	group.name = name
	group.position = Vector3(x, 0, z)
	world_root.add_child(group)
	env_motion_nodes.append(group)
	return group

func create_building(x, z):
	var group = create_prop_group("BuildingGroup", x, z)
	var h = randf_range(2.0, 6.2)
	var w = randf_range(0.60, 1.15)
	add_box("Building", Vector3(0, h * 0.5, 0), Vector3(w, h, randf_range(0.70, 1.18)), mats["env_dark"], group)
	var floors = clamp(int(h * 1.35), 3, 9)
	for f in range(floors):
		if randf() > 0.32:
			var y = 0.65 + float(f) * 0.45
			add_box("Window", Vector3(-w * 0.18, y, -0.60), Vector3(0.10, 0.055, 0.018), mats["window"], group)
			add_box("Window", Vector3(w * 0.18, y, -0.60), Vector3(0.10, 0.055, 0.018), mats["window"], group)
	# occasional street light / sign for depth and premium feel
	if randf() > 0.62:
		var lamp_x = -sign(x) * 1.15
		add_cylinder("LampPost", Vector3(lamp_x, 0.75, 0.15), 0.025, 1.5, mats["lane"], group)
		add_sphere("Lamp", Vector3(lamp_x, 1.55, 0.15), Vector3(0.12, 0.12, 0.12), mats["lamp"], group)

func create_tree(x, z):
	var group = create_prop_group("TreeGroup", x, z)
	add_cylinder("Trunk", Vector3(0, 0.55, 0), 0.16, 1.1, make_mat(Color(0.25, 0.12, 0.05)), group)
	add_sphere("Leaves", Vector3(0, 1.35, 0), Vector3(0.75, 0.62, 0.75), mats["env_green"], group)

func create_pillar(x, z):
	var group = create_prop_group("PillarGroup", x, z)
	add_cylinder("Pillar", Vector3(0, 1.1, 0), 0.32, 2.2, mats["env_desert"], group)

func create_rock(x, z, mat):
	var group = create_prop_group("RockGroup", x, z)
	add_sphere("Rock", Vector3(0, 0.35, 0), Vector3(randf_range(0.55, 1.0), 0.35, randf_range(0.55, 1.0)), mat, group)

func create_neon_gate(z):
	var group = create_prop_group("NeonGateGroup", 0, z)
	add_box("NeonL", Vector3(-5.0, 1.5, 0), Vector3(0.08, 1.6, 0.08), mats["env_cyber"], group)
	add_box("NeonR", Vector3(5.0, 1.5, 0), Vector3(0.08, 1.6, 0.08), mats["env_cyber"], group)
	add_box("NeonT", Vector3(0, 3.1, 0), Vector3(5.1, 0.08, 0.08), mats["env_cyber"], group)

func create_player():
	player_root = Node3D.new()
	player_root.name = "Player"
	add_child(player_root)
	player_root.position = Vector3(LANES[lane_index], BASE_Y, PLAYER_Z)
	player_body = Node3D.new()
	player_root.add_child(player_body)
	add_box("PlayerShadow", Vector3(0, -0.43, 0.10), Vector3(0.62, 0.025, 0.38), mats["shadow"], player_body)
	add_capsule("Torso", Vector3(0, 0.38, 0), 0.20, 0.74, mats["player"], player_body)
	add_box("ChestPlate", Vector3(0, 0.42, -0.10), Vector3(0.34, 0.25, 0.07), mats["player_light"], player_body)
	add_box("Backpack", Vector3(0, 0.40, 0.16), Vector3(0.30, 0.38, 0.08), mats["player_dark"], player_body)
	player_head = add_sphere("Head", Vector3(0, 0.96, -0.02), Vector3(0.22, 0.22, 0.22), mats["player_light"], player_body)
	add_box("Visor", Vector3(0, 0.98, -0.22), Vector3(0.18, 0.045, 0.025), mats["powerup"], player_body)
	player_arm_l = add_box("ArmL", Vector3(-0.27, 0.42, 0), Vector3(0.065, 0.34, 0.065), mats["player_dark"], player_body)
	player_arm_r = add_box("ArmR", Vector3(0.27, 0.42, 0), Vector3(0.065, 0.34, 0.065), mats["player_dark"], player_body)
	player_leg_l = add_box("LegL", Vector3(-0.12, -0.17, 0), Vector3(0.07, 0.34, 0.08), mats["player_dark"], player_body)
	player_leg_r = add_box("LegR", Vector3(0.12, -0.17, 0), Vector3(0.07, 0.34, 0.08), mats["player_dark"], player_body)
	add_box("ShoeL", Vector3(-0.12, -0.36, -0.07), Vector3(0.12, 0.045, 0.20), mats["shoe"], player_body)
	add_box("ShoeR", Vector3(0.12, -0.36, -0.07), Vector3(0.12, 0.045, 0.20), mats["shoe"], player_body)
	player_trail_nodes.clear()
	for i in range(3):
		var trail = add_box("RunTrail", Vector3(0, 0.05, 0.35 + float(i) * 0.20), Vector3(0.06, 0.028, 0.20), mats["road_side"], player_body)
		trail.visible = false
		player_trail_nodes.append(trail)

func create_camera():
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 4.15, 8.20)
	camera.look_at(Vector3(0, 1.10, -16), Vector3.UP)
	camera.fov = 78
	camera.current = true
	add_child(camera)

func create_game_ui():
	var layer = CanvasLayer.new()
	layer.name = "GameUI"
	add_child(layer)
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	hud_label = Label.new()
	hud_label.anchor_left = 0.04
	hud_label.anchor_right = 0.96
	hud_label.anchor_top = 0.025
	hud_label.anchor_bottom = 0.135
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_color", Color(0.94, 0.92, 1.0))
	root.add_child(hud_label)

	feedback_label = Label.new()
	feedback_label.anchor_left = 0.30
	feedback_label.anchor_right = 0.70
	feedback_label.anchor_top = 0.18
	feedback_label.anchor_bottom = 0.24
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 22)
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.26))
	feedback_label.text = ""
	root.add_child(feedback_label)

	pause_button = make_button("Pause", 0.80, 0.035, 0.955, 0.085)
	pause_button.pressed.connect(toggle_pause)
	root.add_child(pause_button)

	var left_btn = make_button("◀", 0.04, 0.865, 0.23, 0.935)
	left_btn.pressed.connect(lane_left)
	root.add_child(left_btn)
	var right_btn = make_button("▶", 0.77, 0.865, 0.96, 0.935)
	right_btn.pressed.connect(lane_right)
	root.add_child(right_btn)
	var jump_btn = make_button("JUMP", 0.31, 0.865, 0.48, 0.935)
	jump_btn.pressed.connect(jump)
	root.add_child(jump_btn)
	var slide_btn = make_button("SLIDE", 0.52, 0.865, 0.69, 0.935)
	slide_btn.pressed.connect(slide)
	root.add_child(slide_btn)

	game_over_panel = Panel.new()
	game_over_panel.anchor_left = 0.16
	game_over_panel.anchor_right = 0.84
	game_over_panel.anchor_top = 0.30
	game_over_panel.anchor_bottom = 0.50
	game_over_panel.visible = false
	root.add_child(game_over_panel)

	game_over_label = Label.new()
	game_over_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 29)
	game_over_label.add_theme_color_override("font_color", Color(0.96, 0.94, 1.0))
	game_over_panel.add_child(game_over_label)

	restart_button = make_button("Restart", 0.32, 0.515, 0.68, 0.585)
	restart_button.visible = false
	restart_button.pressed.connect(reset_game)
	root.add_child(restart_button)

func make_button(text, l, t, r, b):
	var btn = Button.new()
	btn.text = text
	btn.anchor_left = l
	btn.anchor_top = t
	btn.anchor_right = r
	btn.anchor_bottom = b
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.94, 0.92, 1.0, 0.92))
	btn.add_theme_stylebox_override("normal", button_style(Color(0.045, 0.045, 0.070, 0.46)))
	btn.add_theme_stylebox_override("hover", button_style(Color(0.20, 0.14, 0.35, 0.58)))
	btn.add_theme_stylebox_override("pressed", button_style(Color(0.50, 0.32, 0.95, 0.72)))
	return btn

func button_style(color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.75, 0.62, 1.0, 0.18)
	return style

func reset_game():
	for item in items:
		if is_instance_valid(item.node):
			item.node.queue_free()
	items.clear()
	lane_index = 1
	last_lane_index = 1
	run_cycle = 0.0
	screen_shake_timer = 0.0
	feedback_timer = 0.0
	if feedback_label:
		feedback_label.text = ""
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
	is_game_over = false
	is_paused = false
	game_over_panel.visible = false
	restart_button.visible = false
	pause_button.text = "Pause"
	player_root.position = Vector3(LANES[lane_index], BASE_Y, PLAYER_Z)
	for i in range(9):
		spawn_item(-24.0 - float(i) * 9.8)
	update_hud()

func game_speed():
	return 7.6 + float(config.get("speed", 3)) * 1.35 + float(config.get("difficulty", 2)) * 0.45 + min(distance_score / 850.0, 3.3)

func update_player(delta):
	var target_x = LANES[lane_index]
	var before_x = player_root.position.x
	player_root.position.x = lerp(player_root.position.x, target_x, min(delta * 11.0, 1.0))
	var lane_velocity = (player_root.position.x - before_x) / max(delta, 0.001)

	if on_ground and slide_timer <= 0.0:
		run_cycle += delta * game_speed() * 2.8
	else:
		run_cycle += delta * game_speed() * 1.25

	if not on_ground:
		vertical_velocity -= 18.0 * delta
		player_y += vertical_velocity * delta
		if player_y <= BASE_Y:
			player_y = BASE_Y
			vertical_velocity = 0.0
			on_ground = true
	player_root.position.y = player_y

	var run_bob = 0.0
	if on_ground and slide_timer <= 0.0:
		run_bob = abs(sin(run_cycle)) * 0.075
	player_root.position.z = PLAYER_Z + sin(run_cycle * 0.55) * 0.035

	if slide_timer > 0.0:
		slide_timer -= delta
		player_body.scale.y = lerp(player_body.scale.y, 0.58, min(delta * 16.0, 1.0))
		player_body.position.y = lerp(player_body.position.y, -0.18, min(delta * 16.0, 1.0))
	else:
		player_body.scale.y = lerp(player_body.scale.y, 1.0, min(delta * 14.0, 1.0))
		player_body.position.y = lerp(player_body.position.y, run_bob, min(delta * 14.0, 1.0))

	var lane_lean = clamp(-lane_velocity * 5.0, -16.0, 16.0)
	player_body.rotation_degrees.z = lerp(player_body.rotation_degrees.z, lane_lean, min(delta * 8.0, 1.0))
	player_body.rotation_degrees.y = sin(run_cycle * 0.8) * 3.5
	player_body.rotation_degrees.x = lerp(player_body.rotation_degrees.x, -13.0 if slide_timer > 0.0 else 0.0, min(delta * 9.0, 1.0))
	if player_head:
		player_head.position.y = 0.96 + run_bob * 0.45
	animate_runner_limbs(delta)
	update_runner_trails(delta)

func animate_runner_limbs(delta):
	if player_arm_l == null or player_leg_l == null:
		return
	var swing = sin(run_cycle)
	var swing_back = sin(run_cycle + PI)
	var arm_amount = 34.0 if slide_timer <= 0.0 else 10.0
	var leg_amount = 28.0 if slide_timer <= 0.0 else 8.0
	player_arm_l.rotation_degrees.x = lerp(player_arm_l.rotation_degrees.x, swing * arm_amount, min(delta * 12.0, 1.0))
	player_arm_r.rotation_degrees.x = lerp(player_arm_r.rotation_degrees.x, swing_back * arm_amount, min(delta * 12.0, 1.0))
	player_leg_l.rotation_degrees.x = lerp(player_leg_l.rotation_degrees.x, swing_back * leg_amount, min(delta * 12.0, 1.0))
	player_leg_r.rotation_degrees.x = lerp(player_leg_r.rotation_degrees.x, swing * leg_amount, min(delta * 12.0, 1.0))

func update_runner_trails(delta):
	var active = on_ground and slide_timer <= 0.0 and game_speed() > 8.5
	for i in range(player_trail_nodes.size()):
		var trail = player_trail_nodes[i]
		if is_instance_valid(trail):
			trail.visible = active and (sin(run_cycle * 1.7 + float(i)) > -0.2)
			trail.position.z = 0.34 + float(i) * 0.18 + fmod(run_cycle * 0.08, 0.18)


func update_powerups(delta):
	shield_timer = max(0.0, shield_timer - delta)
	magnet_timer = max(0.0, magnet_timer - delta)
	double_timer = max(0.0, double_timer - delta)
	feedback_timer = max(0.0, feedback_timer - delta)
	if feedback_label and feedback_timer <= 0.0:
		feedback_label.text = ""

func update_spawning(delta):
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_item(SPAWN_Z)
		spawn_timer = max(0.45, randf_range(0.78, 1.22) - float(config.get("difficulty", 2)) * 0.04)

func update_items(delta):
	var move = game_speed() * delta
	var remove_list = []
	for item in items:
		item.z += move
		item.node.position.z = item.z
		if item.kind == "coin" or item.kind == "powerup":
			item.node.rotation_degrees.y += delta * 100.0
		else:
			item.node.rotation_degrees.y += delta * 16.0
		if magnet_timer > 0.0 and (item.kind == "coin" or item.kind == "powerup"):
			item.node.position.x = lerp(item.node.position.x, player_root.position.x, min(delta * 4.5, 1.0))
		if item.z > DESPAWN_Z:
			remove_list.append(item)
		elif abs(item.z - PLAYER_Z) < 1.05:
			check_collision(item, remove_list)
	for item in remove_list:
		items.erase(item)
		if is_instance_valid(item.node):
			item.node.queue_free()

func update_world_motion(delta):
	var move = game_speed() * delta
	for dash in road_dash_nodes:
		if is_instance_valid(dash):
			dash.position.z += move * 1.45
			if dash.position.z > 10.0:
				dash.position.z -= 96.0
	for prop in env_motion_nodes:
		if is_instance_valid(prop):
			prop.position.z += move * 0.78
			if prop.position.z > 10.0:
				prop.position.z -= 135.0

func update_camera(delta):
	var speed_push = clamp((game_speed() - 9.0) * 0.040, 0.0, 0.40)
	var bob = sin(run_cycle * 0.58) * 0.050
	var shake = Vector3.ZERO
	if screen_shake_timer > 0.0:
		screen_shake_timer = max(0.0, screen_shake_timer - delta)
		shake = Vector3(randf_range(-0.10, 0.10), randf_range(-0.06, 0.06), 0) * (screen_shake_timer / 0.30)
	var target_pos = Vector3(player_root.position.x * 0.18, 3.85 + bob, 8.15 - speed_push) + shake
	camera.position = camera.position.lerp(target_pos, min(delta * 5.5, 1.0))
	camera.fov = lerp(camera.fov, 78.0 + speed_push * 9.0, min(delta * 2.7, 1.0))
	camera.look_at(Vector3(player_root.position.x * 0.08, 1.08 + bob, -18.0), Vector3.UP)

func update_hud():
	var score = int(distance_score)
	hud_label.text = "%s\nScore: %d   Best: %d   Coins: %d\nLane: %d   Speed: %s   Difficulty: %s" % [str(config.get("gameName", "3D Runner")), score, best_score, coins, lane_index + 1, str(config.get("speed", 3)), str(config.get("difficulty", 2))]
	var buffs = []
	if shield_timer > 0.0:
		buffs.append("Shield %ds" % int(ceil(shield_timer)))
	if magnet_timer > 0.0:
		buffs.append("Magnet %ds" % int(ceil(magnet_timer)))
	if double_timer > 0.0:
		buffs.append("2x Coins %ds" % int(ceil(double_timer)))
	if buffs.size() > 0:
		hud_label.text += "\n" + "  •  ".join(buffs)

func spawn_item(z):
	var lane = randi_range(0, 2)
	var roll = randf()
	var kind = "block"
	if bool(config.get("coinsEnabled", true)) and roll < 0.30:
		kind = "coin"
	elif bool(config.get("powerupsEnabled", true)) and roll < 0.39:
		kind = "powerup"
	else:
		var pack = str(config.get("obstaclePack", "mixed_starter_pack")).to_lower()
		if pack.find("gate") >= 0:
			kind = "gate"
		elif pack.find("ramp") >= 0:
			kind = "ramp"
		elif pack.find("cone") >= 0:
			kind = "cone"
		else:
			kind = ["block", "gate", "cone", "barrier"].pick_random()
	var node = create_item_node(kind)
	node.position = Vector3(LANES[lane], item_height(kind), z)
	if kind != "coin" and kind != "powerup":
		add_box("ItemShadow", Vector3(0, -item_height(kind) + 0.08, 0.14), Vector3(0.48, 0.022, 0.34), mats["shadow"], node)
	item_root.add_child(node)
	items.append({"node": node, "lane": lane, "z": z, "kind": kind})

func item_height(kind):
	match kind:
		"coin": return 1.15
		"powerup": return 1.38
		"gate": return 1.48
		"ramp": return 0.26
		_: return 0.48

func create_item_node(kind):
	var root = Node3D.new()
	root.name = "Item_" + kind
	match kind:
		"coin":
			add_cylinder("Coin", Vector3.ZERO, 0.22, 0.08, mats["coin"], root).rotation_degrees.x = 90
			add_sphere("CoinGlow", Vector3.ZERO, Vector3(0.30, 0.30, 0.04), mats["coin"], root)
		"powerup":
			add_sphere("PowerCore", Vector3.ZERO, Vector3(0.23, 0.23, 0.23), mats["powerup"], root)
			add_cylinder("PowerRing", Vector3.ZERO, 0.32, 0.035, mats["powerup"], root).rotation_degrees.x = 90
		"gate":
			add_box("GateTop", Vector3(0, 0, 0), Vector3(0.80, 0.12, 0.14), mats["powerup"], root)
			add_box("GateL", Vector3(-0.40, -0.66, 0), Vector3(0.07, 1.12, 0.09), mats["powerup"], root)
			add_box("GateR", Vector3(0.40, -0.66, 0), Vector3(0.07, 1.12, 0.09), mats["powerup"], root)
		"ramp":
			add_box("RampBase", Vector3(0, -0.02, 0), Vector3(0.70, 0.20, 0.64), mats["box"], root)
			add_box("RampStripe", Vector3(0, 0.12, -0.18), Vector3(0.56, 0.028, 0.06), mats["box_band"], root)
			root.rotation_degrees.x = -12
		"cone":
			add_cylinder("Cone", Vector3(0, 0.0, 0), 0.22, 0.58, mats["obstacle"], root)
			add_box("ConeStripe", Vector3(0, 0.05, -0.22), Vector3(0.26, 0.035, 0.018), mats["box_band"], root)
		"barrier":
			add_box("Barrier", Vector3(0, 0.02, 0), Vector3(0.82, 0.40, 0.18), mats["obstacle"], root)
			add_box("BarrierStripe", Vector3(0, 0.12, -0.11), Vector3(0.70, 0.05, 0.025), mats["box_band"], root)
			add_box("BarrierBase", Vector3(0, -0.26, 0), Vector3(0.90, 0.08, 0.28), mats["obstacle_dark"], root)
		_:
			add_box("Crate", Vector3.ZERO, Vector3(0.58, 0.58, 0.58), mats["box"], root)
			add_box("CrateBandH", Vector3(0, 0.02, -0.31), Vector3(0.60, 0.055, 0.025), mats["box_band"], root)
			add_box("CrateBandV", Vector3(0.18, 0.02, -0.32), Vector3(0.055, 0.58, 0.025), mats["box_band"], root)
	return root

func check_collision(item, remove_list):
	if item.kind == "coin" or item.kind == "powerup":
		if abs(item.node.position.x - player_root.position.x) < 0.78:
			collect_item(item)
			remove_list.append(item)
		return
	if int(item.lane) != lane_index:
		return
	var passed = false
	if item.kind == "gate" and slide_timer > 0.0:
		passed = true
	if (item.kind == "block" or item.kind == "cone" or item.kind == "barrier") and player_root.position.y > 1.35:
		passed = true
	if item.kind == "ramp" and player_root.position.y > 1.0:
		passed = true
	if passed:
		return
	if shield_timer > 0.0:
		shield_timer = 0.0
		remove_list.append(item)
		return
	end_game()

func collect_item(item):
	if item.kind == "coin":
		var gain = 2 if double_timer > 0.0 else 1
		coins += gain
		distance_score += 30
		show_feedback("+%d coin" % gain)
	elif item.kind == "powerup":
		var p = randi_range(0, 2)
		if p == 0:
			shield_timer = 6.0
			show_feedback("Shield")
		elif p == 1:
			magnet_timer = 7.0
			show_feedback("Magnet")
		else:
			double_timer = 8.0
			show_feedback("2x Coins")

func show_feedback(text):
	if feedback_label:
		feedback_label.text = text
		feedback_timer = 1.0


func end_game():
	screen_shake_timer = 0.30
	is_game_over = true
	var final_score = int(distance_score)
	if final_score > best_score:
		best_score = final_score
		save_best_score()
	game_over_panel.visible = true
	restart_button.visible = true
	game_over_label.text = "Game Over\nScore %d  •  Coins %d" % [final_score, coins]
	update_hud()

func toggle_pause():
	if is_game_over:
		return
	is_paused = not is_paused
	pause_button.text = "Play" if is_paused else "Pause"
	game_over_panel.visible = is_paused
	game_over_label.text = "Paused" if is_paused else ""

func lane_left():
	if not is_game_over and not is_paused:
		lane_index = max(0, lane_index - 1)

func lane_right():
	if not is_game_over and not is_paused:
		lane_index = min(2, lane_index + 1)

func jump():
	if is_game_over or is_paused:
		return
	if on_ground:
		on_ground = false
		vertical_velocity = 8.7

func slide():
	if is_game_over or is_paused:
		return
	if on_ground:
		slide_timer = 0.85

func _unhandled_input(event):
	if event.is_action_pressed("lane_left"):
		lane_left()
	elif event.is_action_pressed("lane_right"):
		lane_right()
	elif event.is_action_pressed("jump"):
		jump()
	elif event.is_action_pressed("slide"):
		slide()

func add_box(name, pos, size, mat, parent):
	var mesh = BoxMesh.new()
	var node = MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.scale = size
	node.material_override = mat
	parent.add_child(node)
	return node

func add_sphere(name, pos, size, mat, parent):
	var mesh = SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 8
	var node = MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.scale = size
	node.material_override = mat
	parent.add_child(node)
	return node

func add_cylinder(name, pos, radius, height, mat, parent):
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var node = MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

func add_capsule(name, pos, radius, height, mat, parent):
	var mesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var node = MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

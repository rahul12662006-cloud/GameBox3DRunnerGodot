extends Node3D

# GameBox 3D Runner - Android-safe real 3D prototype.
# Phase 5A.2: camera, scale, UI and procedural low-poly art pass for a cleaner real-3D runner.

const LANES = [-1.65, 0.0, 1.65]
const PLAYER_Z = 3.2
const SPAWN_Z = -82.0
const DESPAWN_Z = 8.5
const BASE_Y = 0.68

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
	mats["road"] = make_mat(Color(0.025, 0.028, 0.040))
	mats["road_side"] = make_mat(Color(0.32, 0.18, 0.72))
	mats["lane"] = make_mat(Color(0.72, 0.76, 0.92))
	mats["player"] = make_mat(character_color())
	mats["player_dark"] = make_mat(Color(0.15, 0.11, 0.28))
	mats["coin"] = make_mat(Color(1.0, 0.78, 0.12))
	mats["powerup"] = make_mat(Color(0.18, 0.88, 0.95))
	mats["obstacle"] = make_mat(Color(1.0, 0.22, 0.30))
	mats["box"] = make_mat(Color(0.95, 0.42, 0.18))
	mats["shadow"] = make_mat(Color(0.0, 0.0, 0.0, 0.45))
	mats["env_dark"] = make_mat(Color(0.08, 0.08, 0.16))
	mats["env_green"] = make_mat(Color(0.05, 0.32, 0.14))
	mats["env_desert"] = make_mat(Color(0.52, 0.31, 0.14))
	mats["env_snow"] = make_mat(Color(0.78, 0.88, 0.98))
	mats["env_cyber"] = make_mat(Color(0.10, 0.72, 0.95))

func make_mat(color):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = 0.02
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
		"jungle": e.background_color = Color(0.02, 0.12, 0.08)
		"desert": e.background_color = Color(0.20, 0.12, 0.06)
		"snow": e.background_color = Color(0.12, 0.16, 0.22)
		"cyber": e.background_color = Color(0.02, 0.02, 0.08)
		_: e.background_color = Color(0.035, 0.04, 0.07)
	env.environment = e
	add_child(env)
	RenderingServer.set_default_clear_color(e.background_color)

	var sun = DirectionalLight3D.new()
	sun.light_energy = 2.25
	sun.rotation_degrees = Vector3(-54, -18, 0)
	add_child(sun)
	var fill = OmniLight3D.new()
	fill.position = Vector3(0, 4.5, 5.8)
	fill.light_energy = 1.45
	fill.omni_range = 22.0
	add_child(fill)

	create_road()
	create_environment_props()

func create_road():
	add_box("GroundPlane", Vector3(0, -0.06, -32), Vector3(18.0, 0.05, 60.0), make_mat(Color(0.012, 0.014, 0.025)), world_root)
	add_box("Road", Vector3(0, 0, -36), Vector3(5.1, 0.08, 46.0), mats["road"], world_root)
	add_box("LeftRail", Vector3(-3.35, 0.14, -36), Vector3(0.12, 0.12, 46.0), mats["road_side"], world_root)
	add_box("RightRail", Vector3(3.35, 0.14, -36), Vector3(0.12, 0.12, 46.0), mats["road_side"], world_root)
	for x in [-0.83, 0.83]:
		add_box("Lane", Vector3(x, 0.13, -36), Vector3(0.028, 0.035, 46.0), mats["lane"], world_root)
	for z in range(-80, 8, 5):
		add_box("Dash", Vector3(0, 0.17, float(z)), Vector3(0.12, 0.035, 0.40), mats["lane"], world_root)

func create_environment_props():
	var key = map_key()
	for i in range(26):
		var z = -78.0 + float(i) * 4.5
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

func create_building(x, z):
	var h = randf_range(1.6, 5.2)
	var w = randf_range(0.55, 1.05)
	add_box("Building", Vector3(x, h * 0.5, z), Vector3(w, h, randf_range(0.65, 1.05)), mats["env_dark"], world_root)
	if randf() > 0.45:
		add_box("WindowGlow", Vector3(x, h * 0.62, z - 0.56), Vector3(w * 0.42, 0.08, 0.018), mats["road_side"], world_root)

func create_tree(x, z):
	add_cylinder("Trunk", Vector3(x, 0.55, z), 0.16, 1.1, make_mat(Color(0.25, 0.12, 0.05)), world_root)
	add_sphere("Leaves", Vector3(x, 1.35, z), Vector3(0.75, 0.62, 0.75), mats["env_green"], world_root)

func create_pillar(x, z):
	add_cylinder("Pillar", Vector3(x, 1.1, z), 0.32, 2.2, mats["env_desert"], world_root)

func create_rock(x, z, mat):
	add_sphere("Rock", Vector3(x, 0.35, z), Vector3(randf_range(0.55, 1.0), 0.35, randf_range(0.55, 1.0)), mat, world_root)

func create_neon_gate(z):
	add_box("NeonL", Vector3(-5.0, 1.5, z), Vector3(0.08, 1.6, 0.08), mats["env_cyber"], world_root)
	add_box("NeonR", Vector3(5.0, 1.5, z), Vector3(0.08, 1.6, 0.08), mats["env_cyber"], world_root)
	add_box("NeonT", Vector3(0, 3.1, z), Vector3(5.1, 0.08, 0.08), mats["env_cyber"], world_root)

func create_player():
	player_root = Node3D.new()
	player_root.name = "Player"
	add_child(player_root)
	player_root.position = Vector3(LANES[lane_index], BASE_Y, PLAYER_Z)
	player_body = Node3D.new()
	player_root.add_child(player_body)
	add_box("PlayerShadow", Vector3(0, -0.46, 0.10), Vector3(0.55, 0.025, 0.34), mats["shadow"], player_body)
	add_capsule("Body", Vector3(0, 0.40, 0), 0.23, 0.78, mats["player"], player_body)
	add_sphere("Head", Vector3(0, 0.98, 0), Vector3(0.24, 0.24, 0.24), mats["player"], player_body)
	add_box("Chest", Vector3(0, 0.37, -0.05), Vector3(0.32, 0.32, 0.08), mats["player_dark"], player_body)
	add_box("ArmL", Vector3(-0.28, 0.42, 0), Vector3(0.07, 0.36, 0.07), mats["player_dark"], player_body)
	add_box("ArmR", Vector3(0.28, 0.42, 0), Vector3(0.07, 0.36, 0.07), mats["player_dark"], player_body)
	add_box("LegL", Vector3(-0.12, -0.16, 0), Vector3(0.07, 0.32, 0.08), mats["player_dark"], player_body)
	add_box("LegR", Vector3(0.12, -0.16, 0), Vector3(0.07, 0.32, 0.08), mats["player_dark"], player_body)

func create_camera():
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 4.75, 10.2)
	camera.look_at(Vector3(0, 0.95, -20), Vector3.UP)
	camera.fov = 72
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

	pause_button = make_button("Pause", 0.78, 0.032, 0.96, 0.082)
	pause_button.pressed.connect(toggle_pause)
	root.add_child(pause_button)

	var left_btn = make_button("◀", 0.04, 0.865, 0.25, 0.94)
	left_btn.pressed.connect(lane_left)
	root.add_child(left_btn)
	var right_btn = make_button("▶", 0.75, 0.865, 0.96, 0.94)
	right_btn.pressed.connect(lane_right)
	root.add_child(right_btn)
	var jump_btn = make_button("JUMP", 0.30, 0.855, 0.48, 0.925)
	jump_btn.pressed.connect(jump)
	root.add_child(jump_btn)
	var slide_btn = make_button("SLIDE", 0.52, 0.855, 0.70, 0.925)
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
	btn.add_theme_font_size_override("font_size", 18)
	btn.modulate = Color(1, 1, 1, 0.82)
	return btn

func reset_game():
	for item in items:
		if is_instance_valid(item.node):
			item.node.queue_free()
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
	is_game_over = false
	is_paused = false
	game_over_panel.visible = false
	restart_button.visible = false
	pause_button.text = "Pause"
	player_root.position = Vector3(LANES[lane_index], BASE_Y, PLAYER_Z)
	for i in range(8):
		spawn_item(-22.0 - float(i) * 9.2)
	update_hud()

func game_speed():
	return 7.6 + float(config.get("speed", 3)) * 1.35 + float(config.get("difficulty", 2)) * 0.45 + min(distance_score / 850.0, 3.3)

func update_player(delta):
	var target_x = LANES[lane_index]
	player_root.position.x = lerp(player_root.position.x, target_x, min(delta * 11.0, 1.0))
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
		player_body.scale.y = lerp(player_body.scale.y, 0.58, min(delta * 16.0, 1.0))
		player_body.position.y = lerp(player_body.position.y, -0.18, min(delta * 16.0, 1.0))
	else:
		player_body.scale.y = lerp(player_body.scale.y, 1.0, min(delta * 14.0, 1.0))
		player_body.position.y = lerp(player_body.position.y, 0.0, min(delta * 14.0, 1.0))
	player_body.rotation_degrees.y = sin(Time.get_ticks_msec() * 0.009) * 5.0
	player_body.rotation_degrees.x = -4.0 if slide_timer > 0.0 else 0.0

func update_powerups(delta):
	shield_timer = max(0.0, shield_timer - delta)
	magnet_timer = max(0.0, magnet_timer - delta)
	double_timer = max(0.0, double_timer - delta)

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

func update_camera(delta):
	camera.position.x = lerp(camera.position.x, player_root.position.x * 0.18, min(delta * 4.0, 1.0))
	camera.look_at(Vector3(player_root.position.x * 0.10, 0.90, -20.0), Vector3.UP)

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
		"powerup":
			add_sphere("Powerup", Vector3.ZERO, Vector3(0.24, 0.24, 0.24), mats["powerup"], root)
		"gate":
			add_box("GateTop", Vector3(0, 0, 0), Vector3(0.72, 0.12, 0.12), mats["powerup"], root)
			add_box("GateL", Vector3(-0.36, -0.66, 0), Vector3(0.06, 1.12, 0.08), mats["powerup"], root)
			add_box("GateR", Vector3(0.36, -0.66, 0), Vector3(0.06, 1.12, 0.08), mats["powerup"], root)
		"ramp":
			add_box("Ramp", Vector3.ZERO, Vector3(0.62, 0.24, 0.62), mats["box"], root)
			root.rotation_degrees.x = -12
		"cone":
			add_cylinder("Cone", Vector3.ZERO, 0.26, 0.62, mats["obstacle"], root)
		"barrier":
			add_box("Barrier", Vector3.ZERO, Vector3(0.82, 0.48, 0.28), mats["obstacle"], root)
		_:
			add_box("Box", Vector3.ZERO, Vector3(0.62, 0.62, 0.62), mats["box"], root)
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
		coins += 2 if double_timer > 0.0 else 1
		distance_score += 30
	elif item.kind == "powerup":
		var p = randi_range(0, 2)
		if p == 0:
			shield_timer = 6.0
		elif p == 1:
			magnet_timer = 7.0
		else:
			double_timer = 8.0

func end_game():
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

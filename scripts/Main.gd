extends Node3D

# GameBox 3D Runner - Android-safe real 3D prototype.
# Phase 5A.9.1: Run animation speed/selection fix.

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
var asset_catalog = {}
var asset_mode = "built_in_fallback"
var locked_asset_warnings = []
var asset_debug_text = ""
var selected_character_path = ""
var imported_player_model = null
var imported_skeleton = null
var imported_bones = {}
var imported_pose_ready = false
var imported_overlay_arm_l = null
var imported_overlay_arm_r = null
var imported_overlay_leg_l = null
var imported_overlay_leg_r = null
var imported_overlay_mode = false
var imported_animation_player = null
var imported_animation_status = "Animation: not loaded"
var imported_run_animation = ""
var imported_idle_animation = ""
var imported_jump_animation = ""
var imported_slide_animation = ""
var imported_current_anim = ""
var imported_run_speed_multiplier = 2.25
var imported_walk_as_run = false

func _ready():
	randomize()
	create_boot_ui()
	status_label.text = "Loading runner..."
	setup_keyboard_input()
	load_config()
	load_best_score()
	create_materials()
	scan_asset_catalog()
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

func scan_asset_catalog():
	asset_catalog = {
		"road": [],
		"barrier": [],
		"cone": [],
		"crate": [],
		"lamp": [],
		"sign": [],
		"building": [],
		"environment": [],
		"character": []
	}
	locked_asset_warnings.clear()
	asset_debug_text = ""
	selected_character_path = read_selected_player_path()
	if selected_character_path != "":
		register_asset("character", selected_character_path)
		asset_debug_text = "Selected path: " + selected_character_path.get_file()

	# Phase 5A.7C: strict, predictable asset order with explicit selected-player path.
	# 1) User-provided locked packs are highest priority.
	# 2) Bundled GameBox starter GLBs are fallback assets.
	# 3) Old random/vendor scan is intentionally avoided for visuals, because it produced ugly/mismatched output.
	var roots = [
		"res://assets/gamebox_locked/player/quaternius_fantasy/active",
		"res://assets/gamebox_locked/player/quaternius_fantasy",
		"res://assets/gamebox_locked/obstacles",
		"res://assets/gamebox_locked/environment",
		"res://assets/gamebox_locked/road",
		"res://assets/models/gamebox_lowpoly"
	]
	for root_path in roots:
		scan_asset_dir(root_path)

	var total = 0
	for key in asset_catalog.keys():
		asset_catalog[key].sort()
		total += asset_catalog[key].size()
	if selected_character_path != "" or has_locked_character():
		asset_mode = "locked_character_pack"
	elif total > 0:
		asset_mode = "gamebox_starter_pack"
	else:
		asset_mode = "built_in_fallback"
	print("GameBox asset mode: ", asset_mode, " models=", total)
	if not has_locked_character():
		locked_asset_warnings.append("Drop Quaternius fantasy .glb/.gltf files into assets/gamebox_locked/player/quaternius_fantasy/")
	else:
		print("GameBox locked character selected: ", preferred_asset_path("character"))


func read_selected_player_path():
	# Phase 5A.7E: load the generated wrapper scene first.
	# Directory scanning and TXT marker checks were unreliable in exported Android builds.
	# The GitHub Actions asset installer creates this scene after extracting the LFS ZIP,
	# and the scene directly references the selected full outfit glTF.
	return "res://scenes/LockedCharacter.tscn"

func try_load_scene_or_mesh(path):
	if path == "":
		return null
	# Do not hard-fail on ResourceLoader.exists(); exported generated glTF files can be loadable
	# even when exists() is unreliable during Android export.
	var res = load(path)
	if res == null:
		print("GameBox selected character load returned null: ", path)
		return null
	if res is PackedScene:
		return res.instantiate()
	if res is Mesh:
		var m = MeshInstance3D.new()
		m.mesh = res
		return m
	print("GameBox selected character unsupported resource type: ", path, " type=", typeof(res))
	return null

func create_locked_character_instance():
	var paths_to_try = []
	if selected_character_path != "":
		paths_to_try.append(selected_character_path)
	if has_asset("character"):
		for path in asset_catalog["character"]:
			if not paths_to_try.has(path):
				paths_to_try.append(path)
	for path in paths_to_try:
		var node = try_load_scene_or_mesh(path)
		if node != null:
			node.name = "LockedCharacterModel"
			node.rotation_degrees.y += 180.0
			fit_visual_model_to_height(node, 1.62, -0.52)
			prepare_imported_character_visual(node)
			asset_mode = "locked_character_loaded"
			asset_debug_text = "Character: " + path.get_file()
			print("GameBox locked character loaded: ", path)
			return node
	if paths_to_try.size() > 0:
		asset_debug_text = "Character failed: " + paths_to_try[0].get_file()
		print("GameBox locked character failed. Tried: ", paths_to_try)
	return null


func prepare_imported_character_visual(model):
	# Phase 5A.9: keep the model upright, then try to attach the Quaternius UAL animation GLB.
	# No blind bone-pose guessing. If real retarget fails, we keep safe upright mode instead
	# of flipping/folding the character.
	imported_player_model = model
	imported_skeleton = find_first_skeleton(model)
	imported_bones = {}
	imported_pose_ready = false
	imported_overlay_mode = false
	imported_overlay_arm_l = null
	imported_overlay_arm_r = null
	imported_overlay_leg_l = null
	imported_overlay_leg_r = null
	imported_animation_player = null
	imported_animation_status = "Animation: safe upright"
	imported_run_animation = ""
	imported_idle_animation = ""
	imported_jump_animation = ""
	imported_slide_animation = ""
	imported_current_anim = ""
	imported_run_speed_multiplier = 2.25
	imported_walk_as_run = false
	asset_debug_text = "Character: LockedCharacter.tscn • safe upright"
	if imported_skeleton != null:
		print("GameBox character skeleton found: ", imported_skeleton.name, " bones=", imported_skeleton.get_bone_count())
		setup_imported_animation_player()
	else:
		print("GameBox character has no skeleton. Using safe upright root motion only.")

func setup_imported_animation_player():
	if imported_player_model == null or imported_skeleton == null:
		return
	var source_instance = create_locked_animation_instance()
	if source_instance == null:
		imported_animation_status = "Animation: UAL missing"
		asset_debug_text = "Character: LockedCharacter.tscn • no animation pack"
		return
	var source_player = find_first_animation_player(source_instance)
	var source_skeleton = find_first_skeleton(source_instance)
	if source_player == null:
		imported_animation_status = "Animation: no AnimationPlayer"
		asset_debug_text = "Character: LockedCharacter.tscn • no anim player"
		source_instance.queue_free()
		return
	if source_skeleton == null:
		print("GameBox animation source skeleton not found; trying direct copy anyway.")
	imported_animation_player = AnimationPlayer.new()
	imported_animation_player.name = "GameBoxRetargetedAnimationPlayer"
	imported_player_model.add_child(imported_animation_player)
	# Animation track paths are relative to this root. Keeping root at the imported model
	# lets us rewrite source skeleton paths to the real character skeleton path.
	imported_animation_player.root_node = NodePath("..")
	var lib = AnimationLibrary.new()
	var installed = 0
	var anim_names = source_player.get_animation_list()
	for anim_name in anim_names:
		var anim = source_player.get_animation(anim_name)
		if anim == null:
			continue
		var copy = anim.duplicate(true)
		retarget_animation_tracks(copy, source_skeleton, imported_skeleton)
		lib.add_animation(anim_name, copy)
		installed += 1
	if installed <= 0:
		imported_animation_status = "Animation: empty UAL"
		asset_debug_text = "Character: LockedCharacter.tscn • empty animation"
		source_instance.queue_free()
		return
	imported_animation_player.add_animation_library("", lib)
	choose_imported_animation_names(anim_names)
	if imported_run_animation != "":
		play_imported_animation(imported_run_animation)
	imported_animation_status = "Animation: UAL %d clips • run x%.1f" % [installed, imported_run_speed_multiplier]
	asset_debug_text = "Character: LockedCharacter.tscn • " + imported_animation_status
	print("GameBox UAL animations installed: ", installed, " run=", imported_run_animation, " idle=", imported_idle_animation)
	source_instance.queue_free()

func create_locked_animation_instance():
	var paths = [
		"res://scenes/LockedAnimations.tscn",
		"res://assets/gamebox_locked/animations/quaternius_ual/active/UAL_Standard.glb"
	]
	for path in paths:
		var res = load(path)
		if res == null:
			continue
		if res is PackedScene:
			var node = res.instantiate()
			node.name = "GameBoxAnimationSource"
			add_child(node)
			node.visible = false
			node.position = Vector3(9999, 9999, 9999)
			print("GameBox animation source loaded: ", path)
			return node
	return null

func find_first_animation_player(node):
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = find_first_animation_player(child)
		if found != null:
			return found
	return null

func retarget_animation_tracks(anim, source_skeleton, target_skeleton):
	if anim == null or target_skeleton == null:
		return
	var target_path = str(imported_player_model.get_path_to(target_skeleton))
	var source_name = ""
	if source_skeleton != null:
		source_name = str(source_skeleton.name)
	for i in range(anim.get_track_count()):
		var original = str(anim.track_get_path(i))
		var colon = original.find(":")
		if colon < 0:
			continue
		var prop_part = original.substr(colon)
		# Bone tracks usually look like SomeRig/Skeleton3D:BoneName or Skeleton3D:BoneName.
		# We keep the bone/property part and redirect only the skeleton node part.
		if source_name == "" or original.find(source_name) >= 0 or original.to_lower().find("skeleton") >= 0 or prop_part.find(":") == 0:
			anim.track_set_path(i, NodePath(target_path + prop_part))

func choose_imported_animation_names(anim_names):
	# Phase 5A.9.1: prefer real run/sprint clips first. If the library only exposes
	# a walk/locomotion clip, use it as a temporary run and speed it up.
	imported_run_animation = pick_best_run_animation(anim_names)
	imported_idle_animation = pick_animation_name(anim_names, ["idle", "stand", "rest"] )
	imported_jump_animation = pick_animation_name(anim_names, ["jump", "leap", "fall", "air"] )
	imported_slide_animation = pick_animation_name(anim_names, ["slide", "crouch", "duck", "roll"] )
	var lower = imported_run_animation.to_lower()
	imported_walk_as_run = lower.find("walk") >= 0 or lower.find("locomotion") >= 0
	imported_run_speed_multiplier = 2.35 if imported_walk_as_run else 1.55
	print("GameBox animation selection: run=", imported_run_animation, " walk_as_run=", imported_walk_as_run, " speed=", imported_run_speed_multiplier)

func pick_best_run_animation(anim_names):
	var preferred = ["sprint", "running", "run", "jogging", "jog"]
	for key in preferred:
		for name in anim_names:
			var lower = str(name).to_lower()
			if lower.find(key) >= 0:
				return str(name)
	# Fallback: a walk clip is better than T-pose. We speed it up in play_imported_animation().
	return pick_animation_name(anim_names, ["walk", "walking", "locomotion", "move_forward", "forward"] )

func pick_animation_name(anim_names, keywords):
	for key in keywords:
		for name in anim_names:
			if str(name).to_lower().find(key) >= 0:
				return str(name)
	return ""

func imported_anim_speed_for(name):
	if name == "":
		return 1.0
	if name == imported_run_animation:
		return imported_run_speed_multiplier
	if name == imported_jump_animation:
		return 1.25
	if name == imported_slide_animation:
		return 1.35
	return 1.0

func play_imported_animation(name):
	if imported_animation_player == null or name == "":
		return
	if imported_animation_player.has_animation(name):
		imported_animation_player.speed_scale = imported_anim_speed_for(name)
		if imported_current_anim != name:
			imported_animation_player.play(name)
			imported_current_anim = name


func find_first_skeleton(node):
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = find_first_skeleton(child)
		if found != null:
			return found
	return null

func map_imported_bones(skel):
	imported_bones.clear()
	for i in range(skel.get_bone_count()):
		var n = skel.get_bone_name(i).to_lower()
		var compact = n.replace(" ", "").replace("_", "").replace("-", "")
		var is_left = compact.find("left") >= 0 or compact.find(" l") >= 0 or compact.ends_with("l") or compact.find(".l") >= 0
		var is_right = compact.find("right") >= 0 or compact.find(" r") >= 0 or compact.ends_with("r") or compact.find(".r") >= 0
		if compact.find("head") >= 0 and not imported_bones.has("head"):
			imported_bones["head"] = i
		elif (compact.find("spine") >= 0 or compact.find("chest") >= 0 or compact.find("torso") >= 0) and not imported_bones.has("spine"):
			imported_bones["spine"] = i
		elif (compact.find("upperarm") >= 0 or (compact.find("arm") >= 0 and compact.find("fore") < 0 and compact.find("lower") < 0)):
			if is_left and not imported_bones.has("arm_l"):
				imported_bones["arm_l"] = i
			elif is_right and not imported_bones.has("arm_r"):
				imported_bones["arm_r"] = i
		elif (compact.find("forearm") >= 0 or compact.find("lowerarm") >= 0):
			if is_left and not imported_bones.has("forearm_l"):
				imported_bones["forearm_l"] = i
			elif is_right and not imported_bones.has("forearm_r"):
				imported_bones["forearm_r"] = i
		elif (compact.find("thigh") >= 0 or compact.find("upperleg") >= 0 or compact.find("upleg") >= 0):
			if is_left and not imported_bones.has("leg_l"):
				imported_bones["leg_l"] = i
			elif is_right and not imported_bones.has("leg_r"):
				imported_bones["leg_r"] = i
		elif (compact.find("shin") >= 0 or compact.find("calf") >= 0 or (compact.find("leg") >= 0 and compact.find("upper") < 0)):
			if is_left and not imported_bones.has("shin_l"):
				imported_bones["shin_l"] = i
			elif is_right and not imported_bones.has("shin_r"):
				imported_bones["shin_r"] = i

func hide_static_arm_meshes(node):
	var lower = node.name.to_lower()
	if node is MeshInstance3D:
		if lower.find("arm") >= 0 or lower.find("pauldron") >= 0 or lower.find("shoulder") >= 0:
			node.visible = false
	for child in node.get_children():
		hide_static_arm_meshes(child)

func create_imported_overlay_limbs():
	if player_body == null:
		return
	var arm_mat = make_mat(Color(0.20, 0.42, 0.25))
	var boot_mat = make_mat(Color(0.09, 0.07, 0.08))
	imported_overlay_arm_l = add_box("OverlayArmL", Vector3(-0.36, 0.36, 0.02), Vector3(0.07, 0.44, 0.08), arm_mat, player_body)
	imported_overlay_arm_r = add_box("OverlayArmR", Vector3(0.36, 0.36, 0.02), Vector3(0.07, 0.44, 0.08), arm_mat, player_body)
	imported_overlay_leg_l = add_box("OverlayLegL", Vector3(-0.13, -0.36, 0.03), Vector3(0.08, 0.44, 0.08), boot_mat, player_body)
	imported_overlay_leg_r = add_box("OverlayLegR", Vector3(0.13, -0.36, 0.03), Vector3(0.08, 0.44, 0.08), boot_mat, player_body)
	imported_overlay_mode = true

func quat_from_euler_deg(x, y, z):
	return Basis.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))).get_rotation_quaternion()

func set_imported_bone_pose(key, x, y, z):
	if imported_skeleton == null or not imported_bones.has(key):
		return
	var idx = int(imported_bones[key])
	if idx >= 0 and idx < imported_skeleton.get_bone_count():
		imported_skeleton.set_bone_pose_rotation(idx, quat_from_euler_deg(x, y, z))

func animate_imported_character(delta):
	if imported_player_model == null:
		return
	# Real animation first. If retarget succeeds, play UAL clips. If not, stay upright
	# and only use subtle root motion. No unsafe bone guessing.
	if imported_animation_player != null:
		var target_anim = ""
		if slide_timer > 0.0 and imported_slide_animation != "":
			target_anim = imported_slide_animation
		elif not on_ground and imported_jump_animation != "":
			target_anim = imported_jump_animation
		elif on_ground and imported_run_animation != "":
			target_anim = imported_run_animation
		elif imported_idle_animation != "":
			target_anim = imported_idle_animation
		play_imported_animation(target_anim)
		if imported_animation_player.current_animation != "":
			imported_animation_player.speed_scale = imported_anim_speed_for(imported_animation_player.current_animation)
			if imported_animation_player.is_playing() == false:
				imported_animation_player.play(imported_animation_player.current_animation)
	else:
		var pulse = 0.018 * abs(sin(run_cycle)) if on_ground and slide_timer <= 0.0 else 0.0
		imported_player_model.position.y = lerp(imported_player_model.position.y, pulse, min(delta * 10.0, 1.0))
	var forward_pitch = -4.5 if on_ground and slide_timer <= 0.0 else 0.0
	imported_player_model.rotation_degrees.x = lerp(imported_player_model.rotation_degrees.x, forward_pitch, min(delta * 14.0, 1.0))
	imported_player_model.rotation_degrees.z = lerp(imported_player_model.rotation_degrees.z, 0.0, min(delta * 14.0, 1.0))


func scan_asset_dir(dir_path):
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		if file_name.begins_with("."):
			continue
		var path = dir_path + "/" + file_name
		if dir.current_is_dir():
			scan_asset_dir(path)
		else:
			var ext = file_name.get_extension().to_lower()
			if ext in ["glb", "gltf", "obj", "tscn", "scn"]:
				categorize_asset(path)
	dir.list_dir_end()

func categorize_asset(path):
	var lower = path.to_lower()
	# Locked player pack: Quaternius fantasy files may not contain the word "character", so we trust the folder.
	if lower.find("gamebox_locked/player") >= 0:
		register_asset("character", path)
		return
	if lower.find("character") >= 0 or lower.find("runner") >= 0 or lower.find("person") >= 0 or lower.find("robot") >= 0 or lower.find("hero") >= 0 or lower.find("adventurer") >= 0:
		register_asset("character", path)
	if lower.find("road") >= 0 or lower.find("street") >= 0 or lower.find("asphalt") >= 0 or lower.find("lane") >= 0:
		register_asset("road", path)
	if lower.find("barrier") >= 0 or lower.find("fence") >= 0 or lower.find("block") >= 0 or lower.find("gate") >= 0:
		register_asset("barrier", path)
	if lower.find("cone") >= 0:
		register_asset("cone", path)
	if lower.find("crate") >= 0 or lower.find("box") >= 0:
		register_asset("crate", path)
	if lower.find("lamp") >= 0 or lower.find("light") >= 0:
		register_asset("lamp", path)
	if lower.find("sign") >= 0:
		register_asset("sign", path)
	if lower.find("building") >= 0 or lower.find("house") >= 0 or lower.find("tower") >= 0:
		register_asset("building", path)
	if lower.find("tree") >= 0 or lower.find("rock") >= 0 or lower.find("pillar") >= 0 or lower.find("prop") >= 0:
		register_asset("environment", path)

func register_asset(key, path):
	if not asset_catalog.has(key):
		asset_catalog[key] = []
	if not asset_catalog[key].has(path):
		asset_catalog[key].append(path)

func has_asset(key):
	return asset_catalog.has(key) and asset_catalog[key].size() > 0

func has_locked_character():
	if not has_asset("character"):
		return false
	for path in asset_catalog["character"]:
		if str(path).find("gamebox_locked/player") >= 0:
			return true
	return false

func preferred_asset_path(key):
	if not has_asset(key):
		return ""
	var paths = asset_catalog[key]
	if key == "character":
		var preferred_names = [
			"active/outfits/male_ranger.gltf",
			"active/outfits/male_peasant.gltf",
			"active/outfits/female_ranger.gltf",
			"active/outfits/female_peasant.gltf",
			"outfits/male_ranger.gltf",
			"outfits/male_peasant.gltf",
			"outfits/female_ranger.gltf",
			"outfits/female_peasant.gltf"
		]
		for wanted in preferred_names:
			for path in paths:
				var lower = str(path).to_lower().replace("\\", "/")
				if lower.find(wanted) >= 0:
					return path
		# Avoid modular body parts as player models when possible.
		for path in paths:
			var lower = str(path).to_lower().replace("\\", "/")
			if lower.find("/outfits/") >= 0:
				return path
		for path in paths:
			if str(path).find("gamebox_locked") >= 0:
				return path
		return paths[0]
	# Locked assets first, then starter pack.
	for path in paths:
		if str(path).find("gamebox_locked") >= 0:
			return path
	return paths.pick_random()

func instantiate_asset_model(key, parent, pos := Vector3.ZERO, scale_value := Vector3.ONE, rot_degrees := Vector3.ZERO):
	if not has_asset(key):
		return null
	var path = preferred_asset_path(key)
	if path == "":
		return null
	var res = load(path)
	if res == null:
		print("GameBox asset failed to load: ", path)
		return null
	var node = null
	if res is PackedScene:
		node = res.instantiate()
	elif res is Mesh:
		node = MeshInstance3D.new()
		node.mesh = res
	else:
		return null
	node.name = "Asset_" + key
	node.position = pos
	node.scale = scale_value
	node.rotation_degrees = rot_degrees
	parent.add_child(node)
	if key == "character":
		# Quaternius outfits face direction/scale can vary; normalize after import.
		node.rotation_degrees.y += 180.0
		fit_visual_model_to_height(node, 1.52, -0.50)
		print("GameBox character model loaded: ", path)
	return node

func fit_visual_model_to_height(node, target_height, bottom_y):
	# Normalizes imported GLB/GLTF characters so random pack scale does not break the camera.
	if node == null:
		return
	var bounds = {"found": false, "min": Vector3(99999, 99999, 99999), "max": Vector3(-99999, -99999, -99999)}
	accumulate_mesh_bounds(node, bounds)
	if not bool(bounds["found"]):
		return
	var min_v = bounds["min"]
	var max_v = bounds["max"]
	var h = max(0.01, max_v.y - min_v.y)
	var factor = target_height / h
	node.scale *= factor
	# Recalculate after scaling and put the model feet near the same baseline as fallback player.
	bounds = {"found": false, "min": Vector3(99999, 99999, 99999), "max": Vector3(-99999, -99999, -99999)}
	accumulate_mesh_bounds(node, bounds)
	if bool(bounds["found"]):
		node.position.y += bottom_y - bounds["min"].y

func accumulate_mesh_bounds(node, bounds):
	if node is MeshInstance3D and node.mesh != null:
		var aabb = node.mesh.get_aabb()
		var corners = [
			aabb.position,
			aabb.position + Vector3(aabb.size.x, 0, 0),
			aabb.position + Vector3(0, aabb.size.y, 0),
			aabb.position + Vector3(0, 0, aabb.size.z),
			aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
			aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
			aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
			aabb.position + aabb.size
		]
		for corner in corners:
			var p = node.global_transform * corner
			bounds["min"] = Vector3(min(bounds["min"].x, p.x), min(bounds["min"].y, p.y), min(bounds["min"].z, p.z))
			bounds["max"] = Vector3(max(bounds["max"].x, p.x), max(bounds["max"].y, p.y), max(bounds["max"].z, p.z))
			bounds["found"] = true
	for child in node.get_children():
		if child is Node:
			accumulate_mesh_bounds(child, bounds)

func create_asset_prop(key, x, z, scale_min := 0.65, scale_max := 1.15):
	var group = create_prop_group("AssetProp_" + key, x, z)
	var s = randf_range(scale_min, scale_max)
	var model = instantiate_asset_model(key, group, Vector3.ZERO, Vector3(s, s, s), Vector3(0, randf_range(-12, 12), 0))
	if model == null:
		group.queue_free()
		return null
	return group

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
	e.ambient_light_energy = 0.92
	e.fog_enabled = true
	e.fog_density = 0.013
	e.fog_light_color = e.background_color.lightened(0.20)
	env.environment = e
	add_child(env)
	RenderingServer.set_default_clear_color(e.background_color)

	var sun = DirectionalLight3D.new()
	sun.light_energy = 3.20
	sun.rotation_degrees = Vector3(-58, -22, 0)
	add_child(sun)
	var fill = OmniLight3D.new()
	fill.position = Vector3(0, 4.2, 4.2)
	fill.light_energy = 2.35
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
				if create_asset_prop("environment", left_x, z, 0.55, 1.05) == null:
					create_tree(left_x, z)
				if create_asset_prop("environment", right_x, z + 2.2, 0.55, 1.05) == null:
					create_tree(right_x, z + 2.2)
			"desert":
				if create_asset_prop("environment", left_x, z, 0.70, 1.20) == null:
					create_pillar(left_x, z)
				if create_asset_prop("environment", right_x, z + 1.7, 0.70, 1.20) == null:
					create_pillar(right_x, z + 1.7)
			"snow":
				if create_asset_prop("environment", left_x, z, 0.65, 1.15) == null:
					create_rock(left_x, z, mats["env_snow"])
				if create_asset_prop("environment", right_x, z + 1.3, 0.65, 1.15) == null:
					create_rock(right_x, z + 1.3, mats["env_snow"])
			"cyber":
				create_neon_gate(z)
			_:
				if has_asset("building") and randf() > 0.25:
					create_asset_prop("building", left_x, z, 0.55, 1.15)
				else:
					create_building(left_x, z)
				if has_asset("building") and randf() > 0.25:
					create_asset_prop("building", right_x, z + 2.0, 0.55, 1.15)
				else:
					create_building(right_x, z + 2.0)
		if has_asset("lamp") and i % 3 == 0:
			create_asset_prop("lamp", -3.95, z + 0.9, 0.55, 0.90)
			create_asset_prop("lamp", 3.95, z + 2.4, 0.55, 0.90)

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
	add_box("PlayerShadow", Vector3(0, -0.43, 0.10), Vector3(0.66, 0.025, 0.42), mats["shadow"], player_body)

	# Phase 5A.7E: force-load generated LockedCharacter.tscn first.
	var imported_player = create_locked_character_instance()
	if imported_player != null:
		player_body.add_child(imported_player)
		player_head = null
		player_arm_l = null
		player_arm_r = null
		player_leg_l = null
		player_leg_r = null
		player_trail_nodes.clear()
		for i in range(3):
			var trail = add_box("RunTrail", Vector3(0, 0.05, 0.35 + float(i) * 0.20), Vector3(0.06, 0.028, 0.20), mats["road_side"], player_body)
			trail.visible = false
			player_trail_nodes.append(trail)
		return

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
	hud_label.add_theme_font_size_override("font_size", 17)
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

	var left_btn = make_button("◀", 0.05, 0.885, 0.20, 0.945)
	left_btn.pressed.connect(lane_left)
	root.add_child(left_btn)
	var right_btn = make_button("▶", 0.80, 0.885, 0.95, 0.945)
	right_btn.pressed.connect(lane_right)
	root.add_child(right_btn)
	var jump_btn = make_button("JUMP", 0.33, 0.890, 0.48, 0.945)
	jump_btn.pressed.connect(jump)
	root.add_child(jump_btn)
	var slide_btn = make_button("SLIDE", 0.52, 0.890, 0.67, 0.945)
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
	animate_imported_character(delta)
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
	if asset_mode == "locked_character_loaded":
		hud_label.text += "\n" + asset_debug_text
		if imported_animation_status != "":
			hud_label.text += "\n" + imported_animation_status
	elif asset_mode == "locked_character_pack":
		hud_label.text += "\nAssets: Locked pack found • " + asset_debug_text
	elif asset_mode == "gamebox_starter_pack":
		hud_label.text += "\nAssets: GameBox starter pack"
	elif locked_asset_warnings.size() > 0:
		hud_label.text += "\nAssets: fallback - add locked character pack"
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
	var asset_key = ""
	match kind:
		"cone": asset_key = "cone"
		"barrier": asset_key = "barrier"
		"block": asset_key = "crate"
		"gate": asset_key = "barrier"
		_: asset_key = ""
	if asset_key != "" and has_asset(asset_key):
		var asset_scale = Vector3(0.95, 0.95, 0.95)
		if kind == "gate":
			asset_scale = Vector3(1.15, 1.15, 1.15)
		var model = instantiate_asset_model(asset_key, root, Vector3.ZERO, asset_scale, Vector3.ZERO)
		if model != null:
			return root
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

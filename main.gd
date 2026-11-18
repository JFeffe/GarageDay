extends Node3D

const SYMBOL_FONT := preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf")
const HostSave := preload("res://host_save.gd")
const Coop := preload("res://workshop_coop.gd")
const BINDINGS := {
	"reset": [KEY_F9, JOY_BUTTON_BACK],
	"take": [KEY_E, JOY_BUTTON_Y],
	"rotate_item": [KEY_R, JOY_BUTTON_X],
	"cancel_item": [KEY_Q, JOY_BUTTON_B],
	"use_item": [KEY_F, JOY_BUTTON_A],
	"zoom_in": [KEY_EQUAL, JOY_BUTTON_RIGHT_SHOULDER],
	"zoom_out": [KEY_MINUS, JOY_BUTTON_LEFT_SHOULDER],
}

var player_visual = preload("res://player_visual.gd").new()
var workshop = preload("res://workshop.gd").new()
var web_room: JavaScriptObject
var web_controls: JavaScriptObject
var hosting := false
var save_elapsed := 0.0
var last_checkpoint := ""
var fps_elapsed := 0.0
var room_audio: AudioEffectCapture
var room_audio_rate := 0
@onready var avatar: Node3D = $Player
@onready var camera: Camera3D = $Camera

func _ready() -> void:
	set_process(false)
	# Web exports need an explicit fallback for the HUD symbols.
	var ui_fonts: Array[Font] = [ThemeDB.get_default_theme().default_font, ThemeDB.fallback_font]
	for font in ui_fonts:
		var fallbacks := font.fallbacks
		if SYMBOL_FONT in fallbacks: continue
		fallbacks.append(SYMBOL_FONT)
		font.fallbacks = fallbacks

	for action in BINDINGS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = BINDINGS[action][0]
		InputMap.action_add_event(action,key)
		var button := InputEventJoypadButton.new()
		button.button_index = BINDINGS[action][1]
		InputMap.action_add_event(action,button)
	player_visual.build(self,avatar)
	var initial_layout := 0
	var checkpoint := ""
	if OS.has_feature("web"):
		web_room = JavaScriptBridge.get_interface("window").parent.GarageDay
		if web_room!=null:
			var launch: Variant = JSON.parse_string(web_room.startInfo())
			if launch is Dictionary:
				initial_layout = clampi(int(launch.get("layout",0)),0,2)
				hosting = launch.get("mode")=="host"
				checkpoint = str(launch.get("save",""))
				apply_graphics(str(launch.get("quality","balanced")),bool(launch.get("showFps",false)))
				if hosting:
					workshop.coop = Coop.new()
					room_audio = AudioEffectCapture.new()
					room_audio.buffer_length = 0.15
					AudioServer.add_bus_effect(0,room_audio)
					room_audio_rate = int(AudioServer.get_mix_rate())
	workshop.setup(self,initial_layout)
	if checkpoint!="":
		if HostSave.restore(workshop,checkpoint): last_checkpoint = checkpoint
		else: workshop.inform("La sauvegarde n’a pas pu être relue.")
	if web_room!=null:
		web_controls = JavaScriptBridge.create_callback(control_web_game)
		web_room.gameReady(web_controls)
	store_checkpoint()

func control_web_game(args: Array) -> void:
	match args[0]:
		"pause":
			if hosting: return
			if args[1]: store_checkpoint()
			get_tree().paused = bool(args[1])
		"graphics":
			apply_graphics(str(args[1]),bool(args[2]))

func apply_graphics(quality: String, show_fps: bool) -> void:
	var sun: DirectionalLight3D = $Sun
	var viewport := get_viewport()
	sun.shadow_enabled = quality!="fast"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality=="high" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	viewport.scaling_3d_scale = 1.0 if quality=="high" else (0.67 if quality=="fast" else 0.85)
	fps_elapsed = 0.0
	set_process(show_fps)

func _process(dt: float) -> void:
	fps_elapsed += dt
	if fps_elapsed>=1.0:
		fps_elapsed = 0.0
		web_room.reportFps(Engine.get_frames_per_second())

func _physics_process(dt: float) -> void:
	if hosting:
		var controls: Variant = JSON.parse_string(web_room.guestInput())
		workshop.guest_input = controls if controls is Array else []
	workshop.tick(dt)
	if hosting:
		send_room_audio()
	if web_room!=null:
		save_elapsed += dt
		if save_elapsed>=0.8:
			save_elapsed = 0.0
			store_checkpoint()

func send_room_audio() -> void:
	var available := room_audio.get_frames_available()
	if available==0: return
	if workshop.guest_input.is_empty() or not workshop.guest_input[0]:
		room_audio.clear_buffer()
		return
	var frames := room_audio.get_buffer(available)
	web_room.gameAudio(Marshalls.raw_to_base64(frames.to_byte_array()),room_audio_rate)

func store_checkpoint() -> void:
	if web_room==null or workshop.relocating!="": return
	if workshop.run.mode not in ["open","lost","won"]: return
	var data := HostSave.capture(workshop) if workshop.run.mode=="open" else ""
	if data==last_checkpoint: return
	web_room.storeSave(data)
	last_checkpoint = data

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

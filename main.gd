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
var hosting := false
var save_elapsed := 0.0
var last_checkpoint := ""
@onready var avatar: Node3D = $Player
@onready var camera: Camera3D = $Camera

func _ready() -> void:
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
				if hosting:
					workshop.coop = Coop.new()
					checkpoint = str(launch.get("save",""))
	workshop.setup(self,initial_layout)
	if hosting and checkpoint!="":
		if HostSave.restore(workshop,checkpoint): last_checkpoint = checkpoint
		else: workshop.inform("La sauvegarde n’a pas pu être relue.")
	if web_room!=null: web_room.gameReady()
	store_checkpoint()

func _physics_process(dt: float) -> void:
	if hosting:
		var controls: Variant = JSON.parse_string(web_room.guestInput())
		workshop.guest_input = controls if controls is Array else []
	workshop.tick(dt)
	if hosting:
		save_elapsed += dt
		if save_elapsed>=0.8:
			save_elapsed = 0.0
			store_checkpoint()

func store_checkpoint() -> void:
	if not hosting or workshop.relocating!="": return
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

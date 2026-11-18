extends Node3D

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
@onready var avatar: Node3D = $Player
@onready var camera: Camera3D = $Camera

func _ready() -> void:
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
	workshop.setup(self)

func _physics_process(dt: float) -> void:
	workshop.tick(dt)

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

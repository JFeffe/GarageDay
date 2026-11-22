extends Control

const LOOK_LIMIT := deg_to_rad(82.0)
const MOUSE_SENSITIVITY := 0.0025
const LOOK_SPEED := 2.2
const FIELD_OF_VIEW := 67.0

var yaw := 0.0
var pitch := 0.0
var target_ready := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	set_input_active(false)

func set_input_active(active: bool) -> void:
	visible = active
	set_process_unhandled_input(active)
	var mode := Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE
	if DisplayServer.get_name()!="headless" and Input.mouse_mode!=mode:
		Input.mouse_mode = mode

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		turn(event.screen_relative*MOUSE_SENSITIVITY)

func turn(amount: Vector2) -> void:
	yaw = wrapf(yaw-amount.x,-PI,PI)
	pitch = clampf(pitch-amount.y,-LOOK_LIMIT,LOOK_LIMIT)

func face(direction: Vector3) -> void:
	yaw = atan2(-direction.x,-direction.z)
	pitch = clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-LOOK_LIMIT,LOOK_LIMIT)

func forward() -> Vector2:
	return Vector2.UP.rotated(-yaw)

func eye_position(player: Vector2, seated: float) -> Vector3:
	return Vector3(player.x,lerpf(1.60,1.23,seated),player.y)

func view_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch,yaw,0))

func frame(camera: Camera3D, player: Vector2, seated: float) -> void:
	if camera.projection!=Camera3D.PROJECTION_PERSPECTIVE:
		camera.set_perspective(FIELD_OF_VIEW,camera.near,camera.far)
	camera.rotation = Vector3(pitch,yaw,0)
	camera.position = eye_position(player,seated)

func indicate(ready: bool) -> void:
	if target_ready==ready: return
	target_ready = ready
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO,5.0,Color(0.06,0.12,0.14,0.85),true,-1.0,true)
	draw_circle(Vector2.ZERO,2.8,Color("#ffce84") if target_ready else Color("#fff3dc"),true,-1.0,true)

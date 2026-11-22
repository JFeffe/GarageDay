extends RefCounted

const ROTATION := Vector3(-63,0,0)
const ANGLES := ROTATION * (PI/180.0)
const ZOOM_SIZES := [13.8,9.2]

static func aspect(camera: Camera3D) -> float:
	var screen := camera.get_viewport().get_visible_rect().size
	return maxf(0.1,screen.x/maxf(1.0,screen.y))

static func overview_size(footprint: Vector2, ratio: float) -> float:
	var c := cos(ANGLES.y)
	var s := absf(sin(ANGLES.y))
	var width := footprint.x*c+footprint.y*s
	var depth := footprint.y*c+footprint.x*s
	return maxf(width/ratio+2.0,depth*absf(sin(ANGLES.x))+2.2)

static func fit_pair(view_size: float, separation: Vector2, ratio: float) -> float:
	return maxf(view_size,maxf(absf(separation.x)/ratio,absf(separation.y)*absf(sin(ANGLES.x)))+4.0)

static func place(camera: Camera3D, center: Vector2, view_size: float, blend: float) -> void:
	var offset := Basis.from_euler(ANGLES)*Vector3(0,0,35)
	camera.rotation_degrees = camera.rotation_degrees.lerp(ROTATION,blend)
	camera.position = camera.position.lerp(Vector3(center.x,0,center.y)+offset,blend)
	camera.size = lerpf(camera.size,view_size,blend)

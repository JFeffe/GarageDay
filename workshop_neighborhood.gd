extends RefCounted

const Miniature := preload("res://workshop_miniature.gd")
const SEDAN := preload("res://assets/garage_quartier/sedan.glb")
const VAN := preload("res://assets/garage_quartier/van.glb")
const CONVERTIBLE := preload("res://assets/garage_quartier/convertible.glb")
const SPORTS := preload("res://assets/garage_quartier/sedan-sports.glb")
const LUXURY := preload("res://assets/garage_quartier/suv-luxury.glb")
const WORN_HATCHBACK := preload("res://assets/garage_quartier/worn-hatchback.glb")
const ENGINE := preload("res://assets/garage_quartier/engine.glb")
const DELIVERY := preload("res://assets/garage_quartier/delivery.glb")
const WHEEL := preload("res://assets/garage_quartier/wheel-default.glb")
const CONE := preload("res://assets/garage_quartier/cone.glb")
const DISC := preload("res://assets/garage_quartier/brake-disc.glb")
const LIFT := preload("res://assets/garage_quartier/car-lift.glb")
const TROLLEY := preload("res://assets/garage_quartier/tool-trolley.glb")
const CAR_MODELS := [
	[SEDAN,Vector3(1.36,1.10,1.57)],
	[VAN,Vector3(1.38,1.28,1.51)],
	[CONVERTIBLE,Vector3(1.46,1.13,1.54)],
	[SPORTS,Vector3(1.43,1.10,1.57)],
	[LUXURY,Vector3(1.39,1.22,1.49)],
	[WORN_HATCHBACK,Vector3(1.37,1.10,1.42)],
]
const WHEEL_NAMES := ["wheel-front-left","wheel-back-left","wheel-front-right","wheel-back-right"]
const CABINET := preload("res://assets/garage_quartier/tool-cabinet.glb")
const SHELF := preload("res://assets/garage_quartier/parts-shelf.glb")
const OIL_CRATE := preload("res://assets/garage_quartier/oil-crate.glb")
const IMPACT_WRENCH := preload("res://assets/garage_quartier/impact-wrench.glb")
const COMPRESSOR := preload("res://assets/garage_quartier/compressor.glb")
const FIRE_EXTINGUISHER := preload("res://assets/garage_quartier/fire-extinguisher.glb")
const LIGHT_BAR := preload("res://assets/garage_quartier/shop-light.glb")
const SHUTTER := preload("res://assets/garage_quartier/roller-door.glb")
const STATION_MODELS := {
	"phone":preload("res://assets/kenney/desk.glb"),
	"reception":preload("res://assets/garage_quartier/reception-desk.glb"),
	"office_chair":preload("res://assets/kenney/chairCushion.glb"),
	"decor":preload("res://assets/kenney/bookcaseClosedDoors.glb"),
	"bench":preload("res://assets/garage_quartier/workbench.glb"),
	"parts_chassis":SHELF,
	"parts_electric":SHELF,
	"waste_oil":preload("res://assets/garage_quartier/oil-drum.glb"),
	"trash":preload("res://assets/garage_quartier/shop-bin.glb"),
	"seat":preload("res://assets/garage_quartier/waiting-bench.glb"),
}
const PART_MODELS := {
	"new_battery":preload("res://assets/garage_quartier/battery.glb"),
	"old_battery":preload("res://assets/garage_quartier/battery.glb"),
	"new_muffler":preload("res://assets/garage_quartier/muffler.glb"),
	"old_muffler":preload("res://assets/garage_quartier/muffler.glb"),
	"damper_part":preload("res://assets/garage_quartier/damper.glb"),
}

static func vehicle(root: Node3D, kind: int) -> Dictionary:
	var spec: Array = CAR_MODELS[kind]
	var model: Node3D = spec[0].instantiate()
	model.name = "CarrosserieKenney"
	model.scale = spec[1]
	root.add_child(model)
	var tires: Array[Node3D] = []
	var discs: Array[Node3D] = []
	for wheel_name in WHEEL_NAMES:
		var tire := model.find_child(wheel_name,true,false) as MeshInstance3D
		var side := signf(tire.position.x)
		tire.scale.z = 0.77
		tires.append(tire)
		discs.append(brake_disc(model,tire.position+Vector3(side*0.23,-0.184,0.0),side))
	var hood := model.find_child("HoodPivot",true,false) as MeshInstance3D
	add_engine_bay(hood)
	var wiper_mount := model.find_child("WiperMount",true,false) as Node3D
	if kind==2: dress_convertible(wiper_mount.get_parent() as Node3D)
	elif kind==3:
		var spoiler := model.find_child("spoiler",true,false) as MeshInstance3D
		spoiler.material_override = Miniature.material(Color("#3b3841"),0.42,0.10)
	elif kind==5: add_primer_patches(wiper_mount.get_parent() as Node3D)
	var lights := {
		"front":vehicle_lamps(model,["FrontLeft","FrontRight"],Color("#f6d592")),
		"rear":vehicle_lamps(model,["RearLeft","RearRight"],Color("#d75d4b")),
	}
	return {"hood":hood,"tires":tires,"discs":discs,"lights":lights,"wipers":windshield_wipers(wiper_mount)}

static func vehicle_lamps(model: Node3D, names: Array, color: Color) -> Array[MeshInstance3D]:
	var lamps: Array[MeshInstance3D] = []
	for node_name in names:
		var lamp := model.find_child(node_name,true,false) as MeshInstance3D
		lamp.material_override = Miniature.material(color,0.31,0.06)
		lamp.set_meta("lens",color)
		lamps.append(lamp)
	return lamps

static func add_engine_bay(hood: MeshInstance3D) -> void:
	var body := hood.get_parent() as Node3D
	var lid := hood.get_aabb()
	var floor_at := hood.position+Vector3(0,lid.position.y-0.153,lid.get_center().z)
	Miniature.bevel_box(body,Vector3(lid.size.x+0.025,0.031,lid.size.z+0.035),
		floor_at,Color("#303e47"),0.014)
	fit(body,ENGINE,Vector3(lid.size.x*0.64,0.119,lid.size.z*0.82),floor_at+Vector3(-0.09,0.016,0))
	fit(body,PART_MODELS.new_battery,Vector3(0.18,0.095,lid.size.z*0.38),floor_at+Vector3(0.27,0.015,0.016))
	anchor(body,"BatteryGrip",floor_at+Vector3(0.27,0.113,0.03))
	anchor(body,"EngineGrip",floor_at+Vector3(-0.05,0.12,lid.size.z*0.23))
	for x in [-0.38,0.38]:
		Miniature.bevel_box(body,Vector3(0.045,0.080,lid.size.z+0.013),
			floor_at+Vector3(x,0.046,0),Color("#53616a"),0.01)

static func impact_wrench(parent: Node3D) -> void:
	var model := IMPACT_WRENCH.instantiate() as Node3D
	model.rotation.y = PI
	model.scale = Vector3.ONE*0.86
	model.position = Vector3(0,0.24,0.16)
	parent.add_child(model)
	anchor(model,"SocketTip",Vector3(0,-0.15,-0.10))
	anchor(model,"HandleGrip",Vector3(0.036,-0.268,0.194))
	anchor(model,"MotorGrip",Vector3(-0.049,-0.132,0.137))

static func anchor(parent: Node3D, label: String, at: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = at
	parent.add_child(marker)

static func windshield_wipers(mount: Node3D) -> Array[Node3D]:
	var pivots: Array[Node3D] = []
	for x in [-0.28,0.13]:
		var pivot := Node3D.new()
		pivot.position.x = x
		mount.add_child(pivot)
		Miniature.bevel_box(pivot,Vector3(0.19,0.015,0.022),Vector3(0.085,0,0),Color("#28343a"),0.005)
		Miniature.bevel_box(pivot,Vector3(0.25,0.014,0.024),Vector3(0.19,0,-0.014),Color("#20282e"),0.004)
		pivots.append(pivot)
	return pivots

static func dress_convertible(body: Node3D) -> void:
	var trim := Color("#2b4249")
	Miniature.bevel_box(body,Vector3(0.94,0.025,0.90),Vector3(0,0.655,-0.03),trim,0.016)
	for x in [-0.26,0.26]:
		Miniature.bevel_box(body,Vector3(0.29,0.080,0.28),Vector3(x,0.69,-0.075),Color("#c19a72"),0.027)
		Miniature.bevel_box(body,Vector3(0.29,0.21,0.092),Vector3(x,0.74,-0.22),Color("#c19a72"),0.027)
		var pillar := Miniature.bevel_box(body,Vector3(0.028,0.028,0.334),Vector3(x*1.65,0.752,0.445),trim,0.009)
		pillar.rotation.x = atan2(0.20,0.26)
	Miniature.pane(body,[Vector3(-0.443,0.65,0.575),Vector3(0.443,0.65,0.575),
		Vector3(0.413,0.85,0.315),Vector3(-0.413,0.85,0.315)],Vector3.BACK,Color("#779eae"))
	Miniature.bevel_box(body,Vector3(0.85,0.025,0.03),Vector3(0,0.85,0.315),trim,0.008)

static func add_primer_patches(body: Node3D) -> void:
	Miniature.bevel_box(body,Vector3(0.009,0.088,0.262),Vector3(-0.554,0.50,-0.06),Color("#9b7e63"),0.004)
	Miniature.bevel_box(body,Vector3(0.009,0.077,0.205),Vector3(0.554,0.52,0.13),Color("#806852"),0.004)

static func brake_disc(parent: Node3D, at: Vector3, side: float) -> Node3D:
	var disc := DISC.instantiate() as Node3D
	disc.position = at
	disc.rotation.y = side*PI/2.0
	disc.scale = Vector3(1.05,1.10,1.05)
	parent.add_child(disc)
	disc.hide()
	return disc

static func loose_tire(parent: Node3D, at: Vector3, tint: Color) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.z = PI/2.0
	var model := WHEEL.instantiate() as Node3D
	model.rotation.z = PI/2.0
	model.scale = Vector3(0.47,1.03,1.03)
	root.add_child(model)
	color_tire(root,tint)
	return root

static func color_tire(root: Node3D, tint: Color) -> void:
	var mesh := root.get_child(0) as MeshInstance3D
	if not is_instance_valid(mesh):
		mesh = root.find_children("*","MeshInstance3D",true,false)[0]
	if mesh.material_override==null:
		mesh.material_override = mesh.mesh.surface_get_material(0).duplicate()
	mesh.material_override.albedo_color = Color.WHITE.lerp(tint.lightened(0.48),0.66)

static func fit(parent: Node3D, asset: PackedScene, size: Vector3, at := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var fitted := Node3D.new()
	var model := asset.instantiate() as Node3D
	parent.add_child(fitted)
	fitted.add_child(model)
	model.rotate_y(yaw)
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	if model is MeshInstance3D: meshes.push_front(model)
	var bounds := AABB()
	var from_world := fitted.global_transform.affine_inverse()
	for i in range(meshes.size()):
		var mesh: MeshInstance3D = meshes[i]
		var extent: AABB = (from_world*mesh.global_transform)*mesh.get_aabb()
		bounds = extent if i==0 else bounds.merge(extent)
	var scale := size/bounds.size
	if size.y==0.0: scale.y = minf(scale.x,scale.z)
	fitted.scale = scale
	var center := bounds.get_center()
	center.y = bounds.position.y
	fitted.position = at-center*fitted.scale
	return fitted

static func station(parent: Node3D, id: String, height: float, span: int) -> bool:
	if id.begins_with("seat_"):
		fit(parent,STATION_MODELS.seat,Vector3(0.70,0.92,0.90),Vector3.ZERO,PI/2.0)
	elif id.begins_with("counter_"):
		trolley(parent)
	elif STATION_MODELS.has(id):
		var model_height := height
		if id=="reception" or id=="bench" or id=="office_chair": model_height += 0.35
		fit(parent,STATION_MODELS[id],Vector3(span-0.12,model_height,0.84),Vector3.ZERO,PI if id=="reception" else 0.0)
	elif id.begins_with("tool_") or id in ["fresh_oil","new_battery","coolant"]:
		fit(parent,CABINET,Vector3(0.88,height,0.79),Vector3.ZERO,PI)
	else:
		return false
	return true

static func spare_part(parent: Node3D, part: String) -> bool:
	if not PART_MODELS.has(part): return false
	var size: Vector3 = {
		"new_battery":Vector3(0.35,0.25,0.24),"old_battery":Vector3(0.35,0.25,0.24),
		"new_muffler":Vector3(0.64,0.17,0.28),"old_muffler":Vector3(0.64,0.17,0.28),
		"damper_part":Vector3(0.15,0.18,0.46),
	}[part]
	fit(parent,PART_MODELS[part],size)
	return true

static func lift(site: Node3D, point: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.name = "PontGrab3D"
	root.position = Vector3(point.x,0.047,point.y)
	site.add_child(root)
	Miniature.bevel_box(root,Vector3(3.32,0.029,4.66),Vector3(0,0.012,0),Color("#526b68"),0.04)
	var model := LIFT.instantiate() as Node3D
	model.scale = Vector3(1.08,0.96,1.22)
	# Offset the columns from the door so the driver can step out beside the car.
	model.position.z = -0.62
	root.add_child(model)
	var carriage := model.find_child("car-lift_carriage",true,false) as Node3D
	var deck := Node3D.new()
	carriage.add_child(deck)
	# Give the original arms readable pads at the in-game sill height.
	for side in [-1,1]:
		for end in [-1,1]:
			Miniature.bevel_box(deck,Vector3(0.22,0.040,0.20),Vector3(side*0.65,-0.015,end*0.83),Color("#394a4a"),0.01)
	for side in [-1,1]:
		var column := point+Vector2(side*1.62,model.position.z+0.05)
		site.wall_rects.append(Rect2(column-Vector2(0.16,0.19),Vector2(0.32,0.38)))
	return {"carriage":carriage,"low_y":carriage.position.y,"scale_y":model.scale.y}

static func set_lift(nodes: Dictionary, height: float) -> void:
	nodes.carriage.position.y = nodes.low_y+height/nodes.scale_y

static func trolley(station: Node3D) -> void:
	var model := TROLLEY.instantiate() as Node3D
	model.name = "DesserteAtelier"
	model.rotation.y = PI/2
	model.scale = Vector3(0.87,0.87,0.87)
	station.add_child(model)

static func tire_rack(root: Node3D) -> void:
	fit(root,SHELF,Vector3(1.90,1.31,0.76))
	for x in [-0.61,0.0,0.61]:
		var tire := loose_tire(root,Vector3(x,0.50,0.17),Color.WHITE)
		tire.rotation = Vector3(PI/2.0,0,0)
		tire.scale = Vector3.ONE*0.73

static func dress_shop(site: Node3D) -> void:
	for z in range(1,17):
		Miniature.bevel_box(site,Vector3(6.67,0.005,0.022),Vector3(3.48,0.065,z),Color("#ae8970"),0.001)
	for z in [1.25,4.75,11.0,15.3]:
		Miniature.bevel_box(site,Vector3(5.60,0.007,0.027),Vector3(9.89,0.052,z),Color("#879395"),0.001)
		for bay in site.bays:
			Miniature.bevel_box(site,Vector3(2.55,0.007,0.027),Vector3(bay.at.x+3.0,0.052,z),Color("#879395"),0.001)
	add_light(site,Vector3(12.72,2.68,6.55),Color("#d8eafa"),0.51,6.0)
	for i in range(site.bays.size()):
		var bay: Dictionary = site.bays[i]
		add_light(site,Vector3(bay.at.x+2.63,2.68,9.43 if i%2==0 else 6.55),Color("#d8eafa"),0.56,6.5)
	add_light(site,Vector3(3.5,2.48,12.0),Color("#ffe0a9"),0.64,5.5)

static func add_light(parent: Node3D, point: Vector3, tint: Color, strength: float, reach: float) -> void:
	var fixture := fit(parent,LIGHT_BAR,Vector3(0.26,0.17,1.35),point,PI/2.0)
	for mesh in fixture.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.position = point+Vector3(0,-0.13,0)
	light.light_color = tint
	light.light_energy = strength
	light.omni_range = reach
	light.omni_attenuation = 1.4
	parent.add_child(light)

static func dress_bay(site: Node3D, point: Vector2) -> void:
	var root := Node3D.new()
	root.name = "FinitionsBaie"
	root.position = Vector3(point.x,0,point.y)
	site.add_child(root)
	var teal := Color("#72918c")
	for side in [-1,1]:
		for length in [-1,1]:
			Miniature.bevel_box(root,Vector3(0.48,0.012,2.16),Vector3(side*1.10,0.065,length*3.56),teal,0.01)
		for i in range(6):
			var stripe := Miniature.bevel_box(root,Vector3(0.28,0.012,0.075),
				Vector3(side*1.41,0.077,-2.45+i*0.15),Color("#ecc98d"),0.006)
			stripe.rotation.y = side*0.45
	for mark in [Vector3(-1.51,0.059,7.92),Vector3(1.52,0.059,-7.54)]:
		var cone := CONE.instantiate() as Node3D
		cone.position = mark
		cone.scale = Vector3.ONE*0.72
		root.add_child(cone)
	fit(root,FIRE_EXTINGUISHER,Vector3(0.25,0.64,0.30),Vector3(1.94,0.05,8.62))

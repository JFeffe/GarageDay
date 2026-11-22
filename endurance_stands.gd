extends Node3D

const Race := preload("res://endurance_race.gd")
const Meshes := preload("res://workshop_miniature.gd")
const Props := preload("res://workshop_neighborhood.gd")
const GarageCamera := preload("res://garage_camera.gd")
const GT_MODELS := ["res://assets/endurance/gt-avant.glb", "res://assets/endurance/gt4.glb"]
const CREAM := Color("#f7edd5")
const WALL := Color("#516d6b")
const INK := Color("#263d41")
const GOLD := Color("#f7c674")
const RED := Color("#c5664a")
const BOX := Vector3(0,0.055,4.15)
const GARAGE := Vector3(0,0.055,-5.9)
const PUMP := Vector2(2.9,0.17)
const TOOLS := [Vector2(5.05,-3.45),Vector2(6.75,-7.8)]
const CONTROL_POINT := Vector2(4.25,-8.0)
const CONTROL_IDLE := Color("#587b7a")
const CONTROL_WAIT := Color("#ffc06a")
const CONTROL_READY := Color("#79edaa")
const JACK_HOME := [Vector2(-4.25,0.10),Vector2(-3.15,0.10)]
const WALKABLE := Rect2(-15.8,-10.42,31.6,17.02)

var cars: Array[Node3D] = []
var animations: Array[AnimationPlayer] = []
var playing := ["", ""]
var bodies: Array[Node3D] = []
var body_height: Array[float] = []
var obstacles: Array[Rect2] = []
var jacks: Array[Node3D] = []
var hose: Array[MeshInstance3D] = []
var control_lights: Array[StandardMaterial3D] = []
var zoom := 0

func build() -> void:
	block(Vector3(36.7,0.62,27.95),Vector3(0,-0.357,2.48),Color("#607571"),0.12)
	block(Vector3(36.5,0.073,24.7),Vector3(0,-0.030,0.9),Color("#9da4a0"))
	block(Vector3(36.5,0.073,5.2),Vector3(0,-0.017,9.4),Color("#4a575c"))
	block(Vector3(36.5,0.073,3.75),Vector3(0,-0.018,14.5),Color("#3c4b50"))
	block(Vector3(21.7,0.07,9.15),Vector3(0,-0.009,-6.14),Color("#b9bdb0"))
	block(Vector3(36.5,0.072,3.02),Vector3(0,-0.008,0.12),Color("#75938a"))
	for x in [-7.4,-3.7,0.0,3.7,7.4]:
		paint(Vector2(x,-10.65),Vector2(x,-1.62),0.023,Color("#929b91"))
	for z in [-8.15,-5.25,-2.35]:
		paint(Vector2(-10.65,z),Vector2(10.65,z),0.023,Color("#929b91"))
	for marker in range(-18,18):
		paint(Vector2(marker+0.07,1.57),Vector2(marker+0.70,1.57),0.075,CREAM)
	build_garage()
	build_control_desk()
	build_lane()
	for i in range(2): add_gt(i)
	build_service_equipment()

func block(size: Vector3, at: Vector3, color: Color, bevel := 0.04) -> MeshInstance3D:
	return Meshes.bevel_box(self,size,at,color,bevel)

func paint(from: Vector2, to: Vector2, width: float, color: Color, y := 0.036) -> void:
	var middle := (from+to)/2.0
	var marking := block(Vector3(width,0.009,from.distance_to(to)),Vector3(middle.x,y,middle.y),color,0.001)
	marking.rotation.y = atan2(to.x-from.x,to.y-from.y)
	marking.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func arrow(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	paint(from,to,width,color)
	var direction := from.direction_to(to)
	for side in [-1,1]:
		paint(to-direction.rotated(side*0.54)*0.74,to,width,color)

func sign_text(message: String, at: Vector3, height: float, color: Color, on_floor := false) -> void:
	var label := Label3D.new()
	label.text = message
	label.position = at
	label.modulate = color
	label.outline_size = 0
	label.font_size = 56
	label.pixel_size = height/56.0
	if on_floor: label.rotation_degrees.x = -90.0
	add_child(label)

func wall(size: Vector3, at: Vector3) -> void:
	var footprint := Vector2(size.x,size.z)
	obstacles.append(Rect2(Vector2(at.x,at.z)-footprint/2.0,footprint))
	block(size,at,WALL,0.07)
	block(Vector3(size.x+0.04,0.11,size.z+0.04),at+Vector3(0,size.y/2,0),CREAM)
	block(Vector3(size.x+0.015,0.20,size.z+0.015),Vector3(at.x,0.14,at.z),INK)

func build_garage() -> void:
	wall(Vector3(21.85,1.92,0.30),Vector3(0,0.95,-10.75))
	for side in [-1,1]:
		wall(Vector3(0.28,1.92,9.4),Vector3(side*10.84,0.95,-6.1))
		wall(Vector3(5.75,1.92,0.31),Vector3(side*8.04,0.95,-1.42))
		block(Vector3(0.49,2.39,0.62),Vector3(side*5.05,1.18,-1.38),INK)
		for notch in range(4):
			var hazard := block(Vector3(0.20,0.115,0.022),Vector3(side*5.05,0.32+notch*0.165,-1.054),GOLD,0.009)
			hazard.rotation.z = -0.34
		Props.fit(self,Props.LIGHT_BAR,Vector3(2.4,0.12,0.25),Vector3(side*6.3,1.63,-10.42))
	Props.fit(self,Props.SHUTTER,Vector3(9.85,0.39,0.28),Vector3(0,2.04,-1.44))
	block(Vector3(5.05,0.68,0.17),Vector3(0,2.36,-1.22),INK)
	sign_text("GARAGE DAY",Vector3(0,2.36,-1.12),0.48,CREAM)
	for x in [-3.1,3.1]: paint(Vector2(x,-8.5),Vector2(x,-1.6),0.083,CREAM)
	paint(Vector2(-3.1,-8.5),Vector2(3.1,-8.5),0.083,CREAM)
	for x in [-8.85,-6.45]:
		var shelf := Node3D.new()
		shelf.position = Vector3(x,0.034,-7.35)
		add_child(shelf)
		Props.tire_rack(shelf)
	for i in range(3):
		for y in [0.17,0.48,0.79]:
			Props.loose_tire(self,Vector3(-9.15+0.94*i,y,-4.74),CREAM).rotation = Vector3.ZERO
	Props.fit(self,Props.CABINET,Vector3(1.12,1.14,0.85),Vector3(-9.15,0.03,-9.72),PI)
	Props.fit(self,Props.STATION_MODELS.bench,Vector3(3.32,1.20,1.0),Vector3(6.75,0.03,-8.94))
	Props.fit(self,Props.CABINET,Vector3(1.28,1.05,0.92),Vector3(9.65,0.03,-9.22),PI)
	Props.fit(self,Props.COMPRESSOR,Vector3(1.31,0.99,0.65),Vector3(9.12,0.03,-4.8))
	Props.fit(self,Props.TROLLEY,Vector3(0.86,1.02,0.71),Vector3(6.2,0.03,-3.42),-0.24)
	Props.fit(self,Props.FIRE_EXTINGUISHER,Vector3(0.36,0.83,0.33),Vector3(5.52,0.03,-0.73))
	sign_text("PNEUS",Vector3(-7.45,0.038,-3.89),0.51,INK,true)
	sign_text("OUTILS",Vector3(7.44,0.038,-6.15),0.51,INK,true)
	for footprint in [Rect2(-10.05,-8.0,4.65,1.15),Rect2(-9.7,-5.2,2.95,0.93),
		Rect2(4.7,-9.5,3.7,1.15),Rect2(8.47,-5.28,1.26,0.88),Rect2(5.78,-3.87,0.85,0.83)]:
		obstacles.append(footprint)
	for x in [-5.82,6.0]:
		Props.fit(self,Props.CONE,Vector3(0.46,0.65,0.46),Vector3(x,0.035,1.96))

func build_control_desk() -> void:
	var x := CONTROL_POINT.x-0.57
	var z := -9.63
	block(Vector3(3.42,0.015,3.40),Vector3(x,0.037,-8.70),Color("#718a80"),0.01)
	for edge in [x-1.71,x+1.71]:
		paint(Vector2(edge,-10.38),Vector2(edge,-7.0),0.063,CREAM,0.054)
	paint(Vector2(x-1.71,-7.0),Vector2(x+1.71,-7.0),0.063,CREAM,0.054)
	sign_text("CONTRÔLE",Vector3(x,0.058,-7.34),0.38,CREAM,true)
	block(Vector3(3.10,0.15,0.86),Vector3(x,0.94,z),Color("#bf936d"),0.06)
	for side in [-1,1]:
		block(Vector3(0.14,0.87,0.69),Vector3(x+side*1.40,0.50,z),INK)
	block(Vector3(2.91,0.28,0.12),Vector3(x,0.74,z+0.372),INK)
	sign_text("CONTRÔLE COURSE",Vector3(x,0.74,z+0.436),0.22,CREAM)
	Props.fit(self,Props.STATION_MODELS.seat,Vector3(1.21,0.65,0.46),Vector3(x-0.94,0.040,-8.12),PI/2.0)
	obstacles.append(Rect2(x-1.65,z-0.52,3.30,1.04))
	obstacles.append(Rect2(x-1.21,-8.86,0.54,1.45))
	for i in range(3):
		var screen_x := x+(i-1)*0.96
		block(Vector3(0.33,0.04,0.29),Vector3(screen_x,1.03,z),INK,0.02)
		block(Vector3(0.11,0.18,0.10),Vector3(screen_x,1.13,z),INK,0.02)
		block(Vector3(0.82,0.51,0.15),Vector3(screen_x,1.45,z),INK)
		block(Vector3(0.72,0.40,0.022),Vector3(screen_x,1.46,z+0.081),Color("#37696a"),0.014)
		sign_text(["GT 27","TEMPS","GT 81"][i],Vector3(screen_x,1.55,z+0.096),0.13,CREAM)
		for line in range(2):
			block(Vector3(0.23+line*0.12,0.022,0.006),Vector3(screen_x-0.11,1.36+line*0.058,z+0.095),Color("#8fbdb4"),0.002)
		if i!=1:
			var light := block(Vector3(0.076,0.076,0.022),Vector3(screen_x+0.21,1.40,z+0.096),CONTROL_IDLE,0.014)
			var material := light.material_override as StandardMaterial3D
			material.emission_enabled = true
			material.emission = CONTROL_IDLE
			control_lights.append(material)
	block(Vector3(0.45,0.037,0.19),Vector3(CONTROL_POINT.x,1.033,z+0.28),INK,0.012)

func update_control_lights(race: Race) -> void:
	for i in range(control_lights.size()):
		var car := race.cars[i]
		var color := CONTROL_IDLE
		if release_available(race,i): color = CONTROL_READY
		elif car.called or car.state in [Race.State.ENTRY,Race.State.QUEUE,Race.State.BOX,Race.State.GARAGE]:
			color = CONTROL_WAIT
		var light := control_lights[i]
		if light.albedo_color!=color:
			light.albedo_color = color
			light.emission = color

func release_available(race: Race, index: int) -> bool:
	var car := race.cars[index]
	return race.allowed(car,"exit") and ready_for_work(index,car)

func build_lane() -> void:
	block(Vector3(8.72,0.027,4.15),Vector3(0,0.021,4.27),Color("#747e7d"))
	for z in [2.15,6.4]: paint(Vector2(-4.45,z),Vector2(4.45,z),0.103,GOLD,0.049)
	for x in [-4.45,4.45]: paint(Vector2(x,2.15),Vector2(x,6.4),0.086,GOLD,0.049)
	var entry := Curve2D.new()
	entry.add_point(Vector2(-16.5,8.43),Vector2.ZERO,Vector2(3.0,0.0))
	entry.add_point(Vector2(-5.14,4.28),Vector2(-3.05,0.0))
	var exit := Curve2D.new()
	exit.add_point(Vector2(5.14,4.28),Vector2.ZERO,Vector2(3.0,0.0))
	exit.add_point(Vector2(16.5,8.43),Vector2(-3.05,0.0))
	for curve: Curve2D in [entry,exit]:
		var length := curve.get_baked_length()
		var cursor := 0.0
		while cursor+1.7<length:
			paint(curve.sample_baked(cursor),curve.sample_baked(cursor+0.75),0.112,CREAM)
			cursor += 1.25
		arrow(curve.sample_baked(length-1.05),curve.sample_baked(length),0.112,CREAM)
	paint(Vector2(-18.24,6.81),Vector2(18.24,6.81),0.093,CREAM)
	paint(Vector2(-18.24,11.95),Vector2(18.24,11.95),0.10,CREAM)
	for x in [-15.4,12.6]: arrow(Vector2(x,10.37),Vector2(x+2.55,10.37),0.15,CREAM)
	sign_text("VOIE DES STANDS",Vector3(0,0.047,10.02),0.83,CREAM,true)
	block(Vector3(36.45,0.70,0.55),Vector3(0,0.34,12.64),Color("#9ca6a0"),0.06)
	for x in range(-18,18):
		block(Vector3(0.98,0.12,0.59),Vector3(x+0.5,0.71,12.64),RED if x%2==0 else CREAM,0.018)
	for x in range(-18,18,3): paint(Vector2(x,14.38),Vector2(x+1.75,14.38),0.105,Color("#a0afab"))

func add_gt(index: int) -> void:
	var car := Node3D.new()
	add_child(car)
	cars.append(car)
	var asset := load(GT_MODELS[index]) as PackedScene
	var scene := Props.fit(car,asset,Vector3(2.16,1.36,4.85))
	bodies.append(scene)
	body_height.append(scene.position.y)
	var matching := scene.find_children("*","AnimationPlayer",true,false)
	animations.append(matching[0] if not matching.is_empty() else null)
	var color := Color("#b94b28") if index==0 else Color("#187f91")
	var paint_material := Meshes.material(color,0.34,0.22)
	for mesh: MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i)
			if material!=null and material.resource_name=="paint": mesh.set_surface_override_material(i,paint_material)
	var badge := Label3D.new()
	badge.text = str(Race.CARS[index][0])
	badge.position = Vector3(0,1.63,0)
	badge.modulate = Color(Race.CARS[index][5])
	badge.outline_modulate = INK
	badge.outline_size = 9
	badge.pixel_size = 0.013
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	car.add_child(badge)

func change_zoom(step: int) -> void:
	zoom = clampi(zoom+step,0,GarageCamera.ZOOM_SIZES.size())

func frame(camera: Camera3D, player: Vector2, partner: Vector2, blend: float) -> void:
	var ratio := GarageCamera.aspect(camera)
	var center := Vector2(0,2.48)
	var view_size := GarageCamera.overview_size(Vector2(36.7,27.95),ratio)
	if zoom>0:
		center = player
		view_size = GarageCamera.ZOOM_SIZES[zoom-1]
		if partner!=Vector2.INF:
			view_size = GarageCamera.fit_pair(view_size,player-partner,ratio)
			center = player.lerp(partner,0.5)
	GarageCamera.place(camera,center,view_size,blend)

func build_service_equipment() -> void:
	obstacles.append(Rect2(PUMP-Vector2(0.45,0.34),Vector2(0.9,0.68)))
	block(Vector3(0.85,0.18,0.66),Vector3(PUMP.x,0.13,PUMP.y),INK)
	block(Vector3(0.69,1.04,0.54),Vector3(PUMP.x,0.69,PUMP.y),RED)
	block(Vector3(0.62,0.18,0.48),Vector3(PUMP.x,1.23,PUMP.y),CREAM)
	block(Vector3(0.46,0.06,0.27),Vector3(PUMP.x,1.34,PUMP.y),INK)
	block(Vector3(0.20,0.055,0.12),Vector3(PUMP.x,1.37,PUMP.y),Color("#9adcc1"))
	sign_text("POMPE",Vector3(PUMP.x,0.049,PUMP.y+0.77),0.43,INK,true)
	sign_text("CRICS",Vector3(-3.66,0.049,1.0),0.43,INK,true)
	for i in range(2):
		var jack := Node3D.new()
		add_child(jack)
		jacks.append(jack)
		Meshes.bevel_box(jack,Vector3(0.49,0.14,0.83),Vector3(0,0.14,0),GOLD)
		Meshes.cylinder(jack,0.16,0.22,Vector3(0,0.25,0.19),INK,14)
		var handle := Meshes.cylinder(jack,0.035,0.97,Vector3(0,0.16,-0.77),INK,12)
		handle.rotation.x = PI/2.0
		for x in [-0.23,0.23]:
			Meshes.cylinder(jack,0.09,0.09,Vector3(x,0.10,-0.28),INK,10).rotation.z = PI/2.0
	for i in range(3):
		var line := Meshes.cylinder(self,0.043,1.0,Vector3.ZERO,INK,10)
		line.hide()
		hose.append(line)

func parked_center(car: Dictionary) -> Vector2:
	var center := GARAGE if car.state==Race.State.GARAGE else BOX
	return Vector2(center.x,center.z)

func local_service_point(car: Dictionary, offset: Vector2) -> Vector2:
	var origin := parked_center(car)
	return origin+offset.rotated(PI if car.state==Race.State.GARAGE else -PI/2.0)

func ready_for_work(index: int, car: Dictionary) -> bool:
	if car.state not in [Race.State.BOX,Race.State.GARAGE]: return false
	var model := cars[index]
	return Vector2(model.position.x,model.position.z).distance_to(parked_center(car))<0.37 and \
		absf(angle_difference(model.rotation.y,PI if car.state==Race.State.GARAGE else PI/2.0))<0.22

func walkable(point: Vector2, race: Race) -> bool:
	if not WALKABLE.has_point(point): return false
	for wall_area in obstacles:
		if wall_area.grow(0.24).has_point(point): return false
	for i in range(2):
		var car := race.cars[i]
		if car.state not in [Race.State.BOX,Race.State.GARAGE,Race.State.QUEUE,Race.State.ENTRY,Race.State.EXIT]: continue
		var model := cars[i]
		var offset := (point-Vector2(model.position.x,model.position.z)).rotated(model.rotation.y)
		if absf(offset.x)<1.29 and absf(offset.y)<2.60: return false
	return true

func update_cars(race: RefCounted, dt: float) -> void:
	for i in range(2):
		var car: Dictionary = race.cars[i]
		var model := cars[i]
		var point := BOX
		var yaw := PI/2.0
		var visible_on_track: bool = car.state==Race.State.TRACK and fposmod(car.distance+0.035,1.0)<0.073
		model.visible = race.phase==Race.Phase.GRID or visible_on_track or car.state in [Race.State.ENTRY,
			Race.State.QUEUE,Race.State.BOX,Race.State.GARAGE,Race.State.EXIT]
		if race.phase==Race.Phase.GRID:
			point = Vector3(-2.8+5.6*i,0.055,8.55)
		elif visible_on_track:
			point = Vector3(lerpf(-18.0,18.0,fposmod(car.distance+0.035,1.0)/0.073),0.05,14.2+0.8*i)
		elif car.state==Race.State.ENTRY:
			var approach := clampf(1.0-car.timer/Race.ENTRY_TIME,0.0,1.0)
			point = Vector3(lerpf(-18.0,-7.9,approach),0.055,lerpf(8.1,6.05,smoothstep(0.2,1.0,approach)))
		elif car.state==Race.State.QUEUE:
			point = Vector3(-7.9,0.055,6.05)
		elif car.state==Race.State.GARAGE:
			point = GARAGE
			yaw = PI
		elif car.state==Race.State.EXIT:
			var progress := clampf(1.0-car.timer/Race.EXIT_TIME,0.0,1.0)
			if car.exit_from==Race.State.GARAGE and progress<0.46:
				point = GARAGE.lerp(Vector3(0,0.055,0.5),progress/0.46)
				yaw = 0.0
			elif car.exit_from==Race.State.GARAGE:
				var merge := (progress-0.46)/0.54
				point = Vector3(lerpf(0.0,18.0,merge),0.055,lerpf(0.5,9.6,smoothstep(0.34,1.0,merge)))
			else:
				point = Vector3(lerpf(0.0,18.0,progress),0.055,lerpf(4.15,9.6,progress))
		if not model.visible or dt==0.0 or visible_on_track or model.position.distance_squared_to(point)>200.0:
			model.position = point
		else:
			model.position = model.position.lerp(point,1.0-exp(-dt*3.9))
		model.rotation.y = lerp_angle(model.rotation.y,yaw,1.0 if dt==0.0 else 1.0-exp(-dt*6.0))
		var lift := Vector2(float(race.jack_owners[0]==i),float(race.jack_owners[1]==i))
		bodies[i].position.y = lerpf(bodies[i].position.y,body_height[i]+0.16*(lift.x+lift.y),1.0 if dt==0.0 else minf(1.0,dt*7.0))
		bodies[i].rotation.x = lerpf(bodies[i].rotation.x,(lift.y-lift.x)*0.09,1.0 if dt==0.0 else minf(1.0,dt*7.0))
		var pose := "bonnet-open" if car.jobs.has("repair") else "doors-open" if car.jobs.has("driver") else ""
		update_pose(i,pose)
	update_equipment(race)

func update_equipment(race: Race) -> void:
	for axle in range(2):
		var owner: int = race.jack_owners[axle]
		var point: Vector2 = JACK_HOME[axle]
		var yaw := 0.0
		if owner>=0:
			point = local_service_point(race.cars[owner],Vector2(0.0,2.36 if axle==0 else -2.36))
			yaw = cars[owner].rotation.y+(PI if axle==0 else 0.0)
		jacks[axle].position = Vector3(point.x,0.04,point.y)
		jacks[axle].rotation.y = yaw
	for line in hose: line.hide()
	for i in range(2):
		if not race.cars[i].jobs.has("fuel"): continue
		var socket := local_service_point(race.cars[i],Vector2(-1.05,-1.1))
		var points := [Vector3(PUMP.x,0.83,PUMP.y),Vector3(PUMP.x-0.45,0.11,PUMP.y+signf(socket.y-PUMP.y)*0.65),
			Vector3(socket.x-0.33,0.09,socket.y),Vector3(socket.x,0.70,socket.y)]
		for k in range(hose.size()):
			var from: Vector3 = points[k]
			var to: Vector3 = points[k+1]
			hose[k].position = (from+to)/2.0
			hose[k].quaternion = Quaternion(Vector3.UP,from.direction_to(to))
			hose[k].scale.y = from.distance_to(to)+0.05
			hose[k].show()

func update_pose(index: int, pose: String) -> void:
	var animation := animations[index]
	if animation==null or pose==playing[index]: return
	if playing[index]!="" and animation.has_animation(playing[index]):
		animation.seek(0.0,true)
		animation.stop()
	playing[index] = pose
	if pose!="" and animation.has_animation(pose): animation.play(pose)

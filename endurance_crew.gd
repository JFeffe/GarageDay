extends Node3D

const Race := preload("res://endurance_race.gd")
const Stands := preload("res://endurance_stands.gd")
const Visual := preload("res://player_visual.gd")
const Props := preload("res://workshop_neighborhood.gd")
const Meshes := preload("res://workshop_miniature.gd")
const SPAWN := [Vector2(-4.25,-4.0),Vector2(4.25,-4.0)]
const REACH := 1.26
const SPEED := 6.1

var stands: Stands
var race: Race
var workers: Array[Dictionary] = []
var markers: Array[MeshInstance3D] = []
var guest_present := false

func build(game: Node3D, site: Stands, session: Race) -> void:
	stands = site
	race = session
	for i in range(2):
		var avatar := Node3D.new()
		add_child(avatar)
		var visual := Visual.new()
		visual.build(game,avatar)
		var wrench := Node3D.new()
		wrench.position = Vector3(0.17,0.72,0.36)
		avatar.add_child(wrench)
		Props.impact_wrench(wrench)
		var nozzle := Meshes.bevel_box(avatar,Vector3(0.11,0.12,0.38),Vector3(-0.17,0.95,0.40),Color("#c57652"),0.03)
		var caption := Label3D.new()
		caption.text = "J%d" % (i+1)
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.position = Vector3(0,1.58,0.55)
		caption.font_size = 34
		caption.pixel_size = 0.012
		caption.outline_size = 8
		caption.modulate = Color("#f9db9b") if i==0 else Color("#a8edf5")
		avatar.add_child(caption)
		workers.append({"avatar":avatar,"visual":visual,"wrench":wrench,"nozzle":nozzle})
	for i in range(18):
		var marker := Meshes.cylinder(self,0.15,0.021,Vector3.ZERO,Color("#ffd787"),16)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.hide()
		markers.append(marker)
	reset()

func reset() -> void:
	for i in range(2):
		var worker := workers[i]
		worker.point = SPAWN[i]
		worker.held = ""
		worker.aim = Vector2.DOWN
		worker.target = {}
		worker.options = []
		worker.progress = 0.0
		worker.latched = false
		worker.avatar.position = Vector3(SPAWN[i].x,0.08,SPAWN[i].y)
		worker.avatar.rotation.y = 0.0
		worker.avatar.visible = i==0
		worker.wrench.hide()
		worker.nozzle.hide()
	guest_present = false
	for marker in markers: marker.hide()

func tick(dt: float, clock_rate: float, move: Vector2, use: bool, guest: Array, guest_can_work: bool) -> void:
	var online: bool = guest.size()==9 and guest[0]==true
	if not online and guest_present:
		workers[1].held = ""
		workers[1].target = {}
		workers[1].options = []
		workers[1].progress = 0.0
		workers[1].latched = false
	guest_present = online
	workers[1].avatar.visible = online
	move_worker(0,dt,clock_rate,move,use)
	if online:
		var input := Vector2(float(guest[1]),float(guest[2])) if guest_can_work else Vector2.ZERO
		move_worker(1,dt,clock_rate,input,guest_can_work and ((int(guest[5]) | int(guest[8])) & 4)!=0)
	update_markers()

func move_worker(index: int, dt: float, clock_rate: float, input: Vector2, use: bool) -> void:
	var worker := workers[index]
	var origin: Vector2 = worker.point
	if not stands.walkable(worker.point,race): worker.point = clear_point(worker.point)
	var movement := input.limit_length()*dt*SPEED
	for delta in [Vector2(movement.x,0),Vector2(0,movement.y)]:
		if stands.walkable(worker.point+delta,race): worker.point += delta
	var aim: Vector2 = input.normalized() if input.length()>0.15 else worker.aim
	worker.options = station_options(index)
	var option := nearby(worker.point,worker.options)
	if not use: worker.latched = false
	if option!=worker.target or option.is_empty() or not use or movement.length()>0.025:
		worker.progress = 0.0
	worker.target = option
	if use and not worker.latched and not option.is_empty() and movement.length()<=0.025:
		worker.progress += dt*clock_rate
		var facing: Vector2 = worker.point.direction_to(option.point)
		if not facing.is_zero_approx(): aim = facing
		if worker.progress+0.0001>=option.duration:
			complete(index,option)
			worker.latched = true
			worker.progress = 0.0
	worker.aim = aim
	worker.avatar.position = Vector3(worker.point.x,0.08,worker.point.y)
	worker.avatar.rotation.y = atan2(aim.x,aim.y)
	worker.nozzle.visible = worker.held=="nozzle"
	worker.wrench.visible = worker.held=="wrench"
	var speed: float = origin.distance_to(worker.point)/maxf(0.001,dt)
	worker.visual.animate(dt,minf(speed,SPEED),worker.held!="")
	if worker.progress>0.0:
		worker.visual.reach(0,Vector3(0.19,0.74,0.48),0.9)
		worker.visual.reach(1,Vector3(-0.19,0.75,0.49),0.8)

func clear_point(origin: Vector2) -> Vector2:
	for radius in [0.6,1.2,1.8,2.4,3.0,4.2]:
		for i in range(8):
			var point: Vector2 = origin+Vector2.RIGHT.rotated(TAU*i/8.0)*radius
			if stands.walkable(point,race): return point
	return SPAWN[0]

func station_options(index: int) -> Array[Dictionary]:
	var work: Array[Dictionary] = []
	if race.phase!=Race.Phase.RACE: return work
	var worker := workers[index]
	if (not guest_present and index==0) or workers[1-index].held!="nozzle":
		work.append(target(-1,"nozzle",Stands.PUMP+Vector2(0.71,0.15),
			"Reposer le pistolet" if worker.held=="nozzle" else "Prendre le pistolet de la pompe",2.0))
	for point in Stands.TOOLS:
		work.append(target(-1,"wrench",point,"Reposer la clé" if worker.held=="wrench" else "Prendre la clé de réparation",2.0))
	for i in range(2):
		var car := race.cars[i]
		if not stands.ready_for_work(i,car): continue
		if worker.held=="nozzle" and race.manual_needed(i,"fuel") and race.can_start(i,"fuel"):
			work.append(target(i,"fuel",stands.local_service_point(car,Vector2(-1.57,-1.0)),"Brancher le pistolet",4.0))
		if worker.held=="wrench" and race.manual_needed(i,"repair"):
			work.append(target(i,"repair",stands.local_service_point(car,Vector2(-1.61,1.65)),"Réparer avec la clé",16.0 if car.state==Race.State.GARAGE else 10.0))
		if race.manual_needed(i,"driver"):
			work.append(target(i,"driver",stands.local_service_point(car,Vector2(1.62,-0.04)),"Faire la relève",8.0))
		if race.manual_needed(i,"tires"): tire_options(work,i,car)
		if race.allowed(car,"exit"):
			work.append(target(i,"exit",stands.local_service_point(car,Vector2(1.62,-0.04)),"Faire repartir la GT",3.0))
	return work

func tire_options(work: Array[Dictionary], index: int, car: Dictionary) -> void:
	for axle in range(2):
		var end := 1.0 if axle==0 else -1.0
		var label := "avant" if axle==0 else "arrière"
		var stage: int = car.axles[axle]
		if (stage==-1 and race.jack_owners[axle]==-1) or stage==3:
			var title := "Lever le train %s" if stage==-1 else "Abaisser le train %s"
			work.append(target(index,"tires",stands.local_service_point(car,Vector2(0.0,2.96*end)),title%label,3.3,axle))
		if stage not in [0,1,2]: continue
		for wheel in range(2):
			if (stage & (1<<wheel))!=0: continue
			var side := -1.0 if wheel==0 else 1.0
			work.append(target(index,"tires",stands.local_service_point(car,Vector2(side*1.55,1.60*end)),"Changer le pneu %s %s" % [label,"gauche" if wheel==0 else "droit"],4.0,axle,wheel))

func target(index: int, action: String, point: Vector2, title: String, duration: float, axle := -1, wheel := -1) -> Dictionary:
	return {"car":index,"action":action,"point":point,"title":title,"duration":duration,"axle":axle,"wheel":wheel}

func nearby(point: Vector2, options: Array) -> Dictionary:
	var closest := REACH*REACH
	var result := {}
	for option in options:
		var distance: float = point.distance_squared_to(option.point)
		if distance<closest:
			closest = distance
			result = option
	return result

func complete(index: int, option: Dictionary) -> void:
	var worker := workers[index]
	if option.car<0:
		worker.held = "" if worker.held==option.action else option.action
		return
	if option.action=="exit":
		race.perform(option.car,"exit")
		return
	if race.manual_action(option.car,option.action,option.axle,option.wheel):
		if option.action=="fuel": worker.held = ""

func update_markers() -> void:
	var shown := {}
	var count := 0
	for index in range(2 if guest_present else 1):
		for option in workers[index].options:
			if count>=markers.size() or shown.has(option.point): continue
			shown[option.point] = true
			markers[count].position = Vector3(option.point.x,0.067,option.point.y)
			markers[count].show()
			count += 1
	for i in range(count,markers.size()): markers[i].hide()

func instruction(index: int) -> String:
	var worker := workers[index]
	var held := " · Pistolet en main" if worker.held=="nozzle" else " · Clé en main" if worker.held=="wrench" else ""
	if worker.target.is_empty(): return "J%d · Déplace-toi vers un repère%s" % [index+1,held]
	var prefix := "N° %d · " % race.cars[worker.target.car].number if worker.target.car>=0 else ""
	return "J%d · Maintiens A / F · %s%s%s" % [index+1,prefix,worker.target.title,held]

func progress(index: int) -> float:
	var worker := workers[index]
	return 100.0*worker.progress/worker.target.duration if not worker.target.is_empty() else 0.0

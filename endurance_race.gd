extends RefCounted

enum Phase { GRID, RACE, FINISH }
enum State { TRACK, ENTRY, QUEUE, BOX, GARAGE, EXIT, OUT }
enum Mode { SKIP, MANUAL, AUTO }

const DURATION := 12 * 3600.0
const ENTRY_TIME := 24.0
const EXIT_TIME := 20.0
const BASE_RATE := 24.0
const PIT_RATE := 5.0
const PACE_NAMES := ["Économie", "Normal", "Attaque"]
const SERVICES := ["fuel", "tires", "driver", "repair"]
const AUTO_TIME := {"fuel": 60.0, "tires": 150.0, "driver": 43.0, "repair": 78.0}
const MANUAL_TIME := {"fuel": 19.0, "repair": 25.0}
const TEAM := "Garage Day"
const CARS := [
	[27, TEAM, 125.0, "Maya Roy", "Louis Vega", "#f5a168"],
	[81, TEAM, 125.4, "Nora Chen", "Émile Cruz", "#83d8dd"],
	[14, "Vallon Racing", 125.4, "R. Ellis", "F. Royer", "#bfc8d1"],
	[18, "Vallon Racing", 126.9, "A. Moss", "P. King", "#bfc8d1"],
	[42, "Apex Nord", 124.6, "G. Hart", "L. Zane", "#e5bb72"],
	[46, "Apex Nord", 127.1, "D. Cruz", "S. Kim", "#e5bb72"],
	[63, "Écurie Silex", 125.3, "J. Fox", "E. Alba", "#a4c58d"],
	[68, "Écurie Silex", 126.6, "N. Watt", "S. Xu", "#a4c58d"],
	[91, "Delta Sport", 126.3, "T. Tate", "K. Park", "#ccacd5"],
	[96, "Delta Sport", 127.9, "M. Bell", "H. Ito", "#ccacd5"],
]

var phase := Phase.GRID
var elapsed := 0.0
var fraction := 0.0
var speed_up := false
var cars: Array[Dictionary] = []
var radio: Array[String] = []
var random := RandomNumberGenerator.new()
var next_team_incident := 0.0
var next_rival_incident := 0.0
var jack_owners: Array[int] = [-1,-1]

func setup(seed_value: int) -> void:
	random.seed = seed_value
	phase = Phase.GRID
	elapsed = 0.0
	fraction = 0.0
	speed_up = false
	cars.clear()
	radio.clear()
	jack_owners = [-1,-1]
	for i in CARS.size():
		var spec: Array = CARS[i]
		var first_stop := 2780.0 + 440.0 * i if i<2 else random.randf_range(2650.0,3400.0)
		var pace := 2 if i in [4,5] else 0 if i in [6,7] else 1
		cars.append({
			"number": spec[0], "team": spec[1], "base_lap": spec[2], "drivers": [spec[3], spec[4]],
			"color": Color(spec[5]), "ours": i<2, "driver": 0, "fatigue": [0.0, 0.0],
			"distance": -0.0015 * i, "fuel": 1.0, "tires": 1.0, "damage": 0.0, "pace": pace,
			"state": State.TRACK, "timer": 0.0, "called": false, "planned": first_stop, "exit_from": State.BOX,
			"orders": {}, "jobs": {}, "done": {}, "axles": [-1,-1], "garage_stop": false, "stops": 0,
			"queue_time": 0.0, "lap_variation": 0.0, "last_lap_time": 0.0,
		})
	next_team_incident = random.randf_range(1700.0,2350.0)
	next_rival_incident = random.randf_range(700.0,1200.0)

func start() -> void:
	if phase!=Phase.GRID: return
	phase = Phase.RACE
	announce("Drapeau vert. Les deux GT sont en piste.")

func announce(message: String) -> void:
	radio.push_front("%s  %s" % [clock(), message])
	if radio.size()>5: radio.pop_back()

func clock() -> String:
	var minutes := 8 * 60 + floori(elapsed / 60.0)
	return "%02d:%02d" % [floori(minutes / 60.0), minutes % 60]

static func time_left(seconds: float) -> String:
	var whole := maxi(0, ceili(seconds))
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]

func rate() -> float:
	for car in cars.slice(0,2):
		if car.state in [State.BOX, State.GARAGE, State.QUEUE, State.ENTRY]: return PIT_RATE
		if car.state==State.TRACK and car.called and seconds_to_line(car)<21.0: return PIT_RATE
	return BASE_RATE * (2.0 if speed_up else 1.0)

func advance(seconds: float) -> void:
	if phase!=Phase.RACE: return
	fraction += maxf(0.0,seconds)
	while fraction>=1.0 and phase==Phase.RACE:
		fraction -= 1.0
		step()

func step() -> void:
	elapsed += 1.0
	for car in cars:
		match car.state:
			State.TRACK: drive(car)
			State.ENTRY:
				car.timer -= 1.0
				if car.timer<=0.0: arrive(car)
			State.BOX, State.GARAGE:
				if car.ours: work_on_car(car)
				else: rival_service(car)
			State.EXIT:
				car.timer -= 1.0
				if car.timer<=0.0:
					car.state = State.TRACK
					car.last_lap_time = elapsed
		if car.state!=State.OUT:
			var spare: int = 1-car.driver
			car.fatigue[spare] = maxf(0.0,car.fatigue[spare]-1.15)
	assign_stands()
	if elapsed>=next_team_incident:
		incident(0,2)
		next_team_incident += random.randf_range(2800.0,4600.0)
	if elapsed>=next_rival_incident:
		incident(2,cars.size())
		next_rival_incident += random.randf_range(1150.0,2350.0)
	if elapsed>=DURATION:
		phase = Phase.FINISH
		announce("Drapeau à damier. Le classement est figé.")

func incident(first: int, end: int) -> void:
	var candidates: Array[Dictionary] = []
	for i in range(first,end):
		if cars[i].state==State.TRACK: candidates.append(cars[i])
	if candidates.is_empty(): return
	var car: Dictionary = candidates[random.randi_range(0,candidates.size()-1)]
	var hit := random.randf_range(0.15,0.59) + (0.07 if car.pace==2 else 0.0)
	car.damage = minf(0.94,car.damage+hit)
	if car.ours:
		announce("N° %d · accrochage (%d %% de dégâts). %s" % [car.number,roundi(car.damage*100),
			"Prévois un passage au garage." if car.damage>=0.38 else "Réparation possible au box."])
	else:
		announce("N° %d · %s signale un accrochage." % [car.number,car.team])

func seconds_to_line(car: Dictionary) -> float:
	return (1.0-fposmod(car.distance,1.0))*lap_seconds(car)

func lap_seconds(car: Dictionary) -> float:
	var worn := (1.0-float(car.tires))*7.5
	var tired := clampf((float(car.fatigue[car.driver])-2600.0)/960.0,0.0,12.0)
	return float(car.base_lap)+float(car.lap_variation)+worn+tired+float(car.damage)*43.0+[4.5,0.0,-3.2][car.pace]

func fuel_burn(car: Dictionary) -> float:
	return [0.84,1.0,1.18][car.pace]/4300.0

func drive(car: Dictionary) -> void:
	var previous := floori(car.distance)
	car.distance += 1.0/lap_seconds(car)
	car.fuel -= fuel_burn(car)
	car.tires = maxf(0.04,car.tires-[0.80,1.0,1.28][car.pace]/6400.0)
	car.fatigue[car.driver] += 1.0
	if not car.ours and (car.fuel<0.14 or car.damage>0.25): car.called = true
	if not car.called and elapsed>=car.planned:
		car.called = true
		if car.ours: announce("N° %d · arrêt prévu, confirme les interventions." % car.number)
	if car.fuel<=0.0:
		car.fuel = 0.0
		car.state = State.OUT
		announce("N° %d · abandon, panne d’essence." % car.number)
		return
	if floori(car.distance)<=previous: return
	car.lap_variation = random.randf_range(-1.9,1.9)
	if car.called:
		car.distance = floorf(car.distance)
		car.state = State.ENTRY
		car.timer = ENTRY_TIME
		if car.ours: announce("N° %d · entrée dans la voie des stands." % car.number)
	elif car.last_lap_time>0.0 and car.fuel<0.15 and car.ours:
		if floori(car.distance)%3==0: announce("N° %d · essence basse. Appelle la GT au box." % car.number)
	car.last_lap_time = elapsed

func arrive(car: Dictionary) -> void:
	car.done.clear()
	car.axles = [-1,-1]
	car.called = false
	car.stops += 1
	if car.ours:
		car.state = State.QUEUE
		car.queue_time = elapsed
	else:
		car.state = State.BOX
		car.timer = 73.0 + float(car.damage)*385.0 + random.randf_range(-6.0,12.0)

func assign_stands() -> void:
	for destination in [State.BOX, State.GARAGE]:
		assign_place(destination)

func assign_place(destination: int) -> void:
	if cars[0].state==destination or cars[1].state==destination: return
	var waiting := {}
	for car in cars.slice(0,2):
		if car.state!=State.QUEUE or car.garage_stop!=(destination==State.GARAGE): continue
		if waiting.is_empty() or car.queue_time<waiting.queue_time: waiting = car
	if waiting.is_empty(): return
	waiting.state = destination
	announce("N° %d · %s." % [waiting.number,"au garage" if destination==State.GARAGE else "au box"])

func rival_service(car: Dictionary) -> void:
	car.timer -= 1.0
	if car.timer>0.0: return
	car.fuel = 1.0
	car.tires = 1.0
	car.damage = maxf(0.0,car.damage-0.84)
	car.driver = 1-car.driver
	leave(car)

func work_on_car(car: Dictionary) -> void:
	var index := cars.find(car)
	for action in car.jobs.keys():
		var job: Dictionary = car.jobs[action]
		job.left -= 1.0
		if job.left<=0.0: finish_service(index,action)
	for action in SERVICES:
		if car.orders.get(action)==Mode.AUTO and can_start(index,action):
			start_service(index,action,Mode.AUTO)

func finish_service(index: int, action: String) -> void:
	var car := cars[index]
	match action:
		"fuel": car.fuel = 1.0
		"tires":
			car.tires = 1.0
			for axle in range(2):
				if jack_owners[axle]==index: jack_owners[axle] = -1
		"driver": car.driver = 1-car.driver
		"repair": car.damage = 0.0 if car.state==State.GARAGE else maxf(0.0,car.damage-0.29)
	car.done[action] = true
	car.jobs.erase(action)
	var reports := {"fuel":"plein terminé", "tires":"pneus changés", "driver":"%s prend le volant" % car.drivers[car.driver],
		"repair":"réparation au garage terminée" if car.state==State.GARAGE else "réparation rapide terminée"}
	announce("N° %d · %s." % [car.number,reports[action]])

func leave(car: Dictionary) -> void:
	car.exit_from = car.state
	car.state = State.EXIT
	car.timer = EXIT_TIME
	car.orders.clear()
	car.done.clear()
	car.axles = [-1,-1]
	car.garage_stop = false
	var stint := random.randf_range(2700.0,3450.0) if not car.ours else 3000.0
	stint = minf(stint,(float(car.fuel)-0.18)/fuel_burn(car))
	if car.ours: stint = minf(stint,maxf(900.0,3500.0-float(car.fatigue[car.driver])))
	car.planned = elapsed+EXIT_TIME+maxf(100.0,stint)

func reset_plan(car: Dictionary) -> void:
	car.called = false
	car.planned = elapsed + seconds_to_line(car) + 6.0
	car.orders.clear()
	car.garage_stop = false

func allowed(car: Dictionary, action: String) -> bool:
	if phase!=Phase.RACE or not car.ours: return false
	if action=="plan":
		return car.state in [State.TRACK,State.ENTRY,State.QUEUE,State.BOX,State.GARAGE] and car.jobs.is_empty() and not tires_in_progress(car)
	if car.state==State.TRACK:
		match action:
			"delay": return car.fuel>0.09 and (car.called or car.planned-elapsed<seconds_to_line(car)+145.0)
			"pace": return true
		return false
	return action=="exit" and car.state in [State.BOX,State.GARAGE] and car.fuel>=0.055 \
		and not car.orders.is_empty() and car.jobs.is_empty() and not tires_in_progress(car) and pending_orders(car).is_empty()

func needs_service(car: Dictionary, action: String) -> bool:
	if car.done.has(action): return false
	match action:
		"fuel": return car.fuel<0.998
		"tires": return car.tires<0.998
		"driver": return true
		"repair": return car.damage>=0.03
	return false

func pending_orders(car: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for action in SERVICES:
		if car.orders.get(action, Mode.SKIP)!=Mode.SKIP and needs_service(car,action): result.append(action)
	return result

func recommended_orders(car: Dictionary) -> Dictionary:
	if not car.orders.is_empty(): return car.orders.duplicate()
	return {"fuel":Mode.MANUAL if car.fuel<0.67 else Mode.SKIP,
		"tires":Mode.MANUAL if car.tires<0.84 else Mode.SKIP,
		"driver":Mode.AUTO if car.fatigue[car.driver]>2100.0 else Mode.SKIP,
		"repair":Mode.MANUAL if car.damage>=0.03 else Mode.SKIP}

func confirm_stop(index: int, orders: Dictionary, garage: bool) -> bool:
	if index<0 or index>=2 or not allowed(cars[index],"plan"): return false
	var car := cars[index]
	car.orders.clear()
	for action in SERVICES:
		var mode: int = orders.get(action,Mode.SKIP)
		car.orders[action] = mode if mode in [Mode.MANUAL,Mode.AUTO] and not car.done.has(action) else Mode.SKIP
	car.garage_stop = garage or car.state==State.GARAGE
	if car.state==State.BOX and garage:
		if not cars.any(func(peer: Dictionary) -> bool: return peer.ours and peer.state==State.GARAGE):
			car.state = State.GARAGE
			announce("N° %d · au garage, le box extérieur est libre." % car.number)
		else:
			car.state = State.QUEUE
			car.queue_time = elapsed
			announce("N° %d · attend que le garage se libère." % car.number)
	elif car.state==State.TRACK:
		car.called = true
		announce("N° %d · arrêt confirmé à la fin du tour." % car.number)
	assign_stands()
	return true

func tires_in_progress(car: Dictionary) -> bool:
	return not car.done.has("tires") and (car.axles[0]>=0 or car.axles[1]>=0)

func can_start(index: int, action: String) -> bool:
	var car := cars[index]
	if phase!=Phase.RACE or car.state not in [State.BOX,State.GARAGE] or car.jobs.has(action) or not needs_service(car,action): return false
	if action=="tires": return -1==jack_owners[0] and -1==jack_owners[1]
	if action=="fuel": return not cars[1-index].jobs.has("fuel")
	return true

func service_time(car: Dictionary, action: String, mode: int) -> float:
	if action=="repair" and car.state==State.GARAGE:
		return ceilf((38.0+car.damage*115.0) if mode==Mode.MANUAL else (145.0+car.damage*250.0))
	return AUTO_TIME[action] if mode==Mode.AUTO else MANUAL_TIME[action]

func start_service(index: int, action: String, mode: int) -> bool:
	if action not in SERVICES or not can_start(index,action): return false
	if mode==Mode.MANUAL and not MANUAL_TIME.has(action): return false
	var car := cars[index]
	if car.orders.get(action)!=mode: return false
	if action=="tires":
		jack_owners = [index,index]
	var duration := service_time(car,action,mode)
	car.jobs[action] = {"left":duration,"total":duration,"mode":mode}
	return true

func manual_needed(index: int, action: String) -> bool:
	var car := cars[index]
	return phase==Phase.RACE and car.state in [State.BOX,State.GARAGE] and car.orders.get(action)==Mode.MANUAL \
		and needs_service(car,action) and not car.jobs.has(action)

func manual_action(index: int, action: String, axle := -1, wheel := -1) -> bool:
	var car := cars[index]
	if not manual_needed(index,action): return false
	if action=="driver":
		finish_service(index,action)
		return true
	if action!="tires": return start_service(index,action,Mode.MANUAL)
	var stage: int = car.axles[axle]
	if wheel>=0:
		if jack_owners[axle]!=index or stage<0 or stage>=4 or (stage & (1<<wheel))!=0: return false
		car.axles[axle] = stage | (1<<wheel)
	elif stage==-1 and jack_owners[axle]==-1:
		jack_owners[axle] = index
		car.axles[axle] = 0
	elif stage==3 and jack_owners[axle]==index:
		jack_owners[axle] = -1
		car.axles[axle] = 4
	else: return false
	if car.axles==[4,4]: finish_service(index,action)
	return true

func perform(index: int, action: String) -> bool:
	if index<0 or index>=2 or index>=cars.size(): return false
	var car := cars[index]
	if not allowed(car,action): return false
	match action:
		"delay":
			reset_plan(car)
			announce("N° %d · l’arrêt est décalé d’un tour." % car.number)
		"pace": car.pace = (car.pace+1)%PACE_NAMES.size()
		"exit":
			leave(car)
			announce("N° %d · feu vert, sortie des stands." % car.number)
	assign_stands()
	return true

static func action_label(action: String) -> String:
	return {"fuel":"Essence", "tires":"Pneus", "driver":"Relève", "repair":"Réparation",
		"plan":"Plan d’arrêt", "exit":"Reprendre la piste", "delay":"Décaler d’un tour"}.get(action,action)

func classification() -> Array[Dictionary]:
	var result := cars.duplicate()
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.state==State.OUT and b.state!=State.OUT: return false
		if b.state==State.OUT and a.state!=State.OUT: return true
		return a.distance>b.distance if not is_equal_approx(a.distance,b.distance) else a.number<b.number)
	return result

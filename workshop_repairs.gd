extends RefCounted

const Catalog := preload("res://workshop_catalog.gd")
const BENCH_STEPS := [
	["puncture_test","Tester la roue à l’établi","",1.0],
	["puncture_patch","Poser la rustine à l’établi","patch",1.15],
	["puncture_recycle","Recycler la roue irréparable","",0.5],
]

static func hint(label: String, item: String = "", lift: int = -1) -> Dictionary:
	return {"label":label,"item":item,"lift":lift}

static func with_hint(action: Dictionary, label: String, item: String = "", lift: int = -1,
		station: String = "") -> Dictionary:
	action.work = hint(label,item,lift)
	action.work.at = action.at
	if station!="": action.work.station = station
	return action

static func started(order: Dictionary, job: String) -> bool:
	match job:
		"oil": return order.oil>0
		"battery": return order.battery>0
		"coolant": return order.coolant
	return stage(order,job)>0 or (job=="damper" and not order.service.get("damper_checked",[]).is_empty())

static func active(order: Dictionary, job: String) -> bool:
	return job in order.required and job not in order.done

static func stage(order: Dictionary, key: String) -> int:
	return order.service.get(key,0)

static func finish(order: Dictionary, job: String) -> void:
	if active(order,job): order.done.append(job)

static func wheel_needed(order: Dictionary, wheel: int) -> bool:
	if order.wheels[wheel]==4: return false
	return active(order,"tires") or order.wheels[wheel]>0 or (
		active(order,"brakes") and wheel in Catalog.FRONT_WHEELS) or (
		active(order,"puncture") and order.faults.puncture==wheel) or (
		active(order,"bearing") and (stage(order,"bearing")==0 or order.faults.bearing==wheel))

static func wheel_is_punctured(order: Dictionary, wheel: int) -> bool:
	return active(order,"puncture") and order.faults.puncture==wheel

static func wheel_needs_new(order: Dictionary, wheel: int) -> bool:
	return active(order,"tires") or (wheel_is_punctured(order,wheel) and stage(order,"puncture")==4)

static func wheel_step(w, order: Dictionary, wheel: int, p: Vector2, bay: int) -> Dictionary:
	var extra := {"wheel":wheel}
	if active(order,"bearing") and stage(order,"bearing")==0:
		var checked: Array = order.service.get("bearing_checked",[])
		if wheel in checked: return w.target("none","Roulement sain · vérifie une autre roue",p,0)
		return step(w,bay,p,true,"bearing_test","Écouter la roue · "+Catalog.WHEEL_SIDES[wheel],"probe",0.7,extra)
	if order.wheels[wheel]!=2: return {}
	if active(order,"brakes") and wheel in Catalog.FRONT_WHEELS and wheel not in order.service.get("pads",[]):
		return step(w,bay,p,true,"brake_fit","Remplacer les plaquettes · "+Catalog.WHEEL_SIDES[wheel],"brake_pads",1.05,extra)
	if active(order,"bearing") and order.faults.bearing==wheel:
		if stage(order,"bearing")==1:
			return step(w,bay,p,true,"bearing_extract","Extraire le roulement","puller",1.2,extra)
		if stage(order,"bearing")==2:
			return step(w,bay,p,true,"bearing_fit","Monter le roulement neuf","bearing_part",0.9,extra)
	if wheel_is_punctured(order,wheel):
		var state := stage(order,"puncture")
		var top: Dictionary = w.site.stations.bench.get("top",{})
		var at_bench: bool = top.get("item","")=="repair_wheel" and top.get("origin",-1)==order.id
		var in_hand: bool = w.held=="repair_wheel" and w.held_origin==order.id
		if state<3:
			var action: Dictionary = w.target("none","Traite la roue crevée à l’établi",p,0)
			if not at_bench:
				return with_hint(action,"Apporter la roue à l’établi","repair_wheel",1,"bench")
			var next: Array = BENCH_STEPS[state]
			return with_hint(action,next[1],next[2],1,"bench")
		if state==3 and not in_hand:
			var action: Dictionary = w.target("none","Récupère la roue réparée de ce véhicule",p,0)
			return with_hint(action,"Récupérer la roue réparée","repair_wheel",1,"bench")
	return {}

static func complete_wheels(order: Dictionary) -> void:
	if order.wheels.count(4)==4: finish(order,"tires")
	if order.wheels[0]==4 and order.wheels[2]==4 and order.service.get("pads",[]).size()==2:
		finish(order,"brakes")
	if stage(order,"bearing")==3 and order.wheels[order.faults.bearing]==4: finish(order,"bearing")
	if stage(order,"puncture")>=3 and order.wheels[order.faults.puncture]==4: finish(order,"puncture")

static func step(w, bay: int, p: Vector2, raised: bool, id: String, label: String,
		item: String, seconds: float, extra: Dictionary = {}) -> Dictionary:
	var under_hood := id in Catalog.HOOD_ACTIONS
	var action: Dictionary = w.lift_requirement(bay,raised,p)
	if action.is_empty():
		if w.held!=item or w.pulling_cart:
			var needed: String = "Libère tes mains" if item=="" else w.item_name(item)
			action = w.target("none",label+" · "+needed,p,0)
		else:
			action = w.target(id,label,p,w.repair_seconds(seconds),{"bay":bay,"raised":raised})
			action.merge(extra,true)
	with_hint(action,label,item,int(raised))
	if under_hood: action.work.zone = "Capot"
	elif id=="drain": action.work.zone = "Avant du véhicule"
	if under_hood or id=="drain": action.from_front = true
	return action

static func service_actions(w, order: Dictionary, job: String, bay: int, center: Vector2) -> Array[Dictionary]:
	if job=="damper": return damper_actions(w,order,bay,center)
	if job=="lights": return [light_action(w,order,bay,center)]
	var p: Vector2 = center+Catalog.PANEL_OFFSETS[job]
	var state := stage(order,job)
	match job:
		"muffler":
			if state==0: return [step(w,bay,p,true,"muffler_unbolt","Détacher le silencieux","ratchet",1.25)]
			if state==1: return [step(w,bay,p,true,"muffler_take","Prendre le silencieux usé","",0.55)]
			if state==2:
				return [with_hint(w.target("none","Dépose le silencieux usé à la récupération",p,0),
					"Déposer le silencieux à la récupération","old_muffler",1,"scrap")]
			return [step(w,bay,p,true,"muffler_fit","Poser le silencieux neuf","new_muffler",1.35)]
		"shield":
			if state==0: return [step(w,bay,p,true,"shield_test","Contrôler le cache sous le moteur","ratchet",0.65)]
			if order.faults.broken_panel: return [step(w,bay,p,true,"shield_fit","Remplacer le cache cassé","shield_part",1.0)]
			return [step(w,bay,p,true,"shield_tighten","Resserrer le cache","ratchet",0.8)]
		"belt":
			if state==0: return [step(w,bay,p,false,"belt_remove","Retirer la courroie usée","ratchet",0.9)]
			if state==1: return [step(w,bay,p,false,"belt_fit","Poser la courroie neuve","belt_part",1.0)]
			return [step(w,bay,center+Catalog.ENGINE_SWITCH,false,"belt_test","Tester le moteur","",0.75)]
		"wipers":
			if state==0: return [step(w,bay,p,false,"wipers_fit","Remplacer les deux balais","wiper_pair",0.85)]
			return [step(w,bay,center+Catalog.WIPER_SWITCH,false,"wipers_test","Tester les essuie-glaces","",0.7)]
		"window":
			if state==0: return [step(w,bay,p,false,"window_test","Tester la vitre","",0.75)]
			if state==1: return [step(w,bay,p,false,"window_rail","Débloquer le rail","ratchet",1.2)]
			if state==2: return [w.target("none","Module de vitre à remplacer · parle au client",p,0)]
			if state==3: return [step(w,bay,p,false,"window_fit","Installer le module de vitre","window_module",1.15)]
			return [step(w,bay,p,false,"window_verify","Vérifier la course de la vitre","",0.65)]
	return []

static func damper_actions(w, order: Dictionary, bay: int, center: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var checked: Array = order.service.get("damper_checked",[])
	for i in range(2):
		var p := center+Vector2(-1.46 if i==0 else 1.46,0.44)
		if stage(order,"damper")==0:
			if i in checked: result.append(w.target("none","Amortisseur sain · vérifie l’autre côté",p,0))
			else: result.append(step(w,bay,p,true,"damper_test","Tester l’amortisseur "+("gauche" if i==0 else "droit"),"probe",0.8,{"side":i}))
		elif i==order.faults.damper:
			result.append(step(w,bay,p,true,"damper_fit","Remplacer l’amortisseur usé","damper_part",1.25))
	return result

static func light_action(w, order: Dictionary, bay: int, center: Vector2) -> Dictionary:
	var state := stage(order,"lights")
	if state!=1:
		var id := "lights_test" if state==0 else "lights_verify"
		return step(w,bay,center+Catalog.LIGHT_SWITCH,false,id,"Allumer et tester les feux","",0.65)
	var rear: bool = order.faults.rear_lamp
	return step(w,bay,center+(Catalog.REAR_LAMP if rear else Catalog.FRONT_LAMP),false,
		"light_fit","Remplacer l’ampoule "+("arrière" if rear else "avant"),
		"lamp_rear" if rear else "lamp_front",0.8)

static func bench_action(w, p: Vector2) -> Dictionary:
	var top: Dictionary = w.site.stations.bench.get("top",{})
	if top.get("item")!="repair_wheel": return w.counter_action("bench",p)
	var order: Dictionary = w.find_order(top.origin)
	if order.is_empty(): return {}
	var state := stage(order,"puncture")
	if w.pulling_cart: return w.target("none","Gare le chariot",p,0)
	if state<BENCH_STEPS.size():
		var next: Array = BENCH_STEPS[state]
		if w.held==next[2]:
			return w.target(next[0],next[1],p,next[3],{"origin":order.id})
	if state==3: return w.counter_action("bench",p)
	return w.target("none","Prends une rustine pour réparer la roue" if state==1 else "Libère tes mains",p,0)

static func finish_station(w, a: Dictionary) -> void:
	var order: Dictionary = w.find_order(a.origin)
	if order.is_empty(): return
	match a.id:
		"puncture_test":
			order.service.puncture = 2 if order.faults.bad_puncture else 1
			w.inform("La roue est irréparable · recycle-la puis prends un pneu neuf." if order.faults.bad_puncture else "Fuite réparable · prends une rustine au rayon châssis.")
		"puncture_patch":
			order.service.puncture = 3
			w.set_held("")
			w.inform("Roue réparée · récupère-la sur l’établi et remonte-la.")
		"puncture_recycle":
			var bench: Dictionary = w.site.stations.bench
			bench.top.count = 0
			w.update_stack(bench.top,bench.root,Vector3.ZERO)
			bench.erase("top")
			order.service.puncture = 4
		"recycle_muffler":
			order.service.muffler = 3
			w.set_held("")

static func finish_vehicle(w, a: Dictionary, order: Dictionary, bay: Dictionary) -> void:
	match a.id:
		"brake_fit":
			if not order.service.has("pads"): order.service.pads = []
			if a.wheel not in order.service.pads: order.service.pads.append(a.wheel)
			w.set_held("")
		"bearing_test":
			var bad: bool = a.wheel==order.faults.bearing
			w.site.play_bearing_test(bad)
			if bad:
				order.service.bearing = 1
				w.inform("Grincement · roulement "+Catalog.WHEEL_SIDES[a.wheel]+".")
			else:
				var checked: Array = order.service.get("bearing_checked",[])
				order.service.bearing_checked = checked+[a.wheel]
				w.inform("Roue "+Catalog.WHEEL_SIDES[a.wheel]+" · roulement sain.")
		"bearing_extract": order.service.bearing = 2
		"bearing_fit":
			order.service.bearing = 3
			w.set_held("")
		"muffler_unbolt": order.service.muffler = 1
		"muffler_take":
			order.service.muffler = 2
			w.set_held("old_muffler",order.id)
		"muffler_fit":
			w.set_held("")
			finish(order,"muffler")
		"damper_test":
			if a.side==order.faults.damper:
				order.service.damper = 1
				w.inform("Amortisseur "+("gauche" if a.side==0 else "droit")+" usé · prends une pièce au rayon châssis.")
			else:
				var checked: Array = order.service.get("damper_checked",[])
				order.service.damper_checked = checked+[a.side]
				w.inform("Amortisseur sain · vérifie l’autre côté.")
		"damper_fit":
			w.set_held("")
			finish(order,"damper")
		"shield_test":
			order.service.shield = 1
			w.inform("Cache cassé · prends un cache neuf." if order.faults.broken_panel else "Cache intact · resserre ses fixations.")
		"shield_tighten","shield_fit":
			if a.id=="shield_fit": w.set_held("")
			finish(order,"shield")
		"lights_test":
			order.service.lights = 1
			w.site.flash_lights(bay,"rear" if order.faults.rear_lamp else "front")
			w.inform("Ampoule "+("arrière" if order.faults.rear_lamp else "avant")+" grillée.")
		"light_fit":
			order.service.lights = 2
			w.set_held("")
		"lights_verify":
			w.site.flash_lights(bay,"")
			finish(order,"lights")
		"belt_remove": order.service.belt = 1
		"belt_fit":
			order.service.belt = 2
			w.set_held("")
		"belt_test": finish(order,"belt")
		"wipers_fit":
			order.service.wipers = 1
			w.set_held("")
		"wipers_test": finish(order,"wipers")
		"window_test":
			order.service.window = 2 if order.faults.module else 1
			w.inform("Module HS · demande l’accord du client en salle d’attente." if order.faults.module else "Rail bloqué · prends la clé à cliquet.")
		"window_approve":
			order.service.window = 3
			order.service.module_approved = true
		"window_decline":
			order.required.erase("window")
			w.run.penalty()
			w.inform("Module reporté · −½ étoile")
		"window_rail": order.service.window = 4
		"window_fit":
			w.set_held("")
			order.service.window = 4
		"window_verify": finish(order,"window")

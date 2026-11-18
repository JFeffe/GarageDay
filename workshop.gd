extends RefCounted

const Map := preload("res://workshop_map.gd")
const Scene := preload("res://workshop_map.tscn")
const Day := preload("res://workshop_day.gd")
const Menu := preload("res://workshop_menu.gd")
const Ring := preload("res://workshop_ring.gd")
const Catalog := preload("res://workshop_catalog.gd")
const Repairs := preload("res://workshop_repairs.gd")
const RepairPose := preload("res://workshop_repair_pose.gd")
const FORWARD_SPEED := 4.6
const REVERSE_SPEED := 2.6
const PARKING_MARGIN := 0.26
const PARKING_SPEED := 1.25
const CUSTOMER_NEAR := 1.4
const RECEIPT_SECONDS := 2.2
const GARAGE_CAMERA_ROTATION := Vector3(-63,0,0)

enum IntakeStatus { APPROACH, TURN, LEFT, RIGHT, FORWARD, BACK, SLOW, BLOCKED, READY }
enum ParkingStatus { ALIGN, SLOW, BLOCKED, READY, FULL }
const JOBS := Catalog.JOBS
const ITEMS := {"fresh_oil":"Bouteille d’huile neuve","empty_bottle":"Bouteille vide","old_battery":"Batterie usée",
	"new_battery":"Batterie neuve","coolant":"Liquide neuf","coolant_empty":"Bidon vide",
	"new_tire":"Pneu neuf","used_tire":"Pneu usagé","repair_wheel":"Roue à réparer","old_muffler":"Silencieux usé"}

var game: Node3D
var site: Node3D
var run = Day.new()
var layout := -1
var player := Vector2(3.5,11.5)
var facing := Vector2.UP
var velocity := Vector2.ZERO
var zoom := 0
var driven_bay := -1
var drive_speed := 0.0
var drive_steering := 0.0
var office_seated := false
var seat_blend := 0.0
var ui: CanvasLayer
var header: RichTextLabel
var ticket: RichTextLabel
var footer: RichTextLabel
var menu: Control
var ring: Control
var engine: AudioStreamPlayer
var held := ""
var held_origin := -1
var held_turn := -1
var oil_pan_for := -1
var day_setup: Dictionary = {}
var tool_holder: Node3D
var item_prop: Node3D
var rolling_cart: Node3D
var cart_wheels: Array[Node3D] = []
var cart_display: Array[Node3D] = []
var pulling_cart := false
var cart_kind := ""
var cart_count := 0
var cart_turn := 0
var relocating := ""
var relocating_turn := 0
var parts_shelf := ""
var action: Dictionary = {}
var progress := 0.0
var repair_pose := RepairPose.new()
var notice := ""
var notice_time := 0.0
var visitors: Dictionary = {}
var incoming: Dictionary = {}
var accepted_intakes: Array[int] = []
var waiting_for_bay: Array[Dictionary] = []
var checkout_queue: Array[int] = []
var parked_cars: Dictionary = {}
var incoming_driver := -1
var departures: Dictionary = {}
var road_customer := -1
var coop
var guest_input: Array = []

func setup(g: Node3D, initial_layout := 0) -> void:
	game = g
	setup_ui()
	build(initial_layout)

func setup_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 4
	game.add_child(ui)
	header = make_panel(270)
	ticket = make_panel(320)
	footer = make_panel(580)
	ring = Ring.new()
	ui.add_child(ring)
	ring.hide()
	engine = AudioStreamPlayer.new()
	engine.volume_db = -25.0
	engine.stream = engine_loop()
	ui.add_child(engine)
	menu = Menu.new()
	ui.add_child(menu)
	menu.chosen.connect(menu_chosen)
	menu.dismissed.connect(menu_dismissed)
	menu.reroll_requested.connect(reroll_vendor_offers)

func engine_loop() -> AudioStreamWAV:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 16000
	clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
	clip.loop_end = 6400
	var samples := PackedByteArray()
	samples.resize(clip.loop_end*2)
	for n in range(clip.loop_end):
		var phase := float(n)*TAU/clip.mix_rate
		var sound := sin(phase*45.0)*0.50+sin(phase*90.0)*0.24+sin(phase*135.0)*0.12
		sound *= 0.82+sin(phase*7.5)*0.18
		samples.encode_s16(n*2,int(sound*32767))
	clip.data = samples
	return clip

func make_panel(width: float) -> RichTextLabel:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1b323a")
	style.border_color = Color("#547878")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	ui.add_child(panel)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.x = width
	panel.add_child(label)
	return label

func show_layouts() -> void:
	menu.open("layout","Choisir ton garage","Une partie de dix jours",
		Map.LAYOUTS,"Flèches / Croix directionnelle   ·   A / F choisir   ·   B / Q retour")

func show_vendor(message := "", focused := 0) -> void:
	if run.mode!="open": return
	var cards: Array = []
	for offer in run.nightly_offers():
		var price := "%d $"%offer.price
		var color := "#fff3d9"
		if run.vendor_purchase_record(offer).has(offer.id):
			price = "Prévu demain" if offer.get("temporary",false) else "Installé"
			color = "#a5dfaf"
		elif run.cash<offer.price:
			price += " · Fonds insuffisants"
			color = "#f0ca85"
		cards.append([offer.name,offer.description,offer.color,price,color,offer.id,offer.has("unlock_day")])
	var subtitle := "%d $ en caisse"%run.cash
	if message!="": subtitle += "   ·   "+message
	var rare_preview: Array[String] = []
	for offer in Catalog.VENDOR_OFFERS:
		if not offer.has("unlock_day") or run.purchases.has(offer.id): continue
		var availability := "Débloqué" if run.day>=offer.unlock_day else "Soir %d"%offer.unlock_day
		rare_preview.append("%s · %s · %d $"%[availability,offer.name,offer.price])
	var details := "Améliorations rares\n"+"\n".join(rare_preview) if not rare_preview.is_empty() else ""
	menu.open("vendor","La Fourgonnette",subtitle,cards,"A / F acheter   ·   B / Q fermer",details)
	if run.vendor_reroll_day==run.day:
		menu.set_vendor_reroll("Relance utilisée ce soir",true)
	elif run.cash<Day.VENDOR_REROLL_COST:
		menu.set_vendor_reroll("Relancer · %d $ · Fonds insuffisants"%Day.VENDOR_REROLL_COST,true)
	else:
		menu.set_vendor_reroll("X / R · Relancer les offres · %d $"%Day.VENDOR_REROLL_COST,false)
	menu.choice = focused
	menu.update_focus()

func reroll_vendor_offers() -> void:
	if menu.kind!="vendor" or not menu.visible or not site.van.visible: return
	if run.reroll_vendor():
		update_hud()
		show_vendor("Nouvelles offres")
	else:
		show_vendor("Aucune relance disponible",menu.choice)

func purchase_vendor_offer(index: int) -> void:
	if run.mode!="open" or not site.van.visible: return
	var offers: Array[Dictionary] = run.nightly_offers()
	if index<0 or index>=offers.size(): return
	var offer := offers[index]
	if run.day<int(offer.get("unlock_day",0)): return
	var temporary: bool = offer.get("temporary",false)
	var record: Dictionary = run.vendor_purchase_record(offer)
	if record.has(offer.id):
		show_vendor("Déjà prévu pour demain" if temporary else "Déjà installé",index)
		return
	if run.cash<offer.price:
		show_vendor("Il manque %d $"%(offer.price-run.cash),index)
		return
	match offer.id:
		"compressor": site.install_compressor()
		"lounge": site.install_waiting_room_cushions()
		"counter","vending","magazines":
			var span := 2 if offer.id=="counter" else 1
			var tiles := find_office_space(span,offer.id)
			if tiles.is_empty():
				show_vendor("Libère deux cases voisines dans le bureau" if span==2 else "Libère une case dans le bureau",index)
				return
			if offer.id=="counter":
				for i in range(tiles.size()):
					site.make_station("counter_vendor_%d"%i,"Desserte %d"%(i+1),tiles[i],Color(offer.color))
			else:
				site.make_station(offer.id,offer.name,tiles[0],Color(offer.color),1.23 if offer.id=="vending" else 0.76)
	run.cash -= offer.price
	record[offer.id] = true
	if offer.id=="lift": update_lift_speed()
	update_hud()
	var message := "Livré au bureau" if offer.id in ["counter","vending","magazines"] else "Achat installé"
	show_vendor("Prévu pour demain" if temporary else message,index)

func update_lift_speed() -> void:
	var multiplier := 1.6 if run.purchases.has("lift") else 1.0
	if run.mode in ["day","closing"] and run.active_services.has("tuning"): multiplier *= 1.35
	site.lift_speed = Map.LIFT_SPEED*multiplier

func find_office_space(span: int, id: String) -> Array[Vector2i]:
	var office: Rect2i = site.office_tiles()
	for z in range(office.position.y,office.end.y):
		for x in range(office.end.x-span,office.position.x-1,-1):
			var base := Vector2i(x,z)
			var tiles: Array[Vector2i] = []
			for offset in range(span): tiles.append(base+Vector2i(offset,0))
			if tiles.any(func(tile: Vector2i) -> bool:
				return site.blocks_traffic(tile) or not site.placement_ok(tile,id)): continue
			var footprint := Rect2(Vector2(base),Vector2(span,1))
			if footprint.grow(Map.PLAYER_RADIUS).has_point(player): continue
			for tile in tiles: site.cells[tile] = {"kind":"preview"}
			var visited := reachable_tiles(player,false)
			var accessible := furniture_routes_ok(visited) and tiles.all(func(tile: Vector2i) -> bool:
				return interaction_reachable(visited,[tile]))
			for tile in tiles: site.cells.erase(tile)
			if accessible: return tiles
	return []

func request_restart() -> void:
	cancel_action()
	menu.open("restart","Redémarrer le garage","La partie en cours et sa caisse seront effacées.",
		[["Continuer","Revenir au garage."],["Nouvelle partie","Choisir un bâtiment et repartir au jour 1."]],
		"Flèches   ·   A / F confirmer   ·   B / Q annuler")

func menu_chosen(index: int) -> void:
	var kind: String = menu.kind
	if kind=="vendor":
		purchase_vendor_offer(index)
		return
	menu.hide()
	if kind=="layout": build(index)
	elif kind=="restart" and index==1: show_layouts()
	elif kind=="summary" and run.mode in ["won","lost"]: show_layouts()
	elif kind=="parts" and Catalog.SHELVES.has(parts_shelf) and held=="" and not pulling_cart:
		var choices: Array = Catalog.SHELVES[parts_shelf]
		if index>=0 and index<choices.size(): set_held(choices[index])

func show_parts(shelf: String) -> void:
	parts_shelf = shelf
	var cards: Array = []
	for part in Catalog.SHELVES[shelf]:
		var description: String = JOBS[Catalog.PART_JOBS[part]][0]
		if part=="brake_pads": description = "Une paire par roue avant"
		elif part=="shield_part": description = "Pour remplacer un cache cassé"
		cards.append([item_name(part),description])
	menu.open("parts",site.stations[shelf].title,"Prends une pièce à la fois",cards,
		"Croix directionnelle · A / F prendre · B / Q fermer")

func menu_dismissed() -> void:
	menu.hide()

func build(index: int) -> void:
	if coop!=null: coop.reset()
	cancel_action()
	repair_pose.release = 0.0
	engine.stop()
	if is_instance_valid(site):
		site.hide()
		site.queue_free()
	if is_instance_valid(tool_holder):
		tool_holder.hide()
		tool_holder.queue_free()
	layout = index
	site = Scene.instantiate()
	game.add_child(site)
	site.build(game,layout)
	run = Day.new()
	run.intro_brakes = index==0
	day_setup.clear()
	visitors.clear()
	incoming.clear()
	accepted_intakes.clear()
	waiting_for_bay.clear()
	checkout_queue.clear()
	parked_cars.clear()
	incoming_driver = -1
	departures.clear()
	road_customer = -1
	held = ""
	held_origin = -1
	held_turn = -1
	oil_pan_for = -1
	relocating = ""
	relocating_turn = 0
	pulling_cart = false
	cart_kind = ""
	cart_count = 0
	cart_turn = 0
	notice_time = 0
	player = Vector2(3.5,11.5)
	facing = Vector2.UP
	velocity = Vector2.ZERO
	zoom = 0
	driven_bay = -1
	drive_speed = 0.0
	drive_steering = 0.0
	game.avatar.show()
	office_seated = false
	seat_blend = 0.0
	site.cells[site.cart_cell] = {"kind":"cart"}
	tool_holder = Node3D.new()
	game.avatar.add_child(tool_holder)
	rolling_cart = site.trolley_model(tool_holder,Vector3(0,-0.92,-1.13))
	rolling_cart.rotation.y = PI
	cart_display.clear()
	cart_wheels.clear()
	for i in range(4):
		var at := Vector3(0,0.33+i*0.20,0)
		var parked: Node3D = site.tire_model(site.parked_cart,at)
		parked.rotation.z = 0
		cart_display.append(parked)
		var carried: Node3D = site.tire_model(rolling_cart,at)
		carried.rotation.z = 0
		cart_wheels.append(carried)
	for id in Map.TOOLS:
		var station: Dictionary = site.stations["tool_"+id]
		station.top = {"item":id,"count":1,"origin":-1}
		update_stack(station.top,station.root,Vector3(0,station.height+0.09,0))
	refresh_cart()
	item_prop = null
	sync_player(0,0)
	update_camera(1)
	update_hud()

func item_name(id: String) -> String:
	if id=="oil" and run.purchases.has("oil_recovery"): return "Bac récupérateur"
	if Catalog.PARTS.has(id): return Catalog.PARTS[id][0]
	return Map.TOOLS.get(id,ITEMS.get(id,id))

func inform(message: String) -> void:
	notice = message
	notice_time = 3.5

func item_model(parent: Node3D, id: String, at: Vector3) -> Node3D:
	if id in Map.TOOLS: return site.tool_model(parent,id,at)
	if id in ["new_tire","used_tire","repair_wheel"]:
		var tire: Node3D = site.tire_model(parent,at,Color("#27373c") if id=="new_tire" else Color("#514945"))
		tire.rotation.z = 0
		return tire
	return site.supply_model(parent,id,at)

func set_held(id: String, origin := -1, turn := -1) -> void:
	if is_instance_valid(item_prop):
		item_prop.hide()
		item_prop.queue_free()
	held = id
	held_origin = origin
	held_turn = turn if id!="" else -1
	item_prop = null if id=="" else item_model(tool_holder,id,Vector3(0,0.04,0))

func update_stack(stack: Dictionary, parent: Node3D, at: Vector3) -> void:
	if is_instance_valid(stack.get("visual")):
		stack.visual.hide()
		stack.visual.queue_free()
	if stack.count<=0: return
	var visual := Node3D.new()
	parent.add_child(visual)
	visual.position = at
	visual.rotation.y = Map.turn_yaw(maxi(0,stack.get("turn",-1)))
	for i in range(stack.count): item_model(visual,stack.item,Vector3(0,i*0.20,0))
	stack.visual = visual

func refresh_cart() -> void:
	if coop!=null and coop.processing_guest: return
	site.parked_cart.visible = not pulling_cart
	rolling_cart.visible = pulling_cart
	var p: Vector2 = site.center(site.cart_cell)
	site.parked_cart.position = Vector3(p.x,0.075,p.y)
	site.parked_cart.rotation.y = Map.turn_yaw(cart_turn)
	for i in range(4):
		for tire in [cart_display[i],cart_wheels[i]]:
			tire.visible = i<cart_count
			site.Neighborhood.color_tire(tire,Color("#514945") if cart_kind=="used_tire" else Color("#27373c"))

func active_orders() -> Array[Dictionary]:
	var result := waiting_for_bay.duplicate()
	for bay in site.bays:
		if not bay.order.is_empty() and not bay.order.paid: result.append(bay.order)
	for parked in parked_cars.values():
		if not parked.order.paid: result.append(parked.order)
	return result

func free_bay() -> int:
	for i in range(site.bays.size()):
		if site.bays[i].status=="": return i
	return -1

func accept_client() -> void:
	if run.waiting.is_empty(): return
	var order: Dictionary = run.waiting[0]
	if not incoming.has(order.id) or not visitor_at(order.id,site.queue_head): return
	var arrival: Dictionary = incoming[order.id]
	if arrival.stage!="walk": return
	waiting_for_bay.append(run.waiting.pop_front())
	assign_waiting_customers()
	if order in waiting_for_bay:
		inform("%s est accueilli · voiture en A %02d en attendant une baie."%[order.name,arrival.slot+1])

func assign_waiting_customers() -> void:
	while not waiting_for_bay.is_empty():
		var index := free_bay()
		if index<0: return
		var order: Dictionary = waiting_for_bay.pop_front()
		var arrival: Dictionary = incoming[order.id]
		var bay: Dictionary = site.bays[index]
		bay.order = order
		bay.status = "intake"
		bay.arrival_slot = arrival.slot
		site.transfer_car(arrival,bay)
		incoming.erase(order.id)
		accepted_intakes.append(index)
		inform("%s attend · voiture en A %02d, à rentrer en baie %02d."%[order.name,bay.arrival_slot+1,index+1])

func order_ready(order: Dictionary) -> bool:
	return order.done.size()==order.required.size() and order.decision!="pending"

func target(id: String,title: String,p: Vector2,duration: float, extra: Dictionary = {}) -> Dictionary:
	var result := {"id":id,"label":title,"at":p,"seconds":duration}
	result.merge(extra,true)
	return result


func station_action(id: String, p: Vector2) -> Dictionary:
	if Catalog.SHELVES.has(id):
		if held in Catalog.SHELVES[id]: return return_supply_action(id,p)
		if held=="" and not pulling_cart:
			return target("parts","Choisir une pièce",p,0,{"station":id})
	match id:
		"phone":
			match run.mode:
				"open": return target("start","Ouvrir le jour %d"%(run.day+1),p,0.7)
				"day":
					if run.elapsed+4.0>=Day.LENGTH: return target("none","Il est trop tard pour appeler un client",p,0)
					return target("call","Appeler un autre client",p,0.65)
				"closing": return target("none","Les appels sont fermés pour aujourd’hui",p,0)
		"office_chair":
			if held=="" and not pulling_cart: return target("sit","S’asseoir au bureau",p,0)
		"reception":
			if run.mode in ["day","closing"]:
				p = site.reception_at
				if not site.behind_reception(p,player): return {}
				if run.waiting.is_empty(): return target("none","Aucun client au comptoir",p,0)
				var next_id: int = run.waiting[0].id
				if not incoming.has(next_id) or incoming[next_id].stage=="drive":
					return target("none","Le prochain client arrive en voiture",p,0)
				if not visitor_at(next_id,site.queue_head):
					return target("none","Le prochain client s’avance",p,0)
				var label: String = "Accueillir "+run.waiting[0].name
				if free_bay()<0: label += " · attente d’une baie"
				var seconds := 0.275 if run.active_services.has("reception") else 0.55
				return target("receive",label,p,seconds)
		"rack":
			if pulling_cart and cart_kind!="used_tire":
				if cart_count==4: return target("return_cart_stock","Remettre les pneus neufs au rack",p,0)
				return target("rack_cart","Charger %d pneus neufs"%(4-cart_count),p,0.55)
			if held=="new_tire": return return_supply_action(id,p)
			if held=="" and not pulling_cart: return target("rack_hand","Prendre un pneu neuf",p,0.45)
		"fresh_oil","new_battery","coolant":
			if held==id: return return_supply_action(id,p)
			if held=="" and not pulling_cart: return target("stock","Prendre "+item_name(id),p,0.48,{"item":id})
		"bench":
			return Repairs.bench_action(self,p)
		"scrap":
			if held=="old_muffler" and held_origin>=0:
				return target("recycle_muffler","Déposer le silencieux usé",p,0.5,{"origin":held_origin})
		"waste_oil":
			if held=="oil" and oil_pan_for>=0: return target("waste","Vider l’huile usée",p,0.8)
		"trash":
			if held in ["empty_bottle","old_battery","coolant_empty"]: return target("trash","Déposer "+item_name(held),p,0.5)
			if held in ["fresh_oil","new_battery","coolant"]: return target("discard_supply","Écarter "+item_name(held),p,0.45)
		_:
			if id.begins_with("counter_") or id.begins_with("tool_"): return counter_action(id,p)
	if run.mode=="open": return target("none",site.stations[id].title,p,0)
	return {}

func return_supply_action(id: String, p: Vector2) -> Dictionary:
	return target("return_supply","Remettre "+item_name(held)+" en réserve",p,0,{"station":id})

func counter_action(id: String, p: Vector2) -> Dictionary:
	if pulling_cart: return target("none","Gare le chariot",p,0)
	if held=="used_tire": return target("none","Pose le pneu usagé au sol avec Y / E",p,0)
	var top: Dictionary = site.stations[id].get("top",{})
	if top.is_empty():
		if held=="": return target("none","Surface libre",p,0,{"station":id})
		return target("surface","Déposer · "+item_name(held),p,0,{"station":id})
	if held=="":
		return target("surface","Reprendre · "+item_name(top.item),p,0.36,{"station":id})
	if held=="new_tire" and top.item=="new_tire" and top.count<4:
		return target("surface","Empiler le pneu",p,0,{"station":id})
	if top.count==1:
		return target("surface","Échanger · "+item_name(top.item),p,0.4,{"station":id})
	return target("none",item_name(top.item)+" · %d / 4"%top.count,p,0)

func lift_requirement(index: int, raised: bool, p: Vector2) -> Dictionary:
	var bay: Dictionary = site.bays[index]
	if site.lift_moving(bay):
		return target("none","Attends l’arrêt du pont %02d"%(index+1),p,0)
	if bay.lift_raised!=raised:
		var instruction := "Lève" if raised else "Abaisse"
		return target("none","%s le pont %02d avec son levier"%[instruction,index+1],p,0)
	return {}

func lever_action(index: int) -> Dictionary:
	var bay: Dictionary = site.bays[index]
	var p: Vector2 = bay.lever_at
	if bay.status=="intake":
		var status := intake_status(bay)
		if status!=IntakeStatus.READY:
			return target("none","Reprends le volant · "+intake_prompt(status),p,0,{"bay":index})
		var vehicle_area := Rect2(bay.at-Map.CAR_HALF,Map.CAR_HALF*2.0)
		if vehicle_area.grow(Map.PLAYER_RADIUS).has_point(player):
			return target("none","Écarte-toi du véhicule pour valider sa position",p,0,{"bay":index})
		return target("validate_lift","Valider la position et lever le pont %02d"%(index+1),p,0,{"bay":index})
	if bay.status=="driving":
		return target("none","Reprends le volant pour stationner le véhicule dehors",p,0,{"bay":index})
	if bay.status!="parked":
		var status := "baie libre" if bay.status=="" else "véhicule hors du pont"
		return target("none","Pont %02d · %s"%[index+1,status],p,0,{"bay":index})
	if site.lift_moving(bay):
		return target("none","Pont %02d · %s"%[index+1,"montée" if bay.lift_raised else "descente"],p,0)
	if bay.lift_raised and bay.order.wheels.has(2):
		return target("none","Remonte les roues avant d’abaisser le pont",p,0)
	var instruction := "Abaisser" if bay.lift_raised else "Lever"
	return target("lift","%s le pont %02d"%[instruction,index+1],p,0,{"bay":index})

func wheel_action(order: Dictionary, index: int, p: Vector2, bay: int) -> Dictionary:
	var blocked := lift_requirement(bay,true,p)
	var special := Repairs.wheel_step(self,order,index,p,bay)
	if not special.is_empty():
		if blocked.is_empty(): return special
		if special.has("work"): blocked.work = special.work
		return blocked
	var state: int = order.wheels[index]
	var punctured := Repairs.wheel_is_punctured(order,index)
	var replace := Repairs.wheel_needs_new(order,index)
	var item := "tires"
	var needed := "Clé à choc requise"
	var message := "Desserrer la roue" if state==0 else "Resserrer la roue"
	var able := held==item
	if state==1:
		message = "Retirer la roue"
		item = ""
		needed = "Mains libres"
		able = held=="" and not pulling_cart
		if replace and not punctured:
			needed = "Mains libres ou chariot pour pneus usagés"
			able = able or (pulling_cart and cart_kind!="new_tire" and cart_count<4)
	elif state==2:
		message = "Remonter la roue"
		item = ""
		needed = "Mains libres"
		able = held=="" and not pulling_cart
		if replace:
			message = "Monter le pneu neuf"
			item = "new_tire"
			needed = "Pneu neuf requis"
			able = held=="new_tire" or (pulling_cart and cart_kind=="new_tire" and cart_count>0)
		elif punctured:
			item = "repair_wheel"
			needed = "Récupère la roue réparée de ce véhicule"
			able = held=="repair_wheel" and held_origin==order.id
	var side: String = Catalog.WHEEL_SIDES[index]
	var label := message+" · "+side
	var option := blocked
	if option.is_empty():
		var seconds: float = [1.1,0.6,0.65,1.1][state]
		if item=="tires" and run.purchases.has("impact"): seconds *= 0.5
		if able: option = target("wheel",label,p,repair_seconds(seconds),{"bay":bay,"wheel":index})
		else: option = target("none",needed+" · "+side,p,0)
	return Repairs.with_hint(option,label,item,1)

func repair_seconds(seconds: float) -> float:
	return seconds*0.70 if run.purchases.has("express_shop") else seconds

func service_action(order: Dictionary, id: String, bay: int, p: Vector2) -> Dictionary:
	var option: Dictionary
	match id:
		"inspection":
			var seconds := 1.0 if run.active_services.has("diagnostic") else 2.0
			option = Repairs.step(self,bay,p,false,"inspection","Inspecter le véhicule","inspection",seconds)
		"pressure":
			var seconds := 0.85 if run.purchases.has("compressor") else 1.7
			option = Repairs.step(self,bay,p,false,"pressure","Ajuster la pression","pressure",seconds)
		"oil":
			match order.oil:
				0:
					if oil_pan_for<0:
						option = Repairs.step(self,bay,p,true,"drain","Vidanger dans le bac","oil",1.55)
					else:
						option = Repairs.with_hint(target("none","Le bac d’huile est plein",p,0),
							"Vider le bac au bidon d’huile usée","oil",-1,"waste_oil")
				1:
					option = Repairs.with_hint(target("none","Vide le bac d’huile usée",p,0),
						"Vider le bac au bidon d’huile usée","oil",-1,"waste_oil")
				2:
					option = Repairs.step(self,bay,p,false,"fill_oil","Verser l’huile neuve","fresh_oil",1.25)
				3:
					option = Repairs.with_hint(target("none","Jette la bouteille vide",p,0),
						"Jeter la bouteille vide","empty_bottle",-1,"trash")
		"battery":
			match order.battery:
				0:
					option = Repairs.step(self,bay,p,false,"remove_battery","Ouvrir le capot et retirer la batterie","",1.25)
				1:
					option = Repairs.with_hint(target("none","Dépose la batterie usée à la poubelle",p,0),
						"Jeter la batterie usée","old_battery",-1,"trash")
				2:
					option = Repairs.step(self,bay,p,false,"install_battery","Installer la batterie neuve","new_battery",1.35)
		"coolant":
			if order.coolant:
				option = Repairs.with_hint(target("none","Jette le bidon vide",p,0),"Jeter le bidon vide","coolant_empty",-1,"trash")
			else:
				option = Repairs.step(self,bay,p,false,"fill_coolant","Faire l’appoint","coolant",1.35)
	return option

func in_front_of_car(index: int) -> bool:
	var center: Vector2 = site.bays[index].at
	return player.y<=center.y-1.95 and absf(player.x-center.x)<2.45

func repair_targets(index: int, decline: bool = false) -> Array[Dictionary]:
	var bay: Dictionary = site.bays[index]
	var order: Dictionary = bay.order
	var list: Array[Dictionary] = []
	for wheel in range(4):
		if not Repairs.wheel_needed(order,wheel): continue
		var at: Vector2 = bay.at+Map.WHEEL_OFFSETS[wheel]
		if decline and Repairs.active(order,"tires") and not tire_work_started(order):
			list.append(target("refuse","Refuser le changement de pneus",at,0.58,{"bay":index,"job":"tires"}))
		else:
			var option := wheel_action(order,wheel,at,index)
			var state: int = order.wheels[wheel]
			option.work_priority = 20 if state==2 else (10 if state>0 else 0)
			if option.has("work"):
				option.bay = index
				option.work.zone = "Roue "+Catalog.WHEEL_SIDES[wheel]
			list.append(option)
	for id in order.required:
		if id in Catalog.WHEEL_JOBS or id in order.done: continue
		var options: Array[Dictionary] = []
		if Map.SERVICE_OFFSETS.has(id): options.append(service_action(order,id,index,bay.at+Map.SERVICE_OFFSETS[id]))
		else: options = Repairs.service_actions(self,order,id,index,bay.at)
		for option in options:
			if option.is_empty(): continue
			option.work_priority = 10 if Repairs.started(order,id) else 0
			option.job = id
			if option.has("work"): option.bay = index
			list.append(option)
	return list

func candidates(decline: bool) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if coop!=null and not coop.processing_guest:
		var recover: Dictionary = coop.rescue_item(self)
		if not recover.is_empty(): list.append(recover)
	for id in site.stations:
		var p: Vector2 = site.station_point(id)
		if player.distance_squared_to(p)>7: continue
		var option := station_action(id,p)
		if not option.is_empty():
			if run.mode=="open": option["station"] = id
			list.append(option)
	var cashier := checkout_action()
	if not cashier.is_empty(): list.append(cashier)
	for tile in site.cells:
		var entry: Dictionary = site.cells[tile]
		if entry.kind=="station": continue
		var p: Vector2 = site.center(tile)
		if player.distance_squared_to(p)>6: continue
		if entry.kind=="cart" and held=="" and relocating=="" and not pulling_cart:
			var label := "Tracter le chariot"
			if cart_count>0: label += "   ·   Y / E prendre un pneu (%d / 4)"%cart_count
			list.append(target("cart",label,p,0.35))
		elif entry.kind=="stack":
			if held=="" and not pulling_cart:
				list.append(target("floor_pick","Prendre · "+item_name(entry.item),p,0.35,{"tile":tile}))
			elif pulling_cart and entry.item in ["new_tire","used_tire"] and cart_kind in ["",entry.item] and cart_count<4:
				list.append(target("cart_stack","Charger la pile",p,0.48,{"tile":tile}))
	if site.van.visible: list.append(target("vendor","Voir les offres de la fourgonnette",site.vendor_at-Vector2(0,0.65),0.0))
	for i in range(site.bays.size()):
		var bay: Dictionary = site.bays[i]
		if player.distance_squared_to(bay.lever_at)<7: list.append(lever_action(i))
		var seat: Vector2 = site.seats[i]
		if can_call_to_checkout(bay) and visitor_at(bay.order.id,seat):
			list.append(invite_to_checkout(bay.order,seat))
		if bay.status in ["intake","driving"]:
			list.append(driver_action(bay,i))
			continue
		if bay.status!="parked": continue
		var approval := approval_action(i,decline)
		if not approval.is_empty(): list.append(approval)
		elif order_ready(bay.order):
			list.append(driver_action(bay,i))
		list.append_array(repair_targets(i,decline))
	for parked in parked_cars.values():
		if not can_call_to_checkout(parked) or not visitors.has(parked.order.id): continue
		var position: Vector3 = visitors[parked.order.id].root.position
		list.append(invite_to_checkout(parked.order,Vector2(position.x,position.z)))
	return list

func approval_action(index: int, decline := false) -> Dictionary:
	var order: Dictionary = site.bays[index].order
	var seat: Vector2 = site.seats[index]
	if not visitor_at(order.id,seat): return {}
	if order.decision=="pending":
		var label := "Reporter la batterie" if decline else "Proposer le remplacement"
		return target("decline" if decline else "approve",label,seat,0.58,{"bay":index})
	if Repairs.active(order,"window") and Repairs.stage(order,"window")==2:
		var label := "Reporter le module" if decline else "Proposer le module · +%d $"%Catalog.WINDOW_MODULE_SURCHARGE
		return target("window_decline" if decline else "window_approve",label,seat,0.58,{"bay":index})
	return {}

func can_call_to_checkout(holder: Dictionary) -> bool:
	return holder.get("status") in ["parked","driving","outdoors"] and order_ready(holder.order) and (
		not holder.order.paid and holder.order.id not in checkout_queue)

func invite_to_checkout(order: Dictionary, point: Vector2) -> Dictionary:
	return target("call_checkout","Inviter %s à la caisse"%order.name,point,0,{"order_id":order.id})

func checkout_action() -> Dictionary:
	if checkout_queue.is_empty() or run.mode not in ["day","closing"]: return {}
	var point: Vector2 = site.checkout_at
	if not site.behind_reception(point,player): return {}
	var order := find_order(checkout_queue[0])
	if order.is_empty(): return {}
	if not visitor_at(order.id,site.checkout_head):
		return target("none","%s s’avance vers la caisse"%order.name,point,0)
	return target("payment","Encaisser · "+order.name,point,3.0,{"order_id":order.id})

func driver_door(bay: Dictionary) -> Vector2:
	return site.vehicle_position(bay)+Vector2(-1.55,0.34).rotated(PI-bay.car.rotation.y)

func driver_action(bay: Dictionary, index: int) -> Dictionary:
	var door := driver_door(bay)
	if not site.clear_at(door): door = site.vehicle_position(bay)*2.0-door
	if held!="" or pulling_cart:
		return target("none","Libère tes mains pour prendre le volant",door,0)
	var blocked := lift_requirement(index,false,door)
	if not blocked.is_empty(): return blocked
	if absf(bay.hood.rotation.x)>0.01:
		return target("none","Attends la fermeture du capot",door,0)
	return target("drive","Monter dans le véhicule de "+bay.order.name,door,0,{"bay":index})

func visitor_at(id: int, seat: Vector2) -> bool:
	if not visitors.has(id): return false
	var p: Vector3 = visitors[id].root.position
	return Vector2(p.x,p.z).distance_to(seat)<0.45

func tire_work_started(order: Dictionary) -> bool:
	return order.wheels.count(0)!=4

func can_refuse(order: Dictionary, id: String) -> bool:
	match id:
		"oil": return order.oil==0
		"battery": return order.battery==0
		"coolant": return not order.coolant
	return true

func context(decline := false) -> Dictionary:
	if run.mode in ["lost","won"] or relocating!="" or driven_bay>=0: return {}
	if office_seated:
		var phone: Vector2 = site.station_point("phone")
		var chair: Vector2 = site.station_point("office_chair")
		if chair.distance_to(phone)<=1.96: return station_action("phone",phone)
		return target("none","Chaise du bureau",chair,0)
	var best := {}
	var score := INF
	for option in candidates(decline):
		if coop!=null and not coop.allows(option): continue
		var p: Vector2 = option.at
		var distance := player.distance_to(p)
		if distance>1.96: continue
		if option.get("from_front",false) and not in_front_of_car(option.bay):
			var prompt := "Place-toi devant le capot" if option.work.zone=="Capot" else "Place-toi devant la voiture"
			option = target("none",prompt,p,0,{"work":option.work,"bay":option.bay})
		var alignment := facing.dot(player.direction_to(p)) if distance>0.05 else 1.0
		if not decline and option.id!="none" and distance<=1.70 and option.get("work",{}).get("zone")=="Capot":
			alignment = maxf(alignment,0.74)
		if alignment<0.42:
			if option.id!="call_checkout" or decline or distance>CUSTOMER_NEAR: continue
			alignment = 0.42
		var cost := distance+1.8*(1.0-alignment)
		if option.id=="none": cost += 0.42 if option.has("work") else 0.12
		if cost<score and site.can_see(player,p):
			best = option
			score = cost
	return best

func holds_used_tires() -> bool:
	return held=="used_tire" or (pulling_cart and cart_kind=="used_tire" and cart_count>0)

func advance_action(dt: float, pressed: bool, maintained: bool, decline := false) -> void:
	if not maintained:
		cancel_action()
		return
	var selected := context(decline)
	if selected.is_empty() or selected.id=="none":
		cancel_action()
		return
	if not action.is_empty() and (action.id!=selected.id or action.at!=selected.at or action.get("order_id")!=selected.get("order_id")):
		cancel_action()
	if action.is_empty():
		if not pressed: return
		action = selected
		progress = 0
	progress += dt
	if progress+0.00001>=action.seconds:
		var completed := action
		cancel_action()
		finish_action(completed)

func cancel_action() -> void:
	repair_pose.restore_wheel()
	action = {}
	progress = 0
	if is_instance_valid(ring): ring.hide()

func finish_action(a: Dictionary) -> void:
	match a.id:
		"start":
			game.store_checkpoint()
			if run.start():
				update_lift_speed()
				save_day_setup()
				site.van.hide()
		"call":
			inform("Un client supplémentaire est en route." if run.call_customer() else "La file et les rendez-vous sont complets.")
		"receive": accept_client()
		"sit":
			office_seated = true
			velocity = Vector2.ZERO
		"vendor": show_vendor()
		"rack_hand": set_held("new_tire")
		"rack_cart":
			cart_kind = "new_tire"
			cart_count = 4
			refresh_cart()
		"stock": set_held(a.item)
		"parts": show_parts(a.station)
		"puncture_test","puncture_patch","puncture_recycle","recycle_muffler": Repairs.finish_station(self,a)
		"return_supply","discard_supply": set_held("")
		"return_cart_stock": return_cart_stock()
		"surface": exchange_surface(a.station)
		"floor_pick": pick_stack(a.tile,false)
		"rescue_item":
			if coop!=null: coop.take_rescued_item(self)
		"cart_stack": pick_stack(a.tile,true)
		"cart":
			site.cells.erase(site.cart_cell)
			pulling_cart = true
			refresh_cart()
		"waste":
			var order := find_order(oil_pan_for)
			if not order.is_empty(): order.oil = 2
			oil_pan_for = -1
		"trash": discard_item()
		"call_checkout":
			var holder := find_customer_holder(a.order_id)
			if can_call_to_checkout(holder):
				checkout_queue.append(a.order_id)
				inform("%s rejoint la caisse à gauche du comptoir."%holder.order.name)
		"payment": complete_invoice(find_customer_holder(a.order_id))
		_:
			if a.has("bay"): finish_repair(a)

func find_customer_holder(id: int) -> Dictionary:
	if parked_cars.has(id): return parked_cars[id]
	for bay in site.bays:
		if not bay.order.is_empty() and bay.order.id==id: return bay
	return {}

func find_order(id: int) -> Dictionary:
	return find_customer_holder(id).get("order",{})

func exchange_surface(id: String) -> void:
	var station: Dictionary = site.stations[id]
	var top: Dictionary = station.get("top",{})
	var surface_turn := posmod(held_turn-int(station.turn),4) if held_turn>=0 else -1
	var pickup_turn := posmod(int(top.get("turn",-1))+int(station.turn),4) if top.get("turn",-1)>=0 else -1
	if top.is_empty():
		station.top = {"item":held,"count":1,"origin":held_origin,"turn":surface_turn}
		set_held("")
	elif held=="":
		set_held(top.item,top.origin,pickup_turn)
		top.count -= 1
	elif held=="new_tire" and top.item==held and top.count<4:
		top.count += 1
		set_held("")
	else:
		var old: Array = [top.item,top.origin]
		top.item = held
		top.origin = held_origin
		top.turn = surface_turn
		set_held(old[0],old[1],pickup_turn)
	top = station.top
	update_stack(top,station.root,Vector3(0,station.height+0.09,0))
	if top.count==0: station.erase("top")

func discard_item() -> void:
	var order := find_order(held_origin)
	if not order.is_empty():
		match held:
			"empty_bottle": order.done.append("oil")
			"coolant_empty": order.done.append("coolant")
			"old_battery": order.battery = 2
	set_held("")

func finish_repair(a: Dictionary) -> void:
	var bay: Dictionary = site.bays[a.bay]
	var order: Dictionary = bay.order
	match a.id:
		"validate_lift":
			confirm_intake(a.bay)
			bay.lift_raised = true
			inform("✓ Véhicule en place · montée du pont.")
		"lift":
			bay.lift_raised = not bay.lift_raised
		"drive":
			if bay.status!="intake": bay.status = "driving"
			driven_bay = a.bay
			drive_speed = 0.0
			drive_steering = 0.0
			velocity = Vector2.ZERO
			seat_blend = 0.0
			player = site.vehicle_position(bay)
			engine.pitch_scale = 1.0
			engine.play()
			game.avatar.hide()
			if bay.status=="intake":
				inform("Entre par la porte du bas et aligne la voiture en baie %02d."%(a.bay+1))
			else: inform("Sors la voiture et stationne-la sur une place P libre.")
		"approve":
			order.decision = "approved"
			order.required.append("battery")
		"refuse":
			order.required.erase(a.job)
			run.penalty()
			inform("Réparation refusée · −½ étoile")
		"decline":
			order.decision = "declined"
			run.penalty()
			inform("Réparation refusée · −½ étoile")
		"wheel":
			complete_wheel_step(a.wheel,order,bay)
		"inspection":
			order.done.append("inspection")
			if order.issue!="":
				order.decision = "pending"
				inform("Batterie faible. Va voir "+order.name+" en salle d’attente.")
		"pressure": order.done.append("pressure")
		"drain":
			if run.purchases.has("oil_recovery"):
				order.oil = 2
				inform("Huile usée récupérée · prends de l’huile neuve.")
			else:
				order.oil = 1
				oil_pan_for = order.id
		"fill_oil":
			order.oil = 3
			set_held("empty_bottle",order.id)
		"remove_battery":
			order.battery = 1
			set_held("old_battery",order.id)
		"install_battery":
			set_held("")
			order.done.append("battery")
		"fill_coolant":
			order.coolant = true
			set_held("coolant_empty",order.id)
		_: Repairs.finish_vehicle(self,a,order,bay)

func complete_wheel_step(wheel: int, order: Dictionary, bay: Dictionary) -> void:
	var punctured := Repairs.wheel_is_punctured(order,wheel)
	var replace := Repairs.wheel_needs_new(order,wheel)
	match order.wheels[wheel]:
		1:
			if punctured:
				set_held("repair_wheel",order.id)
			elif replace:
				if pulling_cart:
					cart_kind = "used_tire"
					cart_count += 1
				else: set_held("used_tire")
			else: site.store_wheel(bay,wheel)
			bay.tires[wheel].hide()
			bay.discs[wheel].show()
		2:
			if replace and pulling_cart:
				cart_count -= 1
				if cart_count==0: cart_kind = ""
			elif replace or punctured: set_held("")
			else: site.clear_stored_wheel(bay,wheel)
			bay.tires[wheel].show()
			bay.discs[wheel].hide()
	order.wheels[wheel] += 1
	Repairs.complete_wheels(order)
	refresh_cart()


func pick_stack(tile: Vector2i, bulk: bool) -> void:
	var stack: Dictionary = site.cells[tile]
	if bulk:
		var amount := mini(4-cart_count,int(stack.count))
		cart_count += amount
		cart_kind = stack.item
		stack.count -= amount
		refresh_cart()
	else:
		set_held(stack.item,stack.origin,stack.get("turn",-1))
		stack.count -= 1
	refresh_floor_stack(tile,stack)

func refresh_floor_stack(tile: Vector2i, stack: Dictionary) -> void:
	var p: Vector2 = site.center(tile)
	update_stack(stack,site,Vector3(p.x,0.18,p.y))
	if stack.count==0: site.cells.erase(tile)

func stack_contents(stack: Dictionary) -> Dictionary:
	return {"item":stack.item,"count":stack.count,"origin":stack.origin,"turn":stack.get("turn",-1)}

func save_day_setup() -> void:
	day_setup = equipment_snapshot()

func equipment_snapshot() -> Dictionary:
	var surfaces := {}
	for id in site.stations:
		var top: Dictionary = site.stations[id].get("top",{})
		if not top.is_empty(): surfaces[id] = stack_contents(top)
	var floor_stacks := {}
	for tile in site.cells:
		var entry: Dictionary = site.cells[tile]
		if entry.kind=="stack": floor_stacks[tile] = stack_contents(entry)
	return {"surfaces":surfaces,"floor_stacks":floor_stacks,"cart_cell":site.cart_cell,
		"cart_kind":cart_kind,"cart_count":cart_count,"cart_turn":cart_turn,"pulling_cart":pulling_cart,
		"held":held,"held_origin":held_origin,"held_turn":held_turn}

func restore_day_setup() -> void:
	if day_setup.is_empty(): return
	if not pulling_cart: site.cells.erase(site.cart_cell)
	for tile in site.cells.keys():
		var entry: Dictionary = site.cells[tile]
		if entry.kind=="stack":
			entry.count = 0
			refresh_floor_stack(tile,entry)
	for id in site.stations:
		var station: Dictionary = site.stations[id]
		if station.has("top"):
			station.top.count = 0
			update_stack(station.top,station.root,Vector3.ZERO)
			station.erase("top")
		if day_setup.surfaces.has(id):
			station.top = day_setup.surfaces[id]
			update_stack(station.top,station.root,Vector3(0,station.height+0.09,0))
	for tile in day_setup.floor_stacks:
		var stack: Dictionary = day_setup.floor_stacks[tile]
		stack["kind"] = "stack"
		site.cells[tile] = stack
		refresh_floor_stack(tile,stack)
	site.cart_cell = day_setup.cart_cell
	cart_kind = day_setup.cart_kind
	cart_count = day_setup.cart_count
	cart_turn = day_setup.get("cart_turn",0)
	pulling_cart = day_setup.pulling_cart
	if not pulling_cart: site.cells[site.cart_cell] = {"kind":"cart"}
	refresh_cart()
	set_held(day_setup.held,day_setup.held_origin,day_setup.get("held_turn",-1))
	oil_pan_for = -1
	day_setup.clear()

func keep_player_clear() -> void:
	var entrance := Vector2i(3,17)
	if site.clear_at(player) and reachable_tiles(player,true).has(entrance): return
	var nearest := INF
	var safe := player
	for tile in reachable_tiles(site.center(entrance),false):
		var point: Vector2 = site.center(tile)
		var distance := player.distance_squared_to(point)
		if distance<nearest:
			nearest = distance
			safe = point
	player = safe
	velocity = Vector2.ZERO


func drop_cell() -> Vector2i:
	return site.cell(player+facing*1.03)

func can_drop(tile: Vector2i,id: String) -> bool:
	var point: Vector2 = site.center(tile)
	var footprint := Rect2(Vector2(tile),Vector2.ONE)
	var furniture := id==relocating and relocating!=""
	if furniture: footprint = Rect2(site.station_footprint(id,tile,relocating_turn))
	if footprint.grow(Map.PLAYER_RADIUS+0.015).has_point(player): return false
	if coop!=null and coop.blocks_placement(footprint.grow(Map.PLAYER_RADIUS+0.015)): return false
	if not site.can_see(player,point): return false
	if furniture:
		for occupied in site.station_tiles(id,tile,relocating_turn):
			if site.blocks_traffic(occupied) or not site.placement_ok(occupied,id): return false
		return true
	if id not in ["cart","used_tire","new_tire","repair_wheel"]: return false
	if site.blocks_traffic(tile): return false
	for approach in site.reception_approaches(site.station_point("reception"),site.stations.reception.turn):
		if tile==site.cell(approach): return false
	for holder in site.car_holders:
		var shape: PackedVector2Array = site.vehicle_shape(site.vehicle_position(holder),holder.car.rotation.y)
		if site.hits_rectangle(shape,site.vehicle_bounds(shape),footprint): return false
	if site.cells.has(tile):
		var stack: Dictionary = site.cells[tile]
		return stack.kind=="stack" and id in ["used_tire","new_tire"] and stack.item==id and stack.count<4
	if site.blocked_tile(tile): return false
	if id=="cart": return site.clear_at(point,0.1)
	return site.placement_ok(tile,id)

func place_or_move() -> void:
	if office_seated: return
	var tile := drop_cell()
	if pulling_cart:
		if can_drop(tile,"cart") and layout_route_ok(tile):
			pulling_cart = false
			site.cart_cell = tile
			site.cells[tile] = {"kind":"cart"}
			refresh_cart()
		else: inform("Vise une case libre et garde un passage pour garer le chariot.")
		return
	if held!="":
		var selected := context()
		if selected.get("id")=="return_supply": set_held("")
		elif selected.get("id")=="surface" and selected.seconds==0.0: exchange_surface(selected.station)
		elif can_drop(tile,held) and layout_route_ok(tile): drop_stack(tile,held,1)
		elif held in ["new_tire","used_tire","repair_wheel"]: inform("Vise une case libre ou une pile de moins de quatre pneus du même type.")
		else: inform("Vise un comptoir libre pour déposer "+item_name(held)+".")
		return
	if relocating!="":
		if can_drop(tile,relocating) and layout_route_ok(tile,true):
			site.move_station(relocating,tile,relocating_turn)
			relocating = ""
		else: inform("Garde un passage vers les postes et la sortie.")
		return
	var selected := context()
	if selected.get("id")=="cart" and cart_count>0:
		set_held(cart_kind)
		cart_count -= 1
		if cart_count==0: cart_kind = ""
		cancel_action()
		refresh_cart()
		return
	if run.mode=="open" and selected.has("station"):
		relocating = selected.station
		relocating_turn = site.stations[relocating].turn
		site.remove_station_cells(relocating)
		cancel_action()
		inform("Vise une case libre pour installer le meuble.")

func rotate_or_unload() -> void:
	if relocating!="":
		relocating_turn = (relocating_turn+1)%4
	elif held!="":
		var turn := held_turn
		if turn<0: turn = roundi(-atan2(facing.x,facing.y)/(PI/2.0))
		held_turn = posmod(turn+1,4)
	elif pulling_cart:
		empty_cart()
		return
	elif context().get("id")=="cart":
		cart_turn = (cart_turn+1)%4
		refresh_cart()
	else: return
	game.player_visual.trigger("rotate")

func return_cart_stock() -> void:
	cart_count = 0
	cart_kind = ""
	refresh_cart()

func empty_cart() -> void:
	if not pulling_cart or cart_count==0: return
	if cart_kind=="new_tire" and context().get("id") in ["rack_cart","return_cart_stock"]:
		return_cart_stock()
		return
	var tile := drop_cell()
	if not can_drop(tile,cart_kind) or not layout_route_ok(tile):
		inform("Vise une case libre ou une pile du même type et garde un passage.")
		return
	var room := 4-int(site.cells.get(tile,{}).get("count",0))
	drop_stack(tile,cart_kind,mini(cart_count,room))

func drop_stack(tile: Vector2i,id: String,count: int) -> void:
	var stack: Dictionary = site.cells.get(tile,{"kind":"stack","item":id,"count":0,"origin":held_origin,"turn":held_turn})
	stack.count += count
	site.cells[tile] = stack
	refresh_floor_stack(tile,stack)
	if pulling_cart:
		cart_count -= count
		if cart_count==0: cart_kind = ""
		refresh_cart()
	else: set_held("")

func walk_segment_clear(from: Vector2, to: Vector2) -> bool:
	for step in range(1,5):
		if not site.clear_at(from.lerp(to,step/4.0)): return false
	return true

func reachable_tiles(origin: Vector2, stop_at_entrance: bool) -> Dictionary:
	var entrance := Vector2i(3,17)
	var visited := {}
	var queue: Array[Vector2i] = []
	var start: Vector2i = site.cell(origin)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var nearby := start+Vector2i(dx,dz)
			if not walk_segment_clear(origin,site.center(nearby)): continue
			visited[nearby] = true
			queue.append(nearby)
	var read := 0
	while read<queue.size():
		var current := queue[read]
		read += 1
		if stop_at_entrance and current==entrance: break
		var from: Vector2 = site.center(current)
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+offset
			if visited.has(next) or not walk_segment_clear(from,site.center(next)): continue
			visited[next] = true
			queue.append(next)
	return visited

func layout_route_ok(tile: Vector2i, furniture := false) -> bool:
	if site.cells.has(tile): return true
	var entrance := Vector2i(3,17)
	var footprint: Array[Vector2i] = [tile]
	if furniture: footprint = site.station_tiles(relocating,tile,relocating_turn)
	for occupied in footprint: site.cells[occupied] = {"kind":"preview"}
	var visited := reachable_tiles(player,not furniture)
	var ok := visited.has(entrance)
	if ok and furniture: ok = furniture_routes_ok(visited,relocating,tile,relocating_turn)
	for occupied in footprint: site.cells.erase(occupied)
	if not ok and not furniture:
		var previous := reachable_tiles(player,true)
		return not previous.has(entrance) and visited.size()+1>=previous.size()
	return ok

func furniture_routes_ok(visited: Dictionary, moved := "", new_tile := Vector2i.ZERO, new_turn := 0) -> bool:
	if not visited.has(Vector2i(3,17)) or not visited.has(site.cell(Map.PEDESTRIAN_ACCESS)): return false
	var counter: Vector2 = site.station_point("reception")
	var reception_turn: int = site.stations.reception.turn
	if moved=="reception":
		counter = Rect2(site.station_footprint("reception",new_tile,new_turn)).get_center()
		reception_turn = new_turn
	for point in site.reception_approaches(counter,reception_turn):
		if not visited.has(site.cell(point)) or not site.clear_at(point,0.16): return false
	for id in site.stations:
		var anchor: Vector2i = new_tile if id==moved else site.stations[id].tile
		if not interaction_reachable(visited,site.station_tiles(id,anchor,new_turn if id==moved else -1)): return false
	for bay in site.bays:
		if not interaction_reachable(visited,[site.cell(bay.lever_at)]): return false
	return true

func interaction_reachable(visited: Dictionary, tiles: Array[Vector2i]) -> bool:
	for tile in tiles:
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if visited.has(tile+offset) and site.can_see(site.center(tile+offset),site.center(tile)):
				return true
	return false

func advance_cars(dt: float) -> void:
	for bay in site.bays:
		var gate: Node3D = bay.gates[1]
		gate.position.y = move_toward(gate.position.y,2.7 if bay.status=="intake" else 0.0,dt*7)
		gate.visible = gate.position.y<2.65
		var exit_gate: Node3D = bay.gates[0]
		exit_gate.position.y = move_toward(exit_gate.position.y,2.7 if bay.status=="driving" else 0.0,dt*7)
		exit_gate.visible = exit_gate.position.y<2.65
	advance_incoming(dt)
	advance_departures(dt)

func available_arrival_space() -> int:
	var occupied := {}
	for arrival in incoming.values(): occupied[arrival.slot] = true
	for bay in site.bays:
		if bay.status=="intake": occupied[bay.arrival_slot] = true
	for i in range(site.bays.size()):
		if site.bays[i].status=="" and not occupied.has(i): return i
	for i in range(site.arrivals.size()):
		if not occupied.has(i): return i
	return -1

func queue_incoming_car() -> void:
	if run.mode!="day" or run.waiting.is_empty(): return
	var slot := available_arrival_space()
	if slot<0: return
	for order in run.waiting:
		if incoming.has(order.id): continue
		var center: Vector2 = site.arrivals[slot].get_center()
		var entry := Vector2(site.size.x+3.6,Map.ARRIVAL_ROAD_LANE)
		var turn := Vector2(center.x+2.85,Map.ARRIVAL_ROAD_LANE)
		var straight := Vector2(center.x,Map.ARRIVAL_ROAD_LANE-2.85)
		var curve := Curve2D.new()
		curve.bake_interval = 0.12
		curve.add_point(entry,Vector2.ZERO,Vector2.LEFT*1.1)
		curve.add_point(turn,Vector2.RIGHT*1.1,Vector2.LEFT*1.6)
		curve.add_point(straight,Vector2.DOWN*1.6,Vector2.UP*1.8)
		curve.add_point(center,Vector2.DOWN*1.8)
		var arrival := {"slot":slot,"stage":"drive","curve":curve,"distance":0.0,"speed":0.0}
		site.spawn_car(arrival,order,entry,-PI/2)
		incoming[order.id] = arrival
		incoming_driver = order.id
		return

func curve_heading(curve: Curve2D, distance: float, reversing := false) -> float:
	var tangent := curve.sample_baked(minf(curve.get_baked_length(),distance+0.08))-curve.sample_baked(maxf(0.0,distance-0.08))
	if reversing: tangent = -tangent
	return atan2(tangent.x,tangent.y)

func move_traffic_vehicle(holder: Dictionary, next: Vector2, yaw: float) -> bool:
	if coop!=null and coop.blocks_vehicle(next,yaw,Map.CAR_HALF,Map.PLAYER_RADIUS): return false
	var local_player := (player-next).rotated(yaw).abs()
	if local_player.x<Map.CAR_HALF.x+Map.PLAYER_RADIUS and local_player.y<Map.CAR_HALF.y+Map.PLAYER_RADIUS:
		return false
	if not site.vehicle_can_move(holder,next,yaw,true): return false
	holder.car.position.x = next.x
	holder.car.position.z = next.y
	holder.car.rotation.y = yaw
	return true

func advance_incoming(dt: float) -> void:
	if incoming_driver<0: queue_incoming_car()
	if incoming_driver<0: return
	var arrival: Dictionary = incoming[incoming_driver]
	var curve: Curve2D = arrival.curve
	var length := curve.get_baked_length()
	var speed := clampf((length-arrival.distance)*2.8,2.05,7.5)
	arrival.speed = move_toward(arrival.speed,speed,dt*6.5)
	var steps := maxi(1,ceili(arrival.speed*dt/0.13))
	for step in range(steps):
		var distance := minf(length,arrival.distance+arrival.speed*dt/steps)
		var yaw := PI if is_equal_approx(distance,length) else curve_heading(curve,distance)
		if not move_traffic_vehicle(arrival,curve.sample_baked(distance),yaw):
			arrival.speed = 0.0
			return
		arrival.distance = distance
		if is_equal_approx(distance,length):
			arrival.stage = "unboard"
			arrival.unboard_time = 0.0
			incoming_driver = -1
			return

func driving_axis(value: float, response: float) -> float:
	var magnitude := clampf((absf(value)-0.16)/0.84,0.0,1.0)
	return signf(value)*pow(magnitude,response)

func driving_guide(bay: Dictionary, point: Vector2, yaw: float, destination: Vector2) -> float:
	var door_z := 16.93 if bay.status=="intake" else 0.07
	var range_z := minf(absf(point.y-door_z),absf(point.y-destination.y))
	var off_axis := absf(point.x-destination.x)
	var heading := absf(wrapf(yaw,-PI/2,PI/2))
	var proximity := 1.0-smoothstep(3.1,6.7,range_z)
	var alignment := 1.0-smoothstep(0.48,1.27,off_axis)
	return proximity*alignment*(1.0-smoothstep(0.32,0.62,heading))

func drive_vehicle(input: Vector2, dt: float, braking := false) -> void:
	var bay: Dictionary = site.bays[driven_bay]
	var throttle := 0.0 if braking else -driving_axis(input.y,1.45)
	var steering := driving_axis(input.x,1.55)
	drive_steering = move_toward(drive_steering,steering,dt*(10.0 if steering!=0.0 else 15.0))
	steer_front_wheels(bay,-drive_steering*0.56)

	var point: Vector2 = site.vehicle_position(bay)
	var destination: Vector2 = bay.at if bay.status=="intake" else bay.parking.get_center()
	if bay.status=="driving" and point.y<-2.5:
		var slot := nearest_exit_slot(bay)
		if slot>=0: destination = site.bays[slot].parking.get_center()
	var guide := driving_guide(bay,point,bay.car.rotation.y,destination)
	var speed_limit := FORWARD_SPEED if throttle>=0.0 else REVERSE_SPEED
	speed_limit = minf(speed_limit,lerpf(2.0,FORWARD_SPEED,smoothstep(1.6,4.0,point.distance_to(destination))))
	speed_limit = minf(speed_limit,lerpf(FORWARD_SPEED,3.1,guide))
	var target_speed := throttle*speed_limit
	var changing_direction := target_speed*drive_speed<0.0
	var acceleration := 8.5
	if braking or changing_direction:
		target_speed = 0.0
		acceleration = 30.0
	elif absf(target_speed)<absf(drive_speed): acceleration = 22.0
	drive_speed = move_toward(drive_speed,target_speed,dt*acceleration)
	var pace := absf(drive_speed)
	engine.pitch_scale = lerpf(1.0,1.82,clampf(pace/FORWARD_SPEED,0.0,1.0))

	var travel := drive_speed*dt
	var turn_rate := lerpf(1.04,1.30,smoothstep(0.2,3.4,pace))*smoothstep(0.0,1.5,pace)
	var turn := -drive_steering*turn_rate*dt
	if drive_speed<0.0: turn = -turn
	if is_zero_approx(travel) and is_zero_approx(turn): return
	var steps := maxi(1,ceili(maxf(absf(travel)/0.10,absf(turn)/0.06)))
	for step in range(steps):
		if not drive_step(bay,travel/steps,turn/steps,dt/steps,absf(steering)<0.08,destination):
			drive_speed = 0.0
			return

func steer_front_wheels(bay: Dictionary, angle: float) -> void:
	for wheel in Catalog.FRONT_WHEELS:
		bay.tires[wheel].rotation.y = angle

func drive_step(bay: Dictionary, travel: float, turn: float, dt: float, assist: bool, destination: Vector2) -> bool:
	var point: Vector2 = site.vehicle_position(bay)
	var old_yaw: float = bay.car.rotation.y
	var yaw := old_yaw+turn
	var guide := driving_guide(bay,point,old_yaw,destination) if assist and absf(travel)>0.001 else 0.0
	if guide>0.0:
		var parallel_yaw := PI if cos(old_yaw)<0.0 else 0.0
		yaw = rotate_toward(yaw,parallel_yaw,2.65*guide*dt)
	var next := point+Vector2(sin(yaw),cos(yaw))*travel
	if guide>0.0:
		next.x = move_toward(next.x,destination.x,absf(travel)*0.86*guide)
	if can_drive_to(bay,next,yaw):
		apply_vehicle_pose(bay,next,yaw)
		return true
	if absf(travel)>0.001 and (guide>0.0 or not is_equal_approx(yaw,old_yaw)):
		var straight := point+Vector2(sin(old_yaw),cos(old_yaw))*travel
		if can_drive_to(bay,straight,old_yaw):
			apply_vehicle_pose(bay,straight,old_yaw)
			return true
	if can_drive_to(bay,point,yaw): apply_vehicle_pose(bay,point,yaw)
	return false

func can_drive_to(bay: Dictionary, point: Vector2, yaw: float) -> bool:
	if coop!=null and coop.blocks_vehicle(point,yaw,Map.CAR_HALF,Map.PLAYER_RADIUS): return false
	return site.vehicle_can_move(bay,point,yaw)

func apply_vehicle_pose(bay: Dictionary, point: Vector2, yaw: float) -> void:
	bay.car.position.x = point.x
	bay.car.position.z = point.y
	bay.car.rotation.y = yaw
	if driven_bay>=0: player = point

func exit_slot_free(slot: int) -> bool:
	for parked in parked_cars.values():
		if parked.exit_slot==slot: return false
	return true

func nearest_exit_slot(bay: Dictionary) -> int:
	var center: Vector2 = site.vehicle_position(bay)
	var nearest := -1
	var distance := INF
	for i in range(site.bays.size()):
		if not exit_slot_free(i): continue
		var slot: Rect2 = site.bays[i].parking
		var offset := absf(center.x-slot.get_center().x)
		if offset<distance:
			nearest = i
			distance = offset
	return nearest

func waiting_by_parking(index: int) -> Vector2:
	var bay: Dictionary = site.bays[index]
	for offset in range(site.bays.size()):
		var slot: int = (index+offset)%site.bays.size()
		if not exit_slot_free(slot): continue
		if site.bays.any(func(other: Dictionary) -> bool: return other!=bay and other.get("wait_slot",-1)==slot): continue
		var area: Rect2 = site.bays[slot].parking
		for side in [-1,1]:
			var point := area.get_center()+Vector2(side*(area.size.x*0.5+0.60),0)
			if site.clear_at(point,0.16):
				bay.wait_slot = slot
				return point
	bay.erase("wait_slot")
	return Map.PEDESTRIAN_ACCESS

func parking_ready(bay: Dictionary, margin := 0.0) -> bool:
	var slot: int = bay.exit_slot if bay.has("exit_slot") else nearest_exit_slot(bay)
	if slot<0: return false
	var area: Rect2 = site.bays[slot].parking
	var shape: PackedVector2Array = site.vehicle_shape(site.vehicle_position(bay),bay.car.rotation.y)
	return area.grow(margin).encloses(site.vehicle_bounds(shape))

func parking_placement(bay: Dictionary) -> Dictionary:
	var slot := nearest_exit_slot(bay)
	if slot<0: return {"status":ParkingStatus.FULL,"slot":-1}
	if not parking_ready(bay,PARKING_MARGIN):
		var reserved: int = bay.get("wait_slot",-1)
		return {"status":ParkingStatus.ALIGN,"slot":reserved if reserved>=0 and exit_slot_free(reserved) else slot}
	if absf(drive_speed)>PARKING_SPEED: return {"status":ParkingStatus.SLOW,"slot":slot}
	var center: Vector2 = site.vehicle_position(bay)
	var yaw: float = bay.car.rotation.y
	if not parking_ready(bay):
		center = site.bays[slot].parking.get_center()
		yaw = PI if cos(yaw)<0.0 else 0.0
	var step := driver_exit_point(center,yaw)
	if step==Vector2.INF or not site.vehicle_can_move(bay,center,yaw):
		return {"status":ParkingStatus.BLOCKED,"slot":slot}
	return {"status":ParkingStatus.READY,"slot":slot,"center":center,"yaw":yaw,"step":step}

func parking_prompt(status: ParkingStatus, index: int) -> String:
	match status:
		ParkingStatus.SLOW: return "Bien aligné · relâche le stick gauche pour freiner."
		ParkingStatus.BLOCKED: return "Dégage la place ou le passage à côté de la voiture."
		ParkingStatus.READY: return "✓ Bien placé · Y / E stationner et descendre"
		ParkingStatus.FULL: return "Stationnement plein · attends qu’une place se libère."
	return "Rejoins la place P %02d par la porte du haut."%(index+1)

func intake_status(bay: Dictionary) -> IntakeStatus:
	var offset: Vector2 = site.vehicle_position(bay)-bay.at
	if absf(offset.y)>4.0 or absf(offset.x)>3.0: return IntakeStatus.APPROACH
	if absf(angle_difference(bay.car.rotation.y,PI))>0.28: return IntakeStatus.TURN
	if offset.x>0.66: return IntakeStatus.LEFT
	if offset.x<-0.66: return IntakeStatus.RIGHT
	if offset.y>1.0: return IntakeStatus.FORWARD
	if offset.y<-1.0: return IntakeStatus.BACK
	if absf(drive_speed)>PARKING_SPEED: return IntakeStatus.SLOW
	if not site.vehicle_can_move(bay,bay.at,PI) or driver_exit_point(bay.at,PI)==Vector2.INF:
		return IntakeStatus.BLOCKED
	return IntakeStatus.READY

func intake_prompt(status: IntakeStatus) -> String:
	match status:
		IntakeStatus.APPROACH: return "Rejoins le pont par la porte du bas."
		IntakeStatus.TURN: return "Oriente le capot vers le haut de l’écran."
		IntakeStatus.LEFT: return "Décale-toi vers la gauche."
		IntakeStatus.RIGHT: return "Décale-toi vers la droite."
		IntakeStatus.FORWARD: return "Avance encore un peu."
		IntakeStatus.BACK: return "Recule un peu."
		IntakeStatus.SLOW: return "Bien aligné · relâche le stick gauche pour freiner."
		IntakeStatus.BLOCKED: return "Dégage le pont ou le passage à côté de la voiture."
	return "Position correcte sur le pont."

func driver_exit_point(center: Vector2, yaw: float) -> Vector2:
	var side := Vector2.LEFT.rotated(PI-yaw)
	for offset in [side*1.65,-side*1.65,side*2.0,-side*2.0]:
		var step: Vector2 = center+offset
		if site.clear_at(step): return step
	return Vector2.INF

func confirm_intake(index: int) -> void:
	var bay: Dictionary = site.bays[index]
	apply_vehicle_pose(bay,bay.at,PI)
	bay.status = "parked"
	bay.erase("arrival_slot")
	accepted_intakes.erase(index)

func exit_driver_seat(park: bool) -> void:
	var index := driven_bay
	var bay: Dictionary = site.bays[index]
	var entering: bool = bay.status=="intake"
	var center: Vector2 = site.vehicle_position(bay)
	var yaw: float = bay.car.rotation.y
	var step := Vector2.INF
	var placement_slot := -1
	if not park and absf(drive_speed)>0.22:
		inform("Relâche le stick gauche pour t’arrêter.")
		return
	if entering:
		var status := intake_status(bay)
		if status==IntakeStatus.READY:
			park = true
			center = bay.at
			yaw = PI
		elif park:
			inform(intake_prompt(status))
			return
	else:
		var placement := parking_placement(bay)
		if placement.status==ParkingStatus.READY:
			park = true
			center = placement.center
			yaw = placement.yaw
			step = placement.step
			placement_slot = placement.slot
		elif park:
			inform(parking_prompt(placement.status,placement.slot))
			return
	if step==Vector2.INF: step = driver_exit_point(center,yaw)
	if step==Vector2.INF:
		inform("Laisse de la place autour de la voiture pour descendre.")
		return
	if park and not entering: apply_vehicle_pose(bay,center,yaw)
	player = step
	facing = player.direction_to(center)
	game.avatar.show()
	engine.stop()
	steer_front_wheels(bay,0.0)
	driven_bay = -1
	drive_speed = 0.0
	drive_steering = 0.0
	if park and entering:
		confirm_intake(index)
		inform("✓ Véhicule en place · les réparations peuvent commencer.")
	elif park:
		complete_parking(index,placement_slot)
	elif entering:
		inform("Reprends le volant et aligne le véhicule sur le pont.")
	else:
		inform("Reprends le volant et valide une place de sortie quand elle passe au vert.")

func complete_parking(index: int, slot: int) -> void:
	var bay: Dictionary = site.bays[index]
	var order: Dictionary = bay.order
	var parked := {"status":"outdoors","order":order,"exit_slot":slot}
	site.transfer_car(bay,parked)
	parked_cars[order.id] = parked
	bay.order = {}
	bay.status = ""
	bay.erase("wait_slot")
	if order.paid:
		begin_departure(parked)
		inform("%s rejoint sa voiture."%order.name)
	else:
		inform("Voiture stationnée · encaisse %s à la caisse."%order.name)
	assign_waiting_customers()

func complete_invoice(holder: Dictionary) -> void:
	var order: Dictionary = holder.get("order",{})
	if order.is_empty() or order.paid or checkout_queue.is_empty() or checkout_queue[0]!=order.id: return
	if not order_ready(order) or not visitor_at(order.id,site.checkout_head): return
	var amount := 0
	for id in order.done: amount += JOBS[id][1]
	if "window" in order.done and order.service.get("module_approved",false):
		amount += Catalog.WINDOW_MODULE_SURCHARGE
	amount += run.loyalty_bonus(order)
	if site.amenity_active("vending"): amount = roundi(amount*1.05)
	run.invoice(order,amount)
	order.paid = true
	checkout_queue.pop_front()
	if holder.status=="outdoors": begin_departure(holder)
	else: waiting_by_parking(site.bays.find(holder))
	var visual: Dictionary = visitors[order.id]
	visual.receipt.text = "+%d $"%amount
	visual.receipt_left = RECEIPT_SECONDS
	visual.meter.hide()
	visual.receipt.show()
	notice_time = 0.0

func begin_departure(bay: Dictionary) -> void:
	bay.status = "departing"
	var door := driver_door(bay)
	if not site.clear_at(door): door = site.vehicle_position(bay)*2.0-door
	var id: int = bay.order.id
	var outside: bool = visitors.has(id) and visitors[id].root.position.z<0.0
	departures[id] = {"bay":bay,"door":door,"stage":"walk","outdoors":outside}

func passenger_departure(id: int, departure: Dictionary, dt: float) -> void:
	var bay: Dictionary = departure.bay
	if departure.stage=="walk":
		if not departure.outdoors and visitor_at(id,Map.PEDESTRIAN_ACCESS): departure.outdoors = true
		var goal: Vector2 = departure.door if departure.outdoors else Map.PEDESTRIAN_ACCESS
		visitor(bay.order,goal,false,dt)
		if departure.outdoors and visitor_at(id,goal):
			departure.stage = "board"
			departure.board_time = 0.0
			departure.board_start = visitors[id].root.position
		return
	if departure.stage!="board": return
	var node: Node3D = visitors[id].root
	var end: Vector3 = bay.car.to_global(Vector3(0.34,0.48,-0.27))
	departure.board_time = move_toward(departure.board_time,1.0,dt/0.45)
	var weight := smoothstep(0.0,1.0,departure.board_time)
	var toward := end-node.position
	node.rotation.y = atan2(toward.x,toward.z)
	node.position = departure.board_start.lerp(end,weight)
	node.scale.y = lerpf(1.0,0.72,weight)
	if departure.board_time<1.0: return
	if bay.order.vehicle==2:
		node.reparent(bay.car,true)
		node.rotation.y = 0.0
	else:
		node.hide()
	departure.stage = "ready"

func departure_route(departure: Dictionary) -> void:
	var bay: Dictionary = departure.bay
	var center: Vector2 = site.vehicle_position(bay)
	var forward := Vector2(sin(bay.car.rotation.y),cos(bay.car.rotation.y))
	var reversing := forward.y>0
	var motion := -forward if reversing else forward
	var area: Rect2 = site.bays[bay.exit_slot].parking
	var merge := Vector2(area.get_center().x,-12.15)
	var turn := -1.0 if reversing else 1.0
	var road := Vector2(merge.x+turn*2.85,Map.ROAD_LANE)
	var curve := Curve2D.new()
	curve.bake_interval = 0.12
	var lead := center.distance_to(merge)*0.33
	curve.add_point(center,Vector2.ZERO,motion*lead)
	curve.add_point(merge,Vector2.DOWN*lead,Vector2.UP*1.6)
	curve.add_point(road,Vector2(-turn*1.6,0))
	departure.curve = curve
	departure.distance = 0.0
	departure.progress_speed = 0.0
	departure.reversing = reversing
	departure.stage = "drive"

func advance_departures(dt: float) -> void:
	if road_customer<0:
		for id in departures:
			if departures[id].stage!="ready": continue
			road_customer = id
			departure_route(departures[id])
			break
	if road_customer<0: return
	var departure: Dictionary = departures[road_customer]
	var bay: Dictionary = departure.bay
	var curve: Curve2D = departure.curve
	var backing: bool = departure.stage=="drive" and departure.reversing
	var speed := 3.7 if backing else (5.6 if departure.stage=="drive" else 8.0)
	departure.progress_speed = move_toward(departure.progress_speed,speed,dt*5.0)
	var length := curve.get_baked_length()
	var steps := maxi(1,ceili(departure.progress_speed*dt/0.13))
	for step in range(steps):
		var next_distance: float = departure.distance+departure.progress_speed*dt/steps
		var next: Vector2
		var yaw: float
		if departure.stage=="drive":
			next_distance = minf(length,next_distance)
			next = curve.sample_baked(next_distance)
			yaw = PI/2 if is_equal_approx(next_distance,length) else curve_heading(curve,next_distance,backing)
		else:
			next = site.vehicle_position(bay)+Vector2.RIGHT*departure.progress_speed*dt/steps
			yaw = PI/2
		if not move_traffic_vehicle(bay,next,yaw):
			departure.progress_speed = 0.0
			return
		departure.distance = next_distance
		if departure.stage=="drive" and is_equal_approx(next_distance,length):
			departure.stage = "road"
			if backing: departure.progress_speed = 0.0
			return
		if departure.stage=="road" and next.x>=site.size.x+3.5:
			finish_departure(bay)
			return

func finish_departure(bay: Dictionary) -> void:
	departures.erase(bay.order.id)
	parked_cars.erase(bay.order.id)
	road_customer = -1
	site.remove_car(bay)

func arrival_customer(person: Dictionary, arrival: Dictionary, target_point: Vector2, dt: float) -> void:
	if arrival.stage=="walk":
		visitor(person,target_point,false,dt)
		return
	var seat: Vector3 = arrival.car.to_global(Vector3(0.34,0.48,-0.27))
	var door := driver_door(arrival)
	if not visitors.has(person.id):
		visitors[person.id] = site.make_visitor(door,Color(Day.VEHICLES[person.vehicle][1]))
	var visual: Dictionary = visitors[person.id]
	var node: Node3D = visual.root
	var progress := move_toward(float(arrival.unboard_time),1.0,dt/0.42)
	arrival.unboard_time = progress
	var weight := smoothstep(0.0,1.0,progress)
	node.position = seat.lerp(Vector3(door.x,0.06,door.y),weight)
	node.rotation.y = -PI/2
	node.scale.y = lerpf(0.72,1.0,weight)
	visual.meter.hide()
	if progress>=1.0: arrival.stage = "walk"

func reception_queue_point(index: int, path: Array[Vector2]) -> Vector2:
	var head: Vector2 = site.queue_head
	if index==0: return head
	if site.stations.reception.turn==0:
		var point := head+Vector2(0,0.83*index)
		if point.y>=16.5: point.x = site.portal.x
		return point
	var remaining := 0.83*index
	for point in path:
		var distance := head.distance_to(point)
		if remaining<=distance: return head.move_toward(point,remaining)
		remaining -= distance
		head = point
	return head

func refresh_visitors(dt: float) -> void:
	var visible := {}
	var queue_index := 0
	var queue_path: Array[Vector2] = []
	for person in run.waiting:
		if not incoming.has(person.id) or incoming[person.id].stage=="drive": continue
		if queue_index==1 and site.stations.reception.turn!=0:
			queue_path = site.walk_path(site.queue_head,site.portal+Vector2.DOWN*1.5)
		arrival_customer(person,incoming[person.id],reception_queue_point(queue_index,queue_path),dt)
		visible[person.id] = true
		queue_index += 1
	if not waiting_for_bay.is_empty():
		var places: Array[Vector2] = site.bay_waiting_places()
		for i in range(waiting_for_bay.size()):
			var person := waiting_for_bay[i]
			if not waiting_room_visitor(person,places[i%places.size()],false,dt):
				var meter: Label3D = visitors[person.id].meter
				meter.text += "\nAttend une baie"
			visible[person.id] = true
	for i in range(site.bays.size()):
		var bay: Dictionary = site.bays[i]
		if bay.order.is_empty(): continue
		var order: Dictionary = bay.order
		var point: Vector2 = site.seats[i]
		if order.paid: point = waiting_by_parking(i)
		service_visitor(bay,point,not order.paid,dt,site.stations["seat_%d"%i].turn)
		visible[order.id] = true
	for parked in parked_cars.values():
		if parked.status!="outdoors": continue
		service_visitor(parked,site.parked_customer_point(parked.exit_slot),false,dt)
		visible[parked.order.id] = true
	for id in departures:
		passenger_departure(id,departures[id],dt)
		visible[id] = true
	for id in visitors.keys():
		var visual: Dictionary = visitors[id]
		if id in visible:
			var receipt_left := maxf(0.0,visual.get("receipt_left",0.0)-dt)
			visual.receipt_left = receipt_left
			visual.receipt.visible = receipt_left>0.0
			if receipt_left>0.0:
				visual.receipt.position.y = 2.06+(1.0-receipt_left/RECEIPT_SECONDS)*0.38
			continue
		visual.root.hide()
		visual.root.queue_free()
		visitors.erase(id)

func service_visitor(holder: Dictionary, point: Vector2, seated: bool, dt: float, seat_turn := 0) -> void:
	var order: Dictionary = holder.order
	var status := ""
	if order.paid:
		status = "Attend sa voiture"
	elif not checkout_queue.is_empty() and checkout_queue[0]==order.id:
		point = site.checkout_head
		seated = false
		status = "À la caisse"
	elif order.id in checkout_queue:
		status = "Attend la caisse"
	elif can_call_to_checkout(holder):
		status = "Prêt pour la caisse"
	if status=="" and order.decision!="pending" and not (Repairs.active(order,"window") and Repairs.stage(order,"window")==2):
		waiting_room_visitor(order,point,seated,dt,seat_turn)
	else:
		visitor(order,point,seated,dt,seat_turn)
		visitors[order.id].erase("amenity")
		visitors[order.id].erase("reading_time")
	if status!="":
		var meter: Label3D = visitors[order.id].meter
		meter.text += "\n"+status

func waiting_room_visitor(order: Dictionary, seat: Vector2, seated: bool, dt: float, seat_turn := 0) -> bool:
	if not visitors.has(order.id):
		visitor(order,seat,seated,dt,seat_turn)
		return false
	var visual: Dictionary = visitors[order.id]
	var amenity: Dictionary = visual.get("amenity",{})
	var reading_time := maxf(0.0,visual.get("reading_time",0.0)-dt)
	visual.reading_time = reading_time
	if amenity.is_empty() and order.in_waiting_room and not order.late:
		var desired := ""
		if site.amenity_active("vending") and order.patience>0.0 and order.patience<=order.max_patience/5.0 and (
			order.snacks_used<Day.MAX_SNACKS and order.snack_pause<=0.0):
			desired = "vending"
		elif site.amenity_active("magazines") and not visual.get("magazine_seen",false) and visitor_at(order.id,seat):
			visual.magazine_wait = visual.get("magazine_wait",0.0)+dt
			if visual.magazine_wait>=2.0: desired = "magazines"
		if desired!="" and visual.get("retry_amenity",0.0)<=0.0:
			var p: Vector3 = visual.root.position
			var access: Vector2 = site.amenity_access(desired,Vector2(p.x,p.z))
			if access!=Vector2.INF:
				amenity = {"id":desired,"at":access,"travel":0.0,"use":0.0,"started":false}
				visual.amenity = amenity
			else:
				visual.retry_amenity = 1.0
	visual.retry_amenity = maxf(0.0,visual.get("retry_amenity",0.0)-dt)
	if not amenity.is_empty():
		if use_waiting_amenity(order,visual,amenity,dt): return true
		visual.erase("amenity")
	visitor(order,seat,seated,dt,seat_turn)
	if reading_time>0.0 and visitor_at(order.id,seat):
		show_amenity_hands(visual,false,reading_time)
		visual.meter.text += "\nLit un magazine"
		return true
	return false

func use_waiting_amenity(order: Dictionary, visual: Dictionary, amenity: Dictionary, dt: float) -> bool:
	var snack: bool = amenity.id=="vending"
	if not amenity.started:
		amenity.travel += dt
		if amenity.travel>6.0 or order.late:
			visual.retry_amenity = 1.5
			return false
	visitor(order,amenity.at,false,dt)
	if not visitor_at(order.id,amenity.at): return true
	if not amenity.started:
		amenity.started = true
		if snack:
			order.snacks_used += 1
			order.snack_pause = Day.SNACK_BREAK
			visual.reading_time = 0.0
		else:
			visual.magazine_seen = true
	amenity.use += dt
	if amenity.use>=1.0:
		if not snack: visual.reading_time = 12.0
		return false
	var point: Vector2 = site.station_point(amenity.id)-amenity.at
	visual.root.rotation.y = atan2(point.x,point.y)
	show_amenity_hands(visual,snack,amenity.use)
	visual.meter.text += "\nSe sert" if snack else "\nPrend un magazine"
	return true

func show_amenity_hands(visual: Dictionary, snack: bool, phase: float) -> void:
	var hands: Node3D = visual.hands
	hands.position.y = 0.65+0.06*sin(phase*8.0)
	hands.rotation.x = -0.24+0.12*sin(phase*6.0)
	visual.snack.visible = snack
	visual.magazine.visible = not snack
	hands.show()

func visitor(person: Dictionary, p: Vector2, seated: bool, dt: float, seat_turn := 0) -> void:
	if not visitors.has(person.id):
		visitors[person.id] = site.make_visitor(site.portal,Color(Day.VEHICLES[person.vehicle][1]))
	var visual: Dictionary = visitors[person.id]
	var node: Node3D = visual.root
	var desired := Vector3(p.x,0.06,p.y)
	var goal: Vector2 = visual.get("goal",Vector2.INF)
	var path: Array = visual.get("path",[])
	visual.retry = maxf(0.0,float(visual.get("retry",0.0))-dt)
	if goal!=p or (path.is_empty() and visual.retry==0.0 and node.position.distance_to(desired)>0.15):
		visual.goal = p
		visual.retry = 0.35
		path = site.walk_path(Vector2(node.position.x,node.position.z),p)
		visual.path = path
	if not path.is_empty():
		var step: Vector2 = path[0]
		var destination := Vector3(step.x,0.06,step.y)
		var forward := destination-node.position
		if forward.length_squared()>0.0001:
			node.rotation.y = atan2(forward.x,forward.z)
		node.position = node.position.move_toward(destination,dt*4.9)
		if node.position.distance_to(destination)<0.06: path.pop_front()
	var sitting := seated and node.position.distance_to(desired)<0.38
	node.scale.y = 0.73 if sitting else 1.0
	if sitting: node.rotation.y = PI/2+Map.turn_yaw(seat_turn)
	visual.meter.position.y = 2.35 if sitting else 1.57
	person.in_waiting_room = site.waiting_area().has_point(Vector2(node.position.x,node.position.z))
	visual.hands.hide()
	visual.meter.visible = not departures.has(person.id) and visual.get("receipt_left",0.0)<=0.0
	if person.paid:
		visual.meter.text = person.name
		visual.meter.modulate = Color("#b5efca")
		return
	var count := ceili(5.0*person.patience/person.max_patience)
	visual.meter.text = person.name+"  "+"■".repeat(count)+"□".repeat(5-count)
	visual.meter.modulate = Color("#ffc192") if count<=2 else Color("#fff0c7")

func show_summary() -> void:
	var rows: Array[String] = []
	for id in run.completed_repairs:
		rows.append("%s × %d" % [JOBS[id][0],run.completed_repairs[id]])
	var line := " · ".join(rows) if not rows.is_empty() else "Aucune réparation facturée"
	var title := "Jour %d terminé"%run.day
	var cards: Array = [["Retour à l’atelier","Réaménage le garage ou visite la fourgonnette."]]
	if run.mode=="lost":
		title = "Garage fermé"
		cards = [["Nouvelle partie","Réputation épuisée au jour %d."%run.day]]
	elif run.mode=="won":
		title = "Dix jours réussis !"
		cards = [["Nouvelle partie","Essaie une autre disposition de garage."]]
	menu.open("summary",title,"%d clients servis   ·   +%d $ aujourd’hui   ·   %d $ en caisse"%[run.served,run.daily_cash,run.cash],
		cards,line+"     /     A / F continuer")

func tick(dt: float) -> void:
	if is_instance_valid(menu) and menu.visible:
		menu.tick()
		return
	if Input.is_action_just_pressed("reset"):
		request_restart()
		return
	notice_time = maxf(0,notice_time-dt)
	var was: String = run.mode
	if was not in ["lost","won"]:
		var guarantee_was_used: bool = run.guarantee_used
		var room_rate := 1.0
		for id in Map.WAITING_AMENITIES:
			if site.amenity_active(id): room_rate *= Day.AMENITY_PATIENCE_RATE
		run.tick(dt,active_orders(),not departures.is_empty() or site.bays.any(func(bay: Dictionary) -> bool:
			return not bay.order.is_empty() and bay.order.paid),room_rate)
		if was=="day" and run.mode=="closing":
			run.waiting = run.waiting.filter(func(order: Dictionary) -> bool: return incoming.has(order.id))
		if not guarantee_was_used and run.guarantee_used:
			inform("Garantie d’accueil · une demi-étoile préservée.")
		if run.mode in ["open","lost","won"] and run.mode!=was:
			if coop!=null: coop.reset()
			cancel_action()
			engine.stop()
			if run.mode in ["open","won"]:
				update_lift_speed()
				restore_day_setup()
				if run.mode=="open": site.van.show()
				keep_player_clear()
				sync_player(0,0)
				update_camera(1)
				update_hud()
			show_summary()
			game.store_checkpoint()
			return
		advance_cars(dt)
		refresh_visitors(dt)
	if coop!=null: coop.tick(self,dt,guest_input)
	if driven_bay>=0:
		if run.mode not in ["lost","won"]:
			drive_vehicle(driving_input(),dt,Input.is_action_pressed("rotate_item"))
			if Input.is_action_just_pressed("take"): exit_driver_seat(true)
			elif Input.is_action_just_pressed("cancel_item"): exit_driver_seat(false)
		update_view(dt,0.0)
		return
	var before := player
	if run.mode not in ["lost","won"]: move_player(dt)
	var refuse: bool = Input.is_action_pressed("cancel_item") and context(true).get("id") in ["decline","refuse","window_decline"]
	if office_seated and Input.is_action_just_pressed("cancel_item"):
		office_seated = false
		cancel_action()
	elif refuse:
		advance_action(dt,Input.is_action_just_pressed("cancel_item"),true,true)
	elif Input.is_action_pressed("cancel_item"):
		cancel_action()
		if Input.is_action_just_pressed("cancel_item") and relocating!="":
			site.move_station(relocating,site.stations[relocating].tile)
			relocating = ""
			keep_player_clear()
	else:
		advance_action(dt,Input.is_action_just_pressed("use_item"),Input.is_action_pressed("use_item"))
	if menu.visible: return
	if run.mode not in ["lost","won"]:
		if Input.is_action_just_pressed("take"): place_or_move()
		if Input.is_action_just_pressed("rotate_item"): rotate_or_unload()
	update_view(dt,player.distance_to(before)/maxf(dt,0.001))

func update_view(dt: float, speed: float) -> void:
	if Input.is_action_just_pressed("zoom_in"): change_zoom(1)
	if Input.is_action_just_pressed("zoom_out"): change_zoom(-1)
	site.animate_bays(dt,action,coop.guest.get("action",{}) if coop!=null else {})
	site.animate_personnel_door(player,dt,coop.guest.player if coop!=null and coop.online and not coop.guest.is_empty() else Vector2.INF)
	sync_player(dt,speed)
	update_camera(minf(dt*7,1))
	update_hud()

func movement_input() -> Vector2:
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var stick := Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_X),Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_Y))
		if stick.length()>0.2: return stick.limit_length()
	return keyboard_movement().limit_length()

func keyboard_movement() -> Vector2:
	return Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func driving_input() -> Vector2:
	var pads := Input.get_connected_joypads()
	if pads.is_empty(): return keyboard_movement()
	var pad := pads[0]
	var sticks := Vector2(Input.get_joy_axis(pad,JOY_AXIS_RIGHT_X),Input.get_joy_axis(pad,JOY_AXIS_LEFT_Y))
	if maxf(absf(sticks.x),absf(sticks.y))>0.16: return sticks
	return keyboard_movement()

func walking_speed() -> float:
	if held!="" or (pulling_cart and not run.purchases.has("light_cart")): return 4.0
	return 4.9

func move_player(dt: float) -> void:
	var move := movement_input()
	var aim := Vector2(float(Input.is_physical_key_pressed(KEY_L))-float(Input.is_physical_key_pressed(KEY_J)),
		float(Input.is_physical_key_pressed(KEY_K))-float(Input.is_physical_key_pressed(KEY_I)))
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var right := Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_RIGHT_X),Input.get_joy_axis(pads[0],JOY_AXIS_RIGHT_Y))
		if right.length()>0.26: aim = right
	walk_with_input(dt,move,aim)

func walk_with_input(dt: float, move: Vector2, aim: Vector2) -> void:
	if move.length()>0.2: office_seated = false
	move = move.rotated(-game.camera.rotation.y)
	aim = aim.rotated(-game.camera.rotation.y)
	velocity = velocity.move_toward(move.limit_length()*walking_speed(),dt*30.0)
	for i in range(4):
		var delta := velocity*dt/4
		var attempt := player+Vector2(delta.x,0)
		if site.clear_at(attempt): player = attempt
		attempt = player+Vector2(0,delta.y)
		if site.clear_at(attempt): player = attempt
	if aim.length()>0.1: facing = aim.normalized()
	elif move.length()>0.07: facing = move.normalized()

func sync_player(dt: float,speed: float) -> void:
	game.avatar.position = Vector3(player.x,0.08,player.y)
	if driven_bay>=0: return
	game.avatar.rotation = Vector3(0,atan2(facing.x,facing.y),0)
	var work_height := 0.0
	if action.has("bay") and (action.id in ["wheel","drain"] or action.get("raised",false)):
		work_height = site.bays[action.bay].lift_height*0.45
	tool_holder.position = Vector3(0,0.93+work_height,0.38)
	if is_instance_valid(item_prop):
		var yaw: float = Map.turn_yaw(held_turn)-game.avatar.rotation.y if held_turn>=0 and action.is_empty() else 0.0
		item_prop.transform = Transform3D(Basis(Vector3.UP,yaw),Vector3(0,0.04,0))
	game.player_visual.animate(dt,speed,held!="" or relocating!="")
	seat_blend = move_toward(seat_blend,1.0 if office_seated else 0.0,dt*3.6)
	if seat_blend>0.0:
		var chair_turn: int = site.stations.office_chair.turn
		var chair_point: Vector2 = site.station_point("office_chair")
		game.player_visual.sit_at(chair_point,Map.turn_yaw(chair_turn),seat_blend)
	if pulling_cart:
		game.player_visual.reach(1,Vector3(-0.17,0.96,-0.48),1.0)
	if not repair_pose.apply(self,dt) and action.has("bay") and action.id not in ["payment","approve","decline","refuse"]:
		for side in range(2):
			game.player_visual.reach(side,Vector3(0.16 if side==0 else -0.16,
				0.79+work_height+sin(progress*16)*0.04,0.43),1.0)

func change_zoom(step: int) -> void:
	zoom = clampi(zoom+step,0,2)

func update_camera(blend: float) -> void:
	var rotation := GARAGE_CAMERA_ROTATION
	var angles := rotation * (PI/180.0)
	var offset := Basis.from_euler(angles)*Vector3(0,0,35)
	var center := player
	var view_size := 13.8 if zoom<2 else 9.2
	if zoom==0 and driven_bay<0:
		var viewport: Vector2 = game.get_viewport().get_visible_rect().size
		var aspect := viewport.x/maxf(1.0,viewport.y)
		var footprint := Vector2(site.size.x+2.0,site.size.y+Map.NORTH_APRON+2.1)
		var c := cos(angles.y)
		var s := absf(sin(angles.y))
		var width := footprint.x*c+footprint.y*s
		var depth := footprint.y*c+footprint.x*s
		view_size = maxf(width/maxf(0.1,aspect)+2.0,depth*absf(sin(angles.x))+2.2)
		center = site.playable_area().get_center()
	elif driven_bay>=0:
		var yaw: float = site.bays[driven_bay].car.rotation.y
		center += Vector2(sin(yaw),cos(yaw))*clampf(drive_speed/3.2,-1.1,1.35)
	elif action.has("bay"):
		var bay_center: Vector2 = site.bays[action.bay].at
		if bay_center.distance_squared_to(action.at)<9.0:
			center = center.lerp(bay_center,0.33)
	if coop!=null and coop.online and not coop.guest.is_empty() and (zoom!=0 or driven_bay>=0):
		var partner: Vector2 = coop.guest.player
		var separation := (center-partner).abs()
		var viewport: Vector2 = game.get_viewport().get_visible_rect().size
		var aspect := viewport.x/maxf(1.0,viewport.y)
		view_size = maxf(view_size,maxf(separation.x/maxf(0.1,aspect),separation.y*absf(sin(angles.x)))+4.0)
		center = center.lerp(partner,0.5)
	game.camera.rotation_degrees = game.camera.rotation_degrees.lerp(rotation,blend)
	game.camera.position = game.camera.position.lerp(Vector3(center.x,0,center.y)+offset,blend)
	game.camera.size = lerpf(game.camera.size,view_size,blend)


func next_vehicle_work(index: int, options: Array[Dictionary] = []) -> Dictionary:
	var bay: Dictionary = site.bays[index]
	var order: Dictionary = bay.order
	if order.decision=="pending":
		return client_work("Parler au client pour la batterie",index)
	if Repairs.active(order,"window") and Repairs.stage(order,"window")==2:
		return client_work("Demander l’accord pour la vitre",index)
	if Repairs.active(order,"tires") and order.wheels.has(2) and held=="used_tire":
		return Repairs.hint("Poser le pneu usagé au sol","used_tire")
	var best := {}
	var best_score := -1
	if options.is_empty(): options = repair_targets(index)
	for option in options:
		if not option.has("work"): continue
		var work: Dictionary = option.work
		var score: int = option.work_priority
		if work.lift==-1 or work.lift==int(bay.lift_raised): score += 1
		if score>best_score:
			best = work
			best_score = score
	return best

func client_work(label: String, index: int) -> Dictionary:
	var work := Repairs.hint(label)
	work.merge({"at":site.seats[index],"zone":"Client","on_car":false})
	return work

func station_marker(id: String, caption: String) -> Dictionary:
	var point: Vector2 = site.station_point(id)
	return {"label":caption,"at":Vector3(point.x,site.stations[id].height+0.15,point.y)}

func material_marker(item: String, order_id: int) -> Dictionary:
	var needs_origin := item in ["repair_wheel","old_battery","old_muffler","empty_bottle","coolant_empty"]
	if item=="" or (held==item and (not needs_origin or held_origin==order_id)): return {}
	if pulling_cart and cart_kind==item and cart_count>0: return {}
	var caption := "Prendre · "+item_name(item)
	for id in site.stations:
		var top: Dictionary = site.stations[id].get("top",{})
		if top.get("item")==item and (not needs_origin or top.get("origin")==order_id):
			return station_marker(id,caption)
	for tile in site.cells:
		var entry: Dictionary = site.cells[tile]
		if entry.get("item")==item and (not needs_origin or entry.get("origin")==order_id):
			var point: Vector2 = site.center(tile)
			return {"label":caption,"at":Vector3(point.x,0.5,point.y)}
	if item=="new_tire": return station_marker("rack",caption)
	if item in ["fresh_oil","new_battery","coolant"]: return station_marker(item,caption)
	for id in Catalog.SHELVES:
		if item in Catalog.SHELVES[id]: return station_marker(id,caption)
	return {}

func work_marker(index: int, work: Dictionary) -> Dictionary:
	if work.is_empty(): return {}
	var bay: Dictionary = site.bays[index]
	if work.lift>=0 and (work.lift!=int(bay.lift_raised) or site.lift_moving(bay)):
		var point: Vector2 = bay.lever_at
		var caption := "Lever le pont" if work.lift==1 else "Baisser le pont"
		if site.lift_moving(bay): caption = "Pont en mouvement"
		return {"label":caption,"at":Vector3(point.x,1.20,point.y)}
	var material := material_marker(work.item,bay.order.id)
	if not material.is_empty(): return material
	if work.has("station"):
		var station: String = work.station
		return station_marker(station,site.stations[station].title)
	return work_location(index,work)

func work_location(index: int, work: Dictionary) -> Dictionary:
	if not work.has("at"): return {}
	var bay: Dictionary = site.bays[index]
	var point: Vector2 = work.at
	var label: String = work.get("zone","")
	if label=="":
		var offset: Vector2 = point-bay.at
		if offset.y<-1.6: label = "Avant du véhicule"
		elif offset.y>1.6: label = "Arrière du véhicule"
		else: label = "Côté gauche" if offset.x<0.0 else "Côté droit"
	var height: float = bay.car.position.y+1.15 if work.get("on_car",true) else 1.25
	return {"label":label,"at":Vector3(point.x,height,point.y)}

func ready_repair_actions(index: int, options: Array[Dictionary], plan: Dictionary) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var order_id: int = site.bays[index].order.id
	for option in options:
		if not option.has("work"): continue
		if option.id!="none":
			choices.append(option)
			continue
		var work: Dictionary = option.work
		var station: String = work.get("station","")
		match station:
			"trash","scrap":
				if held!=work.item or held_origin!=order_id: continue
			"waste_oil":
				if oil_pan_for!=order_id: continue
			"bench":
				var top: Dictionary = site.stations.bench.get("top",{})
				var has_wheel := held=="repair_wheel" and held_origin==order_id
				if not has_wheel and (top.get("item")!="repair_wheel" or top.get("origin")!=order_id): continue
			_: continue
		var ready := station_action(station,site.station_point(station))
		if ready.is_empty() or ready.id=="none": continue
		ready.work = work
		choices.append(ready)
	if plan.get("zone")=="Client":
		var approval := approval_action(index)
		if not approval.is_empty():
			approval.work = plan
			choices.append(approval)
	return choices

func vehicle_work_cues(index: int, choices: Array, plan: Dictionary) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	if choices.is_empty():
		var cue := work_marker(index,plan)
		if not cue.is_empty(): cues.append(cue)
		return cues
	var multiple := choices.size()>1
	for choice in choices:
		var station: String = choice.work.get("station","")
		var cue := station_marker(station,site.stations[station].title) if station!="" else work_location(index,choice.work)
		if multiple and station=="":
			match choice.id:
				"wheel":
					var state: int = site.bays[index].order.wheels[choice.wheel]
					cue.label = ["Desserrer","Déposer","Monter","Serrer"][state]
				"brake_fit": cue.label = "Plaquettes"
				"bearing_test","bearing_extract","bearing_fit": cue.label = "Roulement"
				"approve","window_approve": cue.label = "Client"
				_: cue.label = JOBS[choice.job][0]
		cue.compact = multiple
		cue.action_id = choice.id
		cues.append(cue)
	return cues

func append_work_hint(lines: Array[String], work: Dictionary, bay: Dictionary, action_count := 0) -> void:
	if work.is_empty(): return
	var item := "Mains libres" if work.item=="" else item_name(work.item)
	if work.item=="repair_wheel": item = "Roue du véhicule"
	var lift := "Pont indifférent"
	if work.lift==1:
		if not bay.lift_raised: lift = "Pont à lever"
		else: lift = "Pont en montée" if site.lift_moving(bay) else "Pont levé"
	elif work.lift==0:
		if bay.lift_raised: lift = "Pont à baisser"
		else: lift = "Pont en descente" if site.lift_moving(bay) else "Pont baissé"
	var heading := "Suggestion" if action_count>1 else "Suivant"
	lines.append("[color=#ffd99a][b]%s[/b] · %s[/color]"%[heading,work.label])
	lines.append("[color=#d4e4df]%s  ·  %s[/color]"%[item,lift])

func update_hud() -> void:
	var driving: bool = driven_bay>=0 and run.mode not in ["lost","won"]
	var placing: bool = driving and site.bays[driven_bay].status=="intake"
	var placement := intake_status(site.bays[driven_bay]) if placing else IntakeStatus.APPROACH
	var parking := ParkingStatus.ALIGN
	var parking_slot := -1
	if driving and not placing:
		var result := parking_placement(site.bays[driven_bay])
		parking = result.status
		parking_slot = result.slot
	var guide_ready := placement==IntakeStatus.READY or parking==ParkingStatus.READY
	var view: Vector2 = game.get_viewport().get_visible_rect().size
	var stars := ""
	for i in range(5):
		if run.rating>=2*i+2: stars += "★ "
		elif run.rating==2*i+1: stars += "◐ "
		else: stars += "☆ "
	var rating := "[color=#ffd38b]%s[/color]   %s / 5"%[stars,("%.1f"%(run.rating/2.0)).replace(".",",")]
	var state: String = {"day":run.clock_label(),"closing":"[color=#ffd38b]17 h 00[/color]",
		"open":"Atelier libre","lost":"Garage fermé","won":"Partie gagnée"}[run.mode]
	header.text = "[color=#93c4bd]GARAGE DAY  /  %s[/color]\n[b][font_size=21]Jour %d / 10  ·  %s[/font_size][/b]\n%s\n[color=#b6cbca]%d $  ·  %d clients en file[/color]" % [Map.LAYOUTS[layout][0],maxi(1,run.day),state,rating,run.cash,run.waiting.size()]
	header.get_parent().position = Vector2(14,14)
	var lines: Array[String] = ["[color=#9bd1c6]TABLEAU DE SERVICE[/color]"]
	var planned_work := {}
	var available_work := {}
	for i in range(site.bays.size()):
		if i>0: lines.append("[font_size=6] [/font_size]")
		var bay: Dictionary = site.bays[i]
		var order: Dictionary = bay.order
		if order.is_empty():
			lines.append("[color=#b7c8c5]Baie %02d   ·   Libre[/color]"%(i+1))
		else:
			var lift_status := "[color=#a9dbb5]↓ Bas[/color]"
			if site.lift_moving(bay):
				lift_status = "[color=#ffd18c]%s[/color]"%("↑ Monte" if bay.lift_raised else "↓ Descend")
			elif bay.lift_raised: lift_status = "[color=#ffd18c]↑ Levé[/color]"
			lines.append("[b]Baie %02d · %s[/b]  [color=#c3d0c8]%s[/color]  %s"%
				[i+1,order.name,Day.VEHICLES[order.vehicle][0],lift_status])
			var jobs: Array[String] = []
			for id in order.required:
				var label: String = JOBS[id][0]
				if id=="tires": label += " %d/4"%order.wheels.count(4)
				if id=="brakes": label += " %d/2"%order.service.get("pads",[]).size()
				if id=="puncture" and id not in order.done: label += " · "+Catalog.WHEEL_SIDES[order.faults.puncture]
				jobs.append(("✓ " if id in order.done else "○ ")+label)
			lines.append("  ·  ".join(jobs))
			if bay.status=="intake":
				if placing and i==driven_bay:
					if guide_ready: lines.append("[color=#a5efb9]✓ Bien placé · à valider[/color]")
					else: lines.append("[color=#ffd18c]Positionnement en cours[/color]")
				elif not driving and intake_status(bay)==IntakeStatus.READY:
					lines.append("[color=#a5efb9]✓ Bien placé · A / F au levier[/color]")
				else: lines.append("[color=#ffd18c]À rentrer · A %02d → baie %02d[/color]"%[bay.arrival_slot+1,i+1])
			elif bay.status=="driving":
				if i==driven_bay and guide_ready:
					lines.append("[color=#a5efb9]✓ Bien placé · à valider[/color]")
				else: lines.append("[color=#a9dbb5]À stationner dehors[/color]")
			elif bay.status=="parked" and not order_ready(order):
				lines.append("[color=#a5dfaf]✓ En place[/color]")
				var options := repair_targets(i)
				var work := next_vehicle_work(i,options)
				var choices := ready_repair_actions(i,options,work)
				append_work_hint(lines,work,bay,choices.size())
				planned_work[i] = work
				available_work[i] = choices
			elif order_ready(order):
				if "tires" in order.done and holds_used_tires():
					var work := Repairs.hint("Poser les pneus usagés au sol","used_tire")
					append_work_hint(lines,work,bay)
					planned_work[i] = work
				elif bay.lift_raised or site.lift_moving(bay):
					lines.append("[color=#ffd18c]Abaisser le pont avant la sortie[/color]")
				elif nearest_exit_slot(bay)<0:
					lines.append("[color=#ffd18c]Sortie · stationnement plein[/color]")
				else: lines.append("[color=#a9dbb5]Prêt à sortir[/color]")
			if order_ready(order):
				if order.paid:
					var slot: int = bay.get("wait_slot",-1)
					if slot>=0:
						lines.append("[color=#9be3ff]Payé · attend en [b]P %02d[/b][/color]"%(slot+1))
					else: lines.append("[color=#a9dbb5]Payé · le client attend dehors[/color]")
				elif not checkout_queue.is_empty() and checkout_queue[0]==order.id:
					lines.append("[color=#ffd18c]À encaisser · caisse à gauche[/color]")
				elif order.id in checkout_queue:
					lines.append("[color=#ffd18c]Attend son tour à la caisse[/color]")
				else:
					lines.append("[color=#ffd18c]À encaisser · inviter le client[/color]")
	if not parked_cars.is_empty():
		lines.append("[color=#9be3ff]STATIONNEMENT DE SORTIE[/color]")
		for parked in parked_cars.values():
			var order: Dictionary = parked.order
			var status := "À encaisser"
			if order.paid: status = "Payé · départ"
			elif not checkout_queue.is_empty() and checkout_queue[0]==order.id: status = "À la caisse"
			elif order.id in checkout_queue: status = "Attend la caisse"
			lines.append("[b]P %02d · %s[/b] · %s"%[parked.exit_slot+1,order.name,status])
	if not waiting_for_bay.is_empty():
		lines.append("[color=#ffd99a]ATTENTE D’UNE BAIE[/color]")
		for order in waiting_for_bay:
			lines.append("%s · voiture en A %02d"%[order.name,incoming[order.id].slot+1])
	if not run.appointments.is_empty(): lines.append("%d rendez-vous en route"%run.appointments.size())
	var equipment := item_name(held) if held!="" else "Mains libres"
	if relocating!="": equipment = site.stations[relocating].title
	if pulling_cart: equipment = "Chariot · %d / 4"%cart_count
	lines.append("[color=#9bd1c6]EN MAIN[/color]   "+equipment)
	ticket.text = "\n".join(lines)
	ticket.custom_minimum_size.x = minf(335,view.x*0.41-24)
	var ticket_panel: Control = ticket.get_parent()
	ticket_panel.size = Vector2(ticket.custom_minimum_size.x+24,0)
	ticket_panel.position = Vector2(view.x-ticket_panel.size.x-14,14)
	var selected := context()
	var marked_points: Array[Vector3] = []
	for i in range(site.bays.size()):
		var visible_cues: Array[Dictionary] = []
		if not driving and run.mode in ["day","closing"]:
			for cue in vehicle_work_cues(i,available_work.get(i,[]),planned_work.get(i,{})):
				var point: Vector3 = cue.at
				var target_point := Vector2(point.x,point.z)
				var action_id: String = cue.get("action_id","")
				if point in marked_points: continue
				if action.get("at")==target_point and (action_id=="" or action.id==action_id): continue
				marked_points.append(point)
				cue.ready = selected.get("at")==target_point and selected.id!="none" and (action_id=="" or selected.id==action_id)
				visible_cues.append(cue)
		site.show_work_markers(i,visible_cues,game.camera.size)
	var instruction := ""
	if not selected.is_empty():
		instruction = selected.label if selected.id=="none" else (("A / F" if selected.seconds==0 else "Maintenir A / F")+"  ·  "+selected.label)
		if selected.id in ["approve","window_approve"]: instruction += "   ·   Maintenir B / Q pour reporter"
		elif context(true).get("id")=="refuse": instruction += "   ·   Maintenir B / Q pour refuser"
		elif selected.id=="cart": instruction += "   ·   X / R tourner"
	if office_seated: instruction += "   ·   B / Q se lever"
	elif run.mode=="open" and selected.has("station") and held=="" and not pulling_cart:
		instruction += "   ·   Y / E déplacer"
	if held!="" or pulling_cart or relocating!="":
		var command := "Y / E poser" if held in ["","new_tire","used_tire","repair_wheel"] else "Y / E poser sur un comptoir"
		if pulling_cart:
			var empty_label := "remettre les pneus" if cart_kind=="new_tire" and selected.get("id") in ["rack_cart","return_cart_stock"] else "vider le chariot"
			command = "Y / E garer · X / R "+empty_label
		elif selected.get("id")=="return_supply":
			command = "Y / E remettre en réserve"
		if relocating!="": command = "X / R tourner   ·   Y / E poser   ·   B / Q annuler"
		elif held!="" and not pulling_cart: command += "   ·   X / R tourner"
		instruction += ("   ·   " if instruction!="" else "")+command
	if instruction=="":
		if run.mode=="lost": instruction = "Garage fermé · View / F9 nouvelle partie"
		elif run.mode=="won": instruction = "Partie gagnée · View / F9 nouvelle partie"
		else: instruction = "Vise un poste avec le stick droit ou I / J / K / L."
	var hint: String = {"day":"Accueille les clients, rentre leurs voitures et encaisse après les réparations.",
		"closing":"Termine les clients présents. Le téléphone est fermé.",
		"open":"Téléphone pour ouvrir · Y / E déplacer · Fourgonnette à la fin de la journée.",
		"lost":"View / F9 pour commencer une nouvelle partie.",
		"won":"View / F9 pour choisir un nouveau garage."}[run.mode]
	var instruction_color := "#ffd99a"
	if driving:
		if placing:
			instruction = "Baie %02d · %s"%[driven_bay+1,intake_prompt(placement)]
			if guide_ready:
				var buttons := "Y / E ou B / Q" if absf(drive_speed)<=0.22 else "Y / E"
				instruction = "✓ Bien placé · %s pour valider et descendre"%buttons
		else: instruction = parking_prompt(parking,parking_slot)
		if guide_ready: instruction_color = "#a5efb9"
		hint = "Stick gauche ↑ avancer · ↓ freiner / reculer  |  Stick droit ← → braquer"
	site.show_placement_guide(driven_bay if placing else parking_slot,placing,guide_ready)
	site.show_waiting_parking(game.camera.size,run.mode in ["day","closing"])
	var marked_bay := -1
	if driven_bay<0 and run.mode not in ["lost","won"] and not accepted_intakes.is_empty():
		marked_bay = accepted_intakes.back()
	site.show_intake_car(marked_bay,game.camera.size)
	if notice_time>0 and not driving: hint = notice
	var shortcuts := "View / F9 nouvelle partie   ·   LB / RB zoom"
	if driven_bay>=0: shortcuts = "B / Q descendre à l’arrêt   ·   LB / RB zoom"
	footer.text = "[center][color=%s][b]%s[/b][/color]\n%s\n[color=#a6bfbd][font_size=12]%s[/font_size][/color][/center]"%[
		instruction_color,instruction,hint,shortcuts]
	footer.custom_minimum_size.x = minf(690,view.x-44)
	var footer_panel: Control = footer.get_parent()
	footer_panel.size = Vector2(footer.custom_minimum_size.x+24,0)
	footer_panel.position = Vector2((view.x-footer_panel.size.x)/2,view.y-footer_panel.size.y-12)
	site.select_corners.visible = not selected.is_empty()
	if site.select_corners.visible:
		var point: Vector2 = selected.at
		var high: bool = selected.has("station") or (selected.has("bay") and point==site.bays[selected.bay].lever_at)
		var height := 0.96 if high else 0.12
		if selected.has("work") and selected.get("bay",-1)>=0 and not selected.work.has("station"):
			height = site.bays[selected.bay].car.position.y+1.02
		site.select_corners.position = Vector3(point.x,height,point.y)
	site.preview.visible = (held in ["new_tire","used_tire","repair_wheel"] or pulling_cart or relocating!="") and run.mode not in ["lost","won"]
	if site.preview.visible:
		var tile := drop_cell()
		var area := Rect2(Vector2(tile),Vector2.ONE)
		if relocating!="":
			area = Rect2(site.station_footprint(relocating,tile,relocating_turn))
			site.pose_station(relocating,tile,relocating_turn)
		var p := area.get_center()
		site.preview.position = Vector3(p.x,0.097,p.y)
		site.preview.scale = Vector3(area.size.x,1,area.size.y)
		var id := "cart" if pulling_cart else (held if held!="" else relocating)
		var valid := can_drop(tile,id) or (pulling_cart and cart_kind=="used_tire" and can_drop(tile,"used_tire"))
		site.preview.material_override.albedo_color = Color("#90c4a9") if valid else Color("#c0786b")
	if action.is_empty(): ring.hide()
	else:
		var at: Vector2 = game.camera.unproject_position(Vector3(player.x,2.3,player.y))
		at = at.clamp(Vector2(135,115),Vector2(maxf(135,view.x-135),maxf(115,view.y-125)))
		ring.update_progress(progress/maxf(0.001,action.seconds),action.label,Color("#f1cf91"))
		var ring_bounds: Rect2 = ring.content_rect()
		if Rect2(at+ring_bounds.position,ring_bounds.size).intersects(ticket_panel.get_rect()):
			at.x = maxf(-ring_bounds.position.x,ticket_panel.position.x-ring_bounds.end.x-8)
		ring.position = at
		ring.show()


extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func run_test() -> void:
	check_clock()
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	game.local_storage_enabled = false
	root.add_child(game)
	check(game.game_menu.screen=="home" and paused,"L’accueil local doit ouvrir avec le garage en pause")
	game.start_local_game(game.workshop.Map.COMPACT_LAYOUT)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	var w = game.workshop
	check(w.layout==w.Map.COMPACT_LAYOUT and w.site.visible and w.run.mode=="open" and not w.menu.visible
		and w.header.text.contains("Le Petit Atelier"),"La nouvelle partie doit démarrer dans Le Petit Atelier")
	w.request_restart()
	w.menu_chosen(1)
	check(w.menu.visible and w.menu.kind=="layout","Choix du garage absent lors d’une nouvelle partie")
	check(w.menu.options.size()==4 and w.menu.options[0][0]=="Le Petit Atelier"
		and w.menu.options[1][0]=="La Traversée" and w.menu.options[2][0]=="Le Tandem"
		and w.menu.options[3][0]=="Les Trois Ponts","Le petit garage doit précéder les trois garages existants")
	w.menu_chosen(0)
	check(w.layout==w.Map.COMPACT_LAYOUT,"Le premier choix du menu doit ouvrir la carte compacte")
	w.menu_dismissed()
	for i in range(w.Map.LAYOUTS.size()):
		w.build(i)
		check(w.site.bays.size()==w.Map.LAYOUTS[i][2],"Nombre de baies incorrect")
		var unique := {}
		for id in w.site.stations:
			var tiles: Array[Vector2i] = w.site.station_tiles(id,w.site.stations[id].tile)
			for tile in tiles:
				check(not unique.has(tile),"Deux meubles sur la même case")
				check(w.site.cells[tile].id==id,"Emprise du meuble incomplète")
				unique[tile] = true
		for id in ["rack","phone","reception"]:
			check(w.site.stations[id].span==2,"Ce meuble doit prendre deux cases · "+id)
		check(w.site.seats[0].x<2,"La banquette doit être à gauche")
		check(not w.site.walk_path(w.player,w.site.station_point("phone")-Vector2(-1,0)).is_empty(),"Téléphone inaccessible")
		check(not w.site.walk_path(w.player,Vector2(3.5,18.5)).is_empty(),"Accès à la cour inaccessible")
		var door: Vector2 = w.site.personnel_door_area.get_center()
		var shutter: Vector2 = Vector2(w.site.bays[0].at.x,door.y)
		check(not w.site.clear_at(shutter) and not w.site.can_see(shutter-Vector2.DOWN,shutter+Vector2.DOWN),
			"Le rideau d’entrée baissé doit barrer le passage")
		check(w.walk_segment_clear(door-Vector2.DOWN,door+Vector2.DOWN),"La porte piétonne doit permettre de sortir")
		w.site.animate_personnel_door(door,0.25)
		check(absf(w.site.personnel_door.rotation.y)>1.4,"La porte piétonne doit s’ouvrir à l’approche")
		for seat in w.site.seats:
			check(not w.site.walk_path(w.site.queue_head,seat).is_empty(),"Siège inaccessible")
		var zone: Rect2i = w.site.used_tire_zone
		check(zone.position.x>w.site.bays.back().at.x+1.65 and zone.position.y==17,"Zone des pneus mal placée")
		check(w.site.placement_ok(zone.position,"used_tire"),"La zone extérieure doit accepter les pneus usagés")
		for bay in w.site.bays:
			check(bay.lift.has("carriage"),"Le pont Grab3D doit être présent dans chaque baie")
			var tile: Vector2i = w.site.cell(bay.lever_at)
			check(not unique.has(tile) and w.site.cells[tile].kind=="lift","Emprise du levier invalide")
			check(not w.site.walk_path(w.player,bay.lever_at+Vector2.UP).is_empty(),"Levier inaccessible")
			check(not w.site.clear_at(bay.lever_at),"Collision du levier absente")
		if i==0:
			check(w.site.stations.rack.tile==Vector2i(7,12) and w.site.cart_cell==Vector2i(12,9)
				and w.site.stations.tool_tires.tile==Vector2i(20,3) and w.site.stations.bench.tile==Vector2i(12,7),
				"La Traversée doit ouvrir sur la disposition de départ")
			check(w.run.purchases.is_empty() and not w.site.stations.has("counter_vendor_0"),
				"La disposition de départ doit se limiter au matériel de base")
			check(w.furniture_routes_ok(w.reachable_tiles(w.player,false)),
				"Tous les postes de la nouvelle disposition doivent rester accessibles")
		if i==w.Map.COMPACT_LAYOUT:
			check(w.site.floor_inside.get_area()==234.0 and w.site.office_tiles().size.x==5
				and w.site.waiting_area().size.y<4.0,"L’atelier et les salles du Petit Atelier doivent être plus compacts")
			check(w.furniture_routes_ok(w.reachable_tiles(w.player,false)),
				"Les postes, les portes et le comptoir du Petit Atelier doivent rester accessibles")
			for id in w.site.stations:
				check(w.site.floor_inside.has_point(w.site.station_point(id)),
					"Le poste doit être dans le Petit Atelier : "+id)
	check_two_bays(w)
	check_intro_brakes(w)
	check_intro_brakes(w,w.Map.COMPACT_LAYOUT)
	check_fleet_animations(w)
	check_repair_contacts(w)
	check_arrival_queue(w)
	check_arrival_queue(w,w.Map.COMPACT_LAYOUT)
	check_reception_while_busy(w)
	check_first_payment(w)
	check_first_payment(w,w.Map.COMPACT_LAYOUT)
	check_checkout_queue(w)
	check_waiting_room_purchases(w)
	check_arrival_cutoff(w)
	check_host_checkpoint(w)
	check_guest_worker(w)
	check_guest_driving(w)
	w.build(2)
	var s = w.site
	var phone: Vector2 = s.station_point("phone")
	use(w,phone,"start")
	check(w.run.day==1 and w.run.mode=="day","Le téléphone ne lance pas la journée")
	use(w,phone,"call")
	use(w,phone,"call")
	var empty: Array[Dictionary] = []
	w.run.tick(4,empty)
	check(w.run.waiting.size()==3,"File de trois clients absente")
	for i in range(3):
		var expected: Dictionary = w.run.waiting[0]
		check(receive_customer(w,expected),"Impossible d’accueillir le client")
		var bay: Dictionary = s.bays[i]
		check(bay.order.get("id")==expected.id and bay.status=="intake" and bay.car.position.z>24.0,
			"L’accueil ne laisse pas le bon véhicule dehors")
		if bay.status=="intake": dock_incoming(w,bay)
	check(w.free_bay()==-1 and w.active_orders().size()==3,"Plusieurs baies ne travaillent pas en parallèle")
	for i in range(3):
		check(s.bays[i].status=="parked","Une baie est bloquée à l’entrée")
		for job in w.Map.SERVICE_OFFSETS:
			check(can_aim(w,s.bays[i].at+w.Map.SERVICE_OFFSETS[job]),"Poste inaccessible en baie "+str(i+1)+" "+job)
		var corners := [Vector2(-2.23,-2.75),Vector2(2.23,-2.75),Vector2(2.23,2.75),Vector2(-2.23,2.75)]
		for corner in range(corners.size()):
			var from: Vector2 = s.bays[i].at+corners[corner]
			var to: Vector2 = s.bays[i].at+corners[(corner+1)%corners.size()]
			for step in range(13):
				check(s.clear_at(from.lerp(to,step/12.0)),"Le tour du véhicule est obstrué en baie %d"%(i+1))
	for frame in range(50): w.refresh_visitors(0.1)
	var bay: Dictionary = s.bays[0]
	var order: Dictionary = bay.order
	check(w.visitor_at(order.id,s.seats[0]),"Le client ne s’assoit pas")
	order.required.assign(["oil","pressure","battery","coolant"])
	order.done.clear()
	s.bays[1].order.required.assign(["tires"])
	s.bays[2].order.required.assign(["lights"])
	w.update_hud()
	check(w.next_vehicle_work(0).item=="pressure" and w.next_vehicle_work(1).item=="tires"
		and w.next_vehicle_work(2).label=="Allumer et tester les feux"
		and w.ticket.text.contains("Clé à choc  ·  Pont à lever")
		and w.ticket.text.contains("Manomètre  ·  Pont baissé"),
		"Le tableau ne distingue pas les outils et ponts des trois voitures")
	use(w,s.station_point("tool_oil"),"surface")
	var drain_point: Vector2 = bay.at+w.Map.SERVICE_OFFSETS.oil
	use(w,drain_point,"none")
	check(order.oil==0,"Vidange autorisée avec le pont en bas")
	use(w,bay.lever_at,"lift",0.0)
	s.animate_bays(0.35,{})
	use(w,drain_point,"none")
	check(order.oil==0,"Vidange autorisée pendant la montée")
	use(w,s.bays[1].lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	check(bay.lift_raised and s.bays[1].lift_raised and not s.bays[2].lift_raised,
		"Les trois baies partagent l’état du pont")
	check(bay.car.position.y>s.bays[2].car.position.y+0.8 and s.bays[1].car.position.y>s.bays[2].car.position.y+0.8,
		"La position des voitures ne suit pas leurs ponts")
	use(w,drain_point,"drain")
	check(order.oil==1 and s.bays[1].order.oil==0,"Vidange appliquée à la mauvaise baie")
	w.update_hud()
	check(w.next_vehicle_work(0).lift==-1 and w.ticket.text.contains("Vider le bac au bidon")
		and w.ticket.text.contains("Bac à huile  ·  Pont indifférent"),
		"Le tableau ne dirige pas le joueur vers le bidon après la vidange")
	use(w,s.station_point("waste_oil"),"waste")
	w.update_hud()
	check(w.ticket.text.contains("Bouteille d’huile neuve  ·  Pont à baisser")
		and w.ticket.text.contains("Clé à choc  ·  Pont levé"),
		"Le remplissage d’huile et les pneus doivent afficher leurs propres exigences de pont")
	use(w,s.station_point("counter_0"),"surface",0.0)
	check(w.held=="","Dépôt au comptoir non instantané")
	use(w,s.station_point("fresh_oil"),"stock")
	use(w,drain_point,"none")
	check(order.oil==2,"Remplissage d’huile autorisé avec le pont levé")
	use(w,bay.lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	check(s.bays[1].lift_raised and s.bays[1].lift_height>0.9,"Abaisser le premier pont abaisse le second")
	use(w,drain_point,"fill_oil")
	use(w,s.station_point("trash"),"trash")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.battery,"remove_battery")
	use(w,s.station_point("trash"),"trash")
	use(w,s.station_point("new_battery"),"stock")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.battery,"install_battery")
	use(w,s.station_point("coolant"),"stock")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.coolant,"fill_coolant")
	use(w,s.station_point("trash"),"trash")
	use(w,s.station_point("tool_pressure"),"surface")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.pressure,"pressure")
	check(w.order_ready(order),"Les quatre services ne terminent pas la commande")
	use(w,s.station_point("tool_pressure"),"surface",0.0)
	use(w,w.driver_door(bay),"drive",0.0)
	var parked := park_north(w,bay)
	check(w.run.cash==0 and w.run.served==0 and bay.status=="" and parked.get("status")=="outdoors",
		"La voiture stationnée doit libérer la baie et rester disponible jusqu’au paiement")
	if parked.is_empty(): quit(1); return
	check(w.visitors[order.id].root.position.z>=0.0,"Le client a quitté la salle avant de payer")
	var parked_car: Node3D = parked.car
	settle_at_checkout(w,order.id)
	check(w.run.cash==140 and w.run.served==1 and parked.status=="departing" and parked.car==parked_car,
		"Le paiement efface la voiture ou ne prépare pas le départ")
	w.complete_invoice(parked)
	check(w.run.cash==140 and w.run.served==1,"Le client peut être facturé deux fois")
	check_customer_departure(w,parked)
	check(w.run.completed_repairs.get("oil")==1,"Vidange absente du bilan")
	check(s.bays[1].status=="parked","Le départ ferme une autre baie")
	var second: Dictionary = s.bays[1].order
	second.required.assign(["inspection","tires","brakes"])
	second.done.clear()
	second.issue = "battery"
	use(w,s.station_point("tool_inspection"),"surface")
	var inspection_point: Vector2 = s.bays[1].at+w.Map.SERVICE_OFFSETS.inspection
	use(w,inspection_point,"none")
	check(not second.done.has("inspection"),"Inspection autorisée avec le pont levé")
	use(w,s.bays[1].lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	use(w,inspection_point,"inspection")
	check(w.next_vehicle_work(1).label=="Parler au client pour la batterie",
		"Le tableau ne rappelle pas de consulter le client après le diagnostic")
	var rating: int = w.run.rating
	use(w,s.seats[1],"decline",1.0,true)
	check(w.run.rating==rating-1 and second.decision=="declined","Refus sans perte de demi-étoile")
	use(w,s.station_point("tool_inspection"),"surface",0.0)
	use(w,s.station_point("tool_tires"),"surface")
	use(w,s.bays[1].lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	for i in range(4): use(w,s.bays[1].at+w.Map.WHEEL_OFFSETS[i],"wheel")
	use(w,s.station_point("counter_2"),"surface",0.0)
	use(w,s.center(s.cart_cell),"cart")
	for i in range(4): use(w,s.bays[1].at+w.Map.WHEEL_OFFSETS[i],"wheel")
	check(w.cart_count==4 and w.cart_kind=="used_tire","Retrait des quatre roues avec le chariot")
	check(w.next_vehicle_work(1).item=="brake_pads" and w.next_vehicle_work(1).lift==1,
		"Le tableau doit indiquer les plaquettes tant que la roue avant est démontée")
	w.player = Vector2(s.used_tire_zone.position.x-0.5,18.5)
	w.facing = Vector2.RIGHT
	var pile: Vector2i = w.drop_cell()
	w.empty_cart()
	check(s.cells.has(pile) and s.cells[pile].count==4 and not s.clear_at(s.center(pile)),"Pile de pneus ou collision incorrecte")
	check(not w.can_drop(pile,"new_tire") and not w.can_drop(pile,"used_tire"),"Pile mixte ou trop haute autorisée")
	use(w,s.station_point("rack"),"rack_cart")
	use(w,s.bays[1].at+w.Map.WHEEL_OFFSETS[0],"none")
	check(second.wheels[0]==2 and w.cart_count==4,"Un pneu neuf masque les freins à réparer")
	w.player = Vector2(8.5,12.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	for wheel in w.Catalog.FRONT_WHEELS:
		take_part(w,"parts_chassis","brake_pads")
		use(w,s.bays[1].at+w.Map.WHEEL_OFFSETS[wheel],"brake_fit")
		check(second.wheels[wheel]==2 and not s.bays[1].tires[wheel].visible,
			"Le remplacement des plaquettes doit conserver la roue démontée")
	check(w.next_vehicle_work(1).item=="new_tire" and w.next_vehicle_work(1).lift==1,
		"Le tableau doit passer au pneu neuf après les plaquettes")
	use(w,s.center(s.cart_cell),"cart")
	for i in range(4): use(w,s.bays[1].at+w.Map.WHEEL_OFFSETS[i],"wheel")
	w.player = Vector2(8.5,12.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	check(not w.pulling_cart and s.cart_cell==Vector2i(9,12) and not s.clear_at(Vector2(9.5,12.5)),"Impossible de garer le chariot hors repère")
	use(w,s.center(pile),"floor_pick")
	check(w.held=="used_tire" and s.cells[pile].count==3,"La main prend plusieurs pneus empilés")
	w.set_held("")
	use(w,s.station_point("counter_2"),"surface")
	for i in range(4): use(w,s.bays[1].at+w.Map.WHEEL_OFFSETS[i],"wheel")
	check(second.done.has("tires") and second.done.has("brakes") and second.wheels==[4,4,4,4],
		"Un seul cycle des roues doit terminer pneus et plaquettes")
	use(w,s.station_point("counter_2"),"surface",0.0)
	use(w,w.driver_door(s.bays[1]),"none")
	check(s.bays[1].status=="parked","Conduite autorisée alors que le pont est levé")
	use(w,s.bays[1].lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	use(w,w.driver_door(s.bays[1]),"drive",0.0)
	var second_parked := park_north(w,s.bays[1])
	if second_parked.is_empty(): quit(1); return
	# Use the legal reverse-in orientation to exercise the driver's backing turn.
	second_parked.car.rotation.y = 0
	check(w.parking_ready(second_parked),"La voiture en marche arrière dépasse sa place")
	settle_at_checkout(w,second.id)
	check_customer_departure(w,second_parked)
	check(w.run.served==2 and s.bays[2].status=="parked","Le départ en baie 2 libère une autre baie")
	w.build(0)
	var counter: Vector2 = w.site.station_point("counter_0")
	aim(w,counter,"none")
	w.place_or_move()
	var old: Vector2i = w.site.stations.counter_0.tile
	w.player = Vector2(8.5,5.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	check(w.relocating=="" and w.site.stations.counter_0.tile!=old,"Réaménagement impossible dans la phase libre")
	w.show_vendor()
	check(w.menu.kind=="vendor" and w.menu.options.size()==3,"Vitrine de trois offres absente")
	w.menu.hide()
	check_miniature(w)
	check_battery_guide(w)
	check_available_repair_markers(w)
	check_chassis_repairs(w)
	check_ground_repairs(w)
	check_alternate_repairs(w)
	check_window_choices(w)
	check_safe_drops(w)
	await check_workshop_rotation(w)
	check_rotated_reception(w)
	check_used_tire_stacks(w)
	check_steering(w)
	check_assisted_entry(w)
	check_lever_validation(w)
	check_day_setup(w)
	check_vendor_upgrades(w)
	check_vendor_draw()
	await check_vendor_reroll(w)
	check_additional_upgrades(w)
	check_rare_vendor_offers(w)
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: dix jours, quatre plans, trois voitures indépendantes, réparations, file, piles, chariot, six baies miniatures, ponts indépendants, circulation, moteur à l’avant, bureau assis, arrivées au volant, réception, repère du véhicule accueilli, entrée manuelle, direction progressive, freinage, recentrage, repères verts, dix nouvelles réparations, démontage pneus-freins partagé, prochaines étapes par baie, caisse et accueil indépendants, paiement avant ou après le stationnement, départ des clients au volant, patience récurrente et fin de journée.")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func check_host_checkpoint(w) -> void:
	const Checkpoint := preload("res://host_save.gd")
	w.build(1)
	w.run.day = 3
	w.run.cash = 112
	w.run.purchases = {"vending":true,"lift":true}
	w.run.next_day_services = {"advertising":true}
	w.run.vendor_offers.assign([w.Catalog.VENDOR_OFFERS[0]])
	w.run.vendor_day = 3
	w.site.make_station("vending","Distributrice",Vector2i(5,6),Color("#92bfb0"),1.23)
	w.site.move_station("vending",Vector2i(5,6),2)
	w.site.move_station("counter_0",Vector2i(9,5),1)
	w.set_held("ratchet",-1,3)
	w.cart_count = 2
	w.cart_kind = "new_tire"
	var checkpoint := Checkpoint.capture(w)
	w.build(0)
	check(not Checkpoint.restore(w,""),"Une sauvegarde vide ne doit pas changer la partie")
	check(Checkpoint.restore(w,checkpoint),"La sauvegarde de l’hôte doit être relue")
	check(w.layout==1 and w.run.day==3 and w.run.cash==112 and w.run.mode=="open",
		"La reprise doit restaurer le garage, le jour et la caisse")
	check(w.site.stations.get("vending",{}).get("turn")==2 and w.site.stations.counter_0.tile==Vector2i(9,5)
		and w.site.stations.counter_0.turn==1 and w.held=="ratchet" and w.held_turn==3
		and w.cart_count==2 and w.cart_kind=="new_tire","L’équipement et son orientation doivent être conservés")
	check(w.run.next_day_services.has("advertising") and w.run.vendor_offers.size()==1 and w.site.van.visible,
		"Les améliorations et les offres du soir doivent être reprises")

func check_guest_worker(w) -> void:
	const Coop := preload("res://workshop_coop.gd")
	w.build(0)
	w.coop = Coop.new()
	w.run.start()
	var host_position: Vector2 = w.player
	var host_avatar: Node3D = w.game.avatar
	w.coop.tick(w,0.1,[true,1.0,0.0,1.0,0.0,0,0.0,0.0,0])
	check(w.coop.guest.player.x>4.5 and w.player==host_position and w.game.avatar==host_avatar,
		"J2 doit se déplacer indépendamment de l’hôte")
	var tool: Vector2 = w.site.station_point("tool_pressure")
	w.coop.guest.player = tool+Vector2.DOWN
	w.coop.guest.facing = Vector2.UP
	w.coop.guest.velocity = Vector2.ZERO
	w.coop.tick(w,0.1,[true,0.0,0.0,0.0,-1.0,Coop.USE,0.0,0.0,Coop.USE])
	check(not w.coop.guest.action.is_empty() and not w.coop.allows(w.target("surface","Manomètre",tool,0.36)),
		"Un poste utilisé par J2 doit être réservé pendant l’action")
	w.coop.tick(w,0.3,[true,0.0,0.0,0.0,-1.0,Coop.USE,0.0,0.0,0])
	check(w.coop.guest.held=="pressure" and w.held=="" and not w.site.stations.tool_pressure.has("top"),
		"J2 doit pouvoir prendre un outil avec son propre inventaire")
	w.coop.tick(w,0.016,[false,0.0,0.0,0.0,0.0,0,0.0,0.0,0])
	w.coop.take_rescued_item(w)
	check(w.held=="pressure" and w.coop.guest.held=="","L’hôte doit pouvoir récupérer un outil après une déconnexion")
	w.coop.reset()
	w.coop = null

func check_guest_driving(w) -> void:
	const Coop := preload("res://workshop_coop.gd")
	w.build(1)
	w.run.start()
	var site = w.site
	for i in range(site.bays.size()):
		var bay: Dictionary = site.bays[i]
		var order: Dictionary = w.run.new_order()
		order.required.assign(["pressure"])
		bay.order = order
		bay.status = "intake"
		bay.arrival_slot = i
		site.spawn_car(bay,order,bay.at,PI)
	w.coop = Coop.new()
	var host_bay: Dictionary = site.bays[0]
	var guest_bay: Dictionary = site.bays[1]
	var host_engine: AudioStreamPlayer = w.engine
	w.finish_repair(w.driver_action(host_bay,0))
	w.coop.tick(w,0.016,[true,0.0,0.0,0.0,0.0,0,0.0,0.0,0])

	var door: Vector2 = w.driver_door(host_bay)
	w.coop.guest.player = door-Vector2.RIGHT*0.4
	w.coop.guest.facing = Vector2.RIGHT
	w.coop.tick(w,0.016,[true,0.0,0.0,1.0,0.0,Coop.USE,0.0,0.0,Coop.USE])
	check(w.coop.guest.driven_bay==-1 and w.driven_bay==0,"J2 ne doit pas prendre le volant déjà occupé")

	door = w.driver_door(guest_bay)
	w.coop.guest.player = door-Vector2.RIGHT*0.4
	w.coop.guest.facing = Vector2.RIGHT
	w.coop.tick(w,0.016,[true,0.0,0.0,1.0,0.0,Coop.USE,0.0,0.0,Coop.USE])
	check(w.coop.guest.driven_bay==1 and w.driven_bay==0 and not w.coop.avatar.visible
		and w.coop.guest.engine!=host_engine and w.engine==host_engine,
		"Les deux conducteurs doivent avoir chacun leur voiture et leur moteur")
	if w.coop.guest.driven_bay!=1:
		w.coop.reset()
		w.coop = null
		return
	var before: Vector2 = site.vehicle_position(guest_bay)
	var host_before: Vector2 = site.vehicle_position(host_bay)
	w.coop.tick(w,0.1,[true,0.0,0.0,0.0,0.0,0,0.0,-1.0,0])
	check(site.vehicle_position(guest_bay).y<before.y and site.vehicle_position(host_bay)==host_before,
		"L’accélération de J2 doit déplacer sa voiture seule")
	w.coop.tick(w,0.25,[true,0.0,0.0,0.0,0.0,0,0.0,0.0,0])
	w.update_hud()
	check(w.coop.guide.get("ready",false) and guest_bay.intake_guide.root.visible
		and guest_bay.intake_guide.material.albedo_color==w.Map.PLACEMENT_READY_COLOR,
		"J2 doit voir le repère vert sur son pont pendant que l’hôte conduit")
	w.coop.tick(w,0.016,[true,0.0,0.0,0.0,0.0,Coop.TAKE,0.0,0.0,Coop.TAKE])
	check(guest_bay.status=="parked" and w.coop.guest.driven_bay==-1 and w.driven_bay==0,
		"Y doit stationner la voiture de J2 et le faire descendre")

	guest_bay.order.done.assign(["pressure"])
	door = w.driver_door(guest_bay)
	w.coop.guest.player = door-Vector2.RIGHT*0.4
	w.coop.guest.facing = Vector2.RIGHT
	w.coop.tick(w,0.016,[true,0.0,0.0,1.0,0.0,Coop.USE,0.0,0.0,Coop.USE])
	check(w.coop.guest.driven_bay==1,"J2 doit pouvoir reprendre une voiture réparée pour la sortir")
	w.coop.tick(w,0.016,[])
	check(not w.coop.other_drives(1) and guest_bay.status=="driving" and w.driven_bay==0,
		"Une déconnexion doit laisser la voiture récupérable par l’hôte")
	w.coop.reset()
	w.coop = null

func check_two_bays(w) -> void:
	w.build(1)
	var site = w.site
	use(w,site.station_point("phone"),"start")
	for i in range(2):
		var order: Dictionary = w.run.new_order()
		w.run.waiting.append(order)
		if not receive_customer(w,order): return
	w.update_hud()
	var marker: Label3D = site.intake_car_marker
	check(marker.visible and marker.text.contains(site.bays[1].order.name)
		and marker.text.contains("BAIE 02") and is_equal_approx(marker.position.x,site.bays[1].car.position.x),
		"Le repère ne pointe pas la dernière voiture accueillie")
	dock_incoming(w,site.bays[1])
	w.update_hud()
	check(marker.visible and marker.text.contains(site.bays[0].order.name) and marker.text.contains("BAIE 01")
		and is_equal_approx(marker.position.x,site.bays[0].car.position.x),
		"Le repère ne revient pas sur l’autre voiture à rentrer")
	dock_incoming(w,site.bays[0])
	w.update_hud()
	check(not marker.visible,"Le repère reste affiché une fois les deux voitures en baie")
	use(w,site.bays[0].lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	check(site.bays[0].lift_height>0.9 and site.bays[1].lift_height==0.0,"Les ponts du Tandem montent ensemble")
	use(w,site.bays[1].lever_at,"lift",0.0)
	use(w,site.bays[0].lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	check(site.bays[0].lift_height==0.0 and site.bays[1].lift_height>0.9,"Le Tandem ne peut pas inverser ses hauteurs")

func check_arrival_queue(w, layout := 0) -> void:
	w.build(layout)
	var site = w.site
	use(w,site.station_point("phone"),"start")
	var first: Dictionary = w.run.new_order()
	w.run.waiting.append(first)
	if not receive_customer(w,first): return
	dock_incoming(w,site.bays[0])
	var ids: Array[int] = []
	for i in range(site.arrivals.size()+1):
		var order: Dictionary = w.run.new_order()
		ids.append(order.id)
		w.run.waiting.append(order)
	for frame in range(720):
		w.advance_cars(0.05)
		w.refresh_visitors(0.05)
	if w.incoming.size()!=site.arrivals.size():
		failures.append("Le stationnement ne reçoit pas une file quand la baie est occupée")
		return
	var occupied := {}
	for id in w.incoming:
		var arrival: Dictionary = w.incoming[id]
		check(arrival.stage=="walk" and not occupied.has(arrival.slot),"Véhicules en attente superposés ou coincés")
		occupied[arrival.slot] = true
		var bounds: Rect2 = site.vehicle_bounds(site.vehicle_shape(site.vehicle_position(arrival),arrival.car.rotation.y))
		check(site.arrivals[arrival.slot].encloses(bounds),"Une arrivée ne termine pas dans sa place")
	check(not w.incoming.has(ids.back()) and w.visitor_at(ids[0],site.queue_head),
		"La file déborde sur une place occupée ou bloque le premier client")
	w.update_hud()
	check(not site.intake_car_marker.visible,"Une voiture dont le client attend encore est marquée")

func check_intro_brakes(w, layout := 0) -> void:
	w.build(layout)
	var site = w.site
	use(w,site.station_point("phone"),"start")
	w.run.tick(2.01,w.active_orders())
	check(w.run.waiting.size()==1,"Le garage doit proposer son premier ticket dès l’ouverture")
	if w.run.waiting.is_empty(): return
	var order: Dictionary = w.run.waiting.front()
	check(order.vehicle==0 and order.required==["brakes"],"Le premier ticket doit demander les plaquettes avant sur la berline")
	if not receive_customer(w,order): return
	var bay: Dictionary = site.bays.front()
	check(bay.car.has_node("CarrosserieKenney"),"Le ticket d’ouverture doit utiliser la berline Kenney")
	dock_incoming(w,bay)
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	var point: Vector2 = bay.at+w.Map.WHEEL_OFFSETS[0]
	loosen_and_remove(w,point)
	check(bay.discs[0].visible and not bay.tires[0].visible,"Le disque doit être visible sur la berline déposée")
	take_part(w,"parts_chassis","brake_pads")
	use(w,point,"brake_fit")
	use(w,point,"wheel")
	check(bay.tires[0].visible and not bay.discs[0].visible,"Le disque doit disparaître derrière la roue remontée")

func check_fleet_animations(w) -> void:
	w.build(0)
	var site = w.site
	var bay: Dictionary = site.bays.front()
	for kind in range(w.Day.VEHICLES.size()):
		var name: String = w.Day.VEHICLES[kind][0]
		site.spawn_car(bay,{"vehicle":kind},bay.at,PI)
		bay.status = "parked"
		check(bay.hood is MeshInstance3D and bay.hood.get_aabb().size.z>0.22 and bay.tires.size()==4,
			name+" · le capot doit être une pièce de la carrosserie avec son propre pivot")
		site.animate_bays(0.45,{"id":"remove_battery","bay":0})
		check(bay.hood.rotation.x<-0.9,name+" · ouverture du capot")
		site.animate_bays(0.45,{})
		check(is_zero_approx(bay.hood.rotation.x),name+" · fermeture du capot")
		for group in ["front","rear"]:
			site.flash_lights(bay,group)
			check(not bay.lights[group][0].material_override.emission_enabled
				and bay.lights[group][1].material_override.emission_enabled,name+" · le feu en panne doit être identifiable")
		site.flash_lights(bay,"")
		check(bay.lights.front[0].material_override.emission_enabled
			and bay.lights.rear[0].material_override.emission_enabled,name+" · test après réparation des feux")
		site.animate_bays(2.11,{})
		check(not bay.lights.front[0].material_override.emission_enabled
			and not bay.lights.rear[0].material_override.emission_enabled,name+" · extinction après le test")
		site.animate_bays(0.16,{"id":"wipers_test","bay":0})
		check(bay.wipers.size()==2 and bay.wipers[0].rotation.y>0.40
			and bay.wipers[1].rotation.y>0.40,name+" · mouvement des deux essuie-glaces")
		site.animate_bays(0.25,{})
		check(is_zero_approx(bay.wipers[0].rotation.y) and is_zero_approx(bay.wipers[1].rotation.y),
			name+" · retour des essuie-glaces au repos")
		site.remove_car(bay)

func check_repair_contacts(w) -> void:
	w.build(0)
	var site = w.site
	var visual = w.game.player_visual
	var bay: Dictionary = site.bays.front()
	for kind in range(w.Day.VEHICLES.size()):
		var order: Dictionary = w.run.new_order()
		order.vehicle = kind
		order.required.assign(["battery","tires"])
		site.spawn_car(bay,order,bay.at,PI)
		bay.status = "parked"
		bay.order = order
		bay.lift_raised = false
		site.animate_bays(1.0,{})
		w.player = bay.at+Vector2(0.20,-3.0)
		w.facing = Vector2.DOWN
		w.action = w.service_action(order,"battery",0,bay.at+w.Map.SERVICE_OFFSETS.battery)
		w.progress = 0.40
		site.animate_bays(w.progress,w.action)
		w.sync_player(0.1,0.0)
		check_contacts_at(visual,"%s · capot"%w.Day.VEHICLES[kind][0])
		w.cancel_action()
		bay.lift_raised = true
		site.animate_bays(1.0,{})
		for wheel in range(4):
			var point: Vector2 = bay.at+w.Map.WHEEL_OFFSETS[wheel]
			var direction := signf(point.x-bay.at.x)
			w.player = point+Vector2(direction*0.75,0.10)
			w.facing = Vector2(-direction,0)
			w.set_held("tires")
			w.action = w.wheel_action(order,wheel,point,0)
			w.progress = 0.32
			w.sync_player(0.1,0.0)
			check_contacts_at(visual,"Véhicule %d · clé, roue %d"%[kind,wheel])
			var tire: MeshInstance3D = bay.tires[wheel]
			var side := signf(bay.car.to_local(tire.global_position).x)
			var bounds := tire.get_aabb()
			var face := bounds.get_center()
			face.x = bounds.end.x if side>0.0 else bounds.position.x
			var target: Vector3 = tire.to_global(w.repair_pose.wheel_face(tire,face,side))
			var socket: Marker3D = w.item_prop.find_child("SocketTip",true,false)
			check(socket.global_position.distance_to(target)<0.03,"La douille doit rester dans l’axe du moyeu")
			w.cancel_action()
			w.set_held("")
			order.wheels[wheel] = 1
			w.action = w.wheel_action(order,wheel,point,0)
			w.progress = 0.43
			var rest := tire.position
			w.sync_player(0.1,0.0)
			check_contacts_at(visual,"Véhicule %d · retrait, roue %d"%[kind,wheel])
			check(tire.position.distance_to(rest)>0.08,"La roue doit suivre le geste de retrait")
			w.cancel_action()
			check(tire.position==rest and tire.visible and order.wheels[wheel]==1,
				"Annuler le retrait doit rendre sa position à la roue")
		site.remove_car(bay)
	for item in ["tires","used_tire"]:
		w.set_held(item)
		w.sync_player(0.2,0.0)
		check_contacts_at(visual,"Prise en main après la réparation")

func check_contacts_at(visual, description: String) -> void:
	check(visual.contact_targets.size()==2,"%s · deux prises doivent être actives"%description)
	for hand in range(visual.contact_targets.size()):
		var error: float = visual.hand_position(hand).distance_to(visual.contact_targets[hand])
		check(error<0.065,"%s · main %d à %.2f de sa prise"%[description,hand,error])

func check_miniature(w) -> void:
	var site = w.site
	use(w,site.station_point("phone"),"start")
	var order: Dictionary = w.run.new_order()
	order.required.assign(["tires","inspection"])
	order.issue = ""
	w.run.waiting.append(order)
	var bay: Dictionary = site.bays[0]
	check(receive_customer(w,order),"Le client miniature ne passe pas à la réception")
	if bay.status=="intake": dock_incoming(w,bay,true)
	for frame in range(50): w.refresh_visitors(0.1)
	check(bay.status=="parked","La voiture miniature n’est pas entrée en baie")
	if bay.status!="parked": return

	use(w,site.station_point("tool_tires"),"surface")
	var first_wheel: Vector2 = bay.at+w.Map.WHEEL_OFFSETS[0]
	use(w,first_wheel,"none")
	check(order.wheels[0]==0,"Desserrage autorisé sans lever la voiture")
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	check(bay.lift_height>0.9 and bay.car.position.y>1.0,"Le pont ne soulève pas la voiture")
	use(w,first_wheel,"wheel",0.5)
	w.advance_action(0.7,false,true)
	check(order.wheels[0]==1,"Le desserrage miniature ne termine pas")
	for wheel in range(1,4): use(w,bay.at+w.Map.WHEEL_OFFSETS[wheel],"wheel")
	use(w,site.station_point("counter_0"),"surface",0.0)
	use(w,site.center(site.cart_cell),"cart")
	for offset in w.Map.WHEEL_OFFSETS: use(w,bay.at+offset,"wheel")
	check(w.cart_count==4 and not bay.tires[0].visible,"Les roues déposées restent visibles")
	use(w,bay.lever_at,"none")
	check(bay.lift_raised,"Le pont redescend sans roues")
	w.player = Vector2(site.used_tire_zone.position.x-0.5,18.5)
	w.facing = Vector2.RIGHT
	w.empty_cart()
	use(w,site.station_point("rack"),"rack_cart")
	for offset in w.Map.WHEEL_OFFSETS: use(w,bay.at+offset,"wheel")
	check(w.cart_count==0 and bay.tires[0].visible,"Les roues neuves ne sont pas affichées")
	w.player = Vector2(17.5,9.5)
	w.facing = Vector2.DOWN
	w.place_or_move()
	use(w,site.station_point("counter_0"),"surface")
	for offset in w.Map.WHEEL_OFFSETS: use(w,bay.at+offset,"wheel")
	use(w,site.station_point("counter_0"),"surface",0.0)
	use(w,site.station_point("tool_inspection"),"surface")
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(0.5,{})
	use(w,bay.at+w.Map.SERVICE_OFFSETS.inspection,"none")
	site.animate_bays(0.5,{})
	use(w,bay.at+w.Map.SERVICE_OFFSETS.inspection,"inspection",1.0)
	site.animate_bays(0.50,w.action)
	check(bay.hood.rotation.x < -0.9,"Le capot reste fermé durant l’inspection")
	w.advance_action(1.1,false,true)
	check(w.order_ready(order),"La réparation miniature ne termine pas la demande")
	use(w,site.station_point("tool_inspection"),"surface",0.0)
	use(w,w.driver_door(bay),"none")
	check(bay.status=="parked" and w.driven_bay==-1,"Conduite autorisée avec le capot ouvert")
	site.animate_bays(0.6,{})
	use(w,w.driver_door(bay),"drive",0.0)
	check(w.driven_bay==0 and not w.game.avatar.visible,"Le personnage ne monte pas dans la voiture")
	var before: float = bay.car.position.z
	w.advance_cars(3.0)
	check(is_equal_approx(bay.car.position.z,before),"Le véhicule roule tout seul après l’embarquement")
	w.exit_driver_seat(true)
	check(w.driven_bay==0 and bay.status=="driving","Une place devant la baie valide le stationnement")
	w.exit_driver_seat(false)
	check(w.driven_bay==-1 and site.clear_at(w.player),"Impossible de descendre dans la baie")
	use(w,w.driver_door(bay),"drive",0.0)
	var parked := park_north(w,bay,true)
	if parked.is_empty(): return
	w.run.mode = "closing"
	w.tick(0.0)
	check(w.run.mode=="closing" and bay.status=="" and parked.status=="outdoors","Le bilan s’ouvre avant le règlement")
	settle_at_checkout(w,order.id)
	check(w.run.served==1 and w.run.cash>0,"La réparation miniature ne génère pas de facture")
	w.tick(0.0)
	check(w.run.mode=="closing" and w.active_orders().is_empty(),"Le bilan coupe le départ ou le client payé perd sa patience")
	check_customer_departure(w,parked)
	w.tick(0.0)
	check(w.run.mode=="open" and w.menu.kind=="summary","Le client payé bloque la fin de journée")
	w.menu.hide()

func receive_customer(w, order: Dictionary, hold_time := 2.1) -> bool:
	var site = w.site
	var saw_car := false
	var saw_unboard := false
	for frame in range(520):
		w.advance_cars(0.05)
		w.refresh_visitors(0.05)
		if w.incoming.has(order.id):
			var arrival: Dictionary = w.incoming[order.id]
			saw_car = saw_car or (arrival.stage=="drive" and arrival.car.position.z>30.0)
			saw_unboard = saw_unboard or arrival.stage=="unboard"
		if w.visitor_at(order.id,site.queue_head): break
	check(saw_car or (w.incoming.has(order.id) and w.incoming[order.id].distance>5.0),
		"Le client ne vient pas de la rue en voiture")
	check(saw_unboard or (w.incoming.has(order.id) and w.incoming[order.id].stage=="walk"),
		"Le client ne descend pas après s’être garé")
	if not w.incoming.has(order.id) or not w.visitor_at(order.id,site.queue_head):
		failures.append("Le client ne rejoint pas le comptoir")
		return false
	var car: Node3D = w.incoming[order.id].car
	var index: int = w.free_bay()
	use(w,site.reception_at,"receive",hold_time)
	if index<0:
		var accepted: bool = order in w.waiting_for_bay and w.incoming[order.id].car==car
		check(accepted,"Le comptoir doit accueillir le client même si toutes les baies sont occupées")
		return accepted
	if site.bays[index].status!="intake": return false
	check(site.bays[index].car==car and not w.incoming.has(order.id),"L’accueil remplace la voiture du client")
	return true

func dock_incoming(w, bay: Dictionary, verify_controls := false) -> void:
	var departure: Vector2 = w.site.vehicle_position(bay)
	check(absf(departure.x-bay.at.x)<0.01,"Le scénario doit partir de la place alignée sur cette baie")
	if verify_controls:
		check(w.run.cash==0 and w.site.bays[0].status=="intake","Une voiture dehors est prête aux réparations")
		check(w.site.bays[0].gates[0].position.y<0.1,"La porte du haut s’ouvre avant l’entrée")
	use(w,w.driver_door(bay),"drive",0.0)
	if w.driven_bay<0: return
	if verify_controls:
		w.advance_cars(1.0)
		check(w.site.vehicle_position(bay)==departure,"Le véhicule rentre sans commande")
		w.exit_driver_seat(true)
		check(w.driven_bay>=0 and bay.status=="intake","Le stationnement est validé dehors")
		w.update_hud()
		check(not w.site.intake_car_marker.visible,"Le repère masque la route pendant la conduite")
		w.exit_driver_seat(false)
		w.update_hud()
		check(w.site.intake_car_marker.visible,"Le repère ne revient pas quand on descend dehors")
		use(w,w.driver_door(bay),"drive",0.0)
		if w.driven_bay<0: return
	finish_docking(w,bay)

func finish_docking(w, bay: Dictionary) -> void:
	for frame in range(480):
		w.advance_cars(1.0/60.0)
		var input := Vector2.UP if bay.car.position.z>bay.at.y+0.18 else Vector2.ZERO
		w.drive_vehicle(input,1.0/60.0)
		if input==Vector2.ZERO and is_zero_approx(w.drive_speed): break
	check(w.intake_status(bay)==w.IntakeStatus.READY,"La voiture ne peut pas atteindre le pont par le bas · %s"%w.intake_prompt(w.intake_status(bay)))
	w.exit_driver_seat(true)
	check(w.driven_bay==-1 and bay.status=="parked" and w.site.vehicle_position(bay)==bay.at
		and w.game.avatar.visible and w.site.clear_at(w.player),"La voiture n’est pas prête en baie après Y/E")

func check_customer_departure(w, parked: Dictionary) -> void:
	var id: int = parked.order.id
	var initial: Vector2 = w.site.vehicle_position(parked)
	var walked := false
	var boarded := false
	var drove := false
	for frame in range(500):
		if not w.departures.has(id): break
		var departure: Dictionary = w.departures[id]
		if departure.stage=="walk":
			check(w.site.vehicle_position(parked)==initial,"La voiture roule avant que son client soit monté")
			walked = walked or departure.outdoors
		elif departure.stage=="board":
			boarded = true
		elif departure.stage=="road":
			drove = drove or w.site.vehicle_position(parked).distance_to(initial)>5.0
		w.advance_cars(0.05)
		w.refresh_visitors(0.05)
	check(walked and boarded and drove,"Trajet piéton, embarquement ou sortie sur la rue absent")
	check(parked.car==null and not w.parked_cars.has(id) and not w.departures.has(id) and not w.visitors.has(id),
		"Le client ou sa voiture bloque toujours la place extérieure après le départ")

func check_reception_while_busy(w) -> void:
	w.build(0)
	w.menu.hide()
	var site = w.site
	use(w,site.station_point("phone"),"start")
	var first: Dictionary = w.run.new_order()
	first.required.assign(["pressure"])
	first.issue = ""
	w.run.waiting.append(first)
	if not receive_customer(w,first): return
	var bay: Dictionary = site.bays[0]
	var second: Dictionary = w.run.new_order()
	var third: Dictionary = w.run.new_order()
	w.run.waiting.append(second)
	w.run.waiting.append(third)
	if not receive_customer(w,second): return
	dock_incoming(w,bay)
	if not receive_customer(w,third): return
	var arrival: Dictionary = w.incoming[second.id]
	var slot: int = arrival.slot
	var car: Node3D = arrival.car
	for frame in range(75): w.refresh_visitors(0.05)
	w.update_hud()
	var places: Array[Vector2] = site.bay_waiting_places()
	check(bay.order.id==first.id and bay.status=="parked" and w.waiting_for_bay==[second,third]
		and w.active_orders().size()==3 and w.run.waiting.is_empty()
		and w.visitor_at(second.id,places[0]) and w.visitor_at(third.id,places[1])
		and w.ticket.text.contains("ATTENTE D’UNE BAIE"),
		"Les clients accueillis doivent attendre leur tour sans interrompre la réparation en cours")
	use(w,site.station_point("tool_pressure"),"surface")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.pressure,"pressure")
	use(w,site.station_point("tool_pressure"),"surface",0.0)
	invite_customer_to_checkout(w,first.id)
	use(w,w.driver_door(bay),"drive",0.0)
	var parked := park_north(w,bay)
	if parked.is_empty(): return
	w.update_hud()
	check(bay.status=="intake" and bay.car==car and bay.arrival_slot==slot and slot!=0
		and w.waiting_for_bay==[third] and not w.incoming.has(second.id) and w.site.intake_car_marker.visible
		and w.run.cash==0 and not first.paid and first in w.active_orders()
		and w.checkout_queue==[first.id] and w.ticket.text.contains("STATIONNEMENT DE SORTIE"),
		"Le stationnement doit affecter le prochain client à la baie et garder la première facture en attente")
	use(w,w.driver_door(bay),"drive",0.0)
	check(w.driven_bay==0,"La voiture promue doit être accessible depuis sa place d’arrivée latérale")
	if w.driven_bay<0: return
	for frame in range(120):
		if bay.car.rotation.y<=PI-0.74: break
		w.advance_cars(1.0/60.0)
		w.drive_vehicle(Vector2(1.0,-0.56),1.0/60.0)
	for frame in range(240):
		if bay.car.position.x>=bay.at.x-0.44: break
		w.advance_cars(1.0/60.0)
		w.drive_vehicle(Vector2(0.0,-0.56),1.0/60.0)
	for frame in range(120):
		if bay.car.rotation.y>=PI-0.025: break
		w.advance_cars(1.0/60.0)
		w.drive_vehicle(Vector2(-1.0,-0.56),1.0/60.0)
	finish_docking(w,bay)
	check(bay.status=="parked" and bay.order.id==second.id and parked.car!=bay.car and not first.paid,
		"Le deuxième véhicule doit pouvoir entrer sur le pont avant le premier paiement")
	check(w.parking_placement(bay).status==w.ParkingStatus.FULL,"La première voiture doit garder sa place extérieure")
	settle_at_checkout(w,first.id)
	check(first.paid and not second.paid and w.run.cash==25 and parked.status=="departing",
		"La facture du premier client doit rester accessible et indépendante")
	if parked.status=="departing": check_customer_departure(w,parked)
	check(bay.car==car and bay.status=="parked" and w.exit_slot_free(0),
		"Le départ de la première voiture ne doit pas modifier le véhicule déjà en baie")

func park_north(w, bay: Dictionary, verify_assist := false, use_cancel := false) -> Dictionary:
	check(w.driven_bay>=0,"Impossible de prendre le volant")
	if w.driven_bay<0: return {}
	var order_id: int = bay.order.id
	var guide: Dictionary = bay.parking_guide
	if verify_assist:
		w.update_hud()
		check(guide.root.visible and not bay.intake_guide.root.visible
			and guide.material.albedo_color==w.Map.PLACEMENT_GUIDE_COLOR,
			"La place de sortie n’est pas indiquée avant le stationnement")
	var target_z: float = bay.parking.get_center().y+0.18
	for frame in range(360):
		w.advance_cars(1.0/60.0)
		var input := Vector2.UP if bay.car.position.z>target_z else Vector2.ZERO
		w.drive_vehicle(input,1.0/60.0)
		if input==Vector2.ZERO and is_zero_approx(w.drive_speed): break
	check(w.parking_ready(bay),"La voiture n’atteint pas la place par la sortie")
	if verify_assist:
		var offset: Vector2 = w.site.vehicle_position(bay)+Vector2(0.71,0.0)
		w.apply_vehicle_pose(bay,offset,PI)
		check(not w.parking_ready(bay) and w.parking_ready(bay,w.PARKING_MARGIN),
			"Le stationnement de test ne présente pas le léger décalage attendu")
		w.drive_speed = 2.0
		w.update_hud()
		check(w.footer.text.contains("pour freiner") and guide.material.albedo_color==w.Map.PLACEMENT_GUIDE_COLOR,
			"La place passe au vert avant que la voiture ait ralenti")
		w.drive_speed = 0.0
		var blocked: Vector2i = w.site.cell(bay.parking.get_center())
		w.site.cells[blocked] = {"kind":"cart"}
		w.update_hud()
		check(w.footer.text.contains("Dégage la place") and guide.material.albedo_color==w.Map.PLACEMENT_GUIDE_COLOR,
			"La place passe au vert malgré un obstacle")
		w.exit_driver_seat(true)
		check(w.driven_bay>=0,"La voiture se stationne malgré un obstacle")
		w.site.cells.erase(blocked)
		w.update_hud()
		check(w.footer.text.contains("Bien placé") and w.footer.text.contains("Y / E")
			and w.ticket.text.contains("Bien placé") and guide.material.albedo_color==w.Map.PLACEMENT_READY_COLOR,
			"La place prête ne montre pas le contour vert et la commande")
	w.exit_driver_seat(not use_cancel)
	var parked: Dictionary = w.parked_cars.get(order_id,{})
	check(not parked.is_empty(),"La voiture n’a pas été transférée au stationnement de sortie")
	if verify_assist:
		w.update_hud()
		check(not parked.is_empty() and w.parking_ready(parked) and not guide.root.visible and w.ticket.text.contains("À encaisser"),
			"Le stationnement ne confirme pas le passage au paiement")
	check(w.driven_bay==-1 and w.game.avatar.visible and w.site.clear_at(w.player),
		"Le stationnement ne rend pas le personnage au joueur")
	w.advance_cars(0.5)
	var path: Dictionary = w.reachable_tiles(w.player,true)
	check(path.has(w.site.customer_entrance_tile()),"Le conducteur ne peut pas revenir par l’accès piéton")
	return parked

func invite_customer_to_checkout(w, order_id: int) -> void:
	if order_id in w.checkout_queue: return
	var site = w.site
	var holder: Dictionary = w.find_customer_holder(order_id)
	var index: int = site.bays.find(holder)
	if index>=0:
		for frame in range(65):
			if w.visitor_at(order_id,site.seats[index]): break
			w.refresh_visitors(0.08)
		use(w,site.seats[index],"call_checkout",0.016)
	else:
		var position: Vector3 = w.visitors[order_id].root.position
		use(w,Vector2(position.x,position.z),"call_checkout",0.016)

func settle_at_checkout(w, order_id: int) -> void:
	invite_customer_to_checkout(w,order_id)
	wait_at_checkout(w,order_id)
	use(w,w.site.checkout_at,"payment",3.0)

func wait_at_checkout(w, order_id: int) -> void:
	var point: Vector2 = w.site.checkout_head
	for frame in range(160):
		if w.visitor_at(order_id,point): break
		w.refresh_visitors(0.05)
	check(w.visitor_at(order_id,point),"Le client ne rejoint pas la caisse")

func check_first_payment(w, layout := 0) -> void:
	w.build(layout)
	w.menu.hide()
	var site = w.site
	var phone: Vector2 = site.station_point("phone")
	use(w,phone,"start")
	w.run.tick(2.0,w.active_orders())
	var first: Dictionary = w.run.waiting.front()
	first.required.assign(["pressure"])
	first.issue = ""
	if not receive_customer(w,first): return
	var bay: Dictionary = site.bays[0]
	dock_incoming(w,bay)
	use(w,site.station_point("tool_pressure"),"surface")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.pressure,"pressure")
	use(w,site.station_point("tool_pressure"),"surface",0.0)
	settle_at_checkout(w,first.id)
	check(first.paid and w.run.served==1 and w.run.cash==25 and bay.status=="parked",
		"Le premier client doit pouvoir payer même si sa voiture est encore sur le pont")
	if not first.paid: return
	check(w.active_orders().is_empty() and w.departures.is_empty(),
		"Un client payé qui attend encore sa voiture ne doit ni perdre patience ni embarquer")
	w.run.mode = "closing"
	w.tick(0.0)
	check(w.run.mode=="closing","Le bilan s’ouvre alors qu’il faut encore sortir une voiture payée")
	w.run.mode = "day"
	for frame in range(240): w.refresh_visitors(0.05)
	var waiting_point: Vector2 = w.waiting_by_parking(0)
	check(waiting_point.y<0.0 and w.visitor_at(first.id,waiting_point)
		and w.visitors[first.id].meter.text.contains("Attend sa voiture"),
		"Le client payé ne rejoint pas le bord d’une place de sortie libre")
	use(w,w.driver_door(bay),"drive",0.0)
	check(w.engine.playing,"Le moteur doit se mettre en route en prenant le volant")
	var parked := park_north(w,bay,false,true)
	check(parked.get("status")=="departing" and not w.engine.playing,
		"Le moteur du joueur doit s’arrêter au stationnement et le client payé doit rejoindre sa voiture")
	if parked.get("status")!="departing": return
	check_customer_departure(w,parked)
	use(w,phone,"call")
	check(w.run.appointments.size()==1,"Le téléphone reste inaccessible après le premier client")
	w.run.tick(4.1,w.active_orders())
	check(not w.run.waiting.is_empty(),"Le rendez-vous suivant n’arrive pas")
	if w.run.waiting.is_empty(): return
	var second: Dictionary = w.run.waiting.front()
	check(receive_customer(w,second) and bay.order.get("id")==second.id,
		"La baie n’accepte pas de nouveau client après le départ du premier")

func check_checkout_queue(w) -> void:
	w.build(1)
	var site = w.site
	use(w,site.station_point("phone"),"start")
	for i in range(2):
		var order: Dictionary = w.run.new_order()
		order.required.assign(["pressure"])
		order.issue = ""
		w.run.waiting.append(order)
		if not receive_customer(w,order): return
		dock_incoming(w,site.bays[i])
	for frame in range(65): w.refresh_visitors(0.1)
	use(w,site.station_point("tool_pressure"),"surface")
	for bay in site.bays:
		use(w,bay.at+w.Map.SERVICE_OFFSETS.pressure,"pressure")
	use(w,site.station_point("tool_pressure"),"surface",0.0)
	use(w,site.seats[1],"call_checkout",0.016)
	use(w,site.seats[0],"call_checkout",0.016)
	wait_at_checkout(w,site.bays[1].order.id)
	check(w.checkout_queue==[site.bays[1].order.id,site.bays[0].order.id] and w.visitor_at(site.bays[0].order.id,site.seats[0]),
		"Le deuxième client invité doit rester assis pendant le paiement du premier")
	use(w,site.checkout_at,"payment",2.9)
	check(w.run.cash==0 and not site.bays[1].order.paid,"La caisse termine avant trois secondes")
	w.advance_action(0.1,false,true)
	check(w.run.cash==25 and site.bays[1].order.paid and not site.bays[0].order.paid,
		"La caisse débite le mauvais client ou les deux clients")
	wait_at_checkout(w,site.bays[0].order.id)
	use(w,site.checkout_at,"payment",3.0)
	check(w.run.cash==50 and w.checkout_queue.is_empty(),"Le deuxième paiement n’avance pas la file")
	w.update_hud()
	for i in range(2):
		var waiting_bay: Dictionary = site.bays[i]
		var marker: Label3D = waiting_bay.waiting_marker
		var slot := "P %02d"%(i+1)
		check(marker.visible and marker.text.begins_with(waiting_bay.order.name+"\n"+slot+"\n")
			and is_equal_approx(marker.position.x,waiting_bay.parking.get_center().x)
			and w.ticket.text.contains("attend en [b]"+slot+"[/b]"),
			"Le repère et le tableau doivent identifier la place de chaque client payé")
	var bay: Dictionary = site.bays[0]
	use(w,w.driver_door(bay),"drive",0.0)
	if w.driven_bay!=0: return
	w.apply_vehicle_pose(bay,Vector2(site.bays[1].at.x,-2.8),PI)
	w.update_hud()
	check(w.footer.text.contains("Rejoins la place P 01") and bay.parking_guide.root.visible,
		"En approche, le jeu doit guider le conducteur vers la place où son client attend")
	w.apply_vehicle_pose(bay,site.bays[1].parking.get_center(),PI)
	check(w.parking_placement(bay).slot==1,"Une autre place libre devrait être utilisable")
	var order_id: int = bay.order.id
	w.exit_driver_seat(true)
	w.refresh_visitors(0.05)
	w.update_hud()
	var parked: Dictionary = w.parked_cars.get(order_id,{})
	var other: Dictionary = site.bays[1]
	check(parked.get("status")=="departing" and parked.get("exit_slot",-1)==1 and other.get("wait_slot",-1)==0,
		"Le client payé doit attendre près d’une autre place si celle qu’il visait a été occupée")
	check(not bay.waiting_marker.visible and other.waiting_marker.visible
		and other.waiting_marker.text.begins_with(other.order.name+"\nP 01\n")
		and is_equal_approx(other.waiting_marker.position.x,bay.parking.get_center().x)
		and w.ticket.text.contains("attend en [b]P 01[/b]")
		and not w.ticket.text.contains("attend en [b]P 02[/b]"),
		"Le repère du client parti doit disparaître et celui du client réaffecté doit suivre sa nouvelle place")
	if parked.get("status")=="departing": check_customer_departure(w,parked)

func check_steering(w) -> void:
	w.build(1)
	use(w,w.site.station_point("phone"),"start")
	for i in range(2):
		var order: Dictionary = w.run.new_order()
		order.required.clear()
		order.issue = ""
		w.run.waiting.append(order)
		if receive_customer(w,order): dock_incoming(w,w.site.bays[i])
	var bay: Dictionary = w.site.bays[0]
	var other: Dictionary = w.site.bays[1]
	check(not w.site.vehicle_can_move(bay,Vector2(bay.at.x,0.08),PI),"La voiture passe à travers la porte fermée")
	check(not w.site.vehicle_can_move(bay,Vector2(other.at.x,8),PI),"Les voitures peuvent se chevaucher")
	var obstacle := Vector2i(16,5)
	w.site.cells[obstacle] = {"kind":"cart"}
	check(not w.site.vehicle_can_move(bay,Vector2(15.8,5.5),PI),"La voiture traverse un obstacle déposé")
	w.site.cells.erase(obstacle)
	use(w,w.driver_door(bay),"drive",0.0)
	var origin: Vector2 = w.site.vehicle_position(bay)
	for frame in range(15): w.drive_vehicle(Vector2(0.11,-0.12),1.0/60.0)
	check(w.site.vehicle_position(bay)==origin and is_equal_approx(bay.car.rotation.y,PI),
		"Le bruit du stick fait dériver le véhicule")
	for frame in range(18): w.drive_vehicle(Vector2.RIGHT,1.0/60.0)
	check(is_equal_approx(bay.car.rotation.y,PI) and w.site.vehicle_position(bay)==origin
		and bay.tires[0].rotation.y<-0.45 and bay.tires[2].rotation.y<-0.45
		and is_zero_approx(bay.tires[1].rotation.y),
		"Le braquage à l’arrêt doit orienter uniquement les roues avant")
	w.apply_vehicle_pose(bay,origin,PI)
	w.drive_steering = 0.0
	for frame in range(18): w.drive_vehicle(Vector2(0.72,-0.88),1.0/60.0)
	check(bay.car.rotation.y<PI-0.10 and bay.car.position.x>origin.x+0.02,
		"Le stick ne tourne pas la voiture pendant la marche avant")
	var brake_start: Vector2 = w.site.vehicle_position(bay)
	for frame in range(12):
		if w.drive_speed<=0.0: break
		w.drive_vehicle(Vector2.DOWN,1.0/60.0)
	check(is_zero_approx(w.drive_speed) and w.site.vehicle_position(bay).distance_to(brake_start)<0.30,
		"Le stick doit freiner jusqu’à zéro avant de permettre la marche arrière")
	var stopped: float = bay.car.position.z
	for frame in range(16): w.drive_vehicle(Vector2.DOWN,1.0/60.0)
	check(bay.car.position.z>stopped+0.15,"La marche arrière ne fonctionne pas")

func check_assisted_entry(w) -> void:
	w.build(0)
	use(w,w.site.station_point("phone"),"start")
	var order: Dictionary = w.run.new_order()
	order.issue = ""
	w.run.waiting.append(order)
	if not receive_customer(w,order): return
	var bay: Dictionary = w.site.bays[0]
	use(w,w.driver_door(bay),"drive",0.0)
	if w.driven_bay<0: return
	w.update_hud()
	var guide: Dictionary = bay.intake_guide
	check(guide.root.visible and guide.material.albedo_color==w.Map.PLACEMENT_GUIDE_COLOR
		and w.footer.text.contains("Rejoins le pont"),"Le pont n’indique pas le trajet à l’approche")
	var approach := Vector2(16.24,22.0)
	check(w.site.vehicle_can_move(bay,approach,PI-0.24),"Position d’approche invalide")
	w.apply_vehicle_pose(bay,approach,PI-0.24)
	for frame in range(14): w.drive_vehicle(Vector2(0,-0.31),1.0/60.0)
	check(absf(w.drive_speed)<0.60 and bay.car.position.z<approach.y,
		"Une légère pression du stick fait bondir la voiture")
	var passed_door := false
	for frame in range(430):
		w.advance_cars(1.0/60.0)
		var input := Vector2.UP if bay.car.position.z>bay.at.y+0.18 else Vector2.ZERO
		w.drive_vehicle(input,1.0/60.0)
		if not passed_door and bay.car.position.z<17.0:
			passed_door = true
			check(absf(bay.car.position.x-bay.at.x)<0.38 and absf(angle_difference(bay.car.rotation.y,PI))<0.14,
				"La voiture accroche le montant au lieu de se recentrer")
		if input==Vector2.ZERO and is_zero_approx(w.drive_speed): break
	check(passed_door and w.intake_status(bay)==w.IntakeStatus.READY,"L’approche décalée ne rejoint pas le pont")
	w.drive_speed = 2.0
	w.update_hud()
	check(w.footer.text.contains("pour freiner") and guide.material.albedo_color==w.Map.PLACEMENT_GUIDE_COLOR,
		"Le repère passe au vert avant d’avoir ralenti")
	w.exit_driver_seat(true)
	check(w.driven_bay>=0,"La validation accepte une vitesse excessive")
	w.drive_speed = 0.0
	var occupied: Vector2i = w.site.cell(bay.at)
	w.site.cells[occupied] = {"kind":"cart"}
	w.update_hud()
	check(w.footer.text.contains("Dégage le pont") and guide.material.albedo_color==w.Map.PLACEMENT_GUIDE_COLOR,
		"Le repère vert autorise une place obstruée")
	w.site.cells.erase(occupied)
	w.update_hud()
	check(w.footer.text.contains("Bien placé") and w.footer.text.contains("Y / E ou B / Q")
		and w.ticket.text.contains("Bien placé") and guide.material.albedo_color==w.Map.PLACEMENT_READY_COLOR,
		"La position validable doit afficher le repère vert et la commande")
	w.exit_driver_seat(false)
	w.update_hud()
	check(bay.status=="parked" and w.site.vehicle_position(bay)==bay.at and w.driven_bay==-1,
		"Descendre avec B à l’arrêt doit valider et centrer la voiture sur le pont")
	check(not guide.root.visible and w.ticket.text.contains("En place") and w.footer.text.contains("Véhicule en place"),
		"Le jeu ne confirme pas que les réparations sont disponibles")

func check_lever_validation(w) -> void:
	w.build(0)
	var site = w.site
	use(w,site.station_point("phone"),"start")
	var order: Dictionary = w.run.new_order()
	order.required.assign(["tires"])
	w.run.waiting.append(order)
	if not receive_customer(w,order): return
	var bay: Dictionary = site.bays[0]
	use(w,w.driver_door(bay),"drive",0.0)
	if w.driven_bay<0: return
	w.apply_vehicle_pose(bay,bay.at+Vector2(0.8,0.1),PI)
	w.exit_driver_seat(false)
	check(bay.status=="intake" and w.driven_bay==-1 and not bay.lift_raised,
		"B doit laisser une voiture mal alignée à rentrer")
	check(aim(w,bay.lever_at,"none") and w.context().get("label","").contains("Reprends le volant"),
		"Le levier doit expliquer comment corriger l’alignement")
	w.apply_vehicle_pose(bay,bay.at+Vector2(0.2,0.25),PI)
	w.update_hud()
	check(w.ticket.text.contains("A / F au levier") and w.footer.text.contains("Valider la position"),
		"Une voiture alignée sur le pont doit pouvoir être validée du côté du levier")
	if not aim(w,bay.lever_at,"validate_lift"):
		check(false,"La validation par le levier est inaccessible")
		return
	var position: Vector2 = w.player
	w.advance_action(0.016,true,true)
	site.animate_bays(1.0,{})
	check(bay.status=="parked" and bay.lift_raised and site.vehicle_position(bay)==bay.at
		and not bay.has("arrival_slot") and w.accepted_intakes.is_empty() and w.player==position
		and site.clear_at(w.player),"Le levier ne valide pas puis ne lève pas la voiture correctement")

func check_safe_drops(w) -> void:
	w.build(1)
	var site = w.site
	w.set_held("oil")
	w.player = Vector2(9.5,7.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	check(w.held=="oil" and not site.cells.has(w.drop_cell()),"Un outil peut encore être posé au sol")
	check(aim(w,site.station_point("counter_0"),"surface"),"Le comptoir doit recevoir le bac à huile")
	w.place_or_move()
	check(w.held=="" and site.stations.counter_0.top.item=="oil","Y doit poser le bac sur le comptoir immédiatement")
	w.set_held("used_tire")
	w.facing = Vector2.RIGHT
	w.player = Vector2(9.84,7.5)
	var adjacent: Vector2i = w.drop_cell()
	w.place_or_move()
	check(w.held=="used_tire" and not site.cells.has(adjacent) and site.clear_at(w.player),
		"Le dépôt couvre la collision du joueur au bord de la case")
	w.player = Vector2(9.5,7.5)
	w.place_or_move()
	check(w.held=="" and site.cells.has(adjacent) and site.clear_at(w.player),
		"Une case voisine accessible refuse le dépôt")

	for direction in [Vector2.UP,Vector2.DOWN]:
		w.set_held("used_tire")
		w.player = Vector2(11.5,7.5)+2*direction
		w.facing = -direction
		w.place_or_move()
	check(site.cells.has(Vector2i(11,6)) and site.cells.has(Vector2i(11,8)),"Préparation du passage étroit impossible")
	w.set_held("used_tire")
	w.player = Vector2(11.5,7.5)
	w.facing = Vector2.RIGHT
	check(w.can_drop(Vector2i(12,7),"used_tire"),"La dernière case de sortie doit être libre")
	w.place_or_move()
	check(w.held=="used_tire" and not site.cells.has(Vector2i(12,7)),"Un dépôt ferme la seule sortie du joueur")
	w.player = Vector2(13.5,11.5)
	check(not w.can_drop(Vector2i(14,11),"cart"),"Le chariot peut bloquer la sortie du véhicule")

func check_workshop_rotation(w) -> void:
	w.build(0)
	w.menu.hide()
	var site = w.site
	var origin: Vector2i = site.stations.rack.tile
	var next_cell := origin+Vector2i.DOWN
	check(aim(w,site.station_point("rack"),"rack_hand"),"Le rack doit pouvoir être visé pour pivoter")
	w.place_or_move()
	w.player = site.center(origin)+Vector2.RIGHT
	w.facing = Vector2.LEFT
	w.game.set_physics_process(true)
	Input.action_press("rotate_item")
	await physics_frame
	await physics_frame
	Input.action_release("rotate_item")
	w.game.set_physics_process(false)
	check(w.relocating_turn==1 and site.preview.scale==Vector3(1,1,2)
		and is_equal_approx(site.stations.rack.root.rotation.y,-PI/2),
		"X doit faire pivoter le modèle et l’emprise de deux cases")
	site.cells[next_cell] = {"kind":"preview"}
	check(not w.can_drop(origin,"rack"),"La seconde case de l’emprise tournée doit rester libre")
	site.cells.erase(next_cell)
	w.place_or_move()
	check(w.relocating=="" and site.cells.get(next_cell,{}).get("id")=="rack"
		and not site.cells.has(origin+Vector2i.RIGHT) and not site.clear_at(site.center(next_cell)),
		"Le rack tourné doit occuper uniquement les deux nouvelles cases")
	check(aim(w,site.station_point("rack"),"rack_hand"),"Le rack tourné doit rester utilisable")
	w.place_or_move()
	w.rotate_or_unload()
	w.game.set_physics_process(true)
	Input.action_press("cancel_item")
	await physics_frame
	await physics_frame
	Input.action_release("cancel_item")
	w.game.set_physics_process(false)
	check(w.relocating=="" and site.stations.rack.tile==origin and site.stations.rack.turn==1
		and is_equal_approx(site.stations.rack.root.rotation.y,-PI/2),
		"B doit rétablir l’emplacement et l’orientation enregistrés")

	var surface: Vector2i = site.stations.counter_0.tile
	site.move_station("counter_0",surface,2)
	use(w,site.station_point("tool_pressure"),"surface")
	w.rotate_or_unload()
	var item_turn: int = w.held_turn
	w.sync_player(0.016,0)
	check(item_turn>=0 and is_zero_approx(angle_difference(w.item_prop.global_rotation.y,w.Map.turn_yaw(item_turn))),
		"L’outil tenu doit pivoter dans le monde")
	use(w,site.station_point("counter_0"),"surface",0.0)
	check(site.stations.counter_0.get("top",{}).get("turn",-1)==posmod(item_turn-2,4),
		"Le dépôt doit conserver la rotation sur un comptoir déjà tourné")
	use(w,site.station_point("phone"),"start")
	use(w,site.station_point("counter_0"),"surface")
	check(w.held_turn==item_turn,"L’outil repris doit conserver son orientation")
	w.run.mode = "closing"
	w.tick(0.0)
	check(site.stations.rack.turn==1 and site.stations.counter_0.get("top",{}).get("turn",-1)==posmod(item_turn-2,4),
		"Le rangement du soir doit retrouver les orientations préparées")
	w.menu.hide()

func check_rotated_reception(w) -> void:
	w.build(0)
	var site = w.site
	check(aim(w,site.station_point("reception"),"none"),"Le comptoir doit pouvoir être visé")
	w.place_or_move()
	w.rotate_or_unload()
	w.player = Vector2(2.5,11.5)
	w.facing = Vector2.DOWN
	w.place_or_move()
	check(w.relocating=="" and site.stations.reception.turn==1
		and site.reception_at==Vector2(2.5,13.5) and site.checkout_at==Vector2(2.5,12.5),
		"L’accueil et la caisse doivent suivre la rotation du comptoir")
	if w.relocating!="": return
	use(w,site.station_point("phone"),"start")
	var order: Dictionary = w.run.new_order()
	order.required.assign(["pressure"])
	w.run.waiting.append(order)
	if not receive_customer(w,order): return
	dock_incoming(w,site.bays[0])
	order.done.assign(["pressure"])
	settle_at_checkout(w,order.id)
	check(order.paid and w.run.cash==25,"Un comptoir tourné doit pouvoir accueillir et encaisser")

func check_used_tire_stacks(w) -> void:
	w.build(1)
	var site = w.site
	var pile := Vector2i(11,7)
	w.player = Vector2(10.5,7.5)
	w.facing = Vector2.RIGHT
	for i in range(4):
		w.set_held("used_tire")
		w.place_or_move()
	check(site.cells.has(pile) and site.cells[pile].count==4 and not site.clear_at(site.center(pile)),
		"Quatre pneus usagés doivent pouvoir former une pile au sol dans l’atelier")
	if not site.cells.has(pile): return
	w.set_held("used_tire")
	w.place_or_move()
	check(w.held=="used_tire" and site.cells[pile].count==4,"Une pile de quatre ne doit pas accepter un cinquième pneu")
	w.set_held("")
	use(w,site.center(pile),"floor_pick")
	check(w.held=="used_tire" and site.cells[pile].count==3,"La reprise à la main doit prendre un seul pneu usagé")
	w.player = Vector2(10.5,7.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	w.set_held("new_tire")
	w.place_or_move()
	check(w.held=="new_tire" and site.cells[pile].item=="used_tire","Un pneu neuf ne doit pas rejoindre une pile usagée")
	var new_pile := Vector2i(11,8)
	w.player = Vector2(10.5,8.5)
	w.place_or_move()
	check(site.cells.has(new_pile) and not w.can_drop(new_pile,"used_tire"),"Un pneu usagé ne doit pas rejoindre une pile neuve")
	use(w,site.center(site.cart_cell),"cart")
	use(w,site.center(pile),"cart_stack")
	check(w.cart_kind=="used_tire" and w.cart_count==4 and not site.cells.has(pile),
		"Le chariot doit pouvoir reprendre quatre pneus empilés dans l’atelier")
	w.player = Vector2(10.5,8.5)
	w.facing = Vector2.RIGHT
	w.empty_cart()
	check(w.cart_count==4 and site.cells.has(new_pile) and site.cells[new_pile].count==1,
		"Le chariot ne doit pas vider les pneus usagés sur du neuf")
	w.player = Vector2(9.5,9.5)
	w.place_or_move()
	check(not w.pulling_cart and not w.holds_used_tires() and w.cart_count==4,
		"Un chariot chargé doit pouvoir être garé pour poursuivre une autre action")
	check(aim(w,site.center(site.cart_cell),"cart"),"Le chariot chargé doit être accessible")
	w.rotate_or_unload()
	check(w.cart_count==4 and site.cells.get(site.cart_cell,{}).get("kind")=="cart"
		and is_equal_approx(site.parked_cart.rotation.y,-PI/2),"Le chariot garé doit pivoter sur place sans vider sa charge")
	w.place_or_move()
	check(w.held=="used_tire" and w.cart_count==3 and not w.pulling_cart,"Y doit reprendre un seul pneu du chariot à l’arrêt")
	w.set_held("")
	use(w,site.center(site.cart_cell),"cart")
	w.player = Vector2(10.5,6.5)
	w.facing = Vector2.RIGHT
	w.empty_cart()
	var unloaded := Vector2i(11,6)
	check(w.cart_count==0 and site.cells.has(unloaded) and site.cells[unloaded].count==3,
		"Le chariot doit pouvoir déposer temporairement sa pile dans l’atelier")

func check_day_setup(w) -> void:
	w.build(0)
	var site = w.site
	var rack: Vector2 = site.station_point("rack")
	for id in ["fresh_oil","new_battery","coolant"]:
		var point: Vector2 = site.station_point(id)
		use(w,point,"stock")
		check(w.held==id,"La réserve ne fournit pas "+id)
		if id=="new_battery":
			check(aim(w,point,"return_supply"),"La batterie neuve ne retourne pas en réserve")
			w.place_or_move()
		else: use(w,point,"return_supply",0.0)
		check(w.held=="","La réserve ne reprend pas "+id)
	use(w,rack,"rack_hand")
	use(w,rack,"return_supply",0.0)
	check(w.held=="","Le rack ne reprend pas un pneu neuf")
	use(w,site.center(site.cart_cell),"cart")
	use(w,rack,"rack_cart")
	check(aim(w,rack,"return_cart_stock"),"Le rack ne reprend pas un chariot chargé")
	w.empty_cart()
	check(w.pulling_cart and w.cart_count==0,"Le retour au rack ne vide pas le chariot")
	use(w,rack,"rack_cart")
	w.player = Vector2(9.5,13.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	var initial_cart: Vector2i = site.cart_cell
	check(not w.pulling_cart and initial_cart==Vector2i(10,13),"Chariot de départ mal garé")

	check(aim(w,site.station_point("counter_0"),"none"),"Comptoir initial inaccessible")
	w.place_or_move()
	w.player = Vector2(8.5,5.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	var counter_tile: Vector2i = site.stations.counter_0.tile
	var counter: Vector2 = site.station_point("counter_0")
	use(w,site.station_point("tool_pressure"),"surface")
	use(w,counter,"surface",0.0)
	w.set_held("new_tire")
	w.player = Vector2(8.5,7.5)
	w.facing = Vector2.RIGHT
	var initial_floor: Vector2i = w.drop_cell()
	w.place_or_move()
	check(site.cells.has(initial_floor),"Objet au sol de départ absent")

	use(w,site.station_point("office_chair"),"sit",0.0)
	w.sync_player(0.35,0.0)
	check(w.office_seated and w.game.player_visual.last_pose=="chair","La chaise de bureau ne déclenche pas la pose assise")
	use(w,site.station_point("phone"),"start")
	check(w.run.mode=="day","Le téléphone ne fonctionne pas depuis la chaise")
	w.office_seated = false
	use(w,counter,"surface")
	use(w,site.station_point("counter_2"),"surface",0.0)
	w.set_held("used_tire")
	w.player = Vector2(10.5,8.5)
	w.facing = Vector2.RIGHT
	var service_floor: Vector2i = w.drop_cell()
	w.place_or_move()
	check(site.cells.has(service_floor),"Pneu utilisé absent du sol")
	use(w,site.center(initial_floor),"floor_pick")
	use(w,site.station_point("counter_1"),"surface",0.0)
	use(w,site.center(initial_cart),"cart")
	check(aim(w,rack,"return_cart_stock"),"Retour des pneus pendant le service impossible")
	w.empty_cart()
	w.player = Vector2(10.5,9.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	var service_cart: Vector2i = site.cart_cell
	check(service_cart!=initial_cart,"Le chariot n’a pas été déplacé pendant le service")
	w.set_held("used_tire")
	w.player = Vector2(site.used_tire_zone.position.x-0.5,18.5)
	w.facing = Vector2.RIGHT
	var used_pile: Vector2i = w.drop_cell()
	w.place_or_move()
	check(site.cells.has(used_pile),"La zone de droite ne reçoit pas un pneu à la main")
	use(w,site.station_point("new_battery"),"stock")
	w.player = site.center(initial_floor)
	w.run.cash = 75
	w.run.mode = "closing"
	w.tick(0.0)
	check(w.run.mode=="open" and w.menu.kind=="summary" and w.run.cash==75,"Bilan ou caisse modifié par le rangement")
	check(site.stations.counter_0.tile==counter_tile and site.stations.counter_0.get("top",{}).get("item")=="pressure",
		"L’outil ne revient pas sur le comptoir préparé")
	check(not site.stations.counter_1.has("top") and not site.stations.counter_2.has("top") and not site.cells.has(service_floor),
		"Des objets du service restent dans l’atelier")
	check(site.cells.get(initial_floor,{}).get("item")=="new_tire" and not site.cells.has(used_pile),
		"Les piles de départ ou les pneus usagés ne sont pas restaurés correctement")
	check(site.cart_cell==initial_cart and w.cart_count==4 and not site.cells.has(service_cart),
		"Le chariot ou sa charge de départ ne revient pas")
	check(w.held=="" and site.clear_at(w.player) and w.player!=site.center(initial_floor),
		"Le rangement laisse un objet en main ou coince le joueur")
	w.menu.hide()

func check_vendor_upgrades(w) -> void:
	w.build(2)
	var site = w.site
	use(w,site.station_point("phone"),"start")
	w.run.cash = 49
	w.purchase_vendor_offer(2)
	check(w.run.purchases.is_empty() and w.run.cash==49,"La fourgonnette ne doit pas vendre pendant le service")
	w.run.mode = "closing"
	w.tick(0.0)
	check(w.run.mode=="open" and site.van.visible,"La fourgonnette doit apparaître après le bilan")
	var catalog: Array = w.Catalog.VENDOR_OFFERS
	w.run.vendor_offers.assign([catalog[2],catalog[0],catalog[1]])
	w.menu_chosen(0)
	use(w,site.vendor_at-Vector2(0,0.65),"vendor",0.0)
	check(w.menu.visible and w.menu.kind=="vendor" and w.menu.options.size()==3,"Les trois offres doivent être accessibles depuis la fourgonnette")
	w.menu_chosen(0)
	check(w.run.cash==49 and not w.run.purchases.has("compressor") and w.menu.subtitle.text.contains("Il manque 1 $"),
		"Un achat sans fonds ne doit ni débiter ni installer l’amélioration")
	w.run.cash = 185
	var blocked: Array[Vector2i] = []
	var office: Rect2i = site.office_tiles()
	for z in range(office.position.y,office.end.y):
		for x in range(office.position.x,office.end.x):
			var tile := Vector2i(x,z)
			if site.cells.has(tile): continue
			site.cells[tile] = {"kind":"preview"}
			blocked.append(tile)
	w.menu_chosen(2)
	check(w.run.cash==185 and not w.run.purchases.has("counter") and not site.stations.has("counter_vendor_0"),
		"Un bureau sans place ne doit pas débiter l’achat de la desserte")
	for tile in blocked: site.cells.erase(tile)
	w.menu_chosen(1)
	w.menu_chosen(1)
	check(w.run.cash==125 and is_equal_approx(site.lift_speed,w.Map.LIFT_SPEED*1.6),
		"Le pont rapide doit être installé une seule fois")
	w.menu_chosen(2)
	w.menu_chosen(0)
	check(w.run.cash==0 and w.header.text.contains("0 $") and w.run.purchases.size()==3
		and site.stations.has("counter_vendor_0") and site.stations.has("counter_vendor_1"),
		"Les trois achats doivent débiter leur prix et installer les deux surfaces")
	if not site.stations.has("counter_vendor_1"): return
	check(office.has_point(site.stations.counter_vendor_0.tile) and office.has_point(site.stations.counter_vendor_1.tile),
		"Les deux parties de la desserte doivent être livrées au bureau")
	w.menu_dismissed()
	var surface: Vector2 = site.station_point("counter_vendor_1")
	use(w,site.station_point("tool_inspection"),"surface")
	use(w,surface,"surface",0.0)
	check(site.stations.counter_vendor_1.top.item=="inspection" and not site.stations.counter_vendor_0.has("top"),
		"Les deux surfaces de la desserte doivent fonctionner indépendamment")
	use(w,site.station_point("phone"),"start")
	check(w.run.day==2 and not site.van.visible and w.run.purchases.size()==3
		and w.day_setup.surfaces.has("counter_vendor_1"),"Les achats et le rangement doivent être conservés au jour suivant")
	var order: Dictionary = w.run.new_order()
	order.required.assign(["pressure"])
	w.run.waiting.append(order)
	if not receive_customer(w,order): return
	var bay: Dictionary = site.bays[0]
	dock_incoming(w,bay)
	use(w,site.station_point("tool_pressure"),"surface")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.pressure,"pressure",0.85)
	check(w.order_ready(order),"Le compresseur doit réduire le temps réel du réglage de pression")
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(0.7,{})
	check(is_equal_approx(bay.lift_height,w.Map.LIFT_TRAVEL) and is_zero_approx(site.bays[1].lift_height),
		"Le pont acheté doit monter plus vite et rester indépendant des autres")
	w.build(0)
	check(w.run.purchases.is_empty() and is_equal_approx(w.site.lift_speed,w.Map.LIFT_SPEED)
		and not w.site.stations.has("counter_vendor_0"),"Une nouvelle partie doit repartir sans les achats précédents")

func check_waiting_room_purchases(w) -> void:
	w.build(0)
	var site = w.site
	w.run.day = 1
	w.run.cash = 105
	site.van.show()
	w.run.vendor_day = 1
	for offer in w.Catalog.VENDOR_OFFERS:
		if offer.id in ["vending","magazines"]: w.run.vendor_offers.append(offer)
	for index in range(2): w.purchase_vendor_offer(index)
	check(w.run.cash==0 and site.stations.has("vending") and site.stations.has("magazines"),"Les deux améliorations doivent pouvoir être achetées")
	if not site.stations.has("vending") or not site.stations.has("magazines"): return
	w.menu_dismissed()
	var placements := {"vending":Vector2i(5,6),"magazines":Vector2i(1,9)}
	for id in placements:
		check(site.office_tiles().has_point(site.stations[id].tile) and not site.amenity_active(id),
			"L’achat doit être livré au bureau et attendre d’être placé en salle d’attente")
		check(aim(w,site.station_point(id),"none"),"L’achat doit pouvoir être visé au bureau")
		w.place_or_move()
		w.player = site.center(placements[id])+Vector2.RIGHT
		w.facing = Vector2.LEFT
		w.place_or_move()
		check(site.amenity_active(id),"L’achat doit s’activer après son déplacement en salle d’attente")
	use(w,site.station_point("phone"),"start")
	w.run.scheduled = w.Day.QUOTAS[w.run.day-1]
	var order: Dictionary = w.run.new_order()
	order.required.assign(["pressure"])
	w.run.waiting.append(order)
	if not receive_customer(w,order): return
	dock_incoming(w,site.bays[0])
	var saw_reading := false
	for frame in range(150):
		w.refresh_visitors(0.05)
		if w.visitors[order.id].meter.text.contains("Lit un magazine"):
			saw_reading = true
			break
	check(saw_reading and order.in_waiting_room and order.snacks_used==0,
		"Le client doit aller chercher un magazine et le lire sans se servir tant que sa patience est haute")
	var patience: float = order.patience
	w.tick(1.0)
	check(is_equal_approx(order.patience,patience-0.63*0.95*0.95),
		"Les deux améliorations doivent ralentir la patience en salle d’attente")
	var outside: Dictionary = w.run.new_order()
	outside.in_waiting_room = false
	patience = outside.patience
	var outside_orders: Array[Dictionary] = [outside]
	w.run.tick(1.0,outside_orders,true,0.95*0.95)
	check(is_equal_approx(outside.patience,patience-0.63),"Le bonus d’attente ne doit pas s’appliquer à l’extérieur")
	# Le supplément de la distributrice doit s’appliquer même à un client qui n’a rien pris.
	var bay: Dictionary = site.bays[0]
	bay.order.done.assign(["pressure"])
	settle_at_checkout(w,order.id)
	check(order.paid and order.snacks_used==0 and w.run.cash==26 and w.visitors[order.id].receipt.visible
		and not w.visitors[order.id].meter.visible and w.visitors[order.id].receipt.text=="+26 $" and not w.notice.contains("+26 $"),
		"Le paiement doit inclure le supplément et afficher le reçu uniquement au-dessus du client")
	w.refresh_visitors(2.3)
	check(not w.visitors[order.id].receipt.visible,"Le reçu doit disparaître après quelques secondes")

	# Un client encore en attente peut prendre au plus quatre collations.
	var waiting: Dictionary = w.run.new_order()
	w.waiting_for_bay.append(waiting)
	for frame in range(100): w.refresh_visitors(0.05)
	waiting.patience = waiting.max_patience/5.0-0.1
	for visit in range(4):
		for frame in range(160):
			w.refresh_visitors(0.05)
			if waiting.snacks_used>visit: break
		check(waiting.snacks_used==visit+1 and is_equal_approx(waiting.snack_pause,10.0),
			"Il doit se servir automatiquement avec une seule barre de patience")
		patience = waiting.patience
		w.run.lose_patience(waiting,9.9)
		check(is_equal_approx(waiting.patience,patience),"La collation doit suspendre la patience pendant dix secondes")
		w.run.lose_patience(waiting,0.11)
		check(waiting.patience<patience,"La patience doit reprendre après la pause")
	for frame in range(160): w.refresh_visitors(0.05)
	check(waiting.snacks_used==4 and is_zero_approx(waiting.snack_pause),"Le même client ne doit pas prendre de cinquième collation")

func check_arrival_cutoff(w) -> void:
	w.build(0)
	use(w,w.site.station_point("phone"),"start")
	w.run.elapsed = w.Day.LENGTH-0.15
	w.run.scheduled = w.Day.QUOTAS[0]
	var present: Dictionary = w.run.new_order()
	w.run.waiting.append(present)
	w.queue_incoming_car()
	var not_arrived: Dictionary = w.run.new_order()
	w.run.waiting.append(not_arrived)
	w.tick(0.2)
	check(w.run.mode=="closing" and w.run.clock_label()=="17 h 00" and w.run.waiting==[present]
		and w.incoming.has(present.id) and not w.incoming.has(not_arrived.id),
		"Seuls les clients dont l’arrivée est déjà visible doivent poursuivre après 17 h")
	check(receive_customer(w,present),"Il doit rester possible d’accueillir un client présent après 17 h")
	w.tick(1.0)
	check(w.run.mode=="closing" and w.header.text.contains("17 h 00") and not w.run.call_customer(),
		"L’horloge doit rester figée avec des clients à servir")

func check_vendor_draw() -> void:
	var progress = preload("res://workshop_day.gd").new()
	progress.vendor_random.seed = 42
	var previous: Array[String] = []
	var catalogs_seen := {}
	for day in range(1,10):
		progress.day = day
		progress.mode = "closing"
		var active: Array[Dictionary] = []
		progress.tick(0.0,active)
		var offers: Array[Dictionary] = progress.nightly_offers().duplicate()
		var ids: Array[String] = []
		for offer in offers:
			check(not ids.has(offer.id) and not progress.purchases.has(offer.id),
				"Le catalogue du soir doit proposer des offres distinctes encore disponibles")
			check(day>=int(offer.get("unlock_day",0)),"Une offre rare est apparue avant son déblocage")
			ids.append(offer.id)
		ids.sort()
		check(ids.size()==3 and ids!=previous,"Le tirage doit proposer trois offres et changer d’un soir à l’autre")
		previous = ids
		catalogs_seen[" ".join(ids)] = true
		for offer in offers:
			progress.vendor_purchase_record(offer)[offer.id] = true
		check(progress.nightly_offers()==offers,"Acheter ou rouvrir la fourgonnette ne doit pas relancer le tirage")
		var planned: Dictionary = progress.next_day_services.duplicate()
		progress.start()
		check(progress.next_day_services.is_empty() and progress.active_services==planned,
			"Seuls les préparatifs achetés la veille doivent être actifs")
		progress.appointments.clear()
	check(catalogs_seen.size()>1,"Une partie doit rencontrer plusieurs catalogues")
	var first_catalogs := {}
	for seed_value in [1,2,3,4]:
		var fresh = preload("res://workshop_day.gd").new()
		fresh.vendor_random.seed = seed_value
		var ids: Array[String] = []
		for offer in fresh.nightly_offers(): ids.append(offer.id)
		ids.sort()
		first_catalogs[" ".join(ids)] = true
	check(first_catalogs.size()>1,"Des parties différentes doivent pouvoir recevoir des catalogues différents")

func check_vendor_reroll(w) -> void:
	w.build(0)
	w.run.vendor_random.seed = 43
	w.run.day = 1
	w.site.van.show()
	var cost: int = w.Day.VENDOR_REROLL_COST
	w.run.cash = cost-1
	w.show_vendor()
	var original: Array[Dictionary] = w.run.nightly_offers().duplicate()
	check(w.menu.reroll_button.disabled,"La relance doit être désactivée si la caisse est insuffisante")
	w.reroll_vendor_offers()
	check(w.run.cash==cost-1 and w.run.nightly_offers()==original and w.run.vendor_reroll_day!=w.run.day,
		"Une relance sans fonds ne doit pas consommer la relance du soir")
	w.run.cash = cost*2
	w.show_vendor()
	w.menu.reroll_button.pressed.emit()
	var replacement: Array[Dictionary] = w.run.nightly_offers().duplicate()
	check(w.run.cash==cost and w.header.text.contains("%d $"%cost) and w.menu.options.size()==3
		and replacement.size()==3 and replacement.all(func(offer: Dictionary) -> bool: return offer not in original),
		"La relance doit débiter une fois et remplacer les trois offres si le stock le permet")
	w.menu_dismissed()
	w.show_vendor()
	w.reroll_vendor_offers()
	check(w.run.cash==cost and w.run.nightly_offers()==replacement and w.menu.reroll_button.disabled,
		"Rouvrir le catalogue doit conserver les nouvelles offres et la limite du soir")
	w.menu_dismissed()
	w.run.start()
	check(not w.run.reroll_vendor() and w.run.cash==cost,"Le service de jour doit interdire la relance")
	w.run.mode = "closing"
	w.tick(0.0)
	w.show_vendor()
	check(not w.menu.reroll_button.disabled,"Le lendemain soir doit donner droit à une nouvelle relance")
	w.game.set_physics_process(true)
	Input.action_press("rotate_item")
	await physics_frame
	await physics_frame
	Input.action_release("rotate_item")
	w.game.set_physics_process(false)
	check(w.run.cash==0 and w.run.vendor_reroll_day==w.run.day,"Le raccourci doit relancer le catalogue")
	w.menu_dismissed()

	var progress = w.Day.new()
	progress.day = 2
	progress.cash = cost*2
	for offer in w.Catalog.VENDOR_OFFERS:
		if not offer.get("temporary",false): progress.purchases[offer.id] = true
	var low_stock: Array[Dictionary] = progress.nightly_offers().duplicate()
	check(progress.reroll_vendor() and progress.vendor_offers.size()==3
		and not progress.vendor_offers.all(func(offer: Dictionary) -> bool: return offer in low_stock),
		"Une relance en stock réduit doit remplacer autant de cartes que possible")
	progress.day = 3
	var final_stock: Array[Dictionary] = progress.nightly_offers().duplicate()
	for offer in w.Catalog.VENDOR_OFFERS:
		if offer.get("temporary",false) and offer not in final_stock:
			progress.next_day_services[offer.id] = true
	check(not progress.reroll_vendor() and progress.cash==cost and progress.vendor_offers==final_stock,
		"Une relance sans nouvelle offre possible doit laisser la caisse et le catalogue intacts")

func check_rare_vendor_offers(w) -> void:
	for seed_value in [2,17,43,88]:
		var progress = w.Day.new()
		progress.vendor_random.seed = seed_value
		var nights_without_rare := 0
		for night in range(1,10):
			progress.day = night
			var offers: Array[Dictionary] = progress.nightly_offers()
			var rare := offers.filter(func(offer: Dictionary) -> bool: return offer.has("unlock_day"))
			check(rare.size()<=1 and (night>=3 or rare.is_empty()),"Le catalogue doit proposer au plus une offre rare")
			if night<3: continue
			nights_without_rare = nights_without_rare+1 if rare.is_empty() else 0
			check(nights_without_rare<3,"Trois soirs admissibles se sont écoulés sans offre rare")
			check(progress.nightly_offers()==offers,"Rouvrir la boutique ne doit pas changer l’offre rare")
	w.build(0)
	var site = w.site
	w.run.day = 1
	w.run.cash = 134
	site.van.show()
	w.show_vendor()
	check(w.menu.details_label.text.contains("Soir 3 · Bac récupérateur · 135 $")
		and w.menu.details_label.text.contains("Soir 5 · Garantie d’accueil · 180 $")
		and w.menu.details_label.text.contains("Soir 7 · Atelier express · 240 $"),
		"La fourgonnette doit afficher les soirs et les prix des futures offres rares")
	var catalog: Array = w.Catalog.VENDOR_OFFERS
	for i in range(3):
		var offer: Dictionary = catalog[11+i]
		w.run.day = offer.unlock_day
		w.run.vendor_day = w.run.day
		w.run.vendor_offers.assign([catalog[0],offer,catalog[1]])
		w.show_vendor()
		check(w.menu.options[1][6],"L’offre rare doit être signalée sur sa carte")
		if i==0:
			w.menu_chosen(1)
			check(w.run.cash==134 and w.run.purchases.is_empty()
				and w.menu.subtitle.text.contains("Il manque 1 $"),"Un achat rare doit vérifier la caisse")
			w.run.cash = 555
		var balance: int = w.run.cash
		w.menu_chosen(1)
		check(w.run.cash==balance-offer.price and w.run.purchases.has(offer.id),
			"L’offre rare doit être payée et active pour la partie")
	check(not w.menu.details_label.visible,"Les améliorations déjà installées doivent quitter l’aperçu des offres rares")
	w.menu_dismissed()
	use(w,site.station_point("phone"),"start")
	var order: Dictionary = w.run.new_order()
	order.required.assign(["oil"])
	w.run.waiting.append(order)
	if not receive_customer(w,order): return
	var bay: Dictionary = site.bays[0]
	dock_incoming(w,bay)
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	use(w,site.station_point("tool_oil"),"surface")
	var drain_point: Vector2 = bay.at+w.Map.SERVICE_OFFSETS.oil
	use(w,drain_point,"drain",1.09)
	check(order.oil==2 and w.oil_pan_for<0 and w.next_vehicle_work(0).item=="fresh_oil",
		"L’atelier express doit accélérer la vidange et le bac doit passer directement à l’huile neuve")
	use(w,site.station_point("counter_0"),"surface",0.0)
	use(w,site.station_point("fresh_oil"),"stock")
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	use(w,drain_point,"fill_oil",0.88)
	use(w,site.station_point("trash"),"trash")
	check(w.order_ready(order),"Le parcours raccourci de vidange doit terminer le ticket")
	w.run.penalty()
	check(w.run.rating==9 and not w.run.guarantee_used,"Un refus doit conserver sa pénalité")
	order.patience = 0.5
	w.run.lose_patience(order,0.5)
	check(order.late and w.run.rating==9 and w.run.guarantee_used,
		"La première pénalité d’impatience doit être absorbée")
	w.run.lose_patience(order,w.Day.LATE_INTERVAL)
	check(w.run.rating==8,"La pénalité suivante doit retirer une demi-étoile")
	w.run.mode = "open"
	w.run.start()
	check(not w.run.guarantee_used,"La garantie doit se recharger au début de la journée suivante")

func check_additional_upgrades(w) -> void:
	w.build(0)
	var site = w.site
	var catalog: Array = w.Catalog.VENDOR_OFFERS
	w.run.day = 1
	w.run.cash = 400
	w.run.vendor_day = 1
	w.run.vendor_offers.assign([catalog[3],catalog[4],catalog[5]])
	site.van.show()
	w.show_vendor()
	for i in range(3): w.menu_chosen(i)
	check(w.run.cash==205 and w.run.purchases.has_all(["impact","light_cart","lounge"]),
		"Les nouvelles améliorations permanentes doivent être achetables")
	w.menu_dismissed()
	use(w,site.center(site.cart_cell),"cart")
	check(is_equal_approx(w.walking_speed(),4.9),"Le chariot léger doit conserver la vitesse de marche normale")
	w.player = Vector2(9.5,9.5)
	w.facing = Vector2.RIGHT
	w.place_or_move()
	use(w,site.station_point("phone"),"start")
	var order: Dictionary = w.run.new_order()
	order.required.assign(["tires"])
	w.run.waiting.append(order)
	var patience: float = order.patience
	w.run.tick(1.0,w.active_orders())
	check(is_equal_approx(order.patience,patience-0.75),"Le salon doit réduire la perte de patience")
	if not receive_customer(w,order): return
	var bay: Dictionary = site.bays[0]
	dock_incoming(w,bay)
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	use(w,site.station_point("tool_tires"),"surface")
	use(w,bay.at+w.Map.WHEEL_OFFSETS[0],"wheel",0.55)
	check(order.wheels[0]==1,"La clé à choc pro doit diviser par deux le temps réel de desserrage")

	w.build(0)
	site = w.site
	w.run.day = 1
	w.run.cash = 180
	w.run.vendor_day = 1
	w.run.vendor_offers.assign([catalog[6],catalog[7],catalog[8]])
	site.van.show()
	w.show_vendor()
	for i in range(3): w.menu_chosen(i)
	w.menu_chosen(2)
	check(w.run.cash==48 and w.run.active_services.is_empty() and w.run.next_day_services.has("advertising"),
		"Les préparatifs doivent être facturés une seule fois et attendre le prochain service")
	w.menu_dismissed()
	use(w,site.station_point("phone"),"start")
	use(w,site.station_point("phone"),"call")
	check(w.run.appointments.size()==2 and w.run.appointments[0].when==4.0 and w.run.appointments[1].when==32.0,
		"La publicité doit ajouter un client sans retarder les autres rendez-vous")
	w.run.tick(4.1,w.active_orders())
	var customer: Dictionary = w.run.waiting.front()
	customer.required.assign(["pressure"])
	if not receive_customer(w,customer): return
	bay = site.bays[0]
	dock_incoming(w,bay)
	use(w,site.station_point("tool_pressure"),"surface")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.pressure,"pressure")
	settle_at_checkout(w,customer.id)
	check(w.run.cash==81 and w.run.daily_cash==33,"Le contrat fidélité doit ajouter 8 $ à une vraie facture payée à temps")
	customer.late = true
	check(w.run.loyalty_bonus(customer)==0,"Un client qui a perdu patience ne doit pas donner de prime")

	w.build(0)
	site = w.site
	w.run.day = 1
	w.run.cash = 100
	w.run.vendor_day = 1
	w.run.vendor_offers.assign([catalog[7],catalog[9],catalog[10]])
	site.van.show()
	w.show_vendor()
	for i in range(3): w.menu_chosen(i)
	check(w.run.cash==47 and w.menu.options[1][3]=="Prévu demain" and is_equal_approx(site.lift_speed,w.Map.LIFT_SPEED),
		"Les réglages temporaires ne doivent prendre effet qu’au prochain service")
	w.menu_dismissed()
	use(w,site.station_point("phone"),"start")
	var inspection: Dictionary = w.run.new_order()
	inspection.required.assign(["inspection"])
	inspection.issue = ""
	w.run.waiting.append(inspection)
	var received := receive_customer(w,inspection,0.275)
	check(received,"Le renfort doit accueillir les clients en deux fois moins de temps")
	if not received: return
	bay = site.bays[0]
	dock_incoming(w,bay)
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(0.8,{})
	check(is_equal_approx(bay.lift_height,w.Map.LIFT_TRAVEL),"Le réglage de la veille doit accélérer le pont")
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(0.8,{})
	use(w,site.station_point("tool_inspection"),"surface")
	use(w,bay.at+w.Map.SERVICE_OFFSETS.inspection,"inspection",1.0)
	check(w.order_ready(inspection),"La valise louée doit accélérer le diagnostic pendant ce service")

func repair_ticket(w,jobs: Array) -> Dictionary:
	w.build(0)
	use(w,w.site.station_point("phone"),"start")
	var order: Dictionary = w.run.new_order()
	order.required.assign(jobs)
	order.issue = ""
	w.run.waiting.append(order)
	if not receive_customer(w,order): return {}
	var bay: Dictionary = w.site.bays[0]
	dock_incoming(w,bay)
	for frame in range(55): w.refresh_visitors(0.1)
	return bay

func check_battery_guide(w) -> void:
	var bay := repair_ticket(w,["battery"])
	if bay.is_empty(): return
	var site = w.site
	var order: Dictionary = bay.order
	var hood_point: Vector2 = bay.at+w.Map.SERVICE_OFFSETS.battery
	for level in range(3):
		w.zoom = level
		w.update_camera(1.0)
		check(w.game.camera.rotation_degrees.distance_to(Vector3(-63,0,0))<0.1,
			"La caméra du garage doit garder la vue inclinée dans l’axe des baies à chaque zoom")
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	w.update_hud()
	var marker: Label3D = bay.work_markers[0]
	check(marker.visible and marker.text.contains("Baisser le pont")
		and is_equal_approx(marker.position.x,bay.lever_at.x),"Le repère doit indiquer quel pont baisser")
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	use(w,site.station_point("tool_inspection"),"surface")
	check(aim(w,hood_point,"none") and w.context().get("label","").contains("Libère tes mains"),
		"Le joueur doit savoir qu’il faut poser son outil avant d’ouvrir le capot")
	use(w,site.station_point("tool_inspection"),"surface",0.0)
	w.player = bay.at+Vector2(0,-2.88)
	w.facing = Vector2.RIGHT
	w.update_hud()
	check(site.clear_at(w.player) and w.context().get("id")=="remove_battery"
		and marker.visible and marker.text.contains("A / F · Capot")
		and marker.modulate==w.Map.PLACEMENT_READY_COLOR
		and w.footer.text.contains("Ouvrir le capot et retirer la batterie"),
		"La batterie doit être accessible au centre devant le capot et le repère doit passer au vert")
	w.advance_action(0.48,true,true)
	site.animate_bays(0.48,w.action)
	check(bay.hood.rotation.x<-0.9 and order.battery==0,"Le maintien d’A doit ouvrir le capot avant le retrait")
	w.advance_action(0.8,false,true)
	w.update_hud()
	var trash_point: Vector2 = site.station_point("trash")
	check(w.held=="old_battery" and marker.text.contains("Poubelle")
		and Vector2(marker.position.x,marker.position.z)==trash_point,
		"Après le retrait, le repère doit indiquer où déposer la batterie usée")
	use(w,trash_point,"trash")
	w.update_hud()
	var stock_point: Vector2 = site.station_point("new_battery")
	check(marker.text.contains("Batterie neuve") and Vector2(marker.position.x,marker.position.z)==stock_point,
		"La réserve de batteries doit être repérée avant l’installation")
	use(w,stock_point,"stock")
	use(w,hood_point,"install_battery")
	w.update_hud()
	check(w.order_ready(order) and not marker.visible,"Le repère doit disparaître après l’installation")

func visible_repair_markers(bay: Dictionary) -> Dictionary:
	var labels := {}
	for marker: Label3D in bay.work_markers:
		if marker.visible: labels[Vector2(marker.position.x,marker.position.z)] = marker.text
	return labels

func check_available_repair_markers(w) -> void:
	var bay := repair_ticket(w,["battery","lights","wipers"])
	if bay.is_empty(): return
	var site = w.site
	var order: Dictionary = bay.order
	var hood: Vector2 = bay.at+w.Map.SERVICE_OFFSETS.battery
	var lights: Vector2 = bay.at+w.Catalog.LIGHT_SWITCH
	var wipers: Vector2 = bay.at+w.Catalog.WIPER_SWITCH
	take_part(w,"parts_electric","wiper_pair")
	use(w,bay.at+w.Catalog.PANEL_OFFSETS.wipers,"wipers_fit")
	w.player = site.desk_side
	w.update_hud()
	var markers := visible_repair_markers(bay)
	check(markers.size()==3 and markers.has(hood) and markers.has(lights) and markers.has(wipers)
		and w.ticket.text.contains("Suggestion"),
		"Toutes les actions prêtes doivent être repérées même quand le joueur est loin de la voiture")
	use(w,wipers,"wipers_test",0.3)
	w.update_hud()
	markers = visible_repair_markers(bay)
	check(not markers.has(wipers) and markers.has(hood) and markers.has(lights),
		"La progression d’une action doit laisser les autres choix visibles")
	w.advance_action(0.5,false,true)
	check("wipers" in order.done and order.battery==0 and w.Repairs.stage(order,"lights")==0,
		"Les essuie-glaces doivent pouvoir être testés avant les autres réparations du ticket")
	use(w,lights,"lights_test")
	w.update_hud()
	markers = visible_repair_markers(bay)
	check(markers.size()==1 and markers.has(hood),
		"Le repère des feux doit attendre la bonne ampoule")
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	w.update_hud()
	markers = visible_repair_markers(bay)
	check(markers.size()==1 and markers.has(bay.lever_at),
		"Le repère de préparation doit revenir si toutes les réparations sont bloquées par le pont")

	bay = repair_ticket(w,["tires"])
	if bay.is_empty(): return
	site = w.site
	use(w,bay.lever_at,"lift",0.0)
	site.animate_bays(1.0,{})
	var tool: Vector2 = site.station_point("tool_tires")
	use(w,tool,"surface")
	w.update_hud()
	check(visible_repair_markers(bay).size()==4,"Les quatre roues à desserrer doivent être repérées")
	var wheel: Vector2 = bay.at+w.Map.WHEEL_OFFSETS[3]
	use(w,wheel,"wheel")
	w.update_hud()
	check(visible_repair_markers(bay).size()==3 and not visible_repair_markers(bay).has(wheel),
		"Une roue desserrée ne doit plus être proposée tant que la clé à choc est en main")
	use(w,tool,"surface",0.0)
	w.update_hud()
	markers = visible_repair_markers(bay)
	check(markers.size()==1 and markers.has(wheel),"Mains libres, seule la roue desserrée peut être déposée")

func check_chassis_repairs(w) -> void:
	var bay := repair_ticket(w,["muffler","damper","shield","bearing"])
	if bay.is_empty(): return
	var s = w.site
	var order: Dictionary = bay.order
	order.faults.bearing = 2
	order.faults.damper = 1
	order.faults.broken_panel = false
	var muffler: Vector2 = bay.at+w.Catalog.PANEL_OFFSETS.muffler
	var shield: Vector2 = bay.at+w.Catalog.PANEL_OFFSETS.shield
	var wheel: Vector2 = bay.at+w.Map.WHEEL_OFFSETS[2]
	use(w,s.station_point("tool_ratchet"),"surface")
	use(w,muffler,"none")
	check(w.Repairs.stage(order,"muffler")==0,"Silencieux détachable au sol")
	use(w,bay.lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	use(w,muffler,"muffler_unbolt")
	use(w,s.station_point("tool_ratchet"),"surface",0.0)
	use(w,muffler,"muffler_take")
	check(w.held=="old_muffler" and w.held_origin==order.id,"Silencieux usé absent")
	use(w,s.station_point("scrap"),"recycle_muffler")
	take_part(w,"parts_chassis","new_muffler")
	use(w,muffler,"muffler_fit")
	use(w,s.station_point("tool_probe"),"surface")
	use(w,bay.at+Vector2(-1.46,0.44),"damper_test")
	check(w.Repairs.stage(order,"damper")==0,"Le contrôle prend le côté sain pour la panne")
	use(w,bay.at+Vector2(1.46,0.44),"damper_test")
	use(w,s.station_point("tool_probe"),"surface",0.0)
	take_part(w,"parts_chassis","damper_part")
	use(w,bay.at+Vector2(1.46,0.44),"damper_fit")
	use(w,s.station_point("tool_ratchet"),"surface")
	use(w,shield,"shield_test")
	use(w,shield,"shield_tighten")
	use(w,s.station_point("tool_ratchet"),"surface",0.0)
	use(w,s.station_point("tool_probe"),"surface")
	use(w,bay.at+w.Map.WHEEL_OFFSETS[0],"bearing_test")
	check(w.Repairs.stage(order,"bearing")==0,"Mauvais roulement détecté")
	use(w,wheel,"bearing_test")
	check(s.bearing_audio.stream==s.bearing_clips[1] and w.Repairs.stage(order,"bearing")==1,
		"Le test du roulement bruyant ne joue pas le grincement")
	use(w,s.station_point("tool_probe"),"surface",0.0)
	loosen_and_remove(w,wheel)
	check(not bay.tires[2].visible and bay.discs[2].visible and bay.stored_wheels.has(2),
		"Le disque doit apparaître et la roue d’origine rester disponible")
	use(w,s.station_point("tool_puller"),"surface")
	use(w,wheel,"bearing_extract")
	use(w,s.station_point("tool_puller"),"surface",0.0)
	take_part(w,"parts_chassis","bearing_part")
	use(w,wheel,"bearing_fit")
	use(w,wheel,"wheel")
	finish_wheel(w,wheel)
	check(w.order_ready(order) and order.done.size()==4 and bay.tires[2].visible
		and not bay.stored_wheels.has(2),"Les travaux de châssis ne terminent pas la commande")

func loosen_and_remove(w, wheel: Vector2) -> void:
	var tool: Vector2 = w.site.station_point("tool_tires")
	use(w,tool,"surface")
	use(w,wheel,"wheel")
	use(w,tool,"surface",0.0)
	use(w,wheel,"wheel")

func finish_wheel(w, wheel: Vector2) -> void:
	var tool: Vector2 = w.site.station_point("tool_tires")
	use(w,tool,"surface")
	use(w,wheel,"wheel")
	use(w,tool,"surface",0.0)

func check_ground_repairs(w) -> void:
	var bay := repair_ticket(w,["puncture","lights","belt","wipers"])
	if bay.is_empty(): return
	var s = w.site
	var order: Dictionary = bay.order
	order.faults.puncture = 1
	order.faults.bad_puncture = false
	order.faults.rear_lamp = true
	var bench: Vector2 = s.station_point("bench")
	var wheel: Vector2 = bay.at+w.Map.WHEEL_OFFSETS[1]
	var controls: Vector2 = bay.at+w.Catalog.LIGHT_SWITCH
	use(w,bay.lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	loosen_and_remove(w,wheel)
	check(w.held=="repair_wheel" and w.held_origin==order.id,"La route de la roue crevée perd sa commande")
	check(w.next_vehicle_work(0).label=="Apporter la roue à l’établi","Le tableau ne suit pas la roue déposée")
	use(w,bench,"surface",0.0)
	check(w.next_vehicle_work(0).label=="Tester la roue à l’établi","L’étape du test de la roue est absente")
	use(w,bench,"puncture_test")
	check(w.next_vehicle_work(0).item=="patch" and w.next_vehicle_work(0).lift==1,
		"La rustine et le pont levé doivent figurer sur le tableau")
	take_part(w,"parts_chassis","patch")
	use(w,bench,"puncture_patch")
	check(w.next_vehicle_work(0).label=="Récupérer la roue réparée","Le tableau doit indiquer la roue prête à reprendre")
	use(w,bench,"surface")
	use(w,wheel,"wheel")
	finish_wheel(w,wheel)
	use(w,controls,"none")
	check(w.Repairs.stage(order,"lights")==0,"Le test des feux est accessible pont levé")
	use(w,bay.lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	use(w,controls,"lights_test")
	check(not bay.lights.rear[0].material_override.emission_enabled
		and bay.lights.rear[1].material_override.emission_enabled,"Le feu grillé ne se distingue pas")
	take_part(w,"parts_electric","lamp_rear")
	use(w,bay.at+w.Catalog.REAR_LAMP,"light_fit")
	use(w,controls,"lights_verify")
	check(bay.lights.rear[0].material_override.emission_enabled,"Le feu réparé ne s’allume pas")
	var belt: Vector2 = bay.at+w.Catalog.PANEL_OFFSETS.belt
	use(w,s.station_point("tool_ratchet"),"surface")
	use(w,belt,"belt_remove")
	use(w,s.station_point("tool_ratchet"),"surface",0.0)
	take_part(w,"parts_electric","belt_part")
	use(w,belt,"belt_fit")
	use(w,bay.at+w.Catalog.ENGINE_SWITCH,"belt_test")
	take_part(w,"parts_electric","wiper_pair")
	use(w,bay.at+w.Catalog.PANEL_OFFSETS.wipers,"wipers_fit")
	use(w,bay.at+w.Catalog.WIPER_SWITCH,"wipers_test")
	check(w.order_ready(order) and order.done.size()==4,"Crevaison, feux, courroie ou essuie-glaces incomplets")

func check_alternate_repairs(w) -> void:
	var bay := repair_ticket(w,["shield","window","puncture"])
	if bay.is_empty(): return
	var s = w.site
	var order: Dictionary = bay.order
	order.faults.broken_panel = true
	order.faults.module = true
	order.faults.bad_puncture = true
	order.faults.puncture = 3
	var window: Vector2 = bay.at+w.Catalog.PANEL_OFFSETS.window
	use(w,window,"window_test")
	check(w.Repairs.stage(order,"window")==2 and not w.order_ready(order),"Le module requiert un devis")
	check(w.next_vehicle_work(0).label=="Demander l’accord pour la vitre" and w.next_vehicle_work(0).lift==-1,
		"Le tableau doit indiquer l’accord du client avant de prendre le module")
	use(w,s.seats[0],"window_approve")
	check(w.next_vehicle_work(0).item=="window_module" and w.next_vehicle_work(0).lift==0,
		"Le tableau doit indiquer le module et le pont baissé une fois le devis approuvé")
	take_part(w,"parts_electric","window_module")
	use(w,window,"window_fit")
	use(w,window,"window_verify")
	var shield: Vector2 = bay.at+w.Catalog.PANEL_OFFSETS.shield
	use(w,bay.lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	use(w,s.station_point("tool_ratchet"),"surface")
	use(w,shield,"shield_test")
	use(w,s.station_point("tool_ratchet"),"surface",0.0)
	take_part(w,"parts_chassis","shield_part")
	use(w,shield,"shield_fit")
	var wheel: Vector2 = bay.at+w.Map.WHEEL_OFFSETS[3]
	var bench: Vector2 = s.station_point("bench")
	loosen_and_remove(w,wheel)
	use(w,bench,"surface",0.0)
	use(w,bench,"puncture_test")
	use(w,bench,"puncture_recycle")
	use(w,s.station_point("rack"),"rack_hand")
	use(w,wheel,"wheel")
	finish_wheel(w,wheel)
	check(w.order_ready(order) and order.done.size()==3,"Les variantes avec pièces neuves restent bloquées")
	use(w,bay.lever_at,"lift",0.0)
	s.animate_bays(1.0,{})
	use(w,w.driver_door(bay),"drive",0.0)
	park_north(w,bay)
	settle_at_checkout(w,order.id)
	check(w.run.cash==115,"Le module approuvé doit être ajouté au prix du devis")

func check_window_choices(w) -> void:
	var bay := repair_ticket(w,["window"])
	if bay.is_empty(): return
	var order: Dictionary = bay.order
	var target: Vector2 = bay.at+w.Catalog.PANEL_OFFSETS.window
	order.faults.module = false
	use(w,target,"window_test")
	use(w,w.site.station_point("tool_ratchet"),"surface")
	use(w,target,"window_rail")
	use(w,w.site.station_point("tool_ratchet"),"surface",0.0)
	use(w,target,"window_verify")
	check(w.order_ready(order),"Le déblocage du rail ne permet pas de terminer le ticket")
	order.done.clear()
	order.service.clear()
	order.faults.module = true
	use(w,target,"window_test")
	var rating: int = w.run.rating
	use(w,w.site.seats[0],"window_decline",0.65,true)
	check(w.run.rating==rating-1 and w.order_ready(order) and order.required.is_empty(),
		"Le refus du module ne doit ni bloquer ni facturer la vitre")

func take_part(w, shelf: String, part: String) -> void:
	use(w,w.site.station_point(shelf),"parts",0.0)
	check(w.menu.visible and w.menu.kind=="parts","Rayon indisponible · "+shelf)
	if not w.menu.visible or w.menu.kind!="parts": return
	w.menu_chosen(w.Catalog.SHELVES[shelf].find(part))
	check(w.held==part,"Le rayon ne remet pas "+part)

func can_aim(w, p: Vector2) -> bool:
	for radius in [0.83,1.28,1.76]:
		for i in range(16):
			var at: Vector2 = p+Vector2.RIGHT.rotated(i*TAU/16)*radius
			if w.site.clear_at(at) and w.site.can_see(at,p): return true
	return false

func aim(w,p: Vector2,id: String,decline := false) -> bool:
	for radius in [0.83,1.28,1.76]:
		for i in range(16):
			var at: Vector2 = p+Vector2.UP.rotated(i*TAU/16)*radius
			if not w.site.clear_at(at): continue
			w.player = at
			w.facing = at.direction_to(p)
			var selected: Dictionary = w.context(decline)
			if selected.get("id")==id and selected.get("at")==p: return true
	return false

func use(w,p: Vector2,id: String,dt := 2.1,decline := false) -> void:
	if not aim(w,p,id,decline):
		failures.append("Action indisponible · "+id+" @ "+str(p))
		return
	w.advance_action(dt,true,true,decline)

func check_clock() -> void:
	var day = preload("res://workshop_day.gd").new()
	day.random.seed = 512
	var counts := {}
	var jobs_seen := {}
	for i in range(10):
		check(day.start() and day.rating==10,"Réinitialisation des étoiles incorrecte")
		check(day.clock_label()=="07 h 00","L’horloge doit commencer à 7 h")
		for j in range(25):
			var job: Dictionary = day.new_order()
			counts[job.required.size()] = true
			for id in job.required:
				jobs_seen[id] = true
				check(day.day>=day.Catalog.UNLOCKS.get(id,1),"Réparation avancée tirée trop tôt")
			check(not ("tires" in job.required and "puncture" in job.required),"Deux demandes de pneus incompatibles")
			check(job.required.size()>=1 and job.required.size()<=4,"Nombre de réparations hors limites")
		for second in range(180):
			day.tick(1.0,[],true)
			day.waiting.clear()
		check(day.mode=="closing" and not day.call_customer(),"Appel permis après la fermeture")
		check(day.clock_label()=="17 h 00","L’horloge doit s’arrêter à 17 h")
		check(day.scheduled==day.QUOTAS[i],"Quota quotidien incorrect")
		day.tick(0,[],true)
		check(day.mode=="closing","La journée termine avant la sortie de la voiture")
		day.tick(0,[])
	check(day.mode=="won" and not day.start() and counts.size()==4,"Fin des dix jours ou variation incorrecte")
	check(jobs_seen.size()==day.Catalog.JOBS.size(),"Le planning ne propose pas toutes les réparations")
	var failed = preload("res://workshop_day.gd").new()
	failed.start()
	var order: Dictionary = failed.new_order()
	order.patience = 0.63
	failed.lose_patience(order,1.0,0.63)
	check(failed.rating==9,"La patience à zéro ne retire pas une demi-étoile")
	failed.lose_patience(order,9.9,0.63)
	check(failed.rating==9,"La pénalité se répète avant dix secondes réelles")
	failed.lose_patience(order,0.1,0.63)
	check(failed.rating==8,"La deuxième pénalité n’arrive pas après dix secondes")
	failed.lose_patience(order,20.1,0.63)
	check(failed.rating==6,"Les pénalités suivantes ne se cumulent pas par tranche de dix secondes")
	for i in range(6): failed.penalty()
	check(failed.mode=="lost" and not failed.start(),"Une partie perdue peut se poursuivre")


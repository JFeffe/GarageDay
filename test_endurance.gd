extends SceneTree

const Race := preload("res://endurance_race.gd")
const Crew := preload("res://endurance_crew.gd")
const GarageCamera := preload("res://garage_camera.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, description: String) -> void:
	if not condition: failures.append(description)

func make_race() -> Race:
	var race := Race.new()
	race.setup(2006)
	race.start()
	return race

func check_stops_and_repairs() -> void:
	var race := make_race()
	var first := race.cars[0]
	var second := race.cars[1]
	check(first.drivers.size()==2 and second.drivers.size()==2 and first.drivers!=second.drivers,
		"Chaque GT doit inscrire deux pilotes différents.")
	check(race.cars.size()==10 and race.cars[2].team!=Race.TEAM,"Le plateau doit inclure huit GT rivales.")
	race.advance(580.0)
	check(first.fuel<1.0 and second.tires<1.0 and first.distance>1.0,"Les relais doivent avancer et user les consommables.")
	first.damage = 0.62
	first.distance = 5.999
	second.distance = 5.999
	check(race.confirm_stop(0,{},false) and race.confirm_stop(1,{"fuel":Race.Mode.AUTO,"tires":Race.Mode.AUTO,"driver":Race.Mode.AUTO},false),
		"Les deux GT doivent pouvoir confirmer un arrêt.")
	race.advance(27.0)
	check(first.state==Race.State.BOX and second.state==Race.State.QUEUE,"Un deuxième arrêt doit attendre si le box est occupé.")
	check(race.confirm_stop(0,{"repair":Race.Mode.MANUAL},true) and second.state==Race.State.BOX,
		"Rentrer la première GT au garage doit libérer le box immédiatement.")
	check(race.manual_action(0,"repair"),"La réparation au garage doit pouvoir être commencée par le joueur.")
	race.advance(1.0)
	check(first.jobs.has("repair") and second.jobs.size()==3,"La réparation et les trois tâches du box doivent avancer en parallèle.")
	check(not race.perform(0,"exit") and not race.perform(1,"exit"),"Une GT ne doit pas partir pendant son intervention.")
	check(race.service_time(first,"repair",Race.Mode.MANUAL)+16.0<race.service_time(first,"repair",Race.Mode.AUTO),
		"Même avec la manipulation, la réparation manuelle doit prendre moins de temps.")
	check(race.service_time(second,"fuel",Race.Mode.MANUAL)+6.0<race.service_time(second,"fuel",Race.Mode.AUTO),
		"Le plein à la pompe doit être plus rapide que le plein automatique.")
	race.advance(61.0)
	check(second.fuel==1.0 and second.driver==1 and second.jobs.has("tires"),"Essence et relève doivent finir pendant les pneus.")
	race.advance(100.0)
	check(second.tires==1.0 and second.driver==1 and race.perform(1,"exit"),"Les trois tâches automatiques doivent se terminer une seule fois.")
	race.advance(20.0)
	check(second.state==Race.State.TRACK and second.planned>race.elapsed,"La deuxième GT doit reprendre son relais avec un prochain arrêt.")
	check(first.damage==0.0 and race.perform(0,"exit"),"Le garage doit permettre une réparation complète et la sortie.")
	race.advance(20.0)
	check(first.state==Race.State.TRACK,"La GT réparée doit regagner la piste.")

func check_jacks() -> void:
	var race := make_race()
	var first := race.cars[0]
	var second := race.cars[1]
	first.state = Race.State.BOX
	second.state = Race.State.GARAGE
	first.tires = 0.45
	second.tires = 0.47
	first.fuel = 0.55
	check(race.confirm_stop(0,{"fuel":Race.Mode.AUTO,"tires":Race.Mode.MANUAL},false),"Le plan doit mélanger manuel et auto sur une GT.")
	check(race.confirm_stop(1,{"tires":Race.Mode.AUTO},true),"Une deuxième demande de pneus doit pouvoir attendre les crics.")
	check(not race.manual_action(0,"tires",0,0),"Une roue ne doit pas se changer avant de lever son train.")
	check(race.manual_action(0,"tires",0) and race.manual_action(0,"tires",1),"Les deux crics doivent pouvoir lever leur propre train.")
	race.advance(1.0)
	check(first.jobs.has("fuel") and not second.jobs.has("tires") and race.jack_owners==[0,0],"Le plein avance en parallèle et l’autre GT attend les crics.")
	for axle in range(2):
		check(not race.manual_action(0,"tires",axle),"Impossible d’abaisser un train avec une roue encore à changer.")
		for wheel in range(2):
			check(race.manual_action(0,"tires",axle,wheel),"Chaque roue levée doit pouvoir être changée.")
			check(not race.manual_action(0,"tires",axle,wheel),"Le même pneu ne doit pas être validé deux fois.")
		check(race.manual_action(0,"tires",axle),"Le cric doit se libérer quand les deux pneus sont changés.")
	check(first.tires==1.0 and race.jack_owners==[-1,-1] and not race.perform(0,"exit"),"Les pneus sont terminés mais le plein doit finir avant le départ.")
	race.advance(1.0)
	check(second.jobs.has("tires") and race.jack_owners==[1,1],"Le travail automatique doit récupérer les crics libérés.")

func check_incident_and_delay() -> void:
	var race := make_race()
	race.next_team_incident = 2.0
	race.advance(3.0)
	var damaged: Dictionary = race.cars[0] if race.cars[0].damage>0.0 else race.cars[1]
	check(damaged.damage>=0.15 and race.lap_seconds(damaged)>damaged.base_lap,
		"Un accrochage doit réellement dégrader le rythme d’une GT.")
	check(race.radio[0].contains("accrochage"),"Le pilote doit signaler l’accrochage à la radio.")
	var car := race.cars[0]
	car.distance = 3.994
	check(race.confirm_stop(0,{},false) and race.perform(0,"delay"),"Un arrêt peut être décalé avant l’entrée des stands.")
	race.advance(4.0)
	check(car.state==Race.State.TRACK and floori(car.distance)==4,"La GT doit passer la ligne en piste avant son arrêt décalé.")
	race.advance(10.0)
	check(car.called,"L’arrêt décalé doit être rappelé au tour suivant.")
	car.fuel = 0.0001
	check(not race.perform(0,"delay"),"Une GT sur la réserve ne peut pas repousser un arrêt indéfiniment.")
	race.advance(1.0)
	check(car.state==Race.State.OUT and race.classification().back()==car,"Une panne d’essence doit entraîner un abandon classé en arrière.")

func check_complete_race() -> void:
	var race := make_race()
	var real_seconds := 0.0
	while race.phase==Race.Phase.RACE:
		for i in range(2):
			var car := race.cars[i]
			if car.state not in [Race.State.BOX,Race.State.GARAGE]: continue
			if car.orders.is_empty():
				var orders := {"fuel":Race.Mode.AUTO,"tires":Race.Mode.AUTO,"driver":Race.Mode.AUTO,"repair":Race.Mode.AUTO}
				race.confirm_stop(i,orders,car.damage>=0.38)
			else: race.perform(i,"exit")
		real_seconds += 1.0/race.rate()
		race.advance(1.0)
	check(race.phase==Race.Phase.FINISH and race.elapsed==Race.DURATION and race.clock()=="20:00",
		"Le drapeau à damier doit arrêter la simulation exactement après douze heures.")
	check(race.cars[0].state!=Race.State.OUT and race.cars[1].state!=Race.State.OUT,
		"Une équipe qui entretient ses deux GT doit pouvoir terminer.")
	var standings := race.classification()
	var leader: float = standings[0].distance
	var winner := int(standings[0].number)
	race.advance(999.0)
	check(race.elapsed==Race.DURATION and race.classification()[0].distance==leader,
		"Le classement reste figé après l’arrivée.")
	for car in race.cars:
		check(car.distance>250.0 and car.stops>=8,"Chaque concurrent doit faire ses propres tours et arrêts.")
	check(race.cars[0].stops<=20 and race.cars[1].stops<=20 and real_seconds<54.0*60.0,
		"Une rotation normale des pilotes ne doit pas provoquer des arrêts répétés en fin de course.")
	check(standings[0].distance>standings[1].distance and standings[1].distance>standings.back().distance,
		"Le classement doit départager les stratégies et les performances.")
	print("12 h simulées · vainqueur n° %d · %.1f tours · %.1f min de jeu avec interventions immédiates" % [winner,leader,real_seconds/60.0])

func frames() -> void:
	await process_frame
	await process_frame
	await physics_frame
	await process_frame

func press_pad(button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventJoypadButton.new()
	event.button_index = button_index
	Input.parse_input_event(event)
	await process_frame

func move_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await process_frame

func check_local_menu() -> void:
	var game = load("res://main.tscn").instantiate()
	game.local_storage_enabled = false
	root.add_child(game)
	game.game_menu.request_new_game()
	var choice: Button
	for control: Button in game.game_menu.content.find_children("*","Button",true,false):
		if control.text=="Course de 12 h": choice = control
	check(choice!=null and game.game_menu.screen=="layouts","La course de 12 h doit se trouver dans Nouvelle partie.")
	if choice==null:
		game.queue_free()
		return
	await frames()
	choice.grab_focus()
	await press_pad(JOY_BUTTON_A)
	await frames()
	check(game.endurance_active and not paused and game.endurance_hud.visible and not game.workshop.ui.visible,
		"A doit lancer le mode endurance avec la bonne interface.")
	if game.endurance_active:
		var hud = game.endurance_hud
		check(game.endurance_stands.cars.size()==2 and game.endurance_stands.animations[1].has_animation("bonnet-open"),
			"Les deux vrais modèles GT et leurs animations doivent se charger.")
		check(root.gui_get_focus_owner()==hud.start_button,"La manette doit être prête à donner le départ.")
		await press_pad(JOY_BUTTON_A)
		await frames()
		check(game.endurance.phase==Race.Phase.RACE,"A doit donner le départ depuis le briefing.")
		var screen = game.endurance_stands.screen_circuit
		check(screen.race==game.endurance and screen.live and screen.get_viewport()==game.endurance_stands.control_screen,
			"L’écran physique doit afficher le circuit de la course en cours.")
		var ours: Vector2 = screen.car_transform(0).origin
		var rival: Vector2 = screen.car_transform(5).origin
		game.endurance.advance(4.0)
		check(screen.car_transform(0).origin.distance_to(ours)>1.0 and screen.car_transform(5).origin.distance_to(rival)>1.0,
			"L’écran doit faire avancer la GT de l’équipe et les rivales avec la simulation.")
		check(game.endurance.rate()==24.0,"Le rythme initial en piste doit être ×24.")
		await move_axis(JOY_AXIS_TRIGGER_RIGHT,0.8)
		check(game.endurance.rate()==48.0,"RT doit accélérer le temps à ×48.")
		await move_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
		await move_axis(JOY_AXIS_TRIGGER_LEFT,0.65)
		await move_axis(JOY_AXIS_TRIGGER_LEFT,0.95)
		check(game.endurance.rate()==24.0,"Un maintien de LT doit ralentir d’un seul cran.")
		await move_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
		await move_axis(JOY_AXIS_TRIGGER_LEFT,0.9)
		await move_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
		check(game.endurance.rate()==12.0,"Une deuxième pression de LT doit passer à ×12.")
		await press_pad(JOY_BUTTON_Y)
		hud.open_plan(0)
		check(not hud.control_panel.visible and not hud.planner.visible,
			"Une décision d’arrêt doit être inaccessible depuis le terrain.")
		var worker: Dictionary = game.endurance_crew.workers[0]
		var spawn: Vector2 = worker.point
		worker.point = game.endurance_stands.CONTROL_POINT
		check(worker.point.y>-1.22 and game.endurance_stands.walkable(worker.point,game.endurance),
			"Le poste de contrôle doit être accessible à l’extérieur du garage.")
		await press_pad(JOY_BUTTON_Y)
		check(hud.control_panel.visible and not hud.left_panel.visible,"Y doit ouvrir le panneau de gauche au poste de contrôle.")
		check(hud.clock_panel.visible and hud.service_details[0].is_visible_in_tree() and hud.service_details[1].is_visible_in_tree(),
			"Les deux GT et le chrono doivent rester visibles au poste.")
		check(hud.live_circuit.is_visible_in_tree() and hud.control_scores.size()==10
			and hud.control_scores[9].is_visible_in_tree(),"Le direct et les dix rangs doivent figurer dans la console.")
		await move_axis(JOY_AXIS_LEFT_X,0.75)
		await move_axis(JOY_AXIS_LEFT_X,0.0)
		check(hud.selected_car==1,"Le stick gauche doit sélectionner la n° 81 au contrôle.")
		await press_pad(JOY_BUTTON_DPAD_LEFT)
		check(hud.selected_car==0,"La croix doit sélectionner la n° 27 au contrôle.")
		check(game.endurance.rate(true)==Race.PIT_RATE,"Le poste doit plafonner la progression du temps.")
		await press_pad(JOY_BUTTON_A)
		check(hud.planner.visible and hud.planner_index==0 and not game.endurance.cars[0].called,
			"Y puis A doit ouvrir le plan d’arrêt et attendre la confirmation.")
		check(hud.clock_panel.visible and hud.service_details[1].is_visible_in_tree(),
			"Le chrono et les deux voitures doivent rester visibles pendant la planification.")
		var last_car: Dictionary = game.endurance.cars[9]
		var previous_distance: float = last_car.distance
		last_car.distance = 2.0
		hud.refresh()
		check(hud.live_circuit.is_visible_in_tree() and hud.control_scores[0].is_visible_in_tree()
			and hud.control_scores[0].text.contains("96"),"Le classement doit rester visible et s’actualiser dans le plan.")
		await frames()
		check(hud.control_panel.position.y>hud.clock_panel.get_rect().end.y,
			"Le panneau de stratégie doit laisser le chrono dégagé.")
		check(hud.service_status[0].size.y>=48.0 and not hud.service_status[0].text.is_empty(),
			"Le suivi des deux GT doit garder de la place pour l’état de service.")
		last_car.distance = previous_distance
		var previous_mode: int = hud.draft.fuel
		await press_pad(JOY_BUTTON_DPAD_RIGHT)
		check(hud.draft.fuel!=previous_mode,"Droite doit modifier le mode de l’intervention sélectionnée.")
		await press_pad(JOY_BUTTON_B)
		check(hud.control_panel.visible and not hud.planner.visible and not game.endurance.cars[0].called,
			"Annuler un plan doit restaurer le contrôle sans appeler la GT.")
		await press_pad(JOY_BUTTON_B)
		check(hud.field_input() and hud.left_panel.visible,"Quitter le poste doit restituer les commandes de terrain.")
		check(game.camera.rotation_degrees.is_equal_approx(GarageCamera.ROTATION),
			"L’endurance doit reprendre la perspective du garage de quartier.")
		check(not hud.standings_rows.visible,"Le classement doit pouvoir se replier pour dégager la vue.")
		hud.standings_button.pressed.emit()
		check(hud.standings_rows.visible and hud.scores.size()==10,"Le classement complet doit rester consultable.")
		hud.standings_button.pressed.emit()
		var overview: float = game.camera.size
		await press_pad(JOY_BUTTON_RIGHT_SHOULDER)
		await create_timer(0.2).timeout
		check(game.endurance_stands.zoom==1 and game.camera.size<overview,"RB doit rapprocher la caméra du mécano.")
		await press_pad(JOY_BUTTON_LEFT_SHOULDER)
		check(game.endurance_stands.zoom==0,"LB doit revenir au plan d’ensemble.")
		worker.point = spawn
		var key := InputEventKey.new()
		key.physical_keycode = KEY_D
		key.pressed = true
		Input.parse_input_event(key)
		await create_timer(0.15).timeout
		key = InputEventKey.new()
		key.physical_keycode = KEY_D
		Input.parse_input_event(key)
		check(worker.point.x>spawn.x+0.1 and worker.avatar.visible,"Le mécano doit marcher avec les commandes habituelles.")
		game.set_physics_process(false)
		var guest: Array = [true,0.0,0.0,0.0,0.0,0,0.0,0.0,2]
		var crew: Crew = game.endurance_crew
		crew.tick(0.016,Race.PIT_RATE,Vector2.ZERO,false,guest,true)
		hud.guest_input(guest)
		check(hud.control_owner==-1,"X ne doit pas ouvrir le contrôle à distance pour l’invité.")
		guest[8] = 32
		hud.guest_input(guest)
		check(game.endurance.rate()==24.0,"RT côté invité doit transmettre la demande de vitesse.")
		crew.workers[1].point = crew.stands.CONTROL_POINT
		guest[8] = 2
		hud.guest_input(guest)
		check(hud.control_owner==1 and hud.field_input(),
			"L’invité ouvre le contrôle avec X à proximité du banc pendant que l’hôte reste libre.")
		guest[8] = 4
		hud.guest_input(guest)
		check(hud.planner.visible and hud.planner_index==1,"A ouvre le plan de la n° 81 à l’invité.")
		check(hud.live_circuit.is_visible_in_tree() and hud.control_scores[9].is_visible_in_tree(),
			"L’invité doit aussi voir la course et le classement pendant la planification.")
		guest[2] = -1.0
		guest[8] = 0
		hud.guest_input(guest)
		guest[2] = 0.0
		hud.guest_input(guest)
		guest[2] = -1.0
		hud.guest_input(guest)
		guest[2] = 0.0
		guest[8] = 4
		hud.guest_input(guest)
		check(game.endurance.cars[1].called and not game.endurance.cars[0].called,"A doit confirmer le plan de l’invité.")
		hud.guest_input([])
		check(hud.control_owner==-1 and not hud.control_panel.visible,"Une déconnexion doit libérer le poste.")
		check_world_tools(game)
		game.set_physics_process(true)
		game.game_menu.show_pause()
		var elapsed: float = game.endurance.elapsed
		await create_timer(0.15).timeout
		check(paused and game.endurance.elapsed==elapsed and not hud.visible,"La pause doit figer la course et masquer son interface.")
		check(game.game_menu.content.find_children("*","Label",true,false).any(
			func(row: Label) -> bool: return row.text==hud.clock_line()),"Le menu de pause doit conserver le chrono à l’écran.")
		game.game_menu.return_home()
		check(game.endurance_in_progress(),"La course doit rester disponible après le retour à l’accueil.")
		game.start_local_game(0)
		await frames()
		check(not game.endurance_active and game.workshop.ui.visible and game.workshop.site.visible,
			"Un garage de quartier doit rester jouable après la course.")
		game.resume_endurance()
		await frames()
		check(game.endurance_active and game.endurance.elapsed>=elapsed,"La reprise doit conserver la course en mémoire.")
	game.queue_free()
	await process_frame

func check_world_tools(game: Node3D) -> void:
	var race: Race = game.endurance
	var crew: Crew = game.endurance_crew
	var car := race.cars[0]
	car.state = Race.State.BOX
	car.fuel = 0.57
	car.tires = 0.49
	check(race.confirm_stop(0,{"fuel":Race.Mode.MANUAL,"tires":Race.Mode.MANUAL},false),"Le joueur doit confirmer les opérations avant de travailler.")
	game.endurance_stands.update_cars(race,0.0)
	var pump: Vector2 = crew.stands.PUMP
	crew.workers[0].point = pump+Vector2(1.65,0.15)
	crew.workers[0].velocity = Vector2.ZERO
	crew.move_worker(0,0.016,Race.PIT_RATE,Vector2.ZERO,false,Vector2.RIGHT)
	check(crew.workers[0].target.is_empty(),"Viser ailleurs ne doit pas sélectionner la pompe à distance.")
	crew.move_worker(0,0.016,Race.PIT_RATE,Vector2.ZERO,true,Vector2.LEFT)
	var hud = game.endurance_hud
	hud.refresh()
	hud.update_feedback(game.camera)
	check(crew.workers[0].target.get("action")=="nozzle" and crew.workers[0].outline.visible
		and hud.feedback[0].visible and hud.feedback[0].amount>0.0,"L’intervention affiche une jauge au-dessus du repère.")
	try_station(crew,"control")
	check(hud.control_panel.visible and hud.service_buttons[2].disabled,"Le feu vert doit rester bloqué si des actions sont en attente.")
	hud.close_control()
	try_station(crew,"nozzle")
	hud.update_feedback(game.camera)
	check(crew.workers[0].held=="nozzle","Le pistolet doit se prendre à la pompe.")
	check(hud.feedback[0].visible and hud.feedback[0].outcome=="✓","Une action réussie doit afficher une coche.")
	try_station(crew,"fuel")
	check(car.jobs.has("fuel") and crew.workers[0].held=="","Le joueur doit brancher le pistolet sur la GT.")
	var fill_duration: float = car.jobs.get("fuel",{}).get("left",0.0)
	for axle in range(2):
		try_station(crew,"tires",axle)
		for wheel in range(2): try_station(crew,"tires",axle,wheel)
		try_station(crew,"tires",axle)
		race.advance(2.0)
	check(car.tires==1.0 and car.jobs.has("fuel") and car.jobs.fuel.left<fill_duration,
		"On peut changer les quatre pneus pendant que la pompe remplit le réservoir.")
	race.advance(22.0)
	check(car.fuel==1.0,"Le plein doit arriver à son terme.")
	car.damage = 0.62
	check(race.confirm_stop(0,{"repair":Race.Mode.MANUAL},true),"Le plan peut demander une intervention au garage.")
	game.endurance_stands.update_cars(race,0.0)
	try_station(crew,"wrench")
	check(crew.workers[0].held=="wrench","Les outils doivent être accessibles dans le décor.")
	try_station(crew,"repair")
	check(car.jobs.has("repair"),"La réparation doit démarrer au repère de la GT avec la clé.")
	race.advance(140.0)
	check(car.damage==0.0 and race.allowed(car,"exit"),"La GT réparée dans le garage doit être prête à repartir.")
	check(not crew.station_options(0).any(func(option: Dictionary) -> bool: return option.action=="exit"),
		"Aucune interaction devant la voiture ne doit pouvoir la libérer.")
	hud.activate(2)
	check(car.state==Race.State.GARAGE,"Le feu vert à distance doit être refusé.")
	try_station(crew,"control")
	check(not hud.service_buttons[2].disabled,"Le feu vert doit être disponible au contrôle après les réparations.")
	game.endurance_stands.update_control_lights(race)
	check(game.endurance_stands.control_lights[0].albedo_color==game.endurance_stands.CONTROL_READY,
		"Le voyant de la GT prête doit passer au vert.")
	hud.service_buttons[2].pressed.emit()
	check(car.state==Race.State.EXIT,"Le bouton Feu vert doit faire repartir la GT.")
	hud.close_control()

func try_station(crew: Crew, action: String, axle := -1, wheel := -1) -> void:
	for site in crew.station_options(0):
		if site.action!=action or site.axle!=axle or site.wheel!=wheel: continue
		check(crew.stands.walkable(site.point,crew.race),"Le repère de l’intervention doit être accessible à pied : "+site.title)
		crew.workers[0].point = site.point
		crew.workers[0].velocity = Vector2.ZERO
		crew.move_worker(0,0.016,Race.PIT_RATE,Vector2.ZERO,false)
		for i in range(ceili(site.duration*12.0/Race.PIT_RATE)):
			crew.move_worker(0,1.0/12.0,Race.PIT_RATE,Vector2.ZERO,true)
		return
	check(false,"Repère d’intervention manquant : "+action)

func run_tests() -> void:
	check_stops_and_repairs()
	check_jacks()
	check_incident_and_delay()
	check_complete_race()
	await check_local_menu()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS · contrôle course sur place, feu vert, manette, invité, crics, pompe et interventions parallèles.")
	quit(0 if failures.is_empty() else 1)

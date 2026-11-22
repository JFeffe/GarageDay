extends SceneTree

const Race := preload("res://endurance_race.gd")
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
	check(race.perform(0,"call") and race.perform(1,"call"),"Les deux GT doivent pouvoir recevoir un appel au box.")
	race.advance(27.0)
	check(first.state==Race.State.BOX and second.state==Race.State.QUEUE,"Un deuxième arrêt doit attendre si le box est occupé.")
	check(race.perform(0,"garage") and second.state==Race.State.BOX,"Rentrer au garage doit libérer le box immédiatement.")
	check(race.perform(0,"repair") and race.perform(1,"fuel"),"Le garage et le box doivent permettre deux interventions simultanées.")
	check(first.job_left>300.0 and not race.perform(0,"exit"),"Une réparation importante prend du temps et doit être terminée avant de repartir.")
	race.advance(35.0)
	check(is_equal_approx(second.fuel,1.0) and first.job=="repair","Le plein doit finir pendant la réparation de l’autre GT.")
	check(race.perform(1,"tires"),"La deuxième GT doit pouvoir changer ses pneus après le plein.")
	race.advance(30.0)
	check(is_equal_approx(second.tires,1.0) and race.perform(1,"driver"),"Les pneus doivent être neufs et la relève disponible.")
	race.advance(26.0)
	check(second.driver==1 and not race.perform(1,"driver"),"La relève doit changer le pilote une seule fois par arrêt.")
	second.damage = 0.24
	check(not race.perform(1,"garage") and race.perform(1,"patch"),"Une GT peut être réparée au box pendant que le garage est occupé.")
	race.advance(52.0)
	check(second.damage==0.0 and race.perform(1,"exit"),"La réparation rapide doit enlever les petits dégâts.")
	race.advance(20.0)
	check(second.state==Race.State.TRACK and second.planned>race.elapsed,"La deuxième GT doit reprendre son relais avec un prochain arrêt.")
	race.advance(300.0)
	check(first.damage==0.0 and race.perform(0,"exit"),"Le garage doit permettre une réparation complète et la sortie.")
	race.advance(20.0)
	check(first.state==Race.State.TRACK,"La GT réparée doit regagner la piste.")

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
	check(race.perform(0,"call") and race.perform(0,"delay"),"Un arrêt peut être décalé avant l’entrée des stands.")
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
			if car.state not in [Race.State.BOX,Race.State.GARAGE] or car.job!="": continue
			if car.damage>=0.38 and race.perform(i,"garage"): continue
			if car.state==Race.State.GARAGE and race.perform(i,"repair"): continue
			if car.fuel<0.80 and race.perform(i,"fuel"): continue
			if car.tires<0.80 and race.perform(i,"tires"): continue
			if car.fatigue[car.driver]>1500.0 and race.perform(i,"driver"): continue
			if race.perform(i,"patch"): continue
			race.perform(i,"exit")
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
	check(race.cars[0].stops<=20 and race.cars[1].stops<=20 and real_seconds<45.0*60.0,
		"Une rotation normale des pilotes ne doit pas provoquer des arrêts répétés en fin de course.")
	check(standings[0].distance>standings[1].distance and standings[1].distance>standings.back().distance,
		"Le classement doit départager les stratégies et les performances.")
	print("12 h simulées · vainqueur n° %d · %.1f tours · %.1f min de jeu avec interventions immédiates" % [winner,leader,real_seconds/60.0])

func frames() -> void:
	await process_frame
	await process_frame
	await physics_frame
	await process_frame

func press_a() -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	Input.parse_input_event(event)
	await process_frame

func check_local_menu() -> void:
	var game = load("res://main.tscn").instantiate()
	game.local_storage_enabled = false
	root.add_child(game)
	var choice: Button
	for control: Button in game.game_menu.content.find_children("*","Button",true,false):
		if control.text=="Course de 12 h": choice = control
	check(choice!=null,"L’accueil local doit proposer la course de 12 h.")
	if choice==null:
		game.queue_free()
		return
	await frames()
	choice.grab_focus()
	await press_a()
	await frames()
	check(game.endurance_active and not paused and game.endurance_hud.visible and not game.workshop.ui.visible,
		"A doit lancer le mode endurance avec la bonne interface.")
	if game.endurance_active:
		var hud = game.endurance_hud
		check(game.endurance_stands.cars.size()==2 and game.endurance_stands.animations[1].has_animation("bonnet-open"),
			"Les deux vrais modèles GT et leurs animations doivent se charger.")
		check(root.gui_get_focus_owner()==hud.start_button,"La manette doit être prête à donner le départ.")
		await press_a()
		await frames()
		check(game.endurance.phase==Race.Phase.RACE,"A doit donner le départ depuis le briefing.")
		var guest: Array = [true,0.0,0.0,0.0,0.0,0,0.0,0.0,4]
		hud.guest_input(guest)
		check(game.endurance.cars[1].called and not game.endurance.cars[0].called,"L’invité doit commander uniquement la n° 81.")
		game.game_menu.show_pause()
		var elapsed: float = game.endurance.elapsed
		await create_timer(0.15).timeout
		check(paused and game.endurance.elapsed==elapsed and not hud.visible,"La pause doit figer la course et masquer son interface.")
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

func run_tests() -> void:
	check_stops_and_repairs()
	check_incident_and_delay()
	check_complete_race()
	await check_local_menu()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS · endurance, deux GT, rivaux, arrêts concurrents, relais, réparations, manette et invité.")
	quit(0 if failures.is_empty() else 1)

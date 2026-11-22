extends SceneTree

var failures: Array[String] = []
var save_path := "res://.godot/menu-test.save"
var config_path := "res://.godot/menu-test.cfg"

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames() -> void:
	await process_frame
	await process_frame
	await physics_frame
	await process_frame

func make_game():
	var game = load("res://main.tscn").instantiate()
	game.local_save_path = save_path
	game.settings_path = config_path
	root.add_child(game)
	return game

func clean_files() -> void:
	for path in [save_path,config_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func pad_event(button_index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event)

func start_event(pressed: bool) -> void:
	pad_event(JOY_BUTTON_START,pressed)

func press_pad(button_index: int) -> void:
	pad_event(button_index,true)
	await process_frame
	pad_event(button_index,false)
	await process_frame

func run_test() -> void:
	clean_files()
	var game = make_game()
	var menu = game.game_menu
	check(paused and menu.screen=="home" and not game.session_active,"Le lancement doit afficher l’accueil et figer le garage")
	check(game.saved_game().is_empty(),"L’accueil ne doit pas créer ni écraser une sauvegarde")
	check(is_equal_approx(game.get_viewport().scaling_3d_scale,1.0),"Le mode Équilibré en solo doit conserver toute la résolution 3D")
	menu.request_new_game()
	check(menu.screen=="layouts","Sans sauvegarde, Nouvelle partie doit proposer les garages")
	check(menu.first_button.text=="Le Petit Atelier","L’accueil doit présenter le petit garage en premier")
	await process_frame
	await press_pad(JOY_BUTTON_A)
	await frames()
	check(not paused and game.workshop.layout==game.Map.COMPACT_LAYOUT,"A doit lancer le petit garage depuis l’accueil")
	menu.return_home()
	game.session_active = false
	game.continue_local_game()
	await frames()
	check(not paused and game.workshop.layout==game.Map.COMPACT_LAYOUT,"Continuer doit restaurer le petit garage enregistré")
	game.start_local_game(1)
	await frames()
	check(not paused and game.workshop.layout==1 and game.workshop.site.bays.size()==2,"Le Tandem doit démarrer depuis l’accueil")
	game.workshop.run.cash = 123
	game.store_checkpoint()
	var checkpoint: String = game.saved_game()
	game.workshop.run.start()
	await create_timer(0.08).timeout
	start_event(true)
	await process_frame
	start_event(false)
	check(paused and menu.screen=="pause","Start doit ouvrir la pause")
	await process_frame
	await press_pad(JOY_BUTTON_DPAD_DOWN)
	await press_pad(JOY_BUTTON_A)
	check(paused and menu.screen=="options","La croix directionnelle et A doivent ouvrir les options depuis la pause")
	if menu.screen=="options":
		await press_pad(JOY_BUTTON_A)
		var popup: PopupMenu = menu.quality_button.get_popup()
		check(popup.visible,"A doit ouvrir le choix de la qualité graphique")
		if popup.visible:
			await press_pad(JOY_BUTTON_DPAD_UP)
			await press_pad(JOY_BUTTON_A)
			check(game.display_quality=="fast" and not popup.visible,"A doit valider une qualité dans la liste")
		await press_pad(JOY_BUTTON_B)
		check(menu.screen=="pause","B doit ramener des options à la pause")
	game.apply_graphics("high",false)
	check(game.get_viewport().msaa_3d==Viewport.MSAA_2X,"Le mode Qualité en solo doit lisser les contours")
	var elapsed: float = game.workshop.run.elapsed
	var position: Vector2 = game.workshop.player
	await create_timer(0.12).timeout
	check(game.workshop.run.elapsed==elapsed and game.workshop.player==position,"L’horloge et le joueur doivent rester immobiles en pause")
	menu.show_options("pause")
	game.change_display("fast",true)
	check(not game.get_node("Sun").shadow_enabled and game.get_viewport().scaling_3d_scale<0.7,"Le mode Fluide doit appliquer ses réglages")
	menu.go_back()
	check(paused and menu.screen=="pause","Retour depuis les options doit conserver la pause")
	menu.return_home()
	check(paused and menu.screen=="home","Retour à l’accueil doit conserver la partie en pause")
	check(game.saved_game()==checkpoint,"Un service en cours ne doit pas écraser le point de reprise sûr")
	menu.request_new_game()
	check(menu.screen=="new_confirm","Remplacer une partie doit demander confirmation")
	menu.go_back()
	game.continue_local_game()
	await frames()
	check(not paused and game.workshop.run.mode=="day" and game.workshop.run.cash==123,"Continuer doit reprendre le service en cours")
	check(game.workshop.run.elapsed>elapsed,"L’horloge doit reprendre après Continuer")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(paused and menu.screen=="pause","Échap doit ouvrir la pause avec un événement clavier logique")
	escape.pressed = false
	Input.parse_input_event(escape)
	menu.resume_game()
	await frames()
	# A workshop sub-menu must survive pause/resume too.
	game.workshop.show_layouts()
	start_event(true)
	await process_frame
	start_event(false)
	check(paused and menu.screen=="pause","Start doit aussi fonctionner au-dessus du choix du garage")
	start_event(true)
	await frames()
	start_event(false)
	check(not paused and game.workshop.menu.visible,"Start doit reprendre le sous-menu du garage")
	menu.show_home()
	game.queue_free()
	await process_frame
	game = make_game()
	check(paused and game.game_menu.screen=="home","Un redémarrage doit revenir à l’accueil")
	check(game.saved_game()==checkpoint,"Un redémarrage ne doit pas écraser la sauvegarde existante")
	check(game.display_quality=="fast" and game.display_fps,"Les options doivent être relues au redémarrage")
	game.continue_local_game()
	await frames()
	check(game.workshop.layout==1 and game.workshop.run.mode=="open" and game.workshop.run.cash==123,
		"Après fermeture, Continuer doit restaurer le garage et la caisse avant le service")
	game.start_local_game(2)
	await frames()
	check(game.workshop.layout==2 and game.workshop.site.bays.size()==3 and game.workshop.run.cash==0,"Une nouvelle partie doit réinitialiser le garage choisi")
	game.workshop.run.mode = "won"
	game.store_checkpoint()
	check(game.saved_game().is_empty(),"Une partie terminée ne doit pas laisser une ancienne sauvegarde")
	game.queue_free()
	await process_frame
	paused = false
	clean_files()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: accueil, choix du garage à la manette, Start, vraie pause, sous-menus, reprise en mémoire, sauvegarde locale, options persistantes.")
	quit(0 if failures.is_empty() else 1)

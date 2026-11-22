extends CanvasLayer

const INK := Color("#101e20")
const CREAM := Color("#fff3d9")
const MINT := Color("#8fc6bb")
const QUALITY_IDS := ["fast","balanced","high"]
const QUALITY_NAMES := ["Fluide","Équilibré","Qualité"]
const QUALITY_DETAILS := ["Résolution 3D réduite et ombres désactivées.",
	"Image plus nette en solo et ombres simplifiées.",
	"Résolution maximale, ombres détaillées et contours lissés en solo."]
const GARAGE_IMAGES := [preload("res://web/images/traversee.webp"),
	preload("res://web/images/tandem.webp"),preload("res://web/images/trois-ponts.webp"),
	preload("res://web/images/petit-atelier.webp")]
const HERO := preload("res://web/images/atelier.webp")
const ENDURANCE := preload("res://web/images/endurance.webp")

var game: Node3D
var screen := ""
var options_origin := "home"
var overlay: ColorRect
var content: VBoxContainer
var notice: Label
var fps: Label
var pause_button: Button
var quality_button: OptionButton
var fps_check: CheckButton
var quality_details: Label
var first_button: Button
var fps_elapsed := 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme := Theme.new()
	theme.default_font_size = 18
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#31534e") if state in ["hover","focus"] else Color("#203635")
		style.border_color = Color("#e5bd78") if state=="focus" else Color("#4d756f")
		style.set_border_width_all(2 if state=="focus" else 1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		for type in ["Button","OptionButton"]:
			theme.set_stylebox(state,type,style)
			theme.set_color("font_color",type,CREAM)
	overlay = ColorRect.new()
	overlay.color = INK
	overlay.theme = theme
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+edge,38)
	overlay.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	scroll.add_child(content)
	pause_button = Button.new()
	pause_button.theme = theme
	pause_button.text = "Menu · Start / Échap"
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pause_button.position = Vector2(-115,12)
	pause_button.size = Vector2(230,42)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(show_pause)
	add_child(pause_button)
	fps = Label.new()
	fps.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	fps.position = Vector2(-30,60)
	fps.add_theme_color_override("font_color",CREAM)
	fps.add_theme_color_override("font_shadow_color",INK)
	fps.add_theme_constant_override("shadow_offset_x",2)
	fps.add_theme_constant_override("shadow_offset_y",2)
	add_child(fps)
	overlay.hide()

func _process(dt: float) -> void:
	fps.visible = game.display_fps and not OS.has_feature("web")
	fps_elapsed += dt
	if fps_elapsed>=0.5:
		fps_elapsed = 0.0
		fps.text = "%d i/s"%Engine.get_frames_per_second()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if screen=="": show_pause()
		elif screen=="pause": resume_game()
		elif screen!="home": go_back()
	elif overlay.visible and (event.is_action_pressed("cancel_item") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		go_back()
	elif overlay.visible and event.is_action_pressed("use_item") and event is InputEventKey and not event.is_echo():
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and not focused is OptionButton:
			get_viewport().set_input_as_handled()
			if focused is BaseButton and focused.toggle_mode: focused.button_pressed = not focused.button_pressed
			else: focused.pressed.emit()

func page(id: String, title: String, subtitle := "") -> void:
	screen = id
	game.get_tree().paused = true
	game.show_activity_hud(false)
	pause_button.hide()
	overlay.color = Color(0.04,0.09,0.10,0.94) if id=="pause" else INK
	overlay.show()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	first_button = null
	content.add_child(label(title,40,CREAM))
	if subtitle!="": content.add_child(label(subtitle,17,MINT))
	if game.endurance_active and (id in ["pause","leave_host"] or (id=="options" and options_origin=="pause")):
		content.add_child(label(game.endurance_hud.clock_line(),18,CREAM))
	notice = label("",16,Color("#e5bd78"))
	content.add_child(notice)

func label(text: String, font_size := 18, color := CREAM) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	return result

func button(parent: Control, text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 46
	result.pressed.connect(callback)
	parent.add_child(result)
	if first_button==null:
		first_button = result
		focus_control.call_deferred(result.get_instance_id())
	return result

func focus_control(control_id: int) -> void:
	var control = instance_from_id(control_id)
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()

func picture(texture: Texture2D, width: float, height: float) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = Vector2(width,height)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func show_home() -> void:
	game.store_checkpoint()
	page("home","Garage Day","Atelier de quartier et course d’endurance.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",36)
	content.add_child(row)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 300
	actions.add_theme_constant_override("separation",12)
	row.add_child(actions)
	if game.session_active or not game.saved_game().is_empty():
		button(actions,"Continuer",game.continue_local_game)
	button(actions,"Nouvelle partie",request_new_game)
	if game.endurance_in_progress(): button(actions,"Reprendre les 12 h",game.resume_endurance)
	button(actions,"Multijoueur",show_multiplayer)
	button(actions,"Options",func() -> void: show_options("home"))
	button(actions,"Notes de mise à jour",show_notes)
	button(actions,"Quitter le jeu",quit_game)
	row.add_child(picture(HERO,220,340))
	content.add_child(label("Flèches / stick · A / Entrée / F choisir · B / Q retour",15,MINT))
	content.add_child(label("v"+str(ProjectSettings.get_setting("application/config/version")),14,MINT))

func show_pause() -> void:
	if not game.session_active and not game.endurance_active: return
	game.store_checkpoint()
	page("pause","Pause","La course est en pause." if game.endurance_active else "Le garage est en pause. Reprends quand tu veux.")
	button(content,"Reprendre",resume_game)
	button(content,"Options",func() -> void: show_options("pause"))
	button(content,"Retour au menu d’accueil",return_home)
	if not OS.has_feature("web"): button(content,"Quitter le jeu",quit_game)
	content.add_child(label("Croix / flèches · A / Entrée choisir · Start / Échap reprendre",16,MINT))

func resume_game() -> void:
	screen = ""
	overlay.hide()
	var endurance: bool = game.endurance_active
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if endurance else Control.PRESET_CENTER_TOP)
	pause_button.text = "Pause" if endurance else "Menu · Start / Échap"
	pause_button.position = Vector2(14,12) if endurance else Vector2(-115,12)
	pause_button.size = Vector2(100,42) if endurance else Vector2(230,42)
	fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if endurance else Control.PRESET_CENTER_TOP)
	fps.position = Vector2(493,22) if endurance else Vector2(-30,60)
	pause_button.show()
	game.show_activity_hud(true)
	# Resume on the next frame so accepting the menu cannot interact with the garage.
	resume_after_input.call_deferred()

func resume_after_input() -> void:
	await get_tree().process_frame
	if screen=="":
		get_tree().paused = false
		if game.endurance_active: game.endurance_hud.focus_first()

func return_home() -> void:
	if game.web_room!=null:
		if game.hosting:
			var detail := "L’invité sera déconnecté et la course prendra fin." if game.endurance_active else "La connexion de l’invité sera fermée. La reprise se fera au dernier atelier libre sauvegardé."
			page("leave_host","Quitter la partie ?",detail)
			button(content,"Rester dans le garage",show_pause)
			button(content,"Retour à l’accueil",func() -> void: game.web_room.returnToMenu())
		else: game.web_room.returnToMenu()
	else: show_home()

func go_back() -> void:
	match screen:
		"pause": resume_game()
		"options":
			if options_origin=="pause": show_pause()
			else: show_home()
		"leave_host": show_pause()
		"new_confirm": show_layouts()
		"home": pass
		_: show_home()

func request_new_game() -> void:
	show_layouts()

func select_workshop(index: int) -> void:
	if game.session_active or not game.saved_game().is_empty():
		page("new_confirm","Nouveau garage ?","La progression de ton garage actuel sera remplacée.")
		button(content,"Annuler",show_layouts)
		button(content,"Commencer",game.start_local_game.bind(index))
	else: game.start_local_game(index)

func select_endurance() -> void:
	if game.endurance_in_progress():
		page("new_confirm","Nouvelle course ?","La course en cours sera remplacée.")
		button(content,"Annuler",show_layouts)
		button(content,"Commencer",game.start_endurance)
	else: game.start_endurance()

func show_layouts() -> void:
	page("layouts","Nouvelle partie","Dix jours en atelier ou douze heures en course.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	content.add_child(row)
	for index in game.workshop.Map.LAYOUT_ORDER:
		var layout: Array = game.workshop.Map.LAYOUTS[index]
		add_game_card(row,GARAGE_IMAGES[index],layout[0],layout[1],select_workshop.bind(index))
	add_game_card(row,ENDURANCE,"Course de 12 h","Deux GT · Arrêts aux stands",select_endurance)
	button(content,"Retour",show_home)

func add_game_card(row: HBoxContainer,art: Texture2D,title: String,description: String,action: Callable) -> void:
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	card.add_child(picture(art,120,180))
	button(card,title,action)
	card.add_child(label(description,16,MINT))

func show_options(origin: String) -> void:
	options_origin = origin
	page("options","Options","Affichage et commandes")
	content.add_child(label("Qualité graphique",20))
	quality_button = OptionButton.new()
	for name in QUALITY_NAMES: quality_button.add_item(name)
	quality_button.select(QUALITY_IDS.find(game.display_quality))
	quality_button.item_selected.connect(func(_index: int) -> void: update_options())
	content.add_child(quality_button)
	focus_control.call_deferred(quality_button.get_instance_id())
	quality_details = label(QUALITY_DETAILS[quality_button.selected],16,MINT)
	content.add_child(quality_details)
	fps_check = CheckButton.new()
	fps_check.text = "Afficher les images par seconde"
	fps_check.button_pressed = game.display_fps
	fps_check.toggled.connect(func(_enabled: bool) -> void: update_options())
	content.add_child(fps_check)
	content.add_child(label("Commandes",24))
	content.add_child(label("Marcher : WASD / flèches · Stick gauche     |     Viser : IJKL · Stick droit\nInteragir / réparer : F · A     |     Prendre / poser : E · Y\nPivoter / vider le chariot / freiner : R · X     |     Annuler : Q · B\nZoom : − / = · LB / RB     |     Nouvelle partie : F9 · View\nConduire : W / S et A / D · Stick gauche ↑↓ et stick droit ←→\nPause / reprendre : Échap · Start",16,MINT))
	button(content,"Retour",go_back)
	# Keep the first setting focused rather than the return button.
	focus_control.call_deferred(quality_button.get_instance_id())

func update_options() -> void:
	quality_details.text = QUALITY_DETAILS[quality_button.selected]
	game.change_display(QUALITY_IDS[quality_button.selected],fps_check.button_pressed)

func show_multiplayer() -> void:
	page("multiplayer","Multijoueur","Jouez à deux dans le navigateur.")
	content.add_child(label("Crée une partie ou rejoins un ami avec son lien d’invitation. L’hôte garde son navigateur ouvert.\nLa progression multijoueur reste sauvegardée dans le navigateur de l’hôte ; ta partie locale est conservée.",20,MINT))
	button(content,"Ouvrir le multijoueur Web",func() -> void:
		if OS.shell_open("https://jfeffe.github.io/GarageDay/#multiplayer")!=OK:
			show_message("Le navigateur n’a pas pu être ouvert."))
	button(content,"Retour",show_home)

func show_notes() -> void:
	page("notes","Notes de mise à jour","0.1.13 · Classement de l’invité")
	content.add_child(label("Le navigateur de l’invité affiche le classement des 12 h en texte net, y compris pendant la préparation d’un arrêt.",20,MINT))
	button(content,"Retour",show_home)

func show_message(message: String) -> void:
	if is_instance_valid(notice): notice.text = message

func quit_game() -> void:
	game.store_checkpoint()
	get_tree().quit()

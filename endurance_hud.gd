extends CanvasLayer

const Race := preload("res://endurance_race.gd")
const Crew := preload("res://endurance_crew.gd")
const HudStyle := preload("res://garage_hud_style.gd")
const CREAM := Color("#fff3d9")
const MINT := Color("#b4d8cd")
const GOLD := Color("#ffd99a")
const BLUE := Color("#9be3ff")
const BRIEFING := "Au banc de contrôle, prépare les arrêts et donne le feu vert aux deux GT. Sur le terrain, prends en charge la pompe, les crics et les réparations.\n\nStick gauche / WASD pour marcher · stick droit / IJKL pour viser · A / F à maintenir pour interagir."
const BUTTONS := {
	Race.State.TRACK: ["plan", "delay", "pace"],
	Race.State.ENTRY: ["plan", "", ""],
	Race.State.QUEUE: ["plan", "", ""],
	Race.State.BOX: ["plan", "", "exit"],
	Race.State.GARAGE: ["plan", "", "exit"],
}
const MODES := ["Ignorer", "Joueur", "Auto · plus lent"]

class Circuit extends Control:
	const POINTS := [Vector2(0.12,0.69),Vector2(0.23,0.81),Vector2(0.63,0.81),Vector2(0.82,0.64),
		Vector2(0.88,0.43),Vector2(0.73,0.21),Vector2(0.57,0.23),Vector2(0.47,0.41),
		Vector2(0.31,0.38),Vector2(0.24,0.17),Vector2(0.12,0.29),Vector2(0.10,0.50)]
	var race: RefCounted
	var route := Curve2D.new()

	func _ready() -> void:
		for p in POINTS: route.add_point(p*Vector2(200,100))
		route.add_point(POINTS[0]*Vector2(200,100))
		resized.connect(queue_redraw)

	func _draw() -> void:
		var scale_to_size := size/Vector2(200,100)
		var path := PackedVector2Array()
		for p in POINTS: path.append(p*size)
		path.append(path[0])
		draw_polyline(path,Color("#567270"),7,true)
		draw_polyline(path,Color("#162a2d"),4,true)
		var entry := PackedVector2Array([Vector2(0.23,0.81)*size,Vector2(0.28,0.91)*size,
			Vector2(0.58,0.91)*size,Vector2(0.63,0.81)*size])
		draw_polyline(entry,Color("#9d7851"),2,true)
		if race==null: return
		var distance := route.get_baked_length()
		for i in range(race.cars.size()-1,-1,-1):
			var car: Dictionary = race.cars[i]
			if car.state==Race.State.OUT: continue
			var point := route.sample_baked(fposmod(car.distance,1.0)*distance)*scale_to_size
			if car.state!=Race.State.TRACK:
				point = Vector2(0.30+0.034*i,0.91)*size
			draw_circle(point,5.5 if car.ours else 3.8,Color("#182b2e"),true,-1,true)
			draw_circle(point,4.0 if car.ours else 2.5,car.color,true,-1,true)

var race: Race
var crew: Crew
var start_button: Button
var speed_button: Button
var standings_button: Button
var headline: RichTextLabel
var footer: RichTextLabel
var left_panel: PanelContainer
var footer_panel: PanelContainer
var standings_rows: VBoxContainer
var circuit: Circuit
var scores: Array[Label] = []
var team_status: RichTextLabel
var control_panel: PanelContainer
var control_owner := -1
var selected_car := 0
var control_heading: Label
var car_tabs: Array[Button] = []
var service_details: Label
var service_status: Label
var service_buttons: Array[Button] = []
var leave_button: Button
var briefing: PanelContainer
var briefing_title: Label
var briefing_copy: Label
var restart_button: Button
var exit_button: Button
var guest_online := false
var guest_axis := 0
var planner: PanelContainer
var planner_title: Label
var planner_feedback: Label
var planner_rows: Array[Button] = []
var planner_index := 0
var guest_pick: Button
var guest_cursor := StyleBoxFlat.new()
var draft: Dictionary = {}
var send_to_garage := false

signal restart_requested
signal exit_requested

func build(session: Race, mechanics: Crew) -> void:
	race = session
	crew = mechanics
	layer = 4
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.theme = make_theme()
	add_child(layout)

	left_panel = anchored_panel(layout,Vector4(0,0,0,0),Vector4(14,70,249,70))
	var left_content := column(left_panel)
	headline = HudStyle.rich_label()
	left_content.add_child(headline)
	circuit = Circuit.new()
	circuit.custom_minimum_size = Vector2(0,62)
	circuit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	circuit.race = race
	circuit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_content.add_child(circuit)
	team_status = HudStyle.rich_label()
	left_content.add_child(team_status)
	var commands := HBoxContainer.new()
	commands.add_theme_constant_override("separation",6)
	left_content.add_child(commands)
	speed_button = button(commands,"",func() -> void:
		race.speed_up = not race.speed_up
		refresh()
		release_focus())
	standings_button = button(commands,"Classement",toggle_standings)
	standings_rows = column(left_content)
	for i in race.cars.size():
		var row := text("",14)
		standings_rows.add_child(row)
		scores.append(row)
	standings_rows.hide()

	footer_panel = anchored_panel(layout,Vector4(0.5,1,0.5,1),Vector4(-270,-10,270,-10))
	footer_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer = HudStyle.rich_label()
	footer_panel.add_child(footer)
	footer_panel.minimum_size_changed.connect(fit_bottom.bind(footer_panel,10.0))
	layout.resized.connect(resize_hud.bind(layout))
	resize_hud(layout)

	briefing = anchored_panel(layout,Vector4(0.5,0.5,0.5,0.5),Vector4(-234,-154,234,0))
	var brief := column(briefing)
	brief.add_theme_constant_override("separation",9)
	briefing_title = text("Les 12 h de Garage Day",25)
	brief.add_child(briefing_title)
	briefing_copy = text(BRIEFING,17,MINT)
	briefing_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.add_child(briefing_copy)
	start_button = button(brief,"Donner le départ",func() -> void:
		race.start()
		refresh()
		focus_first())
	restart_button = button(brief,"Nouvelle course",func() -> void: restart_requested.emit())
	exit_button = button(brief,"Retour à l’accueil",func() -> void: exit_requested.emit())
	build_control(layout)
	build_planner(layout)
	guest_cursor.bg_color = Color("#285353")
	guest_cursor.border_color = BLUE
	guest_cursor.set_border_width_all(2)
	guest_cursor.set_corner_radius_all(6)
	refresh()

func resize_hud(layout: Control) -> void:
	var half_width := minf(540.0,maxf(260.0,layout.size.x-20.0))/2.0
	footer_panel.offset_left = -half_width
	footer_panel.offset_right = half_width

func toggle_standings() -> void:
	standings_rows.visible = not standings_rows.visible
	standings_button.text = "Masquer" if standings_rows.visible else "Classement"
	left_panel.size.y = 0.0
	release_focus()

func desk_panel(layout: Control) -> PanelContainer:
	var desk := anchored_panel(layout,Vector4(0,1,0,1),Vector4(14,-12,336,-12))
	desk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	desk.minimum_size_changed.connect(fit_bottom.bind(desk,12.0))
	desk.hide()
	return desk

func fit_bottom(control: Control, inset: float) -> void:
	control.offset_top = -inset-control.get_combined_minimum_size().y
	control.offset_bottom = -inset

func build_control(layout: Control) -> void:
	control_panel = desk_panel(layout)
	var body := column(control_panel)
	control_heading = text("Contrôle course",22,GOLD)
	body.add_child(control_heading)
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	for i in range(2):
		var tab := button(tabs,"N° %d" % race.cars[i].number,select_car.bind(i))
		tab.add_theme_color_override("font_color",race.cars[i].color)
		car_tabs.append(tab)
	service_details = text("",14)
	body.add_child(service_details)
	service_status = text("",14,MINT)
	service_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(service_status)
	for i in range(3): service_buttons.append(button(body,"",activate.bind(i)))
	leave_button = button(body,"Quitter le contrôle",close_control)

func build_planner(layout: Control) -> void:
	planner = desk_panel(layout)
	var body := column(planner)
	planner_title = text("",22,GOLD)
	body.add_child(planner_title)
	for action in Race.SERVICES:
		planner_rows.append(button(body,"",cycle_mode.bind(action)))
	planner_rows.append(button(body,"",func() -> void:
		send_to_garage = not send_to_garage
		refresh_plan()))
	planner_rows.append(button(body,"Confirmer l’arrêt",confirm_plan))
	planner_rows.append(button(body,"Retour au contrôle",close_plan))
	planner_feedback = text("",14,MINT)
	planner_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(planner_feedback)
	planner.hide()

func open_control(worker_index: int) -> void:
	if not visible or control_owner>=0 or race.phase!=Race.Phase.RACE or not crew.at_control(worker_index): return
	control_owner = worker_index
	selected_car = worker_index
	crew.workers[worker_index].velocity = Vector2.ZERO
	var inputs := car_tabs+service_buttons+planner_rows+[leave_button]
	for control: Button in inputs:
		control.focus_mode = Control.FOCUS_ALL if worker_index==0 else Control.FOCUS_NONE
		control.mouse_filter = Control.MOUSE_FILTER_STOP if worker_index==0 else Control.MOUSE_FILTER_IGNORE
	release_focus()
	control_panel.show()
	refresh()
	focus_control_action()

func control_active() -> bool:
	return visible and control_owner>=0 and race.phase==Race.Phase.RACE and crew.at_control(control_owner)

func select_car(index: int) -> void:
	if not control_active(): return
	selected_car = index
	refresh()

func open_plan(index: int) -> void:
	if not control_active() or planner.visible or not race.allowed(race.cars[index],"plan"): return
	planner_index = index
	var car: Dictionary = race.cars[index]
	draft = race.recommended_orders(car)
	send_to_garage = car.garage_stop or car.state==Race.State.GARAGE or car.damage>=0.38
	planner_feedback.text = "Stick / flèches pour choisir · A / F pour valider" if control_owner==1 else "A / F pour modifier ou valider"
	control_panel.hide()
	planner.show()
	refresh_plan()
	for row in planner_rows:
		if not row.disabled:
			focus_operator(row)
			break

func cycle_mode(action: String) -> void:
	draft[action] = (int(draft.get(action,Race.Mode.SKIP))+1)%MODES.size()
	refresh_plan()

func refresh_plan() -> void:
	var car: Dictionary = race.cars[planner_index]
	planner_title.text = "Plan d’arrêt · n° %d" % car.number
	for i in range(Race.SERVICES.size()):
		var action: String = Race.SERVICES[i]
		planner_rows[i].disabled = car.done.has(action)
		planner_rows[i].text = "%s · %s" % [Race.action_label(action),"Terminé" if car.done.has(action) else MODES[draft.get(action,Race.Mode.SKIP)]]
	planner_rows[4].disabled = car.state==Race.State.GARAGE
	planner_rows[4].text = "Destination · Garage" if send_to_garage else "Destination · Box extérieur"
	planner_rows[5].disabled = not race.allowed(car,"plan")

func confirm_plan() -> void:
	if not control_active(): return
	if race.confirm_stop(planner_index,draft,send_to_garage):
		close_plan()
		refresh()
	else:
		planner_feedback.text = "La voiture est en intervention. Réessaie quand le travail est terminé."

func close_plan() -> void:
	planner.hide()
	if control_active():
		control_panel.show()
		refresh()
		focus_control_action()

func close_control() -> void:
	planner.hide()
	control_panel.hide()
	control_owner = -1
	guest_axis = 0
	set_guest_cursor(null)
	release_focus()
	refresh()

func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_stylebox("panel","PanelContainer",HudStyle.panel_style())
	for state in ["normal","hover","pressed","disabled"]:
		var action := StyleBoxFlat.new()
		action.bg_color = Color("#213c43") if state=="normal" else Color("#285353")
		if state=="disabled": action.bg_color = Color("#172c32")
		action.border_color = Color("#46666b") if state=="normal" else Color("#4d756f")
		action.set_border_width_all(1)
		action.set_corner_radius_all(6)
		action.content_margin_left = 4
		action.content_margin_right = 4
		theme.set_stylebox(state,"Button",action)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(4)
	focus.set_border_width_all(2)
	focus.border_color = GOLD
	theme.set_stylebox("focus","Button",focus)
	theme.set_color("font_color","Button",CREAM)
	theme.set_color("font_disabled_color","Button",Color("#8da09e"))
	return theme

func anchor(control: Control, edges: Vector4, offsets: Vector4) -> void:
	control.anchor_left = edges.x
	control.anchor_top = edges.y
	control.anchor_right = edges.z
	control.anchor_bottom = edges.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w

func panel(parent: Control) -> PanelContainer:
	var control := PanelContainer.new()
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control

func anchored_panel(parent: Control, edges: Vector4, offsets: Vector4) -> PanelContainer:
	var control := panel(parent)
	anchor(control,edges,offsets)
	return control

func column(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation",4)
	parent.add_child(box)
	return box

func text(value: String, font_size: int, color := CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func button(parent: Control, title: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = title
	control.custom_minimum_size.y = 30
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func options_for(car: Dictionary) -> Array:
	return BUTTONS.get(car.state,["", "", ""])

func activate(slot: int) -> void:
	if not control_active() or planner.visible: return
	var index := selected_car
	var action: String = options_for(race.cars[index])[slot]
	if action=="plan":
		open_plan(index)
		return
	if action=="exit" and not crew.stands.release_available(race,index): return
	if action!="" and race.perform(index,action):
		crew.stands.update_control_lights(race)
		refresh()
		if not service_buttons[slot].visible or service_buttons[slot].disabled: focus_control_action()

func refresh() -> void:
	var on_grid: bool = race.phase==Race.Phase.GRID
	var finished: bool = race.phase==Race.Phase.FINISH
	if control_owner>=0 and (finished or not crew.at_control(control_owner)):
		close_control()
		return
	left_panel.visible = control_owner<0
	var left: float = Race.DURATION-race.elapsed
	var rate: float = Race.PIT_RATE if control_owner>=0 else race.rate()
	var left_text := "%d h %02d restantes  ·  ×%d" % [floori(left/3600.0),floori(left/60.0)%60,roundi(rate)]
	var clock_text: String = "Sur la grille" if on_grid else "Drapeau à damier" if finished else race.clock()
	set_rich_text(headline,"[color=#b4d8cd]GARAGE DAY  /  LES 12 H[/color]\n[b][font_size=21]%s[/font_size][/b]\n[color=#b6cbca]%s[/color]" % [clock_text,left_text])
	speed_button.disabled = on_grid or finished
	speed_button.text = "En piste ×48" if race.speed_up else "En piste ×24"
	speed_button.tooltip_text = "Accélérer ou ralentir le temps en piste. Les arrêts ralentissent l’horloge."
	circuit.queue_redraw()
	var standings: Array[Dictionary] = race.classification()
	for i in standings.size():
		var car := standings[i]
		var suffix := "%d t." % maxi(0,floori(car.distance))
		if car.state==Race.State.OUT: suffix = "Ab."
		elif i>0 and not finished and not on_grid:
			var gap: float = standings[0].distance-car.distance
			suffix = "+%d t." % floori(gap) if gap>=1.0 else "+%d s" % roundi(gap*standings[0].base_lap)
		scores[i].text = "%2d   %02d  %s  ·  %s" % [i+1,car.number,car.team,suffix]
		scores[i].add_theme_color_override("font_color",car.color if car.ours else CREAM)
	var team := PackedStringArray()
	for i in range(2):
		var car := race.cars[i]
		team.append("[b][color=#%s]N° %d[/color][/b]  P%d  ·  %s" % [
			car.color.to_html(false),car.number,standings.find(car)+1,short_status(i)])
	set_rich_text(team_status,"\n".join(team))
	if control_panel.visible: refresh_control()
	if planner.visible: refresh_plan()
	refresh_footer(on_grid or finished)
	briefing.visible = on_grid or finished
	start_button.visible = on_grid
	restart_button.visible = finished
	exit_button.visible = finished
	briefing_title.text = "Drapeau à damier" if finished else "Les 12 h de Garage Day"
	if on_grid: briefing_copy.text = BRIEFING
	if finished:
		var results := PackedStringArray()
		for car in race.cars.slice(0,2):
			var result := "abandon" if car.state==Race.State.OUT else "P%d" % (standings.find(car)+1)
			results.append("N° %d · %s · %d tours · %d arrêts" % [car.number,result,maxi(0,floori(car.distance)),car.stops])
		briefing_copy.text = "\n".join(results)

func refresh_footer(brief: bool) -> void:
	footer_panel.visible = not brief and (control_owner!=0 or guest_online)
	if not footer_panel.visible: return
	var lines := PackedStringArray()
	if control_owner!=0:
		lines.append("[color=#ffd99a]%s[/color]" % crew.instruction(0))
	if guest_online and control_owner!=1:
		lines.append("[color=#9be3ff]J2 · %s[/color]" % crew.instruction(1))
	if not race.radio.is_empty():
		lines.append("[color=#bacdca][font_size=13]%s[/font_size][/color]" % race.radio[0])
	set_rich_text(footer,"[center]%s[/center]" % "\n".join(lines))

func set_rich_text(label: RichTextLabel, content: String) -> void:
	if label.text!=content: label.text = content

func refresh_control() -> void:
	var car := race.cars[selected_car]
	var driver: String = car.drivers[car.driver]
	var alternate: String = car.drivers[1-car.driver]
	control_heading.text = "Contrôle course · J2" if control_owner==1 else "Contrôle course"
	for i in range(2):
		car_tabs[i].text = "%sN° %d" % ["●  " if i==selected_car else "",race.cars[i].number]
	service_details.text = "%s · fatigue %d %%\nRelève · %s\nEss. %d %%   Pneus %d %%   Dégâts %d %%" % [
		driver,clampi(roundi(car.fatigue[car.driver]/36.0),0,100),alternate,
		roundi(car.fuel*100),roundi(car.tires*100),roundi(car.damage*100)]
	var green := crew.stands.release_available(race,selected_car)
	service_status.text = describe(car)
	service_status.add_theme_color_override("font_color",Color("#a4e9b7") if green else MINT)
	var actions := options_for(car)
	for i in range(3):
		var action: String = actions[i]
		var control := service_buttons[i]
		control.visible = action!=""
		control.disabled = not (green if action=="exit" else race.allowed(car,action))
		var title := Race.action_label(action)
		if action=="pace": title = "Rythme · "+Race.PACE_NAMES[car.pace]
		if action=="plan" and car.called: title = "Modifier l’arrêt" if not car.orders.is_empty() else "Confirmer l’arrêt"
		if action=="exit": title = "Feu vert · reprendre la piste"
		control.text = title
		control.add_theme_color_override("font_color",Color("#a4e9b7") if action=="exit" else CREAM)

func short_status(index: int) -> String:
	var car := race.cars[index]
	match car.state:
		Race.State.TRACK: return "Appelée" if car.called else "En piste"
		Race.State.ENTRY: return "Entrée"
		Race.State.QUEUE: return "En attente"
		Race.State.BOX, Race.State.GARAGE:
			if crew.stands.release_available(race,index): return "Feu vert attendu"
			return "Au garage" if car.state==Race.State.GARAGE else "Au box"
		Race.State.EXIT: return "Sortie"
		Race.State.OUT: return "Abandon"
	return ""

func describe(car: Dictionary) -> String:
	if race.phase==Race.Phase.GRID: return "Sur la grille · deux pilotes par voiture"
	if race.phase==Race.Phase.FINISH: return "Classement final · %d tours" % maxi(0,floori(car.distance))
	if not car.jobs.is_empty():
		var working := PackedStringArray()
		for action in car.jobs:
			working.append("%s %s" % [Race.action_label(action),Race.time_left(car.jobs[action].left)])
		return " · ".join(working)
	match car.state:
		Race.State.TRACK:
			if car.called: return "Entrée à la fin du tour · "+("plan à confirmer" if car.orders.is_empty() else "garage" if car.garage_stop else "box")
			var alert := "Accrochage · " if car.damage>=0.15 else "Réserve d’essence · " if car.fuel<0.16 else "En piste · "
			return alert+"arrêt prévu dans %s" % Race.time_left(car.planned-race.elapsed)
		Race.State.ENTRY: return "Entrée des stands · "+Race.time_left(car.timer)
		Race.State.QUEUE: return "En attente · "+("garage occupé" if car.garage_stop else "box occupé")
		Race.State.BOX, Race.State.GARAGE:
			var location := "Au garage" if car.state==Race.State.GARAGE else "Au box"
			if car.orders.is_empty(): return location+" · confirme le plan d’arrêt"
			var pending := race.pending_orders(car)
			var needs := PackedStringArray()
			for action in pending:
				needs.append(Race.action_label(action)+( " (joueur)" if car.orders[action]==Race.Mode.MANUAL else " (auto)"))
			if car.fuel<0.055 and not pending.has("fuel"):
				return location+" · ajoute du carburant au plan"
			if not needs.is_empty(): return location+" · "+", ".join(needs)
			var index := race.cars.find(car)
			return location+" · "+("en attente du feu vert" if crew.stands.release_available(race,index) else "mise en place")
		Race.State.EXIT: return "Sortie des stands · "+Race.time_left(car.timer)
		Race.State.OUT: return "Abandon · panne d’essence"
	return ""

func focus_first() -> void:
	if not visible: return
	if start_button.is_visible_in_tree(): start_button.grab_focus()
	elif restart_button.is_visible_in_tree(): restart_button.grab_focus()
	elif control_owner==0 and planner.visible:
		focus_operator(planner_rows[5] if not planner_rows[5].disabled else planner_rows[6])
	elif control_owner==0: focus_control_action()
	else: release_focus()

func focus_control_action() -> void:
	for slot in [2,0]:
		var action := service_buttons[slot]
		if action.visible and not action.disabled and (slot==0 or options_for(race.cars[selected_car])[slot]=="exit"):
			focus_operator(action)
			return
	focus_operator(leave_button)

func focus_operator(control: Button) -> void:
	if control_owner==1: set_guest_cursor(control)
	elif control_owner==0: control.grab_focus()

func set_guest_cursor(control: Button) -> void:
	if guest_pick!=null: guest_pick.remove_theme_stylebox_override("normal")
	guest_pick = control
	if guest_pick!=null: guest_pick.add_theme_stylebox_override("normal",guest_cursor)

func release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused!=null and is_ancestor_of(focused): focused.release_focus()

func field_input() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return visible and race.phase==Race.Phase.RACE and control_owner!=0 and (focused==null or not is_ancestor_of(focused))

func _input(event: InputEvent) -> void:
	if not visible or race==null or race.phase!=Race.Phase.RACE or event.is_echo() or control_owner==1: return
	var toggle: bool = (event is InputEventKey and event.pressed and event.keycode==KEY_TAB) or \
		(event is InputEventJoypadButton and event.is_action_pressed("take"))
	if toggle:
		get_viewport().set_input_as_handled()
		if control_owner==0: close_control()
		else: open_control(0)
	elif control_owner==0 and event.is_action_pressed("cancel_item"):
		get_viewport().set_input_as_handled()
		if planner.visible: close_plan()
		else: close_control()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.is_action_pressed("use_item") or event.is_echo(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Button and is_ancestor_of(focus) and not focus.disabled:
		get_viewport().set_input_as_handled()
		focus.pressed.emit()

func guest_input(input: Array) -> bool:
	guest_online = input.size()==9 and input[0]==true
	if not guest_online or race.phase!=Race.Phase.RACE:
		if control_owner==1: close_control()
		return false
	var pressed := int(input[8])
	if (pressed & 2)!=0:
		if control_owner==1: close_control()
		else: open_control(1)
		return control_owner!=1
	if control_owner!=1: return true
	if (pressed & 8)!=0:
		if planner.visible: close_plan()
		else: close_control()
		return false
	var y := float(input[2])
	var x := float(input[1])
	var axis := y if absf(y)>absf(x) else x
	var direction := int(signf(axis)) if absf(axis)>0.55 else 0
	if direction!=0 and guest_axis==0:
		var rows: Array = planner_rows if planner.visible else car_tabs+service_buttons+[leave_button]
		var current := rows.find(guest_pick)
		for offset in range(1,rows.size()+1):
			var next: Button = rows[posmod(current+direction*offset,rows.size())]
			if next.visible and not next.disabled:
				set_guest_cursor(next)
				break
	if (pressed & 4)!=0 and guest_pick!=null and guest_pick.is_visible_in_tree() and not guest_pick.disabled:
		guest_pick.pressed.emit()
	guest_axis = direction
	return false

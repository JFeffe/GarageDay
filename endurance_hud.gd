extends CanvasLayer

const Race := preload("res://endurance_race.gd")
const Circuit := preload("res://endurance_circuit.gd")
const Crew := preload("res://endurance_crew.gd")
const HudStyle := preload("res://garage_hud_style.gd")
const CREAM := Color("#fff3d9")
const MINT := Color("#b4d8cd")
const GOLD := Color("#ffd99a")
const BLUE := Color("#9be3ff")
const BRIEFING := "Prépare les arrêts au poste à gauche de la porte du garage. Maintiens A / F pour utiliser le poste ou les outils.\n\nStick gauche / WASD pour marcher · stick droit / IJKL pour viser.\nLT / RT ou [ / ] pour régler la vitesse en piste."
const BUTTONS := {
	Race.State.TRACK: ["plan", "delay", "pace"],
	Race.State.ENTRY: ["plan", "", ""],
	Race.State.QUEUE: ["plan", "", ""],
	Race.State.BOX: ["plan", "", "exit"],
	Race.State.GARAGE: ["plan", "", "exit"],
}
const MODES := ["Ignorer", "Joueur", "Auto · plus lent"]
const MENU_DIRECTIONS := {"ui_left":Vector2i.LEFT,"ui_right":Vector2i.RIGHT,"ui_up":Vector2i.UP,"ui_down":Vector2i.DOWN}


class ActionFeedback extends Control:
	var amount := 0.0
	var outcome := ""
	var accent := Color.WHITE

	func _draw() -> void:
		if outcome!="":
			var color := Color("#83e9af") if outcome=="✓" else Color("#ffaa87")
			draw_circle(Vector2(34,8),11,Color("#172b31"),true,-1.0,true)
			if outcome=="✓":
				draw_polyline(PackedVector2Array([Vector2(28,8),Vector2(32,12),Vector2(40,4)]),color,2.5,true)
			else:
				draw_line(Vector2(29,3),Vector2(39,13),color,2.5,true)
				draw_line(Vector2(39,3),Vector2(29,13),color,2.5,true)
			return
		draw_line(Vector2(5,8),Vector2(63,8),Color("#162b31"),12,true)
		draw_line(Vector2(7,8),Vector2(61,8),Color("#617777"),6,true)
		draw_line(Vector2(7,8),Vector2(7+54*amount,8),accent,6,true)

var race: Race
var crew: Crew
var start_button: Button
var speed_buttons: Array[Button] = []
var speed_target: Label
var standings_button: Button
var clock_panel: PanelContainer
var clock_label: RichTextLabel
var headline: RichTextLabel
var footer: RichTextLabel
var left_panel: PanelContainer
var footer_panel: PanelContainer
var standings_rows: VBoxContainer
var circuit: Circuit
var scores: Array[Label] = []
var live_circuit: Circuit
var control_table: VBoxContainer
var control_scores: Array[Label] = []
var control_ranking: Array[Dictionary] = []
var team_status: RichTextLabel
var control_panel: PanelContainer
var control_owner: int:
	get: return crew.control_owner
	set(value): crew.control_owner = value
var selected_car := 0
var control_heading: Label
var car_tabs: Array[Button] = []
var service_details: Array[Label] = []
var service_status: Array[Label] = []
var console_actions: VBoxContainer
var service_buttons: Array[Button] = []
var leave_button: Button
var briefing: PanelContainer
var briefing_title: Label
var briefing_copy: Label
var restart_button: Button
var exit_button: Button
var guest_online := false
var guest_direction := Vector2i.ZERO
var stick_motion := Vector2.ZERO
var stick_direction := Vector2i.ZERO
var triggers := [false,false]
var feedback: Array[ActionFeedback] = []
var planner: VBoxContainer
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

	clock_panel = anchored_panel(layout,Vector4(0,0,0,0),Vector4(126,12,481,12))
	clock_label = HudStyle.rich_label()
	clock_panel.add_child(clock_label)
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
	left_content.add_child(commands)
	speed_buttons.append(button(commands,"−",change_speed.bind(-1)))
	speed_target = text("",13,MINT)
	speed_target.custom_minimum_size.x = 108
	speed_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_target.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	commands.add_child(speed_target)
	speed_buttons.append(button(commands,"+",change_speed.bind(1)))
	speed_buttons[0].tooltip_text = "Ralentir en piste · LT / ["
	speed_buttons[1].tooltip_text = "Accélérer en piste · RT / ]"
	standings_button = button(left_content,"Classement",toggle_standings)
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
	for i in range(2):
		var meter := ActionFeedback.new()
		meter.accent = GOLD if i==0 else BLUE
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.hide()
		layout.add_child(meter)
		feedback.append(meter)
	guest_cursor.bg_color = Color("#285353")
	guest_cursor.border_color = BLUE
	guest_cursor.set_border_width_all(2)
	guest_cursor.set_corner_radius_all(6)
	visibility_changed.connect(reset_motion)
	refresh()

func reset_motion() -> void:
	triggers = [false,false]
	stick_motion = Vector2.ZERO
	stick_direction = Vector2i.ZERO
	guest_direction = Vector2i.ZERO

func resize_hud(layout: Control) -> void:
	var half_width := minf(540.0,maxf(260.0,layout.size.x-20.0))/2.0
	var shift := maxf(0.0,control_panel.get_rect().end.x+12.0-(layout.size.x/2.0-half_width)) \
		if control_panel!=null and control_panel.visible else 0.0
	footer_panel.offset_left = -half_width+shift
	footer_panel.offset_right = minf(half_width+shift,layout.size.x/2.0-10.0)

func toggle_standings() -> void:
	standings_rows.visible = not standings_rows.visible
	standings_button.text = "Masquer" if standings_rows.visible else "Classement"
	left_panel.size.y = 0.0
	release_focus()

func desk_panel(layout: Control) -> PanelContainer:
	var desk := anchored_panel(layout,Vector4(0,1,0,1),Vector4(14,-12,464,-12))
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
	build_race_monitor(body)
	var cars := HBoxContainer.new()
	cars.add_theme_constant_override("separation",8)
	body.add_child(cars)
	var tile := HudStyle.panel_style()
	tile.bg_color = Color("#20383c")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: tile.set_content_margin(side,7)
	for i in range(2):
		var card := panel(cars)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",tile)
		var card_body := column(card)
		var tab := button(card_body,"",select_car.bind(i,true))
		tab.add_theme_color_override("font_color",race.cars[i].color)
		car_tabs.append(tab)
		var details := text("",13)
		card_body.add_child(details)
		service_details.append(details)
		var status := text("",13,MINT)
		status.custom_minimum_size.y = 48
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.max_lines_visible = 2
		card_body.add_child(status)
		service_status.append(status)
	console_actions = column(body)
	for i in range(3): service_buttons.append(button(console_actions,"",activate.bind(i)))
	leave_button = button(console_actions,"Quitter le contrôle  ·  B / Q",close_control)
	build_planner(body)

func build_race_monitor(body: VBoxContainer) -> void:
	var monitor := HBoxContainer.new()
	monitor.add_theme_constant_override("separation",12)
	body.add_child(monitor)
	var screen := column(monitor)
	screen.add_child(text("Course en direct",14,MINT))
	live_circuit = Circuit.new()
	live_circuit.custom_minimum_size = Vector2(174,96)
	live_circuit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_circuit.race = race
	live_circuit.live = true
	live_circuit.animate = true
	screen.add_child(live_circuit)
	control_table = column(monitor)
	control_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_table.add_child(text("Classement",14,MINT))
	var ranks := HBoxContainer.new()
	ranks.add_theme_constant_override("separation",8)
	control_table.add_child(ranks)
	var rows_per_column := ceili(race.cars.size()/2.0)
	for start in range(0,race.cars.size(),rows_per_column):
		var group := column(ranks)
		group.add_theme_constant_override("separation",0)
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in range(start,mini(start+rows_per_column,race.cars.size())):
			var row := text("",12)
			row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			group.add_child(row)
			control_scores.append(row)

func build_planner(body: VBoxContainer) -> void:
	planner = column(body)
	planner_title = text("",18,GOLD)
	planner.add_child(planner_title)
	for action in Race.SERVICES:
		planner_rows.append(button(planner,"",cycle_mode.bind(action,1)))
	planner_rows.append(button(planner,"",func() -> void:
		send_to_garage = not send_to_garage
		refresh_plan()))
	planner_rows.append(button(planner,"Confirmer l’arrêt",confirm_plan))
	planner_rows.append(button(planner,"Retour au contrôle  ·  B / Q",close_plan))
	planner_feedback = text("",13,MINT)
	planner_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	planner.add_child(planner_feedback)
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

func select_car(index: int, refocus := false) -> void:
	if not control_active() or planner.visible: return
	selected_car = index
	refresh()
	if refocus: focus_control_action()

func open_plan(index: int) -> void:
	if not control_active() or planner.visible or not race.allowed(race.cars[index],"plan"): return
	planner_index = index
	var car: Dictionary = race.cars[index]
	draft = race.recommended_orders(car)
	send_to_garage = car.garage_stop or car.state==Race.State.GARAGE or car.damage>=0.38
	planner_feedback.text = "Haut/bas pour choisir · Gauche/droite pour régler · A/F pour valider"
	console_actions.hide()
	planner.show()
	refresh()
	for row in planner_rows:
		if not row.disabled:
			focus_operator(row)
			break

func cycle_mode(action: String, step: int) -> void:
	draft[action] = posmod(int(draft.get(action,Race.Mode.SKIP))+step,MODES.size())
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
		planner_feedback.text = "Intervention en cours. Attends la fin des travaux."

func close_plan() -> void:
	planner.hide()
	if control_active():
		console_actions.show()
		refresh()
		focus_control_action()

func close_control() -> void:
	planner.hide()
	console_actions.show()
	control_panel.hide()
	control_owner = -1
	guest_direction = Vector2i.ZERO
	stick_motion = Vector2.ZERO
	stick_direction = Vector2i.ZERO
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

func clock_line() -> String:
	return "%s  ·  Reste %s" % [Race.race_time(race.elapsed),Race.race_time(Race.DURATION-race.elapsed)]

func guest_standings() -> Array:
	if not control_table.is_visible_in_tree(): return []
	var view := get_viewport().get_visible_rect().size
	var table := control_table.get_global_rect()
	if view.x<=0.0 or view.y<=0.0 or table.size.x<=0.0 or table.size.y<=0.0: return []
	var bounds := [
		roundi(10000.0*table.position.x/view.x),roundi(10000.0*table.position.y/view.y),
		roundi(10000.0*table.size.x/view.x),roundi(10000.0*table.size.y/view.y),
	]
	var rows: Array = []
	for car in control_ranking:
		var team_name: String = "Abandon" if car.state==Race.State.OUT else car.team
		rows.append([car.number,team_name,"#"+car.color.to_html(false)])
	return [view.aspect(),bounds,rows]

func change_speed(step: int) -> void:
	race.change_speed(step)
	refresh()
	if control_owner<0: release_focus()

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
	var rate := "  ·  ×%d" % roundi(race.rate(control_owner>=0)) if not (on_grid or finished) else ""
	set_rich_text(clock_label,"[font_size=17][b]%s[/b][/font_size][color=#b4d8cd]%s[/color]" % [clock_line(),rate])
	var clock_text := "Sur la grille" if on_grid else "Drapeau à damier" if finished else "Heure locale  ·  "+race.clock()
	set_rich_text(headline,"[b]LES 12 H DE GARAGE DAY[/b]\n[color=#b4d8cd]%s[/color]" % clock_text)
	speed_buttons[0].disabled = on_grid or finished or race.speed_step==0
	speed_buttons[1].disabled = on_grid or finished or race.speed_step==Race.TRACK_RATES.size()-1
	speed_target.text = "LT  ·  ×%d  ·  RT" % roundi(Race.TRACK_RATES[race.speed_step])
	circuit.queue_redraw()
	var standings: Array[Dictionary] = race.classification()
	if control_panel.visible: control_ranking = standings
	for i in standings.size():
		var car := standings[i]
		var suffix := "%d t." % maxi(0,floori(car.distance))
		if car.state==Race.State.OUT: suffix = "Ab."
		elif i>0 and not finished and not on_grid:
			var gap: float = standings[0].distance-car.distance
			suffix = "+%d t." % floori(gap) if gap>=1.0 else "+%d s" % roundi(gap*standings[0].base_lap)
		scores[i].text = "%2d   %02d  %s  ·  %s" % [i+1,car.number,car.team,suffix]
		scores[i].add_theme_color_override("font_color",car.color if car.ours else CREAM)
		if control_panel.visible:
			var team_name: String = "Abandon" if car.state==Race.State.OUT else car.team
			control_scores[i].text = "%2d  %02d %s" % [i+1,car.number,team_name]
			control_scores[i].add_theme_color_override("font_color",car.color)
	var team := PackedStringArray()
	for i in range(2):
		var car := race.cars[i]
		team.append("[b][color=#%s]N° %d[/color][/b]  P%d  ·  %s" % [
			car.color.to_html(false),car.number,standings.find(car)+1,short_status(i)])
	set_rich_text(team_status,"\n".join(team))
	if control_panel.visible:
		live_circuit.queue_redraw()
		refresh_control(standings)
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
	resize_hud(footer_panel.get_parent())
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

func update_feedback(camera: Camera3D) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	for i in range(feedback.size()):
		var meter := feedback[i]
		var worker := crew.workers[i]
		var amount := crew.progress(i)
		meter.visible = race.phase==Race.Phase.RACE and (i==0 or crew.guest_present) and (amount>0.0 or worker.feedback_left>0.0)
		if not meter.visible: continue
		meter.amount = amount
		meter.outcome = ""
		var point: Vector2
		if amount>0.0:
			point = worker.target.point
		else:
			point = worker.feedback_point
			meter.outcome = "✓" if worker.feedback_ok else "×"
		var at := camera.unproject_position(Vector3(point.x,0.65,point.y))-Vector2(34,30+22*i)
		if at.x<0.0 or at.y<0.0 or at.x+68>viewport_size.x or at.y+22>viewport_size.y:
			meter.hide()
			continue
		var bounds := Rect2(at,Vector2(68,22))
		var side := control_panel if control_panel.visible else left_panel
		if side.visible and bounds.intersects(side.get_rect()): at.x = side.get_rect().end.x+8
		if footer_panel.visible and bounds.intersects(footer_panel.get_rect()): at.y = footer_panel.position.y-24
		meter.position = at
		meter.queue_redraw()

func refresh_control(standings: Array[Dictionary]) -> void:
	var tempo := "  ·  LT / RT ×%d" % roundi(Race.TRACK_RATES[race.speed_step])
	control_heading.text = ("Contrôle course · J2" if control_owner==1 else "Contrôle course")+tempo
	for i in range(2):
		var peer := race.cars[i]
		var driver: String = peer.drivers[peer.driver]
		var alternate: String = peer.drivers[1-peer.driver]
		car_tabs[i].text = "%sN° %d · P%d" % ["●  " if i==selected_car else "",peer.number,standings.find(peer)+1]
		car_tabs[i].disabled = planner.visible
		service_details[i].text = "%s · %d %% fatigue\nRelève · %s\nEss. %d %%   Pneus %d %%\nDégâts %d %%   ·   %d t." % [
			driver,clampi(roundi(peer.fatigue[peer.driver]/36.0),0,100),alternate,
			roundi(peer.fuel*100),roundi(peer.tires*100),roundi(peer.damage*100),maxi(0,floori(peer.distance))]
		service_status[i].text = describe(peer)
		service_status[i].add_theme_color_override("font_color",Color("#a4e9b7") if crew.stands.release_available(race,i) else MINT)
	if planner.visible: return
	var car := race.cars[selected_car]
	var green := crew.stands.release_available(race,selected_car)
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

func axis_direction(axis: Vector2) -> Vector2i:
	if axis.length()<0.55: return Vector2i.ZERO
	return Vector2i(int(signf(axis.x)),0) if absf(axis.x)>absf(axis.y) else Vector2i(0,int(signf(axis.y)))

func navigate_operator(direction: Vector2i) -> void:
	if not control_active() or direction==Vector2i.ZERO: return
	var focused := guest_pick if control_owner==1 else get_viewport().gui_get_focus_owner() as Button
	if direction.x!=0:
		if not planner.visible:
			select_car(0 if direction.x<0 else 1,true)
		else:
			var row := planner_rows.find(focused)
			if row>=0 and row<4 and not planner_rows[row].disabled:
				cycle_mode(Race.SERVICES[row],direction.x)
			elif row==4 and not planner_rows[4].disabled: planner_rows[4].pressed.emit()
		return
	var rows: Array = planner_rows if planner.visible else service_buttons+[leave_button]
	var current := rows.find(focused)
	if current<0: current = -1 if direction.y>0 else 0
	for offset in range(1,rows.size()+1):
		var next: Button = rows[posmod(current+direction.y*offset,rows.size())]
		if next.visible and not next.disabled:
			focus_operator(next)
			return

func _input(event: InputEvent) -> void:
	if not visible or race==null or event.is_echo(): return
	if event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out"):
		get_viewport().set_input_as_handled()
		crew.stands.change_zoom(1 if event.is_action_pressed("zoom_in") else -1)
		return
	if race.phase!=Race.Phase.RACE: return
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			var index := 0 if event.axis==JOY_AXIS_TRIGGER_LEFT else 1
			if not triggers[index] and event.axis_value>=0.55:
				triggers[index] = true
				change_speed(-1 if index==0 else 1)
			elif event.axis_value<0.35: triggers[index] = false
		elif control_owner==0 and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			stick_motion[event.axis] = event.axis_value
			var next := axis_direction(stick_motion)
			if next!=stick_direction: navigate_operator(next)
			stick_direction = next
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.physical_keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
		get_viewport().set_input_as_handled()
		change_speed(-1 if event.physical_keycode==KEY_BRACKETLEFT else 1)
		return
	if control_owner==1: return
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
	elif control_owner==0:
		for action in MENU_DIRECTIONS:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				navigate_operator(MENU_DIRECTIONS[action])
				break

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
	var speed_change := int((pressed & 32)!=0)-int((pressed & 16)!=0)
	if speed_change!=0: change_speed(speed_change)
	if (pressed & 2)!=0:
		if control_owner==1: close_control()
		else: open_control(1)
		return control_owner!=1
	if control_owner!=1: return true
	if (pressed & 8)!=0:
		if planner.visible: close_plan()
		else: close_control()
		return false
	var direction := axis_direction(Vector2(float(input[1]),float(input[2])))
	if direction!=guest_direction: navigate_operator(direction)
	if (pressed & 4)!=0 and guest_pick!=null and guest_pick.is_visible_in_tree() and not guest_pick.disabled:
		guest_pick.pressed.emit()
	guest_direction = direction
	return false

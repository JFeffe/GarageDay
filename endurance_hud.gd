extends CanvasLayer

const Race := preload("res://endurance_race.gd")
const Crew := preload("res://endurance_crew.gd")
const HudStyle := preload("res://garage_hud_style.gd")
const Ring := preload("res://workshop_ring.gd")
const CREAM := Color("#fff3d9")
const MINT := Color("#b4d8cd")
const GOLD := Color("#ffd99a")
const BLUE := Color("#9be3ff")
const BRIEFING := "Prépare les arrêts de tes deux GT. Pour chaque intervention, choisis qui s’en occupe.\n\nStick gauche / WASD pour marcher · stick droit / IJKL pour viser · A / F à maintenir pour travailler."
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

var race: RefCounted
var crew: Crew
var start_button: Button
var speed_button: Button
var standings_button: Button
var headline: RichTextLabel
var footer: RichTextLabel
var left_panel: PanelContainer
var right_panel: PanelContainer
var footer_panel: PanelContainer
var standings_rows: VBoxContainer
var equipment: Label
var circuit: Circuit
var scores: Array[Label] = []
var cards: Array[Dictionary] = []
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
var planner_pick := 0
var planner_for_guest := false
var draft: Dictionary = {}
var send_to_garage := false
var work_rings: Array[Control] = []

signal restart_requested
signal exit_requested

func build(session: RefCounted, mechanics: Crew) -> void:
	race = session
	crew = mechanics
	layer = 4
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.theme = make_theme()
	add_child(layout)

	left_panel = anchored_panel(layout,Vector4(0,0,0,0),Vector4(14,14,308,14))
	var left_content := column(left_panel)
	headline = HudStyle.rich_label()
	left_content.add_child(headline)
	circuit = Circuit.new()
	circuit.custom_minimum_size = Vector2(0,76)
	circuit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	circuit.race = race
	circuit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_content.add_child(circuit)
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

	right_panel = anchored_panel(layout,Vector4(1,0,1,0),Vector4(-373,14,-14,14))
	var right_content := column(right_panel)
	right_content.add_theme_constant_override("separation",8)
	var title := HudStyle.rich_label()
	title.text = "[color=#b4d8cd][b]TABLEAU DE SERVICE[/b][/color]"
	right_content.add_child(title)
	for i in range(2): build_card(right_content,i)
	equipment = text("",15,MINT)
	equipment.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	right_content.add_child(equipment)

	footer_panel = anchored_panel(layout,Vector4(0.5,1,0.5,1),Vector4(-357,-12,357,-12))
	footer_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer = HudStyle.rich_label()
	footer_panel.add_child(footer)
	for i in range(2):
		var ring := Ring.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(ring)
		ring.hide()
		work_rings.append(ring)
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
	build_planner(layout)
	refresh()

func resize_hud(layout: Control) -> void:
	right_panel.offset_left = -14.0-minf(359,layout.size.x*0.41)
	var half_width := minf(714.0,maxf(260.0,layout.size.x-20.0))/2.0
	footer_panel.offset_left = -half_width
	footer_panel.offset_right = half_width

func toggle_standings() -> void:
	standings_rows.visible = not standings_rows.visible
	standings_button.text = "Masquer" if standings_rows.visible else "Classement"
	left_panel.size.y = 0.0
	release_focus()

func build_planner(layout: Control) -> void:
	planner = anchored_panel(layout,Vector4(0.5,0.5,0.5,0.5),Vector4(-232,-210,232,0))
	var body := column(planner)
	planner_title = text("",24,GOLD)
	body.add_child(planner_title)
	for action in Race.SERVICES:
		planner_rows.append(button(body,"",cycle_mode.bind(action)))
	planner_rows.append(button(body,"",func() -> void:
		send_to_garage = not send_to_garage
		refresh_plan()))
	planner_rows.append(button(body,"Confirmer l’arrêt",confirm_plan))
	planner_rows.append(button(body,"Annuler",close_plan))
	planner_feedback = text("",14,MINT)
	planner_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(planner_feedback)
	planner.hide()

func open_plan(index: int, from_guest := false) -> void:
	if planner.visible or not race.allowed(race.cars[index],"plan"): return
	planner_index = index
	planner_for_guest = from_guest
	planner_pick = 0
	var car: Dictionary = race.cars[index]
	draft = race.recommended_orders(car)
	send_to_garage = car.garage_stop or car.state==Race.State.GARAGE or car.damage>=0.38
	planner_feedback.text = "J2 · stick / flèches et A / F" if from_guest else "Choisis les interventions et la destination."
	planner.show()
	refresh_plan()
	planner_rows[0].grab_focus()

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

func confirm_plan() -> void:
	if race.confirm_stop(planner_index,draft,send_to_garage):
		close_plan()
		refresh()
	else:
		planner_feedback.text = "La voiture est en intervention. Réessaie quand le travail est terminé."

func close_plan() -> void:
	planner.hide()
	planner_for_guest = false
	release_focus()

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

func build_card(parent: VBoxContainer,index: int) -> void:
	var body := column(parent)
	var title := text("",17,race.cars[index].color)
	var metrics := text("",15)
	var relief := text("",14,MINT)
	var prompt := text("",15,MINT)
	for label in [title,metrics,relief,prompt]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",5)
	body.add_child(actions)
	var options: Array[Button] = []
	for i in range(3):
		var control := button(actions,"",activate.bind(index,i))
		control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		options.append(control)
	cards.append({"title":title,"metrics":metrics,"relief":relief,"prompt":prompt,"buttons":options})

func options_for(car: Dictionary) -> Array:
	return BUTTONS.get(car.state,["", "", ""])

func activate(index: int, slot: int) -> void:
	if planner.visible: return
	var action: String = options_for(race.cars[index])[slot]
	if action=="plan":
		open_plan(index)
		return
	if action!="" and race.perform(index,action):
		refresh()
		release_focus()

func refresh() -> void:
	var on_grid: bool = race.phase==Race.Phase.GRID
	var finished: bool = race.phase==Race.Phase.FINISH
	var left: float = Race.DURATION-race.elapsed
	var rate: float = Race.PIT_RATE if planner.visible else race.rate()
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
	for i in range(2): refresh_card(i,standings.find(race.cars[i])+1)
	equipment.text = "EN MAIN   "+crew.held_item(0)
	right_panel.size.y = 0.0
	refresh_footer(on_grid or finished)
	briefing.visible = on_grid or finished
	start_button.visible = on_grid
	restart_button.visible = finished
	exit_button.visible = finished
	briefing_title.text = "Drapeau à damier" if finished else "Les 12 h de Garage Day"
	if on_grid: briefing_copy.text = BRIEFING
	if finished and planner.visible: close_plan()
	if finished:
		var results := PackedStringArray()
		for car in race.cars.slice(0,2):
			var result := "abandon" if car.state==Race.State.OUT else "P%d" % (standings.find(car)+1)
			results.append("N° %d · %s · %d tours · %d arrêts" % [car.number,result,maxi(0,floori(car.distance)),car.stops])
		briefing_copy.text = "\n".join(results)

func refresh_footer(brief: bool) -> void:
	var instruction := "Appelle les GT et prépare leurs arrêts." if brief else crew.instruction(0)
	var event: String = "Les deux GT de Garage Day se préparent pour le départ." if race.radio.is_empty() else race.radio[0]
	var guest := "\n[color=#9be3ff]J2 · %s[/color]" % crew.instruction(1) if guest_online and not brief else ""
	set_rich_text(footer,"[center][color=#ffd99a][b]%s[/b][/color]%s\n%s\n[color=#a6bfbd][font_size=12]Tab / Y plan d’arrêt   ·   LB / RB zoom[/font_size][/color][/center]" % [instruction,guest,event])
	# RichTextLabel's minimum height changes when the radio or a crew hint wraps.
	footer_panel.offset_top = -12.0-footer.get_content_height()-24.0
	footer_panel.offset_bottom = -12.0

func set_rich_text(label: RichTextLabel, content: String) -> void:
	if label.text!=content: label.text = content

func update_action_rings(camera: Camera3D) -> void:
	var view := get_viewport().get_visible_rect().size
	for i in range(work_rings.size()):
		var ring = work_rings[i]
		var amount := crew.progress(i)
		if amount<=0.0 or planner.visible or race.phase!=Race.Phase.RACE or (i==1 and not guest_online):
			ring.hide()
			continue
		var point: Vector2 = crew.workers[i].point
		var head := camera.unproject_position(Vector3(point.x,1.6,point.y))
		var at := head-Vector2(0,79)
		if at.y<92.0: at = head+Vector2(135 if head.x<view.x/2.0 else -135,5)
		at = at.clamp(Vector2(135,115),Vector2(maxf(135,view.x-135),maxf(115,view.y-125)))
		ring.update_progress(amount,crew.workers[i].target.title,GOLD if i==0 else BLUE)
		var bounds: Rect2 = ring.content_rect()
		if Rect2(at+bounds.position,bounds.size).intersects(right_panel.get_rect()):
			at.x = maxf(-bounds.position.x,right_panel.position.x-bounds.end.x-8)
		if Rect2(at+bounds.position,bounds.size).intersects(left_panel.get_rect()):
			at.x = minf(view.x-bounds.end.x,left_panel.get_rect().end.x-bounds.position.x+8)
		ring.position = at
		ring.show()

func refresh_card(index: int, position: int) -> void:
	var car: Dictionary = race.cars[index]
	var card := cards[index]
	var driver: String = car.drivers[car.driver]
	var alternate: String = car.drivers[1-car.driver]
	card.title.text = "N° %d · P%d · %s" % [car.number,position,driver]
	card.metrics.text = "Essence %d %%    Pneus %d %%    Dégâts %d %%" % [
		roundi(car.fuel*100),roundi(car.tires*100),roundi(car.damage*100)]
	card.relief.text = "Relève · %s     Fatigue · %d %%" % [alternate,clampi(roundi(car.fatigue[car.driver]/36.0),0,100)]
	card.prompt.text = describe(car)
	var actions := options_for(car)
	for i in range(3):
		var action: String = actions[i]
		var control: Button = card.buttons[i]
		control.visible = action!="" and race.phase==Race.Phase.RACE
		control.disabled = not race.allowed(car,action)
		var title := Race.action_label(action)
		if action=="pace": title = Race.PACE_NAMES[car.pace]
		if action=="plan" and car.called: title = "Modifier l’arrêt" if not car.orders.is_empty() else "Confirmer l’arrêt"
		control.tooltip_text = "Rythme · "+title if action=="pace" else title
		control.text = "Décaler +1 t." if action=="delay" else title

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
			var needs := PackedStringArray()
			for action in race.pending_orders(car):
				needs.append(Race.action_label(action)+( " (joueur)" if car.orders[action]==Race.Mode.MANUAL else " (auto)"))
			return location+" · "+(", ".join(needs) if not needs.is_empty() else "prête à repartir")
		Race.State.EXIT: return "Sortie des stands · "+Race.time_left(car.timer)
		Race.State.OUT: return "Abandon · panne d’essence"
	return ""

func focus_first() -> void:
	if not visible: return
	if start_button.is_visible_in_tree(): start_button.grab_focus()
	elif restart_button.is_visible_in_tree(): restart_button.grab_focus()
	elif planner.visible: planner_rows[5].grab_focus()
	else: release_focus()

func focus_dashboard() -> void:
	for card in cards:
		for control: Button in card.buttons:
			if control.is_visible_in_tree() and not control.disabled:
				control.grab_focus()
				return
	if not speed_button.disabled: speed_button.grab_focus()
	else: standings_button.grab_focus()

func release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused!=null and is_ancestor_of(focused): focused.release_focus()

func field_input() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return visible and race.phase==Race.Phase.RACE and not planner.visible and (focused==null or not is_ancestor_of(focused))

func _input(event: InputEvent) -> void:
	if not visible or race==null or race.phase!=Race.Phase.RACE or event.is_echo(): return
	var toggle: bool = (event is InputEventKey and event.pressed and event.keycode==KEY_TAB) or \
		(event is InputEventJoypadButton and event.is_action_pressed("take"))
	if toggle:
		get_viewport().set_input_as_handled()
		if planner.visible: close_plan()
		elif field_input(): focus_dashboard()
		else: release_focus()
	elif planner.visible and (event.is_action_pressed("cancel_item") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close_plan()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.is_action_pressed("use_item") or event.is_echo(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Button and is_ancestor_of(focus) and not focus.disabled:
		get_viewport().set_input_as_handled()
		focus.pressed.emit()

func guest_input(input: Array) -> bool:
	guest_online = input.size()==9 and input[0]==true
	if not guest_online or race.phase!=Race.Phase.RACE:
		guest_axis = 0
		if planner_for_guest: close_plan()
		return false
	var pressed := int(input[8])
	if (pressed & 2)!=0:
		if planner_for_guest: close_plan()
		elif not planner.visible: open_plan(1,true)
	if not planner_for_guest: return not planner.visible
	if (pressed & 8)!=0:
		close_plan()
		return false
	var y := float(input[2])
	var x := float(input[1])
	var axis := y if absf(y)>absf(x) else x
	var direction := int(signf(axis)) if absf(axis)>0.55 else 0
	if direction!=0 and guest_axis==0:
		for offset in range(1,planner_rows.size()+1):
			var next := posmod(planner_pick+direction*offset,planner_rows.size())
			if planner_rows[next].disabled: continue
			planner_pick = next
			planner_rows[next].grab_focus()
			break
	if (pressed & 4)!=0 and not planner_rows[planner_pick].disabled: planner_rows[planner_pick].pressed.emit()
	guest_axis = direction
	return false

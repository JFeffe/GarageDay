extends CanvasLayer

const Race := preload("res://endurance_race.gd")
const CREAM := Color("#fff3d9")
const MINT := Color("#a6ccc3")
const GOLD := Color("#ffc47e")
const BLUE := Color("#a8edf5")
const BRIEFING := "Deux GT et quatre pilotes. Appelle tes voitures au box, fais le plein, change les pneus et alterne les pilotes. Les gros dégâts se réparent au garage.\n\nSouris ou flèches / croix et A / F."
const BUTTONS := {
	Race.State.TRACK: ["call", "delay", "pace", "", "", ""],
	Race.State.BOX: ["fuel", "tires", "driver", "patch", "garage", "exit"],
	Race.State.GARAGE: ["fuel", "tires", "driver", "repair", "", "exit"],
}

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
var start_button: Button
var speed_button: Button
var headline: Label
var status: Label
var radio: Label
var circuit: Circuit
var scores: Array[Label] = []
var cards: Array[Dictionary] = []
var briefing: PanelContainer
var briefing_title: Label
var briefing_copy: Label
var restart_button: Button
var exit_button: Button
var guest_online := false
var guest_selection := 0
var guest_axis := 0

signal restart_requested
signal exit_requested

func build(session: RefCounted) -> void:
	race = session
	layer = 4
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.theme = make_theme()
	add_child(layout)

	var left := anchored_panel(layout,Vector4(0,0,0,0),Vector4(15,14,237,0))
	var left_content := column(left)
	left_content.add_child(text("12 H D’ENDURANCE",20))
	headline = text("",29,GOLD)
	left_content.add_child(headline)
	status = text("",14,MINT)
	left_content.add_child(status)
	circuit = Circuit.new()
	circuit.custom_minimum_size = Vector2(188,99)
	circuit.race = race
	circuit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_content.add_child(circuit)
	speed_button = button(left_content,"",func() -> void:
		race.speed_up = not race.speed_up
		refresh())

	var right := anchored_panel(layout,Vector4(1,0,1,0),Vector4(-240,14,-15,0))
	var right_content := column(right)
	right_content.add_child(text("CLASSEMENT",17))
	for i in race.cars.size():
		var row := text("",14)
		right_content.add_child(row)
		scores.append(row)

	var bottom := VBoxContainer.new()
	anchor(bottom,Vector4(0,1,1,1),Vector4(15,0,-15,-14))
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation",6)
	layout.add_child(bottom)
	var feed := panel(bottom)
	radio = text("",15,MINT)
	radio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.add_child(radio)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	bottom.add_child(row)
	for i in range(2): build_card(row,i)

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
	refresh()

func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#14292df5")
	background.border_color = Color("#52736d")
	background.set_border_width_all(1)
	background.set_corner_radius_all(8)
	for edge in [SIDE_LEFT,SIDE_RIGHT]: background.set_content_margin(edge,11.0)
	for edge in [SIDE_TOP,SIDE_BOTTOM]: background.set_content_margin(edge,8.0)
	theme.set_stylebox("panel","PanelContainer",background)
	for state in ["normal","hover","pressed","disabled"]:
		var action := StyleBoxFlat.new()
		action.bg_color = Color("#213b3f") if state=="normal" else Color("#315750")
		if state=="disabled": action.bg_color = Color("#1d292e")
		action.set_corner_radius_all(4)
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
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	theme.set_stylebox("fill","ProgressBar",fill)
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color("#213638")
	theme.set_stylebox("background","ProgressBar",empty)
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

func build_card(parent: HBoxContainer,index: int) -> void:
	var frame := panel(parent)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := column(frame)
	var title := text("",21,race.cars[index].color)
	var metrics := text("",15)
	var relief := text("",14,MINT)
	var prompt := text("",15,MINT)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 4
	for label in [title,metrics,relief,prompt]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		body.add_child(label)
	body.add_child(bar)
	var actions := GridContainer.new()
	actions.columns = 3
	actions.custom_minimum_size.y = 65
	actions.add_theme_constant_override("h_separation",5)
	actions.add_theme_constant_override("v_separation",5)
	body.add_child(actions)
	var options: Array[Button] = []
	for i in range(6):
		var control := button(actions,"",activate.bind(index,i))
		control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		options.append(control)
	cards.append({"title":title,"metrics":metrics,"relief":relief,"prompt":prompt,"bar":bar,"buttons":options})

func options_for(car: Dictionary) -> Array:
	return BUTTONS.get(car.state,["", "", "", "", "", ""])

func activate(index: int, slot: int) -> void:
	var action: String = options_for(race.cars[index])[slot]
	if action!="" and race.perform(index,action):
		refresh()
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button and focus.disabled: focus_car(index)

func refresh() -> void:
	var on_grid: bool = race.phase==Race.Phase.GRID
	var finished: bool = race.phase==Race.Phase.FINISH
	headline.text = race.clock()
	var left: float = Race.DURATION-race.elapsed
	status.text = "%d h %02d restantes · ×%d" % [floori(left/3600.0),floori(left/60.0)%60,roundi(race.rate())]
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
	var controls := "Flèches / croix · A / F choisir"
	if guest_online: controls = "J2 · n° 81 avec stick / flèches et A / F"
	radio.text = race.radio[0] if not race.radio.is_empty() else controls
	radio.tooltip_text = "\n".join(race.radio)
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

func refresh_card(index: int, position: int) -> void:
	var car: Dictionary = race.cars[index]
	var card := cards[index]
	var driver: String = car.drivers[car.driver]
	var alternate: String = car.drivers[1-car.driver]
	var guest := " · J2" if index==1 and guest_online else ""
	card.title.text = "N° %d · P%d · %s%s" % [car.number,position,driver,guest]
	card.metrics.text = "Essence %d %%    Pneus %d %%    Dégâts %d %%" % [
		roundi(car.fuel*100),roundi(car.tires*100),roundi(car.damage*100)]
	card.relief.text = "Relève · %s     Fatigue · %d %%" % [alternate,clampi(roundi(car.fatigue[car.driver]/36.0),0,100)]
	card.prompt.text = describe(car)
	var in_progress: bool = car.job!=""
	card.bar.value = 100.0*(1.0-car.job_left/car.job_total) if in_progress else 0.0
	var actions := options_for(car)
	for i in range(6):
		var action: String = actions[i]
		var control: Button = card.buttons[i]
		control.visible = action!="" and race.phase==Race.Phase.RACE
		control.disabled = not race.allowed(car,action)
		var title := Race.action_label(action)
		if action=="pace": title = "Rythme · "+Race.PACE_NAMES[car.pace]
		if action=="call" and car.called: title = "Appel confirmé"
		if car.done.has(action): title += " ✓"
		var selected := index==1 and guest_online and i==guest_selection and not control.disabled
		control.text = "› "+title if selected else title
		control.add_theme_color_override("font_color",BLUE if selected else CREAM)

func describe(car: Dictionary) -> String:
	if race.phase==Race.Phase.GRID: return "Sur la grille · deux pilotes par voiture"
	if race.phase==Race.Phase.FINISH: return "Classement final · %d tours" % maxi(0,floori(car.distance))
	if car.job!="": return "%s · %s" % [Race.action_label(car.job),Race.time_left(car.job_left)]
	match car.state:
		Race.State.TRACK:
			if car.called: return "Appel au box · entrée à la fin du tour"
			var alert := "Accrochage · " if car.damage>=0.15 else "Réserve d’essence · " if car.fuel<0.16 else "En piste · "
			return alert+"arrêt prévu dans %s" % Race.time_left(car.planned-race.elapsed)
		Race.State.ENTRY: return "Entrée des stands · "+Race.time_left(car.timer)
		Race.State.QUEUE: return "En attente · le box extérieur est occupé"
		Race.State.BOX, Race.State.GARAGE:
			var needs := PackedStringArray()
			if car.fuel<0.44: needs.append("essence")
			if car.tires<0.74: needs.append("pneus")
			if car.fatigue[car.driver]>2200.0 and not car.done.has("driver"): needs.append("relève")
			if car.damage>=0.38: needs.append("réparation au garage")
			elif car.damage>=0.07: needs.append("réparation")
			var location := "Au garage" if car.state==Race.State.GARAGE else "Au box"
			return location+" · "+(", ".join(needs) if not needs.is_empty() else "prête à repartir")
		Race.State.EXIT: return "Sortie des stands · "+Race.time_left(car.timer)
		Race.State.OUT: return "Abandon · panne d’essence"
	return ""

func focus_first() -> void:
	if not visible: return
	if start_button.is_visible_in_tree(): start_button.grab_focus()
	elif restart_button.is_visible_in_tree(): restart_button.grab_focus()
	else: focus_car(0)

func focus_car(index: int) -> void:
	for control: Button in cards[index].buttons:
		if control.is_visible_in_tree() and not control.disabled:
			control.grab_focus()
			return
	if not speed_button.disabled: speed_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.is_action_pressed("use_item") or event.is_echo(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Button and is_ancestor_of(focus) and not focus.disabled:
		get_viewport().set_input_as_handled()
		focus.pressed.emit()

func guest_input(input: Array) -> void:
	guest_online = input.size()==9 and input[0]==true
	if not guest_online or race.phase!=Race.Phase.RACE:
		guest_axis = 0
		return
	var y := float(input[2])
	var x := float(input[1])
	var axis := y if absf(y)>absf(x) else x
	var direction := int(signf(axis)) if absf(axis)>0.55 else 0
	var car: Dictionary = race.cars[1]
	var options := options_for(car)
	var available: Array[int] = []
	for i in options.size():
		if options[i]!="" and race.allowed(car,options[i]): available.append(i)
	if not available.is_empty():
		if guest_selection not in available: guest_selection = available[0]
		elif direction!=0 and guest_axis==0:
			guest_selection = available[posmod(available.find(guest_selection)+direction,available.size())]
		if int(input[8]) & 4: activate(1,guest_selection)
	guest_axis = direction

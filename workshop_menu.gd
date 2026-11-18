extends Control

class OfferArt extends Control:
	var ink := Color("#203a42")
	var cream := Color("#fff2cf")
	var kind := ""

	func _draw() -> void:
		var middle := size/2
		for x in range(8,int(size.x),15):
			draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.1,0.2,0.25,0.12))
		for y in range(8,int(size.y),15):
			draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.1,0.2,0.25,0.12))
		match kind:
			"lift","tuning":
				draw_rect(Rect2(middle-Vector2(43,15),Vector2(86,7)),ink)
				draw_line(middle+Vector2(-25,-6),middle+Vector2(23,21),ink,6,true)
				draw_line(middle+Vector2(25,-6),middle+Vector2(-23,21),ink,6,true)
				draw_rect(Rect2(middle+Vector2(-32,18),Vector2(64,5)),ink)
				draw_circle(middle+Vector2(0,7),4,cream)
			"counter":
				draw_rect(Rect2(middle-Vector2(30,20),Vector2(60,38)),ink)
				for y in [-12,0,12]:
					draw_line(middle+Vector2(-24,y),middle+Vector2(24,y),cream,2,true)
				for x in [-22,22]: draw_circle(middle+Vector2(x,21),4,ink)
			"compressor":
				draw_arc(middle-Vector2(2,1),23,-PI,0,20,ink,5,true)
				draw_rect(Rect2(middle-Vector2(26,3),Vector2(52,25)),ink)
				draw_circle(middle-Vector2(7,3),10,cream)
				draw_line(middle-Vector2(7,3),middle+Vector2(-1,-9),ink,2,true)
				draw_line(middle+Vector2(27,10),middle+Vector2(43,10),ink,4,true)
			"impact":
				draw_rect(Rect2(middle-Vector2(31,16),Vector2(52,21)),ink)
				draw_rect(Rect2(middle-Vector2(22,0),Vector2(18,23)),ink)
				draw_rect(Rect2(middle+Vector2(19,-12),Vector2(20,11)),cream)
				draw_circle(middle+Vector2(-7,-6),4,cream)
			"light_cart":
				draw_polyline(PackedVector2Array([middle+Vector2(-38,-18),middle+Vector2(-28,-18),
					middle+Vector2(-20,14),middle+Vector2(34,14)]),ink,5,true)
				for x in [-16,28]: draw_circle(middle+Vector2(x,21),6,ink)
				for x in [-3,15]: draw_circle(middle+Vector2(x,2),9,cream)
			"lounge":
				draw_rect(Rect2(middle-Vector2(27,17),Vector2(54,28)),ink)
				draw_rect(Rect2(middle-Vector2(34,1),Vector2(68,18)),cream)
				for x in [-28,24]: draw_rect(Rect2(middle+Vector2(x,14),Vector2(6,9)),ink)
			"loyalty":
				draw_rect(Rect2(middle-Vector2(36,18),Vector2(72,36)),ink)
				draw_circle(middle+Vector2(-18,0),9,cream)
				for y in [-6,6]: draw_line(middle+Vector2(-2,y),middle+Vector2(25,y),cream,3,true)
			"reception":
				draw_rect(Rect2(middle-Vector2(32,13),Vector2(64,33)),ink)
				draw_rect(Rect2(middle-Vector2(26,19),Vector2(52,6)),cream)
				draw_line(middle+Vector2(-17,0),middle+Vector2(17,0),cream,3,true)
			"advertising":
				draw_colored_polygon(PackedVector2Array([middle+Vector2(-25,-8),middle+Vector2(20,-20),
					middle+Vector2(20,15),middle+Vector2(-25,5)]),ink)
				draw_line(middle+Vector2(-12,5),middle+Vector2(-6,20),ink,6,true)
				for y in [-9,4]: draw_line(middle+Vector2(26,y),middle+Vector2(38,y),cream,3,true)
			"diagnostic":
				draw_rect(Rect2(middle-Vector2(34,19),Vector2(68,36)),ink)
				draw_rect(Rect2(middle-Vector2(27,12),Vector2(54,19)),cream)
				draw_line(middle+Vector2(-14,13),middle+Vector2(14,13),cream,3,true)
			"oil_recovery":
				draw_rect(Rect2(middle-Vector2(20,13),Vector2(40,33)),ink)
				draw_line(middle+Vector2(-39,-18),middle+Vector2(-15,-18),ink,4,true)
				draw_line(middle+Vector2(-15,-18),middle+Vector2(-7,-8),ink,4,true)
				draw_line(middle+Vector2(-12,6),middle+Vector2(12,6),cream,3,true)
			"service_guarantee":
				draw_colored_polygon(PackedVector2Array([middle+Vector2(-22,-21),middle+Vector2(22,-21),
					middle+Vector2(20,7),middle+Vector2(0,24),middle+Vector2(-20,7)]),ink)
				draw_polyline(PackedVector2Array([middle+Vector2(-10,1),middle+Vector2(-3,7),middle+Vector2(10,-8)]),cream,4,true)
			"express_shop":
				draw_circle(middle+Vector2(4,3),19,ink)
				draw_rect(Rect2(middle-Vector2(2,22),Vector2(12,9)),ink)
				draw_line(middle+Vector2(4,3),middle+Vector2(14,-5),cream,3,true)
				for y in [-6,4,14]: draw_line(middle+Vector2(-33,y),middle+Vector2(-20,y),ink,3,true)
			"vending":
				draw_rect(Rect2(middle-Vector2(24,25),Vector2(48,50)),ink)
				draw_rect(Rect2(middle-Vector2(18,19),Vector2(36,28)),cream)
				for row in [-15,-3]:
					for x in [-15,-4,7]: draw_rect(Rect2(middle+Vector2(x,row),Vector2(6,8)),ink)
				draw_rect(Rect2(middle+Vector2(-13,14),Vector2(21,5)),cream)
			"magazines":
				draw_rect(Rect2(middle-Vector2(30,24),Vector2(60,48)),ink)
				for y in [-17,1]:
					for x in [-23,-7,9]:
						draw_rect(Rect2(middle+Vector2(x,y),Vector2(13,14)),cream)
						draw_rect(Rect2(middle+Vector2(x+2,y+3),Vector2(9,2)),ink)

class PlanArt extends Control:
	var bays := 1
	var variant := 0

	func _draw() -> void:
		var left := size.x*0.38
		draw_rect(Rect2(Vector2.ZERO,size),Color("#719299"))
		draw_rect(Rect2(0,0,left,size.y),Color("#dec5a1"))
		var wait_y := 0.09 if variant==2 else 0.40
		draw_rect(Rect2(6,wait_y*size.y,left-12,size.y*0.22),Color("#80aaa2"))
		for boundary in [0.33,0.69]:
			draw_line(Vector2(0,size.y*boundary),Vector2(left*0.34,size.y*boundary),Color("#f5e7cc"),2)
			draw_line(Vector2(left*0.59,size.y*boundary),Vector2(left,size.y*boundary),Color("#f5e7cc"),2)
		for i in range(bays):
			var width := (size.x-left)/bays
			var lane := Rect2(left+i*width+width*0.22,3,width*0.56,size.y-6)
			draw_rect(lane,Color("#9bb9b9"))
			draw_rect(Rect2(lane.position+Vector2(lane.size.x*0.23,7),Vector2(lane.size.x*0.54,lane.size.y-14)),Color("#42646c"))
		draw_line(Vector2(1,size.y-2),Vector2(left,size.y-2),Color("#f5e7cc"),2)

signal chosen(index: int)
signal dismissed
signal reroll_requested
const INK := Color("#142a31")
const MINT := Color("#8fc6bb")
var shade: ColorRect
var frame: PanelContainer
var title: Label
var subtitle: Label
var cards: HBoxContainer
var details_label: Label
var footer: Label
var reroll_button: Button
var choice := 0
var kind := ""
var options: Array = []
var buttons: Array[PanelContainer] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade = ColorRect.new()
	shade.color = Color(0.04,0.10,0.13,0.83)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel",style(INK,Color("#4d756f"),18))
	center.add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",15)
	frame.add_child(content)
	title = label("",30,Color("#fff3d9"))
	content.add_child(title)
	subtitle = label("",16,MINT)
	content.add_child(subtitle)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation",10)
	content.add_child(cards)
	details_label = label("",13,Color("#e5c68d"))
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(details_label)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",14)
	content.add_child(controls)
	footer = label("",14,Color("#b9ccca"))
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(footer)
	reroll_button = Button.new()
	reroll_button.focus_mode = Control.FOCUS_NONE
	reroll_button.add_theme_font_size_override("font_size",14)
	reroll_button.add_theme_color_override("font_color",Color("#ffe4af"))
	reroll_button.add_theme_color_override("font_hover_color",Color("#fff3d9"))
	reroll_button.add_theme_stylebox_override("normal",style(Color("#344645"),Color("#ae8c56"),9))
	reroll_button.add_theme_stylebox_override("hover",style(Color("#465650"),Color("#e5bd78"),9))
	reroll_button.add_theme_stylebox_override("pressed",style(Color("#243837"),Color("#e5bd78"),9))
	reroll_button.add_theme_stylebox_override("disabled",style(Color("#22383e"),Color("#46666b"),9))
	reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	controls.add_child(reroll_button)
	hide()

func style(color: Color, border: Color, margin: int) -> StyleBoxFlat:
	var theme := StyleBoxFlat.new()
	theme.bg_color = color
	theme.border_color = border
	theme.set_border_width_all(1)
	theme.set_corner_radius_all(10)
	theme.content_margin_left = margin
	theme.content_margin_right = margin
	theme.content_margin_top = margin
	theme.content_margin_bottom = margin
	return theme

func label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	return result

func open(page: String, heading: String, sub: String, items: Array, instructions: String, details := "") -> void:
	kind = page
	title.text = heading
	subtitle.text = sub
	footer.text = instructions
	reroll_button.hide()
	details_label.text = details
	details_label.visible = not details.is_empty()
	options = items
	choice = 0
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	buttons.clear()
	var width := clampf((get_viewport_rect().size.x-70-items.size()*10)/maxi(1,items.size()),95,220)
	for i in range(items.size()):
		var item: Array = items[i]
		var card := PanelContainer.new()
		card.custom_minimum_size.x = width
		cards.add_child(card)
		buttons.append(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation",9)
		card.add_child(stack)
		if page=="vendor":
			var image_tile := ColorRect.new()
			image_tile.color = Color(item[2])
			image_tile.custom_minimum_size.y = 66
			stack.add_child(image_tile)
			var art := OfferArt.new()
			art.kind = item[5]
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			image_tile.add_child(art)
		elif page=="layout":
			var plan := PlanArt.new()
			plan.bays = item[2]
			plan.variant = item[3]
			plan.custom_minimum_size.y = 53
			stack.add_child(plan)
		var name := label(item[0],17,Color("#fff3d9"))
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.custom_minimum_size.x = width-22
		if page=="vendor" and item[6]:
			stack.add_child(label("Rare",12,Color("#e5c68d")))
		stack.add_child(name)
		var description := label(item[1],13,Color("#bacdca"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = width-22
		stack.add_child(description)
		if page=="vendor":
			description.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var price := label(item[3],14,Color(item[4]))
			price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stack.add_child(price)
		ignore_mouse(stack)
		card.gui_input.connect(_click.bind(i))
	update_focus()
	show()

func set_vendor_reroll(text: String, disabled: bool) -> void:
	reroll_button.text = text
	reroll_button.disabled = disabled
	reroll_button.show()

func ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: ignore_mouse(child)

func _click(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		choice = index
		update_focus()
		chosen.emit(index)

func update_focus() -> void:
	for i in range(buttons.size()):
		var active := i==choice
		buttons[i].add_theme_stylebox_override("panel",style(Color("#285353") if active else Color("#213c43"),Color("#e5bd78") if active else Color("#46666b"),10))

func tick() -> void:
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_up"):
		choice = posmod(choice-1,options.size())
		update_focus()
	elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_down"):
		choice = posmod(choice+1,options.size())
		update_focus()
	if Input.is_action_just_pressed("cancel_item") or Input.is_action_just_pressed("ui_cancel"):
		dismissed.emit()
	elif reroll_button.visible and not reroll_button.disabled and Input.is_action_just_pressed("rotate_item"):
		reroll_requested.emit()
	elif Input.is_action_just_pressed("use_item") or Input.is_action_just_pressed("ui_accept"):
		chosen.emit(choice)

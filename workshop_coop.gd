extends RefCounted

const PlayerVisual := preload("res://player_visual.gd")
const ActorRepairPose := preload("res://workshop_repair_pose.gd")
const ActorFields := ["player","facing","velocity","held","held_origin","held_turn","pulling_cart",
	"tool_holder","item_prop","action","progress","repair_pose"]
const HostActions := ["start","call","sit","vendor","parts","cart","drive"]
const TAKE := 1
const ROTATE := 2
const USE := 4
const CANCEL := 8

var online := false
var processing_guest := false
var guest := {}
var host := {}
var avatar: Node3D
var visual
var panel: RichTextLabel

func reset() -> void:
	if is_instance_valid(avatar):
		avatar.hide()
		avatar.queue_free()
	if is_instance_valid(panel): panel.get_parent().queue_free()
	avatar = null
	panel = null
	visual = null
	guest.clear()
	host.clear()

func setup_guest(w) -> void:
	avatar = Node3D.new()
	w.site.add_child(avatar)
	visual = PlayerVisual.new()
	visual.build(w.game,avatar)
	var caption: Label3D = w.site.label_at(avatar,"J2",Vector3(0,1.7,0))
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = Color("#9be3ff")
	var holder := Node3D.new()
	avatar.add_child(holder)
	guest = {"player":Vector2(4.5,11.5),"facing":Vector2.UP,"velocity":Vector2.ZERO,
		"held":"","held_origin":-1,"held_turn":-1,"pulling_cart":false,
		"tool_holder":holder,"item_prop":null,"action":{},"progress":0.0,"repair_pose":ActorRepairPose.new()}
	if not w.site.clear_at(guest.player): guest.player = w.site.portal
	panel = w.make_panel(218)

func tick(w, dt: float, input: Array) -> void:
	online = input.size()==7 and input[0]==true
	if not online and guest.is_empty(): return
	if guest.is_empty(): setup_guest(w)
	if not online:
		guest.repair_pose.restore_wheel()
		guest.action = {}
		guest.velocity = Vector2.ZERO
		avatar.visible = guest.held!=""
		panel.get_parent().hide()
		return

	for field in ActorFields:
		host[field] = w.get(field)
		w.set(field,guest[field])
	var host_avatar: Node3D = w.game.avatar
	var host_visual = w.game.player_visual
	var host_seated: bool = w.office_seated
	var host_seat_blend: float = w.seat_blend
	var host_driver: int = w.driven_bay
	host["driven_bay"] = host_driver
	w.game.avatar = avatar
	w.game.player_visual = visual
	w.office_seated = false
	w.seat_blend = 0.0
	w.driven_bay = -1
	processing_guest = true
	avatar.show()
	var before: Vector2 = w.player
	var buttons := int(input[5])
	var pressed := int(input[6])
	if w.run.mode not in ["won","lost"]:
		var move := Vector2(float(input[1]),float(input[2])).limit_length()
		var aim := Vector2(float(input[3]),float(input[4])).limit_length()
		w.walk_with_input(dt,move,aim)
	if w.run.mode in ["day","closing"]:
		if (buttons | pressed) & CANCEL:
			if w.context(true).get("id") in ["decline","refuse","window_decline"]:
				w.advance_action(dt,(pressed & CANCEL)!=0,true,true)
			else:
				w.cancel_action()
		else:
			w.advance_action(dt,(pressed & USE)!=0,((buttons | pressed) & USE)!=0)
		if pressed & TAKE: w.place_or_move()
		if pressed & ROTATE: w.rotate_or_unload()
	else:
		w.cancel_action()
	w.sync_player(dt,before.distance_to(w.player)/maxf(0.001,dt))
	var option: Dictionary = w.context()
	var hint: String = option.get("label","Vise un poste")
	if not w.action.is_empty() and w.action.seconds>0.0:
		hint += " · %d %%"%roundi(100*w.progress/w.action.seconds)
	elif w.run.mode=="open":
		hint = "En attente du service"
	panel.text = "[color=#9be3ff]J2[/color]   %s\n%s"%[w.item_name(w.held) if w.held!="" else "Mains libres",hint]
	panel.get_parent().position = Vector2(14,157)
	panel.get_parent().show()
	for field in ActorFields:
		guest[field] = w.get(field)
		w.set(field,host[field])
	processing_guest = false
	w.game.avatar = host_avatar
	w.game.player_visual = host_visual
	w.office_seated = host_seated
	w.seat_blend = host_seat_blend
	w.driven_bay = host_driver

func allows(option: Dictionary) -> bool:
	if processing_guest and option.id in HostActions: return false
	if processing_guest and option.has("bay") and option.bay==host.driven_bay: return false
	var other := host if processing_guest else guest
	var other_action: Dictionary = other.get("action",{})
	if other_action.is_empty(): return true
	return option.at!=other_action.at and (not option.has("bay") or option.bay!=other_action.get("bay",-1))

func blocks_placement(area: Rect2) -> bool:
	var other := host if processing_guest else guest
	return online and not other.is_empty() and area.has_point(other.player)

func blocks_vehicle(point: Vector2, yaw: float, extents: Vector2, radius: float) -> bool:
	if not online or guest.is_empty(): return false
	var local: Vector2 = (guest.player-point).rotated(yaw).abs()
	return local.x<extents.x+radius and local.y<extents.y+radius

func rescue_item(w) -> Dictionary:
	if not online and not guest.is_empty() and guest.held!="" and w.held=="":
		return w.target("rescue_item","Reprendre · "+w.item_name(guest.held),guest.player,0.0)
	return {}

func take_rescued_item(w) -> void:
	if online or guest.is_empty() or guest.held=="" or w.held!="": return
	w.set_held(guest.held,guest.held_origin,guest.held_turn)
	if is_instance_valid(guest.item_prop): guest.item_prop.queue_free()
	guest.held = ""
	guest.item_prop = null
	avatar.hide()

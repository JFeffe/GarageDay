extends RefCounted

const PlayerVisual := preload("res://player_visual.gd")
const ActorRepairPose := preload("res://workshop_repair_pose.gd")
const ActorFields := ["player","facing","velocity","held","held_origin","held_turn","pulling_cart",
	"tool_holder","item_prop","action","progress","repair_pose","driven_bay","drive_speed","drive_steering","engine"]
const HostActions := ["start","call","sit","vendor","parts","cart"]
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
var guide: Dictionary = {}

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
	guide.clear()

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
	var motor := AudioStreamPlayer.new()
	motor.stream = w.engine.stream
	motor.volume_db = w.engine.volume_db
	motor.playback_type = w.engine.playback_type
	avatar.add_child(motor)
	var spawn: Vector2 = w.site.desk_side+Vector2.RIGHT*1.5 if w.site.compact else Vector2(4.5,11.5)
	guest = {"player":spawn,"facing":Vector2.UP,"velocity":Vector2.ZERO,
		"held":"","held_origin":-1,"held_turn":-1,"pulling_cart":false,
		"tool_holder":holder,"item_prop":null,"action":{},"progress":0.0,"repair_pose":ActorRepairPose.new(),
		"driven_bay":-1,"drive_speed":0.0,"drive_steering":0.0,"engine":motor}
	if not w.site.clear_at(guest.player): guest.player = w.site.portal
	panel = w.make_panel(218)

func tick(w, dt: float, input: Array) -> void:
	online = input.size()==9 and input[0]==true
	if not online and guest.is_empty(): return
	if guest.is_empty(): setup_guest(w)
	if not online:
		release_vehicle(w)
		guide.clear()
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
	w.game.avatar = avatar
	w.game.player_visual = visual
	w.office_seated = false
	w.seat_blend = 0.0
	processing_guest = true
	avatar.visible = w.driven_bay<0
	var before: Vector2 = w.player
	var was_driving: bool = w.driven_bay>=0
	var buttons := int(input[5])
	var pressed := int(input[8])
	if w.driven_bay>=0 and w.run.mode in ["day","closing"]:
		var drive := Vector2(float(input[6]),float(input[7]))
		w.control_vehicle(drive,dt,(buttons & ROTATE)!=0,(pressed & TAKE)!=0,(pressed & CANCEL)!=0)
	elif w.run.mode not in ["won","lost"]:
		w.walk_with_input(dt,Vector2(float(input[1]),float(input[2])).limit_length(),
			Vector2(float(input[3]),float(input[4])).limit_length())
	if not was_driving and w.driven_bay<0 and w.run.mode in ["day","closing"]:
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
	var driving: bool = w.driven_bay>=0
	guide = w.current_drive_guide()
	var option: Dictionary = w.context()
	var hint: String = option.get("label","Vise un poste")
	if driving:
		hint = guide.get("prompt","Au volant")
	elif not w.action.is_empty() and w.action.seconds>0.0:
		hint += " · %d %%"%roundi(100*w.progress/w.action.seconds)
	elif w.run.mode=="open":
		hint = "En attente du service"
	var equipment: String = "Au volant" if driving else (w.item_name(w.held) if w.held!="" else "Mains libres")
	panel.text = "[color=#9be3ff]J2[/color]   %s\n%s"%[equipment,hint]
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

func release_vehicle(w) -> void:
	var index: int = guest.driven_bay
	if index<0: return
	var bay: Dictionary = w.site.bays[index]
	w.steer_front_wheels(bay,0.0)
	var exit: Vector2 = w.driver_exit_point(w.site.vehicle_position(bay),bay.car.rotation.y)
	guest.player = w.site.portal if exit==Vector2.INF else exit
	guest.driven_bay = -1
	guest.drive_speed = 0.0
	guest.drive_steering = 0.0
	guest.engine.stop()

func allows(option: Dictionary) -> bool:
	if processing_guest and option.id in HostActions: return false
	if option.has("bay") and other_drives(option.bay): return false
	var other := host if processing_guest else guest
	var other_action: Dictionary = other.get("action",{})
	if other_action.is_empty(): return true
	return option.at!=other_action.at and (not option.has("bay") or option.bay!=other_action.get("bay",-1))

func other_drives(index: int) -> bool:
	var other := host if processing_guest else guest
	return index>=0 and other.get("driven_bay",-1)==index

func blocks_placement(area: Rect2) -> bool:
	var other := host if processing_guest else guest
	return online and not other.is_empty() and area.has_point(other.player)

func blocks_vehicle(point: Vector2, yaw: float, extents: Vector2, radius: float) -> bool:
	var other := host if processing_guest else guest
	if not online or other.is_empty() or other.get("driven_bay",-1)>=0: return false
	var local: Vector2 = (other.player-point).rotated(yaw).abs()
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

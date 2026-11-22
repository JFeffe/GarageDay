extends Node3D

const Miniature := preload("res://workshop_miniature.gd")
const Catalog := preload("res://workshop_catalog.gd")
const Neighborhood := preload("res://workshop_neighborhood.gd")
const PLANT := preload("res://assets/kenney/pottedPlant.glb")

const COMPACT_LAYOUT := 3
# The order of the numbered layouts is part of the save format.
const LAYOUTS := [
	["La Traversée","1 baie · bureau au nord, réception séparée",1,0],
	["Le Tandem","2 baies · salle d’attente commune",2,0],
	["Les Trois Ponts","3 baies · grand hall et bureau central",3,2],
	["Le Petit Atelier","1 baie · atelier et salles compacts",1,3],
]
const LAYOUT_ORDER := [COMPACT_LAYOUT,0,1,2]
const COMPACT_STATIONS := {
	"office_chair":Vector2i(2,1), "reception":Vector2i(1,9),
	"decor":Vector2i(3,1), "plant":Vector2i(1,11),
	"tool_tires":Vector2i(16,2), "tool_oil":Vector2i(16,4),
	"tool_inspection":Vector2i(16,1), "tool_pressure":Vector2i(16,3),
	"tool_ratchet":Vector2i(7,2), "tool_probe":Vector2i(6,2), "tool_puller":Vector2i(8,2),
	"rack":Vector2i(6,11), "fresh_oil":Vector2i(5,9),
	"new_battery":Vector2i(6,8), "coolant":Vector2i(5,11),
	"parts_chassis":Vector2i(6,10), "parts_electric":Vector2i(7,10),
	"bench":Vector2i(7,5), "waste_oil":Vector2i(16,8), "trash":Vector2i(16,9),
	"scrap":Vector2i(16,10), "counter_0":Vector2i(6,4), "counter_1":Vector2i(7,7),
	"counter_2":Vector2i(16,6),
}
const TRAVERSEE_STATIONS := {
	"tool_pressure": Vector2i(18,1),
	"tool_inspection": Vector2i(20,1),
	"tool_oil": Vector2i(18,3),
	"tool_tires": Vector2i(20,3),
	"tool_probe": Vector2i(10,3),
	"tool_ratchet": Vector2i(11,3),
	"tool_puller": Vector2i(12,3),
	"counter_0": Vector2i(8,5),
	"counter_1": Vector2i(11,7),
	"bench": Vector2i(12,7),
	"trash": Vector2i(20,5),
	"waste_oil": Vector2i(20,6),
	"scrap": Vector2i(20,7),
	"counter_2": Vector2i(20,8),
	"parts_chassis": Vector2i(7,10),
	"parts_electric": Vector2i(7,11),
	"rack": Vector2i(7,12),
	"coolant": Vector2i(10,11),
	"fresh_oil": Vector2i(11,11),
	"new_battery": Vector2i(12,11),
}
const TOOLS := {"tires":"Clé à choc","oil":"Bac à huile","inspection":"Valise de diagnostic","pressure":"Manomètre",
	"ratchet":"Clé à cliquet","probe":"Sonde de contrôle","puller":"Extracteur"}
const SERVICE_OFFSETS := {"oil":Vector2(-0.88,-2.10),"inspection":Vector2(0.38,-2.15),
	"battery":Vector2(0,-2.17),"pressure":Vector2(1.45,1.28),"coolant":Vector2(-0.38,-2.15)}
const NORTH_APRON := 11.0
const ROAD_TOP := -18.0
const ROAD_LANE := -15.05
const ARRIVAL_ROAD_LANE := 37.7
const ARRIVAL_ROAD_END := 41.2
const CEILING_HEIGHT := 3.12
const PEDESTRIAN_ACCESS := Vector2(9.36,-0.95)
const SHOP_PERSONNEL_DOOR := Rect2(12.55,16.82,1.27,0.18)
const WAITING_AMENITIES := ["vending","magazines"]
const WHEEL_OFFSETS := [Vector2(-1.18,-1.27),Vector2(-1.18,1.27),Vector2(1.18,-1.27),Vector2(1.18,1.27)]
const CAR_HALF := Vector2(1.13,2.2)
const PLAYER_RADIUS := 0.26
const LIFT_TRAVEL := 0.96
const LIFT_SPEED := 0.96
const PLACEMENT_GUIDE_COLOR := Color("#ffd084")
const PLACEMENT_READY_COLOR := Color("#8df0aa")
const WAITING_PARKING_COLOR := Color("#9be3ff")
const WORK_MARKER_COLOR := Color("#ffdb94")
var game: Node3D
var lift_speed := LIFT_SPEED
var size := Vector2(22,34)
var variant := 0
var compact := false
var left_width := 7.0
var floor_inside := Rect2(0,0,22,17)
var wall_rects: Array[Rect2] = []
var stations: Dictionary = {}
var cells: Dictionary = {}
var bays: Array[Dictionary] = []
var arrivals: Array[Rect2] = []
var car_holders: Array[Dictionary] = []
var seats: Array[Vector2] = []
var portal := Vector2(3.5,16.9)
var pedestrian_access := PEDESTRIAN_ACCESS
var personnel_door_area := SHOP_PERSONNEL_DOOR
var desk_side := Vector2(3.5,11.5)
var reception_at := Vector2(3.5,12.5)
var checkout_at := Vector2(2.5,12.5)
var queue_head := Vector2(3.5,13.5)
var checkout_head := Vector2(2.5,13.5)
var waiting_room := Vector2(3.6,8.0)
var vendor_at := Vector2(7.5,19.45)
var preview: MeshInstance3D
var select_corners: Node3D
var intake_car_marker: Label3D
var van: Node3D
var parked_cart: Node3D
var personnel_door: Node3D
var cart_cell := Vector2i(10,10)
var used_tire_zone := Rect2i()
var bearing_audio: AudioStreamPlayer
var bearing_clips: Array[AudioStreamWAV] = []

var eye_level := false

func build(g: Node3D, layout_index: int, eye_level_view := false) -> void:
	game = g
	eye_level = eye_level_view
	var layout: Array = LAYOUTS[layout_index]
	var count: int = layout[2]
	variant = layout[3]
	compact = layout_index==COMPACT_LAYOUT
	var depth := 13.0 if compact else 17.0
	var first_bay_x := 11.5 if compact else 15.5
	size.x = 18.0 if compact else 22.0+6*(count-1)
	floor_inside.size = Vector2(size.x,depth)
	if compact:
		left_width = 5.0
		portal = Vector2(2.5,depth-0.1)
		pedestrian_access = Vector2(6.7,PEDESTRIAN_ACCESS.y)
		personnel_door_area.position = Vector2(first_bay_x-2.95,depth-0.18)
	slab(Rect2(-1,-NORTH_APRON-1.0,size.x+2,size.y+NORTH_APRON+2.1),-0.13,Color("#869987"))
	slab(floor_inside,0,Color("#abb4af"))
	slab(Rect2(0,0,left_width,depth),0.006,Color("#c9ae89"))
	slab(Rect2(0,depth,size.x,size.y-depth),0.0,Color("#a9aba1"))
	slab(Rect2(0,size.y,size.x+6.5,ARRIVAL_ROAD_END-size.y),0.0,Color("#687d80"))
	slab(Rect2(0,-NORTH_APRON,size.x,NORTH_APRON),0.0,Color("#a9aba1"))
	slab(Rect2(0,ROAD_TOP,size.x+6.5,-NORTH_APRON-ROAD_TOP),0.0,Color("#687d80"))
	for x in range(1,int(size.x)+6,3):
		for z in [-16.65,35.75]:
			game.box(self,Vector3(1.4,0.012,0.06),Vector3(x,0.053,z),Color("#d6c695"))
	if compact:
		waiting_room = Vector2(2.7,5.5)
		for z in [3.9,7.8]:
			add_wall(0,z,1.2,0.18)
			add_wall(3.8,z,left_width-3.8,0.18)
	elif variant==2:
		waiting_room = Vector2(3.4,3.0)
		add_wall(0,5.7,2.1,0.18)
		add_wall(4.6,5.7,2.4,0.18)
		add_wall(0,11.1,2.1,0.18)
		add_wall(4.6,11.1,2.4,0.18)
	else:
		add_wall(0,5.6,2.1,0.18)
		add_wall(4.5,5.6,2.5,0.18)
		add_wall(0,10.8,2.1,0.18)
		add_wall(4.5,10.8,2.5,0.18)
	var office: Vector2i = Vector2i(1,7) if variant==2 else Vector2i(1,2)
	sign_at("BUREAU",center(office)+Vector2(1.7,0.75 if compact else 0.2),Color("#324b4c"))
	sign_at("ATTENTE",waiting_room+Vector2(0.4,0.8),Color("#324b4c"))
	sign_at("ENTRÉE CLIENTS",portal+Vector2(0,0.45),Color("#fff0cf"))
	for offset in [-0.95,0.95]:
		game.box(self,Vector3(0.18,1.11,0.29),Vector3(portal.x+offset,0.61,portal.y),Color("#72948d"))
	game.box(self,Vector3(1.74,0.026,0.32),Vector3(portal.x,0.061,depth-0.04),Color("#768b83"))
	var bay_wall_start := first_bay_x-3.10
	add_wall(0,0,0.18,depth)
	add_wall(size.x-0.18,0,0.18,depth)
	add_wall(0,depth-0.18,portal.x-1.0,0.18)
	add_wall(portal.x+1.0,depth-0.18,bay_wall_start-portal.x-1.0,0.18)
	var opening_start := 4.8 if compact else 7.1
	var opening_end := 7.6 if compact else 10.0
	add_wall(left_width-0.1,0,0.18,opening_start)
	add_wall(left_width-0.1,opening_end,0.18,depth-opening_end)
	add_wall(0,0,pedestrian_access.x-0.81,0.18)
	add_wall(pedestrian_access.x+0.82,0,bay_wall_start-pedestrian_access.x-0.82,0.18)
	for stripe in range(4):
		game.box(self,Vector3(0.19,0.012,1.6),Vector3(pedestrian_access.x-0.51+stripe*0.34,0.053,-0.40),Color("#e1d9af"))
	sign_at("ACCÈS PIÉTON",pedestrian_access+Vector2(0,-0.63),Color("#fff0cf"))
	for i in range(count):
		build_bay(i,Vector2(first_bay_x+6*i,6.5 if compact else 8.0))
		var seat_row := floori(waiting_room.y)+i-(1 if variant==2 else 0)
		var tile := Vector2i(1,seat_row)
		seats.append(center(tile)+Vector2(0.23,0))
		make_station("seat_%d"%i,"Banquette",tile,Color("#759da2"),0.48)
	if eye_level:
		var roof: MeshInstance3D = game.box(self,Vector3(size.x,0.16,depth),
			Vector3(size.x*0.5,CEILING_HEIGHT+0.08,depth*0.5),Color("#d7dad0"))
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in ([15.5,7.5] if compact else [11.5,7.5]): build_arrival_space(x)
	build_used_tire_zone()
	make_station("phone","Téléphone",office,Color("#947760"),0.83,2)
	make_station("office_chair","Chaise du bureau",office+Vector2i(1,-1),Color("#739a96"),0.55)
	make_station("reception","Comptoir d’accueil",Vector2i(2,12),Color("#cfa876"),0.88,2)
	var storage_y := 14
	var storage_x := 8 if variant==2 else 9
	make_station("rack","Pneus neufs",Vector2i(storage_x,storage_y),Color("#60777e"),1.36,2)
	make_station("fresh_oil","Huile neuve",Vector2i(storage_x+2,storage_y),Color("#739f90"))
	make_station("new_battery","Batteries",Vector2i(storage_x+3,storage_y),Color("#9c81a5"))
	make_station("coolant","Liquide",Vector2i(storage_x+4,storage_y),Color("#7196a9"))
	sign_at("RÉSERVE",Vector2(6.65,9.45) if compact else Vector2(storage_x+2.75,storage_y-0.78),Color("#435d62"))
	make_station("waste_oil","Huile usée",Vector2i(9,16),Color("#aa8755"))
	make_station("trash","Poubelle",Vector2i(11,16),Color("#596d72"))
	for i in range(TOOLS.size()):
		var kind: String = TOOLS.keys()[i]
		var tile := Vector2i(8+i,1) if i<4 else Vector2i(8+(i-4)*2,3)
		make_station("tool_"+kind,["Clé","Bac","Diagnostic","Pression","Cliquet","Sonde","Extracteur"][i],tile,tool_color(kind))
	make_station("parts_chassis","Pièces châssis",Vector2i(8,13),Color("#7b9291"),1.10)
	make_station("parts_electric","Moteur et élec.",Vector2i(11,12),Color("#8c8bab"),1.10)
	make_station("bench","Établi pneus",Vector2i(12,5),Color("#568e8a"),0.77)
	make_station("scrap","Récupération",Vector2i(8,16),Color("#7b8070"),0.52)
	for i in range(3):
		var tile := [Vector2i(8,5),Vector2i(10,11),Vector2i(19+6*(count-1),10)][i] as Vector2i
		make_station("counter_%d"%i,"Desserte" if i==2 else "Comptoir",tile,Color("#75999a"))
	make_station("decor","Armoire",Vector2i(1,1 if variant!=2 else 6),Color("#a58570"),1.12)
	make_station("plant","Plante",Vector2i(1,14),Color("#829b72"),0.58)
	if layout_index==0:
		for id in TRAVERSEE_STATIONS:
			move_station(id,TRAVERSEE_STATIONS[id])
		cart_cell = Vector2i(12,9)
	elif compact:
		cart_cell = Vector2i(7,8)
	parked_cart = trolley_model(self,Vector3(center(cart_cell).x,0.075,center(cart_cell).y))
	build_selection()
	intake_car_marker = label_at(self,"",Vector3.ZERO)
	intake_car_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	intake_car_marker.font_size = 32
	intake_car_marker.outline_size = 10
	intake_car_marker.modulate = PLACEMENT_GUIDE_COLOR
	intake_car_marker.outline_modulate = Color("#203539")
	intake_car_marker.hide()
	build_vendor()
	Neighborhood.dress_shop(self)
	bearing_audio = AudioStreamPlayer.new()
	if game.hosting: bearing_audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	bearing_audio.volume_db = -11.0
	add_child(bearing_audio)
	bearing_clips = [bearing_clip(false),bearing_clip(true)]

func make_station(id: String, title: String, tile: Vector2i, color: Color, height := 0.76, span := 1) -> void:
	if compact:
		tile = COMPACT_STATIONS.get(id,tile)
	var root := Node3D.new()
	add_child(root)
	stations[id] = {"root":root,"tile":tile,"title":title,"height":height,"span":span,"turn":0}
	move_station(id,tile)
	if id=="plant":
		Neighborhood.fit(root,PLANT,Vector3(0.55,0,0.55))
		return
	if id in WAITING_AMENITIES:
		build_waiting_amenity(root,id,color)
	elif not Neighborhood.station(root,id,height,span):
		if id=="rack": Neighborhood.tire_rack(root)
		else:
			game.box(root,Vector3(0.85,0.08,0.86),Vector3(0,0.15,0),color)
			for x in [-0.38,0.38]:
				game.box(root,Vector3(0.08,0.38,0.86),Vector3(x,0.32,0),color)
	if id=="reception":
		desk_label(root,"CAISSE",-0.5,height,Color("#765127"))
		desk_label(root,"ACCUEIL",0.5,height,Color("#2c585a"))
		return
	var label := label_at(root,title,Vector3(0,height+0.36,0))
	label.pixel_size = 0.0032 if eye_level else 0.0059
	stations[id].caption = label
	match id:
		"phone":
			game.box(root,Vector3(0.31,0.16,0.25),Vector3(-0.53,height+0.11,0),Color("#294a51"))
			game.box(root,Vector3(0.31,0.05,0.07),Vector3(-0.53,height+0.21,0.03),Color("#8aada5"))
		"fresh_oil":
			Neighborhood.fit(root,Neighborhood.OIL_CRATE,Vector3(0.48,0.28,0.35),Vector3(0,height,0))
		"new_battery","coolant":
			supply_model(root,id,Vector3(0,height+0.05,0))

func build_waiting_amenity(root: Node3D, id: String, color: Color) -> void:
	var dark := Color("#314b50")
	if id=="vending":
		game.box(root,Vector3(0.75,1.25,0.66),Vector3(0,0.66,0),color)
		game.box(root,Vector3(0.60,0.75,0.022),Vector3(0,0.81,0.339),dark)
		var packaging := [Color("#e3b560"),Color("#cc7960"),Color("#83b5cb"),Color("#a3ba83")]
		for row in range(3):
			var y := 0.6+row*0.23
			for column in range(4):
				game.box(root,Vector3(0.093,0.13,0.032),Vector3(-0.218+column*0.145,y,0.356),packaging[(row+column)%4])
		game.box(root,Vector3(0.33,0.14,0.04),Vector3(-0.08,0.28,0.347),dark)
		game.box(root,Vector3(0.10,0.19,0.04),Vector3(0.24,0.31,0.347),Color("#e8dabe"))
	else:
		game.box(root,Vector3(0.74,0.08,0.59),Vector3(0,0.07,0),dark)
		game.box(root,Vector3(0.69,0.75,0.13),Vector3(0,0.42,-0.15),color)
		for row in range(2):
			var y := 0.31+row*0.28
			game.box(root,Vector3(0.66,0.07,0.26),Vector3(0,y,0.025),color)
			for column in range(3):
				var x := -0.21+column*0.21
				var ink: Color = [Color("#5f919a"),Color("#e3bd74"),Color("#b2736b")][(column+row)%3]
				game.box(root,Vector3(0.16,0.19,0.038),Vector3(x,y+0.12,0.08),ink)
				game.box(root,Vector3(0.12,0.028,0.010),Vector3(x,y+0.17,0.103),Color("#ffecd2"))

func build_used_tire_zone() -> void:
	var x := int(bays.back().at.x)+3
	used_tire_zone = Rect2i(x,17,3,2)
	slab(Rect2(used_tire_zone),0.009,Color("#778e86"))
	for dx in range(4):
		game.box(self,Vector3(0.025,0.01,1.99),Vector3(x+dx,0.063,18),Color("#c9d3b5"))
	for z in [17.0,18.0,19.0]:
		game.box(self,Vector3(3,0.01,0.025),Vector3(x+1.5,0.063,z),Color("#c9d3b5"))
	var caption := label_at(self,"PNEUS USAGÉS",Vector3(x+1.5,0.065,19.48))
	caption.rotation_degrees.x = -90
	caption.pixel_size = 0.0105
	caption.modulate = Color("#fff0cf")

func desk_label(root: Node3D, text: String, x: float, height: float, color: Color) -> void:
	var caption := label_at(root,text,Vector3(x,height+0.073,0.17))
	caption.rotation_degrees.x = -90
	caption.font_size = 28
	caption.pixel_size = 0.005
	caption.modulate = color
	caption.outline_size = 0

func build_bay(index: int, at: Vector2) -> void:
	var x := at.x
	var depth := floor_inside.size.y
	slab(Rect2(x-1.65,0,3.3,depth),0.015,Color("#a1af9f"))
	slab(Rect2(x-1.65,depth,3.3,24.9-depth),0.009,Color("#929f9b"))
	for z in [18.6,20.2,21.8,23.4]:
		for side in [-1,1]:
			game.box(self,Vector3(0.055,0.012,0.57),Vector3(x+side*1.52,0.061,z),Color("#dec99a"))
	build_arrival_space(x)
	for side in [-1,1]:
		var rail_x: float = x+side*1.52
		game.box(self,Vector3(0.07,0.024,depth-0.1),Vector3(rail_x,0.067,depth/2),Color("#e5c481"))
		for end in [1.3,depth-1.5]:
			for stripe in range(3):
				game.box(self,Vector3(0.34,0.018,0.075),Vector3(rail_x,0.064,end+stripe*0.15),Color("#e3bc71"))
	var gates: Array[Node3D] = []
	for z in [0.07,depth-0.07]:
		var gate := Node3D.new()
		add_child(gate)
		gate.position = Vector3(x,0,z)
		Neighborhood.fit(gate,Neighborhood.SHUTTER,Vector3(3.04,CEILING_HEIGHT if eye_level else 0.70,0.14))
		gates.append(gate)
	for z in [0.0,depth-0.18]:
		if index==0 and z>0:
			build_personnel_door(x-3.10,x-1.62)
		else:
			add_wall(x-3.10,z,1.48,0.18)
		add_wall(x+1.62,z,1.38,0.18)
		if x+3.0+6>size.x: add_wall(x+3.0,z,size.x-x-3.0,0.18)
	sign_at("↑   SORTIE %d"%(index+1),Vector2(x,0.04),Color("#ffebc0"))
	sign_at("↑   ENTRÉE %d"%(index+1),Vector2(x,depth-0.08),Color("#ffebc0"))
	sign_at("BAIE %02d"%(index+1),at+Vector2(0,3.05),Color("#f9ead0"))
	var parking := Rect2(x-1.70,-10.45,3.40,5.90)
	make_parking(parking,"P %02d"%(index+1),false)
	var waiting_marker := label_at(self,"",Vector3.ZERO)
	waiting_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waiting_marker.font_size = 28
	waiting_marker.outline_size = 9
	waiting_marker.outline_modulate = Color("#203539")
	waiting_marker.modulate = WAITING_PARKING_COLOR
	waiting_marker.hide()
	var lever_at := at+Vector2(3.0,3.5)
	var lever := Miniature.lift_control(self,lever_at)
	var label := label_at(lever.root,"PONT %02d"%(index+1),Vector3(0,1.17,0))
	label.pixel_size = 0.0032 if eye_level else 0.0055
	cells[cell(lever_at)] = {"kind":"lift"}
	var lift := Neighborhood.lift(self,at)
	Neighborhood.dress_bay(self,at)
	var bay := {"at":at,"gates":gates,"car":null,"tires":[],"status":"","order":{},
		"lift":lift,"lift_height":0.0,"lift_raised":false,
		"lever_at":lever_at,"lever":lever,"hood":null,"parking":parking,
		"stored_wheels":{},"waiting_marker":waiting_marker,"work_markers":[],
		"intake_guide":build_placement_guide(Rect2(at-Vector2(1.60,2.39),Vector2(3.20,4.78)),true),
		"parking_guide":build_placement_guide(parking)}
	bays.append(bay)

func build_placement_guide(area: Rect2, show_arrow := false) -> Dictionary:
	var guide := Node3D.new()
	var center := area.get_center()
	var half := area.size*0.5
	guide.position = Vector3(center.x,0.10,center.y)
	add_child(guide)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = PLACEMENT_GUIDE_COLOR
	for side in [-1,1]:
		for end in [-1,1]:
			var side_bar: MeshInstance3D = game.box(guide,Vector3(0.09,0.018,0.91),
				Vector3(side*half.x,0,end*(half.y-0.41)),PLACEMENT_GUIDE_COLOR)
			var end_bar: MeshInstance3D = game.box(guide,Vector3(0.63,0.018,0.09),
				Vector3(side*(half.x-0.27),0,end*half.y),PLACEMENT_GUIDE_COLOR)
			for bar in [side_bar,end_bar]:
				bar.material_override = material
				bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if show_arrow:
			var arrow: MeshInstance3D = game.box(guide,Vector3(0.075,0.018,0.38),
				Vector3(side*0.12,0,-half.y-0.46),PLACEMENT_GUIDE_COLOR)
			arrow.rotation.y = side*0.62
			arrow.material_override = material
			arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guide.hide()
	return {"root":guide,"material":material}

func show_placement_guide(index: int, at_lift: bool, ready: bool, partner: Dictionary = {}) -> void:
	for i in range(bays.size()):
		var bay := bays[i]
		var partner_here: bool = partner.get("index",-1)==i
		for lifting in [true,false]:
			var guide: Dictionary = bay.intake_guide if lifting else bay.parking_guide
			var local_guide: bool = index==i and at_lift==lifting
			var guest_guide: bool = partner_here and partner.lifting==lifting
			guide.root.visible = local_guide or guest_guide
			var is_ready: bool = (local_guide and ready) or (guest_guide and partner.ready)
			guide.material.albedo_color = PLACEMENT_READY_COLOR if is_ready else PLACEMENT_GUIDE_COLOR

func show_intake_car(index: int, view_size: float) -> void:
	if index<0:
		intake_car_marker.hide()
		return
	var bay := bays[index]
	intake_car_marker.text = "%s · BAIE %02d\n▼"%[bay.order.name,index+1]
	intake_car_marker.position = bay.car.position+Vector3(0,2.45,-1.35)
	intake_car_marker.pixel_size = view_size*0.00082
	intake_car_marker.show()

func show_waiting_parking(view_size: float, service_active: bool) -> void:
	for bay in bays:
		var marker: Label3D = bay.waiting_marker
		var slot: int = bay.get("wait_slot",-1)
		if not service_active or slot<0:
			marker.hide()
			continue
		var area: Rect2 = bays[slot].parking
		var center := area.get_center()
		marker.text = "%s\nP %02d\n▼"%[bay.order.name,slot+1]
		marker.position = Vector3(center.x,1.6,center.y-0.60)
		marker.pixel_size = view_size*0.00076
		marker.show()

func show_work_markers(index: int, cues: Array[Dictionary], view_size: float) -> void:
	var markers: Array = bays[index].work_markers
	while markers.size()<cues.size():
		var marker := label_at(self,"",Vector3.ZERO)
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.font_size = 28
		marker.outline_size = 10
		marker.outline_modulate = Color("#26383d")
		marker.no_depth_test = not eye_level
		markers.append(marker)
	for i in range(markers.size()):
		var marker: Label3D = markers[i]
		if i>=cues.size():
			marker.hide()
			continue
		var cue := cues[i]
		var ready: bool = cue.get("ready",false)
		var compact: bool = cue.get("compact",false)
		if eye_level:
			marker.text = "▼"
			marker.pixel_size = clampf(get_viewport().get_camera_3d().position.distance_to(cue.at)*0.00125,0.001,0.010)
		elif compact and view_size>24.0:
			marker.text = cue.label+"\n▼" if ready else "▼"
		else:
			marker.text = ("A / F · " if ready else "")+cue.label+"\n▼"
		marker.position = cue.at
		if not eye_level: marker.pixel_size = view_size*(0.00065 if compact else 0.00076)
		marker.modulate = PLACEMENT_READY_COLOR if ready else WORK_MARKER_COLOR
		marker.show()

func build_arrival_space(x: float) -> void:
	var area := Rect2(x-1.70,24.9,3.40,5.90)
	arrivals.append(area)
	make_parking(area,"A %02d"%arrivals.size(),true)

func make_parking(area: Rect2, text: String, from_south: bool) -> void:
	slab(area,0.010,Color("#95917d") if from_south else Color("#7e9291"))
	var center_point := area.get_center()
	for x in [area.position.x,area.end.x]:
		game.box(self,Vector3(0.065,0.013,area.size.y),Vector3(x,0.065,center_point.y),Color("#e5d6a6"))
	game.box(self,Vector3(area.size.x,0.013,0.065),Vector3(center_point.x,0.065,area.position.y),Color("#e5d6a6"))
	var z := area.position.y-0.45 if from_south else area.end.y+0.45
	var caption := label_at(self,text,Vector3(center_point.x,0.072,z))
	caption.rotation_degrees.x = -90
	caption.pixel_size = 0.021

func spawn_car(holder: Dictionary, order: Dictionary, point: Vector2, yaw: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.rotation.y = yaw
	root.position = Vector3(point.x,0,point.y)
	var visuals := Neighborhood.vehicle(root,order.vehicle)
	holder.car = root
	holder.hood = visuals.hood
	holder.tires = visuals.tires
	holder.lights = visuals.lights
	holder.wipers = visuals.wipers
	holder.discs = visuals.discs
	car_holders.append(holder)

func transfer_car(source: Dictionary, target: Dictionary) -> void:
	car_holders.erase(source)
	for key in ["car","hood","tires","lights","wipers","discs"]: target[key] = source[key]
	clear_car_references(source)
	car_holders.append(target)

func remove_car(holder: Dictionary) -> void:
	car_holders.erase(holder)
	holder.car.hide()
	holder.car.queue_free()
	clear_car_references(holder)

func clear_car_references(holder: Dictionary) -> void:
	holder.car = null
	holder.hood = null
	holder.tires = []
	holder.lights = {}
	holder.wipers = []
	holder.discs = []
	holder.light_timer = 0.0
	holder.wiper_phase = 0.0
	for wheel in holder.get("stored_wheels",{}).keys(): clear_stored_wheel(holder,wheel)

func store_wheel(bay: Dictionary, index: int) -> void:
	var offset: Vector2 = WHEEL_OFFSETS[index]
	offset += Vector2(signf(offset.x)*0.60,signf(offset.y)*0.42)
	var model := tire_model(self,Vector3(bay.at.x+offset.x,0.18,bay.at.y+offset.y),Color("#514945"))
	model.rotation.z = 0
	bay.stored_wheels[index] = model

func clear_stored_wheel(bay: Dictionary, index: int) -> void:
	if not bay.stored_wheels.has(index): return
	bay.stored_wheels[index].hide()
	bay.stored_wheels[index].queue_free()
	bay.stored_wheels.erase(index)

func bearing_clip(bad: bool) -> AudioStreamWAV:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 16000
	var data := PackedByteArray()
	data.resize(9600)
	for i in range(4800):
		var t := i/16000.0
		var envelope := minf(t*40.0,(0.3-t)*16.0)
		var sound := sin(t*TAU*105.0)*0.23
		if bad: sound += sin(t*TAU*620.0)*sin(t*TAU*34.0)*0.62
		data.encode_s16(i*2,int(sound*envelope*24000))
	clip.data = data
	return clip

func play_bearing_test(bad: bool) -> void:
	bearing_audio.stream = bearing_clips[int(bad)]
	bearing_audio.play()

func update_lights(bay: Dictionary, enabled: bool, fault: String) -> void:
	for group in bay.lights:
		for i in range(bay.lights[group].size()):
			var lamp: MeshInstance3D = bay.lights[group][i]
			var color: Color = lamp.get_meta("lens")
			var failed: bool = enabled and group==fault and i==0
			lamp.material_override.albedo_color = color.darkened(0.72) if failed else color
			lamp.material_override.emission_enabled = enabled and not failed
			lamp.material_override.emission = color
			lamp.material_override.emission_energy_multiplier = 0.62

func flash_lights(bay: Dictionary, fault: String) -> void:
	bay.light_timer = 2.1
	update_lights(bay,true,fault)

func lift_moving(bay: Dictionary) -> bool:
	var goal := LIFT_TRAVEL if bay.lift_raised else 0.0
	return not is_equal_approx(bay.lift_height,goal)

func animate_bays(dt: float, active_action: Dictionary, partner_action: Dictionary = {}) -> void:
	for i in range(bays.size()):
		var bay := bays[i]
		var previous_height: float = bay.lift_height
		var target := LIFT_TRAVEL if bay.lift_raised else 0.0
		bay.lift_height = move_toward(previous_height,target,dt*lift_speed)
		if bay.lift_height!=previous_height:
			Neighborhood.set_lift(bay.lift,bay.lift_height)
		Miniature.set_lift_control(bay.lever,bay.lift_raised,lift_moving(bay))
		if not is_instance_valid(bay.car): continue
		var approach := 1.0-smoothstep(0.08,0.95,vehicle_position(bay).distance_to(bay.at))
		bay.car.position.y = 0.12*approach+bay.lift_height
		var active := str(active_action.get("id","")) if active_action.get("bay",-1)==i else ""
		if active=="" and partner_action.get("bay",-1)==i: active = str(partner_action.get("id",""))
		var hood_open: bool = bay.status=="parked" and active in Catalog.HOOD_ACTIONS
		bay.hood.rotation.x = move_toward(bay.hood.rotation.x,-1.19 if hood_open else 0.0,dt*2.9)
		if bay.get("light_timer",0.0)>0.0:
			bay.light_timer = move_toward(bay.light_timer,0.0,dt)
			if bay.light_timer==0.0: update_lights(bay,false,"")
		var wiping: bool = bay.status=="parked" and active=="wipers_test"
		bay.wiper_phase = fmod(bay.get("wiper_phase",0.0)+dt*TAU/0.60,TAU) if wiping else 0.0
		var sweep := 0.475*(1.0-cos(bay.wiper_phase))
		for blade in bay.wipers:
			blade.rotation.y = move_toward(blade.rotation.y,sweep,dt*5.0)

func install_compressor() -> void:
	var station: Dictionary = stations.tool_pressure
	Neighborhood.fit(station.root,Neighborhood.COMPRESSOR,Vector3(0.65,0.31,0.22),Vector3(0,station.height,-0.22))

func install_waiting_room_cushions() -> void:
	for i in range(seats.size()):
		var station: Dictionary = stations["seat_%d"%i]
		Miniature.bevel_box(station.root,Vector3(0.51,0.11,0.70),Vector3(0.10,station.height+0.075,0),
			Color("#55857b"),0.042)

func build_vendor() -> void:
	van = Node3D.new()
	add_child(van)
	van.position = Vector3(vendor_at.x,0,vendor_at.y)
	Neighborhood.fit(van,Neighborhood.DELIVERY,Vector3(3.35,1.76,1.70),Vector3.ZERO,PI/2.0)
	Miniature.bevel_box(van,Vector3(1.58,0.055,0.36),Vector3(-0.38,1.52,-0.90),Color("#ddbd83"),0.015)
	label_at(van,"LA FOURGONNETTE",Vector3(0,1.87,-0.68))
	van.hide()

func build_personnel_door(left: float, right: float) -> void:
	var area := personnel_door_area
	add_wall(left,area.position.y,area.position.x-left,area.size.y)
	add_wall(area.end.x,area.position.y,right-area.end.x,area.size.y)
	personnel_door = Node3D.new()
	add_child(personnel_door)
	personnel_door.position = Vector3(area.position.x,0.06,area.get_center().y)
	var width := area.size.x
	var height := 2.17 if eye_level else 0.77
	game.box(personnel_door,Vector3(width-0.025,height,0.09),Vector3(width/2,height*0.5+0.005,0),Color("#628c82"))
	game.box(personnel_door,Vector3(0.52,0.37 if eye_level else 0.23,0.105),
		Vector3(width/2,1.55 if eye_level else 0.54,0),Color("#a9c3bc"))
	game.box(personnel_door,Vector3(0.12,0.04,0.16),
		Vector3(width-0.15,1.06 if eye_level else 0.34,0),Color("#dfbf79"))
	if eye_level:
		game.box(self,Vector3(width,CEILING_HEIGHT-height-0.06,area.size.y),
			Vector3(area.get_center().x,(CEILING_HEIGHT+height+0.06)*0.5,area.get_center().y),Color("#d7d6c4"))
	game.box(self,Vector3(width,0.022,0.36),Vector3(area.get_center().x,0.058,area.get_center().y),Color("#728e85"))
	sign_at("PORTE PIÉTONNE",Vector2(area.get_center().x,floor_inside.end.y+0.56),Color("#fff0cf"))

func animate_personnel_door(player: Vector2, dt: float, partner := Vector2.INF) -> void:
	var approach := personnel_door_area.grow_individual(0.10,0.95,0.10,0.95)
	var near := approach.has_point(player) or approach.has_point(partner)
	personnel_door.rotation.y = move_toward(personnel_door.rotation.y,-PI/2 if near else 0.0,dt*8.0)

func make_visitor(at: Vector2, color: Color) -> Dictionary:
	var person := Node3D.new()
	add_child(person)
	person.position = Vector3(at.x,0.08,at.y)
	game.box(person,Vector3(0.41,0.46,0.31),Vector3(0,0.64,0),color)
	game.box(person,Vector3(0.32,0.33,0.30),Vector3(0,1.04,0),Color("#c99d83"))
	game.box(person,Vector3(0.34,0.13,0.32),Vector3(0,1.17,0),Color("#625650"))
	for x in [-0.115,0.115]: game.box(person,Vector3(0.15,0.42,0.17),Vector3(x,0.24,0),Color("#4d606c"))
	var meter := label_at(person,"",Vector3(0,1.57,0))
	meter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	meter.pixel_size = 0.007
	var receipt := label_at(person,"",Vector3(0,2.06,0))
	receipt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	receipt.font_size = 42
	receipt.modulate = Color("#a7f3bf")
	receipt.hide()
	var hands := Node3D.new()
	person.add_child(hands)
	hands.position = Vector3(0,0.63,0.22)
	for side in [-1,1]:
		game.box(hands,Vector3(0.13,0.15,0.29),Vector3(side*0.22,0,-0.035),color)
		game.box(hands,Vector3(0.105,0.10,0.115),Vector3(side*0.18,0.03,0.12),Color("#c99d83"))
	var magazine: MeshInstance3D = game.box(hands,Vector3(0.31,0.037,0.24),Vector3(0,0.049,0.13),Color("#e7bc70"))
	game.box(magazine,Vector3(0.019,0.048,0.22),Vector3(0,0.006,0),Color("#f9ebd2"))
	var snack: MeshInstance3D = game.box(hands,Vector3(0.13,0.21,0.10),Vector3(0.12,0.11,0.10),Color("#be755f"))
	hands.hide()
	return {"root":person,"meter":meter,"receipt":receipt,"hands":hands,"magazine":magazine,"snack":snack}

func build_selection() -> void:
	select_corners = Miniature.selection_corners(game,self)
	preview = game.box(self,Vector3(0.95,0.022,0.95),Vector3.ZERO,Color("#77b49c"))
	preview.hide()

func center(tile: Vector2i) -> Vector2:
	return Vector2(tile)+Vector2(0.5,0.5)

func cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x),floori(p.y))

func playable_area() -> Rect2:
	return Rect2(0,-NORTH_APRON,size.x,size.y+NORTH_APRON)

func customer_entrance_tile() -> Vector2i:
	return cell(portal+Vector2.DOWN*0.6)

func office_tiles() -> Rect2i:
	if compact: return Rect2i(0,0,5,3)
	return Rect2i(0,6,7,5) if variant==2 else Rect2i(0,0,7,5)

func waiting_area() -> Rect2:
	if compact: return Rect2(0.18,4.08,4.72,3.72)
	return Rect2(0.18,0.18,6.72,5.52) if variant==2 else Rect2(0.18,5.78,6.72,5.02)

func amenity_active(id: String) -> bool:
	return stations.has(id) and cells.get(stations[id].tile,{}).get("id")==id and waiting_area().has_point(station_point(id))

func amenity_access(id: String, from: Vector2) -> Vector2:
	var station := station_point(id)
	var turn: int = stations[id].turn
	for offset in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
		var point: Vector2 = station+rotate_offset(offset,turn)
		if not waiting_area().has_point(point) or not clear_at(point,0.16): continue
		var path := walk_path(from,point)
		if not path.is_empty() and path.back()==point: return point
	return Vector2.INF

func blocked_tile(tile: Vector2i) -> bool:
	var p := center(tile)
	if not playable_area().has_point(p): return true
	var area := Rect2(Vector2(tile),Vector2.ONE)
	for wall in wall_rects:
		if wall.intersection(area).get_area()>0.14 or wall.grow(0.10).has_point(p): return true
	return false

func placement_ok(tile: Vector2i, id: String) -> bool:
	var p := center(tile)
	if blocked_tile(tile) or cells.has(tile): return false
	if id=="used_tire" and used_tire_zone.has_point(tile): return true
	if p.y<0: return false
	if p.y>=floor_inside.end.y and p.x>=bays[0].at.x-4.5: return false
	if id=="reception":
		var reception_area := Rect2(1.0,8.0,3.0,3.0) if compact else Rect2(2.0,11.0,3.0,3.0)
		return reception_area.has_point(p)
	var seat_area := waiting_area() if compact else Rect2(0.55,waiting_room.y-1.45,5.95,4.75)
	if id.begins_with("seat_") and not seat_area.has_point(p): return false
	if p.distance_to(desk_side)<0.8 or p.distance_to(queue_head)<0.75 or p.distance_to(checkout_head)<0.75: return false
	if p.x>portal.x-1.1 and p.x<portal.x+1.0 and p.y>floor_inside.end.y-(4.0 if compact else 5.0): return false
	if not id.begins_with("seat_") and p.x>2.0 and p.x<left_width-1.3 and p.y>=waiting_room.y-0.7 and p.y<=waiting_room.y+3.1: return false
	for bay in bays:
		if absf(p.x-bay.at.x)<2.12: return false
	return not van.visible or not Rect2(5.7,18.4,3.65,2.0).has_point(p)

static func turn_yaw(turn: int) -> float:
	return -turn*PI/2.0

static func rotate_offset(offset: Vector2, turn: int) -> Vector2:
	match posmod(turn,4):
		1: return Vector2(-offset.y,offset.x)
		2: return -offset
		3: return Vector2(offset.y,-offset.x)
	return offset

func station_footprint(id: String, anchor: Vector2i, turn := -1) -> Rect2i:
	var station: Dictionary = stations[id]
	var orientation: int = station.turn if turn<0 else turn
	var span: int = station.span
	return Rect2i(anchor,Vector2i(span,1) if orientation%2==0 else Vector2i(1,span))

func station_tiles(id: String, anchor: Vector2i, turn := -1) -> Array[Vector2i]:
	var bounds := station_footprint(id,anchor,turn)
	var tiles: Array[Vector2i] = []
	for z in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x): tiles.append(Vector2i(x,z))
	return tiles

func station_point(id: String) -> Vector2:
	var station: Dictionary = stations[id]
	return Rect2(station_footprint(id,station.tile)).get_center()

func reception_approaches(point: Vector2, turn: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for x in [-0.5,0.5]:
		for z in [-1.0,1.14]: points.append(point+rotate_offset(Vector2(x,z),turn))
	return points

func behind_reception(point: Vector2, from: Vector2) -> bool:
	return (from-point).dot(rotate_offset(Vector2.UP,stations.reception.turn))>0.24

func bay_waiting_places() -> Array[Vector2]:
	var places: Array[Vector2] = []
	for z in [0.12,1.12]:
		for x in ([2.42,3.37,4.30] if compact else [2.62,3.82,5.02]):
			var point := Vector2(x,waiting_room.y+z)
			if clear_at(point,0.16): places.append(point)
	if places.is_empty(): places.append(waiting_room)
	return places

func parked_customer_point(slot: int) -> Vector2:
	var point := Vector2(left_width-1.25,waiting_room.y+0.12+slot*0.9)
	if clear_at(point,0.16): return point
	var places := bay_waiting_places()
	return places[slot%places.size()]

func remove_station_cells(id: String) -> void:
	for tile in station_tiles(id,stations[id].tile):
		if cells.get(tile,{}).get("id")==id: cells.erase(tile)

func pose_station(id: String, tile: Vector2i, turn: int) -> void:
	var root: Node3D = stations[id].root
	var p := Rect2(station_footprint(id,tile,turn)).get_center()
	root.position = Vector3(p.x,0.07,p.y)
	root.rotation.y = turn_yaw(turn)
	var caption: Label3D = stations[id].get("caption")
	if caption!=null: caption.rotation.y = -root.rotation.y
	root.show()

func move_station(id: String, tile: Vector2i, turn := -1) -> void:
	var station: Dictionary = stations[id]
	remove_station_cells(id)
	station.tile = tile
	if turn>=0: station.turn = posmod(turn,4)
	var orientation: int = station.turn
	pose_station(id,tile,orientation)
	var p := station_point(id)
	if id=="reception":
		reception_at = p+rotate_offset(Vector2(0.5,0),orientation)
		checkout_at = p+rotate_offset(Vector2(-0.5,0),orientation)
		queue_head = reception_at+rotate_offset(Vector2(0,1.14),orientation)
		checkout_head = checkout_at+rotate_offset(Vector2(0,1.14),orientation)
		desk_side = p+rotate_offset(Vector2.UP,orientation)
	elif id.begins_with("seat_"):
		seats[int(id.trim_prefix("seat_"))] = p+rotate_offset(Vector2(0.23,0),orientation)
	for occupied in station_tiles(id,tile): cells[occupied] = {"kind":"station","id":id}

func can_see(from: Vector2, target: Vector2, allow_source := false) -> bool:
	for bay in bays:
		for shutter in bay.gates:
			if shutter.position.y>=1.35: continue
			var area := gate_area(shutter)
			if area.has_point(from) or area.has_point(target): return false
			var start := Vector2(area.position.x,shutter.position.z)
			var end := Vector2(area.end.x,shutter.position.z)
			if Geometry2D.segment_intersects_segment(from,target,start,end)!=null: return false
	var source_cell := cell(from)
	var target_cell := cell(target)
	var station_id: String = cells.get(target_cell,{}).get("id","")
	for i in range(1,13):
		var point := from.lerp(target,float(i)/13)
		for wall in wall_rects:
			if wall.has_point(point): return false
		var tile := cell(point)
		if tile!=target_cell and (not allow_source or tile!=source_cell) and cells.has(tile):
			if station_id=="" or cells[tile].get("id")!=station_id: return false
		for holder in car_holders:
			if vehicle_contains(holder,point) and not vehicle_contains(holder,target): return false
	return true

func blocks_traffic(tile: Vector2i) -> bool:
	var footprint := Rect2(Vector2(tile),Vector2.ONE)
	if footprint.intersects(Rect2(pedestrian_access.x-0.81,-2.2,1.63,3.19)): return true
	if footprint.intersects(personnel_door_area.grow_individual(0.0,1.1,0.0,1.1)): return true
	for bay in bays:
		var lane := Rect2(Vector2(bay.at.x-CAR_HALF.x,-NORTH_APRON),Vector2(CAR_HALF.x*2,size.y+NORTH_APRON))
		if lane.intersects(footprint) or footprint.intersects(bay.parking.grow(0.55)): return true
	for area in arrivals:
		if footprint.intersects(area.grow(0.55)): return true
	return false

func vehicle_position(bay: Dictionary) -> Vector2:
	return Vector2(bay.car.position.x,bay.car.position.z)

func vehicle_contains(bay: Dictionary, point: Vector2, radius := 0.0) -> bool:
	var delta := (point-vehicle_position(bay)).rotated(bay.car.rotation.y)
	return absf(delta.x)<CAR_HALF.x+radius and absf(delta.y)<CAR_HALF.y+radius

func vehicle_shape(point: Vector2, yaw: float) -> PackedVector2Array:
	var half := CAR_HALF
	var corners := PackedVector2Array()
	for corner in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
		corners.append(point+corner.rotated(-yaw))
	return corners

func vehicle_bounds(poly: PackedVector2Array) -> Rect2:
	var result := Rect2(poly[0],Vector2.ZERO)
	for point in poly: result = result.expand(point)
	return result

func hits_rectangle(poly: PackedVector2Array, bounds: Rect2, box: Rect2) -> bool:
	if not bounds.intersects(box): return false
	var outline := PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])
	return not Geometry2D.intersect_polygons(poly,outline).is_empty()

func gate_area(gate: Node3D) -> Rect2:
	return Rect2(gate.position.x-1.55,gate.position.z-0.1,3.1,0.2)

func vehicle_can_move(bay: Dictionary, point: Vector2, yaw: float, use_road := false) -> bool:
	var poly := vehicle_shape(point,yaw)
	var bounds := vehicle_bounds(poly)
	var area := Rect2(0,ROAD_TOP,size.x+6.5,ARRIVAL_ROAD_END-ROAD_TOP) if use_road else playable_area()
	if not area.encloses(bounds): return false
	for wall in wall_rects:
		if hits_rectangle(poly,bounds,wall): return false
	if van.visible and hits_rectangle(poly,bounds,Rect2(5.75,18.52,3.5,1.84)): return false
	for x in range(floori(bounds.position.x),ceili(bounds.end.x)):
		for z in range(floori(bounds.position.y),ceili(bounds.end.y)):
			if cells.has(Vector2i(x,z)) and hits_rectangle(poly,bounds,Rect2(x,z,1,1)): return false
	for service_bay in bays:
		for gate in service_bay.gates:
			if gate.position.y<2.1 and hits_rectangle(poly,bounds,gate_area(gate)):
				return false
	for other in car_holders:
		if other==bay: continue
		var shape := vehicle_shape(vehicle_position(other),other.car.rotation.y)
		if bounds.intersects(vehicle_bounds(shape)) and not Geometry2D.intersect_polygons(poly,shape).is_empty():
			return false
	return true

func clear_at(p: Vector2, radius := PLAYER_RADIUS) -> bool:
	if not playable_area().grow(-radius).has_point(p): return false
	for wall in wall_rects:
		if wall.grow(radius).has_point(p): return false
	var tile := cell(p)
	for dx in [-1,0,1]:
		for dz in [-1,0,1]:
			var other := tile+Vector2i(dx,dz)
			if cells.has(other) and Rect2(Vector2(other),Vector2.ONE).grow(radius).has_point(p): return false
	if van.visible and Rect2(5.75,18.52,3.5,1.84).grow(radius).has_point(p): return false
	for bay in bays:
		for shutter in bay.gates:
			if shutter.position.y<1.35 and gate_area(shutter).grow(radius).has_point(p): return false
	for holder in car_holders:
		if vehicle_contains(holder,p,radius): return false
	return true

func walk_path(from: Vector2, goal: Vector2) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if can_see(from,goal,true):
		route.append(goal)
		return route
	var start := cell(from)
	var queue: Array[Vector2i] = [start]
	var previous := {start:start}
	var nearest := start
	var nearest_distance := from.distance_to(goal)
	var read := 0
	while read<queue.size():
		var entry := queue[read]
		read += 1
		var p := center(entry)
		var distance := p.distance_to(goal)
		if distance<nearest_distance:
			nearest = entry
			nearest_distance = distance
			if distance<=1.08 and can_see(p,goal,true): break
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = entry+offset
			if previous.has(next) or not clear_at(center(next),0.16): continue
			if not can_see(p,center(next),true): continue
			previous[next] = entry
			queue.append(next)
	if can_see(center(nearest),goal,true): route.append(goal)
	while nearest!=start:
		route.push_front(center(nearest))
		nearest = previous[nearest]
	return route

func slab(area: Rect2, y: float, color: Color) -> void:
	var p := area.get_center()
	game.box(self,Vector3(area.size.x,0.085,area.size.y),Vector3(p.x,y,p.y),color)

func add_wall(x: float,z: float,w: float,h: float) -> void:
	var area := Rect2(x,z,w,h)
	wall_rects.append(area)
	var p := area.get_center()
	Miniature.bevel_box(self,Vector3(w,0.56,h),Vector3(p.x,0.32,p.y),Color("#d7c5a9"),0.022)
	Miniature.bevel_box(self,Vector3(w+0.035,0.064,h+0.035),Vector3(p.x,0.624,p.y),Color("#f2e4c8"),0.017)
	if eye_level:
		game.box(self,Vector3(w,CEILING_HEIGHT-0.65,h),Vector3(p.x,(CEILING_HEIGHT+0.65)*0.5,p.y),Color("#d7d6c4"))

func label_at(parent: Node3D, title: String, at: Vector3) -> Label3D:
	var caption := Label3D.new()
	caption.text = title
	caption.position = at
	if eye_level:
		caption.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		caption.visibility_range_begin = 1.15
		caption.visibility_range_end = 9.0
		caption.font_size = 24
	else: caption.rotation_degrees.x = -52
	caption.modulate = Color("#fff0da")
	caption.outline_modulate = Color("#354b51")
	caption.outline_size = 5
	caption.pixel_size = 0.0036 if eye_level else 0.0074
	parent.add_child(caption)
	return caption

func sign_at(title: String,p: Vector2,color: Color) -> void:
	label_at(self,title,Vector3(p.x,1.65 if eye_level else 0.66,p.y)).modulate = color

func supply_model(parent: Node3D, kind: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	if Neighborhood.spare_part(root,kind): return root
	match kind:
		"fresh_oil","empty_bottle","coolant","coolant_empty":
			var color := {"fresh_oil":Color("#80b099"),"coolant":Color("#74b5cf")}.get(kind,Color("#bbc5bf")) as Color
			game.box(root,Vector3(0.19,0.29,0.13),Vector3(0,0.15,0),color)
			game.box(root,Vector3(0.08,0.05,0.08),Vector3(0.03,0.32,0),Color("#eadbbe"))
			game.box(root,Vector3(0.13,0.11,0.015),Vector3(0,0.15,0.071),Color("#f5e7c9"))
		"old_muffler":
			Miniature.repair_part(root,kind)
		_:
			if Catalog.PARTS.has(kind):
				Miniature.repair_part(root,kind)
				return root
			var color := Color("#b895c0") if kind=="new_battery" else Color("#6a626d")
			game.box(root,Vector3(0.35,0.2,0.27),Vector3(0,0.09,0),color)
			for side in [-1,1]:
				game.box(root,Vector3(0.055,0.06,0.06),Vector3(side*0.11,0.21,0),Color("#dbc991"))
	return root

func tool_color(kind: String) -> Color:
	return {"tires":Color("#d69c62"),"oil":Color("#74ad91"),"inspection":Color("#7caec9"),"battery":Color("#b895c0"),"coolant":Color("#7bb9cf"),"pressure":Color("#e4bc77"),
		"ratchet":Color("#b1b9ba"),"probe":Color("#659b91"),"puller":Color("#b46755")}[kind]

func tool_model(parent: Node3D, kind: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var color := tool_color(kind)
	match kind:
		"tires":
			Neighborhood.impact_wrench(root)
		"oil":
			game.box(root,Vector3(0.38,0.15,0.27),Vector3(0,0.03,0),color)
			game.box(root,Vector3(0.3,0.016,0.19),Vector3(0,0.11,0),Color("#324e46"))
		"pressure":
			game.box(root,Vector3(0.16,0.12,0.27),Vector3(0,0.05,0),color)
			game.box(root,Vector3(0.1,0.015,0.11),Vector3(0,0.12,0.05),Color("#374b53"))
		"inspection":
			game.box(root,Vector3(0.27,0.095,0.23),Vector3(0,0.04,0),color)
			game.box(root,Vector3(0.2,0.02,0.15),Vector3(0,0.1,0),Color("#304f64"))
		"ratchet":
			Miniature.bevel_box(root,Vector3(0.085,0.065,0.35),Vector3(0,0.08,0),color,0.018)
			Miniature.cylinder(root,0.078,0.05,Vector3(0,0.08,0.17),color,12)
		"probe":
			Miniature.bevel_box(root,Vector3(0.13,0.09,0.23),Vector3(0,0.08,0),color,0.02)
			Miniature.bevel_box(root,Vector3(0.028,0.03,0.21),Vector3(0,0.08,0.19),Color("#bdc7c9"),0.008)
		"puller":
			Miniature.bevel_box(root,Vector3(0.21,0.075,0.11),Vector3(0,0.075,0),color,0.016)
			for x in [-0.09,0.09]:
				Miniature.bevel_box(root,Vector3(0.055,0.06,0.27),Vector3(x,0.075,0.09),color,0.012)
	return root

func tire_model(parent: Node3D, pos: Vector3, color := Color("#303b40")) -> Node3D:
	return Neighborhood.loose_tire(parent,pos,color)

func trolley_model(parent: Node3D, pos: Vector3) -> Node3D:
	return Miniature.trolley(parent,pos)

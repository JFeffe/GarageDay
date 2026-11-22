extends Control

const Race := preload("res://endurance_race.gd")
const TRACK_SIZE := Vector2(240,132)
const POINTS := [
	Vector2(118,100),Vector2(166,100),Vector2(206,81),Vector2(215,60),
	Vector2(191,32),Vector2(160,37),Vector2(142,62),Vector2(107,61),
	Vector2(85,34),Vector2(54,32),Vector2(32,53),Vector2(31,79),Vector2(54,97),Vector2(86,100),
]
const PIT_START := Vector2(69,119)
const PIT_STEP := 13.0
const INK := Color("#101f23")
const CAR_HIGHLIGHT := Color("#fff1ce")

var race: Race
var live := false
var animate := false
var redraw_elapsed := 0.0
var route := Curve2D.new()
var outline: PackedVector2Array
var length := 0.0

func _ready() -> void:
	route.bake_interval = 3.0
	for i in range(POINTS.size()+1):
		var point: Vector2 = POINTS[i%POINTS.size()]
		var tangent: Vector2 = (POINTS[(i+1)%POINTS.size()]-POINTS[posmod(i-1,POINTS.size())])*0.13
		route.add_point(point,-tangent,tangent)
	length = route.get_baked_length()
	outline = route.get_baked_points()
	resized.connect(queue_redraw)
	set_process(animate)

func _process(dt: float) -> void:
	if not is_visible_in_tree(): return
	redraw_elapsed += dt
	if redraw_elapsed>=1.0/30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func car_transform(index: int) -> Transform2D:
	var car := race.cars[index]
	if car.state!=Race.State.TRACK:
		var slot := PIT_START+Vector2(index*PIT_STEP,0)
		return Transform2D(0.0,slot)
	var lap: float = car.distance
	if race.phase==Race.Phase.RACE: lap += race.fraction/race.lap_seconds(car)
	# Spread the grid over two lanes until the cars have built up real gaps.
	lap -= index*0.012*(1.0-smoothstep(0.0,25.0,race.elapsed))
	var at := fposmod(lap,1.0)*length
	var transform := route.sample_baked_with_rotation(at)
	transform.origin += transform.y*(2.5 if index%2==0 else -2.5)
	return transform

func _draw() -> void:
	if length<=0.0: return
	var scale_factor := minf(size.x/TRACK_SIZE.x,size.y/TRACK_SIZE.y)
	if scale_factor<=0.0: return
	var scale_to_size := Vector2.ONE*scale_factor if live else size/Vector2(214,102)
	var origin := (size-TRACK_SIZE*scale_to_size)/2.0
	if live: draw_rect(Rect2(Vector2.ZERO,size),Color("#192e31"))
	draw_set_transform(origin,0.0,scale_to_size)
	draw_polyline(outline,Color("#647f7b"),11.0,true)
	draw_polyline(outline,Color("#26393e"),8.0,true)
	draw_polyline(PackedVector2Array([Vector2(58,101),Vector2(69,119),Vector2(195,119),Vector2(205,88)]),Color("#aa895e"),3.0,true)
	if live:
		for y in range(4):
			for x in range(2):
				if (x+y)%2==0:
					draw_rect(Rect2(116.0+2*x,96.0+2*y,2,2),CAR_HIGHLIGHT)
	if race==null: return
	# Draw Garage Day over the field so both team colors remain visible in a pack.
	for index in range(race.cars.size()-1,-1,-1):
		var car := race.cars[index]
		if car.state==Race.State.OUT: continue
		var motion := car_transform(index)
		if live:
			draw_car(origin+motion.origin*scale_factor,motion.get_rotation(),scale_factor,car)
		else:
			draw_circle(motion.origin,5.3 if car.ours else 4.0,INK,true,-1,true)
			draw_circle(motion.origin,4.1 if car.ours else 2.8,car.color,true,-1,true)

func draw_car(point: Vector2, heading: float, scale_factor: float, car: Dictionary) -> void:
	draw_set_transform(point,heading,Vector2.ONE*scale_factor)
	var body := Rect2(-6,-3,12,6)
	draw_rect(body.grow(1),CAR_HIGHLIGHT if car.ours else INK)
	draw_rect(body,car.color)
	draw_rect(Rect2(-1,-2,4,4),Color("#2a4449"))
	draw_rect(Rect2(4,-2,2,4),car.color.lightened(0.38))

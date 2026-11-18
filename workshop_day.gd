extends RefCounted

const Catalog := preload("res://workshop_catalog.gd")

const LENGTH := 180.0
const OPENING_MINUTE := 7*60
const CLOSING_MINUTE := 17*60
const SNACK_BREAK := 10.0
const MAX_SNACKS := 4
const AMENITY_PATIENCE_RATE := 0.95
const LATE_INTERVAL := 10.0
const VENDOR_REROLL_COST := 25
const QUOTAS := [2,2,3,3,4,4,5,5,6,7]
const NAMES := ["Camille","Noah","Léa","Sacha","Maël","Zia","Alex","Inès","Charlie","Sam","Jules","Morgan"]
const VEHICLES := [
	["Berline","#7eabb9"],["Fourgonnette","#bfa274"],["Décapotable","#cb827c"],
	["Sportive","#e0af56"],["Voiture de luxe","#8386a4"],["Guimbarde","#98917a"],
]
const REPAIRS := ["tires","oil","inspection","battery","pressure","coolant"]
var random := RandomNumberGenerator.new()
var vendor_random := RandomNumberGenerator.new()
var day := 0
var rating := 10
var mode := "open"
var elapsed := 0.0
var arrivals := 0
var scheduled := 0
var appointments: Array[Dictionary] = []
var waiting: Array[Dictionary] = []
var cash := 0
var daily_cash := 0
var served := 0
var completed_repairs: Dictionary = {}
var purchases: Dictionary = {}
var next_day_services: Dictionary = {}
var active_services: Dictionary = {}
var vendor_offers: Array[Dictionary] = []
var vendor_day := -1
var vendor_reroll_day := -1
var evenings_without_rare := 0
var seen_rare_offers: Dictionary = {}
var guarantee_used := false
var serial := 0
var intro_brakes := false

func _init() -> void:
	random.randomize()
	vendor_random.randomize()

func start() -> bool:
	if mode!="open" or day>=10: return false
	day += 1
	elapsed = 0
	arrivals = 0
	scheduled = 0
	rating = 10
	guarantee_used = false
	daily_cash = 0
	served = 0
	completed_repairs.clear()
	mode = "day"
	active_services = next_day_services
	next_day_services = {}
	if active_services.has("advertising"):
		schedule_customer(32.0)
	return true

func nightly_offers() -> Array[Dictionary]:
	if vendor_day==day: return vendor_offers
	vendor_offers = draw_vendor_offers()
	remember_vendor_rare(vendor_offers)
	vendor_day = day
	return vendor_offers

func reroll_vendor() -> bool:
	if mode!="open" or day<1 or day>=QUOTAS.size() or vendor_reroll_day==day or cash<VENDOR_REROLL_COST:
		return false
	nightly_offers()
	var draw := draw_vendor_offers(true)
	if draw.size()!=3 or draw.all(func(offer: Dictionary) -> bool: return offer in vendor_offers):
		return false
	cash -= VENDOR_REROLL_COST
	vendor_reroll_day = day
	vendor_offers = draw
	remember_vendor_rare(vendor_offers)
	return true

func draw_vendor_offers(replacing := false) -> Array[Dictionary]:
	var regular: Array[Dictionary] = []
	var rare: Array[Dictionary] = []
	var repeat_regular: Array[Dictionary] = []
	var repeat_rare: Dictionary = {}
	for offer in Catalog.VENDOR_OFFERS:
		if vendor_purchase_record(offer).has(offer.id): continue
		var repeat: bool = replacing and offer in vendor_offers
		if offer.has("unlock_day"):
			if day<offer.unlock_day: continue
			if repeat: repeat_rare = offer
			else: rare.append(offer)
		elif repeat: repeat_regular.append(offer)
		else: regular.append(offer)
	if replacing and regular.is_empty() and rare.is_empty(): return []
	var draw: Array[Dictionary] = []
	var limited_regular_stock := regular.size()+repeat_regular.size()<3
	var force_rare := regular.size()<3 if replacing else evenings_without_rare>=2
	var rare_offer := draw_rare_offer(rare,force_rare)
	if replacing and limited_regular_stock and rare_offer.is_empty(): rare_offer = repeat_rare
	if not rare_offer.is_empty(): draw.append(rare_offer)
	elif not replacing:
		evenings_without_rare = 0 if rare.is_empty() else evenings_without_rare+1
	var first_regular := draw.size()
	while draw.size()<3 and not regular.is_empty():
		draw.append(regular.pop_at(vendor_random.randi_range(0,regular.size()-1)))
	while draw.size()<3 and not repeat_regular.is_empty():
		draw.append(repeat_regular.pop_at(vendor_random.randi_range(0,repeat_regular.size()-1)))
	if not replacing and not regular.is_empty() and draw.size()==vendor_offers.size() and draw.all(func(offer: Dictionary) -> bool:
		return offer in vendor_offers):
		draw[vendor_random.randi_range(first_regular,draw.size()-1)] = regular[vendor_random.randi_range(0,regular.size()-1)]
	if first_regular>0:
		draw.pop_front()
		draw.insert(vendor_random.randi_range(0,draw.size()),rare_offer)
	return draw

func remember_vendor_rare(offers: Array[Dictionary]) -> void:
	for offer in offers:
		if offer.has("unlock_day"):
			seen_rare_offers[offer.id] = true
			evenings_without_rare = 0
			return

func draw_rare_offer(eligible: Array[Dictionary], force: bool) -> Dictionary:
	if eligible.is_empty() or (not force and vendor_random.randf()>=0.40): return {}
	var unseen := eligible.filter(func(offer: Dictionary) -> bool: return not seen_rare_offers.has(offer.id))
	var pool := eligible if unseen.is_empty() else unseen
	return pool[vendor_random.randi_range(0,pool.size()-1)]

func vendor_purchase_record(offer: Dictionary) -> Dictionary:
	return next_day_services if offer.get("temporary",false) else purchases

func loyalty_bonus(order: Dictionary) -> int:
	return 8 if purchases.has("loyalty") and not order.late else 0

func call_customer() -> bool:
	if mode!="day" or elapsed+4.0>=LENGTH or appointments.size()+waiting.size()>=5: return false
	schedule_customer(elapsed+4.0)
	return true

func clock_label() -> String:
	var minute := OPENING_MINUTE+floori((CLOSING_MINUTE-OPENING_MINUTE)*clampf(elapsed/LENGTH,0.0,1.0))
	return "%02d h %02d"%[minute/60,minute%60]

func schedule_customer(at: float) -> void:
	var appointment := {"when":at,"order":new_order()}
	for i in range(appointments.size()):
		if appointments[i].when>at:
			appointments.insert(i,appointment)
			return
	appointments.append(appointment)

func new_order() -> Dictionary:
	serial += 1
	var left := REPAIRS.duplicate()
	for id in Catalog.UNLOCKS:
		if day>=Catalog.UNLOCKS[id]: left.append(id)
	var jobs: Array[String] = []
	var count := random.randi_range(1,mini(4,2+day/3))
	if day>=7: count = maxi(2,count)
	while jobs.size()<count:
		var job: String = left.pop_at(random.randi_range(0,left.size()-1))
		jobs.append(job)
		if job=="tires": left.erase("puncture")
		elif job=="puncture": left.erase("tires")
		if job=="brakes" and jobs.size()<count and left.has("tires") and random.randf()<0.35:
			left.erase("tires")
			left.erase("puncture")
			jobs.append("tires")
	var vehicle := random.randi_range(0,VEHICLES.size()-1)
	var issue := "battery" if "inspection" in jobs and not "battery" in jobs and jobs.size()<4 and random.randf()<0.58 else ""
	var patience := maxf(75,143-day*5)
	return {"id":serial,"name":NAMES[(serial+day-2)%NAMES.size()],"vehicle":vehicle,
		"required":jobs,"done":[],"paid":false,"issue":issue,"decision":"","patience":patience,
		"max_patience":patience,"late":false,"late_seconds":0.0,"wheels":[0,0,0,0],"oil":0,"battery":0,"coolant":false,
		"snacks_used":0,"snack_pause":0.0,"in_waiting_room":false,
		"service":{},"faults":{"bearing":random.randi_range(0,3),"puncture":random.randi_range(0,3),
			"damper":random.randi_range(0,1),"rear_lamp":random.randf()<0.5,
			"broken_panel":random.randf()<0.40,"bad_puncture":random.randf()<0.33,"module":random.randf()<0.46}}

func tick(dt: float, active_orders: Array[Dictionary], returning := false, room_rate := 1.0) -> void:
	if mode not in ["day","closing"]: return
	if mode=="day":
		elapsed = minf(LENGTH,elapsed+dt)
		var quota: int = QUOTAS[day-1]
		while scheduled<quota and elapsed>=2.0+scheduled*125.0/maxi(1,quota-1):
			var order := new_order()
			if intro_brakes and day==1 and scheduled==0:
				order.vehicle = 0
				order.required.assign(["brakes"])
				order.issue = ""
			waiting.append(order)
			scheduled += 1
			arrivals += 1
		while not appointments.is_empty() and elapsed>=appointments[0].when and appointments[0].when<LENGTH:
			waiting.append(appointments.pop_front().order)
			arrivals += 1
		if elapsed>=LENGTH:
			mode = "closing"
			appointments.clear()
	var patience_rate := 0.75 if purchases.has("lounge") else 1.0
	for order in waiting: lose_patience(order,dt,patience_rate)
	for order in active_orders:
		var rate := room_rate if order.get("in_waiting_room",false) else 1.0
		lose_patience(order,dt,0.63*patience_rate*rate)
	if mode=="closing" and waiting.is_empty() and appointments.is_empty() and active_orders.is_empty() and not returning:
		mode = "won" if day==10 else "open"
		if mode=="open": nightly_offers()

func lose_patience(order: Dictionary, dt: float, rate := 1.0) -> void:
	var pause := minf(dt,order.get("snack_pause",0.0))
	if pause>0.0:
		order.snack_pause -= pause
		dt -= pause
		if dt<=0.0: return
	if not order.late:
		var until_late: float = order.patience/rate
		order.patience = maxf(0,order.patience-dt*rate)
		if order.patience>0: return
		order.late = true
		late_penalty()
		dt = maxf(0,dt-until_late)
	order.late_seconds += dt
	while order.late_seconds>=LATE_INTERVAL and mode in ["day","closing"]:
		order.late_seconds -= LATE_INTERVAL
		late_penalty()

func late_penalty() -> void:
	if purchases.has("service_guarantee") and not guarantee_used and mode in ["day","closing"]:
		guarantee_used = true
		return
	penalty()

func penalty() -> void:
	if mode not in ["day","closing"]: return
	rating = maxi(0,rating-1)
	if rating==0: mode = "lost"

func invoice(order: Dictionary, total: int) -> void:
	cash += total
	daily_cash += total
	served += 1
	for id in order.done: completed_repairs[id] = completed_repairs.get(id,0)+1

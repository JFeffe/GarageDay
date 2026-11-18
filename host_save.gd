extends RefCounted

const RUN_FIELDS := ["day","rating","cash","purchases","next_day_services","vendor_offers","vendor_day",
	"vendor_reroll_day","evenings_without_rare","seen_rare_offers","serial"]

static func capture(w) -> String:
	var progress := {}
	for id in RUN_FIELDS: progress[id] = w.run.get(id)
	var decor := {}
	for id in w.site.stations:
		var station: Dictionary = w.site.stations[id]
		decor[id] = [station.tile,station.turn]
	return Marshalls.variant_to_base64({"version":1,"layout":w.layout,"progress":progress,"decor":decor,
		"equipment":w.equipment_snapshot(),"random":w.run.random.state,"vendor_random":w.run.vendor_random.state})

static func restore(w, encoded: String) -> bool:
	if encoded.is_empty() or encoded.length()>250000: return false
	var data: Variant = Marshalls.base64_to_variant(encoded)
	if not data is Dictionary or data.get("version")!=1: return false
	if not data.get("layout") is int or data.layout<0 or data.layout>=w.Map.LAYOUTS.size(): return false
	if not data.get("progress") is Dictionary or not data.get("decor") is Dictionary or not data.get("equipment") is Dictionary: return false
	for id in RUN_FIELDS:
		if not data.progress.has(id) or typeof(data.progress[id])!=typeof(w.run.get(id)): return false
	if data.progress.day<0 or data.progress.day>=10: return false
	for id in data.decor:
		var placement: Variant = data.decor[id]
		if not placement is Array or placement.size()!=2 or not placement[0] is Vector2i or not placement[1] is int: return false
	w.build(data.layout)
	for id in RUN_FIELDS:
		if id=="vendor_offers": w.run.vendor_offers.assign(data.progress[id])
		else: w.run.set(id,data.progress[id])
	w.run.random.state = int(data.get("random",w.run.random.state))
	w.run.vendor_random.state = int(data.get("vendor_random",w.run.vendor_random.state))
	for id in w.site.stations: w.site.remove_station_cells(id)
	for offer in w.Catalog.VENDOR_OFFERS:
		if not w.run.purchases.has(offer.id): continue
		match offer.id:
			"compressor": w.site.install_compressor()
			"lounge": w.site.install_waiting_room_cushions()
			"counter":
				for i in range(2):
					var id := "counter_vendor_%d"%i
					if data.decor.has(id): w.site.make_station(id,"Desserte %d"%(i+1),data.decor[id][0],Color(offer.color))
			"vending","magazines":
				if data.decor.has(offer.id):
					w.site.make_station(offer.id,offer.name,data.decor[offer.id][0],Color(offer.color),1.23 if offer.id=="vending" else 0.76)
	for id in w.site.stations:
		var station: Dictionary = w.site.stations[id]
		var position: Array = data.decor.get(id,[station.tile,station.turn])
		w.site.move_station(id,position[0],position[1])
	w.day_setup = data.equipment
	w.restore_day_setup()
	w.update_lift_speed()
	w.site.van.visible = w.run.day>0
	w.keep_player_clear()
	w.sync_player(0.0,0.0)
	w.update_camera(1.0)
	w.update_hud()
	return true

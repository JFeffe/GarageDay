--!strict

export type Phase = "free" | "idle" | "service" | "arrival" | "reception" | "intake" | "repair" | "outbound" | "checkout" | "payment" | "departing" | "closing" | "vendor" | "complete"
export type Lane = { phase: Phase, ticket: number, repairIndex: number, driver: number }
export type Placement = { x: number, z: number, turn: number }
type JobInfo = { read name: string, read amount: number, read unlock: number }
type Catalog = { read [string]: JobInfo }
type Offer = { name: string, price: number, description: string, temporary: boolean?, unlock: number? }
export type Order = {
	name: string, jobs: { string }, vehicle: "Sedan" | "Sport", estimate: number, amount: number,
	paid: boolean, late: boolean, patience: number, patienceMax: number, snacks: number, snackUntil: number, lateSeconds: number,
}
export type State = {
	phase: Phase, day: number, ticket: number, repairIndex: number, driver: number,
	cash: number, served: number, dailyCash: number, totalEarned: number, spent: number, lastInvoice: number,
	orders: { Order }, catalog: Catalog, pick: (number) -> number, seen: { [string]: number },
	purchases: { [string]: boolean }, nextServices: { [string]: boolean }, activeServices: { [string]: boolean },
	offers: { string }, rerolled: boolean, extraBooked: boolean, rating: number, guaranteeUsed: boolean,
	map: string, furniture: { [string]: { [string]: Placement } }, grades: { [string]: number },
}
type Campaign = { data: any, day: number, cash: number, complete: boolean }
export type Campaigns = { [string]: Campaign }

local Service = {}
local quotas = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 7 }
Service.maxAppointments = 9
Service.lastDay = #quotas
Service.maps = table.freeze({ "PetitAtelier", "Tandem" })
local lateInterval = 10
local names = { "Camille", "Noah", "Léa", "Sacha", "Maël", "Zia", "Alex", "Inès", "Charlie", "Sam", "Jules", "Morgan" }
local offers: { [string]: Offer } = {
	lift = { name = "Élévateur rapide", price = 60, description = "Les montées et descentes du pont prennent 38 % moins de temps." },
	counter = { name = "Desserte double", price = 75, description = "Installe deux surfaces où poser et reprendre des pièces." },
	compressor = { name = "Compresseur pro", price = 50, description = "Divise par deux le temps de réglage de la pression." },
	impact = { name = "Clé à choc pro", price = 50, description = "Desserre et resserre les roues deux fois plus vite." },
	light_cart = { name = "Chariot léger", price = 65, description = "Pousse le chariot à ta vitesse normale." },
	lounge = { name = "Salle d’attente confort", price = 80, description = "Les clients perdent patience 25 % plus lentement." },
	loyalty = { name = "Contrat fidélité", price = 95, description = "Ajoute 8 $ aux factures des clients servis à temps." },
	reception = { name = "Renfort à l’accueil", price = 15, description = "Demain, accueille les clients deux fois plus vite.", temporary = true },
	advertising = { name = "Publicité locale", price = 22, description = "Ajoute un rendez-vous au planning de demain.", temporary = true },
	tuning = { name = "Réglage des ponts", price = 20, description = "Demain, les mouvements du pont durent 35 % de moins.", temporary = true },
	diagnostic = { name = "Location d’une valise pro", price = 18, description = "Demain, inspecte les voitures deux fois plus vite.", temporary = true },
	oil_recovery = { name = "Bac récupérateur", price = 135, description = "Récupère l’huile usée directement pendant la vidange.", unlock = 3 },
	service_guarantee = { name = "Garantie d’accueil", price = 180, description = "Protège la première demi-étoile perdue par impatience chaque jour.", unlock = 5 },
	express_shop = { name = "Atelier express", price = 240, description = "Réduit de 30 % le temps des gestes sur la voiture.", unlock = 7 },
	vending = { name = "Distributrice", price = 70, description = "Offre jusqu’à quatre pauses-collation par client et majore les factures de 5 %." },
	magazines = { name = "Porte-magazines", price = 35, description = "Réduit de 5 % la perte de patience en salle d’attente." },
}
Service.offers = table.freeze(offers)
Service.rerollCost = 25

function Service.new(catalog: Catalog, pick: (number) -> number): State
	return {
		phase = "free", day = 0, ticket = 1, repairIndex = 1, driver = 0, cash = 0, served = 0, dailyCash = 0,
		totalEarned = 0, spent = 0, lastInvoice = 0, orders = {}, catalog = catalog, pick = pick, seen = {},
		purchases = {}, nextServices = {}, activeServices = {}, offers = {}, rerolled = false, extraBooked = false,
		rating = 10, guaranteeUsed = false, map = Service.maps[1], furniture = {}, grades = {},
	}
end

function Service.current(state: State, lane: Lane?): Order?
	return state.orders[(lane or state).ticket]
end

local function patienceFor(day: number, jobs: number): number
	return math.max(105, 164 - day * 4 + jobs * 32)
end

local function drawOrder(state: State): Order
	local jobs, eligible, usedNames = {}, {}, {}
	for _, order in state.orders do usedNames[order.name] = true end
	local availableNames = {}
	for _, name in names do if not usedNames[name] then table.insert(availableNames, name) end end
	for id, spec in state.catalog do if spec.unlock <= state.day then table.insert(eligible, id) end end
	table.sort(eligible)
	local maximum = math.min(#eligible, 4, 2 + math.floor((state.day - 1) / 3))
	local count = math.max(if state.day >= 7 then 2 else 1, state.pick(maximum))
	local estimate = 0
	for _ = 1, count do
		local rarest = math.huge
		local candidates = {}
		for _, id in eligible do
			local seen = state.seen[id] or 0
			if seen < rarest then
				table.clear(candidates)
				rarest = seen
			end
			if seen == rarest then table.insert(candidates, id) end
		end
		local picked = candidates[state.pick(#candidates)]
		table.insert(jobs, picked)
		state.seen[picked] = (state.seen[picked] or 0) + 1
		estimate += state.catalog[picked].amount
		for i = #eligible, 1, -1 do
			local id = eligible[i]
			if id == picked or (picked == "tires" and id == "puncture") or (picked == "puncture" and id == "tires") then
				table.remove(eligible, i)
			end
		end
	end
	local patience = patienceFor(state.day, #jobs)
	return {
		name = availableNames[state.pick(#availableNames)],
		vehicle = if state.pick(3) == 1 then "Sport" else "Sedan",
		jobs = jobs, estimate = estimate, amount = 0, paid = false, late = false,
		patience = patience, patienceMax = patience, snacks = 0, snackUntil = 0, lateSeconds = 0,
	}
end

function Service.open(state: State): boolean
	if state.phase ~= "free" and state.phase ~= "vendor" then return false end
	if state.day >= Service.lastDay then return false end
	state.day += 1
	state.ticket, state.repairIndex = 1, 1
	state.served, state.dailyCash, state.lastInvoice = 0, 0, 0
	state.rating, state.guaranteeUsed, state.extraBooked = 10, false, false
	state.activeServices = state.nextServices
	state.nextServices = {}
	state.offers = {}
	state.orders = {}
	local count = quotas[math.min(state.day, #quotas)] + (if state.activeServices.advertising then 1 else 0)
	for _ = 1, count do table.insert(state.orders, drawOrder(state)) end
	state.phase = "arrival"
	return true
end

function Service.book(state: State): boolean
	if state.phase ~= "service" and state.phase ~= "reception" and state.phase ~= "intake" and state.phase ~= "repair" then return false end
	if state.extraBooked or #state.orders >= Service.maxAppointments then return false end
	state.extraBooked = true
	table.insert(state.orders, drawOrder(state))
	return true
end

function Service.arrived(state: Lane)
	if state.phase == "arrival" then state.phase = "reception" end
end

function Service.receive(state: Lane): boolean
	if state.phase ~= "reception" then return false end
	state.phase = "intake"
	return true
end

function Service.beginDrive(state: Lane, playerId: number): boolean
	if playerId == 0 or state.driver ~= 0 or (state.phase ~= "intake" and state.phase ~= "outbound") then return false end
	state.driver = playerId
	return true
end

function Service.park(state: Lane, playerId: number, aligned: boolean): boolean
	if state.driver == 0 or state.driver ~= playerId or not aligned then return false end
	if state.phase == "intake" then state.phase = "repair"
	elseif state.phase == "outbound" then state.phase = "checkout"
	else return false end
	state.driver = 0
	return true
end

function Service.finishRepair(state: State, job: string, billable: boolean, declined: boolean, surcharge: number, addBattery: boolean, lane: Lane?): boolean
	local active = lane or state
	local order = Service.current(state, lane)
	if active.phase ~= "repair" or not order or order.jobs[active.repairIndex] ~= job then return false end
	if billable then order.amount += state.catalog[job].amount + surcharge end
	if declined then state.rating = math.max(0, state.rating - 1) end
	if addBattery and not table.find(order.jobs, "battery") then
		table.insert(order.jobs, "battery")
		order.estimate += state.catalog.battery.amount
	end
	if surcharge > 0 then order.estimate += surcharge end
	if not billable then order.estimate -= state.catalog[job].amount end
	active.repairIndex += 1
	if active.repairIndex > #order.jobs then active.phase = "outbound" end
	return true
end

function Service.readyToPay(state: Lane)
	if state.phase == "checkout" then state.phase = "payment" end
end

function Service.invoice(state: State, order: Order): number
	local amount = order.amount
	if amount <= 0 then return 0 end
	if state.purchases.loyalty and not order.late then amount += 8 end
	if state.purchases.vending then amount = math.floor(amount * 1.05 + 0.5) end
	return amount
end

function Service.pay(state: State, lane: Lane?): boolean
	local active = lane or state
	local order = Service.current(state, lane)
	if active.phase ~= "payment" or not order or order.paid then return false end
	order.paid = true
	local amount = Service.invoice(state, order)
	state.lastInvoice = amount
	state.cash += amount
	state.dailyCash += amount
	state.totalEarned += amount
	state.served += 1
	active.phase = "departing"
	return true
end

function Service.departed(state: State)
	if state.phase ~= "departing" then return end
	if state.ticket < #state.orders then
		state.ticket += 1
		state.repairIndex = 1
		state.phase = "arrival"
	else
		state.phase = "closing"
	end
end

function Service.newLane(): Lane
	return { phase = "idle", ticket = 0, repairIndex = 1, driver = 0 }
end

function Service.dispatch(state: State, lanes: { Lane }, lane: Lane): boolean
	if state.phase ~= "service" or lane.phase ~= "idle" then return false end
	for index, order in state.orders do
		if not order.paid then
			local assigned = false
			for _, working in lanes do
				if working.ticket == index then
					assigned = true
					break
				end
			end
			if not assigned then
				lane.ticket, lane.repairIndex, lane.phase = index, 1, "arrival"
				return true
			end
		end
	end
	return false
end

function Service.clearLane(lane: Lane)
	if lane.phase == "departing" then lane.phase, lane.ticket = "idle", 0 end
end

function Service.closeShift(state: State, lanes: { Lane }): boolean
	if state.phase ~= "service" or state.served ~= #state.orders then return false end
	for _, lane in lanes do if lane.phase ~= "idle" then return false end end
	state.phase = "closing"
	return true
end

function Service.selectMap(state: State, id: string): boolean
	if (state.phase ~= "free" and state.phase ~= "vendor") or state.day >= Service.lastDay
		or not table.find(Service.maps, id) or state.map == id then return false end
	state.map = id
	return true
end

function Service.finishCampaign(state: State): boolean
	if state.phase ~= "vendor" or state.day < Service.lastDay then return false end
	state.phase = "complete"
	return true
end

function Service.owns(state: State, id: string): boolean
	local offer = offers[id]
	if not offer then return false end
	return (if offer.temporary then state.nextServices[id] else state.purchases[id]) == true
end

local function drawOffers(state: State, replacing: boolean): { string }
	local primary: {string} = {}
	local previous: {string} = {}
	for id, offer in offers do
		if not Service.owns(state, id) and state.day >= (offer.unlock or 1) and (not offer.temporary or state.day < Service.lastDay) then
			local pool = if replacing and table.find(state.offers, id) then previous else primary
			table.insert(pool, id)
		end
	end
	if replacing and #primary == 0 then return {} end
	table.sort(primary)
	table.sort(previous)
	local stock = {}
	for _ = 1, 3 do
		local pool = if #primary > 0 then primary else previous
		if #pool == 0 then break end
		local index = state.pick(#pool)
		table.insert(stock, pool[index])
		table.remove(pool, index)
	end
	return stock
end

function Service.openMarket(state: State): boolean
	if state.phase ~= "closing" then return false end
	state.offers = drawOffers(state, false)
	state.rerolled = false
	state.grades[tostring(state.day)] = state.rating
	state.phase = "vendor"
	return true
end

function Service.buy(state: State, id: string): (boolean, string)
	local offer = offers[id]
	if state.phase ~= "vendor" or not offer or not table.find(state.offers, id) then return false, "Cette offre a pris fin." end
	if Service.owns(state, id) then return false, "Cet article est déjà acheté." end
	if state.cash < offer.price then return false, "La caisse ne suffit pas encore." end
	local inventory = if offer.temporary then state.nextServices else state.purchases
	inventory[id] = true
	state.cash -= offer.price
	state.spent += offer.price
	return true, offer.name .. (if offer.temporary then " réservé pour demain." else " installé au garage.")
end

function Service.reroll(state: State): (boolean, string)
	if state.phase ~= "vendor" or state.rerolled then return false, "Renouvellement déjà utilisé." end
	if state.cash < Service.rerollCost then return false, "Il faut 25 $ pour renouveler les offres." end
	local stock = drawOffers(state, true)
	if #stock == 0 then return false, "Le marchand n’a plus d’autres articles." end
	state.cash -= Service.rerollCost
	state.spent += Service.rerollCost
	state.rerolled = true
	state.offers = stock
	return true, "La caravane a sorti de nouvelles offres."
end

function Service.passTime(state: State, dt: number, now: number, lane: Lane?): boolean
	local phase = (lane or state).phase
	if phase ~= "reception" and phase ~= "intake" and phase ~= "repair" and phase ~= "outbound" and phase ~= "checkout" and phase ~= "payment" then return false end
	local order = Service.current(state, lane)
	if not order or now < order.snackUntil then return false end
	local rate = if state.purchases.lounge then 0.75 else 1
	if phase ~= "reception" then
		rate *= 0.67
		if state.purchases.magazines then rate *= 0.95 end
		if state.purchases.vending then rate *= 0.95 end
	end
	local penalties = 0
	if order.patience > 0 then
		local remaining = order.patience
		order.patience = math.max(0, order.patience - dt * rate)
		if order.patience > 0 then return false end
		order.late = true
		penalties = 1
		order.lateSeconds += math.max(0, dt - remaining / rate)
	else
		order.lateSeconds += dt
	end
	penalties += math.floor(order.lateSeconds / lateInterval)
	order.lateSeconds %= lateInterval
	if penalties > 0 and state.purchases.service_guarantee and not state.guaranteeUsed then
		state.guaranteeUsed = true
		penalties -= 1
		if penalties == 0 then return true end
	end
	local previous = state.rating
	state.rating = math.max(0, state.rating - penalties)
	return state.rating ~= previous
end

function Service.snack(state: State, now: number, lane: Lane?): boolean
	local order = Service.current(state, lane)
	local phase = (lane or state).phase
	if not order or not state.purchases.vending or order.snacks >= 4 or now < order.snackUntil
		or (phase ~= "intake" and phase ~= "repair" and phase ~= "outbound") then return false end
	order.snacks += 1
	order.snackUntil = now + 10
	return true
end

function Service.hold(state: State, seconds: number, rate: string?, carWork: boolean): number
	if carWork and state.purchases.express_shop then seconds *= 0.70 end
	if (rate == "impact" and state.purchases.impact) or (rate == "compressor" and state.purchases.compressor)
		or (rate == "reception" and state.activeServices.reception) or (rate == "diagnostic" and state.activeServices.diagnostic) then
		seconds *= 0.5
	end
	return seconds
end

function Service.liftTime(state: State): number
	return 0.9 * (if state.purchases.lift then 0.625 else 1) * (if state.activeServices.tuning then 0.65 else 1)
end

function Service.release(state: Lane, playerId: number)
	if state.driver == playerId then state.driver = 0 end
end

function Service.snapshot(state: State)
	local orders = {}
	for _, order in state.orders do
		table.insert(orders, {
			name = order.name, jobs = table.clone(order.jobs), vehicle = order.vehicle,
			estimate = order.estimate, amount = order.amount, paid = order.paid,
			late = order.late, snacks = order.snacks, patience = order.patience, lateSeconds = order.lateSeconds,
		})
	end
	local furniture = {}
	for map, layout in state.furniture do furniture[map] = table.clone(layout) end
	return {
		version = 1, day = state.day, cash = state.cash, dailyCash = state.dailyCash,
		totalEarned = state.totalEarned, spent = state.spent, lastInvoice = state.lastInvoice,
		rating = state.rating, guaranteeUsed = state.guaranteeUsed, extraBooked = state.extraBooked,
		orders = orders, seen = table.clone(state.seen), purchases = table.clone(state.purchases),
		nextServices = table.clone(state.nextServices), activeServices = table.clone(state.activeServices),
		market = state.phase == "vendor", offers = table.clone(state.offers), rerolled = state.rerolled,
		complete = state.phase == "complete", map = state.map, furniture = furniture, grades = table.clone(state.grades),
	}
end

local function count(value: unknown, limit: number): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value > limit or math.floor(value) ~= value then return nil end
	return value
end

local function purchased(saved: any, temporary: boolean): { [string]: boolean }
	local result = {}
	if type(saved) == "table" then
		for id, offer in offers do
			if (offer.temporary == true) == temporary and saved[id] == true then result[id] = true end
		end
	end
	return result
end

local function restoreFurniture(saved: any): { [string]: { [string]: Placement } }
	local result: { [string]: { [string]: Placement } } = {}
	if type(saved) ~= "table" then return result end
	for _, map in Service.maps do
		local layout = saved[map]
		if type(layout) == "table" then
			local restored, total = {}, 0
			for id, row in layout do
				if total >= 80 then break end
				if type(id) == "string" and #id <= 40 and type(row) == "table" then
					local x, z, turn = row.x, row.z, count(row.turn, 3)
					if type(x) == "number" and type(z) == "number" and math.abs(x) <= 100 and math.abs(z) <= 100 and turn then
						restored[id] = { x = x, z = z, turn = turn }
						total += 1
					end
				end
			end
			result[map] = restored
		end
	end
	return result
end

function Service.restore(state: State, saved: any): boolean
	if type(saved) ~= "table" or saved.version ~= 1 or type(saved.orders) ~= "table" then return false end
	local day = count(saved.day, 1e9)
	local cash, total, spent = count(saved.cash, 1e12), count(saved.totalEarned, 1e12), count(saved.spent, 1e12)
	local daily, last, rating = count(saved.dailyCash, 1e12), count(saved.lastInvoice, 1e12), count(saved.rating, 10)
	if not day or not cash or not total or not spent or not daily or not last or not rating then return false end
	if (day == 0) ~= (#saved.orders == 0) or #saved.orders > Service.maxAppointments then return false end
	local restored: { Order } = {}
	local paid, firstUnpaid = 0, nil
	for index = 1, #saved.orders do
		local row = saved.orders[index]
		if type(row) ~= "table" then return false end
		local order = row :: { [string]: any }
		local name, items, vehicle, wasPaid = order.name, order.jobs, order.vehicle, order.paid
		if type(name) ~= "string" or #name > 48 or type(items) ~= "table" or #items == 0 or #items > 4
			or (vehicle ~= "Sedan" and vehicle ~= "Sport") or type(wasPaid) ~= "boolean" then return false end
		local jobs: { string } = {}
		local estimate = 0
		for index = 1, #items do
			local id = (items :: { any })[index]
			if type(id) ~= "string" or not state.catalog[id] or table.find(jobs, id) then return false end
			table.insert(jobs, id)
			estimate += state.catalog[id].amount
		end
		local amount = 0
		if wasPaid then
			paid += 1
			amount = count(order.amount, 1e6) or 0
			estimate = count(order.estimate, 1e6) or estimate
		elseif not firstUnpaid then
			firstUnpaid = index
		end
		local patienceMax = patienceFor(day, #jobs)
		local patience, lateSeconds = order.patience, order.lateSeconds
		table.insert(restored, {
			name = name, jobs = jobs, vehicle = vehicle, estimate = estimate, amount = amount,
			paid = wasPaid, late = order.late == true, patienceMax = patienceMax,
			patience = if type(patience) == "number" and patience >= 0 and patience <= patienceMax then patience
				elseif order.late == true then 0 else patienceMax,
			snacks = count(order.snacks, 4) or 0, snackUntil = 0,
			lateSeconds = if type(lateSeconds) == "number" and lateSeconds >= 0 and lateSeconds < lateInterval then lateSeconds else 0,
		})
	end
	local phase: Phase = "free"
	local marketOffers = {}
	if day > 0 then
		if paid < #restored then
			phase = "arrival"
		elseif saved.complete == true and day >= Service.lastDay then
			phase = "complete"
		elseif saved.market == true and type(saved.offers) == "table" then
			phase = "vendor"
			for _, id in ipairs(saved.offers) do
				if #marketOffers == 3 then break end
				if type(id) ~= "string" then continue end
				local offer = offers[id]
				if offer and (not offer.temporary or day < Service.lastDay) and not table.find(marketOffers, id) then
					table.insert(marketOffers, id)
				end
			end
		else
			phase = "closing"
		end
	end
	local seen = {}
	if type(saved.seen) == "table" then
		for id in state.catalog do seen[id] = count(saved.seen[id], 1e12) end
	end

	state.phase, state.day, state.orders = phase, day, restored
	state.ticket, state.repairIndex, state.driver = firstUnpaid or math.max(1, #restored), 1, 0
	state.cash, state.totalEarned, state.spent = cash, total, spent
	state.served, state.dailyCash, state.lastInvoice, state.rating = paid, daily, last, rating
	state.guaranteeUsed, state.extraBooked = saved.guaranteeUsed == true, saved.extraBooked == true
	state.seen, state.offers, state.rerolled = seen, marketOffers, saved.rerolled == true
	state.purchases = purchased(saved.purchases, false)
	state.nextServices = purchased(saved.nextServices, true)
	state.activeServices = purchased(saved.activeServices, true)
	state.map = if table.find(Service.maps, saved.map) then saved.map else Service.maps[1]
	state.furniture = restoreFurniture(saved.furniture)
	state.grades = {}
	if type(saved.grades) == "table" then
		for index = 1, Service.lastDay do
			local key = tostring(index)
			state.grades[key] = count(saved.grades[key], 10)
		end
	end
	return true
end

local function campaign(state: State, data: any): Campaign
	return { data = data, day = state.day, cash = state.cash, complete = state.phase == "complete" }
end

function Service.readCampaigns(saved: any, catalog: Catalog, pick: (number) -> number): Campaigns?
	if saved == nil then return {} end
	if type(saved) ~= "table" then return nil end
	if saved.version == 1 then
		local state = Service.new(catalog, pick)
		if not Service.restore(state, saved) then return nil end
		return { [state.map] = campaign(state, saved) }
	end
	if saved.version ~= 2 or type(saved.campaigns) ~= "table" then return nil end
	local campaigns: Campaigns = {}
	for map, snapshot in saved.campaigns do
		if type(map) ~= "string" or not table.find(Service.maps, map) then return nil end
		local state = Service.new(catalog, pick)
		if not Service.restore(state, snapshot) or state.map ~= map then return nil end
		campaigns[map] = campaign(state, snapshot)
	end
	return campaigns
end

function Service.saveCampaign(campaigns: Campaigns, state: State)
	campaigns[state.map] = campaign(state, Service.snapshot(state))
	local snapshots: { [string]: any } = {}
	for map, entry in campaigns do snapshots[map] = entry.data end
	return { version = 2, campaigns = snapshots }
end

function Service.chooseCampaign(campaigns: Campaigns, map: string, action: string, confirmed: boolean, catalog: Catalog, pick: (number) -> number): State?
	if not table.find(Service.maps, map) then return nil end
	local entry = campaigns[map]
	local state = Service.new(catalog, pick)
	if action == "continue" then
		if not entry or not Service.restore(state, entry.data) then return nil end
	elseif action == "new" then
		if entry and not confirmed then return nil end
		state.map = map
	else return nil end
	return state
end

return Service

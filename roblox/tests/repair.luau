--!strict

local Repair = require("../src/shared/Repair")
local Service = require("../src/shared/Service")

local mechanic, assistant, stranger = 1, 2, 99
local function runStep(repair: Repair.State, actor: number)
	local current = assert(Repair.current(repair))
	assert(not Repair.act(repair, stranger, "outOfOrder"))
	local held = Repair.using(repair, actor)
	if held and (current.cargo or Repair.needsEmptyHands(current) or (current.tool and current.tool ~= held)) then
		assert(not Repair.act(repair, actor, current.action))
		assert(Repair.returnTool(repair, actor, held))
	end
	if current.tool then
		assert(not Repair.act(repair, stranger, current.action))
		if repair.tools[current.tool] ~= actor then assert(Repair.takeTool(repair, actor, current.tool)) end
		assert(not Repair.takeTool(repair, stranger, current.tool))
	end
	if current.cargo and repair.carried[current.cargo] ~= actor then
		assert(not Repair.act(repair, actor, current.action))
		assert(Repair.source(repair, current.cargo), current.cargo .. " is missing")
		assert(Repair.take(repair, actor, current.cargo))
		assert(not Repair.take(repair, stranger, current.cargo))
	end
	assert(Repair.act(repair, actor, current.action), repair.job .. " / " .. current.action)
	if current.motion then
		assert(repair.moving and Repair.current(repair) == current)
		assert(not Repair.act(repair, mechanic, current.action))
		Repair.finishMotion(repair)
	end
	assert(Repair.current(repair) ~= current)
end

local function finish(repair: Repair.State)
	while Repair.current(repair) do runStep(repair, mechanic) end
	assert(not repair.raised and not repair.moving and not repair.hoodOpen)
	assert(next(repair.carried) == nil and next(repair.placements) == nil, repair.job)
end

local variants: { Repair.Faults } = {
	{ wheel = "FrontLeft", rightDamper = true, rearLamp = true, crackedShield = true, badPuncture = true,
		windowModule = true, weakBattery = true, highPressure = true, oilRecovery = true },
	{ wheel = "BackLeft" }, { wheel = "FrontRight" }, { wheel = "BackRight" }, {},
}
local jobCount, cases = 0, 0
local allTools, allCargo = {}, {}
for id in Repair.jobs do
	jobCount += 1
	for _, faults in variants do
		local repair = Repair.new(id, faults)
		for _, step in repair.steps do
			assert(step.title ~= "" and step.target ~= "" and step.hold >= 0)
			if step.tool then allTools[step.tool] = true end
			if step.cargo then allCargo[step.cargo] = true end
		end
		finish(repair)
		local work = Repair.forOrder({ id }, { [id] = faults }, {})
		for _, gesture in work.steps do
			if gesture.cargo then allCargo[gesture.cargo] = true end
		end
		finish(work)
		local done, steps = Repair.jobProgress(work, id)
		assert(done == steps, id)
		if id == "pressure" then assert(repair.pressure == 34) end
		if id == "window" then assert(repair.surcharge == (if faults.windowModule then 18 else 0)) end
		if id == "inspection" then assert(repair.addBattery == (faults.weakBattery == true)) end
		cases += 1
	end
end
assert(jobCount == 16 and cases == 80)
for id in Repair.tools do assert(allTools[id], id) end
for id in Repair.cargo do assert(allCargo[id], id) end

local function available(repair: Repair.State, action: string, target: string?, cargo: string?): Repair.Step?
	for _, step in Repair.available(repair) do
		if step.action == action and (not target or step.target == target) and (not cargo or step.cargo == cargo) then return step end
	end
	return nil
end

local oilOrder = Repair.forOrder({ "oil", "wipers" }, {}, {})
local function perform(repair: Repair.State, action: string, target: string?)
	assert(Repair.act(repair, mechanic, assert(available(repair, action, target))), action)
	if repair.moving then Repair.finishMotion(repair) end
end
assert(Repair.take(oilOrder, mechanic, "pan"))
assert(not available(oilOrder, "drain") and not available(oilOrder, "fillOil"))
perform(oilOrder, "remove_Wipers")
perform(oilOrder, "raise")
perform(oilOrder, "drain")
assert(Repair.source(oilOrder, "usedOil") == "UsedPan" and Repair.take(oilOrder, mechanic, "usedOil"))
assert(not Repair.take(oilOrder, mechanic, "newWipers"))
assert(Repair.drop(oilOrder, mechanic, "Ground") == "usedOil" and Repair.take(oilOrder, mechanic, "usedOil"))
perform(oilOrder, "lower")
perform(oilOrder, "recycle_usedOil")
assert(not Repair.carrying(oilOrder, mechanic))
assert(not available(oilOrder, "fillOil"))
perform(oilOrder, "openHood")
assert(Repair.take(oilOrder, mechanic, "freshOil"))
perform(oilOrder, "fillOil")
perform(oilOrder, "closeHood")
assert(Repair.drop(oilOrder, mechanic, "Ground") == "emptyBottle")
assert(Repair.take(oilOrder, mechanic, "newWipers"))
perform(oilOrder, "fit_Wipers")
perform(oilOrder, "testWipers")
finish(oilOrder)

local firstOilBay = Repair.forOrder({ "oil" }, {}, {})
local secondOilBay = Repair.forOrder({ "oil" }, {}, {})
assert(Repair.take(firstOilBay, mechanic, "pan"))
perform(secondOilBay, "raise")
local secondDrain = assert(available(secondOilBay, "drain"))
assert(not Repair.act(secondOilBay, stranger, secondDrain, firstOilBay))
assert(Repair.act(secondOilBay, mechanic, secondDrain, firstOilBay))
assert(not Repair.carrying(firstOilBay, mechanic))
assert(Repair.take(secondOilBay, mechanic, "usedOil"))
assert(not Repair.stockFrom(firstOilBay, secondOilBay, "usedOil"))
perform(secondOilBay, "recycle_usedOil")
finish(secondOilBay)

local mixed = Repair.forOrder({ "brakes", "tires", "oil" }, {}, {})
perform(mixed, "raise")
assert(Repair.takeTool(mixed, mechanic, "impact"))
local brakeLoosen
for _, gesture in Repair.available(mixed) do
	if gesture.action == "loosen" and gesture.job == "brakes" and gesture.target == "FrontLeft" then brakeLoosen = gesture end
end
assert(Repair.act(mixed, mechanic, assert(brakeLoosen)))
assert(not available(mixed, "lower") and not available(mixed, "loosen", "FrontLeft"))
perform(mixed, "loosen", "BackRight")
perform(mixed, "removeWheel", "BackRight")
perform(mixed, "removeWheel", "FrontLeft")
assert(Repair.source(mixed, "usedTire_BackRight") == "FloorBackRight")
assert(Repair.source(mixed, "serviceWheel_brakes_FrontLeft") == "FloorFrontLeft")
assert(not Repair.take(mixed, mechanic, "serviceWheel_brakes_FrontLeft"))
assert(Repair.using(mixed, mechanic) == "impact")
assert(Repair.returnTool(mixed, mechanic, "impact"))
finish(mixed)

local tires = Repair.new("tires")
local wheels = { "BackRight", "FrontRight", "BackLeft", "FrontLeft" }
assert(Repair.canChooseJob(tires))
local lower = tires.steps[#tires.steps]
runStep(tires, mechanic)
assert(tires.raised and not Repair.canChooseJob(tires) and #Repair.available(tires) == 4)
assert(not available(tires, "removeWheel") and not available(tires, "mountWheel"))
assert(Repair.takeTool(tires, mechanic, "impact") and not Repair.take(tires, mechanic, "newTire"))
for _, wheel in wheels do
	local step = assert(available(tires, "loosen", wheel))
	assert(Repair.act(tires, mechanic, step) and not Repair.act(tires, mechanic, step))
end
for index = 1, 3 do
	local step = assert(available(tires, "removeWheel", wheels[index]))
	assert(Repair.act(tires, mechanic, step) and Repair.using(tires, mechanic) == "impact")
	assert(not Repair.take(tires, mechanic, "usedTire_" .. wheels[index]))
end
assert(Repair.returnTool(tires, mechanic, "impact") and Repair.take(tires, mechanic, "newTire"))
assert(Repair.act(tires, mechanic, assert(available(tires, "removeWheel", "FrontLeft"))))
for _, wheel in wheels do
	assert(tires.wheels[wheel] == "removed" and Repair.source(tires, "usedTire_" .. wheel) == "Floor" .. wheel)
end
assert(Repair.carrying(tires, mechanic) == "newTire" and not Repair.take(tires, mechanic, "usedTire_FrontLeft"))
assert(not Repair.act(tires, mechanic, lower))
assert(Repair.act(tires, mechanic, assert(available(tires, "mountWheel", "FrontRight"))))
assert(Repair.source(tires, "usedTire_FrontRight") == "FloorFrontRight")

local used = "usedTire_FrontLeft"
assert(Repair.take(tires, assistant, used))
assert(not Repair.take(tires, assistant, "newTire") and not Repair.takeTool(tires, assistant, "impact"))
assert(Repair.drop(tires, assistant, "Counter1") == used and Repair.source(tires, used) == "Counter1")
assert(Repair.take(tires, mechanic, used))
Repair.release(tires, mechanic)
assert(Repair.source(tires, used) == "Recovery")
assert(Repair.take(tires, assistant, used))
assert(Repair.drop(tires, assistant, "Ground") == used and Repair.source(tires, used) == "Ground")

for _, wheel in { "FrontLeft", "BackRight", "BackLeft" } do
	assert(Repair.take(tires, mechanic, "newTire"))
	assert(Repair.act(tires, mechanic, assert(available(tires, "mountWheel", wheel))))
end
assert(Repair.takeTool(tires, mechanic, "impact"))
for _, wheel in wheels do
	assert(Repair.act(tires, mechanic, assert(available(tires, "tighten", wheel))))
	assert(tires.wheels[wheel] == "new")
end
assert(not available(tires, "lower"))
for _, wheel in { "BackLeft", "FrontLeft", "BackRight", "FrontRight" } do
	local item = "usedTire_" .. wheel
	local recycling = assert(available(tires, "recycle_usedTire", "TireBin", item))
	assert(not Repair.act(tires, mechanic, recycling))
	assert(Repair.take(tires, assistant, item) and Repair.act(tires, assistant, recycling))
end
assert(available(tires, "lower") == lower)
finish(tires)

local puncture = Repair.new("puncture", { wheel = "BackRight" })
for _ = 1, 3 do runStep(puncture, mechanic) end
assert(Repair.source(puncture, "serviceWheel") == "FloorBackRight")
runStep(puncture, assistant)
assert(puncture.placements.serviceWheel == "Bench" and Repair.source(puncture, "serviceWheel") == nil)
runStep(puncture, mechanic)
runStep(puncture, assistant)
assert(Repair.source(puncture, "serviceWheel") == "Bench")
finish(puncture)
assert(puncture.wheels.BackRight == "installed")

local brakes = Repair.new("brakes")
for _ = 1, 4 do runStep(brakes, mechanic) end
assert(brakes.placements.serviceWheel == "WheelStand")
runStep(brakes, mechanic)
assert(Repair.using(brakes, mechanic) == "ratchet" and Repair.using(brakes, assistant) == nil)
assert(Repair.carrying(brakes, mechanic) == nil and Repair.source(brakes, "oldPads") == "Workpiece")
assert(not Repair.take(brakes, mechanic, "oldPads"))
assert(not Repair.takeTool(brakes, mechanic, "impact"))
assert(Repair.take(brakes, assistant, "oldPads") and Repair.drop(brakes, assistant, "Ground") == "oldPads")
runStep(brakes, assistant)
finish(brakes)
assert(brakes.components.PadsFrontLeft == "new" and brakes.components.PadsFrontRight == "new")

local window = Repair.new("window", { windowModule = true })
assert(not Repair.decline(window))
runStep(window, mechanic)
assert(Repair.decline(window) and not window.billable)
assert(not Repair.decline(window) and Repair.current(window) == nil)
local inspection = Repair.new("inspection", { weakBattery = true })
for _ = 1, 3 do runStep(inspection, mechanic) end
assert(Repair.decline(inspection) and inspection.billable and not inspection.addBattery)

local function random(seed: number): (number) -> number
	return function(maximum: number): number
		assert(maximum >= 1)
		seed = (seed * 48271) % 2147483647
		return seed % maximum + 1
	end
end

local function park(state: Service.Lane)
	assert(Service.beginDrive(state, mechanic))
	assert(not Service.beginDrive(state, assistant))
	assert(not Service.park(state, assistant, true) and not Service.park(state, mechanic, false))
	assert(Service.park(state, mechanic, true))
end

local function serve(state: Service.State)
	assert(not Service.pay(state))
	Service.arrived(state)
	assert(Service.receive(state) and not Service.receive(state))
	park(state)
	local order = assert(Service.current(state))
	for _, id in order.jobs do
		assert(not Service.finishRepair(state, "unknown", true, false, 0, false))
		assert(Service.finishRepair(state, id, true, false, 0, false))
	end
	assert(state.phase == "outbound")
	park(state)
	Service.readyToPay(state)
	local before = state.cash
	local invoice = Service.invoice(state, order)
	assert(Service.pay(state))
	assert(state.cash == before + invoice and state.lastInvoice == invoice and order.paid)
	assert(not Service.pay(state))
	Service.departed(state)
	return invoice
end

local counts = {2, 2, 3, 3, 4, 4, 5, 5, 6, 7}
local state = Service.new(Repair.jobs, random(47))
local alternate = Service.new(Repair.jobs, random(200))
assert(Service.open(alternate))
local drawn = {}
local permanentPurchased = {}
local variation = false
for day = 1, Service.lastDay do
	assert(Service.open(state) and not Service.open(state))
	local number = counts[math.min(day, #counts)] + (if state.activeServices.advertising then 1 else 0)
	assert(state.day == day and #state.orders == number)
	local customers: { [string]: boolean } = {}
	local distinct: { [string]: boolean } = {}
	for _, order in state.orders do
		assert(not customers[order.name] and #order.jobs >= 1 and #order.jobs <= 4)
		customers[order.name] = true
		table.clear(distinct)
		local estimate = 0
		for _, id in order.jobs do
			assert(not distinct[id] and Repair.jobs[id].unlock <= day)
			distinct[id], drawn[id] = true, true
			estimate += Repair.jobs[id].amount
		end
		assert(not (distinct.tires and distinct.puncture) and order.estimate == estimate)
	end
	if day == 1 then
		variation = table.concat(state.orders[1].jobs, "/") ~= table.concat(alternate.orders[1].jobs, "/")
		Service.arrived(state)
		assert(Service.book(state) and not Service.book(state) and #state.orders == number + 1)
	end
	local dailyCash = 0
	for _ in state.orders do dailyCash += serve(state) end
	assert(state.phase == "closing" and state.dailyCash == dailyCash and state.served == #state.orders)
	assert(Service.openMarket(state) and not Service.openMarket(state))
	while #state.offers > 0 do
		for _, id in state.offers do
			local price = Service.offers[id].price
			local before = state.cash
			local bought = Service.buy(state, id)
			if bought then
				assert(state.cash == before - price and Service.owns(state, id))
				if not Service.offers[id].temporary then permanentPurchased[id] = true end
				assert(not Service.buy(state, id) and state.cash == before - price)
			else
				assert(state.cash == before)
			end
		end
		if not Service.reroll(state) then break end
		assert(state.rerolled)
	end
	assert(state.cash == state.totalEarned - state.spent)
end
assert(not Service.open(state) and state.day == 10 and state.phase == "vendor")
assert(Service.finishCampaign(state) and state.phase == "complete" and not Service.open(state))
for day = 1, Service.lastDay do assert(state.grades[tostring(day)] == 10) end
assert(variation)
for id in Repair.jobs do assert(drawn[id], id) end
for id, offer in Service.offers do if not offer.temporary then assert(permanentPurchased[id], id) end end

local quote = Service.new(Repair.jobs, random(3))
quote.phase = "repair"
quote.orders = { {name = "QA", jobs = {"inspection", "window"}, vehicle = "Sedan", estimate = 61, amount = 0, paid = false,
	late = false, patience = 1, patienceMax = 1, snacks = 0, snackUntil = 0, lateSeconds = 0} }
local order = quote.orders[1]
assert(Service.finishRepair(quote, "inspection", true, false, 0, true))
assert(order.amount == 30 and order.estimate == 106 and order.jobs[3] == "battery")
assert(Service.finishRepair(quote, "window", true, false, 18, false))
assert(order.amount == 79 and order.estimate == 124)
assert(Service.finishRepair(quote, "battery", true, false, 0, false))
assert(order.amount == 124)
quote.purchases.loyalty, quote.purchases.vending, quote.purchases.service_guarantee = true, true, true
assert(Service.invoice(quote, order) == 139)
assert(Service.snack(quote, 10) and not Service.snack(quote, 11))
assert(not Service.passTime(quote, 11, 19))
assert(Service.passTime(quote, 2, 21) and order.late and quote.rating == 10)
assert(Service.passTime(quote, 14, 35) and quote.rating == 9)
assert(Service.invoice(quote, order) == 130)
quote.purchases.lift, quote.purchases.express_shop, quote.purchases.impact, quote.purchases.compressor = true, true, true, true
quote.activeServices.tuning, quote.activeServices.diagnostic, quote.activeServices.reception = true, true, true
assert(Service.liftTime(quote) < 0.40)
for _, rate in {"impact", "compressor", "diagnostic"} do assert(Service.hold(quote, 2, rate, true) == 0.7) end
assert(Service.hold(quote, 2, "reception", false) == 1)
quote.cash, quote.phase, quote.offers = 0, "vendor", {"lift"}
assert(not Service.buy(quote, "lift") and not Service.buy(quote, "unknown") and not Service.reroll(quote))

local workOrder = Service.new(Repair.jobs, random(53))
assert(Service.open(workOrder))
Service.arrived(workOrder)
assert(Service.receive(workOrder))
park(workOrder)
local pending = assert(Service.current(workOrder))
pending.jobs, pending.estimate = { "oil", "tires", "wipers" }, Repair.jobs.oil.amount + Repair.jobs.tires.amount + Repair.jobs.wipers.amount
assert(Service.selectRepair(workOrder, "wipers") and not Service.selectRepair(workOrder, "unknown"))
assert(not Service.finishRepair(workOrder, "oil", true, false, 0, false))
assert(Service.finishRepair(workOrder, "wipers", true, false, 0, false))
assert(not Service.selectRepair(workOrder, "wipers") and Service.selectRepair(workOrder, "tires"))
assert(Service.finishRepair(workOrder, "tires", true, false, 0, false))
assert(workOrder.phase == "repair" and pending.jobs[workOrder.repairIndex] == "oil")
assert(Service.finishRepair(workOrder, "oil", true, false, 0, false, nil, true))
assert(workOrder.phase == "repair" and Service.prepareReturn(workOrder))
assert(workOrder.phase == "outbound" and pending.amount == pending.estimate and not Service.selectRepair(workOrder, "oil"))

local tandem = Service.new(Repair.jobs, random(95))
local lanes = { Service.newLane(), Service.newLane() }
assert(Service.selectMap(tandem, "Tandem"))
for day = 1, Service.lastDay do
	assert(Service.open(tandem))
	tandem.phase = "service"
	assert(not Service.selectMap(tandem, "PetitAtelier"))
	while tandem.served < #tandem.orders do
		for _, lane in lanes do
			if Service.dispatch(tandem, lanes, lane) then
				Service.arrived(lane)
				assert(Service.receive(lane))
				park(lane)
			end
		end
		if day == 1 then
			local first, second = assert(Service.current(tandem, lanes[1])), assert(Service.current(tandem, lanes[2]))
			assert(first ~= second)
			assert(Service.passTime(tandem, 1000, 1000, lanes[2]))
			assert(second.late and not first.late and tandem.rating == 0)
		end
		for i = #lanes, 1, -1 do
			local lane = lanes[i]
			local active = Service.current(tandem, lane)
			if active then
				for _, id in active.jobs do
					local repair = Repair.new(id)
					finish(repair)
					assert(Service.finishRepair(tandem, id, repair.billable, false, repair.surcharge, repair.addBattery, lane))
				end
				park(lane)
				Service.readyToPay(lane)
				assert(Service.pay(tandem, lane) and not Service.pay(tandem, lane))
				if day == 1 and i == 2 then
					local restored = Service.new(Repair.jobs, random(95))
					assert(Service.restore(restored, Service.snapshot(tandem)))
					assert(restored.served == 1 and restored.ticket == 1 and restored.orders[2].late
						and restored.orders[2].paid and not restored.orders[1].paid and restored.map == "Tandem")
				end
				assert(not Service.closeShift(tandem, lanes))
				Service.clearLane(lane)
			end
		end
	end
	assert(Service.closeShift(tandem, lanes) and Service.openMarket(tandem))
	assert(tandem.day == day and tandem.cash > 0)
end
assert(tandem.grades["1"] == 0 and tandem.grades["2"] == 10 and tandem.day == 10)
assert(not Service.open(tandem) and Service.finishCampaign(tandem))
local restored = Service.new(Repair.jobs, random(1))
assert(Service.restore(restored, Service.snapshot(tandem)) and restored.phase == "complete")

print("PASS Roblox — ordre des interventions, quatre roues indépendantes, une seule prise à la fois, 16 réparations et 80 variantes, dix jours sur chaque carte.")

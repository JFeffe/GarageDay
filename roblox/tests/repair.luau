--!strict

local Repair = require("../src/shared/Repair")
local Service = require("../src/shared/Service")

local function act(repair: Repair.State, playerId: number, action: string)
	assert(Repair.act(repair, playerId, action), `Expected {action} for player {playerId} at step {repair.step}`)
end

local function motion(repair: Repair.State, playerId: number, action: string)
	act(repair, playerId, action)
	assert(repair.moving)
	assert(not Repair.act(repair, playerId, action))
	Repair.finishMotion(repair)
	assert(not repair.moving)
end

local function collect(repair: Repair.State, playerId: number, item: Repair.Cargo)
	assert(Repair.take(repair, playerId, item), `Expected {item} to be available at step {repair.step}`)
	assert(not Repair.take(repair, playerId + 100, item))
end

local function brakes(repair: Repair.State, mechanic: number, partsRunner: number)
	assert(not Repair.act(repair, mechanic, "loosenFrontLeft"))
	act(repair, mechanic, "raise")
	assert(repair.moving and repair.step == 1)
	assert(not Repair.act(repair, partsRunner, "raise"))
	act(repair, mechanic, "takeTool")
	assert(not Repair.act(repair, 100, "takeTool"))
	assert(not Repair.act(repair, 100, "returnTool"))
	collect(repair, partsRunner, "pads")
	Repair.finishMotion(repair)
	assert(repair.step == 2 and repair.raised and not repair.moving)
	for i, wheel in { "FrontLeft", "FrontRight" } do
		assert(not Repair.act(repair, 100, "loosen" .. wheel))
		act(repair, mechanic, "loosen" .. wheel)
		assert(not Repair.act(repair, mechanic, "loosen" .. wheel))
		act(repair, mechanic, "remove" .. wheel)
		assert(repair.removed[wheel])
		if i == 2 then collect(repair, partsRunner, "pads") end
		assert(not Repair.act(repair, 100, "install" .. wheel))
		act(repair, partsRunner, "install" .. wheel)
		assert(repair.replaced[wheel] and not repair.carried.pads)
		assert(Repair.canTake(repair, "pads") == (i == 1))
		act(repair, partsRunner, "mount" .. wheel)
		assert(not repair.removed[wheel])
		act(repair, mechanic, "tighten" .. wheel)
	end
	act(repair, mechanic, "lower")
	assert(repair.moving and Repair.current(repair))
	Repair.finishMotion(repair)
	assert(not repair.moving and not repair.raised and not Repair.current(repair))
end

local function pressure(repair: Repair.State, mechanic: number)
	assert(not Repair.act(repair, mechanic, "measure"))
	assert(not Repair.canTake(repair, "pads"))
	act(repair, mechanic, "takeTool")
	assert(not Repair.act(repair, mechanic, "inflate"))
	act(repair, mechanic, "measure")
	assert(repair.pressure == 28)
	act(repair, mechanic, "inflate")
	assert(repair.pressure == 34)
	act(repair, mechanic, "verifyPressure")
end

local function oil(repair: Repair.State, mechanic: number, partsRunner: number)
	assert(not Repair.canTake(repair, "usedOil"))
	collect(repair, mechanic, "pan")
	motion(repair, mechanic, "raise")
	act(repair, mechanic, "drain")
	assert(repair.raised and not repair.carried.pan and not Repair.canTake(repair, "pan"))
	assert(not Repair.act(repair, mechanic, "recycleOil"))
	collect(repair, partsRunner, "usedOil")
	Repair.release(repair, partsRunner)
	collect(repair, mechanic, "usedOil")
	act(repair, mechanic, "recycleOil")
	assert(not Repair.canTake(repair, "usedOil"))
	motion(repair, mechanic, "lower")
	collect(repair, partsRunner, "freshOil")
	motion(repair, mechanic, "openHood")
	assert(repair.hoodOpen and not repair.raised)
	assert(not Repair.act(repair, 100, "fillOil"))
	act(repair, partsRunner, "fillOil")
	assert(repair.carried.emptyBottle == partsRunner and not repair.carried.freshOil)
	Repair.release(repair, partsRunner)
	collect(repair, mechanic, "emptyBottle")
	act(repair, mechanic, "recycleBottle")
	motion(repair, mechanic, "closeHood")
	assert(not repair.hoodOpen)
end

local function battery(repair: Repair.State, mechanic: number, partsRunner: number)
	collect(repair, partsRunner, "newBattery")
	assert(not Repair.act(repair, mechanic, "takeTool"))
	assert(not Repair.act(repair, partsRunner, "installBattery"))
	motion(repair, mechanic, "openHood")
	act(repair, mechanic, "removeBattery")
	assert(repair.battery == "empty" and repair.carried.oldBattery == mechanic)
	assert(not Repair.act(repair, 100, "recycleBattery"))
	Repair.release(repair, mechanic)
	collect(repair, mechanic, "oldBattery")
	act(repair, mechanic, "recycleBattery")
	if mechanic == partsRunner then collect(repair, partsRunner, "newBattery") end
	act(repair, partsRunner, "installBattery")
	assert(repair.battery == "new" and not repair.carried.newBattery)
	assert(not Repair.act(repair, mechanic, "testIgnition"))
	motion(repair, mechanic, "closeHood")
	act(repair, mechanic, "testIgnition")
end

local function park(service: Service.State, driver: number)
	assert(not Service.park(service, 0, true))
	assert(Service.beginDrive(service, driver))
	assert(not Service.beginDrive(service, 100))
	assert(not Service.park(service, 100, true))
	assert(not Service.park(service, driver, false))
	Service.release(service, driver)
	assert(Service.beginDrive(service, driver))
	assert(Service.park(service, driver, true))
	assert(service.driver == 0)
end

local function trial(mechanic: number, partsRunner: number)
	local service = Service.new()
	assert(not Service.pay(service) and not Service.beginDrive(service, mechanic))
	local jobs = { brakes = brakes, pressure = pressure, oil = oil, battery = battery }
	local total = 0
	for day, revenue in { 108, 70, 128, 108 } do
		assert(Service.open(service) and service.day == day)
		assert(service.served == 0 and service.dailyCash == 0 and service.cash == total)
		assert(not Service.open(service))
		local plan = Service.plan(day)
		for i, order in plan do
			local repair = Repair.new(order.job)
			assert(service.phase == "arrival" and service.ticket == i)
			assert(not Service.receive(service))
			Service.arrived(service)
			assert(Service.receive(service) and not Service.receive(service))
			park(service, mechanic)
			assert(not Service.finishRepair(service, Repair.current(repair) == nil))
			if order.job == "pressure" then pressure(repair, mechanic)
			else jobs[order.job](repair, mechanic, partsRunner) end
			assert(Service.finishRepair(service, Repair.current(repair) == nil))
			assert(not Service.pay(service))
			park(service, mechanic)
			assert(not Service.pay(service))
			Service.readyToPay(service)
			assert(Service.pay(service) and not Service.pay(service))
			Service.departed(service)
		end
		total += revenue
		assert(service.phase == "done" and service.served == #plan and service.cash == total and service.dailyCash == revenue)
	end
end

trial(-1, -1)
trial(-1, -2)

local handoff = Repair.new("brakes")
act(handoff, 1, "takeTool")
collect(handoff, 1, "pads")
Repair.release(handoff, 1)
assert(handoff.toolOwner == 0 and not handoff.carried.pads)
act(handoff, 2, "takeTool")
act(handoff, 2, "returnTool")
act(handoff, 3, "takeTool")
collect(handoff, 2, "pads")

print("PASS · quatre interventions, partage et récupération des pièces, conduite, caisse et planning")

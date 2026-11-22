--!strict

local Repair = require("../src/shared/Repair")
local Service = require("../src/shared/Service")

local function act(repair: Repair.State, playerId: number, action: string)
	assert(Repair.act(repair, playerId, action), `Expected {action} for player {playerId} at step {repair.step}`)
end

local function brakes(repair: Repair.State, mechanic: number, partsRunner: number)
	assert(not Repair.act(repair, mechanic, "loosenFrontLeft"))
	act(repair, mechanic, "raise")
	assert(repair.moving and repair.step == 1)
	assert(not Repair.act(repair, partsRunner, "raise"))
	act(repair, mechanic, "takeTool")
	assert(not Repair.act(repair, 100, "takeTool"))
	assert(not Repair.act(repair, 100, "returnTool"))
	act(repair, partsRunner, "takePads")
	Repair.finishLift(repair)
	assert(repair.step == 2 and repair.raised and not repair.moving)
	for i, wheel in { "FrontLeft", "FrontRight" } do
		assert(not Repair.act(repair, 100, "loosen" .. wheel))
		act(repair, mechanic, "loosen" .. wheel)
		assert(not Repair.act(repair, mechanic, "loosen" .. wheel))
		act(repair, mechanic, "remove" .. wheel)
		assert(repair.removed[wheel])
		if i == 2 then act(repair, partsRunner, "takePads") end
		assert(not Repair.act(repair, 100, "install" .. wheel))
		act(repair, partsRunner, "install" .. wheel)
		assert(repair.replaced[wheel] and repair.padsOwner == 0)
		assert(Repair.canTakePads(repair) == (i == 1))
		act(repair, partsRunner, "mount" .. wheel)
		assert(not repair.removed[wheel])
		act(repair, mechanic, "tighten" .. wheel)
	end
	act(repair, mechanic, "lower")
	assert(repair.moving and Repair.current(repair))
	Repair.finishLift(repair)
	assert(not repair.moving and not repair.raised and not Repair.current(repair))
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
	assert(Service.open(service) and service.day == 1)
	assert(not Service.open(service))
	for i, order in Service.orders do
		local repair = Repair.new(order.job)
		assert(service.phase == "arrival" and service.ticket == i)
		assert(not Service.receive(service))
		Service.arrived(service)
		assert(Service.receive(service) and not Service.receive(service))
		park(service, mechanic)
		assert(not Service.finishRepair(service, Repair.current(repair) == nil))
		if order.job == "brakes" then
			brakes(repair, mechanic, partsRunner)
		else
			assert(not Repair.act(repair, mechanic, "measure"))
			assert(not Repair.canTakePads(repair))
			act(repair, mechanic, "takeTool")
			act(repair, mechanic, "measure")
		end
		assert(Service.finishRepair(service, Repair.current(repair) == nil))
		assert(not Service.pay(service))
		park(service, mechanic)
		assert(not Service.pay(service))
		Service.readyToPay(service)
		assert(Service.pay(service) and not Service.pay(service))
		Service.departed(service)
	end
	assert(service.phase == "done" and service.served == 2 and service.cash == 73 and service.dailyCash == 73)
	assert(Service.open(service))
	assert(service.day == 2 and service.served == 0 and service.cash == 73 and service.dailyCash == 0)
end

trial(-1, -1)
trial(-1, -2)

local handoff = Repair.new("brakes")
act(handoff, 1, "takeTool")
act(handoff, 1, "takePads")
Repair.release(handoff, 1)
assert(handoff.toolOwner == 0 and handoff.padsOwner == 0)
act(handoff, 2, "takeTool")
act(handoff, 2, "returnTool")
act(handoff, 3, "takeTool")
act(handoff, 2, "takePads")

print("PASS · service solo et coop, conduite, deux interventions, caisse et réouverture")

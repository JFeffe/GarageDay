--!strict

local Service = require("../src/shared/Service")
local Repair = require("../src/shared/Repair")
local Preferences = require("../src/shared/Preferences")
local SaveSlot = require("../src/server/SaveSlot")

local function newService()
	local seed = 9
	return Service.new(Repair.jobs, function(maximum)
		seed = (seed * 48271) % 2147483647
		return seed % maximum + 1
	end)
end

local function restore(state: Service.State): Service.State
	local result = newService()
	assert(Service.restore(result, Service.snapshot(state)))
	return result
end

local function payment(state: Service.State)
	Service.arrived(state)
	assert(Service.receive(state))
	assert(Service.beginDrive(state, 1) and Service.park(state, 1, true))
	local order = assert(Service.current(state))
	for _, id in order.jobs do assert(Service.finishRepair(state, id, true, false, 0, false)) end
	assert(Service.beginDrive(state, 1) and Service.park(state, 1, true))
	Service.readyToPay(state)
	assert(Service.pay(state))
end

local state = newService()
assert(restore(state).phase == "free")
assert(Service.selectMap(state, "Tandem"))
state.furniture.Tandem = { phone = { x = 1.75, z = 3.25, turn = 1 } }
local moved = restore(state)
assert(moved.map == "Tandem" and moved.furniture.Tandem.phone.turn == 1 and moved.day == 0)
assert(Service.selectMap(moved, "PetitAtelier") and Service.selectMap(moved, "Tandem"))
assert(moved.furniture.Tandem.phone.x == 1.75)
local legacy = Service.snapshot(newService())
assert(Service.restore(moved, { version = 1, orders = legacy.orders, day = 0, cash = 0, totalEarned = 0, spent = 0,
	dailyCash = 0, lastInvoice = 0, rating = 10 }))
assert(moved.map == "PetitAtelier" and next(moved.furniture) == nil)
assert(Service.open(state))
local first = assert(Service.current(state))
	local snapshot = Service.snapshot(state)
	local planned = state.orders[2].name
first.jobs[1] = if snapshot.orders[1].jobs[1] == "pressure" then "oil" else "pressure"
	assert(snapshot.orders[1].jobs[1] ~= first.jobs[1])
	first.jobs[1] = snapshot.orders[1].jobs[1]
payment(state)
local receipt = state.cash
assert(state.phase == "departing")
local nextCustomer = restore(state)
assert(nextCustomer.phase == "arrival" and nextCustomer.day == state.day and nextCustomer.ticket == 2)
assert(nextCustomer.orders[1].paid and nextCustomer.orders[2].name == planned)
assert(nextCustomer.cash == receipt and nextCustomer.dailyCash == receipt and nextCustomer.served == 1)
assert(not Service.pay(nextCustomer))

Service.arrived(nextCustomer)
assert(Service.receive(nextCustomer))
assert(Service.book(nextCustomer))
assert(Service.beginDrive(nextCustomer, 1))
local paused = restore(nextCustomer)
assert(paused.phase == "arrival" and paused.ticket == 2 and paused.driver == 0 and paused.extraBooked)
assert(#paused.orders == 3 and paused.orders[3].name == nextCustomer.orders[3].name)
paused.cash = 500
payment(paused)
Service.departed(paused)
payment(paused)
local market = restore(paused)
assert(market.phase == "closing" and market.served == #market.orders)
assert(Service.openMarket(market))
market.offers = { "impact", "advertising" }
assert(Service.buy(market, "impact") and Service.buy(market, "advertising"))
assert(Service.reroll(market))
local finished = restore(market)
assert(finished.phase == "vendor" and finished.day == 1 and finished.cash == market.cash)
assert(Service.owns(finished, "impact") and Service.owns(finished, "advertising") and finished.rerolled)
assert(table.concat(finished.offers, "/") == table.concat(market.offers, "/") and not Service.reroll(finished))
assert(Service.open(finished) and finished.day == 2 and #finished.orders == 3 and finished.activeServices.advertising)
assert(restore(finished).activeServices.advertising and restore(finished).purchases.impact)
local damaged = Service.snapshot(state)
damaged.orders[1].jobs[1] = "unknown"
local untouched = newService()
assert(not Service.restore(untouched, damaged) and untouched.day == 0 and untouched.cash == 0)

assert(Preferences.sensitivity(55) == Preferences.defaultSensitivity)
assert(Preferences.sensitivity(73) == 75 and Preferences.sensitivity(0) == 20 and Preferences.sensitivity(900) == 130)
assert(Preferences.sensitivity("80") == nil and Preferences.sensitivity(0/0) == nil and Preferences.sensitivity(math.huge) == nil)

local records: { [string]: any } = {}
local failRead, loseResponse = false, false
local backend = {
	read = function(key: string): any
		if failRead then error("Transport de lecture") end
		return records[key]
	end,
	update = function(key: string, transform: (any) -> any): any
		local staged = transform(records[key])
		if staged == nil then return nil end
		records[key] = staged
		if loseResponse then error("Réponse perdue après écriture") end
		return staged
	end,
}
local nonce = 0
local function slot(key: string)
	return SaveSlot.new(backend, key, function()
		nonce += 1
		return tostring(nonce)
	end)
end
local current = slot("workshop")
assert(current:load() == nil and current.status == "ready")
assert(current:queue({ cash = 90 }))
loseResponse = true
current:flush()
assert(current.status == "retry" and current:hasPending() and records.workshop.data.cash == 90)
assert(current:queue({ cash = 130, purchase = "lift" }))
loseResponse = false
current:flush()
assert(current.status == "saved" and current:hasPending())
current:flush()
assert(not current:hasPending())
local joinedAgain = slot("workshop")
local recovered = joinedAgain:load()
assert(recovered.cash == 130 and recovered.purchase == "lift")

local older = slot("workshop")
assert(older:load().cash == 130)
assert(joinedAgain:queue({ cash = 122 }))
joinedAgain:flush()
assert(older:queue({ cash = 89 }))
older:flush()
assert(older.status == "conflict" and not older:hasPending() and records.workshop.data.cash == 122)
failRead = true
local unavailable = slot("workshop")
assert(unavailable:load() == nil and not unavailable:queue({ cash = 0 }))
assert(records.workshop.data.cash == 122)
failRead = false
records.future = { version = 2 }
local future = slot("future")
assert(future:load() == nil and not future:queue({ cash = 0 }) and records.future.version == 2)

print("PASS sauvegarde Roblox — reprise du jour et du marché, caisse et achats, valeurs options, erreur réseau et session concurrente.")

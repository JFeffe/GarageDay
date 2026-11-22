--!strict

export type Phase = "free" | "arrival" | "reception" | "intake" | "repair" | "outbound" | "checkout" | "payment" | "departing" | "done"
export type Job = "brakes" | "pressure"
type Order = { name: string, job: Job, amount: number }
export type State = {
	phase: Phase,
	day: number,
	ticket: number,
	cash: number,
	served: number,
	dailyCash: number,
	driver: number,
}

local Service = {}
Service.orders = table.freeze({
	{ name = "Camille", job = "brakes", amount = 48 },
	{ name = "Noah", job = "pressure", amount = 25 },
} :: { Order })

function Service.new(): State
	return { phase = "free", day = 0, ticket = 1, cash = 0, served = 0, dailyCash = 0, driver = 0 }
end

function Service.open(state: State): boolean
	if state.phase ~= "free" and state.phase ~= "done" then return false end
	state.day += 1
	state.ticket = 1
	state.served = 0
	state.dailyCash = 0
	state.phase = "arrival"
	return true
end

function Service.arrived(state: State)
	if state.phase == "arrival" then state.phase = "reception" end
end

function Service.receive(state: State): boolean
	if state.phase ~= "reception" then return false end
	state.phase = "intake"
	return true
end

function Service.beginDrive(state: State, playerId: number): boolean
	if playerId == 0 or state.driver ~= 0 or (state.phase ~= "intake" and state.phase ~= "outbound") then return false end
	state.driver = playerId
	return true
end

function Service.park(state: State, playerId: number, aligned: boolean): boolean
	if state.driver == 0 or state.driver ~= playerId or not aligned then return false end
	if state.phase == "intake" then state.phase = "repair"
	elseif state.phase == "outbound" then state.phase = "checkout"
	else return false end
	state.driver = 0
	return true
end

function Service.finishRepair(state: State, complete: boolean): boolean
	if state.phase ~= "repair" or not complete then return false end
	state.phase = "outbound"
	return true
end

function Service.readyToPay(state: State)
	if state.phase == "checkout" then state.phase = "payment" end
end

function Service.pay(state: State): boolean
	if state.phase ~= "payment" then return false end
	local amount = Service.orders[state.ticket].amount
	state.cash += amount
	state.dailyCash += amount
	state.served += 1
	state.phase = "departing"
	return true
end

function Service.departed(state: State)
	if state.phase ~= "departing" then return end
	if state.ticket < #Service.orders then
		state.ticket += 1
		state.phase = "arrival"
	else
		state.phase = "done"
	end
end

function Service.release(state: State, playerId: number)
	if state.driver == playerId then state.driver = 0 end
end

return Service

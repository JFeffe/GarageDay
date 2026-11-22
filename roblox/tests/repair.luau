--!strict

local Repair = require("../src/shared/Repair")

local function apply(state: Repair.State, playerId: number, action: string)
	assert(Repair.act(state, playerId, action), `Expected {action} for player {playerId} at step {state.step}`)
end

local function trial(mechanic: number, partsRunner: number)
	local state = Repair.new()
	assert(not Repair.act(state, mechanic, "loosen"))
	apply(state, mechanic, "raise")
	assert(state.moving and state.step == 1)
	assert(not Repair.act(state, partsRunner, "raise"))
	apply(state, mechanic, "takeWrench")
	assert(not Repair.act(state, partsRunner, "takeWrench"))
	assert(not Repair.act(state, partsRunner == mechanic and 100 or partsRunner, "returnWrench"))
	apply(state, partsRunner, "takePads")
	Repair.finishLift(state)
	assert(state.step == 2 and not state.moving)
	assert(not Repair.act(state, partsRunner == mechanic and 100 or partsRunner, "loosen"))
	apply(state, mechanic, "loosen")
	assert(not Repair.act(state, mechanic, "loosen"))
	apply(state, mechanic, "remove")
	if mechanic ~= partsRunner then
		assert(not Repair.act(state, mechanic, "install"))
	end
	apply(state, partsRunner, "install")
	assert(state.padsOwner == 0 and not Repair.canTakePads(state))
	apply(state, partsRunner, "mount")
	apply(state, mechanic, "tighten")
	apply(state, mechanic, "lower")
	assert(not Repair.act(state, partsRunner, "replay"))
	Repair.finishLift(state)
	assert(state.step == #Repair.steps)
	apply(state, partsRunner, "replay")
	assert(state.step == 1 and state.wrenchOwner == 0 and state.padsOwner == 0)
end

trial(-1, -1)
trial(-1, -2)

local handoff = Repair.new()
apply(handoff, 1, "takeWrench")
apply(handoff, 1, "takePads")
Repair.release(handoff, 1)
assert(handoff.wrenchOwner == 0 and handoff.padsOwner == 0)
apply(handoff, 2, "takeWrench")
apply(handoff, 2, "returnWrench")
apply(handoff, 3, "takeWrench")
apply(handoff, 2, "takePads")

print("PASS · intervention solo, partage à deux, ordre des étapes, retour des outils et relance")

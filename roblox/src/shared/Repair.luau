--!strict

export type Step = {
	action: string,
	title: string,
	target: string,
	hold: number,
	item: ("tool" | "pads")?,
	wheel: string?,
	remove: boolean?,
}
export type Job = "brakes" | "pressure"
type JobSpec = { name: string, tool: string, steps: { Step } }
export type State = {
	job: Job,
	step: number,
	toolOwner: number,
	padsOwner: number,
	moving: boolean,
	raised: boolean,
	removed: { [string]: boolean },
	replaced: { [string]: boolean },
}

local Repair = {}

local brakes: { Step } = {
	{ action = "raise", title = "Lever le pont", target = "Lever", hold = 0 },
}

local function addWheel(wheel: string, side: string)
	local stages: { { action: string, title: string, hold: number, item: ("tool" | "pads")?, remove: boolean? } } = {
		{ action = "loosen", title = "Desserrer la roue", hold = 0.65, item = "tool" },
		{ action = "remove", title = "Déposer la roue", hold = 0.45, remove = true },
		{ action = "install", title = "Poser les plaquettes", hold = 0.85, item = "pads" },
		{ action = "mount", title = "Remonter la roue", hold = 0.45, remove = false },
		{ action = "tighten", title = "Serrer la roue", hold = 0.65, item = "tool" },
	}
	for _, stage in stages do
		table.insert(brakes, {
			action = stage.action .. wheel, title = stage.title .. " · " .. side,
			target = wheel, hold = stage.hold, item = stage.item, wheel = wheel, remove = stage.remove,
		})
	end
end

addWheel("FrontLeft", "avant gauche")
addWheel("FrontRight", "avant droite")
table.insert(brakes, { action = "lower", title = "Abaisser le pont", target = "Lever", hold = 0 })

local jobs: { [Job]: JobSpec } = {
	brakes = { name = "Plaquettes avant", tool = "Clé à choc", steps = table.freeze(brakes) },
	pressure = { name = "Pression des pneus", tool = "Manomètre", steps = table.freeze({
		{ action = "measure", title = "Contrôler la pression · arrière droite", target = "BackRight", hold = 1.15, item = "tool" },
	} :: { Step }) },
}
Repair.jobs = table.freeze(jobs)

function Repair.new(job: Job): State
	return { job = job, step = 1, toolOwner = 0, padsOwner = 0, moving = false, raised = false, removed = {}, replaced = {} }
end

function Repair.current(state: State): Step?
	return Repair.jobs[state.job].steps[state.step]
end

function Repair.canTakePads(state: State): boolean
	if state.job ~= "brakes" or state.padsOwner ~= 0 then return false end
	for i = state.step, #brakes do
		if brakes[i].item == "pads" then return true end
	end
	return false
end

function Repair.act(state: State, playerId: number, action: string): boolean
	local step = Repair.current(state)
	if not step then return false end
	if action == "takeTool" and state.toolOwner == 0 then
		state.toolOwner = playerId
		return true
	elseif action == "returnTool" and state.toolOwner == playerId then
		state.toolOwner = 0
		return true
	elseif action == "takePads" and Repair.canTakePads(state) then
		state.padsOwner = playerId
		return true
	end

	local owner = if step.item == "pads" then state.padsOwner else state.toolOwner
	if state.moving or action ~= step.action or (step.item and owner ~= playerId) then return false end
	if action == "raise" or action == "lower" then
		state.moving = true
		return true
	end
	if step.wheel and step.remove ~= nil then state.removed[step.wheel] = step.remove end
	if step.wheel and step.item == "pads" then
		state.padsOwner = 0
		state.replaced[step.wheel] = true
	end
	state.step += 1
	return true
end

function Repair.finishLift(state: State)
	if not state.moving then return end
	state.raised = not state.raised
	state.moving = false
	state.step += 1
end

function Repair.release(state: State, playerId: number)
	if state.toolOwner == playerId then state.toolOwner = 0 end
	if state.padsOwner == playerId then state.padsOwner = 0 end
end

return Repair

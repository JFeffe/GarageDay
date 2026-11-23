--!strict

export type Job = "brakes" | "pressure" | "oil" | "battery"
export type Cargo = "pads" | "pan" | "usedOil" | "freshOil" | "emptyBottle" | "oldBattery" | "newBattery"
export type Motion = "raise" | "lower" | "openHood" | "closeHood"
type CargoSpec = { name: string, action: string, target: string, hint: string, stock: boolean? }
export type Step = {
	action: string,
	title: string,
	target: string,
	hold: number,
	hint: string?,
	tool: boolean?,
	cargo: Cargo?,
	output: Cargo?,
	motion: Motion?,
	wheel: string?,
	remove: boolean?,
}
type JobSpec = { name: string, tool: string?, steps: { Step } }
export type State = {
	job: Job,
	step: number,
	toolOwner: number,
	carried: { [Cargo]: number },
	generated: { [Cargo]: boolean },
	moving: boolean,
	raised: boolean,
	hoodOpen: boolean,
	battery: "old" | "empty" | "new",
	pressure: number?,
	removed: { [string]: boolean },
	replaced: { [string]: boolean },
}

local Repair = {}
local cargo: { [Cargo]: CargoSpec } = {
	pads = { name = "Plaquettes", action = "Prendre les plaquettes", target = "Pads", hint = "Prends les plaquettes à l’étagère CHÂSSIS.", stock = true },
	pan = { name = "Bac de vidange", action = "Prendre le bac", target = "OilPan", hint = "Prends le bac au poste VIDANGE.", stock = true },
	usedOil = { name = "Bac d’huile usée", action = "Ramasser le bac plein", target = "UsedPan", hint = "Récupère le bac plein sous l’avant de la voiture." },
	freshOil = { name = "Huile neuve", action = "Prendre de l’huile neuve", target = "OilStock", hint = "Prends un bidon au poste VIDANGE.", stock = true },
	emptyBottle = { name = "Bidon vide", action = "Ramasser le bidon", target = "OilCap", hint = "Récupère le bidon vide près du moteur." },
	oldBattery = { name = "Batterie usée", action = "Ramasser la batterie usée", target = "BatteryTray", hint = "Récupère la batterie usée sur le bord du moteur." },
	newBattery = { name = "Batterie neuve", action = "Prendre une batterie neuve", target = "BatteryStock", hint = "Prends une batterie à l’étagère ÉLECTRICITÉ.", stock = true },
}
Repair.cargo = table.freeze(cargo)

local raise: Step = { action = "raise", title = "Lever le pont", target = "Lever", hold = 0, motion = "raise" }
local lower: Step = { action = "lower", title = "Abaisser le pont", target = "Lever", hold = 0, motion = "lower" }
local openHood: Step = { action = "openHood", title = "Ouvrir le capot", target = "Hood", hold = 0.25, motion = "openHood" }
local closeHood: Step = { action = "closeHood", title = "Refermer le capot", target = "Hood", hold = 0.25, motion = "closeHood" }

local brakes: { Step } = { raise }
local function addWheel(wheel: string, side: string)
	local stages: { { action: string, title: string, hold: number, tool: boolean?, cargo: Cargo?, remove: boolean? } } = {
		{ action = "loosen", title = "Desserrer la roue", hold = 0.65, tool = true },
		{ action = "remove", title = "Déposer la roue", hold = 0.45, remove = true },
		{ action = "install", title = "Poser les plaquettes", hold = 0.85, cargo = "pads" },
		{ action = "mount", title = "Remonter la roue", hold = 0.45, remove = false },
		{ action = "tighten", title = "Serrer la roue", hold = 0.65, tool = true },
	}
	for _, stage in stages do
		table.insert(brakes, {
			action = stage.action .. wheel, title = stage.title .. " · " .. side,
			target = wheel, hold = stage.hold, tool = stage.tool, cargo = stage.cargo,
			wheel = wheel, remove = stage.remove, hint = "Approche-toi de la roue indiquée.",
		})
	end
end
addWheel("FrontLeft", "avant gauche")
addWheel("FrontRight", "avant droite")
table.insert(brakes, lower)

local jobs: { [Job]: JobSpec } = {
	brakes = { name = "Plaquettes avant", tool = "Clé à choc", steps = table.freeze(brakes) },
	pressure = { name = "Pression des pneus", tool = "Manomètre", steps = table.freeze({
		{ action = "measure", title = "Mesurer la pression", target = "BackRight", hold = 0.7, tool = true,
			hint = "Vise la valve de la roue arrière droite." },
		{ action = "inflate", title = "Gonfler le pneu à 34 psi", target = "BackRight", hold = 1.25, tool = true },
		{ action = "verifyPressure", title = "Vérifier la pression", target = "BackRight", hold = 0.65, tool = true,
			hint = "Confirme la lecture avant de rendre la voiture." },
	} :: { Step }) },
	oil = { name = "Vidange", steps = table.freeze({
		raise,
		{ action = "drain", title = "Vidanger dans le bac", target = "Drain", hold = 1.25, cargo = "pan", output = "usedOil",
			hint = "Place le bac sous l’avant de la voiture." },
		{ action = "recycleOil", title = "Vider le bac d’huile usée", target = "WasteOil", hold = 0.8, cargo = "usedOil" },
		lower,
		openHood,
		{ action = "fillOil", title = "Verser l’huile neuve", target = "OilCap", hold = 1.15, cargo = "freshOil", output = "emptyBottle" },
		{ action = "recycleBottle", title = "Déposer le bidon vide", target = "Recycling", hold = 0.45, cargo = "emptyBottle" },
		closeHood,
	} :: { Step }) },
	battery = { name = "Batterie", steps = table.freeze({
		openHood,
		{ action = "removeBattery", title = "Retirer la batterie usée", target = "BatteryTray", hold = 0.85, output = "oldBattery" },
		{ action = "recycleBattery", title = "Recycler la batterie usée", target = "Recycling", hold = 0.5, cargo = "oldBattery" },
		{ action = "installBattery", title = "Installer la batterie neuve", target = "BatteryTray", hold = 1.05, cargo = "newBattery" },
		closeHood,
		{ action = "testIgnition", title = "Tester le démarrage", target = "Door", hold = 0.7,
			hint = "Essaye le démarreur depuis la porte conducteur." },
	} :: { Step }) },
}
Repair.jobs = table.freeze(jobs)

function Repair.new(job: Job): State
	return { job = job, step = 1, toolOwner = 0, carried = {}, generated = {}, moving = false, raised = false,
		hoodOpen = false, battery = "old", pressure = nil, removed = {}, replaced = {} }
end

function Repair.current(state: State): Step?
	return jobs[state.job].steps[state.step]
end

function Repair.canTake(state: State, item: Cargo): boolean
	local spec = cargo[item]
	if state.carried[item] or not (spec.stock or state.generated[item]) then return false end
	local steps = jobs[state.job].steps
	for i = state.step, #steps do
		if steps[i].cargo == item then return true end
	end
	return false
end

function Repair.take(state: State, playerId: number, item: Cargo): boolean
	if playerId == 0 or not Repair.canTake(state, item) then return false end
	state.carried[item] = playerId
	return true
end

function Repair.act(state: State, playerId: number, action: string): boolean
	local step = Repair.current(state)
	if not step or playerId == 0 then return false end
	if action == "takeTool" and jobs[state.job].tool and state.toolOwner == 0 then
		state.toolOwner = playerId
		return true
	elseif action == "returnTool" and state.toolOwner == playerId then
		state.toolOwner = 0
		return true
	end

	if state.moving or action ~= step.action or (step.tool and state.toolOwner ~= playerId)
		or (step.cargo and state.carried[step.cargo] ~= playerId) then return false end
	if step.motion then
		state.moving = true
		return true
	end
	if step.cargo then state.carried[step.cargo] = nil end
	if step.output then
		state.generated[step.output] = true
		if step.output ~= "usedOil" then state.carried[step.output] = playerId end
	end
	if step.wheel and step.remove ~= nil then state.removed[step.wheel] = step.remove end
	if step.wheel and step.cargo == "pads" then state.replaced[step.wheel] = true end
	if action == "measure" then state.pressure = 28
	elseif action == "inflate" then state.pressure = 34
	elseif action == "removeBattery" then state.battery = "empty"
	elseif action == "installBattery" then state.battery = "new" end
	state.step += 1
	return true
end

function Repair.finishMotion(state: State)
	if not state.moving then return end
	local step = Repair.current(state)
	local motion = if step then step.motion else nil
	if motion == "raise" or motion == "lower" then state.raised = motion == "raise" end
	if motion == "openHood" or motion == "closeHood" then state.hoodOpen = motion == "openHood" end
	state.moving = false
	state.step += 1
end

function Repair.release(state: State, playerId: number)
	if state.toolOwner == playerId then state.toolOwner = 0 end
	for item, owner in state.carried do
		if owner == playerId then state.carried[item] = nil end
	end
end

return Repair

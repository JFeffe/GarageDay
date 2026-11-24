--!strict

export type Motion = "raise" | "lower" | "openHood" | "closeHood"
export type Faults = {
	wheel: string?, rightDamper: boolean?, rearLamp: boolean?, crackedShield: boolean?, badPuncture: boolean?,
	windowModule: boolean?, weakBattery: boolean?, highPressure: boolean?, oilRecovery: boolean?,
}
export type Step = {
	action: string, title: string, target: string, hold: number,
	tool: string?, cargo: string?, output: string?, leaveAt: string?, storeAt: string?, motion: Motion?,
	wheel: string?, wheelState: ("removed" | "installed" | "new")?, component: string?, componentState: ("removed" | "new")?,
	note: string?, reading: number?, quote: ("battery" | "window")?, rate: string?,
	after: { Step }?, job: string?, raised: boolean?, hoodOpen: boolean?,
}
type ToolSpec = { name: string, target: string }
type CargoSpec = { name: string, target: string?, hint: string, large: boolean?, asset: string? }
type JobSpec = { name: string, amount: number, unlock: number, steps: (Faults) -> { Step } }
type WorkOrder = { jobs: { [string]: { Step } }, looseWheels: { [string]: string }, oilDrained: boolean }
export type State = {
	job: string, steps: { Step }, index: number, tools: { [string]: number }, carried: { [string]: number },
	placements: { [string]: string }, moving: boolean, raised: boolean, hoodOpen: boolean,
	wheels: { [string]: string }, components: { [string]: string },
	note: string, pressure: number?, billable: boolean, addBattery: boolean, surcharge: number,
	done: { [Step]: boolean }, motionStep: Step?, order: WorkOrder?,
}

local Repair = {}
local tools: { [string]: ToolSpec } = {
	impact = { name = "Clé à choc", target = "Impact" },
	pressure = { name = "Manomètre", target = "PressureTool" },
	inspection = { name = "Valise de diagnostic", target = "Diagnostic" },
	ratchet = { name = "Clé à cliquet", target = "Ratchet" },
	probe = { name = "Sonde de contrôle", target = "Probe" },
	puller = { name = "Extracteur", target = "Puller" },
}
Repair.tools = table.freeze(tools)

local cargo: { [string]: CargoSpec } = {
	pads = { name = "Plaquettes", target = "Pads", hint = "Prends des plaquettes au rayon CHÂSSIS." },
	oldPads = { name = "Plaquettes usées", hint = "Amène les plaquettes démontées au bac à métaux." },
	pan = { name = "Bac de vidange", target = "OilPan", hint = "Prends le bac au poste VIDANGE.", large = true },
	usedOil = { name = "Bac d’huile usée", hint = "Ramasse le bac plein devant le moteur, puis apporte-le au fût HUILE USÉE.", large = true },
	freshOil = { name = "Huile neuve", target = "OilStock", hint = "Prends un bidon au poste VIDANGE." },
	emptyBottle = { name = "Bidon d’huile vide", hint = "Ramasse le bidon vide." },
	coolant = { name = "Liquide de refroidissement", target = "CoolantStock", hint = "Prends un bidon au rayon FLUIDES." },
	emptyCoolant = { name = "Bidon de liquide vide", hint = "Ramasse le bidon vide." },
	oldBattery = { name = "Batterie usée", hint = "Ramasse la batterie déposée.", large = true },
	newBattery = { name = "Batterie neuve", target = "BatteryStock", hint = "Prends une batterie au rayon ÉLECTRICITÉ.", large = true },
	newTire = { name = "Roue neuve", target = "TireRack", hint = "Prends une roue neuve au rack ou au chariot.", large = true },
	serviceWheel = { name = "Roue du client", hint = "Reprends la roue du client à l’endroit où elle a été déposée.", large = true },
	patch = { name = "Rustine", target = "PatchStock", hint = "Prends une rustine au rayon CHÂSSIS." },
	newBearing = { name = "Roulement neuf", target = "BearingStock", hint = "Prends un roulement au rayon CHÂSSIS." },
	oldBearing = { name = "Roulement usé", hint = "Ramasse le roulement extrait." },
	newMuffler = { name = "Silencieux neuf", target = "MufflerStock", hint = "Prends un silencieux au rack CHÂSSIS.", large = true },
	oldMuffler = { name = "Silencieux usé", hint = "Récupère le silencieux détaché.", large = true },
	newDamper = { name = "Amortisseur neuf", target = "DamperStock", hint = "Prends un amortisseur au rack CHÂSSIS." },
	oldDamper = { name = "Amortisseur usé", hint = "Récupère l’amortisseur retiré." },
	newShield = { name = "Cache moteur neuf", target = "ShieldStock", hint = "Prends un cache au rack CHÂSSIS.", large = true },
	oldShield = { name = "Cache cassé", hint = "Récupère le cache démonté.", large = true },
	newBelt = { name = "Courroie neuve", target = "BeltStock", hint = "Prends une courroie au rayon ÉLECTRICITÉ." },
	oldBelt = { name = "Courroie usée", hint = "Ramasse la courroie retirée." },
	newWipers = { name = "Balais neufs", target = "WiperStock", hint = "Prends les balais au rayon ÉLECTRICITÉ." },
	oldWipers = { name = "Balais usés", hint = "Ramasse les balais déposés." },
	frontBulb = { name = "Ampoule avant", target = "FrontBulbStock", hint = "Prends une ampoule avant au rayon ÉLECTRICITÉ." },
	rearBulb = { name = "Ampoule arrière", target = "RearBulbStock", hint = "Prends une ampoule arrière au rayon ÉLECTRICITÉ." },
	oldBulb = { name = "Ampoule grillée", hint = "Ramasse l’ampoule retirée." },
	newWindow = { name = "Module de vitre neuf", target = "WindowStock", hint = "Prends un module au rayon ÉLECTRICITÉ." },
	oldWindow = { name = "Module de vitre usé", hint = "Ramasse le module retiré." },
}
local raise: Step = { action = "raise", title = "Lever le pont", target = "Lever", hold = 0, motion = "raise" }
local lower: Step = { action = "lower", title = "Abaisser le pont", target = "Lever", hold = 0, motion = "lower" }
local openHood: Step = { action = "openHood", title = "Ouvrir le capot", target = "Hood", hold = 0.25, motion = "openHood" }
local closeHood: Step = { action = "closeHood", title = "Refermer le capot", target = "Hood", hold = 0.25, motion = "closeHood" }
local ignition: Step = { action = "ignition", title = "Tester le démarrage", target = "Door", hold = 0.65, note = "Démarrage vérifié." }
local wheelNames: { [string]: string } = { FrontLeft = "avant gauche", FrontRight = "avant droite", BackLeft = "arrière gauche", BackRight = "arrière droite" }
local allWheels = { "FrontLeft", "FrontRight", "BackLeft", "BackRight" }
Repair.wheels = table.freeze(allWheels)
for _, wheel in allWheels do
	cargo["usedTire_" .. wheel] = {
		name = "Roue usée · " .. wheelNames[wheel],
		hint = "Ramasse la roue déposée et amène-la au recyclage.",
		large = true, asset = "usedTire",
	}
	local front = wheel:sub(1, 5) == "Front"
	if front then
		local pads = table.clone(cargo.oldPads)
		pads.asset = "oldPads"
		cargo["oldPads_" .. wheel] = pads
	end
	for _, job in (if front then { "brakes", "puncture", "bearing" } else { "puncture", "bearing" }) do
		local serviceWheel = table.clone(cargo.serviceWheel)
		serviceWheel.name ..= " · " .. wheelNames[wheel]
		serviceWheel.asset = "serviceWheel"
		cargo["serviceWheel_" .. job .. "_" .. wheel] = serviceWheel
	end
end
Repair.cargo = table.freeze(cargo)

Repair.disposal = table.freeze({ WasteOil = true, Recycling = true, Scrap = true, TireBin = true } :: { [string]: boolean })

function Repair.assetKey(key: string): string
	local spec = cargo[key]
	return if spec and spec.asset then spec.asset else key
end

function Repair.isWheel(key: string): boolean
	local asset = Repair.assetKey(key)
	return asset == "newTire" or asset == "usedTire" or asset == "serviceWheel"
end

local function step(action: string, title: string, target: string, hold: number, spec: {[string]: any}?): Step
	local result = (spec or {}) :: any
	result.action = action
	result.title = title
	result.target = target
	result.hold = hold
	return result
end

local function recycle(item: string, bin: string): Step
	return step("recycle_" .. Repair.assetKey(item), "Recycler · " .. cargo[item].name, bin, 0.45, { cargo = item })
end

local function wheelOff(line: { Step }, wheel: string, item: string): (Step, Step)
	local side = wheelNames[wheel]
	local loosen = step("loosen", "Desserrer · " .. side, wheel, 0.65, { tool = "impact", rate = "impact" })
	local remove = step("removeWheel", "Déposer la roue · " .. side, wheel, 0.42, {
		wheel = wheel, wheelState = "removed", output = item, leaveAt = "Floor" .. wheel,
	})
	table.insert(line, loosen)
	table.insert(line, remove)
	return loosen, remove
end

local function wheelOn(line: { Step }, wheel: string, item: string): (Step, Step)
	local side = wheelNames[wheel]
	local mount = step("mountWheel", "Remonter la roue · " .. side, wheel, 0.48, {
		wheel = wheel, wheelState = if item == "newTire" then "new" else "installed", cargo = item,
	})
	local tighten = step("tighten", "Serrer · " .. side, wheel, 0.65, { tool = "impact", rate = "impact" })
	table.insert(line, mount)
	table.insert(line, tighten)
	return mount, tighten
end

local function suspendWheel(line: { Step }, wheel: string, location: string)
	wheelOff(line, wheel, "serviceWheel")
	table.insert(line, step("storeWheel", "Poser la roue", location, 0.35, { cargo = "serviceWheel", storeAt = location }))
end

local function swap(line: { Step }, component: string, target: string, old: string, new: string, bin: string, tool: string?)
	table.insert(line, step("remove_" .. component, "Retirer · " .. cargo[old].name, target, 0.68,
		{ tool = tool, output = old, leaveAt = if tool then "Workpiece" else nil, component = component, componentState = "removed" }))
	table.insert(line, recycle(old, bin))
	table.insert(line, step("fit_" .. component, "Poser · " .. cargo[new].name, target, 0.85,
		{ cargo = new, component = component, componentState = "new" }))
end

local jobs: { [string]: JobSpec } = {
	tires = { name = "Pneus", amount = 40, unlock = 1, steps = function()
		local line = { raise }
		local finishedWheels = {}
		for _, wheel in allWheels do
			local item = "usedTire_" .. wheel
			local loosen, remove = wheelOff(line, wheel, item)
			loosen.after = { raise }
			local discard = recycle(item, "TireBin")
			table.insert(line, discard)
			local mount, tighten = wheelOn(line, wheel, "newTire")
			mount.after = { remove }
			table.insert(finishedWheels, discard)
			table.insert(finishedWheels, tighten)
		end
		local finish = table.clone(lower)
		finish.after = finishedWheels
		table.insert(line, finish)
		return line
	end },
	brakes = { name = "Plaquettes", amount = 48, unlock = 2, steps = function()
		local line = { raise }
		for _, wheel in { "FrontLeft", "FrontRight" } do
			suspendWheel(line, wheel, "WheelStand")
			swap(line, "Pads" .. wheel, wheel, "oldPads", "pads", "Scrap", "ratchet")
			wheelOn(line, wheel, "serviceWheel")
		end
		table.insert(line, lower)
		return line
	end },
	puncture = { name = "Crevaison", amount = 38, unlock = 3, steps = function(faults)
		local wheel = faults.wheel or "BackRight"
		local line = { raise }
		suspendWheel(line, wheel, "Bench")
		table.insert(line, step("testPuncture", "Localiser la fuite à l’établi", "Bench", 0.75, {
			note = if faults.badPuncture then "Flanc abîmé. La roue doit être recyclée." else "Fuite dans la bande de roulement. Pose une rustine.",
		}))
		if faults.badPuncture then
			table.insert(line, step("recyclePuncture", "Recycler la roue irréparable", "TireBin", 0.5, { cargo = "serviceWheel" }))
			wheelOn(line, wheel, "newTire")
		else
			table.insert(line, step("patch", "Poser la rustine à l’établi", "Bench", 1.15, { cargo = "patch", note = "Fuite colmatée. Reprends la roue." }))
			wheelOn(line, wheel, "serviceWheel")
		end
		table.insert(line, lower)
		return line
	end },
	bearing = { name = "Roulement", amount = 52, unlock = 6, steps = function(faults)
		local bad = faults.wheel or "BackRight"
		local line = { raise }
		for _, wheel in allWheels do
			table.insert(line, step("listen", "Écouter la roue · " .. wheelNames[wheel], wheel, 0.55, {
				tool = "probe", note = if wheel == bad then "Grincement détecté. Dépose cette roue." else "Roulement sain. Vérifie la roue suivante.",
			}))
			if wheel == bad then break end
		end
		suspendWheel(line, bad, "WheelStand")
		swap(line, "Bearing" .. bad, bad, "oldBearing", "newBearing", "Scrap", "puller")
		wheelOn(line, bad, "serviceWheel")
		table.insert(line, lower)
		return line
	end },
	oil = { name = "Vidange", amount = 35, unlock = 1, steps = function(faults)
		local line = { raise }
		if faults.oilRecovery then
			table.insert(line, step("drain", "Vidanger dans le récupérateur", "Drain", 1.1, { note = "Huile usée récupérée." }))
		else
			table.insert(line, step("drain", "Vidanger dans le bac", "Drain", 1.25, { cargo = "pan", output = "usedOil", leaveAt = "UsedPan" }))
			table.insert(line, step("recycle_usedOil", "Vider le bac d’huile usée", "WasteOil", 0.8, { cargo = "usedOil" }))
		end
		table.insert(line, lower)
		table.insert(line, openHood)
		table.insert(line, step("fillOil", "Verser l’huile neuve", "OilCap", 1.15, { cargo = "freshOil", output = "emptyBottle" }))
		table.insert(line, recycle("emptyBottle", "Recycling"))
		table.insert(line, closeHood)
		return line
	end },
	battery = { name = "Batterie", amount = 45, unlock = 1, steps = function()
		local line = { openHood }
		swap(line, "Battery", "BatteryTray", "oldBattery", "newBattery", "Recycling", nil)
		table.insert(line, closeHood)
		table.insert(line, ignition)
		return line
	end },
	pressure = { name = "Pression", amount = 25, unlock = 1, steps = function(faults)
		local wheel = faults.wheel or "BackRight"
		return {
			step("measure", "Mesurer la pression · " .. wheelNames[wheel], wheel, 0.7, { tool = "pressure", reading = if faults.highPressure then 41 else 27 }),
			step("adjustPressure", if faults.highPressure then "Purger jusqu’à 34 psi" else "Gonfler jusqu’à 34 psi", wheel, 1.25,
				{ tool = "pressure", reading = 34, rate = "compressor" }),
			step("verifyPressure", "Confirmer la pression", wheel, 0.6, { tool = "pressure", note = "Pression confirmée à 34 psi." }),
		}
	end },
	inspection = { name = "Inspection", amount = 30, unlock = 1, steps = function(faults)
		local line = { openHood, step("scan", "Brancher la valise et lire le diagnostic", "DiagnosticPort", 1.6,
			{ tool = "inspection", rate = "diagnostic", note = if faults.weakBattery then "Batterie faible. Présente le diagnostic au client." else "Diagnostic terminé. Aucun défaut supplémentaire." }),
			closeHood }
		if faults.weakBattery then table.insert(line, step("quoteBattery", "Proposer une batterie au client", "Quote", 0.65, { quote = "battery" })) end
		return line
	end },
	coolant = { name = "Refroidissement", amount = 35, unlock = 1, steps = function()
		return { openHood, step("fillCoolant", "Faire l’appoint de liquide", "Radiator", 1.2, { cargo = "coolant", output = "emptyCoolant" }),
			recycle("emptyCoolant", "Recycling"), step("verifyCoolant", "Vérifier le niveau", "Radiator", 0.55), closeHood }
	end },
	muffler = { name = "Silencieux", amount = 48, unlock = 4, steps = function()
		local line = { raise, step("unboltMuffler", "Desserrer les fixations du silencieux", "Exhaust", 0.8, { tool = "ratchet" }) }
		swap(line, "Muffler", "Exhaust", "oldMuffler", "newMuffler", "Scrap", nil)
		table.insert(line, lower)
		return line
	end },
	damper = { name = "Amortisseur", amount = 46, unlock = 4, steps = function(faults)
		local side = if faults.rightDamper then "Right" else "Left"
		local line = { raise }
		for _, check in { "Left", "Right" } do
			table.insert(line, step("testDamper", "Tester la suspension " .. (if check == "Left" then "gauche" else "droite"),
				"Damper" .. check, 0.65, { tool = "probe", note = if check == side then "Amortisseur usé." else "Amortisseur sain." }))
			if check == side then break end
		end
		swap(line, "Damper" .. side, "Damper" .. side, "oldDamper", "newDamper", "Scrap", "ratchet")
		table.insert(line, lower)
		return line
	end },
	shield = { name = "Cache moteur", amount = 28, unlock = 2, steps = function(faults)
		local line = { raise, step("inspectShield", "Contrôler le cache sous le moteur", "Drain", 0.6, { tool = "ratchet",
			note = if faults.crackedShield then "Cache fissuré. Remplace-le." else "Cache intact. Resserre ses fixations." }) }
		if faults.crackedShield then swap(line, "Shield", "Drain", "oldShield", "newShield", "Scrap", "ratchet")
		else table.insert(line, step("tightenShield", "Resserrer les fixations du cache", "Drain", 0.75, { tool = "ratchet" })) end
		table.insert(line, lower)
		return line
	end },
	lights = { name = "Feu grillé", amount = 26, unlock = 1, steps = function(faults)
		local key = if faults.rearLamp then "RearLamp" else "FrontLamp"
		local line = { step("testLights", "Allumer les feux", "Door", 0.55,
			{ component = key, componentState = "removed", note = if faults.rearLamp then "Ampoule arrière grillée." else "Ampoule avant grillée." }) }
		swap(line, key, key, "oldBulb", if faults.rearLamp then "rearBulb" else "frontBulb", "Recycling", nil)
		table.insert(line, step("verifyLights", "Vérifier les feux", "Door", 0.55))
		return line
	end },
	belt = { name = "Courroie", amount = 36, unlock = 3, steps = function()
		local line = { openHood }
		swap(line, "Belt", "Belt", "oldBelt", "newBelt", "Recycling", "ratchet")
		table.insert(line, closeHood)
		table.insert(line, ignition)
		return line
	end },
	wipers = { name = "Essuie-glaces", amount = 22, unlock = 1, steps = function()
		local line = {}
		swap(line, "Wipers", "Wipers", "oldWipers", "newWipers", "Recycling", nil)
		table.insert(line, step("testWipers", "Faire un aller-retour des essuie-glaces", "Door", 0.6))
		return line
	end },
	window = { name = "Vitre électrique", amount = 31, unlock = 5, steps = function(faults)
		local line = { step("testWindow", "Tester la montée de la vitre", "Window", 0.6,
			{ note = if faults.windowModule then "Module HS. Demande l’accord du client." else "Rail bloqué. Prends la clé à cliquet." }) }
		if faults.windowModule then
			table.insert(line, step("quoteWindow", "Proposer le module (+18 $)", "Quote", 0.65, { quote = "window" }))
			swap(line, "WindowModule", "Window", "oldWindow", "newWindow", "Recycling", "ratchet")
		else
			table.insert(line, step("unblockWindow", "Débloquer et régler le rail", "Window", 1.15, { tool = "ratchet" }))
		end
		table.insert(line, step("verifyWindow", "Vérifier la course de la vitre", "Window", 0.65))
		return line
	end },
}

Repair.jobs = table.freeze(jobs)

function Repair.new(job: string, faults: Faults?, toolOwners: { [string]: number }?): State
	return { job = job, steps = jobs[job].steps(faults or {}), index = 1, tools = toolOwners or {}, carried = {}, placements = {},
		moving = false, raised = false, hoodOpen = false, wheels = {}, components = {}, note = "", pressure = nil,
		billable = true, addBattery = false, surcharge = 0, done = {} }
end

local controls = { raise, lower, openHood, closeHood }
local engineTargets: { [string]: boolean } = { OilCap = true, Radiator = true, BatteryTray = true, DiagnosticPort = true, Belt = true }
local undersideTargets: { [string]: boolean } = { Drain = true, Exhaust = true, DamperLeft = true, DamperRight = true }
local standingTargets: { [string]: boolean } = { Door = true, Window = true, Wipers = true, FrontLamp = true, RearLamp = true }

local function wheelCargo(key: string?, job: string, wheel: string?): string?
	if key == "serviceWheel" then return "serviceWheel_" .. job .. "_" .. assert(wheel) end
	if key == "oldPads" then return "oldPads_" .. assert(wheel) end
	return key
end

function Repair.addJob(state: State, job: string, faults: Faults?)
	local order = assert(state.order)
	if order.jobs[job] then return end
	local original = jobs[job].steps(faults or {})
	local work: { Step } = {}
	local copies: { [Step]: Step } = {}
	local sources: { [Step]: { Step } } = {}
	local wheel: string?
	local drain: Step?
	for index, base in original do
		local previous = original[index - 1]
		sources[base] = base.after or (if previous then { previous } else {})
		-- Position the shared lift and hood as needed. A wheel can stay beside the car during brake or bearing work.
		if base.motion or base.storeAt == "WheelStand" then continue end
		if base.action == "loosen" then wheel = base.target end
		local action: Step = table.clone(base)
		action.job = job
		action.cargo = wheelCargo(action.cargo, job, wheel)
		action.output = wheelCargo(action.output, job, wheel)
		if engineTargets[base.target] then
			action.raised, action.hoodOpen = false, true
		elseif undersideTargets[base.target] or (wheelNames[base.target] and job ~= "pressure") then
			action.raised = true
		elseif standingTargets[base.target] then
			action.raised = false
		end
		if base.action == "ignition" then action.hoodOpen = false end
		if base.action:sub(1, 7) == "remove_" and not base.leaveAt then action.leaveAt = "Workpiece" end
		if base.action == "drain" then drain = base end
		if base.action == "fillOil" then sources[base] = { assert(drain) } end
		if (base.action == "loosen" and job == "brakes") or base.action == "listen" or base.action == "testDamper" then
			sources[base] = {}
		end
		copies[base] = action
		table.insert(work, action)
		table.insert(state.steps, action)
	end
	local function requireAction(base: Step, prerequisites: { Step }, skipDisposal: boolean)
		local copy = copies[base]
		if copy and not (skipDisposal and Repair.disposal[base.target]) then
			if not table.find(prerequisites, copy) then table.insert(prerequisites, copy) end
		else
			for _, earlier in sources[base] do requireAction(earlier, prerequisites, skipDisposal) end
		end
	end
	for _, base in original do
		local action = copies[base]
		if not action then continue end
		local prerequisites = {}
		for _, earlier in sources[base] do
			requireAction(earlier, prerequisites, not Repair.disposal[action.target])
		end
		action.after = prerequisites
	end
	order.jobs[job] = work
end

function Repair.forOrder(jobIds: { string }, faults: { [string]: Faults }, toolOwners: { [string]: number }): State
	local state = Repair.new(jobIds[1], nil, toolOwners)
	state.steps = {}
	state.order = { jobs = {}, looseWheels = {}, oilDrained = false }
	for _, job in jobIds do Repair.addJob(state, job, faults[job]) end
	return state
end

function Repair.jobProgress(state: State, job: string): (number, number)
	local order = state.order
	local steps = if order then order.jobs[job] or {} else state.steps
	local completed = 0
	for _, action in steps do
		if state.done[action] then completed += 1 end
	end
	return completed, #steps
end

local function dependenciesDone(state: State, step: Step): boolean
	for _, prerequisite in step.after or {} do
		if not state.done[prerequisite] then return false end
	end
	return true
end

local function inPosition(state: State, step: Step): boolean
	return (step.raised == nil or step.raised == state.raised) and (step.hoodOpen == nil or step.hoodOpen == state.hoodOpen)
end

local function canMove(state: State, step: Step): boolean
	local order = assert(state.order)
	if step == lower then return state.raised and next(order.looseWheels) == nil end
	if step == closeHood then return state.hoodOpen end
	if state.index > #state.steps then return false end
	if step == raise then return not state.raised and not state.hoodOpen end
	return step == openHood and not state.hoodOpen and not state.raised
end

local function ready(state: State, step: Step, index: number): boolean
	if state.done[step] or state.index > #state.steps then return false end
	local order = state.order
	if order then
		local wheelJob = order.looseWheels[step.target]
		if wheelJob and wheelJob ~= step.job then return false end
		if step.action == "ignition" then
			if order.oilDrained or state.components.Belt == "removed" or state.components.Battery == "removed" then return false end
		end
		return dependenciesDone(state, step) and inPosition(state, step)
	end
	if step.after then return dependenciesDone(state, step) end
	return index == 1 or state.done[state.steps[index - 1]] == true
end

function Repair.available(state: State): { Step }
	if state.motionStep then return { state.motionStep } end
	local available = {}
	for index, step in state.steps do
		if ready(state, step, index) then table.insert(available, step) end
	end
	if state.order then
		for _, control in controls do
			if canMove(state, control) then table.insert(available, control) end
		end
	end
	return available
end

function Repair.current(state: State): Step?
	if state.motionStep then return state.motionStep end
	local order = state.order
	if order then
		for _, step in order.jobs[state.job] or {} do
			if state.done[step] or not dependenciesDone(state, step) then continue end
			if not inPosition(state, step) then
				local control = if step.raised == true then (if state.hoodOpen then closeHood else raise)
					elseif state.raised then lower elseif step.hoodOpen == true then openHood else closeHood
				if canMove(state, control) then return control end
			elseif ready(state, step, 0) then
				return step
			end
		end
	end
	for index, step in state.steps do
		if ready(state, step, index) then return step end
	end
	if order then
		if canMove(state, lower) then return lower end
		if canMove(state, closeHood) then return closeHood end
	end
	return nil
end

function Repair.canChooseJob(state: State): boolean
	return state.index == 1 and not state.moving and next(state.carried) == nil and next(state.placements) == nil
end

function Repair.carrying(state: State, playerId: number): string?
	for item, owner in state.carried do
		if owner == playerId then return item end
	end
	return nil
end

function Repair.using(state: State, playerId: number): string?
	for tool, owner in state.tools do
		if owner == playerId then return tool end
	end
	return nil
end

function Repair.canTakeTool(state: State, key: string): boolean
	if state.tools[key] then return false end
	for _, step in state.steps do
		if not state.done[step] and step.tool == key then return state.index <= #state.steps end
	end
	return false
end

function Repair.takeTool(state: State, playerId: number, key: string): boolean
	if playerId == 0 or Repair.using(state, playerId) or Repair.carrying(state, playerId)
		or not Repair.canTakeTool(state, key) then return false end
	state.tools[key] = playerId
	return true
end

function Repair.returnTool(state: State, playerId: number, key: string): boolean
	if state.tools[key] ~= playerId then return false end
	state.tools[key] = nil
	return true
end

function Repair.source(state: State, item: string): string?
	local spec = cargo[item]
	if not spec or state.carried[item] then return nil end
	local location = state.placements[item]
	if location then
		if spec.target or location == "Ground" or location == "Recovery" then return location end
		if state.order and location ~= "Bench" then return location end
		for _, step in Repair.available(state) do
			if step.cargo == item then return location end
		end
		return nil
	end
	if spec.target and state.index <= #state.steps then
		for _, step in state.steps do
			if step.cargo == item and not state.done[step] then return spec.target end
		end
	end
	return nil
end

function Repair.take(state: State, playerId: number, item: string): boolean
	if playerId == 0 or Repair.using(state, playerId) or Repair.carrying(state, playerId) or not Repair.source(state, item) then return false end
	state.placements[item] = nil
	state.carried[item] = playerId
	return true
end

function Repair.drop(state: State, playerId: number, place: string): string?
	local item = Repair.carrying(state, playerId)
	if item then
		state.carried[item] = nil
		state.placements[item] = place
	end
	return item
end

function Repair.needsEmptyHands(step: Step): boolean
	return step.cargo == nil and step.output ~= nil and step.leaveAt == nil
end

function Repair.stockFrom(state: State, supply: State, item: string): number?
	if state == supply or not cargo[item].target or state.carried[item] or state.placements[item] then return nil end
	return supply.carried[item]
end

function Repair.act(state: State, playerId: number, action: string | Step, supply: State?): boolean
	if state.moving or playerId == 0 then return false end
	local current = if type(action) == "string" then Repair.current(state) else action
	if not current then return false end
	if type(action) == "string" then
		if current.action ~= action then return false end
	elseif state.order and current.motion then
		if not canMove(state, current) then return false end
	else
		local index = table.find(state.steps, current)
		if not index or not ready(state, current, index) then return false end
	end
	if current.tool and state.tools[current.tool] ~= playerId then return false end
	local inventory = state
	if current.cargo and state.carried[current.cargo] ~= playerId then
		if not supply or Repair.stockFrom(state, supply, current.cargo) ~= playerId then return false end
		inventory = supply
	end
	if Repair.needsEmptyHands(current) and (Repair.carrying(state, playerId) or Repair.using(state, playerId)) then return false end
	if current.motion then
		state.moving, state.motionStep = true, current
		return true
	end
	if current.cargo then
		inventory.carried[current.cargo] = nil
		state.placements[current.cargo] = current.storeAt
	end
	if current.output then
		if current.leaveAt then state.placements[current.output] = current.leaveAt
		else state.carried[current.output] = playerId end
	end
	if current.wheel and current.wheelState then state.wheels[current.wheel] = current.wheelState end
	if current.component and current.componentState then state.components[current.component] = current.componentState end
	if current.reading then state.pressure = current.reading end
	if current.quote == "battery" then state.addBattery = true end
	if current.quote == "window" then state.surcharge = 18 end
	if current.note then state.note = current.note end
	local order = state.order
	if order then
		if current.action == "loosen" then order.looseWheels[current.target] = current.job end
		if current.action == "tighten" then order.looseWheels[current.target] = nil end
		if current.action == "drain" then order.oilDrained = true end
		if current.action == "fillOil" then order.oilDrained = false end
	end
	state.done[current] = true
	state.index += 1
	return true
end

function Repair.decline(state: State, action: Step?): boolean
	if state.moving then return false end
	local current = action or Repair.current(state)
	if not current or not current.quote then return false end
	local index = table.find(state.steps, current)
	if not index or not ready(state, current, index) then return false end
	if current.quote == "window" then state.billable = false end
	state.note = "Intervention reportée."
	local order = state.order
	if order and current.job then
		for _, remaining in order.jobs[current.job] do
			if not state.done[remaining] then
				state.done[remaining] = true
				state.index += 1
			end
		end
	else
		state.index = #state.steps + 1
	end
	return true
end

function Repair.finishMotion(state: State)
	local current = state.motionStep
	if not current then return end
	local motion = current.motion
	if motion == "raise" or motion == "lower" then state.raised = motion == "raise" end
	if motion == "openHood" or motion == "closeHood" then state.hoodOpen = motion == "openHood" end
	state.moving, state.motionStep = false, nil
	if state.order then return end
	state.done[current] = true
	state.index += 1
end

function Repair.release(state: State, playerId: number)
	local tool = Repair.using(state, playerId)
	if tool then state.tools[tool] = nil end
	local item = Repair.carrying(state, playerId)
	if item then
		state.carried[item] = nil
		state.placements[item] = if cargo[item].target then nil else "Recovery"
	end
end

return Repair

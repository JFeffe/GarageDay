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
}
type ToolSpec = { name: string, target: string }
type CargoSpec = { name: string, target: string?, hint: string, large: boolean? }
type JobSpec = { name: string, amount: number, unlock: number, steps: (Faults) -> { Step } }
export type State = {
	job: string, steps: { Step }, index: number, tools: { [string]: number }, carried: { [string]: number },
	placements: { [string]: string }, moving: boolean, raised: boolean, hoodOpen: boolean,
	wheels: { [string]: string }, components: { [string]: string },
	note: string, pressure: number?, billable: boolean, addBattery: boolean, surcharge: number,
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
	usedOil = { name = "Bac d’huile usée", hint = "Ramasse le bac sous le moteur.", large = true },
	freshOil = { name = "Huile neuve", target = "OilStock", hint = "Prends un bidon au poste VIDANGE." },
	emptyBottle = { name = "Bidon d’huile vide", hint = "Ramasse le bidon vide." },
	coolant = { name = "Liquide de refroidissement", target = "CoolantStock", hint = "Prends un bidon au rayon FLUIDES." },
	emptyCoolant = { name = "Bidon de liquide vide", hint = "Ramasse le bidon vide." },
	oldBattery = { name = "Batterie usée", hint = "Ramasse la batterie déposée.", large = true },
	newBattery = { name = "Batterie neuve", target = "BatteryStock", hint = "Prends une batterie au rayon ÉLECTRICITÉ.", large = true },
	newTire = { name = "Roue neuve", target = "TireRack", hint = "Prends une roue neuve au rack ou au chariot.", large = true },
	usedTire = { name = "Roue usée", hint = "Ramasse la roue déposée et amène-la au recyclage.", large = true },
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
Repair.cargo = table.freeze(cargo)

local raise: Step = { action = "raise", title = "Lever le pont", target = "Lever", hold = 0, motion = "raise" }
local lower: Step = { action = "lower", title = "Abaisser le pont", target = "Lever", hold = 0, motion = "lower" }
local openHood: Step = { action = "openHood", title = "Ouvrir le capot", target = "Hood", hold = 0.25, motion = "openHood" }
local closeHood: Step = { action = "closeHood", title = "Refermer le capot", target = "Hood", hold = 0.25, motion = "closeHood" }
local ignition: Step = { action = "ignition", title = "Tester le démarrage", target = "Door", hold = 0.65, note = "Démarrage vérifié." }
local wheelNames: { [string]: string } = { FrontLeft = "avant gauche", FrontRight = "avant droite", BackLeft = "arrière gauche", BackRight = "arrière droite" }
local allWheels = { "FrontLeft", "FrontRight", "BackLeft", "BackRight" }
Repair.wheels = table.freeze(allWheels)

local function step(action: string, title: string, target: string, hold: number, spec: {[string]: any}?): Step
	local result = (spec or {}) :: any
	result.action = action
	result.title = title
	result.target = target
	result.hold = hold
	return result
end

local function recycle(item: string, bin: string): Step
	return step("recycle_" .. item, "Recycler · " .. cargo[item].name, bin, 0.45, { cargo = item })
end

local function wheelOff(line: { Step }, wheel: string, item: string)
	local side = wheelNames[wheel]
	table.insert(line, step("loosen", "Desserrer · " .. side, wheel, 0.65, { tool = "impact", rate = "impact" }))
	table.insert(line, step("removeWheel", "Déposer la roue · " .. side, wheel, 0.42, {
		wheel = wheel, wheelState = "removed", output = item, leaveAt = "Floor" .. wheel,
	}))
end

local function wheelOn(line: { Step }, wheel: string, item: string)
	local side = wheelNames[wheel]
	table.insert(line, step("mountWheel", "Remonter la roue · " .. side, wheel, 0.48, {
		wheel = wheel, wheelState = if item == "newTire" then "new" else "installed", cargo = item,
	}))
	table.insert(line, step("tighten", "Serrer · " .. side, wheel, 0.65, { tool = "impact", rate = "impact" }))
end

local function loadedWheel(line: { Step }, wheel: string)
	wheelOff(line, wheel, "usedTire")
	table.insert(line, recycle("usedTire", "TireBin"))
	wheelOn(line, wheel, "newTire")
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
		for _, wheel in allWheels do loadedWheel(line, wheel) end
		table.insert(line, lower)
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
		billable = true, addBattery = false, surcharge = 0 }
end

function Repair.current(state: State): Step?
	return state.steps[state.index]
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
	for i = state.index, #state.steps do
		if state.steps[i].tool == key then return true end
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
	if state.carried[item] then return nil end
	local current = Repair.current(state)
	local location = state.placements[item]
	if location then
		if not cargo[item].target and location ~= "Ground" and location ~= "Recovery" and (not current or current.cargo ~= item) then return nil end
		return location
	end
	local stock = cargo[item].target
	if stock then
		for i = state.index, #state.steps do if state.steps[i].cargo == item then return stock end end
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
	return step.cargo == nil and step.tool == nil and step.output ~= nil
end

function Repair.act(state: State, playerId: number, action: string): boolean
	local current = Repair.current(state)
	if not current or state.moving or playerId == 0 or current.action ~= action then return false end
	if current.tool and state.tools[current.tool] ~= playerId then return false end
	if current.cargo and state.carried[current.cargo] ~= playerId then return false end
	if Repair.needsEmptyHands(current) and (Repair.carrying(state, playerId) or Repair.using(state, playerId)) then return false end
	if current.motion then
		state.moving = true
		return true
	end
	if current.cargo then
		state.carried[current.cargo] = nil
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
	state.index += 1
	return true
end

function Repair.decline(state: State): boolean
	local current = Repair.current(state)
	if not current or not current.quote then return false end
	if current.quote == "window" then state.billable = false end
	state.note = "Intervention reportée."
	state.index = #state.steps + 1
	return true
end

function Repair.finishMotion(state: State)
	if not state.moving then return end
	local current = Repair.current(state)
	local motion = if current then current.motion else nil
	if motion == "raise" or motion == "lower" then state.raised = motion == "raise" end
	if motion == "openHood" or motion == "closeHood" then state.hoodOpen = motion == "openHood" end
	state.moving = false
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

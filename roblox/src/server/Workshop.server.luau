local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

Players.CharacterAutoLoads = false

local Repair = require(ReplicatedStorage.GarageDay.Repair)
local Service = require(ReplicatedStorage.GarageDay.Service)
local Drive = require(script.Parent.Drive)
local Furniture = require(script.Parent.Furniture)
local Gear = require(script.Parent.GearWorld)
local Props = require(script.Parent.GarageProps)
local World = require(script.Parent.WorkshopWorld)
local WorkshopSaves = require(script.Parent.WorkshopSaves)

local random = Random.new()
local function pick(maximum)
	return random:NextInteger(1, maximum)
end
local state
local session = Instance.new("Folder")
session.Name = "GarageDaySession"
session:SetAttribute("LaunchMode", "menu")
session:SetAttribute("LaunchStatus", "loading")
local bayFolder = Instance.new("Folder")
bayFolder.Name = "Bays"
bayFolder.Parent = session
local saves = WorkshopSaves.new(session, Repair.jobs, pick)
local workshopOwner, workshopReady
local world, lanes, prompts
local owners, equipment, layoutsHeld = {}, {}, {}
local refresh, advance, finishStep, mount

local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = session
	return event
end

local driveControl = remote("DriveControl")
local vendorControl = remote("VendorControl")
local carryControl = remote("CarryControl")
local optionsControl = remote("OptionsControl")
local furnitureControl = remote("FurnitureControl")
local repairFeedback = remote("RepairFeedback")
local repairControl = remote("RepairControl")
local launchControl = remote("LaunchControl")

local function activeRoot(player)
	if not workshopReady or player:GetAttribute("GarageDriverBay") then return nil end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and humanoid and humanoid.Health > 0 then root else nil
end

local function nearby(player, anchor, radius)
	local root = activeRoot(player)
	return root and anchor and anchor:IsDescendantOf(workspace) and (root.Position - anchor.WorldPosition).Magnitude <= radius
end

local function toolHeld(player)
	for key, owner in owners do
		if owner == player.UserId then return key end
	end
end

local function held(player)
	if layoutsHeld[player] then return "furniture", layoutsHeld[player].id end
	if world.cart.owner == player then return "cart" end
	for _, bay in world.bays do
		local key = Repair.carrying(bay.repair, player.UserId)
		if key then return "cargo", key, bay end
	end
	local key = toolHeld(player)
	if key then return "tool", key end
end

local function updateEquipment(player)
	local kind, key, bay = held(player)
	player:SetAttribute("GarageHeldKind", kind)
	player:SetAttribute("GarageHeldKey", key)
	player:SetAttribute("GarageHeldBay", if bay then bay.id else nil)
	local mechanical = kind == "tool" or kind == "cargo"
	local previous = equipment[player]
	local character = player.Character
	if mechanical and character and previous and key == previous.key and previous.item.Parent == character then return end
	if previous then
		if previous.speed and previous.humanoid.Parent then previous.humanoid.WalkSpeed = previous.speed end
		previous.item:Destroy()
	end
	equipment[player] = nil
	if not mechanical then return end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local item = World.makeEquipment(world, key, character)
	if not item then return end
	local speed
	if kind == "cargo" and Repair.cargo[key].large then
		speed = humanoid.WalkSpeed
		humanoid.WalkSpeed = speed * 0.79
	end
	equipment[player] = { key = key, item = item, speed = speed, humanoid = humanoid }
end

local function createPrompt(name, title, object, anchor, hold, action, alternate)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = title
	prompt.ObjectText = object or ""
	prompt.KeyboardKeyCode = alternate or Enum.KeyCode.E
	prompt.GamepadKeyCode = if alternate == Enum.KeyCode.R then Enum.KeyCode.ButtonL1
		elseif alternate then Enum.KeyCode.ButtonY else Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 6.4
	prompt.RequiresLineOfSight = true
	prompt.ClickablePrompt = true
	prompt.HoldDuration = hold
	prompt.Enabled = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if prompt.Enabled and nearby(player, prompt.Parent, prompt.MaxActivationDistance + 0.75) then action(player) end
	end)
	return prompt
end

local function activeSteps(bay)
	return if bay.lane.phase == "repair" then Repair.available(bay.repair) else {}
end

local function liftControl(bay)
	if bay.lane.driver ~= 0 then return nil end
	local step = Repair.liftControl(bay.repair)
	if step and step.motion == "raise" and not bay.onLift and World.liftOccupied(bay) then return nil end
	return step
end

local function hoodControl(bay)
	if bay.onLift and bay.lane.driver == 0 then return Repair.hoodControl(bay.repair) end
end

local function driveBlocker(bay)
	local repair = bay.repair
	if repair.moving and repair.motionStep then return repair.motionStep.target end
	if repair.raised then return "Lever" end
	if repair.hoodOpen then return "Hood" end
end

local function canChooseRepair(bay, order)
	return bay.lane.phase == "repair" and order ~= nil and bay.lane.repairIndex < #order.jobs
end

local function disposalStep(bay, target, item)
	for _, step in activeSteps(bay) do
		if step.target == target and step.cargo and (not item or step.cargo == item) and bay.repair.carried[step.cargo] then
			return step
		end
	end
end

local function focus(player, bay)
	player:SetAttribute("GarageFocusBay", bay.id)
end

local function supplyBay(player, key)
	local chosen
	for _, bay in world.bays do
		local repair = bay.repair
		if not repair.placements[key] and Repair.source(repair, key) == Repair.cargo[key].target then
			if player and player:GetAttribute("GarageFocusBay") == bay.id then return bay end
			chosen = chosen or bay
		end
	end
	return chosen
end

local function cargoOwner(bay, key)
	local repair = bay.repair
	if repair.carried[key] then return repair.carried[key] end
	for _, other in world.bays do
		local owner = Repair.stockFrom(repair, other.repair, key)
		if owner then return owner end
	end
end

local function sharedSlotOccupied(key)
	if not world.depositSlots[key] and key ~= "Bench" and key ~= "WheelStand" then return false end
	for _, drop in world.toolDrops do if drop.location == key then return true end end
	for _, bay in world.bays do
		for _, location in bay.repair.placements do if location == key then return true end end
	end
	return false
end

local names = {
	FrontLeft = "Roue avant gauche", FrontRight = "Roue avant droite", BackLeft = "Roue arrière gauche", BackRight = "Roue arrière droite",
	WheelStand = "Support de roue", Hood = "Capot", OilCap = "Moteur", Drain = "Sous le moteur", WasteOil = "Récupérateur d’huile",
	Recycling = "Recyclage", TireBin = "Pneus usés", Scrap = "Récupération des métaux",
	BatteryTray = "Compartiment moteur", DiagnosticPort = "Compartiment moteur", Belt = "Compartiment moteur",
	Radiator = "Radiateur", Door = "Porte conducteur", FrontLamp = "Bloc optique avant", RearLamp = "Bloc optique arrière",
	Quote = "Client", Wipers = "Pare-brise", Window = "Porte passager", Exhaust = "Échappement",
	DamperLeft = "Suspension gauche", DamperRight = "Suspension droite", Bench = "Établi",
}

local keys = { Enum.KeyCode.E, Enum.KeyCode.G, Enum.KeyCode.T, Enum.KeyCode.V }
local buttons = { Enum.KeyCode.ButtonX, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.DPadUp }

local function configureWork(bay, steps, guide)
	local current = {}
	local usedKeys = {}
	local first = if guide then table.find(steps, guide) else nil
	if first and first > 1 then
		table.remove(steps, first)
		table.insert(steps, 1, guide)
	end
	for _, step in steps do
		if step.motion or Repair.disposal[step.target] then continue end
		local promptsForStep = bay.workPrompts[step]
		if not promptsForStep then
			local anchor = bay.targets[step.target]
			local hold = Service.hold(state, step.hold, step.rate, anchor:IsDescendantOf(bay.vehicle))
			local prompt = createPrompt("WorkStep", step.title, names[step.target] or "Pont 0" .. bay.id, anchor, hold,
				function(player) finishStep(bay, player, step, false) end)
			prompt:SetAttribute("Mechanical", not step.quote)
			prompt:SetAttribute("WorkAction", step.action)
			prompt:SetAttribute("WorkTarget", step.target)
			promptsForStep = { work = prompt }
			if step.quote then
				promptsForStep.decline = createPrompt("DeclineQuote", "Reporter l’intervention", "Client", anchor, 0.40,
					function(player) finishStep(bay, player, step, true) end, Enum.KeyCode.R)
			end
		end
		local enabled = not bay.repair.moving and (not step.tool or owners[step.tool] ~= nil)
			and (not step.cargo or cargoOwner(bay, step.cargo) ~= nil) and not sharedSlotOccupied(step.storeAt)
		if enabled then
			local index = (usedKeys[step.target] or 0) + 1
			usedKeys[step.target] = index
			promptsForStep.work.KeyboardKeyCode = keys[index]
			promptsForStep.work.GamepadKeyCode = buttons[index]
		end
		promptsForStep.work.Enabled = enabled
		if promptsForStep.decline then promptsForStep.decline.Enabled = enabled end
		current[step] = promptsForStep
	end
	for step, stale in bay.workPrompts do
		if not current[step] then
			stale.work:Destroy()
			if stale.decline then stale.decline:Destroy() end
		end
	end
	bay.workPrompts = current
end

local function refreshControl(prompt, step)
	prompt.Enabled = workshopReady == true and step ~= nil
	if step then
		prompt.ActionText = step.title
		prompt.HoldDuration = Service.hold(state, step.hold, step.rate, step.target == "Hood")
		prompt:SetAttribute("WorkAction", step.action)
	end
end

local function updatePatience(bay)
	local order = Service.current(state, bay.lane)
	local fraction = if order then order.patience / order.patienceMax else 0
	local late = order ~= nil and order.late
	bay.info:SetAttribute("PatienceSeconds", if order then math.ceil(order.patience) else 0)
	bay.info:SetAttribute("Patience", math.round(fraction * 100))
	bay.info:SetAttribute("CustomerLate", late)
	bay.info:SetAttribute("SnackPause", order ~= nil and workspace:GetServerTimeNow() < order.snackUntil)
	World.updatePatience(bay, fraction, late)
end

local function snackAvailable(bay, now)
	local order, phase = Service.current(state, bay.lane), bay.lane.phase
	return order ~= nil and (phase == "intake" or phase == "repair" or phase == "outbound")
		and Service.owns(state, "vending") and order.snacks < 4 and now >= order.snackUntil
end

local function updateCartLoading()
	local cart = world.cart
	prompts.loadCart.Enabled = cart.owner ~= nil and cart.stock < #cart.tires
		and (world.targets.Cart.WorldPosition - world.targets.TireRack.WorldPosition).Magnitude < 9
end

local function refreshBay(bay)
	local lane, info, repair, p = bay.lane, bay.info, bay.repair, bay.prompts
	local phase = lane.phase
	local order, steps = Service.current(state, lane), activeSteps(bay)
	local step = if phase == "repair" then Repair.current(repair) else nil
	local job = if step then step.job or repair.job else nil
	World.apply(bay, lane, repair)
	p.receive.Enabled = phase == "reception"
	p.receive.HoldDuration = Service.hold(state, 0.48, "reception", false)
	p.receive.ObjectText = if order then order.name .. " · Baie 0" .. bay.id else "Accueil"
	local blocker = driveBlocker(bay)
	p.drive.Enabled = (phase == "intake" or phase == "outbound") and lane.driver == 0 and blocker == nil
	refreshControl(p.lift, liftControl(bay))
	refreshControl(p.hood, hoodControl(bay))
	p.pay.Enabled = phase == "payment"
	p.pay.ActionText = if order then "Encaisser " .. Service.invoice(state, order) .. " $" else "Encaisser"
	p.pay.ObjectText = if order then order.name .. " · Baie 0" .. bay.id else "Caisse"
	p.snack.Enabled = snackAvailable(bay, workspace:GetServerTimeNow())
	p.choose.Enabled = canChooseRepair(bay, order)
	for key, prompt in p.cargo do
		local placement = bay.placed[key]
		local anchor = if placement and Repair.source(repair, key) then placement.anchor else nil
		if prompt.Parent ~= anchor then prompt.Parent = anchor end
		prompt.Enabled = anchor ~= nil
	end
	configureWork(bay, steps, step)
	if lane.driver == 0 then
		World.markParking(bay, phase, false)
		info:SetAttribute("ParkingReady", false)
		info:SetAttribute("ParkingHint", "")
	end
	info:SetAttribute("Ticket", lane.ticket)
	info:SetAttribute("Customer", if order then order.name else "")
	info:SetAttribute("OrderEstimate", if order then order.estimate else 0)
	info:SetAttribute("Invoice", if order then Service.invoice(state, order) else 0)
	local label = {}
	if order then for _, key in order.jobs do table.insert(label, Repair.jobs[key].name) end end
	local pending = if order then table.concat(order.jobs, ",", lane.repairIndex) else ""
	info:SetAttribute("OrderJobs", table.concat(label, " · "))
	info:SetAttribute("PendingJobs", pending)
	info:SetAttribute("CanChooseRepair", p.choose.Enabled)
	info:SetAttribute("Job", job)
	info:SetAttribute("JobNumber", if order and job then table.find(order.jobs, job) or lane.repairIndex else 0)
	info:SetAttribute("JobCount", if order then #order.jobs else 0)
	local done, count = 0, 0
	if job then done, count = Repair.jobProgress(repair, job) end
	info:SetAttribute("Step", if count > 0 then math.min(done + 1, count) else 0)
	info:SetAttribute("Steps", count)
	info:SetAttribute("AvailableActions", #steps)
	info:SetAttribute("Action", step and step.action)
	info:SetAttribute("ActionTitle", step and step.title)
	info:SetAttribute("Target", step and step.target)
	info:SetAttribute("NeedsTool", step and step.tool)
	info:SetAttribute("ToolDropped", step ~= nil and step.tool ~= nil and world.toolDrops[step.tool] ~= nil)
	info:SetAttribute("NeedsEmptyHands", step ~= nil and Repair.needsEmptyHands(step))
	info:SetAttribute("NeedsCargo", step and step.cargo)
	info:SetAttribute("CargoOwner", if step and step.cargo then cargoOwner(bay, step.cargo) else nil)
	local source = if step and step.cargo then Repair.source(repair, step.cargo) else nil
	info:SetAttribute("CargoSource", if world.depositSlots[source] then "Counter" else source)
	info:SetAttribute("Motion", step and step.motion)
	info:SetAttribute("Moving", repair.moving)
	info:SetAttribute("DriveBlocked", blocker)
	info:SetAttribute("Pressure", repair.pressure)
	info:SetAttribute("StatusNote", if repair.note ~= "" then repair.note else bay.completedNote)
	info:SetAttribute("Driver", lane.driver)
	info:SetAttribute("Phase", phase)
	updatePatience(bay)

	if phase == "reception" then return bay.targets.Reception end
	if phase == "payment" then return bay.targets.Checkout end
	if phase == "intake" or phase == "outbound" then
		if blocker then return bay.targets[blocker] end
		return if lane.driver == 0 then bay.targets.Door elseif phase == "intake" then bay.targets.Dock else bay.targets.Parking
	end
	if step and not repair.moving then
		if step.cargo and not cargoOwner(bay, step.cargo) then
			local placement = bay.placed[step.cargo]
			if placement then return placement.anchor end
			local stock = Repair.source(repair, step.cargo)
			if stock then return bay.targets[stock] end
		end
		if step.tool and not owners[step.tool] then
			local drop = world.toolDrops[step.tool]
			return if drop then drop.anchor else bay.targets[Repair.tools[step.tool].target]
		end
		return bay.targets[step.target]
	end
end

refresh = function()
	local phase = state.phase
	local nextDay = state.day < Service.lastDay
	prompts.open.Enabled = workshopReady == true and (phase == "free" or (phase == "vendor" and nextDay))
	prompts.open.ActionText = if phase == "vendor" then "Ouvrir la prochaine journée" else "Ouvrir le service"
	prompts.map.Enabled = workshopReady == true and (phase == "free" or phase == "vendor" or phase == "complete")
	prompts.finish.Enabled = phase == "vendor" and not nextDay
	prompts.book.Enabled = phase == "service" and not state.extraBooked and #state.orders < Service.maxAppointments
	prompts.vendor.Enabled = phase == "vendor"

	local cart = world.cart
	prompts.cart.Enabled = phase == "service" or cart.owner ~= nil
	prompts.cart.ActionText = if cart.owner then "Poser le chariot" else "Pousser le chariot"
	prompts.cart.ObjectText = string.format("Chariot · %d/4 roues", cart.stock)
	updateCartLoading()
	prompts.unloadCart.Enabled = cart.stock > 0 and supplyBay(nil, "newTire") ~= nil
	local carrying = next(owners) ~= nil
	for _, bay in world.bays do if next(bay.repair.carried) ~= nil then carrying = true break end end
	Props.apply(world, state)
	for key, prompt in prompts.deposits do
		prompt.Enabled = carrying and prompt:IsDescendantOf(workspace) and not sharedSlotOccupied(key)
	end

	for key, spec in Repair.tools do
		local drop = world.toolDrops[key]
		local take = prompts.tools[key]
		take.Parent = if drop then drop.anchor else world.targets[spec.target]
		take.ActionText = if drop then "Ramasser" else "Prendre"
		local onFloor = drop and not world.depositSlots[drop.location]
		take.KeyboardKeyCode = if onFloor then Enum.KeyCode.F else Enum.KeyCode.E
		take.GamepadKeyCode = if onFloor then Enum.KeyCode.ButtonY else Enum.KeyCode.ButtonX
		take.Enabled = owners[key] == nil
		prompts.returns[key].Enabled = owners[key] ~= nil
		session:SetAttribute("Tool_" .. key, owners[key])
	end
	Gear.syncStocks(world, owners)
	local objective
	for _, bay in world.bays do
		local target = refreshBay(bay)
		objective = objective or target
	end
	for target, prompt in prompts.disposal do
		prompt.Enabled = false
		for _, bay in world.bays do
			if disposalStep(bay, target) then
				prompt.Enabled = true
				break
			end
		end
	end
	for key, prompt in prompts.supplies do prompt.Enabled = supplyBay(nil, key) ~= nil end
	for id, prompt in prompts.furniture do
		local item = world.furniture[id]
		prompt.Enabled = phase == "vendor" and item.model:IsDescendantOf(workspace) and not item.holder
	end
	for _, player in Players:GetPlayers() do updateEquipment(player) end

	if phase == "free" then objective = world.targets.Phone end
	if phase == "vendor" then objective = if nextDay then world.targets.Vendor else world.targets.Phone end
	World.setObjective(world, if workshopReady then objective else nil)
	World.updateBoard(world, state)

	session:SetAttribute("Day", state.day)
	session:SetAttribute("Cash", state.cash)
	session:SetAttribute("DailyCash", state.dailyCash)
	session:SetAttribute("LastInvoice", state.lastInvoice)
	session:SetAttribute("Served", state.served)
	session:SetAttribute("Appointments", #state.orders)
	session:SetAttribute("Rating", state.rating)
	session:SetAttribute("TotalEarned", state.totalEarned)
	local total, days = 0, 0
	for _, rating in state.grades do total += rating days += 1 end
	session:SetAttribute("AverageRating", if days > 0 then total / (2 * days) else 0)
	session:SetAttribute("CartOwner", cart.owner and cart.owner.UserId)
	session:SetAttribute("CartStock", cart.stock)
	for i = 1, 3 do session:SetAttribute("Offer" .. i, state.offers[i]) end
	for id in Service.offers do session:SetAttribute("Bought_" .. id, Service.owns(state, id)) end
	session:SetAttribute("Rerolled", state.rerolled)
	session:SetAttribute("Phase", phase)
end

local function makeRepair(bay)
	local order = Service.current(state, bay.lane)
	table.clear(bay.drops)
	table.clear(bay.pieceMotion)
	local faults = {}
	for _, job in order.jobs do
		faults[job] = {
			wheel = Repair.wheels[random:NextInteger(1, #Repair.wheels)],
			rightDamper = random:NextNumber() < 0.5, rearLamp = random:NextNumber() < 0.5,
			crackedShield = random:NextNumber() < 0.5, badPuncture = random:NextNumber() < 0.45,
			windowModule = random:NextNumber() < 0.55, highPressure = random:NextNumber() < 0.48,
			weakBattery = job == "inspection" and #order.jobs < 4 and not table.find(order.jobs, "battery") and random:NextNumber() < 0.44,
			oilRecovery = Service.owns(state, "oil_recovery"),
		}
	end
	local raised = bay.repair.raised
	bay.repair = Repair.forOrder(order.jobs, faults, owners)
	bay.repair.raised = raised
end

local function openMarket()
	refresh()
	World.moveVendor(world, true)
	if Service.openMarket(state) then saves:checkpoint() end
	refresh()
end

advance = function()
	for _, bay in world.bays do
		if not bay.repair.moving and Service.dispatch(state, lanes, bay.lane) then
			local order = Service.current(state, bay.lane)
			bay.completedNote = ""
			makeRepair(bay)
			World.selectVehicle(bay, order.vehicle)
			task.spawn(function()
				World.arrive(bay, order)
				Service.arrived(bay.lane)
				refresh()
			end)
		end
	end
	if Service.closeShift(state, lanes) then task.spawn(openMarket) end
	refresh()
end

finishStep = function(bay, player, step, declined)
	local repair, lane = bay.repair, bay.lane
	local root = activeRoot(player)
	if not root or sharedSlotOccupied(step.storeAt) then return end
	if step.target == "Lever" then
		if step ~= liftControl(bay) then return end
	elseif step.target == "Hood" then
		if step ~= hoodControl(bay) then return end
	elseif lane.phase ~= "repair" then return end
	local kind, _, cargoBay = held(player)
	if kind == "cart" or kind == "furniture" or (cargoBay and cargoBay ~= bay and Repair.needsEmptyHands(step)) then return end
	local done = if declined then Repair.decline(repair, step) else Repair.act(repair, player.UserId, step, cargoBay and cargoBay.repair)
	if not done then return end
	if step.job then repair.job = step.job end
	focus(player, bay)
	if step.motion then
		refresh()
		World.animate(bay, step.motion, Service.liftTime(state))
		Repair.finishMotion(repair)
		if lane.phase == "idle" and state.phase == "service" then advance() return end
	elseif not declined then
		if step.leaveAt == "Workpiece" then
			local point = bay.targets[step.target].WorldPosition
			local direction = (root.Position - point) * Vector3.new(1, 0, 1)
			local offset = if direction.Magnitude > 0.1 then direction.Unit * 1.15 else Vector3.xAxis
			local height = math.clamp(bay.gearTemplates[Repair.assetKey(step.output)]:GetExtentsSize().Y / 2, 0.14, 0.75)
			bay.drops[step.output] = CFrame.new(Vector3.new(point.X, height + 0.08, point.Z) + offset)
			bay.pieceMotion[step.output] = CFrame.new(point + offset * 0.5)
		end
		if step.storeAt and step.cargo then
			bay.pieceMotion[step.cargo] = bay.targets[step.target].WorldCFrame + Vector3.yAxis * 0.28
		end
		World.effect(bay, step, root)
		if not step.quote then repairFeedback:FireClient(player, step.action) end
	end
	local order = Service.current(state, lane)
	if step.job then
		local completed, count = Repair.jobProgress(repair, step.job)
		if completed == count and Service.selectRepair(state, step.job, lane) then
			local declinedWindow = declined and step.quote == "window"
			local addBattery = step.job == "inspection" and repair.addBattery
			local surcharge = if step.job == "window" then repair.surcharge else 0
			Service.finishRepair(state, step.job, not declinedWindow, declinedWindow, surcharge, addBattery, lane, true)
			if addBattery then Repair.addJob(repair, "battery") end
			repair.job = order.jobs[lane.repairIndex] or step.job
			saves:checkpoint()
		end
	end
	if not repair.raised and not repair.hoodOpen and Service.prepareReturn(state, lane) then
		World.recordRepair(bay, repair)
		bay.completedNote = repair.note
		table.clear(repair.carried)
		table.clear(repair.placements)
		saves:checkpoint()
	end
	refresh()
end

local function stopArrangement(player)
	local selection = layoutsHeld[player]
	if not selection then return false end
	selection.item.holder = nil
	layoutsHeld[player] = nil
	if player.Parent == Players then furnitureControl:FireClient(player, "end") end
	return true
end

local function mountBay(bay)
	bay.lane, bay.repair, bay.completedNote = Service.newLane(), Repair.forOrder({}, {}, owners), ""
	bay.onLift = false
	bay.workPrompts = {}
	table.insert(lanes, bay.lane)
	bay.drive = Drive.new(bay)
	local info = Instance.new("Folder")
	info.Name = tostring(bay.id)
	info:SetAttribute("Dock", bay.dockPose.Position)
	info.Parent = bayFolder
	bay.info = info
	local car = Instance.new("ObjectValue")
	car.Name = "Vehicle"
	car.Value = bay.vehicle
	car.Parent = info
	local lane = bay.lane
	local p = { cargo = {} }
	bay.prompts = p
	for _, control in {
		{ key = "lift", target = "Lever", name = "Pont 0" .. bay.id, step = liftControl, hold = 0 },
		{ key = "hood", target = "Hood", name = "Capot", step = hoodControl, hold = 0.25 },
	} do
		local prompt = createPrompt("WorkStep", "", control.name, bay.targets[control.target], control.hold, function(player)
			local step = control.step(bay)
			if step then finishStep(bay, player, step, false) end
		end)
		prompt:SetAttribute("Mechanical", true)
		prompt:SetAttribute("WorkTarget", control.target)
		p[control.key] = prompt
	end
	p.receive = createPrompt("Receive", "Accueillir le client", "Accueil", bay.targets.Reception, 0.48, function(player)
		if not Service.receive(lane) then return end
		focus(player, bay)
		refresh()
		World.waitCustomer(bay)
	end)
	p.drive = createPrompt("Drive", "Prendre le volant", "Véhicule · Baie 0" .. bay.id, bay.targets.Door, 0, function(player)
		if held(player) or driveBlocker(bay) or not Service.beginDrive(lane, player.UserId) then return end
		if not bay.drive:enter(player) then lane.driver = 0
		else
			bay.onLift = false
			player:SetAttribute("GarageDriverBay", bay.id)
			focus(player, bay)
		end
		refresh()
	end)
	p.pay = createPrompt("Pay", "Encaisser", "Caisse", bay.targets.Checkout, 0.55, function(player)
		if not Service.pay(state, lane) then return end
		focus(player, bay)
		saves:checkpoint()
		refresh()
		World.depart(bay)
		Service.clearLane(lane)
		advance()
	end)
	p.snack = createPrompt("Snack", "Offrir une collation", "Baie 0" .. bay.id, bay.targets.Snack, 0.3, function(player)
		if Service.snack(state, workspace:GetServerTimeNow(), lane) then focus(player, bay) saves:checkpoint() refresh() end
	end)
	p.choose = createPrompt("ChooseRepair", "Changer le suivi", "Bon de travail · Baie 0" .. bay.id, bay.targets.Door, 0.18, function(player)
		if canChooseRepair(bay, Service.current(state, lane)) then
			focus(player, bay)
			repairControl:FireClient(player, bay.id)
		end
	end, Enum.KeyCode.F)
	for key, spec in Repair.cargo do
		p.cargo[key] = createPrompt("Recover_" .. key, "Ramasser", spec.name, nil, 0.15, function(player)
			if not held(player) and Repair.take(bay.repair, player.UserId, key) then focus(player, bay) refresh() end
		end)
		p.cargo[key]:SetAttribute("Mechanical", true)
	end
end

local function placePlayer(player, spawn)
	player.RespawnLocation = spawn
	player:SetAttribute("GarageFocusBay", nil)
	if player.Character then player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0)) end
end

local function openLauncher(player)
	if player ~= workshopOwner or next(layoutsHeld) or world.cart.owner or next(owners) then return end
	for _, bay in world.bays do
		if bay.repair.moving or next(bay.repair.carried) then return end
	end
	saves:checkpoint()
	saves:showCampaigns()
	workshopReady = false
	session:SetAttribute("LaunchReturn", true)
	session:SetAttribute("LaunchMode", "menu")
	refresh()
end

local function mountPrompts()
	prompts = { tools = {}, returns = {}, supplies = {}, furniture = {}, disposal = {}, deposits = {} }
	prompts.open = createPrompt("OpenDay", "Ouvrir le service", "Téléphone", world.targets.Phone, 0.45, function()
		if next(layoutsHeld) then return end
		local night = state.phase == "vendor"
		if not Service.open(state) then return end
		state.phase = "service"
		saves:checkpoint()
		if night then task.spawn(World.moveVendor, world, false) end
		advance()
	end)
	prompts.map = createPrompt("SelectCampaign", "Choisir une partie", "Téléphone", world.targets.Phone, 0.42,
		openLauncher, Enum.KeyCode.F)
	prompts.finish = createPrompt("FinishCampaign", "Voir le bilan des 10 jours", "Téléphone", world.targets.Phone, 0.65, function()
		if not next(layoutsHeld) and Service.finishCampaign(state) then saves:checkpoint() refresh() end
	end)
	prompts.book = createPrompt("Book", "Ajouter un rendez-vous", "Téléphone", world.targets.Phone, 0.40, function()
		if Service.book(state) then saves:checkpoint() advance() end
	end)
	prompts.vendor = createPrompt("Vendor", "Voir les offres", "La Caravane", world.targets.Vendor, 0, function(player)
		if state.phase == "vendor" and not layoutsHeld[player] then vendorControl:FireClient(player, "open") end
	end)
	for _, entry in {
		{ "WasteOil", "Vider le bac d’huile usée", "Fût HUILE USÉE", 0.8, "recycle_usedOil" },
		{ "Recycling", "Déposer au recyclage", "RECYCLAGE", 0.45, "recycle" },
		{ "Scrap", "Déposer la pièce usée", "MÉTAUX", 0.45, "recycle" },
		{ "TireBin", "Recycler la roue", "PNEUS USÉS", 0.45, "recycle_usedTire" },
	} do
		local target, title, object, hold, workAction = table.unpack(entry)
		local prompt = createPrompt("WorkStep", title, object, world.targets[target], hold, function(player)
			local kind, item, bay = held(player)
			if kind ~= "cargo" then return end
			local step = disposalStep(bay, target, item)
			if step then finishStep(bay, player, step, false) end
		end)
		prompt:SetAttribute("Mechanical", true)
		prompt:SetAttribute("WorkAction", workAction)
		prompt:SetAttribute("WorkTarget", target)
		prompts.disposal[target] = prompt
	end

	for key, spec in Repair.tools do
		local anchor = world.targets[spec.target]
		prompts.tools[key] = createPrompt("TakeTool_" .. key, "Prendre", spec.name, anchor, 0.12, function(player)
			if held(player) or owners[key] then return end
			owners[key] = player.UserId
			Gear.clearTool(world, key, prompts.tools[key])
			refresh()
		end)
		prompts.tools[key]:SetAttribute("Mechanical", true)
		prompts.returns[key] = createPrompt("ReturnTool_" .. key, "Ranger", spec.name, anchor, 0.22, function(player)
			if owners[key] ~= player.UserId then return end
			owners[key] = nil
			World.sound(anchor, "drop")
			refresh()
		end, Enum.KeyCode.F)
	end
	for key, spec in Repair.cargo do
		if spec.target then
			prompts.supplies[key] = createPrompt("Stock_" .. key, "Prendre", spec.name, world.targets[spec.target], 0.15, function(player)
				local bay = not held(player) and supplyBay(player, key)
				if bay and Repair.take(bay.repair, player.UserId, key) then focus(player, bay) refresh() end
			end)
			prompts.supplies[key]:SetAttribute("Mechanical", true)
		end
	end
	for key, anchor in world.depositSlots do
		local counter = anchor.Parent.Parent
		prompts.deposits[key] = createPrompt("Store_" .. key, "Poser l’objet", counter.Name, anchor, 0.18, function(player)
			local kind, item, bay = held(player)
			if sharedSlotOccupied(key) then return end
			if kind == "cargo" then
				bay.pieceMotion[item] = anchor.WorldCFrame + Vector3.yAxis * 0.32
				Repair.drop(bay.repair, player.UserId, key)
			elseif kind == "tool" then
				Gear.dropTool(world, item, nil, anchor.WorldCFrame + Vector3.yAxis * 0.32, key)
				owners[item] = nil
			else return end
			World.sound(anchor, "drop")
			refresh()
		end)
		prompts.deposits[key]:SetAttribute("Mechanical", true)
	end
	prompts.cart = createPrompt("Cart", "Pousser le chariot", "Chariot", world.targets.Cart, 0, function(player)
		if (not held(player) or world.cart.owner == player) and Props.pullCart(world, player, state) then refresh() end
	end)
	prompts.loadCart = createPrompt("LoadCart", "Charger une roue", "Chariot", world.targets.TireRack, 0.30, function(player)
		if world.cart.owner ~= player or not prompts.loadCart.Enabled then return end
		Props.stockCart(world, 1)
		refresh()
	end, Enum.KeyCode.F)
	prompts.unloadCart = createPrompt("UnloadCart", "Prendre une roue du chariot", "Chariot", world.targets.Cart, 0.22, function(player)
		local bay = not held(player) and supplyBay(player, "newTire")
		if bay and world.cart.stock > 0 and Repair.take(bay.repair, player.UserId, "newTire") then
			Props.stockCart(world, -1)
			focus(player, bay)
			refresh()
		end
	end, Enum.KeyCode.F)

	for id, item in world.furniture do
		prompts.furniture[id] = createPrompt("Arrange_" .. id, "Déplacer ou pivoter", item.model.Name, item.anchor, 0.24, function(player)
			if state.phase ~= "vendor" or item.holder or held(player) then return end
			item.holder = player
			layoutsHeld[player] = { id = id, item = item }
			furnitureControl:FireClient(player, "begin", item.model, item.size, item.home, item.turn or 0, world.layout.at(0, 0), world.layout.scale)
			refresh()
		end, Enum.KeyCode.F)
	end
end

mount = function()
	if world then
		for _, bay in world.bays do
			for _, temporary in bay.prompts.cargo do temporary:Destroy() end
		end
		World.destroy(world)
		bayFolder:ClearAllChildren()
		world = nil
	end
	world, lanes = World.build(state.map), {}
	Props.apply(world, state)
	Furniture.restore(world, state.furniture[state.map])
	for _, bay in world.bays do mountBay(bay) end
	mountPrompts()
	session:SetAttribute("Map", state.map)
	session:SetAttribute("MapName", world.layout.name)
	session:SetAttribute("BayCount", #world.bays)
	for i, player in Players:GetPlayers() do
		placePlayer(player, world.spawns[(i - 1) % #world.spawns + 1])
	end
	if state.phase == "vendor" then World.restoreVendor(world)
	elseif state.phase == "complete" then World.setEvening(world, true) end
	refresh()
end

local function groundDrop(player, key)
	local root = activeRoot(player)
	if not root then return end
	local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if forward.Magnitude < 0.1 then return end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { player.Character }
	parameters.RespectCanCollide = true
	local direction = forward.Unit
	local obstruction = workspace:Raycast(root.Position, direction * 2.35, parameters)
	local reach = if obstruction then math.max(0, obstruction.Distance - 0.65) else 2.35
	local tool = world.gearTemplates[Repair.assetKey(key)]
	local height = if Repair.isWheel(key) then 0.41 else math.clamp(tool:GetExtentsSize().Y / 2, 0.13, 0.82)
	local rotation = CFrame.lookAlong(Vector3.zero, direction).Rotation
	for _, scale in { 1, 0.62, 0.25, 0 } do
		local point = root.Position + direction * (reach * scale)
		local surface = workspace:Raycast(point + Vector3.yAxis * 0.4, -Vector3.yAxis * 7, parameters)
		if surface and surface.Position.Y >= -0.5 and surface.Position.Y <= 0.45 then
			local landing = CFrame.new(surface.Position + Vector3.yAxis * height) * rotation
			return landing, CFrame.new(point - Vector3.yAxis * 0.85) * rotation
		end
	end
end

carryControl.OnServerEvent:Connect(function(player)
	if not workshopReady then return end
	local kind, key, bay = held(player)
	if kind == "furniture" then
		stopArrangement(player)
	elseif kind == "cart" then
		Props.parkCart(world)
	elseif kind == "cargo" or kind == "tool" then
		local pose, start = groundDrop(player, key)
		if not pose then return end
		if kind == "cargo" then
			bay.drops[key], bay.pieceMotion[key] = pose, start
			Repair.drop(bay.repair, player.UserId, "Ground")
		else
			owners[key] = nil
			Gear.dropTool(world, key, pose, start)
		end
		repairFeedback:FireClient(player, "drop")
	else return end
	refresh()
	local drop = if kind == "cargo" then bay.placed[key] elseif kind == "tool" then world.toolDrops[key] else nil
	if drop then World.sound(drop.anchor, "drop") end
end)

furnitureControl.OnServerEvent:Connect(function(player, action, x, z, turn)
	local selection = layoutsHeld[player]
	local root = activeRoot(player)
	if not selection or not root or state.phase ~= "vendor" or action ~= "place" then return end
	local placement = Furniture.place(world, selection.item, root, x, z, turn)
	if not placement then furnitureControl:FireClient(player, "blocked") return end
	local layout = state.furniture[state.map] or {}
	state.furniture[state.map] = layout
	layout[selection.id] = placement
	stopArrangement(player)
	World.sound(selection.item.anchor, "drop")
	saves:checkpoint()
	refresh()
end)

vendorControl.OnServerEvent:Connect(function(player, action, id)
	if state.phase ~= "vendor" or not nearby(player, world.targets.Vendor, 7.15) then return end
	local bought, message
	if action == "buy" and type(id) == "string" then
		bought, message = Service.buy(state, id)
	elseif action == "reroll" then
		bought, message = Service.reroll(state)
	else return end
	if bought then saves:checkpoint() refresh() end
	vendorControl:FireClient(player, "result", bought, message)
end)

optionsControl.OnServerEvent:Connect(function(player, sensitivity)
	saves:changeSensitivity(player, sensitivity)
end)

repairControl.OnServerEvent:Connect(function(player, bayId, job)
	if not workshopReady or typeof(bayId) ~= "number" or typeof(job) ~= "string" then return end
	local bay = world.bays[bayId]
	local order = bay and Service.current(state, bay.lane)
	if not bay or not canChooseRepair(bay, order) or not nearby(player, bay.targets.Door, 7.15) then return end
	local position = table.find(order.jobs, job)
	if position and position >= bay.lane.repairIndex then
		bay.repair.job = job
		focus(player, bay)
		refresh()
	end
end)

local function drivingGoal(bay)
	return if bay.lane.phase == "intake" then bay.dockPose else bay.parkingPose
end

driveControl.OnServerEvent:Connect(function(player, action, throttle, steer)
	if not workshopReady then return end
	local bay = world.bays[player:GetAttribute("GarageDriverBay")]
	if not bay or bay.lane.driver ~= player.UserId or not bay.drive.rider then return end
	local drive, lane = bay.drive, bay.lane
	if action == "input" then
		drive:setInput(throttle, steer)
	elseif action == "park" then
		local goal = drivingGoal(bay)
		local aligned = drive:aligned(goal)
		if not Service.park(lane, player.UserId, aligned) then return end
		bay.onLift = lane.phase == "repair"
		drive:leave(goal)
		player:SetAttribute("GarageDriverBay", nil)
		refresh()
		if lane.phase == "checkout" then
			World.checkoutCustomer(bay)
			Service.readyToPay(lane)
			refresh()
		end
	elseif action == "exit" and math.abs(drive.speed) < 2.2 then
		local docked = lane.phase == "outbound" and drive:aligned(bay.dockPose)
		if docked then bay.onLift = true end
		drive:leave(if docked then bay.dockPose else nil)
		lane.driver = 0
		player:SetAttribute("GarageDriverBay", nil)
		refresh()
	end
end)

local elapsed, doorElapsed, saveElapsed = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	if not workshopReady then return end
	for _, bay in world.bays do
		if bay.lane.driver ~= 0 then
			bay.drive:update(dt)
			local ready, hint = bay.drive:aligned(drivingGoal(bay))
			if bay.info:GetAttribute("ParkingReady") ~= ready then
				World.markParking(bay, bay.lane.phase, ready)
				bay.info:SetAttribute("ParkingReady", ready)
			end
			bay.info:SetAttribute("ParkingHint", hint)
		end
	end
	if not Props.moveCart(world, dt) then refresh() end
	doorElapsed += dt
	if doorElapsed >= 0.09 then
		World.updateDoors(world, Players:GetPlayers(), os.clock())
		doorElapsed = 0
	end
	elapsed += dt
	if elapsed < 0.27 then return end
	local changed = false
	local now = workspace:GetServerTimeNow()
	for _, bay in world.bays do
		if Service.passTime(state, elapsed, now, bay.lane) then changed = true end
		updatePatience(bay)
		bay.prompts.snack.Enabled = snackAvailable(bay, now)
	end
	session:SetAttribute("Rating", state.rating)
	saveElapsed += elapsed
	if changed or (state.phase == "service" and saveElapsed > 24) then
		saves:checkpoint()
		saveElapsed = 0
	end
	elapsed = 0
end)

local function release(player)
	if not world then return end
	stopArrangement(player)
	if world.cart.owner == player then Props.parkCart(world) end
	local key = toolHeld(player)
	if key then
		local pose, start = groundDrop(player, key)
		if pose then Gear.dropTool(world, key, pose, start) else Gear.recoverTool(world, key) end
		owners[key] = nil
	end
	for _, bay in world.bays do
		if bay.lane.driver == player.UserId then bay.drive:leave() end
		Service.release(bay.lane, player.UserId)
		Repair.release(bay.repair, player.UserId)
	end
	player:SetAttribute("GarageDriverBay", nil)
	refresh()
end

local loadRevision = 0
local function inspectCampaigns(player)
	loadRevision += 1
	local revision = loadRevision
	workshopOwner = player
	session:SetAttribute("LaunchOwnerId", player and player.UserId)
	session:SetAttribute("SaveOwner", player and player.DisplayName)
	session:SetAttribute("LaunchStatus", "loading")
	if not player then return end
	task.spawn(function()
		local slot, campaigns = saves:loadCampaigns(player)
		if revision ~= loadRevision or player.Parent ~= Players then return end
		saves.workshop, saves.campaigns = slot, campaigns
		saves:showCampaigns()
	end)
end

local function enterWorkshop(selected)
	session:SetAttribute("LaunchMode", "starting")
	session:SetAttribute("LaunchReturn", nil)
	state = selected
	elapsed, doorElapsed, saveElapsed = 0, 0, 0
	mount()
	workshopReady = true
	for _, player in Players:GetPlayers() do
		if not player.Character then
			task.spawn(function()
				if player.Parent == Players and not player.Character then player:LoadCharacterAsync() end
			end)
		end
	end
	Players.CharacterAutoLoads = true
	if state.phase == "arrival" then
		state.phase = "service"
		advance()
	elseif state.phase == "closing" then
		task.spawn(openMarket)
	else
		refresh()
	end
	session:SetAttribute("LaunchMode", "playing")
end

launchControl.OnServerEvent:Connect(function(player, action, map, confirmed)
	if player ~= workshopOwner or session:GetAttribute("LaunchMode") ~= "menu" then return end
	if action == "back" and session:GetAttribute("LaunchReturn") then
		workshopReady = true
		session:SetAttribute("LaunchReturn", nil)
		refresh()
		session:SetAttribute("LaunchMode", "playing")
	elseif action == "retry" and session:GetAttribute("LaunchStatus") ~= "loading" and session:GetAttribute("LaunchStatus") ~= "ready" then
		inspectCampaigns(player)
	elseif session:GetAttribute("LaunchStatus") ~= "loading" and typeof(action) == "string" and typeof(map) == "string" then
		local selected = saves:selectCampaign(map, action, confirmed == true)
		if selected then enterWorkshop(selected) end
	end
end)

local function watchPlayer(player)
	if not workshopOwner and not world and session:GetAttribute("LaunchMode") == "menu" then inspectCampaigns(player) end
	saves:watch(player)
	if world then
		placePlayer(player, world.spawns[(#Players:GetPlayers() - 1) % #world.spawns + 1])
	end
	player.CharacterRemoving:Connect(function() release(player) end)
end

session.Parent = ReplicatedStorage
saves:bindToClose()
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	release(player)
	equipment[player] = nil
	task.spawn(function() saves:leaving(player) end)
	local remaining
	for _, other in Players:GetPlayers() do
		if other ~= player then remaining = other break end
	end
	if player == workshopOwner and session:GetAttribute("LaunchMode") == "menu" then
		if world then
			workshopReady = true
			session:SetAttribute("LaunchReturn", nil)
			refresh()
			session:SetAttribute("LaunchMode", "playing")
		else
			inspectCampaigns(remaining)
		end
	end
	if remaining then return end
	if workshopReady then saves:checkpoint() end
	task.spawn(function() saves:drain(saves.activeSlot) end)
end)
for _, player in Players:GetPlayers() do watchPlayer(player) end
print("Garage Day · Menu prêt")

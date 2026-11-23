local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Repair = require(ReplicatedStorage.GarageDay.Repair)
local Service = require(ReplicatedStorage.GarageDay.Service)
local Drive = require(script.Parent.Drive)
local Gear = require(script.Parent.GearWorld)
local Props = require(script.Parent.GarageProps)
local World = require(script.Parent.WorkshopWorld)
local WorkshopSaves = require(script.Parent.WorkshopSaves)

local random = Random.new()
local state = Service.new(Repair.jobs, function(maximum) return random:NextInteger(1, maximum) end)
local repair = Repair.new("pressure")
local completedNote = ""
local world = World.build()
local drive = Drive.new(world)
local session = Instance.new("Folder")
session.Name = "GarageDaySession"
local saves = WorkshopSaves.new(state, session)
local workshopOwner, workshopReady = nil, false

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
local prompts, equipment = {}, {}
local workPrompt, declinePrompt, promptedStep
local finishStep

local function updateEquipment(player)
	local key = Repair.carrying(repair, player.UserId) or Repair.using(repair, player.UserId)
	local previous = equipment[player]
	if previous and key == previous.key and previous.tool.Parent == player.Character then return end
	if previous then previous.tool:Destroy() end
	equipment[player] = nil
	if not key then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid or humanoid.Health <= 0 then return end
	local tool = World.makeEquipment(world, key, (Repair.cargo[key] or Repair.tools[key]).name)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	equipment[player] = { key = key, tool = tool }
end

local function activeRoot(player)
	if state.driver == player.UserId then return nil end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and humanoid and humanoid.Health > 0 then root else nil
end

local function nearby(player, anchor, radius)
	local root = activeRoot(player)
	return root and anchor and anchor:IsDescendantOf(workspace) and (root.Position - anchor.WorldPosition).Magnitude <= radius
end

local function createPrompt(name, title, object, key, hold, action, alternate)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = title
	prompt.ObjectText = object or ""
	prompt.KeyboardKeyCode = alternate or Enum.KeyCode.E
	prompt.GamepadKeyCode = if alternate then Enum.KeyCode.ButtonY else Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 6.4
	prompt.RequiresLineOfSight = true
	prompt.ClickablePrompt = true
	prompt.HoldDuration = hold
	prompt.Enabled = false
	prompt.Parent = world.targets[key]
	prompt.Triggered:Connect(function(player)
		if prompt.Enabled and nearby(player, prompt.Parent, prompt.MaxActivationDistance + 0.75) then action(player) end
	end)
	return prompt
end

local function addPrompt(name, title, object, key, hold, action, alternate)
	local prompt = createPrompt(name, title, object, key, hold, action, alternate)
	prompts[name] = prompt
	return prompt
end

local names = {
	Lever = "Pont 01", FrontLeft = "Roue avant gauche", FrontRight = "Roue avant droite",
	BackLeft = "Roue arrière gauche", BackRight = "Roue arrière droite", WheelStand = "Support de roue",
	Hood = "Capot", OilCap = "Moteur", Drain = "Sous le moteur", WasteOil = "Récupérateur d’huile",
	Recycling = "Recyclage", TireBin = "Pneus usés", Scrap = "Récupération des métaux",
	BatteryTray = "Compartiment moteur", DiagnosticPort = "Compartiment moteur", Belt = "Compartiment moteur",
	Radiator = "Radiateur", Door = "Porte conducteur", FrontLamp = "Bloc optique avant", RearLamp = "Bloc optique arrière",
	Quote = "Client", Wipers = "Pare-brise", Window = "Porte passager", Exhaust = "Échappement",
	DamperLeft = "Suspension gauche", DamperRight = "Suspension droite", Bench = "Établi",
}

local function configureWork(step)
	if step ~= promptedStep then
		if workPrompt then workPrompt:Destroy() end
		if declinePrompt then declinePrompt:Destroy() end
		workPrompt, declinePrompt, promptedStep = nil, nil, step
		if step then
			local hold = Service.hold(state, step.hold, step.rate, world.targets[step.target]:IsDescendantOf(world.vehicle))
			workPrompt = createPrompt("WorkStep", step.title, names[step.target], step.target, hold,
				function(player) finishStep(player, step, false) end)
			workPrompt:SetAttribute("Mechanical", not step.quote)
			if step.quote then
				declinePrompt = createPrompt("DeclineQuote", "Reporter l’intervention", "Client", step.target, 0.40,
					function(player) finishStep(player, step, true) end, Enum.KeyCode.R)
			end
		end
	end
	if step then
		workPrompt.Enabled = not repair.moving and (not step.tool or repair.tools[step.tool] ~= nil)
			and (not step.cargo or repair.carried[step.cargo] ~= nil)
		if declinePrompt then declinePrompt.Enabled = workPrompt.Enabled end
	end
end

local serviceTargets = { free = "Phone", reception = "Reception", payment = "Checkout", vendor = "Vendor" }

local function updatePatience(order)
	session:SetAttribute("PatienceSeconds", if order then math.ceil(order.patience) else 0)
	session:SetAttribute("Rating", state.rating)
	session:SetAttribute("CustomerLate", order ~= nil and order.late)
end

local function updateCartLoading()
	local cart = world.cart
	prompts.loadCart.Enabled = cart.owner ~= nil and cart.stock < #cart.tires
		and (world.targets.Cart.WorldPosition - world.targets.TireRack.WorldPosition).Magnitude < 9
end

local function refresh()
	local phase = state.phase
	local order = Service.current(state)
	local step = if phase == "repair" then Repair.current(repair) else nil
	World.apply(world, state, repair)
	for _, player in Players:GetPlayers() do updateEquipment(player) end

	local focus = serviceTargets[phase]
	prompts.open.Enabled = workshopReady and (phase == "free" or phase == "vendor")
	prompts.open.ActionText = if phase == "vendor" then "Ouvrir la prochaine journée" else "Ouvrir le service"
	prompts.book.Enabled = not state.extraBooked and #state.orders < Service.maxAppointments
		and (phase == "reception" or phase == "intake" or phase == "repair")
	prompts.receive.Enabled = phase == "reception"
	prompts.receive.HoldDuration = Service.hold(state, 0.48, "reception", false)
	prompts.drive.Enabled = (phase == "intake" or phase == "outbound") and state.driver == 0
	prompts.pay.Enabled = phase == "payment"
	prompts.pay.ActionText = if order then "Encaisser " .. Service.invoice(state, order) .. " $" else "Encaisser"
	prompts.vendor.Enabled = phase == "vendor"
	prompts.snack.Enabled = Service.owns(state, "vending") and step ~= nil and order.snacks < 4
		and workspace:GetServerTimeNow() >= order.snackUntil
	local cart = world.cart
	prompts.cart.Enabled = true
	prompts.cart.ActionText = if cart.owner then "Poser le chariot" else "Pousser le chariot"
	prompts.cart.ObjectText = string.format("Chariot · %d/4 roues", cart.stock)
	updateCartLoading()
	prompts.unloadCart.Enabled = step ~= nil and cart.stock > 0 and Repair.source(repair, "newTire") == "TireRack"
	for _, key in { "Counter1", "Counter2" } do
		local occupied = false
		for _, location in repair.placements do if location == key then occupied = true break end end
		prompts["store" .. key].Enabled = step ~= nil and Service.owns(state, "counter")
			and next(repair.carried) ~= nil and not occupied
	end
	if phase == "intake" or phase == "outbound" then
		focus = if state.driver == 0 then "Door" elseif phase == "intake" then "Dock" else "Parking"
	end

	for key, spec in Repair.tools do
		prompts["takeTool_" .. key].Enabled = step ~= nil and Repair.canTakeTool(repair, key)
		prompts["returnTool_" .. key].Enabled = step ~= nil and repair.tools[key] ~= nil
		session:SetAttribute("Tool_" .. key, repair.tools[key])
	end
	for key in Repair.cargo do
		local source = if step then Repair.source(repair, key) else nil
		local placement = world.placed[key]
		local prompt = prompts["take_" .. key]
		local anchor = if source then (if placement then placement.anchor else world.targets[source]) else nil
		if prompt.Parent ~= anchor then prompt.Parent = anchor end
		prompt.Enabled = anchor ~= nil
		session:SetAttribute("Carry_" .. key, repair.carried[key])
	end
	configureWork(step)
	if step and not repair.moving then
		focus = step.target
		if step.cargo and not repair.carried[step.cargo] then
			local placement = world.placed[step.cargo]
			focus = if placement then placement.anchor else Repair.source(repair, step.cargo) or step.target
		end
		if step.tool and not repair.tools[step.tool] then focus = Repair.tools[step.tool].target end
	end
	World.setObjective(world, if workshopReady then focus else nil)
	World.updateBoard(world, state)
	if state.driver == 0 then
		World.markParking(world, phase, false)
		session:SetAttribute("ParkingReady", false)
		session:SetAttribute("ParkingHint", "")
	end

	session:SetAttribute("Day", state.day)
	session:SetAttribute("Cash", state.cash)
	session:SetAttribute("DailyCash", state.dailyCash)
	session:SetAttribute("LastInvoice", state.lastInvoice)
	session:SetAttribute("Served", state.served)
	session:SetAttribute("Appointments", #state.orders)
	session:SetAttribute("Ticket", state.ticket)
	session:SetAttribute("Customer", if order then order.name else "")
	session:SetAttribute("OrderEstimate", if order then order.estimate else 0)
	session:SetAttribute("Invoice", if order then Service.invoice(state, order) else 0)
	local label = {}
	if order then for _, key in order.jobs do table.insert(label, Repair.jobs[key].name) end end
	session:SetAttribute("OrderJobs", table.concat(label, " · "))
	session:SetAttribute("Job", if step then repair.job else nil)
	session:SetAttribute("JobNumber", state.repairIndex)
	session:SetAttribute("JobCount", if order then #order.jobs else 0)
	session:SetAttribute("Step", if step then repair.index else 0)
	session:SetAttribute("Steps", if step then #repair.steps else 0)
	session:SetAttribute("Action", step and step.action)
	session:SetAttribute("ActionTitle", step and step.title)
	session:SetAttribute("Target", step and step.target)
	session:SetAttribute("NeedsTool", step and step.tool)
	session:SetAttribute("NeedsEmptyHands", step ~= nil and Repair.needsEmptyHands(step))
	session:SetAttribute("NeedsCargo", step and step.cargo)
	session:SetAttribute("CargoSource", if step and step.cargo then Repair.source(repair, step.cargo) else nil)
	session:SetAttribute("Quote", step and step.quote)
	session:SetAttribute("Motion", step and step.motion)
	session:SetAttribute("Moving", repair.moving)
	session:SetAttribute("HoodOpen", repair.hoodOpen)
	session:SetAttribute("Pressure", repair.pressure)
	session:SetAttribute("StatusNote", if repair.note ~= "" then repair.note else completedNote)
	session:SetAttribute("Driver", state.driver)
	session:SetAttribute("CartOwner", cart.owner and cart.owner.UserId)
	session:SetAttribute("CartStock", cart.stock)
	for i = 1, 3 do session:SetAttribute("Offer" .. i, state.offers[i]) end
	for id in Service.offers do session:SetAttribute("Bought_" .. id, Service.owns(state, id)) end
	session:SetAttribute("Rerolled", state.rerolled)
	updatePatience(order)
	session:SetAttribute("Phase", phase)
end

local function makeRepair()
	local order = Service.current(state)
	local job = order.jobs[state.repairIndex]
	table.clear(world.drops)
	repair = Repair.new(job, {
		wheel = Repair.wheels[random:NextInteger(1, #Repair.wheels)],
		rightDamper = random:NextNumber() < 0.5, rearLamp = random:NextNumber() < 0.5,
		crackedShield = random:NextNumber() < 0.5, badPuncture = random:NextNumber() < 0.45,
		windowModule = random:NextNumber() < 0.55, highPressure = random:NextNumber() < 0.48,
		weakBattery = job == "inspection" and #order.jobs < 4 and not table.find(order.jobs, "battery") and random:NextNumber() < 0.44,
		oilRecovery = Service.owns(state, "oil_recovery"),
	})
end

local function arrival()
	local order = Service.current(state)
	completedNote = ""
	makeRepair()
	World.selectVehicle(world, order.vehicle)
	refresh()
	World.arrive(world, order)
	Service.arrived(state)
	refresh()
end

local function openMarket()
	refresh()
	World.moveVendor(world, true)
	if Service.openMarket(state) then saves:checkpoint() end
	refresh()
end

finishStep = function(player, step, declined)
	if state.phase ~= "repair" or Repair.current(repair) ~= step then return end
	local done = if declined then Repair.decline(repair) else Repair.act(repair, player.UserId, step.action)
	if not done then return end
	if step.motion then
		refresh()
		World.animate(world, step.motion, Service.liftTime(state))
		Repair.finishMotion(repair)
	elseif not declined then
		World.effect(world, step)
		if step.target == "TireBin" and step.cargo then Gear.recycle(world, step.cargo) end
	end
	if not Repair.current(repair) then
		World.recordRepair(world, repair)
		completedNote = repair.note
		Service.finishRepair(state, repair.job, repair.billable, declined and step.quote == "window", repair.surcharge, repair.addBattery)
		saves:checkpoint()
		if state.phase == "repair" then
			makeRepair()
		else
			table.clear(repair.tools)
			table.clear(repair.carried)
			table.clear(repair.placements)
			Props.parkCart(world)
		end
	end
	refresh()
end

addPrompt("open", "Ouvrir le service", "Téléphone", "Phone", 0.45, function()
	local night = state.phase == "vendor"
	if not Service.open(state) then return end
	saves:checkpoint()
	if night then task.spawn(World.moveVendor, world, false) end
	arrival()
end)
addPrompt("book", "Ajouter un rendez-vous", "Téléphone", "Phone", 0.40, function()
	if Service.book(state) then saves:checkpoint() refresh() end
end)
addPrompt("receive", "Accueillir le client", "Accueil", "Reception", 0.48, function()
	if not Service.receive(state) then return end
	refresh()
	World.waitCustomer(world)
end)
addPrompt("drive", "Prendre le volant", "Véhicule du client", "Door", 0, function(player)
	if not Service.beginDrive(state, player.UserId) then return end
	if world.cart.owner == player then Props.parkCart(world) end
	if not drive:enter(player) then state.driver = 0 end
	refresh()
end)
addPrompt("pay", "Encaisser", "Caisse", "Checkout", 0.55, function()
	if not Service.pay(state) then return end
	saves:checkpoint()
	refresh()
	World.depart(world)
	Service.departed(state)
	if state.phase == "arrival" then
		arrival()
	else
		openMarket()
	end
end)
addPrompt("vendor", "Voir les offres", "La Caravane", "Vendor", 0, function(player)
	if state.phase == "vendor" then vendorControl:FireClient(player, "open") end
end)
addPrompt("snack", "Offrir une collation", "Salle d’attente", "Snack", 0.3, function()
	if Service.snack(state, workspace:GetServerTimeNow()) then saves:checkpoint() refresh() end
end)

for key, spec in Repair.tools do
	addPrompt("takeTool_" .. key, "Prendre", spec.name, spec.target, 0.12, function(player)
		if Repair.takeTool(repair, player.UserId, key) then refresh() end
	end):SetAttribute("Mechanical", true)
	addPrompt("returnTool_" .. key, "Rendre", spec.name, spec.target, 0.24, function(player)
		if Repair.returnTool(repair, player.UserId, key) then refresh() end
	end)
end
for key, spec in Repair.cargo do
	addPrompt("take_" .. key, "Prendre", spec.name, spec.target, 0.15, function(player)
		if Repair.take(repair, player.UserId, key) then refresh() end
	end):SetAttribute("Mechanical", true)
end
for _, key in { "Counter1", "Counter2" } do
	addPrompt("store" .. key, "Poser la pièce", "Desserte", key, 0.18, function(player)
		if Repair.drop(repair, player.UserId, key) then refresh() end
	end)
end

addPrompt("cart", "Pousser le chariot", "Chariot", "Cart", 0, function(player)
	if Props.pullCart(world, player, state) then refresh() end
end)
addPrompt("loadCart", "Charger une roue", "Chariot", "TireRack", 0.30, function(player)
	if world.cart.owner ~= player then return end
	if (world.targets.Cart.WorldPosition - world.targets.TireRack.WorldPosition).Magnitude >= 9 then return end
	Props.stockCart(world, 1)
	refresh()
end, Enum.KeyCode.F)
addPrompt("unloadCart", "Prendre une roue du chariot", "Chariot", "Cart", 0.22, function(player)
	if world.cart.stock > 0 and Repair.source(repair, "newTire") == "TireRack" and Repair.take(repair, player.UserId, "newTire") then
		Props.stockCart(world, -1)
		refresh()
	end
end, Enum.KeyCode.F)

carryControl.OnServerEvent:Connect(function(player)
	local root = activeRoot(player)
	if not root then return end
	local cargo = if state.phase == "repair" then Repair.carrying(repair, player.UserId) else nil
	if not cargo then
		if world.cart.owner == player then Props.parkCart(world) refresh() end
		return
	end
	local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if forward.Magnitude < 0.1 then return end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { player.Character }
	parameters.RespectCanCollide = true
	local obstruction = workspace:Raycast(root.Position, forward.Unit * 2.35, parameters)
	local point = root.Position + forward.Unit * (if obstruction then math.max(0, obstruction.Distance - 0.65) else 2.35)
	local floor = workspace:Raycast(point + Vector3.yAxis * 0.4, -Vector3.yAxis * 7, parameters)
	if not floor then return end
	local height = if cargo == "usedTire" or cargo == "newTire" or cargo == "serviceWheel" then 0.41
		else math.clamp(world.gearTemplates[cargo]:GetExtentsSize().Y / 2, 0.13, 0.82)
	world.drops[cargo] = CFrame.new(floor.Position + Vector3.yAxis * height)
	Repair.drop(repair, player.UserId, "Ground")
	refresh()
end)

vendorControl.OnServerEvent:Connect(function(player, action, id)
	if state.phase ~= "vendor" or not nearby(player, world.targets.Vendor, 7.15) then return end
	local bought, message
	if action == "buy" and type(id) == "string" then
		bought, message = Service.buy(state, id)
	elseif action == "reroll" then
		bought, message = Service.reroll(state)
	else
		return
	end
	if bought then saves:checkpoint() refresh() end
	vendorControl:FireClient(player, "result", bought, message)
end)

optionsControl.OnServerEvent:Connect(function(player, sensitivity)
	saves:changeSensitivity(player, sensitivity)
end)

local function goalPose()
	return if state.phase == "intake" then world.dockPose else world.parkingPose
end

driveControl.OnServerEvent:Connect(function(player, action, throttle, steer)
	if state.driver ~= player.UserId or not drive.rider then return end
	if action == "input" then
		drive:setInput(throttle, steer)
	elseif action == "park" then
		local goal = goalPose()
		local aligned = drive:aligned(goal)
		if not Service.park(state, player.UserId, aligned) then return end
		drive:leave(goal)
		refresh()
		if state.phase == "checkout" then
			World.checkoutCustomer(world)
			Service.readyToPay(state)
			refresh()
		end
	elseif action == "exit" and math.abs(drive.speed) < 2.2 then
		drive:leave()
		state.driver = 0
		refresh()
	end
end)

local elapsed, doorElapsed = 0, 0
RunService.Heartbeat:Connect(function(dt)
	if state.driver ~= 0 then
		drive:update(dt)
		local ready, hint = drive:aligned(goalPose())
		if session:GetAttribute("ParkingReady") ~= ready then
			World.markParking(world, state.phase, ready)
			session:SetAttribute("ParkingReady", ready)
		end
		session:SetAttribute("ParkingHint", hint)
	end
	if not Props.moveCart(world, dt) then refresh() end
	doorElapsed += dt
	if doorElapsed >= 0.09 then
		World.updateDoors(world, Players:GetPlayers(), os.clock())
		doorElapsed = 0
	end
	elapsed += dt
	if elapsed < 0.27 then return end
	local order = Service.current(state)
	local now = workspace:GetServerTimeNow()
	if Service.passTime(state, elapsed, now) then saves:checkpoint() end
	updatePatience(order)
	if world.cart.owner then updateCartLoading() end
	if not prompts.snack.Enabled and state.phase == "repair" and Service.owns(state, "vending")
		and order.snacks < 4 and now >= order.snackUntil then prompts.snack.Enabled = true end
	elapsed = 0
end)

local function release(player)
	if state.driver == player.UserId then drive:leave() end
	if world.cart.owner == player then Props.parkCart(world) end
	Repair.release(repair, player.UserId)
	Service.release(state, player.UserId)
	refresh()
end

local spawnOwners = {}
local function watchPlayer(player)
	saves:watch(player)
	if not workshopOwner then
		workshopOwner = player
		task.spawn(function()
			saves:restore(workshopOwner)
			workshopReady = true
			if state.phase == "arrival" then
				arrival()
			elseif state.phase == "closing" then
				openMarket()
			else
				if state.phase == "vendor" then World.restoreVendor(world) end
				refresh()
			end
		end)
	end
	for _, spawn in world.spawns do
		if not spawnOwners[spawn] then
			spawnOwners[spawn] = player
			player.RespawnLocation = spawn
			if player.Character then player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0)) end
			break
		end
	end
	player.CharacterRemoving:Connect(function() release(player) end)
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	for spawn, owner in spawnOwners do
		if owner == player then spawnOwners[spawn] = nil end
	end
	release(player)
	equipment[player] = nil
	task.spawn(function() saves:leaving(player) end)
	for _, other in Players:GetPlayers() do if other ~= player then return end end
	task.spawn(function() saves:drain(saves.workshop) end)
end)

refresh()
session.Parent = ReplicatedStorage
saves:bindToClose()
for _, player in Players:GetPlayers() do watchPlayer(player) end
print("Garage Day · Le Petit Atelier prêt")

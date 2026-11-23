local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Repair = require(ReplicatedStorage.GarageDay.Repair)
local Service = require(ReplicatedStorage.GarageDay.Service)
local Drive = require(script.Parent.Drive)
local World = require(script.Parent.WorkshopWorld)

local state = Service.new()
local repair = Repair.new(Service.plan(1)[1].job)
local world = World.build()
local drive = Drive.new(world)
local session = Instance.new("Folder")
session.Name = "GarageDaySession"
local driveControl = Instance.new("RemoteEvent")
driveControl.Name = "DriveControl"
driveControl.Parent = session
local prompts = {}
local equipment = {}

local function itemInHand(userId, step)
	if repair.toolOwner == userId then return repair.job, Repair.jobs[repair.job].tool end
	if step and step.cargo and repair.carried[step.cargo] == userId then
		return step.cargo, Repair.cargo[step.cargo].name
	end
	for item, owner in repair.carried do
		if owner == userId then return item, Repair.cargo[item].name end
	end
end

local function updateEquipment(player, step)
	local key, title = itemInHand(player.UserId, step)
	local previous = equipment[player]
	if previous and previous.key == key and previous.tool.Parent then return end
	if previous then previous.tool:Destroy() end
	equipment[player] = nil
	if not key then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid then return end
	local tool = World.makeEquipment(world, key, title)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	equipment[player] = { key = key, tool = tool }
end

local serviceTargets = { free = "Phone", done = "Phone", reception = "Reception", payment = "Checkout" }

local function refresh()
	local phase = state.phase
	local plan = Service.plan(state.day)
	World.apply(world, state, repair)
	local step = if phase == "repair" then Repair.current(repair) else nil
	for _, player in Players:GetPlayers() do updateEquipment(player, step) end
	for name, prompt in prompts do
		prompt.Enabled = step ~= nil and not repair.moving and step.action == name
	end
	prompts.open.Enabled = phase == "free" or phase == "done"
	prompts.receive.Enabled = phase == "reception"
	prompts.drive.Enabled = (phase == "intake" or phase == "outbound") and state.driver == 0
	prompts.pay.Enabled = phase == "payment"
	local focus = serviceTargets[phase]
	if phase == "intake" or phase == "outbound" then
		focus = if state.driver == 0 then "Door" elseif phase == "intake" then "Dock" else "Parking"
	end
	if step then
		local toolPrompt = prompts["takeTool" .. repair.job]
		if toolPrompt then
			toolPrompt.Enabled = repair.toolOwner == 0
			prompts["returnTool" .. repair.job].Enabled = repair.toolOwner ~= 0
		end
		for item in Repair.cargo do prompts["take_" .. item].Enabled = Repair.canTake(repair, item) end
		if not repair.moving then
			focus = step.target
			if step.cargo and Repair.canTake(repair, step.cargo) then focus = Repair.cargo[step.cargo].target end
			if step.tool and repair.toolOwner == 0 then focus = "Tool" .. repair.job end
		end
	end
	World.setObjective(world, focus)
	World.updateBoard(world, state, plan)
	if state.driver == 0 then
		World.markParking(world, phase, false)
		session:SetAttribute("ParkingReady", false)
		session:SetAttribute("ParkingHint", "")
	end
	session:SetAttribute("Day", state.day)
	session:SetAttribute("Cash", state.cash)
	session:SetAttribute("DailyCash", state.dailyCash)
	session:SetAttribute("Served", state.served)
	session:SetAttribute("Ticket", state.ticket)
	session:SetAttribute("Job", repair.job)
	session:SetAttribute("Step", repair.step)
	session:SetAttribute("Moving", repair.moving)
	session:SetAttribute("HoodOpen", repair.hoodOpen)
	session:SetAttribute("Battery", repair.battery)
	session:SetAttribute("Pressure", repair.pressure)
	session:SetAttribute("ToolOwner", repair.toolOwner)
	for item in Repair.cargo do session:SetAttribute("Carry_" .. item, repair.carried[item]) end
	session:SetAttribute("Driver", state.driver)
	session:SetAttribute("Phase", phase)
end

local function addPrompt(name, title, object, key, hold, action)
	local attachment = world.targets[key]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = title
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 6.4
	prompt.RequiresLineOfSight = true
	prompt.ClickablePrompt = true
	prompt.HoldDuration = hold
	prompt.Enabled = false
	prompt.Parent = attachment
	prompts[name] = prompt
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not prompt.Enabled or state.driver == player.UserId or not root or not humanoid or humanoid.Health <= 0 then return end
		if (root.Position - attachment.WorldPosition).Magnitude > prompt.MaxActivationDistance + 0.75 then return end
		action(player)
	end)
end

local function arrival()
	local order = Service.plan(state.day)[state.ticket]
	repair = Repair.new(order.job)
	World.selectVehicle(world, order.vehicle)
	refresh()
	World.arrive(world, order)
	Service.arrived(state)
	refresh()
end

addPrompt("open", "Ouvrir le service", "Téléphone", "Phone", 0.45, function()
	if Service.open(state) then arrival() end
end)
addPrompt("receive", "Accueillir le client", "Accueil", "Reception", 0.48, function()
	if not Service.receive(state) then return end
	refresh()
	World.waitCustomer(world)
end)
addPrompt("drive", "Prendre le volant", "Véhicule du client", "Door", 0, function(player)
	if not Service.beginDrive(state, player.UserId) then return end
	if not drive:enter(player) then state.driver = 0 end
	refresh()
end)
addPrompt("pay", "Encaisser", "Caisse", "Checkout", 0.8, function()
	if not Service.pay(state) then return end
	refresh()
	World.depart(world)
	Service.departed(state)
	if state.phase == "arrival" then arrival() else refresh() end
end)

local function repairAction(player, name)
	local step = Repair.current(repair)
	if state.phase ~= "repair" or not Repair.act(repair, player.UserId, name) then return end
	if step and step.motion and name == step.action then
		refresh()
		World.animate(world, step.motion)
		Repair.finishMotion(repair)
	end
	if name == "testIgnition" then World.testIgnition(world) end
	if Service.finishRepair(state, Repair.current(repair) == nil) then
		repair.toolOwner = 0
		table.clear(repair.carried)
	end
	refresh()
end

local workNames = {
	Lever = "Pont 01", FrontLeft = "Roue avant gauche", FrontRight = "Roue avant droite", BackRight = "Roue arrière droite",
	Hood = "Capot", OilCap = "Moteur", Drain = "Sous le moteur", WasteOil = "Récupérateur", Recycling = "Recyclage",
	BatteryTray = "Plateau de batterie", Door = "Porte conducteur",
}
for job, spec in Repair.jobs do
	for _, step in spec.steps do
		if not prompts[step.action] then
			addPrompt(step.action, step.title, workNames[step.target], step.target, step.hold, function(player)
				repairAction(player, step.action)
			end)
		end
	end
	if spec.tool then
		addPrompt("takeTool" .. job, "Prendre", spec.tool, "Tool" .. job, 0, function(player)
			repairAction(player, "takeTool")
		end)
		addPrompt("returnTool" .. job, "Rendre", spec.tool, "Tool" .. job, 0.4, function(player)
			repairAction(player, "returnTool")
		end)
	end
end
for item, spec in Repair.cargo do
	addPrompt("take_" .. item, spec.action, spec.name, spec.target, 0.15, function(player)
		if state.phase == "repair" and Repair.take(repair, player.UserId, item) then refresh() end
	end)
end

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

RunService.Heartbeat:Connect(function(dt)
	if state.driver == 0 then return end
	drive:update(dt)
	local ready, hint = drive:aligned(goalPose())
	if session:GetAttribute("ParkingReady") ~= ready then
		World.markParking(world, state.phase, ready)
		session:SetAttribute("ParkingReady", ready)
	end
	session:SetAttribute("ParkingHint", hint)
end)

local function release(player)
	if state.driver == player.UserId then drive:leave() end
	Repair.release(repair, player.UserId)
	Service.release(state, player.UserId)
	refresh()
end

local spawnOwners = {}
local function watchPlayer(player)
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
end)
for _, player in Players:GetPlayers() do watchPlayer(player) end

refresh()
session.Parent = ReplicatedStorage
print("Garage Day · Le Petit Atelier prêt")

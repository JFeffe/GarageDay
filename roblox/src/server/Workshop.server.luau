local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Repair = require(ReplicatedStorage.GarageDay.Repair)
local Service = require(ReplicatedStorage.GarageDay.Service)
local Drive = require(script.Parent.Drive)
local World = require(script.Parent.WorkshopWorld)

local state = Service.new()
local repair = Repair.new(Service.orders[state.ticket].job)
local world = World.build()
local drive = Drive.new(world)
local session = Instance.new("Folder")
session.Name = "GarageDaySession"
local driveControl = Instance.new("RemoteEvent")
driveControl.Name = "DriveControl"
driveControl.Parent = session
local prompts = {}
local heldTool
local toolOwner = 0

local function updateTool()
	if toolOwner == repair.toolOwner then return end
	if heldTool then heldTool:Destroy() end
	heldTool = nil
	toolOwner = repair.toolOwner
	if toolOwner == 0 then return end
	local owner = Players:GetPlayerByUserId(toolOwner)
	local backpack = owner and owner:FindFirstChildOfClass("Backpack")
	local humanoid = owner and owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
	if backpack and humanoid then
		heldTool = World.makeTool(world, repair.job, Repair.jobs[repair.job].tool)
		heldTool.Parent = backpack
		humanoid:EquipTool(heldTool)
	end
end

local function refresh()
	local phase = state.phase
	World.apply(world, state, repair)
	updateTool()
	local step = if phase == "repair" then Repair.current(repair) else nil
	for name, prompt in prompts do
		prompt.Enabled = step ~= nil and not repair.moving and step.action == name
	end
	prompts.open.Enabled = phase == "free" or phase == "done"
	prompts.receive.Enabled = phase == "reception"
	prompts.drive.Enabled = (phase == "intake" or phase == "outbound") and state.driver == 0
	prompts.pay.Enabled = phase == "payment"
	if step then
		prompts["takeTool" .. repair.job].Enabled = repair.toolOwner == 0
		prompts["returnTool" .. repair.job].Enabled = repair.toolOwner ~= 0
		prompts.takePads.Enabled = Repair.canTakePads(repair)
	end
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
	session:SetAttribute("LiftMoving", repair.moving)
	session:SetAttribute("ToolOwner", repair.toolOwner)
	session:SetAttribute("PadsOwner", repair.padsOwner)
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
	local order = Service.orders[state.ticket]
	repair = Repair.new(order.job)
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
addPrompt("drive", "Prendre le volant", "Berline du client", "Door", 0, function(player)
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
	if state.phase ~= "repair" or not Repair.act(repair, player.UserId, name) then return end
	if name == "raise" or name == "lower" then
		refresh()
		World.moveLift(world, name == "raise")
		Repair.finishLift(repair)
	end
	if Service.finishRepair(state, Repair.current(repair) == nil) then
		repair.toolOwner = 0
		repair.padsOwner = 0
	end
	refresh()
end

local workNames = { Lever = "Pont 01", FrontLeft = "Roue avant gauche", FrontRight = "Roue avant droite", BackRight = "Roue arrière droite" }
for job, spec in Repair.jobs do
	for _, step in spec.steps do
		addPrompt(step.action, step.title, workNames[step.target], step.target, step.hold, function(player)
			repairAction(player, step.action)
		end)
	end
	addPrompt("takeTool" .. job, "Prendre", spec.tool, "Tool" .. job, 0, function(player)
		repairAction(player, "takeTool")
	end)
	addPrompt("returnTool" .. job, "Rendre", spec.tool, "Tool" .. job, 0.4, function(player)
		repairAction(player, "returnTool")
	end)
end
addPrompt("takePads", "Prendre les plaquettes", "Pièces châssis", "Pads", 0, function(player)
	repairAction(player, "takePads")
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
end)
for _, player in Players:GetPlayers() do watchPlayer(player) end

refresh()
session.Parent = ReplicatedStorage
print("Garage Day · Le Petit Atelier prêt")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Repair = require(ReplicatedStorage.GarageDay.Repair)
local World = require(script.Parent.WorkshopWorld)

local state = Repair.new()
local world = World.build()
local session = Instance.new("Folder")
session.Name = "GarageDaySession"
local prompts = {}
local heldTool
local toolOwner = 0

local function updateTool()
	if toolOwner == state.wrenchOwner then return end
	if heldTool then
		heldTool:Destroy()
		heldTool = nil
	end
	toolOwner = state.wrenchOwner
	if toolOwner ~= 0 then
		local owner = Players:GetPlayerByUserId(toolOwner)
		local backpack = owner and owner:FindFirstChildOfClass("Backpack")
		local humanoid = owner and owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
		if backpack and humanoid then
			heldTool = World.makeWrench(world)
			heldTool.Parent = backpack
			humanoid:EquipTool(heldTool)
		end
	end
end

local function refresh()
	World.apply(world, state)
	updateTool()
	local action = Repair.steps[state.step].action
	for id, prompt in prompts do
		prompt.Enabled = not state.moving and id == action
	end
	prompts.takeWrench.Enabled = state.wrenchOwner == 0 and state.step < #Repair.steps
	prompts.returnWrench.Enabled = state.wrenchOwner ~= 0
	prompts.takePads.Enabled = Repair.canTakePads(state)
	session:SetAttribute("Step", state.step)
	session:SetAttribute("LiftMoving", state.moving)
	session:SetAttribute("WrenchOwner", state.wrenchOwner)
	session:SetAttribute("PadsOwner", state.padsOwner)
end

local function addPrompt(action, label, object, attachment, hold)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = action
	prompt.ActionText = label
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 6.4
	prompt.RequiresLineOfSight = true
	prompt.ClickablePrompt = true
	prompt.HoldDuration = hold
	prompt.Enabled = false
	prompt.Parent = attachment
	prompts[action] = prompt
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not prompt.Enabled or not root or not humanoid or humanoid.Health <= 0 then return end
		if (root.Position - attachment.WorldPosition).Magnitude > prompt.MaxActivationDistance + 0.75 then return end
		if not Repair.act(state, player.UserId, action) then return end
		refresh()
		if action == "raise" or action == "lower" then
			World.moveLift(world, action == "raise")
			Repair.finishLift(state)
			refresh()
		end
	end)
end

for _, step in Repair.steps do
	local title = if step.action == "replay" then "Recommencer" else step.title
	local object = if step.target == "Lever" then "Pont" else "Roue avant gauche"
	addPrompt(step.action, title, object, world.targets[step.target], step.hold)
end
addPrompt("takeWrench", "Prendre", "Clé à choc", world.targets.Tools, 0)
addPrompt("returnWrench", "Rendre", "Clé à choc", world.targets.Tools, 0.4)
addPrompt("takePads", "Prendre", "Plaquettes avant", world.targets.Shelf, 0)

local function release(player)
	Repair.release(state, player.UserId)
	refresh()
end

local spawnOwners = {}
local function watchPlayer(player)
	for _, spawn in world.spawns do
		if not spawnOwners[spawn] then
			spawnOwners[spawn] = player
			player.RespawnLocation = spawn
			if player.Character then
				player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
			end
			break
		end
	end
	player.CharacterRemoving:Connect(function()
		release(player)
	end)
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	for spawn, owner in spawnOwners do
		if owner == player then spawnOwners[spawn] = nil end
	end
	release(player)
end)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end

refresh()
session.Parent = ReplicatedStorage
print("Garage Day · Le Petit Atelier prêt")

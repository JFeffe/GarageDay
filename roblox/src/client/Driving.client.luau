local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local session = ReplicatedStorage:WaitForChild("GarageDaySession")
local remote = session:WaitForChild("DriveControl")
local bays = session:WaitForChild("Bays")
local keys = {}
local stick = Vector2.zero
local active = false
local sentAt = 0
local priority = Enum.ContextActionPriority.High.Value
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true

local controls = Instance.new("ScreenGui")
controls.Name = "ConduiteGarageDay"
controls.ResetOnSpawn = false
controls.Enabled = false
controls.DisplayOrder = 5
controls.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -17)
bar.Size = UDim2.fromOffset(287, 39)
bar.BackgroundTransparency = 1
bar.Parent = controls
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 8)
layout.Parent = bar

local function button(text, width, command)
	local result = Instance.new("TextButton")
	result.Size = UDim2.fromOffset(width, 39)
	result.Font = Enum.Font.GothamBold
	result.TextSize = 15
	result.Text = text
	result.TextColor3 = Color3.fromRGB(255, 241, 211)
	result.BackgroundColor3 = Color3.fromRGB(24, 49, 51)
	result.Parent = bar
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 7)
	round.Parent = result
	result.Activated:Connect(function() remote:FireServer(command) end)
	return result
end

local parkButton = button("Valider la place", 155, "park")
button("Descendre", 124, "exit")

local directions = {
	{ "GarageAvant", "↑", UDim2.fromScale(0.08, 0.05), Enum.KeyCode.W, Enum.KeyCode.Up },
	{ "GarageArrière", "↓", UDim2.fromScale(0.08, 0.44), Enum.KeyCode.S, Enum.KeyCode.Down },
	{ "GarageGauche", "←", UDim2.fromScale(0.50, 0.44), Enum.KeyCode.A, Enum.KeyCode.Left },
	{ "GarageDroite", "→", UDim2.fromScale(0.85, 0.44), Enum.KeyCode.D, Enum.KeyCode.Right },
}

local function keyInput(name, inputState)
	keys[name] = if inputState == Enum.UserInputState.Begin then 1 else 0
	return Enum.ContextActionResult.Sink
end

local function stickInput(_, inputState, input)
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		stick = Vector2.zero
	else
		local raw = Vector2.new(input.Position.X, input.Position.Y)
		stick = if raw.Magnitude > 0.17 then raw else Vector2.zero
	end
	return Enum.ContextActionResult.Sink
end

local function commandInput(name, inputState)
	if inputState == Enum.UserInputState.Begin then
		remote:FireServer(if name == "GaragePark" then "park" else "exit")
	end
	return Enum.ContextActionResult.Sink
end

local function frame(dt)
	local bay = bays:FindFirstChild(tostring(player:GetAttribute("GarageDriverBay")))
	local reference = bay and bay:FindFirstChild("Vehicle")
	local car = reference and reference.Value
	if not car then return end
	local pose = car:GetPivot()
	local camera = workspace.CurrentCamera
	local look = pose:PointToWorldSpace(Vector3.new(0, 1.85, -3.2))
	local eye = pose:PointToWorldSpace(Vector3.new(0, 7.2, 10.8))
	ray.FilterDescendantsInstances = { car, player.Character }
	local hit = workspace:Raycast(look, eye - look, ray)
	if hit then eye = hit.Position:Lerp(look, 0.095) end
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, look), math.min(dt * 13, 1))
	camera.Focus = CFrame.new(look)

	if os.clock() - sentAt >= 0.055 then
		local throttle = (keys.GarageAvant or 0) - (keys["GarageArrière"] or 0)
		local steer = (keys.GarageDroite or 0) - (keys.GarageGauche or 0)
		remote:FireServer("input", math.clamp(throttle + stick.Y, -1, 1), math.clamp(steer + stick.X, -1, 1))
		sentAt = os.clock()
	end
end

local function update()
	local id = player:GetAttribute("GarageDriverBay")
	local bay = id and bays:FindFirstChild(tostring(id))
	local ready = bay and bay:GetAttribute("ParkingReady") == true
	parkButton.BackgroundColor3 = if ready then Color3.fromRGB(64, 113, 78) else Color3.fromRGB(24, 49, 51)
	local driving = id ~= nil
	if driving == active then return end
	active = driving
	controls.Enabled = driving
	local camera = workspace.CurrentCamera
	if driving then
		player.CameraMode = Enum.CameraMode.Classic
		camera.CameraType = Enum.CameraType.Scriptable
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		for _, action in directions do
			ContextActionService:BindActionAtPriority(action[1], keyInput, true, priority, action[4], action[5])
			ContextActionService:SetTitle(action[1], action[2])
			ContextActionService:SetPosition(action[1], action[3])
		end
		ContextActionService:BindActionAtPriority("GarageStick", stickInput, false, priority, Enum.KeyCode.Thumbstick1)
		ContextActionService:BindActionAtPriority("GaragePark", commandInput, false, priority, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:BindActionAtPriority("GarageExit", commandInput, false, priority, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
		RunService:BindToRenderStep("GarageDayDrive", Enum.RenderPriority.Camera.Value + 1, frame)
	else
		RunService:UnbindFromRenderStep("GarageDayDrive")
		for _, action in directions do ContextActionService:UnbindAction(action[1]) end
		for _, action in { "GarageStick", "GaragePark", "GarageExit" } do ContextActionService:UnbindAction(action) end
		table.clear(keys)
		stick = Vector2.zero
		camera.CameraType = Enum.CameraType.Custom
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

player:GetAttributeChangedSignal("GarageDriverBay"):Connect(update)
local function watchBay(bay)
	bay:GetAttributeChangedSignal("ParkingReady"):Connect(update)
end
for _, bay in bays:GetChildren() do watchBay(bay) end
bays.ChildAdded:Connect(watchBay)
update()

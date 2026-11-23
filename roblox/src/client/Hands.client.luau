local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local session = ReplicatedStorage:WaitForChild("GarageDaySession")

local screen = Instance.new("ScreenGui")
screen.Name = "MainsGarageDay"
screen.ResetOnSpawn = false
screen.ScreenInsets = Enum.ScreenInsets.None
screen.DisplayOrder = 2
screen.Parent = playerGui

local view = Instance.new("ViewportFrame")
view.Name = "Vue des mains"
view.Size = UDim2.fromScale(1, 1)
view.BackgroundTransparency = 1
view.Ambient = Color3.fromRGB(200, 204, 199)
view.LightColor = Color3.fromRGB(255, 240, 218)
view.LightDirection = Vector3.new(0.7, -0.8, -1)
view.Parent = screen

local camera = Instance.new("Camera")
camera.CFrame = CFrame.identity
camera.FieldOfView = 51
camera.Parent = view
view.CurrentCamera = camera

local stage = Instance.new("WorldModel")
stage.Parent = view

local cuff = Color3.fromRGB(39, 65, 70)
local sleeve = Color3.fromRGB(48, 87, 87)
local glove = Color3.fromRGB(137, 94, 62)
local leather = Color3.fromRGB(97, 65, 46)
local seam = Color3.fromRGB(203, 158, 103)

local function makeHand(side, grip)
	local hand = Instance.new("Model")
	hand.Name = if side < 0 then "Main gauche" else "Main droite"
	hand.WorldPivot = CFrame.identity

	local function shape(name, size, pose, color, kind)
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.CFrame = pose
		piece.Color = color
		piece.Shape = kind or Enum.PartType.Block
		piece.Material = Enum.Material.SmoothPlastic
		piece.Anchored = true
		piece.CanCollide, piece.CanQuery, piece.CanTouch = false, false, false
		piece.Parent = hand
		return piece
	end

	local angle = CFrame.Angles(0, math.pi / 2, 0.09 * side)
	shape("Manche de mécanicien", Vector3.new(1.29, 0.43, 0.45), CFrame.new(side * 0.115, -0.22, 0.86)
		* CFrame.Angles(-0.27, 0, 0) * angle, sleeve, Enum.PartType.Cylinder)
	shape("Poignet de la manche", Vector3.new(0.24, 0.43, 0.44), CFrame.new(side * 0.046, -0.055, 0.25) * angle,
		cuff, Enum.PartType.Cylinder)
	shape("Tranche de la manche", Vector3.new(0.056, 0.44, 0.45), CFrame.new(side * 0.045, -0.051, 0.154) * angle,
		sleeve, Enum.PartType.Cylinder)
	shape("Paume", Vector3.new(0.43, 0.237, 0.52), CFrame.new(side * -0.025, -0.054, -0.057), leather, Enum.PartType.Ball)
	shape("Dos du gant", Vector3.new(0.405, 0.18, 0.48), CFrame.new(side * -0.026, 0.006, -0.070), glove, Enum.PartType.Ball)
	shape("Renfort du gant", Vector3.new(0.27, 0.058, 0.19), CFrame.new(side * -0.025, 0.084, -0.112), leather, Enum.PartType.Ball)
	for index, length in { 0.25, 0.29, 0.26, 0.20 } do
		local x = side * (-0.165 + (index - 1) * 0.085)
		local bend = if grip then -0.8 else -0.25 + index * 0.035
		local joint = CFrame.new(x, -0.034, -0.253) * CFrame.Angles(bend, 0, 0)
		shape("Doigt", Vector3.new(0.095, 0.13, length), joint * CFrame.new(0, 0, -length * 0.3), glove, Enum.PartType.Ball)
		shape("Bout du gant", Vector3.new(0.086, 0.11, 0.12), joint * CFrame.new(0, -0.019, -length * 0.68), leather, Enum.PartType.Ball)
	end
	shape("Pouce", Vector3.new(0.16, 0.16, 0.33), CFrame.new(side * -0.203, -0.056, -0.08)
		* CFrame.Angles(-0.49, 0.58 * side, 0), glove, Enum.PartType.Ball)
	shape("Couture", Vector3.new(0.27, 0.022, 0.041), CFrame.new(side * -0.01, 0.075, 0.04), seam, Enum.PartType.Ball)
	return hand
end

local openLeft, openRight = makeHand(-1, false), makeHand(1, false)
local gripLeft, gripRight = makeHand(-1, true), makeHand(1, true)
local activeHold
local actionUntil = 0
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, actor)
	if actor == player and prompt:GetAttribute("Mechanical") then activeHold = prompt end
end)
ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, actor)
	if actor == player and activeHold == prompt then activeHold = nil end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if activeHold == prompt then activeHold = nil end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, actor)
	if actor == player and prompt:GetAttribute("Mechanical") then actionUntil = os.clock() + 0.20 end
end)

local original, item, itemPieces
local gearKey, large, wheel
local function showEquipment(visual, count)
	if visual == original and count == itemPieces then return end
	if original then
		for _, piece in original:GetChildren() do piece.LocalTransparencyModifier = 0 end
	end
	if item then item:Destroy() end
	original, itemPieces, item, gearKey, large, wheel = visual, count, nil, nil, false, false
	if not visual then return end

	gearKey = visual.Parent:GetAttribute("GearKey")
	large = visual.Parent:GetAttribute("TwoHanded")
	wheel = gearKey == "newTire" or gearKey == "usedTire" or gearKey == "serviceWheel"
	local clone = visual:Clone()
	for _, piece in clone:GetChildren() do
		local gripPose = piece:GetAttribute("GripPose")
		if not gripPose then
			clone:Destroy()
			original, itemPieces, gearKey, large, wheel = nil, nil, nil, false, false
			return
		end
		piece:ClearAllChildren()
		piece.Anchored = true
		piece.CFrame = gripPose
		piece.LocalTransparencyModifier = 0
	end
	clone.WorldPivot = CFrame.identity
	if wheel then clone:ScaleTo(0.90) end
	clone.Parent = stage
	item = clone
	for _, piece in visual:GetChildren() do piece.LocalTransparencyModifier = 1 end
end

local gait, swing, reach = 0, 0, 0
RunService:BindToRenderStep("GarageDayMains", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local driving = session:GetAttribute("Driver") == player.UserId
	local enabled = humanoid ~= nil and humanoid.Health > 0 and not driving and not playerGui:GetAttribute("CaravaneOpen")
	screen.Enabled = enabled
	if not enabled then showEquipment(nil, nil) return end

	local tool = character:FindFirstChildOfClass("Tool")
	local visual = tool and tool:FindFirstChild("HeldGeometry")
	showEquipment(visual, if visual then #visual:GetChildren() else nil)
	local root = character:FindFirstChild("HumanoidRootPart")
	local speed = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	local pushing = session:GetAttribute("CartOwner") == player.UserId
	swing += (math.clamp(speed / 13, 0, 1) - swing) * math.min(dt * 8, 1)
	reach += ((if activeHold or os.clock() < actionUntil then 1 else 0) - reach) * math.min(dt * 11, 1)
	gait += dt * 9
	local bounce = math.cos(gait * 2) * 0.048 * swing + math.sin(os.clock() * 2.5) * 0.017
	local sway = math.sin(gait) * 0.093 * swing
	local aspect = view.AbsoluteSize.X / math.max(1, view.AbsoluteSize.Y)
	local gap = math.clamp(aspect / 1.53, 0.65, 1)
	local raised = bounce + reach * 0.34

	local left = if large or pushing then gripLeft else openLeft
	local right = if item or pushing then gripRight else openRight
	openLeft.Parent = if left == openLeft then stage else nil
	gripLeft.Parent = if left == gripLeft then stage else nil
	openRight.Parent = if right == openRight then stage else nil
	gripRight.Parent = if right == gripRight then stage else nil

	if large then
		local height = if wheel then -1.51 else -1.28
		local base = CFrame.new(sway * 0.44, height + raised, -3.84 - reach * 0.29) * CFrame.Angles(0.20, -0.10, 0.03 * sway)
		local offset = if wheel then 0.77 else 0.59
		left:PivotTo(base * CFrame.new(-offset * gap, -0.07, 0.10) * CFrame.Angles(0.24, -0.27, -0.35))
		right:PivotTo(base * CFrame.new(offset * gap, -0.07, 0.10) * CFrame.Angles(0.24, 0.27, 0.35))
		item:PivotTo(base * CFrame.new(0, if wheel then 0.14 else 0.02, -0.25)
			* CFrame.Angles(if wheel then -0.24 else 0.31, if wheel then -math.pi / 2 + 0.19 else -0.16, 0.02))
	else
		local width = if pushing then 0.70 else 1.03
		local level = if pushing then -1.08 else -1.26
		left:PivotTo(CFrame.new(-width * gap + sway, level + bounce + reach * 0.14, -3.26 - reach * 0.29)
			* CFrame.Angles(0.32, 0.28, -0.28))
		local grip = CFrame.new((if item then 0.77 else width) * gap + sway, level + raised, -3.33 - reach * 0.37)
			* CFrame.Angles(0.26, -0.24, 0.24)
		right:PivotTo(grip)
		if item then
			item:PivotTo(grip * CFrame.new(-0.035, 0.24, -0.13) * CFrame.Angles(0.30, if gearKey == "impact" then -0.53 else 0.15, -0.25))
		end
	end
end)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local session = ReplicatedStorage:WaitForChild("GarageDaySession")
local control = session:WaitForChild("FurnitureControl")
local carry = session:WaitForChild("CarryControl")
local color = Color3.fromRGB(161, 219, 190)
local warning = Color3.fromRGB(244, 135, 108)

local screen = Instance.new("ScreenGui")
screen.Name = "ReamenagementGarageDay"
screen.ResetOnSpawn = false
screen.DisplayOrder = 5
screen.Enabled = false
screen.Parent = playerGui
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 1)
banner.Position = UDim2.new(0.5, 0, 1, -20)
banner.Size = UDim2.new(0.88, 0, 0, 59)
banner.BackgroundColor3 = Color3.fromRGB(27, 47, 46)
banner.TextColor3 = color
banner.Font = Enum.Font.GothamMedium
banner.TextSize = 14
banner.TextWrapped = true
banner.Parent = screen
local bounds = Instance.new("UISizeConstraint")
bounds.MaxSize = Vector2.new(480, 65)
bounds.Parent = banner
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 8)
round.Parent = banner

local selection
local function display()
	if not selection then return end
	local input = UserInputService.PreferredInput
	local keys = if input == Enum.PreferredInput.Touch then "Vise le sol pour déplacer l’objet."
		elseif input == Enum.PreferredInput.Gamepad then "X déposer · LB pivoter · B annuler"
		else "E déposer · R pivoter · Q annuler"
	local blocked = os.clock() < selection.blocked
	banner.Text = selection.name .. "\n" .. (if blocked then "Place bloquée. Libère le passage ou vise un autre endroit." else keys)
	banner.TextColor3 = if blocked then warning else color
	selection.outline.Color3 = if blocked then warning else color
end

local actions = {
	{ "GarageMeublePoser", "Déposer", Enum.KeyCode.E, Enum.KeyCode.ButtonX, UDim2.fromScale(0.57, 0.24) },
	{ "GarageMeublePivoter", "Pivoter", Enum.KeyCode.R, Enum.KeyCode.ButtonL1, UDim2.fromScale(0.36, 0.12) },
	{ "GarageMeubleAnnuler", "Annuler", Enum.KeyCode.Q, Enum.KeyCode.ButtonB, UDim2.fromScale(0.18, 0.24) },
}

local function close()
	if not selection then return end
	ProximityPromptService.Enabled = selection.promptsEnabled
	selection.ghost:Destroy()
	selection = nil
	screen.Enabled = false
	RunService:UnbindFromRenderStep("GarageDayPlacement")
	for _, action in actions do ContextActionService:UnbindAction(action[1]) end
end

local function update()
	local camera = workspace.CurrentCamera
	local eye, aim = camera.CFrame.Position, camera.CFrame.LookVector
	local data = selection
	data.follow = data.follow or data.eye:Dot(aim) < 0.996 or (eye - data.position).Magnitude > 0.85
	if data.follow then
		local distance = if aim.Y < -0.03 then math.clamp((eye.Y - data.home.Y) / -aim.Y, 2.2, 7.1) else 5.2
		local point = eye + aim * distance
		local grid = data.scale / 4
		data.x = data.origin.X + math.round((point.X - data.origin.X) / grid) * grid
		data.z = data.origin.Z + math.round((point.Z - data.origin.Z) / grid) * grid
	end
	local pose = CFrame.new(data.x, data.home.Y, data.z) * data.home.Rotation * CFrame.Angles(0, data.turn * math.pi / 2, 0)
	data.ghost:PivotTo(pose + Vector3.yAxis * 0.04)
	display()
end

local function begin(model, size, home, turn, origin, scale)
	close()
	local pose = model:GetPivot()
	local ghost = Instance.new("Model")
	ghost.Name = "Aperçu du placement"
	ghost.WorldPivot = pose
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.Transparency < 0.95 then
			local clone = piece:Clone()
			clone:ClearAllChildren()
			clone.Anchored = true
			clone.CanCollide, clone.CanTouch, clone.CanQuery = false, false, false
			clone.Color = clone.Color:Lerp(color, 0.35)
			clone.Transparency = math.max(clone.Transparency, 0.48)
			clone.Parent = ghost
		end
	end
	local box = Instance.new("Part")
	box.Size = size
	box.CFrame = pose * CFrame.new(0, size.Y / 2, 0)
	box.Transparency = 1
	box.Anchored = true
	box.CanCollide, box.CanTouch, box.CanQuery = false, false, false
	box.Parent = ghost
	local outline = Instance.new("SelectionBox")
	outline.Adornee = box
	outline.Color3 = color
	outline.LineThickness = 0.035
	outline.Parent = ghost
	ghost.Parent = workspace
	local camera = workspace.CurrentCamera.CFrame
	selection = {
		name = model.Name, ghost = ghost, outline = outline, home = home, turn = turn, origin = origin, scale = scale,
		x = pose.X, z = pose.Z, eye = camera.LookVector, position = camera.Position, blocked = 0,
		promptsEnabled = ProximityPromptService.Enabled,
	}
	ProximityPromptService.Enabled = false
	local priority = Enum.ContextActionPriority.High.Value + 1
	for i, action in actions do
		ContextActionService:BindActionAtPriority(action[1], function(_, inputState)
			if inputState == Enum.UserInputState.Begin and selection then
				if i == 1 then
					control:FireServer("place", selection.x, selection.z, selection.turn)
				elseif i == 2 then
					selection.turn = (selection.turn + 1) % 4
					selection.blocked = 0
				else
					carry:FireServer()
				end
			end
			return Enum.ContextActionResult.Sink
		end, UserInputService.TouchEnabled, priority, action[3], action[4])
		ContextActionService:SetTitle(action[1], action[2])
		ContextActionService:SetPosition(action[1], action[5])
	end
	screen.Enabled = true
	RunService:BindToRenderStep("GarageDayPlacement", Enum.RenderPriority.Camera.Value + 3, update)
end

control.OnClientEvent:Connect(function(action, ...)
	if action == "begin" then begin(...)
	elseif action == "end" then close()
	elseif action == "blocked" and selection then selection.blocked = os.clock() + 1.85 end
end)
player.CharacterRemoving:Connect(close)

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local jobs = require(ReplicatedStorage:WaitForChild("GarageDay"):WaitForChild("Repair")).jobs
local session = ReplicatedStorage:WaitForChild("GarageDaySession")
local bays = session:WaitForChild("Bays")
local control = session:WaitForChild("RepairControl")
local dark = Color3.fromRGB(23, 43, 43)
local teal = Color3.fromRGB(44, 74, 71)
local cream = Color3.fromRGB(250, 237, 209)
local mint = Color3.fromRGB(172, 215, 193)
local gold = Color3.fromRGB(239, 192, 119)

local screen = Instance.new("ScreenGui")
screen.Name = "BonDeTravail"
screen.ResetOnSpawn = false
screen.DisplayOrder = 10
screen.Enabled = false
screen.Parent = playerGui

local function panel(parent, color)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3, frame.BorderSizePixel = color, 0
	frame.Parent = parent
	return frame
end

local function rounded(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function text(parent, label, position, size, fontSize, color, button)
	local item = Instance.new(if button then "TextButton" else "TextLabel")
	item.Position, item.Size = position, size
	item.Text, item.TextSize, item.TextColor3 = label, fontSize, color
	item.Font = Enum.Font.GothamBold
	item.BackgroundTransparency = if button then 0 else 1
	if button then
		item.BackgroundColor3 = teal
		rounded(item, 7)
	else
		item.TextXAlignment = Enum.TextXAlignment.Left
	end
	item.Parent = parent
	return item
end

local backdrop = panel(screen, dark)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Active = true
backdrop.BackgroundTransparency = 0.36
local card = panel(backdrop, dark)
card.AnchorPoint, card.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(1, -30, 0, 290)
rounded(card, 12)
local bounds = Instance.new("UISizeConstraint")
bounds.MaxSize = Vector2.new(410, 340)
bounds.Parent = card
local rule = Instance.new("UIStroke")
rule.Color, rule.Parent = Color3.fromRGB(93, 132, 117), card

text(card, "Choisir une réparation", UDim2.fromOffset(17, 12), UDim2.new(1, -74, 0, 38), 22, cream)
local details = text(card, "", UDim2.fromOffset(18, 50), UDim2.new(1, -36, 0, 21), 13, mint)
local dismiss = text(card, "×", UDim2.new(1, -47, 0, 10), UDim2.fromOffset(35, 34), 20, cream, true)
dismiss.Name, dismiss.Modal = "Fermer", true
local list = Instance.new("ScrollingFrame")
list.Position, list.Size = UDim2.fromOffset(17, 81), UDim2.new(1, -34, 1, -98)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.fromOffset(0, 0)
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = mint
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Parent = card
local stack = Instance.new("UIListLayout")
stack.SortOrder, stack.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 7)
stack.Parent = list

local bay, watcher, savedPrompts
local function close()
	if not screen.Enabled then return end
	if watcher then watcher:Disconnect() end
	watcher, bay = nil, nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(screen) then GuiService.SelectedObject = nil end
	screen.Enabled = false
	playerGui:SetAttribute("RepairChoiceOpen", false)
	ProximityPromptService.Enabled = savedPrompts
	ContextActionService:UnbindAction("GarageRepairChoice")
end
dismiss.Activated:Connect(close)
player.CharacterRemoving:Connect(close)
session:GetAttributeChangedSignal("LaunchMode"):Connect(close)

local buttons, displayed = {}, {}
for i = 1, 4 do
	local item = text(list, "", UDim2.fromOffset(0, 0), UDim2.new(1, -5, 0, 38), 15, cream, true)
	item.Name, item.LayoutOrder = "Intervention" .. i, i
	buttons[i] = item
	item.Activated:Connect(function()
		local key = displayed[i]
		if not bay or not key then return end
		control:FireServer(tonumber(bay.Name), key)
		close()
	end)
end

local function refresh()
	if not bay or bay.Parent ~= bays or not bay:GetAttribute("CanChooseRepair") then close() return end
	local current = bay:GetAttribute("Job")
	local pending = string.split(bay:GetAttribute("PendingJobs") or "", ",")
	details.Text = "Baie 0" .. bay.Name .. " · " .. (bay:GetAttribute("Customer") or "")
	for i, item in buttons do
		local key = pending[i]
		local job = key and jobs[key]
		displayed[i] = job and key
		item.Visible = job ~= nil
		if job then
			item.Text = job.name
			item.BackgroundColor3 = if key == current then gold else teal
			item.TextColor3 = if key == current then dark else cream
		end
	end
	card.Size = UDim2.new(1, -30, 0, 98 + #pending * 45)
end

control.OnClientEvent:Connect(function(id)
	if playerGui:GetAttribute("WorkshopOptionsOpen") or playerGui:GetAttribute("CaravaneOpen") then return end
	local row = bays:FindFirstChild(tostring(id))
	if not row or not row:GetAttribute("CanChooseRepair") then return end
	close()
	bay, savedPrompts = row, ProximityPromptService.Enabled
	screen.Enabled = true
	ProximityPromptService.Enabled = false
	playerGui:SetAttribute("RepairChoiceOpen", true)
	watcher = row.AttributeChanged:Connect(refresh)
	ContextActionService:BindActionAtPriority("GarageRepairChoice", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin and (input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.F) then close() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.F, Enum.KeyCode.ButtonB,
		Enum.KeyCode.E, Enum.KeyCode.Q, Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump, Enum.KeyCode.Thumbstick1)
	refresh()
	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then GuiService.SelectedObject = buttons[1] end
end)

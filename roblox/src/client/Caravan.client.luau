local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local session = ReplicatedStorage:WaitForChild("GarageDaySession")
local remote = session:WaitForChild("VendorControl")
local Service = require(ReplicatedStorage.GarageDay.Service)

local ink = Color3.fromRGB(21, 38, 40)
local teal = Color3.fromRGB(44, 73, 71)
local paper = Color3.fromRGB(249, 235, 207)
local gold = Color3.fromRGB(238, 184, 104)
local mint = Color3.fromRGB(180, 222, 195)

local function corner(parent, radius)
	local node = Instance.new("UICorner")
	node.CornerRadius = UDim.new(0, radius)
	node.Parent = parent
end

local function text(parent, message, position, size, fontSize, color, button)
	local element = Instance.new(if button then "TextButton" else "TextLabel")
	element.Position = position
	element.Size = size
	element.Text = message
	element.TextColor3 = color
	element.TextSize = fontSize
	element.Font = if button then Enum.Font.GothamBold else Enum.Font.GothamMedium
	element.BackgroundTransparency = if button then 0 else 1
	if button then
		element.BackgroundColor3 = teal
		corner(element, 7)
	else
		element.TextXAlignment = Enum.TextXAlignment.Left
	end
	element.Parent = parent
	return element
end

local gui = Instance.new("ScreenGui")
gui.Name = "OffresCaravane"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.Enabled = false
gui.Parent = playerGui

local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = ink
shade.BackgroundTransparency = 0.32
shade.BorderSizePixel = 0
shade.Active = true
shade.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(1, -42, 1, -38)
card.BackgroundColor3 = ink
card.Parent = shade
corner(card, 13)
local bounds = Instance.new("UISizeConstraint")
bounds.MaxSize = Vector2.new(520, 432)
bounds.Parent = card
local rule = Instance.new("UIStroke")
rule.Color = Color3.fromRGB(115, 139, 122)
rule.Parent = card

local heading = text(card, "La Caravane", UDim2.fromOffset(18, 9), UDim2.new(1, -90, 0, 34), 25, paper)
heading.Font = Enum.Font.GothamBold
local till = text(card, "", UDim2.fromOffset(18, 47), UDim2.new(1, -36, 0, 24), 14, gold)
local close = text(card, "×", UDim2.new(1, -53, 0, 12), UDim2.fromOffset(37, 35), 22, paper, true)
close.Modal = true

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(16, 81)
list.Size = UDim2.new(1, -32, 1, -154)
list.BackgroundTransparency = 1
list.CanvasSize = UDim2.fromScale(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = gold
list.BorderSizePixel = 0
list.Parent = card
local stack = Instance.new("UIListLayout")
stack.Padding = UDim.new(0, 8)
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Parent = list

local rows = {}
local empty = text(list, "Tout le stock a été vendu.", UDim2.fromOffset(0, 0), UDim2.new(1, -12, 0, 58), 14, mint)
for i = 1, 3 do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 80)
	row.LayoutOrder = i
	row.BackgroundColor3 = Color3.fromRGB(29, 53, 54)
	row.Parent = list
	corner(row, 8)
	local name = text(row, "", UDim2.fromOffset(11, 5), UDim2.new(1, -108, 0, 23), 15, paper)
	name.Font = Enum.Font.GothamBold
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local description = text(row, "", UDim2.fromOffset(11, 31), UDim2.new(1, -108, 0, 43), 12, mint)
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	local buy = text(row, "", UDim2.new(1, -88, 0.5, -17), UDim2.fromOffset(77, 35), 13, gold, true)
	buy.Activated:Connect(function()
		local id = session:GetAttribute("Offer" .. i)
		local offer = Service.offers[id]
		if offer and offer.price <= (session:GetAttribute("Cash") or 0) and not session:GetAttribute("Bought_" .. id) then
			remote:FireServer("buy", id)
		end
	end)
	rows[i] = { row = row, name = name, description = description, buy = buy }
end

local feedback = text(card, "", UDim2.new(0, 18, 1, -66), UDim2.new(1, -36, 0, 25), 12, mint)
feedback.TextTruncate = Enum.TextTruncate.AtEnd
local reroll = text(card, "Changer les offres · 25 $", UDim2.new(0, 16, 1, -40), UDim2.fromOffset(190, 30), 13, paper, true)
reroll.Activated:Connect(function()
	if not session:GetAttribute("Rerolled") and (session:GetAttribute("Cash") or 0) >= Service.rerollCost then
		remote:FireServer("reroll")
	end
end)

local function closeMarket()
	if not gui.Enabled then return end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
	gui.Enabled = false
	playerGui:SetAttribute("CaravaneOpen", false)
	ContextActionService:UnbindAction("GarageFermerCaravane")
end
close.Activated:Connect(closeMarket)
player.CharacterRemoving:Connect(closeMarket)

local function refresh()
	if not gui.Enabled then return end
	if session:GetAttribute("Phase") ~= "vendor" then closeMarket() return end
	local cash = session:GetAttribute("Cash") or 0
	till.Text = string.format("Jour %d · Disponible %d $", session:GetAttribute("Day") or 0, cash)
	local offers = 0
	for i, row in rows do
		local id = session:GetAttribute("Offer" .. i)
		local offer = Service.offers[id]
		row.row.Visible = offer ~= nil
		if offer then
			offers += 1
			local sold = session:GetAttribute("Bought_" .. id)
			row.name.Text = offer.name
			row.description.Text = offer.description
			row.buy.Text = if sold then "Acheté" else string.format("%d $", offer.price)
			local available = not sold and cash >= offer.price
			row.buy.AutoButtonColor = available
			row.buy.TextColor3 = if available then gold else mint
		end
	end
	empty.Visible = offers == 0
	local changed = session:GetAttribute("Rerolled")
	reroll.Text = if changed then "Offres renouvelées" else "Changer les offres · 25 $"
	reroll.AutoButtonColor = not changed and cash >= Service.rerollCost
	reroll.TextColor3 = if reroll.AutoButtonColor then paper else mint
end
session.AttributeChanged:Connect(refresh)

remote.OnClientEvent:Connect(function(action, success, message)
	if action == "open" then
		if session:GetAttribute("Phase") ~= "vendor" then return end
		feedback.Text = ""
		gui.Enabled = true
		playerGui:SetAttribute("CaravaneOpen", true)
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then GuiService.SelectedObject = close end
		ContextActionService:BindActionAtPriority("GarageFermerCaravane", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then closeMarket() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.ButtonB)
		refresh()
	elseif action == "result" then
		feedback.TextColor3 = if success then mint else gold
		feedback.Text = message
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(0.35)
		if gui.Enabled then
			local room = workspace:FindFirstChild("Le Petit Atelier")
			local vendor = room and room:FindFirstChild("La Caravane")
			local point = vendor and vendor:FindFirstChild("Comptoir")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not point or not root or (point.Position - root.Position).Magnitude > 7.15 then closeMarket() end
		end
	end
end)

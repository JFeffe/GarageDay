local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Preferences = require(ReplicatedStorage:WaitForChild("GarageDay"):WaitForChild("Preferences"))
local value = Preferences.defaultSensitivity
UserInputService.MouseDeltaSensitivity = value / 100
local session = ReplicatedStorage:WaitForChild("GarageDaySession")
local remote = session:WaitForChild("OptionsControl")

local ink = Color3.fromRGB(21, 38, 40)
local teal = Color3.fromRGB(43, 72, 72)
local cream = Color3.fromRGB(249, 235, 207)
local gold = Color3.fromRGB(238, 184, 104)
local mint = Color3.fromRGB(180, 222, 195)

local function round(element, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = element
end

local function text(parent, name, message, position, size, textSize, button)
	local element = Instance.new(if button then "TextButton" else "TextLabel")
	element.Name = name
	element.Text = message
	element.Position, element.Size = position, size
	element.Font = if button then Enum.Font.GothamBold else Enum.Font.GothamMedium
	element.TextSize, element.TextColor3 = textSize, cream
	element.BackgroundTransparency = if button then 0 else 1
	element.BackgroundColor3 = teal
	element.BorderSizePixel = 0
	if button then round(element, 7) else element.TextXAlignment = Enum.TextXAlignment.Left end
	element.Parent = parent
	return element
end

local gui = Instance.new("ScreenGui")
gui.Name = "OptionsGarageDay"
gui.ResetOnSpawn = false
gui.DisplayOrder = 11
gui.Parent = playerGui

local openButton = text(gui, "Ouvrir", "Options  ·  O", UDim2.fromOffset(13, 10), UDim2.fromOffset(104, 31), 13, true)
local backdrop = Instance.new("Frame")
backdrop.Name = "Menu"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3, backdrop.BackgroundTransparency = ink, 0.30
backdrop.Active, backdrop.Visible = true, false
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint, card.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(1, -36, 0, 246)
card.BackgroundColor3 = ink
card.Parent = backdrop
round(card, 12)
local size = Instance.new("UISizeConstraint")
size.MaxSize = Vector2.new(452, 246)
size.Parent = card
local edge = Instance.new("UIStroke")
edge.Color = Color3.fromRGB(115, 139, 122)
edge.Parent = card

local title = text(card, "Titre", "Options", UDim2.fromOffset(18, 12), UDim2.new(1, -75, 0, 34), 25)
title.Font = Enum.Font.GothamBold
local close = text(card, "Fermer", "×", UDim2.new(1, -51, 0, 13), UDim2.fromOffset(34, 34), 22, true)
close.Modal = true
text(card, "Libellé", "Sensibilité de la souris", UDim2.fromOffset(18, 64), UDim2.new(1, -92, 0, 24), 15)
local reading = text(card, "Valeur", "", UDim2.new(1, -86, 0, 64), UDim2.fromOffset(68, 24), 15)
reading.TextColor3, reading.TextXAlignment = gold, Enum.TextXAlignment.Right
local less = text(card, "Diminuer", "−", UDim2.fromOffset(18, 102), UDim2.fromOffset(36, 33), 20, true)
local more = text(card, "Augmenter", "+", UDim2.new(1, -54, 0, 102), UDim2.fromOffset(36, 33), 20, true)
local slider = text(card, "Curseur", "", UDim2.fromOffset(66, 102), UDim2.new(1, -132, 0, 33), 14, true)
slider.BackgroundTransparency, slider.AutoButtonColor, slider.Selectable = 1, false, false
local rail = Instance.new("Frame")
rail.AnchorPoint, rail.Position = Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5)
rail.Size, rail.BackgroundColor3 = UDim2.new(1, 0, 0, 6), teal
rail.Parent = slider
round(rail, 3)
local fill = Instance.new("Frame")
fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent = gold, 0, rail
round(fill, 3)
local knob = Instance.new("Frame")
knob.AnchorPoint, knob.Size = Vector2.new(0.5, 0.5), UDim2.fromOffset(16, 16)
knob.BackgroundColor3, knob.Parent = cream, rail
round(knob, 8)
local reset = text(card, "Réinitialiser", "Valeur par défaut", UDim2.fromOffset(18, 150), UDim2.fromOffset(151, 31), 13, true)
local saveLabel = text(card, "Sauvegarde", "", UDim2.fromOffset(18, 192), UDim2.new(1, -36, 0, 37), 12)
saveLabel.TextWrapped, saveLabel.TextColor3 = true, mint

local pointer
local function apply(newValue)
	value = newValue
	UserInputService.MouseDeltaSensitivity = newValue / 100
	reading.Text = string.format("%d %%", value)
	local fraction = (value - Preferences.minSensitivity) / (Preferences.maxSensitivity - Preferences.minSensitivity)
	fill.Size = UDim2.fromScale(fraction, 1)
	knob.Position = UDim2.fromScale(fraction, 0.5)
end

local function commit()
	if player:GetAttribute("SensitivityReady") then remote:FireServer(value) end
end

local function setValue(proposed)
	if not player:GetAttribute("SensitivityReady") then return end
	apply(Preferences.sensitivity(proposed) or Preferences.defaultSensitivity)
	commit()
end

local function selectAt(x)
	local fraction = math.clamp((x - slider.AbsolutePosition.X) / math.max(1, slider.AbsoluteSize.X), 0, 1)
	local newValue = Preferences.minSensitivity + fraction * (Preferences.maxSensitivity - Preferences.minSensitivity)
	apply(Preferences.sensitivity(newValue))
end

slider.InputBegan:Connect(function(input)
	if not player:GetAttribute("SensitivityReady") then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pointer = input
		selectAt(input.Position.X)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if pointer and (input == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
		selectAt(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == pointer then pointer = nil commit() end
end)
less.Activated:Connect(function() setValue(value - Preferences.step) end)
more.Activated:Connect(function() setValue(value + Preferences.step) end)
reset.Activated:Connect(function() setValue(Preferences.defaultSensitivity) end)

local function syncSetting()
	if not pointer then apply(player:GetAttribute("MouseSensitivity") or Preferences.defaultSensitivity) end
end
player:GetAttributeChangedSignal("MouseSensitivity"):Connect(syncSetting)
syncSetting()

local saveMessages = {
	loading = "Chargement de la sauvegarde…", ready = "Sauvegarde automatique activée",
	saving = "Sauvegarde en cours…", saved = "Progression sauvegardée",
	retry = "Sauvegarde en attente. Nouvelle tentative automatique.",
	conflict = "Une autre session a sauvegardé cet atelier. Reviens pour le recharger.",
	unsupported = "Cette sauvegarde est illisible dans cette version.",
	unavailable = "Sauvegarde indisponible pour cette partie.",
}

local function updateStatus()
	local message = saveMessages[session:GetAttribute("SaveState")]
	local owner = session:GetAttribute("SaveOwner")
	if owner and owner ~= player.DisplayName and message then message = message .. " · Atelier de " .. owner end
	saveLabel.Text = message or ""
end
session:GetAttributeChangedSignal("SaveState"):Connect(updateStatus)
session:GetAttributeChangedSignal("SaveOwner"):Connect(updateStatus)
updateStatus()

local priority = Enum.ContextActionPriority.High.Value + 2
local function setOpen(open)
	if open and (playerGui:GetAttribute("CaravaneOpen") or session:GetAttribute("Driver") == player.UserId) then return end
	if backdrop.Visible == open then return end
	backdrop.Visible, openButton.Visible = open, not open
	playerGui:SetAttribute("WorkshopOptionsOpen", open)
	if open then
		ContextActionService:BindActionAtPriority("GarageOptionsModal", function(_, inputState, input)
			if inputState == Enum.UserInputState.Begin and input.KeyCode == Enum.KeyCode.ButtonB then setOpen(false) end
			return Enum.ContextActionResult.Sink
		end, false, priority, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up,
			Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.F,
			Enum.KeyCode.R, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonB)
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then GuiService.SelectedObject = less end
	else
		ContextActionService:UnbindAction("GarageOptionsModal")
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(backdrop) then GuiService.SelectedObject = nil end
		if pointer then pointer = nil commit() end
	end
end
close.Activated:Connect(function() setOpen(false) end)
openButton.Activated:Connect(function() setOpen(true) end)
player.CharacterRemoving:Connect(function() setOpen(false) end)
playerGui:GetAttributeChangedSignal("CaravaneOpen"):Connect(function()
	if playerGui:GetAttribute("CaravaneOpen") then setOpen(false) end
end)
session:GetAttributeChangedSignal("Driver"):Connect(function()
	local driving = session:GetAttribute("Driver") == player.UserId
	if driving then setOpen(false) end
	openButton.Visible = not driving and not backdrop.Visible
end)
ContextActionService:BindActionAtPriority("GarageOptions", function(_, inputState)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then setOpen(not backdrop.Visible) end
	return Enum.ContextActionResult.Sink
end, false, priority, Enum.KeyCode.O)
local function inputLabel()
	openButton.Text = if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then "Options  ·  O" else "Options"
end
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(inputLabel)
inputLabel()

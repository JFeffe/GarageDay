local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local session = ReplicatedStorage:WaitForChild("GarageDaySession")
local control = session:WaitForChild("LaunchControl")
local Service = require(ReplicatedStorage.GarageDay.Service)
local cream = Color3.fromRGB(250, 238, 209)
local ink = Color3.fromRGB(22, 42, 40)
local cardColor = Color3.fromRGB(39, 63, 58)
local border = Color3.fromRGB(90, 118, 103)
local gold = Color3.fromRGB(239, 192, 119)
local mint = Color3.fromRGB(176, 209, 189)

local screen = Instance.new("ScreenGui")
screen.Name = "AccueilGarageDay"
screen.ResetOnSpawn = false
screen.DisplayOrder = 16
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local playerGui = player:WaitForChild("PlayerGui")
screen.Parent = playerGui

local backdrop = Instance.new("ScreenGui")
backdrop.Name = "FondAccueilGarageDay"
backdrop.ResetOnSpawn = false
backdrop.DisplayOrder = 15
backdrop.ScreenInsets = Enum.ScreenInsets.None
backdrop.Parent = playerGui

local function rectangle(parent, color, radius)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	if radius then
		local rounded = Instance.new("UICorner")
		rounded.CornerRadius = UDim.new(0, radius)
		rounded.Parent = frame
	end
	return frame
end

local function text(parent, value, size, color, bold)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextColor3 = color
	label.Text = value
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function outlined(parent, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.23
	stroke.Parent = parent
end

local function button(parent, name, value, accent, command)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Text = value
	item.Font = Enum.Font.GothamBold
	item.TextSize = 15
	item.TextColor3 = if accent then ink else cream
	item.BackgroundColor3 = if accent then gold else ink
	item.BorderSizePixel = 0
	item.SelectionOrder = 1
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = item
	if not accent then outlined(item, border) end
	item.Activated:Connect(command)
	return item
end

local background = rectangle(backdrop, Color3.new(1, 1, 1))
background.Size = UDim2.fromScale(1, 1)
local gradient = Instance.new("UIGradient")
gradient.Rotation = 108
gradient.Color = ColorSequence.new(Color3.fromRGB(35, 68, 62), Color3.fromRGB(18, 32, 35))
gradient.Parent = background

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Choix de l’atelier"
scroll.AnchorPoint = Vector2.new(0.5, 0.5)
scroll.Position = UDim2.fromScale(0.5, 0.5)
scroll.Size = UDim2.new(1, -38, 1, -28)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = mint
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Parent = screen
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(920, 680)
limit.Parent = scroll

local content = rectangle(scroll, ink)
content.BackgroundTransparency = 1
content.Size = UDim2.new(1, -8, 0, 0)
content.AutomaticSize = Enum.AutomaticSize.Y
local stack = Instance.new("UIListLayout")
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Padding = UDim.new(0, 16)
stack.Parent = content
local inset = Instance.new("UIPadding")
inset.PaddingTop, inset.PaddingBottom = UDim.new(0, 15), UDim.new(0, 16)
inset.Parent = content

local heading = rectangle(content, ink)
heading.BackgroundTransparency = 1
heading.LayoutOrder = 1
heading.Size = UDim2.new(1, 0, 0, 100)
local brand = text(heading, "Garage Day", 55, cream, true)
brand.Size = UDim2.new(1, -4, 0, 67)
local intro = text(heading, "Choisis un atelier", 19, mint)
intro.Position = UDim2.fromOffset(1, 69)
intro.Size = UDim2.new(1, -4, 0, 28)

local cards = rectangle(content, ink)
cards.BackgroundTransparency = 1
cards.LayoutOrder = 2
cards.Size = UDim2.new(1, 0, 0, 344)
local row = Instance.new("UIListLayout")
row.FillDirection = Enum.FillDirection.Horizontal
row.SortOrder = Enum.SortOrder.LayoutOrder
row.Padding = UDim.new(0, 14)
row.Parent = cards

local function mapPreview(parent, bayCount)
	local view = Instance.new("ViewportFrame")
	view.Name = "Aperçu de l’atelier"
	view.Position = UDim2.fromOffset(12, 12)
	view.Size = UDim2.new(1, -24, 0, 157)
	view.BorderSizePixel = 0
	view.BackgroundColor3 = Color3.fromRGB(51, 83, 77)
	view.Ambient = Color3.fromRGB(182, 190, 177)
	view.LightColor = Color3.fromRGB(255, 226, 180)
	view.LightDirection = Vector3.new(-1, -2, -1)
	view.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = view
	local model = Instance.new("WorldModel")
	model.Parent = view
	local function block(size, position, color)
		local part = Instance.new("Part")
		part.Size, part.Position, part.Color = size, position, color
		part.Anchored, part.CastShadow = true, false
		part.Parent = model
		return part
	end
	local width = if bayCount == 1 then 15 else 22
	local teal = Color3.fromRGB(70, 119, 110)
	local roof = Color3.fromRGB(40, 68, 68)
	local wall = Color3.fromRGB(228, 213, 181)
	block(Vector3.new(width + 5, 0.4, 15), Vector3.new(0, -0.2, 1.5), Color3.fromRGB(144, 156, 139))
	block(Vector3.new(width, 5, 9), Vector3.new(0, 2.5, -1), wall)
	block(Vector3.new(width + 0.5, 0.48, 9.5), Vector3.new(0, 5.17, -1), roof)
	block(Vector3.new(width, 0.29, 0.18), Vector3.new(0, 4.78, 3.56), gold)
	block(Vector3.new(width, 0.86, 0.21), Vector3.new(0, 0.49, 3.58), teal)
	local entry = -width / 2 + 2.65
	block(Vector3.new(2.2, 3.31, 0.16), Vector3.new(entry, 1.65, 3.69), roof)
	block(Vector3.new(1.46, 2.07, 0.18), Vector3.new(entry, 2.05, 3.79), Color3.fromRGB(137, 181, 181))
	block(Vector3.new(3.45, 0.27, 1.77), Vector3.new(entry, 3.88, 4.07), roof)
	for i = 1, bayCount do
		local x = width / 2 - 4.45 - (i - 1) * 6.4
		block(Vector3.new(4.9, 3.89, 0.18), Vector3.new(x, 1.95, 3.7), roof)
		for stripe = 1, 9 do
			block(Vector3.new(4.66, 0.31, 0.21), Vector3.new(x, stripe * 0.40 + 0.03, 3.83), teal)
		end
		block(Vector3.new(3.9, 0.025, 3.12), Vector3.new(x, 0.015, 6.07), Color3.fromRGB(112, 132, 123))
		for _, side in {-1, 1} do
			block(Vector3.new(0.10, 0.03, 3.14), Vector3.new(x + side * 1.92, 0.042, 6.07), gold)
		end
	end
	for x = -2, 2 do
		block(Vector3.new(0.34, 0.032, 1.95), Vector3.new(entry + x * 0.55, 0.035, 5.67), cream)
	end
	for _, x in {-width / 2 - 1.34, width / 2 + 1.34} do
		block(Vector3.new(0.98, 0.66, 1.37), Vector3.new(x, 0.33, 5), Color3.fromRGB(151, 110, 71))
		local foliage = block(Vector3.new(1.12, 1.35, 1.13), Vector3.new(x, 1.30, 5), Color3.fromRGB(124, 164, 107))
		foliage.Shape = Enum.PartType.Ball
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(Vector3.new(width * 0.56, 12, width * 0.63 + 15), Vector3.new(0, 1.65, 1))
	camera.Parent = view
	view.CurrentCamera = camera
end

local footer = rectangle(content, ink)
footer.BackgroundTransparency = 1
footer.LayoutOrder = 3
footer.Size = UDim2.new(1, 0, 0, 47)
local notice = text(footer, "", 15, mint)
notice.Size = UDim2.new(1, 0, 1, 0)

local function footerButton(name, label, action)
	local result = button(footer, name, label, false, function() control:FireServer(action) end)
	result.AnchorPoint = Vector2.new(1, 0)
	result.Position = UDim2.fromScale(1, 0)
	result.Size = UDim2.fromOffset(180, 40)
	return result
end
local back = footerButton("Retour", "Retour à l’atelier", "back")
local retry = footerButton("Reessayer", "Réessayer", "retry")

local veil = rectangle(screen, Color3.fromRGB(11, 20, 19))
veil.Size = UDim2.fromScale(1, 1)
veil.BackgroundTransparency = 0.24
veil.Active = true
veil.Visible = false
veil.ZIndex = 2
local dialog = rectangle(veil, cardColor, 13)
dialog.AnchorPoint = Vector2.new(0.5, 0.5)
dialog.Position = UDim2.fromScale(0.5, 0.5)
dialog.Size = UDim2.new(1, -38, 0, 211)
outlined(dialog, border)
local dialogLimit = Instance.new("UISizeConstraint")
dialogLimit.MaxSize = Vector2.new(430, 211)
dialogLimit.Parent = dialog
local dialogTitle = text(dialog, "Recommencer cette carte ?", 23, cream, true)
dialogTitle.Position = UDim2.fromOffset(19, 16)
dialogTitle.Size = UDim2.new(1, -38, 0, 59)
local warning = text(dialog, "", 15, mint)
warning.Position = UDim2.fromOffset(19, 78)
warning.Size = UDim2.new(1, -38, 0, 56)

local choices = {
	{ id = "PetitAtelier", name = "Le Petit Atelier", bays = 1 },
	{ id = "Tandem", name = "Le Tandem", bays = 2 },
}
local entries = {}
local confirmedChoice
local refresh
local cancel = button(dialog, "Annuler", "Annuler", false, function()
	confirmedChoice = nil
	refresh()
end)
cancel.Position = UDim2.new(0, 18, 1, -63)
cancel.Size = UDim2.new(0.45, -12, 0, 43)
local replace = button(dialog, "ConfirmerNouvelle", "Recommencer", true, function()
	if confirmedChoice then
		control:FireServer("new", confirmedChoice.id, true)
		confirmedChoice = nil
		refresh()
	end
end)
replace.AnchorPoint = Vector2.new(1, 0)
replace.Position = UDim2.new(1, -18, 1, -63)
replace.Size = UDim2.new(0.55, -33, 0, 43)

for index, choice in choices do
	local card = rectangle(cards, cardColor, 12)
	card.Name = choice.id
	card.LayoutOrder = index
	outlined(card, border)
	mapPreview(card, choice.bays)
	local name = text(card, choice.name, 25, cream, true)
	name.Position = UDim2.fromOffset(17, 176)
	name.Size = UDim2.new(1, -34, 0, 32)
	local details = text(card, if choice.bays == 1 then "1 baie de réparation" else "2 baies de réparation", 14, mint)
	details.Position = UDim2.fromOffset(18, 208)
	details.Size = UDim2.new(1, -36, 0, 23)
	local progress = text(card, "", 15, cream, true)
	progress.Position = UDim2.fromOffset(18, 238)
	progress.Size = UDim2.new(1, -36, 0, 23)
	local resume = button(card, "Continuer", "Continuer", true, function()
		control:FireServer("continue", choice.id)
	end)
	resume.Position = UDim2.new(0, 17, 1, -60)
	resume.Size = UDim2.new(0.43, -20, 0, 43)
	local start = button(card, "NouvellePartie", "Nouvelle partie", true, function()
		if session:GetAttribute("LaunchStatus") ~= "ready" then
			control:FireServer("trial", choice.id)
		elseif session:GetAttribute(choice.id .. "Day") ~= nil then
			confirmedChoice = choice
			refresh()
		else
			control:FireServer("new", choice.id)
		end
	end)
	entries[index] = { choice = choice, card = card, progress = progress, resume = resume, start = start }
end

local mobile = false
local function resize()
	mobile = scroll.AbsoluteSize.X < 620
	local height = 340
	for _, entry in entries do
		entry.card.Size = UDim2.new(if mobile then 1 else 0.5, if mobile then 0 else -7, 0, height)
	end
	row.FillDirection = if mobile then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	cards.Size = UDim2.new(1, 0, 0, if mobile then height * 2 + 14 else height)
	brand.TextSize = if mobile then 42 else 55
end

local menuOpen
local promptsEnabled
local function setOpen(open)
	if menuOpen == open then return end
	menuOpen = open
	screen.Enabled = open
	backdrop.Enabled = open
	local camera = workspace.CurrentCamera
	if open then
		promptsEnabled = ProximityPromptService.Enabled
		ProximityPromptService.Enabled = false
		player.CameraMode = Enum.CameraMode.Classic
		if camera then camera.CameraType = Enum.CameraType.Scriptable end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		ContextActionService:BindActionAtPriority("GarageLaunchMovement", function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 1,
			Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward, Enum.PlayerActions.CharacterLeft,
			Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump, Enum.KeyCode.Thumbstick1)
	else
		if promptsEnabled ~= nil then ProximityPromptService.Enabled = promptsEnabled end
		ContextActionService:UnbindAction("GarageLaunchMovement")
		if camera then camera.CameraType = Enum.CameraType.Custom end
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		confirmedChoice = nil
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(screen) then GuiService.SelectedObject = nil end
	end
end

refresh = function()
	local mode = session:GetAttribute("LaunchMode")
	local open = mode ~= "playing"
	setOpen(open)
	if not open then return end
	local status = session:GetAttribute("LaunchStatus")
	local owner = session:GetAttribute("LaunchOwnerId")
	local canChoose = owner == player.UserId and mode == "menu" and status ~= "loading"
	local ready = status == "ready"
	local waiting = owner ~= nil and owner ~= player.UserId
	if not canChoose or not ready then confirmedChoice = nil end
	veil.Visible = confirmedChoice ~= nil
	if confirmedChoice then warning.Text = "Ta partie sur la carte " .. confirmedChoice.name .. " sera remplacée." end
	back.Visible = owner == player.UserId and mode == "menu" and session:GetAttribute("LaunchReturn") == true
	retry.Visible = canChoose and not ready
	retry.Position = UDim2.new(1, 0, 0, if back.Visible then 48 else 0)
	footer.Size = UDim2.new(1, 0, 0, if back.Visible and retry.Visible then 93 else 47)
	notice.Size = UDim2.new(1, if back.Visible or retry.Visible then -196 else 0, 1, 0)
	notice.Text = if mode == "starting" then "Préparation de l’atelier…"
		elseif waiting then "En attente du choix de " .. (session:GetAttribute("SaveOwner") or "l’hôte") .. "…"
		elseif status == "loading" then "Chargement des sauvegardes…"
		elseif not ready then "Sauvegarde indisponible. Un essai temporaire est possible." else ""
	footer.Visible = notice.Text ~= "" or back.Visible or retry.Visible
	local firstButton
	for _, entry in entries do
		local id, start, resume = entry.choice.id, entry.start, entry.resume
		local day = session:GetAttribute(id .. "Day")
		local cash = session:GetAttribute(id .. "Cash") or 0
		local complete = session:GetAttribute(id .. "Complete")
		resume.Visible = canChoose and ready and day ~= nil
		resume.Text = if complete then "Voir le bilan" else "Continuer"
		start.Visible = canChoose
		start.Text = if ready then "Nouvelle partie" else "Essai temporaire"
		start.AnchorPoint = Vector2.new(1, 0)
		start.Position = UDim2.new(1, -17, 1, -60)
		start.Size = UDim2.new(if resume.Visible then 0.57 else 1, if resume.Visible then -21 else -34, 0, 43)
		start.BackgroundColor3 = if resume.Visible then ink else gold
		start.TextColor3 = if resume.Visible then cream else ink
		entry.progress.Text = if not ready or waiting then ""
			elseif day == nil then "Aucune sauvegarde"
			elseif day == 0 then string.format("Avant le jour 1 · %d $", cash)
			elseif complete then string.format("Campagne terminée · %d $", cash)
			else string.format("Jour %d/%d · %d $", day, Service.lastDay, cash)
		if canChoose then firstButton = firstButton or (if resume.Visible then resume else start) end
	end
	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		local selected = GuiService.SelectedObject
		if veil.Visible then
			if selected ~= cancel and selected ~= replace then GuiService.SelectedObject = cancel end
		elseif not selected or not selected.Visible or selected:IsDescendantOf(veil) then
			GuiService.SelectedObject = firstButton
		end
	end
end

scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
session.AttributeChanged:Connect(refresh)
resize()
refresh()

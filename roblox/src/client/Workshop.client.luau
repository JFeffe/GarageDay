local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local modules = ReplicatedStorage:WaitForChild("GarageDay")
local Repair = require(modules:WaitForChild("Repair"))
local Service = require(modules:WaitForChild("Service"))
local playerGui = player:WaitForChild("PlayerGui")
player.CameraMode = Enum.CameraMode.LockFirstPerson
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

local cream = Color3.fromRGB(255, 239, 210)
local mint = Color3.fromRGB(161, 212, 197)
local gold = Color3.fromRGB(249, 200, 113)
local ink = Color3.fromRGB(19, 37, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "GarageDay"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -14, 0, 10)
panel.Size = UDim2.fromScale(0.46, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = ink
panel.BackgroundTransparency = 0.08
panel.Parent = gui

local bounds = Instance.new("UISizeConstraint")
bounds.MinSize = Vector2.new(224, 0)
bounds.MaxSize = Vector2.new(318, 1000)
bounds.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(75, 114, 113)
outline.Transparency = 0.4
outline.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 11)
pad.PaddingBottom = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.Parent = panel
local stack = Instance.new("UIListLayout")
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Padding = UDim.new(0, 5)
stack.Parent = panel

local function label(order, text, size, color, bold)
	local item = Instance.new("TextLabel")
	item.LayoutOrder = order
	item.Size = UDim2.fromScale(1, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.BackgroundTransparency = 1
	item.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	item.TextColor3 = color
	item.TextSize = size
	item.Text = text
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = panel
	return item
end

label(1, "LE PETIT ATELIER", 12, mint, true)
local ledger = label(2, "Atelier libre", 13, mint, false)
local orderLine = label(3, "", 13, mint, false)
local action = label(4, "Préparation du garage…", 19, cream, true)
local hint = label(5, "", 13, cream, false)
local held = label(7, "", 12, mint, false)

local rail = Instance.new("Frame")
rail.LayoutOrder = 6
rail.Size = UDim2.new(1, 0, 0, 3)
rail.BackgroundColor3 = Color3.fromRGB(58, 82, 84)
rail.BorderSizePixel = 0
rail.Parent = panel
local progress = Instance.new("Frame")
progress.Size = UDim2.fromScale(0, 1)
progress.BackgroundColor3 = gold
progress.BorderSizePixel = 0
progress.Parent = rail

local reticleGui = Instance.new("ScreenGui")
reticleGui.Name = "ViseurGarageDay"
reticleGui.ResetOnSpawn = false
reticleGui.ScreenInsets = Enum.ScreenInsets.None
reticleGui.Parent = playerGui
local reticle = Instance.new("Frame")
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(5, 5)
reticle.BackgroundColor3 = cream
reticle.BorderSizePixel = 0
reticle.Parent = reticleGui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(1, 0)
round.Parent = reticle
local edge = Instance.new("UIStroke")
edge.Color = ink
edge.Parent = reticle

local session = ReplicatedStorage:WaitForChild("GarageDaySession")
local phases = {
	free = {"Ouvrir le service", "Utilise le téléphone dans le bureau."},
	arrival = {"Le client arrive", "Retrouve-le au comptoir d’accueil."},
	reception = {"Accueillir le client", "Rends-toi au comptoir marqué ACCUEIL."},
	intake = {"Rentrer la berline", "Prends le volant en A 01 et entre par le rideau ouvert."},
	outbound = {"Sortir la berline", "Prends le volant et rejoins la place P 01 par la sortie."},
	checkout = {"Le client rejoint la caisse", "Rends-toi au comptoir marqué CAISSE."},
	payment = {"Encaisser la réparation", "Encaisse le client à la caisse."},
	departing = {"Le client récupère sa voiture", "Laisse le passage libre pendant son départ."},
	done = {"Service terminé", "Utilise le téléphone pour ouvrir la journée suivante."},
}

local function refresh()
	local phase = session:GetAttribute("Phase") or "free"
	local day = session:GetAttribute("Day") or 0
	local cash = session:GetAttribute("Cash") or 0
	local served = session:GetAttribute("Served") or 0
	local ticket = Service.orders[session:GetAttribute("Ticket") or 1]
	local job = Repair.jobs[session:GetAttribute("Job") or ticket.job]
	local index = session:GetAttribute("Step") or 1
	local step = job.steps[index]
	local toolOwner = session:GetAttribute("ToolOwner") or 0
	local padsOwner = session:GetAttribute("PadsOwner") or 0
	local ownTool = toolOwner == player.UserId
	local ownPads = padsOwner == player.UserId
	local rider = session:GetAttribute("Driver") or 0
	local driving = rider == player.UserId
	local input = UserInputService.PreferredInput
	reticleGui.Enabled = not driving and input ~= Enum.PreferredInput.Touch
	ledger.Text = if day == 0 then "Atelier libre" else `Jour {day}  ·  {served}/{#Service.orders} clients  ·  {cash} $`
	orderLine.Visible = phase ~= "free" and phase ~= "done"
	orderLine.Text = ticket.name .. " · " .. job.name
	action.TextColor3 = if phase == "done" then mint else cream
	local description = phases[phase] or phases.free
	action.Text, hint.Text = description[1], description[2]
	local drivingControls = if input == Enum.PreferredInput.Touch then "Commandes tactiles" elseif input == Enum.PreferredInput.Gamepad then
		"Stick gauche conduire  ·  X valider  ·  B descendre" else "W/S accélérer et reculer  ·  A/D braquer  ·  E valider"
	if driving then
		action.Text = if phase == "intake" then "Baie 01" else "Stationnement P 01"
		action.TextColor3 = if session:GetAttribute("ParkingReady") then mint else cream
		hint.Text = session:GetAttribute("ParkingHint") or ""
	elseif rider ~= 0 then
		hint.Text = "Ton collègue est au volant. Laisse le passage libre."
	elseif phase == "repair" and step then
		action.Text = step.title
		if session:GetAttribute("LiftMoving") then
			action.Text = if step.action == "raise" then "Le pont monte" else "Le pont descend"
			hint.Text = if step.action == "raise" then "Prépare les outils pendant la montée." else "Attends l’arrêt du pont."
		elseif step.item == "tool" and not ownTool then
			hint.Text = if toolOwner ~= 0 then "Ton collègue a l’outil." else `Prends l’outil « {job.tool} » sur le meuble à droite du pont.`
		elseif step.item == "pads" and not ownPads then
			hint.Text = if padsOwner ~= 0 then "Ton collègue a les plaquettes." else "Prends les plaquettes à l’étagère des pièces châssis."
		else
			hint.Text = if step.target == "Lever" then "Vise le levier jaune." else "Approche-toi de la roue indiquée."
		end
	elseif phase == "done" then
		orderLine.Visible = true
		orderLine.Text = `Recette du jour · {session:GetAttribute("DailyCash") or 0} $`
	end
	local items = {}
	if ownTool then table.insert(items, job.tool) end
	if ownPads then table.insert(items, "Plaquettes") end
	held.Text = if driving then drivingControls elseif #items > 0 then "En main · " .. table.concat(items, " + ") else "Mains libres"
	local amount = if phase == "repair" then (index - 1) / #job.steps else served / #Service.orders
	progress.Size = UDim2.fromScale(math.clamp(amount, 0, 1), 1)
end
session.AttributeChanged:Connect(refresh)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
refresh()

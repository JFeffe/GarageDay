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

local cream = Color3.fromRGB(255, 241, 214)
local mint = Color3.fromRGB(172, 218, 194)
local gold = Color3.fromRGB(240, 189, 110)
local ink = Color3.fromRGB(21, 38, 40)

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
panel.BackgroundTransparency = 0.035
panel.Parent = gui

local bounds = Instance.new("UISizeConstraint")
bounds.MinSize = Vector2.new(224, 0)
bounds.MaxSize = Vector2.new(318, 1000)
bounds.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(124, 150, 134)
outline.Transparency = 0.42
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

label(1, "LE PETIT ATELIER", 12, gold, true)
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
local motionHelp = {
	raise = { "Le pont monte", "Tu peux préparer le matériel pendant la montée." },
	lower = { "Le pont descend", "Attends l’arrêt du pont." },
	openHood = { "Le capot s’ouvre", "Laisse l’avant du véhicule dégagé." },
	closeHood = { "Le capot se referme", "Attends la fermeture." },
}
local targetHelp = {
	Lever = "Vise le levier jaune.", Hood = "Place-toi devant le véhicule.", BatteryTray = "Vise le plateau de batterie sous le capot.",
	OilCap = "Vise le bouchon jaune sur le moteur.", WasteOil = "Approche-toi du récupérateur à côté des établis.",
	Recycling = "Dépose la pièce au bac marqué RECYCLAGE.",
}
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
	local plan = Service.plan(day)
	local ticket = plan[math.clamp(session:GetAttribute("Ticket") or 1, 1, #plan)]
	local job = Repair.jobs[session:GetAttribute("Job") or ticket.job]
	local index = session:GetAttribute("Step") or 1
	local step = job.steps[index]
	local toolOwner = session:GetAttribute("ToolOwner") or 0
	local ownTool = toolOwner == player.UserId
	local rider = session:GetAttribute("Driver") or 0
	local driving = rider == player.UserId
	local input = UserInputService.PreferredInput
	reticleGui.Enabled = not driving and input ~= Enum.PreferredInput.Touch
	ledger.Text = if day == 0 then "Atelier libre" else `Jour {day}  ·  {served}/{#plan} clients  ·  {cash} $`
	orderLine.Visible = phase ~= "free" and phase ~= "done"
	orderLine.Text = `{ticket.name} · {job.name} · {ticket.amount} $`
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
		local cargo = step.cargo and Repair.cargo[step.cargo]
		local owner = step.cargo and session:GetAttribute("Carry_" .. step.cargo)
		local motion = step.motion and motionHelp[step.motion]
		if motion and session:GetAttribute("Moving") then
			action.Text, hint.Text = motion[1], motion[2]
		elseif step.tool and not ownTool then
			hint.Text = if toolOwner ~= 0 then "Ton collègue a l’outil." else `Prends l’outil « {job.tool} » sur le meuble à droite du pont.`
		elseif cargo and owner ~= player.UserId then
			hint.Text = if owner then `Ton collègue transporte cet objet · {cargo.name}.` else cargo.hint
		elseif step.action == "inflate" then
			hint.Text = `{session:GetAttribute("Pressure") or 28} psi mesurés · cible 34 psi.`
		elseif step.action == "verifyPressure" then
			hint.Text = `Lecture actuelle {session:GetAttribute("Pressure") or 34} psi. Confirme la mesure.`
		else
			hint.Text = step.hint or targetHelp[step.target] or "Approche-toi du point indiqué."
		end
	elseif phase == "done" then
		orderLine.Visible = true
		orderLine.Text = `Recette du jour · {session:GetAttribute("DailyCash") or 0} $`
	end
	local items = {}
	if ownTool and job.tool then table.insert(items, job.tool) end
	for item, spec in Repair.cargo do
		if session:GetAttribute("Carry_" .. item) == player.UserId then table.insert(items, spec.name) end
	end
	table.sort(items)
	held.Visible = driving or #items > 0
	held.Text = if driving then drivingControls else "En main · " .. table.concat(items, " + ")
	local amount = if phase == "repair" then (index - 1) / #job.steps else served / #plan
	progress.Size = UDim2.fromScale(math.clamp(amount, 0, 1), 1)
end
session.AttributeChanged:Connect(refresh)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
refresh()

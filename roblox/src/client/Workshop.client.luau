local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local modules = ReplicatedStorage:WaitForChild("GarageDay")
local Repair = require(modules:WaitForChild("Repair"))
local playerGui = player:WaitForChild("PlayerGui")
player.CameraMode = Enum.CameraMode.LockFirstPerson
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

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
local note = label(8, "", 12, gold, false)

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
reticleGui.DisplayOrder = 3
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
local carryControl = session:WaitForChild("CarryControl")
local dropBound = false
local motionHelp = {
	raise = { "Le pont monte", "Tu peux préparer le matériel pendant la montée." },
	lower = { "Le pont descend", "Attends l’arrêt du pont." },
	openHood = { "Le capot s’ouvre", "Laisse l’avant du véhicule dégagé." },
	closeHood = { "Le capot se referme", "Attends la fermeture." },
}
local targetHelp = {
	Lever = "Vise le levier jaune à droite du pont.", Hood = "Place-toi devant le véhicule.",
	BatteryTray = "Vise le plateau de batterie sous le capot.",
	OilCap = "Vise le bouchon sur le moteur.", Drain = "Vise le dessous du moteur, depuis l’avant.",
	WasteOil = "Vide le bac au fût marqué HUILE USÉE.",
	Recycling = "Dépose la pièce au bac marqué RECYCLAGE.", Scrap = "Va au bac MÉTAUX, près de la porte piétonne.",
	TireBin = "Amène la roue au bac PNEUS USÉS dehors, à droite de l’entrée.", Quote = "Retourne voir le client dans la salle d’attente.",
	WheelStand = "Le support se trouve côté établi, à gauche du pont.", Bench = "L’établi se trouve à gauche du pont.",
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
	closing = {"Service terminé", "La caravane se gare sur le parvis."},
	vendor = {"La caravane est ouverte", "Va au comptoir sur le parvis. Le téléphone ouvre la prochaine journée."},
}

local function bindDrop(canDrop)
	if canDrop == dropBound then return end
	dropBound = canDrop
	if canDrop then
		ContextActionService:BindAction("GaragePoser", function(_, inputState)
			if inputState == Enum.UserInputState.Begin and not playerGui:GetAttribute("CaravaneOpen") then carryControl:FireServer() end
			return Enum.ContextActionResult.Sink
		end, UserInputService.TouchEnabled, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle("GaragePoser", "Poser")
		ContextActionService:SetPosition("GaragePoser", UDim2.fromScale(0.58, 0.21))
	else
		ContextActionService:UnbindAction("GaragePoser")
	end
end

local function refresh()
	local phase = session:GetAttribute("Phase") or "free"
	local day = session:GetAttribute("Day") or 0
	local cash = session:GetAttribute("Cash") or 0
	local served = session:GetAttribute("Served") or 0
	local total = session:GetAttribute("Appointments") or 0
	local customer = session:GetAttribute("Customer") or ""
	local job = Repair.jobs[session:GetAttribute("Job") or ""]
	local index = session:GetAttribute("Step") or 0
	local steps = session:GetAttribute("Steps") or 0
	local partOfDay = phase == "vendor" or phase == "closing"
	local rider = session:GetAttribute("Driver") or 0
	local driving = rider == player.UserId
	local input = UserInputService.PreferredInput
	local heldCargo
	for item, spec in Repair.cargo do
		if session:GetAttribute("Carry_" .. item) == player.UserId then heldCargo = spec.name break end
	end
	reticleGui.Enabled = not driving and not playerGui:GetAttribute("CaravaneOpen") and input ~= Enum.PreferredInput.Touch
	ledger.Text = if day == 0 then "Atelier libre" else string.format("Jour %d · %d/%d clients · %d $", day, served, total, cash)
	orderLine.Visible = phase ~= "free"
	orderLine.Text = string.format("%s · %d $\n%s", customer, session:GetAttribute("OrderEstimate") or 0, session:GetAttribute("OrderJobs") or "")
	action.TextColor3 = if partOfDay then mint else cream
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
	elseif phase == "repair" and job then
		action.Text = session:GetAttribute("ActionTitle") or job.name
		local toolKey = session:GetAttribute("NeedsTool")
		local cargoKey = session:GetAttribute("NeedsCargo")
		local actionKey = session:GetAttribute("Action")
		local cargo = cargoKey and Repair.cargo[cargoKey]
		local owner = cargoKey and session:GetAttribute("Carry_" .. cargoKey)
		local toolOwner = toolKey and session:GetAttribute("Tool_" .. toolKey)
		local motion = motionHelp[session:GetAttribute("Motion") or ""]
		if motion and session:GetAttribute("Moving") then
			action.Text, hint.Text = motion[1], motion[2]
		elseif heldCargo and (session:GetAttribute("NeedsEmptyHands") or (cargo and owner ~= player.UserId)) then
			hint.Text = "Pose d’abord ce que tu transportes."
		elseif toolKey and toolOwner ~= player.UserId then
			hint.Text = if toolOwner then "Ton collègue a l’outil." else "Prends « " .. Repair.tools[toolKey].name .. " » à droite du pont."
		elseif cargo and owner ~= player.UserId then
			local source = session:GetAttribute("CargoSource")
			hint.Text = if owner then "Ton collègue transporte " .. cargo.name .. "."
				elseif source == "Ground" then "Ramasse la pièce là où tu l’as posée."
				elseif source == "Recovery" then "La pièce est au point OBJETS RÉCUPÉRÉS."
				elseif source == "Counter1" or source == "Counter2" then "Reprends la pièce sur la desserte."
				else cargo.hint
		elseif actionKey == "adjustPressure" or actionKey == "verifyPressure" then
			hint.Text = string.format("%d psi mesurés · cible 34 psi.", session:GetAttribute("Pressure") or 34)
		else
			hint.Text = targetHelp[session:GetAttribute("Target") or ""] or "Approche-toi du point indiqué."
		end
	elseif partOfDay then
		orderLine.Text = string.format("Recette du jour · %d $ · %.1f/5 ★", session:GetAttribute("DailyCash") or 0,
			(session:GetAttribute("Rating") or 10) / 2)
	elseif phase == "payment" then
		action.Text = string.format("Encaisser %d $", session:GetAttribute("Invoice") or 0)
	elseif phase == "departing" then
		orderLine.Text = string.format("%s · %d $ encaissés", customer, session:GetAttribute("LastInvoice") or 0)
	end
	local inHand = heldCargo
	local carrying = heldCargo ~= nil
	local cart = session:GetAttribute("CartOwner") == player.UserId
	if not inHand then
		for key, spec in Repair.tools do
			if session:GetAttribute("Tool_" .. key) == player.UserId then inHand = spec.name break end
		end
	end
	local drop = if input == Enum.PreferredInput.Touch then "Poser" elseif input == Enum.PreferredInput.Gamepad then "B poser" else "Q poser"
	held.Visible = driving or inHand ~= nil or cart
	held.Text = if driving then drivingControls elseif inHand then "En main · " .. inHand .. (if carrying then "  ·  " .. drop else "")
		else string.format("Chariot · %d/4 roues · %s", session:GetAttribute("CartStock") or 0, drop)
	bindDrop(not driving and (carrying or cart))
	local status = session:GetAttribute("StatusNote") or ""
	note.Visible = (phase == "repair" and (status ~= "" or job ~= nil)) or session:GetAttribute("CustomerLate") and not partOfDay and phase ~= "departing"
	note.Text = if session:GetAttribute("CustomerLate") then "Client impatient · " .. (if status ~= "" then status else "travail en cours")
		elseif status ~= "" then status
		elseif job then string.format("%s · %d/%d · geste %d/%d", job.name, session:GetAttribute("JobNumber") or 1,
			session:GetAttribute("JobCount") or 1, index, steps)
		else ""
	local amount = if phase == "repair" and steps > 0 then (index - 1) / steps elseif total > 0 then served / total else 0
	progress.Size = UDim2.fromScale(math.clamp(amount, 0, 1), 1)
end
session.AttributeChanged:Connect(refresh)
playerGui:GetAttributeChangedSignal("CaravaneOpen"):Connect(refresh)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
refresh()

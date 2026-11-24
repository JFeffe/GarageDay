local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local modules = ReplicatedStorage:WaitForChild("GarageDay")
local Repair = require(modules:WaitForChild("Repair"))
local Service = require(modules:WaitForChild("Service"))
local playerGui = player:WaitForChild("PlayerGui")
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

local mapName = label(1, "Garage Day", 12, gold, true)
local ledger = label(2, "Atelier libre", 13, mint, false)
local orderLine = label(5, "", 13, mint, false)
local action = label(6, "Préparation du garage…", 19, cream, true)
local hint = label(7, "", 13, cream, false)
local held = label(9, "", 12, mint, false)
local note = label(10, "", 12, gold, false)
local saveNote = label(11, "", 12, gold, false)

local rail = Instance.new("Frame")
rail.LayoutOrder = 8
rail.Size = UDim2.new(1, 0, 0, 3)
rail.BackgroundColor3 = Color3.fromRGB(58, 82, 84)
rail.BorderSizePixel = 0
rail.Parent = panel
local progress = Instance.new("Frame")
progress.Size = UDim2.fromScale(0, 1)
progress.BackgroundColor3 = gold
progress.BorderSizePixel = 0
progress.Parent = rail

local ratingRow = Instance.new("Frame")
ratingRow.LayoutOrder = 3
ratingRow.Size = UDim2.new(1, 0, 0, 20)
ratingRow.BackgroundTransparency = 1
ratingRow.Parent = panel
local function rowText(parent, size, color, text)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Size = UDim2.fromScale(1, 1)
	item.Font = Enum.Font.GothamMedium
	item.TextSize = size
	item.TextColor3 = color
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Text = text or ""
	item.Parent = parent
	return item
end
local stars = {}
for i = 1, 5 do
	local slot = Instance.new("Frame")
	slot.BackgroundTransparency = 1
	slot.Position = UDim2.fromOffset((i - 1) * 19, 0)
	slot.Size = UDim2.fromOffset(19, 20)
	slot.Parent = ratingRow
	rowText(slot, 19, Color3.fromRGB(109, 131, 120), "★")
	local fill = Instance.new("Frame")
	fill.BackgroundTransparency = 1
	fill.ClipsDescendants = true
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = slot
	local star = rowText(fill, 19, gold, "★")
	star.Size = UDim2.fromOffset(19, 20)
	stars[i] = fill
end
local ratingText = rowText(ratingRow, 12, cream)
ratingText.Position = UDim2.fromOffset(104, 0)
ratingText.Size = UDim2.new(1, -104, 1, 0)

local patients = Instance.new("Frame")
patients.LayoutOrder = 4
patients.Size = UDim2.fromScale(1, 0)
patients.AutomaticSize = Enum.AutomaticSize.Y
patients.BackgroundTransparency = 1
patients.Parent = panel
local patientLayout = Instance.new("UIListLayout")
patientLayout.Padding = UDim.new(0, 4)
patientLayout.SortOrder = Enum.SortOrder.LayoutOrder
patientLayout.Parent = patients
local patientRows = {}
local warning = Color3.fromRGB(245, 141, 120)
for i = 1, 2 do
	local row = Instance.new("Frame")
	row.LayoutOrder = i
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = patients
	local caption = rowText(row, 12, cream)
	caption.Size = UDim2.new(1, 0, 0, 17)
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(0, 18)
	track.Size = UDim2.new(1, 0, 0, 3)
	track.BackgroundColor3 = rail.BackgroundColor3
	track.BorderSizePixel = 0
	track.Parent = row
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	patientRows[i] = { row = row, caption = caption, fill = fill }
end

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
local bays = session:WaitForChild("Bays")
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
	WasteOil = "Vide le bac au fût HUILE USÉE. Le bac vide retourne au poste VIDANGE.",
	Recycling = "Dépose la pièce au bac marqué RECYCLAGE.", Scrap = "Va au bac MÉTAUX, près de la porte piétonne.",
	TireBin = "Amène la roue au bac PNEUS USÉS sur le parvis.", Quote = "Retourne voir le client dans la salle d’attente.",
	WheelStand = "Repère le support de roue près de l’établi.", Bench = "Repère l’établi dans l’atelier.",
}
local phases = {
	free = {"Ouvrir le service", "Utilise le téléphone dans le bureau."},
	arrival = {"Le client arrive", "Retrouve-le au comptoir d’accueil."},
	reception = {"Accueillir le client", "Rends-toi au comptoir marqué ACCUEIL."},
	intake = {"Rentrer la berline", "Prends le volant et entre par le rideau ouvert."},
	outbound = {"Sortir la berline", "Prends le volant et rejoins le stationnement de la baie."},
	checkout = {"Le client rejoint la caisse", "Rends-toi au comptoir marqué CAISSE."},
	payment = {"Encaisser la réparation", "Encaisse le client à la caisse."},
	departing = {"Le client récupère sa voiture", "Laisse le passage libre pendant son départ."},
	closing = {"Service terminé", "La caravane se gare sur le parvis."},
	vendor = {"Soirée à l’atelier", "Achète à la caravane sur le parvis ou réaménage le garage."},
	service = {"Service ouvert", "Consulte les rendez-vous au comptoir."},
	complete = {"Campagne terminée", "Les 10 journées sont terminées."},
}

local function bindDrop(canDrop)
	if canDrop == dropBound then return end
	dropBound = canDrop
	if canDrop then
		ContextActionService:BindAction("GaragePoser", function(_, inputState)
			if inputState == Enum.UserInputState.Begin and not playerGui:GetAttribute("CaravaneOpen")
				and not playerGui:GetAttribute("WorkshopOptionsOpen") then carryControl:FireServer() end
			return Enum.ContextActionResult.Sink
		end, UserInputService.TouchEnabled, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
		ContextActionService:SetTitle("GaragePoser", "Poser")
		ContextActionService:SetPosition("GaragePoser", UDim2.fromScale(0.58, 0.21))
	else
		ContextActionService:UnbindAction("GaragePoser")
	end
end

local function focusedBay()
	local driver = player:GetAttribute("GarageDriverBay")
	if driver then return bays:FindFirstChild(tostring(driver)) end
	if session:GetAttribute("Phase") ~= "service" then return nil end
	if player:GetAttribute("GarageHeldKey") == "usedOil" then
		local oilBay = bays:FindFirstChild(tostring(player:GetAttribute("GarageHeldBay")))
		if oilBay then return oilBay end
	end
	local id = player:GetAttribute("GarageFocusBay")
	local remembered = id and bays:FindFirstChild(tostring(id))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local selected, fallback, distance = nil, nil, 13
	for index = 1, #patientRows do
		local bay = bays:FindFirstChild(tostring(index))
		local phase = bay and bay:GetAttribute("Phase")
		if phase and phase ~= "idle" then
			fallback = fallback or bay
			if root and bay:GetAttribute("Dock") then
				local offset = (bay:GetAttribute("Dock") - root.Position).Magnitude
				if offset < distance then selected, distance = bay, offset end
			end
		end
	end
	return selected or (remembered and remembered:GetAttribute("Phase") ~= "idle" and remembered) or fallback
end

local displayed
local function refresh()
	local playing = session:GetAttribute("LaunchMode") == "playing"
	gui.Enabled = playing
	if not playing then
		reticleGui.Enabled = false
		bindDrop(false)
		return
	end
	local servicePhase = session:GetAttribute("Phase") or "free"
	local bay = focusedBay()
	displayed = bay
	local function value(key, default)
		if bay then
			local result = bay:GetAttribute(key)
			if result ~= nil then return result end
		end
		return default
	end
	local phase = value("Phase", servicePhase)
	local bayNumber = if bay then "0" .. bay.Name else ""
	local day = session:GetAttribute("Day") or 0
	local cash = session:GetAttribute("Cash") or 0
	local served = session:GetAttribute("Served") or 0
	local total = session:GetAttribute("Appointments") or 0
	local customer = value("Customer", "")
	local job = Repair.jobs[value("Job", "")]
	local index, steps = value("Step", 0), value("Steps", 0)
	local evening = phase == "vendor" or phase == "closing"
	local driving = player:GetAttribute("GarageDriverBay") ~= nil
	local input = UserInputService.PreferredInput
	local hand = player:GetAttribute("GarageHeldKind")
	local heldKey = player:GetAttribute("GarageHeldKey")
	local object = heldKey and (Repair.cargo[heldKey] or Repair.tools[heldKey])
	local arranging = hand == "furniture"
	local modal = playerGui:GetAttribute("CaravaneOpen") or playerGui:GetAttribute("WorkshopOptionsOpen") or playerGui:GetAttribute("RepairChoiceOpen")
	local alternate = if input == Enum.PreferredInput.Gamepad then "Y" elseif input == Enum.PreferredInput.Touch then "l’action de choix" else "F"

	mapName.Text = string.upper(session:GetAttribute("MapName") or "Garage Day")
	reticleGui.Enabled = not driving and not modal and input ~= Enum.PreferredInput.Touch
	ledger.Text = if day == 0 then string.format("Campagne de %d jours · %d $", Service.lastDay, cash)
		else string.format("Jour %d/%d · %d/%d clients · %d $", day, Service.lastDay, served, total, cash)
	ratingRow.Visible = day > 0
	local rating = session:GetAttribute("Rating") or 10
	for i, star in stars do star.Size = UDim2.fromScale(math.clamp(rating / 2 - i + 1, 0, 1), 1) end
	ratingText.Text = string.format("%.1f / 5 · Journée", rating / 2):gsub("%.", ",")
	patients.Visible = servicePhase == "service"
	for i, row in patientRows do
		local station = bays:FindFirstChild(tostring(i))
		local stage = station and station:GetAttribute("Phase")
		row.row.Visible = stage ~= nil and stage ~= "idle" and stage ~= "arrival" and stage ~= "departing"
		if row.row.Visible then
			local fraction = (station:GetAttribute("Patience") or 0) / 100
			local late = station:GetAttribute("CustomerLate")
			local remaining = station:GetAttribute("PatienceSeconds") or 0
			local time = if station:GetAttribute("SnackPause") then "Pause collation" elseif late then "Impatient"
				else string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
			row.caption.Text = string.format("%sBaie 0%d · %s · %s", if station == bay then "› " else "", i, station:GetAttribute("Customer") or "", time)
			row.fill.Size = UDim2.fromScale(if late then 1 else fraction, 1)
			row.fill.BackgroundColor3 = if late then warning elseif fraction < 0.3 then gold else mint
		end
	end

	orderLine.Visible = bay ~= nil or evening or phase == "complete"
	orderLine.Text = string.format("%s · %d $\n%s", customer, value("OrderEstimate", 0), value("OrderJobs", ""))
	action.TextColor3 = if evening or phase == "complete" then mint else cream
	local description = phases[phase] or phases.service
	action.Text, hint.Text = description[1], description[2]
	local saveStatus = session:GetAttribute("SaveState")
	if phase == "free" then
		hint.Text = "Téléphone du bureau · " .. alternate .. " choisir une partie."
		if saveStatus == "loading" then
			action.Text, hint.Text = "Chargement de l’atelier…", "Récupération de ta dernière journée."
		end
	end
	saveNote.Visible = saveStatus == "unavailable" or saveStatus == "unsupported" or saveStatus == "conflict" or saveStatus == "retry"
	saveNote.Text = if saveStatus == "retry" then "Sauvegarde en attente." elseif saveStatus == "conflict" then "Atelier sauvegardé dans une autre session."
		else "Sauvegarde indisponible pour cette partie."
	local drivingControls = if input == Enum.PreferredInput.Touch then "Commandes tactiles" elseif input == Enum.PreferredInput.Gamepad then
		"Stick gauche conduire  ·  X valider  ·  B descendre" else "W/S accélérer et reculer  ·  A/D braquer  ·  E valider"
	if driving then
		action.Text = (if phase == "intake" then "Baie " else "Stationnement P ") .. bayNumber
		action.TextColor3 = if value("ParkingReady") then mint else cream
		hint.Text = value("ParkingHint", "")
	elseif value("Driver", 0) ~= 0 then
		hint.Text = "Ton collègue est au volant. Laisse le passage libre."
	elseif phase == "repair" and job then
		action.Text = value("ActionTitle", job.name)
		local toolKey, cargoKey = value("NeedsTool"), value("NeedsCargo")
		local actionKey = value("Action")
		local cargo = cargoKey and Repair.cargo[cargoKey]
		local owner = value("CargoOwner")
		local toolOwner = toolKey and session:GetAttribute("Tool_" .. toolKey)
		local motion = motionHelp[value("Motion", "")]
		if motion and value("Moving") then
			action.Text, hint.Text = motion[1], motion[2]
		elseif heldKey == "usedOil" then
			action.Text = "Vider le bac d’huile usée"
			hint.Text = targetHelp.WasteOil
		elseif hand and (value("NeedsEmptyHands") or (toolKey and toolOwner ~= player.UserId) or (cargo and owner ~= player.UserId)) then
			hint.Text = "Pose d’abord ce que tu tiens."
		elseif toolKey and toolOwner ~= player.UserId then
			hint.Text = if toolOwner then "Ton collègue a l’outil." elseif value("ToolOnFloor") then "Utilise l’invite Ramasser sur l’outil déposé."
				else "Prends « " .. Repair.tools[toolKey].name .. " » au poste d’outillage."
		elseif cargo and owner ~= player.UserId then
			local source = value("CargoSource")
			hint.Text = if owner then "Ton collègue transporte " .. cargo.name .. "."
				elseif source == "Ground" then "Ramasse la pièce là où tu l’as posée."
				elseif source == "Workpiece" then "Ramasse la pièce que tu viens de retirer."
				elseif source == "Recovery" then "La pièce est au point OBJETS RÉCUPÉRÉS."
				elseif source == "Counter1" or source == "Counter2" then "Reprends la pièce sur la desserte."
				else cargo.hint
		elseif actionKey == "adjustPressure" or actionKey == "verifyPressure" then
			hint.Text = string.format("%d psi mesurés · cible 34 psi.", value("Pressure", 34))
		elseif actionKey == "drain" and cargoKey == "pan" then
			hint.Text = "Place le bac sous le moteur depuis l’avant, puis ramasse le bac plein."
		elseif actionKey == "fillOil" then
			hint.Text = "Verse le bidon d’huile neuve au bouchon sous le capot."
		else
			hint.Text = targetHelp[value("Target", "")] or "Approche-toi du point indiqué."
		end
		if value("CanChooseRepair") and heldKey ~= "usedOil" then hint.Text ..= "\n" .. alternate .. " au véhicule pour changer le suivi." end
	elseif evening then
		orderLine.Text = string.format("Recette du jour · %d $", session:GetAttribute("DailyCash") or 0)
		if phase == "vendor" and day >= Service.lastDay then hint.Text = "Le téléphone affiche le bilan. La caravane est encore ouverte." end
	elseif phase == "complete" then
		orderLine.Text = string.format("%d $ encaissés en 10 jours", session:GetAttribute("TotalEarned") or 0)
		hint.Text = string.format("Moyenne de la campagne · %.1f / 5 étoiles", session:GetAttribute("AverageRating") or 0):gsub("%.", ",")
	elseif phase == "payment" then
		action.Text = string.format("Encaisser %d $", value("Invoice", 0))
	elseif phase == "departing" then
		orderLine.Text = customer .. " a réglé sa facture."
	elseif (phase == "intake" or phase == "outbound") and hand then
		hint.Text = "Pose ce que tu tiens avant de prendre le volant."
	end
	local drop = if input == Enum.PreferredInput.Touch then "Poser" elseif input == Enum.PreferredInput.Gamepad then "B poser" else "Q poser"
	held.Visible = driving or (hand ~= nil and not arranging)
	held.Text = if driving then drivingControls elseif object then "En main · " .. object.name .. "  ·  " .. drop
		else string.format("Chariot · %d/4 roues · %s", session:GetAttribute("CartStock") or 0, drop)
	bindDrop(not driving and hand ~= nil and not arranging)
	local status = value("StatusNote", "")
	note.Visible = phase == "repair" and job ~= nil
	note.Text = if status ~= "" then status
		elseif job then string.format("Baie %s · %s · %d/%d · geste %d/%d", bayNumber, job.name, value("JobNumber", 1),
			value("JobCount", 1), index, steps)
		else ""
	local amount = if phase == "repair" and steps > 0 then (index - 1) / steps elseif total > 0 then served / total else 0
	progress.Size = UDim2.fromScale(math.clamp(amount, 0, 1), 1)
end

local function watchBay(bay)
	bay.AttributeChanged:Connect(refresh)
	refresh()
end
for _, bay in bays:GetChildren() do watchBay(bay) end
bays.ChildAdded:Connect(watchBay)
bays.ChildRemoved:Connect(refresh)
for _, attr in { "GarageDriverBay", "GarageFocusBay", "GarageHeldKind", "GarageHeldKey", "GarageHeldBay" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
session.AttributeChanged:Connect(refresh)
playerGui:GetAttributeChangedSignal("CaravaneOpen"):Connect(refresh)
playerGui:GetAttributeChangedSignal("WorkshopOptionsOpen"):Connect(refresh)
playerGui:GetAttributeChangedSignal("RepairChoiceOpen"):Connect(refresh)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
task.spawn(function()
	while gui.Parent do
		task.wait(0.22)
		if focusedBay() ~= displayed then refresh() end
	end
end)
refresh()

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layout = require(script.Parent.PetitAtelier)
local MeshLibrary = require(script.Parent.MeshLibrary)
local Decor = require(script.Parent.AtelierDecor)
local Repair = require(ReplicatedStorage.GarageDay.Repair)

local World = {}
local at = Layout.at
local unit = Layout.scale
local roofHeight = 9.85
local concrete = Color3.fromRGB(153, 164, 154)
local wall = Color3.fromRGB(227, 220, 201)
local trim = Color3.fromRGB(197, 174, 141)
local steel = Color3.fromRGB(48, 64, 68)
local teal = Color3.fromRGB(68, 109, 111)
local yellow = Color3.fromRGB(242, 192, 88)
local mint = Color3.fromRGB(140, 224, 166)
local red = Color3.fromRGB(200, 77, 54)
local black = Color3.fromRGB(34, 43, 45)

local function part(parent, name, size, position, color, solid, material)
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Size = size
	instance.Position = position
	instance.Color = color
	instance.Material = material or Enum.Material.SmoothPlastic
	instance.Anchored = true
	instance.CanCollide = solid == true
	instance.CanQuery = instance.CanCollide
	instance.CanTouch = false
	instance.Parent = parent
	return instance
end

local function model(parent, name, pivot)
	local instance = Instance.new("Model")
	instance.Name = name
	instance.WorldPivot = pivot or CFrame.identity
	instance.Parent = parent
	return instance
end

local function rectPart(parent, name, rect, height, y, color, solid, material)
	return part(parent, name, Vector3.new(rect[3] * unit, height, rect[4] * unit), Layout.centre(rect, y), color, solid, material)
end

local function target(parent, name, position)
	local anchor = part(parent, name, Vector3.one * 0.12, position, steel)
	anchor.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	return attachment
end

local function sign(attachment, label, offset, range)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Panneau"
	gui.Size = UDim2.fromOffset(166, 28)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset or 1.25, 0)
	gui.MaxDistance = range or 30
	gui.Parent = attachment
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = label
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextColor3 = Color3.fromRGB(255, 238, 200)
	text.TextStrokeColor3 = steel
	text.TextStrokeTransparency = 0.1
	text.Parent = gui
end

local function cloneMesh(template, parent, pivot)
	if not template then return nil end
	local instance = template:Clone()
	instance.CFrame = pivot * instance.CFrame
	instance.Parent = parent
	return instance
end

local function prop(world, key, name, position, size, color, yaw)
	local pose = CFrame.new(position) * CFrame.Angles(0, yaw or 0, 0)
	local shape = cloneMesh(world.meshes[key], world.room, pose)
	local collision = part(world.room, name, size, position, color, true)
	collision.CFrame = pose * CFrame.new(0, size.Y / 2, 0)
	if shape then collision.Transparency = 1 end
	return collision
end

local function plate(world, name, rect, color, label)
	local slab = rectPart(world.room, name, rect, 0.035, 0.045, color)
	local markers = {}
	for _, x in { rect[1], rect[1] + rect[3] } do
		table.insert(markers, rectPart(world.room, "Ligne", { x - 0.026, rect[2], 0.052, rect[4] }, 0.028, 0.08, yellow))
	end
	table.insert(markers, rectPart(world.room, "Ligne", { rect[1], rect[2], rect[3], 0.052 }, 0.028, 0.08, yellow))
	if label then sign(target(world.room, label, slab.Position), label, 1.15, 34) end
	return markers
end

local function buildShell(world)
	local room = world.room
	Lighting.TimeOfDay = "15:45:00"
	Lighting.Brightness = 2.18
	Lighting.Ambient = Color3.fromRGB(129, 123, 117)
	Lighting.OutdoorAmbient = Color3.fromRGB(151, 154, 153)
	Lighting.ColorShift_Top = Color3.fromRGB(24, 13, 6)
	Lighting.EnvironmentDiffuseScale = 0.26
	Lighting.EnvironmentSpecularScale = 0.31
	Lighting.ShadowSoftness = 0.28
	Lighting.GlobalShadows = true
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Color = Color3.fromRGB(205, 224, 240)
	atmosphere.Decay = Color3.fromRGB(220, 182, 136)
	atmosphere.Density = 0.21
	atmosphere.Haze = 1.08
	atmosphere.Parent = Lighting

	rectPart(room, "Îlot du garage", {-1.5, -17, 25, 57.2}, 0.65, -0.42, Color3.fromRGB(110, 138, 101), true, Enum.Material.Grass)
	rectPart(room, "Cour et parvis", {0, -11, 18, 45}, 0.18, -0.10, Color3.fromRGB(114, 123, 122), true, Enum.Material.Concrete)
	local asphalt = Color3.fromRGB(62, 72, 76)
	rectPart(room, "Route des arrivées", {0, 34, 22.5, 6.2}, 0.16, -0.08, asphalt, true, Enum.Material.Asphalt)
	rectPart(room, "Route de sortie", {0, -17, 22.5, 6}, 0.16, -0.08, asphalt, true, Enum.Material.Asphalt)
	rectPart(room, "Sol de l’atelier", {0, 0, 18, 13}, 0.16, -0.06, concrete, true, Enum.Material.Concrete)
	rectPart(room, "Sol du bureau et de l’accueil", {0, 0, 4.9, 13}, 0.035, 0.037, trim, false, Enum.Material.WoodPlanks)
	rectPart(room, "Toit", {-0.17, -0.15, 18.34, 13.3}, 0.42, roofHeight + 0.21, steel, true, Enum.Material.Metal)
	rectPart(room, "Plafond", {0, 0, 18, 13}, 0.06, roofHeight - 0.045, Color3.fromRGB(185, 184, 168), false, Enum.Material.Plaster)
	for _, z in { 3.53, 7.81, 11.18 } do
		rectPart(room, "Traverse du plafond", {0, z, 18, 0.065}, 0.26, roofHeight - 0.19, steel, false, Enum.Material.Metal)
	end

	local function wallSection(rect, height, bottom)
		rectPart(room, "Mur", rect, height, bottom + height / 2, wall, true, Enum.Material.Plaster)
		if bottom == 0 then
			local fascia = { rect[1] - 0.016, rect[2] - 0.016, rect[3] + 0.032, rect[4] + 0.032 }
			rectPart(room, "Soubassement", fascia, 1.68, 0.84, Color3.fromRGB(102, 125, 113), false, Enum.Material.Concrete)
			rectPart(room, "Liseré mural", fascia, 0.12, 1.74, trim)
		end
	end
	for _, rect in Layout.walls do wallSection(rect, roofHeight, 0) end
	for _, side in Layout.sideWindows do
		local last = 0
		for _, opening in side.openings do
			local first, finish = opening[1], opening[2]
			wallSection({ side.x, last, 0.18, first - last }, roofHeight, 0)
			local window = { side.x, first, 0.18, finish - first }
			wallSection(window, 4.32, 0)
			wallSection(window, roofHeight - 8.0, 8.0)
			local glass = rectPart(room, "Vitre", { side.x + 0.075, first, 0.03, finish - first }, 3.68, 6.16,
				Color3.fromRGB(173, 209, 212), true, Enum.Material.Glass)
			glass.Transparency = 0.52
			for _, z in { first, (first + finish) / 2, finish } do
				part(room, "Montant de fenêtre", Vector3.new(0.48, 3.72, 0.14), at(side.x + 0.09, z, 6.16), steel, false, Enum.Material.Metal)
			end
			for _, y in { 4.32, 8.0 } do
				part(room, "Cadre de fenêtre", Vector3.new(0.52, 0.16, (finish - first) * unit + 0.14), at(side.x + 0.09, (first + finish) / 2, y),
					steel, false, Enum.Material.Metal)
			end
			last = finish
		end
		wallSection({ side.x, last, 0.18, 13 - last }, roofHeight, 0)
	end
	for _, door in { {1.5, 12.82, 2, 0.18}, {5.89, 0, 1.63, 0.18}, {8.55, 12.82, 1.27, 0.18} } do
		rectPart(room, "Linteau piéton", door, 2.25, roofHeight - 1.125, wall, true)
	end
	for _, rect in { {-1.47, -17, 0.11, 57.2}, {23.37, -17, 0.11, 57.2}, {-1.5, -17, 25, 0.10}, {-1.5, 40.1, 25, 0.10} } do
		local fence = rectPart(room, "Limite de la cour", rect, 4, 2, steel, true)
		fence.Transparency = 1
	end
	for x = 1, 22, 3 do
		for _, z in { -14.36, 36.1 } do
			rectPart(room, "Marquage routier", { x, z, 1.4, 0.062 }, 0.026, 0.025, trim)
		end
	end
	for _, x in { 2.5, 8.2, 12.5, 16.0 } do
		for _, z in { 2.2, 6.35, 10.2 } do
			local lamp = part(room, "Rampe d’atelier", Vector3.new(0.29, 0.06, 3.85), at(x, z, roofHeight - 0.39), Color3.fromRGB(255, 237, 203))
			lamp.Material = Enum.Material.Neon
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Color = Color3.fromRGB(255, 238, 210)
			light.Range = 15
			light.Angle = 114
			light.Brightness = 0.75
			light.Parent = lamp
		end
	end

	for i, spec in { {2.05, 3.25, 1.55, 2.5}, {3.25, 3.28, 1.55, 2.5} } do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Mécano " .. i
		spawn.Size = Vector3.new(1.9, 0.38, 1.9)
		spawn.CFrame = CFrame.lookAt(at(spec[1], spec[2], 0.25), at(spec[3], spec[4], 0.25))
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.CanTouch = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = room
		world.spawns[i] = spawn
	end
	for _, caption in {
		{ "BUREAU", 2.44, 3.41 }, { "SALLE D’ATTENTE", 2.43, 6.83 }, { "ENTRÉE CLIENTS", 2.5, 13.03 },
		{ "PORTE PIÉTONNE", 9.18, 12.94 }, { "SORTIE", 6.7, -0.22 },
	} do
		sign(target(room, caption[1], at(caption[2], caption[3], 6.9)), caption[1], 0, 27)
	end
end

local function buildStations(world)
	local room = world.room
	local function station(point)
		return at(table.unpack(Layout.stations[point]))
	end
	for _, item in {
		{ "phone", "Desk", "Bureau", Vector3.new(5.6, 2.62, 2.55), trim },
		{ "officeChair", "Chair", "Chaise", Vector3.new(2.05, 2.68, 2.08), teal },
		{ "bookcase", "Bookcase", "Armoire", Vector3.new(2.3, 3.4, 1.4), trim },
		{ "waitingBench", "Bench", "Banquette", Vector3.new(2.26, 2.66, 2.68), teal, math.pi / 2 },
		{ "reception", "Reception", "Accueil et caisse", Vector3.new(5.75, 3.55, 2.5), trim, math.pi },
		{ "plant", "Plant", "Plante", Vector3.new(1.52, 2.1, 1.52), mint },
		{ "bench", "Workbench", "Établi", Vector3.new(2.86, 3.05, 2.62), teal },
		{ "cart", "Trolley", "Chariot", Vector3.new(2.76, 2.55, 2.45), steel },
		{ "partsChassis", "Shelf", "Pièces châssis", Vector3.new(2.62, 3.45, 2.52), teal },
		{ "partsElectric", "Shelf", "Pièces électriques", Vector3.new(2.62, 3.45, 2.52), teal },
		{ "wasteOil", "Drum", "Récupération d’huile", Vector3.new(1.84, 2.36, 1.84), steel },
		{ "trash", "Bin", "Poubelle", Vector3.new(1.85, 1.94, 1.85), teal },
		{ "counter", "Trolley", "Desserte", Vector3.new(2.76, 2.55, 2.45), teal },
	} do
		prop(world, item[2], item[3], station(item[1]), item[4], item[5], item[6])
	end
	for _, point in { "toolWrench", "toolPressure", "toolInspection", "toolOil" } do
		prop(world, "Cabinet", "Poste d’outillage", station(point), Vector3.new(2.73, 2.37, 2.45), red, -math.pi / 2)
	end
	local phone = at(1.5, 2.48, 2.81)
	part(room, "Téléphone", Vector3.new(1.06, 0.31, 0.82), phone, steel)
	part(room, "Combiné", Vector3.new(0.96, 0.15, 0.28), phone + Vector3.new(0, 0.20, -0.16), teal)
	part(room, "Terminal", Vector3.new(0.97, 0.46, 0.86), at(1.5, 9.48, 3.52), steel)
	part(room, "Voyant de caisse", Vector3.new(0.8, 0.06, 0.19), at(1.5, 9.60, 3.79), mint)
	local wrenchPos = station("toolWrench") + Vector3.new(0, 2.43, 0)
	local gaugePos = station("toolPressure") + Vector3.new(0, 2.64, 0)
	world.tools.brakes = cloneMesh(world.meshes.Wrench, room, CFrame.new(wrenchPos) * CFrame.Angles(0, math.rad(24), 0))
		or part(room, "Clé à choc", Vector3.new(0.62, 1.35, 1.29), wrenchPos + Vector3.yAxis * 0.69, steel)
	world.tools.pressure = part(room, "Manomètre", Vector3.new(0.77, 0.53, 0.94), gaugePos, yellow)
	local face = part(room, "Cadran", Vector3.new(0.55, 0.04, 0.68), gaugePos + Vector3.yAxis * 0.29, steel)
	world.gaugeFace = face
	local panPos = station("toolOil") + Vector3.yAxis * 2.48
	local oilPos = station("counter") + Vector3.new(-0.20, 2.61, -0.05)
	local batteryPos = station("partsElectric") + Vector3.new(0, 2.64, -0.44)
	local usedPan = Vector3.new(0, 0.26, -7.33)
	local waste = station("wasteOil")
	local recycling = at(16.5, 10.53)
	world.cargo.pads = part(room, "Plaquettes", Vector3.new(1.06, 0.33, 0.7), at(6.5, 10.28, 2.68), yellow, false, Enum.Material.Metal)
	world.cargo.pan = part(room, "Bac de vidange", Vector3.new(1.65, 0.28, 1.2), panPos, steel)
	world.cargo.usedOil = part(room, "Bac d’huile usée", Vector3.new(1.65, 0.48, 1.2), usedPan, Color3.fromRGB(65, 45, 34))
	world.cargo.freshOil = part(room, "Bidon d’huile", Vector3.new(0.55, 0.85, 0.37), oilPos + Vector3.new(-0.78, 0.34, 0), yellow)
	world.cargo.newBattery = cloneMesh(world.meshes.Battery, room, CFrame.new(batteryPos))
		or part(room, "Batterie neuve", Vector3.new(0.96, 0.58, 0.68), batteryPos + Vector3.yAxis * 0.29, steel)
	cloneMesh(world.meshes.OilCrate, room, CFrame.new(oilPos + Vector3.new(0.47, -0.05, 0)))
	cloneMesh(world.meshes.Compressor, room, CFrame.new(at(16.73, 0.72)) * CFrame.Angles(0, math.pi / 2, 0))
	cloneMesh(world.meshes.Extinguisher, room, CFrame.new(at(17.54, 11.67, 0.75)))
	prop(world, "Bin", "Bac de recyclage", recycling, Vector3.new(1.85, 1.94, 1.85), teal)
	for _, entry in {
		{ "Phone", "TÉLÉPHONE", phone + Vector3.yAxis * 0.34 },
		{ "Reception", "ACCUEIL", at(2.53, 9.14, 3.62) }, { "Checkout", "CAISSE", at(1.47, 9.14, 3.75) },
		{ "Toolbrakes", "CLÉ À CHOC", wrenchPos + Vector3.new(-0.53, 0.82, 0) },
		{ "Toolpressure", "PRESSION", gaugePos + Vector3.new(-0.53, 0.24, 0) },
		{ "Pads", "CHÂSSIS", at(6.52, 10.05, 2.93) },
		{ "BatteryStock", "ÉLECTRICITÉ", station("partsElectric") + Vector3.new(0, 3.49, -1.31) },
		{ "OilPan", "VIDANGE", panPos + Vector3.new(-0.80, 0.44, 0) },
		{ "OilStock", "HUILE NEUVE", oilPos + Vector3.new(-0.83, 0.84, 0) },
		{ "WasteOil", "HUILE USÉE", waste + Vector3.new(-0.94, 2.17, 0) },
		{ "Recycling", "RECYCLAGE", recycling + Vector3.new(-0.97, 1.8, 0) },
		{ "UsedPan", nil, usedPan + Vector3.new(0, 0.22, -0.34) },
	} do
		local anchor = target(room, entry[1], entry[3])
		world.targets[entry[1]] = anchor
		if entry[2] then sign(anchor, entry[2], 0.82, 24) end
	end
end

local function buildBay(world)
	local room = world.room
	rectPart(room, "Allée du pont", {9.85, 0.18, 3.3, 12.65}, 0.014, 0.068, Color3.fromRGB(95, 120, 115))
	world.bayMarkers = plate(world, "Baie 01", Layout.bay, steel, "BAIE 01")
	world.parkingMarkers = plate(world, "Sortie P 01", Layout.parking, teal, "P 01")
	for i, rect in Layout.arrivals do plate(world, "Arrivée A 0" .. i, rect, trim, "A 0" .. i) end
	world.dockPose = CFrame.new(Layout.centre(Layout.bay))
	world.parkingPose = CFrame.new(Layout.centre(Layout.parking))
	world.arrivalPose = CFrame.new(Layout.centre(Layout.arrivals[1]))
	world.targets.Dock = target(room, "Repère baie", world.dockPose.Position + Vector3.new(0, 0.2, -5.2))
	world.targets.Parking = target(room, "Repère sortie", world.parkingPose.Position + Vector3.new(0, 0.2, -5.9))

	for side, z in { intake = 12.93, outbound = 0.07 } do
		local pose = CFrame.new(at(11.5, z))
		local gate = model(room, if side == "intake" then "Rideau d’entrée" else "Rideau de sortie", pose)
		local skin = cloneMesh(world.meshes.Roller, gate, pose)
		local stop = part(gate, "Rideau", Vector3.new(9.35, 8.15, 0.43), pose.Position + Vector3.yAxis * 4.075, teal, true)
		if skin then stop.Transparency = 1 end
		part(room, "Traverse", Vector3.new(9.7, roofHeight - 8.15, 0.63), pose.Position + Vector3.yAxis * ((roofHeight + 8.15) / 2), wall, true)
		world.gates[side] = { panels = { stop, skin }, pose = pose, open = false }
	end

	local pivot = CFrame.new(0, 0.06, -1.74)
	world.liftBase = pivot
	world.carriage = model(room, "Plateforme mobile", pivot)
	cloneMesh(world.meshes.LiftBase, room, pivot)
	cloneMesh(world.meshes.LiftCarriage, world.carriage, pivot)
	for _, x in { -4.72, 4.72 } do
		local column = part(room, "Colonne", Vector3.new(0.86, 9.12, 0.98), Vector3.new(x, 4.61, -1.78), yellow, true)
		if world.meshes.LiftBase then column.Transparency = 1 end
		if not world.meshes.LiftCarriage then
			part(world.carriage, "Bras du pont", Vector3.new(2.65, 0.25, 0.45), Vector3.new(x * 0.69, 0.46, -0.08), yellow)
		end
	end
	local lever = at(14.5, 10.0)
	part(room, "Pied du pont", Vector3.new(0.52, 2.41, 0.48), lever + Vector3.yAxis * 1.20, steel, true)
	part(room, "Pupitre", Vector3.new(1.42, 0.59, 1.22), lever + Vector3.yAxis * 2.64, yellow)
	part(room, "Poignée", Vector3.new(0.32, 0.45, 0.31), lever + Vector3.new(0, 3.13, 0.10), red)
	world.targets.Lever = target(room, "Levier", lever + Vector3.new(0, 3.21, 0.43))
	sign(world.targets.Lever, "PONT 01", 0.85)
end

local function cylinder(parent, name, width, diameter, center, color)
	local shape = part(parent, name, Vector3.new(width, diameter, diameter), center, color)
	shape.Shape = Enum.PartType.Cylinder
	return shape
end

local function buildVehicle(world)
	local vehicle = model(nil, "Berline client")
	world.vehicle = vehicle
	local origin = CFrame.new(0, 0.17, 0)
	local meshes = world.meshes
	local names = { "FrontLeft", "FrontRight", "BackLeft", "BackRight" }
	for _, variant in { "Sedan", "Sport" } do
		local body = model(vehicle, if variant == "Sport" then "Berline sport" else "Berline classique")
		local paint = if variant == "Sport" then teal else red
		if not cloneMesh(meshes[variant], body, origin) then
			part(body, "Carrosserie", Vector3.new(5.8, 1.56, 13.25), Vector3.new(0, 1.5, 0), paint)
			part(body, "Habitacle", Vector3.new(4.9, 1.36, 5.77), Vector3.new(0, if variant == "Sport" then 2.81 else 3.08, 0.77), steel)
			part(body, "Toit", Vector3.new(5.05, 0.22, 5.95), Vector3.new(0, if variant == "Sport" then 3.55 else 3.83, 0.77), paint)
		end
		local hood = cloneMesh(meshes[variant .. "Hood"], body, origin)
		if not hood then
			hood = part(body, "Capot", Vector3.new(4.0, 0.20, 2.5), Vector3.new(0, 2.78, -4.49), paint)
			hood.PivotOffset = CFrame.new(0, 0, 1.25)
		end
		world.bodies[variant] = { parts = body:GetChildren(), hood = hood, closed = hood:GetPivot() }
	end
	world.engineBay = model(vehicle, "Compartiment moteur")
	part(world.engineBay, "Plateau moteur", Vector3.new(3.74, 0.13, 2.44), Vector3.new(0, 2.11, -4.54), steel, false, Enum.Material.Metal)
	if not cloneMesh(meshes.Engine, world.engineBay, CFrame.new(-0.43, 2.15, -4.51)) then
		part(world.engineBay, "Moteur", Vector3.new(2.4, 0.55, 1.76), Vector3.new(-0.43, 2.41, -4.51), black, false, Enum.Material.Metal)
	end
	local batteryBase = Vector3.new(1.24, 2.11, -4.72)
	world.battery = cloneMesh(meshes.Battery, world.engineBay, CFrame.new(batteryBase))
		or part(world.engineBay, "Batterie", Vector3.new(0.96, 0.58, 0.68), batteryBase + Vector3.yAxis * 0.29, steel)
	part(world.engineBay, "Bouchon d’huile", Vector3.new(0.31, 0.13, 0.32), Vector3.new(-0.45, 2.71, -5.20), yellow)
	world.cargo.oldBattery = cloneMesh(meshes.Battery, vehicle, CFrame.new(1.21, 2.61, -5.64))
		or part(vehicle, "Batterie à recycler", Vector3.new(0.96, 0.58, 0.68), Vector3.new(1.21, 2.90, -5.64), steel)
	world.cargo.emptyBottle = part(vehicle, "Bidon vide", Vector3.new(0.51, 0.74, 0.33), Vector3.new(-1.28, 3.0, -5.54), trim)
	world.targets.Hood = target(vehicle, "Capot", Vector3.new(-0.12, 2.96, -6.46))
	world.targets.BatteryTray = target(vehicle, "Plateau de batterie", Vector3.new(1.25, 3.38, -5.18))
	world.targets.OilCap = target(vehicle, "Bouchon d’huile", Vector3.new(-0.45, 3.41, -5.30))
	world.targets.Drain = target(vehicle, "Bouchon de vidange", Vector3.new(0, 0.28, -6.3))
	local hull = part(vehicle, "Volume de la berline", Vector3.new(4.7, 2.72, 12.34), Vector3.new(0, 1.88, 0), red, true)
	hull.Transparency = 1
	for _, name in names do
		local left = name:find("Left") ~= nil
		local front = name:find("Front") ~= nil
		local side = if left then -1 else 1
		local tire = cloneMesh(meshes[name], vehicle, origin)
			or cylinder(vehicle, "Pneu", 0.98, 2.12, Vector3.new(side * 2.31, 1.23, if front then -3.70 else 3.43), black)
		local hub = tire.Position
		world.targets[name] = target(vehicle, name, hub + Vector3.xAxis * side * (tire.Size.X / 2 + 0.21))
		if front then
			local discCentre = hub + Vector3.xAxis * side * 0.25
			local originalDisc = cloneMesh(meshes.BrakeDisc, vehicle,
				CFrame.new(discCentre - Vector3.yAxis * 0.765) * CFrame.Angles(0, side * math.pi / 2, 0))
			local disc = originalDisc or cylinder(vehicle, "Disque", 0.25, 1.53, discCentre, trim)
			disc.Material = Enum.Material.Metal
			local caliper = part(vehicle, if originalDisc then "Plaquette neuve" else "Étrier",
				if originalDisc then Vector3.new(0.15, 0.18, 0.31) else Vector3.new(0.3, 0.68, 0.53),
				hub + Vector3.new(side * 0.39, 0.56, 0.12), teal)
			disc.Transparency = 1
			caliper.Transparency = 1
			world.wheels[name] = { tire = tire, home = tire.CFrame, disc = disc, caliper = caliper, originalDisc = originalDisc ~= nil,
				removed = CFrame.new(side * 6.28, tire.Size.X / 2 + 0.06, -4.85) * CFrame.Angles(0, 0, math.pi / 2) }
		end
	end
	world.targets.Door = target(vehicle, "Porte conducteur", Vector3.new(-3.52, 3.02, 0.45))
	world.headlights = {}
	for _, x in { -2.02, 2.02 } do
		local light = part(vehicle, "Feu de contrôle", Vector3.new(0.87, 0.20, 0.08), Vector3.new(x, 2.14, -6.88), yellow, false, Enum.Material.Neon)
		light.Transparency = 1
		table.insert(world.headlights, light)
	end
	world.room:SetAttribute("OriginalModels", meshes.Sedan ~= nil and meshes.SedanHood ~= nil and meshes.FrontLeft ~= nil
		and meshes.FrontRight ~= nil and meshes.BackLeft ~= nil and meshes.BackRight ~= nil and meshes.LiftBase ~= nil and meshes.Wrench ~= nil)
	world.room:SetAttribute("OriginalServiceModels", meshes.Battery ~= nil and meshes.Engine ~= nil
		and meshes.Sport ~= nil and meshes.SportHood ~= nil and meshes.BrakeDisc ~= nil)
end

local function tweenModel(actor, goal, duration, onMove, style)
	local pivot = Instance.new("CFrameValue")
	pivot.Value = actor:GetPivot()
	local connection = pivot.Changed:Connect(function(pose)
		actor:PivotTo(pose)
		if onMove then onMove(pose) end
	end)
	local tween = TweenService:Create(pivot, TweenInfo.new(duration, style or Enum.EasingStyle.Linear), { Value = goal })
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	pivot:Destroy()
	actor:PivotTo(goal)
	if onMove then onMove(goal) end
end

function World.build()
	local world = { room = model(workspace, "Le Petit Atelier"), targets = {}, spawns = {}, tools = {}, cargo = {}, gates = {}, wheels = {}, bodies = {} }
	buildShell(world)
	world.meshes = MeshLibrary.load()
	buildStations(world)
	buildBay(world)
	buildVehicle(world)
	Decor.build(world, part, cloneMesh)
	World.selectVehicle(world, "Sedan")
	return world
end

function World.setObjective(world, targetName)
	local objective = world.targets[targetName]
	world.objective.Adornee = objective
	world.objective.Enabled = objective ~= nil
end

function World.updateBoard(world, state, plan)
	Decor.updateBoard(world, state, plan, Repair.jobs)
end

function World.selectVehicle(world, variant)
	world.body = world.bodies[variant]
	for name, body in world.bodies do
		for _, panel in body.parts do panel.Transparency = if name == variant then 0 else 1 end
	end
	world.vehicle:SetAttribute("Carrosserie", variant)
end

function World.animate(world, motion)
	if motion == "raise" or motion == "lower" then
		local goal = world.liftBase + Vector3.yAxis * (if motion == "raise" then 2.85 else 0)
		tweenModel(world.carriage, goal, 0.9, function(pose)
			world.vehicle:PivotTo(world.dockPose + Vector3.yAxis * (pose.Y - world.liftBase.Y))
		end, Enum.EasingStyle.Sine)
	else
		local angle = if motion == "openHood" then 1.12 else 0
		tweenModel(world.body.hood, world.vehicle:GetPivot() * world.body.closed * CFrame.Angles(angle, 0, 0), 0.58, nil, Enum.EasingStyle.Sine)
	end
end

function World.testIgnition(world)
	for _, light in world.headlights do light.Transparency = 0 end
	task.delay(0.68, function()
		for _, light in world.headlights do light.Transparency = 1 end
	end)
end

function World.apply(world, state, repair)
	for phase, gate in world.gates do
		local open = state.phase == phase
		if open ~= gate.open then
			gate.open = open
			local height = if open then 0.37 else 8.15
			local position = gate.pose * CFrame.new(0, 8.15 - height / 2, 0)
			for _, panel in gate.panels do
				TweenService:Create(panel, TweenInfo.new(0.55, Enum.EasingStyle.Sine), {
					Size = Vector3.new(panel.Size.X, height, panel.Size.Z), CFrame = position,
				}):Play()
			end
		end
	end
	for name, parts in world.wheels do
		local removed = repair.removed[name] == true
		if removed and parts.tire.Parent ~= world.room then
			parts.tire.Parent = world.room
			parts.tire.CFrame = parts.removed
		elseif not removed and parts.tire.Parent ~= world.vehicle then
			parts.tire.Parent = world.vehicle
			parts.tire.CFrame = world.vehicle:GetPivot() * parts.home
		end
		parts.disc.Transparency = if removed then 0 else 1
		parts.caliper.Transparency = if removed and (repair.replaced[name] or not parts.originalDisc) then 0 else 1
		parts.caliper.Color = if repair.replaced[name] then mint else teal
	end
	for job, tool in world.tools do
		tool.Transparency = if repair.job == job and repair.toolOwner ~= 0 then 1 else 0
	end
	world.gaugeFace.Transparency = world.tools.pressure.Transparency
	for item, propPart in world.cargo do
		local show = if Repair.cargo[item].stock then not repair.carried[item] else state.phase == "repair" and Repair.canTake(repair, item)
		propPart.Transparency = if show then 0 else 1
	end
	local step = Repair.current(repair)
	local engineVisible = repair.hoodOpen or (repair.moving and step and step.motion == "openHood")
	for _, enginePart in world.engineBay:GetChildren() do enginePart.Transparency = if engineVisible then 0 else 1 end
	if repair.battery == "empty" then world.battery.Transparency = 1 end
	world.battery.Color = if repair.battery == "new" then Color3.fromRGB(225, 255, 225) else Color3.fromRGB(170, 168, 154)
end

function World.markParking(world, phase, ready)
	for _, group in { world.bayMarkers, world.parkingMarkers } do
		local active = (phase == "intake" and group == world.bayMarkers) or (phase == "outbound" and group == world.parkingMarkers)
		for _, marker in group do
			marker.Color = if active and ready then mint else yellow
			marker.Material = if active then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

function World.makeEquipment(world, key, title)
	local tool = Instance.new("Tool")
	tool.Name = title
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0.04, 0.28) * CFrame.Angles(0, math.pi / 2, 0)
	local handle = (world.tools[key] or world.cargo[key]):Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.Massless = true
	handle.Size *= 0.8
	handle.Transparency = 0
	handle.Parent = tool
	return tool
end

local customerColors = { Camille = teal, Noah = red, ["Léa"] = Color3.fromRGB(180, 138, 63), Alex = Color3.fromRGB(97, 111, 162) }

local function makeCustomer(world, name, position)
	local actor = model(world.room, name, CFrame.new(position))
	local shirt = customerColors[name] or teal
	local skin = Color3.fromRGB(216, 157, 116)
	part(actor, "Veste", Vector3.new(1.38, 1.62, 0.66), position + Vector3.yAxis * 2.62, shirt)
	part(actor, "Tête", Vector3.new(0.98, 1.02, 0.94), position + Vector3.yAxis * 3.87, skin)
	part(actor, "Cheveux", Vector3.new(1.01, 0.26, 0.96), position + Vector3.yAxis * 4.36, black)
	for _, x in { -1, 1 } do
		part(actor, "Bras", Vector3.new(0.38, 1.57, 0.50), position + Vector3.new(x * 0.90, 2.52, 0), shirt)
		part(actor, "Main", Vector3.new(0.38, 0.35, 0.49), position + Vector3.new(x * 0.90, 1.65, 0), skin)
		part(actor, "Jambe", Vector3.new(0.57, 1.52, 0.54), position + Vector3.new(x * 0.36, 1.0, 0), steel)
		part(actor, "Chaussure", Vector3.new(0.63, 0.30, 0.70), position + Vector3.new(x * 0.36, 0.16, -0.08), black)
		part(actor, "Œil", Vector3.new(0.10, 0.12, 0.035), position + Vector3.new(x * 0.215, 3.96, -0.485), black)
	end
	sign(target(actor, "Nom", position + Vector3.yAxis * 4.52), name, 0.28, 28)
	world.customer = actor
end

local function walk(world, points)
	local actor = world.customer
	if not actor then return end
	while world.walking do task.wait() end
	world.walking = true
	for _, point in points do
		local goal = at(point[1], point[2])
		local start = actor:GetPivot().Position
		local distance = (goal - start).Magnitude
		if distance > 0.05 then
			local rotation = CFrame.lookAt(start, goal).Rotation
			actor:PivotTo(CFrame.new(start) * rotation)
			tweenModel(actor, CFrame.new(goal) * rotation, math.max(0.13, distance / 20.5))
		end
	end
	world.walking = false
end

function World.arrive(world, order)
	world.vehicle:PivotTo(CFrame.new(at(21.1, 37.1)) * CFrame.Angles(0, math.pi / 2, 0))
	world.vehicle.Parent = world.room
	tweenModel(world.vehicle, CFrame.new(at(11.5, 36.2)) * CFrame.Angles(0, math.pi / 2, 0), 1.25)
	tweenModel(world.vehicle, world.arrivalPose, 1.28)
	makeCustomer(world, order.name, at(9.55, 27.85))
	walk(world, { {2.5, 15.4}, {2.5, 10.64} })
end

function World.waitCustomer(world)
	walk(world, { {3.53, 10.65}, {3.53, 8.52}, {2.71, 8.22}, {2.70, 5.62} })
end

function World.checkoutCustomer(world)
	walk(world, { {2.70, 8.25}, {3.55, 8.65}, {3.55, 10.66}, {1.55, 10.68} })
end

function World.depart(world)
	walk(world, { {3.55, 10.65}, {3.55, 8.57}, {2.72, 8.22}, {2.72, 6.28}, {5.52, 6.28},
		{5.56, 1.15}, {6.70, 0.47}, {6.70, -1.24}, {9.41, -3.69}, {9.41, -7.48} })
	world.customer:Destroy()
	world.customer = nil
	tweenModel(world.vehicle, CFrame.new(at(11.5, -14.2)), 1.04)
	tweenModel(world.vehicle, CFrame.new(at(21.1, -14.2)) * CFrame.Angles(0, -math.pi / 2, 0), 1.26)
	world.vehicle.Parent = nil
end

return World

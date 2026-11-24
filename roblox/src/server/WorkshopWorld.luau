local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layouts = {
	PetitAtelier = require(script.Parent.PetitAtelier),
	Tandem = require(script.Parent.Tandem),
}
local MeshLibrary = require(script.Parent.MeshLibrary)
local Decor = require(script.Parent.AtelierDecor)
local Gear = require(script.Parent.GearWorld)
local GarageProps = require(script.Parent.GarageProps)
local Doors = require(script.Parent.EntranceDoors)
local Furniture = require(script.Parent.Furniture)
local Repair = require(ReplicatedStorage.GarageDay.Repair)

local World = {}
local meshes
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

local function rectPart(world, name, rect, height, y, color, solid, material)
	local unit = world.layout.scale
	return part(world.room, name, Vector3.new(rect[3] * unit, height, rect[4] * unit), world.layout.centre(rect, y), color, solid, material)
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

local function prop(world, id, key, name, position, size, color, yaw)
	local pose = CFrame.new(position) * CFrame.Angles(0, yaw or 0, 0)
	local actor = model(world.room, name, pose)
	local shape = cloneMesh(world.meshes[key], actor, pose)
	local collision = part(actor, name, size, position, color, true)
	collision.CFrame = pose * CFrame.new(0, size.Y / 2, 0)
	if shape then collision.Transparency = 1 end
	Furniture.add(world, id, actor, size, target)
	return actor
end

local function plate(world, name, rect, color, label)
	local slab = rectPart(world, name, rect, 0.035, 0.045, color)
	local markers = {}
	for _, x in { rect[1], rect[1] + rect[3] } do
		table.insert(markers, rectPart(world, "Ligne", { x - 0.026, rect[2], 0.052, rect[4] }, 0.028, 0.08, yellow))
	end
	table.insert(markers, rectPart(world, "Ligne", { rect[1], rect[2], rect[3], 0.052 }, 0.028, 0.08, yellow))
	if label then sign(target(world.room, label, slab.Position), label, 1.15, 34) end
	return markers
end

local function buildShell(world)
	local room = world.room
	local layout = world.layout
	local at, unit = layout.at, layout.scale
	local width, depth, wing = layout.width, layout.depth, layout.wing
	Lighting.TimeOfDay = "15:45:00"
	Lighting.Brightness = 2.18
	Lighting.Ambient = Color3.fromRGB(129, 123, 117)
	Lighting.OutdoorAmbient = Color3.fromRGB(151, 154, 153)
	Lighting.ColorShift_Top = Color3.fromRGB(24, 13, 6)
	Lighting.EnvironmentDiffuseScale = 0.26
	Lighting.EnvironmentSpecularScale = 0.31
	Lighting.ShadowSoftness = 0.28
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Color = Color3.fromRGB(205, 224, 240)
	atmosphere.Decay = Color3.fromRGB(220, 182, 136)
	atmosphere.Density = 0.21
	atmosphere.Haze = 1.08
	atmosphere.Parent = Lighting

	rectPart(world, "Îlot du garage", {-1.5, -17, width + 7, 57.2}, 0.65, -0.42, Color3.fromRGB(110, 138, 101), true, Enum.Material.Grass)
	rectPart(world, "Cour et parvis", {0, -11, width, 45}, 0.18, -0.10, Color3.fromRGB(114, 123, 122), true, Enum.Material.Concrete)
	local asphalt = Color3.fromRGB(62, 72, 76)
	rectPart(world, "Route des arrivées", {0, 34, width + 4.5, 6.2}, 0.16, -0.08, asphalt, true, Enum.Material.Asphalt)
	rectPart(world, "Route de sortie", {0, -17, width + 4.5, 6}, 0.16, -0.08, asphalt, true, Enum.Material.Asphalt)
	rectPart(world, "Sol de l’atelier", {0, 0, width, depth}, 0.16, -0.06, concrete, true, Enum.Material.Concrete)
	rectPart(world, "Sol du bureau et de l’accueil", {0, 0, wing, depth}, 0.035, 0.037, trim, false, Enum.Material.WoodPlanks)
	rectPart(world, "Toit", {-0.17, -0.15, width + 0.34, depth + 0.3}, 0.42, roofHeight + 0.21, steel, true, Enum.Material.Metal)
	rectPart(world, "Plafond", {0, 0, width, depth}, 0.06, roofHeight - 0.045, Color3.fromRGB(185, 184, 168), false, Enum.Material.Plaster)
	for _, z in { depth * 0.27, depth * 0.60, depth * 0.86 } do
		rectPart(world, "Traverse du plafond", {0, z, width, 0.065}, 0.26, roofHeight - 0.19, steel, false, Enum.Material.Metal)
	end

	local function wallSection(rect, height, bottom)
		rectPart(world, "Mur", rect, height, bottom + height / 2, wall, true, Enum.Material.Plaster)
		if bottom == 0 then
			local fascia = { rect[1] - 0.016, rect[2] - 0.016, rect[3] + 0.032, rect[4] + 0.032 }
			rectPart(world, "Soubassement", fascia, 1.68, 0.84, Color3.fromRGB(102, 125, 113), false, Enum.Material.Concrete)
			rectPart(world, "Liseré mural", fascia, 0.12, 1.74, trim)
		end
	end
	for _, rect in layout.walls do wallSection(rect, roofHeight, 0) end
	for _, side in layout.sideWindows do
		local last = 0
		for _, opening in side.openings do
			local first, finish = opening[1], opening[2]
			wallSection({ side.x, last, 0.18, first - last }, roofHeight, 0)
			local window = { side.x, first, 0.18, finish - first }
			wallSection(window, 4.32, 0)
			wallSection(window, roofHeight - 8.0, 8.0)
			local glass = rectPart(world, "Vitre", { side.x + 0.075, first, 0.03, finish - first }, 3.68, 6.16,
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
		wallSection({ side.x, last, 0.18, depth - last }, roofHeight, 0)
	end
	for _, door in layout.pedestrianDoors do
		rectPart(world, "Linteau piéton", { door.left, door.z, door.right - door.left, 0.18 }, 2.25, roofHeight - 1.125, wall, true)
	end
	for _, rect in { {-1.47, -17, 0.11, 57.2}, {width + 5.37, -17, 0.11, 57.2}, {-1.5, -17, width + 7, 0.10}, {-1.5, 40.1, width + 7, 0.10} } do
		local fence = rectPart(world, "Limite de la cour", rect, 4, 2, steel, true)
		fence.Transparency = 1
	end
	for x = 1, width + 4, 3 do
		for _, z in { -14.36, 36.1 } do
			rectPart(world, "Marquage routier", { x, z, 1.4, 0.062 }, 0.026, 0.025, trim)
		end
	end
	for _, x in layout.lamps do
		for _, z in layout.lampRows do
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
		{ "BUREAU", layout.entry, layout.officeSplit - 0.48 },
		{ "SALLE D’ATTENTE", layout.entry, layout.receptionSplit - 0.96 },
		{ "ENTRÉE CLIENTS", layout.entry, depth + 0.03 },
		{ "PORTE PIÉTONNE", (layout.pedestrianDoors[2].left + layout.pedestrianDoors[2].right) / 2, depth },
		{ "SORTIE", layout.exit, -0.22 },
	} do
		sign(target(room, caption[1], at(caption[2], caption[3], 6.9)), caption[1], 0, 27)
	end
end

local function buildStations(world)
	local room = world.room
	local function station(point)
		return world.layout.at(table.unpack(world.layout.stations[point]))
	end
	for _, item in {
		{ "phone", "Desk", "Bureau", Vector3.new(5.6, 2.62, 2.55), trim },
		{ "officeChair", "Chair", "Chaise", Vector3.new(2.05, 2.68, 2.08), teal },
		{ "bookcase", "Bookcase", "Armoire", Vector3.new(2.3, 3.4, 1.4), trim },
		{ "waitingBench", "Bench", "Banquette", Vector3.new(2.26, 2.66, 2.68), teal, math.pi / 2 },
		{ "secondBench", "Bench", "Deuxième banquette", Vector3.new(2.26, 2.66, 2.68), teal, math.pi / 2 },
		{ "reception", "Reception", "Accueil et caisse", Vector3.new(5.75, 3.55, 2.5), trim, math.pi },
		{ "plant", "Plant", "Plante", Vector3.new(1.52, 2.1, 1.52), mint },
		{ "bench", "Workbench", "Établi", Vector3.new(2.86, 3.05, 2.62), teal },
		{ "partsChassis", "Shelf", "Pièces châssis", Vector3.new(2.62, 3.45, 2.52), teal },
		{ "partsElectric", "Shelf", "Pièces électriques", Vector3.new(2.62, 3.45, 2.52), teal },
		{ "wasteOil", "Drum", "Récupération d’huile", Vector3.new(1.84, 2.36, 1.84), steel },
		{ "trash", "Bin", "Poubelle", Vector3.new(1.85, 1.94, 1.85), teal },
		{ "counter", "Trolley", "Desserte", Vector3.new(2.76, 2.55, 2.45), teal },
	} do
		if world.layout.stations[item[1]] then
			prop(world, item[1], item[2], item[3], station(item[1]), item[4], item[5], item[6])
		end
	end
	local tandem = world.layout == Layouts.Tandem
	local toolsTurn = if tandem then 0 else -math.pi / 2
	for _, point in { "toolWrench", "toolPressure", "toolInspection", "toolOil" } do
		local cabinet = prop(world, point, "Cabinet", "Poste d’outillage", station(point), Vector3.new(2.73, 2.37, 2.45), red, toolsTurn)
		if tandem then
			-- Keep saved turns relative to the original cabinet orientation.
			local item = world.furniture[point]
			item.turn = 1
			cabinet:PivotTo(item.home * CFrame.Angles(0, math.pi / 2, 0))
		end
	end
	local phone = station("phone") + Vector3.new(-1.55, 2.81, -0.06)
	local desk = world.furniture.phone.model
	local reception = world.furniture.reception.model
	local counter = station("reception")
	part(desk, "Téléphone", Vector3.new(1.06, 0.31, 0.82), phone, steel)
	part(desk, "Combiné", Vector3.new(0.96, 0.15, 0.28), phone + Vector3.new(0, 0.20, -0.16), teal)
	part(reception, "Terminal", Vector3.new(0.97, 0.46, 0.86), counter + Vector3.new(-1.55, 3.52, -0.06), steel)
	part(reception, "Voyant de caisse", Vector3.new(0.8, 0.06, 0.19), counter + Vector3.new(-1.55, 3.79, 0.31), mint)
	local waste = station("wasteOil")
	local drum = world.furniture.wasteOil.model
	local lid = part(drum, "Couvercle du fût", Vector3.new(0.16, 1.91, 1.91), waste + Vector3.yAxis * 2.30, yellow, false, Enum.Material.Metal)
	lid.Shape = Enum.PartType.Cylinder
	lid.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	local inlet = part(drum, "Orifice pour l’huile", Vector3.new(0.08, 0.7, 0.7), waste + Vector3.yAxis * 2.41, black)
	inlet.Shape = Enum.PartType.Cylinder
	inlet.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	local recycling = station("recycling")
	local compressor = prop(world, "compressor", "Compressor", "Compresseur", station("compressor"), Vector3.new(2.1, 2.35, 1.64), teal, math.pi / 2)
	world.compressor = compressor:FindFirstChildWhichIsA("MeshPart")
	local layout = world.layout
	cloneMesh(world.meshes.Extinguisher, room, CFrame.new(layout.at(layout.width - 0.46, layout.depth - 1.33, 0.75)))
	local bin = prop(world, "recycling", "Bin", "Bac de recyclage", recycling, Vector3.new(1.85, 1.94, 1.85), teal)
	for _, entry in {
		{ "Phone", "TÉLÉPHONE", phone + Vector3.yAxis * 0.34, desk },
		{ "Reception", "ACCUEIL", counter + Vector3.new(1.64, 3.62, -1.12), reception },
		{ "Checkout", "CAISSE", counter + Vector3.new(-1.64, 3.75, -1.12), reception },
		{ "WasteOil", "HUILE USÉE", waste + Vector3.yAxis * 2.93, drum },
		{ "Recycling", "RECYCLAGE", recycling + Vector3.yAxis * 2.28, bin },
	} do
		local anchor = target(entry[4], entry[1], entry[3])
		world.targets[entry[1]] = anchor
		if entry[2] then sign(anchor, entry[2], 0.82, 24) end
	end
end

local function buildBay(world)
	local room = world.room
	local layout, spec = world.layout, world.spec
	local at = layout.at
	local index = "0" .. world.id
	rectPart(world, "Allée du pont", {spec.x - 1.65, 0.18, 3.3, layout.depth - 0.35}, 0.014, 0.068, Color3.fromRGB(95, 120, 115))
	world.bayMarkers = plate(world, "Baie " .. index, spec.dock, steel, "BAIE " .. index)
	world.parkingMarkers = plate(world, "Sortie P " .. index, spec.parking, teal, "P " .. index)
	plate(world, "Arrivée A " .. index, spec.arrival, trim, "A " .. index)
	world.dockPose = CFrame.new(layout.centre(spec.dock))
	world.parkingPose = CFrame.new(layout.centre(spec.parking))
	world.arrivalPose = CFrame.new(layout.centre(spec.arrival))
	world.targets.Dock = target(room, "Repère baie", world.dockPose.Position + Vector3.new(0, 0.2, -5.2))
	world.targets.Parking = target(room, "Repère sortie", world.parkingPose.Position + Vector3.new(0, 0.2, -5.9))

	local opening = 3.24 * layout.scale
	local gateHeight = 8.15
	local width = opening + 0.08
	for side, z in { intake = spec.intake, outbound = 0.09 } do
		local pose = CFrame.new(at(spec.x, z))
		local gate = model(room, (if side == "intake" then "Rideau d’entrée " else "Rideau de sortie ") .. index, pose)
		local skin = cloneMesh(world.meshes.Roller, gate, pose)
		local stop = part(gate, "Rideau", Vector3.new(width, gateHeight, 0.4), pose.Position + Vector3.yAxis * (gateHeight / 2), teal, true)
		if skin then
			skin.Size = Vector3.new(width, gateHeight, skin.Size.Z)
			skin.CFrame = stop.CFrame
			stop.Transparency = 1
		end
		for _, edge in { -opening / 2, opening / 2 } do
			part(room, "Glissière du rideau", Vector3.new(0.31, gateHeight, 0.71),
				pose.Position + Vector3.new(edge, gateHeight / 2, 0), steel, true, Enum.Material.Metal)
		end
		part(room, "Traverse", Vector3.new(opening + 0.31, roofHeight - gateHeight, 0.63),
			pose.Position + Vector3.yAxis * ((roofHeight + gateHeight) / 2), wall, true)
		world.gates[side] = { panels = { stop, skin }, pose = pose, height = gateHeight, open = false }
	end

	local pivot = CFrame.new(at(spec.x, spec.z, 0.06) - Vector3.zAxis * 1.74)
	world.liftBase = pivot
	world.carriage = model(room, "Plateforme mobile", pivot)
	cloneMesh(world.meshes.LiftBase, room, pivot)
	cloneMesh(world.meshes.LiftCarriage, world.carriage, pivot)
	for _, x in { -4.72, 4.72 } do
		local column = part(room, "Colonne", Vector3.new(0.86, 9.12, 0.98), pivot.Position + Vector3.new(x, 4.55, -0.04), yellow, true)
		if world.meshes.LiftBase then column.Transparency = 1 end
		if not world.meshes.LiftCarriage then
			part(world.carriage, "Bras du pont", Vector3.new(2.65, 0.25, 0.45), pivot.Position + Vector3.new(x * 0.69, 0.4, 1.66), yellow)
		end
	end
	local lever = at(table.unpack(spec.lever))
	part(room, "Pied du pont", Vector3.new(0.52, 2.41, 0.48), lever + Vector3.yAxis * 1.20, steel, true)
	part(room, "Pupitre", Vector3.new(1.42, 0.59, 1.22), lever + Vector3.yAxis * 2.64, yellow)
	part(room, "Poignée", Vector3.new(0.32, 0.45, 0.31), lever + Vector3.new(0, 3.13, 0.10), red)
	world.targets.Lever = target(room, "Levier", lever + Vector3.new(0, 3.21, 0.43))
	sign(world.targets.Lever, "PONT " .. index, 0.85)
	local bench = world.root.furniture[if world.id == 2 then "secondBench" else "waitingBench"].model
	world.targets.Quote = target(bench, "Client de la baie " .. index, bench:GetPivot().Position + Vector3.new(1.8, 3.1, 0))
	if #layout.bays > 1 then
		for _, key in { "Reception", "Checkout", "Snack" } do
			local original = world.root.targets[key]
			world.targets[key] = target(original.Parent, key .. " " .. index,
				original.WorldPosition + Vector3.xAxis * (if world.id == 1 then -0.57 else 0.57))
		end
	end
end

local function cylinder(parent, name, width, diameter, center, color)
	local shape = part(parent, name, Vector3.new(width, diameter, diameter), center, color)
	shape.Shape = Enum.PartType.Cylinder
	return shape
end

local function buildVehicle(world)
	local vehicle = model(nil, "Berline client 0" .. world.id)
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
	for name, position in {
		Hood = Vector3.new(-0.12, 2.96, -6.46), BatteryTray = Vector3.new(1.25, 3.38, -5.18),
		OilCap = Vector3.new(-0.45, 3.41, -5.30), Drain = Vector3.new(0, 0.28, -6.3),
		DiagnosticPort = Vector3.new(-1.08, 3.57, -5.68), Radiator = Vector3.new(0.77, 3.55, -5.97),
		Belt = Vector3.new(-0.97, 3.52, -5.30), Wipers = Vector3.new(-1.60, 3.65, -3.12),
		Window = Vector3.new(3.36, 3.42, 0.10), FrontLamp = Vector3.new(2.0, 2.22, -6.67),
		RearLamp = Vector3.new(2.0, 2.17, 6.69), Exhaust = Vector3.new(0.95, 0.46, 6.49),
		DamperLeft = Vector3.new(-3.11, 1.47, 2.90), DamperRight = Vector3.new(3.11, 1.47, 2.90),
		Door = Vector3.new(-3.52, 3.02, 0.45),
	} do
		world.targets[name] = target(vehicle, name, position)
	end
	local components = {
		Battery = { world.battery },
		Belt = { cylinder(world.engineBay, "Courroie", 0.12, 0.72, Vector3.new(-1.62, 2.43, -4.68), black) },
		Muffler = { cloneMesh(meshes.Muffler, vehicle, CFrame.new(0.94, 0.46, 5.88))
			or part(vehicle, "Silencieux", Vector3.new(2.91, 0.34, 0.93), Vector3.new(0.94, 0.46, 5.88), steel) },
		Shield = { part(vehicle, "Cache moteur", Vector3.new(3.22, 0.11, 2.18), Vector3.new(0, 0.42, -4.94), black) },
		Wipers = {},
	}
	part(world.engineBay, "Radiateur", Vector3.new(3.15, 0.71, 0.17), Vector3.new(0, 2.33, -5.76), steel, false, Enum.Material.Metal)
	part(world.engineBay, "Bouchon du radiateur", Vector3.new(0.27, 0.13, 0.26), Vector3.new(0.77, 2.74, -5.76), mint)
	world.wiperHomes = {}
	for _, x in { -1.34, 0.65 } do
		local blade = part(vehicle, "Balai d’essuie-glace", Vector3.new(1.07, 0.065, 0.074), Vector3.new(x, 3.10, -3.43), black)
		blade.CFrame *= CFrame.Angles(0, math.rad(19), math.rad(14))
		table.insert(components.Wipers, blade)
		world.wiperHomes[blade] = blade.CFrame
	end
	world.windowPane = part(vehicle, "Vitre passager", Vector3.new(0.033, 0.70, 1.70), Vector3.new(2.39, 3.06, -0.60),
		Color3.fromRGB(131, 176, 179), false, Enum.Material.Glass)
	world.windowPane.Transparency = 1
	world.windowHome = world.windowPane.CFrame
	for _, side in { -1, 1 } do
		local position = Vector3.new(side * 2.08, 0.64, 3.16)
		components[if side < 0 then "DamperLeft" else "DamperRight"] = {
			cloneMesh(meshes.Damper, vehicle, CFrame.new(position))
				or part(vehicle, "Amortisseur", Vector3.new(0.24, 1.10, 0.25), position, red),
		}
	end
	world.components = components
	world.originalColors = {}
	for _, pieces in components do
		for _, piece in pieces do world.originalColors[piece] = piece.Color end
	end
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
		local discCentre = hub + Vector3.xAxis * side * 0.25
		local disc = cloneMesh(meshes.BrakeDisc, vehicle,
			CFrame.new(discCentre - Vector3.yAxis * 0.765) * CFrame.Angles(0, side * math.pi / 2, 0))
			or cylinder(vehicle, "Disque", 0.25, 1.53, discCentre, trim)
		disc.Material = Enum.Material.Metal
		local caliper = part(vehicle, "Étrier", Vector3.new(0.21, 0.28, 0.39), hub + Vector3.new(side * 0.39, 0.56, 0.12), teal)
		local bearing = cylinder(vehicle, "Moyeu", 0.21, 0.37, hub + Vector3.xAxis * side * 0.47, trim)
		world.wheels[name] = { tire = tire, paint = tire.Color, disc = disc, caliper = caliper, bearing = bearing }
	end
	world.lamps = {}
	for _, name in { "FrontLamp", "RearLamp" } do
		world.lamps[name] = {}
		for _, x in { -2.02, 2.02 } do
			local front = name == "FrontLamp"
			local light = part(vehicle, "Feu de contrôle", Vector3.new(0.82, 0.16, 0.08),
				Vector3.new(x, 2.14, if front then -6.79 else 6.77), if front then yellow else red, false, Enum.Material.Neon)
			light.Transparency = 1
			table.insert(world.lamps[name], light)
		end
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

function World.build(map)
	local layout = Layouts[map]
	local world = { room = model(workspace, layout.name), layout = layout, targets = {}, spawns = {}, furniture = {}, bays = {} }
	buildShell(world)
	meshes = meshes or MeshLibrary.load()
	world.meshes = meshes
	buildStations(world)
	Gear.build(world, part, cloneMesh, target, sign, model)
	GarageProps.build(world, part, model, cloneMesh, target, sign)
	for i, spec in layout.bays do
		local bay = {
			id = i, root = world, room = world.room, layout = layout, spec = spec, meshes = meshes, spawns = world.spawns,
			targets = table.clone(world.targets), gearTemplates = world.gearTemplates, gearTarget = target,
			gates = {}, wheels = {}, bodies = {},
		}
		buildBay(bay)
		buildVehicle(bay)
		Gear.buildBay(bay)
		World.selectVehicle(bay, "Sedan")
		world.bays[i] = bay
	end
	for i, rect in layout.arrivals do
		if rect ~= layout.bays[1].arrival then
			plate(world, "File d’attente " .. i, rect, teal, nil)
		end
	end
	Decor.build(world, part, cloneMesh)
	world.doors = Doors.build(world.room, part, model, roofHeight - 2.25, layout)
	return world
end

function World.destroy(world)
	world.vendor:Destroy()
	for _, bay in world.bays do bay.vehicle:Destroy() end
	for _, stock in world.stocks do stock.model:Destroy() end
	for _, prop in world.upgradeProps do prop:Destroy() end
	for _, scrap in world.scrapVisuals do scrap:Destroy() end
	world.room:Destroy()
end

function World.setObjective(world, targetName)
	local objective = if typeof(targetName) == "Instance" then targetName else world.targets[targetName]
	world.objective.Adornee = objective
	world.objective.Enabled = objective ~= nil
end

function World.updateBoard(world, state)
	Decor.updateBoard(world, state, Repair.jobs)
end

function World.selectVehicle(world, variant)
	world.history = { wheels = {}, components = {} }
	world.body = world.bodies[variant]
	for name, body in world.bodies do
		for _, panel in body.parts do panel.Transparency = if name == variant then 0 else 1 end
	end
	world.vehicle:SetAttribute("Carrosserie", variant)
end

local function sound(anchor, file, speed, volume)
	local cue = Instance.new("Sound")
	cue.SoundId = "rbxasset://sounds/" .. file
	cue.PlaybackSpeed = speed
	cue.Volume = volume
	cue.RollOffMaxDistance = 25
	cue.Parent = anchor
	cue:Play()
	Debris:AddItem(cue, 3)
	return cue
end

function World.sound(anchor, action)
	if action == "loosen" or action == "tighten" then
		sound(anchor, "action_jump_land.mp3", 1.85, 0.45)
		task.delay(0.08, function()
			if anchor:IsDescendantOf(workspace) then sound(anchor, "action_jump_land.mp3", 2.1, 0.35) end
		end)
	elseif action:find("fill") or action:find("drain") or action == "recycle_usedOil" then
		sound(anchor, "impact_water.mp3", 1.26, 0.37)
	elseif action == "snap" or action == "closeHood" or action == "lower" then
		sound(anchor, "action_jump_land.mp3", 0.85, 0.52)
	elseif action:find("recycle") or action == "drop" then
		sound(anchor, "action_jump_land.mp3", 0.74, 0.42)
	else
		sound(anchor, "volume_slider.ogg", 0.87, 0.29)
	end
end

function World.animate(world, motion, liftTime)
	local anchor = world.targets[if motion == "raise" or motion == "lower" then "Lever" else "Hood"]
	if motion == "raise" or motion == "lower" then
		local motor = sound(anchor, "action_footsteps_plastic.mp3", 1.65, 0.16)
		local goal = world.liftBase + Vector3.yAxis * (if motion == "raise" then 2.85 else 0)
		tweenModel(world.carriage, goal, liftTime, function(pose)
			world.vehicle:PivotTo(world.dockPose + Vector3.yAxis * (pose.Y - world.liftBase.Y))
		end, Enum.EasingStyle.Sine)
		motor:Destroy()
	else
		local angle = if motion == "openHood" then 1.12 else 0
		tweenModel(world.body.hood, world.vehicle:GetPivot() * world.body.closed * CFrame.Angles(angle, 0, 0), 0.58, nil, Enum.EasingStyle.Sine)
	end
	World.sound(anchor, motion)
end

function World.effect(world, step, root)
	local action = step.action
	local pivot = world.vehicle:GetPivot()
	local anchor = world.targets[step.target]
	if action == "removeWheel" then
		local tire = world.wheels[step.wheel].tire
		local side = if step.wheel:find("Left") then -1 else 1
		world.pieceMotion[step.output] = tire.CFrame + pivot.RightVector * side * 0.63
	elseif action == "mountWheel" then
		local wheel = world.wheels[step.wheel]
		local tire = wheel.tire
		local side = if step.wheel:find("Left") then -1 else 1
		local home = tire.CFrame
		tire.CFrame = home + pivot.RightVector * side * 0.76 + Vector3.yAxis * 0.15
		local profile = TweenInfo.new(0.19, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local snap = TweenService:Create(tire, profile, { CFrame = home })
		snap.Completed:Once(function()
			if anchor:IsDescendantOf(workspace) then World.sound(anchor, "snap") end
		end)
		snap:Play()
	elseif action == "recycle_usedOil" then
		local point = anchor.WorldPosition
		Gear.toss(world.root, "usedOil", CFrame.new(point + Vector3.yAxis * 0.53),
			CFrame.new(point + Vector3.yAxis * 0.57) * CFrame.Angles(0.28, 0, 0.72))
		World.sound(anchor, action)
	elseif (action:find("^recycle_") or action == "recyclePuncture") and step.cargo then
		local point = anchor.WorldPosition
		local direction = (point - root.Position) * Vector3.new(1, 0, 1)
		local unit = if direction.Magnitude > 0.1 then direction.Unit else Vector3.xAxis
		local from = CFrame.new(point - unit * 1.15 + Vector3.yAxis * 0.75)
		local to = CFrame.new(point + unit * 1.5 - Vector3.yAxis * 0.42) * CFrame.Angles(0.95, 0.45, 0.7)
		Gear.toss(world.root, step.cargo, from, to)
		task.delay(0.27, function()
			if anchor:IsDescendantOf(workspace) then
				World.sound(anchor, action)
				if step.target == "TireBin" then Gear.recycle(world.root, step.cargo) end
			end
		end)
	elseif not step.quote then
		World.sound(anchor, action)
	end
	if action:find("^fill") or action:find("^drain") or action == "recycle_usedOil" then
		local pour = Instance.new("ParticleEmitter")
		pour.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pour.Color = ColorSequence.new(if action == "fillCoolant" then Color3.fromRGB(137, 213, 167) else Color3.fromRGB(115, 77, 37))
		pour.LightInfluence = 1
		pour.Enabled = false
		pour.EmissionDirection = Enum.NormalId.Bottom
		pour.Acceleration = -Vector3.yAxis * 10
		pour.Size = NumberSequence.new(0.08, 0.035)
		pour.Lifetime = NumberRange.new(0.24, 0.43)
		pour.Speed = NumberRange.new(0.7, 1.6)
		pour.Parent = anchor
		pour:Emit(22)
		Debris:AddItem(pour, 1)
	end
	if action == "ignition" or action == "testLights" or action == "verifyLights" then
		world.lightTest = (world.lightTest or 0) + 1
		local test = world.lightTest
		for key, lights in world.lamps do
			for index, light in lights do light.Transparency = if key == step.component and index == 2 then 1 else 0 end
		end
		task.delay(0.85, function()
			if test ~= world.lightTest then return end
			for _, lights in world.lamps do
				for _, light in lights do light.Transparency = 1 end
			end
		end)
	elseif action == "testWipers" then
		for blade, home in world.wiperHomes do
			local sweep = TweenService:Create(blade, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), {
				CFrame = pivot * home * CFrame.Angles(0, -1.0, 0.42),
			})
			sweep:Play()
		end
	elseif action == "testWindow" or action == "verifyWindow" then
		local pane = world.windowPane
		pane.Transparency = 0.35
		pane.CFrame = pivot * world.windowHome
		local run = TweenService:Create(pane, TweenInfo.new(0.34, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), {
			CFrame = pane.CFrame - Vector3.yAxis * (if action == "testWindow" then 0.14 else 0.69),
		})
		run.Completed:Once(function() pane.Transparency = 1 end)
		run:Play()
	end
end

function World.recordRepair(world, repair)
	for key, value in repair.wheels do
		if world.history.wheels[key] ~= "new" or value == "new" then world.history.wheels[key] = value end
	end
	for key, value in repair.components do world.history.components[key] = value end
end

function World.apply(world, lane, repair)
	for phase, gate in world.gates do
		local open = (phase == "intake" and lane.phase == "intake") or (phase == "outbound" and lane.phase == "outbound")
		if open ~= gate.open then
			gate.open = open
			local height = if open then 0.37 else gate.height
			local position = gate.pose * CFrame.new(0, gate.height - height / 2, 0)
			for _, panel in gate.panels do
				TweenService:Create(panel, TweenInfo.new(0.55, Enum.EasingStyle.Sine), {
					Size = Vector3.new(panel.Size.X, height, panel.Size.Z), CFrame = position,
				}):Play()
			end
		end
	end
	local history = world.history
	for name, wheel in world.wheels do
		local status = repair.wheels[name] or history.wheels[name]
		local pads = repair.components["Pads" .. name] or history.components["Pads" .. name]
		local bearing = repair.components["Bearing" .. name] or history.components["Bearing" .. name]
		local removed = status == "removed"
		wheel.tire.Transparency = if removed then 1 else 0
		wheel.tire.Color = if status == "new" or history.wheels[name] == "new" then wheel.paint:Lerp(Color3.fromRGB(224, 230, 227), 0.07) else wheel.paint
		wheel.disc.Transparency = if removed then 0 else 1
		wheel.caliper.Transparency = if pads == "removed" then 1 else wheel.disc.Transparency
		wheel.caliper.Color = if pads == "new" then mint else teal
		wheel.bearing.Transparency = if removed and bearing ~= "removed" then 0 else 1
		wheel.bearing.Color = if bearing == "new" then Color3.fromRGB(213, 223, 220) else trim
	end
	local step = Repair.current(repair)
	local engineVisible = repair.hoodOpen or (repair.moving and step and step.motion == "openHood")
	for _, enginePart in world.engineBay:GetChildren() do enginePart.Transparency = if engineVisible then 0 else 1 end
	for key, pieces in world.components do
		local status = repair.components[key] or history.components[key]
		for _, piece in pieces do
			piece.Transparency = if status == "removed" or (piece.Parent == world.engineBay and not engineVisible) then 1 else 0
			local base = world.originalColors[piece]
			piece.Color = if status == "new" then base:Lerp(Color3.fromRGB(204, 220, 220), 0.21) else base
		end
	end
	Gear.sync(world, repair)
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
	return Gear.equipment(world, key, title)
end

function World.setEvening(world, evening)
	TweenService:Create(Lighting, TweenInfo.new(1.7, Enum.EasingStyle.Sine), {
		ClockTime = if evening then 18.05 else 14.2,
		Brightness = if evening then 1.6 else 2.22,
		OutdoorAmbient = if evening then Color3.fromRGB(136, 143, 154) else Color3.fromRGB(152, 162, 156),
	}):Play()
	Decor.setEvening(world, evening)
end

function World.moveVendor(world, arriving)
	local vendor = world.vendor
	if arriving then
		vendor:PivotTo(world.vendorEntry)
		vendor.Parent = world.room
		World.setEvening(world, true)
		tweenModel(vendor, world.vendorParking, 2.15, nil, Enum.EasingStyle.Sine)
	else
		World.setEvening(world, false)
		tweenModel(vendor, world.vendorEntry, 1.85, nil, Enum.EasingStyle.Sine)
		vendor.Parent = nil
	end
end

function World.restoreVendor(world)
	world.vendor:PivotTo(world.vendorParking)
	world.vendor.Parent = world.room
	World.setEvening(world, true)
end

function World.updateDoors(world, players, now)
	local positions = {}
	for _, player in players do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then table.insert(positions, root.Position) end
	end
	for _, bay in world.bays do
		if bay.customer then table.insert(positions, bay.customer:GetPivot().Position) end
	end
	table.insert(positions, world.cart.model:GetPivot().Position)
	Doors.update(world.doors, positions, now)
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
	local marker = Instance.new("BillboardGui")
	marker.Name = "Patience"
	marker.Adornee = actor:FindFirstChild("Tête")
	marker.StudsOffsetWorldSpace = Vector3.yAxis * 0.75
	marker.Size = UDim2.fromOffset(80, 6)
	marker.MaxDistance = 26
	marker.Parent = actor
	local track = Instance.new("Frame")
	track.Size = UDim2.fromScale(1, 1)
	track.BorderSizePixel = 0
	track.BackgroundColor3 = steel
	track.Parent = marker
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = mint
	fill.Parent = track
	world.customerPatience = fill
	world.customer = actor
end

function World.updatePatience(world, fraction, late)
	local fill = world.customerPatience
	if not fill then return end
	fill.Size = UDim2.fromScale(if late then 1 else fraction, 1)
	fill.BackgroundColor3 = if late then red elseif fraction < 0.3 then yellow else mint
end

local function walk(world, points)
	local actor = world.customer
	if not actor then return end
	while world.walking do task.wait() end
	world.walking = true
	for _, point in points do
		local goal = if typeof(point) == "Vector3" then point * Vector3.new(1, 0, 1) else world.layout.at(point[1], point[2])
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
	local layout, x = world.layout, world.spec.x
	while world.root.arrivalTraffic do task.wait() end
	world.root.arrivalTraffic = true
	world.vehicle:PivotTo(CFrame.new(layout.at(layout.width + 3.1, 37.1)) * CFrame.Angles(0, math.pi / 2, 0))
	world.vehicle.Parent = world.room
	tweenModel(world.vehicle, CFrame.new(layout.at(x, 36.2)) * CFrame.Angles(0, math.pi / 2, 0), 1.25)
	tweenModel(world.vehicle, world.arrivalPose, 1.28)
	world.root.arrivalTraffic = false
	makeCustomer(world, order.name, world.arrivalPose.Position - Vector3.xAxis * 5.7)
	walk(world, { {layout.entry, layout.depth + 2.4}, {layout.entry, layout.depth - 0.65},
		world.targets.Reception.WorldPosition + Vector3.zAxis * 3.9 })
end

function World.waitCustomer(world)
	local layout = world.layout
	walk(world, { {layout.entry + 0.77, layout.depth - 0.85}, {layout.entry + 0.59, layout.receptionSplit + 0.6},
		{layout.entry, layout.receptionSplit - 0.62}, world.targets.Quote.WorldPosition })
end

function World.checkoutCustomer(world)
	local layout = world.layout
	walk(world, { {layout.entry, layout.receptionSplit - 0.52}, {layout.entry + 0.46, layout.receptionSplit + 0.52},
		{layout.entry + 0.79, layout.depth - 1.20}, world.targets.Checkout.WorldPosition + Vector3.zAxis * 4.4 })
end

function World.depart(world)
	local layout = world.layout
	local interior = if #layout.bays == 2 then 8.7 else 6.28
	walk(world, { {layout.entry + 0.60, layout.depth - 1.15}, {layout.entry, layout.receptionSplit + 0.52},
		{layout.entry, layout.receptionSplit - 0.63}, {layout.entry, interior}, {layout.exit, interior},
		{layout.exit, 1.15}, {layout.exit, -1.24}, {world.spec.x - 1.7, -5.8}, {world.spec.x - 1.6, -7.48} })
	if world.customer then world.customer:Destroy() end
	world.customer, world.customerPatience = nil, nil
	while world.root.outboundTraffic do task.wait() end
	world.root.outboundTraffic = true
	tweenModel(world.vehicle, CFrame.new(layout.at(world.spec.x, -14.2)), 1.04)
	tweenModel(world.vehicle, CFrame.new(layout.at(layout.width + 3.1, -14.2)) * CFrame.Angles(0, -math.pi / 2, 0), 1.26)
	world.vehicle.Parent = nil
	world.root.outboundTraffic = false
end

return World

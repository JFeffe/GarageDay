local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Layout = require(script.Parent.PetitAtelier)
local MeshLibrary = require(script.Parent.MeshLibrary)

local World = {}
local at = Layout.at
local unit = Layout.scale
local roofHeight = 9.85
local concrete = Color3.fromRGB(166, 180, 170)
local wall = Color3.fromRGB(226, 220, 198)
local trim = Color3.fromRGB(198, 174, 137)
local steel = Color3.fromRGB(48, 64, 68)
local teal = Color3.fromRGB(68, 109, 111)
local yellow = Color3.fromRGB(242, 192, 88)
local mint = Color3.fromRGB(140, 224, 166)
local red = Color3.fromRGB(200, 77, 54)
local black = Color3.fromRGB(34, 43, 45)

local function part(parent, name, size, position, color, solid)
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Size = size
	instance.Position = position
	instance.Color = color
	instance.Material = Enum.Material.SmoothPlastic
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

local function rectPart(parent, name, rect, height, y, color, solid)
	return part(parent, name, Vector3.new(rect[3] * unit, height, rect[4] * unit), Layout.centre(rect, y), color, solid)
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
	Lighting.ClockTime = 14.3
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(128, 129, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 152, 151)
	Lighting.GlobalShadows = true

	rectPart(room, "Îlot du garage", {-1.5, -17, 25, 57.2}, 0.65, -0.42, Color3.fromRGB(110, 143, 113), true)
	rectPart(room, "Cour et parvis", {0, -11, 18, 45}, 0.18, -0.10, concrete, true)
	rectPart(room, "Route des arrivées", {0, 34, 22.5, 6.2}, 0.16, -0.08, steel, true)
	rectPart(room, "Route de sortie", {0, -17, 22.5, 6}, 0.16, -0.08, steel, true)
	rectPart(room, "Sol de l’atelier", {0, 0, 18, 13}, 0.16, -0.06, concrete, true)
	rectPart(room, "Sol du bureau et de l’accueil", {0, 0, 4.9, 13}, 0.035, 0.037, trim)
	rectPart(room, "Toit", {0, 0, 18, 13}, 0.27, roofHeight + 0.135, wall, true)

	for _, rect in Layout.walls do
		rectPart(room, "Mur", rect, roofHeight, roofHeight / 2, wall, true)
		rectPart(room, "Soubassement", { rect[1] - 0.012, rect[2] - 0.012, rect[3] + 0.024, rect[4] + 0.024 }, 1.65, 0.825, trim)
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
			local lamp = part(room, "Rampe d’atelier", Vector3.new(0.5, 0.13, 4.1), at(x, z, roofHeight - 0.23), wall)
			lamp.Material = Enum.Material.Neon
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 17
			light.Angle = 112
			light.Brightness = 0.96
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
	world.pads = part(room, "Plaquettes", Vector3.new(1.06, 0.33, 0.7), at(6.5, 10.28, 2.68), yellow)
	for _, entry in {
		{ "Phone", "TÉLÉPHONE", phone + Vector3.yAxis * 0.34 },
		{ "Reception", "ACCUEIL", at(2.53, 9.14, 3.62) }, { "Checkout", "CAISSE", at(1.47, 9.14, 3.75) },
		{ "Toolbrakes", "CLÉ À CHOC", wrenchPos + Vector3.new(-0.53, 0.82, 0) },
		{ "Toolpressure", "PRESSION", gaugePos + Vector3.new(-0.53, 0.24, 0) },
		{ "Pads", "PLAQUETTES", at(6.52, 10.05, 2.93) },
	} do
		local anchor = target(room, entry[1], entry[3])
		world.targets[entry[1]] = anchor
		sign(anchor, entry[2], 0.82, 24)
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

	for side, z in { intake = 12.93, outbound = 0.07 } do
		local pose = CFrame.new(at(11.5, z))
		local gate = model(room, if side == "intake" then "Rideau d’entrée" else "Rideau de sortie", pose)
		local skin = cloneMesh(world.meshes.Roller, gate, pose)
		local stop = part(gate, "Rideau", Vector3.new(9.35, 8.15, 0.43), pose.Position + Vector3.yAxis * 4.075, teal, true)
		if skin then stop.Transparency = 1 end
		part(room, "Traverse", Vector3.new(9.7, roofHeight - 8.15, 0.63), pose.Position + Vector3.yAxis * ((roofHeight + 8.15) / 2), wall, true)
		world.gates[side] = { model = gate, pose = pose }
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
	local original = meshes.Sedan and meshes.FrontLeft and meshes.FrontRight and meshes.BackLeft and meshes.BackRight
	if original then
		cloneMesh(meshes.Sedan, vehicle, origin)
	else
		part(vehicle, "Carrosserie", Vector3.new(5.9, 1.55, 13.4), Vector3.new(0, 1.7, 0), red)
		part(vehicle, "Habitacle", Vector3.new(4.9, 1.43, 5.8), Vector3.new(0, 3.07, 0.75), teal)
		part(vehicle, "Toit", Vector3.new(5.05, 0.25, 5.95), Vector3.new(0, 3.85, 0.75), red)
	end
	local hull = part(vehicle, "Volume de la berline", Vector3.new(4.7, 2.72, 12.34), Vector3.new(0, 1.88, 0), red, true)
	hull.Transparency = 1
	for _, name in names do
		local left = name:find("Left") ~= nil
		local front = name:find("Front") ~= nil
		local side = if left then -1 else 1
		local tire = if original then cloneMesh(meshes[name], vehicle, origin)
			else cylinder(vehicle, "Pneu", 0.98, 2.12, Vector3.new(side * 2.31, 1.23, if front then -3.70 else 3.43), black)
		local hub = tire.Position
		world.targets[name] = target(vehicle, name, hub + Vector3.xAxis * side * (tire.Size.X / 2 + 0.21))
		if front then
			local disc = cylinder(vehicle, "Disque", 0.25, 1.53, hub + Vector3.xAxis * side * 0.25, trim)
			disc.Material = Enum.Material.Metal
			local caliper = part(vehicle, "Étrier", Vector3.new(0.3, 0.68, 0.53), hub + Vector3.new(side * 0.33, 0.50, 0.12), teal)
			disc.Transparency = 1
			caliper.Transparency = 1
			world.wheels[name] = { tire = tire, home = tire.CFrame, disc = disc, caliper = caliper,
				removed = CFrame.new(side * 6.28, tire.Size.X / 2 + 0.06, -4.85) * CFrame.Angles(0, 0, math.pi / 2) }
		end
	end
	world.targets.Door = target(vehicle, "Porte conducteur", Vector3.new(-3.52, 3.02, 0.45))
	world.room:SetAttribute("OriginalModels", original ~= nil and meshes.LiftBase ~= nil and meshes.Wrench ~= nil)
end

local function tweenModel(actor, goal, duration, onMove)
	local pivot = Instance.new("CFrameValue")
	pivot.Value = actor:GetPivot()
	local connection = pivot.Changed:Connect(function(pose)
		actor:PivotTo(pose)
		if onMove then onMove(pose) end
	end)
	local tween = TweenService:Create(pivot, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = goal })
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	pivot:Destroy()
	actor:PivotTo(goal)
	if onMove then onMove(goal) end
end

function World.build()
	local world = { room = model(workspace, "Le Petit Atelier"), targets = {}, spawns = {}, tools = {}, gates = {}, wheels = {} }
	buildShell(world)
	world.meshes = MeshLibrary.load()
	buildStations(world)
	buildBay(world)
	buildVehicle(world)
	return world
end

function World.moveLift(world, up)
	local goal = world.liftBase + Vector3.yAxis * (if up then 2.85 else 0)
	tweenModel(world.carriage, goal, 0.9, function(pose)
		world.vehicle:PivotTo(world.dockPose + Vector3.yAxis * (pose.Y - world.liftBase.Y))
	end)
end

function World.apply(world, state, repair)
	for phase, gate in world.gates do
		gate.model:PivotTo(gate.pose + Vector3.yAxis * (if state.phase == phase then 8.4 else 0))
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
		parts.caliper.Transparency = parts.disc.Transparency
		parts.caliper.Color = if repair.replaced[name] then mint else teal
	end
	for job, tool in world.tools do
		tool.Transparency = if repair.job == job and repair.toolOwner ~= 0 then 1 else 0
	end
	world.gaugeFace.Transparency = world.tools.pressure.Transparency
	world.pads.Transparency = if repair.padsOwner ~= 0 then 1 else 0
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

function World.makeTool(world, job, title)
	local tool = Instance.new("Tool")
	tool.Name = title
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.37, 0.24) * CFrame.Angles(0, math.pi / 2, 0)
	local handle = world.tools[job]:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.Massless = true
	handle.Transparency = 0
	handle.Parent = tool
	return tool
end

local function makeCustomer(world, name, position)
	local actor = model(world.room, name, CFrame.new(position))
	local shirt = if name == "Camille" then teal else red
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

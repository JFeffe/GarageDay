local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local MeshLibrary = require(script.Parent.MeshLibrary)

local World = {}

local concrete = Color3.fromRGB(169, 181, 173)
local wall = Color3.fromRGB(226, 220, 198)
local trim = Color3.fromRGB(198, 174, 137)
local steel = Color3.fromRGB(49, 67, 71)
local teal = Color3.fromRGB(69, 109, 111)
local yellow = Color3.fromRGB(238, 183, 70)
local red = Color3.fromRGB(199, 82, 57)
local black = Color3.fromRGB(35, 43, 45)

local function part(parent, name, size, position, color, solid)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.Position = position
	item.Color = color
	item.Material = Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = solid == true
	item.CanQuery = item.CanCollide
	item.CanTouch = false
	item.Parent = parent
	return item
end

local function box(parent, name, sx, sy, sz, x, y, z, color, solid)
	return part(parent, name, Vector3.new(sx, sy, sz), Vector3.new(x, y, z), color, solid)
end

local function model(parent, name)
	local group = Instance.new("Model")
	group.Name = name
	group.Parent = parent
	return group
end

local function target(parent, name, position)
	local anchor = part(parent, name, Vector3.one * 0.15, position, steel, false)
	anchor.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	return attachment
end

local function sign(attachment, text)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Panneau"
	gui.Size = UDim2.fromOffset(150, 28)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.MaxDistance = 27
	gui.Parent = attachment
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 237, 207)
	label.TextStrokeColor3 = black
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
end

local function buildRoom(room)
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(125, 126, 117)
	Lighting.OutdoorAmbient = Color3.fromRGB(141, 153, 151)
	Lighting.GlobalShadows = true

	box(room, "Dalle", 44, 0.7, 32, 0, -0.35, 0, concrete, true)
	box(room, "Toit", 44, 0.5, 32, 0, 11.85, 0, wall, true)
	for _, x in { -21.75, 21.75 } do
		box(room, "Mur latéral", 0.5, 11.6, 32, x, 5.8, 0, wall, true)
		box(room, "Soubassement", 0.57, 1.45, 32, x, 0.725, 0, trim)
	end
	for _, z in { -15.75, 15.75 } do
		box(room, "Mur du fond", 44, 11.6, 0.5, 0, 5.8, z, wall, true)
		box(room, "Soubassement", 44, 1.45, 0.57, 0, 0.725, z, trim)
	end
	box(room, "Rideau de baie", 11, 9, 0.28, 0, 4.5, -15.3, teal)
	for row = 1, 11 do
		box(room, "Lame", 10.9, 0.04, 0.13, 0, row * 0.78, -15.11, steel)
	end
	box(room, "Emplacement", 9.8, 0.07, 18, 0, 0.045, 0, steel, true)
	for _, x in { -5.65, 5.65 } do
		box(room, "Marquage de baie", 0.14, 0.03, 23, x, 0.03, 0, yellow)
		for mark = -1, 1 do
			local stripe = box(room, "Bande de sécurité", 0.26, 0.03, 1.05, x + mark * 0.42, 0.04, 9.3, yellow)
			stripe.CFrame *= CFrame.Angles(0, math.rad(36), 0)
		end
	end
	for _, x in { -12, 0, 12 } do
		for _, z in { -7, 7 } do
			box(room, "Rampe", 1.25, 0.23, 6.2, x, 11.28, z, steel)
			local lamp = box(room, "Tube", 0.65, 0.10, 5.8, x, 11.12, z, Color3.fromRGB(239, 249, 244))
			lamp.Material = Enum.Material.Neon
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 22
			light.Angle = 110
			light.Brightness = 1.4
			light.Parent = lamp
		end
	end

	local spawns = {}
	local positions = { Vector3.new(8.3, 0.4, 12.3), Vector3.new(12.7, 0.4, 10.1) }
	for i, position in positions do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Arrivée " .. i
		spawn.Size = Vector3.new(2.4, 0.4, 2.4)
		spawn.CFrame = CFrame.lookAt(position, Vector3.new(7.3, 0.4, 7.8))
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.CanTouch = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = room
		spawns[i] = spawn
	end
	return spawns
end

local function fitMesh(mesh, parent, origin)
	mesh.CFrame = origin * mesh.CFrame
	mesh.Parent = parent
	return mesh
end

local function cylinder(parent, name, width, diameter, center, color)
	local result = part(parent, name, Vector3.new(width, diameter, diameter), center, color, false)
	result.Shape = Enum.PartType.Cylinder
	return result
end

local function buildVehicle(room, moving, meshes)
	local carOrigin = CFrame.new(0, 0.18, 0)
	local wheel
	if meshes.Sedan then
		fitMesh(meshes.Sedan, moving, carOrigin)
		for _, name in { "FrontLeft", "FrontRight", "BackLeft", "BackRight" } do
			fitMesh(meshes[name], moving, carOrigin)
		end
		wheel = meshes.FrontLeft
	else
		box(moving, "Berline", 5.9, 1.55, 13.4, 0, 1.7, 0, red)
		box(moving, "Vitres", 4.9, 1.42, 5.8, 0, 3.07, 0.75, teal)
		box(moving, "Toit de la berline", 5.05, 0.25, 5.95, 0, 3.86, 0.75, red)
		for _, z in { -6.77, 6.77 } do
			box(moving, "Pare-chocs", 5.8, 0.45, 0.26, 0, 1.22, z, steel)
			for _, x in { -2.2, 2.2 } do
				box(moving, "Feu", 1.05, 0.32, 0.12, x, 2.1, z, wall)
			end
		end
		for _, x in { -2.38, 2.38 } do
			for _, z in { -3.7, 3.44 } do
				local tire = cylinder(moving, "Roue", 1.05, 2.15, Vector3.new(x, 1.24, z), black)
				if x < 0 and z < 0 then wheel = tire end
			end
		end
	end
	local collision = box(moving, "Collision de la berline", 4.62, 2.7, 12.2, 0, 1.9, 0, red, true)
	collision.Transparency = 1
	local hub = wheel.Position
	local rotor = cylinder(moving, "Disque de frein", 0.23, 1.53, hub + Vector3.new(-0.25, 0, 0), trim)
	rotor.Material = Enum.Material.Metal
	local caliper = box(moving, "Étrier et plaquettes", 0.31, 0.74, 0.54, hub.X - 0.34, hub.Y + 0.54, hub.Z, teal)
	local attachment = target(moving, "Roue avant gauche", hub - Vector3.new(wheel.Size.X * 0.5 + 0.14, 0, 0))
	local tray = box(room, "Support de roue", 2.7, 0.32, 2.8, -7.45, 0.2, -4.75, steel, true)
	local removedPose = CFrame.new(tray.Position + Vector3.new(0, tray.Size.Y * 0.5 + wheel.Size.X * 0.5, 0))
		* CFrame.Angles(0, 0, math.pi / 2)
	rotor.Transparency = 1
	caliper.Transparency = 1
	return wheel, attachment, rotor, caliper, removedPose
end

local function buildLift(room, moving, meshes)
	local liftOrigin = CFrame.new(0, 0, 1.85)
	if meshes.LiftBase then
		fitMesh(meshes.LiftBase, room, liftOrigin)
		fitMesh(meshes.LiftCarriage, moving, liftOrigin)
	else
		for _, x in { -4.7, 4.7 } do
			box(room, "Colonne", 0.78, 10.1, 0.85, x, 5.1, 1.85, yellow)
			box(moving, "Bras de levage", 2.85, 0.25, 0.4, x * 0.7, 0.44, 1.8, yellow)
		end
	end
	for _, x in { -4.7, 4.7 } do
		local collision = box(room, "Collision de colonne", 0.8, 10.1, 0.85, x, 5.1, 1.85, steel, true)
		collision.Transparency = 1
	end
	box(room, "Pupitre du pont", 0.46, 2.8, 0.46, 7.3, 1.4, 7.8, steel, true)
	box(room, "Boîtier", 1.48, 0.55, 1.25, 7.3, 2.88, 7.8, yellow)
	box(room, "Levier", 0.32, 0.45, 0.32, 7.3, 3.35, 7.72, red)
	local lever = target(room, "Levier", Vector3.new(7.3, 3.42, 8.36))
	sign(lever, "PONT")
	return lever
end

local function buildSupplies(room, meshes)
	box(room, "Établi rouge", 4, 2.75, 3, 15.1, 1.375, -5.4, red, true)
	box(room, "Plateau", 4.2, 0.26, 3.2, 15.1, 2.85, -5.4, steel)
	for _, y in { 0.72, 1.48, 2.22 } do
		box(room, "Poignée de tiroir", 2, 0.09, 0.11, 15.1, y, -3.85, trim)
	end
	local wrench = meshes.Wrench or box(room, "Clé à choc", 0.65, 1.35, 1.24, 0, 0.775, 0, steel)
	fitMesh(wrench, room, CFrame.new(15.1, 3.08, -5.05) * CFrame.Angles(0, math.rad(24), 0))
	local tools = target(room, "Clé à choc", Vector3.new(15.1, 3.23, -3.7))
	sign(tools, "OUTILS")
	for _, x in { -14.9, -11.0 } do
		box(room, "Montant d’étagère", 0.15, 4.7, 1.92, x, 2.35, -1.4, teal, true)
	end
	for _, y in { 0.35, 1.6, 2.85, 4.1 } do
		box(room, "Tablette", 3.8, 0.16, 1.92, -12.95, y, -1.4, steel, true)
	end
	local pads = box(room, "Boîte de plaquettes", 1.15, 0.41, 0.72, -12.95, 3.13, -1.25, yellow)
	local shelf = target(room, "Plaquettes avant", Vector3.new(-12.95, 3.3, -0.35))
	sign(shelf, "PIÈCES")
	return tools, wrench, shelf, pads
end

function World.build()
	local room = model(workspace, "Le Petit Atelier")
	local spawns = buildRoom(room)
	local meshes = MeshLibrary.load()
	room:SetAttribute("OriginalModels", meshes.Sedan ~= nil)
	local moving = model(room, "Plateforme mobile")
	local lever = buildLift(room, moving, meshes)
	local wheel, attachment, rotor, caliper, removedPose = buildVehicle(room, moving, meshes)
	local tools, wrench, shelf, pads = buildSupplies(room, meshes)
	moving.WorldPivot = CFrame.identity
	return {
		room = room, spawns = spawns, moving = moving, wheel = wheel, wheelHome = wheel.CFrame, removedPose = removedPose,
		rotor = rotor, caliper = caliper, wrench = wrench, pads = pads,
		targets = { Lever = lever, Wheel = attachment, Tools = tools, Shelf = shelf },
	}
end

function World.moveLift(world, up)
	local pose = Instance.new("CFrameValue")
	pose.Value = world.moving:GetPivot()
	local connection = pose.Changed:Connect(function(value)
		world.moving:PivotTo(value)
	end)
	local goal = CFrame.new(0, if up then 2.85 else 0, 0)
	local tween = TweenService:Create(pose, TweenInfo.new(0.85, Enum.EasingStyle.Sine), { Value = goal })
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	pose:Destroy()
	world.moving:PivotTo(goal)
end

function World.apply(world, state)
	local removed = state.step == 4 or state.step == 5
	if removed and world.wheel.Parent ~= world.room then
		world.wheel.Parent = world.room
		world.wheel.CFrame = world.removedPose
	elseif not removed and world.wheel.Parent ~= world.moving then
		world.wheel.Parent = world.moving
		world.wheel.CFrame = world.moving:GetPivot() * world.wheelHome
	end
	world.rotor.Transparency = if removed then 0 else 1
	world.caliper.Transparency = world.rotor.Transparency
	world.caliper.Color = if state.step >= 5 then Color3.fromRGB(107, 183, 145) else teal
	world.wrench.Transparency = if state.wrenchOwner == 0 then 0 else 1
	world.pads.Transparency = if state.padsOwner == 0 and state.step <= 4 then 0 else 1
end

function World.makeWrench(world)
	local tool = Instance.new("Tool")
	tool.Name = "Clé à choc"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.42, 0.25) * CFrame.Angles(0, math.pi / 2, 0)
	local handle = world.wrench:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.Massless = true
	handle.Transparency = 0
	handle.Parent = tool
	return tool
end

return World

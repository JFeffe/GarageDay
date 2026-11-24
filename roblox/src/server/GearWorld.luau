local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService("TweenService")
local Furniture = require(script.Parent.Furniture)
local Repair = require(ReplicatedStorage.GarageDay.Repair)

local Gear = {}
local dark = Color3.fromRGB(34, 51, 53)
local metal = Color3.fromRGB(157, 169, 165)
local blue = Color3.fromRGB(77, 151, 166)
local ochre = Color3.fromRGB(226, 172, 72)
local red = Color3.fromRGB(178, 79, 58)
local green = Color3.fromRGB(124, 187, 148)
local zUp = CFrame.Angles(0, 0, math.pi / 2)

local function frame(name, parent)
	local object = Instance.new("Model")
	object.Name = name
	object.WorldPivot = CFrame.identity
	object.Parent = parent
	return object
end

local function shape(part, parent, name, size, atPoint, color, kind)
	local piece = part(parent, name, size, atPoint, color)
	if kind then piece.Shape = kind end
	return piece
end

local function buildTemplates(world, part, cloneMesh)
	local specs = {}
	local function template(key, templateMesh, size, color)
		local model = frame(key)
		local source = world.meshes[templateMesh]
		if source then
			local mesh = cloneMesh(source, model, CFrame.new(-source.Position))
			mesh.Color = color
		else
			part(model, "Corps", size, Vector3.zero, color)
		end
		specs[key] = model
		return model
	end

	template("impact", "Wrench", Vector3.new(0.65, 1.15, 1.15), Color3.new(1, 1, 1))
	template("newBattery", "Battery", Vector3.new(0.96, 0.58, 0.68), Color3.new(1, 1, 1))
	template("oldBattery", "Battery", Vector3.new(0.96, 0.58, 0.68), Color3.fromRGB(170, 166, 141))
	template("newMuffler", "Muffler", Vector3.new(2.68, 0.54, 0.91), Color3.new(1, 1, 1))
	template("oldMuffler", "Muffler", Vector3.new(2.68, 0.54, 0.91), Color3.fromRGB(138, 111, 88))
	template("newDamper", "Damper", Vector3.new(0.5, 1.54, 0.52), Color3.new(1, 1, 1))
	template("oldDamper", "Damper", Vector3.new(0.5, 1.54, 0.52), Color3.fromRGB(171, 137, 106))

	for _, key in { "newTire", "usedTire", "serviceWheel" } do
		local wheel = frame(key)
		local source = world.meshes.StockWheel or world.meshes.FrontLeft
		if source then
			local mesh = cloneMesh(source, wheel, CFrame.new(-source.Position))
			mesh.Color = if key == "usedTire" then Color3.fromRGB(164, 147, 129) else Color3.new(1, 1, 1)
		else
			shape(part, wheel, "Pneu", Vector3.new(0.81, 2.18, 2.18), Vector3.zero, dark, Enum.PartType.Cylinder)
			shape(part, wheel, "Jante", Vector3.new(0.85, 1.21, 1.21), Vector3.zero, metal, Enum.PartType.Cylinder)
		end
		specs[key] = wheel
	end

	local gauge = frame("pressure")
	local dial = shape(part, gauge, "Cadran", Vector3.new(0.24, 0.78, 0.78), Vector3.zero, ochre, Enum.PartType.Cylinder)
	dial.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
	local face = shape(part, gauge, "Face graduée", Vector3.new(0.25, 0.59, 0.59), Vector3.new(0, 0, -0.025),
		Color3.fromRGB(222, 232, 220), Enum.PartType.Cylinder)
	face.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
	local needle = part(gauge, "Aiguille", Vector3.new(0.037, 0.22, 0.04), Vector3.new(0.038, 0.075, -0.154), red)
	needle.CFrame *= CFrame.Angles(0, 0, -0.55)
	part(gauge, "Flexible", Vector3.new(0.12, 0.54, 0.12), Vector3.new(0, -0.52, 0.04), dark)
	specs.pressure = gauge

	local diagnosis = frame("inspection")
	part(diagnosis, "Valise", Vector3.new(0.96, 0.68, 0.29), Vector3.zero, dark)
	part(diagnosis, "Écran", Vector3.new(0.7, 0.31, 0.025), Vector3.new(0, 0.1, -0.154), green)
	for i = -1, 1 do
		part(diagnosis, "Bouton", Vector3.new(0.12, 0.075, 0.045), Vector3.new(i * 0.22, -0.18, -0.154), blue)
	end
	specs.inspection = diagnosis

	local ratchet = frame("ratchet")
	part(ratchet, "Manche", Vector3.new(0.21, 0.67, 0.19), Vector3.new(0, -0.28, 0), dark)
	part(ratchet, "Tige", Vector3.new(0.11, 0.75, 0.12), Vector3.new(0, 0.23, 0), metal)
	local ratchetHead = shape(part, ratchet, "Douille", Vector3.new(0.29, 0.38, 0.38), Vector3.new(0, 0.54, -0.08), metal, Enum.PartType.Cylinder)
	ratchetHead.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
	specs.ratchet = ratchet

	local probe = frame("probe")
	part(probe, "Poignée", Vector3.new(0.32, 0.53, 0.23), Vector3.new(0, -0.27, 0), blue)
	part(probe, "Sonde", Vector3.new(0.085, 0.72, 0.085), Vector3.new(0, 0.33, 0), metal)
	specs.probe = probe

	local puller = frame("puller")
	part(puller, "Vis", Vector3.new(0.13, 0.91, 0.14), Vector3.zero, metal)
	part(puller, "Traverse", Vector3.new(0.82, 0.14, 0.18), Vector3.new(0, 0.19, 0), red)
	for side = -1, 1, 2 do
		part(puller, "Griffe", Vector3.new(0.15, 0.53, 0.19), Vector3.new(side * 0.34, -0.15, 0), red)
	end
	specs.puller = puller

	for _, key in { "pan", "usedOil" } do
		local pan = frame(key)
		part(pan, "Fond du bac", Vector3.new(1.68, 0.12, 1.12), Vector3.new(0, -0.11, 0), dark)
		for side = -1, 1, 2 do
			part(pan, "Bord", Vector3.new(1.68, 0.21, 0.09), Vector3.new(0, 0.025, side * 0.52), dark)
			part(pan, "Poignée", Vector3.new(0.14, 0.21, 1.07), Vector3.new(side * 0.76, 0.025, 0), dark)
		end
		if key == "usedOil" then
			part(pan, "Huile", Vector3.new(1.45, 0.035, 0.90), Vector3.new(0, 0.04, 0), Color3.fromRGB(79, 47, 28))
		end
		specs[key] = pan
	end

	for _, spec in { {"freshOil", ochre}, {"emptyBottle", metal}, {"coolant", blue}, {"emptyCoolant", metal} } do
		local bottle = frame(spec[1])
		part(bottle, "Bidon", Vector3.new(0.55, 0.7, 0.33), Vector3.zero, spec[2])
		part(bottle, "Bouchon", Vector3.new(0.19, 0.16, 0.19), Vector3.new(0.15, 0.4, 0), dark)
		part(bottle, "Étiquette", Vector3.new(0.36, 0.3, 0.017), Vector3.new(0, 0, -0.17), Color3.fromRGB(230, 225, 199))
		specs[spec[1]] = bottle
	end

	for _, spec in {
		{"pads", Vector3.new(0.83, 0.27, 0.57), ochre}, {"oldPads", Vector3.new(0.78, 0.22, 0.57), dark},
		{"patch", Vector3.new(0.47, 0.07, 0.51), red},
		{"newShield", Vector3.new(1.78, 0.15, 0.98), dark}, {"oldShield", Vector3.new(1.63, 0.16, 0.89), Color3.fromRGB(100, 85, 66)},
		{"newWindow", Vector3.new(0.77, 0.25, 0.49), blue}, {"oldWindow", Vector3.new(0.77, 0.25, 0.49), dark},
	} do template(spec[1], "", spec[2], spec[3]) end

	for _, key in { "newWipers", "oldWipers", "newBelt", "oldBelt", "newBearing", "oldBearing", "frontBulb", "rearBulb", "oldBulb" } do
		local model = frame(key)
		local worn = string.sub(key, 1, 3) == "old"
		if key:find("Wipers") then
			for side = -1, 1, 2 do
				part(model, "Balai", Vector3.new(1.14, 0.10, 0.12), Vector3.new(0, 0, side * 0.13), if worn then metal else dark)
			end
		elseif key:find("Belt") then
			for i = 0, 7 do
				local angle = i * math.pi / 4
				local strip = part(model, "Segment de courroie", Vector3.new(0.27, 0.1, 0.11),
					Vector3.new(math.sin(angle) * 0.32, 0, math.cos(angle) * 0.25), if worn then metal else dark)
				strip.CFrame *= CFrame.Angles(0, angle, 0)
			end
		elseif key:find("Bearing") then
			shape(part, model, "Couronne", Vector3.new(0.22, 0.58, 0.58), Vector3.zero, if worn then red else metal, Enum.PartType.Cylinder)
			shape(part, model, "Moyeu", Vector3.new(0.25, 0.35, 0.35), Vector3.zero, dark, Enum.PartType.Cylinder)
		else
			part(model, "Culot", Vector3.new(0.21, 0.24, 0.21), Vector3.new(0, -0.12, 0), metal)
			shape(part, model, "Ampoule", Vector3.new(0.36, 0.38, 0.36), Vector3.new(0, 0.10, 0),
				if worn then dark elseif key == "rearBulb" then red else ochre, Enum.PartType.Ball)
		end
		specs[key] = model
	end
	return specs
end

function Gear.place(world, key, parent, pose)
	local gear = world.gearTemplates[Repair.assetKey(key)]:Clone()
	gear.Parent = parent
	gear:PivotTo(pose)
	return gear
end

local function slot(world, name, position, target, parent)
	world.slots[name] = CFrame.new(position)
	world.targets[name] = target(parent or world.room, name, position + Vector3.yAxis * 0.4)
end

function Gear.build(world, part, cloneMesh, target, sign, model)
	world.gearTemplates = buildTemplates(world, part, cloneMesh)
	world.stocks, world.slots, world.toolDrops = {}, {}, {}
	world.gearTarget = target
	local layout = world.layout
	local toolSide = layout.toolSide or -1
	local function at(id, x, z, height)
		local home = layout.stations[id]
		return layout.at(home[1] + x, home[2] + z, height)
	end
	local function furnish(id, title, size)
		local actor = model(world.room, title, CFrame.new(at(id, 0, 0, 0)))
		Furniture.add(world, id, actor, size, target)
		return actor
	end
	local panel = furnish("toolPanel", "Panneau d’outillage", Vector3.new(0.45, 4.6, 6.24))
	local tireRack = furnish("tireRack", "Rack des pneus", Vector3.new(5.4, 2.56, 2.58))
	local longShelf = furnish("longShelf", "Rayon pièces longues", Vector3.new(2.62, 2.4, 8.05))
	local stand = furnish("wheelStand", "Support de roue", Vector3.new(2.23, 0.46, 2.27))
	local function makeStock(key, spec, data, isTool)
		local id, x, z, height = table.unpack(data)
		local parent = world.furniture[id].model
		local position = at(id, x, z, height)
		local turn = if isTool then toolSide * math.pi / 2 else 0
		local pose = CFrame.new(position) * CFrame.Angles(0, turn, 0)
		local visual = Gear.place(world, key, parent, pose)
		world.stocks[key] = { model = visual, parent = parent, pose = parent:GetPivot():ToObjectSpace(pose) }
		local offset = if isTool or key == "pan" then Vector3.new(toolSide * 0.64, 0.27, 0) else Vector3.new(0, 0.27, -0.25)
		if key == "newTire" then offset = Vector3.new(0, 0.48, 1.35) end
		world.targets[spec.target] = target(parent, spec.target, position + offset)
	end
	local tools = {
		impact = {"toolWrench", 0, 0, 2.98}, inspection = {"toolInspection", 0, 0, 2.83}, pressure = {"toolPressure", 0, 0, 2.91},
		ratchet = {"toolPanel", 0, -0.79, 3.67}, probe = {"toolPanel", 0, -0.02, 3.64}, puller = {"toolPanel", 0, 0.76, 3.69},
	}
	for key, data in tools do makeStock(key, Repair.tools[key], data, true) end
	sign(target(panel, "Poste d’outillage", at("toolPanel", 0, 0, 5.08)), "OUTILLAGE", 0, 24)
	part(panel, "Panneau d’outillage", Vector3.new(0.14, 1.67, 6.24), at("toolPanel", -toolSide * 0.22, 0, 3.78), dark, true)

	local supplies = {
		pads = {"partsChassis", 0, -0.42, 3.01}, pan = {"toolOil", 0, 0, 2.53}, freshOil = {"counter", -0.37, 0.23, 3.03},
		newBattery = {"partsElectric", 0, -0.44, 3.17}, coolant = {"counter", -0.38, -0.16, 3.02},
		patch = {"partsChassis", -0.09, -0.43, 2.02}, newBearing = {"partsChassis", 0.23, -0.43, 2.02},
		newMuffler = {"longShelf", 0, 0, 1.71}, newDamper = {"longShelf", -0.20, -0.97, 1.97}, newShield = {"longShelf", -0.04, 1.06, 1.77},
		newBelt = {"partsElectric", -0.09, -0.42, 1.96}, newWipers = {"partsElectric", 0, -0.44, 2.50},
		frontBulb = {"partsElectric", -0.16, -0.44, 1.24}, rearBulb = {"partsElectric", 0.14, -0.44, 1.24},
		newWindow = {"partsElectric", 0.06, -0.42, 3.57}, newTire = {"tireRack", 0.6, 0, 1.36},
	}
	for key, data in supplies do makeStock(key, Repair.cargo[key], data, false) end
	sign(world.targets.Pads, "CHÂSSIS", 0.39, 25)
	sign(world.targets.BatteryStock, "ÉLECTRICITÉ", 1.02, 25)
	sign(world.targets.OilPan, "VIDANGE", 0.93, 25)
	sign(world.targets.CoolantStock, "FLUIDES", 1.32, 23)
	sign(world.targets.TireRack, "PNEUS NEUFS", 1.67, 26)
	cloneMesh(world.meshes.OilCrate, world.furniture.counter.model, CFrame.new(at("counter", 0.20, 0.02, 2.57)))

	part(tireRack, "Rack des pneus", Vector3.new(5.4, 0.17, 2.58), at("tireRack", 0, 0, 0.21), metal, true)
	for _, x in { -0.45, 0.08, 0.43 } do
		Gear.place(world, "newTire", tireRack, CFrame.new(at("tireRack", x, 0, 1.37)))
	end
	part(longShelf, "Rayon pièces longues", Vector3.new(2.62, 0.16, 8.05), at("longShelf", 0, 0, 1.39), dark, true)

	slot(world, "Bench", at("bench", 0, 0, 3.23), target, world.furniture.bench.model)
	slot(world, "WheelStand", at("wheelStand", 0, 0, 1.04), target, stand)
	slot(world, "Recovery", at("recovery", 0, 0, 0.38), target)
	part(stand, "Support de roue", Vector3.new(2.23, 0.23, 2.27), world.slots.WheelStand.Position - Vector3.yAxis * 0.93, dark)
	sign(world.targets.WheelStand, "SUPPORT DE ROUE", 1.15, 23)
	sign(world.targets.Bench, "ÉTABLI", 1.55, 24)
	sign(world.targets.Recovery, "OBJETS RÉCUPÉRÉS", 1.65, 20)

	local tireBin = at("tireBin", 0, 0, 0.68)
	local scrap = at("scrap", 0, 0, 0.61)
	for _, storage in { {"TireBin", "PNEUS USÉS", tireBin, 3.68}, {"Scrap", "MÉTAUX", scrap, 2.67} } do
		local key, label, position, width = table.unpack(storage)
		part(world.room, label, Vector3.new(width, 1.14, 1.7), position, dark, true, Enum.Material.Metal)
		world.targets[key] = target(world.room, key, position + Vector3.yAxis * 0.95)
		sign(world.targets[key], label, 1.05, 38)
	end
	world.scrapVisuals = {}
	for i = 1, #Repair.wheels do
		local pose = CFrame.new(tireBin + Vector3.new(0, 0.67 + (i - 1) * 0.34, 0)) * zUp
		local wheel = Gear.place(world, "usedTire", world.room, pose)
		wheel.Parent = nil
		world.scrapVisuals[i] = wheel
	end
	world.recycled = 0
end

function Gear.buildBay(world)
	world.slots, world.placed, world.drops, world.pieceMotion = {}, {}, {}, {}
	local dock = world.dockPose.Position
	world.slots.UsedPan = CFrame.new(dock + Vector3.new(0, 0.28, -7.35))
	for _, wheel in Repair.wheels do
		local side = if wheel:find("Left") then -1 else 1
		local z = if wheel:find("Front") then -4.35 else 4.08
		world.slots["Floor" .. wheel] = CFrame.new(dock + Vector3.new(side * 6.52, 0.43, z))
	end
end

local function animate(model, from, to, seconds, style)
	model:PivotTo(from)
	local pivot = Instance.new("CFrameValue")
	pivot.Value = from
	local change = pivot.Changed:Connect(function(value)
		if model.Parent then model:PivotTo(value) end
	end)
	local tween = TweenService:Create(pivot, TweenInfo.new(seconds, style, Enum.EasingDirection.In), { Value = to })
	tween.Completed:Once(function()
		change:Disconnect()
		pivot:Destroy()
	end)
	tween:Play()
end

function Gear.toss(world, key, from, to)
	local visual = Gear.place(world, key, world.room, to)
	animate(visual, from, to, 0.32, Enum.EasingStyle.Quad)
	task.delay(0.36, function() visual:Destroy() end)
end

function Gear.recycle(world, item)
	if not Repair.isWheel(item) then return end
	world.recycled = math.min(#world.scrapVisuals, world.recycled + 1)
	world.scrapVisuals[world.recycled].Parent = world.room
end

function Gear.syncStocks(world, owners)
	for key in Repair.tools do
		local stock = world.stocks[key]
		local parent = if owners[key] or world.toolDrops[key] then nil else stock.parent
		if stock.model.Parent ~= parent then
			stock.model.Parent = parent
			if parent then stock.model:PivotTo(parent:GetPivot() * stock.pose) end
		end
	end
end

local function counterPose(world, key, anchor)
	local asset = Repair.assetKey(key)
	local rotation = CFrame.identity
	if Repair.isWheel(key) then rotation = zUp
	elseif Repair.tools[key] then rotation = CFrame.Angles(math.pi / 2, 0, 0)
	elseif asset == "newMuffler" or asset == "oldMuffler" then rotation = CFrame.Angles(0, math.pi / 2, 0) end
	local bounds, size = world.gearTemplates[asset]:GetBoundingBox()
	local box = rotation * bounds
	local halfHeight = (math.abs(box.RightVector.Y) * size.X + math.abs(box.UpVector.Y) * size.Y
		+ math.abs(box.LookVector.Y) * size.Z) / 2
	return anchor.WorldCFrame * CFrame.new(0, halfHeight - box.Y - 0.4, 0) * rotation
end

function Gear.dropTool(world, key, pose, from, location)
	local counter = world.depositSlots[location]
	local parent = if counter then counter.Parent.Parent else world.room
	if counter then pose = counterPose(world, key, counter) end
	local visual = Gear.place(world, key, parent, pose)
	if from then animate(visual, from, pose, 0.22, Enum.EasingStyle.Quad) end
	local point = if counter then counter.WorldPosition + Vector3.yAxis * 0.24 else pose.Position + Vector3.yAxis * 0.43
	local anchor = world.gearTarget(parent, "Outil déposé", point)
	world.toolDrops[key] = { visual = visual, anchor = anchor, location = location }
end

function Gear.recoverTool(world, key)
	local recovery = world.targets.Recovery.WorldPosition
	local offset = 0
	for _, drop in world.toolDrops do
		if drop.location == "Recovery" then offset = math.max(offset, drop.anchor.WorldPosition.X - recovery.X + 0.72) end
	end
	local height = world.gearTemplates[key]:GetExtentsSize().Y / 2
	Gear.dropTool(world, key, CFrame.new(recovery.X + offset, 0.10 + height, recovery.Z), nil, "Recovery")
end

function Gear.clearTool(world, key, prompt)
	local drop = world.toolDrops[key]
	if not drop then return end
	prompt.Parent = nil
	drop.visual:Destroy()
	drop.anchor.Parent:Destroy()
	world.toolDrops[key] = nil
end

function Gear.sync(world, repair)
	for key, old in world.placed do
		if old.location ~= repair.placements[key] then
			for _, child in old.anchor:GetChildren() do
				if child:IsA("ProximityPrompt") then child.Parent = nil end
			end
			old.visual:Destroy()
			old.anchor.Parent:Destroy()
			world.placed[key] = nil
		end
	end
	for key, location in repair.placements do
		if not world.placed[key] then
			local counter = world.root.depositSlots[location]
			local shared = world.root.slots[location] and world.targets[location]
			local pose = if location == "Ground" or location == "Workpiece" then world.drops[key] else world.slots[location]
			if shared then pose = shared.WorldCFrame - Vector3.yAxis * 0.4 end
			pose = pose or world.targets.Recovery.WorldCFrame - Vector3.yAxis * 0.4
			local wheel = Repair.isWheel(key)
			if counter then pose = counterPose(world, key, counter)
			elseif wheel and location ~= "WheelStand" then pose *= zUp end
			local parent = if counter then counter.Parent.Parent else world.room
			local visual = Gear.place(world, key, parent, pose)
			local origin = world.pieceMotion[key]
			if origin then
				animate(visual, origin, pose, if wheel then 0.38 else 0.24, Enum.EasingStyle.Quad)
				world.pieceMotion[key] = nil
			end
			local point = if counter then counter.WorldPosition + Vector3.yAxis * 0.24
				elseif location == "Bench" then pose.Position + Vector3.new(0, 0.50, 0.9) else pose.Position + Vector3.yAxis * 0.6
			local anchor = world.gearTarget(parent, "Objet déposé · " .. key, point)
			world.placed[key] = { location = location, visual = visual, anchor = anchor }
		end
	end
end

function Gear.equipment(world, key, character)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then return nil end
	local item = frame("GarageHeldItem")
	local asset = Repair.assetKey(key)
	item:SetAttribute("GearKey", asset)
	item:SetAttribute("TwoHanded", Repair.cargo[key] ~= nil and Repair.cargo[key].large == true)
	local grip = CFrame.new(0, 0.09, -0.16) * CFrame.Angles(0, math.pi / 2, 0)
	local attachment = hand:FindFirstChild("RightGripAttachment")
	local wrist = if attachment then attachment.CFrame else CFrame.new(0, -hand.Size.Y / 2, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.one * 0.25
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = hand.CFrame * wrist * grip:Inverse()
	handle.Parent = item
	local connection = Instance.new("Weld")
	connection.Part0, connection.Part1 = hand, handle
	connection.C0, connection.C1 = wrist, grip
	connection.Parent = handle

	local visual = world.gearTemplates[asset]:Clone()
	visual.Name = "HeldGeometry"
	visual.Parent = item
	for _, piece in visual:GetChildren() do
		piece:SetAttribute("GripPose", piece.CFrame)
		piece.CFrame = handle.CFrame * piece.CFrame
		piece.Anchored = false
		piece.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = piece
		weld.Parent = piece
	end
	item.Parent = character
	return item
end

return Gear

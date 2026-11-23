local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.PetitAtelier)
local Repair = require(ReplicatedStorage.GarageDay.Repair)

local Gear = {}
local at = Layout.at
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
	local gear = world.gearTemplates[key]:Clone()
	gear.Parent = parent
	gear:PivotTo(pose)
	return gear
end

local function slot(world, name, position, target)
	world.slots[name] = CFrame.new(position)
	world.targets[name] = target(world.room, name, position + Vector3.yAxis * 0.4)
end

function Gear.build(world, part, cloneMesh, target, sign)
	world.gearTemplates = buildTemplates(world, part, cloneMesh)
	world.stocks, world.slots, world.placed, world.drops = {}, {}, {}, {}
	world.gearTarget = target
	local tools = {
		impact = at(16.5, 2.5, 2.98), inspection = at(16.5, 1.5, 2.83), pressure = at(16.5, 3.5, 2.91),
		ratchet = at(17.16, 5.18, 3.67), probe = at(17.16, 5.95, 3.64), puller = at(17.16, 6.73, 3.69),
	}
	for key, position in tools do
		local spec = Repair.tools[key]
		local pose = CFrame.new(position) * CFrame.Angles(0, -math.pi / 2, 0)
		world.stocks[key] = Gear.place(world, key, world.room, pose)
		world.targets[spec.target] = target(world.room, spec.target, position + Vector3.new(-0.64, 0.27, 0))
	end
	sign(target(world.room, "Poste d’outillage", at(16.24, 3.58, 5.08)), "OUTILLAGE", 0, 24)
	part(world.room, "Panneau d’outillage", Vector3.new(0.14, 1.67, 6.24), at(17.69, 5.97, 3.78), dark)

	local supplies = {
		pads = at(6.5, 10.08, 3.01), pan = at(16.5, 4.5, 2.53), freshOil = at(16.13, 6.73, 3.03),
		newBattery = at(7.5, 10.06, 3.17), coolant = at(16.12, 6.34, 3.02),
		patch = at(6.41, 10.07, 2.02), newBearing = at(6.73, 10.07, 2.02), newMuffler = at(6.38, 7.58, 1.71),
		newDamper = at(6.18, 6.61, 1.97), newShield = at(6.34, 8.64, 1.77),
		newBelt = at(7.41, 10.08, 1.96), newWipers = at(7.5, 10.06, 2.50),
		frontBulb = at(7.34, 10.06, 1.24), rearBulb = at(7.64, 10.06, 1.24), newWindow = at(7.56, 10.08, 3.57),
		newTire = at(7.62, 1.61, 1.36),
	}
	for key, position in supplies do
		local spec = Repair.cargo[key]
		world.stocks[key] = Gear.place(world, key, world.room, CFrame.new(position))
		local offset = if position.X > 10 then Vector3.new(-0.82, 0.38, 0) else Vector3.new(0, 0.27, -0.25)
		if key == "newTire" then offset = Vector3.new(0, 0.48, 1.35) end
		world.targets[spec.target] = target(world.room, spec.target, position + offset)
	end
	sign(world.targets.Pads, "CHÂSSIS", 1.04, 25)
	sign(world.targets.BatteryStock, "ÉLECTRICITÉ", 1.02, 25)
	sign(world.targets.OilPan, "VIDANGE", 0.93, 25)
	sign(world.targets.CoolantStock, "FLUIDES", 1.32, 23)
	sign(world.targets.TireRack, "PNEUS NEUFS", 1.67, 26)
	cloneMesh(world.meshes.OilCrate, world.room, CFrame.new(at(16.7, 6.52, 2.57)))

	part(world.room, "Rack des pneus", Vector3.new(5.4, 0.17, 2.58), at(7.02, 1.61, 0.21), metal, true)
	for _, x in { 6.57, 7.10, 7.45 } do
		Gear.place(world, "newTire", world.room, CFrame.new(at(x, 1.61, 1.37)))
	end
	part(world.room, "Rayon pièces longues", Vector3.new(2.62, 0.16, 8.05), at(6.38, 7.58, 1.39), dark, true)

	slot(world, "Bench", at(7.5, 5.5, 3.23), target)
	slot(world, "WheelStand", at(7.93, 6.72, 1.04), target)
	slot(world, "UsedPan", Vector3.new(0, 0.28, -7.35), target)
	slot(world, "Recovery", at(6.12, 2.93, 0.38), target)
	slot(world, "Counter1", at(6.23, 4.55, 2.64), target)
	slot(world, "Counter2", at(6.23, 3.70, 2.64), target)
	part(world.room, "Support de roue", Vector3.new(2.23, 0.23, 2.27), world.slots.WheelStand.Position - Vector3.yAxis * 0.93, dark)
	sign(world.targets.WheelStand, "SUPPORT DE ROUE", 1.15, 23)
	sign(world.targets.Bench, "ÉTABLI", 1.55, 24)
	sign(world.targets.Recovery, "OBJETS RÉCUPÉRÉS", 1.65, 20)
	for _, wheel in Repair.wheels do
		local side = if wheel:find("Left") then -1 else 1
		local z = if wheel:find("Front") then -4.35 else 4.08
		slot(world, "Floor" .. wheel, Vector3.new(side * 6.52, 0.43, z), target)
	end

	local tireBin = at(16.58, 15.32, 0.68)
	local scrap = at(16.70, 12.20, 0.61)
	for _, storage in { {"TireBin", "PNEUS USÉS", tireBin, 3.68}, {"Scrap", "MÉTAUX", scrap, 2.67} } do
		local key, label, position, width = table.unpack(storage)
		part(world.room, label, Vector3.new(width, 1.14, 1.7), position, dark, true, Enum.Material.Metal)
		world.targets[key] = target(world.room, key, position + Vector3.new(-width / 2 - 0.12, 0.86, 0))
		sign(world.targets[key], label, 1.05, 38)
	end
	world.scrapVisuals = {}
	for i = 1, 3 do
		local pose = CFrame.new(tireBin + Vector3.new(0, 0.67 + (i - 1) * 0.34, 0)) * zUp
		local wheel = Gear.place(world, "usedTire", world.room, pose)
		wheel.Parent = nil
		world.scrapVisuals[i] = wheel
	end
	world.recycled = 0
end

function Gear.recycle(world, item)
	if item ~= "serviceWheel" and item ~= "usedTire" then return end
	world.recycled = math.min(#world.scrapVisuals, world.recycled + 1)
	world.scrapVisuals[world.recycled].Parent = world.room
end

function Gear.sync(world, repair)
	for key, model in world.stocks do
		local used = repair.tools[key] or repair.carried[key] or repair.placements[key]
		local parent = if used then nil else world.room
		if model.Parent ~= parent then model.Parent = parent end
	end
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
			local pose = if location == "Ground" then world.drops[key] else world.slots[location]
			pose = pose or world.slots.Recovery
			local wheel = key == "newTire" or key == "usedTire" or key == "serviceWheel"
			if wheel and location ~= "WheelStand" then pose *= zUp end
			local visual = Gear.place(world, key, world.room, pose)
			local offset = if location == "Bench" then Vector3.new(0, 0.50, 0.9) else Vector3.yAxis * 0.6
			local anchor = world.gearTarget(world.room, "Objet déposé · " .. key, pose.Position + offset)
			world.placed[key] = { location = location, visual = visual, anchor = anchor }
		end
	end
end

function Gear.equipment(world, key, title)
	local tool = Instance.new("Tool")
	tool.Name = title
	tool.CanBeDropped = false
	tool:SetAttribute("GearKey", key)
	tool:SetAttribute("TwoHanded", Repair.cargo[key] ~= nil and Repair.cargo[key].large == true)
	tool.Grip = CFrame.new(0, 0.09, -0.16) * CFrame.Angles(0, math.pi / 2, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.one * 0.25
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	local visual = world.gearTemplates[key]:Clone()
	visual.Name = "HeldGeometry"
	visual.Parent = tool
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
	return tool
end

return Gear

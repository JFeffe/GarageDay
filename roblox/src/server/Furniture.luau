local Furniture = {}

function Furniture.add(world, id, model, size, makeTarget)
	local pivot = model:GetPivot()
	local anchor = makeTarget(model, "Réaménager", pivot.Position + Vector3.yAxis * math.min(3.9, size.Y + 0.4))
	local layout = world.layout
	local x = pivot.X / layout.scale + layout.origin.X
	local z = pivot.Z / layout.scale + layout.origin.Y
	local zone = if x >= layout.wing then "shop" elseif z < layout.officeSplit then "office"
		elseif z < layout.receptionSplit then "waiting" else "reception"
	world.furniture[id] = { model = model, anchor = anchor, size = size, home = pivot, zone = zone }
end

local function poseFor(world, item, placement)
	return CFrame.new(world.layout.at(placement.x, placement.z, item.home.Y))
		* item.home.Rotation * CFrame.Angles(0, math.pi / 2 * placement.turn, 0)
end

function Furniture.restore(world, placements)
	for id, placement in placements or {} do
		local item = world.furniture[id]
		if item then
			item.model:PivotTo(poseFor(world, item, placement))
			item.turn = placement.turn
		end
	end
end

function Furniture.place(world, item, root, x, z, turn)
	if typeof(x) ~= "number" or typeof(z) ~= "number" or typeof(turn) ~= "number"
		or not (math.abs(x) < 300 and math.abs(z) < 300 and turn >= 0 and turn <= 3 and turn % 1 == 0) then return end
	local layout = world.layout
	local floor = Vector3.new(x, 0, z)
	if (floor - root.Position * Vector3.new(1, 0, 1)).Magnitude > 8 then return end
	local placement = {
		x = math.round((x / layout.scale + layout.origin.X) * 4) / 4,
		z = math.round((z / layout.scale + layout.origin.Y) * 4) / 4, turn = turn,
	}
	local pose = poseFor(world, item, placement)
	local edgeX = (math.abs(pose.RightVector.X) * item.size.X + math.abs(pose.LookVector.X) * item.size.Z) / (2 * layout.scale)
	local edgeZ = (math.abs(pose.RightVector.Z) * item.size.X + math.abs(pose.LookVector.Z) * item.size.Z) / (2 * layout.scale)
	local left, right = placement.x - edgeX, placement.x + edgeX
	local front, back = placement.z - edgeZ, placement.z + edgeZ
	local function crosses(x1, x2, z1, z2)
		return left < x2 and right > x1 and front < z2 and back > z1
	end
	if left < 0.24 or right > layout.width - 0.24 or front < 0.24 or back > layout.depth - 0.24 then return end
	if item.zone == "shop" then
		if left < layout.wing + 0.22 then return end
		if crosses(layout.wing, layout.wing + 1.26, layout.shopPassage[1], layout.shopPassage[2]) then return end
		for _, bay in layout.bays do
			if crosses(bay.x - 2.38, bay.x + 2.38, 0, layout.depth) then return end
		end
		for _, door in layout.pedestrianDoors do
			if crosses(door.left - 0.13, door.right + 0.13, door.z - 1.7, door.z + 1.7) then return end
		end
	else
		if right > layout.wing - 0.13 then return end
		local low = if item.zone == "office" then 0 elseif item.zone == "waiting" then layout.officeSplit else layout.receptionSplit
		local high = if item.zone == "office" then layout.officeSplit elseif item.zone == "waiting" then layout.receptionSplit else layout.depth
		if front < low + 0.25 or back > high - 0.2 then return end
		if crosses(layout.entry - 0.47, layout.entry + 0.47, layout.officeSplit - 0.7, layout.depth) then return end
	end
	local box = pose * CFrame.new(0, item.size.Y / 2 + 0.10, 0)
	local size = item.size - Vector3.new(0.11, 0.22, 0.11)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { item.model }
	params.RespectCanCollide = true
	params.MaxParts = 1
	if #workspace:GetPartBoundsInBox(box, size, params) > 0 then return end
	for _, other in world.furniture do
		if other ~= item and other.model:IsDescendantOf(workspace) then
			local p = other.model:GetPivot()
			local dx = (math.abs(p.RightVector.X) * other.size.X + math.abs(p.LookVector.X) * other.size.Z) / (2 * layout.scale)
			local dz = (math.abs(p.RightVector.Z) * other.size.X + math.abs(p.LookVector.Z) * other.size.Z) / (2 * layout.scale)
			local ox, oz = p.X / layout.scale + layout.origin.X, p.Z / layout.scale + layout.origin.Y
			if crosses(ox - dx + 0.04, ox + dx - 0.04, oz - dz + 0.04, oz + dz - 0.04) then return end
		end
	end
	if math.abs(root.Position.X - pose.X) < edgeX * layout.scale + 0.8 and math.abs(root.Position.Z - pose.Z) < edgeZ * layout.scale + 0.8 then return end
	item.model:PivotTo(pose)
	item.turn = turn
	return placement
end

return Furniture

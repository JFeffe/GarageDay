local TweenService = game:GetService("TweenService")

local Doors = {}
local metal = Color3.fromRGB(41, 70, 68)
local glass = Color3.fromRGB(158, 193, 190)
local brass = Color3.fromRGB(218, 169, 89)
local panelColor = Color3.fromRGB(93, 130, 118)

local function leaf(door, part, centre, width, height, direction)
	local panel = {}
	local function add(name, size, offset, color, material)
		local piece = part(door.model, name, size, centre + offset, color, false, material)
		table.insert(panel, { part = piece, closed = piece.CFrame, shift = Vector3.xAxis * direction * (width + 0.17) })
		return piece
	end
	local glassPane = add("Verre", Vector3.new(width - 0.16, height - 0.22, 0.13), Vector3.zero, glass, Enum.Material.Glass)
	glassPane.Transparency = 0.48
	for _, side in { -1, 1 } do
		add("Montant de porte", Vector3.new(0.108, height, 0.20), Vector3.xAxis * side * (width / 2 - 0.055), metal, Enum.Material.Metal)
		add("Traverse de porte", Vector3.new(width, 0.11, 0.20), Vector3.yAxis * side * (height / 2 - 0.055), metal, Enum.Material.Metal)
	end
	add("Panneau bas", Vector3.new(width - 0.19, 1.23, 0.17), Vector3.yAxis * (-height / 2 + 0.70), panelColor, Enum.Material.Metal)
	add("Bandeau à hauteur des yeux", Vector3.new(width - 0.18, 0.095, 0.19), Vector3.yAxis * 0.33, brass, Enum.Material.Metal)
	add("Poignée verticale", Vector3.new(0.09, 0.83, 0.28), Vector3.new(-direction * (width / 2 - 0.27), -0.46, 0), metal, Enum.Material.Metal)
	for _, piece in panel do table.insert(door.panels, piece) end
end

function Doors.build(room, part, model, height, layout)
	local doors = {}
	for _, spec in layout.pedestrianDoors do
		local center = layout.at((spec.left + spec.right) / 2, spec.z + (if spec.outside == 1 then 0.18 else 0))
		local edge = (spec.right - spec.left) * layout.scale / 2
		local frame = model(room, spec.name, CFrame.new(center))
		frame:SetAttribute("Ouverte", false)
		for _, side in { -1, 1 } do
			part(frame, "Huisserie", Vector3.new(0.16, height, 0.37), center + Vector3.new(side * (edge - 0.08), height / 2, 0),
				metal, true, Enum.Material.Metal)
		end
		part(frame, "Rail supérieur", Vector3.new(edge * (if spec.double then 3.78 else 3.85), 0.23, 0.42),
			center + Vector3.new(if spec.double then 0 else -edge * 0.88, height - 0.07, spec.outside * 0.18),
			metal, false, Enum.Material.Metal)
		part(frame, "Seuil métallique", Vector3.new(edge * 2 - 0.19, 0.035, 0.69), center + Vector3.yAxis * 0.042,
			brass, false, Enum.Material.Metal)
		local collision = part(frame, "Vantail fermé", Vector3.new(edge * 2 - 0.27, height - 0.22, 0.20),
			center + Vector3.new(0, height / 2, spec.outside * 0.22), metal, true)
		collision.Transparency = 1
		local door = { model = frame, center = center, edge = edge, open = false, collision = collision, panels = {}, heldUntil = 0, motion = 0 }
		local centre = collision.Position
		if spec.double then
			local width = edge - 0.13
			for _, side in { -1, 1 } do
				leaf(door, part, centre + Vector3.xAxis * side * (width / 2 + 0.018), width, height - 0.30, side)
			end
		else
			leaf(door, part, centre, edge * 2 - 0.25, height - 0.30, -1)
		end
		table.insert(doors, door)
	end
	return doors
end

local function slide(door, open)
	door.open = open
	door.motion += 1
	door.model:SetAttribute("Ouverte", open)
	door.collision.CanCollide = false
	door.collision.CanQuery = false
	local animation = TweenInfo.new(0.34, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local last
	for _, panel in door.panels do
		last = TweenService:Create(panel.part, animation, { CFrame = panel.closed + if open then panel.shift else Vector3.zero })
		last:Play()
	end
	if not open then
		local motion = door.motion
		last.Completed:Once(function(playback)
			if playback == Enum.PlaybackState.Completed and motion == door.motion then
				door.collision.CanQuery = true
				door.collision.CanCollide = true
			end
		end)
	end
end

function Doors.update(doors, positions, now)
	for _, door in doors do
		for _, position in positions do
			local offset = position - door.center
			if math.abs(offset.Z) < 6.4 and math.abs(offset.X) < door.edge + 1.25 and offset.Y > -0.8 and offset.Y < 7.8 then
				door.heldUntil = now + 0.95
				break
			end
		end
		local open = now < door.heldUntil
		if open ~= door.open then slide(door, open) end
	end
end

return Doors

local Layout = require(script.Parent.PetitAtelier)

local Decor = {}
local at = Layout.at
local ink = Color3.fromRGB(34, 61, 62)
local paper = Color3.fromRGB(255, 239, 203)
local brass = Color3.fromRGB(228, 179, 99)
local moss = Color3.fromRGB(96, 129, 108)
local concrete = Color3.fromRGB(156, 155, 137)
local asphalt = Color3.fromRGB(62, 72, 76)
local tile = Color3.fromRGB(173, 145, 117)
local glass = Color3.fromRGB(124, 159, 163)

local function surface(board, face, size, range)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = size
	gui.LightInfluence = 0.24
	gui.MaxDistance = range
	gui.Parent = board
	return gui
end

local function letter(parent, message, position, size, color, font)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Font = font or Enum.Font.GothamBold
	text.Text = message
	text.TextColor3 = color
	text.TextScaled = true
	text.Parent = parent
	return text
end

local function sign(board, face, message, color, range)
	local gui = surface(board, face, Vector2.new(board.Size.X * 64, math.max(board.Size.Y, 0.9) * 64), range)
	letter(gui, message, UDim2.fromScale(0.04, 0.14), UDim2.fromScale(0.92, 0.72), color)
end

local function street(world, part)
	local room = world.room
	part(room, "Terrain du quartier", Vector3.new(350, 1.4, 375), Vector3.new(-1, -1.12, 15),
		Color3.fromRGB(109, 137, 103), false, Enum.Material.Grass)
	for _, road in { {37.1, 19.22, 40.85}, {-14, 18.6, -17.6} } do
		local z, depth, walk = table.unpack(road)
		part(room, "Rue du quartier", Vector3.new(344, 0.17, depth), at(11.25, z, -0.105), asphalt, false, Enum.Material.Asphalt)
		part(room, "Trottoir", Vector3.new(344, 0.22, 3.25), at(11.25, walk, 0.0), concrete, false, Enum.Material.Concrete)
		for x = -43, 65, 3 do
			if x < 0 or x > 22 then
				part(room, "Ligne de la rue", Vector3.new(4.4, 0.023, 0.17), at(x, z + 0.03, 0.006), brass)
			end
		end
	end

	for _, spec in {
		{-6, -23, 8.5, Color3.fromRGB(159, 142, 121), Color3.fromRGB(80, 92, 85), 1},
		{5.4, -24, 10.2, Color3.fromRGB(207, 188, 153), Color3.fromRGB(109, 84, 72), 1},
		{22.5, -25, 9.3, Color3.fromRGB(144, 165, 156), Color3.fromRGB(65, 91, 92), 1},
		{-4.6, 50, 9.0, Color3.fromRGB(192, 172, 154), Color3.fromRGB(102, 74, 69), -1},
		{7.4, 49.0, 10.5, Color3.fromRGB(181, 196, 175), Color3.fromRGB(69, 86, 91), -1},
		{22.4, 51.3, 9.8, Color3.fromRGB(216, 188, 156), Color3.fromRGB(109, 79, 60), -1},
	} do
		local x, z, height, masonry, roof, facing = table.unpack(spec)
		local origin = at(x, z)
		part(room, "Maison du quartier", Vector3.new(14.4, height, 9.1), origin + Vector3.yAxis * (height / 2 - 0.25),
			masonry, false, Enum.Material.Brick)
		local courseHeight = 0.395
		for course = 1, 5 do
			local width = 14.4 * (1 - (course - 0.55) / 5)
			part(room, "Pignon", Vector3.new(width, courseHeight, 9.08),
				origin + Vector3.yAxis * (height - 0.25 + (course - 0.5) * courseHeight), masonry, false, Enum.Material.Brick)
		end
		for side = -1, 1, 2 do
			local slab = part(room, "Toiture", Vector3.new(8.0, 0.43, 10.1), origin + Vector3.new(side * 3.7, height + 0.88, 0),
				roof, false, Enum.Material.Slate)
			slab.CFrame *= CFrame.Angles(0, 0, side * -0.28)
		end
		for _, offset in { -4.35, 4.35 } do
			local opening = origin + Vector3.new(offset, 4.95, facing * 4.69)
			part(room, "Cadre de maison", Vector3.new(2.59, 2.92, 0.16), opening - Vector3.zAxis * facing * 0.08, paper)
			local pane = part(room, "Fenêtre de maison", Vector3.new(1.98, 2.5, 0.19), opening, glass, false, Enum.Material.Glass)
			table.insert(world.nightWindows, pane)
			part(room, "Traverse de fenêtre", Vector3.new(2.02, 0.08, 0.20), opening + Vector3.zAxis * facing * 0.08, paper)
			part(room, "Montant de fenêtre", Vector3.new(0.08, 2.50, 0.20), opening + Vector3.zAxis * facing * 0.08, paper)
			part(room, "Appui de fenêtre", Vector3.new(2.90, 0.14, 0.49), opening + Vector3.new(0, -1.44, facing * 0.18), concrete)
		end
		part(room, "Porte de maison", Vector3.new(2.44, 4.13, 0.24), origin + Vector3.new(0, 1.80, facing * 4.64), roof,
			false, Enum.Material.WoodPlanks)
		part(room, "Seuil de maison", Vector3.new(3.25, 0.35, 1.35), origin + Vector3.new(0, 0.07, facing * 5.25),
			concrete, false, Enum.Material.Concrete)
		part(room, "Cheminée", Vector3.new(1.01, 2.57, 0.99), origin + Vector3.new(4.2, height + 0.96, -1.65), masonry,
			false, Enum.Material.Brick)
	end

	local autumn = { moss, Color3.fromRGB(151, 161, 102), Color3.fromRGB(181, 151, 90), Color3.fromRGB(118, 145, 104) }
	for i, coordinates in { {-11, -22}, {-0.5, -21}, {13.0, -22.5}, {29, -24}, {-9.4, 47.0}, {0.7, 47.4}, {16.6, 48.0},
		{29.3, 46.9}, {-3.4, 14.25}, {20.4, 6.3}, {19.9, 19.6}, {-3.1, -6.6}, {17.6, 33}, {-0.6, 30.1},
		{22.4, 30.65}, {18.8, -8.1}, {-5.1, 26.26}, {28.1, 16.72} } do
		local origin = at(coordinates[1], coordinates[2])
		local height = 8.3 + (i % 5) * 1.43
		local trunk = part(room, "Tronc", Vector3.new(height * 0.67, 0.61, 0.62), origin + Vector3.new(0, height * 0.31, 0),
			Color3.fromRGB(113, 91, 66), false, Enum.Material.Wood)
		trunk.Shape = Enum.PartType.Cylinder
		trunk.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
		local base = autumn[i % #autumn + 1]
		for j, bunch in { {0, 0, 0, 1.05}, {-1, -0.8, 0.4, 0.76}, {1.14, -1.28, -0.57, 0.71}, {-0.38, 0.87, -0.77, 0.78},
			{0.86, 0.72, 0.90, 0.69} } do
			local x, y, z, scale = table.unpack(bunch)
			local crown = part(room, "Feuillage", Vector3.new(5.0, 5.07, 4.65) * scale * (height / 10),
				origin + Vector3.new(x * (height / 8), height * 0.72 + y, z), base:Lerp(paper, j * 0.032), false, Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
	end
end

local function lightPost(world, part, position)
	local room = world.room
	part(room, "Pied de lampadaire", Vector3.new(0.79, 0.32, 0.79), position + Vector3.yAxis * 0.17, concrete)
	part(room, "Lampadaire", Vector3.new(0.19, 7.44, 0.21), position + Vector3.yAxis * 3.74, ink, false, Enum.Material.Metal)
	part(room, "Support de lanterne", Vector3.new(0.25, 0.19, 1.21), position + Vector3.new(0, 7.36, -0.52), ink)
	part(room, "Chapeau de lanterne", Vector3.new(0.85, 0.19, 0.87), position + Vector3.new(0, 7.06, -1.03), ink)
	local lamp = part(room, "Lanterne", Vector3.new(0.58, 0.59, 0.58), position + Vector3.new(0, 6.71, -1.03), paper)
	part(room, "Socle de lanterne", Vector3.new(0.66, 0.12, 0.67), position + Vector3.new(0, 6.36, -1.03), ink)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Enabled = Color3.fromRGB(255, 197, 130), 20, 1.75, false
	light.Parent = lamp
	table.insert(world.nightLights, light)
end

local function forecourt(world, part)
	local room = world.room
	local lawn = Color3.fromRGB(107, 136, 86)
	local leaf = Color3.fromRGB(79, 108, 76)
	for _, place in { {0.46, 16.20, 5.7}, {5.13, 21.43, 6.8}, {18.49, 17.00, 9.3}, {18.49, 27.44, 13.3}, {1.47, -3.04, 5.5} } do
		local x, z, length = table.unpack(place)
		local origin = at(x, z)
		part(room, "Bordure plantée", Vector3.new(2.78, 0.24, length), origin + Vector3.yAxis * 0.12, concrete, false, Enum.Material.Concrete)
		part(room, "Terre du massif", Vector3.new(2.52, 0.16, length - 0.18), origin + Vector3.yAxis * 0.26,
			Color3.fromRGB(105, 85, 62), false, Enum.Material.Ground)
		for j = 1, math.floor(length * 1.22) do
			local patch = part(room, "Massif", Vector3.new(1.27 + (j % 3) * 0.37, 0.84 + (j % 2) * 0.56, 1.62),
				origin + Vector3.new(math.sin(j * 1.53) * 0.42, 0.71, j * 0.75 - length / 2), leaf:Lerp(lawn, (j % 4) / 4),
				false, Enum.Material.Grass)
			patch.Shape = Enum.PartType.Ball
			if j % 2 == 0 then
				local flower = part(room, "Fleurs du parvis", Vector3.new(0.29, 0.23, 0.41), patch.Position + Vector3.new(0.38, 0.51, -0.22),
					if j % 4 == 0 then brass else paper)
				flower.Shape = Enum.PartType.Ball
			end
		end
	end
	for i = 0, 20 do
		local row = at(2.5, 16.51 + i * 0.35, 0.021)
		for col = -1, 1 do
			part(room, "Dalle d’accès", Vector3.new(1.76, 0.037, 1.04), row + Vector3.xAxis * (col * 1.80), tile:Lerp(concrete, (i + col) % 4 / 5),
				false, Enum.Material.Pavement)
		end
	end
	local vendor = at(15.77, 20.68, 0.017)
	part(room, "Aire de la caravane", Vector3.new(12.1, 0.04, 17.1), vendor, Color3.fromRGB(124, 126, 112), false, Enum.Material.Pavement)
	for _, off in { -5.98, 5.98 } do
		part(room, "Marquage de la caravane", Vector3.new(0.11, 0.022, 16.98), vendor + Vector3.new(off, 0.04, 0), brass)
	end
	local stand = part(room, "Plaque de la caravane", Vector3.new(3.48, 1.01, 0.18), at(15.88, 16.55, 2.42), ink)
	part(room, "Pied de la plaque", Vector3.new(0.20, 2.0, 0.24), stand.Position - Vector3.yAxis * 1.42, ink)
	sign(stand, Enum.NormalId.Front, "LA CARAVANE", paper, 54)
	sign(stand, Enum.NormalId.Back, "LA CARAVANE", paper, 54)
	for _, post in { {0.67, 13.94}, {4.60, 24.96}, {18.43, 20.24}, {15.78, 25.81}, {14.16, -5.88}, {5.39, -4.93}, {18.64, 33.42} } do
		lightPost(world, part, at(table.unpack(post)))
	end
end

local function facade(world, part, cloneMesh)
	local room = world.room
	local wood = Color3.fromRGB(157, 124, 87)
	for _, side in { {12.99, Enum.NormalId.Back, "LE PETIT ATELIER"}, {0.01, Enum.NormalId.Front, "SORTIE · P 01"} } do
		local z, face, label = table.unpack(side)
		local board = part(room, label, Vector3.new(18.2, 1.29, 0.35), at(11.5, z, 9.31), ink, false, Enum.Material.Metal)
		part(room, "Bordure d’enseigne", Vector3.new(18.1, 0.13, 0.40), board.Position - Vector3.yAxis * 0.62, brass)
		sign(board, face, label, paper, 135)
	end
	local canopy = part(room, "Auvent de l’accueil", Vector3.new(8.03, 0.26, 2.78), at(2.5, 13.18, 7.9), ink, false, Enum.Material.Metal)
	part(room, "Bandeau d’accueil", Vector3.new(8.05, 0.67, 0.21), canopy.Position + Vector3.new(0, -0.23, 1.36), ink)
	local welcome = part(room, "Plaque d’accueil", Vector3.new(6.3, 0.64, 0.18), canopy.Position + Vector3.new(0, -0.23, 1.50), ink)
	sign(welcome, Enum.NormalId.Back, "ACCUEIL CLIENTS", paper, 50)
	for i = 1, 6 do
		local seam = part(room, "Joint debout de l’auvent", Vector3.new(0.05, 0.055, 2.71),
			canopy.Position + Vector3.new(-3.56 + (i - 1) * 1.42, 0.142, 0), brass, false, Enum.Material.Metal)
		seam.Color = seam.Color:Lerp(ink, 0.38)
	end
	for _, x in { 0.5, 4.5 } do
		part(room, "Équerre d’auvent", Vector3.new(0.16, 1.82, 0.16), at(x, 13.15, 7.09), ink).CFrame *= CFrame.Angles(0.75, 0, 0)
	end
	for _, side in { {0.13, -1}, {12.96, 1} } do
		local z, direction = table.unpack(side)
		for _, x in { 0.0, 5.05, if direction > 0 then 8.44 else 8.96, 14.05, 17.96 } do
			part(room, "Pilastre de façade", Vector3.new(0.31, 7.95, 0.18), at(x, z + direction * 0.07, 4.06), tile,
				false, Enum.Material.Brick)
		end
		for _, span in { {0.62, 2.84}, {4.69, 5.8}, {7.36, 5.55}, {15.52, 14.24} } do
			local width = span[2]
			local position = at(span[1], z + direction * 0.11, 8.53)
			part(room, "Bandeau de façade", Vector3.new(width, 0.44, 0.19), position, moss, false, Enum.Material.WoodPlanks)
			part(room, "Corniche", Vector3.new(width + 0.06, 0.10, 0.24), position + Vector3.yAxis * 0.21, brass)
		end
	end
	for _, x in { 0.63, 4.39 } do
		part(room, "Bac extérieur", Vector3.new(1.85, 0.77, 1.65), at(x, 13.67, 0.39), wood, false, Enum.Material.WoodPlanks)
		cloneMesh(world.meshes.Plant, room, CFrame.new(at(x, 13.67, 0.38)))
	end
	for _, z in { -0.42, 13.33 } do
		for _, x in { if z > 0 then 9.81 else 9.59, 13.43 } do
			part(room, "Borne de protection", Vector3.new(0.31, 1.65, 0.31), at(x, z, 0.83), brass, false, Enum.Material.Metal)
			part(room, "Bande de borne", Vector3.new(0.326, 0.24, 0.326), at(x, z, 1.18), ink)
		end
	end
	for _, p in { {9.32, 24.94}, {13.55, 24.95}, {9.33, -9.77}, {13.82, -9.75} } do
		local position = at(p[1], p[2])
		cloneMesh(world.meshes.Cone, room, CFrame.new(position))
	end
	local line = Color3.fromRGB(233, 221, 183)
	for z = 14.2, 16.0, 0.36 do
		part(room, "Passage piéton", Vector3.new(5.7, 0.015, 0.48), at(2.5, z, 0.006), line)
	end
	for _, x in { 2.5, 8.2, 12.5, 16.0 } do
		for _, z in { 2.2, 6.35, 10.2 } do
			cloneMesh(world.meshes.ShopLight, room, CFrame.new(at(x, z, 9.54)) * CFrame.Angles(0, math.pi / 2, 0))
		end
	end
end

function Decor.build(world, part, cloneMesh)
	world.nightLights, world.nightWindows = {}, {}
	street(world, part)
	forecourt(world, part)
	facade(world, part, cloneMesh)

	local panel = part(world.room, "Planning du garage", Vector3.new(7.12, 4.76, 0.13), at(4.81, 10.25, 6.15), ink, false, Enum.Material.Wood)
	panel.CFrame = CFrame.lookAt(panel.Position, panel.Position - Vector3.xAxis)
	local ui = surface(panel, Enum.NormalId.Front, Vector2.new(630, 416), 42)
	local header = letter(ui, "Planning du garage", UDim2.fromScale(0.06, 0.05), UDim2.fromScale(0.86, 0.11), paper, Enum.Font.GothamBold)
	header.TextXAlignment = Enum.TextXAlignment.Left
	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromScale(0.06, 0.19)
	divider.Size = UDim2.fromScale(0.88, 0.012)
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = brass
	divider.Parent = ui
	world.boardHeader = header
	world.boardRows = {}
	for i = 1, 9 do
		local row = letter(ui, "", UDim2.fromScale(0.06, 0.229 + (i - 1) * 0.084), UDim2.fromScale(0.88, 0.072), paper, Enum.Font.GothamMedium)
		row.TextXAlignment = Enum.TextXAlignment.Left
		world.boardRows[i] = row
	end

	local marker = Instance.new("BillboardGui")
	marker.Name = "Repère de l’étape"
	marker.Enabled = false
	marker.Size = UDim2.fromOffset(20, 20)
	marker.AlwaysOnTop = false
	marker.StudsOffsetWorldSpace = Vector3.new(0, 2.1, 0)
	marker.MaxDistance = 82
	marker.Parent = world.room
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(9, 9)
	dot.Rotation = 45
	dot.BackgroundColor3 = brass
	dot.BorderSizePixel = 0
	dot.Parent = marker
	local edge = Instance.new("UIStroke")
	edge.Color = ink
	edge.Thickness = 1
	edge.Parent = dot
	world.objective = marker
end

function Decor.updateBoard(world, state, jobs)
	world.boardHeader.Text = if state.day > 0 then `Planning · Jour {state.day}` else "Planning du garage"
	for i, row in world.boardRows do
		local order = state.orders[i]
		row.Visible = order ~= nil
		if order then
			local current = state.day > 0 and i == state.ticket and i > state.served
			local summary = {}
			for _, key in order.jobs do table.insert(summary, jobs[key].name) end
			local prefix = if order.paid then "✓  " elseif current then "→  " else ""
			row.Text = string.format("%s%s · %s · %d $", prefix, order.name, table.concat(summary, " / "), order.estimate)
			row.TextColor3 = if current then brass elseif i <= state.served then Color3.fromRGB(170, 218, 187) else paper
		end
	end
end

function Decor.setEvening(world, evening)
	for _, light in world.nightLights do
		light.Enabled = evening
		light.Parent.Material = if evening then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	for index, pane in world.nightWindows do
		pane.Color = if evening and index % 3 ~= 1 then Color3.fromRGB(244, 187, 114) else glass
		pane.Material = if evening and index % 3 ~= 1 then Enum.Material.Neon else Enum.Material.Glass
	end
end

return Decor

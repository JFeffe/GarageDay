local Layout = require(script.Parent.PetitAtelier)

local Decor = {}
local at = Layout.at
local ink = Color3.fromRGB(34, 61, 62)
local paper = Color3.fromRGB(255, 239, 203)
local brass = Color3.fromRGB(228, 179, 99)
local moss = Color3.fromRGB(96, 129, 108)
local concrete = Color3.fromRGB(156, 155, 137)
local asphalt = Color3.fromRGB(62, 72, 76)

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
			part(room, "Cadre de maison", Vector3.new(2.4, 2.92, 0.16), origin + Vector3.new(offset, 4.95, facing * 4.61), paper)
			part(room, "Fenêtre de maison", Vector3.new(1.98, 2.5, 0.19), origin + Vector3.new(offset, 4.95, facing * 4.69),
				Color3.fromRGB(99, 144, 158), false, Enum.Material.Glass)
		end
		part(room, "Porte de maison", Vector3.new(2.44, 4.13, 0.24), origin + Vector3.new(0, 1.80, facing * 4.64), roof,
			false, Enum.Material.WoodPlanks)
	end

	for i, coordinates in { {-11, -22}, {-0.5, -21}, {13.0, -22.5}, {29, -24}, {-9.4, 47.0}, {0.7, 47.4}, {16.6, 48.0},
		{29.3, 46.9}, {-3.4, 14.25}, {20.4, 6.3}, {19.1, 19.6}, {-3.1, -6.6} } do
		local origin = at(coordinates[1], coordinates[2])
		local height = 8.4 + (i % 3) * 1.46
		part(room, "Tronc", Vector3.new(0.68, height * 0.62, 0.68), origin + Vector3.new(0, height * 0.27, 0),
			Color3.fromRGB(113, 91, 66), false, Enum.Material.Wood)
		local crown = part(room, "Feuillage", Vector3.new(5.3, height * 0.72, 5.15), origin + Vector3.new(0, height * 0.73, 0),
			moss:Lerp(Color3.fromRGB(154, 158, 102), (i % 4) / 6), false, Enum.Material.Grass)
		crown.Shape = Enum.PartType.Ball
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
	for _, x in { 0.63, 4.39 } do
		part(room, "Bac extérieur", Vector3.new(1.85, 0.77, 1.65), at(x, 13.67, 0.39), wood, false, Enum.Material.WoodPlanks)
		cloneMesh(world.meshes.Plant, room, CFrame.new(at(x, 13.67, 0.38)))
	end
	for _, z in { -0.42, 13.33 } do
		for _, x in { 9.59, 13.43 } do
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
	street(world, part)
	facade(world, part, cloneMesh)

	local panel = part(world.room, "Planning du garage", Vector3.new(7.12, 3.74, 0.13), at(4.81, 10.25, 6.20), ink, false, Enum.Material.Wood)
	panel.CFrame = CFrame.lookAt(panel.Position, panel.Position - Vector3.xAxis)
	local ui = surface(panel, Enum.NormalId.Front, Vector2.new(590, 310), 42)
	local header = letter(ui, "Planning du garage", UDim2.fromScale(0.06, 0.08), UDim2.fromScale(0.86, 0.17), paper, Enum.Font.GothamBold)
	header.TextXAlignment = Enum.TextXAlignment.Left
	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromScale(0.06, 0.29)
	divider.Size = UDim2.fromScale(0.88, 0.012)
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = brass
	divider.Parent = ui
	world.boardHeader = header
	world.boardRows = {}
	for i = 1, 3 do
		local row = letter(ui, "", UDim2.fromScale(0.06, 0.36 + (i - 1) * 0.174), UDim2.fromScale(0.88, 0.12), paper, Enum.Font.GothamMedium)
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

function Decor.updateBoard(world, state, plan, jobs)
	world.boardHeader.Text = if state.day > 0 then `Planning · Jour {state.day}` else "Planning du garage"
	for i, row in world.boardRows do
		local order = plan[i]
		row.Visible = order ~= nil
		if order then
			local current = state.day > 0 and i == state.ticket and i > state.served
			row.Text = `{if i <= state.served then "✓  " elseif current then "→  " else ""}{order.name}  ·  {jobs[order.job].name}  ·  {order.amount} $`
			row.TextColor3 = if current then brass elseif i <= state.served then Color3.fromRGB(170, 218, 187) else paper
		end
	end
end

return Decor

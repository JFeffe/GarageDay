local Layout = {}

local scale = 3.1
Layout.scale = scale

function Layout.at(x, z, height)
	return Vector3.new((x - 11.5) * scale, height or 0, (z - 6.5) * scale)
end

-- The first Godot layout, relative to the centre of bay 01.
Layout.walls = {
	{0, 3.9, 1.2, 0.18}, {3.8, 3.9, 1.2, 0.18},
	{0, 7.8, 1.2, 0.18}, {3.8, 7.8, 1.2, 0.18},
	{0, 12.82, 1.5, 0.18}, {3.5, 12.82, 4.9, 0.18},
	{4.9, 0, 0.18, 4.8}, {4.9, 7.6, 0.18, 5.4},
	{0, 0, 5.89, 0.18}, {7.52, 0, 0.88, 0.18}, {8.4, 0, 1.48, 0.18},
	{13.12, 0, 1.38, 0.18}, {14.5, 0, 3.5, 0.18},
	{8.4, 12.82, 0.15, 0.18}, {9.82, 12.82, 0.06, 0.18},
	{13.12, 12.82, 1.38, 0.18}, {14.5, 12.82, 3.5, 0.18},
}

Layout.sideWindows = {
	{ x = 0, openings = { {0.96, 2.89}, {4.52, 6.58}, {8.64, 10.62} } },
	{ x = 17.82, openings = { {1.24, 3.67}, {5.27, 7.74}, {9.52, 11.88} } },
}

Layout.pedestrianDoors = {
	{ name = "Porte de l’accueil", left = 1.5, right = 3.5, z = 12.82, outside = 1, double = true },
	{ name = "Porte de l’atelier", left = 8.55, right = 9.82, z = 12.82, outside = 1 },
	{ name = "Porte de sortie", left = 5.89, right = 7.52, z = 0, outside = -1 },
}

Layout.stations = {
	phone = {2, 2.5}, officeChair = {2.5, 1.5}, bookcase = {3.5, 1.5},
	waitingBench = {1.5, 5.5}, reception = {2, 9.5}, plant = {1.5, 11.5},
	bench = {7.5, 5.5}, cart = {7.5, 8.5}, partsChassis = {6.5, 10.5}, partsElectric = {7.5, 10.5},
	toolWrench = {16.5, 2.5}, toolPressure = {16.5, 3.5}, toolInspection = {16.5, 1.5}, toolOil = {16.5, 4.5},
	counter = {16.5, 6.5}, wasteOil = {16.5, 8.5}, trash = {16.5, 9.5},
}

Layout.arrivals = { {9.8, 24.9, 3.4, 5.9}, {13.8, 24.9, 3.4, 5.9}, {5.8, 24.9, 3.4, 5.9} }
Layout.parking = {9.8, -10.45, 3.4, 5.9}
Layout.bay = {9.9, 4.11, 3.2, 4.78}

function Layout.centre(rect, height)
	return Layout.at(rect[1] + rect[3] / 2, rect[2] + rect[4] / 2, height)
end

return Layout

local scale = 3.1
local Layout = {
	name = "Le Tandem", width = 28, depth = 17, wing = 7,
	origin = Vector2.new(15.5, 8), entry = 3.5, exit = 9.36,
	officeSplit = 5.6, receptionSplit = 10.8, scale = scale,
	toolSide = 1,
	shopPassage = {7.1, 10},
	lamps = { 3.5, 9.5, 15.5, 21.5, 26 }, lampRows = { 2.5, 7.7, 13.65 },
	vendor = { 7.5, 21.3 }, board = { 6.85, 13.33 },
}

function Layout.at(x, z, height)
	return Vector3.new((x - Layout.origin.X) * scale, height or 0, (z - Layout.origin.Y) * scale)
end

function Layout.centre(rect, height)
	return Layout.at(rect[1] + rect[3] / 2, rect[2] + rect[4] / 2, height)
end

-- Le Tandem uses the plan from workshop_map.gd, including its separate pedestrian exit.
Layout.walls = {
	{0, 5.6, 2.1, 0.18}, {4.5, 5.6, 2.5, 0.18}, {0, 10.8, 2.1, 0.18}, {4.5, 10.8, 2.5, 0.18},
	{6.9, 0, 0.18, 7.1}, {6.9, 10, 0.18, 7},
	{0, 16.82, 2.5, 0.18}, {4.5, 16.82, 8.05, 0.18}, {13.82, 16.82, 0.06, 0.18},
	{0, 0, 8.55, 0.18}, {10.18, 0, 3.70, 0.18},
	{17.12, 0, 2.76, 0.18}, {23.12, 0, 4.88, 0.18},
	{17.12, 16.82, 2.76, 0.18}, {23.12, 16.82, 4.88, 0.18},
}
Layout.sideWindows = {
	{ x = 0, openings = {{1.2, 3.9}, {6.8, 9.35}, {12.35, 15.25}} },
	{ x = 27.82, openings = {{1.3, 4.45}, {6.4, 9.62}, {12.05, 15.45}} },
}
Layout.pedestrianDoors = {
	{ name = "Porte de l’accueil", left = 2.5, right = 4.5, z = 16.82, outside = 1, double = true },
	{ name = "Porte de l’atelier", left = 12.55, right = 13.82, z = 16.82, outside = 1 },
	{ name = "Porte de sortie", left = 8.55, right = 10.18, z = 0, outside = -1 },
}
Layout.stations = {
	phone = {2, 2.5}, officeChair = {2.5, 1.5}, bookcase = {3.5, 1.5},
	waitingBench = {1.5, 8.0}, secondBench = {1.5, 9.35}, reception = {3, 12.5}, plant = {1.5, 14.5},
	bench = {12.25, 5.5}, cart = {10.85, 9.45}, partsChassis = {8.5, 13.5}, partsElectric = {11.5, 12.5},
	toolWrench = {7.65, 1.2}, toolPressure = {7.65, 5.7}, toolInspection = {7.65, 4.2}, toolOil = {7.65, 2.7},
	counter = {11.55, 14.65}, wasteOil = {9.5, 16.18}, trash = {11.5, 16.18},
	recycling = {10.5, 16.18}, compressor = {12.7, 1.5}, toolPanel = {7.23, 3.45},
	tireRack = {9.05, 14.5}, longShelf = {7.7, 11.15}, recovery = {8.12, 6.6}, wheelStand = {12.26, 6.72},
	tireBin = {11.85, 18.2}, scrap = {8.42, 16.12}, doubleCounter = {9.1, 5.25},
	vending = {5.75, 7.25}, magazines = {1.24, 7.15},
}
Layout.arrivals = { {9.8, 24.9, 3.4, 5.9}, {5.8, 24.9, 3.4, 5.9} }
Layout.deposits = { {9.1, 8.15}, {26, 9.30} }
Layout.bays = {}
for index, x in { 15.5, 21.5 } do
	Layout.bays[index] = {
		x = x, z = 8, lever = {x + 3, 11.5}, intake = 16.93,
		dock = {x - 1.6, 5.61, 3.2, 4.78},
		parking = {x - 1.7, -10.45, 3.4, 5.9}, arrival = {x - 1.7, 24.9, 3.4, 5.9},
	}
end

return Layout

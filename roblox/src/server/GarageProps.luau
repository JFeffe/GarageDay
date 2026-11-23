local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(script.Parent.GearWorld)
local Layout = require(script.Parent.PetitAtelier)
local Service = require(ReplicatedStorage.GarageDay.Service)

local Props = {}
local at = Layout.at
local teal = Color3.fromRGB(50, 87, 88)
local gold = Color3.fromRGB(234, 164, 85)
local steel = Color3.fromRGB(58, 68, 69)
local cream = Color3.fromRGB(245, 220, 173)
local ivory = Color3.fromRGB(238, 224, 195)
local red = Color3.fromRGB(150, 68, 52)

local function makeCart(world, part, model, cloneMesh, target, sign)
	local home = at(table.unpack(Layout.stations.cart))
	local cart = model(world.room, "Chariot à pneus", CFrame.new(home))
	if not cloneMesh(world.meshes.Trolley, cart, CFrame.new(home)) then
		part(cart, "Plateau", Vector3.new(2.67, 0.20, 2.13), home + Vector3.yAxis * 0.46, red)
		part(cart, "Poignée", Vector3.new(2.06, 0.14, 0.16), home + Vector3.new(0, 2.45, 1.08), steel)
	end
	local tires = {}
	for i = 1, 4 do
		local wheel = Gear.place(world, "newTire", cart, CFrame.new(home + Vector3.new(0, 0.78 + (i - 1) * 0.72, 0))
			* CFrame.Angles(0, 0, math.pi / 2))
		tires[i] = wheel
		for _, piece in wheel:GetChildren() do piece.Transparency = 1 end
	end
	world.cart = { model = cart, stock = 0, tires = tires, owner = nil, driver = nil, oldSpeed = nil }
	world.targets.Cart = target(cart, "Poignée du chariot", home + Vector3.new(0, 2.52, 1.06))
	sign(world.targets.Cart, "CHARIOT", 1.35, 19)
end

local function makeVendor(world, part, model, cloneMesh, target, sign)
	local position = at(15.87, 20.55)
	world.vendorParking = CFrame.new(position)
	world.vendorEntry = CFrame.new(at(22.06, 36.1)) * CFrame.Angles(0, math.rad(36), 0)
	local vendor = model(nil, "La Caravane", world.vendorParking)
	world.vendor = vendor
	local copy = cloneMesh(world.meshes.Delivery, vendor, world.vendorParking)
	if not copy then
		part(vendor, "Carrosserie", Vector3.new(6.2, 3.2, 11.3), position + Vector3.yAxis * 2.49, cream)
		part(vendor, "Cabine", Vector3.new(6.2, 2.38, 3.05), position + Vector3.new(0, 2.74, -5.4), teal)
	end
	part(vendor, "Comptoir de la caravane", Vector3.new(1.32, 0.22, 4.60), position + Vector3.new(-3.65, 2.63, 0.72), teal, true)
	part(vendor, "Enseigne", Vector3.new(0.12, 0.88, 5.0), position + Vector3.new(-3.39, 4.66, 0.72), red)
	local shelf = part(vendor, "Auvent", Vector3.new(2.32, 0.12, 5.46), position + Vector3.new(-4.28, 4.29, 0.72), teal)
	shelf.CFrame *= CFrame.Angles(0, 0, math.rad(8))
	for index = 1, 7 do
		local stripe = part(vendor, "Toile de l’auvent", Vector3.new(2.38, 0.12, 0.36),
			position + Vector3.new(-4.28, 4.33, -1.70 + (index - 1) * 0.80), cream)
		stripe.CFrame *= CFrame.Angles(0, 0, math.rad(8))
	end
	for j, key in { "inspection", "pressure", "frontBulb" } do
		Gear.place(world, key, vendor, CFrame.new(position + Vector3.new(-3.72, 2.99, -0.48 + (j - 1) * 1.17)))
	end
	local bulb = part(vendor, "Lampe", Vector3.new(0.27, 0.13, 3.65), position + Vector3.new(-4.59, 4.09, 0.65), ivory, false, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Brightness, light.Range, light.Color = 1.45, 16, Color3.fromRGB(255, 201, 134)
	light.Parent = bulb
	world.targets.Vendor = target(vendor, "Comptoir", position + Vector3.new(-4.64, 3.15, 0.74))
	sign(world.targets.Vendor, "LA CARAVANE", 1.89, 58)
end

local function makeUpgrades(world, part, model, target, sign)
	local position = at(6.23, 4.12)
	local counters = model(nil, "Desserte double", CFrame.new(position))
	for _, name in { "Counter1", "Counter2" } do
		local top = world.slots[name].Position
		part(counters, "Plateau", Vector3.new(1.9, 0.19, 2.14), top - Vector3.yAxis * 0.50, teal, true)
		for _, corner in { Vector3.new(-0.73, 0, -0.81), Vector3.new(0.73, 0, 0.81) } do
			part(counters, "Pied", Vector3.new(0.14, 2.01, 0.15), top + corner - Vector3.yAxis * 1.58, steel)
		end
	end
	local vendingPoint = at(3.73, 5.30)
	local vending = model(nil, "Distributrice", CFrame.new(vendingPoint))
	part(vending, "Distributrice", Vector3.new(2.4, 5.15, 1.60), vendingPoint + Vector3.yAxis * 2.58, teal, true)
	part(vending, "Vitrine", Vector3.new(1.89, 2.70, 0.14), vendingPoint + Vector3.new(0, 3.31, -0.85), ivory)
	for i, color in { red, gold, teal } do
		for j = 1, 4 do
			part(vending, "Collation", Vector3.new(0.25, 0.43, 0.14),
				vendingPoint + Vector3.new(-0.67 + (j - 1) * 0.44, 2.55 + (i - 1) * 0.85, -0.95), color)
		end
	end
	part(vending, "Trappe", Vector3.new(1.48, 0.42, 0.15), vendingPoint + Vector3.new(0, 0.86, -0.85), steel)
	world.targets.Snack = target(vending, "Collation", vendingPoint + Vector3.new(0, 3.13, -1.14))
	sign(world.targets.Snack, "COLLATIONS", 2.32, 20)

	local magazinePoint = at(1.17, 6.67)
	local magazines = model(nil, "Porte-magazines", CFrame.new(magazinePoint))
	part(magazines, "Présentoir", Vector3.new(1.77, 1.71, 0.40), magazinePoint + Vector3.yAxis * 1.30, steel)
	for i, color in { red, gold, teal } do
		part(magazines, "Magazine", Vector3.new(0.46, 0.89, 0.19), magazinePoint + Vector3.new((i - 2) * 0.48, 1.98, -0.22), color)
	end
	local lounge = model(nil, "Salle d’attente confort")
	for _, offset in { -0.56, 0.55 } do
		local cushion = part(lounge, "Coussin", Vector3.new(0.79, 0.26, 0.80), at(1.58, 5.50, 1.50) + Vector3.zAxis * offset, gold)
		cushion.CFrame *= CFrame.Angles(0.06, 0.1, 0.12)
	end
	part(lounge, "Tapis", Vector3.new(3.2, 0.048, 4.01), at(2.43, 5.65, 0.077), red, false, Enum.Material.Fabric)
	world.upgradeProps = { counter = counters, vending = vending, magazines = magazines, lounge = lounge }
end

function Props.build(world, part, model, cloneMesh, target, sign)
	makeCart(world, part, model, cloneMesh, target, sign)
	makeVendor(world, part, model, cloneMesh, target, sign)
	makeUpgrades(world, part, model, target, sign)
end

function Props.apply(world, state)
	for key, prop in world.upgradeProps do
		local parent = if Service.owns(state, key) then world.room else nil
		if prop.Parent ~= parent then prop.Parent = parent end
	end
	if world.compressor and Service.owns(state, "compressor") then world.compressor.Color = Color3.fromRGB(195, 228, 209) end
end

function Props.stockCart(world, amount)
	local cart = world.cart
	cart.stock = math.clamp(cart.stock + amount, 0, #cart.tires)
	for index, tire in cart.tires do
		for _, piece in tire:GetChildren() do piece.Transparency = if index <= cart.stock then 0 else 1 end
	end
end

function Props.parkCart(world)
	local cart = world.cart
	if cart.driver and cart.driver.Parent then cart.driver.WalkSpeed = cart.oldSpeed end
	cart.owner, cart.driver, cart.oldSpeed = nil, nil, nil
end

function Props.pullCart(world, player, state)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local cart = world.cart
	if not humanoid or (cart.owner and cart.owner ~= player) then return false end
	if cart.owner then
		Props.parkCart(world)
	else
		cart.owner, cart.driver, cart.oldSpeed = player, humanoid, humanoid.WalkSpeed
		humanoid.WalkSpeed = if Service.owns(state, "light_cart") then cart.oldSpeed else math.min(9.5, cart.oldSpeed)
	end
	return true
end

function Props.moveCart(world, dt)
	local cart = world.cart
	if not cart.owner then return true end
	local character = cart.owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or cart.driver.Health <= 0 then
		Props.parkCart(world)
		return false
	end
	local pivot = cart.model:GetPivot()
	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if facing.Magnitude < 0.1 then return true end
	local destination = root.Position + facing.Unit * 3.1
	destination = Vector3.new(destination.X, pivot.Y, destination.Z)
	local shift = destination - pivot.Position
	if shift.Magnitude > 11 then
		Props.parkCart(world)
		return false
	end
	if shift.Magnitude < 0.045 then return true end
	local travel = shift * math.min(1, dt * 6)
	local query = RaycastParams.new()
	query.FilterType = Enum.RaycastFilterType.Exclude
	query.FilterDescendantsInstances = { character, cart.model }
	query.RespectCanCollide = true
	local blockage = workspace:Blockcast(pivot + Vector3.yAxis * 1.08, Vector3.new(2.57, 1.68, 2.27), travel, query)
	if not blockage then cart.model:PivotTo(CFrame.lookAlong(pivot.Position + travel, facing)) end
	return true
end

return Props

local Drive = {}
Drive.__index = Drive

local carSize = Vector3.new(6.04, 3.1, 13.36)
local seat = CFrame.new(-0.81, 1.98, 0.77)

local function approach(value, goal, amount)
	return value + math.clamp(goal - value, -amount, amount)
end

function Drive.new(world)
	local query = OverlapParams.new()
	query.FilterType = Enum.RaycastFilterType.Exclude
	query.RespectCanCollide = true
	query.MaxParts = 1
	return setmetatable({ world = world, query = query, speed = 0, throttle = 0, steer = 0, lastInput = 0 }, Drive)
end

function Drive:enter(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if self.rider or not root or not humanoid or humanoid.Health <= 0 or root.Anchored then return false end
	self.rider = { character = character, root = root, humanoid = humanoid, autoRotate = humanoid.AutoRotate }
	self.query.FilterDescendantsInstances = { self.world.vehicle, character }
	root.Anchored = true
	humanoid.AutoRotate = false
	humanoid.Sit = true
	character:PivotTo(self.world.vehicle:GetPivot() * seat)
	return true
end

function Drive:setInput(throttle, steer)
	if type(throttle) ~= "number" or type(steer) ~= "number" then return end
	if throttle ~= throttle or steer ~= steer or math.abs(throttle) > 1 or math.abs(steer) > 1 then return end
	self.throttle = throttle
	self.steer = steer
	self.lastInput = os.clock()
end

function Drive:clear(pose)
	return #workspace:GetPartBoundsInBox(pose * CFrame.new(0, 2.15, 0), carSize, self.query) == 0
end

function Drive:update(dt)
	local rider = self.rider
	if not rider or not rider.root.Parent then return end
	if os.clock() - self.lastInput > 0.32 then
		self.throttle = 0
		self.steer = 0
	end
	dt = math.min(dt, 0.055)
	local target = self.throttle * (if self.throttle >= 0 then 20.0 else 10.8)
	local response = if math.abs(target) < math.abs(self.speed) or target * self.speed < 0 then 28 else 14
	self.speed = approach(self.speed, target, response * dt)
	if math.abs(self.speed) < 0.01 then return end
	local pose = self.world.vehicle:GetPivot()
	local steering = -self.steer * math.sign(self.speed) * math.min(math.abs(self.speed) / 7, 1) * 1.36 * dt
	local rotation = pose.Rotation * CFrame.Angles(0, steering, 0)
	local nextPose = CFrame.new(pose.Position + rotation.LookVector * self.speed * dt) * rotation
	if self:clear(nextPose) then
		self.world.vehicle:PivotTo(nextPose)
		rider.root.CFrame = nextPose * seat
	else
		self.speed = 0
	end
end

function Drive:aligned(goal)
	local pose = self.world.vehicle:GetPivot()
	local offset = goal:PointToObjectSpace(pose.Position)
	if math.abs(offset.Z) > 2.3 or math.abs(offset.X) > 1.63 then return false, "Aligne la berline entre les lignes jaunes." end
	if pose.LookVector:Dot(goal.LookVector) < 0.948 then return false, "Redresse la voiture vers la sortie." end
	if math.abs(self.speed) > 2.2 then return false, "Relâche l’accélérateur pour t’arrêter." end
	if not self:clear(goal) then return false, "Dégage la place avant de valider." end
	return true, "Position correcte. Valide pour descendre."
end

function Drive:leave(goal)
	local rider = self.rider
	if not rider then return end
	self.rider = nil
	self.speed, self.throttle, self.steer = 0, 0, 0
	local vehicle = self.world.vehicle
	if goal then vehicle:PivotTo(goal) end
	if not rider.root.Parent then return end

	local pose = vehicle:GetPivot()
	local chosen = self.world.spawns[1].Position + Vector3.new(0, 3.1, 0)
	for _, offset in { Vector3.new(-4.65, 3.06, 0.48), Vector3.new(4.65, 3.06, 0.48),
		Vector3.new(-4.65, 3.06, 3.1), Vector3.new(4.65, 3.06, -3.1), Vector3.new(0, 3.06, 8.04) } do
		local position = pose:PointToWorldSpace(offset)
		if #workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(1.95, 4.7, 1.85), self.query) == 0 then
			chosen = position
			break
		end
	end
	rider.humanoid.Sit = false
	rider.humanoid.AutoRotate = rider.autoRotate
	local toward = Vector3.new(pose.X, chosen.Y, pose.Z)
	rider.character:PivotTo(CFrame.lookAt(chosen, toward))
	rider.root.Anchored = false
end

return Drive

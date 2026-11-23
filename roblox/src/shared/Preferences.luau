--!strict

local Preferences = {
	defaultSensitivity = 55,
	minSensitivity = 20,
	maxSensitivity = 130,
	step = 5,
}

function Preferences.sensitivity(value: unknown): number?
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return nil end
	local step = Preferences.step
	return math.clamp(math.round(value / step) * step, Preferences.minSensitivity, Preferences.maxSensitivity)
end

return table.freeze(Preferences)

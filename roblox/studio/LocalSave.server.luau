local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() or not RunService:IsServer() or RunService:IsEdit() or game.GameId ~= 0 then return end
local garage = ReplicatedStorage:FindFirstChild("GarageDay")
if not garage or garage:GetAttribute("StudioStorage") ~= "GarageDayV1" then return end

local EncodingService = game:GetService("EncodingService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local store = Instance.new("BindableFunction")
store.Name = "GarageDayLocalSave"
store.OnInvoke = function(operation, key, expected, value)
	assert(type(key) == "string" and (key:match("^workshop_%-?%d+$") or key:match("^options_%-?%d+$")), "Clé de sauvegarde inconnue")
	local current = plugin:GetSetting(key)
	if operation == "read" then
		if current == nil then return nil, nil end
		assert(type(current) == "string", "Format de sauvegarde locale incorrect")
		local json = buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(current)))
		return HttpService:JSONDecode(json), current
	end
	assert(operation == "write" and type(value) == "table", "Écriture de sauvegarde incorrecte")
	if current ~= expected then return false end
	local json = HttpService:JSONEncode(value)
	local encoded = buffer.tostring(EncodingService:Base64Encode(buffer.fromstring(json)))
	plugin:SetSetting(key, encoded)
	assert(plugin:GetSetting(key) == encoded, "Écriture locale non confirmée")
	return true
end
store.Parent = ServerStorage
plugin.Unloading:Connect(function() store:Destroy() end)
